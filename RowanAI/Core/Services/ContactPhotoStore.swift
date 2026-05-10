import Foundation
import UIKit

// MARK: - Contact Photo Store (Build 1 Step 8)
// Stores contact profile photos and intel-tab photo galleries on disk under
// Documents with NSFileProtectionComplete (encrypted when device is locked).
// File naming:
//   contact_photo_<contactID>.jpg                   — single profile photo
//   intel_photo_<contactID>_<UUID>.jpg              — gallery photos

struct ContactPhotoStore {
    static let shared = ContactPhotoStore()
    private init() {}

    // In-memory caches. NSCache is thread-safe and self-evicts under memory
    // pressure — exactly what we want for avatar thumbnails and per-contact
    // intel photo counts that ArchiveView reads on every scroll.
    private static let imageCache = NSCache<NSString, UIImage>()
    private static let countCache = NSCache<NSString, NSNumber>()

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: Profile photo

    func profilePhotoURL(contactID: String) -> URL {
        documentsDirectory.appendingPathComponent("contact_photo_\(contactID).jpg")
    }

    /// Synchronous load — only used internally and by callers that already
    /// know they're off the main thread. View code should use the async
    /// variant below to avoid blocking the main actor on JPEG decode.
    func loadProfilePhoto(contactID: String) -> UIImage? {
        let key = contactID as NSString
        if let cached = Self.imageCache.object(forKey: key) {
            return cached
        }
        let url = profilePhotoURL(contactID: contactID)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        Self.imageCache.setObject(image, forKey: key)
        return image
    }

    /// Async variant — checks the in-memory cache on the calling actor, falls
    /// back to a detached background task for the disk read + JPEG decode.
    /// Use this from any SwiftUI `.task` running on the MainActor.
    func loadProfilePhotoAsync(contactID: String) async -> UIImage? {
        let key = contactID as NSString
        if let cached = Self.imageCache.object(forKey: key) {
            return cached
        }
        let url = profilePhotoURL(contactID: contactID)
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        if let image {
            Self.imageCache.setObject(image, forKey: key)
        }
        return image
    }

    @discardableResult
    func saveProfilePhoto(_ image: UIImage, contactID: String) -> Bool {
        guard let data = downscaledJPEG(image, maxDimension: 1024) else { return false }
        let url = profilePhotoURL(contactID: contactID)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            // Update cache immediately so the next read sees the new photo.
            Self.imageCache.setObject(image, forKey: contactID as NSString)
            return true
        } catch {
            return false
        }
    }

    func deleteProfilePhoto(contactID: String) {
        try? FileManager.default.removeItem(at: profilePhotoURL(contactID: contactID))
        Self.imageCache.removeObject(forKey: contactID as NSString)
    }

    // MARK: Intel gallery

    func intelPhotoURLs(contactID: String) -> [URL] {
        let prefix = "intel_photo_\(contactID)_"
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }
        return contents
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "jpg" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b
            }
    }

    @discardableResult
    func saveIntelPhoto(_ image: UIImage, contactID: String) -> URL? {
        guard let data = downscaledJPEG(image, maxDimension: 1600) else { return nil }
        let photoID = UUID().uuidString
        let url = documentsDirectory
            .appendingPathComponent("intel_photo_\(contactID)_\(photoID).jpg")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            recordNewPhoto(url: url, contactID: contactID)
            Self.countCache.removeObject(forKey: contactID as NSString)
            return url
        } catch {
            return nil
        }
    }

    func deleteIntelPhoto(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        // Drop any caption metadata that referenced this URL.
        if let contactID = contactIDFromIntelURL(url) {
            var meta = loadMeta(contactID: contactID)
            meta.captions.removeValue(forKey: url.lastPathComponent)
            saveMeta(meta, contactID: contactID)
            Self.countCache.removeObject(forKey: contactID as NSString)
        }
    }

    // MARK: Counts

    /// Cached count — backed by an in-memory NSCache so that ArchiveView's
    /// per-row `RowCard.photoCount` doesn't enumerate the documents directory
    /// on every scroll. Invalidated by saveIntelPhoto / deleteIntelPhoto /
    /// deleteAllPhotos.
    func intelPhotoCount(contactID: String) -> Int {
        let key = contactID as NSString
        if let cached = Self.countCache.object(forKey: key) {
            return cached.intValue
        }
        let count = intelPhotoURLs(contactID: contactID).count
        Self.countCache.setObject(NSNumber(value: count), forKey: key)
        return count
    }

    func hasAnyPhotos(contactID: String) -> Bool {
        if loadProfilePhoto(contactID: contactID) != nil { return true }
        return intelPhotoCount(contactID: contactID) > 0
    }

    // MARK: Bulk cleanup (called when a contact is deleted from Archive)

    func deleteAllPhotos(contactID: String) {
        deleteProfilePhoto(contactID: contactID)
        for url in intelPhotoURLs(contactID: contactID) {
            try? FileManager.default.removeItem(at: url)
        }
        // Remove sidecar caption metadata.
        let metaURL = metaFileURL(contactID: contactID)
        try? FileManager.default.removeItem(at: metaURL)
        Self.countCache.removeObject(forKey: contactID as NSString)
    }

    // MARK: - Caption metadata
    // Sidecar JSON stores per-photo captions and the original add-date.
    // Keyed by file basename (e.g. intel_photo_<cid>_<uuid>.jpg) so the
    // metadata survives URL re-resolution.

    struct PhotoMeta: Codable {
        var caption: String = ""
        var addedAt: Date = Date()
    }

    private struct ContactPhotoMeta: Codable {
        var captions: [String: PhotoMeta] = [:]
    }

    func caption(for url: URL) -> String {
        guard let contactID = contactIDFromIntelURL(url) else { return "" }
        return loadMeta(contactID: contactID)
            .captions[url.lastPathComponent]?.caption ?? ""
    }

    func setCaption(_ caption: String, for url: URL) {
        guard let contactID = contactIDFromIntelURL(url) else { return }
        var meta = loadMeta(contactID: contactID)
        var entry = meta.captions[url.lastPathComponent] ?? PhotoMeta()
        entry.caption = caption
        meta.captions[url.lastPathComponent] = entry
        saveMeta(meta, contactID: contactID)
    }

    /// Returns the saved add-date if present; otherwise falls back to the
    /// file's creationDate so older photos still show a sensible stamp.
    func addedDate(for url: URL) -> Date {
        if let contactID = contactIDFromIntelURL(url),
           let stored = loadMeta(contactID: contactID).captions[url.lastPathComponent]?.addedAt {
            return stored
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.creationDate] as? Date) ?? Date()
    }

    // Called by `saveIntelPhoto` so newly-added photos have a stable add-date
    // even if iOS later changes the file's creationDate.
    private func recordNewPhoto(url: URL, contactID: String) {
        var meta = loadMeta(contactID: contactID)
        meta.captions[url.lastPathComponent] = PhotoMeta()
        saveMeta(meta, contactID: contactID)
    }

    private func loadMeta(contactID: String) -> ContactPhotoMeta {
        let url = metaFileURL(contactID: contactID)
        guard let data = try? Data(contentsOf: url),
              let meta = try? JSONDecoder().decode(ContactPhotoMeta.self, from: data)
        else { return ContactPhotoMeta() }
        return meta
    }

    private func saveMeta(_ meta: ContactPhotoMeta, contactID: String) {
        guard let data = try? JSONEncoder().encode(meta) else { return }
        try? data.write(to: metaFileURL(contactID: contactID),
                        options: [.atomic, .completeFileProtection])
    }

    private func metaFileURL(contactID: String) -> URL {
        documentsDirectory.appendingPathComponent("intel_meta_\(contactID).json")
    }

    private func contactIDFromIntelURL(_ url: URL) -> String? {
        // intel_photo_<contactID>_<uuid>.jpg
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("intel_photo_") else { return nil }
        let trimmed = String(name.dropFirst("intel_photo_".count))
        // contactID uses UUID strings (with dashes). Last underscore separates
        // contactID from the photo UUID — split on the LAST underscore.
        guard let lastUnderscore = trimmed.lastIndex(of: "_") else { return nil }
        return String(trimmed[..<lastUnderscore])
    }

    // MARK: - Helpers

    // Downscales the longest edge to `maxDimension` and returns JPEG data at 0.85 quality.
    // Keeps storage modest while preserving display quality. UIImage retains orientation.
    private func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
