import SwiftUI

// MARK: - Contact Avatar (Build 1 Step 8)
// Reusable circular avatar — renders the saved profile photo if one exists,
// otherwise falls back to the existing initial-on-tinted-circle look. Loads
// the image from disk lazily; pass `version` to force a refresh after a save.

struct ContactAvatar: View {
    let person: Person
    let size: CGFloat
    var showFavoriteBadge: Bool = false
    // Bumping `version` from a parent forces SwiftUI to recompute the body
    // and re-read the photo from disk after the user picks a new one.
    var version: Int = 0

    @State private var image: UIImage? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(person.source.color.opacity(0.25), lineWidth: 1))
            } else {
                Circle()
                    .fill(person.source.color.opacity(0.15))
                    .frame(width: size, height: size)
                Text(person.initial)
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundColor(person.source.color)
            }
            if showFavoriteBadge && person.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: max(10, size * 0.18)))
                    .foregroundColor(.rwAccent)
                    .padding(3)
                    .background(Circle().fill(Color.rwBackground))
                    .offset(x: size * 0.32, y: -size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .task(id: "\(person.id)-\(version)") {
            image = ContactPhotoStore.shared.loadProfilePhoto(contactID: person.id)
        }
    }
}
