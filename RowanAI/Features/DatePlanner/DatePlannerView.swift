import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Venue Models

struct Venue: Identifiable, Codable {
    var id = UUID().uuidString
    var name = ""
    var category: VenueCategory = .restaurant
    var address = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var notes = ""
    var savedAt = Date()
    var isVisited = false
    var visitedAt: Date? = nil
    var dateRating = 0
    var personId: String? = nil
    var personName = ""

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum VenueCategory: String, Codable, CaseIterable {
    case restaurant = "Restaurant"
    case bar        = "Bar"
    case cafe       = "Coffee Shop"
    case park       = "Park"
    case activity   = "Activity"
    case museum     = "Museum"
    case rooftop    = "Rooftop"
    case beach      = "Beach"
    case other      = "Other"

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .bar:        return "wineglass.fill"
        case .cafe:       return "cup.and.saucer.fill"
        case .park:       return "leaf.fill"
        case .activity:   return "figure.2.arms.open"
        case .museum:     return "building.columns.fill"
        case .rooftop:    return "building.2.fill"
        case .beach:      return "beach.umbrella.fill"
        case .other:      return "mappin.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .restaurant: return Color(hex: "E8356D")
        case .bar:        return Color(hex: "5B8DEF")
        case .cafe:       return Color(hex: "8B5E3C")
        case .park:       return Color(hex: "00BFB3")
        case .activity:   return Color(hex: "F59E0B")
        case .museum:     return Color(hex: "9B59B6")
        case .rooftop:    return Color(hex: "E8356D")
        case .beach:      return Color(hex: "00BFB3")
        case .other:      return Color(hex: "9BA8BF")
        }
    }

    var searchTerm: String {
        switch self {
        case .restaurant: return "restaurant"
        case .bar:        return "bar cocktails"
        case .cafe:       return "coffee shop cafe"
        case .park:       return "park"
        case .activity:   return "entertainment activities"
        case .museum:     return "museum gallery"
        case .rooftop:    return "rooftop bar"
        case .beach:      return "beach"
        case .other:      return "point of interest"
        }
    }
}

// MARK: - Wishlist Store

@Observable
class WishlistStore {
    static let shared = WishlistStore()
    var venues: [Venue] = []
    private let key = "wishlist_v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([Venue].self, from: data) else { return }
        venues = stored
    }

    func save() {
        if let data = try? JSONEncoder().encode(venues) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ venue: Venue) {
        guard !venues.contains(where: { $0.name == venue.name && $0.address == venue.address }) else { return }
        venues.insert(venue, at: 0)
        save()
    }

    func update(_ venue: Venue) {
        if let i = venues.firstIndex(where: { $0.id == venue.id }) {
            venues[i] = venue; save()
        }
    }

    func remove(_ venue: Venue) {
        venues.removeAll { $0.id == venue.id }
        save()
    }

    func removeBy(name: String, address: String) {
        venues.removeAll { $0.name == name && $0.address == address }
        save()
    }

    func isWishlisted(_ name: String, address: String) -> Bool {
        venues.contains { $0.name == name && $0.address == address }
    }

    var unvisited: [Venue] { venues.filter { !$0.isVisited } }
    var visited: [Venue] { venues.filter { $0.isVisited } }
}

// MARK: - Location Manager

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    func start() { manager.startUpdatingLocation() }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.location = loc
            self.region = MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04))
        }
        manager.stopUpdatingLocation()
    }
}

// MARK: - Planner Category
// Visible category for the explore strip. Maps down to VenueCategory when
// a wishlist save needs a Codable enum to persist alongside legacy data.

struct PlannerCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let searchTerm: String

    static let all: [PlannerCategory] = [
        .init(id: "restaurants",   name: "Restaurants",     icon: "fork.knife",                        searchTerm: "restaurant"),
        .init(id: "coffee",        name: "Coffee",          icon: "cup.and.saucer.fill",               searchTerm: "coffee shop"),
        .init(id: "bars",          name: "Bars",            icon: "wineglass.fill",                    searchTerm: "bar"),
        .init(id: "movies",        name: "Movies",          icon: "film.fill",                         searchTerm: "movie theater"),
        .init(id: "activities",    name: "Activities",      icon: "figure.walk",                       searchTerm: "activities"),
        .init(id: "parks",         name: "Parks",           icon: "leaf.fill",                         searchTerm: "park"),
        .init(id: "beach",         name: "Beach",           icon: "water.waves",                       searchTerm: "beach"),
        .init(id: "art",           name: "Art & Culture",   icon: "paintpalette.fill",                 searchTerm: "museum"),
        .init(id: "live-music",    name: "Live Music",      icon: "music.note",                        searchTerm: "live music"),
        .init(id: "shopping",      name: "Shopping",        icon: "bag.fill",                          searchTerm: "shopping"),
        .init(id: "late-night",    name: "Late Night",      icon: "moon.stars.fill",                   searchTerm: "late night"),
        .init(id: "spa",           name: "Spa",             icon: "sparkles",                          searchTerm: "spa"),
        .init(id: "entertainment", name: "Entertainment",   icon: "star.fill",                         searchTerm: "entertainment"),
        .init(id: "casual",        name: "Casual Eats",     icon: "takeoutbag.and.cup.and.straw.fill", searchTerm: "casual restaurant"),
        .init(id: "fine-dining",   name: "Fine Dining",     icon: "fork.knife.circle.fill",            searchTerm: "fine dining"),
    ]

    static let restaurants: PlannerCategory = all[0]

    var venueCategory: VenueCategory {
        switch id {
        case "restaurants", "casual", "fine-dining": return .restaurant
        case "coffee":                                return .cafe
        case "bars", "late-night":                    return .bar
        case "movies", "activities", "live-music",
             "entertainment":                         return .activity
        case "parks":                                 return .park
        case "beach":                                 return .beach
        case "art":                                   return .museum
        case "shopping", "spa":                       return .other
        default:                                      return .other
        }
    }
}

// MARK: - Distance Filter

enum DistanceFilter: Double, CaseIterable, Identifiable {
    case one        = 1
    case five       = 5
    case ten        = 10
    case twentyFive = 25
    case fifty      = 50

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue)) mi" }
    var meters: CLLocationDistance { rawValue * 1609.344 }

    /// Next-larger option, or nil if already at the max. Powers the
    /// "Expand to X mi" button in the empty-results state.
    var next: DistanceFilter? {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    static let storageKey = "datePlanner.distanceFilter.v2"
    /// Reads the saved radius from DatePlannerStore (or UserDefaults as a
    /// fallback during the v1 → v2 migration). New installs default to 10 mi.
    static var stored: DistanceFilter {
        if let stored = DatePlannerStore.shared.radius { return stored }
        let raw = UserDefaults.standard.double(forKey: storageKey)
        return DistanceFilter(rawValue: raw) ?? .ten
    }
    func persist() {
        DatePlannerStore.shared.setRadius(self)
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }
}

// MARK: - Date Planner Main View

struct DatePlannerView: View {
    let initialSearchLocation: SearchLocation?
    let initialCategory: PlannerCategory?
    let modalDismiss: (() -> Void)?

    init(initialSearchLocation: SearchLocation? = nil,
         initialCategory: PlannerCategory? = nil,
         modalDismiss: (() -> Void)? = nil) {
        self.initialSearchLocation = initialSearchLocation
        self.initialCategory = initialCategory
        self.modalDismiss = modalDismiss
    }

    @State private var tab: PlannerTab = .explore
    @StateObject private var locationManager = LocationManager()
    @State private var searchLocation: SearchLocation?
    @State private var showMidpoint = false
    @State private var plannerStore = DatePlannerStore.shared
    @State private var showSetup = false

    enum PlannerTab: String, CaseIterable {
        case explore  = "Explore"
        case wishlist = "Saved"
        case picks    = "AI Picks"

        var icon: String {
            switch self {
            case .explore:  return "map.fill"
            case .wishlist: return "heart.fill"
            case .picks:    return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let context = plannerStore.context {
                    DateContextHeaderBar(
                        context: context,
                        onChange: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showSetup = true
                        },
                        onClear: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.25)) {
                                plannerStore.clearContext()
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                RWSegmentedPicker(
                    options: PlannerTab.allCases.map { (value: $0, label: $0.rawValue, icon: $0.icon) },
                    selected: $tab
                )
                .padding(.horizontal, SP.lg).padding(.top, 6).padding(.bottom, 4)

                switch tab {
                case .explore:
                    ExploreMapView(
                        locationManager: locationManager,
                        searchLocation: $searchLocation,
                        initialCategory: initialCategory)
                case .wishlist:
                    WishlistView()
                case .picks:
                    AIPicksView(
                        locationManager: locationManager,
                        searchLocation: searchLocation)
                }
            }
            .rwBG()
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: plannerStore.context)
            .navigationTitle("Date Planner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if modalDismiss != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { modalDismiss?() }
                            .foregroundColor(.rwAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            plannerStore.startNewDate()
                            showSetup = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                Text("New Date").font(RWF.cap(12))
                            }
                            .foregroundColor(.rwAccent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.rwAccent.opacity(0.10))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.rwAccent.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(SBS())

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showMidpoint = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "location.viewfinder")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                Text("Midpoint").font(RWF.cap(12))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(LinearGradient.accent)
                            .clipShape(Capsule())
                            .shadow(color: Color.rwAccent.opacity(0.3), radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(SBS())
                    }
                }
            }
            .sheet(isPresented: $showMidpoint) {
                MidpointPickerView(userCoordinate: locationManager.location?.coordinate) { resolved in
                    searchLocation = resolved
                }
            }
            .sheet(isPresented: $showSetup) {
                DateSetupView(
                    userCoordinate: locationManager.location?.coordinate
                ) { ctx in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        plannerStore.setContext(ctx)
                    }
                    applyContextToSearchLocation(ctx)
                    if plannerStore.context != nil {
                        tab = .picks
                    }
                }
            }
        }
        .onChange(of: plannerStore.forceSetup) { _, force in
            if force { showSetup = true }
        }
        .onAppear {
            if let preset = initialSearchLocation, searchLocation == nil {
                searchLocation = preset
            }
            // First open with no saved scene → run setup. Otherwise honor
            // the persisted context and apply its location to the search.
            if plannerStore.context == nil && !plannerStore.forceSetup {
                showSetup = true
            } else if let ctx = plannerStore.context {
                applyContextToSearchLocation(ctx)
            }
            switch locationManager.authStatus {
            case .notDetermined:
                locationManager.requestPermission()
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.start()
            case .denied, .restricted:
                break
            @unknown default:
                break
            }
        }
    }

    // Map the setup-flow location choice onto the planner's search anchor so
    // Explore + AI Picks both center on the right place.
    private func applyContextToSearchLocation(_ ctx: DateSetupContext) {
        switch ctx.location {
        case .nearMe, .none:
            // Explicit override is "Near Me" or skipped → fall back to GPS.
            searchLocation = nil
        case .midpoint(let name, let lat, let lng):
            searchLocation = SearchLocation(
                title: "Midpoint",
                subtitle: "Halfway with \(name)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                kind: .midpoint(name))
        case .area(let title, let subtitle, let lat, let lng):
            searchLocation = SearchLocation(
                title: title,
                subtitle: subtitle,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                kind: .area)
        }
    }
}

// MARK: - Identifiable MKMapItem wrapper
// Stable id derived from coordinate + name so SwiftUI ForEach keeps identity
// across re-renders (lets us track pin selection reliably).

struct IdentifiableMapItem: Identifiable, Hashable {
    let id: String
    let item: MKMapItem

    init(_ item: MKMapItem) {
        let lat = item.placemark.coordinate.latitude
        let lng = item.placemark.coordinate.longitude
        self.id  = "\(lat),\(lng)|\(item.name ?? "")"
        self.item = item
    }

    var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }

    static func == (lhs: IdentifiableMapItem, rhs: IdentifiableMapItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Explore Map

struct ExploreMapView: View {
    @ObservedObject var locationManager: LocationManager
    @Binding var searchLocation: SearchLocation?
    let initialCategory: PlannerCategory?

    @StateObject private var search = MapSearchService()
    @State private var searchCompleter = LocationSearchCompleter()

    @State private var query: String = ""
    @State private var selectedCategory: PlannerCategory? = nil
    @State private var distance: DistanceFilter = .stored
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedItemID: String? = nil
    @State private var detailItem: MKMapItem? = nil
    @State private var detailCategory: VenueCategory = .other
    @State private var detailDistance: String? = nil
    @State private var showDetail = false
    @State private var didApplyInitial = false
    @FocusState private var queryFocused: Bool

    // Active center coordinate the search runs around. Override > GPS > NYC fallback.
    private var center: CLLocationCoordinate2D {
        searchLocation?.coordinate
            ?? locationManager.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    }

    private var midpointName: String? {
        if case .midpoint(let name) = searchLocation?.kind { return name }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.rwBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, SP.lg).padding(.top, 8)

                if queryFocused && !searchCompleter.suggestions.isEmpty {
                    autocompleteList
                        .padding(.horizontal, SP.lg).padding(.top, 6)
                }

                if let active = searchLocation {
                    activePill(active)
                        .padding(.horizontal, SP.lg).padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let name = midpointName {
                    midpointBanner(name: name)
                        .padding(.horizontal, SP.lg).padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                radiusCaption
                    .padding(.horizontal, SP.lg).padding(.top, 6)

                categoryStrip
                    .padding(.top, 10)

                distanceStrip
                    .padding(.horizontal, SP.lg).padding(.top, 8).padding(.bottom, 10)

                if locationManager.authStatus == .denied || locationManager.authStatus == .restricted {
                    LocationDeniedCard().padding(SP.lg)
                    Spacer(minLength: 0)
                } else {
                    ZStack(alignment: .top) {
                        map
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                                .stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 14, x: 0, y: 6)
                            .padding(.horizontal, SP.lg)

                        if let id = selectedItemID,
                           let result = search.results.first(where: { $0.id == id }) {
                            calloutCard(for: result)
                                .padding(.horizontal, SP.lg + 8)
                                .padding(.top, 10)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    resultsList
                }
            }
            .animation(.easeInOut(duration: 0.22), value: searchLocation)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: selectedCategory?.id)
            .animation(.easeInOut(duration: 0.2), value: search.results.count)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: selectedItemID)
        }
        .onAppear { handleAppear() }
        .onChange(of: searchLocation) { _, _ in
            recenter()
            rerunSearch()
        }
        .onChange(of: distance) { _, new in
            new.persist()
            rerunSearch()
        }
        .onReceive(locationManager.$location.compactMap { $0 }) { _ in
            if searchLocation == nil { recenter() }
        }
        .sheet(isPresented: $showDetail) {
            if let item = detailItem {
                PlaceDetailSheet(item: item, category: detailCategory, distanceLabel: detailDistance)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: search bar + autocomplete

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.rwTextMuted)

            TextField("Search venues or any area…", text: $query)
                .focused($queryFocused)
                .font(RWF.body(15))
                .foregroundColor(.rwTextPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onChange(of: query) { _, new in
                    searchCompleter.query = new
                }
                .onSubmit { runManualSearch() }

            if !query.isEmpty {
                Button {
                    query = ""
                    searchCompleter.clear()
                    selectedCategory = nil
                    search.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.rwTextMuted)
                }
                .buttonStyle(SBS())
            } else if search.isSearching {
                ProgressView().tint(.rwAccent).scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg)
            .stroke(queryFocused ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))
    }

    private var autocompleteList: some View {
        VStack(spacing: 0) {
            ForEach(Array(searchCompleter.suggestions.prefix(4).enumerated()), id: \.offset) { idx, completion in
                Button {
                    Task { await pickLocationSuggestion(completion) }
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
                if idx < min(3, searchCompleter.suggestions.count - 1) {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func activePill(_ loc: SearchLocation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: pillIcon(loc))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text("Searching near: \(loc.title)")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.2)) { searchLocation = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.rwTextSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.rwCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
            }
            .buttonStyle(SBS())
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(LinearGradient.accentSoft)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
    }

    private func midpointBanner(name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "location.viewfinder")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text("Midpoint between you and \(name)")
                .font(RWF.cap(12))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(LinearGradient.accent)
        .clipShape(Capsule())
        .shadow(color: Color.rwAccent.opacity(0.30), radius: 8, x: 0, y: 3)
    }

    private func pillIcon(_ loc: SearchLocation) -> String {
        switch loc.kind {
        case .area:     return "mappin.and.ellipse"
        case .contact:  return "person.fill"
        case .midpoint: return "location.viewfinder"
        }
    }

    // MARK: categories + distance

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlannerCategory.all) { cat in
                    categoryPill(cat)
                }
            }
            .padding(.horizontal, SP.lg)
        }
    }

    private func categoryPill(_ cat: PlannerCategory) -> some View {
        let selected = selectedCategory?.id == cat.id
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                if selected {
                    selectedCategory = nil
                    search.clear()
                    selectedItemID = nil
                } else {
                    selectedCategory = cat
                    query = ""
                    queryFocused = false
                }
            }
            if !selected {
                Task { await runCategorySearch(cat) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(cat.name)
                    .font(RWF.cap(13))
            }
            .foregroundColor(selected ? .white : .rwTextPrimary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                ZStack {
                    if selected {
                        LinearGradient.accent
                    } else {
                        Color.rwCard
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Color.rwBorder, lineWidth: 1))
            .shadow(color: selected ? Color.rwAccent.opacity(0.30) : Color.rwShadow,
                    radius: selected ? 10 : 4,
                    x: 0, y: selected ? 4 : 2)
            .scaleEffect(selected ? 1.04 : 1.0)
        }
        .buttonStyle(SBS())
    }

    private var distanceStrip: some View {
        HStack(spacing: 6) {
            ForEach(DistanceFilter.allCases) { d in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { distance = d }
                } label: {
                    Text(d.label)
                        .font(RWF.cap(12))
                        .foregroundColor(distance == d ? .white : .rwTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(distance == d ? Color(hex: "0D0D0D") : Color.rwSurface)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(distance == d ? Color.clear : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
        }
    }

    // MARK: map + callout

    private var map: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            // Translucent radius circle so the user can see exactly where
            // Cyrano + MKLocalSearch are looking. Updates live with the
            // distance selector.
            MapCircle(center: center, radius: distance.meters)
                .foregroundStyle(Color.rwAccent.opacity(0.10))
                .stroke(Color.rwAccent.opacity(0.4), lineWidth: 1)
            ForEach(search.results) { result in
                Annotation(result.item.name ?? "", coordinate: result.coordinate, anchor: .bottom) {
                    VenuePin(
                        icon: selectedCategory?.icon ?? "mappin",
                        selected: selectedItemID == result.id
                    )
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedItemID = result.id
                        cameraPosition = .region(MKCoordinateRegion(
                            center: result.coordinate,
                            latitudinalMeters: 1500,
                            longitudinalMeters: 1500))
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
    }

    // MARK: radius caption

    /// "Within 10 miles of Lakewood, NJ" — sits between the search pill and
    /// the distance strip so the user always sees the active scope of search.
    private var radiusCaption: some View {
        let placeName: String = {
            if case .midpoint(let name) = searchLocation?.kind { return "midpoint with \(name)" }
            if let title = searchLocation?.title { return title }
            return "your location"
        }()
        return HStack(spacing: 6) {
            Image(systemName: "scope")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.rwAccent)
            Text("Within \(Int(distance.rawValue)) miles of \(placeName)")
                .font(RWF.cap(11))
                .foregroundColor(.rwTextSecondary)
                .lineLimit(1)
            Spacer()
        }
    }

    private func calloutCard(for result: IdentifiableMapItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            detailItem = result.item
            detailCategory = selectedCategory?.venueCategory ?? .other
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient.accent)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: selectedCategory?.icon ?? "mappin")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.item.name ?? "Place")
                        .font(RWF.head(14))
                        .foregroundColor(.rwTextPrimary)
                        .lineLimit(1)
                    Text(distanceLabel(for: result.coordinate))
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                }
                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Text("View")
                        .font(RWF.cap(12))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(LinearGradient.accent)
                .clipShape(Capsule())

                Button {
                    withAnimation { selectedItemID = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                        .frame(width: 22, height: 22)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(SBS())
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 14, x: 0, y: 6)
        }
        .buttonStyle(SBS())
    }

    // MARK: results

    @ViewBuilder
    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                if search.results.isEmpty {
                    if search.isSearching {
                        searchingState
                    } else if selectedCategory == nil && query.isEmpty {
                        emptyStartState
                    } else {
                        emptyResultsState
                    }
                } else {
                    ForEach(search.results) { result in
                        PlannerResultCard(
                            result: result,
                            category: selectedCategory,
                            distanceLabel: distanceLabel(for: result.coordinate),
                            highlighted: selectedItemID == result.id,
                            onSelect: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedItemID = result.id
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: result.coordinate,
                                    latitudinalMeters: 1200,
                                    longitudinalMeters: 1200))
                                detailItem = result.item
                                detailCategory = selectedCategory?.venueCategory ?? .other
                                detailDistance = distanceLabel(for: result.coordinate)
                                showDetail = true
                            },
                            onDirections: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                result.item.openInMaps(launchOptions: [
                                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                                ])
                            },
                            onAddToPlan: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                detailItem = result.item
                                detailCategory = selectedCategory?.venueCategory ?? .other
                                detailDistance = distanceLabel(for: result.coordinate)
                                showDetail = true
                            }
                        )
                        .padding(.horizontal, SP.lg)
                    }
                    Spacer().frame(height: 80)
                }
            }
            .padding(.top, 14)
        }
    }

    private var searchingState: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.rwAccent).scaleEffect(1.05)
            Text("Searching nearby…")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    private var emptyStartState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 30, design: .rounded))
                .foregroundStyle(LinearGradient.accent)
            Text("Pick a category to discover spots")
                .font(RWF.head(14))
                .foregroundColor(.rwTextSecondary)
            Text("Or type a venue or area above.")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextMuted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36)
    }

    private var emptyResultsState: some View {
        let categoryName = selectedCategory?.name.lowercased() ?? "spots"
        let placeName: String = {
            if case .midpoint(let name) = searchLocation?.kind { return "the midpoint with \(name)" }
            if let title = searchLocation?.title { return title }
            return "your location"
        }()
        return VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 26, design: .rounded))
                .foregroundColor(.rwTextMuted)
            Text("No \(categoryName) found within \(Int(distance.rawValue)) miles of \(placeName)")
                .font(RWF.head(14))
                .foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SP.lg)
            Text("Try increasing your distance or searching a different area.")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center)

            if let next = distance.next {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        distance = next
                    }
                } label: {
                    Label("Expand to \(Int(next.rawValue)) mi", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(RWF.cap(13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(LinearGradient.accent)
                        .clipShape(Capsule())
                        .shadow(color: Color.rwAccent.opacity(0.30), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(SBS())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    // MARK: actions

    private func handleAppear() {
        if !didApplyInitial {
            didApplyInitial = true
            recenter()
            if let initial = initialCategory {
                selectedCategory = initial
                Task { await runCategorySearch(initial) }
            }
        }
    }

    private func rerunSearch() {
        if let cat = selectedCategory {
            Task { await runCategorySearch(cat) }
        } else if !query.isEmpty {
            Task { await runFreeSearch(query) }
        }
    }

    private func runCategorySearch(_ cat: PlannerCategory) async {
        await search.searchAsync(query: cat.searchTerm, center: center, maxMiles: distance.rawValue)
        fitMapToResults()
    }

    private func runFreeSearch(_ q: String) async {
        await search.searchAsync(query: q, center: center, maxMiles: distance.rawValue)
        fitMapToResults()
    }

    private func runManualSearch() {
        guard !query.isEmpty else { return }
        selectedCategory = nil
        queryFocused = false
        Task { await runFreeSearch(query) }
    }

    private func regionForSearch() -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: distance.meters * 2,
            longitudinalMeters: distance.meters * 2)
    }

    private func recenter() {
        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            latitudinalMeters: distance.meters * 1.4,
            longitudinalMeters: distance.meters * 1.4))
    }

    // Build an MKMapRect that contains the search center plus every result,
    // pad it ~30% on each axis, animate the map to fit.
    private func fitMapToResults() {
        guard !search.results.isEmpty else {
            recenter()
            return
        }
        var rect = MKMapRect.null
        let centerPoint = MKMapPoint(center)
        rect = rect.union(MKMapRect(origin: centerPoint, size: .init(width: 0, height: 0)))
        for r in search.results {
            let pt = MKMapPoint(r.coordinate)
            rect = rect.union(MKMapRect(origin: pt, size: .init(width: 0, height: 0)))
        }
        let padX = max(rect.size.width * 0.3, 600)
        let padY = max(rect.size.height * 0.3, 600)
        let padded = rect.insetBy(dx: -padX, dy: -padY)
        withAnimation(.easeInOut(duration: 0.45)) {
            cameraPosition = .rect(padded)
        }
    }

    @MainActor
    private func pickLocationSuggestion(_ completion: MKLocalSearchCompletion) async {
        guard let resolved = await searchCompleter.resolve(completion) else { return }
        searchLocation = SearchLocation(
            title: resolved.title,
            subtitle: resolved.subtitle.isEmpty ? nil : resolved.subtitle,
            coordinate: resolved.coordinate,
            kind: .area)
        searchCompleter.clear()
        query = ""
        queryFocused = false
    }

    private func distanceLabel(for coord: CLLocationCoordinate2D) -> String {
        let from = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let to   = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let miles = from.distance(from: to) / 1609.344
        if miles < 0.1  { return "Right here" }
        if miles < 10   { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }
}

// MARK: - Map Search Service

@MainActor
class MapSearchService: ObservableObject {
    @Published var results: [IdentifiableMapItem] = []
    @Published var isSearching = false

    nonisolated func search(query: String,
                            center: CLLocationCoordinate2D,
                            maxMiles: Double) {
        Task { await searchAsync(query: query, center: center, maxMiles: maxMiles) }
    }

    /// Strict-radius search. Builds a 2× radius region (so MKLocalSearch
    /// returns candidates across the whole circle), then post-filters by
    /// straight-line miles from `center`. Results are sorted closest-first.
    func searchAsync(query: String,
                     center: CLLocationCoordinate2D,
                     maxMiles: Double) async {
        isSearching = true
        let meters = maxMiles * 1609.344
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: meters * 2,
            longitudinalMeters: meters * 2)
        req.resultTypes = .pointOfInterest
        do {
            let response = try await MKLocalSearch(request: req).start()
            let from = CLLocation(latitude: center.latitude, longitude: center.longitude)
            results = response.mapItems
                .map(IdentifiableMapItem.init)
                .compactMap { item -> (IdentifiableMapItem, Double)? in
                    let to = CLLocation(latitude: item.coordinate.latitude, longitude: item.coordinate.longitude)
                    let miles = from.distance(from: to) / 1609.344
                    return miles <= maxMiles ? (item, miles) : nil
                }
                .sorted { $0.1 < $1.1 }
                .map { $0.0 }
        } catch {
            results = []
        }
        isSearching = false
    }

    func clear() {
        results = []
        isSearching = false
    }
}

// MARK: - Venue Pin
// Pink-gradient annotation. Selected state pulses up in size + glow.

struct VenuePin: View {
    let icon: String
    let selected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(LinearGradient.accent)
                    .frame(width: selected ? 40 : 32, height: selected ? 40 : 32)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.85),
                                        lineWidth: selected ? 2.5 : 2)
                    )
                    .shadow(color: Color.rwAccent.opacity(selected ? 0.55 : 0.35),
                            radius: selected ? 12 : 6, x: 0, y: 3)
                Image(systemName: icon)
                    .font(.system(size: selected ? 16 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(Color(hex: "00BFB3"))
                .frame(width: 9, height: 6)
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.74), value: selected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Planner Result Card
// Each search result rendered below the map. Has Get Directions, a heart-toggle
// for the wishlist, and an Add-to-Plan button that opens VenueDetailSheet for
// contact attachment + notes.

struct PlannerResultCard: View {
    let result: IdentifiableMapItem
    let category: PlannerCategory?
    let distanceLabel: String
    let highlighted: Bool
    let onSelect: () -> Void
    let onDirections: () -> Void
    let onAddToPlan: () -> Void

    @State private var wishStore = WishlistStore.shared

    private var item: MKMapItem { result.item }
    private var name: String { item.name ?? "Place" }
    private var address: String { item.placemark.title ?? "" }
    private var categoryName: String { category?.name ?? "Place" }
    private var categoryIcon: String { category?.icon ?? "mappin" }

    private var isSaved: Bool {
        WishlistStore.shared.isWishlisted(name, address: address)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.accentSoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryIcon)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(categoryName)
                            .font(RWF.micro())
                            .foregroundColor(.rwAccent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.rwAccent.opacity(0.10))
                            .clipShape(Capsule())

                        Text(distanceLabel)
                            .font(RWF.cap(11))
                            .foregroundColor(.rwTextMuted)
                    }

                    if !address.isEmpty {
                        Text(address)
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let phone = item.phoneNumber {
                        Link(destination: URL(string: "tel:\(phone)") ?? URL(string: "tel:")!) {
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill").font(.system(size: 10, design: .rounded))
                                Text(phone).font(RWF.cap(11))
                            }
                            .foregroundColor(.rwTextSecondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isSaved {
                        wishStore.removeBy(name: name, address: address)
                    } else {
                        let venue = Venue(
                            name: name,
                            category: category?.venueCategory ?? .other,
                            address: address,
                            latitude: result.coordinate.latitude,
                            longitude: result.coordinate.longitude)
                        wishStore.add(venue)
                    }
                } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(isSaved ? .rwAccent : .rwTextMuted)
                        .frame(width: 38, height: 38)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isSaved ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }

            HStack(spacing: 8) {
                Button(action: onDirections) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("Get Directions").font(RWF.cap(12))
                    }
                    .foregroundColor(.rwTextPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.rwSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())

                Button(action: onAddToPlan) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("Add to Date Plan").font(RWF.cap(12))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                    .shadow(color: Color.rwAccent.opacity(0.30), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(SBS())
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(highlighted ? Color.rwAccent.opacity(0.45) : Color.rwBorder,
                        lineWidth: highlighted ? 1.5 : 1)
        )
        .shadow(color: highlighted ? Color.rwAccent.opacity(0.18) : Color.rwShadow,
                radius: highlighted ? 14 : 8, x: 0, y: highlighted ? 6 : 2)
        .scaleEffect(highlighted ? 1.01 : 1.0)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: highlighted)
        .onTapGesture { onSelect() }
    }
}

// MARK: - Wishlist View

struct WishlistView: View {
    @State private var store = WishlistStore.shared
    @State private var filter: WFilter = .all

    enum WFilter: String, CaseIterable { case all = "All", toVisit = "To Visit", visited = "Visited" }

    var filtered: [Venue] {
        switch filter {
        case .all:     return store.venues
        case .toVisit: return store.unvisited
        case .visited: return store.visited
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                HStack(spacing: 8) {
                    ForEach(WFilter.allCases, id: \.self) { f in
                        FilterChip(label: f.rawValue, isSelected: filter == f) { withAnimation { filter = f } }
                    }
                    Spacer()
                    Text("\(filtered.count) places").font(RWF.cap()).foregroundColor(.rwTextMuted)
                }
                .padding(.horizontal, SP.lg)

                if store.venues.isEmpty {
                    RWEmptyState(
                        icon: "heart.slash",
                        title: "No saved venues yet",
                        subtitle: "Explore the map and save places you want to take someone.",
                        cta: nil,
                        ctaIcon: nil,
                        onCTA: nil
                    )
                    .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { venue in
                            WishlistCard(venue: venue)
                                .padding(.horizontal, SP.lg)
                        }
                    }
                }
                Spacer().frame(height: 80)
            }
            .padding(.top, 12)
        }
    }
}

struct WishlistCard: View {
    @State var venue: Venue
    @State private var store = WishlistStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: venue.category.icon)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(venue.isVisited ? .rwTextMuted : .white)
                    .frame(width: 44, height: 44)
                    .background(venue.isVisited ? Color.rwSurface : venue.category.color)
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))

                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.name).font(RWF.head(15)).foregroundColor(.rwTextPrimary).lineLimit(1)
                    Text(venue.address).font(RWF.cap(11)).foregroundColor(.rwTextMuted).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(venue.category.rawValue).font(RWF.micro()).foregroundColor(venue.category.color)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(venue.category.color.opacity(0.1)).clipShape(Capsule())
                        if !venue.personName.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "person.fill").font(.system(size: 9, design: .rounded))
                                Text(venue.personName).font(RWF.micro())
                            }
                            .foregroundColor(.rwAccent).padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.rwAccent.opacity(0.1)).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Button {
                    store.remove(venue)
                } label: {
                    Image(systemName: "trash").font(.system(size: 14, design: .rounded)).foregroundColor(.rwTextMuted)
                }
                .buttonStyle(SBS())
            }

            if !venue.notes.isEmpty {
                Text(venue.notes).font(RWF.body(13)).foregroundColor(.rwTextMuted).lineLimit(2)
            }

            if venue.isVisited {
                HStack {
                    Label("Visited", systemImage: "checkmark.circle.fill").font(RWF.cap()).foregroundColor(.rwSuccess)
                    if let date = venue.visitedAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Button { venue.dateRating = i; store.update(venue) } label: {
                                Image(systemName: i <= venue.dateRating ? "heart.fill" : "heart")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(i <= venue.dateRating ? .rwAccent : .rwTextMuted)
                            }
                            .buttonStyle(SBS())
                        }
                    }
                }
            } else {
                Button {
                    venue.isVisited = true; venue.visitedAt = Date(); store.update(venue)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("Mark as Visited", systemImage: "checkmark.circle")
                        .font(RWF.cap()).foregroundColor(.rwSuccess)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color.rwSuccess.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwSuccess.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
    }
}

// MARK: - AI Picks View
// Generates 3 venue ideas via Cyrano, resolves each to a real MKMapItem via
// MKLocalSearch, plots all resolved picks as pink pins on a small map, and
// renders them as tappable cards. Card or pin tap → PlaceDetailSheet.

struct AIPicksView: View {
    @ObservedObject var locationManager: LocationManager
    let searchLocation: SearchLocation?

    @State private var store = WishlistStore.shared
    @State private var plannerStore = DatePlannerStore.shared
    @State private var picks: [AIPick] = []
    @State private var phase: Phase = .idle
    @State private var lastError: String? = nil
    @State private var selectedPerson: Person? = nil
    @State private var vibe = ""

    @State private var detailItem: MKMapItem? = nil
    @State private var detailCategory: VenueCategory = .other
    @State private var detailDistance: String? = nil
    @State private var showDetail = false

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPickID: UUID? = nil

    enum Phase: Equatable { case idle, loading, ready, failed, empty }

    struct AIPick: Identifiable, Equatable {
        let id = UUID()
        let category: VenueCategory
        let name: String           // category-level title (e.g. "Cozy Italian restaurant")
        let reason: String
        let searchQuery: String
        let thingToDo: String?
        var resolved: IdentifiableMapItem? = nil

        static func == (lhs: AIPick, rhs: AIPick) -> Bool { lhs.id == rhs.id }
    }

    private var activeCenter: CLLocationCoordinate2D {
        searchLocation?.coordinate
            ?? locationManager.location?.coordinate
            ?? CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    }

    private var activeRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: activeCenter,
            latitudinalMeters: 4000,
            longitudinalMeters: 4000)
    }

    private var resolvedPicks: [AIPick] { picks.filter { $0.resolved != nil } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {

                if !AISettings.shared.isEnabled {
                    AIOffBanner(feature: "AI Picks", msg: "Turn on AI to get personalised date suggestions.")
                        .padding(.horizontal, SP.lg)
                } else {
                    if plannerStore.context != nil {
                        sceneCard.padding(.horizontal, SP.lg)
                    } else {
                        contextCard.padding(.horizontal, SP.lg)
                    }
                    contentForPhase
                }

                Spacer().frame(height: 80)
            }
            .padding(.top, 12)
        }
        .sheet(isPresented: $showDetail) {
            if let item = detailItem {
                PlaceDetailSheet(item: item, category: detailCategory, distanceLabel: detailDistance)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: scene card (shown when DatePlannerStore.context is set)

    private var sceneCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.system(size: 18, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    Text("Picks for your scene").font(RWF.head()).foregroundColor(.rwTextPrimary)
                }

                if let context = plannerStore.context {
                    Text(context.promptDescription())
                        .font(RWF.body(13))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                RWButton(phase == .loading ? "Thinking…" : (picks.isEmpty ? "Get 5 Picks" : "Refresh Picks"),
                         icon: phase == .loading ? nil : "sparkles") {
                    Task { await generatePicks() }
                }
                .disabled(phase == .loading)
            }
        }
    }

    // MARK: context card

    private var contextCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.system(size: 18, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    Text("Cyrano's Date Picks").font(RWF.head()).foregroundColor(.rwTextPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Who's the date with?", systemImage: "person.fill")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)

                    if ArchiveStore.shared.active.isEmpty {
                        Text("Add connections to The Archive first")
                            .font(RWF.body(13)).foregroundColor(.rwTextMuted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button { selectedPerson = nil } label: {
                                    Text("General").font(RWF.cap(12))
                                        .foregroundColor(selectedPerson == nil ? .white : .rwTextMuted)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(selectedPerson == nil ? Color(hex: "0D0D0D") : Color.rwSurface)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(SBS())

                                ForEach(ArchiveStore.shared.active.prefix(8)) { p in
                                    Button { selectedPerson = p } label: {
                                        Text(p.name).font(RWF.cap(12))
                                            .foregroundColor(selectedPerson?.id == p.id ? .white : .rwTextSecondary)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(selectedPerson?.id == p.id ? Color(hex: "0D0D0D") : Color.rwSurface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(SBS())
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("What's the vibe?", systemImage: "wand.and.stars")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("Casual, romantic, adventurous, cheap…", text: $vibe)
                        .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwSurface)
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
                }

                RWButton(phase == .loading ? "Thinking…" : "Get Suggestions",
                         icon: phase == .loading ? nil : "sparkles") {
                    Task { await generatePicks() }
                }
                .disabled(phase == .loading)
            }
        }
    }

    // MARK: phase routing

    @ViewBuilder
    private var contentForPhase: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .loading:
            loadingState.padding(.horizontal, SP.lg)
        case .failed:
            errorState.padding(.horizontal, SP.lg)
        case .empty:
            emptyState.padding(.horizontal, SP.lg)
        case .ready:
            resultsSection
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 12, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("Cyrano is picking…")
                    .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                Spacer()
            }
            ForEach(0..<3, id: \.self) { _ in SkeletonCard() }
        }
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, design: .rounded))
                .foregroundColor(.rwWarning)
            Text("Couldn't get suggestions")
                .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
            if let lastError {
                Text(lastError)
                    .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await generatePicks() }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 26, design: .rounded)).foregroundColor(.rwTextMuted)
            Text("No matching venues nearby")
                .font(RWF.head(14)).foregroundColor(.rwTextSecondary)
            Text("Try a different vibe or move the search location.")
                .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                .multilineTextAlignment(.center)
        }
        .padding(SP.lg)
        .frame(maxWidth: .infinity)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }

    private var resultsSection: some View {
        VStack(spacing: SP.md) {
            if !resolvedPicks.isEmpty { picksMap.padding(.horizontal, SP.lg) }
            VStack(spacing: 12) {
                ForEach(picks) { pick in
                    AIPickCard(
                        pick: pick,
                        distanceLabel: pick.resolved.map { distanceLabel(for: $0.coordinate) },
                        highlighted: selectedPickID == pick.id,
                        onTap: { tap(pick) }
                    )
                    .padding(.horizontal, SP.lg)
                }
            }
        }
    }

    // MARK: pin map

    private var picksMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            MapCircle(center: activeCenter, radius: DistanceFilter.stored.meters)
                .foregroundStyle(Color.rwAccent.opacity(0.10))
                .stroke(Color.rwAccent.opacity(0.4), lineWidth: 1)
            ForEach(resolvedPicks) { pick in
                if let resolved = pick.resolved {
                    Annotation(resolved.item.name ?? pick.name, coordinate: resolved.coordinate, anchor: .bottom) {
                        VenuePin(
                            icon: pick.category.icon,
                            selected: selectedPickID == pick.id
                        )
                        .onTapGesture { tap(pick) }
                    }
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 4)
    }

    // MARK: tap → detail

    private func tap(_ pick: AIPick) {
        guard let resolved = pick.resolved else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            selectedPickID = pick.id
        }
        detailItem = resolved.item
        detailCategory = pick.category
        detailDistance = distanceLabel(for: resolved.coordinate)
        showDetail = true
    }

    private func distanceLabel(for coord: CLLocationCoordinate2D) -> String {
        let from = CLLocation(latitude: activeCenter.latitude, longitude: activeCenter.longitude)
        let to   = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let miles = from.distance(from: to) / 1609.344
        if miles < 0.1 { return "Right here" }
        if miles < 10  { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }

    // MARK: generate

    @MainActor
    func generatePicks() async {
        phase = .loading
        lastError = nil
        picks = []
        selectedPickID = nil

        let scene = plannerStore.context
        let count = scene == nil ? 3 : 5

        let (system, userMsg) = buildPrompt(scene: scene, count: count)

        do {
            let raw = try await Claude.shared.send(system: system, user: userMsg, max: 600)
            let cleaned = Claude.shared.clean(raw)

            struct RawPick: Codable {
                var category: String
                var name: String
                var reason: String
                var searchQuery: String
                var thingToDo: String?
            }
            guard let data = cleaned.data(using: .utf8),
                  let rawPicks = try? JSONDecoder().decode([RawPick].self, from: data),
                  !rawPicks.isEmpty
            else {
                phase = .failed
                lastError = "Cyrano's response wasn't readable. Try again."
                return
            }

            picks = rawPicks.map { r in
                let cat = VenueCategory.allCases.first { $0.rawValue == r.category } ?? .other
                return AIPick(
                    category: cat,
                    name: r.name,
                    reason: r.reason,
                    searchQuery: r.searchQuery,
                    thingToDo: r.thingToDo)
            }

            // Resolve each pick to a real MKMapItem in parallel.
            await resolveAll()

            if resolvedPicks.isEmpty {
                phase = .empty
            } else {
                phase = .ready
                fitMapToPicks()
            }
        } catch {
            phase = .failed
            lastError = "Cyrano isn't reachable right now."
        }
    }

    private func buildPrompt(scene: DateSetupContext?, count: Int) -> (String, String) {
        let savedCategories = WishlistStore.shared.venues.map { $0.category.rawValue }
        let savedContext = savedCategories.isEmpty ? "" : "Previously saved venue types: \(Set(savedCategories).joined(separator: ", "))."

        let radius = Int(DistanceFilter.stored.rawValue)

        if let scene {
            // Resolve the contact's interests if we have them in Archive.
            var interestLine = ""
            if let pid = scene.personId,
               let person = ArchiveStore.shared.active.first(where: { $0.id == pid }),
               !person.interests.isEmpty {
                interestLine = " Their interests include \(person.interests.joined(separator: ", "))."
            }

            let occasion = scene.occasion?.rawValue ?? "casual hangout"
            let vibeStr = scene.vibes.isEmpty ? "open" : scene.vibes.map { $0.rawValue.lowercased() }.joined(separator: ", ")
            let location = scene.location?.summary ?? "this area"
            let budget = scene.budget.map { "\($0.rawValue) (\($0.range))" } ?? "any"
            let nameStr = scene.personName.isEmpty ? "the person" : scene.personName

            let system = """
            You are Cyrano, a dating coach. Suggest \(count) date spots within \(radius) miles of \(location) for a \(occasion) with a \(vibeStr) vibe and a \(budget) budget. The person's name is \(nameStr).\(interestLine) Be creative and specific — not generic restaurant lists. \(savedContext)

            HARD CONSTRAINT: Do not suggest anything further than \(radius) miles away. The user's results are filtered to this radius — anything outside is invisible to them.

            For each spot return:
            - name (memorable category-style title — e.g. "Cozy Italian counter-seating")
            - category (one of: Restaurant, Bar, Coffee Shop, Park, Activity, Museum, Rooftop, Beach, Other)
            - searchQuery (specific Apple Maps search term, e.g. "natural wine bar")
            - reason (1 sentence why this works for THIS occasion and vibe — include the neighborhood or area name so the user knows roughly where it is)
            - thingToDo (one specific thing to do or say there)

            Use gender-neutral language. Return ONLY a JSON array — no other text:
            [{"category":"…","name":"…","reason":"…","searchQuery":"…","thingToDo":"…"}]
            """

            return (system, "Generate \(count) picks for the scene above.")
        }

        // Default (no-scene) prompt — keeps the legacy 3-pick behavior.
        var ctx = ""
        if let person = selectedPerson {
            ctx = "Planning a date with \(person.name)."
            if !person.interests.isEmpty { ctx += " Their interests: \(person.interests.joined(separator: ", "))." }
            if !person.keyFacts.isEmpty { ctx += " Key facts: \(person.keyFacts.prefix(3).joined(separator: ", "))." }
            if person.totalDates > 0 { ctx += " This would be date number \(person.totalDates + 1)." }
        }
        let vibeContext = vibe.isEmpty ? "" : "Desired vibe: \(vibe)."
        let locationName: String = {
            if let loc = searchLocation {
                if case .midpoint(let name) = loc.kind { return "the midpoint with \(name)" }
                return loc.title
            }
            return "the user's current location"
        }()

        let system = """
        You are Cyrano, a dating coach. Suggest 3 specific date venue types within \(radius) miles of \(locationName).
        HARD CONSTRAINT: Do not suggest anything further than \(radius) miles away — results outside this radius will not be shown.
        Be specific and practical. Use gender-neutral language. Focus on genuine connection. In the reason field include the neighborhood or area name so the user knows roughly where it is.
        Return ONLY a JSON array — no other text:
        [{"category":"Restaurant|Bar|Coffee Shop|Park|Activity|Museum|Rooftop|Beach|Other","name":"…","reason":"…","searchQuery":"…"}]
        """
        let user = "\(ctx) \(vibeContext) \(savedContext) Suggest 3 great date venues."
        return (system, user)
    }

    private func resolveAll() async {
        let center = activeCenter
        let maxMiles = DistanceFilter.stored.rawValue
        let meters = maxMiles * 1609.344
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: meters * 2,
            longitudinalMeters: meters * 2)
        await withTaskGroup(of: (UUID, IdentifiableMapItem?).self) { group in
            for pick in picks {
                group.addTask {
                    let req = MKLocalSearch.Request()
                    req.naturalLanguageQuery = pick.searchQuery
                    req.region = region
                    req.resultTypes = .pointOfInterest
                    do {
                        let resp = try await MKLocalSearch(request: req).start()
                        // Strict-radius post-filter — same rule as Explore.
                        // Take the closest match within range, not the
                        // server's first result, so a far-away top hit
                        // doesn't get picked over a closer one.
                        let from = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        let inRange = resp.mapItems.compactMap { mi -> (MKMapItem, Double)? in
                            let to = CLLocation(latitude: mi.placemark.coordinate.latitude,
                                                longitude: mi.placemark.coordinate.longitude)
                            let miles = from.distance(from: to) / 1609.344
                            return miles <= maxMiles ? (mi, miles) : nil
                        }
                        .sorted { $0.1 < $1.1 }
                        if let nearest = inRange.first {
                            return (pick.id, IdentifiableMapItem(nearest.0))
                        }
                    } catch { }
                    return (pick.id, nil)
                }
            }
            for await (id, item) in group {
                if let idx = picks.firstIndex(where: { $0.id == id }) {
                    picks[idx].resolved = item
                }
            }
        }
    }

    private func fitMapToPicks() {
        let coords = resolvedPicks.compactMap { $0.resolved?.coordinate }
        guard !coords.isEmpty else { return }

        var rect = MKMapRect.null
        rect = rect.union(MKMapRect(origin: MKMapPoint(activeCenter), size: .init(width: 0, height: 0)))
        for c in coords {
            rect = rect.union(MKMapRect(origin: MKMapPoint(c), size: .init(width: 0, height: 0)))
        }
        let padX = max(rect.size.width * 0.3, 600)
        let padY = max(rect.size.height * 0.3, 600)
        let padded = rect.insetBy(dx: -padX, dy: -padY)
        withAnimation(.easeInOut(duration: 0.45)) {
            cameraPosition = .rect(padded)
        }
    }
}

// MARK: - AI Pick Card
// Whole-card tap opens PlaceDetailSheet for the resolved venue. If a pick
// failed to resolve to a real venue, show a "no nearby match" pill but
// still render the suggestion text.

struct AIPickCard: View {
    let pick: AIPicksView.AIPick
    let distanceLabel: String?
    let highlighted: Bool
    let onTap: () -> Void

    private var resolvedName: String? { pick.resolved?.item.name }
    private var resolvedAddress: String? { pick.resolved?.item.placemark.title }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: pick.category.icon)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .shadow(color: Color.rwAccent.opacity(0.30), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pick.name)
                            .font(RWF.head(15))
                            .foregroundColor(.rwTextPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(pick.reason)
                            .font(RWF.body(13))
                            .foregroundColor(.rwTextSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if let thingToDo = pick.thingToDo, !thingToDo.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.rwGold)
                            .padding(.top, 2)
                        Text(thingToDo)
                            .font(RWF.body(13))
                            .foregroundColor(.rwTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let resolvedName {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(resolvedName)
                                .font(RWF.med(14))
                                .foregroundColor(.rwTextPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let distanceLabel {
                                    Text(distanceLabel)
                                        .font(RWF.cap(11))
                                        .foregroundColor(.rwTextMuted)
                                }
                                if let resolvedAddress, !resolvedAddress.isEmpty {
                                    Text("·")
                                        .font(RWF.cap(11))
                                        .foregroundColor(.rwTextMuted)
                                    Text(resolvedAddress)
                                        .font(RWF.cap(11))
                                        .foregroundColor(.rwTextMuted)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.rwTextMuted)
                    }
                    .padding(SP.sm)
                    .background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.rwTextMuted)
                        Text("No close match in this area")
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextMuted)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.rwSurface)
                    .clipShape(Capsule())
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(highlighted ? Color.rwAccent.opacity(0.45) : Color.rwBorder,
                            lineWidth: highlighted ? 1.5 : 1)
            )
            .shadow(color: highlighted ? Color.rwAccent.opacity(0.18) : Color.rwShadow,
                    radius: highlighted ? 14 : 8, x: 0, y: highlighted ? 6 : 2)
            .scaleEffect(highlighted ? 1.01 : 1.0)
        }
        .buttonStyle(SBS())
        .disabled(pick.resolved == nil)
        .opacity(pick.resolved == nil ? 0.85 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: highlighted)
    }
}

// MARK: - Location Denied Card

struct LocationDeniedCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash.fill").font(.system(size: 36, design: .rounded)).foregroundColor(.rwTextMuted)
            Text("Location Access Needed").font(RWF.head()).foregroundColor(.rwTextPrimary)
            Text("Enable location in Settings to find venues near you.")
                .font(RWF.body(14)).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings").font(RWF.med()).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(LinearGradient.accent).clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
        .padding(SP.xl).background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
    }
}

// MARK: - FilterChip (shared)

struct FilterChip: View {
    let label: String; let isSelected: Bool; var color: Color = .rwAccent; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(label).font(RWF.cap(12))
                .foregroundColor(isSelected ? .white : .rwTextSecondary)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isSelected ? color : Color.rwSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.clear : Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Midpoint Picker
// Lists archived contacts that have a saved coordinate, calculates the
// geographic midpoint between the user's GPS and the contact's coordinate
// (simple lat/lng average — fine for typical metro use cases), and returns
// it as a SearchLocation.

struct MidpointPickerView: View {
    let userCoordinate: CLLocationCoordinate2D?
    let onPicked: (SearchLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var archive = ArchiveStore.shared

    private var withCoords: [Person] { archive.active.filter { $0.contactCoordinate != nil } }
    private var withoutCoords: [Person] { archive.active.filter { $0.contactCoordinate == nil } }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    header
                    if userCoordinate == nil {
                        noLocationCard
                    } else if withCoords.isEmpty && withoutCoords.isEmpty {
                        emptyArchiveCard
                    } else {
                        if !withCoords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                RWSectionLabel("WITH SAVED LOCATION")
                                VStack(spacing: 8) {
                                    ForEach(withCoords) { p in
                                        contactRow(p, enabled: true)
                                    }
                                }
                            }
                        }
                        if !withoutCoords.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                RWSectionLabel("NO LOCATION SAVED")
                                Text("Add a location on their profile to use them for midpoints.")
                                    .font(RWF.cap(12))
                                    .foregroundColor(.rwTextMuted)
                                VStack(spacing: 8) {
                                    ForEach(withoutCoords) { p in
                                        contactRow(p, enabled: false)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, SP.lg).padding(.top, 12).padding(.bottom, 60)
            }
            .rwBG()
            .navigationTitle("Meet in the Middle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick someone to meet halfway.")
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("We'll center the search on the geographic midpoint between you and them.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func contactRow(_ p: Person, enabled: Bool) -> some View {
        Button {
            guard enabled, let userCoord = userCoordinate, let pCoord = p.contactCoordinate else { return }
            let loc = SearchLocation.midpoint(between: userCoord, and: pCoord, contactName: p.name)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onPicked(loc)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ContactAvatar(person: p, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(p.location.isEmpty ? "—" : p.location)
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if enabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                } else {
                    Text("Add location")
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
            .opacity(enabled ? 1.0 : 0.55)
        }
        .buttonStyle(SBS())
        .disabled(!enabled)
    }

    private var noLocationCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Location needed", systemImage: "location.slash")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text("Turn on Location Services so we can place you on the map. Then you can meet anyone halfway.")
                    .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyArchiveCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("No connections yet", systemImage: "person.2")
                    .font(RWF.cap()).foregroundColor(.rwTextPrimary)
                Text("Add people to your Archive (with their location) to find midpoint meetups.")
                    .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
