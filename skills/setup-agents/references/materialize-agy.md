# Materialize — Antigravity (`.agents/` + `AGENTS.md`)

Reached when `agy` is in `TARGETS`. Applies the approved Step 3 plan (same scan,
same catalogs, same plan table) to a flat `.agents/` tree plus `AGENTS.md` at
the project root. Uses the `antigravity-cli` skill adapter. Antigravity
discovers this tree natively — no plugin bundle, no `plugin.json`. Read the
bundle root and plan from `references/scan-and-plan.md`.

Target layout:

```
AGENTS.md                  project root — the CLAUDE.md equivalent
.agents/
  skills/<name>/SKILL.md   bundled + agent-derived + external skills, one home
  rules/<name>.md          rules
  hooks/<name>.sh          all hook scripts
  hooks.json               wires the scripts in .agents/hooks/
  mcp_config.json          MCP server config — only if MCPs are selected
  .agent-starter.json      drift fingerprint (session-start hook)
```

Three differences from the Claude path that matter:

- **Agents ship as skills, not as `agy`'s native `agents/<name>.md`.** Whether an
  `agents/` component behaves as a real delegable subagent at runtime (vs.
  Claude's Task-tool subagents) is unconfirmed — so use the verified path: write
  `.agents/skills/<name>/SKILL.md` with frontmatter reduced to `name` +
  `description` and the agent's body carried verbatim. It becomes a `/<name>`
  slash command and lives alongside bundled + external skills in `.agents/skills/`.
- **All 10 hooks port, but 6 needed a redesign, not just a contract swap.**
  The four PreToolUse safety hooks (`block-dangerous-commands`, `scan-secrets`,
  `protect-files`, `warn-large-files`) map 1:1 onto Antigravity's `PreToolUse`.
  The rest can't, because Antigravity's `PostToolUse` carries no tool
  arguments at all (no file path, no tool name) — so `format-on-save`,
  `auto-test`, `typecheck-on-stop`, `lint-on-stop`, and `notify` instead run on
  `Stop` (fires once the execution loop is about to fully terminate), reading
  `git status`/`git diff` against `workspacePaths[0]` in place of a per-edit
  marker; `session-start` runs on `PreInvocation` (fires before every model
  call), gated to `invocationNum==0` to approximate "session start".
- **Project context goes in `AGENTS.md`** at the project root, not `CLAUDE.md`.

## Materialize

- **Rules** → `.agents/rules/<name>.md`, identical markdown; apply the same
  `paths:` rewrite as the Claude path (rewrite globs to the real source dirs
  found in Step 1). When `TARGETS` also has `claude`, this is a second, real
  copy — not a symlink to `.claude/rules/`.
- **Agents** → `.agents/skills/<name>/SKILL.md` per the conversion above.
- **Skills** → `.agents/skills/`. Handle the three groups separately:
  - **Bundled skills** (individually selected): for each, write
    `.agents/skills/<name>/SKILL.md` the same way agents and workflow commands convert
    — **frontmatter reduced to `name` + `description`** (agy is picky about extra keys),
    the body from `${BUNDLE}/template/skills/<name>/SKILL.md` carried verbatim. They are
    **not** installed globally — picked one-by-one and copied per-project. Skip any that
    already exist; log each as "skill (copied)".
  - **Workflow commands** (`qnew`/`qplan`/`qcode`/`qgit`/`qcheck`, when the group was
    selected): for each, write `.agents/skills/<name>/SKILL.md` the same way agents
    convert — **frontmatter reduced to `name` + `description`** (agy is picky about
    extra keys), the body from `${BUNDLE}/template/skills/<name>/SKILL.md` carried
    verbatim. Skip any that already exist; log each as "workflow (copied)".
  - **External skills:** for each selected external skill, run
    `bunx skills add <repo-url> --skill <skill-name> -a antigravity-cli -y` from the
    project directory (repo URL and skill name from the "External Skills" table in
    `references/skills-catalog.md` — always both a repo URL and `--skill`; never the
    display name alone) → writes `.agents/skills/` directly. After a successful install
    of the base `caveman` or `ponytail` skill, append its mode nudge from the
    skills-catalog footnote to `AGENTS.md` (`# Communication style` / `# Build
discipline`); the ponytail sub-tools and all other external skills append nothing.
- **Third-party plugins:** read `references/third-party-plugins-catalog.md` — now
  **Graphify only** (caveman + ponytail install as external skills, above).
  - **Graphify:** host-agnostic Python tool — same detect/install as the Claude path
    (`uv` → `pipx` → `pip`), then `graphify install --project`, append the graph-report
    snippet to `AGENTS.md`, and tell the user to run `/graphify .` and commit
    `graphify-out/`.
    Treat install failure as non-fatal.
- **Hooks** → copy each supported hook's native script from
  `${BUNDLE}/hooks/antigravity/<name>.sh` (not the `hooks/claude/` one —
  Antigravity gets its own duplicated-logic implementation, no translation shim)
  into `.agents/hooks/`, `chmod +x`, then write `.agents/hooks.json`. Two
  different shapes depending on the hook's event:
  - `PreToolUse` (the 4 safety hooks): matcher+hooks wrapper —
    `{"<name>": {"PreToolUse": [{"matcher": "...", "hooks": [{"type":"command","command":"bash \"<abs>/.agents/hooks/<name>.sh\""}]}]}}`.
    Matcher `run_command` for `block-dangerous-commands`, else
    `write_to_file|replace_file_content|multi_replace_file_content`.
  - `PreInvocation`/`Stop` (the other 6): a flat handler array, no matcher —
    `{"<name>": {"Stop": [{"type":"command","command":"bash \"<abs>/.agents/hooks/<name>.sh\""}]}}`
    (`session-start` uses `"PreInvocation"` instead of `"Stop"`).
- **MCP servers** → if any are selected, write `.agents/mcp_config.json`. No MCP
  server is in the current catalog, so normally this file is not written — leave
  it out rather than emitting an empty stub.
- **AGENTS.md** → always at the **project root** (`./AGENTS.md`) — never
  `.agents/AGENTS.md`. Apply the doc action the plan carries (Step 2.6) — never
  silently skip an existing doc, the compare/recommend happens in Step 2.6 — then
  run the same budget check as the Claude path (`grep -cv '^[[:space:]]*$' AGENTS.md`;
  ≤25 pass, 25-50 warn/trim, >50 must trim to ≤50):
  - **Fresh copy** → copy `${BUNDLE}/template/CLAUDE.md` → `./AGENTS.md`.
  - **Replace** → same copy, overwriting the existing root `./AGENTS.md`.
  - **Merge** → keep `./AGENTS.md`, fold in only the template sections it lacks.
  - **Keep existing** → leave `./AGENTS.md` untouched, no write.
- **Drift fingerprint** → if `session-start` was installed, run
  `AGENT_STARTER_FINGERPRINT=1 .agents/hooks/session-start.sh > .agents/.agent-starter.json`
  (mirrors the Claude fingerprint write; `session-start.sh` reads this path back
  by default on its next `invocationNum==0` `PreInvocation`). Tell the user to
  commit it.
- **Removals (gap-analysis mode only):** for each file the approved plan marks
  `remove` under `.agents/`, delete it individually (never a bulk `rm`) and
  confirm after.

The terminal `install.sh` implements exactly this; prefer matching its output.

## Report

1. **Mechanical checks:** `hooks.json` is valid JSON; every hook wired in it has
   a matching executable file under `.agents/hooks/`; every installed
   `.md`/`SKILL.md`/`.json` parses; nothing installed or removed outside the
   approved plan.
2. **Always-loaded token estimate:** `AGENTS.md` + rules with no `paths:`
   frontmatter, chars/4. Report the number; if over ~1000 tokens, propose the
   single biggest trim.
3. **AGENTS.md budget verdict:** PASS / WARN / FAIL per the thresholds above.
4. **Summary:** three lists — installed (with evidence), skipped (with reason),
   removed (with reason, gap-analysis mode only). Tell the user to **reload
   Antigravity** so the new `.agents/` skills, rules, and hooks are picked up.

(When `TARGETS` also has `claude`, run `references/materialize-claude.md` too and
combine both reports into one summary.)
