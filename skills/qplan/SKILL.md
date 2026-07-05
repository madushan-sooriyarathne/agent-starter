---
name: qplan
description: Turn a task into an implementation plan that follows the project's own rules, patterns, and existing code. Trigger with /qplan followed by the task.
argument-hint: "[task description]"
disable-model-invocation: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(git status)
  - Bash(git log *)
  - Bash(git diff *)
---

Plan the task in `$ARGUMENTS` so it fits the codebase instead of fighting it. Understand first,
then propose the smallest change that works.

## Steps

1. **Read the rules.** Load the project instructions (`CLAUDE.md` for Claude Code / `AGENTS.md`
   for Antigravity) plus any rules/guides they reference. The plan must obey them.
2. **Map the ground.** If `graphify-out/GRAPH_REPORT.md` exists, read it first for the god nodes
   and community structure before scanning raw files. Then grep for existing functionality,
   patterns, and naming conventions the task touches — trace the real flow end to end.
3. **Reuse before adding.** Find helpers, utilities, types, and patterns already in the repo that
   the task can build on. Prefer extending existing code over new files. No speculative
   abstractions.
4. **Assess the diff.** Determine the minimal set of files to modify vs. create. Note backward-
   compatibility and any callers that must change together (fix at the shared root, not per caller).
5. **Write the plan.** Ordered steps, each naming the exact files and why. Call out the test
   strategy that matches the project's existing test style, and any risks or dependencies.

## Output

A numbered plan: per step, `file(s)` + one line of rationale. Lead with a one-line summary of the
approach and the scope (files touched). Keep it tight — the plan is for acting on, not admiring.
End by offering `/qcode` to implement.
