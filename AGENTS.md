# AGENTS.md

Guidance for AI coding agents working in this environment.

## Operating principles

- Always enable the `/i-have-adhd` skill at the start of each session.
- Start by understanding the current context. Inspect relevant files, recent changes,
  and project conventions before editing.
- Prefer small, focused changes that solve the requested problem without unrelated
  refactors or formatting churn.
- Make only the minimum change needed for the request. Ask before adding related
  features, documentation, automation, or cleanup that the user did not request.
- Preserve user work. Check version-control status before broad edits and avoid
  overwriting unrelated local modifications.
- Treat configuration, credentials, generated state, and automation entry points as
  sensitive. Do not add secrets, tokens, private keys, or machine-specific values to
  tracked files.
- Do not run destructive commands, package installs, bootstrap scripts, migrations,
  or mass file moves without explicit user approval.
- Beware of interactive pagers when running commands (`git log`, `git diff`, `man`,
  etc.) — agents can get stuck in them. Use non-interactive flags such as
  `git --no-pager` or set `PAGER=cat` in the environment.
- Do not commit changes, create branches, push, reset, clean, or rewrite history
  unless explicitly asked.
- Do not add tool attribution, co-author metadata, or session links to commit
  messages or PR descriptions/comments. Write them as if authored directly by the
  user.

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
