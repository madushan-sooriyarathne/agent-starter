# Language tailoring

Bundled skills, workflow commands, agents, several rules, and the project-doc template are
language-neutral at the source and carry `<!-- lang:<section> -->` markers where
language-specific detail belongs (commands, test idioms, error idioms, review checklist,
security, perf, files never to stage, naming). Materialization fills them from the language
profiles in `${BUNDLE}/template/lang/<id>.md`.

## `LANGS` — which profiles apply

Recorded in Step 1, fixed order, from manifests at the project root:

| Profile      | Signal                            |
| ------------ | --------------------------------- |
| `typescript` | `package.json` or `tsconfig.json` |
| `rust`       | `Cargo.toml`                      |
| `go`         | `go.mod`                          |

Several can apply (e.g. a TS frontend with a Rust backend → `typescript,rust`). Other
languages have no profile yet; their markers stay empty and the neutral text stands.

## Filling a marker

Apply to every file materialization writes from `${BUNDLE}/template/` — agents (and their
Antigravity skill conversions), rules, bundled skills, workflow commands, and a freshly
copied `CLAUDE.md`/`AGENTS.md` — after the copy and any `paths:` rewrite.

Replace each `<!-- lang:<section> -->` line with an open comment carrying the language list,
then, for each profile in `LANGS` whose `## <section>` has a body, a `**<profile H1>:**` label,
a blank line, and that body (blank line between profiles), then the close comment. Indent every
emitted line by the marker's own indentation (markers inside list items stay inside them):

```text
   <!-- lang:commands=typescript,rust -->
   **TypeScript / JavaScript:**

   …the ## commands body from typescript.md…

   **Rust:**

   …the ## commands body from rust.md…
   <!-- /lang -->
```

With no profile in `LANGS`, emit just `<!-- lang:<section>= -->` and `<!-- /lang -->`. Keep
the comments: they are how a later run refills the block in place.

`## permissions` is not a marker. Its ``- `Bash(...)` `` lines are added to
`.claude/settings.json` `permissions.allow` (Claude Code only). The `typescript` profile has
none — its permissions come from the real `package.json` scripts.

## Re-tailor (gap-analysis mode)

Step 1.7 lists, per host, the catalog files already on disk that need tailoring:

- **refill** — the file has filled blocks whose recorded list (`=<langs>`) differs from the
  current `LANGS`, or still has a raw unfilled marker. Rewrite only the content between each
  block's open and close comments; everything outside them (user edits) is untouched. This
  also applies to an existing `CLAUDE.md`/`AGENTS.md`.
- **recopy** — the file has no blocks (installed before language profiles existed) while its
  source now has markers, and its `description:` matches the source's (so it is our copy, not
  an external skill of the same name). Re-copy it from source and fill it. This overwrites
  local edits — say so. Never recopy the project doc.

`install.sh` implements exactly this (`lang_fill`, `scan_retailor`); prefer matching its
output.
