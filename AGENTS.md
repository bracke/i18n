# AGENTS.md — AI Contributor Guide

This file is the fast-entry guide for AI coding agents and human maintainers working on ICU Messages Ada.

## Project identity

ICU Messages Ada is an Ada 2022 library for deterministic ICU-style message rendering. The v1.1.0 production path is:

```text
text catalog -> deterministic catalog validation -> read-only runtime lookup -> render -> structured result
```

This is the v1.1.0 release branch.

The completion scope includes eventual expansion of ICU runtime semantics,
Unicode algorithms, historical calendar data, runtime tzdb ingestion, and CLDR
RBNF behavior. Until those features are implemented and covered by release-gate
tests, documentation must describe the current deterministic behavior and mark
the expansion as planned work rather than as supported behavior.

## Stable public API

Application code may depend only on these packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Everything else under `src/` is implementation detail or compatibility/regression support.

## Primary files to read first

1. `PROJECT_INDEX.md` — repository map and entry points.
2. `docs/QUICKSTART.md` — smallest working usage flow.
3. `docs/API.md` — public API contract.
4. `docs/CATALOG_FORMAT.md` — catalog syntax.
5. `docs/ICU_SUBSET.md` — supported message syntax.
6. `docs/TEST_MATRIX.md` — release-gate coverage.
7. `ai/API_MANIFEST.json` — machine-readable public API summary.

## Build and test commands

```sh
alr test
```

`alr test` routes through `check_i18n`, the project-tools-based release guard.
Use this as the primary verification command locally and for release gating.

## Release verification rule

Do not mark the release complete from source/documentation inspection alone. Before public publication, run the library build, test project build, AUnit runner, example project, Alire build, and selected packaging/documentation tooling listed in `docs/RELEASE_VERIFICATION.md`.

## Coding rules

* Ada 2022.
* Keep public APIs documented with GNATdoc-compatible comments.
* Do not expose parser, validator, compiler, IR, cache, AST, buffer, formatter implementation packages, generated CLDR data, or execution internals through the public v1.1.0 facade.
* Do not use Ada reserved words as identifiers. Ada is case-insensitive, so variants such as `OtherS` collide with `others` and are invalid.
* Do not introduce duplicate argument map or buffer abstractions.
* Preserve deterministic failures: the same invalid catalog or message must produce the same classification.
* Preserve diagnostics non-interference: callbacks must not alter render output and callback exceptions must not escape.
* Preserve locale fallback: `language-region -> language -> default locale`.

## When adding examples

Add new examples under `examples/`, update:

* `examples/EXAMPLES_INDEX.md`
* `docs/EXAMPLES.md`
* `PROJECT_INDEX.md`
* `MANIFEST.txt`

Examples should use only public packages unless explicitly marked as implementation-regression examples.

## When changing public behavior

Update all of these in the same change:

* public package spec comments in `src/`
* `docs/API.md`
* `docs/ERROR_MODEL.md` if statuses or failures change
* `docs/CATALOG_FORMAT.md` if catalog behavior changes
* `docs/COMPATIBILITY.md`
* `ai/API_MANIFEST.json`
* `ai/CONTRACT_SUMMARY.yaml`
* release-gate tests

## Forbidden shortcuts

* Do not call internal parser/compiler packages from application-facing examples.
* Do not document behavior that is not covered by implementation and tests.
* Do not silently accept malformed catalogs.
* Do not replace deterministic status returns with normal exception flow for render failures.

## Alire packaging

Keep `alire.toml`, `i18n.gpr`, `docs/PACKAGING.md`, and `LICENSE` in sync. Do not list internal test/example projects as primary Alire project files unless the crate publication strategy changes.
