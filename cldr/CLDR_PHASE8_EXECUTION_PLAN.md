# CLDR Phase 8 Execution Plan — Transliteration (Transforms)

## Goal

Script conversion and text transforms: the CLDR/ICU transform engine (UTS #35
Part 3) — a rule-based rewriting system — as `I18N.Transliteration`
(`Transform (Text, Name)`), reusing Phase-0 normalization for the `::NFx` steps.
This is the last engine in the programme and the most syntactically complex: the
transform rules are a full mini-language (cursor, contexts, variables, filters,
compound calls, bidirectional rules).

## What the data looks like (confirmed)

CLDR `common/transforms/<Name>.xml` holds a `<tRule>` CDATA in ICU syntax, e.g.
`Greek-Latin.xml`:

- `:: [ filter-set ] ;` — a UnicodeSet limiting which characters are touched.
- `:: NFD (NFC) ;` — a compound/built-in call (forward NFD, reverse NFC).
- `$lower = [[:latin:][:greek:] & [:Ll:]] ;` — variables bound to **UnicodeSets**
  (`[:Greek:]`, `[:M:]`, `[:Ll:]`, script/category properties, `&` intersection,
  `-` difference, ranges, nesting).
- `before { X } after → replacement ;` — context-sensitive rules, with `|` revisit,
  quoting, and `↔`/`←`/`→` directions (`direction="both"`).

Validation data exists: **`common/testData/transforms/*.txt`** (BCP-47-named,
input/output pairs) — the conformance signal, analogous to CollationTest.

## Why this needs a plan (open, costly decisions)

- **UnicodeSet is itself a sub-project.** Rules lean on `[:Script:]`,
  `[:General_Category:]`, `[:Ll:]`… so the engine needs a UnicodeSet parser **and**
  the Unicode property data behind it (Scripts.txt, DerivedGeneralCategory,
  binary props). That is a data-generation task before any rule runs.
- **Case mapping is a real dependency.** `::Lower/Upper/Title` appear everywhere;
  they need simple + full case data (UnicodeData + SpecialCasing) we don't have yet.
- **The transform set is huge (400+ files)** and ranges from clean script pairs to
  language-specific romanizations (Han→pinyin) and `Any-*` auto-script-detection.
  Covering all is out of proportion; the engine + a curated set is the value.
- **No free lunch on Any-Latin:** it requires detecting the source script per run
  and dispatching to the right script→Latin transform + chaining.

## Architecture (consistent with prior phases)

- **Runtime data files.** `generate_cldr_transform_data` compiles each chosen
  transform's rules into `share/i18n/transforms/<name>.i18ndata` (parsed rule list
  + resolved variables/filter). A shared **property** data file
  `share/i18n/uprops.i18ndata` (scripts + general category + binary props) backs
  the UnicodeSet evaluator. `::NFx` reuses `I18N.Normalization`; case built-ins
  reuse a new small case-mapping table.
- **Engine `I18N.Transliteration`.** `Transform (Text, Name) return String`,
  `Available`. Loads the named transform (a pipeline of steps: filter, rule-set,
  built-in call, or sub-transform), applies the rewriting with a cursor.

## Stages

### Stage A — UnicodeSet + property data  ← the foundation
- Generate `uprops.i18ndata`: per code point, Script and General_Category, plus
  the binary properties the transforms use, as sorted ranges (the segmentation
  pattern). Sources: Scripts.txt, extracted GC, PropList/DerivedCoreProperties.
- A UnicodeSet parser/evaluator: `[...]` with literals, ranges, `[:prop:]` /
  `\p{...}`, set ops (`&` `-` union), nesting, string-quoting. Returns a
  membership test. Validate against a handful of known sets.

### Stage B — the rule engine  ← the core
- Parse one transform's forward rules: `$var` definitions (bound to UnicodeSets),
  context rules `pre { key } post → out`, the `|` revisit cursor, quoting/escapes.
- Apply: scan left to right; at each cursor position try rules in order; on a
  match (respecting contexts) splice the replacement and move the cursor (or
  revisit at `|`). Deterministic, first-rule-wins.
- Validate on a self-contained rule set and one simple CLDR transform.

### Stage C — built-ins, filters, compounds
- `::[filter]` (only filtered characters are transformed).
- Built-in calls: `::NFD/NFC/NFKD/NFKC` (Phase 0), `::Lower/Upper/Title` (new case
  table, Stage C.1), `::Remove`, `::Null`, `::Hex`.
- Compound transforms: a rule file is a **pipeline** of `::calls` and rule-sets;
  run them in order. Recursive sub-transform invocation.

### Stage D — direction
- Bidirectional rules (`↔`), reverse-only (`←`), and inverse transform names
  (`Greek-Latin` vs `Latin-Greek`): build both directions from `direction="both"`.

### Stage E — curated CLDR transforms + conformance
- Ship a curated set (clean script pairs — Latin-Greek, Latin-Cyrillic, a couple
  of Indic, Latin-ASCII, and the functional NFx/case ones). Validate against the
  matching `common/testData/transforms/*.txt`. Zero-mismatch is the bar where a
  test file exists.

### Stage F — API, tests, cascade, commit
- `I18N.Transliteration` (`Transform`, `Available`); self-contained AUnit (hand
  rules + one CLDR transform) + the offline conformance harness over testData.
- Wire `fetch_ucd.sh` (transforms + testData + Scripts/SpecialCasing) and
  `regenerate.sh`; `.gitignore`. Build → test → gnatprove → commit; update memory.

## Recommended v1 scope

**A–D fully** (UnicodeSet + property data, the rule engine, built-ins/filters/
compounds, bidirectional), **plus E as a curated transform set** validated against
CLDR testData. **Defer, documented:** the long tail of language-specific
romanizations, full `Any-*` auto-script-detection (or ship a limited `Any-Latin`
over the covered scripts), and the most exotic syntax corners. Same "v1 +
documented deferrals" shape as Phases 4 / 7.

Tighter alternative: **engine + built-ins only** (NFx, case, Remove, and
hand/loaded rule sets) with the CLDR transform *catalog* as Phase 8b.

## STATUS — IMPLEMENTED (engine + catalog; conformance partial)

- **A–D built:** `I18N.Transliteration` (`Transform`, `Available`) with a full
  UnicodeSet evaluator (ranges, `[:Script:]`/`[:gc:]` via `uprops.i18ndata`,
  `&`/`-`/complement, nesting, `\p{}`), the rule engine (variables, before/after
  contexts, `|` revisit cursor, `()`/`$1` segments, `+`/`*`/`?` quantifiers),
  `::` filters, built-in calls (NFx via Phase 0, Lower/Upper/Title via the new
  `I18N.Casing`, Null/Remove), compound chaining and bidirectional rules.
- **Full case mapping `I18N.Casing`** (simple + SpecialCasing: ß→SS, Final_Sigma,
  Turkish/Lithuanian) backing the case built-ins. 152/152 AUnit; gnatprove clean.
- **Whole catalog generated:** `generate_ucd_uprops_data` + `generate_cldr_
  transform_data` compile the 379-file CLDR catalog into 165 shards + an alias
  index; `fetch_ucd.sh`/`regenerate.sh` wire it.
- **CONFORMANCE (offline harness over `common/testData/transforms`):**
  **289,564 / 296,989 case lines pass (~97.5%); 234 of 288 files fully pass.**
  Earlier baseline was 218,762 / 92 after three foundational fixes (plain-`<tRule>`
  `::`-chains dropped by the generator; a use-after-realloc in the compiled-cache;
  the `Data_Store` `Max_Files=16` starvation). A second wave of systematic engine
  and parser fixes closed most of the remaining gap — each verified with the full
  harness (no regressions), 152/152 AUnit, gnatprove clean:
  1. `{string}` UnicodeSet members (`[a-z{ng}{ny}]`) matched literally.
  2. Transform-id resolution made case-/underscore-insensitive (BCP-47 + ICU ids),
     plus deriving the inverted-basename alias so testData names resolve
     (`beta-metsehaf`/`ies-jes`, and the no-source-lang `d0-morse-t-am-Ethi`).
  3. ASCII rule operators `>` `<` `<>` (Arrow_At only knew the Unicode → ← ↔),
     so whole transforms (Myanmar-Latin) no longer run as identity.
  4. `[:block=Script:]` and case-folded script-name matching (BGN romanizers).
  5. Set/rule parsing robustness: a literal `:` inside a set (`[_:;,]`) is not a
     property start (only a leading `[:` is); a `'` inside a `[set]` is a member,
     not a quote — in both the engine splitter and the generator's flattener.
  6. A bare `$` in a set is the text-boundary anchor (`[aeiou$]` = vowel-or-edge),
     via the existing U+0000 boundary convention — +34 files (es-fonipa et al.).
  7. A global filter `::[set]` gates the *whole* remaining pipeline including
     sub-transform and NFx steps (per-filtered-run), not just direct rules — the
     seven `und-*-t-und-mlym` (Malayalam chillu pass-through).
  8. `::[set] Name` is a filtered call (apply Name to the set), not a global
     filter that also dropped the Name (Japanese hrkt romanizers).
  9. Quantified sets match `{string}` members too (`[ij{i̯}]+`) — es→ja diphthongs.
  10. Zero-width insertion rules (empty key with a before/after context,
      `a { } b → X`) are kept, not dropped at parse time — syllable-dot /
      epenthesis insertion (my-fonipa and friends).
- **Third wave (scoped "implement the medium/easy, defer the hard"):** brought it
  to **290,440 / 296,989 (~97.8%); 241 of 288 files.** Fixed: the Ethiopic-Morse
  second pass (`-` before `]` is a literal dash, not a range that ate the `]` —
  d0-morse 0→613); `<!-- -->` XML-comment blocks in tRule CDATA are stripped so
  their prose apostrophes stop truncating shards (Indic→Tamil/Oriya); `[:Lowercase:]
  /:Uppercase:/:Cased:]` binary properties from DerivedCoreProperties (BGN
  title-casing, ru-bgn); `::Any-X` falls back to `Latin-X` and whitespace inside a
  `{string}` set member is skipped (de-ASCII 10→19); and `(…)` segments in the
  **before-context** are captured for `$n` (Persian gemination, fa-fonipa
  2447→2547).
- **Deferred as agreed (the "hard" tail, ~out of scope):** Amharic IPA glides and
  the `am_FONIPA-am` hub feeding the ~21 `am-t-*` chains (some glides have no rule
  in the CLDR data — ICU makes them by iterative cursor re-application); Burmese
  syllabification/schwa (my-fonipa + the `*-t-my` chains); Uyghur IPA. These need
  ICU-engine-level semantics we don't replicate.
- **Also documented, not engine bugs:** the ka-bgn-2009 apostrophe (transform
  emits U+2019, testData wants U+02BC — a within-release data skew); the
  alaloc/sera glottal (identical rules, contradictory testData); the InterIndic→
  Arabic independent-vowel alif carrier (ICU drops it after a vowel via a
  mechanism absent from the rule data). Small per-transform tails (a few Japanese
  romanization pairs, Welsh stress/length, X-SAMPA, Zawgyi) remain, each 1–12
  cases, individually per-language.

## Decisions — LOCKED (maximal scope)

1. **Breadth: engine + ALL CLDR transforms** (the full `common/transforms`
   catalog, 400+ files — script pairs, romanizations, functional). Stage E
   generates a shard per transform; whatever a rule needs (UnicodeSet props,
   built-ins, sub-transform chaining) must therefore be supported, and coverage
   is validated file-by-file against `common/testData/transforms`. Transforms
   whose rules use a still-unsupported construct are generated best-effort and
   reported, not silently dropped.
2. **Case mapping: FULL** — UnicodeData simple case **plus SpecialCasing.txt**
   (one-to-many + context/locale-sensitive: final sigma, German ß, Turkish i,
   Lithuanian, …). Backs `::Lower/Upper/Title` and is a reusable `I18N.Case`.
3. **Any-Latin: ship a limited auto-detecting `Any-Latin`** — detect the source
   script per run and dispatch to the covered script→Latin transforms, chaining
   as needed. Other `Any-*` targets follow the same mechanism where data exists.

This is the largest phase: the full rule mini-language, a complete UnicodeSet
evaluator with the property data behind it, full case mapping, the whole CLDR
catalog, and script-run detection for Any-Latin. Expect it to run longest and to
lean hardest on file-by-file testData validation.

## Risks

- **The rule mini-language** is the largest risk (cursor + contexts + revisit +
  variables + quoting); Stage B is the core effort.
- **UnicodeSet property breadth** — getting the script/category/binary-property
  data complete and correct is a prerequisite for most real transforms.
- **Case mapping** is a genuine sub-dependency (new UCD data).
- **Conformance coverage is uneven** — testData exists per transform ID but not
  for every rule; validate where it exists and curate known cases elsewhere.
