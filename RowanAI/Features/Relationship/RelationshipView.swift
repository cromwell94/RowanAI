import SwiftUI

// MARK: - Relationship Hub

struct RelationshipView: View {
    @State private var store = RelationshipStore.shared
    @State private var showSetup = false
    @State private var selectedTab: RelTab = .weSpace

    // Build 1 Step 6 — 5-pillar redesign.
    enum RelTab: String, CaseIterable {
        case weSpace       = "We"
        case communication = "Talk"
        case rituals       = "Rituals"
        case intimacy      = "Intimacy"
        case growth        = "Grow"

        var icon: String {
            switch self {
            case .weSpace:       return "house.fill"
            case .communication: return "bubble.left.and.bubble.right.fill"
            case .rituals:       return "sparkles"
            case .intimacy:      return "heart.fill"
            case .growth:        return "leaf.fill"
            }
        }
    }

    var body: some View {
        if store.relationship == nil {
            RelationshipSetupView()
        } else {
            NavigationView {
                VStack(spacing: 0) {
                    // Tab bar
                    RWSegmentedPicker(
                        options: RelTab.allCases.map { (value: $0, label: $0.rawValue, icon: $0.icon) },
                        selected: $selectedTab
                    )
                    .padding(.horizontal, SP.lg).padding(.vertical, 8)

                    Group {
                        switch selectedTab {
                        case .weSpace:       RelHomeView()
                        case .communication: RelCommunicationLab()
                        case .rituals:       RelRitualsView()
                        case .intimacy:      RelIntimacyView()
                        case .growth:        RelGrowthView()
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
                }
                .rwBG()
                .navigationTitle(store.relationship?.partnerName.isEmpty == false ?
                    "You & \(store.relationship!.partnerName)" : "Relationship")
                .navigationBarTitleDisplayMode(.large)
            }
        }
    }
}

// MARK: - Setup View

struct RelationshipSetupView: View {
    @State private var store = RelationshipStore.shared
    @State private var archive = ArchiveStore.shared
    @State private var partnerName = ""
    @State private var selectedPersonId: String? = nil
    @State private var startDate = Date()
    @State private var on = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.xl) {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color(hex: "E8356D").opacity(0.07)).frame(width: 110, height: 110)
                        Circle().fill(Color(hex: "E8356D").opacity(0.12)).frame(width: 80, height: 80)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 44, design: .rounded))
                            .foregroundStyle(LinearGradient.accent)
                    }
                    .padding(.top, 40)
                    Text("You're in a relationship!").font(RWF.display(28)).foregroundColor(.rwTextPrimary)
                        .multilineTextAlignment(.center)
                    Text("Rowan will help you build something honest, healthy, and lasting.")
                        .font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .opacity(on ? 1 : 0).offset(y: on ? 0 : 10)

                VStack(spacing: 14) {
                    // From archive or new
                    if !ArchiveStore.shared.active.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Who's your partner?", systemImage: "person.fill")
                                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button { selectedPersonId = nil; partnerName = "" } label: {
                                        Text("Someone new").font(RWF.cap(12))
                                            .foregroundColor(selectedPersonId == nil && partnerName.isEmpty ? .white : .rwTextMuted)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(selectedPersonId == nil && partnerName.isEmpty ? Color(hex: "0D0D0D") : Color.rwSurface)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(SBS())

                                    ForEach(ArchiveStore.shared.active) { p in
                                        Button {
                                            selectedPersonId = p.id
                                            partnerName = p.name
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle().fill(p.source.color.opacity(0.2)).frame(width: 20, height: 20)
                                                    .overlay(Text(p.initial).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(p.source.color))
                                                Text(p.name).font(RWF.cap(12))
                                            }
                                            .foregroundColor(selectedPersonId == p.id ? .white : .rwTextSecondary)
                                            .padding(.horizontal, 10).padding(.vertical, 7)
                                            .background(selectedPersonId == p.id ? Color(hex: "0D0D0D") : Color.rwSurface)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(SBS())
                                    }
                                }
                            }
                        }
                    }

                    SF(label: "Their name", icon: "person.fill", ph: "Partner's first name", text: $partnerName)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("When did you get together?", systemImage: "calendar.heart.fill")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, SP.xl).opacity(on ? 1 : 0)

                RWButton("Let's Build Something Real", icon: "heart.fill") {
                    guard !partnerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.startRelationship(partnerName: partnerName, personId: selectedPersonId, startDate: startDate)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .disabled(partnerName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(partnerName.isEmpty ? 0.5 : 1)
                .padding(.horizontal, SP.xl).padding(.bottom, 48)
                .opacity(on ? 1 : 0)
            }
        }
        .rwBG()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { on = true }
        }
    }
}

struct RelHomeView: View {
    @State private var store = RelationshipStore.shared
    @State private var partnerStore = PartnerStore.shared
    @State private var showPartnerConnect = false
    @State private var on = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                if let rel = store.relationship {
                relContent(rel: rel)
                }
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { on = true }
            partnerStore.checkForNudge()
        }
    }

    @ViewBuilder
    func relContent(rel: Relationship) -> some View {
        VStack(spacing: SP.lg) {

                // Proactive nudge
                RelNudgeBanner()

                // Partner connection
                Button { showPartnerConnect = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: partnerStore.isConnected ? "link.circle.fill" : "link.circle")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(partnerStore.isConnected ? Color(hex: "00BFB3") : .rwTextMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(partnerStore.isConnected ? "Connected with \(partnerStore.partnerName)" : "Connect with your partner")
                                .font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                            Text(partnerStore.isConnected ? "Tracking health from both sides" : "Track relationship health together")
                                .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.rwTextMuted).font(.system(size: 12, design: .rounded))
                    }
                    .padding(SP.md).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                    .overlay(RoundedRectangle(cornerRadius: RR.xl)
                        .stroke(partnerStore.isConnected ? Color(hex: "00BFB3").opacity(0.3) : Color.rwBorder, lineWidth: 1))
                    .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SBS())
                .sheet(isPresented: $showPartnerConnect) { PartnerConnectionView() }

                // Together card
                RWCard(pad: SP.xl) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOGETHER FOR").font(RWF.micro()).foregroundColor(.rwTextMuted).tracking(1.5)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(rel.daysTogether)")
                                    .font(.system(size: 52, weight: .black, design: .rounded))
                                    .foregroundStyle(LinearGradient.accent)
                                Text("days").font(RWF.head(20)).foregroundColor(.rwTextSecondary)
                            }
                            Text("Since \(rel.startDate.formatted(date: .long, time: .omitted))")
                                .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(Color(hex: "E8356D").opacity(0.08)).frame(width: 64, height: 64)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 30, design: .rounded))
                                .foregroundStyle(LinearGradient.accent)
                        }
                    }
                }
                .opacity(on ? 1 : 0)

                // Nudges
                if store.needsHealthCheck {
                    NudgeCard(
                        icon: "heart.text.square.fill",
                        title: "Time for a check-in",
                        subtitle: "How's the relationship feeling this week?",
                        color: Color(hex: "E8356D"),
                        action: "Check In"
                    )
                    .opacity(on ? 1 : 0)
                }

                if store.needsDateNight {
                    NudgeCard(
                        icon: "map.fill",
                        title: "Date night overdue",
                        subtitle: "You haven't logged a date in a while. Let Cyrano suggest something.",
                        color: Color(hex: "5B8DEF"),
                        action: "Plan a Date"
                    )
                    .opacity(on ? 1 : 0)
                }

                // Quick actions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    RelActionCard(icon: "bubble.left.fill", title: "Just Vent", sub: "Get it off your chest", color: Color(hex: "9B59B6"))
                    RelActionCard(icon: "questionmark.bubble.fill", title: "Is This Normal?", sub: "Ask Cyrano anything", color: Color(hex: "5B8DEF"))
                    RelActionCard(icon: "exclamationmark.triangle.fill", title: "Warning Signs", sub: "Know what to look for", color: Color(hex: "E8356D"))
                    RelActionCard(icon: "list.star", title: "Bucket List", sub: "\(rel.bucketList.filter { !$0.isDone }.count) to go", color: Color(hex: "00BFB3"))
                }
                .opacity(on ? 1 : 0)

                // Recent milestones
                if !rel.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RWSectionLabel("MILESTONES")
                        ForEach(rel.milestones.sorted { $0.date > $1.date }.prefix(3)) { m in
                            HStack(spacing: 12) {
                                Image(systemName: m.type.icon).font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(m.type.color).frame(width: 36, height: 36)
                                    .background(m.type.color.opacity(0.1)).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(RWF.med(14)).foregroundColor(.rwTextPrimary)
                                    Text(m.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                                }
                                Spacer()
                            }
                            .padding(SP.sm)
                        }
                    }
                    .opacity(on ? 1 : 0)
                }

        }
    }
}

struct NudgeCard: View {
    let icon: String; let title: String; let subtitle: String; let color: Color; let action: String
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: RR.md)
                    .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                Text(subtitle).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(action).font(RWF.cap(12)).foregroundColor(color)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(color.opacity(0.1)).clipShape(Capsule())
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(color.opacity(0.15), lineWidth: 1))
        .shadow(color: color.opacity(0.12), radius: 12, x: 0, y: 4)
    }
}

struct RelActionCard: View {
    let icon: String; let title: String; let sub: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundColor(color)
                .frame(width: 44, height: 44).background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: RR.md))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Text(sub).font(RWF.cap(11)).foregroundColor(.rwTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color.rwShadow, radius: 8, x: 0, y: 2)
    }
}
