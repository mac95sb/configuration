# Xcode-style macOS editor shell

Use for native macOS editor/IDE shells that mimic Xcode-style navigation and inspection.

## Ownership model

- Left navigator: project-level workflows — file/project navigation, repository source control, project search, issues/warnings, tests, debug, reports, and bookmarks.
- Right inspector: active-file context — file information, per-file history, document symbols/outline, and Documentation / Quick Help from DocC, language comments, JSDoc, or LSP hover.
- Assistant/AI panels should not displace the file inspector rail by default. Prefer a separate assistant surface such as a bottom utility panel, command palette entry, dedicated assistant sidebar, or contextual popover.

## Implementation notes

- On macOS 26+ Liquid Glass shells, the outer layout should usually be `NavigationSplitView`, while navigator/inspector rail categories should use native `TabView(selection:)` with `Tab(..., value:)` and `.tabViewStyle(.sidebarAdaptable)` to get the Xcode-like sidebar tab affordance. Use `List`/`OutlineGroup` for the content inside a selected tab, not as a custom replacement for the native tab rail.
- Prefer `.inspector(isPresented:)` for the right inspector and provide a visible native toolbar/sidebar toggle for it.
- Persist rail selection independently, e.g. separate `@AppStorage` keys for left navigator and right inspector selection.
- Keep placeholder panels scoped to their future responsibility; avoid labeling project-wide Git or AI features as right-inspector tabs when the inspector is meant to be active-file scoped.
- Keep the center editor canvas clean: do not add new/close/show/hide buttons in the center by default; use commands, menu items, and appropriate toolbar/sidebar controls.
- For bottom utilities such as terminals/logs, use a native split-view divider (`VSplitView`) for resizing instead of a height slider.
- Add small real panels where cheap (for example, current tab/file metadata) so the shell communicates the intended ownership instead of only showing placeholders.

## Planning notes

- For sandboxed macOS editing, require a real `.app` target with bundle metadata and entitlements before file open/save acceptance work; do not rely indefinitely on a SwiftPM executable.
- If the codebase begins as a SwiftPM package, a practical direct-Xcode-project bridge is: create an `.xcodeproj` app target, add a local Swift package reference to `.`, depend on the package products needed by the app shell, and keep the SwiftPM executable/test baseline green. This avoids duplicating all library targets in the project file while still producing a real `.app` for entitlement-backed manual acceptance.
- For dual Xcode-app + SwiftPM baselines, prefer making the SwiftPM product a library target that excludes the app `@main` entry-point directory, while the Xcode app target owns `@main`, bundle metadata, entitlements, and commands. If SwiftPM tests report a package test-runner build cycle after adding the package manifest, split test targets by test folder instead of using one broad `path: "Tests"` target.
- Include an entitlements file early for the upcoming file-access slice, typically sandbox enabled plus `com.apple.security.files.user-selected.read-write` for `NSOpenPanel`/save-panel workflows.
- Verify both paths after adding the app bundle: `xcodebuild -list -project <App>.xcodeproj`, an explicit app target/scheme build such as `xcodebuild -project <App>.xcodeproj -target <App> -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`, and the existing `swift build && swift test` baseline.
- Watch for scheme-name ambiguity when the SwiftPM executable product and the Xcode app scheme share the same name; use explicit `-project` + `-target`/unambiguous scheme in automation.
- Prefer maintained Apple / SSWG / Swift language workgroup packages for non-editor infrastructure when they reduce custom maintenance burden.

- Prefer maintained Apple / SSWG / Swift language workgroup packages for non-editor infrastructure when they reduce custom maintenance burden.
