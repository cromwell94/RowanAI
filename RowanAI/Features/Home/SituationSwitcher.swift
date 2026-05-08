import SwiftUI

// MARK: - Situation Switcher (Build 1 — Home Feature 3)
// Bottom sheet for changing the user's relationshipStatus on the home screen.
// Multi-step flow: pick status → (if switching to relationship) collect partner
// name + duration → (if switching away from relationship) confirm. Updates
// RWUser via AuthService and toggles AppState mode in real time.

struct SituationSwitcherSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @State private var auth = AuthService.shared

    @State private var step: Step = .pick
    @State private var pickedStatus: RelationshipStatus
    @State private var partnerName: String = ""
    @State private var duration: RelationshipDuration? = nil
    @FocusState private var nameFocused: Bool

    private var currentStatus: RelationshipStatus {
        auth.currentUser?.relationshipStatus ?? .single
    }

    init() {
        _pickedStatus = State(initialValue: AuthService.shared.currentUser?.relationshipStatus ?? .single)
    }

    enum Step { case pick, partner, duration, confirmLeave }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SP.lg) {
                handle
                switch step {
                case .pick:         pickStep
                case .partner:      partnerStep
                case .duration:     durationStep
                case .confirmLeave: confirmLeaveStep
                }
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, SP.lg)
        }
        .background(Color.rwBackground.ignoresSafeArea())
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.rwBorder)
            .frame(width: 40, height: 5)
            .padding(.top, 8)
    }

    // MARK: - Step 1: Pick

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: SP.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Where are you right now?")
                    .font(RWF.title(24)).foregroundColor(.rwTextPrimary)
                Text("Life changes — Rowan adapts. You can switch back anytime.")
                    .font(RWF.body(15)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 10) {
                ForEach(RelationshipStatus.allCases) { status in
                    statusCard(status)
                }
            }
            RWButton(continueLabel, icon: "arrow.right") { advance() }
                .padding(.top, 4)
            Button("Cancel") { dismiss() }
                .font(RWF.cap()).foregroundColor(.rwTextMuted)
                .frame(maxWidth: .infinity)
        }
    }

    private var continueLabel: String {
        if pickedStatus == currentStatus { return "Keep current" }
        return "Continue"
    }

    private func statusCard(_ status: RelationshipStatus) -> some View {
        let selected = pickedStatus == status
        return Button {
            pickedStatus = status
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selected ? status.color : status.color.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selected ? .white : status.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(status.displayLabel)
                            .font(RWF.head(15)).foregroundColor(.rwTextPrimary)
                        if status == currentStatus {
                            Text("CURRENT").font(RWF.micro())
                                .foregroundColor(.rwTextMuted)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.rwBorder.opacity(0.6))
                                .clipShape(Capsule())
                        }
                    }
                    Text(status.subLabel)
                        .font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(status.color).font(.system(size: 20))
                }
            }
            .padding(SP.md)
            .background(selected ? status.color.opacity(0.06) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl)
                .stroke(selected ? status.color.opacity(0.4) : Color.rwBorder,
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(SBS())
    }

    // MARK: - Step 2: Partner Name

    private var partnerStep: some View {
        VStack(alignment: .leading, spacing: SP.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What's your partner's first name?")
                    .font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("We'll use this to personalise relationship coaching.")
                    .font(RWF.body(14)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField("", text: $partnerName,
                      prompt: Text("First name").foregroundColor(.rwTextMuted))
                .focused($nameFocused)
                .font(RWF.head(18)).foregroundColor(.rwTextPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(SP.md)
                .background(Color.rwCard)
                .clipShape(RoundedRectangle(cornerRadius: RR.lg))
                .overlay(RoundedRectangle(cornerRadius: RR.lg)
                    .stroke(nameFocused ? Color.rwGold.opacity(0.5) : Color.rwBorder, lineWidth: 1))
            HStack(spacing: 10) {
                Button("Back") { withAnimation { step = .pick } }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Spacer()
            }
            RWButton("Continue", icon: "arrow.right") {
                withAnimation { step = .duration }
            }
            .disabled(partnerName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(partnerName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .onAppear {
            // Pre-fill from existing user data so a re-entry feels seamless.
            if partnerName.isEmpty, let existing = auth.currentUser?.partnerName {
                partnerName = existing
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { nameFocused = true }
        }
    }

    // MARK: - Step 3: Duration

    private var durationStep: some View {
        VStack(alignment: .leading, spacing: SP.lg) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How long together?")
                    .font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                Text("Helps Cyrano calibrate the rituals and tools we surface.")
                    .font(RWF.body(14)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 8) {
                ForEach(RelationshipDuration.allCases) { d in
                    durationRow(d)
                }
            }
            HStack(spacing: 10) {
                Button("Back") { withAnimation { step = .partner } }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Spacer()
            }
            RWButton("Save", icon: "checkmark") { commit() }
                .disabled(duration == nil)
                .opacity(duration == nil ? 0.5 : 1)
        }
        .onAppear {
            if duration == nil { duration = auth.currentUser?.relationshipDuration }
        }
    }

    private func durationRow(_ d: RelationshipDuration) -> some View {
        let selected = duration == d
        return Button {
            duration = d
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selected ? .white : .rwGold)
                    .frame(width: 36, height: 36)
                    .background(selected ? Color.rwGold : Color.rwGold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RR.sm))
                Text(d.rawValue)
                    .font(RWF.body(15)).foregroundColor(.rwTextPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.rwGold).font(.system(size: 18))
                }
            }
            .padding(SP.md)
            .background(selected ? Color.rwGold.opacity(0.08) : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg)
                .stroke(selected ? Color.rwGold.opacity(0.4) : Color.rwBorder,
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(SBS())
    }

    // MARK: - Step 4: Confirm Leave Relationship

    private var confirmLeaveStep: some View {
        VStack(alignment: .leading, spacing: SP.lg) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(LinearGradient.amber)
                    .padding(.bottom, 6)
                Text("Switching to \(pickedStatus.displayLabel.lowercased())")
                    .font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your Relationship data is saved. The Relationship tab will hide for now — switch back anytime and everything is right where you left it.")
                    .font(RWF.body(15)).foregroundColor(.rwTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button("Back") { withAnimation { step = .pick } }
                    .font(RWF.cap()).foregroundColor(.rwTextMuted)
                Spacer()
            }
            RWButton("Confirm switch", icon: "checkmark") { commit() }
        }
    }

    // MARK: - Flow control

    private func advance() {
        // No change — close.
        if pickedStatus == currentStatus {
            dismiss(); return
        }
        // Switching INTO relationship: collect partner details.
        if pickedStatus == .relationship && currentStatus != .relationship {
            withAnimation { step = .partner }
            return
        }
        // Switching FROM relationship: confirm.
        if pickedStatus != .relationship && currentStatus == .relationship {
            withAnimation { step = .confirmLeave }
            return
        }
        // Single ↔ complicated — no extra step.
        commit()
    }

    private func commit() {
        let trimmed = partnerName.trimmingCharacters(in: .whitespaces)
        let switchedToRelationship = (pickedStatus == .relationship && currentStatus != .relationship)
        let switchedAway          = (pickedStatus != .relationship && currentStatus == .relationship)

        AuthService.shared.update { u in
            u.relationshipStatus = pickedStatus
            if switchedToRelationship {
                if !trimmed.isEmpty { u.partnerName = trimmed }
                if let dur = duration { u.relationshipDuration = dur }
            }
        }

        // Mode switch — drives accent color + arc menu visibility.
        if pickedStatus == .relationship {
            app.switchToKeepMode()
            // Seed RelationshipStore if it's empty so the Relationship tab
            // opens straight to the Setup screen with the right starting data.
            if RelationshipStore.shared.relationship == nil, !trimmed.isEmpty {
                RelationshipStore.shared.startRelationship(
                    partnerName: trimmed,
                    personId: nil,
                    startDate: estimatedStartDate(from: duration)
                )
            }
        } else {
            app.switchToHuntMode()
            // Switching away — leave RelationshipStore.relationship intact
            // so the user can swap back without losing rituals/data.
            _ = switchedAway // silenced: we're choosing not to act on it
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func estimatedStartDate(from duration: RelationshipDuration?) -> Date {
        let cal = Calendar.current
        let now = Date()
        let days: Int
        switch duration {
        case .lessThanSixMonths: days = 90
        case .sixToTwelveMonths: days = 270
        case .oneToTwoYears:     days = 547   // ~1.5 years
        case .threeToFiveYears:  days = 1460  // ~4 years
        case .fivePlusYears:     days = 2190  // ~6 years
        case .none:              days = 90
        }
        return cal.date(byAdding: .day, value: -days, to: now) ?? now
    }
}

// MARK: - Situation Pill (used inline on Home)

struct SituationPill: View {
    let onTap: () -> Void
    @State private var auth = AuthService.shared

    private var status: RelationshipStatus {
        auth.currentUser?.relationshipStatus ?? .single
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(status.color.opacity(0.14)).frame(width: 32, height: 32)
                    Image(systemName: status.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(status.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("MY SITUATION")
                        .font(RWF.micro())
                        .foregroundColor(.rwTextMuted)
                        .tracking(1.4)
                    Text(status.displayLabel)
                        .font(RWF.head(15))
                        .foregroundColor(.rwTextPrimary)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.rwTextMuted)
                    .frame(width: 28, height: 28)
                    .background(Color.rwSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: Color.rwShadow, radius: 12, x: 0, y: 3)
        }
        .buttonStyle(SBS())
    }
}
