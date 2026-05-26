# Catalog Format

The v1.0 canonical catalog format is line-oriented text.

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
```

## Lexical rules

* One directive or message entry per line.
* Blank lines are ignored.
* Lines whose first non-space character is `#` are comments.
* The first `=` separates the name from the value.
* Additional `=` characters belong to the value.
* Leading/trailing spaces around the name and value are trimmed.
* If the trimmed value starts and ends with `"`, the surrounding quotes are removed.
* No TOML parser is part of v1.0; this text format is the canonical authoring format.

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
* an explicitly present empty value is a valid empty message and renders as successful empty text;
* any invalid entry makes initialization fail deterministically.

## Locale fallback

For requested locale `de-AT`, fallback order is:

```text
de-AT -> de -> default locale
```

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

v1.0 does not define or ship a persistent binary compiled catalog format. The only frozen input format is this line-oriented text authoring format. Future binary catalogs must be explicitly versioned and must reject unsupported versions deterministically.
