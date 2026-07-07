# ICU Subset

ICU Messages Ada v1.1.0 implements a deliberately small, deterministic ICU-style subset.

## Supported constructs

### Literal text

```text
Hello world
```

### Variables

```text
Hello, {name}!
```

A missing variable returns `Missing_Argument`.

### Plural

```text
{count, plural, one {One item} other {# items}}
{count, plural, zero {No items} one {One item} two {Two items} few {A few items} many {Many items} other {# items}}
{count, plural, =0 {No items} =1 {One exact item} other {# items}}
{count, plural, offset:1 one {# item} other {# items}}
```

Rules:

* `other` is required; `zero`, `one`, `two`, `few`, and `many` are optional and fall back to `other` when absent;
* the parser accepts the `zero`, `one`, `two`, `few`, `many`, and `other` branch names; other category names are rejected;
* exact integer branches such as `=0` and `=1` are accepted, normalized for duplicate detection, and take precedence over plural-category branches;
* selector argument must be strict decimal text: a strict integer, or for non-offset plurals a strict decimal with digits on both sides of `.` such as `1.5`;
* `#` is replaced with the normalized integer selector text for integers and with the original decimal selector text for non-offset decimals;
* an optional non-negative integer `offset:N` may appear before branches; with an offset present, category selection and `#` use `selector - N`;
* offset plurals require an integer selector; decimal selectors with offsets return `Invalid_Argument`;
* the branch is chosen by the resolved locale's CLDR cardinal category via `I18N.Plurals`, using CLDR fractional operands `i`, `v`, and `f` for non-offset decimals, and falling back to `other` when the category's branch is absent.

### Select

```text
{gender, select, male {He} female {She} other {They}}
{width,  select, full {hour} short {hr} narrow {h} other {hour}}
```

Rules:

* `other` is required;
* branch names are arbitrary validated identifiers (the legacy `male`/`female`/`other` branches keep working unchanged);
* duplicate branch names are rejected;
* selector argument is string-valued;
* unmatched values use `other`.

Boolean-style selects pair naturally with `I18N.Arguments.Set_Boolean`, which serializes `true`/`false`:

```text
{active, select, true {on} false {off} other {?}}
```

### Selectordinal

```text
{rank, selectordinal, one {1st} two {2nd} few {3rd} many {#th-many} other {#th}}
{rank, selectordinal, =11 {11th} one {#st} two {#nd} few {#rd} other {#th}}
```

Rules:

* `other` is required; `zero`, `one`, `two`, `few`, and `many` are optional and fall back to `other` when absent;
* the parser accepts the `zero`, `one`, `two`, `few`, `many`, and `other` branch names; other category names are rejected;
* exact integer branches such as `=11` are accepted, normalized for duplicate detection, and take precedence over ordinal-category branches;
* selector argument must be a strict decimal integer;
* `#` is replaced with the numeric selector text;
* the branch is chosen by the resolved locale's CLDR ordinal category via `I18N.Plurals` (for English `21 -> 21st`, `11 -> 11th`), falling back to `other` when the category's branch is absent.

### Currency

```text
{amount, currency, USD}
{amount, currency, USD/name}
{amount, currency, CAD/narrow}
{amount, currency, USD/accounting}
{amount, currency, CHF/cash}
{amount, number, ::currency/USD}
{amount, number, ::currency/USD/accounting}
```

Rules:

* the third field is a three-letter uppercase ASCII currency code with optional `/symbol`, `/standard`, `/narrow`, `/name`, `/full-name`, `/unit-width-short`, `/unit-width/short`, `/unit-width-narrow`, `/unit-width/narrow`, `/unit-width-long`, `/unit-width/long`, `/unit-width-full-name`, `/unit-width/full-name`, `/unit-width-iso-code`, `/unit-width/iso-code`, `/iso-code`, `/accounting`, `/cash`, `/precision-currency-standard`, `/precision-currency/standard`, `/precision/currency-standard`, `/precision-currency-cash`, `/precision-currency/cash`, `/precision/currency-cash`, `/cash-accounting`, `/narrow-accounting`, `/accounting-narrow`, `/unit-width-narrow-accounting`, `/accounting-unit-width-narrow`, `/name-accounting`, `/accounting-name`, `/unit-width-full-name-accounting`, `/accounting-unit-width-full-name`, `/unit-width-iso-code-accounting`, `/accounting-unit-width-iso-code`, `/cash-narrow`, `/cash-name`, `/cash-unit-width-narrow`, `/cash-unit-width-full-name`, `/cash-unit-width-iso-code`, `/cash-narrow-accounting`, `/cash-unit-width-narrow-accounting`, `/cash-name-accounting`, `/cash-unit-width-full-name-accounting`, or `/cash-unit-width-iso-code-accounting`;
* slash-composed direct currency aliases such as `/unit-width/full-name/accounting`, `/cash/unit-width/iso-code`, and `/cash/unit-width/full-name/accounting` map to the same deterministic display, cash-rounding, and accounting behavior as their hyphenated counterparts;
* `{amount, number, ::currency/USD}` is accepted as the ICU number-skeleton spelling for currency formatting, and the same currency option suffixes are accepted after the currency code;
* currency number skeletons may also use separate compound tokens after the currency code: `symbol`, `standard`, `unit-width-short`, `unit-width/short`, `narrow`, `unit-width-narrow`, `unit-width/narrow`, `name`, `full-name`, `unit-width-long`, `unit-width/long`, `unit-width-full-name`, `unit-width/full-name`, `unit-width-iso-code`, `unit-width/iso-code`, `iso-code`, `cash`, `precision-currency-cash`, `precision-currency/cash`, `precision/currency-cash`, `precision-currency-standard`, `precision-currency/standard`, `precision/currency-standard`, `accounting`, `sign-accounting`, and `sign/accounting`, for example `{amount, number, ::currency/CHF precision-currency/cash sign/accounting unit-width/full-name}`;
* the amount argument is strict decimal text with an optional leading sign and `.` fraction separator;
* most currencies render with exactly two fractional digits; the generated CLDR 46.1 table includes standard minor-unit and cash-rounding metadata for 307 currency codes, including zero-, three-, and four-minor-unit entries such as `JPY`, `KRW`, `ADP`, `XCG`, `KWD`, `VED`, `ZWG`, and `CLF`;
* inputs with too many fractional digits are rejected as `Invalid_Argument`; `/cash` accepts one extra fractional digit for deterministic cash rounding;
* `/standard`, `/precision-currency-standard`, `/precision-currency/standard`, and `/precision/currency-standard` restore standard symbol output and standard minor-unit precision, `/narrow`, `/unit-width-narrow`, and `/unit-width/narrow` use narrow symbols where built in, `/name`, `/full-name`, `/unit-width-long`, `/unit-width/long`, `/unit-width-full-name`, and `/unit-width/full-name` emit generated CLDR 46.1 currency display names with CLDR plural-category selection for all imported currency-name locales with exact, parent, and default fallback, `/iso-code`, `/unit-width-iso-code`, and `/unit-width/iso-code` emit the ISO currency code, and `/accounting` renders negative values in parentheses;
* English display names, standard symbols, and narrow symbols are built in for all 307 generated CLDR 46.1 currency codes; localized display-name payloads are generated from CLDR currency locale files where available, with English/code fallback for the broader table;
* `/cash` applies built-in cash increments for currencies such as `CHF`, `CAD`, `DKK`, `HUF`, and `SEK`;
* common comma-decimal locales such as `de`, `fr`, `es`, `it`, `nl`, `pt`, `pl`, `cs`, `ru`, `ro`, `lt`, and `sl` render with comma decimals and suffix symbols; `en`, `ar`, `hi`, `bn`, `ja`, `zh`, and `ko` render symbol and ISO-code currency displays before the amount; `ar` uses Arabic-Indic digits and Arabic separators; `fa` uses Persian digits; `th` uses Thai digits; `bn` uses Bengali digits and Indian grouping; runtime locale sign overrides such as `locale.xx.number_minus_sign` also feed non-accounting negative currency output; explicit `-u-nu-*` locale extensions select all generated CLDR numeric numbering systems, including Latin, Arabic-Indic, extended Arabic, Thai, Devanagari, Bengali, fullwidth, Myanmar, and Han decimal digits;
* generated CLDR 46.1 symbols, narrow symbols, localized display names, cash increments, and ISO minor-unit metadata are built in for 307 currency codes; process-wide runtime data overrides may replace currency symbols, narrow symbols, display names, minor units, and cash increments before generated fallback data is used.

### Number

```text
{value, number}
{value, number, ::percent}
{value, number, ::permille}
{value, number, ::compact-short}
{value, number, ::compact-long}
{value, number, ::scientific}
{value, number, ::engineering}
{value, number, ::precision-integer}
{value, number, ::precision/integer}
{value, number, ::precision-unlimited}
{value, number, ::precision/unlimited}
{value, number, ::precision-fraction/2}
{value, number, ::precision/fraction/2}
{value, number, ::precision-fraction/0-2}
{value, number, ::precision-significant/3}
{value, number, ::precision/significant/3}
{value, number, ::precision-significant/1-3}
{value, number, ::pad-integer/6}
{value, number, ::padding/integer/6}
{value, number, ::precision-increment/0.05}
{value, number, ::precision/increment/0.05}
{value, number, ::rounding/increment/0.05}
{value, number, ::rounding-mode-down}
{value, number, ::rounding-mode-up}
{value, number, ::trailing-zero-display/stripIfInteger}
{value, number, ::spellout}
{value, number, ::ordinal-words}
{value, number, ::spellout-cardinal}
{value, number, ::spellout-ordinal}
{value, number, ::spellout-numbering}
{value, number, ::spellout-year}
{value, number, ::spellout-numbering-verbose}
{value, number, ::spellout-cardinal-masculine}
{value, number, ::spellout-ordinal-feminine}
{amount, number, ::currency/USD}
```

Rules:

* the value argument is strict decimal text with an optional leading sign and `.` fraction separator;
* the supported number skeleton subset includes `::percent`, `::permille`, `::compact-short`, `::compact/short`, `::compact-long`, `::compact/long`, `::scientific`, `::engineering`, `::notation-simple`, `::notation-standard`, `::notation-scientific`, `::notation-engineering`, `::notation-compact-short`, `::notation-compact-long`, `::notation/simple`, `::notation/standard`, `::notation/scientific`, `::notation/engineering`, `::notation/compact-short`, `::notation/compact/short`, `::notation/compact-long`, `::notation/compact/long`, `::precision-integer`, `::precision/integer`, `::precision-unlimited`, `::precision/unlimited`, `::precision-fraction/N`, `::precision/fraction/N`, `::precision-fraction/MIN-MAX`, `::precision/fraction/MIN-MAX`, `::precision-significant/N`, `::precision/significant/N`, `::precision-significant/MIN-MAX`, `::precision/significant/MIN-MAX`, `::precision-increment/N`, `::precision/increment/N`, `::pad-integer/N`, `::padding/integer/N`, `::integer-width/+000`, `::integer-width/000`, `::integer-width/*000`, `::integer-width/+##0`, `::integer-width/##0`, `::integer-width/*##0`, `::rounding-increment/N`, `::rounding/increment/N`, `::rounding-mode-down`, `::rounding-mode-up`, `::rounding-mode-half-up`, `::rounding-mode-half-even`, `::rounding-mode-half-down`, `::rounding-mode-half-ceiling`, `::rounding-mode-half-floor`, `::rounding-mode-ceiling`, `::rounding-mode-floor`, `::sign-auto`, `::sign/auto`, `::sign-negative`, `::sign/negative`, `::sign-always`, `::sign/always`, `::sign-except-zero`, `::sign/except-zero`, `::sign-never`, `::sign/never`, `::sign-accounting`, `::sign/accounting`, `::sign-accounting-always`, `::sign/accounting-always`, `::sign-accounting-except-zero`, `::sign/accounting-except-zero`, `::group-off`, `::group/off`, `::group-auto`, `::group/auto`, `::group-min2`, `::group/min2`, `::group-on-aligned`, `::group/on-aligned`, `::group-thousands`, `::group/thousands`, `::decimal-auto`, `::decimal-always`, `::decimal-display-auto`, `::decimal-display-always`, `::decimal-display/auto`, `::decimal-display/always`, `::trailing-zero-display/auto`, `::trailing-zero-display-auto`, `::trailing-zero-display/stripIfInteger`, `::trailing-zero-display-stripIfInteger`, `::trailing-zero-display-strip-if-integer`, `::scale/N`, `::spellout`, `::spellout-cardinal`, `::spellout-cardinal-verbose`, `::spellout-numbering`, `::spellout-numbering-year`, `::spellout-year`, `::spellout-numbering-verbose`, `::spellout-numbering-financial`, `::spellout-cardinal-masculine`, `::spellout-cardinal-feminine`, `::spellout-cardinal-neuter`, `::ordinal-words`, `::spellout-ordinal`, `::spellout-ordinal-verbose`, `::spellout-ordinal-masculine`, `::spellout-ordinal-feminine`, `::spellout-ordinal-neuter`, and `::currency/XXX[/option]`;
* supported number skeleton tokens may be combined after one `::` prefix, for example `::percent precision-integer` or `::precision-fraction/2 rounding-mode-down`;
* leading zeroes are normalized while preserving a single zero;
* plain `{value, number}` and `::precision-unlimited` preserve fraction digits exactly as supplied; precision and rounding skeletons round deterministically; `::precision-fraction/MIN-MAX` rounds at `MAX` fractional digits and trims trailing zeroes down to `MIN`; `::precision-significant/MIN-MAX` rounds at `MAX` significant digits and trims fractional trailing zeroes while preserving at least `MIN` significant digits;
* compact notation composes with precision and rounding skeletons; `ja`, `zh`, and `ko` use deterministic CJK compact scaling at 10,000 and 100,000,000 with localized suffixes, while other locales use western-style 1,000/1,000,000/1,000,000,000/1,000,000,000,000 thresholds; scientific and engineering notation compose with fraction precision and rounding skeletons while preserving their deterministic default output when no explicit precision is supplied;
* percent and permille notation localize the suffix for built-in `ar` and `fa` entries while preserving deterministic scaling and localized digits;
* notation skeletons accept both the compact local spellings (`::scientific`, `::engineering`, `::compact-short`, `::compact/short`, `::compact-long`, `::compact/long`) and ICU-style aliases (`::notation-scientific`, `::notation-engineering`, `::notation-compact-short`, `::notation-compact-long`, `::notation-simple`, `::notation-standard`, `::notation/scientific`, `::notation/engineering`, `::notation/compact-short`, `::notation/compact/short`, `::notation/compact-long`, `::notation/compact/long`, `::notation/simple`, and `::notation/standard`);
* integer-width skeletons accept one to eighteen required zeroes, optional `#` digits before the required zeroes, and optional `+` or `*` prefixes, then pad integer digits before grouping;
* rounding skeletons include half-up, half-even, half-down, half-ceiling, half-floor, up, down, ceiling, and floor; ceiling/floor and half-ceiling/half-floor preserve mathematical direction for negative values; both hyphen and slash aliases such as `::rounding-mode-half-even` and `::rounding-mode/half-even` are accepted; `::precision-increment/N`, `::precision/increment/N`, `::rounding-increment/N`, and `::rounding/increment/N` round to a positive integer or decimal increment and compose with rounding modes, percent/permille scaling, grouping, and sign display;
* sign-display skeletons control the rendered sign after deterministic rounding; `::sign-auto`, `::sign/auto`, `::sign-display-auto`, `::sign-negative`, `::sign/negative`, and `::sign-display-negative` restore the default sign behavior in compound skeletons, slash aliases such as `::sign/always`, `::sign/except-zero`, `::sign/never`, `::sign-display/always`, `::sign-display/negative`, `::sign/accounting`, `::sign/accounting-always`, and `::sign/accounting-except-zero` are accepted, hyphenated `::sign-display-always`, `::sign-display-except-zero`, `::sign-display-never`, `::sign-display-accounting`, `::sign-display-accounting-always`, and `::sign-display-accounting-except-zero` aliases are accepted, and `::sign-accounting`, `::sign-accounting-always`, and `::sign-accounting-except-zero` render negative values in accounting parentheses;
* grouping skeletons either keep the deterministic locale grouping default (`::group-auto`, `::group/auto`, `::group-on-aligned`, `::group/on-aligned`, `::group-thousands`, `::group/thousands`), suppress grouping separators (`::group-off`, `::group/off`), or require at least two digits before the first separator (`::group-min2`, `::group/min2`); slash aliases such as `::grouping/auto` and `::grouping/min2` are accepted, and hyphenated `::grouping-off`, `::grouping-auto`, `::grouping-min2`, `::grouping-on-aligned`, and `::grouping-thousands` aliases map to the same deterministic controls;
* decimal-display skeletons either keep the deterministic default (`::decimal-auto`, `::decimal-display-auto`, `::decimal/auto`, or `::decimal-display/auto`) or force one localized zero fractional digit for values that would otherwise render as integers (`::decimal-always`, `::decimal-display-always`, `::decimal/always`, or `::decimal-display/always`);
* trailing-zero-display skeletons either keep fixed fractional zeroes (`::trailing-zero-display/auto` or `::trailing-zero-display-auto`) or strip the fractional part when rounding produces an integer (`::trailing-zero-display/stripIfInteger`); `::trailing-zero-display/strip-if-integer`, `::trailing-zero-display-stripIfInteger`, and `::trailing-zero-display-strip-if-integer` are accepted as aliases;
* scale skeletons multiply the parsed numeric value by a positive integer or decimal factor before percent/permille and notation-specific scaling; zero, negative, and malformed factors are rejected; zero, negative, empty, and malformed rounding increments are also rejected;
* grouping is output-only and is applied deterministically using the resolved locale's grouping policy;
* `::spellout`, `::spellout-cardinal`, `::spellout-cardinal-verbose`, `::spellout-numbering`, `::spellout-numbering-year`, `::spellout-year`, `::spellout-numbering-verbose`, `::spellout-numbering-financial`, and the deterministic gendered cardinal aliases render the same cardinal spellout output; `::ordinal-words`, `::spellout-ordinal`, `::spellout-ordinal-verbose`, and the deterministic gendered ordinal aliases render ordinal-word output. These render deterministic English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Japanese, Chinese, Korean, Turkish, Swedish, Danish, Norwegian, Finnish, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Catalan, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, and Hebrew words for signed whole numbers whose absolute integer part is up to 999,999,999, with English fallback for other locales; cardinal spellout skeletons also accept strict decimal text and spell each visible fraction digit after a deterministic localized decimal separator word, exact cardinal decimal RBNF rows can override the full decimal text, exact signed RBNF rows can provide the signed integer-part text for negative decimal spellout, runtime literal numeric `rbnf_rule` rows without substitutions feed exact spellout rows, and runtime `rbnf_rule` rows with substitutions can compose non-negative integer cardinal or ordinal spellout with bounded `<<`, `>>`, `>>>`, CLDR arrow-glyph equivalents `←←`, `→→`, and `→→→`, named `%...` arrow substitutions, including ASCII `<%...<` and `>%...>` forms, recognized cardinal/ordinal target rule-set names for named quotient, remainder, and equality substitutions such as `=%spellout-ordinal=`, bounded plural-affix expressions such as `$(ordinal,one{st}two{nd}few{rd}other{th})$` and `$(cardinal,one{...}other{...})$`, a single trailing CLDR rule semicolon, and optional `[ ... ]` substitutions before built-in fallback, while ordinal-word skeletons remain whole-number only; negative values without an exact signed row use the locale minus sign followed by the localized words, and an explicit plus sign is accepted without rendering a plus sign;
* common comma-decimal locales such as `de`, `fr`, `es`, `it`, `nl`, `pt`, `pl`, `cs`, `ru`, `ro`, `lt`, and `sl` render as `12.345,67`; `fr`, `pl`, `cs`, and `ru` use space-style grouping; `ar` uses Arabic-Indic digits and Arabic separators; `fa` uses Persian digits; `th` uses Thai digits; `bn` uses Bengali digits and Indian grouping; explicit `-u-nu-*` locale extensions select all generated CLDR numeric numbering systems, including `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`; `hi`, `bn`, and `*-IN` locales use Indian primary/secondary grouping;
* input containing grouping separators, exponent notation, or an empty fractional part is rejected as `Invalid_Argument`.

### Date

```text
{day, date}
{day, date, short}
{day, date, medium}
{day, date, long}
{day, date, full}
{day, date, ::short}
{day, date, ::yMMMd}
{instant, date, ::EdMMMy, Europe/Berlin}
```

Rules:

* the date argument is strict ISO calendar text in `YYYY-MM-DD` form;
* dates are range-checked, including leap years;
* the default and `medium` style render as `DD.MM.YYYY` for common day-month-year locales such as `de`, `fr`, `es`, `it`, `nl`, `pt`, `pl`, `cs`, `ru`, `ro`, `lt`, and `sl`, as year-month-day text for `ja`, `zh`, and `ko`, and as `YYYY-MM-DD` for other locales;
* `short` renders as `DD.MM.YY` for day-month-year locales, `YY/M/D` for `ja`, `zh`, and `ko`, and `M/D/YY` for other locales;
* `long` renders with localized month names from the imported CLDR 46.1 date-locale table, or locale-shaped year/month/day literals for locales such as Japanese, Chinese, and Korean;
* `full` includes localized weekday names from the imported CLDR 46.1 date-locale table;
* ICU-style date skeletons beginning with `::` are supported for the deterministic date field set: `G`, `y`, `Y`, `u`, `U`, `r`, `Q`, `q`, `M`, `L`, `l`, `w`, `W`, `d`, `D`, `F`, `g`, `E`, `e`, and `c`; common CLDR `availableFormats` skeletons such as `::yMMMd` resolve through generated locale data before falling back to direct field rendering;
* `::short`, `::medium`, `::long`, `::full`, and the ICU-style `::date-short`, `::date-medium`, `::date-long`, `::date-full`, `::date/short`, `::date/medium`, `::date/long`, and `::date/full` aliases are accepted as skeleton-style aliases for the corresponding deterministic date style patterns;
* skeleton field width controls numeric padding and text width; year fields use width 2 for the two-digit year and otherwise honor the requested minimum width, so `yyyyy` pads to five digits; `r` renders the related Gregorian year from the input date, so it can differ from calendar `y` after non-Gregorian conversion; `Y` renders the week-based year, `w` renders the week of year, and `W` renders the week of month with `0` for leading days before the first week; these fields use generated locale week data by default and runtime-data `first_day_of_week`/`first_week_min_days` preferences when explicitly loaded, so boundary dates can differ from calendar `y`; `G` renders localized Gregorian era labels for built-in `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, and `ko` entries; for example `M` is numeric, `MM` is padded numeric, `MMM` is abbreviated month text, `MMMM` is full month text from the all-locale CLDR 46.1 date-name table, and width 5 uses explicit runtime-data narrow month/weekday names when loaded before falling back without splitting UTF-8 characters; weekday width 6 renders abbreviated short names; `Q`/`q` widths 1-2 render numeric quarters, width 3 renders abbreviated quarter names from the imported CLDR 46.1 date-locale table, width 4 renders wide quarter names from the same table, and width 5 renders runtime/imported narrow quarter names with numeric fallback; `e`/`c` widths 1-2 render deterministic numeric local weekday values, while wider `e`/`c` widths render localized weekday names from the all-locale CLDR 46.1 date-name table;
* skeletons may include apostrophe-quoted literal text, for example `::yyyy'-'MM'-'dd`, `::yyyy','MM`, or `::yyyy'{'MM'}'dd`; doubled apostrophes inside quoted text render one literal apostrophe, quoted braces do not close the message argument, and quoted commas do not split the optional zone argument;
* Buddhist calendar year display, Japanese calendar era-year display with localized `ja` era names for Reiwa, Heisei, Showa, Taisho, Meiji, and Keio, ROC/Minguo year display with localized `zh` era names, Julian calendar date conversion, Coptic calendar date conversion, Ethiopic calendar date conversion, Ethiopic Amete Alem calendar year display, tabular Islamic civil calendar date conversion, tabular astronomical Islamic calendar date conversion, Indian national calendar date conversion, arithmetic Persian calendar date conversion, and deterministic Hebrew lunisolar calendar date conversion are selected by `-u-ca-buddhist`, `-u-ca-japanese`, `-u-ca-roc`, `-u-ca-julian`, `-u-ca-coptic`, `-u-ca-ethiopic`, `-u-ca-ethioaa`, `-u-ca-islamic-civil`, `-u-ca-islamic`, `-u-ca-islamicc`, `-u-ca-islamic-tbla`, `-u-ca-indian`, `-u-ca-persian`, and `-u-ca-hebrew` locale extensions or by runtime-data `locale.xx.default_calendar` preferences; `islamicc` is accepted as an alias for the deterministic tabular Islamic civil conversion and `islamic-tbla` selects the tabular astronomical epoch, `-u-ca-gregory`/`-u-ca-gregorian` explicitly select Gregorian behavior and override runtime defaults, `-u-ca-iso8601` selects Gregorian date conversion with ISO week data (`Y`/`w`/`W` use Monday as first day and four minimum days in the first week), and unsupported calendar extensions are rejected deterministically;
* date arguments may also be ISO instants/date-times in `YYYY-MM-DDTHH:MM[:SS[.fraction]]Z`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HHMM`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM`, or `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM:SS` form, with matching negative offset forms; with an optional zone option, the rendered date is converted before formatting;
* checked IANA tzdb 2026a transition tables are generated into `I18N.CLDR_Data` for primary tzdb zones and aliases over 1900 through 2050; broader runtime tzdb ingestion and historical calendar databases are part of the completion scope, while the current v1.1.0 implementation is the deterministic generated/runtime-data behavior documented here.

### Time

```text
{clock, time}
{clock, time, short}
{clock, time, medium}
{clock, time, long}
{clock, time, full}
{clock, time, ::short}
{clock, time, ::hhmmssa}
{instant, time, ::HHmmz, UTC}
```

Rules:

* the time argument is strict 24-hour text in `HH:MM`, `HH:MM:SS`, or `HH:MM:SS.fraction` form with one to nine fractional-second digits;
* hour, minute, and second ranges are validated;
* the default and `medium` style preserve the validated 24-hour text;
* `short` renders `HH:MM`, except built-in `ko` renders localized 12-hour output with an AM/PM marker;
* `long` and `full` render `HH:MM:SS`, adding `:00` when the input omits seconds, except built-in `ko` renders localized 12-hour output with an AM/PM marker;
* ICU-style time skeletons beginning with `::` are supported for the deterministic time and zone field set: `a`, `b`, `B`, `h`, `H`, `K`, `k`, `j`, `J`, `C`, `m`, `s`, `S`, `A`, `n`, `N`, `z`, `Z`, `O`, `v`, `V`, `X`, and `x`;
* `::short`, `::medium`, `::long`, `::full`, and the ICU-style `::time-short`, `::time-medium`, `::time-long`, `::time-full`, `::time/short`, `::time/medium`, `::time/long`, and `::time/full` aliases are accepted as skeleton-style aliases for the corresponding deterministic time style patterns;
* `H` renders a fixed 24-hour clock field, `h`/`K` render fixed 12-hour clock fields, and `j`/`J`/`C` render the deterministic locale-preferred hour cycle: built-in `en`, `ar`, and `ko` use 12-hour output while other built-in locales use 24-hour output; `j` and `C` add an implicit localized AM/PM marker for 12-hour locales when no explicit `a`/`b`/`B` field is present, while `J` renders the preferred hour without adding a day period; `a` renders source-backed localized AM/PM labels for all 725 imported CLDR 46.1 date locales, `b`/`B` render deterministic flexible day periods using source-backed midnight/noon labels and generated `morning1`/`afternoon1`/`evening1`/`night1` labels where CLDR supplies them, with exact midnight/noon handling, runtime-loadable exact `HH:MM` and half-open day-period range rules, and stable coarse fallback ranges of 00:01-05:59 night, 06:00-11:59 morning, 12:01-17:59 afternoon, and 18:00-23:59 evening before AM/PM fallback, width 5 uses the abbreviated label as the deterministic narrow fallback, `S` renders fractional-second digits padded or truncated from the parsed nanosecond value, `n` renders nanosecond-of-second with the requested minimum width, `A` renders milliseconds in day including parsed fractional seconds, and `N` renders nanoseconds in day;
* time-zone skeleton widths distinguish deterministic zone forms: `Z` widths 1-3 render RFC 822 offsets, `ZZZZ` renders localized GMT offsets with source-backed GMT prefixes and offset separators for imported CLDR 46.1 date locales, `ZZZZZ` renders ISO extended offsets and `Z` for UTC, `X` renders ISO offsets and `Z` for UTC, `x` renders ISO offsets but keeps numeric zero offsets, `O` widths 1-3 render short localized GMT offsets such as `GMT-4`, `GMT+5:45`, `UTC+5.45`, or `GMT` for zero offset, `O` width 4 renders long GMT offsets, `z` widths 1-3 render source-backed short zone abbreviations for built-in DST families with short GMT-offset fallback for fixed zones, `v` widths 1-3 render source-backed short generic zone labels for built-in DST families with short GMT-offset fallback for fixed zones, `zzzz` and `vvvv` render generated source-backed generic-family display names for existing DST family keys plus Lord Howe and fixed Australian eastern, central, central-western, and western zones across imported CLDR date locales where CLDR supplies metazone names, with deterministic built-in and English fallback, `V`/`VV` render the target zone identifier, `VVV` renders a runtime-data or generated CLDR exemplar location before falling back to the location parsed from the zone identifier, and `VVVV` renders source-backed generic location patterns for imported CLDR 46.1 date locales with generated exemplar locations and deterministic fallback;
* skeletons may include apostrophe-quoted literal text, for example `::HH':'mm':'ss' o''clock'`; doubled apostrophes inside quoted text render one literal apostrophe, quoted braces do not close the message argument, and quoted commas do not split the optional zone argument;
* time arguments may also be ISO instants/date-times in `YYYY-MM-DDTHH:MM[:SS[.fraction]]Z`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HHMM`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM`, or `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM:SS` form, with matching negative offset forms; fractional seconds require an explicit seconds field and one to nine digits; the optional second style option names the fixed target zone, for example `{instant, time, long, UTC}` or `{instant, time, short, America/New_York}`;
* supported target zones include `UTC`, `utc`, `Z`, `z`, `GMT`, `gmt`, `Etc/UTC`, `Etc/GMT`, `Zulu`, and UTC aliases, numeric offsets such as `+02`, `+0230`, and `+02:00`, checked IANA tzdb 2026a primary zones, and checked tzdb links such as `US/Eastern`, `Canada/Eastern`, `Mexico/General`, and `Brazil/East`;
* instant conversion uses generated seconds-based tzdb transition offsets for 447 primary zones over 1900 through 2050, including zones outside the older deterministic subset such as `Pacific/Chatham`, `Africa/Cairo`, and `America/St_Johns`; GMT prefixes, offset separators, generic location patterns, and localized `Etc/UTC` long display names are source-backed for imported CLDR date locales where CLDR supplies them, fixed-zone display names for the selected built-in fixed-zone set checked by `cldr/raw/coverage.txt` are generated from source-backed CLDR metazone rows where available, generated generic-family display names cover existing DST family keys plus Lord Howe and fixed Australian eastern, central, central-western, and western zones across imported CLDR date locales where CLDR supplies metazone names, and short-family display names are source-backed where present, while remaining display names use deterministic built-ins with GMT-offset fallback where a localized name family is not built in.

### Date-Time

```text
{instant, datetime}
{instant, datetime, short, UTC}
{instant, datetime, ::short, UTC}
{instant, datetime, long, Europe/Berlin}
{instant, datetime, ::yMdHHmmssz, UTC}
```

Rules:

* date-time arguments use strict ISO instant/date-time text in `YYYY-MM-DDTHH:MM[:SS[.fraction]]Z`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HHMM`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM`, or `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM:SS` form, with matching negative offset forms;
* output combines the corresponding date and time style after converting to the optional fixed target zone;
* date-time skeletons may combine the supported date and time skeleton fields in one `::` option, and `::short`, `::medium`, `::long`, `::full`, `::date-short`, `::date-medium`, `::date-long`, `::date-full`, `::date/short`, `::date/medium`, `::date/long`, `::date/full`, `::time-short`, `::time-medium`, `::time-long`, `::time-full`, `::time/short`, `::time/medium`, `::time/long`, `::time/full`, `::datetime-short`, `::datetime-medium`, `::datetime-long`, `::datetime-full`, `::datetime/short`, `::datetime/medium`, `::datetime/long`, `::datetime/full`, `::dateTime-short`, `::dateTime-medium`, `::dateTime-long`, `::dateTime-full`, `::dateTime/short`, `::dateTime/medium`, `::dateTime/long`, and `::dateTime/full` are accepted as style-pattern aliases;
* invalid offsets, unknown zone identifiers, invalid calendar dates, and out-of-range times return `Invalid_Argument`.

### Deterministic Domain Formatters

```text
{seconds, duration}
{size, bytes}
{distance, unit, kilometer}
{distance, number, ::measure-unit/length-kilometer}
{distance, number, ::measure-unit/length-kilometer unit-width-short}
{distance, number, ::measure-unit/length-kilometer per-measure-unit/duration-hour}
{offset, relative, day}
{items, list}
{items, list, or}
{items, list, unit}
```

Rules:

* `duration` accepts non-negative integer seconds and renders `H:MM:SS` with locale digit substitution;
* `bytes` accepts non-negative integer bytes and renders deterministic binary units (`B`, `KiB`, `MiB`, `GiB`, `TiB`, `PiB`);
* `unit` accepts strict integer or decimal quantities and a supported unit option: `item`, `meter`/`metre`, `kilometer`/`kilometre`, `mile`, `yard`, `foot`, `inch`, `centimeter`/`centimetre`, `millimeter`/`millimetre`, `decimeter`/`decimetre`, `micrometer`/`micrometre`, `nanometer`/`nanometre`, `picometer`/`picometre`, `nautical-mile`, `astronomical-unit`, `light-year`, `parsec`, `fathom`, `furlong`, `pixel`, `point`, `solar-radius`, `earth-radius`, `dot`, `megapixel`, `pixel-per-centimeter`/`pixel-per-centimetre`, `pixel-per-inch`, `dot-per-centimeter`/`dot-per-centimetre`, `dot-per-inch`, `liter`/`litre`, `milliliter`/`millilitre`, `gallon`, `fluid-ounce`, `cup`, `tablespoon`, `teaspoon`, `pint`, `quart`, `barrel`, `gram`, `kilogram`, `milligram`, `tonne`, `pound`, `ounce`, `stone`, `carat`, `ton`, `dalton`, `earth-mass`, `solar-mass`, `nanosecond`, `microsecond`, `millisecond`, `second`, `minute`, `hour`, `day`, `week`, `month`, `quarter`, `year`, `decade`, `century`, `square-meter`/`square-metre`, `square-kilometer`/`square-kilometre`, `square-foot`, `square-mile`, `square-centimeter`/`square-centimetre`, `square-inch`, `square-yard`, `acre`, `hectare`, `celsius`, `fahrenheit`, `kelvin`, `degree`, `radian`, `revolution`, `arc-minute`, `arc-second`, `g-force`, `meter-per-square-second`/`metre-per-square-second`, `newton`, `pound-force`, `newton-meter`/`newton-metre`, `bit`, `byte`, `kilobyte`, `megabyte`, `gigabyte`, `terabyte`, `megabit`, `gigabit`, `petabyte`, `kilometer-per-hour`/`kilometre-per-hour`, `mile-per-hour`, `knot`, `beaufort`, `meter-per-second`/`metre-per-second`, `liter-per-100-kilometer`/`litre-per-100-kilometre`, `mile-per-gallon`, `mile-per-gallon-imperial`, `joule`, `kilojoule`, `calorie`, `kilocalorie`, `kilowatt-hour`, `electronvolt`, `british-thermal-unit`, `therm-us`, `watt`, `kilowatt`, `horsepower`, `hertz`, `kilohertz`, `megahertz`, `hectopascal`, `pascal`, `kilopascal`, `millibar`, `bar`, `atmosphere`, `inch-ofhg`, `millimeter-ofhg`, `pound-force-per-square-inch`, `ampere`, `milliampere`, `volt`, `millivolt`, `ohm`, `lumen`, `lux`, `candela`, `solar-luminosity`, `percent`, `permille`, `permillion`, `portion`, or `karat`; ICU-style identifiers such as `length-metre`, `length-kilometre`, `length-mile`, `length-yard`, `length-foot`, `length-inch`, `length-decimeter`/`length-decimetre`, `length-micrometer`/`length-micrometre`, `length-nanometer`/`length-nanometre`, `length-picometer`/`length-picometre`, `length-nautical-mile`, `length-astronomical-unit`, `length-light-year`, `length-parsec`, `length-fathom`, `length-furlong`, `length-pixel`, `length-point`, `length-solar-radius`, `length-earth-radius`, `graphics-dot`, `graphics-megapixel`, `graphics-pixel-per-centimeter`, `graphics-pixel-per-centimetre`, `graphics-pixel-per-inch`, `graphics-dot-per-centimeter`, `graphics-dot-per-centimetre`, `graphics-dot-per-inch`, `volume-litre`, `volume-fluid-ounce`, `volume-cup`, `volume-tablespoon`, `volume-teaspoon`, `volume-pint`, `volume-quart`, `volume-barrel`, `volume-cubic-meter`/`volume-cubic-metre`, `volume-cubic-centimeter`/`volume-cubic-centimetre`, `volume-cubic-inch`, `volume-cubic-foot`, `volume-cubic-yard`, `volume-acre-foot`, `mass-milligram`, `mass-tonne`, `mass-pound`, `mass-stone`, `mass-carat`, `mass-ton`, `mass-dalton`, `mass-earth-mass`, `mass-solar-mass`, `duration-nanosecond`, `duration-microsecond`, `duration-millisecond`, `duration-fortnight`, `duration-hour`, `duration-quarter`, `duration-decade`, `duration-century`, `area-square-meter`, `area-square-kilometre`, `area-square-foot`, `area-square-mile`, `area-square-centimeter`/`area-square-centimetre`, `area-square-inch`, `area-square-yard`, `area-acre`, `area-hectare`, `temperature-celsius`, `temperature-fahrenheit`, `temperature-kelvin`, `angle-degree`, `angle-radian`, `angle-revolution`, `angle-arc-minute`, `angle-arc-second`, `acceleration-g-force`, `acceleration-meter-per-square-second`, `acceleration-metre-per-square-second`, `force-newton`, `force-pound-force`, `torque-newton-meter`, `torque-newton-metre`, `digital-bit`, `digital-byte`, `digital-megabyte`, `digital-megabit`, `digital-gigabit`, `digital-petabyte`, `speed-kilometre-per-hour`, `speed-metre-per-second`, `consumption-liter-per-100-kilometer`, `consumption-litre-per-100-kilometre`, `consumption-mile-per-gallon`, `consumption-mile-per-gallon-imperial`, `energy-joule`, `energy-kilojoule`, `energy-calorie`, `energy-kilocalorie`, `energy-kilowatt-hour`, `energy-electronvolt`, `energy-british-thermal-unit`, `energy-therm-us`, `power-watt`, `power-kilowatt`, `power-horsepower`, `frequency-hertz`, `frequency-kilohertz`, `frequency-megahertz`, `pressure-hectopascal`, `pressure-pascal`, `pressure-kilopascal`, `pressure-millibar`, `pressure-bar`, `pressure-atmosphere`, `pressure-inch-ofhg`, `pressure-millimeter-ofhg`, `pressure-pound-force-per-square-inch`, `electric-ampere`, `electric-milliampere`, `electric-volt`, `electric-millivolt`, `electric-ohm`, `light-lumen`, `light-lux`, `light-candela`, `light-solar-luminosity`, `concentr-percent`, `concentr-permille`, `concentr-permillion`, `concentr-portion`, and `concentr-karat` are accepted as aliases; width suffixes include `/unit-width-short`, `/unit-width/short`, `/unit-width-narrow`, `/unit-width/narrow`, `/unit-width-long`, `/unit-width/long`, `/unit-width-full-name`, and `/unit-width/full-name`; decimal output localizes signs, digits, and decimal separators, short/narrow unit symbols are source-backed, per-unit separators are source-backed for the expanded list-locale set, and full unit names include source-backed English rows for all supported units, source-backed German rows for the generated German fallback-unit set, source-backed Italian, Portuguese, Dutch, Romanian, Lithuanian, Slovenian, Polish, Czech, Russian, Arabic, Japanese, Chinese, and Korean rows for their generated extended-unit sets, and are localized for `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, and `ko`, with English fallback for supported units that lack localized built-ins;
* `{value, number, ::measure-unit/...}` is accepted as an ICU number-skeleton spelling for deterministic unit formatting; supported unit identifiers are `length-meter`/`length-metre`, `length-kilometer`/`length-kilometre`, `length-mile`, `length-yard`, `length-foot`, `length-inch`, `length-centimeter`/`length-centimetre`, `length-millimeter`/`length-millimetre`, `length-decimeter`/`length-decimetre`, `length-micrometer`/`length-micrometre`, `length-nanometer`/`length-nanometre`, `length-picometer`/`length-picometre`, `length-nautical-mile`, `length-astronomical-unit`, `length-light-year`, `length-parsec`, `length-fathom`, `length-furlong`, `length-pixel`, `length-point`, `length-solar-radius`, `length-earth-radius`, `graphics-dot`, `graphics-megapixel`, `graphics-pixel-per-centimeter`/`graphics-pixel-per-centimetre`, `graphics-pixel-per-inch`, `graphics-dot-per-centimeter`/`graphics-dot-per-centimetre`, `graphics-dot-per-inch`, `volume-liter`/`volume-litre`, `volume-milliliter`/`volume-millilitre`, `volume-gallon`, `volume-fluid-ounce`, `volume-cup`, `volume-tablespoon`, `volume-teaspoon`, `volume-pint`, `volume-quart`, `volume-barrel`, `volume-cubic-meter`/`volume-cubic-metre`, `volume-cubic-centimeter`/`volume-cubic-centimetre`, `volume-cubic-inch`, `volume-cubic-foot`, `volume-cubic-yard`, `volume-acre-foot`, `mass-gram`, `mass-kilogram`, `mass-milligram`, `mass-tonne`, `mass-pound`, `mass-ounce`, `mass-stone`, `mass-carat`, `mass-ton`, `mass-dalton`, `mass-earth-mass`, `mass-solar-mass`, `duration-nanosecond`/`microsecond`/`millisecond`/`second`/`minute`/`hour`/`day`/`week`/`month`/`fortnight`/`quarter`/`year`/`decade`/`century`, `area-square-meter`/`area-square-metre`, `area-square-kilometer`/`area-square-kilometre`, `area-square-foot`, `area-square-mile`, `area-square-centimeter`/`area-square-centimetre`, `area-square-inch`, `area-square-yard`, `area-acre`, `area-hectare`, `temperature-celsius`, `temperature-fahrenheit`, `temperature-kelvin`, `angle-degree`, `angle-radian`, `angle-revolution`, `angle-arc-minute`, `angle-arc-second`, `acceleration-g-force`, `acceleration-meter-per-square-second`/`acceleration-metre-per-square-second`, `force-newton`, `force-pound-force`, `torque-newton-meter`/`torque-newton-metre`, `digital-bit`/`byte`/`kilobyte`/`kilobit`/`megabyte`/`gigabyte`/`terabyte`/`terabit`/`megabit`/`gigabit`/`petabyte`/`petabit`/`exabyte`/`exabit`, `speed-kilometer-per-hour`/`speed-kilometre-per-hour`, `speed-mile-per-hour`, `speed-knot`, `speed-beaufort`, `speed-meter-per-second`/`speed-metre-per-second`, `consumption-liter-per-100-kilometer`, `consumption-litre-per-100-kilometre`, `consumption-mile-per-gallon`, `consumption-mile-per-gallon-imperial`, `energy-joule`, `energy-kilojoule`, `energy-calorie`, `energy-kilocalorie`, `energy-kilowatt-hour`, `energy-electronvolt`, `energy-british-thermal-unit`, `energy-therm-us`, `power-watt`, `power-kilowatt`, `power-horsepower`, `frequency-hertz`, `frequency-kilohertz`, `frequency-megahertz`, `pressure-hectopascal`, `pressure-pascal`, `pressure-kilopascal`, `pressure-millibar`, `pressure-bar`, `pressure-atmosphere`, `pressure-inch-ofhg`, `pressure-millimeter-ofhg`, `pressure-pound-force-per-square-inch`, `electric-ampere`, `electric-milliampere`, `electric-volt`, `electric-millivolt`, `electric-ohm`, `light-lumen`, `light-lux`, `light-candela`, `light-solar-luminosity`, `concentr-percent`, `concentr-permille`, `concentr-permillion`, `concentr-portion`, and `concentr-karat`, plus the direct unit names; supported width tokens are `unit-width-full-name`/`unit-width/full-name`, `unit-width-long`/`unit-width/long`, `unit-width-short`/`unit-width/short`, and `unit-width-narrow`/`unit-width/narrow`; one `per-measure-unit/...` token may be added for compound rates such as `kilometers per hour`, `Kilometer pro Stunde`, `chilometri per ora`, `meters per square second`, or `km/h`;
* `relative` accepts an integer offset and one of the supported unit options `second`, `minute`, `hour`, `day`, `week`, `month`, `quarter`, or `year`, with optional `/short`, `/unit-width-short`, `/unit-width/short`, `/narrow`, `/unit-width-narrow`, or `/unit-width/narrow` width suffixes, rendering forms such as `5 seconds ago`, `in 2 qtrs.`, `in 2q`, or `now`; numeric offsets localize digits, current-period full/short/narrow second/minute/hour/day/week/month/quarter/year names for offset `0` and complete nonzero full/short/narrow second/minute/hour/day/week/month/quarter/year future/past plural-category patterns are generated from source-backed CLDR date-field rows for all imported CLDR 46.1 date locales where CLDR supplies them, source-backed one/other relative unit display rows are generated for `en`, `ro`, `lt`, `sl`, `cs`, `ar`, `tr`, `sv`, `da`, `eo`, `vi`, `hu`, `sk`, `fi`, `no`, `id`, `ms`, `af`, `sw`, `eu`, `ja`, `zh`, and `ko`, with German plural day/month/year display overrides, and source-backed offset affixes are generated for `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, `ko`, `tr`, `sv`, `da`, `fi`, `eo`, `vi`, `hu`, `sk`, `no`, `id`, `ms`, `af`, `sw`, and `eu`; English fallback is used elsewhere, and deterministic CLDR cardinal-category forms are source-backed where built in for Russian/Ukrainian and Polish values such as `5 days` or `5 months`;
* `list` accepts non-empty pipe-delimited item text and renders deterministic CLDR-style list output. The default, `standard`, and `and` options render conjunction lists; `or` and `disjunction` render deterministic disjunction lists; `unit` renders unit-style lists without a final conjunction. Two-item, start, middle, final, and generic item separators are source-backed for `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, `ko`, `tr`, `sv`, `da`, `no`, `fi`, `id`, `ms`, `eo`, `vi`, `sw`, `af`, `eu`, `hu`, `sk`, `bg`, `uk`, `fa`, `th`, `hi`, `el`, and `he`, with deterministic fallback elsewhere. Runtime data can override CLDR-style standard, or/disjunction, and unit two-item, start, middle, final, and item list pattern separators, including typed `listPatternPart` rows and child rows inside CLDR `<listPattern type="standard">`, `<listPattern type="or">`, `<listPattern type="disjunction">`, and `<listPattern type="unit">` containers.

Numeric fields in these domain formatters use the resolved locale signs and digit set, including explicit `-u-nu-*` numbering-system extensions for all generated CLDR numeric systems.

### Runtime Data Overrides

`I18N.Runtime.Load_Data_Text` and `Load_Data_File` load deterministic process-wide runtime-data overrides from line-oriented text. Supported key/value entries include locale separators, grouping policy, digits, number signs/suffixes/exponent/accounting symbols, month/weekday/quarter/day-period/era names, exact and range flexible day-period rules, time-zone display, exemplar-location, generic-location patterns, and short specific/generic names, default time-zone preferences and offset components, unit and relative-time display text, list separators, date/time style skeletons, available-format skeleton patterns, date/time skeleton append separators, and datetime style separators, supported default calendar preferences, currency placement/separators/accounting affixes, fixed time-zone base offsets, currency metadata/display fields, exact non-negative plural-category overrides, and known CLDR plural-rule family aliases:

```text
locale.zz.decimal_separator = |
locale.zz.group_separator = _
locale.zz.number_percent_suffix = " pct"
locale.zz.number_permille_suffix = " pm"
locale.zz.number_plus_sign = PLUS
locale.zz.number_minus_sign = MINUS
locale.zz.number_exponent_separator = EXP
locale.zz.number_accounting_prefix = [
locale.zz.number_accounting_suffix = ]
locale.zz.gmt_offset_prefix = GMT
locale.zz.timezone_offset_separator = :
locale.zz.timezone_utc_designator = Z
locale.zz.default_timezone = Example/Zone
locale.zz.uses_indian_grouping = true
locale.zz.month.1 = OverrideMonth
locale.zz.quarter.2 = OverrideQuarter
locale.zz.quarter_short.2 = OQ2
locale.zz.day_period.pm = override-pm
locale.zz.day_period_wide.noon = override-noon
locale.zz.day_period_rule.morning1 = 04:00-10:00
locale.zz.day_period_rule.night1 = 21:00-04:00
locale.zz.era.gregorian.ad = AD-override
locale.zz.timezone_display.Example/Zone = Example Time
locale.zz.timezone_exemplar.Example/Zone = Example
locale.zz.timezone_location_pattern = {0} Time
locale.zz.unit.meter.unit-width-full-name.one = meter-override
locale.zz.relative_current.day = today-override
locale.zz.relative_exact.day.unit-width-full-name.-1 = yesterday-override
locale.zz.relative_unit.day.other = days-override
locale.zz.relative_prefix.future = "in "
locale.zz.relative_suffix.future = " from now"
locale.zz.list_item_separator = " | "
locale.zz.list_pair_separator = " + "
locale.zz.list_start_separator = " < "
locale.zz.list_middle_separator = " = "
locale.zz.list_final_separator = " & "
locale.zz.date_style.long = MMMM' 'd' 'yyyy
locale.zz.default_calendar = persian
locale.zz.default_hour_cycle = h12
locale.zz.first_day_of_week = mon
locale.zz.first_week_min_days = 4
timezone.Example/Zone.base_offset_minutes = 90
timezone.Example/Zone.transition.20260101000000 = 3600
timezone.Example/Zone.transition.2026-01-01T00:00:00Z = 3600
currency.XTS.symbol = XT$
currency.XTS.display_name.other = test credits
currency.XTS.minor_units = 3
currency.XTS.cash_increment = 5
plural.cardinal.zz.7 = few
plural.ordinal.zz.9 = two
plural.rule_family.cardinal.zz = ar
plural.rule_family.ordinal.zz = en-ordinal
plural.rule.cardinal.zz.one = n is 1
plural.rule.cardinal.zz.few = n mod 10 in 2..4
rbnf.zz.cardinal.2 = two
rbnf.zz.ordinal.2 = second
rbnf.zz.decimal_separator = point
rbnf_rule.zz.cardinal.40 = forty[->>]
rbnf_rule.zz.cardinal.100 = << hundred[ >>>]
```

Malformed runtime data is rejected transactionally and leaves the previous override set intact. Fixed time-zone base offsets use `timezone.<zone>.base_offset_minutes` or second-precision `timezone.<zone>.base_offset_seconds`; bounded runtime transition offsets use `timezone.<zone>.transition.<UTC>` with either `YYYYMMDDHHMMSS` or `YYYY-MM-DDTHH:MM[:SS]Z` UTC keys and an offset in seconds. Transition rendering selects the nearest loaded transition at or before the instant, before falling back to generated tzdb data. Flexible day-period rules use exact `HH:MM` rows or half-open `HH:MM-HH:MM` ranges; ranges may wrap midnight, and exact midnight/noon labels are still selected before flexible rules. CLDR-shaped `dayPeriodRuleSet` and `dayPeriodRules` containers provide inherited `locales` or `locale` lists for child `<dayPeriodRule>` rows, with inner `dayPeriodRules` locale lists taking precedence. Exact CLDR `at="HH:MM"` rows are accepted for supported day-period types and malformed exact times are rejected transactionally. CLDR `<currency type="...">` containers provide inherited ISO codes for child `<symbol>` rows, including `alt="narrow"` narrow-symbol rows, and child `<displayName>` rows, using `count` for plural-category display names with `other` as the default. CLDR `currencyFormats`, `currencyFormatLength`, and non-self-closing `currencyFormat type="standard|accounting"` containers provide context for child `<pattern>` rows when the pattern can be mapped to currency sign placement, an optional amount separator, and accounting affixes from a negative subpattern. CLDR `currencySpacing` containers with nested `beforeCurrency` or `afterCurrency` containers provide placement context for child `<insertBetween>` rows and accept bounded `currencyMatch`/`surroundingMatch` metadata rows in that spacing context. CLDR `dateFormatLength`/`dateFormat`, `timeFormatLength`/`timeFormat`, and `dateTimeFormatLength`/`dateTimeFormat` containers provide style and kind context for child `<pattern>` rows, with datetime patterns limited to strict `{1}<separator>{0}` extraction. Bounded plural-rule expression rows use `plural.rule.<kind>.<locale>.<category> = <rule>`, normalized `plural_rule_text|kind|locale|category|rule`, or LDML-style `<pluralRule locale="xx" type="cardinal" count="one">n is 1</pluralRule>` forms. CLDR-shaped `plurals` and `pluralRules locales="...">` containers provide inherited cardinal/ordinal kind and space-separated locale lists for child `<pluralRule>` rows. They support operands `n`, `i`, `v`, `w`, `f`, `t`, `c`, and `e`, optional `mod`/`%`, relation operators `is`, `is not`, `=`, `!=`, `in`, `not in`, `within`, and `not within`, comma-separated values, `A..B` ranges, and `and`/`or` clauses; the `c` and `e` compact-exponent operands are accepted with deterministic value zero on this runtime path; CLDR sample annotations beginning with `@integer` or `@decimal` are ignored for evaluation; exact plural-category rows take precedence, and generated rule families remain the fallback. `rbnf_rule.<locale>.<kind>.<base>` rows, normalized `rbnf_rule_text|locale|kind|base|hex-bytes` rows, and LDML-style `<rbnfRule ...>` element text accept `cardinal` or `ordinal` kinds, a positive integer base, `base/divisor` descriptor, or LDML-style `radix` attribute, `negative`/`-x`/`−x` negative-number rules, `0.x` zero-integer decimal rules, `x.0` visible-zero-fraction decimal rules, and `decimal`/`x.x` decimal-number rules. Literal numeric rule rows without substitutions are stored as exact spellout rows when the descriptor has no explicit divisor or trailing divisor marker. Integer rules with substitutions use `<<` quotient substitutions, `>>` or `>>>` remainder substitutions, CLDR arrow-glyph equivalents `←←`, `→→`, and `→→→`, named `%...` arrow substitutions, including ASCII `<%...<` and `>%...>` forms, recognized cardinal/ordinal target rule-set names for named quotient, remainder, and equality substitutions such as `=%spellout-ordinal=`, bounded plural-affix expressions such as `$(ordinal,one{st}two{nd}few{rd}other{th})$` and `$(cardinal,one{...}other{...})$`, a single trailing CLDR rule semicolon, and optional `[ ... ]` text emitted only for nonzero remainders; plural-affix expressions are validated at load time and must use a `cardinal` or `ordinal` selector, known CLDR count names, balanced branch braces, and an `other` branch; unknown named substitution rule-set names continue to normalize to same-kind bounded substitutions; quotient and remainder substitutions use the CLDR-style default divisor derived from the rule descriptor unless an explicit `base/divisor` descriptor is loaded; negative rules apply `>>` or `>>>` to the absolute value; decimal rules apply `<<` to the integer part and `>>` or `>>>` to visible fraction digits; arrow-glyph forms are normalized at load time. Evaluation is bounded, and exact/runtime rows take precedence. Bounded multi-line RBNF LDML-style blocks are accepted when the opening `<rbnf ...>`, `<rbnfRule ...>`, or `<rbnfrule ...>` tag, element text, and matching closing tag appear on separate lines; malformed, nested, mismatched, overlong, empty, or unterminated blocks are rejected transactionally. Full LDML expression parsing is part of the completion scope; the current v1.1.0 overrides are a deterministic public loading format for runtime data the library already consumes, including imports that map locales onto built-in CLDR plural-rule families.

The same loader accepts checked normalized CLDR import rows emitted by the project tooling, including `decimal_text`, `group_text`, `digits_codepoints`, `names_hex` month/weekday/quarter name sets, `locale_text|locale|field|hex-bytes`, `currency_text`, `plural_rule|kind|locale|family`, `plural_rule_text|kind|locale|category|rule`, `rbnf_text|locale|kind|value|hex-bytes`, `rbnf_rule_text|locale|kind|base|hex-bytes`, and selected `raw|...` rows for grouping, date order, currency placement, plural rule-family mappings, and localized currency-name payloads. `locale_text`, `rbnf_text`, and `rbnf_rule_text` payloads are UTF-8 bytes encoded as hexadecimal and are accepted only for supported locale fields, exact RBNF spellout override fields with a single trailing CLDR rule semicolon ignored, literal numeric RBNF rule rows without substitutions, or bounded RBNF rule-expression fields. These rows feed the same formatter data tables as the key/value overrides.


CLDR RBNF containers `rulesetGrouping`, `ruleSetGrouping`, `ruleset`, `ruleSet`, and `rules` are accepted around supported RBNF leaf rows with `value` attributes or CLDR `descriptor: rule` element text; `ruleset` and `ruleSet` containers provide inherited rule-set names for child `<rbnfrule>` rows that omit `type`, `ruleSet`, or `ruleset`. Positive integer RBNF rule descriptors may use properly comma-grouped bases such as `2,000` and CLDR-style trailing `>` divisor markers; each marker reduces the effective default or explicit divisor by one decimal order, and malformed grouping or over-reduction is rejected transactionally.

`weekData` rows accept `day` as an alias for `firstDay` and `count` as an alias for `minDays`. CLDR-shaped `<weekData>` containers may wrap child `<firstDay day="..."/>` and `<minDays count="..."/>` rows, with locale context inherited from a surrounding `ldml`/`locale` wrapper.

CLDR-shaped `monthWidth`, `dayWidth`, and `quarterWidth` containers provide inherited `wide`/`abbreviated`/`narrow` width context for child `month`, `day`, and `quarter` rows. `dayPeriodWidth` containers provide inherited abbreviated, wide, and narrow width context for child `dayPeriod` rows.

CLDR-shaped `monthContext`, `dayContext`, and `quarterContext` containers with `type="stand-alone"` provide stand-alone runtime date names used by `L`, `c`, and `q` skeleton fields, including explicit narrow width 5 names for `LLLLL`, `ccccc`, and `qqqqq`. Missing stand-alone names fall back to the corresponding format names used by `M`, `E`, and `Q`.

`unitName`, `unitDisplayName`, `displayName`, and `unitPattern` rows treat `type` as the unit identifier when `unit` is omitted. `unitDisplayName`, `displayName`, and `unitName` rows without `count` feed the `other` unit display slot. `compoundUnitPattern` rows with `type="per"` accept strict `{0}<separator>{1}` text and feed long or short per-unit separators.

`relativeName`, `relativePeriod`, and `relativeUnit` rows treat `type` as the unit identifier when `unit` is omitted. CLDR-shaped `fields` containers may wrap `field` containers that provide inherited relative unit and width for child exact-offset and relative-time rows.

Fixed-offset `timeZone` rows accept `gmtOffset` and `utcOffset` as aliases for `offset`; fixed-offset LDML and tzdb rows accept case-insensitive `Z`, `UTC`, `GMT`, `+H`, `+HH`, `+HMM`, `+HHMM`, `+H:MM`, and `+HH:MM` offsets, with matching negative numeric forms; bounded fixed-offset tzdb `Zone` rows apply direct SAVE offsets from the RULES column, and continuation rows use direct SAVE offsets plus numeric, last-weekday, and weekday-on-or-before/after Jan-Dec until fields with optional `HH[:MM[:SS]][u|g|z|s|w]` times where suffixless and `w` use wall time, `s` uses standard time, and `u`/`g`/`z` use UTC to feed runtime transition offsets. Month and weekday tokens plus Rule only/minimum/maximum year keywords are accepted case-insensitively. Full-line and trailing `#` comments are ignored in tzdb `Zone`, continuation, `Rule`, and `Link` rows. Runtime transition override rows accept UTC transition keys in `YYYYMMDDHHMMSS` or `YYYY-MM-DDTHH:MM[:SS]Z` form and signed offset seconds in the range -86400 through 86400.

`symbols` rows accept CLDR-shaped number-symbol aliases: `percentSign`, `perMille`, `plusSign`, `minusSign`, and `exponential` feed the same fields as `percent`, `permille`, `plus`, `minus`, and `exponent`. CLDR-shaped `<defaultNumberingSystem>` element text feeds the locale default numbering-system field, and `<symbols numberSystem="...">` containers provide context for child `<decimal>`, `<group>`, `<percentSign>`, `<perMille>`, `<plusSign>`, `<minusSign>`, and `<exponential>` rows. Child symbol rows are applied for the selected default numbering system, or for `latn` when no default is set.

### Nesting

Supported constructs may be nested inside branch bodies.

### Apostrophe Escaping

ICU-style apostrophe quoting is supported for syntax characters:

```text
Don''t parse '{name}'
{count, plural, one {'#' item} other {'#' items and # raw}}
```

Rules:

* `''` renders as a single apostrophe;
* an apostrophe before `{`, `}`, `#`, or another apostrophe starts quoted literal text;
* quoted `{` and `}` are literal braces and do not start or end an argument;
* quoted `#` is literal and does not trigger plural/selectordinal number substitution;
* an apostrophe before an ordinary non-syntax character remains a literal apostrophe;
* an unterminated quoted span closes at the end of the current message or branch.

## Unsupported v1.1.0 features

* Loading arbitrary external CLDR plural-rule files at runtime; built-in `I18N.Plurals` rules use generated CLDR 46.1 rule-family mappings and deterministic evaluators, with bounded runtime plural-rule expression rows for selected categories.
* Unsupported formatting skeletons.
* LDML/tzdb source forms outside the deterministic runtime-data loaders documented above. Broader runtime loading and compilation of external LDML/tzdb sources is part of the completion scope.
* CLDR RBNF rule-set behavior outside the deterministic spellout, ordinal-word, exact override, and bounded runtime-rule forms documented above. Full CLDR RBNF behavior is part of the completion scope.
* Runtime parser/compiler access through the public API.
* Bytecode VM or code-generation execution model in the current v1.1.0 runtime. Alternative execution and code-generation paths are part of the completion scope.
* Binary catalog formats beyond the versioned `I18N-CATALOG-BINARY` envelope.

Unsupported syntax must fail deterministically during initialization or validation rather than being accepted silently.
