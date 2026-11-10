# Shared flow — scan, confirm, plan

The calling setup skill selects a fixed subset of `{claude, agy, codex}`.
`setup-agents` selects all three. Each single-host skill selects its named
target, regardless of the host executing it.

Select the skills adapters from the targets: `claude-code` for Claude Code,
`antigravity-cli` for Antigravity alone, and `codex` for Codex. If both Codex
and Antigravity are selected, use the `codex` adapter for their shared
`.agents/skills/` directory. Claude Code keeps its own adapter.

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

From the invoked skill's installed `skills/<name>/SKILL.md` path, walk up to
the bundle root. It contains the `skills/setup-agents/references/` directory and
`template/` with all shipped assets, including language profiles and the Codex
writer. The path is independent of the current project. Use the absolute
installed skill path supplied by the host when available.

- **Claude Code** can also resolve `CLAUDE_PLUGIN_ROOT`.
- **Antigravity** can also use `~/.gemini/config/plugins/setup-agents/`.
- **Codex** installs to the plugin cache. If the skill path is unavailable,
  use `codex plugin list --json` to identify the enabled marketplace and version,
  then locate the matching `setup-agents` under the configured Codex plugin
  cache. Verify the bundle contains `template/` and the
  references before applying a plan. If it cannot be resolved uniquely, stop
  and report the missing bundle.

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
- Existing host config for any selected target triggers **gap analysis**.
  Detect Claude via `.claude/` or `CLAUDE.md`, Antigravity via its rule/hook/MCP
  files under `.agents/`, and Codex via `.codex/`. Treat `AGENTS.md` and
  `.agents/skills/` as shared. A handwritten doc, shared skills, or a
  marketplace catalog alone does not mark either host configured.

If the project has no source files and no manifests, offer the minimal
baseline (project instructions and the four safety hooks). Re-run after the
project has code to add stack-specific components.

When any target has configuration, inspect it per target. A fresh target
still needs its recommended agents, guidance, hooks, and portable skills.
An existing target lists missing, owned orphans, and re-tailor candidates.
Preserve unknown files and existing shared skills. Plan `AGENTS.md` once
for both hosts, independently of whether `CLAUDE.md` exists.

Build a `detectedStack` list from the hits, and the `LANGS` list of language profiles
(`typescript` / `rust` / `go`) per `references/language-tailoring.md` — materialization
uses it to fill the language markers in every copied file.

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
  Tailoring:  typescript (language profiles from LANGS)
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
  `warn-large-files`). Excludes all agents, rules, additional skills, the
  workflow commands, and third-party plugins.
- **Standard (Recommended)** — read all 6 catalogs silently, apply every
  "Recommend when" rule against the scan, and build the recommended selection
  (bundled skills copied per-project one-by-one, external skills queued for
  install, the workflow-command group copied in). Excludes catalog items with no
  supporting evidence.
- **Full** — every item in all 6 catalogs plus the workflow commands and Graphify
  (the one third-party plugin; caveman + ponytail are external skills, covered by
  the skills catalog). Excludes nothing.
- **Custom** — pick each agent, rule, hook, and skill individually (the
  category-by-category flow in Step 2; every item is listed and toggleable). The
  workflow commands are offered as one opt-in group (all five or none), not per
  command.

The **workflow commands** (`qnew`/`qplan`/`qcode`/`qgit`/`qcheck`, the Workflow
Commands section of the skills catalog) are a group, not per-catalog picks: on by
default in Standard/Full, one yes/no in Custom, off in Minimal. They are copied
into the project (see the materialize refs), not installed via the skills CLI.

**One-shot tiers (Minimal / Standard / Full):** build the selection silently
from the catalogs, skip all per-category prompts, and go straight to Step 3's
plan table. Ask for plan approval and resolve these conditions before applying it:

- a required system dep is missing (`uv`/`pipx` for Graphify, `bunx` for
  skills, `gh auth` for a private skill repo), or
- a crucial/destructive action is pending (overwriting an existing project doc,
  or overwriting/removing existing files in gap-analysis mode).
  Apply the approved plan and report at the end.

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
- **Orphan** — an installer-owned file whose catalog entry no longer applies.
  Treat ownership as unconfirmed for unknown paths or edited copies. Keep
  shared skill entries if Codex or Antigravity uses or may still use them.
  Preserve existing native Codex files by default. Project docs, hook
  registration files, and fingerprints are configuration, never orphans.

- **Re-tailor** — catalog files on disk whose language sections are out of date
  for the current `LANGS`: **refill** (blocks record other languages — rewritten
  in place, user edits kept) or **recopy** (installed before language profiles
  existed — re-copied from source, overwriting local edits). Rules in
  `references/language-tailoring.md`.

Render one gap report — labeled sections, one row per item with a one-line
reason. When multiple targets differ, group by host.

```
Gap analysis (Targets: Claude Code)
  Missing — catalog offers, not installed
    security-reviewer (agent)   API routes in src/api/ — no reviewer present
    scan-secrets (hook)         safety baseline — not wired
  Orphan — installed, no longer justified
    graphql.md (rule)           no GraphQL dep or schema found anymore
  Re-tailor — language sections out of date (now: rust)
    qgit (skill)                refill — tailored for typescript only
    code-reviewer (agent)       recopy — pre-profile copy, overwrites local edits
```

If all three lists are empty, tell the user the setup is already in sync with the
current stack and stop — nothing to plan.

Otherwise ask up to three `AskUserQuestion` rounds, **missing, then orphans, then
re-tailor**:

1. **Missing** — options: **Install all (Recommended)** (list each item with its
   reason so the user sees why) / **Choose per category** (drop into the Step 2
   category flow, pre-marked, but scoped to the missing items only — use the same
   batched-`multiSelect` picker mechanics, never a type-the-names prompt) /
   **Skip**.
2. **Orphans** — options: **Remove all** / **Choose per category** (batched-
   `multiSelect` picker toggles, scoped to the orphans only) / **Keep all**.
   Removal is destructive: it only ever proceeds via the approved Step 3 plan
   (below), never here.
3. **Re-tailor** — options: **Re-tailor all (Recommended)** / **Refill only**
   (keeps local edits; skips recopy rows) / **Skip**. With no recopy rows, ask
   **Re-tailor (Recommended)** / **Skip**.

Carry the selections into Step 3 as `install` rows (chosen missing items),
`remove` rows (chosen orphans), and `re-tailor` rows (chosen refill/recopy
files), then continue to Step 3 as normal.

## Step 2 — Category-by-category selection

(Only reached from the **Custom** tier.)

Read the matching catalog before presenting each category, and pre-mark the
recommended items per its **Recommend when** column against the scan.

**Selection mechanics.** When `AskUserQuestion` supports multi-select, use
batches of up to four options per question. Otherwise, show the same choices
as numbered options in chat, pre-mark recommendations, and accept option
numbers or “recommended”, “all”, or “none”. This fallback applies to every
confirmation in the flow. Present one category at a time.

Go in this order, one turn each:

1. **Agents** — read `references/agents-catalog.md`. All 8 → **2 multiSelect
   questions** (4 + 4) in one call, one-line purpose each; pre-mark
   recommendations.
2. **Rules** — read `references/rules-catalog.md`. All 16 → **4 multiSelect
   questions** (4 × 4) in one call; pre-mark.
3. **Hooks** — read `references/hooks-catalog.md`. All 10 → **3 multiSelect
   questions** (4 + 4 + 2) in one call; **always pre-mark the four safety hooks**
   (`block-dangerous-commands`, `scan-secrets`, `protect-files`,
   `warn-large-files`); pre-mark `format-on-save` when Biome is detected,
   `typecheck-on-stop`/`lint-on-stop` when a type-checker/linter is detected,
   `session-start` by default (cheap).
4. **Third-party plugins** — read `references/third-party-plugins-catalog.md`. This is
   now **Graphify only** (Caveman + Ponytail moved to the Skills catalog — see Step 5).
   Offer Graphify for the supported Claude or Antigravity targets only.
   It writes project configuration, so confirm those changes in the plan.
5. **Skills** — read `references/skills-catalog.md`. Present in two groups:
   - **Bundled skills** (repo-bundled, copied into the project — never installed
     globally): scan the bundle's `template/skills/` dir (see bundle-root resolution
     above) for subdirectory names, exclude the four setup skills,
     and the workflow commands (`qnew`/`qplan`/`qcode`/`qgit`/`qcheck` — handled as their
     own group). Show each bundled skill with its one-line description and pre-mark per
     the **Recommend when** column in the catalog's "Bundled Skills" section. Present
     them **individually selectable** (one-by-one, not all-or-none). Each selected
     bundled skill is copied into the project's skills dir at install (materialize step),
     the same mechanism as the workflow commands.
   - **Additional skills** (installed from GitHub via `bunx skills add`): read the
     catalog's "External Skills" section. Pre-mark recommendations from the scan.
     Each selected skill runs `bunx skills add <repo-url> --skill <skill-name> -a <adapter> -y`
     at install time, once per adapter in `ADAPTERS`. The base `caveman` and `ponytail`
     skills are pre-marked by default and, on successful install, append a mode nudge to
     the host doc (`# Communication style` / `# Build discipline`) — see the catalog
     footnote. All other external skills and the ponytail sub-tools append nothing.
6. **Project doc template** — the template is `CLAUDE.md` for `claude`,
   `AGENTS.md` for Antigravity or Codex (one shared action), and always lands at the
   **project root** — never inside `.claude/` or `.agents/`.
   - **No doc yet** → ask once whether to copy the template.
   - **Doc already exists** → never silently skip or overwrite. Read both the
     existing root doc and the template, compare them, and tell the user in 2-3
     lines what differs (e.g. existing is project-specific and richer → keep;
     existing is the stale/thin default and the template adds sections → update).
     For a shared `AGENTS.md` when Codex is selected, offer **Keep existing**
     (default) or **Merge** (add only the approved sections and guidance link).
     For other docs also offer **Replace with template**. Carry the explicit
     choice into the Step 3 plan.

Each category is one turn: present its pre-marked picker (per the selection
mechanics above), take the reply, move to the next. Never skip a category into a
free-text "type the names you want" prompt.

## Step 3 — Plan & approve

Before writing anything, render one table covering each selected target and
the affected output paths. List each shared path once. Mark incompatible items
as skipped on that target. Separate Codex guidance files are read on demand.
Include explicitly approved removals and edits to existing instructions:

| Component                         | Action             | Evidence                                                  | Cost class                  |
| --------------------------------- | ------------------ | --------------------------------------------------------- | --------------------------- |
| `security-reviewer` (agent)       | install            | API routes detected in `src/api/`                         | invoked-only                |
| `security.md` (rule)              | install            | `src/auth/`, `src/middleware/` found                      | path-scoped                 |
| `testing.md` (rule)               | install            | `vitest.config.ts` + `*.test.ts` found                    | always-loaded (no `paths:`) |
| `block-dangerous-commands` (hook) | install            | always-on safety                                          | hook — no context cost      |
| `caveman` (skill)                 | install            | default selected; user confirmed                          | project-doc snippet         |
| `graphify` (plugin)               | skip               | `uv`/`pipx` not found on PATH                             | —                           |
| `pr-review` (skill)               | skip               | no GitHub remote / `gh` not installed                     | —                           |
| `old-custom-rule.md` (rule)       | remove             | no longer justified by scan; not in approved selection    | —                           |
| `qgit` (skill)                    | re-tailor (refill) | `Cargo.toml` added; blocks tailored for `typescript` only | invoked-only                |

Cost class: `invoked-only` for agents/skills, `path-scoped` for rules with
`paths:` frontmatter, `always-loaded` for rules without it, `hook` for hooks
(zero per-turn context cost, registered in host config).

Ask the user to approve, adjust, or cancel the combined plan before writing.
Show the files that would be removed, overwritten, or merged and keep those
actions opt-in. The plan is the contract for every materializer.

## Next — materialize

With the plan approved, run the materializer(s) for `TARGETS`:

- `claude` in `TARGETS` → follow `references/materialize-claude.md`.
- `agy` in `TARGETS` → follow `references/materialize-agy.md`.

- `codex` in `TARGETS` → follow `references/materialize-codex.md`.

Scan once and apply each selected writer. When Codex and Antigravity are both
selected, the Codex writer handles portable skills, the shared external-skill
adapter and the root `AGENTS.md`. Run a third-party installation at most once
where it supports the selected hosts. Keep existing documentation and avoid
duplicate snippets.

## Guardrails

- Limit writes to the selected hosts' approved paths. Claude writes
  `.claude/` and root `CLAUDE.md`. Antigravity writes `.agents/` and root
  `AGENTS.md`. Codex writes `.codex/`, `.agents/skills/`, and root
  `AGENTS.md`. Keep existing marketplace files and user settings.
- Never overwrite, remove, or install a file without it appearing in the
  approved Step 3 plan first.
- If a category has no recommendations and the user skips it, that's fine —
  record it as empty and move on.
- Uncertain detection → ask, don't guess.
- Keep all user-facing messaging in plain language; don't dump file paths or JSON
  at the user unless they ask.
