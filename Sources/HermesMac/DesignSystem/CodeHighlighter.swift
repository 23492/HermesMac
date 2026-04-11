// `@preconcurrency` is required because Highlightr ships without Sendable
// annotations. All usage of `Highlightr` in this module is funneled through
// `@MainActor`-isolated entry points, so the lack of Sendability is safe:
// instances are never handed across actor boundaries. When Highlightr
// updates with proper concurrency annotations this attribute can be dropped.
@preconcurrency import Highlightr
import SwiftUI

/// Shared ``Highlightr`` instances for HermesMac code blocks.
///
/// `Highlightr` has no `Sendable` annotations; `@MainActor` isolation keeps
/// instances on a single actor which is also where SwiftUI view bodies run.
/// One instance per color scheme is reused across every code block in the
/// entire app — each `Highlightr` carries a `JSContext` that is roughly
/// 5 MB of resident memory, so building a new one per view is wasteful.
@MainActor
enum CodeHighlighter {

    /// Highlighter configured with the light theme (`github`), or `nil`
    /// when Highlightr cannot initialise (e.g. the bundled
    /// `highlight.min.js` resource is missing from the build).
    static let light: Highlightr? = make(theme: "github")

    /// Highlighter configured with the dark theme (`github-dark-dimmed`),
    /// or `nil` when Highlightr cannot initialise.
    static let dark: Highlightr? = make(theme: "github-dark-dimmed")

    /// Pick the correct singleton for a SwiftUI ``ColorScheme``.
    ///
    /// Returns `nil` when the underlying Highlightr instance failed to
    /// initialise. Callers are expected to fall back to plain text
    /// rendering in that case (see ``CodeBlockView``'s existing
    /// `?? NSAttributedString(string: code)` path).
    static func optionalInstance(for colorScheme: ColorScheme) -> Highlightr? {
        colorScheme == .dark ? dark : light
    }

    /// Pick the correct singleton for a SwiftUI ``ColorScheme``.
    ///
    /// This is the legacy non-optional accessor; it forwards to
    /// ``optionalInstance(for:)`` and, on the extremely rare failure
    /// path where Highlightr could not be constructed at all, traps
    /// with `fatalError`. The assertion inside ``make(theme:)`` has
    /// already fired at that point in debug builds.
    ///
    /// New code should prefer ``optionalInstance(for:)`` and render
    /// plain text when it returns `nil`; this non-optional variant is
    /// kept so existing callers continue to compile.
    static func instance(for colorScheme: ColorScheme) -> Highlightr {
        guard let highlightr = optionalInstance(for: colorScheme) else {
            // Reachable only when `Highlightr()` returned nil for the
            // requested theme, which indicates a broken bundle. The
            // `assertionFailure` in `make(theme:)` has already fired in
            // debug builds, so this message is primarily for release
            // crash reports.
            fatalError(
                "Highlightr unavailable for color scheme \(colorScheme); " +
                "check that bundled highlight.min.js is present."
            )
        }
        return highlightr
    }

    /// Build a `Highlightr` instance configured for the given theme name.
    ///
    /// Returns `nil` if Highlightr itself cannot be constructed (typically
    /// indicates a missing `highlight.min.js` resource at runtime). The
    /// failure is surfaced via `assertionFailure` in debug builds so it
    /// gets caught in development, but the function does **not** crash
    /// release builds — callers treat a `nil` highlighter as a signal to
    /// render the code as plain text.
    ///
    /// Intentionally does **not** call `setCodeFont`: the caller's SwiftUI
    /// `Text` view controls the font via `.font(...)`, which keeps Dynamic
    /// Type working. Forcing a fixed-size `PlatformFont` here would
    /// override the user's preferred text size.
    private static func make(theme name: String) -> Highlightr? {
        guard let highlightr = Highlightr() else {
            assertionFailure(
                "Highlightr init failed for theme \(name); " +
                "bundled highlight.min.js may be missing?"
            )
            return nil
        }
        _ = highlightr.setTheme(to: name)
        return highlightr
    }
}
