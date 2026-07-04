# Shared flow — scan, confirm, plan

This is the host-agnostic core shared by **`/setup-agents`**, **`/setup-claude`**,
and **`/setup-agy`**. The calling skill sets:

- **`TARGETS`** — a subset of `{claude, agy}`. `/setup-claude` → `{claude}`,
  `/setup-agy` → `{agy}`, `/setup-agents` → `{claude, agy}`.
- **`ADAPTERS`** — the Vercel-`skills` adapter name(s) for the targets:
  `claude-code` for `claude`, `antigravity-cli` for `agy`. Both when `TARGETS`
  has both.

These are fixed by the invoking skill — **do not detect the host you run in.**
`/setup-claude` scaffolds Claude Code even when invoked from Antigravity, and
`/setup-agy` scaffolds Antigravity even when invoked from Claude Code.

**Target directory is always the current working directory.** Do not ask the
user to confirm the directory — the in-session CWD is the target.

**Governing principle:** install nothing without evidence and consent. Every
agent, rule, hook, and skill installed must be justified by something found in
the scan or explicitly requested by the user. The Step 3 plan table is the
contract — materialization applies exactly that plan, nothing more.

**Interaction style:** conversational, one category at a time. Present each
category, show the scan-based recommendations pre-marked, and wait for the
user's reply before moving to the next. Keep messages tight — show the choices,
not an essay.

## Resolving the bundle root

Source files live under `template/` at the plugin bundle root: `agents/`,
`rules/`, `hooks/`, `CLAUDE.md`, `settings.json`, and the catalogs in
`skills/setup-agents/references/`. Resolve the bundle root per host you are
running in (this is about _reading_ the plugin's own files — it is independent
of `TARGETS`, which only decides what gets _written_):

- **Claude Code** — `${CLAUDE_PLUGIN_ROOT}` (env var is always set). Catalogs
  and this file are at `${CLAUDE_PLUGIN_ROOT}/skills/setup-agents/references/`.
- **Antigravity** — no equivalent env var is exposed to skills. `agy plugin
install` stages the whole plugin tree verbatim under
  `~/.gemini/config/plugins/setup-agents/`, so read `template/` and
  `skills/setup-agents/references/` from there. If that path doesn't exist,
  walk up from this file's own directory until you find a sibling `plugin.json`
  — that directory is the bundle root.

## Step 1 — Scan the project

Inspect the CWD and record what you find. Don't stop at manifests — open a
handful of real source/test files when a signal is ambiguous.

**Stack manifests** (any present):

- `package.json` (read it: dependencies, `name`/`description`, scripts)
- `pyproject.toml`, `requirements.txt` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `Gemfile` → Ruby
- `composer.json` → PHP
- `build.gradle`/`build.gradle.kts`/`pom.xml` → Java/Kotlin
- `Makefile` → record real build/test/lint targets regardless of language
- CI workflows: `.github/workflows/`, `.gitlab-ci.yml` — record real job commands

**JS/TS-specific signals:**

- `pnpm-workspace.yaml`, `turbo.json`, `lerna.json`, `nx.json`, or multiple
  manifests at depth 2+ → monorepo (list the packages)
- `next.config.*` → Next.js
- `drizzle.config.*` → Drizzle
- `sanity.config.*` or `@sanity/*` dep → Sanity
- `better-auth` dep / `auth.ts` / `app/api/auth/` → BetterAuth/auth
- `biome.json` / `biome.jsonc` → Biome
- `tsconfig.json` or `.ts`/`.tsx` files → TypeScript
- `react` dep → React
- `hono` dep → Hono
- `bunfig.toml`, `bun.lockb`, or `packageManager: bun@*` → Bun
- `tailwindcss` dep (v4) or `@theme` block in a CSS file → Tailwind

**Cross-language signals (drive catalog rows, not just JS):**

- Source layout: list the real source dirs found (`src/`, `app/`, `lib/`,
  `packages/*/src`, `cmd/`, `internal/`, ...) — these become rule `paths:`
  rewrites in materialization, never assume `src/` blindly.
- Tests: config files (`jest.config.*`, `vitest.config.*`, `pytest.ini`,
  `conftest.py`, `playwright.config.*`, language-native test dirs) — if found,
  open 1-2 real test files to confirm runner and convention.
- Frontend: `.tsx`/`.jsx`/`.vue`/`.svelte` files or `**/components/**`,
  `**/pages/**`, `**/views/**` dirs.
- Backend/API/auth: route/controller/handler/service dirs, `src/api/`,
  `src/auth/`, `src/middleware/**`.
- Database: migration or ORM dirs (`**/migrations/**`, `prisma/`, `drizzle/`,
  `alembic/`, `db/migrate/`, `knex/migrations/`, ...).
- Docs: a `docs/` directory or substantial `.md` files beyond the README.
- Formatter/linter beyond Biome: configs AND binaries (Prettier, ESLint, Ruff,
  Black, rustfmt, gofmt) — only recommend `lint-on-stop`/`format-on-save` when
  one is actually present.
- Deploy signals: `Dockerfile`, `docker-compose.*`, `Caddyfile`, `nginx.conf`.
- Git: default branch (`git symbolic-ref refs/remotes/origin/HEAD`), whether
  `gh` is installed and a GitHub remote exists (gates PR-related skills).
- existing host config for any of `TARGETS` (`.claude/` + `CLAUDE.md` for
  `claude`, `.agents/` + `AGENTS.md` for `agy`) → **gap-analysis mode** (see
  below); presence of the tree OR its project doc is enough to trip it

If the project has no source files and no manifests: say so, offer only the
minimal baseline (project-doc template + the four safety hooks), and stop after
installing it. Tell the user to re-run once code exists.

**Gap-analysis mode:** if a target's host config already exists (`.claude/` +
`CLAUDE.md` for `claude`, `.agents/` + `AGENTS.md` for `agy`), set gap mode for
this run and read what's already there (agents/skills, rules, hooks wired in
`settings.json`/`hooks.json`) directly from disk — no separate install-record
file is needed. Gap mode **replaces the install-tier pick (Step 1.6) with the
gap-analysis remediation (Step 1.7)**: it offers what's missing and flags what's
orphaned, then routes both through the Step 3 plan. Never delete or overwrite an
existing file without it appearing in the approved plan first. When `TARGETS`
has both hosts, run gap-analysis independently per host — a host with no config
yet simply has its full recommended set as "missing" and nothing orphaned.

Build a `detectedStack` list from the hits.

## Step 1.5 — Confirm the detected stack

Before any selection, render a labeled summary of `detectedStack` so the user
can sanity-check what was found. **Evidence-driven, not assumed:** emit a row
only for a category that has a real signal; mark `—` for one that was looked for
but not found; omit categories that never apply. Append a `Packages` list when a
monorepo was detected.

```
Stack
  Frontend:   Next.js 15 (React, Tailwind v4, TS)
  Backend:    Hono + Bun
  Database:   Drizzle + PostgreSQL
  Auth:       BetterAuth + Google
  Realtime:   Soketi (Pusher-compat)
  Testing:    bun:test (game-engine)
  Formatter:  Prettier (printWidth 100)
  Typecheck:  tsc (no ESLint/Biome)
  Pkg mgr:    pnpm workspaces
  Git:        <default-branch>, gh <installed?/remote?>
  CI:         <detected workflow / —>
Packages
  apps/web              Next.js frontend
  apps/api              Hono + Bun backend
  packages/db           Drizzle schema + migrations
  packages/types        Zod schemas (single source of truth)
  packages/game-engine  Pure game logic + bun:test
  packages/ui           Shared React components
```

(The values above are an example; fill in only what the scan actually found.)

Then ask one `AskUserQuestion`: **Accept** / **Correct it**. On _Correct it_,
take the user's edits, patch `detectedStack`, re-render the summary, and re-ask
until accepted. Do not proceed until the stack is confirmed.

**Fork after the stack is confirmed:** if this run is in gap-analysis mode (Step
1 found existing config for any target), skip the install tiers and go straight
to **Step 1.7**. Otherwise continue to Step 1.6.

## Step 1.6 — Pick install tier (fresh install only)

Reached only when no target has existing config — in gap-analysis mode this step
is skipped and Step 1.7 replaces it. Once the stack is accepted, offer how to
install. Ask one `AskUserQuestion` with four options, each stating what's in and
out:

- **Minimal** — project-doc template + the four safety hooks only
  (`block-dangerous-commands`, `scan-secrets`, `protect-files`,
  `warn-large-files`). Excludes all agents, rules, additional skills, and
  third-party plugins.
- **Standard (Recommended)** — read all 6 catalogs silently, apply every
  "Recommend when" rule against the scan, and build the recommended selection
  (bundled skills marked as already available, external skills queued for
  install). Excludes catalog items with no supporting evidence.
- **Full** — every item in all 6 catalogs plus Graphify (the one third-party plugin;
  caveman + ponytail are external skills, covered by the skills catalog). Excludes nothing.
- **Custom** — pick each agent, rule, hook, and skill individually (the
  category-by-category flow in Step 2; every item is listed and toggleable).

**One-shot tiers (Minimal / Standard / Full):** build the selection silently
from the catalogs, skip all per-category prompts, and go straight to Step 3's
plan table. Render the table (the contract still holds), then install without
further questions **except** when one of these fires — only then stop and ask:

- a required system dep is missing (`uv`/`pipx` for Graphify, `bunx` for
  skills, `gh auth` for a private skill repo), or
- a crucial/destructive action is pending (overwriting an existing project doc,
  or overwriting/removing existing files in gap-analysis mode).
  Otherwise apply the whole plan and report at the end.

**Custom** → proceed to Step 2.

## Step 1.7 — Gap-analysis remediation (gap mode only)

Reached when Step 1 detected existing host config for any target. This
**replaces** the install tiers (Step 1.6). Compute the two lists per host in
`TARGETS` independently, against the confirmed stack and the six catalogs (read
each catalog once, apply its **Recommend when** column):

- **Missing** — a catalog item whose **Recommend when** now holds against the
  scan but which is absent from disk. The four safety hooks
  (`block-dangerous-commands`, `scan-secrets`, `protect-files`,
  `warn-large-files`) count as missing whenever they aren't wired. A host with
  no config yet lists its full recommended set here.
- **Orphan** — something already on disk that current evidence no longer
  justifies: (a) an installed catalog item whose **Recommend when** is now false
  (stack signal removed), or (b) an installed file with no catalog match at all
  (renamed or dropped upstream, hand-added). Never treat the project doc,
  `settings.json`/`hooks.json`, or `.agent-starter.json` as orphans — they are
  host plumbing, not catalog components.

Render one gap report — two labeled sections, one row per item with a one-line
reason. When `TARGETS` has both hosts and their state differs, group by host.

```
Gap analysis (Targets: Claude Code)
  Missing — catalog offers, not installed
    security-reviewer (agent)   API routes in src/api/ — no reviewer present
    scan-secrets (hook)         safety baseline — not wired
  Orphan — installed, no longer justified
    graphql.md (rule)           no GraphQL dep or schema found anymore
    old-helper.sh (hook)        no catalog match — renamed/removed upstream
```

If both lists are empty, tell the user the setup is already in sync with the
current stack and stop — nothing to plan.

Otherwise ask two `AskUserQuestion` rounds, **missing first, then orphans**:

1. **Missing** — options: **Install all (Recommended)** (list each item with its
   reason so the user sees why) / **Choose per category** (drop into the Step 2
   category flow, pre-marked, but scoped to the missing items only) / **Skip**.
2. **Orphans** — options: **Remove all** / **Choose per category** (per-category
   toggles, scoped to the orphans only) / **Keep all**. Removal is destructive:
   it only ever proceeds via the approved Step 3 plan (below), never here.

Carry both selections into Step 3 as `install` rows (chosen missing items) and
`remove` rows (chosen orphans), then continue to Step 3 as normal.

## Step 2 — Category-by-category selection

(Only reached from the **Custom** tier.)

Read the matching catalog before presenting each category, and pre-mark the
recommended items per its **Recommend when** column against the scan.

Go in this order, one turn each:

1. **Agents** — read `references/agents-catalog.md`. List all 8 with a one-line
   purpose; pre-mark recommendations. Ask the user to confirm, adjust, or skip.
2. **Rules** — read `references/rules-catalog.md`. List all 16; pre-mark.
3. **Hooks** — read `references/hooks-catalog.md`. List all 10; **always
   pre-mark the four safety hooks** (`block-dangerous-commands`, `scan-secrets`,
   `protect-files`, `warn-large-files`); pre-mark `format-on-save` when Biome is
   detected, `typecheck-on-stop`/`lint-on-stop` when a type-checker/linter is
   detected, `session-start` by default (cheap).
4. **Third-party plugins** — read `references/third-party-plugins-catalog.md`. This is
   now **Graphify only** (Caveman + Ponytail moved to the Skills catalog — see Step 5).
   Present Graphify **pre-marked by default**; it's a system tool (`uv`/`pipx`/`pip`)
   that writes a graph-report snippet to the project doc, so confirm before proceeding.
5. **Skills** — read `references/skills-catalog.md`. Present in two groups:
   - **Bundled skills** (already included with this plugin — no install needed): scan
     the bundle's `skills/` dir (see bundle-root resolution above) for subdirectory
     names, exclude `setup-agents`, `setup-claude`, and `setup-agy` themselves. Show
     each bundled skill with its one-line description and pre-mark per the
     **Recommend when** column in the catalog's "Bundled Skills" section. Selected
     bundled skills are logged as "already available" — no action required at install.
   - **Additional skills** (installed from GitHub via `bunx skills add`): read the
     catalog's "External Skills" section. Pre-mark recommendations from the scan.
     Each selected skill runs `bunx skills add <repo-url> --skill <skill-name> -a <adapter> -y`
     at install time, once per adapter in `ADAPTERS`. The base `caveman` and `ponytail`
     skills are pre-marked by default and, on successful install, append a mode nudge to
     the host doc (`# Communication style` / `# Build discipline`) — see the catalog
     footnote. All other external skills and the ponytail sub-tools append nothing.
6. **Project doc template** — the template is `CLAUDE.md` for `claude`,
   `AGENTS.md` for `agy` (both when `TARGETS` has both), and always lands at the
   **project root** — never inside `.claude/` or `.agents/`.
   - **No doc yet** → ask once whether to copy the template.
   - **Doc already exists** → never silently skip or overwrite. Read both the
     existing root doc and the template, compare them, and tell the user in 2-3
     lines what differs (e.g. existing is project-specific and richer → keep;
     existing is the stale/thin default and the template adds sections → update).
     Then one `AskUserQuestion`: **Keep existing** / **Replace with template** /
     **Merge** (fold the template's missing sections into the existing doc,
     preserving the user's own content). Recommend the safer of keep/merge; don't
     decide for them. Carry the choice into the Step 3 plan as the doc's action.

Use AskUserQuestion for each category so the user can multi-select. Accept
"all", "the recommended ones", "none", or specific names.

## Step 3 — Plan & approve

Before writing anything, render one table from everything selected (and, in
gap-analysis mode, everything flagged for removal). When `TARGETS` has both
hosts, one plan drives both — note the target set in the table caption
(e.g. "Targets: Claude Code + Antigravity"):

| Component                         | Action  | Evidence                                               | Cost class                  |
| --------------------------------- | ------- | ------------------------------------------------------ | --------------------------- |
| `security-reviewer` (agent)       | install | API routes detected in `src/api/`                      | invoked-only                |
| `security.md` (rule)              | install | `src/auth/`, `src/middleware/` found                   | path-scoped                 |
| `testing.md` (rule)               | install | `vitest.config.ts` + `*.test.ts` found                 | always-loaded (no `paths:`) |
| `block-dangerous-commands` (hook) | install | always-on safety                                       | hook — no context cost      |
| `caveman` (skill)                 | install | default selected; user confirmed                       | project-doc snippet         |
| `graphify` (plugin)               | skip    | `uv`/`pipx` not found on PATH                          | —                           |
| `pr-review` (skill)               | skip    | no GitHub remote / `gh` not installed                  | —                           |
| `old-custom-rule.md` (rule)       | remove  | no longer justified by scan; not in approved selection | —                           |

Cost class: `invoked-only` for agents/skills, `path-scoped` for rules with
`paths:` frontmatter, `always-loaded` for rules without it, `hook` for hooks
(zero per-turn context cost, registered in host config).

For the **Custom** tier, ask one `AskUserQuestion`: **approve the plan** /
**adjust** (loop back to Step 2) / **cancel**. Do not proceed to materialization
without approval. For one-shot tiers (Minimal / Standard / Full), still render
this table, but auto-approve and proceed — interrupt only on the missing-dep or
crucial/destructive flags listed in Step 1.6. **In gap-analysis mode always ask
for approval** (**approve the plan** / **adjust** — loop back to Step 1.7 /
**cancel**), since the plan may carry `remove` rows. This table is the contract
— materialization installs and removes exactly what it lists.

## Next — materialize

With the plan approved, run the materializer(s) for `TARGETS`:

- `claude` in `TARGETS` → follow `references/materialize-claude.md`.
- `agy` in `TARGETS` → follow `references/materialize-agy.md`.

When both are present, the scan/confirm/plan above ran **once**; only
materialization runs twice (once per host, writing `.claude/` and `.agents/`
independently — no shared files, no symlinks between the two trees).

## Guardrails

- Only ever write under the target host's tree: the `.claude/` directory plus a
  `CLAUDE.md` at the **project root** (`claude`), the `.agents/` directory plus
  an `AGENTS.md` at the **project root** (`agy`). The project doc is ALWAYS
  root-level — never write `.claude/CLAUDE.md` or `.agents/AGENTS.md`. Never
  write a tree for a host not in `TARGETS`.
- Never overwrite, remove, or install a file without it appearing in the
  approved Step 3 plan first.
- If a category has no recommendations and the user skips it, that's fine —
  record it as empty and move on.
- Uncertain detection → ask, don't guess.
- Keep all user-facing messaging in plain language; don't dump file paths or JSON
  at the user unless they ask.
