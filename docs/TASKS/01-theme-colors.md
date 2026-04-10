# Task 01: Theme and cross-platform colors

**Status:** Niet gestart
**Dependencies:** Task 00
**Estimated effort:** 15 min

## Doel

Maak een `Theme` enum en cross-platform kleur helpers zodat views niet met `#if os(iOS)` / `#if os(macOS)` bezaaid worden voor basic system colors.

## Context

SwiftUI's `Color.systemBackground` en vrienden zijn iOS-only. Op macOS moet je `Color(nsColor: .windowBackgroundColor)` gebruiken. Dit is een klassieke papercut. We vangen het één keer netjes af in een centrale file.

## Scope

### In scope
- `Sources/HermesMac/DesignSystem/Theme.swift` met:
  - Cross-platform `Color` extensions: `systemBackground`, `secondarySystemBackground`, `systemGray6`, `separator`
  - Een `Theme` namespace enum met semantic colors (voor later gebruik)
- Tests? Nee, dit is puur visual glue code

### Niet in scope
- Light/dark mode switching (dat werkt automatisch via SwiftUI)
- Custom tints of branding kleuren
- Iconografie

## Implementation

**`Sources/HermesMac/DesignSystem/Theme.swift`**:

```swift
import SwiftUI

// MARK: - Cross-platform system colors

public extension Color {

    static var systemBackground: Color {
        #if os(iOS)
        Color(.systemBackground)
        #elseif os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.gray
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #elseif os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.gray.opacity(0.5)
        #endif
    }

    static var systemGray6: Color {
        #if os(iOS)
        Color(.systemGray6)
        #elseif os(macOS)
        Color(nsColor: .quaternaryLabelColor).opacity(0.1)
        #else
        Color.gray.opacity(0.1)
        #endif
    }

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

public enum Theme {

    /// Background voor de hele app
    public static var background: Color { .systemBackground }

    /// Background voor sidebars en secondaire panelen
    public static var secondaryBackground: Color { .secondarySystemBackground }

    /// Background voor message bubbles (assistant)
    public static var assistantBubble: Color { .systemGray6 }

    /// Background voor message bubbles (user)
    public static var userBubble: Color { .accentColor }

    /// Foreground op user bubbles
    public static var userBubbleText: Color { .white }

    /// Divider kleur
    public static var divider: Color { .separator }

    /// Corner radius voor bubbles en kaarten
    public static let bubbleCornerRadius: CGFloat = 16

    /// Default padding binnen bubbles
    public static let bubblePadding: CGFloat = 12
}
```

## Verification

```bash
cd /root/HermesMac
swift build 2>&1 | tail -10
```

## Done when

- [ ] `Sources/HermesMac/DesignSystem/Theme.swift` bestaat
- [ ] Package bouwt nog steeds
- [ ] Commit: `feat(task01): add Theme and cross-platform color helpers`
