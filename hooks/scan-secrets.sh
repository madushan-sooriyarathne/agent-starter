#!/usr/bin/env bash
#
# scan-secrets.sh
# Hook: PreToolUse / Write|Edit
#
# Scans the content about to be written/edited for hardcoded secrets.
# Reads the tool-call JSON from stdin. Exit 0 = allow, exit 2 = block
# (the stderr message is fed back to Claude).
#
# Tier A (always block): provider key/token shapes that are almost never
#   false positives (OpenAI/Anthropic sk-, GitHub tokens, AWS AKIA, Slack
#   xox-, Google AIza, PEM private keys).
# Tier B (block unless placeholder): DB connection strings with embedded
#   credentials and generic name=value secret assignments. Skipped when the
#   value is clearly a placeholder or an env-var reference.
#
# Pure bash + an optional JSON parser (python3/node). Without a parser it
# degrades to Tier A scanning of the raw payload.

set -uo pipefail

INPUT="$(cat)"

# --- Extract the text being written (content + new_string + edits[]) -------
extract_payload() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
ti = d.get("tool_input") or {}
parts = []
for k in ("content", "new_string"):
    v = ti.get(k)
    if isinstance(v, str):
        parts.append(v)
for e in (ti.get("edits") or []):
    if isinstance(e, dict) and isinstance(e.get("new_string"), str):
        parts.append(e["new_string"])
sys.stdout.write("\n".join(parts))
' 2>/dev/null && return 0
  fi
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$INPUT" | node -e '
let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const ti=(JSON.parse(s).tool_input)||{};let p=[];for(const k of ["content","new_string"]){if(typeof ti[k]==="string")p.push(ti[k]);}for(const e of (ti.edits||[])){if(e&&typeof e.new_string==="string")p.push(e.new_string);}process.stdout.write(p.join("\n"))}catch(e){process.exit(3)}});
' 2>/dev/null && return 0
  fi
  return 3
}

extract_file_path() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = (d.get("tool_input") or {}).get("file_path", "")
sys.stdout.write(v if isinstance(v, str) else "")
' 2>/dev/null && return 0
  fi
  printf '%s' "$INPUT" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

FILE_PATH="$(extract_file_path)"

# Files meant to hold placeholders/examples — do not scan.
case "$FILE_PATH" in
  *.example|*.sample|*.template|*.dist|*.lock|*.md|*.mdx) exit 0 ;;
esac

if PAYLOAD="$(extract_payload)"; then
  PARSED=1
else
  PARSED=0
  PAYLOAD="$INPUT"   # no parser: scan raw payload, Tier A only
fi

[ -z "$PAYLOAD" ] && exit 0

block() {
  echo "BLOCKED by scan-secrets hook: possible hardcoded secret detected ($1)." >&2
  if [ -n "$FILE_PATH" ]; then echo "  File: $FILE_PATH" >&2; fi
  echo "  Move secrets to an untracked .env file and read them via environment variables." >&2
  echo "  If this is a false positive (e.g. an example value), put it in a *.example file." >&2
  exit 2
}

# --- Tier A: high-confidence token shapes ---------------------------------
TIER_A='sk-(ant-|proj-)?[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|ghs_[A-Za-z0-9]{36}|ghr_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
if printf '%s' "$PAYLOAD" | grep -Eq "$TIER_A"; then
  match="$(printf '%s' "$PAYLOAD" | grep -Eo "$TIER_A" | head -n1)"
  block "token pattern: ${match:0:8}…"
fi

# Without a parser, stop after Tier A to avoid false positives on raw JSON.
[ "$PARSED" -eq 0 ] && exit 0

# --- Tier B: connection strings + generic secret assignments --------------
PLACEHOLDER='xxx|your[_-]?|example|changeme|change-me|placeholder|dummy|redacted|sample|test[_-]?key|<[^>]+>|\*\*\*|\.\.\.|process\.env|import\.meta\.env|\$\{|os\.environ|getenv|localhost|127\.0\.0\.1|:password@|:postgres@|:root@|:pass@|:user@|:secret@'

CONN='(postgres|postgresql|mysql|mysql2|mongodb)(\+srv)?://[^:@[:space:]/"]+:[^@[:space:]/"]+@[^[:space:]/"]+'
hits="$(printf '%s' "$PAYLOAD" | grep -Ei "$CONN" | grep -Eiv "$PLACEHOLDER" || true)"
if [ -n "$hits" ]; then
  block "database connection string with embedded credentials"
fi

GENERIC='(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|private[_-]?key)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}["'"'"']'
hits="$(printf '%s' "$PAYLOAD" | grep -Ei "$GENERIC" | grep -Eiv "$PLACEHOLDER" || true)"
if [ -n "$hits" ]; then
  block "hardcoded credential assignment"
fi

exit 0
