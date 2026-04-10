import Testing
import Foundation
@testable import HermesMac

@Suite("KeychainStore")
struct KeychainStoreTests {

    @Test("write then read returns the same value")
    func writeAndRead() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("hello", forKey: key)
        #expect(store.getString(forKey: key) == "hello")
        try store.delete(forKey: key)
    }

    @Test("overwrite updates the value")
    func overwrite() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("first", forKey: key)
        try store.setString("second", forKey: key)
        #expect(store.getString(forKey: key) == "second")
        try store.delete(forKey: key)
    }

    @Test("delete removes the value")
    func delete() throws {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        let key = "testKey"
        try store.setString("gone soon", forKey: key)
        try store.delete(forKey: key)
        #expect(store.getString(forKey: key) == nil)
    }

    @Test("missing key returns nil")
    func missingKey() {
        let store = KeychainStore(service: "com.hermesmac.tests.\(UUID().uuidString)")
        #expect(store.getString(forKey: "nonexistent") == nil)
    }
}
