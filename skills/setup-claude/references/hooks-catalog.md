# Hooks Catalog

Three deterministic shell hooks, copied from `${CLAUDE_PLUGIN_ROOT}/hooks/` (slash command)
or `$SCRIPT_DIR/hooks/` (install.sh) into the target project's `.claude/hooks/`, then
registered in `.claude/settings.json`.

All hooks read the tool-call JSON from stdin, exit `0` to allow and exit `2` to block
(stderr is fed back to Claude). No external dependencies are required.

| # | Hook | File | Event / matcher | Behavior | Recommend when |
|---|------|------|-----------------|----------|----------------|
| 1 | `block-dangerous-commands` | `block-dangerous-commands.sh` | `PreToolUse` / `Bash` | Blocks `rm -rf` on root/home, `DROP TABLE`, `TRUNCATE`, `git push --force` (without `--force-with-lease`), `git commit/push --no-verify` | **Always pre-mark** |
| 2 | `scan-secrets` | `scan-secrets.sh` | `PreToolUse` / `Write\|Edit` | Blocks writing hardcoded secrets (provider token shapes, DB connection strings with creds, generic secret assignments). Skips `*.example`/`*.sample`/`*.md`; ignores env-var references and placeholders | **Always pre-mark** |
| 3 | `format-on-save` | `format-on-save.sh` | `PostToolUse` / `Write\|Edit` | Runs `biome check --write` on `.ts`/`.tsx` files. No-ops silently if no `biome.json`/`biome.jsonc` found or no biome binary available. Never blocks or errors | `biome.json` or `biome.jsonc` detected |

## settings.json registration

Merge the following into the target's `.claude/settings.json` (create if missing, merge
without clobbering existing hooks). Only include entries for the hooks the user selected.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/block-dangerous-commands.sh\"" }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/scan-secrets.sh\"" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/format-on-save.sh\"" }
        ]
      }
    ]
  }
}
```

Notes:

- The `Write|Edit` matcher (rather than `Write` only) ensures `Edit` operations are also
  scanned/formatted — Edit modifies file contents too.
- `$CLAUDE_PROJECT_DIR` resolves to the project root at runtime, so the registration is
  portable across machines.
- When merging into an existing `settings.json`, append hook entries idempotently — do not
  add a duplicate entry for a hook command that is already registered.
