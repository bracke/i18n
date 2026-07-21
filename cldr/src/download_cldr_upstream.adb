--  Fetch the upstream CLDR-JSON release named by upstream/source_manifest.txt.
--
--  A clone carries the provenance manifest but not the 810 MB of upstream JSON
--  it names -- that is deliberately untracked. This tool is the first step of
--  the regeneration cascade (see CLDR_DATA.md): it turns the manifest's
--  cldr_version into a cldr-json GitHub release asset URL, downloads that
--  archive, and unpacks it into upstream/cldr-json so that
--  generate_cldr_export can run.
--
--  Run it from cldr/:
--
--     ./bin/download_cldr_upstream [--force] [--dest=DIR] [--keep-archive]

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Http_Client.Clients;
with Http_Client.Errors;

with Project_Tools.Files;

with Zlib;

procedure Download_CLDR_Upstream is

   use type Http_Client.Errors.Result_Status;
   use type Zlib.Status_Code;

   Manifest_Path : constant String := "upstream/source_manifest.txt";
   --  Tracked provenance: the one file in upstream/ that a clone does have.

   Default_Dest : constant String := "upstream";

   Release_Base : constant String := "https://github.com/unicode-org/cldr-json/releases/download/";
   --  The cldr-json project publishes one "-json-full.zip" asset per release
   --  tag. https://cldr.unicode.org/index/downloads links here.

   Max_Archive_Bytes : constant Natural := 512 * 1024 * 1024;
   --  The 48.2.0 asset is 82 MB. The cap is a sanity bound, not a tight fit:
   --  it exists so a redirect to something unexpected cannot fill the disk.

   procedure Put_Line (Item : String) renames Ada.Text_IO.Put_Line;

   function Has_Argument (Value : String) return Boolean;
   function Argument_Value (Prefix : String; Default : String) return String;
   function Release_Tag (Version : String) return String;
   function Archive_URL (Tag : String) return String;
   function Extracted_Root (Staging : String) return String;
   procedure Fail (Message : String);
   procedure Unpack_Into
     (Archive_Path : String;
      Staging_Dir  : String;
      Status       : out Zlib.Status_Code;
      Failure      : out Ada.Strings.Unbounded.Unbounded_String);

   ---------------------
   --  Has_Argument   --
   ---------------------

   function Has_Argument (Value : String) return Boolean is
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (Index) = Value then
            return True;
         end if;
      end loop;
      return False;
   end Has_Argument;

   ----------------------
   --  Argument_Value  --
   ----------------------

   function Argument_Value (Prefix : String; Default : String) return String is
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Argument : constant String := Ada.Command_Line.Argument (Index);
         begin
            if Argument'Length > Prefix'Length
              and then Argument (Argument'First .. Argument'First + Prefix'Length - 1) = Prefix
            then
               return Argument (Argument'First + Prefix'Length .. Argument'Last);
            end if;
         end;
      end loop;
      return Default;
   end Argument_Value;

   ------------
   --  Fail  --
   ------------

   procedure Fail (Message : String) is
   begin
      Put_Line ("download_cldr_upstream: " & Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Fail;

   -------------------
   --  Release_Tag  --
   -------------------

   --  The manifest records the CLDR version ("48.2"); cldr-json tags releases
   --  with a three-part version ("48.2.0"). Append the missing patch level
   --  rather than guessing from the release list, so the same manifest always
   --  resolves to the same tag. A manifest may override this outright with
   --  source_release_tag when a rebuild (48.2.1) is wanted instead.

   function Release_Tag (Version : String) return String is
      Override : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_release_tag");
      Dots     : Natural := 0;
   begin
      if Override /= "" then
         return Override;
      end if;

      for Character of Version loop
         if Character = '.' then
            Dots := Dots + 1;
         end if;
      end loop;

      if Dots >= 2 then
         return Version;
      elsif Dots = 1 then
         return Version & ".0";
      else
         return Version & ".0.0";
      end if;
   end Release_Tag;

   -------------------
   --  Archive_URL  --
   -------------------

   function Archive_URL (Tag : String) return String is
      Override : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_archive_url");
   begin
      if Override /= "" then
         return Override;
      end if;
      return Release_Base & Tag & "/cldr-" & Tag & "-json-full.zip";
   end Archive_URL;

   ---------------------
   --  Extracted_Root --
   ---------------------

   --  Accept both plausible archive shapes: the packages nested under a
   --  "cldr-json" directory, or the packages at the archive root. The
   --  regeneration tools read upstream/cldr-json/<package>/..., so whichever
   --  directory actually holds cldr-core is the one to install.

   function Extracted_Root (Staging : String) return String is
      Nested : constant String := Project_Tools.Files.Join (Staging, "cldr-json");
   begin
      if Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Nested, "cldr-core")) then
         return Nested;
      elsif Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Staging, "cldr-core")) then
         return Staging;
      else
         return "";
      end if;
   end Extracted_Root;

   --------------------
   --  Unpack_Into   --
   --------------------

   --  Zlib reads an archive into stack-allocated arrays -- twice over, as a
   --  stream buffer and then as bytes -- so unpacking an 82 MB release asset
   --  needs an order of magnitude more stack than the 8 MB a process gets by
   --  default. Do it on a task whose stack is sized for the job rather than
   --  requiring every caller to raise their shell's limit first.

   Unpack_Stack_Bytes : constant := 512 * 1024 * 1024;

   procedure Unpack_Into
     (Archive_Path : String;
      Staging_Dir  : String;
      Status       : out Zlib.Status_Code;
      Failure      : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Outcome : Zlib.Status_Code := Zlib.Input_File_Error;
      Trouble : Ada.Strings.Unbounded.Unbounded_String;
   begin
      declare
         task Unpacker with Storage_Size => Unpack_Stack_Bytes;

         task body Unpacker is
         begin
            Zlib.Extract_Archive_File_To_Directory
              (Archive_Path    => Archive_Path,
               Destination_Dir => Staging_Dir,
               Password        => "",
               Status          => Outcome);
         exception
            --  A task that dies of an unhandled exception dies silently, and
            --  Outcome would still read Input_File_Error -- naming the wrong
            --  cause for the one failure this task exists to contain. Sizing
            --  the stack is a bet on how much the decoder needs; if the bet is
            --  wrong the Storage_Error must say so, not masquerade as a
            --  missing file.
            when Error : others =>
               Trouble :=
                 Ada.Strings.Unbounded.To_Unbounded_String
                   (Ada.Exceptions.Exception_Name (Error) & ": " & Ada.Exceptions.Exception_Message (Error));
         end Unpacker;
      begin
         null;  --  Unpacker is awaited on leaving this block.
      end;

      Status := Outcome;
      Failure := Trouble;
   end Unpack_Into;

   Destination : constant String := Argument_Value ("--dest=", Default_Dest);
   Install_Dir : constant String := Project_Tools.Files.Join (Destination, "cldr-json");
   Staging_Dir : constant String := Project_Tools.Files.Join (Destination, "cldr-json.incoming");

begin
   if Has_Argument ("--help") then
      Put_Line
        ("usage: download_cldr_upstream [--force] [--dest=DIR] [--keep-archive]"
         & ASCII.LF
         & "Downloads the cldr-json release named by " & Manifest_Path
         & ASCII.LF
         & "and unpacks it into DIR/cldr-json (default DIR: " & Default_Dest & ")."
         & ASCII.LF
         & "Does nothing when DIR/cldr-json is already populated, unless --force.");
      return;
   end if;

   if not Project_Tools.Files.File_Exists (Manifest_Path) then
      Fail ("missing " & Manifest_Path & " -- run this from the cldr/ directory");
      return;
   end if;

   if Project_Tools.Files.Directory_Exists (Project_Tools.Files.Join (Install_Dir, "cldr-core"))
     and then not Has_Argument ("--force")
   then
      Put_Line (Install_Dir & " is already populated; nothing to download (use --force to refetch)");
      return;
   end if;

   declare
      Version : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "cldr_version");
      Family  : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_family");
   begin
      if Version = "" then
         Fail (Manifest_Path & " does not declare cldr_version");
         return;
      end if;

      if Family /= "" and then Family /= "cldr-json" then
         Fail ("source_family is " & Family & ", but this tool only fetches cldr-json releases");
         return;
      end if;

      declare
         Tag          : constant String := Release_Tag (Version);
         URL          : constant String := Archive_URL (Tag);
         Archive_Path : constant String :=
           Project_Tools.Files.Join (Destination, "cldr-" & Tag & "-json-full.zip");
         Result       : Http_Client.Clients.Download_Result;
         Options      : Http_Client.Clients.Download_Options := Http_Client.Clients.Default_Download_Options;
         Status       : Http_Client.Errors.Result_Status;
         Unpacked     : Zlib.Status_Code;
         Unpack_Error : Ada.Strings.Unbounded.Unbounded_String;
      begin
         Options.File_Mode := Http_Client.Clients.Replace_Atomically;
         Options.Create_Parent_Dirs := True;
         Options.Max_Download_Size := Max_Archive_Bytes;

         Put_Line ("CLDR " & Version & " -> release tag " & Tag);
         Put_Line ("fetching " & URL);

         Status :=
           Http_Client.Clients.Download_To_File
             (URL     => URL,
              Path    => Archive_Path,
              Result  => Result,
              Options => Options);

         if Status /= Http_Client.Errors.Ok then
            Fail ("download failed: " & Status'Image & " (HTTP" & Natural'Image (Result.HTTP_Status_Code) & ")");
            return;
         end if;

         Put_Line ("downloaded" & Natural'Image (Result.Bytes_Written) & " bytes to " & Archive_Path);

         --  Unpack beside the target and swap it in, so an interrupted or
         --  malformed archive never leaves a half-populated upstream/cldr-json
         --  that the cascade would then mistake for a complete checkout.

         if Project_Tools.Files.Directory_Exists (Staging_Dir) then
            Project_Tools.Files.Delete_Tree (Staging_Dir);
         end if;
         Ada.Directories.Create_Path (Staging_Dir);

         Put_Line ("unpacking into " & Staging_Dir);
         Unpack_Into (Archive_Path, Staging_Dir, Unpacked, Unpack_Error);

         if Ada.Strings.Unbounded.Length (Unpack_Error) > 0 then
            Fail
              ("unpacking " & Archive_Path & " raised "
               & Ada.Strings.Unbounded.To_String (Unpack_Error)
               & " (if this is a STORAGE_ERROR, raise Unpack_Stack_Bytes)");
            return;
         end if;

         if Unpacked /= Zlib.Ok then
            Fail ("unpacking " & Archive_Path & " failed: " & Unpacked'Image);
            return;
         end if;

         declare
            Root : constant String := Extracted_Root (Staging_Dir);
         begin
            if Root = "" then
               Fail ("unpacked archive has no cldr-core package; unexpected archive layout");
               return;
            end if;

            if Project_Tools.Files.Directory_Exists (Install_Dir) then
               Project_Tools.Files.Delete_Tree (Install_Dir);
            end if;
            Ada.Directories.Rename (Old_Name => Root, New_Name => Install_Dir);
         end;

         if Project_Tools.Files.Directory_Exists (Staging_Dir) then
            Project_Tools.Files.Delete_Tree (Staging_Dir);
         end if;

         if not Has_Argument ("--keep-archive") then
            Project_Tools.Files.Delete_File_If_Present (Archive_Path);
         end if;

         Put_Line ("installed " & Install_Dir);
      end;
   end;
end Download_CLDR_Upstream;
