# Phase 4 — Execution Plan: RBNF Spellout / Ordinal (number → words)

Turn a number into words: `123 -> "one hundred twenty-three"`, `3 -> "third"`.
This is the first genuine **recursive rule interpreter** in the library — the
data is small, the engine is the whole job. Precedent: `I18N.Plurals` is already
a generated rule engine; RBNF is a bigger, recursive one. Reuses the Phase 1-2
loader, `Cldr_Json`, and per-locale sharding unchanged.

---

## Data (confirmed, v48.2, cldr-rbnf/rbnf/<locale>.json)

```
rbnf.rbnf.<Group>.<%ruleset> = [ ["<base>", "<rule text>"], ... ]   (ordered)
  Group   = SpelloutRules | OrdinalRules   (NumberingSystemRules where present)
  %name   = %spellout-cardinal, %spellout-ordinal, %spellout-numbering,
            gendered/case variants (%spellout-cardinal-feminine, ...),
            and %%private helper rulesets
```
~89 locales ship RBNF. Rule text grammar (JSON uses the arrow forms):

| Token | Meaning |
|---|---|
| `←←` / `<<` | quotient substitution: format `value / divisor` |
| `→→` / `>>` | remainder substitution: format `value mod divisor` |
| `←%rs←` `→%rs→` | same, but via ruleset `rs` |
| `=%rs=` | format the whole value via ruleset `rs` |
| `=0.0=` / `=#,##0.#=` | format the value via a decimal pattern |
| `[ ... ]` | optional: omitted when the enclosed substitution would be 0 |
| `$(cardinal,one{…}other{…})$` | plural selection on the value |
| special bases | `-x` (negative), `x.x`/`0.x`/`x.0` (fractions), `Inf`, `NaN` |
| `123/100:` | radix/divisor override on a base value |

The **divisor** for a normal rule is `radix ^ floor(log_radix(base))` (radix 10
unless a NumberingSystemRules radix says otherwise), or the explicit `/D`.

---

## Storage — per-locale shard, ruleset-granular

`share/i18n/rbnf/<locale>.i18ndata`, one section:

```
section  ruleset
key      <%ruleset-name>            (e.g. "%spellout-cardinal", "%%and")
value    base1 \x1f text1 \x1e base2 \x1f text2 \x1e ...   (rules, in order)
```

Rule **selection is numeric** ("largest base ≤ N"), which the loader's exact-key
bisection can't do — so a whole ruleset is one value; the engine loads it with a
single `Lookup`, parses it once, caches it, and does numeric selection in memory.
This keeps the loader untouched and puts all RBNF logic in the engine.

---

## Workstream A — Generator

`generate_cldr_rbnf_data.adb` (new tool): read `cldr-rbnf/rbnf/<locale>.json`;
for each Group and each `%ruleset`, serialize its `[base, text]` list into the
value above; write one shard per locale. The rules are a JSON **array of
2-element arrays** — add a tiny `For_Each_Pair` (or array-of-arrays walk) to
`Cldr_Json`, or parse the pairs inline. Deterministic; gitignored; best-effort in
`regenerate.sh`.

## Workstream B — The engine (the phase) — `I18N.Spellout`

- Ruleset store: `Load (Locale, Name) -> parsed ruleset` (cache per locale+name;
  parse base tokens into: Numeric(value), Negative, Fraction kinds, Inf, NaN,
  plus optional `/divisor`).
- `Format (Value, Ruleset)` — recursive interpreter:
  1. dispatch special bases (sign, fraction, Inf/NaN) before numeric selection;
  2. pick the rule with the largest numeric base ≤ Value;
  3. compute the divisor;
  4. walk the rule text emitting literals and expanding tokens:
     - `←←`/`←%rs←` → recurse on `Value / divisor` (this ruleset / `rs`),
     - `→→`/`→%rs→` → recurse on `Value mod divisor`,
     - `=%rs=` → recurse whole Value via `rs`; `=pattern=` → decimal format,
     - `[ … ]` → include iff the governing sub-value ≠ 0,
     - `$(…)$` → plural pick via the existing `I18N.Plurals`,
  5. depth guard against pathological recursion.
- Public API:
  - `Spell (Locale, Value : Long_Long_Integer;
           Ruleset : String := "%spellout-cardinal") return String`
  - `Ordinal (Locale, Value; Ruleset := "%spellout-ordinal")` convenience,
  - the `Ruleset` string lets callers reach gendered/case variants for free,
  - `Available (Locale)`.

### Scope for v1
- **Integers** via `%spellout-cardinal` and `%spellout-ordinal` (and any ruleset
  the caller names, incl. gendered variants) across the ~89 RBNF locales.
- Substitutions `←← →→ =%..= [...]`, ruleset calls, negatives.
- **`$(…)$` plurals** wired through `I18N.Plurals` (present in the lib).
- **Deferred (4'):** fraction spelling (`x.x` → delegate to number formatting or
  spell digit-by-digit — v1 may format the fractional part with a decimal
  pattern), non-decimal radices (NumberingSystemRules), and very large /
  arbitrary-precision values (v1 caps at Long_Long_Integer). State these gaps.

## Workstream C — cascade / gitignore / features

`regenerate.sh generate_runtime_data` gains an rbnf step (guarded on
`cldr-rbnf`); `.gitignore /share/i18n/rbnf/`; a `features` toggle.

## Workstream D — Tests

No official RBNF conformance fixtures are vendored in cldr-json, so validate
against **well-known ICU outputs**:
- self-contained AUnit: a tiny hand-written English-like ruleset exercising
  quotient/remainder/optional/ruleset-call/negative, so the interpreter is pinned
  independently of the real data;
- real-data spot checks for a few locales (en `123` → "one hundred twenty-three",
  `1000`, `21` → "twenty-one", ordinal `3` → "third"; de `21` →
  "einundzwanzig"), guarded by `Available`.

---

## Sequencing

```
A generator → B engine (recursive interpreter — the work) → C cascade → D tests
```
Land behind `features`; the engine is one commit once the interpreter passes the
hand-written ruleset and the real-data spot checks.

## Risks / decisions

- **The interpreter is the hardest thing built so far.** Budget the phase for it;
  the data/generator is trivial. Pin it with the self-contained ruleset first.
- **Divisor computation and `[...]` semantics** are the classic RBNF bug sources
  — implement straight from TR35 and cross-check against ICU for representative
  numbers (round hundreds/thousands, teens, 21, 100, 1000, 1000000).
- **Recursion + caching**: rulesets call each other; cache parsed rulesets and
  guard depth.
- **Fractions / big numbers / non-decimal radices** are explicitly out of v1 —
  say so, since "spell 3.14" or 10^20 will otherwise look like bugs.
- **Plurals** already exist in-library — reuse `I18N.Plurals`, don't reimplement.
