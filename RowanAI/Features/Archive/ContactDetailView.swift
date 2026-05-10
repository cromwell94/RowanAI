import SwiftUI
import MapKit
import UserNotifications
import PhotosUI

// MARK: - Full Contact Detail View

struct ContactDetailView: View {
    @State var p: Person
    @State private var store = ArchiveStore.shared
    @State private var showEdit = false
    @State private var showAddDate = false
    @State private var showOutcome = false
    @State private var showPaywall = false
    @State private var showDatePlanner = false
    @State private var showRelationshipPrompt = false
    @State private var dateSuggestions: [DateSuggestion] = []
    @State private var loadingSuggestions = false
    @State private var selectedSection: DetailSection = .overview
    // Bump after the edit sheet dismisses so ContactAvatar re-reads disk.
    @State private var photoVersion = 0
    // Intel-tab photo gallery state
    @State private var intelPhotos: [URL] = []
    @State private var intelPicks: [PhotosPickerItem] = []
    @State private var fullscreenPhotoIndex: Int? = nil
    // Date Planner deep-link state
    @State private var showFindDateSpots = false
    @State private var noLocationAlert = false
    // Photo gallery state
    @State private var showCameraCapture = false
    @State private var photoSourceMenu = false
    @State private var captionTarget: URL? = nil
    @State private var captionDraft: String = ""
    // Contacts sync state
    @State private var syncing = false
    @State private var syncToast: String? = nil

    @Environment(\.dismiss) var dismiss

    enum DetailSection: String, CaseIterable {
        case overview      = "Overview"
        case conversations = "Conversations"
        case dates         = "Dates"
        case intel         = "Intel"
        case photos        = "Photos"
        case notes         = "Notes"
    }

    func loadSuggestions() async {
        guard AISettings.shared.isEnabled else { return }
        loadingSuggestions = true
        dateSuggestions = await Claude.shared.suggestDates(for: p)
        loadingSuggestions = false
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero header
                heroSection

                // Section tabs
                sectionTabs

                // Content
                switch selectedSection {
                case .overview:      overviewSection
                case .conversations: conversationsSection
                case .dates:         datesSection
                case .intel:         intelSection
                case .photos:        photosSection
                case .notes:         notesSection
                }

                Spacer().frame(height: 100)
            }
        }
        .rwBG()
        .navigationTitle(p.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { trailingToolbar }
        .overlay(alignment: .top) { syncToastOverlay }
        .modifier(DetailSheetsModifier(
            p: $p,
            showEdit: $showEdit,
            showAddDate: $showAddDate,
            showOutcome: $showOutcome,
            showRelationshipPrompt: $showRelationshipPrompt,
            showFindDateSpots: $showFindDateSpots,
            noLocationAlert: $noLocationAlert,
            showCameraCapture: $showCameraCapture,
            photoSourceMenu: $photoSourceMenu,
            captionTarget: $captionTarget,
            captionDraft: $captionDraft,
            fullscreenPhotoIndex: $fullscreenPhotoIndex,
            photoVersion: $photoVersion,
            intelPhotos: intelPhotos,
            reloadIntelPhotos: reloadIntelPhotos
        ))
        .onAppear { reloadIntelPhotos() }
        .onDisappear { store.update(p) }
    }

    private func reloadIntelPhotos() {
        intelPhotos = ContactPhotoStore.shared.intelPhotoURLs(contactID: p.id)
    }

    private func ingestIntelPicks() async {
        guard !intelPicks.isEmpty else { return }
        for item in intelPicks {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                _ = ContactPhotoStore.shared.saveIntelPhoto(image, contactID: p.id)
            }
        }
        await MainActor.run {
            intelPicks = []
            reloadIntelPhotos()
        }
    }

    // MARK: - Hero

    var heroSection: some View {
        VStack(spacing: 16) {
            ContactAvatar(person: p, size: 96, showFavoriteBadge: true, version: photoVersion)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(p.name).font(RWF.title(24)).foregroundColor(.rwTextPrimary)
                    if let age = p.age {
                        Text("\(age)").font(RWF.body()).foregroundColor(.rwTextMuted)
                    }
                }
                if !p.occupation.isEmpty || !p.location.isEmpty {
                    Text([p.occupation, p.location].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(RWF.body()).foregroundColor(.rwTextSecondary)
                }

                // Status row
                HStack(spacing: 8) {
                    // Source
                    HStack(spacing: 4) {
                        Image(systemName: p.source.icon).font(.system(size: 10, weight: .semibold, design: .rounded))
                        Text(p.source.rawValue).font(RWF.micro())
                    }
                    .foregroundColor(p.source.color)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(p.source.color.opacity(0.1)).clipShape(Capsule())

                    // Status menu
                    Menu {
                        ForEach(Person.Status.allCases, id: \.rawValue) { s in
                            Button {
                                p.status = s
                                store.update(p)
                            } label: { Label(s.rawValue, systemImage: s.icon) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: p.status.icon).font(.system(size: 10, weight: .semibold, design: .rounded))
                            Text(p.status.rawValue).font(RWF.micro())
                            Image(systemName: "chevron.down").font(.system(size: 8, design: .rounded))
                        }
                        .foregroundColor(p.status.color)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(p.status.color.opacity(0.1)).clipShape(Capsule())
                    }
                    .onChange(of: p.status) { _, newStatus in
                        if (newStatus == .seeingEachOther || newStatus == .gotSerious) && !RelationshipStore.shared.isInRelationship {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showRelationshipPrompt = true
                            }
                        }
                    }
                }
            }

            // Cold warning
            if p.isGoingCold {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.snowflake").font(.system(size: 13, design: .rounded))
                    Text("Going cold — \(p.daysSinceLastSpoke ?? 0) days since last contact")
                        .font(RWF.cap(12))
                    Spacer()
                    Button("Message") {}.font(RWF.cap(12)).foregroundColor(.rwAccent)
                }
                .foregroundColor(Color(hex: "5B8DEF"))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(hex: "5B8DEF").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color(hex: "5B8DEF").opacity(0.2), lineWidth: 1))
                .padding(.horizontal, SP.lg)
            }

            // Quick actions
            HStack(spacing: 12) {
                if !p.phone.isEmpty {
                    QuickAction(icon: "phone.fill", label: "Call", color: Color(hex: "00BFB3")) {
                        if let url = URL(string: "tel:\(p.phone)") { UIApplication.shared.open(url) }
                    }
                }
                if !p.phone.isEmpty {
                    QuickAction(icon: "message.fill", label: "Text", color: Color(hex: "5B8DEF")) {
                        if let url = URL(string: "sms:\(p.phone)") { UIApplication.shared.open(url) }
                    }
                }
                if !p.instagram.isEmpty {
                    QuickAction(icon: "camera.fill", label: "Instagram", color: Color(hex: "E8356D")) {
                        if let url = URL(string: "instagram://user?username=\(p.instagram)") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                QuickAction(icon: "heart.fill", label: p.isFavorite ? "Unfave" : "Favorite",
                    color: p.isFavorite ? .rwAccent : .rwTextMuted) {
                    p.isFavorite.toggle(); store.update(p)
                }
            }
            .padding(.horizontal, SP.lg)

            // Rating
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        p.rating = i; store.update(p)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: i <= p.rating ? "star.fill" : "star")
                            .font(.system(size: 24, design: .rounded))
                            .foregroundColor(i <= p.rating ? Color(hex: "F59E0B") : .rwBorder)
                    }
                    .buttonStyle(SBS())
                }
            }
        }
        .padding(.top, 20).padding(.bottom, 24)
    }

    // MARK: - Section Tabs

    var sectionTabs: some View {
        RWSegmentedPicker<DetailSection>(
            options: [
                (value: .overview,      label: "Overview",      icon: nil),
                (value: .conversations, label: "Conversations", icon: nil),
                (value: .dates,         label: "Dates",         icon: nil),
                (value: .intel,         label: "Intel",         icon: nil),
                (value: .notes,         label: "Notes",         icon: nil),
            ],
            selected: $selectedSection
        )
        .padding(.horizontal, SP.lg)
        .padding(.bottom, 20)
    }

    // MARK: - Overview Section

    var overviewSection: some View {
        VStack(spacing: 14) {

            // Cyrano's Read — living analysis, always at the top.
            CyranoReadCard(person: p)

            // Key facts
            if !p.keyFacts.isEmpty {
                InfoCard(title: "Key Facts", icon: "star.fill", color: Color(hex: "F59E0B")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(p.keyFacts, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(Color(hex: "F59E0B")).frame(width: 5, height: 5).padding(.top, 7)
                                Text(fact).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            // Personal details grid
            InfoCard(title: "About", icon: "person.fill", color: Color(hex: "5B8DEF")) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let age = p.age { DetailPill(label: "Age", value: "\(age)") }
                    if !p.height.isEmpty { DetailPill(label: "Height", value: p.height) }
                    if !p.hometown.isEmpty { DetailPill(label: "Hometown", value: p.hometown) }
                    if !p.school.isEmpty { DetailPill(label: "School", value: p.school) }
                    if !p.occupation.isEmpty { DetailPill(label: "Work", value: p.occupation) }
                    if !p.location.isEmpty { DetailPill(label: "Lives in", value: p.location) }
                }
            }

            findDateSpotsButton

            // Contact info
            if !p.phone.isEmpty || !p.instagram.isEmpty || !p.snapchat.isEmpty {
                InfoCard(title: "Contact", icon: "phone.fill", color: Color(hex: "00BFB3")) {
                    VStack(spacing: 10) {
                        if !p.phone.isEmpty { ContactRow(icon: "phone.fill", value: p.phone, color: Color(hex: "00BFB3")) }
                        if !p.instagram.isEmpty { ContactRow(icon: "camera.fill", value: "@\(p.instagram)", color: Color(hex: "E8356D")) }
                        if !p.snapchat.isEmpty { ContactRow(icon: "camera.viewfinder", value: p.snapchat, color: Color(hex: "F59E0B")) }
                    }
                }
            }

            // Interests
            if !p.interests.isEmpty {
                InfoCard(title: "Interests", icon: "heart.text.square.fill", color: Color(hex: "E8356D")) {
                    FlowLayout(tags: p.interests, color: Color(hex: "E8356D"))
                }
            }

            // Timeline
            InfoCard(title: "Timeline", icon: "calendar", color: Color(hex: "5B8DEF")) {
                VStack(spacing: 8) {
                    TimelineRow(label: "Met on", value: p.source.rawValue, date: nil)
                    TimelineRow(label: "First contact", value: nil, date: p.firstContactDate)
                    if let last = p.lastSpoke {
                        TimelineRow(label: "Last spoke", value: nil, date: last)
                    }
                    TimelineRow(label: "Total dates", value: "\(p.totalDates)", date: nil)
                    if let next = p.nextDatePlanned {
                        TimelineRow(label: "Next date", value: p.nextDateLocation.isEmpty ? "Planned" : p.nextDateLocation, date: next)
                    }
                }
            }

            // Outcome
            if p.outcome != .active {
                InfoCard(title: "Outcome", icon: p.outcome.icon, color: p.outcome.color) {
                    HStack(spacing: 12) {
                        Image(systemName: p.outcome.icon).font(.system(size: 20, design: .rounded))
                            .foregroundColor(p.outcome.color)
                            .frame(width: 44, height: 44).background(p.outcome.color.opacity(0.1))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.outcome.rawValue).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                            if !p.outcomeNotes.isEmpty {
                                Text(p.outcomeNotes).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                            }
                        }
                    }
                }
            }

            // Cyrano Date Suggestions
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    Text("Cyrano's Date Ideas").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Spacer()
                    if !dateSuggestions.isEmpty {
                        Button {
                            dateSuggestions = []
                            Task { await loadSuggestions() }
                        } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 13, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                        }
                    }
                }

                if loadingSuggestions {
                    HStack(spacing: 10) {
                        ProgressView().tint(.rwAccent)
                        Text("Thinking about \(p.name)...").font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    }
                    .padding(SP.md).background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                } else if dateSuggestions.isEmpty {
                    Button { Task { await loadSuggestions() } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(LinearGradient.accent)
                            Text("Get personalised date ideas for \(p.name)")
                                .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.rwTextMuted)
                        }
                        .padding(SP.md).background(Color.rwSurface)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                } else {
                    ForEach(dateSuggestions) { s in
                        ContactDateSuggestionCard(suggestion: s)
                    }
                }
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)

            // Action buttons
            VStack(spacing: 10) {
                RWButton("Log a Date", icon: "calendar.badge.plus", style: .secondary) {
                    showAddDate = true
                }
                RWButton("Record Outcome", icon: "checkmark.circle", style: .secondary) {
                    showOutcome = true
                }
                RWButton("Archive \(p.name)", icon: "archivebox", style: .ghost) {
                    store.archive(p); dismiss()
                }
            }
        }
        .padding(.horizontal, SP.lg)
    }

    // MARK: - Find Date Spots Action
    // Anchors Date Planner on the contact's saved coordinates. Falls back
    // to an alert offering to add their location or search near the user.

    private var findDateSpotsButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if p.contactCoordinate != nil {
                showFindDateSpots = true
            } else {
                noLocationAlert = true
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "map.fill")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(LinearGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Find date spots near \(p.name)")
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                    Text(p.contactCoordinate != nil
                         ? (p.location.isEmpty ? "Anchor the search on their saved area" : "Around \(p.location)")
                         : "Add a location on their profile to use this")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient.accent.opacity(0.4), lineWidth: 1))
            .shadow(color: Color.rwAccent.opacity(0.10), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(SBS())
    }

    // MARK: - Dates Section

    var datesSection: some View {
        VStack(spacing: 14) {
            if p.dateHistory.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus").font(.system(size: 44, design: .rounded)).foregroundColor(.rwTextMuted)
                    Text("No dates logged yet").font(RWF.head()).foregroundColor(.rwTextSecondary)
                    Text("Log your dates to track how things are progressing.")
                        .font(RWF.body()).foregroundColor(.rwTextMuted).multilineTextAlignment(.center)
                    RWButton("Log First Date", icon: "plus") { showAddDate = true }
                }
                .padding(.vertical, 40)
            } else {
                // Stats row
                HStack(spacing: 12) {
                    DateStat(value: "\(p.totalDates)", label: "Total Dates")
                    DateStat(value: avgRating, label: "Avg Rating")
                    DateStat(value: successRate, label: "Went Well")
                }

                ForEach(p.dateHistory.sorted { $0.date > $1.date }) { entry in
                    DateEntryCard(entry: entry)
                }

                RWButton("Log Another Date", icon: "plus", style: .secondary) { showAddDate = true }
            }
        }
        .padding(.horizontal, SP.lg)
    }

    var avgRating: String {
        guard !p.dateHistory.isEmpty else { return "—" }
        let avg = Double(p.dateHistory.map { $0.rating }.reduce(0, +)) / Double(p.dateHistory.count)
        return String(format: "%.1f", avg)
    }

    var successRate: String {
        guard !p.dateHistory.isEmpty else { return "—" }
        let good = p.dateHistory.filter { $0.wentWell }.count
        return "\(Int(Double(good) / Double(p.dateHistory.count) * 100))%"
    }

    // MARK: - Intel Section

    var intelSection: some View {
        VStack(spacing: 14) {

            photosCard

            if !p.thingsToAsk.isEmpty {
                InfoCard(title: "Things to Ask", icon: "questionmark.bubble.fill", color: Color(hex: "5B8DEF")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.thingsToAsk, id: \.self) { q in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 12, design: .rounded)).foregroundColor(Color(hex: "5B8DEF"))
                                Text(q).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !p.greenFlags.isEmpty {
                InfoCard(title: "Green Flags", icon: "checkmark.seal.fill", color: Color(hex: "00BFB3")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.greenFlags, id: \.self) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(Color(hex: "00BFB3")).frame(width: 5, height: 5).padding(.top, 7)
                                Text(flag).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !p.redFlags.isEmpty {
                InfoCard(title: "Red Flags", icon: "exclamationmark.triangle.fill", color: Color(hex: "E8356D")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.redFlags, id: \.self) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(Color(hex: "E8356D")).frame(width: 5, height: 5).padding(.top, 7)
                                Text(flag).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !p.thingsToAvoid.isEmpty {
                InfoCard(title: "Things to Avoid", icon: "nosign", color: Color(hex: "F59E0B")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(p.thingsToAvoid, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 12, design: .rounded)).foregroundColor(Color(hex: "F59E0B"))
                                Text(item).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !p.dealBreakers.isEmpty {
                InfoCard(title: "Deal Breakers", icon: "xmark.octagon.fill", color: Color(hex: "E8356D")) {
                    FlowLayout(tags: p.dealBreakers, color: Color(hex: "E8356D"))
                }
            }

            if p.thingsToAsk.isEmpty && p.greenFlags.isEmpty && p.redFlags.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "brain.head.profile").font(.system(size: 44, design: .rounded)).foregroundColor(.rwTextMuted)
                    Text("No intel yet").font(RWF.head()).foregroundColor(.rwTextSecondary)
                    Text("Add flags, questions, and things to remember when you edit this contact.")
                        .font(RWF.body()).foregroundColor(.rwTextMuted).multilineTextAlignment(.center)
                    RWButton("Add Intel", icon: "plus", style: .secondary) { showEdit = true }
                }
                .padding(.vertical, 40)
            }
        }
        .padding(.horizontal, SP.lg)
    }

    // MARK: - Intel Photos Card

    private var photosCard: some View {
        InfoCard(title: "Photos", icon: "photo.on.rectangle.angled", color: Color(hex: "9B59B6")) {
            VStack(alignment: .leading, spacing: 10) {
                if intelPhotos.isEmpty {
                    HStack {
                        Text("No photos yet")
                            .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        Spacer()
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6),
                                        GridItem(.flexible(), spacing: 6),
                                        GridItem(.flexible(), spacing: 6)], spacing: 8) {
                        ForEach(Array(intelPhotos.enumerated()), id: \.element) { idx, url in
                            VStack(spacing: 3) {
                                IntelPhotoThumbnail(url: url)
                                    .onTapGesture { fullscreenPhotoIndex = idx }
                                    .onLongPressGesture {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        captionDraft = ContactPhotoStore.shared.caption(for: url)
                                        captionTarget = url
                                    }
                                Text(ContactPhotoStore.shared.addedDate(for: url),
                                     format: .dateTime.day().month(.abbreviated))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(.rwTextMuted)
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    PhotosPicker(selection: $intelPicks,
                                 maxSelectionCount: 8,
                                 matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .font(RWF.cap()).foregroundColor(Color(hex: "9B59B6"))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color(hex: "9B59B6").opacity(0.10))
                            .clipShape(Capsule())
                    }
                    if UIImagePickerController.hasCamera {
                        Button { showCameraCapture = true } label: {
                            Label("Take photo", systemImage: "camera.fill")
                                .font(RWF.cap()).foregroundColor(Color(hex: "9B59B6"))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(hex: "9B59B6").opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(SBS())
                    }
                }
                .onChange(of: intelPicks) { _, _ in
                    Task { await ingestIntelPicks() }
                }
                Text("Long-press a photo to add a caption or delete it.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
        }
    }

    // MARK: - Photos Section (full-screen Photos tab — iOS Photos style)

    var photosSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $intelPicks,
                             maxSelectionCount: 8,
                             matching: .images) {
                    Label("Add", systemImage: "plus")
                        .font(RWF.cap()).foregroundColor(.rwAccent)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.rwAccent.opacity(0.10))
                        .clipShape(Capsule())
                }
                if UIImagePickerController.hasCamera {
                    Button { showCameraCapture = true } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .font(RWF.cap()).foregroundColor(.rwAccent)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.rwAccent.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(SBS())
                }
                Spacer()
                Text("\(intelPhotos.count) \(intelPhotos.count == 1 ? "photo" : "photos")")
                    .font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
            }

            if intelPhotos.isEmpty {
                RWEmptyState(
                    icon: "photo.on.rectangle.angled",
                    title: "No photos yet",
                    subtitle: "Snap a photo or add from your library — they'll all live here in one beautiful gallery.",
                    cta: "Add Photo",
                    ctaIcon: "plus",
                    onCTA: { photoSourceMenu = true }
                )
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 3),
                                    GridItem(.flexible(), spacing: 3),
                                    GridItem(.flexible(), spacing: 3)], spacing: 3) {
                    ForEach(Array(intelPhotos.enumerated()), id: \.element) { idx, url in
                        IntelPhotoThumbnail(url: url)
                            .onTapGesture { fullscreenPhotoIndex = idx }
                            .onLongPressGesture {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                captionDraft = ContactPhotoStore.shared.caption(for: url)
                                captionTarget = url
                            }
                    }
                }
            }
        }
        .padding(.horizontal, SP.lg)
        .onChange(of: intelPicks) { _, _ in
            Task { await ingestIntelPicks() }
        }
    }

    // MARK: - Notes Section

    var notesSection: some View {
        VStack(spacing: 14) {
            if !p.notes.isEmpty {
                InfoCard(title: "Notes", icon: "note.text", color: Color(hex: "5B8DEF")) {
                    Text(p.notes).font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !p.privateNotes.isEmpty {
                InfoCard(title: "Private Notes", icon: "lock.fill", color: Color(hex: "9BA8BF")) {
                    Text(p.privateNotes).font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if p.notes.isEmpty && p.privateNotes.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "note.text").font(.system(size: 44, design: .rounded)).foregroundColor(.rwTextMuted)
                    Text("No notes yet").font(RWF.head()).foregroundColor(.rwTextSecondary)
                    RWButton("Add Notes", icon: "plus", style: .secondary) { showEdit = true }
                }
                .padding(.vertical, 40)
            }
        }
        .padding(.horizontal, SP.lg)
    }

    // MARK: - Conversations Section

    var conversationsSection: some View {
        ConversationsTabContent(person: p)
            .padding(.horizontal, SP.lg)
    }

    // MARK: - Toolbar + Sync Toast (extracted to keep body type-checker fast)

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                if !(p.iosContactIdentifier ?? "").isEmpty {
                    syncButton
                }
                Button("Edit") { showEdit = true }.foregroundColor(.rwAccent)
            }
        }
    }

    private var syncButton: some View {
        Button { triggerSync() } label: {
            Image(systemName: syncing
                  ? "arrow.triangle.2.circlepath"
                  : "arrow.triangle.2.circlepath.circle")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.rwAccent)
                .rotationEffect(.degrees(syncing ? 360 : 0))
                .animation(syncing
                           ? .linear(duration: 1).repeatForever(autoreverses: false)
                           : .default,
                           value: syncing)
        }
        .disabled(syncing)
    }

    @ViewBuilder
    private var syncToastOverlay: some View {
        if let toast = syncToast {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundColor(.rwSuccess)
                Text(toast).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Color.rwCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 4)
            .padding(.top, 8)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Contacts Sync

    private func triggerSync() {
        guard !syncing else { return }
        syncing = true
        Task {
            let outcome = await ContactSyncService.sync(p)
            // Pull the freshest Person back from the store so the view
            // reflects whatever the sync mutated (and so subsequent edits
            // start from the synced state, not a stale snapshot).
            if case .updated(_) = outcome {
                if let fresh = ArchiveStore.shared.people.first(where: { $0.id == p.id }) {
                    p = fresh
                }
                photoVersion &+= 1
            }
            syncing = false
            withAnimation(.spring(response: 0.4)) {
                syncToast = outcome.userMessage
            }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.3)) { syncToast = nil }
        }
    }
}

// MARK: - Detail Sheets Modifier
//
// Bundles every sheet/alert/cover/dialog the detail view needs into a single
// ViewModifier. Without this extraction the body's modifier chain is long
// enough to time out SwiftUI's type checker.

private struct DetailSheetsModifier: ViewModifier {
    @Binding var p: Person
    @Binding var showEdit: Bool
    @Binding var showAddDate: Bool
    @Binding var showOutcome: Bool
    @Binding var showRelationshipPrompt: Bool
    @Binding var showFindDateSpots: Bool
    @Binding var noLocationAlert: Bool
    @Binding var showCameraCapture: Bool
    @Binding var photoSourceMenu: Bool
    @Binding var captionTarget: URL?
    @Binding var captionDraft: String
    @Binding var fullscreenPhotoIndex: Int?
    @Binding var photoVersion: Int

    let intelPhotos: [URL]
    let reloadIntelPhotos: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showEdit, onDismiss: {
                photoVersion &+= 1
                reloadIntelPhotos()
            }) { EditContactView(p: $p) }
            .sheet(isPresented: $showAddDate) { AddDateView(p: $p) }
            .sheet(isPresented: $showOutcome) { OutcomeView(p: $p) }
            .sheet(isPresented: $showRelationshipPrompt) { MoveToRelationshipView(p: p) }
            .sheet(isPresented: $showFindDateSpots) { findDateSpotsSheet }
            .alert("No saved location for \(p.name)", isPresented: $noLocationAlert) {
                Button("Add their location") { showEdit = true }
                Button("Search near you instead") { showFindDateSpots = true }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Add a location on their profile so we can anchor the search there.")
            }
            .fullScreenCover(isPresented: $showCameraCapture) { cameraCaptureSheet }
            .sheet(item: captionBinding) { target in
                captionEditorSheet(target: target)
            }
            .confirmationDialog("Add a photo",
                                isPresented: $photoSourceMenu,
                                titleVisibility: .visible) {
                Button("Take Photo") { showCameraCapture = true }
                Button("Choose from Library") { /* PhotosPicker is on the main button row */ }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(item: indexBinding) { box in
                IntelPhotoFullscreen(urls: intelPhotos, startIndex: box.index)
            }
    }

    // MARK: - Sub-view builders (each one keeps the parent body lean)

    private var findDateSpotsSheet: some View {
        DatePlannerView(
            initialSearchLocation: p.contactCoordinate.map {
                SearchLocation(
                    title: "Date spots near \(p.name)",
                    subtitle: p.location.isEmpty ? nil : p.location,
                    coordinate: $0,
                    kind: .contact(p.name)
                )
            },
            initialCategory: .restaurants,
            modalDismiss: { showFindDateSpots = false }
        )
    }

    private var cameraCaptureSheet: some View {
        CameraCaptureSheet(
            onPicked: { image in
                showCameraCapture = false
                _ = ContactPhotoStore.shared.saveIntelPhoto(image, contactID: p.id)
                reloadIntelPhotos()
            },
            onCancel: { showCameraCapture = false }
        )
        .ignoresSafeArea()
    }

    private func captionEditorSheet(target: CaptionTarget) -> some View {
        CaptionEditorSheet(
            url: target.url,
            draft: $captionDraft,
            onSave: { newCaption in
                ContactPhotoStore.shared.setCaption(newCaption, for: target.url)
                captionTarget = nil
                reloadIntelPhotos()
            },
            onDelete: {
                ContactPhotoStore.shared.deleteIntelPhoto(at: target.url)
                captionTarget = nil
                reloadIntelPhotos()
            },
            onCancel: { captionTarget = nil }
        )
    }

    // Bindings that wrap the optional state into the Identifiable types the
    // sheet/cover modifiers expect.

    private var captionBinding: Binding<CaptionTarget?> {
        Binding(
            get: { captionTarget.map { CaptionTarget(url: $0) } },
            set: { captionTarget = $0?.url }
        )
    }

    private var indexBinding: Binding<IndexBox?> {
        Binding(
            get: { fullscreenPhotoIndex.map { IndexBox(index: $0) } },
            set: { fullscreenPhotoIndex = $0?.index }
        )
    }
}

// MARK: - Supporting Components

struct QuickAction: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(color).frame(width: 48, height: 48)
                    .background(color.opacity(0.1)).clipShape(Circle())
                Text(label).font(RWF.micro()).foregroundColor(.rwTextSecondary)
            }
        }
        .buttonStyle(SBS())
        .frame(maxWidth: .infinity)
    }
}

struct InfoCard<Content: View>: View {
    let title: String; let icon: String; let color: Color; let content: Content
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title; self.icon = icon; self.color = color; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                Text(title).font(RWF.cap()).foregroundColor(.rwTextSecondary).tracking(0.5)
            }
            content
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
    }
}

struct DetailPill: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(RWF.micro()).foregroundColor(.rwTextMuted)
            Text(value).font(RWF.med(14)).foregroundColor(.rwTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SP.sm).background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.md))
    }
}

struct ContactRow: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(color).frame(width: 32, height: 32)
                .background(color.opacity(0.1)).clipShape(Circle())
            Text(value).font(RWF.body()).foregroundColor(.rwTextPrimary)
            Spacer()
            Button {
                UIPasteboard.general.string = value
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 13, design: .rounded)).foregroundColor(.rwTextMuted)
            }
        }
    }
}

struct TimelineRow: View {
    let label: String; let value: String?; let date: Date?
    var body: some View {
        HStack {
            Text(label).font(RWF.body(14)).foregroundColor(.rwTextSecondary)
            Spacer()
            if let v = value { Text(v).font(RWF.med(14)).foregroundColor(.rwTextPrimary) }
            else if let d = date { Text(d.formatted(date: .abbreviated, time: .omitted)).font(RWF.med(14)).foregroundColor(.rwTextPrimary) }
        }
    }
}

struct FlowLayout: View {
    let tags: [String]; let color: Color
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag).font(RWF.cap(12)).foregroundColor(color)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(color.opacity(0.08)).clipShape(Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
            }
        }
    }
}

struct DateStat: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(RWF.display(24)).foregroundStyle(LinearGradient.accent)
            Text(label).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(SP.md)
        .background(Color.rwSurface).clipShape(RoundedRectangle(cornerRadius: RR.lg))
    }
}

struct DateEntryCard: View {
    let entry: DateEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.formatted(date: .long, time: .omitted))
                    .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= entry.rating ? "star.fill" : "star")
                            .font(.system(size: 12, design: .rounded)).foregroundColor(i <= entry.rating ? Color(hex: "F59E0B") : .rwBorder)
                    }
                }
            }
            if !entry.location.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill").font(.system(size: 12, design: .rounded))
                    Text(entry.location).font(RWF.body(13))
                }
                .foregroundColor(.rwTextSecondary)
            }
            HStack(spacing: 8) {
                Label(entry.wentWell ? "Went well" : "Not great",
                    systemImage: entry.wentWell ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(RWF.cap(12))
                    .foregroundColor(entry.wentWell ? Color(hex: "00BFB3") : Color(hex: "E8356D"))
                if let again = entry.willSeeAgain {
                    Text("·").foregroundColor(.rwTextMuted)
                    Text(again ? "Will see again" : "Won't see again")
                        .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                }
            }
            if !entry.notes.isEmpty {
                Text(entry.notes).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Add Date Sheet

struct AddDateView: View {
    @Binding var p: Person
    @Environment(\.dismiss) var dismiss
    @State private var store = ArchiveStore.shared
    @State private var entry = DateEntry()
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.xl) {
                    OBHead(step: "Log a Date", title: "How did it\ngo with \(p.name)?", sub: "Just the facts.")

                    VStack(spacing: 16) {
                        // Date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Label("When?", systemImage: "calendar").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            DatePicker("", selection: $entry.date, displayedComponents: .date)
                                .datePickerStyle(.compact).labelsHidden()
                                .padding(SP.md).background(Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                        }

                        // Location
                        SF(label: "Where?", icon: "mappin.circle.fill", ph: "Restaurant, bar, park...", text: $entry.location)

                        // Rating
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Overall vibe?", systemImage: "star.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { i in
                                    Button { entry.rating = i } label: {
                                        Image(systemName: i <= entry.rating ? "star.fill" : "star")
                                            .font(.system(size: 32, design: .rounded))
                                            .foregroundColor(i <= entry.rating ? Color(hex: "F59E0B") : .rwBorder)
                                    }
                                    .buttonStyle(SBS())
                                }
                            }
                        }

                        // Went well
                        VStack(alignment: .leading, spacing: 8) {
                            Label("How did it go?", systemImage: "heart.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            HStack(spacing: 10) {
                                Toggle2Button(title: "Went well", icon: "checkmark.circle.fill",
                                    color: Color(hex: "00BFB3"), isOn: entry.wentWell) {
                                    entry.wentWell = true
                                }
                                Toggle2Button(title: "Not great", icon: "xmark.circle.fill",
                                    color: Color(hex: "E8356D"), isOn: !entry.wentWell) {
                                    entry.wentWell = false
                                }
                            }
                        }

                        // See again
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Would you see them again?", systemImage: "arrow.clockwise").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            HStack(spacing: 10) {
                                Toggle2Button(title: "Yes", icon: "heart.fill",
                                    color: Color(hex: "E8356D"), isOn: entry.willSeeAgain == true) {
                                    entry.willSeeAgain = true
                                }
                                Toggle2Button(title: "Not sure", icon: "questionmark.circle.fill",
                                    color: Color(hex: "9BA8BF"), isOn: entry.willSeeAgain == nil) {
                                    entry.willSeeAgain = nil
                                }
                                Toggle2Button(title: "No", icon: "xmark.circle.fill",
                                    color: Color(hex: "5B8DEF"), isOn: entry.willSeeAgain == false) {
                                    entry.willSeeAgain = false
                                }
                            }
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes (optional)", systemImage: "note.text").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            ZStack(alignment: .topLeading) {
                                if entry.notes.isEmpty {
                                    Text("Anything worth remembering...").font(RWF.body()).foregroundColor(.rwTextMuted)
                                        .padding(.horizontal, 4).padding(.vertical, 12).allowsHitTesting(false)
                                }
                                TextEditor(text: $entry.notes)
                                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .frame(minHeight: 80).scrollContentBackground(.hidden).focused($notesFocused)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(notesFocused ? Color.rwAccent.opacity(0.3) : Color.rwBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, SP.xl)

                    RWButton("Save Date", icon: "checkmark") {
                        p.dateHistory.append(entry)
                        p.lastSpoke = entry.date
                        store.update(p)
                        StreakManager.shared.addPoints(10, reason: "date")
                        dismiss()
                    }
                    .padding(.horizontal, SP.xl).padding(.bottom, 48)
                }
                .padding(.top, 20)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
            }
        }
    }
}

struct Toggle2Button: View {
    let title: String; let icon: String; let color: Color; let isOn: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(title).font(RWF.cap(13))
            }
            .foregroundColor(isOn ? .white : .rwTextSecondary)
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .background(isOn ? color : Color.rwSurface)
            .clipShape(RoundedRectangle(cornerRadius: RR.md))
            .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(isOn ? Color.clear : Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
        .animation(.spring(response: 0.3), value: isOn)
    }
}

// MARK: - Outcome Sheet

struct OutcomeView: View {
    @Binding var p: Person
    @Environment(\.dismiss) var dismiss
    @State private var store = ArchiveStore.shared
    @State private var selected: Person.Outcome = .active
    @State private var notes = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.xl) {
                    OBHead(step: "Outcome", title: "Where did\nthings go?", sub: "Be honest — this is just for you.")

                    VStack(spacing: 10) {
                        ForEach(Person.Outcome.allCases.filter { $0 != .active }, id: \.rawValue) { outcome in
                            Button { withAnimation { selected = outcome } } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: outcome.icon).font(.system(size: 18, weight: .semibold, design: .rounded))
                                        .foregroundColor(selected == outcome ? .white : outcome.color)
                                        .frame(width: 46, height: 46)
                                        .background(selected == outcome ? outcome.color : outcome.color.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                                    Text(outcome.rawValue).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                                    Spacer()
                                    if selected == outcome {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(outcome.color).font(.system(size: 20, design: .rounded))
                                    }
                                }
                                .padding(SP.md)
                                .background(selected == outcome ? outcome.color.opacity(0.06) : Color.rwCard)
                                .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                                .overlay(RoundedRectangle(cornerRadius: RR.xl)
                                    .stroke(selected == outcome ? outcome.color.opacity(0.4) : Color.rwBorder,
                                            lineWidth: selected == outcome ? 1.5 : 1))
                            }
                            .buttonStyle(SBS())
                        }
                    }
                    .padding(.horizontal, SP.xl)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notes (optional)", systemImage: "note.text").font(RWF.cap()).foregroundColor(.rwTextMuted)
                            .padding(.horizontal, SP.xl)
                        TextField("", text: $notes, prompt: Text("What happened...").foregroundColor(.rwTextMuted))
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                            .padding(.horizontal, SP.xl)
                    }

                    RWButton("Save Outcome", icon: "checkmark") {
                        p.outcome = selected
                        p.outcomeDate = Date()
                        p.outcomeNotes = notes
                        if selected != .active && selected != .stillDating {
                            p.status = .movedOn
                        }
                        store.update(p)
                        dismiss()
                    }
                    .padding(.horizontal, SP.xl).padding(.bottom, 48)
                }
                .padding(.top, 20)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
            }
        }
        .onAppear { selected = p.outcome == .active ? .stillDating : p.outcome }
    }
}

// MARK: - Full Edit Contact View

struct EditContactView: View {
    @Binding var p: Person
    @State private var store = ArchiveStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var newInterest = ""
    @State private var newGreenFlag = ""
    @State private var newRedFlag = ""
    @State private var newKeyFact = ""
    @State private var newThingToAsk = ""
    @State private var newThingToAvoid = ""
    @State private var selectedTab = 0
    @State private var profilePick: PhotosPickerItem? = nil
    @State private var profilePhotoVersion = 0
    @State private var locationCompleter = LocationSearchCompleter()
    @FocusState private var locationFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["Basic", "Contact", "Personal", "Intel", "Notes"].enumerated().map { $0 }, id: \.offset) { i, tab in
                            Button(tab) { withAnimation { selectedTab = i } }
                                .font(RWF.cap(12))
                                .foregroundColor(selectedTab == i ? .white : .rwTextSecondary)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selectedTab == i ? Color(hex: "0D0D0D") : Color.rwSurface)
                                .clipShape(Capsule())
                                .buttonStyle(SBS())
                        }
                    }
                    .padding(.horizontal, SP.lg)
                }
                .padding(.vertical, 10)

                RWLine()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        switch selectedTab {
                        case 0: basicTab
                        case 1: contactTab
                        case 2: personalTab
                        case 3: intelTab
                        default: notesTab
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, SP.lg).padding(.top, 16)
                }
                .rwBG()
            }
            .rwBG()
            .navigationTitle("Edit \(p.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { store.update(p); dismiss() }
                        .font(RWF.med()).foregroundColor(.rwAccent)
                }
            }
        }
    }

    var profilePhotoSection: some View {
        HStack(spacing: 14) {
            ContactAvatar(person: p, size: 64, version: profilePhotoVersion)
            VStack(alignment: .leading, spacing: 6) {
                Text("Profile Photo").font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                HStack(spacing: 8) {
                    PhotosPicker(selection: $profilePick, matching: .images) {
                        Label("Choose photo", systemImage: "photo.on.rectangle")
                            .font(RWF.cap(12)).foregroundColor(.rwAccent)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.rwAccent.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    if ContactPhotoStore.shared.loadProfilePhoto(contactID: p.id) != nil {
                        Button {
                            ContactPhotoStore.shared.deleteProfilePhoto(contactID: p.id)
                            profilePhotoVersion &+= 1
                        } label: {
                            Label("Remove", systemImage: "trash")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.rwSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .onChange(of: profilePick) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    ContactPhotoStore.shared.saveProfilePhoto(image, contactID: p.id)
                    await MainActor.run {
                        profilePhotoVersion &+= 1
                        profilePick = nil
                    }
                }
            }
        }
    }

    // Location field with MKLocalSearchCompleter autocomplete. Picking a
    // suggestion writes both the canonical address string and the geocoded
    // coordinates back onto the Person, which downstream powers Date Planner
    // "near this contact" and the midpoint feature.
    private var locationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Location", systemImage: "location.fill")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
            HStack(spacing: 8) {
                TextField("", text: Binding(
                    get: { locationCompleter.query.isEmpty ? p.location : locationCompleter.query },
                    set: { locationCompleter.query = $0; p.location = $0 }
                ), prompt: Text("City or neighborhood").foregroundColor(.rwTextMuted))
                .focused($locationFocused)
                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                .autocorrectionDisabled()
                if p.contactCoordinate != nil {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.rwAccent)
                }
                if !p.location.isEmpty || !locationCompleter.query.isEmpty {
                    Button {
                        p.location = ""
                        p.contactLatitude = nil
                        p.contactLongitude = nil
                        locationCompleter.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.rwTextMuted)
                    }
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(locationFocused ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))

            // Autocomplete suggestions
            if locationFocused && !locationCompleter.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(locationCompleter.suggestions.prefix(5).enumerated()), id: \.offset) { idx, completion in
                        Button { Task { await pickLocation(completion) } } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.rwAccent)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .buttonStyle(SBS())
                        if idx < min(4, locationCompleter.suggestions.count - 1) {
                            Divider().padding(.leading, 38)
                        }
                    }
                }
                .background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 4)
            }

            if p.contactCoordinate != nil {
                Text("Saved with coordinates — Date Planner can anchor here.")
                    .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
            }
        }
    }

    @MainActor
    private func pickLocation(_ completion: MKLocalSearchCompletion) async {
        guard let resolved = await locationCompleter.resolve(completion) else { return }
        let canonical = resolved.subtitle.isEmpty
            ? resolved.title
            : "\(resolved.title), \(resolved.subtitle)"
        p.location = canonical
        p.contactLatitude  = resolved.coordinate.latitude
        p.contactLongitude = resolved.coordinate.longitude
        locationCompleter.clear()
        locationFocused = false
    }

    var basicTab: some View {
        VStack(spacing: 12) {
            profilePhotoSection
            SF(label: "Name", icon: "person.fill", ph: "Name", text: $p.name)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Age", systemImage: "calendar.circle").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("", value: $p.age, format: .number, prompt: Text("—").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary).keyboardType(.numberPad)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                }
                SF(label: "Height", icon: "ruler", ph: "5'9\"", text: $p.height)
            }
            SF(label: "Occupation", icon: "briefcase.fill", ph: "What do they do?", text: $p.occupation)
            locationField
            SF(label: "Hometown", icon: "house.fill", ph: "Where are they from?", text: $p.hometown)
            SF(label: "School", icon: "graduationcap.fill", ph: "University, college...", text: $p.school)

            // Source picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Where did you meet?", systemImage: "map.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 8) {
                    ForEach(Person.Source.allCases, id: \.rawValue) { s in
                        Button { p.source = s } label: {
                            VStack(spacing: 4) {
                                Image(systemName: s.icon).font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(p.source == s ? .white : s.color)
                                    .frame(width: 36, height: 36)
                                    .background(p.source == s ? s.color : s.color.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                                Text(s.rawValue).font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(p.source == s ? .rwTextPrimary : .rwTextMuted)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .padding(8)
                            .background(p.source == s ? s.color.opacity(0.1) : Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(p.source == s ? s.color.opacity(0.4) : Color.rwBorder, lineWidth: 1))
                        }
                        .buttonStyle(SBS())
                    }
                }
            }

            // Next date planned
            VStack(alignment: .leading, spacing: 8) {
                Label("Next date planned?", systemImage: "calendar.badge.plus").font(RWF.cap()).foregroundColor(.rwTextMuted)
                if p.nextDatePlanned != nil {
                    DatePicker("", selection: Binding(
                        get: { p.nextDatePlanned ?? Date() },
                        set: { p.nextDatePlanned = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact).labelsHidden()
                    .padding(SP.md).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    SF(label: "Location", icon: "mappin.circle.fill", ph: "Where?", text: $p.nextDateLocation)
                    Button { p.nextDatePlanned = nil } label: {
                        Text("Remove planned date").font(RWF.cap()).foregroundColor(.rwDanger)
                    }
                } else {
                    Button { p.nextDatePlanned = Calendar.current.date(byAdding: .day, value: 7, to: Date()) } label: {
                        Label("Set a planned date", systemImage: "plus.circle")
                            .font(RWF.body()).foregroundColor(.rwAccent)
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(SBS())
                }
            }
        }
    }

    var contactTab: some View {
        VStack(spacing: 12) {
            SF(label: "Phone", icon: "phone.fill", ph: "Phone number", text: $p.phone)
            SF(label: "Instagram", icon: "camera.fill", ph: "@handle", text: $p.instagram)
            SF(label: "Snapchat", icon: "camera.viewfinder", ph: "Username", text: $p.snapchat)
            SF(label: "Twitter/X", icon: "at", ph: "@handle", text: $p.twitter)
        }
    }

    var personalTab: some View {
        VStack(spacing: 16) {
            TagEditor(title: "Interests", icon: "heart.text.square.fill", color: Color(hex: "E8356D"),
                tags: $p.interests, newTag: $newInterest, placeholder: "hiking, cooking, jazz...")
            TagEditor(title: "Key Facts to Remember", icon: "star.fill", color: Color(hex: "F59E0B"),
                tags: $p.keyFacts, newTag: $newKeyFact, placeholder: "Has a dog named Max...")
        }
    }

    var intelTab: some View {
        VStack(spacing: 16) {
            TagEditor(title: "Green Flags", icon: "checkmark.seal.fill", color: Color(hex: "00BFB3"),
                tags: $p.greenFlags, newTag: $newGreenFlag, placeholder: "Great communicator...")
            TagEditor(title: "Red Flags", icon: "exclamationmark.triangle.fill", color: Color(hex: "E8356D"),
                tags: $p.redFlags, newTag: $newThingToAvoid, placeholder: "Vague about their past...")
            TagEditor(title: "Things to Ask", icon: "questionmark.bubble.fill", color: Color(hex: "5B8DEF"),
                tags: $p.thingsToAsk, newTag: $newThingToAsk, placeholder: "What happened in Berlin?...")
            TagEditor(title: "Things to Avoid", icon: "nosign", color: Color(hex: "F59E0B"),
                tags: $p.thingsToAvoid, newTag: $newThingToAvoid, placeholder: "Don't mention their ex...")
        }
    }

    var notesTab: some View {
        VStack(spacing: 12) {
            LargeTextEditor(label: "Notes", icon: "note.text", ph: "General notes...", text: $p.notes)
            LargeTextEditor(label: "Private Notes", icon: "lock.fill", ph: "Just for you — never shown to anyone...", text: $p.privateNotes)
        }
    }
}

struct TagEditor: View {
    let title: String; let icon: String; let color: Color
    @Binding var tags: [String]
    @Binding var newTag: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(RWF.cap()).foregroundColor(color)
            if !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(RWF.cap(12)).foregroundColor(color)
                            Button { tags.removeAll { $0 == tag } } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(color)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(color.opacity(0.08)).clipShape(Capsule())
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("", text: $newTag, prompt: Text(placeholder).foregroundColor(.rwTextMuted))
                    .font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                Button {
                    let t = newTag.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty && !tags.contains(t) { tags.append(t); newTag = "" }
                } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22, design: .rounded)).foregroundColor(color)
                }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
    }
}

struct LargeTextEditor: View {
    let label: String; let icon: String; let ph: String
    @Binding var text: String
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon).font(RWF.cap()).foregroundColor(.rwTextMuted)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(ph).font(RWF.body()).foregroundColor(.rwTextMuted)
                        .padding(.horizontal, 4).padding(.vertical, 12).allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .frame(minHeight: 100).scrollContentBackground(.hidden).focused($focused)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(focused ? Color.rwAccent.opacity(0.3) : Color.rwBorder, lineWidth: 1))
        }
    }
}

// MARK: - Contact Date Suggestion Card

struct ContactDateSuggestionCard: View {
    let suggestion: DateSuggestion
    
    @State private var search = MapSearchService()

    var cat: VenueCategory { suggestion.venueCategory }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: cat.icon)
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white)
                    .frame(width: 36, height: 36).background(cat.color)
                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                    Text(suggestion.why).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !suggestion.tip.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 10, design: .rounded)).foregroundColor(Color(hex: "F59E0B"))
                    Text(suggestion.tip).font(RWF.body(12)).foregroundColor(.rwTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = suggestion.searchQuery
                MKLocalSearch(request: req).start { response, _ in
                    if let item = response?.mapItems.first { item.openInMaps() }
                }
            } label: {
                Label("Find on map", systemImage: "map.fill").font(RWF.cap(12))
                    .foregroundColor(cat.color)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(cat.color.opacity(0.08)).clipShape(Capsule())
                    .overlay(Capsule().stroke(cat.color.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(SBS())
        }
        .padding(SP.sm)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
    }
}

// MARK: - Move to Relationship Prompt

struct MoveToRelationshipView: View {
    let p: Person
    @State private var relStore = RelationshipStore.shared
    @State private var startDate = Date()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3).fill(Color.rwBorder)
                .frame(width: 40, height: 5).padding(.top, 12)

            ScrollView {
                VStack(spacing: SP.xl) {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 52, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                            .padding(.top, 20)
                        Text("Things are getting serious with \(p.name).")
                            .font(RWF.title(22)).foregroundColor(.rwTextPrimary).multilineTextAlignment(.center)
                        Text("Want to move them to your Relationship space? You'll get access to relationship tools, date planning for couples, and Cyrano's relationship coaching.")
                            .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("When did you get together?", systemImage: "calendar.heart.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, SP.xl)

                    VStack(spacing: 10) {
                        RWButton("Yes — We're Official 🎉", icon: "heart.fill") {
                            relStore.startRelationship(partnerName: p.name, personId: p.id, startDate: startDate)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            // Schedule a congratulations local notification
                            let content = UNMutableNotificationContent()
                            content.title = "Congratulations! 🎉"
                            content.body = "You and \(p.name) are official. Rowan is here to help you build something real."
                            content.sound = .default
                            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                            let request = UNNotificationRequest(identifier: "relationship_start", content: content, trigger: trigger)
                            UNUserNotificationCenter.current().add(request)
                            dismiss()
                        }
                        .padding(.horizontal, SP.xl)

                        Button("Not yet") { dismiss() }
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .background(Color.rwBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Intel Photo Helpers (Build 1 Step 8)

// Identifiable wrapper so the fullscreen cover can take an Int index via .item.
struct IndexBox: Identifiable, Equatable {
    let index: Int
    var id: Int { index }
}

// Disk-loading thumbnail used in the intel photos grid.
struct IntelPhotoThumbnail: View {
    let url: URL
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.rwSurface
            }
        }
        .frame(height: 100)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: RR.md))
        .task(id: url) {
            // Load on a background queue to avoid scrolling jank.
            let loaded = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return UIImage?.none }
                return UIImage(data: data)
            }.value
            image = loaded
        }
    }
}

// Fullscreen pager that swipes between intel photos. Tap to dismiss.
struct IntelPhotoFullscreen: View {
    let urls: [URL]
    let startIndex: Int
    @State private var index: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.element) { i, url in
                    // Only the current page and its two neighbours decode.
                    // Without this, TabView's eager page materialisation hits
                    // disk for every photo on open — guaranteed beachball with
                    // 30+ images in a single contact's intel gallery.
                    FullscreenPhoto(url: url, shouldLoad: abs(i - index) <= 1)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.top, 50).padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear { index = startIndex }
    }
}

private struct FullscreenPhoto: View {
    let url: URL
    let shouldLoad: Bool
    @State private var image: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if shouldLoad {
                ProgressView().tint(.white)
            }
            // Caption overlay if one exists.
            let caption = ContactPhotoStore.shared.caption(for: url)
            if !caption.isEmpty {
                Text(caption)
                    .font(RWF.body(15))
                    .foregroundColor(.white)
                    .padding(.horizontal, SP.lg).padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .padding(.bottom, 80)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Re-fires whenever shouldLoad flips true — handles the case where a
        // far-away page becomes adjacent as the user swipes.
        .task(id: "\(url.path)-\(shouldLoad)") {
            guard shouldLoad, image == nil else { return }
            let loaded = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return UIImage?.none }
                return UIImage(data: data)
            }.value
            image = loaded
        }
    }
}

// MARK: - Caption editor sheet

struct CaptionTarget: Identifiable {
    let url: URL
    var id: String { url.lastPathComponent }
}

struct CaptionEditorSheet: View {
    let url: URL
    @Binding var draft: String
    let onSave: (String) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var image: UIImage? = nil
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    }
                    Text("Caption")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("", text: $draft,
                              prompt: Text("What's this photo of?").foregroundColor(.rwTextMuted),
                              axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md)
                        .background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg)
                            .stroke(focused ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))

                    Text("Added \(ContactPhotoStore.shared.addedDate(for: url), format: .dateTime.day().month().year())")
                        .font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)

                    Spacer().frame(height: 8)

                    RWButton("Save", icon: "checkmark") { onSave(draft) }

                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete photo", systemImage: "trash")
                            .font(RWF.cap()).foregroundColor(.rwDanger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }.foregroundColor(.rwTextSecondary)
                }
            }
        }
        .task(id: url) {
            let loaded = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return UIImage?.none }
                return UIImage(data: data)
            }.value
            image = loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

