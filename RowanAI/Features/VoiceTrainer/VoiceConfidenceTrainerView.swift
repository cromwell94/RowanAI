import SwiftUI

// MARK: - Voice Confidence Trainer (Build 1 Step 11 stub)
// Three exercises ship in Build 3: Presence Check (filler/pace/inflection),
// Warmth Calibration (read-with-three-intentions), Silence Practice (5s hold).
// This stub gives the arc-menu a real destination today.

struct VoiceConfidenceTrainerView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                hero
                exerciseCard(
                    icon: "waveform",
                    title: "The Presence Check",
                    sub: "Speak for 30 seconds. Cyrano analyses fillers, pace, and upward inflection."
                )
                exerciseCard(
                    icon: "heart.text.square.fill",
                    title: "Warmth Calibration",
                    sub: "Read three sentences three ways: neutral, warm, deeply sincere. Hear the difference."
                )
                exerciseCard(
                    icon: "pause.circle.fill",
                    title: "Silence Practice",
                    sub: "Hold five seconds of silence after speaking. Track your personal best."
                )
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, SP.lg).padding(.top, 20)
        }
        .rwBG()
        .navigationTitle("Voice Trainer")
        .navigationBarTitleDisplayMode(.large)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.rwAccent.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.rwAccent)
            }
            .padding(.top, 12)
            Text("Voice Confidence")
                .font(RWF.display(26)).foregroundColor(.rwTextPrimary)
            Text("How you sound shapes how people receive you. Three short exercises, daily.")
                .font(RWF.body()).foregroundColor(.rwTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SP.xl)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func exerciseCard(icon: String, title: String, sub: String) -> some View {
        RWCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.rwAccent)
                    .frame(width: 52, height: 52)
                    .background(Color.rwAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.md))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        Text("BUILD 3").font(RWF.micro())
                            .foregroundColor(.rwTextMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.rwBorder.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    Text(sub).font(RWF.body(13)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
