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
SKILL_CATALOG_EXCLUDE=" setup-agents setup-agy setup-claude setup-codex "

CATALOG="skills/setup-agents/references"
# Sections every lang/<id>.md profile must carry (see lang/README.md).
LANG_SECTIONS="commands permissions testing errors review security perf ship-excludes naming"

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
v3=$(jq -r '.version // ""' plugins/setup-agents/.codex-plugin/plugin.json)
if [ -n "$v1" ] && [ "$v1" = "$v2" ] && [ "$v1" = "$v3" ]; then
  pass "plugin.json versions match ($v1)"
else
  faild "plugin.json version mismatch: Claude=$v1 Antigravity=$v2 Codex=$v3"
fi
mv=$(jq -r '.plugins[0].version // "none"' .claude-plugin/marketplace.json)
if [ "$mv" = none ]; then
  pass "marketplace carries no version (plugin.json wins)"
else
  faild "marketplace must not set a version (found '$mv') — see CLAUDE.md"
fi

if jq -e '.name == "agent-starter" and
  (.plugins | length == 1 and .[0].name == "setup-agents" and
    .[0].source == {source:"local", path:"./plugins/setup-agents"} and
    .[0].policy == {installation:"AVAILABLE", authentication:"ON_INSTALL"} and
    (.[0] | has("version") | not))' .agents/plugins/marketplace.json >/dev/null &&
  jq -e '.name == "setup-agents" and .skills == "./skills/"' plugins/setup-agents/.codex-plugin/plugin.json >/dev/null; then
  pass "Codex marketplace points to the setup-agents bundle"
else
  faild "invalid Codex marketplace entry or manifest"
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
while IFS= read -r name; do
  if [ ! -x "hooks/claude/$name.sh" ] || [ ! -x hooks/codex/run.sh ] ||
    [ -z "$(find "hooks/tests/fixtures/codex/$name" -name '*.json' -print 2>/dev/null)" ]; then
    faild "missing Codex hook policy or fixtures for $name"
    bad=1
  fi
done < <(jq -r 'keys[]' templates/codex-hooks.json)
[ "$bad" = 0 ] && pass "every hook has its required port and fixtures"

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

# --- 7. plugin bundle freshness -------------------------------------------
group "plugin bundle"
if scripts/materialize-agy-skills.sh --check >/dev/null 2>&1; then
  pass "bundled skills and templates are self-contained and match source"
else
  faild "plugin bundle stale — run scripts/materialize-agy-skills.sh"
fi

# --- 7b. language profiles + markers ---------------------------------------
group "language profiles"
bad=0
for f in lang/*.md; do
  [ "$(basename "$f")" = README.md ] && continue
  head -1 "$f" | grep -q '^# ' || {
    faild "$f: first line must be the '# <Display name>' label"
    bad=1
  }
  for sec in $LANG_SECTIONS; do
    grep -qx "## $sec" "$f" || {
      faild "$f: missing '## $sec'"
      bad=1
    }
  done
done
while IFS= read -r m; do
  sec="${m#*<!-- lang:}"
  sec="${sec%% -->*}"
  case " $LANG_SECTIONS " in
    *" $sec "*) [ "$sec" = permissions ] && {
      faild "marker lang:permissions is not fillable: ${m%%:*}"
      bad=1
    } ;;
    *)
      faild "unknown marker section '$sec': ${m%%:*}"
      bad=1
      ;;
  esac
done < <(grep -o '<!-- lang:[^>]*-->' -H agents/*.md rules/*.md skills/*/SKILL.md templates/*.template.md 2>/dev/null)
[ "$bad" = 0 ] && pass "profiles carry every section; every marker names one"

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

# --- 9b. install.sh smoke — language tailoring (Rust, TS, Go) ---------------
# AGENT_STARTER_NO_EXTERNAL=1 skips bunx/graphify so the run is offline.
group "install.sh tailoring smoke"
tailor_smoke() { # tailor_smoke <label> <dir> <want-in-qgit> <forbidden-regex> <want-perm>
  local label="$1" d="$2" want="$3" deny="$4" perm="$5" ok=1
  if ! (cd "$d" && AGENT_STARTER_NO_EXTERNAL=1 bash "$ROOT/install.sh" </dev/null) >"$d.log" 2>&1; then
    faild "$label: install.sh exited nonzero"
    tail -20 "$d.log" | sed 's/^/    /'
    return
  fi
  grep -qF -- "$want" "$d/.claude/skills/qgit/SKILL.md" 2>/dev/null || {
    faild "$label: qgit not tailored (no '$want')"
    ok=0
  }
  if grep -rlE '<!-- lang:[a-z-]+ -->' "$d/.claude" "$d/CLAUDE.md" >/dev/null 2>&1; then
    faild "$label: unfilled <!-- lang --> marker left in install output"
    ok=0
  fi
  if grep -rlE -- "$deny" "$d/.claude/skills" "$d/.claude/agents" "$d/.claude/rules" "$d/CLAUDE.md" >/dev/null 2>&1; then
    faild "$label: other-language content leaked: $(grep -rlE -- "$deny" "$d/.claude/skills" "$d/.claude/agents" "$d/.claude/rules" "$d/CLAUDE.md" | head -3 | tr '\n' ' ')"
    ok=0
  fi
  jq -e --arg p "$perm" '.permissions.allow | index($p)' "$d/.claude/settings.json" >/dev/null 2>&1 || {
    faild "$label: settings.json missing permission $perm"
    ok=0
  }
  [ "$ok" = 1 ] && pass "$label: skills/rules/agents/CLAUDE.md tailored, no leaks, permissions set"
}
rs="$smoke/rust"
mkdir -p "$rs/src"
printf '[package]\nname = "smoke"\nversion = "0.1.0"\n' >"$rs/Cargo.toml"
printf 'fn main() {}\n\n#[test]\nfn ok() {}\n' >"$rs/src/main.rs"
tailor_smoke "rust" "$rs" "cargo clippy" 'npm run|tsconfig|\.tsx|go vet' "Bash(cargo test *)"
tsd="$smoke/ts"
mkdir -p "$tsd/src"
printf '{"name":"smoke","scripts":{"test":"vitest"},"devDependencies":{"typescript":"5"}}\n' >"$tsd/package.json"
printf '{}\n' >"$tsd/tsconfig.json"
printf 'export const a = 1;\n' >"$tsd/src/a.ts"
tailor_smoke "typescript" "$tsd" "npm run typecheck" 'cargo |go vet|gofmt' "Bash(npm run test *)"
god="$smoke/go"
mkdir -p "$god"
printf 'module smoke\n\ngo 1.22\n' >"$god/go.mod"
printf 'package main\n\nfunc main() {}\n' >"$god/main.go"
tailor_smoke "go" "$god" "go vet ./..." 'npm run|cargo |tsconfig|\.tsx' "Bash(go test *)"

group "Codex scaffold smoke"
if result=$(bash scripts/test-codex.sh scaffold 2>&1); then
  pass "Codex-only and all-host setup preserve existing config and tailor native agents"
else
  faild "Codex scaffold smoke failed"
  printf '%s\n' "$result" | tail -25 | sed 's/^/    /'
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

if command -v codex >/dev/null 2>&1 && codex plugin add --help >/dev/null 2>&1; then
  if result=$(bash scripts/test-codex.sh marketplace 2>&1); then
    pass "Codex marketplace installs a self-contained plugin and its cached writer scaffolds a project"
  else
    faild "Codex marketplace install failed"
    printf '%s\n' "$result" | tail -25 | sed 's/^/    /'
  fi
else
  skp "Codex CLI plugin install unavailable"
fi

# --- summary ---------------------------------------------------------------
printf '\n\033[1mRESULT:\033[0m %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  printf 'Failed:\n'
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
