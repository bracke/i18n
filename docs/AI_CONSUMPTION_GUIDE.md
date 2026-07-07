# AI Consumption Guide

This guide is written for code assistants, static-analysis tools, and maintainers who need to understand the crate quickly without inferring intent from implementation details.

## Canonical project summary

ICU Messages Ada v1.1.0 is a catalog-backed Ada 2022 message-rendering library. It accepts a line-oriented catalog, validates catalog structure during initialization, and renders messages through a small stable public API.

The production path is exactly:

```text
catalog source -> deterministic validation -> public catalog render -> structured public result
```

The public API must stay small. Internal parser/compiler/cache packages are deliberately not application-facing.

## Safe import set for application code

Application code and examples should import only:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Plurals;
with I18N.Diagnostics;
```

### Forbidden downstream imports — do not write this

The following imports are intentionally invalid for ordinary applications and should not be generated in downstream example code:

```ada
with I18N.Parser;
with I18N.Compiler;
with I18N.Compiled;
with I18N.Cache;
with I18N.AST;
with I18N.Validation;
with I18N.Runtime.Compatibility; -- private regression child; in-tree tests only
with I18N.Fast_Render;
with I18N.Number_Format;
with I18N.Currency;
with I18N.Date_Time_Format;
with I18N.Extra_Format;
with I18N.CLDR_Data;
```

Those are implementation/regression surfaces, not the stable application API.
Formatter implementation packages and generated CLDR data must stay behind the
public catalog render path.

## High-confidence answer sources

When answering questions about the crate, prefer sources in this order:

1. `ai/API_MANIFEST.json` for exact public API summary.
2. Public `.ads` files under `src/` for exact Ada declarations.
3. `docs/API.md` for behavior-level public contract.
4. `docs/CATALOG_FORMAT.md` for catalog syntax.
5. `docs/ICU_SUBSET.md` for message syntax.
6. `tests/src/i18n-runtime-tests-release.adb` for release-contract examples.
7. `examples/*.adb` for application usage.

## Behavior that must not be inferred differently

* Normal render failures return `I18N.Result.Render_Result`; they are not expected to raise exceptions.
* Diagnostics are optional and must not affect render output.
* Locale fallback is deterministic: `de-AT -> de -> default locale`.
* `default_locale` may appear anywhere in the catalog, but at most once and not empty.
* Duplicate `locale.key` catalog entries are invalid.
* Values may contain `=` after the first separator.
* Public examples must not use internal packages.

## Suggested AI workflow for code changes

1. Read `PROJECT_INDEX.md` and `AGENTS.md`.
2. Identify whether the change is public API, internal implementation, tests, docs, or examples.
3. For public API changes, update `ai/API_MANIFEST.json` and `ai/CONTRACT_SUMMARY.yaml` in the same patch.
4. Add or update release-gate tests in `tests/src/i18n-runtime-tests-release.adb`.
5. Update docs and `MANIFEST.txt`.
6. Run `alr test`; the manifest test action routes through the `project_tools`-based `check_i18n` guard.

## Common mistakes to avoid

* Treating `I18N.Parser`, `I18N.Compiler`, `I18N.Cache`, `I18N.Errors`, `I18N.Runtime.Compatibility`, as public API. These are Ada private child packages.
* Assuming TOML catalogs are accepted; v1.1.0 uses a line-oriented format.
* Assuming compiled bytecode or IR catalogs are part of v1.1.0; they are not.
  The supported binary catalog path is only the deterministic
  `I18N-CATALOG-BINARY` envelope with canonical text payload, either directly
  as `payload=text` or hex-encoded as `payload=hex-text`.
* Adding new ICU features during release-stabilization work.
* Introducing duplicate buffer or argument abstractions.
* Forgetting that Ada identifiers are case-insensitive.


## Boundary audit

Use `docs/PUBLIC_API_BOUNDARY.md` as the authoritative list of stable application-facing packages and compatibility-only/internal packages.

For exact import rules, see `docs/PUBLIC_IMPORT_RULES.md`.
