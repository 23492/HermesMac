import Foundation
import SwiftData
import os

// MARK: - Versioned Schema

/// Baseline versioned schema (v1.0.0) wrapping the current
/// ``ConversationEntity`` and ``MessageEntity`` models.
///
/// Future schema changes add a `SchemaV2`, `SchemaV3`, etc. and the
/// corresponding lightweight/custom migration stages in
/// ``HermesMigrationPlan``.
public enum SchemaV1: VersionedSchema {
    /// Semantic version tag for this schema revision.
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    /// All persistent model types included in this schema version.
    public static var models: [any PersistentModel.Type] {
        [ConversationEntity.self, MessageEntity.self]
    }
}

// MARK: - Migration Plan

/// Migration plan that tells SwiftData how to move between schema
/// versions.
///
/// Currently contains only ``SchemaV1`` with no migration stages
/// (baseline). When a `SchemaV2` is introduced, add it to ``schemas``
/// and append the corresponding ``MigrationStage`` to ``stages``.
public enum HermesMigrationPlan: SchemaMigrationPlan {
    /// Ordered list of schema versions from oldest to newest.
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    /// Migration stages between consecutive schema versions.
    ///
    /// Empty for the baseline — there is nothing to migrate yet.
    public static var stages: [MigrationStage] {
        []
    }
}

// MARK: - ModelStack

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
    /// Uses ``SchemaV1`` and ``HermesMigrationPlan`` so that SwiftData
    /// can apply future migration stages automatically when the schema
    /// version advances.
    ///
    /// A failure here is always logged at ``OSLogType/fault`` level
    /// before the error is returned — persistence build failures are
    /// rare, unexpected and worth a `log show` trail for debugging.
    @MainActor
    private static func buildContainer() -> Result<ModelContainer, Error> {
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: HermesMigrationPlan.self,
                configurations: config
            )
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
    /// Uses the same ``SchemaV1`` / ``HermesMigrationPlan`` path as the
    /// on-disk container so that test and preview behaviour matches
    /// production.
    ///
    /// Never touches disk, so it cannot fail for the same reasons the
    /// shared on-disk container can; callers should still handle the
    /// `throws` in case the schema itself is ill-formed.
    @MainActor
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: HermesMigrationPlan.self,
            configurations: config
        )
    }
}
