# Make

## Snippets

### Adding a suffix to a list of files

```make
BINS := $(SRC:=.bin)
```

### Depending on the `Makefile`

```make
# All rules should depend on the Makefile itself
THIS = $(abspath $(lastword $(MAKEFILE_LIST)))
```

### Listing (phony) targets

See above for `$(THIS)`.

```make
.PHONY: help
help:
 @printf 'Targets:\n'
 @grep '^\.PHONY: ' $(THIS) | cut -d ' ' -f2
```

### Setting the shell

```make
SHELL = bash
.SHELLFLAGS = -euo pipefail
```

## Useful functions

- `addprefix`
- `addsuffix`
- `dir`: Like Bash's `dirname`
- `notdir`: Like Bash's `basename`
- `subst`

## Automatic variables

### `$@`

<!-- marki[card] -->

Q. In GNU Make, what does the `$@` variable denote?

A. The target.

### `$<`

<!-- marki[card] -->

Q. In GNU Make, what does the `$<` variable denote?

A. The first prerequisite.

### `$?`

<!-- marki[card] -->

Q. In GNU Make, what does the `$?` variable denote?

A. All prerequisites that are newer than the target.

### `$^`

<!-- marki[card] -->

Q. In GNU Make, what does the `$^` variable denote?

A. All the prerequisites.
