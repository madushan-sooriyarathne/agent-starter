#!/usr/bin/env bash
# Shared rendering helpers for the terminal installer and the Codex materializer.

# lang_fill <file> — replace each <!-- lang:<section> --> marker (fresh copy) or
# existing <!-- lang:<section>=<langs> --> … <!-- /lang --> block (re-tailor)
# with that ## section from every detected language's lang/<id>.md profile.
# The installed block keeps its open/close comments so a later run can refill
# it in place without touching user edits outside it.
lang_fill() {
  local f="$1" opens closes
  grep -q '<!-- lang:' "$f" 2>/dev/null || return 0
  opens=$(grep -c '<!-- lang:[a-z-]*=' "$f" || true)
  closes=$(grep -c '<!-- /lang -->' "$f" || true)
  if [ "$opens" != "$closes" ]; then
    skip "$(basename "$f"): unbalanced <!-- lang --> block — not re-tailored"
    return 0
  fi
  awk -v langs="$LANGS_CSV" -v dir="$LANG_PROFILE_DIR" '
    function emit(sec, ind,   n, ids, i, j, k, path, line, on, title, body, out, printed) {
      print ind "<!-- lang:" sec "=" langs " -->"
      n = split(langs, ids, ",")
      for (i = 1; i <= n; i++) {
        path = dir "/" ids[i] ".md"; on = 0; title = ""; body = ""
        while ((getline line < path) > 0) {
          if (title == "" && line ~ /^# /) title = substr(line, 3)
          if (line ~ /^## /) { on = (line == "## " sec); continue }
          if (on) body = body line "\n"
        }
        close(path)
        sub(/^\n+/, "", body); sub(/\n+$/, "", body)
        if (body == "") continue
        if (printed) print ""
        printed = 1
        print ind "**" title ":**"
        print ""
        k = split(body, out, "\n")
        for (j = 1; j <= k; j++) print (out[j] == "" ? "" : ind out[j])
      }
      print ind "<!-- /lang -->"
    }
    skip { if ($0 ~ /<!-- \/lang -->/) skip = 0; next }
    match($0, /<!-- lang:[a-z-]+(=[a-z,]*)? -->/) {
      ind = substr($0, 1, RSTART - 1)
      tag = substr($0, RSTART + 10, RLENGTH - 14)
      sec = tag
      eq = index(tag, "=")
      if (eq) { sec = substr(tag, 1, eq - 1); skip = 1 }
      emit(sec, ind)
      next
    }
    { print }
  ' "$f" >"$f.lang.$$" && mv "$f.lang.$$" "$f"
}

# lang_recorded <file> — the language list(s) recorded in a file's filled
# blocks, one per line (empty output = no filled blocks).
lang_recorded() { grep -o '<!-- lang:[a-z-]*=[a-z,]* -->' "$1" 2>/dev/null | sed 's/.*=\([a-z,]*\) -->/\1/' | sort -u; }

# Rewrite rule/skill `paths:` globs from src/ to the project's real source dir.
rewrite_paths() {
  [ -n "$PRIMARY_SRC_DIR" ] && grep -q '^paths:' "$1" 2>/dev/null || return 0
  sed -i.bak "/^paths:/,/^---/ s#\"src/#\"$PRIMARY_SRC_DIR/#g" "$1"
  rm -f "$1.bak"
}

# ag_skill_write <src> <dest> <name> — Antigravity skill from an agent or skill
# source: frontmatter reduced to name+description (agy is picky about extra
# keys), body carried verbatim, then language-tailored.
ag_skill_write() {
  local src="$1" dest="$2" name="$3" desc
  mkdir -p "$(dirname "$dest")"
  desc=$(sed -n 's/^description: //p' "$src" | head -1)
  case "$desc" in
    \"*\" | \'*\') ;;
    *) desc="'$(printf '%s' "${desc:-$name}" | sed "s/'/''/g")'" ;;
  esac
  {
    printf '%s\n' "---" "name: $name" "description: $desc" "---"
    awk 'NR == 1 && /^---$/ {next} !body {if (/^---$/) body=1; next} {print}' "$src"
  } >"$dest"
  lang_fill "$dest"
}
