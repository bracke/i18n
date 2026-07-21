# Full CLDR/ICU Coverage — Expansion Plan

Goal: extend `i18n` from its current curated ~26-category CLDR subset to **all**
CLDR/ICU data areas. This document is a grounded, phased implementation plan.

> **Read this first — scope reality.** "All areas" of CLDR/ICU is, in practice,
> building toward ICU parity in pure Ada. Roughly a third of the areas are
> *data + table lookup* (achievable in the existing pipeline, weeks each). The
> rest are *algorithmic subsystems* — collation, transliteration, segmentation,
> calendar arithmetic, spellout — each a self-contained engine plus Unicode data,
> and each a multi-month effort. The whole is a multi-person-year programme. The
> plan is therefore phased so the library stays releasable throughout and each
> area ships independently and opt-in. **Decide which areas you actually need
> before committing to Phases 6–8.**

---

## 1. Current architecture (baseline)

Pipeline (all already exists; full upstream is already downloaded):

```
download_cldr_upstream      → cldr-json v48.2 (4,437 files, 1.16M records, ~1 GB)
generate_cldr_export (3.2k) → cldr/upstream/cldr_export.jsonl (156 MB, 1.16M rows)
import_cldr_raw     (1.1k)  → cldr/raw/cldr_records.txt
extract_cldr_normalized(1.7k)→ cldr/import/normalized_cldr.txt  (validates coverage.txt)
import_cldr_subset  (1.5k)  → cldr/data/cldr_subset.txt         (110 MB pinned subset)
generate_cldr_data  (12k)   → src/i18n-cldr_data.adb (+subunits, 5.5 MB Ada blob)
```

Data model: pipe-delimited rows → packed base64 value stores + base62 offset
indices, **compiled into one Ada source blob** at `-O0`, looked up by
**bisection**. Rule-based areas (plurals, 1.5k LOC) use a **generated rule
interpreter**, proving the codebase can host engines, not just tables.

Config: `i18n_config` exposes `locales` to narrow the compiled locale set.

**Reduction happens only at extract/subset** — `coverage.txt` pins exactly which
categories/counts are kept; everything else in the 1.16M-record export is dropped.

---

## 2. The decisive constraint: data size vs. the compile-in model

| Fact | Value |
|---|---|
| Current subset input | 110 MB → **5.5 MB** compiled Ada blob (already a build/OOM concern at `-O0`) |
| Excluded raw upstream | annotations **155 MB**, units 107 MB (already in), dates 99 MB, localenames 35 MB, person-names 9 MB, transforms 4.3 MB, rbnf 2.4 MB, subdivisions ~1 MB, segments 172 KB |
| Not in cldr-json at all | **UCA/DUCET collation weights**, **Unicode Character Database (UCD)** — need separate unicode.org sources |

Compiling *all* of this into Ada source is infeasible — the blob would reach
hundreds of MB and neither compile in reasonable memory nor link sanely. This is
the single most important architectural decision:

> **Split the storage model.** Keep the compile-in packed-table model for small,
> hot, always-on data (what exists today + display-name-sized tables). Introduce
> a **runtime packed-data loader** for heavy/optional areas (annotations,
> collation weights, transform rules, per-calendar data): the generator emits
> compact binary data *files*, the runtime memory-maps/loads them on demand,
> gated by per-feature **and** per-locale config. This trades the current
> "single self-contained compiled artifact" property for feasibility — a product
> decision to make explicitly (see §9).

---

## 3. Area-by-area breakdown

Tiered by implementation shape. "Engine?" = needs a new runtime algorithm beyond
table lookup.

### Tier 1 — pure data + table lookup (fits the existing pipeline)
| Area | CLDR source | Shape | Engine? | Size | Effort |
|---|---|---|---|---|---|
| Language / script / territory / variant **display names** | cldr-localenames | locale → code → name | no | med (35 MB raw) | S–M |
| **Subdivision** names | cldr-subdivisions | locale → subdiv → name | no | ~1 MB | S |
| **Key/type** names, **measurement systems**, **delimiters**, **character labels** | cldr-misc, cldr-core | small locale tables | no | small | S |
| Extended **currency** display (all, not the current curated set) | cldr-numbers | locale → code → name | no | med | S |

These are the highest value-to-effort. Each is "add extraction paths + coverage
rows + `Emit_*` table + a public `I18n.Display_Names`-style API" — the workflow
the current generator already embodies.

### Tier 2 — data + moderate formatting algorithm (pattern-driven, like dates)
| Area | Source | Shape | Engine? | Effort |
|---|---|---|---|---|
| **Person-name formatting** | cldr-person-names | name-order + format patterns | small (name-order logic) | M |
| Non-Gregorian calendar **names** (month/era/day-period for buddhist, japanese, islamic, hebrew, chinese, …) | cldr-cal-* | tables like Gregorian names | no (names only) | M |
| **Annotations** (emoji names + keywords) | cldr-annotations (155 MB) | locale → emoji → name/keywords | no, but **must** be runtime-loaded | M (size-driven) |

### Tier 3 — algorithmic subsystems (new engines; several need Unicode data)
| Area | Source | Why it's hard | Prereqs |
|---|---|---|---|
| **RBNF** spellout / ordinal-words ("123" → "one hundred twenty-three") | cldr-rbnf | recursive rule grammar interpreter (plurals is the precedent, but larger) | — |
| Non-Gregorian calendar **arithmetic** (date conversion, leap/epoch rules) | algorithms (not data) | each calendar its own math; correctness-critical | — |
| **Segmentation** (grapheme / word / line / sentence break) | UAX #29/#14 + cldr-segments tailorings | rule-based break engine over Unicode properties | UCD, normalization |

### Tier 4 — the heavy engines (large data **and** complex algorithm; each a project)
| Area | Source | Why it's a project |
|---|---|---|
| **Collation** (locale-aware sorting) | UCA/DUCET (unicode.org) + cldr collation tailorings | UCA algorithm + ~2 MB DUCET weights + tailoring-rule parser + normalization; huge conformance surface |
| **Transliteration** (script transforms, Latin↔Cyrillic, etc.) | cldr-transforms | a context-sensitive rule-**rewriting** engine (ordering, reverse rules, contexts) — essentially a mini language |

---

## 4. Cross-cutting workstreams (prerequisites, not optional)

1. **Unicode Character Database (UCD) import** — a *new* pipeline parallel to CLDR
   (source: unicode.org UCD). Provides general category, scripts, combining
   classes, decompositions, break properties. **Prerequisite** for normalization,
   segmentation, collation, casing. Nothing downstream in Tier 3–4 starts without it.
2. **Normalization (NFC/NFD/NFKC/NFKD)** — foundational engine + decomposition/
   composition/CCC tables. Required by collation, segmentation, transliteration.
   Ships with its own conformance fixture (`NormalizationTest.txt`).
3. **Runtime data-loader infrastructure** — compact binary format, mmap/load,
   per-feature + per-locale gating, versioning. Unblocks all heavy areas (§2).
4. **Config surface** — extend `i18n_config` from just `locales` to per-feature
   toggles (`features = "display-names,rbnf,…"`) so a consumer pays only for what
   they use, in both compiled size and runtime data.
5. **Conformance testing** — wire the official ICU/Unicode test suites per area
   (UCA CollationTest, NormalizationTest, break test files, RBNF/number data).
   This is large and non-negotiable for correctness claims.
6. **Coverage & regeneration cascade** — every area extends `coverage.txt`, the
   `check_*` validators, and the regenerate cascade; keep it deterministic.

---

## 5. Concrete per-area change checklist

For a **Tier-1/2 (data) area**, repeat the existing pattern:
1. `generate_cldr_export.adb` / `import_cldr_raw.adb`: select the new CLDR JSON paths.
2. `coverage.txt` + `extract_cldr_normalized.adb`: add required counts; emit normalized rows.
3. `import_cldr_subset.adb`: expand into pinned `cldr_subset.txt` rows (new kinds).
4. `generate_cldr_data.adb`: add `Emit_*` producing a bisected table **or** (if heavy) a runtime data file.
5. New public package `I18n.<Area>` (spec + body) mapping the domain to the table.
6. Tests + conformance fixture.

For a **Tier-3/4 (engine) area**, additionally:
- New runtime engine package (interpreter/algorithm) + its data tables.
- UCD/normalization dependency wired first.
- Full conformance suite integration.

---

## 6. Phased roadmap (dependency- and value-ordered)

Each phase is independently shippable and opt-in.

- **Phase 0 — Foundations.** UCD import pipeline + Normalization engine + runtime
  data-loader + per-feature config. *(De-risks size; prerequisite for Tier 3–4.)*
- **Phase 1 — Display names** (languages, scripts, territories, variants,
  subdivisions, extended currencies) + measurement/delimiters. *Highest
  value/effort; establishes the "add a category" workflow end-to-end.*
- **Phase 2 — Annotations (emoji)** via the runtime loader. *Validates the loader
  at 150 MB scale.*
- **Phase 3 — Calendar names + person-name formatting.**
- **Phase 4 — RBNF spellout/ordinal** rule engine.
- **Phase 5 — Calendar arithmetic** (per non-Gregorian calendar).
- **Phase 6 — Segmentation** (grapheme/word/line/sentence). *Needs Phase 0.*
- **Phase 7 — Collation** (UCA + tailorings). *Largest data + algorithm; needs Phase 0.*
- **Phase 8 — Transliteration** (transforms). *Largest algorithm.*

Rough weight (pure-Ada, correctness-first, incl. conformance):
Phases 0–3 are the achievable, high-value core (a quarter-ish of focused work);
Phases 4–5 moderate; Phases 6–8 dominate the total and are each a standalone
subsystem.

---

## 7. Risks & decisions to make *now*

- **Library identity.** This turns a *message-formatting* library into a full
  i18n toolkit. Confirm that's the intent.
- **Purity vs. feasibility.** The heavy areas force runtime data files, breaking
  the "single self-contained compiled artifact + deterministic" property that is
  currently a selling point. Either accept a data-file model, or cap scope to
  what compiles in.
- **Build/compile budget.** Even gated, the compiled tables grow; keep `-O0`,
  split per-feature subunits, watch the memory-tight build box.
- **CLDR/UCD version pinning** across many more files; the manifest + checkers must scale.
- **Maintenance.** The regeneration cascade and conformance suites roughly
  multiply with each area.

**Recommendation:** commit to **Phases 0–3** as a concrete first programme (real,
high-value, low-algorithmic-risk), and gate **Phases 6–8** behind an explicit
decision about whether pure-Ada collation/transliteration/segmentation are worth
their cost versus deferring them or binding to ICU for those services only.

---

*Generated as a planning artifact; not committed. Move/edit freely.*
