# Validation and Release Gate

The v1.1.0 release freezes the test suite as the release gate. A v1.1.0 build is valid only if all release-gate groups pass.

Required groups:

* parser tests
* validator tests
* compiler tests
* IR equivalence tests
* render tests
* plural/select/selectordinal tests
* number-format tests
* currency-format tests
* date/time-format tests
* deterministic domain-format tests
* locale fallback tests
* diagnostic tests
* fuzz smoke tests, including formatted-argument parser fuzz and malformed formatted-value validation fuzz
* corpus regression tests
* concurrency tests
* zero-allocation checks
* public API freeze tests
* catalog validation tests
* CLDR data-boundary checks
* public example output checks
* benchmark smoke checks for render hot paths and bounded `Render_Into`
* runtime feature tests (shard loading, duplicate policy, `Load_Text`, non-destructive validation, key resolution, argument helpers, generalized select, plural categories, number formatting, currency formatting, date/time formatting, deterministic domain formatting, bounded render)

## Non-destructive validation API

`I18N.Runtime.Validate_Catalog_File` and `Validate_Catalog_Text` parse and validate a catalog without mutating any runtime, returning a `Catalog_Validation_Result` (`Valid`, `Entry_Count`, `Diagnostics`). They detect invalid catalog syntax, invalid locale prefixes, invalid keys, invalid ICU messages, missing required `other` branches, and duplicate keys within the input. Diagnostics name the offending source line (for example `invalid ICU message in app.catalog at line 47`). A failed validation never invalidates an existing runtime.

Corpus requirements remain in force:

```text
100% pass
0 semantic divergence
0 unexpected parser acceptances
0 unexpected parser rejections
```

## Public API freeze validation

Examples and public API tests must compile using only:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Any example requiring parser, AST, compiler, compiled IR, cache, buffer,
fast-render, lower-level renderer, formatter implementation, or generated CLDR
data packages is not a valid public example.

## Documentation validation

Documentation must describe implemented behavior only. A release is invalid if documentation promises:

* a TOML catalog parser;
* binary catalog behavior beyond the versioned `I18N-CATALOG-BINARY`
  envelope with `format_version=1`, `ir_version=1`, and `payload=text` or
  `payload=hex-text`;
* broad external CLDR plural-data generation outside the private checked-in `I18N.CLDR_Data` boundary;
* public parser/compiler access;
* public `Render` itself is zero-allocation;
* diagnostics that affect correctness;
* fallback semantics other than the frozen hyphen-parent/default-locale chain.


## Toolchain verification

The validation boundary is release-ready only when the project-tools-based `check_i18n` guard launched by `alr test` passes for the intended release channel.
