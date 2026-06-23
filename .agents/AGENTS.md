# AGENTS.md

Guidance for AI coding agents using this machine-wide configuration.

## Operating principles

- Be conservative with dotfiles and machine configuration. Changes can affect shells, editors, package managers, credentials, and future agent behavior.
- Prefer small, focused changes that preserve existing behavior.
- Do not add secrets, access tokens, private keys, or machine-specific credentials to tracked files.
- Do not run destructive bootstrap commands, package installs, or mass file moves without explicit user approval.
- Do not commit changes or create branches unless explicitly asked.

## Configuration repository

The canonical local configuration repository is expected at:

`~/Developer/configuration`

Important paths in that repository:

- `README.md` — human setup/bootstrap instructions.
- `Brewfile` — Homebrew bundle dependencies.
- `.zshrc` — interactive Zsh configuration.
- `.config/git/` — Git configuration and ignore rules.
- `.config/mise/config.toml` — mise tools, settings, dotfiles, and bootstrap tasks.
- `.config/zed/` — Zed editor settings and keymap.
- `.agents/` — canonical shared agent configuration.
- `.agents/skills/` — canonical local skill library in Zed-compatible flat layout.
- `.hermes/` — Hermes-specific profile/configuration only; skills are linked from `.agents/skills` during bootstrap.

## Agent skill management

- Treat `~/.agents/skills/` as the canonical installed skill root.
- Keep skills compatible with Zed's skill format:
  - Each skill must be a direct child of `skills/`.
  - Each skill directory must contain `SKILL.md`.
  - `SKILL.md` must start with YAML frontmatter containing `name` and `description`.
  - The frontmatter `name` should match the containing directory name.
- Avoid nested duplicate package copies such as `*/skills/<same-skill>/`.
- Keep detailed references, scripts, and templates inside the owning skill directory.
- Keep descriptions concise and actionable so agents can decide when to invoke a skill.

## Editing guidelines

- Check `git status` before broad edits and avoid overwriting unrelated local modifications.
- Use POSIX-compatible shell syntax for portable scripts unless a file is explicitly Zsh-specific.
- Use Zsh-specific features only in `.zshrc`, Zsh functions, or files clearly intended for Zsh.
- Keep Markdown concise and developer-oriented.
- For Zed settings, preserve valid JSON and avoid removing user preferences unless asked.
- For Homebrew changes, update `Brewfile` only when a package, cask, or tap is intentionally added or removed.

## Validation checklist

Use the narrowest validation appropriate for the change:

- Markdown/docs: inspect rendered structure or run a Markdown linter if available.
- Shell/Zsh changes: run `zsh -n .zshrc` for syntax when applicable.
- POSIX shell scripts: run `sh -n <script>`.
- Zed skills: verify each `.agents/skills/*/SKILL.md` has valid frontmatter and a matching `name`.
- Mise changes: run `mise config` or the relevant `mise run <task>`/`mise bootstrap --dry-run` check when safe.
- Git changes: use `git --no-pager diff` and `git --no-pager status --short` before summarizing.
