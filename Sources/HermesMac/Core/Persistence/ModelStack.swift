import Foundation
import SwiftData

/// Factory for the app's SwiftData `ModelContainer`.
public enum ModelStack {

    /// Shared app container. Fatal error on failure — this is unrecoverable.
    @MainActor
    public static let shared: ModelContainer = {
        do {
            let schema = Schema([ConversationEntity.self, MessageEntity.self])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// In-memory container for previews and tests.
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
