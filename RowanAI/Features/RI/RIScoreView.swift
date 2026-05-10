import SwiftUI
import Charts

// MARK: - RI Score View — full implementation
//
// Replaces the Build 1 stub. Reads RIScoreStore which now records events +
// 30-day history. Animated count-up on appear, dimension grid with expand,
// 30-day chart via Swift Charts, activity feed, level badges, improvement
// tips for the lowest dimensions, share image, and milestone celebration
// when a level threshold is crossed.

struct RIScoreView: View {
    @State private var store = RIScoreStore.shared
    @State private var animatedTotal: Int = 0
    @State private var expandedDimension: RIDimension? = nil
    @State private var celebrationLevel: RILevel? = nil
    @State private var showShareCard = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                header
                dimensionGrid
                chartSection
                howToImprove
                activityFeed
                levelBadges
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg)
            .padding(.top, 12)
        }
        .rwBG()
        .navigationTitle("RI Score")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showShareCard = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwAccent)
                }
            }
        }
        .onAppear {
            animateCountUp()
            celebrationLevel = store.consumePendingLevelUp()
        }
        .fullScreenCover(item: Binding(
            get: { celebrationLevel.map { CelebrationLevelBox(level: $0) } },
            set: { celebrationLevel = $0?.level }
        )) { box in
            MilestoneCelebrationView(level: box.level) {
                celebrationLevel = nil
            }
        }
        .sheet(isPresented: $showShareCard) {
            RIScoreShareSheet(score: store.score)
        }
    }

    // MARK: - Header

    private var header: some View {
        let level = store.score.level
        let pointsToNext = store.score.pointsToNextLevel
        let nextLevel = store.score.nextLevel

        return VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.rwBorder, lineWidth: 10)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: progressInLevel(level: level))
                    .stroke(LinearGradient(colors: [level.color, level.color.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .animation(.spring(response: 1.2, dampingFraction: 0.85), value: store.score.total)

                VStack(spacing: 2) {
                    Text("\(animatedTotal)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.rwTextPrimary)
                        .contentTransition(.numericText())
                    Text(level.rawValue.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(level.color)
                        .tracking(1.4)
                }
            }
            .padding(.top, 6)

            Text("Relational Intelligence")
                .font(RWF.cap()).foregroundColor(.rwTextSecondary)

            if let toNext = pointsToNext, let next = nextLevel {
                Text("\(toNext) point\(toNext == 1 ? "" : "s") from \(next.rawValue)")
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextMuted)
            } else {
                Text("Master tier — keep going")
                    .font(RWF.body(13))
                    .foregroundColor(.rwAccent)
            }
        }
        .padding(.vertical, SP.md)
    }

    /// 0…1 progress from the current level's threshold to the next, used for
    /// the ring fill — a full ring at the start of each level would be a lie.
    private func progressInLevel(level: RILevel) -> CGFloat {
        let lower = CGFloat(level.threshold)
        let upper: CGFloat = level == .master ? 1000 : CGFloat(level.threshold + 200)
        let span = max(upper - lower, 1)
        let v = CGFloat(store.score.total) - lower
        return min(max(v / span, 0), 1)
    }

    private func animateCountUp() {
        animatedTotal = 0
        let target = store.score.total
        guard target > 0 else { return }
        let steps = 32
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.035) {
                animatedTotal = target * step / steps
            }
        }
    }

    // MARK: - Dimension Grid

    private var dimensionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            ForEach(RIDimension.allCases) { dim in
                DimensionCard(
                    dimension: dim,
                    value: store.score.value(for: dim),
                    trend: store.trend(for: dim),
                    isExpanded: expandedDimension == dim,
                    recentEvents: store.events.filter { $0.dimension == dim }.prefix(3).map { $0 }
                ) {
                    withAnimation(.spring(response: 0.35)) {
                        expandedDimension = (expandedDimension == dim) ? nil : dim
                    }
                }
            }
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        let series = store.last30Days()
        return RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Last 30 Days", systemImage: "chart.line.uptrend.xyaxis")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)

                if series.allSatisfy({ $0.total == series.first?.total }) {
                    Text("Your score line goes here once you start logging activity. Try a Sim session or complete today's ritual.")
                        .font(RWF.body(13))
                        .foregroundColor(.rwTextSecondary)
                        .padding(.vertical, 6)
                } else {
                    Chart(series) { snap in
                        LineMark(
                            x: .value("Day", snap.date),
                            y: .value("Score", snap.total)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(LinearGradient.accent)

                        AreaMark(
                            x: .value("Day", snap.date),
                            y: .value("Score", snap.total)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(
                            colors: [Color.rwAccent.opacity(0.20), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
                    .frame(height: 130)
                    .chartYScale(domain: chartYDomain(series: series))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(RWF.cap(10))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisValueLabel().font(RWF.cap(10))
                        }
                    }
                }
            }
        }
    }

    private func chartYDomain(series: [RIScoreSnapshot]) -> ClosedRange<Int> {
        guard let lo = series.map(\.total).min(),
              let hi = series.map(\.total).max() else { return 0...1000 }
        return max(0, lo - 30)...min(1000, hi + 30)
    }

    // MARK: - How to improve

    private var howToImprove: some View {
        let lowest = lowestDimensions(count: 3)
        return RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("How to Improve", systemImage: "sparkles")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                ForEach(lowest, id: \.self) { dim in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: dim.icon)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(dim.color)
                            .frame(width: 24, height: 24)
                            .background(dim.color.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(dim.rawValue) is at \(store.score.value(for: dim))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.rwTextSecondary)
                            Text(dim.improvementTip)
                                .font(RWF.body(13))
                                .foregroundColor(.rwTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func lowestDimensions(count: Int) -> [RIDimension] {
        RIDimension.allCases
            .sorted { store.score.value(for: $0) < store.score.value(for: $1) }
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Activity feed

    private var activityFeed: some View {
        let recent = Array(store.events.prefix(10))
        return RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("What's feeding your score", systemImage: "list.bullet")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)

                if recent.isEmpty {
                    Text("Activity shows up here as you use Rowan. Run a Sim session, complete today's ritual, or finish a debrief to see your first event.")
                        .font(RWF.body(13))
                        .foregroundColor(.rwTextSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(recent) { event in
                        ActivityRow(event: event)
                    }
                }
            }
        }
    }

    // MARK: - Level Badges

    private var levelBadges: some View {
        let current = store.score.level
        return RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Levels", systemImage: "trophy.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)

                LazyVGrid(columns: [GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())], spacing: 8) {
                    ForEach(RILevel.allCases, id: \.rawValue) { level in
                        LevelBadge(level: level,
                                   isCurrent: level == current,
                                   isAchieved: store.score.total >= level.threshold)
                    }
                }
            }
        }
    }
}

// MARK: - Dimension Card

private struct DimensionCard: View {
    let dimension: RIDimension
    let value: Int
    let trend: RIScoreStore.Trend
    let isExpanded: Bool
    let recentEvents: [RIScoreEvent]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: dimension.icon)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(dimension.color)
                    Text(dimension.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                    Spacer()
                    trendArrow
                }

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(value)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.rwTextPrimary)
                    Text("/200")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.rwTextMuted)
                }

                progressBar

                if isExpanded {
                    Divider().background(Color.rwBorder)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fed by")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.rwTextMuted)
                            .tracking(0.5)
                        ForEach(dimension.feeders, id: \.self) { feeder in
                            HStack(alignment: .top, spacing: 6) {
                                Circle().fill(dimension.color).frame(width: 4, height: 4).padding(.top, 6)
                                Text(feeder)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.rwTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !recentEvents.isEmpty {
                            Text("Recent")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.rwTextMuted)
                                .tracking(0.5)
                                .padding(.top, 4)
                            ForEach(recentEvents) { event in
                                Text("+\(event.points) · \(event.reason)")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.rwTextMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(SP.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(
                isExpanded ? dimension.color.opacity(0.45) : Color.rwBorder,
                lineWidth: isExpanded ? 1.5 : 1
            ))
        }
        .buttonStyle(SBS())
    }

    private var trendArrow: some View {
        Group {
            switch trend {
            case .up:
                Image(systemName: "arrow.up").foregroundColor(.rwSuccess)
            case .down:
                Image(systemName: "arrow.down").foregroundColor(.rwDanger)
            case .steady:
                Image(systemName: "arrow.right").foregroundColor(.rwTextMuted)
            }
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(dimension.color.opacity(0.15))
                    .frame(height: 5)
                RoundedRectangle(cornerRadius: 3)
                    .fill(dimension.color)
                    .frame(width: geo.size.width * (CGFloat(value) / 200.0), height: 5)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let event: RIScoreEvent

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.points >= 0 ? "+\(event.points)" : "\(event.points)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(event.dimension.color)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(event.reason)
                    .font(RWF.body(13))
                    .foregroundColor(.rwTextPrimary)
                Text("\(event.dimension.rawValue) · \(Self.formatter.localizedString(for: event.timestamp, relativeTo: Date()))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.rwTextMuted)
            }
            Spacer()
        }
    }
}

// MARK: - Level Badge

private struct LevelBadge: View {
    let level: RILevel
    let isCurrent: Bool
    let isAchieved: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(isAchieved ? level.color.opacity(0.20) : Color.rwBorder.opacity(0.3))
                    .frame(width: isCurrent ? 50 : 38, height: isCurrent ? 50 : 38)
                if isCurrent {
                    Circle()
                        .stroke(level.color, lineWidth: 2)
                        .frame(width: 56, height: 56)
                }
                Image(systemName: isAchieved ? "checkmark" : "lock.fill")
                    .font(.system(size: isCurrent ? 18 : 13, weight: .bold, design: .rounded))
                    .foregroundColor(isAchieved ? level.color : .rwTextMuted)
            }
            Text(level.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(isAchieved ? .rwTextPrimary : .rwTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - Milestone Celebration

private struct CelebrationLevelBox: Identifiable, Equatable {
    let level: RILevel
    var id: String { level.rawValue }
}

private struct MilestoneCelebrationView: View {
    let level: RILevel
    let onDismiss: () -> Void

    @State private var bounced = false

    var body: some View {
        ZStack {
            ConfettiBackdrop(accent: level.color)

            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(level.color.opacity(0.20))
                        .frame(width: 160, height: 160)
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 88, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [level.color, level.color.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .scaleEffect(bounced ? 1 : 0.6)
                        .opacity(bounced ? 1 : 0)
                }

                VStack(spacing: 10) {
                    Text("You've reached")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Text(level.rawValue)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(level.blurb)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SP.xl)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(bounced ? 1 : 0)
                .offset(y: bounced ? 0 : 12)

                Spacer()

                Button(action: onDismiss) {
                    Text("Keep Going")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(SBS())
                .padding(.horizontal, SP.xl)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                bounced = true
            }
        }
    }
}

private struct ConfettiBackdrop: View {
    let accent: Color
    var body: some View {
        ZStack {
            Color(hex: "06000F").ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.35), .clear],
                           center: .top, startRadius: 0, endRadius: 600)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Share Sheet

private struct RIScoreShareSheet: View {
    let score: RIScore
    @Environment(\.dismiss) var dismiss
    @State private var renderedImage: UIImage? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: SP.lg) {
                ShareCardView(score: score)
                    .padding(.horizontal, SP.lg)
                    .padding(.top, 12)

                if let image = renderedImage {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(
                        "My RI Score",
                        image: Image(uiImage: image)
                    )) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(RWF.med(15))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient.accent)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, SP.lg)
                } else {
                    ProgressView().tint(.rwAccent)
                }

                Spacer()
            }
            .rwBG()
            .navigationTitle("Share Your Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.rwAccent)
                }
            }
            .onAppear {
                let renderer = ImageRenderer(content:
                    ShareCardView(score: score)
                        .frame(width: 360, height: 580)
                        .background(Color(hex: "06000F"))
                )
                renderer.scale = UIScreen.main.scale
                renderedImage = renderer.uiImage
            }
        }
    }
}

private struct ShareCardView: View {
    let score: RIScore

    private var topTwo: [RIDimension] {
        RIDimension.allCases
            .sorted { score.value(for: $0) > score.value(for: $1) }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [.rwAccent, Color.rwGold],
                        startPoint: .leading, endPoint: .trailing
                    ))
                Text("rowan")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)

            VStack(spacing: 6) {
                Text("My Relational Intelligence Score")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text("\(score.total)")
                    .font(.system(size: 78, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(score.level.rawValue.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(score.level.color)
                    .tracking(2)
            }

            VStack(spacing: 8) {
                ForEach(topTwo, id: \.self) { dim in
                    HStack {
                        Image(systemName: dim.icon)
                            .foregroundColor(dim.color)
                        Text(dim.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(score.value(for: dim))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 22)

            Spacer()

            Text("@RowanAI.app")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(hex: "06000F")
                RadialGradient(colors: [score.level.color.opacity(0.35), .clear],
                               center: .top, startRadius: 0, endRadius: 400)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
