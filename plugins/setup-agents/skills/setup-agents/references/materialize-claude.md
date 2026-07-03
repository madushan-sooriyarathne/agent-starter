# Materialize — Claude Code (`.claude/` + `CLAUDE.md`)

Reached when `claude` is in `TARGETS`. Applies the approved Step 3 plan to the
Claude Code tree. Uses the `claude-code` skill adapter. Read the bundle root and
plan from `references/scan-and-plan.md`.

## Step 4 — Install

Apply the approved plan exactly:

- **Agents:** create `.claude/agents/`; copy each selected
  `${BUNDLE}/template/agents/<name>.md` → `.claude/agents/<name>.md`.
- **Rules:** create `.claude/rules/`; copy each selected
  `${BUNDLE}/template/rules/<name>.md` → `.claude/rules/<name>.md`. For any
  copied rule that carries a `paths:` frontmatter block, rewrite the globs to
  the real source/migration/frontend dirs found in Step 1 (with monorepo
  package prefixes, e.g. `apps/web/src/api/**`, when applicable). Show the
  rewritten frontmatter before writing — never leave a rule's `paths:` pointing
  at a directory structure the project doesn't have.
- **Hooks:** create `.claude/hooks/`; copy each selected hook script from
  `${BUNDLE}/template/hooks/` → `.claude/hooks/`, `chmod +x` them, then merge
  the matching registration entries into `.claude/settings.json` (create if
  missing; merge without clobbering existing hooks; do not duplicate an entry
  that already exists; only add entries for hooks actually selected). Use the
  JSON shape in `references/hooks-catalog.md`. When generating
  `permissions.allow`, include only commands that actually exist in this
  project (real script names from the manifest read in Step 1, real `gh`
  subcommands only if a GitHub remote + `gh` were detected) — never paste in a
  generic allow-list wholesale.
- **Third-party plugins:** read `references/third-party-plugins-catalog.md` for exact
  install sequences. Apply in this order for each selected plugin:
  - **Caveman:** run `bunx skills add JuliusBrussee/caveman -a claude-code -y` from the
    project directory (project-scoped) — lands the skill in `.claude/skills/`. Then
    append the caveman context snippet from the catalog to `CLAUDE.md`.
  - **Ponytail:** Ponytail uses the Claude Code native plugin system and installs to
    `~/.claude/` (user-scoped, not project-scoped). Print the two in-session commands
    for the user to run manually:
    ```
    /plugin marketplace add DietrichGebert/ponytail
    /plugin install ponytail@ponytail
    ```
    Tell the user to restart Claude Code after running them. Then append the ponytail
    CLAUDE.md snippet from the catalog.
  - **Graphify:** detect a Python package manager by priority `uv` → `pipx` → `pip`
    (`uv tool install graphifyy`, else `pipx install graphifyy`, else
    `pip install graphifyy`). If none is on PATH, warn and skip with a note to install
    `uv` first (`curl -LsSf https://astral.sh/uv/install.sh | sh`). After install run
    `graphify install --project`, append the graph-report CLAUDE.md snippet from the
    catalog, then tell the user to run `/graphify .` in Claude Code to build the graph
    and to commit `graphify-out/` so teammates share it.
  Treat all third-party plugin install failures as non-fatal — log the failure, skip
  that plugin, and continue.
- **Skills:** handle the two groups separately:
  - **Bundled skills:** no action required — they are already available via the plugin.
    Log each selected bundled skill as "available (bundled)" in the summary.
  - **External skills:** for each selected external skill, run
    `bunx skills add <repo-url> --skill <skill-name> -a claude-code -y` from the
    project directory (repo URL and skill name from the catalog) → writes
    `.claude/skills/`. Private repos (e.g. `madushan/next-pro-seo`) need `gh auth` —
    treat an auth failure as non-fatal and continue. There is no marketplace/plugin
    install step.
- **CLAUDE.md:** if selected, copy `${BUNDLE}/template/CLAUDE.md`
  → `./CLAUDE.md`. Then run the budget check: `grep -cv '^[[:space:]]*$' CLAUDE.md`.
  - Under 25 non-blank lines: pass, no message needed.
  - 25-50: warn — list the longest sections, ask the user (one
    `AskUserQuestion`) which to trim.
  - Over 50: must propose specific cuts and keep trimming until ≤50 before
    moving on.
- **Removals (gap-analysis mode only):** for each file the approved plan marks
  `remove`, delete it individually (never a bulk `rm`) and confirm immediately
  after — list what was removed and why in the summary. Never remove a file that
  doesn't appear in the approved plan table.

## Step 5 — Finalize

If the `session-start` hook was installed, write the drift fingerprint so the
setup stays tuned over time:

```bash
[ -x .claude/hooks/session-start.sh ] && AGENT_STARTER_FINGERPRINT=1 .claude/hooks/session-start.sh > .claude/.agent-starter.json
```

This hashes the project's manifests (`hooks/claude/session-start.sh` already
implements this mode and already reads `.claude/.agent-starter.json` back for
the drift nudge — nothing to build here, just invoke it). From then on,
`session-start` emits a one-line "config drift" nudge whenever the manifests
change (new scripts, new framework, new package manager) — the signal to re-run
`/setup-agents`. Tell the user to commit this file so the whole team shares the
baseline.

If `session-start` was not installed, skip this and tell the user to re-run
`/setup-agents` (or `/setup-claude`) manually after stack changes — there is no
other drift signal.

Do not write any other install-record file. Gap-analysis mode reads `.claude/`
directly on every run instead of relying on a separate JSON record.

## Step 6 — Verify and report

1. **Mechanical checks:** every hook wired in `settings.json` has a matching
   executable file under `.claude/hooks/`; every installed `.md`/`.json` file
   parses (YAML frontmatter, JSON); nothing was installed or removed outside
   the approved Step 3 plan.
2. **Always-loaded token estimate:** `CLAUDE.md` + rules with no `paths:`
   frontmatter (e.g. `code-quality.md`, `testing.md`), chars/4. Report the
   number; if it's over ~1000 tokens, propose the single biggest trim.
3. **CLAUDE.md budget verdict:** PASS / WARN / FAIL per the thresholds in
   Step 4, restated here for the summary.
4. **Summary:** three lists — installed (with the evidence that justified
   each), skipped (with reason), removed (with reason, gap-analysis mode only).
   Tell the user to **restart Claude Code** so the new agents, rules, and hooks
   are picked up.

(When `TARGETS` also has `agy`, run `references/materialize-agy.md` too and
combine both reports into one summary.)
