--  Bring the generated CLDR tables into existence, from whatever the tree has.
--
--  src/i18n-cldr_data*.adb are build artifacts, not sources: they are gitignored
--  because re-committing a 14 MB generated file on every generator change bloats
--  history permanently. That leaves a clone with the spec and no body, so the
--  build has to be able to produce one. This is the cascade that does it,
--  cheapest path first:
--
--    1. body already present  -> nothing to do (but still fill runtime data)
--    2. data/cldr_subset.txt  -> generate
--    3. upstream/cldr-json    -> import, then generate
--    4. nothing               -> download the release, import, then generate
--
--  Only step 1 costs anything in the normal case, so this is safe to run before
--  every build. Steps 2-4 are what a fresh clone or a CI runner actually needs.
--
--  A standalone, dependency-free program (so it builds with plain gprbuild) run
--  as the i18n pre-build action. It spawns the generator and download tools --
--  itself the reason cldr is a separate crate: the library never inherits their
--  HTTP stack and ZIP decoder. The optional UCD downloads run through the
--  fetch_ucd tool, spawned here best-effort.
--
--  Run from the i18n crate root (Alire pre-build actions already are).

with Ada.Calendar;             use type Ada.Calendar.Time;
with Ada.Command_Line;         use Ada.Command_Line;
with Ada.Directories;          use Ada.Directories;
with Ada.Text_IO;              use Ada.Text_IO;

with GNAT.OS_Lib;

procedure Regenerate is

   package OS renames GNAT.OS_Lib;
   use type OS.String_Access;

   Root     : constant String := Current_Directory;
   Cldr     : constant String := Root & "/cldr";
   Body_F   : constant String := Root & "/src/i18n-cldr_data.adb";
   Subset   : constant String := Cldr & "/data/cldr_subset.txt";
   Upstream : constant String := Cldr & "/upstream/cldr-json";
   Ucd      : constant String := Cldr & "/upstream/ucd";
   Uca      : constant String := Cldr & "/upstream/uca";
   Ucd16    : constant String := Cldr & "/upstream/ucd16";
   Share    : constant String := Root & "/share/i18n";

   No_Args : constant OS.Argument_List (1 .. 0) := (others => <>);

   Regenerate_Failed : exception;

   function "+" (Text : String) return OS.String_Access is (new String'(Text));

   procedure Log (Message : String) is
   begin
      Put_Line ("cldr: " & Message);
   end Log;

   procedure Fail (Message : String) is
   begin
      Put_Line (Standard_Error, "cldr: " & Message);
      raise Regenerate_Failed;
   end Fail;

   function File_Here (Path : String) return Boolean is
     (Exists (Path) and then Kind (Path) = Ordinary_File);

   function Dir_Here (Path : String) return Boolean is
     (Exists (Path) and then Kind (Path) = Directory);

   --  A *generated artifact* that is there.
   --
   --  Stricter than File_Here on purpose: a zero-byte file is not data. The
   --  repository tracks empty placeholders for several of these so that a
   --  fresh clone has the paths, and every "is it already generated?" test
   --  below answered yes for a file holding nothing -- so a clone shipped
   --  empty tables and nothing regenerated them.
   function Data_Here (Path : String) return Boolean is
     (File_Here (Path) and then Size (Path) > 0);

   --  A built generator, tolerating a .exe suffix on Windows.
   function Binary_Here (Path : String) return Boolean is
     (File_Here (Path) or else File_Here (Path & ".exe"));

   --  Resolve a program to a spawnable path: a name with a separator is used
   --  as given (with a .exe fallback); a bare name is searched on PATH.
   function Resolve (Program : String) return String is
      Has_Sep : constant Boolean :=
        (for some C of Program => C = '/' or else C = '\');
   begin
      if Has_Sep then
         return (if File_Here (Program & ".exe") and then not File_Here (Program)
                 then Program & ".exe" else Program);
      end if;

      declare
         Located : OS.String_Access := OS.Locate_Exec_On_Path (Program);
      begin
         if Located = null then
            return Program;   --  not found; Spawn fails with a clear error
         end if;
         return Result : constant String := Located.all do
            OS.Free (Located);
         end return;
      end;
   end Resolve;

   --  Run Program with Args, optionally from directory Dir. Aborts the whole
   --  regeneration on a non-zero exit unless Allow_Failure is set, which lets a
   --  best-effort step continue past a failure.
   procedure Run
     (Program       : String;
      Args          : OS.Argument_List := No_Args;
      Dir           : String := "";
      Allow_Failure : Boolean := False)
   is
      Saved : constant String := Current_Directory;
      Code  : Integer;
   begin
      if Dir /= "" then
         Set_Directory (Dir);
      end if;

      Code := OS.Spawn (Resolve (Program), Args);

      if Dir /= "" then
         Set_Directory (Saved);
      end if;

      if Code /= 0 and then not Allow_Failure then
         Fail (Program & " exited with status" & Code'Image);
      end if;
   end Run;

   --  Spawn a generator (absolute path under cldr/bin) from the cldr directory,
   --  where the generators expect to run (they write ../share/i18n).
   procedure Generate_With (Tool : String) is
   begin
      Run (Cldr & "/bin/" & Tool, Dir => Cldr);
   end Generate_With;

   --  The generators are their own crate (cldr_tools) so that the library never
   --  inherits an HTTP stack and a ZIP decoder. Build them on demand.
   Tools : constant array (Positive range <>) of OS.String_Access :=
     [+"generate_cldr_data",
      +"generate_cldr_display_data",
      +"generate_cldr_annotation_data",
      +"generate_cldr_calendar_data",
      +"generate_cldr_personname_data",
      +"generate_cldr_rbnf_data",
      +"generate_ucd_normalization_data",
      +"generate_ucd_segmentation_data",
      +"generate_uca_collation_data",
      +"generate_cldr_collation_tailoring",
      +"generate_ucd_uprops_data",
      +"generate_cldr_transform_data",
      +"download_tzdb",
      +"fetch_ucd"];

   --  Whether the generators can be run here at all.
   --
   --  They are their own crate with their own dependencies -- an HTTP client,
   --  an archive reader, an awk -- and a *consumer* of this library checks out
   --  the crates this library needs, not the crates its tooling needs. So a
   --  build of i18n inside somebody else's workspace can be a build where the
   --  generators cannot even be compiled, and that is not an error in their
   --  build: the library compiles and runs without the runtime data, and the
   --  feature that needs a missing file reports itself unavailable.
   --
   --  Said out loud rather than passed over in silence, because a consumer who
   --  *does* need the data -- messages, which formats real locales -- must be
   --  able to see why it is not there. That one asserts the file exists in its
   --  own CI, which is exactly the right place for the question.
   function Tools_Ready return Boolean is
      Missing : Boolean := False;
   begin
      for Tool of Tools loop
         if not Binary_Here (Cldr & "/bin/" & Tool.all) then
            Missing := True;
            exit;
         end if;
      end loop;

      if Missing then
         Log ("building the CLDR tools");
         Run ("alr",
              [+"-n", +"build", +"--profiles=*=development"],
              Dir => Cldr, Allow_Failure => True);
      end if;

      for Tool of Tools loop
         if not Binary_Here (Cldr & "/bin/" & Tool.all) then
            Log ("the CLDR tools are not available in this workspace; "
                 & "leaving the runtime data as it is");
            return False;
         end if;
      end loop;

      return True;
   end Tools_Ready;

   --  Set once the answer is known, so that the handler at the end can tell a
   --  workspace without the tooling from a generator that went wrong, without
   --  trying to build the tools a second time to find out.
   Tooling_Absent : Boolean := False;

   procedure Build_Tools is
   begin
      if not Tools_Ready then
         Tooling_Absent := True;
         raise Regenerate_Failed;
      end if;
   end Build_Tools;

   --  Fetch the UCD files (unicode.org) via the fetch_ucd tool, best-effort.
   --  It uses crate-root-relative paths, so run it from the root (no Dir),
   --  unlike the cldr/-relative generators.
   procedure Fetch_Ucd is
   begin
      Build_Tools;
      Run (Cldr & "/bin/fetch_ucd", Allow_Failure => True);
   end Fetch_Ucd;

   --  Runtime data files for the "heavy/optional" areas read upstream cldr-json
   --  directly, so each is generated only when its vendored upstream is present
   --  and its output is missing. Best-effort: the library compiles and runs
   --  without them, the feature just reports itself unavailable.
   procedure Generate_Runtime_Data is
   begin
      if not Data_Here (Share & "/display-names.i18ndata")
        and then Dir_Here (Upstream & "/cldr-localenames-full")
      then
         Build_Tools;
         Log ("generating share/i18n/display-names.i18ndata");
         Generate_With ("generate_cldr_display_data");
      end if;

      if not Dir_Here (Share & "/annotations")
        and then Dir_Here (Upstream & "/cldr-annotations-full")
      then
         Build_Tools;
         Log ("generating share/i18n/annotations shards");
         Generate_With ("generate_cldr_annotation_data");
      end if;

      if not Dir_Here (Share & "/calendars")
        and then Dir_Here (Upstream & "/cldr-cal-islamic-full")
      then
         Build_Tools;
         Log ("generating share/i18n/calendars shards");
         Generate_With ("generate_cldr_calendar_data");
      end if;

      if not Dir_Here (Share & "/person-names")
        and then Dir_Here (Upstream & "/cldr-person-names-full")
      then
         Build_Tools;
         Log ("generating share/i18n/person-names shards");
         Generate_With ("generate_cldr_personname_data");
      end if;

      if not Dir_Here (Share & "/rbnf")
        and then Dir_Here (Upstream & "/cldr-rbnf")
      then
         Build_Tools;
         Log ("generating share/i18n/rbnf shards");
         Generate_With ("generate_cldr_rbnf_data");
      end if;

      --  UCD normalization data (from unicode.org, not cldr-json). Fetch the
      --  UCD files if missing, then generate; best-effort like the rest.
      if not Data_Here (Share & "/normalization.i18ndata") then
         if not File_Here (Ucd & "/UnicodeData.txt") then
            Fetch_Ucd;
         end if;
         if File_Here (Ucd & "/UnicodeData.txt") then
            Build_Tools;
            Log ("generating share/i18n/normalization.i18ndata");
            Generate_With ("generate_ucd_normalization_data");
         end if;
      end if;

      --  Segmentation break tables (UAX #29 / #14), also from the UCD.
      if not Data_Here (Share & "/segmentation.i18ndata") then
         if not File_Here (Ucd & "/LineBreak.txt") then
            Fetch_Ucd;
         end if;
         if File_Here (Ucd & "/LineBreak.txt") then
            Build_Tools;
            Log ("generating share/i18n/segmentation.i18ndata");
            Generate_With ("generate_ucd_segmentation_data");
         end if;
      end if;

      --  Collation (UCA DUCET root + CLDR locale tailorings).
      if not Data_Here (Share & "/collation.i18ndata") then
         if not File_Here (Uca & "/allkeys.txt") then
            Fetch_Ucd;
         end if;
         if File_Here (Uca & "/allkeys.txt") then
            Build_Tools;
            Log ("generating share/i18n/collation.i18ndata");
            Generate_With ("generate_uca_collation_data");
            if Dir_Here (Cldr & "/upstream/collation") then
               Log ("generating share/i18n/collation/ tailoring shards");
               Generate_With ("generate_cldr_collation_tailoring");
            end if;
         end if;
      end if;

      --  Transliteration (UCA/UCD 16 properties + CLDR transform catalog).
      if not Data_Here (Share & "/uprops.i18ndata") then
         if not File_Here (Ucd16 & "/Scripts.txt") then
            Fetch_Ucd;
         end if;
         if File_Here (Ucd16 & "/Scripts.txt") then
            Build_Tools;
            Log ("generating share/i18n/uprops.i18ndata");
            Generate_With ("generate_ucd_uprops_data");
         end if;
      end if;

      if not Data_Here (Share & "/transforms/_index.i18ndata")
        and then Dir_Here (Cldr & "/upstream/transforms")
      then
         Build_Tools;
         Log ("generating share/i18n/transforms/ catalog");
         Generate_With ("generate_cldr_transform_data");
      end if;
   end Generate_Runtime_Data;

   --  The tzdb fixtures (rearguard tzdata.zi + zone tables) are downloaded from
   --  IANA and built by running the tz project's ziguard/zishrink scripts
   --  through awklib -- no external awk. generate_cldr_data reads them, so fetch
   --  them first when a fresh tree lacks them.
   procedure Ensure_TZDB is
   begin
      if not File_Here (Cldr & "/upstream/tzdb/tzdata.zi") then
         Build_Tools;
         Log ("fetching and building the tzdb fixtures");
         Run (Cldr & "/bin/download_tzdb", Dir => Cldr);
      end if;
   end Ensure_TZDB;

   procedure Generate is
   begin
      Build_Tools;
      Ensure_TZDB;
      Log ("generating " & Body_F);
      Generate_With ("generate_cldr_data");
      Generate_Runtime_Data;
   end Generate;

   procedure Import_From_Upstream is
   begin
      Build_Tools;
      Log ("importing from " & Upstream & " (this takes a while)");
      Generate_With ("generate_cldr_export");
      Generate_With ("import_cldr_raw");
      Generate_With ("extract_cldr_normalized");
      Generate_With ("import_cldr_subset");
   end Import_From_Upstream;

   --  Whether the upstream release could be fetched.
   --
   --  Best-effort, like the runtime data it exists to produce. A workspace
   --  that cannot reach the CDN -- a Windows runner whose TLS trust store will
   --  not load, a machine with no network, a build behind a proxy that refuses
   --  it -- is not a broken build: this library compiles and runs from the
   --  tables already in it, and the feature that needs a missing file reports
   --  itself unavailable.
   --
   --  Said out loud, and left to the consumer that actually needs the data to
   --  insist on it. messages formats real locales and asserts the file exists
   --  in its own CI; adash uses this library for its catalogue and never asks
   --  for a locale's formats, and a download it does not need must not be able
   --  to stop it building.
   function Fetched_Upstream return Boolean is
   begin
      Build_Tools;
      if not Binary_Here (Cldr & "/bin/download_cldr_upstream") then
         Log ("the downloader is not built here; leaving the upstream alone");
         return False;
      end if;

      Log ("fetching the CLDR release named by upstream/source_manifest.txt");
      Run (Cldr & "/bin/download_cldr_upstream", Dir => Cldr,
           Allow_Failure => True);

      if not Dir_Here (Upstream) then
         Log ("the CLDR upstream could not be fetched here; "
              & "leaving the runtime data as it is");
         return False;
      end if;

      return True;
   end Fetched_Upstream;

begin
   if not Dir_Here (Cldr) then
      Fail ("no " & Cldr & " directory; cannot regenerate");
   end if;

   --  Step 1 -- the compiled body is already current. "Current" means newer
   --  than the subset it is generated from; without the timestamp test a stale
   --  body silently survives a subset change. The runtime data files are
   --  separate artifacts, so still (re)generate them when they are missing.
   if File_Here (Body_F)
     and then Data_Here (Share & "/formats.i18ndata")
   then
      if not File_Here (Subset)
        or else Modification_Time (Body_F) > Modification_Time (Subset)
      then
         Generate_Runtime_Data;
         return;
      end if;
      Log (Body_F & " is older than " & Subset & "; regenerating");
   end if;

   --  The formats file is asked about beside the body because one generator
   --  writes both, and only one of them is tracked. Tracking the body made
   --  this step conclude that everything was current on a fresh clone, and
   --  return -- and formats.i18ndata, which nothing else writes, was never
   --  produced. A consumer's CI found it: `messages` builds, then tests
   --  `test -f ../i18n/share/i18n/formats.i18ndata`, and had been failing on
   --  all three hosts since the body was tracked.

   --  Step 2 -- the pinned subset is the generator's real input.
   if File_Here (Subset) then
      Generate;
      return;
   end if;

   --  Step 3 -- upstream JSON present: import down to the subset, then generate.
   if Dir_Here (Upstream) then
      Import_From_Upstream;
      Generate;
      return;
   end if;

   --  Step 4 -- nothing local: fetch the release, then fall through 3 and 2.
   if Fetched_Upstream then
      Import_From_Upstream;
      Generate;
   end if;

exception
   when Regenerate_Failed =>
      if not Tooling_Absent then
         --  A real failure: the tools are here and something they did went
         --  wrong.
         Set_Exit_Status (Failure);
      end if;

      --  Otherwise this is a workspace that carries the library and not its
      --  tooling. Nothing was regenerated and nothing is broken; the consumer
      --  that needs the data says so where it needs it.
end Regenerate;
