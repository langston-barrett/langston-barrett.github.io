# Rust

## Performance

- [The Rust Performance Book](https://nnethercote.github.io/perf-book/introduction.html)
- [Wild Performance Tricks](https://davidlattimore.github.io/posts/2025/09/02/rustforge-wild-performance-tricks.html)

### Allocators

[Build Configuration - The Rust Performance Book](https://nnethercote.github.io/perf-book/build-configuration.html#build-configuration)

```sh
cargo add mimalloc
```

```rust
#[cfg(not(miri))]
#[global_allocator]
static ALLOC: mimalloc::MiMalloc = mimalloc::MiMalloc;
```

### Cargo profiles

[Profiles - The Cargo Book](https://doc.rust-lang.org/cargo/reference/profiles.html)

```toml
# https://nnethercote.github.io/perf-book/build-configuration.html
[profile.release]
codegen-units = 1
lto = "fat"

# https://github.com/mstange/samply#turn-on-debug-info-for-full-stacks
[profile.profiling]
inherits = "release"
debug = true
```

### Tools

See also this section of the
[Rust Performance Book](https://nnethercote.github.io/perf-book/profiling.html?highlight=dhat#profilers).

- [Samply](https://github.com/mstange/samply)
- [tracing-chrome](https://crates.io/crates/tracing-chrome)

#### `dhat`

[`dhat`](https://docs.rs/dhat/latest/dhat/) is a heap profiler.

Quickstart:

```sh
cargo add --optional dhat
```

In `Cargo.toml`:

```toml
[features]
dhat = ["dep:dhat"]
```

In `main.rs`:

```rs
#[cfg(feature = "dhat")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

fn main() {
    #[cfg(feature = "dhat")]
    let _profiler = dhat::Profiler::new_heap();
    // ...
}
```

Then:

```sh
cargo run --profile=profiling --features dhat -- your args here
```

Then upload `dhat-heap.json` to [the online viewer].

[the online viewer]: https://nnethercote.github.io/dh_view/dh_view.html

## Safety

### `cargo-careful`

[`cargo-careful`](https://github.com/RalfJung/cargo-careful)

> cargo careful is a tool to run your Rust code extra carefully -- opting into
> a bunch of nightly-only extra checks that help detect Undefined Behavior, and
> using a standard library with debug assertions.

```sh
cargo +nightly install cargo-careful
cargo +nightly fetch
cargo +nightly careful build -Zcareful-sanitizer=address --target=x86_64-unknown-linux-gnu --tests --frozen
cargo +nightly careful test -Zcareful-sanitizer=address --target=x86_64-unknown-linux-gnu --frozen
```

### Scudo

[Scudo](https://llvm.org/docs/ScudoHardenedAllocator.html)

```sh
cargo add scudo
```

```rust
#[cfg(all(not(miri), debug_assertions))]
#[global_allocator]
static ALLOC: scudo::GlobalScudoAllocator = scudo::GlobalScudoAllocator;
```

## Links

- [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/)
