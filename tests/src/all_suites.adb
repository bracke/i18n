with I18N.Runtime.Tests.Suite;

package body All_Suites is

   function Suite return Access_Test_Suite is
      Result : constant Access_Test_Suite := New_Suite;
   begin
      Result.Add_Test (I18N.Runtime.Tests.Suite.Suite);
      return Result;
   end Suite;

end All_Suites;