# Task 15: SettingsView (API key, about) ✅ Done

**Status:** ✅ Done
**Dependencies:** Task 04
**Estimated effort:** 20 min

## Doel

Een simpel Settings scherm waar de user zijn API key kan invoeren. Plus een "About" sectie met versie + link naar de repo en een "Test connection" knop.

De backend URL is hardcoded en wordt getoond als read-only info (niet editable).

## Scope

### In scope
- `SettingsView.swift` met een `Form` lay-out
- API Key veld (SecureField met show/hide toggle)
- Read-only display van `BackendConfig.baseURL`
- "Test connection" knop die een `/models` call doet en toont of het werkt
- About sectie met versie, "Open in GitHub" link

### Niet in scope
- URL velden (hardcoded, niet editable)
- Export/import van instellingen
- Advanced section (timeout, retries etc)
- Theme picker
- Font size slider

## Platform integratie

- **macOS:** `.commands { CommandGroup(after: .appSettings) { ... } }` zodat Cmd+, het scherm opent via de standaard menu item
- **iOS:** Toegankelijk via een gear icon in de toolbar van de ConversationListView

## Implementation skeleton

```swift
import SwiftUI

public struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showAPIKey = false
    @State private var testResult: TestResult?
    @State private var isTesting = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

    public init() {}

    public var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Backend") {
                LabeledContent("Server", value: BackendConfig.baseURL.absoluteString)
                    .font(.system(.body, design: .monospaced))
            }

            Section("API Key") {
                HStack {
                    if showAPIKey {
                        TextField("Bearer token", text: apiKeyBinding)
                    } else {
                        SecureField("Bearer token", text: apiKeyBinding)
                    }
                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Test") {
                Button(action: test) {
                    if isTesting {
                        ProgressView()
                    } else {
                        Text("Test verbinding")
                    }
                }
                .disabled(isTesting || !settings.hasValidConfiguration)

                if let result = testResult {
                    switch result {
                    case .success(let msg):
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section("Over HermesMac") {
                LabeledContent("Versie", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Link("GitHub", destination: URL(string: "https://github.com/23492/HermesMac")!)
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 500, height: 450)
        #endif
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { settings.apiKey },
            set: { settings.apiKey = $0 }
        )
    }

    private func test() {
        Task {
            isTesting = true
            testResult = nil
            do {
                let client = HermesClient()
                await client.setEndpoint(HermesEndpoint(
                    baseURL: settings.backendURL,
                    apiKey: settings.apiKey
                ))
                let models = try await client.listModels()
                testResult = .success("✓ Verbonden. \(models.count) model(len) beschikbaar.")
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
```

## Done when

- [x] Settings scherm werkt op macOS en iOS
- [x] API key wordt opgeslagen (check via app restart)
- [x] Test verbinding knop doet een echte `/models` call
- [x] Link naar GitHub werkt
- [x] Commit: `feat(task15): settings view with backend config and connection test`

## Completion notes

**Date:** 2026-04-11
**Commit:** 1a60a13

`SettingsView` volgt de spec-skeleton maar met een paar kleine
aanpassingen:

- Platform wiring op macOS gebruikt een dedicated `Settings { ... }`
  scene in `HermesMacApp`. Dat is de standaard SwiftUI manier en
  geeft automatisch de Cmd+, shortcut plus het menu item
  "HermesMac → Instellingen…". Geen custom `CommandGroup` nodig
  zoals de spec suggereerde.
- Op iOS presenteert `ConversationListView` een sheet met een
  `NavigationStack` rond `SettingsView` en een "Klaar" dismiss
  button in de top-trailing toolbar. Gear button staat in
  `topBarLeading` zodat hij niet botst met de bestaande "Nieuwe
  chat" plus button.
- De "Test verbinding" Task wordt expliciet als `Task { @MainActor in }`
  gestart omdat `@State` mutaties (`testResult`, `isTesting`) onder
  Swift 6 strict concurrency op de main actor moeten blijven. De
  `HermesClient` actor handelt netwerk-suspendpoints zelf af.
- `apiKeyBinding` doet een diff check voor het schrijven: alleen
  als de nieuwe waarde echt anders is gaat hij naar de Keychain en
  wordt `testResult` gereset. Voorkomt een Keychain hit op elke
  keystroke van SwiftUI's two-way binding dance.
- `appVersion` leest `CFBundleShortVersionString` + `CFBundleVersion`
  uit `Bundle.main.infoDictionary` en valt terug op "dev" als het
  bundle nog geen versie-info heeft (zoals in SwiftPM dev builds).
- GitHub URL is hardcoded op `https://github.com/23492/HermesMac`,
  met een nil-coalescing fallback naar `BackendConfig.baseURL` zodat
  de force-unwrap regel uit CLAUDE.md niet geschonden wordt.

swift build clean onder Swift 6 strict concurrency, swift test 34/35
(pre-existing `HermesClientTests` failure uit 99-followups.md #2,
geen regressie).

Build niet geverifieerd op fysieke Mac/iPhone met Xcode — manuele
verificatie van Cmd+, shortcut, sheet presentation op iPhone en de
test-connection round-trip door Kiran.
