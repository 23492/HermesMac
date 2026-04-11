import Testing
import SwiftData
@testable import HermesMac

/// High-level sanity checks that the package is wired together correctly.
///
/// These tests are cheap and deliberately platform-agnostic — they run
/// on every CI machine and on every developer laptop in a fraction of
/// a second, so they can act as a canary when a task accidentally
/// breaks the build graph.
@Suite("Smoke")
@MainActor
struct SmokeTests {

    /// The in-memory model container must build without throwing and
    /// must own both app entities. Guards against schema typos and
    /// ModelStack helper regressions.
    @Test("in-memory model container builds with both entities")
    func modelStackBuildsInMemory() throws {
        let container = try ModelStack.makeInMemoryContainer()
        #expect(container.schema.entities.count >= 2)
    }

    /// The backend is always reached over TLS. Guards against a copy
    /// paste that would downgrade to plain HTTP — a meaningful
    /// security regression that would otherwise slip past code review.
    @Test("backend URL uses https")
    func backendURLUsesHTTPS() {
        #expect(BackendConfig.baseURL.scheme == "https")
    }
}
