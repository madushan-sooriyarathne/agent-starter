# CLAUDE.md

Guidance for Claude Code when working in this repository. Keep this file current — it is loaded into context every session.

## Stack

- **Framework:** Next.js (App Router)
- **Monorepo:** Turborepo + pnpm workspaces _(remove if this is a single app)_
- **API:** Hono on Bun
- **Database:** Drizzle ORM + PostgreSQL
- **Auth:** BetterAuth
- **CMS:** Sanity _(remove if unused)_
- **Styling:** Tailwind CSS v4
- **Tooling:** Biome (format + lint), Vitest (tests)
- **Package manager:** pnpm (monorepo) / bun (runtime). Never npm or yarn.

## Code style

- **No `any`.** Use `unknown` + narrowing or a Zod parse. No `@ts-ignore` without an explaining comment.
- **Infer types from the source of truth** — DB types from the Drizzle schema (`$inferSelect`/`$inferInsert`), DTOs from Zod (`z.infer`). Don't hand-maintain parallel types.
- **Validate external input with Zod** at every boundary (request bodies, params, env, third-party + webhook responses). Pass inferred types inward.
- **Formatting and linting are Biome's job** — run `biome check --write`; don't hand-format.
- **No barrel files** (`index.ts` re-export hubs). Import from the specific module.
- **No cross-package relative imports** in the monorepo — import by workspace package name (`@scope/pkg`).
- **Server Components by default;** add `"use client"` only on the interactive leaf that needs it.

## Project structure

<!-- Single app: describe the top-level src/ layout. -->
<!-- Monorepo: list apps/ and packages/ and what each owns, e.g. -->

```
apps/
  web/        # Next.js front end
  api/        # Hono (Bun) service
packages/
  db/         # Drizzle schema + client
  ui/         # shared React components
  config/     # shared Biome / TS config
```

Naming: workspace packages are `@<scope>/<name>`. Apps are deployables; packages are shared libraries (apps depend on packages, never the reverse).

## Commands

<!-- Fill in the real scripts from package.json / turbo.json. -->

```
pnpm dev            # run dev servers
pnpm build          # build all packages (turbo)
pnpm test           # vitest
pnpm check          # biome check
pnpm db:generate    # drizzle-kit generate
pnpm db:migrate     # apply migrations
```

## Project Overview

<!-- What is this project? Who is it for? One short paragraph. -->

## Key Decisions

<!-- Non-obvious architectural choices and the *why* behind them.
     The reasoning that isn't recoverable from reading the code. -->

## Current Focus

<!-- What's actively being worked on right now. Update as priorities shift. -->

## Out of Scope

<!-- What this project deliberately does NOT do, and things Claude should
     not touch or change without asking. -->
