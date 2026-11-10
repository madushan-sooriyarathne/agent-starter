#!/usr/bin/env bash
# Offline scaffold and optional real Codex marketplace smoke.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run_install() { (cd "$1" && AGENT_STARTER_NO_EXTERNAL=1 bash "$root/install.sh" --host "$2" </dev/null); }
go_project() {
  mkdir -p "$1/internal"
  printf 'module smoke\n\ngo 1.22\n' >"$1/go.mod"
  printf 'package main\nfunc main() {}\n' >"$1/internal/main.go"
}

case "${1:-}" in
  scaffold)
    project="$work/codex"
    go_project "$project"
    mkdir -p "$project/.codex/agents" "$project/.agents/skills/qnew"
    printf '# Handwritten instructions\n' >"$work/doc"
    printf '# Custom skill\n' >"$work/skill"
    printf 'model = "my-model"\n' >"$work/config"
    cp "$work/doc" "$project/AGENTS.md"
    cp "$work/skill" "$project/.agents/skills/qnew/SKILL.md"
    cp "$work/config" "$project/.codex/config.toml"
    printf 'name = "my-reviewer"\n' >"$project/.codex/agents/my-reviewer.toml"
    printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"my-command"}]}]}}\n' >"$project/.codex/hooks.json"
    run_install "$project" codex
    cmp "$work/doc" "$project/AGENTS.md"
    cmp "$work/skill" "$project/.agents/skills/qnew/SKILL.md"
    cmp "$work/config" "$project/.codex/config.toml"
    grep -q 'my-reviewer' "$project/.codex/agents/my-reviewer.toml"
    test -x "$project/.codex/hooks/agent-starter/run.sh"
    test ! -e "$project/.claude"
    test ! -e "$project/.agents/hooks"
    test ! -e "$project/.agents/rules"
    jq -e 'any(.hooks.Stop[]?.hooks[]?; .command == "my-command")' "$project/.codex/hooks.json" >/dev/null
    cp "$project/.codex/hooks.json" "$work/first-hooks"
    run_install "$project" codex
    cmp "$work/first-hooks" "$project/.codex/hooks.json"

    all="$work/all"
    go_project "$all"
    run_install "$all" agy
    cp "$all/.agents/skills/qplan/SKILL.md" "$work/agy-skill"
    jq '.custom = {"Stop":[{"type":"command","command":"my-ag-command"}]}' "$all/.agents/hooks.json" >"$work/agy-hooks"
    cp "$work/agy-hooks" "$all/.agents/hooks.json"
    printf '\n# Project customization\n' >>"$all/.agents/hooks/session-start.sh"
    cp "$all/.agents/hooks/session-start.sh" "$work/agy-hook"
    # Add Codex to a project with existing Antigravity config and a shared doc.
    run_install "$all" all
    cmp "$work/agy-skill" "$all/.agents/skills/qplan/SKILL.md"
    cmp "$work/agy-hooks" "$all/.agents/hooks.json"
    cmp "$work/agy-hook" "$all/.agents/hooks/session-start.sh"
    test -f "$all/.claude/settings.json"
    test -f "$all/.agents/hooks.json"
    test -f "$all/.codex/hooks.json"
    test -f "$all/.codex/agents/code-reviewer.toml"
    test -f "$all/.codex/guidance/golang.md"
    grep -q 'Goroutine leaks' "$all/.codex/agents/code-reviewer.toml"
    if python3 -c 'import tomllib' 2>/dev/null; then
      python3 - "$all/.codex/agents" <<'PY'
import sys
import tomllib
from pathlib import Path

for file in Path(sys.argv[1]).glob("*.toml"):
    data = tomllib.loads(file.read_text())
    assert {"name", "description", "developer_instructions"} <= data.keys()
    assert data["sandbox_mode"] == "read-only"
PY
    fi

    fresh="$work/fresh"
    go_project "$fresh"
    run_install "$fresh" all
    test -f "$fresh/AGENTS.md"
    test -f "$fresh/CLAUDE.md"
    test -f "$fresh/.agents/skills/qplan/SKILL.md"
    test "$(grep -cF '## Codex project guidance' "$fresh/AGENTS.md")" = 1
    run_install "$fresh" all
    test "$(grep -cF '## Codex project guidance' "$fresh/AGENTS.md")" = 1
    printf '{}\n' >"$fresh/package.json"
    run_install "$fresh" codex
    grep -qF 'lang:review=typescript,go' "$fresh/.codex/agents/code-reviewer.toml"

    inline="$work/inline"
    mkdir -p "$inline/.codex"
    printf '[[hooks.SessionStart]]\nmatcher = "startup"\n' >"$inline/.codex/config.toml"
    bash "$root/scripts/materialize-codex.sh" "$inline" --hook session-start
    test ! -e "$inline/.codex/hooks.json"
    test ! -e "$inline/.codex/hooks"
    ;;
  marketplace)
    market="$work/market"
    mkdir -p "$market/.agents/plugins" "$market/plugins" "$work/state" "$work/target"
    cp "$root/.agents/plugins/marketplace.json" "$market/.agents/plugins/"
    cp -Rp "$root/plugins/setup-agents" "$market/plugins/"
    export CODEX_HOME="$work/state"
    cd "$work/target"
    codex plugin marketplace add "$market"
    installed=$(codex plugin add setup-agents@agent-starter --json | jq -er '.installedPath')
    mv "$market" "$work/market-offline"
    diff -rq "$work/market-offline/plugins/setup-agents/template" "$installed/template"
    for skill in setup-agents setup-agy setup-claude setup-codex; do test -s "$installed/skills/$skill/SKILL.md"; done
    bash "$installed/template/scripts/materialize-codex.sh" "$work/target" \
      --doc create --lang go --agent code-reviewer --rule golang --skill qplan --hook protect-files
    test -f "$work/target/.codex/agents/code-reviewer.toml"
    test -f "$work/target/.agents/skills/qplan/SKILL.md"
    test -x "$work/target/.codex/hooks/agent-starter/run.sh"
    ;;
  *) exit 2 ;;
esac
