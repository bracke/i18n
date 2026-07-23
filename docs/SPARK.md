# SPARK Coverage

`i18n` runs GNATprove as part of release validation:

```sh
alr exec -- gnatprove -P i18n.gpr --level=0 --mode=check
```

The current SPARK-enabled surface is intentionally focused on deterministic, bounded data handling:

- `I18N` root package metadata.
- `I18N.Locales`, including deterministic locale canonicalization, matching,
  direction, and parent-locale fallback helpers. The expanded bounded
  collation/search implementation is ordinary Ada because its generated
  compatibility-folding decision tree is validated by the release tests and is
  too large for the current GNATprove Global-generation pass.
`I18N.Plurals` remains total and deterministic, but is no longer SPARK-enabled because integer classification may consult process-wide runtime data overrides before generated CLDR fallback rules. The CLDR data pipeline, formatting implementations, and AUnit tests remain ordinary Ada. They perform file I/O, dynamic data storage, callbacks, container operations, and application-facing workflow checks that are better covered by the release test suite for now.

SPARK coverage for the ICU message-formatting packages (`Messages.Buffer`, `Messages.Diagnostics`, `Messages.Result`, and the parser/render pipeline) now lives in the `messages` crate.
