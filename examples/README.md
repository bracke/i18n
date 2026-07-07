# Examples

This directory contains small, standalone programs that demonstrate the sealed
v1.1.0 public API.

## Start here

The shortest example is:

```sh
gprbuild -P examples/examples.gpr
./examples/bin/hello_world
```

Expected output:

```text
hello world: Hello, Ada!
```

## Build the suite

```sh
gprbuild -P examples/examples.gpr
```

The generated executables are written into this `examples/` directory. Run them
from the repository root because the examples use relative catalog paths such as
`examples/catalogs/messages.catalog`.

## Public API rule

Examples intended for application code must only import:

```ada
with I18N;
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Result;
with I18N.Runtime;
```

Private implementation packages are intentionally not used by examples. See
`docs/PUBLIC_IMPORT_RULES.md` for the release boundary.

## Coverage map

See:

- `EXAMPLES_INDEX.md` for the complete inventory.
- `EXPECTED_OUTPUT.md` for command-by-command output.
- `docs/EXAMPLES.md` for the documentation-oriented walkthrough.

## Public API smoke examples

`examples/public_api_example.adb` and `examples/public_api_sealed.adb` are
minimal public API boundary smoke examples. They are part of the maintained
example suite and use only the stable public import set.
