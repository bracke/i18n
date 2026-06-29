with AUnit;
with AUnit.Test_Cases;

--  Tests for the strengthened public runtime surface: shard loading, duplicate
--  policies, Load_Text, non-destructive validation, key resolution, argument
--  helper setters, generalized select branches, the plural-category API, and
--  bounded rendering.
package I18N.Runtime.Tests.Features is

   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   --  @param T Test case instance to identify.
   --  @return AUnit display name for the feature tests.
   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String;

   --  @param T Test case instance to populate.
   overriding procedure Register_Tests
     (T : in out Test_Case);

end I18N.Runtime.Tests.Features;
