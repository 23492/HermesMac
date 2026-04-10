# Task 00: Scaffold ✅ Done

**Status:** Niet gestart
**Dependencies:** none
**Estimated effort:** 20 min

## Doel

Zet de basis Swift package structuur op zodat `swift build` slaagt en er een minimale SwiftUI app is die op zowel iOS als macOS start met een placeholder view.

## Context

Dit is het fundament. Geen features, geen netwerk, geen persistence. Alleen genoeg om een Xcode project te kunnen openen en een window te zien. Alle volgende taken bouwen hierop.

## Scope

### In scope
- Package.swift met iOS 17 / macOS 14 targets, Swift 6 tools
- Basis directory structuur onder `Sources/HermesMac/`
- Een `@main` struct `HermesMacApp` met één placeholder `ContentView`
- `.gitignore` voor Swift/Xcode
- Lege `Tests/HermesMacTests/` directory met één dummy test zodat test target bestaat

### Niet in scope
- Netwerk code
- SwiftData
- Dependencies (MarkdownUI, Splash komen later)
- Styling beyond een `Text("HermesMac")`
- App icon

## Implementation

### Files to create

**`Package.swift`** (root):

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HermesMac",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HermesMac",
            targets: ["HermesMac"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HermesMac",
            path: "Sources/HermesMac",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HermesMacTests",
            dependencies: ["HermesMac"],
            path: "Tests/HermesMacTests"
        )
    ]
)
```

Let op: we maken een **library target**, niet executable. De iOS/macOS apps worden via Xcode (niet SwiftPM) gelanceerd, maar de library compileert op Linux wat handig is voor CI en voor testing.

**`Sources/HermesMac/App/HermesMacApp.swift`**:

```swift
import SwiftUI

public struct HermesMacApp: View {
    public init() {}

    public var body: some View {
        ContentView()
    }
}

public struct ContentView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("HermesMac")
                .font(.largeTitle.weight(.semibold))

            Text("Scaffolding in progress")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
```

**`Tests/HermesMacTests/SmokeTests.swift`**:

```swift
import Testing
@testable import HermesMac

@Test func smokeTestPackageBuilds() {
    // If this test runs, the package compiled successfully.
    #expect(true)
}
```

**`.gitignore`** (root):

```
# Xcode
*.xcodeproj/
*.xcworkspace/
xcuserdata/
DerivedData/
*.hmap
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# macOS
.DS_Store

# Editors
.vscode/
.idea/
*.swp
*.swo

# Secrets (never commit)
*.env
secrets.json
```

### Files to modify

None. This is a from-scratch scaffold.

## Verification

```bash
cd /root/HermesMac

# Build on Linux (SwiftUI code won't link UI but library should resolve)
swift build 2>&1
# Expected: On Linux, SwiftUI unavailable means build fails at import.
# That's OK for now — we verify structure via package resolve instead.

swift package resolve 2>&1
# Expected: Resolved dependencies (none currently).

swift package describe 2>&1 | head -20
# Expected: shows HermesMac library + HermesMacTests test target
```

If you're on a Mac:
```bash
swift build
# Expected: Build complete.

swift test
# Expected: 1 test passed (smokeTestPackageBuilds).
```

## Done when

- [ ] `Package.swift` exists with Swift 6 tools version
- [ ] Directory structure `Sources/HermesMac/App/` exists with `HermesMacApp.swift`
- [ ] `Tests/HermesMacTests/SmokeTests.swift` exists
- [ ] `.gitignore` covers Swift, Xcode, macOS
- [ ] `swift package describe` lists both targets without error
- [ ] Commit: `feat(task00): initial scaffold with Package.swift and placeholder view`

## Notes for the implementer

- De `public` modifiers op `HermesMacApp` en `ContentView` zijn nodig omdat ze in een library zitten die vanuit een Xcode app target geïnstantieerd wordt
- Als je een Mac hebt: probeer ook `swift test` te draaien om te verifiëren dat Swift Testing werkt
- Als `swift package describe` klaagt over Swift version: check dat je `swift --version` 6.0 of hoger is

## Completion notes

**Date:** 2026-04-10
**Commit:** 830b13a

Scaffold opgezet volgens spec. Package.swift met Swift 6 tools version, library target + test target. HermesMacApp.swift in Sources/HermesMac/App/ met ContentView placeholder. SmokeTests.swift in Tests/HermesMacTests/. Placeholder files verwijderd. .gitignore was al compleet.

Build niet geverifieerd op Linux (geen Swift toolchain), moet op Mac getest worden.
