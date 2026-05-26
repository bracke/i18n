# Error Model

Normal catalog, parse, validation, and render failures are reported through deterministic state or structured results. Public catalog rendering must not expose parser/compiler/cache internals and must not raise for ordinary ICU/message failures.

## Stable public statuses

* `Success` — render succeeded and `I18N.Result.Output_Text (Result.Text)` returns the rendered message.
* `Missing_Key` — locale fallback completed but no entry for the key existed.
* `Missing_Argument` — a variable, plural selector, select selector, or selectordinal selector argument was absent.
* `Invalid_Argument` — a selector argument had the wrong syntax, for example a non-decimal plural value.
* `Formatting_Error` — a compiled message could not select a required branch.
* `Execution_Error` — deterministic initialization, validation, or execution failure outside the above public categories.
* `Buffer_Overflow` — render output exceeded the supported output buffer.
* `Internal_Error` — unexpected implementation failure contained by the facade.

The meaning of these statuses is frozen for v1.0.

## Initialization errors

Invalid catalogs do not produce a partially valid public runtime. After invalid initialization:

* `I18N.Runtime.Is_Valid` returns `False`;
* public catalog `Render` returns `Execution_Error`;
* `private child I18N.Runtime.Compatibility.Last_Error` is available only for regression tests that inspect pre-v1.0 internal classifications. Application code should rely on the public render status.

## Render errors

Public render never returns parser nodes, AST values, compiler internals, IR arrays, cache internals, or internal error objects. It returns `I18N.Result.Render_Result`.

`I18N.Result.Output_Text (Result.Text)` is meaningful only on `Success`. On failure, it returns the empty string.

## Diagnostics

Diagnostics may add detail, but they must not change status semantics, output text, cache state, runtime state, or IR state. Callback exceptions are contained and converted to no externally visible render failure.
