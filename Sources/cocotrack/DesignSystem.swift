import AppKit
import SwiftUI

enum DS {
    enum Palette {
        static let bg          = dyn(light: 0xFBF9F5, dark: 0x2A2620)
        static let bgElev      = dyn(light: 0xFFFFFF, dark: 0x322D26)
        static let card        = dyn(light: 0xF8F6F1, dark: 0x36312A)
        static let card2       = dyn(light: 0xF1EEE8, dark: 0x3F3A32)
        static let line        = dyn(light: 0xE2DFD9, dark: 0x4A453C)
        static let lineSoft    = dyn(light: 0xEDEAE4, dark: 0x3B362F)
        static let ink         = dyn(light: 0x2A2620, dark: 0xF4F1EC)
        static let ink2        = dyn(light: 0x5D584F, dark: 0xC3BDB3)
        // ink3/ink4 and the semantic colours below were darkened/lightened so that
        // every one of them clears WCAG AA (4.5:1) for body text — or 3:1 for the
        // purely decorative ink4 — against both `bg` and `card`. The previous
        // values sat between 1.9:1 and 3.3:1, i.e. warning and status text was
        // measurably unreadable in light mode. Hue is preserved; only lightness moved.
        static let ink3        = dyn(light: 0x726D64, dark: 0x9C968C)
        static let ink4        = dyn(light: 0x8F897E, dark: 0x847E73)
        static let accent      = dyn(light: 0xD27B4D, dark: 0xEB9067)
        static let accentInk   = dyn(light: 0x6F3A1B, dark: 0xF2B997)
        static let accentBg    = dyn(light: 0xF7ECDA, dark: 0x4A3729)
        /// Foreground for filled accent buttons. White on the light-mode terracotta,
        /// near-black on the lighter dark-mode terracotta (white there was 2.4:1).
        static let onAccent    = dyn(light: 0xFFFFFF, dark: 0x2A2620)
        static let ok          = dyn(light: 0x347553, dark: 0x67BC91)
        static let warn        = dyn(light: 0x8A6410, dark: 0xD9B255)
        static let bad         = dyn(light: 0xB33F31, dark: 0xE87E6E)
        static let titlebar    = dyn(light: 0xF1EEE8, dark: 0x322D26)
    }

    enum Font {
        static let appName            = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let appSub             = SwiftUI.Font.system(size: 11, weight: .regular)
        static let sectionLabel       = SwiftUI.Font.system(size: 10.5, weight: .heavy)
        static let runningDesc        = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let elapsedHero        = SwiftUI.Font.system(size: 40, weight: .bold, design: .monospaced).monospacedDigit()
        static let elapsedPopover     = SwiftUI.Font.system(size: 26, weight: .bold, design: .monospaced).monospacedDigit()
        static let entryDesc          = SwiftUI.Font.system(size: 13, weight: .medium)
        static let entryMeta          = SwiftUI.Font.system(size: 11, weight: .regular)
        static let entryDur           = SwiftUI.Font.system(size: 12.5, weight: .semibold, design: .monospaced).monospacedDigit()
        static let dayHead            = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let daySum             = SwiftUI.Font.system(size: 11.5, weight: .semibold, design: .monospaced).monospacedDigit()
        static let qsDesc             = SwiftUI.Font.system(size: 13, weight: .medium)
        static let qsProj             = SwiftUI.Font.system(size: 11, weight: .regular)
        static let qsStart            = SwiftUI.Font.system(size: 11.5, weight: .semibold)
        static let capsule            = SwiftUI.Font.system(size: 11.5, weight: .medium)
        static let textField          = SwiftUI.Font.system(size: 13, weight: .regular)
        static let warnText           = SwiftUI.Font.system(size: 11.5, weight: .medium)
        static let statusBar          = SwiftUI.Font.system(size: 11, weight: .regular)
        static let statusBarRight     = SwiftUI.Font.system(size: 10.5, weight: .regular)
        static let configHeadline     = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let configSub          = SwiftUI.Font.system(size: 12, weight: .regular)
        static let popHead            = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let runningBadge       = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let sheetTitle         = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let sheetSub           = SwiftUI.Font.system(size: 12, weight: .regular)
        static let formLabel          = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let btnDefault         = SwiftUI.Font.system(size: 12, weight: .medium)
        static let btnLg              = SwiftUI.Font.system(size: 13, weight: .semibold)
    }

    enum Metric {
        static let cardRadius: CGFloat = 10
        static let rowRadius: CGFloat = 6
        static let btnRadius: CGFloat = 5
        static let btnLgRadius: CGFloat = 6
        static let textFieldRadius: CGFloat = 5
        static let sectionPaddingH: CGFloat = 18
        static let contentMaxWidth: CGFloat = 560
        static let topPadding: CGFloat = 14
        static let bottomPadding: CGFloat = 10
        static let cardPadding: CGFloat = 16
        static let dividerVMargin: CGFloat = 14
        static let entryBarWidth: CGFloat = 3
        static let entryBarHeight: CGFloat = 24
        static let starWidth: CGFloat = 18
        static let elapsedSize: CGFloat = 40
        static let popoverElapsedSize: CGFloat = 26
    }

    private static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return ns(hex: isDark ? dark : light)
        }))
    }

    private static func ns(hex: UInt32) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Reusable bits

struct DSDivider: View {
    var soft: Bool = true
    var body: some View {
        Rectangle()
            .fill(soft ? DS.Palette.lineSoft : DS.Palette.line)
            .frame(height: 0.5)
    }
}

struct DSCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .padding(DS.Metric.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DS.Metric.cardRadius, style: .continuous)
                    .fill(DS.Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Metric.cardRadius, style: .continuous)
                    .strokeBorder(DS.Palette.line, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.sectionLabel)
            .tracking(1)
            .foregroundStyle(DS.Palette.ink3)
    }
}

// Pulsing live indicator for active timer
struct LiveDot: View {
    var size: CGFloat = 6
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(DS.Palette.ok)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(DS.Palette.ok.opacity(pulsing ? 0 : 0.55), lineWidth: pulsing ? 5 : 0)
                    .scaleEffect(pulsing ? 2.4 : 1)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)
            // The indefinite pulse is decorative; honouring Reduce Motion also
            // stops a permanent animation loop from running behind the timer.
            .onAppear { pulsing = !reduceMotion }
            .accessibilityHidden(true)
    }
}

// Status dot used in toolbar (not pulsing)
struct StatusDot: View {
    enum Kind { case ok, warn, off }
    let kind: Kind

    var color: Color {
        switch kind {
        case .ok:   return DS.Palette.ok
        case .warn: return DS.Palette.warn
        case .off:  return DS.Palette.ink4
        }
    }

    // The dot alone encodes state by colour only, so VoiceOver gets the wording.
    private var stateLabel: String {
        switch kind {
        case .ok:   return L10n.statusConnected
        case .warn: return L10n.statusNeedsConnection
        case .off:  return L10n.statusNotConfigured
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(color.opacity(kind == .off ? 0 : 0.25), lineWidth: 2)
                    .scaleEffect(1.4)
            )
            .accessibilityElement()
            .accessibilityLabel(L10n.a11yConnectionStatus)
            .accessibilityValue(stateLabel)
            .help(stateLabel)
    }
}

// Elapsed time with grayed colons (matches `.elapsed .sec { color: var(--ink-3) }`)
struct ElapsedText: View {
    let text: String   // "HH:MM:SS"
    let font: SwiftUI.Font
    var colonColor: Color = DS.Palette.ink3
    var primaryColor: Color = DS.Palette.ink

    var body: some View {
        content
            // Without this the digits are read out as five separate elements
            // ("12", ":", "34", ":", "56").
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.a11yElapsed(text))
    }

    private var content: some View {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        return HStack(spacing: 0) {
            if parts.count == 3 {
                Text(parts[0]).foregroundStyle(primaryColor)
                Text(":").foregroundStyle(colonColor)
                Text(parts[1]).foregroundStyle(primaryColor)
                Text(":").foregroundStyle(colonColor)
                Text(parts[2]).foregroundStyle(primaryColor)
            } else {
                Text(text).foregroundStyle(primaryColor)
            }
        }
        .font(font)
    }
}

// "Capsule" project picker matching .capsule and .capsule.strong
struct ProjectCapsuleLabel: View {
    let projectName: String?
    let projectColorHex: String?
    var strong: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let projectName {
                Circle()
                    .fill(Color(hex: projectColorHex ?? "") ?? DS.Palette.ink4)
                    .frame(width: 8, height: 8)
                Text(projectName)
                    .lineLimit(1)
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Palette.ink3)
                Text(L10n.noProject)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DS.Palette.ink3)
                .padding(.leading, 1)
        }
        .font(DS.Font.capsule)
        .foregroundStyle(DS.Palette.ink2)
        .padding(.leading, 8)
        .padding(.trailing, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(strong ? DS.Palette.bgElev : DS.Palette.card2)
        )
        .overlay(
            Capsule().strokeBorder(strong ? DS.Palette.line : Color.clear, lineWidth: 0.5)
        )
        .fixedSize()
    }
}

// Replacement for .capsule used inline in Menu label (sized to content)
struct ProjectCapsuleMenuLabel: View {
    let selectedProjectId: String?
    let projects: [ClockifyProject]
    var strong: Bool = false

    var body: some View {
        if let id = selectedProjectId, let p = projects.first(where: { $0.id == id }) {
            ProjectCapsuleLabel(projectName: p.name, projectColorHex: p.color, strong: strong)
        } else {
            ProjectCapsuleLabel(projectName: nil, projectColorHex: nil, strong: strong)
        }
    }
}

// Buttons matching .btn / .btn.prom / .btn.danger / .btn.lg / .btn.ghost
struct DSButtonStyle: ButtonStyle {
    enum Kind { case standard, prominent, danger, ghost }
    var kind: Kind = .standard
    var large: Bool = false
    var iconOnly: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let bg: Color
        let fg: Color
        let border: Color

        switch kind {
        case .standard:
            bg = DS.Palette.bgElev
            fg = DS.Palette.ink
            border = DS.Palette.line
        case .prominent:
            bg = DS.Palette.accent
            fg = DS.Palette.onAccent
            border = .clear
        case .danger:
            bg = DS.Palette.bad
            fg = DS.Palette.onAccent
            border = .clear
        case .ghost:
            bg = .clear
            fg = DS.Palette.ink2
            border = .clear
        }

        let pad: EdgeInsets = {
            if iconOnly { return EdgeInsets(top: 4, leading: 7, bottom: 4, trailing: 7) }
            if large { return EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14) }
            return EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        }()

        let radius = large ? DS.Metric.btnLgRadius : DS.Metric.btnRadius

        return configuration.label
            .font(large ? DS.Font.btnLg : DS.Font.btnDefault)
            .foregroundStyle(fg)
            .padding(pad)
            .frame(minHeight: large ? 28 : 22)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(bg.opacity(configuration.isPressed ? 0.85 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 0.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static var dsStandard: DSButtonStyle { DSButtonStyle(kind: .standard) }
    static var dsStandardIcon: DSButtonStyle { DSButtonStyle(kind: .standard, iconOnly: true) }
    static var dsProminent: DSButtonStyle { DSButtonStyle(kind: .prominent, large: true) }
    static var dsDanger: DSButtonStyle { DSButtonStyle(kind: .danger, large: true) }
    static var dsGhost: DSButtonStyle { DSButtonStyle(kind: .ghost) }
    static var dsGhostIcon: DSButtonStyle { DSButtonStyle(kind: .ghost, iconOnly: true) }
}

// Text field matching .tfield
struct DSTextFieldStyle: TextFieldStyle {
    // `.textFieldStyle(.plain)` strips the native focus ring, so keyboard users
    // previously had no visible indication of which field held focus. The
    // `@FocusState` below was declared but never bound; it now drives the ring.
    @FocusState private var focused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(DS.Font.textField)
            .foregroundStyle(DS.Palette.ink)
            .focused($focused)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: DS.Metric.textFieldRadius, style: .continuous)
                    .fill(DS.Palette.bgElev)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Metric.textFieldRadius, style: .continuous)
                    .strokeBorder(focused ? DS.Palette.accent : DS.Palette.line, lineWidth: focused ? 2 : 0.5)
            )
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}

extension TextFieldStyle where Self == DSTextFieldStyle {
    static var ds: DSTextFieldStyle { DSTextFieldStyle() }
}
