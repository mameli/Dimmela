import AppKit
import SwiftUI

/// dimmela.app's colours, light and dark, for the welcome tour.
enum Brand {
    static let accent = Color(light: 0x128A3E, dark: 0x6FE68B)
    /// The hero's text: dark green on the light gradient, near white on the dark one.
    static let ink = Color(light: 0x04220F, dark: 0xEFFFF3)
    static let inkSecondary = Color(light: 0x04220F, dark: 0xE8FFEE, lightOpacity: 0.78, darkOpacity: 0.74)
}

extension Color {
    /// A colour that follows the window's appearance.
    init(light: UInt32, dark: UInt32, lightOpacity: CGFloat = 1, darkOpacity: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: isDark ? darkOpacity : lightOpacity
            )
        })
    }

    init(hex: UInt32) {
        self.init(light: hex, dark: hex)
    }
}

/// The green of dimmela.app's hero: a vertical gradient lit from the top, deeper at the bottom
/// right.
struct HeroBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            LinearGradient(
                colors: isDark
                    ? [Color(hex: 0x0F3A22), Color(hex: 0x0B2A17), Color(hex: 0x061A0E)]
                    : [Color(hex: 0x74EE8E), Color(hex: 0x5EE079), Color(hex: 0x39C970)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(hex: isDark ? 0x1F8A48 : 0x8FF5A4), .clear],
                center: UnitPoint(x: 0.5, y: -0.1), startRadius: 0, endRadius: 460
            )
            RadialGradient(
                colors: [Color(hex: isDark ? 0x0F4A28 : 0x2FBF68), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 420
            )
        }
    }
}

/// A Mac key as dimmela.app draws it: a light cap with a soft shadow, pressed down and green
/// while `isPressed`.
struct KeyCap: View {
    let label: String
    var systemImage: String?
    var isPressed = false
    var scale: CGFloat = 1
    var minWidth: CGFloat = 44
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        HStack(spacing: 4 * scale) {
            Text(verbatim: label)
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11 * scale, weight: .semibold))
            }
        }
        .font(.system(size: 15 * scale, weight: .semibold))
        .foregroundStyle(isPressed ? Color(hex: 0x04220F) : Color(light: 0x3A3A3C, dark: 0xE5E5EA))
        .padding(.horizontal, 12 * scale)
        .frame(minWidth: minWidth * scale, minHeight: 40 * scale)
        .background {
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .fill(isPressed
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x8FF5A4), Color(hex: 0x5EE079)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(LinearGradient(
                        colors: isDark ? [Color(hex: 0x3A3A3C), Color(hex: 0x2C2C2E)] : [.white, Color(hex: 0xF4F4F6)],
                        startPoint: .top, endPoint: .bottom
                    )))
                .shadow(color: .black.opacity(isPressed ? 0.08 : (isDark ? 0.6 : 0.16)), radius: isPressed ? 1 : 3, y: isPressed ? 0.5 : 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                        .strokeBorder(isDark ? .white.opacity(0.08) : .black.opacity(0.12), lineWidth: 0.5)
                )
        }
        .offset(y: isPressed ? 2 * scale : 0)
        .accessibilityLabel(Text(verbatim: label))
    }
}

/// fn and space side by side, the shortcut every page talks about.
struct ShortcutKeys: View {
    var isPressed = false
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 8 * scale) {
            KeyCap(label: "fn", systemImage: "globe", isPressed: isPressed, scale: scale)
            KeyCap(label: "space", isPressed: isPressed, scale: scale, minWidth: 150)
        }
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isPressed)
    }
}

/// A page's title and the sentence under it, as dimmela.app's section heads.
struct PageHead: View {
    var eyebrow: String?
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            if let eyebrow {
                Text(eyebrow).font(.callout.weight(.semibold)).foregroundStyle(Brand.accent)
            }
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.8)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// An icon, a title and a sentence, as dimmela.app's "small things".
struct Tile: View {
    let systemImage: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(height: 22)
            Text(title).font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background.secondary))
    }
}
