# Phase 0 — Execution Plan: UCD Import + Normalization (the foundations)

Phase 0 is the prerequisite for the heavy engines (6 segmentation, 7 collation,
8 transliteration). Its original scope also listed the runtime loader / config /
sharding — but those were **already built incrementally in Phases 1-4** and are
reused here unchanged. What remains, and what this plan covers, is the hard core:

- **UCD import** — a *new, non-CLDR* data source (Unicode Character Database from
  unicode.org), because Unicode properties are not shipped in cldr-json.
- **Normalization** — a conformant NFC / NFD / NFKC / NFKD engine, validated
  against the official `NormalizationTest.txt`.

Nothing downstream (canonical collation, break iteration over composed text,
transform rules) is correct without normalization, so it is built first.

---

## The new thing: a UCD data source

cldr-json ships no Unicode properties, no UCA. The existing downloader already
speaks HTTP (`Http_Client`) to fetch cldr-json release assets, so it can fetch
the UCD files from `https://www.unicode.org/Public/<ver>/ucd/`. Pin the version
CLDR 48 aligns with (Unicode 16.x — record the exact value in a UCD manifest next
to `source_manifest.txt`).

Files Phase 0 needs (normalization only; break/UCA files come with their phases,
reusing this same importer):

| File | Provides |
|---|---|
| `UnicodeData.txt` | canonical combining class (field 3), decomposition mapping (field 5, `<compat>`-tagged for compatibility) |
| `CompositionExclusions.txt` | script/post-composition exclusions |
| `DerivedNormalizationProps.txt` | Full_Composition_Exclusion, the NF*_QC quick-check props |
| `NormalizationTest.txt` | the conformance suite (the gold standard) |

---

## Storage — one global table set, loaded once (not per-locale)

UCD data is **per-code-point**, not per-locale — so a single global file
`share/i18n/normalization.i18ndata`, section `table`, with whole-table values
(the RBNF trick: one big value the engine parses once, not per-char `Lookup`s):

```
key  ccc            value  cp:class cp:class ...          (only non-zero CCC, ~1k)
key  canon-decomp   value  cp>cp1 cp2 ... | ...           (fully expanded, ~13k)
key  compat-decomp  value  cp>cp1 cp2 ... | ...
key  compose        value  a,b>c ...   (canonical (starter,mark)->composite, minus
                                         exclusions/singletons/non-starter-firsts)
```

`I18N.Normalization` loads the four tables on first use (four `Lookup`s) and
builds in-memory structures for O(1)-ish per-code-point lookup — because
normalization is on the hot path of collation and segmentation, per-char file
bisection would be far too slow. Code points are hex; tables are a few hundred KB.

---

## Workstream A — UCD import

- **A1** `download_ucd.adb` (or extend the downloader): fetch the four files for
  the pinned Unicode version into `cldr/upstream/ucd/`; a `ucd/source_manifest.txt`
  records version + hashes. Gitignored like the rest of `upstream/`.
- **A2** A small UCD line reader (`;`-delimited, `#` comments) — either a shared
  helper or inline in the generator (analogous to `Cldr_Json`).

## Workstream B — Normalization data generator

`generate_ucd_normalization_data.adb`:
- Parse `UnicodeData.txt` → CCC per cp; raw decomposition per cp (canonical vs
  `<compat>`).
- **Fully expand** decompositions recursively (canonical → canonical only;
  compatibility → apply canonical+compat to fixpoint) so the engine never
  recurses at run time.
- Build the **composition table**: every canonical decomposition `c -> a b`
  where `c` is not in `CompositionExclusions` / `Full_Composition_Exclusion`,
  `a b` are two code points, and `c` is not a non-starter — invert to `(a,b)->c`.
- Emit the four tables to `normalization.i18ndata`. Deterministic; gitignored;
  best-effort in `regenerate.sh` (guarded on the vendored UCD).

## Workstream C — Normalization engine — `I18N.Normalization`

- `type Form is (NFC, NFD, NFKC, NFKD);`
- `function Normalize (Text : String; Form : Form) return String;` (UTF-8 in/out)
- `function Is_Normalized (Text : String; Form : Form) return Boolean;`
- Algorithm (UAX #15), operating on decoded code points:
  1. **Decompose** each cp via the canonical (NFC/NFD) or compatibility
     (NFKC/NFKD) table (already fully expanded — no runtime recursion).
  2. **Canonical ordering**: stable-sort each maximal run of non-starters
     (CCC > 0) by CCC.
  3. For the composing forms (NFC/NFKC) **compose**: walk starters; for each,
     pull following combining marks and compose via the `(a,b)->c` table,
     honoring the *blocked* rule (a mark blocks composition of a later mark with
     the starter when CCC is equal-or-greater), Hangul (algorithmic
     LV/LVT composition/decomposition — do it in code, don't table it).
- Reuse `I18N.Data_Store`; add nothing to the loader.

## Workstream D — Conformance (the acceptance bar)

`NormalizationTest.txt` is the definitive suite (~2×10^4 lines). Its columns give
`source c1 c2 c3 c4 c5` where, per UAX#15, `c2 = NFC`, `c3 = NFD`, `c4 = NFKC`,
`c5 = NFKD`, plus the invariants (`toNFC(c1)==toNFC(c2)==toNFC(c3)==c2`, etc.).
- Wire a differential harness that runs **every** line and checks all four forms
  and the idempotence invariants — Phase 0 is not done until it is green.
- A self-contained AUnit test with a handful of canonical cases (é composed vs
  decomposed, a CCC-reordering case, a Hangul syllable, a compatibility case like
  ﬁ → fi) so the engine is pinned in the normal test run too.

---

## Sequencing

```
A import (download + reader) → B generator (tables) → C engine (UAX#15)
   → D NormalizationTest.txt differential  (gates "done")
```
Behind a `features` toggle; the library builds and runs without the UCD (the
engine reports unavailable / returns input unchanged).

## Risks / decisions

- **New data source & downloader** — the first non-cldr-json fetch; keep it in
  the tools crate (the library must not gain an HTTP stack), pin the Unicode
  version to CLDR 48's, and record hashes.
- **Correctness is all-or-nothing** — normalization feeds collation and
  segmentation, so a subtle bug propagates. `NormalizationTest.txt` must pass in
  full before this phase is called done; do not ship on spot checks.
- **Hangul is algorithmic** — compose/decompose Hangul in code (the arithmetic
  from UAX#15), don't put 11k syllables in the tables.
- **Scope** — Phase 0 imports only the normalization UCD files and ships the
  normalization engine. Break properties (Phase 6) and the DUCET/UCA (Phase 7)
  reuse this importer but are out of Phase 0. Case mappings (a nicer `-allCaps`
  for Phase 3B, full Unicode) are an easy follow-on once UCD import exists — note,
  don't build here.
- **Performance** — load the tables once into in-memory maps/arrays; never bisect
  the file per code point.
