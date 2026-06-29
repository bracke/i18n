# ICU Messages Ada

i18n is an Ada 2022 message-formatting library for a strict, deterministic ICU-style subset. The v1.0 application-facing contract is catalog-based:

```text
catalog file -> initialization -> deterministic catalog validation -> locale/key lookup -> structured render result
```

The stable public packages are:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Applications should not depend on parser, validator, compiler, AST, compiled IR, cache, buffer, or lower-level renderer packages. Those packages remain in the source tree for implementation and regression testing, but they are outside the source-compatibility guarantee.

## Supported ICU subset

The ICU subset supports:

* literal text
* variables: `{name}`
* plural blocks with required `other`
* select blocks with **arbitrary validated identifier branch names** and a required `other` branch (the legacy `male`/`female`/`other` branches keep working unchanged)
* selectordinal blocks with required `other`
* nesting of supported constructs
* `#` substitution in plural and selectordinal branches

Generalized select example:

```text
{width, select, full {hour} short {hr} narrow {h} other {hour}}
```

`other` is required, duplicate branches are rejected, unmatched selector values use `other`, and branch names must be valid identifiers.

Out of scope: date/time/number formatting, plural offsets, code generation, and public parser/compiler access. Application-domain formatting (relative time, durations, byte sizes, compact numbers, ordinal wording, unit humanization) is intentionally **not** part of `i18n` and belongs in libraries built on top of it.

## Catalog format

The canonical v1.0 catalog format is line-oriented text:

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
```

`default_locale` may appear anywhere, but it may appear at most once and must not be empty. Entries use `locale.key = ICU message`. Duplicate `locale.key` entries, empty locale names, empty keys, malformed lines, and unbalanced catalog message braces make initialization invalid deterministically. Deeper ICU construct errors are reported deterministically by render/status paths and regression tests.

## Minimal example

```ada
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Example is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, "messages.catalog");
   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "welcome",
           Arguments => Args);
   begin
      if Result.Status = I18N.Result.Success then
         null; -- I18N.Result.Output_Text (Result.Text) contains the rendered message.
      end if;
   end;
end Example;
```

## Runtime behavior

Initialization reads the text catalog, records deterministic failure state if the catalog file itself is invalid, and stores normalized locale/key/source entries for lookup. Public rendering resolves locale fallback, locates the stored source, and evaluates it through the public catalog render path. Internal regression paths exercise the parser/validator/compiler/cache pipeline for the strict ICU subset and fixed-buffer execution checks, but public callers never receive parser, compiler, cache, or compiled-message handles. Public `Render` does not raise for normal message failures; it returns `I18N.Result.Render_Result` with a stable `Render_Status`.

Locale fallback is fixed as:

```text
de-AT -> de -> default locale
```

If the key is still absent after fallback, render returns `Missing_Key`.

Catalog entries are parsed, validated, and compiled to an AST **once at load time** and stored behind a deterministic `(locale, key)` index. Rendering fetches the compiled entry (O(1) per locale, bounded by locale fallback depth) and executes it (O(output length)); it never re-parses message source on the hot path.

## Catalog shard loading

A single runtime can layer multiple catalog shards, for example a base application catalog, an optional library catalog, and an optional user override shard:

```ada
declare
   Runtime : I18N.Runtime.Instance;
   Result  : I18N.Runtime.Load_Result;
begin
   I18N.Runtime.Initialize (Runtime, "app.catalog");          -- base
   I18N.Runtime.Load_File  (Runtime, "lib.catalog", Result);  -- library shard
   I18N.Runtime.Load_File  (Runtime, "user.catalog", Result,
                            Policy => I18N.Runtime.Override_Previous);
end;
```

`Load_File` and `Load_Text` are transactional and non-destructive: either every entry in the input is ingested or the runtime is left exactly as it was. A failed shard load never corrupts an already usable runtime. The outcome is reported in `Load_Result` (`Status`, `Entries_Added`, `Entries_Replaced`, `Entries_Ignored`, `Diagnostics`); statuses are `Loaded`, `Source_Not_Found`, `Invalid_Catalog`, `Duplicate_Rejected`, and `Runtime_Invalid`. The counters distinguish newly added pairs, entries overwritten under `Override_Previous`, and duplicates skipped under `Keep_First`.

A `default_locale` directive is adopted only when the runtime has no default locale yet, so a runtime can be built entirely from `Load_Text`/`Load_File`. Once `Initialize` (or an earlier load) has established the default locale, later shard directives are ignored.

`Load_Text` ingests an in-memory catalog string with the same semantics, using a caller-supplied source name for diagnostics.

### Duplicate policy

`Duplicate_Policy` controls how an incoming `locale/key` that already exists is handled:

| Policy | Behavior |
| --- | --- |
| `Reject_Duplicates` (default) | Loading fails on any duplicate; prior entries are unchanged. |
| `Keep_First` | The existing entry stays active; the duplicate is ignored. |
| `Override_Previous` | The new entry replaces the previous entry. |

## Non-destructive validation

`Validate_Catalog_File` and `Validate_Catalog_Text` parse and validate a catalog without touching any runtime. They return a `Catalog_Validation_Result` (`Valid`, `Entry_Count`, `Diagnostics`) and detect invalid catalog syntax, invalid locale prefixes, invalid keys, invalid ICU messages, missing required `other` branches, and duplicate keys within the input. If validation fails, any existing runtime remains usable.

## Key resolution

`Resolve` reports whether a key is reachable through the locale fallback chain **without rendering it** and without requiring arguments:

```ada
R : constant I18N.Runtime.Resolve_Result :=
  I18N.Runtime.Resolve (Runtime, "de-AT", "welcome");
--  R.Status is Found / Missing_Key / Runtime_Invalid
--  I18N.Runtime.Resolved_Locale (R) is the locale that satisfied the request
```

## Argument helper setters

Arguments remain string-valued, with helpers that serialize common values correctly:

```ada
I18N.Arguments.Set_Integer (Args, "delta", -3);   -- "-3" (strict decimal, no 'Image space)
I18N.Arguments.Set_Natural (Args, "count", 0);     -- "0"
I18N.Arguments.Set_Boolean (Args, "active", True); -- "true" / "false"
```

These helpers are deterministic and intentionally **not** locale-aware; they prepare selector/argument values for the message engine.

## Plural categories

`I18N.Plurals` classifies an integer value into a CLDR plural category for a locale:

```ada
I18N.Plurals.Cardinal ("en", 1);  -- One
I18N.Plurals.Ordinal  ("en", 2);  -- Two   ("2nd")
I18N.Plurals.Ordinal  ("en", 3);  -- Few   ("3rd")
```

Categories are `Zero`, `One`, `Two`, `Few`, `Many`, `Other`. Cardinal rules cover `en`, `de`, `nl`, `es`, `it`, `fr`, `pt`, `ru`, `pl`, `cs`, and `ar` — the Slavic and Arabic rules cover all six categories. Ordinal rules are modelled for `en`, `fr`, and `it`. Classification operates on integer values (fraction digits zero) using the absolute value as the CLDR operand `n`; locales outside these sets resolve through their language subtag to the root rule (`Other`).

The public catalog render path uses these rules to pick `plural` and `selectordinal` branches by the **resolved** locale, so English `{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}` correctly renders `21st`, `22nd`, `23rd`, and `11th`/`12th`/`13th`. A plural/ordinal category with no matching branch falls back to `other`. (The internal compatibility/IR render path used only by in-tree regression tests remains locale-agnostic.)

## Bounded rendering

`Render_Into` renders the compiled message directly into caller-owned fixed storage — each fragment is written straight into the buffer, with no intermediate dynamic allocation:

```ada
Buffer : String (1 .. 256);
Last   : Natural;
Status : I18N.Result.Render_Status;
...
I18N.Runtime.Render_Into (Runtime, "en", "welcome", Args, Buffer, Last, Status);
--  Success: Buffer (Buffer'First .. Last) holds the output.
--  Buffer_Overflow: Buffer holds the prefix that fits and Last is the last written index.
--  Other failure: Last = 0.
```

## Threading and allocation

A successfully initialized runtime is intended to be shared for concurrent read-only rendering. Initialization is setup-time work and may allocate. The lower-level `I18N.Runtime.Compatibility.Render_Into` path uses caller-owned storage for fixed-buffer execution checks and lives behind Ada private-child visibility for in-tree regression tests; it is not part of the v1.0 application API. The public `Render` facade returns a structured result and materializes the final result string after execution. Do not describe public `Render` as a zero-allocation API.

## Build and tests

```sh
gprbuild -P i18n.gpr
cd tests
alr exec -- gprbuild -P tests.gpr
./bin/tests
cd ..
```

The test suite is the release gate and includes parser, validator, compiler/cache regression, IR equivalence, render, plural/select/selectordinal, locale fallback, diagnostics, fuzz smoke, corpus regression, concurrency, zero-allocation compatibility-path checks, and public API freeze checks. See `docs/TEST_MATRIX.md`, `docs/RELEASE_VERIFICATION.md`, and `docs/SPARK.md`.

## Ada-level API sealing

`I18N.Arguments` maps are mutable and noncopyable. Create them as local objects, update them with `Set`/`Clear`, pass them to `Render`, and use `I18N.Arguments.Copy` when an explicit duplicate is needed; do not depend on whole-object assignment.

The public surface is not just documented; it is enforced with Ada visibility. Implementation units such as `I18N.Parser`, `I18N.Compiler`, `I18N.Cache`, `I18N.Errors`, `I18N.AST`, `I18N.Runtime.Compatibility` are declared as private child packages. Ordinary applications should import only the stable public package set: `I18N`, `I18N.Runtime`, `I18N.Result`, `I18N.Arguments`, `I18N.Locales`, `I18N.Plurals`, and optionally `I18N.Diagnostics`.

## Supported locales and deferred functionality

Locale identifiers are arbitrary BCP-47-style strings used as catalog keys; fallback removes the rightmost subtag and finally falls back to the runtime default locale. Plural-category classification ships cardinal rules for `en`, `de`, `nl`, `es`, `it`, `fr`, `pt`, `ru`, `pl`, `cs`, and `ar`, ordinal rules for `en`/`fr`/`it`, and a root fallback that covers everything else.

Out of scope by design — these belong in libraries built on top of `i18n`: number, date, and time formatting; plural offsets; and all application-domain formatting policy (relative time, durations, byte sizes, compact numbers, ordinal wording, unit humanization). Plural classification is integer-only; additional locales and fractional-digit operands can be added behind the existing `I18N.Plurals` API without breaking it.


## Alire package metadata

The release tree includes `alire.toml` for source-crate consumption. The crate name is `i18n`, the primary project file is `i18n.gpr`, and the package declares an Ada 2022/GNAT dependency. See `docs/PACKAGING.md` before publishing or consuming the crate through Alire.

## Documentation map

* `docs/QUICKSTART.md` — smallest complete catalog/render workflow
* `docs/EXAMPLES.md` — comprehensive v1.0 example program series
* `examples/README.md` — example directory orientation
* `examples/EXPECTED_OUTPUT.md` — command-by-command expected output
* `docs/ARCHITECTURE.md` — runtime structure and public/internal boundary
* `docs/API.md` — stable public API and internal compatibility notes
* `docs/ICU_SUBSET.md` — supported and unsupported message syntax
* `docs/CATALOG_FORMAT.md` — canonical authoring format
* `docs/ERROR_MODEL.md` — public status semantics and deterministic failures
* `docs/THREADING.md` — concurrency and allocation guarantees
* `docs/VALIDATION.md` — release-gate rules
* `docs/TEST_MATRIX.md` — release-gate coverage map
* `docs/COMPATIBILITY.md` — v1.0 source/runtime compatibility policy
* `docs/PUBLIC_API_BOUNDARY.md` — sealed public API surface and compatibility-only packages
* `docs/RELEASE_CHECKLIST.md` — final release audit checklist
* `docs/RELEASE_VERIFICATION.md` — GNAT/GPRbuild verification required before tagging v1.0
* `docs/SPARK.md` — SPARK-enabled units and GNATprove release command
* `docs/AI_CONSUMPTION_GUIDE.md` — project guide for AI tools and maintainers

## AI and tool discoverability

The release includes explicit orientation files for code assistants and automated tooling:

* `AGENTS.md` — contributor instructions and maintenance guardrails.
* `PROJECT_INDEX.md` — repository map by task, package, and file role.
* `docs/AI_CONSUMPTION_GUIDE.md` — guidance for interpreting the public contract.
* `ai/API_MANIFEST.json` — machine-readable public API summary.
* `ai/CONTRACT_SUMMARY.yaml` — compact behavior contract.
* `ai/EXAMPLE_CATALOG.json` — example and catalog inventory.
* `ai/FILE_ROLE_MAP.json` — machine-readable file role classification.

These files are non-runtime metadata. They do not define behavior independently of the Ada specs, docs, and tests, but they make the project easier to inspect and consume correctly.


## Verification status

Before publishing or tagging v1.0, run the release verification commands in `docs/RELEASE_VERIFICATION.md`. The required checks include the library build, test project build, AUnit runner, `check_i18n`, example project, Alire build, and selected documentation tooling. Treat any recurrence of the `I18N.Errors.Result` `Storage_Error` warning as a release blocker.

## v1.0 compatibility boundary

Stable after v1.0:

* public package names listed above
* catalog-oriented `I18N.Runtime.Initialize`
* catalog-oriented `I18N.Runtime.Render`
* `I18N.Result.Render_Status` meanings
* locale fallback semantics
* missing-key and missing-argument behavior
* diagnostics non-interference
* catalog authoring format

Allowed after v1.0: adding overloads, adding diagnostics, adding ICU features that do not change existing behavior, and improving performance.

Forbidden after v1.0: renaming public packages, changing public status meanings, removing public functions, changing fallback semantics, or silently changing missing-argument behavior.
