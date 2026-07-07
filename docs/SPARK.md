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
- `I18N.Buffer`, the fixed-capacity private render buffer used by compatibility-path checks.
- `I18N.Diagnostics` fixed-storage diagnostic records and helper operations; callback installation remains outside SPARK because it stores and invokes access-to-subprogram values.
- `I18N.Result`, including bounded output views, output extraction, and public failure construction.

`I18N.Plurals` remains total and deterministic, but is no longer SPARK-enabled because integer classification may consult process-wide runtime data overrides before generated CLDR fallback rules. The parser, catalog loader, runtime initialization, public render orchestration, examples, and AUnit tests remain ordinary Ada. They perform file I/O, dynamic catalog storage, callbacks, container operations, and application-facing workflow checks that are better covered by the release test suite for now.
