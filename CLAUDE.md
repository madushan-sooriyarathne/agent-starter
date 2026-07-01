# claude-code-starter (this repo)

A Claude Code plugin marketplace: agents, skills, rules, and safety hooks, published from the top-level directories. There is no application code, build, or package manager here — everything is bash + markdown + JSON.

## Commands

```bash
bash hooks/tests/run-all.sh              # run all hook fixture tests (requires jq)
claude plugin validate . --strict        # validate marketplace + plugin manifests
agy plugin validate plugins/<name>       # validate a single plugin against agy's own schema
./scripts/materialize-agy-skills.sh --check  # verify plugins/*/skills/ copies aren't stale
```

## Architecture

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the single source of truth. `plugins/<name>/` dirs contain a `plugin.json` plus **relative symlinks** into the top-level dirs (Claude Code dereferences marketplace-internal symlinks at install) — never put real component copies there. Plugin sources must NOT be `"./"`: with the repo root as plugin root, default component discovery would load every skill/agent into every plugin.
  - **Exception: `plugins/<name>/skills/<name>/`.** `agy`'s plugin scanner follows symlinked *files* (that's why `agents/<name>.md` symlinks work) but silently skips symlinked *directories* — so a whole-directory symlink for a skill is invisible to `agy plugin install`. Those are real, generated copies instead, produced by `./scripts/materialize-agy-skills.sh`. Run it (or at least `--check`) after touching anything under `skills/<name>/` and commit both the source and the regenerated copy.
- `templaes/CLAUDE.template.md` is the template shipped to user projects by `/setup-agents`. This file (`CLAUDE.md`) is for working on the repo itself — don't confuse the two.
- `templates/settings.json` is the template users copy to `.claude/settings.json`; it wires the hooks.
- **Two install hosts, two distribution mechanisms.**
  - **Scaffolding a target project** (`install.sh` / the `setup-agents` skill's in-session flow): materializes output into either Claude Code (`.claude/` + `settings.json`) or Antigravity (`.agents/plugins/setup-agents/` + `AGENTS.md`) in a project the user is working on; the platform prompt / `WANT_CLAUDE`/`WANT_AG` gate the two paths. Scan + selection are host-agnostic — only how the plan is written to disk differs.
  - **Installing this repo itself as a plugin**: Claude Code via `claude plugin marketplace add` + `.claude-plugin/marketplace.json` (existing); Antigravity via `agy plugin install <path-to-checkout>` — `agy` auto-detects a `plugins/` dir as a bulk marketplace and reads each `.claude-plugin/plugin.json` directly, no extra manifest needed. `plugins/setup-agents/plugin.json` (root-level, sibling to `.claude-plugin/plugin.json`) is the `agy`-native marker that also lets `agy plugin validate`/`install` target that one plugin directly. There's no confirmed `agy`-native equivalent of `claude plugin marketplace add <owner>/<repo>` yet (`agy plugin link` requires an already-registered marketplace name; no `marketplace add` subcommand was found) — local-path install is the supported flow for now.
- **Antigravity port rules:** `agy plugin validate` does recognize a native `agents/<name>.md` component, but whether `agy` actually runs it as a delegable subagent at runtime (vs. a passive prompt fragment) is unconfirmed — so agents still ship as skills (`skills/<name>/SKILL.md`, frontmatter reduced to name+description) rather than switching to the native component. Only the 4 PreToolUse safety hooks port (AG PostToolUse carries no tool args); they run unchanged behind `hooks/antigravity-adapter.sh`, which maps AG's `toolCall.args` stdin / `{"decision","reason"}` stdout to Claude's `tool_input` / exit-2 `hookSpecificOutput`. `AG_SUPPORTED_HOOKS` in `install.sh` is the eligible set.
  - Skills installed via `agy` (bulk or single-plugin) stage as a full verbatim copy of the plugin directory under `~/.gemini/config/plugins/<name>/` — confirmed by inspecting a real local install. A skill that needs sibling assets outside its own dir (like `setup-agents`'s `template/`) can rely on that path existing, since `$CLAUDE_PLUGIN_ROOT` is not set under Antigravity.
  - `install.sh`'s third-party skill/plugin catalog (`sel_skills`, `caveman`) installs through the Vercel `skills` CLI (`bunx skills add <repo> --skill <name> -a <agent>`), which ships a project-scoped `antigravity-cli` adapter (writes `.agents/skills/`) alongside `claude-code` (writes `.claude/skills/`) — confirmed via the installed package's own adapter registry. `install.sh` runs it once per selected host. `ponytail` (Claude plugin marketplace only) and `graphify` (host-agnostic Python tool) don't have/need that adapter split — see the Step 4c comments in `install.sh`.

## Key decisions

- Versioning: each `plugins/<name>/.claude-plugin/plugin.json` carries semver — bump it when that plugin's components change. Marketplace entries carry NO version (plugin.json silently wins; never set both). `plugins/setup-agents/plugin.json` (the `agy`-native marker) tracks the same version.
- Hooks fail open (exit 0) when `jq` is missing, except file-protection hooks which fail closed. Hook `timeout` values are in seconds.
- Agents never set `model` — users choose their own.
- No unconfirmed URLs get shipped in generated config (e.g. `plugin.json`'s `$schema`) — `agy` has no published schema URL, so none is set, rather than guessing one.

## Workflow

- Every new or modified hook MUST ship with fixtures under `hooks/tests/fixtures/<hook-name>/`.
- After changing any manifest, skill, or agent frontmatter, run `claude plugin validate . --strict`.
- After changing anything under `skills/<name>/`, run `./scripts/materialize-agy-skills.sh` and commit the regenerated `plugins/*/skills/<name>/` copies alongside it.
- Adding/renaming a skill or agent requires: marketplace entry, `plugins/<name>/` (plugin.json + symlink; skills additionally need a materialized copy, see above).
