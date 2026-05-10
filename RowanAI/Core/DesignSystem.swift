import SwiftUI

// MARK: - Colors
// Cal.ai inspired — clean white, near-black text, single gradient accent from Rowan logo

extension Color {
    // Backgrounds
    static let rwBackground    = Color(hex: "FFFFFF")
    static let rwSurface       = Color(hex: "F7F8FA")
    static let rwCard          = Color(hex: "FFFFFF")
    static let rwCardElevated  = Color(hex: "F2F4F8")

    // Brand accent — pink → teal gradient endpoints
    static let rwAccent        = Color(hex: "E8356D")   // pink
    static let rwAccentSoft    = Color(hex: "E8356D").opacity(0.08)
    static let rwGold          = Color(hex: "00BFB3")   // teal
    static let rwGoldSoft      = Color(hex: "00BFB3").opacity(0.08)
    static let rwViolet        = Color(hex: "5B8DEF")
    static let rwAmber         = Color(hex: "C0A020")   // warm amber for Relationship mode
    static let rwAmberSoft     = Color(hex: "C0A020").opacity(0.10)

    // Text — near black, high contrast
    static let rwTextPrimary   = Color(hex: "0D0D0D")
    static let rwTextSecondary = Color(hex: "6B7280")
    static let rwTextMuted     = Color(hex: "B0B7C3")

    // Semantic
    static let rwSuccess       = Color(hex: "00BFB3")
    static let rwWarning       = Color(hex: "F59E0B")
    static let rwDanger        = Color(hex: "E8356D")

    // Borders — barely visible
    static let rwBorder        = Color(hex: "0D0D0D").opacity(0.06)
    static let rwBorderAccent  = Color(hex: "E8356D").opacity(0.15)
    static let rwShadow        = Color(hex: "0D0D0D").opacity(0.05)
    static let rwShadowDeep    = Color(hex: "E8356D").opacity(0.18) // gradient-button glow

    // Cinematic palette — for Face to Face Sim and any "stage" view
    static let rwInk           = Color(hex: "0A0612")  // near-black with violet undertone
    static let rwInkSurface    = Color(hex: "1A1422")
    static let rwInkBorder     = Color.white.opacity(0.08)
    static let rwInkText       = Color(hex: "F5F2F8")
    static let rwInkTextMuted  = Color(hex: "9C95A8")

    // Navy (for dark elements)
    static let rwNavy          = Color(hex: "1B2B4B")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        let a, r, g, b: UInt64
        switch h.count {
        case 6: (a,r,g,b) = (255, n>>16, n>>8&0xFF, n&0xFF)
        case 8: (a,r,g,b) = (n>>24, n>>16&0xFF, n>>8&0xFF, n&0xFF)
        default:(a,r,g,b) = (255,255,255,255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Gradients

extension LinearGradient {
    // Signature brand gradient — strict pink → teal, the spec.
    static let accent = LinearGradient(
        colors: [Color(hex: "E8356D"), Color(hex: "00BFB3")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Subtle, faded version for hairlines and tints.
    static let accentSoft = LinearGradient(
        colors: [Color(hex: "E8356D").opacity(0.12), Color(hex: "00BFB3").opacity(0.12)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Warm amber gradient — Relationship mode signature.
    static let amber = LinearGradient(
        colors: [Color(hex: "E0B844"), Color(hex: "A88416")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Cinematic radial — Face to Face Sim avatar stage backdrop.
    static let cinematic = LinearGradient(
        colors: [Color(hex: "1A1422"), Color(hex: "0A0612")],
        startPoint: .top, endPoint: .bottom)

    // Teal gradient
    static let gold = LinearGradient(
        colors: [Color(hex: "00BFB3"), Color(hex: "00A8A0")],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    // Dark gradient for nav/headers
    static let navy = LinearGradient(
        colors: [Color(hex: "1B2B4B"), Color(hex: "0F1E38")],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - Typography
// SF Pro Rounded for headers — same as Cal.ai, Hinge, Linear

// SF Pro Rounded throughout — including body text — per the visual spec.
// Weights graduate cleanly from black (display) through semibold (heads),
// medium (UI labels), regular (body), and back up at micro for chip captions.
struct RWF {
    static func display(_ s: CGFloat = 34) -> Font { .system(size: s, weight: .black,    design: .rounded) }
    static func title(_ s: CGFloat = 28) -> Font   { .system(size: s, weight: .bold,     design: .rounded) }
    static func head(_ s: CGFloat = 20) -> Font    { .system(size: s, weight: .semibold, design: .rounded) }
    static func body(_ s: CGFloat = 17) -> Font    { .system(size: s, weight: .regular,  design: .rounded) }
    static func med(_ s: CGFloat = 17) -> Font     { .system(size: s, weight: .medium,   design: .rounded) }
    static func cap(_ s: CGFloat = 13) -> Font     { .system(size: s, weight: .medium,   design: .rounded) }
    static func micro(_ s: CGFloat = 11) -> Font   { .system(size: s, weight: .semibold, design: .rounded) }
    // Monospaced lockup — for codes, scores, timers — preserves rounded feel.
    static func mono(_ s: CGFloat = 18, weight: Font.Weight = .bold) -> Font {
        .system(size: s, weight: weight, design: .monospaced)
    }
}

// MARK: - Spacing / Radius
// Cal.ai uses very generous spacing and very round corners

enum SP {
    static let xs: CGFloat = 4;  static let sm: CGFloat = 8
    static let md: CGFloat = 16; static let lg: CGFloat = 24
    static let xl: CGFloat = 32; static let xxl: CGFloat = 48
}

enum RR {
    static let sm: CGFloat = 10;  static let md: CGFloat = 14
    static let lg: CGFloat = 18;  static let xl: CGFloat = 24
    static let xxl: CGFloat = 32; static let pill: CGFloat = 999
}

// MARK: - Button Style

struct SBS: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - RWButton
// Full-width pill. Primary = signature pink→teal gradient with a colored glow.
// Secondary = neutral surface, used as the "cancel/return" sibling to a primary.
// Ghost = inline text-button with accent color. Dark = inverted neutral.
// Cinematic = white-on-translucent for dark stage views (Face to Face Sim).

struct RWButton: View {
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    let action: () -> Void

    enum Style { case primary, secondary, ghost, dark, cinematic }

    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.style = style; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium, design: .rounded)) }
                Text(title).font(RWF.med(16))
            }
            .foregroundColor(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(bg)
            .overlay(borderOverlay)
            .clipShape(RoundedRectangle(cornerRadius: RR.pill))
            .shadow(color: shadowColor, radius: 22, x: 0, y: 10)
        }
        .buttonStyle(SBS())
    }

    @ViewBuilder var bg: some View {
        switch style {
        case .primary:   LinearGradient.accent
        case .dark:      Color(hex: "0D0D0D")
        case .secondary: Color.rwSurface
        case .ghost:     Color.clear
        case .cinematic: Color.white.opacity(0.10)
        }
    }

    @ViewBuilder var borderOverlay: some View {
        switch style {
        case .secondary:
            RoundedRectangle(cornerRadius: RR.pill).stroke(Color.rwBorder, lineWidth: 1)
        case .cinematic:
            RoundedRectangle(cornerRadius: RR.pill).stroke(Color.white.opacity(0.18), lineWidth: 1)
        default: EmptyView()
        }
    }

    var fg: Color {
        switch style {
        case .primary, .dark, .cinematic: return .white
        case .secondary:                  return .rwTextPrimary
        case .ghost:                      return .rwAccent
        }
    }

    var shadowColor: Color {
        switch style {
        case .primary:   return Color(hex: "E8356D").opacity(0.32)
        case .dark:      return Color(hex: "0D0D0D").opacity(0.22)
        case .cinematic: return Color.black.opacity(0.6)
        default:         return .clear
        }
    }
}

// MARK: - Page Header
// Single source of truth for the screen-level title block. Use this everywhere
// instead of one-off `OBHead`-style inline VStacks to enforce the consistent
// header style the spec requires.

struct RWPageHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var alignment: HorizontalAlignment = .leading
    var topPadding: CGFloat = 8

    init(_ title: String,
         eyebrow: String? = nil,
         subtitle: String? = nil,
         alignment: HorizontalAlignment = .leading,
         topPadding: CGFloat = 8) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.alignment = alignment
        self.topPadding = topPadding
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(RWF.micro())
                    .foregroundStyle(LinearGradient.accent)
                    .tracking(1.6)
            }
            Text(title)
                .font(RWF.display(32))
                .foregroundColor(.rwTextPrimary)
                .lineLimit(3)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(RWF.body(16))
                    .foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .padding(.top, topPadding)
    }
}

// MARK: - Card
// Premium card — white surface, hairline border, two-layer shadow for depth.
// Use the default; reach for `.cinematic` variant on dark stages.

struct RWCard<C: View>: View {
    let content: C
    var pad: CGFloat = SP.lg
    var variant: Variant = .light

    enum Variant { case light, cinematic }

    init(pad: CGFloat = SP.lg,
         variant: Variant = .light,
         @ViewBuilder _ content: () -> C) {
        self.content = content()
        self.pad = pad
        self.variant = variant
    }

    var body: some View {
        content
            .padding(pad)
            .background(variant == .cinematic ? Color.rwInkSurface : Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(
                RoundedRectangle(cornerRadius: RR.xl)
                    .stroke(variant == .cinematic ? Color.rwInkBorder : Color.rwBorder,
                            lineWidth: 1)
            )
            .shadow(color: variant == .cinematic ? Color.black.opacity(0.4) : Color.rwShadow,
                    radius: 24, x: 0, y: 10)
    }
}

// MARK: - Quick Action Tile
// The standard "destination card" used on Home and entry surfaces. Two-line
// layout, accent-tinted icon chip, soft shadow. Pass a `tint` to color-key it.

struct RWQuickTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = .rwAccent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: RR.md)
                        .fill(tint.opacity(0.10))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(RWF.head(16)).foregroundColor(.rwTextPrimary)
                    Text(subtitle).font(RWF.cap(12)).foregroundColor(.rwTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .padding(SP.md)
            .background(Color.rwCard)
            .clipShape(RoundedRectangle(cornerRadius: RR.xl))
            .overlay(RoundedRectangle(cornerRadius: RR.xl).stroke(Color.rwBorder, lineWidth: 1))
            .shadow(color: tint.opacity(0.10), radius: 18, x: 0, y: 6)
        }
        .buttonStyle(SBS())
    }
}

// MARK: - Header Bar
// A consistent leading-back / centered-title / trailing-action toolbar that
// sits inside the body (avoids navigation bar inconsistencies across sheets).

struct RWHeaderBar<Trailing: View>: View {
    let title: String?
    var onClose: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String? = nil,
         onClose: (() -> Void)? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.onClose = onClose
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.rwTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.rwSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.rwBorder, lineWidth: 1))
                }
                .buttonStyle(SBS())
            }
            if let title {
                Text(title).font(RWF.head(15)).foregroundColor(.rwTextPrimary)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, SP.lg)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Divider

struct RWLine: View {
    var body: some View {
        Rectangle().fill(Color.rwBorder).frame(height: 1)
    }
}

// MARK: - Accent Dot

struct GlowDot: View {
    var color: Color = .rwAccent
    var size: CGFloat = 8
    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .shadow(color: color.opacity(0.3), radius: size)
    }
}

// MARK: - Loading

struct RWLoading: View {
    let msg: String
    @State private var pulsing = false
    var body: some View {
        VStack(spacing: SP.lg) {
            ZStack {
                Circle().fill(Color.rwAccent.opacity(0.08))
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulsing ? 1.5 : 1)
                    .opacity(pulsing ? 0 : 0.7)
                ProgressView().tint(.rwAccent).scaleEffect(1.1)
            }
            Text(msg).font(RWF.cap()).foregroundColor(.rwTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { pulsing = true }
        }
    }
}

// MARK: - Empty State

struct RWEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var cta: String? = nil
    var ctaIcon: String? = nil
    var onCTA: (() -> Void)? = nil
    @State private var on = false

    var body: some View {
        VStack(spacing: SP.xl) {
            ZStack {
                Circle().fill(Color.rwAccent.opacity(0.06)).frame(width: 110, height: 110)
                Circle().fill(Color.rwAccent.opacity(0.10)).frame(width: 78, height: 78)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient.accent)
            }
            .scaleEffect(on ? 1 : 0.6)
            .opacity(on ? 1 : 0)

            VStack(spacing: 10) {
                Text(title).font(RWF.title(22)).foregroundColor(.rwTextPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle).font(RWF.body()).foregroundColor(.rwTextSecondary)
                    .multilineTextAlignment(.center).padding(.horizontal, SP.xl)
            }
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 10)

            if let cta, let onCTA {
                RWButton(cta, icon: ctaIcon, action: onCTA)
                    .padding(.horizontal, SP.xxl)
                    .opacity(on ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SP.xxl)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15)) { on = true }
        }
    }
}

/// MARK: - Section Label

struct RWSectionLabel: View {
    let title: String
    var accent: Bool = false

    init(_ title: String, accent: Bool = false) {
        self.title = title
        self.accent = accent
    }
    var body: some View {
        HStack(spacing: 6) {
            if accent { GlowDot(size: 6) }
            Text(title).font(RWF.micro()).foregroundColor(accent ? .rwAccent : .rwTextMuted).tracking(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Segmented Picker

struct RWSegmentedPicker<T: Hashable>: View {
    let options: [(value: T, label: String, icon: String?)]
    @Binding var selected: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = opt.value }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 5) {
                        if let icon = opt.icon {
                            Image(systemName: icon).font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        Text(opt.label).font(RWF.cap(12))
                    }
                    .foregroundColor(selected == opt.value ? .white : .rwTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selected == opt.value {
                                RoundedRectangle(cornerRadius: RR.md)
                                    .fill(Color(hex: "0D0D0D"))
                                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                            }
                        }
                    )
                }
                .buttonStyle(SBS())
            }
        }
        .padding(4)
        .background(Color.rwSurface)
        .clipShape(RoundedRectangle(cornerRadius: RR.lg))
        .overlay(RoundedRectangle(cornerRadius: RR.lg).stroke(Color.rwBorder, lineWidth: 1))
    }
}

// MARK: - View Modifiers

extension View {
    func rwBG() -> some View {
        background(Color.rwBackground.ignoresSafeArea())
    }

    func hideKB() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    func staggerAppear(_ index: Int, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.07), value: appeared)
    }
}

// MARK: - Rowan Logo Heart
// Programmatic version of the logo heart — two overlapping hearts

struct RowanLogo: View {
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Outer heart — teal/violet gradient
            Image(systemName: "heart.fill")
                .font(.system(size: size, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "5B8DEF"), Color(hex: "00BFB3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
                .offset(y: size * 0.1)

            // Inner heart — pink
            Image(systemName: "heart.fill")
                .font(.system(size: size * 0.6, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "F0387A"), Color(hex: "E8356D")],
                        startPoint: .top,
                        endPoint: .bottom))
                .offset(y: -size * 0.1)
        }
        .frame(width: size * 1.2, height: size * 1.2)
    }
}
