# Go

## commands

```bash
go build ./...                    # build
go vet ./...                      # static checks
golangci-lint run                 # lint (when .golangci.* exists)
gofmt -l .                        # list unformatted files (gofmt -w . to fix)
go test ./...                     # all tests
go test -run TestName ./pkg/...   # one test
go test -race ./...               # with the race detector
```

Gate order: `gofmt -l .` (must print nothing) → `go vet ./...` → `golangci-lint run` (if configured) → `go test -race ./...`. Prefer `Makefile`/CI targets when the project defines them.

## permissions

- `Bash(go build *)`
- `Bash(go vet *)`
- `Bash(go test *)`
- `Bash(gofmt *)`
- `Bash(golangci-lint *)`

## testing

- `_test.go` beside the code; `package foo` for internals, `package foo_test` for black-box API tests.
- Table-driven tests with `t.Run(tc.name, ...)`; case names describe behavior (`"empty cart returns zero"`). One behavior per row.
- `t.Helper()` in helpers, `t.Cleanup` for teardown, `t.TempDir()` for files, `t.Parallel()` where state is isolated.
- Compare errors with `errors.Is`/`errors.As`, never by string. `cmp.Diff` (go-cmp) for structs.
- Fakes over mocks: small interfaces defined at the consumer; `httptest.Server` for HTTP. Run with `-race`.

## errors

- Return errors, don't panic. Wrap with context: `fmt.Errorf("load config: %w", err)`. Sentinel or typed errors, checked with `errors.Is`/`errors.As`.
- Handle or return each `err` exactly once. No log-and-return duplicates.
- Silent failures: `_ = f()`, empty `if err != nil { }`, `if err != nil { return nil }` dropping the error, ignored `Close()`/`Flush()` errors on writers, goroutine errors that go nowhere (use `errgroup`).

## review

- Writes to a nil map; nil derefs on optional struct fields; typed-nil returned as an `error` interface.
- Goroutine leaks with no cancellation path; loop-variable capture in closures (modules before Go 1.22).
- `context.Context` not the first param or not propagated; `context.Background()` deep in request paths.
- Data races on shared maps/slices; `defer` inside loops; slices aliasing a shared backing array after `append`.
- Unchecked type assertions `v.(T)` on untrusted values: use `v, ok :=`.

## security

- Run `govulncheck ./...`. Flag new modules, `replace` directives, and unpinned tool versions in CI.
- SQL with placeholders (`db.Query(q, args...)`), never `fmt.Sprintf`. `exec.Command(prog, args...)`, never `sh -c` with input.
- `html/template` (not `text/template`) for HTML; `filepath.Clean` plus a root check against traversal; `crypto/rand` for tokens; `subtle.ConstantTimeCompare` for secrets.
- HTTP servers set `ReadHeaderTimeout` and timeouts; never `InsecureSkipVerify`.

## perf

- Allocation in hot loops: pre-size with `make([]T, 0, n)`; `strings.Builder` over `+=`; avoid `[]byte`↔`string` round-trips.
- Unbounded goroutine fan-out (bound with a worker pool or `errgroup.SetLimit`); mutex contention on hot paths.
- Reflection or `fmt` in hot paths; N+1 queries.
- Measure first: `go test -bench . -benchmem`, `pprof`.

## ship-excludes

- `go.sum` changes only alongside matching `go.mod` changes; `vendor/` only if the repo vendors.
- Build output: compiled binaries, `bin/`, `coverage.out`, `*.test`.
- Generated: `*.pb.go`, `*_gen.go`, `mock_*.go`, any file headed `// Code generated ... DO NOT EDIT.` Regenerate, don't hand-edit.

## naming

- `MixedCaps`; exported names capitalized. Acronyms keep their case: `userID`, `HTTPClient`.
- Short lowercase package names, no `util`/`common`; no stutter (`user.Service`, not `user.UserService`). Files `snake_case.go`.
- Getters drop `Get` (`Owner()`, setter `SetOwner()`). One-method interfaces end in `-er`. Short receiver names, consistent per type.
- Imports: stdlib, external, then this module, as `goimports` groups them.
