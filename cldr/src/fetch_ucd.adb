--  Fetch the Unicode Character Database files the normalization engine (and the
--  later break / collation / transliteration phases) build from. UCD is not part
--  of cldr-json, so it is fetched separately from unicode.org, pinned to the
--  Unicode version CLDR aligns with. Kept in the tools/build layer -- the library
--  never fetches.
--
--  The Ada replacement for the former cldr/fetch_ucd.sh: it downloads over
--  httpclient (no curl) and unpacks the collation test archive with zlib (no
--  unzip). Built by cldr_download.gpr alongside download_cldr_upstream -- the
--  two tools that carry the HTTP stack and ZIP decoder the generators never do.
--
--  Run from the i18n crate root.  Usage: fetch_ucd [version]

with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Directories;   use Ada.Directories;
with Ada.Text_IO;       use Ada.Text_IO;

with Http_Client.Clients;
with Http_Client.Errors;
with Http_Client.Headers;
with Http_Client.Responses;

with Zlib;

procedure Fetch_Ucd is

   package HC renames Http_Client;
   use type HC.Errors.Result_Status;
   use type Zlib.Status_Code;

   type Name_Ref is access constant String;
   type Name_List is array (Positive range <>) of Name_Ref;

   Version    : constant String :=
     (if Argument_Count >= 1 then Argument (1) else "17.0.0");

   Ucd_Base   : constant String :=
     "https://www.unicode.org/Public/" & Version & "/ucd";
   Ucd_Dest   : constant String := "cldr/upstream/ucd";

   Uca_Ver    : constant String := "16.0.0";
   Uca_Dest   : constant String := "cldr/upstream/uca";
   Cldr_Tag   : constant String := "release-46";
   Col_Dest   : constant String := "cldr/upstream/collation";
   Ucd16_Ver  : constant String := "16.0.0";
   Ucd16_Dest : constant String := "cldr/upstream/ucd16";
   Tx_Dest    : constant String := "cldr/upstream/transforms";
   Td_Dest    : constant String := "cldr/upstream/transforms_test";
   Raw_Base   : constant String :=
     "https://raw.githubusercontent.com/unicode-org/cldr/" & Cldr_Tag & "/common";
   Api_Base   : constant String :=
     "https://api.github.com/repos/unicode-org/cldr/contents/common";

   Fetch_Failed : exception;
   Any_Failure  : Boolean := False;

   --  Downloads stream straight to file, so advertising a transfer encoding
   --  would land the compressed bytes on disk undecoded. Ask for identity, the
   --  way curl does by default, so the served file is what is written.
   function Plain_Config return HC.Clients.Client_Configuration is
      Config : HC.Clients.Client_Configuration :=
        HC.Clients.Default_Client_Configuration;
   begin
      Config.Enable_Decompression := False;
      return Config;
   end Plain_Config;

   Download_Config : constant HC.Clients.Client_Configuration := Plain_Config;

   --  The ZIP decoder holds the archive image and inflate state on the stack,
   --  so extraction runs in a task with a large stack (as download_cldr_upstream
   --  does); the default stack overflows on a multi-megabyte archive.
   Unpack_Stack : constant := 512 * 1024 * 1024;

   procedure Note (Message : String) is
   begin
      Put_Line (Standard_Error, "fetch_ucd: " & Message);
      Any_Failure := True;
   end Note;

   --  Download URL to Dest if Dest is absent. Essential downloads abort the run
   --  on failure (mirroring the script's "set -e" + "curl -f"); best-effort ones
   --  log and continue (the script's "|| true" / "2>/dev/null" downloads).
   procedure Download
     (URL       : String;
      Dest      : String;
      Label     : String;
      Essential : Boolean := True)
   is
      Result  : HC.Clients.Download_Result;
      Options : HC.Clients.Download_Options := HC.Clients.Default_Download_Options;
      Status  : HC.Errors.Result_Status;
   begin
      if Exists (Dest) then
         return;
      end if;

      Put_Line (Label);
      Options.Create_Parent_Dirs := True;
      Status :=
        HC.Clients.Download_To_File (URL, Dest, Result, Options, Download_Config);

      if Status /= HC.Errors.Ok then
         if Exists (Dest) then
            Delete_File (Dest);
         end if;
         Note ("failed " & URL & " (" & Status'Image
               & " HTTP" & Result.HTTP_Status_Code'Image & ")");
         if Essential then
            raise Fetch_Failed;
         end if;
      end if;
   end Download;

   procedure Fetch (File, Sub : String) is
      Rel : constant String := (if Sub = "" then File else Sub & "/" & File);
   begin
      Download (Ucd_Base & "/" & Rel, Ucd_Dest & "/" & Rel, "ucd: fetching " & Rel);
   end Fetch;

   --  Normalization + segmentation UCD files.
   procedure Fetch_Ucd_Files is
      Root_Files : constant Name_List :=
        [new String'("UnicodeData.txt"),
         new String'("CompositionExclusions.txt"),
         new String'("DerivedNormalizationProps.txt"),
         new String'("NormalizationTest.txt"),
         new String'("LineBreak.txt"),
         new String'("DerivedCoreProperties.txt"),
         new String'("EastAsianWidth.txt")];
      Aux_Files  : constant Name_List :=
        [new String'("GraphemeBreakProperty.txt"),
         new String'("WordBreakProperty.txt"),
         new String'("SentenceBreakProperty.txt"),
         new String'("GraphemeBreakTest.txt"),
         new String'("WordBreakTest.txt"),
         new String'("SentenceBreakTest.txt"),
         new String'("LineBreakTest.txt")];
   begin
      for F of Root_Files loop
         Fetch (F.all, "");
      end loop;
      for F of Aux_Files loop
         Fetch (F.all, "auxiliary");
      end loop;
      Fetch ("emoji-data.txt", "emoji");
      Put_Line ("ucd: " & Version & " present in " & Ucd_Dest);
   end Fetch_Ucd_Files;

   --  UCA collation: keys, PropList, and the conformance test archive.
   procedure Fetch_Collation is
      Test_Marker : constant String :=
        Uca_Dest & "/CollationTest/CollationTest_SHIFTED.txt";
      Zip_Path    : constant String := Uca_Dest & "/CollationTest.zip";
      Status      : Zlib.Status_Code;
   begin
      Download
        ("https://www.unicode.org/Public/UCA/" & Uca_Ver & "/allkeys.txt",
         Uca_Dest & "/allkeys.txt", "uca: fetching allkeys.txt");
      Download
        ("https://www.unicode.org/Public/" & Uca_Ver & "/ucd/PropList.txt",
         Uca_Dest & "/PropList.txt", "uca: fetching PropList.txt (" & Uca_Ver & ")");

      if not Exists (Test_Marker) then
         Download
           ("https://www.unicode.org/Public/UCA/" & Uca_Ver & "/CollationTest.zip",
            Zip_Path, "uca: fetching CollationTest.zip");
         if Exists (Zip_Path) then
            Status := Zlib.Input_File_Error;
            declare
               task Unpacker with Storage_Size => Unpack_Stack;
               task body Unpacker is
               begin
                  Zlib.Extract_Archive_File_To_Directory
                    (Zip_Path, Uca_Dest, "", Status);
               exception
                  when others =>
                     Status := Zlib.Input_File_Error;
               end Unpacker;
            begin
               null;   --  await the unpacker
            end;
            if Status /= Zlib.Ok then
               Note ("unzip CollationTest.zip failed (" & Status'Image & ")");
            end if;
         end if;
      end if;

      --  CLDR standard collation tailorings for locales with non-trivial rules;
      --  best-effort, like the script.
      declare
         Locales : constant Name_List :=
           [new String'("sv"), new String'("da"), new String'("nb"),
            new String'("fi"), new String'("is"), new String'("es"),
            new String'("ca"), new String'("pt"), new String'("et"),
            new String'("pl"), new String'("cs"), new String'("sk"),
            new String'("sl"), new String'("hr"), new String'("hu"),
            new String'("ro"), new String'("tr"), new String'("az"),
            new String'("lt"), new String'("lv"), new String'("vi")];
      begin
         for Loc of Locales loop
            Download
              (Raw_Base & "/collation/" & Loc.all & ".xml",
               Col_Dest & "/" & Loc.all & ".xml",
               "collation: " & Loc.all & ".xml", Essential => False);
         end loop;
      end;
      Put_Line ("uca: " & Uca_Ver & " / CLDR " & Cldr_Tag & " collation data present");
   end Fetch_Collation;

   --  Unicode 16 property/case data for the transliteration phase.
   procedure Fetch_Ucd16 is
      Files : constant Name_List :=
        [new String'("Scripts.txt"),
         new String'("SpecialCasing.txt"),
         new String'("UnicodeData.txt"),
         new String'("PropertyValueAliases.txt"),
         new String'("DerivedCoreProperties.txt")];
   begin
      for F of Files loop
         Download
           ("https://www.unicode.org/Public/" & Ucd16_Ver & "/ucd/" & F.all,
            Ucd16_Dest & "/" & F.all, "ucd16: fetching " & F.all);
      end loop;
      Download
        ("https://www.unicode.org/Public/" & Ucd16_Ver
         & "/ucd/extracted/DerivedGeneralCategory.txt",
         Ucd16_Dest & "/DerivedGeneralCategory.txt",
         "ucd16: fetching DerivedGeneralCategory.txt");
   end Fetch_Ucd16;

   --  A GitHub API contents listing carries the file names in JSON "name"
   --  fields; pull each one whose name ends in Suffix and download its raw file.
   procedure Fetch_Listing
     (Api_Url, Raw_Dir, Dest, Suffix, Label : String)
   is
      Config : HC.Clients.Client_Configuration := Plain_Config;
      Result : HC.Clients.Client_Result;
      Status : HC.Errors.Result_Status;
   begin
      --  GitHub rejects API requests without a User-Agent; identity encoding
      --  (from Plain_Config) keeps the JSON body directly readable.
      Status := HC.Headers.Set
        (Config.Default_Headers, "User-Agent", "i18n-fetch-ucd");
      if Status /= HC.Errors.Ok then
         Note ("could not set User-Agent header");
         return;
      end if;

      Status := HC.Clients.Get (Api_Url, Result, Config);
      if Status /= HC.Errors.Ok then
         Note ("listing failed " & Api_Url & " (" & Status'Image & ")");
         return;
      end if;

      declare
         Payload : constant String := HC.Responses.Response_Body (Result.Response);
         Index   : Positive := Payload'First;
      begin
         while Index <= Payload'Last loop
            if Index + 5 <= Payload'Last
              and then Payload (Index .. Index + 5) = """name"""
            then
               Index := Index + 6;
               while Index <= Payload'Last
                 and then (Payload (Index) = ' '
                           or else Payload (Index) = ':'
                           or else Payload (Index) = ASCII.HT)
               loop
                  Index := Index + 1;
               end loop;

               if Index <= Payload'Last and then Payload (Index) = '"' then
                  Index := Index + 1;
                  declare
                     Start : constant Positive := Index;
                  begin
                     while Index <= Payload'Last
                       and then Payload (Index) /= '"'
                     loop
                        Index := Index + 1;
                     end loop;
                     declare
                        Name : constant String := Payload (Start .. Index - 1);
                     begin
                        if Name'Length > Suffix'Length
                          and then Name (Name'Last - Suffix'Length + 1 .. Name'Last)
                                     = Suffix
                        then
                           Download
                             (Raw_Dir & "/" & Name, Dest & "/" & Name,
                              Label & Name, Essential => False);
                        end if;
                     end;
                  end;
               end if;
            else
               Index := Index + 1;
            end if;
         end loop;
      end;
   end Fetch_Listing;

   --  CLDR transform catalog + its conformance testData.
   procedure Fetch_Transforms is
   begin
      if Exists (Tx_Dest & "/Greek-Latin.xml") then
         return;
      end if;
      Put_Line ("transforms: fetching the CLDR transform catalog + testData");
      Fetch_Listing
        (Api_Base & "/transforms?ref=" & Cldr_Tag,
         Raw_Base & "/transforms", Tx_Dest, ".xml", "transforms: ");
      Fetch_Listing
        (Api_Base & "/testData/transforms?ref=" & Cldr_Tag,
         Raw_Base & "/testData/transforms", Td_Dest, ".txt", "transforms/test: ");
   end Fetch_Transforms;

begin
   begin
      Fetch_Ucd_Files;
      Fetch_Collation;
      Fetch_Ucd16;
      Fetch_Transforms;
      Put_Line ("transliteration data present");
   exception
      when Fetch_Failed =>
         null;   --  an essential download failed; Any_Failure is already set
   end;

   if Any_Failure then
      Set_Exit_Status (Failure);
   end if;
end Fetch_Ucd;
