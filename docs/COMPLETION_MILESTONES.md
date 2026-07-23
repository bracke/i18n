# i18n Completion Milestones

> **Historical note.** This roadmap was written before the message-formatting
> layer was split into the sibling `messages` crate. The Parser & Validation and
> ICU-runtime slices below (files `src/i18n-parser.*`, `i18n-ast.*`,
> `i18n-validation.*`, `i18n-runtime.*`, and the `i18n-runtime-tests-*` suites)
> were realized in that crate and now live there as `Messages.*`. The
> number/currency/date, CLDR, locale, plural, and Unicode-algorithm milestones
> remain the platform's own. File paths below reflect the pre-split layout.

This roadmap turns the completion work into concrete implementation passes by
subsystem with file-level slices and test coverage obligations.

The local AUnit runner now supports per-slice execution via `--suite=<name>`, so
per-slice validation can be run without editing suite registration.

## Milestone Set A — Parser & Validation

### Sprint A — parser-1 (blocking)

### Slice A1: strict syntax and apostrophe behavior
**Files**
- `src/i18n-parser.adb`
- `src/i18n-parser.ads`
- `src/i18n-ast.ads`
- `src/i18n-ast.adb`

**Goal**
- Make parser acceptance/rejection deterministic for all currently-in-scope ICU
  constructs.
- Confirm quoted apostrophe literal handling, malformed quote recovery, and
  branch-option capture for nested arguments.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`
- `tests/src/i18n-runtime-tests-strict.adb`

**Do now command sequence**
```bash
cd tests && alr exec -- gprbuild -P tests.gpr
cd tests && alr exec -- ./bin/tests --suite=parser
```

### Slice A2: parse/validation boundary
**Files**
- `src/i18n-validation.adb`
- `src/i18n-validation.ads`
- `src/i18n-runtime.adb`
- `src/i18n-runtime.ads`

**Goal**
- Ensure every parser-level rejection path remains deterministic and maps to
  parser or validation diagnostics before runtime execution.
- Keep malformed catalog/ICU payloads non-destructive (`Validate_*` leaves prior
  runtime intact).

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-compilation.adb`
- `tests/src/i18n-runtime-tests-release.adb`

**Do now command sequence**
```bash
cd tests && alr exec -- ./bin/tests --suite=validation
```

---

## Milestone Set B — Number, Currency, and Domain Formatters

### Slice B1: number skeleton engine
**Files**
- `src/i18n-number_format.adb`
- `src/i18n-number_format.ads`

**Goal**
- Complete number token acceptance/validation and composition semantics across
  supported tokens, aliases, and combined skeleton chains.
- Cover malformed skeleton and malformed numeric-input cases.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

### Slice B2: currency formatting surface
**Files**
- `src/i18n-currency.adb`
- `src/i18n-currency.ads`
- `src/i18n-runtime_data.adb`
- `src/i18n-runtime_data.ads`
- `src/i18n-cldr_data.ads`
- `src/i18n-cldr_data.adb`

**Goal**
- Finalize currency-option matrix (symbol/name/narrow/unit-width/accounting/cash/
  precision-currency family), minor-unit metadata, and override precedence.
- Ensure deterministic locale digits/separators/sign behavior remains stable.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

### Slice B3: unit and measure-unit formatting
**Files**
- `src/i18n-extra_format.adb`
- `src/i18n-extra_format.ads`

**Goal**
- Finalize unit and measure-unit option validation and runtime dispatch.
- Complete output behavior for list separators, compact forms, and unit fallback.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

---

## Milestone Set C — Date/Time and Calendar/TZ

### Slice C1: date/time skeletons and zone options
**Files**
- `src/i18n-date_time_format.adb`
- `src/i18n-date_time_format.ads`

**Goal**
- Complete skeleton field handling, quoted literal parsing, and format aliasing.
- Harden time instant parsing and timezone option handling.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

### Slice C2: date/time locales and calendars
**Files**
- `src/i18n-date_time_format.adb`
- `src/i18n-locales.ads`
- `src/i18n-locales.adb`
- `src/i18n-runtime_data.adb`

**Goal**
- Finalize locale-extension driven calendars and runtime calendar default overrides.
- Expand calendar/date field validation and ensure deterministic fallback results.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

### Slice C3: timezone and tzdb transitions
**Files**
- `src/i18n-runtime_data.adb`
- `src/i18n-runtime_data.ads`

**Goal**
- Finalize deterministic fixed-offset and tzdb-derived transition resolution and
  zone-name display fallbacks.
- Validate malformed UTC/offset forms as hard failures.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`

---

## Milestone Set D — CLDR Pipeline

### Slice D1: raw import / normalization refresh
**Files**
- `cldr/src/import_cldr_raw.adb`
- `cldr/src/extract_cldr_normalized.adb`
- `cldr/src/import_cldr_subset.adb`
- `cldr/src/check_cldr_sources.adb`

**Goal**
- Regenerate raw extract/normalized/imported payloads with stricter row coverage
  checks.

**Acceptance artifacts**
- `cldr/raw/cldr_records.txt`
- `cldr/raw/coverage.txt`
- `cldr/import/normalized_cldr.txt`
- `cldr/upstream/source_manifest.txt`

### Slice D2: generated data boundary updates
**Files**
- `cldr/src/generate_cldr_export.adb`
- `cldr/src/generate_cldr_data.adb`

**Goal**
- Refresh checked-in subset payload and generated `I18N.CLDR_Data` binding.

**Acceptance artifacts**
- `cldr/data/cldr_subset.txt`
- `src/i18n-cldr_data.adb` / `src/i18n-cldr_data.ads`

### Slice D3: pipeline verifiers and CI guard
**Files**
- `cldr/src/check_tzdb_sources.adb`
- `.github/workflows/ci.yml`
- `check_i18n/src/check_i18n.adb`
- `docs/RELEASE_VERIFICATION.md`
- `docs/TEST_MATRIX.md`

**Goal**
- Keep CLDR/tzdb boundary checks in the release gate and ensure failures block
  pipeline acceptance.

**Acceptance tests**
- `cd check_i18n && ./bin/check_i18n --skip-alr-test`
- `cd cldr && ./bin/generate_cldr_export --check`
- `cd cldr && ./bin/import_cldr_raw --check`

---

## Milestone Set E — Locales/Data and Behavior Contracts

### Slice E1: locale utilities and fallback behavior
**Files**
- `src/i18n-locales.ads`
- `src/i18n-locales.adb`

**Goal**
- Complete locale extension parsing, fallback normalization, directionality,
  and transliteration/case helpers within bounded contract.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

### Slice E2: plural rules and runtime override model
**Files**
- `src/i18n-plurals.adb`
- `src/i18n-plurals.ads`
- `src/i18n-runtime_data.ads`

**Goal**
- Expand rule-family coverage and locale override behavior without changing the
  deterministic fallback chain.

**Acceptance tests**
- `tests/src/i18n-runtime-tests-features.adb`

### Slice E3: public contract/doc updates
**Files**
- `docs/API.md`
- `docs/ICU_SUBSET.md`
- `ai/API_MANIFEST.json`
- `ai/CONTRACT_SUMMARY.yaml`
- `docs/RELEASE_CHECKLIST.md`

**Goal**
- Keep contract, manifest, and examples aligned with implemented feature set.
- Remove any mention of unsupported behavior and avoid over-claiming beyond
  implemented slices.

---

## Milestone Set F — Release Hardening

### Slice F1: test matrix completion
**Files**
- `docs/TEST_MATRIX.md`
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-release.adb`

**Goal**
- Ensure every new acceptance case is mapped to an explicit test gate.

### Slice F2: benchmarks and bounded render
**Files**
- `benchmarks/`
- `check_i18n/src/check_i18n.adb`

**Goal**
- Keep smoke checks for hot paths and bounded `Render_Into` as hard gates.

---

## Milestone Set G — Expanded Completion Scope

These slices are in scope for completion, but must not be documented as
supported behavior until implementation and release-gate tests are present.

### Slice G1: expanded ICU runtime semantics and execution models
**Files**
- `src/i18n-parser.adb`
- `src/i18n-validation.adb`
- `src/i18n-runtime.adb`
- `src/i18n-compiler.adb`
- `src/i18n-compiled.ads`

**Goal**
- Expand ICU grammar/runtime behavior where needed for completion while keeping
  deterministic validation failures and public facade stability.
- Evaluate bytecode VM or code-generation execution paths only behind internal
  packages until they have release-gate coverage and a documented public
  contract.

### Slice G2: full Unicode text algorithms
**Files**
- `src/i18n-locales.ads`
- `src/i18n-locales.adb`
- `tests/src/i18n-runtime-tests-features.adb`
- `tests/src/i18n-runtime-tests-corpus.adb`

**Goal**
- Move normalization, case mapping, transliteration, collation/search,
  grapheme, line-break, sentence, and word-boundary helpers from bounded
  deterministic subsets toward full Unicode algorithm coverage.

### Slice G3: historical calendars and runtime tzdb ingestion
**Files**
- `src/i18n-date_time_format.adb`
- `src/i18n-runtime_data.adb`
- `src/i18n-runtime_data.ads`
- `cldr/src/check_tzdb_sources.adb`
- `tests/src/i18n-runtime-tests-features.adb`

**Goal**
- Add broader historical calendar databases and runtime ingestion of external
  tzdb data without weakening deterministic fallback or transactional load
  failure behavior.

### Slice G4: full CLDR RBNF behavior
**Files**
- `src/i18n-number_format.adb`
- `src/i18n-runtime_data.adb`
- `src/i18n-runtime_data.ads`
- `cldr/src/import_cldr_raw.adb`
- `cldr/src/extract_cldr_normalized.adb`
- `tests/src/i18n-runtime-tests-features.adb`

**Goal**
- Expand from the current deterministic spellout/RBNF subset to full CLDR RBNF
  rule-set behavior, including parser, data import, runtime validation, and
  locale fallback coverage.

---

## Execution Pattern

Run in ascending pass order:

1. **A → B → C → E → D → F → G** for safe layering (parser/format rules before data
   expansion, behavior contracts before tooling hardening).
2. Finish one slice at a time and close it only when gate checks pass.
3. After each slice:
   - run impacted tests (`features` + targeted corpus cases)
   - run `check_i18n --skip-alr-test`
   - update docs/contracts only when behavior is fully implemented.

## Slice close criteria (required)

- Compilation and unit tests pass on the modified slice area.
- New behavior covered by at least one feature test and one corpus test.
- No public API contract mismatch in `API.md`/`ICU_SUBSET.md`.
- Guard checks (where touched file set is in scope) updated and green.
