with I18N.Locale_Data;

package body I18N.List_Format is

   --  U+2205 three times, in UTF-8.
   Empty_Set : constant String :=
     Character'Val (16#E2#) & Character'Val (16#88#) & Character'Val (16#85#);
   No_Value  : constant String := Empty_Set & Empty_Set & Empty_Set;

   function Separator (Locale : String; Family : String; Part : String)
     return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("list_separator", Locale, Family & ":" & Part, Found);
   begin
      --  CLDR's "{0}{1}" (Japanese narrow units) is stored as its "no value"
      --  marker, as the store holds no empty values.
      return (if Found and then Value /= No_Value then Value else "");
   end Separator;

end I18N.List_Format;
