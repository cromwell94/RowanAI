import SwiftUI

// MARK: - Debrief List

struct DebriefListView: View {
    @State private var store  = DebriefStore.shared
    @State private var showNew = false
    @State private var showPaywall = false
    @State private var storeManager = StoreManager.shared
    @State private var appeared = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SP.lg) {

                    if !AISettings.shared.isEnabled {
                        AIOffBanner(feature: "Date Debrief", msg: "AI is off. You can still log dates manually.")
                            .padding(.horizontal, SP.lg)
                    }

                    RWButton(AISettings.shared.isEnabled ? "Debrief a Date" : "Log a Date", icon: "plus") {
                        if storeManager.canUseDebrief() {
                            showNew = true
                        } else {
                            showPaywall = true
                        }
                    }
                    .padding(.horizontal, SP.lg)

                    if store.debriefs.isEmpty {
                        RWEmptyState(
                            icon: "moon.stars.fill",
                            title: "No entries yet",
                            subtitle: "After a date, come here and tell Cyrano how it went."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(store.debriefs.enumerated()), id: \.element.id) { index, d in
                                NavigationLink(destination: DebriefDetail(d: d)) {
                                    DebriefRow(d: d)
                                }
                                .padding(.horizontal, SP.lg)
                                .staggerAppear(index, appeared: appeared)
                            }
                        }
                        .onAppear { appeared = true }
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.top, 20)
            }
            .rwBG()
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showNew) { NewDebrief() }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .debriefLimit) }
    }
}

struct DebriefRow: View {
    let d: DateDebrief
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: "6B7FD7").opacity(0.12)).frame(width: 48, height: 48)
                Text(String(d.personName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(LinearGradient.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(d.personName.isEmpty ? "Unnamed" : d.personName).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                Text("Date \(d.dateNumber) · \(d.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(RWF.cap()).foregroundColor(.rwTextSecondary)
            }
            Spacer()
            if let a = d.analysis {
                Text(a.recommendation.rawValue).font(RWF.micro()).foregroundColor(a.recommendation.color)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(a.recommendation.color.opacity(0.12)).clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextMuted).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.rwTextMuted)
        }
        .padding(SP.md).background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
        .shadow(color: Color(hex: "6B7FD7").opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

// MARK: - New Debrief

struct NewDebrief: View {
    @Environment(\.dismiss) var dismiss
    @State private var d = DateDebrief()
    @State private var step: St = .info
    @State private var analyzing = false
    @State private var result: DateDebrief.Analysis? = nil
    @State private var err = ""
    @FocusState private var f: Bool

    enum St { case info, notes, result }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                switch step {
                case .info:   infoStep
                case .notes:  notesStep
                case .result: resultStep
                }
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary) } }
        }
    }

    var infoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SP.xl) {
                OBHead(step: "Step 1 of 2", title: "Who was\nthe date with?", sub: "Just enough context.")
                VStack(spacing: 14) {
                    SF(label: "Their Name", icon: "person.fill", ph: "First name or nickname", text: $d.personName)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Which date was this?", systemImage: "number.circle.fill").font(RWF.cap()).foregroundColor(.rwTextMuted)
                        HStack(spacing: 8) {
                            ForEach([1,2,3,4,5], id: \.self) { n in
                                Button("\(n)") { d.dateNumber = n }
                                    .font(RWF.head())
                                    .foregroundColor(d.dateNumber == n ? .white : .rwTextSecondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                                    .background(d.dateNumber == n ? Color.rwAccent : Color.rwCard)
                                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                                    .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
                                    .buttonStyle(SBS())
                            }
                        }
                    }
                }
                .padding(.horizontal, SP.xl)
                RWButton("Next", icon: "arrow.right") { withAnimation { step = .notes } }
                    .padding(.horizontal, SP.xl).padding(.bottom, 48)
                    .disabled(d.personName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(d.personName.isEmpty ? 0.5 : 1)
            }
            .padding(.top, 20)
        }
    }

    var notesStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            OBHead(step: "Step 2 of 2", title: "How did it\nactually go?", sub: "Be honest. No judgment.").padding(.bottom, SP.md)
            ZStack(alignment: .topLeading) {
                if d.notes.isEmpty {
                    Text("Tell me everything. Energy, vibes, what you liked, what felt off...")
                        .font(RWF.body()).foregroundColor(.rwTextMuted)
                        .padding(.horizontal, 20).padding(.vertical, 16).allowsHitTesting(false)
                }
                TextEditor(text: $d.notes)
                    .font(RWF.body()).foregroundColor(.rwTextPrimary)
                    .scrollContentBackground(.hidden).padding(.horizontal, 16).padding(.vertical, 12).focused($f)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(f ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))
            .padding(.horizontal, SP.lg).onAppear { f = true }

            VStack(spacing: 10) {
                if !err.isEmpty { Text(err).font(RWF.cap()).foregroundColor(.rwDanger) }
                RWButton(analyzing ? "Analyzing..." : (AISettings.shared.isEnabled ? "Analyze with Cyrano" : "Save Notes"), icon: analyzing ? nil : "sparkles") {
                    f = false
                    if AISettings.shared.isEnabled { Task { await analyze() } }
                    else { save(); dismiss() }
                }
                .disabled(d.notes.trimmingCharacters(in: .whitespaces).isEmpty || analyzing)
                .opacity(d.notes.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, SP.lg).padding(.vertical, SP.lg)
        }
    }

    var resultStep: some View {
        ScrollView {
            VStack(spacing: SP.lg) {
                if let a = result {
                    VStack(spacing: 10) {
                        Image(systemName: a.recommendation.icon).font(.system(size: 44, design: .rounded)).foregroundColor(a.recommendation.color)
                        Text(a.recommendation.rawValue).font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                        Text(a.keyInsight).font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .padding(.top, 28)

                    if !a.greenFlags.isEmpty  { Flags(title: "Green Flags",   flags: a.greenFlags,  color: .rwSuccess, icon: "checkmark.seal.fill") }
                    if !a.yellowFlags.isEmpty { Flags(title: "Watch Out For", flags: a.yellowFlags, color: .rwGold,    icon: "exclamationmark.triangle.fill") }
                    if !a.redFlags.isEmpty    { Flags(title: "Red Flags",     flags: a.redFlags,    color: .rwDanger,  icon: "xmark.octagon.fill") }

                    if !a.suggestedMessage.isEmpty {
                        RWCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Suggested Follow-Up").font(RWF.head()).foregroundColor(.rwTextPrimary)
                                Text(a.suggestedMessage).font(RWF.body()).foregroundColor(.rwTextPrimary).fixedSize(horizontal: false, vertical: true)
                                Button { UIPasteboard.general.string = a.suggestedMessage } label: {
                                    Label("Copy", systemImage: "doc.on.doc").font(RWF.cap()).foregroundColor(.rwAccent)
                                }
                            }
                        }
                    }

                    Text("AI analysis — not professional advice. Trust your own instincts.")
                        .font(.system(size: 11, design: .rounded)).foregroundColor(.rwTextMuted).multilineTextAlignment(.center).padding(.horizontal)

                    RWButton("Save to Journal", icon: "book.fill", style: .secondary) {
                        d.analysis = result; save(); dismiss()
                    }
                    .padding(.bottom, 48)
                } else {
                    RWLoading(msg: "Reading between the lines...")
                }
            }
            .padding(.horizontal, SP.lg)
        }
    }

    func analyze() async {
        analyzing = true; err = ""
        withAnimation { step = .result }
        do { result = try await Claude.shared.debrief(notes: d.notes, name: d.personName, num: d.dateNumber) }
        catch { err = error.localizedDescription; withAnimation { step = .notes } }
        analyzing = false
    }

    func save() { DebriefStore.shared.add(d) }
}

struct Flags: View {
    let title: String; let flags: [String]; let color: Color; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(color)
                Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
            }
            VStack(spacing: 6) {
                ForEach(flags, id: \.self) { flag in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(color).frame(width: 5, height: 5).padding(.top, 7)
                        Text(flag).font(RWF.body()).foregroundColor(.rwTextSecondary).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
            .padding(SP.md).background(color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }
}

struct DebriefDetail: View {
    let d: DateDebrief
    var body: some View {
        ScrollView {
            VStack(spacing: SP.lg) {
                if let a = d.analysis {
                    VStack(spacing: 10) {
                        Image(systemName: a.recommendation.icon).font(.system(size: 44, design: .rounded)).foregroundColor(a.recommendation.color)
                        Text(a.recommendation.rawValue).font(RWF.display(26)).foregroundColor(.rwTextPrimary)
                        Text(a.keyInsight).font(RWF.body()).foregroundColor(.rwTextSecondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                    .padding(.top, 20)
                    if !a.greenFlags.isEmpty  { Flags(title: "Green Flags",   flags: a.greenFlags,  color: .rwSuccess, icon: "checkmark.seal.fill") }
                    if !a.yellowFlags.isEmpty { Flags(title: "Watch Out For", flags: a.yellowFlags, color: .rwGold,    icon: "exclamationmark.triangle.fill") }
                    if !a.redFlags.isEmpty    { Flags(title: "Red Flags",     flags: a.redFlags,    color: .rwDanger,  icon: "xmark.octagon.fill") }
                }
            }
            .padding(.horizontal, SP.lg).padding(.bottom, 60)
        }
        .rwBG()
        .navigationTitle("Date \(d.dateNumber) with \(d.personName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}
