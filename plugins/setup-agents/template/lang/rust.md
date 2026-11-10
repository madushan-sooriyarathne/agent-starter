# Rust

## commands

```bash
cargo build                    # build
cargo check --all-targets      # fast compile + type check
cargo clippy --all-targets --all-features -- -D warnings   # lint
cargo fmt --check              # format check (cargo fmt to fix)
cargo test                     # all tests: unit, integration, doc
cargo test <name>              # tests whose path contains <name>
```

Gate order: `cargo fmt --check` → `cargo clippy` → `cargo test`. Workspace: add `--workspace`; one crate: `-p <crate>`. Prefer aliases in `.cargo/config.toml`, `justfile`/`Makefile` targets, or CI jobs when the project defines them.

## permissions

- `Bash(cargo build *)`
- `Bash(cargo check *)`
- `Bash(cargo clippy *)`
- `Bash(cargo fmt *)`
- `Bash(cargo test *)`

## testing

- Unit tests in `#[cfg(test)] mod tests { use super::*; }` beside the code; integration tests in `tests/` against the public API only; `///` examples run as doc tests.
- Name tests as behavior in snake_case: `returns_none_when_cart_is_empty`.
- Return `Result<(), E>` from tests and use `?` instead of chained `unwrap()`. Assert error variants: `assert!(matches!(err, Error::NotFound { .. }))`.
- `#[should_panic(expected = "...")]` only for documented panics, always with `expected`.
- No mocking framework by default: put the boundary (clock, network, fs) behind a trait and pass a fake. `proptest` for invariants, `insta` for large outputs, `#[tokio::test]` for async.
- TDD red: stub new functions with `todo!()` so the test compiles and fails at runtime. A compile error is not a red test.

## errors

- `Result<T, E>` for recoverable failure; `panic!` only for broken invariants. No `unwrap()`/`expect()` in production paths unless the invariant is proven and commented.
- Libraries: typed error enums (`thiserror`). Binaries: `anyhow` with `.context("loading config")?` so the chain says what failed.
- Silent failures: `let _ = fallible();`, `.ok()` dropping an error, `unwrap_or_default()`/`unwrap_or(0)` hiding a failure, `if let Ok(x) = …` with no `else`, `.map_err(|_| …)` discarding the source, ignored `#[must_use]` values, futures never awaited.

## review

- `unwrap()`/`expect()`/slice indexing on input-derived data in non-test code.
- Lossy `as` casts (`u64 as u32`, `i64 as usize`): use `try_from`. Unchecked arithmetic on untrusted numbers.
- `.clone()` added to silence the borrow checker; `&String`/`&Vec<T>` params instead of `&str`/`&[T]`.
- `unsafe` without a `// SAFETY:` comment naming the invariant.
- Async: a `MutexGuard` held across `.await`; blocking I/O or CPU work on the executor (use `spawn_blocking`); a dropped `JoinHandle` losing a task's error.
- `pub` items that should be `pub(crate)`; new public API without doc comments.

## security

- Run `cargo audit` (RustSec) and `cargo deny check` when configured. Flag new crates with git sources, few downloads, or a `build.rs` that touches the network.
- Every `unsafe` block, FFI boundary, and `transmute` is a review hotspot.
- SQL: bind parameters (`sqlx::query!`, `.bind()`), never `format!` into SQL. Shell: `Command::new(prog).arg(x)`, never `sh -c` with interpolated input.
- Secrets in `secrecy::SecretString` or a redacting `Debug` impl; no `{:?}` logging of structs that carry tokens.

## perf

- Needless `.clone()`/`.to_string()`/`collect::<Vec<_>>()` in hot paths; collect-then-iterate instead of chained iterators.
- Missing `with_capacity` when the size is known; `String` built with `+` in loops (use `push_str`/`write!`).
- `Box<dyn Trait>` or `Arc<Mutex<_>>` where generics or plain ownership work; long lock critical sections.
- Blocking calls inside async; one `tokio::spawn` per item instead of bounded concurrency (`buffer_unordered`).
- Measure first: `cargo bench` (criterion) or `cargo flamegraph`, always on `--release`.

## ship-excludes

- Build output: `target/`.
- `Cargo.lock`: commit it for binaries and workspaces; for a library follow the repo's existing choice. Never stage unrelated lockfile churn.
- Generated: files written by `build.rs` or under `src/generated/`; `*.profraw` coverage data.

## naming

- `snake_case` functions, variables, modules, and files; `UpperCamelCase` types and traits; `SCREAMING_SNAKE_CASE` consts and statics. Acronyms as words: `HttpClient`, `user_id`.
- Conversions: `as_*` (cheap borrow), `to_*` (costly), `into_*` (consumes). Constructors `new`/`with_*`/`from_*`. Getters drop `get_` (`fn name(&self)`). Predicates `is_*`/`has_*`.
- `use` groups: `std`, external crates, then `crate::`/`super::`, blank line between. No glob imports outside tests and preludes.
- Items are `pub(crate)` by default; `pub` only for the intended API. Module files follow the repo (`foo.rs` vs `foo/mod.rs`).
