#!/usr/bin/env bash
# Fixture asset for format-on-save. Kept in shfmt-canonical form (repo
# .editorconfig: 2-space, indented case) so `shfmt -w` is a no-op and the
# test run never mutates a tracked file. The runner globs *.json, so this
# .sh is not treated as a fixture itself.
greet() {
  local name="$1"
  case "$name" in
    world)
      echo "hello world"
      ;;
    *)
      echo "hello $name"
      ;;
  esac
}

greet "world"
