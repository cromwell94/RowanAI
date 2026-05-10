import SwiftUI

// MARK: - Growth Together (Build 1 Step 6, Pillar 5)
// Vision Board · Bucket List · Timeline · Growth Challenges · Gridlock Navigator
// Plus the Couple Chemistry Report stub (full feature in Build 4).

struct RelGrowthView: View {
    @State private var showVision = false
    @State private var showBucket = false
    @State private var showTimeline = false
    @State private var showChallenge = false
    @State private var showGridlock = false
    @State private var showChemistry = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                tile(icon: "sparkles.rectangle.stack.fill", title: "Vision Board",
                     sub: "1-year and 5-year. Both contribute privately. Cyrano synthesises.",
                     tint: Color(hex: "9B59B6")) { showVision = true }
                tile(icon: "checkmark.square.fill", title: "Bucket List",
                     sub: "Adventure, Creative, Quiet, Romantic, Challenging.",
                     tint: Color(hex: "00BFB3")) { showBucket = true }
                tile(icon: "calendar.badge.clock", title: "Relationship Timeline",
                     sub: "A visual record of every milestone.",
                     tint: Color(hex: "5B8DEF")) { showTimeline = true }
                tile(icon: "leaf.fill", title: "Growth Challenge",
                     sub: "Weekly research-backed challenge for couples.",
                     tint: Color(hex: "F59E0B")) { showChallenge = true }
                tile(icon: "compass.drawing", title: "Gridlock Navigator",
                     sub: "Gottman's perpetual-vs-solvable framework — for the fights you keep having.",
                     tint: .rwAccent) { showGridlock = true }
                chemistryStubCard
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 16)
        }
        .rwBG()
        .sheet(isPresented: $showVision) { VisionBoardView() }
        .sheet(isPresented: $showBucket) { CoupleBucketView() }
        .sheet(isPresented: $showTimeline) { CoupleTimelineView() }
        .sheet(isPresented: $showChallenge) { GrowthChallengeView() }
        .sheet(isPresented: $showGridlock) { GridlockView() }
        .sheet(isPresented: $showChemistry) { CoupleChemistryStubView() }
    }

    private var hero: some View {
        RWPageHeader("Growth Together",
                     subtitle: "Tools for the relationship you're becoming, not just the one you have today.",
                     topPadding: 0)
    }

    private func tile(icon: String, title: String, sub: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                    Text(sub).font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    private var chemistryStubCard: some View {
        Button { showChemistry = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "E8356D"))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: "E8356D").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Couple Chemistry Report").font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        Text("BUILD 4").font(RWF.micro())
                            .foregroundColor(.rwTextMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.rwBorder.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    Text("8-dimension assessment, both partners answer privately, Cyrano writes the report.")
                        .font(RWF.body(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
            }
            .padding(SP.md).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Sub-views (scaffolds — content slots ready for Build 1 polish or Build 2 expansion)

struct VisionBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var oneYear: String = ""
    @State private var fiveYear: String = ""
    @State private var saved = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    Text("What does this relationship look like in one year? In five?\nBoth of you fill this out privately.")
                        .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    section(title: "One year from now", text: $oneYear)
                    section(title: "Five years from now", text: $fiveYear)
                    RWButton(saved ? "Saved" : "Save privately",
                             icon: saved ? "checkmark" : "lock.fill") { saved = true }
                        .disabled(saved).opacity(saved ? 0.6 : 1)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Vision Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }

    @ViewBuilder
    private func section(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
            TextField("", text: text,
                      prompt: Text("Write here…").foregroundColor(.rwTextMuted),
                      axis: .vertical)
                .lineLimit(3...8)
                .font(RWF.body()).foregroundColor(.rwTextPrimary)
                .padding(SP.md).background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
    }
}

struct CoupleBucketView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""
    @State private var category: BucketCategory = .adventure
    @State private var items: [BucketEntry] = []

    enum BucketCategory: String, CaseIterable, Identifiable, Codable {
        case adventure = "Adventure"
        case creative  = "Creative"
        case quiet     = "Quiet"
        case romantic  = "Romantic"
        case challenging = "Challenging"
        var id: String { rawValue }
    }
    struct BucketEntry: Identifiable { let id = UUID(); let title: String; let category: BucketCategory; var done = false }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BucketCategory.allCases) { c in
                            Button {
                                category = c
                            } label: {
                                Text(c.rawValue).font(RWF.cap(12))
                                    .foregroundColor(category == c ? .white : .rwTextSecondary)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(category == c ? Color.rwGold : Color.rwCard)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(SBS())
                        }
                    }
                    .padding(.horizontal, SP.lg).padding(.vertical, 8)
                }
                List {
                    ForEach(items) { entry in
                        HStack {
                            Image(systemName: entry.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(entry.done ? .rwGold : .rwTextMuted)
                            Text(entry.title).strikethrough(entry.done).foregroundColor(.rwTextPrimary)
                            Spacer()
                            Text(entry.category.rawValue).font(RWF.cap(10)).foregroundColor(.rwTextMuted)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let i = items.firstIndex(where: { $0.id == entry.id }) {
                                items[i].done.toggle()
                            }
                        }
                    }
                    .onDelete { indices in items.remove(atOffsets: indices) }
                }
                .listStyle(.plain)
                HStack(spacing: 8) {
                    TextField("", text: $newItem,
                              prompt: Text("Add to your bucket list…").foregroundColor(.rwTextMuted))
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    Button {
                        let trimmed = newItem.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        items.append(BucketEntry(title: trimmed, category: category))
                        newItem = ""
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white).frame(width: 44, height: 44)
                            .background(Color.rwGold).clipShape(Circle())
                    }
                }
                .padding(SP.md)
            }
            .rwBG()
            .navigationTitle("Bucket List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}

struct CoupleTimelineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = RelationshipStore.shared
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    if let rel = store.relationship {
                        RelTimelineRow(date: rel.startDate, title: "Together", icon: "heart.fill", color: .rwGold)
                    }
                    Text("More milestones populate as you log them — first trip, key conversations, anniversaries.")
                        .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                        .padding(.horizontal, SP.xl)
                        .multilineTextAlignment(.center)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}

private struct RelTimelineRow: View {
    let date: Date
    let title: String
    let icon: String
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundColor(.white)
                .frame(width: 36, height: 36).background(color).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(RWF.head(14)).foregroundColor(.rwTextPrimary)
                Text(date, style: .date).font(RWF.cap(12)).foregroundColor(.rwTextMuted)
            }
            Spacer()
        }
    }
}

struct GrowthChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    private let starters: [String] = [
        "Spend 20 uninterrupted minutes together with no screens this week.",
        "Compliment something specific about how they handled something each day for 7 days.",
        "Cook a meal together neither of you has made before.",
        "Take a 30-minute walk and only ask each other questions you don't know the answer to.",
        "Each share one fear about the relationship — without rebutting the other's.",
    ]
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.md) {
                    Text("Pick one. Library of 52 lands fully in Build 2.")
                        .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        .padding(.top, 8)
                    ForEach(starters, id: \.self) { c in
                        RWCard {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "leaf.fill").foregroundColor(Color(hex: "F59E0B"))
                                Text(c).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Growth Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}

struct GridlockView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var topic = ""
    @State private var output = ""
    @State private var working = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SP.md) {
                    Text("Gottman's research: 69% of relationship conflicts are perpetual — about who you are, not who's right. The work isn't to win them; it's to live with them well.")
                        .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The fight you keep having").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    TextField("", text: $topic,
                              prompt: Text("Describe the recurring conflict…").foregroundColor(.rwTextMuted),
                              axis: .vertical)
                        .lineLimit(3...8)
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .padding(SP.md).background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    if !output.isEmpty {
                        RWCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Cyrano's read", systemImage: "sparkles")
                                    .font(RWF.cap()).foregroundColor(.rwAccent)
                                Text(output).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    RWButton(working ? "Reading…" : "Read this", icon: "wand.and.stars") {
                        Task { await analyze() }
                    }
                    .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty || working)
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationTitle("Gridlock Navigator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }

    private func analyze() async {
        guard AISettings.shared.isEnabled else { return }
        working = true
        defer { working = false }
        let role = """
        YOUR ROLE NOW: Couples coach using Gottman's perpetual-vs-solvable framework.
        Read the conflict. Decide if it looks perpetual (about identity/values) or solvable (about a specific situation).
        Then in 4-5 sentences: name it, name what's underneath it for each partner, and give one move that turns the gridlock into dialogue.
        Plain text. No bullets.
        """
        do {
            let raw = try await Claude.shared.send(system: role, user: topic, max: 400)
            output = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            output = "Most recurring fights are about meaning, not facts. Try this: name what each of you is afraid of underneath the surface argument. The shift from 'who's right' to 'what does this mean to each of us' is usually where the dialogue restarts."
        }
    }
}

struct CoupleChemistryStubView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 48, design: .rounded)).foregroundColor(Color(hex: "E8356D"))
                        .padding(.top, 32)
                    Text("Couple Chemistry Report").font(RWF.title()).foregroundColor(.rwTextPrimary)
                    Text("Coming in Build 4.").font(RWF.cap()).foregroundColor(.rwTextMuted)
                    RWCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What it includes", systemImage: "list.bullet")
                                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                            ForEach([
                                "Natural Alignment — where you click effortlessly",
                                "Natural Friction — where you predictably clash, and why",
                                "Your Growth Practices — specific to your friction zones",
                                "Combined Attachment Dynamic",
                                "Your Relationship Strengths"
                            ], id: \.self) { line in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle().fill(Color(hex: "E8356D").opacity(0.4))
                                        .frame(width: 5, height: 5).padding(.top, 7)
                                    Text(line).font(RWF.body()).foregroundColor(.rwTextPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(SP.lg)
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.rwAccent) } }
        }
    }
}
