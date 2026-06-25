---
name: zed-pro
description: Zed editor configuration guidance. Use when editing Zed settings, keymaps, agent servers, extensions, language settings, themes, or JSONC-style configuration.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Zed Pro

- Inspect existing `settings.json`, `keymap.json`, installed extensions, and nearby editor configuration before editing.
- Zed settings are JSONC-like and commonly include trailing commas; preserve existing formatting conventions instead of rewriting the whole file.
- For `agent_servers`, verify command/args shape against adjacent entries and avoid removing user preferences while adjusting a single server.
- Validate structural correctness after edits with a JSONC-tolerant parse (strip comments/trailing commas before `json.loads`, or use a project-provided JSONC validator when available).
- Keep changes narrow: editor settings are personal workflow configuration, so avoid broad reformatting or preference churn.
