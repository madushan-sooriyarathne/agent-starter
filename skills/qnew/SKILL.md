---
name: qnew
description: Start a coding session by loading the project instructions and committing to its best practices before any work. Trigger with /qnew.
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
---

Open the session by internalizing this project's rules. Read, then commit — write no code yet.

## Steps

1. **Locate the instruction file.** Read whichever exists at the project root:
   `CLAUDE.md` (Claude Code) or `AGENTS.md` (Antigravity). Also read any `.claude/rules/*.md`
   / `.agents/rules/*.md` and files under `guides/` or `docs/` the instruction file points to.
2. **If none exists**, say so and stop — recommend running `/init` (or `/setup-agents`) to create
   one. Do not invent practices or start coding.
3. **Parse the practices.** Pull out the concrete standards: naming, error handling, testing
   expectations, the required pre-commit/quality gate, commit conventions, and any explicit
   MUST/MUST NOT rules.
4. **Commit and confirm.** State that these govern every change this session, then echo the key
   practices back in a short list (proof of comprehension, not a full reprint).

## Output

Terse. `✓ Read <file> (+N rules)`, then a bulleted list of the practices that will bind the
session. End: `Ready.` Nothing more.

If the instruction file is empty or has no actionable rules, say exactly that and ask the user to
fill it in before continuing.
