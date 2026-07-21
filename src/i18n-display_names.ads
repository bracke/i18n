--  CLDR display names: human-readable names for languages, scripts, territories,
--  variants, and BCP-47 keys/types, plus composition of a full locale's display
--  name. Backed by the runtime data file "display-names" (see I18N.Data_Store);
--  when that file is absent every entry falls back to the code itself, so the
--  API never fails.
--
--  Locale identifiers should be CLDR-canonical (e.g. "en", "zh-Hant-HK");
--  underscores are accepted and treated as hyphens. Lookup walks the locale's
--  parents ("zh-Hant-HK" -> "zh-Hant" -> "zh" -> root), matching CLDR fallback.
package I18N.Display_Names is

   --  Name of a language subtag (e.g. Language_Name ("en", "de") = "German").
   --  Returns Code when no name is available.
   function Language_Name (Locale : String; Code : String) return String;

   --  Name of a script subtag (e.g. Script_Name ("en", "Latn") = "Latin").
   function Script_Name (Locale : String; Code : String) return String;

   --  Name of a territory/region subtag (Territory_Name ("en", "US") =
   --  "United States"). Accepts UN M.49 numeric regions too (e.g. "001").
   function Territory_Name (Locale : String; Code : String) return String;

   --  Name of a language variant subtag.
   function Variant_Name (Locale : String; Code : String) return String;

   --  Name of a BCP-47 key (Key_Name ("en", "calendar") = "Calendar").
   function Key_Name (Locale : String; Code : String) return String;

   --  Name of a BCP-47 key type where CLDR provides a flat name.
   function Type_Name (Locale : String; Code : String) return String;

   --  Full display name of Of_Locale, expressed in Locale, composed with CLDR's
   --  localeDisplayPattern (e.g. Locale_Display_Name ("en", "zh-Hant-HK") =
   --  "Chinese (Traditional, Hong Kong SAR China)").
   function Locale_Display_Name
     (Locale    : String;
      Of_Locale : String)
      return String;

   --  True when the display-name data file is installed and loaded.
   function Available return Boolean;

end I18N.Display_Names;
