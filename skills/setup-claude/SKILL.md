---
name: setup-claude
description: >
  This skill should be used when the user runs "/setup-claude" or asks to
  "set up Claude Code in this project", "scaffold a .claude folder", "add a
  CLAUDE.md and agents to this repo", or "configure Claude Code for this
  codebase". It scans the current project for its actual stack (JS/TS, Python,
  Go, Rust, Ruby, Java, or anything else evidence supports), then interactively
  installs review agents, rules, deterministic hooks, recommended skills, and a
  CLAUDE.md template — targeting Claude Code ONLY (.claude/ + CLAUDE.md), even
  when invoked from Antigravity. For Antigravity use /setup-agy; for both hosts
  use /setup-agents.
metadata:
  version: "0.8.0"
---

# /setup-claude

Scaffold a tailored agent workspace into the current project for **Claude Code
only**. This skill is the in-session entry point; `install.sh` at the plugin
root (platform option "Claude Code") is the terminal equivalent.

**Targets are fixed, not detected:** `TARGETS = {claude}`,
`ADAPTERS = claude-code`. It writes `.claude/` + `CLAUDE.md` and never touches
`.agents/` — even when invoked from Antigravity.

## Flow

The shared flow lives in the `setup-agents` skill's references (same plugin
bundle). Resolve that directory:

- **Claude Code** — `${CLAUDE_PLUGIN_ROOT}/skills/setup-agents/references/`.
- **Antigravity** — the staged plugin tree at
  `~/.gemini/config/plugins/setup-agents/skills/setup-agents/references/`, or walk
  from this file's own directory to the sibling `../setup-agents/references/`.

Then:

1. **Scan → confirm → plan.** Read `scan-and-plan.md` from that directory and run
   it end to end with `TARGETS = {claude}`.
2. **Materialize.** With the plan approved, apply `materialize-claude.md` →
   `.claude/` + `CLAUDE.md`. Do **not** run `materialize-agy.md`.
3. **Report.** Emit the Step 6 summary and tell the user to restart Claude Code.

Ponytail (Claude Code only) is available in this mode. Everything else in
`scan-and-plan.md` — the governing principle, gap-analysis mode, and guardrails
— applies as written.
