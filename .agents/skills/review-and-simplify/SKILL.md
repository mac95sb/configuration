---
name: review-and-simplify
description: Combined simplification and best-practice audit of recently changed code. Use when the user asks to review, simplify, refactor, clean up, or inspect staged/uncommitted changes across Swift, Python (FastAPI, SQLAlchemy, Pydantic), Vue, Zsh, POSIX shell, Git, or Mise. Delegates to the repository's specialist skills when available and falls back to official docs when needed.
model: sonnet
---

# Review and Simplify

Simplify recently changed code and check it against current best practices for the project's frameworks and tools.

## Workflow

1. **Scope the changes**
   - Prefer `git diff --cached` + `git diff` for the current branch against the checked-out HEAD.
   - If the user names a base (e.g. `review against main`), use `git diff <base>..HEAD`.
   - If the change set is large, group by extension or directory before reviewing.

2. **Identify the domain per file**
   - `*.swift` — delegate to `ios-code-audit`, `swiftui-pro`, `swift-concurrency-pro`, `swiftdata-pro` as relevant.
   - `*.py` — delegate to `python-api-pro`.
   - `*.vue` / `*.tsx` / front-end TS — delegate to `vue-app-pro`.
   - `*.sh` / install scripts — delegate to `posix-shell-pro`.
   - `.zshrc` / `*.zsh` — delegate to `zsh-pro`.
   - `.gitconfig` / Git workflows — delegate to `git-pro`.
   - `mise.toml` / `.mise.toml` — delegate to `mise-pro`.
   - `.config/zed/settings.json` — delegate to `zed-pro`.
   - `.hermes/config.yaml` — delegate to `mise-pro` for Hermes-specific config rules.
   - Markdown / dotfiles — follow concise Markdown and POSIX conventions; consult `markdown-pro` for doc formatting.

3. **Simplify**
   - Preserve exact functionality; only refactor how.
   - Reduce unnecessary nesting, dead code, duplication, and redundant abstractions.
   - Rename for clarity and consolidate related logic.
   - Prefer explicit over clever. Avoid nested ternaries, dense one-liners, and premature compression.
   - Do not remove useful abstractions or reorder unrelated logic.

4. **Audit best practices**
   - Let the relevant specialist skill lead. Read it before editing the target files.
   - If no specialist skill covers a file type, fall back to `references/best-practices.md`.
   - Report issues as concrete patches or edit instructions, not vague advice.

5. **Stay scoped**
   - Do not reformat whitespace outside touched symbols.
   - Do not rewrite unrelated files.
   - Do not remove policies, credentials, or user preferences.

## Output

- A unified patch or `file:line`-cited review with two sections:
  1. **Simplifications** — what changed and why.
  2. **Best Practice Review** — framework-specific findings with docs links.
- A `No issues` note if the diff is already clean.

## References

- `references/best-practices.md` — doc links and lightweight fallback checks.
