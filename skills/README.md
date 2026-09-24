# Skills

Skills are slash commands you invoke with `/name`. They run in the main conversation context, so they see all loaded rules and `CLAUDE.md`.

- `disable-model-invocation: true` means manual only. You type `/name` to trigger.
- Without that flag, Claude can also trigger the skill automatically when relevant.

## Available skills

### /setup-agents

**Trigger**: Manual only

Set up agent-starter in any project on an install-nothing-without-evidence basis. Deep-scans the codebase (manifests, real source and test files, directory layout, git workflow, existing AI configs like `.cursorrules`), interviews you about scope and preferences, then proposes an install plan where every rule, hook, agent, and skill is justified by scan evidence. Only the approved plan is copied in, customized to the stack (real commands, real path globs, hooks wired only if installed). On an existing `.claude/` it runs as a gap analysis: add what's missing, propose removing what's unjustified. Confirms every change before applying.

`/setup-agents` targets **both** hosts. Two host-scoped variants share the same scan/plan logic but write only one tree:

### /setup-claude

**Trigger**: Manual only

Same flow as `/setup-agents`, Claude Code only. Writes `.claude/` + `CLAUDE.md`, even when run from Antigravity.

### /setup-agy

**Trigger**: Manual only

Same flow as `/setup-agents`, Antigravity only. Writes `.agents/` + `AGENTS.md`, even when run from Claude Code.

### /debug-fix [issue, error, or description] [--fast]

**Trigger**: Manual only

Find and fix a bug. Default is the careful path: understand, reproduce, investigate, fix, verify, commit. Add `--fast` for emergency production mode: creates a `hotfix/` branch from production, makes the smallest correct change (no refactoring), runs only critical tests, and ships a `[HOTFIX]` PR. Warns if the fix is too complex for fast mode.

### /ship [optional message]

**Trigger**: Manual only

Full shipping workflow with confirmation at every step: scan changes, stage and commit, push, create PR, then optional cleanup of local branches whose remotes are gone. Proposes commit messages and PR descriptions. Blocks secrets, force-push, and push to main.

### /pr-review [PR number | staged | file path]

**Trigger**: Manual only

Reviews code changes by delegating to six specialist agents in parallel (`@code-reviewer`, `@silent-failure-hunter`, `@pr-test-analyzer`, `@security-reviewer`, `@performance-reviewer`, `@doc-reviewer` — each only when the diff warrants it). Synthesis deduplicates, deconflicts overlapping fixes, and buckets findings by confidence. When given a PR number (or auto-detected from branch), also checks PR title, description quality, CI status, unresolved comments, and size. Ends with a clear merge or needs-changes verdict.

### /fix-issue [issue number or URL]

**Trigger**: Manual only

Takes a GitHub issue from number to tested fix: reads the issue body AND comment thread, reproduces, locates the cause, fixes with a regression test, verifies each acceptance criterion, and preps a PR with `Fixes #N` so the merge closes the issue.

### /catchup [handoff | focus area]

**Trigger**: Manual only

Rebuilds working context after `/clear` or a fresh session: reads `.claude/HANDOFF.md` if present, then the branch's commits and changed files, and summarizes goal / done / in-flight / next. Run `/catchup handoff` at the end of a session to write the handoff note (goal, state, gotchas, next step) for the next one.

### /claude-md [audit?]

**Trigger**: Manual only

Keeps `CLAUDE.md` earning its every-turn cost. Default mode captures this session's durable learnings (user corrections, surprising constraints) as one-line additions, each confirmed. `audit` mode verifies every documented command and path still exists, hunts duplication with rules and hooks, and enforces the 25/50 line budget.

### /tdd [feature description]

**Trigger**: Manual only

Strict Test-Driven Development loop. Red: write a failing test for the smallest next behavior. Green: write the minimum code to pass. Refactor: clean up without changing behavior. Repeat. Commits after each green-plus-refactor cycle.

### /explain [file, function, or concept]

**Trigger**: Manual only

Explains code with a one-sentence summary, a mental model analogy, an ASCII diagram, key details, and a modification guide.

### /refactor [target | --diff]

**Trigger**: Manual only

Safe refactoring with tests as a safety net. Writes tests first if none exist, makes changes in small testable steps, verifies no behavior change. `--diff` mode is the pre-commit polish pass: simplifies only the current working diff (inline one-use abstractions, drop dead params and redundant comments) without touching surrounding code.

### /test-writer

**Trigger**: Automatic — after adding a function, endpoint, or component, or changing behavior, when the change has no corresponding test changes. Not for config, docs, or test-only diffs.

Writes comprehensive tests covering every code path: happy path, edge cases, nulls, type boundaries, error paths, concurrency, state transitions. Covers API endpoints, UI components, database operations, and async. Verifies tests actually catch bugs by breaking the code.

### /context-budget [--api]

**Trigger**: Manual only

Estimates the per-turn token cost of this project's `.claude/` configuration and `CLAUDE.md`. Reports always-loaded files (rules without `paths:` plus `CLAUDE.md`), path-scoped rules, and invoked-only agents and skills. Ranks the top contributors and flags entries over budget. Default uses Anthropic's documented `chars/4` heuristic. Add `--api` to call Anthropic's `count_tokens` endpoint for exact counts (requires `$ANTHROPIC_API_KEY`).

## Workflow commands

An opt-in `qnew` → `qplan` → `qcode` → `qcheck` → `qgit` loop, copied into the project by
`/setup-agents` (or `install.sh`) so it travels with the repo. Each is host-neutral — it reads
`CLAUDE.md` or `AGENTS.md`, whichever the host uses.

### /qnew

**Trigger**: Manual only

Discovers the project instruction files from the repo root down, resolves their precedence
(subdirectory over root, user over repo), loads the skills they reference plus the optional
`i-have-adhd`/`caveman`/`ponytail` session defaults when installed, reads the referenced rules, and
notes the package manager, layout, and build/lint/test tooling. Then commits to those practices —
echoes the key ones back and writes no code until it has. Stops if no instruction file exists, and
halts on unresolvable conflicts or a missing required skill.

### /qplan [task description]

**Trigger**: Manual only

Investigates the repo and turns a task into an implementation-ready plan that fits the codebase:
reads the project rules (and `graphify-out/GRAPH_REPORT.md` first when present), reuses existing
helpers/patterns before adding, and proposes the minimal change plus a portable execution handoff.
Saves both to a temp file, shows a TL;DR, then offers to view the detailed plan or copy the handoff
prompt to the clipboard for another model — otherwise run `/qcode` to execute it.

### /qcode [EXECUTION HANDOFF or notes]

**Trigger**: Manual only

Executes the most recent `/qplan` plan (or a pasted `EXECUTION HANDOFF`) without expanding scope:
loads the rules and skills the plan requires, checks the workspace matches the plan, then
implements step by step with targeted validation after each. Finishes with the project's own
quality gate and an `Execution Complete` / `Execution Blocked` report, including any deviations.

### /qcheck [diff | branch | path]

**Trigger**: Manual only

Senior-engineer review of a scope — uncommitted changes by default, or a branch or path — hunting
silent bugs, missed edge cases, error-handling gaps, performance problems, and structural debt,
judged against the project's own rules. Findings are one or two lines each, grouped by severity.
Saves a fix plan (in `/qplan`'s `EXECUTION HANDOFF` format) to a temp file, then offers to show it,
copy it to the clipboard for another model, or run `/qcode` to apply it.

### /qgit

**Trigger**: Manual only

Runs the quality gate, stages changes, and commits with a Conventional Commits message (imperative,
≤72-char subject, no AI-assistant attribution), then pushes after confirmation.

## Adding your own

Create a directory with a `SKILL.md` file:

```
your-skill/
└── SKILL.md
```

```yaml
---
name: your-skill
description: What it does and when to use it
disable-model-invocation: true
---
Your instructions here. Use $ARGUMENTS for user input.
```

See [Claude Code docs](https://code.claude.com/docs/en/skills) for all frontmatter options.
