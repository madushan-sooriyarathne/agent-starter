#!/usr/bin/env bash
# Generate the self-contained setup-agents bundle for all three marketplaces.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
bundle=plugins/setup-agents
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/skills" "$stage/template/"{agents,hooks/{claude,antigravity,codex},lang,rules,skills,scripts}
for name in setup-agents setup-claude setup-agy setup-codex; do
  cp -Rp "skills/$name" "$stage/skills/"
done
cp -p agents/*.md "$stage/template/agents/"
cp -p lang/*.md "$stage/template/lang/"
for f in rules/*.md; do
  [ "$f" = rules/README.md ] || cp -p "$f" "$stage/template/rules/"
done
for host in claude antigravity codex; do
  cp -p "hooks/$host/"*.sh "$stage/template/hooks/$host/"
done
for skill in skills/*/SKILL.md; do
  dir=${skill%/SKILL.md}
  case "$dir" in skills/setup-*) continue ;; esac
  cp -Rp "$dir" "$stage/template/skills/"
done
cp -p templates/CLAUDE.template.md "$stage/template/CLAUDE.md"
cp -p templates/AGENTS.template.md "$stage/template/AGENTS.md"
cp -p templates/{settings,codex-hooks}.json "$stage/template/"
cp -p scripts/{render,materialize-codex}.sh "$stage/template/scripts/"

for part in skills template; do
  if [ "${1:-}" = --check ]; then
    if [ ! -d "$bundle/$part" ] || [ -L "$bundle/$part" ] ||
      [ -n "$(find "$bundle/$part" -type l -print)" ] ||
      ! diff -rq "$stage/$part" "$bundle/$part"; then
      printf 'stale: %s/%s. Run scripts/materialize-agy-skills.sh\n' "$bundle" "$part" >&2
      exit 1
    fi
    while IFS= read -r file; do
      [ -x "$bundle/$part/${file#"$stage/$part/"}" ] || {
        printf 'missing executable bit: %s\n' "${file#"$stage/"}" >&2
        exit 1
      }
    done < <(find "$stage/$part" -type f -perm -100)
  else
    rm -rf "$bundle/$part"
    cp -Rp "$stage/$part" "$bundle/"
  fi
done
