# agent-starter (this repo)

One setup plugin for Claude Code, Antigravity, and Codex. Top-level Bash, Markdown, and JSON sources define the published components.

## Commands

```bash
bash scripts/test.sh                     # ONE gate — run before every commit (aggregates everything below + more)
bash hooks/tests/run-all.sh              # run all hook fixture tests (requires jq)
claude plugin validate . --strict        # validate marketplace + plugin manifests
agy plugin validate plugins/<name>       # validate a single plugin against agy's own schema
./scripts/materialize-agy-skills.sh --check  # verify the generated plugin bundle
bash scripts/test-codex.sh marketplace    # isolated Codex CLI install
```

The test gate checks manifest parity, catalogs, real bundle assets, hook fixtures, and scaffolding in temporary projects. It runs host validation and the Codex install smoke when the corresponding CLIs are available.

## Architecture

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the single source of truth. They reach user projects ONLY via `/setup-agents` scaffolding (see install hosts below), NOT as standalone plugins. **The marketplace ships exactly one plugin: `setup-agents`.** Adding a new agent/skill/rule/hook = drop it in the top-level dir; no per-component plugin dir, no marketplace entry. (History: the repo used to publish ~22 thin wrapper plugins, one per component, each a `plugin.json` + relative symlinks into the top-level dirs — all removed. If reintroducing any wrapper plugin, its source must NOT be `"./"`: with the repo root as plugin root, default component discovery would load every skill/agent into every plugin.)
  - `scripts/materialize-agy-skills.sh` generates all four setup skills and their runtime assets under `plugins/setup-agents/`. Antigravity skips symlinked skill directories and Codex drops symlinked template entries when caching the plugin. Commit the real generated files with the source changes.
- **Language profiles (`lang/<id>.md`)** fill the `<!-- lang:<section> -->` markers in agents, rules, skills, and the CLAUDE.md template at install time (`install.sh`'s `lang_fill`; `skills/setup-agents/references/language-tailoring.md` for the in-session flow). Keep shared component bodies language-neutral — put language-specific commands, idioms, and checklists in the profiles behind a marker, never inline. A new section name must be added to every profile and to `LANG_SECTIONS` in `scripts/test.sh`; a new language needs a profile, a detection line in `install.sh` (`LANGS`), a row in `language-tailoring.md`, and a tailoring smoke in `scripts/test.sh`. Bundled in `plugins/setup-agents/template/lang/`.
- `templates/CLAUDE.template.md` and `templates/AGENTS.template.md` are the target-project instruction templates.
- `templates/settings.json` is the template users copy to `.claude/settings.json`; it wires the hooks.
- **Target project scaffolding** uses `install.sh` or a setup skill. Claude uses `.claude/` and `CLAUDE.md`. Antigravity uses `.agents/`. Codex uses `.codex/` for native agents, guidance and hooks. Antigravity and Codex share root `AGENTS.md` and `.agents/skills/`, with one writer in all-host mode.
- **Plugin distribution** uses `.claude-plugin/marketplace.json` for Claude, `.agents/plugins/marketplace.json` for Codex, and the plugin's root `plugin.json` for local `agy plugin install`. The marketplace entries point at the same `plugins/setup-agents/` bundle. Installing the plugin only makes the setup skills available.
- **Codex port rules:** `scripts/materialize-codex.sh` serves both the terminal and the skill. `hooks/codex/run.sh` adapts native events to the existing checks, with coverage defined in `templates/codex-hooks.json`. Codex applies its normal project and hook trust requirements.
- **Antigravity port rules:** `agy plugin validate` does recognize a native `agents/<name>.md` component, but whether `agy` actually runs it as a delegable subagent at runtime (vs. a passive prompt fragment) is unconfirmed — so agents still ship as skills (`skills/<name>/SKILL.md`, frontmatter reduced to name+description) rather than switching to the native component. `hooks/antigravity/` contains the native Antigravity implementations. All 10 hooks port, **duplicated** not translated: `hooks/antigravity/<name>.sh` reimplements the same detection rules as `hooks/claude/<name>.sh` directly against AG's native contract (always exits 0 — the gate/result lives in stdout), instead of shimming into the Claude-shaped `tool_input`/exit-2 contract. No shared source between the two copies — when detection rules change, mirror the change in both files by hand. `AG_SUPPORTED_HOOKS` in `install.sh` is the eligible set. `hooks/tests/fixtures/` mirrors the same split (`fixtures/claude/<name>/`, `fixtures/antigravity/<name>/`).
  - The 4 safety hooks map 1:1 onto `PreToolUse` (`{"toolCall":{"name","args"}}` stdin / `{"decision","reason"}` stdout). The other 6 needed a redesign, not just a contract swap, because AG's `PostToolUse` carries no tool args at all (confirmed against AG's own hooks docs — stdin is only `{stepIdx, error, conversationId, workspacePaths, ...}`, no file path, no tool name): `typecheck-on-stop`/`lint-on-stop`/`format-on-save`/`auto-test`/`notify` moved to `Stop` (fires once the execution loop is about to fully terminate), using `git status`/`git diff` against `workspacePaths[0]` in place of the Claude-side PostToolUse dirty-marker; `session-start` moved to `PreInvocation` (fires before every model call, gated to `invocationNum==0` to approximate "session start"). `install.sh`'s AG `hooks.json` generator emits two different shapes accordingly: `PreToolUse`/`PostToolUse` get the `matcher`+`hooks[]` wrapper, `PreInvocation`/`PostInvocation`/`Stop` are a flat handler array with no matcher. It writes scripts to `.agents/hooks/<name>.sh` and the config to `.agents/hooks.json` (paths inside point at `.agents/hooks/<name>.sh`).
  - **Unverified**: `typecheck-on-stop.sh` and `lint-on-stop.sh` both request `{"decision":"continue"}` on failure (AG only injects `reason` into the agent's context when `decision` is `"continue"`), guarded by a `conversationId`-keyed `/tmp` marker so each nags at most once per conversation per failing state. AG's `Stop` schema has no `stop_hook_active`-equivalent field, and its docs don't say how multiple independent Stop hooks' `decision` values combine if more than one requests `"continue"` in the same cycle — both are inferred designs, not documented behavior. Needs testing against a real Antigravity instance before relying on it.
  - Skills installed via `agy` (bulk or single-plugin) stage as a full verbatim copy of the plugin directory under `~/.gemini/config/plugins/<name>/` — confirmed by inspecting a real local install. A skill that needs sibling assets outside its own dir (like `setup-agents`'s `template/`) can rely on that path existing, since `$CLAUDE_PLUGIN_ROOT` is not set under Antigravity.
  - `install.sh`'s external skill catalog (`sel_skills`, `caveman`) installs through the Vercel `skills` CLI (`bunx skills add <repo> --skill <name> -a <agent>`), which has project-scoped `claude-code`, `antigravity-cli`, and `codex` adapters. Select one adapter for the shared Antigravity/Codex directory and one for Claude when selected. Optional Graphify project integration remains gated by host.

## Key decisions

- Versioning: keep all three `plugins/setup-agents/` manifests at the same semver. Leave version out of the marketplace entries.
- Hooks fail open (exit 0) when `jq` is missing, except file-protection hooks which fail closed. Hook `timeout` values are in seconds.
- Agents never set `model` — users choose their own. Exception, workflow skills only: `qplan` pins `model: opus` (planning always runs on the most capable tier), and `qcode`/`qcheck`/`qgit` pick a model per subagent dispatch. Both use aliases (`opus`/`sonnet`/`haiku`), never version IDs, so they track the newest model per tier. Delegation happens only when the skill's break-even estimate (subagent work + handoff + monitoring) beats the planning model doing the work inline.
- No unconfirmed URLs get shipped in generated config (e.g. `plugin.json`'s `$schema`) — `agy` has no published schema URL, so none is set, rather than guessing one.

## Workflow

- **Run `bash scripts/test.sh` before every commit** and make it green. It fails closed on any structural break — a new component missing from its catalog, a hook without its antigravity twin or fixtures, mismatched plugin.json versions, broken JSON/bash, or an `install.sh` that no longer scaffolds. It's the enforcement layer for every rule below; the individual commands still exist for targeted runs.
- Every new or modified hook MUST ship with fixtures under `hooks/tests/fixtures/<host>/<hook-name>/` for each supported host.
- After changing any manifest, skill, or agent frontmatter, run `claude plugin validate . --strict`.
- After changing a shipped source, run `./scripts/materialize-agy-skills.sh` and include the regenerated plugin bundle.
- Adding/renaming a skill, agent, rule, or hook = edit the top-level dir only. No marketplace entry, no `plugins/<name>/` dir (the marketplace ships `setup-agents` alone). Ensure `/setup-agents`'s scan/catalog picks up the new component.
