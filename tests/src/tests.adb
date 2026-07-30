with AUnit;
with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with AUnit.Reporter.Text;
with AUnit.Run;
with I18N.Platform_Tests.Suite;

--  AUnit's plain Test_Runner reports success however many assertions
--  failed, so a build server ticks a job green over a failing suite.
--  The outcome is carried in the exit status here instead.
procedure Tests is
   use type AUnit.Status;


   function Runner is
     new AUnit.Run.Test_Runner_With_Status (I18N.Platform_Tests.Suite.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status   : AUnit.Status;

begin
   Status := Runner (Reporter);
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (1);

   if Status /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
