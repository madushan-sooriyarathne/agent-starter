---
name: setup-agents
description: Scaffold or update project configuration for Claude Code, Antigravity, and Codex together. Use for setup-agents or requests to configure all three coding agents in a repository. Scans the stack and plans the agents, rules, hooks, skills, and project instructions to install.
metadata:
  version: "0.9.0"
---

# setup-agents

Set `TARGETS = {claude, agy, codex}`. These are the output targets on every host.
For one target, use `setup-claude`, `setup-agy`, or `setup-codex`.

1. Read [the shared scan and planning flow](references/scan-and-plan.md).
   Scan, confirm the stack, and build one plan for all three targets.
2. Apply the Claude, Antigravity, and Codex materializers linked from that flow.
   Give the root `AGENTS.md` and portable `.agents/skills/` entries one plan row
   per path and one writer. The Codex materializer owns those shared writes in
   this mode. Antigravity still installs its agent personas as skills.
3. Report installed, preserved, and removed items together. Mention starting a
   new session in each host and reviewing newly installed Codex hooks.

The terminal equivalent from a checkout is `install.sh --host all`.
