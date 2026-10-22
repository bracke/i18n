# Changelog

Notable changes to i18n. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`alire.toml` says `1.1.0`; consumers here pin this crate **by path**, so the
commit is what a consumer's release records.

## [Unreleased]

### Fixed

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
