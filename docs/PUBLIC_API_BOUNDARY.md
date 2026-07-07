# Public API Boundary

This document records the public API boundary in a form that is easy to audit.

## Stable application-facing packages

Application code should depend only on these library packages:

```ada
with I18N;
with I18N.Runtime;
with I18N.Result;
with I18N.Arguments;
with I18N.Locales;
with I18N.Plurals;
with I18N.Diagnostics;
```

`I18N.Runtime` is the catalog-backed facade (loading, validation, resolution, rendering). `I18N.Arguments` is the stable argument-map facade. `I18N.Result` is the frozen render-status/result model. `I18N.Locales` defines locale identifiers and fallback helpers. `I18N.Plurals` classifies integer and explicit fractional CLDR operands into plural categories. `I18N.Diagnostics` exposes optional non-interfering trace/diagnostic hooks.

## Stable runtime surface

The stable `I18N.Runtime` visible surface is small and additive:

```ada
type Runtime is tagged limited private;
subtype Instance is Runtime;

--  Loading
procedure Initialize (Item : in out Runtime; Catalog_Path : String);
procedure Load       (Item : in out Runtime; Catalog_Path : String);  -- legacy append
type Duplicate_Policy is (Reject_Duplicates, Keep_First, Override_Previous);
type Load_Status is (Loaded, Source_Not_Found, Invalid_Catalog, Duplicate_Rejected, Runtime_Invalid);
type Load_Result is record
   Status : Load_Status; Entries_Added, Entries_Replaced, Entries_Ignored : Natural;
   Diagnostics : I18N.Diagnostics.Diagnostic_List;
end record;
procedure Load_File (Item : in out Instance; Path : String;
                     Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Text (Item : in out Instance; Source_Name, Text : String;
                     Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);

--  Validation (non-destructive)
type Catalog_Validation_Result is record
   Valid : Boolean; Entry_Count : Natural; Diagnostics : I18N.Diagnostics.Diagnostic_List;
end record;
function Validate_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Catalog_Text (Source_Name, Text : String) return Catalog_Validation_Result;

--  Resolution (no render)
type Resolve_Status is (Found, Missing_Key, Runtime_Invalid);
type Resolve_Result is private-ish record with Status and a bounded resolved locale;
function Resolved_Locale (Item : Resolve_Result) return I18N.Locales.Locale_Id;
function Resolve (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String) return Resolve_Result;

--  Rendering
function Render (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String;
                Arguments : I18N.Arguments.Arguments) return I18N.Result.Render_Result;
procedure Render_Into (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String;
                       Arguments : I18N.Arguments.Arguments;
                       Target : in out String; Last : out Natural;
                       Status : out I18N.Result.Render_Status);  -- allocation-free

function Is_Valid (Item : Runtime) return Boolean;
procedure Finalize (Item : in out Runtime);
```

No application-facing runtime declaration exposes parser state, AST nodes, compiler state, IR opcode arrays, cache maps, buffer internals, or internal error enums.
Formatter implementation packages and generated CLDR data are likewise private
implementation detail behind the public catalog render path.

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
I18N.Number_Format
I18N.Currency
I18N.Date_Time_Format
I18N.Extra_Format
I18N.CLDR_Data
```

Downstream application examples, quickstarts, and projects cannot legally import these units as normal public API. Their signatures may change without a v1.1.0 source-compatibility break.

## Public example gate

`examples/public_api_sealed.adb` is the compile-only public API boundary example. It intentionally imports only the stable public packages listed above. Attempting to import `I18N.Parser`, `I18N.Compiler`, `I18N.Runtime.Compatibility`, `I18N.Number_Format`, or `I18N.CLDR_Data` from a non-descendant application unit is an Ada visibility error, not merely a documentation violation.

## Documentation rule

If documentation describes behavior requiring a compatibility-only package, it must explicitly say that the package is for tests/regression validation and is outside the v1.1.0 application contract.


## Compiler verification

The source declarations use Ada private child packages to enforce this boundary. The boundary is release-proven only after GNAT/GPRbuild compiles the library, tests, and public examples. See `docs/RELEASE_VERIFICATION.md`.
