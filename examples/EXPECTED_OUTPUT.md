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
./examples/bin/hello_world
```

```text
hello world: Hello, Ada!
```

```sh
./examples/bin/basic_render
```

```text
basic: Hello, Ada!
```

```sh
./examples/bin/public_api_example
```

```text
public API render: Servus, Ada!
```

```sh
./examples/bin/public_api_sealed
```

```text
public API sealed smoke: SUCCESS
```

## ICU subset examples

```sh
./examples/bin/plural_render
```

```text
plural one: One item
plural other: 5 items
```

```sh
./examples/bin/select_render
```

```text
select male: Tomcat
select fallback branch: Unknown pet
```

```sh
./examples/bin/selectordinal_render
```

```text
ordinal one: 1st place
ordinal other: 4th place
ordinal many: 8o posto speciale
```

```sh
./examples/bin/nested_message_render
```

```text
nested select/plural: Grace uploaded 2 files
```

```sh
./examples/bin/number_formatting
```

```text
number en: Number: 12,345.67
number de: Zahl: 12.345,67
number percent: Percent: 13%
number permille: Permille: 125‰
number compact: Compact: 12.3K
number scientific: Scientific: 1.23E+4
number engineering: Engineering: 12.35E+3
number spellout: Spellout: forty-two
number trailing: Trailing stripped: 42
number accounting: Accounting number: (12,345)
number scale: Scaled: 12,345,670.00
number arabic digits: Arabic digits: ١٬٢٣٤٬٥٦٧٫٨٩
number indian grouping: Indian grouping: 12,34,567.89
```

```sh
./examples/bin/currency_formatting
```

```text
currency en: Total: $1,234.50
currency de: Summe: 1.234,50 €
currency name: Name: 1,234.50 US dollars
currency narrow: Narrow: $1,234.50
currency iso: ISO: USD 1,234.50
currency cash: Cash: CHF 1.05
currency accounting: Accounting: ($1,234.50)
currency yen: Yen: ¥1,234
```

```sh
./examples/bin/date_formatting
```

```text
date en: Date: February 29, 2024
date de: Datum: Donnerstag, 29. Februar 2024
date skeleton: Date skeleton: Feb 29, 2024
date numeric skeleton: Numeric skeleton: 2024 02 29
date japanese calendar: Japanese calendar: 令和 6年2月29日
date buddhist calendar: Buddhist calendar: กุมภาพันธ์ ๒๙, ๒๕๖๗
date locale week: Locale week fields: 2016/1/1/2016
date persian calendar: Persian calendar: AP 1403 01 01
```

```sh
./examples/bin/time_formatting
```

```text
time short: Time: 09:05
time long: Time with seconds: 09:05:07
time skeleton: Time skeleton: 09:05:07 AM
time fraction: Fractional time: 09:05:07.123
time zone: Zoned time: 09:05 EST
time zone widths: Zone widths: GMT-04:00|-04:00|-04:00|America/New_York
time utc widths: UTC widths: Z|+00:00|UTC
time datetime long: Long datetime: February 29, 2024 21:30:00
time datetime full: Full datetime: Thursday, February 29, 2024 21:30:00
```

```sh
./examples/bin/domain_formatting
```

```text
domain duration: Duration: 1:01:01
domain bytes: Size: 2 TiB
domain unit: Distance: 1.5 kilometers
domain rate: Rate: 1.5 kilometers per hour
domain short rate: Short rate: 1.5 km/h
domain relative: When: 3 days ago
domain relative de: Wann: vor 3 Tagen
domain list: List: red, green and blue
domain list de: Liste: red, green und blue
```

## Locale and catalog examples

```sh
./examples/bin/locale_fallback
```

```text
exact de-AT: Servus, Ada!
parent de: 3 Artikel
default en: Default fallback text for Ada.
```

```sh
./examples/bin/fallback_chain
```

```text
fallback de-AT exact: Servus, Ada!
fallback de parent: 3 Artikel
fallback default en: Default fallback text for Ada.
```

```sh
./examples/bin/default_locale_key
```

```text
unqualified catalog key uses default locale: Unqualified default-locale text for Ada.
```

```sh
./examples/bin/equals_in_value
```

```text
equals in catalog value: A value may contain = after the first separator.
```

```sh
./examples/bin/empty_message
```

```text
empty message status: SUCCESS
empty message length: 0
```

## Error and status examples

```sh
./examples/bin/missing_key
```

```text
missing key: MISSING_KEY
```

```sh
./examples/bin/missing_argument
```

```text
missing argument: MISSING_ARGUMENT
```

```sh
./examples/bin/invalid_argument
```

```text
invalid numeric argument: INVALID_ARGUMENT
```

```sh
./examples/bin/invalid_catalog
```

```text
duplicate catalog valid: FALSE
render after invalid catalog: EXECUTION_ERROR
syntax catalog valid: FALSE
```

```sh
./examples/bin/invalid_catalog_fields
```

```text
empty locale valid: FALSE
empty key valid: FALSE
empty default locale valid: FALSE
```

```sh
./examples/bin/status_handling
```

```text
success status: success => Hello, Ada!
missing argument status: required render argument was not supplied
missing key status: message key not found after locale fallback
```

## Diagnostics and lifecycle examples

```sh
./examples/bin/diagnostics_non_interference
```

```text
trace callback cannot affect render: Hello, Ada!
diagnostic count: 0
```

```sh
./examples/bin/diagnostics_inspection
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
./examples/bin/reuse_runtime
```

```text
first render: Hello, Ada!
second render: 7 Artikel
```

```sh
./examples/bin/argument_lifecycle
```

```text
has name after set: TRUE
name value: Ada
has name after clear: FALSE
```
