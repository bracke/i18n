--  Calendar arithmetic: convert dates between calendars via a fixed day number
--  (Rata Die, RD 1 = proleptic Gregorian 0001-01-01). Pure algorithm -- no CLDR
--  data. Complements I18N.Calendars, which localizes month/era *names*.
--
--  Supported (arithmetic calendars): Gregorian, Julian, tabular/civil Islamic,
--  Hebrew, Coptic, Ethiopic, arithmetic Persian (Solar Hijri), Indian national
--  (Saka), Thai Buddhist, and Minguo (ROC). The lunisolar Chinese/Dangi
--  calendars and the observational Islamic (umm-al-qura) are astronomical and
--  are out of scope here; Japanese date math is Gregorian with era-year
--  numbering (an era-data concern, handled by the names layer).
package I18N.Calendar_Math is

   type Calendar_Kind is
     (Gregorian, Julian, Islamic, Hebrew, Coptic, Ethiopic, Persian,
      Indian, Buddhist, ROC);

   type Date is record
      Year  : Long_Long_Integer;
      Month : Positive;   --  1 .. 13 (Hebrew leap year and Coptic/Ethiopic)
      Day   : Positive;   --  1 .. 30
   end record;

   --  Rata Die fixed day number for a calendar date.
   function To_Fixed (Cal : Calendar_Kind; D : Date) return Long_Long_Integer;

   --  Calendar date for a fixed day number.
   function From_Fixed
     (Cal : Calendar_Kind; RD : Long_Long_Integer) return Date;

   --  Convert a date from one calendar to another.
   function Convert
     (From, To : Calendar_Kind; D : Date) return Date;

   --  Day of week for a fixed day number: 0 = Sunday .. 6 = Saturday.
   function Day_Of_Week (RD : Long_Long_Integer) return Natural;

   --  Day of week of a calendar date.
   function Day_Of_Week (Cal : Calendar_Kind; D : Date) return Natural;

   --  Whether a calendar year is a leap year.
   function Is_Leap_Year
     (Cal : Calendar_Kind; Year : Long_Long_Integer) return Boolean;

   --  Number of months in a calendar year (12, or 13 for some calendars).
   function Months_In_Year
     (Cal : Calendar_Kind; Year : Long_Long_Integer) return Positive;

   --  Number of days in a calendar month.
   function Days_In_Month
     (Cal : Calendar_Kind; Year : Long_Long_Integer; Month : Positive)
      return Positive;

end I18N.Calendar_Math;
