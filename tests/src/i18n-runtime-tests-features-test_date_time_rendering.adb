separate (I18N.Runtime.Tests.Features)
procedure Test_Date_Time_Rendering
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
   Target  : String (1 .. 48) := [others => Character'Val (0)];
   Last    : Natural := 0;
   Status  : I18N.Result.Render_Status;
   Arabic_Full : constant String :=
     U (16#627#) & U (16#644#) & U (16#62E#) & U (16#645#) & U (16#64A#)
     & U (16#633#) & U (16#60C#) & " " & U (16#662#) & U (16#669#) & " "
     & U (16#641#) & U (16#628#) & U (16#631#) & U (16#627#)
     & U (16#64A#) & U (16#631#) & " " & U (16#662#) & U (16#660#)
     & U (16#662#) & U (16#664#) & " " & U (16#660#) & U (16#669#) & ":"
     & U (16#660#) & U (16#665#) & ":" & U (16#660#) & U (16#667#);
begin
   I18N.Runtime.Load_Text
     (Runtime, "base",
      "en.when = ""On {day, date} at {clock, time}""" & ASCII.LF
      & "de.when = ""Am {day, date} um {clock, time}""" & ASCII.LF
      & "en.short = ""{day, date, short} {clock, time, short}"""
      & ASCII.LF
      & "en.short_skeleton_alias = ""{day, date, ::short} {clock, time, ::short}"""
      & ASCII.LF
      & "en.short_named_skeleton_alias = ""{day, date, ::date-short} {clock, time, ::time-short}"""
      & ASCII.LF
      & "en.short_slash_skeleton_alias = ""{day, date, ::date/short} {clock, time, ::time/short}"""
      & ASCII.LF
      & "en.medium = ""{day, date, medium} {clock, time, medium}"""
      & ASCII.LF
      & "en.medium_skeleton_alias = ""{day, date, ::medium} {clock, time, ::medium}"""
      & ASCII.LF
      & "en.medium_named_skeleton_alias = ""{day, date, ::date-medium} {clock, time, ::time-medium}"""
      & ASCII.LF
      & "en.medium_slash_skeleton_alias = ""{day, date, ::date/medium} {clock, time, ::time/medium}"""
      & ASCII.LF
      & "en.long = ""{day, date, long} {clock, time, long}"""
      & ASCII.LF
      & "en.long_skeleton_alias = ""{day, date, ::long} {clock, time, ::long}"""
      & ASCII.LF
      & "en.long_named_skeleton_alias = ""{day, date, ::date-long} {clock, time, ::time-long}"""
      & ASCII.LF
      & "en.long_slash_skeleton_alias = ""{day, date, ::date/long} {clock, time, ::time/long}"""
      & ASCII.LF
      & "en.full = ""{day, date, full} {clock, time, full}"""
      & ASCII.LF
      & "en.full_skeleton_alias = ""{day, date, ::full} {clock, time, ::full}"""
      & ASCII.LF
      & "en.full_named_skeleton_alias = ""{day, date, ::date-full} {clock, time, ::time-full}"""
      & ASCII.LF
      & "en.full_slash_skeleton_alias = ""{day, date, ::date/full} {clock, time, ::time/full}"""
      & ASCII.LF
      & "de.full = ""{day, date, full}""" & ASCII.LF
      & "ar.full = ""{day, date, full} {clock, time, full}"""
      & ASCII.LF
      & "ja.full = ""{day, date, full}""" & ASCII.LF
      & "ja.full_skeleton_alias = ""{day, date, ::full}""" & ASCII.LF
      & "zh.long = ""{day, date, long}""" & ASCII.LF
      & "zh.long_skeleton_alias = ""{day, date, ::long}""" & ASCII.LF
      & "ko.full = ""{day, date, full}""" & ASCII.LF
      & "ko.full_skeleton_alias = ""{day, date, ::full}""" & ASCII.LF
      & "ko.short_time = ""{clock, time, short}""" & ASCII.LF
      & "ko.short_time_alias = ""{clock, time, ::short}""" & ASCII.LF
      & "ko.long_time = ""{clock, time, long}""" & ASCII.LF
      & "ko.long_time_alias = ""{clock, time, ::long}""" & ASCII.LF
      & "cy.month = ""{day, date, ::MMMM}""" & ASCII.LF
      & "haw.weekday = ""{day, date, ::EEEE}""" & ASCII.LF
      & "sr.month = ""{day, date, ::MMMM}""" & ASCII.LF
      & "sr-Latn.month = ""{day, date, ::MMMM}""" & ASCII.LF
      & "zh-Hant.weekday = ""{day, date, ::EEEE}""" & ASCII.LF
      & "en-u-ca-gregory.gregory = ""{day, date, ::yyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-iso8601.iso = ""{day, date, ::yyyyMMdd'|'Y'|'w'|'W}"""
      & ASCII.LF
      & "th-u-ca-buddhist.buddhist = ""{day, date, long}""" & ASCII.LF
      & "ja-u-ca-japanese.japanese = ""{day, date, long}""" & ASCII.LF
      & "ja-u-ca-japanese.taisho = ""{day, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ja-u-ca-japanese.meiji = ""{day, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ja-u-ca-japanese.keio = ""{day, date, ::GyyyyMMdd}""" & ASCII.LF
      & "en-u-ca-julian.julian = ""{day, date, long}""" & ASCII.LF
      & "zh-u-ca-roc.roc = ""{day, date, ::GyyyyMMdd}""" & ASCII.LF
      & "en-u-ca-coptic.coptic = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-coptic.coptic_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en-u-ca-ethiopic.ethiopic = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-ethiopic.ethiopic_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en-u-ca-ethioaa.ethioaa = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-islamic-civil.islamic = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-islamic-civil.islamic_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en-u-ca-islamic.islamic_alias = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-islamicc.islamicc_alias = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-islamic-tbla.islamic_tbla = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-indian.indian = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-indian.indian_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en-u-ca-persian.persian = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-persian.related_year = ""{day, date, ::r'/'yyyy'-'MM'-'dd}"""
      & ASCII.LF
      & "en-u-ca-persian.persian_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en-u-ca-hebrew.hebrew = ""{day, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "en-u-ca-hebrew.related_year = ""{day, date, ::r'/'yyyy'-'MM'-'dd}"""
      & ASCII.LF
      & "en-u-ca-hebrew.hebrew_datetime = ""{instant, datetime, ::GyyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "en.utc_time = ""{instant, time, long, UTC}""" & ASCII.LF
      & "en.utc_lower_time = ""{instant, time, long, utc}""" & ASCII.LF
      & "en.gmt_time = ""{instant, time, long, GMT}""" & ASCII.LF
      & "en.gmt_lower_time = ""{instant, time, long, gmt}""" & ASCII.LF
      & "en.z_lower_time = ""{instant, time, long, z}""" & ASCII.LF
      & "en.offset_hour_time = ""{instant, time, long, +02}"""
      & ASCII.LF
      & "en.offset_compact_time = ""{instant, time, long, +0230}"""
      & ASCII.LF
      & "en.offset_negative_hour_time = ""{instant, time, long, -05}"""
      & ASCII.LF
      & "en.etc_utc_time = ""{instant, time, long, Etc/UTC}"""
      & ASCII.LF
      & "en.etc_gmt_time = ""{instant, time, long, Etc/GMT}"""
      & ASCII.LF
      & "en.ut_time = ""{instant, time, long, UT}""" & ASCII.LF
      & "en.ut_lower_time = ""{instant, time, long, ut}""" & ASCII.LF
      & "en.zulu_time = ""{instant, time, long, Zulu}""" & ASCII.LF
      & "en.berlin_date = ""{instant, date, short, Europe/Berlin}"""
      & ASCII.LF
      & "en.berlin_summer = ""{instant, time, short, Europe/Berlin}"""
      & ASCII.LF
      & "en.new_york = ""{instant, datetime, short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_skeleton_alias = ""{instant, datetime, ::short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_named_skeleton_alias = ""{instant, datetime, ::date-short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_slash_skeleton_alias = ""{instant, datetime, ::date/short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_datetime_named_alias = ""{instant, datetime, ::datetime-short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_datetime_slash_alias = ""{instant, datetime, ::datetime/short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_dateTime_named_alias = ""{instant, datetime, ::dateTime-short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_dateTime_slash_alias = ""{instant, datetime, ::dateTime/short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_medium = ""{instant, datetime, medium, America/New_York}"""
      & ASCII.LF
      & "en.new_york_medium_alias = ""{instant, datetime, ::medium, America/New_York}"""
      & ASCII.LF
      & "en.new_york_medium_named_alias = ""{instant, datetime, ::date-medium, America/New_York}"""
      & ASCII.LF
      & "en.new_york_medium_datetime_alias = ""{instant, datetime, ::datetime-medium, America/New_York}"""
      & ASCII.LF
      & "en.new_york_medium_dateTime_alias = ""{instant, datetime, ::dateTime-medium, America/New_York}"""
      & ASCII.LF
      & "en.new_york_long = ""{instant, datetime, long, America/New_York}"""
      & ASCII.LF
      & "en.new_york_long_alias = ""{instant, datetime, ::long, America/New_York}"""
      & ASCII.LF
      & "en.new_york_long_datetime_alias = ""{instant, datetime, ::datetime/long, America/New_York}"""
      & ASCII.LF
      & "en.new_york_long_dateTime_alias = ""{instant, datetime, ::dateTime/long, America/New_York}"""
      & ASCII.LF
      & "en.new_york_long_named_alias = ""{instant, datetime, ::time-long, America/New_York}"""
      & ASCII.LF
      & "en.new_york_full = ""{instant, datetime, full, America/New_York}"""
      & ASCII.LF
      & "en.new_york_full_alias = ""{instant, datetime, ::full, America/New_York}"""
      & ASCII.LF
      & "en.new_york_full_named_alias = ""{instant, datetime, ::time-full, America/New_York}"""
      & ASCII.LF
      & "en.new_york_full_datetime_alias = ""{instant, datetime, ::datetime-full, America/New_York}"""
      & ASCII.LF
      & "en.new_york_full_dateTime_alias = ""{instant, datetime, ::dateTime-full, America/New_York}"""
      & ASCII.LF
      & "en.new_york_summer = ""{instant, time, short, America/New_York}"""
      & ASCII.LF
      & "en.new_york_offset = ""{instant, datetime, ::yyyyMMddHHmmZ, America/New_York}"""
      & ASCII.LF
      & "en.chatham_winter = ""{instant, datetime, ::yyyyMMddHHmmZ, Pacific/Chatham}"""
      & ASCII.LF
      & "en.chatham_summer = ""{instant, datetime, ::yyyyMMddHHmmZ, Pacific/Chatham}"""
      & ASCII.LF
      & "en.cairo_tzdb = ""{instant, datetime, ::yyyyMMddHHmmZ, Africa/Cairo}"""
      & ASCII.LF
      & "en.st_johns_tzdb = ""{instant, datetime, ::yyyyMMddHHmmZ, America/St_Johns}"""
      & ASCII.LF
      & "en.us_eastern = ""{instant, datetime, short, US/Eastern}"""
      & ASCII.LF
      & "en.us_pacific = ""{instant, time, short, US/Pacific}"""
      & ASCII.LF
      & "en.canada_eastern = ""{instant, time, short, Canada/Eastern}"""
      & ASCII.LF
      & "en.toronto = ""{instant, time, short, America/Toronto}"""
      & ASCII.LF
      & "en.montreal = ""{instant, time, short, America/Montreal}"""
      & ASCII.LF
      & "en.detroit = ""{instant, time, short, America/Detroit}"""
      & ASCII.LF
      & "en.indianapolis = ""{instant, time, short, America/Indiana/Indianapolis}"""
      & ASCII.LF
      & "en.louisville = ""{instant, time, short, America/Kentucky/Louisville}"""
      & ASCII.LF
      & "en.nassau = ""{instant, time, short, America/Nassau}"""
      & ASCII.LF
      & "en.london_winter = ""{instant, time, short, Europe/London}"""
      & ASCII.LF
      & "en.london_summer = ""{instant, time, short, Europe/London}"""
      & ASCII.LF
      & "en.dublin = ""{instant, time, short, Europe/Dublin}"""
      & ASCII.LF
      & "en.lisbon = ""{instant, time, short, Europe/Lisbon}"""
      & ASCII.LF
      & "en.canary = ""{instant, time, short, Atlantic/Canary}"""
      & ASCII.LF
      & "en.moscow = ""{instant, time, short, Europe/Moscow}"""
      & ASCII.LF
      & "en.athens = ""{instant, time, short, Europe/Athens}"""
      & ASCII.LF
      & "en.helsinki = ""{instant, time, short, Europe/Helsinki}"""
      & ASCII.LF
      & "en.bucharest = ""{instant, time, short, Europe/Bucharest}"""
      & ASCII.LF
      & "en.sofia = ""{instant, time, short, Europe/Sofia}"""
      & ASCII.LF
      & "en.vilnius = ""{instant, time, short, Europe/Vilnius}"""
      & ASCII.LF
      & "en.riga = ""{instant, time, short, Europe/Riga}"""
      & ASCII.LF
      & "en.tallinn = ""{instant, time, short, Europe/Tallinn}"""
      & ASCII.LF
      & "en.kyiv = ""{instant, time, short, Europe/Kyiv}"""
      & ASCII.LF
      & "en.paris_winter = ""{instant, time, short, Europe/Paris}"""
      & ASCII.LF
      & "en.zurich_winter = ""{instant, time, short, Europe/Zurich}"""
      & ASCII.LF
      & "en.stockholm_winter = ""{instant, time, short, Europe/Stockholm}"""
      & ASCII.LF
      & "en.warsaw_winter = ""{instant, time, short, Europe/Warsaw}"""
      & ASCII.LF
      & "en.rome_summer = ""{instant, time, short, Europe/Rome}"""
      & ASCII.LF
      & "en.madrid_winter = ""{instant, time, short, Europe/Madrid}"""
      & ASCII.LF
      & "en.amsterdam_summer = ""{instant, time, short, Europe/Amsterdam}"""
      & ASCII.LF
      & "en.zurich_summer = ""{instant, time, short, Europe/Zurich}"""
      & ASCII.LF
      & "en.vienna_summer = ""{instant, time, short, Europe/Vienna}"""
      & ASCII.LF
      & "en.brussels_summer = ""{instant, time, short, Europe/Brussels}"""
      & ASCII.LF
      & "en.copenhagen_summer = ""{instant, time, short, Europe/Copenhagen}"""
      & ASCII.LF
      & "en.stockholm_summer = ""{instant, time, short, Europe/Stockholm}"""
      & ASCII.LF
      & "en.oslo_summer = ""{instant, time, short, Europe/Oslo}"""
      & ASCII.LF
      & "en.warsaw_summer = ""{instant, time, short, Europe/Warsaw}"""
      & ASCII.LF
      & "en.prague_summer = ""{instant, time, short, Europe/Prague}"""
      & ASCII.LF
      & "en.budapest_summer = ""{instant, time, short, Europe/Budapest}"""
      & ASCII.LF
      & "en.bratislava = ""{instant, time, short, Europe/Bratislava}"""
      & ASCII.LF
      & "en.luxembourg = ""{instant, time, short, Europe/Luxembourg}"""
      & ASCII.LF
      & "en.monaco = ""{instant, time, short, Europe/Monaco}"""
      & ASCII.LF
      & "en.andorra = ""{instant, time, short, Europe/Andorra}"""
      & ASCII.LF
      & "en.malta = ""{instant, time, short, Europe/Malta}"""
      & ASCII.LF
      & "en.san_marino = ""{instant, time, short, Europe/San_Marino}"""
      & ASCII.LF
      & "en.vatican = ""{instant, time, short, Europe/Vatican}"""
      & ASCII.LF
      & "en.belgrade = ""{instant, time, short, Europe/Belgrade}"""
      & ASCII.LF
      & "en.zagreb = ""{instant, time, short, Europe/Zagreb}"""
      & ASCII.LF
      & "en.ljubljana = ""{instant, time, short, Europe/Ljubljana}"""
      & ASCII.LF
      & "en.sarajevo = ""{instant, time, short, Europe/Sarajevo}"""
      & ASCII.LF
      & "en.skopje = ""{instant, time, short, Europe/Skopje}"""
      & ASCII.LF
      & "en.podgorica = ""{instant, time, short, Europe/Podgorica}"""
      & ASCII.LF
      & "en.tirane = ""{instant, time, short, Europe/Tirane}"""
      & ASCII.LF
      & "en.chisinau = ""{instant, time, short, Europe/Chisinau}"""
      & ASCII.LF
      & "en.nicosia = ""{instant, time, short, Asia/Nicosia}"""
      & ASCII.LF
      & "en.los_angeles_summer = ""{instant, time, short, America/Los_Angeles}"""
      & ASCII.LF
      & "en.vancouver = ""{instant, time, short, America/Vancouver}"""
      & ASCII.LF
      & "en.tijuana = ""{instant, time, short, America/Tijuana}"""
      & ASCII.LF
      & "en.chicago_winter = ""{instant, time, short, America/Chicago}"""
      & ASCII.LF
      & "en.winnipeg = ""{instant, time, short, America/Winnipeg}"""
      & ASCII.LF
      & "en.denver_summer = ""{instant, time, short, America/Denver}"""
      & ASCII.LF
      & "en.boise = ""{instant, time, short, America/Boise}"""
      & ASCII.LF
      & "en.edmonton = ""{instant, time, short, America/Edmonton}"""
      & ASCII.LF
      & "en.phoenix = ""{instant, time, short, America/Phoenix}"""
      & ASCII.LF
      & "en.mexico_city = ""{instant, time, short, America/Mexico_City}"""
      & ASCII.LF
      & "en.bogota = ""{instant, time, short, America/Bogota}"""
      & ASCII.LF
      & "en.lima = ""{instant, time, short, America/Lima}"""
      & ASCII.LF
      & "en.johannesburg = ""{instant, time, short, Africa/Johannesburg}"""
      & ASCII.LF
      & "en.accra = ""{instant, time, short, Africa/Accra}"""
      & ASCII.LF
      & "en.abidjan = ""{instant, time, short, Africa/Abidjan}"""
      & ASCII.LF
      & "en.algiers = ""{instant, time, short, Africa/Algiers}"""
      & ASCII.LF
      & "en.tunis = ""{instant, time, short, Africa/Tunis}"""
      & ASCII.LF
      & "en.nairobi = ""{instant, time, short, Africa/Nairobi}"""
      & ASCII.LF
      & "en.lagos = ""{instant, time, short, Africa/Lagos}"""
      & ASCII.LF
      & "en.dubai = ""{instant, time, short, Asia/Dubai}"""
      & ASCII.LF
      & "en.yerevan = ""{instant, time, short, Asia/Yerevan}"""
      & ASCII.LF
      & "en.tbilisi = ""{instant, time, short, Asia/Tbilisi}"""
      & ASCII.LF
      & "en.baku = ""{instant, time, short, Asia/Baku}"""
      & ASCII.LF
      & "en.riyadh = ""{instant, time, short, Asia/Riyadh}"""
      & ASCII.LF
      & "en.jerusalem = ""{instant, time, short, Asia/Jerusalem}"""
      & ASCII.LF
      & "en.tehran = ""{instant, time, short, Asia/Tehran}"""
      & ASCII.LF
      & "en.shanghai = ""{instant, time, short, Asia/Shanghai}"""
      & ASCII.LF
      & "en.singapore = ""{instant, time, short, Asia/Singapore}"""
      & ASCII.LF
      & "en.hong_kong = ""{instant, time, short, Asia/Hong_Kong}"""
      & ASCII.LF
      & "en.taipei = ""{instant, time, short, Asia/Taipei}"""
      & ASCII.LF
      & "en.kuala_lumpur = ""{instant, time, short, Asia/Kuala_Lumpur}"""
      & ASCII.LF
      & "en.istanbul = ""{instant, time, short, Europe/Istanbul}"""
      & ASCII.LF
      & "en.seoul = ""{instant, time, short, Asia/Seoul}"""
      & ASCII.LF
      & "en.ulaanbaatar = ""{instant, time, short, Asia/Ulaanbaatar}"""
      & ASCII.LF
      & "en.bangkok = ""{instant, time, short, Asia/Bangkok}"""
      & ASCII.LF
      & "en.jakarta = ""{instant, time, short, Asia/Jakarta}"""
      & ASCII.LF
      & "en.ho_chi_minh = ""{instant, time, short, Asia/Ho_Chi_Minh}"""
      & ASCII.LF
      & "en.karachi = ""{instant, time, short, Asia/Karachi}"""
      & ASCII.LF
      & "en.colombo = ""{instant, time, short, Asia/Colombo}"""
      & ASCII.LF
      & "en.dhaka = ""{instant, time, short, Asia/Dhaka}"""
      & ASCII.LF
      & "en.yangon = ""{instant, time, short, Asia/Yangon}"""
      & ASCII.LF
      & "en.tashkent = ""{instant, time, short, Asia/Tashkent}"""
      & ASCII.LF
      & "en.kathmandu = ""{instant, time, short, Asia/Kathmandu}"""
      & ASCII.LF
      & "en.manila = ""{instant, time, short, Asia/Manila}"""
      & ASCII.LF
      & "en.honolulu = ""{instant, time, short, Pacific/Honolulu}"""
      & ASCII.LF
      & "en.auckland = ""{instant, time, short, Pacific/Auckland}"""
      & ASCII.LF
      & "en.sydney = ""{instant, time, short, Australia/Sydney}"""
      & ASCII.LF
      & "en.melbourne = ""{instant, time, short, Australia/Melbourne}"""
      & ASCII.LF
      & "en.hobart = ""{instant, time, short, Australia/Hobart}"""
      & ASCII.LF
      & "en.adelaide = ""{instant, time, short, Australia/Adelaide}"""
      & ASCII.LF
      & "en.brisbane = ""{instant, time, short, Australia/Brisbane}"""
      & ASCII.LF
      & "en.perth = ""{instant, time, short, Australia/Perth}"""
      & ASCII.LF
      & "en.darwin = ""{instant, time, short, Australia/Darwin}"""
      & ASCII.LF
      & "en.sao_paulo = ""{instant, time, short, America/Sao_Paulo}"""
      & ASCII.LF
      & "en.buenos_aires = ""{instant, time, short, America/Argentina/Buenos_Aires}"""
      & ASCII.LF
      & "en.date_skeleton = ""{day, date, ::yMMMd}""" & ASCII.LF
      & "en.date_literal = ""{day, date, ::yyyy'-'MM'-'dd}"""
      & ASCII.LF
      & "en.date_comma_literal = ""{day, date, ::yyyy','MM}"""
      & ASCII.LF
      & "en.date_brace_literal = ""{day, date, ::yyyy'{'MM'}'dd}"""
      & ASCII.LF
      & "en.year_widths = ""{day, date, ::y'/'yy'/'yyyy'/'yyyyy}"""
      & ASCII.LF
      & "en.year_alias_fields = ""{day, date, ::u'/'U'/'r}"""
      & ASCII.LF
      & "en.standalone_month_fields = ""{day, date, ::L'/'LL'/'LLL'/'LLLL'/'l}"""
      & ASCII.LF
      & "en.modified_julian_day = ""{day, date, ::g}""" & ASCII.LF
      & "en.week_year = ""{day, date, ::Y'/'w'/'W'/'yyyy}"""
      & ASCII.LF
      & "de.week_year = ""{day, date, ::Y'/'w'/'W'/'yyyy}"""
      & ASCII.LF
      & "de.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "cs.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "ro.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "lt.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "sl.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "ja.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "zh.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "ko.date_skeleton = ""{day, date, ::EdMMMy}""" & ASCII.LF
      & "de.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "fr.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "es.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "it.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "pt.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "nl.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "ro.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "lt.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "sl.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "pl.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "cs.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "ru.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "ar.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "ja.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "zh.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "ko.era = ""{day, date, ::Gy}""" & ASCII.LF
      & "de.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "fr.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "es.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "it.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "pt.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "nl.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "ro.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "lt.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "sl.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "pl.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "cs.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "ru.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "ar.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "ja.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "zh.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "ko.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "bg.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "uk.quarter = ""{day, date, ::QQQQ}""" & ASCII.LF
      & "en.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "en.narrow_quarter = ""{day, date, ::QQQQQ}""" & ASCII.LF
      & "fr.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "ro.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "cs.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "ru.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "ar.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "zh.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "ko.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "hi.short_quarter = ""{day, date, ::QQQ}""" & ASCII.LF
      & "en.weekday_numeric = ""{day, date, ::e'/'ee'/'c'/'cc'/'eee'/'cccc}"""
      & ASCII.LF
      & "en.weekday_widths = ""{day, date, ::EEE'/'EEEE'/'EEEEE'/'EEEEEE'/'cccccc}"""
      & ASCII.LF
      & "de.weekday_numeric = ""{day, date, ::e'/'ee'/'eee'/'cccc}"""
      & ASCII.LF
      & "cs.narrow_names = ""{day, date, ::MMMMM'/'ccccc}"""
      & ASCII.LF
      & "en.time_skeleton = ""{clock, time, ::hhmmssa}""" & ASCII.LF
      & "en.preferred_hour = ""{clock, time, ::jmm}""" & ASCII.LF
      & "en.preferred_hour_explicit = ""{clock, time, ::jmma}"""
      & ASCII.LF
      & "en.preferred_hour_no_period = ""{clock, time, ::Jmm}"""
      & ASCII.LF
      & "en.preferred_hour_flexible = ""{clock, time, ::Cmm}"""
      & ASCII.LF
      & "de.preferred_hour = ""{clock, time, ::jmm}""" & ASCII.LF
      & "de.preferred_hour_no_period = ""{clock, time, ::Jmm}"""
      & ASCII.LF
      & "de.preferred_hour_flexible = ""{clock, time, ::Cmm}"""
      & ASCII.LF
      & "ko.preferred_hour = ""{clock, time, ::jmm}""" & ASCII.LF
      & "ko.preferred_hour_no_period = ""{clock, time, ::Jmm}"""
      & ASCII.LF
      & "ko.preferred_hour_flexible = ""{clock, time, ::Cmm}"""
      & ASCII.LF
      & "th.time_skeleton = ""{clock, time, ::hhmmssa}""" & ASCII.LF
      & "uk.time_skeleton = ""{clock, time, ::hhmmssa}"""
      & ASCII.LF
      & "en.fractional_fields = ""{clock, time, ::ss'.'SSS'|'nnn'|'N'|'A}"""
      & ASCII.LF
      & "de.period_midnight = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "de.period_midnight_narrow = ""{clock, time, ::BBBBB}"""
      & ASCII.LF
      & "en.period_midnight_narrow = ""{clock, time, ::BBBBB}"""
      & ASCII.LF
      & "fr.period_noon = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "es.period_am = ""{clock, time, ::aaa}""" & ASCII.LF
      & "it.period_noon = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "pt.period_midnight = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "nl.period_pm = ""{clock, time, ::aaa}""" & ASCII.LF
      & "ro.period_midnight = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "lt.period_noon = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "sl.period_pm = ""{clock, time, ::aaa}""" & ASCII.LF
      & "pl.period_midnight = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "cs.period_noon = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "ru.period_midnight = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "de.period_morning = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "fr.period_afternoon = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "de.period_evening = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "de.period_night = ""{clock, time, ::BBBB}""" & ASCII.LF
      & "ar.period_pm = ""{clock, time, ::aaa}""" & ASCII.LF
      & "ja.period_am = ""{clock, time, ::aaa}""" & ASCII.LF
      & "zh.period_am = ""{clock, time, ::aaa}""" & ASCII.LF
      & "ko.period_am = ""{clock, time, ::aaa}""" & ASCII.LF
      & "en.time_literal = ""{clock, time, ::HH':'mm':'ss' o''clock'}"""
      & ASCII.LF
      & "en.zone_skeleton = ""{instant, time, ::HHmmz, UTC}""" & ASCII.LF
      & "en.zone_widths = ""{instant, datetime, ::OOOO'|'ZZZZZ'|'xxxxx'|'VV, America/New_York}"""
      & ASCII.LF
      & "fr.zone_widths = ""{instant, datetime, ::OOOO'|'ZZZZZ'|'xxxxx'|'VV, America/New_York}"""
      & ASCII.LF
      & "en.zone_seconds_widths = ""{instant, datetime, ::ZZZZZ'|'xxxxx, +02:00:30}"""
      & ASCII.LF
      & "en.zone_v_widths = ""{instant, datetime, ::V'|'VV'|'VVV'|'VVVV, America/New_York}"""
      & ASCII.LF
      & "fr.zone_v_widths = ""{instant, datetime, ::V'|'VV'|'VVV'|'VVVV, America/New_York}"""
      & ASCII.LF
      & "en.utc_v_widths = ""{instant, datetime, ::V'|'VV'|'VVV'|'VVVV, UTC}"""
      & ASCII.LF
      & "en.zone_short_gmt = ""{instant, datetime, ::O, America/New_York}"""
      & ASCII.LF
      & "en.kathmandu_short_gmt = ""{instant, datetime, ::O, Asia/Kathmandu}"""
      & ASCII.LF
      & "da.kathmandu_short_gmt = ""{instant, datetime, ::O, Asia/Kathmandu}"""
      & ASCII.LF
      & "fi.kathmandu_short_gmt = ""{instant, datetime, ::O, Asia/Kathmandu}"""
      & ASCII.LF
      & "en.utc_short_gmt = ""{instant, datetime, ::O, UTC}"""
      & ASCII.LF
      & "en.zone_names = ""{instant, datetime, ::z'|'v'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "en.zone_long_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "fr.zone_long_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "en.berlin_zone_names = ""{instant, datetime, ::z'|'v'|'vvvv'|'VV, Europe/Berlin}"""
      & ASCII.LF
      & "de.berlin_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Europe/Berlin}"""
      & ASCII.LF
      & "de.berlin_short_zone_names = ""{instant, datetime, ::z'|'v'|'VV, Europe/Berlin}"""
      & ASCII.LF
      & "de-AT.berlin_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Europe/Berlin}"""
      & ASCII.LF
      & "en-AU.lord_howe_short_names = ""{instant, datetime, ::z'|'v'|'vvvv'|'VV, Australia/Lord_Howe}"""
      & ASCII.LF
      & "de.lord_howe_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Australia/Lord_Howe}"""
      & ASCII.LF
      & "de.brisbane_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Australia/Brisbane}"""
      & ASCII.LF
      & "de.darwin_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Australia/Darwin}"""
      & ASCII.LF
      & "de.perth_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Australia/Perth}"""
      & ASCII.LF
      & "de.eucla_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Australia/Eucla}"""
      & ASCII.LF
      & "ru.zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "ar.zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "ja.zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "zh.zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "ko.zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/New_York}"""
      & ASCII.LF
      & "en.tokyo_short_generic = ""{instant, datetime, ::v'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "de.tokyo_location_names = ""{instant, datetime, ::VVV'|'VVVV, Asia/Tokyo}"""
      & ASCII.LF
      & "de.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "de-AT.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "de.dubai_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Dubai}"""
      & ASCII.LF
      & "de.kolkata_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Kolkata}"""
      & ASCII.LF
      & "de.kathmandu_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Kathmandu}"""
      & ASCII.LF
      & "de.bogota_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, America/Bogota}"""
      & ASCII.LF
      & "de.nairobi_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Africa/Nairobi}"""
      & ASCII.LF
      & "de.manila_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Manila}"""
      & ASCII.LF
      & "de.yangon_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Yangon}"""
      & ASCII.LF
      & "de.honolulu_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Pacific/Honolulu}"""
      & ASCII.LF
      & "ru.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "ar.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "ja.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "zh.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "ko.tokyo_zone_names = ""{instant, datetime, ::zzzz'|'vvvv'|'VV, Asia/Tokyo}"""
      & ASCII.LF
      & "en.utc_zone_widths = ""{instant, datetime, ::ZZZZZ'|'xxxxx'|'VV, UTC}"""
      & ASCII.LF
      & "fr.utc_long_zone = ""{instant, datetime, ::zzzz, Etc/UTC}"""
      & ASCII.LF
      & "en.full_skeleton = ""{instant, datetime, ::GyyyyQQQDDDwWFEBhmsSAZ, +02:00}"""
      & ASCII.LF
      & "en.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en-u-nu-deva.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en-u-nu-beng.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "bn.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en.datetime_fraction = ""{instant, datetime, ::HH':'mm':'ss'.'SSS'|'N, UTC}"""
      & ASCII.LF
      & "en.datetime_comma_literal_zone = ""{instant, datetime, ::yyyy','MM, UTC}"""
      & ASCII.LF
      & "en.datetime_literal = ""{instant, datetime, ::yyyy'-'MM'-'dd'T'HH':'mm':'ssXXX, UTC}"""
      & ASCII.LF
      & "ar.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "ar-u-nu-latn.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "ar-u-nu-deva.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en-u-nu-arab.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en-u-nu-arabext.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en-u-nu-thai.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "fa.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "th.datetime_skeleton = ""{instant, datetime, ::yMdHHmmss, UTC}"""
      & ASCII.LF
      & "en.bad_zone = ""{instant, time, long, Mars/Base}""" & ASCII.LF,
      Result);
   Assert (Result.Status = I18N.Runtime.Loaded,
           "date/time catalog should load");

   I18N.Arguments.Set (Args, "day", "2024-02-29");
   I18N.Arguments.Set (Args, "clock", "09:05:07");
   Assert (Rendered (Runtime, "en", "when", Args) =
             "On 2024-02-29 at 09:05:07",
           "English date/time uses ISO date and 24-hour time");
   Assert (Rendered (Runtime, "de", "when", Args) =
             "Am 29.02.2024 um 09:05:07",
           "German date uses day-month-year output");
   Assert (Rendered (Runtime, "en", "short", Args) = "2/29/24 09:05",
           "short date/time styles render deterministically");
   Assert (Rendered (Runtime, "en", "short_skeleton_alias", Args) =
             Rendered (Runtime, "en", "short", Args),
           "short skeleton style aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "short_named_skeleton_alias", Args) =
             Rendered (Runtime, "en", "short", Args),
           "date-short/time-short skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "short_slash_skeleton_alias", Args) =
             Rendered (Runtime, "en", "short", Args),
           "date/short/time/short skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "medium_skeleton_alias", Args) =
             Rendered (Runtime, "en", "medium", Args),
           "medium skeleton style aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "medium_named_skeleton_alias", Args) =
             Rendered (Runtime, "en", "medium", Args),
           "date-medium/time-medium skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "medium_slash_skeleton_alias", Args) =
             Rendered (Runtime, "en", "medium", Args),
           "date/medium/time/medium skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "long", Args) =
             "February 29, 2024 09:05:07",
           "long date/time styles render deterministically");
   Assert (Rendered (Runtime, "en", "long_skeleton_alias", Args) =
             Rendered (Runtime, "en", "long", Args),
           "long skeleton style aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "long_named_skeleton_alias", Args) =
             Rendered (Runtime, "en", "long", Args),
           "date-long/time-long skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "long_slash_skeleton_alias", Args) =
             Rendered (Runtime, "en", "long", Args),
           "date/long/time/long skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "full_skeleton_alias", Args) =
             Rendered (Runtime, "en", "full", Args),
           "full skeleton style aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "full_named_skeleton_alias", Args) =
             Rendered (Runtime, "en", "full", Args),
           "date-full/time-full skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "en", "full_slash_skeleton_alias", Args) =
             Rendered (Runtime, "en", "full", Args),
           "date/full/time/full skeleton aliases match date/time styles");
   Assert (Rendered (Runtime, "de", "full", Args) =
             "Donnerstag, 29. Februar 2024",
           "full date style includes localized weekday and month names");
   Assert (Rendered (Runtime, "ar", "full", Args) = Arabic_Full,
           "Arabic full date/time localizes names and digits");
   Assert (Rendered (Runtime, "ja", "full", Args) =
             "2024" & U (16#5E74#) & "2" & U (16#6708#)
             & "29" & U (16#65E5#) & U (16#6728#)
             & U (16#66DC#) & U (16#65E5#),
           "Japanese full date style uses year-month-day order");
   Assert (Rendered (Runtime, "ja", "full_skeleton_alias", Args) =
             Rendered (Runtime, "ja", "full", Args),
           "Japanese full skeleton style alias keeps year-month-day order");
   Assert (Rendered (Runtime, "zh", "long", Args) =
             "2024" & U (16#5E74#) & "2" & U (16#6708#)
             & "29" & U (16#65E5#),
           "Chinese long date style uses year-month-day order");
   Assert (Rendered (Runtime, "zh", "long_skeleton_alias", Args) =
             Rendered (Runtime, "zh", "long", Args),
           "Chinese long skeleton style alias keeps year-month-day order");
   Assert (Rendered (Runtime, "ko", "full", Args) =
             "2024" & U (16#B144#) & " 2" & U (16#C6D4#)
             & " 29" & U (16#C77C#) & " " & U (16#BAA9#)
             & U (16#C694#) & U (16#C77C#),
           "Korean full date style uses year-month-day order");
   Assert (Rendered (Runtime, "ko", "full_skeleton_alias", Args) =
             Rendered (Runtime, "ko", "full", Args),
           "Korean full skeleton style alias keeps year-month-day order");
   Assert (Rendered (Runtime, "ko", "short_time", Args) =
             U (16#C624#) & U (16#C804#) & " 9:05",
           "Korean short time style uses localized 12-hour output");
   Assert (Rendered (Runtime, "ko", "short_time_alias", Args) =
             Rendered (Runtime, "ko", "short_time", Args),
           "Korean short skeleton style alias keeps 12-hour output");
   Assert (Rendered (Runtime, "ko", "long_time", Args) =
             U (16#C624#) & U (16#C804#) & " 9:05:07",
           "Korean long time style uses localized 12-hour output");
   Assert (Rendered (Runtime, "ko", "long_time_alias", Args) =
             Rendered (Runtime, "ko", "long_time", Args),
           "Korean long skeleton style alias keeps 12-hour output");
   Assert (Rendered (Runtime, "cy", "month", Args) = "Chwefror",
           "all-locale CLDR date names include Welsh month names");
   Assert (Rendered (Runtime, "haw", "weekday", Args) =
             "Po" & U (16#2BB#) & "ah" & U (16#101#),
           "all-locale CLDR date names include Hawaiian weekday names");
   Assert (Rendered (Runtime, "sr", "month", Args) =
             U (16#444#) & U (16#435#) & U (16#431#)
             & U (16#440#) & U (16#443#) & U (16#430#)
             & U (16#440#),
           "all-locale CLDR date names include Serbian Cyrillic month names");
   Assert (Rendered (Runtime, "sr-Latn", "month", Args) =
             "februar",
           "all-locale CLDR date names prefer exact script locale rows");
   Assert (Rendered (Runtime, "zh-Hant-HK", "weekday", Args) =
             U (16#661F#) & U (16#671F#) & U (16#56DB#),
           "all-locale CLDR date names fall back through script locale rows");
   Assert (Rendered (Runtime, "en-u-ca-gregory", "gregory", Args) =
             "2024 02 29",
           "gregory calendar extension keeps Gregorian date conversion");
   I18N.Arguments.Set (Args, "day", "2021-01-01");
   Assert (Rendered (Runtime, "en-u-ca-iso8601", "iso", Args) =
             "2021 01 01|2020|53|0",
           "iso8601 calendar extension uses ISO week data");
   I18N.Arguments.Set (Args, "day", "2024-02-29");
   Assert (Rendered (Runtime, "th-u-ca-buddhist", "buddhist", Args) =
             --  CLDR th buddhist long is "d MMMM y" -- no point after the
             --  day, and no era (the gregorian pattern has one, buddhist
             --  does not).
             U (16#E52#) & U (16#E59#) & " "
             & U (16#E01#) & U (16#E38#) & U (16#E21#)
             & U (16#E20#) & U (16#E32#) & U (16#E1E#)
             & U (16#E31#) & U (16#E19#) & U (16#E18#)
             & U (16#E4C#) & " "
             & U (16#E52#) & U (16#E55#) & U (16#E56#) & U (16#E57#),
           "Buddhist calendar year is formatted from locale extension");
   Assert (Rendered (Runtime, "ja-u-ca-japanese", "japanese", Args) =
             U (16#4EE4#) & U (16#548C#) & " 6" & U (16#5E74#)
             & "2" & U (16#6708#) & "29" & U (16#65E5#),
           "Japanese calendar era year localizes era names for ja locale");
   I18N.Arguments.Set (Args, "day", "1912-07-30");
   Assert (Rendered (Runtime, "ja-u-ca-japanese", "taisho", Args) =
             U (16#5927#) & U (16#6B63#) & " 0001 07 30",
           "Japanese calendar renders Taisho era boundary dates");
   I18N.Arguments.Set (Args, "day", "1873-01-01");
   Assert (Rendered (Runtime, "ja-u-ca-japanese", "meiji", Args) =
             U (16#660E#) & U (16#6CBB#) & " 0006 01 01",
           "Japanese calendar renders Meiji era years");
   I18N.Arguments.Set (Args, "day", "1868-09-07");
   Assert (Rendered (Runtime, "ja-u-ca-japanese", "keio", Args) =
             U (16#6176#) & U (16#5FDC#) & " 0004 09 07",
           "Japanese calendar renders Keio era years before Meiji");
   I18N.Arguments.Set (Args, "day", "1865-05-01");
   Assert (Rendered (Runtime, "ja-u-ca-japanese", "keio", Args) =
             U (16#6176#) & U (16#5FDC#) & " 0001 05 01",
           "Japanese calendar renders the Keio era boundary");
   I18N.Arguments.Set (Args, "day", "2024-02-29");
   Assert (Rendered (Runtime, "en-u-ca-julian", "julian", Args) =
             "February 16, 2024",
           "Julian calendar date is converted from Gregorian input");
   Assert (Rendered (Runtime, "zh-u-ca-roc", "roc", Args) =
             UTF8 ([16#6C11#, 16#570B#]) & " 0113 02 29",
           "ROC calendar year and era render from locale extension");
   I18N.Arguments.Set (Args, "day", "2024-09-11");
   Assert (Rendered (Runtime, "en-u-ca-coptic", "coptic", Args) =
             "A.M. 1741 01 01",
           "Coptic calendar date is converted from Gregorian input");
   I18N.Arguments.Set (Args, "instant", "2024-09-11T00:00:00Z");
   Assert (Rendered (Runtime, "en-u-ca-coptic", "coptic_datetime", Args) =
             "A.M. 1741 01 01 00:00",
           "Coptic calendar conversion applies to datetime skeletons");
   Assert (Rendered (Runtime, "en-u-ca-ethiopic", "ethiopic", Args) =
             "A.M. 2017 01 01",
           "Ethiopic calendar date is converted from Gregorian input");
   Assert
     (Rendered (Runtime, "en-u-ca-ethiopic", "ethiopic_datetime", Args) =
      "A.M. 2017 01 01 00:00",
      "Ethiopic calendar conversion applies to datetime skeletons");
   Assert (Rendered (Runtime, "en-u-ca-ethioaa", "ethioaa", Args) =
             "A.A. 7517 01 01",
           "Ethiopic Amete Alem calendar shifts the Ethiopic era year");
   I18N.Arguments.Set (Args, "day", "2024-03-11");
   Assert (Rendered (Runtime, "en-u-ca-islamic-civil", "islamic", Args) =
             "AH 1445 09 01",
           "Islamic civil calendar date is converted from Gregorian input");
   I18N.Arguments.Set (Args, "instant", "2024-03-11T00:00:00Z");
   Assert
     (Rendered
        (Runtime, "en-u-ca-islamic-civil", "islamic_datetime", Args) =
      "AH 1445 09 01 00:00",
      "Islamic civil calendar conversion applies to datetime skeletons");
   I18N.Arguments.Set (Args, "day", "2024-03-11");
   Assert (Rendered (Runtime, "en-u-ca-islamic", "islamic_alias", Args) =
             "AH 1445 09 01",
           "islamic calendar alias maps to deterministic civil conversion");
   Assert (Rendered (Runtime, "en-u-ca-islamicc", "islamicc_alias", Args) =
             "AH 1445 09 01",
           "islamicc calendar alias maps to deterministic civil conversion");
   Assert
     (Rendered (Runtime, "en-u-ca-islamic-tbla", "islamic_tbla", Args) =
        "AH 1445 09 02",
      "islamic-tbla calendar uses tabular astronomical epoch");
   I18N.Arguments.Set (Args, "day", "2024-03-21");
   Assert (Rendered (Runtime, "en-u-ca-indian", "indian", Args) =
             "Saka 1946 01 01",
           "Indian national calendar date is converted from Gregorian input");
   I18N.Arguments.Set (Args, "instant", "2024-03-21T00:00:00Z");
   Assert
     (Rendered (Runtime, "en-u-ca-indian", "indian_datetime", Args) =
      "Saka 1946 01 01 00:00",
      "Indian national calendar conversion applies to datetime skeletons");
   I18N.Arguments.Set (Args, "day", "2024-03-20");
   Assert (Rendered (Runtime, "en-u-ca-persian", "persian", Args) =
             "AP 1403 01 01",
           "Persian calendar date is converted from Gregorian input");
   Assert (Rendered (Runtime, "en-u-ca-persian", "related_year", Args) =
             "2024/1403-01-01",
           "related Gregorian year stays separate from Persian calendar year");
   I18N.Arguments.Set (Args, "instant", "2024-03-20T00:00:00Z");
   Assert
     (Rendered (Runtime, "en-u-ca-persian", "persian_datetime", Args) =
      "AP 1403 01 01 00:00",
      "Persian calendar conversion applies to datetime skeletons");
   I18N.Arguments.Set (Args, "day", "2023-09-16");
   Assert (Rendered (Runtime, "en-u-ca-hebrew", "hebrew", Args) =
             "AM 5784 01 01",
           "Hebrew calendar date is converted from Gregorian input");
   I18N.Arguments.Set (Args, "day", "2024-02-29");
   Assert (Rendered (Runtime, "en-u-ca-hebrew", "hebrew", Args) =
             "AM 5784 06 20",
           "Hebrew leap-year Adar I dates render deterministically");
   Assert (Rendered (Runtime, "en-u-ca-hebrew", "related_year", Args) =
             "2024/5784-06-20",
           "related Gregorian year stays separate from Hebrew calendar year");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T00:00:00Z");
   Assert
     (Rendered (Runtime, "en-u-ca-hebrew", "hebrew_datetime", Args) =
      "AM 5784 06 20 00:00",
      "Hebrew calendar conversion applies to datetime skeletons");

   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00+02:00");
   Assert (Rendered (Runtime, "en", "utc_time", Args) = "21:30:00",
           "time format converts offset instant to UTC");
   Assert (Rendered (Runtime, "en", "utc_lower_time", Args) = "21:30:00",
           "time format accepts lowercase utc as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "gmt_time", Args) = "21:30:00",
           "time format accepts GMT as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "gmt_lower_time", Args) = "21:30:00",
           "time format accepts lowercase gmt as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "z_lower_time", Args) = "21:30:00",
           "time format accepts lowercase z as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "offset_hour_time", Args) =
             "23:30:00",
           "time format accepts compact +HH target-zone offsets");
   Assert (Rendered (Runtime, "en", "offset_compact_time", Args) =
             "00:00:00",
           "time format accepts compact +HHMM target-zone offsets");
   Assert (Rendered (Runtime, "en", "offset_negative_hour_time", Args) =
             "16:30:00",
           "time format accepts compact -HH target-zone offsets");
   Assert (Rendered (Runtime, "en", "etc_utc_time", Args) = "21:30:00",
           "time format accepts Etc/UTC as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "etc_gmt_time", Args) = "21:30:00",
           "time format accepts Etc/GMT as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "ut_time", Args) = "21:30:00",
           "time format accepts UT as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "ut_lower_time", Args) = "21:30:00",
           "time format accepts lowercase ut as a UTC target-zone alias");
   Assert (Rendered (Runtime, "en", "zulu_time", Args) = "21:30:00",
           "time format accepts Zulu as a UTC target-zone alias");

   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00+02");
   Assert (Rendered (Runtime, "en", "utc_time", Args) = "21:30:00",
           "time format accepts compact +HH instant offsets");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00+0230");
   Assert (Rendered (Runtime, "en", "utc_time", Args) = "21:00:00",
           "time format accepts compact +HHMM instant offsets");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00-05");
   Assert (Rendered (Runtime, "en", "utc_time", Args) = "04:30:00",
           "time format accepts compact -HH instant offsets");

   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00Z");
   Assert (Rendered (Runtime, "en", "berlin_date", Args) = "3/1/24",
           "date format converts instant into configured zone date");
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "berlin_summer", Args) = "14:00",
           "Berlin named zone applies deterministic summer time");
   I18N.Arguments.Set (Args, "instant", "2024-03-31T00:59:00Z");
   Assert (Rendered (Runtime, "en", "berlin_summer", Args) = "01:59",
           "Berlin DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-03-31T01:00:00Z");
   Assert (Rendered (Runtime, "en", "berlin_summer", Args) = "03:00",
           "Berlin DST boundary applies summer offset at spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-27T00:59:00Z");
   Assert (Rendered (Runtime, "en", "berlin_summer", Args) = "02:59",
           "Berlin DST boundary keeps summer offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-27T01:00:00Z");
   Assert (Rendered (Runtime, "en", "berlin_summer", Args) = "02:00",
           "Berlin DST boundary restores standard offset at autumn transition");

   I18N.Arguments.Set (Args, "instant", "2024-03-01T02:30:00Z");
   Assert (Rendered (Runtime, "en", "new_york", Args) = "2/29/24 21:30",
           "datetime format converts instant into configured zone");
   Assert (Rendered (Runtime, "en", "us_eastern", Args) =
             Rendered (Runtime, "en", "new_york", Args),
           "US/Eastern aliases America/New_York");
   Assert (Rendered (Runtime, "en", "new_york_skeleton_alias", Args) =
             Rendered (Runtime, "en", "new_york", Args),
           "datetime skeleton style aliases preserve zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_named_skeleton_alias", Args) =
             Rendered (Runtime, "en", "new_york", Args),
           "datetime date-short skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_slash_skeleton_alias", Args) =
             Rendered (Runtime, "en", "new_york", Args),
           "datetime date/short skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_datetime_named_alias", Args) =
        Rendered (Runtime, "en", "new_york", Args),
      "datetime-short skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_datetime_slash_alias", Args) =
        Rendered (Runtime, "en", "new_york", Args),
      "datetime/short skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_dateTime_named_alias", Args) =
        Rendered (Runtime, "en", "new_york", Args),
      "dateTime-short skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_dateTime_slash_alias", Args) =
        Rendered (Runtime, "en", "new_york", Args),
      "dateTime/short skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_medium_alias", Args) =
             Rendered (Runtime, "en", "new_york_medium", Args),
           "datetime medium skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_medium_named_alias", Args) =
             Rendered (Runtime, "en", "new_york_medium", Args),
           "datetime date-medium skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_medium_datetime_alias", Args) =
        Rendered (Runtime, "en", "new_york_medium", Args),
      "datetime-medium skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_medium_dateTime_alias", Args) =
        Rendered (Runtime, "en", "new_york_medium", Args),
      "dateTime-medium skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_long_alias", Args) =
             Rendered (Runtime, "en", "new_york_long", Args),
           "datetime long skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_long_named_alias", Args) =
             Rendered (Runtime, "en", "new_york_long", Args),
           "datetime time-long skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_long_datetime_alias", Args) =
        Rendered (Runtime, "en", "new_york_long", Args),
      "datetime/long skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_long_dateTime_alias", Args) =
        Rendered (Runtime, "en", "new_york_long", Args),
      "dateTime/long skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_full_alias", Args) =
             Rendered (Runtime, "en", "new_york_full", Args),
           "datetime full skeleton alias preserves zone conversion");
   Assert (Rendered (Runtime, "en", "new_york_full_named_alias", Args) =
             Rendered (Runtime, "en", "new_york_full", Args),
           "datetime time-full skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_full_datetime_alias", Args) =
        Rendered (Runtime, "en", "new_york_full", Args),
      "datetime-full skeleton alias preserves zone conversion");
   Assert
     (Rendered (Runtime, "en", "new_york_full_dateTime_alias", Args) =
        Rendered (Runtime, "en", "new_york_full", Args),
      "dateTime-full skeleton alias preserves zone conversion");
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "new_york_summer", Args) = "08:00",
           "New York named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "canada_eastern", Args) = "08:00",
           "Canada/Eastern aliases America/Toronto");
   Assert (Rendered (Runtime, "en", "us_pacific", Args) = "05:00",
           "US/Pacific aliases America/Los_Angeles");
   Assert (Rendered (Runtime, "en", "new_york_offset", Args) =
             "2024 07 01 08:00 -0400",
           "New York skeleton zone offset applies daylight time");
   Assert (Rendered (Runtime, "en", "chatham_winter", Args) =
             "2024 07 02 00:45 +1245",
           "generated tzdb table converts Pacific/Chatham standard offset");
   Assert (Rendered (Runtime, "en", "cairo_tzdb", Args) =
             "2024 07 01 15:00 +0300",
           "generated tzdb table converts Africa/Cairo daylight offset");
   Assert (Rendered (Runtime, "en", "st_johns_tzdb", Args) =
             "2024 07 01 09:30 -0230",
           "generated tzdb table converts America/St_Johns half-hour offset");
   I18N.Arguments.Set (Args, "instant", "2024-01-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "chatham_summer", Args) =
             "2024 01 02 01:45 +1345",
           "generated tzdb table converts Pacific/Chatham daylight offset");
   I18N.Arguments.Set (Args, "instant", "2024-03-10T06:59:00Z");
   Assert (Rendered (Runtime, "en", "new_york_summer", Args) = "01:59",
           "New York DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-03-10T07:00:00Z");
   Assert (Rendered (Runtime, "en", "new_york_summer", Args) = "03:00",
           "New York DST boundary applies daylight offset at spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-11-03T05:59:00Z");
   Assert (Rendered (Runtime, "en", "new_york_summer", Args) = "01:59",
           "New York DST boundary keeps daylight offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-11-03T06:00:00Z");
   Assert (Rendered (Runtime, "en", "new_york_summer", Args) = "01:00",
           "New York DST boundary restores standard offset at autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "toronto", Args) = "08:00",
           "Toronto named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "montreal", Args) = "08:00",
           "Montreal named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "detroit", Args) = "08:00",
           "Detroit named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "indianapolis", Args) = "08:00",
           "Indianapolis named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "louisville", Args) = "08:00",
           "Louisville named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "nassau", Args) = "08:00",
           "Nassau named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "london_summer", Args) = "13:00",
           "London named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "dublin", Args) = "13:00",
           "Dublin named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "lisbon", Args) = "13:00",
           "Lisbon named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "canary", Args) = "13:00",
           "Canary named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "moscow", Args) = "15:00",
           "Moscow named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "athens", Args) = "15:00",
           "Athens named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "helsinki", Args) = "15:00",
           "Helsinki named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "bucharest", Args) = "15:00",
           "Bucharest named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "sofia", Args) = "15:00",
           "Sofia named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "vilnius", Args) = "15:00",
           "Vilnius named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "riga", Args) = "15:00",
           "Riga named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "tallinn", Args) = "15:00",
           "Tallinn named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "kyiv", Args) = "15:00",
           "Kyiv named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "rome_summer", Args) = "14:00",
           "Rome named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "amsterdam_summer", Args) = "14:00",
           "Amsterdam named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "zurich_summer", Args) = "14:00",
           "Zurich named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "vienna_summer", Args) = "14:00",
           "Vienna named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "brussels_summer", Args) = "14:00",
           "Brussels named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "copenhagen_summer", Args) = "14:00",
           "Copenhagen named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "stockholm_summer", Args) = "14:00",
           "Stockholm named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "oslo_summer", Args) = "14:00",
           "Oslo named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "warsaw_summer", Args) = "14:00",
           "Warsaw named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "prague_summer", Args) = "14:00",
           "Prague named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "budapest_summer", Args) = "14:00",
           "Budapest named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "bratislava", Args) = "14:00",
           "Bratislava named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "luxembourg", Args) = "14:00",
           "Luxembourg named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "monaco", Args) = "14:00",
           "Monaco named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "andorra", Args) = "14:00",
           "Andorra named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "malta", Args) = "14:00",
           "Malta named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "san_marino", Args) = "14:00",
           "San Marino named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "vatican", Args) = "14:00",
           "Vatican named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "belgrade", Args) = "14:00",
           "Belgrade named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "zagreb", Args) = "14:00",
           "Zagreb named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "ljubljana", Args) = "14:00",
           "Ljubljana named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "sarajevo", Args) = "14:00",
           "Sarajevo named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "skopje", Args) = "14:00",
           "Skopje named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "podgorica", Args) = "14:00",
           "Podgorica named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "tirane", Args) = "14:00",
           "Tirane named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "chisinau", Args) = "15:00",
           "Chisinau named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "nicosia", Args) = "15:00",
           "Nicosia named zone applies deterministic summer time");
   Assert (Rendered (Runtime, "en", "los_angeles_summer", Args) = "05:00",
           "Los Angeles named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "vancouver", Args) = "05:00",
           "Vancouver named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "tijuana", Args) = "05:00",
           "Tijuana named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "denver_summer", Args) = "06:00",
           "Denver named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "boise", Args) = "06:00",
           "Boise named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "edmonton", Args) = "06:00",
           "Edmonton named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "winnipeg", Args) = "07:00",
           "Winnipeg named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "phoenix", Args) = "05:00",
           "Phoenix named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "mexico_city", Args) = "06:00",
           "Mexico City named zone uses deterministic post-2022 fixed offset");
   Assert (Rendered (Runtime, "en", "bogota", Args) = "07:00",
           "Bogota named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "lima", Args) = "07:00",
           "Lima named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "johannesburg", Args) = "14:00",
           "Johannesburg named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "accra", Args) = "12:00",
           "Accra named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "abidjan", Args) = "12:00",
           "Abidjan named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "algiers", Args) = "13:00",
           "Algiers named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "tunis", Args) = "13:00",
           "Tunis named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "nairobi", Args) = "15:00",
           "Nairobi named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "lagos", Args) = "13:00",
           "Lagos named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "dubai", Args) = "16:00",
           "Dubai named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "yerevan", Args) = "16:00",
           "Yerevan named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "tbilisi", Args) = "16:00",
           "Tbilisi named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "baku", Args) = "16:00",
           "Baku named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "riyadh", Args) = "15:00",
           "Riyadh named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "15:00",
           "Jerusalem named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "15:30",
           "Tehran named zone uses deterministic post-2022 fixed offset");
   Assert (Rendered (Runtime, "en", "shanghai", Args) = "20:00",
           "Shanghai named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "singapore", Args) = "20:00",
           "Singapore named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "hong_kong", Args) = "20:00",
           "Hong Kong named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "taipei", Args) = "20:00",
           "Taipei named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "kuala_lumpur", Args) = "20:00",
           "Kuala Lumpur named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "istanbul", Args) = "15:00",
           "Istanbul named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "seoul", Args) = "21:00",
           "Seoul named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "ulaanbaatar", Args) = "20:00",
           "Ulaanbaatar named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "bangkok", Args) = "19:00",
           "Bangkok named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "jakarta", Args) = "19:00",
           "Jakarta named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "ho_chi_minh", Args) = "19:00",
           "Ho Chi Minh named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "karachi", Args) = "17:00",
           "Karachi named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "colombo", Args) = "17:30",
           "Colombo named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "dhaka", Args) = "18:00",
           "Dhaka named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "yangon", Args) = "18:30",
           "Yangon named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "tashkent", Args) = "17:00",
           "Tashkent named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "kathmandu", Args) = "17:45",
           "Kathmandu named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "manila", Args) = "20:00",
           "Manila named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "honolulu", Args) = "02:00",
           "Honolulu named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "00:00",
           "Auckland named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "22:00",
           "Sydney named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "melbourne", Args) = "22:00",
           "Melbourne named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "hobart", Args) = "22:00",
           "Hobart named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "adelaide", Args) = "21:30",
           "Adelaide named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "brisbane", Args) = "22:00",
           "Brisbane named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "perth", Args) = "20:00",
           "Perth named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "darwin", Args) = "21:30",
           "Darwin named zone uses deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "sao_paulo", Args) = "09:00",
           "Sao Paulo named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "buenos_aires", Args) = "09:00",
           "Buenos Aires named zone uses deterministic fixed offset");

   I18N.Arguments.Set (Args, "instant", "2021-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "mexico_city", Args) = "07:00",
           "Mexico City named zone applies historical deterministic DST");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "16:30",
           "Tehran named zone applies historical deterministic DST");

   I18N.Arguments.Set (Args, "instant", "2018-01-15T12:00:00Z");
   Assert (Rendered (Runtime, "en", "sao_paulo", Args) = "10:00",
           "Sao Paulo named zone applies historical deterministic DST");

   I18N.Arguments.Set (Args, "instant", "2024-01-15T12:00:00Z");
   Assert (Rendered (Runtime, "en", "sao_paulo", Args) = "09:00",
           "Sao Paulo named zone uses post-2019 deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "01:00",
           "Auckland named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "23:00",
           "Sydney named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "melbourne", Args) = "23:00",
           "Melbourne named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "hobart", Args) = "23:00",
           "Hobart named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "adelaide", Args) = "22:30",
           "Adelaide named zone applies deterministic daylight time");
   Assert (Rendered (Runtime, "en", "brisbane", Args) = "22:00",
           "Brisbane named zone remains on deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "perth", Args) = "20:00",
           "Perth named zone remains on deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "darwin", Args) = "21:30",
           "Darwin named zone remains on deterministic fixed offset");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "14:00",
           "Jerusalem named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "15:30",
           "Tehran named zone applies deterministic standard time");
   I18N.Arguments.Set (Args, "instant", "2024-03-28T23:59:00Z");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "01:59",
           "Jerusalem DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-03-29T00:00:00Z");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "03:00",
           "Jerusalem DST boundary applies daylight offset at spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-26T22:59:00Z");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "01:59",
           "Jerusalem tzdb boundary keeps daylight offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-26T23:00:00Z");
   Assert (Rendered (Runtime, "en", "jerusalem", Args) = "01:00",
           "Jerusalem tzdb boundary restores standard offset at autumn transition");
   I18N.Arguments.Set (Args, "instant", "2021-03-21T12:00:00Z");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "15:30",
           "Tehran historical DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2021-03-22T12:00:00Z");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "16:30",
           "Tehran historical DST boundary applies daylight offset after spring transition");
   I18N.Arguments.Set (Args, "instant", "2021-09-21T12:00:00Z");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "16:30",
           "Tehran historical DST boundary keeps daylight offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2021-09-22T12:00:00Z");
   Assert (Rendered (Runtime, "en", "tehran", Args) = "15:30",
           "Tehran historical DST boundary restores standard offset after autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-04-06T12:00:00Z");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "01:00",
           "Auckland DST boundary keeps daylight offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-04-07T12:00:00Z");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "00:00",
           "Auckland DST boundary restores standard offset after autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-09-28T12:00:00Z");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "00:00",
           "Auckland DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-09-29T12:00:00Z");
   Assert (Rendered (Runtime, "en", "auckland", Args) = "01:00",
           "Auckland DST boundary applies daylight offset after spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-04-06T15:59:00Z");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "02:59",
           "Sydney DST boundary keeps daylight offset before autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-04-06T16:00:00Z");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "02:00",
           "Sydney DST boundary restores standard offset at autumn transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-05T15:59:00Z");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "01:59",
           "Sydney DST boundary keeps standard offset before spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-10-05T16:00:00Z");
   Assert (Rendered (Runtime, "en", "sydney", Args) = "03:00",
           "Sydney DST boundary applies daylight offset at spring transition");
   I18N.Arguments.Set (Args, "instant", "2024-01-15T12:00:00Z");
   Assert (Rendered (Runtime, "en", "london_winter", Args) = "12:00",
           "London named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "dublin", Args) = "12:00",
           "Dublin named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "lisbon", Args) = "12:00",
           "Lisbon named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "canary", Args) = "12:00",
           "Canary named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "athens", Args) = "14:00",
           "Athens named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "helsinki", Args) = "14:00",
           "Helsinki named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "bucharest", Args) = "14:00",
           "Bucharest named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "sofia", Args) = "14:00",
           "Sofia named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "vilnius", Args) = "14:00",
           "Vilnius named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "riga", Args) = "14:00",
           "Riga named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "tallinn", Args) = "14:00",
           "Tallinn named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "kyiv", Args) = "14:00",
           "Kyiv named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "paris_winter", Args) = "13:00",
           "Paris named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "zurich_winter", Args) = "13:00",
           "Zurich named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "stockholm_winter", Args) = "13:00",
           "Stockholm named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "warsaw_winter", Args) = "13:00",
           "Warsaw named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "madrid_winter", Args) = "13:00",
           "Madrid named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "bratislava", Args) = "13:00",
           "Bratislava named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "belgrade", Args) = "13:00",
           "Belgrade named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "chisinau", Args) = "14:00",
           "Chisinau named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "nicosia", Args) = "14:00",
           "Nicosia named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "chicago_winter", Args) = "06:00",
           "Chicago named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "toronto", Args) = "07:00",
           "Toronto named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "montreal", Args) = "07:00",
           "Montreal named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "detroit", Args) = "07:00",
           "Detroit named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "indianapolis", Args) = "07:00",
           "Indianapolis named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "louisville", Args) = "07:00",
           "Louisville named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "nassau", Args) = "07:00",
           "Nassau named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "winnipeg", Args) = "06:00",
           "Winnipeg named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "edmonton", Args) = "05:00",
           "Edmonton named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "boise", Args) = "05:00",
           "Boise named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "vancouver", Args) = "04:00",
           "Vancouver named zone applies deterministic standard time");
   Assert (Rendered (Runtime, "en", "tijuana", Args) = "04:00",
           "Tijuana named zone applies deterministic standard time");

   I18N.Arguments.Set (Args, "day", "2024-02-29");
   I18N.Arguments.Set (Args, "clock", "09:05:07");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:07+02:00");
   Assert (Rendered (Runtime, "en", "date_skeleton", Args) =
             "Feb 29, 2024",
           "date skeleton resolves CLDR availableFormats order");
   Assert (Rendered (Runtime, "en", "date_literal", Args) =
             "2024-02-29",
           "date skeleton renders quoted literal separators");
   Assert (Rendered (Runtime, "en", "date_comma_literal", Args) =
             "2024,02",
           "date skeleton preserves quoted comma literals");
   Assert (Rendered (Runtime, "en", "date_brace_literal", Args) =
             "2024{02}29",
           "date skeleton preserves quoted brace literals");
   Assert (Rendered (Runtime, "en", "year_widths", Args) =
             "2024/24/2024/02024",
           "date skeleton pads year fields to requested width");
   Assert (Rendered (Runtime, "en", "year_alias_fields", Args) =
             "2024/2024/2024",
           "date skeleton renders extended cyclic and related year fields");
   Assert (Rendered (Runtime, "en", "standalone_month_fields", Args) =
             "2/02/Feb/February/2",
           "date skeleton renders standalone month numeric and name fields");
   Assert (Rendered (Runtime, "en", "modified_julian_day", Args) =
             "60369",
           "date skeleton renders modified Julian day fields");
   I18N.Arguments.Set (Args, "day", "2016-01-01");
   Assert (Rendered (Runtime, "en", "week_year", Args) =
             "2016/1/1/2016",
           "date skeleton Y/w/W render locale week-year data");
   Assert (Rendered (Runtime, "de", "week_year", Args) =
             "2015/53/0/2016",
           "date skeleton Y/w/W render Monday min-days locale data");
   I18N.Arguments.Set (Args, "day", "2024-02-29");
   Assert (Rendered (Runtime, "de", "date_skeleton", Args) =
             "Do. 29 Feb. 2024",
           "date skeleton renders localized weekday/month fields");
   Assert (Rendered (Runtime, "cs", "date_skeleton", Args) =
             U (16#10D#) & "t 29 " & U (16#FA#) & "no 2024",
           "date skeleton renders UTF-8 short names without slicing");
   Assert (Rendered (Runtime, "ro", "date_skeleton", Args) =
             "joi 29 feb. 2024",
           "date skeleton localizes Romanian weekday/month names");
   Assert (Rendered (Runtime, "lt", "date_skeleton", Args) =
             "kt 29 vas. 2024",
           "date skeleton localizes Lithuanian weekday/month names");
   Assert (Rendered (Runtime, "sl", "date_skeleton", Args) =
             U (16#10D#) & "et. 29 feb. 2024",
           "date skeleton localizes Slovenian weekday/month names");
   Assert (Rendered (Runtime, "ja", "date_skeleton", Args) =
             U (16#6728#) & " 29 2" & U (16#6708#) & " 2024",
           "date skeleton localizes Japanese weekday/month names");
   Assert (Rendered (Runtime, "zh", "date_skeleton", Args) =
             U (16#5468#) & U (16#56DB#) & " 29 2"
             & U (16#6708#) & " 2024",
           "date skeleton localizes Chinese weekday/month names");
   Assert (Rendered (Runtime, "ko", "date_skeleton", Args) =
             U (16#BAA9#) & " 29 2" & U (16#C6D4#) & " 2024",
           "date skeleton localizes Korean weekday/month names");
   Assert (Rendered (Runtime, "de", "era", Args) = "2024 n. Chr.",
           "date skeleton localizes German Gregorian era names");
   Assert (Rendered (Runtime, "fr", "era", Args) = "2024 ap. J.-C.",
           "date skeleton localizes French Gregorian era names");
   Assert (Rendered (Runtime, "es", "era", Args) = "2024 d. C.",
           "date skeleton localizes Spanish Gregorian era names");
   Assert (Rendered (Runtime, "it", "era", Args) = "2024 d.C.",
           "date skeleton localizes Italian Gregorian era names");
   Assert (Rendered (Runtime, "pt", "era", Args) = "2024 d.C.",
           "date skeleton localizes Portuguese Gregorian era names");
   Assert (Rendered (Runtime, "nl", "era", Args) = "2024 n.Chr.",
           "date skeleton localizes Dutch Gregorian era names");
   Assert (Rendered (Runtime, "ro", "era", Args) = "2024 d.Hr.",
           "date skeleton localizes Romanian Gregorian era names");
   Assert (Rendered (Runtime, "lt", "era", Args) = "2024 m. po Kr.",
           "date skeleton localizes Lithuanian Gregorian era names");
   Assert (Rendered (Runtime, "sl", "era", Args) = "2024 po Kr.",
           "date skeleton localizes Slovenian Gregorian era names");
   Assert (Rendered (Runtime, "pl", "era", Args) = "2024 n.e.",
           "date skeleton localizes Polish Gregorian era names");
   Assert (Rendered (Runtime, "cs", "era", Args) = "2024 n. l.",
           "date skeleton localizes Czech Gregorian era names");
   Assert (Rendered (Runtime, "ru", "era", Args) =
             "2024" & U (16#202F#)
             & UTF8 ([16#433#, 16#2E#, 16#20#, 16#43D#, 16#2E#,
                       16#20#, 16#44D#, 16#2E#]),
           "date skeleton localizes Russian Gregorian era names");
   Assert (Rendered (Runtime, "ar", "era", Args) =
             U (16#662#) & U (16#660#) & U (16#662#)
             & U (16#664#) & " " & U (16#645#),
           "date skeleton localizes Arabic Gregorian era names");
   Assert (Rendered (Runtime, "ja", "era", Args) =
             U (16#897F#) & U (16#66A6#) & " 2024" & U (16#5E74#),
           "date skeleton localizes Japanese Gregorian era names");
   Assert (Rendered (Runtime, "zh", "era", Args) =
             U (16#516C#) & U (16#5143#) & " 2024" & U (16#5E74#),
           "date skeleton localizes Chinese Gregorian era names");
   Assert (Rendered (Runtime, "ko", "era", Args) =
             U (16#C11C#) & U (16#AE30#) & " 2024" & U (16#B144#),
           "date skeleton localizes Korean Gregorian era names");
   Assert (Rendered (Runtime, "de", "quarter", Args) = "1. Quartal",
           "date skeleton localizes German wide quarter names");
   Assert (Rendered (Runtime, "fr", "quarter", Args) = "1er trimestre",
           "date skeleton localizes French wide quarter names");
   Assert (Rendered (Runtime, "es", "quarter", Args) =
             "1.er trimestre",
           "date skeleton localizes Spanish wide quarter names");
   Assert (Rendered (Runtime, "it", "quarter", Args) =
             "1" & U (16#BA#) & " trimestre",
           "date skeleton localizes Italian wide quarter names");
   Assert (Rendered (Runtime, "pt", "quarter", Args) =
             "1" & U (16#BA#) & " trimestre",
           "date skeleton localizes Portuguese wide quarter names");
   Assert (Rendered (Runtime, "nl", "quarter", Args) = "1e kwartaal",
           "date skeleton localizes Dutch wide quarter names");
   Assert (Rendered (Runtime, "ro", "quarter", Args) = "trimestrul I",
           "date skeleton localizes Romanian wide quarter names");
   Assert (Rendered (Runtime, "lt", "quarter", Args) = "I ketvirtis",
           "date skeleton localizes Lithuanian wide quarter names");
   Assert (Rendered (Runtime, "sl", "quarter", Args) =
             "1. " & U (16#10D#) & "etrtletje",
           "date skeleton localizes Slovenian wide quarter names");
   Assert (Rendered (Runtime, "pl", "quarter", Args) =
             "I kwarta" & U (16#142#),
           "date skeleton localizes Polish wide quarter names");
   Assert (Rendered (Runtime, "cs", "quarter", Args) =
             "1. " & U (16#10D#) & "tvrtlet" & U (16#ED#),
           "date skeleton localizes Czech wide quarter names");
   Assert (Rendered (Runtime, "ru", "quarter", Args) =
             "1-" & U (16#439#) & " "
             & UTF8 ([16#43A#, 16#432#, 16#430#, 16#440#, 16#442#,
                      16#430#, 16#43B#]),
           "date skeleton localizes Russian wide quarter names");
   Assert (Rendered (Runtime, "ar", "quarter", Args) =
             UTF8 ([16#627#, 16#644#, 16#631#, 16#628#, 16#639#])
             & " "
             & UTF8 ([16#627#, 16#644#, 16#623#, 16#648#, 16#644#]),
           "date skeleton localizes Arabic wide quarter names");
   Assert (Rendered (Runtime, "ja", "quarter", Args) =
             U (16#7B2C#) & "1" & U (16#56DB#) & U (16#534A#)
             & U (16#671F#),
           "date skeleton localizes Japanese wide quarter names");
   Assert (Rendered (Runtime, "zh", "quarter", Args) =
             U (16#7B2C#) & U (16#4E00#) & U (16#5B63#)
             & U (16#5EA6#),
           "date skeleton localizes Chinese wide quarter names");
   Assert (Rendered (Runtime, "ko", "quarter", Args) =
             U (16#C81C#) & " 1/4" & U (16#BD84#) & U (16#AE30#),
           "date skeleton localizes Korean wide quarter names");
   Assert (Rendered (Runtime, "bg", "quarter", Args) =
             "1. " & UTF8 ([16#442#, 16#440#, 16#438#, 16#43C#,
                             16#435#, 16#441#, 16#435#, 16#447#,
                             16#438#, 16#435#]),
           "date skeleton uses full CLDR Bulgarian wide quarter names");
   Assert (Rendered (Runtime, "uk", "quarter", Args) =
             "1-" & U (16#439#) & " "
             & UTF8 ([16#43A#, 16#432#, 16#430#, 16#440#, 16#442#,
                      16#430#, 16#43B#]),
           "date skeleton uses full CLDR Ukrainian wide quarter names");
   Assert (Rendered (Runtime, "en", "short_quarter", Args) = "Q1",
           "date skeleton keeps English abbreviated quarter names");
   Assert (Rendered (Runtime, "en", "narrow_quarter", Args) = "1",
           "date skeleton falls back to numeric narrow quarter names");
   Assert (Rendered (Runtime, "fr", "short_quarter", Args) = "T1",
           "date skeleton localizes French abbreviated quarter names");
   Assert (Rendered (Runtime, "ro", "short_quarter", Args) = "trim. I",
           "date skeleton localizes Romanian abbreviated quarter names");
   Assert (Rendered (Runtime, "cs", "short_quarter", Args) =
             "Q1",
           "date skeleton localizes Czech abbreviated quarter names");
   Assert (Rendered (Runtime, "ru", "short_quarter", Args) =
             "1-" & U (16#439#) & " "
             & U (16#43A#) & U (16#432#) & ".",
           "date skeleton localizes Russian abbreviated quarter names");
   Assert (Rendered (Runtime, "ar", "short_quarter", Args) =
             UTF8 ([16#627#, 16#644#, 16#631#, 16#628#, 16#639#])
             & " "
             & UTF8 ([16#627#, 16#644#, 16#623#, 16#648#, 16#644#]),
           "date skeleton localizes Arabic abbreviated quarter names");
   Assert (Rendered (Runtime, "zh", "short_quarter", Args) =
             "1" & U (16#5B63#) & U (16#5EA6#),
           "date skeleton localizes Chinese abbreviated quarter names");
   Assert (Rendered (Runtime, "ko", "short_quarter", Args) =
             "1" & U (16#BD84#) & U (16#AE30#),
           "date skeleton localizes Korean abbreviated quarter names");
   Assert (Rendered (Runtime, "hi", "short_quarter", Args) =
             U (16#924#) & U (16#93F#) & "1",
           "date skeleton uses full CLDR Hindi abbreviated quarter names");
   Assert (Rendered (Runtime, "en", "weekday_numeric", Args) =
             "5/05/5/05/Thu/Thursday",
           "date skeleton renders numeric and named e/c weekday fields");
   Assert (Rendered (Runtime, "en", "weekday_widths", Args) =
             "Thu/Thursday/T/Thu/Thu",
           "date skeleton distinguishes weekday widths 3, 4, 5, and 6");
   Assert (Rendered (Runtime, "de", "weekday_numeric", Args) =
             "4/04/Do./Donnerstag",
           "date skeleton localizes numeric e/c weekday base");
   Assert (Rendered (Runtime, "cs", "narrow_names", Args) =
             U (16#FA#) & "/" & U (16#10D#),
           "date skeleton narrow names preserve whole UTF-8 characters");
   Assert (Rendered (Runtime, "en", "time_skeleton", Args) =
             "09:05:07 AM",
           "time skeleton renders 12-hour clock and day period");
   Assert (Rendered (Runtime, "en", "preferred_hour", Args) =
             "9:05 AM",
           "j skeleton uses English preferred 12-hour cycle");
   Assert (Rendered (Runtime, "en", "preferred_hour_explicit", Args) =
             "9:05 AM",
           "j skeleton does not duplicate an explicit day-period field");
   Assert (Rendered (Runtime, "en", "preferred_hour_no_period", Args) =
             "9:05",
           "J skeleton uses English preferred cycle without day period");
   Assert (Rendered (Runtime, "en", "preferred_hour_flexible", Args) =
             "9:05 AM",
           "C skeleton uses English preferred cycle with day period");
   Assert (Rendered (Runtime, "de", "preferred_hour", Args) =
             "9:05",
           "j skeleton uses German preferred 24-hour cycle");
   Assert (Rendered (Runtime, "de", "preferred_hour_no_period", Args) =
             "9:05",
           "J skeleton uses German preferred 24-hour cycle");
   Assert (Rendered (Runtime, "de", "preferred_hour_flexible", Args) =
             "9:05",
           "C skeleton uses German preferred 24-hour cycle");
   Assert (Rendered (Runtime, "ko", "preferred_hour", Args) =
             "9:05 " & U (16#C624#) & U (16#C804#),
           "j skeleton uses Korean preferred 12-hour cycle");
   Assert (Rendered (Runtime, "ko", "preferred_hour_no_period", Args) =
             "9:05",
           "J skeleton uses Korean preferred 12-hour cycle without period");
   Assert (Rendered (Runtime, "ko", "preferred_hour_flexible", Args) =
             "9:05 " & U (16#C624#) & U (16#C804#),
           "C skeleton uses Korean preferred 12-hour cycle");
   Assert (Rendered (Runtime, "th", "time_skeleton", Args) =
             U (16#E50#) & U (16#E59#) & ":"
             & U (16#E50#) & U (16#E55#) & ":"
             & U (16#E50#) & U (16#E57#) & " AM",
           "time skeleton uses full CLDR Thai abbreviated day-period names");
   Assert (Rendered (Runtime, "uk", "time_skeleton", Args) =
             "09:05:07 " & U (16#434#) & U (16#43F#),
           "time skeleton uses full CLDR Ukrainian abbreviated day-period names");
   Assert (Rendered (Runtime, "en", "fractional_fields", Args) =
             "07.000|000|32707000000000|32707000",
           "time skeleton renders zero fractional fields deterministically");
   I18N.Arguments.Set (Args, "clock", "09:05:07.123456789");
   Assert (Rendered (Runtime, "en", "fractional_fields", Args) =
             "07.123|123456789|32707123456789|32707123",
           "time skeleton renders parsed fractional seconds");
   I18N.Arguments.Set (Args, "clock", "00:00:00");
   Assert (Rendered (Runtime, "de", "period_midnight", Args) =
             "Mitternacht",
           "time skeleton localizes German wide midnight period");
   Assert (Rendered (Runtime, "de", "period_midnight_narrow", Args) =
             "Mitternacht",
           "time skeleton uses CLDR abbreviated fallback for width 5 day periods");
   Assert (Rendered (Runtime, "en", "period_midnight_narrow", Args) =
             "midnight",
           "time skeleton uses English CLDR abbreviated fallback for width 5 day periods");
   Assert (Rendered (Runtime, "pt", "period_midnight", Args) =
             "meia-noite",
           "time skeleton localizes Portuguese wide midnight period");
   Assert (Rendered (Runtime, "ro", "period_midnight", Args) =
             "la miezul nop" & U (16#21B#) & "ii",
           "time skeleton localizes Romanian wide midnight period");
   Assert (Rendered (Runtime, "pl", "period_midnight", Args) =
             "o p" & U (16#F3#) & U (16#142#) & "nocy",
           "time skeleton localizes Polish wide midnight period");
   Assert (Rendered (Runtime, "ru", "period_midnight", Args) =
             UTF8 ([16#43F#, 16#43E#, 16#43B#, 16#43D#, 16#43E#,
                    16#447#, 16#44C#]),
           "time skeleton localizes Russian wide midnight period");
   I18N.Arguments.Set (Args, "clock", "12:00:00");
   Assert (Rendered (Runtime, "fr", "period_noon", Args) = "midi",
           "time skeleton localizes French wide noon period");
   Assert (Rendered (Runtime, "it", "period_noon", Args) = "mezzogiorno",
           "time skeleton localizes Italian wide noon period");
   Assert (Rendered (Runtime, "lt", "period_noon", Args) = "perpiet",
           "time skeleton localizes Lithuanian wide noon period");
   Assert (Rendered (Runtime, "cs", "period_noon", Args) = "poledne",
           "time skeleton localizes Czech wide noon period");
   I18N.Arguments.Set (Args, "clock", "09:05:07");
   Assert (Rendered (Runtime, "es", "period_am", Args) =
             "a." & U (16#202F#) & "m.",
           "time skeleton localizes Spanish abbreviated AM period");
   Assert (Rendered (Runtime, "ja", "period_am", Args) =
             U (16#5348#) & U (16#524D#),
           "time skeleton localizes Japanese abbreviated AM period");
   Assert (Rendered (Runtime, "zh", "period_am", Args) =
             U (16#4E0A#) & U (16#5348#),
           "time skeleton localizes Chinese abbreviated AM period");
   Assert (Rendered (Runtime, "ko", "period_am", Args) =
             U (16#C624#) & U (16#C804#),
           "time skeleton localizes Korean abbreviated AM period");
   I18N.Arguments.Set (Args, "clock", "15:00:00");
   Assert (Rendered (Runtime, "nl", "period_pm", Args) = "p.m.",
           "time skeleton localizes Dutch abbreviated PM period");
   Assert (Rendered (Runtime, "sl", "period_pm", Args) = "pop.",
           "time skeleton localizes Slovenian abbreviated PM period");
   Assert (Rendered (Runtime, "ar", "period_pm", Args) = U (16#645#),
           "time skeleton localizes Arabic abbreviated PM period");
   I18N.Arguments.Set (Args, "clock", "09:05:07");
   Assert (Rendered (Runtime, "de", "period_morning", Args) = "morgens",
           "flexible day periods use generated German morning labels");
   I18N.Arguments.Set (Args, "clock", "15:00:00");
   Assert (Rendered (Runtime, "fr", "period_afternoon", Args) =
             "de l" & U (16#2019#) & "apr" & U (16#E8#) & "s-midi",
           "flexible day periods use generated French afternoon labels");
   I18N.Arguments.Set (Args, "clock", "20:00:00");
   Assert (Rendered (Runtime, "de", "period_evening", Args) = "abends",
           "flexible day periods use generated German evening labels");
   I18N.Arguments.Set (Args, "clock", "03:00:00");
   Assert (Rendered (Runtime, "de", "period_night", Args) = "nachts",
           "flexible day periods use generated German night labels");
   I18N.Arguments.Set (Args, "clock", "09:05:07");
   Assert (Rendered (Runtime, "en", "time_literal", Args) =
             "09:05:07 o'clock",
           "time skeleton renders quoted literals and doubled apostrophes");
   Assert (Rendered (Runtime, "en", "zone_skeleton", Args) =
             "21:30 UTC",
           "time skeleton renders converted fixed-zone text");
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "zone_widths", Args) =
             "GMT-04:00|-04:00|-04:00|America/New_York",
           "time zone skeleton widths render long offsets and zone IDs");
   Assert (Rendered (Runtime, "fr", "zone_widths", Args) =
             "UTC-04:00|-04:00|-04:00|America/New_York",
           "time zone skeleton uses full CLDR French GMT prefix data");
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00+02:00:30");
   declare
      Zone_Second_Widths : constant String :=
        Rendered (Runtime, "en", "zone_seconds_widths", Args);
   begin
      Assert (Zone_Second_Widths = "+02:00:30|+02:00:30",
              "time zone width 5 formats retain fixed-second offsets");
   end;
   I18N.Arguments.Set (Args, "instant", "2024-07-01T12:00:00Z");
   Assert (Rendered (Runtime, "en", "zone_v_widths", Args) =
             "America/New_York|America/New_York|New York|New York Time",
           "V skeleton widths render identifiers and location labels");
   Assert (Rendered (Runtime, "fr", "zone_v_widths", Args) =
             "America/New_York|America/New_York|New York|heure : New York",
           "V skeleton widths use full CLDR French location pattern data");
   Assert (Rendered (Runtime, "en", "utc_v_widths", Args) =
             "UTC|UTC|UTC|UTC",
           "V skeleton widths keep UTC labels stable");
   Assert (Rendered (Runtime, "en", "zone_short_gmt", Args) =
             "GMT-4",
           "short localized GMT skeleton omits hour padding");
   Assert (Rendered (Runtime, "en", "kathmandu_short_gmt", Args) =
             "GMT+5:45",
           "short localized GMT skeleton keeps minute offsets");
   Assert (Rendered (Runtime, "da", "kathmandu_short_gmt", Args) =
             "GMT+5.45",
           "short localized GMT skeleton uses full CLDR Danish offset separator");
   Assert (Rendered (Runtime, "fi", "kathmandu_short_gmt", Args) =
             "UTC+5.45",
           "short localized GMT skeleton uses full CLDR Finnish GMT prefix and offset separator");
   Assert (Rendered (Runtime, "en", "utc_short_gmt", Args) =
             "GMT",
           "short localized GMT skeleton collapses zero offset");
   Assert (Rendered (Runtime, "en", "zone_names", Args) =
             "EDT|ET|Eastern Time|America/New_York",
           "short z and v zone skeletons render deterministic abbreviations");
   Assert (Rendered (Runtime, "en", "zone_long_names", Args) =
             "Eastern Time|Eastern Time|America/New_York",
           "long z zone skeleton renders deterministic generic names");
   Assert (Rendered (Runtime, "fr", "zone_long_names", Args) =
             "heure de l" & U (16#2019#) & "Est nord-am" & U (16#E9#)
             & "ricain|heure de l" & U (16#2019#) & "Est nord-am"
             & U (16#E9#) & "ricain|America/New_York",
           "long z zone skeleton uses generated CLDR metazone rows");
   Assert (Rendered (Runtime, "en", "berlin_zone_names", Args) =
             "GMT+2|GMT+2|Central European Time|Europe/Berlin",
           "European short z and v skeletons render abbreviations");
   Assert (Rendered (Runtime, "de", "berlin_zone_names", Args) =
             "Mitteleurop" & U (16#E4#) & "ische Zeit|Mitteleurop"
             & U (16#E4#) & "ische Zeit|Europe/Berlin",
           "European zone skeleton names localize German generic names");
   Assert (Rendered (Runtime, "de", "berlin_short_zone_names", Args) =
             "MESZ|MEZ|Europe/Berlin",
           "European short zone skeleton names use generated CLDR fallback");
   Assert (Rendered (Runtime, "de-AT", "berlin_zone_names", Args) =
             "Mitteleurop" & U (16#E4#) & "ische Zeit|Mitteleurop"
             & U (16#E4#) & "ische Zeit|Europe/Berlin",
           "European zone skeleton names fall back through source-backed German family rows");
   Assert (Rendered (Runtime, "en-AU", "lord_howe_short_names", Args) =
             "LHST|LHT|Lord Howe Time|Australia/Lord_Howe",
           "Lord Howe zone skeleton names use generated CLDR short family rows");
   Assert (Rendered (Runtime, "de", "lord_howe_zone_names", Args) =
             "Lord-Howe-Zeit|Lord-Howe-Zeit|Australia/Lord_Howe",
           "Lord Howe zone skeleton names localize German generic names");
   Assert (Rendered (Runtime, "de", "brisbane_zone_names", Args) =
             "Ostaustralische Zeit|Ostaustralische Zeit|Australia/Brisbane",
           "Brisbane zone skeleton names use generated CLDR eastern Australia rows");
   Assert (Rendered (Runtime, "de", "darwin_zone_names", Args) =
             "Zentralaustralische Zeit|Zentralaustralische Zeit|Australia/Darwin",
           "Darwin zone skeleton names use generated CLDR central Australia rows");
   Assert (Rendered (Runtime, "de", "perth_zone_names", Args) =
             "Westaustralische Zeit|Westaustralische Zeit|Australia/Perth",
           "Perth zone skeleton names use generated CLDR western Australia rows");
   Assert (Rendered (Runtime, "de", "eucla_zone_names", Args) =
             "Zentral-/Westaustralische Zeit|Zentral-/Westaustralische Zeit|Australia/Eucla",
           "Eucla zone skeleton names use generated CLDR central-western Australia rows");
   Assert (Rendered (Runtime, "ru", "zone_names", Args) =
             UTF8 ([16#412#, 16#43E#, 16#441#, 16#442#, 16#43E#,
                    16#447#, 16#43D#, 16#430#, 16#44F#, 16#20#,
                    16#410#, 16#43C#, 16#435#, 16#440#, 16#438#,
                    16#43A#, 16#430#])
             & "|"
             & UTF8 ([16#412#, 16#43E#, 16#441#, 16#442#, 16#43E#,
                      16#447#, 16#43D#, 16#430#, 16#44F#, 16#20#,
                      16#410#, 16#43C#, 16#435#, 16#440#, 16#438#,
                      16#43A#, 16#430#])
             & "|America/New_York",
           "zone skeleton names localize Russian generic names");
   Assert (Rendered (Runtime, "ar", "zone_names", Args) =
             UTF8 ([16#627#, 16#644#, 16#62A#, 16#648#, 16#642#,
                    16#64A#, 16#62A#, 16#20#, 16#627#, 16#644#,
                    16#634#, 16#631#, 16#642#, 16#64A#, 16#20#,
                    16#644#, 16#623#, 16#645#, 16#631#, 16#64A#,
                    16#643#, 16#627#, 16#20#, 16#627#, 16#644#,
                    16#634#, 16#645#, 16#627#, 16#644#, 16#64A#,
                    16#629#])
             & "|"
             & UTF8 ([16#627#, 16#644#, 16#62A#, 16#648#, 16#642#,
                      16#64A#, 16#62A#, 16#20#, 16#627#, 16#644#,
                      16#634#, 16#631#, 16#642#, 16#64A#, 16#20#,
                      16#644#, 16#623#, 16#645#, 16#631#, 16#64A#,
                      16#643#, 16#627#, 16#20#, 16#627#, 16#644#,
                      16#634#, 16#645#, 16#627#, 16#644#, 16#64A#,
                      16#629#])
             & "|America/New_York",
           "zone skeleton names localize Arabic generic names");
   Assert (Rendered (Runtime, "ja", "zone_names", Args) =
             UTF8 ([16#7C73#, 16#56FD#, 16#6771#, 16#90E8#,
                    16#6642#, 16#9593#])
             & "|"
             & UTF8 ([16#7C73#, 16#56FD#, 16#6771#, 16#90E8#,
                      16#6642#, 16#9593#])
             & "|America/New_York",
           "zone skeleton names localize Japanese generic names");
   Assert (Rendered (Runtime, "zh", "zone_names", Args) =
             UTF8 ([16#5317#, 16#7F8E#, 16#4E1C#, 16#90E8#,
                    16#65F6#, 16#95F4#])
             & "|"
             & UTF8 ([16#5317#, 16#7F8E#, 16#4E1C#, 16#90E8#,
                      16#65F6#, 16#95F4#])
             & "|America/New_York",
           "zone skeleton names localize Chinese generic names");
   Assert (Rendered (Runtime, "ko", "zone_names", Args) =
             UTF8 ([16#BBF8#, 16#20#, 16#B3D9#, 16#BD80#,
                    16#20#, 16#C2DC#, 16#AC04#])
             & "|"
             & UTF8 ([16#BBF8#, 16#20#, 16#B3D9#, 16#BD80#,
                      16#20#, 16#C2DC#, 16#AC04#])
             & "|America/New_York",
           "zone skeleton names localize Korean generic names");
   Assert (Rendered (Runtime, "en", "tokyo_short_generic", Args) =
             "GMT+9|Japan Time|Asia/Tokyo",
           "short v skeleton falls back to short GMT for fixed zones");
   Assert (Rendered (Runtime, "de", "tokyo_location_names", Args) =
             "Tokio|Tokio (Ortszeit)",
           "VVV and VVVV zone skeletons use generated CLDR exemplar locations");
   Assert (Rendered (Runtime, "de", "tokyo_zone_names", Args) =
             "Japanische Zeit|Japanische Zeit|Asia/Tokyo",
           "fixed zone skeleton names localize German names");
   Assert (Rendered (Runtime, "de-AT", "tokyo_zone_names", Args) =
             "Japanische Zeit|Japanische Zeit|Asia/Tokyo",
           "fixed zone skeleton names fall back through source-backed German zone rows");
   Assert (Rendered (Runtime, "de", "dubai_zone_names", Args) =
             "Golf-Zeit|Golf-Zeit|Asia/Dubai",
           "fixed Gulf zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "kolkata_zone_names", Args) =
             "Indische Normalzeit|Indische Normalzeit|Asia/Kolkata",
           "fixed India zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "kathmandu_zone_names", Args) =
             "Nepalesische Zeit|Nepalesische Zeit|Asia/Kathmandu",
           "fixed Nepal zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "bogota_zone_names", Args) =
             "Kolumbianische Zeit|Kolumbianische Zeit|America/Bogota",
           "fixed Colombia zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "nairobi_zone_names", Args) =
             "Ostafrikanische Zeit|Ostafrikanische Zeit|Africa/Nairobi",
           "fixed east Africa zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "manila_zone_names", Args) =
             "Philippinische Zeit|Philippinische Zeit|Asia/Manila",
           "fixed Philippines zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "yangon_zone_names", Args) =
             "Myanmar-Zeit|Myanmar-Zeit|Asia/Yangon",
           "fixed Myanmar zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "de", "honolulu_zone_names", Args) =
             "Hawaii-Aleuten-Zeit|Hawaii-Aleuten-Zeit|Pacific/Honolulu",
           "fixed Hawaii-Aleutian zone skeleton names use generated CLDR metazone rows");
   Assert (Rendered (Runtime, "ru", "tokyo_zone_names", Args) =
             UTF8 ([16#42F#, 16#43F#, 16#43E#, 16#43D#, 16#438#,
                    16#44F#])
             & "|"
             & UTF8 ([16#42F#, 16#43F#, 16#43E#, 16#43D#, 16#438#,
                      16#44F#])
             & "|Asia/Tokyo",
           "fixed zone skeleton names localize Russian names");
   Assert (Rendered (Runtime, "ar", "tokyo_zone_names", Args) =
             UTF8 ([16#62A#, 16#648#, 16#642#, 16#64A#, 16#62A#,
                    16#20#, 16#627#, 16#644#, 16#64A#, 16#627#,
                    16#628#, 16#627#, 16#646#])
             & "|"
             & UTF8 ([16#62A#, 16#648#, 16#642#, 16#64A#, 16#62A#,
                      16#20#, 16#627#, 16#644#, 16#64A#, 16#627#,
                      16#628#, 16#627#, 16#646#])
             & "|Asia/Tokyo",
           "fixed zone skeleton names localize Arabic names");
   Assert (Rendered (Runtime, "ja", "tokyo_zone_names", Args) =
             UTF8 ([16#65E5#, 16#672C#, 16#6642#, 16#9593#])
             & "|"
             & UTF8 ([16#65E5#, 16#672C#, 16#6642#, 16#9593#])
             & "|Asia/Tokyo",
           "fixed zone skeleton names localize Japanese names");
   Assert (Rendered (Runtime, "zh", "tokyo_zone_names", Args) =
             UTF8 ([16#65E5#, 16#672C#, 16#65F6#, 16#95F4#])
             & "|"
             & UTF8 ([16#65E5#, 16#672C#, 16#65F6#, 16#95F4#])
             & "|Asia/Tokyo",
           "fixed zone skeleton names localize Chinese names");
   Assert (Rendered (Runtime, "ko", "tokyo_zone_names", Args) =
             UTF8 ([16#C77C#, 16#BCF8#, 16#20#, 16#C2DC#,
                    16#AC04#])
             & "|"
             & UTF8 ([16#C77C#, 16#BCF8#, 16#20#, 16#C2DC#,
                      16#AC04#])
             & "|Asia/Tokyo",
           "fixed zone skeleton names localize Korean names");
   Assert (Rendered (Runtime, "en", "utc_zone_widths", Args) =
             "Z|+00:00|UTC",
           "time zone skeleton widths distinguish zero x from X/Z");
   Assert (Rendered (Runtime, "fr", "utc_long_zone", Args) =
             "temps universel coordonn" & U (16#E9#),
           "time-zone formatter uses generated French UTC display name");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:07+02:00");
   Assert (Rendered (Runtime, "en", "full_skeleton", Args) =
             "AD 2024 Q1 060 9 5 5 Thu in the evening 11:30:7.0 84607000 +0200",
           "expanded date/time skeleton fields render deterministically");
   Assert (Rendered (Runtime, "en", "datetime_skeleton", Args) =
             "2024 2 29 21:30:07",
           "datetime skeleton combines date and time fields");
   I18N.Arguments.Set
     (Args, "instant", "2024-02-29T23:30:07.987654321+02:00");
   Assert (Rendered (Runtime, "en", "datetime_fraction", Args) =
             "21:30:07.987|77407987654321",
           "datetime skeleton renders fractional instant seconds");
   I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:07+02:00");
   Assert (Rendered (Runtime, "en", "datetime_comma_literal_zone", Args) =
             "2024,02",
           "datetime skeleton splits zone option after quoted comma literals");
   Assert (Rendered (Runtime, "en", "datetime_literal", Args) =
             "2024-02-29T21:30:07 Z",
           "datetime skeleton renders quoted literals and zone offset");
   Assert (Rendered (Runtime, "ar", "datetime_skeleton", Args) =
             U (16#662#) & U (16#660#) & U (16#662#) & U (16#664#) & " "
             & U (16#662#) & " " & U (16#662#) & U (16#669#) & " "
             & U (16#662#) & U (16#661#) & ":" & U (16#663#)
             & U (16#660#) & ":" & U (16#660#) & U (16#667#),
           "datetime skeleton localizes digits");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "datetime_skeleton", Args) =
             "2024 2 29 21:30:07",
           "latn numbering-system extension overrides Arabic datetime digits");
   Assert (Rendered (Runtime, "ar-u-nu-deva", "datetime_skeleton", Args) =
             U (16#968#) & U (16#966#) & U (16#968#) & U (16#96A#) & " "
             & U (16#968#) & " " & U (16#968#) & U (16#96F#) & " "
             & U (16#968#) & U (16#967#) & ":" & U (16#969#)
             & U (16#966#) & ":" & U (16#966#) & U (16#96D#),
           "numbering-system extension overrides Arabic datetime digits");
   Assert (Rendered (Runtime, "en-u-nu-arab", "datetime_skeleton", Args) =
             U (16#662#) & U (16#660#) & U (16#662#) & U (16#664#) & " "
             & U (16#662#) & " " & U (16#662#) & U (16#669#) & " "
             & U (16#662#) & U (16#661#) & ":" & U (16#663#)
             & U (16#660#) & ":" & U (16#660#) & U (16#667#),
           "arab numbering-system extension localizes datetime digits");
   Assert (Rendered (Runtime, "en-u-nu-arabext", "datetime_skeleton", Args) =
             U (16#6F2#) & U (16#6F0#) & U (16#6F2#) & U (16#6F4#) & " "
             & U (16#6F2#) & " " & U (16#6F2#) & U (16#6F9#) & " "
             & U (16#6F2#) & U (16#6F1#) & ":" & U (16#6F3#)
             & U (16#6F0#) & ":" & U (16#6F0#) & U (16#6F7#),
           "arabext numbering-system extension localizes datetime digits");
   Assert (Rendered (Runtime, "en-u-nu-thai", "datetime_skeleton", Args) =
             U (16#E52#) & U (16#E50#) & U (16#E52#) & U (16#E54#) & " "
             & U (16#E52#) & " " & U (16#E52#) & U (16#E59#) & " "
             & U (16#E52#) & U (16#E51#) & ":" & U (16#E53#)
             & U (16#E50#) & ":" & U (16#E50#) & U (16#E57#),
           "thai numbering-system extension localizes datetime digits");
   Assert (Rendered (Runtime, "fa", "datetime_skeleton", Args) =
             U (16#6F2#) & U (16#6F0#) & U (16#6F2#) & U (16#6F4#) & " "
             & U (16#6F2#) & " " & U (16#6F2#) & U (16#6F9#) & " "
             & U (16#6F2#) & U (16#6F1#) & ":" & U (16#6F3#)
             & U (16#6F0#) & ":" & U (16#6F0#) & U (16#6F7#),
           "datetime skeleton localizes Persian digits");
   Assert (Rendered (Runtime, "th", "datetime_skeleton", Args) =
             U (16#E52#) & U (16#E50#) & U (16#E52#) & U (16#E54#) & " "
             & U (16#E52#) & " " & U (16#E52#) & U (16#E59#) & " "
             & U (16#E52#) & U (16#E51#) & ":" & U (16#E53#)
             & U (16#E50#) & ":" & U (16#E50#) & U (16#E57#),
           "datetime skeleton localizes Thai digits");
   Assert (Rendered (Runtime, "en-u-nu-deva", "datetime_skeleton", Args) =
             U (16#968#) & U (16#966#) & U (16#968#) & U (16#96A#) & " "
             & U (16#968#) & " " & U (16#968#) & U (16#96F#) & " "
             & U (16#968#) & U (16#967#) & ":" & U (16#969#)
             & U (16#966#) & ":" & U (16#966#) & U (16#96D#),
           "numbering-system extension localizes datetime to Devanagari digits");
   Assert (Rendered (Runtime, "en-u-nu-beng", "datetime_skeleton", Args) =
             U (16#9E8#) & U (16#9E6#) & U (16#9E8#) & U (16#9EA#) & " "
             & U (16#9E8#) & " " & U (16#9E8#) & U (16#9EF#) & " "
             & U (16#9E8#) & U (16#9E7#) & ":" & U (16#9E9#)
             & U (16#9E6#) & ":" & U (16#9E6#) & U (16#9ED#),
           "numbering-system extension localizes datetime to Bengali digits");
   Assert (Rendered (Runtime, "bn", "datetime_skeleton", Args) =
             U (16#9E8#) & U (16#9E6#) & U (16#9E8#) & U (16#9EA#) & " "
             & U (16#9E8#) & " " & U (16#9E8#) & U (16#9EF#) & " "
             & U (16#9E8#) & U (16#9E7#) & ":" & U (16#9E9#)
             & U (16#9E6#) & ":" & U (16#9E6#) & U (16#9ED#),
           "Bengali locale localizes datetime skeleton digits");
   Assert (Status_Of (Runtime, "en", "bad_zone", Args) =
             I18N.Result.Invalid_Argument,
           "unknown time zone identifiers are invalid arguments");

   I18N.Runtime.Render_Into
     (Runtime, "de", "when", Args, Target, Last, Status);
   Assert (Status = I18N.Result.Success,
           "bounded date/time render succeeds");
   Assert (Target (1 .. Last) = "Am 29.02.2024 um 09:05:07",
           "bounded date/time render matches materialized render");
end Test_Date_Time_Rendering;
