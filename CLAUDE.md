# claude-code-starter (this repo)

A Claude Code plugin marketplace: agents, skills, rules, and safety hooks, published from the top-level directories. There is no application code, build, or package manager here — everything is bash + markdown + JSON.

## Commands

```bash
bash hooks/tests/run-all.sh          # run all hook fixture tests (requires jq)
claude plugin validate . --strict    # validate marketplace + plugin manifests
```

## Architecture

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the single source of truth. `plugins/<name>/` dirs contain only a `plugin.json` plus **relative symlinks** into the top-level dirs (Claude Code dereferences marketplace-internal symlinks at install) — never put real component copies there. Plugin sources must NOT be `"./"`: with the repo root as plugin root, default component discovery would load every skill/agent into every plugin.
- `templaes/CLAUDE.template.md` is the template shipped to user projects by `/setup-agents`. This file (`CLAUDE.md`) is for working on the repo itself — don't confuse the two.
- `templates/settings.json` is the template users copy to `.claude/settings.json`; it wires the hooks.
- **Two install hosts.** `install.sh` (and the `setup-agents` skill) scaffold into either Claude Code (`.claude/` + `settings.json`) or Antigravity (`.agents/plugins/setup-agents/` + `AGENTS.md`); the platform prompt / `WANT_CLAUDE`/`WANT_AG` gate the two materialization paths. Scan + selection are host-agnostic — only how the plan is written to disk differs.
- **Antigravity port rules:** agents have no static AG schema → shipped as skills (`skills/<name>/SKILL.md`, frontmatter reduced to name+description). Only the 4 PreToolUse safety hooks port (AG PostToolUse carries no tool args); they run unchanged behind `hooks/antigravity-adapter.sh`, which maps AG's `toolCall.args` stdin / `{"decision","reason"}` stdout to Claude's `tool_input` / exit-2 `hookSpecificOutput`. `AG_SUPPORTED_HOOKS` in `install.sh` is the eligible set.

## Key decisions

- Versioning: each `plugins/<name>/.claude-plugin/plugin.json` carries semver — bump it when that plugin's components change. Marketplace entries carry NO version (plugin.json silently wins; never set both).
- Hooks fail open (exit 0) when `jq` is missing, except file-protection hooks which fail closed. Hook `timeout` values are in seconds.
- Agents never set `model` — users choose their own.

## Workflow

- Every new or modified hook MUST ship with fixtures under `hooks/tests/fixtures/<hook-name>/`.
- After changing any manifest, skill, or agent frontmatter, run `claude plugin validate . --strict`.
- Adding/renaming a skill or agent requires: marketplace entry, `plugins/<name>/` (plugin.json + symlink).
