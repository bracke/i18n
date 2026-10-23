with I18N.Week_Data;  use I18N.Week_Data;

--  CLDR's weekData through the locale's region, as ICU answers (CLDR 48:
--  the United Arab Emirates start weeks on Monday).
separate (I18N.Platform_Tests)
procedure Test_Week_Data
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
begin
   Assert (First_Day ("en") = "sun", "English (United States) weeks start on Sunday");
   Assert (First_Day ("en-GB") = "mon", "British weeks start on Monday");
   Assert (First_Day ("de") = "mon", "German weeks start on Monday");
   Assert (First_Day ("ar-EG") = "sat", "Egyptian weeks start on Saturday");
   Assert (First_Day ("ar-AE") = "mon", "Emirati weeks start on Monday");
   Assert (First_Day ("fa") = "sat", "Persian (Iran) weeks start on Saturday");
   Assert (First_Day ("dv-MV") = "fri", "Maldivian weeks start on Friday");
   Assert (First_Day ("pt") = "sun", "Brazilian weeks start on Sunday");
   Assert (First_Day ("zh") = "mon", "Chinese weeks start on Monday");
   Assert (First_Day ("sw") = "mon", "Swahili (Tanzania) weeks start on Monday");
   Assert (Minimal_Days ("de") = 4, "a German first week has four days of the year");
   Assert (Minimal_Days ("en-GB") = 4, "a British first week has four days of the year");
   Assert (Minimal_Days ("en") = 1, "a United States first week has one day of the year");
   Assert (Minimal_Days ("ja") = 1, "a Japanese first week has one day of the year");
end Test_Week_Data;
