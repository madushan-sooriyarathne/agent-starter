#!/usr/bin/env bash
#
# test.sh — one-command consistency + smoke gate for this repo.
#
# Run before every commit (CLAUDE.md workflow). Aggregates every check that
# keeps the marketplace shippable: bash syntax, JSON validity, version parity,
# frontmatter, hook parity, catalog drift, agy-skill copy freshness, the hook
# fixture suite, an install.sh smoke run, and — when the CLIs are installed —
# claude/agy plugin validate.
#
# Pure-bash structural/logic checks fail CLOSED (a real problem fails the run).
# Optional external tools (claude, agy) are SKIPPED when absent, matching the
# hooks' fail-open philosophy. Exit 0 = all pass, 1 = any fail.

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v jq >/dev/null 2>&1 || {
  echo "FATAL: jq required" >&2
  exit 2
}

# All 10 hooks have a native Antigravity twin (mirror of install.sh's list).
AG_SUPPORTED_HOOKS="block-dangerous-commands scan-secrets protect-files warn-large-files typecheck-on-stop lint-on-stop format-on-save auto-test notify session-start"
# Skills that are installer machinery, not user-facing catalog entries.
SKILL_CATALOG_EXCLUDE=" setup-agents setup-agy setup-claude "

CATALOG="skills/setup-agents/references"

PASS=0
FAIL=0
SKIP=0
FAILED=()
pass() {
  printf '  \033[32m✓\033[0m %s\n' "$1"
  PASS=$((PASS + 1))
}
faild() {
  printf '  \033[31m✗\033[0m %s\n' "$1"
  FAIL=$((FAIL + 1))
  FAILED+=("$1")
}
skp() {
  printf '  \033[2m•\033[0m %s\n' "$1"
  SKIP=$((SKIP + 1))
}
group() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# --- 1. bash syntax --------------------------------------------------------
group "bash syntax"
bad=0
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null || {
    faild "syntax error: $f"
    bad=1
  }
done < <(find . -path ./.git -prune -o -name '*.sh' -print)
[ "$bad" = 0 ] && pass "all .sh parse"

# --- 2. JSON validity ------------------------------------------------------
group "JSON validity"
bad=0
while IFS= read -r f; do
  jq empty "$f" 2>/dev/null || {
    faild "invalid JSON: $f"
    bad=1
  }
done < <(find . -path ./.git -prune -o -name '*.json' -print)
[ "$bad" = 0 ] && pass "all .json parse"

# --- 2b. formatting (shfmt + prettier; skips absent tools) ------------------
group "formatting"
if fmt=$(bash scripts/format.sh --check 2>&1); then
  pass "all .sh/.json/.md formatted (or tool absent)"
else
  faild "unformatted files — run scripts/format.sh"
  printf '%s\n' "$fmt" | sed 's/^/    /'
fi

# --- 3. version parity -----------------------------------------------------
group "version parity"
v1=$(jq -r '.version // ""' plugins/setup-agents/.claude-plugin/plugin.json)
v2=$(jq -r '.version // ""' plugins/setup-agents/plugin.json)
if [ -n "$v1" ] && [ "$v1" = "$v2" ]; then
  pass "plugin.json versions match ($v1)"
else
  faild "plugin.json version mismatch: '$v1' vs '$v2'"
fi
mv=$(jq -r '.plugins[0].version // "none"' .claude-plugin/marketplace.json)
if [ "$mv" = none ]; then
  pass "marketplace carries no version (plugin.json wins)"
else
  faild "marketplace must not set a version (found '$mv') — see CLAUDE.md"
fi

# --- 4. frontmatter (agents + skills need name + description) ---------------
group "frontmatter (agents + skills)"
fm_ok() { # exit 0 if file has name: and description: inside its --- frontmatter
  awk 'NR==1 && $0!="---" { exit }
       NR>1 && $0=="---"  { done=1; exit }
       /^name:/        { n=1 }
       /^description:/ { d=1 }
       END { exit (done && n && d) ? 0 : 1 }' "$1"
}
bad=0
for f in agents/*.md skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = README.md ] && continue
  fm_ok "$f" || {
    faild "missing name/description frontmatter: $f"
    bad=1
  }
done
[ "$bad" = 0 ] && pass "agents + skills have name + description"

# --- 5. hook parity (antigravity twin + fixtures both hosts) ----------------
group "hook parity"
bad=0
for f in hooks/claude/*.sh; do
  h=$(basename "$f" .sh)
  case " $AG_SUPPORTED_HOOKS " in
    *" $h "*)
      [ -f "hooks/antigravity/$h.sh" ] || {
        faild "no antigravity twin: $h"
        bad=1
      }
      [ -d "hooks/tests/fixtures/antigravity/$h" ] || {
        faild "no antigravity fixtures: $h"
        bad=1
      }
      ;;
  esac
  [ -d "hooks/tests/fixtures/claude/$h" ] || {
    faild "no claude fixtures: $h"
    bad=1
  }
done
[ "$bad" = 0 ] && pass "every hook has its twin + fixtures"

# --- 6. catalog drift ------------------------------------------------------
group "catalog drift"
bad=0
cat_has() { # slug catalog-file label
  grep -qF "$1" "$CATALOG/$2" || {
    faild "$3 '$1' not listed in $2"
    bad=1
  }
}
for f in agents/*.md; do
  b=$(basename "$f" .md)
  [ "$b" = README ] && continue
  cat_has "$b" agents-catalog.md agent
done
for f in rules/*.md; do
  b=$(basename "$f" .md)
  [ "$b" = README ] && continue
  cat_has "$b" rules-catalog.md rule
done
for f in hooks/claude/*.sh; do
  b=$(basename "$f" .sh)
  cat_has "$b" hooks-catalog.md hook
done
for d in skills/*/; do
  b=$(basename "$d")
  case "$SKILL_CATALOG_EXCLUDE" in *" $b "*) continue ;; esac
  cat_has "$b" skills-catalog.md skill
done
[ "$bad" = 0 ] && pass "all components listed in their catalogs"

# --- 7. agy skill copy freshness -------------------------------------------
group "agy skill copies"
if scripts/materialize-agy-skills.sh --check >/dev/null 2>&1; then
  pass "plugins/*/skills copies are real files and match source"
else
  faild "agy skill copies stale — run scripts/materialize-agy-skills.sh"
fi

# --- 8. hook fixture suite -------------------------------------------------
group "hook fixture suite"
out=$(hooks/tests/run-all.sh 2>&1)
if [ $? -eq 0 ]; then
  pass "$(printf '%s' "$out" | grep '^RESULT:' || echo 'hook fixtures pass')"
else
  faild "hook fixtures failed — run hooks/tests/run-all.sh"
  printf '%s\n' "$out" | grep -E '^  FAIL|^Failed:' | sed 's/^/    /'
fi

# --- 9. install.sh smoke (Claude default, non-interactive) ------------------
group "install.sh smoke"
smoke=$(mktemp -d)
trap 'rm -rf "$smoke"' EXIT
if (cd "$smoke" && bash "$ROOT/install.sh" </dev/null) >"$smoke/.log" 2>&1; then
  ok=1
  jq empty "$smoke/.claude/settings.json" 2>/dev/null || {
    faild "smoke: .claude/settings.json missing/invalid"
    ok=0
  }
  for h in block-dangerous-commands scan-secrets protect-files warn-large-files; do
    [ -f "$smoke/.claude/hooks/$h.sh" ] || {
      faild "smoke: hook $h not installed"
      ok=0
    }
  done
  [ -f "$smoke/CLAUDE.md" ] || {
    faild "smoke: CLAUDE.md not installed"
    ok=0
  }
  [ "$ok" = 1 ] && pass "install.sh lands .claude/ + settings.json + safety hooks + CLAUDE.md"
else
  faild "install.sh exited nonzero"
  tail -20 "$smoke/.log" | sed 's/^/    /'
fi

# --- 10. manifest validation (optional CLIs) --------------------------------
group "manifest validation"
if command -v claude >/dev/null 2>&1; then
  if cv=$(claude plugin validate . --strict 2>&1); then
    pass "claude plugin validate --strict"
  else
    faild "claude plugin validate failed"
    printf '%s\n' "$cv" | tail -10 | sed 's/^/    /'
  fi
else
  skp "claude not installed — --strict manifest validate skipped"
fi
if command -v agy >/dev/null 2>&1; then
  if av=$(agy plugin validate plugins/setup-agents 2>&1); then
    pass "agy plugin validate plugins/setup-agents"
  else
    faild "agy plugin validate failed"
    printf '%s\n' "$av" | tail -10 | sed 's/^/    /'
  fi
else
  skp "agy not installed — agy validate skipped"
fi

# --- summary ---------------------------------------------------------------
printf '\n\033[1mRESULT:\033[0m %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed:\n'
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
