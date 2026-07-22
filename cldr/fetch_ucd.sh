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

#  Collation (Phase 7): the UCA DUCET, its conformance tests, the matching
#  PropList (Unified_Ideograph), and the CLDR locale tailoring rules. UCA and
#  CLDR trail the UCD by one release, so these pin 16.0.0 / CLDR release-46.
UCA_VER="16.0.0"
UCA_DEST="cldr/upstream/uca"
CLDR_TAG="release-46"
COL_DEST="cldr/upstream/collation"
mkdir -p "$UCA_DEST" "$COL_DEST"

if [ ! -f "$UCA_DEST/allkeys.txt" ]; then
   printf 'uca: fetching allkeys.txt\n'
   curl -fsSL -o "$UCA_DEST/allkeys.txt" \
     "https://www.unicode.org/Public/UCA/$UCA_VER/allkeys.txt"
fi
if [ ! -f "$UCA_DEST/PropList.txt" ]; then
   printf 'uca: fetching PropList.txt (%s)\n' "$UCA_VER"
   curl -fsSL -o "$UCA_DEST/PropList.txt" \
     "https://www.unicode.org/Public/$UCA_VER/ucd/PropList.txt"
fi
if [ ! -f "$UCA_DEST/CollationTest/CollationTest_SHIFTED.txt" ]; then
   printf 'uca: fetching CollationTest.zip\n'
   curl -fsSL -o "$UCA_DEST/CollationTest.zip" \
     "https://www.unicode.org/Public/UCA/$UCA_VER/CollationTest.zip"
   ( cd "$UCA_DEST" && unzip -o CollationTest.zip >/dev/null 2>&1 ) || true
fi

#  CLDR standard collation tailorings for locales with non-trivial rules.
for loc in sv da nb fi is es ca pt et pl cs sk sl hr hu ro tr az lt lv vi; do
   if [ ! -f "$COL_DEST/$loc.xml" ]; then
      curl -fsSL -o "$COL_DEST/$loc.xml" \
        "https://raw.githubusercontent.com/unicode-org/cldr/$CLDR_TAG/common/collation/$loc.xml" \
        2>/dev/null || rm -f "$COL_DEST/$loc.xml"
   fi
done
printf 'uca: %s / CLDR %s collation data present\n' "$UCA_VER" "$CLDR_TAG"
