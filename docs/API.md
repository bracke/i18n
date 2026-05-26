# Public API

This document describes the v1.0 application-facing API. Packages not listed here are implementation details or regression-test support and are outside the v1.0 source-compatibility promise.

## Public packages

Stable public packages:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`

Parser, validation, compiler, AST, compiled IR, cache, buffer, fast-render, lower-level renderer, internal error, observability, and compatibility packages are Ada private child packages. Ordinary application code cannot legally `with` those packages.

## `I18N.Runtime`

`I18N.Runtime.Instance` is the stable runtime handle. Initialize it once, then call the catalog-oriented render API.

### Initialization

```ada
procedure Initialize
  (Item         : in out I18N.Runtime.Instance;
   Catalog_Path : String);
```

Behavior:

* opens the catalog file when `Catalog_Path` names an existing ordinary file;
* reads the entire catalog deterministically;
* accepts blank lines and comment lines beginning with `#`;
* accepts one `default_locale = locale` directive anywhere in the file;
* validates duplicate entries, empty locale names, empty keys, empty default locale, duplicate default locale, malformed lines, and unbalanced catalog message braces;
* performs deterministic catalog validation during initialization;
* leaves the runtime invalid when any catalog error is found.

Failure behavior:

* initialization records failure state instead of exposing parser/compiler internals;
* `Is_Valid` returns `False` after invalid initialization;
* public catalog `Render` returns `Execution_Error` when the runtime is invalid.

Compatibility note: the source contains single-message helper entry points for in-tree regression tests. Those entry points live behind Ada private-child visibility and are not importable application API.

### Render

```ada
function Render
  (Item      : I18N.Runtime.Instance;
   Locale    : I18N.Locales.Locale_Id;
   Key       : String;
   Arguments : I18N.Arguments.Arguments)
   return I18N.Result.Render_Result;
```

Render behavior:

* does not mutate the runtime catalog;
* resolves locale by deterministic fallback;
* returns `Missing_Key` after fallback if no entry exists;
* returns `Missing_Argument` when a variable or selector argument is absent;
* returns `Invalid_Argument` when a numeric selector argument is not a strict decimal integer;
* returns `Formatting_Error` for deterministic branch-selection failures;
* returns `Buffer_Overflow` when output exceeds the supported render buffer;
* returns `Internal_Error` only for unexpected implementation failures contained by the facade;
* does not raise for normal ICU/render failures.

### Allocation note

Public `Render` returns a structured result containing materialized text. The public function is not specified as a zero-allocation API. The no-allocation release gate applies to the private fixed-buffer compatibility path used by in-tree regression tests.

### Runtime inspection and cleanup

```ada
function Is_Valid (Item : I18N.Runtime.Runtime) return Boolean;
procedure Finalize (Item : in out I18N.Runtime.Runtime);
```

`Is_Valid` is useful after initialization. `Finalize` clears runtime-owned catalog/message references; it does not define a persistent binary catalog format and does not clear the process-global cache.

The single-message/fixed-buffer APIs are isolated in private child package `I18N.Runtime.Compatibility` for in-tree regression tests only. They are not part of the v1.0 application contract and are not directly importable by ordinary downstream units. This private path is where strict fixed-buffer no-allocation checks are performed.

## `I18N.Result`

Frozen status set:

```ada
type Render_Status is
  (Success,
   Missing_Key,
   Missing_Argument,
   Invalid_Argument,
   Formatting_Error,
   Execution_Error,
   Buffer_Overflow,
   Internal_Error);
```

`I18N.Result.Output_Text (Result.Text)` is meaningful only when `Status = Success`. `Render_Result.Diagnostics` may contain additional detail. Public callers do not receive parser nodes, compiler objects, cache internals, IR arrays, or internal error records through this result type.

## `I18N.Arguments`

Public argument map API:

```ada
procedure Set (Args : in out Arguments; Key : String; Value : String);
procedure Clear (Args : in out Arguments);
procedure Copy (Source : Arguments; Destination : in out Arguments);
function Has (Args : Arguments; Key : String) return Boolean;
function Get (Args : Arguments; Key : String) return String;
```

Arguments are string-valued and intentionally noncopyable at the Ada type level; pass them by reference, mutate them with `Set`/`Clear`, use `Copy` when an explicit duplicate is needed, and do not rely on whole-object assignment. Numeric plural and selectordinal selectors are parsed strictly during render. Missing values produce `Missing_Argument`; syntactically invalid numeric selectors produce `Invalid_Argument`.

## `I18N.Locales`

```ada
subtype Locale_Id is String;
function Parent (Item : Locale_Id) return String;
```

Locale identifiers are treated as hyphen-separated identifiers. `Parent ("de-AT")` returns `"de"`; `Parent ("de")` returns the empty string.

## `I18N.Diagnostics`

Diagnostics are fixed-storage structures used to report optional detail without affecting correctness. They are safe to ignore. The callback and diagnostic list APIs are observational; rendering correctness must not depend on them.

```ada
procedure Set_Trace_Callback
  (CB : I18N.Diagnostics.Trace_Callback);
```

Passing `null` disables tracing. Callback exceptions are caught by the diagnostics layer and do not escape into render.

## Public example imports

A valid v1.0 application example should need only:

```ada
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;
```

It may additionally `with I18N.Diagnostics` or `I18N.Locales` when it needs those names explicitly.

See also `docs/PUBLIC_IMPORT_RULES.md` for the exact Ada import boundary.
