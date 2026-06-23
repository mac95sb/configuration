---
name: vue-app-pro
description: Senior Vue 3 guidance for Pinia, Vuetify, Auth0, Stripe, vue-i18n, and Three.js. Use when building, reviewing, or debugging Vue apps with these libraries.
license: CC0-1.0
metadata:
  author: local
  version: "1.0"
---

# Vue App Pro

Use this skill for Vue 3 applications, especially TypeScript + Vite projects using Pinia, Vuetify, Auth0, Stripe, i18n, or Three.js.

## Default workflow

1. Inspect `package.json`, lockfile, Vite/Vue config, router, store layout, plugins, and tests before editing.
2. Follow the project’s existing Composition API, TypeScript, component, and styling conventions.
3. Prefer small components, typed composables, and explicit tests. Do not add packages unless approved.
4. Verify with the project’s real commands: typecheck, lint, unit/component tests, and build.

## Vue 3 conventions

- Prefer Composition API with `<script setup lang="ts">` when the project uses it.
- Keep components presentation-focused; move shared state/effects to Pinia stores or composables.
- Use typed props/emits and avoid untyped `any` payloads.
- Keep async state explicit: loading, success, empty, error, retry/cancel behavior.
- Use `computed` for derived state; avoid watchers unless reacting to side effects.

## Pinia

- Stores should own cross-route state and business actions; components should not duplicate store logic.
- Keep state serializable where possible and resettable for tests/logout.
- Use getters for derived state and actions for async mutations.
- Avoid calling router/Auth0/Stripe APIs directly in unrelated stores unless the app already has an integration boundary.

## Vuetify

- Use Vuetify components semantically and preserve accessibility: labels, aria where needed, keyboard flow, disabled/loading states.
- Prefer theme tokens and utility classes already used in the app; avoid ad-hoc CSS unless necessary.
- Validate forms with the project’s chosen pattern and show actionable error text.

## Auth0

- Treat tokens as sensitive. Do not log them or store them in localStorage unless the existing Auth0 setup explicitly requires it.
- Keep route guards and API client token injection centralized.
- Handle loading/authenticated/error states; avoid rendering protected UI before auth state is known.
- Check audience, scope, redirect URI, logout URL, and refresh token configuration when debugging auth failures.

## Stripe

- Never put secret keys in frontend code. Frontend uses publishable keys only.
- For Checkout/PaymentIntent flows, create sessions/intents server-side and confirm client-side with Stripe.js.
- Handle SCA, redirects, cancellations, idempotency, and webhook-driven fulfillment.
- Do not trust client-only payment success; verify via backend/webhooks.

## vue-i18n

- Avoid hard-coded user-visible strings in components unless the project deliberately excludes them.
- Keep message keys stable and organized by feature.
- Handle pluralization, date/number/currency formatting, locale fallback, and missing translation behavior.
- Do not concatenate translated fragments when interpolation or plural rules are needed.

## Three.js in Vue

- Encapsulate scenes in composables/components with clear lifecycle cleanup: dispose geometries, materials, textures, controls, and renderers on unmount.
- Use `requestAnimationFrame` carefully; stop loops when components unmount or are hidden.
- Keep renderer size/pixel ratio responsive and avoid unnecessary reactive re-renders of heavy scene objects.
- Separate scene setup, asset loading, controls, and domain state for testability.

## Review checklist

- Type safety, component boundaries, store responsibilities, async state, accessibility, i18n coverage.
- Auth/token handling, payment security, Stripe webhook assumptions.
- Bundle/build impact, lazy loading, Three.js cleanup/performance.
- Tests for stores, composables, route guards, and critical user flows.
