# Test Matrix

This document records v1.0 release-gate coverage. The executable AUnit suite is the source of truth; this document maps release requirements to concrete test areas by capability.

## Required release gates

| Release gate | AUnit coverage |
| --- | --- |
| Parser tests | strict parser/error tests and invalid corpus cases |
| Validator tests | structural validation tests and catalog initialization failures |
| Compiler tests | compiled-message and cache tests |
| IR equivalence tests | AST/render equivalence and corpus differential checks |
| Render tests | simple render, compiled render, catalog render, and public facade tests |
| Plural/select/selectordinal tests | ICU subset regression tests and corpus cases |
| Locale fallback tests | catalog fallback tests for regional locale, parent locale, and default locale |
| Diagnostic tests | diagnostics/observability tests and public render non-interference checks |
| Fuzz smoke tests | randomized malformed and valid message smoke checks |
| Corpus regression tests | executable valid/invalid corpus assertions |
| Concurrency tests | shared-runtime concurrent rendering checks |
| Zero-allocation checks | fixed-buffer compatibility-path checks |
| Public API freeze tests | public-import smoke tests and catalog render tests |
| Catalog validation tests | catalog syntax, duplicate, default-locale, and empty-field checks |

## Catalog-specific gates

The catalog release tests verify:

* public catalog rendering through `I18N.Runtime`, `I18N.Locales`, `I18N.Arguments`, and `I18N.Result`;
* deterministic fallback from regional locale to parent locale to default locale;
* missing-key status stability;
* missing/invalid argument status mapping;
* unbalanced catalog message rejection during initialization;
* empty catalog rejection;
* duplicate catalog entry rejection;
* duplicate `default_locale` rejection;
* empty `default_locale` rejection;
* empty locale/key rejection;
* malformed line rejection;
* catalog values containing `=` after the first separator;
* explicitly present empty message values rendering as successful empty text;
* late `default_locale` binding for unqualified message keys;
* non-invasive diagnostics and callback exception containment.

## Documentation gate

The documentation gate checks that:

* supported ICU syntax in `docs/ICU_SUBSET.md` matches tests;
* catalog rules in `docs/CATALOG_FORMAT.md` match catalog release tests;
* public status meanings in `docs/ERROR_MODEL.md` match `I18N.Result`;
* public examples avoid internal packages;
* no release document promises unsupported TOML, binary catalogs, CLDR compilation, VM/codegen, or public parser/compiler APIs.

## Verification gate

This matrix defines expected coverage. It is satisfied only after the test project builds and the test runner passes under GNAT/GPRbuild. Documentation review alone is not enough to close the release gate.
