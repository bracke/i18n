# Expected Example Output

Build the example suite from the repository root:

```sh
gprbuild -P examples/examples.gpr
```

Run examples from the repository root because they use catalog paths such as
`examples/catalogs/messages.catalog`.

The following output is written for GNAT-style enumeration images. If another Ada
implementation formats enumeration images differently, the status category names
should still match semantically.

## Quick examples

```sh
./examples/hello_world
```

```text
hello world: Hello, Ada!
```

```sh
./examples/basic_render
```

```text
basic: Hello, Ada!
```

```sh
./examples/public_api_example
```

```text
public API render: Servus, Ada!
```

```sh
./examples/public_api_sealed
```

```text
public API sealed smoke: SUCCESS
```

## ICU subset examples

```sh
./examples/plural_render
```

```text
plural one: One item
plural other: 5 items
```

```sh
./examples/select_render
```

```text
select male: Tomcat
select fallback branch: Unknown pet
```

```sh
./examples/selectordinal_render
```

```text
ordinal one: 1st place
ordinal other: 4th place
```

```sh
./examples/nested_message_render
```

```text
nested select/plural: Grace uploaded 2 files
```

## Locale and catalog examples

```sh
./examples/locale_fallback
```

```text
exact de-AT: Servus, Ada!
parent de: 3 Artikel
default en: Default fallback text for Ada.
```

```sh
./examples/fallback_chain
```

```text
fallback de-AT exact: Servus, Ada!
fallback de parent: 3 Artikel
fallback default en: Default fallback text for Ada.
```

```sh
./examples/default_locale_key
```

```text
unqualified catalog key uses default locale: Unqualified default-locale text for Ada.
```

```sh
./examples/equals_in_value
```

```text
equals in catalog value: A value may contain = after the first separator.
```

```sh
./examples/empty_message
```

```text
empty message status: SUCCESS
empty message length: 0
```

## Error and status examples

```sh
./examples/missing_key
```

```text
missing key: MISSING_KEY
```

```sh
./examples/missing_argument
```

```text
missing argument: MISSING_ARGUMENT
```

```sh
./examples/invalid_argument
```

```text
invalid numeric argument: INVALID_ARGUMENT
```

```sh
./examples/invalid_catalog
```

```text
duplicate catalog valid: FALSE
render after invalid catalog: EXECUTION_ERROR
syntax catalog valid: FALSE
```

```sh
./examples/invalid_catalog_fields
```

```text
empty locale valid: FALSE
empty key valid: FALSE
empty default locale valid: FALSE
```

```sh
./examples/status_handling
```

```text
success status: success => Hello, Ada!
missing argument status: required render argument was not supplied
missing key status: message key not found after locale fallback
```

## Diagnostics and lifecycle examples

```sh
./examples/diagnostics_non_interference
```

```text
trace callback cannot affect render: Hello, Ada!
diagnostic count: 0
```

```sh
./examples/diagnostics_inspection
```

Expected deterministic prefix:

```text
render status: MISSING_ARGUMENT
has missing-variable diagnostic: TRUE
diagnostic count: 1
diagnostic 1: MISSING_VARIABLE key=name message=
```

The diagnostic message text after `message=` may contain implementation detail
text intended for debugging; the stable part is the status, kind, key, and count.

```sh
./examples/reuse_runtime
```

```text
first render: Hello, Ada!
second render: 7 Artikel
```

```sh
./examples/argument_lifecycle
```

```text
has name after set: TRUE
name value: Ada
has name after clear: FALSE
```
