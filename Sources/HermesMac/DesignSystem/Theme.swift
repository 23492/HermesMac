import SwiftUI

// MARK: - Cross-platform system colors
//
// These `Color` extensions are plain accessors over SwiftUI.Color, which is
// `Sendable` on iOS 17+ / macOS 14+. No main-actor isolation is required;
// the getters are pure functions over platform constants and can be read
// from any isolation domain under `SWIFT_STRICT_CONCURRENCY=complete`.

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
    /// Note: currently hard-coded to white, which assumes a blue-ish
    /// accent color. See followup #7 for a contrast-aware variant.
    public static var userBubbleText: Color { .white }

    /// Divider color for rules and borders.
    public static var divider: Color { .separator }

    // MARK: - Layout constants

    /// Corner radius for bubbles and cards.
    public static let bubbleCornerRadius: CGFloat = 16

    /// Default padding inside bubbles.
    public static let bubblePadding: CGFloat = 12
}
