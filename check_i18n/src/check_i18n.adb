with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Alire_Manifests;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Project_Tools.Tree_Checks;

procedure Check_I18N is
   use Ada.Text_IO;
   use GNAT.OS_Lib;

   Gnatprove_Check_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gnatprove"),
      4 => new String'("-P"),
      5 => new String'("i18n.gpr"),
      6 => new String'("--level=0"),
      7 => new String'("--mode=check"));
   Alr_Build_Args : constant Argument_List :=
     (1 => new String'("build"));
   Alr_Test_Args : constant Argument_List :=
     (1 => new String'("test"));
   Exec_Tests_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("./bin/tests"));
   Build_Tests_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("tests.gpr"));
   Build_Examples_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("examples/examples.gpr"));
   Gnatdoc_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gnatdoc"),
      4 => new String'("-P"),
      5 => new String'("i18n.gpr"));

   function Root_Directory return String is
      Current : constant String := Ada.Directories.Current_Directory;
   begin
      if Ada.Directories.Exists (Current & "/i18n.gpr") then
         return Current;
      elsif Ada.Directories.Exists (Current & "/../i18n.gpr") then
         return Ada.Directories.Full_Name (Current & "/..");
      else
         Put_Line (Standard_Error, "i18n root not found from " & Current);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Root_Directory;

   Root   : constant String := Root_Directory;
   Checks : constant Project_Tools.Release_Checks.Checker :=
     Project_Tools.Release_Checks.Create (Root);
   Errors : Natural := 0;

   procedure Error (Message : String) is
   begin
      Errors := Errors + 1;
      Put_Line (Standard_Error, "error: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Error;

   function Alr_Path return String is
   begin
      return Project_Tools.Processes.Locate_Command ("alr");
   end Alr_Path;

   function Gprbuild_Path return String is
   begin
      return Project_Tools.Processes.Locate_Command ("gprbuild");
   end Gprbuild_Path;

   function Gnatdoc_Path return String is
   begin
      return Project_Tools.Processes.Locate_Command ("gnatdoc");
   end Gnatdoc_Path;

   procedure Run_Check
     (Label   : String;
      Dir     : String;
      Program : String;
      Args    : Argument_List)
   is
   begin
      Project_Tools.Release_Checks.Run
        (Label   => Label,
         Dir     => Dir,
         Program => Program,
         Args    => Args,
         Quiet   => False);
   exception
      when Program_Error =>
         Error (Label & " failed");
   end Run_Check;

   procedure Check_Gnatprove is
   begin
      Run_Check
        ("run i18n GNATprove release check",
         Root,
         Alr_Path,
         Gnatprove_Check_Args);
   end Check_Gnatprove;

   procedure Run_Release_Builds is
   begin
      Run_Check ("build i18n library", Root, Alr_Path, Alr_Build_Args);
      Run_Check ("build i18n tests", Root & "/tests", Alr_Path, Build_Tests_Args);
      Run_Check ("run i18n tests", Root & "/tests", Alr_Path, Exec_Tests_Args);
      Run_Check ("build i18n examples", Root, Alr_Path, Build_Examples_Args);
      Run_Check ("build i18n through alr test action", Root, Alr_Path, Alr_Test_Args);
      Run_Check ("generate i18n GNATdoc", Root, Alr_Path, Gnatdoc_Args);
   end Run_Release_Builds;

   procedure Require_Text (Relative_Path : String; Pattern : String; Message : String) is
   begin
      Project_Tools.Release_Checks.Require_Text (Checks, Relative_Path, Pattern);
   exception
      when Program_Error =>
         Error (Message);
   end Require_Text;

   procedure Check_AUnit_Metrics is
      Search  : Ada.Directories.Search_Type;
      Item    : Ada.Directories.Directory_Entry_Type;
      Metrics : Project_Tools.AUnit_Checks.Suite_Metrics;
   begin
      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Root & "/tests/src",
         Pattern   => "i18n-runtime-tests-*.adb",
         Filter    => [Ada.Directories.Ordinary_File => True, others => False]);

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Text : constant String :=
              To_String
                (Project_Tools.Text.Read_Text_File
                   (Ada.Directories.Full_Name (Item)));
         begin
            Metrics.Section_Count := Metrics.Section_Count + 1;
            Metrics.Registration_Count :=
              Metrics.Registration_Count
              + Project_Tools.AUnit_Checks.Registration_Count (Text);
            Metrics.Assertion_Count :=
              Metrics.Assertion_Count
              + Project_Tools.AUnit_Checks.Assertion_Count (Text);
            Metrics.Test_Body_Count :=
              Metrics.Test_Body_Count
              + Project_Tools.AUnit_Checks.Test_Body_Count (Text);
         end;
      end loop;
      Ada.Directories.End_Search (Search);

      if Metrics.Section_Count < 6 then
         Error ("expected at least 6 I18N AUnit section bodies");
      end if;
      if Metrics.Registration_Count < 70 then
         Error ("expected at least 70 registered I18N AUnit tests");
      end if;
      if Metrics.Assertion_Count < 70 then
         Error ("expected at least 70 I18N AUnit assertions");
      end if;
   exception
      when others =>
         if Ada.Directories.More_Entries (Search) then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_AUnit_Metrics;

   procedure Check_Generated_Artifacts is
      Hygiene_Errors : Natural := 0;
   begin
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/tests/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/examples");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/docs");
      Errors := Errors + Hygiene_Errors;
   end Check_Generated_Artifacts;

begin
   Project_Tools.Processes.Require_Command
     ("alr", "alr executable not found on PATH");
   Project_Tools.Processes.Require_Command
     ("gprbuild", "gprbuild executable not found on PATH");

   Project_Tools.Alire_Manifests.Require_Pin_Free_Crate_Manifest
     (Root & "/alire.toml", "i18n");

   Project_Tools.Release_Checks.Require_File (Checks, "README.md");
   Project_Tools.Release_Checks.Require_File (Checks, "i18n.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/RELEASE_VERIFICATION.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/SPARK.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/API.md");
   Project_Tools.Release_Checks.Require_File (Checks, "tests/tests.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "examples/examples.gpr");

   Require_Text
     ("README.md",
      "docs/RELEASE_VERIFICATION.md",
      "README must point maintainers to release verification");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "check_i18n",
      "release verification must include check_i18n");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "release verification must include examples project build");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gnatprove -P i18n.gpr --level=0 --mode=check",
      "release verification must include GNATprove release check");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr test",
      "release verification must include Alire test action");
   Require_Text
     ("README.md",
      "docs/SPARK.md",
      "README must point maintainers to SPARK coverage");
   Require_Text
     ("docs/SPARK.md",
      "I18N.Result",
      "SPARK documentation must describe I18N.Result coverage");
   Require_Text
     ("alire.toml",
      "type = ""test""",
      "Alire manifest must define a test action");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gnatdoc -P i18n.gpr",
      "release verification must include GNATdoc command");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "private child",
      "public import rules must document private-child boundary");
   Require_Text
     ("tests/alire.toml",
      "project_tools",
      "i18n tests must use project_tools for shared tooling helpers");

   Check_AUnit_Metrics;
   Check_Generated_Artifacts;
   Run_Release_Builds;
   Check_Gnatprove;

   if Errors = 0 then
      Put_Line ("i18n checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Put_Line
        (Standard_Error,
         "i18n checks failed:" & Natural'Image (Errors) & " error(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
exception
   when Program_Error =>
      null;
end Check_I18N;
