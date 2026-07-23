# Architecture

For the ICU message-formatting architecture (the two-phase catalog → compile →
render engine), see the `messages` crate's docs/ARCHITECTURE.md.

`i18n` is the native Ada Unicode/CLDR internationalization platform. Its
architecture has three cooperating layers: Unicode text algorithms, CLDR
formatters, and a generated CLDR data layer that both of the first two consume.

## Engine layering

Unicode text algorithms operate on UTF-8 text and do not depend on catalog or
message state:

* `I18N.Normalization` — bounded canonical composition/decomposition (NFC/NFD);
* `I18N.Casing` — deterministic locale-sensitive case transforms;
* `I18N.Segmentation` — grapheme, word, sentence, and hard-line segmentation;
* `I18N.Collation` — sort keys, comparison, equivalence, and search;
* `I18N.Transliteration` — bounded deterministic ASCII transliteration.

CLDR formatters render locale-aware values against the data layer:

* `I18N.Number_Format`, `I18N.Currency`, `I18N.Measurement`, `I18N.Spellout`;
* `I18N.Date_Time_Format`, `I18N.Calendars`, `I18N.Calendar_Math`;
* `I18N.Display_Names`, `I18N.Emoji`, `I18N.Delimiters`, `I18N.Person_Names`.

Locale identity (`I18N.Locales`) and plural classification (`I18N.Plurals`) sit
alongside these engines. `I18N.Locales` provides canonicalization, BCP-47
component extraction, likely-subtag maximization/minimization, and fallback that
the formatters resolve against; `I18N.Plurals` provides the CLDR cardinal and
ordinal categories the formatters use for plural-sensitive output.

## Data ownership

CLDR-derived runtime data is centralized in the private `I18N.CLDR_Data`
generated-data boundary. Number, currency, and date/time formatters consume that
internal package for locale symbols, numbering digits, grouping policy, date
ordering, style patterns and separators, localized date/time names, zone display
data, number/currency affixes, unit/list separators, unit labels, currency
metadata, and plural rule-family mappings. `I18N.Data_Store` provides the
lookup structures the generated image is organized into, and `I18N.Runtime_Data`
holds the process-wide override tables that take precedence over generated
fallback data.

## CLDR data pipeline

The checked-in `I18N.CLDR_Data` body is the deterministic curated data image for
this release. The staged CLDR import tooling regenerates that package from a
checked source subset without changing the public API: it emits normalized rows
(number symbols, digit sets, month/weekday/quarter names, currency metadata,
plural rule families, tzdb transition tables, and so on) that are compiled into
the generated image.

Runtime data loaded through `I18N.Runtime_Data` may override selected locale,
currency, fixed-zone, and exact plural-category values before the generated
fallback data is consulted. These process-wide overrides accept the same
key/value and normalized LDML/tzdb import rows the pipeline produces, so the
formatters see a single merged view of override-then-generated data.

## Release verification boundary

The platform release boundary is verified by the project-tools-based `check_i18n`
guard: the core library build, GNAT style/warning checks, the data-boundary
checks that keep generated CLDR data behind `I18N.CLDR_Data`, GNATdoc, and
GNATprove must pass for the intended release channel.
