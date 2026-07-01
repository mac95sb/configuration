# Best-Practice Fallbacks

Use this file when no specialist skill covers the file type, or when the specialist skill lacks guidance for a specific pattern.

Instructions for the agent:
- Fetch the exact official docs page when uncertain.
- Prefer the "Editors Guide" or "API Reference" sections over blog posts.
- Keep findings concrete: file path, line, problem, and recommended fix with link.

## Swift (iOS/macOS)

- Modern API usage: https://developer.apple.com/swift/
- SwiftUI: https://developer.apple.com/documentation/swiftui
- SwiftData: https://developer.apple.com/documentation/swiftdata
- Concurrency (async/await, actors): https://developer.apple.com/documentation/swift/concurrency
- HIG and best practices: https://developer.apple.com/design/human-interface-guidelines/

## Python

- FastAPI: https://fastapi.tiangolo.com/
- Pydantic v2: https://docs.pydantic.dev/latest/
- SQLAlchemy 2.x: https://docs.sqlalchemy.org/en/20/
- Alembic migrations: https://alembic.sqlalchemy.org/en/latest/

## Vue

- Vue 3 composition API: https://vuejs.org/guide/introduction.html
- Vuetify: https://vuetifyjs.com/en/getting-started/installation/
- Pinia: https://pinia.vuejs.org/
- Vue Router: https://router.vuejs.org/

## Shell & Dotfiles

- POSIX sh: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
- Zsh: https://zsh.sourceforge.io/Doc/Release/
- Git: https://git-scm.com/doc
- Mise (tool version management): https://mise.jdx.dev/

## Data / Three.js

- Three.js: https://threejs.org/docs/

## Markdown / Docs

- Markdown guide (MDN): https://developer.mozilla.org/en-US/docs/Web/Markdown
- Prefer short, scannable docs and tables over prose.

## Operational Guidance

- If a rule contradicts the project's own style or `AGENTS.md`, follow the project's explicit rules.
- Do not upgrade dependencies, refactor unrelated modules, or change architecture to satisfy a doc link during this pass.
