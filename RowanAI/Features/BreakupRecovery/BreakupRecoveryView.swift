import SwiftUI

// MARK: - Breakup Recovery (Build 1 Step 10 stub)
// Activated when RWUser.isInBreakupRecovery is true. Full feature in Build 2:
// grief timeline, daily check-ins, readiness assessment, pattern analysis,
// gradual re-entry. This stub establishes the visual register and the
// gating path so the rest of the app can hide/show the right surfaces.

struct BreakupRecoveryView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                comingSoonCard
                stagesPreviewCard
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20)
        }
        .background(
            LinearGradient(colors: [Color(hex: "FFF7E8"), Color(hex: "FFFBF2")],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
        .navigationTitle("Healing")
        .navigationBarTitleDisplayMode(.large)
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: "C0A020").opacity(0.10)).frame(width: 110, height: 110)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(Color(hex: "C0A020"))
            }
            .padding(.top, 20)
            Text("Take your time.")
                .font(RWF.display(26)).foregroundColor(.rwTextPrimary)
            Text("This space is for healing — not for fixing or rushing. Cyrano is here to listen, not coach.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.xl)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comingSoonCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Coming in Build 2", systemImage: "clock.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Text("Daily Check-Ins")
                    .font(RWF.head()).foregroundColor(.rwTextPrimary)
                Text("One question a day. Thirty seconds. No advice — just acknowledgment.")
                    .font(RWF.body()).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stagesPreviewCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("The grief timeline", systemImage: "map.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                ForEach(["Shock", "Bargaining", "The Fog", "Anger", "The Hollow", "Gradual Return"], id: \.self) { stage in
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: "C0A020").opacity(0.4)).frame(width: 6, height: 6)
                        Text(stage).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                        Spacer()
                    }
                }
                Text("Not linear. Not a checklist. You'll move through these in your own order, and that's how it works.")
                    .font(RWF.cap(12)).foregroundColor(.rwTextMuted)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
