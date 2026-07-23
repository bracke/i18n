with AUnit.Test_Cases;

package body I18N.Platform_Tests.Suite is

   function Suite
      return AUnit.Test_Suites.Access_Test_Suite
   is
      type Test_Case_Access is access all AUnit.Test_Cases.Test_Case'Class;
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test
        (Test_Case_Access'(new I18N.Platform_Tests.Test_Case));
      return Result;
   end Suite;

end I18N.Platform_Tests.Suite;
