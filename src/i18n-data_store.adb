with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body I18N.Data_Store is

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);

   type String_Access is access String;
   type Dir_List is array (Positive range <>) of Unbounded_String;

   Max_Sections : constant := 64;
   type Section_Record is record
      Name : Unbounded_String;
      Lo   : Natural := 1;   --  first byte of the first record
      Hi   : Natural := 0;   --  last byte of the last record (Hi < Lo => empty)
   end record;
   type Section_Array is array (1 .. Max_Sections) of Section_Record;

   Max_Files : constant := 16;
   type File_Record is record
      Name     : Unbounded_String;
      Content  : String_Access;      --  null when the file was not found
      Sections : Section_Array;
      Count    : Natural := 0;
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
         To_Unbounded_String ("share/i18n"))
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
               Pos := Pos + 1;
               Result (Pos) := Character'Val (Buf (Stream_Element_Offset (I)));
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
   procedure Index_Sections
     (Content  : String;
      Sections : out Section_Array;
      Count    : out Natural)
   is
      I         : Natural := Content'First;
      Line_Stop : Natural;
      Is_Header : Boolean;
   begin
      Count := 0;
      while I <= Content'Last loop
         --  Line runs [I .. Line_Stop - 1], with Line_Stop at the LF or past end.
         Line_Stop := I;
         while Line_Stop <= Content'Last and then Content (Line_Stop) /= LF loop
            Line_Stop := Line_Stop + 1;
         end loop;

         --  A section header is "@name|count" -- it has no TAB. A record whose
         --  key happens to start with '@' (the emoji "@") always has a TAB, so
         --  the header sentinel does not collide with such keys.
         Is_Header := Content (I) = '@';
         if Is_Header then
            for J in I .. Line_Stop - 1 loop
               if Content (J) = HT then
                  Is_Header := False;
                  exit;
               end if;
            end loop;
         end if;

         if Is_Header then
            --  Close the previous section at the byte before this header line.
            if Count > 0 then
               Sections (Count).Hi := I - 2;   --  drop the preceding LF too
            end if;
            if Count < Max_Sections then
               Count := Count + 1;
               declare
                  Bar : Natural := I + 1;
               begin
                  while Bar < Line_Stop and then Content (Bar) /= '|' loop
                     Bar := Bar + 1;
                  end loop;
                  Sections (Count).Name :=
                    To_Unbounded_String (Content (I + 1 .. Bar - 1));
                  Sections (Count).Lo := Line_Stop + 1;
                  Sections (Count).Hi := 0;   --  empty until closed
               end;
            end if;
         end if;

         exit when Line_Stop > Content'Last;
         I := Line_Stop + 1;
      end loop;

      --  Close the final section at end of content.
      if Count > 0 and then Sections (Count).Hi = 0 then
         Sections (Count).Hi := Content'Last;
      end if;
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
         Sections : out Section_Array;
         Count    : out Natural;
         State    : out File_State);
      procedure Install
        (Name     : String;
         Content  : String_Access;
         Sections : Section_Array;
         Count    : Natural);
   private
      Files : File_Array;
      Used  : Natural := 0;
   end Registry;

   protected body Registry is
      procedure Peek
        (Name     : String;
         Content  : out String_Access;
         Sections : out Section_Array;
         Count    : out Natural;
         State    : out File_State)
      is
      begin
         Content := null;
         Count   := 0;
         State   := Unknown;
         for I in 1 .. Used loop
            if To_String (Files (I).Name) = Name then
               Content  := Files (I).Content;
               Sections := Files (I).Sections;
               Count    := Files (I).Count;
               State    := (if Files (I).Content = null then Missing else Present);
               return;
            end if;
         end loop;
      end Peek;

      procedure Install
        (Name     : String;
         Content  : String_Access;
         Sections : Section_Array;
         Count    : Natural)
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
               Count    => Count,
               Known    => True);
         end if;
      end Install;
   end Registry;

   --  Return the cached (loading if needed) content + section table.
   procedure Obtain
     (File     : String;
      Content  : out String_Access;
      Sections : out Section_Array;
      Count    : out Natural)
   is
      State : File_State;
   begin
      Registry.Peek (File, Content, Sections, Count, State);
      if State /= Unknown then
         return;
      end if;

      --  Load outside the lock (file I/O must not run in a protected action).
      declare
         Path : constant String := Resolve (File);
      begin
         if Path = "" then
            Content := null;
            Count   := 0;
            Registry.Install (File, null, Sections, 0);
         else
            Content := Read_File (Path);
            if Content = null then
               Count := 0;
               Registry.Install (File, null, Sections, 0);
            else
               Index_Sections (Content.all, Sections, Count);
               Registry.Install (File, Content, Sections, Count);
            end if;
         end if;
      end;

      --  Re-read the winning entry (in case another task installed first).
      Registry.Peek (File, Content, Sections, Count, State);
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
      Sections : Section_Array;
      Count    : Natural;
   begin
      Obtain (File, Content, Sections, Count);
      if Content = null then
         return "";
      end if;
      for I in 1 .. Count loop
         if To_String (Sections (I).Name) = Section then
            return Find_In_Section
              (Content.all, Sections (I).Lo, Sections (I).Hi, Key);
         end if;
      end loop;
      return "";
   end Lookup;

   function Available (File : String) return Boolean is
      Content  : String_Access;
      Sections : Section_Array;
      Count    : Natural;
   begin
      Obtain (File, Content, Sections, Count);
      return Content /= null;
   end Available;

end I18N.Data_Store;
