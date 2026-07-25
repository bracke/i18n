package I18N.Parent_Locales is
   --  The CLDR supplemental parentLocale override map (parentLocales.json):
   --  locales whose fallback parent is NOT the plain drop-a-subtag truncation --
   --  region variants such as en-AU -> en-001 or es-MX -> es-419. Keys and
   --  values are store-normalised (lowercase, '-'). Parent returns "" when
   --  Locale has no override, so the caller falls back to subtag truncation.
   --  This is the small structural table the on-the-fly locale-data fallback
   --  walk consults; it stays compiled (needed to resolve every other lookup).
   function Parent (Locale : String) return String;
end I18N.Parent_Locales;
