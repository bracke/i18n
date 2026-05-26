# Compatibility Policy

## Source compatibility

The v1.0 source-compatibility boundary covers only the public packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`

Allowed after v1.0:

* adding overloads;
* adding diagnostic categories without changing existing meanings;
* adding ICU features that do not change accepted v1.0 behavior;
* improving performance;
* adding new catalog tooling while preserving the v1.0 authoring format.

Forbidden after v1.0:

* renaming public packages;
* changing existing public status meanings;
* removing public functions from the stable packages;
* changing locale fallback semantics;
* silently changing missing-key, missing-argument, or invalid-argument behavior;
* requiring applications to import parser/compiler/cache/IR packages.

## Runtime/catalog compatibility

The current v1.0 release defines a text authoring catalog format, not a persistent binary compiled catalog format. Catalogs are deterministic line-oriented source catalogs. Public initialization stores normalized locale/key/source entries and rejects malformed catalog structure deterministically; persistent compiled catalogs are not part of v1.0.

If a future binary catalog format is introduced, it must include at least:

```text
magic
format version
default locale
message count
IR version
```

Unsupported binary versions must be rejected deterministically.

## Internal package stability

Internal and compatibility-only packages may change without source-compatibility guarantees. They remain visible in the source tree for implementation and regression tests, but application code must not depend on them.


## Release verification

The core compatibility boundary is backed by a GNAT/GPRbuild build of the library and test project plus a passing AUnit run for this handoff. Public publication should still include example-project and packaging/documentation tooling verification for the intended release channel.
