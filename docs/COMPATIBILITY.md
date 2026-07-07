# Compatibility Policy

## Source compatibility

The source-compatibility boundary covers only the public packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`
* `I18N.Plurals`

Allowed after v1.1.0:

* adding overloads;
* adding deterministic helper functions to stable public packages, such as
  bounded locale collation/search/segmentation helpers, without changing
  existing render or fallback semantics;
* adding diagnostic categories without changing existing meanings;
* adding ICU features that do not change accepted v1.1.0 behavior;
* improving performance;
* adding new catalog tooling while preserving the v1.1.0 authoring format.

Forbidden after v1.1.0:

* renaming public packages;
* changing existing public status meanings;
* removing public functions from the stable packages;
* changing locale fallback semantics;
* silently changing missing-key, missing-argument, or invalid-argument behavior;
* silently changing the deterministic date/time output rules for accepted catalogs;
* silently changing the deterministic grouped number output rules for accepted catalogs;
* silently changing the deterministic currency output rules for accepted catalogs;
* requiring applications to import parser/compiler/cache/IR packages.

## Runtime/catalog compatibility

The release defines a text authoring catalog format and a versioned binary
catalog envelope. Text catalogs are deterministic line-oriented source catalogs.
Binary catalogs use the `I18N-CATALOG-BINARY` magic, `format_version=1`,
`ir_version=1`, `payload=text`, a blank line, then the canonical text payload.
They may also use `payload=hex-text`, where the body is ASCII hex bytes for
the same canonical text payload.
Initialization and shard loading parse, validate, and compile each message once
and store the compiled entry behind a normalized locale/key index, rejecting
malformed catalog structure deterministically.

The v1.1 binary header includes:

```text
magic
format version
IR version
payload kind
```

Unsupported binary versions must be rejected deterministically.

## Internal package stability

Internal and compatibility-only packages may change without source-compatibility guarantees. They remain visible in the source tree for implementation and regression tests, but application code must not depend on them.


## Release verification

The compatibility boundary is backed by the project-tools-based release verification guard in `docs/RELEASE_VERIFICATION.md`, including the library build, test project build, AUnit run, example-project build and output checks, CLDR data-boundary checks, Alire build/test checks, render benchmark smoke checks, GNATdoc, and GNATprove for the intended release channel.
