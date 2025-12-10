# Build systems

See also [Make](make.md).

## Build systems I have enjoyed

- [ninja](https://github.com/langston-barrett/dots/blob/576dc9072e68c5ae33d568f29a4d2c9acedecec7/scripts/lint/lint.py)
- [make](https://github.com/langston-barrett/langston-barrett.github.io/blob/c950dabbd1c5ec4884f0dc39bce373a96818cf46/Makefile)
- [shake](https://github.com/GaloisInc/MATE/tree/ba73c5745c55aba92fa28b4d867bf9faf96e0085/shake)

## Build systems I gave up on

- [tup](https://gittup.org/tup/): can't install via Nix
- [redo](https://redo.readthedocs.io/en/latest/): interesting, but unmaintained

## What to look for

### Allow or require out-of-tree builds

*Justification*: Out-of-tree builds are occasionally necessary, for instance
if your source tree is mounted on a read-only filesystem. More realistically,
out-of-tree builds ensure that you and your build system are aware of all
the files that get created and read during the build process, which aids in
maintainability, source tree cleanliness, and accurate dependency tracking.

### Do only necessary work

As much as your build system supports it, you should use dependency tracking to
ensure that you don't redo any build steps or other tasks.

*Example*: If package or file `B` depends on `A` and `B` changes, don't
re-compile, re-lint, or re-test `A`.

### Pin external dependencies as precisely as possible

It's nice to work with a range of versions of dependencies, but ensure that
there is at least one known-good, fully-specified list of dependencies. This
usually means a specific commit hash or tarball hash for each dependency.

*Justification*: This aids in reproducibility.

*Example*: Poetry and Cargo provides lock files that fully specify dependency
versions. CMake and Pip do not. Cabal can be configured to provide and use a
"freeze" file.

### Use ecosystem-appropriate tooling

To the extent that it's reasonable, use tooling that's common in the ecosystem
you're targeting.

*Justification*: This aids in maintainability by making it easier for likely
contributors (that is, people familiar with the ecosystem) to contribute. It
can also aid in debugging, in that others may have seen the same issues you're
seeing before.

*Example*: When building C++, use [Make](make.md), CMake, or Meson. Don't use
something super obscure.

*Example*: It's not always reasonable to use `pip` or `setuptools` for Python,
because they have notable flaws (e.g. `pip install` does extraneous work
when the package hasn't changed since the last call to `pip install`). When
using Python on a project, it may be appropriate to consider a different
build/packaging solution.

### Utilize content-addressing for build products where possible

*Justification*: Content-addressing provides an *extensional* view of when
dependencies change, leading to fewer rebuilds, i.e. speed.

*Example*: If package `B` depends on `A` and the README of `A` changes, but
doesn't affect the build products that `B` uses, don't rebuild `B`.

### Don't modify the user's system

The build system should only modify files inside the build directory. In
particular, it shouldn't install system-wide packages. There are certain
exceptions, for instance it's OK for Cabal's Nix-style builds to install
packages in `~/.cabal` because they are hermetically built.

*Justification*: This aids portability, because your assumptions about
 developers' (and CI systems') machines *will break*.

### Provide a source distribution

The build system should provide a target that packages all necessary source
files into an archive so that that archive can be unpacked and built with just
the files present plus those downloaded and managed by the build system.

*Justification*: This ensures all dependencies are accurately accounted for.
For instance, a common unstated dependency is a bunch of git submodules. It also
makes it easier to back up your sources.

## Research

- [Build systems a la carte](https://www.microsoft.com/en-us/research/publication/build-systems-la-carte/)
- [Riker: Always-Correct and Fast Incremental Builds from Simple Specifications](https://www.usenix.org/conference/atc22/presentation/curtsinger):
  Forward (tracing) build system

## Links

- [build system tradeoffs - jyn](https://jyn.dev/build-system-tradeoffs)
- [Neil Mitchell - Four Interesting Build Tools](http://neilmitchell.blogspot.com/2012/02/four-interesting-build-tools.html)
- [rattle](https://github.com/ndmitchell/rattle): forward build system
