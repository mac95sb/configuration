---
name: daily-brief
description: Prepare the user's concise morning brief for today's PAIR work. Use when the user asks for their daily brief, morning brief, today's priorities, or scheduled work review.
---

# Daily Brief

Prepare a concise morning brief for **today's PAIR work only**.

## Sources

Use the configured MCPs and connectors for:

- Microsoft Teams: messages, mentions, and relevant threads
- Microsoft Outlook: today's calendar and important email
- Notion: PAIR pages, tasks, and project notes
- GitHub: PAIR repositories, issues, pull requests, reviews, checks, and blockers

Use MCPs or CLIs before browser access. If a source is unavailable, say which source could not be checked instead of guessing.

## Research rules

- Search for items due today first, then urgent overdue items and blockers.
- Prioritize incidents, security work, SLA risks, deadlines, meetings, requested reviews, and blocked work.
- Exclude non-PAIR work.
- Avoid resolved or already completed items when reliable automation memory or current status shows they are resolved.
- Verify the current state before reporting an item.
- Link every mentioned pull request number directly to its GitHub URL.
- Link meetings, emails, Notion pages, issues, and other mentioned work where a direct URL is available.
- Do not send messages, change tickets, approve reviews, or modify external systems.

## Output

Start with the most urgent action. Use this structure:

### Today

- **Urgent / blockers**: action, reason, owner, deadline, and direct link.
- **Meetings**: time, title, purpose, preparation, and direct calendar link.
- **Reviews and delivery**: requested reviews, PR status, checks, deadlines, and next step.
- **Next steps**: the smallest useful action for each remaining item.

Keep the brief short and concrete. Combine duplicates across sources.

### Growth opportunities

Suggest 1–3 time-boxed opportunities grounded in today's work. Prefer urgent work first and cover relevant categories:

- **Platform**: contribute to, shadow, or trace infrastructure, deployment, or platform work.
- **Speaking/interviewing**: lead a walkthrough, interview segment, demo, or discussion.
- **Team rituals**: prepare, travel, or communicate for an important meeting.
- **Proactivity**: identify the highest-value unowned issue and define a small first action.

For every opportunity, include:

- a time box;
- the smallest outcome to record for the next 1:1.

If there are no credible opportunities, omit the section rather than inventing one.
