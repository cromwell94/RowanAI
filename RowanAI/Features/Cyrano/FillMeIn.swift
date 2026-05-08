import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct FillMeInExchange: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var side: Side
    var text: String

    enum Side: String, Codable {
        case me
        case them
    }
}

struct SavedConversation: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var contactName: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var exchanges: [FillMeInExchange]
    var context: String
    var cyranoAnalysis: Claude.FillMeInAnalysis?

    var preview: String {
        if let first = exchanges.first {
            let prefix = first.side == .me ? "You: " : "Them: "
            return prefix + first.text
        }
        return "Empty conversation"
    }
}

// MARK: - Conversation Store
// Persists saved conversations to disk under .completeFileProtection so they're
// only readable when the device is unlocked. Files live in
// Application Support/FillMeIn/<id>.json.

@MainActor
@Observable
final class ConversationStore {
    static let shared = ConversationStore()

    var conversations: [SavedConversation] = []

    private let folderName = "FillMeIn"

    private init() { reload() }

    // MARK: - Disk I/O

    private var folderURL: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true) else { return nil }
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func reload() {
        guard let folder = folderURL else { return }
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var loaded: [SavedConversation] = []
        let decoder = JSONDecoder()
        for url in urls where url.pathExtension == "json" {
            if let data = try? Data(contentsOf: url),
               let conv = try? decoder.decode(SavedConversation.self, from: data) {
                loaded.append(conv)
            }
        }
        conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conv: SavedConversation) {
        guard let folder = folderURL else { return }
        var copy = conv
        copy.updatedAt = Date()
        let url = folder.appendingPathComponent("\(copy.id.uuidString).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(copy) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])

        if let idx = conversations.firstIndex(where: { $0.id == copy.id }) {
            conversations[idx] = copy
        } else {
            conversations.insert(copy, at: 0)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    func delete(_ id: UUID) {
        guard let folder = folderURL else { return }
        let url = folder.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
        conversations.removeAll { $0.id == id }
    }
}

// MARK: - Fill Me In View

struct FillMeInView: View {
    @State private var store = ConversationStore.shared
    @State private var current: SavedConversation = .init(exchanges: [], context: "")

    @State private var loading = false
    @State private var error: String? = nil
    @State private var showPaywall = false
    @State private var showCrisis = false

    @State private var draggedID: UUID? = nil
    @FocusState private var focusedExchangeID: UUID?
    @FocusState private var contextFocused: Bool
    @State private var storeManager = StoreManager.shared

    private var canAnalyze: Bool {
        current.exchanges.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {

                CrisisBanner(show: $showCrisis)

                hero

                if !storeManager.isPro {
                    quotaBar
                }

                columnHeaders

                if current.exchanges.isEmpty {
                    emptyState
                } else {
                    bubbles
                }

                addButtons

                contextField

                askButton

                if loading { Dots(msg: "Cyrano is reading the room…") }

                if let error {
                    Text(error).font(RWF.body(13)).foregroundColor(.rwDanger)
                        .padding(SP.md).background(Color.rwDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                }

                if let analysis = current.cyranoAnalysis {
                    AnalysisSection(analysis: analysis)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if !store.conversations.isEmpty {
                    recentSection
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 16)
        }
        .rwBG()
        .hideKB()
        .sheet(isPresented: $showPaywall) { PaywallView(reason: .fillMeInLimit) }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: current.exchanges)
        .animation(.easeOut(duration: 0.25), value: current.cyranoAnalysis)
    }

    // MARK: hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FILL ME IN")
                .font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text("Walk Cyrano through the conversation.")
                .font(RWF.title(24))
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Type each message exchange — left for you, right for them. Cyrano reads the whole thing and coaches you.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quotaBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LinearGradient.accent)
            Text("\(storeManager.fillMeInsRemainingThisWeek()) free \(storeManager.fillMeInsRemainingThisWeek() == 1 ? "analysis" : "analyses") left this week")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextSecondary)
            Spacer()
            Button { showPaywall = true } label: {
                Text("Go Pro")
                    .font(RWF.cap(12))
                    .foregroundStyle(LinearGradient.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.rwSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
    }

    // MARK: column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("I SAID")
                    .font(RWF.micro())
                    .foregroundColor(Color(hex: "E8356D"))
                    .tracking(1.6)
                Capsule().fill(Color(hex: "E8356D")).frame(width: 28, height: 2)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 2) {
                Text("THEY SAID")
                    .font(RWF.micro())
                    .foregroundColor(Color(hex: "00BFB3"))
                    .tracking(1.6)
                Capsule().fill(Color(hex: "00BFB3")).frame(width: 28, height: 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: bubbles

    private var bubbles: some View {
        VStack(spacing: 8) {
            ForEach(current.exchanges) { exchange in
                BubbleRow(
                    exchange: bindingFor(exchange.id),
                    focused: $focusedExchangeID,
                    onDelete: { delete(exchange.id) }
                )
                .onDrag {
                    draggedID = exchange.id
                    return NSItemProvider(object: exchange.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: RowDropDelegate(
                    target: exchange.id,
                    exchanges: $current.exchanges,
                    draggedID: $draggedID
                ))
            }
        }
    }

    private func bindingFor(_ id: UUID) -> Binding<FillMeInExchange> {
        Binding(
            get: { current.exchanges.first { $0.id == id } ?? FillMeInExchange(side: .me, text: "") },
            set: { newValue in
                if let idx = current.exchanges.firstIndex(where: { $0.id == id }) {
                    current.exchanges[idx] = newValue
                }
            }
        )
    }

    private func delete(_ id: UUID) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            current.exchanges.removeAll { $0.id == id }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(LinearGradient.accentSoft)
            Text("Start with what you said or what they said.")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).strokeBorder(Color.rwBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    // MARK: add buttons

    private var addButtons: some View {
        HStack(spacing: 10) {
            addButton(label: "I said", color: Color(hex: "E8356D"), side: .me)
            addButton(label: "They said", color: Color(hex: "00BFB3"), side: .them)
        }
    }

    private func addButton(label: String, color: Color, side: FillMeInExchange.Side) -> some View {
        Button {
            let new = FillMeInExchange(side: side, text: "")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                current.exchanges.append(new)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedExchangeID = new.id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(label).font(RWF.cap(13))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(SBS())
    }

    // MARK: context

    private var contextField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Add context (optional)", systemImage: "info.circle")
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
            TextField(
                "e.g. we matched 3 days ago, this is after our first date, we've been talking for a week",
                text: $current.context,
                axis: .vertical
            )
            .focused($contextFocused)
            .font(RWF.body(14))
            .foregroundColor(.rwTextPrimary)
            .lineLimit(1...3)
            .padding(SP.md).background(Color.rwSurface)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(contextFocused ? Color.rwAccent.opacity(0.4) : Color.rwBorder, lineWidth: 1))
        }
    }

    // MARK: ask button

    private var askButton: some View {
        RWButton(loading ? "Asking Cyrano…" : "Ask Cyrano",
                 icon: loading ? nil : "arrow.right") {
            focusedExchangeID = nil
            contextFocused = false
            if storeManager.canUseFillMeIn() {
                Task { await analyze() }
            } else {
                showPaywall = true
            }
        }
        .disabled(loading || !canAnalyze)
        .opacity(canAnalyze ? 1 : 0.5)
    }

    // MARK: recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RWSectionLabel("RECENT CONVERSATIONS")
                .padding(.top, SP.md)

            VStack(spacing: 8) {
                ForEach(store.conversations) { conv in
                    SavedConversationRow(
                        conversation: conv,
                        isOpen: conv.id == current.id,
                        onTap: { open(conv) },
                        onDelete: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                store.delete(conv.id)
                                if conv.id == current.id {
                                    current = SavedConversation(exchanges: [], context: "")
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    private func open(_ conv: SavedConversation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            current = conv
            error = nil
        }
    }

    // MARK: analyze

    private func analyze() async {
        loading = true
        error = nil
        defer { loading = false }

        let myMessages = current.exchanges
            .filter { $0.side == .me }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let theirMessages = current.exchanges
            .filter { $0.side == .them }
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            let analysis = try await Claude.shared.fillMeIn(
                myMessages: myMessages,
                theirMessages: theirMessages,
                context: current.context.trimmingCharacters(in: .whitespacesAndNewlines))
            current.cyranoAnalysis = analysis
            store.save(current)
            StoreManager.shared.trackFillMeInUsed()
            StreakManager.shared.addPoints(5, reason: "fillmein")
        } catch let e {
            if e.localizedDescription == "crisis" {
                withAnimation { showCrisis = true }
            } else {
                error = e.localizedDescription
            }
        }
    }
}

// MARK: - Bubble Row
// One conversation row. Rendered as a chat bubble — pink on left for the user,
// teal on right for the other person. Inline TextEditor — tap to edit.

struct BubbleRow: View {
    @Binding var exchange: FillMeInExchange
    var focused: FocusState<UUID?>.Binding
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var deleting = false

    private var color: Color {
        exchange.side == .me ? Color(hex: "E8356D") : Color(hex: "00BFB3")
    }

    private var isFocused: Bool {
        focused.wrappedValue == exchange.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if exchange.side == .them { Spacer(minLength: 50) }

            VStack(alignment: exchange.side == .me ? .leading : .trailing, spacing: 0) {
                bubble
            }

            if exchange.side == .me { Spacer(minLength: 50) }
        }
        .offset(x: offsetX)
        .opacity(deleting ? 0 : 1)
        .gesture(swipeGesture)
    }

    private var bubble: some View {
        ZStack(alignment: .topLeading) {
            // Background bubble
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isFocused ? color : color.opacity(0.25), lineWidth: isFocused ? 1.5 : 1)
                )

            // Editable text
            VStack(alignment: .leading, spacing: 0) {
                if exchange.text.isEmpty && !isFocused {
                    Text(exchange.side == .me ? "Type what you said…" : "Type what they said…")
                        .font(RWF.body(14))
                        .foregroundColor(.rwTextMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                }
                TextField(
                    exchange.side == .me ? "Your message" : "Their message",
                    text: $exchange.text,
                    axis: .vertical
                )
                .focused(focused, equals: exchange.id)
                .font(RWF.body(14))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(1...8)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .submitLabel(.done)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 260, alignment: exchange.side == .me ? .leading : .trailing)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                // Swipe left to reveal delete; clamp.
                offsetX = max(-100, min(0, value.translation.width))
            }
            .onEnded { value in
                if value.translation.width < -60 {
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    withAnimation(.easeIn(duration: 0.18)) {
                        offsetX = -400
                        deleting = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        onDelete()
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        offsetX = 0
                    }
                }
            }
    }
}

// MARK: - Drop delegate (drag-to-reorder)

private struct RowDropDelegate: DropDelegate {
    let target: UUID
    @Binding var exchanges: [FillMeInExchange]
    @Binding var draggedID: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedID,
              dragged != target,
              let from = exchanges.firstIndex(where: { $0.id == dragged }),
              let to = exchanges.firstIndex(where: { $0.id == target })
        else { return }
        if exchanges[from].id != exchanges[to].id {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                exchanges.move(fromOffsets: IndexSet(integer: from),
                               toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

// MARK: - Analysis Section

struct AnalysisSection: View {
    let analysis: Claude.FillMeInAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RWSectionLabel("CYRANO'S READ")

            block(title: "The Dynamic", icon: "waveform", body: analysis.dynamic, color: .rwAccent)
            block(title: "What They're Saying", icon: "ear.fill", body: analysis.subtext, color: .rwViolet)
            block(title: "What's Working", icon: "checkmark.seal.fill", body: analysis.working, color: .rwSuccess)
            block(title: "What to Watch", icon: "exclamationmark.circle.fill", body: analysis.watch, color: .rwWarning)

            if !analysis.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Cyrano's Suggestion — what to say next",
                          systemImage: "sparkles")
                        .font(RWF.head(14))
                        .foregroundColor(.rwTextPrimary)
                        .padding(.top, 4)

                    ForEach(Array(analysis.suggestions.enumerated()), id: \.offset) { _, s in
                        SuggestionCard(tone: s.tone, text: s.text)
                    }
                }
            }
        }
    }

    private func block(title: String, icon: String, body: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(RWF.head(14))
                    .foregroundColor(.rwTextPrimary)
            }
            Text(body)
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(color.opacity(0.18), lineWidth: 1))
    }
}

struct SuggestionCard: View {
    let tone: String
    let text: String
    @State private var copied = false

    private var toneEnum: CyranoSuggestion.Tone? {
        CyranoSuggestion.Tone(rawValue: tone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    if let t = toneEnum {
                        Image(systemName: t.icon).font(.system(size: 11, weight: .bold))
                    }
                    Text(tone.uppercased()).font(RWF.micro()).tracking(1.5)
                }
                .foregroundColor(toneEnum?.color ?? .rwAccent)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background((toneEnum?.color ?? .rwAccent).opacity(0.12))
                .clipShape(Capsule())
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copied ? "Copied" : "Copy").font(RWF.cap(12))
                    }
                    .foregroundColor(copied ? .white : .rwTextSecondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(copied ? Color.rwSuccess : Color.rwCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(copied ? Color.clear : Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
            Text(text)
                .font(RWF.body())
                .foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - Saved Conversation Row

struct SavedConversationRow: View {
    let conversation: SavedConversation
    let isOpen: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var deleting = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                Button(action: triggerDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.rwDanger)
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                }
                .buttonStyle(SBS())
            }

            // Foreground row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(LinearGradient.accent)
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(conversation.contactName ?? "Conversation")
                                .font(RWF.head(14))
                                .foregroundColor(.rwTextPrimary)
                            Text(timeAgo(conversation.updatedAt))
                                .font(RWF.cap(11))
                                .foregroundColor(.rwTextMuted)
                        }
                        Text(conversation.preview)
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if conversation.cyranoAnalysis != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(LinearGradient.accent)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rwTextMuted)
                }
                .padding(SP.md)
                .background(isOpen ? Color.rwAccent.opacity(0.06) : Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: RR.lg)
                        .stroke(isOpen ? Color.rwAccent.opacity(0.3) : Color.rwBorder,
                                lineWidth: isOpen ? 1.5 : 1)
                )
            }
            .buttonStyle(SBS())
            .offset(x: offsetX)
            .gesture(swipeGesture)
            .opacity(deleting ? 0 : 1)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                offsetX = max(-72, min(0, value.translation.width))
            }
            .onEnded { value in
                if value.translation.width < -56 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        offsetX = -72
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        offsetX = 0
                    }
                }
            }
    }

    private func triggerDelete() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeIn(duration: 0.18)) {
            offsetX = -400
            deleting = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDelete()
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
