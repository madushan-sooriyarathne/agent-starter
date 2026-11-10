#!/usr/bin/env bash
# Translate Codex events into inputs for the existing agent-starter checks.
set -uo pipefail

hook=${1:-}
dir=$(cd "$(dirname "$0")" && pwd)
policies="$dir/policies"
[ -d "$policies" ] || policies="$dir/../claude"
policy="$policies/$hook.sh"

if ! command -v jq >/dev/null 2>&1; then
  case "$hook" in
    block-dangerous-commands | protect-files | warn-large-files)
      printf '%s\n' "jq is required for the $hook guardrail." >&2
      exit 2
      ;;
  esac
  exit 0
fi

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input") || exit 0
tool=$(jq -r '.tool_name // empty' <<<"$input") || exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input") || exit 0
[ -z "$cwd" ] || cd -- "$cwd" || exit 0

run_policy() { bash "$policy"; }
deny() {
  jq -cn --arg reason "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}
check_policy() {
  local output status=0 reason
  output=$(run_policy) || status=$?
  if [ "$status" -eq 2 ]; then
    reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$output" 2>/dev/null)
    deny "${reason:-Blocked by $hook.}"
  fi
  return "$status"
}

case "$hook:$event:$tool" in
  block-dangerous-commands:PreToolUse:Bash)
    check_policy <<<"$input"
    exit $?
    ;;
  scan-secrets:PreToolUse:apply_patch)
    jq -c '{tool_name:"Write",tool_input:{content:((.tool_input.command // "") | split("\n") |
      map(select(startswith("+")) | .[1:]) | join("\n"))}}' <<<"$input" | {
      # A matched secret needs to be removed from the patch before it can proceed.
      result=$(run_policy)
      status=$?
      if [ "$status" -eq 2 ]; then
        jq -c '.hookSpecificOutput.permissionDecision = "deny"' <<<"$result"
      else
        exit "$status"
      fi
    }
    exit $?
    ;;
  protect-files:PreToolUse:apply_patch | warn-large-files:PreToolUse:apply_patch | \
    format-on-save:PostToolUse:apply_patch | auto-test:PostToolUse:apply_patch | \
    lint-on-stop:PostToolUse:apply_patch | typecheck-on-stop:PostToolUse:apply_patch)
    ;;
  lint-on-stop:Stop: | typecheck-on-stop:Stop:)
    [ "$(jq -r '.stop_hook_active // false' <<<"$input")" != true ] || exit 0
    ;;
  session-start:SessionStart:)
    root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
    result=$(cd "$root" && AGENT_STARTER_META=.codex/.agent-starter.json run_policy </dev/null) || exit $?
    [ -z "$result" ] || jq -cn --arg text "$result" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$text}}'
    exit 0
    ;;
  notify:Stop:)
    [ "$(jq -r '.stop_hook_active // false' <<<"$input")" != true ] || exit 0
    result=$(jq -cn '{message:"Codex reached the end of a turn."}' | AGENT_STARTER_NOTIFY_TITLE=Codex run_policy)
    [ -z "$result" ] || jq -cn --arg text "$result" '{systemMessage:$text}'
    exit 0
    ;;
  *) exit 0 ;;
esac

# Isolate quality-check markers from other hosts and validate the session identifier.
if [[ "$hook" = *-on-stop ]]; then
  session=$(jq -er '.session_id | select(type == "string" and test("^[A-Za-z0-9_-]+$"))' <<<"$input") || exit 0
  input=$(jq -c --arg id "codex-$session" '.session_id = $id' <<<"$input") || exit 0
  if [ "$event" = Stop ]; then
    result=$(run_policy <<<"$input" 2>&1)
    status=$?
    if [ "$status" -eq 2 ]; then
      jq -cn --arg reason "$result" '{decision:"block",reason:$reason}'
      exit $?
    fi
    exit "$status"
  fi
fi

if [ "$event" = PostToolUse ] && jq -e '.tool_response | objects | .is_error == true' <<<"$input" >/dev/null; then
  exit 0
fi

# Include both ends of a move. For post-edit checks, only use surviving files.
paths=$(jq -r --arg event "$event" '(.tool_input.command // "") | split("\n")[] |
  capture("^\\*\\*\\* (?<action>Add File|Update File|Delete File|Move to): (?<path>.+)$") |
  select($event == "PreToolUse" or .action != "Delete File") | .path' <<<"$input") || exit 0
[ -n "$paths" ] || exit 0

while IFS= read -r file; do
  if [ "$hook" = protect-files ]; then
    lower=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    case "/$lower" in
      */.codex/hooks/* | */.codex/hooks.json | */.codex/config.toml)
        deny "Protected Codex configuration: edit $file manually after review."
        ;;
    esac
  fi
  payload=$(jq -c --arg path "$file" '.tool_input = {file_path:$path}' <<<"$input") || exit 1
  if [ "$event" = PreToolUse ]; then
    check_policy <<<"$payload" || exit $?
  elif [ -f "$file" ]; then
    result=$(run_policy <<<"$payload") || exit $?
    [ -z "$result" ] || jq -cn --arg text "$result" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$text}}'
    # Codex consumes a single JSON result. Report the first failing file.
    [ -z "$result" ] || exit 0
  fi
done <<<"$paths"
