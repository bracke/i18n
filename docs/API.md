# Public API

For the ICU message-formatting API (catalog runtime, render results, message
arguments, and diagnostics), see the `messages` crate's docs/API.md.

This document describes the v1.1.0 application-facing platform API. Packages not listed here are implementation details or regression-test support and are outside the v1.1.0 source-compatibility promise.

## Public packages

Stable public packages:

* `I18N` — root platform package
* Unicode text algorithms: `I18N.Normalization`, `I18N.Casing`, `I18N.Segmentation`, `I18N.Collation`, `I18N.Transliteration`
* CLDR formatters: `I18N.Number_Format`, `I18N.Currency`, `I18N.Date_Time_Format`, `I18N.Calendars`, `I18N.Calendar_Math`, `I18N.Spellout`, `I18N.Display_Names`, `I18N.Emoji`, `I18N.Measurement`, `I18N.Delimiters`, `I18N.Person_Names`
* Locale identity: `I18N.Locales`
* Plural classification: `I18N.Plurals`

Many of the most common Unicode text-algorithm entry points (case transforms,
normalization, transliteration, collation, and segmentation) are also exposed as
locale-parameterized convenience functions on `I18N.Locales`; see that section.

The data layer — `I18N.Data_Store`, `I18N.Runtime_Data`, and the generated
`I18N.CLDR_Data` boundary — is consumed internally by the formatters. Runtime-data
overrides are loadable, but the generated CLDR data package itself is a private
Ada child package that ordinary application code cannot legally `with`.

## Runtime data overrides (`I18N.Runtime_Data`)

`I18N.Runtime_Data` installs process-wide deterministic runtime-data overrides before generated CLDR/tzdb fallback data. (The `messages` crate re-exposes these loaders to message callers as `Messages.Runtime.Load_Data_Text`/`Load_Data_File`/`Clear_Runtime_Data`.) The key/value line format is `key = value`. Supported keys are locale overrides such as `locale.xx.decimal_separator`, `locale.xx.group_separator`, `locale.xx.number_percent_suffix`, `locale.xx.number_permille_suffix`, `locale.xx.number_plus_sign`, `locale.xx.number_minus_sign`, `locale.xx.number_exponent_separator`, `locale.xx.number_accounting_prefix`, `locale.xx.number_accounting_suffix`, `locale.xx.uses_indian_grouping`, `locale.xx.uses_day_month_year`, `locale.xx.digit.0` through `digit.9`, `locale.xx.default_numbering_system` for generated CLDR numeric numbering systems such as `latn`, `arab`, `arabext`, `thai`, `deva`, `beng`, `fullwide`, `mymr`, and `hanidec`, `locale.xx.default_hour_cycle` for `h11`, `h12`, `h23`, or `h24`, `locale.xx.first_day_of_week` for `sun`, `mon`, `tue`, `wed`, `thu`, `fri`, or `sat`, `locale.xx.first_week_min_days` from `1` through `7`, `locale.xx.month.1` through `month.12`, `locale.xx.month_short.1` through `month_short.12`, `locale.xx.month_narrow.1` through `month_narrow.12`, `locale.xx.month_standalone.1` through `month_standalone.12`, `locale.xx.month_standalone_short.1` through `month_standalone_short.12`, `locale.xx.month_standalone_narrow.1` through `month_standalone_narrow.12`, `locale.xx.quarter.1` through `quarter.4`, `locale.xx.quarter_short.1` through `quarter_short.4`, `locale.xx.quarter_narrow.1` through `quarter_narrow.4`, `locale.xx.quarter_standalone.1` through `quarter_standalone.4`, `locale.xx.quarter_standalone_short.1` through `quarter_standalone_short.4`, `locale.xx.quarter_standalone_narrow.1` through `quarter_standalone_narrow.4`, `locale.xx.day_period.am`/`pm`/`noon`/`midnight`, corresponding `locale.xx.day_period_wide.*` and `locale.xx.day_period_narrow.*` fields, flexible day-period rule keys such as `locale.xx.day_period_rule.morning1 = 04:00-10:00` using half-open `HH:MM-HH:MM` ranges with midnight wraparound support, exact day-period rule keys such as `locale.xx.day_period_exact.morning1 = 06:00`, `locale.xx.weekday.0` through `weekday.6`, `locale.xx.weekday_short.0` through `weekday_short.6`, `locale.xx.weekday_narrow.0` through `weekday_narrow.6`, `locale.xx.weekday_standalone.0` through `weekday_standalone.6`, `locale.xx.weekday_standalone_short.0` through `weekday_standalone_short.6`, and `locale.xx.weekday_standalone_narrow.0` through `weekday_standalone_narrow.6`, `locale.xx.date_style.short`, `locale.xx.time_style.short`, `locale.xx.date_time_style_separator`, `locale.xx.default_calendar`, `locale.xx.default_timezone`, `locale.xx.timezone_display_standard.Example/Zone`, `locale.xx.timezone_display_daylight.Example/Zone`, `locale.xx.timezone_exemplar.Example/Zone`, `locale.xx.timezone_location_pattern`, `locale.xx.timezone_location_pattern_standard`, `locale.xx.timezone_location_pattern_daylight`, `locale.xx.timezone_short.Example/Zone`, `locale.xx.timezone_generic_short.Example/Zone`, currency placement/separator/accounting fields such as `locale.xx.currency_symbol_first`, list pattern fields `locale.xx.list_item_separator`, `locale.xx.list_pair_separator`, `locale.xx.list_start_separator`, `locale.xx.list_middle_separator`, and `locale.xx.list_final_separator`, fixed-zone overrides such as `timezone.Example/Zone.base_offset_minutes` or `timezone.Example/Zone.base_offset_seconds`, bounded transition overrides such as `timezone.Example/Zone.transition.20260101000000 = 3600` and `timezone.Example/Zone.transition.2026-01-01T00:00:00Z = 3600`, currency metadata such as `currency.XTS.symbol`, `currency.XTS.narrow_symbol`, `currency.XTS.display_name.other`, `currency.XTS.minor_units`, and `currency.XTS.cash_increment`, exact non-negative plural overrides such as `plural.cardinal.xx.7 = few` and `plural.ordinal.xx.9 = two`, and known CLDR plural-rule family aliases such as `plural.rule_family.cardinal.xx = ar` and `plural.rule_family.ordinal.xx = en-ordinal`. The loader also accepts checked normalized CLDR import rows produced by the project tooling: `decimal_text`, `group_text`, `digits_codepoints`, `names_hex` month/weekday/quarter name sets, `locale_text|locale|field|hex-bytes`, `currency_text`, `plural_rule|kind|locale|family`, deterministic LDML-style rows, with single-line XML declarations and comments ignored, attribute-only rows single-line and supported attributes accepting optional whitespace around = and single or double quotes and supported element-text rows accepted as bounded multi-line blocks, with standard XML entity references and numeric character references decoded in supported attributes and element text plus CDATA sections accepted in supported element text, and bounded <ldml locale=xx> or <locale id=xx> wrappers providing locale context for child rows that omit locale attributes, exact <ldml> roots deriving locale context from CLDR identity language/script/territory rows, plus known inert CLDR grouping containers around supported leaf rows, including `<symbols ...>` number-symbol attributes for percent, per-mille, signs, exponent, and accounting affixes plus `<day ...>`, `<month ...>, <weekday ...>, and <quarter ...>` including `width="narrow"` rows, `<dayPeriod ...>`, `<dayPeriodRule locale="xx" type="morning1" from="05:00" before="11:00"/>`, `<dayPeriodRule locale="xx" type="midnight" at="00:00"/>`, `<dayPeriodRule locale="xx" type="noon" at="12:00"/>`, `<dayPeriodRuleSet ...>` and `<dayPeriodRules ...>` containers, `<era ...>`, `<eraSeparator ...>`, `<zoneName ...>`, `<timeZoneName ...>`, `<zoneExemplar ...>`, `<exemplarCity ...>`, `<zoneLocationPattern ...>`, `<regionFormat ...>`, `<gmtFormat ...>`, `<gmtZeroFormat ...>`, `<hourFormat ...>`, `<zoneShort ...>`, `<zoneShortStandard ...>`, `<zoneStandardShort ...>`, `<zoneShortDaylight ...>`, `<zoneDaylightShort ...>`, `<zoneGenericShort ...>`, `<zoneShortGeneric ...>`, `<calendarPreference ...>`, `<timeZonePreference ...>`, `<numberingSystemPreference locale="xx" system="arab"/>`, `<hourCyclePreference locale="xx" cycle="h12"/>`, `<weekData locale="xx" firstDay="mon" minDays="4"/>`, `<currencyFormat ...>`, `<currencySpacing ...>`, `<currency ...>`, `<currencySymbol ...>`, `<currencyName ...>`, `<unitName ...>`, `<unitPattern ...>`, `<relativeName ...>`, `<relativePeriod ...>`, `<relativeUnit ...>`, `<relativePattern ...>`, `<relativeTime ...>`, `<relativeTimePattern ...>`, `<listPattern ...>`, and `<listPatternPart ...>` localized display data with `type="2"`, `type="start"`, `type="middle"`, `type="end"`/`type="final"`, or compatibility `type="item"`; `dateTimeFormat` and `dateTimeStyle` rows feed datetime style separators from strict `{1}<separator>{0}` patterns; `dayPeriodRule` rows and CLDR-shaped `dayPeriodRuleSet`/`dayPeriodRules` containers feed flexible `b`/`B` skeleton range selection from direct or inherited `locale`/`locales` attributes, with exact `at="HH:MM"` rows accepted for supported day-period types, `zoneExemplar` and `exemplarCity` rows feed VVV/VVVV exemplar-location output, `zoneLocationPattern` and generic `regionFormat` rows feed non-UTC VVVV generic-location output through `{0}` substitution while standard/daylight `regionFormat` rows feed long `zzzz` fallbacks, `zoneName` and `timeZoneName` rows accept omitted/`long`/`generic` type for long display names, `standard`/`long-standard`/`standardLong` and `daylight`/`long-daylight`/`daylightLong` aliases for long specific `zzzz` output, plus `short`, `standard-short`, `short-standard`, `standardShort`, `shortStandard`, `daylight-short`, `short-daylight`, `daylightShort`, `shortDaylight`, `generic-short`, `short-generic`, `genericShort`, and `shortGeneric` aliases for short `z`/`v` output, `zoneShort`/`zoneShortStandard`/`zoneStandardShort`, `zoneShortDaylight`/`zoneDaylightShort`, and `zoneGenericShort`/`zoneShortGeneric` rows feed short `z`/`v` output, `gmtFormat` rows with prefix-`{0}` patterns, `gmtZeroFormat` rows, and standard `hourFormat` rows feed localized GMT offset prefixes, UTC designators, and hour/minute separators; fixed-offset `timeZone` rows accept `gmtOffset` and `utcOffset` as aliases for `offset` and accept case-insensitive `Z`, `UTC`, `GMT`, `+H`, `+HH`, `+HMM`, `+HHMM`, `+H:MM`, and `+HH:MM` offsets, with matching negative numeric forms, `unitPattern` rows accept exactly one `{0}` placeholder, including reordered patterns, `relativePattern`, `relativeTime`, and `relativeTimePattern` rows without `unit`/`count` split one `{0}` placeholder into deterministic prefix/suffix affixes; rows with `unit` and `count` or `relativeUnit` and `count` feed direct unit/count relative-time patterns with zero or one `{0}` placeholder, and `listPattern`/`listPatternPart` element text may be a raw separator or a strict `{0}<separator>{1}` CLDR pattern. The loader also accepts fixed-offset tzdb Zone/Link rows with case-insensitive Z/UTC/GMT zero offsets plus +H, +HH, +HMM, +HHMM, +H:MM, +HH:MM, and colon-separated second offsets such as +HH:MM:SS offsets, with matching negative numeric forms, bounded fixed-offset Zone continuation rows whose direct SAVE offsets with optional second precision and numeric, last-weekday, and weekday-on-or-before/after Jan-Dec until fields plus wall/standard/UTC until time bases, including normalized `24:00` end-of-day times, feed runtime transition offsets, and bounded numeric-year tzdb Rule rows with second-precision SAVE offsets and min/minimum and max/maximum bounded to 1900..2050 plus numeric, last-weekday, and weekday-on-or-before/after ON days whose UTC, standard-time, wall-time, or default wall-time transition times, including normalized `24:00` end-of-day times, are applied in chronological transition order and carry prior SAVE values across years when materializing runtime offsets for fixed-offset Zone rows even when the Rule rows appear after the Zone reference, and selected `raw|...` rows for Indian grouping, day-month-year order, currency symbol placement, cardinal/ordinal rule-family mappings, and localized currency-name payloads. Runtime transition overrides accept UTC keys in `YYYYMMDDHHMMSS` or `YYYY-MM-DDTHH:MM[:SS]Z` form and signed offset seconds from -86400 through 86400. `raw|day_month_year|xx` feeds date-style ordering, and `raw|symbol_first|xx` feeds currency symbol placement. Loads are transactional: malformed data returns `Invalid_Data` and leaves the previous override set intact. `Clear` removes all loaded overrides.

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

The centralized CLDR data image behind these overrides is the generated
`I18N.CLDR_Data` boundary; see docs/ARCHITECTURE.md for the data pipeline, and
docs/ICU_SUBSET.md for the full override key grammar with worked examples.

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

Total classification of a value into a CLDR plural category. Integer `Cardinal`/`Ordinal` classify whole values with fraction digits zero and consult any process-wide exact plural overrides loaded through `I18N.Runtime_Data` before generated fallback rules. The overloaded `Cardinal` accepts explicit CLDR fractional operands: integer part `i`, visible fraction digit count `v`, and visible fraction value `f`; with `v = 0` it follows the integer path, including overrides. Cardinal and ordinal rule-family mappings are generated from the checked CLDR 46.1 source subset and evaluated by built-in deterministic families. The checked-in tables cover all 219 CLDR cardinal locale IDs and all 104 CLDR ordinal locale IDs from that source, with exact locale matching before parent fallback. Locales outside the generated CLDR set use the root rule (`Other`).

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
regional indicator flag pairs, multi-code-point zero-width-joiner sequences, bounded
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
