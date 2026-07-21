# Phase 1 — Execution Plan: Display Names + Delimiters + Measurement (runtime data files)

Scope: deliver **language / script / territory / variant / key / type display
names**, **locale display composition**, **delimiters**, and **measurement
systems** — as the first CLDR areas served from **runtime data files**, building
the loader infrastructure that all later heavy areas (annotations, collation,
transliteration) will reuse.

Decisions locked: runtime-data-file model accepted; full CLDR is the end goal;
this phase builds the loader once, on a tractable area.

---

## Design keystone (de-risks the whole phase)

The current packed-table format — a **base64 value store + a base62-offset,
fixed-width key index**, bisected at runtime — is already **portable ASCII with
no endianness**. So a "data file" is simply *that same packed text written to a
file* instead of emitted as an Ada `constant String`. The runtime runs the
**identical `Key`/`Value_At`/bisect logic** over a loaded `String` rather than a
literal.

**Consequence:** the only genuinely new runtime algorithm is *loading a file and
locating a named section*. Packing, sorting, dedup, offsets, parent-walk, and
bisection are all reused unchanged. Build the loader against this format and every
future area inherits it.

---

## Workstream A — Runtime data-file infrastructure (foundational)

**A1. File format.** A section container, all ASCII/text:
- Header line: magic + format version + CLDR version.
- A section directory: `name|byte-offset|byte-length` per section.
- Each section body = one existing packed table: `Values` blob + `Index_Data`
  (fixed-width `key + First(5b62) + Last(5b62)` records) exactly as emitted today.
- Document at `share/doc/i18n/data-file-format.md`. Deterministic byte-for-byte.

**A2. Loader package `I18n.Data_Store` (runtime).**
- `Open (Path) ` → maps/reads the file once into a held `String` (or mmap via a
  thin `System`-level binding; start with read-into-memory, mmap later).
- `Section (Store, Name) return Section_View` → the packed-table slice.
- `Lookup (Section_View, Key) return String` → the **existing** bisection + parent
  walk, operating on the view. Absent file/section → `""` (caller falls back).
- Lazy, load-once, task-safe (protected initialisation; the runtime already uses
  Ada tasking for shared immutable state — follow that pattern).

**A3. Data-file discovery.** Search order, first hit wins:
1. `I18n.Configure_Data_Dir (Path)` set programmatically;
2. `I18N_DATA_DIR` environment variable;
3. compiled-in install default (`<prefix>/share/i18n`, prefix from the Alire
   install / config gpr);
4. directory of the running executable + `share/i18n`.
Document; provide a clear error/empty behaviour when nothing is found (formatting
falls back to codes, never crashes).

**A4. Generator-side writer.** Extract the current packing routines
(`Pack_Table`, `To_Base62`, value dedup, `Emit_Unit_String_Expression`) into a
reusable unit that can target **either** an Ada `L(...)` sink (today) **or** a
byte sink (a file). Add `Write_Data_File (Path, Sections)`.

**A5. Config.** Extend `i18n_config`:
- new `features` variable (comma list, default `all`) gating which data files are
  built/installed;
- confirm `locales` also narrows the rows written into each data file;
- wire `regenerate.sh` / Alire pre-build to (re)produce enabled data files.

**Acceptance A:** a hand-written 2-section test file round-trips: writer → file →
`I18n.Data_Store` → correct `Lookup` incl. parent walk; missing file returns `""`.

---

## Workstream B — Pipeline extraction (new categories)

New subset row kinds: `language_name`, `script_name`, `territory_name`,
`variant_name`, `key_name`, `type_name`, `locale_display_pattern`, `code_pattern`,
`delimiter`, `measurement_system`, `measurement_system_name`.

- **B1. `generate_cldr_export.adb`** — select JSON paths:
  - `cldr-localenames-full/main/<loc>/{languages,scripts,territories,variants}.json`
    → `main.<loc>.localeDisplayNames.{languages|scripts|territories|variants}.<code>`;
  - `.../localeDisplayNames.json` → `localeDisplayPattern`, `codePatterns`,
    `keys`, `types`, `measurementSystemNames`;
  - `cldr-misc-full/main/<loc>/delimiters.json` → quotation/alternate marks;
  - `cldr-units-full/main/<loc>/measurementSystemNames.json`;
  - `cldr-core/supplemental/measurementData.json` → territory → system (metric/US/UK).
- **B2. `coverage.txt` + `extract_cldr_normalized.adb` + `check_cldr_sources.adb`**
  — add `require_raw_count` rows for each new kind; emit normalized rows; extend
  the source-coverage validator.
- **B3. `import_cldr_subset.adb`** — expand normalized rows into pinned
  `cldr_subset.txt` rows for the new kinds.

**Acceptance B:** `regenerate.sh` (steps 3→2) reproduces a subset that contains
the new kinds with counts matching `coverage.txt`; `--check` green.

---

## Workstream C — Data generation (the runtime file)

- **C1. `generate_cldr_display_data.adb`** (new cldr tool, or a mode of the
  existing generator): reads the display-name/delimiter/measurement subset rows,
  builds one packed section per category (locale-keyed, parent-walk-enabled,
  values deduped — reusing A4), and writes
  `share/i18n/display-names.i18ndata`.
- **C2.** Deterministic output + `--check` mode; hook into the regeneration
  cascade and Alire pre-build; honour `features`/`locales` config.

**Acceptance C:** the data file is byte-deterministic across runs; regenerating
from a fixed subset produces an identical file (md5 pinned in a test).

---

## Workstream D — Public runtime API

- **D1. `I18n.Display_Names`:**
  - `Language_Name (Locale, Code) return String`
  - `Script_Name`, `Territory_Name`, `Variant_Name`, `Key_Name`, `Type_Name`
  - `Locale_Display_Name (Locale, Of_Locale) return String` — composes
    language + script + territory via `localeDisplayPattern`/`codePatterns`
    (e.g. `en`,`zh-Hant-HK` → `Chinese (Traditional, Hong Kong SAR China)`);
    a small pattern-fill algorithm, not a table.
  - Fallbacks: locale parent-walk (reuse existing), then the code itself.
- **D2. `I18n.Delimiters`:** `Quotation_Start/End`, `Alternate_Quotation_Start/End (Locale)`.
- **D3. `I18n.Measurement`:** `System (Territory) return (Metric|US|UK)`,
  `System_Name (Locale, System)`.
- **D4.** Each package lazily obtains its section from `I18n.Data_Store` and
  caches it; no data file present → documented fallbacks.

**Acceptance D:** all entry points return correct values for a sample matrix of
locales × codes; composition matches ICU output; no crash when the feature is
disabled/absent.

---

## Workstream E — Testing & conformance

- **E1. Differential (ground-truth) tests.** Generate a fixture directly from the
  upstream CLDR JSON (`cldr_export.jsonl`) for a locale sample (en, de, fr, ja,
  ar, zh-Hant, und, a long-tail locale) and assert API == JSON for each code.
- **E2. Fallback tests.** parent-walk (`de-AT`→`de`), missing code → code
  fallback, unknown locale, empty inputs.
- **E3. Composition tests.** `Locale_Display_Name` across mono/multi-subtag cases.
- **E4. Infra tests.** loader round-trip, discovery order, feature-off build
  excludes the file and the API degrades gracefully.
- **E5.** Wire into AUnit + `check_i18n`; add to the release checklist and the
  benchmark smoke (load-once + lookup timing). Keep existing **141/0** green.

---

## Workstream F — Build, install, docs

- **F1.** Alire: install `share/i18n/*.i18ndata` as artifacts (extend the
  `Install` package); confirm consumers get the data dir.
- **F2.** Docs: data-file format, loader, discovery, config `features`; update
  `CLDR_DATA.md` (note the runtime-file model now exists) and the expansion plan.
- **F3.** Keep the memory-tight build safe (`--profiles=*=development`); ensure
  the new tool + data file don't regress build memory.

---

## Sequencing & dependencies

```
A1 ─ A4 ─┬─ C1 ─ C2 ─┐
A2 ─ A3 ─┤           ├─ D1..D4 ─ E ─ F
B1 ─ B2 ─ B3 ────────┘
```
1. A1–A5 (format, loader, discovery, writer, config) and B1–B3 (extraction) in
   parallel.
2. C (generate the file) once A4 + B land.
3. D (API) once A2/A3 + C land.
4. E throughout; F to finish.

Land each workstream behind the `features` flag so `main` stays releasable; the
whole phase is opt-in until E is green.

---

## Acceptance criteria (Phase 1 done)

- Display names (languages/scripts/territories/variants/keys/types), locale
  display composition, delimiters, and measurement systems are queryable via
  public API for every pinned locale, with correct CLDR fallback.
- Data is delivered as a runtime `.i18ndata` file, loaded on demand, gated by
  `features`/`locales`; absent file → graceful code fallback, never a crash.
- Differential tests vs upstream JSON pass; parent-walk + composition correct.
- Deterministic regeneration (`--check` green, pinned md5); existing **141/0**
  AUnit still green; gnatprove clean; build stays within memory budget.
- The loader, file format, discovery, and writer are documented and reused-ready
  for Phase 2 (annotations) with **no new algorithm** — only new sections.

---

## Top risks / decisions inside Phase 1

- **Data-file discovery** is the one genuinely new design surface (where does a
  consuming app find the files?). Nail A3 early with a robust override + default;
  it's the reusable contract for every later area.
- **Locale display composition** (`Locale_Display_Name`) is the only non-trivial
  algorithm here — pattern parsing + subtag ordering; budget for edge cases.
- **Determinism** of the data file (stable section order, stable dedup) must be
  locked by a pinned-hash test from day one, mirroring the current generator's
  discipline.
- Keep values ASCII-packed (base64) — do **not** switch to raw bytes in files
  (revisits the `-gnatW8`/encoding hazard and adds endianness for no gain).

*Planning artifact; not committed. Companion to CLDR_COVERAGE_EXPANSION_PLAN.md.*
