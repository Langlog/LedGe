import AppKit
import SwiftUI

enum LedgeStyle {
    static let accent = Color(
        red: 31 / 255,
        green: 178 / 255,
        blue: 126 / 255
    )
    static let accentInk = Color(
        nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(
                from: [.darkAqua, .aqua]
            ) == .darkAqua
            return isDark
                ? NSColor(
                    srgbRed: 88 / 255,
                    green: 224 / 255,
                    blue: 174 / 255,
                    alpha: 1
                )
                : NSColor(
                    srgbRed: 0 / 255,
                    green: 112 / 255,
                    blue: 75 / 255,
                    alpha: 1
                )
        }
    )
    static let accentSoft = accent.opacity(0.14)
    static let ink = Color(nsColor: .labelColor)
    static let secondaryInk = Color(nsColor: .secondaryLabelColor)
    static let hairline = Color(nsColor: .separatorColor).opacity(0.72)
    static let controlFill = Color(nsColor: .labelColor).opacity(0.065)
    static let cardSurface = Color(nsColor: .controlBackgroundColor)
        .opacity(0.76)
    static let editorSurface = Color(nsColor: .textBackgroundColor)
        .opacity(0.62)
    static let panelRadius: CGFloat = 22
}

struct PanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThickMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: LedgeStyle.panelRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: LedgeStyle.panelRadius,
                    style: .continuous
                )
                .stroke(LedgeStyle.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.10), radius: 24, y: 10)
            .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
    }
}

extension View {
    func ledgePanelSurface() -> some View {
        modifier(PanelSurface())
    }
}
