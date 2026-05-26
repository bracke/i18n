# Project Index — ICU Messages Ada

This index makes the crate easy to navigate for humans, code assistants, and automated analysis tools.

## What this project is

ICU Messages Ada is a GNAT/GPRbuild-verified release-candidate Ada 2022 library for rendering a strict ICU-style message subset from a catalog. It exposes a small public API and keeps parsing, validation, compilation, IR, cache, and execution internals behind Ada private child package visibility and the `I18N.Runtime` facade.

## Start here by task

| Task | Start with |
| --- | --- |
| Use the library in an application | `docs/QUICKSTART.md`, then `examples/hello_world.adb` |
| Learn the public API | `docs/API.md`, `ai/API_MANIFEST.json` |
| Write a catalog | `docs/CATALOG_FORMAT.md`, `examples/catalogs/messages.catalog` |
| Understand supported ICU syntax | `docs/ICU_SUBSET.md` |
| Understand architecture | `docs/ARCHITECTURE.md` |
| Check release rules | `docs/RELEASE_CHECKLIST.md`, `docs/RELEASE_VERIFICATION.md`, `docs/TEST_MATRIX.md` |
| Add or modify tests | the AUnit test suite under `tests/`, `docs/TEST_MATRIX.md` |
| Add examples | `examples/README.md`, `examples/EXAMPLES_INDEX.md` |
| AI-assisted maintenance | `AGENTS.md`, `ai/CONTRACT_SUMMARY.yaml` |

## Public packages

| Package | File | Purpose |
| --- | --- | --- |
| `I18N` | `src/i18n.ads` | Root namespace. |
| `I18N.Runtime` | `src/i18n-runtime.ads` | Initialize catalog-backed runtime and render messages. |
| `I18N.Result` | `src/i18n-result.ads` | Stable render status and result shape. |
| `I18N.Arguments` | `src/i18n-arguments.ads` | Public argument map facade. |
| `I18N.Locales` | `src/i18n-locales.ads` | Locale identifier type and fallback helpers. |
| `I18N.Diagnostics` | `src/i18n-diagnostics.ads` | Optional non-interfering diagnostics facade. |

## Internal implementation packages

These files may exist in the source tree but are not part of the application-facing v1.0 compatibility contract:

| Area | Representative files |
| --- | --- |
| Parser and AST | `src/i18n-parser.*`, `src/i18n-ast.*` |
| Validation | `src/i18n-validation.*` |
| Compilation and IR | `src/i18n-compiler.*`, `src/i18n-compiled.*` |
| Cache/store | `src/i18n-cache.*` |
| Buffer/render internals | `src/i18n-buffer.*`, `src/i18n-render.*`, `src/i18n-fast_render.*` |
| Error internals | `src/i18n-errors.*` |
| Regression compatibility | `src/i18n-runtime-compatibility.*` |

Application examples must not `with` these internal packages.

## Project files

| File | Purpose |
| --- | --- |
| `i18n.gpr` | Main library project. |
| `tests/i18n_tests.gpr` | AUnit release-gate test project. |
| `examples/examples.gpr` | v1.0 public API examples project. |
| `examples/README.md` | Example directory orientation and public API import rule. |
| `examples/EXPECTED_OUTPUT.md` | Typical example output notes. |
| `MANIFEST.txt` | Full release file listing. |

## Documentation files

| File | Purpose |
| --- | --- |
| `README.md` | Release overview and documentation map. |
| `docs/QUICKSTART.md` | Minimal end-to-end usage. |
| `docs/API.md` | Stable public API. |
| `docs/ARCHITECTURE.md` | Runtime structure and internal boundary. |
| `docs/CATALOG_FORMAT.md` | Canonical catalog authoring format. |
| `docs/ICU_SUBSET.md` | Supported/unsupported ICU subset. |
| `docs/ERROR_MODEL.md` | Status semantics and deterministic failure model. |
| `docs/THREADING.md` | Threading and allocation behavior. |
| `docs/VALIDATION.md` | Validation rules. |
| `docs/TEST_MATRIX.md` | Test coverage matrix. |
| `docs/EXAMPLES.md` | Example suite guide. |
| `docs/COMPATIBILITY.md` | Source/runtime compatibility policy. |
| `docs/RELEASE_CHECKLIST.md` | Release audit checklist. |
| `docs/RELEASE_VERIFICATION.md` | GNAT/GPRbuild commands required before tagging v1.0. |
| `docs/AI_CONSUMPTION_GUIDE.md` | AI-oriented project consumption guide. |

## Machine-readable AI metadata

| File | Purpose |
| --- | --- |
| `ai/API_MANIFEST.json` | Public package/subprogram/status manifest. |
| `ai/CONTRACT_SUMMARY.yaml` | Compact v1.0 behavior contract. |
| `ai/EXAMPLE_CATALOG.json` | Example and catalog inventory. |
| `ai/FILE_ROLE_MAP.json` | File-to-role classification. |

* `docs/PUBLIC_API_BOUNDARY.md` — sealed public API boundary and compatibility-only package list.

- `docs/PUBLIC_IMPORT_RULES.md` — Ada-level public/private import boundary.

## Package metadata

- `alire.toml` — Alire source-crate manifest for `i18n`.
- `LICENSE` — MIT license text matching the manifest.
- `docs/PACKAGING.md` — package identity and Alire consumption notes.

## Release hygiene

| File | Purpose |
| --- | --- |
| `.gitignore` | Keeps GNAT/GPRbuild, Alire, test, and example build outputs out of the source release tree. |
