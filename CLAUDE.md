# CLAUDE.md

HubDrop is a macOS menu bar app that adds media to iOS and visionOS simulators by shelling out to `xcrun simctl addmedia`. Read `DESIGN.md` before changing anything. It records the architecture, the decisions already made, and the remaining work.

## Conventions

- Swift, SwiftUI for views, AppKit only where SwiftUI has no API (the status item and its drop target).
- 4-space indentation. PascalCase types, camelCase members. `@State private var` for view state.
- Use `os.Logger` for diagnostics, never `print()`.
- Model-View, not MVVM. Never name anything "ViewModel". The app model is `HubDropModel`.
- Avoid Combine. Use async/await.
- Swift 5 language mode with approachable concurrency and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Anything that must run off the main actor is marked `nonisolated` explicitly.
- Never add "Generated with Claude Code", "Co-Authored-By: Claude", or any other Claude attribution to commits or PR descriptions.
- Do not hand-edit `project.pbxproj` while Xcode has the project open. Use Xcode or the xcode-tools MCP build-setting tools.
