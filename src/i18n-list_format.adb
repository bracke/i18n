with I18N.CLDR_Data;
with I18N.Locale_Data;

package body I18N.List_Format is

   function Compiled (Family : String; Part : String; Locale : String)
     return String
   is
   begin
      if Family = "or" then
         if Part = "final" then
            return I18N.CLDR_Data.List_Or_Final_Separator (Locale);
         elsif Part = "pair" then
            return I18N.CLDR_Data.List_Or_Pair_Separator (Locale);
         elsif Part = "start" then
            return I18N.CLDR_Data.List_Or_Start_Separator (Locale);
         elsif Part = "item" then
            return I18N.CLDR_Data.List_Or_Item_Separator (Locale);
         else
            return I18N.CLDR_Data.List_Or_Middle_Separator (Locale);
         end if;
      elsif Family = "unit" then
         if Part = "final" then
            return I18N.CLDR_Data.List_Unit_Final_Separator (Locale);
         elsif Part = "pair" then
            return I18N.CLDR_Data.List_Unit_Pair_Separator (Locale);
         elsif Part = "start" then
            return I18N.CLDR_Data.List_Unit_Start_Separator (Locale);
         else
            return I18N.CLDR_Data.List_Unit_Middle_Separator (Locale);
         end if;
      else
         if Part = "final" then
            return I18N.CLDR_Data.List_Final_Separator (Locale);
         elsif Part = "pair" then
            return I18N.CLDR_Data.List_Pair_Separator (Locale);
         elsif Part = "start" then
            return I18N.CLDR_Data.List_Start_Separator (Locale);
         elsif Part = "item" then
            return I18N.CLDR_Data.List_Item_Separator (Locale);
         else
            return I18N.CLDR_Data.List_Middle_Separator (Locale);
         end if;
      end if;
   end Compiled;

   function Separator (Locale : String; Family : String; Part : String)
     return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("list_separator", Locale, Family & ":" & Part, Found);
   begin
      return (if Found then Value else Compiled (Family, Part, Locale));
   end Separator;

end I18N.List_Format;
