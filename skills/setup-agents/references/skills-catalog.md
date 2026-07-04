# Skills Catalog

## Bundled Skills

These skills ship with this plugin and are **already available** — no install command
needed. When selected in setup-agents, they are logged as "available (bundled)" in the
summary. Surface them to the user so they know what they have.

| #   | Skill            | Description                                                                                     | Recommend when                                                  |
| --- | ---------------- | ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| B1  | `catchup`        | Rebuild working context fast after `/clear` or a fresh session; summarizes branch changes       | Always                                                          |
| B2  | `debug-fix`      | Find and fix a bug. `--fast` flag for emergency hotfix mode                                     | Always                                                          |
| B3  | `explain`        | One-sentence summary + mental model. `verbose` for ASCII diagram + modification guide           | Always                                                          |
| B4  | `fix-issue`      | Take a GitHub issue number to tested fix, prep a closing PR                                     | `gh` + GitHub remote detected                                   |
| B5  | `pr-review`      | Parallel specialist-agent review (quality, security, performance, silent failures, tests, docs) | `gh` + GitHub remote detected                                   |
| B6  | `refactor`       | Safe refactor with tests as safety net. `--diff` to simplify current diff before committing     | Always                                                          |
| B7  | `ship`           | Scan changes → commit → push → create PR, with confirmation at each step                        | `gh` + GitHub remote detected                                   |
| B8  | `tdd`            | TDD loop: failing test first → minimum code to pass → refactor → repeat                         | Test runner detected (`jest.config.*`, `vitest.config.*`, etc.) |
| B9  | `test-writer`    | Write comprehensive tests for new or changed code                                               | Test runner detected                                            |
| B10 | `claude-md`      | Keep CLAUDE.md current and lean. `audit` to check for stale commands, drift, and bloat          | Always                                                          |
| B11 | `context-budget` | Estimate per-turn token cost of `.claude/` and `CLAUDE.md`; flags over-budget contributors      | Always                                                          |

## External Skills

Installed with the Vercel `skills` CLI
([vercel-labs/skills](https://github.com/vercel-labs/skills)) from a **GitHub repo URL
plus a skill name** — never via a Claude Code marketplace/plugin install. Each row
below maps a display name to its repo and `--skill` argument.

Install (non-interactive, into the project's skills dir for the detected host), run
from the project directory. `<adapter>` = `claude-code` under Claude Code (→
`.claude/skills/`) or `antigravity-cli` under Antigravity (→ `.agents/skills/`):

```bash
bunx skills add <repo-url> --skill <skill-name> -a <adapter> -y
# example (Claude Code):
bunx skills add https://github.com/anthropics/skills --skill frontend-design -a claude-code -y
# example (Antigravity):
bunx skills add https://github.com/anthropics/skills --skill frontend-design -a antigravity-cli -y
```

| #   | Skill                       | Repo URL                                                  | `--skill`                     | Recommend when                                                  |
| --- | --------------------------- | --------------------------------------------------------- | ----------------------------- | --------------------------------------------------------------- |
| 1   | frontend-design             | `https://github.com/anthropics/skills`                    | `frontend-design`             | Frontend detected (`.tsx`/`.jsx`, `components/` dir)            |
| 2   | webapp-testing              | `https://github.com/anthropics/skills`                    | `webapp-testing`              | Always                                                          |
| 3   | next-pro-seo                | `https://github.com/madushan-sooriyarathne/next-pro-seo`  | `next-pro-seo`                | `next.config.*` detected                                        |
| 4   | brand-guidelines            | `https://github.com/anthropics/skills`                    | `brand-guidelines`            | Hospitality / real-estate / marketing signals                   |
| 5   | mcp-builder                 | `https://github.com/anthropics/skills`                    | `mcp-builder`                 | Opt-in (off by default)                                         |
| 6   | skill-creator               | `https://github.com/anthropics/skills`                    | `skill-creator`               | Opt-in (off by default)                                         |
| 7   | vercel-react-best-practices | `https://github.com/vercel-labs/agent-skills`             | `vercel-react-best-practices` | `react` dep detected                                            |
| 8   | vercel-composition-patterns | `https://github.com/vercel-labs/agent-skills`             | `vercel-composition-patterns` | `react` dep detected                                            |
| 9   | shadcn                      | `https://github.com/shadcn/ui`                            | `shadcn`                      | `react` dep + `components/` dir detected                        |
| 10  | systematic-debugging        | `https://github.com/obra/superpowers`                     | `systematic-debugging`        | Always                                                          |
| 11  | next-best-practices         | `https://github.com/vercel-labs/next-skills`              | `next-best-practices`         | `next.config.*` detected                                        |
| 12  | emil-design-eng             | `https://github.com/emilkowalski/skills`                  | `emil-design-eng`             | Next.js + `framer-motion` or `motion` dep detected              |
| 13  | agent-browser               | `https://github.com/vercel-labs/agent-browser`            | `agent-browser`               | `playwright.config.*` or `cypress` detected                     |
| 14  | web-design-guidelines       | `https://github.com/vercel-labs/agent-skills`             | `web-design-guidelines`       | Any frontend detected                                           |
| 15  | tdd                         | `https://github.com/mattpocock/skills`                    | `tdd`                         | Test config detected (`jest.config.*`, `vitest.config.*`, etc.) |
| 16  | to-prd                      | `https://github.com/mattpocock/skills`                    | `to-prd`                      | Opt-in (off by default)                                         |
| 17  | ui-ux-pro-max               | `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` | `ui-ux-pro-max`               | Frontend detected                                               |
| 18  | caveman                     | `https://github.com/JuliusBrussee/caveman`                | `caveman`                     | Always (default on) — appends comm-style nudge ¹                |
| 19  | ponytail                    | `https://github.com/DietrichGebert/ponytail`              | `ponytail`                    | Always (default on) — appends build-discipline nudge ¹          |
| 20  | ponytail-review             | `https://github.com/DietrichGebert/ponytail`              | `ponytail-review`             | Opt-in (over-engineering review)                                |
| 21  | ponytail-audit              | `https://github.com/DietrichGebert/ponytail`              | `ponytail-audit`              | Opt-in (whole-repo over-engineering audit)                      |
| 22  | ponytail-debt               | `https://github.com/DietrichGebert/ponytail`              | `ponytail-debt`               | Opt-in (harvest `ponytail:` debt comments)                      |
| 23  | design-taste-frontend       | `https://github.com/Leonxlnx/taste-skill`                 | `design-taste-frontend`       | Frontend detected (anti-slop landing/portfolio design)          |
| 24  | redesign-existing-projects  | `https://github.com/Leonxlnx/taste-skill`                 | `redesign-existing-projects`  | Frontend detected (upgrading existing UI)                       |
| 25  | high-end-visual-design      | `https://github.com/Leonxlnx/taste-skill`                 | `high-end-visual-design`      | Frontend detected (agency-grade visual polish)                  |
| 26  | minimalist-ui               | `https://github.com/Leonxlnx/taste-skill`                 | `minimalist-ui`               | Frontend detected (clean editorial minimalism)                  |
| 27  | industrial-brutalist-ui     | `https://github.com/Leonxlnx/taste-skill`                 | `industrial-brutalist-ui`     | Frontend / data-dashboard detected (brutalist telemetry)        |

¹ **caveman + ponytail (base skills only)** carry a mode: after a successful install
they append a short nudge block to the host doc (`CLAUDE.md` and/or `AGENTS.md`) so the
mode is discoverable — `# Communication style` for caveman, `# Build discipline` for
ponytail. The `ponytail-review`/`ponytail-audit`/`ponytail-debt` sub-tools and all other
external skills append nothing. (These two were previously in
`third-party-plugins-catalog.md`; they moved here once both shipped as skills-CLI
packages. Graphify stays a third-party plugin — it's a Python tool, not a skill.)

## Adding your own

Any GitHub repo whose skills live under `skills/<name>/SKILL.md` works — add a row with
the repo URL and the `--skill` name. To discover what a repo offers:

```bash
bunx skills add <repo-url> --list
```

## Notes

- **`-a <adapter> -y`** targets the detected host's agent and runs non-interactively:
  `claude-code` (→ `.claude/skills/`) or `antigravity-cli` (→ `.agents/skills/`). Never
  hard-code `claude-code` under Antigravity — it would leak skills into `.claude/skills/`.
  Run from the project directory for a project-level install; add `-g` for a user-level
  (global) install.
- **`--skill <name>`** installs one named skill from a multi-skill repo. Omit it to be
  prompted, or use `--skill '*'` to install all skills in the repo.
- Record installed skill names in `.setup-log.json`.
