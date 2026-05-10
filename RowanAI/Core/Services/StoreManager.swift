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
            case .simLimit:      return "You've used your \(StoreManager.freeSimSessionsPerWeek) free Face to Face sessions this week."
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
            case .simLimit:      return "Pro unlocks unlimited Face to Face Sim sessions, every avatar, and every environment."
            case .practiceLimit: return "Practice real scenarios with Cyrano as your partner."
            case .fillMeInLimit: return "Pro unlocks unlimited Fill Me In coaching, every week."
            case .profilePhotoLimit, .profilePromptLimit, .profileBioLimit, .profileOpenerLimit:
                                 return "Pro unlocks unlimited Profile Coach — photos, prompts, bios, and openers."
            case .generic, .upgrade: return "Everything you need to find, build, and keep great relationships."
            }
        }
    }

    let proFeatures: [(String, String)] = [
        ("bubble.left.and.bubble.right.fill", "Unlimited Cyrano replies — every day"),
        ("doc.text.magnifyingglass",          "Unlimited Date Debriefs"),
        ("person.2.fill",                     "Archive unlimited connections"),
        ("graduationcap.fill",                "Full Conversation Coach — all scenarios"),
        ("book.fill",                         "All lesson categories unlocked"),
        ("bolt.fill",                         "Challenge Mode with AI scoring"),
        ("bell.badge.fill",                   "Smart match reminders"),
        ("chart.xyaxis.line",                 "Weekly progress insights"),
        ("heart.fill",                        "Relationship — couples coaching tools"),
    ]

    var monthly: Product? { store.products.first { $0.id == RowanProduct.monthlyPro.rawValue } }
    var annual: Product?  { store.products.first { $0.id == RowanProduct.annualPro.rawValue } }
    var proPlusMonthly: Product? { store.products.first { $0.id == RowanProduct.monthlyProPlus.rawValue } }
    var proPlusAnnual: Product?  { store.products.first { $0.id == RowanProduct.annualProPlus.rawValue } }

    @State private var billingCycle: PaywallBilling = .annual

    enum PaywallBilling { case monthly, annual }

    /// The Pro product matching the currently-selected billing cycle.
    var selectedProByCycle: Product? {
        billingCycle == .annual ? annual : monthly
    }
    /// The Pro+ product matching the currently-selected billing cycle.
    var selectedProPlusByCycle: Product? {
        billingCycle == .annual ? proPlusAnnual : proPlusMonthly
    }

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
            if let annual = annual { selectedProduct = annual }
            // Kick off a load if the manager hasn't loaded yet — covers the
            // case where the paywall is the first thing the user opens.
            if store.products.isEmpty && store.loadState != .loading {
                store.retryLoad()
            }
        }
        // When products land after onAppear, default the selection to annual.
        .onChange(of: store.products.count) { _, _ in
            if selectedProduct == nil, let annual = annual {
                selectedProduct = annual
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
                VStack(spacing: SP.xl) {

                    // 7-day free trial callout — pinned at the very top.
                    trialCallout
                        .opacity(on ? 1 : 0).offset(y: on ? 0 : -6)

                    // Header — primary trial pitch on top, reason-specific
                    // copy underneath as supporting context.
                    VStack(spacing: 12) {
                        RowanLogo(size: 52)
                            .scaleEffect(on ? 1 : 0.5).opacity(on ? 1 : 0)

                        VStack(spacing: 6) {
                            Text("Try any plan free for 7 days")
                                .font(RWF.display(28))
                                .foregroundStyle(LinearGradient.accent)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(reason.headline)
                                .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(reason.subheadline)
                                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)
                    }

                    // Features
                    VStack(spacing: 10) {
                        ForEach(proFeatures, id: \.0) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.0)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(LinearGradient.accent)
                                    .frame(width: 28)
                                Text(feature.1).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                Spacer()
                            }
                        }
                    }
                    .padding(SP.lg).background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .opacity(on ? 1 : 0)

                    // Pricing options — side-by-side annual + monthly with
                    // skeleton / cached / error fallbacks.
                    pricingSection
                        .opacity(on ? 1 : 0)

                    // CTA
                    VStack(spacing: 12) {
                        RWButton(isPurchasing ? "Processing..." : "Start 7-Day Free Trial") {
                            guard let product = selectedProduct else { return }
                            isPurchasing = true
                            Task {
                                let success = await store.purchase(product)
                                isPurchasing = false
                                if success { withAnimation { showSuccess = true } }
                            }
                        }
                        .disabled(isPurchasing || selectedProduct == nil)

                        if !store.purchaseError.isEmpty {
                            Text(store.purchaseError).font(RWF.cap()).foregroundColor(.rwDanger)
                        }

                        Text("7-day free trial, then auto-renews. Cancel anytime in your Apple ID settings. No charges during trial.")
                            .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(on ? 1 : 0)

                    // Restore + legal — pinned at the very bottom per Apple
                    // submission guidance (Restore visible, Terms + Privacy
                    // links reachable from the paywall).
                    VStack(spacing: 10) {
                        Button("Restore Purchases") {
                            Task { await store.restore() }
                        }
                        .font(RWF.cap()).foregroundColor(.rwTextSecondary)

                        HStack(spacing: 14) {
                            Button("Terms of Service") { showTerms = true }
                                .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                            Text("·").font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                            Button("Privacy Policy") { showTerms = true }
                                .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted)
                        }
                    }
                    .opacity(on ? 1 : 0)

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, SP.lg)
            }
        }
        .sheet(isPresented: $showTerms) { TermsSheet() }
    }

    private var trialCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("7-day free trial").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Text("Try every Pro feature. Cancel anytime, no charge.")
                    .font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, SP.md).padding(.vertical, 10)
        .background(Color.rwAccent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
    }

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

    func perMonth(_ product: Product) -> String {
        let price = product.price / 12
        return "\(product.priceFormatStyle.format(price))/mo"
    }

    // MARK: - Pricing section state machine

    @ViewBuilder
    private var pricingSection: some View {
        if !store.products.isEmpty {
            VStack(spacing: 12) {
                billingToggle
                tierCardStack
            }
        } else {
            // No live products yet — pick the right fallback for the state.
            switch store.loadState {
            case .failed(let message):
                loadErrorCard(message: message)
            case .loading, .idle:
                let cached = store.cachedProducts()
                if cached.isEmpty {
                    VStack(spacing: 10) {
                        SkeletonPricingCard()
                        SkeletonPricingCard()
                        SkeletonPricingCard()
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(cached, id: \.id) { info in
                            CachedPricingCard(info: info)
                        }
                        Text("Refreshing pricing from the App Store…")
                            .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
            case .loaded:
                // Loaded but the store returned nothing — most often a config
                // mismatch (product IDs not yet approved in App Store Connect).
                loadErrorCard(message: "No subscriptions are currently available. If you've previously subscribed, try Restore Purchases.")
            }
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

    // MARK: - Three-tier pricing UI

    /// Top-of-section monthly/annual toggle. Annual is selected by default;
    /// the active option is filled with the accent gradient.
    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingPill(label: "Monthly", cycle: .monthly)
            billingPill(label: "Annual", cycle: .annual, badge: store.annualSavingsPercent().map { "Save \($0)%" })
        }
        .padding(4)
        .background(Color.rwSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
    }

    private func billingPill(label: String, cycle: PaywallBilling, badge: String? = nil) -> some View {
        let isSelected = billingCycle == cycle
        return Button {
            withAnimation(.spring(response: 0.3)) {
                billingCycle = cycle
                // Move the selection over to the new cycle so the CTA buys
                // the right SKU. Default the tier to whatever was already
                // selected — Pro by default if nothing chosen yet.
                if isProPlusSelected, let p = selectedProPlusByCycle {
                    selectedProduct = p
                } else if let p = selectedProByCycle {
                    selectedProduct = p
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(label).font(RWF.med(13))
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(isSelected
                                    ? Color.white.opacity(0.22)
                                    : Color.rwAccent.opacity(0.15))
                        .foregroundColor(isSelected ? .white : .rwAccent)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : .rwTextSecondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        LinearGradient.accent
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(Capsule())
        }
        .buttonStyle(SBS())
    }

    /// Three stacked tier cards: Free / Pro (recommended) / Pro+.
    private var tierCardStack: some View {
        VStack(spacing: 10) {
            freeTierCard
            proTierCard
            proPlusTierCard
        }
    }

    /// Whether the user has selected the Pro+ row (used by the toggle to
    /// choose which product to flip to when the cycle changes).
    private var isProPlusSelected: Bool {
        guard let id = selectedProduct?.id else { return false }
        return id == RowanProduct.monthlyProPlus.rawValue || id == RowanProduct.annualProPlus.rawValue
    }

    private var freeTierCard: some View {
        TierCard(
            title: "Free",
            price: "$0",
            perPeriod: "forever",
            badge: store.isPro ? nil : "Current Plan",
            badgeTint: .rwTextMuted,
            features: [
                "10 Cyrano replies/day",
                "2 Sim sessions/week",
                "5 Archive connections",
                "Basic RI Score view"
            ],
            isSelected: false,
            isCurrent: !store.isPro,
            accent: .rwTextMuted,
            ctaLabel: nil,
            disabled: true,
            onTap: {}
        )
    }

    private var proTierCard: some View {
        let product = selectedProByCycle
        let priceText = product?.displayPrice ?? "—"
        let perPeriod = billingCycle == .annual ? "per year" : "per month"
        let monthlyEquivText: String? = billingCycle == .annual && product != nil
            ? perMonth(product!) : nil

        return TierCard(
            title: "Pro",
            price: priceText,
            perPeriod: perPeriod,
            badge: "Most Popular",
            badgeTint: .rwAccent,
            features: [
                "Unlimited Cyrano coaching",
                "All 6 avatars · all environments",
                "Full RI Score with history",
                "Relationship Mode",
                "iMessage extension full access"
            ],
            extraNote: monthlyEquivText,
            isSelected: !isProPlusSelected && selectedProduct?.id == product?.id,
            isCurrent: store.isPro && !store.isProPlus,
            accent: .rwAccent,
            ctaLabel: nil,
            disabled: product == nil,
            recommended: true,
            onTap: {
                if let product = product { selectedProduct = product }
            }
        )
    }

    private var proPlusTierCard: some View {
        let product = selectedProPlusByCycle
        let priceText = product?.displayPrice ?? "—"
        let perPeriod = billingCycle == .annual ? "per year" : "per month"
        let monthlyEquivText: String? = billingCycle == .annual && product != nil
            ? perMonth(product!) : nil

        return TierCard(
            title: "Pro+",
            price: priceText,
            perPeriod: perPeriod,
            badge: "Includes Cyrano Live",
            badgeTint: .rwAccent,
            badgeIcon: "headphones",
            features: [
                "Everything in Pro",
                "Cyrano Live — real-time AI in your earpiece",
                "Priority Cyrano response speed",
                "Early access to new features"
            ],
            extraNote: monthlyEquivText,
            isSelected: isProPlusSelected && selectedProduct?.id == product?.id,
            isCurrent: store.isProPlus,
            accent: Color(hex: "C0A020"),
            ctaLabel: nil,
            disabled: product == nil,
            onTap: {
                if let product = product { selectedProduct = product }
            }
        )
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
