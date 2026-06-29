# ICU Subset

ICU Messages Ada v1.0 implements a deliberately small, deterministic ICU-style subset.

## Supported constructs

### Literal text

```text
Hello world
```

### Variables

```text
Hello, {name}!
```

A missing variable returns `Missing_Argument`.

### Plural

```text
{count, plural, one {One item} other {# items}}
```

Rules:

* `other` is required; `one` is optional and falls back to `other` when absent;
* the parser accepts the `one` and `other` branch names; other category names are rejected;
* selector argument must be a strict decimal integer;
* `#` is replaced with the numeric selector text;
* the branch is chosen by the resolved locale's CLDR cardinal category via `I18N.Plurals`.

### Select

```text
{gender, select, male {He} female {She} other {They}}
{width,  select, full {hour} short {hr} narrow {h} other {hour}}
```

Rules:

* `other` is required;
* branch names are arbitrary validated identifiers (the legacy `male`/`female`/`other` branches keep working unchanged);
* duplicate branch names are rejected;
* selector argument is string-valued;
* unmatched values use `other`.

Boolean-style selects pair naturally with `I18N.Arguments.Set_Boolean`, which serializes `true`/`false`:

```text
{active, select, true {on} false {off} other {?}}
```

### Selectordinal

```text
{rank, selectordinal, one {1st} two {2nd} few {3rd} other {#th}}
```

Rules:

* `other` is required; `one`, `two`, and `few` are optional and fall back to `other` when absent;
* the parser accepts the `one`, `two`, `few`, and `other` branch names; other category names are rejected;
* selector argument must be a strict decimal integer;
* `#` is replaced with the numeric selector text;
* the branch is chosen by the resolved locale's CLDR ordinal category via `I18N.Plurals` (for English `21 -> 21st`, `11 -> 11th`), falling back to `other` when the category's branch is absent.

### Nesting

Supported constructs may be nested inside branch bodies.

## Unsupported v1.0 features

* Loading plural rules from external CLDR data files at runtime (built-in `I18N.Plurals` rules cover a fixed locale set).
* Date, time, currency, percent, or number formatting skeletons.
* Plural offsets.
* Rich apostrophe escaping beyond the implemented strict parser.
* Runtime parser/compiler access through the public API.
* Bytecode VM or code-generation execution model.
* Binary catalog authoring format.

Unsupported syntax must fail deterministically during initialization or validation rather than being accepted silently.
