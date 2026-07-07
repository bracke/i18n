with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Exceptions;
with Ada.Text_IO;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Suites;
with I18N.Runtime.Tests.Corpus;
with I18N.Runtime.Tests.Compilation;
with I18N.Runtime.Tests.Diagnostics;
with I18N.Runtime.Tests.Execution;
with I18N.Runtime.Tests.Features;
with I18N.Runtime.Tests.Release;
with I18N.Runtime.Tests.Strict;

procedure Tests is

   function To_Lower (Value : String) return String is
      Lowered : String (Value'Range) := Value;
   begin
      for I in Lowered'Range loop
         Lowered (I) := Ada.Characters.Handling.To_Lower (Lowered (I));
      end loop;

      return Lowered;
   end To_Lower;

   Filtered_Suite : Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.To_Unbounded_String ("all");
   Should_Run     : Boolean := True;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Name   : constant String :=
        To_Lower
          (Ada.Strings.Unbounded.To_String (Filtered_Suite));
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      if Name = "all" or else Name = "" then
         Result.Add_Test (new I18N.Runtime.Tests.Strict.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Compilation.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Execution.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Diagnostics.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Corpus.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Release.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Features.Test_Case);

      elsif Name = "parser" then
         Result.Add_Test (new I18N.Runtime.Tests.Strict.Test_Case);

      elsif Name = "validation" then
         Result.Add_Test (new I18N.Runtime.Tests.Strict.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Compilation.Test_Case);
         Result.Add_Test (new I18N.Runtime.Tests.Release.Test_Case);

      elsif Name = "strict" then
         Result.Add_Test (new I18N.Runtime.Tests.Strict.Test_Case);

      elsif Name = "compilation" then
         Result.Add_Test (new I18N.Runtime.Tests.Compilation.Test_Case);

      elsif Name = "execution" then
         Result.Add_Test (new I18N.Runtime.Tests.Execution.Test_Case);

      elsif Name = "diagnostics" then
         Result.Add_Test (new I18N.Runtime.Tests.Diagnostics.Test_Case);

      elsif Name = "corpus" then
         Result.Add_Test (new I18N.Runtime.Tests.Corpus.Test_Case);

      elsif Name = "release" then
         Result.Add_Test (new I18N.Runtime.Tests.Release.Test_Case);

      elsif Name = "features" then
         Result.Add_Test (new I18N.Runtime.Tests.Features.Test_Case);

      else
         raise Program_Error with "Unknown suite: " & Name;
      end if;

      return Result;
   end Suite;

   procedure Runner is new AUnit.Run.Test_Runner (Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;

   procedure Parse_Arguments;

   procedure Parse_Arguments is
      I : Positive := 1;
   begin
      while I <= Ada.Command_Line.Argument_Count loop
         declare
            Raw_Arg : constant String := Ada.Command_Line.Argument (I);
            Arg     : constant String := To_Lower (Raw_Arg);
         begin
            if Arg'Length > 8 and then
              Ada.Strings.Fixed.Index (Arg, "--suite=") = 1
            then
               Filtered_Suite :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Arg (Arg'First + 8 .. Arg'Last));
            elsif Arg = "--suite" then
               if I = Ada.Command_Line.Argument_Count then
                  raise Program_Error with "--suite requires a value";
               end if;
               I := I + 1;
               Filtered_Suite :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (To_Lower (Ada.Command_Line.Argument (I)));
            elsif Arg = "--verbose" then
               null;
            elsif Arg = "--help" or else Arg = "-h" then
               Ada.Text_IO.Put_Line
                 ("Usage: ./bin/tests [--suite=<name>|--suite <name>] "
                  & "[--verbose]");
               Ada.Text_IO.Put_Line
                 ("Available suites: all, strict, compilation, execution, "
                  & "diagnostics, corpus, release, features, validation, parser");
               Ada.Command_Line.Set_Exit_Status (0);
               Should_Run := False;
               return;
            else
               raise Program_Error with "Unknown argument: " & Raw_Arg;
            end if;
         end;

         I := I + 1;
      end loop;
   end Parse_Arguments;

begin
   Parse_Arguments;
   if Should_Run then
      Runner (Reporter);
   end if;
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (1);
end Tests;
