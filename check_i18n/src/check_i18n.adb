with Ada.Command_Line;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;
with Project_Tools.Text;
with Project_Tools.Tree_Checks;

--  Release gate for the i18n Unicode/CLDR platform: it builds the library, the
--  standalone platform test suite, and the CLDR data tools, runs the platform
--  tests and the CLDR data-boundary --check pipeline, and runs GNATprove and
--  GNATdoc. ICU message formatting was split into the sibling `messages` crate;
--  its release gate lives in ../messages/check_messages.
procedure Check_I18N is
   use Ada.Text_IO;
   use GNAT.OS_Lib;

   Gnatprove_Check_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gnatprove"),
      4 => new String'("-P"),
      5 => new String'("i18n.gpr"),
      6 => new String'("--level=0"),
      7 => new String'("--mode=check")];
   Alr_Build_Args : constant Argument_List :=
     [1 => new String'("build")];
   Exec_Tests_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("./bin/tests")];
   Build_Tests_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("tests.gpr")];
   Build_CLDR_Tools_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("cldr_tools.gpr")];
   Check_CLDR_Args : constant Argument_List :=
     [1 => new String'("--check")];
   Gnatdoc_Args : constant Argument_List :=
     [1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gnatdoc"),
      4 => new String'("-P"),
      5 => new String'("i18n.gpr")];

   function Root_Directory return String is
      Root : constant String :=
        Project_Tools.Files.Find_Root_Upward (".", "i18n.gpr");
   begin
      if Root'Length = 0 then
         Put_Line (Standard_Error, "i18n root not found");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      return Root;
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

   procedure Run_Release_Builds is
   begin
      Run_Check ("build i18n library", Root, Alr_Path, Alr_Build_Args);
      Run_Check ("build i18n platform tests", Root & "/tests", Alr_Path, Build_Tests_Args);
      Run_Check ("run i18n platform tests", Root & "/tests", Alr_Path, Exec_Tests_Args);
      Run_Check ("build i18n CLDR data tools", Root & "/cldr", Alr_Path, Build_CLDR_Tools_Args);
      --  Every one of these re-runs a pipeline stage against the vendored CLDR
      --  tree and compares the result with what is checked in. Without the
      --  tree there is nothing to compare against, so they are skipped with
      --  the file requirements rather than failing for the same reason.
      if Project_Tools.Processes.Has_Argument ("--no-upstream") then
         Ada.Text_IO.Put_Line
           ("note: --no-upstream, skipping 7 CLDR pipeline stage checks");
      else
         Run_Check
           ("check i18n CLDR upstream source inventory",
            Root & "/cldr",
            Root & "/cldr/bin/check_cldr_sources",
            Check_CLDR_Args);
         Run_Check
           ("check i18n IANA tzdb source inventory",
            Root & "/cldr",
            Root & "/cldr/bin/check_tzdb_sources",
            Check_CLDR_Args);
         Run_Check
           ("check generated i18n CLDR staged export",
            Root & "/cldr",
            Root & "/cldr/bin/generate_cldr_export",
            Check_CLDR_Args);
         Run_Check
           ("check imported i18n CLDR raw data",
            Root & "/cldr",
            Root & "/cldr/bin/import_cldr_raw",
            Check_CLDR_Args);
         Run_Check
           ("check extracted i18n CLDR normalized data",
            Root & "/cldr",
            Root & "/cldr/bin/extract_cldr_normalized",
            Check_CLDR_Args);
         Run_Check
           ("check imported i18n CLDR subset",
            Root & "/cldr",
            Root & "/cldr/bin/import_cldr_subset",
            Check_CLDR_Args);
         Run_Check
           ("check generated i18n CLDR data",
            Root & "/cldr",
            Root & "/cldr/bin/generate_cldr_data",
            Check_CLDR_Args);
      end if;

      Run_Check
        ("run i18n GNATprove release check",
         Root,
         Alr_Path,
         Gnatprove_Check_Args);
      Run_Check ("generate i18n GNATdoc", Root, Alr_Path, Gnatdoc_Args);
   end Run_Release_Builds;

   procedure Check_Generated_Artifacts is
      Hygiene_Errors : Natural := 0;
   begin
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/tests/src");
      Project_Tools.Tree_Checks.Check_No_Generated_Python
        (Hygiene_Errors, Root & "/docs");
      Errors := Errors + Hygiene_Errors;
   end Check_Generated_Artifacts;

   procedure Check_ICU_CLDR_Completion_Checklist is
      Path : constant String := Root & "/docs/ICU_CLDR_COMPLETION_CHECKLIST.md";
      Text : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Has_Unresolved : constant Boolean :=
        Project_Tools.Text.Contains (Text, "- [ ]");
      Claims_Complete : constant Boolean :=
        Project_Tools.Files.Has_Line (Path, "Overall status: COMPLETE");
   begin
      if Claims_Complete and then Has_Unresolved then
         Error
           ("ICU/CLDR completion checklist claims COMPLETE while unresolved items remain");
      end if;

      if not Claims_Complete
        and then not Project_Tools.Files.Has_Line
          (Path, "Overall status: INCOMPLETE")
      then
         Error
           ("ICU/CLDR completion checklist must state COMPLETE or INCOMPLETE");
      end if;
   exception
      when others =>
         Error ("failed to validate ICU/CLDR completion checklist");
   end Check_ICU_CLDR_Completion_Checklist;

begin
   Project_Tools.Processes.Require_Command
     ("alr", "alr executable not found on PATH");

   --  File inventory: the platform crate's structural surface.
   Project_Tools.Release_Checks.Require_File (Checks, "README.md");
   Project_Tools.Release_Checks.Require_File (Checks, "i18n.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.ads");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.h");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/API.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/SPARK.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/ICU_CLDR_COMPLETION_CHECKLIST.md");
   Project_Tools.Release_Checks.Require_File (Checks, "src/i18n-cldr_data.ads");
   Project_Tools.Release_Checks.Require_File (Checks, "src/i18n-cldr_data.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/CLDR_DATA.md");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/cldr_tools.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/check_cldr_sources.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/check_tzdb_sources.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/generate_cldr_export.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/import_cldr_raw.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/extract_cldr_normalized.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/import_cldr_subset.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/generate_cldr_data.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "tests/tests.gpr");
   --  The vendored CLDR tree and everything derived from it are deliberately
   --  untracked: upstream is roughly a gigabyte, and the pinned data it
   --  produces is regenerated rather than reviewed. A checkout without it can
   --  still be checked -- the generated Ada sources are committed -- so
   --  --no-upstream drops these requirements and says so, rather than the
   --  release gate being unsatisfiable anywhere the tree is absent.
   if Project_Tools.Processes.Has_Argument ("--no-upstream") then
      Ada.Text_IO.Put_Line
        ("note: --no-upstream, skipping"
         & Integer'Image (12)
         & " vendored-CLDR file checks");
   else
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/source_manifest.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/source_files.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/cldr_export.jsonl");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/tzdb/source_manifest.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/tzdb/tzdata.zi");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/tzdb/zone1970.tab");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/tzdb/zone.tab");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/upstream/tzdb/leapseconds");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/raw/cldr_records.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/raw/coverage.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/import/normalized_cldr.txt");
      Project_Tools.Release_Checks.Require_File (Checks, "cldr/data/cldr_subset.txt");
   end if;

   Check_ICU_CLDR_Completion_Checklist;
   Check_Generated_Artifacts;
   Run_Release_Builds;

   if Errors = 0 then
      Put_Line ("i18n platform release checks passed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Put_Line
        (Standard_Error,
         "i18n platform release checks failed:" & Natural'Image (Errors) & " error(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Check_I18N;
