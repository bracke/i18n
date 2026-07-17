separate (I18N.Runtime.Tests.Features)
procedure Test_Currency_Rendering
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
   Target  : String (1 .. 32) := [others => Character'Val (0)];
   Last    : Natural := 0;
   Status  : I18N.Result.Render_Status;
   Arabic_USD : constant String :=
     "$" & U (16#661#) & U (16#662#) & U (16#66B#)
     & U (16#663#) & U (16#660#);
begin
   I18N.Runtime.Load_Text
     (Runtime, "base",
      "en.price = ""Total {amount, currency, USD}""" & ASCII.LF
      & "de.price = ""Summe {amount, currency, EUR}""" & ASCII.LF
      & "en.yen = ""Total {amount, currency, JPY}""" & ASCII.LF
      & "en.skeleton = ""Total {amount, number, ::currency/USD}"""
      & ASCII.LF
      & "en.skeleton_accounting = ""{amount, number, ::currency/USD/accounting}"""
      & ASCII.LF
      & "ar.price = ""{amount, currency, USD}""" & ASCII.LF
      & "ar-u-nu-latn.price = ""{amount, currency, USD}""" & ASCII.LF
      & "en.kuwait = ""{amount, currency, KWD}""" & ASCII.LF
      & "en.name = ""{amount, currency, USD/name}""" & ASCII.LF
      & "de.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "fr.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "es.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "it.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "pt.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "nl.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "ro.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "lt.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "sl.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "pl.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "cs.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "ru.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "ar.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "ja.name = ""{amount, currency, EUR/name}""" & ASCII.LF
      & "zh.usd_name = ""{amount, currency, USD/name}""" & ASCII.LF
      & "ko.jpy_name = ""{amount, currency, JPY/name}""" & ASCII.LF
      & "ja.kwd_name = ""{amount, currency, KWD/name}""" & ASCII.LF
      & "ru.usd_name = ""{amount, currency, USD/name}""" & ASCII.LF
      & "ar.usd_name = ""{amount, currency, USD/name}""" & ASCII.LF
      & "ru.kwd_name = ""{amount, currency, KWD/name}""" & ASCII.LF
      & "ar.kwd_name = ""{amount, currency, KWD/name}""" & ASCII.LF
      & "ro.cad_name = ""{amount, currency, CAD/name}""" & ASCII.LF
      & "lt.chf_name = ""{amount, currency, CHF/name}""" & ASCII.LF
      & "sl.jpy_name = ""{amount, currency, JPY/name}""" & ASCII.LF
      & "pl.cad_name = ""{amount, currency, CAD/name}""" & ASCII.LF
      & "cs.czk_name = ""{amount, currency, CZK/name}""" & ASCII.LF
      & "de.cad_name = ""{amount, currency, CAD/name}""" & ASCII.LF
      & "fr.gbp_name = ""{amount, currency, GBP/name}""" & ASCII.LF
      & "es.jpy_name = ""{amount, currency, JPY/name}""" & ASCII.LF
      & "it.cad_name = ""{amount, currency, CAD/name}""" & ASCII.LF
      & "pt.gbp_name = ""{amount, currency, GBP/name}""" & ASCII.LF
      & "nl.jpy_name = ""{amount, currency, JPY/name}""" & ASCII.LF
      & "de.aud_name = ""{amount, currency, AUD/name}""" & ASCII.LF
      & "fr.nzd_name = ""{amount, currency, NZD/name}""" & ASCII.LF
      & "es.cny_name = ""{amount, currency, CNY/name}""" & ASCII.LF
      & "it.inr_name = ""{amount, currency, INR/name}""" & ASCII.LF
      & "pt.brl_name = ""{amount, currency, BRL/name}""" & ASCII.LF
      & "nl.sek_name = ""{amount, currency, SEK/name}""" & ASCII.LF
      & "de.try_name = ""{amount, currency, TRY/name}""" & ASCII.LF
      & "fr.zar_name = ""{amount, currency, ZAR/name}""" & ASCII.LF
      & "es.rub_name = ""{amount, currency, RUB/name}""" & ASCII.LF
      & "it.pln_name = ""{amount, currency, PLN/name}""" & ASCII.LF
      & "pt.czk_name = ""{amount, currency, CZK/name}""" & ASCII.LF
      & "nl.kwd_name = ""{amount, currency, KWD/name}""" & ASCII.LF
      & "en.clp_name = ""{amount, currency, CLP/name}""" & ASCII.LF
      & "en.bhd_name = ""{amount, currency, BHD/name}""" & ASCII.LF
      & "en.additional_zero_names = ""{amount, currency, COP/name}|"
      & "{amount, currency, ISK/name}|{amount, currency, MGA/name}|"
      & "{amount, currency, PYG/name}|{amount, currency, RWF/name}|"
      & "{amount, currency, UGX/name}|{amount, currency, UYI/name}|"
      & "{amount, currency, VND/name}|{amount, currency, XAF/name}|"
      & "{amount, currency, XOF/name}|{amount, currency, XPF/name}"""
      & ASCII.LF
      & "en.additional_three_names = ""{amount, currency, JOD/name}|"
      & "{amount, currency, LYD/name}|{amount, currency, OMR/name}|"
      & "{amount, currency, TND/name}""" & ASCII.LF
      & "en.huf_name = ""{amount, currency, HUF/name}""" & ASCII.LF
      & "en.clf = ""{amount, currency, CLF/unit-width-iso-code}""" & ASCII.LF
      & "en.clf_name = ""{amount, currency, CLF/name}""" & ASCII.LF
      & "en.aed = ""{amount, currency, AED}""" & ASCII.LF
      & "en.sgd_narrow = ""{amount, currency, SGD/narrow}""" & ASCII.LF
      & "en.hkd = ""{amount, currency, HKD}""" & ASCII.LF
      & "en.php_narrow = ""{amount, currency, PHP/narrow}""" & ASCII.LF
      & "en.thb = ""{amount, currency, THB}""" & ASCII.LF
      & "en.thb_narrow = ""{amount, currency, THB/narrow}""" & ASCII.LF
      & "en.ils = ""{amount, currency, ILS}""" & ASCII.LF
      & "en.bif_name = ""{amount, currency, BIF/name}""" & ASCII.LF
      & "en.iqd_name = ""{amount, currency, IQD/name}""" & ASCII.LF
      & "en.sar_name = ""{amount, currency, SAR/name}""" & ASCII.LF
      & "en.ars_name = ""{amount, currency, ARS/name}""" & ASCII.LF
      & "en.qar_name = ""{amount, currency, QAR/name}""" & ASCII.LF
      & "en.adp_name = ""{amount, currency, ADP/name}""" & ASCII.LF
      & "en.xcg_symbol = ""{amount, currency, XCG}""" & ASCII.LF
      & "en.ved_name = ""{amount, currency, VED/name}""" & ASCII.LF
      & "en.zwg_name = ""{amount, currency, ZWG/name}""" & ASCII.LF
      & "en.bdt_narrow = ""{amount, currency, BDT/narrow}""" & ASCII.LF
      & "bn.bdt = ""{amount, currency, BDT}""" & ASCII.LF
      & "bn.bdt_iso = ""{amount, currency, BDT/unit-width-iso-code}""" & ASCII.LF
      & "en-u-nu-beng.bdt = ""{amount, currency, BDT}""" & ASCII.LF
      & "en.khr = ""{amount, currency, KHR}""" & ASCII.LF
      & "en.khr_narrow = ""{amount, currency, KHR/narrow}""" & ASCII.LF
      & "en.gel = ""{amount, currency, GEL}""" & ASCII.LF
      & "en.gel_narrow = ""{amount, currency, GEL/narrow}""" & ASCII.LF
      & "en.narrow = ""{amount, currency, CAD/narrow}""" & ASCII.LF
      & "en.unit_name = ""{amount, currency, USD/unit-width-full-name}"""
      & ASCII.LF
      & "en.unit_name_slash = ""{amount, currency, USD/unit-width/full-name}"""
      & ASCII.LF
      & "en.unit_long = ""{amount, currency, USD/unit-width-long}"""
      & ASCII.LF
      & "en.unit_long_slash = ""{amount, currency, USD/unit-width/long}"""
      & ASCII.LF
      & "en.full_name = ""{amount, currency, USD/full-name}"""
      & ASCII.LF
      & "en.iso_alias = ""{amount, currency, USD/iso-code}"""
      & ASCII.LF
      & "en.standard_alias = ""{amount, currency, USD/standard}"""
      & ASCII.LF
      & "en.precision_standard_alias = ""{amount, currency, USD/precision-currency-standard}"""
      & ASCII.LF
      & "en.precision_standard_alias_slash = ""{amount, currency, USD/precision-currency/standard}"""
      & ASCII.LF
      & "en.unit_narrow = ""{amount, currency, CAD/unit-width-narrow}"""
      & ASCII.LF
      & "en.unit_narrow_slash = ""{amount, currency, CAD/unit-width/narrow}"""
      & ASCII.LF
      & "en.iso = ""{amount, currency, USD/unit-width-iso-code}"""
      & ASCII.LF
      & "en.iso_slash = ""{amount, currency, USD/unit-width/iso-code}"""
      & ASCII.LF
      & "de.iso = ""{amount, currency, EUR/unit-width-iso-code}"""
      & ASCII.LF
      & "ja.symbol = ""{amount, currency, USD}""" & ASCII.LF
      & "zh.symbol = ""{amount, currency, USD}""" & ASCII.LF
      & "ko.symbol = ""{amount, currency, USD}""" & ASCII.LF
      & "ja.iso = ""{amount, currency, USD/unit-width-iso-code}"""
      & ASCII.LF
      & "zh.iso = ""{amount, currency, USD/unit-width-iso-code}"""
      & ASCII.LF
      & "ko.iso = ""{amount, currency, USD/unit-width-iso-code}"""
      & ASCII.LF
      & "en.skeleton_iso = ""{amount, number, ::currency/USD/unit-width-iso-code}"""
      & ASCII.LF
      & "en.skeleton_unit_name = ""{amount, number, ::currency/USD unit-width-full-name}"""
      & ASCII.LF
      & "en.skeleton_unit_long = ""{amount, number, ::currency/USD unit-width-long}"""
      & ASCII.LF
      & "en.skeleton_full_name = ""{amount, number, ::currency/USD full-name}"""
      & ASCII.LF
      & "en.skeleton_iso_alias = ""{amount, number, ::currency/USD iso-code}"""
      & ASCII.LF
      & "en.skeleton_standard_alias = ""{amount, number, ::currency/USD precision-currency-standard}"""
      & ASCII.LF
      & "en.skeleton_iso_slash = ""{amount, number, ::currency/USD unit-width/iso-code}"""
      & ASCII.LF
      & "en.skeleton_unit_name_slash = ""{amount, number, ::currency/USD unit-width/full-name}"""
      & ASCII.LF
      & "en.skeleton_unit_long_slash = ""{amount, number, ::currency/USD unit-width/long}"""
      & ASCII.LF
      & "en.skeleton_unit_narrow_slash = ""{amount, number, ::currency/CAD unit-width/narrow}"""
      & ASCII.LF
      & "en.skeleton_usd_precision_standard_slash = ""{amount, number, ::currency/USD precision-currency/standard}"""
      & ASCII.LF
      & "en.skeleton_cash_accounting = ""{amount, number, "
      & "::currency/CHF cash sign-accounting unit-width-full-name}"""
      & ASCII.LF
      & "en.skeleton_cash_accounting_slash = ""{amount, number, "
      & "::currency/CHF precision-currency/cash sign/accounting "
      & "unit-width/full-name}"""
      & ASCII.LF
      & "en.skeleton_cash_accounting_suffix_slash = ""{amount, number, "
      & "::currency/CHF/cash/unit-width/full-name/accounting}"""
      & ASCII.LF
      & "en.skeleton_precision_cash = ""{amount, number, "
      & "::currency/CHF precision-currency-cash}"""
      & ASCII.LF
      & "en.skeleton_precision_cash_slash = ""{amount, number, "
      & "::currency/CHF precision/currency-cash}"""
      & ASCII.LF
      & "en.skeleton_precision_standard = ""{amount, number, "
      & "::currency/CHF precision-currency-cash "
      & "precision-currency-standard}"""
      & ASCII.LF
      & "en.skeleton_precision_standard_slash = ""{amount, number, "
      & "::currency/CHF precision-currency/cash "
      & "precision/currency-standard}"""
      & ASCII.LF
      & "en.skeleton_narrow_accounting = ""{amount, number, ::currency/CAD unit-width-narrow accounting}"""
      & ASCII.LF
      & "en.accounting = ""{amount, currency, USD/accounting}"""
      & ASCII.LF
      & "en.unit_narrow_accounting = ""{amount, currency, CAD/unit-width-narrow-accounting}"""
      & ASCII.LF
      & "en.unit_narrow_accounting_slash = "
      & """{amount, currency, CAD/unit-width/narrow/accounting}"""
      & ASCII.LF
      & "en.unit_name_accounting = ""{amount, currency, USD/unit-width-full-name-accounting}"""
      & ASCII.LF
      & "en.unit_name_accounting_slash = "
      & """{amount, currency, USD/unit-width/full-name/accounting}"""
      & ASCII.LF
      & "en.unit_iso_accounting = ""{amount, currency, USD/unit-width-iso-code-accounting}"""
      & ASCII.LF
      & "en.unit_iso_accounting_slash = "
      & """{amount, currency, USD/unit-width/iso-code/accounting}"""
      & ASCII.LF
      & "en.cash_unit_name_accounting = ""{amount, currency, CHF/cash-unit-width-full-name-accounting}"""
      & ASCII.LF
      & "en.cash_unit_name_accounting_slash = "
      & """{amount, currency, CHF/cash/unit-width/full-name/accounting}"""
      & ASCII.LF
      & "en.cad_cash = ""{amount, currency, CAD/cash-unit-width-iso-code}"""
      & ASCII.LF
      & "en.cad_cash_slash = ""{amount, currency, CAD/cash/unit-width/iso-code}"""
      & ASCII.LF
      & "en.dkk_cash = ""{amount, currency, DKK/cash-unit-width-iso-code}"""
      & ASCII.LF
      & "en.sek_cash = ""{amount, currency, SEK/cash-unit-width-iso-code}"""
      & ASCII.LF
      & "en.huf_cash = ""{amount, currency, HUF/cash-unit-width-iso-code}"""
      & ASCII.LF
      & "en.cash = ""{amount, currency, CHF/cash}""" & ASCII.LF
      & "en.cash_slash = ""{amount, currency, CHF/precision-currency/cash}"""
      & ASCII.LF,
      Result);
   Assert (Result.Status = I18N.Runtime.Loaded,
           "currency catalog should load");

   I18N.Arguments.Set (Args, "amount", "12.3");
   Assert (Rendered (Runtime, "en", "price", Args) = "Total $12.30",
           "English currency uses symbol prefix and dot decimal");
   Assert (Rendered (Runtime, "de", "price", Args) = "Summe 12,30 " & U (16#20AC#),
           "German currency uses comma decimal and symbol suffix");

   I18N.Runtime.Render_Into
     (Runtime, "en", "price", Args, Target, Last, Status);
   Assert (Status = I18N.Result.Success,
           "bounded currency render succeeds");
   Assert (Target (1 .. Last) = "Total $12.30",
           "bounded currency render matches materialized render");

   I18N.Arguments.Set (Args, "amount", "12");
   Assert (Rendered (Runtime, "en", "yen", Args) = "Total " & U (16#A5#) & "12",
           "zero-minor-unit currencies omit fractional digits");

   I18N.Arguments.Set (Args, "amount", "12.3");
   Assert (Rendered (Runtime, "en", "skeleton", Args) = "Total $12.30",
           "number currency skeleton renders as currency");
   Assert (Rendered (Runtime, "en", "name", Args) =
             "12.30 US dollars",
           "currency display-name option renders a localized name");
   Assert (Rendered (Runtime, "en", "narrow", Args) = "$12.30",
           "currency narrow-symbol option uses narrow symbols");
   Assert (Rendered (Runtime, "en", "unit_name", Args) =
             "12.30 US dollars",
           "currency unit-width-full-name option renders display name");
   Assert (Rendered (Runtime, "en", "unit_long", Args) =
             Rendered (Runtime, "en", "unit_name", Args),
           "currency unit-width-long aliases full-name display");
   Assert (Rendered (Runtime, "en", "full_name", Args) =
             Rendered (Runtime, "en", "unit_name", Args),
           "currency full-name aliases unit-width-full-name display");
   Assert (Rendered (Runtime, "en", "unit_narrow", Args) = "$12.30",
           "currency unit-width-narrow option uses narrow symbols");
   Assert (Rendered (Runtime, "en", "unit_narrow_slash", Args) =
             Rendered (Runtime, "en", "unit_narrow", Args),
           "currency unit-width/narrow option uses narrow symbols");
   Assert (Rendered (Runtime, "en", "aed", Args) = "AED 12.30",
           "code-like currency symbols are spaced before the number");
   Assert (Rendered (Runtime, "en", "sgd_narrow", Args) = "$12.30",
           "Singapore dollar narrow symbol uses built-in metadata");
   Assert (Rendered (Runtime, "en", "hkd", Args) = "HK$12.30",
           "Hong Kong dollar symbol uses built-in metadata");
   Assert (Rendered (Runtime, "en", "php_narrow", Args) =
             U (16#20B1#) & "12.30",
           "Philippine peso narrow symbol uses built-in metadata");
   Assert (Rendered (Runtime, "en", "thb", Args) = "THB 12.30",
           "Thai baht standard symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "thb_narrow", Args) =
             U (16#E3F#) & "12.30",
           "Thai baht narrow symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "ils", Args) =
             U (16#20AA#) & "12.30",
           "Israeli shekel symbol uses built-in metadata");
   Assert (Rendered (Runtime, "en", "bdt_narrow", Args) =
             U (16#9F3#) & "12.30",
           "Bangladeshi taka narrow symbol uses built-in metadata");
   Assert (Rendered (Runtime, "bn", "bdt", Args) =
             U (16#9E7#) & U (16#9E8#)
             & "." & U (16#9E9#) & U (16#9E6#) & " BDT",
           "Bengali currency uses Bengali digits and generated CLDR symbol");
   Assert (Rendered (Runtime, "bn", "bdt_iso", Args) =
             U (16#9E7#) & U (16#9E8#)
             & "." & U (16#9E9#) & U (16#9E6#) & " BDT",
           "Bengali currency ISO code follows the locale currency pattern");
   Assert (Rendered (Runtime, "en-u-nu-beng", "bdt", Args) =
             "BDT " & U (16#9E7#) & U (16#9E8#)
             & "." & U (16#9E9#) & U (16#9E6#),
           "currency honors explicit Bengali numbering-system digits");
   I18N.Arguments.Set (Args, "amount", "1234.5");
   Assert (Rendered (Runtime, "bn", "bdt", Args) =
             U (16#9E7#) & "," & U (16#9E8#)
             & U (16#9E9#) & U (16#9EA#) & "." & U (16#9EB#)
             & U (16#9E6#) & " BDT",
           "Bengali currency uses Indian grouping");
   I18N.Arguments.Set (Args, "amount", "12.3");
   Assert (Rendered (Runtime, "en", "khr", Args) = "KHR 12.30",
           "Cambodian riel standard symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "khr_narrow", Args) =
             U (16#17DB#) & "12.30",
           "Cambodian riel narrow symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "gel", Args) = "GEL 12.30",
           "Georgian lari standard symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "gel_narrow", Args) =
             U (16#20BE#) & "12.30",
           "Georgian lari narrow symbol uses generated CLDR metadata");
   Assert (Rendered (Runtime, "en", "iso", Args) = "USD 12.30",
           "currency unit-width-iso-code option renders ISO code");
   Assert (Rendered (Runtime, "en", "iso_slash", Args) =
             Rendered (Runtime, "en", "iso", Args),
           "currency unit-width/iso-code option renders ISO code");
   Assert (Rendered (Runtime, "en", "iso_alias", Args) =
             Rendered (Runtime, "en", "iso", Args),
           "currency iso-code aliases unit-width-iso-code display");
   Assert (Rendered (Runtime, "en", "standard_alias", Args) = "$12.30",
           "currency standard alias preserves symbol display");
   Assert (Rendered (Runtime, "en", "precision_standard_alias", Args) =
             "$12.30",
           "currency precision-currency-standard alias preserves standard precision");
   Assert (Rendered (Runtime, "en", "precision_standard_alias_slash",
             Args) =
             Rendered (Runtime, "en", "precision_standard_alias", Args),
           "currency precision-currency/standard alias preserves standard precision");
   Assert (Rendered (Runtime, "de", "iso", Args) = "12,30 EUR",
           "currency ISO-code option follows locale symbol position");
   Assert (Rendered (Runtime, "ja", "symbol", Args) = "$12.30",
           "Japanese currency symbols render before the amount");
   Assert (Rendered (Runtime, "zh", "symbol", Args) = "$12.30",
           "Chinese currency symbols render before the amount");
   Assert (Rendered (Runtime, "ko", "symbol", Args) = "$12.30",
           "Korean currency symbols render before the amount");
   Assert (Rendered (Runtime, "ja", "iso", Args) = "USD 12.30",
           "Japanese ISO currency code renders before the amount");
   Assert (Rendered (Runtime, "zh", "iso", Args) = "USD 12.30",
           "Chinese ISO currency code renders before the amount");
   Assert (Rendered (Runtime, "ko", "iso", Args) = "USD 12.30",
           "Korean ISO currency code renders before the amount");
   Assert (Rendered (Runtime, "en", "skeleton_iso", Args) = "USD 12.30",
           "number currency skeleton accepts unit-width-iso-code option");
   Assert (Rendered (Runtime, "en", "skeleton_iso_slash", Args) =
             Rendered (Runtime, "en", "skeleton_iso", Args),
           "number currency skeleton accepts unit-width/iso-code token");
   Assert (Rendered (Runtime, "en", "skeleton_unit_name", Args) =
             "12.30 US dollars",
           "number currency skeleton accepts separate unit-width tokens");
   Assert (Rendered (Runtime, "en", "skeleton_unit_name_slash", Args) =
             Rendered (Runtime, "en", "skeleton_unit_name", Args),
           "number currency skeleton accepts unit-width/full-name token");
   Assert (Rendered (Runtime, "en", "skeleton_unit_long", Args) =
             Rendered (Runtime, "en", "skeleton_unit_name", Args),
           "currency number skeleton unit-width-long aliases full-name");
   Assert (Rendered (Runtime, "en", "skeleton_unit_long_slash", Args) =
             Rendered (Runtime, "en", "skeleton_unit_name", Args),
           "currency number skeleton unit-width/long aliases full-name");
   Assert (Rendered (Runtime, "en", "skeleton_full_name", Args) =
             Rendered (Runtime, "en", "skeleton_unit_name", Args),
           "currency number skeleton full-name aliases full-name");
   Assert (Rendered (Runtime, "en", "skeleton_iso_alias", Args) =
             Rendered (Runtime, "en", "skeleton_iso", Args),
           "currency number skeleton iso-code aliases unit-width-iso-code");
   Assert (Rendered (Runtime, "en", "skeleton_standard_alias", Args) =
             "$12.30",
           "currency number skeleton precision-currency-standard is accepted");
   Assert (Rendered (Runtime, "en",
             "skeleton_usd_precision_standard_slash", Args) =
             Rendered (Runtime, "en", "skeleton_standard_alias", Args),
           "currency number skeleton accepts precision-currency/standard");
   Assert (Rendered (Runtime, "en", "skeleton_unit_narrow_slash", Args) =
             "$12.30",
           "currency number skeleton accepts unit-width/narrow token");
   I18N.Arguments.Set (Args, "amount", "1");
   Assert (Rendered (Runtime, "en", "name", Args) =
             "1.00 US dollar",
           "currency display-name option renders singular names");
   Assert (Rendered (Runtime, "en", "skeleton_unit_name", Args) =
             "1.00 US dollar",
           "number currency skeleton renders singular display names");
   Assert (Rendered (Runtime, "en", "unit_name_slash", Args) =
             Rendered (Runtime, "en", "unit_name", Args),
           "currency unit-width/full-name aliases full-name");
   Assert (Rendered (Runtime, "en", "unit_long_slash", Args) =
             Rendered (Runtime, "en", "unit_long", Args),
           "currency unit-width/long aliases full-name");
   Assert (Rendered (Runtime, "de", "name", Args) = "1,00 Euro",
           "currency display names localize German singular output");
   Assert (Rendered (Runtime, "fr", "name", Args) = "1,00 euro",
           "currency display names localize French singular output");
   Assert (Rendered (Runtime, "es", "name", Args) = "1,00 euro",
           "currency display names localize Spanish singular output");
   Assert (Rendered (Runtime, "it", "name", Args) = "1,00 euro",
           "currency display names localize Italian singular output");
   Assert (Rendered (Runtime, "pt", "name", Args) = "1,00 Euro",
           "currency display names localize Portuguese singular output");
   Assert (Rendered (Runtime, "nl", "name", Args) = "1,00 euro",
           "currency display names localize Dutch singular output");
   Assert (Rendered (Runtime, "ro", "name", Args) = "1,00 euro",
           "currency display names localize Romanian singular output");
   Assert (Rendered (Runtime, "lt", "name", Args) = "1,00 euras",
           "currency display names localize Lithuanian singular output");
   Assert (Rendered (Runtime, "sl", "name", Args) = "1,00 evro",
           "currency display names localize Slovenian singular output");
   Assert (Rendered (Runtime, "pl", "name", Args) = "1,00 euro",
           "currency display names localize Polish singular output");
   Assert (Rendered (Runtime, "cs", "name", Args) = "1,00 euro",
           "currency display names localize Czech singular output");
   Assert (Rendered (Runtime, "ru", "name", Args) =
             "1,00 " & UTF8 ([16#435#, 16#432#, 16#440#, 16#43E#]),
           "currency display names localize Russian singular output");
   Assert (Rendered (Runtime, "ar", "name", Args) =
             U (16#0661#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & " " & UTF8 ([16#64A#, 16#648#, 16#631#, 16#648#]),
           "currency display names localize Arabic singular output");
   Assert (Rendered (Runtime, "ja", "name", Args) =
             "1.00 " & UTF8 ([16#30E6#, 16#30FC#, 16#30ED#]),
           "currency display names localize Japanese singular output");
   Assert (Rendered (Runtime, "zh", "usd_name", Args) =
             "1.00 " & UTF8 ([16#7F8E#, 16#5143#]),
           "currency display names localize Chinese USD singular output");
   Assert (Rendered (Runtime, "ko", "jpy_name", Args) =
             "1 " & UTF8 ([16#C77C#, 16#BCF8#, 16#20#, 16#C5D4#, 16#D654#]),
           "currency display names localize Korean JPY singular output");
   Assert (Rendered (Runtime, "ja", "kwd_name", Args) =
             "1.000 " & UTF8 ([16#30AF#, 16#30A6#, 16#30A7#, 16#30FC#,
                                16#30C8#, 16#20#, 16#30C7#, 16#30A3#,
                                16#30CA#, 16#30FC#, 16#30EB#]),
           "currency display names localize Japanese KWD singular output");
   Assert (Rendered (Runtime, "ru", "usd_name", Args) =
             "1,00 "
             & UTF8 ([16#434#, 16#43E#, 16#43B#, 16#43B#, 16#430#,
                       16#440#, 16#20#, 16#421#, 16#428#, 16#410#]),
           "currency display names localize Russian USD singular output");
   Assert (Rendered (Runtime, "ar", "usd_name", Args) =
             U (16#0661#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & " "
             & UTF8 ([16#62F#, 16#648#, 16#644#, 16#627#, 16#631#,
                       16#20#, 16#623#, 16#645#, 16#631#, 16#64A#,
                       16#643#, 16#64A#]),
           "currency display names localize Arabic USD singular output");
   Assert (Rendered (Runtime, "ru", "kwd_name", Args) =
             "1,000 "
             & UTF8 ([16#43A#, 16#443#, 16#432#, 16#435#, 16#439#,
                       16#442#, 16#441#, 16#43A#, 16#438#, 16#439#,
                       16#20#, 16#434#, 16#438#, 16#43D#, 16#430#,
                       16#440#]),
           "currency display names localize Russian KWD singular output");
   Assert (Rendered (Runtime, "ar", "kwd_name", Args) =
             U (16#0661#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & U (16#0660#) & " "
             & UTF8 ([16#62F#, 16#64A#, 16#646#, 16#627#, 16#631#,
                       16#20#, 16#643#, 16#648#, 16#64A#, 16#62A#,
                       16#64A#]),
           "currency display names localize Arabic KWD singular output");
   Assert (Rendered (Runtime, "ro", "cad_name", Args) =
             "1,00 dolar canadian",
           "currency display names localize Romanian CAD singular output");
   Assert (Rendered (Runtime, "lt", "chf_name", Args) =
             "1,00 " & U (16#160#) & "veicarijos frankas",
           "currency display names localize Lithuanian CHF singular output");
   Assert (Rendered (Runtime, "sl", "jpy_name", Args) =
             "1 japonski jen",
           "currency display names localize Slovenian JPY singular output");
   Assert (Rendered (Runtime, "pl", "cad_name", Args) =
             "1,00 dolar kanadyjski",
           "currency display names localize Polish CAD singular output");
   Assert (Rendered (Runtime, "cs", "czk_name", Args) =
             "1,00 " & U (16#10D#) & "esk" & U (16#E1#) & " koruna",
           "currency display names localize Czech CZK singular output");
   Assert (Rendered (Runtime, "de", "cad_name", Args) =
             "1,00 Kanadischer Dollar",
           "currency display names localize German CAD singular output");
   Assert (Rendered (Runtime, "fr", "gbp_name", Args) =
             "1,00 livre sterling",
           "currency display names localize French GBP singular output");
   Assert (Rendered (Runtime, "es", "jpy_name", Args) =
             "1 yen japon" & U (16#E9#) & "s",
           "currency display names localize Spanish JPY singular output");
   Assert (Rendered (Runtime, "it", "cad_name", Args) =
             "1,00 dollaro canadese",
           "currency display names localize Italian CAD singular output");
   Assert (Rendered (Runtime, "pt", "gbp_name", Args) =
             "1,00 Libra esterlina",
           "currency display names localize Portuguese GBP singular output");
   Assert (Rendered (Runtime, "nl", "jpy_name", Args) =
             "1 Japanse yen",
           "currency display names localize Dutch JPY singular output");
   Assert (Rendered (Runtime, "de", "aud_name", Args) =
             "1,00 Australischer Dollar",
           "currency display names localize German AUD singular output");
   Assert (Rendered (Runtime, "fr", "nzd_name", Args) =
             "1,00 dollar n" & U (16#E9#) & "o-z" & U (16#E9#) & "landais",
           "currency display names localize French NZD singular output");
   Assert (Rendered (Runtime, "es", "cny_name", Args) =
             "1,00 yuan renminbi",
           "currency display names localize Spanish CNY singular output");
   Assert (Rendered (Runtime, "it", "inr_name", Args) =
             "1,00 rupia indiana",
           "currency display names localize Italian INR singular output");
   Assert (Rendered (Runtime, "pt", "brl_name", Args) =
             "1,00 Real brasileiro",
           "currency display names localize Portuguese BRL singular output");
   Assert (Rendered (Runtime, "nl", "sek_name", Args) =
             "1,00 Zweedse kroon",
           "currency display names localize Dutch SEK singular output");
   Assert (Rendered (Runtime, "de", "try_name", Args) =
             "1,00 T" & U (16#FC#) & "rkische Lira",
           "currency display names localize German TRY singular output");
   Assert (Rendered (Runtime, "fr", "zar_name", Args) =
             "1,00 rand sud-africain",
           "currency display names localize French ZAR singular output");
   Assert (Rendered (Runtime, "es", "rub_name", Args) =
             "1,00 rublo ruso",
           "currency display names localize Spanish RUB singular output");
   Assert (Rendered (Runtime, "it", "pln_name", Args) =
             "1,00 zloty polacco",
           "currency display names localize Italian PLN singular output");
   Assert (Rendered (Runtime, "pt", "czk_name", Args) =
             "1,00 Coroa tcheca",
           "currency display names localize Portuguese CZK singular output");
   Assert (Rendered (Runtime, "nl", "kwd_name", Args) =
             "1,000 Koeweitse dinar",
           "currency display names localize Dutch KWD singular output");
   Assert (Rendered (Runtime, "en", "clp_name", Args) =
             "1 Chilean peso",
           "currency display names singularize zero-minor-unit CLP output");
   Assert (Rendered (Runtime, "en", "bhd_name", Args) =
             "1.000 Bahraini dinar",
           "currency display names singularize three-minor-unit BHD output");
   Assert (Rendered (Runtime, "en", "additional_zero_names", Args) =
             "1.00 Colombian peso|1 Icelandic kr" & U (16#F3#) & "na|1 Malagasy ariary|"
             & "1 Paraguayan guarani|1 Rwandan franc|"
             & "1 Ugandan shilling|1 Uruguayan peso (indexed units)|"
             & "1 Vietnamese dong|1 Central African CFA franc|"
             & "1 West African CFA franc|1 CFP franc",
           "currency display names singularize added minor-unit corpus");
   Assert (Rendered (Runtime, "en", "additional_three_names", Args) =
             "1.000 Jordanian dinar|1.000 Libyan dinar|"
             & "1.000 Omani rial|1.000 Tunisian dinar",
           "currency display names singularize added three-minor corpus");
   Assert (Rendered (Runtime, "en", "huf_name", Args) =
             "1.00 Hungarian forint",
           "currency display names singularize HUF output");
   Assert (Rendered (Runtime, "en", "clf_name", Args) =
             "1.0000 Chilean unit of account (UF)",
           "currency display names singularize four-minor-unit CLF output");
   Assert (Rendered (Runtime, "en", "bif_name", Args) =
             "1 Burundian franc",
           "currency display names singularize added zero-minor output");
   Assert (Rendered (Runtime, "en", "iqd_name", Args) =
             "1 Iraqi dinar",
           "currency display names singularize added zero-minor output");
   Assert (Rendered (Runtime, "en", "sar_name", Args) =
             "1.00 Saudi riyal",
           "currency display names singularize added two-minor output");
   Assert (Rendered (Runtime, "en", "ars_name", Args) =
             "1.00 Argentine peso",
           "currency display names singularize added Latin America output");
   Assert (Rendered (Runtime, "en", "qar_name", Args) =
             "1.00 Qatari riyal",
           "currency display names singularize added Middle East output");
   I18N.Arguments.Set (Args, "amount", "2");
   Assert (Rendered (Runtime, "en", "adp_name", Args) =
             "2 Andorran pesetas",
           "currency metadata covers CLDR historic zero-minor codes");
   Assert (Rendered (Runtime, "en", "xcg_symbol", Args) =
             "Cg.2.00",
           "currency metadata covers CLDR 46.1 Caribbean guilder symbol");
   Assert (Rendered (Runtime, "en", "ved_name", Args) =
             "2.00 Bol" & U (16#ED#) & "var Soberanos",
           "currency metadata covers CLDR Venezuelan digital unit names");
   Assert (Rendered (Runtime, "en", "zwg_name", Args) =
             "2.00 Zimbabwean gold",
           "currency metadata covers CLDR Zimbabwe Gold names");
   I18N.Arguments.Set (Args, "amount", "2");
   Assert (Rendered (Runtime, "de", "name", Args) = "2,00 Euro",
           "currency display names localize German plural output");
   Assert (Rendered (Runtime, "fr", "name", Args) = "2,00 euros",
           "currency display names localize French plural output");
   Assert (Rendered (Runtime, "es", "name", Args) = "2,00 euros",
           "currency display names localize Spanish plural output");
   Assert (Rendered (Runtime, "it", "name", Args) = "2,00 euro",
           "currency display names localize Italian plural output");
   Assert (Rendered (Runtime, "pt", "name", Args) = "2,00 Euros",
           "currency display names localize Portuguese plural output");
   Assert (Rendered (Runtime, "nl", "name", Args) = "2,00 euro",
           "currency display names localize Dutch plural output");
   Assert (Rendered (Runtime, "ro", "name", Args) = "2,00 euro",
           "currency display names localize Romanian plural output");
   Assert (Rendered (Runtime, "lt", "name", Args) =
             "2,00 eurai",
           "currency display names localize Lithuanian plural output");
   Assert (Rendered (Runtime, "sl", "name", Args) = "2,00 evra",
           "currency display names localize Slovenian plural output");
   Assert (Rendered (Runtime, "pl", "name", Args) = "2,00 euro",
           "currency display names localize Polish plural output");
   Assert (Rendered (Runtime, "cs", "name", Args) = "2,00 eura",
           "currency display names localize Czech plural output");
   Assert (Rendered (Runtime, "ru", "name", Args) =
             "2,00 " & UTF8 ([16#435#, 16#432#, 16#440#, 16#43E#]),
           "currency display names localize Russian plural output");
   Assert (Rendered (Runtime, "ar", "name", Args) =
             U (16#0662#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & " "
             & UTF8 ([16#64A#, 16#648#, 16#631#, 16#648#]),
           "currency display names localize Arabic plural output");
   Assert (Rendered (Runtime, "ja", "name", Args) =
             "2.00 " & UTF8 ([16#30E6#, 16#30FC#, 16#30ED#]),
           "currency display names localize Japanese plural output");
   Assert (Rendered (Runtime, "zh", "usd_name", Args) =
             "2.00 " & UTF8 ([16#7F8E#, 16#5143#]),
           "currency display names localize Chinese USD plural output");
   Assert (Rendered (Runtime, "ko", "jpy_name", Args) =
             "2 " & UTF8 ([16#C77C#, 16#BCF8#, 16#20#, 16#C5D4#, 16#D654#]),
           "currency display names localize Korean JPY plural output");
   Assert (Rendered (Runtime, "ru", "usd_name", Args) =
             "2,00 "
             & UTF8 ([16#434#, 16#43E#, 16#43B#, 16#43B#, 16#430#,
                       16#440#, 16#430#, 16#20#, 16#421#, 16#428#,
                       16#410#]),
           "currency display names localize Russian USD plural output");
   Assert (Rendered (Runtime, "ar", "usd_name", Args) =
             U (16#0662#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & " "
             & UTF8 ([16#62F#, 16#648#, 16#644#, 16#627#, 16#631#,
                       16#20#, 16#623#, 16#645#, 16#631#, 16#64A#,
                       16#643#, 16#64A#]),
           "currency display names localize Arabic USD plural output");
   Assert (Rendered (Runtime, "ru", "kwd_name", Args) =
             "2,000 "
             & UTF8 ([16#43A#, 16#443#, 16#432#, 16#435#, 16#439#,
                       16#442#, 16#441#, 16#43A#, 16#438#, 16#445#,
                       16#20#, 16#434#, 16#438#, 16#43D#, 16#430#,
                       16#440#, 16#430#]),
           "currency display names localize Russian KWD plural output");
   Assert (Rendered (Runtime, "ar", "kwd_name", Args) =
             U (16#0662#) & U (16#066B#) & U (16#0660#) & U (16#0660#)
             & U (16#0660#) & " "
             & UTF8 ([16#62F#, 16#64A#, 16#646#, 16#627#, 16#631#,
                       16#20#, 16#643#, 16#648#, 16#64A#, 16#62A#,
                       16#64A#]),
           "currency display names localize Arabic KWD plural output");
   Assert (Rendered (Runtime, "ro", "cad_name", Args) =
             "2,00 dolari canadieni",
           "currency display names localize Romanian CAD plural output");
   Assert (Rendered (Runtime, "lt", "chf_name", Args) =
             "2,00 " & U (16#160#) & "veicarijos frankai",
           "currency display names localize Lithuanian CHF plural output");
   Assert (Rendered (Runtime, "sl", "jpy_name", Args) =
             "2 japonska jena",
           "currency display names localize Slovenian JPY plural output");
   Assert (Rendered (Runtime, "pl", "cad_name", Args) =
             "2,00 dolary kanadyjskie",
           "currency display names localize Polish CAD plural output");
   Assert (Rendered (Runtime, "cs", "czk_name", Args) =
             "2,00 " & U (16#10D#) & "esk" & U (16#E9#) & " koruny",
           "currency display names localize Czech CZK plural output");
   Assert (Rendered (Runtime, "de", "cad_name", Args) =
             "2,00 Kanadische Dollar",
           "currency display names localize German CAD plural output");
   Assert (Rendered (Runtime, "fr", "gbp_name", Args) =
             "2,00 livres sterling",
           "currency display names localize French GBP plural output");
   Assert (Rendered (Runtime, "es", "jpy_name", Args) =
             "2 yenes japoneses",
           "currency display names localize Spanish JPY plural output");
   Assert (Rendered (Runtime, "it", "cad_name", Args) =
             "2,00 dollari canadesi",
           "currency display names localize Italian CAD plural output");
   Assert (Rendered (Runtime, "pt", "gbp_name", Args) =
             "2,00 Libras esterlinas",
           "currency display names localize Portuguese GBP plural output");
   Assert (Rendered (Runtime, "nl", "jpy_name", Args) =
             "2 Japanse yen",
           "currency display names localize Dutch JPY plural output");
   Assert (Rendered (Runtime, "de", "aud_name", Args) =
             "2,00 Australische Dollar",
           "currency display names localize German AUD plural output");
   Assert (Rendered (Runtime, "fr", "nzd_name", Args) =
             "2,00 dollars n" & U (16#E9#) & "o-z" & U (16#E9#) & "landais",
           "currency display names localize French NZD plural output");
   Assert (Rendered (Runtime, "es", "cny_name", Args) =
             "2,00 yuanes renminbi",
           "currency display names localize Spanish CNY plural output");
   Assert (Rendered (Runtime, "it", "inr_name", Args) =
             "2,00 rupie indiane",
           "currency display names localize Italian INR plural output");
   Assert (Rendered (Runtime, "pt", "brl_name", Args) =
             "2,00 Reais brasileiros",
           "currency display names localize Portuguese BRL plural output");
   Assert (Rendered (Runtime, "nl", "sek_name", Args) =
             "2,00 Zweedse kronen",
           "currency display names localize Dutch SEK plural output");
   Assert (Rendered (Runtime, "de", "try_name", Args) =
             "2,00 T" & U (16#FC#) & "rkische Lira",
           "currency display names localize German TRY plural output");
   Assert (Rendered (Runtime, "fr", "zar_name", Args) =
             "2,00 rands sud-africains",
           "currency display names localize French ZAR plural output");
   Assert (Rendered (Runtime, "es", "rub_name", Args) =
             "2,00 rublos rusos",
           "currency display names localize Spanish RUB plural output");
   Assert (Rendered (Runtime, "it", "pln_name", Args) =
             "2,00 zloty polacchi",
           "currency display names localize Italian PLN plural output");
   Assert (Rendered (Runtime, "pt", "czk_name", Args) =
             "2,00 Coroas tchecas",
           "currency display names localize Portuguese CZK plural output");
   Assert (Rendered (Runtime, "nl", "kwd_name", Args) =
             "2,000 Koeweitse dinar",
           "currency display names localize Dutch KWD plural output");
   Assert (Rendered (Runtime, "en", "clp_name", Args) =
             "2 Chilean pesos",
           "currency display names pluralize zero-minor-unit CLP output");
   Assert (Rendered (Runtime, "en", "bhd_name", Args) =
             "2.000 Bahraini dinars",
           "currency display names pluralize three-minor-unit BHD output");
   Assert (Rendered (Runtime, "en", "additional_zero_names", Args) =
             "2.00 Colombian pesos|2 Icelandic kr" & U (16#F3#) & "nur|2 Malagasy ariaries|"
             & "2 Paraguayan guaranis|2 Rwandan francs|"
             & "2 Ugandan shillings|2 Uruguayan pesos (indexed units)|"
             & "2 Vietnamese dong|2 Central African CFA francs|"
             & "2 West African CFA francs|2 CFP francs",
           "currency display names pluralize added minor-unit corpus");
   Assert (Rendered (Runtime, "en", "additional_three_names", Args) =
             "2.000 Jordanian dinars|2.000 Libyan dinars|"
             & "2.000 Omani rials|2.000 Tunisian dinars",
           "currency display names pluralize added three-minor corpus");
   Assert (Rendered (Runtime, "en", "huf_name", Args) =
             "2.00 Hungarian forints",
           "currency display names pluralize HUF output");
   Assert (Rendered (Runtime, "en", "clf_name", Args) =
             "2.0000 Chilean units of account (UF)",
           "currency display names pluralize four-minor-unit CLF output");
   Assert (Rendered (Runtime, "en", "bif_name", Args) =
             "2 Burundian francs",
           "currency display names pluralize added zero-minor output");
   Assert (Rendered (Runtime, "en", "iqd_name", Args) =
             "2 Iraqi dinars",
           "currency display names pluralize added zero-minor output");
   Assert (Rendered (Runtime, "en", "sar_name", Args) =
             "2.00 Saudi riyals",
           "currency display names pluralize added two-minor output");
   Assert (Rendered (Runtime, "en", "ars_name", Args) =
             "2.00 Argentine pesos",
           "currency display names pluralize added Latin America output");
   Assert (Rendered (Runtime, "en", "qar_name", Args) =
             "2.00 Qatari riyals",
           "currency display names pluralize added Middle East output");
   I18N.Arguments.Set (Args, "amount", "12.3");

   Assert (Rendered (Runtime, "ar", "price", Args) = Arabic_USD,
           "Arabic currency uses localized digits and decimal separator");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "price", Args) =
             "$12" & U (16#66B#) & "30",
           "currency numbering-system extension overrides Arabic digits");

   I18N.Arguments.Set (Args, "amount", "1.234");
   Assert (Rendered (Runtime, "en", "kuwait", Args) = "KWD 1.234",
           "three-minor-unit currencies preserve three fraction digits");
   I18N.Arguments.Set (Args, "amount", "1.2345");
   Assert (Rendered (Runtime, "en", "clf", Args) = "CLF 1.2345",
           "four-minor-unit currencies preserve four fraction digits");

   I18N.Arguments.Set (Args, "amount", "-12.3");
   Assert (Rendered (Runtime, "en", "accounting", Args) = "($12.30)",
           "currency accounting option uses parentheses for negatives");
   Assert (Rendered (Runtime, "en", "unit_narrow_accounting", Args) =
             "($12.30)",
           "currency unit-width-narrow-accounting option composes");
   Assert (Rendered (Runtime, "en", "unit_narrow_accounting_slash",
             Args) =
             Rendered (Runtime, "en", "unit_narrow_accounting", Args),
           "currency unit-width/narrow/accounting option composes");
   Assert (Rendered (Runtime, "en", "unit_name_accounting", Args) =
             "(12.30 US dollars)",
           "currency unit-width-full-name-accounting option composes");
   Assert (Rendered (Runtime, "en", "unit_name_accounting_slash", Args) =
             Rendered (Runtime, "en", "unit_name_accounting", Args),
           "currency unit-width/full-name/accounting option composes");
   Assert (Rendered (Runtime, "en", "unit_iso_accounting", Args) =
             "(USD 12.30)",
           "currency unit-width-iso-code-accounting option composes");
   Assert (Rendered (Runtime, "en", "unit_iso_accounting_slash", Args) =
             Rendered (Runtime, "en", "unit_iso_accounting", Args),
           "currency unit-width/iso-code/accounting option composes");
   Assert (Rendered (Runtime, "en", "skeleton_accounting", Args) =
             "($12.30)",
           "number currency skeleton accepts accounting option");
   Assert (Rendered (Runtime, "en", "skeleton_narrow_accounting", Args) =
             "($12.30)",
           "number currency skeleton accepts separate accounting tokens");

   I18N.Arguments.Set (Args, "amount", "1.03");
   Assert (Rendered (Runtime, "en", "cash", Args) = "CHF 1.05",
           "currency cash option rounds to the cash increment");
   Assert (Rendered (Runtime, "en", "cash_slash", Args) =
             Rendered (Runtime, "en", "cash", Args),
           "currency precision-currency/cash option rounds to the cash increment");
   Assert (Rendered (Runtime, "en", "skeleton_precision_cash", Args) =
             "CHF 1.05",
           "number currency skeleton accepts precision-currency-cash");
   Assert (Rendered (Runtime, "en", "skeleton_precision_cash_slash",
             Args) =
             Rendered (Runtime, "en", "skeleton_precision_cash", Args),
           "number currency skeleton accepts precision/currency-cash");
   Assert (Rendered (Runtime, "en", "skeleton_precision_standard", Args) =
             "CHF 1.03",
           "precision-currency-standard resets cash rounding");
   Assert (Rendered (Runtime, "en", "skeleton_precision_standard_slash",
             Args) =
             Rendered (Runtime, "en", "skeleton_precision_standard", Args),
           "precision/currency-standard resets cash rounding");
   Assert (Rendered (Runtime, "en", "cad_cash", Args) = "CAD 1.05",
           "Canadian dollar cash option rounds to the cash increment");
   Assert (Rendered (Runtime, "en", "cad_cash_slash", Args) =
             Rendered (Runtime, "en", "cad_cash", Args),
           "currency cash/unit-width/iso-code option rounds to the cash increment");
   Assert (Rendered (Runtime, "en", "huf_cash", Args) = "HUF 1.03",
           "Hungarian forint cash option uses CLDR cash metadata");
   I18N.Arguments.Set (Args, "amount", "1.26");
   Assert (Rendered (Runtime, "en", "dkk_cash", Args) = "DKK 1.50",
           "Danish krone cash option rounds to the cash increment");
   I18N.Arguments.Set (Args, "amount", "1.51");
   Assert (Rendered (Runtime, "en", "sek_cash", Args) = "SEK 1.51",
           "Swedish krona cash option uses CLDR cash metadata");
   I18N.Arguments.Set (Args, "amount", "-1.03");
   Assert (Rendered (Runtime, "en", "skeleton_cash_accounting", Args) =
             "(1.05 Swiss francs)",
           "number currency skeleton accepts cash/sign-accounting tokens");
   Assert (Rendered (Runtime, "en", "skeleton_cash_accounting_slash",
             Args) =
             Rendered (Runtime, "en", "skeleton_cash_accounting", Args),
           "number currency skeleton accepts slash-style cash/accounting tokens");
   Assert (Rendered (Runtime, "en",
             "skeleton_cash_accounting_suffix_slash", Args) =
             Rendered (Runtime, "en", "skeleton_cash_accounting", Args),
           "number currency skeleton accepts slash-composed suffix aliases");
   Assert (Rendered (Runtime, "en", "cash_unit_name_accounting", Args) =
             "(1.05 Swiss francs)",
           "currency cash unit-width-full-name accounting option composes");
   Assert (Rendered (Runtime, "en", "cash_unit_name_accounting_slash",
             Args) =
             Rendered (Runtime, "en", "cash_unit_name_accounting", Args),
           "currency cash/unit-width/full-name/accounting option composes");
   I18N.Arguments.Set (Args, "amount", "-1.00");
   Assert (Rendered (Runtime, "en", "skeleton_cash_accounting", Args) =
             "(1.00 Swiss franc)",
           "number currency skeleton renders singular cash display names");
   Assert (Rendered (Runtime, "en",
             "skeleton_cash_accounting_suffix_slash", Args) =
             Rendered (Runtime, "en", "skeleton_cash_accounting", Args),
           "number currency skeleton suffix aliases singularize display names");
   Assert (Rendered (Runtime, "en", "cash_unit_name_accounting", Args) =
             "(1.00 Swiss franc)",
           "currency cash display names singularize after rounding");
   Assert (Rendered (Runtime, "en", "cash_unit_name_accounting_slash",
             Args) =
             Rendered (Runtime, "en", "cash_unit_name_accounting", Args),
           "currency slash-composed cash display names singularize after rounding");
end Test_Currency_Rendering;
