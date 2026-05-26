# Public API Boundary

This document records the v1.0 API boundary in a form that is easy to audit.

## Stable application-facing packages

Application code should depend only on these library packages:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Diagnostics;
```

`I18N.Runtime` is the catalog-backed facade. `I18N.Arguments` is the stable argument-map facade. `I18N.Result` is the frozen render-status/result model. `I18N.Locales` defines locale identifiers and fallback helpers. `I18N.Diagnostics` exposes optional non-interfering trace/diagnostic hooks.

## Stable runtime surface

The stable `I18N.Runtime` visible surface is intentionally small:

```ada
type Runtime is tagged limited private;
subtype Instance is Runtime;

procedure Initialize
  (Item         : in out Runtime;
   Catalog_Path : String);

function Render
  (Item      : Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : I18N.Arguments.Arguments)
   return I18N.Result.Render_Result;

function Is_Valid
  (Item : Runtime)
   return Boolean;

procedure Finalize
  (Item : in out Runtime);
```

No application-facing runtime declaration exposes parser state, AST nodes, compiler state, IR opcode arrays, cache maps, buffer internals, or internal error enums.

## Ada-level private implementation packages

The following implementation and regression-support units are declared as Ada `private package` children. They are available only to descendants of the owning parent package and cannot be `with`ed by ordinary downstream application units. Because `I18N.Runtime.Compatibility` is a private child of `I18N.Runtime`, the in-tree regression suites live under `I18N.Runtime.Tests.*`.

```ada
I18N.Runtime.Compatibility
I18N.AST
I18N.Parser
I18N.Validation
I18N.Compiler
I18N.Compiled
I18N.Cache
I18N.Render
I18N.Fast_Render
I18N.Buffer
I18N.Errors
I18N.Observability
```

Downstream application examples, quickstarts, and projects cannot legally import these units as normal public API. Their signatures may change without a v1.0 source-compatibility break.

## Public example gate

`examples/public_api_sealed.adb` is the compile-only public API boundary example. It intentionally imports only the stable public packages listed above. Attempting to import `I18N.Parser`, `I18N.Compiler`, or `I18N.Runtime.Compatibility` from a non-descendant application unit is an Ada visibility error, not merely a documentation violation.

## Documentation rule

If documentation describes behavior requiring a compatibility-only package, it must explicitly say that the package is for tests/regression validation and is outside the v1.0 application contract.


## Compiler verification

The source declarations use Ada private child packages to enforce this boundary. The boundary is release-proven only after GNAT/GPRbuild compiles the library, tests, and public examples. See `docs/RELEASE_VERIFICATION.md`.
