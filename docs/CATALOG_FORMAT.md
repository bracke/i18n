# Catalog Format

The v1.1.0 canonical catalog format is line-oriented text.

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
en.total = "Total {value, number}"
en.price = "Total {amount, currency, USD}"
en.when = "On {day, date} at {clock, time}"
```

## Lexical rules

* One directive or message entry per line.
* Blank lines are ignored.
* Lines whose first non-space character is `#` are comments.
* The first `=` separates the name from the value.
* Additional `=` characters belong to the value.
* Leading/trailing spaces around the name and value are trimmed.
* If the trimmed value starts and ends with `"`, the surrounding quotes are removed.
* No TOML parser is part of v1.1.0; this text format is the canonical authoring format.

## Default locale

```text
default_locale = en
```

Rules:

* may appear anywhere in the file;
* may appear at most once;
* must not be empty;
* applies to unqualified message keys;
* is the final fallback locale.

If omitted, the implementation default locale name is `default`.

## Message entries

```text
locale.key = ICU message string
```

Rules:

* qualified entries require a non-empty locale and non-empty key;
* unqualified entries use the configured default locale;
* duplicate `locale.key` entries are invalid;
* catalog structure and brace balance are validated during initialization;
* ICU messages may use variables, plural, select, selectordinal, deterministic number/date/time formats, and deterministic currency formats documented in `docs/ICU_SUBSET.md`;
* an explicitly present empty value is a valid empty message and renders as successful empty text;
* any invalid entry makes initialization fail deterministically.

## Locale fallback

For requested locale `de-AT`, fallback order is:

```text
de-AT -> de -> default locale
```

Catalog locale prefixes, `default_locale`, and public render/resolve requests
are canonicalized before lookup: language subtags are lower-case, script
subtags title-case, region subtags upper-case, extension subtags lower-case,
and deterministic CLDR language aliases such as `iw -> he`, `in -> id`,
`ji -> yi`, and `sh -> sr-Latn` are applied.

A missing key after fallback returns `Missing_Key`.

## Invalid catalog examples

```text
# empty default locale
default_locale =

# duplicate default locale
default_locale = en
default_locale = de

# empty locale
.welcome = "Welcome"

# empty key
en. = "Welcome"

# malformed line
en.welcome "Welcome"

# duplicate entry
en.welcome = "Welcome"
en.welcome = "Hello"
```


## Binary catalogs

v1.1.0 defines a deterministic versioned binary catalog envelope:

```text
I18N-CATALOG-BINARY
format_version=1
ir_version=1
payload=text

default_locale = en
en.welcome = "Welcome, {name}!"
```

The blank line after `payload=text` separates the header from the canonical text
catalog payload. The alternate `payload=hex-text` kind uses the same envelope
but encodes the canonical text catalog payload as ASCII hex bytes after the
blank line. Unsupported magic, format versions, IR versions, malformed
hex-text payloads, and unsupported payload kinds are rejected
deterministically. The v1.1 payload kinds are `text` and `hex-text`; the
runtime still validates and compiles entries into its private indexed runtime
representation during initialization or load.
