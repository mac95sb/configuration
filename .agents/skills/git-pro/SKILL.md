---
name: git-pro
description: Git workflow guidance. Use when inspecting history, branches, diffs, remotes, conflicts, bisects, tags, submodules, or release/change management.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Git Pro

- Always inspect live state before advising or acting: `git status --short`, `git branch --show-current`, and relevant diffs/logs.
- Do not commit, push, reset hard, clean, rebase, or rewrite history unless the user explicitly asks.
- Preserve user changes. Distinguish staged, unstaged, untracked, ignored, and generated files.
- For reviews, cite `path:line` and use `git diff --stat`, targeted diffs, and history only as needed.
- For conflicts, understand both sides before resolving; avoid choosing ours/theirs blindly.
- Xcode `.xcodeproj` files are OpenStep property lists: when Xcode reports “not a valid property list” or “unresolved source control conflicts,” inspect `*.xcodeproj/project.pbxproj` directly. Search for conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) and malformed project syntax, but verify with `xcodebuild -list -project <Project>.xcodeproj` or `xcodebuild -project <Project>.xcodeproj -scheme <Scheme> -showBuildSettings`; generic `plutil -lint` may reject valid pbxproj header comments and is not the final authority. See `references/xcode-pbxproj-repair.md`.
- For bisect/debugging, keep steps reproducible and record good/bad commits and test command.
- Verify repository health after changes with status and the relevant tests/builds.
- After build/test verification, inspect whether generated artifacts changed. If build outputs are tracked or unignored (for example `.build/` in SwiftPM repos), report that noise separately and do not run cleanup/reset commands unless the user explicitly approves that destructive cleanup scope.
