with AUnit;
with AUnit.Test_Cases;

--  Standalone AUnit suite for the i18n platform engines: transliteration,
--  collation, case mapping, normalization, segmentation, calendar arithmetic
--  and names, display names, emoji annotations, person names, and RBNF
--  spellout. Every routine exercises a platform API directly through
--  AUnit.Assertions and has no dependency on the message-formatting layer,
--  which now lives in the separate `messages` crate.
package I18N.Platform_Tests is

   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   --  @param T Test case instance to identify.
   --  @return AUnit display name for the platform engine tests.
   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String;

   --  @param T Test case instance to populate.
   overriding procedure Register_Tests
     (T : in out Test_Case);

end I18N.Platform_Tests;
