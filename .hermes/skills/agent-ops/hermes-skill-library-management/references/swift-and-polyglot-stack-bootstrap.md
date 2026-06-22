# Swift and polyglot stack bootstrap example

This note captures a reusable pattern from a local skill-library setup session.

## User request shape

The user wanted Hermes configured as a coding assistant for:

- Swift / Apple platform projects, using curated skills from `https://github.com/twostraws/Swift-Agent-Skills`.
- Python APIs: FastAPI, SQLAlchemy, Alembic, Pydantic.
- Vue apps: Pinia, Stripe, Auth0, i18n, Vuetify, Three.js.
- Vim 9, Zsh, Markdown, POSIX shell, Git, and Mise.

## Useful approach

1. Use the curated Swift directory as a discovery index, not as a blind install source.
2. Select class-level Swift/Apple capabilities that cover recurring work:
   - SwiftUI
   - SwiftData
   - Swift Concurrency
   - Swift Testing
   - Swift architecture
   - iOS accessibility
   - App Intents
   - Core Data
   - Swift/iOS security
   - iOS simulator automation
   - iOS code audits
3. Preserve high-value supporting files for script-heavy or reference-heavy skills.
4. For ecosystems without a trusted single umbrella skill, create local class-level stack skills:
   - `python-api-pro` for FastAPI + SQLAlchemy + Alembic + Pydantic.
   - `vue-app-pro` for Vue 3 + Pinia + Auth0 + Stripe + i18n + Vuetify + Three.js.
   - Small but class-level workflow skills for Vim 9, Zsh, Markdown, POSIX shell, Git, and Mise.
5. Verify by listing the library and loading at least one custom and one third-party skill.
6. If the user's stack is stable and recurring, save a compact user memory of the stack.

## Provenance note pattern

For copied third-party skills, add `references/SOURCE.md` containing:

```md
Installed from curated Swift-Agent-Skills list: https://github.com/twostraws/Swift-Agent-Skills
Review each third-party repository license before redistribution.
```

## Pitfalls

- Do not flatten stack preferences into dozens of tiny library-only skills.
- Do not copy `.git`, `.github`, caches, or upstream test suites unless they are operationally needed.
- Do not treat a failed attempt to load a missing built-in helper skill as a durable tool failure.
