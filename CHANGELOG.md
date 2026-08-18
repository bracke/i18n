# Changelog

Notable changes to i18n. Format follows [Keep a Changelog](https://keepachangelog.com/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`alire.toml` says `1.1.0`; consumers here pin this crate **by path**, so the
commit is what a consumer's release records.

## [Unreleased]

### Fixed

- **A fresh clone produces `share/i18n/formats.i18ndata` again.** The
  regeneration's fast path returns early when the generated body is present and
  newer than the subset — which stopped being safe when the body itself was
  committed: one generator writes the body *and* the formats file, and only the
  body was tracked. A consumer's CI (`messages`, which asserts the file exists)
  had been failing on all three hosts since.
- "Already generated" now means present *and non-empty*. Several artifacts were
  tracked as zero-byte placeholders, and every "is it there?" test answered yes
  for a file holding nothing, so a clone shipped empty tables that nothing
  regenerated.
- A workspace without the CLDR tooling, or without a reachable upstream, is no
  longer a failed build. The regeneration runs as a pre-build action in every
  consumer's workspace, and a consumer checks out the crates the *library*
  needs, not the crates its generators need; the attempt is reported and the
  build carries on. The consumer that needs the data asserts it where it needs
  it.
- The CLDR download resumes rather than restarting, and judges an attempt by
  what it added: progress is retried at once, a stall waits, and six stalls in a
  row give up. It was six restarts from zero with a minute of backoff between
  them.

### Changed

- Generated `.i18ndata` files are no longer tracked as empty placeholders, so a
  build no longer leaves six modified files in the tree.

## Releasing

No procedure yet.
