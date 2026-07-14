# Configuration

Personal macOS development environment configuration. This repository is the
source of truth for dotfiles, bootstrap repos, command-line tools, apps, macOS
defaults, and shared agent instructions.

The setup is managed primarily by [mise](https://mise.jdx.dev/). The mise config
tracks repositories under `~/Developer`, installs tooling and applications,
applies dotfile symlinks, and keeps agent skills installed through `skills.sh`
rather than committing third-party skill packages into this repo.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/mac95sb/configuration/main/setup.sh | sh
```

## Common Commands

```sh
mise bootstrap
mise run skills
mise tasks
```
