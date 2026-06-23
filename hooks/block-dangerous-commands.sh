#!/usr/bin/env bash
#
# block-dangerous-commands.sh
# Hook: PreToolUse / Bash
#
# Blocks a small set of catastrophic shell commands before they run.
# Reads the tool-call JSON from stdin. Exit 0 = allow, exit 2 = block
# (the stderr message is fed back to Claude).
#
# Blocked: rm -rf on root/home, DROP TABLE, TRUNCATE,
#          git push --force (without --force-with-lease),
#          git commit --no-verify.
#
# Best-effort safety net, not a sandbox. Pure bash + an optional JSON
# parser (python3/node) with a sed fallback; no required dependencies.

set -uo pipefail

INPUT="$(cat)"

# --- Extract tool_input.command (decoded). Falls back to sed. -------------
extract_command() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
v = (d.get("tool_input") or {}).get("command", "")
sys.stdout.write(v if isinstance(v, str) else "")
' 2>/dev/null && return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$INPUT" | node -e '
let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const v=((JSON.parse(s).tool_input)||{}).command;process.stdout.write(typeof v==="string"?v:"")}catch(e){process.exit(3)}});
' 2>/dev/null && return 0
  fi
  # Last resort: pull the command field out with sed (single value, best effort).
  printf '%s' "$INPUT" \
    | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' \
    | head -n1
}

CMD="$(extract_command)"
# If we could not isolate the command, scan the whole payload instead.
[ -z "$CMD" ] && CMD="$INPUT"

block() {
  echo "BLOCKED by block-dangerous-commands hook: $1" >&2
  echo "If this is genuinely intended, run it yourself in a terminal." >&2
  exit 2
}

# --- rm -rf on root or home ----------------------------------------------
has_rm_recursive_force() {
  printf '%s' "$CMD" | grep -Eq '(^|[^[:alnum:]_./-])rm([^[:alnum:]_]|$)' || return 1
  # combined flag containing both r and f (any order/case): -rf, -fr, -Rf, -rvf...
  if printf '%s' "$CMD" | grep -Eiq -- '-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r'; then return 0; fi
  # separate flags: -r ... -f
  if printf '%s' "$CMD" | grep -Eiq -- '(^|[^a-z-])-r([^a-z]|$)' \
     && printf '%s' "$CMD" | grep -Eiq -- '(^|[^a-z-])-f([^a-z]|$)'; then return 0; fi
  return 1
}
targets_root_or_home() {
  printf '%s' "$CMD" | grep -Eq -- '[[:space:]](/|~|\$HOME)([[:space:]]|$)' && return 0
  printf '%s' "$CMD" | grep -Eq -- '[[:space:]]/\*' && return 0
  printf '%s' "$CMD" | grep -Eq -- '[[:space:]]~/' && return 0
  return 1
}
if has_rm_recursive_force && targets_root_or_home; then
  block "recursive force-delete targeting / or home directory (rm -rf)."
fi

# --- Destructive SQL ------------------------------------------------------
if printf '%s' "$CMD" | grep -Eiq 'drop[[:space:]]+table'; then
  block "DROP TABLE statement."
fi
if printf '%s' "$CMD" | grep -Eiq '(^|[^a-z])truncate([^a-z]|$)'; then
  block "TRUNCATE statement."
fi

# --- git push --force without --force-with-lease --------------------------
if printf '%s' "$CMD" | grep -Eiq 'git[[:space:]]+push'; then
  if printf '%s' "$CMD" | grep -Eq -- '--force([^-]|$)' \
     || printf '%s' "$CMD" | grep -Eq -- '[[:space:]]-f([[:space:]]|$)'; then
    if ! printf '%s' "$CMD" | grep -Eq -- '--force-with-lease'; then
      block "git push --force. Use --force-with-lease instead."
    fi
  fi
fi

# --- git commit --no-verify (bypasses hooks) -----------------------------
if printf '%s' "$CMD" | grep -Eiq 'git[[:space:]]+commit' \
   && printf '%s' "$CMD" | grep -Eq -- '--no-verify'; then
  block "git commit --no-verify bypasses pre-commit hooks."
fi
if printf '%s' "$CMD" | grep -Eiq 'git[[:space:]]+push' \
   && printf '%s' "$CMD" | grep -Eq -- '--no-verify'; then
  block "git push --no-verify bypasses pre-push hooks."
fi

exit 0
