with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Streams;
with Ada.Strings.Hash;
with Http_Client.Clients;
with Http_Client.Errors;
with Zlib;
with Tarlib.Readers;
with Tarlib.Inputs;
with Tarlib.Entries;
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
   Work_Dir    : constant String := Project_Tools.Files.Temp_Dir & "/i18n_tzdb_download";
   Tgz_Path    : constant String := Work_Dir & "/tzdata.tar.gz";
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

   procedure Write_String (Path : String; Content : String) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      Create (F, Out_File, Path);
      String'Write (Stream (F), Content);
      Close (F);
   end Write_String;

   function Trim (S : String) return String is
      use Ada.Strings, Ada.Strings.Fixed;
   begin
      return Trim (S, Both);
   end Trim;

   ---------------------------------------------------------------------------
   --  In-memory tar extraction (Tarlib.Readers only, so tarlib-files' POSIX
   --  filesystem code -- chown/symlink/mknod/... -- is never linked; that unit
   --  does not build on Windows). Regular-file entries are collected by base
   --  name into a content map the pipeline reads from.
   ---------------------------------------------------------------------------
   package Content_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String, Element_Type => Unbounded_String,
      Hash => Ada.Strings.Hash, Equivalent_Keys => "=");

   Extracted : Content_Maps.Map;

   type SEA_Access is access Ada.Streams.Stream_Element_Array;

   type Memory_Source is limited new Tarlib.Inputs.Input_Source with record
      Data : SEA_Access;
      Pos  : Ada.Streams.Stream_Element_Offset := 1;
   end record;

   overriding procedure Read
     (Source : in out Memory_Source;
      Data   : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset;
      Result : out Tarlib.Errors.Status)
   is
      use type Ada.Streams.Stream_Element_Offset;
      Available : constant Ada.Streams.Stream_Element_Offset :=
        Source.Data'Last - Source.Pos + 1;
      Take      : constant Ada.Streams.Stream_Element_Offset :=
        Ada.Streams.Stream_Element_Offset'Min (Data'Length, Available);
   begin
      Result := Tarlib.Errors.OK;
      if Take <= 0 then
         Last := Data'First - 1;
         return;
      end if;
      Data (Data'First .. Data'First + Take - 1) :=
        Source.Data (Source.Pos .. Source.Pos + Take - 1);
      Source.Pos := Source.Pos + Take;
      Last := Data'First + Take - 1;
   end Read;

   function Base_Name (Path : String) return String is
      Cut : Natural := Path'First - 1;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Cut := I;
         end if;
      end loop;
      return Path (Cut + 1 .. Path'Last);
   end Base_Name;

   procedure Extract_Tar (Tar : Zlib.Byte_Array) is
      use type Ada.Streams.Stream_Element_Offset;
      use type Tarlib.Entries.Entry_Kind;
      Bytes  : constant SEA_Access :=
        new Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Tar'Length));
      Source : aliased Memory_Source;
      Reader : Tarlib.Readers.Reader;
      Info   : Tarlib.Readers.Entry_Info;
      Has    : Boolean;
      R      : Tarlib.Errors.Status;
   begin
      for I in Tar'Range loop
         Bytes (Ada.Streams.Stream_Element_Offset (I - Tar'First + 1)) :=
           Ada.Streams.Stream_Element (Tar (I));
      end loop;
      Source.Data := Bytes;

      Tarlib.Readers.Initialize (Reader, Source, R);
      if not Tarlib.Errors.Is_Success (R) then
         Fail ("cannot read tar: " & R'Image);
      end if;

      loop
         Tarlib.Readers.Next_Entry (Reader, Info, Has, R);
         exit when not Has;
         if not Tarlib.Errors.Is_Success (R) then
            Fail ("tar read failed: " & R'Image);
         end if;
         if Tarlib.Readers.Kind (Info) = Tarlib.Entries.Regular_File then
            declare
               Content : Unbounded_String;
               Buf     : Ada.Streams.Stream_Element_Array (1 .. 65536);
               RLast   : Ada.Streams.Stream_Element_Offset;
            begin
               loop
                  Tarlib.Readers.Read (Reader, Buf, RLast, R);
                  exit when RLast < Buf'First;
                  for K in Buf'First .. RLast loop
                     Append (Content, Character'Val (Natural (Buf (K))));
                  end loop;
               end loop;
               Extracted.Include (Base_Name (Tarlib.Readers.Path (Info)), Content);
            end;
         end if;
      end loop;
   end Extract_Tar;

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
      --  Retry: CI runners hit transient connection failures against IANA.
      for Attempt in 1 .. 3 loop
         Status := HC.Download_To_File (URL, Tgz_Path, Result, Options, Config);
         exit when Status = Http_Client.Errors.Ok;
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "tzdb: download attempt" & Attempt'Image & " failed: " & Status'Image
            & " (HTTP" & Result.HTTP_Status_Code'Image & ")");
         if Attempt < 3 then
            delay 10.0;
         end if;
      end loop;
      if Status /= Http_Client.Errors.Ok then
         Fail ("download failed after retries: " & Status'Image
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
      --  3. Extract the tar in memory (regular files by base name).
      Extract_Tar (Tar);
   end;

   --  4. Run ziguard (rearguard) then zishrink through awklib.
   declare
      function Src (Name : String) return String is
        (if Extracted.Contains (Name) then To_String (Extracted.Element (Name)) else "");

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
