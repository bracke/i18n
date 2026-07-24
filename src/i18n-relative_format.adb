with I18N.CLDR_Data;
with I18N.Locale_Data;

package body I18N.Relative_Format is

   function Current_Name (Locale : String; Base : String; Width : String)
     return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_current", Locale, Base & ":" & Width, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Current_Name (Locale, Base, Width));
   end Current_Name;

   function Offset_Prefix (Locale : String; Future : Boolean) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_offset_prefix", Locale,
           (if Future then "future" else "past"), Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Offset_Prefix (Locale, Future));
   end Offset_Prefix;

   function Offset_Suffix (Locale : String; Future : Boolean) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_offset_suffix", Locale,
           (if Future then "future" else "past"), Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Offset_Suffix (Locale, Future));
   end Offset_Suffix;

   function Unit_Category_Name
     (Locale : String; Base : String; Category : String) return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_unit_category", Locale, Base & ":" & Category, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Unit_Category_Name
                (Locale, Base, Category));
   end Unit_Category_Name;

   function Time_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Future   : Boolean)
      return String
   is
      Tense : constant String := (if Future then "future" else "past");
      Head  : constant String := Base & ":" & Width & ":" & Tense & ":";
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_time_pattern", Locale, Head & Category, Found);
   begin
      if Found then
         return Value;
      end if;

      --  CLDR narrows the plural category to "other" when no exact row exists;
      --  do the same within the on-the-fly tier before the compiled fallback.
      if Category /= "other" then
         declare
            Other : constant String :=
              I18N.Locale_Data.Lookup
                ("relative_time_pattern", Locale, Head & "other", Found);
         begin
            if Found then
               return Other;
            end if;
         end;
      end if;

      return I18N.CLDR_Data.Relative_Time_Pattern
               (Locale, Base, Width, Category, Future);
   end Time_Pattern;

   function Unit_Display_Name
     (Locale : String; Base : String; Singular : Boolean) return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("relative_unit_category", Locale,
           Base & ":" & (if Singular then "one" else "other"), Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Unit_Display_Name
                (Locale, Base, Singular));
   end Unit_Display_Name;

end I18N.Relative_Format;
