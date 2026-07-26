with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Http_Client.Clients;
with Http_Client.Errors;
with Zlib;
with Tarlib.Readers;
with Tarlib.Files;
with Tarlib.Errors;
with Awklib.Interpreter;
with Project_Tools.Files;

--  Fetch the pinned IANA tzdb release and produce the rearguard tzdb fixtures
--  under cldr/upstream/tzdb/ -- tzdata.zi (built by running the tz project's own
--  ziguard/zishrink scripts through awklib, no external awk), plus the vendored
--  zone tables and leapseconds. Run from the cldr/ directory.
procedure Download_TZDB is

   use type Http_Client.Errors.Result_Status;
   use type Zlib.Status_Code;
   use type Awklib.Interpreter.Run_Status;

   package HC renames Http_Client.Clients;

   TZ_Version  : constant String := "2026a";
   URL         : constant String :=
     "https://data.iana.org/time-zones/releases/tzdata" & TZ_Version & ".tar.gz";
   Work_Dir    : constant String := "/tmp/i18n_tzdb_download";
   Tgz_Path    : constant String := Work_Dir & "/tzdata.tar.gz";
   Tar_Path    : constant String := Work_Dir & "/tzdata.tar";
   Extract_Dir : constant String := Work_Dir & "/tree";
   Out_Dir     : constant String := "upstream/tzdb";

   --  TDATA, in the order the tz Makefile concatenates it.
   TDATA : constant array (Positive range <>) of access constant String :=
     (new String'("africa"), new String'("antarctica"), new String'("asia"),
      new String'("australasia"), new String'("europe"), new String'("northamerica"),
      new String'("southamerica"), new String'("etcetera"), new String'("factory"),
      new String'("backward"));

   Failed : exception;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "download_tzdb: " & Message);
      raise Failed;
   end Fail;

   ---------------------------------------------------------------------------
   --  Byte I/O
   ---------------------------------------------------------------------------
   function Read_Bytes (Path : String) return Zlib.Byte_Array is
      use Ada.Streams.Stream_IO;
      F    : File_Type;
      Size : Ada.Streams.Stream_Element_Count;
   begin
      Open (F, In_File, Path);
      Size := Ada.Streams.Stream_Element_Count (Ada.Streams.Stream_IO.Size (F));
      declare
         SEA  : Ada.Streams.Stream_Element_Array (1 .. Size);
         Last : Ada.Streams.Stream_Element_Offset;
         Out_B : Zlib.Byte_Array (0 .. Natural (Size) - 1);
      begin
         Read (F, SEA, Last);
         Close (F);
         for I in 0 .. Natural (Last) - 1 loop
            Out_B (I) := Zlib.Byte (SEA (Ada.Streams.Stream_Element_Offset (I + 1)));
         end loop;
         return Out_B (0 .. Natural (Last) - 1);
      end;
   end Read_Bytes;

   procedure Write_Bytes (Path : String; Data : Zlib.Byte_Array) is
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      SEA : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
   begin
      for I in Data'Range loop
         SEA (Ada.Streams.Stream_Element_Offset (I - Data'First + 1)) :=
           Ada.Streams.Stream_Element (Data (I));
      end loop;
      Create (F, Out_File, Path);
      Write (F, SEA);
      Close (F);
   end Write_Bytes;

   procedure Write_String (Path : String; Content : String) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      Create (F, Out_File, Path);
      String'Write (Stream (F), Content);
      Close (F);
   end Write_String;

   function Read_String (Path : String) return String is
     (Project_Tools.Files.Read_Raw_File (Path));

   function Trim (S : String) return String is
      use Ada.Strings, Ada.Strings.Fixed;
   begin
      return Trim (S, Both);
   end Trim;

   ---------------------------------------------------------------------------
   --  awklib driver
   ---------------------------------------------------------------------------
   package AV renames Awklib.Interpreter.Assignment_Vectors;

   function Run_Awk
     (Program     : String;
      Input       : String;
      Vars        : Awklib.Interpreter.Assignment_Vectors.Vector;
      Label       : String;
      Files       : Awklib.Interpreter.Assignment_Vectors.Vector := AV.Empty_Vector;
      Input_Files : Awklib.Interpreter.Assignment_Vectors.Vector := AV.Empty_Vector)
      return String
   is
      Output    : Unbounded_String;
      Exit_Code : Integer;
      Status    : Awklib.Interpreter.Run_Status;
      Message   : Unbounded_String;
      Empty     : Awklib.Interpreter.Assignment_Vectors.Vector;
   begin
      Awklib.Interpreter.Run
        (Program_Source => Program,
         Input          => Input,
         Assignments    => Vars,
         Environment    => Empty,
         Filename       => "tzdata",
         Output         => Output,
         Exit_Code      => Exit_Code,
         Status         => Status,
         Message        => Message,
         Files          => Files,
         Input_Files    => Input_Files);
      if Status /= Awklib.Interpreter.Run_Ok then
         Fail (Label & ": " & To_String (Message));
      end if;
      return To_String (Output);
   end Run_Awk;

   function Assign (Name, Value : String)
     return Awklib.Interpreter.Var_Assignment
   is
     ((Name => To_Unbounded_String (Name), Value => To_Unbounded_String (Value)));

begin
   Ada.Text_IO.Put_Line ("tzdb: fetching " & URL);
   Ada.Directories.Create_Path (Work_Dir);

   --  1. Download the raw .tar.gz (no HTTP-layer decompression).
   declare
      Result  : HC.Download_Result;
      Options : HC.Download_Options := HC.Default_Download_Options;
      Config  : HC.Client_Configuration := HC.Default_Client_Configuration;
      Status  : Http_Client.Errors.Result_Status;
   begin
      Config.Enable_Decompression := False;
      Options.Create_Parent_Dirs := True;
      Options.File_Mode := HC.Replace_Atomically;
      Status := HC.Download_To_File (URL, Tgz_Path, Result, Options, Config);
      if Status /= Http_Client.Errors.Ok then
         Fail ("download failed: " & Status'Image
               & " (HTTP" & Result.HTTP_Status_Code'Image & ")");
      end if;
      Ada.Text_IO.Put_Line ("tzdb: downloaded" & Natural'Image (Result.Bytes_Written) & " bytes");
   end;

   --  2. Gunzip to a plain .tar.
   declare
      Gz     : constant Zlib.Byte_Array := Read_Bytes (Tgz_Path);
      Status : Zlib.Status_Code;
      Tar    : constant Zlib.Byte_Array := Zlib.Inflate_Auto (Gz, Status);
   begin
      if Status /= Zlib.Ok then
         Fail ("gunzip failed: " & Status'Image);
      end if;
      Write_Bytes (Tar_Path, Tar);
   end;

   --  3. Extract the tar into a working tree.
   declare
      Source : aliased Tarlib.Files.File_Input_Source;
      Reader : Tarlib.Readers.Reader;
      R      : Tarlib.Errors.Status;
   begin
      if Project_Tools.Files.Directory_Exists (Extract_Dir) then
         Project_Tools.Files.Delete_Tree (Extract_Dir);
      end if;
      Ada.Directories.Create_Path (Extract_Dir);
      Tarlib.Files.Open_Read (Source, Tar_Path, R);
      if not Tarlib.Errors.Is_Success (R) then
         Fail ("cannot open tar: " & R'Image);
      end if;
      Tarlib.Readers.Initialize (Reader, Source, R);
      if not Tarlib.Errors.Is_Success (R) then
         Fail ("cannot read tar: " & R'Image);
      end if;
      Tarlib.Files.Extract_All (Reader, Extract_Dir, R);
      if not Tarlib.Errors.Is_Success (R) then
         Fail ("tar extraction failed: " & R'Image);
      end if;
      Tarlib.Files.Close (Source, R);
   end;

   --  4. Run ziguard (rearguard) then zishrink through awklib.
   declare
      function Src (Name : String) return String is
        (Read_String (Extract_Dir & "/" & Name));

      Version_Str  : constant String := Trim (Src ("version"));

      --  Match the tz Makefile's PACKRATDATA=backzone PACKRATLIST=zone.tab build
      --  (the fixtures i18n consumes): TDATA then backzone as ordered input
      --  files (ziguard uses FILENAME to find backzone rows), zone.tab supplied
      --  for ziguard's `getline <zone.tab`.
      Zig_Vars    : Awklib.Interpreter.Assignment_Vectors.Vector;
      Shr_Vars    : Awklib.Interpreter.Assignment_Vectors.Vector;
      Input_Files : Awklib.Interpreter.Assignment_Vectors.Vector;
      Getline_F   : Awklib.Interpreter.Assignment_Vectors.Vector;
   begin
      for F of TDATA loop
         Input_Files.Append (Assign (F.all, Src (F.all)));
      end loop;
      Input_Files.Append (Assign ("backzone", Src ("backzone")));
      Getline_F.Append (Assign ("zone.tab", Src ("zone.tab")));

      Zig_Vars.Append (Assign ("DATAFORM", "rearguard"));
      Zig_Vars.Append (Assign ("PACKRATDATA", "backzone"));
      Zig_Vars.Append (Assign ("PACKRATLIST", "zone.tab"));

      Ada.Text_IO.Put_Line ("tzdb: running ziguard (rearguard, +backzone)");
      declare
         Rearguard : constant String :=
           Run_Awk (Src ("ziguard.awk"), "", Zig_Vars, "ziguard",
                    Files => Getline_F, Input_Files => Input_Files);
      begin
         Shr_Vars.Append (Assign ("dataform", "rearguard"));
         Shr_Vars.Append (Assign ("version", Version_Str));
         Shr_Vars.Append (Assign ("redo", "posix_only"));
         Shr_Vars.Append (Assign ("deps", ""));

         Ada.Text_IO.Put_Line ("tzdb: running zishrink");
         declare
            Zi : constant String := Run_Awk (Src ("zishrink.awk"), Rearguard, Shr_Vars, "zishrink");
         begin
            --  5. Write the fixtures.
            Ada.Directories.Create_Path (Out_Dir);
            Write_String (Out_Dir & "/tzdata.zi", Zi);
            Write_String (Out_Dir & "/zone.tab", Src ("zone.tab"));
            Write_String (Out_Dir & "/zone1970.tab", Src ("zone1970.tab"));
            Write_String (Out_Dir & "/leapseconds", Src ("leapseconds"));
            Write_String
              (Out_Dir & "/source_manifest.txt",
               "# Deterministic source manifest for checked IANA tzdb fixtures." & ASCII.LF
               & "tzdb_version=" & Version_Str & ASCII.LF
               & "source_family=iana-tzdb" & ASCII.LF
               & "dataform=rearguard" & ASCII.LF
               & "source_file_count=4" & ASCII.LF
               & "source|tzdb|tzdb/tzdata.zi" & ASCII.LF
               & "source|tzdb|tzdb/zone1970.tab" & ASCII.LF
               & "source|tzdb|tzdb/zone.tab" & ASCII.LF
               & "source|tzdb|tzdb/leapseconds" & ASCII.LF);
            Ada.Text_IO.Put_Line
              ("tzdb: wrote " & Out_Dir & "/{tzdata.zi,zone.tab,zone1970.tab,leapseconds}"
               & " (tzdata.zi" & Zi'Length'Image & " bytes)");
         end;
      end;
   end;

exception
   when Failed =>
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Download_TZDB;
