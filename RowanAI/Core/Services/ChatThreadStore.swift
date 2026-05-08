import Foundation
import SwiftUI

// MARK: - Conversation Store
//
// Persists every cross-platform thread the user has built for each contact.
// Stored as a single JSON file in the Documents directory with
// .completeFileProtection so the data is encrypted whenever the device is
// locked — the same protection class used by ArchiveStore.
//
// All mutating methods write through synchronously; the data set is small
// (hundreds of messages at most) so we never need a background queue.

@Observable
final class ChatThreadStore {
    static let shared = ChatThreadStore()

    var threads: [ConversationThread] = []

    private let key = "conversations_v1"

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations_v1.json")
    }

    init() { load() }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? JSONDecoder().decode([ConversationThread].self, from: data)
        else { return }
        threads = stored
    }

    func save() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Queries

    /// All threads for a contact, sorted by last activity descending so the
    /// most recently used platform pill appears first in the picker.
    func threads(for contactID: String) -> [ConversationThread] {
        threads
            .filter { $0.contactID == contactID }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    func thread(id: String) -> ConversationThread? {
        threads.first { $0.id == id }
    }

    func thread(for contactID: String, platform: ConversationPlatform) -> ConversationThread? {
        threads.first { $0.contactID == contactID && $0.platform == platform }
    }

    /// Every message for a contact across every platform, sorted ascending by
    /// timestamp. This is the canonical timeline Cyrano reads when generating
    /// the Living Relationship Analysis.
    func allMessages(for contactID: String) -> [ThreadMessage] {
        threads
            .filter { $0.contactID == contactID }
            .flatMap { $0.messages }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func messageCount(for contactID: String) -> Int {
        threads(for: contactID).reduce(0) { $0 + $1.messages.count }
    }

    func platformCount(for contactID: String) -> Int {
        threads(for: contactID).count
    }

    // MARK: - Mutations

    /// Returns the existing thread for the (contact, platform) pair if one
    /// exists, otherwise creates and persists a new one.
    @discardableResult
    func addThread(contactID: String, platform: ConversationPlatform) -> ConversationThread {
        if let existing = thread(for: contactID, platform: platform) {
            return existing
        }
        let new = ConversationThread(contactID: contactID, platform: platform)
        threads.append(new)
        save()
        return new
    }

    func addMessage(to threadID: String,
                    sender: ThreadMessage.MessageSender,
                    text: String,
                    at timestamp: Date = Date()) {
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let message = ThreadMessage(
            sender: sender,
            text: trimmed,
            timestamp: timestamp,
            platform: threads[i].platform
        )
        threads[i].messages.append(message)
        threads[i].lastActivityAt = timestamp
        save()
    }

    func deleteMessage(threadID: String, messageID: String) {
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[i].messages.removeAll { $0.id == messageID }
        save()
    }

    func deleteThread(_ thread: ConversationThread) {
        threads.removeAll { $0.id == thread.id }
        save()
    }

    func deleteAllThreads(for contactID: String) {
        threads.removeAll { $0.contactID == contactID }
        save()
    }

    func updateNotes(threadID: String, notes: String) {
        guard let i = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[i].notes = notes
        save()
    }
}
