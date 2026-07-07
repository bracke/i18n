# Packaging and Alire Metadata

This project ships an `alire.toml` manifest so the library can be consumed as an
Alire source crate.

## Crate identity

```toml
name = "i18n"
version = "1.1.0"
project-files = ["i18n.gpr"]
```

The crate exposes the static library project `i18n.gpr`. The test and
example project files are shipped for validation and demonstration, but they are
not listed as primary project files in the Alire manifest.

## Public API package set

Alire consumers should depend only on the stable public packages:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Plurals;
with I18N.Diagnostics;
```

Implementation packages such as `I18N.Parser`, `I18N.Compiler`, `I18N.Cache`,
`I18N.Compiled`, `I18N.Errors`, and `I18N.Runtime.Compatibility` are Ada-private
implementation units and are not part of the crate's public source contract.

## Toolchain requirement

The project is written for Ada 2022 and the manifest declares:

```toml
[[depends-on]]
gnat = ">=12"
```

A release verification pass should still be run with the exact GNAT/GPRbuild
version used for publication.

## License

The package metadata declares the crate license as MIT and the release archive
includes the corresponding `LICENSE` file.

## Publication readiness audit

The `alr test` release gate runs an Alire publication readiness audit through
the project-tools-based `check_i18n` guard. The audit requires the root
`alire.toml` to be pin-free, named `i18n`, declare publication metadata
(`description`, `version`, authors, maintainers, maintainer logins, MIT license,
tags, `project-files = ["i18n.gpr"]`, and `gnat = ">=12"`), and route the Alire
test action through `check_i18n`.

The audit also verifies that `LICENSE`, `i18n.gpr`, and the release packaging
documentation are present and consistent, and that the Alire manifest does not
publish the test or example project files as primary project files.

## Local consumption

From another Alire workspace, use the crate as a local dependency during testing:

```sh
alr with --use=/path/to/i18n i18n
```

Then import only the stable public packages listed above.

## Release verification

Before publication, run `alr test`. The manifest test action invokes the
project-tools-based `check_i18n` guard described in
`docs/RELEASE_VERIFICATION.md`.
