with I18N.Date_Time_Format;

--  An ISO 8601 interval value as CLDR 48's interval formats write it: the
--  pattern for the greatest field that differs, else the fallback joining
--  two whole dates.
separate (I18N.Platform_Tests)
procedure Test_Date_Intervals
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   Thin    : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#89#)];
   En_Dash : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#93#)];
   Range_Dash : constant String := Thin & En_Dash & Thin;

   function Interval (Value, Locale, Style : String) return String is
      Buffer : String (1 .. 256);
      Last   : Natural;
      Ok     : Boolean;
      Full   : Boolean;
   begin
      I18N.Date_Time_Format.Format_Date_Into (Value, Locale, Style, Buffer, Last, Ok, Full);
      return (if Ok and then not Full then Buffer (1 .. Last) else "<failed>");
   end Interval;
begin
   Assert (Interval ("2026-10-09/2026-10-15", "en", "::yMMMd") = "Oct 9" & Range_Dash & "15, 2026",
           "English days of one month share the month and year");
   Assert (Interval ("2026-10-09/2026-11-15", "en", "::yMMMd") = "Oct 9" & Range_Dash & "Nov 15, 2026",
           "English months of one year share the year");
   Assert (Interval ("2026-10-09/2027-01-15", "en", "::yMMMd")
           = "Oct 9, 2026" & Range_Dash & "Jan 15, 2027",
           "English years are written twice");
   Assert (Interval ("2026-10-09/2026-10-15", "de", "::yMMMd") = "9." & En_Dash & "15. Okt. 2026",
           "German days of one month");
   Assert (Interval ("2026-10-09/2026-11-15", "de", "::yMd") = "09.10." & Range_Dash & "15.11.2026",
           "German numeric months of one year");
   Assert (Interval ("2026-10-09/2026-10-15", "pl", "::yMMMd")
           = "9" & En_Dash & "15 pa" & Character'Val (16#C5#) & Character'Val (16#BA#) & " 2026",
           "Polish days of one month");
   Assert (Interval ("2026-10-09/2026-10-09", "de", "::yMMMd") = "9. Okt. 2026",
           "one day is that date");
   Assert (Interval ("2026-10-09/2026-10-15", "de", "medium") = "09.10.2026" & Range_Dash & "15.10.2026",
           "a named style joins two whole dates by the fallback");
end Test_Date_Intervals;
