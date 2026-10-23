with I18N.Locale_Data;
with I18N.Regions;

package body I18N.Week_Data is

   --  Field ("first" or "min") for Locale's region, else the world's.
   function Lookup (Field : String; Locale : String) return String is
      Found     : Boolean;
      Own       : constant String := I18N.Regions.Region (Locale);
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
