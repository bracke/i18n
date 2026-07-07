# Public API

This document describes the v1.1.0 application-facing API. Packages not listed here are implementation details or regression-test support and are outside the v1.1.0 source-compatibility promise.

## Public packages

Stable public packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Parser, validation, compiler, AST, compiled IR, cache, buffer, fast-render,
lower-level renderer, internal error, observability, formatter implementation,
generated CLDR data, and compatibility packages are Ada private child packages.
Ordinary application code cannot legally `with` those packages.

## `I18N.Runtime`

`I18N.Runtime.Instance` is the stable runtime handle. Initialize it once, then call the catalog-oriented render API.

### Initialization

```ada
procedure Initialize
  (Item         : in out I18N.Runtime.Instance;
   Catalog_Path : String);
procedure Initialize_Binary_File
  (Item         : in out I18N.Runtime.Instance;
   Catalog_Path : String);
```

Behavior:

* opens the catalog file when `Catalog_Path` names an existing ordinary file;
* reads the entire catalog deterministically;
* accepts blank lines and comment lines beginning with `#`;
* accepts one `default_locale = locale` directive anywhere in the file;
* validates duplicate entries, empty locale names, empty keys, empty default locale, duplicate default locale, malformed lines, and unbalanced catalog message braces;
* performs deterministic catalog validation during initialization;
* leaves the runtime invalid when any catalog error is found.
* `Initialize_Binary_File` first validates the v1.1 binary envelope, then
  initializes from its canonical text payload.

Failure behavior:

* initialization records failure state instead of exposing parser/compiler internals;
* `Is_Valid` returns `False` after invalid initialization;
* public catalog `Render` returns `Execution_Error` when the runtime is invalid.

Compatibility note: the source contains single-message helper entry points for in-tree regression tests. Those entry points live behind Ada private-child visibility and are not importable application API.

### Render

```ada
function Render
  (Item      : I18N.Runtime.Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : I18N.Arguments.Arguments)
   return I18N.Result.Render_Result;
```

Render behavior:

* does not mutate the runtime catalog;
* resolves locale by deterministic fallback;
* returns `Missing_Key` after fallback if no entry exists;
* returns `Missing_Argument` when a variable or selector argument is absent;
* returns `Invalid_Argument` when a numeric selector argument is not a strict decimal integer;
* applies ICU-style apostrophe escaping for literal syntax characters in catalog messages;
* returns `Formatting_Error` for deterministic branch-selection failures;
* returns `Buffer_Overflow` when output exceeds the supported render buffer;
* returns `Internal_Error` only for unexpected implementation failures contained by the facade;
* does not raise for normal ICU/render failures.

### Catalog shard loading

```ada
type Duplicate_Policy is (Reject_Duplicates, Keep_First, Override_Previous);
type Load_Status is
  (Loaded, Source_Not_Found, Invalid_Catalog, Duplicate_Rejected, Runtime_Invalid);
type Load_Result is record
   Status           : Load_Status;
   Entries_Added    : Natural;   --  new locale/key pairs inserted
   Entries_Replaced : Natural;   --  existing pairs overwritten (Override_Previous)
   Entries_Ignored  : Natural;   --  duplicate pairs skipped (Keep_First)
   Diagnostics      : I18N.Diagnostics.Diagnostic_List;
end record;

procedure Load_File
  (Item   : in out Instance; Path : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Binary_File
  (Item   : in out Instance; Path : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Text
  (Item   : in out Instance; Source_Name : String; Text : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
```

`Load_File`/`Load_Text` layer additional catalog shards into a runtime. `Load_Binary_File` layers a versioned binary catalog shard after decoding its envelope. These load APIs are transactional and non-destructive: a failed load (`Source_Not_Found`, `Invalid_Catalog`, `Duplicate_Rejected`, `Runtime_Invalid`) leaves the runtime exactly as it was. The legacy `Load` procedure is retained and, like `Initialize`/`Initialize_Binary_File`, marks the runtime invalid on failure.

### Catalog validation

```ada
type Catalog_Validation_Result is record
   Valid       : Boolean;
   Entry_Count : Natural;
   Diagnostics : I18N.Diagnostics.Diagnostic_List;
end record;

function Validate_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Binary_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Catalog_Text
  (Source_Name : String; Text : String) return Catalog_Validation_Result;
function Validate_Binary_Catalog_Text
  (Source_Name : String; Text : String) return Catalog_Validation_Result;
```

Validation never mutates any runtime. If validation fails, existing runtimes remain usable.

### Runtime Data Overrides

```ada
type Data_Load_Status is (Data_Loaded, Data_Source_Not_Found, Invalid_Data);
type Data_Load_Result is record
   Status      : Data_Load_Status;
   Diagnostics : I18N.Diagnostics.Diagnostic_List;
end record;

function Load_Data_Text
  (Source_Name : String; Text : String) return Data_Load_Result;
function Load_Data_File (Path : String) return Data_Load_Result;
procedure Clear_Runtime_Data;
```

`Load_Data_Text`/`Load_Data_File` install process-wide deterministic runtime-data overrides before generated CLDR/tzdb fallback data. The key/value line format is `key = value`. Supported keys are locale overrides such as `locale.xx.decimal_separator`, `locale.xx.group_separator`, `locale.xx.number_percent_suffix`, `locale.xx.number_permille_suffix`, `locale.xx.number_plus_sign`, `locale.xx.number_minus_sign`, `locale.xx.number_exponent_separator`, `locale.xx.number_accounting_prefix`, `locale.xx.number_accounting_suffix`, `locale.xx.uses_indian_grouping`, `locale.xx.uses_day_month_year`, `locale.xx.digit.0` through `digit.9`, `locale.xx.default_numbering_system` for generated CLDR numeric numbering systems such as `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`, `locale.xx.default_hour_cycle` for `h11`, `h12`, `h23`, or `h24`, `locale.xx.first_day_of_week` for `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, or `sat`, `locale.xx.first_week_min_days` from `1` through `7`, `locale.xx.month.1` through `month.12`, `locale.xx.month_short.1` through `month_short.12`, `locale.xx.month_narrow.1` through `month_narrow.12`, `locale.xx.month_standalone.1` through `month_standalone.12`, `locale.xx.month_standalone_short.1` through `month_standalone_short.12`, `locale.xx.month_standalone_narrow.1` through `month_standalone_narrow.12`, `locale.xx.quarter.1` through `quarter.4`, `locale.xx.quarter_short.1` through `quarter_short.4`, `locale.xx.quarter_narrow.1` through `quarter_narrow.4`, `locale.xx.quarter_standalone.1` through `quarter_standalone.4`, `locale.xx.quarter_standalone_short.1` through `quarter_standalone_short.4`, `locale.xx.quarter_standalone_narrow.1` through `quarter_standalone_narrow.4`, `locale.xx.day_period.am`/`pm`/`noon`/`midnight`, corresponding `locale.xx.day_period_wide.*` and `locale.xx.day_period_narrow.*` fields, flexible day-period rule keys such as `locale.xx.day_period_rule.morning1 = 04:00-10:00` using half-open `HH:MM-HH:MM` ranges with midnight wraparound support, exact day-period rule keys such as `locale.xx.day_period_exact.morning1 = 06:00`, `locale.xx.weekday.0` through `weekday.6`, `locale.xx.weekday_short.0` through `weekday_short.6`, `locale.xx.weekday_narrow.0` through `weekday_narrow.6`, `locale.xx.weekday_standalone.0` through `weekday_standalone.6`, `locale.xx.weekday_standalone_short.0` through `weekday_standalone_short.6`, and `locale.xx.weekday_standalone_narrow.0` through `weekday_standalone_narrow.6`, `locale.xx.date_style.short`, `locale.xx.time_style.short`, `locale.xx.date_time_style_separator`, `locale.xx.default_calendar`, `locale.xx.default_timezone`, `locale.xx.timezone_display_standard.Example/Zone`, `locale.xx.timezone_display_daylight.Example/Zone`, `locale.xx.timezone_exemplar.Example/Zone`, `locale.xx.timezone_location_pattern`, `locale.xx.timezone_location_pattern_standard`, `locale.xx.timezone_location_pattern_daylight`, `locale.xx.timezone_short.Example/Zone`, `locale.xx.timezone_generic_short.Example/Zone`, currency placement/separator/accounting fields such as `locale.xx.currency_symbol_first`, list pattern fields `locale.xx.list_item_separator`, `locale.xx.list_pair_separator`, `locale.xx.list_start_separator`, `locale.xx.list_middle_separator`, and `locale.xx.list_final_separator`, fixed-zone overrides such as `timezone.Example/Zone.base_offset_minutes` or `timezone.Example/Zone.base_offset_seconds`, bounded transition overrides such as `timezone.Example/Zone.transition.20260101000000 = 3600` and `timezone.Example/Zone.transition.2026-01-01T00:00:00Z = 3600`, currency metadata such as `currency.XTS.symbol`, `currency.XTS.narrow_symbol`, `currency.XTS.display_name.other`, `currency.XTS.minor_units`, and `currency.XTS.cash_increment`, exact non-negative plural overrides such as `plural.cardinal.xx.7 = few` and `plural.ordinal.xx.9 = two`, and known CLDR plural-rule family aliases such as `plural.rule_family.cardinal.xx = ar` and `plural.rule_family.ordinal.xx = en-ordinal`. The loader also accepts checked normalized CLDR import rows produced by the project tooling: `decimal_text`, `group_text`, `digits_codepoints`, `names_hex` month/weekday/quarter name sets, `locale_text|locale|field|hex-bytes`, `currency_text`, `plural_rule|kind|locale|family`, deterministic LDML-style rows, with single-line XML declarations and comments ignored, attribute-only rows single-line and supported attributes accepting optional whitespace around = and single or double quotes and supported element-text rows accepted as bounded multi-line blocks, with standard XML entity references and numeric character references decoded in supported attributes and element text plus CDATA sections accepted in supported element text, and bounded <ldml locale=xx> or <locale id=xx> wrappers providing locale context for child rows that omit locale attributes, exact <ldml> roots deriving locale context from CLDR identity language/script/territory rows, plus known inert CLDR grouping containers around supported leaf rows, including `<symbols ...>` number-symbol attributes for percent, per-mille, signs, exponent, and accounting affixes plus `<day ...>`, `<month ...>, <weekday ...>, and <quarter ...>` including `width="narrow"` rows, `<dayPeriod ...>`, `<dayPeriodRule locale="xx" type="morning1" from="05:00" before="11:00"/>`, `<dayPeriodRule locale="xx" type="midnight" at="00:00"/>`, `<dayPeriodRule locale="xx" type="noon" at="12:00"/>`, `<dayPeriodRuleSet ...>` and `<dayPeriodRules ...>` containers, `<era ...>`, `<eraSeparator ...>`, `<zoneName ...>`, `<timeZoneName ...>`, `<zoneExemplar ...>`, `<exemplarCity ...>`, `<zoneLocationPattern ...>`, `<regionFormat ...>`, `<gmtFormat ...>`, `<gmtZeroFormat ...>`, `<hourFormat ...>`, `<zoneShort ...>`, `<zoneShortStandard ...>`, `<zoneStandardShort ...>`, `<zoneShortDaylight ...>`, `<zoneDaylightShort ...>`, `<zoneGenericShort ...>`, `<zoneShortGeneric ...>`, `<calendarPreference ...>`, `<timeZonePreference ...>`, `<numberingSystemPreference locale="xx" system="arab"/>`, `<hourCyclePreference locale="xx" cycle="h12"/>`, `<weekData locale="xx" firstDay="mon" minDays="4"/>`, `<currencyFormat ...>`, `<currencySpacing ...>`, `<currency ...>`, `<currencySymbol ...>`, `<currencyName ...>`, `<unitName ...>`, `<unitPattern ...>`, `<relativeName ...>`, `<relativePeriod ...>`, `<relativeUnit ...>`, `<relativePattern ...>`, `<relativeTime ...>`, `<relativeTimePattern ...>`, `<listPattern ...>`, and `<listPatternPart ...>` localized display data with `type="2"`, `type="start"`, `type="middle"`, `type="end"`/`type="final"`, or compatibility `type="item"`; `dateTimeFormat` and `dateTimeStyle` rows feed datetime style separators from strict `{1}<separator>{0}` patterns; `dayPeriodRule` rows and CLDR-shaped `dayPeriodRuleSet`/`dayPeriodRules` containers feed flexible `b`/`B` skeleton range selection from direct or inherited `locale`/`locales` attributes, with exact `at="HH:MM"` rows accepted for supported day-period types, `zoneExemplar` and `exemplarCity` rows feed VVV/VVVV exemplar-location output, `zoneLocationPattern` and generic `regionFormat` rows feed non-UTC VVVV generic-location output through `{0}` substitution while standard/daylight `regionFormat` rows feed long `zzzz` fallbacks, `zoneName` and `timeZoneName` rows accept omitted/`long`/`generic` type for long display names, `standard`/`long-standard`/`standardLong` and `daylight`/`long-daylight`/`daylightLong` aliases for long specific `zzzz` output, plus `short`, `standard-short`, `short-standard`, `standardShort`, `shortStandard`, `daylight-short`, `short-daylight`, `daylightShort`, `shortDaylight`, `generic-short`, `short-generic`, `genericShort`, and `shortGeneric` aliases for short `z`/`v` output, `zoneShort`/`zoneShortStandard`/`zoneStandardShort`, `zoneShortDaylight`/`zoneDaylightShort`, and `zoneGenericShort`/`zoneShortGeneric` rows feed short `z`/`v` output, `gmtFormat` rows with prefix-`{0}` patterns, `gmtZeroFormat` rows, and standard `hourFormat` rows feed localized GMT offset prefixes, UTC designators, and hour/minute separators; fixed-offset `timeZone` rows accept `gmtOffset` and `utcOffset` as aliases for `offset` and accept case-insensitive `Z`, `UTC`, `GMT`, `+H`, `+HH`, `+HMM`, `+HHMM`, `+H:MM`, and `+HH:MM` offsets, with matching negative numeric forms, `unitPattern` rows accept exactly one `{0}` placeholder, including reordered patterns, `relativePattern`, `relativeTime`, and `relativeTimePattern` rows without `unit`/`count` split one `{0}` placeholder into deterministic prefix/suffix affixes; rows with `unit` and `count` or `relativeUnit` and `count` feed direct unit/count relative-time patterns with zero or one `{0}` placeholder, and `listPattern`/`listPatternPart` element text may be a raw separator or a strict `{0}<separator>{1}` CLDR pattern. The loader also accepts fixed-offset tzdb Zone/Link rows with case-insensitive Z/UTC/GMT zero offsets plus +H, +HH, +HMM, +HHMM, +H:MM, +HH:MM, and colon-separated second offsets such as +HH:MM:SS offsets, with matching negative numeric forms, bounded fixed-offset Zone continuation rows whose direct SAVE offsets with optional second precision and numeric, last-weekday, and weekday-on-or-before/after Jan-Dec until fields plus wall/standard/UTC until time bases, including normalized `24:00` end-of-day times, feed runtime transition offsets, and bounded numeric-year tzdb Rule rows with second-precision SAVE offsets and min/minimum and max/maximum bounded to 1900..2050 plus numeric, last-weekday, and weekday-on-or-before/after ON days whose UTC, standard-time, wall-time, or default wall-time transition times, including normalized `24:00` end-of-day times, are applied in chronological transition order and carry prior SAVE values across years when materializing runtime offsets for fixed-offset Zone rows even when the Rule rows appear after the Zone reference, and selected `raw|...` rows for Indian grouping, day-month-year order, currency symbol placement, cardinal/ordinal rule-family mappings, and localized currency-name payloads. Runtime transition overrides accept UTC keys in `YYYYMMDDHHMMSS` or `YYYY-MM-DDTHH:MM[:SS]Z` form and signed offset seconds from -86400 through 86400. `raw|day_month_year|xx` feeds date-style ordering, and `raw|symbol_first|xx` feeds currency symbol placement. Loads are transactional: malformed data returns `Invalid_Data` and leaves the previous override set intact. `Clear_Runtime_Data` removes all loaded overrides.

Bounded runtime plural-rule expressions may be loaded as `plural.rule.<kind>.<locale>.<category> = <rule>`, normalized rows `plural_rule_text|kind|locale|category|rule`, or LDML-style `<pluralRule locale="xx" type="cardinal" count="one">n is 1</pluralRule>` rows. CLDR-shaped `plurals` and `pluralRules locales="...">` containers provide inherited cardinal/ordinal kind and space-separated locale lists for child `<pluralRule>` rows. They support operands `n`, `i`, `v`, `w`, `f`, `t`, `c`, and `e`, optional `mod`/`%`, `is`/`is not`/`=`/`!=`/`in`/`not in`/`within`/`not within`, comma-separated values and `A..B` ranges, plus `and`/`or` clauses. The `c` and `e` compact-exponent operands are accepted with deterministic value zero on this runtime path. CLDR sample annotations beginning with `@integer` or `@decimal` are ignored for evaluation. Exact plural-category overrides still take precedence; expression rows are evaluated before generated family fallback.

Currency formatting uses the same locale sign overrides as number formatting for non-accounting negative amounts, so `locale.xx.number_minus_sign` affects `{amount, currency, XXX}` as well as `{value, number}`.

LDML-style `symbols` rows accept CLDR-shaped aliases for number-symbol attributes: `percentSign`, `perMille`, `plusSign`, `minusSign`, and `exponential` feed the same formatter fields as `percent`, `permille`, `plus`, `minus`, and `exponent`. CLDR-shaped `<defaultNumberingSystem>` element text feeds `locale.xx.default_numbering_system`, and non-self-closing `<symbols numberSystem="...">` containers provide number-system context for child `<decimal>`, `<group>`, `<percentSign>`, `<perMille>`, `<plusSign>`, `<minusSign>`, and `<exponential>` rows. Symbol children are applied only for the selected default numbering system, or for `latn` when no default is set; malformed selected rows are rejected transactionally.

LDML-style `unitName`, `unitDisplayName`, `displayName`, and `unitPattern` rows normalize supported ICU unit identifiers such as `length-meter`, `volume-liter`, and `mass-gram`, plus `long`, `short`, and `narrow` width aliases, to the formatter's canonical unit keys; when `unit` is omitted, `type` is treated as the unit identifier. CLDR `<unitLength type="long|short|narrow">` and `<unit type="...">` containers provide inherited width and unit identifiers for child `displayName` and `unitPattern` rows. `unitDisplayName`, `displayName`, and `unitName` rows without `count` feed the `other` unit display slot. `compoundUnitPattern` rows with `type="per"` accept strict `{0}<separator>{1}` text and feed long or short per-unit separators; CLDR `<compoundUnit type="per">` containers and surrounding `unitLength` containers provide inherited type and width for child `compoundUnitPattern` rows.

LDML-style `listPattern` and `listPatternPart` rows accept raw separator text or strict `{0}<separator>{1}` CLDR pattern text for `2`, `start`, `middle`, `end`/`final`, and compatibility `item` parts. Rows without a `listPatternType` attribute feed standard conjunction lists; rows with `listPatternType="or"`/`"disjunction"` or `listPatternType="unit"` feed the matching public list options. CLDR `<listPattern type="standard">`, `<listPattern type="or">`/`<listPattern type="disjunction">`, and `<listPattern type="unit">` containers provide context for child `listPatternPart` rows; unknown list-pattern types are rejected transactionally.

LDML-style `month`, `quarter`, `weekday`, and CLDR `day` rows accept either the compatibility `index` plus text-width `type`, or CLDR-shaped `type` plus `width`. Numeric `type` values feed month and quarter indexes, and weekday or `day` `type` values `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, and `sat` feed the existing weekday index table. Width `narrow` maps to explicit narrow month, weekday, and quarter fields, including stand-alone context when inherited from CLDR `monthContext`, `dayContext`, or `quarterContext` containers. CLDR era-width containers such as `eraAbbr`, `eraNames`, and `eraNarrow` are accepted as inert wrappers around supported `era` leaf rows, and a surrounding `calendar type="..."` container provides the calendar for child era rows that omit `calendar`.

LDML-style `calendar type="..."` containers provide the calendar for child `era` rows that omit `calendar`; `era` and `eraSeparator` rows normalize CLDR-shaped calendar aliases such as `gregory` to `gregorian`, and Gregorian numeric era types `0`/`1` to the existing `bc`/`ad` era keys.

LDML-style locale-preference rows accept CLDR-shaped aliases for existing default-locale fields: `calendarPreference`, `numberingSystemPreference`, and `hourCyclePreference` may use `type`, `calendarPreference` accepts calendar aliases such as `ethioaa`, `islamicc`, `islamic-tbla`, and `iso8601`, and `timeZonePreference` may use `zone` in addition to `id`.

LDML-style `<weekData ...>` rows accept `day` as an alias for `firstDay` and `count` as an alias for `minDays`, feeding the same first-day-of-week and first-week-minimum-days fields. CLDR-shaped non-self-closing `<weekData>` containers may also wrap child `<firstDay day="..."/>` and `<minDays count="..."/>` rows, with locale context inherited from a surrounding `ldml`/`locale` wrapper.

LDML-style time-zone rows accept CLDR-shaped `zone` aliases where an identifier is required: `zoneName`, `timeZoneName`, `zoneExemplar`, `exemplarCity`, `zoneShort`, `zoneShortStandard`, `zoneStandardShort`, `zoneShortDaylight`, `zoneDaylightShort`, `zoneGenericShort`, `zoneShortGeneric`, and fixed-offset `timeZone` rows may use `zone` in addition to `id`. CLDR `<zone type="Area/Name">` containers inside `timeZoneNames` provide the zone identifier for child `exemplarCity`, `generic`, `standard`, and `daylight` rows; surrounding `long` and `short` containers select long display fields or short `z`/`v` fields. `zoneName` and `timeZoneName` rows also accept long standard/daylight type aliases, and `regionFormat type="standard"` or `type="daylight"` feeds the fallback pattern for long specific `zzzz` output.

LDML-style `availableFormat` and `dateFormatItem` rows feed date/time/datetime skeleton resolution from `id` or `skeleton` attributes. `appendItem` rows with `request="Time"` or `request="Timezone"` feed the date-to-time skeleton field separator from strict `{0}<separator>{1}` patterns. Date/time style rows accept `dateStyle` and `timeStyle` aliases in addition to `dateFormat` and `timeFormat`, plus `dateFormatLength` and `timeFormatLength` aliases; all six row forms may use `style` or `length` in addition to `type` for the style name. `dateTimeFormat`, `dateTimeFormatLength`, and `dateTimeStyle` rows accept the same style aliases and feed the datetime style separator from strict `{1}<separator>{0}` patterns. CLDR-shaped `dateFormatLength`/`dateFormat`, `timeFormatLength`/`timeFormat`, and `dateTimeFormatLength`/`dateTimeFormat` containers provide style and kind context for child `<pattern>` rows, with datetime patterns using the same strict `{1}<separator>{0}` extraction.

Representative localized display override keys include `locale.xx.era.gregorian.ad`, `locale.xx.day_period_rule.evening1`, `locale.xx.timezone_display.Example/Zone`, `locale.xx.timezone_display_standard.Example/Zone`, `locale.xx.timezone_display_daylight.Example/Zone`, `locale.xx.timezone_exemplar.Example/Zone`, `locale.xx.timezone_location_pattern`, `locale.xx.timezone_location_pattern_standard`, `locale.xx.timezone_location_pattern_daylight`, `locale.xx.timezone_short.Example/Zone`, `locale.xx.timezone_generic_short.Example/Zone`, `locale.xx.default_timezone`, `locale.xx.gmt_offset_prefix`, `locale.xx.timezone_offset_separator`, `locale.xx.timezone_utc_designator`, `locale.xx.unit.meter.unit-width-full-name.one`, `locale.xx.relative_exact.day.unit-width-full-name.-1`, `locale.xx.relative_current.day`, `locale.xx.relative_unit.day.other`, `locale.xx.relative_prefix.future`, `locale.xx.relative_suffix.future`, `locale.xx.list_pair_separator`, `locale.xx.list_start_separator`, `locale.xx.list_middle_separator`, `locale.xx.list_final_separator`, `locale.xx.list_or_final_separator`, and `locale.xx.list_unit_item_separator`.

LDML-style `<currencyFormat ...>` rows are accepted for locale currency formatting fields. They may set `symbolFirst="true|false"`, `separator="..."`, `accountingPrefix="..."`, and `accountingSuffix="..."`, feeding the same currency placement, spacing, and accounting-affix runtime data as key/value overrides. CLDR-shaped `currencyFormats`, `currencyFormatLength`, and non-self-closing `currencyFormat type="standard|accounting"` containers are accepted around child `<pattern>` rows when the pattern can be represented as currency sign before/after the amount, an optional amount separator, and accounting affixes from a negative subpattern. The CLDR-shaped `<currencySpacing ...>` alias accepts `beforeCurrency="true|false"` and `insertBetween="..."` for the same placement and separator fields, plus the same accounting affix attributes; nested `beforeCurrency` and `afterCurrency` containers provide placement context for child `<insertBetween>` element-text rows and accept bounded `currencyMatch`/`surroundingMatch` metadata rows in that context.

LDML-style `<currency ...>` rows accept CLDR-shaped `type`/`iso4217`, `digits`, `cashRounding`/`rounding`, `narrowSymbol`, and `displayName` aliases for currency code, minor-unit, cash-increment, narrow-symbol, and display-name metadata. CLDR `<currency type="...">` containers provide inherited ISO codes for child `<symbol>` and `<displayName>` rows; child `<displayName>` rows use `count` for plural-category display names with `other` as the default. `<currencySymbol ...>` rows accept `code`/`type`/`iso4217` aliases for the code and use element text for the standard symbol, or for the narrow symbol when `alt="narrow"` is present. `<currencyName ...>` accepts `type`/`iso4217` and `count` aliases for code and plural category, feeding the same localized display-name table as `code`/`category`. `<pluralRule ...>` accepts `kind` as an alias for `type`, `family` for rule-family mappings, `locales` for space-separated locale lists, and `count`/`category` plus element text for bounded plural-rule expressions, including inherited kind/locales from surrounding `plurals` and `pluralRules` containers.

Unit and relative-unit display fields may use any CLDR count suffix: `zero`, `one`, `two`, `few`, `many`, or `other`. LDML-style relative-time rows accept CLDR `duration-*` unit aliases such as `duration-day`, `duration-week`, `duration-month`, `duration-quarter`, and `duration-year`, mapping them to the existing relative formatter unit names. `relativeName`, `relativePeriod`, and `relativeUnit` rows treat `type` as the unit identifier when `unit` is omitted; direct `relativeTime` and `relativeTimePattern` rows may use `relativeUnit` as a unit alias while `type` remains the `future`/`past` direction, and may use `unitWidth` as an alias for `width`. CLDR-shaped `fields` containers may wrap `field type="day|day-short|day-narrow|duration-*"` containers, which provide inherited unit and width for child `relative`, `relativeUnit`, `relativeTime`, and `relativeTimePattern` rows; `relative type="N"` rows feed exact relative-offset text, while non-self-closing `relativeTime type="future|past"` containers provide direction context for child `relativeTimePattern` rows. Unit quantities select the resolved CLDR cardinal category, including visible fractional operands for strict decimal text such as `1.0` and `1.5`.

Runtime RBNF spellout overrides are supported for exact signed values and exact cardinal or ordinal decimals, ignoring a single trailing CLDR rule semicolon in exact text, through key/value rows such as `rbnf.xx.cardinal.2 = two`, `rbnf.xx.cardinal.-2 = minus two`, `rbnf.xx.cardinal.-2.3 = minus two point three`, `rbnf.xx.ordinal.2 = second`, `rbnf.xx.ordinal.-2.3 = minus second point three`, and `rbnf.xx.decimal_separator = point`; bounded rule-composition rows such as `rbnf_rule.xx.cardinal.100 = << hundred[ >>>]`; literal numeric rule rows such as `rbnf_rule.xx.cardinal.13 = thirteen`, which are stored as exact spellout rows; normalized `rbnf_text|locale|kind|value|hex-bytes` and `rbnf_rule_text|locale|kind|base|hex-bytes` rows; and LDML-style `<rbnf ...>`, `<rbnfRule ...>`, or lowercase `<rbnfrule ...>` rows with `value` attributes or CLDR `descriptor: rule` element text. LDML-style rows with element text, including RBNF rows, may be single-line or bounded multi-line blocks with the opening tag, element text, and matching closing tag on separate lines. `rbnfrule` rows may use `ruleSet` or `ruleset` for the rule-set name, CLDR percent-prefixed rule-set names such as `%spellout-cardinal` normalize to the same supported kind, and LDML-style `radix` attributes are normalized to explicit `base/divisor` descriptors. Bounded rule rows support `<<` quotient substitutions, `>>` and `>>>` remainder substitutions, CLDR arrow-glyph equivalents `←←`, `→→`, and `→→→`, named `%...` arrow substitutions, including ASCII `<%...<` and `>%...>` forms, recognized cardinal/ordinal target rule-set names for named quotient, remainder, and equality substitutions such as `=%spellout-ordinal=`, bounded plural-affix expressions such as `$(ordinal,one{st}two{nd}few{rd}other{th})$` and `$(cardinal,one{...}other{...})$`, a single trailing CLDR rule semicolon, and optional `[ ... ]` remainder text for positive integer bases including properly comma-grouped bases such as `2,000`, `base/divisor` descriptors, or CLDR-style trailing `>` divisor markers, `negative`/`-x`/`−x` negative rules, `0.x` zero-integer decimal rules, `x.0` visible-zero-fraction decimal rules, and `x.x`/`decimal` rules; plural-affix expressions are validated at load time and must use a `cardinal` or `ordinal` selector, known CLDR count names, balanced branch braces, and an `other` branch; integer base rules use the CLDR-style default divisor derived from the rule descriptor unless an explicit `base/divisor` descriptor or trailing `>` marker is loaded for quotient and remainder substitution. Spellout kind aliases such as `spellout-cardinal-verbose`, `spellout-cardinal-masculine`, `spellout-ordinal-verbose`, and `spellout-ordinal-feminine` normalize to the same cardinal or ordinal override tables used by number skeleton aliases. Unknown named substitution rule-set names continue to normalize to same-kind bounded substitutions. These rows feed `::spellout` cardinal text, signed integer-part text for negative decimal spellout, `::ordinal-words` exact ordinal text, and the decimal separator word used by strict decimal spellout before built-in deterministic spellout fallback data.

CLDR RBNF containers `rulesetGrouping`, `ruleSetGrouping`, `ruleset`, `ruleSet`, and `rules` are accepted as bounded wrappers around supported RBNF leaf rows. `ruleset` and `ruleSet` containers provide inherited rule-set names for child `<rbnfrule>` rows that omit `type`, `ruleSet`, or `ruleset`.

Generated time-zone display data includes localized `Etc/UTC` long names where CLDR supplies them, in addition to selected fixed-zone, generic-family rows including Lord Howe and fixed Australian eastern, central, central-western, and western zones, and short-family zone rows.

### Key resolution

```ada
type Resolve_Status is (Found, Missing_Key, Runtime_Invalid);
type Resolve_Result is record
   Status : Resolve_Status; ...
end record;
function Resolved_Locale (Item : Resolve_Result) return I18N.Locales.Locale_Id;
function Resolve
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String)
   return Resolve_Result;
```

`Resolve` answers whether a key is reachable through locale fallback without rendering it and without arguments.

### Bounded rendering

```ada
procedure Render_Into
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String;
   Arguments : I18N.Arguments.Arguments;
   Target : in out String; Last : out Natural;
   Status : out I18N.Result.Render_Status);
```

Renders the compiled AST **directly into** caller-owned storage without materializing an intermediate dynamic buffer. On `Success`, `Target (Target'First .. Last)` holds the output. On `Buffer_Overflow`, `Target` holds the prefix that fits and `Last` is the last written index. On any other failure, `Last = 0`.

### Allocation note

Public `Render` returns a structured result containing materialized text and is not specified as a zero-allocation API. `Render_Into` is the public allocation-free path: it writes each rendered fragment straight into the caller's `String` and never builds an `Unbounded_String`. The no-allocation release gate also covers the private fixed-buffer compatibility path used by in-tree regression tests.

### Runtime inspection and cleanup

```ada
function Is_Valid (Item : I18N.Runtime.Runtime) return Boolean;
procedure Finalize (Item : in out I18N.Runtime.Runtime);
```

`Is_Valid` is useful after initialization. `Initialize_Binary_File` accepts the v1.1 binary catalog envelope:

```text
I18N-CATALOG-BINARY
format_version=1
ir_version=1
payload=text

```

The blank line after the header is followed by the canonical text catalog payload. Unsupported magic, format versions, IR versions, and payload kinds are rejected deterministically. `Finalize` clears runtime-owned catalog/message references and does not clear the process-global cache.

`payload=hex-text` is also accepted in the same envelope; the payload body is ASCII hex bytes for the canonical text catalog payload and is decoded before the normal catalog validation/compile path. Malformed hex payloads are rejected deterministically.

The single-message/fixed-buffer APIs are isolated in private child package `I18N.Runtime.Compatibility` for in-tree regression tests only. They are not part of the v1.1.0 application contract and are not directly importable by ordinary downstream units. This private path is where strict fixed-buffer no-allocation checks are performed.

## `I18N.Result`

Frozen status set:

```ada
type Render_Status is
  (Success,
   Missing_Key,
   Missing_Argument,
   Invalid_Argument,
   Formatting_Error,
   Execution_Error,
   Buffer_Overflow,
   Internal_Error);
```

`I18N.Result.Output_Text (Result.Text)` is meaningful only when `Status = Success`. `Render_Result.Diagnostics` may contain additional detail. Public callers do not receive parser nodes, compiler objects, cache internals, IR arrays, or internal error records through this result type.

## `I18N.Arguments`

Public argument map API:

```ada
procedure Set (Args : in out Arguments; Key : String; Value : String);
procedure Set_Integer (Args : in out Arguments; Key : String; Value : Long_Long_Integer);
procedure Set_Natural (Args : in out Arguments; Key : String; Value : Natural);
procedure Set_Boolean (Args : in out Arguments; Key : String; Value : Boolean);
procedure Clear (Args : in out Arguments);
procedure Copy (Source : Arguments; Destination : in out Arguments);
function Has (Args : Arguments; Key : String) return Boolean;
function Get (Args : Arguments; Key : String) return String;
procedure Copy_Value
  (Args     : Arguments;
   Key      : String;
   Target   : out String;
   Last     : out Natural;
   Found    : out Boolean;
   Overflow : out Boolean);
```

Arguments are string-valued and intentionally noncopyable at the Ada type level; pass them by reference, mutate them with `Set`/`Clear`, use `Copy` when an explicit duplicate is needed, and do not rely on whole-object assignment. `Copy_Value` copies a stored value into caller-owned fixed storage and reports missing keys or truncation without allocating. `Set_Integer`/`Set_Natural` write strict decimal text with no `'Image` leading space; `Set_Boolean` writes `true`/`false`. These helpers are deterministic and not locale-aware. Plural and selectordinal selectors are parsed strictly during render; non-offset `plural` accepts strict integer or decimal text and uses CLDR fractional operands `i`, `v`, and `f` for decimal cardinal-category selection, while `selectordinal` and offset plurals require integer selectors. Exact integer branches such as `=0` and `=11` are normalized for duplicate detection and selected before category branches; plural messages may use `offset:N`, which makes category selection and `#` substitution use `selector - N`. Number and currency arguments are supplied as strict decimal text for messages such as `{value, number}`, `{value, number, ::percent}`, `{value, number, ::compact-short}`, `{amount, currency, USD}`, and `{amount, number, ::currency/USD}` and separate-token forms such as `{amount, number, ::currency/CHF precision-currency/cash sign/accounting unit-width/full-name}`. Number formatting applies deterministic locale grouping, decimal separators including comma decimals for `ro`, `lt`, and `sl`, Indian grouping for `hi`, `bn`, and `*-IN`, Arabic-Indic digits for `ar`, Persian digits for `fa`, Thai digits for `th`, Bengali digits for `bn`, and explicit `-u-nu-*` digits for all generated CLDR numeric numbering systems including `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`, supported skeletons for percent, permille, compact/scientific/engineering notation including ICU-style `notation-*`, `notation/*`, and slash-expanded compact aliases such as `::compact/short` and `::notation/compact/short`, with CJK compact 10,000 and 100,000,000 scaling for `ja`, `zh`, and `ko`, precision including `::precision-unlimited`, fraction precision ranges such as `::precision-fraction/0-2`, and significant precision ranges such as `::precision-significant/1-3`, padding, integer-width padding with required-zero stems such as `+000`, `000`, or `*000` and optional-`#` stems such as `+##0`, `##0`, or `*##0`, expanded rounding modes, precision-increment skeletons, and rounding-increment aliases including half-even/half-down/half-ceiling/half-floor/ceiling/floor, sign-display skeletons including `::sign-auto`, `::sign-negative`, `::sign/accounting`, and `::sign-accounting` variants, grouping controls including `::group-min2` plus deterministic `::group-on-aligned` and `::group-thousands` aliases, decimal-display controls, trailing-zero-display controls, and positive integer/decimal scale controls, compound skeleton token lists such as `::percent precision-integer`, and deterministic English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Japanese, Chinese, Korean, Turkish, Swedish, Danish, Norwegian, Finnish, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Catalan, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, and Hebrew `::spellout`/`::spellout-cardinal`/`::spellout-cardinal-verbose`/`::spellout-numbering`/`::spellout-year` and deterministic gendered cardinal aliases for signed whole numbers and strict decimals whose absolute integer part is up to 999,999,999, plus `::ordinal-words`/`::spellout-ordinal`/`::spellout-ordinal-verbose` and deterministic gendered ordinal aliases for signed whole numbers whose absolute value is up to 999,999,999; cardinal decimal spellout preserves visible fraction digits after a localized decimal separator word, negative spellout values render the locale minus sign followed by the localized words, and explicit plus signs are accepted without rendering a plus sign. Currency formatting emits symbols, narrow symbols, generated CLDR 46.1 display names with CLDR plural-category selection for all imported currency-name locales with exact, parent, and default fallback, English display names, standard symbols, narrow symbols, minor-unit metadata, and cash-rounding metadata for the 307-code generated CLDR 46.1 currency table including `ADP`, `AFN`, `XCG`, `VED`, `ZWG`, `ZWL`, `JPY`, `KWD`, and `CLF`, ISO-code unit-width output, accounting negatives, cash rounding, grouping, locale digits/separators, and separate-token currency number skeletons including `standard`, `full-name`, `unit-width-long`, `unit-width/long`, `iso-code`, `unit-width/iso-code`, `precision-currency-standard`, `precision-currency/standard`, `precision-currency-cash`, `precision-currency/cash`, and `sign/accounting`, plus common minor-unit metadata such as zero-minor-unit `JPY`, three-minor-unit `KWD`, and four-minor-unit `CLF`; currency options are written as suffixes such as `{amount, currency, USD/name}`, `{amount, currency, USD/full-name}`, `{amount, currency, CAD/narrow}`, `{amount, currency, USD/unit-width-iso-code}`, `{amount, currency, USD/iso-code}`, `{amount, currency, USD/precision-currency-standard}`, `{amount, currency, USD/accounting}`, `{amount, currency, CHF/cash}`, or `{amount, number, ::currency/USD/accounting}`. Date arguments use strict `YYYY-MM-DD` text or ISO instant text for `{day, date}` with optional `short`, `medium`, `long`, `full`, or `::` skeleton style; supported date skeletons allow apostrophe-quoted literals and fields are `G`, `y`, `Y`, `u`, `U`, `r`, `Q`, `q`, `M`, `L`, `l`, `w`, `W`, `d`, `D`, `F`, `g`, `E`, `e`, and `c`, with common CLDR `availableFormats` skeletons resolved through generated locale data before direct field rendering, numeric local weekday output for `e`/`c` widths 1-2, localized full and abbreviated month/weekday names plus wide and abbreviated quarter names for all 725 imported CLDR 46.1 date locales with exact and parent-locale fallback, runtime/imported narrow month and weekday names for `MMMMM`/`LLLLL` and `EEEEE`/`ccccc` with UTF-8-safe fallback, runtime/imported narrow quarter names for `QQQQQ`/`qqqqq` with numeric fallback, and localized Gregorian era labels. Buddhist calendar year display, Japanese calendar era-year display with localized `ja` era names for Reiwa, Heisei, Showa, Taisho, Meiji, and Keio, ROC/Minguo year display with localized `zh` era names, Julian calendar date conversion, Coptic calendar date conversion, Ethiopic calendar date conversion, Ethiopic Amete Alem calendar year display, tabular Islamic civil, tabular astronomical Islamic, Indian national, arithmetic Persian, and deterministic Hebrew lunisolar calendar date conversion are selected from `-u-ca-buddhist`, `-u-ca-japanese`, `-u-ca-roc`, `-u-ca-julian`, `-u-ca-coptic`, `-u-ca-ethiopic`, `-u-ca-ethioaa`, `-u-ca-islamic-civil`, `-u-ca-islamic`, `-u-ca-islamicc`, `-u-ca-islamic-tbla`, `-u-ca-indian`, `-u-ca-persian`, and `-u-ca-hebrew` locale extensions or supported runtime-data `default_calendar` preferences; `-u-ca-gregory`/`-u-ca-gregorian` explicitly select Gregorian behavior and override runtime defaults, `-u-ca-iso8601` selects Gregorian date conversion with ISO week data, and unsupported calendar extensions are rejected deterministically. Time arguments use strict `HH:MM`, `HH:MM:SS`, or `HH:MM:SS.fraction` local time text or ISO instant text for `{clock, time}` with optional style or `::` skeleton; supported time skeletons allow apostrophe-quoted literals and fields are `a`, `b`, `B`, `h`, `H`, `K`, `k`, `j`, `J`, `C`, `m`, `s`, `S`, `A`, `n`, `N`, `z`, `Z`, `O`, `v`, `V`, `X`, and `x`, including skeleton-selected 12-hour output, source-backed localized AM/PM text for all 725 imported CLDR 46.1 date locales and flexible day periods using source-backed midnight/noon labels where CLDR supplies them, fractional-second and nanosecond fields from parsed fractional seconds, milliseconds and nanoseconds in day, and source-backed zone offset/name forms including short `z` specific abbreviations and short `v` generic labels for built-in DST families, built-in localized generic zone names with English fallback, long GMT offsets, ISO extended offsets, numeric zero `x` offsets, and V-width zone identifiers and location labels. `{instant, datetime, style, zone}` combines date and time output after converting `YYYY-MM-DDTHH:MM[:SS[.fraction]]Z`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH`, `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HHMM`, or `YYYY-MM-DDTHH:MM[:SS[.fraction]]+HH:MM` input, with matching negative offset forms, to a deterministic target zone, and datetime skeletons may combine the supported date and time fields. Supported target zones include `UTC`, `utc`, `Z`, `z`, `GMT`, `gmt`, `Etc/UTC`, `Etc/GMT`, `Zulu`, and UTC aliases, numeric offsets such as `+02`, `+0230`, and `+02:00`, checked IANA tzdb 2026a primary zones, and checked tzdb links such as `US/Eastern`, `Canada/Eastern`, `Mexico/General`, and `Brazil/East`. Instant conversion uses generated seconds-based tzdb transition offsets for 447 primary zones over 1900 through 2050; runtime ingestion of broader external tzdb sources is part of the completion scope, while the current v1.1.0 runtime accepts only the deterministic runtime-data formats documented here. Zone-name skeleton output uses generated source-backed fixed-zone, generic-family, and short-family display rows where present, then deterministic built-in display names and GMT-offset fallbacks. Additional deterministic formatters accept `{seconds, duration}`, `{size, bytes}`, `{distance, unit, kilometer}`, `{distance, number, ::measure-unit/length-kilometer unit-width-short per-measure-unit/duration-hour}`, `{offset, relative, day}`, and `{items, list}` where numeric output honors locale signs, digits, and explicit `-u-nu-*` numbering-system extensions for all generated CLDR numeric systems, byte sizes render deterministic B/KiB/MiB/GiB/TiB/PiB units, unit quantities are strict integer or decimal text, direct unit, relative-time, and measure-unit skeleton aliases include unit-width slash aliases and metric length with British metre/kilometre aliases, area including acre/hectare, volume, mass including tonne, energy including electronvolt, British thermal unit, and US therm, power including horsepower, frequency, pressure, graphics, percent, and selected US customary identifiers including mile, yard, foot, inch, gallon, pound, and ounce, source-backed short/narrow unit symbols and per-unit separators for the expanded list-locale set are generated, and full unit names include source-backed English rows for all supported units, source-backed German rows for the generated German fallback-unit set, source-backed Italian, Portuguese, Dutch, Romanian, Lithuanian, Slovenian, Polish, Czech, Russian, Arabic, Japanese, Chinese, and Korean rows for their generated extended-unit sets, and are localized for `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, and `ko`, generated source-backed full/short/narrow current-period second/minute/hour/day/week/month/quarter/year names and complete nonzero full/short/narrow second/minute/hour/day/week/month/quarter/year future/past plural-category patterns cover all imported CLDR 46.1 date locales where CLDR supplies them, with source-backed offset affixes for `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, `ko`, `tr`, `sv`, `da`, `fi`, `eo`, `vi`, `hu`, `sk`, `no`, `id`, `ms`, `af`, `sw`, and `eu`, source-backed one/other relative unit display rows for `en`, `ro`, `lt`, `sl`, `cs`, `ar`, `tr`, `sv`, `da`, `eo`, `vi`, `hu`, `sk`, `fi`, `no`, `id`, `ms`, `af`, `sw`, `eu`, `ja`, `zh`, and `ko`, with German plural day/month/year display overrides, and list items are pipe-delimited with generated localized CLDR-style two-item/start/middle/final separators for `en`, `de`, `fr`, `es`, `it`, `pt`, `nl`, `ro`, `lt`, `sl`, `pl`, `cs`, `ru`, `ar`, `ja`, `zh`, `ko`, `tr`, `sv`, `da`, `no`, `fi`, `id`, `ms`, `eo`, `vi`, `sw`, `af`, `eu`, `hu`, `sk`, `bg`, `uk`, `fa`, `th`, `hi`, `el`, and `he`, with matching generic item separators for that same source-backed list-locale set. Missing values produce `Missing_Argument`; syntactically invalid numeric, number, currency, date, time, date-time, duration, byte-size, unit, relative-time, or list arguments produce `Invalid_Argument`.

List formatting accepts the default `{items, list}` form plus `{items, list, standard}`, `{items, list, and}`, `{items, list, or}`, `{items, list, disjunction}`, and `{items, list, unit}`. `standard` and `and` use the generated conjunction-list data, `or` and `disjunction` use deterministic disjunction separators with localized built-in final separators for common locales, and `unit` uses item-style separators without a final conjunction.

Date, time, and datetime numeric fields use the same locale digit selection as number formatting, including Arabic, Persian, Thai, Bengali, and explicit `-u-nu-*` numbering-system extensions.

Number precision and increment skeletons also accept slash-style aliases: `::precision/integer`, `::precision/unlimited`, `::precision/fraction/N`, `::precision/fraction/MIN-MAX`, `::precision/significant/N`, `::precision/significant/MIN-MAX`, `::precision/increment/N`, `::rounding/increment/N`, and `::padding/integer/N`.

Number sign and grouping skeletons accept the direct slash-style aliases `::sign/auto`, `::sign/negative`, `::sign/always`, `::sign/except-zero`, `::sign/never`, `::group/off`, `::group/auto`, `::group/min2`, `::group/on-aligned`, and `::group/thousands`; sign-display also accepts hyphenated ICU-style aliases such as `::sign-display-auto`, `::sign-display-negative`, `::sign-display-always`, `::sign-display-except-zero`, `::sign-display-never`, `::sign-display-accounting`, `::sign-display-accounting-always`, and `::sign-display-accounting-except-zero`.

Date skeleton field `r` renders the related Gregorian year from the parsed input date. For non-Gregorian calendar output this can differ from calendar year field `y`, which renders the converted calendar year.

Calendar extension and runtime-data values accept `islamicc` as an alias for the same deterministic tabular Islamic civil conversion used by `islamic` and `islamic-civil`. They also accept `islamic-tbla` as a tabular astronomical Islamic calendar and `iso8601` as a Gregorian-conversion calendar with ISO week data, so `Y`, `w`, and `W` use Monday as the first day and four minimum days in the first week.

Relative-time unit text uses the resolved locale's CLDR cardinal category where deterministic category forms are generated from source-backed rows, including Russian/Ukrainian and Polish `few`/`many` forms for relative-time offsets.

Date skeleton week fields `Y`, `w`, and `W` use generated locale week data by
default. When runtime data provides `locale.xx.first_day_of_week` or
`locale.xx.first_week_min_days`, those explicit week preferences are used for
that locale and its fallback children.

The deterministic `{value, unit, ...}` and `::measure-unit/...` sets also accept `length-metre`, `length-kilometre`, `length-yard`, `length-foot`, `length-inch`, `length-centimeter`/`length-centimetre`, `length-millimeter`/`length-millimetre`, `length-decimeter`/`length-decimetre`, `length-micrometer`/`length-micrometre`, `length-nanometer`/`length-nanometre`, `length-picometer`/`length-picometre`, `length-nautical-mile`, `length-astronomical-unit`, `length-light-year`, `length-parsec`, `length-fathom`, `length-furlong`, `length-pixel`, `length-point`, `length-solar-radius`, `length-earth-radius`, `graphics-dot`, `graphics-megapixel`, `graphics-pixel-per-centimeter`/`graphics-pixel-per-centimetre`, `graphics-pixel-per-inch`, `graphics-dot-per-centimeter`/`graphics-dot-per-centimetre`, `graphics-dot-per-inch`, `volume-milliliter`/`volume-millilitre`, `volume-gallon`, `volume-fluid-ounce`, `volume-cup`, `volume-tablespoon`, `volume-teaspoon`, `volume-pint`, `volume-quart`, `volume-barrel`, `volume-cubic-meter`/`volume-cubic-metre`, `volume-cubic-centimeter`/`volume-cubic-centimetre`, `volume-cubic-inch`, `volume-cubic-foot`, `volume-cubic-yard`, `volume-acre-foot`, `mass-milligram`, `mass-tonne`, `mass-pound`, `mass-ounce`, `mass-stone`, `mass-carat`, `mass-ton`, `mass-dalton`, `mass-earth-mass`, `mass-solar-mass`, `duration-nanosecond`, `duration-microsecond`, `duration-millisecond`, `duration-fortnight`, `duration-quarter`, `duration-decade`, `duration-century`, `area-square-meter`/`area-square-metre`, `area-square-kilometer`/`area-square-kilometre`, `area-square-foot`, `area-square-mile`, `area-square-centimeter`/`area-square-centimetre`, `area-square-inch`, `area-square-yard`, `area-acre`, `area-hectare`, `temperature-celsius`, `temperature-fahrenheit`, `temperature-kelvin`, `angle-degree`, `angle-radian`, `angle-revolution`, `angle-arc-minute`, `angle-arc-second`, `acceleration-g-force`, `acceleration-meter-per-square-second`/`acceleration-metre-per-square-second`, `force-newton`, `force-pound-force`, `torque-newton-meter`/`torque-newton-metre`, `digital-bit`/`digital-byte`/`digital-kilobyte`/`digital-kilobit`/`digital-megabyte`/`digital-gigabyte`/`digital-terabyte`/`digital-terabit`/`digital-megabit`/`digital-gigabit`/`digital-petabyte`/`digital-petabit`/`digital-exabyte`/`digital-exabit`, `speed-kilometer-per-hour`/`speed-kilometre-per-hour`, `speed-mile-per-hour`, `speed-knot`, `speed-beaufort`, `speed-meter-per-second`/`speed-metre-per-second`, `consumption-liter-per-100-kilometer`, `consumption-litre-per-100-kilometre`, `consumption-mile-per-gallon`, `consumption-mile-per-gallon-imperial`, `energy-joule`, `energy-kilojoule`, `energy-calorie`, `energy-kilocalorie`, `energy-kilowatt-hour`, `energy-electronvolt`, `energy-british-thermal-unit`, `energy-therm-us`, `power-watt`, `power-kilowatt`, `power-horsepower`, `frequency-hertz`, `frequency-kilohertz`, `frequency-megahertz`, `pressure-hectopascal`, `pressure-pascal`, `pressure-kilopascal`, `pressure-millibar`, `pressure-bar`, `pressure-atmosphere`, `pressure-inch-ofhg`, `pressure-millimeter-ofhg`, `pressure-pound-force-per-square-inch`, `electric-ampere`, `electric-milliampere`, `electric-volt`, `electric-millivolt`, `electric-ohm`, `light-lumen`, `light-lux`, `light-candela`, `light-solar-luminosity`, `concentr-percent`, `concentr-permille`, `concentr-permillion`, `concentr-portion`, and `concentr-karat`, plus their direct unit-name aliases.

For date, time, and datetime options, `::short`, `::medium`, `::long`, `::full`, `::date-short`, `::date-medium`, `::date-long`, `::date-full`, `::date/short`, `::date/medium`, `::date/long`, `::date/full`, `::time-short`, `::time-medium`, `::time-long`, `::time-full`, `::time/short`, `::time/medium`, `::time/long`, `::time/full`, `::datetime-short`, `::datetime-medium`, `::datetime-long`, `::datetime-full`, `::datetime/short`, `::datetime/medium`, `::datetime/long`, `::datetime/full`, `::dateTime-short`, `::dateTime-medium`, `::dateTime-long`, `::dateTime-full`, `::dateTime/short`, `::dateTime/medium`, `::dateTime/long`, and `::dateTime/full` are accepted as skeleton-style aliases for the corresponding generated style patterns, including the optional target-zone argument. Date style aliases use year-month-day order for built-in `ja`, `zh`, and `ko` locale data.

Time style aliases use localized 12-hour output with AM/PM markers for built-in `ko`; other built-in style aliases use deterministic 24-hour output unless a skeleton requests a 12-hour field.

Time-zone name skeletons use generated source-backed GMT prefixes, offset separators, generic location patterns, and localized `Etc/UTC` long display names for imported CLDR date locales where CLDR supplies them. Fixed-zone display names for the selected built-in fixed-zone set checked by `cldr/raw/coverage.txt` are generated from source-backed CLDR metazone rows where available. Generic-family display names are generated for existing DST family keys plus Lord Howe and fixed Australian eastern, central, central-western, and western zones across imported CLDR date locales where CLDR supplies metazone names, short-family display rows are used where present, and deterministic built-in display names and GMT-offset fallbacks cover other locales and zones.

Date skeleton month and weekday field width 5 renders explicit runtime-data narrow names when present and otherwise falls back without splitting UTF-8 characters; width 6 renders the imported CLDR abbreviated short weekday name.

Date skeleton year fields use width 2 for two-digit years and otherwise honor the requested minimum width, including widths above four such as `yyyyy`.

Time skeleton day-period fields `b` and `B` use source-backed midnight/noon and generated flexible `morning1`/`afternoon1`/`evening1`/`night1` labels where CLDR supplies them. Exact `00:00:00` renders midnight, exact `12:00:00` renders noon, runtime-data `day_period_exact.*` entries may select a supported day-period label at an exact `HH:MM`, and runtime-data `day_period_rule.*` entries may override the flexible ranges with validated half-open `HH:MM-HH:MM` ranges that can wrap midnight. Without loaded rules, other times use stable coarse ranges of 00:01-05:59 night, 06:00-11:59 morning, 12:01-17:59 afternoon, and 18:00-23:59 evening before AM/PM fallback. Width 5 uses explicit runtime-data narrow day-period labels when present, then the abbreviated day-period label as the deterministic narrow fallback.

Runtime data also accepts CLDR-shaped `dayPeriodRuleSet` and `dayPeriodRules` containers around child `dayPeriodRule` rows. `locales` or `locale` on either container provides the locale list for children that omit a direct locale attribute, with the inner `dayPeriodRules` locale list taking precedence. Exact CLDR `at="HH:MM"` rows are accepted for supported day-period types and malformed exact times are rejected transactionally.

Time skeleton preferred-hour fields `j`, `J`, and `C` use 12-hour output for built-in `en` and `ar` locales and 24-hour output for the other built-in locales. `j` and `C` add an implicit localized AM/PM marker for 12-hour locales when no explicit `a`/`b`/`B` field is present; `J` renders the preferred hour without adding a day-period marker.

Time skeleton zone field `O` renders short localized GMT offsets for widths 1-3, including unpadded whole-hour offsets such as `GMT-4`, minute offsets such as `GMT+5:45` or `UTC+5.45` where CLDR supplies that locale data, and `GMT` for zero offset; `OOOO` keeps the long localized GMT form.

Date/time skeleton option parsing treats apostrophe-quoted commas as literal skeleton text, not as the separator before an optional target-zone argument.

Date/time skeleton option scanning also treats apostrophe-quoted braces as literal skeleton text, so quoted `}` characters do not close the message argument.

The deterministic DST-aware named zone set also includes `Europe/Zurich`, `Europe/Vienna`, `Europe/Brussels`, `Europe/Copenhagen`, `Europe/Stockholm`, `Europe/Oslo`, `Europe/Warsaw`, `Europe/Prague`, `Europe/Budapest`, `America/Toronto`, `America/Montreal`, `America/Detroit`, `America/Indiana/Indianapolis`, `America/Kentucky/Louisville`, `America/Nassau`, `America/Winnipeg`, `America/Edmonton`, `America/Boise`, `America/Vancouver`, `America/Tijuana`, `America/Mexico_City` for 1996-2022 historical DST, `America/Sao_Paulo` for 2008-2019 historical DST, `Australia/Sydney`, `Australia/Melbourne`, `Australia/Hobart`, `Australia/Adelaide`, `Asia/Jerusalem`, and `Asia/Tehran` for 2008-2022 historical DST. The deterministic fixed-offset named zone set also includes `Europe/Moscow`, `Europe/Istanbul`, `America/Mexico_City` after 2022, `America/Sao_Paulo` after 2019, `America/Bogota`, `America/Lima`, `America/Argentina/Buenos_Aires`, `Africa/Accra`, `Africa/Abidjan`, `Africa/Algiers`, `Africa/Tunis`, `Africa/Nairobi`, `Africa/Lagos`, `Asia/Yerevan`, `Asia/Tbilisi`, `Asia/Baku`, `Asia/Riyadh`, `Asia/Tehran` after 2022, `Asia/Hong_Kong`, `Asia/Taipei`, `Asia/Kuala_Lumpur`, `Asia/Manila`, `Asia/Bangkok`, `Asia/Jakarta`, `Asia/Ho_Chi_Minh`, `Asia/Karachi`, `Asia/Colombo`, `Asia/Dhaka`, `Asia/Yangon`, `Asia/Tashkent`, `Asia/Kathmandu`, `Asia/Seoul`, `Pacific/Honolulu`, `Australia/Brisbane`, `Australia/Eucla`, `Australia/Perth`, and `Australia/Darwin`.

Currency display-name localization is generated from imported CLDR currency locale files and uses exact locale, parent locale, then default/English fallback. Symbol and ISO-code currency displays render before the amount for `en`, `ar`, `hi`, `bn`, `ja`, `zh`, and `ko`.

## `I18N.Plurals`

```ada
type Plural_Category is (Zero, One, Two, Few, Many, Other);
function Cardinal (Locale : I18N.Locales.Locale_Id; Value : Long_Long_Integer) return Plural_Category;
function Cardinal
  (Locale          : I18N.Locales.Locale_Id;
   Integer_Part    : Long_Long_Integer;
   Fraction_Digits : Natural;
   Fraction_Value  : Long_Long_Integer)
   return Plural_Category;
function Ordinal  (Locale : I18N.Locales.Locale_Id; Value : Long_Long_Integer) return Plural_Category;
```

Total classification of a value into a CLDR plural category. Integer `Cardinal`/`Ordinal` classify whole values with fraction digits zero and consult any process-wide exact plural overrides loaded through `I18N.Runtime` before generated fallback rules. The overloaded `Cardinal` accepts explicit CLDR fractional operands: integer part `i`, visible fraction digit count `v`, and visible fraction value `f`; with `v = 0` it follows the integer path, including overrides. Cardinal and ordinal rule-family mappings are generated from the checked CLDR 46.1 source subset and evaluated by built-in deterministic families. The checked-in tables cover all 219 CLDR cardinal locale IDs and all 104 CLDR ordinal locale IDs from that source, with exact locale matching before parent fallback. Locales outside the generated CLDR set use the root rule (`Other`).

## `I18N.Locales`

```ada
subtype Locale_Id is String;
type Text_Direction is (Left_To_Right, Right_To_Left);
type Collation_Order is (Before, Same, After);
function Canonicalize (Item : Locale_Id) return String;
function Base_Name (Item : Locale_Id) return String;
function Language (Item : Locale_Id) return String;
function Script (Item : Locale_Id) return String;
function Region (Item : Locale_Id) return String;
function Language_Display_Name (Item : Locale_Id) return String;
function Language_Display_Name
  (Item : Locale_Id; Display_Locale : Locale_Id) return String;
function Script_Display_Name (Item : Locale_Id) return String;
function Script_Display_Name
  (Item : Locale_Id; Display_Locale : Locale_Id) return String;
function Region_Display_Name (Item : Locale_Id) return String;
function Region_Display_Name
  (Item : Locale_Id; Display_Locale : Locale_Id) return String;
function Display_Name (Item : Locale_Id) return String;
function Display_Name
  (Item : Locale_Id; Display_Locale : Locale_Id) return String;
function Unicode_Extension (Item : Locale_Id; Key : String) return String;
function To_Lower (Text : String; Locale : Locale_Id := "") return String;
function To_Upper (Text : String; Locale : Locale_Id := "") return String;
function Normalize_NFC (Text : String; Locale : Locale_Id := "") return String;
function Normalize_NFD (Text : String; Locale : Locale_Id := "") return String;
function Transliterate_ASCII (Text : String; Locale : Locale_Id := "") return String;
function Direction (Item : Locale_Id) return Text_Direction;
function Is_Right_To_Left (Item : Locale_Id) return Boolean;
function Maximize (Item : Locale_Id) return String;
function Minimize (Item : Locale_Id) return String;
function Match
  (Available_Locales : String;
   Requested_Ranges  : String;
   Default           : Locale_Id := "") return String;
function Sort_Key (Item : String; Locale : Locale_Id := "") return String;
function Compare
  (Left : String; Right : String; Locale : Locale_Id := "")
  return Collation_Order;
function Equivalent
  (Left : String; Right : String; Locale : Locale_Id := "")
  return Boolean;
function Contains
  (Text : String; Pattern : String; Locale : Locale_Id := "")
  return Boolean;
function Grapheme_Count (Text : String; Locale : Locale_Id := "") return Natural;
function Grapheme_At
  (Text : String; Index : Natural; Locale : Locale_Id := "")
  return String;
function Line_Count (Text : String; Locale : Locale_Id := "") return Natural;
function Line_At
  (Text : String; Index : Natural; Locale : Locale_Id := "")
  return String;
function Sentence_Count (Text : String; Locale : Locale_Id := "") return Natural;
function Sentence_At
  (Text : String; Index : Natural; Locale : Locale_Id := "")
  return String;
function Word_Count (Text : String; Locale : Locale_Id := "") return Natural;
function Word_At
  (Text : String; Index : Natural; Locale : Locale_Id := "")
  return String;
function Parent (Item : Locale_Id) return String;
```

Locale identifiers are treated as hyphen-separated identifiers. Catalog ingest
and public `Render`/`Resolve` lookup canonicalize ASCII language, script,
region, and extension casing and apply deterministic CLDR language aliases such
as `iw -> he`, `in -> id`, `ji -> yi`, and `sh -> sr-Latn` before walking
fallback. `Canonicalize` exposes the same deterministic normalization used by
the runtime. `Base_Name` strips BCP-47 extension subtags after canonicalization,
`Language`, `Script`, and `Region` expose canonical locale components from the
base locale, returning empty text when the component is absent.
`Language_Display_Name`, `Script_Display_Name`, `Region_Display_Name`, and
`Display_Name` provide deterministic display names for common subtags used by
the built-in locale matrix, falling back to English and then the canonical code
for unknown values. One-argument forms return English names; two-argument forms
use the requested display locale where a built-in table exists. German,
French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Russian, Turkish, Swedish, Danish, Finnish, Norwegian, Indonesian, Malay, Esperanto, Vietnamese, Swahili, Afrikaans, Basque, Romanian, Lithuanian, Slovenian, Hungarian, Slovak, Bulgarian, Ukrainian, Arabic, Persian, Thai, Hindi, Greek, Hebrew, Catalan, Japanese, Chinese, Korean, Bengali, Azerbaijani, Urdu, Yiddish, Serbian, Pashto, Sindhi, and Uyghur display names are built in for common subtags. For example, `Display_Name
("sr-Latn-RS")` returns `"Serbian (Latin, Serbia)"`, while `Display_Name
("sr-Latn-RS", "de")` returns `"Serbisch (Lateinisch, Serbien)"`.
`Unicode_Extension` returns values from the Unicode `-u-` extension, such as
`"thai"` for key `nu` in `en-US-u-nu-thai`; a present boolean key returns
`"true"`, while absent or malformed keys return the empty string. `To_Lower`
and `To_Upper` expose bounded deterministic locale-sensitive case transforms:
ASCII, Turkish/Azeri dotted-I tailoring, German sharp-s uppercase expansion,
and common Latin, Greek including common tonos/dialytika vowels, bounded
dialytika-tonos uppercase expansion, and bounded final-sigma lowercase
context, Cyrillic, Armenian, and Georgian Mtavruli/Mkhedruli plus
Asomtavruli/Nuskhuri UTF-8 case pairs are mapped while
unknown bytes are preserved. Full Unicode case mapping is part of the completion
scope; the current v1.1.0 implementation is the deterministic bounded behavior
described here. `Normalize_NFC` and `Normalize_NFD` expose
bounded canonical composition/decomposition for common Latin letters with
grave, acute, circumflex, tilde, macron, breve, dot-above, diaeresis, ring,
caron, cedilla, ogonek, and horn marks while
preserving unknown sequences, including additional Latin Extended acute and
cedilla pairs, dot-below, base/tone-marked horn, circumflex/breve tone vowel
pairs, and bounded Greek tonos/dialytika vowels. Full Unicode normalization is
part of the completion scope; the current v1.1.0 implementation is the
deterministic bounded behavior described here. `Transliterate_ASCII` exposes bounded deterministic ASCII
transliteration for common Latin and Latin Extended letters plus Latin alphabetic presentation ligatures and fullwidth Latin letters/digits including dot-below, base/tone-marked horn, and circumflex/breve tone vowels, German sharp-s,
bounded Greek letters including common tonos/dialytika and dialytika-tonos vowels, and bounded Cyrillic, Arabic, Persian Arabic-script letters, Arabic presentation forms-B plus selected single-letter and U+FBEA..U+FDF9 multi-letter ligature presentation forms-A, Armenian, Hebrew letters and alphabetic presentation forms, and Georgian Mkhedruli/Mtavruli plus Asomtavruli/Nuskhuri letters while preserving unknown
bytes. Full transliteration is part of the completion scope; the current v1.1.0
implementation is the deterministic bounded behavior described here. `Direction`
and `Is_Right_To_Left` expose deterministic locale text direction from explicit
RTL script subtags such as `Arab`, `Hebr`, `Thaa`, `Nkoo`, `Adlm`, `Rohg`,
`Syrc`, and `Mand`, plus built-in RTL language families such as Arabic,
Persian, Hebrew, Urdu, Yiddish, Pashto, Sindhi, and Uyghur; other locales
default to left-to-right. `Maximize` and
`Minimize` expose bounded CLDR-style likely-subtag
helpers for common language/script/region families such as `en`, `zh`, `sr`,
`ar`, `he`, `hi`, `ja`, `ko`, `ru`, `th`, and the main Latin-script locales.
For example, `Maximize ("zh-HK")` returns `"zh-Hant-HK"`, and `Minimize
("en-Latn-US")` returns `"en"`. `Parent ("de-AT")` returns `"de"`; `Parent
("de")` returns the empty string. `Match` selects the best canonical locale
from a comma-separated available-locale list and an Accept-Language-style
requested range list with optional `q` weights. It evaluates exact canonical
matches, likely-subtag matches, parent fallback in both directions, wildcard
matches, and deterministic input-order ties; for example `Match ("en, fr",
"fr-CA, en;q=0.5")` returns `"fr"`.

`Sort_Key`, `Compare`, `Equivalent`, and `Contains` expose bounded
deterministic public collation helpers. The primary sort key lowercases ASCII,
folds common Latin and Latin Extended letters plus Latin alphabetic presentation
ligatures, tailors German
`ä`/`ö`/`ü`/`ß` as `ae`/`oe`/`ue`/`ss`, places Swedish/Danish/Norwegian
`å`/`ä`/`æ`/`ö`/`ø` after `z`, handles bounded Czech/Slovak `ch` and South
Slavic Latin `dž`/`lj`/`nj` contractions, folds bounded Greek case plus common
tonos/dialytika vowels, Cyrillic, Armenian, and Georgian case, elides bounded
Latin, Arabic, Hebrew, Syriac, Thaana, NKo, Samaritan, Mandaic, U+1AB0..U+1AFF, U+1DC0..U+1DFF,
U+20D0..U+20FF, and U+FE20..U+FE2F combining marks,
folds assigned Hebrew alphabetic presentation forms to base Hebrew letter
keys, Arabic presentation forms-B, and selected single-letter plus
U+FBEA..U+FDF9 multi-letter ligature presentation forms-A to base Arabic letter keys,
consumes unhandled two-byte UTF-8 elements plus bounded
three-byte Samaritan, Mandaic, Ogham, Runic, Cherokee, Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le, New Tai Lue, Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari, Bengali, Thai, Ethiopic, Hiragana, Katakana, halfwidth Katakana compatibility forms, Han, and
Hangul syllable elements, plus bounded four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Linear B, Aegean Numbers, Lycian, Carian, Old Italic, Gothic, Old Permic, Ugaritic, Old Persian, Deseret, Shavian, Osmanya, Osage, Elbasan, Caucasian Albanian, Cypriot, Imperial Aramaic, Palmyrene, Phoenician, Lydian, Sidetic, Meroitic Hieroglyphs, Meroitic Cursive, Nabataean, Hatran, Kharoshthi, Old South Arabian, Old North Arabian, Manichaean, Avestan, Inscriptional Parthian, Inscriptional Pahlavi, Psalter Pahlavi, Old Turkic, Old Hungarian, Garay, Rumi Numeral Symbols, Vithkuqi, Todhri, Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur, Chorasmian, Elymaic, Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra, Dives Akuru, Nandinagari, Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen, Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema, Tangsa, Kirat Rai, Tangut, Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto, Ol Onal, Tai Yo, Nag Mundari, and Adlam elements as stable byte-key units, enables
bounded numeric ordering for ASCII, Arabic-Indic, extended Arabic-Indic,
Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu, Kannada,
Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer, NKo, fullwidth Latin letters/digits, Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, and Han
decimal digit runs when `-u-kn-true` is present,
and uses raw byte order as a deterministic comparison tie-break.
`Equivalent` compares only the primary keys, so accented and tailored forms can
match even when `Compare` would break the tie by raw bytes. `Contains` searches
the primary keys and treats an empty pattern as present. These helpers are
intended for stable UI ordering and search over common multilingual text. Full
Unicode Collation Algorithm behavior is part of the completion scope; the
current v1.1.0 implementation is the deterministic bounded behavior described
here.
`Grapheme_Count` and `Grapheme_At` expose bounded grapheme-like cluster
segmentation for UTF-8 code points with bounded combining marks including
U+1AB0..U+1AFF, U+1DC0..U+1DFF, U+20D0..U+20FF, U+FE20..U+FE2F,
and bounded Hebrew, Syriac, Thaana, NKo, Samaritan, and Mandaic marks, bounded
South/Southeast Asian dependent vowel, virama, and tone marks, variation
selectors including U+FE00..U+FE0F and U+E0100..U+E01EF, emoji keycap marks,
emoji skin-tone modifiers, emoji tag sequences, bounded Unicode Prepend
characters, Myanmar spacing vowel marks,
regional indicator flag pairs, simple zero-width-joiner sequences, bounded
Hangul Jamo L/V/T sequences, and CRLF pairs while preserving
original bytes.
ASCII control characters and bounded Unicode C1 controls remain standalone clusters.
Malformed bytes are counted as single-byte clusters. Full UAX #29 grapheme segmentation is part of the
completion scope; the current v1.1.0 implementation is the deterministic
bounded behavior described here.
`Line_Count` and `Line_At` expose bounded hard-line segmentation for LF, CR,
CRLF, vertical tab, form feed, Unicode next-line (NEL), Unicode line separator, and Unicode
paragraph separator breaks. Returned line segments preserve the terminating break bytes
when present; empty text has
zero lines and a final trailing break does not add an extra empty line. Full
UAX #14 line-break and line-wrapping behavior is part of the completion scope;
the current v1.1.0 implementation is the deterministic bounded behavior
described here.
`Sentence_Count` and `Sentence_At` expose bounded sentence segmentation after
ASCII `.`, `!`, and `?`, Unicode ellipsis, plus Arabic, Greek, and Ethiopic
question marks, Armenian full stop, Hebrew sof pasuq, Georgian paragraph
separator, Devanagari danda, Ethiopic full stop, Myanmar section signs, CJK ideographic full stop, and
fullwidth exclamation/question terminators.
Closing quotes/brackets immediately after a terminator stay in the returned
sentence, including bounded CJK and fullwidth closing punctuation, and
bounded ASCII/Unicode separator whitespace before the next sentence is
excluded. ASCII periods between bounded
ASCII, Arabic-Indic, extended Arabic-Indic, Devanagari, Bengali, Thai,
Gurmukhi, Gujarati, Odia, Tamil, Telugu, Kannada, Malayalam, Sinhala, Lao,
Tibetan, Khmer, NKo, fullwidth Latin letters/digits, Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai, Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digits stay inside numeric
text.
Full UAX #29 sentence segmentation is part of the completion scope; the current
v1.1.0 implementation is the deterministic bounded behavior described here.
`Word_Count` and `Word_At` expose bounded word segmentation for ASCII
letters/digits; bounded Arabic-Indic, extended Arabic-Indic, Devanagari,
Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu, Kannada, Malayalam, Sinhala,
Thai, Lao, Tibetan, Khmer, NKo, fullwidth Latin letters/digits, Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai, Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digits; bounded two-byte Latin, Greek, Cyrillic, Armenian, Hebrew,
Arabic-range, Syriac, Thaana, and NKo UTF-8 elements plus bounded combining marks including
U+1AB0..U+1AFF, U+1DC0..U+1DFF, U+20D0..U+20FF, U+FE20..U+FE2F,
and bounded Hebrew, Syriac, Thaana, NKo, Samaritan, and Mandaic marks, bounded
three-byte Samaritan, Mandaic, Ogham, Runic, Cherokee, Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le, New Tai Lue, Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil, Telugu,
Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer, Georgian, Ethiopic,
Hiragana, Katakana, halfwidth Katakana compatibility forms, Hangul compatibility Jamo, Han, and Hangul syllable elements, plus bounded four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Linear B, Aegean Numbers, Lycian, Carian, Old Italic, Gothic, Old Permic, Ugaritic, Old Persian, Deseret, Shavian, Osmanya, Osage, Elbasan, Caucasian Albanian, Cypriot, Imperial Aramaic, Palmyrene, Phoenician, Lydian, Sidetic, Meroitic Hieroglyphs, Meroitic Cursive, Nabataean, Hatran, Kharoshthi, Old South Arabian, Old North Arabian, Manichaean, Avestan, Inscriptional Parthian, Inscriptional Pahlavi, Psalter Pahlavi, Old Turkic, Old Hungarian, Garay, Rumi Numeral Symbols, Vithkuqi, Todhri, Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur, Chorasmian, Elymaic, Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra, Dives Akuru, Nandinagari, Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen, Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema, Tangsa, Kirat Rai, Tangut, Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto, Ol Onal, Tai Yo, Nag Mundari, and Adlam elements, and bounded halfwidth Katakana, Hangul compatibility Jamo, fullwidth Latin, and Latin/Hebrew/Arabic presentation forms. Apostrophes, right
apostrophes, hyphens, and underscores connect words only when followed by
another word element, while ASCII `.`, `,`, and `:`, plus Arabic
decimal/thousands separators U+066B and U+066C, connect numeric word parts
only when bounded decimal digits appear on both sides. Punctuation, spacing, symbols, and unsupported bytes
otherwise separate words.
`Word_At` uses 1-based indexes, returns empty text for zero or out-of-range
indexes, and preserves the original UTF-8 bytes from the source text. These
helpers are deterministic public conveniences for common multilingual text.
Full UAX #29 word-boundary behavior is part of the completion scope; the
current v1.1.0 implementation is the deterministic bounded behavior described
here.

## `I18N.Diagnostics`

Diagnostics are fixed-storage structures used to report optional detail without affecting correctness. They are safe to ignore. The callback and diagnostic list APIs are observational; rendering correctness must not depend on them.

```ada
procedure Set_Trace_Callback
  (CB : I18N.Diagnostics.Trace_Callback);
```

Passing `null` disables tracing. Callback exceptions are caught by the diagnostics layer and do not escape into render.

## Public example imports

A valid v1.1.0 application example should need only:

```ada
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;
```

It may additionally `with I18N.Diagnostics` or `I18N.Locales` when it needs those names explicitly.

See also `docs/PUBLIC_IMPORT_RULES.md` for the exact Ada import boundary.
