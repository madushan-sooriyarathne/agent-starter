---
name: setup-agents
description: >
  This skill should be used when the user runs "/setup-agents" or asks to
  "set up my project for both Claude Code and Antigravity", "scaffold both
  .claude and .agents", "install my agent config everywhere", or "configure
  Claude and Antigravity for this codebase". It scans the current project for
  its actual stack (JS/TS, Python, Go, Rust, Ruby, Java, or anything else
  evidence supports), then interactively installs review agents, rules,
  deterministic hooks, recommended skills, and a CLAUDE.md/AGENTS.md template —
  targeting BOTH hosts (Claude Code → .claude/, Antigravity → .agents/)
  regardless of which host it runs in — with deeper built-in signals for a
  Next.js / Turborepo / Hono+Bun / Drizzle / BetterAuth / Sanity / Biome stack
  where present. For a single host, use /setup-claude or /setup-agy instead.
metadata:
  version: "0.8.0"
---

# /setup-agents

Scaffold a tailored agent workspace into the current project for **both** Claude
Code and Antigravity. This skill is the in-session entry point; `install.sh` at
the plugin root (platform option "Both") is the terminal equivalent and runs the
same flow.

**Targets are fixed, not detected:** `TARGETS = {claude, agy}`,
`ADAPTERS = claude-code, antigravity-cli`. It writes both `.claude/` + `CLAUDE.md`
and `.agents/` + `AGENTS.md` no matter which host you are invoked from. For a
single host, tell the user to use `/setup-claude` or `/setup-agy`.

## Flow

1. **Scan → confirm → plan (once).** Read `references/scan-and-plan.md` and run
   it end to end with `TARGETS = {claude, agy}`. The scan, stack confirmation,
   tier pick, category selection, and Step 3 plan table all happen a single time
   and cover both hosts.
2. **Materialize both.** With the plan approved, apply it to each host:
   - `references/materialize-claude.md` → `.claude/` + `CLAUDE.md`
   - `references/materialize-agy.md` → `.agents/` + `AGENTS.md`
     The two trees are written independently — real files in each, no symlinks
     between them. Rules and project-doc content are identical across hosts but are
     deliberately written twice (portable, no symlink fragility).
3. **One combined report.** Merge both materializers' checks into a single
   summary (installed / skipped / removed). Tell the user to restart Claude Code
   **and** reload Antigravity.

External skills — including caveman and ponytail — install once per adapter in
`ADAPTERS`; the base caveman/ponytail skills also append a mode nudge to the host
doc. Graphify (the sole third-party plugin) installs once as a system tool.
Everything else in
`references/scan-and-plan.md` — the governing principle, gap-analysis mode, and
guardrails — applies as written. When either host already has config
(`.claude/`+`CLAUDE.md` or `.agents/`+`AGENTS.md`), that host takes the
gap-analysis fork (Step 1.7): missing items offered, orphans flagged, each
one-shot or per-category — instead of the fresh-install tiers.
