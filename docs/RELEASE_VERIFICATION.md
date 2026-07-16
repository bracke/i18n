# Release Verification Status

This document records what must be verified before tagging ICU Messages Ada v1.1.0. Documentation and metadata describe the intended public contract; the compiler remains the authority for Ada visibility, private-child legality, elaboration rules, project-file source inclusion, and warning cleanliness.

## Verified GNAT/GPRbuild checks

Run the shared project-tools-based release guard for every release candidate:

```sh
alr test
```

The manifest test action builds and runs `check_i18n`, the Ada release guard backed by the sibling `project_tools` crate. The action invokes `check_i18n --skip-alr-test` so the guard does not recursively invoke `alr test`.

For local guard development, the equivalent direct command is:

```sh
cd check_i18n
alr build
./bin/check_i18n
cd ..
```

These checks establish that the core library builds, the test project builds, the AUnit suite runs successfully, the public examples build and match `examples/EXPECTED_OUTPUT.md`, the project_tools-based release guard passes, GNATprove accepts SPARK legality for enabled units, GNATdoc generation works, Alire build/test actions pass, and GNAT accepts the private-child package structure used by the tests.

The build is free of the GNAT warning about `I18N.Errors.Result` object creation possibly raising `Storage_Error`; the internal result value uses non-discriminated storage.

## Verification flow

The full verification flow is:

```text
alr build
cd tests && alr exec -- gprbuild -P tests.gpr
cd tests && alr exec -- ./bin/tests
alr exec -- gprbuild -P examples/examples.gpr -j1
cd check_i18n && ./bin/check_i18n --examples-only
alr exec -- gprbuild -P benchmarks/benchmarks.gpr -j1
./benchmarks/bin/render_benchmarks --smoke
alr exec -- gnatdoc -P i18n.gpr
cd check_i18n && alr build
cd check_i18n && ./bin/check_i18n --skip-alr-test
alr test
```

The explicit steps make test, example build/output, documentation,
project-tools, and Alire packaging failures visible in one run, and use
`alr test` as the gate that executes the full package test action.

## Alire publication readiness audit

`check_i18n` runs the Alire publication readiness audit through
`Project_Tools.Alire_Manifests`, `Project_Tools.Release_Checks`, and
`Project_Tools.Files`. The audit requires the root manifest to be pin-free,
named `i18n`, declare publication metadata, expose only `i18n.gpr` as the
primary project file, include the supported GNAT dependency, and route the Alire
test action through the project-tools-based release guard.

The audit also requires the MIT license file, packaging documentation, and
release checklist entries to remain present so publication metadata does not
drift from the release process.

## Publication checks run by the guard

The release guard runs the publication checks through `project_tools`:

```sh
alr exec -- gprbuild -P examples/examples.gpr -j1
cd check_i18n && ./bin/check_i18n --examples-only
alr exec -- gprbuild -P benchmarks/benchmarks.gpr -j1
./benchmarks/bin/render_benchmarks --smoke
cd cldr && alr exec -- gprbuild -P cldr_tools.gpr
cd cldr && ./bin/check_cldr_sources --check
cd cldr && ./bin/check_tzdb_sources --check
cd cldr && ./bin/generate_cldr_export --check
cd cldr && ./bin/import_cldr_raw --check
cd cldr && ./bin/extract_cldr_normalized --check
cd cldr && ./bin/import_cldr_subset --check
cd cldr && ./bin/generate_cldr_data --check
alr build
alr exec -- gnatdoc -P i18n.gpr
alr exec -- gnatprove -P i18n.gpr --level=0 --mode=check
```

`alr test` is the required full gate and runs the manifest-declared test action. The release is not publication-ready if any command launched by `check_i18n` fails.

## Private-package sealing checks

The implementation packages are declared as Ada private child units. GNAT must confirm that:

* ordinary example applications cannot import private implementation packages;
* in-tree regression tests under `I18N.Runtime.Tests.*` can legally import `I18N.Runtime.Compatibility`;
* internal implementation bodies can legally import the private child units they use;
* project files include the renamed test units and do not include stale unit names.

The compile-only public examples are the boundary checks. They should import only:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Plurals;
with I18N.Diagnostics;
```

No application example may import `I18N.Parser`, `I18N.Validation`, `I18N.Compiler`, `I18N.Cache`, `I18N.Compiled`, `I18N.Buffer`, `I18N.Errors`, `I18N.Render`, `I18N.Fast_Render`, `I18N.Observability`, `I18N.AST`, or `I18N.Runtime.Compatibility`.

## Public render allocation statement

The public catalog API is:

```ada
function Render
  (Item      : I18N.Runtime.Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : I18N.Arguments.Arguments)
   return I18N.Result.Render_Result;
```

This public function returns a structured result and materializes the result text. It is stable and structured, but it is not the zero-allocation public rendering path.

The public bounded render API is:

```ada
procedure Render_Into
  (Item      : I18N.Runtime.Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : I18N.Arguments.Arguments;
   Target    : in out String;
   Last      : out Natural;
   Status    : out I18N.Result.Render_Status);
```

`Render_Into` is the public allocation-free rendering path. It writes directly into caller-owned storage, reports `Buffer_Overflow` with the prefix that fits, and exposes only the stable public status model.

The v1.1.0 allocation guarantee is therefore:

```text
initialization may allocate;
public Render_Into writes into caller-owned storage without materializing text;
the private compatibility Render_Into path remains covered by fixed-buffer no-allocation checks;
public Render returns a materialized result value.
```

Documentation must not state that public `Render` is itself a zero-allocation API; use public `Render_Into` for that guarantee.

## Catalog storage statement

v1.1.0 uses a line-oriented text authoring catalog and a versioned binary
catalog envelope. Initialization stores normalized locale/key/source entries and
rejects malformed catalog structure deterministically. Public render resolves an
entry by locale/key fallback and evaluates the compiled private runtime entry.
Binary catalogs must use the `I18N-CATALOG-BINARY` magic, `format_version=1`,
`ir_version=1`, `payload=text`, a blank separator line, and then canonical text
catalog payload. They may also use `payload=hex-text`, where the body is ASCII
hex bytes for the same canonical text payload. Unsupported binary versions and
malformed hex payloads are rejected deterministically.

## Final acceptance rule

A release may be tagged only after:

* the verified GNAT/GPRbuild and AUnit checks remain passing;
* public examples compile without internal imports;
* selected publication tooling checks, such as Alire and GNATdoc, pass for the intended release channel;
* private package visibility is accepted by GNAT;
* documentation and machine-readable metadata are regenerated from the final tree.
