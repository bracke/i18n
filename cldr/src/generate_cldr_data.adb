with Ada.Exceptions;
with Ada.Command_Line;
with Ada.Containers.Generic_Array_Sort;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Files;
with Hostkit.Fs;
with I18N.TZ_Rules;
with Project_Tools.Processes;

procedure Generate_CLDR_Data is
   package US renames Ada.Strings.Unbounded;

   Source_Path : constant String := "data/cldr_subset.txt";
   TZDB_Path   : constant String := "upstream/tzdb/tzdata.zi";
   Target_Path : constant String := "../src/i18n-cldr_data.adb";
   Generated_Path : constant String := Hostkit.Fs.Temp_Directory & "/i18n_cldr_data.generated.adb";

   CLDR_Version : constant String := "48.2";

   --  Every locale's per-locale formatting data is written here as a
   --  Data_Store file so I18N.Locale_Data serves it on the fly; the compiled
   --  tables carry only structural data with no on-the-fly equivalent.
   Formats_Target : constant String := "../share/i18n/formats.i18ndata";
   --  The tz database for I18N.Time_Zone_Data: each zone's offsets until its
   --  final rule takes over, and the rule.
   TZDB_Target    : constant String := "../share/i18n/tzdb.i18ndata";
   Units_Dir      : constant String := "../share/i18n/units";
   Zones_Dir      : constant String := "../share/i18n/zones";
   Currency_Dir   : constant String := "../share/i18n/currency";

   Max_Rules : constant := 2_000_000;
   Max_TZDB_Zones : constant := 600;
   Max_TZDB_Links : constant := 1000;
   Max_TZDB_Transitions : constant := 120000;

   type Rule is record
      Kind : US.Unbounded_String;
      A    : US.Unbounded_String;
      B    : US.Unbounded_String;
      C    : US.Unbounded_String;
      D    : US.Unbounded_String;
      E    : US.Unbounded_String;
      F    : US.Unbounded_String;
   end record;

   type Rule_Array is array (1 .. Max_Rules) of Rule;
   type Rule_Array_Access is access Rule_Array;

   Rules      : constant Rule_Array_Access := new Rule_Array;
   Rule_Count : Natural := 0;

   --  Per-locale formatting rows captured here and written to formats.i18ndata
   --  for on-the-fly service. Section is the I18N.Locale_Data section name,
   --  Key the store-normalised locale.
   type Format_Entry is record
      Section : US.Unbounded_String;
      Key     : US.Unbounded_String;
      Value   : US.Unbounded_String;
   end record;
   --  Matches I18N.Data_Store.Key_Separator: joins locale and sub-key in a
   --  composite record key (e.g. "de" & Sep & "1" for January).
   Store_Sep : constant Character := Character'Val (16#1F#);
   Max_Format_Entries : constant := 500_000;
   type Format_Entry_Array is array (Positive range <>) of Format_Entry;
   type Format_Entry_Array_Access is access Format_Entry_Array;
   Format_Entries : constant Format_Entry_Array_Access :=
     new Format_Entry_Array (1 .. Max_Format_Entries);
   Format_Count   : Natural := 0;

   --  Unit display names are far larger than everything else combined, so they
   --  are sharded one file per locale (units/<locale>.i18ndata) rather than
   --  bloating formats.i18ndata. Here Section holds the shard locale and Key
   --  the "base:width:category" record key.
   Max_Unit_Entries : constant := 1_500_000;
   Unit_Entries : constant Format_Entry_Array_Access :=
     new Format_Entry_Array (1 .. Max_Unit_Entries);
   Unit_Count   : Natural := 0;

   --  Time-zone exemplar cities are the other large per-locale block, sharded
   --  the same way into zones/<locale>.i18ndata (Section holds the locale, Key
   --  the zone id).
   Max_Zone_Entries : constant := 1_000_000;
   Zone_Entries : constant Format_Entry_Array_Access :=
     new Format_Entry_Array (1 .. Max_Zone_Entries);
   Zone_Count   : Natural := 0;

   --  Currency display names, also per-locale and large, sharded into
   --  currency/<locale>.i18ndata (Key is "CODE:category").
   Max_Currency_Entries : constant := 1_000_000;
   Currency_Entries : constant Format_Entry_Array_Access :=
     new Format_Entry_Array (1 .. Max_Currency_Entries);
   Currency_Count   : Natural := 0;

   use type US.Unbounded_String;
   function Format_Less (L, R : Format_Entry) return Boolean is
     (US."<" (L.Section, R.Section)
      or else (L.Section = R.Section
               and then US."<" (L.Key, R.Key)));
   TZDB_Zone_Names : array (1 .. Max_TZDB_Zones) of US.Unbounded_String;
   TZDB_Zone_Initial_Offsets : array (1 .. Max_TZDB_Zones) of Integer;
   TZDB_Zone_Count : Natural := 0;
   TZDB_Link_Targets : array (1 .. Max_TZDB_Links) of US.Unbounded_String;
   TZDB_Link_Names   : array (1 .. Max_TZDB_Links) of US.Unbounded_String;
   TZDB_Link_Count   : Natural := 0;
   TZDB_Transition_Zones : array (1 .. Max_TZDB_Transitions) of Natural;
   TZDB_Transition_Keys : array (1 .. Max_TZDB_Transitions) of Long_Long_Integer;
   TZDB_Transition_Offsets : array (1 .. Max_TZDB_Transitions) of Integer;
   --  Whether daylight saving time is in effect from the transition on
   --  (zdump's isdst): the specific zone names follow it.
   TZDB_Transition_Daylight : array (1 .. Max_TZDB_Transitions) of Boolean;
   TZDB_Transition_Count : Natural := 0;
   --  Each zone's final rule (the POSIX TZ string zic ends its file with), and
   --  the key from which that rule answers instead of the transitions; 0 when
   --  the zone has no rule this can read and the transitions answer always.
   TZDB_Zone_Rules     : array (1 .. Max_TZDB_Zones) of US.Unbounded_String;
   TZDB_Zone_Rule_From : array (1 .. Max_TZDB_Zones) of Long_Long_Integer := [others => 0];
   --  The last transition each compiled file lists, as seconds since 1970;
   --  after it the file names no instant and the final rule alone governs.
   --  What zdump reports past it is only the C library's reading of that
   --  rule, and macOS's misreads a rule whose change falls at a negative hour
   --  (America/Nuuk's M3.5.0/-1), so there the rule is checked against itself.
   TZDB_Zone_Explicit_End : array (1 .. Max_TZDB_Zones) of Long_Long_Integer :=
     [others => Long_Long_Integer'Last];
   Errors     : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   function Trim (Value : String) return String is
      First : Natural := Value'First;
      Last  : Natural := Value'Last;
   begin
      while First <= Value'Last and then Value (First) = ' ' loop
         First := First + 1;
      end loop;

      while Last >= Value'First and then Value (Last) = ' ' loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      else
         return Value (First .. Last);
      end if;
   end Trim;

   function Starts_With (Value : String; Prefix : String) return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) =
          Prefix;
   end Starts_With;

   function Expr_Item
     (Items  : String;
      Number : Positive) return String
   is
      Start : Positive := Items'First;
      Count : Positive := 1;
   begin
      for Index in Items'Range loop
         if Items (Index) = '~' then
            if Count = Number then
               if Index = Start then
                  return "";
               else
                  return Items (Start .. Index - 1);
               end if;
            end if;

            Count := Count + 1;
            if Index < Items'Last then
               Start := Index + 1;
            else
               Start := Items'Last;
            end if;
         end if;
      end loop;

      if Count = Number then
         if Start > Items'Last then
            return "";
         else
            return Items (Start .. Items'Last);
         end if;
      end if;

      return "";
   end Expr_Item;

   function Expr_Item_Count (Items : String) return Natural is
      Count : Natural := 1;
   begin
      if Items'Length = 0 then
         return 0;
      end if;

      for C of Items loop
         if C = '~' then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Expr_Item_Count;

   procedure Add_Error (Message : String);

   function Is_Hex_Bytes (Value : String) return Boolean is
   begin
      if Value'Length = 0 or else Value'Length mod 2 /= 0 then
         return False;
      end if;

      for C of Value loop
         if C not in '0' .. '9'
           and then C not in 'A' .. 'F'
           and then C not in 'a' .. 'f'
         then
            return False;
         end if;
      end loop;

      return True;
   end Is_Hex_Bytes;

   function Hex_Digit (Value : Natural) return Character is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('A') + Value - 10);
      end if;
   end Hex_Digit;

   function Hex_Byte (Value : Natural) return String is
   begin
      return [1 => Hex_Digit (Value / 16), 2 => Hex_Digit (Value mod 16)];
   end Hex_Byte;

   procedure Append_UTF8_Hex
     (Output : in out US.Unbounded_String;
      Code   : Natural)
   is
   begin
      if Code <= 16#7F# then
         US.Append (Output, Hex_Byte (Code));
      elsif Code <= 16#7FF# then
         US.Append (Output, Hex_Byte (16#C0# + Code / 64));
         US.Append (Output, Hex_Byte (16#80# + Code mod 64));
      elsif Code <= 16#FFFF# then
         US.Append (Output, Hex_Byte (16#E0# + Code / 4096));
         US.Append (Output, Hex_Byte (16#80# + (Code / 64) mod 64));
         US.Append (Output, Hex_Byte (16#80# + Code mod 64));
      else
         US.Append (Output, Hex_Byte (16#F0# + Code / 262144));
         US.Append (Output, Hex_Byte (16#80# + (Code / 4096) mod 64));
         US.Append (Output, Hex_Byte (16#80# + (Code / 64) mod 64));
         US.Append (Output, Hex_Byte (16#80# + Code mod 64));
      end if;
   end Append_UTF8_Hex;

   function Hex_Value (Value : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Value loop
         Result := Result * 16;
         if C in '0' .. '9' then
            Result := Result + Character'Pos (C) - Character'Pos ('0');
         elsif C in 'A' .. 'F' then
            Result := Result + 10 + Character'Pos (C) - Character'Pos ('A');
         elsif C in 'a' .. 'f' then
            Result := Result + 10 + Character'Pos (C) - Character'Pos ('a');
         end if;
      end loop;

      return Result;
   end Hex_Value;

   --  Rows that arrive as four hex digits a code point.
   --  One Unicode code point as raw UTF-8 bytes.
   function Code_Point_UTF8 (Point : Natural) return String is
      Bytes : US.Unbounded_String;
   begin
      if Point <= 16#7F# then
         US.Append (Bytes, Character'Val (Point));
      elsif Point <= 16#7FF# then
         US.Append (Bytes, Character'Val (16#C0# + Point / 64));
         US.Append (Bytes, Character'Val (16#80# + Point mod 64));
      elsif Point <= 16#FFFF# then
         US.Append (Bytes, Character'Val (16#E0# + Point / 4096));
         US.Append (Bytes, Character'Val (16#80# + (Point / 64) mod 64));
         US.Append (Bytes, Character'Val (16#80# + Point mod 64));
      else
         US.Append (Bytes, Character'Val (16#F0# + Point / 262144));
         US.Append (Bytes, Character'Val (16#80# + (Point / 4096) mod 64));
         US.Append (Bytes, Character'Val (16#80# + (Point / 64) mod 64));
         US.Append (Bytes, Character'Val (16#80# + Point mod 64));
      end if;
      return S (Bytes);
   end Code_Point_UTF8;

   --  Decode a run of four-hex-digit BMP code points to raw UTF-8. (The packed
   --  name sets are BMP-only; astral names arrive through the U (16#...#)
   --  override rows instead.)
   function Hex_Points_To_UTF8 (Hex : String) return String is
      Bytes : US.Unbounded_String;
      Index : Natural := Hex'First;
   begin
      while Index + 3 <= Hex'Last loop
         US.Append (Bytes, Code_Point_UTF8 (Hex_Value (Hex (Index .. Index + 3))));
         Index := Index + 4;
      end loop;

      return S (Bytes);
   end Hex_Points_To_UTF8;

   function Ada_Expression_UTF8_Hex_Digits (Expr : String) return String is
      Output : US.Unbounded_String;
      Index  : Natural := Expr'First;
   begin
      while Index <= Expr'Last loop
         if Expr (Index) = '"' then
            Index := Index + 1;
            while Index <= Expr'Last loop
               if Expr (Index) = '"' then
                  if Index < Expr'Last and then Expr (Index + 1) = '"' then
                     US.Append (Output, Hex_Byte (Character'Pos ('"')));
                     Index := Index + 2;
                  else
                     Index := Index + 1;
                     exit;
                  end if;
               else
                  US.Append (Output, Hex_Byte (Character'Pos (Expr (Index))));
                  Index := Index + 1;
               end if;
            end loop;
         elsif Index + 5 <= Expr'Last
           and then Expr (Index .. Index + 5) = "U (16#"
         then
            declare
               Start : constant Natural := Index + 6;
               Stop  : Natural := Start;
            begin
               while Stop <= Expr'Last and then Expr (Stop) /= '#' loop
                  Stop := Stop + 1;
               end loop;

               if Stop <= Expr'Last then
                  Append_UTF8_Hex
                    (Output, Hex_Value (Expr (Start .. Stop - 1)));
                  Index := Stop + 2;
               else
                  Add_Error ("invalid generated CLDR text expression: " & Expr);
                  return "";
               end if;
            end;
         elsif Expr (Index) = ' '
           or else Expr (Index) = '&'
         then
            Index := Index + 1;
         else
            Add_Error ("unsupported generated CLDR text expression: " & Expr);
            return "";
         end if;
      end loop;

      return S (Output);
   end Ada_Expression_UTF8_Hex_Digits;

   --  The same, stopping at the bytes.
   function Ada_Expression_UTF8_Bytes (Expr : String) return String is
      Hex : constant String := Ada_Expression_UTF8_Hex_Digits (Expr);
      Bytes : String (1 .. Hex'Length / 2);
      Source : Natural;
   begin
      for Index in Bytes'Range loop
         Source := Hex'First + (Index - 1) * 2;
         Bytes (Index) :=
           Character'Val
             (Hex_Value (Hex (Source .. Source)) * 16
              + Hex_Value (Hex (Source + 1 .. Source + 1)));
      end loop;

      return Bytes;
   end Ada_Expression_UTF8_Bytes;

   procedure Add_Error (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Add_Error;

   procedure Add_Line_Error (Line_Number : Positive; Message : String) is
   begin
      Add_Error ("line" & Positive'Image (Line_Number) & ": " & Message);
   end Add_Line_Error;

   procedure Add_TZDB_Line_Error (Line_Number : Positive; Message : String) is
   begin
      Add_Error
        (TZDB_Path & ": line" & Positive'Image (Line_Number) & ": " & Message);
   end Add_TZDB_Line_Error;

   function Has_Argument (Value : String) return Boolean is
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (Index) = Value then
            return True;
         end if;
      end loop;

      return False;
   end Has_Argument;

   function Field
     (Line      : String;
      Number    : Positive;
      Separator : Character := '|') return String
   is
      Start : Positive := Line'First;
      Count : Positive := 1;
   begin
      for Index in Line'Range loop
         if Line (Index) = Separator then
            if Count = Number then
               if Index = Start then
                  return "";
               else
                  return Line (Start .. Index - 1);
               end if;
            end if;

            Count := Count + 1;
            if Index < Line'Last then
               Start := Index + 1;
            else
               Start := Line'Last;
            end if;
         end if;
      end loop;

      if Count = Number then
         if Start > Line'Last then
            return "";
         else
            return Line (Start .. Line'Last);
         end if;
      end if;

      return "";
   end Field;

   function Space_Field (Line : String; Number : Positive) return String is
   begin
      return Field (Line, Number, ' ');
   end Space_Field;

   function Contains (Value : String; Fragment : String) return Boolean is
   begin
      if Fragment'Length = 0 or else Value'Length < Fragment'Length then
         return False;
      end if;

      for Index in Value'First .. Value'Last - Fragment'Length + 1 loop
         if Value (Index .. Index + Fragment'Length - 1) = Fragment then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   function Tail_After (Value : String; Fragment : String) return String is
   begin
      if Fragment'Length = 0 or else Value'Length < Fragment'Length then
         return "";
      end if;

      for Index in Value'First .. Value'Last - Fragment'Length + 1 loop
         if Value (Index .. Index + Fragment'Length - 1) = Fragment then
            if Index + Fragment'Length <= Value'Last then
               return Value (Index + Fragment'Length .. Value'Last);
            else
               return "";
            end if;
         end if;
      end loop;

      return "";
   end Tail_After;

   function Valid_Zone_Name (Value : String) return Boolean is
   begin
      if Value'Length = 0
        or else Value (Value'First) = '/'
        or else Value (Value'Last) = '/'
        or else Contains (Value, "//")
      then
         return False;
      end if;

      for C of Value loop
         if not (C in 'A' .. 'Z'
                 or else C in 'a' .. 'z'
                 or else C in '0' .. '9'
                 or else C in '_' | '-' | '+' | '/')
         then
            return False;
         end if;
      end loop;

      return True;
   end Valid_Zone_Name;

   procedure Add_TZDB_Link
     (Target : String;
      Link   : String)
   is
   begin
      for Index in 1 .. TZDB_Link_Count loop
         if S (TZDB_Link_Names (Index)) = Link then
            if S (TZDB_Link_Targets (Index)) /= Target then
               Add_Error ("conflicting tzdb link target for " & Link);
            end if;
            return;
         end if;
      end loop;

      if TZDB_Link_Count = TZDB_Link_Names'Last then
         Add_Error ("too many tzdb links");
         return;
      end if;

      TZDB_Link_Count := TZDB_Link_Count + 1;
      TZDB_Link_Targets (TZDB_Link_Count) := US.To_Unbounded_String (Target);
      TZDB_Link_Names (TZDB_Link_Count) := US.To_Unbounded_String (Link);
   end Add_TZDB_Link;

   procedure Add_TZDB_Zone (Name : String) is
   begin
      for Index in 1 .. TZDB_Zone_Count loop
         if S (TZDB_Zone_Names (Index)) = Name then
            return;
         end if;
      end loop;

      if TZDB_Zone_Count = TZDB_Zone_Names'Last then
         Add_Error ("too many tzdb zones");
         return;
      end if;

      TZDB_Zone_Count := TZDB_Zone_Count + 1;
      TZDB_Zone_Names (TZDB_Zone_Count) := US.To_Unbounded_String (Name);
      TZDB_Zone_Initial_Offsets (TZDB_Zone_Count) := 0;
   end Add_TZDB_Zone;

   function TZDB_Zone_Index (Name : String) return Natural is
   begin
      for Index in 1 .. TZDB_Zone_Count loop
         if S (TZDB_Zone_Names (Index)) = Name then
            return Index;
         end if;
      end loop;

      return 0;
   end TZDB_Zone_Index;
   pragma Unreferenced (TZDB_Zone_Index);

   function Is_Decimal_Text (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;

      for C of Value loop
         if C not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Decimal_Text;

   function Decimal_Value (Value : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Value loop
         Result := Result * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;

      return Result;
   end Decimal_Value;

   --  Parse Text as an unsigned decimal, but never raise: a foreign zdump (BSD
   --  on macOS) can emit an overflowed year such as "-2147481748" (INT_MIN+1900)
   --  or otherwise malformed fields. Anything not made of 1 .. Max_Len digits
   --  yields Natural'Last, an out-of-range sentinel every caller's range guard
   --  rejects -- so the whole transition line is skipped instead of aborting.
   function Bounded_Decimal (Text : String; Max_Len : Positive) return Natural is
     (if Is_Decimal_Text (Text) and then Text'Length in 1 .. Max_Len
      then Decimal_Value (Text)
      else Natural'Last);

   function Signed_Decimal_Value (Value : String) return Integer is
      Result : Integer := 0;
      First  : Positive := Value'First;
      Sign   : Integer := 1;
   begin
      if Value'Length = 0 then
         return 0;
      end if;

      if Value (Value'First) = '-' then
         Sign := -1;
         First := Value'First + 1;
      elsif Value (Value'First) = '+' then
         First := Value'First + 1;
      end if;

      for Index in First .. Value'Last loop
         if Value (Index) not in '0' .. '9' then
            return 0;
         end if;
         Result := Result * 10
           + Character'Pos (Value (Index)) - Character'Pos ('0');
      end loop;

      return Sign * Result;
   end Signed_Decimal_Value;

   function Month_Number (Name : String) return Natural is
   begin
      if Name = "Jan" then
         return 1;
      elsif Name = "Feb" then
         return 2;
      elsif Name = "Mar" then
         return 3;
      elsif Name = "Apr" then
         return 4;
      elsif Name = "May" then
         return 5;
      elsif Name = "Jun" then
         return 6;
      elsif Name = "Jul" then
         return 7;
      elsif Name = "Aug" then
         return 8;
      elsif Name = "Sep" then
         return 9;
      elsif Name = "Oct" then
         return 10;
      elsif Name = "Nov" then
         return 11;
      elsif Name = "Dec" then
         return 12;
      else
         return 0;
      end if;
   end Month_Number;

   function TZDB_Key
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural)
      return Long_Long_Integer
   is
   begin
      return (((((Long_Long_Integer (Year) * 100
                 + Long_Long_Integer (Month)) * 100
                + Long_Long_Integer (Day)) * 100
               + Long_Long_Integer (Hour)) * 100
              + Long_Long_Integer (Minute)) * 100
             + Long_Long_Integer (Second));
   end TZDB_Key;

   function Token
     (Text   : String;
      Number : Positive)
      return String
   is
      Index : Natural := Text'First;
      Count : Positive := 1;
      First : Natural;
   begin
      while Index <= Text'Last loop
         while Index <= Text'Last and then Text (Index) = ' ' loop
            Index := Index + 1;
         end loop;

         exit when Index > Text'Last;
         First := Index;
         while Index <= Text'Last and then Text (Index) /= ' ' loop
            Index := Index + 1;
         end loop;

         if Count = Number then
            return Text (First .. Index - 1);
         end if;

         Count := Count + 1;
      end loop;

      return "";
   end Token;

   function Parse_TZDB_Offset_Seconds (Value : String) return Integer is
      First : Positive := Value'First;
      Sign  : Integer := 1;
      Hours : Natural := 0;
      Mins  : Natural := 0;
      Secs  : Natural := 0;
      Digit_Count : Natural;
      Body_Last : Natural := Value'Last;
   begin
      if Value'Length = 0 then
         return 0;
      end if;

      if Value (Value'First) = '-' then
         Sign := -1;
         First := Value'First + 1;
      elsif Value (Value'First) = '+' then
         First := Value'First + 1;
      end if;

      if First > Value'Last then
         return 0;
      end if;

      if Contains (Value (First .. Value'Last), ":") then
         declare
            H : constant String := Field (Value (First .. Value'Last), 1, ':');
            M : constant String := Field (Value (First .. Value'Last), 2, ':');
            S : constant String := Field (Value (First .. Value'Last), 3, ':');
         begin
            Hours := Decimal_Value (H);
            Mins := (if M = "" then 0 else Decimal_Value (M));
            Secs := (if S = "" then 0 else Decimal_Value (S));
         end;
      else
         while Body_Last >= First and then Value (Body_Last) not in '0' .. '9' loop
            Body_Last := Body_Last - 1;
         end loop;

         Digit_Count := Body_Last - First + 1;
         if Digit_Count <= 2 then
            Hours := Decimal_Value (Value (First .. Body_Last));
         elsif Digit_Count = 4 then
            Hours := Decimal_Value (Value (First .. First + 1));
            Mins := Decimal_Value (Value (First + 2 .. Body_Last));
         else
            Hours := Decimal_Value (Value (First .. First + 1));
            Mins := Decimal_Value (Value (First + 2 .. First + 3));
            Secs := Decimal_Value (Value (First + 4 .. Body_Last));
         end if;
      end if;

      return Sign * Integer (Hours * 3600 + Mins * 60 + Secs);
   exception
      when others =>
         return 0;
   end Parse_TZDB_Offset_Seconds;

   function Field_Count (Line : String) return Natural is
      Count : Natural := 1;
   begin
      if Line'Length = 0 then
         return 0;
      end if;

      for C of Line loop
         if C = '|' then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Field_Count;

   function Comma_Count (Value : String) return Natural is
      Count : Natural := 1;
   begin
      if Value'Length = 0 then
         return 0;
      end if;

      for C of Value loop
         if C = ',' then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Comma_Count;

   --  Every real locale's rows are captured into the data files so the runtime
   --  serves them on the fly. nu-* and empty are not locales; und/root are the
   --  base the fallback walk resolves to, so they ARE captured.
   function Capture_Locale (Value : String) return Boolean is
   begin
      return Value'Length > 0 and then not Starts_With (Value, "nu-");
   end Capture_Locale;

   --  Normalise a CLDR locale id to the store form I18N.Locale_Data queries:
   --  ASCII-lowercase with '_' folded to '-'.
   function To_Store_Locale (Locale : String) return String is
      Result : String := Locale;
   begin
      for Index in Result'Range loop
         if Result (Index) in 'A' .. 'Z' then
            Result (Index) :=
              Character'Val (Character'Pos (Result (Index)) + 32);
         elsif Result (Index) = '_' then
            Result (Index) := '-';
         end if;
      end loop;
      return Result;
   end To_Store_Locale;

   procedure Add_Format
     (Section : String;
      Locale  : String;
      Value   : String;
      Sub     : String := "")
   is
      Key : constant String :=
        (if Sub = "" then To_Store_Locale (Locale)
         else To_Store_Locale (Locale) & Store_Sep & Sub);
   begin
      if Locale'Length = 0 or else Value'Length = 0 then
         return;
      end if;
      for C of Value loop
         if C = ASCII.HT or else C = ASCII.LF then
            return;   --  a tab or newline would corrupt the record framing
         end if;
      end loop;
      if Format_Count = Max_Format_Entries then
         Add_Error ("too many narrowed-out format rows");
         return;
      end if;
      Format_Count := Format_Count + 1;
      Format_Entries (Format_Count) :=
        (Section => US.To_Unbounded_String (Section),
         Key     => US.To_Unbounded_String (Key),
         Value   => US.To_Unbounded_String (Value));
   end Add_Format;

   --  Capture one narrowed-out unit display name for its locale's shard.
   procedure Unit_Add (Locale : String; Key : String; Value : String) is
   begin
      if Locale'Length = 0 or else Key'Length = 0 or else Value'Length = 0 then
         return;
      end if;
      for C of Value loop
         if C = ASCII.HT or else C = ASCII.LF then
            return;
         end if;
      end loop;
      if Unit_Count = Max_Unit_Entries then
         Add_Error ("too many narrowed-out unit rows");
         return;
      end if;
      Unit_Count := Unit_Count + 1;
      Unit_Entries (Unit_Count) :=
        (Section => US.To_Unbounded_String (To_Store_Locale (Locale)),
         Key     => US.To_Unbounded_String (Key),
         Value   => US.To_Unbounded_String (Value));
   end Unit_Add;

   --  Capture one narrowed-out zone exemplar city for its locale's shard.
   procedure Zone_Add (Locale : String; Key : String; Value : String) is
   begin
      if Locale'Length = 0 or else Key'Length = 0 or else Value'Length = 0 then
         return;
      end if;
      for C of Value loop
         if C = ASCII.HT or else C = ASCII.LF then
            return;
         end if;
      end loop;
      if Zone_Count = Max_Zone_Entries then
         Add_Error ("too many narrowed-out zone rows");
         return;
      end if;
      Zone_Count := Zone_Count + 1;
      Zone_Entries (Zone_Count) :=
        (Section => US.To_Unbounded_String (To_Store_Locale (Locale)),
         Key     => US.To_Unbounded_String (Key),
         Value   => US.To_Unbounded_String (Value));
   end Zone_Add;

   --  Capture one narrowed-out currency display name for its locale's shard.
   procedure Currency_Add (Locale : String; Key : String; Value : String) is
   begin
      if Locale'Length = 0 or else Key'Length = 0 or else Value'Length = 0 then
         return;
      end if;
      for C of Value loop
         if C = ASCII.HT or else C = ASCII.LF then
            return;
         end if;
      end loop;
      if Currency_Count = Max_Currency_Entries then
         Add_Error ("too many narrowed-out currency rows");
         return;
      end if;
      Currency_Count := Currency_Count + 1;
      Currency_Entries (Currency_Count) :=
        (Section => US.To_Unbounded_String (To_Store_Locale (Locale)),
         Key     => US.To_Unbounded_String (Key),
         Value   => US.To_Unbounded_String (Value));
   end Currency_Add;

   --  Emit Section -> "1" for each narrowed-out entry of a comma-separated
   --  membership list (locales or languages a boolean toggle applies to).
   procedure Emit_Membership (Section : String; List : String) is
      Start : Positive := List'First;

      procedure Take (Item : String) is
      begin
         if Item'Length > 0 and then Capture_Locale (Item) then
            Add_Format (Section, Item, "1");
         end if;
      end Take;
   begin
      for Index in List'Range loop
         if List (Index) = ',' then
            Take (List (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;
      Take (List (Start .. List'Last));
   end Emit_Membership;

   --  Store index (month/weekday/quarter number) as its bare decimal image.
   function Index_Sub (N : Integer) return String is
      Image : constant String := Integer'Image (N);
   begin
      return (if Image (Image'First) = ' '
              then Image (Image'First + 1 .. Image'Last) else Image);
   end Index_Sub;

   --  Map a CLDR date-name kind to its I18N.Locale_Data section.
   function Name_Section (Kind : String) return String is
     (if Kind = "month_full" then "month_name"
      elsif Kind = "month_short" then "month_name_short"
      elsif Kind = "weekday_full" then "weekday_name"
      elsif Kind = "weekday_short" then "weekday_name_short"
      elsif Kind = "quarter" then "quarter_name"
      elsif Kind = "quarter_short" then "quarter_name_short"
      else "");

   --  Decode the Nth "~"-separated item of a packed name set to raw UTF-8.
   function Name_Set_Item_UTF8 (Items : String; N : Positive) return String is
     (Hex_Points_To_UTF8 (Expr_Item (Items, N)));

   --  Decode a raw two-hex-digits-per-byte blob (e.g. a day_period_hex name).
   function Hex_Bytes_To_String (Hex : String) return String is
      Result : String (1 .. Hex'Length / 2);
      Source : Natural;
   begin
      for Index in Result'Range loop
         Source := Hex'First + (Index - 1) * 2;
         Result (Index) :=
           Character'Val (Hex_Value (Hex (Source .. Source + 1)));
      end loop;
      return Result;
   end Hex_Bytes_To_String;

   --  Decode the Nth comma-separated "16#NNN#" code point of a digits row.
   function Digit_Item_UTF8 (List : String; N : Positive) return String is
      Item  : constant String := Field (List, N, ',');
      Inner : constant String :=
        (if Item'Length > 4 and then Item (Item'First .. Item'First + 2) = "16#"
         then Item (Item'First + 3 .. Item'Last - 1) else Item);
   begin
      return Code_Point_UTF8 (Hex_Value (Inner));
   end Digit_Item_UTF8;

   --  Currency payload slot (1 .. 6) to its CLDR plural category.
   function Currency_Category (Slot : Positive) return String is
     (case Slot is
        when 1 => "zero",
        when 2 => "one",
        when 3 => "two",
        when 4 => "few",
        when 5 => "many",
        when others => "other");

   --  Emit each (code, category) currency display name of a narrowed-out
   --  locale from its packed "CODE:hex,...,hex;CODE2:..." payload.
   procedure Emit_Currency_Names (Locale : String; Payload : String) is
      Seg_Start : Positive := Payload'First;
   begin
      while Seg_Start <= Payload'Last loop
         declare
            Seg_End : Natural := Seg_Start;
         begin
            while Seg_End <= Payload'Last and then Payload (Seg_End) /= ';' loop
               Seg_End := Seg_End + 1;
            end loop;
            declare
               Seg : constant String := Payload (Seg_Start .. Seg_End - 1);
            begin
               if Seg'Length >= 5 and then Seg (Seg'First + 3) = ':' then
                  declare
                     Code  : constant String := Seg (Seg'First .. Seg'First + 2);
                     List  : constant String := Seg (Seg'First + 4 .. Seg'Last);
                     Forms : constant Natural := Comma_Count (List) + 1;
                  begin
                     for Slot in 1 .. 6 loop
                        Currency_Add
                          (Locale, Code & ":" & Currency_Category (Slot),
                           Hex_Bytes_To_String
                             (Field (List, Natural'Min (Slot, Forms), ',')));
                     end loop;
                  end;
               end if;
            end;
            Seg_Start := Seg_End + 1;
         end;
      end loop;
   end Emit_Currency_Names;

   procedure Add_Rule
     (Kind : String;
      A    : String := "";
      B    : String := "";
      C    : String := "";
      D    : String := "";
      E    : String := "";
      F    : String := "")
   is
   begin
      if Rule_Count = Max_Rules then
         Add_Error ("too many CLDR source rows");
         return;
      end if;

      --  Before narrowing drops them, capture the per-locale formatting rows of
      --  the un-wanted locales so formats.i18ndata can serve them on the fly.
      if Kind = "decimal" and then Capture_Locale (A) then
         Add_Format ("decimal_separator", A, Ada_Expression_UTF8_Bytes (B));
      elsif Kind = "group" and then Capture_Locale (A) then
         Add_Format ("group_separator", A, Ada_Expression_UTF8_Bytes (B));
      elsif Kind = "cardinal" or else Kind = "ordinal" then
         --  A is the rule-family name, B its comma-separated locale list.
         declare
            Section : constant String :=
              (if Kind = "cardinal" then "cardinal_family"
               else "ordinal_family");
            Start   : Positive := B'First;

            procedure Take (Loc : String) is
            begin
               if Loc'Length > 0 and then Capture_Locale (Loc) then
                  Add_Format (Section, Loc, A);
               end if;
            end Take;
         begin
            for Index in B'Range loop
               if B (Index) = ',' then
                  Take (B (Start .. Index - 1));
                  Start := Index + 1;
               end if;
            end loop;
            Take (B (Start .. B'Last));
         end;
      elsif Name_Section (Kind) /= "" and then Capture_Locale (A) then
         --  Individual override name row: A=locale, B=index, C=name expr.
         Add_Format
           (Name_Section (Kind), A, Ada_Expression_UTF8_Bytes (C),
            Sub => Index_Sub (Decimal_Value (B)));
      elsif Kind = "name_set_hex"
        and then Name_Section (A) /= ""
        and then Capture_Locale (B)
      then
         --  Packed name set: A=kind, B=locale, C=start index, D=~-list.
         declare
            Section : constant String := Name_Section (A);
            First   : constant Integer := Decimal_Value (C);
            Total   : constant Natural := Expr_Item_Count (D);
         begin
            for P in 1 .. Total loop
               Add_Format
                 (Section, B, Name_Set_Item_UTF8 (D, P),
                  Sub => Index_Sub (First + P - 1));
            end loop;
         end;
      elsif Kind = "day_month_year" then
         --  A is the comma-separated list of languages using D-M-Y order;
         --  the un-wanted ones need the flag served on the fly.
         declare
            Start : Positive := A'First;

            procedure Take (Loc : String) is
            begin
               if Loc'Length > 0 and then Capture_Locale (Loc) then
                  Add_Format ("uses_day_month_year", Loc, "1");
               end if;
            end Take;
         begin
            for Index in A'Range loop
               if A (Index) = ',' then
                  Take (A (Start .. Index - 1));
                  Start := Index + 1;
               end if;
            end loop;
            Take (A (Start .. A'Last));
         end;
      elsif Kind = "date_style_pattern" and then Capture_Locale (A) then
         --  A=locale, B=calendar, C=style, D=pattern; serve the exact CLDR
         --  pattern so a narrowed-out locale keeps its own punctuation.
         Add_Format
           ("date_style_pattern", A, Ada_Expression_UTF8_Bytes (D),
            Sub => B & ":" & C);
      elsif Kind = "digits" and then Starts_With (A, "nu-") then
         --  A numbering system's digits (A="nu-<system>"), keyed by the
         --  system and the Latin digit, for a locale that asks for them by
         --  name (-u-nu-arab, @numbers=arab).
         for P in 1 .. 10 loop
            Add_Format
              ("numbering_digits", "und", Digit_Item_UTF8 (B, P),
               Sub => A (A'First + 3 .. A'Last) & ":" & Character'Val (Character'Pos ('0') + P - 1));
         end loop;
      elsif Kind = "digits" and then Capture_Locale (A) then
         --  A=locale, B=ten comma-separated "16#NNN#" native digit points,
         --  keyed by the Latin digit they replace (0 .. 9).
         for P in 1 .. 10 loop
            Add_Format
              ("digit_text", A, Digit_Item_UTF8 (B, P),
               Sub => [1 => Character'Val (Character'Pos ('0') + P - 1)]);
         end loop;
      elsif (Kind = "day_period" or else Kind = "day_period_hex")
        and then Capture_Locale (A)
      then
         --  A=locale, B=period, C=width (wide/abbreviated), D=name; keyed by
         --  "width:period". day_period_hex is raw hex bytes, day_period an
         --  Ada string expression.
         Add_Format
           ("day_period_name", A,
            (if Kind = "day_period_hex" then Hex_Bytes_To_String (D)
             else Ada_Expression_UTF8_Bytes (D)),
            Sub => C & ":" & B);
      elsif Kind = "relative_current" and then Capture_Locale (A) then
         --  A=locale, B=base, C=width, D=name.
         Add_Format
           ("relative_current", A, Ada_Expression_UTF8_Bytes (D),
            Sub => B & ":" & C);
      elsif Kind = "relative_offset" and then Capture_Locale (A) then
         --  A=locale, B=tense (future/past), C=prefix, D=suffix.
         Add_Format
           ("relative_offset_prefix", A, Ada_Expression_UTF8_Bytes (C),
            Sub => B);
         Add_Format
           ("relative_offset_suffix", A, Ada_Expression_UTF8_Bytes (D),
            Sub => B);
      elsif Kind = "relative_unit_category"
        and then Capture_Locale (A)
      then
         --  A=locale, B=base, C=category, D=name.
         Add_Format
           ("relative_unit_category", A, Ada_Expression_UTF8_Bytes (D),
            Sub => B & ":" & C);
      elsif Kind = "relative_time_pattern"
        and then Capture_Locale (A)
      then
         --  A=locale, B=base, C=width, D=tense, E=category, F=pattern.
         Add_Format
           ("relative_time_pattern", A, Ada_Expression_UTF8_Bytes (F),
            Sub => B & ":" & C & ":" & D & ":" & E);
      elsif Kind = "unit_name" and then Capture_Locale (A) then
         --  A=locale, B=base, C=width, D=category, E=name; sharded per
         --  locale into units/<locale>.i18ndata, keyed "base:width:category".
         Unit_Add (A, B & ":" & C & ":" & D, Ada_Expression_UTF8_Bytes (E));
      elsif Kind = "symbol_first" then
         --  A = comma-separated list of symbol-first languages.
         Emit_Membership ("currency_symbol_first", A);
      elsif Kind = "indian_grouping" then
         --  A = the language list (the narrowable part). B is the fixed
         --  "-IN" substring rule, kept by the compiled fallback, so only the
         --  languages need serving.
         Emit_Membership ("indian_grouping", A);
      elsif Kind = "available_format" and then Capture_Locale (A) then
         --  A=locale, B=skeleton, C=pattern.
         Add_Format
           ("available_format", A, Ada_Expression_UTF8_Bytes (C), Sub => B);
      elsif Kind = "zone_gmt_prefix" and then Capture_Locale (A) then
         Add_Format ("gmt_offset_prefix", A, Ada_Expression_UTF8_Bytes (B));
      elsif Kind = "zone_offset_separator"
        and then Capture_Locale (A)
      then
         Add_Format
           ("timezone_offset_separator", A, Ada_Expression_UTF8_Bytes (B));
      elsif Kind = "zone_location_pattern"
        and then Capture_Locale (A)
      then
         Add_Format
           ("timezone_location_pattern", A, Ada_Expression_UTF8_Bytes (B));
      elsif Kind = "zone_exemplar" and then Capture_Locale (A) then
         --  A=locale, B=zone id, C=exemplar city (Ada expression).
         Zone_Add (A, B, Ada_Expression_UTF8_Bytes (C));
      elsif Kind = "zone_exemplar_hex" and then Capture_Locale (A) then
         --  A=locale, B=zone id, C=exemplar city (raw hex bytes).
         Zone_Add (A, B, Hex_Bytes_To_String (C));
      elsif Kind = "currency_name_payload"
        and then Capture_Locale (A)
      then
         --  A=locale, B=packed "CODE:hex,...;..." per-code display names.
         Emit_Currency_Names (A, B);
      elsif Kind = "unit_separator" and then Capture_Locale (A) then
         --  A=locale, B=part ("per"), C=separator.
         Add_Format
           ("per_unit_separator", A, Ada_Expression_UTF8_Bytes (C));
      elsif Kind = "list_separator" and then Capture_Locale (A) then
         --  A=locale, B=family (standard/or), C=part, D=separator.
         Add_Format
           ("list_separator", A, Ada_Expression_UTF8_Bytes (D),
            Sub => B & ":" & C);
      end if;

      Rule_Count := Rule_Count + 1;
      Rules (Rule_Count) :=
        (Kind => US.To_Unbounded_String (Kind),
         A    => US.To_Unbounded_String (A),
         B    => US.To_Unbounded_String (B),
         C    => US.To_Unbounded_String (C),
         D    => US.To_Unbounded_String (D),
         E    => US.To_Unbounded_String (E),
         F    => US.To_Unbounded_String (F));
   end Add_Rule;

   procedure Parse_Line (Line : String; Line_Number : Positive) is
      Kind : constant String := Field (Line, 1);

      function Is_Day_Period (Value : String) return Boolean is
      begin
         return Value = "midnight"
           or else Value = "noon"
           or else Value = "am"
           or else Value = "pm"
           or else Value = "morning1"
           or else Value = "afternoon1"
           or else Value = "evening1"
           or else Value = "night1";
      end Is_Day_Period;

      function Is_Day_Period_Width (Value : String) return Boolean is
      begin
         return Value = "wide" or else Value = "abbreviated";
      end Is_Day_Period_Width;

      function Is_Relative_Width (Value : String) return Boolean is
      begin
         return Value = "unit-width-full-name"
           or else Value = "unit-width-short"
           or else Value = "unit-width-narrow";
      end Is_Relative_Width;

      function Is_Skeleton_Key (Value : String) return Boolean is
      begin
         if Value = "" then
            return False;
         end if;

         for C of Value loop
            if C not in 'A' .. 'Z'
              and then C not in 'a' .. 'z'
              and then C not in '0' .. '9'
              and then C /= '-'
            then
               return False;
            end if;
         end loop;

         return True;
      end Is_Skeleton_Key;

      function Is_List_Separator_Part (Value : String) return Boolean is
      begin
         return Value = "final"
           or else Value = "pair"
           or else Value = "start"
           or else Value = "middle"
           or else Value = "item";
      end Is_List_Separator_Part;

      function Is_List_Separator_Family (Value : String) return Boolean is
      begin
         return Value = "standard"
           or else Value = "or"
           or else Value = "unit";
      end Is_List_Separator_Family;

      function Is_Unit_Separator_Part (Value : String) return Boolean is
      begin
         return Value = "per";
      end Is_Unit_Separator_Part;

      function Is_Unit_Base (Value : String) return Boolean is
      begin
         if Value = "" then
            return False;
         end if;

         for C of Value loop
            if C not in 'a' .. 'z'
              and then C not in '0' .. '9'
              and then C /= '-'
            then
               return False;
            end if;
         end loop;

         return True;
      end Is_Unit_Base;

      function Is_Relative_Base (Value : String) return Boolean is
      begin
         return Value = "day"
           or else Value = "quarter"
           or else Value = "week"
           or else Value = "month"
           or else Value = "year"
           or else Value = "hour"
           or else Value = "minute"
           or else Value = "second";
      end Is_Relative_Base;

      function Is_Plural_Category (Value : String) return Boolean is
      begin
         return Value = "zero"
           or else Value = "one"
           or else Value = "two"
           or else Value = "few"
           or else Value = "many"
           or else Value = "other";
      end Is_Plural_Category;

      function Is_Zone_Id (Value : String) return Boolean is
      begin
         if Value = "" then
            return False;
         end if;

         for C of Value loop
            if C = '|'
              or else C = ASCII.LF
              or else C = ASCII.CR
            then
               return False;
            end if;
         end loop;

         return True;
      end Is_Zone_Id;

   begin
      if Line'Length = 0 or else Line (Line'First) = '#' then
         return;
      elsif Kind = "decimal"
        or else Kind = "group"
        or else Kind = "digits"
        or else Kind = "cardinal"
        or else Kind = "ordinal"
      then
         if Field_Count (Line) /= 3 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         elsif Kind = "digits" and then Comma_Count (Field (Line, 3)) /= 10 then
            Add_Line_Error (Line_Number, "digits row must contain 10 code points");
         end if;
         Add_Rule (Kind, Field (Line, 2), Field (Line, 3));
      elsif Kind = "month_full"
        or else Kind = "month_short"
        or else Kind = "weekday_full"
        or else Kind = "weekday_short"
        or else Kind = "quarter"
        or else Kind = "quarter_short"
      then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Decimal_Text (Field (Line, 3))
           or else Field (Line, 4) = ""
         then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         elsif (Kind = "month_full" or else Kind = "month_short")
           and then (Decimal_Value (Field (Line, 3)) < 1
                     or else Decimal_Value (Field (Line, 3)) > 12)
         then
            Add_Line_Error (Line_Number, "month index must be 1 through 12");
         elsif (Kind = "weekday_full" or else Kind = "weekday_short")
           and then Decimal_Value (Field (Line, 3)) > 6
         then
            Add_Line_Error (Line_Number, "weekday index must be 0 through 6");
         elsif (Kind = "quarter" or else Kind = "quarter_short")
           and then (Decimal_Value (Field (Line, 3)) < 1
                     or else Decimal_Value (Field (Line, 3)) > 4)
         then
            Add_Line_Error (Line_Number, "quarter index must be 1 through 4");
         end if;
         Add_Rule (Kind, Field (Line, 2), Field (Line, 3), Field (Line, 4));
      elsif Kind = "name_set_hex" then
         if Field_Count (Line) /= 5
           or else not (Field (Line, 2) = "month_full"
                        or else Field (Line, 2) = "month_short"
                        or else Field (Line, 2) = "weekday_full"
                        or else Field (Line, 2) = "weekday_short"
                        or else Field (Line, 2) = "quarter"
                        or else Field (Line, 2) = "quarter_short")
           or else Field (Line, 3) = ""
           or else not Is_Decimal_Text (Field (Line, 4))
           or else Field (Line, 5) = ""
         then
            Add_Line_Error (Line_Number, "invalid name_set_hex row shape");
         elsif Expr_Item_Count (Field (Line, 5))
           /= (if Field (Line, 2) = "month_full"
                 or else Field (Line, 2) = "month_short"
               then 12
               elsif Field (Line, 2) = "quarter"
                 or else Field (Line, 2) = "quarter_short"
               then 4
               else 7)
         then
            Add_Line_Error (Line_Number, "unexpected name_set item count");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5));
      elsif Kind = "day_period" or else Kind = "day_period_hex" then
         if Field_Count (Line) /= 5
           or else Field (Line, 2) = ""
           or else not Is_Day_Period (Field (Line, 3))
           or else not Is_Day_Period_Width (Field (Line, 4))
           or else Field (Line, 5) = ""
           or else (Kind = "day_period_hex" and then not Is_Hex_Bytes (Field (Line, 5)))
         then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5));
      elsif Kind = "list_separator" then
         declare
            Count  : constant Natural := Field_Count (Line);
            Locale : constant String := Field (Line, 2);
            Family : constant String :=
              (if Count = 4 then "standard" else Field (Line, 3));
            Part   : constant String :=
              (if Count = 4 then Field (Line, 3) else Field (Line, 4));
            Value  : constant String :=
              (if Count = 4 then Field (Line, 4) else Field (Line, 5));
         begin
            if Count not in 4 | 5
              or else Locale = ""
              or else not Is_List_Separator_Family (Family)
              or else not Is_List_Separator_Part (Part)
              or else Value = ""
            then
               Add_Line_Error (Line_Number, "invalid list_separator row shape");
            end if;
            Add_Rule (Kind, Locale, Family, Part, Value);
         end;
      elsif Kind = "unit_separator" then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Unit_Separator_Part (Field (Line, 3))
           or else Field (Line, 4) = ""
         then
            Add_Line_Error (Line_Number, "invalid unit_separator row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4));
      elsif Kind = "zone_gmt_prefix"
        or else Kind = "zone_offset_separator"
        or else Kind = "zone_location_pattern"
      then
         if Field_Count (Line) /= 3
           or else Field (Line, 2) = ""
           or else Field (Line, 3) = ""
         then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3));
      elsif Kind = "available_format" then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Skeleton_Key (Field (Line, 3))
           or else Field (Line, 4) = ""
         then
            Add_Line_Error (Line_Number, "invalid available_format row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4));
      elsif Kind = "date_style_pattern" then
         if Field_Count (Line) /= 5
           or else Field (Line, 2) = ""
           or else Field (Line, 3) = ""
           or else Field (Line, 4) = ""
           or else Field (Line, 5) = ""
         then
            Add_Line_Error
              (Line_Number, "invalid date_style_pattern row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5));
      elsif Kind = "unit_short" then
         if Field_Count (Line) /= 3
           or else not Is_Unit_Base (Field (Line, 2))
           or else Field (Line, 3) = ""
         then
            Add_Line_Error (Line_Number, "invalid unit_short row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3));
      elsif Kind = "unit_name" then
         if Field_Count (Line) /= 6
           or else Field (Line, 2) = ""
           or else not Is_Unit_Base (Field (Line, 3))
           or else Field (Line, 4) = ""
           or else not Is_Plural_Category (Field (Line, 5))
           or else Field (Line, 6) = ""
         then
            Add_Line_Error (Line_Number, "invalid unit_name row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5),
            Field (Line, 6));
      elsif Kind = "relative_current" then
         if Field_Count (Line) /= 5
           or else Field (Line, 2) = ""
           or else not Is_Relative_Base (Field (Line, 3))
           or else not Is_Relative_Width (Field (Line, 4))
           or else Field (Line, 5) = ""
         then
            Add_Line_Error (Line_Number, "invalid relative_current row shape");
         end if;
         Add_Rule
           (Kind,
           Field (Line, 2),
           Field (Line, 3),
           Field (Line, 4),
           Field (Line, 5));
      elsif Kind = "relative_offset" then
         if Field_Count (Line) /= 5
           or else Field (Line, 2) = ""
           or else (Field (Line, 3) /= "future" and then Field (Line, 3) /= "past")
           or else Field (Line, 4) = ""
           or else Field (Line, 5) = ""
         then
            Add_Line_Error (Line_Number, "invalid relative_offset row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5));
      elsif Kind = "relative_unit_category" then
         if Field_Count (Line) /= 5
           or else Field (Line, 2) = ""
           or else not Is_Relative_Base (Field (Line, 3))
           or else not Is_Plural_Category (Field (Line, 4))
           or else Field (Line, 5) = ""
         then
            Add_Line_Error (Line_Number, "invalid relative_unit_category row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5));
      elsif Kind = "relative_time_pattern" then
         if Field_Count (Line) /= 7
           or else Field (Line, 2) = ""
           or else not Is_Relative_Base (Field (Line, 3))
           or else not Is_Relative_Width (Field (Line, 4))
           or else (Field (Line, 5) /= "future" and then Field (Line, 5) /= "past")
           or else not Is_Plural_Category (Field (Line, 6))
           or else Field (Line, 7) = ""
         then
            Add_Line_Error
              (Line_Number, "invalid relative_time_pattern row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5),
            Field (Line, 6),
            Field (Line, 7));
      elsif Kind = "zone_exemplar" then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Zone_Id (Field (Line, 3))
           or else Field (Line, 4) = ""
         then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4));
      elsif Kind = "zone_exemplar_hex" then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Zone_Id (Field (Line, 3))
           or else not Is_Hex_Bytes (Field (Line, 4))
         then
            Add_Line_Error (Line_Number, "invalid zone_exemplar_hex row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4));
      elsif Kind = "zone_meta" then
         --  Locale-independent zone metadata (metazone periods, reference
         --  zones, primary zones), kept under und where every walk ends.
         if Field_Count (Line) /= 3 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid zone_meta row shape");
         else
            Add_Format ("zone_meta", "und", Field (Line, 3), Sub => Field (Line, 2));
         end if;
      elsif Kind = "zone_text" then
         --  A locale's zone format text by name ("fallback": "{1} ({0})").
         if Field_Count (Line) /= 4 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid zone_text row shape");
         elsif Capture_Locale (Field (Line, 2)) then
            Add_Format
              ("zone_text", Field (Line, 2), Ada_Expression_UTF8_Bytes (Field (Line, 4)),
               Sub => Field (Line, 3));
         end if;
      elsif Kind = "hour_text" then
         --  A region's preferred hour symbol, under und keyed by the region.
         if Field_Count (Line) /= 4 or else Field (Line, 3) = "" or else Field (Line, 4) = "" then
            Add_Line_Error (Line_Number, "invalid hour_text row shape");
         else
            Add_Format ("hour_cycle", "und", Ada_Expression_UTF8_Bytes (Field (Line, 4)), Sub => Field (Line, 3));
         end if;
      elsif Kind = "unit_text" then
         --  A unit pattern that is not the value, a space and the name, into
         --  the locale's unit shard beside the name, keyed p:base:width:category.
         if Field_Count (Line) /= 4 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid unit_text row shape");
         elsif Capture_Locale (Field (Line, 2)) then
            Unit_Add (Field (Line, 2), "p:" & Field (Line, 3), Ada_Expression_UTF8_Bytes (Field (Line, 4)));
         end if;
      elsif Kind = "relative_text" then
         --  A locale's named relative offset ("yesterday", "last Monday"),
         --  keyed base:width:offset.
         if Field_Count (Line) /= 4 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid relative_text row shape");
         elsif Capture_Locale (Field (Line, 2)) then
            Add_Format
              ("relative_exact", Field (Line, 2), Ada_Expression_UTF8_Bytes (Field (Line, 4)),
               Sub => Field (Line, 3));
         end if;
      elsif Kind = "number_text" then
         --  A locale's number symbol by name (plus, minus, percent, permille,
         --  exponent), into the section the number formatter reads.
         if Field_Count (Line) /= 4 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid number_text row shape");
         elsif Capture_Locale (Field (Line, 2)) then
            declare
               Name    : constant String := Field (Line, 3);
               Section : constant String :=
                 (if Name = "plus" then "number_plus_sign"
                  elsif Name = "minus" then "number_minus_sign"
                  elsif Name = "percent" then "number_percent_suffix"
                  elsif Name = "permille" then "number_permille_suffix"
                  elsif Name = "exponent" then "number_exponent_separator"
                  else "");
            begin
               if Section = "" then
                  Add_Line_Error (Line_Number, "unknown number_text name " & Name);
               else
                  Add_Format (Section, Field (Line, 2), Ada_Expression_UTF8_Bytes (Field (Line, 4)));
               end if;
            end;
         end if;
      elsif Kind = "zone_specific_name" then
         --  A zone's or metazone's six names, into the locale's zone shard
         --  beside its exemplar cities, under keys no zone id can have
         --  (lg/ls/ld: long generic, standard, daylight; sg/ss/sd: short):
         --  loaded only for the locales a program formats in.
         if Field_Count (Line) /= 9 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid zone_specific_name row shape");
         elsif Capture_Locale (Field (Line, 2)) then
            declare
               type Prefixes is array (1 .. 6) of String (1 .. 3);
               Prefix : constant Prefixes := ["lg:", "ls:", "ld:", "sg:", "ss:", "sd:"];
            begin
               for Index in Prefix'Range loop
                  declare
                     Name : constant String := Ada_Expression_UTF8_Bytes (Field (Line, 3 + Index));
                  begin
                     if Name /= "" then
                        Zone_Add (Field (Line, 2), Prefix (Index) & Field (Line, 3), Name);
                     end if;
                  end;
               end loop;
            end;
         end if;
      elsif Kind = "indian_grouping" then
         if Field_Count (Line) /= 3 or else Field (Line, 2) = "" or else Field (Line, 3) = "" then
            Add_Line_Error (Line_Number, "invalid indian_grouping row shape");
         end if;
         Add_Rule (Kind, Field (Line, 2), Field (Line, 3));
      elsif Kind = "day_month_year" or else Kind = "symbol_first" then
         if Field_Count (Line) /= 2 or else Field (Line, 2) = "" then
            Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
         end if;
         Add_Rule (Kind, Field (Line, 2));
      elsif Kind = "currency" then
         if Field_Count (Line) /= 7
           or else Field (Line, 2)'Length /= 3
           or else not Is_Decimal_Text (Field (Line, 3))
           or else not Is_Decimal_Text (Field (Line, 4))
           or else Field (Line, 5) = ""
           or else Field (Line, 6) = ""
           or else Field (Line, 7) = ""
         then
            Add_Line_Error (Line_Number, "invalid currency row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5),
            Field (Line, 6),
            Field (Line, 7));
         --  The currency's own data, keyed by its code under und: minor units
         --  and cash increment (kept only where they are not 2 and 1), its
         --  symbol and its narrow symbol.
         declare
            Code : constant String := Field (Line, 2);
         begin
            if Field (Line, 3) /= "2" then
               Add_Format ("currency_minor_units", "und", Field (Line, 3), Sub => Code);
            end if;
            if Field (Line, 4) /= "1" then
               Add_Format ("currency_cash_increment", "und", Field (Line, 4), Sub => Code);
            end if;
            Add_Format ("currency_symbol", "und", Ada_Expression_UTF8_Bytes (Field (Line, 5)), Sub => Code);
            Add_Format ("currency_narrow_symbol", "und", Ada_Expression_UTF8_Bytes (Field (Line, 6)), Sub => Code);
         end;
      elsif Kind = "currency_name_payload" then
         if Field_Count (Line) /= 3
           or else Field (Line, 2) = ""
           or else Field (Line, 3) = ""
         then
            Add_Line_Error (Line_Number, "invalid currency_name_payload row shape");
         end if;
         Add_Rule (Kind, Field (Line, 2), Field (Line, 3));
      else
         Add_Line_Error (Line_Number, "invalid CLDR source row: " & Line);
      end if;
   end Parse_Line;

   procedure Parse_Source is
      Input : Ada.Text_IO.File_Type;
      Line_Number : Positive := 1;
   begin
      Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Source_Path);
      while not Ada.Text_IO.End_Of_File (Input) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (Input);
         begin
            Parse_Line (Line, Line_Number);
         end;
         Line_Number := Line_Number + 1;
      end loop;
      Ada.Text_IO.Close (Input);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Input) then
            Ada.Text_IO.Close (Input);
         end if;
         raise;
   end Parse_Source;

   procedure Load_TZDB_Links is
      Text        : constant String := Project_Tools.Files.Read_Raw_File (TZDB_Path);
      Start       : Positive := Text'First;
      Stop        : Natural;
      Line_Number : Positive := 1;
   begin
      if not Starts_With (Text, "# version 2026a" & ASCII.LF) then
         Add_Error ("tzdb generator requires tzdata.zi version 2026a");
      end if;

      while Start <= Text'Last loop
         Stop := Start;
         while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
            Stop := Stop + 1;
         end loop;

         if Stop > Start then
            declare
               Line : constant String := Text (Start .. Stop - 1);
            begin
               if Starts_With (Line, "L ") then
                  declare
                     Target : constant String := Space_Field (Line, 2);
                     Link   : constant String := Space_Field (Line, 3);
                  begin
                     if not Valid_Zone_Name (Target) or else not Valid_Zone_Name (Link) then
                        Add_TZDB_Line_Error (Line_Number, "invalid tzdb link row");
                     else
                        Add_TZDB_Link (Target, Link);
                     end if;
                  end;
               elsif Starts_With (Line, "Z ") then
                  declare
                     Zone : constant String := Space_Field (Line, 2);
                  begin
                     if Valid_Zone_Name (Zone) then
                        Add_TZDB_Zone (Zone);
                     else
                        Add_TZDB_Line_Error (Line_Number, "invalid tzdb zone row");
                     end if;
                  end;
               end if;
            end;
         end if;

         Start := Stop + 1;
         Line_Number := Line_Number + 1;
      end loop;

      if TZDB_Link_Count < 100 then
         Add_Error ("tzdb generator found too few link rows");
      end if;

      if TZDB_Zone_Count < 300 then
         Add_Error ("tzdb generator found too few primary zone rows");
      end if;
   exception
      when others =>
      Add_Error ("failed to load tzdb links from " & TZDB_Path);
   end Load_TZDB_Links;

   procedure Add_TZDB_Transition
     (Zone_Index : Natural;
      Key        : Long_Long_Integer;
      Offset     : Integer;
      Daylight   : Boolean)
   is
   begin
      if Zone_Index = 0 then
         return;
      end if;

      if TZDB_Transition_Count = TZDB_Transition_Keys'Last then
         Add_Error ("too many generated tzdb transitions");
         return;
      end if;

      TZDB_Transition_Count := TZDB_Transition_Count + 1;
      TZDB_Transition_Zones (TZDB_Transition_Count) := Zone_Index;
      TZDB_Transition_Keys (TZDB_Transition_Count) := Key;
      TZDB_Transition_Offsets (TZDB_Transition_Count) := Offset;
      TZDB_Transition_Daylight (TZDB_Transition_Count) := Daylight;
   end Add_TZDB_Transition;

   --  Transitions are read through this year, past any zone's predicted
   --  ones (Casablanca's Ramadan changes run into the 2080s), so each zone's
   --  final rule can be checked against them before it replaces them.
   TZDB_Last_Year : constant := 2100;
   --  zdump is asked for a year beyond that: glibc's reports a change in the
   --  last hours before its range ends that is no change at all (Casablanca,
   --  as Ubuntu 26.04's zic writes it, "changes" to +02 at 22:00 UTC on the
   --  last 31 December asked for), and it must not land in a kept year.
   TZDB_Range     : constant String := "1900,2102";

   --  CLDR names some zones by ids the tz database keeps only as links
   --  (Asia/Calcutta for Asia/Kolkata, America/Godthab for America/Nuuk). A
   --  metazone row or a zone's own name under such an id is filed under the
   --  zone it links to as well, so a lookup by the tz database's name finds it.
   --  The zone a tz database link points at; "" for a name that is no link.
   function Link_Target (Name : String) return String is
   begin
      for Index in 1 .. TZDB_Link_Count loop
         if S (TZDB_Link_Names (Index)) = Name then
            return S (TZDB_Link_Targets (Index));
         end if;
      end loop;
      return "";
   end Link_Target;

   --  Each zone's country, from the tz database's zone.tab, as zone_meta
   --  "cc:<zone>" -> "<country>", with a '*' when the zone is its country's
   --  primary one: its only zone, or the one CLDR's primaryZones names. A
   --  zone's generic location name is its country's name when primary, its
   --  city's otherwise ("United Kingdom Time", "Sydney Time").
   procedure Add_Zone_Countries is
      Text : constant String := Project_Tools.Files.Read_Raw_File ("upstream/tzdb/zone.tab");

      type Row is record
         Country : US.Unbounded_String;
         Zone    : US.Unbounded_String;
      end record;
      Rows  : array (1 .. 1_000) of Row;
      Count : Natural := 0;

      function Primary_Of (Country : String) return String is
         Key : constant String := "und" & Store_Sep & "primary:" & Country;
      begin
         for Index in 1 .. Format_Count loop
            if S (Format_Entries (Index).Section) = "zone_meta"
              and then S (Format_Entries (Index).Key) = Key
            then
               return S (Format_Entries (Index).Value);
            end if;
         end loop;
         return "";
      end Primary_Of;

      Start : Positive := Text'First;
   begin
      while Start <= Text'Last loop
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;
            declare
               Line : constant String := Text (Start .. Stop - 1);
            begin
               if Line'Length > 0 and then Line (Line'First) /= '#' and then Count < Rows'Last then
                  Count := Count + 1;
                  Rows (Count) :=
                    (Country => US.To_Unbounded_String (Field (Line, 1, ASCII.HT)),
                     Zone    => US.To_Unbounded_String (Field (Line, 3, ASCII.HT)));
               end if;
            end;
            Start := Stop + 1;
         end;
      end loop;

      for Index in 1 .. Count loop
         declare
            Country : constant String := S (Rows (Index).Country);
            Zone    : constant String := S (Rows (Index).Zone);
            Zones   : Natural := 0;
         begin
            for Other in 1 .. Count loop
               if S (Rows (Other).Country) = Country then
                  Zones := Zones + 1;
               end if;
            end loop;
            --  CLDR may name the primary zone by an id the tz database keeps
            --  as a link (Europe/Kiev for Europe/Kyiv).
            Add_Format
              ("zone_meta", "und",
               Country
               & (if Zones = 1
                    or else Primary_Of (Country) = Zone
                    or else Link_Target (Primary_Of (Country)) = Zone
                  then "*" else ""),
               Sub => "cc:" & Zone);
         end;
      end loop;
   exception
      when others =>
         Add_Error ("failed to read upstream/tzdb/zone.tab");
   end Add_Zone_Countries;

   --  The accounting, currency, unit and zone symbols the formatters had from
   --  constants compiled into I18N.CLDR_Data, which CLDR keeps in patterns
   --  rather than as symbols: the same values, as und rows of the formats
   --  file.
   procedure Add_Fixed_Formats is
   begin
      Add_Format ("number_accounting_prefix", "und", "(");
      Add_Format ("number_accounting_suffix", "und", ")");
      Add_Format ("currency_amount_separator", "und", " ");
      Add_Format ("currency_accounting_prefix", "und", "(");
      Add_Format ("currency_accounting_suffix", "und", ")");
      Add_Format ("unit_value_separator", "und", " ");
      Add_Format ("unit_short_per_separator", "und", "/");
      Add_Format ("timezone_utc_designator", "und", "Z");
      Add_Format ("timezone_offset_separator", "und", ":");
   end Add_Fixed_Formats;

   procedure File_CLDR_Zone_Aliases is

      Format_Before : constant Natural := Format_Count;
      Zone_Before   : constant Natural := Zone_Count;
   begin
      for Index in 1 .. Format_Before loop
         if S (Format_Entries (Index).Section) = "zone_meta" then
            declare
               Key    : constant String := S (Format_Entries (Index).Key);
               Prefix : constant String := "und" & Store_Sep & "mz:";
               Zone   : constant String :=
                 (if Key'Length > Prefix'Length and then Key (Key'First .. Key'First + Prefix'Length - 1) = Prefix
                  then Key (Key'First + Prefix'Length .. Key'Last) else "");
               Target : constant String := (if Zone = "" then "" else Link_Target (Zone));
            begin
               if Target /= "" then
                  Add_Format ("zone_meta", "und", S (Format_Entries (Index).Value), Sub => "mz:" & Target);
               end if;
            end;
         end if;
      end loop;

      for Index in 1 .. Zone_Before loop
         declare
            Key : constant String := S (Zone_Entries (Index).Key);
         begin
            --  An exemplar city is keyed by the bare zone id.
            if Key'Length > 0 and then (for all C of Key => C /= ':') then
               declare
                  Target : constant String := Link_Target (Key);
               begin
                  if Target /= "" then
                     Zone_Count := Zone_Count + 1;
                     Zone_Entries (Zone_Count) :=
                       (Section => Zone_Entries (Index).Section,
                        Key     => US.To_Unbounded_String (Target),
                        Value   => Zone_Entries (Index).Value);
                  end if;
               end;
            elsif Key'Length > 8 and then Key (Key'First + 2 .. Key'First + 7) = ":zone:" then
               declare
                  Target : constant String := Link_Target (Key (Key'First + 8 .. Key'Last));
               begin
                  if Target /= "" then
                     Zone_Count := Zone_Count + 1;
                     Zone_Entries (Zone_Count) :=
                       (Section => Zone_Entries (Index).Section,
                        Key     => US.To_Unbounded_String (Key (Key'First .. Key'First + 7) & Target),
                        Value   => Zone_Entries (Index).Value);
                  end if;
               end;
            end if;
         end;
      end loop;
      Add_Zone_Countries;
   end File_CLDR_Zone_Aliases;

   procedure Load_TZDB_Transitions is

      Zic   : constant String := Project_Tools.Processes.Locate_Command ("zic");
      ZDump : constant String := Project_Tools.Processes.Locate_Command ("zdump");

      --  Ada creates and addresses this directory natively; it must be absolute,
      --  because zdump reads a slash-led argument as an absolute tzfile but
      --  anything else as TZDIR-relative (a relative path sends it looking under
      --  /usr/share/zoneinfo, not here). See Tool_Path for the Windows twist.
      Out_Dir : constant String := Hostkit.Fs.Temp_Directory & "/i18n_tzdb_generated";

      --  On Windows the zic/zdump that Locate_Command finds are the Unix tools
      --  from git-bash/MSYS2: they cannot resolve a native "C:\Users\...\Temp"
      --  path (zdump then reports "unknown timezone"). Rewrite a "C:\dir" /
      --  "C:/dir" drive path to its git-bash mount form "/c/dir" -- an absolute
      --  POSIX path the tools accept, pointing at the same location Ada created.
      --  A path with no drive letter is returned unchanged, so this is a no-op
      --  on Linux and macOS, where Out_Dir is already an absolute POSIX path.
      function Tool_Path (P : String) return String is
      begin
         if P'Length >= 2
           and then P (P'First + 1) = ':'
           and then P (P'First) in 'A' .. 'Z' | 'a' .. 'z'
         then
            declare
               Drive : constant Character :=
                 (if P (P'First) in 'A' .. 'Z'
                  then Character'Val (Character'Pos (P (P'First)) + 32)
                  else P (P'First));
               Rest  : String := P (P'First + 2 .. P'Last);
            begin
               for C of Rest loop
                  if C = '\' then
                     C := '/';
                  end if;
               end loop;
               return '/' & Drive & Rest;
            end;
         end if;
         return P;
      end Tool_Path;

      Tool_Out_Dir : constant String := Tool_Path (Out_Dir);

      --  The last transition a compiled (version 2 or later) file lists: the
      --  last entry of the 64-bit transition times that follow the second
      --  header. Long_Long_Integer'Last for a file this cannot read, so that
      --  every instant is checked against zdump.
      function Last_Explicit_Transition (Raw : String) return Long_Long_Integer is
         function Count_At (Index : Positive) return Natural is
           (((Character'Pos (Raw (Index)) * 256 + Character'Pos (Raw (Index + 1))) * 256
             + Character'Pos (Raw (Index + 2))) * 256 + Character'Pos (Raw (Index + 3)));
         First : constant Positive := Raw'First;
         Header : constant := 44;
      begin
         if Raw'Length < 2 * Header or else Raw (First .. First + 3) /= "TZif"
           or else Raw (First + 4) = ASCII.NUL
         then
            return Long_Long_Integer'Last;
         end if;
         declare
            Is_UT    : constant Natural := Count_At (First + 20);
            Is_Std   : constant Natural := Count_At (First + 24);
            Leaps    : constant Natural := Count_At (First + 28);
            Times    : constant Natural := Count_At (First + 32);
            Types    : constant Natural := Count_At (First + 36);
            Chars    : constant Natural := Count_At (First + 40);
            Second   : constant Positive :=
              First + Header + Times * 5 + Types * 6 + Chars + Leaps * 8 + Is_Std + Is_UT;
            Times_64 : constant Natural := Count_At (Second + 32);
            Result   : Long_Long_Integer;
         begin
            if Raw (Second .. Second + 3) /= "TZif" or else Times_64 = 0 then
               return Long_Long_Integer'Last;
            end if;
            declare
               At_Last : constant Positive := Second + Header + (Times_64 - 1) * 8;
            begin
               --  Big-endian two's complement: the leading byte carries the sign.
               Result := Long_Long_Integer (Character'Pos (Raw (At_Last)));
               if Result >= 128 then
                  Result := Result - 256;
               end if;
               for Index in At_Last + 1 .. At_Last + 7 loop
                  Result := Result * 256 + Long_Long_Integer (Character'Pos (Raw (Index)));
               end loop;
               return Result;
            end;
         end;
      exception
         when Constraint_Error =>
            return Long_Long_Integer'Last;
      end Last_Explicit_Transition;

      procedure Parse_Initial_Offset
        (Zone_Index : Positive;
         Text       : String)
      is
         Start : Positive := Text'First;
         Stop  : Natural;
      begin
         while Start <= Text'Last loop
            Stop := Start;
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;

            if Stop > Start then
               declare
                  Line : constant String := Text (Start .. Stop - 1);
               begin
                  if Starts_With (Line, "-" & ASCII.HT & "-") then
                     TZDB_Zone_Initial_Offsets (Zone_Index) :=
                       Parse_TZDB_Offset_Seconds (Field (Line, 3, ASCII.HT));
                     return;
                  end if;
               end;
            end if;

            Start := Stop + 1;
         end loop;
      end Parse_Initial_Offset;

      procedure Parse_Transitions
        (Zone_Index : Positive;
         Text       : String)
      is
         Start : Positive := Text'First;
         Stop  : Natural;
      begin
         while Start <= Text'Last loop
            Stop := Start;
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;

            if Stop > Start then
               declare
                  Line : constant String := Text (Start .. Stop - 1);
               begin
                  if Contains (Line, " UT = ")
                    and then Contains (Line, " gmtoff=")
                  then
                     declare
                        Month_Text  : constant String := Token (Line, 3);
                        Day_Text    : constant String := Token (Line, 4);
                        Time_Text   : constant String := Token (Line, 5);
                        Year_Text   : constant String := Token (Line, 6);
                        Offset_Text : constant String := Tail_After (Line, "gmtoff=");
                        Year        : constant Natural := Bounded_Decimal (Year_Text, 4);
                        Month       : constant Natural := Month_Number (Month_Text);
                        Day         : constant Natural := Bounded_Decimal (Day_Text, 2);
                        Hour        : constant Natural :=
                          Bounded_Decimal (Field (Time_Text, 1, ':'), 2);
                        Minute      : constant Natural :=
                          Bounded_Decimal (Field (Time_Text, 2, ':'), 2);
                        Second      : constant Natural :=
                          Bounded_Decimal (Field (Time_Text, 3, ':'), 2);
                        Offset      : constant Integer :=
                          Signed_Decimal_Value (Offset_Text);
                        Daylight    : constant Boolean :=
                          Contains (Line, " isdst=1");
                     begin
                        if Year in 1900 .. TZDB_Last_Year
                          and then Month in 1 .. 12
                          and then Day in 1 .. 31
                          and then Hour <= 23
                          and then Minute <= 59
                          and then Second <= 60
                        then
                           Add_TZDB_Transition
                             (Zone_Index,
                              TZDB_Key (Year, Month, Day, Hour, Minute, Second),
                              Offset, Daylight);
                        end if;
                     exception
                        when others =>
                           Add_Error
                             ("failed to parse zdump transition for "
                              & S (TZDB_Zone_Names (Zone_Index)));
                     end;
                  end if;
               end;
            end if;

            Start := Stop + 1;
         end loop;
      end Parse_Transitions;
   begin
      if Zic = "" then
         Add_Error ("zic is required to generate checked tzdb transitions");
         return;
      elsif ZDump = "" then
         Add_Error ("zdump is required to generate checked tzdb transitions");
         return;
      end if;

      Ada.Directories.Create_Path (Out_Dir);

      declare
         Args : constant GNAT.OS_Lib.Argument_List (1 .. 3) :=
           [new String'("-d"), new String'(Tool_Out_Dir), new String'(TZDB_Path)];
      begin
         if Project_Tools.Processes.Run_Status
              ("compile checked tzdb", ".", Zic, Args, Quiet => True) /= 0
         then
            Add_Error ("failed to compile checked tzdb with zic");
            return;
         end if;
      end;

      for Zone_Index in 1 .. TZDB_Zone_Count loop
         declare
            Zone_Path : constant String := Tool_Out_Dir & "/" & S (TZDB_Zone_Names (Zone_Index));
            Output    : US.Unbounded_String;
            Args_I    : constant GNAT.OS_Lib.Argument_List (1 .. 4) :=
              [new String'("-i"), new String'("-c"), new String'(TZDB_Range),
               new String'(Zone_Path)];
            Args_V    : constant GNAT.OS_Lib.Argument_List (1 .. 4) :=
              [new String'("-v"), new String'("-c"), new String'(TZDB_Range),
               new String'(Zone_Path)];
         begin
            if Project_Tools.Processes.Run_Status
                 ("read tzdb initial offset", ".", ZDump, Args_I, Output, Quiet => True) = 0
            then
               Parse_Initial_Offset (Zone_Index, S (Output));
            else
               Add_Error ("failed to read tzdb initial offset for " & S (TZDB_Zone_Names (Zone_Index)));
            end if;

            if Project_Tools.Processes.Run_Status
                 ("read tzdb transitions", ".", ZDump, Args_V, Output, Quiet => True) = 0
            then
               Parse_Transitions (Zone_Index, S (Output));
            else
               Add_Error ("failed to read tzdb transitions for " & S (TZDB_Zone_Names (Zone_Index)));
            end if;
         end;
      end loop;

      --  The final rule: zic ends each compiled file with it, between the
      --  last two newlines.
      for Zone_Index in 1 .. TZDB_Zone_Count loop
         declare
            Raw  : constant String :=
              Project_Tools.Files.Read_Raw_File (Out_Dir & "/" & S (TZDB_Zone_Names (Zone_Index)));
            Stop  : Natural := Raw'Last;
            Start : Natural;
         begin
            if Stop >= Raw'First and then Raw (Stop) = ASCII.LF then
               Stop := Stop - 1;
               Start := Stop;
               while Start >= Raw'First and then Raw (Start) /= ASCII.LF loop
                  Start := Start - 1;
               end loop;
               TZDB_Zone_Rules (Zone_Index) := US.To_Unbounded_String (Raw (Start + 1 .. Stop));
            end if;
            TZDB_Zone_Explicit_End (Zone_Index) := Last_Explicit_Transition (Raw);
         exception
            when others =>
               Add_Error ("failed to read the final tzdb rule for " & S (TZDB_Zone_Names (Zone_Index)));
         end;
      end loop;

      if TZDB_Transition_Count < 20000 then
         Add_Error ("generated tzdb transition table is unexpectedly small");
      end if;
   end Load_TZDB_Transitions;

   --  Let each zone's final rule answer from the earliest year from which it
   --  gives every offset the transitions give, through TZDB_Last_Year, and drop
   --  the transitions it makes redundant. Agreement is checked at every
   --  change of either -- each transition, each change the rule makes, a
   --  second before each, and each new year -- so between them the two agree
   --  at every instant.
   procedure Fit_TZDB_Rules is
      Kept_Zones   : array (1 .. Max_TZDB_Transitions) of Natural;
      Kept_Keys    : array (1 .. Max_TZDB_Transitions) of Long_Long_Integer;
      Kept_Offsets : array (1 .. Max_TZDB_Transitions) of Integer;
      Kept_Daylight : array (1 .. Max_TZDB_Transitions) of Boolean;
      Kept         : Natural := 0;

      function Epoch_Of (Key : Long_Long_Integer) return Long_Long_Integer is
         Second : constant Integer := Integer (Key mod 100);
         Minute : constant Integer := Integer ((Key / 100) mod 100);
         Hour   : constant Integer := Integer ((Key / 10_000) mod 100);
         Day    : constant Integer := Integer ((Key / 1_000_000) mod 100);
         Month  : constant Integer := Integer ((Key / 100_000_000) mod 100);
         Year   : constant Integer := Integer (Key / 10_000_000_000);
      begin
         return I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second);
      end Epoch_Of;
   begin
      for Zone_Index in 1 .. TZDB_Zone_Count loop
         declare
            Rule  : constant String := S (TZDB_Zone_Rules (Zone_Index));
            First : Natural := 0;
            Last  : Natural := 0;
            Valid : Boolean := False;
            From  : Integer := TZDB_Last_Year + 1;

            --  What the transitions give at an instant.
            function Table_Offset (Instant : Long_Long_Integer) return Integer is
               Result : Integer := TZDB_Zone_Initial_Offsets (Zone_Index);
            begin
               if First /= 0 then
                  for Index in First .. Last loop
                     exit when Epoch_Of (TZDB_Transition_Keys (Index)) > Instant;
                     Result := TZDB_Transition_Offsets (Index);
                  end loop;
               end if;
               return Result;
            end Table_Offset;

            function Table_Daylight (Instant : Long_Long_Integer) return Boolean is
               Result : Boolean := False;
            begin
               if First /= 0 then
                  for Index in First .. Last loop
                     exit when Epoch_Of (TZDB_Transition_Keys (Index)) > Instant;
                     Result := TZDB_Transition_Daylight (Index);
                  end loop;
               end if;
               return Result;
            end Table_Daylight;

            --  The rule gives the same offset and the same daylight state.
            function Agrees (Instant : Long_Long_Integer) return Boolean is
               Rule_Valid, Daylight_Valid : Boolean;
               Offset   : constant Integer := I18N.TZ_Rules.Offset_At (Rule, Instant, Rule_Valid);
               Daylight : constant Boolean := I18N.TZ_Rules.Daylight_At (Rule, Instant, Daylight_Valid);
            begin
               if Instant > TZDB_Zone_Explicit_End (Zone_Index) then
                  return Rule_Valid and then Daylight_Valid;
               end if;
               return Rule_Valid and then Daylight_Valid
                 and then Offset = Table_Offset (Instant)
                 and then Daylight = Table_Daylight (Instant);
            end Agrees;

            function Year_Agrees (Year : Integer) return Boolean is
               Starts, Ends : Long_Long_Integer;
               Daylight, Rule_Valid : Boolean;
            begin
               if not Agrees (I18N.TZ_Rules.Epoch_Seconds (Year, 1, 1)) then
                  return False;
               end if;
               if First /= 0 then
                  for Index in First .. Last loop
                     if Integer (TZDB_Transition_Keys (Index) / 10_000_000_000) = Year
                       and then not Agrees (Epoch_Of (TZDB_Transition_Keys (Index)))
                     then
                        return False;
                     end if;
                  end loop;
               end if;
               I18N.TZ_Rules.Changes_In (Rule, Year, Starts, Ends, Daylight, Rule_Valid);
               return Rule_Valid
                 and then (not Daylight
                           or else (Agrees (Starts) and then Agrees (Starts - 1)
                                    and then Agrees (Ends) and then Agrees (Ends - 1)));
            end Year_Agrees;
         begin
            for Index in 1 .. TZDB_Transition_Count loop
               if TZDB_Transition_Zones (Index) = Zone_Index then
                  if First = 0 then
                     First := Index;
                  end if;
                  Last := Index;
               end if;
            end loop;

            if Rule /= "" then
               declare
                  Unused : constant Integer := I18N.TZ_Rules.Offset_At (Rule, 0, Valid);
                  pragma Unreferenced (Unused);
               begin
                  null;
               end;
            end if;

            if Valid then
               for Year in reverse 1900 .. TZDB_Last_Year loop
                  exit when not Year_Agrees (Year);
                  From := Year;
               end loop;

               if From > TZDB_Last_Year then
                  --  The rule zdump itself applied does not give what zdump
                  --  wrote out: the two readings of it differ, and neither can
                  --  be trusted to answer alone.
                  Add_Error ("tzdb final rule " & Rule & " disagrees with the transitions of "
                             & S (TZDB_Zone_Names (Zone_Index)) & " in" & Integer'Image (TZDB_Last_Year));
               else
                  TZDB_Zone_Rule_From (Zone_Index) := TZDB_Key (From, 1, 1, 0, 0, 0);
               end if;
            elsif Rule /= "" then
               Add_Error ("unreadable tzdb final rule " & Rule & " for " & S (TZDB_Zone_Names (Zone_Index)));
            end if;

            if First /= 0 then
               for Index in First .. Last loop
                  if TZDB_Zone_Rule_From (Zone_Index) = 0
                    or else TZDB_Transition_Keys (Index) < TZDB_Zone_Rule_From (Zone_Index)
                  then
                     Kept := Kept + 1;
                     Kept_Zones (Kept) := Zone_Index;
                     Kept_Keys (Kept) := TZDB_Transition_Keys (Index);
                     Kept_Offsets (Kept) := TZDB_Transition_Offsets (Index);
                     Kept_Daylight (Kept) := TZDB_Transition_Daylight (Index);
                  end if;
               end loop;
            end if;
         end;
      end loop;

      TZDB_Transition_Count := Kept;
      for Index in 1 .. Kept loop
         TZDB_Transition_Zones (Index) := Kept_Zones (Index);
         TZDB_Transition_Keys (Index) := Kept_Keys (Index);
         TZDB_Transition_Offsets (Index) := Kept_Offsets (Index);
         TZDB_Transition_Daylight (Index) := Kept_Daylight (Index);
      end loop;
   end Fit_TZDB_Rules;

   function File_Equals_Content (Path : String; Content : String) return Boolean is
      use Ada.Streams;

      File       : Ada.Streams.Stream_IO.File_Type;
      Chunk_Size : constant Stream_Element_Offset := 8192;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      if Natural (Ada.Streams.Stream_IO.Size (File)) /= Content'Length then
         Ada.Streams.Stream_IO.Close (File);
         return False;
      end if;

      declare
         Buffer : Stream_Element_Array (1 .. Chunk_Size);
         Last   : Stream_Element_Offset;
         Offset : Natural := 0;
      begin
         while not Ada.Streams.Stream_IO.End_Of_File (File) loop
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            for Index in Buffer'First .. Last loop
               Offset := Offset + 1;
               if Character'Val (Buffer (Index)) /= Content (Content'First + Offset - 1) then
                  Ada.Streams.Stream_IO.Close (File);
                  return False;
               end if;
            end loop;
         end loop;
      end;

      Ada.Streams.Stream_IO.Close (File);
      return True;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end File_Equals_Content;
   pragma Unreferenced (File_Equals_Content);

   function File_Equals_File (Left_Path : String; Right_Path : String) return Boolean is
      use Ada.Streams;

      Left       : Ada.Streams.Stream_IO.File_Type;
      Right      : Ada.Streams.Stream_IO.File_Type;
      Chunk_Size : constant Stream_Element_Offset := 8192;
   begin
      Ada.Streams.Stream_IO.Open (Left, Ada.Streams.Stream_IO.In_File, Left_Path);
      Ada.Streams.Stream_IO.Open (Right, Ada.Streams.Stream_IO.In_File, Right_Path);

      if Natural (Ada.Streams.Stream_IO.Size (Left))
        /= Natural (Ada.Streams.Stream_IO.Size (Right))
      then
         Ada.Streams.Stream_IO.Close (Left);
         Ada.Streams.Stream_IO.Close (Right);
         return False;
      end if;

      declare
         Left_Buffer  : Stream_Element_Array (1 .. Chunk_Size);
         Right_Buffer : Stream_Element_Array (1 .. Chunk_Size);
         Left_Last    : Stream_Element_Offset;
         Right_Last   : Stream_Element_Offset;
      begin
         while not Ada.Streams.Stream_IO.End_Of_File (Left) loop
            Ada.Streams.Stream_IO.Read (Left, Left_Buffer, Left_Last);
            Ada.Streams.Stream_IO.Read (Right, Right_Buffer, Right_Last);
            if Left_Last /= Right_Last then
               Ada.Streams.Stream_IO.Close (Left);
               Ada.Streams.Stream_IO.Close (Right);
               return False;
            end if;

            for Index in Left_Buffer'First .. Left_Last loop
               if Left_Buffer (Index) /= Right_Buffer (Index) then
                  Ada.Streams.Stream_IO.Close (Left);
                  Ada.Streams.Stream_IO.Close (Right);
                  return False;
               end if;
            end loop;
         end loop;
      end;

      Ada.Streams.Stream_IO.Close (Left);
      Ada.Streams.Stream_IO.Close (Right);
      return True;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (Left) then
            Ada.Streams.Stream_IO.Close (Left);
         end if;
         if Ada.Streams.Stream_IO.Is_Open (Right) then
            Ada.Streams.Stream_IO.Close (Right);
         end if;
         raise;
   end File_Equals_File;

   function Is_Kind (Index : Positive; Kind : String) return Boolean is
   begin
      return S (Rules (Index).Kind) = Kind;
   end Is_Kind;

   function Duplicate_Key (Left : Rule; Right : Rule) return Boolean is
      Kind : constant String := S (Left.Kind);
   begin
      if Kind /= S (Right.Kind) then
         return False;
      elsif Kind = "decimal"
        or else Kind = "group"
        or else Kind = "digits"
        or else Kind = "currency"
        or else Kind = "currency_name_payload"
        or else Kind = "cardinal"
        or else Kind = "ordinal"
      then
         return S (Left.A) = S (Right.A);
      elsif Kind = "month_full"
        or else Kind = "month_short"
        or else Kind = "weekday_full"
        or else Kind = "weekday_short"
      then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "day_period" or else Kind = "day_period_hex" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C);
      elsif Kind = "list_separator" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C);
      elsif Kind = "unit_separator" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "unit_short" then
         return S (Left.A) = S (Right.A);
      elsif Kind = "unit_name" then
         return S (Left.A) = S (Right.A)
           and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C)
           and then S (Left.D) = S (Right.D);
      elsif Kind = "relative_current" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C);
      elsif Kind = "relative_offset" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "relative_unit_category" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C);
      elsif Kind = "relative_time_pattern" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B)
           and then S (Left.C) = S (Right.C)
           and then S (Left.D) = S (Right.D)
           and then S (Left.E) = S (Right.E);
      elsif Kind = "zone_exemplar"
        or else Kind = "zone_exemplar_hex"
      then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "available_format" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "name_set_hex" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      else
         return False;
      end if;
   end Duplicate_Key;
   pragma Unreferenced (Duplicate_Key);

   procedure Validate_Rules is
      Has_Month_Full_EN    : array (1 .. 12) of Boolean := [others => False];
      Has_Month_Short_EN   : array (1 .. 12) of Boolean := [others => False];
      Has_Weekday_Full_EN  : array (0 .. 6) of Boolean := [others => False];
      Has_Weekday_Short_EN : array (0 .. 6) of Boolean := [others => False];
   begin
      for Index in 1 .. Rule_Count loop
         if S (Rules (Index).A) = "en" and then Is_Decimal_Text (S (Rules (Index).B)) then
            declare
               Position : constant Natural := Decimal_Value (S (Rules (Index).B));
            begin
               if Is_Kind (Index, "month_full") and then Position in 1 .. 12 then
                  Has_Month_Full_EN (Position) := True;
               elsif Is_Kind (Index, "month_short") and then Position in 1 .. 12 then
                  Has_Month_Short_EN (Position) := True;
               elsif Is_Kind (Index, "weekday_full") and then Position in 0 .. 6 then
                  Has_Weekday_Full_EN (Position) := True;
               elsif Is_Kind (Index, "weekday_short") and then Position in 0 .. 6 then
                  Has_Weekday_Short_EN (Position) := True;
               end if;
            end;
         elsif Is_Kind (Index, "name_set_hex")
           and then S (Rules (Index).B) = "en"
           and then Is_Decimal_Text (S (Rules (Index).C))
         then
            declare
               Start : constant Natural := Decimal_Value (S (Rules (Index).C));
            begin
               if S (Rules (Index).A) = "month_full" and then Start = 1 then
                  for Month in 1 .. 12 loop
                     Has_Month_Full_EN (Month) := Expr_Item (S (Rules (Index).D), Month) /= "";
                  end loop;
               elsif S (Rules (Index).A) = "month_short" and then Start = 1 then
                  for Month in 1 .. 12 loop
                     Has_Month_Short_EN (Month) := Expr_Item (S (Rules (Index).D), Month) /= "";
                  end loop;
               elsif S (Rules (Index).A) = "weekday_full" and then Start = 0 then
                  for Day in 0 .. 6 loop
                     Has_Weekday_Full_EN (Day) := Expr_Item (S (Rules (Index).D), Day + 1) /= "";
                  end loop;
               elsif S (Rules (Index).A) = "weekday_short" and then Start = 0 then
                  for Day in 0 .. 6 loop
                     Has_Weekday_Short_EN (Day) := Expr_Item (S (Rules (Index).D), Day + 1) /= "";
                  end loop;
               end if;
            end;
         end if;
      end loop;

      for Month in 1 .. 12 loop
         if not Has_Month_Full_EN (Month) then
            Add_Error ("missing English month_full fallback for" & Natural'Image (Month));
         end if;
         if not Has_Month_Short_EN (Month) then
            Add_Error ("missing English month_short fallback for" & Natural'Image (Month));
         end if;
      end loop;

      for Day in 0 .. 6 loop
         if not Has_Weekday_Full_EN (Day) then
            Add_Error ("missing English weekday_full fallback for" & Natural'Image (Day));
         end if;
         if not Has_Weekday_Short_EN (Day) then
            Add_Error ("missing English weekday_short fallback for" & Natural'Image (Day));
         end if;
      end loop;
   end Validate_Rules;

   function Generate return String is
      Output       : aliased Ada.Text_IO.File_Type;
      --  L writes to whichever file is current: the main body, or a subunit while one is
      --  being emitted.
      Current_File : Ada.Text_IO.File_Access;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Current_File.all, Text);
      end L;

      --  Write the standard subunit header (L must already point at the subunit file).
      procedure Emit_Static_Prelude is
      begin
         L ("package body I18N.CLDR_Data is");
         L;
         L ("   --  Generated by cldr/src/generate_cldr_data.adb.");
         L ("   --  Source: cldr/data/cldr_subset.txt.");
         L ("   --  Large generated lookup tables intentionally do not follow");
         L ("   --  handwritten Ada style layout.");
         L ("   pragma Style_Checks (Off);");
         L;
         L ("   function U (Code : Natural) return String is");
         L ("   begin");
         L ("      if Code <= 16#7F# then");
         L ("         return [1 => Character'Val (Code)];");
         L ("      elsif Code <= 16#7FF# then");
         L ("         return");
         L ("           [1 => Character'Val (16#C0# + Code / 64),");
         L ("            2 => Character'Val (16#80# + Code mod 64)];");
         L ("      elsif Code <= 16#FFFF# then");
         L ("         return");
         L ("           [1 => Character'Val (16#E0# + Code / 4096),");
         L ("            2 => Character'Val (16#80# + (Code / 64) mod 64),");
         L ("            3 => Character'Val (16#80# + Code mod 64)];");
         L ("      else");
         L ("         return");
         L ("           [1 => Character'Val (16#F0# + Code / 262144),");
         L ("            2 => Character'Val (16#80# + (Code / 4096) mod 64),");
         L ("            3 => Character'Val (16#80# + (Code / 64) mod 64),");
         L ("            4 => Character'Val (16#80# + Code mod 64)];");
         L ("      end if;");
         L ("   end U;");
         L;
         L ("   function Lower (C : Character) return Character is");
         L ("   begin");
         L ("      if C in 'A' .. 'Z' then");
         L ("         return Character'Val (Character'Pos (C) + 32);");
         L ("      end if;");
         L;
         L ("      return C;");
         L ("   end Lower;");
         L;
         L ("   function Language (Locale : String) return String is");
         L ("      First : constant Positive := Locale'First;");
         L ("   begin");
         L ("      if Locale'Length < 2 then");
         L ("         return """";");
         L ("      end if;");
         L;
         L ("      return Locale (First .. First + 1);");
         L ("   end Language;");
         L;
         L ("   function Canonical_Locale (Locale : String) return String is");
         L ("      Buffer : String (1 .. 64) := [others => Character'Val (0)];");
         L ("      Last   : Natural := 0;");
         L ("   begin");
         L ("      for C of Locale loop");
         L ("         exit when Last = Buffer'Last;");
         L ("         if C = '_' then");
         L ("            Last := Last + 1;");
         L ("            Buffer (Last) := '-';");
         L ("         else");
         L ("            Last := Last + 1;");
         L ("            Buffer (Last) := Lower (C);");
         L ("         end if;");
         L ("      end loop;");
         L;
         L ("      if Last = 0 then");
         L ("         return """";");
         L ("      else");
         L ("         return Buffer (1 .. Last);");
         L ("      end if;");
         L ("   end Canonical_Locale;");
         L;
         L ("   function Locale_Equals (Locale : String; Candidate : String) return Boolean is");
         L ("   begin");
         L ("      return Canonical_Locale (Locale) = Canonical_Locale (Candidate);");
         L ("   end Locale_Equals;");
         L;
         L ("   function Locale_Fallback_Matches");
         L ("     (Locale    : String;");
         L ("      Candidate : String)");
         L ("      return Boolean");
         L ("   is");
         L ("      Current : String (1 .. 64) := [others => Character'Val (0)];");
         L ("      Last    : Natural := 0;");
         L ("      Target  : constant String := Canonical_Locale (Candidate);");
         L ("   begin");
         L ("      declare");
         L ("         Canonical : constant String := Canonical_Locale (Locale);");
         L ("      begin");
         L ("         if Canonical'Length = 0 then");
         L ("            return False;");
         L ("         end if;");
         L;
         L ("         Last := Natural'Min (Canonical'Length, Current'Length);");
         L ("         Current (1 .. Last) := Canonical (Canonical'First .. Canonical'First + Last - 1);");
         L ("      end;");
         L;
         L ("      loop");
         L ("         declare");
         L ("            Dash : Natural := 0;");
         L ("         begin");
         L ("            for Index in reverse 1 .. Last loop");
         L ("               if Current (Index) = '-' then");
         L ("                  Dash := Index;");
         L ("                  exit;");
         L ("               end if;");
         L ("            end loop;");
         L;
         L ("            exit when Dash = 0;");
         L ("            Last := Dash - 1;");
         L ("            if Current (1 .. Last) = Target then");
         L ("               return True;");
         L ("            end if;");
         L ("         end;");
         L ("      end loop;");
         L;
         L ("      return False;");
         L ("   end Locale_Fallback_Matches;");
         L;
         L ("   function Locale_In_List");
         L ("     (Locale           : String;");
         L ("      List             : String;");
         L ("      Include_Fallback : Boolean)");
         L ("      return Boolean");
         L ("   is");
         L ("      Start : Positive := List'First;");
         L;
         L ("      function Matches (Candidate : String) return Boolean is");
         L ("      begin");
         L ("         if Locale_Equals (Locale, Candidate) then");
         L ("            return True;");
         L ("         elsif Include_Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return False;");
         L ("         end if;");
         L ("      end Matches;");
         L ("   begin");
         L ("      for Index in List'Range loop");
         L ("         if List (Index) = ',' then");
         L ("            if Matches (List (Start .. Index - 1)) then");
         L ("               return True;");
         L ("            end if;");
         L ("            Start := Index + 1;");
         L ("         end if;");
         L ("      end loop;");
         L;
         L ("      return Matches (List (Start .. List'Last));");
         L ("   end Locale_In_List;");
      end Emit_Static_Prelude;

      procedure Emit_Week_Data is
      begin
         L;
         L ("   function First_Day_Of_Week (Locale : String) return String is");
         L ("   begin");
         L ("      if Locale_In_List");
         L ("        (Locale => Locale,");
         L ("         List =>");
         L ("           ""en-001,en-AU,en-GB,en-IE,en-IN,en-NZ,de,fr,es,it,nl,""");
         L ("           & ""pl,pt,ru,ro,lt,sl,cs,da,sv,nb,nn,fi,tr,vi,uk,bg,""");
         L ("           & ""el,hu,sk,ca,eu,af,sw,eo"",");
         L ("         Include_Fallback => True)");
         L ("      then");
         L ("         return ""mon"";");
         L ("      elsif Locale_In_List");
         L ("        (Locale => Locale,");
         L ("         List =>");
         L ("           ""ar-AE,ar-BH,ar-DJ,ar-DZ,ar-EG,ar-IQ,ar-JO,ar-KW,""");
         L ("           & ""ar-LY,ar-OM,ar-QA,ar-SD,ar-SY,ar-YE,fa-AF,fa-IR,""");
         L ("           & ""he-IL"",");
         L ("         Include_Fallback => True)");
         L ("      then");
         L ("         return ""sat"";");
         L ("      elsif Locale_In_List");
         L ("        (Locale => Locale,");
         L ("         List => ""ar-MV"",");
         L ("         Include_Fallback => True)");
         L ("      then");
         L ("         return ""fri"";");
         L ("      else");
         L ("         return ""sun"";");
         L ("      end if;");
         L ("   end First_Day_Of_Week;");
         L;
         L ("   function First_Week_Min_Days (Locale : String) return Natural is");
         L ("   begin");
         L ("      if Locale_In_List");
         L ("        (Locale => Locale,");
         L ("         List =>");
         L ("           ""en-001,en-AU,en-GB,en-IE,en-IN,en-NZ,de,fr,es,it,nl,""");
         L ("           & ""pl,pt,ru,ro,lt,sl,cs,da,sv,nb,nn,fi,tr,vi,uk,bg,""");
         L ("           & ""el,hu,sk,ca,eu,af,sw,eo"",");
         L ("         Include_Fallback => True)");
         L ("      then");
         L ("         return 4;");
         L ("      else");
         L ("         return 1;");
         L ("      end if;");
         L ("   end First_Week_Min_Days;");
      end Emit_Week_Data;

      --  The last hand-built index. It bisected the locale as written and,
      --  on a miss, walked all 766 entries calling Locale_Equals -- the same
      --  cost the shared tables shed. Onto the shared machinery it goes:
      --  canonical keys, an explicit sort, repeated segments collapsed, and
      --  the wider offset field. The locale leaves the record, since the
      --  segment says which it is.
      procedure Emit_Time_Style_Pattern is
      begin
         L;
         L ("   function Time_Style_Pattern");
         L ("     (Locale     : String;");
         L ("      Style      : String;");
         L ("      Has_Second : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang = ""ko"" then");
         L ("         if Style = ""long"" or else Style = ""full"" then");
         L ("            return ""ah':'mm':'ss"";");
         L ("         elsif Style = """" or else Style = ""medium"" then");
         L ("            return (if Has_Second then ""ah':'mm':'ss"" else ""ah':'mm"");");
         L ("         else");
         L ("            return ""ah':'mm"";");
         L ("         end if;");
         L ("      elsif Style = ""long"" or else Style = ""full"" then");
         L ("         return ""HH':'mm':'ss"";");
         L ("      elsif Style = """" or else Style = ""medium"" then");
         L ("         return (if Has_Second then ""HH':'mm':'ss"" else ""HH':'mm"");");
         L ("      else");
         L ("         return ""HH':'mm"";");
         L ("      end if;");
         L ("   end Time_Style_Pattern;");
      end Emit_Time_Style_Pattern;

      --  Two levels: a couple of dozen skeletons select a segment of the
      --  locale index, and the locale is bisected inside that segment. The
      --  chain tested up to 822 Locale_In_List calls -- one per distinct
      --  (skeleton, pattern) pair, each parsing a comma-separated locale
      --  list -- to answer a single lookup.
      procedure Emit_Date_Time_Field_Separator is
      begin
         L;
         L ("   function Date_Time_Field_Separator");
         L ("     (Locale     : String;");
         L ("      Last_Class : Character;");
         L ("      Class      : Character;");
         L ("      Last_Field : Character;");
         L ("      Field      : Character)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      if Last_Class = 'D' and then Class = 'T' then");
         L ("         return "" "";");
         L ("      elsif Class = 'T' and then Last_Class = 'T' then");
         L ("         if Field = 'S' then");
         L ("            return ""."";");
         L ("         elsif Last_Field in 'a' | 'b' | 'B' | 'z' | 'Z' | 'O'");
         L ("             | 'v' | 'V' | 'X' | 'x' | 'S' | 'A'");
         L ("           or else Field in 'a' | 'b' | 'B' | 'z' | 'Z' | 'O'");
         L ("             | 'v' | 'V' | 'X' | 'x' | 'A'");
         L ("         then");
         L ("            return "" "";");
         L ("         else");
         L ("            return "":"";");
         L ("         end if;");
         L ("      else");
         L ("         return "" "";");
         L ("      end if;");
         L ("   end Date_Time_Field_Separator;");
      end Emit_Date_Time_Field_Separator;

      procedure Emit_Date_Time_Style_Separator is
      begin
         L;
         L ("   function Date_Time_Style_Separator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return "" "";");
         L ("   end Date_Time_Style_Separator;");
      end Emit_Date_Time_Style_Separator;

      procedure Emit_Number_Display_Affixes is
      begin
         L;
         L ("   function Number_Compact_Suffix");
         L ("     (Locale    : String;");
         L ("      Scale     : Long_Long_Integer;");
         L ("      Long_Form : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang = ""ja"" or else Lang = ""zh"" then");
         L ("         if Scale = 10_000 then");
         L ("            return U (16#4E07#);");
         L ("         elsif Scale = 100_000_000 then");
         L ("            return U (16#5104#);");
         L ("         elsif Scale = 1_000_000_000_000 then");
         L ("            return U (16#5146#);");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Scale = 10_000 then");
         L ("            return U (16#B9CC#);");
         L ("         elsif Scale = 100_000_000 then");
         L ("            return U (16#C5B5#);");
         L ("         elsif Scale = 1_000_000_000_000 then");
         L ("            return U (16#C870#);");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      if Long_Form then");
         L ("         if Scale = 1_000 then");
         L ("            return "" thousand"";");
         L ("         elsif Scale = 1_000_000 then");
         L ("            return "" million"";");
         L ("         elsif Scale = 1_000_000_000 then");
         L ("            return "" billion"";");
         L ("         elsif Scale = 1_000_000_000_000 then");
         L ("            return "" trillion"";");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      else");
         L ("         if Scale = 1_000 then");
         L ("            return ""K"";");
         L ("         elsif Scale = 1_000_000 then");
         L ("            return ""M"";");
         L ("         elsif Scale = 1_000_000_000 then");
         L ("            return ""B"";");
         L ("         elsif Scale = 1_000_000_000_000 then");
         L ("            return ""T"";");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      end if;");
         L ("   end Number_Compact_Suffix;");
      end Emit_Number_Display_Affixes;

      procedure Emit_Era_Name is
      begin
         L;
         L ("   function Era_Name");
         L ("     (Locale   : String;");
         L ("      Calendar : String;");
         L ("      Era      : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Calendar = ""gregorian"" and then Era = ""ad"" then");
         L ("         if Lang = ""de"" then");
         L ("            return ""n. Chr."";");
         L ("         elsif Lang = ""fr"" then");
         L ("            return ""ap. J.-C."";");
         L ("         elsif Lang = ""es"" then");
         L ("            return ""d. C."";");
         L ("         elsif Lang = ""it"" then");
         L ("            return ""d.C."";");
         L ("         elsif Lang = ""pt"" then");
         L ("            return ""d.C."";");
         L ("         elsif Lang = ""nl"" then");
         L ("            return ""n.Chr."";");
         L ("         elsif Lang = ""ro"" then");
         L ("            return ""d.Hr."";");
         L ("         elsif Lang = ""lt"" then");
         L ("            return ""po Kr."";");
         L ("         elsif Lang = ""sl"" then");
         L ("            return ""po Kr."";");
         L ("         elsif Lang = ""pl"" then");
         L ("            return ""n.e."";");
         L ("         elsif Lang = ""cs"" then");
         L ("            return ""n. l."";");
         L ("         elsif Lang = ""ru"" then");
         L ("            return U (16#43D#) & "". "" & U (16#44D#) & ""."";");
         L ("         elsif Lang = ""ar"" then");
         L ("            return U (16#645#);");
         L ("         elsif Lang = ""ja"" then");
         L ("            return U (16#897F#) & U (16#66A6#);");
         L ("         elsif Lang = ""zh"" then");
         L ("            return U (16#516C#) & U (16#5143#);");
         L ("         elsif Lang = ""ko"" then");
         L ("            return U (16#C11C#) & U (16#AE30#);");
         L ("         else");
         L ("            return ""AD"";");
         L ("         end if;");
         L ("      elsif Calendar = ""japanese"" and then Era = ""reiwa"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#4EE4#) & U (16#548C#)");
         L ("            else ""Reiwa"");");
         L ("      elsif Calendar = ""japanese"" and then Era = ""heisei"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#5E73#) & U (16#6210#)");
         L ("            else ""Heisei"");");
         L ("      elsif Calendar = ""japanese"" and then Era = ""showa"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#662D#) & U (16#548C#)");
         L ("            else ""Showa"");");
         L ("      elsif Calendar = ""japanese"" and then Era = ""taisho"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#5927#) & U (16#6B63#)");
         L ("            else ""Taisho"");");
         L ("      elsif Calendar = ""japanese"" and then Era = ""meiji"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#660E#) & U (16#6CBB#)");
         L ("            else ""Meiji"");");
         L ("      elsif Calendar = ""japanese"" and then Era = ""keio"" then");
         L ("         return");
         L ("           (if Lang = ""ja""");
         L ("            then U (16#6176#) & U (16#5FDC#)");
         L ("            else ""Keio"");");
         L ("      elsif Calendar = ""roc"" and then Era = ""minguo"" then");
         L ("         return");
         L ("           (if Lang = ""zh""");
         L ("            then U (16#6C11#) & U (16#570B#)");
         L ("            else ""Minguo"");");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Era_Name;");
         L;
         L ("   function Era_Year_Separator");
         L ("     (Locale   : String;");
         L ("      Calendar : String)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale, Calendar);");
         L ("   begin");
         L ("      return "" "";");
         L ("   end Era_Year_Separator;");
      end Emit_Era_Name;

      procedure Emit_Unit_Separators is
      begin
         L;
         L ("   function Duration_Field_Separator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return "":"";");
         L ("   end Duration_Field_Separator;");
      end Emit_Unit_Separators;

      procedure Emit_Byte_Size_Unit_Label is
      begin
         L;
         L ("   function Byte_Size_Unit_Label (Scale : Long_Long_Integer) return String is");
         L ("   begin");
         L ("      if Scale = 1_125_899_906_842_624 then");
         L ("         return ""PiB"";");
         L ("      elsif Scale = 1_099_511_627_776 then");
         L ("         return ""TiB"";");
         L ("      elsif Scale = 1_073_741_824 then");
         L ("         return ""GiB"";");
         L ("      elsif Scale = 1_048_576 then");
         L ("         return ""MiB"";");
         L ("      elsif Scale = 1_024 then");
         L ("         return ""KiB"";");
         L ("      elsif Scale = 1 then");
         L ("         return ""B"";");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Byte_Size_Unit_Label;");
      end Emit_Byte_Size_Unit_Label;

      procedure Emit_Number_Spellout_Words is
      begin
         L;
         L ("   function Spellout_Cardinal_Under_20");
         L ("     (Locale : String;");
         L ("      Value  : Natural)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      case Value is");
         L ("         when 0 => return ""zero"";");
         L ("         when 1 => return ""one"";");
         L ("         when 2 => return ""two"";");
         L ("         when 3 => return ""three"";");
         L ("         when 4 => return ""four"";");
         L ("         when 5 => return ""five"";");
         L ("         when 6 => return ""six"";");
         L ("         when 7 => return ""seven"";");
         L ("         when 8 => return ""eight"";");
         L ("         when 9 => return ""nine"";");
         L ("         when 10 => return ""ten"";");
         L ("         when 11 => return ""eleven"";");
         L ("         when 12 => return ""twelve"";");
         L ("         when 13 => return ""thirteen"";");
         L ("         when 14 => return ""fourteen"";");
         L ("         when 15 => return ""fifteen"";");
         L ("         when 16 => return ""sixteen"";");
         L ("         when 17 => return ""seventeen"";");
         L ("         when 18 => return ""eighteen"";");
         L ("         when 19 => return ""nineteen"";");
         L ("         when others => return """";");
         L ("      end case;");
         L ("   end Spellout_Cardinal_Under_20;");
         L;
         L ("   function Spellout_Cardinal_Tens");
         L ("     (Locale : String;");
         L ("      Value  : Natural)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      case Value is");
         L ("         when 2 => return ""twenty"";");
         L ("         when 3 => return ""thirty"";");
         L ("         when 4 => return ""forty"";");
         L ("         when 5 => return ""fifty"";");
         L ("         when 6 => return ""sixty"";");
         L ("         when 7 => return ""seventy"";");
         L ("         when 8 => return ""eighty"";");
         L ("         when 9 => return ""ninety"";");
         L ("         when others => return """";");
         L ("      end case;");
         L ("   end Spellout_Cardinal_Tens;");
         L;
         L ("   function Spellout_Ordinal_Under_20");
         L ("     (Locale : String;");
         L ("      Value  : Natural)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      case Value is");
         L ("         when 0 => return ""zeroth"";");
         L ("         when 1 => return ""first"";");
         L ("         when 2 => return ""second"";");
         L ("         when 3 => return ""third"";");
         L ("         when 4 => return ""fourth"";");
         L ("         when 5 => return ""fifth"";");
         L ("         when 6 => return ""sixth"";");
         L ("         when 7 => return ""seventh"";");
         L ("         when 8 => return ""eighth"";");
         L ("         when 9 => return ""ninth"";");
         L ("         when 10 => return ""tenth"";");
         L ("         when 11 => return ""eleventh"";");
         L ("         when 12 => return ""twelfth"";");
         L ("         when 13 => return ""thirteenth"";");
         L ("         when 14 => return ""fourteenth"";");
         L ("         when 15 => return ""fifteenth"";");
         L ("         when 16 => return ""sixteenth"";");
         L ("         when 17 => return ""seventeenth"";");
         L ("         when 18 => return ""eighteenth"";");
         L ("         when 19 => return ""nineteenth"";");
         L ("         when others => return """";");
         L ("      end case;");
         L ("   end Spellout_Ordinal_Under_20;");
         L;
         L ("   function Spellout_Ordinal_Tens");
         L ("     (Locale : String;");
         L ("      Value  : Natural)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      case Value is");
         L ("         when 2 => return ""twentieth"";");
         L ("         when 3 => return ""thirtieth"";");
         L ("         when 4 => return ""fortieth"";");
         L ("         when 5 => return ""fiftieth"";");
         L ("         when 6 => return ""sixtieth"";");
         L ("         when 7 => return ""seventieth"";");
         L ("         when 8 => return ""eightieth"";");
         L ("         when 9 => return ""ninetieth"";");
         L ("         when others => return """";");
         L ("      end case;");
         L ("   end Spellout_Ordinal_Tens;");
         L;
         L ("   function Spellout_Scale_Name");
         L ("     (Locale  : String;");
         L ("      Scale   : Natural;");
         L ("      Ordinal : Boolean := False)");
         L ("      return String");
         L ("   is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      if Scale = 100 then");
         L ("         return (if Ordinal then ""hundredth"" else ""hundred"");");
         L ("      elsif Scale = 1_000 then");
         L ("         return (if Ordinal then ""thousandth"" else ""thousand"");");
         L ("      elsif Scale = 1_000_000 then");
         L ("         return (if Ordinal then ""millionth"" else ""million"");");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Spellout_Scale_Name;");
      end Emit_Number_Spellout_Words;

   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Current_File := Output'Unchecked_Access;
      Emit_Static_Prelude;
      Emit_Week_Data;
      Emit_Time_Style_Pattern;
      Emit_Date_Time_Field_Separator;
      Emit_Date_Time_Style_Separator;
      Emit_Number_Display_Affixes;
      Emit_Era_Name;
      Emit_Unit_Separators;
      Emit_Byte_Size_Unit_Label;
      Emit_Number_Spellout_Words;
      L;
      L ("end I18N.CLDR_Data;");
      Ada.Text_IO.Close (Output);
      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Output) then
            Ada.Text_IO.Close (Output);
         end if;
         raise;
   end Generate;

   --  Write the captured narrowed-out formatting rows as a Data_Store file, or
   --  remove a stale one when nothing was narrowed out.
   procedure Emit_Formats_File (Path : String) is
      procedure Sort is new Ada.Containers.Generic_Array_Sort
        (Index_Type   => Positive,
         Element_Type => Format_Entry,
         Array_Type   => Format_Entry_Array,
         "<"          => Format_Less);
      Out_F : Ada.Text_IO.File_Type;
      I     : Positive := 1;
   begin
      if Format_Count = 0 then
         if Ada.Directories.Exists (Path) then
            Ada.Directories.Delete_File (Path);
         end if;
         return;
      end if;

      Sort (Format_Entries (1 .. Format_Count));

      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Out_F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Out_F, "I18NDATA|1|" & CLDR_Version);

      while I <= Format_Count loop
         declare
            Section : constant String := S (Format_Entries (I).Section);
            J       : Positive := I;
         begin
            --  Entries are section-major after the sort; measure this run.
            while J <= Format_Count
              and then S (Format_Entries (J).Section) = Section
            loop
               J := J + 1;
            end loop;
            Ada.Text_IO.Put_Line
              (Out_F, "@" & Section & "|" & Trim (Natural'Image (J - I)));
            for K in I .. J - 1 loop
               Ada.Text_IO.Put_Line
                 (Out_F,
                  S (Format_Entries (K).Key) & ASCII.HT
                  & S (Format_Entries (K).Value));
            end loop;
            I := J;
         end;
      end loop;

      Ada.Text_IO.Close (Out_F);
   end Emit_Formats_File;

   --  Write the tz database as one Data_Store record per zone, keyed by its
   --  name in section "zone" (see I18N.Time_Zone_Data for the layout):
   --  initial offset; rule-from key; final rule; then the transitions as
   --  fixed-width YYYYMMDDhhmmss, a sign ('-' or '0') and six digits, and
   --  '1' when daylight saving time is in effect from then on, else '0'.
   procedure Emit_TZDB_File (Path : String) is
      Order : array (1 .. TZDB_Zone_Count) of Positive;
      Out_F : Ada.Text_IO.File_Type;

      function Digits_Of (Value : Long_Long_Integer; Width : Positive) return String is
         Image : constant String := Trim (Long_Long_Integer'Image (abs Value));
      begin
         return [1 .. Width - Image'Length => '0'] & Image;
      end Digits_Of;
   begin
      for Index in Order'Range loop
         Order (Index) := Index;
      end loop;
      --  By name, so the store can bisect; a few hundred zones.
      for Outer in 2 .. Order'Last loop
         declare
            Current : constant Positive := Order (Outer);
            Probe   : Natural := Outer - 1;
         begin
            while Probe >= 1
              and then S (TZDB_Zone_Names (Order (Probe))) > S (TZDB_Zone_Names (Current))
            loop
               Order (Probe + 1) := Order (Probe);
               Probe := Probe - 1;
            end loop;
            Order (Probe + 1) := Current;
         end;
      end loop;

      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Out_F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Out_F, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Out_F, "@zone|" & Trim (Natural'Image (TZDB_Zone_Count)));
      for Zone_Index of Order loop
         declare
            Value : US.Unbounded_String :=
              US.To_Unbounded_String
                (Trim (Integer'Image (TZDB_Zone_Initial_Offsets (Zone_Index)))
                 & ";" & Trim (Long_Long_Integer'Image (TZDB_Zone_Rule_From (Zone_Index)))
                 & ";" & (if TZDB_Zone_Rule_From (Zone_Index) /= 0
                          then S (TZDB_Zone_Rules (Zone_Index)) else "")
                 & ";");
         begin
            for Index in 1 .. TZDB_Transition_Count loop
               if TZDB_Transition_Zones (Index) = Zone_Index then
                  US.Append
                    (Value,
                     Digits_Of (TZDB_Transition_Keys (Index), 14)
                     & (if TZDB_Transition_Offsets (Index) < 0 then "-" else "0")
                     & Digits_Of (Long_Long_Integer (TZDB_Transition_Offsets (Index)), 6)
                     & (if TZDB_Transition_Daylight (Index) then "1" else "0"));
               end if;
            end loop;
            Ada.Text_IO.Put_Line
              (Out_F, S (TZDB_Zone_Names (Zone_Index)) & ASCII.HT & S (Value));
         end;
      end loop;

      --  The aliases, by name, each with the zone it names (Asia/Calcutta ->
      --  Asia/Kolkata).
      declare
         Links : array (1 .. TZDB_Link_Count) of Positive;
      begin
         for Index in Links'Range loop
            Links (Index) := Index;
         end loop;
         for Outer in 2 .. Links'Last loop
            declare
               Current : constant Positive := Links (Outer);
               Probe   : Natural := Outer - 1;
            begin
               while Probe >= 1
                 and then S (TZDB_Link_Names (Links (Probe))) > S (TZDB_Link_Names (Current))
               loop
                  Links (Probe + 1) := Links (Probe);
                  Probe := Probe - 1;
               end loop;
               Links (Probe + 1) := Current;
            end;
         end loop;
         Ada.Text_IO.Put_Line (Out_F, "@link|" & Trim (Natural'Image (TZDB_Link_Count)));
         for Index of Links loop
            Ada.Text_IO.Put_Line
              (Out_F, S (TZDB_Link_Names (Index)) & ASCII.HT & S (TZDB_Link_Targets (Index)));
         end loop;
      end;
      Ada.Text_IO.Close (Out_F);
   end Emit_TZDB_File;

   --  Write captured narrowed-out entries as one Data_Store file per locale
   --  under Dir (Section is the shard's single section name), or clear a stale
   --  directory when nothing was narrowed.
   procedure Emit_Shards
     (Entries : Format_Entry_Array_Access;
      Count   : Natural;
      Dir     : String;
      Section : String)
   is
      procedure Sort is new Ada.Containers.Generic_Array_Sort
        (Index_Type   => Positive,
         Element_Type => Format_Entry,
         Array_Type   => Format_Entry_Array,
         "<"          => Format_Less);
      Out_F : Ada.Text_IO.File_Type;
      I     : Positive := 1;
   begin
      --  Always start clean so a locale narrowed out last time but compiled in
      --  now does not keep a stale shard.
      if Ada.Directories.Exists (Dir) then
         Ada.Directories.Delete_Tree (Dir);
      end if;
      if Count = 0 then
         return;
      end if;

      Sort (Entries (1 .. Count));
      Ada.Directories.Create_Path (Dir);

      while I <= Count loop
         declare
            Locale : constant String := S (Entries (I).Section);
            J      : Positive := I;
         begin
            while J <= Count and then S (Entries (J).Section) = Locale loop
               J := J + 1;
            end loop;
            Ada.Text_IO.Create
              (Out_F, Ada.Text_IO.Out_File, Dir & "/" & Locale & ".i18ndata");
            Ada.Text_IO.Put_Line (Out_F, "I18NDATA|1|" & CLDR_Version);
            Ada.Text_IO.Put_Line
              (Out_F, "@" & Section & "|" & Trim (Natural'Image (J - I)));
            for K in I .. J - 1 loop
               Ada.Text_IO.Put_Line
                 (Out_F,
                  S (Entries (K).Key) & ASCII.HT & S (Entries (K).Value));
            end loop;
            Ada.Text_IO.Close (Out_F);
            I := J;
         end;
      end loop;
   end Emit_Shards;

begin
   if Has_Argument ("--help") then
      Ada.Text_IO.Put_Line
        ("usage: generate_cldr_data [--check]" & ASCII.LF
         & "Generates src/i18n-cldr_data.adb from data/cldr_subset.txt "
         & "and checked tzdb alias/transition metadata.");
      return;
   end if;

   Parse_Source;
   Add_Fixed_Formats;
   Load_TZDB_Links;
   if Errors = 0 then
      File_CLDR_Zone_Aliases;
      Load_TZDB_Transitions;
   end if;
   if Errors = 0 then
      Fit_TZDB_Rules;
   end if;
   Validate_Rules;

   if Errors /= 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   declare
      Generated : constant String := Generate;
      pragma Unreferenced (Generated);
   begin
      if Has_Argument ("--check") then
         if File_Equals_File (Generated_Path, Target_Path)
         then
            Ada.Text_IO.Put_Line ("CLDR generated data is current");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "src/i18n-cldr_data.adb is not current; run cldr/bin/generate_cldr_data");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      else
         Ada.Directories.Copy_File (Generated_Path, Target_Path);
         Emit_Formats_File (Formats_Target);
         Emit_TZDB_File (TZDB_Target);
         Emit_Shards (Unit_Entries, Unit_Count, Units_Dir, "unit");
         Emit_Shards (Zone_Entries, Zone_Count, Zones_Dir, "exemplar");
         Emit_Shards
           (Currency_Entries, Currency_Count, Currency_Dir, "currency");
         Ada.Text_IO.Put_Line ("generated src/i18n-cldr_data.adb");
      end if;
   end;
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to generate CLDR data: " & Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Generate_CLDR_Data;
