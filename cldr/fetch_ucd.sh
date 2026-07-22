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

mkdir -p "$DEST" "$DEST/auxiliary" "$DEST/emoji"

#  file : subdirectory under the UCD (empty = ucd root)
fetch() {
   f="$1"; sub="$2"
   dst="$DEST${sub:+/}$sub/$f"
   src="$BASE${sub:+/}$sub/$f"
   if [ ! -f "$dst" ]; then
      printf 'ucd: fetching %s\n' "${sub:+$sub/}$f"
      curl -fsSL -o "$dst" "$src"
   fi
}

#  Normalization (Phase 0).
for f in UnicodeData.txt CompositionExclusions.txt \
         DerivedNormalizationProps.txt NormalizationTest.txt; do
   fetch "$f" ""
done

#  Segmentation (Phase 6): break properties, line break, and their tests.
fetch LineBreak.txt ""
fetch DerivedCoreProperties.txt ""
fetch EastAsianWidth.txt ""
for f in GraphemeBreakProperty.txt WordBreakProperty.txt \
         SentenceBreakProperty.txt GraphemeBreakTest.txt WordBreakTest.txt \
         SentenceBreakTest.txt LineBreakTest.txt; do
   fetch "$f" auxiliary
done
fetch emoji-data.txt emoji

printf 'ucd: %s present in %s\n' "$VER" "$DEST"
