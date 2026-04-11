import SwiftUI

/// Settings pane with the bearer token field, a read-only backend URL
/// display, a "Test verbinding" button that actually hits `/models`,
/// and a small About section.
///
/// The backend URL itself is hardcoded (`BackendConfig.baseURL`) so it
/// is shown for confirmation only — there is no way to edit it from
/// the UI. See `docs/ARCHITECTURE.md` for the reasoning.
public struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showAPIKey = false
    @State private var testResult: TestResult?
    @State private var isTesting = false

    /// Reference to the in-flight "Test verbinding" Task so it can be
    /// cancelled when the settings pane disappears, or when the user
    /// triggers another test before the previous one finishes.
    @State private var testTask: Task<Void, Never>?

    /// Project repository URL for the About section.
    ///
    /// Hardcoded at compile time rather than computed at runtime — the
    /// literal is under our control and cannot become invalid, so we
    /// force-unwrap to remove the misleading nil-coalesce the previous
    /// revision used. Same pattern as ``BackendConfig/baseURL``.
    private static let repositoryURL = URL(string: "https://github.com/kiran/HermesMac")!

    /// Outcome of the last "Test verbinding" press. `nil` means the
    /// button has not been pressed (or has been pressed and is still
    /// in-flight — see `isTesting`).
    enum TestResult {
        case success(String)
        case failure(String)
    }

    public init() {}

    public var body: some View {
        Form {
            backendSection
            apiKeySection
            testSection
            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.title", defaultValue: "Instellingen"))
        #if os(macOS)
        .frame(width: 500, height: 480)
        #endif
        .onDisappear {
            testTask?.cancel()
            testTask = nil
        }
    }

    // MARK: - Sections

    private var backendSection: some View {
        Section(String(localized: "settings.section.backend", defaultValue: "Backend")) {
            LabeledContent(String(localized: "settings.backend.server", defaultValue: "Server"), value: BackendConfig.baseURL.absoluteString)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                Group {
                    if showAPIKey {
                        TextField(String(localized: "settings.apiKey.placeholder", defaultValue: "Bearer token"), text: apiKeyBinding)
                    } else {
                        SecureField(String(localized: "settings.apiKey.placeholder", defaultValue: "Bearer token"), text: apiKeyBinding)
                    }
                }
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .font(.system(.body, design: .monospaced))

                Button {
                    showAPIKey.toggle()
                } label: {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showAPIKey ? String(localized: "settings.apiKey.hide", defaultValue: "Verberg API key") : String(localized: "settings.apiKey.show", defaultValue: "Toon API key"))
            }
        } header: {
            Text(String(localized: "settings.section.apiKey", defaultValue: "API Key"))
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "settings.apiKey.footer", defaultValue: "Wordt veilig bewaard in de Keychain, niet in UserDefaults."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = settings.lastKeychainError {
                    Label(
                        localizedKeychainError(error),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private var testSection: some View {
        Section(String(localized: "settings.section.test", defaultValue: "Test")) {
            Button(action: runTest) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isTesting ? String(localized: "settings.test.inProgress", defaultValue: "Bezig met testen...") : String(localized: "settings.test.button", defaultValue: "Test verbinding"))
                }
            }
            .disabled(isTesting || !settings.hasValidConfiguration)

            if let result = testResult {
                resultLabel(result)
            }
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "settings.section.about", defaultValue: "Over HermesMac")) {
            LabeledContent(String(localized: "settings.about.version", defaultValue: "Versie"), value: appVersion)
            Link(destination: Self.repositoryURL) {
                Label(String(localized: "settings.about.github", defaultValue: "GitHub"), systemImage: "arrow.up.right.square")
            }
        }
    }

    // MARK: - Helpers

    /// Maps a ``KeychainError`` to a Dutch user-facing string.
    ///
    /// ``KeychainError/description`` is intentionally locale-neutral (English
    /// plus `SecCopyErrorMessageString` output) so the store layer stays
    /// presentation-agnostic. This helper lives in the view layer and produces
    /// the Dutch phrasing shown to the user in the settings pane.
    private func localizedKeychainError(_ error: KeychainError) -> String {
        switch error {
        case .itemNotFound:
            return String(localized: "settings.keychain.notFound", defaultValue: "API-sleutel niet gevonden in de Keychain.")
        case .interactionNotAllowed:
            return String(localized: "settings.keychain.blocked", defaultValue: "Keychain-toegang geblokkeerd. Herstart de app en probeer opnieuw.")
        case .missingEntitlement:
            return String(localized: "settings.keychain.missingEntitlement", defaultValue: "Keychain-toegang ontbreekt. Controleer de app-instellingen.")
        case .unexpectedStatus(let status):
            return String(localized: "settings.keychain.unexpectedStatus", defaultValue: "Onverwachte Keychain-fout (code \(Int(status))).")
        }
    }

    /// Two-way binding into the Keychain-backed ``AppSettings/apiKey``
    /// that only triggers a write when the value actually differs —
    /// avoids a Keychain hit on every keystroke of a read-modify-write.
    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { settings.apiKey },
            set: { newValue in
                if newValue != settings.apiKey {
                    settings.apiKey = newValue
                    testResult = nil
                }
            }
        )
    }

    private var appVersion: String {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return "dev"
        }
    }

    @ViewBuilder
    private func resultLabel(_ result: TestResult) -> some View {
        switch result {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Actions

    /// Perform a live `GET /models` call with the current credentials.
    ///
    /// The previous in-flight test task (if any) is cancelled before a
    /// new one starts so users can retry without fire-and-forget Task
    /// leaks. The task is also cancelled in `onDisappear` so the
    /// Settings pane can be torn down while a slow network probe is
    /// still in flight.
    ///
    /// ``CancellationError`` is swallowed silently — the user asked
    /// for it to stop, they do not need an error banner.
    ///
    /// Any `HermesError` is surfaced via its Dutch `errorDescription`
    /// so the user sees the same phrasing as everywhere else in the
    /// app; unexpected error types fall through to
    /// `error.localizedDescription`.
    private func runTest() {
        testTask?.cancel()
        isTesting = true
        testResult = nil
        let apiKey = settings.apiKey
        let baseURL = settings.backendURL
        testTask = Task { @MainActor in
            defer {
                isTesting = false
                testTask = nil
            }
            let client = HermesClient()
            let endpoint = HermesEndpoint(baseURL: baseURL, apiKey: apiKey)
            do {
                let models = try await client.listModels(endpoint: endpoint)
                try Task.checkCancellation()
                let count = models.count
                let countText = count == 1 ? "model" : "modellen"
                testResult = .success(
                    String(localized: "settings.test.success", defaultValue: "Verbonden. \(count) \(countText) beschikbaar.")
                )
            } catch is CancellationError {
                // User (or onDisappear) asked us to stop. Do not show
                // an error banner for an intentional cancel.
                testResult = nil
            } catch let hermesError as HermesError {
                testResult = .failure(
                    hermesError.errorDescription ?? "Onbekende fout"
                )
            } catch {
                testResult = .failure(error.localizedDescription)
            }
        }
    }
}
