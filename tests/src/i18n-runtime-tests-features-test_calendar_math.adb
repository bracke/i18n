with I18N.Calendar_Math;  use I18N.Calendar_Math;

--  Pure algorithm, no data file: known cross-calendar dates plus round-trips.
separate (I18N.Runtime.Tests.Features)
procedure Test_Calendar_Math
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   function Dt (Y : Long_Long_Integer; M, D : Positive) return Date is
     ((Y, M, D));
begin
   --  Cross-calendar conversions against well-known correspondences.
   Assert (Convert (Gregorian, Julian, Dt (2024, 3, 14)) = Dt (2024, 3, 1),
           "Julian runs 13 days behind Gregorian in the 2000s");
   Assert (Convert (Gregorian, Buddhist, Dt (2024, 1, 1)) = Dt (2567, 1, 1),
           "Thai Buddhist = Gregorian + 543");
   Assert (Convert (Gregorian, ROC, Dt (2024, 1, 1)) = Dt (113, 1, 1),
           "Minguo (ROC) = Gregorian - 1911");
   Assert (Convert (Islamic, Julian, Dt (1, 1, 1)) = Dt (622, 7, 16),
           "1 Muharram 1 AH = Julian 622-07-16");
   Assert (Convert (Gregorian, Hebrew, Dt (2024, 10, 3)) = Dt (5785, 7, 1),
           "Rosh Hashanah 5785 (Tishri 1) = 2024-10-03");
   Assert (Convert (Gregorian, Persian, Dt (2024, 3, 20)) = Dt (1403, 1, 1),
           "Nowruz 1403 = 2024-03-20");
   Assert (Convert (Gregorian, Indian, Dt (2024, 3, 21)) = Dt (1946, 1, 1),
           "Chaitra 1, Saka 1946 = 2024-03-21");
   Assert (Convert (Coptic, Julian, Dt (1, 1, 1)) = Dt (284, 8, 29),
           "1 Thout 1 = Julian 284-08-29");
   Assert (Convert (Ethiopic, Julian, Dt (1, 1, 1)) = Dt (8, 8, 29),
           "1 Maskaram 1 = Julian 8-08-29");

   --  Round-trip through the fixed day number for every calendar.
   for Cal in Calendar_Kind loop
      for RD in Long_Long_Integer range 700_000 .. 700_400 loop
         Assert (To_Fixed (Cal, From_Fixed (Cal, RD)) = RD,
                 "round-trip " & Cal'Image & RD'Image);
      end loop;
   end loop;

   --  Day of week: 2024-01-01 was a Monday (0 = Sunday).
   Assert (Day_Of_Week (Gregorian, Dt (2024, 1, 1)) = 1, "2024-01-01 is Monday");

   --  Leap years.
   Assert (Is_Leap_Year (Gregorian, 2024), "2024 is a Gregorian leap year");
   Assert (not Is_Leap_Year (Gregorian, 2023), "2023 is not leap");
   Assert (not Is_Leap_Year (Gregorian, 1900), "1900 is not a leap year");
   Assert (Is_Leap_Year (Gregorian, 2000), "2000 is a leap year");
   Assert (Is_Leap_Year (Julian, 1900), "Julian 1900 is leap");

   --  Days in month.
   Assert (Days_In_Month (Gregorian, 2024, 2) = 29, "Feb 2024 has 29 days");
   Assert (Days_In_Month (Gregorian, 2023, 2) = 28, "Feb 2023 has 28 days");
   Assert (Days_In_Month (Coptic, 1, 13) = 5, "Coptic epagomenal month = 5");
   Assert (Days_In_Month (Coptic, 3, 13) = 6, "Coptic leap epagomenal = 6");

   --  Months in year (Hebrew leap = 13 months).
   Assert (Months_In_Year (Hebrew, 5784) = 13, "Hebrew 5784 is a leap year");
   Assert (Months_In_Year (Hebrew, 5785) = 12, "Hebrew 5785 is a common year");
   Assert (Months_In_Year (Coptic, 1) = 13, "Coptic has 13 months");
   Assert (Months_In_Year (Gregorian, 2024) = 12, "Gregorian has 12 months");
end Test_Calendar_Math;
