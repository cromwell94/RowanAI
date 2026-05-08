import SwiftUI
import MapKit

// MARK: - Relationship Date Planner

struct RelPlannerView: View {
    @State private var tab: RPTab = .tonight
    @StateObject private var locationManager = LocationManager()

    enum RPTab: String, CaseIterable {
        case tonight  = "Date Night"
        case bucket   = "Bucket List"
        case milestones = "Milestones"

        var icon: String {
            switch self {
            case .tonight:    return "sparkles"
            case .bucket:     return "list.star"
            case .milestones: return "star.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RWSegmentedPicker(
                options: RPTab.allCases.map { (value: $0, label: $0.rawValue, icon: $0.icon) },
                selected: $tab
            )
            .padding(.horizontal, SP.lg).padding(.top, 8).padding(.bottom, 4)

            switch tab {
            case .tonight:    DateNightView(locationManager: locationManager)
            case .bucket:     BucketListView()
            case .milestones: MilestonesView()
            }
        }
        .onAppear { locationManager.requestPermission() }
    }
}

// MARK: - Date Night Engine

struct DateNightView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var store = RelationshipStore.shared
    @State private var suggestions: [RelDateSuggestion] = []
    @State private var isLoading = false
    @State private var vibe = ""

    struct RelDateSuggestion: Identifiable {
        let id = UUID()
        let emoji: String; let title: String; let description: String; let why: String
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Date Night Engine").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    if store.needsDateNight {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12)).foregroundColor(Color(hex: "F59E0B"))
                            Text("You haven't had a date night in a while.")
                                .font(RWF.cap(12)).foregroundColor(Color(hex: "F59E0B"))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)

                RWCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What's the vibe tonight?", systemImage: "wand.and.stars")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)
                        TextField("Cozy, adventurous, romantic, silly...", text: $vibe)
                            .font(RWF.body()).foregroundColor(.rwTextPrimary)
                            .padding(SP.md).background(Color.rwSurface)
                            .clipShape(RoundedRectangle(cornerRadius: RR.md))
                            .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
                        RWButton(isLoading ? "Thinking..." : "Get Ideas", icon: isLoading ? nil : "sparkles") {
                            Task { await getSuggestions() }
                        }
                        .disabled(isLoading)
                    }
                }

                if !suggestions.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(suggestions) { s in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Text(s.emoji).font(.system(size: 28))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                        Text(s.description).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                    }
                                }
                                Text(s.why).font(RWF.body(13)).foregroundColor(.rwTextMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 4)
                            }
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
                            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
                            .shadow(color: Color.rwShadow, radius: 6, x: 0, y: 2)
                        }
                    }
                }

                // Wishlist
                let visited = WishlistStore.shared.visited
                if !visited.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RWSectionLabel("PLACES YOU'VE BEEN TOGETHER")
                        ForEach(visited.prefix(4)) { v in
                            HStack(spacing: 10) {
                                Image(systemName: v.category.icon).font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(v.category.color).frame(width: 32, height: 32)
                                    .background(v.category.color.opacity(0.1)).clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(RWF.med(14)).foregroundColor(.rwTextPrimary)
                                    HStack(spacing: 3) {
                                        ForEach(1...5, id: \.self) { i in
                                            Image(systemName: i <= v.dateRating ? "heart.fill" : "heart")
                                                .font(.system(size: 10))
                                                .foregroundColor(i <= v.dateRating ? .rwAccent : .rwBorder)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(SP.sm)
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
    }

    func getSuggestions() async {
        isLoading = true; suggestions = []
        let rel = store.relationship
        let partner = rel?.partnerName ?? "your partner"
        let months = rel?.monthsTogether ?? 0
        let visitedPlaces = WishlistStore.shared.visited.map { $0.category.rawValue }
        let usedTypes = visitedPlaces.isEmpty ? "" : "Places you've already been: \(Set(visitedPlaces).joined(separator: ", "))."

        let system = """
        You are Cyrano helping a couple plan a date night.
        Partner: \(partner). Together for \(months) months. \(usedTypes)
        Desired vibe: \(vibe.isEmpty ? "any good idea" : vibe)
        Suggest 3 specific date night ideas. Be creative and specific — not generic.
        Each should feel different. Consider home dates, outdoor, local adventures.
        Return ONLY JSON array:
        [{"emoji":"...","title":"...","description":"one-line description","why":"one sentence why this is great for them"}]
        """

        do {
            let raw = try await Claude.shared.send(system: system, user: "Suggest 3 date night ideas.", max: 400)
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            struct Raw: Codable { var emoji: String; var title: String; var description: String; var why: String }
            if let data = cleaned.data(using: .utf8),
               let raw = try? JSONDecoder().decode([Raw].self, from: data) {
                suggestions = raw.map { RelDateSuggestion(emoji: $0.emoji, title: $0.title, description: $0.description, why: $0.why) }
            }
        } catch {}
        isLoading = false
    }
}

// MARK: - Bucket List

struct BucketListView: View {
    @State private var store = RelationshipStore.shared
    @State private var newItem = ""
    @State private var showAdd = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bucket List").font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                        if let rel = store.relationship {
                            let done = rel.bucketList.filter { $0.isDone }.count
                            let total = rel.bucketList.count
                            if total > 0 {
                                Text("\(done) of \(total) done").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                            }
                        }
                    }
                    Spacer()
                    Button { showAdd = true; focused = true } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 28))
                            .foregroundStyle(LinearGradient.accent)
                    }
                    .buttonStyle(SBS())
                }
                .padding(.top, 8)

                if showAdd {
                    HStack(spacing: 10) {
                        TextField("", text: $newItem, prompt: Text("Add something to do together...").foregroundColor(.rwTextMuted))
                            .font(RWF.body()).foregroundColor(.rwTextPrimary).focused($focused)
                            .onSubmit { addItem() }
                        Button { addItem() } label: {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundColor(.rwAccent)
                        }
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(SBS())
                    }
                    .padding(SP.md).background(Color.rwCard)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                    .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwAccent.opacity(0.3), lineWidth: 1))
                }

                if let rel = store.relationship {
                    if rel.bucketList.isEmpty {
                        RWEmptyState(
                            icon: "list.star",
                            title: "Your bucket list is empty",
                            subtitle: "Add things you want to experience together — big or small.",
                            cta: nil,
                            ctaIcon: nil,
                            onCTA: nil
                        )
                        .padding(.vertical, 20)
                    } else {
                        let todo = rel.bucketList.filter { !$0.isDone }
                        let done = rel.bucketList.filter { $0.isDone }

                        if !todo.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(todo) { item in BucketItemRow(item: item) }
                            }
                        }

                        if !done.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Completed ✓").font(RWF.cap()).foregroundColor(.rwTextMuted)
                                ForEach(done) { item in BucketItemRow(item: item) }
                            }
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
    }

    func addItem() {
        let text = newItem.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let item = BucketItem(title: text)
        store.update { $0.bucketList.insert(item, at: 0) }
        newItem = ""; showAdd = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct BucketItemRow: View {
    let item: BucketItem
    @State private var store = RelationshipStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.update { r in
                    if let i = r.bucketList.firstIndex(where: { $0.id == item.id }) {
                        r.bucketList[i].isDone.toggle()
                        r.bucketList[i].completedAt = r.bucketList[i].isDone ? Date() : nil
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(item.isDone ? .rwSuccess : .rwBorder)
            }
            .buttonStyle(SBS())

            Text(item.title).font(RWF.body()).foregroundColor(item.isDone ? .rwTextMuted : .rwTextPrimary)
                .strikethrough(item.isDone, color: .rwTextMuted)
            Spacer()
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Milestones

struct MilestonesView: View {
    @State private var store = RelationshipStore.shared
    @State private var showAdd = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                HStack {
                    Text("Milestones").font(RWF.title(22)).foregroundColor(.rwTextPrimary).padding(.top, 8)
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 28)).foregroundStyle(LinearGradient.accent)
                    }
                    .buttonStyle(SBS())
                }

                if let rel = store.relationship {
                    if rel.milestones.isEmpty {
                        RWEmptyState(
                            icon: "star.fill",
                            title: "No milestones yet",
                            subtitle: "Log the moments that matter — your story, saved.",
                            cta: nil,
                            ctaIcon: nil,
                            onCTA: nil
                        )
                        .padding(.vertical, 20)
                    } else {
                        ForEach(rel.milestones.sorted { $0.date > $1.date }) { m in
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 4) {
                                    Image(systemName: m.type.icon).font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white).frame(width: 40, height: 40)
                                        .background(m.type.color).clipShape(Circle())
                                    Rectangle().fill(Color.rwBorder).frame(width: 2).frame(maxHeight: .infinity)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(m.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(RWF.cap(11)).foregroundColor(.rwTextMuted)
                                    Text(m.title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                                    if !m.notes.isEmpty {
                                        Text(m.notes).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 12)
        }
        .sheet(isPresented: $showAdd) { AddMilestoneView() }
    }
}

struct AddMilestoneView: View {
    @State private var store = RelationshipStore.shared
    @State private var title = ""
    @State private var type: Milestone.MType = .moment
    @State private var date = Date()
    @State private var notes = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    SF(label: "What happened?", icon: "sparkles", ph: "Name this milestone", text: $title)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Type", systemImage: "tag.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(Milestone.MType.allCases, id: \.rawValue) { t in
                                Button { type = t } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: t.icon).font(.system(size: 12))
                                        Text(t.rawValue).font(RWF.cap(12))
                                    }
                                    .foregroundColor(type == t ? .white : .rwTextSecondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(type == t ? t.color : Color.rwSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                                }
                                .buttonStyle(SBS())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("When?", systemImage: "calendar").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact).labelsHidden()
                            .padding(SP.md).background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                    }

                    LargeTextEditor(label: "Notes (optional)", icon: "note.text", ph: "What made this special...", text: $notes)
                }
                .padding(.horizontal, SP.xl).padding(.top, 20)
            }
            .rwBG()
            .navigationTitle("Add Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let m = Milestone(title: title, date: date, notes: notes, type: type)
                        store.update { $0.milestones.insert(m, at: 0) }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .font(RWF.med()).foregroundColor(.rwAccent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
