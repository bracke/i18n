with I18N.Date_Time_Format;
with I18N.Number_Format;

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

   function Clock (Value, Locale, Style : String) return String is
      Buffer : String (1 .. 256);
      Last   : Natural;
      Ok     : Boolean;
      Full   : Boolean;
   begin
      I18N.Date_Time_Format.Format_Time_Into (Value, Locale, Style, Buffer, Last, Ok, Full);
      return (if Ok and then not Full then Buffer (1 .. Last) else "<failed>");
   end Clock;

   function Moment (Value, Locale, Style : String) return String is
      Buffer : String (1 .. 256);
      Last   : Natural;
      Ok     : Boolean;
      Full   : Boolean;
   begin
      I18N.Date_Time_Format.Format_Date_Time_Into (Value, Locale, Style, Buffer, Last, Ok, Full);
      return (if Ok and then not Full then Buffer (1 .. Last) else "<failed>");
   end Moment;

   Narrow_No_Break : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#AF#)];

   function Number (Value, Locale : String; Style : String := "") return String is
      Buffer : String (1 .. 160);
      Last   : Natural;
      Ok     : Boolean;
      Full   : Boolean;
   begin
      I18N.Number_Format.Format_Into (Value, Locale, Style, Buffer, Last, Ok, Full);
      return (if Ok and then not Full then Buffer (1 .. Last) else "<failed>");
   end Number;
begin
   --  Number ranges and approximate numbers by CLDR's miscPatterns.
   Assert (Number ("1200/5000", "de") = "1.200" & En_Dash & "5.000", "a German number range");
   Assert (Number ("1200/5000", "ja") = "1,200" & [Character'Val (16#EF#), Character'Val (16#BD#),
           Character'Val (16#9E#)] & "5,000", "a Japanese number range");
   Assert (Number ("~12.5", "de") = [Character'Val (16#E2#), Character'Val (16#89#), Character'Val (16#88#)]
           & "12,5", "a German approximate number");
   Assert (Number ("~12", "en") = "~12", "an English approximate number");
   --  Time intervals by the locale's hour cycle, as ICU writes them.
   Assert (Clock ("14:00:00/15:30:00", "en", "::jm") = "2:00" & Range_Dash & "3:30" & Narrow_No_Break & "PM",
           "English times of one half-day share AM/PM");
   Assert (Clock ("11:00:00/13:00:00", "en", "::jm")
           = "11:00" & Narrow_No_Break & "AM" & Range_Dash & "1:00" & Narrow_No_Break & "PM",
           "English times across noon write both");
   Assert (Clock ("14:00:00/15:30:00", "de", "::jm") = "14:00" & En_Dash & "15:30 Uhr", "German times");
   --  Every interval skeleton CLDR has.
   Assert (Interval ("2026-10-09/2026-11-15", "en", "::yMMMM") = "October" & Range_Dash & "November 2026",
           "English months of one year");
   Assert (Interval ("2026-10-09/2026-11-15", "de", "::yMMMM") = "Oktober" & En_Dash & "November 2026",
           "German months of one year");
   Assert (Interval ("2026-10-09/2026-10-15", "en", "::MEd") = "Fri, 10/9" & Range_Dash & "Thu, 10/15",
           "English weekdays and numeric days");
   Assert (Interval ("2026-10-09/2026-10-15", "de", "::GyMMMd") = "9." & En_Dash & "15. Okt. 2026 n. Chr.",
           "German days with the era");
   Assert (Clock ("10:00:00/15:00:00", "en", "::Bhm")
           = "10:00 in the morning" & Range_Dash & "3:00 in the afternoon",
           "English flexible day periods on both times");
   --  A date and a time joined as the locale joins them, and one day's times.
   Assert (Moment ("2026-10-09T14:00:00Z", "de", "::yMMMdjm") = "9. Okt. 2026, 14:00",
           "a written-out date and a time joined by CLDR's glue");
   Assert (Moment ("2026-10-09T14:00:00Z/2026-10-09T15:30:00Z", "en", "::yMMMdjm")
           = "Oct 9, 2026, 2:00" & Range_Dash & "3:30" & Narrow_No_Break & "PM",
           "one day's times after the date");
   Assert (Moment ("2026-10-09T14:00:00Z/2026-10-10T15:30:00Z", "de", "::yMMMdjm")
           = "9. Okt. 2026, 14:00" & Range_Dash & "10. Okt. 2026, 15:30",
           "two days joined whole");
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
   Assert (Interval ("2026-10-09/2026-11-15", "sw", "::yMMMd") = "9 Okt 2026" & Range_Dash & "15 Nov 2026",
           "a pattern that drops the first month (CLDR 48's Swahili) gives way to the fallback");
   Assert (Interval ("2026-10-09/2026-10-09", "de", "::yMMMd") = "9. Okt. 2026",
           "one day is that date");
   Assert (Interval ("2026-10-09/2026-10-15", "de", "medium") = "09.10.2026" & Range_Dash & "15.10.2026",
           "a named style joins two whole dates by the fallback");
end Test_Date_Intervals;
