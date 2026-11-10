# Contributing

Thanks for helping improve **agent-starter**. This repo provides plugin marketplaces for Claude Code and Codex and a local bundle for Antigravity — agents, skills, rules, and safety hooks published through one
plugin, `setup-agents`. There is **no application code, build, or package
manager**: everything is bash + Markdown + JSON.

## How the repo works

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the **single source of
  truth**. They reach user projects **only** via `/setup-agents` scaffolding —
  never as standalone plugins.
- The marketplace ships **exactly one plugin: `setup-agents`.** Adding a new
  agent/skill/rule/hook means dropping a file in the matching top-level dir. No
  per-component plugin dir, no marketplace entry.
- The three hosts share the scan, catalogs, and language profiles. Codex and
  Antigravity share `AGENTS.md` and `.agents/skills/` in the target project.
- Antigravity has its own hook implementations. Codex translates its event
  payloads in `hooks/codex/run.sh` and reuses the checks in `hooks/claude/`.
  List the supported Codex events in `templates/codex-hooks.json`.

For the full architecture and rationale, see [`CLAUDE.md`](CLAUDE.md) and the
per-directory `README.md` files (`agents/`, `rules/`, `hooks/`, `skills/`).

## The one gate

Run this before **every** commit and make it green:

```bash
bash scripts/test.sh
```

It's the single consistency gate — bash syntax, JSON validity, `plugin.json`
version parity, agent/skill frontmatter, hook antigravity-twin + fixture parity,
catalog drift, bundle freshness, the hook fixture suite, and installer and
marketplace smoke tests. It fails **closed** on any structural break. Exit `0` =
shippable. The gate requires `jq`. Host CLI checks run when the corresponding tool is available.

Format everything first:

```bash
bash scripts/format.sh
```

## Adding a component

| You add…  | Do this                                                                                               |
| --------- | ----------------------------------------------------------------------------------------------------- |
| **Agent** | Drop `agents/<name>.md`. Never set `model` — users pick their own.                                    |
| **Rule**  | Drop `rules/<name>.md`. Path-scope with `paths:` frontmatter unless it must load every turn.          |
| **Skill** | Drop `skills/<name>/SKILL.md`.                                                                        |
| **Hook**  | Drop `hooks/claude/<name>.sh` **and** its `hooks/antigravity/<name>.sh` twin. Ship fixtures for both. |

Every new component must also be listed in the matching
`skills/setup-agents/references/*-catalog.md` — the catalog-drift check in
`scripts/test.sh` fails if it isn't.

### Hooks — extra rules

- Ship fixtures under `hooks/tests/fixtures/<host>/<name>/` (`<host>` = `claude`, `antigravity`, or `codex`). Each supported hook needs fixtures.
- Hooks fail **open** (exit 0) when `jq` is missing, **except** file-protection
  hooks, which fail closed.
- Hook `timeout` values are in seconds.

### Generated plugin bundle

After editing any shipped source, regenerate the package and include the result
with your change:

```bash
./scripts/materialize-agy-skills.sh
./scripts/materialize-agy-skills.sh --check
```

Antigravity skips symlinked skill directories, and Codex's install cache omits
symlinked template assets. The bundle contains real files for both.

## Versioning

Keep the versions in `plugins/setup-agents/plugin.json`,
`plugins/setup-agents/.claude-plugin/plugin.json`, and
`plugins/setup-agents/.codex-plugin/plugin.json` in sync. Marketplace entries
inherit the plugin version.

## Validating manifests

After changing any manifest, skill, or agent frontmatter:

```bash
claude plugin validate . --strict        # marketplace + plugin manifests
agy plugin validate plugins/setup-agents  # single plugin against agy's schema
bash scripts/test-codex.sh marketplace    # isolated Codex CLI install
```

## Commits & PRs

- Conventional commits (`feat:`, `fix:`, `docs:`, …).
- Never `git push --force` to a shared branch; never `--no-verify`.
- Don't ship unconfirmed URLs in generated config.
- Open a PR against `main` with a clear description of what changed and why.

## License

By contributing, you agree your contributions are licensed under the
[MIT License](LICENSE).
