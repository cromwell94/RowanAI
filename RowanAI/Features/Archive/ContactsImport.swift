import SwiftUI
import Contacts
import ContactsUI
import UIKit

// MARK: - Contacts Import Service
//
// Wraps CNContactStore and exposes the small slice of behavior the Archive
// import flow actually needs: permission state, async permission request,
// fetching the full contact list, and a single-contact refresh used by the
// "Sync" button on a Person's detail view.
//
// We never upload contacts anywhere — they're only read into memory to drive
// the picker UI and to seed Person fields the user explicitly imports.

@Observable
@MainActor
final class ContactsImportService {

    static let shared = ContactsImportService()

    private let store = CNContactStore()

    /// The keys we read for each contact. Kept tight so the fetch stays fast
    /// even on devices with thousands of contacts.
    ///
    /// `nonisolated(unsafe)` because the surrounding class is @MainActor but
    /// this constant is read from `Task.detached` blocks below — and Apple's
    /// CNKeyDescriptor type isn't formally Sendable, so plain `nonisolated`
    /// trips Swift 6 strict checks. The data is an immutable static let, so
    /// the unsafe escape is safe in practice.
    nonisolated(unsafe) private static let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey,
        CNContactGivenNameKey,
        CNContactFamilyNameKey,
        CNContactOrganizationNameKey,
        CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey,
        CNContactImageDataAvailableKey,
        CNContactImageDataKey,
        CNContactThumbnailImageDataKey
    ] as [CNKeyDescriptor]

    var authorization: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// `true` once iOS has handed back access — covers both the legacy
    /// .authorized state and iOS 18's .limited (which still permits reading
    /// the visible subset).
    var isGranted: Bool {
        switch authorization {
        case .authorized: return true
        case .limited:    return true
        default:          return false
        }
    }

    /// Returns the post-prompt status. Safe to call when access is already
    /// granted — iOS short-circuits and returns true.
    func requestAccess() async -> CNAuthorizationStatus {
        if isGranted { return authorization }
        // requestAccess returns Bool; the authorization status is the
        // canonical source of truth so we re-read it after the await.
        do {
            _ = try await store.requestAccess(for: .contacts)
        } catch {
            // Silent — the status read below reflects the real outcome.
        }
        return authorization
    }

    /// Fetch every contact the user has authorized us to see. Performed off
    /// the main actor because enumeration can take real time on large
    /// address books.
    nonisolated func fetchAllContacts() async throws -> [CNContact] {
        try await Task.detached(priority: .userInitiated) {
            let request = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
            request.sortOrder = .userDefault
            var collected: [CNContact] = []
            try CNContactStore().enumerateContacts(with: request) { contact, _ in
                collected.append(contact)
            }
            return collected
        }.value
    }

    /// Re-fetch a single contact by identifier — used by the Sync button to
    /// pick up any name/photo/phone/email changes the user made in the
    /// iOS Contacts app since the original import.
    nonisolated func fetchContact(identifier: String) async throws -> CNContact? {
        try await Task.detached(priority: .userInitiated) {
            let predicate = CNContact.predicateForContacts(withIdentifiers: [identifier])
            let results = try CNContactStore().unifiedContacts(
                matching: predicate,
                keysToFetch: Self.keysToFetch
            )
            return results.first
        }.value
    }
}

// MARK: - CNContact convenience

extension CNContact {
    var displayName: String {
        let full = [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !full.isEmpty { return full }
        let org = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return org.isEmpty ? "(No name)" : org
    }

    var primaryPhone: String {
        phoneNumbers.first?.value.stringValue ?? ""
    }

    var primaryEmail: String {
        guard let value = emailAddresses.first?.value else { return "" }
        return value as String
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    var fetchableImage: UIImage? {
        if let data = thumbnailImageData ?? imageData {
            return UIImage(data: data)
        }
        return nil
    }
}

// MARK: - Choice sheet — Import vs Manual
//
// Replaces the old "Add" button's direct push to the manual form. The user
// chooses how they want to create the contact; the sheet routes them
// accordingly. Manual flow stays identical to today.

struct AddContactChoiceSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var showImport = false
    @State private var showManual = false
    @State private var deniedAlert = false
    @State private var importService = ContactsImportService.shared

    /// Fired after a contact is created via either flow so the parent can
    /// e.g. navigate to the new Person's detail view.
    var onContactCreated: (Person) -> Void = { _ in }

    var body: some View {
        NavigationView {
            VStack(spacing: SP.xl) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.badge.plus.fill")
                        .font(.system(size: 36, design: .rounded))
                        .foregroundStyle(LinearGradient.accent)
                    Text("Add a Connection")
                        .font(RWF.title(22))
                        .foregroundColor(.rwTextPrimary)
                    Text("Import from your iPhone or add manually.")
                        .font(RWF.body())
                        .foregroundColor(.rwTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                VStack(spacing: 12) {
                    Button { startImport() } label: {
                        choiceCard(
                            icon: "person.crop.circle.fill.badge.checkmark",
                            title: "Import from Contacts",
                            subtitle: "Pull in name, phone, email, and photo from your iPhone Contacts.",
                            tint: .rwAccent
                        )
                    }
                    .buttonStyle(SBS())

                    Button {
                        dismiss()
                        // Slight delay so the next sheet can present cleanly.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showManual = true
                        }
                    } label: {
                        choiceCard(
                            icon: "square.and.pencil",
                            title: "Add Manually",
                            subtitle: "Type their info yourself.",
                            tint: .rwGold
                        )
                    }
                    .buttonStyle(SBS())
                }
                .padding(.horizontal, SP.lg)

                Spacer()
            }
            .rwBG()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
            }
            .sheet(isPresented: $showImport) {
                ContactImportPickerView { person in
                    showImport = false
                    dismiss()
                    onContactCreated(person)
                }
            }
            .sheet(isPresented: $showManual) {
                AddView()
            }
            .alert("Contacts access needed", isPresented: $deniedAlert) {
                Button("Open Settings") { openAppSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Rowan can only read your iPhone Contacts after you grant permission. You can change this anytime in Settings.")
            }
        }
    }

    private func choiceCard(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: RR.md))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                Text(subtitle).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.rwTextMuted)
        }
        .padding(SP.md)
        .frame(maxWidth: .infinity)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.xl))
        .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
    }

    private func startImport() {
        Task {
            let status = await importService.requestAccess()
            switch status {
            case .authorized, .limited:
                showImport = true
            case .denied, .restricted:
                deniedAlert = true
            case .notDetermined:
                // Shouldn't happen — requestAccess always resolves to one of
                // the above. Guard anyway.
                deniedAlert = true
            @unknown default:
                deniedAlert = true
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Picker — searchable list, single + bulk import

struct ContactImportPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var importService = ContactsImportService.shared

    @State private var contacts: [CNContact] = []
    @State private var search: String = ""
    @State private var loading = true
    @State private var loadError: String? = nil

    /// Identifiers of contacts the user has selected for bulk import.
    @State private var selected: Set<String> = []
    @State private var multiSelect = false
    @State private var importing = false
    @State private var successPerson: Person? = nil
    @State private var showSuccess = false

    /// Called when a single import or bulk import lands. Receives the first
    /// new Person so the caller can navigate to their detail view.
    var onImported: (Person) -> Void

    private var filtered: [CNContact] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return contacts }
        let q = search.lowercased()
        return contacts.filter { c in
            c.displayName.lowercased().contains(q) ||
            c.primaryPhone.lowercased().contains(q) ||
            c.primaryEmail.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.rwBackground.ignoresSafeArea()

                if loading {
                    loadingState
                } else if let err = loadError {
                    errorState(err)
                } else if contacts.isEmpty {
                    emptyState
                } else {
                    contentList
                }

                if showSuccess { successOverlay }
            }
            .navigationTitle(multiSelect ? "Select Contacts" : "Import from Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(multiSelect ? "Single" : "Multiple") {
                        withAnimation(.spring(response: 0.3)) {
                            multiSelect.toggle()
                            if !multiSelect { selected.removeAll() }
                        }
                    }
                    .font(RWF.cap())
                    .foregroundColor(.rwAccent)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().tint(.rwAccent).scaleEffect(1.1)
            Text("Reading your contacts…")
                .font(RWF.body())
                .foregroundColor(.rwTextSecondary)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, design: .rounded))
                .foregroundColor(.rwGold)
            Text("Couldn't read contacts").font(RWF.head(16)).foregroundColor(.rwTextPrimary)
            Text(message).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, SP.xl)
            Button {
                Task { await load() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(RWF.cap()).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(SBS())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32, design: .rounded))
                .foregroundColor(.rwTextMuted)
            Text("No contacts found")
                .font(RWF.head(16)).foregroundColor(.rwTextPrimary)
            Text("Your iPhone Contacts list looks empty.")
                .font(RWF.body(13)).foregroundColor(.rwTextSecondary)
        }
    }

    private var contentList: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.rwTextMuted)
                TextField("", text: $search,
                          prompt: Text("Search contacts").foregroundColor(.rwTextMuted))
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
            .padding(.horizontal, SP.lg).padding(.top, 12).padding(.bottom, 8)

            // List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filtered, id: \.identifier) { contact in
                        contactRow(contact)
                    }
                }
                .padding(.horizontal, SP.lg)
                .padding(.bottom, multiSelect ? 100 : 24)
            }

            if multiSelect {
                bulkImportBar
            }
        }
    }

    private func contactRow(_ c: CNContact) -> some View {
        Button {
            if multiSelect {
                if selected.contains(c.identifier) {
                    selected.remove(c.identifier)
                } else {
                    selected.insert(c.identifier)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                Task { await importSingle(c) }
            }
        } label: {
            HStack(spacing: 12) {
                contactAvatar(c)

                VStack(alignment: .leading, spacing: 3) {
                    Text(c.displayName)
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                        .lineLimit(1)
                    let subtitle = [c.primaryPhone, c.primaryEmail]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(RWF.cap(12))
                            .foregroundColor(.rwTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()

                if multiSelect {
                    Image(systemName: selected.contains(c.identifier)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.system(size: 22, design: .rounded))
                        .foregroundColor(selected.contains(c.identifier) ? .rwAccent : .rwTextMuted)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                }
            }
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(selected.contains(c.identifier) ? Color.rwAccent : Color.rwBorder,
                            lineWidth: selected.contains(c.identifier) ? 2 : 1)
            )
        }
        .buttonStyle(SBS())
    }

    private func contactAvatar(_ c: CNContact) -> some View {
        ZStack {
            if let img = c.fetchableImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.rwAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(c.initial)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.rwAccent)
            }
        }
    }

    private var bulkImportBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.rwBorder)
            HStack {
                Text("\(selected.count) selected")
                    .font(RWF.cap()).foregroundColor(.rwTextSecondary)
                Spacer()
                Button {
                    Task { await importSelected() }
                } label: {
                    HStack(spacing: 6) {
                        if importing { ProgressView().tint(.white) }
                        Text(importing
                             ? "Importing…"
                             : "Import \(selected.count) Contact\(selected.count == 1 ? "" : "s")")
                            .font(RWF.med(15))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(LinearGradient.accent)
                    .clipShape(Capsule())
                    .opacity(selected.isEmpty || importing ? 0.5 : 1)
                }
                .buttonStyle(SBS())
                .disabled(selected.isEmpty || importing)
            }
            .padding(.horizontal, SP.lg)
            .padding(.vertical, 12)
            .background(Color.rwSurface)
        }
    }

    private var successOverlay: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, design: .rounded))
                    .foregroundColor(.rwSuccess)
                Text(successPerson.map { "\($0.name) imported" } ?? "Imported")
                    .font(RWF.head(14)).foregroundColor(.rwTextPrimary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.rwCard)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 4)
            .padding(.top, 80)
            Spacer()
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Loading + Importing

    private func load() async {
        loading = true
        loadError = nil
        do {
            let fetched = try await importService.fetchAllContacts()
            // Hide entries with literally nothing useful — no name, no phone,
            // no email — they show up as garbage rows and confuse the picker.
            contacts = fetched.filter { c in
                let hasIdentity = !c.displayName.isEmpty && c.displayName != "(No name)"
                let hasContactInfo = !c.primaryPhone.isEmpty || !c.primaryEmail.isEmpty
                return hasIdentity || hasContactInfo
            }
            loading = false
        } catch {
            loading = false
            loadError = error.localizedDescription
        }
    }

    private func importSingle(_ c: CNContact) async {
        let person = Self.makePerson(from: c)
        ArchiveStore.shared.add(person)
        successPerson = person
        withAnimation(.spring(response: 0.4)) { showSuccess = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        try? await Task.sleep(nanoseconds: 600_000_000)
        onImported(person)
    }

    private func importSelected() async {
        guard !selected.isEmpty else { return }
        importing = true
        var first: Person? = nil
        for c in contacts where selected.contains(c.identifier) {
            let person = Self.makePerson(from: c)
            ArchiveStore.shared.add(person)
            if first == nil { first = person }
        }
        importing = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if let f = first {
            successPerson = f
            withAnimation(.spring(response: 0.4)) { showSuccess = true }
            try? await Task.sleep(nanoseconds: 600_000_000)
            onImported(f)
        }
    }

    /// Build a Person from a CNContact. Saves the avatar through
    /// ContactPhotoStore so the rest of the app sees it just like a manually
    /// captured profile photo.
    static func makePerson(from c: CNContact) -> Person {
        var p = Person()
        p.name = c.displayName
        p.phone = c.primaryPhone
        p.email = c.primaryEmail
        p.iosContactIdentifier = c.identifier
        p.firstContactDate = Date()
        if let img = c.fetchableImage {
            _ = ContactPhotoStore.shared.saveProfilePhoto(img, contactID: p.id)
        }
        return p
    }
}

// MARK: - Sync Service
//
// Powers the "Sync from Contacts" affordance on a Person's detail view: pulls
// the latest CNContact for the stored identifier and updates name/phone/email/
// photo on the existing Person without losing any Rowan-side data.

enum ContactSyncOutcome {
    case updated(Person)
    case noChange
    case notLinked
    case noLongerExists
    case denied
    case failed(String)

    var userMessage: String {
        switch self {
        case .updated:         return "Synced."
        case .noChange:        return "Already up to date."
        case .notLinked:       return "This contact wasn't imported from iPhone Contacts."
        case .noLongerExists:  return "We can't find this contact in your iPhone anymore."
        case .denied:          return "Contacts access is needed to sync."
        case .failed(let m):   return m
        }
    }
}

@MainActor
enum ContactSyncService {

    static func sync(_ p: Person) async -> ContactSyncOutcome {
        guard let identifier = p.iosContactIdentifier, !identifier.isEmpty else {
            return .notLinked
        }
        let status = await ContactsImportService.shared.requestAccess()
        let isAccessible: Bool
        if #available(iOS 18.0, *) {
            isAccessible = status == .authorized || status == .limited
        } else {
            isAccessible = status == .authorized
        }
        guard isAccessible else {
            return .denied
        }
        do {
            guard let c = try await ContactsImportService.shared.fetchContact(identifier: identifier) else {
                return .noLongerExists
            }

            var updated = p
            var changed = false

            let newName = c.displayName
            if !newName.isEmpty && newName != "(No name)" && newName != p.name {
                updated.name = newName
                changed = true
            }

            let newPhone = c.primaryPhone
            if !newPhone.isEmpty && newPhone != p.phone {
                updated.phone = newPhone
                changed = true
            }

            let newEmail = c.primaryEmail
            if !newEmail.isEmpty && newEmail != p.email {
                updated.email = newEmail
                changed = true
            }

            if let img = c.fetchableImage {
                // Always re-save the photo — the stored bytes might not match
                // what's currently in iOS Contacts even if we can't compare.
                _ = ContactPhotoStore.shared.saveProfilePhoto(img, contactID: p.id)
                changed = true
            }

            guard changed else { return .noChange }
            ArchiveStore.shared.update(updated)
            return .updated(updated)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
