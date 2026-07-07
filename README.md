# ICU Messages Ada

i18n is an Ada 2022 message-formatting library for a strict, deterministic ICU-style subset. The v1.1.0 application-facing contract is catalog-based:

```text
catalog file -> initialization -> deterministic catalog validation -> locale/key lookup -> structured render result
```

The stable public packages are:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Applications should not depend on parser, validator, compiler, AST, compiled IR, cache, buffer, lower-level renderer, formatter implementation, or generated CLDR data packages. Those packages remain in the source tree for implementation and regression testing, but they are outside the source-compatibility guarantee.

## Supported ICU subset

The ICU subset supports:

* literal text
* variables: `{name}`
* plural blocks with exact integer branches such as `=0`, optional `offset:N`, full cardinal category branches (`zero`, `one`, `two`, `few`, `many`, `other`), and required `other`
* select blocks with **arbitrary validated identifier branch names** and a required `other` branch (the legacy `male`/`female`/`other` branches keep working unchanged)
* selectordinal blocks with exact integer branches such as `=11`, full ordinal category branches, and required `other`
* deterministic grouped number formatting with percent, permille, compact/scientific/engineering notation, including CJK compact 10,000 and 100,000,000 scaling for `ja`, `zh`, and `ko`, precision including `::precision-unlimited`, fraction precision ranges such as `::precision-fraction/0-2`, and significant precision ranges such as `::precision-significant/1-3`, integer-width zero- and optional-`#`-pattern padding, expanded rounding and rounding-increment skeletons, accounting sign-display aliases including `::sign-negative`, `::sign/accounting`, and `::sign-accounting`, grouping-control aliases including `::group-min2`, decimal-display, trailing-zero-display slash and hyphen aliases, and positive integer/decimal scale skeletons: `{value, number}`, `{value, number, ::percent}`, `{value, number, ::compact-short}`
* deterministic CLDR-style currency formatting: `{amount, currency, USD}`, `{amount, currency, USD/accounting}`, slash-composed direct aliases such as `{amount, currency, CHF/cash/unit-width/full-name/accounting}`, `{amount, number, ::currency/USD}`, and separate-token forms such as `{amount, number, ::currency/CHF precision-currency/cash sign/accounting unit-width/full-name}`
* deterministic date/time/instant formatting with `short`, `medium`, `long`, and `full` styles plus ICU-style skeletons and generated CLDR `availableFormats` order for common skeletons: `{day, date, full}`, `{clock, time, long}`, `{day, date, ::yMMMd}`, `{clock, time, ::hhmmssa}`, and `{instant, datetime, ::yMdHHmmssz, UTC}`
* nesting of supported constructs
* `#` substitution in plural and selectordinal branches
* ICU-style apostrophe escaping for literal `{`, `}`, `#`, and apostrophe text

Generalized select example:

```text
{width, select, full {hour} short {hr} narrow {h} other {hour}}
```

`other` is required, duplicate branches are rejected, unmatched selector values use `other`, and branch names must be valid identifiers.

Current v1.1.0 boundaries: unsupported format skeletons and public parser/compiler
access remain unsupported. Full CLDR RBNF rule sets, broader non-Gregorian
historical calendar data, arbitrary LDML/tzdb source ingestion, and alternative
code-generation execution paths are part of the completion scope; the current
runtime supports the deterministic RBNF, calendar, runtime-data override, and
normalized CLDR import formats documented below.

## Catalog format

The canonical v1.1.0 catalog format is line-oriented text:

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
```

`default_locale` may appear anywhere, but it may appear at most once and must not be empty. Entries use `locale.key = ICU message`. Duplicate `locale.key` entries, empty locale names, empty keys, malformed lines, and unbalanced catalog message braces make initialization invalid deterministically. Deeper ICU construct errors are reported deterministically by render/status paths and regression tests.

## Minimal example

```ada
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Example is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, "messages.catalog");
   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "welcome",
           Arguments => Args);
   begin
      if Result.Status = I18N.Result.Success then
         null; -- I18N.Result.Output_Text (Result.Text) contains the rendered message.
      end if;
   end;
end Example;
```

## Runtime behavior

Initialization reads the text catalog, records deterministic failure state if the catalog file itself is invalid, and stores normalized locale/key/source entries for lookup. Public rendering resolves locale fallback, locates the stored source, and evaluates it through the public catalog render path. Internal regression paths exercise the parser/validator/compiler/cache pipeline for the strict ICU subset and fixed-buffer execution checks, but public callers never receive parser, compiler, cache, or compiled-message handles. Public `Render` does not raise for normal message failures; it returns `I18N.Result.Render_Result` with a stable `Render_Status`.

Locale fallback is fixed as:

```text
de-AT -> de -> default locale
```

Catalog locale prefixes, `default_locale`, and public render/resolve requests
are canonicalized before lookup: language subtags are lower-case, script
subtags title-case, region subtags upper-case, extension subtags lower-case,
and deterministic CLDR language aliases such as `iw -> he`, `in -> id`,
`ji -> yi`, and `sh -> sr-Latn` are applied.

If the key is still absent after fallback, render returns `Missing_Key`.

Catalog entries are parsed, validated, and compiled to an AST **once at load time** and stored behind a deterministic `(locale, key)` index. Rendering fetches the compiled entry (O(1) per locale, bounded by locale fallback depth) and executes it (O(output length)); it never re-parses message source on the hot path.

## Catalog shard loading

A single runtime can layer multiple catalog shards, for example a base application catalog, an optional library catalog, and an optional user override shard:

```ada
declare
   Runtime : I18N.Runtime.Instance;
   Result  : I18N.Runtime.Load_Result;
begin
   I18N.Runtime.Initialize (Runtime, "app.catalog");          -- base
   I18N.Runtime.Load_File  (Runtime, "lib.catalog", Result);  -- library shard
   I18N.Runtime.Load_File  (Runtime, "user.catalog", Result,
                            Policy => I18N.Runtime.Override_Previous);
end;
```

`Load_File` and `Load_Text` are transactional and non-destructive: either every entry in the input is ingested or the runtime is left exactly as it was. A failed shard load never corrupts an already usable runtime. The outcome is reported in `Load_Result` (`Status`, `Entries_Added`, `Entries_Replaced`, `Entries_Ignored`, `Diagnostics`); statuses are `Loaded`, `Source_Not_Found`, `Invalid_Catalog`, `Duplicate_Rejected`, and `Runtime_Invalid`. The counters distinguish newly added pairs, entries overwritten under `Override_Previous`, and duplicates skipped under `Keep_First`.

A `default_locale` directive is adopted only when the runtime has no default locale yet, so a runtime can be built entirely from `Load_Text`/`Load_File`. Once `Initialize` (or an earlier load) has established the default locale, later shard directives are ignored.

`Load_Text` ingests an in-memory catalog string with the same semantics, using a caller-supplied source name for diagnostics.

### Duplicate policy

`Duplicate_Policy` controls how an incoming `locale/key` that already exists is handled:

| Policy | Behavior |
| --- | --- |
| `Reject_Duplicates` (default) | Loading fails on any duplicate; prior entries are unchanged. |
| `Keep_First` | The existing entry stays active; the duplicate is ignored. |
| `Override_Previous` | The new entry replaces the previous entry. |

## Non-destructive validation

`Validate_Catalog_File` and `Validate_Catalog_Text` parse and validate a catalog without touching any runtime. They return a `Catalog_Validation_Result` (`Valid`, `Entry_Count`, `Diagnostics`) and detect invalid catalog syntax, invalid locale prefixes, invalid keys, invalid ICU messages, missing required `other` branches, and duplicate keys within the input. If validation fails, any existing runtime remains usable.

## Key resolution

`Resolve` reports whether a key is reachable through the locale fallback chain **without rendering it** and without requiring arguments:

```ada
R : constant I18N.Runtime.Resolve_Result :=
  I18N.Runtime.Resolve (Runtime, "de-AT", "welcome");
--  R.Status is Found / Missing_Key / Runtime_Invalid
--  I18N.Runtime.Resolved_Locale (R) is the locale that satisfied the request
```

## Argument helper setters

Arguments remain string-valued, with helpers that serialize common values correctly:

```ada
I18N.Arguments.Set_Integer (Args, "delta", -3);   -- "-3" (strict decimal, no 'Image space)
I18N.Arguments.Set_Natural (Args, "count", 0);     -- "0"
I18N.Arguments.Set_Boolean (Args, "active", True); -- "true" / "false"
```

These helpers are deterministic and intentionally **not** locale-aware; they prepare selector/argument values for the message engine.

## Plural categories

`I18N.Plurals` classifies a value into a CLDR plural category for a locale:

```ada
I18N.Plurals.Cardinal ("en", 1);  -- One
I18N.Plurals.Ordinal  ("en", 2);  -- Two   ("2nd")
I18N.Plurals.Ordinal  ("en", 3);  -- Few   ("3rd")
I18N.Plurals.Cardinal ("fr", 1, 1, 5);  -- One for CLDR operands i=1, v=1, f=5
```

Categories are `Zero`, `One`, `Two`, `Few`, `Many`, `Other`. Cardinal and ordinal rule-family mappings are generated from the checked CLDR 46.1 source subset and evaluated by built-in deterministic families. The checked-in tables cover all 219 CLDR cardinal locale IDs and all 104 CLDR ordinal locale IDs from that source, with exact locale matching before parent fallback. Integer entry points use whole values with fraction digits zero and consult any process-wide exact plural overrides loaded through `I18N.Runtime` before generated fallback rules; the overloaded cardinal classifier accepts explicit CLDR fractional operands `i`, `v`, and `f`. Locales outside the generated CLDR set use the root rule (`Other`).

The public catalog render path uses these rules to pick `plural` and `selectordinal` branches by the **resolved** locale, so English `{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}` correctly renders `21st`, `22nd`, `23rd`, and `11th`/`12th`/`13th`; `selectordinal` also accepts `zero` and `many` branches for locales whose ordinal rules produce them. Exact integer branches such as `=0` and `=11` take precedence over category branches, non-offset `plural` selectors accept strict decimals such as `1.5` using CLDR fractional operands, offset plurals and `selectordinal` remain integer-only, and a plural/ordinal category with no matching branch falls back to `other`. (The internal compatibility/IR render path used only by in-tree regression tests remains locale-agnostic.)

## Bounded rendering

`Render_Into` renders the compiled message directly into caller-owned fixed storage — each fragment is written straight into the buffer, with no intermediate dynamic allocation:

```ada
Buffer : String (1 .. 256);
Last   : Natural;
Status : I18N.Result.Render_Status;
...
I18N.Runtime.Render_Into (Runtime, "en", "welcome", Args, Buffer, Last, Status);
--  Success: Buffer (Buffer'First .. Last) holds the output.
--  Buffer_Overflow: Buffer holds the prefix that fits and Last is the last written index.
--  Other failure: Last = 0.
```

## Threading and allocation

A successfully initialized runtime is intended to be shared for concurrent read-only rendering. Initialization is setup-time work and may allocate. The lower-level `I18N.Runtime.Compatibility.Render_Into` path uses caller-owned storage for fixed-buffer execution checks and lives behind Ada private-child visibility for in-tree regression tests; it is not part of the v1.1.0 application API. The public `Render` facade returns a structured result and materializes the final result string after execution. Do not describe public `Render` as a zero-allocation API.

## Build and tests

```sh
alr test
```

The manifest test action routes through `check_i18n`, the Ada release guard backed by the sibling `project_tools` crate. It builds the library, builds and runs the AUnit tests, builds public examples and checks their output against `examples/EXPECTED_OUTPUT.md`, runs Alire build/test checks, verifies the CLDR data boundary, builds render benchmarks, runs benchmark smoke checks for render hot paths and bounded `Render_Into`, generates GNATdoc, and runs GNATprove check mode. The test suite includes parser, validator, compiler/cache regression, IR equivalence, render, plural/select/selectordinal, number formatting, currency formatting, date/time formatting with quoted skeleton literals, deterministic domain formatting, locale fallback, diagnostics, fuzz smoke, corpus regression, concurrency, zero-allocation compatibility-path checks, and public API freeze checks. See `docs/TEST_MATRIX.md`, `docs/RELEASE_VERIFICATION.md`, and `docs/SPARK.md`.

## Ada-level API sealing

`I18N.Arguments` maps are mutable and noncopyable. Create them as local objects, update them with `Set`/`Clear`, pass them to `Render`, and use `I18N.Arguments.Copy` when an explicit duplicate is needed; do not depend on whole-object assignment.

The public surface is not just documented; it is enforced with Ada visibility. Implementation units such as `I18N.Parser`, `I18N.Compiler`, `I18N.Cache`, `I18N.Errors`, `I18N.AST`, `I18N.Number_Format`, `I18N.Currency`, `I18N.Date_Time_Format`, `I18N.Extra_Format`, `I18N.CLDR_Data`, and `I18N.Runtime.Compatibility` are declared as private child packages. Ordinary applications should import only the stable public package set: `I18N`, `I18N.Runtime`, `I18N.Result`, `I18N.Arguments`, `I18N.Locales`, `I18N.Plurals`, and optionally `I18N.Diagnostics`.

## Supported locales and deferred functionality

Locale identifiers are arbitrary BCP-47-style strings used as catalog keys; catalog ingest and lookup canonicalize locale casing and deterministic CLDR language aliases before fallback removes the rightmost subtag and finally falls back to the runtime default locale. Plural-category classification uses generated CLDR 46.1 rule-family mappings for all 219 cardinal locale IDs and all 104 ordinal locale IDs in the checked source, plus a root fallback that covers everything else.

The built-in formatting subset is deterministic and intentionally narrow:
grouped decimal numbers with locale-specific decimal/group separators and default numbering-system digits for all 725 imported CLDR 46.1 number locales with exact and parent-locale fallback, compatibility Arabic-Indic digits for `ar`, Persian digits and separators for `fa`, Thai digits, Bengali digits, Indian grouping for `hi`, `bn`, and `*-IN`, plus explicit `-u-nu-*` digits for all generated CLDR numeric numbering systems such as `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`,
percent, permille, compact/scientific/engineering notation, CJK compact
10,000 and 100,000,000 scaling for `ja`, `zh`, and `ko`, precision including
`::precision-unlimited`, fraction precision ranges such as
`::precision-fraction/0-2`, and significant precision ranges such as
`::precision-significant/1-3`, integer-width zero- and optional-`#`-pattern padding, expanded rounding and rounding-increment skeletons,
sign-display aliases including `::sign-negative`, `::sign-display-negative`, `::sign-display/negative`, `::sign-display-accounting`, and `::sign-accounting`, grouping-control aliases including `::group-min2`, `::grouping-off`, `::grouping-auto`, `::grouping-min2`, `::grouping-on-aligned`, `::grouping-thousands`, and `::grouping/min2`,
decimal-display including `::decimal-display/always`, `::decimal/always`, and `::decimal-display-always`, trailing-zero-display slash and hyphen aliases, slash-style rounding-mode aliases such as `::rounding-mode/half-even`, and positive integer/decimal scale skeletons,
compound number skeleton token lists such as
`::percent precision-integer`, deterministic English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Japanese, Chinese, Korean, Turkish, Swedish, Danish, Norwegian, Finnish, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Catalan, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, and Hebrew signed whole-number and strict-decimal `::spellout`/`::spellout-cardinal`/`::spellout-cardinal-verbose`/`::spellout-numbering`/`::spellout-year` and deterministic gendered cardinal aliases, including exact cardinal decimal RBNF rows and exact signed RBNF integer-part rows for negative decimal spellout, plus
whole-number `::ordinal-words`/`::spellout-ordinal`/`::spellout-ordinal-verbose` and deterministic gendered ordinal aliases with exact ordinal decimal RBNF rows, currency symbols, narrow symbols, and generated CLDR 46.1 currency display names with CLDR plural-category selection for all imported currency-name locales with exact, parent, and default fallback, plus English display names, standard symbols, narrow symbols, minor-unit metadata, and cash-rounding metadata for the 307-code generated CLDR 46.1 currency table including ADP, AFN, XCG, VED, ZWG, ZWL, JPY, KWD, and CLF,
ISO-code unit-width display, symbol-first currency placement for `en`/`ar`/`hi`/`bn`/`ja`/`zh`/`ko`, cash rounding, and 307-code generated CLDR 46.1 minor-unit metadata, the
`::currency/XXX` number skeleton with suffix or separate unit-width/cash/precision-currency/sign-accounting tokens, strict ISO dates with
`short`/`medium`/`long`/`full` styles and `::` skeletons including year-month-day style order for `ja`/`zh`/`ko`, localized
full and abbreviated month/weekday names plus wide and abbreviated quarter names for all 725 imported CLDR 46.1 date locales with exact and parent-locale fallback, and runtime/imported narrow month and weekday names with UTF-8-safe fallback, and runtime/imported narrow quarter names with numeric fallback, Gregorian era labels, Buddhist calendar year display, Japanese calendar era-year display with localized `ja` era names for Reiwa, Heisei, Showa, Taisho, Meiji, and Keio, ROC/Minguo year display with localized `zh` era names, plus Julian, Coptic, Ethiopic, Ethiopic Amete Alem, Islamic civil, tabular astronomical Islamic, Indian national, Persian, and Hebrew
calendar date conversion from locale extensions or supported runtime-data default-calendar preferences, including the `ethioaa` calendar alias for Ethiopic Amete Alem year display, the `islamicc` alias for deterministic Islamic civil conversion, the `islamic-tbla` calendar for the tabular astronomical epoch, and the `iso8601` calendar alias for Gregorian conversion with ISO week data, with deterministic related-Gregorian-year `r` skeleton output and deterministic rejection of unsupported calendar extensions, date/time/datetime numeric fields with the same locale digit selection as number formatting, strict time values with 24-hour styles plus localized Korean 12-hour time styles and skeleton-selected 12-hour
output with source-backed localized AM/PM names for all 725 imported CLDR 46.1 date locales plus localized midnight/noon and generated flexible morning/afternoon/evening/night labels where CLDR supplies them, source-backed GMT offset prefixes, offset separators, generic time-zone location patterns for imported CLDR date locales, generated CLDR exemplar-location data for VVV/VVVV time-zone location output, generated localized `Etc/UTC` long display rows where CLDR supplies them, generated source-backed fixed-zone display names for the selected built-in fixed-zone set checked by `cldr/raw/coverage.txt`, including `Asia/Tokyo`, `Europe/Moscow`, `America/Bogota`, `Africa/Nairobi`, `Asia/Manila`, `Asia/Yangon`, `Pacific/Honolulu`, and selected Asia/Africa/Americas fixed zones across imported CLDR date locales where CLDR supplies metazone names, generated source-backed generic-family display names for existing DST family keys plus Lord Howe and fixed Australian eastern, central, central-western, and western zones across imported CLDR date locales where CLDR supplies metazone names, source-backed short-family zone display names where present, and ISO instant/date-time formatting with checked IANA tzdb 2026a transition offsets generated into the library for primary zones and links over 1900 through 2050. Runtime formatting does not compile arbitrary external tzdb source files, but deterministic runtime data may supply bounded UTC transition-offset overrides and bounded numeric-year tzdb Rule rows with second-precision SAVE offsets and min/minimum and max/maximum bounded to 1900..2050 plus numeric, last-weekday, and weekday-on-or-before/after ON days for application fixed-offset zones; deterministic built-in zone display names and GMT-offset fallbacks are used where generated/source-backed zone-name data is absent. It also includes deterministic application-domain formatters for
durations, binary byte sizes, supported strict decimal units including metric length units decimeter, micrometer, nanometer, and picometer plus nautical mile, astronomical unit, light year, parsec, fathom, furlong, pixel, point, solar radius, Earth radius, dot, megapixel, pixels per centimeter, pixels per inch, dots per centimeter, and dots per inch, area including acres, hectares, square feet, square miles, square centimeters, square inches, and square yards, volume including cup, tablespoon, teaspoon, pint, quart, barrel, cubic meter, cubic centimeter, cubic inch, cubic foot, cubic yard, acre-foot, and fluid ounce, mass including milligram, tonne, ton, dalton, Earth mass, Solar mass, stone, and carat, duration nanoseconds, microseconds, milliseconds, fortnights, quarters, decades, and centuries, digital bit/byte units including kilobit, megabit, terabit, gigabit, petabyte, petabit, exabyte, and exabit, speed including knots and Beaufort, consumption units, temperature units including Kelvin, angle degrees, radians, revolutions, arc-minutes, and arc-seconds, acceleration g-force and meters per square second, force newtons and pound-force, torque newton-meters, energy including electronvolt, British thermal unit, and US therm, power including horsepower, electric including milliampere and millivolt, frequency, pressure including pascal, kilopascal, hectopascal, millibar, bar, atmosphere, inch-ofhg, millimeter-ofhg, and PSI, light including candela and solar luminosity, graphics units including dot, megapixel, pixels per centimeter, pixels per inch, dots per centimeter, and dots per inch, percent, permille, permillion, portion, and karat, and selected US customary measure units such as mile, yard, foot, inch, gallon, pound, and ounce
through direct `{value, unit, ...}` options plus `::measure-unit/...` and `per-measure-unit/...` number skeleton aliases,
source-backed short/narrow unit symbols and source-backed per-unit separators for the expanded list-locale set, source-backed English full names for all supported units, source-backed German full names for the generated German fallback-unit set, source-backed Italian, Portuguese, Dutch, Romanian, Lithuanian, Slovenian, Polish, Czech, Russian, Arabic, Japanese, Chinese, and Korean full names for their generated extended-unit sets, and localized full unit names for `de`/`fr`/`es`/`it`/`pt`/`nl`/`ro`/`lt`/`sl`/`pl`/`cs`/`ru`/`ar`/`ja`/`zh`/`ko`, relative time offsets with
localized digits, generated source-backed full/short/narrow current-period second/minute/hour/day/week/month/quarter/year names and complete nonzero full/short/narrow second/minute/hour/day/week/month/quarter/year future/past plural-category patterns for all imported CLDR 46.1 date locales where CLDR supplies them, source-backed offset affixes for `en`/`de`/`fr`/`es`/`it`/`pt`/`nl`/`ro`/`lt`/`sl`/`pl`/`cs`/`ru`/`ar`/`ja`/`zh`/`ko`/`tr`/`sv`/`da`/`fi`/`eo`/`vi`/`hu`/`sk`/`no`/`id`/`ms`/`af`/`sw`/`eu`, source-backed one/other relative unit display rows for `en`/`ro`/`lt`/`sl`/`cs`/`ar`/`tr`/`sv`/`da`/`eo`/`vi`/`hu`/`sk`/`fi`/`no`/`id`/`ms`/`af`/`sw`/`eu`/`ja`/`zh`/`ko` plus German plural day/month/year display overrides, and source-backed rows for built-in CLDR cardinal-category forms for Russian/Ukrainian and Polish,
numeric output honoring explicit `-u-nu-*` numbering-system extensions, and pipe-delimited standard/and, or/disjunction, and unit lists with generated localized CLDR-style two-item/start/middle/final separators plus runtime list-pattern overrides for
`en`/`de`/`fr`/`es`/`it`/`pt`/`nl`/`ro`/`lt`/`sl`/`pl`/`cs`/`ru`/`ar`/`ja`/`zh`/`ko` plus `tr`/`sv`/`da`/`no`/`fi`/`id`/`ms`/`eo`/`vi`/`sw`/`af`/`eu`/`hu`/`sk`/`bg`/`uk`/`fa`/`th`/`hi`/`el`/`he`.
Bounded tzdb `Rule` rows are accepted for application fixed-offset zones when `FROM`/`TO` are numeric years, `min`/`minimum`, `max`/`maximum`, or `only`, `IN` is a supported month, `ON` is a numeric day, `lastSun`-style last weekday, or `Sun>=N`/`Sun<=N`-style weekday constraint, `AT` is a time with `u`/`g`/`z` UTC, `s` standard-time, `w` wall-time, or no wall-time suffix, with `24:00` normalized to the next day, and `SAVE` is a supported offset with optional seconds; referenced rules, whether they appear before or after the matching Zone row, are applied in chronological transition order and carry prior SAVE values across years when materializing deterministic runtime transition offsets for matching `Zone` rows.
Process-wide runtime-data overrides can be loaded with `I18N.Runtime.Load_Data_Text` or `Load_Data_File` before rendering. The deterministic key/value override format supports locale separators, grouping, digits, generated numeric default numbering-system preferences, number signs/suffixes/exponent/accounting symbols, month/weekday/quarter/day-period/era names, exact and range flexible day-period rules such as `locale.zz.day_period_rule.morning1 = 04:00-10:00` and midnight-wrapping ranges such as `locale.zz.day_period_rule.night1 = 21:00-04:00`, time-zone display, exemplar-location, generic/standard/daylight location patterns, and short specific/generic names, default time-zone preferences, supported default hour-cycle preferences, first-day-of-week and first-week-minimum-day preferences, and offset components, unit and relative-time display text, list pattern fields including item, pair, start, middle, and final separators, date/time style skeletons, available-format skeleton patterns, and datetime style separators, supported default calendar preferences, currency placement/separators/accounting affixes, fixed time-zone base offsets in minutes or seconds, bounded UTC transition offsets such as `timezone.Example/Zone.transition.20260101000000 = 3600` or `timezone.Example/Zone.transition.2026-01-01T00:00:00Z = 3600`, currency symbols/display names/minor-unit/cash metadata, exact signed RBNF spellout rows such as `rbnf.zz.cardinal.2 = two`, `rbnf.zz.cardinal.-2 = minus two`, bounded composition rows such as `rbnf_rule.zz.cardinal.40 = forty[->>]` and `rbnf_rule.zz.cardinal.100 = << hundred[ >>>]`, exact cardinal or ordinal decimal rows such as `rbnf.zz.cardinal.-2.3 = minus two point three` and `rbnf.zz.ordinal.-2.3 = minus second point three`, `rbnf.zz.ordinal.2 = second`, and `rbnf.zz.decimal_separator = point`, and exact plural-category overrides such as `plural.cardinal.zz.7 = few` and `plural.ordinal.zz.9 = two`, and CLDR plural-rule family aliases such as `plural.rule_family.cardinal.zz = ar`. The same loader also accepts checked normalized CLDR import rows for locale symbols, digits, month/weekday/quarter names, LDML monthContext/dayContext/quarterContext stand-alone child-row context, monthWidth/dayWidth/quarterWidth child-row width context, and dayPeriodWidth abbreviated/wide/narrow child-row context, hex-byte `locale_text|locale|field|payload` display/style rows validated against the supported locale-field set including `default_numbering_system`, `default_hour_cycle`, `first_day_of_week`, and `first_week_min_days`, `rbnf_text|locale|kind|value|payload` and `rbnf_rule_text|locale|kind|base|payload` spellout rows, currency metadata, grouping/date-order/currency-placement booleans, plural rule-family mappings through `plural_rule|kind|locale|family`, deterministic LDML-style rows, with single-line XML declarations and comments ignored, attribute-only rows single-line and supported attributes accepting optional whitespace around = and single or double quotes and supported element-text rows accepted as bounded multi-line blocks, with standard XML entity references and numeric character references decoded in supported attributes and element text plus CDATA sections accepted in supported element text, and bounded <ldml locale=xx> or <locale id=xx> wrappers providing locale context for child rows that omit locale attributes, exact <ldml> roots deriving locale context from CLDR identity language/script/territory rows, plus known inert CLDR grouping containers around supported leaf rows, including `<symbols ...>` number-symbol attributes plus `<day ...>`, `<quarter ...>`, `<dayPeriod ...>`, `<dayPeriodRule locale="xx" type="morning1" from="05:00" before="11:00"/>`, `<dayPeriodRuleSet ...>` and `<dayPeriodRules ...>` containers, `<era ...>`, `<eraSeparator ...>`, `<zoneName ...>`, `<timeZoneName ...>`, `<zoneExemplar ...>`, `<exemplarCity ...>`, `<zoneLocationPattern ...>`, `<regionFormat ...>`, `<gmtFormat ...>`, `<gmtZeroFormat ...>`, `<hourFormat ...>`, `<zoneShort ...>`, `<zoneShortStandard ...>`, `<zoneStandardShort ...>`, `<zoneShortDaylight ...>`, `<zoneDaylightShort ...>`, `<zoneGenericShort ...>`, `<zoneShortGeneric ...>`, `<calendarPreference ...>`, `<timeZonePreference ...>`, `<numberingSystemPreference ...>`, `<hourCyclePreference ...>`, `<weekData ...>`, `<currencyFormat ...>`, `<currencySpacing ...>`, `<currency ...>`, `<currencySymbol ...>`, `<currencyName ...>`, `<unitName ...>`, `<unitPattern ...>`, `<relativeName ...>`, `<relativePeriod ...>`, `<relativeUnit ...>`, `<relativePattern ...>`, `<relativeTime ...>`, `<relativeTimePattern ...>`, `<listPattern ...>`, `<listPatternPart ...>`, `<dateFormat ...>`, `<dateFormatLength ...>`, `<timeFormat ...>`, `<timeFormatLength ...>`, `<dateStyle ...>`, `<timeStyle ...>`, `<availableFormat ...>`, `<dateFormatItem ...>`, `<dateTimeFormat ...>`, `<dateTimeFormatLength ...>`, `<dateTimeStyle ...>`, `<rbnf ...>`, `<rbnfRule ...>`, and lowercase `<rbnfrule ...>` localized display data for `2`/start/middle/end/final/item parts and exact spellout rows, with bounded RBNF rule text accepting `<<`, `>>`, `>>>`, and CLDR arrow-glyph equivalents `←←`, `→→`, and `→→→`, named `%...` arrow substitutions, including ASCII `<%...<` and `>%...>` forms, recognized cardinal/ordinal target rule-set names for named quotient, remainder, and equality substitutions such as `=%spellout-ordinal=`, a single trailing CLDR rule semicolon, fixed-offset tzdb Zone/Link rows accepting direct SAVE offsets with optional second precision in the RULES column plus case-insensitive Z/UTC/GMT zero offsets plus +H, +HH, +HMM, +HHMM, +H:MM, +HH:MM, and colon-separated second offsets such as +HH:MM:SS offsets, with matching negative numeric forms, and bounded fixed-offset Zone continuation rows whose direct SAVE offsets with optional second precision and numeric, last-weekday, and weekday-on-or-before/after Jan-Dec until fields plus wall/standard/UTC until time bases, including normalized `24:00` end-of-day times, feed runtime transition offsets, and localized currency-name payloads; `availableFormat` and `dateFormatItem` rows feed date/time/datetime skeleton resolution from `id` or `skeleton` attributes, `dayPeriodRule` rows and CLDR-shaped `dayPeriodRuleSet`/`dayPeriodRules` containers feed flexible `b`/`B` skeleton range selection from direct or inherited `locale`/`locales` attributes, `zoneExemplar` and `exemplarCity` rows provide VVV/VVVV exemplar-location text for the zone id, `zoneLocationPattern` and generic `regionFormat` rows provide non-UTC VVVV generic-location output through `{0}` substitution while standard/daylight `regionFormat` rows feed long `zzzz` fallbacks, typed `zoneName` and `timeZoneName` rows provide long generic, long standard/daylight, and short `z`/`v` labels, `zoneShort`/`zoneShortStandard`/`zoneStandardShort`, `zoneShortDaylight`/`zoneDaylightShort`, and `zoneGenericShort`/`zoneShortGeneric` rows provide short `z`/`v` labels, `dateTimeFormat`, `dateTimeFormatLength`, and `dateTimeStyle` rows feed the datetime style separator from strict `{1}<separator>{0}` patterns, `unitPattern` rows accept exactly one `{0}` placeholder, including reordered patterns, `relativePattern`, `relativeTime`, and `relativeTimePattern` rows without `unit`/`count` split one `{0}` placeholder into deterministic prefix/suffix affixes; rows with `unit` and `count` or `relativeUnit` and `count` feed direct unit/count relative-time patterns with zero or one `{0}` placeholder, `listPattern`/`listPatternPart` element text may be a compatibility raw separator or a strict `{0}<separator>{1}` CLDR pattern, `unitName`, `unitPattern`, and `relativeUnit` count attributes accept `zero`, `one`, `two`, `few`, `many`, and `other`, and unit quantities select the resolved CLDR cardinal category, including visible fractional operands for strict decimals. Malformed runtime data is rejected transactionally and leaves the previous override set intact.

CLDR-shaped `dayPeriodRule` rows also accept exact `at="HH:MM"` rows for supported day-period types inside direct or inherited `locale`/`locales` contexts; malformed exact `at` rows are rejected transactionally.

Bounded runtime plural-rule expressions can be loaded as `plural.rule.<kind>.<locale>.<category> = <rule>`, normalized `plural_rule_text|kind|locale|category|rule` rows, or LDML-style `<pluralRule ... count="one">n is 1</pluralRule>` rows. CLDR-shaped `plurals` and `pluralRules locales="...">` containers provide inherited cardinal/ordinal kind and space-separated locale lists for child `<pluralRule>` rows. They support operands `n`, `i`, `v`, `w`, `f`, `t`, `c`, and `e`, optional `mod`/`%`, relation operators, comma-separated values, ranges, and `and`/`or` clauses. The `c` and `e` compact-exponent operands are accepted with deterministic value zero on this runtime path. CLDR sample annotations beginning with `@integer` or `@decimal` are ignored for evaluation. Exact plural-category overrides still take precedence, and generated CLDR families remain the fallback.

LDML-style `symbols` rows accept CLDR-shaped aliases for number-symbol attributes: `percentSign`, `perMille`, `plusSign`, `minusSign`, and `exponential` feed the same formatter fields as `percent`, `permille`, `plus`, `minus`, and `exponent`. CLDR-shaped `<defaultNumberingSystem>` element text feeds `locale.xx.default_numbering_system`, and `<symbols numberSystem="...">` containers provide context for child `<decimal>`, `<group>`, `<percentSign>`, `<perMille>`, `<plusSign>`, `<minusSign>`, and `<exponential>` rows; only the selected default numbering system, or `latn` when no default is set, updates formatter symbols. CLDR-shaped `<weekData>` containers may wrap `<firstDay>` and `<minDays>` child rows that feed locale week-data preferences.

LDML-style `unitName`, `unitDisplayName`, `displayName`, and `unitPattern` rows normalize supported ICU unit identifiers such as `length-meter`, `volume-liter`, and `mass-gram`, plus `long`, `short`, and `narrow` width aliases, to the formatter's canonical unit keys; when `unit` is omitted, `type` is treated as the unit identifier. CLDR `<unitLength type="long|short|narrow">` and `<unit type="...">` containers provide inherited width and unit identifiers for child `displayName` and `unitPattern` rows. `unitDisplayName`, `displayName`, and `unitName` rows without `count` feed the `other` unit display slot. `compoundUnitPattern` rows with `type="per"` accept strict `{0}<separator>{1}` text and feed long or short per-unit separators; CLDR `<compoundUnit type="per">` containers and surrounding `unitLength` containers provide inherited type and width for child `compoundUnitPattern` rows.

LDML-style `listPattern` and `listPatternPart` rows accept raw separators or strict `{0}<separator>{1}` CLDR pattern text for list `2`, `start`, `middle`, `end`/`final`, and compatibility `item` parts. CLDR `<listPattern type="standard">`, `<listPattern type="or">`/`<listPattern type="disjunction">`, and `<listPattern type="unit">` containers provide context for child `listPatternPart` rows; unknown parent list-pattern types are rejected transactionally.

LDML-style `month`, `quarter`, `weekday`, and CLDR `day` rows accept CLDR-shaped `type`/`width` aliases such as `type="1" width="abbreviated"` for month/quarter indexes and weekday or `day` type names such as `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, and `sat`. CLDR era-width containers such as `eraAbbr`, `eraNames`, and `eraNarrow` are accepted as inert wrappers around supported `era` leaf rows, and a surrounding `calendar type="..."` container provides the calendar for child era rows that omit `calendar`.

LDML-style `calendar type="..."` containers provide the calendar for child `era` rows that omit `calendar`; `era` and `eraSeparator` rows normalize CLDR-shaped calendar aliases such as `gregory` to `gregorian`, and Gregorian numeric era types `0`/`1` to `bc`/`ad`.

LDML-style locale-preference rows accept CLDR-shaped aliases: `calendarPreference`, `numberingSystemPreference`, and `hourCyclePreference` may use `type` for their value, `calendarPreference` accepts aliases such as `ethioaa`, `islamicc`, `islamic-tbla`, and `iso8601`, and `timeZonePreference` may use `zone`.

LDML-style `<weekData ...>` rows accept `day` as an alias for `firstDay` and `count` as an alias for `minDays`.

LDML-style time-zone display and fixed-offset rows accept CLDR-shaped zone aliases: `zoneName`, `timeZoneName`, `zoneExemplar`, `exemplarCity`, `zoneShort`, `zoneShortStandard`, `zoneStandardShort`, `zoneShortDaylight`, `zoneDaylightShort`, `zoneGenericShort`, `zoneShortGeneric`, and `timeZone` may use `zone` in addition to `id`; CLDR `<zone type="Area/Name">` containers inside `timeZoneNames` provide the zone identifier for child `exemplarCity`, `generic`, `standard`, and `daylight` rows, and surrounding `long`/`short` containers select long display fields or short `z`/`v` fields; `gmtFormat` rows with prefix-`{0}` patterns, `gmtZeroFormat` rows, and standard `hourFormat` rows feed localized GMT offset prefixes, UTC designators, and hour/minute separators; fixed-offset `timeZone` rows may use `gmtOffset` or `utcOffset` in addition to `offset`, and fixed-offset LDML and tzdb rows accept case-insensitive `Z`, `UTC`, `GMT`, `+H`, `+HH`, `+HMM`, `+HHMM`, `+H:MM`, and `+HH:MM` offsets with matching negative numeric forms; bounded fixed-offset tzdb `Zone` rows apply direct SAVE offsets from the RULES column, and continuation rows use direct SAVE offsets plus numeric, last-weekday, and weekday-on-or-before/after Jan-Dec until fields with optional `HH[:MM[:SS]][u|g|z|s|w]` times where suffixless and `w` use wall time, `s` uses standard time, and `u`/`g`/`z` use UTC to feed runtime transition offsets.

LDML-style `availableFormat` and `dateFormatItem` rows feed date/time/datetime skeleton resolution from `id` or `skeleton` attributes. `appendItem` rows with `request="Time"` or `request="Timezone"` feed the date-to-time skeleton field separator from strict `{0}<separator>{1}` patterns. Date/time style rows accept `dateStyle` and `timeStyle` aliases in addition to `dateFormat` and `timeFormat`, plus `dateFormatLength` and `timeFormatLength` aliases, and may use `style` or `length` in addition to `type` for the style name. `dateTimeFormat`, `dateTimeFormatLength`, and `dateTimeStyle` rows accept the same style aliases and feed the datetime style separator from strict `{1}<separator>{0}` patterns. CLDR-shaped date/time/dateTime format length containers provide style context for child `<pattern>` rows.

LDML-style `<currencyFormat ...>` rows may also set locale currency `symbolFirst`, `separator`, `accountingPrefix`, and `accountingSuffix` attributes; CLDR-shaped `currencyFormats`/`currencyFormatLength` wrappers with child `<pattern>` rows are accepted for bounded standard/accounting currency placement and affix extraction; `<currencySpacing ...>` accepts `beforeCurrency` and `insertBetween` aliases for the same placement and separator data, and CLDR-shaped `beforeCurrency`/`afterCurrency` containers provide placement context for child `<insertBetween>` rows plus bounded `currencyMatch`/`surroundingMatch` metadata rows.

LDML-style `<currency ...>` rows accept CLDR-shaped `type`/`iso4217`, `digits`, `cashRounding`/`rounding`, `narrowSymbol`, and `displayName` aliases for currency code, minor-unit, cash-increment, narrow-symbol, and display-name metadata, CLDR `<currency type="...">` containers provide inherited ISO codes for child `<symbol>` and `<displayName>` rows, child `<displayName>` rows use `count` for plural-category display names with `other` as the default, `<currencySymbol ...>` accepts `code`/`type`/`iso4217` aliases and `alt="narrow"` for narrow-symbol metadata, `<currencyName ...>` accepts `type`/`iso4217` and `count` aliases for code and plural category, and `<pluralRule ...>` accepts `kind` as an alias for `type`, `family` for rule-family mappings, `locales` for space-separated locale lists, and `count`/`category` plus element text for bounded plural-rule expressions, including inherited kind/locales from surrounding `plurals` and `pluralRules` containers.

LDML-style relative-time rows accept CLDR `duration-*` unit aliases such as `duration-day`, `duration-week`, `duration-month`, `duration-quarter`, and `duration-year`, mapping them to the existing relative formatter unit names. `relativeName`, `relativePeriod`, and `relativeUnit` rows treat `type` as the unit identifier when `unit` is omitted; direct `relativeTime` and `relativeTimePattern` rows may use `relativeUnit` as a unit alias while `type` remains the `future`/`past` direction, and may use `unitWidth` as an alias for `width`. CLDR-shaped `fields` containers may wrap `field` containers that provide inherited relative unit and width for child rows, `relative type="N"` rows feed exact relative-offset text, and non-self-closing `relativeTime type="future|past"` containers provide direction context for child `relativeTimePattern` rows.

LDML-style RBNF imports may wrap supported `<rbnfrule>` rows in CLDR-shaped `rulesetGrouping`, `ruleSetGrouping`, `ruleset`, `ruleSet`, and `rules` containers. `ruleset` and `ruleSet` containers provide inherited rule-set names for child rows that omit `type`, `ruleSet`, or `ruleset`. Child rows may use `value` attributes or CLDR `descriptor: rule` element text, including bounded multi-line element text and `radix` attributes for explicit divisors.

Current v1.1.0 catalog/runtime-data boundaries: unsupported format skeletons
still fail deterministically. Full CLDR RBNF rule sets and arbitrary LDML/tzdb
source parsing beyond the deterministic runtime-data override and normalized
CLDR import formats are part of the completion scope.
Additional locale rules can
be added behind the existing `I18N.Plurals` API without breaking it. Locale
canonicalization, bounded likely-subtag maximization, and likely-subtag
minimization are exposed through `I18N.Locales` so callers can apply the same
deterministic language/script/region normalization that runtime lookup uses.
`I18N.Locales.Base_Name` and `I18N.Locales.Unicode_Extension` expose
deterministic BCP-47 extension inspection for locale tags such as
`en-US-u-ca-gregory-nu-thai`.
`I18N.Locales.Language`, `Script`, and `Region` expose canonical locale
components without making callers parse tags by hand.
`I18N.Locales.Language_Display_Name`, `Script_Display_Name`,
`Region_Display_Name`, and `Display_Name` expose deterministic English display
names plus display-locale overloads with built-in German, French, Spanish,
Italian, Portuguese, Dutch, Polish, Czech, Russian, Turkish, Swedish, Danish,
Finnish, Norwegian, Indonesian, Malay, Esperanto, Vietnamese, Swahili,
Afrikaans, Basque, Romanian, Lithuanian, Slovenian, Hungarian, Slovak,
Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, Hebrew, Catalan,
Japanese, Chinese, Korean, Bengali, Azerbaijani, Urdu, Yiddish, Serbian,
Pashto, Sindhi, and Uyghur names and English/canonical-code fallback.
`I18N.Locales.Direction` and `Is_Right_To_Left` expose deterministic
locale text direction for explicit RTL scripts and built-in RTL language
families.
`I18N.Locales.To_Lower` and `To_Upper` expose bounded locale-sensitive case
transforms for ASCII, Turkish/Azeri dotted-I tailoring, German sharp-s
uppercase expansion, common Latin, Greek including common tonos/dialytika
vowels, bounded dialytika-tonos uppercase expansion, and bounded final-sigma
lowercase context, Cyrillic, Armenian, and
Georgian Mtavruli/Mkhedruli plus Asomtavruli/Nuskhuri UTF-8 case pairs,
preserving unsupported bytes unchanged. Full Unicode case mapping and normalization are part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Normalize_NFC` and `Normalize_NFD` expose bounded canonical
composition/decomposition for common Latin letters with grave, acute,
circumflex, tilde, macron, breve, dot-above, diaeresis, ring, caron, cedilla,
ogonek, and horn marks, including additional Latin Extended acute and cedilla
pairs plus dot-below, base/tone-marked horn, circumflex/breve tone vowel pairs,
and bounded Greek tonos/dialytika vowels, preserving unsupported sequences
unchanged. Full Unicode normalization is part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Transliterate_ASCII` exposes bounded deterministic ASCII
transliteration for common Latin and Latin Extended letters plus Latin alphabetic presentation ligatures and fullwidth Latin letters/digits including
dot-below, base/tone-marked horn, and circumflex/breve tone vowels, German sharp-s,
bounded Greek letters including common tonos/dialytika and dialytika-tonos vowels, and bounded Cyrillic, Arabic, Persian Arabic-script letters, Arabic presentation forms-B plus selected single-letter and U+FBEA..U+FDF9 multi-letter ligature presentation forms-A, Armenian, Hebrew letters and alphabetic presentation forms, and Georgian Mkhedruli/Mtavruli plus Asomtavruli/Nuskhuri letters, preserving unsupported
bytes unchanged. Full transliteration is part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Match` adds deterministic matching from a comma-separated
available-locale list and an Accept-Language-style requested range list with
optional `q` weights.
`I18N.Locales.Sort_Key`, `Compare`, `Equivalent`, and `Contains` expose bounded
deterministic public collation/search for common multilingual text, including accent
folding for common Latin and Latin Extended letters plus Latin alphabetic
presentation ligatures, German ae/oe/ue/ss
tailoring, Nordic after-z ordering for `å`/`ä`/`æ`/`ö`/`ø`, bounded
Czech/Slovak `ch` and South Slavic Latin `dž`/`lj`/`nj` contractions,
bounded Latin, Arabic, NKo, U+1AB0..U+1AFF, U+1DC0..U+1DFF,
U+20D0..U+20FF, U+FE20..U+FE2F, and bounded Hebrew, Syriac, Thaana, NKo, Samaritan, and Mandaic
combining-mark elision, assigned Hebrew alphabetic presentation-form folding, Arabic presentation forms-B and selected single-letter plus U+FBEA..U+FDF9 multi-letter ligature forms-A folding,
bounded
Greek, Cyrillic, Armenian, and Georgian case folding, stable byte-key units for unhandled two-byte UTF-8 elements and
bounded three-byte Samaritan, Mandaic, Ogham, Runic, Cherokee, Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le, New Tai Lue, Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari, Bengali, Thai, Ethiopic, Hiragana, Katakana, halfwidth Katakana compatibility forms,
Han, and Hangul syllable elements, plus bounded four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Linear B, Aegean Numbers, Lycian, Carian, Old Italic, Gothic, Old Permic, Ugaritic, Old Persian, Deseret, Shavian, Osmanya, Osage, Elbasan, Caucasian Albanian, Cypriot, Imperial Aramaic, Palmyrene, Phoenician, Lydian, Sidetic, Meroitic Hieroglyphs, Meroitic Cursive, Nabataean, Hatran, Kharoshthi, Old South Arabian, Old North Arabian, Manichaean, Avestan, Inscriptional Parthian, Inscriptional Pahlavi, Psalter Pahlavi, Old Turkic, Old Hungarian, Garay, Rumi Numeral Symbols, Vithkuqi, Todhri, Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur, Chorasmian, Elymaic, Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra, Dives Akuru, Nandinagari, Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen, Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema, Tangsa, Kirat Rai, Tangut, Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto, Ol Onal, Tai Yo, Nag Mundari, and Adlam elements, bounded ASCII, Arabic-Indic, extended
Arabic-Indic, Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu,
Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer, NKo, fullwidth,
Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai, Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digit-run numeric ordering through
`-u-kn-true`, primary-strength equivalence, and raw byte tie-breaking for total
ordering. Full Unicode Collation Algorithm behavior is part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Grapheme_Count` and `Grapheme_At` expose bounded deterministic
grapheme-like segmentation for UTF-8 code points with bounded combining marks
including U+1AB0..U+1AFF, U+1DC0..U+1DFF, U+20D0..U+20FF,
U+FE20..U+FE2F, and bounded Hebrew, Syriac, Thaana, NKo, Samaritan, and Mandaic marks,
bounded South/Southeast Asian dependent vowel, virama, and tone marks,
variation selectors including U+FE00..U+FE0F and U+E0100..U+E01EF,
emoji keycap marks, emoji skin-tone modifiers,
emoji tag sequences, regional indicator flag pairs, simple zero-width-joiner sequences,
bounded Hangul Jamo L/V/T sequences, and CRLF pairs,
preserving original bytes when returning a cluster.
Bounded Unicode Prepend characters and Myanmar spacing vowel marks are kept
with their neighboring grapheme clusters. ASCII control characters and bounded
Unicode C1 controls remain standalone clusters. Full UAX #29 grapheme segmentation is
part of the completion scope; the current v1.1.0 implementation is the
deterministic bounded behavior described here.
`I18N.Locales.Line_Count` and `Line_At` expose bounded deterministic hard-line
segmentation for LF, CR, CRLF, vertical tab, form feed, Unicode next-line (NEL), Unicode line
separator, and Unicode paragraph separator breaks, preserving terminating break bytes.
Full UAX #14 line breaking and line wrapping are part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Sentence_Count` and `Sentence_At` expose bounded deterministic
sentence segmentation after ASCII `.`, `!`, and `?`, Unicode ellipsis, plus
Arabic, Greek, and Ethiopic question marks, Armenian full stop, Hebrew sof
pasuq, Georgian paragraph separator, Devanagari danda, Ethiopic full stop, Myanmar section signs, CJK
ideographic full stop, and fullwidth exclamation/question terminators, keeping immediate closing quotes/brackets,
including bounded CJK and fullwidth closing punctuation, with the returned
sentence, and excluding bounded ASCII/Unicode separator whitespace before the
next sentence. ASCII periods between bounded ASCII, Arabic-Indic, extended
Arabic-Indic, Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu,
Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer, NKo, fullwidth,
Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai, Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digits stay inside numeric text.
Full UAX #29 sentence segmentation is part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.
`I18N.Locales.Word_Count` and `Word_At` expose bounded deterministic word
segmentation for ASCII letters/digits; bounded Arabic-Indic, extended
Arabic-Indic, Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu,
Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer, NKo, fullwidth,
Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai, Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digits; bounded two-byte Latin, Greek, Cyrillic, Armenian, Hebrew, Arabic-range, Syriac, Thaana, and NKo UTF-8 elements plus bounded
combining marks, bounded three-byte Samaritan, Mandaic, Ogham, Runic, Cherokee, Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le, New Tai Lue, Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari, Bengali, Gurmukhi, Gujarati,
Odia, Tamil, Telugu, Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer,
Georgian, Ethiopic, Hiragana, Katakana, halfwidth Katakana compatibility forms, Hangul compatibility Jamo, Han, and Hangul syllable elements, plus bounded four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Linear B, Aegean Numbers, Lycian, Carian, Old Italic, Gothic, Old Permic, Ugaritic, Old Persian, Deseret, Shavian, Osmanya, Osage, Elbasan, Caucasian Albanian, Cypriot, Imperial Aramaic, Palmyrene, Phoenician, Lydian, Sidetic, Meroitic Hieroglyphs, Meroitic Cursive, Nabataean, Hatran, Kharoshthi, Old South Arabian, Old North Arabian, Manichaean, Avestan, Inscriptional Parthian, Inscriptional Pahlavi, Psalter Pahlavi, Old Turkic, Old Hungarian, Garay, Rumi Numeral Symbols, Vithkuqi, Todhri, Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur, Chorasmian, Elymaic, Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra, Dives Akuru, Nandinagari, Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen, Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema, Tangsa, Kirat Rai, Tangut, Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto, Ol Onal, Tai Yo, Nag Mundari, and Adlam elements, and bounded
Latin/Hebrew/Arabic presentation forms, preserving original UTF-8 bytes when
returning a word. Apostrophes,
right apostrophes, hyphens, and underscores connect internal word parts;
ASCII `.`, `,`, and `:`, plus Arabic decimal/thousands separators U+066B and
U+066C, connect numeric word parts only when bounded decimal digits
appear on both sides;
punctuation, spacing, symbols, and unsupported bytes otherwise separate words.
Full UAX #29 word-boundary behavior is part of the completion scope; the current v1.1.0 implementation is the deterministic bounded behavior described here.

The current CLDR-derived tables are centralized behind the internal
`I18N.CLDR_Data` generated-data boundary. Formatters consume that package for
locale symbols, numbering-system digits, grouping policy, day-month-year style
selection, style patterns and separators, localized date/time names, zone
display data, generated tzdb alias canonicalization and transition offsets,
number/currency affixes, unit/list separators, unit labels, currency metadata,
and plural rule-family mappings instead of embedding independent copies.
The staged upstream fixture is `cldr/upstream/cldr_export.jsonl`, with release
provenance in `cldr/upstream/source_manifest.txt` and CLDR source inventory in
`cldr/upstream/source_files.txt`. Checked IANA tzdb 2026a fixtures live under
`cldr/upstream/tzdb/` and feed generated time-zone alias canonicalization plus
seconds-based transition-offset tables for instant conversion.
`cldr/cldr_tools.gpr` builds `check_cldr_sources`, `check_tzdb_sources`,
`generate_cldr_export`, `import_cldr_raw`, `extract_cldr_normalized`,
`import_cldr_subset`, and `generate_cldr_data`, whose `--check` modes are part
of the release guard. The source checker validates the declared CLDR JSON
package paths, the tzdb checker validates source provenance and zone/link/table
coverage, the export generator derives staged rows from CLDR-shaped source
fragments, the raw importer validates the JSONL stage and emits
`cldr/raw/cldr_records.txt`; the
extractor validates `cldr/raw/coverage.txt`, emits normalized UTF-8/code-point
rows, and the importer emits the Ada-safe pinned subset. The staged CLDR import
tooling can broaden that upstream source while preserving the stable public
facade.


## Alire package metadata

The release tree includes `alire.toml` for source-crate consumption. The crate name is `i18n`, the primary project file is `i18n.gpr`, and the package declares an Ada 2022/GNAT dependency. See `docs/PACKAGING.md` before publishing or consuming the crate through Alire.

## Documentation map

* `docs/QUICKSTART.md` — smallest complete catalog/render workflow
* `docs/EXAMPLES.md` — comprehensive v1.1.0 example program series
* `examples/README.md` — example directory orientation
* `examples/EXPECTED_OUTPUT.md` — command-by-command expected output
* `docs/ARCHITECTURE.md` — runtime structure and public/internal boundary
* `docs/API.md` — stable public API and internal compatibility notes
* `docs/ICU_SUBSET.md` — supported and unsupported message syntax
* `docs/CATALOG_FORMAT.md` — canonical authoring format
* `docs/ERROR_MODEL.md` — public status semantics and deterministic failures
* `docs/THREADING.md` — concurrency and allocation guarantees
* `docs/VALIDATION.md` — release-gate rules
* `docs/TEST_MATRIX.md` — release-gate coverage map
* `docs/COMPATIBILITY.md` — v1.1.0 source/runtime compatibility policy
* `docs/PUBLIC_API_BOUNDARY.md` — sealed public API surface and compatibility-only packages
* `docs/RELEASE_CHECKLIST.md` — final release audit checklist
* `docs/RELEASE_VERIFICATION.md` — GNAT/GPRbuild verification required before tagging v1.1.0
* `docs/SPARK.md` — SPARK-enabled units and GNATprove release command
* `docs/AI_CONSUMPTION_GUIDE.md` — project guide for AI tools and maintainers

## AI and tool discoverability

The release includes explicit orientation files for code assistants and automated tooling:

* `AGENTS.md` — contributor instructions and maintenance guardrails.
* `PROJECT_INDEX.md` — repository map by task, package, and file role.
* `docs/AI_CONSUMPTION_GUIDE.md` — guidance for interpreting the public contract.
* `ai/API_MANIFEST.json` — machine-readable public API summary.
* `ai/CONTRACT_SUMMARY.yaml` — compact behavior contract.
* `ai/EXAMPLE_CATALOG.json` — example and catalog inventory.
* `ai/FILE_ROLE_MAP.json` — machine-readable file role classification.

These files are non-runtime metadata. They do not define behavior independently of the Ada specs, docs, and tests, but they make the project easier to inspect and consume correctly.


## Verification status

Before publishing or tagging v1.1.0, run `alr test`. The manifest test action invokes the project-tools-based `check_i18n` guard, which covers the library build, test project build, AUnit runner, example project build and output checks, CLDR data-boundary checks, Alire build/test checks, render benchmark smoke checks, GNATdoc, and GNATprove. Treat any recurrence of the `I18N.Errors.Result` `Storage_Error` warning as a release blocker.

## v1.1.0 compatibility boundary

Stable after v1.1.0:

* public package names listed above
* catalog-oriented `I18N.Runtime.Initialize`
* catalog-oriented `I18N.Runtime.Render`
* `I18N.Result.Render_Status` meanings
* locale fallback semantics
* missing-key and missing-argument behavior
* diagnostics non-interference
* catalog authoring format

Allowed after v1.1.0: adding overloads, adding diagnostics, adding ICU features that do not change existing behavior, and improving performance.

Forbidden after v1.1.0: renaming public packages, changing public status meanings, removing public functions, changing fallback semantics, or silently changing missing-argument behavior.
