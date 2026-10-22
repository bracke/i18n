--  A time zone's final rule: the POSIX TZ string (such as
--  "EST5EDT,M3.2.0,M11.1.0") that zic writes at the end of every compiled
--  zone file, and that says what the zone does in every year after its
--  recorded transitions end.
--
--  The compiled CLDR data keeps a zone's transitions only until its rule
--  takes over, and asks this package for any instant after that, so daylight
--  saving time does not stop at the last year anyone wrote out. The CLDR
--  generator uses the same package to decide where that is, so the two
--  cannot disagree about what a rule means.
--
--  Read per call, with no state: a rule is a few dozen characters, and a
--  zone's offset is asked for once per formatted date.
package I18N.TZ_Rules is
   pragma Preelaborate;

   --  Seconds since 1970-01-01 00:00:00 UTC of a UTC date and time. Works for
   --  any year from 1 on; Day may run past the month's end (and Hour past 23)
   --  and carries into the next.
   function Epoch_Seconds
     (Year, Month, Day : Integer;
      Hour, Minute, Second : Integer := 0)
      return Long_Long_Integer;

   --  The UTC offset in seconds, east of Greenwich positive, that Rule gives
   --  at the UTC instant Instant (seconds since the epoch). Valid is False,
   --  and 0 returned, when Rule is not a TZ string this can read.
   function Offset_At
     (Rule    : String;
      Instant : Long_Long_Integer;
      Valid   : out Boolean)
      return Integer;

   --  The UTC instants, in Year, at which Rule's daylight saving time starts
   --  and ends. Has_Daylight is False, and both 0, for a rule without
   --  daylight saving time; Valid as above.
   procedure Changes_In
     (Rule         : String;
      Year         : Integer;
      Starts       : out Long_Long_Integer;
      Ends         : out Long_Long_Integer;
      Has_Daylight : out Boolean;
      Valid        : out Boolean);

end I18N.TZ_Rules;
