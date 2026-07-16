# ICU/CLDR 100 Percent Completion Checklist

This file is the repository's hard completion contract for the explicit goal:
full ICU/CLDR behavior, with no unsupported ICU/CLDR feature remaining.

Completion is not inferred from milestone names. The project may claim
`Overall status: COMPLETE` only when every checklist line below is checked and
the required local gate has passed on the same source state.

Overall status: INCOMPLETE

Target baseline:

1. Unicode version: 17.0.0.
2. CLDR version: 48.2.
3. ICU behavior baseline: ICU 78.3.
4. Verification mode: local Ada tooling through Alire; no standalone scripts.

Required local gate before any completion claim:

1. `alr build`.
2. `cd tests && alr exec -- gprbuild -P tests.gpr`.
3. `cd tests && alr exec -- ./bin/tests`.
4. `alr exec -- gprbuild -P examples/examples.gpr -j1`.
5. Run every public example binary checked by `check_i18n`.
6. `alr exec -- gprbuild -P benchmarks/benchmarks.gpr -j1`.
7. `alr exec -- ./benchmarks/bin/render_benchmarks --smoke`.
8. `cd check_i18n && alr exec -- ./bin/check_i18n --skip-alr-test`.
9. `alr test`.

The checklist is intentionally unchecked until the implementation and
conformance gates exist and pass. `check_i18n` rejects a completion claim while
any `- [ ]` item remains.

## 1. Conformance Harness

1. - [x] Add Ada conformance runners for Unicode, CLDR, ICU message syntax,
   formatting, collation, segmentation, normalization, calendars, time zones,
   number/currency/unit formatting, RBNF, lists, display names, and locale IDs.
2. - [x] Add deterministic fixture manifests for the imported Unicode/CLDR/ICU
   test data.
3. - [x] Add comparison reports that fail on every mismatch, missing fixture,
   unsupported option, and fallback not matching the target baseline.
4. - [x] Wire the conformance runners into `check_i18n` and `alr test`.

## 2. Full CLDR Data Pipeline

1. - [ ] Import the complete CLDR 48.2 source families needed for ICU services,
   not a selected subset.
2. - [ ] Generate all runtime data from checked CLDR source fixtures with
   reproducible Ada tooling.
3. - [ ] Validate every generated table against record counts, locale coverage,
   parent fallback, aliases, likely subtags, numbering systems, calendars,
   currencies, units, RBNF, plural rules, transforms, collation, and time zones.
4. - [ ] Remove all selected-locale and selected-zone coverage limits.

## 3. Unicode Core

1. - [ ] Implement Unicode properties required by ICU services.
2. - [ ] Implement full UTF-8 validation and scalar iteration behavior.
3. - [ ] Implement UnicodeSet parsing and matching where ICU data requires it.
4. - [ ] Verify Unicode behavior against Unicode 17.0.0 conformance data.

## 4. Normalization

1. - [ ] Implement NFC, NFD, NFKC, NFKD, FCD, quick-check, and stream-safe
   behavior.
2. - [ ] Apply normalization where ICU services require it.
3. - [ ] Verify against the Unicode normalization conformance suite.

## 5. Case, Transforms, and Transliteration

1. - [ ] Implement full case mapping, case folding, titlecasing, and
   locale-sensitive casing.
2. - [ ] Implement CLDR/ICU transform and transliteration rules.
3. - [ ] Verify against upstream transform and casing fixtures.

## 6. Segmentation

1. - [ ] Implement grapheme, word, sentence, and line break algorithms.
2. - [ ] Implement dictionary and locale-tailored segmentation where CLDR/ICU
   requires it.
3. - [ ] Verify against Unicode break tests and ICU locale tailoring behavior.

## 7. Collation and Search

1. - [ ] Implement UCA collation, CLDR tailorings, sort keys, comparison levels,
   numeric collation, normalization handling, and search behavior.
2. - [ ] Verify against CLDR collation test data and ICU comparison behavior.

## 8. Locale IDs and Locale Services

1. - [ ] Implement complete BCP-47/Unicode locale identifier parsing,
   canonicalization, aliases, likely subtags, parent locales, and fallback.
2. - [ ] Implement display names, language/script/region/variant names,
   measurement data, layout data, list patterns, and person-name data.
3. - [ ] Verify every CLDR locale in the imported baseline.

## 9. Plurals and Ordinals

1. - [ ] Implement complete CLDR cardinal, ordinal, and range plural rules,
   including operands and sample validation.
2. - [ ] Verify every CLDR plural locale and category against CLDR data.

## 10. Numbers and Currencies

1. - [ ] Implement full decimal, percent, permille, compact, scientific,
   engineering, numbering-system, rounding, padding, grouping, sign, parsing,
   and skeleton behavior.
2. - [ ] Implement every ISO and CLDR currency record, symbol, narrow symbol,
   localized display name, accounting form, cash rounding rule, spacing rule,
   and parsing behavior.
3. - [ ] Verify all CLDR number and currency locales against ICU behavior.

## 11. Date, Time, Calendars, and Time Zones

1. - [ ] Implement full date/time skeletons, styles, flexible day periods,
   interval formats, parsing, and locale preference data.
2. - [ ] Implement every CLDR calendar supported by ICU, including historical
   data where ICU behavior requires it.
3. - [ ] Implement complete IANA tzdb ingestion, transitions, aliases, exemplar
   cities, metazones, generic/specific names, and zone formatting/parsing.
4. - [ ] Verify all date/time/calendar/time-zone behavior against CLDR/ICU.

## 12. Message Formatting

1. - [ ] Implement ICU MessageFormat behavior, escaping, apostrophes, offsets,
   nested selectors, formatted arguments, errors, and parsing compatibility.
2. - [ ] Implement any newer ICU message-format behavior selected for the target
   baseline.
3. - [ ] Verify against ICU message conformance and differential render tests.

## 13. RBNF

1. - [ ] Implement full CLDR rule-based number formatting and parsing.
2. - [ ] Support all rule-set syntax, substitutions, plural-sensitive rules,
   fractions, ordinals, spellout, numbering, and locale fallback.
3. - [ ] Verify every CLDR RBNF locale and rule set.

## 14. Units, Lists, Names, and Miscellaneous CLDR Services

1. - [ ] Implement all CLDR unit formatting, compound units, measurement-system
   preferences, list patterns, relative time, display names, and person names.
2. - [ ] Verify every CLDR locale and width/category combination.

## 15. Public Contract and Release Gate

1. - [ ] Update public docs and metadata to describe exactly the implemented
   full ICU/CLDR surface.
2. - [ ] Remove every bounded-subset, selected-locale, selected-zone, planned,
   and unsupported ICU/CLDR statement that is no longer true.
3. - [ ] Keep deterministic failures and diagnostics non-interference.
4. - [ ] Pass the required local gate listed at the top of this file with no
   unchecked completion items.
