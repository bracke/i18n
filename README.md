# ICU Messages Ada

i18n is an Ada 2022 message-formatting library for a strict, deterministic ICU-style subset. The v1.0 application-facing contract is catalog-based:

```text
catalog file -> initialization -> deterministic catalog validation -> locale/key lookup -> structured render result
```

The frozen public v1.0 packages are:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`

Applications should not depend on parser, validator, compiler, AST, compiled IR, cache, buffer, or lower-level renderer packages. Those packages remain in the source tree for implementation and regression testing, but they are outside the v1.0 source-compatibility guarantee.

## Supported ICU subset

v1.0 supports:

* literal text
* variables: `{name}`
* plural blocks with required `other`
* select blocks with the frozen v1.0 branch names `male`, `female`, and required `other`
* selectordinal blocks with required `other`
* nesting of supported constructs
* `#` substitution in plural and selectordinal branches

Unsupported features include CLDR plural-data compilation, date/time/number formatting, arbitrary select branch names, plural offsets, bytecode/code generation, and public parser/compiler access.

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

The test suite is the release gate and includes parser, validator, compiler/cache regression, IR equivalence, render, plural/select/selectordinal, locale fallback, diagnostics, fuzz smoke, corpus regression, concurrency, zero-allocation compatibility-path checks, and public API freeze checks. See `docs/TEST_MATRIX.md` and `docs/RELEASE_VERIFICATION.md`.

## Ada-level API sealing

`I18N.Arguments` maps are mutable and noncopyable. Create them as local objects, update them with `Set`/`Clear`, pass them to `Render`, and use `I18N.Arguments.Copy` when an explicit duplicate is needed; do not depend on whole-object assignment.

The v1.0 public surface is not just documented; it is enforced with Ada visibility. Implementation units such as `I18N.Parser`, `I18N.Compiler`, `I18N.Cache`, `I18N.Errors`, `I18N.Runtime.Compatibility` are declared as private child packages. Ordinary applications should import only the stable public package set: `I18N`, `I18N.Runtime`, `I18N.Result`, `I18N.Arguments`, `I18N.Locales`, and optionally `I18N.Diagnostics`.


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

Before publishing or tagging v1.0, run the release verification commands in `docs/RELEASE_VERIFICATION.md`. The required checks include the library build, test project build, AUnit runner, example project, Alire build, and selected documentation tooling. Treat any recurrence of the `I18N.Errors.Result` `Storage_Error` warning as a release blocker.

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
