with I18N.CLDR_Data;
with I18N.TZ_Rules;

--  A zone's offset after its recorded transitions end comes from its final
--  rule. The compiled table used to stop in 2050 and keep the last offset
--  for ever after, so daylight saving time ended there; these are the
--  instants that showed it, against what zdump gives for the same zones.
separate (I18N.Platform_Tests)
procedure Test_Time_Zone_Rules
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   function Offset (Zone : String; Y, M, D, H : Natural) return Integer is
      Valid  : Boolean;
      Result : constant Integer :=
        I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC (Zone, Y, M, D, H, 0, 0, Valid);
   begin
      Assert (Valid, Zone & " is a known zone");
      return Result;
   end Offset;

   function Rule_Offset (Rule : String; Y, M, D, H, Mi, S : Natural) return Integer is
      Valid  : Boolean;
      Result : constant Integer :=
        I18N.TZ_Rules.Offset_At (Rule, I18N.TZ_Rules.Epoch_Seconds (Y, M, D, H, Mi, S), Valid);
   begin
      Assert (Valid, Rule & " is readable");
      return Result;
   end Rule_Offset;
begin
   --  Before and after the old end of the table.
   Assert (Offset ("America/New_York", 2049, 7, 1, 12) = -4 * 3_600, "New York summer 2049 is EDT");
   Assert (Offset ("America/New_York", 2051, 7, 1, 12) = -4 * 3_600, "New York summer 2051 is still EDT");
   Assert (Offset ("America/New_York", 2099, 1, 15, 12) = -5 * 3_600, "New York winter 2099 is EST");
   Assert (Offset ("Europe/Berlin", 2060, 7, 1, 12) = 2 * 3_600, "Berlin summer 2060 is CEST");

   --  Southern hemisphere: daylight time spans the new year.
   Assert (Offset ("Australia/Sydney", 2080, 1, 15, 0) = 11 * 3_600, "Sydney January 2080 is AEDT");
   Assert (Offset ("Australia/Sydney", 2080, 7, 15, 0) = 10 * 3_600, "Sydney July 2080 is AEST");

   --  Casablanca's predicted Ramadan changes run past 2050: they are kept, not
   --  replaced by the rule, until the rule takes over after them.
   Assert (Offset ("Africa/Casablanca", 2051, 5, 7, 1) = 3_600, "Casablanca before Ramadan 2051 is +01");
   Assert (Offset ("Africa/Casablanca", 2051, 5, 7, 3) = 0, "Casablanca in Ramadan 2051 is +00");

   --  The rule reader itself, on the forms zic writes: transition times
   --  past midnight and before it, Julian days, fractional offsets.
   Assert (Rule_Offset ("EET-2EEST,M4.5.5/0,M10.5.4/24", 2101, 10, 27, 20, 59, 59) = 10_800
           and then Rule_Offset ("EET-2EEST,M4.5.5/0,M10.5.4/24", 2101, 10, 27, 21, 0, 0) = 7_200,
           "Cairo's end of daylight time at 24:00");
   Assert (Rule_Offset ("<-02>2<-01>,M3.5.0/-1,M10.5.0/0", 2101, 3, 27, 0, 59, 59) = -7_200
           and then Rule_Offset ("<-02>2<-01>,M3.5.0/-1,M10.5.0/0", 2101, 3, 27, 1, 0, 0) = -3_600,
           "Nuuk's start of daylight time at -1:00, the Saturday before");
   Assert (Rule_Offset ("<+00>0<+01>,0/0,J365/25", 2120, 7, 1, 0, 0, 0) = 3_600,
           "Casablanca's rule keeps +01 all year");
   Assert (Rule_Offset ("<+1245>-12:45<+1345>,M9.5.0/2:45,M4.1.0/3:45", 2101, 1, 1, 0, 0, 0) = 49_500,
           "Chatham in January is +13:45");
   Assert (I18N.TZ_Rules.Epoch_Seconds (2000, 3, 1) = 951_868_800, "epoch seconds of 2000-03-01");
end Test_Time_Zone_Rules;
