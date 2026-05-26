with I18N.Runtime.Tests.Strict;
with I18N.Runtime.Tests.Compilation;
with I18N.Runtime.Tests.Execution;
with I18N.Runtime.Tests.Diagnostics;
with I18N.Runtime.Tests.Corpus;
with I18N.Runtime.Tests.Release;

package body I18N.Runtime.Tests.Suite is

   function Suite
      return AUnit.Test_Suites.Access_Test_Suite
   is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      Result.Add_Test (new I18N.Runtime.Tests.Strict.Test_Case);
      Result.Add_Test (new I18N.Runtime.Tests.Compilation.Test_Case);
      Result.Add_Test (new I18N.Runtime.Tests.Execution.Test_Case);
      Result.Add_Test (new I18N.Runtime.Tests.Diagnostics.Test_Case);
      Result.Add_Test (new I18N.Runtime.Tests.Corpus.Test_Case);
      Result.Add_Test (new I18N.Runtime.Tests.Release.Test_Case);
      return Result;
   end Suite;

end I18N.Runtime.Tests.Suite;
