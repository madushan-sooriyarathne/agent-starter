---
name: setup-agy
description: >
  This skill should be used when the user runs "/setup-agy" or asks to "set up
  Antigravity in this project", "scaffold a .agents folder", "add an AGENTS.md
  and skills to this repo", or "configure Antigravity for this codebase". It
  scans the current project for its actual stack (JS/TS, Python, Go, Rust, Ruby,
  Java, or anything else evidence supports), then interactively installs review
  agents (as skills), rules, deterministic hooks, recommended skills, and an
  AGENTS.md template — targeting Antigravity ONLY (flat .agents/ + AGENTS.md),
  even when invoked from Claude Code. For Claude Code use /setup-claude; for both
  hosts use /setup-agents.
metadata:
  version: "0.8.0"
---

# /setup-agy

Scaffold a tailored agent workspace into the current project for **Antigravity
only**. This skill is the in-session entry point; `install.sh` at the plugin
root (platform option "Antigravity") is the terminal equivalent.

**Targets are fixed, not detected:** `TARGETS = {agy}`,
`ADAPTERS = antigravity-cli`. It writes a flat `.agents/` tree + `AGENTS.md` and
never touches `.claude/` — even when invoked from Claude Code.

## Flow

The shared flow lives in the `setup-agents` skill's references (same plugin
bundle). Resolve that directory:

- **Claude Code** — `${CLAUDE_PLUGIN_ROOT}/skills/setup-agents/references/`.
- **Antigravity** — the staged plugin tree at
  `~/.gemini/config/plugins/setup-agents/skills/setup-agents/references/`, or walk
  from this file's own directory to the sibling `../setup-agents/references/`.

Then:

1. **Scan → confirm → plan.** Read `scan-and-plan.md` from that directory and run
   it end to end with `TARGETS = {agy}`.
2. **Materialize.** With the plan approved, apply `materialize-agy.md` →
   `.agents/` + `AGENTS.md`. Do **not** run `materialize-claude.md`.
3. **Report.** Emit the report and tell the user to reload Antigravity.

Ponytail is Claude Code only and is skipped in this mode. Everything else in
`scan-and-plan.md` — the governing principle, gap-analysis mode, and guardrails
— applies as written. When `.agents/`+`AGENTS.md` already exist, this takes the
gap-analysis fork (Step 1.7): missing items offered, orphans flagged, each
one-shot or per-category — instead of the fresh-install tiers.
