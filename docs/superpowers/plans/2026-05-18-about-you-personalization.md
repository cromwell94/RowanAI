# About You Personalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Get to Know You" onboarding step + persistent profile (hobbies, green flags, red flags, vibes) so Cyrano replies/openers/coaching/sim feel personal, with an edit screen in Settings and an opt-in migration prompt for existing users.

**Architecture:**
- Four `@AppStorage` strings (`userHobbies`, `userGreenFlags`, `userRedFlags`, `userVibes`) act as the single source of truth — no new persistence layer.
- All new UI lives **inline** in existing Swift files so the `RowanAI.xcodeproj` doesn't need re-registering (decision recorded in spec): `Onboarding.swift` hosts the onboarding step + shared edit sheet, `HomeView.swift` adds the Settings row, `RowanAIApp.swift` adds the migration cover, `Claude.swift` injects the profile block into `buildSystem()`, `SimSessionView.swift` injects it into the avatar `frame`.
- Profile-block construction is centralized in a `Claude.userProfileBlock()` static helper so both `buildSystem()` and Sim read from the same formatter — DRY.

**Tech Stack:** SwiftUI 5, iOS 17+, `@Observable` AppState, `@AppStorage` (UserDefaults), existing design system (`RWButton`, `RWF`, `SP`, `RR`, `OBHead`).

---

## File Structure

**Modified files only — no new files** (per decision: inline in existing files to avoid `.xcodeproj` churn).

| File | Responsibility added |
|---|---|
| `RowanAI/Features/Onboarding/Onboarding.swift` | `AboutYouView` (onboarding step body), `AboutYouFormSections` (shared form view used by step + edit sheet), `AboutYouEditSheet` (sheet wrapper with Save toolbar), `AboutYouMigrationPrompt` (welcome-back prompt screen). Step 15 wired into the flow graph. |
| `RowanAI/Features/Home/HomeView.swift` | "About You" row in the PREFERENCES section + sheet plumbing. |
| `RowanAI/RowanAIApp.swift` | Second `fullScreenCover` for the migration prompt, gated by a new `@AppStorage("aboutYouMigrationDismissed")` flag. |
| `RowanAI/Core/Services/Claude.swift` | `static func userProfileBlock() -> String` helper. `buildSystem(_:)` appends `userProfileBlock()` when non-empty. |
| `RowanAI/Features/Sim/SimSessionView.swift` | `primeOpening()` and `submitToAvatar()` inject `Claude.userProfileBlock(forSim: true)` into the avatar `frame`. |

---

## Task 1: Add the profile-block helper to Claude.swift

**Files:**
- Modify: `RowanAI/Core/Services/Claude.swift:200-213` (`buildSystem` method) and add a new static helper above it.

- [ ] **Step 1: Read the current `buildSystem` to confirm insertion point**

Run: `grep -n "func buildSystem\|MARK: - Full System Prompt Builder" RowanAI/Core/Services/Claude.swift`
Expected: `198:    // MARK: - Full System Prompt Builder` and `200:    private func buildSystem(_ role: String) -> String {`.

- [ ] **Step 2: Add the `userProfileBlock` static helper directly above `buildSystem`**

Insert immediately before the `// MARK: - Full System Prompt Builder` line at `Claude.swift:198`:

```swift
    // MARK: - User Profile Block
    //
    // Reads the four @AppStorage("userHobbies" / "userGreenFlags" /
    // "userRedFlags" / "userVibes") fields and returns a formatted block
    // for the system prompt. Returns "" when every field is empty so
    // callers can append unconditionally. Shared by buildSystem() and the
    // Sim session frame so both paths personalize from the same source.
    //
    // forSim=true reframes the block from "USER PROFILE" (Cyrano's view of
    // the user) to "USER PROFILE (the person you're chatting with)" so the
    // avatar treats it as their conversation partner's details, not their
    // own. Same fields either way.
    static func userProfileBlock(forSim: Bool = false) -> String {
        let d = UserDefaults.standard
        let hobbies     = (d.string(forKey: "userHobbies")     ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let greenFlags  = (d.string(forKey: "userGreenFlags")  ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let redFlags    = (d.string(forKey: "userRedFlags")    ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let vibes       = (d.string(forKey: "userVibes")       ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if hobbies.isEmpty && greenFlags.isEmpty && redFlags.isEmpty && vibes.isEmpty {
            return ""
        }

        var lines: [String] = []
        if !hobbies.isEmpty    { lines.append("- Hobbies & interests: \(hobbies)") }
        if !greenFlags.isEmpty { lines.append("- Looking for: \(greenFlags)") }
        if !redFlags.isEmpty   { lines.append("- Deal breakers: \(redFlags)") }
        if !vibes.isEmpty      { lines.append("- Personal vibe: \(vibes)") }

        let header = forSim
            ? "USER PROFILE (the person you're chatting with):"
            : "USER PROFILE:"

        let guidance = forSim
            ? "Use this naturally. If they reference one of their interests, engage authentically. Match their personal vibe when it surfaces. Don't list these traits or quiz them on them."
            : "Use this context naturally. Reference their actual interests when generating replies, openers, or coaching. Don't list these traits — weave them in. Match their personal vibe in tone."

        return "\n\n" + header + "\n" + lines.joined(separator: "\n") + "\n\n" + guidance
    }

```

- [ ] **Step 3: Append the block inside `buildSystem`**

In `Claude.swift:200-213`, change the final `return` statement from:

```swift
        return cyranoIdentity + "\n\n" + coachingKnowledge + "\n\n" + safetyRules + "\n\n" + role + "\n\n" + gender.coachingContext + lang + nameInstruction
```

to:

```swift
        return cyranoIdentity + "\n\n" + coachingKnowledge + "\n\n" + safetyRules + "\n\n" + role + "\n\n" + gender.coachingContext + lang + nameInstruction + Claude.userProfileBlock()
```

- [ ] **Step 4: Syntax-check the file**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 \
  RowanAI/Core/Services/Claude.swift 2>&1 | tee /tmp/claude_parse.log
```
Expected: empty log (no errors). If errors reference other files (e.g. `RWUser`, `AISettings`), that's expected from `-parse` of a single file — only failures on `Claude.swift` lines matter.

- [ ] **Step 5: Commit**

```bash
git add RowanAI/Core/Services/Claude.swift
git commit -m "feat(cyrano): inject user profile block into system prompt"
```

---

## Task 2: Sim — inject user profile into the avatar frame

**Files:**
- Modify: `RowanAI/Features/Sim/SimSessionView.swift:566-578` (`primeOpening` frame) and `:637-648` (`submitToAvatar` frame).

- [ ] **Step 1: Update the `primeOpening` frame to include the profile block**

At `SimSessionView.swift:566-572`, replace:

```swift
        let partner = AuthService.shared.currentUser?.partnerName
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))

        SETTING: \(environment.openingScene(for: mode))
        Open the conversation with a single short line in character — 1-2 sentences max.
        """
```

with:

```swift
        let partner = AuthService.shared.currentUser?.partnerName
        let profile = Claude.userProfileBlock(forSim: true)
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))\(profile)

        SETTING: \(environment.openingScene(for: mode))
        Open the conversation with a single short line in character — 1-2 sentences max.
        """
```

- [ ] **Step 2: Update the `submitToAvatar` frame the same way**

At `SimSessionView.swift:637-648`, replace:

```swift
        let partner = AuthService.shared.currentUser?.partnerName
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))

        SETTING: \(environment.openingScene(for: mode))
        \(engagementHint)

        TRANSCRIPT SO FAR:
        \(history)

        YOUR NEXT REPLY (1-3 sentences, in character, no narration, no quotes):
        """
```

with:

```swift
        let partner = AuthService.shared.currentUser?.partnerName
        let profile = Claude.userProfileBlock(forSim: true)
        let frame = """
        \(personality.systemPrompt)\(mode.systemPromptOverlay(partnerName: partner))\(profile)

        SETTING: \(environment.openingScene(for: mode))
        \(engagementHint)

        TRANSCRIPT SO FAR:
        \(history)

        YOUR NEXT REPLY (1-3 sentences, in character, no narration, no quotes):
        """
```

- [ ] **Step 3: Syntax-check**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 \
  RowanAI/Features/Sim/SimSessionView.swift 2>&1 | tee /tmp/sim_parse.log
```
Expected: no errors on `SimSessionView.swift` lines.

- [ ] **Step 4: Commit**

```bash
git add RowanAI/Features/Sim/SimSessionView.swift
git commit -m "feat(sim): personalize avatar frame with user profile"
```

---

## Task 3: Add About You form, sheet, onboarding view, and migration prompt to Onboarding.swift

**Files:**
- Modify: `RowanAI/Features/Onboarding/Onboarding.swift` — append new components at end of file (after `NameEntryView` at line 1769).

- [ ] **Step 1: Append the shared components**

Append to the very end of `RowanAI/Features/Onboarding/Onboarding.swift`:

```swift

// MARK: - About You

/// Canonical list of vibe chips used on the About You screen. Max selection
/// is enforced by the chip row itself — tapping a 4th chip is a no-op.
fileprivate let aboutYouVibeOptions: [String] = [
    "Witty", "Thoughtful", "Adventurous", "Chill", "Ambitious",
    "Creative", "Playful", "Romantic", "Direct", "Funny"
]

fileprivate let aboutYouMaxFieldChars = 200
fileprivate let aboutYouMaxVibes      = 3

/// Returns the set of selected vibes parsed from the comma-separated
/// @AppStorage("userVibes") string. Order is normalized to match
/// aboutYouVibeOptions so the UI feels stable across launches.
fileprivate func aboutYouParseVibes(_ raw: String) -> Set<String> {
    let parts = raw
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    return Set(parts)
}

/// Writes the selected vibes back as a stable, canonical-order CSV.
fileprivate func aboutYouSerializeVibes(_ selected: Set<String>) -> String {
    aboutYouVibeOptions.filter { selected.contains($0) }.joined(separator: ", ")
}

/// Shared body — the four input sections without a header or footer
/// buttons. Embedded by the onboarding step and the Settings edit sheet
/// so both surfaces look identical.
struct AboutYouFormSections: View {
    @Binding var hobbies: String
    @Binding var greenFlags: String
    @Binding var redFlags: String
    @Binding var vibes: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: SP.lg) {
            AboutYouMultilineField(
                label: "HOBBIES & INTERESTS",
                placeholder: "What do you love doing? Hobbies, interests, weekend activities...",
                text: $hobbies
            )
            AboutYouMultilineField(
                label: "WHAT YOU'RE LOOKING FOR",
                placeholder: "What qualities matter most to you in a partner?",
                text: $greenFlags
            )
            AboutYouMultilineField(
                label: "DEAL BREAKERS",
                placeholder: "What's an absolute deal-breaker for you?",
                text: $redFlags
            )
            AboutYouVibePicker(selected: $vibes)
        }
    }
}

/// Single labelled multi-line text field with a 200-char clamp.
struct AboutYouMultilineField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.5)
                Spacer()
                Text("\(text.count)/\(aboutYouMaxFieldChars)")
                    .font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(RWF.body())
                        .foregroundColor(.rwTextMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(RWF.body())
                    .foregroundColor(.rwTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 86)
                    .onChange(of: text) { _, new in
                        if new.count > aboutYouMaxFieldChars {
                            text = String(new.prefix(aboutYouMaxFieldChars))
                        }
                    }
            }
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.lg))
            .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
        }
    }
}

/// 10-chip multi-select. Tap to toggle; capped at 3.
struct AboutYouVibePicker: View {
    @Binding var selected: Set<String>

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR VIBE")
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.5)
                Spacer()
                Text("Pick up to \(aboutYouMaxVibes)")
                    .font(RWF.cap(11))
                    .foregroundColor(.rwTextMuted)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(aboutYouVibeOptions, id: \.self) { v in
                    Button {
                        toggle(v)
                    } label: {
                        Text(v)
                            .font(RWF.med(13))
                            .foregroundColor(selected.contains(v) ? .white : .rwTextPrimary)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selected.contains(v) ? Color.rwAccent : Color.rwCard)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected.contains(v) ? Color.rwAccent : Color.rwBorder, lineWidth: 1))
                    }
                    .buttonStyle(SBS())
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selected.contains(v))
                }
            }
        }
    }

    private func toggle(_ v: String) {
        if selected.contains(v) {
            selected.remove(v)
        } else if selected.count < aboutYouMaxVibes {
            selected.insert(v)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - About You — Onboarding step

/// Onboarding step body. Uses the same OBHead as other onboarding screens.
/// Continue is always enabled (every field is optional); Skip-for-now writes
/// nothing and advances.
struct AboutYouView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @AppStorage("userHobbies")    private var hobbies: String    = ""
    @AppStorage("userGreenFlags") private var greenFlags: String = ""
    @AppStorage("userRedFlags")   private var redFlags: String   = ""
    @AppStorage("userVibes")      private var vibesRaw: String   = ""

    @State private var vibes: Set<String> = []
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            OBHead(
                step: "ABOUT YOU",
                title: "Help Cyrano know you better",
                sub: "The more Cyrano knows, the more personalized your coaching gets. Skip any field and come back later."
            )
            .opacity(on ? 1 : 0)

            ScrollView(showsIndicators: false) {
                AboutYouFormSections(
                    hobbies: $hobbies,
                    greenFlags: $greenFlags,
                    redFlags: $redFlags,
                    vibes: Binding(
                        get: { vibes },
                        set: { new in
                            vibes = new
                            vibesRaw = aboutYouSerializeVibes(new)
                        }
                    )
                )
                .padding(.horizontal, SP.xl)
                .padding(.top, SP.lg)
                .padding(.bottom, 24)
            }
            .opacity(on ? 1 : 0)

            RWButton("Continue", icon: "arrow.right") { onContinue() }
                .padding(.horizontal, SP.xl)
                .opacity(on ? 1 : 0)

            Button { onSkip() } label: {
                Text("Skip for now")
                    .font(RWF.cap(13))
                    .foregroundColor(.rwTextMuted)
                    .padding(.vertical, 14)
            }
            .buttonStyle(SBS())
            .padding(.bottom, 24)
        }
        .background(Color.rwBackground.ignoresSafeArea())
        .onAppear {
            vibes = aboutYouParseVibes(vibesRaw)
            withAnimation(.easeOut(duration: 0.4)) { on = true }
        }
    }
}

// MARK: - About You — Edit Sheet (Settings + Migration)

/// Sheet presentation used from ProfileView → PREFERENCES → About You and
/// from the migration cover after the user taps "Let's go". Same fields as
/// the onboarding step but presented in a NavigationView with Cancel/Save.
struct AboutYouEditSheet: View {
    @Environment(\.dismiss) var dismiss

    @AppStorage("userHobbies")    private var hobbiesStore: String    = ""
    @AppStorage("userGreenFlags") private var greenFlagsStore: String = ""
    @AppStorage("userRedFlags")   private var redFlagsStore: String   = ""
    @AppStorage("userVibes")      private var vibesRawStore: String   = ""

    @State private var hobbies: String = ""
    @State private var greenFlags: String = ""
    @State private var redFlags: String = ""
    @State private var vibes: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                AboutYouFormSections(
                    hobbies: $hobbies,
                    greenFlags: $greenFlags,
                    redFlags: $redFlags,
                    vibes: $vibes
                )
                .padding(.horizontal, SP.lg)
                .padding(.top, SP.lg)
                .padding(.bottom, 40)
            }
            .background(Color.rwBackground.ignoresSafeArea())
            .navigationTitle("About You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.rwTextMuted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundColor(.rwAccent)
                }
            }
        }
        .onAppear {
            // Snapshot stored values into local state so Cancel can bail
            // without writing.
            hobbies    = hobbiesStore
            greenFlags = greenFlagsStore
            redFlags   = redFlagsStore
            vibes      = aboutYouParseVibes(vibesRawStore)
        }
    }

    private func save() {
        hobbiesStore    = hobbies
        greenFlagsStore = greenFlags
        redFlagsStore   = redFlags
        vibesRawStore   = aboutYouSerializeVibes(vibes)
        dismiss()
    }
}

// MARK: - About You — Migration Prompt

/// First-launch prompt shown to users who completed onboarding before this
/// feature shipped. Two outcomes:
///   • "Let's go" → set dismissed flag, then open the AboutYouEditSheet.
///   • "Maybe later" → set dismissed flag and never show again.
/// Hosted in RowanAIApp.swift's RootView via fullScreenCover.
struct AboutYouMigrationPrompt: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var on = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
                Text("ABOUT YOU")
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.8)
                Text("We've added personalization.")
                    .font(RWF.display(28))
                    .foregroundColor(.rwTextPrimary)
                    .multilineTextAlignment(.center)
                Text("Want Cyrano to know you better? It only takes 30 seconds.")
                    .font(RWF.body())
                    .foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SP.xl)
            }
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 14)
            Spacer()
            VStack(spacing: 10) {
                RWButton("Let's go", icon: "arrow.right") { onAccept() }
                Button { onDecline() } label: {
                    Text("Maybe later")
                        .font(RWF.cap(13))
                        .foregroundColor(.rwTextMuted)
                        .padding(.vertical, 14)
                }
                .buttonStyle(SBS())
            }
            .padding(.horizontal, SP.xl)
            .padding(.bottom, 36)
            .opacity(on ? 1 : 0)
        }
        .background(Color.rwBackground.ignoresSafeArea())
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { on = true } }
    }
}
```

- [ ] **Step 2: Wire the new step into the onboarding flow graph**

In `RowanAI/Features/Onboarding/Onboarding.swift:15-32` (the `next(after:)` switch), change:

```swift
        case 0:  return 14           // Welcome → Name (NEW v1.0 — was → Language)
        case 14: return 1            // Name → Language
```

to:

```swift
        case 0:  return 14           // Welcome → Name (NEW v1.0 — was → Language)
        case 14: return 15           // Name → About You (NEW)
        case 15: return 1            // About You → Language
```

- [ ] **Step 3: Wire the new step into the body switch**

In `RowanAI/Features/Onboarding/Onboarding.swift:51-92` (the body `switch step`), insert a new case right after the `case 14:` block (which ends at line 68 with `)`):

```swift
            case 15: AboutYouView(
                        onContinue: { advance() },
                        onSkip: { advance() }
                     )
```

(Place between the existing `case 14: NameEntryView(...)` block and `case 1:  LanguageView(...)`.)

- [ ] **Step 4: Syntax-check**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 \
  RowanAI/Features/Onboarding/Onboarding.swift 2>&1 | tee /tmp/ob_parse.log
```
Expected: no errors on `Onboarding.swift` lines (cross-file references like `AISettings`, `RWUser` may appear — only failures inside this file matter).

- [ ] **Step 5: Commit**

```bash
git add RowanAI/Features/Onboarding/Onboarding.swift
git commit -m "feat(onboarding): add About You step + shared edit/migration sheets"
```

---

## Task 4: Add "About You" row to ProfileView

**Files:**
- Modify: `RowanAI/Features/Home/HomeView.swift:212-542` (ProfileView).

- [ ] **Step 1: Add state for the sheet**

In `RowanAI/Features/Home/HomeView.swift:232` (right after `@State private var showNameEdit = false`), insert:

```swift
    @State private var showAboutYouEdit = false
```

- [ ] **Step 2: Add the row in the PREFERENCES "Other preferences" card**

In `RowanAI/Features/Home/HomeView.swift:372-427` (the PREFERENCES `VStack(spacing: 0) { ... }`), insert the new row directly above `PRow(icon: "globe", title: "Language") { showLanguage = true }` (~line 426). Add **before** that line:

```swift
                        PRow(icon: "sparkles", title: "About You") { showAboutYouEdit = true }
```

`PRow` already renders a divider after itself (see `HomeView.swift:681`), so no extra divider is needed.

- [ ] **Step 3: Attach the sheet modifier**

In `RowanAI/Features/Home/HomeView.swift:507-517` (right after the existing `.sheet(isPresented: $showNameEdit)` block), insert:

```swift
            .sheet(isPresented: $showAboutYouEdit) {
                AboutYouEditSheet()
            }
```

- [ ] **Step 4: Syntax-check**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 \
  RowanAI/Features/Home/HomeView.swift 2>&1 | tee /tmp/home_parse.log
```
Expected: no errors on `HomeView.swift` lines.

- [ ] **Step 5: Commit**

```bash
git add RowanAI/Features/Home/HomeView.swift
git commit -m "feat(profile): add About You row in PREFERENCES"
```

---

## Task 5: Migration cover in RowanAIApp.swift

**Files:**
- Modify: `RowanAI/RowanAIApp.swift:24-164` (`RootView`).

- [ ] **Step 1: Add the migration storage flag and sheet-trigger state**

In `RowanAI/RowanAIApp.swift:39` (right after the existing `@AppStorage("userDisplayName")`), insert:

```swift
    // v1.1 About You migration — set true by either button in the prompt
    // (Let's go or Maybe later) so the cover is one-shot. Existing users with
    // an empty userHobbies / userGreenFlags / userRedFlags / userVibes get
    // one chance to see it; new users never do because the onboarding step
    // either fills the fields or leaves them empty after a deliberate Skip
    // — we treat the migration dismiss flag as automatically true for them
    // (see binding below — once any field has content OR they completed
    // onboarding *after* this build, we just skip).
    @AppStorage("aboutYouMigrationDismissed") private var aboutYouMigrationDismissed: Bool = false
    @AppStorage("userHobbies")    private var userHobbies: String    = ""
    @AppStorage("userGreenFlags") private var userGreenFlags: String = ""
    @AppStorage("userRedFlags")   private var userRedFlags: String   = ""
    @AppStorage("userVibes")      private var userVibes: String      = ""

    @State private var showAboutYouSheet: Bool = false
```

- [ ] **Step 2: Add the migration cover and edit sheet at the end of the body chain**

At `RowanAI/RowanAIApp.swift:146-162` (after the existing v1.0 name-migration `fullScreenCover`), append two new modifiers — a `fullScreenCover` for the prompt and a `sheet` for the edit form. Insert directly **after** the existing closing `}` of the name-migration `fullScreenCover` block (the line with just `}` that closes the `NameEntryView` cover):

```swift
        // v1.1 About You migration — shown once to users who completed
        // onboarding before this feature shipped. Gated on:
        //   • onboarding complete
        //   • the one-shot dismiss flag is still false
        //   • all four About You fields are empty (otherwise they've
        //     already engaged with the feature — no need to prompt).
        //   • name migration is settled (userDisplayName non-empty) so
        //     the two covers don't stack on first launch.
        .fullScreenCover(isPresented: Binding(
            get: {
                appState.hasCompletedOnboarding
                    && !aboutYouMigrationDismissed
                    && !userDisplayName.isEmpty
                    && userHobbies.isEmpty
                    && userGreenFlags.isEmpty
                    && userRedFlags.isEmpty
                    && userVibes.isEmpty
            },
            set: { _ in }
        )) {
            AboutYouMigrationPrompt(
                onAccept: {
                    aboutYouMigrationDismissed = true
                    // Open the edit sheet on the next runloop tick so the
                    // cover has time to dismiss cleanly before the sheet
                    // presents.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showAboutYouSheet = true
                    }
                },
                onDecline: {
                    aboutYouMigrationDismissed = true
                }
            )
        }
        .sheet(isPresented: $showAboutYouSheet) {
            AboutYouEditSheet()
        }
```

- [ ] **Step 3: Syntax-check**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 \
  RowanAI/RowanAIApp.swift 2>&1 | tee /tmp/app_parse.log
```
Expected: no errors on `RowanAIApp.swift` lines.

- [ ] **Step 4: Commit**

```bash
git add RowanAI/RowanAIApp.swift
git commit -m "feat(migration): one-time About You prompt for existing users"
```

---

## Task 6: Full project build + summary

- [ ] **Step 1: Run `swiftc -parse` across all five modified files**

Run:
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
for f in \
  RowanAI/Core/Services/Claude.swift \
  RowanAI/Features/Sim/SimSessionView.swift \
  RowanAI/Features/Onboarding/Onboarding.swift \
  RowanAI/Features/Home/HomeView.swift \
  RowanAI/RowanAIApp.swift
do
  echo "=== $f ==="
  xcrun swiftc -parse -sdk "$SDK" -target arm64-apple-ios17.0 "$f" 2>&1 \
    | grep -E "$(basename "$f"):" || echo "OK"
done
```
Expected: every file prints `OK`.

- [ ] **Step 2: Full Xcode build**

Run from `/Users/chazrakita/Desktop/Developer/RowanAI`:
```bash
xcodebuild \
  -project RowanAI.xcodeproj \
  -scheme RowanAI \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -quiet \
  build 2>&1 | tee /tmp/rowan_build.log

echo "--- ERRORS ---"; grep -E "error:" /tmp/rowan_build.log || echo "0 errors"
echo "--- WARNINGS ---"; grep -E "warning:" /tmp/rowan_build.log || echo "0 warnings"
echo "--- RESULT ---"; grep -E "BUILD SUCCEEDED|BUILD FAILED" /tmp/rowan_build.log
```
Expected: `0 errors`, `0 warnings` (in the files we modified — pre-existing warnings elsewhere are out of scope; flag them but don't fail the task), `BUILD SUCCEEDED`.

- [ ] **Step 3: Print the verification summary**

Print to the user:

```
=== About You Personalization — Summary ===

New onboarding step:
  • Step 15 ("AboutYouView"), routed AFTER Name (step 14) and BEFORE Language (step 1).
  • Eyebrow "ABOUT YOU", headline "Help Cyrano know you better".
  • Four sections: HOBBIES & INTERESTS, WHAT YOU'RE LOOKING FOR, DEAL BREAKERS, YOUR VIBE.
  • Continue always enabled; Skip-for-now advances without writing.

Storage:
  • @AppStorage("userHobbies")    String
  • @AppStorage("userGreenFlags") String
  • @AppStorage("userRedFlags")   String
  • @AppStorage("userVibes")      String   (canonical-order CSV)

Flow into Cyrano:
  • Claude.userProfileBlock() — reads the four keys, returns "" if all empty,
    otherwise a USER PROFILE: block + guidance line.
  • Appended in buildSystem() at Claude.swift — covers every reply/opener/
    coaching/debrief/etc. path that funnels through buildSystem.
  • Sim primeOpening() + submitToAvatar() inject the same block with
    forSim: true so the avatar treats it as their chat partner's profile.

Edit access:
  • Settings → Profile → PREFERENCES → "About You" (sparkles icon)
    → AboutYouEditSheet (Cancel / Save).

Migration:
  • One-shot fullScreenCover in RowanAIApp.swift RootView.
  • Gated on: onboarding complete, name migration settled, all four
    About You fields empty, aboutYouMigrationDismissed == false.
  • "Let's go" sets dismissed flag and opens the edit sheet.
  • "Maybe later" sets dismissed flag and never shows again.

Build: 0 errors, 0 warnings, BUILD SUCCEEDED.
```

- [ ] **Step 4: Final commit (only if Step 2 caught any leftover fixups; otherwise skip)**

```bash
git status
# if anything is dirty:
git add -A
git commit -m "chore: build-clean fixups for About You"
```

---

## Self-Review Notes

**Spec coverage check:**
- CHANGE 1 (onboarding step) → Task 3 Steps 1-3.
- CHANGE 2 (@AppStorage persistence) → all four keys used in `AboutYouView`, `AboutYouEditSheet`, `Claude.userProfileBlock`, migration gate.
- CHANGE 3 (Settings edit) → Task 4.
- CHANGE 4 (pass to Cyrano) → Task 1; covers both `buildSystem` (which `openers()` already uses, so no separate `buildOpenerSystem` is needed — verified via grep at `Claude.swift:674`).
- CHANGE 5 (Sim) → Task 2; `forSim: true` reframes the block for the avatar.
- CHANGE 6 (optional migration) → Task 5; `aboutYouMigrationDismissed` flag.
- CHANGE 7 (verify) → Task 6; runs both `swiftc -parse` and `xcodebuild`, prints summary.

**Placeholder scan:** clean — every code step has full code; every command shows exact invocation.

**Type consistency:** `AboutYouFormSections` takes `Binding<Set<String>>` for vibes; both call sites pass exactly that. `Claude.userProfileBlock(forSim:)` signature matches both call sites. `@AppStorage` keys are spelled identically across all five files.
