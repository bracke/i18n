--  CLDR's week data for a locale (supplemental weekData), by the locale's
--  region -- its own, else its likely one ("en" is the United States, "de"
--  Germany) -- else the world's.
package I18N.Week_Data is

   --  @param Locale A BCP 47 locale.
   --  @return The day its weeks start on: "mon", "sun", "sat" or "fri".
   function First_Day (Locale : String) return String;

   --  @param Locale A BCP 47 locale.
   --  @return How many days of a year's first week must fall in that year
   --          (4 in most of Europe, 1 in the United States).
   function Minimal_Days (Locale : String) return Positive;

end I18N.Week_Data;
