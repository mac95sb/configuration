---
name: hermes-skill-library-management
description: Manage the local Hermes skill library as a class-level, curated capability set. Use when installing, creating, updating, auditing, or organizing Hermes skills for a user's recurring coding stacks and workflows.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Hermes Skill Library Management

Use this skill when the user asks to set up, expand, review, or curate the local Hermes skill library.

## Goals

- Prefer class-level umbrella skills over a long flat list of narrow one-session skills.
- Keep each `SKILL.md` rich enough to be useful on its own.
- Put session-specific detail, source notes, copied research, and operational recipes in `references/`.
- Use `templates/` for starter files and `scripts/` for deterministic actions future agents should run rather than retype.
- Treat third-party skills as code/content to inspect before copying or installing.

## Workflow

1. Inspect the existing library first with `skills_list`, then load likely umbrellas with `skill_view`.
2. If a currently loaded or existing umbrella covers the new learning, patch it instead of creating another narrow skill.
3. Create a new skill only when no class-level umbrella fits. The name should describe a reusable class of work, not today's task, PR, error string, or feature codename.
4. For third-party skills, review source, license, structure, and supporting files before installing or copying.
5. Preserve useful supporting files under allowed skill subdirectories:
   - `references/` for notes, source provenance, condensed docs, troubleshooting, or session detail.
   - `templates/` for copy-and-modify starter files.
   - `scripts/` for re-runnable verification/probing/automation.
6. Add a short pointer in `SKILL.md` whenever a support file is added, so future agents know it exists.
7. Verify the result by loading representative skills with `skill_view` and listing the library.

## Third-party skill intake checklist

- Read the upstream README/SKILL.md enough to understand scope and quality.
- Prefer well-known maintainers or official project/org skills when available.
- Keep provenance in `references/SOURCE.md` with upstream URL and any license caveat.
- Copy only files useful to future agent operation; do not blindly import test suites, build artifacts, or repository metadata.
- For script-heavy skills, preserve scripts and key references if the runtime can invoke them later.
- Avoid encoding transient setup failures as permanent skill constraints.

## Stack bootstrap pattern

When setting up a user as a coding assistant across multiple stacks:

1. Install or copy high-value third-party skills for mature domains where curated skills exist.
2. Create local class-level umbrella skills for the user's recurring stacks when no trusted umbrella exists.
3. Keep stack skills broad enough to cover common work for that ecosystem, e.g. `python-api-pro` rather than separate single-library skills for FastAPI, SQLAlchemy, Alembic, and Pydantic.
4. Verify all installed skills are enabled and loadable.
5. Record stable user stack preferences in memory only when they will reduce future steering.

See `references/swift-and-polyglot-stack-bootstrap.md` for a concrete session-derived example.

## Pitfalls

- Do not create one skill per library when a stack-level skill is more useful.
- Do not edit hub-installed or bundled protected skills; create/patch local umbrellas instead.
- Do not save task progress, PR numbers, commit SHAs, or one-off outcomes in skills.
- Do not turn environment-specific failures into durable negative rules.
- Do not claim a skill is installed until `hermes skills list` or `skill_view` verifies it.
