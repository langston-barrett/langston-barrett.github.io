# bat > .git/hooks/pre-commit <<EOF
# #!/usr/bin/env bash
# make -j8 all
# EOF
# chmod +x .git/hooks/pre-commit

SHELL = bash -euo pipefail
THIS = $(abspath $(lastword $(MAKEFILE_LIST)))

NOTES := $(wildcard md/*.md) $(wildcard notes/*.md)
POSTS := $(wildcard blog/*.md)
OUT := out
MDLYNX := $(HOME)/.cargo/bin/mdlynx

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

all: lint
.PHONY: lint

MD = $(shell $(LS_FILES) '*.md')

lint: markdownlint
.PHONY: markdownlint
markdownlint: $(addsuffix .markdownlint, $(addprefix $(OUT)/, $(NOTES) $(POSTS)))
$(OUT)/%.md.markdownlint: %.md $(THIS)
	@printf "markdownlint %s\n" '$<'
	@mkdir -p -- '$(OUT)/$(dir $<)'
	@markdownlint --fix --config markdownlint.jsonc -- '$<' && touch -- '$@'

lint: missing
.PHONY: missing
missing: $(addsuffix .missing, $(addprefix $(OUT)/, $(NOTES)))
$(OUT)/%.md.missing: %.md $(THIS)
	@printf "missing %s\n" '$<'
	@mkdir -p -- '$(OUT)/$(dir $<)'
	@grep "$(notdir $<)" SUMMARY.md > /dev/null 2>&1 && touch -- '$@'

lint: mdlynx
.PHONY: mdlynx
mdlynx: $(addsuffix .mdlynx, $(addprefix $(OUT)/, $(NOTES) $(POSTS)))
$(OUT)/%.md.mdlynx: %.md $(THIS)
	@printf "mdlynx %s\n" '$<'
	@mkdir -p -- '$(OUT)/$(dir $<)'
	@mdlynx -- '$<' && touch -- '$@'

# TODO: Also scan POSTS
lint: typos
.PHONY: typos
typos: $(addsuffix .typos, $(addprefix $(OUT)/, $(NOTES)))
$(OUT)/%.md.typos: %.md $(THIS)
	@printf "typos %s\n" '$<'
	@mkdir -p -- '$(OUT)/$(dir $<)'
	@typos -- '$<' && touch -- '$@'

lint: whitespace
.PHONY: whitespace
whitespace: $(addsuffix .whitespace, $(addprefix $(OUT)/, $(NOTES) $(POSTS)))
$(OUT)/%.md.whitespace: %.md $(THIS)
	@printf "whitespace %s\n" '$<'
	@mkdir -p -- '$(OUT)/$(dir $<)'
	@if grep -E '[[:space:]]+$$' -- '$<'; then exit 1; else touch -- '$@'; fi
