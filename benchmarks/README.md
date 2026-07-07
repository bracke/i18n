# Benchmarks

This directory contains executable microbenchmarks for public render hot paths.
They use only the stable public API and a fixed catalog under `catalogs/`.

## Run

```sh
alr exec -- gprbuild -P benchmarks/benchmarks.gpr
./benchmarks/bin/render_benchmarks
```

For CI and release-smoke checks, use the shorter mode:

```sh
./benchmarks/bin/render_benchmarks --smoke
```

The benchmark reports elapsed time, microseconds per operation, and a checksum
for both materialized `Render` and bounded caller-buffer `Render_Into` cases.
