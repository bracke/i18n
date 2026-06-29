# Public Import Rules

The release enforces the API boundary with Ada visibility, not only with documentation.

## Allowed application imports

Application code may import these stable public packages:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Plurals;
with I18N.Diagnostics;
```

`I18N.Plurals` provides CLDR plural-category classification. `I18N.Diagnostics` is optional and observational.

## Forbidden downstream imports — do not write this

The following units are Ada private child packages and are not legal ordinary application imports. They are shown only as a negative example for humans and AI tools:

```ada
with I18N.AST;
with I18N.Buffer;
with I18N.Cache;
with I18N.Compiled;
with I18N.Compiler;
with I18N.Errors;
with I18N.Fast_Render;
with I18N.Observability;
with I18N.Parser;
with I18N.Render;
with I18N.Runtime.Compatibility;
with I18N.Validation;
```

These units exist for implementation internals and in-tree descendant regression tests. Their declarations may change without breaking the v1.0 public compatibility contract.

## Regression tests

The AUnit regression suites are declared under the `I18N.Runtime.Tests.*` namespace. This is intentional: those units are descendants of both `I18N` and `I18N.Runtime`, so they may legally import `I18N` private child packages and the private child `I18N.Runtime.Compatibility`. That exception does not apply to downstream application code.

## Public example gate

`examples/public_api_sealed.adb` intentionally imports only stable public packages. It is the reference import pattern for downstream consumers and AI tools.


## Verification

These import rules are intended to be compiler-enforced. Run the commands in `docs/RELEASE_VERIFICATION.md` before tagging v1.0 so GNAT confirms both public-example imports and private-child regression-test access.
