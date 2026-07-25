# Runtime data files

Most CLDR data is served from **runtime data files** loaded on demand by
`I18N.Data_Store` rather than compiled into the library body. Phase 1 introduced
this model with the display-name / delimiter / measurement data; heavy areas
(annotations, collation, transliteration) reuse the same loader with no new
lookup algorithm. The core per-locale formatting data (number/list separators,
month/weekday/quarter/day-period names, date/relative patterns, currency and
unit display names, timezone exemplar cities) is now served this way too — the
files are the primary source, and `src/i18n-cldr_data.adb` retains only the
structural data with no on-the-fly equivalent (see `CLDR_DATA.md`).

## File format (`*.i18ndata`)

Plain ASCII framing; values are raw UTF-8 bytes. Same packed, sorted, bisectable
shape the compiled tables use — just in a file instead of an Ada constant.

```
I18NDATA|1|<cldr-version>\n          header (magic | format-version | cldr version)
@<section>|<count>\n                 section header (count is informational)
<key>\t<value>\n                     records, sorted by <key> within the section
...
@<section>|<count>\n
...
```

- **Records are sorted by `<key>`** within each section. `I18N.Data_Store` bisects
  in place over the loaded bytes — it never builds a per-record index, because a
  full-locale file is ~10^6 records.
- **Keys are composite**, built by the caller with the unit separator
  `U+001F` (`I18N.Data_Store.Key_Separator`), e.g. `"<locale>\x1f<code>"`. The
  data layer is a pure `key -> value` map; **locale parent-fallback is the
  caller's job** (see `I18N.Display_Names`, which walks `zh-Hant-HK -> zh-Hant ->
  zh -> root`).
- The `\t` separates key from value; values never contain a newline.

### Sections in `display-names.i18ndata`

| Section | Key | Value |
|---|---|---|
| `language`, `script`, `territory`, `variant`, `key`, `type` | `<locale>\x1f<code>` | display name |
| `locale-pattern` | `<locale>\x1f{localePattern,localeSeparator,localeKeyTypePattern}` | ICU pattern |
| `delimiter` | `<locale>\x1f{quotationStart,quotationEnd,alternate…}` | mark |
| `measurement-system` | `<territory>` | `metric` \| `US` \| `UK` |
| `measurement-name` | `<locale>\x1f<system>` | localized system name |

## Generation

`cldr/src/generate_cldr_display_data.adb` reads the vendored upstream
`cldr-localenames` / `cldr-misc` / `cldr-units` / `cldr-core` JSON directly and
writes `share/i18n/display-names.i18ndata`. It is **decoupled** from the compiled
subset pipeline (export → normalize → subset) — a runtime area does not need to be
threaded through those stages.

`cldr/regenerate.sh` (the Alire pre-build action) generates it best-effort: when
the vendored upstream is present it (re)builds the file if missing; otherwise it
skips it and the library still compiles — the feature just reports itself
unavailable via `I18N.Display_Names.Available`. The file is gitignored (a
regenerated artifact, like `i18n-cldr_data.adb`).

## Discovery at run time

`I18N.Data_Store` resolves `<name>.i18ndata` against, first hit wins:

1. `I18N.Data_Store.Configure_Data_Dir (Path)` — set programmatically;
2. `$I18N_DATA_DIR`;
3. the running executable's directory + `share/i18n` (and `../share/i18n`, which
   is the standard `<prefix>/bin` + `<prefix>/share` install layout);
4. `share/i18n` relative to the working directory (dev/test convenience).

Alire installs `share/` as an artifact (`i18n.gpr`'s `Install` package), so a
`gprinstall`ed consumer finds the file via rule 3.

## Adding a new runtime area (later phases)

1. Add a generator (`generate_cldr_<area>_data.adb`) that emits packed sections.
2. Hook it into `regenerate.sh`'s `generate_runtime_data`.
3. Add a public `I18N.<Area>` package that composes keys and calls
   `I18N.Data_Store.Lookup` (+ parent walk if locale-keyed).

No changes to the loader or the format are required.
