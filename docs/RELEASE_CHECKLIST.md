# Release Checklist

A v1.0 release candidate is acceptable only when the mandatory items below are true for the candidate being published.

## Build and tests

```text
[verified] alr build succeeds
[verified] tests/alr build succeeds
[verified] tests/alr run passes
[verified] gprbuild -P examples/examples.gpr succeeds
```

## Public API

* Public examples import only public packages.
* Public result statuses match `docs/ERROR_MODEL.md`.
* Public catalog behavior matches `docs/CATALOG_FORMAT.md`.
* No public example imports parser, AST, validation, compiler, compiled IR, cache, buffer, fast-render, or lower-level renderer packages.

## Documentation

* `README.md` describes only implemented behavior.
* `docs/API.md` names the stable public API and marks compatibility-only APIs clearly.
* `docs/ICU_SUBSET.md` matches parser/validator tests.
* `docs/CATALOG_FORMAT.md` matches catalog tests.
* `docs/THREADING.md` distinguishes public render from the no-allocation compatibility `Render_Into` path.
* `docs/COMPATIBILITY.md` states the source/runtime compatibility boundary.
* `docs/RELEASE_VERIFICATION.md` states the GNAT/GPRbuild verification commands and private-package acceptance rules.

## Cleanup

* No abandoned prototype package is presented as public API.
* No non-public AST execution path is presented as the production application path.

## Release blocker

Do not tag v1.0 from documentation review alone. Before public publication, verify the library build, test project build, AUnit runner, example project, and selected packaging/documentation tooling such as Alire and GNATdoc for the candidate being published.

## Ada discriminant-safety audit

The public and internal result models use non-discriminated storage. `I18N.Result.Render_Result`, `I18N.Result.Output_View`, and `I18N.Errors.Result` may be default-created without relying on discriminated string bounds, and the verified build no longer emits the GNAT `Storage_Error` warning previously associated with default result creation.

For future maintenance:

- Do not reintroduce discriminated string fields into public or internal render-result records.
- Keep rendered text behind bounded storage or an explicitly managed string container.
- Re-run the Ada keyword and discriminant-safety audits after changing result types.
- Treat any new GNAT warning about object creation possibly raising `Storage_Error` as a release blocker.

## GNATdoc specification comments

Before release, every `.ads` subprogram declaration must have GNATdoc-style comments immediately documenting each formal parameter with `@param` and each function result with `@return`. This pass has been applied to public, private/internal, example-support, and test specifications.
