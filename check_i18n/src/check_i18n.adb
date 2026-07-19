with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Alire_Manifests;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.JSON;
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
      5 => new String'("examples/examples.gpr"),
      6 => new String'("-j1"));
   No_Args : constant Argument_List (1 .. 0) := (others => null);
   Build_Benchmarks_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("benchmarks/benchmarks.gpr"),
      6 => new String'("-j1"));
   Build_CLDR_Tools_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("cldr_tools.gpr"));
   Build_Conformance_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gprbuild"),
      4 => new String'("-P"),
      5 => new String'("conformance/conformance.gpr"));
   Run_Benchmarks_Args : constant Argument_List :=
     (1 => new String'("--smoke"));
   Check_CLDR_Args : constant Argument_List :=
     (1 => new String'("--check"));
   Gnatdoc_Args : constant Argument_List :=
     (1 => new String'("exec"),
      2 => new String'("--"),
      3 => new String'("gnatdoc"),
      4 => new String'("-P"),
      5 => new String'("i18n.gpr"));

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

   procedure Check_Gnatprove is
   begin
      Run_Check
        ("run i18n GNATprove release check",
         Root,
         Alr_Path,
         Gnatprove_Check_Args);
   end Check_Gnatprove;

   procedure Check_Example_Output is
      use Ada.Strings.Unbounded;

      LF   : constant String := (1 => ASCII.LF);
      Euro : constant String :=
        Character'Val (16#E2#) & Character'Val (16#82#)
        & Character'Val (16#AC#);
      Yen : constant String :=
        Character'Val (16#C2#) & Character'Val (16#A5#);
      Per_Mille : constant String :=
        Character'Val (16#E2#) & Character'Val (16#80#)
        & Character'Val (16#B0#);
      Arabic_Number : constant String :=
        Character'Val (16#D9#) & Character'Val (16#A1#)
        & Character'Val (16#D9#) & Character'Val (16#AC#)
        & Character'Val (16#D9#) & Character'Val (16#A2#)
        & Character'Val (16#D9#) & Character'Val (16#A3#)
        & Character'Val (16#D9#) & Character'Val (16#A4#)
        & Character'Val (16#D9#) & Character'Val (16#AC#)
        & Character'Val (16#D9#) & Character'Val (16#A5#)
        & Character'Val (16#D9#) & Character'Val (16#A6#)
        & Character'Val (16#D9#) & Character'Val (16#A7#)
        & Character'Val (16#D9#) & Character'Val (16#AB#)
        & Character'Val (16#D9#) & Character'Val (16#A8#)
        & Character'Val (16#D9#) & Character'Val (16#A9#);
      Reiwa_Date : constant String :=
        Character'Val (16#E4#) & Character'Val (16#BB#)
        & Character'Val (16#A4#) & Character'Val (16#E5#)
        & Character'Val (16#92#) & Character'Val (16#8C#)
        & " 6" & Character'Val (16#E5#) & Character'Val (16#B9#)
        & Character'Val (16#B4#) & "2" & Character'Val (16#E6#)
        & Character'Val (16#9C#) & Character'Val (16#88#)
        & "29" & Character'Val (16#E6#) & Character'Val (16#97#)
        & Character'Val (16#A5#);
      Buddhist_Date : constant String :=
        Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#92#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#99#)
        & Character'Val (16#20#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#81#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#B8#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#A1#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#A0#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#B2#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#9E#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#B1#)
        & Character'Val (16#E0#) & Character'Val (16#B8#)
        & Character'Val (16#99#) & Character'Val (16#E0#)
        & Character'Val (16#B8#) & Character'Val (16#98#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#8C#) & Character'Val (16#20#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#92#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#95#)
        & Character'Val (16#E0#) & Character'Val (16#B9#)
        & Character'Val (16#96#) & Character'Val (16#E0#)
        & Character'Val (16#B9#) & Character'Val (16#97#);

      procedure Expect_Example
        (Name          : String;
         Expected      : String;
         Prefix_Only   : Boolean := False)
      is
         Output : Project_Tools.Processes.Unbounded_String;
      begin
         if not Project_Tools.Files.File_Contains
           (Root & "/examples/EXPECTED_OUTPUT.md",
            "./examples/bin/" & Name)
         then
            Error ("example command is missing from EXPECTED_OUTPUT.md: " & Name);
         end if;
         if not Project_Tools.Files.File_Contains
           (Root & "/examples/EXPECTED_OUTPUT.md", Expected)
         then
            Error ("example expected output is missing from EXPECTED_OUTPUT.md: " & Name);
         end if;

         Project_Tools.Processes.Run
           (Label   => "run i18n example " & Name,
            Dir     => Root,
            Program => Root & "/examples/bin/" & Name,
            Args    => No_Args,
            Output  => Output,
            Quiet   => True);

         declare
            Text : constant String := To_String (Output);
         begin
            if Prefix_Only then
               if Text'Length < Expected'Length
                 or else Text (Text'First .. Text'First + Expected'Length - 1)
                         /= Expected
               then
                  Error ("example output prefix drifted for " & Name);
               end if;
            elsif Text /= Expected then
               Error ("example output drifted for " & Name);
            end if;
         end;
      exception
         when Program_Error =>
            Error ("example failed: " & Name);
      end Expect_Example;
   begin
      Expect_Example
        ("hello_world",
         "hello world: Hello, Ada!" & LF);
      Expect_Example
        ("basic_render",
         "basic: Hello, Ada!" & LF);
      Expect_Example
        ("public_api_example",
         "public API render: Servus, Ada!" & LF);
      Expect_Example
        ("public_api_sealed",
         "public API sealed smoke: SUCCESS" & LF);
      Expect_Example
        ("plural_render",
         "plural one: One item" & LF
         & "plural other: 5 items" & LF);
      Expect_Example
        ("select_render",
         "select male: Tomcat" & LF
         & "select fallback branch: Unknown pet" & LF);
      Expect_Example
        ("selectordinal_render",
         "ordinal one: 1st place" & LF
         & "ordinal other: 4th place" & LF
         & "ordinal many: 8o posto speciale" & LF);
      Expect_Example
        ("nested_message_render",
         "nested select/plural: Grace uploaded 2 files" & LF);
      Expect_Example
        ("number_formatting",
         "number en: Number: 12,345.67" & LF
         & "number de: Zahl: 12.345,67" & LF
         & "number percent: Percent: 13%" & LF
         & "number permille: Permille: 125" & Per_Mille & LF
         & "number compact: Compact: 12.3K" & LF
         & "number scientific: Scientific: 1.23E+4" & LF
         & "number engineering: Engineering: 12.35E+3" & LF
         & "number spellout: Spellout: forty-two" & LF
         & "number trailing: Trailing stripped: 42" & LF
         & "number accounting: Accounting number: (12,345)" & LF
         & "number scale: Scaled: 12,345,670.00" & LF
         & "number arabic digits: Arabic digits: " & Arabic_Number & LF
         & "number indian grouping: Indian grouping: 12,34,567.89" & LF);
      Expect_Example
        ("currency_formatting",
         "currency en: Total: $1,234.50" & LF
         & "currency de: Summe: 1.234,50 " & Euro & LF
         & "currency name: Name: 1,234.50 US dollars" & LF
         & "currency narrow: Narrow: $1,234.50" & LF
         & "currency iso: ISO: USD 1,234.50" & LF
         & "currency cash: Cash: CHF 1.05" & LF
         & "currency accounting: Accounting: ($1,234.50)" & LF
         & "currency yen: Yen: " & Yen & "1,234" & LF);
      Expect_Example
        ("date_formatting",
         "date en: Date: February 29, 2024" & LF
         & "date de: Datum: Donnerstag, 29. Februar 2024" & LF
         & "date skeleton: Date skeleton: Feb 29, 2024" & LF
         & "date numeric skeleton: Numeric skeleton: 2024 02 29" & LF
         & "date japanese calendar: Japanese calendar: " & Reiwa_Date & LF
         & "date buddhist calendar: Buddhist calendar: "
         & Buddhist_Date & LF
         & "date locale week: Locale week fields: 2016/1/1/2016" & LF
         & "date persian calendar: Persian calendar: AP 1403 01 01" & LF);
      Expect_Example
        ("time_formatting",
         "time short: Time: 09:05" & LF
         & "time long: Time with seconds: 09:05:07" & LF
         & "time skeleton: Time skeleton: 09:05:07 AM" & LF
         & "time fraction: Fractional time: 09:05:07.123" & LF
         & "time zone: Zoned time: 09:05 EST" & LF
         & "time zone widths: Zone widths: "
         & "GMT-04:00|-04:00|-04:00|America/New_York" & LF
         & "time utc widths: UTC widths: Z|+00:00|UTC" & LF
         & "time datetime long: Long datetime: February 29, 2024 21:30:00"
         & LF
         & "time datetime full: Full datetime: Thursday, February 29, 2024 "
         & "21:30:00" & LF);
      Expect_Example
        ("domain_formatting",
         "domain duration: Duration: 1:01:01" & LF
         & "domain bytes: Size: 2 TiB" & LF
         & "domain unit: Distance: 1.5 kilometers" & LF
         & "domain rate: Rate: 1.5 kilometers per hour" & LF
         & "domain short rate: Short rate: 1.5 km/h" & LF
         & "domain relative: When: 3 days ago" & LF
         & "domain relative de: Wann: vor 3 Tagen" & LF
         --  CLDR en listPattern standard "end" is "{0}, and {1}" -- the serial
         --  comma is in the data, not a house style choice.
         & "domain list: List: red, green, and blue" & LF
         & "domain list de: Liste: red, green und blue" & LF);
      Expect_Example
        ("locale_fallback",
         "exact de-AT: Servus, Ada!" & LF
         & "parent de: 3 Artikel" & LF
         & "default en: Default fallback text for Ada." & LF);
      Expect_Example
        ("fallback_chain",
         "fallback de-AT exact: Servus, Ada!" & LF
         & "fallback de parent: 3 Artikel" & LF
         & "fallback default en: Default fallback text for Ada." & LF);
      Expect_Example
        ("default_locale_key",
         "unqualified catalog key uses default locale: "
         & "Unqualified default-locale text for Ada." & LF);
      Expect_Example
        ("equals_in_value",
         "equals in catalog value: "
         & "A value may contain = after the first separator." & LF);
      Expect_Example
        ("empty_message",
         "empty message status: SUCCESS" & LF
         & "empty message length: 0" & LF);
      Expect_Example
        ("missing_key",
         "missing key: MISSING_KEY" & LF);
      Expect_Example
        ("missing_argument",
         "missing argument: MISSING_ARGUMENT" & LF);
      Expect_Example
        ("invalid_argument",
         "invalid numeric argument: INVALID_ARGUMENT" & LF);
      Expect_Example
        ("invalid_catalog",
         "duplicate catalog valid: FALSE" & LF
         & "render after invalid catalog: EXECUTION_ERROR" & LF
         & "syntax catalog valid: FALSE" & LF);
      Expect_Example
        ("invalid_catalog_fields",
         "empty locale valid: FALSE" & LF
         & "empty key valid: FALSE" & LF
         & "empty default locale valid: FALSE" & LF);
      Expect_Example
        ("status_handling",
         "success status: success => Hello, Ada!" & LF
         & "missing argument status: required render argument was not supplied"
         & LF
         & "missing key status: message key not found after locale fallback"
         & LF);
      Expect_Example
        ("diagnostics_non_interference",
         "trace callback cannot affect render: Hello, Ada!" & LF
         & "diagnostic count: 0" & LF);
      Expect_Example
        ("diagnostics_inspection",
         "render status: MISSING_ARGUMENT" & LF
         & "has missing-variable diagnostic: TRUE" & LF
         & "diagnostic count: 1" & LF
         & "diagnostic 1: MISSING_VARIABLE key=name message=",
         Prefix_Only => True);
      Expect_Example
        ("reuse_runtime",
         "first render: Hello, Ada!" & LF
         & "second render: 7 Artikel" & LF);
      Expect_Example
        ("argument_lifecycle",
         "has name after set: TRUE" & LF
         & "name value: Ada" & LF
         & "has name after clear: FALSE" & LF);
   end Check_Example_Output;

   procedure Run_Release_Builds is
   begin
      Run_Check ("build i18n library", Root, Alr_Path, Alr_Build_Args);
      Run_Check ("build i18n tests", Root & "/tests", Alr_Path, Build_Tests_Args);
      Run_Check ("run i18n tests", Root & "/tests", Alr_Path, Exec_Tests_Args);
      Run_Check ("build i18n examples", Root, Alr_Path, Build_Examples_Args);
      Check_Example_Output;
      Run_Check ("build i18n benchmarks", Root, Alr_Path, Build_Benchmarks_Args);
      Run_Check ("build i18n CLDR data tools", Root & "/cldr", Alr_Path, Build_CLDR_Tools_Args);
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
      Run_Check
        ("build i18n ICU/CLDR conformance harness",
         Root,
         Alr_Path,
         Build_Conformance_Args);
      Run_Check
        ("run i18n ICU/CLDR conformance harness",
         Root,
         Root & "/conformance/bin/check_conformance",
         No_Args);
      Run_Check
        ("run i18n benchmark smoke",
         Root,
         Root & "/benchmarks/bin/render_benchmarks",
         Run_Benchmarks_Args);
      if not Project_Tools.Processes.Has_Argument ("--skip-alr-test") then
         Run_Check ("build i18n through alr test action", Root, Alr_Path, Alr_Test_Args);
      end if;
      Run_Check ("generate i18n GNATdoc", Root, Alr_Path, Gnatdoc_Args);
   end Run_Release_Builds;

   procedure Require_Text (Relative_Path : String; Pattern : String; Message : String) is
      Sibling_Prefix : constant String := "-";
   begin
      if Project_Tools.Files.File_Contains (Root & "/" & Relative_Path, Pattern) then
         return;
      end if;

      --  A body split into `separate` subunits still covers what the parent
      --  used to: the text moved to a sibling file, it did not disappear.
      --  Accept it there rather than making every coverage requirement name
      --  the subunit that happens to hold it today.
      declare
         Dir  : constant String :=
           Ada.Directories.Containing_Directory (Root & "/" & Relative_Path);
         Base : constant String :=
           Ada.Directories.Base_Name (Relative_Path);
         Subunits : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree (Dir, Base & Sibling_Prefix & "*.adb");
      begin
         for Path of Subunits loop
            if Project_Tools.Files.File_Contains
              (Ada.Strings.Unbounded.To_String (Path), Pattern)
            then
               return;
            end if;
         end loop;
      end;

      Project_Tools.Release_Checks.Require_Text (Checks, Relative_Path, Pattern);
   exception
      when Program_Error =>
         Error (Message);
   end Require_Text;

   procedure Forbid_Text (Relative_Path : String; Pattern : String; Message : String) is
   begin
      if Project_Tools.Files.File_Contains (Root & "/" & Relative_Path, Pattern) then
         Project_Tools.Release_Checks.Fail
           (Relative_Path & " must not contain: " & Pattern);
      end if;
   exception
      when Program_Error =>
         Error (Message);
   end Forbid_Text;

   procedure Require_JSON_Field
     (Relative_Path : String;
      Field         : String;
      Expected      : String;
      Message       : String)
   is
      Text : constant String :=
        Ada.Strings.Unbounded.To_String
          (Project_Tools.Text.Read_Text_File (Root & "/" & Relative_Path));
      Value : constant String := Project_Tools.JSON.Field_Value (Text, Field);
   begin
      if Value /= Expected then
         Error (Message);
      end if;
   exception
      when others =>
         Error (Message);
   end Require_JSON_Field;

   procedure Check_AI_JSON_Metadata is
   begin
      Require_JSON_Field
        ("ai/API_MANIFEST.json",
         "project",
         "ICU Messages Ada",
         "AI API manifest must be parseable JSON with the expected project name");
      Require_JSON_Field
        ("ai/API_MANIFEST.json",
         "language",
         "Ada 2022",
         "AI API manifest must be parseable JSON with the expected language");
      Require_JSON_Field
        ("ai/EXAMPLE_CATALOG.json",
         "example_project",
         "examples/examples.gpr",
         "AI example catalog must be parseable JSON with the example project");
      Require_JSON_Field
        ("ai/EXAMPLE_CATALOG.json",
         "primary_catalog",
         "examples/catalogs/messages.catalog",
         "AI example catalog must be parseable JSON with the primary catalog");
      Require_JSON_Field
        ("ai/FILE_ROLE_MAP.json",
         "project",
         "ICU Messages Ada",
         "AI file role map must be parseable JSON with the expected project name");
      Require_JSON_Field
        ("ai/FILE_ROLE_MAP.json",
         "version_contract",
         "v1.1.0",
         "AI file role map must be parseable JSON with the release version");
   end Check_AI_JSON_Metadata;

   procedure Check_Alire_Publication_Readiness is
   begin
      begin
         Project_Tools.Alire_Manifests.Require_Pin_Free_Crate_Manifest
           (Root & "/alire.toml", "i18n");
      exception
         when Program_Error =>
            Error ("Alire release manifest must be pin-free and named i18n");
      end;

      Project_Tools.Release_Checks.Require_File (Checks, "alire.toml");
      Project_Tools.Release_Checks.Require_File (Checks, "i18n.gpr");
      Project_Tools.Release_Checks.Require_File (Checks, "LICENSE");

      Require_Text
        ("alire.toml",
         "description = ",
         "Alire manifest must declare a crate description");
      Require_Text
        ("alire.toml",
         "version = ""1.1.0""",
         "Alire manifest version must match the documented release version");
      Require_Text
        ("alire.toml",
         "authors = [",
         "Alire manifest must declare authors");
      Require_Text
        ("alire.toml",
         "maintainers = [",
         "Alire manifest must declare maintainers");
      Require_Text
        ("alire.toml",
         "maintainers-logins = [",
         "Alire manifest must declare maintainer logins");
      Require_Text
        ("alire.toml",
         "licenses = ""MIT""",
         "Alire manifest must declare the MIT license");
      Require_Text
        ("alire.toml",
         "tags = [",
         "Alire manifest must declare search tags");
      Require_Text
        ("alire.toml",
         "project-files = [""i18n.gpr""]",
         "Alire manifest must publish only the library project file");
      Require_Text
        ("alire.toml",
         "gnat = "">=12""",
         "Alire manifest must declare the supported GNAT dependency");
      Require_Text
        ("alire.toml",
         "type = ""test""",
         "Alire manifest must define a test action");
      Require_Text
        ("alire.toml",
         "check_i18n",
         "Alire test action must route through the project_tools-based check_i18n guard");
      Forbid_Text
        ("alire.toml",
         "tests.gpr",
         "Alire manifest must not publish the test project as a primary project");
      Forbid_Text
        ("alire.toml",
         "examples.gpr",
         "Alire manifest must not publish the examples project as a primary project");

      Require_Text
        ("LICENSE",
         "MIT License",
         "LICENSE must contain the MIT license text");
      Require_Text
        ("i18n.gpr",
         "for Library_Name use ""I18n""",
         "i18n.gpr must define the published library project");
      Require_Text
        ("docs/PACKAGING.md",
         "Publication readiness audit",
         "packaging docs must describe the Alire publication readiness audit");
      Require_Text
        ("docs/RELEASE_VERIFICATION.md",
         "Alire publication readiness audit",
         "release verification docs must describe the Alire publication readiness audit");
      Require_Text
        ("docs/RELEASE_CHECKLIST.md",
         "Alire publication readiness audit",
         "release checklist must include the Alire publication readiness audit");
      Require_Text
        ("README.md",
         "v1.1.0",
         "README must match the Alire crate release version");
      Require_Text
        ("docs/API.md",
         "v1.1.0",
         "API documentation must match the Alire crate release version");
      Require_Text
        ("docs/PACKAGING.md",
         "version = ""1.1.0""",
         "packaging documentation must match the Alire crate release version");
   end Check_Alire_Publication_Readiness;

   procedure Check_AUnit_Metrics is
      Metrics : constant Project_Tools.AUnit_Checks.Suite_Metrics :=
        Project_Tools.AUnit_Checks.Collect_Suite_Metrics
          (Root & "/tests/src", "i18n-runtime-tests-*.adb");
   begin
      if Metrics.Section_Count < 6 then
         Error ("expected at least 6 I18N AUnit section bodies");
      end if;
      if Metrics.Registration_Count < 70 then
         Error ("expected at least 70 registered I18N AUnit tests");
      end if;
      if Metrics.Assertion_Count < 70 then
         Error ("expected at least 70 I18N AUnit assertions");
      end if;
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

      if not Project_Tools.Text.Contains (Text, "Unicode version: 17.0.0") then
         Error ("ICU/CLDR completion checklist must pin Unicode 17.0.0");
      end if;

      if not Project_Tools.Text.Contains (Text, "CLDR version: 48.2") then
         Error ("ICU/CLDR completion checklist must pin CLDR 48.2");
      end if;

      if not Project_Tools.Text.Contains (Text, "ICU behavior baseline: ICU 78.3") then
         Error ("ICU/CLDR completion checklist must pin ICU 78.3");
      end if;

      if not Project_Tools.Text.Contains (Text, "`alr test`") then
         Error ("ICU/CLDR completion checklist must include the local alr test gate");
      end if;
   exception
      when others =>
         Error ("failed to validate ICU/CLDR completion checklist");
   end Check_ICU_CLDR_Completion_Checklist;

begin
   Project_Tools.Processes.Require_Command
     ("alr", "alr executable not found on PATH");

   if Project_Tools.Processes.Has_Argument ("--examples-only") then
      Check_Example_Output;
      if Errors = 0 then
         Put_Line ("i18n example output checks passed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
      else
         Put_Line
           (Standard_Error,
            "i18n example output checks failed:"
            & Natural'Image (Errors) & " error(s)");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      return;
   end if;

   Project_Tools.Release_Checks.Require_File (Checks, "README.md");
   Project_Tools.Release_Checks.Require_File (Checks, "i18n.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.ads");
   Project_Tools.Release_Checks.Require_File (Checks, "config/i18n_config.h");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/RELEASE_VERIFICATION.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/ICU_CLDR_COMPLETION_CHECKLIST.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/SPARK.md");
   Project_Tools.Release_Checks.Require_File (Checks, "docs/API.md");
   Project_Tools.Release_Checks.Require_File (Checks, "ai/API_MANIFEST.json");
   Project_Tools.Release_Checks.Require_File (Checks, "ai/CONTRACT_SUMMARY.yaml");
   Project_Tools.Release_Checks.Require_File (Checks, "ai/EXAMPLE_CATALOG.json");
   Project_Tools.Release_Checks.Require_File (Checks, "ai/FILE_ROLE_MAP.json");
   Project_Tools.Release_Checks.Require_File (Checks, "src/i18n-cldr_data.ads");
   Project_Tools.Release_Checks.Require_File (Checks, "src/i18n-cldr_data.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/CLDR_DATA.md");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/cldr_tools.gpr");
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
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/check_cldr_sources.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/check_tzdb_sources.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/generate_cldr_export.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/import_cldr_raw.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/extract_cldr_normalized.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/import_cldr_subset.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "cldr/src/generate_cldr_data.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/conformance.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/src/check_conformance.adb");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/manifest.txt");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/message_format.render");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/plurals.render");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/number_currency.render");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/date_time_calendar_tz.render");
   Project_Tools.Release_Checks.Require_File (Checks, "conformance/fixtures/units_lists_names.render");
   Project_Tools.Release_Checks.Require_File (Checks, "tests/tests.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "examples/examples.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "benchmarks/benchmarks.gpr");
   Project_Tools.Release_Checks.Require_File (Checks, "benchmarks/render_benchmarks.adb");
   Project_Tools.Release_Checks.Require_File
     (Checks, "benchmarks/catalogs/render_hot_paths.catalog");
   Project_Tools.Release_Checks.Require_File (Checks, ".github/workflows/ci.yml");

   Check_AI_JSON_Metadata;
   Check_ICU_CLDR_Completion_Checklist;

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
   Forbid_Text
     ("docs/RELEASE_VERIFICATION.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "release verification must use Alire-wrapped project build commands");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "./bin/check_i18n --examples-only",
      "release verification must include public example output checks");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gprbuild -P benchmarks/benchmarks.gpr",
      "release verification must include benchmark project build");
   Forbid_Text
     ("docs/RELEASE_VERIFICATION.md",
      "```sh" & ASCII.LF & "gprbuild -P benchmarks/benchmarks.gpr",
      "release verification must use Alire-wrapped benchmark build commands");
   Require_Text
     ("docs/QUICKSTART.md",
      "alr exec -- gprbuild -P i18n.gpr",
      "quickstart must show Alire-wrapped library build");
   Forbid_Text
     ("docs/QUICKSTART.md",
      "```sh" & ASCII.LF & "gprbuild -P i18n.gpr",
      "quickstart must not use a system gprbuild build command");
   Require_Text
     ("docs/QUICKSTART.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "quickstart must show Alire-wrapped example build");
   Forbid_Text
     ("docs/QUICKSTART.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "quickstart must not use a system gprbuild example build command");
   Require_Text
     ("docs/EXAMPLES.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "examples docs must use Alire-wrapped example build command");
   Forbid_Text
     ("docs/EXAMPLES.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "examples docs must not use a system gprbuild command");
   Require_Text
     ("examples/README.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "examples README must use Alire-wrapped build command");
   Forbid_Text
     ("examples/README.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "examples README must not use a system gprbuild command");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "examples index must use Alire-wrapped build command");
   Forbid_Text
     ("examples/EXAMPLES_INDEX.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "examples index must not use a system gprbuild command");
   Require_Text
     ("examples/EXPECTED_OUTPUT.md",
      "alr exec -- gprbuild -P examples/examples.gpr",
      "expected output doc must use Alire-wrapped build command");
   Forbid_Text
     ("examples/EXPECTED_OUTPUT.md",
      "```sh" & ASCII.LF & "gprbuild -P examples/examples.gpr",
      "expected output doc must not use a system gprbuild command");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "./benchmarks/bin/render_benchmarks --smoke",
      "release verification must include benchmark smoke run");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gnatprove -P i18n.gpr --level=0 --mode=check",
      "release verification must include GNATprove release check");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr test",
      "release verification must include Alire test action");
   Require_Text
     ("docs/ICU_CLDR_COMPLETION_CHECKLIST.md",
      "1. - [x] Add Ada conformance runners",
      "ICU/CLDR checklist must mark milestone 0 conformance runners complete");
   Require_Text
     ("docs/ICU_CLDR_COMPLETION_CHECKLIST.md",
      "4. - [x] Wire the conformance runners into `check_i18n` and `alr test`.",
      "ICU/CLDR checklist must mark milestone 0 gate integration complete");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "## Publication checks run by the guard",
      "release verification must describe publication checks as covered by the guard");
   Forbid_Text
     ("docs/RELEASE_VERIFICATION.md",
      "## Remaining publication checks",
      "release verification must not describe guarded publication checks as remaining");
   Require_Text
     ("docs/VALIDATION.md",
      "deterministic domain-format tests",
      "validation docs must list deterministic domain-format tests");
   Require_Text
     ("docs/VALIDATION.md",
      "public example output checks",
      "validation docs must list public example output checks");
   Require_Text
     ("docs/VALIDATION.md",
      "benchmark smoke checks for render hot paths and bounded `Render_Into`",
      "validation docs must list benchmark smoke checks");
   Require_Text
     ("docs/VALIDATION.md",
      "formatter implementation, or generated CLDR",
      "validation docs must reject formatter/CLDR internals in public examples");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "`::spellout` and `::ordinal-words` skeletons including Basque coverage",
      "test matrix must document spellout/ordinal-word number coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "`I18N`, `I18N.Runtime`, `I18N.Locales`, `I18N.Arguments`, "
      & "`I18N.Plurals`, and `I18N.Result`",
      "test matrix public render line must include the root facade and I18N.Plurals");
   Require_Text
     ("AGENTS.md",
      "* `I18N.Plurals`",
      "AGENTS public API list must include I18N.Plurals");
   Require_Text
     ("AGENTS.md",
      "`alr test` routes through `check_i18n`",
      "AGENTS build instructions must describe the release guard entry point");
   Require_Text
     (".gitignore",
      "benchmarks/bin/",
      "gitignore must exclude benchmark build outputs");
   Require_Text
     (".gitignore",
      "cldr/bin/",
      "gitignore must exclude CLDR tool build outputs");
   Require_Text
     ("MANIFEST.txt",
      "config/i18n_config.gpr",
      "manifest must include the Alire-generated config project imported by i18n.gpr");
   Require_Text
     ("MANIFEST.txt",
      "release_locale_fallback.catalog",
      "manifest must include tracked root catalog fixtures");
   Forbid_Text
     ("AGENTS.md",
      "This is the v1.0 release branch",
      "AGENTS must not describe this branch as v1.0");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "cash options and cash increments, zero-/three-/four-minor-unit metadata including `CLF`",
      "test matrix must document expanded currency metadata coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "standalone month fields, locale week fields, modified Julian day fields",
      "test matrix must document expanded date skeleton field coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "Buddhist/Japanese/ROC-Minguo/Julian/Coptic/Ethiopic/Islamic-civil/Indian-national/Persian calendar display",
      "test matrix must document expanded calendar coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "generated tzdb transition offsets, built-in DST-aware named-zone display families",
      "test matrix must document expanded time-zone coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "direct unit and measure-unit/per-measure-unit skeletons, localized unit/relative/list text",
      "test matrix table must document expanded domain formatter coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "byte sizes through `PiB`, strict decimal units, direct unit and "
      & "`::measure-unit`/`per-measure-unit` skeleton aliases",
      "test matrix must document expanded domain formatter skeleton coverage");
   Require_Text
     ("docs/TEST_MATRIX.md",
      "localized relative full/short/narrow second/minute/hour/day/week/month/"
      & "quarter/year offsets including zero forms",
      "test matrix must document localized relative-time domain coverage");
   Require_Text
     ("README.md",
      "verifies the CLDR data boundary",
      "README build/test summary must mention CLDR data-boundary verification");
   Require_Text
     ("docs/ARCHITECTURE.md",
      "tooling regenerates that package without changing the public API",
      "architecture docs must describe CLDR tooling as present release tooling");
   Forbid_Text
     ("docs/ARCHITECTURE.md",
      "future CLDR import tooling",
      "architecture docs must not describe current CLDR tooling as future work");
   Require_Text
     ("README.md",
      "tooling can broaden that upstream source while preserving the stable public",
      "README CLDR section must describe current staged CLDR tooling");
   Forbid_Text
     ("README.md",
      "Future CLDR import tooling",
      "README must not describe current CLDR tooling as future work");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "The staged CLDR import tooling can replace or expand",
      "CLDR data manifest must describe current staged CLDR tooling");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "`I18N.Diagnostics`, `I18N.Arguments`, `I18N.Locales`, and `I18N.Plurals`",
      "CLDR data manifest must list the complete public facade");
   Require_Text
     ("MANIFEST.txt",
      "cldr/upstream/cldr-json/cldr-dates-modern/main/ja/ca-gregorian.json",
      "manifest must include expanded CLDR date upstream files");
   Require_Text
     ("MANIFEST.txt",
      "cldr/upstream/cldr-json/cldr-dates-modern/main/zh/ca-gregorian.json",
      "manifest must include expanded CJK CLDR date upstream files");
   Require_Text
     ("MANIFEST.txt",
      "cldr/upstream/cldr-json/cldr-numbers-modern/main/th/numbers.json",
      "manifest must include expanded CLDR number upstream files");
   Forbid_Text
     ("cldr/CLDR_DATA.md",
      "Future CLDR import tooling",
      "CLDR data manifest must not describe current tooling as future work");
   Require_Text
     ("README.md",
      "benchmark smoke checks for render hot paths and bounded `Render_Into`",
      "README build/test summary must mention benchmark smoke checks");
   Require_Text
     ("README.md",
      "`I18N.Number_Format`, `I18N.Currency`, `I18N.Date_Time_Format`, "
      & "`I18N.Extra_Format`, `I18N.CLDR_Data`",
      "README public-boundary text must list private formatter and CLDR units");
   Require_Text
     ("README.md",
      "formatter implementation, or generated CLDR data packages",
      "README public API summary must classify formatter and CLDR internals as private");
   Require_Text
     ("llms.txt",
      "formatter implementation packages, generated CLDR data",
      "LLM guide must classify formatter and CLDR internals as private");
   Require_Text
     ("docs/RELEASE_CHECKLIST.md",
      "formatter implementation, or generated CLDR data packages",
      "release checklist must forbid formatter and CLDR internals in public examples");
   Require_Text
     ("AGENTS.md",
      "formatter implementation packages, generated CLDR data",
      "AGENTS coding rules must keep formatter and CLDR internals private");
   Require_Text
     ("src/i18n-runtime.ads",
      "formatter",
      "runtime spec must classify formatter and CLDR internals as private");
   Require_Text
     ("src/i18n-runtime.ads",
      "generated CLDR data",
      "runtime spec must classify generated CLDR data as private");
   Require_Text
     ("src/i18n-runtime.ads",
      "deterministic formatting set: number skeletons",
      "runtime spec must document expanded number formatter coverage");
   Require_Text
     ("src/i18n-runtime.ads",
      "{instant, datetime, ::yMdHHmmssz, UTC}",
      "runtime spec must document datetime skeleton formatting");
   Require_Text
     ("src/i18n-runtime.ads",
      "duration, byte size, unit",
      "runtime spec must document deterministic domain formatter coverage");
   Require_Text
     ("src/i18n-runtime.ads",
      "datetime, duration, byte-size, unit, relative-time, or list",
      "runtime spec must document malformed formatted-value statuses");
   Require_Text
     ("src/i18n.ads",
      "formatter",
      "root spec must classify formatter internals as private");
   Require_Text
     ("src/i18n.ads",
      "generated CLDR data",
      "root spec must classify generated CLDR data as private");
   Require_Text
     ("src/i18n-result.ads",
      "formatter implementation, generated CLDR data",
      "result spec must hide formatter and CLDR internals");
   Require_Text
     ("src/i18n-arguments.ads",
      "duration, byte-size, unit, measure-unit, and relative-time",
      "arguments spec must document domain formatter value syntax");
   Require_Text
     ("src/i18n-arguments.ads",
      "pipe-delimited item text",
      "arguments spec must document list formatter values");
   Require_Text
     ("src/i18n-arguments.ads",
      "datetime, duration, byte-size, unit, relative-time, or list",
      "arguments spec must document formatted-value invalid status coverage");
   Require_Text
     ("ai/API_MANIFEST.json",
      "number/currency/duration/byte-size/unit/measure-unit/relative-time",
      "AI API manifest must document formatted argument value syntax");
   Require_Text
     ("ai/API_MANIFEST.json",
      "pipe-delimited item text",
      "AI API manifest must document list argument values");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "number/currency/duration/byte-size/unit/measure-unit/relative-time",
      "AI contract summary must document formatted argument value syntax");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "pipe-delimited item text",
      "AI contract summary must document list argument values");
   Require_Text
     ("src/i18n-plurals.ads",
      "whole values and explicit CLDR fractional operands",
      "plural spec must document the fractional-operand public API");
   Require_Text
     ("README.md",
      "deterministic domain formatting",
      "README build/test summary must mention deterministic domain formatting coverage");
   Require_Text
     ("docs/RELEASE_CHECKLIST.md",
      "examples build and output checks, CLDR data-boundary checks",
      "release checklist must include example output and CLDR checks");
   Require_Text
     ("docs/RELEASE_CHECKLIST.md",
      "benchmark smoke checks for render hot paths and",
      "release checklist must include benchmark smoke checks");
   Require_Text
     ("docs/RELEASE_CHECKLIST.md",
      "including example output checks, CLDR data-boundary checks, benchmark smoke checks",
      "release blocker must include the expanded check_i18n guard");
   Require_Text
     ("README.md",
      "example project build and output checks, CLDR data-boundary checks",
      "README verification status must include example output and CLDR checks");
   Require_Text
     ("README.md",
      "render benchmark smoke checks, GNATdoc, and GNATprove",
      "README verification status must include benchmark smoke checks");
   Require_Text
     ("docs/ARCHITECTURE.md",
      "example project build and output checks, CLDR data-boundary checks",
      "architecture docs must include example output and CLDR release checks");
   Require_Text
     ("docs/ARCHITECTURE.md",
      "render benchmark smoke checks, GNATdoc, and GNATprove",
      "architecture docs must include benchmark release checks");
   Require_Text
     ("docs/COMPATIBILITY.md",
      "example-project build and output checks, CLDR data-boundary checks",
      "compatibility docs must include example output and CLDR release checks");
   Require_Text
     ("docs/COMPATIBILITY.md",
      "render benchmark smoke checks, GNATdoc, and GNATprove",
      "compatibility docs must include benchmark release checks");
   Require_Text
     ("docs/QUICKSTART.md",
      "`Asia/Nicosia`, `Europe/Moscow`, `Europe/Istanbul`, `America/New_York`",
      "Quickstart target-zone examples must include Istanbul alongside fixed-offset Europe zones");
   Require_Text
     ("docs/QUICKSTART.md",
      "See `docs/ICU_SUBSET.md` for the",
      "Quickstart must defer exhaustive target-zone coverage to ICU subset docs");
   Require_Text
     ("docs/QUICKSTART.md",
      "complete deterministic target-zone list.",
      "Quickstart must name the complete target-zone list");
   Require_Text
     ("docs/QUICKSTART.md",
      "## 5. Render date, time, number, and currency values",
      "Quickstart formatter section must name date/time/number/currency coverage");
   Require_Text
     ("docs/QUICKSTART.md",
      "## 7. Run the release test suite",
      "Quickstart section numbering must keep release tests after build steps");
   Require_Text
     ("docs/QUICKSTART.md",
      "## 8. What to read next",
      "Quickstart section numbering must keep next-reading after test steps");
   Require_Text
     ("docs/QUICKSTART.md",
      "with I18N.Plurals;",
      "Quickstart public import snippet must include I18N.Plurals");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.Plurals;",
      "examples docs public import boundary must include I18N.Plurals");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "I18N-CATALOG-BINARY",
      "AI guide must distinguish the supported binary envelope from compiled catalogs");
   Forbid_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "Assuming binary compiled catalogs are part of v1.1.0; they are not.",
      "AI guide must not contradict the supported v1.1 binary catalog envelope");
   Require_Text
     ("README.md",
      "docs/SPARK.md",
      "README must point maintainers to SPARK coverage");
   Require_Text
     ("docs/API.md",
      "Symbol and ISO-code currency displays render before the amount for "
      & "`en`, `ar`, `hi`, `bn`, `ja`, `zh`, and `ko`.",
      "API docs must keep currency placement locale coverage aligned");
   Require_Text
     ("docs/ICU_SUBSET.md",
      "`de`, `fr`, `es`, `it`, `nl`, `pt`, `pl`, `cs`, `ru`, `ro`, "
      & "`lt`, and `sl`",
      "ICU subset docs must keep comma-decimal locale coverage aligned");
   Require_Text
     ("ai/API_MANIFEST.json",
      """number_format""",
      "AI API manifest must document number formatting");
   Require_Text
     ("ai/API_MANIFEST.json",
      """currency_format""",
      "AI API manifest must document currency formatting");
   Require_Text
     ("ai/API_MANIFEST.json",
      """date_format""",
      "AI API manifest must document date formatting");
   Require_Text
     ("ai/API_MANIFEST.json",
      """time_format""",
      "AI API manifest must document time formatting");
   Require_Text
     ("ai/API_MANIFEST.json",
      """datetime_format""",
      "AI API manifest must document datetime formatting");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "number_format:",
      "AI contract summary must document number formatting");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "currency_format:",
      "AI contract summary must document currency formatting");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "date_format:",
      "AI contract summary must document date formatting");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "time_format:",
      "AI contract summary must document time formatting");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "datetime_format:",
      "AI contract summary must document datetime formatting");
   Require_Text
     ("ai/API_MANIFEST.json",
      """covered_publication_checks""",
      "AI API manifest must classify publication checks as covered");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "covered_publication_checks:",
      "AI contract summary must classify publication checks as covered");
   Forbid_Text
     ("ai/API_MANIFEST.json",
      "remaining_publication_checks",
      "AI API manifest must not leave publication checks marked as remaining");
   Forbid_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "remaining_publication_checks",
      "AI contract summary must not leave publication checks marked as remaining");
   Require_Text
     ("ai/API_MANIFEST.json",
      """selectordinal_branches_optional"": [""zero"", ""one"", ""two"", ""few"", ""many""]",
      "AI API manifest must document full selectordinal category syntax");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "selectordinal_branches_optional: [zero, one, two, few, many]",
      "AI contract summary must document full selectordinal category syntax");
   Require_Text
     ("docs/ICU_SUBSET.md",
      "`zero`, `one`, `two`, `few`, `many`, and `other`",
      "ICU subset docs must document full selectordinal category syntax");
   Require_Text
     ("README.md",
      "`selectordinal` also accepts `zero` and `many` branches",
      "README must document full selectordinal category syntax");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Italian ordinal many branch is selected",
      "feature tests must cover selectordinal many branch rendering");
   Require_Text
     ("examples/selectordinal_render.adb",
      """ordinal many""",
      "selectordinal example must cover an ordinal many branch");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "locale-aware ordinal categories",
      "example index must document locale-aware selectordinal coverage");
   Require_Text
     ("docs/EXAMPLES.md",
      "locale-aware ordinal categories",
      "examples docs must document locale-aware selectordinal coverage");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "bounded selectordinal many branch matches materialized output",
      "feature tests must cover bounded selectordinal many branch rendering");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "duplicate many selectordinal branches are rejected",
      "feature tests must cover duplicate selectordinal many branches");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "zero {Z} zero {N}",
      "malformed corpus must cover duplicate selectordinal zero branches");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "{value, number, ::scale/0}",
      "malformed corpus must cover invalid number scale skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "{amount, number, ::currency/US}",
      "malformed corpus must cover invalid currency skeleton codes");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "datetime long skeleton alias preserves zone conversion",
      "feature tests must cover datetime long skeleton style aliases");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "datetime full skeleton alias preserves zone conversion",
      "feature tests must cover datetime full skeleton style aliases");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Berlin DST boundary applies summer offset at spring transition",
      "feature tests must cover European DST spring transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Berlin DST boundary restores standard offset at autumn transition",
      "feature tests must cover European DST autumn transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "New York DST boundary applies daylight offset at spring transition",
      "feature tests must cover North American DST spring transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "New York DST boundary restores standard offset at autumn transition",
      "feature tests must cover North American DST autumn transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Auckland DST boundary applies daylight offset after spring transition",
      "feature tests must cover New Zealand DST transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Sydney DST boundary applies daylight offset at spring transition",
      "feature tests must cover Australian DST transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Jerusalem DST boundary applies daylight offset at spring transition",
      "feature tests must cover Jerusalem DST transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Tehran historical DST boundary applies daylight offset after spring transition",
      "feature tests must cover Tehran historical DST transition boundaries");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton resolves CLDR availableFormats order",
      "feature tests must cover CLDR availableFormats skeleton order");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton renders extended cyclic and related year fields",
      "feature tests must cover ICU date skeleton year alias fields");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton renders standalone month numeric and name fields",
      "feature tests must cover ICU date skeleton standalone month fields");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton renders UTF-8 short names without slicing",
      "feature tests must cover UTF-8-safe date skeleton short names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton localizes Japanese weekday/month names",
      "feature tests must cover CJK date skeleton month and weekday names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton localizes Korean Gregorian era names",
      "feature tests must cover localized Gregorian era names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton localizes Japanese wide quarter names",
      "feature tests must cover localized wide quarter names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton localizes Arabic abbreviated quarter names",
      "feature tests must cover localized abbreviated quarter names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton renders modified Julian day fields",
      "feature tests must cover ICU date skeleton modified Julian day fields");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "date skeleton Y/w/W render locale week-year data",
      "feature tests must cover ICU date skeleton locale week fields");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Buddhist calendar year is formatted from locale extension",
      "feature tests must cover Buddhist calendar date formatting");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Japanese calendar era year localizes era names for ja locale",
      "feature tests must cover Japanese calendar era formatting");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "ROC calendar year and era render from locale extension",
      "feature tests must cover ROC/Minguo calendar formatting");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Julian calendar date is converted from Gregorian input",
      "feature tests must cover Julian calendar conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Coptic calendar conversion applies to datetime skeletons",
      "feature tests must cover Coptic calendar datetime conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Ethiopic calendar conversion applies to datetime skeletons",
      "feature tests must cover Ethiopic calendar datetime conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Islamic civil calendar conversion applies to datetime skeletons",
      "feature tests must cover Islamic civil calendar datetime conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Indian national calendar conversion applies to datetime skeletons",
      "feature tests must cover Indian national calendar datetime conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Persian calendar conversion applies to datetime skeletons",
      "feature tests must cover Persian calendar datetime conversion");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "time zone skeleton widths render long offsets and zone IDs",
      "feature tests must cover ICU time-zone skeleton offset widths");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "V skeleton widths render identifiers and location labels",
      "feature tests must cover ICU V-width zone identifiers and locations");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "zone skeleton names localize Korean generic names",
      "feature tests must cover localized generic zone names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "time zone skeleton widths distinguish zero x from X/Z",
      "feature tests must cover UTC X/x/Z zone width distinctions");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Bangladeshi taka narrow symbol uses built-in metadata",
      "feature tests must cover additional currency narrow symbols");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Bengali currency uses Bengali digits and generated CLDR symbol",
      "feature tests must cover Bengali currency digits and symbol position");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Japanese ISO currency code renders before the amount",
      "feature tests must cover CJK ISO-code currency placement");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency display names localize Russian USD singular output",
      "feature tests must cover localized currency display names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency display names localize Arabic USD plural output",
      "feature tests must cover localized plural currency display names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency unit-width-iso-code-accounting option composes",
      "feature tests must cover ISO-code accounting currency display");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "number currency skeleton accepts cash/sign-accounting tokens",
      "feature tests must cover cash accounting currency skeleton composition");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "numbering-system extension renders Bengali digits",
      "feature tests must cover explicit number numbering-system digits");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "permille number skeleton scales and adds permille sign",
      "feature tests must cover permille number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "compact-long number skeleton renders compact word",
      "feature tests must cover compact-long number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "engineering number skeleton renders exponent multiple of 3",
      "feature tests must cover engineering number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "rounding-mode-half-even ties to even",
      "feature tests must cover half-even rounding ties");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "sign-accounting renders negative numbers in parentheses",
      "feature tests must cover number sign-accounting output");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "precision-significant range pads to minimum significant digits",
      "feature tests must cover significant precision ranges");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "integer-width skeleton pads integer digits before grouping",
      "feature tests must cover integer-width number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "decimal-always forces one fractional zero for integers",
      "feature tests must cover decimal-display number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "trailing-zero-display/stripIfInteger strips zero fraction",
      "feature tests must cover trailing-zero-display number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "group-min2 composes with Indian grouping",
      "feature tests must cover group-min2 number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "scale skeleton multiplies the parsed numeric value",
      "feature tests must cover scale number skeletons");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "rounding-increment composes with rounding-mode-down",
      "feature tests must cover rounding increment composition");
   Require_Text
     ("examples/number_formatting.adb",
      """number permille""",
      "number example must cover permille skeleton output");
   Require_Text
     ("examples/number_formatting.adb",
      """number engineering""",
      "number example must cover engineering skeleton output");
   Require_Text
     ("examples/number_formatting.adb",
      """number accounting""",
      "number example must cover sign-accounting skeleton output");
   Require_Text
     ("examples/number_formatting.adb",
      """number scale""",
      "number example must cover scale skeleton output");
   Require_Text
     ("examples/number_formatting.adb",
      """number trailing""",
      "number example must cover trailing-zero-display skeleton output");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Canadian dollar cash option rounds to the cash increment",
      "feature tests must cover CAD cash rounding metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Danish krone cash option rounds to the cash increment",
      "feature tests must cover DKK cash rounding metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Swedish krona cash option uses CLDR cash metadata",
      "feature tests must cover SEK cash rounding metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "Hungarian forint cash option uses CLDR cash metadata",
      "feature tests must cover HUF cash rounding metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "four-minor-unit currencies preserve four fraction digits",
      "feature tests must cover four-minor-unit currency metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency display names pluralize four-minor-unit CLF output",
      "feature tests must cover four-minor-unit currency display names");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency display names pluralize added minor-unit corpus",
      "feature tests must cover the added minor-unit currency metadata corpus");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency display names pluralize added three-minor corpus",
      "feature tests must cover the added three-minor currency metadata corpus");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency metadata covers CLDR historic zero-minor codes",
      "feature tests must cover expanded CLDR currency metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "currency metadata covers CLDR 46.1 Caribbean guilder symbol",
      "feature tests must cover newly generated CLDR currency symbols");
   Require_Text
     ("cldr/raw/coverage.txt",
      "require_currency_count|307",
      "CLDR coverage must require the expanded currency-code table");
   Require_Text
     ("cldr/raw/coverage.txt",
      "ADP,AED,AFA,AFN",
      "CLDR coverage must include historic and current currency prefixes");
   Require_Text
     ("cldr/raw/coverage.txt",
      "XCG,XDR",
      "CLDR coverage must include newer CLDR currency symbols");
   Require_Text
     ("cldr/raw/coverage.txt",
      "ZWG,ZWL,ZWR",
      "CLDR coverage must include Zimbabwe currency metadata");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "four-minor-unit currencies reject five fractional digits",
      "feature tests must cover malformed four-minor-unit currency inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "negative duration input is rejected",
      "feature tests must cover negative duration inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "empty duration input is rejected",
      "feature tests must cover empty duration inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "negative byte-size input is rejected",
      "feature tests must cover negative byte-size inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "empty byte-size input is rejected",
      "feature tests must cover empty byte-size inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "byte formatter renders pebibyte units",
      "feature tests must cover byte-size PiB output");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "duration formatter honors explicit numbering-system digits",
      "feature tests must cover duration numbering-system digits");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "byte formatter honors explicit numbering-system digits",
      "feature tests must cover byte-size numbering-system digits");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "empty unit input is rejected",
      "feature tests must cover empty unit inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "unit formatter accepts ICU-style length-mile alias",
      "feature tests must cover direct ICU-style unit aliases");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "unit formatter localizes decimal digits and separator",
      "feature tests must cover localized unit decimal values");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "measure-unit skeleton accepts volume-litre alias",
      "feature tests must cover measure-unit spelling aliases");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "measure-unit skeleton accepts per-measure-unit",
      "feature tests must cover measure-unit rate formatting");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "measure-unit skeleton honors explicit numbering-system digits",
      "feature tests must cover measure-unit numbering-system digits");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      --  Renamed with the fix: en short kilometer-per-hour is the named
      --  "km/h", not a slash form composed from "km" and "hr".
      "short measure-unit skeleton renders the named short rate",
      "feature tests must cover short measure-unit rate formatting");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "measure-unit skeleton accepts mass units and narrow width",
      "feature tests must cover mass units and narrow measure width");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "empty relative-time input is rejected",
      "feature tests must cover empty relative-time inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "relative-time formatter renders zero day specially",
      "feature tests must cover relative-time zero day forms");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "relative-time formatter localizes Russian current year",
      "feature tests must cover relative-time current period forms");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "empty list input is rejected",
      "feature tests must cover empty list inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "leading-empty list input is rejected",
      "feature tests must cover leading-empty list inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "trailing-empty list input is rejected",
      "feature tests must cover trailing-empty list inputs");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "unit formatter localizes Japanese full unit names",
      "feature tests must cover Japanese direct unit formatter localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "unit formatter localizes Chinese full unit names",
      "feature tests must cover Chinese direct unit formatter localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "unit formatter localizes Korean full unit names",
      "feature tests must cover Korean direct unit formatter localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "relative-time formatter localizes Japanese past offsets",
      "feature tests must cover Japanese relative-time localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "relative-time formatter localizes Chinese past offsets",
      "feature tests must cover Chinese relative-time localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "relative-time formatter localizes Korean past offsets",
      "feature tests must cover Korean relative-time localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "list formatter localizes Japanese conjunction",
      "feature tests must cover Japanese list formatter localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "list formatter localizes Chinese conjunction",
      "feature tests must cover Chinese list formatter localization");
   Require_Text
     ("tests/src/i18n-runtime-tests-features.adb",
      "list formatter localizes Korean conjunction",
      "feature tests must cover Korean list formatter localization");
   Require_Text
     ("docs/API.md",
      "four-minor-unit `CLF`",
      "API docs must mention four-minor-unit CLF currency metadata");
   Require_Text
     ("docs/API.md",
      "307-code generated CLDR 46.1 currency table",
      "API docs must mention expanded CLDR currency metadata coverage");
   Require_Text
     ("README.md",
      "307-code generated CLDR 46.1 currency table",
      "README must mention expanded CLDR currency metadata coverage");
   Require_Text
     ("README.md",
      "Full CLDR RBNF rule sets, broader non-Gregorian",
      "README must identify expanded RBNF/calendar scope as completion work");
   Require_Text
     ("README.md",
      "runtime supports the deterministic RBNF, calendar, runtime-data override",
      "README must keep current runtime-data boundaries documented");
   Forbid_Text
     ("README.md",
      "and localized ordinal-word spelling" & ASCII.LF
      & "beyond the built-in deterministic",
      "README must not imply all localized ordinal-word spelling is out of scope");
   Forbid_Text
     ("README.md",
      "full CLDR RBNF spellout rules beyond built-in",
      "README must not describe the RBNF limit as spellout-only");
   Require_Text
     ("docs/ICU_SUBSET.md",
      "Full CLDR RBNF behavior is part of the completion scope",
      "ICU subset docs must identify expanded RBNF scope as completion work");
   Forbid_Text
     ("docs/ICU_SUBSET.md",
      "Full CLDR RBNF spellout rule sets beyond the built-in deterministic",
      "ICU subset docs must not describe the RBNF limit as spellout-only");
   Require_Text
     ("ai/API_MANIFEST.json",
      "307-code generated CLDR 46.1 currency table",
      "AI API manifest must mention expanded CLDR currency metadata coverage");
   Require_Text
     ("ai/CONTRACT_SUMMARY.yaml",
      "307-code generated CLDR 46.1 currency table",
      "AI contract summary must mention expanded CLDR currency metadata coverage");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "date skeleton with time fields should fail",
      "formatted-value fuzz must cover date skeleton field mismatches");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "time skeleton with date fields should fail",
      "formatted-value fuzz must cover time skeleton field mismatches");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "unknown datetime target zone should fail",
      "formatted-value fuzz must cover unknown datetime target zones");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "out-of-range datetime target offset should fail",
      "formatted-value fuzz must cover out-of-range datetime target offsets");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "empty duration seconds should fail",
      "formatted-value fuzz must cover empty duration values");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "empty byte size should fail",
      "formatted-value fuzz must cover empty byte-size values");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "empty relative offset should fail",
      "formatted-value fuzz must cover empty relative-time values");
   Require_Text
     ("tests/src/i18n-runtime-tests-corpus.adb",
      "trailing empty list item should fail",
      "formatted-value fuzz must cover trailing-empty list values");
   Require_Text
     ("ai/EXAMPLE_CATALOG.json",
      "Arabic digits Indian grouping percent permille compact scientific "
      & "engineering sign-accounting trailing-zero-display scale and "
      & "spellout skeleton output",
      "AI example catalog must describe expanded number formatting examples");
   Require_Text
     ("ai/EXAMPLE_CATALOG.json",
      "narrow symbols ISO-code output display names cash rounding accounting and zero-minor-unit metadata",
      "AI example catalog must describe expanded currency formatting examples");
   Require_Text
     ("examples/currency_formatting.adb",
      """currency narrow""",
      "currency example must cover narrow-symbol output");
   Require_Text
     ("examples/currency_formatting.adb",
      """currency iso""",
      "currency example must cover ISO-code output");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "narrow symbols, ISO-code output",
      "example index must document narrow and ISO currency coverage");
   Require_Text
     ("docs/EXAMPLES.md",
      "narrow symbols, ISO-code output",
      "examples docs must document narrow and ISO currency coverage");
   Require_Text
     ("examples/date_formatting.adb",
      """date numeric skeleton""",
      "date example must cover numeric date skeleton output");
   Require_Text
     ("examples/time_formatting.adb",
      """time fraction""",
      "time example must cover fractional-second skeleton output");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "named, numeric, and locale week skeletons",
      "example index must document expanded date skeleton coverage");
   Require_Text
     ("docs/EXAMPLES.md",
      "zone width skeletons, UTC widths, and datetime style aliases",
      "examples docs must document expanded time skeleton coverage");
   Require_Text
     ("examples/number_formatting.adb",
      """number scientific""",
      "number example must cover scientific notation skeleton output");
   Require_Text
     ("examples/number_formatting.adb",
      """number spellout""",
      "number example must cover spellout skeleton output");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "scientific, engineering, sign-accounting, trailing-zero-display, scale, and spellout skeletons",
      "example index must document expanded number skeleton coverage");
   Require_Text
     ("docs/EXAMPLES.md",
      "scientific, engineering, sign-accounting, trailing-zero-display, scale, and spellout skeleton output",
      "examples docs must document expanded number skeleton coverage");
   Require_Text
     ("ai/EXAMPLE_CATALOG.json",
      "named numeric and locale week skeleton output plus Japanese Buddhist and Persian calendar names",
      "AI example catalog must describe expanded date formatting examples");
   Require_Text
     ("ai/EXAMPLE_CATALOG.json",
      "day-period fractional-second zone width UTC width and datetime style alias skeleton output",
      "AI example catalog must describe expanded time formatting examples");
   Require_Text
     ("examples/domain_formatting.adb",
      """domain short rate""",
      "domain example must cover short measure-unit rate output");
   Require_Text
     ("examples/domain_formatting.adb",
      """domain relative de""",
      "domain example must cover localized relative-time output");
   Require_Text
     ("examples/domain_formatting.adb",
      """domain list de""",
      "domain example must cover localized list output");
   Require_Text
     ("examples/EXAMPLES_INDEX.md",
      "localized relative-time, and localized list",
      "example index must document localized domain formatter coverage");
   Require_Text
     ("docs/EXAMPLES.md",
      "localized relative-time, and localized list",
      "examples docs must document localized domain formatter coverage");
   Require_Text
     ("ai/EXAMPLE_CATALOG.json",
      "short-rate relative-time localized relative-time and localized list",
      "AI example catalog must describe expanded domain formatting examples");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      """file"": ""examples/number_formatting.adb""",
      "AI file role map must include the number formatter example");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      """file"": ""examples/currency_formatting.adb""",
      "AI file role map must include the currency formatter example");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      """file"": ""examples/date_formatting.adb""",
      "AI file role map must include the date formatter example");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      """file"": ""examples/time_formatting.adb""",
      "AI file role map must include the time formatter example");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      "formatter_example_source",
      "AI file role map must classify public formatter examples");
   Require_Text
     ("README.md",
      "generated-data boundary",
      "README must document the CLDR generated-data boundary");
   Require_Text
     ("src/i18n-cldr_data.ads",
      "Generated-data boundary",
      "CLDR data package spec must identify the generated-data boundary");
   Require_Text
     ("src/i18n-cldr_data.ads",
      "Locale-specific spellout word",
      "CLDR data package spec must not describe spellout words as English-only");
   Require_Text
     ("src/i18n-cldr_data.ads",
      "Return deterministic scale words for locale-specific spellout",
      "CLDR data package spec must describe localized spellout scale words");
   Require_Text
     ("src/i18n-cldr_data.ads",
      "Canonical_Time_Zone",
      "CLDR data package spec must expose private tzdb alias canonicalization");
   Require_Text
     ("src/i18n-date_time_format.adb",
      "I18N.CLDR_Data.Canonical_Time_Zone",
      "date/time formatter must consume generated tzdb alias canonicalization");
   Forbid_Text
     ("src/i18n-cldr_data.ads",
      "English spellout word",
      "CLDR data package spec must not describe spellout words as English-only");
   Forbid_Text
     ("src/i18n-cldr_data.ads",
      "English ordinal word",
      "CLDR data package spec must not describe ordinal words as English-only");
   Forbid_Text
     ("src/i18n-cldr_data.ads",
      "English scale word",
      "CLDR data package spec must not describe spellout scale words as English-only");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "I18N.CLDR_Data",
      "CLDR data manifest must name the generated-data target");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/data/cldr_subset.txt",
      "CLDR data manifest must name the pinned source data file");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/upstream/cldr_export.jsonl",
      "CLDR data manifest must name the staged upstream source data file");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/upstream/source_manifest.txt",
      "CLDR data manifest must name the staged upstream source manifest");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/upstream/source_files.txt",
      "CLDR data manifest must name the upstream source inventory");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "check_cldr_sources",
      "CLDR data manifest must document the upstream source checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "generate_cldr_export",
      "CLDR data manifest must document the staged export generator/checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "import_cldr_raw",
      "CLDR data manifest must document the raw importer/checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/raw/cldr_records.txt",
      "CLDR data manifest must name the raw CLDR extract source");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/raw/coverage.txt",
      "CLDR data manifest must name the raw coverage manifest");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "extract_cldr_normalized",
      "CLDR data manifest must document the extractor/checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "cldr/import/normalized_cldr.txt",
      "CLDR data manifest must name the normalized import source");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "import_cldr_subset",
      "CLDR data manifest must document the importer/checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "generate_cldr_data",
      "CLDR data manifest must document the generator/checker command");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "checked tzdb alias",
      "CLDR data manifest must describe tzdb alias generation");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "transition-offset tables",
      "CLDR data manifest must describe generated tzdb transition tables");
   Require_Text
     ("src/i18n-cldr_data.ads",
      "Time_Zone_Offset_Seconds_At_UTC",
      "CLDR data package spec must expose private generated tzdb transition lookup");
   Require_Text
     ("cldr/src/generate_cldr_data.adb",
      "upstream/tzdb/tzdata.zi",
      "CLDR generator must consume checked tzdb source fixtures");
   Require_Text
     ("cldr/src/import_cldr_subset.adb",
      "Project_Tools.Files",
      "CLDR importer must use project_tools file helpers");
   Require_Text
     ("cldr/src/import_cldr_raw.adb",
      "Project_Tools.JSON",
      "CLDR raw importer must use project_tools JSON helpers");
   Require_Text
     ("cldr/src/check_cldr_sources.adb",
      "Project_Tools.Files",
      "CLDR source checker must use project_tools file helpers");
   Require_Text
     ("cldr/src/check_cldr_sources.adb",
      "Project_Tools.JSON",
      "CLDR source checker must use project_tools JSON helpers");
   Require_Text
     ("cldr/src/generate_cldr_export.adb",
      "Project_Tools.Files",
      "CLDR export generator must use project_tools file helpers");
   Require_Text
     ("cldr/src/generate_cldr_export.adb",
      "Project_Tools.JSON",
      "CLDR export generator must use project_tools JSON helpers");
   Require_Text
     ("cldr/src/extract_cldr_normalized.adb",
      "Project_Tools.Files",
      "CLDR extractor must use project_tools file helpers");
   Require_Text
     ("cldr/src/generate_cldr_data.adb",
      "Project_Tools.Files",
      "CLDR generator must use project_tools file helpers");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "plural rule-family mappings",
      "CLDR data manifest must describe plural rule-family data");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "currency",
      "CLDR data manifest must describe currency data");
   Require_Text
     ("cldr/CLDR_DATA.md",
      "Afrikaans, Basque, Romanian",
      "CLDR data manifest must list Basque spellout/ordinal-word data");
   Forbid_Text
     ("cldr/CLDR_DATA.md",
      "Afrikaans, Romanian, Catalan",
      "CLDR data manifest must not omit Basque from spellout/ordinal-word data");
   Require_Text
     ("src/i18n-number_format.adb",
      "I18N.CLDR_Data",
      "number formatting must consume the CLDR data boundary");
   Require_Text
     ("src/i18n-currency.adb",
      "I18N.CLDR_Data",
      "currency formatting must consume the CLDR data boundary");
   Require_Text
     ("src/i18n-date_time_format.adb",
      "I18N.CLDR_Data",
      "date/time formatting must consume the CLDR data boundary");
   Require_Text
     ("docs/SPARK.md",
      "I18N.Result",
      "SPARK documentation must describe I18N.Result coverage");
   Require_Text
     ("alire.toml",
      "type = ""test""",
      "Alire manifest must define a test action");
   Require_Text
     ("alire.toml",
      "check_i18n",
      "Alire test action must route through the project_tools-based check_i18n guard");
   Require_Text
     ("docs/RELEASE_VERIFICATION.md",
      "alr exec -- gnatdoc -P i18n.gpr",
      "release verification must include GNATdoc command");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "private child",
      "public import rules must document private-child boundary");
   Require_Text
     ("docs/API.md",
      "formatter implementation",
      "API docs must classify formatter helper packages as private children");
   Require_Text
     ("docs/API.md",
      "generated CLDR data",
      "API docs must classify generated CLDR data as private");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "with I18N.CLDR_Data;",
      "public import rules must forbid direct CLDR data imports");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "with I18N.Number_Format;",
      "public import rules must forbid direct number formatter imports");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "with I18N.Currency;",
      "public import rules must forbid direct currency formatter imports");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "with I18N.Date_Time_Format;",
      "public import rules must forbid direct date/time formatter imports");
   Require_Text
     ("docs/PUBLIC_IMPORT_RULES.md",
      "with I18N.Extra_Format;",
      "public import rules must forbid direct domain formatter imports");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "Formatter implementation packages and generated CLDR data",
      "public API boundary docs must classify formatter and CLDR internals");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "I18N.Number_Format",
      "public API boundary docs must list private number formatter");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "I18N.Currency",
      "public API boundary docs must list private currency formatter");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "I18N.Date_Time_Format",
      "public API boundary docs must list private date/time formatter");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "I18N.Extra_Format",
      "public API boundary docs must list private domain formatter");
   Require_Text
     ("docs/PUBLIC_API_BOUNDARY.md",
      "I18N.CLDR_Data",
      "public API boundary docs must list private CLDR data package");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.Number_Format;",
      "example docs must forbid direct number formatter imports");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.Currency;",
      "example docs must forbid direct currency formatter imports");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.Date_Time_Format;",
      "example docs must forbid direct date/time formatter imports");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.Extra_Format;",
      "example docs must forbid direct domain formatter imports");
   Require_Text
     ("docs/EXAMPLES.md",
      "with I18N.CLDR_Data;",
      "example docs must forbid direct CLDR data imports");
   Require_Text
     ("docs/EXAMPLES.md",
      "Formatter",
      "example docs must classify formatter and CLDR internals as private");
   Require_Text
     ("docs/EXAMPLES.md",
      "generated CLDR data",
      "example docs must classify generated CLDR internals as private");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "with I18N.Number_Format;",
      "AI consumption guide must forbid direct number formatter imports");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "with I18N.Currency;",
      "AI consumption guide must forbid direct currency formatter imports");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "with I18N.Date_Time_Format;",
      "AI consumption guide must forbid direct date/time formatter imports");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "with I18N.Extra_Format;",
      "AI consumption guide must forbid direct domain formatter imports");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "with I18N.CLDR_Data;",
      "AI consumption guide must forbid direct CLDR data imports");
   Require_Text
     ("docs/AI_CONSUMPTION_GUIDE.md",
      "Formatter implementation packages and generated CLDR data",
      "AI consumption guide must classify formatter and CLDR internals as private");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      "formatter implementation packages, generated CLDR data",
      "AI file role map must classify formatter and CLDR packages as private");
   Require_Text
     ("ai/FILE_ROLE_MAP.json",
      "CLDR data-boundary checks, benchmark smoke checks",
      "AI file role map release note must include CLDR and benchmark checks");
   Require_Text
     ("tests/alire.toml",
      "project_tools",
      "i18n tests must use project_tools for shared tooling helpers");
   Require_Text
     (".github/workflows/ci.yml",
      "Check out project_tools sibling",
      "CI workflow must check out the project_tools sibling crate");
   Require_Text
     (".github/workflows/ci.yml",
      "Run AUnit tests",
      "CI workflow must run the AUnit tests");
   Require_Text
     (".github/workflows/ci.yml",
      "Build public examples",
      "CI workflow must build public examples");
   Require_Text
     (".github/workflows/ci.yml",
      "Run public example output checks",
      "CI workflow must run public example output checks");
   Require_Text
     (".github/workflows/ci.yml",
      "Build render benchmarks",
      "CI workflow must build render benchmarks");
   Require_Text
     (".github/workflows/ci.yml",
      "Run render benchmark smoke",
      "CI workflow must run render benchmark smoke");
   Require_Text
     (".github/workflows/ci.yml",
      "Generate GNATdoc",
      "CI workflow must generate documentation");
   Require_Text
     (".github/workflows/ci.yml",
      "Run project_tools release checker",
      "CI workflow must run check_i18n");
   Require_Text
     (".github/workflows/ci.yml",
      "Run Alire packaging test action",
      "CI workflow must run the Alire packaging test action");

   Check_Alire_Publication_Readiness;
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
