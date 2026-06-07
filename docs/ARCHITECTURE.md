# Architecture

The release architecture has one application-facing production path:

```text
text catalog -> deterministic catalog validation -> locale/key lookup -> public ICU evaluation -> public render result
```

Initialization is the only operation allowed to read text catalog files and populate public catalog state. Catalog entries retain normalized locale/key/source identity for deterministic lookup. Public rendering resolves a catalog entry by locale/key fallback and evaluates the stored source through the public catalog render path. Internal regression paths exercise parser, validator, compiler, cache, and fixed-buffer execution components for internal invariants, but public callers never receive parser objects, compiled handles, cache objects, or buffer internals.

## Runtime structure

```text
I18N.Runtime.Instance
  catalog entries: normalized locale + key + source identity
  default locale
  initialization validity state
  compatibility single-message state for regression tests

Parser -> Validator -> Compiler -> Compiled Message / Cache
                                         |
                                         v
                                Execution Engine
                                         |
                                         v
                               I18N.Result.Render_Result
```

The source tree contains private compatibility entry points and white-box test packages. They exist to preserve regression coverage and semantic continuity. They are not part of the application-facing v1.0 compatibility contract.

## Public/internal boundary

Public packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`

Internal or compatibility-only packages:

* parser and AST packages
* validation packages
* compiler and compiled-message packages
* cache packages
* buffer and fast-render packages
* lower-level renderer packages
* fuzz/corpus harness packages

Application examples for the frozen API must compile without importing internal packages.

## Data ownership

The runtime owns catalog metadata and initialization validity state. Catalog entries are lookup records containing normalized locale/key/source data, not public compiled-message handles. Public render calls accept a limited argument map and do not expose ownership of internal parser, cache, or compiled structures.

## Diagnostics

Diagnostics are optional and observational. Enabling callbacks or storing diagnostic detail must not change message selection, output text, result status, cache contents, runtime contents, or IR contents. Callback exceptions are contained.

## Release cleanup rule

No application-facing release feature may require parser cursors, cache maps, IR arrays, VM/codegen experiments, prototype packages, or non-public AST execution paths. Those may remain only when needed as implementation details or regression-test support, and they must stay out of public examples and v1.0 documentation examples.


## Release verification boundary

The release boundary is verified by the commands in `docs/RELEASE_VERIFICATION.md`: the core library build, test project build, AUnit runner, example project, Alire build, and selected documentation tooling must pass for the intended release channel.
