with I18N.CLDR_Data;
with I18N.Locale_Data;

package body I18N.Unit_Format is

   --  The shards are keyed by the three canonical source widths; fold the
   --  aliases the callers use onto them.
   function Canonical_Width (Width : String) return String is
     (if Width = "unit-width-short" or else Width = "short"
      then "unit-width-short"
      elsif Width = "unit-width-narrow" or else Width = "narrow"
      then "unit-width-narrow"
      else "unit-width-full-name");

   function Display_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Shard_Lookup
          ("units", "unit", Locale,
           Base & ":" & Canonical_Width (Width) & ":" & Category, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Display_Name (Locale, Base, Width, Category));
   end Display_Name;

   function Per_Unit_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("per_unit_separator", Locale,
         I18N.CLDR_Data.Per_Unit_Separator'Access));

end I18N.Unit_Format;
