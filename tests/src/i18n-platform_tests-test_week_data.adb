with I18N.Plural_Ranges;
with I18N.Plurals;
with I18N.Unit_Format;
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
   Assert (First_Day ("dv") = "fri", "Maldivian weeks start on Friday (a likely region)");
   Assert (First_Day ("zh-Hant") = "sun", "Traditional Chinese (Taiwan) weeks start on Sunday");
   Assert (First_Day ("pt") = "sun", "Brazilian weeks start on Sunday");
   Assert (First_Day ("zh") = "mon", "Chinese weeks start on Monday");
   Assert (First_Day ("sw") = "mon", "Swahili (Tanzania) weeks start on Monday");
   Assert (Minimal_Days ("de") = 4, "a German first week has four days of the year");
   Assert (Minimal_Days ("en-GB") = 4, "a British first week has four days of the year");
   Assert (Minimal_Days ("en") = 1, "a United States first week has one day of the year");
   Assert (Minimal_Days ("ja") = 1, "a Japanese first week has one day of the year");
   --  CLDR's plural ranges (supplemental data beside the week's).
   Assert (I18N.Plurals."=" (I18N.Plural_Ranges.Category ("ar", I18N.Plurals.One, I18N.Plurals.Two),
                             I18N.Plurals.Other),
           "an Arabic range from one to two is other");
   Assert (I18N.Plurals."=" (I18N.Plural_Ranges.Category ("fr-CA", I18N.Plurals.One, I18N.Plurals.One),
                             I18N.Plurals.One),
           "a French range within one stays one");
   Assert (I18N.Plurals."=" (I18N.Plural_Ranges.Category ("de", I18N.Plurals.Other, I18N.Plurals.One),
                             I18N.Plurals.One),
           "a German range ending in one is one");
   Assert (I18N.Plurals."=" (I18N.Plural_Ranges.Category ("ru", I18N.Plurals.Few, I18N.Plurals.Many),
                             I18N.Plurals.Many),
           "a Russian range takes its end's category");
   --  CLDR's coordinate units: a hemisphere around the degrees.
   declare
      function Hemisphere (Locale, Direction : String) return String is
         Found : Boolean;
         Text  : constant String :=
           I18N.Unit_Format.Pattern (Locale, "coordinate-" & Direction, "short", "other", Found);
      begin
         return (if Found then Text else "");
      end Hemisphere;
      --  U+5317 U+7DEF, "north latitude".
      Kita_I         : constant String :=
        [Character'Val (16#E5#), Character'Val (16#8C#), Character'Val (16#97#),
         Character'Val (16#E7#), Character'Val (16#B7#), Character'Val (16#AF#)];
      --  " з. д.", "west longitude".
      West_Longitude : constant String :=
        " " & [Character'Val (16#D0#), Character'Val (16#B7#)] & ". "
        & [Character'Val (16#D0#), Character'Val (16#B4#)] & ".";
   begin
      Assert (Hemisphere ("en", "north") = "{0} N", "English writes north as {0} N");
      Assert (Hemisphere ("de", "east") = "{0} O", "German writes east as {0} O");
      Assert (Hemisphere ("de-CH", "east") = "{0} O", "Swiss German inherits German's east");
      Assert (Hemisphere ("ja", "north") = Kita_I & "{0}", "Japanese writes north latitude before the degrees");
      Assert (Hemisphere ("ru", "west") = "{0}" & West_Longitude, "Russian abbreviates west longitude");
   end;
end Test_Week_Data;
