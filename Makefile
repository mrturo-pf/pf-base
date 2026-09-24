# pf-base (this repo) has no build/install step of its own -- it's the
# ecosystem-level index (docs, architecture diagrams, cross-cutting
# scripts/), not a service. This Makefile exists solely to activate this
# repo's own .githooks/pre-commit (word-check against the pf ecosystem),
# consistent with `make install` in every other pf-* repo.

.PHONY: install

install:
	git config core.hooksPath .githooks
