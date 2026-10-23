with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body I18N.Data_Store is

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   CR : constant Character := Character'Val (16#0D#);

   type String_Access is access String;
   type Dir_List is array (Positive range <>) of Unbounded_String;

   type Section_Record is record
      Name : Unbounded_String;
      Lo   : Natural := 1;   --  first byte of the first record
      Hi   : Natural := 0;   --  last byte of the last record (Hi < Lo => empty)
   end record;
   --  A file's sections, sized to the file (formats holds ~180: one per field
   --  and per numbering system). Built once and shared by access: lookups
   --  never copy the table, which held Unbounded_Strings.
   type Section_Array is array (Positive range <>) of Section_Record;
   type Section_Access is access constant Section_Array;
   No_Sections : constant Section_Access := new Section_Array'(1 .. 0 => <>);

   Max_Files : constant := 1024;   --  transforms chain through many shards
   type File_Record is record
      Name     : Unbounded_String;
      Content  : String_Access;      --  null when the file was not found
      Sections : Section_Access := No_Sections;
      Known    : Boolean := False;   --  load has been attempted
   end record;

   type File_Array is array (1 .. Max_Files) of File_Record;

   type File_State is (Unknown, Missing, Present);

   --  ------------------------------------------------------------------
   --  Discovery
   --  ------------------------------------------------------------------

   Configured_Dir : Unbounded_String := Null_Unbounded_String;

   procedure Configure_Data_Dir (Path : String) is
   begin
      Configured_Dir := To_Unbounded_String (Path);
   end Configure_Data_Dir;

   function Executable_Dir return String is
      Name : constant String := Ada.Command_Line.Command_Name;
      Cut  : Natural := 0;
   begin
      for I in reverse Name'Range loop
         if Name (I) = '/' or else Name (I) = '\' then
            Cut := I;
            exit;
         end if;
      end loop;
      return (if Cut = 0 then "" else Name (Name'First .. Cut - 1));
   end Executable_Dir;

   --  First existing "<dir>/<File>.i18ndata" across the search order.
   function Resolve (File : String) return String is
      Leaf : constant String := File & ".i18ndata";

      function Try (Dir : String) return String is
      begin
         if Dir = "" then
            return "";
         end if;
         declare
            Path : constant String := Dir & "/" & Leaf;
         begin
            return (if Ada.Directories.Exists (Path) then Path else "");
         end;
      end Try;

      Exe : constant String := Executable_Dir;
   begin
      declare
         Hit : constant String := Try (To_String (Configured_Dir));
      begin
         if Hit /= "" then
            return Hit;
         end if;
      end;

      if Ada.Environment_Variables.Exists ("I18N_DATA_DIR") then
         declare
            Hit : constant String :=
              Try (Ada.Environment_Variables.Value ("I18N_DATA_DIR"));
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
      end if;

      for Dir of Dir_List'
        (To_Unbounded_String (Exe & "/share/i18n"),
         To_Unbounded_String (Exe & "/../share/i18n"),
         To_Unbounded_String ("share/i18n"),
         --  Sibling-crate layout: a consumer built next to i18n
         --  (root/<consumer>/... alongside root/i18n) finds the data with no
         --  wiring. Dev/workspace convenience; installs use the exe-relative
         --  copy or I18N_DATA_DIR above.
         To_Unbounded_String ("../i18n/share/i18n"),
         To_Unbounded_String ("../../i18n/share/i18n"),
         To_Unbounded_String ("../../../i18n/share/i18n"),
         To_Unbounded_String (Exe & "/../../i18n/share/i18n"),
         To_Unbounded_String (Exe & "/../../../i18n/share/i18n"))
      loop
         declare
            Hit : constant String := Try (To_String (Dir));
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
      end loop;

      return "";
   end Resolve;

   --  ------------------------------------------------------------------
   --  Loading and section indexing
   --  ------------------------------------------------------------------

   function Read_File (Path : String) return String_Access is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      Len : Natural;
   begin
      Open (F, In_File, Path);
      Len := Natural (Ada.Directories.Size (Path));
      declare
         Result : constant String_Access := new String (1 .. Len);
         Buf    : Stream_Element_Array (1 .. 65536);   --  small, on the stack
         Last   : Stream_Element_Offset;
         Pos    : Natural := 0;
      begin
         --  Read the file into the heap-allocated Result in chunks -- the data
         --  file is tens of MB, far too large for a stack buffer.
         loop
            Read (F, Buf, Last);
            for I in 1 .. Natural (Last) loop
               declare
                  Ch : constant Character :=
                    Character'Val (Buf (Stream_Element_Offset (I)));
               begin
                  --  Collapse CRLF to LF. The data files are written with
                  --  Ada.Text_IO, which emits CRLF on Windows; the byte-exact
                  --  section parser and bisection would otherwise keep the CR in
                  --  every value (and after each key), so every lookup misses and
                  --  formatting silently falls back to defaults. Standalone CR
                  --  bytes are left untouched.
                  if Ch = LF and then Pos >= 1 and then Result (Pos) = CR then
                     Result (Pos) := LF;
                  else
                     Pos := Pos + 1;
                     Result (Pos) := Ch;
                  end if;
               end;
            end loop;
            exit when Last < Buf'Last;   --  short read => end of file
         end loop;
         Close (F);
         if Pos = Len then
            return Result;
         else
            return new String'(Result (1 .. Pos));
         end if;
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
         return null;
   end Read_File;

   --  Split the loaded content into sections at the '@' header lines.
   function Index_Sections (Content : String) return Section_Access is

      --  A section header is "@name|count" -- it has no TAB. A record whose
      --  key happens to start with '@' (the emoji "@") always has a TAB, so
      --  the header sentinel does not collide with such keys.
      function Is_Header (First, Stop : Natural) return Boolean is
        (Content (First) = '@' and then (for all J in First .. Stop - 1 => Content (J) /= HT));

      --  Visit each header line: Line_Start .. Line_Stop - 1, Line_Stop at its LF.
      generic
         with procedure Visit (Line_Start, Line_Stop : Natural);
      procedure For_Each_Header;

      procedure For_Each_Header is
         I         : Natural := Content'First;
         Line_Stop : Natural;
      begin
         while I <= Content'Last loop
            Line_Stop := I;
            while Line_Stop <= Content'Last and then Content (Line_Stop) /= LF loop
               Line_Stop := Line_Stop + 1;
            end loop;
            if Is_Header (I, Line_Stop) then
               Visit (I, Line_Stop);
            end if;
            exit when Line_Stop > Content'Last;
            I := Line_Stop + 1;
         end loop;
      end For_Each_Header;

      Total : Natural := 0;

      procedure Count_One (Line_Start, Line_Stop : Natural) is
         pragma Unreferenced (Line_Start, Line_Stop);
      begin
         Total := Total + 1;
      end Count_One;

      procedure Count_All is new For_Each_Header (Count_One);
   begin
      Count_All;
      declare
         Sections : Section_Array (1 .. Total);
         Count    : Natural := 0;

         procedure Add (Line_Start, Line_Stop : Natural) is
            Bar : Natural := Line_Start + 1;
         begin
            --  Close the previous section at the byte before this header line.
            if Count > 0 then
               Sections (Count).Hi := Line_Start - 2;   --  drop the preceding LF too
            end if;
            Count := Count + 1;
            while Bar < Line_Stop and then Content (Bar) /= '|' loop
               Bar := Bar + 1;
            end loop;
            Sections (Count).Name := To_Unbounded_String (Content (Line_Start + 1 .. Bar - 1));
            Sections (Count).Lo := Line_Stop + 1;
            Sections (Count).Hi := 0;   --  empty until closed
         end Add;

         procedure Add_All is new For_Each_Header (Add);
      begin
         Add_All;
         --  Close the final section at end of content.
         if Count > 0 and then Sections (Count).Hi = 0 then
            Sections (Count).Hi := Content'Last;
         end if;
         return new Section_Array'(Sections);
      end;
   end Index_Sections;

   --  ------------------------------------------------------------------
   --  In-place bisection over a section's sorted "key<TAB>value" records
   --  ------------------------------------------------------------------

   function Find_In_Section
     (Content : String;
      Lo, Hi  : Natural;
      Key     : String)
      return String
   is
      L : Natural := Lo;
      R : Natural := Hi;
   begin
      if Hi < Lo then
         return "";
      end if;

      while L <= R loop
         declare
            Mid        : constant Natural := L + (R - L) / 2;
            Line_Start : Natural := Mid;
            Line_End   : Natural := Mid;
            Tab        : Natural;
         begin
            --  Snap back to the start of Mid's line.
            while Line_Start > Lo and then Content (Line_Start - 1) /= LF loop
               Line_Start := Line_Start - 1;
            end loop;
            --  Forward to the line's LF (or one past Hi).
            while Line_End <= Hi and then Content (Line_End) /= LF loop
               Line_End := Line_End + 1;
            end loop;

            Tab := Line_Start;
            while Tab < Line_End and then Content (Tab) /= HT loop
               Tab := Tab + 1;
            end loop;

            declare
               Rec_Key : constant String := Content (Line_Start .. Tab - 1);
            begin
               if Rec_Key = Key then
                  return (if Tab < Line_End
                          then Content (Tab + 1 .. Line_End - 1)
                          else "");
               elsif Rec_Key < Key then
                  L := Line_End + 1;
               elsif Line_Start <= Lo then
                  exit;
               else
                  R := Line_Start - 1;
               end if;
            end;
         end;
      end loop;

      return "";
   end Find_In_Section;

   --  ------------------------------------------------------------------
   --  Process-wide cache (thread-safe, no blocking I/O inside the lock)
   --  ------------------------------------------------------------------

   protected Registry is
      procedure Peek
        (Name     : String;
         Content  : out String_Access;
         Sections : out Section_Access;
         State    : out File_State);
      procedure Install
        (Name     : String;
         Content  : String_Access;
         Sections : Section_Access);
   private
      Files : File_Array;
      Used  : Natural := 0;
   end Registry;

   protected body Registry is
      procedure Peek
        (Name     : String;
         Content  : out String_Access;
         Sections : out Section_Access;
         State    : out File_State)
      is
      begin
         Content  := null;
         Sections := No_Sections;
         State    := Unknown;
         for I in 1 .. Used loop
            if To_String (Files (I).Name) = Name then
               Content  := Files (I).Content;
               Sections := Files (I).Sections;
               State    := (if Files (I).Content = null then Missing else Present);
               return;
            end if;
         end loop;
      end Peek;

      procedure Install
        (Name     : String;
         Content  : String_Access;
         Sections : Section_Access)
      is
      begin
         for I in 1 .. Used loop
            if To_String (Files (I).Name) = Name then
               return;   --  another task won the race; keep the first
            end if;
         end loop;
         if Used < Max_Files then
            Used := Used + 1;
            Files (Used) :=
              (Name     => To_Unbounded_String (Name),
               Content  => Content,
               Sections => Sections,
               Known    => True);
         end if;
      end Install;
   end Registry;

   --  Return the cached (loading if needed) content + section table.
   procedure Obtain
     (File     : String;
      Content  : out String_Access;
      Sections : out Section_Access)
   is
      State : File_State;
   begin
      Registry.Peek (File, Content, Sections, State);
      if State /= Unknown then
         return;
      end if;

      --  Load outside the lock (file I/O must not run in a protected action).
      declare
         Path : constant String := Resolve (File);
      begin
         Content := (if Path = "" then null else Read_File (Path));
         Sections := (if Content = null then No_Sections else Index_Sections (Content.all));
         Registry.Install (File, Content, Sections);
      end;

      --  Re-read the winning entry (in case another task installed first). If
      --  the registry is full and could not cache this file, keep the content we
      --  just loaded (read-through) rather than losing it.
      declare
         PC : String_Access;
         PS : Section_Access;
         PState : File_State;
      begin
         Registry.Peek (File, PC, PS, PState);
         if PState /= Unknown then
            Content := PC;
            Sections := PS;
         end if;
      end;
   end Obtain;

   --  ------------------------------------------------------------------
   --  Public API
   --  ------------------------------------------------------------------

   function Lookup
     (File    : String;
      Section : String;
      Key     : String)
      return String
   is
      Content  : String_Access;
      Sections : Section_Access;
   begin
      Obtain (File, Content, Sections);
      if Content = null then
         return "";
      end if;
      for S of Sections.all loop
         if To_String (S.Name) = Section then
            return Find_In_Section (Content.all, S.Lo, S.Hi, Key);
         end if;
      end loop;
      return "";
   end Lookup;

   function Available (File : String) return Boolean is
      Content  : String_Access;
      Sections : Section_Access;
   begin
      Obtain (File, Content, Sections);
      return Content /= null;
   end Available;

end I18N.Data_Store;
