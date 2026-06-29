# Threading and Allocation

## Runtime sharing

`I18N.Runtime.Instance` is intended to be immutable after successful initialization. Multiple tasks may call the public catalog `Render` function against the same initialized runtime.

Rules:

* initialize a runtime before sharing it;
* do not call `Initialize` or `Finalize` concurrently with render calls on the same runtime object;
* render does not intentionally mutate catalog entries or runtime validity state;
* diagnostics callbacks must be externally thread-safe when shared;
* callback exceptions are contained.

## Execution contexts

The lower-level `private child I18N.Runtime.Compatibility.Render_Into` path uses an explicit execution context. Each task must use its own compatibility execution context; sharing one context concurrently is invalid because it contains mutable output and diagnostic storage.

## Allocation contract

Initialization may allocate for:

* catalog storage;
* parsing;
* validation;
* compilation;
* cache/store population.

The public `I18N.Runtime.Render_Into` facade is allocation-free: it renders directly into the caller-owned `String` without building an intermediate dynamic buffer. The internal `I18N.Runtime.Compatibility.Render_Into` path writes into caller-owned fixed storage and is the path used by the zero-allocation release checks.

The public catalog `Render` function returns `I18N.Result.Render_Result`, whose text view materializes the final string after execution. Therefore that facade is stable and structured, but it is not itself specified as a zero-allocation API. For allocation-free rendering, use the public `Render_Into` facade.

## Determinism

For the same initialized runtime, locale, key, and arguments, render output and failure classification must be deterministic. Invalid catalogs must produce deterministic invalid-runtime state.
