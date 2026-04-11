import Foundation
import SwiftData
import os

/// Factory for the app's SwiftData `ModelContainer`.
///
/// Exposes two access paths:
///
/// - ``shared`` returns a `Result` so callers can surface a
///   recoverable error rather than crash when the on-disk store is
///   unreadable (e.g. corrupt file, schema mismatch mid-migration).
/// - ``makeInMemoryContainer()`` builds an isolated container for
///   tests and previews.
public enum ModelStack {

    /// Subsystem/category used for persistence-layer logging.
    private static let logger = Logger(
        subsystem: "com.hermes.mac",
        category: "modelstack"
    )

    /// Shared app container, lazily built on first access.
    ///
    /// Wrapped in `Result` so the caller (``LaunchView``) can render
    /// a recoverable error overlay instead of the process crashing via
    /// `fatalError` — a corrupt store on a user's machine should never
    /// be terminal without at least offering a "Probeer opnieuw" path.
    ///
    /// Note: this is `let` but re-evaluated on every app launch. After a
    /// failure the user can offer to retry via the overlay; the retry
    /// path calls ``rebuild()`` which rebuilds the container.
    @MainActor
    public static var shared: Result<ModelContainer, Error> {
        cached ?? rebuild()
    }

    /// Backing storage for ``shared`` so a successful build is not
    /// repeated on every access while still allowing ``rebuild()`` to
    /// re-run after a failed launch.
    @MainActor
    private static var cached: Result<ModelContainer, Error>?

    /// Force a fresh build attempt of the on-disk container.
    ///
    /// Used by the LaunchView retry button after a failed boot.
    @MainActor
    @discardableResult
    public static func rebuild() -> Result<ModelContainer, Error> {
        let result = buildContainer()
        cached = result
        return result
    }

    /// Actually build the on-disk ``ModelContainer``.
    ///
    /// A failure here is always logged at ``OSLogType/fault`` level
    /// before the error is returned — persistence build failures are
    /// rare, unexpected and worth a `log show` trail for debugging.
    @MainActor
    private static func buildContainer() -> Result<ModelContainer, Error> {
        do {
            let schema = Schema([ConversationEntity.self, MessageEntity.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            return .success(container)
        } catch {
            logger.fault(
                "ModelStack build failed: \(error.localizedDescription, privacy: .public)"
            )
            return .failure(error)
        }
    }

    /// In-memory container for previews and tests.
    ///
    /// Never touches disk, so it cannot fail for the same reasons the
    /// shared on-disk container can; callers should still handle the
    /// `throws` in case the schema itself is ill-formed.
    @MainActor
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ConversationEntity.self, MessageEntity.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
