# Examples Index

All examples in this directory use the stable public v1.1.0 API only, unless a
file is explicitly identified as support code.

Build the example project with:

```sh
gprbuild -P examples/examples.gpr
```

Run examples from the repository root, for example:

```sh
./examples/bin/hello_world
```

## Catalogs

| File | Purpose |
| --- | --- |
| `catalogs/messages.catalog` | Main valid catalog used by examples. |
| `catalogs/invalid_duplicate.catalog` | Invalid catalog with duplicate key. |
| `catalogs/invalid_syntax.catalog` | Invalid catalog syntax example. |
| `catalogs/invalid_empty_locale.catalog` | Invalid catalog with an empty locale before the dot. |
| `catalogs/invalid_empty_key.catalog` | Invalid catalog with an empty key after the dot. |
| `catalogs/invalid_empty_default_locale.catalog` | Invalid catalog with an empty `default_locale`. |

## Programs

| File | Demonstrates |
| --- | --- |
| `hello_world.adb` | Shortest start-here render example matching the quickstart flow. |
| `basic_render.adb` | Basic catalog initialization and variable rendering. |
| `plural_render.adb` | ICU plural branch selection and `#` replacement. |
| `select_render.adb` | ICU select branch selection. |
| `selectordinal_render.adb` | ICU selectordinal branch selection, including locale-aware ordinal categories. |
| `nested_message_render.adb` | Nested supported constructs. |
| `number_formatting.adb` | Public number formatting with locale grouping, Arabic digits, Indian grouping, percent, permille, compact, scientific, engineering, sign-accounting, trailing-zero-display, scale, and spellout skeletons. |
| `currency_formatting.adb` | Public currency formatting with symbols, narrow symbols, ISO-code output, display names, cash rounding, accounting output, and zero-minor-unit metadata. |
| `date_formatting.adb` | Public date formatting with long/full styles, named, numeric, and locale week skeletons, plus Japanese, Buddhist, and Persian calendar output. |
| `time_formatting.adb` | Public time formatting with styles, day-period and fractional-second skeletons, zoned instant formatting, zone width skeletons, UTC widths, and datetime style aliases. |
| `domain_formatting.adb` | Public deterministic duration, byte-size, unit, measure-unit rates, localized relative-time, and localized list formatting. |
| `locale_fallback.adb` | Region, parent-language, and default-locale fallback. |
| `fallback_chain.adb` | Explicit `de-AT -> de -> en` fallback chain in one program. |
| `missing_key.adb` | Stable `Missing_Key` status. |
| `missing_argument.adb` | Stable `Missing_Argument` status. |
| `invalid_argument.adb` | Stable `Invalid_Argument` status for numeric branch input. |
| `invalid_catalog.adb` | Deterministic invalid catalog handling for duplicate and malformed lines. |
| `invalid_catalog_fields.adb` | Deterministic rejection of empty locale/key/default-locale fields. |
| `diagnostics_non_interference.adb` | Diagnostics callbacks do not change render results. |
| `diagnostics_inspection.adb` | Reading diagnostic entries from an error `Render_Result`. |
| `equals_in_value.adb` | `=` after the first separator remains part of catalog value. |
| `reuse_runtime.adb` | Reusing an initialized runtime for multiple render calls. |
| `status_handling.adb` | Exhaustive handling of the frozen `Render_Status` enumeration. |
| `default_locale_key.adb` | Unqualified catalog keys are assigned to the configured default locale. |
| `empty_message.adb` | Empty catalog values render successfully as empty text. |
| `argument_lifecycle.adb` | Public argument-map `Set`, `Has`, `Get`, and `Clear` operations. |
| `public_api_example.adb` | Minimal public API render smoke example. |
| `public_api_sealed.adb` | Public import-boundary smoke example covering only stable packages. |

## Support files

| File | Purpose |
| --- | --- |
| `example_support.ads` / `example_support.adb` | Shared helper routines for examples. |
| `example_trace_callbacks.ads` / `example_trace_callbacks.adb` | Diagnostics callback helpers. |
| `EXPECTED_OUTPUT.md` | Command-by-command expected output for manual validation. |
