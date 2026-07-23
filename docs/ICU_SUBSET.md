# ICU Subset

For the ICU message-syntax subset (how these formatters are reached through
`{argument, type, options}` placeholders, plus the plural/select/selectordinal
message constructs), see the `messages` crate's docs/ICU_SUBSET.md.

The i18n platform (v1.1.0) implements a deliberately small, deterministic subset
of the Unicode text algorithms and CLDR formatters. This document summarizes the
supported subset for each engine and specifies the runtime-data override grammar
that feeds them.

## Text-algorithm subset (transform, collation, normalization, segmentation, casing)

The bounded Unicode text-algorithm subset is documented in full with the public
entry points on `I18N.Locales` in docs/API.md:

* casing — `To_Lower`/`To_Upper`: ASCII, Turkish/Azeri dotted-I, German sharp-s,
  and bounded Latin/Greek/Cyrillic/Armenian/Georgian case pairs;
* normalization — `Normalize_NFC`/`Normalize_NFD`: bounded canonical
  composition/decomposition for common Latin and Greek marks;
* transliteration — `Transliterate_ASCII`: bounded Latin/Greek/Cyrillic/Arabic/
  Hebrew/Armenian/Georgian to ASCII;
* collation — `Sort_Key`/`Compare`/`Equivalent`/`Contains`: bounded primary-key
  folding, locale tailorings, and `-u-kn-true` numeric ordering;
* segmentation — `Grapheme_*`/`Word_*`/`Sentence_*`/`Line_*`: bounded UAX #29 /
  UAX #14 cluster, word, sentence, and hard-line segmentation.

In every case the current v1.1.0 behavior is the deterministic bounded subset
described in docs/API.md; full UAX/UCA behavior is part of the completion scope.

## CLDR formatter subset

The CLDR formatters accept a deterministic subset of ICU skeletons, options, and
field sets. The exact message-syntax spellings and worked examples live in the
`messages` crate's docs/ICU_SUBSET.md; the package-level API lives in docs/API.md.
The supported subset is:

* numbers (`I18N.Number_Format`): percent, permille, compact-short/long,
  scientific, engineering, precision (integer/unlimited/fraction/significant,
  with MIN-MAX ranges), padding and integer-width, rounding modes and
  increments, sign-display, grouping, decimal-display, trailing-zero-display,
  scale, and spellout/ordinal-words skeletons, including their ICU
  `notation-*`/slash aliases and compound token lists;
* currency (`I18N.Currency`): three-letter ISO codes with symbol/standard/
  narrow/name/full-name/iso-code/accounting/cash options and the
  `::currency/XXX` number-skeleton spelling, over the generated CLDR 46.1
  307-code table with minor-unit and cash-rounding metadata;
* dates and times (`I18N.Date_Time_Format`): short/medium/long/full styles and
  `::` skeletons over the field set `G y Y u U r Q q M L l w W d D F g E e c`
  (date) and `a b B h H K k j J C m s S A n N z Z O v V X x` (time), with
  apostrophe-quoted literals and CLDR `availableFormats` resolution;
* calendars (`I18N.Calendars`, `I18N.Calendar_Math`): Gregorian plus Buddhist,
  Japanese, ROC, Julian, Coptic, Ethiopic (and Amete Alem), tabular Islamic
  civil/astronomical, Indian national, arithmetic Persian, Hebrew lunisolar, and
  ISO-8601, selected by `-u-ca-*` extensions or runtime data;
* time zones: numeric offsets, `UTC`/`GMT` aliases, and checked IANA tzdb 2026a
  primary zones and links, with generated seconds-based transition offsets for
  447 primary zones over 1900-2050;
* measurement and relative time (`I18N.Measurement`): the ICU `measure-unit`
  identifier set with unit-width and per-measure-unit options, plus `duration`,
  `bytes`, `relative`, and `list` formatting;
* spellout (`I18N.Spellout`): cardinal and ordinal RBNF output for the built-in
  locale set with English fallback;
* delimiters, display names, emoji, and person names (`I18N.Delimiters`,
  `I18N.Display_Names`, `I18N.Emoji`, `I18N.Person_Names`).

Numeric fields in every formatter use the resolved locale signs, digit set, and
explicit `-u-nu-*` numbering-system extensions for all generated CLDR numeric
systems.

## Runtime data overrides

`I18N.Runtime_Data.Load_Text` loads deterministic process-wide runtime-data overrides from line-oriented text (the `messages` crate re-exposes it to message callers as `Messages.Runtime.Load_Data_Text`). Supported key/value entries include locale separators, grouping policy, digits, number signs/suffixes/exponent/accounting symbols, month/weekday/quarter/day-period/era names, exact and range flexible day-period rules, time-zone display, exemplar-location, generic-location patterns, and short specific/generic names, default time-zone preferences and offset components, unit and relative-time display text, list separators, date/time style skeletons, available-format skeleton patterns, date/time skeleton append separators, and datetime style separators, supported default calendar preferences, currency placement/separators/accounting affixes, fixed time-zone base offsets, currency metadata/display fields, exact non-negative plural-category overrides, and known CLDR plural-rule family aliases:

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
