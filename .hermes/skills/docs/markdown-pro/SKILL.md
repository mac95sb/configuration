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
- Run markdown lint/link checks if the project has them.
