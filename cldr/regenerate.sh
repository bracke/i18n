#!/bin/sh
#  Bring the generated CLDR tables into existence, from whatever the tree has.
#
#  src/i18n-cldr_data*.adb are build artifacts, not sources: they are gitignored
#  because re-committing a 14 MB generated file on every generator change bloats
#  history permanently. That leaves a clone with the spec and no body, so the
#  build has to be able to produce one. This script is the cascade that does it,
#  cheapest path first:
#
#    1. body already present  -> nothing to do
#    2. data/cldr_subset.txt  -> generate
#    3. upstream/cldr-json    -> import, then generate
#    4. nothing               -> download the release, import, then generate
#
#  Only step 1 costs anything in the normal case, so this is safe to run before
#  every build. Steps 2-4 are what a fresh clone or a CI runner actually needs.
#
#  Run from the i18n crate root (Alire pre-build actions already are).

set -eu

CLDR_DIR="cldr"
BODY="src/i18n-cldr_data.adb"
SUBSET="$CLDR_DIR/data/cldr_subset.txt"
UPSTREAM="$CLDR_DIR/upstream/cldr-json"

log () { printf 'cldr: %s\n' "$1"; }

if [ ! -d "$CLDR_DIR" ]; then
   log "no $CLDR_DIR directory; cannot regenerate" >&2
   exit 1
fi

#  The generators are their own crate (cldr_tools) so that the library never
#  inherits an HTTP stack and a ZIP decoder. Build them on demand.
build_tools () {
   if [ ! -x "$CLDR_DIR/bin/generate_cldr_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_display_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_annotation_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_calendar_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_personname_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_rbnf_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_ucd_normalization_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_ucd_segmentation_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_uca_collation_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_collation_tailoring" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_ucd_uprops_data" ] \
      || [ ! -x "$CLDR_DIR/bin/generate_cldr_transform_data" ]; then
      log "building the CLDR tools"
      ( cd "$CLDR_DIR" && alr -n build --profiles='*=development' >/dev/null )
   fi
}

#  Runtime data files for the "heavy/optional" areas read upstream cldr-json
#  directly, so each is generated only when its vendored upstream is present and
#  its output is missing. Best-effort: the library compiles and runs without
#  them, the feature just reports itself unavailable.
generate_runtime_data () {
   UP="$CLDR_DIR/upstream/cldr-json"
   if [ ! -f "$CLDR_DIR/../share/i18n/display-names.i18ndata" ] \
      && [ -d "$UP/cldr-localenames-full" ]; then
      build_tools
      log "generating share/i18n/display-names.i18ndata"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_display_data )
   fi
   if [ ! -d "$CLDR_DIR/../share/i18n/annotations" ] \
      && [ -d "$UP/cldr-annotations-full" ]; then
      build_tools
      log "generating share/i18n/annotations shards"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_annotation_data )
   fi
   if [ ! -d "$CLDR_DIR/../share/i18n/calendars" ] \
      && [ -d "$UP/cldr-cal-islamic-full" ]; then
      build_tools
      log "generating share/i18n/calendars shards"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_calendar_data )
   fi
   if [ ! -d "$CLDR_DIR/../share/i18n/person-names" ] \
      && [ -d "$UP/cldr-person-names-full" ]; then
      build_tools
      log "generating share/i18n/person-names shards"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_personname_data )
   fi
   if [ ! -d "$CLDR_DIR/../share/i18n/rbnf" ] \
      && [ -d "$UP/cldr-rbnf" ]; then
      build_tools
      log "generating share/i18n/rbnf shards"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_rbnf_data )
   fi
   #  UCD normalization data (from unicode.org, not cldr-json). Fetch the UCD
   #  files if missing, then generate; best-effort like the rest.
   if [ ! -f "$CLDR_DIR/../share/i18n/normalization.i18ndata" ]; then
      [ -f "$CLDR_DIR/upstream/ucd/UnicodeData.txt" ] \
        || sh "$CLDR_DIR/fetch_ucd.sh" || true
      if [ -f "$CLDR_DIR/upstream/ucd/UnicodeData.txt" ]; then
         build_tools
         log "generating share/i18n/normalization.i18ndata"
         ( cd "$CLDR_DIR" && ./bin/generate_ucd_normalization_data )
      fi
   fi
   #  Segmentation break tables (UAX #29 / #14), also from the UCD.
   if [ ! -f "$CLDR_DIR/../share/i18n/segmentation.i18ndata" ]; then
      [ -f "$CLDR_DIR/upstream/ucd/LineBreak.txt" ] \
        || sh "$CLDR_DIR/fetch_ucd.sh" || true
      if [ -f "$CLDR_DIR/upstream/ucd/LineBreak.txt" ]; then
         build_tools
         log "generating share/i18n/segmentation.i18ndata"
         ( cd "$CLDR_DIR" && ./bin/generate_ucd_segmentation_data )
      fi
   fi
   #  Collation (UCA DUCET root + CLDR locale tailorings).
   if [ ! -f "$CLDR_DIR/../share/i18n/collation.i18ndata" ]; then
      [ -f "$CLDR_DIR/upstream/uca/allkeys.txt" ] \
        || sh "$CLDR_DIR/fetch_ucd.sh" || true
      if [ -f "$CLDR_DIR/upstream/uca/allkeys.txt" ]; then
         build_tools
         log "generating share/i18n/collation.i18ndata"
         ( cd "$CLDR_DIR" && ./bin/generate_uca_collation_data )
         if [ -d "$CLDR_DIR/upstream/collation" ]; then
            log "generating share/i18n/collation/ tailoring shards"
            ( cd "$CLDR_DIR" && ./bin/generate_cldr_collation_tailoring )
         fi
      fi
   fi
   #  Transliteration (UCA/UCD 16 properties + CLDR transform catalog).
   if [ ! -f "$CLDR_DIR/../share/i18n/uprops.i18ndata" ]; then
      [ -f "$CLDR_DIR/upstream/ucd16/Scripts.txt" ] \
        || sh "$CLDR_DIR/fetch_ucd.sh" || true
      if [ -f "$CLDR_DIR/upstream/ucd16/Scripts.txt" ]; then
         build_tools
         log "generating share/i18n/uprops.i18ndata"
         ( cd "$CLDR_DIR" && ./bin/generate_ucd_uprops_data )
      fi
   fi
   if [ ! -f "$CLDR_DIR/../share/i18n/transforms/_index.i18ndata" ] \
      && [ -d "$CLDR_DIR/upstream/transforms" ]; then
      build_tools
      log "generating share/i18n/transforms/ catalog"
      ( cd "$CLDR_DIR" && ./bin/generate_cldr_transform_data )
   fi
}

generate () {
   build_tools
   log "generating $BODY"
   ( cd "$CLDR_DIR" && ./bin/generate_cldr_data )
   generate_runtime_data
}

import_from_upstream () {
   build_tools
   log "importing from $UPSTREAM (this takes a while)"
   ( cd "$CLDR_DIR" \
     && ./bin/generate_cldr_export \
     && ./bin/import_cldr_raw \
     && ./bin/extract_cldr_normalized \
     && ./bin/import_cldr_subset )
}

download_upstream () {
   build_tools
   if [ ! -x "$CLDR_DIR/bin/download_cldr_upstream" ]; then
      log "downloader not built; cannot fetch upstream" >&2
      exit 1
   fi
   log "fetching the CLDR release named by upstream/source_manifest.txt"
   ( cd "$CLDR_DIR" && ./bin/download_cldr_upstream )
}


#  Step 1 -- the compiled body is already current. "Current" means newer than
#  the subset it is generated from; without the timestamp test a stale body
#  silently survives a subset change. The runtime data files are separate
#  artifacts, so still (re)generate them when they are missing.
if [ -f "$BODY" ]; then
   if [ ! -f "$SUBSET" ] || [ "$BODY" -nt "$SUBSET" ]; then
      generate_runtime_data
      exit 0
   fi
   log "$BODY is older than $SUBSET; regenerating"
fi

#  Step 2 -- the pinned subset is the generator's real input.
if [ -f "$SUBSET" ]; then
   generate
   exit 0
fi

#  Step 3 -- upstream JSON present: import down to the subset, then generate.
if [ -d "$UPSTREAM" ]; then
   import_from_upstream
   generate
   exit 0
fi

#  Step 4 -- nothing local: fetch the release, then fall through steps 3 and 2.
download_upstream
import_from_upstream
generate
