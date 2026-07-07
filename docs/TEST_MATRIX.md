# Test Matrix

This document records v1.1.0 release-gate coverage. The executable AUnit suite is the source of truth; this document maps release requirements to concrete test areas by capability.

## Required release gates

| Release gate | AUnit coverage |
| --- | --- |
| Parser tests | strict parser/error tests and invalid corpus cases |
| Validator tests | structural validation tests and catalog initialization failures |
| Compiler tests | compiled-message and cache tests |
| IR equivalence tests | AST/render equivalence and corpus differential checks |
| Render tests | simple render, compiled render, catalog render, and public facade tests |
| Plural/select/selectordinal tests | ICU subset regression tests, locale-aware corpus cases, and nested formatted branch cases |
| Number-format tests | public catalog render, bounded render, invalid-argument, and compiled compatibility checks |
| Currency-format tests | public catalog render, bounded render, validation, invalid-argument, and compiled compatibility checks |
| Date/time-format tests | public catalog render, bounded render, invalid-argument, and compiled compatibility checks |
| Deterministic domain-format tests | duration, byte-size through PiB, direct unit and measure-unit/per-measure-unit skeletons, localized unit/relative/list text, explicit numbering-system digits, malformed inputs, and public/bounded render |
| Locale fallback tests | catalog fallback tests for regional locale, parent locale, default locale, and formatter behavior after fallback |
| Diagnostic tests | diagnostics/observability tests and public render non-interference checks |
| Fuzz smoke tests | randomized malformed and valid message smoke checks, formatted-argument parser fuzz, and malformed formatted-value validation fuzz for numeric, date/time, and domain formatters |
| Corpus regression tests | executable valid/invalid corpus assertions |
| Concurrency tests | shared-runtime concurrent rendering checks |
| Zero-allocation checks | fixed-buffer compatibility-path checks |
| Public API freeze tests | public-import smoke tests and catalog render tests |
| Catalog validation tests | catalog syntax, duplicate, default-locale, and empty-field checks |
| CLDR data-boundary checks | `check_i18n` requires `I18N.CLDR_Data`, the staged upstream source manifest, CLDR source-file inventory, generated JSONL export, the raw CLDR extract fixture and coverage manifest, the UTF-8/code-point normalized import source, the pinned CLDR subset source, checked IANA tzdb fixtures, source/export/raw/import/extract/generator/tzdb checkers, generated tzdb alias canonicalization and transition offsets, and formatter consumption of the data boundary |
| Public example output checks | `check_i18n --examples-only` runs public example executables and compares stable stdout with `examples/EXPECTED_OUTPUT.md`, with prefix checking for implementation-detail diagnostic text |

## Catalog-specific gates

The catalog release tests verify:

* public catalog rendering through `I18N`, `I18N.Runtime`, `I18N.Locales`, `I18N.Arguments`, `I18N.Plurals`, and `I18N.Result`;
* deterministic fallback from regional locale to parent locale to default locale, including canonical locale casing, deterministic CLDR language aliases, and formatting with the resolved locale;
* missing-key status stability;
* missing/invalid argument status mapping;
* full plural cardinal category branch selection across locales, fallback to `other`, plural offset branch selection, `#` substitution, bounded plural-rule expressions, and CLDR-shaped `plurals`/`pluralRules` container inheritance;
* nested select/plural branch rendering with nested number, currency, date, and time formatted arguments;
* deterministic number formatting, percent/permille/compact/scientific/engineering notation including CJK compact scaling for `ja`/`zh`/`ko`; precision including `::precision-unlimited`, `::precision-fraction/MIN-MAX`, `::precision-significant/MIN-MAX`, and `::precision-increment/N`/padding/integer-width zero- and optional-`#`-pattern aliases/expanded-rounding/sign-display aliases including `::sign-negative` and `::sign-accounting`/grouping-control aliases including `::group-min2`/decimal-display/trailing-zero-display/positive-integer-or-decimal-scale, `::spellout` and `::ordinal-words` skeletons including Basque coverage, signed whole-number input, cardinal decimal spellout input, `::spellout-year`, verbose RBNF aliases, inherited LDML RBNF `ruleset` container coverage, and CLDR trailing `>` RBNF divisor-marker coverage, runtime-loaded LDML number-symbol overrides including CLDR `defaultNumberingSystem` and nested `symbols` child rows, and `::currency/XXX` number skeleton with suffix or separate unit-width/cash/sign-accounting tokens parsing, locale separators/digits, Indian grouping, and malformed number value validation;
* deterministic currency formatting, symbol/name/narrow/unit-width/accounting/cash options and cash increments, zero-/three-/four-minor-unit metadata including `CLF`, additional ISO metadata/display-name corpus coverage, CLDR nested currency-symbol, currency-display-name, bounded currency-format pattern container imports, nested currency-spacing container imports including spacing metadata rows, and malformed currency amount validation;
* deterministic date/time/date-time `short`/`medium`/`long`/`full` style, `::short`/`::medium`/`::long`/`::full` style aliases, CLDR nested date/time/dateTime style pattern containers, CLDR weekData child-row imports, CLDR dayPeriodRuleSet/dayPeriodRules container imports including exact midnight/noon `at` rows, and `::` skeleton formatting with quoted literals, localized names, parsed fractional-second fields, standalone month fields, locale week fields, modified Julian day fields, localized GMT prefixes/offset separators/generic location patterns, short `z` specific zone abbreviations, short `v` generic zone labels, `V`-width zone identifiers/location labels, Buddhist/Japanese/ROC-Minguo/Julian/Coptic/Ethiopic/Islamic-civil/Indian-national/Persian calendar display, fixed zones, generated tzdb transition offsets, built-in DST-aware named-zone display families, bounded runtime transition-offset overrides, fixed-offset tzdb Zone continuation-row imports, historical DST windows, malformed date/time/instant validation, and malformed skeleton-option parser checks for unquoted braces, unterminated apostrophe quotes, and empty zone tails after quoted commas;
* deterministic domain formatting for durations with locale digits, byte sizes through `PiB`, strict decimal units, direct unit and `::measure-unit`/`per-measure-unit` skeleton aliases, source-backed short/narrow unit symbols, localized full unit names including source-backed unit `one` forms for all imported acre locales (`de`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, and `ko`), localized relative full/short/narrow second/minute/hour/day/week/month/quarter/year offsets including zero forms, exact relative-offset overrides, source-backed offset affixes, source-backed one/other relative unit display rows, CLDR `field`/`relativeTime` container imports, release-gated generated relative day past/future/current output for Bulgarian, Ukrainian, Persian, Thai, Hindi, Greek, Hebrew, Catalan, Azerbaijani, Urdu, and Serbian in addition to the older locale matrix, and built-in CLDR cardinal-category forms for Russian/Ukrainian and Polish from generated rows, localized list conjunctions including generated and runtime two-item/start/middle/final list-pattern separators plus CLDR `listPattern type="standard"` container imports, explicit numbering-system digits, bounded output, and malformed inputs;
* centralized CLDR-derived data consumption for formatter locale symbols, digits, localized date/time names, style patterns and separators, zone display data, generated tzdb alias canonicalization and transition offsets, number/currency affixes, unit/list separators, unit labels, currency metadata, date ordering, and plural rule-family mappings;
* deterministic fuzz coverage for formatted argument parser syntax and malformed number/currency/date/time/datetime/duration/bytes/unit/relative/list values;
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
* no release document promises unsupported TOML, binary behavior beyond the
  versioned envelope, CLDR compilation, VM/codegen, or public parser/compiler
  APIs.

## Verification gate

This matrix defines expected coverage. It is satisfied only after the test project builds and the test runner passes under GNAT/GPRbuild. Documentation review alone is not enough to close the release gate.
