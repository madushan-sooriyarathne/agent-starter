# Contributing

Thanks for helping improve **agent-starter**. This repo is a Claude Code plugin
marketplace — agents, skills, rules, and safety hooks published through one
plugin, `setup-agents`. There is **no application code, build, or package
manager**: everything is bash + Markdown + JSON.

## How the repo works

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the **single source of
  truth**. They reach user projects **only** via `/setup-agents` scaffolding —
  never as standalone plugins.
- The marketplace ships **exactly one plugin: `setup-agents`.** Adding a new
  agent/skill/rule/hook means dropping a file in the matching top-level dir. No
  per-component plugin dir, no marketplace entry.
- Two install hosts: **Claude Code** (`.claude/` + `settings.json` + `CLAUDE.md`)
  and **Antigravity** (flat `.agents/` + `hooks.json` + `AGENTS.md`). The scan
  and selection logic is host-agnostic; only how the plan is written to disk
  differs.
- Hooks are **duplicated, not shimmed**, across hosts: `hooks/claude/<name>.sh`
  and `hooks/antigravity/<name>.sh` implement the same detection rules against
  each host's native contract. When detection logic changes, mirror it in both
  files by hand.

For the full architecture and rationale, see [`CLAUDE.md`](CLAUDE.md) and the
per-directory `README.md` files (`agents/`, `rules/`, `hooks/`, `skills/`).

## The one gate

Run this before **every** commit and make it green:

```bash
bash scripts/test.sh
```

It's the single consistency gate — bash syntax, JSON validity, `plugin.json`
version parity, agent/skill frontmatter, hook antigravity-twin + fixture parity,
catalog drift, agy-skill copy freshness, the hook fixture suite, and an
`install.sh` smoke run. It fails **closed** on any structural break. Exit `0` =
shippable. Missing optional CLIs (`claude`, `agy`, `jq`) are skipped, not failed.

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

- Ship fixtures under `hooks/tests/fixtures/<host>/<name>/` (`<host>` = `claude`
  or `antigravity`). No fixtures → the gate fails.
- Hooks fail **open** (exit 0) when `jq` is missing, **except** file-protection
  hooks, which fail closed.
- Hook `timeout` values are in seconds.

### Skills under `skills/setup-agents/`

After editing anything there, regenerate the agy-native copy and commit it
alongside your change:

```bash
./scripts/materialize-agy-skills.sh          # regenerate
./scripts/materialize-agy-skills.sh --check   # verify not stale (no writes)
```

`agy`'s scanner skips symlinked _directories_, so
`plugins/setup-agents/skills/setup-agents/` is a real copy, not a symlink.

## Versioning

Bump the semver in **both**
`plugins/setup-agents/.claude-plugin/plugin.json` and
`plugins/setup-agents/plugin.json` whenever any shipped component changes (they
all reach users through this one plugin). The marketplace entry carries **no**
version — never set both.

## Validating manifests

After changing any manifest, skill, or agent frontmatter:

```bash
claude plugin validate . --strict        # marketplace + plugin manifests
agy plugin validate plugins/setup-agents  # single plugin against agy's schema
```

## Commits & PRs

- Conventional commits (`feat:`, `fix:`, `docs:`, …).
- Never `git push --force` to a shared branch; never `--no-verify`.
- Don't ship unconfirmed URLs in generated config.
- Open a PR against `main` with a clear description of what changed and why.

## License

By contributing, you agree your contributions are licensed under the
[MIT License](LICENSE).
