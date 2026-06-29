# Examples

The `examples` directory contains a comprehensive series of small programs
that exercise the stable v1.0 public API. The examples are intentionally narrow:
each one demonstrates one release-contract behavior and avoids direct dependency
on parser, compiler, IR, cache, or execution internals.

## Build

From the repository root:

```sh
gprbuild -P examples/examples.gpr
```

The example executables are emitted into the `examples/` directory by the example
project file. Run them from the repository root, for example `./examples/bin/hello_world`,
so relative catalog paths resolve correctly.

## Shared catalog

The maintained example suite is indexed in `examples/EXAMPLES_INDEX.md`. Command-by-command expected output is in `examples/EXPECTED_OUTPUT.md`.

Most examples use:

```text
examples/catalogs/messages.catalog
```

The catalog demonstrates the canonical v1.0 line-oriented format:

```text
default_locale = en
en.hello = "Hello, {name}!"
de-AT.hello = "Servus, {name}!"
```

Additional invalid catalogs under `examples/catalogs` are used by the
catalog validation example.

## Example programs

| Program | Purpose |
| --- | --- |
| `hello_world.adb` | Shortest start-here example matching the quickstart flow. |
| `basic_render.adb` | Initialize a runtime, set one argument, render one message. |
| `plural_render.adb` | Render `plural` branches for `one` and `other`. |
| `select_render.adb` | Render `select` branches and the required `other` fallback branch. |
| `selectordinal_render.adb` | Render `selectordinal` branches and `#` substitution. |
| `nested_message_render.adb` | Render nested `select` plus nested `plural` from one message. |
| `locale_fallback.adb` | Demonstrate exact locale, parent locale, and default locale fallback. |
| `fallback_chain.adb` | Explicitly show `de-AT -> de -> en` fallback in one program. |
| `missing_key.adb` | Show the stable `Missing_Key` result status. |
| `missing_argument.adb` | Show the stable `Missing_Argument` result status. |
| `invalid_argument.adb` | Show the stable `Invalid_Argument` status for non-numeric plural input. |
| `invalid_catalog.adb` | Show deterministic initialization failure for duplicate and invalid catalog input. |
| `invalid_catalog_fields.adb` | Show deterministic rejection of empty locale, key, and default-locale fields. |
| `diagnostics_non_interference.adb` | Show that a raising diagnostic trace callback cannot alter rendering. |
| `equals_in_value.adb` | Show that catalog values may contain `=` after the first separator. |
| `reuse_runtime.adb` | Reuse one initialized runtime for multiple independent renders. |
| `status_handling.adb` | Exhaustively handle the frozen public `Render_Status` values. |
| `diagnostics_inspection.adb` | Inspect diagnostic entries returned with an error `Render_Result`. |
| `default_locale_key.adb` | Show that unqualified catalog entries belong to the configured default locale. |
| `empty_message.adb` | Show that an explicitly present empty message is `Success` with empty output. |
| `argument_lifecycle.adb` | Demonstrate public argument map `Set`, `Has`, `Get`, and `Clear`. |
| `public_api_example.adb` | Minimal downstream-style render using only public packages. |
| `public_api_sealed.adb` | Public import-boundary smoke example covering the allowed package set. |

## Public API boundary

The examples use only stable public packages. The complete allowed application import set is:

```ada
with I18N;
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Result;
with I18N.Runtime;
```

### Forbidden downstream imports — do not write this

The following import pattern is intentionally invalid for ordinary applications and AI-generated examples:

```ada
with I18N.Parser;
with I18N.Compiler;
with I18N.IR;
with I18N.Cache;
```

Those units are implementation/private-regression surfaces. That boundary is part of the v1.0 release contract.

## Expected behavior

The examples are documentation examples, not replacements for the AUnit release
gate. They should remain simple enough to inspect manually. The formal test suite
still owns exhaustive parser, validator, compiler, IR-equivalence, corpus,
diagnostics, threading, and allocation checks.
