import SwiftUI

// MARK: - Arc Navigation (Build 1 Step 4)
// Replaces the bottom tab bar with a radial half-circle of 5 primary
// destinations and a long-press secondary layer of 4 deeper destinations.
// Tap outside to close. Active destination is highlighted in pink.

enum ArcDestination: Hashable {
    // Primary
    case home, archive, cyrano, faceToFaceSim, relationship
    // Secondary
    case datePlanner, communicationLab, debrief, profile

    var icon: String {
        switch self {
        case .home:             return "house.fill"
        case .archive:          return "person.2.fill"
        case .cyrano:           return "sparkles"
        case .faceToFaceSim:    return "bubble.left.and.bubble.right.fill"
        case .relationship:     return "heart.fill"
        case .datePlanner:      return "map.fill"
        case .communicationLab: return "book.fill"
        case .debrief:          return "doc.text.fill"
        case .profile:          return "person.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .home:             return "Home"
        case .archive:          return "Archive"
        case .cyrano:           return "Cyrano"
        case .faceToFaceSim:    return "Face to Face"
        case .relationship:     return "Relationship"
        case .datePlanner:      return "Planner"
        case .communicationLab: return "Coach"
        case .debrief:          return "Journal"
        case .profile:          return "Profile"
        }
    }
}

struct ArcMainView: View {
    @Environment(AppState.self) var app
    @State private var destination: ArcDestination = .home
    @State private var arcOpen = false
    @State private var secondaryLayer = false
    @State private var showGuide = false
    @State private var auth = AuthService.shared

    // Primary slots — fixed positions; visibility flips with the user's
    // relationshipStatus (single → Archive shown; in relationship → Relationship
    // tab shown). Drives the arc-menu update from the Situation Switcher.
    private var primarySlots: [ArcDestination?] {
        let isRel = auth.currentUser?.relationshipStatus == .relationship
        let archiveSlot: ArcDestination? = isRel ? nil : .archive
        let relSlot: ArcDestination? = isRel ? .relationship : nil
        return [archiveSlot, .cyrano, .home, .faceToFaceSim, relSlot]
    }

    private var secondarySlots: [ArcDestination] {
        [.datePlanner, .communicationLab, .debrief, .profile]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Destination — fills the screen
            destinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 2. Dim backdrop when arc is open — tap to dismiss.
            if arcOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closeArc() }
            }

            // 3. Top-right "Ask Cyrano" guide button — preserved utility.
            VStack {
                HStack {
                    Spacer()
                    guideButton
                }
                Spacer()
            }
            .padding(.top, 60).padding(.trailing, 16)
            .allowsHitTesting(!arcOpen)

            // 4. Arc items — fan out above the button when open.
            if arcOpen {
                arcItemsView
                    .padding(.bottom, 100)
            }

            // 5. The main floating action button — pinned to the bottom,
            //    24pt above the screen edge. Always visible, on top of
            //    every other layer.
            CenterButton(
                destination: destination,
                arcOpen: arcOpen,
                onTap: toggleArc,
                onLongPress: showSecondary
            )
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color.rwBackground.ignoresSafeArea())
        .sheet(isPresented: $showGuide) {
            GuideSheet(open: $showGuide)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.rwSurface)
        }
    }

    // MARK: Destination

    @ViewBuilder
    private var destinationView: some View {
        // Wrap each destination in NavigationView so internal navigation works.
        // The arc itself sits above on top.
        switch destination {
        case .home:             ArcHomeView(arcGoTo: { setDestination($0) })
        case .archive:          ArchiveView()
        case .cyrano:           CyranoView()
        case .faceToFaceSim:    FaceToFaceSimView()
        case .relationship:     RelationshipView()
        case .datePlanner:      DatePlannerView()
        case .communicationLab: NavigationView { CommunicationLabView() }
        case .debrief:          DebriefListView()
        case .profile:          ProfileView()
        }
    }

    private func setDestination(_ dest: ArcDestination) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        destination = dest
        closeArc()
    }

    // MARK: Arc Items
    // A flat 1pt-tall horizontal anchor — items use .offset to fan 180° above
    // it. Padded .bottom 100 from screen edge in the parent body, so the fan
    // anchor sits at 100pt above the bottom edge while the center button sits
    // at 24pt — items naturally clear the button.

    private var arcItemsView: some View {
        ZStack {
            let slots = secondaryLayer ? secondarySlots.map(Optional.some) : primarySlots
            ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                if let dest = slot {
                    ArcButton(
                        dest: dest,
                        isActive: destination == dest,
                        onTap: { setDestination(dest) }
                    )
                    .offset(arcOffset(index: i, count: slots.count))
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.68)
                            .delay(Double(i) * 0.04),
                        value: arcOpen
                    )
                }
            }
        }
        .frame(width: 280, height: 1)
    }

    private func toggleArc() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if arcOpen {
            closeArc()
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                arcOpen = true
                secondaryLayer = false
            }
        }
    }

    private func showSecondary() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            arcOpen = true
            secondaryLayer = true
        }
    }

    private func closeArc() {
        withAnimation(.easeOut(duration: 0.22)) {
            arcOpen = false
            secondaryLayer = false
        }
    }

    // MARK: Geometry
    // Items span a strict 180° arc above the center button (180° → 0° in
    // standard math coords, sweeping through 90° at the apex). Distance from
    // center is `radius`; iOS y is down so we negate sin().

    private func arcOffset(index: Int, count: Int) -> CGSize {
        let radius: CGFloat = 100
        guard count > 1 else { return CGSize(width: 0, height: -radius) }
        let startAngle: Double = 180        // far left
        let endAngle:   Double = 0          // far right
        let step = (endAngle - startAngle) / Double(count - 1)
        let angleDeg = startAngle + step * Double(index)
        let angleRad = angleDeg * .pi / 180.0
        let dx = cos(angleRad) * Double(radius)
        let dy = -sin(angleRad) * Double(radius)
        return CGSize(width: dx, height: dy)
    }

    // MARK: Floating guide button (preserved from MainTabView)

    private var guideButton: some View {
        Button {
            showGuide = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                Circle().fill(LinearGradient.accent).frame(width: 50, height: 50)
                    .shadow(color: Color.rwAccent.opacity(0.35), radius: 10, x: 0, y: 4)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            }
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Arc Button
// 52pt circle. On dim backdrop, inactive items are translucent white with a
// hairline border + white icon; the active destination is a solid white fill
// with the brand gradient applied to the icon — clearly readable as "current".

private struct ArcButton: View {
    let dest: ArcDestination
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.18))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Circle().stroke(
                                isActive ? Color.clear : Color.white.opacity(0.28),
                                lineWidth: 1
                            )
                        )
                        .shadow(
                            color: isActive ? Color.black.opacity(0.22) : .clear,
                            radius: 14, x: 0, y: 6
                        )
                    if isActive {
                        Image(systemName: dest.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(LinearGradient.accent)
                    } else {
                        Image(systemName: dest.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                Text(dest.label)
                    .font(RWF.cap(10))
                    .foregroundColor(.white.opacity(isActive ? 1.0 : 0.85))
                    .lineLimit(1)
            }
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Center Button
// 64pt circle with the signature pink → teal gradient. Icon mirrors the
// active destination (or `house.fill` on Home) when closed; rotates to
// `xmark` when the arc is open. Long-press swaps to the secondary layer.

private struct CenterButton: View {
    let destination: ArcDestination
    let arcOpen: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var icon: String {
        if arcOpen { return "xmark" }
        return destination == .home ? "house.fill" : destination.icon
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "E8356D"), Color(hex: "00BFB3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.rwAccent.opacity(0.45), radius: 18, x: 0, y: 8)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(arcOpen ? 90 : 0))
                    .animation(.spring(response: 0.32, dampingFraction: 0.7), value: arcOpen)
            }
        }
        .buttonStyle(SBS())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in onLongPress() }
        )
    }
}

// MARK: - Arc Home View
// Premium home dashboard. Hero greeting → relationship banner (if applicable)
// → "Today" gradient card → 4-tile quick-access grid → RI Score glance.

struct ArcHomeView: View {
    let arcGoTo: (ArcDestination) -> Void
    @State private var on = false
    @State private var riStore = RIScoreStore.shared
    @State private var auth = AuthService.shared
    @State private var insights = HomeInsightsService.shared
    @State private var showSituation = false
    @State private var replayTutorial = false

    private var firstName: String {
        auth.currentUser?.name ?? ""
    }

    private var attachmentStyle: RWUser.AttachmentStyle {
        auth.currentUser?.attachmentStyle ?? .secure
    }

    private var isInRelationship: Bool {
        auth.currentUser?.relationshipStatus == .relationship
    }

    private var timeOfDay: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    hero
                        .staggerAppear(0, appeared: on)

                    StreakCard()
                        .staggerAppear(1, appeared: on)

                    insightsCard
                        .staggerAppear(2, appeared: on)

                    SituationPill { showSituation = true }
                        .staggerAppear(3, appeared: on)

                    if isInRelationship {
                        relationshipBanner
                            .staggerAppear(3, appeared: on)
                    }

                    quickAccess
                        .staggerAppear(4, appeared: on)

                    AttachmentTipsRow(style: attachmentStyle)
                        .staggerAppear(5, appeared: on)

                    riGlanceCard
                        .staggerAppear(6, appeared: on)

                    Spacer().frame(height: 240) // arc menu clearance
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 24)
            }
            .rwBG()
            .navigationBarHidden(true)
            .sheet(isPresented: $showSituation) {
                SituationSwitcherSheet()
                    .environment(app)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .tutorial(.home, forceShow: $replayTutorial)
        }
        .onAppear {
            on = true
            Task { await insights.loadIfStale() }
        }
    }

    // Need access to AppState for the sheet
    @Environment(AppState.self) private var app

    // MARK: Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeOfDay)
                    .font(RWF.head(18))
                    .foregroundColor(.rwTextSecondary)
                Text(firstName.isEmpty ? "Welcome back." : firstName + ".")
                    .font(RWF.display(36))
                    .foregroundStyle(LinearGradient.accent)
            }
            Spacer()
            TutorialReplayButton(id: .home, forceShow: $replayTutorial)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Insights card — Cyrano-driven, refreshed daily

    private var insightsCard: some View {
        let streak = StreakManager.shared.currentStreak
        let cur = insights.current
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LinearGradient.accent)
                Text(cur?.type.eyebrow ?? "TODAY")
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.6)
                Spacer()
                if insights.isGenerating {
                    ProgressView().tint(.rwAccent).scaleEffect(0.7)
                }
            }
            if let cur {
                Text(cur.body)
                    .font(RWF.title(20))
                    .foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().background(Color.rwBorder)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LinearGradient.accent)
                        .padding(.top, 4)
                    Text(cur.actionableTip)
                        .font(RWF.body(14))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if streak > 2 {
                    HStack(spacing: 6) {
                        Text("🔥")
                            .font(.system(size: 14))
                        Text("Your streak is \(streak) days — don't let it go.")
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextMuted)
                    }
                    .padding(.top, 2)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().tint(.rwAccent).scaleEffect(0.8)
                    Text("Cyrano is thinking…")
                        .font(RWF.body(14))
                        .foregroundColor(.rwTextMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SP.lg)
        .background(
            RoundedRectangle(cornerRadius: RR.xl)
                .fill(Color.rwCard)
                .overlay(
                    LinearGradient.accentSoft
                        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: RR.xl)
                .stroke(LinearGradient.accent.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.rwAccent.opacity(0.10), radius: 22, x: 0, y: 8)
    }

    // MARK: Quick access tiles

    private var quickAccess: some View {
        VStack(alignment: .leading, spacing: 12) {
            RWSectionLabel("QUICK ACCESS")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                RWQuickTile(icon: "bubble.left.and.bubble.right.fill",
                            title: "Cyrano",
                            subtitle: "Craft a reply that lands",
                            tint: .rwAccent) { arcGoTo(.cyrano) }
                RWQuickTile(icon: "person.2.wave.2.fill",
                            title: "Face to Face",
                            subtitle: "Practice a real conversation",
                            tint: Color(hex: "9B59B6")) { arcGoTo(.faceToFaceSim) }
                if isInRelationship {
                    RWQuickTile(icon: "heart.fill",
                                title: "Relationship",
                                subtitle: "Rituals, intimacy, growth",
                                tint: .rwAmber) { arcGoTo(.relationship) }
                } else {
                    RWQuickTile(icon: "person.2.fill",
                                title: "Archive",
                                subtitle: "Your connections",
                                tint: Color(hex: "4CAF89")) { arcGoTo(.archive) }
                }
                RWQuickTile(icon: "map.fill",
                            title: "Planner",
                            subtitle: "Find a great date spot",
                            tint: .rwGold) { arcGoTo(.datePlanner) }
            }
        }
    }

    // MARK: RI Score glance

    private var riGlanceCard: some View {
        let score = riStore.score
        let level = score.level
        return Button {
            arcGoTo(.profile)  // RI Score lives behind Profile for now
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.rwBorder, lineWidth: 4).frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.total) / 1200.0)
                        .stroke(LinearGradient.accent,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                    Text("\(score.total)").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Relational Intelligence")
                        .font(RWF.cap(12)).foregroundColor(.rwTextMuted).tracking(1.2)
                    Text(level.rawValue).font(RWF.head(17)).foregroundColor(.rwTextPrimary)
                    Text("Tap to see the breakdown")
                        .font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.rwTextMuted)
            }
            .padding(SP.lg)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 18, x: 0, y: 6)
        }
        .buttonStyle(SBS())
    }

    // MARK: Relationship banner

    private var relationshipBanner: some View {
        let partner = auth.currentUser?.partnerName
            ?? RelationshipStore.shared.relationship?.partnerName
            ?? "your partner"
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient.amber).frame(width: 38, height: 38)
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Relationship Mode")
                    .font(RWF.cap(11)).foregroundColor(.rwTextMuted).tracking(1.2)
                Text("You & \(partner)")
                    .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rwTextMuted)
        }
        .padding(SP.md)
        .background(Color.rwAmberSoft)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwAmber.opacity(0.25), lineWidth: 1))
        .onTapGesture { arcGoTo(.relationship) }
    }
}
