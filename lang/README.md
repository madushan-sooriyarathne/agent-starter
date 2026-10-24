# Language profiles

One file per language (`typescript.md`, `rust.md`, `go.md`). Skills, rules, agents, and the
CLAUDE.md template stay language-neutral and carry `<!-- lang:<section> -->` markers where
language detail belongs. At install time `install.sh` (and the `/setup-agents` in-session flow)
replaces each marker with that `## <section>` from every detected language's profile:

```text
<!-- lang:testing=rust -->
**Rust:**

- Unit tests in `#[cfg(test)] mod tests` ...
<!-- /lang -->
```

The installed block keeps its open/close comments and the language list, so a later re-run
can refill it in place when the project's languages change (gap-analysis "re-tailor") without
touching anything the user edited outside the block. With no detected language the block is
left empty.

Every profile carries every section below (body may be empty). `scripts/test.sh` enforces it.

| Section         | Filled into                                                                          |
| --------------- | ------------------------------------------------------------------------------------ |
| `commands`      | CLAUDE.md/AGENTS.md, `qgit`, `qcode`, `qplan`, `debug-fix`, `fix-issue`, `refactor`  |
| `permissions`   | `.claude/settings.json` `permissions.allow` (``- `Bash(...)` `` lines; not a marker) |
| `testing`       | `tdd`, `test-writer`, `pr-test-analyzer`                                             |
| `errors`        | `error-handling` rule, `qcheck`, `code-reviewer`, `silent-failure-hunter`            |
| `review`        | `qcheck`, `code-reviewer`                                                            |
| `security`      | `security` rule, `security-reviewer`                                                 |
| `perf`          | `performance-reviewer`                                                               |
| `ship-excludes` | `ship`                                                                               |
| `naming`        | `code-quality` rule                                                                  |

`naming` lands in the always-loaded `code-quality` rule — keep every section short.
Language detection: `typescript` = `package.json` or `tsconfig.json`, `rust` = `Cargo.toml`,
`go` = `go.mod`.
