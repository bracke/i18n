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
* `I18N.Plurals`

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

### Catalog shard loading

```ada
type Duplicate_Policy is (Reject_Duplicates, Keep_First, Override_Previous);
type Load_Status is
  (Loaded, Source_Not_Found, Invalid_Catalog, Duplicate_Rejected, Runtime_Invalid);
type Load_Result is record
   Status           : Load_Status;
   Entries_Added    : Natural;   --  new locale/key pairs inserted
   Entries_Replaced : Natural;   --  existing pairs overwritten (Override_Previous)
   Entries_Ignored  : Natural;   --  duplicate pairs skipped (Keep_First)
   Diagnostics      : I18N.Diagnostics.Diagnostic_List;
end record;

procedure Load_File
  (Item   : in out Instance; Path : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
procedure Load_Text
  (Item   : in out Instance; Source_Name : String; Text : String;
   Result : out Load_Result; Policy : Duplicate_Policy := Reject_Duplicates);
```

`Load_File`/`Load_Text` layer additional catalog shards into a runtime. They are transactional and non-destructive: a failed load (`Source_Not_Found`, `Invalid_Catalog`, `Duplicate_Rejected`, `Runtime_Invalid`) leaves the runtime exactly as it was. The legacy `Load` procedure is retained and, like `Initialize`, marks the runtime invalid on failure.

### Catalog validation

```ada
type Catalog_Validation_Result is record
   Valid       : Boolean;
   Entry_Count : Natural;
   Diagnostics : I18N.Diagnostics.Diagnostic_List;
end record;

function Validate_Catalog_File (Path : String) return Catalog_Validation_Result;
function Validate_Catalog_Text
  (Source_Name : String; Text : String) return Catalog_Validation_Result;
```

Validation never mutates any runtime. If validation fails, existing runtimes remain usable.

### Key resolution

```ada
type Resolve_Status is (Found, Missing_Key, Runtime_Invalid);
type Resolve_Result is record
   Status : Resolve_Status; ...
end record;
function Resolved_Locale (Item : Resolve_Result) return I18N.Locales.Locale_Id;
function Resolve
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String)
   return Resolve_Result;
```

`Resolve` answers whether a key is reachable through locale fallback without rendering it and without arguments.

### Bounded rendering

```ada
procedure Render_Into
  (Item : Instance; Locale : I18N.Locales.Locale_Id; Key : String;
   Arguments : I18N.Arguments.Arguments;
   Target : in out String; Last : out Natural;
   Status : out I18N.Result.Render_Status);
```

Renders the compiled AST **directly into** caller-owned storage without materializing an intermediate dynamic buffer. On `Success`, `Target (Target'First .. Last)` holds the output. On `Buffer_Overflow`, `Target` holds the prefix that fits and `Last` is the last written index. On any other failure, `Last = 0`.

### Allocation note

Public `Render` returns a structured result containing materialized text and is not specified as a zero-allocation API. `Render_Into` is the public allocation-free path: it writes each rendered fragment straight into the caller's `String` and never builds an `Unbounded_String`. The no-allocation release gate also covers the private fixed-buffer compatibility path used by in-tree regression tests.

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
procedure Set_Integer (Args : in out Arguments; Key : String; Value : Long_Long_Integer);
procedure Set_Natural (Args : in out Arguments; Key : String; Value : Natural);
procedure Set_Boolean (Args : in out Arguments; Key : String; Value : Boolean);
procedure Clear (Args : in out Arguments);
procedure Copy (Source : Arguments; Destination : in out Arguments);
function Has (Args : Arguments; Key : String) return Boolean;
function Get (Args : Arguments; Key : String) return String;
```

Arguments are string-valued and intentionally noncopyable at the Ada type level; pass them by reference, mutate them with `Set`/`Clear`, use `Copy` when an explicit duplicate is needed, and do not rely on whole-object assignment. `Set_Integer`/`Set_Natural` write strict decimal text with no `'Image` leading space; `Set_Boolean` writes `true`/`false`. These helpers are deterministic and not locale-aware. Numeric plural and selectordinal selectors are parsed strictly during render. Missing values produce `Missing_Argument`; syntactically invalid numeric selectors produce `Invalid_Argument`.

## `I18N.Plurals`

```ada
type Plural_Category is (Zero, One, Two, Few, Many, Other);
function Cardinal (Locale : I18N.Locales.Locale_Id; Value : Long_Long_Integer) return Plural_Category;
function Ordinal  (Locale : I18N.Locales.Locale_Id; Value : Long_Long_Integer) return Plural_Category;
```

Pure, total classification of an integer value into a CLDR plural category. Cardinal coverage is `en`, `de`, `nl`, `es`, `it`, `fr`, `pt`, `ru`, `pl`, `cs`, `ar` (the Slavic/Arabic rules cover all six categories); ordinal coverage is `en`, `fr`, `it`. Locales outside these sets resolve through the language subtag to the root rule (`Other`). Operands are integer-only (fraction digits zero).

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
