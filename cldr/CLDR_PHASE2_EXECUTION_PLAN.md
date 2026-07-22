# Phase 2 — Execution Plan: Emoji Annotations (names + keywords)

Scope: serve CLDR emoji **annotations** — each emoji's display name (`tts`) and
its search **keywords** (`default`) — for every annotated locale, plus the
**derived** annotations (skin-tone / ZWJ / flag sequences). This is the second
runtime-data-file area; it reuses the Phase 1 loader and, critically, proves the
model at ~150 MB scale.

Locked context from Phase 1: `I18N.Data_Store` loads a packed, sorted,
bisected-in-place `*.i18ndata` file; a public `I18N.<Area>` package composes
keys and does locale parent-fallback; generation reads upstream directly and is
gitignored + best-effort in `regenerate.sh`.

---

## Data shape (confirmed against upstream v48.2)

```
cldr-annotations-full/annotations/<locale>/annotations.json
  annotations.<locale>.annotations.<emoji> = { "default": [kw...], "tts": [name] }
cldr-annotations-derived-full/annotations/<locale>/annotations.json   (same shape)
```
- 170 base locales, ~1,966 emoji each; base 56 MB / derived 99 MB raw.
- **Key is the emoji itself** — a UTF-8 grapheme *cluster* (may contain ZWJ
  U+200D, variation selectors, skin-tone modifiers). It never contains `\t`,
  `\n`, or `\x1F`, so it drops straight into the existing key/record framing.
- `tts` is a one-element array → the **name**; `default` is the **keyword list**.

---

## Keystone decision — per-locale sharding (not one giant file)

Phase 1 loads the whole data file into the heap. That is fine at 14 MB; at
~100 MB (base+derived) it is not. Emoji lookups are **always locale-scoped**, so
shard the data **one file per locale**:

```
share/i18n/annotations/<locale>.i18ndata            (base, ~120 KB each)
share/i18n/annotations-derived/<locale>.i18ndata    (derived, opt-in)
```

The loader already supports this **with no change**: `Data_Store.Lookup` takes a
`File` name that may contain a path, so the API asks for
`File => "annotations/" & Locale`, resolving `<datadir>/annotations/<locale>.i18ndata`.
Only the locales actually queried are read (typically one or two), each ~120 KB —
so peak memory is bounded by usage, not by the 100 MB corpus. Parent-fallback
loads the parent locale's shard on a miss (also small).

*(Alternative considered: keep one file and memory-map it. Rejected for now —
mmap needs a platform binding, and per-locale sharding fits the access pattern
better and needs no new code. Note it as the fallback for areas that can't shard
by locale, e.g. collation's shared DUCET.)*

---

## Workstream A — Generator

`cldr/src/generate_cldr_annotation_data.adb` (new tool; add to `cldr_tools.gpr`):
- Iterate `cldr-annotations-full/annotations/<locale>/annotations.json`. For each
  emoji: name = `tts`[0]; keywords = `default` joined by the record's own
  separator (reuse the JSON member iterator + string-unescape from
  `generate_cldr_display_data`; factor them into a shared `cldr/src` helper unit
  so both tools use one copy).
- Emit, per locale, one file with two sections:
  - `name`: key `<emoji>` → name;
  - `keyword`: key `<emoji>` → keywords joined by `\x1f`.
  Records sorted by key (byte order). Write raw bytes.
- Second pass over `cldr-annotations-derived-full` → `annotations-derived/<locale>.i18ndata`.
- Deterministic; a `--check`/hash mode as in Phase 1.

Factor the shared bits out of Phase 1's tool first (small refactor, no behaviour
change) so there is one JSON reader and one packed-record writer.

## Workstream B — Public API

`I18N.Emoji` (spec + body):
- `Name (Locale, Emoji) return String` — the display name; falls back through
  parents, then "" (or the emoji itself? return "" so callers can decide).
- `Keywords (Locale, Emoji) return String` — `\x1f`-joined; plus
  `Keyword_Count` / `Keyword (N)` accessors, or a small split iterator, so callers
  don't parse the separator.
- `Available (Locale) return Boolean` — whether that locale's shard is installed.
- File name composed as `"annotations/" & Canonical (Locale)`; derived data is a
  second `File` (`"annotations-derived/" & Locale`) consulted when a base miss
  looks like a sequence — or simply consult both, base first.

## Workstream C — Config

- Extend the `features` variable so `annotations` and `annotations-derived` are
  independently switchable (derived is 2× the bytes; many consumers won't want it).
- `locales` narrowing already applies (shards are per-locale — narrowing just
  emits fewer shard files).
- `regenerate.sh` `generate_runtime_data`: add the annotations tool, guarded on
  the vendored `cldr-annotations-full` being present; gitignore
  `/share/i18n/annotations*/`.

## Workstream D — Tests

- Self-contained AUnit test (same pattern as Phase 1): write a small
  `annotations/xx.i18ndata` shard, point the loader at it, assert `Name` /
  `Keywords` / parent-fallback / missing-emoji. Write bytes with `Stream_IO`
  (the `-gnatW8` gotcha), and remember emoji keys are multi-byte UTF-8.
- Opportunistic real-data spot check guarded by `Available`.
- A **scale** check: generate (or stub) several locale shards and confirm a
  lookup touches only the queried shard (peak memory stays flat) — the point of
  the phase.

## Workstream E — Reverse search (keyword → emoji)  [scoped]

The high-value emoji-picker feature is **search**: given a query, return matching
emoji. That needs an **inverted index** (keyword → emoji list) per locale — a
different data structure and a bigger build. **Deferred to Phase 2b**; Phase 2
ships forward lookup (emoji → name/keywords). Note it explicitly so the gap is
visible, and design the `name`/`keyword` sections so an inverted section can be
added later without a format change.

## Workstream F — Build / install / docs

- `i18n.gpr` already installs `share/` (the `annotations/` subdirs come along).
- Update `RUNTIME_DATA_FILES.md` with the per-locale sharding convention and the
  emoji sections; note the `features` toggles.

---

## Sequencing

```
A0 refactor shared JSON/writer helper out of Phase 1's tool
    → A generator (base) → A' generator (derived)
    → B API → C config/cascade → D tests → F docs
E (reverse search) deferred to 2b.
```
Land behind the `features` flag; the library builds and runs with annotations
off.

## Acceptance criteria

- `I18N.Emoji.Name`/`Keywords` return correct CLDR values for every annotated
  locale, with parent-fallback; derived sequences resolve when that feature is on.
- Data is per-locale shards under `share/i18n/annotations[-derived]/`; a lookup
  loads only the queried locale's shard — **peak memory is independent of the
  corpus size** (the phase's proof).
- Deterministic regeneration; self-contained AUnit test green; full suite still
  green; gnatprove clean; `features=annotations off` excludes the shards and the
  API degrades to "unavailable".

## Risks / decisions

- **Sharding vs mmap.** Per-locale sharding is the call here; record it as the
  standard for locale-scoped areas, with mmap reserved for shared-corpus areas.
- **Derived size.** Keep it a separate, opt-in feature and separate shard tree.
- **Reverse search** is the feature users will actually ask for — set the
  expectation now that Phase 2 is forward-only and 2b adds the inverted index.
- **Grapheme keys.** Emoji keys are byte-exact; do not normalize or case-fold
  them (unlike locale keys). A caller passing a differently-normalized emoji
  won't match — note that normalization is a UCD/Phase-0 concern.
