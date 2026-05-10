import SwiftUI
import CoreLocation
import MapKit

// MARK: - Date Setup Context
// What we know about the date once "Set the Scene" finishes. All fields are
// optional so the user can skip steps. Persisted via DatePlannerStore.

struct DateSetupContext: Codable, Equatable {
    var personId: String?       // Archive contact id, if picked
    var personName: String      // typed-name path or contact name
    var occasion: Occasion?
    var vibes: [Vibe]
    var location: LocationChoice?
    var budget: Budget?

    var isMinimallySet: Bool {
        occasion != nil || !vibes.isEmpty || location != nil || budget != nil
    }

    enum Occasion: String, Codable, CaseIterable, Identifiable {
        case firstDate     = "First Date"
        case secondDate    = "Second Date"
        case casual        = "Casual Hangout"
        case anniversary   = "Anniversary"
        case makeUp        = "Make Up Date"
        case adventure     = "Adventure Date"
        case stayIn        = "Stay In"
        case doubleDate    = "Double Date"
        case surprise      = "Surprise Date"
        case special       = "Special Occasion"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .firstDate:   return "sparkles"
            case .secondDate:  return "arrow.triangle.2.circlepath"
            case .casual:      return "cup.and.saucer.fill"
            case .anniversary: return "heart.fill"
            case .makeUp:      return "bandage.fill"
            case .adventure:   return "figure.hiking"
            case .stayIn:      return "house.fill"
            case .doubleDate:  return "person.2.fill"
            case .surprise:    return "gift.fill"
            case .special:     return "star.fill"
            }
        }
    }

    enum Vibe: String, Codable, CaseIterable, Identifiable {
        case romantic    = "Romantic"
        case adventurous = "Adventurous"
        case relaxed     = "Relaxed"
        case exciting    = "Exciting"
        case intimate    = "Intimate"
        case fun         = "Fun"
        case classy      = "Classy"
        case creative    = "Creative"
        case cozy        = "Cozy"
        case spontaneous = "Spontaneous"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .romantic:    return "heart.fill"
            case .adventurous: return "mountain.2.fill"
            case .relaxed:     return "leaf.fill"
            case .exciting:    return "bolt.fill"
            case .intimate:    return "moon.stars.fill"
            case .fun:         return "party.popper.fill"
            case .classy:      return "wineglass.fill"
            case .creative:    return "paintpalette.fill"
            case .cozy:        return "flame.fill"
            case .spontaneous: return "wand.and.sparkles"
            }
        }
    }

    enum Budget: String, Codable, CaseIterable, Identifiable {
        case free   = "$"
        case mid    = "$$"
        case nice   = "$$$"
        case lavish = "$$$$"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .free:   return "Free or cheap"
            case .mid:    return "Moderate"
            case .nice:   return "Nice out"
            case .lavish: return "Special occasion"
            }
        }

        var range: String {
            switch self {
            case .free:   return "Under $20"
            case .mid:    return "$20–60"
            case .nice:   return "$60–150"
            case .lavish: return "$150+"
            }
        }
    }

    enum LocationChoice: Codable, Equatable {
        case nearMe
        case midpoint(contactName: String, latitude: Double, longitude: Double)
        case area(title: String, subtitle: String?, latitude: Double, longitude: Double)

        var summary: String {
            switch self {
            case .nearMe: return "Near me"
            case .midpoint(let name, _, _): return "Midpoint with \(name)"
            case .area(let title, _, _, _): return title
            }
        }

        var coordinate: CLLocationCoordinate2D? {
            switch self {
            case .nearMe: return nil
            case .midpoint(_, let lat, let lng): return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            case .area(_, _, let lat, let lng): return CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
        }
    }

    var summaryPills: [String] {
        var out: [String] = []
        if !personName.isEmpty { out.append(personName) }
        if let o = occasion { out.append(o.rawValue) }
        if let first = vibes.first {
            if vibes.count == 1 {
                out.append(first.rawValue)
            } else {
                out.append("\(first.rawValue) +\(vibes.count - 1)")
            }
        }
        if let loc = location { out.append(loc.summary) }
        if let b = budget { out.append(b.rawValue) }
        return out
    }

    /// Plain-text summary used in the Cyrano prompt.
    func promptDescription() -> String {
        var parts: [String] = []
        if !personName.isEmpty { parts.append("for \(personName)") }
        if let o = occasion { parts.append("a \(o.rawValue)") }
        if !vibes.isEmpty { parts.append("\(vibes.map { $0.rawValue.lowercased() }.joined(separator: ", ")) vibe") }
        if let loc = location { parts.append("near \(loc.summary)") }
        if let b = budget { parts.append("\(b.rawValue) (\(b.range))") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Planner Store
// Holds the active date setup context and the "force setup" flag triggered
// by the New Date button.

@MainActor
@Observable
final class DatePlannerStore {
    static let shared = DatePlannerStore()

    var context: DateSetupContext?
    var forceSetup: Bool = false  // tap "New Date" → restart setup even if context exists

    /// Search radius in miles. Persisted independently of context so changing
    /// it during a session sticks across launches even without a full Scene.
    /// nil sentinel means "not yet stored" — DistanceFilter.stored falls back
    /// to UserDefaults during the v1→v2 migration, then defaults to 10 mi.
    private(set) var radius: DistanceFilter?

    private static let contextKey = "datePlanner.context.v1"
    private static let radiusKey  = "datePlanner.radiusMiles.v1"

    private init() { load() }

    func setContext(_ ctx: DateSetupContext) {
        context = ctx
        forceSetup = false
        save()
    }

    func clearContext() {
        context = nil
        save()
    }

    func startNewDate() {
        clearContext()
        forceSetup = true
    }

    func setRadius(_ value: DistanceFilter) {
        radius = value
        UserDefaults.standard.set(value.rawValue, forKey: Self.radiusKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.contextKey),
           let stored = try? JSONDecoder().decode(DateSetupContext.self, from: data) {
            context = stored
        }
        let savedRadius = UserDefaults.standard.double(forKey: Self.radiusKey)
        if savedRadius > 0, let r = DistanceFilter(rawValue: savedRadius) {
            radius = r
        }
    }

    private func save() {
        if let context, let data = try? JSONEncoder().encode(context) {
            UserDefaults.standard.set(data, forKey: Self.contextKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.contextKey)
        }
    }
}

// MARK: - Date Setup View
// Five-step "Set the Scene" flow. Each step has a Skip button. Final step
// commits the context and dismisses.

struct DateSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let userCoordinate: CLLocationCoordinate2D?
    var onFinish: (DateSetupContext) -> Void

    @State private var step: Step = .who
    @State private var draft = DateSetupContext(personId: nil, personName: "", occasion: nil, vibes: [], location: nil, budget: nil)

    enum Step: Int, CaseIterable {
        case who = 0, occasion = 1, vibe = 2, location = 3, budget = 4

        var title: String {
            switch self {
            case .who:      return "Who's the date with?"
            case .occasion: return "What kind of date?"
            case .vibe:     return "What's the vibe?"
            case .location: return "Where?"
            case .budget:   return "Budget?"
            }
        }

        var subtitle: String {
            switch self {
            case .who:      return "Pick a connection or skip if you're just exploring."
            case .occasion: return "Helps Cyrano pick the right kind of place."
            case .vibe:     return "Pick as many as feel right."
            case .location: return "Where should we look?"
            case .budget:   return "Set the spend so picks make sense."
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressBar
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SP.lg) {
                        header
                        stepBody
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, SP.lg)
                    .padding(.top, SP.md)
                    .padding(.bottom, 100)
                }
                .rwBG()
                footerBar
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Set the Scene")
                        .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .font(RWF.cap(13))
                        .foregroundColor(.rwTextSecondary)
                }
            }
        }
    }

    // MARK: progress

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(step.rawValue >= s.rawValue
                          ? AnyShapeStyle(LinearGradient.accent)
                          : AnyShapeStyle(Color.rwBorder))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, SP.lg)
        .padding(.top, 4)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: step)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STEP \(step.rawValue + 1) OF 5")
                .font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text(step.title)
                .font(RWF.title(24))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.subtitle)
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: step body

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .who:      WhoStep(draft: $draft)
        case .occasion: OccasionStep(draft: $draft)
        case .vibe:     VibeStep(draft: $draft)
        case .location: LocationStep(draft: $draft, userCoordinate: userCoordinate)
        case .budget:   BudgetStep(draft: $draft)
        }
    }

    // MARK: footer

    private var footerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if step != .who {
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            step = Step(rawValue: step.rawValue - 1) ?? .who
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.rwTextSecondary)
                            .frame(width: 48, height: 48)
                            .background(Color.rwSurface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }

                RWButton(step == .budget ? "Let's Go" : "Continue",
                         icon: step == .budget ? "sparkles" : "arrow.right") {
                    advance()
                }
            }

            Button("Skip this step") { advance() }
                .font(RWF.cap(12))
                .foregroundColor(.rwTextMuted)
        }
        .padding(.horizontal, SP.lg)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(colors: [Color.rwBackground.opacity(0), Color.rwBackground],
                           startPoint: .top, endPoint: .center)
                .frame(height: 24)
                .offset(y: -24),
            alignment: .top
        )
        .background(Color.rwBackground)
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step == .budget {
            onFinish(draft)
            dismiss()
            return
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            step = Step(rawValue: step.rawValue + 1) ?? step
        }
    }
}

// MARK: - Step 1: Who

private struct WhoStep: View {
    @Binding var draft: DateSetupContext
    @State private var showTypeName = false
    @State private var typedName = ""
    @State private var archive = ArchiveStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: SP.md) {
            modeRow(
                icon: "magnifyingglass",
                title: "Just exploring",
                subtitle: "Skip and browse without a date in mind",
                selected: draft.personId == nil && draft.personName.isEmpty && !showTypeName
            ) {
                draft.personId = nil
                draft.personName = ""
                showTypeName = false
            }

            modeRow(
                icon: "person.fill.badge.plus",
                title: showTypeName ? "Someone new" : "Someone new",
                subtitle: showTypeName ? "Type their name" : "Type a name manually",
                selected: showTypeName
            ) {
                showTypeName = true
                draft.personId = nil
                draft.personName = typedName
            }

            if showTypeName {
                TextField("Their name…", text: $typedName)
                    .font(RWF.body())
                    .foregroundColor(.rwTextPrimary)
                    .padding(SP.md)
                    .background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
                    .onChange(of: typedName) { _, new in
                        draft.personName = new
                    }
                    .padding(.leading, SP.md)
            }

            if !archive.active.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    RWSectionLabel("FROM YOUR ARCHIVE")
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(archive.active) { person in
                            contactCard(person)
                        }
                    }
                }
            }
        }
    }

    private func modeRow(icon: String, title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : .rwAccent)
                    .frame(width: 44, height: 44)
                    .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwAccent.opacity(0.10)))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(subtitle).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                }

                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LinearGradient.accent)
                        .font(.system(size: 18, design: .rounded))
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(selected ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1)
            )
        }
        .buttonStyle(SBS())
    }

    private func contactCard(_ person: Person) -> some View {
        let isSelected = draft.personId == person.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            draft.personId = person.id
            draft.personName = person.name
            showTypeName = false
        } label: {
            VStack(spacing: 8) {
                ContactAvatar(person: person, size: 52)
                Text(person.name)
                    .font(RWF.cap(13))
                    .foregroundColor(.rwTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(SP.md)
            .background(isSelected ? Color.rwAccent.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(
                RoundedRectangle(cornerRadius: RR.lg)
                    .stroke(isSelected ? Color.rwAccent : Color.rwBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Step 2: Occasion

private struct OccasionStep: View {
    @Binding var draft: DateSetupContext

    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(DateSetupContext.Occasion.allCases) { o in
                card(o)
            }
        }
    }

    private func card(_ o: DateSetupContext.Occasion) -> some View {
        let selected = draft.occasion == o
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                draft.occasion = o
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: o.icon)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : .rwAccent)
                    .frame(width: 36, height: 36)
                    .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwAccent.opacity(0.10)))
                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                Text(o.rawValue)
                    .font(RWF.head(14))
                    .foregroundColor(.rwTextPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(
                RoundedRectangle(cornerRadius: RR.lg)
                    .stroke(selected ? Color.rwAccent : Color.rwBorder, lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: selected ? Color.rwAccent.opacity(0.15) : Color.clear, radius: 10, x: 0, y: 4)
            .scaleEffect(selected ? 1.02 : 1.0)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Step 3: Vibe (multi-select)

private struct VibeStep: View {
    @Binding var draft: DateSetupContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RWFlowLayout(spacing: 8) {
                ForEach(DateSetupContext.Vibe.allCases) { vibe in
                    chip(vibe)
                }
            }
            if !draft.vibes.isEmpty {
                Text("\(draft.vibes.count) selected")
                    .font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
            }
        }
    }

    private func chip(_ vibe: DateSetupContext.Vibe) -> some View {
        let on = draft.vibes.contains(vibe)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25)) {
                if on {
                    draft.vibes.removeAll { $0 == vibe }
                } else {
                    draft.vibes.append(vibe)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: vibe.icon)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                Text(vibe.rawValue).font(RWF.cap(13))
            }
            .foregroundColor(on ? .white : .rwTextPrimary)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(on ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwCard))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : Color.rwBorder, lineWidth: 1))
            .shadow(color: on ? Color.rwAccent.opacity(0.30) : Color.clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Step 4: Location

private struct LocationStep: View {
    @Binding var draft: DateSetupContext
    let userCoordinate: CLLocationCoordinate2D?

    @State private var showMidpoint = false
    @State private var showSearch = false
    @State private var completer = LocationSearchCompleter()
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            optionRow(
                icon: "location.fill",
                title: "Near Me",
                subtitle: userCoordinate == nil ? "We'll ask permission first" : "Use your current location",
                selected: draft.location == .nearMe
            ) {
                draft.location = .nearMe
            }

            optionRow(
                icon: "person.line.dotted.person.fill",
                title: "Meet in the Middle",
                subtitle: midpointSubtitle,
                selected: isMidpoint
            ) {
                showMidpoint = true
            }

            optionRow(
                icon: "magnifyingglass",
                title: "Search a Location",
                subtitle: searchSubtitle,
                selected: isArea
            ) {
                showSearch = true
            }

            if showSearch {
                searchInline.transition(.opacity)
            }

            // Once a location is locked in, surface the radius picker so the
            // user sets it as part of the same step.
            if draft.location != nil {
                radiusPicker
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: draft.location)
        .sheet(isPresented: $showMidpoint) {
            MidpointPickerView(userCoordinate: userCoordinate) { resolved in
                if case .midpoint(let name) = resolved.kind {
                    draft.location = .midpoint(
                        contactName: name,
                        latitude: resolved.coordinate.latitude,
                        longitude: resolved.coordinate.longitude)
                } else {
                    draft.location = .area(
                        title: resolved.title,
                        subtitle: resolved.subtitle,
                        latitude: resolved.coordinate.latitude,
                        longitude: resolved.coordinate.longitude)
                }
            }
        }
    }

    private var isMidpoint: Bool {
        if case .midpoint = draft.location { return true }
        return false
    }
    private var isArea: Bool {
        if case .area = draft.location { return true }
        return false
    }

    private var midpointSubtitle: String {
        if case .midpoint(let name, _, _) = draft.location { return "Halfway with \(name)" }
        return "Halfway with a contact"
    }
    private var searchSubtitle: String {
        if case .area(let title, _, _, _) = draft.location { return title }
        return "Type any city or area"
    }

    private var searchInline: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.rwTextMuted)
                TextField("City or area…", text: $query)
                    .focused($queryFocused)
                    .font(RWF.body(14))
                    .foregroundColor(.rwTextPrimary)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, new in
                        completer.query = new
                    }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.rwSurface)
            .clipShape(RoundedRectangle(cornerRadius: RR.md))
            .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))

            if !completer.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(completer.suggestions.prefix(4).enumerated()), id: \.offset) { idx, completion in
                        Button {
                            Task {
                                if let resolved = await completer.resolve(completion) {
                                    draft.location = .area(
                                        title: resolved.title,
                                        subtitle: resolved.subtitle.isEmpty ? nil : resolved.subtitle,
                                        latitude: resolved.coordinate.latitude,
                                        longitude: resolved.coordinate.longitude)
                                    completer.clear()
                                    queryFocused = false
                                    query = resolved.title
                                }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.rwAccent)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(RWF.body(14))
                                        .foregroundColor(.rwTextPrimary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(RWF.cap(11))
                                            .foregroundColor(.rwTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        }
                        .buttonStyle(SBS())
                        if idx < min(3, completer.suggestions.count - 1) {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.md))
                .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
            }
        }
        .padding(.top, 4)
    }

    // Inline radius selector — same options as the Date Planner filter bar.
    // Reads/writes DistanceFilter.stored so the choice carries straight into
    // Explore + AI Picks once setup completes.
    private var radiusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("HOW FAR ARE YOU WILLING TO GO?")
                    .font(RWF.micro())
                    .foregroundColor(.rwTextMuted)
                    .tracking(1.4)
            }
            HStack(spacing: 6) {
                ForEach(DistanceFilter.allCases) { d in
                    let on = DistanceFilter.stored == d
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            d.persist()
                        }
                    } label: {
                        Text(d.label)
                            .font(RWF.cap(12))
                            .foregroundColor(on ? .white : .rwTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(on ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwSurface))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : Color.rwBorder, lineWidth: 1))
                            .shadow(color: on ? Color.rwAccent.opacity(0.30) : .clear,
                                    radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(SBS())
                }
            }
        }
    }

    private func optionRow(icon: String, title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(selected ? .white : .rwAccent)
                    .frame(width: 44, height: 44)
                    .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwAccent.opacity(0.10)))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(subtitle).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(selected ? Color.rwAccent : Color.rwBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Step 5: Budget

private struct BudgetStep: View {
    @Binding var draft: DateSetupContext

    var body: some View {
        VStack(spacing: 10) {
            ForEach(DateSetupContext.Budget.allCases) { b in
                row(b)
            }
        }
    }

    private func row(_ b: DateSetupContext.Budget) -> some View {
        let selected = draft.budget == b
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                draft.budget = b
            }
        } label: {
            HStack(spacing: 14) {
                Text(b.rawValue)
                    .font(RWF.title(20))
                    .foregroundColor(selected ? .white : .rwAccent)
                    .frame(width: 56, height: 44)
                    .background(selected ? AnyShapeStyle(LinearGradient.accent) : AnyShapeStyle(Color.rwAccent.opacity(0.10)))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))

                VStack(alignment: .leading, spacing: 2) {
                    Text(b.label).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(b.range).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LinearGradient.accent)
                        .font(.system(size: 18, design: .rounded))
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(selected ? Color.rwAccent : Color.rwBorder, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Flow Layout
// Wraps chips across multiple lines. Used by VibeStep.

struct RWFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(in: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? rows.map { $0.width }.max() ?? 0,
                      height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(in: bounds.width, subviews: subviews)
        var y: CGFloat = bounds.minY
        var index = 0
        for row in rows {
            var x: CGFloat = bounds.minX
            for size in row.sizes {
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(in width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            let projected = current.width + size.width + (current.sizes.isEmpty ? 0 : spacing)
            if projected > width && !current.sizes.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.sizes.append(size)
            current.width += size.width + (current.sizes.count == 1 ? 0 : spacing)
            current.height = max(current.height, size.height)
        }
        if !current.sizes.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Context Header Bar
// Pinned strip that shows the active setup context as pills, with a "Change"
// affordance. Rendered above the planner tabs.

struct DateContextHeaderBar: View {
    let context: DateSetupContext
    let onChange: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("THE SCENE")
                    .font(RWF.micro())
                    .foregroundColor(.rwTextMuted)
                    .tracking(1.4)
                Spacer()
                Button(action: onChange) {
                    Text("Change")
                        .font(RWF.cap(12))
                        .foregroundStyle(LinearGradient.accent)
                }
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                        .frame(width: 22, height: 22)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(context.summaryPills, id: \.self) { pill in
                        Text(pill)
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextPrimary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(LinearGradient.accentSoft)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.rwAccent.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, SP.lg)
        .padding(.vertical, 10)
        .background(Color.rwCard)
        .overlay(Rectangle().fill(Color.rwBorder).frame(height: 1), alignment: .bottom)
    }
}
