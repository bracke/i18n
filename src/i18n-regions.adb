with Ada.Characters.Handling;

with I18N.Locale_Data;
with I18N.Locales;

package body I18N.Regions is

   function Is_Region (Subtag : String) return Boolean is
     ((Subtag'Length = 2 and then Subtag (Subtag'First) in 'A' .. 'Z' | 'a' .. 'z')
      or else (Subtag'Length = 3 and then Subtag (Subtag'First) in '0' .. '9'));

   function Is_Script (Subtag : String) return Boolean is
     (Subtag'Length = 4 and then (for all C of Subtag => C in 'A' .. 'Z' | 'a' .. 'z'));

   --  The region subtag Tag names after its language, "" if none.
   function Named_Region (Tag : String) return String is
      Start : Positive := Tag'First;
   begin
      for Index in Tag'Range loop
         if Index = Tag'Last or else Tag (Index + 1) in '-' | '_' then
            if Start > Tag'First and then Is_Region (Tag (Start .. Index)) then
               return Ada.Characters.Handling.To_Upper (Tag (Start .. Index));
            end if;
            Start := Index + 2;
         end if;
      end loop;
      return "";
   end Named_Region;

   function Region (Locale : String) return String is
      Own : constant String := Named_Region (Locale);
   begin
      if Own /= "" then
         return Own;
      end if;
      declare
         --  The language, and its script where the tag names one.
         Language_Last : Natural := Locale'First - 1;
         Script        : String (1 .. 4) := [others => ' '];
         Has_Script    : Boolean := False;
         Found         : Boolean;
      begin
         while Language_Last < Locale'Last and then Locale (Language_Last + 1) not in '-' | '_' loop
            Language_Last := Language_Last + 1;
         end loop;
         if Language_Last + 5 <= Locale'Last
           and then Is_Script (Locale (Language_Last + 2 .. Language_Last + 5))
           and then (Language_Last + 5 = Locale'Last or else Locale (Language_Last + 6) in '-' | '_')
         then
            Script := Locale (Language_Last + 2 .. Language_Last + 5);
            Script (1) := Ada.Characters.Handling.To_Upper (Script (1));
            Script (2 .. 4) := Ada.Characters.Handling.To_Lower (Script (2 .. 4));
            Has_Script := True;
         end if;
         declare
            Language : constant String := Ada.Characters.Handling.To_Lower (Locale (Locale'First .. Language_Last));
            By_Script : constant String :=
              (if Has_Script then I18N.Locale_Data.Lookup ("likely_region", "und", Language & "-" & Script, Found)
               else "");
            By_Language : constant String :=
              (if By_Script /= "" then By_Script
               else I18N.Locale_Data.Lookup ("likely_region", "und", Language, Found));
         begin
            if By_Language /= "" then
               return By_Language;
            end if;
         end;
      end;
      --  No likely-subtag data installed: the compiled families.
      return Named_Region (I18N.Locales.Maximize (Locale));
   end Region;

end I18N.Regions;
