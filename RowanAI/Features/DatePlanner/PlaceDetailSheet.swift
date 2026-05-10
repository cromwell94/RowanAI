import SwiftUI
import MapKit
import CoreLocation

// MARK: - Map Snapshot
// Renders an MKMapSnapshot as a static Image with a pink-gradient pin centered
// on the place. Async — shows a soft skeleton until the snapshot finishes.

struct MapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    var size: CGSize = CGSize(width: 320, height: 180)
    var spanMeters: CLLocationDistance = 600

    @State private var snapshot: UIImage? = nil
    @State private var failed = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        ZStack {
            if let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(pinOverlay)
            } else {
                LinearGradient.accentSoft
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .tint(.rwAccent)
                            .opacity(failed ? 0 : 1)
                    )
                    .overlay(
                        Group {
                            if failed {
                                VStack(spacing: 6) {
                                    Image(systemName: "map")
                                        .font(.system(size: 22, design: .rounded))
                                        .foregroundColor(.rwTextMuted)
                                    Text("Map preview unavailable")
                                        .font(RWF.cap(11))
                                        .foregroundColor(.rwTextMuted)
                                }
                            }
                        }
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .task(id: "\(coordinate.latitude),\(coordinate.longitude),\(size.width)x\(size.height)") {
            await loadSnapshot()
        }
    }

    private var pinOverlay: some View {
        ZStack {
            Circle()
                .fill(LinearGradient.accent)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(color: Color.rwAccent.opacity(0.45), radius: 6, x: 0, y: 3)
            Image(systemName: "mappin")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func loadSnapshot() async {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: spanMeters,
            longitudinalMeters: spanMeters)
        options.size = size
        options.scale = displayScale > 0 ? displayScale : 2.0
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll

        do {
            let snap = try await MKMapSnapshotter(options: options).start()
            await MainActor.run { self.snapshot = snap.image }
        } catch {
            await MainActor.run { self.failed = true }
        }
    }
}

// MARK: - Place Detail Sheet
// Full-detail sheet: map snapshot, address, four actions (Directions / Save /
// Add to Plan / Find Nearby), optional contact-tagging when saving.

struct PlaceDetailSheet: View {
    let item: MKMapItem
    let category: VenueCategory
    var distanceLabel: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var wishStore = WishlistStore.shared
    @State private var selectedPersonId: String? = nil
    @State private var notes = ""
    @State private var savedToast = false
    @State private var addedToast = false

    @State private var nearby: [IdentifiableMapItem] = []
    @State private var nearbyLoading = false
    @State private var showNearby = false

    private var name: String { item.name ?? "Place" }
    private var address: String { item.placemark.title ?? "" }
    private var coordinate: CLLocationCoordinate2D { item.placemark.coordinate }

    private var isWishlisted: Bool {
        WishlistStore.shared.isWishlisted(name, address: address)
    }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(Color.rwBorder)
                .frame(width: 40, height: 5)
                .padding(.top, 12).padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.lg) {

                    header
                    snapshotSection
                    actionGrid
                    contactPickerSection
                    notesSection
                    saveButton

                    if showNearby {
                        nearbySection
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 4)
            }
        }
        .background(Color.rwBackground)
    }

    // MARK: header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(RWF.title(24))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(category.rawValue)
                    .font(RWF.micro())
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(category.color.opacity(0.12))
                    .clipShape(Capsule())

                if let distanceLabel {
                    Text(distanceLabel)
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextMuted)
                }
            }

            if !address.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                        .padding(.top, 2)
                    Text(address)
                        .font(RWF.body(14))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: snapshot

    private var snapshotSection: some View {
        GeometryReader { geo in
            MapSnapshotView(
                coordinate: coordinate,
                size: CGSize(width: geo.size.width, height: 180))
        }
        .frame(height: 180)
    }

    // MARK: action grid

    private var actionGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionTile(
                    label: "Directions",
                    icon: "arrow.triangle.turn.up.right.diamond.fill",
                    tint: .rwAccent
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    item.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                }
                actionTile(
                    label: isWishlisted ? "Saved" : "Wishlist",
                    icon: isWishlisted ? "heart.fill" : "heart",
                    tint: isWishlisted ? .rwAccent : .rwTextSecondary,
                    selected: isWishlisted
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if isWishlisted {
                        wishStore.removeBy(name: name, address: address)
                    } else {
                        let venue = Venue(
                            name: name,
                            category: category,
                            address: address,
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude)
                        wishStore.add(venue)
                        savedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { savedToast = false }
                    }
                }
            }
            HStack(spacing: 10) {
                actionTile(
                    label: addedToast ? "Added" : "Add to Date Plan",
                    icon: addedToast ? "checkmark" : "calendar.badge.plus",
                    tint: .rwGold
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let venue = Venue(
                        name: name,
                        category: category,
                        address: address,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        notes: notes,
                        personId: selectedPersonId,
                        personName: ArchiveStore.shared.active.first { $0.id == selectedPersonId }?.name ?? "")
                    wishStore.add(venue)
                    addedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        addedToast = false
                    }
                }
                actionTile(
                    label: nearbyLoading ? "Searching…" : (showNearby ? "Hide Nearby" : "Find Nearby"),
                    icon: nearbyLoading ? "ellipsis" : "magnifyingglass",
                    tint: .rwViolet
                ) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if showNearby {
                        withAnimation(.easeOut(duration: 0.2)) { showNearby = false }
                    } else {
                        Task { await loadNearby() }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if savedToast {
                Text("Saved to wishlist")
                    .font(RWF.cap(12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.rwAccent)
                    .clipShape(Capsule())
                    .offset(y: -28)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: savedToast)
    }

    private func actionTile(label: String, icon: String, tint: Color, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(label).font(RWF.cap(13))
            }
            .foregroundColor(selected ? .white : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.10)))
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(tint.opacity(selected ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    // MARK: contact picker

    @ViewBuilder
    private var contactPickerSection: some View {
        if !ArchiveStore.shared.active.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Tag a connection (optional)", systemImage: "person.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { selectedPersonId = nil } label: {
                            Text("None").font(RWF.cap(12))
                                .foregroundColor(selectedPersonId == nil ? .white : .rwTextMuted)
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(selectedPersonId == nil ? Color(hex: "0D0D0D") : Color.rwSurface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(SBS())

                        ForEach(ArchiveStore.shared.active.prefix(10)) { person in
                            Button { selectedPersonId = person.id } label: {
                                Text(person.name)
                                    .font(RWF.cap(12))
                                    .foregroundColor(selectedPersonId == person.id ? .white : .rwTextSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(selectedPersonId == person.id ? Color(hex: "0D0D0D") : Color.rwSurface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SBS())
                        }
                    }
                }
            }
        }
    }

    // MARK: notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes (optional)", systemImage: "note.text")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
            TextField("Vibe, why you saved this…", text: $notes)
                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                .padding(SP.md).background(Color.rwSurface)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
    }

    // MARK: save button (legacy keep-on-list confirmation)

    @ViewBuilder
    private var saveButton: some View {
        if let phone = item.phoneNumber, let url = URL(string: "tel:\(phone)") {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(phone).font(RWF.med(14))
                }
                .foregroundColor(.rwTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.rwSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
            }
        }
    }

    // MARK: nearby

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RWSectionLabel("SIMILAR NEARBY")
                Spacer()
                if !nearby.isEmpty {
                    Text("\(nearby.count)")
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                }
            }

            if nearbyLoading && nearby.isEmpty {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
            } else if nearby.isEmpty {
                Text("No similar places found nearby.")
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(nearby.prefix(5)) { result in
                        nearbyRow(result)
                    }
                }
            }
        }
    }

    private func nearbyRow(_ result: IdentifiableMapItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            result.item.openInMaps()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(category.color)
                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.item.name ?? "Place")
                        .font(RWF.head(14))
                        .foregroundColor(.rwTextPrimary)
                        .lineLimit(1)
                    if let addr = result.item.placemark.title {
                        Text(addr)
                            .font(RWF.cap(11))
                            .foregroundColor(.rwTextMuted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
            .padding(SP.sm)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    private func loadNearby() async {
        nearbyLoading = true
        showNearby = true
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = category.searchTerm
        req.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1500,
            longitudinalMeters: 1500)
        req.resultTypes = .pointOfInterest
        do {
            let resp = try await MKLocalSearch(request: req).start()
            let mapped = resp.mapItems.map(IdentifiableMapItem.init)
                .filter { $0.item.name != name }
            await MainActor.run {
                self.nearby = Array(mapped.prefix(8))
                self.nearbyLoading = false
            }
        } catch {
            await MainActor.run {
                self.nearby = []
                self.nearbyLoading = false
            }
        }
    }
}

// MARK: - Skeleton row (used by Find Nearby + AI Picks loading state)

struct SkeletonRow: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: RR.sm).fill(Color.rwBorder)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder)
                    .frame(width: 120, height: 11)
                RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder.opacity(0.6))
                    .frame(width: 180, height: 9)
            }
            Spacer()
        }
        .padding(SP.sm)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .opacity(pulse ? 0.55 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

struct SkeletonCard: View {
    @State private var pulse = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Color.rwBorder).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder)
                        .frame(width: 140, height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder.opacity(0.6))
                        .frame(width: 200, height: 10)
                    RoundedRectangle(cornerRadius: 4).fill(Color.rwBorder.opacity(0.4))
                        .frame(width: 100, height: 9)
                }
                Spacer()
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
