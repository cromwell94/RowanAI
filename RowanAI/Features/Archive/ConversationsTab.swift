import SwiftUI
import PhotosUI
import UIKit

// MARK: - Conversations Tab Content
//
// Lives inside ContactDetailView's "Conversations" section. Renders one
// platform pill per active thread plus an "Add Platform" button that opens
// the categorized picker. The full cross-platform timeline is reachable via
// the "Full Timeline" button at the top.

struct ConversationsTabContent: View {
    let person: Person

    @State private var store = ChatThreadStore.shared
    @State private var selectedThreadID: String? = nil
    @State private var showPlatformPicker = false
    @State private var showFullTimeline = false
    @State private var addMessageSheet: AddMessageContext? = nil

    // Screenshot import
    @State private var screenshotPick: PhotosPickerItem? = nil
    @State private var screenshotThreadID: String? = nil
    @State private var screenshotState: ScreenshotImportState = .idle
    @State private var showScreenshotPreview = false

    enum ScreenshotImportState: Equatable {
        case idle
        case extracting
        case ready([ExtractedMessage])
        case failed(String)
    }

    private var threads: [ConversationThread] {
        store.threads(for: person.id)
    }

    private var totalMessages: Int {
        store.messageCount(for: person.id)
    }

    private var activeThread: ConversationThread? {
        if let id = selectedThreadID,
           let match = threads.first(where: { $0.id == id }) {
            return match
        }
        return threads.first
    }

    var body: some View {
        VStack(spacing: 14) {
            if threads.isEmpty {
                emptyState
            } else {
                summaryBar
                platformStrip
                if let thread = activeThread {
                    threadView(thread)
                }
            }
        }
        .sheet(isPresented: $showPlatformPicker) {
            PlatformPickerSheet(
                excluding: Set(threads.map { $0.platform })
            ) { platform in
                let new = store.addThread(contactID: person.id, platform: platform)
                selectedThreadID = new.id
                showPlatformPicker = false
            }
        }
        .sheet(isPresented: $showFullTimeline) {
            FullTimelineSheet(person: person)
        }
        .sheet(item: $addMessageSheet) { ctx in
            AddMessageSheet(threadID: ctx.threadID,
                            platform: ctx.platform,
                            sender: ctx.sender) { sender, text, when in
                store.addMessage(to: ctx.threadID,
                                 sender: sender,
                                 text: text,
                                 at: when)
                // Living analysis is fed by every new message; the service
                // honors a 1-hour cooldown so this is safe to fire here.
                RelationshipAnalysisService.shared.generateIfNeeded(for: person)
                addMessageSheet = nil
            }
        }
        // Screenshot import: PhotosPickerItem → image → Cyrano vision → preview
        .onChange(of: screenshotPick) { _, newValue in
            guard let item = newValue else { return }
            Task { await processScreenshot(item) }
        }
        .sheet(isPresented: $showScreenshotPreview) {
            screenshotPreviewSheet
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundColor(.rwTextMuted)
            Text("No conversations tracked yet")
                .font(RWF.head(16)).foregroundColor(.rwTextPrimary)
            Text("Add a thread for every platform you're talking on. Cyrano reads them all together.")
                .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.lg)
            RWButton("Add Platform", icon: "plus", style: .primary) {
                showPlatformPicker = true
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Summary bar

    private var summaryBar: some View {
        HStack(spacing: 8) {
            Text("\(totalMessages) message\(totalMessages == 1 ? "" : "s") · \(threads.count) platform\(threads.count == 1 ? "" : "s")")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextSecondary)

            Spacer()

            if totalMessages > 0 {
                Button { showFullTimeline = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Full Timeline")
                            .font(RWF.cap())
                    }
                    .foregroundColor(.rwAccent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.rwAccent.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(SBS())
            }
        }
    }

    // MARK: - Platform strip

    private var platformStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(threads) { thread in
                    let selected = (activeThread?.id == thread.id)
                    Button {
                        selectedThreadID = thread.id
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: thread.platform.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(thread.platform.rawValue)
                                .font(RWF.cap())
                            Text("\(thread.messages.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(selected ? .white : .rwTextMuted)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(selected ? Color.white.opacity(0.25) : Color.rwTextMuted.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .foregroundColor(selected ? .white : .rwTextSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(selected ? thread.platform.color : Color.rwCard)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selected ? Color.clear : Color.rwBorder,
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(SBS())
                }

                Button { showPlatformPicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Add Platform")
                    }
                    .font(RWF.cap())
                    .foregroundColor(.rwAccent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.rwAccent.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.rwAccent.opacity(0.30), style: StrokeStyle(lineWidth: 1, dash: [3])))
                }
                .buttonStyle(SBS())
            }
        }
    }

    // MARK: - Thread view

    @ViewBuilder
    private func threadView(_ thread: ConversationThread) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: thread.platform.icon)
                    .foregroundColor(thread.platform.color)
                Text(thread.platform.rawValue)
                    .font(RWF.head(14))
                    .foregroundColor(.rwTextPrimary)
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        store.deleteThread(thread)
                        selectedThreadID = nil
                    } label: {
                        Label("Delete this thread", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.rwTextMuted)
                }
            }

            if thread.messages.isEmpty {
                Text("Add the first message — what was said and by whom.")
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextSecondary)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.rwSurface)
                    .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            } else {
                ForEach(thread.messages) { message in
                    MessageBubble(message: message,
                                  showPlatformBadge: false)
                }
            }

            HStack(spacing: 10) {
                Button {
                    addMessageSheet = AddMessageContext(
                        threadID: thread.id,
                        platform: thread.platform,
                        sender: .them
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.bubble")
                        Text("They said")
                    }
                    .font(RWF.cap())
                    .foregroundColor(.rwGold)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.rwGold.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(SBS())

                Button {
                    addMessageSheet = AddMessageContext(
                        threadID: thread.id,
                        platform: thread.platform,
                        sender: .user
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.bubble.fill")
                        Text("I said")
                    }
                    .font(RWF.cap())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(SBS())
            }

            // Screenshot import — Cyrano reads the image and extracts each message
            screenshotImportButton(threadID: thread.id)
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }

    // MARK: - Screenshot Import

    @ViewBuilder
    private func screenshotImportButton(threadID: String) -> some View {
        let isExtractingThis = (screenshotThreadID == threadID)
            && screenshotState == .extracting

        PhotosPicker(
            selection: Binding(
                get: { screenshotPick },
                set: { newValue in
                    // Stash the thread ID so the async handler knows which
                    // thread the extracted messages belong to.
                    if newValue != nil { screenshotThreadID = threadID }
                    screenshotPick = newValue
                }
            ),
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 6) {
                if isExtractingThis {
                    ProgressView().tint(.rwAccent)
                    Text("Reading screenshot…")
                } else {
                    Image(systemName: "camera.viewfinder")
                    Text("Import Screenshot")
                }
            }
            .font(RWF.cap())
            .foregroundColor(.rwAccent)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Color.rwAccent.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.rwAccent.opacity(0.25),
                                      style: StrokeStyle(lineWidth: 1, dash: [3])))
        }
        .disabled(isExtractingThis)

        if case .failed(let message) = screenshotState, screenshotThreadID == threadID {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.rwGold)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.rwTextSecondary)
            }
            .padding(.top, 4)
        }
    }

    private func processScreenshot(_ item: PhotosPickerItem) async {
        screenshotState = .extracting
        defer { screenshotPick = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            screenshotState = .failed("Couldn't read that image. Try another.")
            return
        }

        do {
            let extracted = try await ScreenshotMessageExtractor.extract(from: image)
            if extracted.isEmpty {
                screenshotState = .failed("Cyrano couldn't find any messages in that screenshot.")
                return
            }
            screenshotState = .ready(extracted)
            showScreenshotPreview = true
        } catch {
            screenshotState = .failed("Cyrano couldn't read this screenshot. Try a clearer one.")
        }
    }

    @ViewBuilder
    private var screenshotPreviewSheet: some View {
        if case .ready(let messages) = screenshotState,
           let threadID = screenshotThreadID,
           let thread = store.thread(id: threadID) {
            ScreenshotPreviewSheet(
                platform: thread.platform,
                messages: messages,
                onConfirm: { confirmed in
                    for message in confirmed {
                        store.addMessage(
                            to: threadID,
                            sender: message.sender,
                            text: message.text
                        )
                    }
                    RelationshipAnalysisService.shared.generateIfNeeded(for: person)
                    showScreenshotPreview = false
                    screenshotState = .idle
                    screenshotThreadID = nil
                },
                onCancel: {
                    showScreenshotPreview = false
                    screenshotState = .idle
                    screenshotThreadID = nil
                }
            )
        } else {
            // Fallback shouldn't fire — preview is only shown when state is .ready.
            VStack {
                Text("No messages to import.")
                    .font(RWF.body())
                    .foregroundColor(.rwTextSecondary)
                    .padding(40)
                Button("Close") {
                    showScreenshotPreview = false
                    screenshotState = .idle
                }
                .foregroundColor(.rwAccent)
            }
            .rwBG()
        }
    }
}

// MARK: - Add Message Context

struct AddMessageContext: Identifiable {
    let threadID: String
    let platform: ConversationPlatform
    let sender: ThreadMessage.MessageSender
    var id: String { threadID + sender.rawValue }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ThreadMessage
    let showPlatformBadge: Bool

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d · h:mm a"
        return df
    }()

    var body: some View {
        HStack(alignment: .top) {
            if message.sender == .user { Spacer(minLength: 40) }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(RWF.body(14))
                    .foregroundColor(message.sender == .user ? .white : .rwTextPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(
                        Group {
                            if message.sender == .user {
                                LinearGradient.accent
                            } else {
                                Color.rwSurface
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 4) {
                    if showPlatformBadge {
                        Image(systemName: message.platform.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(message.platform.color)
                    }
                    Text(Self.timeFormatter.string(from: message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.rwTextMuted)
                }
            }

            if message.sender == .them { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Add Message Sheet

struct AddMessageSheet: View {
    let threadID: String
    let platform: ConversationPlatform
    let sender: ThreadMessage.MessageSender
    let onAdd: (ThreadMessage.MessageSender, String, Date) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var text: String = ""
    @State private var when: Date = Date()
    @State private var customizeTimestamp = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: SP.lg) {
                    HStack(spacing: 8) {
                        Image(systemName: platform.icon)
                            .foregroundColor(platform.color)
                        Text("\(sender.rawValue) · \(platform.rawValue)")
                            .font(RWF.head(15))
                            .foregroundColor(.rwTextPrimary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(sender == .user ? "What did you say?" : "What did they say?")
                            .font(RWF.cap()).foregroundColor(.rwTextMuted)

                        TextField("",
                                  text: $text,
                                  prompt: Text("Type the message…").foregroundColor(.rwTextMuted),
                                  axis: .vertical)
                            .font(RWF.body())
                            .foregroundColor(.rwTextPrimary)
                            .padding(SP.md)
                            .frame(minHeight: 100, alignment: .topLeading)
                            .background(Color.rwCard)
                            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                            .lineLimit(3...8)
                    }

                    Toggle(isOn: $customizeTimestamp) {
                        Text("Set a specific time").font(RWF.cap()).foregroundColor(.rwTextSecondary)
                    }
                    .tint(.rwAccent)

                    if customizeTimestamp {
                        DatePicker("When", selection: $when, in: ...Date())
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(.rwAccent)
                    }
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 12)
            }
            .rwBG()
            .navigationTitle("Add Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(sender, text, customizeTimestamp ? when : Date())
                    }
                    .font(RWF.med(15))
                    .foregroundColor(.rwAccent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Platform Picker Sheet

struct PlatformPickerSheet: View {
    let excluding: Set<ConversationPlatform>
    let onPick: (ConversationPlatform) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var search: String = ""

    private var filtered: [ConversationPlatform.PlatformCategory: [ConversationPlatform]] {
        let base = ConversationPlatform.allCases.filter { !excluding.contains($0) }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let matched = q.isEmpty ? base : base.filter { $0.rawValue.lowercased().contains(q) }
        return Dictionary(grouping: matched, by: { $0.category })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.rwTextMuted)
                    TextField("",
                              text: $search,
                              prompt: Text("Search platforms").foregroundColor(.rwTextMuted))
                        .font(RWF.body()).foregroundColor(.rwTextPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.rwTextMuted)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                .padding(.horizontal, SP.lg).padding(.top, 12).padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SP.lg) {
                        ForEach(ConversationPlatform.PlatformCategory.allCases, id: \.self) { category in
                            if let items = filtered[category], !items.isEmpty {
                                section(title: category.rawValue, items: items)
                            }
                        }
                        if filtered.values.allSatisfy({ $0.isEmpty }) {
                            VStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 28))
                                    .foregroundColor(.rwTextMuted)
                                Text("No platforms match \"\(search)\"")
                                    .font(RWF.body()).foregroundColor(.rwTextSecondary)
                            }
                            .padding(.vertical, 60)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, SP.lg)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .rwBG()
            .navigationTitle("Add Platform")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
            }
        }
    }

    private func section(title: String, items: [ConversationPlatform]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(RWF.cap(11))
                .foregroundColor(.rwTextMuted)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(items) { platform in
                    Button { onPick(platform) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: platform.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(platform.color)
                                .frame(width: 22)
                            Text(platform.rawValue)
                                .font(RWF.body(13))
                                .foregroundColor(.rwTextPrimary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(Color.rwCard)
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                }
            }
        }
    }
}

// MARK: - Screenshot Message Extractor
//
// Sends a conversation screenshot to Cyrano and parses the JSON result into
// a list of extracted messages. Lives outside the view so the preview sheet
// and any future re-import flow can share the same parsing.

struct ExtractedMessage: Identifiable, Equatable {
    let id = UUID()
    var sender: ThreadMessage.MessageSender
    var text: String
}

enum ScreenshotMessageExtractor {

    enum ExtractError: Error {
        case parse
        case empty
    }

    static func extract(from image: UIImage) async throws -> [ExtractedMessage] {
        let system = """
        You are a precise OCR parser for dating-app and messaging conversation screenshots.

        Read every visible message bubble in the screenshot, top to bottom.
        For each message decide which side it came from:
          • "Me" — the user's own messages (typically the right-aligned, colored bubbles)
          • "Them" — messages from the other person (typically left-aligned)

        STRICT RULES:
        - Output ONLY a JSON object. No preamble, no markdown fences.
        - If you can't read a message confidently, omit it — don't guess.
        - Preserve the actual text exactly. Don't rephrase or summarize.
        - Skip timestamps, "Read receipts", and system labels — only the messages themselves.

        Output shape (every key required):
        {
          "messages": [
            { "sender": "Me" | "Them", "text": "<exact message text>" }
          ]
        }
        """

        let user = "Extract every visible message in this screenshot."

        let raw = try await Claude.shared.send(
            system: system,
            user: user,
            image: image,
            max: 1500
        )

        let cleaned = Claude.shared.clean(raw)
        return try parse(cleaned)
    }

    static func parse(_ raw: String) throws -> [ExtractedMessage] {
        // Locate the first balanced JSON object — guards against stray
        // commentary that occasionally leaks past the "ONLY JSON" rule.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate: String = {
            if let start = trimmed.firstIndex(of: "{"),
               let end = trimmed.lastIndex(of: "}"),
               start < end {
                return String(trimmed[start...end])
            }
            return trimmed
        }()

        guard let data = candidate.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["messages"] as? [[String: Any]]
        else { throw ExtractError.parse }

        let extracted: [ExtractedMessage] = raw.compactMap { dict in
            guard let senderText = dict["sender"] as? String,
                  let text = dict["text"] as? String else { return nil }
            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanText.isEmpty else { return nil }
            // Be lenient about case + variants: "me", "user", "self" → user.
            let normalized = senderText.lowercased()
            let sender: ThreadMessage.MessageSender =
                ["me", "user", "self", "i"].contains(normalized) ? .user : .them
            return ExtractedMessage(sender: sender, text: cleanText)
        }
        return extracted
    }
}

// MARK: - Screenshot Preview Sheet
//
// Shows the messages Cyrano extracted with their predicted sender. The user
// can flip a sender if Cyrano misjudged or omit individual messages before
// confirming the import.

struct ScreenshotPreviewSheet: View {
    let platform: ConversationPlatform
    let messages: [ExtractedMessage]
    let onConfirm: ([ExtractedMessage]) -> Void
    let onCancel: () -> Void

    @State private var working: [ExtractedMessage]
    @State private var omitted: Set<UUID> = []

    init(platform: ConversationPlatform,
         messages: [ExtractedMessage],
         onConfirm: @escaping ([ExtractedMessage]) -> Void,
         onCancel: @escaping () -> Void) {
        self.platform = platform
        self.messages = messages
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _working = State(initialValue: messages)
    }

    private var keptCount: Int {
        working.count - omitted.count
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: platform.icon)
                            .foregroundColor(platform.color)
                        Text("\(messages.count) message\(messages.count == 1 ? "" : "s") detected on \(platform.rawValue)")
                            .font(RWF.head(14))
                            .foregroundColor(.rwTextPrimary)
                    }
                    Text("Review Cyrano's extraction. Tap a sender label to flip it, or remove a row to omit it.")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)

                    ForEach($working) { $message in
                        previewRow($message)
                    }
                }
                .padding(.horizontal, SP.lg)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .rwBG()
            .navigationTitle("Confirm Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(.rwTextSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                confirmBar
            }
        }
    }

    private func previewRow(_ binding: Binding<ExtractedMessage>) -> some View {
        let message = binding.wrappedValue
        let isOmitted = omitted.contains(message.id)

        return HStack(alignment: .top, spacing: 10) {
            Button {
                // Flip sender so Cyrano's misclassifications are easy to fix.
                binding.wrappedValue.sender = (message.sender == .user ? .them : .user)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text(message.sender.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(message.sender == .user ? Color.rwAccent : Color.rwGold)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())

            Text(message.text)
                .font(RWF.body(14))
                .foregroundColor(isOmitted ? .rwTextMuted : .rwTextPrimary)
                .strikethrough(isOmitted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if isOmitted { omitted.remove(message.id) } else { omitted.insert(message.id) }
            } label: {
                Image(systemName: isOmitted ? "arrow.uturn.backward" : "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.rwTextMuted)
                    .frame(width: 26, height: 26)
                    .background(Color.rwSurface)
                    .clipShape(Circle())
            }
            .buttonStyle(SBS())
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .opacity(isOmitted ? 0.6 : 1.0)
    }

    private var confirmBar: some View {
        HStack {
            Text("\(keptCount) of \(messages.count) will be added")
                .font(RWF.cap()).foregroundColor(.rwTextSecondary)
            Spacer()
            Button {
                let kept = working.filter { !omitted.contains($0.id) }
                onConfirm(kept)
            } label: {
                Text("Add to Thread")
                    .font(RWF.med(15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                    .opacity(keptCount == 0 ? 0.45 : 1)
            }
            .buttonStyle(SBS())
            .disabled(keptCount == 0)
        }
        .padding(.horizontal, SP.lg)
        .padding(.vertical, 12)
        .background(Color.rwSurface)
    }
}

// MARK: - Full Timeline Sheet

struct FullTimelineSheet: View {
    let person: Person
    @Environment(\.dismiss) var dismiss

    private var messages: [ThreadMessage] {
        ChatThreadStore.shared.allMessages(for: person.id)
    }

    private var platformCount: Int {
        ChatThreadStore.shared.platformCount(for: person.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Complete conversation history — \(messages.count) message\(messages.count == 1 ? "" : "s") across \(platformCount) platform\(platformCount == 1 ? "" : "s")")
                        .font(RWF.cap(12))
                        .foregroundColor(.rwTextSecondary)
                        .padding(.horizontal, SP.lg)
                        .padding(.top, 12)

                    ForEach(messages) { message in
                        MessageBubble(message: message, showPlatformBadge: true)
                            .padding(.horizontal, SP.lg)
                    }
                }
                .padding(.bottom, 40)
            }
            .rwBG()
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
        }
    }
}
