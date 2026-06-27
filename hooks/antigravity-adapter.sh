#!/usr/bin/env bash
# Antigravity -> Claude hook adapter.
#
# Antigravity and Claude Code share identical safety-hook *logic* but differ in
# their I/O contract. This shim translates an Antigravity PreToolUse stdin
# payload into the Claude-shaped payload the existing hooks/*.sh expect, runs
# the real hook unchanged, then maps its exit-2 + hookSpecificOutput back into
# Antigravity's stdout decision object ({"decision","reason"}).
#
# The wrapped hook is named via the AG_HOOK env var (preferred -- keeps the
# fixture runner able to drive it) or the first positional argument.
#
# Antigravity PreToolUse I/O contract:
#   stdin : {"toolCall":{"name","args":{...}}, ...}
#   stdout: {"decision":"allow|deny|ask|force_ask","reason":"..."}
# The adapter always exits 0; the gate is expressed in stdout, not the exit code.

set -uo pipefail

HOOK_NAME="${AG_HOOK:-${1:-}}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PATH="$HERE/${HOOK_NAME}.sh"

allow() { printf '{"decision":"allow"}\n'; exit 0; }
gate()  { jq -cn --arg d "$1" --arg r "$2" '{decision:$d, reason:$r}'; exit 0; }

# ponytail: no jq -> degrade to "ask" (user confirms) rather than silently
# allowing an unscreened action or hard-blocking all work. Upgrade path: a
# jq-free JSON parse if jq-less environments turn out to be common.
command -v jq >/dev/null 2>&1 || gate "ask" "jq not installed; cannot run safety hook '${HOOK_NAME}'. Confirm manually."

[ -n "$HOOK_NAME" ] && [ -f "$HOOK_PATH" ] || allow

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.toolCall.name // empty')

case "$TOOL" in
  run_command)
    CLAUDE=$(printf '%s' "$INPUT" | jq -c '{tool_name:"Bash", tool_input:{command:(.toolCall.args.CommandLine // "")}}') ;;
  write_to_file)
    CLAUDE=$(printf '%s' "$INPUT" | jq -c '{tool_name:"Write", tool_input:{file_path:(.toolCall.args.TargetFile // ""), content:(.toolCall.args.CodeContent // "")}}') ;;
  replace_file_content)
    CLAUDE=$(printf '%s' "$INPUT" | jq -c '{tool_name:"Edit", tool_input:{file_path:(.toolCall.args.TargetFile // ""), new_string:(.toolCall.args.ReplacementContent // "")}}') ;;
  multi_replace_file_content)
    # Concatenate every replacement chunk so the content scanners see all of it.
    CLAUDE=$(printf '%s' "$INPUT" | jq -c '{tool_name:"Edit", tool_input:{file_path:(.toolCall.args.TargetFile // ""), new_string:([.toolCall.args.ReplacementChunks[]?.ReplacementContent] | join("\n"))}}') ;;
  *)
    allow ;;
esac

OUT=$(printf '%s' "$CLAUDE" | bash "$HOOK_PATH"); RC=$?

if [ "$RC" -ne 0 ]; then
  DEC=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision // "deny"' 2>/dev/null || echo deny)
  REASON=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null || echo "")
  [ -z "$REASON" ] && REASON="Blocked by safety hook '${HOOK_NAME}'."
  case "$DEC" in deny|ask|force_ask) : ;; *) DEC="deny" ;; esac
  gate "$DEC" "$REASON"
fi

allow
