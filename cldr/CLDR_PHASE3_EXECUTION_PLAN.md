# Phase 3 — Execution Plan: Calendar Names + Person-Name Formatting

Two areas of very different character, delivered on the runtime-data-file model
established in Phases 1-2 (loader, `Cldr_Json`, per-locale sharding — all reused
unchanged):

- **3A Non-Gregorian calendar names** — pure data tables, like the Gregorian
  names the library already compiles in. Easy; mirrors the annotation generator.
  **Names only.** Date *arithmetic* / conversion is Phase 5 — this phase does not
  convert dates, it localizes a caller-supplied calendar index.
- **3B Person-name formatting** — small per-locale *pattern* data plus a real
  **formatting algorithm** (CLDR TR35). This is where the effort is.

Do 3A first (mechanical, builds confidence and a second sharded area); then 3B.

---

## 3A — Non-Gregorian calendar names

### Data (confirmed, v48.2)
```
cldr-cal-<cal>-full/main/<locale>/ca-<cal>.json
  main.<locale>.dates.calendars.<cal>.{months,days,quarters,dayPeriods,eras}
```
- 11 calendars: buddhist, chinese, coptic, dangi, ethiopic, hebrew, indian,
  islamic (+variants e.g. islamic-umalqura), japanese, persian, roc.
- `months`/`days`/`quarters`: `{format|stand-alone}.{wide|abbreviated|narrow}.<index>`
  → name. `dayPeriods`: same shape, keys am/pm/… `eras`:
  `{eraNames|eraAbbr|eraNarrow}.<index>` → name (japanese has ~236 eras).
- Ignore the `dateFormats`/`timeFormats`/`*Skeletons` in these files here — those
  are formatting patterns for Phase 5.

### Storage — per-locale shards (reuse the annotation pattern)
`share/i18n/calendars/<locale>.i18ndata`, one section per calendar, composite key:

```
section  <cal>            (e.g. "islamic-umalqura", "japanese")
key      <field>\x1f<context>\x1f<width>\x1f<index>
              field   = month | day | quarter | day-period | era
              context = format | stand-alone
              width   = wide | abbreviated | narrow   (eras: wide|abbr|narrow)
value    localized name
```
Per-locale sharding fits the access pattern (a caller formats in one locale
across calendars) and reuses the loader untouched. Calendar names are small — a
locale shard is a few tens of KB.

### Workstreams
- **A1 Generator** `generate_cldr_calendar_data.adb` (new tool; `Cldr_Json`
  reused): iterate the 11 `cldr-cal-*` trees; for each locale accumulate all
  calendars' name records; write one shard per locale. Locale parent-fallback is
  the API's job (as in Phase 1-2).
- **A2 API** `I18N.Calendars`:
  - `Calendar_Kind` enum (Gregorian + the 11);
  - `Month_Name (Locale, Calendar, Month, Context, Width)`,
    `Era_Name (Locale, Calendar, Era, Width)`,
    `Day_Name`, `Quarter_Name`, `Day_Period_Name`;
  - `Context` = (Format, Stand_Alone), `Width` = (Wide, Abbreviated, Narrow);
  - width/context fallback per TR35 (narrow→abbreviated→wide etc.), then parent
    locale, then "" ; Gregorian delegates to the existing compiled tables so one
    API covers every calendar.
- **A3** cascade (`regenerate.sh generate_runtime_data`), gitignore
  `/share/i18n/calendars/`, `features` toggle.
- **A4** self-contained AUnit test (islamic month, japanese era, a parent-walk,
  a width fallback).

**Acceptance 3A:** localized month/day/quarter/day-period/era names for all 11
calendars in every locale, with width/context/locale fallback; Gregorian routes
to the existing tables; peak memory is one locale shard.

---

## 3B — Person-name formatting

### Data (confirmed)
```
cldr-person-names-full/main/<locale>/personNames.json → main.<locale>.personNames
  givenFirst / surnameFirst : locale lists that pick default name order
  initial / initialSequence : "{0}." , "{0}{1}"
  nativeSpaceReplacement / foreignSpaceReplacement
  personName.<order>.<length>.<usage>.<formality> = a pattern, e.g.
     "{title} {given} {given2} {surname} {generation}, {credentials}"
     order    = givenFirst | surnameFirst
     length   = long | medium | short
     usage    = referring | addressing | monogram
     formality= formal | informal
```
Small per locale (a few dozen patterns + the config). Store as a per-locale shard
`share/i18n/person-names/<locale>.i18ndata`:

```
section  pattern    key <order>\x1f<length>\x1f<usage>\x1f<formality>  value pattern
section  config     key {order-given|order-surname|initial|initialSequence|
                          native-space|foreign-space}                value
```

### The algorithm (the substance of the phase) — API `I18N.Person_Names`
- A `Name` value: a small field map (given, given2, surname, surname2, title,
  generation, credentials, plus the *given-informal* etc. variants) + the name's
  own locale/script (used for order and native-vs-foreign spacing).
- `Format (Formatter_Locale, Name, Order, Length, Usage, Formality) return String`
  implementing TR35 §"Person Name formatting":
  1. **Order** = explicit param, else derived from the name's locale against the
     formatter's givenFirst/surnameFirst lists.
  2. **Pattern selection** with the documented fallback chains
     (formality informal↔formal, length medium→short→long, usage referring/
     addressing, and the sorting/monogram variants) until a pattern exists.
  3. **Field resolution** with modifiers: `-informal`, `-allCaps`, `-initial`,
     `-initialCap`, `-monogram`, `-prefix`, `-core`, `-genitive` (apply the ones
     CLDR data uses; degrade unknown modifiers to the plain field).
  4. **Missing-field handling**: drop absent `{fields}` *and* the surrounding
     literal run per the TR35 rules (this is the fiddly part), collapse spaces.
  5. **Initials** via `initial`/`initialSequence`; **space replacement** native
     vs foreign; **monogram** usage builds from initials.
- **Scope for 3B v1:** implement order + selection-with-fallback + field
  substitution + missing-field/space handling for the *referring* and
  *addressing* usages (the common cases). Land **monograms**, the full initial
  edge cases, and sentence-casing as a documented follow-up (3B') — they are a
  small share of real use and a large share of the fiddliness.

### Workstreams
- **B1** Generator `generate_cldr_personname_data.adb` → per-locale shards.
- **B2** API `I18N.Person_Names` (the `Name` type + `Format` + the TR35 engine).
- **B3** cascade + gitignore + `features` toggle.
- **B4** Tests: drive CLDR's **personNameTest** fixtures (upstream ships
  `.../personNames/.../*.txt` conformance cases) — this area has real test data,
  so wire a differential harness, not just spot checks. Self-contained AUnit for
  the fallbacks + missing-field handling.

**Acceptance 3B:** `Format` produces the CLDR-correct string for the referring/
addressing usages across the fallback matrix, verified against the upstream
personNameTest fixtures for a sample of locales; missing fields and spacing match
TR35; order derives correctly from the name's locale.

---

## Sequencing

```
3A: A1 generator → A2 API → A3 cascade → A4 test        (mechanical, ~Phase-2 shape)
3B: B1 generator → B2 engine (the work) → B3 cascade → B4 conformance harness
```
Both behind `features`; land 3A and 3B as separate commits so the phase stays
releasable mid-flight.

## Risks / decisions

- **3A is easy, 3B is not.** Budget the phase almost entirely for the person-name
  engine; 3A is a day or two of the annotation pattern.
- **TR35 missing-field rules** (dropping a `{field}` with its adjacent literal)
  are the classic source of person-name bugs — pin them with the upstream
  fixtures from the start (B4 before B2 is "done").
- **Calendar arithmetic stays out.** Make the 3A API explicitly index-in /
  name-out so no one mistakes it for date conversion (Phase 5).
- **Monograms/initials/sentence-case** deliberately deferred in 3B v1 — state it
  so the gap is visible.
- Reuse holds again: loader, `Cldr_Json`, and per-locale sharding are unchanged;
  new code is two generators + `I18N.Calendars` + the `I18N.Person_Names` engine.
