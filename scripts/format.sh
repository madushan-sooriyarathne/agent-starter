#!/usr/bin/env bash
# format.sh — format every .sh, .json, .md in the repo.
#
#   scripts/format.sh          # write: format files in place
#   scripts/format.sh --check  # check: exit 1 if anything is unformatted
#
# .sh   -> shfmt  (honors .editorconfig: 2-space, indented case)
# .json -> prettier
# .md   -> prettier
#
# No package.json / node_modules: uses shfmt and prettier straight off PATH
# (prettier reads .editorconfig for width/eol). A missing tool is skipped, not
# failed, so this stays green on machines without it — same policy as test.sh.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CHECK=false
[ "${1:-}" = "--check" ] && CHECK=true

FAIL=0
RED=$'\033[31m'
GRN=$'\033[32m'
YEL=$'\033[33m'
RST=$'\033[0m'

# Collect target files, excluding .git. NUL-delimited to survive odd names.
sh_files() { find . -path ./.git -prune -o -name '*.sh' -type f -print0; }
web_files() { find . -path ./.git -prune -o \( -name '*.json' -o -name '*.md' \) -type f -print0; }

# --- shell ------------------------------------------------------------------
if command -v shfmt >/dev/null 2>&1; then
  if $CHECK; then
    diff=$(sh_files | xargs -0 shfmt -d 2>/dev/null)
    if [ -n "$diff" ]; then
      printf '%s✗%s shfmt: shell scripts need formatting (run scripts/format.sh)\n' "$RED" "$RST"
      FAIL=1
    fi
  else
    sh_files | xargs -0 shfmt -w && printf '%s✓%s shfmt: shell formatted\n' "$GRN" "$RST"
  fi
else
  printf '%s•%s shfmt not installed — skipped .sh\n' "$YEL" "$RST"
fi

# --- json + md --------------------------------------------------------------
if command -v prettier >/dev/null 2>&1; then
  if $CHECK; then
    if ! web_files | xargs -0 prettier --check --log-level warn >/dev/null 2>&1; then
      printf '%s✗%s prettier: .json/.md need formatting (run scripts/format.sh)\n' "$RED" "$RST"
      FAIL=1
    fi
  else
    web_files | xargs -0 prettier --write --log-level warn >/dev/null 2>&1 &&
      printf '%s✓%s prettier: json + md formatted\n' "$GRN" "$RST"
  fi
else
  printf '%s•%s prettier not installed — skipped .json/.md\n' "$YEL" "$RST"
fi

exit $FAIL
