--  CLDR emoji annotations: each emoji's display name and its search keywords,
--  per locale. Backed by per-locale runtime shards under
--  share/i18n/annotations/<locale>.i18ndata (base) and
--  share/i18n/annotations-derived/<locale>.i18ndata (skin-tone / ZWJ / flag
--  sequences); only the queried locale's shard is loaded. Locale identifiers
--  follow CLDR casing (e.g. "en", "zh-Hant"); underscores are accepted.
--
--  Emoji keys are byte-exact UTF-8 grapheme clusters -- pass the emoji as it
--  appears in the CLDR data (no case folding or normalization).
package I18N.Emoji is

   --  Display name of an emoji (CLDR "tts"), e.g. Name ("en", U+1F600) =
   --  "grinning face". "" when no annotation is installed for it.
   function Name (Locale : String; Emoji : String) return String;

   --  All search keywords for an emoji, joined by the unit separator U+001F
   --  (CLDR "default"). "" when none. Use Keyword_Count / Keyword to iterate.
   function Keywords (Locale : String; Emoji : String) return String;

   --  Number of keywords for an emoji.
   function Keyword_Count (Locale : String; Emoji : String) return Natural;

   --  The N-th keyword (1-based); "" if out of range.
   function Keyword
     (Locale : String;
      Emoji  : String;
      N      : Positive)
      return String;

   --  True when an annotation shard is installed for the locale (or a parent).
   function Available (Locale : String) return Boolean;

end I18N.Emoji;
