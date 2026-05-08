import SwiftUI
import PhotosUI

struct ProfilePhotoTab: View {
    @State private var store = ProfileCoachStore.shared
    @State private var picks: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var showPaywall = false
    @State private var copiedOrder = false
    @State private var draggingID: UUID? = nil
    @State private var storeManager = StoreManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: SP.lg) {

                hero

                if !storeManager.isPro {
                    quotaBar
                }

                pickerButton

                if !store.uploadedPhotos.isEmpty {
                    photoStrip
                }

                if store.uploadedPhotos.contains(where: { $0.analyzed }) {
                    analyzedSection
                    recommendedOrderSection
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 12)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .profilePhotoLimit)
        }
        .onChange(of: picks) { _, newPicks in
            Task { await loadSelected(newPicks) }
        }
    }

    // MARK: pieces

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PHOTO ANALYZER").font(RWF.micro())
                .foregroundStyle(LinearGradient.accent)
                .tracking(1.6)
            Text("Pick up to 6 photos.")
                .font(RWF.title(22))
                .foregroundColor(.rwTextPrimary)
            Text("Cyrano scores each one for dating-app performance and tells you which to lead with.")
                .font(RWF.body(14))
                .foregroundColor(.rwTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quotaBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(LinearGradient.accent)
            Text("\(storeManager.profilePhotosRemainingThisWeek()) free \(storeManager.profilePhotosRemainingThisWeek() == 1 ? "analysis" : "analyses") left this week")
                .font(RWF.cap(12))
                .foregroundColor(.rwTextSecondary)
            Spacer()
            Button { showPaywall = true } label: {
                Text("Go Pro").font(RWF.cap(12))
                    .foregroundStyle(LinearGradient.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.rwSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.rwBorder, lineWidth: 1))
    }

    private var pickerButton: some View {
        PhotosPicker(
            selection: $picks,
            maxSelectionCount: 6,
            matching: .images,
            photoLibrary: .shared()
        ) {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(store.uploadedPhotos.isEmpty ? "Add photos" : "Replace photos")
                    .font(RWF.med(15))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient.accent)
            .clipShape(Capsule())
            .shadow(color: Color.rwAccent.opacity(0.30), radius: 12, x: 0, y: 4)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.uploadedPhotos) { photo in
                    photoCard(photo)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func photoCard(_ photo: PhotoAnalysis) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                if let img = photo.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.uploadedPhotos.removeAll { $0.id == photo.id }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(8)

                if photo.analyzed {
                    HStack(spacing: 4) {
                        Text("\(photo.score)")
                            .font(RWF.head(13))
                        Text("/10")
                            .font(RWF.cap(10))
                            .opacity(0.85)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(photo.scoreColor)
                    .clipShape(Capsule())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if photo.analyzing {
                HStack(spacing: 6) {
                    ProgressView().tint(.rwAccent).scaleEffect(0.7)
                    Text("Analyzing…").font(RWF.cap(11))
                        .foregroundColor(.rwTextMuted)
                }
            } else if photo.analyzed {
                recommendationPill(photo.recommendation)
            } else if photo.failed {
                Button { Task { await analyzeOne(photo.id) } } label: {
                    Label("Retry", systemImage: "arrow.clockwise").font(RWF.cap(11))
                        .foregroundColor(.rwAccent)
                }
            } else {
                Button {
                    Task { await analyzeOne(photo.id) }
                } label: {
                    Label("Analyze", systemImage: "sparkles")
                        .font(RWF.cap(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(LinearGradient.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(SBS())
            }
        }
        .frame(width: 160)
    }

    private func recommendationPill(_ rec: PhotoAnalysis.Recommendation) -> some View {
        let tint: Color = {
            switch rec {
            case .lead: return .rwSuccess
            case .secondary: return .rwViolet
            case .cut: return .rwDanger
            }
        }()

        return HStack(spacing: 4) {
            Image(systemName: rec.icon).font(.system(size: 10, weight: .semibold))
            Text(rec.rawValue).font(RWF.cap(11))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(tint.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.3), lineWidth: 1))
    }

    private var analyzedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RWSectionLabel("CYRANO'S READ")
                .padding(.top, SP.md)

            ForEach(store.uploadedPhotos) { photo in
                if photo.analyzed {
                    photoFeedbackCard(photo)
                }
            }
        }
    }

    private func photoFeedbackCard(_ photo: PhotoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let img = photo.image {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: RR.md))
                        .overlay(RoundedRectangle(cornerRadius: RR.md).stroke(Color.rwBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text("\(photo.score)").font(RWF.head(14))
                            Text("/10").font(RWF.cap(10)).opacity(0.85)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(photo.scoreColor)
                        .clipShape(Capsule())

                        recommendationPill(photo.recommendation)
                    }
                    Text(photo.reason)
                        .font(RWF.body(12))
                        .foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            if !photo.positives.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(photo.positives, id: \.self) { p in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.rwSuccess)
                                .padding(.top, 1)
                            Text(p)
                                .font(RWF.body(13))
                                .foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !photo.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(photo.improvements, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.rwWarning)
                                .padding(.top, 1)
                            Text(i)
                                .font(RWF.body(13))
                                .foregroundColor(.rwTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(SP.md)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }

    private var recommendedOrderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RWSectionLabel("RECOMMENDED ORDER")
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let lines = store.orderedPhotos.enumerated().map { idx, p in
                        "\(idx + 1). \(p.recommendation.rawValue) (Score \(p.score)/10) — \(p.reason)"
                    }.joined(separator: "\n")
                    UIPasteboard.general.string = lines
                    copiedOrder = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copiedOrder = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedOrder ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(copiedOrder ? "Copied" : "Copy Order to Notes")
                            .font(RWF.cap(11))
                    }
                    .foregroundColor(copiedOrder ? .white : .rwAccent)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(copiedOrder ? Color.rwSuccess : Color.rwAccent.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(SBS())
            }
            .padding(.top, SP.md)

            VStack(spacing: 8) {
                ForEach(store.orderedPhotos) { photo in
                    orderRow(photo)
                }
            }
        }
    }

    private func orderRow(_ photo: PhotoAnalysis) -> some View {
        let isCut = photo.recommendation == .cut
        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rwTextMuted)

            if let img = photo.image {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Text("\(photo.score)").font(RWF.head(13))
                        Text("/10").font(RWF.cap(10)).opacity(0.85)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(photo.scoreColor)
                    .clipShape(Capsule())
                    recommendationPill(photo.recommendation)
                }
                Text(photo.reason).font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(SP.sm)
        .background(Color.rwCard)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        .opacity(isCut ? 0.5 : 1.0)
        .onDrag {
            draggingID = photo.id
            return NSItemProvider(object: photo.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: PhotoDropDelegate(
            target: photo.id,
            store: store,
            draggingID: $draggingID
        ))
    }

    // MARK: actions

    @MainActor
    private func loadSelected(_ items: [PhotosPickerItem]) async {
        loading = true
        defer { loading = false }
        var loaded: [PhotoAnalysis] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let analysis = PhotoAnalysis.from(image) {
                loaded.append(analysis)
            }
        }
        store.uploadedPhotos = loaded
    }

    private func analyzeOne(_ id: UUID) async {
        guard let idx = store.uploadedPhotos.firstIndex(where: { $0.id == id }) else { return }
        guard let image = store.uploadedPhotos[idx].image else { return }

        if !storeManager.canUseProfilePhoto() {
            showPaywall = true
            return
        }

        store.uploadedPhotos[idx].analyzing = true
        store.uploadedPhotos[idx].failed = false

        do {
            let result = try await Claude.shared.analyzeProfilePhoto(image)
            if let i = store.uploadedPhotos.firstIndex(where: { $0.id == id }) {
                store.uploadedPhotos[i].analyzing = false
                store.uploadedPhotos[i].analyzed = true
                store.uploadedPhotos[i].score = result.score
                store.uploadedPhotos[i].positives = result.positives
                store.uploadedPhotos[i].improvements = result.improvements
                store.uploadedPhotos[i].recommendation = PhotoAnalysis.Recommendation(rawValue: result.recommendation) ?? .secondary
                store.uploadedPhotos[i].reason = result.reason
            }
            storeManager.trackProfilePhotoUsed()
        } catch {
            if let i = store.uploadedPhotos.firstIndex(where: { $0.id == id }) {
                store.uploadedPhotos[i].analyzing = false
                store.uploadedPhotos[i].failed = true
            }
        }
    }
}

// MARK: - Drop delegate (drag-to-reorder photos)

private struct PhotoDropDelegate: DropDelegate {
    let target: UUID
    let store: ProfileCoachStore
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingID,
              dragged != target,
              let from = store.uploadedPhotos.firstIndex(where: { $0.id == dragged }),
              let to   = store.uploadedPhotos.firstIndex(where: { $0.id == target })
        else { return }
        if store.uploadedPhotos[from].id != store.uploadedPhotos[to].id {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                store.uploadedPhotos.move(
                    fromOffsets: IndexSet(integer: from),
                    toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
