--  On-the-fly-aware relative-time formatting primitives.
--
--  A peer of I18N.Number_Format and I18N.Date_Time_Format: it returns the
--  localized CLDR relative-time data, consulting the runtime "formats" data
--  file for locales the crate's `locales` configuration narrowed out of the
--  compiled tables and falling back to those tables otherwise. Message
--  renderers delegate here instead of reading I18N.CLDR_Data directly, so a
--  narrowed-out locale still formats "in 3 days" in its own words.
--
--  This layer does not consult I18N.Runtime_Data: the catalog-override tier
--  (with its own category fallbacks) stays with the caller.
package I18N.Relative_Format is

   --  The locale's "today"/"this week" style current-offset label.
   function Current_Name (Locale : String; Base : String; Width : String)
     return String;

   --  Prefix/suffix wrapped around a nonzero relative offset.
   function Offset_Prefix (Locale : String; Future : Boolean) return String;
   function Offset_Suffix (Locale : String; Future : Boolean) return String;

   --  The unit label selected by CLDR plural category ("" when none exists).
   function Unit_Category_Name
     (Locale : String; Base : String; Category : String) return String;

   --  The complete "{0}"-bearing pattern for a nonzero offset. Falls back from
   --  the given category to "other" within the on-the-fly tier, as CLDR does.
   function Time_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Future   : Boolean)
      return String;

   --  The relative-time-specific unit display name (singular/plural).
   function Unit_Display_Name
     (Locale : String; Base : String; Singular : Boolean) return String;

end I18N.Relative_Format;
