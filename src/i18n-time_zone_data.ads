--  Time zone offsets, from the tz database as the CLDR generator wrote it to
--  share/i18n/tzdb.i18ndata: for each zone, its offsets until its final rule
--  takes over, and that rule (see I18N.TZ_Rules) for every year after.
--
--  The file is loaded on the first offset asked for, and a zone's record is
--  bisected where it lies; nothing about time zones is compiled into the
--  library beyond the alias table that names a zone's canonical id.
package I18N.Time_Zone_Data is

   --  The UTC offset in seconds, east of Greenwich positive, of Zone at the
   --  given UTC date and time. Valid is False, and 0 returned, for a zone the
   --  data does not know -- or when the data file is not installed.
   function Offset_Seconds_At_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Valid  : out Boolean)
      return Integer;

end I18N.Time_Zone_Data;
