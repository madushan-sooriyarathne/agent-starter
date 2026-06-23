# Rules Catalog

Four rules files, copied from `${CLAUDE_PLUGIN_ROOT}/rules/` (slash command) or
`$SCRIPT_DIR/rules/` (install.sh) into the target project's `.claude/rules/`.

Rules are always-on guidance for Claude in the project. Pre-mark based on scan signals.

| # | Rule | File | Covers | Recommend when |
|---|------|------|--------|----------------|
| 1 | `typescript` | `typescript.md` | No `any`, infer types from Drizzle schema, Zod at external boundaries | Always (TS detected: `tsconfig.json` or `.ts`/`.tsx` files). Default: recommend |
| 2 | `git-workflow` | `git-workflow.md` | Conventional commits, branch naming, no direct push to main, no `--no-verify`, no destructive force-push | Always (Git repo). Default: recommend |
| 3 | `nextjs` | `nextjs.md` | App Router conventions, server vs client components, justified `"use client"` | `next.config.*` detected |
| 4 | `monorepo` | `monorepo.md` | Turborepo package boundaries, pnpm workspaces, no cross-package `../` imports, no barrel files | `turbo.json` OR `pnpm-workspace.yaml` detected |

Notes:

- `typescript` and `git-workflow` apply to essentially every project; pre-check them by default.
- `nextjs` and `monorepo` are stack-specific; only pre-check when their signal is present, but still list them so the user can opt in.
