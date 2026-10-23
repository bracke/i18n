with Ada.Characters.Handling;

with I18N.Locale_Data;

package body I18N.Plural_Ranges is

   use type I18N.Plurals.Plural_Category;

   function Name (Category : I18N.Plurals.Plural_Category) return String is
     (Ada.Characters.Handling.To_Lower (I18N.Plurals.Plural_Category'Image (Category)));

   function Category
     (Locale : String;
      Start  : I18N.Plurals.Plural_Category;
      Finish : I18N.Plurals.Plural_Category)
      return I18N.Plurals.Plural_Category
   is
      Language_Last : Natural := Locale'First - 1;
   begin
      while Language_Last < Locale'Last and then Locale (Language_Last + 1) not in '-' | '_' loop
         Language_Last := Language_Last + 1;
      end loop;
      declare
         Found : Boolean;
         Value : constant String :=
           I18N.Locale_Data.Lookup
             ("plural_range", "und",
              Ada.Characters.Handling.To_Lower (Locale (Locale'First .. Language_Last)) & ":" & Name (Start) & ":"
              & Name (Finish),
              Found);
      begin
         for Candidate in I18N.Plurals.Plural_Category loop
            if Found and then Value = Name (Candidate) then
               return Candidate;
            end if;
         end loop;
         return Finish;
      end;
   end Category;

end I18N.Plural_Ranges;
