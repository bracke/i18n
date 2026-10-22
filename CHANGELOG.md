# Changelog

Notable changes to i18n. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`alire.toml` says `1.1.0`; consumers here pin this crate **by path**, so the
commit is what a consumer's release records.

## [Unreleased]

### Changed

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
