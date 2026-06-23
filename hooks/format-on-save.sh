#!/usr/bin/env bash
#
# format-on-save.sh
# Hook: PostToolUse / Write|Edit
#
# Runs `biome check --write` on the file that was just written/edited.
# Reads the tool-call JSON from stdin. ALWAYS exits 0 — it must never block
# or error a write. No-ops silently when:
#   - the file is not a .ts/.tsx file
#   - no biome.json/biome.jsonc is found at or above the file
#   - no biome binary is resolvable
#
# Pure bash + an optional JSON parser (python3/node). bunx is used only as a
# last resort to obtain biome.

set -uo pipefail

INPUT="$(cat)"

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
  if command -v node >/dev/null 2>&1; then
    printf '%s' "$INPUT" | node -e '
let s="";process.stdin.on("data",d=>s+=d);process.stdin.on("end",()=>{try{const v=((JSON.parse(s).tool_input)||{}).file_path;process.stdout.write(typeof v==="string"?v:"")}catch(e){}});
' 2>/dev/null && return 0
  fi
  printf '%s' "$INPUT" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

FILE="$(extract_file_path)"
[ -z "$FILE" ] && exit 0

# Only TypeScript/TSX (Biome handles more; widen the case below if desired).
case "$FILE" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Resolve to an absolute path if possible.
if [ "${FILE#/}" = "$FILE" ]; then
  base="${CLAUDE_PROJECT_DIR:-$PWD}"
  FILE="$base/$FILE"
fi
[ -f "$FILE" ] || exit 0

# Walk up from the file's directory to find a biome config.
find_up() {
  local dir="$1" target="$2"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    if [ -e "$dir/$target" ]; then printf '%s' "$dir"; return 0; fi
    dir="$(dirname "$dir")"
  done
  [ -e "/$target" ] && { printf '%s' "/"; return 0; }
  return 1
}

start_dir="$(dirname "$FILE")"
config_dir="$(find_up "$start_dir" biome.json || true)"
[ -z "$config_dir" ] && config_dir="$(find_up "$start_dir" biome.jsonc || true)"
[ -z "$config_dir" ] && exit 0   # no Biome config anywhere above the file

# Resolve a biome binary, preferring a project-local install.
biome_bin=""
bin_dir="$(find_up "$start_dir" node_modules/.bin/biome || true)"
if [ -n "$bin_dir" ] && [ -x "$bin_dir/node_modules/.bin/biome" ]; then
  biome_bin="$bin_dir/node_modules/.bin/biome"
elif command -v biome >/dev/null 2>&1; then
  biome_bin="biome"
fi

if [ -n "$biome_bin" ]; then
  "$biome_bin" check --write "$FILE" >/dev/null 2>&1 || true
elif command -v bunx >/dev/null 2>&1; then
  bunx --bun @biomejs/biome check --write "$FILE" >/dev/null 2>&1 || true
fi

exit 0
