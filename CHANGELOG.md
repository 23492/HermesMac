# Changelog

All notable changes to HermesMac are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-11

First usable release of HermesMac: a native SwiftUI client for macOS and
iOS that talks to a self-hosted Hermes Agent backend over the
OpenAI-compatible chat completions API, reachable through a Cloudflare
Tunnel at `https://hermes-api.knoppsmart.com/v1`. This release covers
tasks 00 through 16 — see `docs/TASKS/` for the individual specs. Task
17 (error states polish) and task 18 (release prep, this entry) are
tracked separately.

### Added

- **Project scaffold** — Swift 6 SwiftPM executable targeting macOS 14+
  and iOS 17+, strict concurrency enabled, single `HermesMac` target
  with `HermesMacTests` using Swift Testing (task 00).
- **Theme and cross-platform color helpers** — `Theme` enum and a small
  set of `Color` helpers that hide `#if os(iOS)` / `#if os(macOS)`
  branching behind a shared API so the views stay portable (task 01).
- **SSE line parser** — `SSELineStream` built on top of
  `URLSession.bytes.lines`, with full support for `data:` lines,
  multi-line data joining, comment filtering, the `[DONE]` sentinel,
  and leading-space stripping. Fully unit-tested (task 02).
- **HermesClient actor** — streaming chat completions and model listings
  against the Hermes backend, driven by `SSELineStream` and typed
  `HermesError` values. Bearer auth via the stored API key (task 03).
- **AppSettings + KeychainStore** — `@Observable` settings container
  with the backend URL hardcoded and the API key stored in the
  Keychain, never in `UserDefaults` (task 04).
- **SwiftData models** — `ConversationEntity` and `MessageEntity`
  `@Model` types plus a shared `ModelStack` / `ModelContainer` wired
  into the app from launch (task 06).
- **ConversationRepository** — `@MainActor` CRUD layer on top of
  `ModelContext` with cascade deletes and sensible sort orders for the
  sidebar (task 07).
- **ChatModel** — per-chat state holder that streams assistant replies
  through `HermesClient`, persists user and assistant messages via
  `ConversationRepository`, auto-titles new conversations, and exposes
  `send` / `cancel` / `regenerate` / `deleteMessage` (task 08).
- **Basic chat UI** — first working end-to-end experience: conversation
  list sidebar, chat view with streamed bubbles, and an input composer
  (task 09).
- **Markdown rendering** — assistant messages rendered through
  [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui)
  while user messages stay as plain text (task 10).
- **Syntax highlighting** — custom code block renderer backed by
  Highlightr for Swift and a monospaced fallback for other languages,
  matching the app's light/dark appearance (task 11).
- **Message actions** — per-message context menu with Copy (all
  messages), Delete (all messages), and Regenerate (assistant only),
  plus a shared `Clipboard` helper (task 12).
- **macOS shell** — `NavigationSplitView` layout with sidebar toggling,
  menu bar commands, and keyboard shortcuts for new chat / send / quit
  (task 13).
- **iOS shell** — `NavigationStack` on the conversation list, push
  navigation into the chat, swipe-back gesture, and haptic feedback on
  send (task 14).
- **SettingsView** — API key entry with secure text field, hardcoded
  backend URL shown as read-only info, "Test connection" action, and
  an About section with version + repository link (task 15).
- **Assets** — `Assets.xcassets` catalog with a 1024×1024 placeholder
  app icon, `AccentColor` set to Hermes blue `#1a73e8`, and a
  full-bleed SwiftUI `LaunchView` matching the icon. `Package.swift`
  processes the catalog via `resources: [.process("Resources")]`
  (task 16).
- **CHANGELOG.md** — this file, introduced as part of the v1.0.0
  release prep (task 18).
- **README updates** — Screenshots section with placeholder references,
  a Building section (`swift build -c release`, `swift run HermesMac`),
  and a GitHub Actions status badge (task 18).
- **GitHub Actions CI** — `.github/workflows/test.yml` runs
  `swift build` and `swift test` on `macos-14` for every push and pull
  request to `main` (task 18).

### Changed

- **Backend URL strategy** — dropped the dual-endpoint / race logic
  that was originally planned. HermesMac now always talks to
  `https://hermes-api.knoppsmart.com/v1` via the Cloudflare Tunnel, so
  there is a single code path for both home and away usage. Task 05
  (`EndpointSelector`) was cancelled as a result.
- **App executable bootstrap** — `HermesMac` now uses the `@main App`
  entry point so SwiftPM produces a launchable executable on macOS
  instead of the earlier placeholder shim.

### Fixed

- **ConversationRepositoryTests import** — added the missing
  `Foundation` import so the test target compiles cleanly on a cold
  checkout.

### Known issues

- `HermesClientTests.listModels decodes a valid response` fails with a
  spurious 401 under the current `MockURLProtocol` setup. Tracked in
  `docs/TASKS/99-followups.md` item #2. `swift test` therefore reports
  34/35 passing until that is fixed; this is not a regression in the
  v1.0.0 release and the CI workflow added by task 18 will stay red
  until the followup lands.
- Task 17 (error states and retry UX) is not included in v1.0.0. It
  will land in a follow-up release.

[1.0.0]: https://github.com/23492/HermesMac/releases/tag/v1.0.0
