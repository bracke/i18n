# Quickstart

This guide shows the smallest complete v1.1.0 workflow: create a catalog, initialize the runtime, pass arguments, render a message, and inspect the structured result.

## 1. Create a catalog

Create `messages.catalog` next to the executable or pass the path you want to use during initialization.

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
de.items = "{count, plural, one {Ein Artikel} other {# Artikel}}"
```

The v1.1.0 catalog format is line-oriented:

```text
locale.key = ICU message string
```

`default_locale` sets the final fallback locale. It may appear anywhere in the file, but it must appear at most once and must not be empty.

## 2. Initialize the runtime

Initialization is explicit and front-loads catalog validation. The runtime records normalized locale/key/source entries before public rendering.

```ada
with I18N.Runtime;

procedure Setup is
   Runtime : I18N.Runtime.Instance;
begin
   I18N.Runtime.Initialize (Runtime, "messages.catalog");

   if not I18N.Runtime.Is_Valid (Runtime) then
      -- The catalog is invalid. Rendering will return Execution_Error.
      return;
   end if;
end Setup;
```

For application code, treat initialization failure as a startup/configuration error. Public rendering does not throw normal ICU failures, but an invalid runtime cannot produce valid catalog output.

## 3. Render a message

Use only the stable public packages in application code:

```ada
with Ada.Text_IO;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Hello_I18N is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, "messages.catalog");

   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      R : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "welcome",
           Arguments => Args);
   begin
      case R.Status is
         when I18N.Result.Success =>
            Ada.Text_IO.Put_Line (I18N.Result.Output_Text (R.Text));

         when I18N.Result.Missing_Key =>
            Ada.Text_IO.Put_Line ("message key not found");

         when I18N.Result.Missing_Argument =>
            Ada.Text_IO.Put_Line ("required argument missing");

         when I18N.Result.Invalid_Argument =>
            Ada.Text_IO.Put_Line ("argument has the wrong value format");

         when others =>
            Ada.Text_IO.Put_Line ("render failed");
      end case;
   end;
end Hello_I18N;
```

With the catalog above, rendering locale `de-AT` and key `welcome` resolves through this deterministic fallback chain:

```text
de-AT -> de -> en
```

Because `de.welcome` exists, the output is:

```text
Willkommen, Ada!
```

## 4. Render plural messages

Plural and selectordinal values are supplied as strings. The renderer parses them as strict decimal integers.

```ada
I18N.Arguments.Clear (Args);
I18N.Arguments.Set (Args, "count", "3");

declare
   R : constant I18N.Result.Render_Result :=
     I18N.Runtime.Render
       (Item      => Runtime,
        Locale    => "en",
        Key       => "items",
        Arguments => Args);
begin
   if R.Status = I18N.Result.Success then
      Ada.Text_IO.Put_Line (I18N.Result.Output_Text (R.Text)); -- 3 items
   end if;
end;
```

If `count` is missing, the result status is `Missing_Argument`. Non-offset plurals accept strict integer or decimal text; malformed numeric text returns `Invalid_Argument`.

## 5. Render date, time, number, and currency values

Date and time values are strict text inputs:

```text
en.when = "On {day, date} at {clock, time}"
de.when = "Am {day, date} um {clock, time}"
```

`day = "2024-02-29"` and `clock = "09:05:07"` render as
`2024-02-29` / `09:05:07` for `en` and `29.02.2024` / `09:05:07` for
`de`. Invalid calendar dates and out-of-range times return `Invalid_Argument`.

ISO instants with offsets can be formatted as date, time, or combined
date-time values with a fixed target zone:

```text
en.meeting = "{instant, datetime, short, America/New_York}"
```

`instant = "2024-03-01T02:30:00Z"` renders as `2/29/24 21:30`.
Supported target zones include deterministic offsets such as `UTC`, `+02:00`,
`Europe/Berlin`, `Europe/Paris`, `Europe/Zurich`, `Europe/Vienna`,
`Europe/Brussels`, `Europe/Copenhagen`, `Europe/Stockholm`, `Europe/Oslo`,
`Europe/Warsaw`, `Europe/Prague`, `Europe/Budapest`, `Europe/London`,
`Z`, `GMT`, `Etc/UTC`, `Etc/GMT`, alias names such as `Zulu`,
`US/Eastern`, `US/Pacific`, and `Canada/Eastern`, `Europe/Bratislava`,
`Europe/Luxembourg`, `Europe/Monaco`, `Europe/Andorra`,
`Europe/Malta`, `Europe/San_Marino`, `Europe/Vatican`, `Europe/Belgrade`,
`Europe/Zagreb`, `Europe/Ljubljana`, `Europe/Sarajevo`, `Europe/Skopje`,
`Europe/Podgorica`, `Europe/Tirane`, `Europe/Dublin`, `Europe/Lisbon`,
`Atlantic/Canary`, `Europe/Athens`,
`Europe/Helsinki`, `Europe/Bucharest`, `Europe/Sofia`, `Europe/Vilnius`,
`Europe/Riga`, `Europe/Tallinn`, `Europe/Kyiv`, `Europe/Chisinau`,
`Asia/Nicosia`, `Europe/Moscow`, `Europe/Istanbul`, `America/New_York`,
`America/Toronto`, `America/Montreal`, `America/Detroit`,
`America/Indiana/Indianapolis`, `America/Kentucky/Louisville`,
`America/Nassau`, `America/Chicago`,
`America/Winnipeg`, `America/Denver`, `America/Edmonton`, `America/Boise`,
`America/Los_Angeles`, `America/Vancouver`, `America/Tijuana`,
`America/Phoenix`, `America/Mexico_City`, `America/Bogota`,
`America/Lima`, `America/Sao_Paulo`,
`America/Argentina/Buenos_Aires`, `Africa/Johannesburg`,
`Africa/Nairobi`, `Africa/Lagos`, `Asia/Dubai`, `Asia/Riyadh`,
`Asia/Shanghai`, `Asia/Singapore`, `Asia/Hong_Kong`, `Asia/Taipei`,
`Asia/Kuala_Lumpur`, `Asia/Tokyo`, `Asia/Kolkata`,
`Asia/Ho_Chi_Minh`, `Asia/Karachi`, `Asia/Kathmandu`,
`Pacific/Honolulu`, `Pacific/Auckland`,
`Australia/Sydney`, `Australia/Melbourne`, `Australia/Hobart`,
`Australia/Adelaide`, `Australia/Brisbane`, `Australia/Perth`, and
`Australia/Darwin`; the listed European DST-rule zones, DST-aware America and
Canada, New Zealand, Sydney, Melbourne, Hobart, and Adelaide named zones keep
their deterministic display-name families. Instant conversion uses checked
IANA tzdb 2026a transition tables generated into the library for 1900 through
2050, plus deterministic runtime-data/tzdb override rows for application-loaded
offset data. See `docs/ICU_SUBSET.md` for the
complete deterministic target-zone list.

Number values are supplied as strict decimal strings. Catalog messages can
format grouped output:

```text
en.total = "Total {value, number}"
de.total = "Summe {value, number}"
```

`"12345.67"` renders as `12,345.67` for `en` and `12.345,67` for `de`.
Grouping separators are output-only; grouped input returns `Invalid_Argument`.

Currency values are supplied as strict decimal strings. Catalog messages choose
the ISO code:

```text
en.price = "Total {amount, currency, USD}"
de.price = "Summe {amount, currency, EUR}"
```

`"12.3"` renders as `USD 12.30` for `en` and `12,30 EUR` for `de`.
Currency codes must be three uppercase ASCII letters. Too many fraction digits
return `Invalid_Argument`.

## 6. Build the library and examples

From the project root:

```sh
alr exec -- gprbuild -P i18n.gpr
```

To build the maintained v1.1.0 example series:

```sh
alr exec -- gprbuild -P examples/examples.gpr
```

The example suite includes `hello_world.adb` as the shortest start-here program and public API import-boundary smoke examples. The examples intentionally use only public packages such as:

```ada
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Plurals;
with I18N.Result;
with I18N.Runtime;
```

Application code should not `with` parser, validator, compiler, IR, cache, AST, or execution packages.

## 7. Run the release test suite

```sh
cd tests
alr exec -- gprbuild -P tests.gpr
./bin/tests
cd ..
```

The tests are the release gate. See `docs/TEST_MATRIX.md` for the mapping between v1.1.0 requirements and concrete test groups.

## 8. What to read next

* `docs/API.md` for the frozen public API contract.
* `docs/CATALOG_FORMAT.md` for exact catalog syntax and rejection rules.
* `docs/ICU_SUBSET.md` for supported message syntax.
* `docs/ERROR_MODEL.md` for status meanings.
* `docs/THREADING.md` for initialization, render, and allocation guarantees.

## More examples

See `docs/EXAMPLES.md`, `examples/README.md`, `examples/EXAMPLES_INDEX.md`, and `examples/EXPECTED_OUTPUT.md` for the full v1.1.0 example series covering hello-world rendering, plural, select, selectordinal, nesting, number/currency/date/time/domain formatting, full fallback chains, diagnostics, invalid catalogs, invalid catalog fields, stable failure statuses, empty messages, default-locale keys, and argument-map lifecycle operations.
