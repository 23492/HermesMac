import SwiftUI

// MARK: - Cross-platform system colors
//
// These `Color` extensions are plain accessors over SwiftUI.Color, which is
// `Sendable` on iOS 17+ / macOS 14+. No main-actor isolation is required;
// the getters are pure functions over platform constants and can be read
// from any isolation domain under `SWIFT_STRICT_CONCURRENCY=complete`.
//
// No asset catalogs are used. Each accessor wraps a semantic platform color
// directly:
//
//   macOS fallback chain:
//     systemBackground        → NSColor.windowBackgroundColor
//     secondarySystemBackground → NSColor.controlBackgroundColor
//     systemGray6              → NSColor.underPageBackgroundColor
//     separator                → NSColor.separatorColor
//
//   iOS fallback chain:
//     systemBackground        → UIColor.systemBackground
//     secondarySystemBackground → UIColor.secondarySystemBackground
//     systemGray6              → UIColor.systemGray6
//     separator                → UIColor.separator
//
//   Other platforms: plain `Color.gray` variants so the module still compiles.

public extension Color {

    /// The primary system background color, adapting to light/dark mode.
    ///
    /// On iOS this maps to `UIColor.systemBackground`; on macOS it maps to
    /// `NSColor.windowBackgroundColor`. On other platforms it falls back
    /// to a plain gray so the DesignSystem keeps compiling.
    static var systemBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.gray
        #endif
    }

    /// A secondary system background color for grouped or inset content.
    ///
    /// On iOS this maps to `UIColor.secondarySystemBackground`; on macOS
    /// it maps to `NSColor.controlBackgroundColor`, the AppKit analog for
    /// grouped content surfaces.
    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.5)
        #endif
    }

    /// A very light gray, matching iOS `UIColor.systemGray6`.
    ///
    /// On macOS this resolves to `NSColor.underPageBackgroundColor`,
    /// AppKit's closest visual analog for the tinted surface iOS uses
    /// behind grouped content. The previous fallback based on
    /// `.quaternaryLabelColor.opacity(0.1)` rendered nearly transparent,
    /// which defeated the purpose of having a distinct bubble
    /// background.
    static var systemGray6: Color {
        #if os(iOS)
        Color(.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

    /// The system separator color for dividers and borders.
    static var separator: Color {
        #if os(iOS)
        Color(.separator)
        #elseif os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color.gray.opacity(0.3)
        #endif
    }
}

// MARK: - Contrast-aware text color

public extension Color {

    /// Returns `.black` or `.white` depending on which provides better contrast
    /// against the given background color, per WCAG relative luminance guidelines.
    ///
    /// Uses the WCAG 2.x luminance threshold of 0.179: backgrounds with relative
    /// luminance above this value are considered "light" and get black text;
    /// backgrounds at or below get white text.
    ///
    /// - Parameter background: The background color to check contrast against.
    /// - Returns: `.black` for light backgrounds, `.white` for dark backgrounds.
    static func contrastingText(against background: Color) -> Color {
        let luminance = background.relativeLuminance
        return luminance > 0.179 ? .black : .white
    }

    /// The WCAG 2.x relative luminance of this color.
    ///
    /// Computed by converting sRGB components through the standard linearization
    /// formula, then weighting R/G/B per the WCAG spec:
    /// `L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin`
    ///
    /// Falls back to 0.0 (assumed dark) when the color cannot be resolved to
    /// sRGB components, which avoids a force-unwrap on platforms where color
    /// space conversion may fail.
    private var relativeLuminance: Double {
        #if os(macOS)
        guard let srgb = NSColor(self).usingColorSpace(.sRGB) else {
            return 0.0
        }
        let r = Double(srgb.redComponent)
        let g = Double(srgb.greenComponent)
        let b = Double(srgb.blueComponent)
        #elseif os(iOS)
        var cr: CGFloat = 0
        var cg: CGFloat = 0
        var cb: CGFloat = 0
        var ca: CGFloat = 0
        UIColor(self).getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        let r = Double(cr)
        let g = Double(cg)
        let b = Double(cb)
        #else
        // Fallback: assume dark background so we return white text.
        return 0.0
        #endif

        func linearize(_ channel: Double) -> Double {
            channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(r)
             + 0.7152 * linearize(g)
             + 0.0722 * linearize(b)
    }
}

// MARK: - Theme namespace

/// Semantic design tokens for HermesMac UI.
///
/// Pure namespace over SwiftUI `Color` accessors and compile-time layout
/// constants. No mutable state, no actor isolation: the compile-time
/// constants (`bubbleCornerRadius`, `bubblePadding`) are literal `CGFloat`
/// values and the color getters forward to the platform-specific `Color`
/// accessors above, both of which are safe under
/// `SWIFT_STRICT_CONCURRENCY=complete`.
public enum Theme {

    // MARK: - Color tokens

    /// Background for the entire app shell.
    public static var background: Color { .systemBackground }

    /// Background for sidebars and secondary panels.
    public static var secondaryBackground: Color { .secondarySystemBackground }

    /// Background for assistant message bubbles.
    public static var assistantBubble: Color { .systemGray6 }

    /// Background for user message bubbles.
    public static var userBubble: Color { .accentColor }

    /// Foreground text color on user bubbles.
    ///
    /// Contrast-aware: computes WCAG relative luminance of `.accentColor`
    /// and returns `.black` (light accent) or `.white` (dark accent).
    public static var userBubbleText: Color {
        .contrastingText(against: .accentColor)
    }

    /// Divider color for rules and borders.
    public static var divider: Color { .separator }

    // MARK: - Layout constants

    /// Corner radius for bubbles and cards.
    public static let bubbleCornerRadius: CGFloat = 16

    /// Default padding inside bubbles.
    public static let bubblePadding: CGFloat = 12
}
