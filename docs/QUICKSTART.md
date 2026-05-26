# Quickstart

This guide shows the smallest complete v1.0 workflow: create a catalog, initialize the runtime, pass arguments, render a message, and inspect the structured result.

## 1. Create a catalog

Create `messages.catalog` next to the executable or pass the path you want to use during initialization.

```text
default_locale = en
en.welcome = "Welcome, {name}!"
de.welcome = "Willkommen, {name}!"
en.items = "{count, plural, one {One item} other {# items}}"
de.items = "{count, plural, one {Ein Artikel} other {# Artikel}}"
```

The v1.0 catalog format is line-oriented:

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

If `count` is missing, the result status is `Missing_Argument`. If `count` is not a strict integer, the result status is `Invalid_Argument`.

## 5. Build the library and examples

From the project root:

```sh
gprbuild -P i18n.gpr
```

To build the maintained v1.0 example series:

```sh
gprbuild -P examples/examples.gpr
```

The example suite includes `hello_world.adb` as the shortest start-here program and public API import-boundary smoke examples. The examples intentionally use only public packages such as:

```ada
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Result;
with I18N.Runtime;
```

Application code should not `with` parser, validator, compiler, IR, cache, AST, or execution packages.

## 6. Run the release test suite

```sh
gprbuild -P tests/i18n_tests.gpr
./tests/bin/tests
```

The tests are the release gate. See `docs/TEST_MATRIX.md` for the mapping between v1.0 requirements and concrete test groups.

## 7. What to read next

* `docs/API.md` for the frozen public API contract.
* `docs/CATALOG_FORMAT.md` for exact catalog syntax and rejection rules.
* `docs/ICU_SUBSET.md` for supported message syntax.
* `docs/ERROR_MODEL.md` for status meanings.
* `docs/THREADING.md` for initialization, render, and allocation guarantees.

## More examples

See `docs/EXAMPLES.md`, `examples/README.md`, `examples/EXAMPLES_INDEX.md`, and `examples/EXPECTED_OUTPUT.md` for the full v1.0 example series covering hello-world rendering, plural, select, selectordinal, nesting, full fallback chains, diagnostics, invalid catalogs, invalid catalog fields, stable failure statuses, empty messages, default-locale keys, and argument-map lifecycle operations.
