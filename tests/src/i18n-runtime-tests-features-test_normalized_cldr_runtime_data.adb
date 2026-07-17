separate (I18N.Runtime.Tests.Features)
procedure Test_Normalized_CLDR_Runtime_Data
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
   Data    : I18N.Runtime.Data_Load_Result;
begin
   I18N.Runtime.Clear_Runtime_Data;
   I18N.Runtime.Load_Text
     (Runtime, "normalized-cldr",
      "default_locale = en" & ASCII.LF
      & "en.num = ""{v, number}""" & ASCII.LF
      & "xy.num = ""{v, number}""" & ASCII.LF
      & "xy.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "xy.ordinal_words = ""{v, number, ::ordinal-words}"""
      & ASCII.LF
      & "xy.day = ""{d, date, long}""" & ASCII.LF
      & "rd.day = ""{d, date, short}""" & ASCII.LF
      & "xy.era = ""{d, date, ::Gy}""" & ASCII.LF
      & "pc.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "nh.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "pc-u-ca-gregory.calendar = ""{d, date, ::GyyyyMMdd}"""
      & ASCII.LF
      & "xy.quarter = ""{d, date, ::QQQQ}""" & ASCII.LF
      & "xy.short_quarter = ""{d, date, ::QQQ}""" & ASCII.LF
      & "xy.narrow_quarter = ""{d, date, ::QQQQQ}""" & ASCII.LF
      & "qn.quarter = ""{d, date, ::QQQQ}""" & ASCII.LF
      & "qn.short_quarter = ""{d, date, ::QQQ}""" & ASCII.LF
      & "qn.narrow_quarter = ""{d, date, ::QQQQQ}""" & ASCII.LF
      & "xy.zone_name = ""{i, time, ::zzzz, Norm/Zone}"""
      & ASCII.LF
      & "xy.zone_location = ""{i, time, ::VVV'|'VVVV, Norm/Zone}"""
      & ASCII.LF
      & "xy.zone_short = ""{i, time, ::z'|'v, Norm/Zone}"""
      & ASCII.LF
      & "tz.default_time = ""{i, time, ::HH'_'mm}""" & ASCII.LF
      & "tz.default_zone = ""{i, time, ::zzzz}""" & ASCII.LF
      & "tz.explicit_time = ""{i, time, ::HH'_'mm, UTC}""" & ASCII.LF
      & "ns.num = ""{v, number}""" & ASCII.LF
      & "ns.date = ""{d, date, ::yyyyMMdd}""" & ASCII.LF
      & "ns.time = ""{t, time, ::HHmm}""" & ASCII.LF
      & "ns-u-nu-latn.num = ""{v, number}""" & ASCII.LF
      & "hc.pref = ""{t, time, ::j}""" & ASCII.LF
      & "hc-u-hc-h24.pref = ""{t, time, ::j}""" & ASCII.LF
      & "wd.weekday = ""{d, date, ::e'/'ee'/'c'/'cc}""" & ASCII.LF
      & "wd.week = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "xy.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "xy.relative = ""{n, relative, day}""" & ASCII.LF
      & "xy.list = ""{l, list}""" & ASCII.LF
      & "xy.money_name = ""{m, currency, XCL/name}""" & ASCII.LF
      & "sf.money = ""{m, currency, XCL}""" & ASCII.LF
      & "xy.items = ""{n, plural, zero {zero #} other {other #}}"""
      & ASCII.LF
      & "xy.rank = ""{n, selectordinal, two {two #} other {other #}}"""
      & ASCII.LF,
      Result);
   Assert (Result.Status = I18N.Runtime.Loaded,
           "normalized CLDR runtime-data catalog loads");

   Data := I18N.Runtime.Load_Data_Text
     ("normalized-cldr-data",
      "decimal_text|xy|!" & ASCII.LF
      & "group_text|xy|:" & ASCII.LF
      & "digits_codepoints|xy|0030,0031,0032,0033,0034,0035,0036,0037,0038,0039"
      & ASCII.LF
      & "names_hex|month_full|xy|1|004A0061006E0075~0046006500620075"
      & "~004D006100720075~0041007000720075~004D006100790075"
      & "~004A0075006E0075~004A0075006C0075~0041007500670075"
      & "~0053006500700075~004F006300740075~004E006F00760075"
      & "~0044006500630075"
      & ASCII.LF
      & "names_hex|quarter_full|qn|1|0051006E002000510031"
      & "~0051006E002000510032~0051006E002000510033"
      & "~0051006E002000510034" & ASCII.LF
      & "names_hex|quarter_short|qn|1|0051004E0031"
      & "~0051004E0032~0051004E0033~0051004E0034"
      & ASCII.LF
      & "names_hex|quarter_narrow|qn|1|004E0031"
      & "~004E0032~004E0033~004E0034"
      & ASCII.LF
      & "locale_text|xy|date_style.long|4D4D4D4D2720276427202779797979"
      & ASCII.LF
      & "locale_text|pc|default_calendar|7065727369616E" & ASCII.LF
      & "locale_text|nh|default_calendar|686562726577" & ASCII.LF
      & "locale_text|xy|era.gregorian.ad|58594144" & ASCII.LF
      & "locale_text|xy|quarter.2|587951756172746572" & ASCII.LF
      & "locale_text|xy|quarter_short.2|585132" & ASCII.LF
      & "locale_text|xy|quarter_narrow.2|5832" & ASCII.LF
      & "locale_text|xy|timezone_display.Norm/Zone|5859205A6F6E65"
      & ASCII.LF
      & "locale_text|xy|timezone_exemplar.Norm/Zone|58592043697479"
      & ASCII.LF
      & "locale_text|xy|timezone_location_pattern|5859207B307D205A6F6E65"
      & ASCII.LF
      & "locale_text|xy|timezone_short.Norm/Zone|585953"
      & ASCII.LF
      & "locale_text|xy|timezone_generic_short.Norm/Zone|585947"
      & ASCII.LF
      & "locale_text|tz|default_timezone|417369612F4B6174686D616E6475"
      & ASCII.LF
      & "locale_text|tz|timezone_display.Asia/Kathmandu|545A2044656661756C74"
      & ASCII.LF
      & "locale_text|ns|default_numbering_system|61726162" & ASCII.LF
      & "locale_text|hc|default_hour_cycle|683131" & ASCII.LF
      & "locale_text|wd|first_day_of_week|667269" & ASCII.LF
      & "locale_text|wd|first_week_min_days|37" & ASCII.LF
      & "locale_text|xy|unit.meter.unit-width-full-name.one|78796D65746572"
      & ASCII.LF
      & "locale_text|xy|unit.meter.unit-width-full-name.few|78796665776D6574657273"
      & ASCII.LF
      & "locale_text|xy|unit.meter.unit-width-full-name.other|78796D6574657273"
      & ASCII.LF
      & "locale_text|xy|relative_current.day|7879746F646179"
      & ASCII.LF
      & "locale_text|xy|relative_unit.day.few|787966657764617973"
      & ASCII.LF
      & "locale_text|xy|relative_unit.day.other|787964617973"
      & ASCII.LF
      & "locale_text|xy|relative_prefix.future|616674657220"
      & ASCII.LF
      & "locale_text|xy|relative_suffix.future|206C61746572"
      & ASCII.LF
      & "locale_text|xy|list_item_separator|203B20" & ASCII.LF
      & "locale_text|xy|list_pair_separator|202A20" & ASCII.LF
      & "locale_text|xy|list_start_separator|205E20" & ASCII.LF
      & "locale_text|xy|list_middle_separator|207E20" & ASCII.LF
      & "locale_text|xy|list_final_separator|202B20" & ASCII.LF
      & "currency_text|XCL|3|5|XC$|X$|test credits" & ASCII.LF
      & "raw|currency_name_payload|xy|XCL:7A65726F,6F6E65,74776F,666577,6D616E79,6F74686572"
      & ASCII.LF
      & "raw|day_month_year|rd" & ASCII.LF
      & "raw|symbol_first|sf" & ASCII.LF
      & "plural_rule|cardinal|xy|ar" & ASCII.LF
      & "plural_rule|ordinal|xy|en-ordinal" & ASCII.LF
      & "rbnf_text|xy|cardinal|2|787974776F" & ASCII.LF
      & "rbnf_text|xy|cardinal|3|78797468726565" & ASCII.LF
      & "rbnf_text|xy|cardinal|5|7879666976653B" & ASCII.LF
      & "rbnf_text|xy|%spellout-cardinal|11|7879656C6576656E"
      & ASCII.LF
      & "rbnf_text|xy|cardinal|12|78797477656C7665" & ASCII.LF
      & "<ldml locale=""xy"">" & ASCII.LF
      & "<rbnf>" & ASCII.LF
      & "<rulesetGrouping type=""SpelloutRules"">" & ASCII.LF
      & "<ruleset type=""%spellout-cardinal"">" & ASCII.LF
      & "<rbnfrule value=""13"">xythirteen</rbnfrule>"
      & ASCII.LF
      & "<rbnfrule value=""2,000"">&lt;&lt; xythousands[ &gt;&gt;&gt;]</rbnfrule>"
      & ASCII.LF
      & "<rbnfrule>3,000: &lt;&lt; xymyriads[ &gt;&gt;&gt;];</rbnfrule>"
      & ASCII.LF
      & "<rbnfrule radix=""100"">4,000: &lt;&lt; xyhundreds[ &gt;&gt;&gt;];</rbnfrule>"
      & ASCII.LF
      & "<rbnfrule>" & ASCII.LF
      & "5,000:" & ASCII.LF
      & "&lt;&lt; xyblocks[ &gt;&gt;&gt;];" & ASCII.LF
      & "</rbnfrule>" & ASCII.LF
      & "</ruleset>" & ASCII.LF
      & "</rulesetGrouping>" & ASCII.LF
      & "</rbnf>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "rbnf_text|xy|cardinal|8|78796569676874" & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|40|7879666F7274795B2D3E3E5D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|14|7879666F75727465656E"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|30|"
      & "787974686972747924286F7264696E616C2C6F6E657B73747D"
      & "74776F7B6E647D6665777B72647D6F746865727B74687D2924"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|70|7879736576656E74795B2DE28692E286925D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|80|78796569676874795B2D3E3E5D3B"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|100>|3C3C20787968756E64726564735B203E3E3E5D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|400/10|3C3C20787974656E735B203E3E3E5D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|700|"
      & "E28690257370656C6C6F75742D63617264696E616CE28690"
      & "2078796E616D65645B20E28692257370656C6C6F75742D"
      & "63617264696E616CE286925D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|800|"
      & "3C257370656C6C6F75742D63617264696E616C3C20"
      & "787961736369696E616D655B203E257370656C6C6F75"
      & "742D63617264696E616C3E5D"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|0.x|78797A65726F203E3E"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|x.0|3C3C20787977686F6C65"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|" & U (16#2212#)
      & "x|78796E6567203E3E3E" & ASCII.LF
      & "rbnf_text|xy|cardinal|-2|78796D696E75732D74776F"
      & ASCII.LF
      & "rbnf_text|xy|cardinal|-2.3|78796D696E75732D74776F2D706F696E742D7468726565"
      & ASCII.LF
      & "rbnf_text|xy|spellout-cardinal-verbose|7|7879736576656E2D766572626F7365"
      & ASCII.LF
      & "rbnf_text|xy|ordinal|2|78797365636F6E64" & ASCII.LF
      & "rbnf_text|xy|ordinal|-2|78796D696E75732D7365636F6E64"
      & ASCII.LF
      & "rbnf_text|xy|ordinal|-2.3|78796D696E75732D7365636F6E642D706F696E742D7468726565"
      & ASCII.LF
      & "rbnf_text|xy|spellout-ordinal-feminine|7|7879736576656E74682D66656D696E696E65"
      & ASCII.LF
      & "rbnf_text|xy|decimal_separator||7879706F696E74" & ASCII.LF
      & "timezone.Norm/Zone.base_offset_minutes = 105" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Data_Loaded,
           "normalized CLDR runtime data loads");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "xy", "num", Args) = "1:234!5",
           "normalized CLDR symbols feed number formatting");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xytwo",
           "normalized CLDR RBNF rows feed spellout formatting");
   I18N.Arguments.Set (Args, "v", "5");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyfive",
           "normalized CLDR exact RBNF rows ignore trailing semicolons");
   I18N.Arguments.Set (Args, "v", "11");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyeleven",
           "normalized CLDR RBNF rows normalize percent rule-set prefixes");
   I18N.Arguments.Set (Args, "v", "13");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xythirteen",
           "LDML CLDR RBNF ruleset containers feed inherited rule-set rows");
   I18N.Arguments.Set (Args, "v", "14");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyfourteen",
           "normalized literal RBNF rule rows feed exact spellout rows");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "xy", "ordinal_words", Args) = "xysecond",
           "normalized CLDR RBNF rows feed ordinal-word formatting");
   I18N.Arguments.Set (Args, "v", "-2");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyminus-two",
           "normalized CLDR RBNF rows accept exact signed values");
   Assert (Rendered (Runtime, "xy", "ordinal_words", Args) =
             "xyminus-second",
           "normalized CLDR ordinal RBNF rows accept exact signed values");
   I18N.Arguments.Set (Args, "v", "42");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyforty-xytwo",
           "normalized CLDR RBNF rule rows compose remainders");
   I18N.Arguments.Set (Args, "v", "31");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xythirtyst",
           "normalized CLDR RBNF plural-affix expressions use ordinal categories");
   I18N.Arguments.Set (Args, "v", "72");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyseventy-xytwo",
           "normalized CLDR RBNF arrow substitutions are normalized");
   I18N.Arguments.Set (Args, "v", "82");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyeighty-xytwo",
           "normalized CLDR RBNF rule rows ignore trailing semicolons");
   I18N.Arguments.Set (Args, "v", "123");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xytwelve xyhundreds xythree",
           "normalized CLDR RBNF trailing divisor markers compose with reduced divisor");
   I18N.Arguments.Set (Args, "v", "402");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyforty xytens xytwo",
           "normalized CLDR RBNF rule descriptors honor explicit divisors");
   I18N.Arguments.Set (Args, "v", "702");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyseven-verbose xynamed xytwo",
           "normalized CLDR RBNF named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "802");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyeight xyasciiname xytwo",
           "normalized CLDR RBNF ASCII named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "2002");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xytwo xythousands xytwo",
           "LDML CLDR grouped RBNF rule descriptors feed spellout composition");
   I18N.Arguments.Set (Args, "v", "3002");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xythree xymyriads xytwo",
           "LDML CLDR inline RBNF descriptors feed spellout composition");
   I18N.Arguments.Set (Args, "v", "4002");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyforty xyhundreds xytwo",
           "LDML CLDR inline RBNF descriptors honor radix attributes");
   I18N.Arguments.Set (Args, "v", "5002");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyfive xyblocks xytwo",
           "multi-line LDML CLDR inline RBNF descriptors compose");
   I18N.Arguments.Set (Args, "v", "0.3");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyzero xythree",
           "normalized CLDR RBNF 0.x decimal rules compose fraction text");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xytwo xywhole",
           "normalized CLDR RBNF x.0 decimal rules compose integer text");
   I18N.Arguments.Set (Args, "v", "2.3");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xytwo xypoint xythree",
           "normalized CLDR RBNF rows feed decimal spellout");
   I18N.Arguments.Set (Args, "v", "-2.3");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyminus-two-point-three",
           "normalized CLDR RBNF decimal rows override full decimal spellout");
   Assert (Rendered (Runtime, "xy", "ordinal_words", Args) =
             "xyminus-second-point-three",
           "normalized CLDR ordinal RBNF decimal rows override exact ordinal spellout");
   I18N.Arguments.Set (Args, "v", "-2.4");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyminus-two xypoint four",
           "normalized CLDR signed RBNF rows feed negative decimal spellout");
   I18N.Arguments.Set (Args, "v", "-4");
   Assert (Rendered (Runtime, "xy", "words", Args) = "xyneg four",
           "normalized CLDR RBNF rows accept Unicode minus x descriptors");
   I18N.Arguments.Set (Args, "v", "7");
   Assert (Rendered (Runtime, "xy", "words", Args) =
             "xyseven-verbose",
           "normalized CLDR RBNF cardinal aliases feed spellout formatting");
   Assert (Rendered (Runtime, "xy", "ordinal_words", Args) =
             "xyseventh-feminine",
           "normalized CLDR RBNF ordinal aliases feed ordinal-word formatting");

   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "xy", "day", Args) = "Janu 4 2026",
           "normalized CLDR month names feed date formatting");
   Assert (Rendered (Runtime, "rd", "day", Args) = "04.01.26",
           "normalized CLDR date-order rows feed date style formatting");
   Assert (Rendered (Runtime, "xy", "era", Args) = "XYAD 2026",
           "normalized CLDR era names feed date skeleton formatting");
   I18N.Arguments.Set (Args, "d", "2024-03-20");
   Assert (Rendered (Runtime, "pc", "calendar", Args) = "AP 1403 01 01",
           "normalized CLDR default calendar preferences feed date formatting");
   Assert (Rendered (Runtime, "pc-u-ca-gregory", "calendar", Args) =
             "AD 2024 03 20",
           "explicit calendar extensions override runtime default calendars");
   I18N.Arguments.Set (Args, "d", "2023-09-16");
   Assert (Rendered (Runtime, "nh", "calendar", Args) = "AM 5784 01 01",
           "normalized CLDR Hebrew calendar preferences feed date formatting");
   I18N.Arguments.Set (Args, "d", "2026-04-04");
   Assert (Rendered (Runtime, "xy", "quarter", Args) = "XyQuarter",
           "normalized CLDR quarter names feed date skeleton formatting");
   Assert (Rendered (Runtime, "xy", "short_quarter", Args) = "XQ2",
           "normalized CLDR abbreviated quarter names feed date skeleton formatting");
   Assert (Rendered (Runtime, "xy", "narrow_quarter", Args) = "X2",
           "normalized CLDR narrow quarter names feed date skeleton formatting");
   Assert (Rendered (Runtime, "qn", "quarter", Args) = "Qn Q2",
           "normalized CLDR quarter names_hex rows feed date skeleton formatting");
   Assert (Rendered (Runtime, "qn", "short_quarter", Args) = "QN2",
           "normalized CLDR abbreviated quarter names_hex rows feed date skeleton formatting");
   Assert (Rendered (Runtime, "qn", "narrow_quarter", Args) = "N2",
           "normalized CLDR quarter_narrow names_hex rows feed date skeleton formatting");

   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "xy", "zone_name", Args) = "XY Zone",
           "normalized CLDR zone display names feed time skeleton formatting");
   Assert (Rendered (Runtime, "xy", "zone_location", Args) =
             "XY City|XY XY City Zone",
           "normalized CLDR zone exemplar names feed time skeleton formatting");
   Assert (Rendered (Runtime, "xy", "zone_short", Args) = "XYS|XYG",
           "normalized CLDR short zone names feed time skeleton formatting");
   Assert (Rendered (Runtime, "tz", "default_time", Args) = "05_45",
           "normalized CLDR default time zones feed instant conversion");
   Assert (Rendered (Runtime, "tz", "default_zone", Args) = "TZ Default",
           "normalized CLDR default time zones feed zone-name skeletons");
   Assert (Rendered (Runtime, "tz", "explicit_time", Args) = "00_00",
           "explicit time-zone options override runtime default time zones");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert
     (Rendered (Runtime, "ns", "num", Args)
      = U (16#661#) & "," & U (16#662#) & U (16#663#)
        & U (16#664#) & "." & U (16#665#),
      "normalized CLDR default numbering systems feed number digits");
   Assert
     (Rendered (Runtime, "ns-u-nu-latn", "num", Args) = "1,234.5",
      "explicit numbering-system extensions override runtime defaults");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert
     (Rendered (Runtime, "ns", "date", Args)
      = U (16#662#) & U (16#660#) & U (16#662#) & U (16#666#)
        & " " & U (16#660#) & U (16#661#)
        & " " & U (16#660#) & U (16#664#),
      "normalized CLDR default numbering systems feed date digits");
   I18N.Arguments.Set (Args, "t", "09:05");
   Assert
     (Rendered (Runtime, "ns", "time", Args)
      = U (16#660#) & U (16#669#) & ":" & U (16#660#) & U (16#665#),
      "normalized CLDR default numbering systems feed time digits");
   I18N.Arguments.Set (Args, "t", "00:05");
   Assert (Rendered (Runtime, "hc", "pref", Args) = "0 AM",
           "normalized CLDR default hour cycles feed preferred-hour skeletons");
   Assert (Rendered (Runtime, "hc-u-hc-h24", "pref", Args) = "24",
           "explicit hour-cycle extensions override normalized defaults");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "wd", "weekday", Args) = "3/03/3/03",
           "normalized CLDR week data feeds numeric weekday fields");
   Assert (Rendered (Runtime, "wd", "week", Args) = "2026/1/1",
           "normalized CLDR week min-days feeds week-year skeleton fields");

   I18N.Arguments.Set (Args, "v", "1.0");
   Assert (Rendered (Runtime, "xy", "unit", Args) = "1!0 xymeter",
           "normalized CLDR singular unit names feed unit formatting");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "xy", "unit", Args) = "2!0 xymeters",
           "normalized CLDR plural unit names feed unit formatting");
   I18N.Arguments.Set (Args, "v", "3.0");
   Assert (Rendered (Runtime, "xy", "unit", Args) = "3!0 xyfewmeters",
           "normalized CLDR few-count unit names feed unit formatting");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "xy", "relative", Args) = "xytoday",
           "normalized CLDR current relative names feed relative formatting");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "xy", "relative", Args) =
             "after 2 xydays later",
           "normalized CLDR relative patterns feed relative formatting");
   I18N.Arguments.Set (Args, "n", "3");
   Assert (Rendered (Runtime, "xy", "relative", Args) =
             "after 3 xyfewdays later",
           "normalized CLDR few-count relative unit names feed relative formatting");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "xy", "list", Args) = "red ^ green + blue",
           "normalized CLDR start/final list patterns feed list formatting");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "xy", "list", Args) = "red * green",
           "normalized CLDR two-item list patterns feed list formatting");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "xy", "list", Args) =
             "red ^ green ~ blue + gold",
           "normalized CLDR middle list patterns feed list formatting");

   I18N.Arguments.Set (Args, "m", "2");
   Assert (Rendered (Runtime, "xy", "money_name", Args) = "2!000 two",
           "normalized CLDR currency metadata and name payload feed currency formatting");
   Assert (Rendered (Runtime, "sf", "money", Args) = "XC$2.000",
           "normalized CLDR currency placement rows feed currency formatting");

   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "xy", "items", Args) = "zero 0",
           "normalized CLDR cardinal family rows feed plural formatting");

   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "xy", "rank", Args) = "two 2",
           "normalized CLDR ordinal family rows feed selectordinal formatting");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-normalized-cldr-data",
      "decimal_text|xy" & ASCII.LF
      & "locale_text|ns|default_numbering_system|726F6D616E" & ASCII.LF
      & "locale_text|hc|default_hour_cycle|683235" & ASCII.LF
      & "locale_text|wd|first_day_of_week|666F6F" & ASCII.LF
      & "locale_text|wd|first_week_min_days|38" & ASCII.LF
      & "plural_rule|cardinal|xy|not-a-family" & ASCII.LF
      & "plural_rule_text|cardinal|xy|one|n is {1}" & ASCII.LF
      & "rbnf_text|xy|cardinal|-1000000000|626164" & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|40/10|6C69746572616C" & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|41|3C253C20626164" & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|100>>>>>>>>>>|3C3C20626164"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|42|E2869025E2869020626164"
      & ASCII.LF
      & "rbnf_rule_text|xy|cardinal|43|"
      & "787924286F7264696E616C2C6F6E657B73747D2924"
      & ASCII.LF
      & "<ldml locale=""xy"">" & ASCII.LF
      & "<rbnf>" & ASCII.LF
      & "<ruleset>" & ASCII.LF
      & "<rbnfrule value=""14"">bad</rbnfrule>" & ASCII.LF
      & "</ruleset>" & ASCII.LF
      & "</rbnf>" & ASCII.LF
      & "</ldml>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed normalized CLDR rows are rejected");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "xy", "num", Args) = "1:234!5",
           "failed normalized CLDR load leaves previous data intact");

   I18N.Runtime.Clear_Runtime_Data;
   I18N.Runtime.Finalize (Runtime);
exception
   when others =>
      I18N.Runtime.Clear_Runtime_Data;
      I18N.Runtime.Finalize (Runtime);
      raise;
end Test_Normalized_CLDR_Runtime_Data;
