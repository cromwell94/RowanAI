import StoreKit
import SwiftUI

// MARK: - Timeout helper

struct TimeoutError: Error {}

func withTimeout<T: Sendable>(seconds: TimeInterval,
                              operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        // The first one to complete wins; the other gets cancelled in defer.
        guard let result = try await group.next() else { throw TimeoutError() }
        return result
    }
}

// MARK: - Product IDs
// These must match exactly what you create in App Store Connect.
// All four sit in the same subscription group ("Rowan Pro") so a Pro user
// upgrading to Pro+ swaps cleanly without double-billing.

enum RowanProduct: String, CaseIterable {
    case monthlyPro     = "com.rakitastudios.RowanAI.pro.monthly"
    case annualPro      = "com.rakitastudios.RowanAI.pro.annual"
    case monthlyProPlus = "com.rakitastudios.RowanAI.proplus.monthly"
    case annualProPlus  = "com.rakitastudios.RowanAI.proplus.annual"

    var displayName: String {
        switch self {
        case .monthlyPro:     return "Rowan Pro Monthly"
        case .annualPro:      return "Rowan Pro Annual"
        case .monthlyProPlus: return "Rowan Pro+ Monthly"
        case .annualProPlus:  return "Rowan Pro+ Annual"
        }
    }

    var tier: SubscriptionTier {
        switch self {
        case .monthlyPro, .annualPro:         return .pro
        case .monthlyProPlus, .annualProPlus: return .proPlus
        }
    }
}

// MARK: - Subscription Tier

/// Three-tier model: free → pro → proPlus. Higher integer = more access, so
/// `>=` checks (`currentTier >= .pro`) are the canonical gating idiom. A user
/// on Pro+ counts as "Pro" for every feature except Cyrano Live.
enum SubscriptionTier: Int, Comparable, Codable {
    case free    = 0
    case pro     = 1
    case proPlus = 2

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .free:    return "Free"
        case .pro:     return "Pro"
        case .proPlus: return "Pro+"
        }
    }
}

// MARK: - Cached Product Info
// Lightweight snapshot persisted to UserDefaults so the paywall can render
// the user's last-seen prices/labels even when the live fetch is slow or
// offline. Updated on every successful loadProducts() call.

struct CachedProductInfo: Codable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
}

// Surfaced as a typed enum so the paywall can render skeleton / cached /
// real / error states unambiguously.
enum StoreLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

// MARK: - Store Manager

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    var products: [Product] = []
    /// True for both Pro and Pro+ subscribers. Existing call sites stay correct.
    var isPro: Bool = false
    /// Pro+ only — gates Cyrano Live and other Pro+ exclusives.
    var isProPlus: Bool = false
    /// Highest tier the user currently holds.
    var currentTier: SubscriptionTier = .free
    var loadState: StoreLoadState = .idle
    var purchaseError: String = ""

    /// Cyrano Live is exclusively Pro+. Use this everywhere instead of a
    /// raw isProPlus check to keep the gating semantically clear.
    var hasCyranoLive: Bool { isProPlus }

    private var updateListenerTask: Task<Void, Error>? = nil
    private var hasRetried = false
    private var loadInFlight: Task<Void, Never>? = nil

    private static let cacheKey = "store.cached.products.v2"

    private init() {
        // Hydrate from cache synchronously so the paywall can render last-known
        // pricing immediately on first appearance.
        _ = cachedProducts()
        updateListenerTask = listenForTransactions()
    }
    // No deinit — `static let shared` lives for the app's lifetime, and the
    // task listener is automatically torn down on process exit.

    /// Called from app launch (`RowanAIApp.init`) so products are fetched and
    /// entitlements verified before the paywall is ever shown. Idempotent —
    /// re-entry while a load is in flight is a no-op.
    func prepare() {
        Task { await loadProducts() }
        Task { await checkEntitlements() }
    }

    // MARK: - Load Products

    /// Fetches subscription products with a hard 10-second timeout, automatic
    /// single retry on first failure, and cache hydration after success. Safe
    /// to call repeatedly — concurrent calls coalesce to the in-flight task.
    func loadProducts(timeoutSeconds: TimeInterval = 10) async {
        if let existing = loadInFlight {
            await existing.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runLoad(timeoutSeconds: timeoutSeconds, isRetry: false)
        }
        loadInFlight = task
        await task.value
        loadInFlight = nil
    }

    private func runLoad(timeoutSeconds: TimeInterval, isRetry: Bool) async {
        loadState = .loading
        purchaseError = ""

        do {
            let storeProducts = try await withTimeout(seconds: timeoutSeconds) {
                try await Product.products(for: RowanProduct.allCases.map { $0.rawValue })
            }
            // Annual goes first in the paywall list; monthly follows.
            products = storeProducts.sorted { lhs, rhs in
                if lhs.id == RowanProduct.annualPro.rawValue { return true }
                if rhs.id == RowanProduct.annualPro.rawValue { return false }
                return lhs.id < rhs.id
            }
            cacheProducts(storeProducts)
            loadState = .loaded
            hasRetried = false
        } catch is TimeoutError {
            if !isRetry {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await runLoad(timeoutSeconds: timeoutSeconds, isRetry: true)
                return
            }
            loadState = .failed("Couldn't reach the App Store in time. Check your connection and try again.")
        } catch {
            if !isRetry {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await runLoad(timeoutSeconds: timeoutSeconds, isRetry: true)
                return
            }
            loadState = .failed(friendlyMessage(for: error))
        }
    }

    /// Public retry hook for the paywall's "Try again" button.
    func retryLoad() {
        guard loadInFlight == nil else { return }
        Task { await loadProducts() }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        purchaseError = ""
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await checkEntitlements()
                    return true
                case .unverified:
                    purchaseError = "Purchase could not be verified. If you were charged, contact Apple Support."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval (often Family Sharing or Ask to Buy)."
                return false
            @unknown default:
                return false
            }
        } catch let skError as StoreKitError {
            purchaseError = friendlyMessage(for: skError)
            return false
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        purchaseError = ""
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            purchaseError = "Restore failed. Please try again."
        }
    }

    // MARK: - Check Entitlements
    // Pure StoreKit 2 verification — Transaction.currentEntitlements only
    // yields verified transactions on the .verified case; .unverified is
    // explicitly skipped so a tampered receipt can never grant Pro.

    func checkEntitlements() async {
        // Walk every verified entitlement and pick the highest tier the user
        // currently holds. Skipping revoked / upgraded transactions — both
        // signal a transition state where the entitlement should NOT be active.
        var highest: SubscriptionTier = .free
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
                if let product = RowanProduct(rawValue: transaction.productID) {
                    if product.tier.rawValue > highest.rawValue {
                        highest = product.tier
                    }
                }
            case .unverified:
                // Untrusted — log only, do not grant entitlement.
                #if DEBUG
                print("[StoreManager] skipping unverified entitlement")
                #endif
            }
        }
        currentTier = highest
        isPro = highest >= .pro
        isProPlus = highest >= .proPlus
    }

    // MARK: - Listen for Transactions

    func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.checkEntitlements()
                case .unverified:
                    #if DEBUG
                    print("[StoreManager] skipping unverified transaction update")
                    #endif
                }
            }
        }
    }

    // MARK: - Cached display info

    func cachedProducts() -> [CachedProductInfo] {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let infos = try? JSONDecoder().decode([CachedProductInfo].self, from: data)
        else { return [] }
        return infos
    }

    private func cacheProducts(_ products: [Product]) {
        let infos = products.map {
            CachedProductInfo(id: $0.id,
                              displayName: $0.displayName,
                              displayPrice: $0.displayPrice)
        }
        if let data = try? JSONEncoder().encode(infos) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    // MARK: - Error mapping

    private func friendlyMessage(for error: Error) -> String {
        if let skError = error as? StoreKitError {
            switch skError {
            case .userCancelled:
                return ""
            case .networkError:
                return "Network error. Check your connection and try again."
            case .systemError:
                return "App Store is unavailable right now. Please try again in a moment."
            case .notAvailableInStorefront:
                return "Rowan Pro isn't available in your region yet."
            case .notEntitled:
                return "You're not entitled to make this purchase on this account."
            case .unknown:
                return "Something went wrong with the App Store. Please try again."
            case .unsupported:
                return "In-app purchases aren't supported on this device."
            @unknown default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Free Tier Limits
    // Caps surfaced in the paywall reason copy below — keep in sync.

    static let freeRepliesPerDay = 10
    static let freeDebriefsPerMonth = 3
    static let freeArchiveLimit = 5
    static let freeSimSessionsPerWeek = 2
    static let freePracticeScenarios = 2
    static let freeLessonCategories = 1
    static let freeFillMeInsPerWeek = 5
    static let freeProfilePhotosPerWeek = 2
    static let freeProfilePromptsPerDay = 5
    static let freeProfileBiosPerDay = 3
    static let freeProfileOpenersPerDay = 5

    private func dayKey(_ prefix: String, _ date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(prefix)_\(comps.year ?? 0)_\(comps.month ?? 0)_\(comps.day ?? 0)"
    }

    private func monthKey(_ prefix: String, _ date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(prefix)_\(comps.year ?? 0)_\(comps.month ?? 0)"
    }

    private func weekKey(_ prefix: String, _ date: Date = Date()) -> String {
        // weekOfYear + yearForWeekOfYear keeps the cap stable across Sun→Mon
        // boundaries and across year-end weeks (week 53 / week 1).
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        return "\(prefix)_\(comps.yearForWeekOfYear ?? 0)_w\(comps.weekOfYear ?? 0)"
    }

    func canUseReplies() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: dayKey("replies"))
        return count < StoreManager.freeRepliesPerDay
    }

    func trackReplyUsed() {
        guard !isPro else { return }
        let key = dayKey("replies")
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    func repliesRemainingToday() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: dayKey("replies"))
        return max(0, StoreManager.freeRepliesPerDay - count)
    }

    func canUseDebrief() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: monthKey("debriefs"))
        return count < StoreManager.freeDebriefsPerMonth
    }

    func trackDebriefUsed() {
        guard !isPro else { return }
        let key = monthKey("debriefs")
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    func debriefsRemainingThisMonth() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: monthKey("debriefs"))
        return max(0, StoreManager.freeDebriefsPerMonth - count)
    }

    func canUseSimSession() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: weekKey("sim_sessions"))
        return count < StoreManager.freeSimSessionsPerWeek
    }

    func trackSimSessionUsed() {
        guard !isPro else { return }
        let key = weekKey("sim_sessions")
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    func simSessionsRemainingThisWeek() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: weekKey("sim_sessions"))
        return max(0, StoreManager.freeSimSessionsPerWeek - count)
    }

    func canAddToArchive() -> Bool {
        if isPro { return true }
        return ArchiveStore.shared.active.count < StoreManager.freeArchiveLimit
    }

    // Fill Me In — weekly cap.
    func canUseFillMeIn() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: weekKey("fillmein"))
        return count < StoreManager.freeFillMeInsPerWeek
    }

    func trackFillMeInUsed() {
        guard !isPro else { return }
        let key = weekKey("fillmein")
        let count = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(count + 1, forKey: key)
    }

    func fillMeInsRemainingThisWeek() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: weekKey("fillmein"))
        return max(0, StoreManager.freeFillMeInsPerWeek - count)
    }

    // Profile Coach — Photos (weekly), Prompts/Bios/Openers (daily).
    func canUseProfilePhoto() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: weekKey("profile_photo"))
        return count < StoreManager.freeProfilePhotosPerWeek
    }
    func trackProfilePhotoUsed() {
        guard !isPro else { return }
        let key = weekKey("profile_photo")
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    func profilePhotosRemainingThisWeek() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: weekKey("profile_photo"))
        return max(0, StoreManager.freeProfilePhotosPerWeek - count)
    }

    func canUseProfilePrompt() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_prompt"))
        return count < StoreManager.freeProfilePromptsPerDay
    }
    func trackProfilePromptUsed() {
        guard !isPro else { return }
        let key = dayKey("profile_prompt")
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    func profilePromptsRemainingToday() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_prompt"))
        return max(0, StoreManager.freeProfilePromptsPerDay - count)
    }

    func canUseProfileBio() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_bio"))
        return count < StoreManager.freeProfileBiosPerDay
    }
    func trackProfileBioUsed() {
        guard !isPro else { return }
        let key = dayKey("profile_bio")
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    func profileBiosRemainingToday() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_bio"))
        return max(0, StoreManager.freeProfileBiosPerDay - count)
    }

    func canUseProfileOpener() -> Bool {
        if isPro { return true }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_opener"))
        return count < StoreManager.freeProfileOpenersPerDay
    }
    func trackProfileOpenerUsed() {
        guard !isPro else { return }
        let key = dayKey("profile_opener")
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: key) + 1, forKey: key)
    }
    func profileOpenersRemainingToday() -> Int {
        if isPro { return 999 }
        let count = UserDefaults.standard.integer(forKey: dayKey("profile_opener"))
        return max(0, StoreManager.freeProfileOpenersPerDay - count)
    }

    /// Annual savings vs paying 12× the monthly price — used by the paywall
    /// "Save X%" badge. Returns nil when either product is missing so the
    /// badge stays off until live pricing arrives.
    func annualSavingsPercent() -> Int? {
        guard
            let monthly = products.first(where: { $0.id == RowanProduct.monthlyPro.rawValue }),
            let annual  = products.first(where: { $0.id == RowanProduct.annualPro.rawValue })
        else { return nil }
        let twelveMonths = monthly.price * 12
        guard twelveMonths > 0 else { return nil }
        let saved = (twelveMonths - annual.price) / twelveMonths
        let pct = NSDecimalNumber(decimal: saved * 100).intValue
        return pct > 0 ? pct : nil
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @State private var store = StoreManager.shared
    @State private var selectedProduct: Product? = nil
    @State private var isPurchasing = false
    @State private var showSuccess = false
    @State private var showTerms = false
    @State private var on = false

    let reason: PaywallReason

    enum PaywallReason {
        case repliesLimit, debriefLimit, archiveLimit, simLimit, practiceLimit
        case fillMeInLimit, profilePhotoLimit, profilePromptLimit, profileBioLimit, profileOpenerLimit
        case generic, upgrade

        var headline: String {
            switch self {
            case .repliesLimit:  return "You've used your \(StoreManager.freeRepliesPerDay) free replies today."
            case .debriefLimit:  return "You've used your \(StoreManager.freeDebriefsPerMonth) free debriefs this month."
            case .archiveLimit:  return "You've reached the \(StoreManager.freeArchiveLimit)-connection free limit."
            case .simLimit:      return "You've used your \(StoreManager.freeSimSessionsPerWeek) free The Sim sessions this week."
            case .practiceLimit: return "Practice Mode is a Pro feature."
            case .fillMeInLimit: return "You've used your \(StoreManager.freeFillMeInsPerWeek) free Fill Me In analyses this week."
            case .profilePhotoLimit:  return "You've used your \(StoreManager.freeProfilePhotosPerWeek) free photo analyses this week."
            case .profilePromptLimit: return "You've used your \(StoreManager.freeProfilePromptsPerDay) free prompt generations today."
            case .profileBioLimit:    return "Bio Writer needs Pro after \(StoreManager.freeProfileBiosPerDay) generations a day."
            case .profileOpenerLimit: return "You've used your \(StoreManager.freeProfileOpenersPerDay) free opener generations today."
            case .generic, .upgrade: return "Unlock the full Rowan experience."
            }
        }

        var subheadline: String {
            switch self {
            case .repliesLimit:  return "Go Pro for unlimited Cyrano coaching — every day."
            case .debriefLimit:  return "Pro gives you unlimited Date Debriefs every month."
            case .archiveLimit:  return "Pro lets you track unlimited connections."
            case .simLimit:      return "Pro unlocks unlimited The Sim sessions, every avatar, and every environment."
            case .practiceLimit: return "Practice real scenarios with Cyrano as your partner."
            case .fillMeInLimit: return "Pro unlocks unlimited Fill Me In coaching, every week."
            case .profilePhotoLimit, .profilePromptLimit, .profileBioLimit, .profileOpenerLimit:
                                 return "Pro unlocks unlimited Profile Coach — photos, prompts, bios, and openers."
            case .generic, .upgrade: return "Everything you need to find, build, and keep great relationships."
            }
        }
    }

    // MARK: - Products
    //
    // Annual is the default after the paywall redesign — the in-paywall
    // monthly/annual toggle was removed in favour of a cleaner narrative
    // flow. Users who prefer monthly billing can switch via the App Store
    // subscription settings post-purchase.
    var monthly: Product? { store.products.first { $0.id == RowanProduct.monthlyPro.rawValue } }
    var annual: Product?  { store.products.first { $0.id == RowanProduct.annualPro.rawValue } }
    var proPlusMonthly: Product? { store.products.first { $0.id == RowanProduct.monthlyProPlus.rawValue } }
    var proPlusAnnual: Product?  { store.products.first { $0.id == RowanProduct.annualProPlus.rawValue } }

    /// Annual Pro — what the "Start 7-Day Free Trial" CTA buys.
    var proProduct: Product? { annual }
    /// Annual Pro+ — what the "Get Cyrano Live" CTA buys.
    var proPlusProduct: Product? { proPlusAnnual }

    @State private var purchasingProPlus = false

    // Pro+ uses a brand-distinct gold gradient on borders and badge fills.
    static let goldGradient = LinearGradient(
        colors: [Color(hex: "F4D03F"), Color(hex: "C0A020")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let proPlusNavy = Color(hex: "1B2B4B")

    var body: some View {
        ZStack {
            Color.rwBackground.ignoresSafeArea()

            if showSuccess {
                successView
            } else {
                mainView
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { on = true }
            // Kick off a load if the manager hasn't loaded yet — covers the
            // case where the paywall is the first thing the user opens.
            if store.products.isEmpty && store.loadState != .loading {
                store.retryLoad()
            }
        }
    }

    var mainView: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    hero
                        .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    momentCards
                        .opacity(on ? 1 : 0)
                    socialProof
                        .opacity(on ? 1 : 0)
                    tierCardsSection
                        .opacity(on ? 1 : 0)
                    trustRow
                        .opacity(on ? 1 : 0)
                    ctaButtons
                        .opacity(on ? 1 : 0)
                    legalFooter
                        .opacity(on ? 1 : 0)
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showTerms) { TermsSheet() }
    }

    // MARK: - Section 1 — Hero with timeline

    private var hero: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Try Rowan free for 7 days")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.rwTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Cancel anytime. No charge until day 8.")
                    .font(RWF.body(15))
                    .foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center)
            }
            timeline
                .padding(.top, 4)
        }
    }

    private var timeline: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                timelineDot(filled: true)
                timelineConnector
                timelineDot(filled: true)
                timelineConnector
                timelineDot(filled: false)
            }
            HStack(alignment: .top, spacing: 0) {
                timelineLabel(day: "Day 1", tag: "Free", alignment: .leading)
                timelineLabel(day: "Day 7", tag: "Reminder", alignment: .center)
                timelineLabel(day: "Day 8", tag: "First charge", alignment: .trailing)
            }
        }
        .padding(.horizontal, 4)
    }

    private func timelineDot(filled: Bool) -> some View {
        Group {
            if filled {
                Circle().fill(LinearGradient.accent)
            } else {
                Circle()
                    .fill(Color.rwBackground)
                    .overlay(Circle().stroke(LinearGradient.accent, lineWidth: 2))
            }
        }
        .frame(width: 14, height: 14)
    }

    private var timelineConnector: some View {
        Rectangle()
            .fill(LinearGradient.accent)
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }

    private func timelineLabel(day: String, tag: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(day).font(RWF.head(12)).foregroundColor(.rwTextPrimary)
            Text(tag).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
    }

    // MARK: - Section 2 — Moment cards (swipeable)

    private struct Moment: Identifiable {
        let id = UUID()
        let icon: String
        let headline: String
        let body: String
    }

    private var moments: [Moment] {
        [
            Moment(icon: "sparkles",
                   headline: "Cyrano reads between the lines",
                   body: "Drop a screenshot. Get a reply that actually works."),
            Moment(icon: "person.wave.2.fill",
                   headline: "Practice before the real thing",
                   body: "Real-time voice simulation. 5 personalities. No judgment."),
            Moment(icon: "chart.line.uptrend.xyaxis",
                   headline: "Watch yourself get better",
                   body: "6 dimensions. 0 to 1000. Actual measurable growth.")
        ]
    }

    private var momentCards: some View {
        TabView {
            ForEach(moments) { m in
                momentCard(m)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .frame(height: 240)
    }

    private func momentCard(_ m: Moment) -> some View {
        VStack(spacing: 14) {
            Image(systemName: m.icon)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text(m.headline)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.rwTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(m.body)
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(SP.lg)
        .padding(.bottom, 28)  // leave room for the dot indicators
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 3 — Social proof

    private var socialProof: some View {
        HStack(spacing: 8) {
            Text("★★★★★")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.rwAccent)
            Text("Loved by people who take connection seriously")
                .font(RWF.body(13))
                .foregroundColor(.rwTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 4 — Tier cards

    @ViewBuilder
    private var tierCardsSection: some View {
        if !store.products.isEmpty {
            VStack(spacing: 12) {
                freeTierCard
                proTierCard
                proPlusTierCard
            }
        } else {
            pricingFallback
        }
    }

    @ViewBuilder
    private var pricingFallback: some View {
        switch store.loadState {
        case .failed(let message):
            loadErrorCard(message: message)
        case .loading, .idle:
            VStack(spacing: 10) {
                SkeletonPricingCard()
                SkeletonPricingCard()
                SkeletonPricingCard()
            }
        case .loaded:
            loadErrorCard(message: "No subscriptions are currently available. If you've previously subscribed, try Restore Purchases.")
        }
    }

    private var freeTierCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Free")
                    .font(RWF.head(18))
                    .foregroundColor(.rwTextPrimary)
                Spacer()
                if !store.isPro {
                    Text("Current Plan")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                }
            }
            Text("$0")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.rwTextPrimary)
            VStack(alignment: .leading, spacing: 7) {
                limitRow("10 Cyrano replies/day")
                limitRow("2 The Sim sessions/week")
                limitRow("5 Archive connections")
                limitRow("Basic RI Score view")
            }
        }
        .padding(SP.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
    }

    private func limitRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "minus")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.rwTextMuted)
                .frame(width: 12)
            Text(text)
                .font(RWF.body(13))
                .foregroundColor(.rwTextSecondary)
        }
    }

    private var proTierCard: some View {
        let priceText = proProduct?.displayPrice ?? "—"
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pro")
                    .font(RWF.head(18))
                    .foregroundColor(.rwTextPrimary)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(priceText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.rwTextPrimary)
                    Text("/year")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    proFeatureRow("Unlimited Cyrano coaching")
                    proFeatureRow("All avatars · all environments")
                    proFeatureRow("Full RI Score with history")
                    proFeatureRow("Relationship Mode")
                }
            }
            .padding(SP.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(LinearGradient.accent, lineWidth: 2)
            )

            // "Most Popular" badge — top right.
            Text("Most Popular")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.rwAccent)
                .clipShape(Capsule())
                .offset(x: -16, y: 12)
        }
        .shadow(color: Color.rwShadow, radius: 10, x: 0, y: 3)
    }

    private func proFeatureRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
                .frame(width: 14)
            Text(text)
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var proPlusTierCard: some View {
        let priceText = proPlusProduct?.displayPrice ?? "—"
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Pro+")
                    .font(RWF.head(20))
                    .foregroundColor(.white)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(priceText)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/year")
                        .font(RWF.cap(12))
                        .foregroundColor(.white.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 8) {
                    proPlusFeatureRow("Everything in Pro")
                    proPlusFeatureRow("Cyrano Live — real-time AI in your earpiece")
                    proPlusFeatureRow("Priority Cyrano response speed")
                    proPlusFeatureRow("Early access to new features")
                }
            }
            // Slightly larger card than Pro per the spec.
            .padding(.horizontal, SP.lg)
            .padding(.vertical, SP.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.proPlusNavy)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(Self.goldGradient, lineWidth: 2)
            )

            // "Cyrano Live Included" gold badge — top right.
            HStack(spacing: 4) {
                Image(systemName: "headphones")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                Text("Cyrano Live Included")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(Self.proPlusNavy)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Self.goldGradient)
            .clipShape(Capsule())
            .offset(x: -16, y: 12)
        }
        .shadow(color: Self.proPlusNavy.opacity(0.18), radius: 14, x: 0, y: 4)
    }

    private func proPlusFeatureRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Self.goldGradient)
                .frame(width: 14)
            Text(text)
                .font(RWF.body(14))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Section 5 — Trust row

    private var trustRow: some View {
        HStack(spacing: 0) {
            trustItem(icon: "lock.fill", text: "Secure payment")
            Rectangle().fill(Color.rwBorder).frame(width: 1, height: 36)
            trustItem(icon: "arrow.uturn.left", text: "Cancel anytime")
            Rectangle().fill(Color.rwBorder).frame(width: 1, height: 36)
            trustItem(icon: "star.fill", text: "7 days free")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, SP.md)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
    }

    private func trustItem(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.rwTextSecondary)
            Text(text)
                .font(RWF.cap(11))
                .foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 6 — CTA buttons

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            // Pro CTA — gradient.
            Button {
                guard let product = proProduct else { return }
                purchasingProPlus = false
                Task { await beginPurchase(product) }
            } label: {
                Text(isPurchasing && !purchasingProPlus ? "Processing..." : "Start 7-Day Free Trial")
                    .font(RWF.head(15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
            .disabled(isPurchasing || proProduct == nil)
            .shadow(color: Color.rwAccent.opacity(0.32), radius: 18, x: 0, y: 8)

            // Pro+ CTA — navy + gold text.
            Button {
                guard let product = proPlusProduct else { return }
                purchasingProPlus = true
                Task { await beginPurchase(product) }
            } label: {
                Text(isPurchasing && purchasingProPlus ? "Processing..." : "Get Cyrano Live")
                    .font(RWF.head(15))
                    .foregroundStyle(Self.goldGradient)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Self.proPlusNavy)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
            .disabled(isPurchasing || proPlusProduct == nil)

            if !store.purchaseError.isEmpty {
                Text(store.purchaseError)
                    .font(RWF.cap())
                    .foregroundColor(.rwDanger)
            }

            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(.rwTextMuted)
            .padding(.top, 4)
        }
    }

    private func beginPurchase(_ product: Product) async {
        await MainActor.run { isPurchasing = true }
        let success = await store.purchase(product)
        await MainActor.run {
            isPurchasing = false
            if success { withAnimation { showSuccess = true } }
        }
    }

    // MARK: - Legal footer

    private var legalFooter: some View {
        VStack(spacing: 6) {
            Text("7-day free trial, then auto-renews. Cancel anytime in your Apple ID settings. No charges during trial.")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                Button("Terms of Service") { showTerms = true }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwTextMuted)
                Text("·")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwTextMuted)
                Button("Privacy Policy") { showTerms = true }
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
        }
    }

    // MARK: - Success / pricing fallback helpers

    var successView: some View {
        VStack(spacing: SP.xl) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("Welcome to Pro").font(RWF.display()).foregroundColor(.rwTextPrimary)
                Text("You now have unlimited access to everything Rowan has to offer.")
                    .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            Spacer()
            RWButton("Let's Go", icon: "arrow.right") { dismiss() }
                .padding(.horizontal, SP.xl).padding(.bottom, 60)
        }
    }

    private func loadErrorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text("Couldn't load pricing")
                .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
            Text(message)
                .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.retryLoad()
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(RWF.cap()).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
        .padding(SP.lg)
        .frame(maxWidth: .infinity)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Tier Card

/// One row in the three-tier paywall stack. Selectable, with optional badge,
/// recommended highlight, and current-plan indicator. Pure presentation —
/// purchase happens via the parent's CTA after `selectedProduct` is set.
struct TierCard: View {
    let title: String
    let price: String
    let perPeriod: String
    let badge: String?
    var badgeTint: Color = .rwAccent
    var badgeIcon: String? = nil
    let features: [String]
    var extraNote: String? = nil
    let isSelected: Bool
    var isCurrent: Bool = false
    let accent: Color
    var ctaLabel: String? = nil
    var disabled: Bool = false
    var recommended: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                priceRow
                featuresList
                if isCurrent {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("Current Plan")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.rwSuccess)
                }
            }
            .padding(SP.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? accent.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(borderOverlay)
            .shadow(color: Color.rwShadow,
                    radius: recommended ? 12 : 6, x: 0, y: 2)
        }
        .buttonStyle(SBS())
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1.0)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(RWF.head(17))
                .foregroundColor(.rwTextPrimary)
            if let badge = badge {
                HStack(spacing: 4) {
                    if let icon = badgeIcon {
                        Image(systemName: icon).font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    Text(badge).font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(badgeTint)
                .clipShape(Capsule())
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundColor(accent)
            }
        }
    }

    private var priceRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(price)
                .font(RWF.display(22))
                .foregroundColor(.rwTextPrimary)
            Text(perPeriod)
                .font(RWF.cap(11))
                .foregroundColor(.rwTextSecondary)
            if let note = extraNote {
                Spacer()
                Text(note)
                    .font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
            }
        }
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(features, id: \.self) { feature in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                        .frame(width: 12)
                    Text(feature)
                        .font(RWF.body(13))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if recommended || isSelected {
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient(colors: [accent, accent.opacity(0.55)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 2.5 : 1.5)
        } else {
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(Color.rwBorder, lineWidth: 1)
        }
    }
}

// MARK: - Skeleton + cached pricing cards

struct SkeletonPricingCard: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(Color.rwBorder).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder)
                    .frame(width: 90, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder.opacity(0.6))
                    .frame(width: 140, height: 10)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder)
                    .frame(width: 60, height: 14)
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder.opacity(0.6))
                    .frame(width: 40, height: 10)
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .opacity(pulse ? 0.55 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

struct CachedPricingCard: View {
    let info: CachedProductInfo
    var body: some View {
        HStack(spacing: 14) {
            Circle().stroke(Color.rwBorder, lineWidth: 2).frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(info.displayName).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                Text("Last seen pricing — refreshing…")
                    .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
            }
            Spacer()
            Text(info.displayPrice).font(RWF.head(18)).foregroundColor(.rwTextPrimary)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .opacity(0.85)
        .allowsHitTesting(false)
    }
}

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let perPeriod: String
    let monthlyEquiv: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Badge (or invisible spacer to keep columns the same height).
                Group {
                    if let badge = badge {
                        Text(badge).font(RWF.micro())
                            .foregroundStyle(LinearGradient.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.rwAccent.opacity(0.10))
                            .clipShape(Capsule())
                    } else {
                        Text(" ").font(RWF.micro())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .opacity(0)
                    }
                }

                Text(product.displayName).font(RWF.head(15)).foregroundColor(.rwTextPrimary)

                Text(product.displayPrice).font(RWF.head(20)).foregroundColor(.rwTextPrimary)
                Text(perPeriod).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)

                if let equiv = monthlyEquiv {
                    Text(equiv).font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                } else {
                    Text(" ").font(RWF.cap(11)).opacity(0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SP.md)
            .background(isSelected ? Color.rwAccent.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                .stroke(isSelected ? Color.rwAccent : Color.rwBorder,
                        lineWidth: isSelected ? 2 : 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Pro Gate Component

struct ProGate<Content: View>: View {
    let reason: PaywallView.PaywallReason
    let checkAccess: () -> Bool
    let content: Content
    @State private var showPaywall = false

    init(reason: PaywallView.PaywallReason, check: @escaping () -> Bool, @ViewBuilder content: () -> Content) {
        self.reason = reason
        self.checkAccess = check
        self.content = content()
    }

    var body: some View {
        if checkAccess() {
            content
        } else {
            Button { showPaywall = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    Text("Unlock with Pro")
                        .font(RWF.med()).foregroundColor(.rwTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                }
                .padding(SP.md).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            }
            .buttonStyle(SBS())
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: reason)
            }
        }
    }
}
