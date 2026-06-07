# Release Verification Status

This document records what must be verified before tagging ICU Messages Ada v1.0. Documentation and metadata describe the intended public contract; the compiler remains the authority for Ada visibility, private-child legality, elaboration rules, project-file source inclusion, and warning cleanliness.

## Verified GNAT/GPRbuild checks

Run these checks for every release candidate:

```sh
gprbuild -P i18n.gpr
cd tests
alr exec -- gprbuild -P tests.gpr
./bin/tests
cd ..
```

These checks establish that the core library builds, the test project builds, the AUnit suite runs successfully, and GNAT accepts the private-child package structure used by the tests.

The build is free of the GNAT warning about `I18N.Errors.Result` object creation possibly raising `Storage_Error`; the internal result value uses non-discriminated storage.

## Remaining publication checks

Before publishing or tagging a public v1.0 release, also run:

```sh
gprbuild -P examples/examples.gpr
alr build
gnatdoc -P i18n.gpr
```

Run `alr test` as well if an Alire test action is added to the manifest or local release process. The release is not publication-ready if any required local publication command fails.

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

This public function returns a structured result and materializes the result text. The strict fixed-buffer no-allocation release check applies to the private compatibility path used by in-tree regression tests, not to a public application-facing `Render_Into` API.

The v1.0 allocation guarantee is therefore:

```text
initialization may allocate;
compiled execution uses the fixed-buffer compatibility path for no-allocation checks;
public Render returns a materialized result value.
```

Documentation must not state that public `Render` is itself a zero-allocation API.

## Catalog storage statement

v1.0 uses a line-oriented text authoring catalog. Initialization stores normalized locale/key/source entries and rejects malformed catalog structure deterministically. Public render resolves an entry by locale/key fallback and evaluates the stored source through the public catalog render path. Persistent binary compiled catalogs are not shipped in v1.0.

The release does not define a persistent binary compiled catalog. No file format with magic/version/default-locale/message-count/IR-version is shipped in v1.0.

If binary catalogs are added later, they must be explicitly versioned and unsupported versions must be rejected deterministically.

## Final acceptance rule

A release may be tagged only after:

* the verified GNAT/GPRbuild and AUnit checks remain passing;
* public examples compile without internal imports;
* selected publication tooling checks, such as Alire and GNATdoc, pass for the intended release channel;
* private package visibility is accepted by GNAT;
* documentation and machine-readable metadata are regenerated from the final tree.
