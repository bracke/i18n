--  On-the-fly-aware measurement-unit display names.
--
--  A peer of I18N.Number_Format and I18N.Date_Time_Format: it returns a
--  localized unit name (kilometer -> "kilometers" / "Kilometer" /
--  "kilomètres"), consulting the per-locale units/<locale>.i18ndata shard for
--  locales the crate's `locales` configuration narrowed out of the compiled
--  tables and falling back to those tables otherwise. Message renderers
--  delegate here instead of reading I18N.CLDR_Data directly.
--
--  The unit data is by far the largest CLDR block, so it is sharded one file
--  per locale; only the locales actually formatted are loaded at runtime.
package I18N.Unit_Format is

   --  Localized display name for Base at Width, selected by CLDR plural
   --  Category. Width accepts the CLDR "unit-width-*" spellings and the bare
   --  "full-name"/"long"/"short"/"narrow" aliases.
   function Display_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String)
      return String;

   --  The locale's "per" separator for compound units (miles per hour).
   function Per_Unit_Separator (Locale : String) return String;

end I18N.Unit_Format;
