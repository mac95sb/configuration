---
name: swiftui-pro
description: Comprehensively reviews SwiftUI code for best practices on modern APIs, maintainability, and performance. Use when reading, writing, or reviewing SwiftUI projects.
license: MIT
metadata:
  author: Paul Hudson
  version: "1.1"
---

Review Swift and SwiftUI code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems - do not nitpick or invent issues.

Review process:

1. Check for deprecated API using `references/api.md`.
1. Check that views, modifiers, and animations have been written optimally using `references/views.md`.
1. Validate that data flow is configured correctly using `references/data.md`.
1. Ensure navigation is updated and performant using `references/navigation.md`.
1. For iOS/macOS 26 app-shell modernization, check `references/native-liquid-glass.md` and prefer native SwiftUI containers, tabs, inspectors, and toolbars over custom chrome.
1. Ensure the code uses designs that are accessible and compliant with Apple’s Human Interface Guidelines using `references/design.md`.
1. Validate accessibility compliance including Dynamic Type, VoiceOver, and Reduce Motion using `references/accessibility.md`.
1. Ensure the code is able to run efficiently using `references/performance.md`.
1. Quick validation of Swift code using `references/swift.md`.
1. Final code hygiene check using `references/hygiene.md`.

If doing a partial review, load only the relevant reference files.


## Core Instructions

- iOS 26 exists, and is the default deployment target for new apps.
- Target Swift 6.2 or later, using modern Swift concurrency.
- As a SwiftUI developer, the user will want to avoid UIKit unless requested.
- Do not introduce third-party frameworks without asking first.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Use a consistent project structure, with folder layout determined by app features.

## User-specific SwiftUI workflow preferences

- When building or resetting app shell UI for this user, start from the simplest native SwiftUI structure and only add behavior after the base layout is visually sound. If requested to "reset" or "zero implementation," remove feature UI and leave a blank SwiftUI app shell rather than preserving scaffolding.
- For macOS 26 Xcode-like editor shells, use `NavigationSplitView` for the primary app layout, but use native `TabView(selection:)` with `Tab(..., value:)` and `.tabViewStyle(.sidebarAdaptable)` inside navigator/inspector rails when the goal is the Xcode/Liquid Glass tabbed sidebar affordance. Use `List(selection:)` for hierarchical content within a selected tab, not as a replacement for the native sidebar tab rail.
- Use `TabView` for native sidebar/inspector tab rails and real document/workspace tabs. Do not build custom tab rails from `List`, segmented controls, `ScrollView` + `HStack`, overlays, or hand-styled buttons unless explicitly requested.
- For macOS editor centers, keep the center canvas minimal: avoid new/close/show/hide buttons in the editor area unless the user asks for in-canvas controls; prefer commands and appropriate toolbar/sidebar controls.
- Use `.sheet` with `presentationDetents` for native slide-up panels. Use `VSplitView`/split-view dividers for resizable bottom utility panels such as terminals/logs; do not use a slider for panel height.
- Avoid forcing sidebar/detail geometry with competing `.frame(minWidth:)` and large column widths. Let `NavigationSplitView` and `.inspector(isPresented:)` own column layout, bound column widths conservatively, and make detail content adapt or scroll so resizing a sidebar cannot push content half off-screen.

## Native SwiftUI shell/navigation guidance

When modernizing an Apple app shell toward native SwiftUI/Liquid Glass, avoid hand-rolled chrome and avoid forcing the wrong native control into the wrong role:

- Use `NavigationSplitView` for app sidebars and inspector/sidebar columns. Put sidebar destinations in native `List(selection:)` rows/sections, not a `TabView` pretending to be a sidebar.
- Use `TabView` for real document/content tabs, not for navigator or inspector sidebars.
- Use `.sheet(...)` with `presentationDetents(...)` for native slide-up panels such as terminals, logs, and transient drawers.
- Use a custom `.overlay(alignment: .bottom)` only when the panel must be always-visible, highly custom, or not representable as a native sheet.
- If the user calls a UI “janky,” prefer removing custom styling/layout and returning to native containers before polishing details.
- For Xcode verification after shell/layout changes, run a build first. If tests fail from stale DerivedData signing state after prior builds, retry with `xcodebuild ... clean test` and report that the clean resolved stale signing artifacts.


## Output Format

Organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated (e.g., "Use `foregroundStyle()` instead of `foregroundColor()`").
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.

Example output:

### ContentView.swift

**Line 12: Use `foregroundStyle()` instead of `foregroundColor()`.**

```swift
// Before
Text("Hello").foregroundColor(.red)

// After
Text("Hello").foregroundStyle(.red)
```

**Line 24: Icon-only button is bad for VoiceOver - add a text label.**

```swift
// Before
Button(action: addUser) {
    Image(systemName: "plus")
}

// After
Button("Add User", systemImage: "plus", action: addUser)
```

**Line 31: Avoid `Binding(get:set:)` in view body - use `@State` with `onChange()` instead.**

```swift
// Before
TextField("Username", text: Binding(
    get: { model.username },
    set: { model.username = $0; model.save() }
))

// After
TextField("Username", text: $model.username)
    .onChange(of: model.username) {
        model.save()
    }
```

### Summary

1. **Accessibility (high):** The add button on line 24 is invisible to VoiceOver.
2. **Deprecated API (medium):** `foregroundColor()` on line 12 should be `foregroundStyle()`.
3. **Data flow (medium):** The manual binding on line 31 is fragile and harder to maintain.

End of example.


## References

- `references/accessibility.md` - Dynamic Type, VoiceOver, Reduce Motion, and other accessibility requirements.
- `references/api.md` - updating code for modern API, and the deprecated code it replaces.
- `references/design.md` - guidance for building accessible apps that meet Apple’s Human Interface Guidelines.
- `references/hygiene.md` - making code compile cleanly and be maintainable in the long term.
- `references/native-liquid-glass.md` - native SwiftUI/Liquid Glass migration guidance for sidebars, inspectors, tabs, toolbars, and related Xcode deployment-target verification.
- `references/navigation.md` - navigation using `NavigationStack`/`NavigationSplitView`, plus alerts, confirmation dialogs, and sheets.
- `references/performance.md` - optimizing SwiftUI code for maximum performance.
- `references/data.md` - data flow, shared state, and property wrappers.
- `references/swift.md` - tips on writing modern Swift code, including using Swift Concurrency effectively.
- `references/views.md` - view structure, composition, and animation.
