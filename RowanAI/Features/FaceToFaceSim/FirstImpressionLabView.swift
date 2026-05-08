import SwiftUI

// MARK: - First Impression Lab (Build 1 Step 5h stub — full feature in Build 2)
// 30-second timer mode. 5 cold-open rounds. Avatar starts neutral; user must
// establish warmth + a thread within 30s. Engagement meter starts at 50.
// Cyrano scores opening energy / thread quality / authenticity / interest direction.

struct FirstImpressionLabView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                howItWorksCard
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20)
        }
        .rwBG()
        .navigationTitle("First Impression Lab")
        .navigationBarTitleDisplayMode(.large)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.rwAccent.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "timer")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.rwAccent)
            }
            .padding(.top, 12)
            HStack(spacing: 6) {
                Text("First Impression Lab")
                    .font(RWF.display(24)).foregroundColor(.rwTextPrimary)
                Text("BUILD 2").font(RWF.micro())
                    .foregroundColor(.rwTextMuted)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.rwBorder.opacity(0.5))
                    .clipShape(Capsule())
            }
            Text("Five 30-second cold opens. Real pressure, real feedback.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.xl)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var howItWorksCard: some View {
        RWCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("How it works", systemImage: "list.bullet.rectangle.fill")
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                bullet("30-second timer per round — visible, prominent")
                bullet("Avatar starts neutral. You establish warmth + a thread.")
                bullet("Engagement meter starts at 50. Goal: 65+ before time's up.")
                bullet("5 rounds, different avatar/environment/mood each time.")
                bullet("Score: opening energy · thread quality · authenticity · interest direction")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Color.rwAccent.opacity(0.4)).frame(width: 5, height: 5).padding(.top, 7)
            Text(text).font(RWF.body(14)).foregroundColor(.rwTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
