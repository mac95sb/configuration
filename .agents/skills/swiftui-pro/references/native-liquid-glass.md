# Native SwiftUI and Liquid Glass migration

Use this when modernizing SwiftUI app shells for iOS/macOS 26 Liquid Glass, especially sidebars, inspectors, tabs, and toolbars.

## Recommended migration pattern

1. Prefer native containers over custom chrome:
   - `NavigationSplitView` for primary app layout.
   - `.inspector(isPresented:)` for right-side inspectors, including a toolbar/sidebar control to show and hide it.
   - `TabView(selection:)` with `Tab(..., value:)` and `.tabViewStyle(.sidebarAdaptable)` for Xcode-like tabbed navigator/inspector rails and document tabs on macOS 26+.
   - `VSplitView`/split-view dividers for resizable bottom utility panels such as terminals/logs; avoid sliders for panel height.
   - Native `.toolbar` / `ToolbarItemGroup` for actions instead of custom horizontal bars.
2. Remove custom visual styling around system chrome unless there is a product requirement:
   - Avoid manual `.background(...)` on shell bars and tab content.
   - Avoid custom tab bars made from `ScrollView` + `HStack` + `RoundedRectangle` + `.buttonStyle(.plain)`.
   - Avoid custom gutter/strip colors for sidebars, tabs, and toolbar-like controls; let Liquid Glass/system materials render them.
3. Keep app-specific editor rendering separate from shell chrome. Syntax colors and text editor internals can remain custom, but the navigation/tab/sidebar/inspector shell should be system-native.
4. Prefer system presentation affordances:
   - Put toggles such as terminal/inspector visibility in toolbars where possible.
   - Use `ContentUnavailableView` and `LabeledContent` instead of hand-rolled empty states and metadata rows.
5. When deleting a custom SwiftUI view that was part of an Xcode project, remove both the source file and its `PBXBuildFile` / `PBXFileReference` / group / sources-build-phase entries from `project.pbxproj`.
6. After raising the app target to macOS/iOS 26 for Liquid Glass, ensure associated test targets use a compatible deployment target. A common failure is tests compiling for macOS 14 while `@testable import` targets a macOS 26 app module.

## Verification

- Build the app target with `xcodebuild -project <Project>.xcodeproj -scheme <Scheme> -configuration Debug -destination 'platform=macOS' build`.
- Run the test action too. If tests fail with a deployment-target import error, align the test target deployment target with the app target and re-run tests.

## Pitfalls

- Do not replace one custom style with another custom style during a Liquid Glass migration. The goal is usually to remove styling and let SwiftUI/system defaults take over.
- Do not keep dead custom shell files in the project after moving to native `TabView`/`Tab`; Xcode may continue compiling stale files until the project references are removed.
