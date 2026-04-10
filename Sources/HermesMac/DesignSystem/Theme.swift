import SwiftUI

// MARK: - Cross-platform system colors

public extension Color {

    /// The primary system background color, adapting to light/dark mode.
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
    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.5)
        #endif
    }

    /// A very light gray, matching iOS systemGray6.
    static var systemGray6: Color {
        #if os(iOS)
        Color(.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .quaternaryLabelColor).opacity(0.1)
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
public enum Theme {

    /// Background voor de hele app.
    public static var background: Color { .systemBackground }

    /// Background voor sidebars en secondaire panelen.
    public static var secondaryBackground: Color { .secondarySystemBackground }

    /// Background voor message bubbles (assistant).
    public static var assistantBubble: Color { .systemGray6 }

    /// Background voor message bubbles (user).
    public static var userBubble: Color { .accentColor }

    /// Foreground op user bubbles.
    public static var userBubbleText: Color { .white }

    /// Divider kleur.
    public static var divider: Color { .separator }

    /// Corner radius voor bubbles en kaarten.
    public static let bubbleCornerRadius: CGFloat = 16

    /// Default padding binnen bubbles.
    public static let bubblePadding: CGFloat = 12
}
