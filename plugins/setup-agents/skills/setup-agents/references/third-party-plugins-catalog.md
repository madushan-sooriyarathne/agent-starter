# Third-Party Plugins Catalog

Plugins with post-install configuration actions — they write rules or snippets into the
project's `CLAUDE.md` or `.claude/` to change Claude's default behavior. Presented as a
separate category from skills so the post-install actions are applied consistently.

All three are **pre-marked by default** (user must explicitly deselect).

---

## Install mechanisms

### Caveman — ultra-compressed communication mode

| Field       | Value                                                                                                                                        |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Repo        | `https://github.com/JuliusBrussee/caveman`                                                                                                   |
| Install cmd | `bunx skills add JuliusBrussee/caveman -a <adapter> -y` (`<adapter>` = `claude-code` under Claude Code, `antigravity-cli` under Antigravity) |
| Scope       | Project (skills CLI writes to `.claude/skills/` or `.agents/skills/` per adapter)                                                            |
| Default     | ✅ pre-selected                                                                                                                              |

**Post-install — append to the host context file (`CLAUDE.md`, or `AGENTS.md` under
Antigravity):**

```markdown
# Communication style

Use caveman mode for all responses: drop articles, drop filler words, fragments OK.
Activate with `/caveman` at session start (or load via skill).
```

### Ponytail — lazy senior developer mode (YAGNI enforcer)

| Field            | Value                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------------ |
| Repo             | `https://github.com/DietrichGebert/ponytail`                                                           |
| Install cmd (CC) | In-session: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` |
| Install cmd (AG) | `agy plugin install https://github.com/DietrichGebert/ponytail`                                        |
| Scope            | User-scoped both hosts (CC: `~/.claude/`; AG: `~/.gemini/config/plugins/`; no project-scope flag)      |
| Default          | ✅ pre-selected                                                                                        |

> **Note:** Ponytail installs to the user scope on both hosts (Claude Code → `~/.claude/`,
> Antigravity → `~/.gemini/config/plugins/`), not the project dir. This means it is available
> across all projects for this user. Inform the user before installing.

**Post-install — append to `CLAUDE.md`:**

```markdown
# Build discipline

Apply ponytail (YAGNI) discipline: stop at the first rung of the ladder that holds.
No speculative abstractions, no boilerplate for later. Activate with `/ponytail` or
load via the ponytail skill.
```

**Post-install instruction to user:**

- **Claude Code** — run these two commands in a Claude Code session, then restart Claude Code:

  ```
  /plugin marketplace add DietrichGebert/ponytail
  /plugin install ponytail@ponytail
  ```

- **Antigravity** — run this from a shell, then reload Antigravity:

  ```
  agy plugin install https://github.com/DietrichGebert/ponytail
  ```

### Graphify — codebase knowledge graph

| Field        | Value                                                                        |
| ------------ | ---------------------------------------------------------------------------- |
| Repo         | `https://github.com/safishamsi/graphify`                                     |
| Install cmd  | `uv tool install graphifyy` (system-level) then `graphify install --project` |
| Scope        | System tool + project CLAUDE.md config                                       |
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

**Post-install — append this rule to `CLAUDE.md`:**

```markdown
# Codebase graph

Before searching raw files for architecture questions, read `graphify-out/GRAPH_REPORT.md`
for god nodes and community structure. Use it to locate high-impact files before grepping.
```

**Team setup note:** commit `graphify-out/` so teammates get the graph immediately.

---

## Handling in setup-agents flow

1. Present all three as a batch (AskUserQuestion multi-select, all pre-checked).
2. For each selected plugin, apply its install sequence above in order.
3. All three attempt automated install (shell commands): Caveman + Graphify via their
   tools; Ponytail via `claude plugin` (CC) and/or `agy plugin install <url>` (AG) per
   selected host, non-fatal. On any failure, print the matching manual command from the
   Ponytail entry above and continue with the rest of setup.
4. Check for prerequisites before running:
   - Graphify: verify `uv`, `pipx`, or `pip` is on PATH (priority order: `uv` → `pipx`
     → `pip`); if none found, warn and skip with a note to install `uv` first
     (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
5. After all selected plugins are processed, continue to the Skills step.
