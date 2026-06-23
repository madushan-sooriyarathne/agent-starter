# Skills Catalog

Installable skills. Unlike agents/rules/hooks (copied from this plugin), skills are
installed with the `skills` CLI. Standardize on **`bunx skills add <name>`** (Bun-first
stack; `npx skills add <name>` works identically as a fallback).

Present the recommended set based on the scan, let the user adjust, then run the install
command for each selected skill.

| # | Skill | Install command | Recommend when |
|---|-------|-----------------|----------------|
| 1 | `engineering:code-review` | `bunx skills add engineering:code-review` | Always |
| 2 | `engineering:debug` | `bunx skills add engineering:debug` | Always |
| 3 | `engineering:documentation` | `bunx skills add engineering:documentation` | Always |
| 4 | `engineering:testing-strategy` | `bunx skills add engineering:testing-strategy` | No existing `.claude/` (fresh setup) |
| 5 | `engineering:architecture` | `bunx skills add engineering:architecture` | `turbo.json` detected |
| 6 | `engineering:system-design` | `bunx skills add engineering:system-design` | `turbo.json` detected |
| 7 | `engineering:deploy-checklist` | `bunx skills add engineering:deploy-checklist` | Next.js or VPS signals |
| 8 | `engineering:incident-response` | `bunx skills add engineering:incident-response` | BetterAuth or auth detected |
| 9 | `engineering:tech-debt` | `bunx skills add engineering:tech-debt` | Sanity detected |
| 10 | `next-pro-seo` | `bunx skills add madushan/next-pro-seo` | `next.config.*` detected |
| 11 | `brand-voice:brand-voice-enforcement` | `bunx skills add brand-voice:brand-voice-enforcement` | Hospitality / real-estate signals |
| 12 | `design:design-critique` | `bunx skills add design:design-critique` | Hospitality / real-estate signals |

## Scan signal definitions

- **Always** — recommend regardless of stack.
- **No existing `.claude/`** — the target had no `.claude/` directory before this run (a first-time setup).
- **`turbo.json` detected** — Turborepo monorepo.
- **Next.js or VPS signals** — `next.config.*` present, or deploy config such as a `Dockerfile`, `docker-compose.*`, `Caddyfile`, `nginx.conf`, or a `deploy`/`vps` script in `package.json`.
- **BetterAuth or auth detected** — `better-auth` in dependencies, a `auth.ts`/`auth.config.*`, or an `app/api/auth/` route.
- **Sanity detected** — `sanity.config.*` or `@sanity/*` in dependencies.
- **Hospitality / real-estate signals** — domain hints in `package.json` name/description or content (e.g. `hotel`, `resort`, `booking`, `property`, `listing`, `realty`, `realestate`). Heuristic; confirm with the user before pre-marking.

## Install notes

- Run one `skills add` command per selected skill. Surface any failures (network, unknown
  skill name) without aborting the rest of the setup.
- `next-pro-seo` is published under the `madushan/` namespace; the others are plugin-scoped
  (`engineering:`, `brand-voice:`, `design:`).
- Skills are installed into the user's skills location by the CLI, not copied into `.claude/`.
  Record the installed skill names in `.madushan-setup.json` for the record.
