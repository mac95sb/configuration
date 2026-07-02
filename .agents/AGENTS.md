# AGENTS.md

Guidance for AI coding agents working in this environment.

## Operating principles

- Start by understanding the current context. Inspect relevant files, recent changes,
  and project conventions before editing.
- Prefer small, focused changes that solve the requested problem without unrelated
  refactors or formatting churn.
- Preserve user work. Check version-control status before broad edits and avoid
  overwriting unrelated local modifications.
- Treat configuration, credentials, generated state, and automation entry points as
  sensitive. Do not add secrets, tokens, private keys, or machine-specific values to
  tracked files.
- Do not run destructive commands, package installs, bootstrap scripts, migrations,
  or mass file moves without explicit user approval.
- Do not commit changes, create branches, push, reset, clean, or rewrite history
  unless explicitly asked.
- Do not add tool attribution to commit messages or PR descriptions/comments (e.g.
  "Generated with Claude Code", "Co-Authored-By: Claude", "Co-authored-by: Codex",
  session links, or similar). Write commit messages and PR text as if authored
  directly by the user.

## Working with a repository

- Identify the repository root and read any local agent or contributor instructions
  before making changes.
- Trace symbols to their definitions and usages instead of guessing APIs, file
  layouts, or available dependencies.
- Match the project's existing style, structure, naming, and validation approach.
- Touch only the files required for the task. Avoid drive-by cleanup.
- Keep Markdown and developer documentation concise, task-oriented, and easy to scan.
- Use the narrowest safe tool for the change: targeted edits for existing files and
  full-file writes only for new files or deliberate rewrites.

## Agent skill management

- Keep shared skills compatible with Zed's skill format:
  - Each skill must be a direct child of a `skills/` directory.
  - Each skill directory must contain `SKILL.md`.
  - `SKILL.md` must start with YAML frontmatter containing `name` and `description`.
  - The frontmatter `name` should match the containing directory name.
- Avoid nested duplicate package copies such as `*/skills/<same-skill>/`.
- Keep detailed references, scripts, and templates inside the owning skill directory.
- Keep descriptions concise and actionable so agents can decide when to invoke a skill.
- When a reusable workflow is discovered, record it as a skill rather than burying it
  in session-specific notes.

## Editing guidelines

- For shell scripts, use POSIX-compatible syntax unless the file is clearly intended
  for a specific shell.
- Use shell-specific features only in files clearly scoped to that shell.
- Preserve valid structured data formats such as JSON, TOML, YAML, and plist files.
- Avoid removing user preferences or local configuration unless the user asks.
- Keep dependency, package-manager, and tool-version changes intentional and limited
  to what the task requires.

## Validation checklist

Use the narrowest validation appropriate for the change:

- Documentation: inspect the rendered structure or run the project's Markdown checks
  if available.
- Shell scripts: run the relevant shell syntax check when applicable.
- Structured configuration: parse or lint the touched files with the relevant tool.
- Skills: verify each changed `SKILL.md` has valid frontmatter and a matching `name`.
- Source changes: run the relevant formatter, linter, type check, test, or build.
- Git changes: inspect the diff and status before summarizing.
