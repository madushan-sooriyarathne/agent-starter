# Third-Party Plugins Catalog

Plugins with post-install actions that **don't fit the skills CLI** — they install a
system tool and/or write config into the project. Kept as a separate category from
skills so the post-install actions are applied consistently.

> **Moved out:** Caveman and Ponytail used to live here. Both now ship as skills-CLI
> packages and live in `skills-catalog.md` under **External Skills**. This catalog is
> **Graphify only**. The base `caveman`/`ponytail` skills still append their mode nudge
> to the host doc on install — that behavior moved with them (see the skills catalog's
> footnote).

Graphify is **pre-marked by default** (user must explicitly deselect).

---

## Install mechanisms

### Graphify — codebase knowledge graph

| Field        | Value                                                                        |
| ------------ | ---------------------------------------------------------------------------- |
| Repo         | `https://github.com/safishamsi/graphify`                                     |
| Install cmd  | `uv tool install graphifyy` (system-level) then `graphify install --project` |
| Scope        | System tool + project doc config                                             |
| Default      | ✅ pre-selected                                                              |
| Prerequisite | Python 3.10+ and `uv`, `pipx`, or `pip` on PATH                              |

**Install sequence (run from project directory):**

```bash
# 1. Install the system tool by package-manager priority (uv puts it on PATH automatically)
uv tool install graphifyy      # preferred
# else: pipx install graphifyy
# else: pip install graphifyy   # may need manual PATH setup

# 2. Register with Claude Code for this project
graphify install --project
```

Then tell the user to run `/graphify .` in a Claude Code session to build the
initial knowledge graph. If none of `uv`/`pipx`/`pip` is on PATH, warn and skip
with a note to install `uv` first (`curl -LsSf https://astral.sh/uv/install.sh | sh`).

**Post-install — append this rule to the host doc (`CLAUDE.md` and/or `AGENTS.md`):**

```markdown
# Codebase graph

Before searching raw files for architecture questions, read `graphify-out/GRAPH_REPORT.md`
for god nodes and community structure. Use it to locate high-impact files before grepping.
```

**Team setup note:** commit `graphify-out/` so teammates get the graph immediately.

---

## Handling in setup-agents flow

1. Present Graphify **pre-marked by default**.
2. Check prerequisites before running: verify `uv`, `pipx`, or `pip` is on PATH
   (priority order: `uv` → `pipx` → `pip`); if none found, warn and skip with a note to
   install `uv` first (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
3. On success, run `graphify install --project`, append the graph-report snippet to the
   host doc, then tell the user to run `/graphify .` and commit `graphify-out/`.
4. Treat install failure as non-fatal — log the failure, skip, and continue with the
   rest of setup.
