SHELL = bash -euo pipefail
THIS = $(abspath $(lastword $(MAKEFILE_LIST)))

NOTES := $(wildcard md/*.md) $(wildcard notes/*.md)
OUT := out

$(shell mkdir -p $(OUT))

.PHONY: all
all:

.PHONY: help
help:
	@printf 'Targets:\n'
	@grep '^\.PHONY: ' $(THIS) | cut -d ' ' -f2

all: $(OUT)/marki.apkg
$(OUT)/marki.apkg: $(NOTES)
	marki --deck 'All::Marki' --verbose --output $@ -- $(addprefix ",$(addsuffix ",$(NOTES)))
