# CLDR Phase 7 Execution Plan — Collation (UCA + CLDR tailorings)

## Goal

Locale-aware string comparison and sort keys: the **Unicode Collation
Algorithm** (UTS #10) over the DUCET, then the **CLDR root** and **locale
tailorings** (UTS #35 Part 5). Delivered as `I18N.Collation`
(`Sort_Key`, `Compare`), reusing the Phase-0 normalization engine.

This is the heaviest engine in the programme and the one with genuinely open,
costly scope decisions — hence a written plan before code.

## Why it is decision-heavy

Unlike segmentation (a determined rule set with an official pass/fail test),
collation forks early:

- **DUCET vs CLDR root.** The Unicode conformance test (`CollationTest.txt`) is
  **DUCET**-based. Real locales use the **CLDR root** (DUCET reordered per
  UTS #35 — script order, a handful of primary changes). ICU uses the CLDR root.
  We can be *conformance-green* against DUCET, or *ICU-faithful* against CLDR —
  the two disagree on specific orderings.
- **Tailorings are a mini-language.** Per-locale rules (`&a < b << c <<< d = e`,
  resets, `[before]`, contractions) are a parser + table-rewriter, not a data
  table. This is the single biggest chunk and the main risk.
- **Both are optional to a point.** A correct DUCET UCA already gives usable
  language-neutral sorting; CLDR root + tailorings is what makes å/ä/ö sort
  Swedish-style.

## Data sources (new UCA data, mirroring how Phase 0/6 pulled UCD)

- `allkeys.txt` — the DUCET (~2 MB, ~34k entries incl. contractions), from
  `unicode.org/Public/UCA/17.0.0/`.
- `CollationTest_NON_IGNORABLE.txt`, `CollationTest_SHIFTED.txt` — official
  conformance (each is an ordered list of strings; sort keys must be
  non-decreasing down the file). From the same UCA directory (`CollationTest.zip`).
- CLDR tailorings: `cldr-common/common/collation/<locale>.xml` (Stage E).
- Extend `fetch_ucd.sh` (or add `fetch_uca.sh`) to pull these; pin UCA 17.0.0 to
  match the Unicode 17 data already vendored.

## Architecture (consistent with prior phases)

- **Runtime data file** `share/i18n/collation.i18ndata` — the DUCET as one
  section: records keyed by code-point sequence (hex, `-`-joined), value = the
  collation elements (primary/secondary/tertiary weights, hex, packed). Sorted
  keys → the existing loader bisection. Contractions are multi-cp keys resolved
  by **longest match**; the generator emits a small "has longer contraction"
  marker set so the engine knows when to look ahead.
- **Implicit weights** (Han/Tangut/Nushu/unassigned) are *computed*, not stored
  (UCA §10.1 range formulas) — like Hangul in normalization.
- Engine flow: `Text → NFD (Phase 0) → collation elements → sort key (S2) →
  compare`.
- Tailorings (Stage E): per-locale shards `collation/<locale>.i18ndata` holding
  the *delta* over the root, or a fully-resolved per-locale table.

## Stages

### Stage A — DUCET import + sort keys (Non-Ignorable)  ← the core
1. `generate_uca_collation_data`: parse `allkeys.txt` → `collation.i18ndata`.
2. Engine: NFD-normalize; produce collation elements (single cp, then
   contractions via longest match, plus S2.1 discontiguous-contraction handling
   that skips already-combined marks); compute implicit weights for anything not
   in the table.
3. Build the sort key (UCA S2): concatenate all level-1 weights, `0000`
   separator, all level-2, separator, all level-3 (drop zero weights per level).
4. `Compare` = byte-compare of sort keys.
5. **Validate against `CollationTest_NON_IGNORABLE.txt`** — sort keys must be
   monotonically non-decreasing down the file. Zero failures is the bar
   (the Phase-0/6 standard).

### Stage B — Variable weighting (Shifted)
- Identify variable collation elements (primary ≤ the `[variable top]` from
  `allkeys.txt`).
- Shifted option: zero a variable CE's primary/secondary/tertiary and emit a
  level-4 (quaternary) weight; non-variables get a max quaternary.
- **Validate against `CollationTest_SHIFTED.txt`.**

### Stage C — Strength, edge cases, API hardening
- Strength levels: Primary … Quaternary + Identical (truncate the sort key).
- Expansions (one cp → several CEs) — mostly free from Stage A parsing; verify.
- Finalize `I18N.Collation` public API.

### Stage D — CLDR root collation
- Apply the CLDR-root modifications to DUCET (script reordering + documented
  primary changes) so real-locale output matches ICU. Source: CLDR
  `common/uca` / FractionalUCA, or expressed as a root tailoring.
- Decision point (see below): this is where "conformance-green" (DUCET) and
  "ICU-faithful" (CLDR) diverge.

### Stage E — CLDR locale tailorings  ← the biggest sub-project
- Parse the tailoring rule syntax from `common/collation/<locale>.xml`
  (`&` reset, `<`/`<<`/`<<<`/`=` relations, `[before N]`, contractions,
  `[import]`, settings like `strength`, `alternate`, `caseFirst`).
- Rewrite the root table into a per-locale table; emit `collation/<locale>`
  shards.
- Validate against known orderings: Swedish (å ä ö after z), German phonebook
  (ä = ae), Spanish (modern: n < ñ < o), Danish, etc.

### Stage F — Tests, cascade, commit
- Self-contained AUnit (hand table: primary/secondary/tertiary distinctions,
  one contraction, one variable) + the offline conformance harness.
- Wire `regenerate.sh` (fetch + generate, best-effort) and `.gitignore`.
- `alr build` → `alr test` → gnatprove → commit/push; update memory.

## Recommended v1 scope

**A–C fully conformant** (DUCET UCA, both variable options, validated against the
official CollationTest — ~and this is the hard algorithmic core), **plus D (CLDR
root)** so locale output is ICU-faithful. For **E (tailorings)** I recommend
shipping the **rule parser + the major European locales** (sv, de, da, es, fr,
nb, fi, …) validated against known orderings, and explicitly deferring the long
tail of syntax corner cases (`[import]` chains, rare `[before 3]` interactions)
to a follow-up — the same "v1 + documented deferrals" pattern as Phases 3B/4.

If you would rather bound it tighter: **A–C only** (a fully-conformant
language-neutral UCA, no CLDR root/tailorings) is a clean, self-contained
deliverable, with D–E as Phase 7b.

## STATUS — IMPLEMENTED

- **A–C DONE, conformance-green:** the UCA engine (`I18N.Collation`, `Sort_Key`
  / `Compare`) over the DUCET, reusing Phase-0 NFD. Contractions, discontiguous
  contractions (S2.1), implicit weights (Han FB40/FB80, Tangut/Nushu/Khitan
  blocks, unassigned FBC0), both variable modes and all strengths. **Validated
  0 out-of-order** against the official `CollationTest_NON_IGNORABLE.txt`
  (206,316 lines) and `CollationTest_SHIFTED.txt` (227,831 lines).
- **E DONE:** the CLDR tailoring-rule parser (`& < << <<< = , [before N] /`)
  builds per-locale fractional-weight override shards for 18 locales; validated
  against known orderings (Swedish z<å<ä<ö, Spanish n<ñ<o). Target keys are
  NFD-normalized to match the engine.
- **D (CLDR root script reordering) — the one deferred refinement.** The shipped
  root is the DUCET (conformance-proven); tailorings are applied on it. This is
  correct for each locale's own script (the anchors that matter, e.g. ǀ, sit in
  the same place in both roots); full CLDR-root cross-script reordering is the
  remaining follow-up. The engine is root-agnostic, so it is a data swap.

## Decisions — LOCKED

1. **Scope: A–E** — full UCA + CLDR root + tailoring parser with locale coverage.
   Stage E (the rule parser) is in scope, not deferred.
2. **Root: DUCET first, then CLDR root** — Stages A–C validate against the
   official DUCET `CollationTest` for a clean zero-failure milestone; Stage D
   layers the CLDR-root changes on top.
3. **API defaults: Tertiary strength + Shifted variable weighting** (the ICU/CLDR
   default). Signature shape: `Compare (A, B, Locale => "…", Strength =>
   Tertiary, Variable => Shifted)` with those as defaults; `Sort_Key` takes the
   same options.

## Risks

- **Tailoring rule parser** is a mini-language — the largest risk; Stage E is
  most of the effort. Bounding it (recommendation above) contains this.
- **Implicit-weight ranges** changed across Unicode versions; get the 17.0
  Han/Tangut/Nushu ranges exactly right or CJK sorts wrong.
- **DUCET vs CLDR root** mismatch: DUCET-only will *fail* real-locale
  expectations even when it passes the Unicode CollationTest — set expectations
  by which target each stage validates against.
- **Data size:** `allkeys.txt` is ~2 MB; the packed record encoding must stay
  compact (weights as hex, contractions as multi-cp keys) so the file and the
  in-memory table stay reasonable.
