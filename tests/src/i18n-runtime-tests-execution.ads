with AUnit;
with AUnit.Test_Cases;

package I18N.Runtime.Tests.Execution is

   type Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   --  Return the AUnit display name for this test case.
   --
   --  @param T Test case instance to identify.
   --  @return AUnit display name for the execution regression tests.
   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String;

   --  Register execution regression tests with AUnit.
   --
   --  @param T Test case instance to populate.
   overriding procedure Register_Tests
     (T : in out Test_Case);

end I18N.Runtime.Tests.Execution;
