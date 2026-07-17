separate (I18N.Runtime.Tests.Features)
procedure Test_Runtime_Data_Overrides
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
     (Runtime, "base",
      "default_locale = en" & ASCII.LF
      & "en.num = ""{v, number}""" & ASCII.LF
      & "en.day = ""{d, date, long}""" & ASCII.LF
      & "en.short_day = ""{d, date, short}""" & ASCII.LF
      & "en.clock = ""{t, time, short}""" & ASCII.LF
      & "en.instant = ""{i, time, ::HH'_'mm, Example/Zone}""" & ASCII.LF
      & "en.ldml_instant = ""{i, time, ::HH'_'mm, Ldml/Zone}"""
      & ASCII.LF
      & "en.ldml_compact_instant = ""{i, time, ::HH'_'mm, Compact/Zone}"""
      & ASCII.LF
      & "en.ldml_hour_instant = ""{i, time, ::HH'_'mm, Hour/Zone}"""
      & ASCII.LF
      & "en.ldml_single_hour_instant = ""{i, time, ::HH'_'mm, SingleHour/Zone}"""
      & ASCII.LF
      & "en.ldml_single_compact_instant = ""{i, time, ::HH'_'mm, SingleCompact/Zone}"""
      & ASCII.LF
      & "en.ldml_single_colon_instant = ""{i, time, ::HH'_'mm, SingleColon/Zone}"""
      & ASCII.LF
      & "en.ldml_negative_single_hour_instant = ""{i, time, ::HH'_'mm, NegativeSingleHour/Zone}"""
      & ASCII.LF
      & "en.ldml_negative_single_colon_instant = ""{i, time, ::HH'_'mm, NegativeSingleColon/Zone}"""
      & ASCII.LF
      & "en.ldml_zulu_instant = ""{i, time, ::HH'_'mm, Zulu/Zone}"""
      & ASCII.LF
      & "en.ldml_utc_word_instant = ""{i, time, ::HH'_'mm, UtcWord/Zone}"""
      & ASCII.LF
      & "en.ldml_gmt_word_instant = ""{i, time, ::HH'_'mm, GmtWord/Zone}"""
      & ASCII.LF
      & "en.ldml_lower_zulu_instant = ""{i, time, ::HH'_'mm, LowerZulu/Zone}"""
      & ASCII.LF
      & "en.ldml_lower_utc_word_instant = ""{i, time, ::HH'_'mm, LowerUtcWord/Zone}"""
      & ASCII.LF
      & "en.ldml_lower_gmt_word_instant = ""{i, time, ::HH'_'mm, LowerGmtWord/Zone}"""
      & ASCII.LF
      & "en.tzdb_instant = ""{i, time, ::HH'_'mm, Tzdb/Fixed}"""
      & ASCII.LF
      & "en.tzdb_compact_instant = ""{i, time, ::HH'_'mm, Tzdb/Compact}"""
      & ASCII.LF
      & "en.tzdb_single_hour_instant = ""{i, time, ::HH'_'mm, Tzdb/SingleHour}"""
      & ASCII.LF
      & "en.tzdb_single_compact_instant = ""{i, time, ::HH'_'mm, Tzdb/SingleCompact}"""
      & ASCII.LF
      & "en.tzdb_single_colon_instant = ""{i, time, ::HH'_'mm, Tzdb/SingleColon}"""
      & ASCII.LF
      & "en.tzdb_negative_single_hour_instant = ""{i, time, ::HH'_'mm, Tzdb/NegativeSingleHour}"""
      & ASCII.LF
      & "en.tzdb_negative_single_compact_instant = ""{i, time, ::HH'_'mm, Tzdb/NegativeSingleCompact}"""
      & ASCII.LF
      & "en.tzdb_zulu_instant = ""{i, time, ::HH'_'mm, Tzdb/Zulu}"""
      & ASCII.LF
      & "en.tzdb_utc_word_instant = ""{i, time, ::HH'_'mm, Tzdb/UTCWord}"""
      & ASCII.LF
      & "en.tzdb_gmt_word_instant = ""{i, time, ::HH'_'mm, Tzdb/GMTWord}"""
      & ASCII.LF
      & "en.tzdb_lower_zulu_instant = ""{i, time, ::HH'_'mm, Tzdb/LowerZulu}"""
      & ASCII.LF
      & "en.tzdb_lower_utc_word_instant = ""{i, time, ::HH'_'mm, Tzdb/LowerUTCWord}"""
      & ASCII.LF
      & "en.tzdb_lower_gmt_word_instant = ""{i, time, ::HH'_'mm, Tzdb/LowerGMTWord}"""
      & ASCII.LF
      & "en.tzdb_alias_instant = ""{i, time, ::HH'_'mm, Tzdb/Alias}"""
      & ASCII.LF
      & "en.tzdb_seconds_instant = ""{i, time, ::HH'_'mm'_'ss, Tzdb/Seconds}"""
      & ASCII.LF
      & "en.tzdb_seconds_alias_instant = ""{i, time, ::HH'_'mm'_'ss, Tzdb/SecondsAlias}"""
      & ASCII.LF
      & "en.tzdb_direct_save_seconds_instant = ""{i, time, ::HH'_'mm'_'ss, Tzdb/DirectSaveSeconds}"""
      & ASCII.LF
      & "en.tzdb_until_instant = ""{i, time, ::HH'_'mm, Tzdb/Until}"""
      & ASCII.LF
      & "en.tzdb_until_utc_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilUTC}"""
      & ASCII.LF
      & "en.tzdb_until_standard_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilStandard}"""
      & ASCII.LF
      & "en.tzdb_until_year_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilYear}"""
      & ASCII.LF
      & "en.tzdb_until_month_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilMonth}"""
      & ASCII.LF
      & "en.tzdb_until_day_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilDay}"""
      & ASCII.LF
      & "en.tzdb_until_last_weekday_instant = ""{i, time, ::HH'_'mm, Tzdb/UntilLastWeekday}"""
      & ASCII.LF
      & "en.tzdb_until_24_instant = ""{i, time, ::HH'_'mm, Tzdb/Until24}"""
      & ASCII.LF
      & "en.tzdb_direct_save_instant = ""{i, time, ::HH'_'mm, Tzdb/DirectSave}"""
      & ASCII.LF
      & "en.tzdb_direct_save_until_instant = ""{i, time, ::HH'_'mm, Tzdb/DirectSaveUntil}"""
      & ASCII.LF
      & "en.tzdb_rule_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleZone}"""
      & ASCII.LF
      & "en.tzdb_rule_max_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleMaxZone}"""
      & ASCII.LF
      & "en.tzdb_rule_standard_wall_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleStandardWallZone}"""
      & ASCII.LF
      & "en.tzdb_rule_out_of_order_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleOutOfOrderZone}"""
      & ASCII.LF
      & "en.tzdb_rule_year_carry_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleYearCarryZone}"""
      & ASCII.LF
      & "en.tzdb_rule_forward_instant = ""{i, time, ::HH'_'mm, Tzdb/RuleForwardZone}"""
      & ASCII.LF
      & "en.tzdb_rule_24_instant = ""{i, time, ::HH'_'mm, Tzdb/Rule24Zone}"""
      & ASCII.LF
      & "en.tzdb_rule_seconds_instant = ""{i, time, ::HH'_'mm'_'ss, Tzdb/RuleSecondsZone}"""
      & ASCII.LF
      & "en.tzdb_comment_instant = ""{i, time, ::HH'_'mm, Tzdb/Comment}"""
      & ASCII.LF
      & "en.tzdb_comment_alias_instant = ""{i, time, ::HH'_'mm, Tzdb/CommentAlias}"""
      & ASCII.LF
      & "en.tzdb_comment_until_instant = ""{i, time, ::HH'_'mm, Tzdb/CommentUntil}"""
      & ASCII.LF
      & "en.tzdb_comment_rule_instant = ""{i, time, ::HH'_'mm, Tzdb/CommentRuleZone}"""
      & ASCII.LF
      & "en.tzdb_case_until_instant = ""{i, time, ::HH'_'mm, Tzdb/CaseUntil}"""
      & ASCII.LF
      & "en.tzdb_case_rule_instant = ""{i, time, ::HH'_'mm, Tzdb/CaseRuleZone}"""
      & ASCII.LF
      & "zz.num = ""{v, number}""" & ASCII.LF
      & "zz.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "zz.ordinal_words = ""{v, number, ::ordinal-words}"""
      & ASCII.LF
      & "zz-REG.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "zz.money = ""{m, currency, XTS}""" & ASCII.LF
      & "zz.money_name = ""{m, currency, XTS/name}""" & ASCII.LF
      & "zz.day = ""{d, date, long}""" & ASCII.LF
      & "zz.era = ""{d, date, ::Gy}""" & ASCII.LF
      & "zz.short_day = ""{d, date, short}""" & ASCII.LF
      & "zz.clock = ""{t, time, short}""" & ASCII.LF
      & "zz.zone_name = ""{i, time, ::zzzz, Example/Zone}"""
      & ASCII.LF
      & "zz.zone_location = ""{i, time, ::VVV'|'VVVV, Example/Zone}"""
      & ASCII.LF
      & "zz.zone_short = ""{i, time, ::z'|'v, Example/Zone}"""
      & ASCII.LF
      & "zz.zone_offset = ""{i, time, ::OOOO, Example/Zone}"""
      & ASCII.LF
      & "zz.zone_zero = ""{i, time, ::XXXXX, UTC}""" & ASCII.LF
      & "gf.zone_offset = ""{i, time, ::OOOO, Example/Zone}"""
      & ASCII.LF
      & "gf.zone_zero = ""{i, time, ::XXXXX, UTC}""" & ASCII.LF
      & "zz.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "zz.relative = ""{n, relative, day}""" & ASCII.LF
      & "zz.list = ""{l, list}""" & ASCII.LF
      & "zz.items = ""{n, plural, zero {zero #} few {few #} other {other #}}"""
      & ASCII.LF
      & "zz.rank = ""{n, selectordinal, two {two #} other {other #}}"""
      & ASCII.LF
      & "ld.num = ""{v, number}""" & ASCII.LF
      & "ld.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "ld.ordinal_words = ""{v, number, ::ordinal-words}"""
      & ASCII.LF
      & "ld.percent = ""{v, number, ::percent}""" & ASCII.LF
      & "ld.permille = ""{v, number, ::permille}""" & ASCII.LF
      & "ld.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "ld.accounting = ""{v, number, ::sign-accounting}""" & ASCII.LF
      & "ld.scientific = ""{v, number, ::scientific}""" & ASCII.LF
      & "sy.num = ""{v, number}""" & ASCII.LF
      & "sy.percent = ""{v, number, ::percent}""" & ASCII.LF
      & "sy.permille = ""{v, number, ::permille}""" & ASCII.LF
      & "sy.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "sy.accounting = ""{v, number, ::sign-accounting}""" & ASCII.LF
      & "sy.scientific = ""{v, number, ::scientific}""" & ASCII.LF
      & "sc.num = ""{v, number}""" & ASCII.LF
      & "sc.percent = ""{v, number, ::percent}""" & ASCII.LF
      & "sc.permille = ""{v, number, ::permille}""" & ASCII.LF
      & "sc.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "sc.scientific = ""{v, number, ::scientific}""" & ASCII.LF
      & "sd.num = ""{v, number}""" & ASCII.LF
      & "xe.num = ""{v, number}""" & ASCII.LF
      & "xe.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "xq.num = ""{v, number}""" & ASCII.LF
      & "xq.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "xs.num = ""{v, number}""" & ASCII.LF
      & "xs.signed = ""{v, number, ::sign-always}""" & ASCII.LF
      & "ld.day = ""{d, date, long}""" & ASCII.LF
      & "ds.day = ""{d, date, short}""" & ASCII.LF
      & "dl.day = ""{d, date, medium}""" & ASCII.LF
      & "ld.era = ""{d, date, ::Gy}""" & ASCII.LF
      & "er.era = ""{d, date, ::Gy}""" & ASCII.LF
      & "ld.quarter = ""{d, date, ::QQQQ}""" & ASCII.LF
      & "ld.short_quarter = ""{d, date, ::QQQ}""" & ASCII.LF
      & "ld.narrow_quarter = ""{d, date, ::QQQQQ}""" & ASCII.LF
      & "dn.names = ""{d, date, ::MMMM'|'MMM'|'EEEE'|'EEE'|'QQQQ'|'QQQ'|'QQQQQ}"""
      & ASCII.LF
      & "dw.names = ""{d, date, ::MMM'|'EEE'|'QQQ'|'QQQQQ}"""
      & ASCII.LF
      & "dw.period_widths = ""{t, time, ::B'|'BBBB'|'BBBBB}""" & ASCII.LF
      & "sx.names = ""{d, date, ::MMMM'|'LLLL'|'MMMMM'|'LLLLL"
      & "'|'EEEE'|'cccc'|'EEEEE'|'ccccc'|'QQQQ'|'qqqq'|'QQQQQ"
      & "'|'qqqqq}"""
      & ASCII.LF
      & "ld.weekday_numeric = ""{d, date, ::e'/'ee'/'c'/'cc}"""
      & ASCII.LF
      & "ld.week_year = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "wa.weekday_numeric = ""{d, date, ::e'/'ee'/'c'/'cc}"""
      & ASCII.LF
      & "wa.week_year = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "wc.weekday_numeric = ""{d, date, ::e'/'ee'/'c'/'cc}"""
      & ASCII.LF
      & "wc.week_year = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "ld.period = ""{t, time, ::hha}""" & ASCII.LF
      & "dw.period = ""{t, time, ::hhBBBB}""" & ASCII.LF
      & "ts.clock = ""{t, time, short}""" & ASCII.LF
      & "tl.clock = ""{t, time, medium}""" & ASCII.LF
      & "ld.noon = ""{t, time, ::hhBBBB}""" & ASCII.LF
      & "ld.zone_name = ""{i, time, ::zzzz, Ldml/Zone}"""
      & ASCII.LF
      & "ld.zone_location = ""{i, time, ::VVV'|'VVVV, Ldml/Zone}"""
      & ASCII.LF
      & "ld.zone_short = ""{i, time, ::z'|'v, Ldml/Zone}"""
      & ASCII.LF
      & "ty.zone_name = ""{i, time, ::zzzz'|'z'|'v, Typed/Zone}"""
      & ASCII.LF
      & "za.zone_name = ""{i, time, ::zzzz, Alias/Zone}"""
      & ASCII.LF
      & "za.zone_location = ""{i, time, ::VVV'|'VVVV, Alias/Zone}"""
      & ASCII.LF
      & "za.zone_short = ""{i, time, ::z'|'v, Alias/Zone}"""
      & ASCII.LF
      & "rf.zone_location = ""{i, time, ::VVV'|'VVVV, Alias/Zone}"""
      & ASCII.LF
      & "ec.zone_location = ""{i, time, ::VVV'|'VVVV, Alias/Zone}"""
      & ASCII.LF
      & "zn.zone_name = ""{i, time, ::zzzz'|'z, Alias/Zone}"""
      & ASCII.LF
      & "zt.zone_name = ""{i, time, ::zzzz, Typed/Zone}"""
      & ASCII.LF
      & "zy.zone_name = ""{i, time, ::zzzz, America/New_York}"""
      & ASCII.LF
      & "rs.zone_name = ""{i, time, ::zzzz, Region/Zone}"""
      & ASCII.LF
      & "sa.zone_standard_alias = ""{i, time, ::z, Typed/Zone}"""
      & ASCII.LF
      & "sb.zone_standard_alias = ""{i, time, ::z, Typed/Zone}"""
      & ASCII.LF
      & "sc.zone_generic_alias = ""{i, time, ::v, Typed/Zone}"""
      & ASCII.LF
      & "se.zone_daylight_alias = ""{i, time, ::z, America/New_York}"""
      & ASCII.LF
      & "zs.zone_short = ""{i, time, ::z, Typed/Zone}"""
      & ASCII.LF
      & "zg.zone_generic = ""{i, time, ::v, Typed/Zone}"""
      & ASCII.LF
      & "zd.zone_daylight = ""{i, time, ::z, America/New_York}"""
      & ASCII.LF
      & "zc.zone_name = ""{i, time, ::zzzz'|'z'|'v, America/New_York}"""
      & ASCII.LF
      & "zc.zone_location = ""{i, time, ::VVV'|'VVVV, America/New_York}"""
      & ASCII.LF
      & "za.zone_time = ""{i, time, ::HH'_'mm, Alias/Zone}"""
      & ASCII.LF
      & "zo.zone_time = ""{i, time, ::HH'_'mm, Offset/Alias}"""
      & ASCII.LF
      & "ld.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "la.unit = ""{v, unit, meter}""" & ASCII.LF
      & "la.short_unit = ""{v, unit, liter/unit-width-short}""" & ASCII.LF
      & "la.pattern_unit = ""{v, unit, gram/unit-width-short}""" & ASCII.LF
      & "ut.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "ut.pattern_unit = ""{v, unit, mass-gram/unit-width-short}"""
      & ASCII.LF
      & "ud.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "un.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "en-UC.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "en-UC.short_unit = ""{v, unit, length-meter/unit-width-short}"""
      & ASCII.LF
      & "cu.rate = ""{v, unit, meter/unit-width-full-name/second}"""
      & ASCII.LF
      & "cs.rate = ""{v, unit, meter/unit-width-short/second}"""
      & ASCII.LF
      & "cp.rate = ""{v, unit, meter/unit-width-full-name/second}"""
      & ASCII.LF
      & "cp.short_rate = ""{v, unit, meter/unit-width-short/second}"""
      & ASCII.LF
      & "ld.relative = ""{n, relative, day}""" & ASCII.LF
      & "ld.list = ""{l, list}""" & ASCII.LF
      & "lx.list = ""{l, list}""" & ASCII.LF
      & "ly.list = ""{l, list}""" & ASCII.LF
      & "lo.list_or = ""{l, list, or}""" & ASCII.LF
      & "lu.list_unit = ""{l, list, unit}""" & ASCII.LF
      & "zz.list_or = ""{l, list, or}""" & ASCII.LF
      & "zz.list_unit = ""{l, list, unit}""" & ASCII.LF
      & "lu.unit = ""{v, unit, length-meter}""" & ASCII.LF
      & "rt.relative = ""{n, relative, day}""" & ASCII.LF
      & "rp.relative = ""{n, relative, day}""" & ASCII.LF
      & "rr.relative = ""{n, relative, day}""" & ASCII.LF
      & "du.relative = ""{n, relative, day}""" & ASCII.LF
      & "dv.relative = ""{n, relative, day}""" & ASCII.LF
      & "dr.relative = ""{n, relative, day}""" & ASCII.LF
      & "ra.relative = ""{n, relative, day}""" & ASCII.LF
      & "rw.relative_short = ""{n, relative, day/short}""" & ASCII.LF
      & "rx.relative = ""{n, relative, day}""" & ASCII.LF
      & "ry.relative = ""{n, relative, day}""" & ASCII.LF
      & "fc.relative = ""{n, relative, day}""" & ASCII.LF
      & "fs.relative_short = ""{n, relative, day/short}""" & ASCII.LF
      & "ft.relative = ""{n, relative, day}""" & ASCII.LF
      & "fw.relative = ""{n, relative, day}""" & ASCII.LF
      & "ld.money_name = ""{m, currency, XLD/name}""" & ASCII.LF
      & "lc.money_name = ""{m, currency, XLD/name}""" & ASCII.LF
      & "li.money_name = ""{m, currency, XLD/name}""" & ASCII.LF
      & "le.money_name = ""{m, currency, XLD/name}""" & ASCII.LF
      & "cm.money_name = ""{m, currency, XCM/name}""" & ASCII.LF
      & "cn.money_narrow = ""{m, currency, XCN/narrow}""" & ASCII.LF
      & "cn.money_name = ""{m, currency, XCN/name}""" & ASCII.LF
      & "cn.money_symbol = ""{m, currency, XSY}""" & ASCII.LF
      & "cn.money_symbol_narrow = ""{m, currency, XSY/narrow}"""
      & ASCII.LF
      & "cc.money_symbol = ""{m, currency, XCC}""" & ASCII.LF
      & "cc.money_symbol_narrow = ""{m, currency, XCC/narrow}"""
      & ASCII.LF
      & "lc.money_container_name = ""{m, currency, XCC/name}"""
      & ASCII.LF
      & "dt.instant = ""{i, datetime, short, UTC}"""
      & ASCII.LF
      & "dx.day = ""{d, date, long}"""
      & ASCII.LF
      & "tx.clock = ""{t, time, long}"""
      & ASCII.LF
      & "dtx.instant = ""{i, datetime, long, UTC}"""
      & ASCII.LF
      & "ndx.day = ""{d, date, full}"""
      & ASCII.LF
      & "ntx.clock = ""{t, time, full}"""
      & ASCII.LF
      & "ndt.instant = ""{i, datetime, full, UTC}"""
      & ASCII.LF
      & "tr.instant = ""{i, time, ::HH'_'mm, Tzdb/Transition}"""
      & ASCII.LF
      & "av.day = ""{d, date, ::yMMMd}"""
      & ASCII.LF
      & "df.day = ""{d, date, ::yMMMd}"""
      & ASCII.LF
      & "ai.instant = ""{i, datetime, ::yyyyMMddHHmm, UTC}"""
      & ASCII.LF
      & "ldc.money = ""{m, currency, XTS}""" & ASCII.LF
      & "ldc.accounting = ""{m, currency, XTS/accounting}"""
      & ASCII.LF
      & "lds.money = ""{m, currency, XTS}""" & ASCII.LF
      & "lds.accounting = ""{m, currency, XTS/accounting}"""
      & ASCII.LF
      & "lsp.accounting = ""{m, currency, XTS/accounting}"""
      & ASCII.LF
      & "cf.money = ""{m, currency, XTS}""" & ASCII.LF
      & "ca.accounting = ""{m, currency, XTS/accounting}"""
      & ASCII.LF
      & "ld.items = ""{n, plural, zero {zero #} other {other #}}"""
      & ASCII.LF
      & "pk.items = ""{n, plural, zero {zero #} other {other #}}"""
      & ASCII.LF
      & "ln.num = ""{v, number}""" & ASCII.LF
      & "ln.date = ""{d, date, ::yyyyMMdd}""" & ASCII.LF
      & "lf.num = ""{v, number}""" & ASCII.LF
      & "lf.date = ""{d, date, ::yyyyMMdd}""" & ASCII.LF
      & "lh.pref = ""{t, time, ::j}""" & ASCII.LF
      & "lh-u-hc-h23.pref = ""{t, time, ::j}""" & ASCII.LF
      & "lw.weekday = ""{d, date, ::e'/'ee'/'c'/'cc}""" & ASCII.LF
      & "lw.week = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "lw-REG.weekday = ""{d, date, ::e'/'ee'/'c'/'cc}"""
      & ASCII.LF
      & "lw-REG.week = ""{d, date, ::Y'/'w'/'W}""" & ASCII.LF
      & "lr.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lr-REG.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lr2.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lr3.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lr4.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lr5.period = ""{t, time, ::BBBB}""" & ASCII.LF
      & "lp.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ic.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ci.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "it.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "lit.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ea.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "lea.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "io.calendar = ""{d, date, ::yyyyMMdd'|'Y'|'w'|'W}""" & ASCII.LF
      & "lio.calendar = ""{d, date, ::yyyyMMdd'|'Y'|'w'|'W}"""
      & ASCII.LF
      & "hb.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "ldh.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "cp.calendar = ""{d, date, ::GyyyyMMdd}""" & ASCII.LF
      & "qz.num = ""{v, number}""" & ASCII.LF
      & "qz.date = ""{d, date, ::yyyyMMdd}""" & ASCII.LF
      & "hc.pref = ""{t, time, ::j}""" & ASCII.LF
      & "lp.default_time = ""{i, time, ::HH'_'mm}""" & ASCII.LF
      & "lp.default_zone = ""{i, time, ::zzzz}"""
      & ASCII.LF
      & "tz.default_time = ""{i, time, ::HH'_'mm}""" & ASCII.LF
      & "tz.default_zone = ""{i, time, ::zzzz}"""
      & ASCII.LF
      & "du.unit = ""{v, unit, meter}""" & ASCII.LF
      & "ml.month = ""{d, date, ::MMMM}""" & ASCII.LF
      & "cd.month = ""{d, date, ::MMMM}""" & ASCII.LF
      & "ml.money_name = ""{m, currency, XML/name}""" & ASCII.LF
      & "ml.unit = ""{v, unit, meter}""" & ASCII.LF
      & "ml.list = ""{l, list}""" & ASCII.LF
      & "cx.num = ""{v, number}""" & ASCII.LF
      & "cx.month = ""{d, date, ::MMMM}""" & ASCII.LF
      & "cx.money_name = ""{m, currency, XCT/name}""" & ASCII.LF
      & "cx.unit = ""{v, unit, meter}""" & ASCII.LF
      & "ct.num = ""{v, number}""" & ASCII.LF
      & "ct.month = ""{d, date, ::MMMM}""" & ASCII.LF
      & "ct.unit = ""{v, unit, meter}""" & ASCII.LF
      & "ct.list = ""{l, list}""" & ASCII.LF
      & "ix-ZZ.num = ""{v, number}""" & ASCII.LF
      & "ix-ZZ.month = ""{d, date, ::MMMM}""" & ASCII.LF
      & "ix-ZZ.weekday = ""{d, date, ::EEEE}""" & ASCII.LF
      & "ix-ZZ.era = ""{d, date, ::Gy}""" & ASCII.LF
      & "ix-ZZ.list = ""{l, list}""" & ASCII.LF
      & "um.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "uld.words = ""{v, number, ::spellout}""" & ASCII.LF
      & "pr.items = ""{count, plural, one {one} few {few} "
      & "many {many} other {other}}""" & ASCII.LF
      & "wt.items = ""{count, plural, one {one} few {few} "
      & "many {many} other {other}}""" & ASCII.LF
      & "nr.items = ""{count, plural, two {two} other {other}}"""
      & ASCII.LF
      & "nq.items = ""{count, plural, one {one} other {other}}"""
      & ASCII.LF
      & "nc.items = ""{count, plural, one {one} other {other}}"""
      & ASCII.LF
      & "ne.items = ""{count, plural, few {few} other {other}}"""
      & ASCII.LF
      & "lrp.items = ""{count, plural, few {few} other {other}}"""
      & ASCII.LF
      & "lrs.items = ""{count, plural, many {many} other {other}}"""
      & ASCII.LF
      & "lpc.items = ""{count, plural, one {one} other {other}}"""
      & ASCII.LF
      & "lpd.items = ""{count, plural, one {one} other {other}}"""
      & ASCII.LF
      & "lpo.rank = ""{n, selectordinal, two {two #} other {other #}}"""
      & ASCII.LF,
      Result);
   Assert (Result.Status = I18N.Runtime.Loaded,
           "runtime data test catalog loads");

   Data := I18N.Runtime.Load_Data_Text
     ("runtime-data",
      "locale.zz.decimal_separator = |" & ASCII.LF
      & "locale.zz.group_separator = _" & ASCII.LF
      & "locale.zz.uses_indian_grouping = true" & ASCII.LF
      & "locale.zz.number_plus_sign = PLUS" & ASCII.LF
      & "locale.zz.number_minus_sign = MINUS" & ASCII.LF
      & "locale.zz.gmt_offset_prefix = ZGMT" & ASCII.LF
      & "locale.zz.timezone_offset_separator = ^" & ASCII.LF
      & "locale.zz.timezone_utc_designator = ZERO" & ASCII.LF
      & "locale.zz.currency_symbol_first = false" & ASCII.LF
      & "locale.zz.currency_amount_separator = "" @ """ & ASCII.LF
      & "locale.zz.month.1 = OverrideMonth" & ASCII.LF
      & "locale.zz.month_short.1 = Om" & ASCII.LF
      & "locale.zz.weekday.0 = OverrideSunday" & ASCII.LF
      & "locale.zz.era.gregorian.ad = ZZAD" & ASCII.LF
      & "locale.zz.timezone_display.Example/Zone = ZZ Zone" & ASCII.LF
      & "locale.zz.timezone_exemplar.Example/Zone = ZZ City" & ASCII.LF
      & "locale.zz.timezone_location_pattern = {0} Zone" & ASCII.LF
      & "locale.zz.timezone_short.Example/Zone = ZZS" & ASCII.LF
      & "locale.zz.timezone_generic_short.Example/Zone = ZZG" & ASCII.LF
      & "locale.zz.unit.meter.unit-width-full-name.one = zmeter" & ASCII.LF
      & "locale.zz.unit.meter.unit-width-full-name.other = zmeters" & ASCII.LF
      & "locale.du.decimal_separator = |" & ASCII.LF
      & "locale.du.unit_value_separator = ~" & ASCII.LF
      & "locale.du.unit.meter.unit-width-full-name.one = duone" & ASCII.LF
      & "locale.du.unit.meter.unit-width-full-name.few = dufew" & ASCII.LF
      & "locale.du.unit.meter.unit-width-full-name.many = dumany"
      & ASCII.LF
      & "locale.du.unit.meter.unit-width-full-name.other = duother"
      & ASCII.LF
      & "locale.zz.relative_current.day = ztoday" & ASCII.LF
      & "locale.zz.relative_unit.day.one = zday" & ASCII.LF
      & "locale.zz.relative_unit.day.other = zdays" & ASCII.LF
      & "locale.zz.relative_prefix.future = ""in-z """ & ASCII.LF
      & "locale.zz.relative_suffix.future = "" ahead""" & ASCII.LF
      & "locale.zz.unit_value_separator = ~" & ASCII.LF
      & "locale.zz.list_item_separator = "" | """ & ASCII.LF
      & "locale.zz.list_pair_separator = "" + """ & ASCII.LF
      & "locale.zz.list_start_separator = "" < """ & ASCII.LF
      & "locale.zz.list_middle_separator = "" = """ & ASCII.LF
      & "locale.zz.list_final_separator = "" & """ & ASCII.LF
      & "locale.zz.list_or_pair_separator = "" ?2 """ & ASCII.LF
      & "locale.zz.list_or_start_separator = "" ?< """ & ASCII.LF
      & "locale.zz.list_or_middle_separator = "" ?= """ & ASCII.LF
      & "locale.zz.list_or_final_separator = "" ?& """ & ASCII.LF
      & "locale.zz.list_unit_item_separator = "" / """ & ASCII.LF
      & "locale.zz.list_unit_final_separator = "" // """ & ASCII.LF
      & "locale.zz.date_style.long = MMMM' 'd' 'yyyy" & ASCII.LF
      & "locale.zz.date_style.short = MMM' 'd" & ASCII.LF
      & "locale.zz.time_style.short = HH'_'mm" & ASCII.LF
      & "locale.lw.first_day_of_week = sat" & ASCII.LF
      & "locale.lw.first_week_min_days = 1" & ASCII.LF
      & "locale.ic.default_calendar = islamicc" & ASCII.LF
      & "locale.it.default_calendar = islamic-tbla" & ASCII.LF
      & "locale.ea.default_calendar = ethioaa" & ASCII.LF
      & "locale.io.default_calendar = iso8601" & ASCII.LF
      & "locale.hb.default_calendar = hebrew" & ASCII.LF
      & "timezone.Example/Zone.base_offset_minutes = 90" & ASCII.LF
      & "timezone.Typed/Zone.base_offset_minutes = 0" & ASCII.LF
      & "timezone.Region/Zone.base_offset_minutes = 0" & ASCII.LF
      & "currency.XTS.symbol = XT$" & ASCII.LF
      & "currency.XTS.narrow_symbol = X$" & ASCII.LF
      & "currency.XTS.display_name.other = test credits" & ASCII.LF
      & "currency.XTS.minor_units = 3" & ASCII.LF
      & "currency.XTS.cash_increment = 5" & ASCII.LF
      & "plural.cardinal.zz.7 = few" & ASCII.LF
      & "plural.ordinal.zz.9 = two" & ASCII.LF
      & "plural.rule_family.cardinal.zz = ar" & ASCII.LF
      & "plural.rule_family.cardinal.la = n-is-1" & ASCII.LF
      & "plural.rule_family.cardinal.lc = n-is-1" & ASCII.LF
      & "plural.rule_family.cardinal.lu = ar" & ASCII.LF
      & "plural.rule_family.cardinal.rp = ar" & ASCII.LF
      & "plural.rule_family.cardinal.du = cs" & ASCII.LF
      & "plural.rule_family.ordinal.zz = en-ordinal" & ASCII.LF
      & "plural.rule.cardinal.pr.one = n is 1" & ASCII.LF
      & "plural.rule.cardinal.pr.few = n mod 10 in 2..4 "
      & "and n mod 100 not in 12..14" & ASCII.LF
      & "plural.rule.cardinal.pr.many = n mod 10 is 0 "
      & "or n mod 10 in 5..9 or n mod 100 in 11..14"
      & ASCII.LF
      & "plural_rule_text|cardinal|nr|two|n is 2" & ASCII.LF
      & "plural_rule_text|cardinal|nq|one|n is 1 @integer 1"
      & ASCII.LF
      & "plural_rule_text|cardinal|nc|one|c is 0" & ASCII.LF
      & "plural_rule_text|cardinal|ne|few|e is 0" & ASCII.LF
      & "rbnf.zz.cardinal.1 = zone" & ASCII.LF
      & "rbnf.zz.cardinal.2 = ztwo" & ASCII.LF
      & "rbnf.zz.cardinal.5 = zfive;" & ASCII.LF
      & "rbnf.zz.cardinal.7 = zseven" & ASCII.LF
      & "rbnf.zz.cardinal.8 = zeight" & ASCII.LF
      & "rbnf.zz.%spellout-cardinal.11 = zeleven" & ASCII.LF
      & "rbnf.zz.cardinal.-2 = zminus-two" & ASCII.LF
      & "rbnf.zz.cardinal.-2.3 = zminus-two-point-three-exact"
      & ASCII.LF
      & "rbnf.zz.ordinal.2 = zsecond" & ASCII.LF
      & "rbnf.zz.ordinal.-2 = zminus-second" & ASCII.LF
      & "rbnf.zz.ordinal.-2.3 = zminus-second-point-three-exact"
      & ASCII.LF
      & "rbnf.zz.decimal_separator = zpoint" & ASCII.LF
      & "rbnf_rule.zz.cardinal.30 = zthirty$(ordinal,one{st}two{nd}few{rd}other{th})$"
      & ASCII.LF
      & "rbnf_rule.zz.cardinal.35 = zthirtyfive$( ordinal, one{st} two{nd} few{rd} other{th} )$"
      & ASCII.LF
      & "rbnf_rule.zz.cardinal.36 = zthirtysix$(ordinal,one{}other{})$"
      & ASCII.LF
      & "rbnf_rule.zz.cardinal.40 = forty[->>]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.13 = zthirteen" & ASCII.LF
      & "rbnf_rule.zz.cardinal.80 = eighty[->>];" & ASCII.LF
      & "rbnf_rule.zz.cardinal.100 = << zhundred[ >>>]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.400/10 = << ztens[ >>>]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.700 = " & U (16#2190#)
      & "%spellout-cardinal" & U (16#2190#) & " znamed[ "
      & U (16#2192#) & "%spellout-cardinal" & U (16#2192#)
      & "]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.800 = <%spellout-cardinal< zascii[ "
      & ">%spellout-cardinal>]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.900 = <%spellout-ordinal< ztarget[ "
      & ">%spellout-cardinal>]" & ASCII.LF
      & "rbnf_rule.zz.cardinal.990 = =%spellout-ordinal= zequal"
      & ASCII.LF
      & "rbnf_rule.zz.cardinal.negative = zneg >>>" & ASCII.LF
      & "rbnf_rule.zz.cardinal.0.x = zzero >>>" & ASCII.LF
      & "rbnf_rule.zz.cardinal.x.0 = << zwhole" & ASCII.LF
      & "rbnf_rule.zz.cardinal.decimal = << zdecimal >>>" & ASCII.LF
      & "rbnf_rule.zz.ordinal.20 = twentieth[->>]" & ASCII.LF
      & "rbnf.um.cardinal.2 = umtwo" & ASCII.LF
      & "rbnf_rule.um.cardinal." & U (16#2212#) & "x = umneg >>>"
      & ASCII.LF
      & "<symbols locale=""ld"" decimal=""|"" group="":"" percent="" pct"""
      & " permille="" pm"" plus=""PLUS"" minus=""MINUS"""
      & " exponent=""EXP"" accountingPrefix=""["" accountingSuffix=""]""/>"
      & ASCII.LF
      & "<symbols locale=""sy"" decimal=""!"" group=""^"""
      & " percentSign="" pc"" perMille="" pm"" plusSign=""P"""
      & " minusSign=""M"" exponential=""X"""
      & " accountingPrefix=""{"" accountingSuffix=""}""/>"
      & ASCII.LF
      & "<ldml locale=""sc"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<defaultNumberingSystem>latn</defaultNumberingSystem>"
      & ASCII.LF
      & "<symbols numberSystem=""latn"">" & ASCII.LF
      & "<decimal>!</decimal>" & ASCII.LF
      & "<group>_</group>" & ASCII.LF
      & "<percentSign> pct</percentSign>" & ASCII.LF
      & "<perMille> pm</perMille>" & ASCII.LF
      & "<plusSign>PLUS</plusSign>" & ASCII.LF
      & "<minusSign>MINUS</minusSign>" & ASCII.LF
      & "<exponential>EXP</exponential>" & ASCII.LF
      & "</symbols>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""sd"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<defaultNumberingSystem>thai</defaultNumberingSystem>"
      & ASCII.LF
      & "<symbols numberSystem=""latn"">" & ASCII.LF
      & "<decimal>BAD</decimal>" & ASCII.LF
      & "<group>BAD</group>" & ASCII.LF
      & "</symbols>" & ASCII.LF
      & "<symbols numberSystem=""thai"">" & ASCII.LF
      & "<decimal>!</decimal>" & ASCII.LF
      & "<group>^</group>" & ASCII.LF
      & "</symbols>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<symbols locale=""xe"" decimal=""&amp;"" group=""&#x2A;"""
      & " plusSign=""&lt;"" minusSign=""&gt;""/>"
      & ASCII.LF
      & "<symbols locale='xq' decimal='&#38;' group='_'"
      & " plusSign='P' minusSign='M'/>"
      & ASCII.LF
      & "<symbols locale = ""xs"" decimal = ""!"" group = ""~"""
      & " plusSign = ""Q"" minusSign = ""R""/>"
      & ASCII.LF
      & "<month locale=""ml"" type=""wide"" index=""1"">"
      & ASCII.LF
      & "MultiMonth" & ASCII.LF
      & "</month>" & ASCII.LF
      & "<month locale=""cd"" type=""wide"" index=""1"">"
      & "<![CDATA[CDATA & Month]]></month>" & ASCII.LF
      & "<currencyName locale=""ml"" type=""XML"" count=""other"">"
      & ASCII.LF
      & "multi credits" & ASCII.LF
      & "</currencyName>" & ASCII.LF
      & "<unitPattern locale=""ml"" unit=""meter"""
      & " width=""unit-width-full-name"" count=""other"">"
      & ASCII.LF
      & "{0} multimeters" & ASCII.LF
      & "</unitPattern>" & ASCII.LF
      & "<listPatternPart locale=""ml"" type=""2"">"
      & ASCII.LF
      & "{0} ml-and {1}" & ASCII.LF
      & "</listPatternPart>" & ASCII.LF
      & "<?xml version=""1.0""?>" & ASCII.LF
      & "<!-- runtime CLDR context rows -->" & ASCII.LF
      & "<ldml locale=""cx"">" & ASCII.LF
      & "<symbols decimal=""*"" group=""^""/>" & ASCII.LF
      & "<month type=""wide"" index=""1"">ContextMonth</month>"
      & ASCII.LF
      & "<currencyName type=""XCT"" count=""other"">context credits"
      & "</currencyName>" & ASCII.LF
      & "<unitPattern unit=""meter"" width=""unit-width-full-name"""
      & " count=""other"">{0} contextmeters</unitPattern>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""ct"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<symbols decimal=""!"" group=""~""/>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<months>" & ASCII.LF
      & "<monthContext type=""format"">" & ASCII.LF
      & "<monthWidth type=""wide"">" & ASCII.LF
      & "<month type=""1"">ContainerMonth</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "</monthContext>" & ASCII.LF
      & "</months>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "<units>" & ASCII.LF
      & "<unitLength type=""long"">" & ASCII.LF
      & "<unitPattern unit=""meter"" width=""unit-width-full-name"""
      & " count=""other"">{0} containermeters</unitPattern>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "</units>" & ASCII.LF
      & "<listPatterns>" & ASCII.LF
      & "<listPatternPart type=""2"">{0} ct-and {1}</listPatternPart>"
      & ASCII.LF
      & "</listPatterns>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml>" & ASCII.LF
      & "<identity>" & ASCII.LF
      & "<language type=""ix""/>" & ASCII.LF
      & "<territory type=""ZZ""/>" & ASCII.LF
      & "</identity>" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<symbols decimal=""?"" group=""'""/>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<months>" & ASCII.LF
      & "<monthContext type=""format"">" & ASCII.LF
      & "<monthWidth type=""wide"">" & ASCII.LF
      & "<month type=""1"">IdentityMonth</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "</monthContext>" & ASCII.LF
      & "</months>" & ASCII.LF
      & "<days>" & ASCII.LF
      & "<dayContext type=""format"">" & ASCII.LF
      & "<dayWidth type=""wide"">" & ASCII.LF
      & "<day type=""mon"">IdentityMonday</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "</dayContext>" & ASCII.LF
      & "</days>" & ASCII.LF
      & "<eras>" & ASCII.LF
      & "<eraAbbr>" & ASCII.LF
      & "<era type=""1"">IXAD</era>" & ASCII.LF
      & "</eraAbbr>" & ASCII.LF
      & "</eras>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "<listPatterns>" & ASCII.LF
      & "<listPatternPart type=""2"">{0} ix-and {1}</listPatternPart>"
      & ASCII.LF
      & "</listPatterns>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""2"">"
      & "ldtwo</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""5"">ldfive;</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""%spellout-cardinal"""
      & " value=""12"">ldtwelve</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""40"">ldforty[->>]</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""9"">"
      & ASCII.LF
      & "ldnine" & ASCII.LF
      & "</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""90"">" & ASCII.LF
      & "ldninety[->>>]" & ASCII.LF
      & "</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""80"">ldeighty[-" & U (16#2192#) & U (16#2192#)
      & "];</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""6"">"
      & "ldsix</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""60"">ldsixty[-" & U (16#2192#) & U (16#2192#)
      & "]</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""600"">" & U (16#2190#) & U (16#2190#)
      & " ldred[ " & U (16#2192#) & U (16#2192#)
      & U (16#2192#) & "]</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""400/10"">" & U (16#2190#) & U (16#2190#)
      & " ldtens[ " & U (16#2192#) & U (16#2192#)
      & U (16#2192#) & "]</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""50"">"
      & "ldfifty</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""500"" radix=""10"">" & U (16#2190#) & U (16#2190#)
      & " ldradix[ " & U (16#2192#) & U (16#2192#)
      & U (16#2192#) & "]</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""700"">" & U (16#2190#) & "%spellout-cardinal"
      & U (16#2190#) & " ldnamed[ " & U (16#2192#)
      & "%spellout-cardinal" & U (16#2192#) & "]</rbnfRule>"
      & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""800""><%spellout-cardinal< ldascii[ "
      & ">%spellout-cardinal>]</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""900"">" & U (16#2190#) & "%spellout-ordinal"
      & U (16#2190#) & " ldtarget[ " & U (16#2192#)
      & "%spellout-cardinal" & U (16#2192#) & "]</rbnfRule>"
      & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""990"">=%spellout-ordinal= ldequal</rbnfRule>"
      & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""0.x"">ldzero " & U (16#2192#) & U (16#2192#)
      & "</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-cardinal"""
      & " value=""x.0"">" & U (16#2190#) & U (16#2190#)
      & " ldwhole</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""-2"">"
      & "ldminus-two</rbnf>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal"" value=""-2.3"">"
      & "ldminus-two-point-three-exact</rbnf>" & ASCII.LF
      & "<rbnf locale=""ld"" type=""spellout-cardinal-masculine"""
      & " value=""7"">ldseven-masculine</rbnf>" & ASCII.LF
      & "<rbnfrule locale=""ld"" ruleset=""spellout-cardinal"""
      & " value=""8"">ldeight-lower</rbnfrule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-ordinal"""
      & " value=""2"">ldsecond</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-ordinal"""
      & " value=""-2"">ldminus-second</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-ordinal"""
      & " value=""-2.3"">ldminus-second-point-three-exact</rbnfRule>"
      & ASCII.LF
      & "<rbnfRule locale=""ld"" ruleSet=""spellout-ordinal-verbose"""
      & " value=""7"">ldseventh-verbose</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""uld"" type=""spellout-cardinal"" value=""2"">"
      & "uldtwo</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""uld"" ruleSet=""spellout-cardinal"""
      & " value=""" & U (16#2212#) & "x"">uldneg >>>"
      & "</rbnfRule>" & ASCII.LF
      & "<month locale=""ld"" type=""wide"" index=""1"">LdMonth</month>"
      & ASCII.LF
      & "<quarter locale=""ld"" type=""wide"" index=""2"">LdQuarter</quarter>"
      & ASCII.LF
      & "<quarter locale=""ld"" type=""abbreviated"" index=""2"">LQ2</quarter>"
      & ASCII.LF
      & "<quarter locale=""ld"" type=""narrow"" index=""2"">L2</quarter>"
      & ASCII.LF
      & "<month locale=""dn"" type=""1"" width=""wide"">DNMonth</month>"
      & ASCII.LF
      & "<month locale=""dn"" type=""1"" width=""abbreviated"">DNM</month>"
      & ASCII.LF
      & "<weekday locale=""dn"" type=""mon"" width=""wide"">DNMonday</weekday>"
      & ASCII.LF
      & "<weekday locale=""dn"" type=""mon"" width=""abbreviated"">DNMon</weekday>"
      & ASCII.LF
      & "<quarter locale=""dn"" type=""1"" width=""wide"">DNQuarter</quarter>"
      & ASCII.LF
      & "<quarter locale=""dn"" type=""1"" width=""abbrev"">DNQ</quarter>"
      & ASCII.LF
      & "<quarter locale=""dn"" type=""1"" width=""narrow"">D1</quarter>"
      & ASCII.LF
      & "<ldml locale=""dw"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<months>" & ASCII.LF
      & "<monthContext type=""format"">" & ASCII.LF
      & "<monthWidth type=""abbreviated"">"
      & ASCII.LF
      & "<month type=""1"">DWM</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "</monthContext>" & ASCII.LF
      & "</months>" & ASCII.LF
      & "<days>" & ASCII.LF
      & "<dayContext type=""format"">" & ASCII.LF
      & "<dayWidth type=""abbreviated"">"
      & ASCII.LF
      & "<day type=""mon"">DWMon</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "</dayContext>" & ASCII.LF
      & "</days>" & ASCII.LF
      & "<quarters>" & ASCII.LF
      & "<quarterContext type=""format"">" & ASCII.LF
      & "<quarterWidth type=""abbreviated"">"
      & ASCII.LF
      & "<quarter type=""1"">DWQ</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "</quarterContext>" & ASCII.LF
      & "<quarterContext type=""format"">" & ASCII.LF
      & "<quarterWidth type=""narrow"">"
      & ASCII.LF
      & "<quarter type=""1"">W1</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "</quarterContext>" & ASCII.LF
      & "</quarters>" & ASCII.LF
      & "<dayPeriods>" & ASCII.LF
      & "<dayPeriodContext type=""format"">"
      & ASCII.LF
      & "<dayPeriodWidth type=""abbreviated"">" & ASCII.LF
      & "<dayPeriod type=""afternoon1"">DW aft</dayPeriod>" & ASCII.LF
      & "</dayPeriodWidth>" & ASCII.LF
      & "<dayPeriodWidth type=""wide"">" & ASCII.LF
      & "<dayPeriod type=""afternoon1"">DW afternoon</dayPeriod>" & ASCII.LF
      & "</dayPeriodWidth>" & ASCII.LF
      & "<dayPeriodWidth type=""narrow"">" & ASCII.LF
      & "<dayPeriod type=""afternoon1"">D</dayPeriod>" & ASCII.LF
      & "</dayPeriodWidth>" & ASCII.LF
      & "</dayPeriodContext>" & ASCII.LF
      & "</dayPeriods>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""sx"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<months>" & ASCII.LF
      & "<monthContext type=""format"">" & ASCII.LF
      & "<monthWidth type=""wide"">" & ASCII.LF
      & "<month type=""1"">SX format month</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "<monthWidth type=""narrow"">" & ASCII.LF
      & "<month type=""1"">FM</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "</monthContext>" & ASCII.LF
      & "<monthContext type=""stand-alone"">" & ASCII.LF
      & "<monthWidth type=""wide"">" & ASCII.LF
      & "<month type=""1"">SX standalone month</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "<monthWidth type=""narrow"">" & ASCII.LF
      & "<month type=""1"">SM</month>" & ASCII.LF
      & "</monthWidth>" & ASCII.LF
      & "</monthContext>" & ASCII.LF
      & "</months>" & ASCII.LF
      & "<days>" & ASCII.LF
      & "<dayContext type=""format"">" & ASCII.LF
      & "<dayWidth type=""wide"">" & ASCII.LF
      & "<day type=""sun"">SX format Sunday</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "<dayWidth type=""narrow"">" & ASCII.LF
      & "<day type=""sun"">FS</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "</dayContext>" & ASCII.LF
      & "<dayContext type=""stand-alone"">" & ASCII.LF
      & "<dayWidth type=""wide"">" & ASCII.LF
      & "<day type=""sun"">SX standalone Sunday</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "<dayWidth type=""narrow"">" & ASCII.LF
      & "<day type=""sun"">SS</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "</dayContext>" & ASCII.LF
      & "</days>" & ASCII.LF
      & "<quarters>" & ASCII.LF
      & "<quarterContext type=""format"">" & ASCII.LF
      & "<quarterWidth type=""wide"">" & ASCII.LF
      & "<quarter type=""1"">SX format quarter</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "<quarterWidth type=""narrow"">" & ASCII.LF
      & "<quarter type=""1"">F1</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "</quarterContext>" & ASCII.LF
      & "<quarterContext type=""stand-alone"">" & ASCII.LF
      & "<quarterWidth type=""wide"">" & ASCII.LF
      & "<quarter type=""1"">SX standalone quarter</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "<quarterWidth type=""narrow"">" & ASCII.LF
      & "<quarter type=""1"">S1</quarter>" & ASCII.LF
      & "</quarterWidth>" & ASCII.LF
      & "</quarterContext>" & ASCII.LF
      & "</quarters>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<dayPeriod locale=""ld"" type=""pm"" width=""abbreviated"">ld-pm</dayPeriod>"
      & ASCII.LF
      & "<dayPeriod locale=""ld"" type=""noon"" width=""wide"">ld-noon</dayPeriod>"
      & ASCII.LF
      & "<era locale=""ld"" calendar=""gregorian"" type=""ad"">LDAD</era>"
      & ASCII.LF
      & "<era locale=""er"" calendar=""gregory"" type=""1"">ERAD</era>"
      & ASCII.LF
      & "<zoneName locale=""ld"" id=""Ldml/Zone"">LD Zone</zoneName>"
      & ASCII.LF
      & "<zoneExemplar locale=""ld"" id=""Ldml/Zone"">LD City</zoneExemplar>"
      & ASCII.LF
      & "<zoneLocationPattern locale=""ld"">LD {0}</zoneLocationPattern>"
      & ASCII.LF
      & "<gmtFormat locale=""gf"">GMT~{0}</gmtFormat>" & ASCII.LF
      & "<hourFormat locale=""gf"">+HH_mm;-HH_mm</hourFormat>"
      & ASCII.LF
      & "<gmtZeroFormat locale=""gf"">ZERO~</gmtZeroFormat>"
      & ASCII.LF
      & "<zoneShort locale=""ld"" id=""Ldml/Zone"">LDS</zoneShort>"
      & ASCII.LF
      & "<zoneGenericShort locale=""ld"" id=""Ldml/Zone"">LDG</zoneGenericShort>"
      & ASCII.LF
      & "<zoneName locale=""ty"" id=""Typed/Zone"" type=""generic"">TY Zone</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""zt"" id=""Typed/Zone"" type=""standard"">ZT Standard Zone</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""zy"" id=""America/New_York"" type=""daylight"">ZY Daylight Zone</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""ty"" id=""Typed/Zone"" type=""short"">TYS</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""ty"" id=""Typed/Zone"" type=""generic-short"">TYG</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""zs"" id=""Typed/Zone"" type=""short-standard"">ZSS</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""zg"" id=""Typed/Zone"" type=""shortGeneric"">ZGG</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""zd"" id=""America/New_York"" type=""daylightShort"">ZDD</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""za"" zone=""Alias/Zone"">Alias Zone</zoneName>"
      & ASCII.LF
      & "<timeZoneName locale=""zn"" zone=""Alias/Zone"">TZ Alias Zone</timeZoneName>"
      & ASCII.LF
      & "<timeZoneName locale=""zn"" zone=""Alias/Zone"" type=""short"">TZN</timeZoneName>"
      & ASCII.LF
      & "<zoneShortStandard locale=""sa"" zone=""Typed/Zone"">SAS</zoneShortStandard>"
      & ASCII.LF
      & "<zoneStandardShort locale=""sb"" zone=""Typed/Zone"">SBS</zoneStandardShort>"
      & ASCII.LF
      & "<zoneShortGeneric locale=""sc"" zone=""Typed/Zone"">SCG</zoneShortGeneric>"
      & ASCII.LF
      & "<zoneDaylightShort locale=""se"" zone=""America/New_York"">SED</zoneDaylightShort>"
      & ASCII.LF
      & "<zoneExemplar locale=""za"" zone=""Alias/Zone"">Alias City</zoneExemplar>"
      & ASCII.LF
      & "<zoneLocationPattern locale=""za"">Alias {0}</zoneLocationPattern>"
      & ASCII.LF
      & "<zoneExemplar locale=""rf"" zone=""Alias/Zone"">RF City</zoneExemplar>"
      & ASCII.LF
      & "<regionFormat locale=""rf"">RF {0}</regionFormat>"
      & ASCII.LF
      & "<exemplarCity locale=""ec"" zone=""Alias/Zone"">EC City</exemplarCity>"
      & ASCII.LF
      & "<regionFormat locale=""ec"">EC {0}</regionFormat>"
      & ASCII.LF
      & "<zoneExemplar locale=""rs"" zone=""Region/Zone"">RS City</zoneExemplar>"
      & ASCII.LF
      & "<regionFormat locale=""rs"" type=""standard"">RS Standard {0}</regionFormat>"
      & ASCII.LF
      & "<zoneShort locale=""za"" zone=""Alias/Zone"">AZS</zoneShort>"
      & ASCII.LF
      & "<zoneGenericShort locale=""za"" zone=""Alias/Zone"">AZG</zoneGenericShort>"
      & ASCII.LF
      & "<ldml locale=""zc"">" & ASCII.LF
      & "<timeZoneNames>" & ASCII.LF
      & "<zone type=""America/New_York"">" & ASCII.LF
      & "<exemplarCity>ZC City</exemplarCity>" & ASCII.LF
      & "<long>" & ASCII.LF
      & "<generic>ZC Generic</generic>" & ASCII.LF
      & "<standard>ZC Standard</standard>" & ASCII.LF
      & "<daylight>ZC Daylight</daylight>" & ASCII.LF
      & "</long>" & ASCII.LF
      & "<short>" & ASCII.LF
      & "<generic>ZCG</generic>" & ASCII.LF
      & "<standard>ZCS</standard>" & ASCII.LF
      & "<daylight>ZCD</daylight>" & ASCII.LF
      & "</short>" & ASCII.LF
      & "</zone>" & ASCII.LF
      & "<regionFormat>ZC {0}</regionFormat>" & ASCII.LF
      & "</timeZoneNames>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<unitName locale=""ld"" unit=""meter"" width=""unit-width-full-name"" count=""one"">ldmeter</unitName>"
      & ASCII.LF
      & "<unitName locale=""ld"" unit=""meter"" width=""unit-width-full-name"" count=""few"">ldfewmeters</unitName>"
      & ASCII.LF
      & "<unitName locale=""ld"" unit=""meter"" width=""unit-width-full-name"" count=""other"">ldmeters</unitName>"
      & ASCII.LF
      & "<unitName locale=""la"" unit=""length-meter"" width=""long"" count=""one"">alias meter</unitName>"
      & ASCII.LF
      & "<unitName locale=""la"" unit=""length-meter"" width=""long"" count=""other"">alias meters</unitName>"
      & ASCII.LF
      & "<unitName locale=""la"" unit=""volume-liter"" width=""short"" count=""other"">alias L</unitName>"
      & ASCII.LF
      & "<unitPattern locale=""lu"" unit=""meter"""
      & " width=""unit-width-full-name"" count=""one"">"
      & "{0} lupattern-meter</unitPattern>"
      & ASCII.LF
      & "<unitPattern locale=""lu"" unit=""meter"""
      & " type=""unit-width-full-name"" count=""other"">"
      & "lupattern-meters {0}</unitPattern>"
      & ASCII.LF
      & "<unitPattern locale=""la"" unit=""mass-gram"""
      & " type=""short"" count=""other"">"
      & "alias grams {0}</unitPattern>"
      & ASCII.LF
      & "<unitName locale=""ut"" type=""length-meter"" count=""one"">typed meter</unitName>"
      & ASCII.LF
      & "<unitName locale=""ut"" type=""length-meter"" count=""other"">typed meters</unitName>"
      & ASCII.LF
      & "<unitPattern locale=""ut"" type=""mass-gram"""
      & " width=""short"" count=""other"">typed grams {0}</unitPattern>"
      & ASCII.LF
      & "<unitDisplayName locale=""ud"" type=""length-meter"">display meters</unitDisplayName>"
      & ASCII.LF
      & "<unitName locale=""un"" type=""length-meter"">countless meters</unitName>"
      & ASCII.LF
      & "<ldml locale=""en-UC"">" & ASCII.LF
      & "<units>" & ASCII.LF
      & "<unitLength type=""long"">" & ASCII.LF
      & "<unit type=""length-meter"">" & ASCII.LF
      & "<displayName>context meters</displayName>" & ASCII.LF
      & "<unitPattern count=""one"">{0} context meter</unitPattern>"
      & ASCII.LF
      & "<unitPattern count=""other"">{0} context meters</unitPattern>"
      & ASCII.LF
      & "</unit>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "<unitLength type=""short"">" & ASCII.LF
      & "<unit type=""length-meter"">" & ASCII.LF
      & "<unitPattern count=""other"">{0} ctx m</unitPattern>"
      & ASCII.LF
      & "</unit>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "</units>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<compoundUnitPattern locale=""cu"" type=""per"" width=""long"">{0} PER {1}</compoundUnitPattern>"
      & ASCII.LF
      & "<compoundUnitPattern locale=""cs"" type=""per"" width=""short"">{0}/{1}</compoundUnitPattern>"
      & ASCII.LF
      & "<ldml locale=""cp"">" & ASCII.LF
      & "<units>" & ASCII.LF
      & "<unitLength type=""long"">" & ASCII.LF
      & "<compoundUnit type=""per"">" & ASCII.LF
      & "<compoundUnitPattern>{0} CPER {1}</compoundUnitPattern>"
      & ASCII.LF
      & "</compoundUnit>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "<unitLength type=""short"">" & ASCII.LF
      & "<compoundUnit type=""per"">" & ASCII.LF
      & "<compoundUnitPattern>{0}~{1}</compoundUnitPattern>"
      & ASCII.LF
      & "</compoundUnit>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "</units>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<relativeName locale=""ld"" unit=""day"">ldtoday</relativeName>"
      & ASCII.LF
      & "<relativeUnit locale=""ld"" unit=""day"" count=""few"">ldfewdays</relativeUnit>"
      & ASCII.LF
      & "<relativeUnit locale=""ld"" unit=""day"" count=""other"">lddays</relativeUnit>"
      & ASCII.LF
      & "<relativePattern locale=""ld"" type=""future"" prefix=""after "" suffix="" later""/>"
      & ASCII.LF
      & "<relativePattern locale=""rr"" type=""future"">rr after {0}</relativePattern>"
      & ASCII.LF
      & "<relativePattern locale=""rr"" type=""past"">{0} rr before</relativePattern>"
      & ASCII.LF
      & "<relativeUnit locale=""rr"" unit=""day"" count=""other"">rrdays</relativeUnit>"
      & ASCII.LF
      & "<relativePeriod locale=""rt"" unit=""day"">rttoday</relativePeriod>"
      & ASCII.LF
      & "<relativeUnit locale=""rt"" unit=""day"" count=""other"">rtdays</relativeUnit>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rt"" type=""future"">after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rt"" type=""past"">{0} before</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rp"" unit=""day"" count=""one"""
      & " type=""future"">rp tomorrowish</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rp"" unit=""day"" count=""other"""
      & " type=""future"">rp after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rp"" unit=""day"" count=""other"""
      & " type=""past"">rp {0} before</relativeTimePattern>"
      & ASCII.LF
      & "<relativePeriod locale=""du"" unit=""duration-day"">du today</relativePeriod>"
      & ASCII.LF
      & "<relativeTimePattern locale=""du"" unit=""duration-day"" count=""other"""
      & " type=""future"">du after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""du"" unit=""duration-day"" count=""other"""
      & " type=""past"">du {0} ago</relativeTimePattern>"
      & ASCII.LF
      & "<relativeUnit locale=""dv"" unit=""duration-day"" count=""other"">dv days</relativeUnit>"
      & ASCII.LF
      & "<relativeTimePattern locale=""dv"" type=""future"">dv after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativePeriod locale=""dr"" type=""duration-day"">dr today</relativePeriod>"
      & ASCII.LF
      & "<relativeUnit locale=""dr"" type=""duration-day"" count=""other"">dr days</relativeUnit>"
      & ASCII.LF
      & "<relativeTimePattern locale=""dr"" unit=""duration-day"" count=""other"""
      & " type=""future"">dr after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""ra"" relativeUnit=""duration-day"""
      & " count=""other"" type=""future"">ra after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTimePattern locale=""rw"" relativeUnit=""duration-day"""
      & " unitWidth=""short"" count=""other"" type=""future"">"
      & "rw after {0}</relativeTimePattern>"
      & ASCII.LF
      & "<relativeTime locale=""rx"" relativeUnit=""duration-day"""
      & " count=""other"" type=""future"">rx after {0}</relativeTime>"
      & ASCII.LF
      & "<relativeTime locale=""ry"" type=""future"">ry after {0}</relativeTime>"
      & ASCII.LF
      & "<relativeUnit locale=""ry"" unit=""duration-day"" count=""other"">rydays</relativeUnit>"
      & ASCII.LF
      & "<ldml locale=""fc"">" & ASCII.LF
      & "<relativeFields>" & ASCII.LF
      & "<field type=""day"">" & ASCII.LF
      & "<relative type=""-1"">fc yesterday</relative>" & ASCII.LF
      & "<relative type=""0"">fc today</relative>" & ASCII.LF
      & "<relative type=""2"">fc after tomorrow</relative>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</relativeFields>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""fs"">" & ASCII.LF
      & "<relativeFields>" & ASCII.LF
      & "<field type=""day-short"">" & ASCII.LF
      & "<relative type=""1"">fs tomorrow</relative>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</relativeFields>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""ft"">" & ASCII.LF
      & "<relativeFields>" & ASCII.LF
      & "<field type=""duration-day"">" & ASCII.LF
      & "<relativeTime type=""future"">" & ASCII.LF
      & "<relativeTimePattern count=""other"">ft in {0}</relativeTimePattern>" & ASCII.LF
      & "</relativeTime>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</relativeFields>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""fw"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<fields>" & ASCII.LF
      & "<field type=""day"">" & ASCII.LF
      & "<relative type=""0"">fw today</relative>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</fields>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<listPattern locale=""ld"" type=""item""> ; </listPattern>"
      & ASCII.LF
      & "<listPattern locale=""ld"" type=""2"">{0} * {1}</listPattern>"
      & ASCII.LF
      & "<listPattern locale=""ld"" type=""start"">{0} ^ {1}</listPattern>"
      & ASCII.LF
      & "<listPattern locale=""ld"" type=""middle"">{0} ~ {1}</listPattern>"
      & ASCII.LF
      & "<listPattern locale=""ld"" type=""final"">{0} + {1}</listPattern>"
      & ASCII.LF
      & "<listPatternPart locale=""lx"" type=""2"">{0} / {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart locale=""lx"" type=""start"">{0} < {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart locale=""lx"" type=""middle"">{0} = {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart locale=""lx"" type=""end"">{0} > {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart locale=""lo"" listPatternType=""or"" type=""2"">"
      & "{0} lo-or {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart locale=""lo"" listPatternType=""or"" type=""end"">"
      & "{0} lo-end {1}</listPatternPart>"
      & ASCII.LF
      & "<ldml locale=""ly"">" & ASCII.LF
      & "<listPatterns>" & ASCII.LF
      & "<listPattern type=""standard"">" & ASCII.LF
      & "<listPatternPart type=""2"">{0} ly-two {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""start"">{0} ly-start {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""middle"">{0} ly-mid {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""end"">{0} ly-end {1}</listPatternPart>"
      & ASCII.LF
      & "</listPattern>" & ASCII.LF
      & "</listPatterns>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""lu"">" & ASCII.LF
      & "<listPatterns>" & ASCII.LF
      & "<listPattern type=""unit"">" & ASCII.LF
      & "<listPatternPart type=""2"">{0} lu-two {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""start"">{0} lu-start {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""middle"">{0} lu-mid {1}</listPatternPart>"
      & ASCII.LF
      & "<listPatternPart type=""end"">{0} lu-end {1}</listPatternPart>"
      & ASCII.LF
      & "</listPattern>" & ASCII.LF
      & "</listPatterns>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<dateFormat locale=""ld"" type=""long"">MMMM' 'd' 'yyyy</dateFormat>"
      & ASCII.LF
      & "<dateStyle locale=""ds"" style=""short"">yyyy'/'MM'/'dd</dateStyle>"
      & ASCII.LF
      & "<dateStyle locale=""dl"" length=""medium"">dd'.'MM'.'yyyy</dateStyle>"
      & ASCII.LF
      & "<timeStyle locale=""ts"" style=""short"">HH'.'mm</timeStyle>"
      & ASCII.LF
      & "<timeStyle locale=""tl"" length=""medium"">HH'_'mm'_'ss</timeStyle>"
      & ASCII.LF
      & "<dateStyle locale=""dt"" style=""short"">yyyy'-'MM'-'dd</dateStyle>"
      & ASCII.LF
      & "<timeStyle locale=""dt"" style=""short"">HH':'mm</timeStyle>"
      & ASCII.LF
      & "<dateTimeFormat locale=""dt"" type=""short"">{1} @@ {0}</dateTimeFormat>"
      & ASCII.LF
      & "<dateFormatLength locale=""dx"" type=""long"">dd' dx 'MM' dx 'yyyy</dateFormatLength>"
      & ASCII.LF
      & "<timeFormatLength locale=""tx"" type=""long"">HH'-tx-'mm'-tx-'ss</timeFormatLength>"
      & ASCII.LF
      & "<dateFormatLength locale=""dtx"" type=""long"">yyyy'/'MM'/'dd</dateFormatLength>"
      & ASCII.LF
      & "<timeFormatLength locale=""dtx"" type=""long"">HH'.'mm'.'ss</timeFormatLength>"
      & ASCII.LF
      & "<dateTimeFormatLength locale=""dtx"" type=""long"">{1} ## {0}</dateTimeFormatLength>"
      & ASCII.LF
      & "<ldml locale=""ndx"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<dateFormats>" & ASCII.LF
      & "<dateFormatLength type=""full"">" & ASCII.LF
      & "<dateFormat>" & ASCII.LF
      & "<pattern>yyyy' ndx 'MM' ndx 'dd</pattern>" & ASCII.LF
      & "</dateFormat>" & ASCII.LF
      & "</dateFormatLength>" & ASCII.LF
      & "</dateFormats>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""ntx"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<timeFormats>" & ASCII.LF
      & "<timeFormatLength type=""full"">" & ASCII.LF
      & "<timeFormat>" & ASCII.LF
      & "<pattern>HH' ntx 'mm' ntx 'ss</pattern>" & ASCII.LF
      & "</timeFormat>" & ASCII.LF
      & "</timeFormatLength>" & ASCII.LF
      & "</timeFormats>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""ndt"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<dateFormats>" & ASCII.LF
      & "<dateFormatLength type=""full"">" & ASCII.LF
      & "<dateFormat>" & ASCII.LF
      & "<pattern>yyyy'/'MM'/'dd</pattern>" & ASCII.LF
      & "</dateFormat>" & ASCII.LF
      & "</dateFormatLength>" & ASCII.LF
      & "</dateFormats>" & ASCII.LF
      & "<timeFormats>" & ASCII.LF
      & "<timeFormatLength type=""full"">" & ASCII.LF
      & "<timeFormat>" & ASCII.LF
      & "<pattern>HH'+'mm'+'ss</pattern>" & ASCII.LF
      & "</timeFormat>" & ASCII.LF
      & "</timeFormatLength>" & ASCII.LF
      & "</timeFormats>" & ASCII.LF
      & "<dateTimeFormats>" & ASCII.LF
      & "<dateTimeFormatLength type=""full"">" & ASCII.LF
      & "<dateTimeFormat>" & ASCII.LF
      & "<pattern>{1} ++ {0}</pattern>" & ASCII.LF
      & "</dateTimeFormat>" & ASCII.LF
      & "</dateTimeFormatLength>" & ASCII.LF
      & "</dateTimeFormats>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<availableFormat locale=""av"" id=""yMMMd"">yyyy'@'MM'@'dd</availableFormat>"
      & ASCII.LF
      & "<dateFormatItem locale=""df"" skeleton=""yMMMd"">dd'~'MM'~'yyyy</dateFormatItem>"
      & ASCII.LF
      & "<availableFormat locale=""ai"" id=""yyyyMMddHHmm"">yyyyMMddHHmm</availableFormat>"
      & ASCII.LF
      & "<appendItem locale=""ai"" request=""Time"">{0} ~~ {1}</appendItem>"
      & ASCII.LF
      & "<calendarPreference locale=""lp"" calendar=""persian""/>"
      & ASCII.LF
      & "<calendarPreference locale=""ldh"" calendar=""hebrew""/>"
      & ASCII.LF
      & "<calendarPreference locale=""cp"" type=""persian""/>"
      & ASCII.LF
      & "<calendarPreference locale=""ci"" type=""islamicc""/>"
      & ASCII.LF
      & "<calendarPreference locale=""lit"" type=""islamic-tbla""/>"
      & ASCII.LF
      & "<calendarPreference locale=""lea"" type=""ethioaa""/>"
      & ASCII.LF
      & "<calendarPreference locale=""lio"" type=""iso8601""/>"
      & ASCII.LF
      & "<timeZonePreference locale=""lp"" id=""Asia/Kathmandu""/>"
      & ASCII.LF
      & "<timeZonePreference locale=""tz"" zone=""Asia/Kathmandu""/>"
      & ASCII.LF
      & "<numberingSystemPreference locale=""ln"" system=""thai""/>"
      & ASCII.LF
      & "<numberingSystemPreference locale=""lf"" system=""fullwide""/>"
      & ASCII.LF
      & "<numberingSystemPreference locale=""qz"" type=""thai""/>"
      & ASCII.LF
      & "<hourCyclePreference locale=""lh"" cycle=""h12""/>" & ASCII.LF
      & "<hourCyclePreference locale=""hc"" type=""h12""/>" & ASCII.LF
      & "<weekData locale=""ld"" firstDay=""mon"" minDays=""7""/>"
      & ASCII.LF
      & "<weekData locale=""wa"" day=""mon"" count=""7""/>"
      & ASCII.LF
      & "<ldml locale=""wc"">" & ASCII.LF
      & "<weekData>" & ASCII.LF
      & "<firstDay day=""mon""/>" & ASCII.LF
      & "<minDays count=""7""/>" & ASCII.LF
      & "</weekData>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<currencyFormat locale=""ldc"" symbolFirst=""false"""
      & " separator="" ~ "" accountingPrefix=""[["" accountingSuffix=""]]""/>"
      & ASCII.LF
      & "<currencySpacing locale=""lds"" beforeCurrency=""false"""
      & " insertBetween="" / "" accountingPrefix=""{"" accountingSuffix=""}""/>"
      & ASCII.LF
      & "<ldml locale=""lsp"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencySpacing>" & ASCII.LF
      & "<afterCurrency>" & ASCII.LF
      & "<currencyMatch>[[:^S:]&amp;[:^Z:]]</currencyMatch>" & ASCII.LF
      & "<surroundingMatch>[:digit:]</surroundingMatch>" & ASCII.LF
      & "<insertBetween> :: </insertBetween>" & ASCII.LF
      & "</afterCurrency>" & ASCII.LF
      & "</currencySpacing>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""cf"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencyFormatLength>" & ASCII.LF
      & "<currencyFormat type=""standard"">" & ASCII.LF
      & "<pattern>#,##0.00 " & U (16#A4#) & "</pattern>" & ASCII.LF
      & "</currencyFormat>" & ASCII.LF
      & "</currencyFormatLength>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""ca"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencyFormatLength>" & ASCII.LF
      & "<currencyFormat type=""accounting"">" & ASCII.LF
      & "<pattern>#,##0.00 " & U (16#A4#) & ";(#,##0.00 "
      & U (16#A4#) & ")</pattern>" & ASCII.LF
      & "</currencyFormat>" & ASCII.LF
      & "</currencyFormatLength>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "locale.lr.day_period_wide.morning1 = LR morning" & ASCII.LF
      & "locale.lr.day_period_wide.afternoon1 = LR afternoon" & ASCII.LF
      & "locale.lr.day_period_wide.evening1 = LR evening" & ASCII.LF
      & "locale.lr.day_period_wide.night1 = LR night" & ASCII.LF
      & "locale.lr.day_period_rule.morning1 = 04:00-10:00" & ASCII.LF
      & "locale.lr.day_period_rule.afternoon1 = 10:00-15:00" & ASCII.LF
      & "locale.lr.day_period_rule.evening1 = 15:00-21:00" & ASCII.LF
      & "locale.lr.day_period_rule.night1 = 21:00-04:00" & ASCII.LF
      & "locale.lr2.day_period_wide.morning1 = LR2 morning" & ASCII.LF
      & "locale.lr2.day_period_wide.evening1 = LR2 evening" & ASCII.LF
      & "<dayPeriodRule locale=""lr2"" type=""morning1"" from=""05:00"" before=""11:00""/>"
      & ASCII.LF
      & "<dayPeriodRule locale=""lr2"" type=""evening1"" from=""11:00"" before=""05:00""/>"
      & ASCII.LF
      & "locale.lr3.day_period_wide.morning1 = LR3 morning" & ASCII.LF
      & "locale.lr3.day_period_wide.night1 = LR3 night" & ASCII.LF
      & "locale.lr4.day_period_wide.morning1 = LR4 morning" & ASCII.LF
      & "locale.lr4.day_period_wide.night1 = LR4 night" & ASCII.LF
      & "<dayPeriodRuleSet locales=""lr3"">" & ASCII.LF
      & "<dayPeriodRules>" & ASCII.LF
      & "<dayPeriodRule type=""morning1"" from=""06:00"" before=""12:00""/>"
      & ASCII.LF
      & "<dayPeriodRule type=""night1"" from=""22:00"" before=""06:00""/>"
      & ASCII.LF
      & "</dayPeriodRules>" & ASCII.LF
      & "</dayPeriodRuleSet>" & ASCII.LF
      & "<dayPeriodRuleSet locales=""ignored"">" & ASCII.LF
      & "<dayPeriodRules locales=""lr4"">" & ASCII.LF
      & "<dayPeriodRule type=""morning1"" from=""07:00"" before=""12:00""/>"
      & ASCII.LF
      & "<dayPeriodRule type=""night1"" from=""21:00"" before=""07:00""/>"
      & ASCII.LF
      & "</dayPeriodRules>" & ASCII.LF
      & "</dayPeriodRuleSet>" & ASCII.LF
      & "locale.lr5.day_period_wide.midnight = LR5 midnight" & ASCII.LF
      & "locale.lr5.day_period_wide.noon = LR5 noon" & ASCII.LF
      & "locale.lr5.day_period_wide.morning1 = LR5 morning" & ASCII.LF
      & "<dayPeriodRuleSet locales=""lr5"">" & ASCII.LF
      & "<dayPeriodRules>" & ASCII.LF
      & "<dayPeriodRule type=""midnight"" at=""00:00""/>" & ASCII.LF
      & "<dayPeriodRule type=""noon"" at=""12:00""/>" & ASCII.LF
      & "<dayPeriodRule type=""morning1"" at=""06:00""/>" & ASCII.LF
      & "</dayPeriodRules>" & ASCII.LF
      & "</dayPeriodRuleSet>" & ASCII.LF
      & "<zoneName locale=""lp"" id=""Asia/Kathmandu"">LP Time</zoneName>"
      & ASCII.LF
      & "<zoneName locale=""tz"" id=""Asia/Kathmandu"">TZ Time</zoneName>"
      & ASCII.LF
      & "<currency code=""XLD"" minor=""2"" cash=""0"" symbol=""L$"" narrow=""L$"" name=""ld credits""/>"
      & ASCII.LF
      & "<currencyName locale=""ld"" code=""XLD"" category=""other"">ld credits</currencyName>"
      & ASCII.LF
      & "<currency type=""XCM"" digits=""1"" cashRounding=""5"""
      & " symbol=""CM$"" narrow=""CM$"" name=""metadata aliases""/>"
      & ASCII.LF
      & "<currency type=""XCN"" digits=""2"" symbol=""CN$"""
      & " narrowSymbol=""CN!"" displayName=""cldr metadata credits""/>"
      & ASCII.LF
      & "<currencySymbol type=""XSY"">CS$</currencySymbol>"
      & ASCII.LF
      & "<currencySymbol iso4217=""XSY"" alt=""narrow"">C!</currencySymbol>"
      & ASCII.LF
      & "<currency type=""XCC"">" & ASCII.LF
      & "<symbol>CC$</symbol>" & ASCII.LF
      & "<symbol alt=""narrow"">C#</symbol>" & ASCII.LF
      & "</currency>" & ASCII.LF
      & "<ldml locale=""lc"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencies>" & ASCII.LF
      & "<currency type=""XCC"">" & ASCII.LF
      & "<displayName>container credits</displayName>" & ASCII.LF
      & "<displayName count=""one"">one container credit</displayName>"
      & ASCII.LF
      & "</currency>" & ASCII.LF
      & "</currencies>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<currencyFormat locale=""cc"" symbolFirst=""true""/>"
      & ASCII.LF
      & "<currencyFormat locale=""cn"" symbolFirst=""true"" separator="" ""/>"
      & ASCII.LF
      & "<currencyName locale=""lc"" type=""XLD"" count=""one"">one lcredit</currencyName>"
      & ASCII.LF
      & "<currencyName locale=""lc"" type=""XLD"" count=""other"">many lcredits</currencyName>"
      & ASCII.LF
      & "<currencyName locale=""li"" iso4217=""XLD"" count=""other"">iso lcredits</currencyName>"
      & ASCII.LF
      & "<currencyName locale=""le"" code=""XLD"" count=""other"">A &amp; B &#x20AC;</currencyName>"
      & ASCII.LF
      & "<pluralRule locale=""ld"" type=""cardinal"" family=""ar""/>"
      & ASCII.LF
      & "<pluralRule locale=""pk"" kind=""cardinal"" family=""ar""/>"
      & ASCII.LF
      & "<pluralRule locale=""lrp"" type=""cardinal"" count=""few"">"
      & "n mod 10 in 3..4</pluralRule>"
      & ASCII.LF
      & "<pluralRule locale=""lrs"" type=""cardinal"" count=""many"">"
      & "n in 5..7 @integer 5, 6, 7 @decimal 5.0</pluralRule>"
      & ASCII.LF
      & "<plurals type=""cardinal"">" & ASCII.LF
      & "<pluralRules locales=""lpc lpd"">" & ASCII.LF
      & "<pluralRule count=""one"">n is 3</pluralRule>" & ASCII.LF
      & "</pluralRules>" & ASCII.LF
      & "</plurals>" & ASCII.LF
      & "<plurals type=""ordinal"">" & ASCII.LF
      & "<pluralRules locales=""lpo"">" & ASCII.LF
      & "<pluralRule count=""two"">n is 4</pluralRule>" & ASCII.LF
      & "</pluralRules>" & ASCII.LF
      & "</plurals>" & ASCII.LF
      & "<timeZone id=""Ldml/Zone"" offset=""+01:45""/>" & ASCII.LF
      & "<timeZone zone=""Alias/Zone"" offset=""+02:15""/>" & ASCII.LF
      & "<timeZone zone=""Offset/Alias"" gmtOffset=""-03:30""/>"
      & ASCII.LF
      & "<timeZone id=""Compact/Zone"" offset=""+0230""/>" & ASCII.LF
      & "<timeZone id=""Hour/Zone"" utcOffset=""+02""/>" & ASCII.LF
      & "<timeZone id=""SingleHour/Zone"" offset=""+2""/>" & ASCII.LF
      & "<timeZone id=""SingleCompact/Zone"" offset=""+230""/>"
      & ASCII.LF
      & "<timeZone id=""SingleColon/Zone"" offset=""+2:30""/>"
      & ASCII.LF
      & "<timeZone id=""NegativeSingleHour/Zone"" offset=""-2""/>"
      & ASCII.LF
      & "<timeZone id=""NegativeSingleColon/Zone"" offset=""-2:30""/>"
      & ASCII.LF
      & "<timeZone id=""Zulu/Zone"" offset=""Z""/>" & ASCII.LF
      & "<timeZone id=""UtcWord/Zone"" utcOffset=""UTC""/>" & ASCII.LF
      & "<timeZone id=""GmtWord/Zone"" gmtOffset=""GMT""/>" & ASCII.LF
      & "<timeZone id=""LowerZulu/Zone"" offset=""z""/>" & ASCII.LF
      & "<timeZone id=""LowerUtcWord/Zone"" utcOffset=""utc""/>" & ASCII.LF
      & "<timeZone id=""LowerGmtWord/Zone"" gmtOffset=""gmt""/>"
      & ASCII.LF
      & "plural.rule.cardinal.wt.one = w is 0" & ASCII.LF
      & "plural.rule.cardinal.wt.few = t mod 10 is 5" & ASCII.LF
      & "plural.rule.cardinal.wt.many = w is 2 and t mod 10 is 6"
      & ASCII.LF
      & "Zone Tzdb/Fixed -02:30 - TST" & ASCII.LF
      & "Zone Tzdb/Compact +0145 - TCP" & ASCII.LF
      & "Zone Tzdb/SingleHour +2 - TSH" & ASCII.LF
      & "Zone Tzdb/SingleCompact +230 - TSC" & ASCII.LF
      & "Zone Tzdb/SingleColon +2:30 - TSL" & ASCII.LF
      & "Zone Tzdb/NegativeSingleHour -2 - TNH" & ASCII.LF
      & "Zone Tzdb/NegativeSingleCompact -230 - TNC" & ASCII.LF
      & "Zone Tzdb/Zulu Z - TZU" & ASCII.LF
      & "Zone Tzdb/UTCWord UTC - TUC" & ASCII.LF
      & "Zone Tzdb/GMTWord GMT - TGM" & ASCII.LF
      & "Zone Tzdb/LowerZulu z - TLZ" & ASCII.LF
      & "Zone Tzdb/LowerUTCWord utc - TLU" & ASCII.LF
      & "Zone Tzdb/LowerGMTWord gmt - TLG" & ASCII.LF
      & "Zone Tzdb/Seconds +00:19:32 - TSS" & ASCII.LF
      & "Link Tzdb/Seconds Tzdb/SecondsAlias" & ASCII.LF
      & "Zone Tzdb/Until -01:00 - TUT 2026 Jan 04 00:00"
      & ASCII.LF
      & "        +02:00 - TUT" & ASCII.LF
      & "Zone Tzdb/UntilUTC -01:00 - TUU 2026 Jan 04 00:00u"
      & ASCII.LF
      & "        +02:00 - TUU" & ASCII.LF
      & "Zone Tzdb/UntilStandard +01:00 0:30 TUS 2026 Jan 04 02:00s"
      & ASCII.LF
      & "        +02:00 - TUS" & ASCII.LF
      & "Zone Tzdb/UntilYear -01:00 - TUY 2026" & ASCII.LF
      & "        +02:00 - TUY" & ASCII.LF
      & "Zone Tzdb/UntilMonth -01:00 - TUM 2026 Feb" & ASCII.LF
      & "        +02:00 - TUM" & ASCII.LF
      & "Zone Tzdb/UntilDay -01:00 - TUD 2026 Mar 15" & ASCII.LF
      & "        +02:00 - TUD" & ASCII.LF
      & "Zone Tzdb/UntilLastWeekday -01:00 - TUL 2026 Mar lastSun 00:00"
      & ASCII.LF
      & "        +02:00 - TUL" & ASCII.LF
      & "Zone Tzdb/Until24 -01:00 - TU4 2026 Jan 04 24:00"
      & ASCII.LF
      & "        +02:00 - TU4" & ASCII.LF
      & "Zone Tzdb/DirectSave +01:00 0:30 TDS" & ASCII.LF
      & "Zone Tzdb/DirectSaveSeconds +00:10:20 0:00:30 TSS"
      & ASCII.LF
      & "Zone Tzdb/DirectSaveUntil +01:00 0:30 TDU 2026 Jan 04 00:00"
      & ASCII.LF
      & "        +02:00 0:45 TDU" & ASCII.LF
      & "Rule TzRule 2026 only - Apr Sun>=1 00:00u 1:00 D"
      & ASCII.LF
      & "Rule TzRule 2026 only - Oct lastSun 00:00u 0 S"
      & ASCII.LF
      & "Zone Tzdb/RuleZone +01:00 TzRule TRZ" & ASCII.LF
      & "Rule TzRuleMax 2026 max - Nov Sun>=1 00:00u 2:00 D"
      & ASCII.LF
      & "Zone Tzdb/RuleMaxZone +01:00 TzRuleMax TRM" & ASCII.LF
      & "Rule TzRuleStandardWall 2026 only - Apr Sun>=1 02:00s 1:00 D"
      & ASCII.LF
      & "Rule TzRuleStandardWall 2026 only - Oct lastSun 02:00w 0 S"
      & ASCII.LF
      & "Zone Tzdb/RuleStandardWallZone +01:00 TzRuleStandardWall TRW"
      & ASCII.LF
      & "Rule TzRuleOutOfOrder 2026 only - Oct lastSun 02:00w 0 S"
      & ASCII.LF
      & "Rule TzRuleOutOfOrder 2026 only - Apr Sun>=1 02:00s 1:00 D"
      & ASCII.LF
      & "Zone Tzdb/RuleOutOfOrderZone +01:00 TzRuleOutOfOrder TRO"
      & ASCII.LF
      & "Rule TzRuleYearCarry 2026 only - Oct lastSun 02:00s 1:00 D"
      & ASCII.LF
      & "Rule TzRuleYearCarry 2027 only - Mar lastSun 02:00w 0 S"
      & ASCII.LF
      & "Zone Tzdb/RuleYearCarryZone +01:00 TzRuleYearCarry TRY"
      & ASCII.LF
      & "Zone Tzdb/RuleForwardZone +01:00 TzRuleForward TRF"
      & ASCII.LF
      & "Rule TzRuleForward 2026 only - May Sun>=1 00:00u 1:00 D"
      & ASCII.LF
      & "Rule TzRule24 2026 only - Jun 24 24:00u 1:00 D" & ASCII.LF
      & "Zone Tzdb/Rule24Zone +00:00 TzRule24 TR4" & ASCII.LF
      & "Rule TzRuleSeconds 2026 only - Jul 1 00:00u 0:00:30 D"
      & ASCII.LF
      & "Zone Tzdb/RuleSecondsZone +00:10:20 TzRuleSeconds TRS"
      & ASCII.LF
      & "# tzdb full-line comments are ignored" & ASCII.LF
      & "Zone Tzdb/Comment +03:00 - TCM # fixed comment"
      & ASCII.LF
      & "Link Tzdb/Comment Tzdb/CommentAlias # alias comment"
      & ASCII.LF
      & "Zone Tzdb/CommentUntil -01:00 - TCU 2026 Jan 04 00:00 # until comment"
      & ASCII.LF
      & "        +02:00 - TCU # continuation comment" & ASCII.LF
      & "Rule TzComment 2026 only - Apr Sun>=1 00:00u 1:00 D # rule comment"
      & ASCII.LF
      & "Zone Tzdb/CommentRuleZone +01:00 TzComment TCR # rule-zone comment"
      & ASCII.LF
      & "Zone Tzdb/CaseUntil -01:00 - TCU 2026 jan 04 00:00"
      & ASCII.LF
      & "        +02:00 - TCU" & ASCII.LF
      & "Rule TzCase 2026 ONLY - apr sun>=1 00:00U 1:00 D"
      & ASCII.LF
      & "Zone Tzdb/CaseRuleZone +01:00 TzCase TCR" & ASCII.LF
      & "Rule TzYearCase MIN MAX - May Sun>=1 00:00u 0:30 D"
      & ASCII.LF
      & "timezone.Tzdb/Transition.base_offset_minutes = -60" & ASCII.LF
      & "timezone.Tzdb/Transition.transition.20260101000000 = -3600"
      & ASCII.LF
      & "timezone.Tzdb/Transition.transition.2026-01-04T00:00:00Z = 3600"
      & ASCII.LF
      & "Link Tzdb/Fixed Tzdb/Alias" & ASCII.LF);
   Assert
     (Data.Status = I18N.Runtime.Data_Loaded,
      "runtime data text loads"
      & (if I18N.Diagnostics.Length (Data.Diagnostics) = 0
         then ""
         else ": "
           & I18N.Diagnostics.Message_Text
             (I18N.Diagnostics.Element (Data.Diagnostics, 1))));

   I18N.Arguments.Set (Args, "count", "1");
   Assert (Rendered (Runtime, "pr", "items", Args) = "one",
           "runtime plural rule expressions select one branches");
   I18N.Arguments.Set (Args, "count", "22");
   Assert (Rendered (Runtime, "pr-REG", "items", Args) = "few",
           "runtime plural rule expressions use parent locale fallback");
   I18N.Arguments.Set (Args, "count", "11");
   Assert (Rendered (Runtime, "pr", "items", Args) = "many",
           "runtime plural rule expressions evaluate or clauses");
   I18N.Arguments.Set (Args, "count", "2");
   Assert (Rendered (Runtime, "nr", "items", Args) = "two",
           "normalized plural rule expression rows feed rendering");
   I18N.Arguments.Set (Args, "count", "1");
   Assert (Rendered (Runtime, "nq", "items", Args) = "one",
           "normalized plural rule expressions ignore CLDR samples");
   I18N.Arguments.Set (Args, "count", "9");
   Assert (Rendered (Runtime, "nc", "items", Args) = "one",
           "normalized plural rule expressions accept c operand");
   Assert (Rendered (Runtime, "ne", "items", Args) = "few",
           "normalized plural rule expressions accept e operand");
   I18N.Arguments.Set (Args, "count", "13");
   Assert (Rendered (Runtime, "lrp", "items", Args) = "few",
           "LDML pluralRule element text feeds rendering");
   I18N.Arguments.Set (Args, "count", "6");
   Assert (Rendered (Runtime, "lrs", "items", Args) = "many",
           "LDML pluralRule element text ignores CLDR samples");
   I18N.Arguments.Set (Args, "count", "3");
   Assert (Rendered (Runtime, "lpc", "items", Args) = "one",
           "CLDR pluralRules containers feed inherited cardinal rules");
   Assert (Rendered (Runtime, "lpd", "items", Args) = "one",
           "CLDR pluralRules locale lists feed multiple locales");
   I18N.Arguments.Set (Args, "count", "2");
   Assert (Rendered (Runtime, "lpc", "items", Args) = "other",
           "CLDR pluralRules inherited rules still fall back to other");
   I18N.Arguments.Set (Args, "n", "4");
   Assert (Rendered (Runtime, "lpo", "rank", Args) = "two 4",
           "CLDR pluralRules containers feed inherited ordinal rules");
   I18N.Arguments.Set (Args, "count", "1.0");
   Assert (Rendered (Runtime, "wt", "items", Args) = "one",
           "runtime plural rule expressions derive w for zero fractions");
   I18N.Arguments.Set (Args, "count", "1.50");
   Assert (Rendered (Runtime, "wt", "items", Args) = "few",
           "runtime plural rule expressions derive t from trimmed digits");
   I18N.Arguments.Set (Args, "count", "1.06");
   Assert (Rendered (Runtime, "wt", "items", Args) = "many",
           "runtime plural rule expressions preserve leading fraction zeros");

   I18N.Arguments.Set (Args, "v", "1234567.5");
   Assert (Rendered (Runtime, "zz", "num", Args) = "12_34_567|5",
           "runtime number separators and grouping override generated data");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "zz", "words", Args) = "ztwo",
           "runtime RBNF cardinal rows feed spellout formatting");
   I18N.Arguments.Set (Args, "v", "5");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zfive",
           "runtime exact RBNF rows ignore trailing CLDR semicolons");
   I18N.Arguments.Set (Args, "v", "11");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zeleven",
           "runtime RBNF rows normalize CLDR percent rule-set prefixes");
   I18N.Arguments.Set (Args, "v", "13");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zthirteen",
           "runtime literal RBNF rule rows feed exact spellout rows");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "zz", "ordinal_words", Args) = "zsecond",
           "runtime RBNF ordinal rows feed ordinal-word formatting");
   I18N.Arguments.Set (Args, "v", "-2");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zminus-two",
           "runtime RBNF cardinal rows accept exact signed values");
   Assert (Rendered (Runtime, "zz", "ordinal_words", Args) =
             "zminus-second",
           "runtime RBNF ordinal rows accept exact signed values");
   Assert (Rendered (Runtime, "zz-REG", "words", Args) = "zminus-two",
           "runtime signed RBNF rows use parent locale fallback");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldminus-two",
           "LDML RBNF cardinal rows accept exact signed values");
   Assert (Rendered (Runtime, "ld", "ordinal_words", Args) =
             "ldminus-second",
           "LDML RBNF ordinal rows accept exact signed values");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "zz-REG", "words", Args) = "ztwo",
           "runtime RBNF rows use parent locale fallback");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldtwo",
           "LDML RBNF cardinal rows feed spellout formatting");
   I18N.Arguments.Set (Args, "v", "5");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldfive",
           "LDML exact RBNF rows ignore trailing CLDR semicolons");
   I18N.Arguments.Set (Args, "v", "12");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldtwelve",
           "LDML RBNF rows normalize CLDR percent rule-set prefixes");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "ld", "ordinal_words", Args) = "ldsecond",
           "LDML RBNF ordinal rows feed ordinal-word formatting");
   I18N.Arguments.Set (Args, "v", "42");
   Assert (Rendered (Runtime, "zz", "words", Args) = "forty-ztwo",
           "runtime RBNF rule expressions compose remainders");
   I18N.Arguments.Set (Args, "v", "82");
   Assert (Rendered (Runtime, "zz", "words", Args) = "eighty-ztwo",
           "runtime RBNF rule rows ignore trailing CLDR semicolons");
   I18N.Arguments.Set (Args, "v", "402");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "forty ztens ztwo",
           "runtime RBNF rule descriptors honor explicit divisors");
   I18N.Arguments.Set (Args, "v", "702");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "zseven znamed ztwo",
           "runtime RBNF named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "802");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "zeight zascii ztwo",
           "runtime RBNF ASCII named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "902");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "ninth ztarget ztwo",
           "runtime RBNF named substitutions can target ordinal rule sets");
   I18N.Arguments.Set (Args, "v", "992");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "twentieth-zsecond zequal",
           "runtime RBNF equality substitutions can target ordinal rule sets");
   I18N.Arguments.Set (Args, "v", "142");
   Assert (Rendered (Runtime, "zz-REG", "words", Args) =
             "zone zhundred forty-ztwo",
           "runtime RBNF rule expressions use parent locale fallback");
   I18N.Arguments.Set (Args, "v", "22");
   Assert (Rendered (Runtime, "zz", "ordinal_words", Args) =
             "twentieth-zsecond",
           "runtime ordinal RBNF rules compose ordinal remainders");
   I18N.Arguments.Set (Args, "v", "31");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zthirtyst",
           "runtime RBNF plural-affix expressions use ordinal categories");
   I18N.Arguments.Set (Args, "v", "35");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zthirtyfiveth",
           "runtime RBNF plural-affix expressions accept CLDR whitespace");
   I18N.Arguments.Set (Args, "v", "36");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zthirtysix",
           "runtime RBNF plural-affix expressions accept empty branches");
   I18N.Arguments.Set (Args, "v", "-42");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zneg forty-ztwo",
           "runtime RBNF negative rules compose absolute values");
   I18N.Arguments.Set (Args, "v", "42.3");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "forty-ztwo zdecimal three",
           "runtime RBNF decimal rules compose integer and fraction text");
   I18N.Arguments.Set (Args, "v", "0.3");
   Assert (Rendered (Runtime, "zz", "words", Args) = "zzero three",
           "runtime RBNF 0.x decimal rules compose fraction text");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "zz", "words", Args) = "ztwo zwhole",
           "runtime RBNF x.0 decimal rules compose integer text");
   I18N.Arguments.Set (Args, "v", "42");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldforty-ldtwo",
           "LDML RBNF rule expressions compose remainders");
   I18N.Arguments.Set (Args, "v", "9");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldnine",
           "multi-line LDML RBNF rows feed spellout formatting");
   I18N.Arguments.Set (Args, "v", "92");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldninety-ldtwo",
           "multi-line LDML RBNF rule rows compose remainders");
   I18N.Arguments.Set (Args, "v", "62");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldsixty-ldtwo",
           "LDML RBNF arrow remainder substitutions are normalized");
   I18N.Arguments.Set (Args, "v", "82");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldeighty-ldtwo",
           "LDML RBNF rule rows ignore trailing CLDR semicolons");
   I18N.Arguments.Set (Args, "v", "602");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldsix ldred ldtwo",
           "LDML RBNF arrow quotient and triple-remainder substitutions are normalized");
   I18N.Arguments.Set (Args, "v", "402");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldforty ldtens ldtwo",
           "LDML RBNF rule descriptors honor explicit divisors");
   I18N.Arguments.Set (Args, "v", "502");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldfifty ldradix ldtwo",
           "LDML RBNF radix attributes feed explicit divisors");
   I18N.Arguments.Set (Args, "v", "702");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldseven-masculine ldnamed ldtwo",
           "LDML RBNF named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "802");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldeight-lower ldascii ldtwo",
           "LDML RBNF ASCII named substitutions normalize to same-kind substitutions");
   I18N.Arguments.Set (Args, "v", "902");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ninth ldtarget ldtwo",
           "LDML RBNF named substitutions can target ordinal rule sets");
   I18N.Arguments.Set (Args, "v", "992");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "nine hundred ninety-second ldequal",
           "LDML RBNF equality substitutions can target ordinal rule sets");
   I18N.Arguments.Set (Args, "v", "0.3");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldzero three",
           "LDML RBNF 0.x decimal rules compose fraction text");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "ld", "words", Args) = "ldtwo ldwhole",
           "LDML RBNF x.0 decimal rules compose integer text");
   I18N.Arguments.Set (Args, "v", "2.3");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "ztwo zdecimal three",
           "runtime RBNF decimal rule rows feed decimal spellout");
   I18N.Arguments.Set (Args, "v", "-2.3");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "zminus-two-point-three-exact",
           "runtime RBNF decimal rows override full decimal spellout");
   Assert (Rendered (Runtime, "zz-REG", "words", Args) =
             "zminus-two-point-three-exact",
           "runtime RBNF decimal rows use parent locale fallback");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldminus-two-point-three-exact",
           "LDML RBNF decimal rows override full decimal spellout");
   Assert (Rendered (Runtime, "zz", "ordinal_words", Args) =
             "zminus-second-point-three-exact",
           "runtime RBNF ordinal decimal rows override exact ordinal spellout");
   Assert (Rendered (Runtime, "zz-REG", "ordinal_words", Args) =
             "zminus-second-point-three-exact",
           "runtime RBNF ordinal decimal rows use parent locale fallback");
   Assert (Rendered (Runtime, "ld", "ordinal_words", Args) =
             "ldminus-second-point-three-exact",
           "LDML RBNF ordinal decimal rows override exact ordinal spellout");
   I18N.Arguments.Set (Args, "v", "-2.4");
   Assert (Rendered (Runtime, "zz", "words", Args) =
             "zminus-two zpoint four",
           "runtime signed RBNF rows feed negative decimal spellout");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldminus-two point four",
           "LDML signed RBNF rows feed negative decimal spellout");
   I18N.Arguments.Set (Args, "v", "7");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldseven-masculine",
           "LDML RBNF cardinal alias rows normalize to cardinal spellout");
   Assert (Rendered (Runtime, "ld", "ordinal_words", Args) =
             "ldseventh-verbose",
           "LDML RBNF ordinal alias rows normalize to ordinal spellout");
   I18N.Arguments.Set (Args, "v", "8");
   Assert (Rendered (Runtime, "ld", "words", Args) =
             "ldeight-lower",
           "LDML lowercase RBNF rows and ruleset aliases feed spellout");
   I18N.Arguments.Set (Args, "v", "-2");
   Assert (Rendered (Runtime, "um", "words", Args) = "umneg umtwo",
           "runtime RBNF rules accept Unicode minus x descriptors");
   Assert (Rendered (Runtime, "uld", "words", Args) = "uldneg uldtwo",
           "LDML RBNF rules accept Unicode minus x descriptors");

   I18N.Arguments.Set (Args, "m", "12.345");
   Assert (Rendered (Runtime, "zz", "money", Args) = "12|345 @ XT$",
           "runtime currency symbol and minor-unit metadata override generated data");
   I18N.Arguments.Set (Args, "m", "-12.345");
   Assert (Rendered (Runtime, "zz", "money", Args) = "MINUS12|345 @ XT$",
           "runtime minus signs feed negative currency formatting");
   I18N.Arguments.Set (Args, "m", "12.345");
   Assert
     (Rendered (Runtime, "zz", "money_name", Args)
      = "12|345 @ test credits",
      "runtime currency display names override generated data");

   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert
     (Rendered (Runtime, "zz", "day", Args)
      = "OverrideMonth 4 2026",
      "runtime date names and long style override generated data");
   Assert (Rendered (Runtime, "zz", "era", Args) = "ZZAD 2026",
           "runtime era names override generated date data");
   Assert (Rendered (Runtime, "zz", "short_day", Args) = "Om 4",
           "runtime abbreviated month and short style override generated data");
   Assert (Rendered (Runtime, "lw", "weekday", Args) = "2/02/2/02",
           "runtime first-day-of-week preferences feed numeric weekday fields");
   Assert (Rendered (Runtime, "lw", "week", Args) = "2026/2/2",
           "runtime week data feeds week-year skeleton fields");
   Assert (Rendered (Runtime, "lw-REG", "weekday", Args) = "2/02/2/02",
           "runtime first-day-of-week preferences use parent locale fallback");
   Assert (Rendered (Runtime, "lw-REG", "week", Args) = "2026/2/2",
           "runtime week data uses parent locale fallback");

   I18N.Arguments.Set (Args, "t", "07:05");
   Assert (Rendered (Runtime, "zz", "clock", Args) = "07_05",
           "runtime time style override generated data");

   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "en", "instant", Args) = "01_30",
           "runtime fixed timezone offset overrides generated tzdb data");
   Assert (Rendered (Runtime, "zz", "zone_name", Args) = "ZZ Zone",
           "runtime zone display names override generated data");
   Assert (Rendered (Runtime, "zz", "zone_location", Args) =
             "ZZ City|ZZ City Zone",
           "runtime zone exemplar locations override generated data");
   Assert (Rendered (Runtime, "zz", "zone_short", Args) = "ZZS|ZZG",
           "runtime short zone names override generated data");
   Assert (Rendered (Runtime, "zz", "zone_offset", Args) =
             "ZGMTPLUS01^30",
           "runtime zone offset symbols override generated data");
   Assert (Rendered (Runtime, "zz", "zone_zero", Args) = "ZERO",
           "runtime UTC zone designator overrides generated data");

   I18N.Arguments.Set (Args, "v", "1.0");
   Assert (Rendered (Runtime, "zz", "unit", Args) = "1|0~zmeter",
           "runtime unit display names override generated data");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "zz", "unit", Args) = "2|0~zmeters",
           "runtime plural unit display names override generated data");
   I18N.Arguments.Set (Args, "v", "-2.0");
   Assert (Rendered (Runtime, "zz", "unit", Args) = "MINUS2|0~zmeters",
           "runtime minus signs feed domain unit formatting");
   I18N.Arguments.Set (Args, "v", "1");
   Assert (Rendered (Runtime, "du", "unit", Args) = "1~duone",
           "unit formatter uses CLDR one category for integer quantities");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "du", "unit", Args) = "2~dufew",
           "unit formatter uses CLDR few category for integer quantities");
   I18N.Arguments.Set (Args, "v", "1.0");
   Assert (Rendered (Runtime, "du", "unit", Args) = "1|0~dumany",
           "unit formatter uses visible fraction operands for 1.0");
   I18N.Arguments.Set (Args, "v", "1.5");
   Assert (Rendered (Runtime, "du", "unit", Args) = "1|5~dumany",
           "unit formatter uses CLDR decimal operands for unit quantities");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "zz", "relative", Args) = "ztoday",
           "runtime relative current names override generated data");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "zz", "relative", Args) =
             "in-z 2~zdays ahead",
           "runtime relative offset patterns override generated data");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "zz", "list", Args) = "red < green & blue",
           "runtime list start/final separators override generated data");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "zz", "list", Args) = "red + green",
           "runtime list pair separator overrides generated data");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "zz", "list", Args) =
             "red < green = blue & gold",
           "runtime list middle separator overrides generated data");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "zz", "list_or", Args) = "red ?2 green",
           "runtime disjunction list pair separator overrides fallback");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "zz", "list_or", Args) =
             "red ?< green ?= blue ?& gold",
           "runtime disjunction list separators override fallback");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "zz", "list_unit", Args) =
             "red / green // blue",
           "runtime unit list separators override fallback");

   I18N.Arguments.Set (Args, "n", "7");
   Assert (Rendered (Runtime, "zz", "items", Args) = "few 7",
           "runtime cardinal plural categories override generated data");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "zz", "items", Args) = "zero 0",
           "runtime cardinal plural rule-family overrides generated data");

   I18N.Arguments.Set (Args, "n", "9");
   Assert (Rendered (Runtime, "zz", "rank", Args) = "two 9",
           "runtime ordinal plural categories override generated data");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "zz", "rank", Args) = "two 2",
           "runtime ordinal plural rule-family overrides generated data");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "ld", "num", Args) = "1:234|5",
           "LDML symbols feed runtime number formatting");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "ld", "percent", Args) = "12 pct",
           "LDML percent symbols feed runtime number formatting");
   Assert (Rendered (Runtime, "ld", "permille", Args) = "120 pm",
           "LDML per-mille symbols feed runtime number formatting");
   Assert (Rendered (Runtime, "ld", "signed", Args) = "PLUS0|12",
           "LDML plus symbols feed runtime number formatting");
   I18N.Arguments.Set (Args, "v", "-12");
   Assert (Rendered (Runtime, "ld", "accounting", Args) = "[12]",
           "LDML accounting affixes feed runtime number formatting");
   I18N.Arguments.Set (Args, "v", "1234");
   Assert (Rendered (Runtime, "ld", "scientific", Args) = "1|23EXPPLUS3",
           "LDML exponent symbols feed runtime number formatting");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "sy", "num", Args) = "1^234!5",
           "CLDR-shaped decimal/group symbol aliases feed number formatting");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "sy", "percent", Args) = "12 pc",
           "CLDR-shaped percentSign aliases feed number formatting");
   Assert (Rendered (Runtime, "sy", "permille", Args) = "120 pm",
           "CLDR-shaped perMille aliases feed number formatting");
   Assert (Rendered (Runtime, "sy", "signed", Args) = "P0!12",
           "CLDR-shaped plusSign aliases feed number formatting");
   I18N.Arguments.Set (Args, "v", "-12");
   Assert (Rendered (Runtime, "sy", "num", Args) = "M12",
           "CLDR-shaped minusSign aliases feed number formatting");
   Assert (Rendered (Runtime, "sy", "accounting", Args) = "{12}",
           "CLDR-shaped accounting symbol aliases feed number formatting");
   I18N.Arguments.Set (Args, "v", "1234");
   Assert (Rendered (Runtime, "sy", "scientific", Args) = "1!23XP3",
           "CLDR-shaped exponential aliases feed number formatting");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "sc", "num", Args) = "1_234!5",
           "CLDR symbols child decimal/group rows feed number formatting");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "sc", "percent", Args) = "12 pct",
           "CLDR symbols child percentSign row feeds number formatting");
   Assert (Rendered (Runtime, "sc", "permille", Args) = "120 pm",
           "CLDR symbols child perMille row feeds number formatting");
   Assert (Rendered (Runtime, "sc", "signed", Args) = "PLUS0!12",
           "CLDR symbols child plusSign row feeds number formatting");
   I18N.Arguments.Set (Args, "v", "1234");
   Assert (Rendered (Runtime, "sc", "scientific", Args) = "1!23EXPPLUS3",
           "CLDR symbols child exponential row feeds number formatting");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "sd", "num", Args) =
             U (16#0E51#) & "^" & U (16#0E52#) & U (16#0E53#)
             & U (16#0E54#) & "!" & U (16#0E55#),
           "defaultNumberingSystem selects matching CLDR symbols children");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "xe", "num", Args) = "1*234&5",
           "LDML XML entity references decode in symbol attributes");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "xe", "signed", Args) = "<0&12",
           "LDML XML entity references decode in sign attributes");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "xq", "num", Args) = "1_234&5",
           "single-quoted LDML symbol attributes feed number formatting");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "xq", "signed", Args) = "P0&12",
           "single-quoted LDML sign attributes feed number formatting");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "xs", "num", Args) = "1~234!5",
           "spaced LDML symbol attributes feed number formatting");
   I18N.Arguments.Set (Args, "v", "0.12");
   Assert (Rendered (Runtime, "xs", "signed", Args) = "Q0!12",
           "spaced LDML sign attributes feed number formatting");

   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ml", "month", Args) = "MultiMonth",
           "multi-line LDML month rows feed runtime date formatting");
   Assert (Rendered (Runtime, "cd", "month", Args) = "CDATA & Month",
           "LDML CDATA sections decode in supported element text");
   I18N.Arguments.Set (Args, "m", "2");
   Assert (Rendered (Runtime, "ml", "money_name", Args) =
             "2.00 multi credits",
           "multi-line LDML currency-name rows feed currency formatting");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "ml", "unit", Args) = "2 multimeters",
           "multi-line LDML unitPattern rows feed unit formatting");
   I18N.Arguments.Set (Args, "l", "red|blue");
   Assert (Rendered (Runtime, "ml", "list", Args) = "red ml-and blue",
           "multi-line LDML listPatternPart rows feed list formatting");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "cx", "num", Args) = "1^234*5",
           "LDML locale contexts feed symbol rows without locale attributes");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "cx", "month", Args) = "ContextMonth",
           "LDML locale contexts feed name rows without locale attributes");
   I18N.Arguments.Set (Args, "m", "2");
   Assert (Rendered (Runtime, "cx", "money_name", Args) =
             "2*00 context credits",
           "LDML locale contexts feed currency-name rows");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "cx", "unit", Args) = "2 contextmeters",
           "LDML locale contexts feed unitPattern rows");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "ct", "num", Args) = "1~234!5",
           "LDML inert containers allow context symbol rows");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ct", "month", Args) = "ContainerMonth",
           "LDML inert containers allow context month rows");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "ct", "unit", Args) = "2 containermeters",
           "LDML inert containers allow context unitPattern rows");
   I18N.Arguments.Set (Args, "l", "red|blue");
   Assert (Rendered (Runtime, "ct", "list", Args) = "red ct-and blue",
           "LDML inert containers allow context listPatternPart rows");

   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert (Rendered (Runtime, "ix-ZZ", "num", Args) = "1'234?5",
           "LDML identity rows derive locale context for symbols");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ix-ZZ", "month", Args) = "IdentityMonth",
           "LDML identity rows derive locale context for names");
   I18N.Arguments.Set (Args, "d", "2026-01-05");
   Assert (Rendered (Runtime, "ix-ZZ", "weekday", Args) =
             "IdentityMonday",
           "CLDR day rows alias weekday names in identity contexts");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ix-ZZ", "era", Args) = "IXAD 2026",
           "CLDR era width containers allow identity-context era rows");
   I18N.Arguments.Set (Args, "l", "red|blue");
   Assert (Rendered (Runtime, "ix-ZZ", "list", Args) = "red ix-and blue",
           "LDML identity rows derive locale context for list patterns");

   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ld", "day", Args) = "LdMonth 4 2026",
           "LDML date names and formats feed runtime date formatting");
   Assert (Rendered (Runtime, "ds", "day", Args) = "2026/01/04",
           "LDML dateStyle rows feed runtime date styles");
   Assert (Rendered (Runtime, "dl", "day", Args) = "04.01.2026",
           "LDML dateStyle length aliases feed runtime date styles");
   Assert (Rendered (Runtime, "ld", "era", Args) = "LDAD 2026",
           "LDML era names feed runtime date skeleton formatting");
   Assert (Rendered (Runtime, "er", "era", Args) = "ERAD 2026",
           "CLDR-shaped numeric Gregorian era rows feed date skeleton formatting");
   I18N.Arguments.Set (Args, "d", "2024-03-20");
   Assert (Rendered (Runtime, "lp", "calendar", Args) = "AP 1403 01 01",
           "LDML calendar preferences feed runtime date formatting");
   Assert (Rendered (Runtime, "cp", "calendar", Args) = "AP 1403 01 01",
           "CLDR-shaped calendar preference type aliases feed date formatting");
   I18N.Arguments.Set (Args, "d", "2024-03-11");
   Assert (Rendered (Runtime, "ic", "calendar", Args) = "AH 1445 09 01",
           "runtime islamicc calendar preferences feed date formatting");
   Assert (Rendered (Runtime, "ci", "calendar", Args) = "AH 1445 09 01",
           "LDML calendarPreference normalizes islamicc calendar aliases");
   Assert (Rendered (Runtime, "it", "calendar", Args) = "AH 1445 09 02",
           "runtime islamic-tbla calendar preferences feed date formatting");
   Assert (Rendered (Runtime, "lit", "calendar", Args) = "AH 1445 09 02",
           "LDML calendarPreference accepts islamic-tbla calendar aliases");
   I18N.Arguments.Set (Args, "d", "2024-09-11");
   Assert (Rendered (Runtime, "ea", "calendar", Args) = "A.A. 7517 01 01",
           "runtime ethioaa calendar preferences feed date formatting");
   Assert (Rendered (Runtime, "lea", "calendar", Args) = "A.A. 7517 01 01",
           "LDML calendarPreference accepts ethioaa calendar aliases");
   I18N.Arguments.Set (Args, "d", "2021-01-01");
   Assert (Rendered (Runtime, "io", "calendar", Args) =
             "2021 01 01|2020|53|0",
           "runtime ISO8601 default calendar preferences feed week data");
   Assert (Rendered (Runtime, "lio", "calendar", Args) =
             "2021 01 01|2020|53|0",
           "LDML calendarPreference accepts ISO8601 calendar aliases");
   I18N.Arguments.Set (Args, "d", "2023-09-16");
   Assert (Rendered (Runtime, "hb", "calendar", Args) = "AM 5784 01 01",
           "runtime Hebrew default calendar preferences feed date formatting");
   Assert (Rendered (Runtime, "ldh", "calendar", Args) = "AM 5784 01 01",
           "LDML Hebrew calendar preferences feed runtime date formatting");
   I18N.Arguments.Set (Args, "d", "2026-04-04");
   Assert (Rendered (Runtime, "ld", "quarter", Args) = "LdQuarter",
           "LDML quarter names feed runtime date skeleton formatting");
   Assert (Rendered (Runtime, "ld", "short_quarter", Args) = "LQ2",
           "LDML abbreviated quarter names feed runtime date skeleton formatting");
   Assert (Rendered (Runtime, "ld", "narrow_quarter", Args) = "L2",
           "LDML narrow quarter names feed runtime date skeleton formatting");
   I18N.Arguments.Set (Args, "d", "2026-01-05");
   Assert (Rendered (Runtime, "dn", "names", Args) =
             "DNMonth|DNM|DNMonday|DNMon|DNQuarter|DNQ|D1",
           "CLDR-shaped date-name type/width rows feed date skeleton formatting");
   Assert (Rendered (Runtime, "dw", "names", Args) =
             "DWM|DWMon|DWQ|W1",
           "CLDR width containers feed child date-name rows");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "sx", "names", Args) =
             "SX format month|SX standalone month|FM|SM"
             & "|SX format Sunday|SX standalone Sunday|FS|SS"
             & "|SX format quarter"
             & "|SX standalone quarter|F1|S1",
           "CLDR stand-alone date-name contexts feed L, c, and q skeleton fields");
   I18N.Arguments.Set (Args, "t", "13:05");
   Assert (Rendered (Runtime, "ld", "period", Args) = "01 ld-pm",
           "LDML day-period names feed runtime time skeleton formatting");
   Assert (Rendered (Runtime, "dw", "period_widths", Args) =
             "DW aft|DW afternoon|D",
           "CLDR dayPeriodWidth containers feed child day-period rows");
   Assert (Rendered (Runtime, "ts", "clock", Args) = "13.05",
           "LDML timeStyle rows feed runtime time styles");
   I18N.Arguments.Set (Args, "t", "13:05:09");
   Assert (Rendered (Runtime, "tl", "clock", Args) = "13_05_09",
           "LDML timeStyle length aliases feed runtime time styles");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:00Z");
   Assert (Rendered (Runtime, "dt", "instant", Args) =
             "2024-01-02 @@ 03:04",
           "LDML dateTimeFormat rows feed runtime datetime separators");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:30+00:00:30");
   Assert (Rendered (Runtime, "dt", "instant", Args) =
             "2024-01-02 @@ 03:04",
           "timestamp parsing accepts +HH:MM:SS source offsets");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "dx", "day", Args) =
             "04 dx 01 dx 2026",
           "LDML dateFormatLength rows feed runtime date styles");
   I18N.Arguments.Set (Args, "t", "13:05:09");
   Assert (Rendered (Runtime, "tx", "clock", Args) =
             "13-tx-05-tx-09",
           "LDML timeFormatLength rows feed runtime time styles");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:05Z");
   Assert (Rendered (Runtime, "dtx", "instant", Args) =
             "2024/01/02 ## 03.04.05",
           "LDML dateTimeFormatLength rows feed runtime datetime separators");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "ndx", "day", Args) =
             "2026 ndx 01 ndx 04",
           "CLDR nested dateFormat patterns feed runtime date styles");
   I18N.Arguments.Set (Args, "t", "13:05:09");
   Assert (Rendered (Runtime, "ntx", "clock", Args) =
             "13 ntx 05 ntx 09",
           "CLDR nested timeFormat patterns feed runtime time styles");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:05Z");
   Assert (Rendered (Runtime, "ndt", "instant", Args) =
             "2024/01/02 ++ 03+04+05",
           "CLDR nested dateTimeFormat patterns feed runtime datetime styles");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "av", "day", Args) = "2026@01@04",
           "LDML availableFormat rows override skeleton resolution");
   Assert (Rendered (Runtime, "df", "day", Args) = "04~01~2026",
           "LDML dateFormatItem rows alias availableFormat rows");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:00Z");
   Assert (Rendered (Runtime, "ai", "instant", Args) =
             "2024 01 02 ~~ 03:04",
           "LDML appendItem rows feed date/time skeleton separators");
   I18N.Arguments.Set (Args, "t", "12:00:00");
   Assert (Rendered (Runtime, "ld", "noon", Args) = "12 ld-noon",
           "LDML wide flexible day-period names feed runtime time skeleton formatting");
   I18N.Arguments.Set (Args, "t", "03:59");
   Assert (Rendered (Runtime, "lr", "period", Args) = "LR night",
           "runtime day-period rules support wraparound ranges");
   I18N.Arguments.Set (Args, "t", "04:00");
   Assert (Rendered (Runtime, "lr", "period", Args) = "LR morning",
           "runtime day-period rules use half-open range starts");
   I18N.Arguments.Set (Args, "t", "14:59");
   Assert (Rendered (Runtime, "lr", "period", Args) = "LR afternoon",
           "runtime day-period rules can shift afternoon boundaries");
   I18N.Arguments.Set (Args, "t", "15:00");
   Assert (Rendered (Runtime, "lr-REG", "period", Args) = "LR evening",
           "runtime day-period rules use parent locale fallback");
   I18N.Arguments.Set (Args, "t", "05:00");
   Assert (Rendered (Runtime, "lr2", "period", Args) = "LR2 morning",
           "LDML dayPeriodRule rows feed flexible day-period formatting");
   I18N.Arguments.Set (Args, "t", "23:00");
   Assert (Rendered (Runtime, "lr2", "period", Args) = "LR2 evening",
           "LDML dayPeriodRule rows support wraparound ranges");
   I18N.Arguments.Set (Args, "t", "06:00");
   Assert (Rendered (Runtime, "lr3", "period", Args) = "LR3 morning",
           "CLDR dayPeriodRuleSet locales feed child dayPeriodRule rows");
   I18N.Arguments.Set (Args, "t", "23:00");
   Assert (Rendered (Runtime, "lr3", "period", Args) = "LR3 night",
           "CLDR dayPeriodRules inherit outer dayPeriodRuleSet locales");
   I18N.Arguments.Set (Args, "t", "07:00");
   Assert (Rendered (Runtime, "lr4", "period", Args) = "LR4 morning",
           "CLDR dayPeriodRules locales override outer rule-set locales");
   I18N.Arguments.Set (Args, "t", "22:00");
   Assert (Rendered (Runtime, "lr4", "period", Args) = "LR4 night",
           "CLDR dayPeriodRules locale lists support wraparound ranges");
   I18N.Arguments.Set (Args, "t", "00:00");
   Assert (Rendered (Runtime, "lr5", "period", Args) = "LR5 midnight",
           "CLDR dayPeriodRule at rows accept exact midnight");
   I18N.Arguments.Set (Args, "t", "12:00");
   Assert (Rendered (Runtime, "lr5", "period", Args) = "LR5 noon",
           "CLDR dayPeriodRule at rows accept exact noon");
   I18N.Arguments.Set (Args, "t", "06:00");
   Assert (Rendered (Runtime, "lr5", "period", Args) = "LR5 morning",
           "CLDR dayPeriodRule at rows accept exact flexible periods");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "ld", "zone_name", Args) = "LD Zone",
           "LDML zone display names feed runtime time skeleton formatting");
   Assert (Rendered (Runtime, "ld", "zone_location", Args) =
             "LD City|LD LD City",
           "LDML zone exemplar names feed runtime time skeleton formatting");
   Assert (Rendered (Runtime, "ld", "zone_short", Args) = "LDS|LDG",
           "LDML short zone names feed runtime time skeleton formatting");
   Assert (Rendered (Runtime, "gf", "zone_offset", Args) =
             "GMT~+01_30",
           "LDML GMT/hour format rows feed runtime offset formatting");
   Assert (Rendered (Runtime, "gf", "zone_zero", Args) = "ZERO~",
           "LDML GMT zero format rows feed UTC zone designators");
   Assert (Rendered (Runtime, "ty", "zone_name", Args) =
             "TY Zone|TYS|TYG",
           "typed LDML zoneName rows feed long and short zone names");
   Assert (Rendered (Runtime, "zt", "zone_name", Args) =
             "ZT Standard Zone",
           "typed LDML zoneName rows feed long standard zone names");
   Assert (Rendered (Runtime, "rs", "zone_name", Args) =
             "RS Standard RS City",
           "typed LDML regionFormat rows feed standard zone fallbacks");
   Assert (Rendered (Runtime, "zs", "zone_short", Args) = "ZSS",
           "typed LDML zoneName rows accept short-standard aliases");
   Assert (Rendered (Runtime, "zg", "zone_generic", Args) = "ZGG",
           "typed LDML zoneName rows accept camelCase shortGeneric aliases");
   I18N.Arguments.Set (Args, "i", "2026-07-04T12:00:00Z");
   Assert (Rendered (Runtime, "zd", "zone_daylight", Args) = "ZDD",
           "typed LDML zoneName rows accept camelCase daylightShort aliases");
   Assert (Rendered (Runtime, "zc", "zone_name", Args) =
             "ZC Daylight|ZCD|ZCG",
           "CLDR zone containers feed daylight and generic short names");
   Assert (Rendered (Runtime, "zc", "zone_location", Args) =
             "ZC City|ZC ZC City",
           "CLDR zone containers feed exemplarCity rows without zone attributes");
   Assert (Rendered (Runtime, "zy", "zone_name", Args) =
             "ZY Daylight Zone",
           "typed LDML zoneName rows feed long daylight zone names");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "zc", "zone_name", Args) =
             "ZC Standard|ZCS|ZCG",
           "CLDR zone containers feed standard and generic names");
   Assert (Rendered (Runtime, "za", "zone_name", Args) = "Alias Zone",
           "LDML zoneName rows accept zone aliases");
   Assert (Rendered (Runtime, "za", "zone_location", Args) =
             "Alias City|Alias Alias City",
           "LDML zoneExemplar rows accept zone aliases");
   Assert (Rendered (Runtime, "rf", "zone_location", Args) =
             "RF City|RF RF City",
           "LDML regionFormat rows feed generic location patterns");
   Assert (Rendered (Runtime, "ec", "zone_location", Args) =
             "EC City|EC EC City",
           "LDML exemplarCity rows alias zoneExemplar rows");
   Assert (Rendered (Runtime, "za", "zone_short", Args) = "AZS|AZG",
           "LDML short-zone rows accept zone aliases");
   Assert (Rendered (Runtime, "zn", "zone_name", Args) =
             "TZ Alias Zone|TZN",
           "LDML timeZoneName rows alias zoneName rows");
   Assert (Rendered (Runtime, "sa", "zone_standard_alias", Args) = "SAS",
           "LDML zoneShortStandard rows feed short standard zone names");
   Assert (Rendered (Runtime, "sb", "zone_standard_alias", Args) = "SBS",
           "LDML zoneStandardShort rows feed short standard zone names");
   Assert (Rendered (Runtime, "sc", "zone_generic_alias", Args) = "SCG",
           "LDML zoneShortGeneric rows feed short generic zone names");
   I18N.Arguments.Set (Args, "i", "2026-07-04T12:00:00Z");
   Assert (Rendered (Runtime, "se", "zone_daylight_alias", Args) = "SED",
           "LDML zoneDaylightShort rows feed short daylight zone names");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "za", "zone_time", Args) = "02_15",
           "LDML timeZone rows accept zone aliases for fixed offsets");
   Assert (Rendered (Runtime, "zo", "zone_time", Args) = "20_30",
           "LDML timeZone rows accept gmtOffset aliases for fixed offsets");
   Assert (Rendered (Runtime, "lp", "default_time", Args) = "05_45",
           "LDML time-zone preferences feed runtime instant conversion");
   Assert (Rendered (Runtime, "lp", "default_zone", Args) = "LP Time",
           "LDML time-zone preferences feed runtime zone-name skeletons");
   Assert (Rendered (Runtime, "tz", "default_time", Args) = "05_45",
           "CLDR-shaped time-zone preference zone aliases feed instant conversion");
   Assert (Rendered (Runtime, "tz", "default_zone", Args) = "TZ Time",
           "CLDR-shaped time-zone preference aliases feed zone-name skeletons");
   I18N.Arguments.Set (Args, "v", "1.0");
   Assert (Rendered (Runtime, "ld", "unit", Args) = "1|0 ldmeter",
           "LDML unit names feed runtime unit formatting");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "ld", "unit", Args) = "2|0 ldmeters",
           "LDML plural unit names feed runtime unit formatting");
   I18N.Arguments.Set (Args, "v", "3.0");
   Assert (Rendered (Runtime, "ld", "unit", Args) = "3|0 ldfewmeters",
           "LDML few-count unit names feed runtime unit formatting");
   I18N.Arguments.Set (Args, "v", "1.0");
   Assert (Rendered (Runtime, "la", "unit", Args) = "1.0 alias meter",
           "LDML unit aliases feed canonical full-width unit names");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "la", "unit", Args) = "2.0 alias meters",
           "LDML unit aliases feed canonical plural unit names");
   Assert (Rendered (Runtime, "la", "short_unit", Args) = "2.0 alias L",
           "LDML unit width aliases feed canonical short unit names");
   Assert (Rendered (Runtime, "la", "pattern_unit", Args) =
             "alias grams 2.0",
           "LDML unitPattern aliases feed canonical unit patterns");
   I18N.Arguments.Set (Args, "v", "1");
   Assert (Rendered (Runtime, "ut", "unit", Args) = "1 typed meters",
           "CLDR-shaped unitName type aliases feed canonical unit names");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "ut", "unit", Args) = "2.0 typed meters",
           "CLDR-shaped unitName type aliases feed plural unit names");
   Assert (Rendered (Runtime, "ut", "pattern_unit", Args) =
             "typed grams 2.0",
           "CLDR-shaped unitPattern type aliases feed unit patterns");
   Assert (Rendered (Runtime, "ud", "unit", Args) =
             "2.0 display meters",
           "CLDR-shaped unitDisplayName rows feed other unit names");
   Assert (Rendered (Runtime, "un", "unit", Args) =
             "2.0 countless meters",
           "LDML unitName rows without count feed other unit names");
   I18N.Arguments.Set (Args, "v", "1");
   Assert (Rendered (Runtime, "en-UC", "unit", Args) =
             "1 context meter",
           "CLDR unit containers feed singular unitPattern rows");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "en-UC", "unit", Args) =
             "2.0 context meters",
           "CLDR unit containers feed plural unitPattern rows");
   Assert (Rendered (Runtime, "en-UC", "short_unit", Args) =
             "2.0 ctx m",
           "CLDR unitLength containers feed short unitPattern rows");
   Assert (Rendered (Runtime, "cu", "rate", Args) =
             "2.0 meters PER second",
           "LDML compoundUnitPattern rows feed per-unit separators");
   Assert (Rendered (Runtime, "cs", "rate", Args) =
             "2,0 m/s",
           "LDML compoundUnitPattern short rows feed short per-unit separators");
   Assert (Rendered (Runtime, "cp", "rate", Args) =
             "2.0 meters CPER second",
           "CLDR compoundUnit containers feed long per-unit separators");
   Assert (Rendered (Runtime, "cp", "short_rate", Args) =
             "2.0 m~s",
           "CLDR compoundUnit containers inherit short unitLength width");
   I18N.Arguments.Set (Args, "v", "1");
   Assert (Rendered (Runtime, "lu", "unit", Args) =
             "1 lupattern-meter",
           "LDML unitPattern rows feed runtime unit names");
   I18N.Arguments.Set (Args, "v", "11");
   Assert (Rendered (Runtime, "lu", "unit", Args) =
             "lupattern-meters 11",
           "LDML unitPattern type aliases feed reordered unit patterns");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "ld", "relative", Args) = "ldtoday",
           "LDML relative current names feed runtime relative formatting");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "ld", "relative", Args) =
             "after 2 lddays later",
           "LDML relative patterns feed runtime relative formatting");
   I18N.Arguments.Set (Args, "n", "3");
   Assert (Rendered (Runtime, "ld", "relative", Args) =
             "after 3 ldfewdays later",
           "LDML few-count relative unit names feed runtime formatting");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rr", "relative", Args) =
             "rr after 2 rrdays",
           "LDML relativePattern element text feeds future affixes");
   I18N.Arguments.Set (Args, "n", "-2");
   Assert (Rendered (Runtime, "rr", "relative", Args) =
             "2 rrdays rr before",
           "LDML relativePattern element text feeds past affixes");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "rt", "relative", Args) = "rttoday",
           "LDML relativePeriod rows feed runtime relative formatting");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rt", "relative", Args) =
             "after 2 rtdays",
           "LDML relativeTimePattern future rows feed relative formatting");
   I18N.Arguments.Set (Args, "n", "-2");
   Assert (Rendered (Runtime, "rt", "relative", Args) =
             "2 rtdays before",
           "LDML relativeTimePattern past rows feed relative formatting");
   I18N.Arguments.Set (Args, "n", "1");
   Assert (Rendered (Runtime, "rp", "relative", Args) = "rp tomorrowish",
           "LDML unit/count relativeTimePattern rows can omit placeholders");
   I18N.Arguments.Set (Args, "n", "11");
   Assert (Rendered (Runtime, "rp", "relative", Args) = "rp after 11",
           "LDML unit/count relativeTimePattern rows fall back to other");
   I18N.Arguments.Set (Args, "n", "-11");
   Assert (Rendered (Runtime, "rp", "relative", Args) = "rp 11 before",
           "LDML unit/count relativeTimePattern past rows render directly");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "du", "relative", Args) = "du today",
           "CLDR duration relativePeriod unit aliases feed current periods");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "du", "relative", Args) = "du after 2",
           "CLDR duration relativeTimePattern unit aliases render directly");
   I18N.Arguments.Set (Args, "n", "-2");
   Assert (Rendered (Runtime, "du", "relative", Args) = "du 2 ago",
           "CLDR duration relativeTimePattern aliases render past rows");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "dv", "relative", Args) =
             "dv after 2 dv days",
           "CLDR duration relativeUnit aliases feed unit display names");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "dr", "relative", Args) = "dr today",
           "CLDR-shaped relativePeriod type aliases feed current periods");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "dr", "relative", Args) = "dr after 2",
           "CLDR-shaped relativeUnit type aliases feed unit display names");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "ra", "relative", Args) = "ra after 2",
           "LDML relativeTimePattern relativeUnit aliases select direct patterns");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rw", "relative_short", Args) =
             "rw after 2",
           "LDML relativeTimePattern unitWidth aliases select direct widths");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rx", "relative", Args) = "rx after 2",
           "LDML relativeTime rows alias direct relativeTimePattern rows");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "ry", "relative", Args) =
             "ry after 2 rydays",
           "LDML relativeTime rows alias relative affix patterns");
   I18N.Arguments.Set (Args, "n", "-1");
   Assert (Rendered (Runtime, "fc", "relative", Args) = "fc yesterday",
           "CLDR field relative rows feed exact past relative offsets");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "fc", "relative", Args) = "fc today",
           "CLDR field relative rows feed exact current relative offsets");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "fc", "relative", Args) =
             "fc after tomorrow",
           "CLDR field relative rows feed exact future relative offsets");
   I18N.Arguments.Set (Args, "n", "1");
   Assert (Rendered (Runtime, "fs", "relative_short", Args) =
             "fs tomorrow",
           "CLDR short field relative rows preserve relative width");
   I18N.Arguments.Set (Args, "n", "3");
   Assert (Rendered (Runtime, "ft", "relative", Args) = "ft in 3",
           "CLDR field relativeTime containers feed child patterns");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "fw", "relative", Args) = "fw today",
           "CLDR fields containers wrap relative field rows");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "ld", "list", Args) = "red ^ green + blue",
           "LDML start/final list patterns feed runtime list formatting");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "ld", "list", Args) = "red * green",
           "LDML two-item list patterns feed runtime list formatting");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "ld", "list", Args) =
             "red ^ green ~ blue + gold",
           "LDML middle list patterns feed runtime list formatting");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "lx", "list", Args) = "red / green",
           "LDML listPatternPart two-item rows feed list formatting");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "lx", "list", Args) = "red < green > blue",
           "LDML listPatternPart start/end rows feed list formatting");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "lx", "list", Args) =
             "red < green = blue > gold",
           "LDML listPatternPart middle rows feed list formatting");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "ly", "list", Args) = "red ly-two green",
           "CLDR listPattern standard containers feed two-item lists");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "ly", "list", Args) =
             "red ly-start green ly-mid blue ly-end gold",
           "CLDR listPattern standard containers feed multi-item lists");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "lo", "list_or", Args) = "red lo-or green",
           "LDML listPatternType or rows feed disjunction lists");
   I18N.Arguments.Set (Args, "l", "red|green|blue");
   Assert (Rendered (Runtime, "lo", "list_or", Args) =
             "red, green lo-end blue",
           "LDML listPatternType or end rows override final separator");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "lu", "list_unit", Args) =
             "red lu-two green",
           "CLDR listPattern unit containers feed two-item unit lists");
   I18N.Arguments.Set (Args, "l", "red|green|blue|gold");
   Assert (Rendered (Runtime, "lu", "list_unit", Args) =
             "red lu-start green lu-mid blue lu-end gold",
           "CLDR listPattern unit containers feed multi-item unit lists");
   I18N.Arguments.Set (Args, "m", "2");
   Assert (Rendered (Runtime, "ld", "money_name", Args) = "2|00 ld credits",
           "LDML currency metadata feeds runtime currency formatting");
   Assert (Rendered (Runtime, "lc", "money_name", Args) =
             "2.00 many lcredits",
           "CLDR-shaped currencyName type/count aliases feed currency names");
   Assert (Rendered (Runtime, "li", "money_name", Args) =
             "2.00 iso lcredits",
           "CLDR-shaped currencyName iso4217 aliases feed currency names");
   Assert (Rendered (Runtime, "le", "money_name", Args) =
             "2.00 A & B " & U (16#20AC#),
           "LDML XML entity references decode in element text");
   I18N.Arguments.Set (Args, "m", "1");
   Assert (Rendered (Runtime, "lc", "money_name", Args) =
             "1.00 one lcredit",
           "CLDR-shaped currencyName count aliases use plural categories");
   I18N.Arguments.Set (Args, "m", "12.3");
   Assert (Rendered (Runtime, "cm", "money_name", Args) =
             "12.3 metadata aliases",
           "CLDR-shaped currency metadata aliases feed minor units and names");
   Assert (Rendered (Runtime, "cn", "money_narrow", Args) =
             "CN!12.30",
           "CLDR-shaped currency narrowSymbol alias feeds narrow symbols");
   Assert (Rendered (Runtime, "cn", "money_name", Args) =
             "12.30 cldr metadata credits",
           "CLDR-shaped currency displayName alias feeds display names");
   Assert (Rendered (Runtime, "cn", "money_symbol", Args) =
             "CS$12.30",
           "CLDR-shaped currencySymbol rows feed standard symbols");
   Assert (Rendered (Runtime, "cn", "money_symbol_narrow", Args) =
             "C!12.30",
           "CLDR-shaped currencySymbol alt=narrow feeds narrow symbols");
   Assert (Rendered (Runtime, "cc", "money_symbol", Args) =
             "CC$12.30",
           "CLDR currency containers feed inherited symbol rows");
   Assert (Rendered (Runtime, "cc", "money_symbol_narrow", Args) =
             "C#12.30",
           "CLDR currency containers feed inherited narrow symbol rows");
   Assert (Rendered (Runtime, "lc", "money_container_name", Args) =
             "12.30 container credits",
           "CLDR currency containers feed inherited display-name rows");
   I18N.Arguments.Set (Args, "m", "1");
   Assert (Rendered (Runtime, "lc", "money_container_name", Args) =
             "1.00 one container credit",
           "CLDR currency containers feed inherited plural display names");
   I18N.Arguments.Set (Args, "m", "12.3");
   Assert (Rendered (Runtime, "ldc", "money", Args) = "12.300 ~ XT$",
           "LDML currency-format rows feed currency placement and spacing");
   I18N.Arguments.Set (Args, "m", "-12.3");
   Assert (Rendered (Runtime, "ldc", "accounting", Args) =
             "[[12.300 ~ XT$]]",
           "LDML currency-format rows feed accounting affixes");
   I18N.Arguments.Set (Args, "m", "12.3");
   Assert (Rendered (Runtime, "lds", "money", Args) = "12.300 / XT$",
           "LDML currency-spacing rows feed currency placement and spacing");
   I18N.Arguments.Set (Args, "m", "-12.3");
   Assert (Rendered (Runtime, "lds", "accounting", Args) =
             "{12.300 / XT$}",
           "LDML currency-spacing rows feed accounting affixes");
   Assert (Rendered (Runtime, "lsp", "accounting", Args) =
             "(12.300 :: XT$)",
           "CLDR currencySpacing containers feed amount separators");
   I18N.Arguments.Set (Args, "m", "12.3");
   Assert (Rendered (Runtime, "cf", "money", Args) = "12.300 XT$",
           "CLDR currencyFormat pattern containers feed placement and spacing");
   I18N.Arguments.Set (Args, "m", "-12.3");
   Assert (Rendered (Runtime, "ca", "accounting", Args) =
             "(12,300 XT$)",
           "CLDR currencyFormat accounting patterns feed affixes");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert
     (Rendered (Runtime, "ln", "num", Args)
      = U (16#E51#) & "." & U (16#E52#) & U (16#E53#)
        & U (16#E54#) & "," & U (16#E55#),
      "LDML numbering-system preferences feed runtime number digits");
   Assert
     (Rendered (Runtime, "qz", "num", Args)
      = U (16#E51#) & "," & U (16#E52#) & U (16#E53#)
        & U (16#E54#) & "." & U (16#E55#),
      "CLDR-shaped numbering-system preference type aliases feed number digits");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert
     (Rendered (Runtime, "ln", "date", Args)
      = U (16#E52#) & U (16#E50#) & U (16#E52#) & U (16#E56#)
        & " " & U (16#E50#) & U (16#E51#)
        & " " & U (16#E50#) & U (16#E54#),
      "LDML numbering-system preferences feed runtime date digits");
   Assert
     (Rendered (Runtime, "qz", "date", Args)
      = U (16#E52#) & U (16#E50#) & U (16#E52#) & U (16#E56#)
        & " " & U (16#E50#) & U (16#E51#)
        & " " & U (16#E50#) & U (16#E54#),
      "CLDR-shaped numbering-system preference aliases feed date digits");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Assert
     (Rendered (Runtime, "lf", "num", Args)
      = U (16#FF11#) & "," & U (16#FF12#) & U (16#FF13#)
        & U (16#FF14#) & "." & U (16#FF15#),
      "generated numbering-system preferences feed runtime number digits");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert
     (Rendered (Runtime, "lf", "date", Args)
      = U (16#FF12#) & U (16#FF10#) & U (16#FF12#) & U (16#FF16#)
        & " " & U (16#FF10#) & U (16#FF11#)
        & " " & U (16#FF10#) & U (16#FF14#),
      "generated numbering-system preferences feed runtime date digits");
   Assert (Rendered (Runtime, "ld", "weekday_numeric", Args) = "7/07/7/07",
           "LDML week data feeds numeric local weekday fields");
   Assert (Rendered (Runtime, "ld", "week_year", Args) = "2025/52/0",
           "LDML week data min-days feeds week-year skeleton fields");
   Assert (Rendered (Runtime, "wa", "weekday_numeric", Args) = "7/07/7/07",
           "CLDR-shaped weekData day alias feeds numeric weekday fields");
   Assert (Rendered (Runtime, "wa", "week_year", Args) = "2025/52/0",
           "CLDR-shaped weekData count alias feeds week-year skeleton fields");
   Assert (Rendered (Runtime, "wc", "weekday_numeric", Args) = "7/07/7/07",
           "CLDR-shaped firstDay child rows feed numeric weekday fields");
   Assert (Rendered (Runtime, "wc", "week_year", Args) = "2025/52/0",
           "CLDR-shaped minDays child rows feed week-year skeleton fields");
   I18N.Arguments.Set (Args, "t", "15:05");
   Assert (Rendered (Runtime, "lh", "pref", Args) = "3 PM",
           "LDML hour-cycle preferences feed preferred-hour skeletons");
   Assert (Rendered (Runtime, "hc", "pref", Args) = "3 PM",
           "CLDR-shaped hour-cycle preference type aliases feed preferred-hour skeletons");
   Assert (Rendered (Runtime, "lh-u-hc-h23", "pref", Args) = "15",
           "explicit hour-cycle extensions override LDML preferences");
   I18N.Arguments.Set (Args, "n", "0");
   Assert (Rendered (Runtime, "ld", "items", Args) = "zero 0",
           "LDML plural-rule family aliases feed runtime plural formatting");
   Assert (Rendered (Runtime, "pk", "items", Args) = "zero 0",
           "LDML plural-rule kind aliases feed runtime plural formatting");
   Assert (Rendered (Runtime, "en", "ldml_instant", Args) = "01_45",
           "LDML fixed time-zone rows feed runtime time formatting");
   Assert (Rendered (Runtime, "en", "ldml_compact_instant", Args) =
             "02_30",
           "LDML fixed time-zone rows accept compact +HHMM offsets");
   Assert (Rendered (Runtime, "en", "ldml_hour_instant", Args) = "02_00",
           "LDML fixed time-zone rows accept compact +HH offsets");
   Assert (Rendered (Runtime, "en", "ldml_single_hour_instant", Args) =
             "02_00",
           "LDML fixed time-zone rows accept +H offsets");
   Assert (Rendered (Runtime, "en", "ldml_single_compact_instant", Args) =
             "02_30",
           "LDML fixed time-zone rows accept +HMM offsets");
   Assert (Rendered (Runtime, "en", "ldml_single_colon_instant", Args) =
             "02_30",
           "LDML fixed time-zone rows accept +H:MM offsets");
   Assert (Rendered (Runtime, "en", "ldml_negative_single_hour_instant", Args) =
             "22_00",
           "LDML fixed time-zone rows accept -H offsets");
   Assert (Rendered (Runtime, "en", "ldml_negative_single_colon_instant", Args) =
             "21_30",
           "LDML fixed time-zone rows accept -H:MM offsets");
   Assert (Rendered (Runtime, "en", "ldml_zulu_instant", Args) = "00_00",
           "LDML fixed time-zone rows accept Z zero offsets");
   Assert (Rendered (Runtime, "en", "ldml_utc_word_instant", Args) =
             "00_00",
           "LDML fixed time-zone rows accept UTC zero offsets");
   Assert (Rendered (Runtime, "en", "ldml_gmt_word_instant", Args) =
             "00_00",
           "LDML fixed time-zone rows accept GMT zero offsets");
   Assert (Rendered (Runtime, "en", "ldml_lower_zulu_instant", Args) =
             "00_00",
           "LDML fixed time-zone rows accept lowercase z zero offsets");
   Assert (Rendered (Runtime, "en", "ldml_lower_utc_word_instant", Args) =
             "00_00",
           "LDML fixed time-zone rows accept lowercase utc zero offsets");
   Assert (Rendered (Runtime, "en", "ldml_lower_gmt_word_instant", Args) =
             "00_00",
           "LDML fixed time-zone rows accept lowercase gmt zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_instant", Args) = "21_30",
           "tzdb Zone rows feed runtime time formatting");
   Assert (Rendered (Runtime, "en", "tzdb_compact_instant", Args) =
             "01_45",
           "tzdb Zone rows accept compact +HHMM fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_single_hour_instant", Args) =
             "02_00",
           "tzdb Zone rows accept +H fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_single_compact_instant", Args) =
             "02_30",
           "tzdb Zone rows accept +HMM fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_single_colon_instant", Args) =
             "02_30",
           "tzdb Zone rows accept +H:MM fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_negative_single_hour_instant", Args) =
             "22_00",
           "tzdb Zone rows accept -H fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_negative_single_compact_instant", Args) =
             "21_30",
           "tzdb Zone rows accept -HMM fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_zulu_instant", Args) =
             "00_00",
           "tzdb Zone rows accept Z zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_utc_word_instant", Args) =
             "00_00",
           "tzdb Zone rows accept UTC zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_gmt_word_instant", Args) =
             "00_00",
           "tzdb Zone rows accept GMT zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_lower_zulu_instant", Args) =
             "00_00",
           "tzdb Zone rows accept lowercase z zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_lower_utc_word_instant", Args) =
             "00_00",
           "tzdb Zone rows accept lowercase utc zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_lower_gmt_word_instant", Args) =
             "00_00",
           "tzdb Zone rows accept lowercase gmt zero offsets");
   Assert (Rendered (Runtime, "en", "tzdb_alias_instant", Args) = "21_30",
           "tzdb Link rows alias loaded fixed-zone offsets");
   Assert (Rendered (Runtime, "en", "tzdb_seconds_instant", Args) =
             "00_19_32",
           "tzdb Zone rows preserve second-precision fixed offsets");
   Assert (Rendered (Runtime, "en", "tzdb_seconds_alias_instant", Args) =
             "00_19_32",
           "tzdb Link rows alias second-precision fixed offsets");
   Assert
     (Rendered (Runtime, "en", "tzdb_direct_save_seconds_instant", Args) =
        "00_10_50",
      "tzdb Zone rows preserve second-precision direct SAVE offsets");
   Assert (Rendered (Runtime, "en", "tzdb_until_instant", Args) = "23_00",
           "tzdb Zone suffixless until times use wall time");
   Assert (Rendered (Runtime, "en", "tzdb_until_utc_instant", Args) =
             "02_00",
           "tzdb Zone UTC until suffixes apply at UTC transition time");
   Assert (Rendered (Runtime, "en", "tzdb_until_standard_instant", Args) =
             "01_30",
           "tzdb Zone standard-time until suffixes preserve pre-transition");
   I18N.Arguments.Set (Args, "i", "2026-01-04T01:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_standard_instant", Args) =
             "03_00",
           "tzdb Zone standard-time until suffixes apply at standard time");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_year_instant", Args) =
             "02_00",
           "tzdb Zone continuation rows default missing month/day/time");
   Assert (Rendered (Runtime, "tr", "instant", Args) = "01_00",
           "runtime time-zone transitions override generated instant offsets");
   I18N.Arguments.Set (Args, "i", "2026-02-01T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_month_instant", Args) =
             "23_00",
           "tzdb Zone continuation rows default missing day/time as wall time");
   I18N.Arguments.Set (Args, "i", "2026-01-03T23:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_instant", Args) = "22_30",
           "tzdb Zone continuation rows preserve the pre-until offset");
   Assert (Rendered (Runtime, "en", "tzdb_until_month_instant", Args) =
             "22_30",
           "tzdb Zone continuation rows preserve pre-defaulted-month offsets");
   Assert (Rendered (Runtime, "tr", "instant", Args) = "22_30",
           "runtime time-zone transitions use the nearest earlier offset");
   I18N.Arguments.Set (Args, "i", "2026-03-15T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_day_instant", Args) =
             "23_00",
           "tzdb Zone continuation rows default missing time as wall time");
   I18N.Arguments.Set (Args, "i", "2026-03-14T23:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_until_day_instant", Args) =
             "22_30",
           "tzdb Zone continuation rows preserve pre-defaulted-day offsets");
   I18N.Arguments.Set (Args, "i", "2026-03-29T00:00:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_until_last_weekday_instant", Args) =
        "23_00",
      "tzdb Zone continuation rows accept last-weekday wall-time until days");
   I18N.Arguments.Set (Args, "i", "2026-03-28T23:30:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_until_last_weekday_instant", Args) =
        "22_30",
      "tzdb Zone continuation rows preserve pre-last-weekday offsets");
   I18N.Arguments.Set (Args, "i", "2026-01-05T00:30:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_until_24_instant", Args) =
        "23_30",
      "tzdb Zone continuation rows treat 24:00 as end of the local day");
   I18N.Arguments.Set (Args, "i", "2026-01-05T01:00:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_until_24_instant", Args) =
        "03_00",
      "tzdb Zone continuation rows apply transitions after normalized 24:00");
   I18N.Arguments.Set (Args, "i", "2026-01-01T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_direct_save_instant", Args) =
             "01_30",
           "tzdb Zone rows apply direct SAVE offsets");
   I18N.Arguments.Set (Args, "i", "2026-01-03T22:00:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_direct_save_until_instant", Args) =
        "23_30",
      "tzdb Zone continuation rows preserve pre-until direct SAVE offsets");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert
     (Rendered (Runtime, "en", "tzdb_direct_save_until_instant", Args) =
        "02_45",
      "tzdb Zone continuation rows apply direct SAVE transition offsets");
   I18N.Arguments.Set (Args, "i", "2026-04-05T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_instant", Args) =
             "02_30",
           "tzdb Rule weekday-on-or-after rows feed fixed-zone transitions");
   I18N.Arguments.Set (Args, "i", "2026-10-25T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_instant", Args) =
             "01_30",
           "tzdb Rule last-weekday rows restore standard fixed-zone offsets");
   I18N.Arguments.Set (Args, "i", "2027-11-07T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_max_instant", Args) =
             "03_30",
           "tzdb Rule max year rows apply within bounded tzdb window");
   I18N.Arguments.Set (Args, "i", "2026-04-05T01:30:00Z");
   Assert
     (Rendered
        (Runtime, "en", "tzdb_rule_standard_wall_instant", Args) =
          "03_30",
      "tzdb Rule standard-time AT rows shift by base offset");
   I18N.Arguments.Set (Args, "i", "2026-10-25T00:30:00Z");
   Assert
     (Rendered
        (Runtime, "en", "tzdb_rule_standard_wall_instant", Args) =
          "01_30",
      "tzdb Rule wall-time AT rows shift by prior save");
   Assert
     (Rendered
        (Runtime, "en", "tzdb_rule_out_of_order_instant", Args) =
          "01_30",
      "tzdb Rule application sorts source rows before wall-time offsets");
   I18N.Arguments.Set (Args, "i", "2027-03-28T00:30:00Z");
   Assert
     (Rendered
        (Runtime, "en", "tzdb_rule_year_carry_instant", Args) =
          "01_30",
      "tzdb Rule wall-time offsets carry prior SAVE across years");
   I18N.Arguments.Set (Args, "i", "2026-05-03T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_forward_instant", Args) =
             "02_30",
           "tzdb Zone rows can reference later bounded Rule rows");
   I18N.Arguments.Set (Args, "i", "2026-06-24T23:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_24_instant", Args) =
             "23_30",
           "tzdb Rule rows preserve the pre-24:00 transition offset");
   I18N.Arguments.Set (Args, "i", "2026-06-25T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_24_instant", Args) =
             "01_00",
           "tzdb Rule rows normalize 24:00 transition times");
   I18N.Arguments.Set (Args, "i", "2026-07-01T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_rule_seconds_instant", Args) =
             "00_10_50",
           "tzdb Rule SAVE fields preserve second-precision offsets");
   I18N.Arguments.Set (Args, "i", "2026-01-01T00:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_comment_instant", Args) =
             "03_00",
           "tzdb Zone rows ignore trailing comments");
   Assert (Rendered (Runtime, "en", "tzdb_comment_alias_instant", Args) =
             "03_00",
           "tzdb Link rows ignore trailing comments");
   Assert (Rendered (Runtime, "en", "tzdb_comment_until_instant", Args) =
             "23_00",
           "tzdb Zone until rows ignore trailing comments");
   I18N.Arguments.Set (Args, "i", "2026-01-04T01:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_comment_until_instant", Args) =
             "03_00",
           "tzdb Zone continuation rows ignore trailing comments");
   I18N.Arguments.Set (Args, "i", "2026-04-05T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_comment_rule_instant", Args) =
             "02_30",
           "tzdb Rule rows ignore trailing comments");
   I18N.Arguments.Set (Args, "i", "2026-01-04T01:00:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_case_until_instant", Args) =
             "03_00",
           "tzdb Zone until rows accept lowercase month names");
   I18N.Arguments.Set (Args, "i", "2026-04-05T00:30:00Z");
   Assert (Rendered (Runtime, "en", "tzdb_case_rule_instant", Args) =
             "02_30",
           "tzdb Rule rows accept lowercase month and weekday names");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-runtime-data",
      "locale.zz.decimal_separator = ?" & ASCII.LF
      & "locale.zz.unknown = bad" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed runtime data is rejected");
   I18N.Arguments.Set (Args, "v", "1234567.5");
   Assert (Rendered (Runtime, "zz", "num", Args) = "12_34_567|5",
           "failed runtime data load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-plural-container-data",
      "<plurals>" & ASCII.LF
      & "<pluralRules locales=""bad"">" & ASCII.LF
      & "<pluralRule count=""one"">n is 1</pluralRule>" & ASCII.LF
      & "</pluralRules>" & ASCII.LF
      & "</plurals>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR pluralRules containers are rejected");
   I18N.Arguments.Set (Args, "count", "3");
   Assert (Rendered (Runtime, "lpc", "items", Args) = "one",
           "failed CLDR pluralRules load leaves previous data intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-data",
      "rbnf.bad.cardinal.-1000000000 = invalid" & ASCII.LF
      & "rbnf.bad.ordinal.1. = invalid" & ASCII.LF
      & "rbnf.bad.%.2 = invalid" & ASCII.LF
      & "rbnf.bad.cardinal.3 = ;" & ASCII.LF
      & "rbnf_rule.bad.cardinal.20 = literal" & ASCII.LF
      & "rbnf_rule.bad.cardinal.21 = ;" & ASCII.LF
      & "rbnf_rule.bad.cardinal.22/0 = bad[->>]" & ASCII.LF
      & "rbnf_rule.bad.cardinal.23 = " & U (16#2190#)
      & "%spellout-cardinal broken" & ASCII.LF
      & "rbnf_rule.bad.cardinal.24 = <%spellout-cardinal broken"
      & ASCII.LF
      & "rbnf_rule.bad.cardinal.25 = <%< bad" & ASCII.LF
      & "rbnf_rule.bad.cardinal.26 = " & U (16#2190#)
      & "%" & U (16#2190#) & " bad" & ASCII.LF
      & "rbnf_rule.bad.cardinal.negative = literal" & ASCII.LF
      & "<rbnf locale=""bad"" type=""spellout-cardinal"" value=""2"">"
      & ASCII.LF
      & "bad-two" & ASCII.LF
      & "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"""
      & " value=""20"">" & ASCII.LF
      & "badtwenty[->>]" & ASCII.LF
      & "</rbnfRule>" & ASCII.LF
      & "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"""
      & " value=""30"" radix=""0"">badthirty[->>]</rbnfRule>"
      & ASCII.LF
      & "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"""
      & " value=""30"">" & ASCII.LF
      & "badthirty[->>]" & ASCII.LF
      & "</rbnf>" & ASCII.LF
      & "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"""
      & " value=""40"">" & ASCII.LF
      & "</rbnfRule>" & ASCII.LF
      & "<rbnf locale=""bad"" type=""spellout-cardinal"" value=""50"">"
      & ASCII.LF
      & "badfifty" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed RBNF runtime data and blocks are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-grouped-descriptor",
      "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"""
      & " value=""20,00"">badtwenty[->>]</rbnfRule>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed grouped RBNF descriptors are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-plural-affix-missing-other",
      "rbnf_rule.bad.cardinal.30 = bad$(ordinal,one{st})$"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "RBNF plural-affix rows require an other branch");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-plural-affix-category",
      "rbnf_rule.bad.cardinal.31 = bad$(ordinal,some{st}other{th})$"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "RBNF plural-affix rows reject unknown branch names");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-plural-affix-unclosed",
      "rbnf_rule.bad.cardinal.32 = bad$(ordinal,one{st}other{th}"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "RBNF plural-affix rows reject unterminated expressions");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "zz", "words", Args) = "ztwo",
           "failed grouped RBNF descriptor load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-rbnf-inline-descriptor",
      "<rbnfRule locale=""bad"" ruleSet=""spellout-cardinal"">"
      & "20,00: badtwenty[->>]</rbnfRule>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed inline RBNF descriptors are rejected");
   Assert (Rendered (Runtime, "zz", "words", Args) = "ztwo",
           "failed inline RBNF descriptor load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-block-data",
      "<month locale=""bad"" type=""wide"" index=""1"">" & ASCII.LF
      & "<weekday locale=""bad"" type=""mon"" width=""wide"">"
      & ASCII.LF
      & "BadMonday" & ASCII.LF
      & "</weekday>" & ASCII.LF
      & "<currencyName locale=""bad"" type=""BAD"" count=""other"">"
      & ASCII.LF
      & "bad credits" & ASCII.LF
      & "</currencySymbol>" & ASCII.LF
      & "<unitPattern locale=""bad"" unit=""meter"""
      & " width=""unit-width-full-name"" count=""other"">"
      & ASCII.LF
      & "</unitPattern>" & ASCII.LF
      & "<listPatternPart locale=""bad"" type=""2"">" & ASCII.LF
      & "{0} and {1}" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed multi-line LDML blocks are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-cdata-data",
      "<month locale=""bad"" type=""wide"" index=""1"">"
      & "<![CDATA[BadMonth</month>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML CDATA sections are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-context-data",
      "<ldml type=""main"">" & ASCII.LF
      & "<symbols decimal=""."" group="",""/>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""bad"">" & ASCII.LF
      & "<locale id=""nested"">" & ASCII.LF
      & "</locale>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml locale=""open"">" & ASCII.LF
      & "<symbols decimal=""."" group="",""/>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML locale contexts are rejected");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-week-data",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<weekData>" & ASCII.LF
      & "<firstDay day=""funday""/>" & ASCII.LF
      & "<minDays count=""8""/>" & ASCII.LF
      & "</weekData>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR firstDay/minDays child rows are rejected");
   Assert (Rendered (Runtime, "wc", "week_year", Args) = "2025/52/0",
           "failed CLDR weekData child load leaves previous data intact");
   I18N.Arguments.Set (Args, "v", "1234.5");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-symbol-child-data",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<defaultNumberingSystem>roman</defaultNumberingSystem>"
      & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "unsupported LDML defaultNumberingSystem rows are rejected");
   Assert (Rendered (Runtime, "sd", "num", Args) =
             U (16#0E51#) & "^" & U (16#0E52#) & U (16#0E53#)
             & U (16#0E54#) & "!" & U (16#0E55#),
           "failed defaultNumberingSystem load leaves previous data intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-selected-symbol-data",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<defaultNumberingSystem>latn</defaultNumberingSystem>"
      & ASCII.LF
      & "<symbols numberSystem=""latn"">" & ASCII.LF
      & "<decimal></decimal>" & ASCII.LF
      & "<group>,</group>" & ASCII.LF
      & "</symbols>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "empty selected LDML symbol child rows are rejected");
   Assert (Rendered (Runtime, "sc", "num", Args) = "1_234!5",
           "failed selected symbol child load leaves previous data intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-xml-declaration-data",
      "<?xml version=""1.0""" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed XML declarations are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-xml-comment-data",
      "<!-- unterminated" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed XML comments are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-identity-data",
      "<ldml>" & ASCII.LF
      & "<identity>" & ASCII.LF
      & "<territory type=""ZZ""/>" & ASCII.LF
      & "</identity>" & ASCII.LF
      & "<symbols decimal=""."" group="",""/>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "<ldml>" & ASCII.LF
      & "<identity>" & ASCII.LF
      & "<language/>" & ASCII.LF
      & "</identity>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML identity locale contexts are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-container-data",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</ldml>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "<ldml locale=""open"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<symbols decimal=""."" group="",""/>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML inert containers are rejected");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-list-pattern-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<listPatterns>" & ASCII.LF
      & "<listPattern type=""unknown"">" & ASCII.LF
      & "<listPatternPart type=""2"">{0} bad {1}</listPatternPart>"
      & ASCII.LF
      & "</listPattern>" & ASCII.LF
      & "</listPatterns>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "unsupported CLDR listPattern container types are rejected");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "ly", "list", Args) = "red ly-two green",
           "failed CLDR listPattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-day-alias-data",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<days>" & ASCII.LF
      & "<dayContext type=""format"">" & ASCII.LF
      & "<dayWidth type=""wide"">" & ASCII.LF
      & "<day type=""not-a-weekday"">Bad Day</day>" & ASCII.LF
      & "</dayWidth>" & ASCII.LF
      & "</dayContext>" & ASCII.LF
      & "</days>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR day alias rows are rejected");
   I18N.Arguments.Set (Args, "v", "2");
   Assert (Rendered (Runtime, "zz", "words", Args) = "ztwo",
           "failed RBNF data load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-timezone-data",
      "<timeZone id=""Bad/Zone"" offset=""+2360""/>" & ASCII.LF
      & "Zone Tzdb/Bad +24 - BAD" & ASCII.LF
      & "Zone Tzdb/BadUntil +01:00 - BAD 2026 Foo 01" & ASCII.LF
      & "        +02:00 - BAD" & ASCII.LF
      & "Rule BadRule 2026 only - Apr Sun>=32 00:00u 1:00 D"
      & ASCII.LF
      & "timezone.Tzdb/Transition.transition.2026-02-30T00:00:00Z = 0"
      & ASCII.LF
      & "timezone.Tzdb/Transition.transition.20260201000000 = 90000"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed fixed offsets and transition rows are rejected");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "en", "ldml_compact_instant", Args) =
             "02_30",
           "failed fixed time-zone data load leaves previous overrides intact");
   Assert (Rendered (Runtime, "tr", "instant", Args) = "01_00",
           "failed transition data load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-tzdb-24-data",
      "Zone Tzdb/BadUntil24 +01:00 - BAD 2026 Jan 01 24:01"
      & ASCII.LF
      & "Rule BadRule24 2026 only - Jan 01 24:01u 1:00 D"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed tzdb 24:01 transition times are rejected");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "tr", "instant", Args) = "01_00",
           "failed malformed 24-hour tzdb load leaves overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-tzdb-second-offset-data",
      "Zone Tzdb/BadSecond +00:00:60 - BAD" & ASCII.LF
      & "Rule BadSecondRule 2026 only - Jan 01 00:00u 0:00:60 D"
      & ASCII.LF
      & "timezone.Tzdb/BadSecond.base_offset_seconds = 90000"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed tzdb second-precision offsets are rejected");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "tr", "instant", Args) = "01_00",
           "failed malformed second-offset load leaves overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-list-pattern",
      "<listPattern locale=""bad"" type=""2"">{0} only</listPattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML list pattern is rejected");
   I18N.Arguments.Set (Args, "l", "red|green");
   Assert (Rendered (Runtime, "ld", "list", Args) = "red * green",
           "failed list-pattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-date-time-format",
      "<dateTimeFormat locale=""bad"" type=""short"">{0} @@ {1}</dateTimeFormat>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML dateTimeFormat rows are rejected");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:00Z");
   Assert (Rendered (Runtime, "dt", "instant", Args) =
             "2024-01-02 @@ 03:04",
           "failed dateTimeFormat load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-date-time-format-length",
      "<dateTimeFormatLength locale=""bad"" type=""long"">{0} ## {1}</dateTimeFormatLength>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML dateTimeFormatLength rows are rejected");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:05Z");
   Assert (Rendered (Runtime, "dtx", "instant", Args) =
             "2024/01/02 ## 03.04.05",
           "failed dateTimeFormatLength load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-date-time-format-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<dates>" & ASCII.LF
      & "<calendars>" & ASCII.LF
      & "<calendar type=""gregorian"">" & ASCII.LF
      & "<dateTimeFormats>" & ASCII.LF
      & "<dateTimeFormatLength type=""full"">" & ASCII.LF
      & "<dateTimeFormat>" & ASCII.LF
      & "<pattern>{0} bad {1}</pattern>" & ASCII.LF
      & "</dateTimeFormat>" & ASCII.LF
      & "</dateTimeFormatLength>" & ASCII.LF
      & "</dateTimeFormats>" & ASCII.LF
      & "</calendar>" & ASCII.LF
      & "</calendars>" & ASCII.LF
      & "</dates>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR dateTimeFormat containers are rejected");
   Assert (Rendered (Runtime, "ndt", "instant", Args) =
             "2024/01/02 ++ 03+04+05",
           "failed CLDR dateTimeFormat load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-available-format",
      "<availableFormat locale=""bad"">yyyy</availableFormat>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML availableFormat rows are rejected");
   I18N.Arguments.Set (Args, "d", "2026-01-04");
   Assert (Rendered (Runtime, "av", "day", Args) = "2026@01@04",
           "failed availableFormat load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-date-format-item",
      "<dateFormatItem locale=""bad"">yyyy</dateFormatItem>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML dateFormatItem rows are rejected");
   Assert (Rendered (Runtime, "df", "day", Args) = "04~01~2026",
           "failed dateFormatItem load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-append-item",
      "<appendItem locale=""bad"" request=""Time"">{1} ~~ {0}</appendItem>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML appendItem rows are rejected");
   I18N.Arguments.Set (Args, "i", "2024-01-02T03:04:00Z");
   Assert (Rendered (Runtime, "ai", "instant", Args) =
             "2024 01 02 ~~ 03:04",
           "failed appendItem load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-unit-pattern",
      "<unitPattern locale=""bad"" unit=""meter"" count=""other"">{0} meters {0}</unitPattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML unitPattern rows are rejected");
   I18N.Arguments.Set (Args, "v", "11");
   Assert (Rendered (Runtime, "lu", "unit", Args) =
             "lupattern-meters 11",
           "failed unitPattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-unit-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<units>" & ASCII.LF
      & "<unitLength type=""long"">" & ASCII.LF
      & "<unitPattern count=""other"">{0} bad units</unitPattern>"
      & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "</units>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR unit containers are rejected");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "en-UC", "unit", Args) =
             "2.0 context meters",
           "failed CLDR unit container load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-unit-display-name",
      "<unitDisplayName locale=""bad"" type=""unsupported-unit"">bad units</unitDisplayName>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML unitDisplayName rows are rejected");
   I18N.Arguments.Set (Args, "v", "2.0");
   Assert (Rendered (Runtime, "ud", "unit", Args) =
             "2.0 display meters",
           "failed unitDisplayName load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-compound-unit-pattern",
      "<compoundUnitPattern locale=""bad"" type=""per"">{1} PER {0}</compoundUnitPattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML compoundUnitPattern rows are rejected");
   Assert (Rendered (Runtime, "cu", "rate", Args) =
             "2.0 meters PER second",
           "failed compoundUnitPattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-compound-unit-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<units>" & ASCII.LF
      & "<unitLength type=""long"">" & ASCII.LF
      & "<compoundUnit>" & ASCII.LF
      & "<compoundUnitPattern>{0} bad {1}</compoundUnitPattern>"
      & ASCII.LF
      & "</compoundUnit>" & ASCII.LF
      & "</unitLength>" & ASCII.LF
      & "</units>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR compoundUnit containers are rejected");
   Assert (Rendered (Runtime, "cp", "rate", Args) =
             "2.0 meters CPER second",
           "failed CLDR compoundUnit load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-relative-time-pattern",
      "<relativeTimePattern locale=""bad"" type=""future"">later</relativeTimePattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML relativeTimePattern rows are rejected");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rt", "relative", Args) =
             "after 2 rtdays",
           "failed relativeTimePattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-direct-relative-time-pattern",
      "<relativeTimePattern locale=""bad"" unit=""day"" count=""other"""
      & " type=""future"">{0} then {0}</relativeTimePattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed direct LDML relativeTimePattern rows are rejected");
   I18N.Arguments.Set (Args, "n", "11");
   Assert (Rendered (Runtime, "rp", "relative", Args) = "rp after 11",
           "failed direct relativeTimePattern load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-direct-relative-time",
      "<relativeTime locale=""bad"" unit=""day"" count=""other"""
      & " type=""future"">{0} then {0}</relativeTime>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed direct LDML relativeTime rows are rejected");
   I18N.Arguments.Set (Args, "n", "2");
   Assert (Rendered (Runtime, "rx", "relative", Args) = "rx after 2",
           "failed direct relativeTime load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-relative-field",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<relativeFields>" & ASCII.LF
      & "<field type=""unsupported"">" & ASCII.LF
      & "<relative type=""1"">bad future</relative>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</relativeFields>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR relative field containers are rejected");
   I18N.Arguments.Set (Args, "n", "-1");
   Assert (Rendered (Runtime, "fc", "relative", Args) = "fc yesterday",
           "failed CLDR relative field load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-relative-time-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<relativeFields>" & ASCII.LF
      & "<field type=""day"">" & ASCII.LF
      & "<relativeTime type=""future"">" & ASCII.LF
      & "<relativeTimePattern count=""other"">{0} then {0}</relativeTimePattern>"
      & ASCII.LF
      & "</relativeTime>" & ASCII.LF
      & "</field>" & ASCII.LF
      & "</relativeFields>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR relativeTime containers are rejected");
   I18N.Arguments.Set (Args, "n", "3");
   Assert (Rendered (Runtime, "ft", "relative", Args) = "ft in 3",
           "failed CLDR relativeTime load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-zone-exemplar",
      "<zoneExemplar locale=""bad"" id=""Bad/Zone""></zoneExemplar>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML zone exemplar is rejected");
   I18N.Arguments.Set (Args, "i", "2026-01-04T00:00:00Z");
   Assert (Rendered (Runtime, "ld", "zone_location", Args) =
             "LD City|LD LD City",
           "failed zone-exemplar load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-short-zone",
      "<zoneShort locale=""bad"" id=""Bad/Zone""></zoneShort>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML short zone name is rejected");
   Assert (Rendered (Runtime, "ld", "zone_short", Args) = "LDS|LDG",
           "failed short-zone load leaves previous overrides intact");
   Data := I18N.Runtime.Load_Data_Text
     ("bad-short-zone-alias",
      "<zoneShortStandard locale=""bad"" zone=""Bad/Zone""></zoneShortStandard>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML short zone-name aliases are rejected");
   Assert (Rendered (Runtime, "sa", "zone_standard_alias", Args) = "SAS",
           "failed short-zone alias load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-zone-name-type",
      "<zoneName locale=""bad"" id=""Bad/Zone"" type=""bogus"">Bad</zoneName>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "unknown LDML zoneName type is rejected");
   Assert (Rendered (Runtime, "ty", "zone_name", Args) =
             "TY Zone|TYS|TYG",
           "failed typed zoneName load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-zone-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<timeZoneNames>" & ASCII.LF
      & "<long>" & ASCII.LF
      & "<generic>Bad Zone</generic>" & ASCII.LF
      & "</long>" & ASCII.LF
      & "</timeZoneNames>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR zone containers are rejected");
   Assert (Rendered (Runtime, "zc", "zone_name", Args) =
             "ZC Standard|ZCS|ZCG",
           "failed CLDR zone container load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-gmt-format",
      "<gmtFormat locale=""bad"">{0} GMT</gmtFormat>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "unsupported LDML gmtFormat placement is rejected");
   Assert (Rendered (Runtime, "gf", "zone_offset", Args) =
             "GMT~+01_30",
           "failed gmtFormat load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-region-format",
      "<regionFormat locale=""bad"" type=""bogus"">Bad {0}</regionFormat>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "unsupported LDML regionFormat types are rejected");
   Assert (Rendered (Runtime, "rf", "zone_location", Args) =
             "RF City|RF RF City",
           "failed regionFormat load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-exemplar-city",
      "<exemplarCity locale=""bad"" zone=""Bad/Zone""></exemplarCity>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML exemplarCity rows are rejected");
   Assert (Rendered (Runtime, "ec", "zone_location", Args) =
             "EC City|EC EC City",
           "failed exemplarCity load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-day-period-rule",
      "locale.lr.day_period_rule.morning1 = 25:00-26:00" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed runtime day-period rule is rejected");
   I18N.Arguments.Set (Args, "t", "04:00");
   Assert (Rendered (Runtime, "lr", "period", Args) = "LR morning",
           "failed day-period rule load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-day-period-rule",
      "<dayPeriodRule locale=""lr2"" type=""morning1"" from=""11:00"" before=""11:00""/>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML dayPeriodRule row is rejected");
   I18N.Arguments.Set (Args, "t", "05:00");
   Assert (Rendered (Runtime, "lr2", "period", Args) = "LR2 morning",
           "failed LDML dayPeriodRule load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-day-period-rules-container",
      "<dayPeriodRuleSet locales=""lr3"">" & ASCII.LF
      & "<dayPeriodRules>" & ASCII.LF
      & "<dayPeriodRule type=""morning1"" from=""12:00"" before=""12:00""/>"
      & ASCII.LF
      & "</dayPeriodRules>" & ASCII.LF
      & "</dayPeriodRuleSet>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR dayPeriodRules containers are rejected");
   I18N.Arguments.Set (Args, "t", "06:00");
   Assert (Rendered (Runtime, "lr3", "period", Args) = "LR3 morning",
           "failed CLDR dayPeriodRules load leaves overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-ldml-day-period-at-time",
      "<dayPeriodRuleSet locales=""lr5"">" & ASCII.LF
      & "<dayPeriodRules>" & ASCII.LF
      & "<dayPeriodRule type=""morning1"" at=""25:00""/>" & ASCII.LF
      & "</dayPeriodRules>" & ASCII.LF
      & "</dayPeriodRuleSet>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR dayPeriodRule at rows are rejected");
   I18N.Arguments.Set (Args, "t", "00:00");
   Assert (Rendered (Runtime, "lr5", "period", Args) = "LR5 midnight",
           "failed CLDR dayPeriodRule at load leaves overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-zone-location-pattern",
      "<zoneLocationPattern locale=""bad"">Zone</zoneLocationPattern>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML zone location pattern is rejected");
   Assert (Rendered (Runtime, "ld", "zone_location", Args) =
             "LD City|LD LD City",
           "failed zone-location-pattern load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-format",
      "<currencyFormat locale=""bad"" symbolFirst=""maybe""/>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML currency-format rows are rejected");
   I18N.Arguments.Set (Args, "m", "-12.3");
   Assert (Rendered (Runtime, "ldc", "accounting", Args) =
             "[[12.300 ~ XT$]]",
           "failed currency-format load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-spacing",
      "<currencySpacing locale=""bad"" beforeCurrency=""maybe""/>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML currency-spacing rows are rejected");
   Assert (Rendered (Runtime, "lds", "accounting", Args) =
             "{12.300 / XT$}",
           "failed currency-spacing load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-spacing-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencySpacing>" & ASCII.LF
      & "<insertBetween> bad </insertBetween>" & ASCII.LF
      & "</currencySpacing>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR currencySpacing containers are rejected");
   Assert (Rendered (Runtime, "lsp", "accounting", Args) =
             "(12.300 :: XT$)",
           "failed CLDR currencySpacing load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-spacing-match",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencySpacing>" & ASCII.LF
      & "<currencyMatch>[:digit:]</currencyMatch>" & ASCII.LF
      & "</currencySpacing>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "orphan CLDR currencySpacing match rows are rejected");
   Assert (Rendered (Runtime, "lsp", "accounting", Args) =
             "(12.300 :: XT$)",
           "failed CLDR currencySpacing match load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-pattern-container",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencyFormats>" & ASCII.LF
      & "<currencyFormatLength>" & ASCII.LF
      & "<currencyFormat type=""accounting"">" & ASCII.LF
      & "<pattern>#,##0.00 " & U (16#A4#) & "</pattern>" & ASCII.LF
      & "</currencyFormat>" & ASCII.LF
      & "</currencyFormatLength>" & ASCII.LF
      & "</currencyFormats>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR currency pattern containers are rejected");
   Assert (Rendered (Runtime, "ca", "accounting", Args) =
             "(12,300 XT$)",
           "failed CLDR currency pattern load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-currency-symbol",
      "<currencySymbol type=""XBD"" alt=""bogus"">BD$</currencySymbol>"
      & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed LDML currency-symbol rows are rejected");
   I18N.Arguments.Set (Args, "m", "12.3");
   Assert (Rendered (Runtime, "cn", "money_symbol", Args) =
             "CS$12.30",
           "failed currency-symbol load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-currency-container",
      "<currency>" & ASCII.LF
      & "<symbol>BD$</symbol>" & ASCII.LF
      & "</currency>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR currency containers are rejected");
   Assert (Rendered (Runtime, "cc", "money_symbol", Args) =
             "CC$12.30",
           "failed CLDR currency container load leaves previous overrides intact");

   Data := I18N.Runtime.Load_Data_Text
     ("bad-cldr-currency-display-name",
      "<ldml locale=""bad"">" & ASCII.LF
      & "<numbers>" & ASCII.LF
      & "<currencies>" & ASCII.LF
      & "<currency type=""XBD"">" & ASCII.LF
      & "<displayName count=""bogus"">bad credits</displayName>"
      & ASCII.LF
      & "</currency>" & ASCII.LF
      & "</currencies>" & ASCII.LF
      & "</numbers>" & ASCII.LF
      & "</ldml>" & ASCII.LF);
   Assert (Data.Status = I18N.Runtime.Invalid_Data,
           "malformed CLDR currency display-name rows are rejected");
   Assert (Rendered (Runtime, "lc", "money_container_name", Args) =
             "12.30 container credits",
           "failed CLDR currency display-name load leaves previous overrides intact");

   I18N.Runtime.Clear_Runtime_Data;
   I18N.Runtime.Finalize (Runtime);
exception
   when others =>
      I18N.Runtime.Clear_Runtime_Data;
      I18N.Runtime.Finalize (Runtime);
      raise;
end Test_Runtime_Data_Overrides;
