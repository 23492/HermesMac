import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Platform type aliases

#if os(iOS)
/// Platform-native font type. Aliased so DesignSystem code can reference a
/// single symbol (`PlatformFont`) instead of branching between `UIFont` and
/// `NSFont` at every call site.
typealias PlatformFont = UIFont

/// Platform-native color type. Aliased so DesignSystem code can reference a
/// single symbol (`PlatformColor`) instead of branching between `UIColor`
/// and `NSColor` at every call site.
typealias PlatformColor = UIColor
#elseif os(macOS)
/// Platform-native font type. Aliased so DesignSystem code can reference a
/// single symbol (`PlatformFont`) instead of branching between `UIFont` and
/// `NSFont` at every call site.
typealias PlatformFont = NSFont

/// Platform-native color type. Aliased so DesignSystem code can reference a
/// single symbol (`PlatformColor`) instead of branching between `UIColor`
/// and `NSColor` at every call site.
typealias PlatformColor = NSColor
#endif
