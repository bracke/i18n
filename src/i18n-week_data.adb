with Ada.Characters.Handling;

with I18N.Locale_Data;
with I18N.Locales;

package body I18N.Week_Data is

   --  Locale's region subtag, after likely subtags; "" when it has none.
   function Region (Locale : String) return String is
      Full  : constant String := I18N.Locales.Maximize (Locale);
      Start : Positive := Full'First;
   begin
      for Index in Full'Range loop
         if Index = Full'Last or else Full (Index + 1) in '-' | '_' then
            declare
               Subtag : constant String := Full (Start .. Index);
            begin
               if Start > Full'First
                 and then ((Subtag'Length = 2 and then Subtag (Subtag'First) in 'A' .. 'Z' | 'a' .. 'z')
                           or else (Subtag'Length = 3 and then Subtag (Subtag'First) in '0' .. '9'))
               then
                  return Ada.Characters.Handling.To_Upper (Subtag);
               end if;
            end;
            Start := Index + 2;
         end if;
      end loop;
      return "";
   end Region;

   --  Field ("first" or "min") for Locale's region, else the world's.
   function Lookup (Field : String; Locale : String) return String is
      Found     : Boolean;
      Own       : constant String := Region (Locale);
      Of_Region : constant String :=
        (if Own = "" then "" else I18N.Locale_Data.Lookup ("week_data", "und", Field & ":" & Own, Found));
   begin
      return (if Of_Region /= "" then Of_Region
              else I18N.Locale_Data.Lookup ("week_data", "und", Field & ":001", Found));
   end Lookup;

   function First_Day (Locale : String) return String is
      Day : constant String := Lookup ("first", Locale);
   begin
      return (if Day = "" then "mon" else Day);
   end First_Day;

   function Minimal_Days (Locale : String) return Positive is
      Days : constant String := Lookup ("min", Locale);
   begin
      return (if Days'Length = 1 and then Days (Days'First) in '1' .. '7'
              then Character'Pos (Days (Days'First)) - Character'Pos ('0') else 1);
   end Minimal_Days;

end I18N.Week_Data;
