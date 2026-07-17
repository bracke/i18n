separate (I18N.Runtime.Tests.Features)
procedure Test_Locale_Canonicalization_And_Aliases
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
begin
   I18N.Runtime.Load_Text
     (Runtime, "base",
      "default_locale = EN_us" & ASCII.LF
      & "title = ""Default US""" & ASCII.LF
      & "EN-us.label = ""English US""" & ASCII.LF
      & "he.title = ""Hebrew""" & ASCII.LF
      & "id.title = ""Indonesian""" & ASCII.LF
      & "sr-Latn.title = ""Serbian Latin""" & ASCII.LF,
      Result);

   Assert (Result.Status = I18N.Runtime.Loaded,
           "canonicalized locale catalog should load");
   Assert (I18N.Locales.Canonicalize (" EN_us-u-NU-THAI ") =
             "en-US-u-nu-thai",
           "public locale canonicalization normalizes case and extensions");
   Assert (I18N.Locales.Base_Name (" EN_us-u-NU-THAI ") = "en-US",
           "public locale base-name helper strips extensions");
   Assert (I18N.Locales.Language ("iw_IL-u-nu-hebr") = "he",
           "public locale language helper returns canonical aliases");
   Assert (I18N.Locales.Script ("sr_Latn_RS") = "Latn",
           "public locale script helper returns canonical scripts");
   Assert (I18N.Locales.Region ("sr_Latn_RS-u-ca-gregory") = "RS",
           "public locale region helper ignores extensions");
   Assert (I18N.Locales.Region ("es-419") = "419",
           "public locale region helper returns numeric regions");
   Assert (I18N.Locales.Script ("en-US") = "",
           "public locale script helper returns empty text when absent");
   Assert (I18N.Locales.Language_Display_Name ("iw") = "Hebrew",
           "public locale language display names honor aliases");
   Assert (I18N.Locales.Script_Display_Name ("Latn") = "Latin",
           "public locale script display names resolve script codes");
   Assert (I18N.Locales.Region_Display_Name ("es-419") = "Latin America",
           "public locale region display names resolve numeric regions");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS") =
             "Serbian (Latin, Serbia)",
           "public locale display names compose language script and region");
   Assert (I18N.Locales.Display_Name ("en-XY") = "English (XY)",
           "public locale display names fall back to unknown region codes");
   Assert (I18N.Locales.Language_Display_Name ("sr", "de") = "Serbisch",
           "public locale language display names localize to German");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "de") = "Lateinisch",
           "public locale script display names localize to German");
   Assert (I18N.Locales.Region_Display_Name ("RS", "de") = "Serbien",
           "public locale region display names localize to German");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "de") =
             "Serbisch (Lateinisch, Serbien)",
           "public locale display names compose localized German names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "fr") = "serbe",
           "public locale language display names localize to French");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "fr") = "latin",
           "public locale script display names localize to French");
   Assert (I18N.Locales.Region_Display_Name ("RS", "fr") = "Serbie",
           "public locale region display names localize to French");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "fr") =
             "serbe (latin, Serbie)",
           "public locale display names compose localized French names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "es") = "serbio",
           "public locale language display names localize to Spanish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "es") = "latin",
           "public locale script display names localize to Spanish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "es") = "Serbia",
           "public locale region display names localize to Spanish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "es") =
             "serbio (latin, Serbia)",
           "public locale display names compose localized Spanish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "it") = "serbo",
           "public locale language display names localize to Italian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "it") = "latino",
           "public locale script display names localize to Italian");
   Assert (I18N.Locales.Region_Display_Name ("RS", "it") = "Serbia",
           "public locale region display names localize to Italian");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "it") =
             "serbo (latino, Serbia)",
           "public locale display names compose localized Italian names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "pt") = "servio",
           "public locale language display names localize to Portuguese");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "pt") = "latino",
           "public locale script display names localize to Portuguese");
   Assert (I18N.Locales.Region_Display_Name ("RS", "pt") = "Servia",
           "public locale region display names localize to Portuguese");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "pt") =
             "servio (latino, Servia)",
           "public locale display names compose localized Portuguese names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "nl") = "Servisch",
           "public locale language display names localize to Dutch");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "nl") = "Latijn",
           "public locale script display names localize to Dutch");
   Assert (I18N.Locales.Region_Display_Name ("RS", "nl") = "Servie",
           "public locale region display names localize to Dutch");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "nl") =
             "Servisch (Latijn, Servie)",
           "public locale display names compose localized Dutch names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "pl") = "serbski",
           "public locale language display names localize to Polish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "pl") = "lacinski",
           "public locale script display names localize to Polish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "pl") = "Serbia",
           "public locale region display names localize to Polish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "pl") =
             "serbski (lacinski, Serbia)",
           "public locale display names compose localized Polish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "cs") = "srbstina",
           "public locale language display names localize to Czech");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "cs") = "latinka",
           "public locale script display names localize to Czech");
   Assert (I18N.Locales.Region_Display_Name ("RS", "cs") = "Srbsko",
           "public locale region display names localize to Czech");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "cs") =
             "srbstina (latinka, Srbsko)",
           "public locale display names compose localized Czech names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "ru") = "serbskiy",
           "public locale language display names localize to Russian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ru") = "latinitsa",
           "public locale script display names localize to Russian");
   Assert (I18N.Locales.Region_Display_Name ("RS", "ru") = "Serbiya",
           "public locale region display names localize to Russian");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "ru") =
             "serbskiy (latinitsa, Serbiya)",
           "public locale display names compose localized Russian names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "tr") = "Sirpca",
           "public locale language display names localize to Turkish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "tr") = "Latin",
           "public locale script display names localize to Turkish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "tr") = "Sirbistan",
           "public locale region display names localize to Turkish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "tr") =
             "Sirpca (Latin, Sirbistan)",
           "public locale display names compose localized Turkish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "sv") = "serbiska",
           "public locale language display names localize to Swedish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "sv") = "latinska",
           "public locale script display names localize to Swedish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "sv") = "Serbien",
           "public locale region display names localize to Swedish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "sv") =
             "serbiska (latinska, Serbien)",
           "public locale display names compose localized Swedish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "da") = "serbisk",
           "public locale language display names localize to Danish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "da") = "latinsk",
           "public locale script display names localize to Danish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "da") = "Serbien",
           "public locale region display names localize to Danish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "da") =
             "serbisk (latinsk, Serbien)",
           "public locale display names compose localized Danish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "fi") = "serbia",
           "public locale language display names localize to Finnish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "fi") =
             "latinalainen",
           "public locale script display names localize to Finnish");
   Assert (I18N.Locales.Region_Display_Name ("RS", "fi") = "Serbia",
           "public locale region display names localize to Finnish");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "fi") =
             "serbia (latinalainen, Serbia)",
           "public locale display names compose localized Finnish names");
   Assert (I18N.Locales.Language_Display_Name ("sr", "no") = "serbisk",
           "public locale language display names localize to Norwegian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "no") = "latinsk",
           "public locale script display names localize to Norwegian");
   Assert (I18N.Locales.Region_Display_Name ("RS", "no") = "Serbia",
           "public locale region display names localize to Norwegian");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "no") =
             "serbisk (latinsk, Serbia)",
           "public locale display names compose localized Norwegian names");
   Assert (I18N.Locales.Language_Display_Name ("de", "id") = "Jerman",
           "public locale language display names localize to Indonesian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "id") = "Latin",
           "public locale script display names localize to Indonesian");
   Assert (I18N.Locales.Region_Display_Name ("DE", "id") = "Jerman",
           "public locale region display names localize to Indonesian");
   Assert (I18N.Locales.Display_Name ("de-Latn-DE", "id") =
             "Jerman (Latin, Jerman)",
           "public locale display names compose localized Indonesian names");
   Assert (I18N.Locales.Language_Display_Name ("fr", "ms") = "Perancis",
           "public locale language display names localize to Malay");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ms") = "Latin",
           "public locale script display names localize to Malay");
   Assert (I18N.Locales.Region_Display_Name ("FR", "ms") = "Perancis",
           "public locale region display names localize to Malay");
   Assert (I18N.Locales.Display_Name ("fr-Latn-FR", "ms") =
             "Perancis (Latin, Perancis)",
           "public locale display names compose localized Malay names");
   Assert (I18N.Locales.Language_Display_Name ("it", "eo") = "itala",
           "public locale language display names localize to Esperanto");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "eo") = "latina",
           "public locale script display names localize to Esperanto");
   Assert (I18N.Locales.Region_Display_Name ("IT", "eo") = "Italio",
           "public locale region display names localize to Esperanto");
   Assert (I18N.Locales.Display_Name ("it-Latn-IT", "eo") =
             "itala (latina, Italio)",
           "public locale display names compose localized Esperanto names");
   Assert (I18N.Locales.Language_Display_Name ("ja", "vi") = "Nhat",
           "public locale language display names localize to Vietnamese");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "vi") = "La-tinh",
           "public locale script display names localize to Vietnamese");
   Assert (I18N.Locales.Region_Display_Name ("JP", "vi") = "Nhat Ban",
           "public locale region display names localize to Vietnamese");
   Assert (I18N.Locales.Display_Name ("ja-Latn-JP", "vi") =
             "Nhat (La-tinh, Nhat Ban)",
           "public locale display names compose localized Vietnamese names");
   Assert (I18N.Locales.Language_Display_Name ("ru", "sw") = "Kirusi",
           "public locale language display names localize to Swahili");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "sw") = "Kilatini",
           "public locale script display names localize to Swahili");
   Assert (I18N.Locales.Region_Display_Name ("RU", "sw") = "Urusi",
           "public locale region display names localize to Swahili");
   Assert (I18N.Locales.Display_Name ("ru-Latn-RU", "sw") =
             "Kirusi (Kilatini, Urusi)",
           "public locale display names compose localized Swahili names");
   Assert (I18N.Locales.Language_Display_Name ("en", "af") = "Engels",
           "public locale language display names localize to Afrikaans");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "af") = "Latyn",
           "public locale script display names localize to Afrikaans");
   Assert (I18N.Locales.Region_Display_Name ("US", "af") =
             "Verenigde State",
           "public locale region display names localize to Afrikaans");
   Assert (I18N.Locales.Display_Name ("en-Latn-US", "af") =
             "Engels (Latyn, Verenigde State)",
           "public locale display names compose localized Afrikaans names");
   Assert (I18N.Locales.Language_Display_Name ("es", "eu") = "gaztelania",
           "public locale language display names localize to Basque");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "eu") = "latina",
           "public locale script display names localize to Basque");
   Assert (I18N.Locales.Region_Display_Name ("ES", "eu") = "Espainia",
           "public locale region display names localize to Basque");
   Assert (I18N.Locales.Display_Name ("es-Latn-ES", "eu") =
             "gaztelania (latina, Espainia)",
           "public locale display names compose localized Basque names");
   Assert (I18N.Locales.Language_Display_Name ("pt", "ro") = "portugheza",
           "public locale language display names localize to Romanian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ro") = "latina",
           "public locale script display names localize to Romanian");
   Assert (I18N.Locales.Region_Display_Name ("PT", "ro") = "Portugalia",
           "public locale region display names localize to Romanian");
   Assert (I18N.Locales.Display_Name ("pt-Latn-PT", "ro") =
             "portugheza (latina, Portugalia)",
           "public locale display names compose localized Romanian names");
   Assert (I18N.Locales.Language_Display_Name ("fr", "lt") = "prancuzu",
           "public locale language display names localize to Lithuanian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "lt") = "lotynu",
           "public locale script display names localize to Lithuanian");
   Assert (I18N.Locales.Region_Display_Name ("FR", "lt") = "Prancuzija",
           "public locale region display names localize to Lithuanian");
   Assert (I18N.Locales.Display_Name ("fr-Latn-FR", "lt") =
             "prancuzu (lotynu, Prancuzija)",
           "public locale display names compose localized Lithuanian names");
   Assert (I18N.Locales.Language_Display_Name ("de", "sl") = "nemscina",
           "public locale language display names localize to Slovenian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "sl") = "latinica",
           "public locale script display names localize to Slovenian");
   Assert (I18N.Locales.Region_Display_Name ("DE", "sl") = "Nemcija",
           "public locale region display names localize to Slovenian");
   Assert (I18N.Locales.Display_Name ("de-Latn-DE", "sl") =
             "nemscina (latinica, Nemcija)",
           "public locale display names compose localized Slovenian names");
   Assert (I18N.Locales.Language_Display_Name ("it", "hu") = "olasz",
           "public locale language display names localize to Hungarian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "hu") = "latin",
           "public locale script display names localize to Hungarian");
   Assert (I18N.Locales.Region_Display_Name ("IT", "hu") =
             "Olaszorszag",
           "public locale region display names localize to Hungarian");
   Assert (I18N.Locales.Display_Name ("it-Latn-IT", "hu") =
             "olasz (latin, Olaszorszag)",
           "public locale display names compose localized Hungarian names");
   Assert (I18N.Locales.Language_Display_Name ("fr", "sk") =
             "francuzstina",
           "public locale language display names localize to Slovak");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "sk") = "latinka",
           "public locale script display names localize to Slovak");
   Assert (I18N.Locales.Region_Display_Name ("FR", "sk") = "Francuzsko",
           "public locale region display names localize to Slovak");
   Assert (I18N.Locales.Display_Name ("fr-Latn-FR", "sk") =
             "francuzstina (latinka, Francuzsko)",
           "public locale display names compose localized Slovak names");
   Assert (I18N.Locales.Language_Display_Name ("ru", "bg") = "ruski",
           "public locale language display names localize to Bulgarian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "bg") = "latinitsa",
           "public locale script display names localize to Bulgarian");
   Assert (I18N.Locales.Region_Display_Name ("RU", "bg") = "Rusiya",
           "public locale region display names localize to Bulgarian");
   Assert (I18N.Locales.Display_Name ("ru-Latn-RU", "bg") =
             "ruski (latinitsa, Rusiya)",
           "public locale display names compose localized Bulgarian names");
   Assert (I18N.Locales.Language_Display_Name ("tr", "uk") = "turetska",
           "public locale language display names localize to Ukrainian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "uk") =
             "latynytsia",
           "public locale script display names localize to Ukrainian");
   Assert (I18N.Locales.Region_Display_Name ("TR", "uk") = "Turechchyna",
           "public locale region display names localize to Ukrainian");
   Assert (I18N.Locales.Display_Name ("tr-Latn-TR", "uk") =
             "turetska (latynytsia, Turechchyna)",
           "public locale display names compose localized Ukrainian names");
   Assert (I18N.Locales.Language_Display_Name ("fa", "ar") =
             "al-farisiya",
           "public locale language display names localize to Arabic");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ar") =
             "al-latiniya",
           "public locale script display names localize to Arabic");
   Assert (I18N.Locales.Region_Display_Name ("IR", "ar") = "Iran",
           "public locale region display names localize to Arabic");
   Assert (I18N.Locales.Display_Name ("fa-Latn-IR", "ar") =
             "al-farisiya (al-latiniya, Iran)",
           "public locale display names compose localized Arabic names");
   Assert (I18N.Locales.Language_Display_Name ("ar", "fa") = "arabi",
           "public locale language display names localize to Persian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "fa") = "latin",
           "public locale script display names localize to Persian");
   Assert (I18N.Locales.Region_Display_Name ("US", "fa") =
             "Eyatat-e Mottahed",
           "public locale region display names localize to Persian");
   Assert (I18N.Locales.Display_Name ("ar-Latn-US", "fa") =
             "arabi (latin, Eyatat-e Mottahed)",
           "public locale display names compose localized Persian names");
   Assert (I18N.Locales.Language_Display_Name ("zh", "th") = "chin",
           "public locale language display names localize to Thai");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "th") = "latin",
           "public locale script display names localize to Thai");
   Assert (I18N.Locales.Region_Display_Name ("CN", "th") = "Chin",
           "public locale region display names localize to Thai");
   Assert (I18N.Locales.Display_Name ("zh-Latn-CN", "th") =
             "chin (latin, Chin)",
           "public locale display names compose localized Thai names");
   Assert (I18N.Locales.Language_Display_Name ("en", "hi") = "angrezi",
           "public locale language display names localize to Hindi");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "hi") = "latin",
           "public locale script display names localize to Hindi");
   Assert (I18N.Locales.Region_Display_Name ("US", "hi") =
             "Sanyukt Rajya",
           "public locale region display names localize to Hindi");
   Assert (I18N.Locales.Display_Name ("en-Latn-US", "hi") =
             "angrezi (latin, Sanyukt Rajya)",
           "public locale display names compose localized Hindi names");
   Assert (I18N.Locales.Language_Display_Name ("de", "el") = "germanika",
           "public locale language display names localize to Greek");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "el") = "latiniko",
           "public locale script display names localize to Greek");
   Assert (I18N.Locales.Region_Display_Name ("DE", "el") = "Germania",
           "public locale region display names localize to Greek");
   Assert (I18N.Locales.Display_Name ("de-Latn-DE", "el") =
             "germanika (latiniko, Germania)",
           "public locale display names compose localized Greek names");
   Assert (I18N.Locales.Language_Display_Name ("fr", "he") = "tsarfatit",
           "public locale language display names localize to Hebrew");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "he") = "latini",
           "public locale script display names localize to Hebrew");
   Assert (I18N.Locales.Region_Display_Name ("FR", "he") = "Tsarfat",
           "public locale region display names localize to Hebrew");
   Assert (I18N.Locales.Display_Name ("fr-Latn-FR", "he") =
             "tsarfatit (latini, Tsarfat)",
           "public locale display names compose localized Hebrew names");
   Assert (I18N.Locales.Language_Display_Name ("ja", "ca") = "japones",
           "public locale language display names localize to Catalan");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ca") = "llati",
           "public locale script display names localize to Catalan");
   Assert (I18N.Locales.Region_Display_Name ("JP", "ca") = "Japo",
           "public locale region display names localize to Catalan");
   Assert (I18N.Locales.Display_Name ("ja-Latn-JP", "ca") =
             "japones (llati, Japo)",
           "public locale display names compose localized Catalan names");
   Assert (I18N.Locales.Language_Display_Name ("ko", "ja") =
             "kankokugo",
           "public locale language display names localize to Japanese");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ja") =
             "raten moji",
           "public locale script display names localize to Japanese");
   Assert (I18N.Locales.Region_Display_Name ("KR", "ja") = "Kankoku",
           "public locale region display names localize to Japanese");
   Assert (I18N.Locales.Display_Name ("ko-Latn-KR", "ja") =
             "kankokugo (raten moji, Kankoku)",
           "public locale display names compose localized Japanese names");
   Assert (I18N.Locales.Language_Display_Name ("ja", "zh") = "riyu",
           "public locale language display names localize to Chinese");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "zh") =
             "lading zi",
           "public locale script display names localize to Chinese");
   Assert (I18N.Locales.Region_Display_Name ("JP", "zh") = "Riben",
           "public locale region display names localize to Chinese");
   Assert (I18N.Locales.Display_Name ("ja-Latn-JP", "zh") =
             "riyu (lading zi, Riben)",
           "public locale display names compose localized Chinese names");
   Assert (I18N.Locales.Language_Display_Name ("zh", "ko") = "junggugeo",
           "public locale language display names localize to Korean");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ko") =
             "latin munja",
           "public locale script display names localize to Korean");
   Assert (I18N.Locales.Region_Display_Name ("CN", "ko") = "Jungguk",
           "public locale region display names localize to Korean");
   Assert (I18N.Locales.Display_Name ("zh-Latn-CN", "ko") =
             "junggugeo (latin munja, Jungguk)",
           "public locale display names compose localized Korean names");
   Assert (I18N.Locales.Language_Display_Name ("az", "bn") =
             "azarbaijani",
           "public locale language display names localize to Bengali");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "bn") = "latin",
           "public locale script display names localize to Bengali");
   Assert (I18N.Locales.Region_Display_Name ("AZ", "bn") = "Azarbaijan",
           "public locale region display names localize to Bengali");
   Assert (I18N.Locales.Display_Name ("az-Latn-AZ", "bn") =
             "azarbaijani (latin, Azarbaijan)",
           "public locale display names compose localized Bengali names");
   Assert (I18N.Locales.Language_Display_Name ("bn", "az") = "benqal",
           "public locale language display names localize to Azerbaijani");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "az") = "latin",
           "public locale script display names localize to Azerbaijani");
   Assert (I18N.Locales.Region_Display_Name ("BD", "az") = "Banqlades",
           "public locale region display names localize to Azerbaijani");
   Assert (I18N.Locales.Display_Name ("bn-Latn-BD", "az") =
             "benqal (latin, Banqlades)",
           "public locale display names compose localized Azerbaijani names");
   Assert (I18N.Locales.Language_Display_Name ("yi", "ur") = "yiddish",
           "public locale language display names localize to Urdu");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "ur") = "latini",
           "public locale script display names localize to Urdu");
   Assert (I18N.Locales.Region_Display_Name ("IL", "ur") = "Israel",
           "public locale region display names localize to Urdu");
   Assert (I18N.Locales.Display_Name ("yi-Latn-IL", "ur") =
             "yiddish (latini, Israel)",
           "public locale display names compose localized Urdu names");
   Assert (I18N.Locales.Language_Display_Name ("ur", "yi") = "urdu",
           "public locale language display names localize to Yiddish");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "yi") = "lataynish",
           "public locale script display names localize to Yiddish");
   Assert (I18N.Locales.Region_Display_Name ("IL", "yi") = "Yisroel",
           "public locale region display names localize to Yiddish");
   Assert (I18N.Locales.Display_Name ("ur-Latn-IL", "yi") =
             "urdu (lataynish, Yisroel)",
           "public locale display names compose localized Yiddish names");
   Assert (I18N.Locales.Language_Display_Name ("en", "sr") = "engleski",
           "public locale language display names localize to Serbian");
   Assert (I18N.Locales.Script_Display_Name ("Latn", "sr") = "latinica",
           "public locale script display names localize to Serbian");
   Assert (I18N.Locales.Region_Display_Name ("US", "sr") =
             "Sjedinjene Drzave",
           "public locale region display names localize to Serbian");
   Assert (I18N.Locales.Display_Name ("en-Latn-US", "sr") =
             "engleski (latinica, Sjedinjene Drzave)",
           "public locale display names compose localized Serbian names");
   Assert (I18N.Locales.Language_Display_Name ("ps") = "Pashto",
           "public locale language display names include Pashto");
   Assert (I18N.Locales.Language_Display_Name ("sd") = "Sindhi",
           "public locale language display names include Sindhi");
   Assert (I18N.Locales.Language_Display_Name ("ug") = "Uyghur",
           "public locale language display names include Uyghur");
   Assert (I18N.Locales.Region_Display_Name ("AF") = "Afghanistan",
           "public locale region display names include Afghanistan");
   Assert (I18N.Locales.Region_Display_Name ("PK") = "Pakistan",
           "public locale region display names include Pakistan");
   Assert (I18N.Locales.Language_Display_Name ("ur", "ps") = "urdu",
           "public locale language display names localize to Pashto");
   Assert (I18N.Locales.Script_Display_Name ("Arab", "ps") = "arabi",
           "public locale script display names localize to Pashto");
   Assert (I18N.Locales.Region_Display_Name ("PK", "ps") = "Pakistan",
           "public locale region display names localize to Pashto");
   Assert (I18N.Locales.Display_Name ("ur-Arab-PK", "ps") =
             "urdu (arabi, Pakistan)",
           "public locale display names compose localized Pashto names");
   Assert (I18N.Locales.Language_Display_Name ("ps", "sd") = "pashto",
           "public locale language display names localize to Sindhi");
   Assert (I18N.Locales.Script_Display_Name ("Arab", "sd") = "arabi",
           "public locale script display names localize to Sindhi");
   Assert (I18N.Locales.Region_Display_Name ("AF", "sd") =
             "Afghanistan",
           "public locale region display names localize to Sindhi");
   Assert (I18N.Locales.Display_Name ("ps-Arab-AF", "sd") =
             "pashto (arabi, Afghanistan)",
           "public locale display names compose localized Sindhi names");
   Assert (I18N.Locales.Language_Display_Name ("zh", "ug") = "xitay",
           "public locale language display names localize to Uyghur");
   Assert (I18N.Locales.Script_Display_Name ("Arab", "ug") = "ereb",
           "public locale script display names localize to Uyghur");
   Assert (I18N.Locales.Region_Display_Name ("CN", "ug") = "Xitay",
           "public locale region display names localize to Uyghur");
   Assert (I18N.Locales.Display_Name ("zh-Arab-CN", "ug") =
             "xitay (ereb, Xitay)",
           "public locale display names compose localized Uyghur names");
   Assert (I18N.Locales.Display_Name ("sr-Latn-RS", "zz") =
             "Serbian (Latin, Serbia)",
           "public locale display names fall back for unsupported display locales");
   Assert (I18N.Locales.Unicode_Extension
             ("EN_us-u-NU-THAI-ca-GREGORY", "NU") = "thai",
           "public locale Unicode-extension helper reads canonical values");
   Assert (I18N.Locales.Unicode_Extension
             ("en-u-foo-ca-islamic-tbla-x-private", "ca") =
               "islamic-tbla",
           "public locale Unicode-extension helper reads multi-subtag values");
   Assert (I18N.Locales.Unicode_Extension ("en-u-kf", "kf") = "true",
           "public locale Unicode-extension helper exposes boolean keys");
   Assert (I18N.Locales.Unicode_Extension ("en-u-ca-gregory", "calendar") =
             "",
           "public locale Unicode-extension helper rejects malformed keys");
   Assert (I18N.Locales.To_Lower ("MIXED Case", "en") = "mixed case",
           "public locale lowercase transforms ASCII text");
   Assert (I18N.Locales.To_Upper ("mixed Case", "en") = "MIXED CASE",
           "public locale uppercase transforms ASCII text");
   Assert (I18N.Locales.To_Lower ("I", "tr") = U (16#131#),
           "public locale lowercase applies Turkish dotless-i tailoring");
   Assert (I18N.Locales.To_Upper ("i", "tr") = U (16#130#),
           "public locale uppercase applies Turkish dotted-I tailoring");
   Assert (I18N.Locales.To_Lower ("I", "az") = U (16#131#),
           "public locale lowercase applies Azerbaijani dotless-i tailoring");
   Assert (I18N.Locales.To_Upper ("i", "az") = U (16#130#),
           "public locale uppercase applies Azerbaijani dotted-I tailoring");
   Assert (I18N.Locales.To_Lower
             (U (16#C4#) & U (16#D6#) & U (16#DC#), "de") =
             U (16#E4#) & U (16#F6#) & U (16#FC#),
           "public locale lowercase maps common Latin accents");
   Assert (I18N.Locales.To_Upper
             (U (16#E4#) & U (16#F6#) & U (16#FC#) & U (16#DF#), "de") =
             U (16#C4#) & U (16#D6#) & U (16#DC#) & "SS",
           "public locale uppercase maps accents and German sharp-s");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#391#, 16#392#, 16#393#]), "el") =
             UTF8 ([16#3B1#, 16#3B2#, 16#3B3#]),
           "public locale lowercase maps bounded Greek");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#386#, 16#388#, 16#389#, 16#38A#, 16#38C#,
                     16#38E#, 16#38F#, 16#3AA#, 16#3AB#]), "el") =
             UTF8 ([16#3AC#, 16#3AD#, 16#3AE#, 16#3AF#, 16#3CC#,
                    16#3CD#, 16#3CE#, 16#3CA#, 16#3CB#]),
           "public locale lowercase maps Greek tonos vowels");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#39F#, 16#3A3#]) & " "
              & UTF8 ([16#3A3#, 16#39F#]) & " "
              & UTF8 ([16#3A3#]), "el") =
             UTF8 ([16#3BF#, 16#3C2#]) & " "
             & UTF8 ([16#3C3#, 16#3BF#]) & " "
             & UTF8 ([16#3C3#]),
           "public locale lowercase maps bounded Greek final sigma by word context");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#3B1#, 16#3C2#, 16#3C3#]), "el") =
             UTF8 ([16#391#, 16#3A3#, 16#3A3#]),
           "public locale uppercase maps bounded Greek sigma forms");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#3AC#, 16#3AD#, 16#3AE#, 16#3AF#, 16#3CC#,
                     16#3CD#, 16#3CE#, 16#3CA#, 16#3CB#]), "el") =
             UTF8 ([16#386#, 16#388#, 16#389#, 16#38A#, 16#38C#,
                    16#38E#, 16#38F#, 16#3AA#, 16#3AB#]),
           "public locale uppercase maps Greek tonos vowels");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#390#, 16#3B0#]), "el") =
             UTF8 ([16#399#, 16#308#, 16#301#,
                    16#3A5#, 16#308#, 16#301#]),
           "public locale uppercase expands Greek dialytika-tonos vowels");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#41F#, 16#420#, 16#418#, 16#412#, 16#415#, 16#422#]),
              "ru") =
             UTF8 ([16#43F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
           "public locale lowercase maps bounded Cyrillic");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#43F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
              "ru") =
             UTF8 ([16#41F#, 16#420#, 16#418#, 16#412#, 16#415#, 16#422#]),
           "public locale uppercase maps bounded Cyrillic");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#531#, 16#540#, 16#556#]), "hy") =
             UTF8 ([16#561#, 16#570#, 16#586#]),
           "public locale lowercase maps bounded Armenian");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#561#, 16#570#, 16#586#]), "hy") =
             UTF8 ([16#531#, 16#540#, 16#556#]),
           "public locale uppercase maps bounded Armenian");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#1C90#, 16#1CA0#, 16#1CBF#]), "ka") =
             UTF8 ([16#10D0#, 16#10E0#, 16#10FF#]),
           "public locale lowercase maps bounded Georgian Mtavruli");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#10D0#, 16#10E0#, 16#10FF#]), "ka") =
             UTF8 ([16#1C90#, 16#1CA0#, 16#1CBF#]),
           "public locale uppercase maps bounded Georgian Mkhedruli");
   Assert (I18N.Locales.To_Lower
             (UTF8 ([16#10A0#, 16#10B0#, 16#10C5#,
                     16#10C7#, 16#10CD#]), "ka") =
             UTF8 ([16#2D00#, 16#2D10#, 16#2D25#,
                    16#2D27#, 16#2D2D#]),
           "public locale lowercase maps bounded Georgian Asomtavruli");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#2D00#, 16#2D10#, 16#2D25#,
                     16#2D27#, 16#2D2D#]), "ka") =
             UTF8 ([16#10A0#, 16#10B0#, 16#10C5#,
                    16#10C7#, 16#10CD#]),
           "public locale uppercase maps bounded Georgian Nuskhuri");
   Assert (I18N.Locales.To_Upper
             (UTF8 ([16#65E5#, 16#672C#]), "ja") =
             UTF8 ([16#65E5#, 16#672C#]),
           "public locale case transforms preserve unsupported scripts");
   Assert (I18N.Locales.Normalize_NFC
             ("Cafe" & U (16#301#), "en") =
             "Caf" & U (16#E9#),
           "public locale NFC normalization composes acute accents");
   Assert (I18N.Locales.Normalize_NFC
             ("A" & U (16#30A#) & "ngstrom", "en") =
             U (16#C5#) & "ngstrom",
           "public locale NFC normalization composes ring accents");
   Assert (I18N.Locales.Normalize_NFC
             ("fac" & U (16#327#) & "ade", "fr") =
             "fa" & U (16#E7#) & "ade",
           "public locale NFC normalization composes cedilla accents");
   Assert (I18N.Locales.Normalize_NFC
             ("A" & U (16#304#) & " a" & U (16#328#)
              & " C" & U (16#30C#) & " z" & U (16#307#), "en") =
             U (16#100#) & " " & U (16#105#)
             & " " & U (16#10C#) & " " & U (16#17C#),
           "public locale NFC normalization composes Latin Extended marks");
   Assert (I18N.Locales.Normalize_NFC
             ("C" & U (16#301#) & " l" & U (16#301#)
              & " G" & U (16#327#) & " t" & U (16#327#)
              & " R" & U (16#301#) & " z" & U (16#301#), "en") =
             U (16#106#) & " " & U (16#13A#)
             & " " & U (16#122#) & " " & U (16#163#)
             & " " & U (16#154#) & " " & U (16#17A#),
           "public locale NFC normalization composes Latin acute and cedilla marks");
   Assert (I18N.Locales.Normalize_NFC
             ("A" & U (16#323#) & " e" & U (16#323#)
              & " I" & U (16#323#) & " o" & U (16#323#)
              & " U" & U (16#323#) & " y" & U (16#323#), "vi") =
             U (16#1EA0#) & " " & U (16#1EB9#)
             & " " & U (16#1ECA#) & " " & U (16#1ECD#)
             & " " & U (16#1EE4#) & " " & U (16#1EF5#),
           "public locale NFC normalization composes Latin dot-below vowels");
   Assert (I18N.Locales.Normalize_NFC
             ("O" & U (16#31B#) & " o" & U (16#31B#)
              & " U" & U (16#31B#) & " u" & U (16#31B#), "vi") =
             U (16#1A0#) & " " & U (16#1A1#)
             & " " & U (16#1AF#) & " " & U (16#1B0#),
           "public locale NFC normalization composes Latin horn vowels");
   Assert (I18N.Locales.Normalize_NFC
             ("O" & U (16#31B#) & U (16#301#)
              & " o" & U (16#31B#) & U (16#300#)
              & " U" & U (16#31B#) & U (16#309#)
              & " u" & U (16#31B#) & U (16#303#)
              & " u" & U (16#31B#) & U (16#323#), "vi") =
             U (16#1EDA#) & " " & U (16#1EDD#)
             & " " & U (16#1EEC#) & " " & U (16#1EEF#)
             & " " & U (16#1EF1#),
           "public locale NFC normalization composes tone-marked horn vowels");
   Assert (I18N.Locales.Normalize_NFC
             ("A" & U (16#302#) & U (16#301#)
              & " a" & U (16#302#) & U (16#323#)
              & " A" & U (16#306#) & U (16#300#)
              & " a" & U (16#306#) & U (16#303#)
              & " E" & U (16#302#) & U (16#309#)
              & " e" & U (16#302#) & U (16#303#)
              & " O" & U (16#302#) & U (16#301#)
              & " o" & U (16#302#) & U (16#323#), "vi") =
             U (16#1EA4#) & " " & U (16#1EAD#)
             & " " & U (16#1EB0#) & " " & U (16#1EB5#)
             & " " & U (16#1EC2#) & " " & U (16#1EC5#)
             & " " & U (16#1ED0#) & " " & U (16#1ED9#),
           "public locale NFC normalization composes Vietnamese circumflex and breve tone vowels");
   Assert (I18N.Locales.Normalize_NFC
             (U (16#391#) & U (16#301#) & " "
              & U (16#3B5#) & U (16#301#) & " "
              & U (16#399#) & U (16#308#) & " "
              & U (16#3B9#) & U (16#308#) & " "
              & U (16#3C5#) & U (16#308#) & U (16#301#), "el") =
             U (16#386#) & " " & U (16#3AD#) & " "
             & U (16#3AA#) & " " & U (16#3CA#) & " "
             & U (16#3B0#),
           "public locale NFC normalization composes Greek tonos and dialytika vowels");
   Assert (I18N.Locales.Normalize_NFD
             ("Caf" & U (16#E9#), "en") =
             "Cafe" & U (16#301#),
           "public locale NFD normalization decomposes acute accents");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#C5#) & "ngstrom", "en") =
             "A" & U (16#30A#) & "ngstrom",
           "public locale NFD normalization decomposes ring accents");
   Assert (I18N.Locales.Normalize_NFD
             ("fa" & U (16#E7#) & "ade", "fr") =
             "fac" & U (16#327#) & "ade",
           "public locale NFD normalization decomposes cedilla accents");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#112#) & " " & U (16#11F#)
              & " " & U (16#158#) & " " & U (16#172#), "en") =
             "E" & U (16#304#) & " g" & U (16#306#)
             & " R" & U (16#30C#) & " U" & U (16#328#),
           "public locale NFD normalization decomposes Latin Extended marks");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#106#) & " " & U (16#13A#)
              & " " & U (16#122#) & " " & U (16#163#)
              & " " & U (16#154#) & " " & U (16#17A#), "en") =
             "C" & U (16#301#) & " l" & U (16#301#)
             & " G" & U (16#327#) & " t" & U (16#327#)
             & " R" & U (16#301#) & " z" & U (16#301#),
           "public locale NFD normalization decomposes Latin acute and cedilla marks");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#1EA0#) & " " & U (16#1EB9#)
              & " " & U (16#1ECA#) & " " & U (16#1ECD#)
              & " " & U (16#1EE4#) & " " & U (16#1EF5#), "vi") =
             "A" & U (16#323#) & " e" & U (16#323#)
             & " I" & U (16#323#) & " o" & U (16#323#)
             & " U" & U (16#323#) & " y" & U (16#323#),
           "public locale NFD normalization decomposes Latin dot-below vowels");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#1A0#) & " " & U (16#1A1#)
              & " " & U (16#1AF#) & " " & U (16#1B0#), "vi") =
             "O" & U (16#31B#) & " o" & U (16#31B#)
             & " U" & U (16#31B#) & " u" & U (16#31B#),
           "public locale NFD normalization decomposes Latin horn vowels");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#1EDA#) & " " & U (16#1EDD#)
              & " " & U (16#1EEC#) & " " & U (16#1EEF#)
              & " " & U (16#1EF1#), "vi") =
             "O" & U (16#31B#) & U (16#301#)
             & " o" & U (16#31B#) & U (16#300#)
             & " U" & U (16#31B#) & U (16#309#)
             & " u" & U (16#31B#) & U (16#303#)
             & " u" & U (16#31B#) & U (16#323#),
           "public locale NFD normalization decomposes tone-marked horn vowels");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#1EA4#) & " " & U (16#1EAD#)
              & " " & U (16#1EB0#) & " " & U (16#1EB5#)
              & " " & U (16#1EC2#) & " " & U (16#1EC5#)
              & " " & U (16#1ED0#) & " " & U (16#1ED9#), "vi") =
             "A" & U (16#302#) & U (16#301#)
             & " a" & U (16#302#) & U (16#323#)
             & " A" & U (16#306#) & U (16#300#)
             & " a" & U (16#306#) & U (16#303#)
             & " E" & U (16#302#) & U (16#309#)
             & " e" & U (16#302#) & U (16#303#)
             & " O" & U (16#302#) & U (16#301#)
             & " o" & U (16#302#) & U (16#323#),
           "public locale NFD normalization decomposes Vietnamese circumflex and breve tone vowels");
   Assert (I18N.Locales.Normalize_NFD
             (U (16#386#) & " " & U (16#3AD#) & " "
              & U (16#3AA#) & " " & U (16#3CA#) & " "
              & U (16#390#) & " " & U (16#3B0#), "el") =
             U (16#391#) & U (16#301#) & " "
             & U (16#3B5#) & U (16#301#) & " "
             & U (16#399#) & U (16#308#) & " "
             & U (16#3B9#) & U (16#308#) & " "
             & U (16#3B9#) & U (16#308#) & U (16#301#)
             & " " & U (16#3C5#) & U (16#308#) & U (16#301#),
           "public locale NFD normalization decomposes Greek tonos and dialytika vowels");
   Assert (I18N.Locales.Normalize_NFC
             (UTF8 ([16#65E5#, 16#672C#]), "ja") =
             UTF8 ([16#65E5#, 16#672C#]),
           "public locale normalization preserves unsupported scripts");
   Assert (I18N.Locales.Transliterate_ASCII
             ("Stra" & U (16#DF#) & "e "
              & U (16#C5#) & "ngstr" & U (16#F6#) & "m", "de") =
             "Strasse Angstrom",
           "public locale transliteration folds common Latin accents");
   Assert (I18N.Locales.Transliterate_ASCII
             (U (16#10C#) & "esk" & U (16#FD#) & " "
              & U (16#110#) & "uro "
              & U (16#152#) & "uvre", "en") =
             "Cesky Duro OEuvre",
           "public locale transliteration folds Latin Extended letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (U (16#1EA0#) & U (16#1EB8#) & U (16#1ECA#)
              & U (16#1ECC#) & U (16#1EE4#) & U (16#1EF4#)
              & " " & U (16#1EA1#) & U (16#1EB9#)
              & U (16#1ECB#) & U (16#1ECD#)
              & U (16#1EE5#) & U (16#1EF5#), "vi") =
             "AEIOUY aeiouy",
           "public locale transliteration folds Latin dot-below vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (U (16#1A0#) & U (16#1AF#)
              & " " & U (16#1A1#) & U (16#1B0#), "vi") =
             "OU ou",
           "public locale transliteration folds Latin horn vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (U (16#1EDA#) & U (16#1EDD#) & U (16#1EEC#)
              & U (16#1EEF#) & U (16#1EF1#), "vi") =
             "OoUuu",
           "public locale transliteration folds tone-marked horn vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (U (16#1EA4#) & U (16#1EAD#)
              & U (16#1EB0#) & U (16#1EB5#)
              & U (16#1EC2#) & U (16#1EC5#)
              & U (16#1ED0#) & U (16#1ED9#), "vi") =
             "AaAaEeOo",
           "public locale transliteration folds Vietnamese circumflex and breve tone vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB00#, 16#FB01#, 16#FB02#, 16#FB03#,
                     16#FB04#, 16#FB05#, 16#FB06#]), "en") =
             "fffiflffifflstst",
           "public locale transliteration expands Latin alphabetic ligatures");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FF21#, 16#FF22#, 16#FF43#, 16#FF58#,
                     16#FF59#, 16#FF5A#, 16#FF11#, 16#FF12#]), "en") =
             "ABcxyz12",
           "public locale transliteration folds fullwidth Latin letters and digits");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#391#, 16#3B8#, 16#3B7#, 16#3BD#, 16#3B1#]),
              "el") =
             "Athina",
           "public locale transliteration maps bounded Greek letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#386#, 16#388#, 16#389#, 16#38A#, 16#38C#,
                     16#38E#, 16#38F#, 16#3AA#, 16#3AB#, 16#20#,
                     16#3AC#, 16#3AD#, 16#3AE#, 16#3AF#, 16#3CC#,
                     16#3CD#, 16#3CE#, 16#3CA#, 16#3CB#]), "el") =
             "AEIIOYOIY aeiioyoiy",
           "public locale transliteration folds Greek tonos vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#390#, 16#3B0#]), "el") = "iy",
           "public locale transliteration folds Greek dialytika-tonos vowels");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#41F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
              "ru") =
             "Privet",
           "public locale transliteration maps bounded Cyrillic letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#531#, 16#580#, 16#574#, 16#565#, 16#576#,
                     16#56B#, 16#561#, 16#20#, 16#570#, 16#561#,
                     16#575#]), "hy") =
             "Armenia hay",
           "public locale transliteration maps bounded Armenian letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#531#, 16#540#, 16#556#, 16#20#,
                     16#561#, 16#570#, 16#586#]), "hy") =
             "AHF ahf",
           "public locale transliteration preserves bounded Armenian case");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5DD#]), "he") =
             "shlvm",
           "public locale transliteration maps bounded Hebrew letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#5DA#, 16#5DD#, 16#5DF#, 16#5E3#, 16#5E5#]),
              "he") =
             "kmnpts",
           "public locale transliteration maps Hebrew final letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB2A#, 16#FB2B#, 16#FB2C#, 16#FB2D#,
                     16#FB49#]), "he") =
             "shshshshsh",
           "public locale transliteration maps Hebrew shin presentation forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB2E#, 16#FB2F#, 16#FB30#, 16#FB4F#]),
              "he") =
             "aaaal",
           "public locale transliteration maps Hebrew alef presentation forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB31#, 16#FB32#, 16#FB33#, 16#FB34#,
                     16#FB35#, 16#FB37#, 16#FB38#, 16#FB39#,
                     16#FB3A#, 16#FB3B#, 16#FB3C#, 16#FB3E#]),
              "he") =
             "bgdhvztykklm",
           "public locale transliteration maps Hebrew dagesh presentation forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB40#, 16#FB41#, 16#FB43#, 16#FB44#,
                     16#FB46#, 16#FB47#, 16#FB48#, 16#FB4A#,
                     16#FB4B#, 16#FB4C#, 16#FB4D#, 16#FB4E#]),
              "he") =
             "nspptsqrtvbkp",
           "public locale transliteration maps later Hebrew presentation forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB36#, 16#FB3D#, 16#FB3F#, 16#FB42#,
                     16#FB45#]), "he") =
             UTF8 ([16#FB36#, 16#FB3D#, 16#FB3F#, 16#FB42#,
                    16#FB45#]),
           "public locale transliteration preserves unassigned Hebrew presentation forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#633#, 16#644#, 16#627#, 16#645#]), "ar") =
             "slam",
           "public locale transliteration maps bounded Arabic letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#645#, 16#631#, 16#62D#, 16#628#, 16#627#]),
              "ar") =
             "mrhba",
           "public locale transliteration maps Arabic greeting letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FEF5#, 16#FEF6#, 16#FEF7#, 16#FEF8#,
                     16#FEF9#, 16#FEFA#, 16#FEFB#, 16#FEFC#]), "ar") =
             "lalalalalalalala",
           "public locale transliteration maps Arabic lam-alef presentation ligatures");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FE80#, 16#FE81#, 16#FE82#, 16#FE83#,
                     16#FE84#, 16#FE85#, 16#FE86#, 16#FE87#,
                     16#FE88#, 16#FE89#, 16#FE8A#, 16#FE8B#,
                     16#FE8C#, 16#FE8D#, 16#FE8E#]), "ar") =
             "'aaaawwaayyyyaa",
           "public locale transliteration maps Arabic presentation forms-B alef range");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FE8F#, 16#FE90#, 16#FE91#, 16#FE92#,
                     16#FE93#, 16#FE94#, 16#FE95#, 16#FE96#,
                     16#FE97#, 16#FE98#, 16#FE99#, 16#FE9A#,
                     16#FE9B#, 16#FE9C#, 16#FE9D#, 16#FE9E#,
                     16#FE9F#, 16#FEA0#, 16#FEA1#, 16#FEA2#,
                     16#FEA3#, 16#FEA4#, 16#FEA5#, 16#FEA6#,
                     16#FEA7#, 16#FEA8#, 16#FEA9#, 16#FEAA#,
                     16#FEAB#, 16#FEAC#, 16#FEAD#, 16#FEAE#,
                     16#FEAF#, 16#FEB0#, 16#FEB1#, 16#FEB2#,
                     16#FEB3#, 16#FEB4#, 16#FEB5#, 16#FEB6#,
                     16#FEB7#, 16#FEB8#, 16#FEB9#, 16#FEBA#,
                     16#FEBB#, 16#FEBC#]), "ar") =
             "bbbbhhttttththththjjjjhhhhkhkhkhkhdddhdhrrzzssssshshshshssss",
           "public locale transliteration maps Arabic presentation forms-B mid range");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FEBD#, 16#FEBE#, 16#FEBF#, 16#FEC0#,
                     16#FEC1#, 16#FEC2#, 16#FEC3#, 16#FEC4#,
                     16#FEC5#, 16#FEC6#, 16#FEC7#, 16#FEC8#,
                     16#FEC9#, 16#FECA#, 16#FECB#, 16#FECC#,
                     16#FECD#, 16#FECE#, 16#FECF#, 16#FED0#]), "ar") =
             "ddddttttzzzzaaaaghghghgh",
           "public locale transliteration maps Arabic presentation forms-B byte boundary");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FED1#, 16#FED2#, 16#FED3#, 16#FED4#,
                     16#FED5#, 16#FED6#, 16#FED7#, 16#FED8#,
                     16#FED9#, 16#FEDA#, 16#FEDB#, 16#FEDC#,
                     16#FEDD#, 16#FEDE#, 16#FEDF#, 16#FEE0#,
                     16#FEE1#, 16#FEE2#, 16#FEE3#, 16#FEE4#,
                     16#FEE5#, 16#FEE6#, 16#FEE7#, 16#FEE8#,
                     16#FEE9#, 16#FEEA#, 16#FEEB#, 16#FEEC#,
                     16#FEED#, 16#FEEE#, 16#FEEF#, 16#FEF0#,
                     16#FEF1#, 16#FEF2#, 16#FEF3#, 16#FEF4#]), "ar") =
             "ffffqqqqkkkkllllmmmmnnnnhhhhwwaayyyy",
           "public locale transliteration maps Arabic presentation forms-B final range");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#67E#, 16#686#, 16#698#, 16#6A9#, 16#6AF#,
                     16#6CC#]), "fa") =
             "pchzhkgy",
           "public locale transliteration maps Persian Arabic-script letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FB56#, 16#FB57#, 16#FB58#, 16#FB59#,
                     16#FB7A#, 16#FB7B#, 16#FB7C#, 16#FB7D#,
                     16#FB8A#, 16#FB8B#, 16#FB8E#, 16#FB8F#,
                     16#FB90#, 16#FB91#, 16#FB92#, 16#FB93#,
                     16#FB94#, 16#FB95#, 16#FBE8#, 16#FBE9#,
                     16#FBFC#, 16#FBFD#, 16#FBFE#, 16#FBFF#]),
              "fa") =
             "ppppchchchchzhzhkkkkggggaayyyy",
           "public locale transliteration maps Arabic presentation forms-A single letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FC00#, 16#FC01#, 16#FC02#, 16#FC03#,
                     16#FC04#, 16#FC05#, 16#FC06#, 16#FC07#,
                     16#FC08#, 16#FC09#, 16#FC0A#, 16#FC0B#,
                     16#FC0C#, 16#FC0D#, 16#FC0E#, 16#FC0F#,
                     16#FC10#, 16#FC11#, 16#FC12#, 16#FC13#,
                     16#FC14#, 16#FC15#, 16#FC16#, 16#FC17#,
                     16#FC18#, 16#FC19#, 16#FC1A#, 16#FC1B#,
                     16#FC1C#, 16#FC1D#, 16#FC1E#, 16#FC1F#,
                     16#FC20#, 16#FC21#, 16#FC22#, 16#FC23#,
                     16#FC24#, 16#FC25#, 16#FC26#, 16#FC27#,
                     16#FC28#, 16#FC29#, 16#FC2A#, 16#FC2B#,
                     16#FC2C#]), "ar") =
             "yjyhymyayybjbhbkhbmbabytjthtkhtmtatythjthmthathy"
             & "jhjmhjhmkhjkhhkhmsjshskhsmshsmdjdhdkhdmthtmzmajamghjghm",
           "public locale transliteration maps Arabic presentation forms-A"
           & " isolated ligatures first range");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FC2D#, 16#FC2E#, 16#FC2F#, 16#FC30#,
                     16#FC31#, 16#FC32#, 16#FC33#, 16#FC34#,
                     16#FC35#, 16#FC36#, 16#FC37#, 16#FC38#,
                     16#FC39#, 16#FC3A#, 16#FC3B#, 16#FC3C#,
                     16#FC3D#, 16#FC3E#, 16#FC3F#, 16#FC40#,
                     16#FC41#, 16#FC42#, 16#FC43#, 16#FC44#,
                     16#FC45#, 16#FC46#, 16#FC47#, 16#FC48#,
                     16#FC49#, 16#FC4A#, 16#FC4B#, 16#FC4C#,
                     16#FC4D#, 16#FC4E#, 16#FC4F#, 16#FC50#,
                     16#FC51#, 16#FC52#, 16#FC53#, 16#FC54#,
                     16#FC55#, 16#FC56#, 16#FC57#, 16#FC58#,
                     16#FC59#, 16#FC5A#]), "ar") =
             "fjfhfkhfmfafyqhqmqaqykakjkhkkhklkmkakyljlhlkhlmlaly"
             & "mjmhmkhmmmamynjnhnkhnmnanyhjhmhahyyjyhykhymyayy",
           "public locale transliteration maps Arabic presentation forms-A"
           & " isolated ligatures second range");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FBEA#, 16#FBEE#, 16#FBF9#, 16#FC64#,
                     16#FC80#, 16#FC97#, 16#FCC0#, 16#FCDF#,
                     16#FCF5#, 16#FD3B#]), "ar") =
             "yaywyayrkayjfkhymtazm",
           "public locale transliteration maps Arabic presentation forms-A"
           & " two-letter ligatures across forms");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#FD50#, 16#FD58#, 16#FD80#, 16#FD92#,
                     16#FDBA#, 16#FDC7#, 16#FDF2#, 16#FDF3#,
                     16#FDF4#, 16#FDF9#]), "ar") =
             "tjmjmhlhmmjkhljmnjyallhakbrmhmdsla",
           "public locale transliteration maps Arabic presentation forms-A"
           & " multi-letter ligatures");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#]), "ka") =
             "sakartvelo",
           "public locale transliteration maps bounded Georgian letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#1CA1#, 16#1C90#, 16#1CA5#, 16#1C90#,
                     16#1CA0#, 16#1C97#, 16#1C95#, 16#1C94#,
                     16#1C9A#, 16#1C9D#]), "ka") =
             "SAKARTVELO",
           "public locale transliteration preserves bounded Georgian case");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#10F1#, 16#10F2#, 16#10F3#, 16#10F4#,
                     16#10F5#, 16#10F6#, 16#10F7#, 16#10F8#,
                     16#10F9#, 16#10FA#, 16#10FC#, 16#10FD#,
                     16#10FE#, 16#10FF#]), "ka") =
             "hehieweharhoefiynelifiganainnaenhardlabial",
           "public locale transliteration maps historic Georgian letters");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#1CB1#, 16#1CB2#, 16#1CB3#, 16#1CB4#,
                     16#1CB5#, 16#1CB6#, 16#1CB7#, 16#1CB8#,
                     16#1CB9#, 16#1CBA#, 16#1CBD#, 16#1CBE#,
                     16#1CBF#]), "ka") =
             "HeHieWeHarHoeFiYnElifiGanAinAenHardLabial",
           "public locale transliteration maps historic Georgian Mtavruli");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#10A0#, 16#10AF#, 16#10B5#, 16#10B6#,
                     16#10C1#, 16#10C2#, 16#10C7#, 16#10CD#]), "ka") =
             "AZhKhGhHeHieYnAen",
           "public locale transliteration maps Georgian Asomtavruli");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#2D00#, 16#2D0F#, 16#2D15#, 16#2D16#,
                     16#2D21#, 16#2D22#, 16#2D27#, 16#2D2D#]), "ka") =
             "azhkhghhehieynaen",
           "public locale transliteration maps Georgian Nuskhuri");
   Assert (I18N.Locales.Transliterate_ASCII ("ASCII 123", "en") =
             "ASCII 123",
           "public locale transliteration preserves ASCII text");
   Assert (I18N.Locales.Transliterate_ASCII
             (UTF8 ([16#65E5#, 16#672C#]), "ja") =
             UTF8 ([16#65E5#, 16#672C#]),
           "public locale transliteration preserves unsupported scripts");
   Assert (I18N.Locales.Direction ("ar-EG") =
             I18N.Locales.Right_To_Left,
           "public locale direction recognizes Arabic RTL locales");
   Assert (I18N.Locales.Is_Right_To_Left ("iw-IL"),
           "public locale direction follows canonical language aliases");
   Assert (I18N.Locales.Is_Right_To_Left ("az-Arab-IR"),
           "public locale direction recognizes explicit RTL scripts");
   Assert (I18N.Locales.Direction ("az-Latn-AZ") =
             I18N.Locales.Left_To_Right,
           "public locale direction keeps explicit Latin-script locales LTR");
   Assert (I18N.Locales.Direction ("en-US") =
             I18N.Locales.Left_To_Right,
           "public locale direction defaults Latin locales to LTR");
   Assert (I18N.Locales.Canonicalize ("sh_BA") = "sr-Latn-BA",
           "public locale canonicalization expands Serbo-Croatian alias");
   Assert (I18N.Locales.Maximize ("zh-HK") = "zh-Hant-HK",
           "public locale maximize infers Traditional Chinese for Hong Kong");
   Assert (I18N.Locales.Maximize ("sr-Latn") = "sr-Latn-RS",
           "public locale maximize preserves explicit script");
   Assert (I18N.Locales.Minimize ("en-Latn-US") = "en",
           "public locale minimize removes default script and region");
   Assert (I18N.Locales.Minimize ("zh-Hant-TW") = "zh-Hant",
           "public locale minimize preserves non-default script");
   Assert (I18N.Locales.Match
             ("en, fr, de-AT", "fr-CA, de;q=0.9, en;q=0.1") = "fr",
           "public locale matching follows requested parent fallback");
   Assert (I18N.Locales.Match
             ("zh-Hant, en", "zh-HK, en;q=0.1") = "zh-Hant",
           "public locale matching follows likely-subtag parent fallback");
   Assert (I18N.Locales.Match
             ("en, de", "fr;q=0, *;q=0.5") = "en",
           "public locale matching honors q=0 and wildcard ranges");
   Assert (I18N.Locales.Match
             ("en, de", "fr-CA", "en-US") = "en-US",
           "public locale matching returns canonical default without a match");
   Assert (I18N.Locales.Sort_Key
             ("R" & U (16#E9#) & "sum" & U (16#E9#), "en") =
             "resume",
           "public locale sort keys fold common Latin accents");
   Assert (I18N.Locales.Sort_Key
             (U (16#C4#) & "rger " & U (16#DF#), "de") =
             "aerger ss",
           "public locale sort keys apply German ae/ss tailoring");
   Assert (I18N.Locales.Sort_Key
             (U (16#10C#) & "esk" & U (16#FD#) & " "
              & U (16#110#) & "uro "
              & U (16#141#) & U (16#F3#) & "d" & U (16#17A#)
              & " " & U (16#152#) & "uvre", "en") =
             "cesky duro lodz oeuvre",
           "public locale sort keys fold broader Latin Extended letters");
   Assert (I18N.Locales.Sort_Key
             (U (16#106#) & U (16#13A#) & U (16#122#)
              & U (16#163#) & U (16#154#) & U (16#17A#), "en") =
             "clgtrz",
           "public locale sort keys fold Latin Extended acute and cedilla pairs");
   Assert (I18N.Locales.Sort_Key
             (U (16#1EA0#) & U (16#1EB9#) & U (16#1ECA#)
              & U (16#1ECD#) & U (16#1EE4#) & U (16#1EF5#), "vi") =
             "aeiouy",
           "public locale sort keys fold Latin dot-below vowels");
   Assert (I18N.Locales.Sort_Key
             (U (16#1A0#) & U (16#1A1#)
              & U (16#1AF#) & U (16#1B0#), "vi") =
             "oouu",
           "public locale sort keys fold Latin horn vowels");
   Assert (I18N.Locales.Sort_Key
             (U (16#1EDA#) & U (16#1EDD#)
              & U (16#1EEC#) & U (16#1EEF#) & U (16#1EF1#), "vi") =
             "oouuu",
           "public locale sort keys fold tone-marked horn vowels");
   Assert (I18N.Locales.Sort_Key
             (U (16#1EA4#) & U (16#1EAD#)
              & U (16#1EB0#) & U (16#1EB5#)
              & U (16#1EC2#) & U (16#1EC5#)
              & U (16#1ED0#) & U (16#1ED9#), "vi") =
             "aaaaeeoo",
           "public locale sort keys fold Vietnamese circumflex and breve tone vowels");
   Assert (I18N.Locales.Sort_Key
             (UTF8 ([16#386#, 16#3AC#, 16#388#, 16#3AD#,
                     16#38A#, 16#390#, 16#3AA#, 16#3CA#,
                     16#38E#, 16#3B0#, 16#3AB#, 16#3CB#,
                     16#38F#, 16#3CE#]), "el") =
             I18N.Locales.Sort_Key
               (UTF8 ([16#391#, 16#3B1#, 16#395#, 16#3B5#,
                       16#399#, 16#3B9#, 16#399#, 16#3B9#,
                       16#3A5#, 16#3C5#, 16#3A5#, 16#3C5#,
                       16#3A9#, 16#3C9#]), "el"),
           "public locale sort keys fold Greek tonos and dialytika vowels");
   Assert (I18N.Locales.Sort_Key
             (UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#]), "ka") =
           I18N.Locales.Sort_Key
             (UTF8 ([16#1CA1#, 16#1C90#, 16#1CA5#, 16#1C90#,
                     16#1CA0#, 16#1C97#, 16#1C95#, 16#1C94#,
                     16#1C9A#, 16#1C9D#]), "ka"),
           "public locale sort keys fold Georgian Mkhedruli/Mtavruli pairs");
   Assert (I18N.Locales.Sort_Key
             (UTF8 ([16#10F1#, 16#10F2#, 16#10F3#, 16#10FD#,
                     16#10FE#, 16#10FF#]), "ka") =
           I18N.Locales.Sort_Key
             (UTF8 ([16#1CB1#, 16#1CB2#, 16#1CB3#, 16#1CBD#,
                     16#1CBE#, 16#1CBF#]), "ka"),
           "public locale sort keys fold historic Georgian case pairs");
   Assert (I18N.Locales.Compare
             (U (16#C4#) & "rger", "apfel", "de") =
             I18N.Locales.Before,
           "public locale compare orders German tailored keys");
   Assert (I18N.Locales.Compare
             ("hrob", "chata", "cs") = I18N.Locales.Before,
           "public locale compare places Czech ch after h");
   Assert (I18N.Locales.Compare
             ("chata", "ibis", "cs") = I18N.Locales.Before,
           "public locale compare keeps Czech ch before i");
   Assert (I18N.Locales.Compare
             ("loma", "ljubav", "hr") = I18N.Locales.Before,
           "public locale compare places Croatian lj after l");
   Assert (I18N.Locales.Sort_Key ("lj", "sr-Cyrl") = "lj",
           "public locale sort keys keep Latin contractions out of sr-Cyrl");
   Assert (I18N.Locales.Compare
             ("duda", "d" & U (16#17E#) & "em", "hr") =
             I18N.Locales.Before,
           "public locale compare places Croatian dz-caron after d");
   Assert (I18N.Locales.Compare
             ("zoo", U (16#E5#) & "ngstrom", "sv") =
             I18N.Locales.Before,
           "public locale compare places Swedish aa-ring after z");
   Assert (I18N.Locales.Compare
             (U (16#E5#) & "ngstrom", U (16#E4#) & "pple", "sv") =
             I18N.Locales.Before,
           "public locale compare keeps Swedish aa-ring before a-umlaut");
   Assert (I18N.Locales.Compare
             ("nino", "ni" & U (16#F1#) & "o", "es") =
             I18N.Locales.Before,
           "public locale compare tailors Spanish n-tilde after n");
   Assert (I18N.Locales.Compare
             ("resume", "resume", "en") = I18N.Locales.Same,
           "public locale compare reports exact string equality");
   Assert (I18N.Locales.Compare
             ("resume", "r" & U (16#E9#) & "sume", "en") =
             I18N.Locales.Before,
           "public locale compare uses raw bytes as deterministic tie-break");
   Assert (I18N.Locales.Compare
             ("file2", "file10", "en-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare honors numeric collation extension");
   Assert (I18N.Locales.Compare
             ("file" & U (16#0662#),
              "file" & U (16#0661#) & U (16#0660#), "ar-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Arabic-Indic digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#0E52#),
              "file" & U (16#0E51#) & U (16#0E50#), "th-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Thai digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#0AE8#),
              "file" & U (16#0AE7#) & U (16#0AE6#), "gu-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Gujarati digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#0F22#),
              "file" & U (16#0F21#) & U (16#0F20#), "bo-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Tibetan digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#17E2#),
              "file" & U (16#17E1#) & U (16#17E0#), "km-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Khmer digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#FF12#),
              "file" & U (16#FF11#) & U (16#FF10#), "ja-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders fullwidth digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#1042#),
              "file" & U (16#1041#) & U (16#1040#), "my-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Myanmar digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file" & U (16#4E8C#),
              "file" & U (16#4E00#) & U (16#3007#), "zh-u-kn-true") =
             I18N.Locales.Before,
           "public locale compare orders Han decimal digit runs numerically");
   Assert (I18N.Locales.Compare
             ("file2", "file10", "en") = I18N.Locales.After,
           "public locale compare keeps lexical digit order by default");
   Assert (I18N.Locales.Equivalent
             ("resume", "r" & U (16#E9#) & "sum" & U (16#E9#), "en"),
           "public locale equivalence compares primary collation keys");
   Assert (I18N.Locales.Equivalent
             ("cafe" & U (16#301#), "caf" & U (16#E9#), "en"),
           "public locale equivalence ignores bounded combining marks");
   Assert (I18N.Locales.Equivalent
             ("ClGtrz",
              U (16#106#) & U (16#13A#) & U (16#122#)
              & U (16#163#) & U (16#154#) & U (16#17A#), "en"),
           "public locale equivalence folds Latin Extended acute and cedilla pairs");
   Assert (I18N.Locales.Equivalent
             ("aeiouy",
              U (16#1EA0#) & U (16#1EB9#) & U (16#1ECA#)
              & U (16#1ECD#) & U (16#1EE4#) & U (16#1EF5#), "vi"),
           "public locale equivalence folds Latin dot-below vowels");
   Assert (I18N.Locales.Equivalent
             ("oouu",
              U (16#1A0#) & U (16#1A1#)
              & U (16#1AF#) & U (16#1B0#), "vi"),
           "public locale equivalence folds Latin horn vowels");
   Assert (I18N.Locales.Equivalent
             ("oouuu",
              U (16#1EDA#) & U (16#1EDD#)
              & U (16#1EEC#) & U (16#1EEF#) & U (16#1EF1#), "vi"),
           "public locale equivalence folds tone-marked horn vowels");
   Assert (I18N.Locales.Equivalent
             ("aaaaeeoo",
              U (16#1EA4#) & U (16#1EAD#)
              & U (16#1EB0#) & U (16#1EB5#)
              & U (16#1EC2#) & U (16#1EC5#)
              & U (16#1ED0#) & U (16#1ED9#), "vi"),
           "public locale equivalence folds Vietnamese circumflex and breve tone vowels");
   Assert (I18N.Locales.Equivalent
             ("fffiflffifflstst",
              UTF8 ([16#FB00#, 16#FB01#, 16#FB02#, 16#FB03#,
                     16#FB04#, 16#FB05#, 16#FB06#]), "en"),
           "public locale equivalence expands Latin alphabetic ligatures");
   Assert (I18N.Locales.Equivalent
             ("abcxyz12",
              UTF8 ([16#FF21#, 16#FF22#, 16#FF43#, 16#FF58#,
                     16#FF59#, 16#FF5A#, 16#FF11#, 16#FF12#]), "en"),
           "public locale equivalence folds fullwidth Latin letters and digits");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#]),
              UTF8 ([16#1CA1#, 16#1C90#, 16#1CA5#, 16#1C90#,
                     16#1CA0#, 16#1C97#, 16#1C95#, 16#1C94#,
                     16#1C9A#, 16#1C9D#]), "ka"),
           "public locale equivalence folds Georgian case pairs");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#1CB1#, 16#1CB2#, 16#1CB3#, 16#1CBD#,
                     16#1CBE#, 16#1CBF#]),
              UTF8 ([16#10F3#, 16#10FD#, 16#10FE#]), "ka"),
           "public locale contains searches historic Georgian primary keys");
   Assert (I18N.Locales.Contains
             (U (16#1681#) & U (16#1682#) & " "
              & U (16#16A0#) & U (16#16F8#),
              U (16#1682#) & " " & U (16#16A0#), "ga"),
           "public locale contains searches bounded Ogham and Runic byte keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#643#, 16#650#, 16#62A#, 16#64E#,
                     16#627#, 16#628#]),
              UTF8 ([16#643#, 16#62A#, 16#627#, 16#628#]), "ar"),
           "public locale equivalence ignores bounded Arabic marks");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FB2A#, 16#FB2B#, 16#FB2C#, 16#FB2D#,
                     16#FB49#]),
              UTF8 ([16#5E9#, 16#5E9#, 16#5E9#, 16#5E9#,
                     16#5E9#]), "he"),
           "public locale equivalence folds Hebrew shin presentation forms");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FB2E#, 16#FB2F#, 16#FB30#, 16#FB4F#]),
              UTF8 ([16#5D0#, 16#5D0#, 16#5D0#, 16#5D0#,
                     16#5DC#]), "he"),
           "public locale equivalence folds Hebrew alef presentation forms");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FB31#, 16#FB32#, 16#FB33#, 16#FB34#,
                     16#FB35#, 16#FB37#, 16#FB38#, 16#FB39#,
                     16#FB3A#, 16#FB3B#, 16#FB3C#, 16#FB3E#]),
              UTF8 ([16#5D1#, 16#5D2#, 16#5D3#, 16#5D4#,
                     16#5D5#, 16#5D6#, 16#5D8#, 16#5D9#,
                     16#5DA#, 16#5DB#, 16#5DC#, 16#5DE#]), "he"),
           "public locale equivalence folds Hebrew dagesh presentation forms");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FB40#, 16#FB41#, 16#FB43#, 16#FB44#,
                     16#FB46#, 16#FB47#, 16#FB48#, 16#FB4A#,
                     16#FB4B#, 16#FB4C#, 16#FB4D#, 16#FB4E#]),
              UTF8 ([16#5E0#, 16#5E1#, 16#5E3#, 16#5E4#,
                     16#5E6#, 16#5E7#, 16#5E8#, 16#5EA#,
                     16#5D5#, 16#5D1#, 16#5DB#, 16#5E4#]), "he"),
           "public locale equivalence folds later Hebrew presentation forms");
   Assert (not I18N.Locales.Equivalent
             (UTF8 ([16#FB36#, 16#FB3D#, 16#FB3F#, 16#FB42#,
                     16#FB45#]),
              UTF8 ([16#5D6#, 16#5DD#, 16#5DF#, 16#5E2#,
                     16#5E5#]), "he"),
           "public locale equivalence preserves unassigned Hebrew presentation forms");
   Assert (I18N.Locales.Equivalent
             ("ab", "a" & U (16#1AB0#) & "b" & U (16#1AFF#), "en"),
           "public locale equivalence ignores bounded extended combining marks");
   Assert (I18N.Locales.Equivalent
             ("ab", "a" & U (16#1DC0#) & "b" & U (16#1DFF#), "en"),
           "public locale equivalence ignores bounded supplement combining marks");
   Assert (I18N.Locales.Equivalent
             ("ab", "a" & U (16#20D0#) & "b" & U (16#20FF#), "en"),
           "public locale equivalence ignores bounded symbol combining marks");
   Assert (I18N.Locales.Equivalent
             ("ab", "a" & U (16#FE20#) & "b" & U (16#FE2F#), "en"),
           "public locale equivalence ignores bounded half combining marks");
   Assert (I18N.Locales.Equivalent
             (U (16#5E9#) & U (16#5DC#) & U (16#5D5#)
              & U (16#5DD#),
              U (16#5E9#) & U (16#5B8#) & U (16#5DC#)
              & U (16#5D5#) & U (16#5BC#) & U (16#5DD#),
              "he"),
           "public locale equivalence ignores bounded Hebrew marks");
   Assert (I18N.Locales.Equivalent
             (U (16#712#) & U (16#713#),
              U (16#712#) & U (16#711#) & U (16#730#)
              & U (16#713#) & U (16#74A#), "syr"),
           "public locale equivalence ignores bounded Syriac marks");
   Assert (I18N.Locales.Equivalent
             (U (16#786#) & U (16#787#),
              U (16#786#) & U (16#7A6#) & U (16#787#)
              & U (16#7B0#), "dv"),
           "public locale equivalence ignores bounded Thaana marks");
   Assert (I18N.Locales.Equivalent
             (U (16#7CA#) & U (16#7CB#),
              U (16#7CA#) & U (16#7EB#) & U (16#7CB#)
              & U (16#7F3#), "nqo"),
           "public locale equivalence ignores bounded NKo marks");
   Assert (I18N.Locales.Equivalent
             (U (16#800#) & U (16#801#),
              U (16#800#) & U (16#816#) & U (16#801#)
              & U (16#82D#), "sam"),
           "public locale equivalence ignores bounded Samaritan marks");
   Assert (I18N.Locales.Equivalent
             (U (16#840#) & U (16#841#),
              U (16#840#) & U (16#859#) & U (16#841#)
              & U (16#85B#), "mid"),
           "public locale equivalence ignores bounded Mandaic marks");
   Assert (I18N.Locales.Equivalent
             ("item7", "item007", "en-u-kn-true"),
           "public locale equivalence ignores leading zeros with numeric collation");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#06F0#) & U (16#06F0#)
              & U (16#06F7#), "fa-u-kn-true"),
           "public locale equivalence normalizes Persian digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#07C0#) & U (16#07C0#)
              & U (16#07C7#), "nqo-u-kn-true"),
           "public locale equivalence normalizes NKo digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#0A66#) & U (16#0A66#)
              & U (16#0A6D#), "pa-u-kn-true"),
           "public locale equivalence normalizes Gurmukhi digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#0C66#) & U (16#0C66#)
              & U (16#0C6D#), "te-u-kn-true"),
           "public locale equivalence normalizes Telugu digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#0ED0#) & U (16#0ED0#)
              & U (16#0ED7#), "lo-u-kn-true"),
           "public locale equivalence normalizes Lao digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#FF10#) & U (16#FF10#)
              & U (16#FF17#), "ja-u-kn-true"),
           "public locale equivalence normalizes fullwidth digit runs");
   Assert (I18N.Locales.Equivalent
             ("item7", "item" & U (16#3007#) & U (16#3007#)
              & U (16#4E03#), "zh-u-kn-true"),
           "public locale equivalence normalizes Han decimal digit runs");
   Assert (I18N.Locales.Equivalent
             ("strasse", "stra" & U (16#DF#) & "e", "de"),
           "public locale equivalence applies German ss tailoring");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#391#, 16#392#, 16#393#]),
              UTF8 ([16#3B1#, 16#3B2#, 16#3B3#]), "el"),
           "public locale equivalence folds bounded Greek case");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#41F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
              UTF8 ([16#43F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
              "ru"),
           "public locale equivalence folds bounded Cyrillic case");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#531#, 16#532#, 16#533#]),
              UTF8 ([16#561#, 16#562#, 16#563#]), "hy"),
           "public locale equivalence folds bounded Armenian case");
   Assert (not I18N.Locales.Equivalent
             ("nino", "ni" & U (16#F1#) & "o", "es"),
           "public locale equivalence distinguishes Spanish n-tilde");
   Assert (I18N.Locales.Contains
             ("Archived R" & U (16#E9#) & "sum" & U (16#E9#),
              "resume", "en"),
           "public locale contains searches accent-folded keys");
   Assert (I18N.Locales.Contains
             ("Cafe" & U (16#301#) & " archive",
              "caf" & U (16#E9#), "en"),
           "public locale contains searches decomposed accent keys");
   Assert (I18N.Locales.Contains
             ("Archive "
              & U (16#106#) & U (16#13A#) & U (16#122#)
              & U (16#163#) & U (16#154#) & U (16#17A#),
              "clgtrz", "en"),
           "public locale contains searches Latin Extended acute and cedilla keys");
   Assert (I18N.Locales.Contains
             ("Archive " & U (16#1EA0#) & U (16#1EB9#)
              & U (16#1ECA#) & U (16#1ECD#)
              & U (16#1EE4#) & U (16#1EF5#),
              "aeiouy", "vi"),
           "public locale contains searches Latin dot-below vowel keys");
   Assert (I18N.Locales.Contains
             ("Archive " & U (16#1A0#) & U (16#1A1#)
              & U (16#1AF#) & U (16#1B0#),
              "oouu", "vi"),
           "public locale contains searches Latin horn vowel keys");
   Assert (I18N.Locales.Contains
             ("Archive " & U (16#1EDA#) & U (16#1EDD#)
              & U (16#1EEC#) & U (16#1EEF#) & U (16#1EF1#),
              "oouuu", "vi"),
           "public locale contains searches tone-marked horn vowel keys");
   Assert (I18N.Locales.Contains
             ("Archive " & U (16#1EA4#) & U (16#1EAD#)
              & U (16#1EB0#) & U (16#1EB5#)
              & U (16#1EC2#) & U (16#1EC5#)
              & U (16#1ED0#) & U (16#1ED9#),
              "aaaaeeoo", "vi"),
           "public locale contains searches Vietnamese circumflex and breve tone vowel keys");
   Assert (I18N.Locales.Contains
             ("office " & UTF8 ([16#FB03#, 16#FB02#, 16#FB05#]),
              "ffiflst", "en"),
           "public locale contains searches Latin ligatures by expanded keys");
   Assert (I18N.Locales.Contains
             ("office ffiflst",
              UTF8 ([16#FB03#, 16#FB02#, 16#FB05#]), "en"),
           "public locale contains searches expanded Latin text by ligature keys");
   Assert (I18N.Locales.Contains
             ("SKU " & UTF8 ([16#FF21#, 16#FF22#, 16#FF43#,
                              16#FF11#, 16#FF12#]),
              "abc12", "en"),
           "public locale contains searches fullwidth Latin text by ASCII keys");
   Assert (I18N.Locales.Contains
             ("SKU abc12",
              UTF8 ([16#FF21#, 16#FF22#, 16#FF43#,
                     16#FF11#, 16#FF12#]), "en"),
           "public locale contains searches ASCII text by fullwidth Latin keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#30AB#, 16#30BF#, 16#30AB#, 16#30CA#]),
              UTF8 ([16#FF76#, 16#FF80#, 16#FF76#, 16#FF85#]), "ja"),
           "public locale equivalence folds halfwidth Katakana letters");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#30AC#, 16#30D1#, 16#30F4#]),
              UTF8 ([16#FF76#, 16#FF9E#, 16#FF8A#, 16#FF9F#,
                     16#FF73#, 16#FF9E#]), "ja"),
           "public locale equivalence composes halfwidth Katakana voiced marks");
   Assert (I18N.Locales.Contains
             ("Kana " & UTF8 ([16#FF76#, 16#FF80#, 16#FF76#, 16#FF85#]),
              UTF8 ([16#30AB#, 16#30BF#, 16#30AB#, 16#30CA#]), "ja"),
           "public locale contains searches halfwidth Katakana by fullwidth keys");
   Assert (I18N.Locales.Contains
             ("Kana " & UTF8 ([16#30AB#, 16#30BF#, 16#30AB#, 16#30CA#]),
              UTF8 ([16#FF76#, 16#FF80#, 16#FF76#, 16#FF85#]), "ja"),
           "public locale contains searches fullwidth Katakana by halfwidth keys");
   Assert (I18N.Locales.Contains
             ("Kana " & UTF8 ([16#FF76#, 16#FF9E#, 16#FF8A#, 16#FF9F#]),
              UTF8 ([16#30AC#, 16#30D1#]), "ja"),
           "public locale contains searches marked halfwidth Katakana by fullwidth keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#1100#, 16#1161#, 16#1102#, 16#1161#]),
              UTF8 ([16#3131#, 16#314F#, 16#3134#, 16#314F#]), "ko"),
           "public locale equivalence folds Hangul compatibility Jamo");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#1100#, 16#1109#, 16#1105#, 16#1112#]),
              UTF8 ([16#3133#, 16#3140#]), "ko"),
           "public locale equivalence expands composite Hangul compatibility Jamo");
   Assert (I18N.Locales.Contains
             ("Hangul " & UTF8 ([16#3131#, 16#314F#, 16#3134#, 16#314F#]),
              UTF8 ([16#1100#, 16#1161#, 16#1102#, 16#1161#]), "ko"),
           "public locale contains searches compatibility Jamo by conjoining keys");
   Assert (I18N.Locales.Contains
             ("Hangul " & UTF8 ([16#1100#, 16#1161#, 16#1102#, 16#1161#]),
              UTF8 ([16#3131#, 16#314F#, 16#3134#, 16#314F#]), "ko"),
           "public locale contains searches conjoining Jamo by compatibility keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#645#, 16#644#, 16#641#, 16#20#,
                     16#643#, 16#650#, 16#62A#, 16#64E#,
                     16#627#, 16#628#]),
              UTF8 ([16#643#, 16#62A#, 16#627#, 16#628#]), "ar"),
           "public locale contains searches Arabic text without marks");
   Assert (I18N.Locales.Contains
             ("STRASSE", "stra" & U (16#DF#) & "e", "de"),
           "public locale contains applies German ss tailoring");
   Assert (I18N.Locales.Contains
             (U (16#C5#) & "ngstrom", U (16#E5#) & "ng", "sv"),
           "public locale contains searches Nordic tailored keys");
   Assert (I18N.Locales.Contains ("Moja ljubav", "ljub", "hr"),
           "public locale contains searches South Slavic contractions");
   Assert (I18N.Locales.Contains
             ("build 00042 ready", "42", "en-u-kn-true"),
           "public locale contains searches numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0966#) & U (16#0966#)
              & U (16#096A#) & U (16#0968#) & " ready", "42",
              "hi-u-kn-true"),
           "public locale contains searches Devanagari numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0B66#) & U (16#0B66#)
              & U (16#0B6A#) & U (16#0B68#) & " ready", "42",
              "or-u-kn-true"),
           "public locale contains searches Odia numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0BE6#) & U (16#0BE6#)
              & U (16#0BEA#) & U (16#0BE8#) & " ready", "42",
              "ta-u-kn-true"),
           "public locale contains searches Tamil numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0CE6#) & U (16#0CE6#)
              & U (16#0CEA#) & U (16#0CE8#) & " ready", "42",
              "kn-u-kn-true"),
           "public locale contains searches Kannada numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0D66#) & U (16#0D66#)
              & U (16#0D6A#) & U (16#0D68#) & " ready", "42",
              "ml-u-kn-true"),
           "public locale contains searches Malayalam numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#0DE6#) & U (16#0DE6#)
              & U (16#0DEA#) & U (16#0DE8#) & " ready", "42",
              "si-u-kn-true"),
           "public locale contains searches Sinhala numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1040#) & U (16#1040#)
              & U (16#1044#) & U (16#1042#) & " ready", "42",
              "my-u-kn-true"),
           "public locale contains searches Myanmar numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1946#) & U (16#1946#)
              & U (16#194A#) & U (16#1948#) & " ready", "42",
              "lif-u-kn-true"),
           "public locale contains searches Limbu numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#19D0#) & U (16#19D0#)
              & U (16#19D4#) & U (16#19D2#) & " ready", "42",
              "khb-u-kn-true"),
           "public locale contains searches New Tai Lue numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#A900#) & U (16#A900#)
              & U (16#A904#) & U (16#A902#) & " ready", "42",
              "kyu-u-kn-true"),
           "public locale contains searches Kayah Li numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#A9D0#) & U (16#A9D0#)
              & U (16#A9D4#) & U (16#A9D2#) & " ready", "42",
              "jv-u-kn-true"),
           "public locale contains searches Javanese numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#AA50#) & U (16#AA50#)
              & U (16#AA54#) & U (16#AA52#) & " ready", "42",
              "cjm-u-kn-true"),
           "public locale contains searches Cham numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1A80#) & U (16#1A80#)
              & U (16#1A84#) & U (16#1A82#) & " ready", "42",
              "nod-u-kn-true"),
           "public locale contains searches Tai Tham Hora numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1A90#) & U (16#1A90#)
              & U (16#1A94#) & U (16#1A92#) & " ready", "42",
              "nod-u-kn-true"),
           "public locale contains searches Tai Tham Tham numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1B50#) & U (16#1B50#)
              & U (16#1B54#) & U (16#1B52#) & " ready", "42",
              "ban-u-kn-true"),
           "public locale contains searches Balinese numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1BB0#) & U (16#1BB0#)
              & U (16#1BB4#) & U (16#1BB2#) & " ready", "42",
              "su-u-kn-true"),
           "public locale contains searches Sundanese numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1C40#) & U (16#1C40#)
              & U (16#1C44#) & U (16#1C42#) & " ready", "42",
              "lep-u-kn-true"),
           "public locale contains searches Lepcha numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1C50#) & U (16#1C50#)
              & U (16#1C54#) & U (16#1C52#) & " ready", "42",
              "sat-u-kn-true"),
           "public locale contains searches Ol Chiki numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#A620#) & U (16#A620#)
              & U (16#A624#) & U (16#A622#) & " ready", "42",
              "vai-u-kn-true"),
           "public locale contains searches Vai numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#A8D0#) & U (16#A8D0#)
              & U (16#A8D4#) & U (16#A8D2#) & " ready", "42",
              "saz-u-kn-true"),
           "public locale contains searches Saurashtra numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11066#) & U (16#11066#)
              & U (16#1106A#) & U (16#11068#) & " ready", "42",
              "brh-u-kn-true"),
           "public locale contains searches Brahmi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#110F0#) & U (16#110F0#)
              & U (16#110F4#) & U (16#110F2#) & " ready", "42",
              "srb-u-kn-true"),
           "public locale contains searches Sora Sompeng numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11136#) & U (16#11136#)
              & U (16#1113A#) & U (16#11138#) & " ready", "42",
              "ccp-u-kn-true"),
           "public locale contains searches Chakma numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#111D0#) & U (16#111D0#)
              & U (16#111D4#) & U (16#111D2#) & " ready", "42",
              "sa-Shrd-u-kn-true"),
           "public locale contains searches Sharada numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#112F0#) & U (16#112F0#)
              & U (16#112F4#) & U (16#112F2#) & " ready", "42",
              "sd-Sind-u-kn-true"),
           "public locale contains searches Khudawadi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11450#) & U (16#11450#)
              & U (16#11454#) & U (16#11452#) & " ready", "42",
              "new-u-kn-true"),
           "public locale contains searches Newa numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#114D0#) & U (16#114D0#)
              & U (16#114D4#) & U (16#114D2#) & " ready", "42",
              "mai-Tirh-u-kn-true"),
           "public locale contains searches Tirhuta numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11650#) & U (16#11650#)
              & U (16#11654#) & U (16#11652#) & " ready", "42",
              "mr-Modi-u-kn-true"),
           "public locale contains searches Modi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#116C0#) & U (16#116C0#)
              & U (16#116C4#) & U (16#116C2#) & " ready", "42",
              "doi-Takr-u-kn-true"),
           "public locale contains searches Takri numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11730#) & U (16#11730#)
              & U (16#11734#) & U (16#11732#) & " ready", "42",
              "aho-u-kn-true"),
           "public locale contains searches Ahom numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#118E0#) & U (16#118E0#)
              & U (16#118E4#) & U (16#118E2#) & " ready", "42",
              "hoc-Wara-u-kn-true"),
           "public locale contains searches Warang Citi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11C50#) & U (16#11C50#)
              & U (16#11C54#) & U (16#11C52#) & " ready", "42",
              "sa-Bhks-u-kn-true"),
           "public locale contains searches Bhaiksuki numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11D50#) & U (16#11D50#)
              & U (16#11D54#) & U (16#11D52#) & " ready", "42",
              "gon-Gonm-u-kn-true"),
           "public locale contains searches Masaram Gondi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11DA0#) & U (16#11DA0#)
              & U (16#11DA4#) & U (16#11DA2#) & " ready", "42",
              "gon-Gong-u-kn-true"),
           "public locale contains searches Gunjala Gondi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11DE0#) & U (16#11DE0#)
              & U (16#11DE4#) & U (16#11DE2#) & " ready", "42",
              "tsg-Tols-u-kn-true"),
           "public locale contains searches Tolong Siki numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11950#) & U (16#11950#)
              & U (16#11954#) & U (16#11952#) & " ready", "42",
              "dv-Diak-u-kn-true"),
           "public locale contains searches Dives Akuru numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#10D30#) & U (16#10D30#)
              & U (16#10D34#) & U (16#10D32#) & " ready", "42",
              "rhg-Rohg-u-kn-true"),
           "public locale contains searches Hanifi Rohingya numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#104A0#) & U (16#104A0#)
              & U (16#104A4#) & U (16#104A2#) & " ready", "42",
              "so-Osma-u-kn-true"),
           "public locale contains searches Osmanya numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#11F50#) & U (16#11F50#)
              & U (16#11F54#) & U (16#11F52#) & " ready", "42",
              "kaw-u-kn-true"),
           "public locale contains searches Kawi numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1E950#) & U (16#1E950#)
              & U (16#1E954#) & U (16#1E952#) & " ready", "42",
              "ff-Adlm-u-kn-true"),
           "public locale contains searches Adlam numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#16AC0#) & U (16#16AC0#)
              & U (16#16AC4#) & U (16#16AC2#) & " ready", "42",
              "nst-Tnsa-u-kn-true"),
           "public locale contains searches Tangsa numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#1E4F0#) & U (16#1E4F0#)
              & U (16#1E4F4#) & U (16#1E4F2#) & " ready", "42",
              "unr-Nagm-u-kn-true"),
           "public locale contains searches Nag Mundari numeric collation keys");
   Assert (I18N.Locales.Contains
             ("build " & U (16#3007#) & U (16#3007#)
              & U (16#56DB#) & U (16#4E8C#) & " ready", "42",
              "zh-u-kn-true"),
           "public locale contains searches Han decimal numeric collation keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#65E5#, 16#672C#, 16#8A9E#])
              & " " & UTF8 ([16#4E2D#, 16#6587#]),
              UTF8 ([16#4E2D#, 16#6587#]), "zh"),
           "public locale contains searches bounded three-byte script keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5DD#]),
              UTF8 ([16#5DC#, 16#5D5#]), "he"),
           "public locale contains searches bounded Hebrew byte keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FB2A#, 16#FB4F#, 16#FB44#]),
              UTF8 ([16#5D0#, 16#5DC#, 16#5E4#]), "he"),
           "public locale contains searches Hebrew presentation forms by base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#5E9#, 16#5D0#, 16#5DC#, 16#5E4#]),
              UTF8 ([16#FB4F#, 16#FB44#]), "he"),
           "public locale contains searches base Hebrew text by presentation keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#633#, 16#644#, 16#627#, 16#645#]),
              UTF8 ([16#644#, 16#627#]), "ar"),
           "public locale contains searches bounded Arabic byte keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FEF5#, 16#FEF6#, 16#FEF7#, 16#FEF8#,
                     16#FEF9#, 16#FEFA#, 16#FEFB#, 16#FEFC#]),
              UTF8 ([16#644#, 16#622#, 16#644#, 16#622#,
                     16#644#, 16#623#, 16#644#, 16#623#,
                     16#644#, 16#625#, 16#644#, 16#625#,
                     16#644#, 16#627#, 16#644#, 16#627#]), "ar"),
           "public locale equivalence folds Arabic lam-alef presentation ligatures");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FE80#, 16#FE81#, 16#FE82#, 16#FE83#,
                     16#FE84#, 16#FE85#, 16#FE86#, 16#FE87#,
                     16#FE88#, 16#FE89#, 16#FE8A#, 16#FE8B#,
                     16#FE8C#, 16#FE8D#, 16#FE8E#]),
              UTF8 ([16#621#, 16#622#, 16#622#, 16#623#,
                     16#623#, 16#624#, 16#624#, 16#625#,
                     16#625#, 16#626#, 16#626#, 16#626#,
                     16#626#, 16#627#, 16#627#]), "ar"),
           "public locale equivalence folds Arabic presentation forms-B alef range");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FEBD#, 16#FEBE#, 16#FEBF#, 16#FEC0#]),
              UTF8 ([16#636#, 16#636#, 16#636#, 16#636#]), "ar"),
           "public locale equivalence folds Arabic presentation forms-B byte boundary");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FEFB#, 16#FEFC#]),
              UTF8 ([16#644#, 16#627#]), "ar"),
           "public locale contains searches Arabic lam-alef ligatures by base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#644#, 16#627#, 16#644#, 16#627#]),
              UTF8 ([16#FEFC#]), "ar"),
           "public locale contains searches base Arabic text by lam-alef ligature keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FE8F#, 16#FE90#, 16#FE91#, 16#FE92#]),
              UTF8 ([16#628#, 16#628#]), "ar"),
           "public locale contains searches Arabic presentation forms-B by base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#636#, 16#636#, 16#636#, 16#636#]),
              UTF8 ([16#FEC0#]), "ar"),
           "public locale contains searches base Arabic text by presentation forms-B keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FB56#, 16#FB57#, 16#FB58#, 16#FB59#,
                     16#FB7A#, 16#FB7B#, 16#FB7C#, 16#FB7D#,
                     16#FB8A#, 16#FB8B#, 16#FB8E#, 16#FB8F#,
                     16#FB90#, 16#FB91#, 16#FB92#, 16#FB93#,
                     16#FB94#, 16#FB95#, 16#FBE8#, 16#FBE9#,
                     16#FBFC#, 16#FBFD#, 16#FBFE#, 16#FBFF#]),
              UTF8 ([16#67E#, 16#67E#, 16#67E#, 16#67E#,
                     16#686#, 16#686#, 16#686#, 16#686#,
                     16#698#, 16#698#, 16#6A9#, 16#6A9#,
                     16#6A9#, 16#6A9#, 16#6AF#, 16#6AF#,
                     16#6AF#, 16#6AF#, 16#649#, 16#649#,
                     16#6CC#, 16#6CC#, 16#6CC#, 16#6CC#]), "fa"),
           "public locale equivalence folds Arabic presentation forms-A single letters");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FB56#, 16#FB7A#, 16#FB8A#, 16#FB8E#]),
              UTF8 ([16#686#, 16#698#]), "fa"),
           "public locale contains searches Arabic presentation forms-A by base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#67E#, 16#686#, 16#698#, 16#6A9#]),
              UTF8 ([16#FB7B#, 16#FB8B#]), "fa"),
           "public locale contains searches base Persian text by presentation forms-A keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FC00#, 16#FC01#, 16#FC02#]),
              UTF8 ([16#626#, 16#62C#, 16#626#, 16#62D#,
                     16#626#, 16#645#]), "ar"),
           "public locale equivalence folds Arabic presentation forms-A"
           & " isolated ligatures");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FC3F#, 16#FC40#, 16#FC5A#]),
              UTF8 ([16#644#, 16#62C#, 16#644#, 16#62D#,
                     16#64A#, 16#64A#]), "ar"),
           "public locale equivalence folds later Arabic isolated ligatures");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FC00#, 16#FC01#, 16#FC02#]),
              UTF8 ([16#626#, 16#62D#]), "ar"),
           "public locale contains searches Arabic isolated ligatures by"
           & " base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#626#, 16#62C#, 16#626#, 16#62D#]),
              UTF8 ([16#FC01#]), "ar"),
           "public locale contains searches base Arabic text by isolated"
           & " ligature keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FBEA#, 16#FBEE#, 16#FBF9#, 16#FC64#,
                     16#FC80#, 16#FC97#, 16#FCC0#, 16#FCDF#,
                     16#FCF5#, 16#FD3B#]),
              UTF8 ([16#626#, 16#627#, 16#626#, 16#648#,
                     16#626#, 16#649#, 16#626#, 16#631#,
                     16#643#, 16#627#, 16#626#, 16#62C#,
                     16#641#, 16#62E#, 16#626#, 16#645#,
                     16#637#, 16#649#, 16#638#, 16#645#]), "ar"),
           "public locale equivalence folds Arabic presentation forms-A"
           & " two-letter ligatures across forms");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FBEA#, 16#FC64#, 16#FC80#, 16#FD3B#]),
              UTF8 ([16#626#, 16#631#, 16#643#, 16#627#]), "ar"),
           "public locale contains searches Arabic two-letter ligatures by"
           & " base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#626#, 16#631#, 16#643#, 16#627#, 16#638#, 16#645#]),
              UTF8 ([16#FC80#, 16#FD3B#]), "ar"),
           "public locale contains searches base Arabic text by two-letter"
           & " ligature keys");
   Assert (I18N.Locales.Equivalent
             (UTF8 ([16#FD50#, 16#FD58#, 16#FD80#, 16#FD92#,
                     16#FDBA#, 16#FDC7#, 16#FDF2#, 16#FDF3#,
                     16#FDF4#, 16#FDF9#]),
              UTF8 ([16#62A#, 16#62C#, 16#645#,
                     16#62C#, 16#645#, 16#62D#,
                     16#644#, 16#62D#, 16#645#,
                     16#645#, 16#62C#, 16#62E#,
                     16#644#, 16#62C#, 16#645#,
                     16#646#, 16#62C#, 16#64A#,
                     16#627#, 16#644#, 16#644#, 16#647#,
                     16#627#, 16#643#, 16#628#, 16#631#,
                     16#645#, 16#62D#, 16#645#, 16#62F#,
                     16#635#, 16#644#, 16#649#]), "ar"),
           "public locale equivalence folds Arabic presentation forms-A"
           & " multi-letter ligatures");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#FD50#, 16#FD80#, 16#FDF2#, 16#FDF9#]),
              UTF8 ([16#644#, 16#62D#, 16#645#,
                     16#627#, 16#644#, 16#644#, 16#647#]), "ar"),
           "public locale contains searches Arabic multi-letter ligatures by"
           & " base keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#644#, 16#62D#, 16#645#,
                     16#627#, 16#644#, 16#644#, 16#647#,
                     16#635#, 16#644#, 16#649#]),
              UTF8 ([16#FD80#, 16#FDF2#, 16#FDF9#]), "ar"),
           "public locale contains searches base Arabic text by multi-letter"
           & " ligature keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#531#, 16#532#, 16#533#, 16#534#, 16#535#]),
              UTF8 ([16#562#, 16#563#]), "hy"),
           "public locale contains searches bounded Armenian folded keys");
   Assert (I18N.Locales.Contains
             (UTF8 ([16#12A0#, 16#121B#, 16#122D#, 16#1362#])
              & UTF8 ([16#1230#, 16#1208#]),
              UTF8 ([16#1230#, 16#1208#]), "am"),
           "public locale contains searches bounded Ethiopic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1401#) & U (16#1402#) & " "
              & U (16#167F#),
              U (16#1402#) & " " & U (16#167F#), "iu"),
           "public locale contains searches bounded Canadian syllabics byte keys");
   Assert (I18N.Locales.Contains
             (U (16#2D30#) & U (16#2D31#) & " "
              & U (16#2D67#),
              U (16#2D31#) & " " & U (16#2D67#), "tzm"),
           "public locale contains searches bounded Tifinagh byte keys");
   Assert (I18N.Locales.Contains
             (U (16#13A0#) & U (16#13A1#) & " "
              & U (16#13FF#),
              U (16#13A1#) & " " & U (16#13FF#), "chr"),
           "public locale contains searches bounded Cherokee byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1900#) & U (16#1920#) & " "
              & U (16#191E#),
              U (16#1920#) & " " & U (16#191E#), "lif"),
           "public locale contains searches bounded Limbu byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1950#) & U (16#1974#) & " "
              & U (16#1951#),
              U (16#1974#) & " " & U (16#1951#), "tdd"),
           "public locale contains searches bounded Tai Le byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1980#) & U (16#19C8#) & " "
              & U (16#19DA#),
              U (16#19C8#) & " " & U (16#19DA#), "khb"),
           "public locale contains searches bounded New Tai Lue byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1A00#) & U (16#1A17#) & " "
              & U (16#1A16#),
              U (16#1A17#) & " " & U (16#1A16#), "bug"),
           "public locale contains searches bounded Buginese byte keys");
   Assert (I18N.Locales.Contains
             (U (16#A90A#) & U (16#A926#) & " "
              & U (16#A925#),
              U (16#A926#) & " " & U (16#A925#), "kyu"),
           "public locale contains searches bounded Kayah Li byte keys");
   Assert (I18N.Locales.Contains
             (U (16#A930#) & U (16#A947#) & " "
              & U (16#A953#),
              U (16#A947#) & " " & U (16#A953#), "rej"),
           "public locale contains searches bounded Rejang byte keys");
   Assert (I18N.Locales.Contains
             (U (16#A984#) & U (16#A9B3#) & " "
              & U (16#A9CF#),
              U (16#A9B3#) & " " & U (16#A9CF#), "jv"),
           "public locale contains searches bounded Javanese byte keys");
   Assert (I18N.Locales.Contains
             (U (16#AA00#) & U (16#AA29#) & " "
              & U (16#AA4D#),
              U (16#AA29#) & " " & U (16#AA4D#), "cjm"),
           "public locale contains searches bounded Cham byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1A20#) & U (16#1A55#) & " "
              & U (16#1AA7#),
              U (16#1A55#) & " " & U (16#1AA7#), "nod"),
           "public locale contains searches bounded Tai Tham byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1B05#) & U (16#1B35#) & " "
              & U (16#1B44#),
              U (16#1B35#) & " " & U (16#1B44#), "ban"),
           "public locale contains searches bounded Balinese byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1B83#) & U (16#1BA0#) & " "
              & U (16#1BB5#),
              U (16#1BA0#) & " " & U (16#1BB5#), "su"),
           "public locale contains searches bounded Sundanese byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1C00#) & U (16#1C2C#) & " "
              & U (16#1C4D#),
              U (16#1C2C#) & " " & U (16#1C4D#), "lep"),
           "public locale contains searches bounded Lepcha byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1C5A#) & U (16#1C7D#) & " "
              & U (16#1C59#),
              U (16#1C7D#) & " " & U (16#1C59#), "sat"),
           "public locale contains searches bounded Ol Chiki byte keys");
   Assert (I18N.Locales.Contains
             (U (16#A500#) & U (16#A610#) & " "
              & U (16#A62A#),
              U (16#A610#) & " " & U (16#A62A#), "vai"),
           "public locale contains searches bounded Vai byte keys");
   Assert (I18N.Locales.Contains
             (U (16#A882#) & U (16#A8C4#) & " "
              & U (16#A8D4#),
              U (16#A8C4#) & " " & U (16#A8D4#), "saz"),
           "public locale contains searches bounded Saurashtra byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11005#) & U (16#11046#) & " "
              & U (16#1107F#),
              U (16#11046#) & " " & U (16#1107F#), "brh"),
           "public locale contains searches bounded Brahmi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11083#) & U (16#110B0#) & " "
              & U (16#110C2#),
              U (16#110B0#) & " " & U (16#110C2#), "kht"),
           "public locale contains searches bounded Kaithi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#110D0#) & U (16#110E8#) & " "
              & U (16#110F4#),
              U (16#110E8#) & " " & U (16#110F4#), "srb"),
           "public locale contains searches bounded Sora Sompeng byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11103#) & U (16#11134#) & " "
              & U (16#11144#),
              U (16#11134#) & " " & U (16#11144#), "ccp"),
           "public locale contains searches bounded Chakma byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11183#) & U (16#111C4#) & " "
              & U (16#111DC#),
              U (16#111C4#) & " " & U (16#111DC#), "sa-Shrd"),
           "public locale contains searches bounded Sharada byte keys");
   Assert (I18N.Locales.Contains
             (U (16#112B0#) & U (16#112EA#) & " "
              & U (16#112F4#),
              U (16#112EA#) & " " & U (16#112F4#), "sd-Sind"),
           "public locale contains searches bounded Khudawadi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11400#) & U (16#1144A#) & " "
              & U (16#1145E#),
              U (16#1144A#) & " " & U (16#1145E#), "new"),
           "public locale contains searches bounded Newa byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11480#) & U (16#114C5#) & " "
              & U (16#114C7#),
              U (16#114C5#) & " " & U (16#114C7#), "mai-Tirh"),
           "public locale contains searches bounded Tirhuta byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11600#) & U (16#11640#) & " "
              & U (16#11644#),
              U (16#11640#) & " " & U (16#11644#), "mr-Modi"),
           "public locale contains searches bounded Modi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11680#) & U (16#116B8#) & " "
              & U (16#116C4#),
              U (16#116B8#) & " " & U (16#116C4#), "doi-Takr"),
           "public locale contains searches bounded Takri byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11700#) & U (16#1172B#) & " "
              & U (16#11740#),
              U (16#1172B#) & " " & U (16#11740#), "aho"),
           "public locale contains searches bounded Ahom byte keys");
   Assert (I18N.Locales.Contains
             (U (16#118A0#) & U (16#118F2#) & " "
              & U (16#118FF#),
              U (16#118F2#) & " " & U (16#118FF#), "hoc-Wara"),
           "public locale contains searches bounded Warang Citi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11AC0#) & U (16#11AF8#) & " "
              & U (16#11AC1#),
              U (16#11AF8#) & " " & U (16#11AC1#), "ctd-Pauc"),
           "public locale contains searches bounded Pau Cin Hau byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11C00#) & U (16#11C40#) & " "
              & U (16#11C50#),
              U (16#11C40#) & " " & U (16#11C50#), "sa-Bhks"),
           "public locale contains searches bounded Bhaiksuki byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11C72#) & U (16#11CB6#) & " "
              & U (16#11C8F#),
              U (16#11CB6#) & " " & U (16#11C8F#), "bo-Marc"),
           "public locale contains searches bounded Marchen byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11D00#) & U (16#11D47#) & " "
              & U (16#11D54#),
              U (16#11D47#) & " " & U (16#11D54#), "gon-Gonm"),
           "public locale contains searches bounded Masaram Gondi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11D60#) & U (16#11D98#) & " "
              & U (16#11DA4#),
              U (16#11D98#) & " " & U (16#11DA4#), "gon-Gong"),
           "public locale contains searches bounded Gunjala Gondi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11DB0#) & U (16#11DDB#) & " "
              & U (16#11DE8#),
              U (16#11DDB#) & " " & U (16#11DE8#), "tsg-Tols"),
           "public locale contains searches bounded Tolong Siki byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11EE0#) & U (16#11EF6#) & " "
              & U (16#11EE1#),
              U (16#11EF6#) & " " & U (16#11EE1#), "mak-Maka"),
           "public locale contains searches bounded Makasar byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11200#) & U (16#11241#) & " "
              & U (16#11213#),
              U (16#11241#) & " " & U (16#11213#), "sd-Khoj"),
           "public locale contains searches bounded Khojki byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11280#) & U (16#112A8#) & " "
              & U (16#1128F#),
              U (16#112A8#) & " " & U (16#1128F#), "skr-Mult"),
           "public locale contains searches bounded Multani byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11305#) & U (16#11374#) & " "
              & U (16#11350#),
              U (16#11374#) & " " & U (16#11350#), "sa-Gran"),
           "public locale contains searches bounded Grantha byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11580#) & U (16#115DD#) & " "
              & U (16#115B5#),
              U (16#115DD#) & " " & U (16#115B5#), "sa-Sidd"),
           "public locale contains searches bounded Siddham byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11800#) & U (16#1183A#) & " "
              & U (16#11801#),
              U (16#1183A#) & " " & U (16#11801#), "doi-Dogr"),
           "public locale contains searches bounded Dogra byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11900#) & U (16#11943#) & " "
              & U (16#11954#),
              U (16#11943#) & " " & U (16#11954#), "dv-Diak"),
           "public locale contains searches bounded Dives Akuru byte keys");
   Assert (I18N.Locales.Contains
             (U (16#119A0#) & U (16#119E4#) & " "
              & U (16#119AA#),
              U (16#119E4#) & " " & U (16#119AA#), "sa-Nand"),
           "public locale contains searches bounded Nandinagari byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11A00#) & U (16#11A47#) & " "
              & U (16#11A3E#),
              U (16#11A47#) & " " & U (16#11A3E#), "mn-Zanb"),
           "public locale contains searches bounded Zanabazar Square byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11A50#) & U (16#11A9D#) & " "
              & U (16#11A99#),
              U (16#11A9D#) & " " & U (16#11A99#), "mn-Soyo"),
           "public locale contains searches bounded Soyombo byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10D00#) & U (16#10D27#) & " "
              & U (16#10D34#),
              U (16#10D27#) & " " & U (16#10D34#), "rhg-Rohg"),
           "public locale contains searches bounded Hanifi Rohingya byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10D50#) & U (16#10D85#) & " "
              & U (16#10D42#),
              U (16#10D85#) & " " & U (16#10D42#), "wo-Gara"),
           "public locale contains searches bounded Garay byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10F00#) & U (16#10F27#) & " "
              & U (16#10F30#),
              U (16#10F27#) & " " & U (16#10F30#), "sog-Sogo"),
           "public locale contains searches bounded Old Sogdian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10F30#) & U (16#10F54#) & " "
              & U (16#10F40#),
              U (16#10F54#) & " " & U (16#10F40#), "sog-Sogd"),
           "public locale contains searches bounded Sogdian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10FE0#) & U (16#10FF6#) & " "
              & U (16#10FE1#),
              U (16#10FF6#) & " " & U (16#10FE1#), "arc-Elym"),
           "public locale contains searches bounded Elymaic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11F00#) & U (16#11F42#) & " "
              & U (16#11F54#),
              U (16#11F42#) & " " & U (16#11F54#), "kaw"),
           "public locale contains searches bounded Kawi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11380#) & U (16#113D3#) & " "
              & U (16#113E2#),
              U (16#113D3#) & " " & U (16#113E2#), "tcy-Tutg"),
           "public locale contains searches bounded Tulu-Tigalari byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16100#) & U (16#1612F#) & " "
              & U (16#16135#),
              U (16#1612F#) & " " & U (16#16135#), "gvr-Gukh"),
           "public locale contains searches bounded Gurung Khema byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16E40#) & U (16#16E96#) & " "
              & U (16#16E41#),
              U (16#16E96#) & " " & U (16#16E41#), "dmf-Medf"),
           "public locale contains searches bounded Medefaidrin byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16EA0#) & U (16#16ED3#) & " "
              & U (16#16EA1#),
              U (16#16ED3#) & " " & U (16#16EA1#), "zag-Beri"),
           "public locale contains searches bounded Beria Erfe byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16D43#) & U (16#16D6D#) & " "
              & U (16#16D75#),
              U (16#16D6D#) & " " & U (16#16D75#), "rai-Krai"),
           "public locale contains searches bounded Kirat Rai byte keys");
   Assert (I18N.Locales.Contains
             (U (16#11BC0#) & U (16#11BE0#) & " "
              & U (16#11BF8#),
              U (16#11BE0#) & " " & U (16#11BF8#), "suz-Sunu"),
           "public locale contains searches bounded Sunuwar byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1E5D0#) & U (16#1E5F0#) & " "
              & U (16#1E5F8#),
              U (16#1E5F0#) & " " & U (16#1E5F8#), "unr-Onao"),
           "public locale contains searches bounded Ol Onal byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1E6C0#) & U (16#1E6F5#) & " "
              & U (16#1E6C1#),
              U (16#1E6F5#) & " " & U (16#1E6C1#), "tai-Tayo"),
           "public locale contains searches bounded Tai Yo byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1E900#) & U (16#1E94B#) & " "
              & U (16#1E954#),
              U (16#1E94B#) & " " & U (16#1E954#), "ff-Adlm"),
           "public locale contains searches bounded Adlam byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10570#) & U (16#105BC#) & " "
              & U (16#10571#),
              U (16#105BC#) & " " & U (16#10571#), "sq-Vith"),
           "public locale contains searches bounded Vithkuqi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#105C0#) & U (16#105F3#) & " "
              & U (16#105C1#),
              U (16#105F3#) & " " & U (16#105C1#), "sq-Todr"),
           "public locale contains searches bounded Todhri byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10E80#) & U (16#10EB1#) & " "
              & U (16#10E81#),
              U (16#10EB1#) & " " & U (16#10E81#), "ku-Yezi"),
           "public locale contains searches bounded Yezidi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10F70#) & U (16#10F89#) & " "
              & U (16#10F71#),
              U (16#10F89#) & " " & U (16#10F71#), "oui-Ougr"),
           "public locale contains searches bounded Old Uyghur byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10FB0#) & U (16#10FCB#) & " "
              & U (16#10FB1#),
              U (16#10FCB#) & " " & U (16#10FB1#), "xco-Chrs"),
           "public locale contains searches bounded Chorasmian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10000#) & U (16#1005D#) & " "
              & U (16#100FA#),
              U (16#1005D#) & " " & U (16#100FA#), "gmy-Linb"),
           "public locale contains searches bounded Linear B byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10107#) & U (16#10133#) & " "
              & U (16#1013F#),
              U (16#10133#) & " " & U (16#1013F#), "gmy-Linb"),
           "public locale contains searches bounded Aegean number byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10280#) & U (16#1029C#) & " "
              & U (16#10281#),
              U (16#1029C#) & " " & U (16#10281#), "xlc-Lyci"),
           "public locale contains searches bounded Lycian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#102A0#) & U (16#102D0#) & " "
              & U (16#102A1#),
              U (16#102D0#) & " " & U (16#102A1#), "xcr-Cari"),
           "public locale contains searches bounded Carian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10300#) & U (16#1032F#) & " "
              & U (16#10301#),
              U (16#1032F#) & " " & U (16#10301#), "ett-Ital"),
           "public locale contains searches bounded Old Italic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10330#) & U (16#1034A#) & " "
              & U (16#10331#),
              U (16#1034A#) & " " & U (16#10331#), "got-Goth"),
           "public locale contains searches bounded Gothic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10350#) & U (16#1037A#) & " "
              & U (16#10351#),
              U (16#1037A#) & " " & U (16#10351#), "kv-Perm"),
           "public locale contains searches bounded Old Permic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10380#) & U (16#1039D#) & " "
              & U (16#10381#),
              U (16#1039D#) & " " & U (16#10381#), "uga-Ugar"),
           "public locale contains searches bounded Ugaritic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#103A0#) & U (16#103CF#) & " "
              & U (16#103D5#),
              U (16#103CF#) & " " & U (16#103D5#), "peo-Xpeo"),
           "public locale contains searches bounded Old Persian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10400#) & U (16#1044F#) & " "
              & U (16#10401#),
              U (16#1044F#) & " " & U (16#10401#), "en-Dsrt"),
           "public locale contains searches bounded Deseret byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10450#) & U (16#1047F#) & " "
              & U (16#10451#),
              U (16#1047F#) & " " & U (16#10451#), "en-Shaw"),
           "public locale contains searches bounded Shavian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10480#) & U (16#1049D#) & " "
              & U (16#104A4#),
              U (16#1049D#) & " " & U (16#104A4#), "so-Osma"),
           "public locale contains searches bounded Osmanya byte keys");
   Assert (I18N.Locales.Contains
             (U (16#104B0#) & U (16#104D3#) & " "
              & U (16#104FB#),
              U (16#104D3#) & " " & U (16#104FB#), "osa-Osge"),
           "public locale contains searches bounded Osage byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10500#) & U (16#10527#) & " "
              & U (16#10501#),
              U (16#10527#) & " " & U (16#10501#), "sq-Elba"),
           "public locale contains searches bounded Elbasan byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10530#) & U (16#10563#) & " "
              & U (16#10531#),
              U (16#10563#) & " " & U (16#10531#), "agw-Aghb"),
           "public locale contains searches bounded Caucasian Albanian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10800#) & U (16#1083F#) & " "
              & U (16#10801#),
              U (16#1083F#) & " " & U (16#10801#), "grc-Cprt"),
           "public locale contains searches bounded Cypriot byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10840#) & U (16#10855#) & " "
              & U (16#1085F#),
              U (16#10855#) & " " & U (16#1085F#), "arc-Armi"),
           "public locale contains searches bounded Imperial Aramaic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10860#) & U (16#10876#) & " "
              & U (16#1087F#),
              U (16#10876#) & " " & U (16#1087F#), "arc-Palm"),
           "public locale contains searches bounded Palmyrene byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10900#) & U (16#1091B#) & " "
              & U (16#10901#),
              U (16#1091B#) & " " & U (16#10901#), "phn-Phnx"),
           "public locale contains searches bounded Phoenician byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10920#) & U (16#10939#) & " "
              & U (16#10921#),
              U (16#10939#) & " " & U (16#10921#), "xld-Lydi"),
           "public locale contains searches bounded Lydian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10940#) & U (16#10959#) & " "
              & U (16#10941#),
              U (16#10959#) & " " & U (16#10941#), "xsd-Sidt"),
           "public locale contains searches bounded Sidetic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10980#) & U (16#1099F#) & " "
              & U (16#10981#),
              U (16#1099F#) & " " & U (16#10981#), "xmr-Mero"),
           "public locale contains searches bounded Meroitic Hieroglyph byte keys");
   Assert (I18N.Locales.Contains
             (U (16#109A0#) & U (16#109B7#) & " "
              & U (16#109FF#),
              U (16#109B7#) & " " & U (16#109FF#), "xmr-Merc"),
           "public locale contains searches bounded Meroitic Cursive byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10880#) & U (16#1089E#) & " "
              & U (16#108AF#),
              U (16#1089E#) & " " & U (16#108AF#), "arc-Nbat"),
           "public locale contains searches bounded Nabataean byte keys");
   Assert (I18N.Locales.Contains
             (U (16#108E0#) & U (16#108F5#) & " "
              & U (16#108FF#),
              U (16#108F5#) & " " & U (16#108FF#), "arc-Hatr"),
           "public locale contains searches bounded Hatran byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10A00#) & U (16#10A35#) & " "
              & U (16#10A48#),
              U (16#10A35#) & " " & U (16#10A48#), "pra-Khar"),
           "public locale contains searches bounded Kharoshthi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10A60#) & U (16#10A7C#) & " "
              & U (16#10A7F#),
              U (16#10A7C#) & " " & U (16#10A7F#), "xsa-Sarb"),
           "public locale contains searches bounded Old South Arabian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10A80#) & U (16#10A9C#) & " "
              & U (16#10A9F#),
              U (16#10A9C#) & " " & U (16#10A9F#), "xna-Narb"),
           "public locale contains searches bounded Old North Arabian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10AC0#) & U (16#10AE6#) & " "
              & U (16#10AEF#),
              U (16#10AE6#) & " " & U (16#10AEF#), "xmn-Mani"),
           "public locale contains searches bounded Manichaean byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10B00#) & U (16#10B35#) & " "
              & U (16#10B01#),
              U (16#10B35#) & " " & U (16#10B01#), "ae-Avst"),
           "public locale contains searches bounded Avestan byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10B40#) & U (16#10B55#) & " "
              & U (16#10B5F#),
              U (16#10B55#) & " " & U (16#10B5F#), "xpr-Prti"),
           "public locale contains searches bounded Inscriptional Parthian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10B60#) & U (16#10B72#) & " "
              & U (16#10B7F#),
              U (16#10B72#) & " " & U (16#10B7F#), "pal-Phli"),
           "public locale contains searches bounded Inscriptional Pahlavi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10B80#) & U (16#10B91#) & " "
              & U (16#10BAF#),
              U (16#10B91#) & " " & U (16#10BAF#), "pal-Phlp"),
           "public locale contains searches bounded Psalter Pahlavi byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10C00#) & U (16#10C48#) & " "
              & U (16#10C01#),
              U (16#10C48#) & " " & U (16#10C01#), "otk-Orkh"),
           "public locale contains searches bounded Old Turkic byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10C80#) & U (16#10CB2#) & " "
              & U (16#10CFF#),
              U (16#10CB2#) & " " & U (16#10CFF#), "hu-Hung"),
           "public locale contains searches bounded Old Hungarian byte keys");
   Assert (I18N.Locales.Contains
             (U (16#10E60#) & U (16#10E7E#) & " "
              & U (16#10E61#),
              U (16#10E7E#) & " " & U (16#10E61#), "ar-Rumi"),
           "public locale contains searches bounded Rumi numeral byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16A70#) & U (16#16ABE#) & " "
              & U (16#16AC4#),
              U (16#16ABE#) & " " & U (16#16AC4#), "nst-Tnsa"),
           "public locale contains searches bounded Tangsa byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1E290#) & U (16#1E2AE#) & " "
              & U (16#1E291#),
              U (16#1E2AE#) & " " & U (16#1E291#), "txo-Toto"),
           "public locale contains searches bounded Toto byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1E4D0#) & U (16#1E4EB#) & " "
              & U (16#1E4F4#),
              U (16#1E4EB#) & " " & U (16#1E4F4#), "unr-Nagm"),
           "public locale contains searches bounded Nag Mundari byte keys");
   Assert (I18N.Locales.Contains
             (U (16#12000#) & U (16#1246E#) & " "
              & U (16#12543#),
              U (16#1246E#) & " " & U (16#12543#), "akk-Xsux"),
           "public locale contains searches bounded Cuneiform byte keys");
   Assert (I18N.Locales.Contains
             (U (16#13000#) & U (16#1342E#) & " "
              & U (16#13001#),
              U (16#1342E#) & " " & U (16#13001#), "egy-Egyp"),
           "public locale contains searches bounded Egyptian Hieroglyph byte keys");
   Assert (I18N.Locales.Contains
             (U (16#14400#) & U (16#14646#) & " "
              & U (16#14401#),
              U (16#14646#) & " " & U (16#14401#), "hlu-Hluw"),
           "public locale contains searches bounded Anatolian Hieroglyph byte keys");
   Assert (I18N.Locales.Contains
             (U (16#16800#) & U (16#16A38#) & " "
              & U (16#16801#),
              U (16#16A38#) & " " & U (16#16801#), "bax-Bamu"),
           "public locale contains searches bounded Bamum Supplement byte keys");
   Assert (I18N.Locales.Contains
             (U (16#17000#) & U (16#187FB#) & " "
              & U (16#18D1E#),
              U (16#187FB#) & " " & U (16#18D1E#), "txg-Tang"),
           "public locale contains searches bounded Tangut byte keys");
   Assert (I18N.Locales.Contains
             (U (16#18B00#) & U (16#18CD5#) & " "
              & U (16#18CFF#),
              U (16#18CD5#) & " " & U (16#18CFF#), "zkt-Kits"),
           "public locale contains searches bounded Khitan byte keys");
   Assert (I18N.Locales.Contains
             (U (16#1B170#) & U (16#1B2FB#) & " "
              & U (16#1B171#),
              U (16#1B2FB#) & " " & U (16#1B171#), "zh-Nshu"),
           "public locale contains searches bounded Nushu byte keys");
   Assert (not I18N.Locales.Equivalent
             (UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5DD#]),
              UTF8 ([16#5E1#, 16#5E4#, 16#5E8#]), "he"),
           "public locale equivalence distinguishes Hebrew byte keys");
   Assert (not I18N.Locales.Equivalent
             (UTF8 ([16#633#, 16#644#, 16#627#, 16#645#]),
              UTF8 ([16#643#, 16#644#, 16#628#]), "ar"),
           "public locale equivalence distinguishes Arabic byte keys");
   Assert (I18N.Locales.Contains ("abc", "", "en"),
           "public locale contains treats an empty pattern as present");
   Assert (not I18N.Locales.Contains ("resume", "zoo", "en"),
           "public locale contains reports absent patterns");
   Assert (I18N.Locales.Grapheme_Count
             ("Cafe" & U (16#301#), "en") = 4,
           "public locale grapheme count keeps combining marks with base");
   Assert (I18N.Locales.Grapheme_At
             ("Cafe" & U (16#301#), 4, "en") =
             "e" & U (16#301#),
           "public locale grapheme access preserves decomposed cluster bytes");
   Assert (I18N.Locales.Grapheme_Count
             ("a" & U (16#1AB0#) & "b" & U (16#1AFF#), "en") = 2,
           "public locale grapheme count keeps extended combining marks with base");
   Assert (I18N.Locales.Grapheme_At
             ("a" & U (16#1AB0#) & "b" & U (16#1AFF#), 2, "en") =
             "b" & U (16#1AFF#),
           "public locale grapheme access preserves extended combining mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             ("a" & U (16#1DC0#) & "b" & U (16#1DFF#), "en") = 2,
           "public locale grapheme count keeps supplement combining marks with base");
   Assert (I18N.Locales.Grapheme_At
             ("a" & U (16#1DC0#) & "b" & U (16#1DFF#), 1, "en") =
             "a" & U (16#1DC0#),
           "public locale grapheme access preserves supplement combining mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             ("a" & U (16#20D0#) & "b" & U (16#20FF#), "en") = 2,
           "public locale grapheme count keeps symbol combining marks with base");
   Assert (I18N.Locales.Grapheme_At
             ("a" & U (16#20D0#) & "b" & U (16#20FF#), 2, "en") =
             "b" & U (16#20FF#),
           "public locale grapheme access preserves symbol combining mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             ("a" & U (16#FE20#) & "b" & U (16#FE2F#), "en") = 2,
           "public locale grapheme count keeps half combining marks with base");
   Assert (I18N.Locales.Grapheme_At
             ("a" & U (16#FE20#) & "b" & U (16#FE2F#), 1, "en") =
             "a" & U (16#FE20#),
           "public locale grapheme access preserves half combining mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#5E9#) & U (16#5B8#)
              & U (16#5DC#) & U (16#5BC#), "he") = 2,
           "public locale grapheme count keeps Hebrew marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#5E9#) & U (16#5B8#)
              & U (16#5DC#) & U (16#5BC#), 2, "he") =
             U (16#5DC#) & U (16#5BC#),
           "public locale grapheme access preserves Hebrew mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#712#) & U (16#711#) & U (16#730#)
              & U (16#713#) & U (16#74A#), "syr") = 2,
           "public locale grapheme count keeps Syriac marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#712#) & U (16#711#) & U (16#730#)
              & U (16#713#) & U (16#74A#), 1, "syr") =
             U (16#712#) & U (16#711#) & U (16#730#),
           "public locale grapheme access preserves Syriac mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#786#) & U (16#7A6#)
              & U (16#787#) & U (16#7B0#), "dv") = 2,
           "public locale grapheme count keeps Thaana marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#786#) & U (16#7A6#)
              & U (16#787#) & U (16#7B0#), 2, "dv") =
             U (16#787#) & U (16#7B0#),
           "public locale grapheme access preserves Thaana mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#7CA#) & U (16#7EB#)
              & U (16#7CB#) & U (16#7F3#), "nqo") = 2,
           "public locale grapheme count keeps NKo marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#7CA#) & U (16#7EB#)
              & U (16#7CB#) & U (16#7F3#), 1, "nqo") =
             U (16#7CA#) & U (16#7EB#),
           "public locale grapheme access preserves NKo mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#800#) & U (16#816#)
              & U (16#801#) & U (16#82D#), "sam") = 2,
           "public locale grapheme count keeps Samaritan marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#800#) & U (16#816#)
              & U (16#801#) & U (16#82D#), 2, "sam") =
             U (16#801#) & U (16#82D#),
           "public locale grapheme access preserves Samaritan mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (U (16#840#) & U (16#859#)
              & U (16#841#) & U (16#85B#), "mid") = 2,
           "public locale grapheme count keeps Mandaic marks with base");
   Assert (I18N.Locales.Grapheme_At
             (U (16#840#) & U (16#859#)
              & U (16#841#) & U (16#85B#), 1, "mid") =
             U (16#840#) & U (16#859#),
           "public locale grapheme access preserves Mandaic mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#915#, 16#93E#]) & "!", "hi") = 2,
           "public locale grapheme count keeps Devanagari vowel signs");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#915#, 16#93E#]) & "!", 1, "hi") =
              UTF8 ([16#915#, 16#93E#]),
           "public locale grapheme access preserves Devanagari mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#995#, 16#9C0#]) & "!", "bn") = 2,
           "public locale grapheme count keeps Bengali vowel signs");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#995#, 16#9C0#]) & "!", 1, "bn") =
              UTF8 ([16#995#, 16#9C0#]),
           "public locale grapheme access preserves Bengali mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#E01#, 16#E48#]) & "!", "th") = 2,
           "public locale grapheme count keeps Thai tone marks");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#E01#, 16#E48#]) & "!", 1, "th") =
              UTF8 ([16#E01#, 16#E48#]),
           "public locale grapheme access preserves Thai mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0A15#, 16#0A3E#]) & "!", "pa") = 2,
           "public locale grapheme count keeps Gurmukhi vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0A95#, 16#0ABE#]) & "!", "gu") = 2,
           "public locale grapheme count keeps Gujarati vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0B15#, 16#0B3E#]) & "!", "or") = 2,
           "public locale grapheme count keeps Odia vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0B95#, 16#0BBE#]) & "!", "ta") = 2,
           "public locale grapheme count keeps Tamil vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0C15#, 16#0C3E#]) & "!", "te") = 2,
           "public locale grapheme count keeps Telugu vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0C95#, 16#0CBE#]) & "!", "kn") = 2,
           "public locale grapheme count keeps Kannada vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0D15#, 16#0D3E#]) & "!", "ml") = 2,
           "public locale grapheme count keeps Malayalam vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0D9A#, 16#0DCF#]) & "!", "si") = 2,
           "public locale grapheme count keeps Sinhala vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0E81#, 16#0EB2#]) & "!", "lo") = 2,
           "public locale grapheme count keeps Lao vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0F40#, 16#0F71#]) & "!", "bo") = 2,
           "public locale grapheme count keeps Tibetan vowel signs");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1780#, 16#17B6#]) & "!", "km") = 2,
           "public locale grapheme count keeps Khmer vowel signs");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1780#, 16#17B6#]) & "!", 1, "km") =
              UTF8 ([16#1780#, 16#17B6#]),
           "public locale grapheme access preserves Khmer mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#600#, 16#627#]) & "!", "ar") = 2,
           "public locale grapheme count applies bounded Prepend rules");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#600#, 16#627#]) & "!", 1, "ar") =
              UTF8 ([16#600#, 16#627#]),
           "public locale grapheme access preserves Prepend clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#110BD#, 16#110D0#]) & "!", "kthi") = 2,
           "public locale grapheme count applies supplementary Prepend rules");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#110BD#, 16#110D0#]) & "!", 1, "kthi") =
              UTF8 ([16#110BD#, 16#110D0#]),
           "public locale grapheme access preserves supplementary Prepend clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1000#, 16#102C#]) & "!", "my") = 2,
           "public locale grapheme count keeps Myanmar spacing marks");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1000#, 16#102C#]) & "!", 1, "my") =
              UTF8 ([16#1000#, 16#102C#]),
           "public locale grapheme access preserves Myanmar spacing-mark clusters");
   Assert (I18N.Locales.Grapheme_Count
             ("a" & ASCII.CR & ASCII.LF & "b", "en") = 3,
           "public locale grapheme count treats CRLF as one cluster");
   Assert (I18N.Locales.Grapheme_At
             ("a" & ASCII.CR & ASCII.LF & "b", 2, "en") =
             ASCII.CR & ASCII.LF,
           "public locale grapheme access returns CRLF as one cluster");
   Assert (I18N.Locales.Grapheme_Count
             (ASCII.LF & UTF8 ([16#0301#]) & "a", "en") = 3,
           "public locale grapheme count keeps LF as a control cluster");
   Assert (I18N.Locales.Grapheme_At
             (ASCII.LF & UTF8 ([16#0301#]) & "a", 1, "en") =
             String'(1 => ASCII.LF),
           "public locale grapheme access keeps LF standalone");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#0085#, 16#0301#]) & "a", "en") = 3,
           "public locale grapheme count keeps NEL as a control cluster");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#0085#, 16#0301#]) & "a", 1, "en") =
             UTF8 ([16#0085#]),
           "public locale grapheme access keeps NEL standalone");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#009F#, 16#0301#]) & "a", "en") = 3,
           "public locale grapheme count keeps C1 controls standalone");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#009F#, 16#0301#]) & "a", 1, "en") =
             UTF8 ([16#009F#]),
           "public locale grapheme access keeps C1 controls standalone");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#2764#, 16#FE0F#]) & "!", "en") = 2,
           "public locale grapheme count keeps variation selectors");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#4E00#, 16#E0100#]) & "!", "en") = 2,
           "public locale grapheme count keeps supplementary variation selectors");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#4E00#, 16#E01EF#]) & "!", 1, "en") =
             UTF8 ([16#4E00#, 16#E01EF#]),
           "public locale grapheme access preserves supplementary variation selectors");
   Assert (I18N.Locales.Grapheme_Count
             ("1" & UTF8 ([16#20E3#]) & "!", "en") = 2,
           "public locale grapheme count keeps keycap marks");
   Assert (I18N.Locales.Grapheme_At
             ("1" & UTF8 ([16#FE0F#, 16#20E3#]) & "!", 1, "en") =
             "1" & UTF8 ([16#FE0F#, 16#20E3#]),
           "public locale grapheme access preserves keycap sequences");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1F44D#, 16#1F3FB#]) & "!", "en") = 2,
           "public locale grapheme count keeps emoji modifiers");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F44D#, 16#1F3FB#]) & "!", 1, "en") =
             UTF8 ([16#1F44D#, 16#1F3FB#]),
           "public locale grapheme access preserves emoji modifier clusters");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1F1E9#, 16#1F1F0#]) & "!", "en") = 2,
           "public locale grapheme count keeps regional indicator pairs");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F1E9#, 16#1F1F0#, 16#1F1FA#]) & "!", 1,
              "en") =
             UTF8 ([16#1F1E9#, 16#1F1F0#]),
           "public locale grapheme access preserves regional indicator pairs");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F1E9#, 16#1F1F0#, 16#1F1FA#]) & "!", 2,
              "en") =
             UTF8 ([16#1F1FA#]),
           "public locale grapheme access leaves odd regional indicators");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1F3F4#, 16#E0067#, 16#E0062#, 16#E007F#])
              & "!", "en") = 2,
           "public locale grapheme count keeps emoji tag sequences");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F3F4#, 16#E0067#, 16#E0062#, 16#E007F#])
              & "!", 1, "en") =
             UTF8 ([16#1F3F4#, 16#E0067#, 16#E0062#, 16#E007F#]),
           "public locale grapheme access preserves emoji tag sequences");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F469#, 16#200D#, 16#1F4BB#]) & "!", 1,
              "en") =
             UTF8 ([16#1F469#, 16#200D#, 16#1F4BB#]),
           "public locale grapheme access keeps simple ZWJ sequences");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1F468#, 16#200D#, 16#1F469#, 16#200D#,
                     16#1F467#, 16#200D#, 16#1F466#]) & "!", "en") = 2,
           "public locale grapheme count keeps multi-code-point ZWJ sequences");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1F468#, 16#200D#, 16#1F469#, 16#200D#,
                     16#1F467#, 16#200D#, 16#1F466#]) & "!", 1,
              "en") =
             UTF8 ([16#1F468#, 16#200D#, 16#1F469#, 16#200D#,
                    16#1F467#, 16#200D#, 16#1F466#]),
           "public locale grapheme access preserves multi-code-point ZWJ sequences");
   Assert (I18N.Locales.Grapheme_Count
             (UTF8 ([16#1100#, 16#1161#, 16#11A8#]) & "!", "ko") = 2,
           "public locale grapheme count keeps bounded Hangul Jamo clusters");
   Assert (I18N.Locales.Grapheme_At
             (UTF8 ([16#1100#, 16#1161#, 16#11A8#]) & "!", 1, "ko") =
             UTF8 ([16#1100#, 16#1161#, 16#11A8#]),
           "public locale grapheme access preserves Hangul Jamo clusters");
   Assert (I18N.Locales.Grapheme_At ("abc", 0, "en") = "",
           "public locale grapheme access rejects zero indexes");
   Assert (I18N.Locales.Grapheme_At ("abc", 4, "en") = "",
           "public locale grapheme access returns empty for missing clusters");
   Assert (I18N.Locales.Line_Count
             ("one" & ASCII.LF & "two" & ASCII.CR & ASCII.LF
              & "three", "en") = 3,
           "public locale line count recognizes LF and CRLF breaks");
   Assert (I18N.Locales.Line_At
             ("one" & ASCII.LF & "two" & ASCII.CR & ASCII.LF
              & "three", 2, "en") =
             "two" & ASCII.CR & ASCII.LF,
           "public locale line access preserves CRLF bytes");
   Assert (I18N.Locales.Line_Count
             ("a" & UTF8 ([16#2028#]) & "b" & UTF8 ([16#2029#]),
              "en") = 2,
           "public locale line count recognizes Unicode line separators");
   Assert (I18N.Locales.Line_At
             ("a" & UTF8 ([16#2028#]) & "b" & UTF8 ([16#2029#]),
              1, "en") =
             "a" & UTF8 ([16#2028#]),
           "public locale line access preserves Unicode line separator bytes");
   Assert (I18N.Locales.Line_Count
             ("a" & UTF8 ([16#85#]) & "b", "en") = 2,
           "public locale line count recognizes Unicode NEL breaks");
   Assert (I18N.Locales.Line_At
             ("a" & UTF8 ([16#85#]) & "b", 1, "en") =
             "a" & UTF8 ([16#85#]),
           "public locale line access preserves Unicode NEL bytes");
   Assert (I18N.Locales.Line_Count
             ("a" & ASCII.FF & "b", "en") = 2,
           "public locale line count recognizes form feed breaks");
   Assert (I18N.Locales.Line_At
             ("a" & ASCII.FF & "b", 1, "en") =
             "a" & ASCII.FF,
           "public locale line access preserves form feed bytes");
   Assert (I18N.Locales.Line_Count
             ("a" & Character'Val (11) & "b", "en") = 2,
           "public locale line count recognizes vertical tab breaks");
   Assert (I18N.Locales.Line_At
             ("a" & Character'Val (11) & "b", 1, "en") =
             "a" & Character'Val (11),
           "public locale line access preserves vertical tab bytes");
   Assert (I18N.Locales.Line_Count ("a" & ASCII.LF, "en") = 1,
           "public locale line count ignores final trailing empty line");
   Assert (I18N.Locales.Line_At ("abc", 0, "en") = "",
           "public locale line access rejects zero indexes");
   Assert (I18N.Locales.Line_At ("abc", 2, "en") = "",
           "public locale line access returns empty for missing lines");
   Assert (I18N.Locales.Sentence_Count
             ("Hello world!  Next sentence. Tail", "en") = 3,
           "public locale sentence count splits bounded ASCII terminators");
   Assert (I18N.Locales.Sentence_At
             ("Hello world!  Next sentence. Tail", 2, "en") =
             "Next sentence.",
           "public locale sentence access skips separator whitespace");
   Assert (I18N.Locales.Sentence_At
             ("First." & UTF8 ([16#2028#]) & "Second.", 2, "en") =
             "Second.",
           "public locale sentence access skips Unicode line separators");
   Assert (I18N.Locales.Sentence_At
             ("First." & UTF8 ([16#2029#]) & "Second.", 2, "en") =
             "Second.",
           "public locale sentence access skips Unicode paragraph separators");
   Assert (I18N.Locales.Sentence_At
             ("First." & UTF8 ([16#A0#]) & "Second.", 2, "en") =
             "Second.",
           "public locale sentence access skips non-breaking spaces");
   Assert (I18N.Locales.Sentence_At
             ("First." & UTF8 ([16#3000#]) & "Second.", 2, "ja") =
             "Second.",
           "public locale sentence access skips ideographic spaces");
   Assert (I18N.Locales.Sentence_At
             ("First." & Character'Val (11) & "Second.", 2, "en") =
             "Second.",
           "public locale sentence access skips vertical tabs");
   Assert (I18N.Locales.Sentence_At
             ("He said " & Character'Val (34) & "go!" & Character'Val (34)
              & " Done.", 1, "en") =
             "He said " & Character'Val (34) & "go!" & Character'Val (34),
           "public locale sentence access keeps closing quotes");
   Assert (I18N.Locales.Sentence_Count
             ("Pi is 3.14. Next.", "en") = 2,
           "public locale sentence count keeps decimal periods inside numbers");
   Assert (I18N.Locales.Sentence_At
             ("Pi is 3.14. Next.", 1, "en") = "Pi is 3.14.",
           "public locale sentence access preserves decimal period text");
   Assert (I18N.Locales.Sentence_Count
             ("n=" & U (16#0661#) & "." & U (16#0662#) & ". Done.",
              "ar") = 2,
           "public locale sentence count keeps decimal periods between bounded digits");
   Assert (I18N.Locales.Sentence_Count
             ("n=" & U (16#FF11#) & "." & U (16#FF12#) & ". Done.",
              "ja") = 2,
           "public locale sentence count keeps decimal periods between fullwidth digits");
   Assert (I18N.Locales.Sentence_Count
             ("n=" & U (16#3007#) & "." & U (16#4E03#) & ". Done.",
              "zh") = 2,
           "public locale sentence count keeps decimal periods between Han decimal digits");
   Assert (I18N.Locales.Sentence_Count
             ("n=" & U (16#0AE7#) & "." & U (16#0AE8#) & ". Done.",
              "gu") = 2,
           "public locale sentence count keeps decimal periods between Gujarati digits");
   Assert (I18N.Locales.Sentence_Count
             ("n=" & U (16#17E1#) & "." & U (16#17E2#) & ". Done.",
              "km") = 2,
           "public locale sentence count keeps decimal periods between Khmer digits");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#645#, 16#631#, 16#62D#, 16#628#, 16#627#,
                     16#61F#])
              & " "
              & UTF8 ([16#646#, 16#639#, 16#645#]), "ar") = 2,
           "public locale sentence count recognizes Arabic question mark");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#65E5#, 16#672C#, 16#8A9E#, 16#3002#])
              & UTF8 ([16#4E2D#, 16#6587#]), 1, "ja") =
             UTF8 ([16#65E5#, 16#672C#, 16#8A9E#, 16#3002#]),
           "public locale sentence access recognizes CJK full stop");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#300C#, 16#65E5#, 16#672C#, 16#8A9E#,
                     16#3002#, 16#300D#])
              & UTF8 ([16#4E2D#, 16#6587#]), 1, "ja") =
             UTF8 ([16#300C#, 16#65E5#, 16#672C#, 16#8A9E#,
                    16#3002#, 16#300D#]),
           "public locale sentence access keeps CJK closing quotes");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#4E2D#, 16#6587#, 16#FF01#])
              & " "
              & UTF8 ([16#65E5#, 16#672C#, 16#8A9E#, 16#FF1F#]),
              "zh") = 2,
           "public locale sentence count recognizes fullwidth terminators");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#597D#, 16#FF01#, 16#FF09#]) & " Next.",
              1, "zh") =
              UTF8 ([16#597D#, 16#FF01#, 16#FF09#]),
           "public locale sentence access keeps fullwidth closing punctuation");
   Assert (I18N.Locales.Sentence_At
             ("Wait" & UTF8 ([16#2026#]) & " Done.", 1, "en") =
             "Wait" & UTF8 ([16#2026#]),
           "public locale sentence access recognizes Unicode ellipsis");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#3B3#, 16#3B9#, 16#3B1#]) & UTF8 ([16#37E#])
              & " "
              & UTF8 ([16#3BD#, 16#3B1#, 16#3B9#]), "el") = 2,
           "public locale sentence count recognizes Greek question mark");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#531#, 16#532#, 16#533#, 16#589#])
              & UTF8 ([16#534#, 16#535#]), 1, "hy") =
             UTF8 ([16#531#, 16#532#, 16#533#, 16#589#]),
           "public locale sentence access recognizes Armenian full stop");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5DD#, 16#5C3#])
              & " "
              & UTF8 ([16#5D4#, 16#591#]), "he") = 2,
           "public locale sentence count recognizes Hebrew sof pasuq");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#12A0#, 16#121B#, 16#122D#, 16#1362#])
              & " "
              & UTF8 ([16#1230#, 16#1208#]), "am") = 2,
           "public locale sentence count recognizes Ethiopic full stop");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#12A0#, 16#121B#, 16#122D#, 16#1367#])
              & " "
              & UTF8 ([16#1230#, 16#1208#]), "am") = 2,
           "public locale sentence count recognizes Ethiopic question mark");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#, 16#10FB#])
              & " "
              & UTF8 ([16#10DB#, 16#10D4#, 16#10DD#, 16#10E0#]),
              "ka") = 2,
           "public locale sentence count recognizes Georgian paragraph separator");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#, 16#10FB#])
              & UTF8 ([16#10DB#, 16#10D4#]), 1, "ka") =
              UTF8 ([16#10E1#, 16#10D0#, 16#10E5#, 16#10D0#,
                     16#10E0#, 16#10D7#, 16#10D5#, 16#10D4#,
                     16#10DA#, 16#10DD#, 16#10FB#]),
           "public locale sentence access keeps Georgian paragraph separator");
   Assert (I18N.Locales.Sentence_Count
             (UTF8 ([16#1019#, 16#103C#, 16#1014#, 16#103A#, 16#104B#])
              & " "
              & UTF8 ([16#1005#, 16#102C#]), "my") = 2,
           "public locale sentence count recognizes Myanmar section");
   Assert (I18N.Locales.Sentence_At
             (UTF8 ([16#1019#, 16#103C#, 16#1014#, 16#103A#, 16#104A#])
              & UTF8 ([16#1005#, 16#102C#]), 1, "my") =
              UTF8 ([16#1019#, 16#103C#, 16#1014#, 16#103A#, 16#104A#]),
           "public locale sentence access recognizes Myanmar little section");
   Assert (I18N.Locales.Sentence_At ("abc", 0, "en") = "",
           "public locale sentence access rejects zero indexes");
   Assert (I18N.Locales.Sentence_At ("abc", 2, "en") = "",
           "public locale sentence access returns empty for missing sentences");
   Assert (I18N.Locales.Word_Count
             ("Hello, R" & U (16#E9#) & "sum" & U (16#E9#)
              & " 42!", "en") = 3,
           "public locale word count segments ASCII and accented Latin words");
   Assert (I18N.Locales.Word_At
             ("Hello, R" & U (16#E9#) & "sum" & U (16#E9#)
              & " 42!", 2, "en") =
             "R" & U (16#E9#) & "sum" & U (16#E9#),
           "public locale word access preserves original UTF-8 bytes");
   Assert (I18N.Locales.Word_At
             ("Cafe" & U (16#301#) & " au lait", 1, "en") =
             "Cafe" & U (16#301#),
           "public locale word access keeps bounded combining marks");
   Assert (I18N.Locales.Word_At
             ("a" & U (16#1AB0#) & " b", 1, "en") =
             "a" & U (16#1AB0#),
           "public locale word access keeps extended combining marks");
   Assert (I18N.Locales.Word_At
             ("a" & U (16#1DC0#) & " b", 1, "en") =
             "a" & U (16#1DC0#),
           "public locale word access keeps supplement combining marks");
   Assert (I18N.Locales.Word_At
             ("a" & U (16#20D0#) & " b", 1, "en") =
             "a" & U (16#20D0#),
           "public locale word access keeps symbol combining marks");
   Assert (I18N.Locales.Word_At
             ("a" & U (16#FE20#) & " b", 1, "en") =
             "a" & U (16#FE20#),
           "public locale word access keeps half combining marks");
   Assert (I18N.Locales.Word_At
             (U (16#5E9#) & U (16#5B8#)
              & U (16#5DC#) & U (16#5D5#) & U (16#5BC#)
              & U (16#5DD#) & " !", 1, "he") =
             U (16#5E9#) & U (16#5B8#)
              & U (16#5DC#) & U (16#5D5#) & U (16#5BC#)
              & U (16#5DD#),
           "public locale word access keeps Hebrew combining marks");
   Assert (I18N.Locales.Word_At
             (U (16#712#) & U (16#711#) & U (16#730#)
              & U (16#713#) & U (16#74A#) & " !", 1, "syr") =
             U (16#712#) & U (16#711#) & U (16#730#)
              & U (16#713#) & U (16#74A#),
           "public locale word access keeps Syriac combining marks");
   Assert (I18N.Locales.Word_At
             (U (16#786#) & U (16#7A6#)
              & U (16#787#) & U (16#7B0#) & " !", 1, "dv") =
             U (16#786#) & U (16#7A6#)
              & U (16#787#) & U (16#7B0#),
           "public locale word access keeps Thaana combining marks");
   Assert (I18N.Locales.Word_At
             (U (16#7CA#) & U (16#7EB#)
              & U (16#7CB#) & U (16#7F3#)
              & U (16#7FA#) & " !", 1, "nqo") =
             U (16#7CA#) & U (16#7EB#)
              & U (16#7CB#) & U (16#7F3#)
              & U (16#7FA#),
           "public locale word access keeps NKo combining marks and signs");
   Assert (I18N.Locales.Word_At
             (U (16#800#) & U (16#816#)
              & U (16#801#) & U (16#82D#) & " !", 1, "sam") =
             U (16#800#) & U (16#816#)
              & U (16#801#) & U (16#82D#),
           "public locale word access keeps Samaritan combining marks");
   Assert (I18N.Locales.Word_At
             (U (16#840#) & U (16#859#)
              & U (16#858#) & U (16#85B#) & " !", 1, "mid") =
             U (16#840#) & U (16#859#)
              & U (16#858#) & U (16#85B#),
           "public locale word access keeps Mandaic combining marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1681#) & U (16#1682#) & U (16#1680#)
              & U (16#16A0#) & U (16#16F8#), "ga") = 2,
           "public locale word count recognizes bounded Ogham and Runic words");
   Assert (I18N.Locales.Word_At
             (U (16#1681#) & U (16#1682#) & U (16#1680#)
              & U (16#16A0#) & U (16#16F8#), 2, "ga") =
             U (16#16A0#) & U (16#16F8#),
           "public locale word access preserves bounded Runic words");
   Assert (I18N.Locales.Word_Count
             (U (16#1401#) & U (16#1402#) & " "
              & U (16#167F#), "iu") = 2,
           "public locale word count recognizes bounded Canadian syllabics words");
   Assert (I18N.Locales.Word_At
             (U (16#1401#) & U (16#1402#) & " "
              & U (16#167F#), 1, "iu") =
             U (16#1401#) & U (16#1402#),
           "public locale word access preserves bounded Canadian syllabics words");
   Assert (I18N.Locales.Word_Count
             (U (16#2D30#) & U (16#2D7F#) & U (16#2D70#)
              & U (16#2D67#), "tzm") = 2,
           "public locale word count recognizes bounded Tifinagh words");
   Assert (I18N.Locales.Word_At
             (U (16#2D30#) & U (16#2D7F#) & U (16#2D70#)
              & U (16#2D67#), 1, "tzm") =
             U (16#2D30#) & U (16#2D7F#),
           "public locale word access preserves bounded Tifinagh marks");
   Assert (I18N.Locales.Word_Count
             (U (16#13A0#) & U (16#13A1#) & " "
              & U (16#13FF#), "chr") = 2,
           "public locale word count recognizes bounded Cherokee words");
   Assert (I18N.Locales.Word_At
             (U (16#13A0#) & U (16#13A1#) & " "
              & U (16#13FF#), 2, "chr") =
             U (16#13FF#),
           "public locale word access preserves bounded Cherokee words");
   Assert (I18N.Locales.Word_Count
             (U (16#1900#) & U (16#1920#) & U (16#1944#)
              & U (16#191E#), "lif") = 2,
           "public locale word count recognizes bounded Limbu words");
   Assert (I18N.Locales.Word_At
             (U (16#1900#) & U (16#1920#) & U (16#1944#)
              & U (16#191E#), 1, "lif") =
             U (16#1900#) & U (16#1920#),
           "public locale word access preserves bounded Limbu marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1950#) & U (16#1974#) & " "
              & U (16#1951#), "tdd") = 2,
           "public locale word count recognizes bounded Tai Le words");
   Assert (I18N.Locales.Word_At
             (U (16#1950#) & U (16#1974#) & " "
              & U (16#1951#), 1, "tdd") =
             U (16#1950#) & U (16#1974#),
           "public locale word access preserves bounded Tai Le words");
   Assert (I18N.Locales.Word_Count
             (U (16#1980#) & U (16#19C8#) & U (16#19DE#)
              & U (16#19D4#) & U (16#19D2#), "khb") = 2,
           "public locale word count recognizes bounded New Tai Lue words");
   Assert (I18N.Locales.Word_At
             (U (16#1980#) & U (16#19C8#) & U (16#19DE#)
              & U (16#19D4#) & U (16#19D2#), 2, "khb") =
             U (16#19D4#) & U (16#19D2#),
           "public locale word access preserves bounded New Tai Lue digits");
   Assert (I18N.Locales.Word_Count
             (U (16#1A00#) & U (16#1A17#) & U (16#1A1E#)
              & U (16#1A16#), "bug") = 2,
           "public locale word count recognizes bounded Buginese words");
   Assert (I18N.Locales.Word_At
             (U (16#1A00#) & U (16#1A17#) & U (16#1A1E#)
              & U (16#1A16#), 1, "bug") =
             U (16#1A00#) & U (16#1A17#),
           "public locale word access preserves bounded Buginese marks");
   Assert (I18N.Locales.Word_Count
             (U (16#A90A#) & U (16#A926#) & U (16#A92E#)
              & U (16#A925#), "kyu") = 2,
           "public locale word count recognizes bounded Kayah Li words");
   Assert (I18N.Locales.Word_At
             (U (16#A90A#) & U (16#A926#) & U (16#A92E#)
              & U (16#A925#), 1, "kyu") =
             U (16#A90A#) & U (16#A926#),
           "public locale word access preserves bounded Kayah Li marks");
   Assert (I18N.Locales.Word_Count
             (U (16#A930#) & U (16#A947#) & U (16#A95F#)
              & U (16#A953#), "rej") = 2,
           "public locale word count recognizes bounded Rejang words");
   Assert (I18N.Locales.Word_At
             (U (16#A930#) & U (16#A947#) & U (16#A95F#)
              & U (16#A953#), 1, "rej") =
             U (16#A930#) & U (16#A947#),
           "public locale word access preserves bounded Rejang marks");
   Assert (I18N.Locales.Word_Count
             (U (16#A984#) & U (16#A9B3#) & U (16#A9C1#)
              & U (16#A9D4#) & U (16#A9D2#), "jv") = 2,
           "public locale word count recognizes bounded Javanese words");
   Assert (I18N.Locales.Word_At
             (U (16#A984#) & U (16#A9B3#) & U (16#A9C1#)
              & U (16#A9D4#) & U (16#A9D2#), 2, "jv") =
             U (16#A9D4#) & U (16#A9D2#),
           "public locale word access preserves bounded Javanese digits");
   Assert (I18N.Locales.Word_Count
             (U (16#AA00#) & U (16#AA29#) & U (16#AA5C#)
              & U (16#AA54#) & U (16#AA52#), "cjm") = 2,
           "public locale word count recognizes bounded Cham words");
   Assert (I18N.Locales.Word_At
             (U (16#AA00#) & U (16#AA29#) & U (16#AA5C#)
              & U (16#AA54#) & U (16#AA52#), 1, "cjm") =
             U (16#AA00#) & U (16#AA29#),
           "public locale word access preserves bounded Cham marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1A20#) & U (16#1A55#) & U (16#1AA0#)
              & U (16#1A94#) & U (16#1A92#), "nod") = 2,
           "public locale word count recognizes bounded Tai Tham words");
   Assert (I18N.Locales.Word_At
             (U (16#1A20#) & U (16#1A55#) & U (16#1AA0#)
              & U (16#1A94#) & U (16#1A92#), 1, "nod") =
             U (16#1A20#) & U (16#1A55#),
           "public locale word access preserves bounded Tai Tham marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1B05#) & U (16#1B35#) & U (16#1B5A#)
              & U (16#1B54#) & U (16#1B52#), "ban") = 2,
           "public locale word count recognizes bounded Balinese words");
   Assert (I18N.Locales.Word_At
             (U (16#1B05#) & U (16#1B35#) & U (16#1B5A#)
              & U (16#1B54#) & U (16#1B52#), 2, "ban") =
             U (16#1B54#) & U (16#1B52#),
           "public locale word access preserves bounded Balinese digits");
   Assert (I18N.Locales.Word_Count
             (U (16#1B83#) & U (16#1BA0#) & " "
              & U (16#1BB4#) & U (16#1BB2#), "su") = 2,
           "public locale word count recognizes bounded Sundanese words");
   Assert (I18N.Locales.Word_At
             (U (16#1B83#) & U (16#1BA0#) & " "
              & U (16#1BB4#) & U (16#1BB2#), 1, "su") =
             U (16#1B83#) & U (16#1BA0#),
           "public locale word access preserves bounded Sundanese marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1C00#) & U (16#1C2C#) & U (16#1C3B#)
              & U (16#1C44#) & U (16#1C42#), "lep") = 2,
           "public locale word count recognizes bounded Lepcha words");
   Assert (I18N.Locales.Word_At
             (U (16#1C00#) & U (16#1C2C#) & U (16#1C3B#)
              & U (16#1C44#) & U (16#1C42#), 1, "lep") =
             U (16#1C00#) & U (16#1C2C#),
           "public locale word access preserves bounded Lepcha marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1C5A#) & U (16#1C7D#) & U (16#1C7E#)
              & U (16#1C54#) & U (16#1C52#), "sat") = 2,
           "public locale word count recognizes bounded Ol Chiki words");
   Assert (I18N.Locales.Word_At
             (U (16#1C5A#) & U (16#1C7D#) & U (16#1C7E#)
              & U (16#1C54#) & U (16#1C52#), 2, "sat") =
             U (16#1C54#) & U (16#1C52#),
           "public locale word access preserves bounded Ol Chiki digits");
   Assert (I18N.Locales.Word_Count
             (U (16#A500#) & U (16#A610#) & U (16#A60D#)
              & U (16#A624#) & U (16#A622#), "vai") = 2,
           "public locale word count recognizes bounded Vai words");
   Assert (I18N.Locales.Word_At
             (U (16#A500#) & U (16#A610#) & U (16#A60D#)
              & U (16#A624#) & U (16#A622#), 1, "vai") =
             U (16#A500#) & U (16#A610#),
           "public locale word access preserves bounded Vai letters");
   Assert (I18N.Locales.Word_Count
             (U (16#A882#) & U (16#A8C4#) & U (16#A8CE#)
              & U (16#A8D4#) & U (16#A8D2#), "saz") = 2,
           "public locale word count recognizes bounded Saurashtra words");
   Assert (I18N.Locales.Word_At
             (U (16#A882#) & U (16#A8C4#) & U (16#A8CE#)
              & U (16#A8D4#) & U (16#A8D2#), 2, "saz") =
             U (16#A8D4#) & U (16#A8D2#),
           "public locale word access preserves bounded Saurashtra digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11005#) & U (16#11046#) & U (16#11047#)
              & U (16#1106A#) & U (16#11068#), "brh") = 2,
           "public locale word count recognizes bounded Brahmi words");
   Assert (I18N.Locales.Word_At
             (U (16#11005#) & U (16#11046#) & U (16#11047#)
              & U (16#1106A#) & U (16#11068#), 2, "brh") =
             U (16#1106A#) & U (16#11068#),
           "public locale word access preserves bounded Brahmi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11083#) & U (16#110B0#) & U (16#110BB#)
              & U (16#110C2#), "kht") = 2,
           "public locale word count recognizes bounded Kaithi words");
   Assert (I18N.Locales.Word_At
             (U (16#11083#) & U (16#110B0#) & U (16#110BB#)
              & U (16#110C2#), 2, "kht") =
             U (16#110C2#),
           "public locale word access preserves bounded Kaithi signs");
   Assert (I18N.Locales.Word_Count
             (U (16#110D0#) & U (16#110E8#) & " "
              & U (16#110F4#) & U (16#110F2#), "srb") = 2,
           "public locale word count recognizes bounded Sora Sompeng words");
   Assert (I18N.Locales.Word_At
             (U (16#110D0#) & U (16#110E8#) & " "
              & U (16#110F4#) & U (16#110F2#), 2, "srb") =
             U (16#110F4#) & U (16#110F2#),
           "public locale word access preserves bounded Sora Sompeng digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11103#) & U (16#11134#) & U (16#11140#)
              & U (16#1113A#) & U (16#11138#), "ccp") = 2,
           "public locale word count recognizes bounded Chakma words");
   Assert (I18N.Locales.Word_At
             (U (16#11103#) & U (16#11134#) & U (16#11140#)
              & U (16#1113A#) & U (16#11138#), 2, "ccp") =
             U (16#1113A#) & U (16#11138#),
           "public locale word access preserves bounded Chakma digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11183#) & U (16#111C4#) & U (16#111C5#)
              & U (16#111D4#) & U (16#111D2#), "sa-Shrd") = 2,
           "public locale word count recognizes bounded Sharada words");
   Assert (I18N.Locales.Word_At
             (U (16#11183#) & U (16#111C4#) & U (16#111C5#)
              & U (16#111D4#) & U (16#111D2#), 2, "sa-Shrd") =
             U (16#111D4#) & U (16#111D2#),
           "public locale word access preserves bounded Sharada digits");
   Assert (I18N.Locales.Word_Count
             (U (16#112B0#) & U (16#112EA#) & " "
              & U (16#112F4#) & U (16#112F2#), "sd-Sind") = 2,
           "public locale word count recognizes bounded Khudawadi words");
   Assert (I18N.Locales.Word_At
             (U (16#112B0#) & U (16#112EA#) & " "
              & U (16#112F4#) & U (16#112F2#), 2, "sd-Sind") =
             U (16#112F4#) & U (16#112F2#),
           "public locale word access preserves bounded Khudawadi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11400#) & U (16#1144A#) & U (16#1144B#)
              & U (16#11454#) & U (16#11452#), "new") = 2,
           "public locale word count recognizes bounded Newa words");
   Assert (I18N.Locales.Word_At
             (U (16#11400#) & U (16#1144A#) & U (16#1144B#)
              & U (16#11454#) & U (16#11452#), 2, "new") =
             U (16#11454#) & U (16#11452#),
           "public locale word access preserves bounded Newa digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11480#) & U (16#114C5#) & U (16#114C6#)
              & U (16#114D4#) & U (16#114D2#), "mai-Tirh") = 2,
           "public locale word count recognizes bounded Tirhuta words");
   Assert (I18N.Locales.Word_At
             (U (16#11480#) & U (16#114C5#) & U (16#114C6#)
              & U (16#114D4#) & U (16#114D2#), 2, "mai-Tirh") =
             U (16#114D4#) & U (16#114D2#),
           "public locale word access preserves bounded Tirhuta digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11600#) & U (16#11640#) & U (16#11641#)
              & U (16#11654#) & U (16#11652#), "mr-Modi") = 2,
           "public locale word count recognizes bounded Modi words");
   Assert (I18N.Locales.Word_At
             (U (16#11600#) & U (16#11640#) & U (16#11641#)
              & U (16#11654#) & U (16#11652#), 2, "mr-Modi") =
             U (16#11654#) & U (16#11652#),
           "public locale word access preserves bounded Modi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11680#) & U (16#116B8#) & U (16#116B9#)
              & U (16#116C4#) & U (16#116C2#), "doi-Takr") = 2,
           "public locale word count recognizes bounded Takri words");
   Assert (I18N.Locales.Word_At
             (U (16#11680#) & U (16#116B8#) & U (16#116B9#)
              & U (16#116C4#) & U (16#116C2#), 2, "doi-Takr") =
             U (16#116C4#) & U (16#116C2#),
           "public locale word access preserves bounded Takri digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11700#) & U (16#1172B#) & U (16#1173C#)
              & U (16#11734#) & U (16#11732#), "aho") = 2,
           "public locale word count recognizes bounded Ahom words");
   Assert (I18N.Locales.Word_At
             (U (16#11700#) & U (16#1172B#) & U (16#1173C#)
              & U (16#11734#) & U (16#11732#), 2, "aho") =
             U (16#11734#) & U (16#11732#),
           "public locale word access preserves bounded Ahom digits");
   Assert (I18N.Locales.Word_Count
             (U (16#118A0#) & U (16#118F2#) & " "
              & U (16#118E4#) & U (16#118E2#), "hoc-Wara") = 2,
           "public locale word count recognizes bounded Warang Citi words");
   Assert (I18N.Locales.Word_At
             (U (16#118A0#) & U (16#118F2#) & " "
              & U (16#118E4#) & U (16#118E2#), 2, "hoc-Wara") =
             U (16#118E4#) & U (16#118E2#),
           "public locale word access preserves bounded Warang Citi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11AC0#) & U (16#11AF8#) & " "
              & U (16#11AC1#), "ctd-Pauc") = 2,
           "public locale word count recognizes bounded Pau Cin Hau words");
   Assert (I18N.Locales.Word_At
             (U (16#11AC0#) & U (16#11AF8#) & " "
              & U (16#11AC1#), 1, "ctd-Pauc") =
             U (16#11AC0#) & U (16#11AF8#),
           "public locale word access preserves bounded Pau Cin Hau letters");
   Assert (I18N.Locales.Word_Count
             (U (16#11C00#) & U (16#11C40#) & " "
              & U (16#11C54#) & U (16#11C52#), "sa-Bhks") = 2,
           "public locale word count recognizes bounded Bhaiksuki words");
   Assert (I18N.Locales.Word_At
             (U (16#11C00#) & U (16#11C40#) & " "
              & U (16#11C54#) & U (16#11C52#), 2, "sa-Bhks") =
             U (16#11C54#) & U (16#11C52#),
           "public locale word access preserves bounded Bhaiksuki digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11C72#) & U (16#11CB6#) & " "
              & U (16#11C8F#), "bo-Marc") = 2,
           "public locale word count recognizes bounded Marchen words");
   Assert (I18N.Locales.Word_At
             (U (16#11C72#) & U (16#11CB6#) & " "
              & U (16#11C8F#), 1, "bo-Marc") =
             U (16#11C72#) & U (16#11CB6#),
           "public locale word access preserves bounded Marchen marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11D00#) & U (16#11D47#) & " "
              & U (16#11D54#) & U (16#11D52#), "gon-Gonm") = 2,
           "public locale word count recognizes bounded Masaram Gondi words");
   Assert (I18N.Locales.Word_At
             (U (16#11D00#) & U (16#11D47#) & " "
              & U (16#11D54#) & U (16#11D52#), 2, "gon-Gonm") =
             U (16#11D54#) & U (16#11D52#),
           "public locale word access preserves bounded Masaram Gondi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11D60#) & U (16#11D98#) & " "
              & U (16#11DA4#) & U (16#11DA2#), "gon-Gong") = 2,
           "public locale word count recognizes bounded Gunjala Gondi words");
   Assert (I18N.Locales.Word_At
             (U (16#11D60#) & U (16#11D98#) & " "
              & U (16#11DA4#) & U (16#11DA2#), 2, "gon-Gong") =
             U (16#11DA4#) & U (16#11DA2#),
           "public locale word access preserves bounded Gunjala Gondi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11DB0#) & U (16#11DDB#) & " "
              & U (16#11DE8#) & U (16#11DE6#), "tsg-Tols") = 2,
           "public locale word count recognizes bounded Tolong Siki words");
   Assert (I18N.Locales.Word_At
             (U (16#11DB0#) & U (16#11DDB#) & " "
              & U (16#11DE8#) & U (16#11DE6#), 2, "tsg-Tols") =
             U (16#11DE8#) & U (16#11DE6#),
           "public locale word access preserves bounded Tolong Siki digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11EE0#) & U (16#11EF6#) & " "
              & U (16#11EE1#), "mak-Maka") = 2,
           "public locale word count recognizes bounded Makasar words");
   Assert (I18N.Locales.Word_At
             (U (16#11EE0#) & U (16#11EF6#) & " "
              & U (16#11EE1#), 1, "mak-Maka") =
             U (16#11EE0#) & U (16#11EF6#),
           "public locale word access preserves bounded Makasar marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11200#) & U (16#11241#) & " "
              & U (16#11213#), "sd-Khoj") = 2,
           "public locale word count recognizes bounded Khojki words");
   Assert (I18N.Locales.Word_At
             (U (16#11200#) & U (16#11241#) & " "
              & U (16#11213#), 1, "sd-Khoj") =
             U (16#11200#) & U (16#11241#),
           "public locale word access preserves bounded Khojki marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11280#) & U (16#112A8#) & " "
              & U (16#1128F#), "skr-Mult") = 2,
           "public locale word count recognizes bounded Multani words");
   Assert (I18N.Locales.Word_At
             (U (16#11280#) & U (16#112A8#) & " "
              & U (16#1128F#), 1, "skr-Mult") =
             U (16#11280#) & U (16#112A8#),
           "public locale word access preserves bounded Multani letters");
   Assert (I18N.Locales.Word_Count
             (U (16#11305#) & U (16#11374#) & " "
              & U (16#11350#), "sa-Gran") = 2,
           "public locale word count recognizes bounded Grantha words");
   Assert (I18N.Locales.Word_At
             (U (16#11305#) & U (16#11374#) & " "
              & U (16#11350#), 1, "sa-Gran") =
             U (16#11305#) & U (16#11374#),
           "public locale word access preserves bounded Grantha marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11580#) & U (16#115DD#) & " "
              & U (16#115B5#), "sa-Sidd") = 2,
           "public locale word count recognizes bounded Siddham words");
   Assert (I18N.Locales.Word_At
             (U (16#11580#) & U (16#115DD#) & " "
              & U (16#115B5#), 1, "sa-Sidd") =
             U (16#11580#) & U (16#115DD#),
           "public locale word access preserves bounded Siddham marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11800#) & U (16#1183A#) & " "
              & U (16#11801#), "doi-Dogr") = 2,
           "public locale word count recognizes bounded Dogra words");
   Assert (I18N.Locales.Word_At
             (U (16#11800#) & U (16#1183A#) & " "
              & U (16#11801#), 1, "doi-Dogr") =
             U (16#11800#) & U (16#1183A#),
           "public locale word access preserves bounded Dogra marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11900#) & U (16#11943#) & " "
              & U (16#11954#) & U (16#11952#), "dv-Diak") = 2,
           "public locale word count recognizes bounded Dives Akuru words");
   Assert (I18N.Locales.Word_At
             (U (16#11900#) & U (16#11943#) & " "
              & U (16#11954#) & U (16#11952#), 2, "dv-Diak") =
             U (16#11954#) & U (16#11952#),
           "public locale word access preserves bounded Dives Akuru digits");
   Assert (I18N.Locales.Word_Count
             (U (16#119A0#) & U (16#119E4#) & " "
              & U (16#119AA#), "sa-Nand") = 2,
           "public locale word count recognizes bounded Nandinagari words");
   Assert (I18N.Locales.Word_At
             (U (16#119A0#) & U (16#119E4#) & " "
              & U (16#119AA#), 1, "sa-Nand") =
             U (16#119A0#) & U (16#119E4#),
           "public locale word access preserves bounded Nandinagari marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11A00#) & U (16#11A47#) & " "
              & U (16#11A3E#), "mn-Zanb") = 2,
           "public locale word count recognizes bounded Zanabazar Square words");
   Assert (I18N.Locales.Word_At
             (U (16#11A00#) & U (16#11A47#) & " "
              & U (16#11A3E#), 1, "mn-Zanb") =
             U (16#11A00#) & U (16#11A47#),
           "public locale word access preserves bounded Zanabazar Square marks");
   Assert (I18N.Locales.Word_Count
             (U (16#11A50#) & U (16#11A9D#) & " "
              & U (16#11A99#), "mn-Soyo") = 2,
           "public locale word count recognizes bounded Soyombo words");
   Assert (I18N.Locales.Word_At
             (U (16#11A50#) & U (16#11A9D#) & " "
              & U (16#11A99#), 1, "mn-Soyo") =
             U (16#11A50#) & U (16#11A9D#),
           "public locale word access preserves bounded Soyombo marks");
   Assert (I18N.Locales.Word_Count
             (U (16#10D00#) & U (16#10D27#) & " "
              & U (16#10D34#) & U (16#10D32#), "rhg-Rohg") = 2,
           "public locale word count recognizes bounded Hanifi Rohingya words");
   Assert (I18N.Locales.Word_At
             (U (16#10D00#) & U (16#10D27#) & " "
              & U (16#10D34#) & U (16#10D32#), 2, "rhg-Rohg") =
             U (16#10D34#) & U (16#10D32#),
           "public locale word access preserves bounded Hanifi Rohingya digits");
   Assert (I18N.Locales.Word_Count
             (U (16#10D50#) & U (16#10D85#) & " "
              & U (16#10D42#) & U (16#10D43#), "wo-Gara") = 2,
           "public locale word count recognizes bounded Garay words");
   Assert (I18N.Locales.Word_At
             (U (16#10D50#) & U (16#10D85#) & " "
              & U (16#10D42#) & U (16#10D43#), 2, "wo-Gara") =
             U (16#10D42#) & U (16#10D43#),
           "public locale word access preserves bounded Garay digits");
   Assert (I18N.Locales.Word_Count
             (U (16#10F00#) & U (16#10F27#) & " "
              & U (16#10F30#), "sog-Sogo") = 2,
           "public locale word count recognizes bounded Old Sogdian words");
   Assert (I18N.Locales.Word_At
             (U (16#10F00#) & U (16#10F27#) & " "
              & U (16#10F30#), 1, "sog-Sogo") =
             U (16#10F00#) & U (16#10F27#),
           "public locale word access preserves bounded Old Sogdian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10F30#) & U (16#10F54#) & " "
              & U (16#10F40#), "sog-Sogd") = 2,
           "public locale word count recognizes bounded Sogdian words");
   Assert (I18N.Locales.Word_At
             (U (16#10F30#) & U (16#10F54#) & " "
              & U (16#10F40#), 1, "sog-Sogd") =
             U (16#10F30#) & U (16#10F54#),
           "public locale word access preserves bounded Sogdian marks");
   Assert (I18N.Locales.Word_Count
             (U (16#10FE0#) & U (16#10FF6#) & " "
              & U (16#10FE1#), "arc-Elym") = 2,
           "public locale word count recognizes bounded Elymaic words");
   Assert (I18N.Locales.Word_At
             (U (16#10FE0#) & U (16#10FF6#) & " "
              & U (16#10FE1#), 1, "arc-Elym") =
             U (16#10FE0#) & U (16#10FF6#),
           "public locale word access preserves bounded Elymaic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#11F00#) & U (16#11F42#) & " "
              & U (16#11F54#) & U (16#11F52#), "kaw") = 2,
           "public locale word count recognizes bounded Kawi words");
   Assert (I18N.Locales.Word_At
             (U (16#11F00#) & U (16#11F42#) & " "
              & U (16#11F54#) & U (16#11F52#), 2, "kaw") =
             U (16#11F54#) & U (16#11F52#),
           "public locale word access preserves bounded Kawi digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11380#) & U (16#113D3#) & " "
              & U (16#113E2#), "tcy-Tutg") = 2,
           "public locale word count recognizes bounded Tulu-Tigalari words");
   Assert (I18N.Locales.Word_At
             (U (16#11380#) & U (16#113D3#) & " "
              & U (16#113E2#), 1, "tcy-Tutg") =
             U (16#11380#) & U (16#113D3#),
           "public locale word access preserves bounded Tulu-Tigalari marks");
   Assert (I18N.Locales.Word_Count
             (U (16#16100#) & U (16#1612F#) & " "
              & U (16#16135#) & U (16#16133#), "gvr-Gukh") = 2,
           "public locale word count recognizes bounded Gurung Khema words");
   Assert (I18N.Locales.Word_At
             (U (16#16100#) & U (16#1612F#) & " "
              & U (16#16135#) & U (16#16133#), 2, "gvr-Gukh") =
             U (16#16135#) & U (16#16133#),
           "public locale word access preserves bounded Gurung Khema digits");
   Assert (I18N.Locales.Word_Count
             (U (16#16E40#) & U (16#16E96#) & " "
              & U (16#16E41#), "dmf-Medf") = 2,
           "public locale word count recognizes bounded Medefaidrin words");
   Assert (I18N.Locales.Word_At
             (U (16#16E40#) & U (16#16E96#) & " "
              & U (16#16E41#), 1, "dmf-Medf") =
             U (16#16E40#) & U (16#16E96#),
           "public locale word access preserves bounded Medefaidrin letters");
   Assert (I18N.Locales.Word_Count
             (U (16#16EA0#) & U (16#16ED3#) & " "
              & U (16#16EA1#), "zag-Beri") = 2,
           "public locale word count recognizes bounded Beria Erfe words");
   Assert (I18N.Locales.Word_At
             (U (16#16EA0#) & U (16#16ED3#) & " "
              & U (16#16EA1#), 1, "zag-Beri") =
             U (16#16EA0#) & U (16#16ED3#),
           "public locale word access preserves bounded Beria Erfe letters");
   Assert (I18N.Locales.Word_Count
             (U (16#16D43#) & U (16#16D6D#) & " "
              & U (16#16D75#) & U (16#16D73#), "rai-Krai") = 2,
           "public locale word count recognizes bounded Kirat Rai words");
   Assert (I18N.Locales.Word_At
             (U (16#16D43#) & U (16#16D6D#) & " "
              & U (16#16D75#) & U (16#16D73#), 2, "rai-Krai") =
             U (16#16D75#) & U (16#16D73#),
           "public locale word access preserves bounded Kirat Rai digits");
   Assert (I18N.Locales.Word_Count
             (U (16#11BC0#) & U (16#11BE0#) & " "
              & U (16#11BF8#) & U (16#11BF6#), "suz-Sunu") = 2,
           "public locale word count recognizes bounded Sunuwar words");
   Assert (I18N.Locales.Word_At
             (U (16#11BC0#) & U (16#11BE0#) & " "
              & U (16#11BF8#) & U (16#11BF6#), 2, "suz-Sunu") =
             U (16#11BF8#) & U (16#11BF6#),
           "public locale word access preserves bounded Sunuwar digits");
   Assert (I18N.Locales.Word_Count
             (U (16#1E5D0#) & U (16#1E5F0#) & " "
              & U (16#1E5F8#) & U (16#1E5F6#), "unr-Onao") = 2,
           "public locale word count recognizes bounded Ol Onal words");
   Assert (I18N.Locales.Word_At
             (U (16#1E5D0#) & U (16#1E5F0#) & " "
              & U (16#1E5F8#) & U (16#1E5F6#), 1, "unr-Onao") =
             U (16#1E5D0#) & U (16#1E5F0#),
           "public locale word access preserves bounded Ol Onal marks");
   Assert (I18N.Locales.Word_Count
             (U (16#1E6C0#) & U (16#1E6F5#) & " "
              & U (16#1E6C1#), "tai-Tayo") = 2,
           "public locale word count recognizes bounded Tai Yo words");
   Assert (I18N.Locales.Word_At
             (U (16#1E6C0#) & U (16#1E6F5#) & " "
              & U (16#1E6C1#), 1, "tai-Tayo") =
             U (16#1E6C0#) & U (16#1E6F5#),
           "public locale word access preserves bounded Tai Yo signs");
   Assert (I18N.Locales.Word_Count
             (U (16#1E900#) & U (16#1E94B#) & " "
              & U (16#1E954#) & U (16#1E952#), "ff-Adlm") = 2,
           "public locale word count recognizes bounded Adlam words");
   Assert (I18N.Locales.Word_At
             (U (16#1E900#) & U (16#1E94B#) & " "
              & U (16#1E954#) & U (16#1E952#), 2, "ff-Adlm") =
             U (16#1E954#) & U (16#1E952#),
           "public locale word access preserves bounded Adlam digits");
   Assert (I18N.Locales.Word_Count
             (U (16#10570#) & U (16#105BC#) & " "
              & U (16#10571#), "sq-Vith") = 2,
           "public locale word count recognizes bounded Vithkuqi words");
   Assert (I18N.Locales.Word_At
             (U (16#10570#) & U (16#105BC#) & " "
              & U (16#10571#), 1, "sq-Vith") =
             U (16#10570#) & U (16#105BC#),
           "public locale word access preserves bounded Vithkuqi letters");
   Assert (I18N.Locales.Word_Count
             (U (16#105C0#) & U (16#105F3#) & " "
              & U (16#105C1#), "sq-Todr") = 2,
           "public locale word count recognizes bounded Todhri words");
   Assert (I18N.Locales.Word_At
             (U (16#105C0#) & U (16#105F3#) & " "
              & U (16#105C1#), 1, "sq-Todr") =
             U (16#105C0#) & U (16#105F3#),
           "public locale word access preserves bounded Todhri letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10E80#) & U (16#10EB1#) & " "
              & U (16#10E81#), "ku-Yezi") = 2,
           "public locale word count recognizes bounded Yezidi words");
   Assert (I18N.Locales.Word_At
             (U (16#10E80#) & U (16#10EB1#) & " "
              & U (16#10E81#), 1, "ku-Yezi") =
             U (16#10E80#) & U (16#10EB1#),
           "public locale word access preserves bounded Yezidi letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10F70#) & U (16#10F89#) & " "
              & U (16#10F71#), "oui-Ougr") = 2,
           "public locale word count recognizes bounded Old Uyghur words");
   Assert (I18N.Locales.Word_At
             (U (16#10F70#) & U (16#10F89#) & " "
              & U (16#10F71#), 1, "oui-Ougr") =
             U (16#10F70#) & U (16#10F89#),
           "public locale word access preserves bounded Old Uyghur letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10FB0#) & U (16#10FCB#) & " "
              & U (16#10FB1#), "xco-Chrs") = 2,
           "public locale word count recognizes bounded Chorasmian words");
   Assert (I18N.Locales.Word_At
             (U (16#10FB0#) & U (16#10FCB#) & " "
              & U (16#10FB1#), 1, "xco-Chrs") =
             U (16#10FB0#) & U (16#10FCB#),
           "public locale word access preserves bounded Chorasmian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10000#) & U (16#1005D#) & " "
              & U (16#100FA#), "gmy-Linb") = 2,
           "public locale word count recognizes bounded Linear B words");
   Assert (I18N.Locales.Word_At
             (U (16#10000#) & U (16#1005D#) & " "
              & U (16#100FA#), 1, "gmy-Linb") =
             U (16#10000#) & U (16#1005D#),
           "public locale word access preserves bounded Linear B signs");
   Assert (I18N.Locales.Word_Count
             (U (16#10107#) & U (16#10133#) & " "
              & U (16#1013F#), "gmy-Linb") = 2,
           "public locale word count recognizes bounded Aegean number words");
   Assert (I18N.Locales.Word_At
             (U (16#10107#) & U (16#10133#) & " "
              & U (16#1013F#), 2, "gmy-Linb") =
             U (16#1013F#),
           "public locale word access preserves bounded Aegean measures");
   Assert (I18N.Locales.Word_Count
             (U (16#10280#) & U (16#1029C#) & " "
              & U (16#10281#), "xlc-Lyci") = 2,
           "public locale word count recognizes bounded Lycian words");
   Assert (I18N.Locales.Word_At
             (U (16#10280#) & U (16#1029C#) & " "
              & U (16#10281#), 1, "xlc-Lyci") =
             U (16#10280#) & U (16#1029C#),
           "public locale word access preserves bounded Lycian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#102A0#) & U (16#102D0#) & " "
              & U (16#102A1#), "xcr-Cari") = 2,
           "public locale word count recognizes bounded Carian words");
   Assert (I18N.Locales.Word_At
             (U (16#102A0#) & U (16#102D0#) & " "
              & U (16#102A1#), 1, "xcr-Cari") =
             U (16#102A0#) & U (16#102D0#),
           "public locale word access preserves bounded Carian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10300#) & U (16#1032F#) & " "
              & U (16#10301#), "ett-Ital") = 2,
           "public locale word count recognizes bounded Old Italic words");
   Assert (I18N.Locales.Word_At
             (U (16#10300#) & U (16#1032F#) & " "
              & U (16#10301#), 1, "ett-Ital") =
             U (16#10300#) & U (16#1032F#),
           "public locale word access preserves bounded Old Italic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10330#) & U (16#1034A#) & " "
              & U (16#10331#), "got-Goth") = 2,
           "public locale word count recognizes bounded Gothic words");
   Assert (I18N.Locales.Word_At
             (U (16#10330#) & U (16#1034A#) & " "
              & U (16#10331#), 1, "got-Goth") =
             U (16#10330#) & U (16#1034A#),
           "public locale word access preserves bounded Gothic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10350#) & U (16#1037A#) & " "
              & U (16#10351#), "kv-Perm") = 2,
           "public locale word count recognizes bounded Old Permic words");
   Assert (I18N.Locales.Word_At
             (U (16#10350#) & U (16#1037A#) & " "
              & U (16#10351#), 1, "kv-Perm") =
             U (16#10350#) & U (16#1037A#),
           "public locale word access preserves bounded Old Permic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10380#) & U (16#1039D#) & " "
              & U (16#10381#), "uga-Ugar") = 2,
           "public locale word count recognizes bounded Ugaritic words");
   Assert (I18N.Locales.Word_At
             (U (16#10380#) & U (16#1039D#) & " "
              & U (16#10381#), 1, "uga-Ugar") =
             U (16#10380#) & U (16#1039D#),
           "public locale word access preserves bounded Ugaritic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#103A0#) & U (16#103CF#) & " "
              & U (16#103D5#), "peo-Xpeo") = 2,
           "public locale word count recognizes bounded Old Persian words");
   Assert (I18N.Locales.Word_At
             (U (16#103A0#) & U (16#103CF#) & " "
              & U (16#103D5#), 2, "peo-Xpeo") =
             U (16#103D5#),
           "public locale word access preserves bounded Old Persian numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10400#) & U (16#1044F#) & " "
              & U (16#10401#), "en-Dsrt") = 2,
           "public locale word count recognizes bounded Deseret words");
   Assert (I18N.Locales.Word_At
             (U (16#10400#) & U (16#1044F#) & " "
              & U (16#10401#), 1, "en-Dsrt") =
             U (16#10400#) & U (16#1044F#),
           "public locale word access preserves bounded Deseret letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10450#) & U (16#1047F#) & " "
              & U (16#10451#), "en-Shaw") = 2,
           "public locale word count recognizes bounded Shavian words");
   Assert (I18N.Locales.Word_At
             (U (16#10450#) & U (16#1047F#) & " "
              & U (16#10451#), 1, "en-Shaw") =
             U (16#10450#) & U (16#1047F#),
           "public locale word access preserves bounded Shavian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10480#) & U (16#1049D#) & " "
              & U (16#104A4#) & U (16#104A2#), "so-Osma") = 2,
           "public locale word count recognizes bounded Osmanya words");
   Assert (I18N.Locales.Word_At
             (U (16#10480#) & U (16#1049D#) & " "
              & U (16#104A4#) & U (16#104A2#), 2, "so-Osma") =
             U (16#104A4#) & U (16#104A2#),
           "public locale word access preserves bounded Osmanya digits");
   Assert (I18N.Locales.Word_Count
             (U (16#104B0#) & U (16#104D3#) & " "
              & U (16#104FB#), "osa-Osge") = 2,
           "public locale word count recognizes bounded Osage words");
   Assert (I18N.Locales.Word_At
             (U (16#104B0#) & U (16#104D3#) & " "
              & U (16#104FB#), 1, "osa-Osge") =
             U (16#104B0#) & U (16#104D3#),
           "public locale word access preserves bounded Osage letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10500#) & U (16#10527#) & " "
              & U (16#10501#), "sq-Elba") = 2,
           "public locale word count recognizes bounded Elbasan words");
   Assert (I18N.Locales.Word_At
             (U (16#10500#) & U (16#10527#) & " "
              & U (16#10501#), 1, "sq-Elba") =
             U (16#10500#) & U (16#10527#),
           "public locale word access preserves bounded Elbasan letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10530#) & U (16#10563#) & " "
              & U (16#10531#), "agw-Aghb") = 2,
           "public locale word count recognizes bounded Caucasian Albanian words");
   Assert (I18N.Locales.Word_At
             (U (16#10530#) & U (16#10563#) & " "
              & U (16#10531#), 1, "agw-Aghb") =
             U (16#10530#) & U (16#10563#),
           "public locale word access preserves bounded Caucasian Albanian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10800#) & U (16#1083F#) & " "
              & U (16#10801#), "grc-Cprt") = 2,
           "public locale word count recognizes bounded Cypriot words");
   Assert (I18N.Locales.Word_At
             (U (16#10800#) & U (16#1083F#) & " "
              & U (16#10801#), 1, "grc-Cprt") =
             U (16#10800#) & U (16#1083F#),
           "public locale word access preserves bounded Cypriot syllables");
   Assert (I18N.Locales.Word_Count
             (U (16#10840#) & U (16#10855#) & " "
              & U (16#1085F#), "arc-Armi") = 2,
           "public locale word count recognizes bounded Imperial Aramaic words");
   Assert (I18N.Locales.Word_At
             (U (16#10840#) & U (16#10855#) & " "
              & U (16#1085F#), 2, "arc-Armi") =
             U (16#1085F#),
           "public locale word access preserves bounded Imperial Aramaic numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10860#) & U (16#10876#) & " "
              & U (16#1087F#), "arc-Palm") = 2,
           "public locale word count recognizes bounded Palmyrene words");
   Assert (I18N.Locales.Word_At
             (U (16#10860#) & U (16#10876#) & " "
              & U (16#1087F#), 1, "arc-Palm") =
             U (16#10860#) & U (16#10876#),
           "public locale word access preserves bounded Palmyrene letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10900#) & U (16#1091B#) & " "
              & U (16#10901#), "phn-Phnx") = 2,
           "public locale word count recognizes bounded Phoenician words");
   Assert (I18N.Locales.Word_At
             (U (16#10900#) & U (16#1091B#) & " "
              & U (16#10901#), 1, "phn-Phnx") =
             U (16#10900#) & U (16#1091B#),
           "public locale word access preserves bounded Phoenician letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10920#) & U (16#10939#) & " "
              & U (16#10921#), "xld-Lydi") = 2,
           "public locale word count recognizes bounded Lydian words");
   Assert (I18N.Locales.Word_At
             (U (16#10920#) & U (16#10939#) & " "
              & U (16#10921#), 1, "xld-Lydi") =
             U (16#10920#) & U (16#10939#),
           "public locale word access preserves bounded Lydian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10940#) & U (16#10959#) & " "
              & U (16#10941#), "xsd-Sidt") = 2,
           "public locale word count recognizes bounded Sidetic words");
   Assert (I18N.Locales.Word_At
             (U (16#10940#) & U (16#10959#) & " "
              & U (16#10941#), 1, "xsd-Sidt") =
             U (16#10940#) & U (16#10959#),
           "public locale word access preserves bounded Sidetic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10980#) & U (16#1099F#) & " "
              & U (16#10981#), "xmr-Mero") = 2,
           "public locale word count recognizes bounded Meroitic Hieroglyph words");
   Assert (I18N.Locales.Word_At
             (U (16#10980#) & U (16#1099F#) & " "
              & U (16#10981#), 1, "xmr-Mero") =
             U (16#10980#) & U (16#1099F#),
           "public locale word access preserves bounded Meroitic Hieroglyphs");
   Assert (I18N.Locales.Word_Count
             (U (16#109A0#) & U (16#109B7#) & " "
              & U (16#109FF#), "xmr-Merc") = 2,
           "public locale word count recognizes bounded Meroitic Cursive words");
   Assert (I18N.Locales.Word_At
             (U (16#109A0#) & U (16#109B7#) & " "
              & U (16#109FF#), 2, "xmr-Merc") =
             U (16#109FF#),
           "public locale word access preserves bounded Meroitic Cursive numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10880#) & U (16#1089E#) & " "
              & U (16#108AF#), "arc-Nbat") = 2,
           "public locale word count recognizes bounded Nabataean words");
   Assert (I18N.Locales.Word_At
             (U (16#10880#) & U (16#1089E#) & " "
              & U (16#108AF#), 1, "arc-Nbat") =
             U (16#10880#) & U (16#1089E#),
           "public locale word access preserves bounded Nabataean letters");
   Assert (I18N.Locales.Word_Count
             (U (16#108E0#) & U (16#108F5#) & " "
              & U (16#108FF#), "arc-Hatr") = 2,
           "public locale word count recognizes bounded Hatran words");
   Assert (I18N.Locales.Word_At
             (U (16#108E0#) & U (16#108F5#) & " "
              & U (16#108FF#), 2, "arc-Hatr") =
             U (16#108FF#),
           "public locale word access preserves bounded Hatran numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10A00#) & U (16#10A35#) & " "
              & U (16#10A48#), "pra-Khar") = 2,
           "public locale word count recognizes bounded Kharoshthi words");
   Assert (I18N.Locales.Word_At
             (U (16#10A00#) & U (16#10A35#) & " "
              & U (16#10A48#), 1, "pra-Khar") =
             U (16#10A00#) & U (16#10A35#),
           "public locale word access preserves bounded Kharoshthi letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10A35#) & U (16#10A50#) & U (16#10A48#),
              "pra-Khar") = 2,
           "public locale word count separates Kharoshthi punctuation");
   Assert (I18N.Locales.Word_Count
             (U (16#10A60#) & U (16#10A7C#) & " "
              & U (16#10A7F#), "xsa-Sarb") = 2,
           "public locale word count recognizes bounded Old South Arabian words");
   Assert (I18N.Locales.Word_At
             (U (16#10A60#) & U (16#10A7C#) & " "
              & U (16#10A7F#), 1, "xsa-Sarb") =
             U (16#10A60#) & U (16#10A7C#),
           "public locale word access preserves bounded Old South Arabian letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10A80#) & U (16#10A9C#) & " "
              & U (16#10A9F#), "xna-Narb") = 2,
           "public locale word count recognizes bounded Old North Arabian words");
   Assert (I18N.Locales.Word_At
             (U (16#10A80#) & U (16#10A9C#) & " "
              & U (16#10A9F#), 2, "xna-Narb") =
             U (16#10A9F#),
           "public locale word access preserves bounded Old North Arabian numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10AC0#) & U (16#10AE6#) & " "
              & U (16#10AEF#), "xmn-Mani") = 2,
           "public locale word count recognizes bounded Manichaean words");
   Assert (I18N.Locales.Word_At
             (U (16#10AC0#) & U (16#10AE6#) & " "
              & U (16#10AEF#), 1, "xmn-Mani") =
             U (16#10AC0#) & U (16#10AE6#),
           "public locale word access preserves bounded Manichaean letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10AE6#) & U (16#10AF0#) & U (16#10AEF#),
              "xmn-Mani") = 2,
           "public locale word count separates Manichaean punctuation");
   Assert (I18N.Locales.Word_Count
             (U (16#10B00#) & U (16#10B35#) & " "
              & U (16#10B01#), "ae-Avst") = 2,
           "public locale word count recognizes bounded Avestan words");
   Assert (I18N.Locales.Word_At
             (U (16#10B00#) & U (16#10B35#) & " "
              & U (16#10B01#), 1, "ae-Avst") =
             U (16#10B00#) & U (16#10B35#),
           "public locale word access preserves bounded Avestan letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10B35#) & U (16#10B39#) & U (16#10B00#),
              "ae-Avst") = 2,
           "public locale word count separates Avestan punctuation");
   Assert (I18N.Locales.Word_Count
             (U (16#10B40#) & U (16#10B55#) & " "
              & U (16#10B5F#), "xpr-Prti") = 2,
           "public locale word count recognizes bounded Inscriptional Parthian words");
   Assert (I18N.Locales.Word_At
             (U (16#10B40#) & U (16#10B55#) & " "
              & U (16#10B5F#), 2, "xpr-Prti") =
             U (16#10B5F#),
           "public locale word access preserves bounded Inscriptional Parthian numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10B60#) & U (16#10B72#) & " "
              & U (16#10B7F#), "pal-Phli") = 2,
           "public locale word count recognizes bounded Inscriptional Pahlavi words");
   Assert (I18N.Locales.Word_At
             (U (16#10B60#) & U (16#10B72#) & " "
              & U (16#10B7F#), 1, "pal-Phli") =
             U (16#10B60#) & U (16#10B72#),
           "public locale word access preserves bounded Inscriptional Pahlavi letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10B80#) & U (16#10B91#) & " "
              & U (16#10BAF#), "pal-Phlp") = 2,
           "public locale word count recognizes bounded Psalter Pahlavi words");
   Assert (I18N.Locales.Word_At
             (U (16#10B80#) & U (16#10B91#) & " "
              & U (16#10BAF#), 2, "pal-Phlp") =
             U (16#10BAF#),
           "public locale word access preserves bounded Psalter Pahlavi numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10B91#) & U (16#10B99#) & U (16#10BAF#),
              "pal-Phlp") = 2,
           "public locale word count separates Psalter Pahlavi punctuation");
   Assert (I18N.Locales.Word_Count
             (U (16#10C00#) & U (16#10C48#) & " "
              & U (16#10C01#), "otk-Orkh") = 2,
           "public locale word count recognizes bounded Old Turkic words");
   Assert (I18N.Locales.Word_At
             (U (16#10C00#) & U (16#10C48#) & " "
              & U (16#10C01#), 1, "otk-Orkh") =
             U (16#10C00#) & U (16#10C48#),
           "public locale word access preserves bounded Old Turkic letters");
   Assert (I18N.Locales.Word_Count
             (U (16#10C80#) & U (16#10CB2#) & " "
              & U (16#10CFF#), "hu-Hung") = 2,
           "public locale word count recognizes bounded Old Hungarian words");
   Assert (I18N.Locales.Word_At
             (U (16#10C80#) & U (16#10CB2#) & " "
              & U (16#10CFF#), 2, "hu-Hung") =
             U (16#10CFF#),
           "public locale word access preserves bounded Old Hungarian numbers");
   Assert (I18N.Locales.Word_Count
             (U (16#10E60#) & U (16#10E7E#) & " "
              & U (16#10E61#), "ar-Rumi") = 2,
           "public locale word count recognizes bounded Rumi numeral words");
   Assert (I18N.Locales.Word_At
             (U (16#10E60#) & U (16#10E7E#) & " "
              & U (16#10E61#), 1, "ar-Rumi") =
             U (16#10E60#) & U (16#10E7E#),
           "public locale word access preserves bounded Rumi numeral symbols");
   Assert (I18N.Locales.Word_Count
             (U (16#16A70#) & U (16#16ABE#) & " "
              & U (16#16AC4#) & U (16#16AC2#), "nst-Tnsa") = 2,
           "public locale word count recognizes bounded Tangsa words");
   Assert (I18N.Locales.Word_At
             (U (16#16A70#) & U (16#16ABE#) & " "
              & U (16#16AC4#) & U (16#16AC2#), 2, "nst-Tnsa") =
             U (16#16AC4#) & U (16#16AC2#),
           "public locale word access preserves bounded Tangsa digits");
   Assert (I18N.Locales.Word_Count
             (U (16#1E290#) & U (16#1E2AE#) & " "
              & U (16#1E291#), "txo-Toto") = 2,
           "public locale word count recognizes bounded Toto words");
   Assert (I18N.Locales.Word_At
             (U (16#1E290#) & U (16#1E2AE#) & " "
              & U (16#1E291#), 1, "txo-Toto") =
             U (16#1E290#) & U (16#1E2AE#),
           "public locale word access preserves bounded Toto letters");
   Assert (I18N.Locales.Word_Count
             (U (16#1E4D0#) & U (16#1E4EB#) & " "
              & U (16#1E4F4#) & U (16#1E4F2#), "unr-Nagm") = 2,
           "public locale word count recognizes bounded Nag Mundari words");
   Assert (I18N.Locales.Word_At
             (U (16#1E4D0#) & U (16#1E4EB#) & " "
              & U (16#1E4F4#) & U (16#1E4F2#), 2, "unr-Nagm") =
             U (16#1E4F4#) & U (16#1E4F2#),
           "public locale word access preserves bounded Nag Mundari digits");
   Assert (I18N.Locales.Word_Count
             (U (16#12000#) & U (16#1246E#) & " "
              & U (16#12543#), "akk-Xsux") = 2,
           "public locale word count recognizes bounded Cuneiform words");
   Assert (I18N.Locales.Word_At
             (U (16#12000#) & U (16#1246E#) & " "
              & U (16#12543#), 1, "akk-Xsux") =
             U (16#12000#) & U (16#1246E#),
           "public locale word access preserves bounded Cuneiform signs");
   Assert (I18N.Locales.Word_Count
             (U (16#13000#) & U (16#1342E#) & " "
              & U (16#13001#), "egy-Egyp") = 2,
           "public locale word count recognizes bounded Egyptian Hieroglyph words");
   Assert (I18N.Locales.Word_At
             (U (16#13000#) & U (16#1342E#) & " "
              & U (16#13001#), 1, "egy-Egyp") =
             U (16#13000#) & U (16#1342E#),
           "public locale word access preserves bounded Egyptian Hieroglyphs");
   Assert (I18N.Locales.Word_Count
             (U (16#14400#) & U (16#14646#) & " "
              & U (16#14401#), "hlu-Hluw") = 2,
           "public locale word count recognizes bounded Anatolian Hieroglyph words");
   Assert (I18N.Locales.Word_At
             (U (16#14400#) & U (16#14646#) & " "
              & U (16#14401#), 1, "hlu-Hluw") =
             U (16#14400#) & U (16#14646#),
           "public locale word access preserves bounded Anatolian Hieroglyphs");
   Assert (I18N.Locales.Word_Count
             (U (16#16800#) & U (16#16A38#) & " "
              & U (16#16801#), "bax-Bamu") = 2,
           "public locale word count recognizes bounded Bamum Supplement words");
   Assert (I18N.Locales.Word_At
             (U (16#16800#) & U (16#16A38#) & " "
              & U (16#16801#), 1, "bax-Bamu") =
             U (16#16800#) & U (16#16A38#),
           "public locale word access preserves bounded Bamum Supplement letters");
   Assert (I18N.Locales.Word_Count
             (U (16#17000#) & U (16#187FB#) & " "
              & U (16#18D1E#), "txg-Tang") = 2,
           "public locale word count recognizes bounded Tangut words");
   Assert (I18N.Locales.Word_At
             (U (16#17000#) & U (16#187FB#) & " "
              & U (16#18D1E#), 1, "txg-Tang") =
             U (16#17000#) & U (16#187FB#),
           "public locale word access preserves bounded Tangut characters");
   Assert (I18N.Locales.Word_Count
             (U (16#18B00#) & U (16#18CD5#) & " "
              & U (16#18CFF#), "zkt-Kits") = 2,
           "public locale word count recognizes bounded Khitan words");
   Assert (I18N.Locales.Word_At
             (U (16#18B00#) & U (16#18CD5#) & " "
              & U (16#18CFF#), 1, "zkt-Kits") =
             U (16#18B00#) & U (16#18CD5#),
           "public locale word access preserves bounded Khitan characters");
   Assert (I18N.Locales.Word_Count
             (U (16#1B170#) & U (16#1B2FB#) & " "
              & U (16#1B171#), "zh-Nshu") = 2,
           "public locale word count recognizes bounded Nushu words");
   Assert (I18N.Locales.Word_At
             (U (16#1B170#) & U (16#1B2FB#) & " "
              & U (16#1B171#), 1, "zh-Nshu") =
             U (16#1B170#) & U (16#1B2FB#),
           "public locale word access preserves bounded Nushu characters");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#3B1#, 16#3B2#]) & " "
              & UTF8 ([16#41F#, 16#440#, 16#438#, 16#432#, 16#435#, 16#442#]),
              "el") = 2,
           "public locale word count recognizes bounded Greek and Cyrillic words");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#531#, 16#532#, 16#533#, 16#589#])
              & UTF8 ([16#534#, 16#535#]), "hy") = 2,
           "public locale word count recognizes bounded Armenian words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#12A0#, 16#121B#, 16#122D#, 16#1362#])
              & UTF8 ([16#1230#, 16#1208#]), 2, "am") =
             UTF8 ([16#1230#, 16#1208#]),
           "public locale word access recognizes bounded Ethiopic words");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#10E5#, 16#10D0#, 16#10E0#, 16#10D7#])
              & " "
              & UTF8 ([16#10E3#, 16#10DA#, 16#10D8#]), "ka") = 2,
           "public locale word count recognizes bounded Georgian words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#10D0#, 16#10D1#, 16#10D2#, 16#10FB#])
              & UTF8 ([16#10D3#, 16#10D4#]), 2, "ka") =
             UTF8 ([16#10D3#, 16#10D4#]),
           "public locale word access treats Georgian punctuation as a separator");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#928#, 16#92E#, 16#938#, 16#94D#, 16#924#, 16#947#])
              & " "
              & UTF8 ([16#9AC#, 16#9BE#, 16#982#, 16#9B2#, 16#9BE#])
              & " "
              & UTF8 ([16#E44#, 16#E17#, 16#E22#]),
              "hi") = 3,
           "public locale word count recognizes bounded Indic and Thai words");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#0A17#, 16#0A41#, 16#0A30#, 16#0A2E#, 16#0A41#, 16#0A16#])
              & " "
              & UTF8 ([16#0A97#, 16#0AC1#, 16#0A9C#, 16#0AB0#, 16#0ABE#, 16#0AA4#])
              & " "
              & UTF8 ([16#0B13#, 16#0B21#, 16#0B3C#, 16#0B3F#, 16#0B06#]),
              "pa") = 3,
           "public locale word count recognizes bounded Gurmukhi Gujarati and Odia words");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#0BA4#, 16#0BAE#, 16#0BBF#, 16#0BB4#, 16#0BCD#])
              & " "
              & UTF8 ([16#0C24#, 16#0C46#, 16#0C32#, 16#0C41#, 16#0C17#, 16#0C41#])
              & " "
              & UTF8 ([16#0C95#, 16#0CA8#, 16#0CCD#, 16#0CA8#, 16#0CA1#]),
              "ta") = 3,
           "public locale word count recognizes bounded Tamil Telugu and Kannada words");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#0D2E#, 16#0D32#, 16#0D2F#, 16#0D3E#, 16#0D33#, 16#0D02#])
              & " "
              & UTF8 ([16#0DC3#, 16#0DD2#, 16#0D82#, 16#0DC4#, 16#0DBD#])
              & " "
              & UTF8 ([16#0EA5#, 16#0EB2#, 16#0EA7#])
              & " "
              & UTF8 ([16#0F56#, 16#0F7C#, 16#0F51#])
              & " "
              & UTF8 ([16#1781#, 16#17D2#, 16#1798#, 16#17C2#, 16#179A#]),
              "ml") = 5,
           "public locale word count recognizes bounded Malayalam Sinhala Lao Tibetan and Khmer words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#1781#, 16#17D2#, 16#1798#, 16#17C2#, 16#179A#])
              & " "
              & UTF8 ([16#0F56#, 16#0F7C#, 16#0F51#]), 1, "km") =
              UTF8 ([16#1781#, 16#17D2#, 16#1798#, 16#17C2#, 16#179A#]),
           "public locale word access preserves bounded Khmer bytes");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#304B#, 16#306A#, 16#30AB#, 16#30CA#])
              & " " & UTF8 ([16#4E2D#, 16#6587#])
              & " " & UTF8 ([16#D55C#, 16#AD6D#]),
              "ja") = 3,
           "public locale word count recognizes bounded Japanese Chinese and Korean words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#304B#, 16#306A#, 16#30AB#, 16#30CA#])
              & " " & UTF8 ([16#4E2D#, 16#6587#])
              & " " & UTF8 ([16#D55C#, 16#AD6D#]),
              2, "zh") = UTF8 ([16#4E2D#, 16#6587#]),
           "public locale word access preserves bounded CJK UTF-8 bytes");
   Assert (I18N.Locales.Word_At
             ("l'amour can" & U (16#2019#) & "t alpha_beta",
              2, "en") =
             "can" & U (16#2019#) & "t",
           "public locale word access keeps apostrophes inside words");
   Assert (I18N.Locales.Word_At
             ("l'amour can" & U (16#2019#) & "t alpha_beta",
              3, "en") = "alpha_beta",
           "public locale word access keeps underscore inside words");
   Assert (I18N.Locales.Word_Count
             ("3.14 1,000 10:30", "en") = 3,
           "public locale word count keeps numeric punctuation inside words");
   Assert (I18N.Locales.Word_At
             ("3.14 1,000 10:30", 2, "en") = "1,000",
           "public locale word access preserves numeric group separators");
   Assert (I18N.Locales.Word_Count ("hello,world", "en") = 2,
           "public locale word count still separates nonnumeric commas");
   Assert (I18N.Locales.Word_At
             (U (16#0661#) & "." & U (16#0662#) & " x", 1, "ar") =
              U (16#0661#) & "." & U (16#0662#),
           "public locale word access keeps decimal points between bounded digits");
   Assert (I18N.Locales.Word_At
             (U (16#0661#) & U (16#066C#) & U (16#0662#)
              & U (16#0663#) & U (16#0664#) & U (16#066B#)
              & U (16#0665#) & " x", 1, "ar") =
              U (16#0661#) & U (16#066C#) & U (16#0662#)
              & U (16#0663#) & U (16#0664#) & U (16#066B#)
              & U (16#0665#),
           "public locale word access keeps Arabic numeric separators");
   Assert (I18N.Locales.Word_At
             (U (16#06F1#) & U (16#066C#) & U (16#06F2#)
              & U (16#06F3#) & U (16#06F4#) & U (16#066B#)
              & U (16#06F5#) & " x", 1, "fa") =
              U (16#06F1#) & U (16#066C#) & U (16#06F2#)
              & U (16#06F3#) & U (16#06F4#) & U (16#066B#)
              & U (16#06F5#),
           "public locale word access keeps Persian numeric separators");
   Assert (I18N.Locales.Word_At
             (U (16#FF11#) & "," & U (16#FF10#) & U (16#FF10#)
              & " x", 1, "ja") =
              U (16#FF11#) & "," & U (16#FF10#) & U (16#FF10#),
           "public locale word access keeps grouping commas between fullwidth digits");
   Assert (I18N.Locales.Word_At
             (U (16#1044#) & U (16#1042#) & ":"
              & U (16#1040#) & U (16#1040#) & " x", 1, "my") =
              U (16#1044#) & U (16#1042#) & ":"
              & U (16#1040#) & U (16#1040#),
           "public locale word access keeps time separators between Myanmar digits");
   Assert (I18N.Locales.Word_At
             (U (16#3007#) & "." & U (16#56DB#) & U (16#4E8C#)
              & " x", 1, "zh") =
              U (16#3007#) & "." & U (16#56DB#) & U (16#4E8C#),
           "public locale word access keeps decimal points between Han decimal digits");
   Assert (I18N.Locales.Word_At
             (U (16#0F24#) & U (16#0F22#) & ":"
              & U (16#0F20#) & U (16#0F20#) & " x", 1, "bo") =
              U (16#0F24#) & U (16#0F22#) & ":"
              & U (16#0F20#) & U (16#0F20#),
           "public locale word access keeps time separators between Tibetan digits");
   Assert (I18N.Locales.Word_At
             (U (16#0ED1#) & "," & U (16#0ED0#) & U (16#0ED0#)
              & " x", 1, "lo") =
              U (16#0ED1#) & "," & U (16#0ED0#) & U (16#0ED0#),
           "public locale word access keeps grouping commas between Lao digits");
   Assert (I18N.Locales.Word_Count
             (UTF8 ([16#FB2E#, 16#FB4F#]) & " "
              & UTF8 ([16#FEFB#, 16#FEFC#]), "he") = 2,
           "public locale word count recognizes bounded presentation forms");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FB2E#, 16#FB4F#]) & " "
              & UTF8 ([16#FEFB#, 16#FEFC#]), 2, "ar") =
             UTF8 ([16#FEFB#, 16#FEFC#]),
           "public locale word access preserves presentation-form bytes");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FC00#, 16#FC01#, 16#FC5A#]) & " "
              & UTF8 ([16#628#, 16#62C#]), 1, "ar") =
             UTF8 ([16#FC00#, 16#FC01#, 16#FC5A#]),
           "public locale word access preserves Arabic forms-A"
           & " isolated ligatures");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FBEA#, 16#FC64#, 16#FC80#, 16#FD3B#]) & " "
              & UTF8 ([16#628#, 16#62C#]), 1, "ar") =
             UTF8 ([16#FBEA#, 16#FC64#, 16#FC80#, 16#FD3B#]),
           "public locale word access preserves Arabic forms-A"
           & " two-letter ligatures");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FD50#, 16#FD80#, 16#FDF2#, 16#FDF9#]) & " "
              & UTF8 ([16#628#, 16#62C#]), 1, "ar") =
             UTF8 ([16#FD50#, 16#FD80#, 16#FDF2#, 16#FDF9#]),
           "public locale word access preserves Arabic forms-A"
           & " multi-letter ligatures");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FB00#, 16#FB01#, 16#FB02#, 16#FB03#,
                     16#FB04#, 16#FB05#, 16#FB06#]) & " x", 1, "en") =
             UTF8 ([16#FB00#, 16#FB01#, 16#FB02#, 16#FB03#,
                    16#FB04#, 16#FB05#, 16#FB06#]),
           "public locale word access preserves Latin alphabetic ligatures");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FF21#, 16#FF22#, 16#FF43#, 16#FF11#,
                     16#FF12#]) & " x", 1, "en") =
             UTF8 ([16#FF21#, 16#FF22#, 16#FF43#, 16#FF11#,
                    16#FF12#]),
           "public locale word access preserves fullwidth Latin words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#FF76#, 16#FF80#, 16#FF76#, 16#FF85#]) & " x",
              1, "ja") =
             UTF8 ([16#FF76#, 16#FF80#, 16#FF76#, 16#FF85#]),
           "public locale word access preserves halfwidth Katakana words");
   Assert (I18N.Locales.Word_At
             (UTF8 ([16#3131#, 16#314F#, 16#3134#, 16#314F#]) & " x",
              1, "ko") =
             UTF8 ([16#3131#, 16#314F#, 16#3134#, 16#314F#]),
           "public locale word access preserves Hangul compatibility Jamo words");
   Assert (I18N.Locales.Word_At ("alpha--beta", 2, "en") = "beta",
           "public locale word access treats punctuation as separators");
   Assert (I18N.Locales.Word_At ("alpha", 0, "en") = "",
           "public locale word access rejects zero indexes");
   Assert (I18N.Locales.Word_At ("alpha", 2, "en") = "",
           "public locale word access returns empty for missing words");
   Assert (Rendered (Runtime, "en_US", "label", Args) = "English US",
           "underscore request resolves canonical region locale");
   Assert (Rendered (Runtime, "EN-us", "title", Args) = "Default US",
           "mixed-case request resolves canonical default locale");
   Assert (Rendered (Runtime, "iw-IL", "title", Args) = "Hebrew",
           "deprecated Hebrew language alias falls back to he");
   Assert (Rendered (Runtime, "in-ID", "title", Args) = "Indonesian",
           "deprecated Indonesian language alias falls back to id");
   Assert (Rendered (Runtime, "sh-BA", "title", Args) = "Serbian Latin",
           "Serbo-Croatian alias expands through sr-Latn fallback");

   declare
      R : constant I18N.Runtime.Resolve_Result :=
        I18N.Runtime.Resolve (Runtime, "iw_IL", "title");
   begin
      Assert (R.Status = I18N.Runtime.Found,
              "alias request resolves through canonical parent locale");
      Assert (I18N.Runtime.Resolved_Locale (R) = "he",
              "resolved locale reports the canonical stored locale");
   end;
end Test_Locale_Canonicalization_And_Aliases;
