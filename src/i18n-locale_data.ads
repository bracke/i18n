private package I18N.Locale_Data is
   --  The on-the-fly tier beneath the process-wide runtime overrides. Locale
   --  formatting data (number symbols, date names, currency placement, plural
   --  families) is served from a single "formats.i18ndata" file loaded lazily
   --  by I18N.Data_Store from the configured data dir. When no such file is
   --  installed every entry point here reports "not found", so callers fall
   --  through to whatever compiled data still backs their section.

   --  Look Section up for Locale with the same exact -> parent -> root fallback
   --  the compiled tables use. Sub is an optional composite suffix (calendar,
   --  index, ...) appended after the locale so fallback still walks locale
   --  parents. Found is False (and "" returned) when no installed file supplies
   --  a value.
   function Lookup
     (Section : String;
      Locale  : String;
      Sub     : String;
      Found   : out Boolean)
      return String;

   --  Convenience for the common shape: a runtime override keyed by Section,
   --  else the on-the-fly file, else the compiled accessor. Used by fields
   --  whose runtime key equals Section and whose compiled fallback is a plain
   --  (Locale) -> String function.
   function Field
     (Section  : String;
      Locale   : String;
      Compiled : not null access function (L : String) return String)
      return String;

   --  Exact per-locale lookup with NO fallback walk -- for fields CLDR keys by
   --  the exact locale and resolves by exact bisect (plural rule families),
   --  where walking the parentLocale chain would wrongly inherit (ht -> fr).
   --  Found is False (and "" returned) when no installed file has that key.
   function Lookup_Exact
     (Section : String; Locale : String; Found : out Boolean) return String;

   --  Membership test matching the compiled In_List (Language (Locale), list)
   --  toggles (currency symbol placement, Indian grouping): looks the locale's
   --  two-letter language up EXACTLY -- no parent or root fallback, since the
   --  compiled test is an exact list membership on the bare language. Found is
   --  False (and "" returned) when no installed file lists that language.
   function Language_Member
     (Section : String; Locale : String; Found : out Boolean) return String;

   --  Look Key up in a per-locale shard file Dir/<locale>.i18ndata (the layout
   --  used for large data such as units), walking exact -> parent -> root shard
   --  by shard so only the locales actually touched are loaded. Section is the
   --  shard's section name. Found is False (and "" returned) when no installed
   --  shard supplies a value.
   function Shard_Lookup
     (Dir     : String;
      Section : String;
      Locale  : String;
      Key     : String;
      Found   : out Boolean)
      return String;
end I18N.Locale_Data;
