with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with AUnit.Reporter.Text;
with AUnit.Run;
with I18N.Platform_Tests.Suite;

procedure Tests is

   procedure Runner is
     new AUnit.Run.Test_Runner (I18N.Platform_Tests.Suite.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;

begin
   Runner (Reporter);
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (1);
end Tests;
