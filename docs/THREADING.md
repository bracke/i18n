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

The compatibility `Render_Into` path writes into caller-owned fixed storage for supported output sizes and is the path used by zero-allocation release checks.

The public catalog `Render` function returns `I18N.Result.Render_Result`, whose text view materializes the final string after execution. Therefore the public facade is stable and structured, but it is not itself specified as a zero-allocation API. The strict no-allocation guarantee is specifically verified at the lower-level caller-owned-buffer render path.

## Determinism

For the same initialized runtime, locale, key, and arguments, render output and failure classification must be deterministic. Invalid catalogs must produce deterministic invalid-runtime state.
