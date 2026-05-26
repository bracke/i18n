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

* `other` is required;
* selector argument must be a strict decimal integer;
* `#` is replaced with the numeric selector text;
* unsupported categories are rejected by the strict parser/validator.

### Select

```text
{gender, select, male {He} female {She} other {They}}
```

Rules:

* `other` is required;
* v1.0 accepts the branch names `male`, `female`, and `other`;
* selector argument is string-valued;
* unmatched values use `other`;
* arbitrary select branch names are intentionally not part of the frozen v1.0 subset.

### Selectordinal

```text
{rank, selectordinal, one {1st} two {2nd} few {3rd} other {#th}}
```

Rules:

* `other` is required;
* selector argument must be a strict decimal integer;
* `#` is replaced with the numeric selector text.

### Nesting

Supported constructs may be nested inside branch bodies.

## Unsupported v1.0 features

* CLDR plural-rule compiler or locale-specific plural data import.
* Date, time, currency, percent, or number formatting skeletons.
* Plural offsets.
* Rich apostrophe escaping beyond the implemented strict parser.
* Runtime parser/compiler access through the public API.
* Bytecode VM or code-generation execution model.
* Binary catalog authoring format.

Unsupported syntax must fail deterministically during initialization or validation rather than being accepted silently.
