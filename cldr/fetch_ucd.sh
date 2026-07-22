#!/bin/sh
#  Fetch the Unicode Character Database files the normalization engine (and the
#  later break / collation phases) build from. UCD is not part of cldr-json, so
#  it is fetched separately from unicode.org, pinned to the Unicode version CLDR
#  aligns with. Kept in the tools/build layer -- the library never fetches.
#
#  Run from the i18n crate root.  Usage: sh cldr/fetch_ucd.sh [version]
set -eu

VER="${1:-17.0.0}"
DEST="cldr/upstream/ucd"
BASE="https://www.unicode.org/Public/$VER/ucd"

mkdir -p "$DEST"
for f in UnicodeData.txt CompositionExclusions.txt \
         DerivedNormalizationProps.txt NormalizationTest.txt; do
   if [ ! -f "$DEST/$f" ]; then
      printf 'ucd: fetching %s\n' "$f"
      curl -fsSL -o "$DEST/$f" "$BASE/$f"
   fi
done
printf 'ucd: %s present in %s\n' "$VER" "$DEST"
