---
name: markdown-pro
description: Markdown writing and maintenance guidance. Use when editing READMEs, docs, changelogs, API docs, runbooks, or Markdown generated for developers.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Markdown Pro

- Match the repository’s existing Markdown flavor, heading style, line length, and lint rules.
- Keep docs task-oriented: prerequisites, commands, expected output, troubleshooting, and links to source of truth.
- Use relative links for repo-local files and verify anchors/paths when possible.
- Fence code blocks with language identifiers; mark shell snippets clearly and avoid prompting users to paste secrets.
- Prefer concise tables and lists; avoid overly deep heading nesting.
- For changelogs/release notes, separate user-facing changes from internal implementation details.
- When rectifying project notes against an implementation plan, convert rough TODO notes into explicit accepted decisions, update the plan where the decision changes sequencing or scope, and mark the original notes as addressed rather than leaving duplicate unresolved TODOs.
- If the user references “suggested changes” without restating them, first inspect repo-local notes/TODO docs (for example `NOTES.md`, `TODO.md`, and the active plan) before asking for clarification; treat those notes as the likely source of requested edits.
- When docs updates are paired with source changes, keep the plan and source code aligned in the same pass and verify with the project’s normal build/test command before reporting completion.
- Run markdown lint/link checks if the project has them.
