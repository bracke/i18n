# Validation and Release Gate

The v1.0 release freezes the test suite as the release gate. A v1.0 build is valid only if all release-gate groups pass.

Required groups:

* parser tests
* validator tests
* compiler tests
* IR equivalence tests
* render tests
* plural/select/selectordinal tests
* locale fallback tests
* diagnostic tests
* fuzz smoke tests
* corpus regression tests
* concurrency tests
* zero-allocation checks
* public API freeze tests
* catalog validation tests

Corpus requirements remain in force:

```text
100% pass
0 semantic divergence
0 unexpected parser acceptances
0 unexpected parser rejections
```

## Public API freeze validation

Examples and public API tests must compile using only:

* `I18N`
* `I18N.Runtime`
* `I18N.Result`
* `I18N.Diagnostics`
* `I18N.Arguments`
* `I18N.Locales`

Any example requiring parser, AST, compiler, compiled IR, cache, buffer, fast-render, or lower-level renderer packages is not a valid v1.0 public example.

## Documentation validation

Documentation must describe implemented behavior only. A release is invalid if documentation promises:

* a TOML catalog parser;
* a binary catalog format;
* CLDR plural-data generation;
* public parser/compiler access;
* public `Render` itself is zero-allocation;
* diagnostics that affect correctness;
* fallback semantics other than the frozen hyphen-parent/default-locale chain.


## Toolchain verification

The validation boundary is release-ready only when the build, test, example, Alire, and documentation checks in `docs/RELEASE_VERIFICATION.md` pass for the intended release channel.
