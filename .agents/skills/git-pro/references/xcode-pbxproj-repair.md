# Xcode `.pbxproj` property-list repair

Use this when Xcode refuses to open a project with messages like:

- “The project `<Name>` is not a valid property list, and cannot be opened.”
- “Examine `<Name>.xcodeproj` for invalid content or unresolved source control conflicts.”

## Workflow

1. Preserve user changes first: check live git state (`git status --short`, branch) and note whether the `.xcodeproj/` is tracked or untracked.
2. Inspect the actual project file, usually `<Name>.xcodeproj/project.pbxproj`.
3. Search for merge-conflict markers:
   - `<<<<<<<`
   - `=======`
   - `>>>>>>>`
4. Also search for malformed OpenStep plist syntax introduced by generators or bad merges, especially around recently edited sections:
   - doubled object braces such as `= {{isa = ...; buildSettings = {{`
   - doubled closing braces such as `}}; name = Debug; }}`
   - missing semicolons after object assignments
5. Repair only the malformed project syntax. Avoid drive-by reformatting; pbxproj ordering and comments are significant for minimizing churn.
6. Validate with Xcode’s parser rather than relying only on generic plist tools:
   - `xcodebuild -list -project <Name>.xcodeproj`
   - if a scheme exists: `xcodebuild -project <Name>.xcodeproj -scheme <Scheme> -showBuildSettings`
7. Re-scan for conflict markers and malformed brace patterns after the edit.

## Important validation note

`project.pbxproj` is an OpenStep-style plist with Xcode-specific conventions. `plutil -lint` can emit confusing errors on pbxproj files (for example at the `// !$*UTF8*$!` header). Treat `xcodebuild -list` / `-showBuildSettings` as the practical authority for whether Xcode can open and parse the project.

## Example malformed pattern

Bad:

```pbxproj
00000000000000000000014F /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {{
    PRODUCT_NAME = "$(TARGET_NAME)";
}}; name = Debug; }}
```

Good:

```pbxproj
00000000000000000000014F /* Debug */ = {isa = XCBuildConfiguration; buildSettings = {
    PRODUCT_NAME = "$(TARGET_NAME)";
}; name = Debug; };
```
