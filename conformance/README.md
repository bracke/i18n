# ICU/CLDR Conformance Harness

This directory contains Ada-only local conformance tooling. The first gate is
`check_conformance`, which reads `fixtures/manifest.txt`, validates the pinned
Unicode/CLDR/ICU baseline, requires every completion-plan suite to be declared,
and runs public-render fixture rows where deterministic fixtures are present.

Run it through Alire:

```sh
alr exec -- gprbuild -P conformance/conformance.gpr
alr exec -- ./conformance/bin/check_conformance
```

The harness is a gate, not a completion claim. Full ICU/CLDR completion remains
blocked until the checklist in `docs/ICU_CLDR_COMPLETION_CHECKLIST.md` has no
unchecked items and the local verification gate passes.
