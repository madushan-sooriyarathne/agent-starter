---
name: setup-codex
description: Scaffold or update OpenAI Codex configuration in the current project. Use for setup-codex or requests to configure a repository specifically for OpenAI Codex. Scans the stack and applies the approved Codex setup plan.
metadata:
  version: "0.9.0"
---

# setup-codex

Set `TARGETS = {codex}` regardless of the host running this skill.

1. Read [the shared scan and planning flow](../setup-agents/references/scan-and-plan.md)
   from this skill's installed directory. Scan the current project, confirm the
   stack, and plan the Codex files. Preserve existing shared skills and show the
   action for the root `AGENTS.md`.
2. Apply only [the Codex materializer](../setup-agents/references/materialize-codex.md).
   Write Codex configuration under `.codex/` and selected portable skills under
   `.agents/skills/`.
3. Report installed, kept, and skipped items. Ask the user to start a new Codex
   session and review new project hooks with `/hooks`.

The terminal equivalent from a checkout is `install.sh --host codex`.
