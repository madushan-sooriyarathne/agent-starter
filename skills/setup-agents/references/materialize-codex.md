# Materialize Codex

Apply the approved rows for `codex` in the current project. If Antigravity is
also selected, this path owns the shared `AGENTS.md` and portable skills.
Antigravity owns its separate rules, hooks, and agent personas.

- **Agents** use `.codex/agents/<name>.toml`. The writer converts each canonical
  agent's name, description, and language-tailored body into native Codex
  fields. Reviewers use the read-only sandbox. Existing agents are kept.
- **Guidance** uses `.codex/guidance/<name>.md` with the source applicability
  globs. `AGENTS.md` links to those files. If the user keeps an existing
  `AGENTS.md` verbatim, tell them when they need to link the guidance manually.
  Codex execution-policy `.rules` files have a separate purpose.
- **Hooks** use `.codex/hooks.json` and `.codex/hooks/agent-starter/`. The
  command guard runs on Bash. The file, secret, artifact, and post-edit checks
  use `apply_patch` events. Lint and type checks can request one continuation
  through `Stop`. The hook writer preserves unrelated registrations and skips
  registration when the project already defines inline TOML hooks.
- **Skills** use `.agents/skills/<name>/SKILL.md`. Existing directories are
  preserved. Leave Claude-specific `claude-md` and `context-budget` out of the
  Codex-only plan. The `codex` skills adapter also installs to this directory.
- **MCP** has no entries in the current setup catalog. Keep existing project
  `.codex/config.toml` settings.

Run the bundled writer after approval. Use actual selections and shell-quote
each argument. Supply one flag per selected component. Run `--doc create` for
a new root document, `--doc merge` to append the approved Codex guidance index,
or `--doc keep` for no document write. If the approved plan merges other
project-specific text, make only those approved edits separately.

```bash
bash "$BUNDLE/template/scripts/materialize-codex.sh" "$PROJECT" \
  --lang go --source-dir internal --doc create \
  --agent code-reviewer --rule golang --skill qplan --hook protect-files
```

For external skills, use the exact catalog repo and slug with
`bunx skills add <repo> --skill <slug> -a codex -y` from the project. Skip
existing same-name skill directories. When Codex and Antigravity are both
selected, use the `codex` adapter once for their shared skill directory.
Append mode nudges only for successful installs and only when the approved
document action allows them.

For an approved re-tailor, refresh only existing language-marker blocks.
Pass `--refill-agent <name>` to the writer for generated TOML agents. It
round-trips the `developer_instructions` field and keeps the other fields.
Keep unknown files and existing shared skills. If the installed config includes
`AGENTS.override.md`, report that Codex reads it in preference to `AGENTS.md`.
Report hook trust as a separate user step through `/hooks`.
