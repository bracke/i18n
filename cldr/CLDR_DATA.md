# CLDR Data Subset

This directory records the deterministic CLDR-derived data subset compiled into
`src/i18n-cldr_data.adb`.

## Generated target

`I18N.CLDR_Data` is the internal generated-data boundary. Runtime formatter
packages must consume that package instead of carrying independent locale or
currency tables.

## Source and checkers

The staged upstream export fixture is `cldr/upstream/cldr_export.jsonl`, with
release provenance in `cldr/upstream/source_manifest.txt` and CLDR source-file
inventory in `cldr/upstream/source_files.txt`. The Ada tool
`cldr/src/check_cldr_sources.adb` validates the declared upstream CLDR JSON
families and source-path inventory. The checked IANA tzdb 2026a fixtures live
under `cldr/upstream/tzdb/`; `cldr/src/check_tzdb_sources.adb` validates the
tzdb manifest, `tzdata.zi`, `zone1970.tab`, `zone.tab`, and `leapseconds`
before release checks proceed. The Ada tool
`cldr/src/generate_cldr_export.adb` generates the staged number, date-name,
currency, and plural export rows from CLDR JSON source fragments. The Ada tool
`cldr/src/import_cldr_raw.adb` validates those
deterministic JSONL records with `project_tools` JSON helpers, checks the source
manifest, and imports `cldr/raw/cldr_records.txt`. The raw extract fixture has
release coverage requirements in `cldr/raw/coverage.txt`.
The Ada tool `cldr/src/extract_cldr_normalized.adb` validates that coverage
manifest and normalizes the CLDR-family records into
`cldr/import/normalized_cldr.txt`. The Ada tool `cldr/src/import_cldr_subset.adb`
expands compact normalized rows into the pinned subset source
`cldr/data/cldr_subset.txt`. The Ada tool `cldr/src/generate_cldr_data.adb` then
emits `src/i18n-cldr_data.adb` from that pinned subset plus checked tzdb alias
and transition metadata. All tools are built by
`cldr/cldr_tools.gpr` and use `project_tools` helpers. Run them from `cldr/`:

```sh
alr exec -- gprbuild -P cldr_tools.gpr
./bin/check_cldr_sources --check
./bin/check_tzdb_sources --check
./bin/generate_cldr_export --check
./bin/import_cldr_raw --check
./bin/extract_cldr_normalized --check
./bin/import_cldr_subset --check
./bin/generate_cldr_data --check
```

The source checker validates the declared upstream CLDR JSON package path
inventory, duplicate source paths, required `numbers`, `dates`, and
`supplemental` families, source-family provenance, source-file count, source
file existence, and per-file `cldrVersion` identity.

The tzdb source checker validates the checked IANA tzdb 2026a rearguard
fixtures, public-domain provenance markers, required source-file set, primary
zone rows, link rows, `zone1970.tab` and `zone.tab` references, and
leap-second row coverage. Runtime formatting does not load `/usr/share/zoneinfo`
or any external tzdb files.

The export generator derives decimal/group symbols and default numbering-system
digits for every imported CLDR number locale, explicit `nu-*` rows for every
generated CLDR numeric numbering system, Indian grouping policy,
day-month-year locale policy, localized month/weekday names for every imported
CLDR date locale, localized quarter names for every imported date locale,
source-backed AM/PM names for every imported date locale, localized
midnight/noon and generated flexible morning/afternoon/evening/night names
where CLDR supplies them,
localized GMT offset prefixes, offset separators, and generic time-zone
location patterns for imported CLDR date locales,
generated localized `Etc/UTC` long display names where CLDR supplies them,
generated source-backed fixed-zone display names for the selected built-in
fixed-zone set checked by `cldr/raw/coverage.txt` across imported CLDR date
locales where CLDR supplies metazone names, generated source-backed
generic-family display names for existing DST family keys plus Lord Howe and
fixed Australian eastern, central, central-western, and western zones where
CLDR supplies metazone names, and source-backed short-family time-zone display
names where present,
selected localized list-pattern
separators, symbol-first policy, currency metadata, and cardinal/ordinal
plural-family mappings from CLDR-shaped source fragments.

The raw importer validates staged JSONL record kind, duplicate staged keys,
numbering-system code-point width, currency metadata shape, raw field safety,
and source-manifest `cldr_version`, `source_family`, export path, and record
count. Without arguments it rewrites `cldr/raw/cldr_records.txt`; with `--check`
it compares imported bytes with the checked-in raw source and fails on drift.

The extractor validates raw record shape, duplicate raw keys, name-set widths,
numbering-system code-point lists, currency metadata shape, plural-family
records, and the declarative coverage manifest. Without arguments it rewrites
`cldr/import/normalized_cldr.txt`; with `--check` it compares extracted bytes
with the checked-in normalized source and fails on drift.

The importer validates normalized row shape, converts UTF-8 text rows into
Ada-safe string expressions, converts Unicode code-point lists into generated
table literals, and expands compact indexed month/weekday/quarter rows. Without
arguments it rewrites `cldr/data/cldr_subset.txt`; with `--check` it compares
the imported bytes with the checked-in subset and fails on drift.

The generator parses the pinned subset rows and checked tzdb zone/link rows,
uses `zic` and `zdump` to derive transition offsets from the checked
`tzdata.zi` fixture for 1900 through 2050, then emits
`src/i18n-cldr_data.adb`. Without arguments it rewrites the generated package
body; with `--check` it compares the generated bytes with the checked-in target
and fails on drift.

Before either writing or checking the generated body, the generator validates
row shape, required fields, numeric month/weekday ranges, digit row width,
numeric quarter ranges, duplicate data keys, and the English fallback rows
required by generated date name functions.

## Current data families

1. Locale primary-subtag lookup for formatter policy.
2. Decimal and grouping separators for all 725 imported CLDR 46.1 number
   locales, with exact and parent-locale fallback at runtime.
3. Default numbering-system digit substitution for imported CLDR number
   locales, plus explicit Arabic-Indic, extended Arabic, Thai, Devanagari, and
   Bengali `-u-nu-*` digit overrides.
4. Plus/minus signs, accounting wrappers, percent, permille, compact-number,
   and exponent display affixes.
5. Indian grouping policy.
6. Day-month-year date ordering and deterministic date-style patterns for
   built-in style formats.
7. Generated first-day-of-week and first-week-minimum-day preferences for
   deterministic week-year, week-of-year, week-of-month, and local weekday
   skeleton fields, with runtime data overrides taking precedence.
8. Deterministic time-style patterns, date/time skeleton field separators,
   and date-time style separators for built-in style formats.
9. Localized full and abbreviated month and weekday names for all 725 imported
   CLDR 46.1 date locales, with exact and parent-locale fallback at runtime.
10. Localized wide and abbreviated quarter-name formatting for all 725
   imported CLDR 46.1 date locales, with exact and parent-locale fallback at
   runtime.
11. Day-period display names for time skeleton formatting, including
    source-backed AM/PM rows for all 725 imported CLDR 46.1 date locales and
    source-backed midnight/noon plus flexible morning/afternoon/evening/night
    rows where CLDR supplies them, with
    deterministic fallback formatting outside the supplied rows.
12. Calendar era display names and era/year separators for supported
    deterministic calendars.
13. Built-in named time-zone base offsets, deterministic DST rule-family
   mappings, source-backed localized fixed-zone display names for selected
   zones generated across imported CLDR date locales where CLDR supplies
   metazone names,
   generated source-backed generic-family display names for existing DST
   family keys plus Lord Howe and fixed Australian eastern, central,
   central-western, and western zones where CLDR supplies metazone names,
   source-backed short-family
   display names where present, deterministic fallback zone display names,
   source-backed GMT offset prefixes, offset separators, and generic
   location patterns for imported CLDR 46.1 date locales, plus deterministic
   UTC designators. Checked IANA tzdb 2026a
   source fixtures are present, validated, and used to generate canonical alias
   mappings plus seconds-based UTC transition-offset tables for 447 primary
   zones over 1900 through 2050 in `I18N.CLDR_Data`; runtime formatting does
   not load external tzdb files.
14. CLDR 46.1 currency minor-unit and cash-rounding metadata for 307
    generated currency codes.
15. Currency symbols, narrow symbols, English display names for the 307-code
    CLDR 46.1 generated table, localized currency display-name payloads for
    all imported CLDR currency-name locales with zero, one, two, few, many, and
    other category slots plus exact, parent, and default fallback, symbol
    placement, amount spacing, and accounting wrappers.
16. Localized standard/and, or/disjunction, and unit list-pattern families
    with two-item, start, middle, final, and generic item separators,
    including staged CLDR list-pattern rows
    for `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`,
    `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, `ko`, `tr`, `sv`, `da`,
    `no`, `fi`, `id`, `ms`, `eo`, `vi`, `sw`, `af`, `eu`, `hu`, `sk`,
    `bg`, `uk`, `fa`, `th`, `hi`, `el`, and `he`, with source-backed
    typed `or` and `unit` separators for the same list-locale set and
    deterministic fallback formatting outside that set.
17. Localized per-unit separators, including staged CLDR per-unit rows for
    the same source-backed list-locale set, plus deterministic fallback
    formatting, short/narrow per-unit separators, numeric unit-value separators,
    and duration field separators.
18. Localized long unit display names, source-backed English full names for all supported units, source-backed German full names for the generated German fallback-unit set, source-backed Italian, Portuguese, Dutch, Romanian, Lithuanian, Slovenian, Polish, Czech, Russian, Arabic, Japanese, Chinese, and Korean full names for their generated extended-unit sets, English fallback names, source-backed
    short/narrow unit symbols, and byte-size unit labels for selected
    measurement and relative-time units.
19. Deterministic English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Japanese, Chinese, Korean, Turkish, Swedish, Danish, Norwegian, Finnish, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Catalan, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, and Hebrew spellout and ordinal-word labels for the built-in
    number skeleton subset.
20. Localized relative-time full/short/narrow current second/minute/hour/day/week/month/quarter/year
    labels and complete nonzero full/short/narrow second/minute/hour/day/week/month/quarter/year
    future/past plural-category patterns generated
    from source-backed CLDR date-field rows for all imported CLDR 46.1 date
    locales where CLDR supplies them, source-backed offset affix patterns,
    source-backed Russian/Ukrainian/Polish relative unit category names,
    source-backed English one/other second/minute/hour/day/week/month/quarter/year rows, source-backed
    one/other relative unit display rows for selected locales, and
    source-backed German plural day/month/year display overrides.
21. Generated CLDR 46.1 cardinal and ordinal plural rule-family mappings for
    all 219 cardinal locale IDs and all 104 ordinal locale IDs in the checked
    source, evaluated by the built-in deterministic family implementations.

## Regeneration rule

The staged CLDR import tooling can replace or expand
`cldr/upstream/cldr_export.jsonl` with broader upstream CLDR release exports
while keeping this checked pipeline and manifest updated with the covered
families. The public API must remain `I18N.Runtime`, `I18N.Result`,
`I18N.Diagnostics`, `I18N.Arguments`, `I18N.Locales`, and `I18N.Plurals`;
generated CLDR data stays private.
