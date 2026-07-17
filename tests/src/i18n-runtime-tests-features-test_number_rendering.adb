separate (I18N.Runtime.Tests.Features)
procedure Test_Number_Rendering
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
   Target  : String (1 .. 32) := [others => Character'Val (0)];
   Last    : Natural := 0;
   Status  : I18N.Result.Render_Status;
   Arabic_Total : constant String :=
     U (16#661#) & U (16#66C#) & U (16#662#) & U (16#663#)
     & U (16#664#) & U (16#66C#) & U (16#665#) & U (16#666#)
     & U (16#667#) & U (16#66B#) & U (16#668#) & U (16#669#);
   Arabic_Extension_Total : constant String :=
     U (16#661#) & "," & U (16#662#) & U (16#663#)
     & U (16#664#) & "," & U (16#665#) & U (16#666#)
     & U (16#667#) & "." & U (16#668#) & U (16#669#);
   Arabic_Decimal : constant String :=
     U (16#664#) & U (16#662#) & U (16#66B#) & U (16#660#);
   Persian_Total : constant String :=
     U (16#6F1#) & U (16#66C#) & U (16#6F2#) & U (16#6F3#)
     & U (16#6F4#) & U (16#66C#) & U (16#6F5#) & U (16#6F6#)
     & U (16#6F7#) & U (16#66B#) & U (16#6F8#) & U (16#6F9#);
   Persian_Extension_Total : constant String :=
     U (16#6F1#) & "," & U (16#6F2#) & U (16#6F3#)
     & U (16#6F4#) & "," & U (16#6F5#) & U (16#6F6#)
     & U (16#6F7#) & "." & U (16#6F8#) & U (16#6F9#);
   Persian_Decimal : constant String :=
     U (16#6F4#) & U (16#6F2#) & U (16#66B#) & U (16#6F0#);
   Thai_Total : constant String :=
     U (16#E51#) & "," & U (16#E52#) & U (16#E53#)
     & U (16#E54#) & "," & U (16#E55#) & U (16#E56#)
     & U (16#E57#) & "." & U (16#E58#) & U (16#E59#);
   Thai_Decimal : constant String :=
     U (16#E54#) & U (16#E52#) & "." & U (16#E50#);
   Devanagari_Total : constant String :=
     U (16#967#) & "," & U (16#968#) & U (16#969#)
     & U (16#96A#) & "," & U (16#96B#) & U (16#96C#)
     & U (16#96D#) & "." & U (16#96E#) & U (16#96F#);
   Devanagari_Arabic_Total : constant String :=
     U (16#967#) & U (16#66C#) & U (16#968#) & U (16#969#)
     & U (16#96A#) & U (16#66C#) & U (16#96B#) & U (16#96C#)
     & U (16#96D#) & U (16#66B#) & U (16#96E#) & U (16#96F#);
   Bengali_Total : constant String :=
     U (16#9E7#) & "," & U (16#9E8#) & U (16#9E9#)
     & U (16#9EA#) & "," & U (16#9EB#) & U (16#9EC#)
     & U (16#9ED#) & "." & U (16#9EE#) & U (16#9EF#);
   Bengali_Indian_Total : constant String :=
     U (16#9E7#) & U (16#9E8#) & "," & U (16#9E9#)
     & U (16#9EA#) & "," & U (16#9EB#) & U (16#9EC#)
     & U (16#9ED#) & "." & U (16#9EE#) & U (16#9EF#);
   Fullwide_Total : constant String :=
     U (16#FF11#) & "," & U (16#FF12#) & U (16#FF13#)
     & U (16#FF14#) & "," & U (16#FF15#) & U (16#FF16#)
     & U (16#FF17#) & "." & U (16#FF18#) & U (16#FF19#);
   Myanmar_Total : constant String :=
     U (16#1041#) & "," & U (16#1042#) & U (16#1043#)
     & U (16#1044#) & "," & U (16#1045#) & U (16#1046#)
     & U (16#1047#) & "." & U (16#1048#) & U (16#1049#);
   Hanidec_Total : constant String :=
     U (16#4E00#) & "," & U (16#4E8C#) & U (16#4E09#)
     & U (16#56DB#) & "," & U (16#4E94#) & U (16#516D#)
     & U (16#4E03#) & "." & U (16#516B#) & U (16#4E5D#);
begin
   I18N.Runtime.Load_Text
     (Runtime, "base",
      "en.total = ""Total {value, number}""" & ASCII.LF
      & "de.total = ""Summe {value, number}""" & ASCII.LF
      & "ro.total = ""{value, number}""" & ASCII.LF
      & "lt.total = ""{value, number}""" & ASCII.LF
      & "sl.total = ""{value, number}""" & ASCII.LF
      & "hi.total = ""{value, number}""" & ASCII.LF
      & "bn.total = ""{value, number}""" & ASCII.LF
      & "ar.total = ""{value, number}""" & ASCII.LF
      & "fa.total = ""{value, number}""" & ASCII.LF
      & "th.total = ""{value, number}""" & ASCII.LF
      & "ar-u-nu-latn.total = ""{value, number}""" & ASCII.LF
      & "ar-u-nu-deva.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-arab.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-arabext.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-thai.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-deva.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-beng.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-fullwide.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-mymr.total = ""{value, number}""" & ASCII.LF
      & "en-u-nu-hanidec.total = ""{value, number}""" & ASCII.LF
      & "en.percent = ""{value, number, ::percent}""" & ASCII.LF
      & "ar.percent = ""{value, number, ::percent}""" & ASCII.LF
      & "fa.percent = ""{value, number, ::percent}""" & ASCII.LF
      & "en.percent_integer = ""{value, number, ::percent precision-integer}"""
      & ASCII.LF
      & "en.permille = ""{value, number, ::permille}""" & ASCII.LF
      & "ar.permille = ""{value, number, ::permille}""" & ASCII.LF
      & "fa.permille = ""{value, number, ::permille}""" & ASCII.LF
      & "en.compact = ""{value, number, ::compact-short}""" & ASCII.LF
      & "en.compact_fraction = ""{value, number, ::compact-short precision-fraction/0-2}"""
      & ASCII.LF
      & "en.compact_fraction_down = ""{value, number, ::compact-short precision-fraction/0-2 rounding-mode-down}"""
      & ASCII.LF
      & "en.compact_long = ""{value, number, ::compact-long}"""
      & ASCII.LF
      & "en.compact_slash = ""{value, number, ::compact/short}"""
      & ASCII.LF
      & "en.compact_slash_long = ""{value, number, ::compact/long}"""
      & ASCII.LF
      & "en.notation_compact = ""{value, number, ::notation-compact-short}"""
      & ASCII.LF
      & "en.notation_slash_compact = ""{value, number, ::notation/compact-short}"""
      & ASCII.LF
      & "en.notation_double_slash_compact = ""{value, number, ::notation/compact/short}"""
      & ASCII.LF
      & "en.notation_compact_long = ""{value, number, ::notation-compact-long}"""
      & ASCII.LF
      & "en.notation_slash_compact_long = ""{value, number, ::notation/compact-long}"""
      & ASCII.LF
      & "en.notation_double_slash_compact_long = ""{value, number, ::notation/compact/long}"""
      & ASCII.LF
      & "ja.compact = ""{value, number, ::compact-short}""" & ASCII.LF
      & "zh.compact = ""{value, number, ::compact-short}""" & ASCII.LF
      & "ko.compact = ""{value, number, ::compact-short}""" & ASCII.LF
      & "ja.compact_long = ""{value, number, ::compact-long}""" & ASCII.LF
      & "zh.compact_large = ""{value, number, ::compact-short}""" & ASCII.LF
      & "ko.compact_large = ""{value, number, ::compact-short}"""
      & ASCII.LF
      & "en.scientific = ""{value, number, ::scientific}""" & ASCII.LF
      & "en.scientific_fraction = ""{value, number, ::scientific precision-fraction/1}"""
      & ASCII.LF
      & "en.engineering = ""{value, number, ::engineering}"""
      & ASCII.LF
      & "en.engineering_fraction = ""{value, number, ::engineering precision-fraction/1}"""
      & ASCII.LF
      & "en.notation_scientific = ""{value, number, ::notation-scientific}"""
      & ASCII.LF
      & "en.notation_slash_scientific = ""{value, number, ::notation/scientific}"""
      & ASCII.LF
      & "en.notation_engineering = ""{value, number, ::notation-engineering}"""
      & ASCII.LF
      & "en.notation_slash_engineering = ""{value, number, ::notation/engineering}"""
      & ASCII.LF
      & "en.notation_simple = ""{value, number, ::notation-simple}"""
      & ASCII.LF
      & "en.notation_slash_simple = ""{value, number, ::notation/simple}"""
      & ASCII.LF
      & "en.notation_standard = ""{value, number, ::notation-standard}"""
      & ASCII.LF
      & "en.notation_slash_standard = ""{value, number, ::notation/standard}"""
      & ASCII.LF
      & "en.integer = ""{value, number, ::precision-integer}"""
      & ASCII.LF
      & "en.integer_slash = ""{value, number, ::precision/integer}"""
      & ASCII.LF
      & "en.precision_unlimited = ""{value, number, ::precision-unlimited}"""
      & ASCII.LF
      & "en.precision_unlimited_slash = ""{value, number, ::precision/unlimited}"""
      & ASCII.LF
      & "en.precision_override = ""{value, number, ::precision-integer precision-unlimited}"""
      & ASCII.LF
      & "en.fraction = ""{value, number, ::precision-fraction/2}"""
      & ASCII.LF
      & "en.fraction_slash = ""{value, number, ::precision/fraction/2}"""
      & ASCII.LF
      & "en.fraction_down = ""{value, number, ::precision-fraction/2 rounding-mode-down}"""
      & ASCII.LF
      & "en.fraction_range = ""{value, number, ::precision-fraction/0-2}"""
      & ASCII.LF
      & "en.fraction_range_min = ""{value, number, ::precision-fraction/2-4}"""
      & ASCII.LF
      & "en.fraction_range_down = ""{value, number, ::precision-fraction/0-2 rounding-mode-down}"""
      & ASCII.LF
      & "en.significant = ""{value, number, ::precision-significant/3}"""
      & ASCII.LF
      & "en.significant_slash = ""{value, number, ::precision/significant/3}"""
      & ASCII.LF
      & "en.significant_range = ""{value, number, ::precision-significant/1-3}"""
      & ASCII.LF
      & "en.significant_range_min = ""{value, number, ::precision-significant/2-4}"""
      & ASCII.LF
      & "en.pad = ""{value, number, ::pad-integer/6}""" & ASCII.LF
      & "en.pad_slash = ""{value, number, ::padding/integer/6}"""
      & ASCII.LF
      & "en.group_off = ""{value, number, ::group-off}""" & ASCII.LF
      & "en.group_slash_off = ""{value, number, ::group/off}"""
      & ASCII.LF
      & "en.grouping_hyphen_off = ""{value, number, ::grouping-off}"""
      & ASCII.LF
      & "en.group_auto = ""{value, number, ::group-auto}""" & ASCII.LF
      & "en.group_slash_auto = ""{value, number, ::group/auto}"""
      & ASCII.LF
      & "en.grouping_hyphen_auto = ""{value, number, ::grouping-auto}"""
      & ASCII.LF
      & "en.group_min2 = ""{value, number, ::group-min2}""" & ASCII.LF
      & "en.group_slash_min2 = ""{value, number, ::group/min2}"""
      & ASCII.LF
      & "en.grouping_min2 = ""{value, number, ::grouping/min2}"""
      & ASCII.LF
      & "en.grouping_hyphen_min2 = ""{value, number, ::grouping-min2}"""
      & ASCII.LF
      & "en.group_on_aligned = ""{value, number, ::group-on-aligned}"""
      & ASCII.LF
      & "en.group_slash_on_aligned = ""{value, number, ::group/on-aligned}"""
      & ASCII.LF
      & "en.grouping_hyphen_on_aligned = "
      & """{value, number, ::grouping-on-aligned}"""
      & ASCII.LF
      & "hi-IN.group_min2 = ""{value, number, ::group-min2}"""
      & ASCII.LF
      & "en.group_thousands = ""{value, number, ::group-thousands}"""
      & ASCII.LF
      & "en.group_slash_thousands = ""{value, number, ::group/thousands}"""
      & ASCII.LF
      & "en.grouping_hyphen_thousands = "
      & """{value, number, ::grouping-thousands}"""
      & ASCII.LF
      & "en.group_off_pad = ""{value, number, ::group-off pad-integer/6}"""
      & ASCII.LF
      & "en.integer_width = ""{value, number, ::integer-width/+000000}"""
      & ASCII.LF
      & "en.integer_width_bare = ""{value, number, ::integer-width/000000}"""
      & ASCII.LF
      & "en.integer_width_star = ""{value, number, ::integer-width/*000000}"""
      & ASCII.LF
      & "en.integer_width_optional = ""{value, number, ::integer-width/+##000}"""
      & ASCII.LF
      & "en.integer_width_optional_bare = ""{value, number, ::integer-width/##000}"""
      & ASCII.LF
      & "en.integer_width_optional_star = ""{value, number, ::integer-width/*##000}"""
      & ASCII.LF
      & "en.decimal_auto = ""{value, number, ::decimal-auto}"""
      & ASCII.LF
      & "en.decimal_always = ""{value, number, ::decimal-always}"""
      & ASCII.LF
      & "en.decimal_slash_always = ""{value, number, ::decimal/always}"""
      & ASCII.LF
      & "en.decimal_display_auto = "
      & """{value, number, ::decimal-display-auto}"""
      & ASCII.LF
      & "en.decimal_display_always = "
      & """{value, number, ::decimal-display-always}"""
      & ASCII.LF
      & "en.decimal_display_slash_always = "
      & """{value, number, ::decimal-display/always}"""
      & ASCII.LF
      & "en.decimal_group_off = ""{value, number, ::decimal-always group-off}"""
      & ASCII.LF
      & "en.trailing_auto = ""{value, number, ::precision-fraction/2 trailing-zero-display/auto}"""
      & ASCII.LF
      & "en.trailing_strip = ""{value, number, ::precision-fraction/2 trailing-zero-display/stripIfInteger}"""
      & ASCII.LF
      & "en.trailing_strip_kebab = ""{value, number, "
      & "::precision-fraction/2 trailing-zero-display/strip-if-integer}"""
      & ASCII.LF
      & "en.trailing_auto_hyphen = ""{value, number, "
      & "::precision-fraction/2 trailing-zero-display-auto}"""
      & ASCII.LF
      & "en.trailing_strip_hyphen = ""{value, number, "
      & "::precision-fraction/2 trailing-zero-display-stripIfInteger}"""
      & ASCII.LF
      & "en.trailing_strip_hyphen_kebab = ""{value, number, "
      & "::precision-fraction/2 trailing-zero-display-strip-if-integer}"""
      & ASCII.LF
      & "en.trailing_override = ""{value, number, "
      & "::precision-fraction/2 trailing-zero-display/stripIfInteger "
      & "trailing-zero-display/auto}"""
      & ASCII.LF
      & "en.compact_trailing_strip = ""{value, number, ::compact-short trailing-zero-display/stripIfInteger}"""
      & ASCII.LF
      & "ar.decimal_always = ""{value, number, ::decimal-always}"""
      & ASCII.LF
      & "fa.decimal_always = ""{value, number, ::decimal-always}"""
      & ASCII.LF
      & "th.decimal_always = ""{value, number, ::decimal-always}"""
      & ASCII.LF
      & "en.scale = ""{value, number, ::scale/1000}""" & ASCII.LF
      & "en.scale_decimal = ""{value, number, ::scale/0.01 precision-fraction/2}"""
      & ASCII.LF
      & "en.scale_percent = ""{value, number, ::scale/10 percent}"""
      & ASCII.LF
      & "en.scale_decimal_percent = ""{value, number, ::scale/0.5 percent}"""
      & ASCII.LF
      & "en.scale_group_off = ""{value, number, ::scale/1000 group-off}"""
      & ASCII.LF
      & "en.pressure_bar = ""{value, unit, pressure-bar}"""
      & ASCII.LF
      & "en.pressure_atmosphere = ""{value, unit, atmosphere}"""
      & ASCII.LF
      & "en.pressure_inhg = ""{value, number, ::measure-unit/pressure-inch-ofhg unit-width-short}"""
      & ASCII.LF
      & "en.pressure_mmhg = ""{value, number, ::measure-unit/pressure-millimeter-ofhg}"""
      & ASCII.LF
      & "en.round_increment = ""{value, number, ::rounding-increment/0.05}"""
      & ASCII.LF
      & "en.round_increment_slash = ""{value, number, ::rounding/increment/0.05}"""
      & ASCII.LF
      & "en.precision_increment = ""{value, number, ::precision-increment/0.05}"""
      & ASCII.LF
      & "en.precision_increment_slash = ""{value, number, ::precision/increment/0.05}"""
      & ASCII.LF
      & "en.round_increment_down = ""{value, number, "
      & "::rounding-increment/0.05 rounding-mode-down}"""
      & ASCII.LF
      & "en.round_increment_percent = ""{value, number, "
      & "::percent rounding-increment/5}"""
      & ASCII.LF
      & "en.round_down = ""{value, number, ::rounding-mode-down}"""
      & ASCII.LF
      & "en.round_up = ""{value, number, ::rounding-mode-up}"""
      & ASCII.LF
      & "en.round_half_even = ""{value, number, ::rounding-mode-half-even}"""
      & ASCII.LF
      & "en.round_slash_half_even = ""{value, number, ::rounding-mode/half-even}"""
      & ASCII.LF
      & "en.round_half_down = ""{value, number, ::rounding-mode-half-down}"""
      & ASCII.LF
      & "en.round_half_ceiling = ""{value, number, ::rounding-mode-half-ceiling}"""
      & ASCII.LF
      & "en.round_half_floor = ""{value, number, ::rounding-mode-half-floor}"""
      & ASCII.LF
      & "en.round_ceiling = ""{value, number, ::rounding-mode-ceiling}"""
      & ASCII.LF
      & "en.round_floor = ""{value, number, ::rounding-mode-floor}"""
      & ASCII.LF
      & "en.sign_always = ""{value, number, ::sign-always}"""
      & ASCII.LF
      & "en.sign_slash_always = ""{value, number, ::sign/always}"""
      & ASCII.LF
      & "en.sign_display_always = ""{value, number, ::sign-display/always}"""
      & ASCII.LF
      & "en.sign_display_hyphen_always = ""{value, number, ::sign-display-always}"""
      & ASCII.LF
      & "en.sign_except_zero = ""{value, number, ::precision-integer sign-except-zero}"""
      & ASCII.LF
      & "en.sign_slash_except_zero = ""{value, number, ::precision-integer sign/except-zero}"""
      & ASCII.LF
      & "en.sign_display_hyphen_except_zero = ""{value, number, ::precision-integer sign-display-except-zero}"""
      & ASCII.LF
      & "en.sign_never = ""{value, number, ::sign-never}"""
      & ASCII.LF
      & "en.sign_slash_never = ""{value, number, ::sign/never}"""
      & ASCII.LF
      & "en.sign_display_hyphen_never = ""{value, number, ::sign-display-never}"""
      & ASCII.LF
      & "en.sign_auto = ""{value, number, ::sign-always sign-auto}"""
      & ASCII.LF
      & "en.sign_slash_auto = ""{value, number, ::sign-always sign/auto}"""
      & ASCII.LF
      & "en.sign_display_hyphen_auto = ""{value, number, ::sign-always sign-display-auto}"""
      & ASCII.LF
      & "en.sign_negative = ""{value, number, ::sign-negative}"""
      & ASCII.LF
      & "en.sign_slash_negative = ""{value, number, ::sign/negative}"""
      & ASCII.LF
      & "en.sign_display_hyphen_negative = ""{value, number, ::sign-display-negative}"""
      & ASCII.LF
      & "en.sign_negative_override = ""{value, number, ::sign-always sign-negative}"""
      & ASCII.LF
      & "en.sign_accounting = ""{value, number, ::sign-accounting}"""
      & ASCII.LF
      & "en.sign_accounting_slash = ""{value, number, ::sign/accounting}"""
      & ASCII.LF
      & "en.sign_display_hyphen_accounting = ""{value, number, ::sign-display-accounting}"""
      & ASCII.LF
      & "en.sign_accounting_always = ""{value, number, ::sign-accounting-always}"""
      & ASCII.LF
      & "en.sign_accounting_always_slash = ""{value, number, ::sign/accounting-always}"""
      & ASCII.LF
      & "en.sign_display_hyphen_accounting_always = ""{value, number, ::sign-display-accounting-always}"""
      & ASCII.LF
      & "en.sign_accounting_except_zero = ""{value, number, ::precision-integer sign-accounting-except-zero}"""
      & ASCII.LF
      & "en.sign_accounting_except_zero_slash = ""{value, number, ::precision-integer sign/accounting-except-zero}"""
      & ASCII.LF
      & "en.sign_display_hyphen_accounting_except_zero = "
      & """{value, number, ::precision-integer "
      & "sign-display-accounting-except-zero}"""
      & ASCII.LF
      & "en.signed_percent = ""{value, number, ::percent sign-always}"""
      & ASCII.LF
      & "en.accounting_percent = ""{value, number, ::percent sign-accounting}"""
      & ASCII.LF
      & "en.signed_compact = ""{value, number, ::compact-short sign-always}"""
      & ASCII.LF
      & "en.accounting_compact = ""{value, number, ::compact-short sign-accounting}"""
      & ASCII.LF
      & "en.signed_scientific = ""{value, number, ::scientific sign-never}"""
      & ASCII.LF
      & "en.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "en.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "en.spellout_cardinal_alias = ""{value, number, ::spellout-cardinal}"""
      & ASCII.LF
      & "en.spellout_ordinal_alias = ""{value, number, ::spellout-ordinal}"""
      & ASCII.LF
      & "en.spellout_numbering_alias = ""{value, number, ::spellout-numbering}"""
      & ASCII.LF
      & "en.spellout_numbering_year_alias = ""{value, number, ::spellout-numbering-year}"""
      & ASCII.LF
      & "en.spellout_year_alias = ""{value, number, ::spellout-year}"""
      & ASCII.LF
      & "en.spellout_numbering_verbose_alias = ""{value, number, ::spellout-numbering-verbose}"""
      & ASCII.LF
      & "en.spellout_numbering_financial_alias = ""{value, number, ::spellout-numbering-financial}"""
      & ASCII.LF
      & "en.spellout_cardinal_verbose_alias = ""{value, number, ::spellout-cardinal-verbose}"""
      & ASCII.LF
      & "en.spellout_cardinal_masculine_alias = ""{value, number, "
      & "::spellout-cardinal-masculine}"""
      & ASCII.LF
      & "en.spellout_cardinal_feminine_alias = ""{value, number, "
      & "::spellout-cardinal-feminine}"""
      & ASCII.LF
      & "en.spellout_cardinal_neuter_alias = ""{value, number, "
      & "::spellout-cardinal-neuter}"""
      & ASCII.LF
      & "en.spellout_ordinal_masculine_alias = ""{value, number, "
      & "::spellout-ordinal-masculine}"""
      & ASCII.LF
      & "en.spellout_ordinal_feminine_alias = ""{value, number, "
      & "::spellout-ordinal-feminine}"""
      & ASCII.LF
      & "en.spellout_ordinal_neuter_alias = ""{value, number, "
      & "::spellout-ordinal-neuter}"""
      & ASCII.LF
      & "en.spellout_ordinal_verbose_alias = ""{value, number, ::spellout-ordinal-verbose}"""
      & ASCII.LF
      & "de.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "de.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "fr.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "fr.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "es.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "es.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "it.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "it.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "pt.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "pt.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "nl.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "nl.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "pl.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "pl.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "cs.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "cs.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ru.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ru.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "uk.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "uk.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ja.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ja.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "zh.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "zh.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ko.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ko.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "tr.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "tr.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "sv.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "sv.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "da.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "da.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "no.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "no.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "nb.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "nb.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "fi.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "fi.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "id.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "id.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ms.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ms.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "eo.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "eo.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "vi.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "vi.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "sw.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "sw.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "af.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "af.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "eu.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "eu.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ro.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ro.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ca.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ca.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "hu.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "hu.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "sk.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "sk.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "bg.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "bg.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "ar.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "ar.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "fa.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "fa.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "th.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "th.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "hi.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "hi.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "el.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "el.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF
      & "he.spellout = ""{value, number, ::spellout}""" & ASCII.LF
      & "he.ordinal_words = ""{value, number, ::ordinal-words}"""
      & ASCII.LF,
      Result);
   Assert (Result.Status = I18N.Runtime.Loaded,
           "number catalog should load");

   I18N.Arguments.Set (Args, "value", "0012345.670");
   Assert (Rendered (Runtime, "en", "total", Args) = "Total 12,345.670",
           "English number uses comma grouping and dot decimal");
   Assert (Rendered (Runtime, "de", "total", Args) = "Summe 12.345,670",
           "German number uses dot grouping and comma decimal");
   Assert (Rendered (Runtime, "ro", "total", Args) = "12.345,670",
           "Romanian number uses dot grouping and comma decimal");
   Assert (Rendered (Runtime, "lt", "total", Args) =
             "12" & U (16#A0#) & "345,670",
           "Lithuanian number uses non-breaking-space grouping");
   Assert (Rendered (Runtime, "sl", "total", Args) = "12.345,670",
           "Slovenian number uses dot grouping and comma decimal");
   Assert (Rendered (Runtime, "hi", "total", Args) = "12,345.670",
           "Hindi language locale keeps western digits");

   I18N.Arguments.Set (Args, "value", "1234567.89");
   Assert (Rendered (Runtime, "hi-IN", "total", Args) = "12,34,567.89",
           "Indian locales use primary/secondary grouping");
   Assert (Rendered (Runtime, "bn", "total", Args) = Bengali_Indian_Total,
           "Bengali locale uses Bengali digits and Indian grouping");
   Assert (Rendered (Runtime, "ar", "total", Args) = Arabic_Total,
           "Arabic numbers use Arabic-Indic digits and separators");
   Assert (Rendered (Runtime, "fa", "total", Args) = Persian_Total,
           "Persian numbers use Persian digits");
   Assert (Rendered (Runtime, "th", "total", Args) = Thai_Total,
           "Thai numbers use Thai digits from CLDR data");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "total", Args) =
             "1" & U (16#66C#) & "234" & U (16#66C#) & "567"
             & U (16#66B#) & "89",
           "latn numbering-system extension overrides Arabic digits");
   Assert (Rendered (Runtime, "ar-u-nu-deva", "total", Args) =
             Devanagari_Arabic_Total,
           "numbering-system extension overrides language default digits");
   Assert (Rendered (Runtime, "en-u-nu-arab", "total", Args) =
             Arabic_Extension_Total,
           "arab numbering-system extension renders Arabic-Indic digits");
   Assert (Rendered (Runtime, "en-u-nu-arabext", "total", Args) =
             Persian_Extension_Total,
           "arabext numbering-system extension renders extended Arabic digits");
   Assert (Rendered (Runtime, "en-u-nu-thai", "total", Args) =
             Thai_Total,
           "thai numbering-system extension renders Thai digits");
   Assert (Rendered (Runtime, "en-u-nu-deva", "total", Args) =
             Devanagari_Total,
           "numbering-system extension renders Devanagari digits");
   Assert (Rendered (Runtime, "en-u-nu-beng", "total", Args) =
             Bengali_Total,
           "numbering-system extension renders Bengali digits");
   Assert (Rendered (Runtime, "en-u-nu-fullwide", "total", Args) =
             Fullwide_Total,
           "generated numbering-system extension renders fullwidth digits");
   Assert (Rendered (Runtime, "en-u-nu-mymr", "total", Args) =
             Myanmar_Total,
           "generated numbering-system extension renders Myanmar digits");
   Assert (Rendered (Runtime, "en-u-nu-hanidec", "total", Args) =
             Hanidec_Total,
           "generated numbering-system extension renders Han decimal digits");

   I18N.Arguments.Set (Args, "value", "0012345.670");
   I18N.Runtime.Render_Into
     (Runtime, "en", "total", Args, Target, Last, Status);
   Assert (Status = I18N.Result.Success,
           "bounded number render succeeds");
   Assert (Target (1 .. Last) = "Total 12,345.670",
           "bounded number render matches materialized render");

   I18N.Arguments.Set (Args, "value", "0.123");
   Assert (Rendered (Runtime, "en", "percent", Args) = "12%",
           "percent number skeleton scales and adds percent sign");
   Assert (Rendered (Runtime, "ar", "percent", Args) =
             U (16#661#) & U (16#662#) & U (16#66A#),
           "Arabic percent skeleton uses localized percent sign");
   Assert (Rendered (Runtime, "fa", "percent", Args) =
             U (16#6F1#) & U (16#6F2#) & U (16#66A#),
           "Persian percent skeleton uses localized percent sign");
   I18N.Arguments.Set (Args, "value", "0.129");
   Assert (Rendered (Runtime, "en", "percent_integer", Args) = "13%",
           "compound percent/integer number skeleton renders");
   I18N.Arguments.Set (Args, "value", "0.123");
   Assert (Rendered (Runtime, "en", "permille", Args) = "123" & U (16#2030#),
           "permille number skeleton scales and adds permille sign");
   Assert (Rendered (Runtime, "ar", "permille", Args) =
             U (16#661#) & U (16#662#) & U (16#663#) & U (16#609#),
           "Arabic permille skeleton uses localized per-mille sign");
   Assert (Rendered (Runtime, "fa", "permille", Args) =
             U (16#6F1#) & U (16#6F2#) & U (16#6F3#) & U (16#609#),
           "Persian permille skeleton uses localized per-mille sign");

   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "compact", Args) = "12.3K",
           "compact-short number skeleton renders compact suffix");
   Assert (Rendered (Runtime, "en", "compact_fraction", Args) = "12.35K",
           "compact-short composes with fraction precision ranges");
   Assert (Rendered (Runtime, "en", "compact_fraction_down", Args) =
             "12.34K",
           "compact-short composes with fraction precision and rounding");
   Assert (Rendered (Runtime, "en", "compact_slash", Args) = "12.3K",
           "compact/short number skeleton aliases compact-short");
   Assert (Rendered (Runtime, "en", "notation_compact", Args) = "12.3K",
           "notation-compact-short skeleton renders compact suffix");
   Assert (Rendered (Runtime, "en", "notation_slash_compact", Args) =
             "12.3K",
           "notation/compact-short skeleton renders compact suffix");
   Assert
     (Rendered (Runtime, "en", "notation_double_slash_compact", Args) =
        "12.3K",
      "notation/compact/short skeleton aliases compact-short");
   Assert (Rendered (Runtime, "en", "notation_standard", Args) = "12,345",
           "notation-standard aliases deterministic decimal notation");
   Assert (Rendered (Runtime, "en", "notation_slash_standard", Args) =
             "12,345",
           "notation/standard aliases deterministic decimal notation");
   Assert (Rendered (Runtime, "en", "compact_long", Args) =
             "12.3 thousand",
           "compact-long number skeleton renders compact word");
   Assert (Rendered (Runtime, "en", "compact_slash_long", Args) =
             "12.3 thousand",
           "compact/long number skeleton aliases compact-long");
   Assert (Rendered (Runtime, "en", "notation_compact_long", Args) =
             "12.3 thousand",
           "notation-compact-long skeleton renders compact word");
   Assert (Rendered (Runtime, "en", "notation_slash_compact_long", Args) =
             "12.3 thousand",
           "notation/compact-long skeleton renders compact word");
   Assert
     (Rendered (Runtime, "en", "notation_double_slash_compact_long", Args)
      = "12.3 thousand",
      "notation/compact/long skeleton aliases compact-long");
   Assert (Rendered (Runtime, "ja", "compact", Args) =
             "1.2" & U (16#4E07#),
           "Japanese compact notation uses ten-thousand suffix");
   Assert (Rendered (Runtime, "zh", "compact", Args) =
             "1.2" & U (16#4E07#),
           "Chinese compact notation uses ten-thousand suffix");
   Assert (Rendered (Runtime, "ko", "compact", Args) =
             "1.2" & U (16#B9CC#),
           "Korean compact notation uses ten-thousand suffix");
   Assert (Rendered (Runtime, "ja", "compact_long", Args) =
             "1.2" & U (16#4E07#),
           "Japanese compact-long uses localized compact suffix");
   I18N.Arguments.Set (Args, "value", "123456789");
   Assert (Rendered (Runtime, "zh", "compact_large", Args) =
             "1.2" & U (16#5104#),
           "Chinese compact notation uses hundred-million suffix");
   Assert (Rendered (Runtime, "ko", "compact_large", Args) =
             "1.2" & U (16#C5B5#),
           "Korean compact notation uses hundred-million suffix");
   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "scientific", Args) = "1.23E+4",
           "scientific number skeleton renders exponent notation");
   Assert (Rendered (Runtime, "en", "scientific_fraction", Args) =
             "1.2E+4",
           "scientific notation composes with fraction precision");
   Assert (Rendered (Runtime, "en", "notation_scientific", Args) =
             "1.23E+4",
           "notation-scientific skeleton renders exponent notation");
   Assert (Rendered (Runtime, "en", "notation_slash_scientific", Args) =
             "1.23E+4",
           "notation/scientific skeleton renders exponent notation");
   Assert (Rendered (Runtime, "en", "engineering", Args) = "12.35E+3",
           "engineering number skeleton renders exponent multiple of 3");
   Assert (Rendered (Runtime, "en", "engineering_fraction", Args) =
             "12.3E+3",
           "engineering notation composes with fraction precision");
   Assert (Rendered (Runtime, "en", "notation_engineering", Args) =
             "12.35E+3",
           "notation-engineering skeleton renders exponent multiple of 3");
   Assert (Rendered (Runtime, "en", "notation_slash_engineering", Args) =
             "12.35E+3",
           "notation/engineering skeleton renders exponent multiple of 3");
   Assert (Rendered (Runtime, "en", "notation_simple", Args) = "12,345",
           "notation-simple skeleton renders decimal notation");
   Assert (Rendered (Runtime, "en", "notation_slash_simple", Args) =
             "12,345",
           "notation/simple skeleton renders decimal notation");
   I18N.Arguments.Set (Args, "value", "12000");
   Assert (Rendered (Runtime, "en", "compact_trailing_strip", Args) =
             "12K",
           "trailing-zero-display composes with compact notation");

   I18N.Arguments.Set (Args, "value", "12.6");
   Assert (Rendered (Runtime, "en", "integer", Args) = "13",
           "precision-integer rounds to whole number");
   Assert (Rendered (Runtime, "en", "integer_slash", Args) =
             Rendered (Runtime, "en", "integer", Args),
           "precision/integer aliases precision-integer");
   Assert (Rendered (Runtime, "en", "precision_unlimited", Args) = "12.6",
           "precision-unlimited preserves supplied fractional digits");
   Assert (Rendered (Runtime, "en", "precision_unlimited_slash", Args) =
             Rendered (Runtime, "en", "precision_unlimited", Args),
           "precision/unlimited aliases precision-unlimited");
   Assert (Rendered (Runtime, "en", "precision_override", Args) = "12.6",
           "precision-unlimited resets earlier integer precision");
   Assert (Rendered (Runtime, "en", "round_down", Args) = "12",
           "rounding-mode-down truncates fractional digits");
   Assert (Rendered (Runtime, "en", "round_up", Args) = "13",
           "rounding-mode-up rounds any fraction away from zero");
   Assert (Rendered (Runtime, "en", "round_half_even", Args) = "13",
           "rounding-mode-half-even rounds above a half up");
   Assert (Rendered (Runtime, "en", "round_slash_half_even", Args) = "13",
           "rounding-mode slash aliases map to existing rounding modes");
   Assert (Rendered (Runtime, "en", "round_half_down", Args) = "13",
           "rounding-mode-half-down rounds above a half up");
   Assert (Rendered (Runtime, "en", "round_half_ceiling", Args) = "13",
           "rounding-mode-half-ceiling rounds above a half up");
   Assert (Rendered (Runtime, "en", "round_half_floor", Args) = "13",
           "rounding-mode-half-floor rounds above a half up");
   Assert (Rendered (Runtime, "en", "round_ceiling", Args) = "13",
           "rounding-mode-ceiling rounds positive fractions upward");
   Assert (Rendered (Runtime, "en", "round_floor", Args) = "12",
           "rounding-mode-floor rounds positive fractions downward");
   Assert (Rendered (Runtime, "en", "sign_always", Args) = "+12.6",
           "sign-always shows a positive sign");
   Assert (Rendered (Runtime, "en", "sign_slash_always", Args) =
             Rendered (Runtime, "en", "sign_always", Args),
           "sign/always aliases sign-always");
   Assert (Rendered (Runtime, "en", "sign_display_always", Args) =
             "+12.6",
           "sign-display slash aliases map to existing sign display");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_always", Args) =
             Rendered (Runtime, "en", "sign_always", Args),
           "sign-display hyphen aliases map to always sign display");
   Assert (Rendered (Runtime, "en", "sign_auto", Args) = "12.6",
           "sign-auto resets explicit sign display");
   Assert (Rendered (Runtime, "en", "sign_slash_auto", Args) =
             Rendered (Runtime, "en", "sign_auto", Args),
           "sign/auto aliases sign-auto");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_auto", Args) =
             Rendered (Runtime, "en", "sign_auto", Args),
           "sign-display-auto aliases sign-auto");
   Assert (Rendered (Runtime, "en", "sign_negative_override", Args) =
             "12.6",
           "sign-negative resets explicit sign display for positives");
   Assert (Rendered (Runtime, "en", "sign_accounting_always", Args) =
             "+12.6",
           "sign-accounting-always shows a positive sign");
   Assert (Rendered (Runtime, "en", "sign_accounting_always_slash",
             Args) =
             Rendered (Runtime, "en", "sign_accounting_always", Args),
           "sign/accounting-always aliases sign-accounting-always");
   Assert (Rendered (Runtime, "en",
             "sign_display_hyphen_accounting_always", Args) =
             Rendered (Runtime, "en", "sign_accounting_always", Args),
           "sign-display-accounting-always aliases accounting-always");

   I18N.Arguments.Set (Args, "value", "12.5");
   Assert (Rendered (Runtime, "en", "round_half_even", Args) = "12",
           "rounding-mode-half-even ties to even");
   Assert (Rendered (Runtime, "en", "round_half_down", Args) = "12",
           "rounding-mode-half-down ties toward zero");
   Assert (Rendered (Runtime, "en", "round_half_ceiling", Args) = "13",
           "rounding-mode-half-ceiling positive ties upward");
   Assert (Rendered (Runtime, "en", "round_half_floor", Args) = "12",
           "rounding-mode-half-floor positive ties downward");

   I18N.Arguments.Set (Args, "value", "-12.6");
   Assert (Rendered (Runtime, "en", "sign_never", Args) = "12.6",
           "sign-never suppresses a negative sign");
   Assert (Rendered (Runtime, "en", "sign_slash_never", Args) =
             Rendered (Runtime, "en", "sign_never", Args),
           "sign/never aliases sign-never");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_never", Args) =
             Rendered (Runtime, "en", "sign_never", Args),
           "sign-display-never aliases sign-never");
   Assert (Rendered (Runtime, "en", "sign_negative", Args) = "-12.6",
           "sign-negative keeps the default negative sign");
   Assert (Rendered (Runtime, "en", "sign_slash_negative", Args) =
             Rendered (Runtime, "en", "sign_negative", Args),
           "sign/negative aliases sign-negative");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_negative",
             Args) =
             Rendered (Runtime, "en", "sign_negative", Args),
           "sign-display-negative aliases sign-negative");
   Assert (Rendered (Runtime, "en", "sign_accounting", Args) = "(12.6)",
           "sign-accounting renders negative numbers in parentheses");
   Assert (Rendered (Runtime, "en", "sign_accounting_slash", Args) =
             Rendered (Runtime, "en", "sign_accounting", Args),
           "sign/accounting aliases sign-accounting");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_accounting",
             Args) =
             Rendered (Runtime, "en", "sign_accounting", Args),
           "sign-display-accounting aliases accounting sign display");
   Assert (Rendered (Runtime, "en", "round_ceiling", Args) = "-12",
           "rounding-mode-ceiling rounds negative fractions upward");
   Assert (Rendered (Runtime, "en", "round_floor", Args) = "-13",
           "rounding-mode-floor rounds negative fractions downward");
   I18N.Arguments.Set (Args, "value", "-12.5");
   Assert (Rendered (Runtime, "en", "round_half_ceiling", Args) = "-12",
           "rounding-mode-half-ceiling negative ties upward");
   Assert (Rendered (Runtime, "en", "round_half_floor", Args) = "-13",
           "rounding-mode-half-floor negative ties downward");
   I18N.Arguments.Set (Args, "value", "0.2");
   Assert (Rendered (Runtime, "en", "sign_except_zero", Args) = "0",
           "sign-except-zero omits the sign after rounding to zero");
   Assert (Rendered (Runtime, "en", "sign_slash_except_zero", Args) =
             Rendered (Runtime, "en", "sign_except_zero", Args),
           "sign/except-zero aliases sign-except-zero");
   Assert (Rendered (Runtime, "en", "sign_display_hyphen_except_zero",
             Args) =
             Rendered (Runtime, "en", "sign_except_zero", Args),
           "sign-display-except-zero aliases sign-except-zero");
   Assert (Rendered (Runtime, "en", "sign_accounting_except_zero", Args) =
             "0",
           "sign-accounting-except-zero omits sign after rounding to zero");
   Assert (Rendered (Runtime, "en",
             "sign_accounting_except_zero_slash", Args) =
             Rendered (Runtime, "en", "sign_accounting_except_zero",
               Args),
           "sign/accounting-except-zero omits sign after rounding to zero");
   Assert (Rendered (Runtime, "en",
             "sign_display_hyphen_accounting_except_zero", Args) =
             Rendered (Runtime, "en", "sign_accounting_except_zero",
               Args),
           "sign-display-accounting-except-zero aliases accounting except zero");
   I18N.Arguments.Set (Args, "value", "1.2");
   Assert (Rendered (Runtime, "en", "sign_except_zero", Args) = "+1",
           "sign-except-zero shows a positive non-zero sign");
   I18N.Arguments.Set (Args, "value", "-1.2");
   Assert (Rendered (Runtime, "en", "sign_except_zero", Args) = "-1",
           "sign-except-zero shows a negative non-zero sign");
   I18N.Arguments.Set (Args, "value", "0.12");
   Assert (Rendered (Runtime, "en", "signed_percent", Args) = "+12%",
           "compound percent/sign skeleton renders a positive sign");
   I18N.Arguments.Set (Args, "value", "-0.12");
   Assert (Rendered (Runtime, "en", "accounting_percent", Args) = "(12%)",
           "sign-accounting composes with percent skeletons");

   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "signed_compact", Args) = "+12.3K",
           "compact skeleton carries sign-display options");
   I18N.Arguments.Set (Args, "value", "-12345");
   Assert (Rendered (Runtime, "en", "accounting_compact", Args) =
             "(12.3K)",
           "sign-accounting composes with compact suffixes");
   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "signed_scientific", Args) =
             "1.23E+4",
           "scientific skeleton carries sign-display options");

   I18N.Arguments.Set (Args, "value", "12.345");
   Assert (Rendered (Runtime, "en", "fraction", Args) = "12.35",
           "precision-fraction fixes fractional width");
   Assert (Rendered (Runtime, "en", "fraction_slash", Args) =
             Rendered (Runtime, "en", "fraction", Args),
           "precision/fraction aliases precision-fraction");
   I18N.Arguments.Set (Args, "value", "12.349");
   Assert (Rendered (Runtime, "en", "fraction_down", Args) = "12.34",
           "compound precision/rounding number skeleton renders");
   Assert (Rendered (Runtime, "en", "fraction_range_down", Args) =
             "12.34",
           "precision-fraction range composes with rounding-mode-down");
   Assert (Rendered (Runtime, "en", "fraction_range", Args) = "12.35",
           "precision-fraction range rounds to max fraction digits");
   I18N.Arguments.Set (Args, "value", "12.300");
   Assert (Rendered (Runtime, "en", "fraction_range", Args) = "12.3",
           "precision-fraction range trims trailing zeroes to minimum");
   I18N.Arguments.Set (Args, "value", "12");
   Assert (Rendered (Runtime, "en", "fraction_range", Args) = "12",
           "zero-minimum precision-fraction range omits decimal part");
   I18N.Arguments.Set (Args, "value", "12.3");
   Assert (Rendered (Runtime, "en", "fraction_range_min", Args) =
             "12.30",
           "precision-fraction range pads to minimum fraction digits");
   I18N.Arguments.Set (Args, "value", "12.34567");
   Assert (Rendered (Runtime, "en", "fraction_range_min", Args) =
             "12.3457",
           "precision-fraction range keeps rounded max fraction digits");
   I18N.Arguments.Set (Args, "value", "12.345");
   Assert (Rendered (Runtime, "en", "significant", Args) = "12.3",
           "precision-significant limits significant digits");
   Assert (Rendered (Runtime, "en", "significant_slash", Args) =
             Rendered (Runtime, "en", "significant", Args),
           "precision/significant aliases precision-significant");
   Assert (Rendered (Runtime, "en", "significant_range", Args) = "12.3",
           "precision-significant range rounds to max significant digits");
   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "significant", Args) = "12,300",
           "precision-significant rounds large integers at the significant place");
   Assert (Rendered (Runtime, "en", "significant_range", Args) =
             "12,300",
           "precision-significant range rounds large integers");
   I18N.Arguments.Set (Args, "value", "12.0");
   Assert (Rendered (Runtime, "en", "significant", Args) = "12.0",
           "fixed precision-significant preserves required trailing zeroes");
   Assert (Rendered (Runtime, "en", "significant_range", Args) = "12",
           "precision-significant range trims trailing zeroes to minimum");
   I18N.Arguments.Set (Args, "value", "0.01234");
   Assert (Rendered (Runtime, "en", "significant", Args) = "0.0123",
           "precision-significant counts leading fractional zeroes");
   Assert (Rendered (Runtime, "en", "significant_range_min", Args) =
             "0.01234",
           "precision-significant range keeps significant non-zero digits");
   I18N.Arguments.Set (Args, "value", "0.0100");
   Assert (Rendered (Runtime, "en", "significant_range_min", Args) =
             "0.010",
           "precision-significant range pads to minimum significant digits");

   I18N.Arguments.Set (Args, "value", "12");
   Assert (Rendered (Runtime, "en", "pad", Args) = "000,012",
           "pad-integer pads integer digits before grouping");
   Assert (Rendered (Runtime, "en", "pad_slash", Args) =
             Rendered (Runtime, "en", "pad", Args),
           "padding/integer aliases pad-integer");
   Assert (Rendered (Runtime, "en", "integer_width", Args) = "000,012",
           "integer-width skeleton pads integer digits before grouping");
   Assert (Rendered (Runtime, "en", "integer_width_bare", Args) =
             "000,012",
           "bare integer-width skeleton pads integer digits");
   Assert (Rendered (Runtime, "en", "integer_width_star", Args) =
             "000,012",
           "starred integer-width skeleton pads integer digits");
   Assert (Rendered (Runtime, "en", "integer_width_optional", Args) =
             "012",
           "integer-width skeleton accepts optional # digits");
   Assert (Rendered (Runtime, "en", "integer_width_optional_bare", Args) =
             "012",
           "bare integer-width skeleton accepts optional # digits");
   Assert (Rendered (Runtime, "en", "integer_width_optional_star", Args) =
             "012",
           "starred integer-width skeleton accepts optional # digits");
   Assert (Rendered (Runtime, "en", "group_off_pad", Args) = "000012",
           "group-off suppresses separators after integer padding");

   I18N.Arguments.Set (Args, "value", "42");
   Assert (Rendered (Runtime, "en", "decimal_auto", Args) = "42",
           "decimal-auto preserves default integer rendering");
   Assert (Rendered (Runtime, "en", "decimal_always", Args) = "42.0",
           "decimal-always forces one fractional zero for integers");
   Assert (Rendered (Runtime, "en", "decimal_slash_always", Args) =
             "42.0",
           "decimal slash aliases map to existing decimal display");
   Assert (Rendered (Runtime, "ar", "decimal_always", Args) =
             Arabic_Decimal,
           "decimal-always localizes decimal separator and digits");
   Assert (Rendered (Runtime, "fa", "decimal_always", Args) =
             Persian_Decimal,
           "decimal-always localizes Persian digits");
   Assert (Rendered (Runtime, "th", "decimal_always", Args) =
             Thai_Decimal,
           "decimal-always localizes Thai digits");
   Assert (Rendered (Runtime, "en", "trailing_auto", Args) = "42.00",
           "trailing-zero-display/auto keeps fixed fractional zeroes");
   Assert (Rendered (Runtime, "en", "trailing_strip", Args) = "42",
           "trailing-zero-display/stripIfInteger strips zero fraction");
   Assert (Rendered (Runtime, "en", "trailing_strip_kebab", Args) = "42",
           "kebab trailing-zero-display spelling is accepted");
   Assert (Rendered (Runtime, "en", "trailing_auto_hyphen", Args) =
             "42.00",
           "hyphen trailing-zero-display-auto spelling is accepted");
   Assert (Rendered (Runtime, "en", "trailing_strip_hyphen", Args) =
             "42",
           "hyphen trailing-zero-display-stripIfInteger spelling is accepted");
   Assert (Rendered (Runtime, "en", "trailing_strip_hyphen_kebab", Args) =
             "42",
           "hyphen trailing-zero-display-strip-if-integer spelling is accepted");
   Assert (Rendered (Runtime, "en", "trailing_override", Args) = "42.00",
           "trailing-zero-display/auto resets stripIfInteger");

   I18N.Arguments.Set (Args, "value", "12345.67");
   Assert (Rendered (Runtime, "en", "group_off", Args) = "12345.67",
           "group-off suppresses grouping separators");
   Assert (Rendered (Runtime, "en", "group_slash_off", Args) =
             Rendered (Runtime, "en", "group_off", Args),
           "group/off aliases group-off");
   Assert (Rendered (Runtime, "en", "grouping_hyphen_off", Args) =
             Rendered (Runtime, "en", "group_off", Args),
           "grouping-off aliases group-off");
   Assert (Rendered (Runtime, "en", "group_auto", Args) = "12,345.67",
           "group-auto preserves default grouping separators");
   Assert (Rendered (Runtime, "en", "group_slash_auto", Args) =
             Rendered (Runtime, "en", "group_auto", Args),
           "group/auto aliases group-auto");
   Assert (Rendered (Runtime, "en", "grouping_hyphen_auto", Args) =
             Rendered (Runtime, "en", "group_auto", Args),
           "grouping-auto aliases group-auto");
   Assert (Rendered (Runtime, "en", "group_min2", Args) = "12,345.67",
           "group-min2 groups when the first group has two digits");
   Assert (Rendered (Runtime, "en", "group_slash_min2", Args) =
             Rendered (Runtime, "en", "group_min2", Args),
           "group/min2 aliases group-min2");
   Assert (Rendered (Runtime, "en", "grouping_min2", Args) =
             "12,345.67",
           "grouping slash aliases map to existing grouping controls");
   Assert (Rendered (Runtime, "en", "grouping_hyphen_min2", Args) =
             Rendered (Runtime, "en", "group_min2", Args),
           "grouping-min2 aliases group-min2");
   Assert (Rendered (Runtime, "hi-IN", "group_min2", Args) = "12,345.67",
           "group-min2 composes with Indian grouping");
   Assert (Rendered (Runtime, "en", "group_on_aligned", Args) =
             "12,345.67",
           "group-on-aligned uses deterministic grouping separators");
   Assert (Rendered (Runtime, "en", "group_slash_on_aligned", Args) =
             Rendered (Runtime, "en", "group_on_aligned", Args),
           "group/on-aligned aliases group-on-aligned");
   Assert (Rendered (Runtime, "en", "grouping_hyphen_on_aligned", Args) =
             Rendered (Runtime, "en", "group_on_aligned", Args),
           "grouping-on-aligned aliases group-on-aligned");
   Assert (Rendered (Runtime, "en", "group_thousands", Args) =
             "12,345.67",
           "group-thousands uses deterministic grouping separators");
   Assert (Rendered (Runtime, "en", "group_slash_thousands", Args) =
             Rendered (Runtime, "en", "group_thousands", Args),
           "group/thousands aliases group-thousands");
   Assert (Rendered (Runtime, "en", "grouping_hyphen_thousands", Args) =
             Rendered (Runtime, "en", "group_thousands", Args),
           "grouping-thousands aliases group-thousands");
   Assert (Rendered (Runtime, "en", "scale", Args) = "12,345,670.00",
           "scale skeleton multiplies the parsed numeric value");
   Assert (Rendered (Runtime, "en", "scale_decimal", Args) = "123.46",
           "decimal scale skeleton factors are accepted");
   Assert (Rendered (Runtime, "en", "scale_group_off", Args) =
             "12345670.00",
           "scale skeleton composes with grouping controls");
   Assert (Rendered (Runtime, "en", "pressure_bar", Args) =
             "12345.67 bars",
           "pressure-bar unit alias renders source-backed unit names");
   Assert (Rendered (Runtime, "en", "pressure_atmosphere", Args) =
             "12345.67 atmospheres",
           "atmosphere unit renders source-backed unit names");
   Assert (Rendered (Runtime, "en", "pressure_inhg", Args) =
             "12345.67 inHg",
           "pressure-inch-ofhg measure-unit skeleton renders short symbol");
   Assert (Rendered (Runtime, "en", "pressure_mmhg", Args) =
             "12345.67 millimeters of mercury",
           "pressure-millimeter-ofhg measure-unit skeleton renders full name");
   I18N.Arguments.Set (Args, "value", "1234.67");
   Assert (Rendered (Runtime, "en", "group_min2", Args) = "1234.67",
           "group-min2 suppresses a single-digit first group");

   I18N.Arguments.Set (Args, "value", "1.23");
   Assert (Rendered (Runtime, "en", "round_increment", Args) = "1.25",
           "rounding-increment rounds to a decimal increment");
   Assert (Rendered (Runtime, "en", "round_increment_slash", Args) =
             Rendered (Runtime, "en", "round_increment", Args),
           "rounding/increment aliases rounding-increment");
   Assert (Rendered (Runtime, "en", "precision_increment", Args) =
             "1.25",
           "precision-increment aliases rounding-increment");
   Assert (Rendered (Runtime, "en", "precision_increment_slash", Args) =
             Rendered (Runtime, "en", "precision_increment", Args),
           "precision/increment aliases precision-increment");
   I18N.Arguments.Set (Args, "value", "-1.23");
   Assert (Rendered (Runtime, "en", "round_increment", Args) = "-1.25",
           "rounding-increment preserves negative sign handling");
   I18N.Arguments.Set (Args, "value", "1.29");
   Assert (Rendered (Runtime, "en", "round_increment_down", Args) =
             "1.25",
           "rounding-increment composes with rounding-mode-down");
   I18N.Arguments.Set (Args, "value", "0.123");
   Assert (Rendered (Runtime, "en", "round_increment_percent", Args) =
             "10%",
           "rounding-increment composes with percent scaling");

   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "en", "decimal_display_auto", Args) =
             Rendered (Runtime, "en", "decimal_auto", Args),
           "decimal-display-auto aliases decimal-auto");
   Assert (Rendered (Runtime, "en", "decimal_display_always", Args) =
             Rendered (Runtime, "en", "decimal_always", Args),
           "decimal-display-always aliases decimal-always");
   Assert (Rendered (Runtime, "en", "decimal_display_slash_always", Args) =
             Rendered (Runtime, "en", "decimal_always", Args),
           "decimal-display/always aliases decimal-always");
   Assert (Rendered (Runtime, "en", "decimal_group_off", Args) =
             "12345.0",
           "decimal-always composes with grouping controls");

   I18N.Arguments.Set (Args, "value", "0.125");
   Assert (Rendered (Runtime, "en", "scale_percent", Args) = "125%",
           "scale skeleton composes with percent scaling");
   I18N.Arguments.Set (Args, "value", "0.10");
   Assert (Rendered (Runtime, "en", "scale_decimal_percent", Args) = "5%",
           "decimal scale skeleton composes with percent scaling");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "en", "spellout", Args) =
             "two thousand three hundred forty-five",
           "spellout number skeleton renders deterministic English words");
   I18N.Arguments.Set (Args, "value", "1234567");
   Assert (Rendered (Runtime, "en", "spellout", Args) =
             "one million two hundred thirty-four thousand "
             & "five hundred sixty-seven",
           "spellout number skeleton renders deterministic English million words");

   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "en", "ordinal_words", Args) =
             "twenty-first",
           "ordinal-word number skeleton renders deterministic English words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "en", "ordinal_words", Args) =
             "one million first",
           "ordinal-word number skeleton renders deterministic English million words");
   I18N.Arguments.Set (Args, "value", "-42");
   Assert (Rendered (Runtime, "en", "spellout", Args) =
             "- forty-two",
           "spellout number skeleton renders signed English words");
   I18N.Arguments.Set (Args, "value", "-21");
   Assert (Rendered (Runtime, "en", "ordinal_words", Args) =
             "- twenty-first",
           "ordinal-word number skeleton renders signed English words");
   I18N.Arguments.Set (Args, "value", "+42");
   Assert (Rendered (Runtime, "en", "spellout", Args) = "forty-two",
           "spellout number skeleton accepts explicit plus signs");
   I18N.Arguments.Set (Args, "value", "12.05");
   Assert (Rendered (Runtime, "en", "spellout", Args) =
             "twelve point zero five",
           "spellout number skeleton preserves decimal fraction digits");
   I18N.Arguments.Set (Args, "value", "-0.5");
   Assert (Rendered (Runtime, "en", "spellout", Args) =
             "- zero point five",
           "spellout number skeleton renders signed decimal values");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "de", "spellout", Args) =
             "zweitausenddreihundertf" & U (16#FC#) & "nfundvierzig",
           "spellout number skeleton renders deterministic German words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "de", "spellout", Args) =
             "eine Million eins",
           "spellout number skeleton renders German million words");
   I18N.Arguments.Set (Args, "value", "1.5");
   Assert (Rendered (Runtime, "de", "spellout", Args) =
             "eins komma f" & U (16#FC#) & "nf",
           "spellout number skeleton renders German decimal words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "de", "ordinal_words", Args) =
             "einundzwanzigste",
           "ordinal-word number skeleton renders deterministic German words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "de", "ordinal_words", Args) =
             "zweitausenddreihundertf" & U (16#FC#) & "nfundvierzigste",
           "ordinal-word number skeleton renders German compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fr", "spellout", Args) =
             "deux mille trois cent quarante-cinq",
           "spellout number skeleton renders deterministic French words");
   I18N.Arguments.Set (Args, "value", "71");
   Assert (Rendered (Runtime, "fr", "spellout", Args) =
             "soixante et onze",
           "spellout number skeleton renders French septante-range words");
   I18N.Arguments.Set (Args, "value", "80");
   Assert (Rendered (Runtime, "fr", "spellout", Args) =
             "quatre-vingts",
           "spellout number skeleton renders French plural eighty words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "fr", "ordinal_words", Args) =
             "vingt et uni" & U (16#E8#) & "me",
           "ordinal-word number skeleton renders deterministic French words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fr", "ordinal_words", Args) =
             "deux mille trois cent quarante-cinqui" & U (16#E8#) & "me",
           "ordinal-word number skeleton renders French compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "en", "spellout_cardinal_alias", Args) =
             "two thousand three hundred forty-five",
           "spellout-cardinal aliases spellout");
   Assert (Rendered (Runtime, "en", "spellout_ordinal_alias", Args) =
             "two thousand three hundred forty-fifth",
           "spellout-ordinal aliases ordinal-words");
   Assert (Rendered (Runtime, "en", "spellout_numbering_alias", Args) =
             "two thousand three hundred forty-five",
           "spellout-numbering aliases spellout");
   Assert (Rendered (Runtime, "en", "spellout_numbering_year_alias", Args) =
             "two thousand three hundred forty-five",
           "spellout-numbering-year aliases spellout");
   Assert (Rendered (Runtime, "en", "spellout_year_alias", Args) =
             "two thousand three hundred forty-five",
           "spellout-year aliases spellout");
   Assert
     (Rendered
        (Runtime, "en", "spellout_numbering_verbose_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-numbering-verbose aliases spellout");
   Assert
     (Rendered
        (Runtime, "en", "spellout_numbering_financial_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-numbering-financial aliases spellout");
   Assert
     (Rendered
        (Runtime, "en", "spellout_cardinal_verbose_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-cardinal-verbose aliases spellout");
   Assert
     (Rendered (Runtime, "en", "spellout_cardinal_masculine_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-cardinal-masculine aliases spellout");
   Assert
     (Rendered (Runtime, "en", "spellout_cardinal_feminine_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-cardinal-feminine aliases spellout");
   Assert
     (Rendered (Runtime, "en", "spellout_cardinal_neuter_alias", Args) =
        "two thousand three hundred forty-five",
      "spellout-cardinal-neuter aliases spellout");
   Assert
     (Rendered (Runtime, "en", "spellout_ordinal_masculine_alias", Args) =
        "two thousand three hundred forty-fifth",
      "spellout-ordinal-masculine aliases ordinal-words");
   Assert
     (Rendered (Runtime, "en", "spellout_ordinal_feminine_alias", Args) =
        "two thousand three hundred forty-fifth",
      "spellout-ordinal-feminine aliases ordinal-words");
   Assert
     (Rendered (Runtime, "en", "spellout_ordinal_neuter_alias", Args) =
        "two thousand three hundred forty-fifth",
      "spellout-ordinal-neuter aliases ordinal-words");
   Assert
     (Rendered (Runtime, "en", "spellout_ordinal_verbose_alias", Args) =
        "two thousand three hundred forty-fifth",
      "spellout-ordinal-verbose aliases ordinal-words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "es", "spellout", Args) =
             "dos mil trescientos cuarenta y cinco",
           "spellout number skeleton renders deterministic Spanish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "es", "spellout", Args) =
             "un mill" & U (16#F3#) & "n uno",
           "spellout number skeleton renders Spanish million words");
   I18N.Arguments.Set (Args, "value", "26");
   Assert (Rendered (Runtime, "es", "spellout", Args) =
             "veintis" & U (16#E9#) & "is",
           "spellout number skeleton renders accented Spanish words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "es", "ordinal_words", Args) =
             "vig" & U (16#E9#) & "simo primero",
           "ordinal-word number skeleton renders deterministic Spanish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "es", "ordinal_words", Args) =
             "dos mil trescientos cuadrag" & U (16#E9#) & "simo quinto",
           "ordinal-word number skeleton renders Spanish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "it", "spellout", Args) =
             "duemilatrecentoquarantacinque",
           "spellout number skeleton renders deterministic Italian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "it", "spellout", Args) =
             "un milione uno",
           "spellout number skeleton renders Italian million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "it", "spellout", Args) =
             "ventitr" & U (16#E9#),
           "spellout number skeleton renders accented Italian words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "it", "ordinal_words", Args) =
             "ventunesimo",
           "ordinal-word number skeleton renders deterministic Italian words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "it", "ordinal_words", Args) =
             "duemilatrecentoquarantacinquesimo",
           "ordinal-word number skeleton renders Italian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "pt", "spellout", Args) =
             "dois mil trezentos e quarenta e cinco",
           "spellout number skeleton renders deterministic Portuguese words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "pt", "spellout", Args) =
             "um milh" & U (16#E3#) & "o um",
           "spellout number skeleton renders Portuguese million words");
   I18N.Arguments.Set (Args, "value", "3");
   Assert (Rendered (Runtime, "pt", "spellout", Args) =
             "tr" & U (16#EA#) & "s",
           "spellout number skeleton renders accented Portuguese words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "pt", "ordinal_words", Args) =
             "vig" & U (16#E9#) & "simo primeiro",
           "ordinal-word number skeleton renders deterministic Portuguese words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "pt", "ordinal_words", Args) =
             "dois mil trezentos quadrag" & U (16#E9#) & "simo quinto",
           "ordinal-word number skeleton renders Portuguese compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "nl", "spellout", Args) =
             "tweeduizend driehonderd vijfenveertig",
           "spellout number skeleton renders deterministic Dutch words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "nl", "spellout", Args) =
             "een miljoen een",
           "spellout number skeleton renders Dutch million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "nl", "spellout", Args) =
             "drie" & U (16#EB#) & "ntwintig",
           "spellout number skeleton renders accented Dutch words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "nl", "ordinal_words", Args) =
             "eenentwintigste",
           "ordinal-word number skeleton renders deterministic Dutch words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "nl", "ordinal_words", Args) =
             "tweeduizend driehonderd vijfenveertigste",
           "ordinal-word number skeleton renders Dutch compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "pl", "spellout", Args) =
             "dwa tysi" & U (16#105#) & "ce trzysta czterdzie"
             & U (16#15B#) & "ci pi" & U (16#119#) & U (16#107#),
           "spellout number skeleton renders deterministic Polish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "pl", "spellout", Args) =
             "jeden milion jeden",
           "spellout number skeleton renders Polish million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "pl", "spellout", Args) =
             "dwadzie" & U (16#15B#) & "cia trzy",
           "spellout number skeleton renders accented Polish words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "pl", "ordinal_words", Args) =
             "dwudziesty pierwszy",
           "ordinal-word number skeleton renders deterministic Polish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "pl", "ordinal_words", Args) =
             "dwa tysi" & U (16#105#) & "ce trzysta czterdziesty pi"
             & U (16#105#) & "ty",
           "ordinal-word number skeleton renders Polish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "cs", "spellout", Args) =
             "dva tis" & U (16#ED#) & "ce t" & U (16#159#)
             & "i sta " & U (16#10D#) & "ty" & U (16#159#)
             & "icet p" & U (16#11B#) & "t",
           "spellout number skeleton renders deterministic Czech words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "cs", "spellout", Args) =
             "jeden milion jeden",
           "spellout number skeleton renders Czech million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "cs", "spellout", Args) =
             "dvacet t" & U (16#159#) & "i",
           "spellout number skeleton renders accented Czech words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "cs", "ordinal_words", Args) =
             "dvac" & U (16#E1#) & "t" & U (16#FD#)
             & " prvn" & U (16#ED#),
           "ordinal-word number skeleton renders deterministic Czech words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "cs", "ordinal_words", Args) =
             "dva tis" & U (16#ED#) & "ce t" & U (16#159#)
             & "i sta " & U (16#10D#) & "ty" & U (16#159#)
             & "ic" & U (16#E1#) & "t" & U (16#FD#)
             & " p" & U (16#E1#) & "t" & U (16#FD#),
           "ordinal-word number skeleton renders Czech compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ru", "spellout", Args) =
             UTF8
               ([16#434#, 16#432#, 16#435#, 16#20#, 16#442#, 16#44B#,
                 16#441#, 16#44F#, 16#447#, 16#438#, 16#20#, 16#442#,
                 16#440#, 16#438#, 16#441#, 16#442#, 16#430#, 16#20#,
                 16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#, 16#20#,
                 16#43F#, 16#44F#, 16#442#, 16#44C#]),
           "spellout number skeleton renders deterministic Russian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "ru", "spellout", Args) =
             UTF8
               ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#20#, 16#43C#,
                 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#,
                 16#20#, 16#43E#, 16#434#, 16#438#, 16#43D#]),
           "spellout number skeleton renders Russian million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "ru", "spellout", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#430#,
                 16#442#, 16#44C#, 16#20#, 16#442#, 16#440#, 16#438#]),
           "spellout number skeleton renders Cyrillic Russian words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ru", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#430#,
                 16#442#, 16#44C#, 16#20#, 16#43F#, 16#435#, 16#440#,
                 16#432#, 16#44B#, 16#439#]),
           "ordinal-word number skeleton renders deterministic Russian words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ru", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#435#, 16#20#, 16#442#, 16#44B#,
                 16#441#, 16#44F#, 16#447#, 16#438#, 16#20#, 16#442#,
                 16#440#, 16#438#, 16#441#, 16#442#, 16#430#, 16#20#,
                 16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#, 16#20#,
                 16#43F#, 16#44F#, 16#442#, 16#44B#, 16#439#]),
           "ordinal-word number skeleton renders Russian compound words");

   I18N.Arguments.Set (Args, "value", "12345");
   Assert (Rendered (Runtime, "uk", "spellout", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#43D#, 16#430#,
                 16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#,
                 16#20#, 16#442#, 16#438#, 16#441#, 16#44F#,
                 16#447#, 16#20#, 16#442#, 16#440#, 16#438#,
                 16#441#, 16#442#, 16#430#, 16#20#, 16#441#,
                 16#43E#, 16#440#, 16#43E#, 16#43A#, 16#20#,
                 16#43F#, 16#27#, 16#44F#, 16#442#, 16#44C#]),
           "spellout number skeleton renders deterministic Ukrainian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "uk", "spellout", Args) =
             UTF8
               ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#20#,
                 16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#,
                 16#43E#, 16#43D#, 16#20#, 16#43E#, 16#434#,
                 16#438#, 16#43D#]),
           "spellout number skeleton renders Ukrainian million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "uk", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#,
                 16#44F#, 16#442#, 16#44C#, 16#20#, 16#43F#,
                 16#435#, 16#440#, 16#448#, 16#438#, 16#439#]),
           "ordinal-word number skeleton renders Ukrainian compound tens");
   I18N.Arguments.Set (Args, "value", "200");
   Assert (Rendered (Runtime, "uk", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#43E#, 16#445#, 16#441#,
                 16#43E#, 16#442#, 16#438#, 16#439#]),
           "ordinal-word number skeleton renders Ukrainian exact hundreds");
   I18N.Arguments.Set (Args, "value", "900");
   Assert (Rendered (Runtime, "uk", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                 16#442#, 16#438#, 16#441#, 16#43E#, 16#442#,
                 16#438#, 16#439#]),
           "ordinal-word number skeleton renders Ukrainian apostrophe hundreds");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "uk", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#456#, 16#20#, 16#442#,
                 16#438#, 16#441#, 16#44F#, 16#447#, 16#456#,
                 16#20#, 16#442#, 16#440#, 16#438#, 16#441#,
                 16#442#, 16#430#, 16#20#, 16#441#, 16#43E#,
                 16#440#, 16#43E#, 16#43A#, 16#20#, 16#43F#,
                 16#27#, 16#44F#, 16#442#, 16#438#, 16#439#]),
           "ordinal-word number skeleton renders Ukrainian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ja", "spellout", Args) =
             UTF8
               ([16#4E8C#, 16#5343#, 16#4E09#, 16#767E#, 16#56DB#,
                 16#5341#, 16#4E94#]),
           "spellout number skeleton renders deterministic Japanese words");
   I18N.Arguments.Set (Args, "value", "123456789");
   Assert (Rendered (Runtime, "ja", "spellout", Args) =
             UTF8
               ([16#4E00#, 16#5104#, 16#4E8C#, 16#5343#, 16#4E09#,
                 16#767E#, 16#56DB#, 16#5341#, 16#4E94#, 16#4E07#,
                 16#516D#, 16#5343#, 16#4E03#, 16#767E#, 16#516B#,
                 16#5341#, 16#4E5D#]),
           "spellout number skeleton renders Japanese oku and man groups");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "ja", "spellout", Args) =
             UTF8 ([16#4E8C#, 16#5341#, 16#4E09#]),
           "spellout number skeleton renders Japanese tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ja", "ordinal_words", Args) =
             UTF8 ([16#7B2C#, 16#4E8C#, 16#5341#, 16#4E00#]),
           "ordinal-word number skeleton renders Japanese ordinal prefix");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ja", "ordinal_words", Args) =
             UTF8
               ([16#7B2C#, 16#4E8C#, 16#5343#, 16#4E09#, 16#767E#,
                 16#56DB#, 16#5341#, 16#4E94#]),
           "ordinal-word number skeleton renders Japanese compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "zh", "spellout", Args) =
             UTF8
               ([16#4E8C#, 16#5343#, 16#4E09#, 16#767E#, 16#56DB#,
                 16#5341#, 16#4E94#]),
           "spellout number skeleton renders deterministic Chinese words");
   I18N.Arguments.Set (Args, "value", "123456789");
   Assert (Rendered (Runtime, "zh", "spellout", Args) =
             UTF8
               ([16#4E00#, 16#4EBF#, 16#4E8C#, 16#5343#, 16#4E09#,
                 16#767E#, 16#56DB#, 16#5341#, 16#4E94#, 16#4E07#,
                 16#516D#, 16#5343#, 16#4E03#, 16#767E#, 16#516B#,
                 16#5341#, 16#4E5D#]),
           "spellout number skeleton renders Chinese yi and wan groups");
   I18N.Arguments.Set (Args, "value", "1001");
   Assert (Rendered (Runtime, "zh", "spellout", Args) =
             UTF8 ([16#4E00#, 16#5343#, 16#96F6#, 16#4E00#]),
           "spellout number skeleton renders Chinese internal zero");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "zh", "ordinal_words", Args) =
             UTF8 ([16#7B2C#, 16#4E8C#, 16#5341#, 16#4E00#]),
           "ordinal-word number skeleton renders Chinese ordinal prefix");
   I18N.Arguments.Set (Args, "value", "10001");
   Assert (Rendered (Runtime, "zh", "ordinal_words", Args) =
             UTF8
               ([16#7B2C#, 16#4E00#, 16#4E07#, 16#96F6#, 16#4E00#]),
           "ordinal-word number skeleton renders Chinese section zero");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ko", "spellout", Args) =
             UTF8
               ([16#C774#, 16#CC9C#, 16#C0BC#, 16#BC31#, 16#C0AC#,
                 16#C2ED#, 16#C624#]),
           "spellout number skeleton renders deterministic Korean words");
   I18N.Arguments.Set (Args, "value", "123456789");
   Assert (Rendered (Runtime, "ko", "spellout", Args) =
             UTF8
               ([16#C77C#, 16#C5B5#, 16#C774#, 16#CC9C#, 16#C0BC#,
                 16#BC31#, 16#C0AC#, 16#C2ED#, 16#C624#, 16#B9CC#,
                 16#C721#, 16#CC9C#, 16#CE60#, 16#BC31#, 16#D314#,
                 16#C2ED#, 16#AD6C#]),
           "spellout number skeleton renders Korean eok and man groups");
   I18N.Arguments.Set (Args, "value", "1001");
   Assert (Rendered (Runtime, "ko", "spellout", Args) =
             UTF8 ([16#CC9C#, 16#C77C#]),
           "spellout number skeleton renders Korean omitted one before unit");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ko", "ordinal_words", Args) =
             UTF8 ([16#C81C#, 16#C774#, 16#C2ED#, 16#C77C#]),
           "ordinal-word number skeleton renders Korean ordinal prefix");
   I18N.Arguments.Set (Args, "value", "10001");
   Assert (Rendered (Runtime, "ko", "ordinal_words", Args) =
             UTF8 ([16#C81C#, 16#B9CC#, 16#C77C#]),
           "ordinal-word number skeleton renders Korean man group");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "tr", "spellout", Args) =
             "iki bin " & U (16#FC#) & U (16#E7#) & " y"
             & U (16#FC#) & "z k" & U (16#131#) & "rk be"
             & U (16#15F#),
           "spellout number skeleton renders deterministic Turkish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "tr", "spellout", Args) =
             "bir milyon bir",
           "spellout number skeleton renders Turkish million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "tr", "spellout", Args) =
             "yirmi " & U (16#FC#) & U (16#E7#),
           "spellout number skeleton renders Turkish accented words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "tr", "ordinal_words", Args) =
             "yirmi birinci",
           "ordinal-word number skeleton renders deterministic Turkish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "tr", "ordinal_words", Args) =
             "iki bin " & U (16#FC#) & U (16#E7#) & " y"
             & U (16#FC#) & "z k" & U (16#131#) & "rk be"
             & U (16#15F#) & "inci",
           "ordinal-word number skeleton renders Turkish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sv", "spellout", Args) =
             "tv" & U (16#E5#) & " tusen tre hundra fyrtio fem",
           "spellout number skeleton renders deterministic Swedish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "sv", "spellout", Args) =
             "en miljon ett",
           "spellout number skeleton renders Swedish million words");
   I18N.Arguments.Set (Args, "value", "28");
   Assert (Rendered (Runtime, "sv", "spellout", Args) =
             "tjugo " & U (16#E5#) & "tta",
           "spellout number skeleton renders Swedish accented words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "sv", "ordinal_words", Args) =
             "tjugo f" & U (16#F6#) & "rsta",
           "ordinal-word number skeleton renders deterministic Swedish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sv", "ordinal_words", Args) =
             "tv" & U (16#E5#) & " tusen tre hundra fyrtio femte",
           "ordinal-word number skeleton renders Swedish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "da", "spellout", Args) =
             "to tusind tre hundrede femogfyrre",
           "spellout number skeleton renders deterministic Danish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "da", "spellout", Args) =
             "en million en",
           "spellout number skeleton renders Danish million words");
   I18N.Arguments.Set (Args, "value", "23");
   Assert (Rendered (Runtime, "da", "spellout", Args) =
             "treogtyve",
           "spellout number skeleton renders Danish reversed tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "da", "ordinal_words", Args) =
             "enogtyvende",
           "ordinal-word number skeleton renders deterministic Danish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "da", "ordinal_words", Args) =
             "to tusind tre hundrede femogfyrretyvende",
           "ordinal-word number skeleton renders Danish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "no", "spellout", Args) =
             "to tusen tre hundre f" & U (16#F8#) & "rtifem",
           "spellout number skeleton renders deterministic Norwegian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "no", "spellout", Args) =
             "en million en",
           "spellout number skeleton renders Norwegian million words");
   I18N.Arguments.Set (Args, "value", "28");
   Assert (Rendered (Runtime, "no", "spellout", Args) =
             "tjue" & U (16#E5#) & "tte",
           "spellout number skeleton renders Norwegian compact tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "no", "ordinal_words", Args) =
             "tjuef" & U (16#F8#) & "rste",
           "ordinal-word number skeleton renders Norwegian words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "nb", "ordinal_words", Args) =
             "to tusen tre hundre f" & U (16#F8#) & "rtifemte",
           "ordinal-word number skeleton renders Norwegian nb alias");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fi", "spellout", Args) =
             "kaksituhatta kolmesataa nelj" & U (16#E4#)
             & "kymment" & U (16#E4#) & "viisi",
           "spellout number skeleton renders deterministic Finnish words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "fi", "spellout", Args) =
             "miljoona yksi",
           "spellout number skeleton renders Finnish million words");
   I18N.Arguments.Set (Args, "value", "28");
   Assert (Rendered (Runtime, "fi", "spellout", Args) =
             "kaksikymment" & U (16#E4#) & "kahdeksan",
           "spellout number skeleton renders Finnish compound tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "fi", "ordinal_words", Args) =
             "kahdeskymmenes ensimm" & U (16#E4#) & "inen",
           "ordinal-word number skeleton renders Finnish words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fi", "ordinal_words", Args) =
             "kaksituhatta kolmesataa nelj" & U (16#E4#)
             & "skymmenes viides",
           "ordinal-word number skeleton renders Finnish compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "id", "spellout", Args) =
             "dua ribu tiga ratus empat puluh lima",
           "spellout number skeleton renders Indonesian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "id", "spellout", Args) =
             "sejuta satu",
           "spellout number skeleton renders Indonesian sejuta words");
   I18N.Arguments.Set (Args, "value", "1111");
   Assert (Rendered (Runtime, "id", "spellout", Args) =
             "seribu seratus sebelas",
           "spellout number skeleton renders Indonesian se- forms");
   I18N.Arguments.Set (Args, "value", "1");
   Assert (Rendered (Runtime, "id", "ordinal_words", Args) =
             "pertama",
           "ordinal-word number skeleton renders Indonesian first word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "id", "ordinal_words", Args) =
             "ke-dua ribu tiga ratus empat puluh lima",
           "ordinal-word number skeleton renders Indonesian compound words");

   I18N.Arguments.Set (Args, "value", "0");
   Assert (Rendered (Runtime, "ms", "spellout", Args) =
             "sifar",
           "spellout number skeleton renders Malay zero word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ms", "spellout", Args) =
             "dua ribu tiga ratus empat puluh lima",
           "spellout number skeleton renders deterministic Malay words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "ms", "spellout", Args) =
             "sejuta satu",
           "spellout number skeleton renders Malay sejuta words");
   I18N.Arguments.Set (Args, "value", "1");
   Assert (Rendered (Runtime, "ms", "ordinal_words", Args) =
             "pertama",
           "ordinal-word number skeleton renders Malay first word");
   I18N.Arguments.Set (Args, "value", "1111");
   Assert (Rendered (Runtime, "ms", "ordinal_words", Args) =
             "ke-seribu seratus sebelas",
           "ordinal-word number skeleton renders Malay compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "eo", "spellout", Args) =
             "du mil tricent kvardek kvin",
           "spellout number skeleton renders deterministic Esperanto words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "eo", "spellout", Args) =
             "miliono unu",
           "spellout number skeleton renders Esperanto million words");
   I18N.Arguments.Set (Args, "value", "99");
   Assert (Rendered (Runtime, "eo", "spellout", Args) =
             "na" & U (16#16D#) & "dek na" & U (16#16D#),
           "spellout number skeleton renders Esperanto accented words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "eo", "ordinal_words", Args) =
             "dudek unua",
           "ordinal-word number skeleton renders Esperanto words");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "eo", "ordinal_words", Args) =
             "du mil tricent kvardek kvina",
           "ordinal-word number skeleton renders Esperanto compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "vi", "spellout", Args) =
             "hai ngh" & U (16#EC#) & "n ba tr" & U (16#103#)
             & "m b" & U (16#1ED1#) & "n m" & U (16#1B0#)
             & U (16#1A1#) & "i l" & U (16#103#) & "m",
           "spellout number skeleton renders deterministic Vietnamese words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "vi", "spellout", Args) =
             "m" & U (16#1ED9#) & "t tri" & U (16#1EC7#)
             & "u m" & U (16#1ED9#) & "t",
           "spellout number skeleton renders Vietnamese million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "vi", "spellout", Args) =
             "hai m" & U (16#1B0#) & U (16#1A1#) & "i m"
             & U (16#1ED1#) & "t",
           "spellout number skeleton renders Vietnamese mot compound");
   I18N.Arguments.Set (Args, "value", "105");
   Assert (Rendered (Runtime, "vi", "spellout", Args) =
             "m" & U (16#1ED9#) & "t tr" & U (16#103#)
             & "m linh n" & U (16#103#) & "m",
           "spellout number skeleton renders Vietnamese linh gap");
   I18N.Arguments.Set (Args, "value", "1");
   Assert (Rendered (Runtime, "vi", "ordinal_words", Args) =
             "th" & U (16#1EE9#) & " nh" & U (16#1EA5#) & "t",
           "ordinal-word number skeleton renders Vietnamese first word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "vi", "ordinal_words", Args) =
             "th" & U (16#1EE9#) & " hai ngh" & U (16#EC#)
             & "n ba tr" & U (16#103#) & "m b" & U (16#1ED1#)
             & "n m" & U (16#1B0#) & U (16#1A1#) & "i l"
             & U (16#103#) & "m",
           "ordinal-word number skeleton renders Vietnamese compound words");

   I18N.Arguments.Set (Args, "value", "0");
   Assert (Rendered (Runtime, "sw", "spellout", Args) =
             "sifuri",
           "spellout number skeleton renders Swahili zero word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sw", "spellout", Args) =
             "elfu mbili mia tatu arobaini na tano",
           "spellout number skeleton renders deterministic Swahili words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "sw", "spellout", Args) =
             "milioni moja moja",
           "spellout number skeleton renders Swahili million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "sw", "spellout", Args) =
             "ishirini na moja",
           "spellout number skeleton renders Swahili compound tens");
   I18N.Arguments.Set (Args, "value", "1");
   Assert (Rendered (Runtime, "sw", "ordinal_words", Args) =
             "kwanza",
           "ordinal-word number skeleton renders Swahili first word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sw", "ordinal_words", Args) =
             "wa elfu mbili mia tatu arobaini na tano",
           "ordinal-word number skeleton renders Swahili compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "af", "spellout", Args) =
             "twee duisend drie honderd vyf en veertig",
           "spellout number skeleton renders deterministic Afrikaans words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "af", "spellout", Args) =
             "een miljoen een",
           "spellout number skeleton renders Afrikaans million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "af", "spellout", Args) =
             "een en twintig",
           "spellout number skeleton renders Afrikaans reversed tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "af", "ordinal_words", Args) =
             "een en twintigste",
           "ordinal-word number skeleton renders Afrikaans reversed tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "af", "ordinal_words", Args) =
             "twee duisend drie honderd vyf en veertigste",
           "ordinal-word number skeleton renders Afrikaans compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "eu", "spellout", Args) =
             "bi mila hirurehun eta berrogeita bost",
           "spellout number skeleton renders deterministic Basque words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "eu", "spellout", Args) =
             "milioi bat bat",
           "spellout number skeleton renders Basque million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "eu", "spellout", Args) =
             "hogeita bat",
           "spellout number skeleton renders Basque vigesimal tens");
   I18N.Arguments.Set (Args, "value", "2");
   Assert (Rendered (Runtime, "eu", "ordinal_words", Args) =
             "bigarren",
           "ordinal-word number skeleton renders Basque second word");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "eu", "ordinal_words", Args) =
             "bi mila hirurehun eta berrogeita bostgarren",
           "ordinal-word number skeleton renders Basque compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ro", "spellout", Args) =
             "doi mii trei sute patruzeci " & U (16#219#) & "i cinci",
           "spellout number skeleton renders deterministic Romanian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "ro", "spellout", Args) =
             "un milion unu",
           "spellout number skeleton renders Romanian million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ro", "spellout", Args) =
             "dou" & U (16#103#) & "zeci " & U (16#219#) & "i unu",
           "spellout number skeleton renders Romanian si compounds");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ro", "ordinal_words", Args) =
             "al dou" & U (16#103#) & "zeci " & U (16#219#)
             & "i unulea",
           "ordinal-word number skeleton renders Romanian compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ro", "ordinal_words", Args) =
             "al doi mii trei sute patruzeci " & U (16#219#)
             & "i cincilea",
           "ordinal-word number skeleton renders Romanian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ca", "spellout", Args) =
             "dos mil tres-cents quaranta-cinc",
           "spellout number skeleton renders deterministic Catalan words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "ca", "spellout", Args) =
             "un mili" & U (16#F3#) & " un",
           "spellout number skeleton renders Catalan million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ca", "spellout", Args) =
             "vint-i-un",
           "spellout number skeleton renders Catalan vint-i compounds");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ca", "ordinal_words", Args) =
             "vint-i-primer",
           "ordinal-word number skeleton renders Catalan vint-i ordinals");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ca", "ordinal_words", Args) =
             "dos mil tres-cents quaranta-cinqu" & U (16#E8#),
           "ordinal-word number skeleton renders Catalan compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "hu", "spellout", Args) =
             "k" & U (16#E9#) & "tezer-h" & U (16#E1#)
             & "romsz" & U (16#E1#) & "znegyven" & U (16#F6#) & "t",
           "spellout number skeleton renders deterministic Hungarian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "hu", "spellout", Args) =
             "egymilli" & U (16#F3#) & "-egy",
           "spellout number skeleton renders Hungarian million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "hu", "spellout", Args) =
             "huszonegy",
           "spellout number skeleton renders Hungarian huszon compounds");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "hu", "ordinal_words", Args) =
             "huszonels" & U (16#151#),
           "ordinal-word number skeleton renders Hungarian compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "hu", "ordinal_words", Args) =
             "k" & U (16#E9#) & "tezer-h" & U (16#E1#)
             & "romsz" & U (16#E1#) & "znegyven"
             & U (16#F6#) & "t" & U (16#F6#) & "dik",
           "ordinal-word number skeleton renders Hungarian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sk", "spellout", Args) =
             "dva tis" & U (16#ED#) & "ce tristo "
             & U (16#161#) & "tyridsa" & U (16#165#) & " p"
             & U (16#E4#) & U (16#165#),
           "spellout number skeleton renders deterministic Slovak words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "sk", "spellout", Args) =
             "jeden mili" & U (16#F3#) & "n jeden",
           "spellout number skeleton renders Slovak million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "sk", "spellout", Args) =
             "dvadsa" & U (16#165#) & " jeden",
           "spellout number skeleton renders Slovak compound tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "sk", "ordinal_words", Args) =
             "dvadsiaty prv" & U (16#FD#),
           "ordinal-word number skeleton renders Slovak compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "sk", "ordinal_words", Args) =
             "dva tis" & U (16#ED#) & "ce tristo "
             & U (16#161#) & "tyridsiaty piaty",
           "ordinal-word number skeleton renders Slovak compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "bg", "spellout", Args) =
             UTF8
               ([16#434#, 16#432#, 16#435#, 16#20#, 16#445#,
                 16#438#, 16#43B#, 16#44F#, 16#434#, 16#438#,
                 16#20#, 16#442#, 16#440#, 16#438#, 16#441#,
                 16#442#, 16#430#, 16#20#, 16#447#, 16#435#,
                 16#442#, 16#438#, 16#440#, 16#438#, 16#434#,
                 16#435#, 16#441#, 16#435#, 16#442#, 16#20#,
                 16#438#, 16#20#, 16#43F#, 16#435#, 16#442#]),
           "spellout number skeleton renders deterministic Bulgarian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "bg", "spellout", Args) =
             UTF8
               ([16#435#, 16#434#, 16#438#, 16#43D#, 16#20#,
                 16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                 16#43D#, 16#20#, 16#435#, 16#434#, 16#43D#,
                 16#43E#]),
           "spellout number skeleton renders Bulgarian million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "bg", "spellout", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#434#, 16#435#,
                 16#441#, 16#435#, 16#442#, 16#20#, 16#438#,
                 16#20#, 16#435#, 16#434#, 16#43D#, 16#43E#]),
           "spellout number skeleton renders Bulgarian compound tens");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "bg", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#430#, 16#434#, 16#435#,
                 16#441#, 16#435#, 16#442#, 16#20#, 16#438#,
                 16#20#, 16#43F#, 16#44A#, 16#440#, 16#432#,
                 16#438#]),
           "ordinal-word number skeleton renders Bulgarian compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "bg", "ordinal_words", Args) =
             UTF8
               ([16#434#, 16#432#, 16#435#, 16#20#, 16#445#,
                 16#438#, 16#43B#, 16#44F#, 16#434#, 16#438#,
                 16#20#, 16#442#, 16#440#, 16#438#, 16#441#,
                 16#442#, 16#430#, 16#20#, 16#447#, 16#435#,
                 16#442#, 16#438#, 16#440#, 16#438#, 16#434#,
                 16#435#, 16#441#, 16#435#, 16#442#, 16#20#,
                 16#438#, 16#20#, 16#43F#, 16#435#, 16#442#,
                 16#438#]),
           "ordinal-word number skeleton renders Bulgarian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "ar", "spellout", Args) =
             UTF8
               ([16#623#, 16#644#, 16#641#, 16#627#, 16#646#,
                 16#20#, 16#648#, 16#62B#, 16#644#, 16#627#,
                 16#62B#, 16#645#, 16#627#, 16#626#, 16#629#,
                 16#20#, 16#648#, 16#62E#, 16#645#, 16#633#,
                 16#629#, 16#20#, 16#648#, 16#623#, 16#631#,
                 16#628#, 16#639#, 16#648#, 16#646#]),
           "spellout number skeleton renders deterministic Arabic words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "ar", "spellout", Args) =
             UTF8
               ([16#645#, 16#644#, 16#64A#, 16#648#, 16#646#,
                 16#20#, 16#648#, 16#648#, 16#627#, 16#62D#,
                 16#62F#]),
           "spellout number skeleton renders Arabic million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "ar", "ordinal_words", Args) =
             UTF8
               ([16#627#, 16#644#, 16#62D#, 16#627#, 16#62F#,
                 16#64A#, 16#20#, 16#648#, 16#627#, 16#644#,
                 16#639#, 16#634#, 16#631#, 16#648#, 16#646#]),
           "ordinal-word number skeleton renders Arabic compound tens");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fa", "spellout", Args) =
             UTF8
               ([16#62F#, 16#648#, 16#20#, 16#647#, 16#632#,
                 16#627#, 16#631#, 16#20#, 16#648#, 16#20#,
                 16#633#, 16#6CC#, 16#635#, 16#62F#, 16#20#,
                 16#648#, 16#20#, 16#686#, 16#647#, 16#644#,
                 16#20#, 16#648#, 16#20#, 16#67E#, 16#646#,
                 16#62C#]),
           "spellout number skeleton renders deterministic Persian words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "fa", "spellout", Args) =
             UTF8
               ([16#6CC#, 16#6A9#, 16#20#, 16#645#, 16#6CC#,
                 16#644#, 16#6CC#, 16#648#, 16#646#, 16#20#,
                 16#648#, 16#20#, 16#6CC#, 16#6A9#]),
           "spellout number skeleton renders Persian million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "fa", "ordinal_words", Args) =
             UTF8
               ([16#628#, 16#6CC#, 16#633#, 16#62A#, 16#20#,
                 16#648#, 16#20#, 16#6CC#, 16#6A9#, 16#645#]),
           "ordinal-word number skeleton renders Persian compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "fa", "ordinal_words", Args) =
             UTF8
               ([16#62F#, 16#648#, 16#20#, 16#647#, 16#632#,
                 16#627#, 16#631#, 16#20#, 16#648#, 16#20#,
                 16#633#, 16#6CC#, 16#635#, 16#62F#, 16#20#,
                 16#648#, 16#20#, 16#686#, 16#647#, 16#644#,
                 16#20#, 16#648#, 16#20#, 16#67E#, 16#646#,
                 16#62C#, 16#645#]),
           "ordinal-word number skeleton renders Persian compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "th", "spellout", Args) =
             UTF8
               ([16#E2A#, 16#E2D#, 16#E07#, 16#E1E#, 16#E31#,
                 16#E19#, 16#E2A#, 16#E32#, 16#E21#, 16#E23#,
                 16#E49#, 16#E2D#, 16#E22#, 16#E2A#, 16#E35#,
                 16#E48#, 16#E2A#, 16#E34#, 16#E1A#, 16#E2B#,
                 16#E49#, 16#E32#]),
           "spellout number skeleton renders deterministic Thai words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "th", "spellout", Args) =
             UTF8
               ([16#E2B#, 16#E19#, 16#E36#, 16#E48#, 16#E07#,
                 16#E25#, 16#E49#, 16#E32#, 16#E19#, 16#E2B#,
                 16#E19#, 16#E36#, 16#E48#, 16#E07#]),
           "spellout number skeleton renders Thai million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "th", "ordinal_words", Args) =
             UTF8
               ([16#E17#, 16#E35#, 16#E48#, 16#E22#, 16#E35#,
                 16#E48#, 16#E2A#, 16#E34#, 16#E1A#, 16#E40#,
                 16#E2D#, 16#E47#, 16#E14#]),
           "ordinal-word number skeleton renders Thai compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "th", "ordinal_words", Args) =
             UTF8
               ([16#E17#, 16#E35#, 16#E48#, 16#E2A#, 16#E2D#,
                 16#E07#, 16#E1E#, 16#E31#, 16#E19#, 16#E2A#,
                 16#E32#, 16#E21#, 16#E23#, 16#E49#, 16#E2D#,
                 16#E22#, 16#E2A#, 16#E35#, 16#E48#, 16#E2A#,
                 16#E34#, 16#E1A#, 16#E2B#, 16#E49#, 16#E32#]),
           "ordinal-word number skeleton renders Thai compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "hi", "spellout", Args) =
             UTF8
               ([16#926#, 16#94B#, 16#20#, 16#939#, 16#91C#,
                 16#93C#, 16#93E#, 16#930#, 16#20#, 16#924#,
                 16#940#, 16#928#, 16#20#, 16#938#, 16#94C#,
                 16#20#, 16#91A#, 16#93E#, 16#932#, 16#940#,
                 16#938#, 16#20#, 16#92A#, 16#93E#, 16#901#,
                 16#91A#]),
           "spellout number skeleton renders deterministic Hindi words");
   I18N.Arguments.Set (Args, "value", "100001");
   Assert (Rendered (Runtime, "hi", "spellout", Args) =
             UTF8
               ([16#90F#, 16#915#, 16#20#, 16#932#, 16#93E#,
                 16#916#, 16#20#, 16#90F#, 16#915#]),
           "spellout number skeleton renders Hindi lakh words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "hi", "ordinal_words", Args) =
             UTF8
               ([16#907#, 16#915#, 16#94D#, 16#915#, 16#940#,
                 16#938#, 16#935#, 16#93E#, 16#901#]),
           "ordinal-word number skeleton renders Hindi compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "hi", "ordinal_words", Args) =
             UTF8
               ([16#926#, 16#94B#, 16#20#, 16#939#, 16#91C#,
                 16#93C#, 16#93E#, 16#930#, 16#20#, 16#924#,
                 16#940#, 16#928#, 16#20#, 16#938#, 16#94C#,
                 16#20#, 16#91A#, 16#93E#, 16#932#, 16#940#,
                 16#938#, 16#20#, 16#92A#, 16#93E#, 16#901#,
                 16#91A#, 16#935#, 16#93E#, 16#901#]),
           "ordinal-word number skeleton renders Hindi compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "el", "spellout", Args) =
             UTF8
               ([16#3B4#, 16#3CD#, 16#3BF#, 16#20#, 16#3C7#,
                 16#3B9#, 16#3BB#, 16#3B9#, 16#3AC#, 16#3B4#,
                 16#3B5#, 16#3C2#, 16#20#, 16#3C4#, 16#3C1#,
                 16#3B9#, 16#3B1#, 16#3BA#, 16#3CC#, 16#3C3#,
                 16#3B9#, 16#3B1#, 16#20#, 16#3C3#, 16#3B1#,
                 16#3C1#, 16#3AC#, 16#3BD#, 16#3C4#, 16#3B1#,
                 16#20#, 16#3C0#, 16#3AD#, 16#3BD#, 16#3C4#,
                 16#3B5#]),
           "spellout number skeleton renders deterministic Greek words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "el", "spellout", Args) =
             UTF8
               ([16#3AD#, 16#3BD#, 16#3B1#, 16#20#, 16#3B5#,
                 16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#, 16#3BC#,
                 16#3BC#, 16#3CD#, 16#3C1#, 16#3B9#, 16#3BF#,
                 16#20#, 16#3AD#, 16#3BD#, 16#3B1#]),
           "spellout number skeleton renders Greek million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "el", "ordinal_words", Args) =
             UTF8
               ([16#3B5#, 16#3AF#, 16#3BA#, 16#3BF#, 16#3C3#,
                 16#3B9#, 16#20#, 16#3C0#, 16#3C1#, 16#3CE#,
                 16#3C4#, 16#3BF#]),
           "ordinal-word number skeleton renders Greek compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "el", "ordinal_words", Args) =
             UTF8
               ([16#3B4#, 16#3CD#, 16#3BF#, 16#20#, 16#3C7#,
                 16#3B9#, 16#3BB#, 16#3B9#, 16#3AC#, 16#3B4#,
                 16#3B5#, 16#3C2#, 16#20#, 16#3C4#, 16#3C1#,
                 16#3B9#, 16#3B1#, 16#3BA#, 16#3CC#, 16#3C3#,
                 16#3B9#, 16#3B1#, 16#20#, 16#3C3#, 16#3B1#,
                 16#3C1#, 16#3AC#, 16#3BD#, 16#3C4#, 16#3B1#,
                 16#20#, 16#3C0#, 16#3AD#, 16#3BC#, 16#3C0#,
                 16#3C4#, 16#3BF#]),
           "ordinal-word number skeleton renders Greek compound words");

   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "he", "spellout", Args) =
             UTF8
               ([16#5D0#, 16#5DC#, 16#5E4#, 16#5D9#, 16#5D9#,
                 16#5DD#, 16#20#, 16#5E9#, 16#5DC#, 16#5D5#,
                 16#5E9#, 16#20#, 16#5DE#, 16#5D0#, 16#5D5#,
                 16#5EA#, 16#20#, 16#5D0#, 16#5E8#, 16#5D1#,
                 16#5E2#, 16#5D9#, 16#5DD#, 16#20#, 16#5D7#,
                 16#5DE#, 16#5E9#]),
           "spellout number skeleton renders deterministic Hebrew words");
   I18N.Arguments.Set (Args, "value", "1000001");
   Assert (Rendered (Runtime, "he", "spellout", Args) =
             UTF8
               ([16#5D0#, 16#5D7#, 16#5D3#, 16#20#, 16#5DE#,
                 16#5D9#, 16#5DC#, 16#5D9#, 16#5D5#, 16#5DF#,
                 16#20#, 16#5D0#, 16#5D7#, 16#5D3#]),
           "spellout number skeleton renders Hebrew million words");
   I18N.Arguments.Set (Args, "value", "21");
   Assert (Rendered (Runtime, "he", "ordinal_words", Args) =
             UTF8
               ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D9#, 16#5DD#,
                 16#20#, 16#5E8#, 16#5D0#, 16#5E9#, 16#5D5#,
                 16#5DF#]),
           "ordinal-word number skeleton renders Hebrew compound tens");
   I18N.Arguments.Set (Args, "value", "2345");
   Assert (Rendered (Runtime, "he", "ordinal_words", Args) =
             UTF8
               ([16#5D0#, 16#5DC#, 16#5E4#, 16#5D9#, 16#5D9#,
                 16#5DD#, 16#20#, 16#5E9#, 16#5DC#, 16#5D5#,
                 16#5E9#, 16#20#, 16#5DE#, 16#5D0#, 16#5D5#,
                 16#5EA#, 16#20#, 16#5D0#, 16#5E8#, 16#5D1#,
                 16#5E2#, 16#5D9#, 16#5DD#, 16#20#, 16#5D7#,
                 16#5DE#, 16#5D9#, 16#5E9#, 16#5D9#]),
           "ordinal-word number skeleton renders Hebrew compound words");
end Test_Number_Rendering;
