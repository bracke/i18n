with I18N.Locale_Data;

package body I18N.List_Format is

   function Separator (Locale : String; Family : String; Part : String)
     return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Lookup
          ("list_separator", Locale, Family & ":" & Part, Found);
   begin
      return (if Found then Value else "");
   end Separator;

end I18N.List_Format;
