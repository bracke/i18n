# Changelog

Notable changes to i18n. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`alire.toml` says `1.1.0`; consumers here pin this crate **by path**, so the
commit is what a consumer's release records.

## [Unreleased]

### Added

- CLDR's `perUnitPattern` -- a unit as a rate's denominator, "{0}/s",
  German "{0} pro Stunde" -- as `p:<unit>:<width>:per` rows of the unit
  shards (64,344 rows), read by `I18N.Unit_Format.Per_Pattern`.

- CLDR's named relative offsets -- "yesterday", "the day before yesterday",
  "last week", and per weekday "last Monday" / "this Monday" / "next
  Monday" -- in a `relative_exact` section of `formats.i18ndata` (91,404 rows
  for every locale), read by `I18N.Relative_Format.Exact_Name`.
- `I18N.Number_Format.Plus_Sign` and `Minus_Sign`, beside `Decimal_Separator`
  and `Digit_Text`, and `I18N.Date_Time_Format.Short_Zone_Name`: a zone's
  CLDR short specific name at a UTC instant, or "" where it has none. They
  replace what callers outside the crate took from `I18N.CLDR_Data`.

### Changed

- `I18N.Number_Format` spells numbers out (`::spellout`) with CLDR's RBNF
  rules through `I18N.Spellout` wherever the locale has them, so the words
  match ICU: soft hyphens in German and Italian compounds, Danish "og",
  Vietnamese "lẻ", Finnish "yksi miljoona", ... The hand-written tables
  remain only for locales CLDR has no rules for.

- **Time styles are CLDR's.** `{t, time}` / `short` / `medium` / `long` /
  `full` used a hand-written pattern ("HH:mm", 12-hour only for Korean).
  Each locale's Gregorian `timeFormats` now come from the data files (a
  `time_style_pattern` section): "9:05 AM" in English, "09:05" in German,
  "9:05 am" in Hindi, "٩:٠٥ ص" in Arabic, and long and full times carry
  the zone ("9:05:07 AM UTC"), as ICU writes them. A medium (or default)
  time of a value without seconds is still written as the short one.
  `I18N.CLDR_Data.Time_Style_Pattern` is gone.
- **Currency symbols, narrow symbols, minor units and cash increments come
  from `formats.i18ndata`**, keyed by currency code, with the same defaults
  (2, 1, the code, the symbol); `I18N.CLDR_Data` loses the four accessors and
  the generator its packed-table encoders. All 307 codes match;
  `i18n-cldr_data.adb` is 16 KB.
- **Plural rule families, Indian grouping, symbol-first currency and
  day-month-year order come from `formats.i18ndata` only.** A plural family
  is the exact locale's, else its language's, else other-only, which
  reproduces the compiled table for all 766 locales; the two membership
  tests answer False where the data lists no locale, as the compiled table
  did. `I18N.CLDR_Data` loses `Cardinal_Rule_Family`, `Ordinal_Rule_Family`,
  `Uses_Indian_Grouping`, `Currency_Symbol_First` and `Uses_Day_Month_Year`,
  and the generator its bisected-table machinery: `i18n-cldr_data.adb` is
  33 KB.
- **Zone aliases come from `tzdb.i18ndata`.** Its new `@link` section maps
  each tz database alias to its zone, and `I18N.Time_Zone_Data.Canonical_Zone`
  replaces `I18N.CLDR_Data.Canonical_Time_Zone` (`i18n-cldr_data.adb` is
  52 KB). Offsets are unchanged for all 553 zone names, aliases included.
- **Digits come from the data files.** The numbering systems a locale can
  name (`-u-nu-arab`, `@numbers=deva`; 77 of them) are a `numbering_digits`
  section of `formats.i18ndata`, beside each locale's own `digit_text`, and
  `I18N.CLDR_Data.Digit_Text` (43% of the compiled file) is gone:
  `i18n-cldr_data.adb` is 62 KB. A system is now read from its subtag
  rather than matched as a substring. ks-Deva and sd-Deva write Latin
  digits, as CLDR has them (the compiled table gave them their base
  language's Arabic-script digits).
- **Number signs come from CLDR.** The plus and minus signs, the percent and
  per-mille signs and the exponent were the same constants for every locale
  ("-" where Swedish and Finnish write U+2212, "%" with nothing before it
  where German, French and Swedish put a no-break space). The exporter now
  takes each locale's symbols from its numbering system in `numbers.json`,
  and the percent sign with whatever its percent pattern puts between the
  digits and the sign, as ICU does: "12 %" in German, "−5" in Swedish, and
  Arabic's signs with their letter mark.
- **Number, currency, unit and zone symbols come only from the data files.**
  `I18N.Locale_Data.Field` no longer takes a compiled fallback, and nineteen
  accessors leave `I18N.CLDR_Data` (`Decimal_Separator`, `Group_Separator`,
  the number signs and affixes, the currency and unit separators, and the
  GMT, location and offset zone formats); `i18n-cldr_data.adb` goes from
  234 KB to 121 KB. Five were already served whole from `formats.i18ndata`;
  the other fourteen were constants in the generator, now written there as a
  `und` base with the languages that differ, and CLDR's "no value" marker
  for an empty one. Every locale answers as before except five where the
  compiled table matched a language by its first two letters: Mapudungun
  (`arn`) no longer gets Arabic percent and per-mille signs, and Konkani
  (`kok`) keeps its space between a value and its unit.
- **The hand-kept zone-family list is gone.** `I18N.CLDR_Data` loses
  `Time_Zone_DST_Family`, `Time_Zone_Display_Name`, `Time_Zone_Short_Name`,
  `Time_Zone_Generic_Short_Name` and `Time_Zone_Base_Offset_Minutes`, and the
  CLDR pipeline loses the `zone_display`, `zone_family_display` and
  `zone_short_family` rows (26,917 of them) that fed only those. Zone names
  come from `I18N.Date_Time_Format` ("z", "zzzz", "v", ...); a time of day
  with no date converts by the new `I18N.Time_Zone_Data.Standard_Offset_Seconds`,
  the zone's standard offset this year from the tz database, where the list
  knew some fifty zones.
- **Time-zone offsets load from `share/i18n/tzdb.i18ndata`**, the last large
  table compiled into `i18n-cldr_data.adb` (which goes from 1.4 MB to 264 KB).
  `I18N.Time_Zone_Data.Offset_Seconds_At_UTC` replaces
  `I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC`: one record per zone,
  bisected where it lies, the last sixteen zones cached (about 1 us an
  offset). Offsets are unchanged for every zone and year 1900-2100, except
  that the GMT aliases (Etc/GMT+0, GMT0, Greenwich, ...) now count as known
  zones at +00:00, where the compiled index refused them. Without the data
  file installed, every zone but UTC is unknown.

### Fixed

- `I18N.Spellout` read a fraction rule ("0.x") as the rule for zero, which
  looped (Ewe, Korean); counted a plural from the whole number instead of
  the divisor's quotient (Russian "одна тысячи" for 1234); used a `/radix`
  base's radix as its divisor; and lacked ICU's roll-back, so an exact
  multiple took the rule meant for one more (Burmese 2000).

- **A skeleton's `j` and the default hour cycle follow CLDR's timeData.** The
  hour cycle came from a hand-kept rule (12-hour for English, Arabic and
  Korean, 24-hour for every other language). It is now the region's
  preferred hour (a new `hour_cycle` section, 276 regions), still under any
  `-u-hc-` or runtime override, and a `j` skeleton CLDR has a format for
  takes that format: `jm` is "h:mm a" in the US, "HH:mm" in Germany, "H:mm"
  in Japan.
- **Unit values follow CLDR's own patterns.** A unit was the value, a space
  (none for Japanese, Chinese and Korean) and the name with its `{0}` cut
  out, which lost French's and German's no-break space, Japanese's space in
  long forms, narrow "2kg", "Beaufort 2", and Arabic's "ساعة" / "ساعتان"
  that name the count in words. Each locale's unit shard now keeps the
  217,163 patterns that are not the plain form, under `p:` keys beside the
  names, read by `I18N.Unit_Format.Pattern` from the locale's own shard
  only, and the CJK no-space rule is gone. Output matches ICU.
- **Relative-time patterns that name their count in words are kept.** The
  exporter dropped every CLDR pattern without a `{0}`, so Arabic's one and
  two forms ("قبل ساعة واحدة", "قبل ساعتين") and other duals fell back to
  the "other" pattern with a digit ("قبل ٢ ساعة"). 2,932 patterns are back.
- **Generic and short zone names ("v", "vvvv", "z", "VVVV") follow TR35 as
  ICU does, from CLDR data; the hand-kept zone-family list no longer names
  anything.** London read "Western European Time", en-GB wrote "WET"/"WEST",
  and a zone outside the list had no name. Now the formatter takes:
  - specific names from the zone's own name, else its metazone's;
  - generic names from the zone's own, else (with no daylight time within
    184 days) its standard name, else the metazone's generic name, with
    the "{1} ({0})" partial-location form when the zone is not the
    metazone's reference zone for the locale's region;
  - the location format from the country name for a zone that is its
    country's primary zone, else the exemplar city.

  Short names resolve along the locale chain and stop at the first locale
  that has a zone shard, so en-GB no longer inherits en's US abbreviations.
  The zero offset is the locale's `gmtZeroFormat`, and the GMT format takes
  its signs from `hourFormat` (U+2212 in French). A zone CLDR keeps apart
  from its tz database link keeps its id (Europe/Busingen is "Büsingen
  Time", not "Switzerland Time").

  Against ICU 74 (CLDR 44), 12,000 cases across 12 locales and 40 zones
  differ in 420 places, all of them CLDR 44 to 48 data changes.
- **Historical dates use the metazone in force at the date.** London before
  1971 was "British"; the zone's whole metazone history now comes from
  `metaZones.json`, and daylight time comes from the tz database (zdump's
  isdst, kept with each transition) rather than the offset.
- The generator checks a zone's final rule against zdump only up to the last
  transition its compiled file lists. Past that, zdump reports the C
  library's reading of the same rule, and macOS's misreads a change at a
  negative hour (America/Nuuk's `M3.5.0/-1`), which stopped the generator.
- The generator asks zdump for one year past the last it keeps: glibc's
  zdump reports a change in the last hours of its range that is none
  (Ubuntu 26.04's zic writes Casablanca's rule in a form that shows it), and
  the generator stopped on it.
- **Long specific zone names ("zzzz") are the standard and daylight names.**
  They were the generic name in every locale and season ("Eastern Time" for
  New York in July, where CLDR has "Eastern Daylight Time"): the import never
  brought CLDR's long standard/daylight names in. The exporter now emits each
  zone's current metazone (from `metaZones.json`) and every locale's long
  standard and daylight metazone names, plus a zone's own ("British Summer
  Time"); they go into the per-locale zone shards, so only locales in use are
  loaded. A zone CLDR names by an older id (Asia/Calcutta) is filed under its
  tz database name too. Generic names ("vvvv") are unchanged in every locale.
- The normalize and subset stages read an empty last field as "" where their
  `Field` helper returns the separator.
- **Daylight saving time no longer stops after 2050.** The compiled zone
  table ran to 2050 and the last offset in it then held for ever, so summer
  dates from 2051 on were an hour off in every zone with daylight time (and
  Casablanca's predicted Ramadan changes, which run to 2087, were missing).
  Each zone now carries its final rule -- the POSIX TZ string zic writes at
  the end of a compiled zone -- and `I18N.TZ_Rules` answers from it once the
  recorded transitions end. The generator reads transitions through 2100 and
  keeps each zone's only until its rule reproduces them exactly, checked at
  every change of either: offsets through 2050 are unchanged in every zone,
  2051-2100 match zdump at all 40,256 of its transitions, and the table
  shrank from 57,442 to 36,214 entries (`i18n-cldr_data.adb` 2.0 MB to 1.4 MB).
- Time-zone display names come from the data files only (the compiled
  `Zone_Display_Row` / `Zone_Family_Display_Row` tables, 366 KB, are gone).
  Output is unchanged except in 23 locales written in a non-default script
  (az-Arab, mn-Mong, uz-Cyrl, ...), which the compiled rows answered in the
  wrong script and which now get the English fallback names, as their units,
  currencies and city names already did.
- **A fresh clone produces `share/i18n/formats.i18ndata` again.** The
  regeneration's fast path returns early when the generated body is present and
  newer than the subset — which stopped being safe when the body itself was
  committed: one generator writes the body *and* the formats file, and only the
  body was tracked. A consumer's CI (`messages`, which asserts the file exists)
  had been failing on all three hosts since.
- "Already generated" now means present *and non-empty*. Several artifacts were
  tracked as zero-byte placeholders, and every "is it there?" test answered yes
  for a file holding nothing, so a clone shipped empty tables that nothing
  regenerated.
- A workspace without the CLDR tooling, or without a reachable upstream, is no
  longer a failed build. The regeneration runs as a pre-build action in every
  consumer's workspace, and a consumer checks out the crates the *library*
  needs, not the crates its generators need; the attempt is reported and the
  build carries on. The consumer that needs the data asserts it where it needs
  it.
- The CLDR download resumes rather than restarting, and judges an attempt by
  what it added: progress is retried at once, a stall waits, and six stalls in a
  row give up. It was six restarts from zero with a minute of backoff between
  them.

### Changed

- Generated `.i18ndata` files are no longer tracked as empty placeholders, so a
  build no longer leaves six modified files in the tree.

## Releasing

No procedure yet.
