# TypeScript / JavaScript

## commands

```bash
npm run build              # build
npm run typecheck          # tsc --noEmit (or check-types)
npm run lint               # ESLint / Biome
npm run format             # Prettier / Biome
npm test                   # full suite
npm test -- path/to/file   # one file
```

Use the lockfile's package manager (`pnpm`, `bun`, `yarn`) and only scripts that exist in `package.json`. Gate order: typecheck → lint → test → build. Monorepo: run through the workspace tool (`turbo run`, `pnpm -r`/`--filter`).

## permissions

<!-- Derived from the real package.json scripts at install time. -->

## testing

- Match the existing runner (Vitest, Jest, `bun:test`; Playwright for E2E) and its file layout (`*.test.ts` beside the code or `__tests__/`).
- Names read as behavior: `it("returns 0 for an empty cart")`.
- Await every async assertion (`await expect(p).rejects.toThrow(ValidationError)`). A missing `await` passes silently.
- Mock only boundaries (`vi.mock`/`jest.mock` for network, fs, clock); restore in `afterEach`. Fake timers for time.
- Cover `null`/`undefined`, empty arrays/strings, and wrong-shape input where data is untyped (JSON, forms, env).
- UI: Testing Library queries by role/label, not test IDs or class names.

## errors

- Throw `Error` subclasses with a `code` and `cause` (`new AppError("load failed", { cause: err })`), never a bare string.
- Every promise is awaited, returned, or explicitly `void`-marked. `Promise.allSettled` when one rejection must not hide the rest.
- Silent failures: `catch {}`, `catch (e) { return null }`, `.catch(() => {})`, `?? []`/`|| 0` masking a failed fetch, `console.error` then continuing as success.
- Validate external data (requests, env, JSON) with a schema (`zod`) at the boundary; `catch (e: unknown)` and narrow before use.

## review

- `==` vs `===`; truthiness checks that reject valid `0`/`""`; missing optional chaining; array methods on possibly-undefined arrays; destructuring possibly-null objects.
- Floating promises; `async` callbacks in `forEach`; sequential `await` in loops.
- `any`, non-null `!`, and `as` casts hiding real type errors.
- Stale closures; listeners, timers, or subscriptions without cleanup; mutation of shared objects or props.
- More than ~3 positional params: take an options object.

## security

- `npm audit` / `pnpm audit` / `bun audit`. Flag new deps with install scripts, typosquat names, or unpinned versions in CI.
- XSS sinks: `dangerouslySetInnerHTML`, `innerHTML`, `eval`, `new Function`, unescaped template output.
- Prototype pollution from merging untrusted objects; `child_process.exec` with interpolated input (use `execFile`).
- PII or secrets in logs (`console.log(user)`, `logger.info(req.body)`) or in client bundles (`NEXT_PUBLIC_*`).

## perf

- Re-renders from new object/function props each render; unmemoized expensive derivations; context values that change every render.
- Bundle: heavy client imports that could stay server-side or load dynamically; barrel imports pulling whole libraries.
- Sequential `await`s that could run in parallel (`Promise.all`); N+1 queries from per-item fetches.
- Unbounded caches or listeners; sync work blocking the event loop (`fs.*Sync`, large `JSON.parse` on hot paths).

## ship-excludes

- Lockfiles `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock*` unless dependencies changed intentionally.
- Build output: `node_modules/`, `dist/`, `build/`, `.next/`, `.turbo/`, `coverage/`.
- Generated: `*.gen.ts`, `*.generated.*`, `*.min.js`, `*.min.css`, `next-env.d.ts`.

## naming

- Files: PascalCase for components and classes (`UserProfile.tsx`), kebab-case for utilities and directories (`date-utils.ts`).
- camelCase functions, verb-first (`getUser`). Handlers `handle*` internally, `on*` as props. Factories `create*`, converters `to*`, predicates `is*`/`has*`. Constants `SCREAMING_SNAKE`. Acronyms as words: `userId`, not `userID`.
- Imports: builtins, external, internal, relative, types. Blank line between groups.
- Named exports over default. One component or class per file.
