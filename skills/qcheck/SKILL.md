---
name: qcheck
description: Skeptical senior-engineer review of the session's major changes against the project's own best-practice checklists. Trigger with /qcheck.
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git diff *)
  - Bash(git status)
  - Bash(git log *)
---

Review the substantial changes from this session as a skeptical senior engineer. Question every
major decision — look for problems, do not rubber-stamp.

## Steps

1. **Find the major changes.** Use `git diff` / session history. Focus on new functions,
   significant logic changes, and new files. Ignore formatting, comments, and trivial tweaks.
2. **Load the checklists.** Read the project instructions (`CLAUDE.md` / `AGENTS.md`) and any
   referenced rules for the "Writing Functions", "Writing Tests", and "Implementation" best
   practices. If a checklist is missing, note it and offer to add a tailored one — do not invent
   findings against rules that don't exist.
3. **Review functions.** Naming and clarity, single responsibility and size, parameter/type
   safety, error handling, edge cases, performance implications.
4. **Review tests.** Coverage of the new/changed behavior, isolation, edge and error cases,
   naming, and whether they test behavior rather than implementation.
5. **Review implementation.** Consistency with existing architecture, error-handling patterns,
   security at trust boundaries, duplication vs. reuse, scalability.

## Output

One finding per line: `path:line — <symbol> <problem>. <fix>.` where symbol is ✓ good / ⚠️ concern
/ ✗ violation. Most-severe first. No praise padding, no scope creep. If nothing substantial is
wrong, say so plainly.
