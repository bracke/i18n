with AUnit.Assertions;

package body I18N.Platform_Tests is

   use AUnit.Assertions;

   ---------------------------------------------------------------------------
   --  Platform engine routines (each a self-contained subunit; assertions
   --  reach AUnit.Assertions through the use clause above).
   ---------------------------------------------------------------------------

   procedure Test_Transliteration
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Collation
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Casing
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Normalization
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Segmentation
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Calendar_Math
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Calendar_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Display_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Emoji_Annotations
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Person_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;
   procedure Test_Spellout
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   ---------------------------------------------------------------------------
   --  AUnit plumbing.
   ---------------------------------------------------------------------------

   overriding function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N platform engine tests");
   end Name;

   overriding procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Transliteration'Access,
                        "Transliteration: rule engine, contexts, and calls");
      Register_Routine (T, Test_Collation'Access,
                        "Collation (UCA): sort keys, comparison, and locale "
                        & "tailoring");
      Register_Routine (T, Test_Casing'Access,
                        "Case mapping: lower/upper/title with SpecialCasing");
      Register_Routine (T, Test_Normalization'Access,
                        "Unicode normalization (UAX #15): NFC/NFD/NFKC/NFKD");
      Register_Routine (T, Test_Segmentation'Access,
                        "Text segmentation (UAX #29/#14): grapheme/word/"
                        & "sentence/line boundaries");
      Register_Routine (T, Test_Calendar_Math'Access,
                        "Calendar arithmetic: date conversion across calendars");
      Register_Routine (T, Test_Calendar_Names'Access,
                        "CLDR non-Gregorian calendar names from per-locale "
                        & "runtime shards");
      Register_Routine (T, Test_Display_Names'Access,
                        "CLDR display names, delimiters, and measurement "
                        & "from the runtime data file");
      Register_Routine (T, Test_Emoji_Annotations'Access,
                        "CLDR emoji annotations (names + keywords) from "
                        & "per-locale runtime shards");
      Register_Routine (T, Test_Person_Names'Access,
                        "CLDR person-name formatting (TR35) from per-locale "
                        & "runtime shards");
      Register_Routine (T, Test_Spellout'Access,
                        "RBNF spellout: numbers to words via the recursive "
                        & "rule interpreter");
   end Register_Tests;

end I18N.Platform_Tests;
