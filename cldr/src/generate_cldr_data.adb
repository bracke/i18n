with Ada.Command_Line;
with Ada.Containers.Generic_Array_Sort;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Files;
with Project_Tools.Processes;

procedure Generate_CLDR_Data is
   package US renames Ada.Strings.Unbounded;

   Source_Path : constant String := "data/cldr_subset.txt";
   TZDB_Path   : constant String := "upstream/tzdb/tzdata.zi";
   Target_Path : constant String := "../src/i18n-cldr_data.adb";
   Generated_Path : constant String := "/tmp/i18n_cldr_data.generated.adb";

   CLDR_Version : constant String := "48.2";

   --  Every locale's per-locale formatting data is written here as a
   --  Data_Store file so I18N.Locale_Data serves it on the fly; the compiled
   --  tables carry only structural data with no on-the-fly equivalent.
   Formats_Target : constant String := "../share/i18n/formats.i18ndata";
   Units_Dir      : constant String := "../share/i18n/units";
   Zones_Dir      : constant String := "../share/i18n/zones";
   Currency_Dir   : constant String := "../share/i18n/currency";

   --  The two largest lookup functions are emitted as subunits: inline they made the
   --  single body file exceed GitHub's 100 MB per-file limit, so each goes in its own
   --  source file (each well under the limit).

   --  Packed literals are wrapped one chunk to a line, and each line costs
   --  about a dozen characters of "& """ around it. At 72 that framing was
   --  2.6 MB across the generated sources -- 15% of those lines, and pure
   --  syntax. Nothing reads them by eye, and they carry Style_Checks (Off).
   --
   --  GNAT rejects a source line over 32,766 characters, so this leaves an
   --  eightfold margin; the file already holds hand-emitted lines of 2,703.
   --  Past 4096 there is only about 35 KB left to win, which is not worth
   --  spending the margin on.
   Data_Chunk : constant := 4096;

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
   Max_Unit_Entries : constant := 1_000_000;
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
   TZDB_Transition_Count : Natural := 0;
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

   --  Values were held as hex: two characters a byte. Base64 spends 1.33,
   --  is pure ASCII so -gnatW8 never sees a wide character, and its
   --  alphabet holds none of the separators the packed records use -- so a
   --  value cannot collide with a delimiter by construction rather than by
   --  audit. No padding: the index offsets already say where a value ends.
   Base64_Alphabet : constant String :=
     "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

   function To_Base64 (Bytes : String) return String is
      Result : US.Unbounded_String;
      Index  : Natural := Bytes'First;

      function Symbol (Value : Natural) return Character is
        (Base64_Alphabet (Base64_Alphabet'First + Value));
   begin
      while Index <= Bytes'Last loop
         declare
            Left : constant Natural := Bytes'Last - Index + 1;
            B0 : constant Natural := Character'Pos (Bytes (Index));
            B1 : constant Natural :=
              (if Left >= 2 then Character'Pos (Bytes (Index + 1)) else 0);
            B2 : constant Natural :=
              (if Left >= 3 then Character'Pos (Bytes (Index + 2)) else 0);
         begin
            US.Append (Result, Symbol (B0 / 4));
            US.Append (Result, Symbol ((B0 mod 4) * 16 + B1 / 16));
            if Left >= 2 then
               US.Append (Result, Symbol ((B1 mod 16) * 4 + B2 / 64));
            end if;
            if Left >= 3 then
               US.Append (Result, Symbol (B2 mod 64));
            end if;
            Index := Index + 3;
         end;
      end loop;

      return S (Result);
   end To_Base64;

   --  Rows that arrive already hex-encoded, a byte to two characters.
   function Hex_Bytes_To_Base64 (Hex : String) return String is
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

      return To_Base64 (Bytes);
   end Hex_Bytes_To_Base64;

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

   --  Codes and base-62 offsets share one alphabet.
   Code_Alphabet : constant String :=
     "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

   --  Offsets as base 62 rather than eight decimal digits: five characters
   --  reach 916 million, and the alphabet is the one the labels already use.
   function To_Base62 (Value : Natural; Width : Positive) return String is
      Result : String (1 .. Width);
      Left   : Natural := Value;
   begin
      for Index in reverse Result'Range loop
         Result (Index) :=
           Code_Alphabet (Code_Alphabet'First + Left mod 62);
         Left := Left / 62;
      end loop;

      if Left /= 0 then
         Add_Error ("offset outgrew the index field");
      end if;

      return Result;
   end To_Base62;

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

   function Ada_Expression_UTF8_Hex (Expr : String) return String is
     (Hex_Bytes_To_Base64 (Ada_Expression_UTF8_Hex_Digits (Expr)));

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
      elsif Kind = "zone_display" and then Capture_Locale (A) then
         --  A=locale, B=zone id, C=display name.
         Add_Format
           ("zone_display", A, Ada_Expression_UTF8_Bytes (C), Sub => B);
      elsif Kind = "zone_family_display" and then Capture_Locale (A) then
         --  A=locale, B=metazone family, C=long name.
         Add_Format
           ("zone_family_display", A, Ada_Expression_UTF8_Bytes (C),
            Sub => B);
      elsif Kind = "zone_exemplar" and then Capture_Locale (A) then
         --  A=locale, B=zone id, C=exemplar city (Ada expression).
         Zone_Add (A, B, Ada_Expression_UTF8_Bytes (C));
      elsif Kind = "zone_exemplar_hex" and then Capture_Locale (A) then
         --  A=locale, B=zone id, C=exemplar city (raw hex bytes).
         Zone_Add (A, B, Hex_Bytes_To_String (C));
      elsif Kind = "zone_short_family" and then Capture_Locale (A) then
         --  A=locale, B=metazone family, C=standard, D=daylight, E=generic.
         Add_Format
           ("zone_short_std", A, Ada_Expression_UTF8_Bytes (C), Sub => B);
         Add_Format
           ("zone_short_dst", A, Ada_Expression_UTF8_Bytes (D), Sub => B);
         Add_Format
           ("zone_short_generic", A, Ada_Expression_UTF8_Bytes (E),
            Sub => B);
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

      function Is_Zone_Family (Value : String) return Boolean is
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
      end Is_Zone_Family;
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
           or else not Contains (Field (Line, 7), "{0}")
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
      elsif Kind = "zone_display" or else Kind = "zone_exemplar" then
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
      elsif Kind = "zone_family_display" then
         if Field_Count (Line) /= 4
           or else Field (Line, 2) = ""
           or else not Is_Zone_Family (Field (Line, 3))
           or else Field (Line, 4) = ""
         then
            Add_Line_Error (Line_Number, "invalid zone_family_display row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4));
      elsif Kind = "zone_short_family" then
         if Field_Count (Line) /= 6
           or else Field (Line, 2) = ""
           or else not Is_Zone_Family (Field (Line, 3))
           or else Field (Line, 4) = ""
           or else Field (Line, 5) = ""
           or else Field (Line, 6) = ""
         then
            Add_Line_Error (Line_Number, "invalid zone_short_family row shape");
         end if;
         Add_Rule
           (Kind,
            Field (Line, 2),
            Field (Line, 3),
            Field (Line, 4),
            Field (Line, 5),
            Field (Line, 6));
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
      Offset     : Integer)
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
   end Add_TZDB_Transition;

   procedure Load_TZDB_Transitions is

      Zic   : constant String := Project_Tools.Processes.Locate_Command ("zic");
      ZDump : constant String := Project_Tools.Processes.Locate_Command ("zdump");
      Out_Dir : constant String := "/tmp/i18n_tzdb_generated";

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
                        Year        : constant Natural := Decimal_Value (Year_Text);
                        Month       : constant Natural := Month_Number (Month_Text);
                        Day         : constant Natural := Decimal_Value (Day_Text);
                        Hour        : constant Natural :=
                          Decimal_Value (Field (Time_Text, 1, ':'));
                        Minute      : constant Natural :=
                          Decimal_Value (Field (Time_Text, 2, ':'));
                        Second      : constant Natural :=
                          Decimal_Value (Field (Time_Text, 3, ':'));
                        Offset      : constant Integer :=
                          Signed_Decimal_Value (Offset_Text);
                     begin
                        if Year in 1900 .. 2050
                          and then Month in 1 .. 12
                          and then Day in 1 .. 31
                          and then Hour <= 23
                          and then Minute <= 59
                          and then Second <= 60
                        then
                           Add_TZDB_Transition
                             (Zone_Index,
                              TZDB_Key (Year, Month, Day, Hour, Minute, Second),
                              Offset);
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
           [new String'("-d"), new String'(Out_Dir), new String'(TZDB_Path)];
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
            Zone_Path : constant String := Out_Dir & "/" & S (TZDB_Zone_Names (Zone_Index));
            Output    : US.Unbounded_String;
            Args_I    : constant GNAT.OS_Lib.Argument_List (1 .. 4) :=
              [new String'("-i"), new String'("-c"), new String'("1900,2051"),
               new String'(Zone_Path)];
            Args_V    : constant GNAT.OS_Lib.Argument_List (1 .. 4) :=
              [new String'("-v"), new String'("-c"), new String'("1900,2051"),
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

      if TZDB_Transition_Count < 20000 then
         Add_Error ("generated tzdb transition table is unexpectedly small");
      end if;
   end Load_TZDB_Transitions;

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
      elsif Kind = "zone_display"
        or else Kind = "zone_exemplar"
        or else Kind = "zone_exemplar_hex"
      then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "zone_family_display" then
         return S (Left.A) = S (Right.A) and then S (Left.B) = S (Right.B);
      elsif Kind = "zone_short_family" then
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
         L ("   type Codepoint_Array is array (Positive range <>) of Natural;");
         L;
         L ("   function UTF8 (Codes : Codepoint_Array) return String is");
         L ("   begin");
         L ("      if Codes'Length = 0 then");
         L ("         return """";");
         L ("      elsif Codes'Length = 1 then");
         L ("         return U (Codes (Codes'First));");
         L ("      else");
         L ("         return");
         L ("           U (Codes (Codes'First))");
         L ("           & UTF8 (Codes (Codes'First + 1 .. Codes'Last));");
         L ("      end if;");
         L ("   end UTF8;");
         L;
         L ("   function B62_Value (C : Character) return Natural is");
         L ("     (if C in 'a' .. 'z' then Character'Pos (C) - Character'Pos ('a')");
         L ("      elsif C in 'A' .. 'Z'");
         L ("      then 26 + Character'Pos (C) - Character'Pos ('A')");
         L ("      else 52 + Character'Pos (C) - Character'Pos ('0'));");
         L;
         L ("   function N62 (Text : String) return Natural is");
         L ("      Value : Natural := 0;");
         L ("   begin");
         L ("      for C of Text loop");
         L ("         Value := Value * 62 + B62_Value (C);");
         L ("      end loop;");
         L;
         L ("      return Value;");
         L ("   end N62;");
         L;
         L ("   --  Values are base64 of UTF-8 bytes, without padding: the");
         L ("   --  offsets and the separators already say where one ends.");
         L ("   function B64_Value (C : Character) return Natural is");
         L ("     (if C in 'A' .. 'Z' then Character'Pos (C) - Character'Pos ('A')");
         L ("      elsif C in 'a' .. 'z'");
         L ("      then 26 + Character'Pos (C) - Character'Pos ('a')");
         L ("      elsif C in '0' .. '9'");
         L ("      then 52 + Character'Pos (C) - Character'Pos ('0')");
         L ("      elsif C = '+' then 62");
         L ("      else 63);");
         L;
         L ("   function VB (Text : String) return String is");
         L ("      Result : String (1 .. Text'Length * 3 / 4);");
         L ("      Filled : Natural := 0;");
         L ("      Index : Natural := Text'First;");
         L ("   begin");
         L ("      while Index <= Text'Last loop");
         L ("         declare");
         L ("            Left : constant Natural := Text'Last - Index + 1;");
         L ("            C0 : constant Natural := B64_Value (Text (Index));");
         L ("            C1 : constant Natural :=");
         L ("              (if Left >= 2 then B64_Value (Text (Index + 1)) else 0);");
         L ("            C2 : constant Natural :=");
         L ("              (if Left >= 3 then B64_Value (Text (Index + 2)) else 0);");
         L ("            C3 : constant Natural :=");
         L ("              (if Left >= 4 then B64_Value (Text (Index + 3)) else 0);");
         L ("         begin");
         L ("            exit when Left < 2;");
         L ("            Filled := Filled + 1;");
         L ("            Result (Filled) := Character'Val (C0 * 4 + C1 / 16);");
         L ("            if Left >= 3 then");
         L ("               Filled := Filled + 1;");
         L ("               Result (Filled) :=");
         L ("                 Character'Val ((C1 mod 16) * 16 + C2 / 4);");
         L ("            end if;");
         L ("            if Left >= 4 then");
         L ("               Filled := Filled + 1;");
         L ("               Result (Filled) :=");
         L ("                 Character'Val ((C2 mod 4) * 64 + C3);");
         L ("            end if;");
         L ("            Index := Index + 4;");
         L ("         end;");
         L ("      end loop;");
         L;
         L ("      return Result (1 .. Filled);");
         L ("   end VB;");
         L;
         L ("   function Contains (Text : String; Fragment : String) return Boolean is");
         L ("   begin");
         L ("      if Fragment'Length = 0 or else Text'Length < Fragment'Length then");
         L ("         return False;");
         L ("      end if;");
         L;
         L ("      for Index in Text'First .. Text'Last - Fragment'Length + 1 loop");
         L ("         if Text (Index .. Index + Fragment'Length - 1) = Fragment then");
         L ("            return True;");
         L ("         end if;");
         L ("      end loop;");
         L;
         L ("      return False;");
         L ("   end Contains;");
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
         L ("   function In_List (Value : String; List : String) return Boolean is");
         L ("      Start : Positive := List'First;");
         L ("   begin");
         L ("      for Index in List'Range loop");
         L ("         if List (Index) = ',' then");
         L ("            if Value = List (Start .. Index - 1) then");
         L ("               return True;");
         L ("            end if;");
         L ("            Start := Index + 1;");
         L ("         end if;");
         L ("      end loop;");
         L;
         L ("      return Value = List (Start .. List'Last);");
         L ("   end In_List;");
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

      --  Entries for a bisected locale table, shared by the tables below.
      --  Collected here so the sort and the packing are written once rather
      --  than once per emitter.
      Max_Table_Entries : constant := 20_000;

      --  A 14-character key and two 5-character base-62 offsets, which
      --  reach 916 million; To_Base62 says so if that is ever not enough.
      Index_Record_Width : constant := 24;

      type Table_Entry is record
         Key   : US.Unbounded_String;
         --  Hex, as HB decodes it in the generated body.
         Value : US.Unbounded_String;
         First : Natural := 0;
         Last  : Natural := 0;
      end record;

      type Table_Entry_Array is array (Positive range <>) of Table_Entry;
      type Table_Entry_Array_Access is access Table_Entry_Array;

      Table_Entries : constant Table_Entry_Array_Access :=
        new Table_Entry_Array (1 .. Max_Table_Entries);
      Table_Entry_Count : Natural := 0;

      --  The same rule as Canonical_Locale in the generated body. Keys are
      --  stored this way so that a lookup canonicalises its argument once
      --  and bisects, rather than bisecting the spelling as written and
      --  walking the whole table when that misses -- which it does for
      --  every locale a table does not hold, and Digit_Text asks once per
      --  digit of every number it formats.
      function Canonical_Key (Value : String) return String is
         Result : String (Value'Range);
      begin
         for Index in Value'Range loop
            if Value (Index) = '_' then
               Result (Index) := '-';
            elsif Value (Index) in 'A' .. 'Z' then
               Result (Index) :=
                 Character'Val (Character'Pos (Value (Index)) + 32);
            else
               Result (Index) := Value (Index);
            end if;
         end loop;

         return Result;
      end Canonical_Key;

      function Padded_Key (Value : String) return String is
        (if Value'Length >= 14 then Value (Value'First .. Value'First + 13)
         else Value & (1 .. 14 - Value'Length => ' '));

      function Key_Less (Left, Right : Table_Entry) return Boolean is
        (Padded_Key (S (Left.Key)) < Padded_Key (S (Right.Key)));

      procedure Sort_Entries is new Ada.Containers.Generic_Array_Sort
        (Index_Type   => Positive,
         Element_Type => Table_Entry,
         Array_Type   => Table_Entry_Array,
         "<"          => Key_Less);

      procedure Reset_Table is
      begin
         Table_Entry_Count := 0;
      end Reset_Table;

      procedure Add_Table_Entry (Key : String; Value : String) is
      begin
         if Key'Length = 0 or else Key'Length > 14 then
            Add_Error ("locale key does not fit the index: " & Key);
            return;
         elsif Table_Entry_Count = Max_Table_Entries then
            Add_Error ("too many entries for a locale table");
            return;
         end if;

         Table_Entry_Count := Table_Entry_Count + 1;
         Table_Entries (Table_Entry_Count) :=
           (Key   => US.To_Unbounded_String (Canonical_Key (Key)),
            Value => US.To_Unbounded_String (Value),
            First => 0,
            Last  => 0);
      end Add_Table_Entry;

      --  Labels repeat far more than the text they describe:
      --  "unit-width-full-name" is twenty characters for one of three
      --  values, and a zone name thirty for one of 419. Each becomes a code
      --  in the record, which the body maps its argument to once per call.
      Max_Labels : constant := 1024;
      type Label_Array is array (1 .. Max_Labels) of US.Unbounded_String;

      procedure Collect_Labels
        (Kind  : String;
         Field : Positive;
         Names : out Label_Array;
         Count : out Natural)
      is
      begin
         Count := 0;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind) then
               declare
                  Value : constant String :=
                    (case Field is
                        when 2 => S (Rules (Index).B),
                        when 3 => S (Rules (Index).C),
                        when 4 => S (Rules (Index).D),
                        when 5 => S (Rules (Index).E),
                        when others => S (Rules (Index).F));
                  Seen : Boolean := False;
               begin
                  for Position in 1 .. Count loop
                     if S (Names (Position)) = Value then
                        Seen := True;
                        exit;
                     end if;
                  end loop;

                  if not Seen then
                     if Count = Max_Labels then
                        Add_Error ("too many labels for " & Kind);
                     else
                        Count := Count + 1;
                        Names (Count) := US.To_Unbounded_String (Value);
                     end if;
                  end if;
               end;
            end if;
         end loop;

         --  Sorted, so a bisected index over them is possible.
         for Outer in 2 .. Count loop
            declare
               Current : constant US.Unbounded_String := Names (Outer);
               Probe : Natural := Outer - 1;
            begin
               while Probe >= 1 and then S (Names (Probe)) > S (Current) loop
                  Names (Probe + 1) := Names (Probe);
                  Probe := Probe - 1;
               end loop;
               Names (Probe + 1) := Current;
            end;
         end loop;
      end Collect_Labels;

      function Label_Code
        (Names : Label_Array;
         Count : Natural;
         Value : String;
         Width : Positive)
         return String
      is
      begin
         for Position in 1 .. Count loop
            if S (Names (Position)) = Value then
               if Width = 1 then
                  return [1 => Code_Alphabet
                                 (Code_Alphabet'First + Position - 1)];
               else
                  return
                    [1 => Code_Alphabet
                            (Code_Alphabet'First + (Position - 1) / 62),
                     2 => Code_Alphabet
                            (Code_Alphabet'First + (Position - 1) mod 62)];
               end if;
            end if;
         end loop;

         return [1 .. Width => ' '];
      end Label_Code;

      --  A chain, for a handful of labels. Anything unmatched codes as
      --  blanks and so matches no record, which is what comparing an
      --  unrecognised name did before.
      procedure Emit_Label_Chain
        (Function_Name : String;
         Argument      : String;
         Names         : Label_Array;
         Count         : Natural;
         Width         : Positive)
      is
      begin
         L ("      function " & Function_Name & " return String is");
         for Position in 1 .. Count loop
            L ("        " & (if Position = 1 then "(if" else " elsif")
               & " " & Argument & " = """ & S (Names (Position)) & """ then """
               & Label_Code (Names, Count, S (Names (Position)), Width) & """");
         end loop;
         L ("         else """ & (1 .. Width => ' ') & """);");
      end Emit_Label_Chain;

      procedure Emit_Unit_String_Expression
        (Indent : String;
         Value  : String;
         Suffix : String := "")
      is
         Chunk : constant := Data_Chunk;
         Start : Positive := Value'First;
         Stop  : Natural;
         Term  : Positive := 1;
      begin
         if Value'Length = 0 then
            L (Indent & """""" & Suffix);
            return;
         end if;

         while Start <= Value'Last loop
            Stop := Natural'Min (Start + Chunk - 1, Value'Last);
            L (Indent & (if Term = 1 then "" else "& ")
               & """" & Value (Start .. Stop) & """"
               & (if Stop = Value'Last then Suffix else ""));
            Start := Stop + 1;
            Term := Term + 1;
         end loop;
      end Emit_Unit_String_Expression;

      --  419 zone names, too many for a chain, so a bisected index of
      --  padded name to code -- the same shape the unit bases use.
      --  Sort the collected entries and append them to a packed value string
      --  and a fixed-width index. Both are in out, so a table built in
      --  several passes -- one per skeleton, say -- shares one value string
      --  and one index, and a repeat found in an earlier pass still costs
      --  nothing.
      procedure Pack_Table
        (Values     : in out US.Unbounded_String;
         Index_Data : in out US.Unbounded_String)
      is
      begin
         --  Bisection needs the padded keys in order, and rows do not always
         --  arrive that way: a rule family lists its locales, so exploding it
         --  yields keys in family order.
         Sort_Entries (Table_Entries (1 .. Table_Entry_Count));

         for N in 1 .. Table_Entry_Count loop
            declare
               Key : constant String := S (Table_Entries (N).Key);
               Hex : constant String := S (Table_Entries (N).Value);
            begin
               --  Values repeat heavily -- a rule family has a handful of
               --  distinct names across hundreds of locales -- so point a
               --  repeat at the copy already packed.
               --  Compared unbounded, not as String: converting each prior
               --  value to compare it copies the whole thing, and a segment
               --  of relative patterns runs to several kilobytes.
               for Prior in 1 .. N - 1 loop
                  if US."=" (Table_Entries (Prior).Value,
                             Table_Entries (N).Value)
                  then
                     Table_Entries (N).First := Table_Entries (Prior).First;
                     Table_Entries (N).Last := Table_Entries (Prior).Last;
                     exit;
                  end if;
               end loop;

               if Table_Entries (N).First = 0 then
                  Table_Entries (N).First := US.Length (Values) + 1;
                  Table_Entries (N).Last :=
                    US.Length (Values) + Hex'Length;
                  US.Append (Values, Hex);
               end if;

               declare
                  First : constant String :=
                    To_Base62 (Table_Entries (N).First, 5);
                  Last : constant String :=
                    To_Base62 (Table_Entries (N).Last, 5);
               begin
                  --  Same fixed-width record and the same space-pad rule as
                  --  the date-pattern index: the pad must sort below '-'.
                  --
                  --  Eight digits, not seven: the unit names pack eleven
                  --  million characters of values, and a seven-digit field
                  --  silently widens to eight rather than truncating, which
                  --  shifts every record after it.
                  US.Append (Index_Data, Key);
                  US.Append (Index_Data, [1 .. 14 - Key'Length => ' ']);
                  US.Append (Index_Data, First);
                  US.Append (Index_Data, Last);
               end;
            end;
         end loop;
      end Pack_Table;

      --  A locale-keyed value as a table rather than a chain. The chain form
      --  emitted two branches per locale -- exact, then fallback -- so a
      --  lookup walked up to 1,532 Locale_In_List calls, each canonicalising
      --  both strings before comparing. The table is bisected instead, and the
      --  same 6 KB-per-766-locales trade as the date-pattern index applies.
      --  Raw leaves the packed value alone instead of decoding it as hex: a
      --  value that is already an encoded blob, as the date-name rows are,
      --  would otherwise be hex-encoded a second time and stored at twice
      --  the size for nothing.
      --  Walk_Parents off stops at an exact match. A caller whose rows are
      --  keyed on more than the locale needs the walk itself, so that it can
      --  retest the row's contents at each parent rather than settle for the
      --  nearest locale that has any row at all.
      procedure Emit_Locale_Table
        (Name         : String;
         Default_Expr : String;
         Raw          : Boolean := False;
         Walk_Parents : Boolean := True)
      is
         Values : US.Unbounded_String;
         Index_Data : US.Unbounded_String;

         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk : constant := Data_Chunk;
            Start : Positive := Value'First;
            Stop  : Natural;
            Term  : Positive := 1;
         begin
            if Value'Length = 0 then
               L (Indent & """""" & Suffix);
               return;
            end if;
            while Start <= Value'Last loop
               Stop := Natural'Min (Start + Chunk - 1, Value'Last);
               L (Indent & (if Term = 1 then "" else "& ")
                  & """" & Value (Start .. Stop) & """"
                  & (if Stop = Value'Last then Suffix else ""));
               Start := Stop + 1;
               Term := Term + 1;
            end loop;
         end Emit_String_Expression;
      begin
         Pack_Table (Values, Index_Data);

         L;
         L ("   function " & Name & " (Locale : String) return String is");
         L ("      Values : constant String :=");
         Emit_String_Expression ("        ", S (Values), ";");
         L ("      Index_Data : constant String :=");
         Emit_String_Expression ("        ", S (Index_Data), ";");
         L ("      Width : constant := " & Trim (Integer'Image (Index_Record_Width)) & ";");
         L ("      Count : constant Natural := Index_Data'Length / Width;");
         L;
         L ("      function Key (N : Positive) return String is");
         L ("        (Index_Data (Index_Data'First + (N - 1) * Width ..");
         L ("                     Index_Data'First + (N - 1) * Width + 13));");
         L;
         L ("      function Padded (Cand : String) return String is");
         L ("        (if Cand'Length >= 14 then Cand (Cand'First .. Cand'First + 13)");
         L ("         else Cand & [1 .. 14 - Cand'Length => ' ']);");
         L;
         L ("      function Value_At (N : Positive) return String is");
         L ("         Base : constant Natural :=");
         L ("           Index_Data'First + (N - 1) * Width + 14;");
         L ("         F : constant Natural :=");
         L ("           N62 (Index_Data (Base .. Base + 4));");
         L ("         T : constant Natural :=");
         L ("           N62 (Index_Data (Base + 5 .. Base + 9));");
         L ("      begin");
         if Raw then
            L ("         return Values (F .. T);");
         else
            L ("         return VB (Values (F .. T));");
         end if;
         L ("      end Value_At;");
         L;
         L ("      --  Keys are stored canonical, so canonicalise once and");
         L ("      --  bisect. Nothing walks: a locale the table does not hold");
         L ("      --  costs the same handful of comparisons as one it does.");
         L ("      function Lookup (Cand : String) return String is");
         L ("         Low : Natural := 1;");
         L ("         High : Natural := Count;");
         L ("         Mid : Natural;");
         L ("      begin");
         --  No "Count = 0" disjunct: an empty table leaves High at 0, so the
         --  loop below already answers "" without it -- and where the table is
         --  non-empty (a static literal), GNAT flags the test as always False.
         L ("         if Cand'Length = 0 then");
         L ("            return """";");
         L ("         end if;");
         L;
         L ("         declare");
         L ("            Wanted : constant String :=");
         L ("              Padded (Canonical_Locale (Cand));");
         L ("         begin");
         L ("            while Low <= High loop");
         L ("               Mid := (Low + High) / 2;");
         L ("               if Key (Mid) = Wanted then");
         L ("                  return Value_At (Mid);");
         L ("               elsif Key (Mid) < Wanted then");
         L ("                  Low := Mid + 1;");
         L ("               else");
         L ("                  High := Mid - 1;");
         L ("               end if;");
         L ("            end loop;");
         L ("         end;");
         L ("         return """";");
         L ("      end Lookup;");

         L;
         if not Walk_Parents then
            L ("      Exact : constant String := Lookup (Locale);");
            L ("   begin");
            L ("      if Exact /= """" then");
            L ("         return Exact;");
            L ("      end if;");
            L;
            L ("      return " & Default_Expr & ";");
            L ("   end " & Name & ";");
            return;
         end if;

         L ("      --  Parents are cut from the canonical spelling: ""de_AT"" has");
         L ("      --  no '-' to cut, and would otherwise lose its fallback.");
         L ("      Canon : constant String := Canonical_Locale (Locale);");
         L ("      Exact : constant String := Lookup (Locale);");
         L ("      Cut : Natural := Canon'Last;");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      --  Then each parent, which is what the fallback pass did.");
         L ("      while Cut > Canon'First loop");
         L ("         if Canon (Cut) = '-' then");
         L ("            declare");
         L ("               Hit : constant String :=");
         L ("                 Lookup (Canon (Canon'First .. Cut - 1));");
         L ("            begin");
         L ("               if Hit /= """" then");
         L ("                  return Hit;");
         L ("               end if;");
         L ("            end;");
         L ("         end if;");
         L ("         Cut := Cut - 1;");
         L ("      end loop;");
         L;
         L ("      return " & Default_Expr & ";");
         L ("   end " & Name & ";");
      end Emit_Locale_Table;

      --  The same table for rows that need more than the kind to select them
      --  and keep their value in a later field: a list separator is picked by
      --  family and part, and several families share one kind.
      --  Rows selected by family alone, with the value in one of the two
      --  fields after it: a relative offset keeps its prefix in one and its
      --  suffix in the other, and each becomes its own table.
      procedure Emit_Family_Locale_Table
        (Name         : String;
         Kind         : String;
         Family       : String;
         Default_Expr : String;
         Value_Field  : Character := 'C')
      is
      begin
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind)
              and then S (Rules (Index).B) = Family
            then
               Add_Table_Entry
                 (S (Rules (Index).A),
                  Ada_Expression_UTF8_Hex
                    (if Value_Field = 'D'
                     then S (Rules (Index).D)
                     else S (Rules (Index).C)));
            end if;
         end loop;
         Emit_Locale_Table (Name, Default_Expr);
      end Emit_Family_Locale_Table;

      --  One row per locale: the key is the locale, the value the row's text.
      procedure Emit_Locale_Return_Table
        (Name         : String;
         Kind         : String;
         Default_Expr : String)
      is
      begin
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind) then
               Add_Table_Entry
                 (S (Rules (Index).A),
                  Ada_Expression_UTF8_Hex (S (Rules (Index).B)));
            end if;
         end loop;
         Emit_Locale_Table (Name, Default_Expr);
      end Emit_Locale_Return_Table;

      procedure Emit_Grouping is
         Has_Row : Boolean := False;
      begin
         for Index in 1 .. Rule_Count loop
            Has_Row := Has_Row or else Is_Kind (Index, "indian_grouping");
         end loop;
         L;
         L ("   function Uses_Indian_Grouping (Locale : String) return Boolean is");
         --  Narrowing may drop every row, leaving Locale unused below.
         if not Has_Row then
            L ("      pragma Unreferenced (Locale);");
         end if;
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "indian_grouping") then
               L ("      if In_List (Language (Locale), """ & S (Rules (Index).A) & """)");
               L ("        or else Contains (Locale, """ & S (Rules (Index).B) & """)");
               L ("      then");
               L ("         return True;");
               L ("      end if;");
            end if;
         end loop;
         L ("      return False;");
         L ("   end Uses_Indian_Grouping;");
      end Emit_Grouping;

      procedure Emit_Day_Month_Year is
         Has_Row : Boolean := False;
      begin
         for Index in 1 .. Rule_Count loop
            Has_Row := Has_Row or else Is_Kind (Index, "day_month_year");
         end loop;
         L;
         L ("   function Uses_Day_Month_Year (Locale : String) return Boolean is");
         --  Narrowing may drop every row, leaving Locale unused below.
         if not Has_Row then
            L ("      pragma Unreferenced (Locale);");
         end if;
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "day_month_year") then
               L ("      if In_List (Language (Locale), """ & S (Rules (Index).A) & """) then");
               L ("         return True;");
               L ("      end if;");
            end if;
         end loop;
         L ("      return False;");
         L ("   end Uses_Day_Month_Year;");
      end Emit_Day_Month_Year;

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

      procedure Emit_Digits is
         First : Boolean := True;

         procedure Emit_Digit_Case (Index : Positive) is
         begin
            L ("         case Digit is");
            for Digit in 0 .. 9 loop
               L ("            when '"
                  & Character'Val (Character'Pos ('0') + Digit)
                  & "' => return U ("
                  & Field (S (Rules (Index).B), Digit + 1, ',') & ");");
            end loop;
            L ("            when others => return [1 => Digit];");
            L ("         end case;");
            First := False;
         end Emit_Digit_Case;
         --  One row per locale, ten digits of four bytes each. The digits of
         --  a numbering system are not always contiguous, so all ten are
         --  stored; padding them to a fixed width keeps the row sliceable,
         --  and UTF-8 never contains a NUL, so the pad strips unambiguously.
         function Digit_Row_Hex (Index : Positive) return String is
            Row : US.Unbounded_String;
         begin
            --  Ten digits of four NUL-padded bytes each. The row is one
            --  value, so Value_At decodes it once and the reader below
            --  slices bytes, as it always did.
            declare
               Bytes : US.Unbounded_String;
            begin
               for Digit in 0 .. 9 loop
                  declare
                     Text : constant String :=
                       Ada_Expression_UTF8_Bytes
                         ("U (" & Field (S (Rules (Index).B), Digit + 1, ',')
                          & ")");
                     Padded : String (1 .. 4) := [others => Character'Val (0)];
                  begin
                     if Text'Length > 4 then
                        Add_Error ("digit does not fit four bytes");
                     else
                        Padded (1 .. Text'Length) := Text;
                     end if;
                     US.Append (Bytes, Padded);
                  end;
               end loop;

               US.Append (Row, To_Base64 (S (Bytes)));
            end;

            return S (Row);
         end Digit_Row_Hex;
      begin
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "digits")
              and then not Starts_With (S (Rules (Index).A), "nu-")
            then
               declare
                  Locales : constant String := S (Rules (Index).A);
                  Row : constant String := Digit_Row_Hex (Index);
                  Start : Positive := Locales'First;
               begin
                  for Position in Locales'Range loop
                     if Locales (Position) = ',' then
                        Add_Table_Entry (Locales (Start .. Position - 1), Row);
                        Start := Position + 1;
                     end if;
                  end loop;

                  if Start <= Locales'Last then
                     Add_Table_Entry (Locales (Start .. Locales'Last), Row);
                  end if;
               end;
            end if;
         end loop;
         Emit_Locale_Table ("Digit_Row", """""");

         L;
         L ("   function Digit_Text (Locale : String; Digit : Character) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      --  A locale either carries a numbering-system override or it");
         L ("      --  does not. Testing that once skips the whole chain for the");
         L ("      --  locales that do not, which is nearly all of them, and");
         L ("      --  Digit_Text is asked once per digit of every number.");
         L ("      if Contains (Locale, ""-u-nu-"")");
         L ("        or else Contains (Locale, ""@numbers="")");
         L ("      then");
         L ("         if Contains (Locale, ""-u-nu-latn"")");
         L ("           or else Contains (Locale, ""@numbers=latn"")");
         L ("         then");
         L ("            return [1 => Digit];");
         First := False;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "digits")
              and then Starts_With (S (Rules (Index).A), "nu-")
            then
               declare
                  Key : constant String := S (Rules (Index).A);
                  Number_System : constant String :=
                    Key (Key'First + 3 .. Key'Last);
               begin
                  L ("         " & (if First then "if" else "elsif")
                     & " Contains (Locale, ""-u-" & Key & """)");
                  L ("           or else Contains (Locale, ""@numbers="
                     & Number_System & """)");
                  L ("         then");
               end;
               Emit_Digit_Case (Index);
            end if;
         end loop;
         L ("         end if;");
         L ("      end if;");
         L;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "digits")
              and then S (Rules (Index).A) = "nu-beng"
            then
               L ("      if Lang = ""bn"" then");
               Emit_Digit_Case (Index);
               L ("      end if;");
               L;
            end if;
         end loop;
         L ("      declare");
         L ("         Row : constant String := Digit_Row (Locale);");
         L ("      begin");
         L ("         --  Digit_Row is decoded by its own Value_At, so Row is");
         L ("         --  already the forty bytes: ten digits of four.");
         L ("         if Row'Length = 40 and then Digit in '0' .. '9' then");
         L ("            declare");
         L ("               Base : constant Natural :=");
         L ("                 Row'First");
         L ("                   + (Character'Pos (Digit)");
         L ("                      - Character'Pos ('0')) * 4;");
         L ("               Stop : Natural := Base + 3;");
         L ("            begin");
         L ("               while Stop >= Base");
         L ("                 and then Row (Stop) = Character'Val (0)");
         L ("               loop");
         L ("                  Stop := Stop - 1;");
         L ("               end loop;");
         L ("               return Row (Base .. Stop);");
         L ("            end;");
         L ("         end if;");
         L;
         L ("         return [1 => Digit];");
         L ("      end;");
         L ("   end Digit_Text;");
      end Emit_Digits;

      procedure Emit_Number_Display_Affixes is
      begin
         L;
         L ("   function Number_Percent_Suffix (Locale : String) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang = ""ar"" or else Lang = ""fa"" then");
         L ("         return U (16#66A#);");
         L ("      end if;");
         L;
         L ("      return ""%"";");
         L ("   end Number_Percent_Suffix;");
         L;
         L ("   function Number_Plus_Sign (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""+"";");
         L ("   end Number_Plus_Sign;");
         L;
         L ("   function Number_Minus_Sign (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""-"";");
         L ("   end Number_Minus_Sign;");
         L;
         L ("   function Number_Accounting_Prefix (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""("";");
         L ("   end Number_Accounting_Prefix;");
         L;
         L ("   function Number_Accounting_Suffix (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return "")"";");
         L ("   end Number_Accounting_Suffix;");
         L;
         L ("   function Number_Permille_Suffix (Locale : String) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang = ""ar"" or else Lang = ""fa"" then");
         L ("         return U (16#609#);");
         L ("      end if;");
         L;
         L ("      return U (16#2030#);");
         L ("   end Number_Permille_Suffix;");
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
         L;
         L ("   function Number_Exponent_Separator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""E"";");
         L ("   end Number_Exponent_Separator;");
      end Emit_Number_Display_Affixes;

      --  The currency accessors were the last linear Code = "..." chains: a
      --  miss walked all 307 rows, comparing the argument to each in turn.
      --  Each field becomes a currency-code-keyed table the emitted body
      --  bisects instead. A String field packs its evaluated UTF-8 value once
      --  (VB decodes it, and repeats -- most symbols are their own code --
      --  collapse to a single copy) and keeps a 3+5+5 record per code; the two
      --  Natural fields keep the small value inline as a base-62 pair, a 3+2
      --  record. Rows whose value is the default are left out and answered by
      --  the default arm, exactly as the chain skipped them.
      procedure Emit_Currency_Field
        (Name         : String;
         Field_Number : Positive;
         Return_Type  : String;
         Default_Expr : String)
      is
         Is_String : constant Boolean := Return_Type = "String";

         Max_Currency : constant := 512;
         type Currency_Entry is record
            Code  : US.Unbounded_String;
            Value : US.Unbounded_String;
            First : Natural := 0;
            Last  : Natural := 0;
         end record;

         Items : array (1 .. Max_Currency) of Currency_Entry;
         Count : Natural := 0;

         Values     : US.Unbounded_String;
         Index_Data : US.Unbounded_String;

         function Field_Value (Index : Positive) return String is
           (case Field_Number is
               when 2 => S (Rules (Index).B),
               when 3 => S (Rules (Index).C),
               when 4 => S (Rules (Index).D),
               when 5 => S (Rules (Index).E),
               when 6 => S (Rules (Index).F),
               when others => "");
      begin
         --  Collect the rows this field keeps. A String field has no literal
         --  default to compare against (the default is the Code itself, or the
         --  symbol accessor), so it keeps every row; the Natural fields drop
         --  the rows the default already answers.
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "currency") then
               declare
                  Raw : constant String := Field_Value (Index);
               begin
                  if Is_String or else Raw /= Default_Expr then
                     if Count = Max_Currency then
                        Add_Error ("too many currency rows for " & Name);
                     else
                        Count := Count + 1;
                        Items (Count).Code := Rules (Index).A;
                        Items (Count).Value :=
                          US.To_Unbounded_String
                            (if Is_String
                             then Ada_Expression_UTF8_Hex (Raw)
                             else Raw);
                     end if;
                  end if;
               end;
            end if;
         end loop;

         --  Sorted so the emitted body can bisect on the code.
         for Outer in 2 .. Count loop
            declare
               Current      : constant Currency_Entry := Items (Outer);
               Current_Code : constant String := S (Current.Code);
               Probe        : Natural := Outer - 1;
            begin
               while Probe >= 1
                 and then S (Items (Probe).Code) > Current_Code
               loop
                  Items (Probe + 1) := Items (Probe);
                  Probe := Probe - 1;
               end loop;
               Items (Probe + 1) := Current;
            end;
         end loop;

         --  Pack the index (and, for a String field, the value store).
         for N in 1 .. Count loop
            US.Append (Index_Data, S (Items (N).Code));
            if Is_String then
               --  Point a repeated value at the copy already packed.
               for Prior in 1 .. N - 1 loop
                  if US."=" (Items (Prior).Value, Items (N).Value) then
                     Items (N).First := Items (Prior).First;
                     Items (N).Last := Items (Prior).Last;
                     exit;
                  end if;
               end loop;

               if Items (N).First = 0 then
                  declare
                     Packed : constant String := S (Items (N).Value);
                  begin
                     Items (N).First := US.Length (Values) + 1;
                     Items (N).Last := US.Length (Values) + Packed'Length;
                     US.Append (Values, Packed);
                  end;
               end if;

               US.Append (Index_Data, To_Base62 (Items (N).First, 5));
               US.Append (Index_Data, To_Base62 (Items (N).Last, 5));
            else
               US.Append
                 (Index_Data,
                  To_Base62 (Natural'Value (S (Items (N).Value)), 2));
            end if;
         end loop;

         L;
         L ("   function " & Name & " (Code : String) return " & Return_Type
            & " is");
         if Is_String then
            L ("      Values : constant String :=");
            Emit_Unit_String_Expression ("        ", S (Values), ";");
         end if;
         L ("      Index_Data : constant String :=");
         Emit_Unit_String_Expression ("        ", S (Index_Data), ";");
         L ("      Width : constant := " & (if Is_String then "13" else "5")
            & ";");
         L ("      Count : constant Natural := Index_Data'Length / Width;");
         L;
         L ("      function Key (N : Positive) return String is");
         L ("        (Index_Data (Index_Data'First + (N - 1) * Width ..");
         L ("                     Index_Data'First + (N - 1) * Width + 2));");
         L;
         if Is_String then
            L ("      function Value_At (N : Positive) return String is");
            L ("         Base : constant Natural :=");
            L ("           Index_Data'First + (N - 1) * Width + 3;");
            L ("         F : constant Natural :=");
            L ("           N62 (Index_Data (Base .. Base + 4));");
            L ("         T : constant Natural :=");
            L ("           N62 (Index_Data (Base + 5 .. Base + 9));");
            L ("      begin");
            L ("         return VB (Values (F .. T));");
            L ("      end Value_At;");
         else
            L ("      function Value_At (N : Positive) return Natural is");
            L ("         Base : constant Natural :=");
            L ("           Index_Data'First + (N - 1) * Width + 3;");
            L ("      begin");
            L ("         return N62 (Index_Data (Base .. Base + 1));");
            L ("      end Value_At;");
         end if;
         L;
         L ("      Low : Natural := 1;");
         L ("      High : Natural := Count;");
         L ("      Mid : Natural;");
         L ("   begin");
         L ("      while Low <= High loop");
         L ("         Mid := (Low + High) / 2;");
         L ("         if Key (Mid) = Code then");
         L ("            return Value_At (Mid);");
         L ("         elsif Key (Mid) < Code then");
         L ("            Low := Mid + 1;");
         L ("         else");
         L ("            High := Mid - 1;");
         L ("         end if;");
         L ("      end loop;");
         L ("      return " & Default_Expr & ";");
         L ("   end " & Name & ";");
      end Emit_Currency_Field;

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

      procedure Emit_Time_Zone_Data is
         Family_Labels : Label_Array;
         Family_Label_Count : Natural;
         Display_Zones : Label_Array;
         Display_Zone_Count : Natural;

         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := Data_Chunk;
            Start      : Positive := Value'First;
            Stop       : Natural;
            Term       : Positive := 1;
         begin
            if Value'Length = 0 then
               L (Indent & """""" & Suffix);
               return;
            elsif Value'Length <= Chunk_Size then
               L (Indent & """" & Value & """" & Suffix);
               return;
            end if;

            while Start <= Value'Last loop
               Stop := Natural'Min (Start + Chunk_Size - 1, Value'Last);
               L (Indent & (if Term = 1 then "" else "& ")
                  & """" & Value (Start .. Stop) & """"
                  & (if Stop = Value'Last then Suffix else ""));
               Start := Stop + 1;
               Term := Term + 1;
            end loop;
         end Emit_String_Expression;
         pragma Unreferenced (Emit_String_Expression);

         function Zone_Exemplar_Data return String is
            Result : US.Unbounded_String;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_exemplar_hex") then
                  US.Append (Result, S (Rules (Index).A));
                  US.Append (Result, "|");
                  US.Append (Result, S (Rules (Index).B));
                  US.Append (Result, "|");
                  US.Append (Result, S (Rules (Index).C));
                  US.Append (Result, "~");
               end if;
            end loop;

            return S (Result);
         end Zone_Exemplar_Data;
         pragma Unreferenced (Zone_Exemplar_Data);
      begin
         L;
         L ("   type TZDB_Zone_Data is record");
         L ("      Initial_Offset : Integer;");
         L ("      First          : Natural;");
         L ("      Last           : Natural;");
         L ("   end record;");
         L;
         L ("   type TZDB_Transition is record");
         L ("      Key    : Long_Long_Integer;");
         L ("      Offset : Integer;");
         L ("   end record;");
         L;
         --  Positional aggregates: the rows are a generated blob no one reads,
         --  and the index and field names ("1 => (Initial_Offset => ...")
         --  repeated per row cost more than the data. Order follows the record
         --  above: Initial_Offset, First, Last -- and Key, Offset for the
         --  transitions.
         L ("   TZDB_Zones : constant array (Positive range <>) of TZDB_Zone_Data :=");
         L ("     [");
         for Zone_Index in 1 .. TZDB_Zone_Count loop
            declare
               First : Natural := 0;
               Last  : Natural := 0;
            begin
               for Transition_Index in 1 .. TZDB_Transition_Count loop
                  if TZDB_Transition_Zones (Transition_Index) = Zone_Index then
                     if First = 0 then
                        First := Transition_Index;
                     end if;
                     Last := Transition_Index;
                  end if;
               end loop;

               L ("      ("
                  & Trim (Integer'Image (TZDB_Zone_Initial_Offsets (Zone_Index)))
                  & "," & Trim (Natural'Image (First))
                  & "," & Trim (Natural'Image (Last)) & ")"
                  & (if Zone_Index = TZDB_Zone_Count then "" else ","));
            end;
         end loop;
         L ("     ];");
         L;
         L ("   TZDB_Transitions : constant array (Positive range <>) of TZDB_Transition :=");
         L ("     [");
         for Transition_Index in 1 .. TZDB_Transition_Count loop
            L ("      ("
               & Trim (Long_Long_Integer'Image
                         (TZDB_Transition_Keys (Transition_Index)))
               & "," & Trim (Integer'Image
                               (TZDB_Transition_Offsets (Transition_Index)))
               & ")"
               & (if Transition_Index = TZDB_Transition_Count then "" else ","));
         end loop;
         L ("     ];");
         L;
         --  Alias -> canonical was a chain of up to 153 Zone = "..." tests.
         --  It is now a table keyed on the alias name, padded to a fixed field,
         --  with the target packed once beside it (repeats -- many aliases
         --  share a target -- collapse to a single copy). The UTC aliases and
         --  GMT keep their own guards above the table, as the chain tested them
         --  first, and an unknown zone still returns itself.
         L ("   function Canonical_Time_Zone (Zone : String) return String is");
         declare
            type Link_Entry is record
               Key   : US.Unbounded_String;
               Value : US.Unbounded_String;
               First : Natural := 0;
               Last  : Natural := 0;
            end record;

            Items      : array (1 .. Natural'Max (TZDB_Link_Count, 1)) of
              Link_Entry;
            Count      : Natural := 0;
            Link_Width : Natural := 0;
            Values     : US.Unbounded_String;
            Index_Data : US.Unbounded_String;
         begin
            for Index in 1 .. TZDB_Link_Count loop
               Link_Width :=
                 Natural'Max
                   (Link_Width, S (TZDB_Link_Names (Index))'Length);
            end loop;

            for Index in 1 .. TZDB_Link_Count loop
               declare
                  Name : constant String := S (TZDB_Link_Names (Index));
               begin
                  Count := Count + 1;
                  Items (Count).Key :=
                    US.To_Unbounded_String
                      (Name & (1 .. Link_Width - Name'Length => ' '));
                  Items (Count).Value := TZDB_Link_Targets (Index);
               end;
            end loop;

            --  Sorted by the padded key; the space pad sorts below every
            --  character an alias contains, so this is the raw-name order too.
            for Outer in 2 .. Count loop
               declare
                  Current     : constant Link_Entry := Items (Outer);
                  Current_Key : constant String := S (Current.Key);
                  Probe       : Natural := Outer - 1;
               begin
                  while Probe >= 1
                    and then S (Items (Probe).Key) > Current_Key
                  loop
                     Items (Probe + 1) := Items (Probe);
                     Probe := Probe - 1;
                  end loop;
                  Items (Probe + 1) := Current;
               end;
            end loop;

            for N in 1 .. Count loop
               US.Append (Index_Data, S (Items (N).Key));
               for Prior in 1 .. N - 1 loop
                  if US."=" (Items (Prior).Value, Items (N).Value) then
                     Items (N).First := Items (Prior).First;
                     Items (N).Last := Items (Prior).Last;
                     exit;
                  end if;
               end loop;

               if Items (N).First = 0 then
                  declare
                     Target : constant String := S (Items (N).Value);
                  begin
                     Items (N).First := US.Length (Values) + 1;
                     Items (N).Last := US.Length (Values) + Target'Length;
                     US.Append (Values, Target);
                  end;
               end if;

               US.Append (Index_Data, To_Base62 (Items (N).First, 5));
               US.Append (Index_Data, To_Base62 (Items (N).Last, 5));
            end loop;

            L ("      Values : constant String :=");
            Emit_Unit_String_Expression ("        ", S (Values), ";");
            L ("      Index_Data : constant String :=");
            Emit_Unit_String_Expression ("        ", S (Index_Data), ";");
            L ("      Link_Width : constant := "
               & Trim (Integer'Image (Link_Width)) & ";");
            L ("      Width : constant := Link_Width + 10;");
            L ("      Count : constant Natural := Index_Data'Length / Width;");
            L;
            L ("      function Key (N : Positive) return String is");
            L ("        (Index_Data (Index_Data'First + (N - 1) * Width ..");
            L ("                     Index_Data'First + (N - 1) * Width"
               & " + Link_Width - 1));");
            L;
            L ("      function Value_At (N : Positive) return String is");
            L ("         Base : constant Natural :=");
            L ("           Index_Data'First + (N - 1) * Width + Link_Width;");
            L ("         F : constant Natural :=");
            L ("           N62 (Index_Data (Base .. Base + 4));");
            L ("         T : constant Natural :=");
            L ("           N62 (Index_Data (Base + 5 .. Base + 9));");
            L ("      begin");
            L ("         return Values (F .. T);");
            L ("      end Value_At;");
            L;
            L ("      Low : Natural := 1;");
            L ("      High : Natural := Count;");
            L ("      Mid : Natural;");
            L ("   begin");
            L ("      if Zone = """"");
            L ("        or else Zone = ""UTC""");
            L ("        or else Zone = ""UCT""");
            L ("        or else Zone = ""Universal""");
            L ("        or else Zone = ""Zulu""");
            L ("        or else Zone = ""Etc/UTC""");
            L ("        or else Zone = ""Etc/UCT""");
            L ("        or else Zone = ""Etc/Universal""");
            L ("        or else Zone = ""Etc/Zulu""");
            L ("      then");
            L ("         return ""UTC"";");
            L ("      end if;");
            L;
            L ("      if Zone = ""GMT"" then");
            L ("         return ""GMT"";");
            L ("      end if;");
            L;
            L ("      if Zone'Length <= Link_Width then");
            L ("         declare");
            L ("            Wanted : constant String :=");
            L ("              Zone & [1 .. Link_Width - Zone'Length => ' '];");
            L ("         begin");
            L ("            while Low <= High loop");
            L ("               Mid := (Low + High) / 2;");
            L ("               if Key (Mid) = Wanted then");
            L ("                  return Value_At (Mid);");
            L ("               elsif Key (Mid) < Wanted then");
            L ("                  Low := Mid + 1;");
            L ("               else");
            L ("                  High := Mid - 1;");
            L ("               end if;");
            L ("            end loop;");
            L ("         end;");
            L ("      end if;");
            L ("      return Zone;");
            L ("   end Canonical_Time_Zone;");
         end;
         L;
         --  Zone -> index was a chain of up to 447 Canonical = "..." tests.
         --  It is now a table keyed on the canonical zone name, padded to a
         --  fixed field so the body can bisect it, with the index packed
         --  beside each name in base 62. The UTC aliases keep their own guard
         --  above the table, as they never had a row.
         L ("   function Time_Zone_TZDB_Index (Zone : String) return Natural is");
         L ("      Canonical : constant String := Canonical_Time_Zone (Zone);");
         declare
            type Zone_Entry is record
               Key   : US.Unbounded_String;
               Value : Natural;
            end record;

            Items      : array (1 .. Natural'Max (TZDB_Zone_Count, 1)) of
              Zone_Entry;
            Count      : Natural := 0;
            Zone_Width : Natural := 0;
            Index_Data : US.Unbounded_String;
         begin
            for Zone_Index in 1 .. TZDB_Zone_Count loop
               Zone_Width :=
                 Natural'Max
                   (Zone_Width, S (TZDB_Zone_Names (Zone_Index))'Length);
            end loop;

            for Zone_Index in 1 .. TZDB_Zone_Count loop
               declare
                  Name : constant String := S (TZDB_Zone_Names (Zone_Index));
               begin
                  Count := Count + 1;
                  Items (Count).Key :=
                    US.To_Unbounded_String
                      (Name & (1 .. Zone_Width - Name'Length => ' '));
                  Items (Count).Value := Zone_Index;
               end;
            end loop;

            --  Sorted by the padded key so the emitted body can bisect. The
            --  pad is a space, which sorts below every character a zone name
            --  contains, so this order matches the raw-name order too.
            for Outer in 2 .. Count loop
               declare
                  Current     : constant Zone_Entry := Items (Outer);
                  Current_Key : constant String := S (Current.Key);
                  Probe       : Natural := Outer - 1;
               begin
                  while Probe >= 1
                    and then S (Items (Probe).Key) > Current_Key
                  loop
                     Items (Probe + 1) := Items (Probe);
                     Probe := Probe - 1;
                  end loop;
                  Items (Probe + 1) := Current;
               end;
            end loop;

            for N in 1 .. Count loop
               US.Append (Index_Data, S (Items (N).Key));
               US.Append (Index_Data, To_Base62 (Items (N).Value, 3));
            end loop;

            L ("      Index_Data : constant String :=");
            Emit_Unit_String_Expression ("        ", S (Index_Data), ";");
            L ("      Zone_Width : constant := "
               & Trim (Integer'Image (Zone_Width)) & ";");
            L ("      Width : constant := Zone_Width + 3;");
            L ("      Count : constant Natural := Index_Data'Length / Width;");
            L;
            L ("      function Key (N : Positive) return String is");
            L ("        (Index_Data (Index_Data'First + (N - 1) * Width ..");
            L ("                     Index_Data'First + (N - 1) * Width"
               & " + Zone_Width - 1));");
            L;
            L ("      function Value_At (N : Positive) return Natural is");
            L ("         Base : constant Natural :=");
            L ("           Index_Data'First + (N - 1) * Width + Zone_Width;");
            L ("      begin");
            L ("         return N62 (Index_Data (Base .. Base + 2));");
            L ("      end Value_At;");
            L;
            L ("      Low : Natural := 1;");
            L ("      High : Natural := Count;");
            L ("      Mid : Natural;");
            L ("   begin");
            L ("      if Canonical = ""UTC""");
            L ("        or else Canonical = ""Z""");
            L ("        or else Canonical = ""GMT""");
            L ("        or else Canonical = ""Etc/UTC""");
            L ("        or else Canonical = ""Etc/GMT""");
            L ("      then");
            L ("         return 0;");
            L ("      end if;");
            L;
            L ("      if Canonical'Length = 0"
               & " or else Canonical'Length > Zone_Width then");
            L ("         return 0;");
            L ("      end if;");
            L;
            L ("      declare");
            L ("         Wanted : constant String :=");
            L ("           Canonical & [1 .. Zone_Width - Canonical'Length => ' '];");
            L ("      begin");
            L ("         while Low <= High loop");
            L ("            Mid := (Low + High) / 2;");
            L ("            if Key (Mid) = Wanted then");
            L ("               return Value_At (Mid);");
            L ("            elsif Key (Mid) < Wanted then");
            L ("               Low := Mid + 1;");
            L ("            else");
            L ("               High := Mid - 1;");
            L ("            end if;");
            L ("         end loop;");
            L ("      end;");
            L ("      return 0;");
            L ("   end Time_Zone_TZDB_Index;");
         end;
         L;
         L ("   function TZDB_Key");
         L ("     (Year   : Natural;");
         L ("      Month  : Natural;");
         L ("      Day    : Natural;");
         L ("      Hour   : Natural;");
         L ("      Minute : Natural;");
         L ("      Second : Natural)");
         L ("      return Long_Long_Integer");
         L ("   is");
         L ("   begin");
         L ("      return (((((Long_Long_Integer (Year) * 100");
         L ("                 + Long_Long_Integer (Month)) * 100");
         L ("                + Long_Long_Integer (Day)) * 100");
         L ("               + Long_Long_Integer (Hour)) * 100");
         L ("              + Long_Long_Integer (Minute)) * 100");
         L ("             + Long_Long_Integer (Second));");
         L ("   end TZDB_Key;");
         L;
         L ("   function Time_Zone_Offset_Seconds_At_UTC");
         L ("     (Zone   : String;");
         L ("      Year   : Natural;");
         L ("      Month  : Natural;");
         L ("      Day    : Natural;");
         L ("      Hour   : Natural;");
         L ("      Minute : Natural;");
         L ("      Second : Natural;");
         L ("      Valid  : out Boolean)");
         L ("      return Integer");
         L ("   is");
         L ("      Index : constant Natural := Time_Zone_TZDB_Index (Zone);");
         L ("   begin");
         L ("      if Zone = """"");
         L ("        or else Zone = ""UTC""");
         L ("        or else Zone = ""Z""");
         L ("        or else Zone = ""GMT""");
         L ("        or else Zone = ""Etc/UTC""");
         L ("        or else Zone = ""Etc/GMT""");
         L ("      then");
         L ("         Valid := True;");
         L ("         return 0;");
         L ("      elsif Index = 0 then");
         L ("         Valid := False;");
         L ("         return 0;");
         L ("      else");
         L ("         declare");
         L ("            Key : constant Long_Long_Integer :=");
         L ("              TZDB_Key (Year, Month, Day, Hour, Minute, Second);");
         L ("            First : constant Natural := TZDB_Zones (Index).First;");
         L ("            Last  : constant Natural := TZDB_Zones (Index).Last;");
         L ("         begin");
         L ("            Valid := True;");
         L ("            if First = 0 then");
         L ("               return TZDB_Zones (Index).Initial_Offset;");
         L ("            end if;");
         L;
         L ("            --  Transitions are sorted ascending by Key, so the one");
         L ("            --  in force is the last whose Key <= the query. Bisect");
         L ("            --  for it rather than walking every transition, which");
         L ("            --  an old query date did in full before falling back.");
         L ("            declare");
         L ("               Low   : Natural := First;");
         L ("               High  : Natural := Last;");
         L ("               Mid   : Natural;");
         L ("               Found : Natural := 0;");
         L ("            begin");
         L ("               while Low <= High loop");
         L ("                  Mid := Low + (High - Low) / 2;");
         L ("                  if TZDB_Transitions (Mid).Key <= Key then");
         L ("                     Found := Mid;");
         L ("                     Low := Mid + 1;");
         L ("                  else");
         L ("                     High := Mid - 1;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Found /= 0 then");
         L ("                  return TZDB_Transitions (Found).Offset;");
         L ("               end if;");
         L ("            end;");
         L;
         L ("            return TZDB_Zones (Index).Initial_Offset;");
         L ("         end;");
         L ("      end if;");
         L ("   end Time_Zone_Offset_Seconds_At_UTC;");
         L;
         L ("   function Time_Zone_Base_Offset_Minutes");
         L ("     (Zone  : String;");
         L ("      Valid : out Boolean)");
         L ("      return Integer");
         L ("   is");
         L ("   begin");
         L ("      Valid := True;");
         L;
         L ("      if Zone = """"");
         L ("        or else Zone = ""UTC""");
         L ("        or else Zone = ""Z""");
         L ("        or else Zone = ""GMT""");
         L ("        or else Zone = ""Etc/UTC""");
         L ("        or else Zone = ""Etc/GMT""");
         L ("      then");
         L ("         return 0;");
         L ("      elsif Zone = ""Europe/Berlin""");
         L ("        or else Zone = ""Europe/Paris""");
         L ("        or else Zone = ""Europe/Rome""");
         L ("        or else Zone = ""Europe/Madrid""");
         L ("        or else Zone = ""Europe/Amsterdam""");
         L ("        or else Zone = ""Europe/Zurich""");
         L ("        or else Zone = ""Europe/Vienna""");
         L ("        or else Zone = ""Europe/Brussels""");
         L ("        or else Zone = ""Europe/Copenhagen""");
         L ("        or else Zone = ""Europe/Stockholm""");
         L ("        or else Zone = ""Europe/Oslo""");
         L ("        or else Zone = ""Europe/Warsaw""");
         L ("        or else Zone = ""Europe/Prague""");
         L ("        or else Zone = ""Europe/Budapest""");
         L ("        or else Zone = ""Europe/Bratislava""");
         L ("        or else Zone = ""Europe/Luxembourg""");
         L ("        or else Zone = ""Europe/Monaco""");
         L ("        or else Zone = ""Europe/Andorra""");
         L ("        or else Zone = ""Europe/Malta""");
         L ("        or else Zone = ""Europe/San_Marino""");
         L ("        or else Zone = ""Europe/Vatican""");
         L ("        or else Zone = ""Europe/Belgrade""");
         L ("        or else Zone = ""Europe/Zagreb""");
         L ("        or else Zone = ""Europe/Ljubljana""");
         L ("        or else Zone = ""Europe/Sarajevo""");
         L ("        or else Zone = ""Europe/Skopje""");
         L ("        or else Zone = ""Europe/Podgorica""");
         L ("        or else Zone = ""Europe/Tirane""");
         L ("      then");
         L ("         return 60;");
         L ("      elsif Zone = ""Europe/London"" then");
         L ("         return 0;");
         L ("      elsif Zone = ""Europe/Dublin""");
         L ("        or else Zone = ""Europe/Lisbon""");
         L ("        or else Zone = ""Atlantic/Canary""");
         L ("      then");
         L ("         return 0;");
         L ("      elsif Zone = ""Europe/Athens""");
         L ("        or else Zone = ""Europe/Helsinki""");
         L ("        or else Zone = ""Europe/Bucharest""");
         L ("        or else Zone = ""Europe/Sofia""");
         L ("        or else Zone = ""Europe/Vilnius""");
         L ("        or else Zone = ""Europe/Riga""");
         L ("        or else Zone = ""Europe/Tallinn""");
         L ("        or else Zone = ""Europe/Kyiv""");
         L ("        or else Zone = ""Europe/Chisinau""");
         L ("        or else Zone = ""Asia/Nicosia""");
         L ("      then");
         L ("         return 120;");
         L ("      elsif Zone = ""Europe/Moscow"" then");
         L ("         return 180;");
         L ("      elsif Zone = ""America/New_York""");
         L ("        or else Zone = ""America/Toronto""");
         L ("        or else Zone = ""America/Montreal""");
         L ("        or else Zone = ""America/Detroit""");
         L ("        or else Zone = ""America/Indiana/Indianapolis""");
         L ("        or else Zone = ""America/Kentucky/Louisville""");
         L ("        or else Zone = ""America/Nassau""");
         L ("      then");
         L ("         return -300;");
         L ("      elsif Zone = ""America/Chicago""");
         L ("        or else Zone = ""America/Winnipeg""");
         L ("      then");
         L ("         return -360;");
         L ("      elsif Zone = ""America/Denver""");
         L ("        or else Zone = ""America/Edmonton""");
         L ("        or else Zone = ""America/Boise""");
         L ("      then");
         L ("         return -420;");
         L ("      elsif Zone = ""America/Los_Angeles""");
         L ("        or else Zone = ""America/Vancouver""");
         L ("        or else Zone = ""America/Tijuana""");
         L ("      then");
         L ("         return -480;");
         L ("      elsif Zone = ""America/Phoenix"" then");
         L ("         return -420;");
         L ("      elsif Zone = ""America/Mexico_City"" then");
         L ("         return -360;");
         L ("      elsif Zone = ""America/Bogota""");
         L ("        or else Zone = ""America/Lima""");
         L ("      then");
         L ("         return -300;");
         L ("      elsif Zone = ""America/Sao_Paulo""");
         L ("        or else Zone = ""America/Argentina/Buenos_Aires""");
         L ("      then");
         L ("         return -180;");
         L ("      elsif Zone = ""Africa/Johannesburg"" then");
         L ("         return 120;");
         L ("      elsif Zone = ""Africa/Accra""");
         L ("        or else Zone = ""Africa/Abidjan""");
         L ("      then");
         L ("         return 0;");
         L ("      elsif Zone = ""Africa/Algiers""");
         L ("        or else Zone = ""Africa/Tunis""");
         L ("      then");
         L ("         return 60;");
         L ("      elsif Zone = ""Africa/Nairobi"" then");
         L ("         return 180;");
         L ("      elsif Zone = ""Africa/Lagos"" then");
         L ("         return 60;");
         L ("      elsif Zone = ""Europe/Istanbul""");
         L ("        or else Zone = ""Asia/Riyadh""");
         L ("      then");
         L ("         return 180;");
         L ("      elsif Zone = ""Asia/Jerusalem"" then");
         L ("         return 120;");
         L ("      elsif Zone = ""Asia/Tehran"" then");
         L ("         return 210;");
         L ("      elsif Zone = ""Asia/Dubai""");
         L ("        or else Zone = ""Asia/Yerevan""");
         L ("        or else Zone = ""Asia/Tbilisi""");
         L ("        or else Zone = ""Asia/Baku""");
         L ("      then");
         L ("         return 240;");
         L ("      elsif Zone = ""Asia/Tashkent"" then");
         L ("         return 300;");
         L ("      elsif Zone = ""Asia/Shanghai""");
         L ("        or else Zone = ""Asia/Singapore""");
         L ("        or else Zone = ""Asia/Manila""");
         L ("        or else Zone = ""Asia/Hong_Kong""");
         L ("        or else Zone = ""Asia/Taipei""");
         L ("        or else Zone = ""Asia/Kuala_Lumpur""");
         L ("      then");
         L ("         return 480;");
         L ("      elsif Zone = ""Asia/Bangkok""");
         L ("        or else Zone = ""Asia/Jakarta""");
         L ("        or else Zone = ""Asia/Ho_Chi_Minh""");
         L ("      then");
         L ("         return 420;");
         L ("      elsif Zone = ""Asia/Karachi"" then");
         L ("         return 300;");
         L ("      elsif Zone = ""Asia/Colombo"" then");
         L ("         return 330;");
         L ("      elsif Zone = ""Asia/Dhaka"" then");
         L ("         return 360;");
         L ("      elsif Zone = ""Asia/Yangon"" then");
         L ("         return 390;");
         L ("      elsif Zone = ""Asia/Tokyo"" then");
         L ("         return 540;");
         L ("      elsif Zone = ""Asia/Seoul"" then");
         L ("         return 540;");
         L ("      elsif Zone = ""Asia/Kolkata"" then");
         L ("         return 330;");
         L ("      elsif Zone = ""Asia/Ulaanbaatar"" then");
         L ("         return 480;");
         L ("      elsif Zone = ""Asia/Kathmandu"" then");
         L ("         return 345;");
         L ("      elsif Zone = ""Pacific/Honolulu"" then");
         L ("         return -600;");
         L ("      elsif Zone = ""Pacific/Auckland"" then");
         L ("         return 720;");
         L ("      elsif Zone = ""Australia/Sydney""");
         L ("        or else Zone = ""Australia/Melbourne""");
         L ("        or else Zone = ""Australia/Hobart""");
         L ("      then");
         L ("         return 600;");
         L ("      elsif Zone = ""Australia/Adelaide"" then");
         L ("         return 570;");
         L ("      elsif Zone = ""Australia/Lord_Howe"" then");
         L ("         return 630;");
         L ("      elsif Zone = ""Australia/Brisbane"" then");
         L ("         return 600;");
         L ("      elsif Zone = ""Australia/Eucla"" then");
         L ("         return 525;");
         L ("      elsif Zone = ""Australia/Perth"" then");
         L ("         return 480;");
         L ("      elsif Zone = ""Australia/Darwin"" then");
         L ("         return 570;");
         L ("      else");
         L ("         Valid := False;");
         L ("         return 0;");
         L ("      end if;");
         L ("   end Time_Zone_Base_Offset_Minutes;");
         L;
         L ("   function Time_Zone_DST_Family (Zone : String) return String is");
         L ("   begin");
         L ("      if Zone = ""Europe/Berlin""");
         L ("        or else Zone = ""Europe/Paris""");
         L ("        or else Zone = ""Europe/Rome""");
         L ("        or else Zone = ""Europe/Madrid""");
         L ("        or else Zone = ""Europe/Amsterdam""");
         L ("        or else Zone = ""Europe/Zurich""");
         L ("        or else Zone = ""Europe/Vienna""");
         L ("        or else Zone = ""Europe/Brussels""");
         L ("        or else Zone = ""Europe/Copenhagen""");
         L ("        or else Zone = ""Europe/Stockholm""");
         L ("        or else Zone = ""Europe/Oslo""");
         L ("        or else Zone = ""Europe/Warsaw""");
         L ("        or else Zone = ""Europe/Prague""");
         L ("        or else Zone = ""Europe/Budapest""");
         L ("        or else Zone = ""Europe/Bratislava""");
         L ("        or else Zone = ""Europe/Luxembourg""");
         L ("        or else Zone = ""Europe/Monaco""");
         L ("        or else Zone = ""Europe/Andorra""");
         L ("        or else Zone = ""Europe/Malta""");
         L ("        or else Zone = ""Europe/San_Marino""");
         L ("        or else Zone = ""Europe/Vatican""");
         L ("        or else Zone = ""Europe/Belgrade""");
         L ("        or else Zone = ""Europe/Zagreb""");
         L ("        or else Zone = ""Europe/Ljubljana""");
         L ("        or else Zone = ""Europe/Sarajevo""");
         L ("        or else Zone = ""Europe/Skopje""");
         L ("        or else Zone = ""Europe/Podgorica""");
         L ("        or else Zone = ""Europe/Tirane""");
         L ("      then");
         L ("         return ""europe-central"";");
         L ("      elsif Zone = ""Europe/London"" then");
         L ("         return ""europe-london"";");
         L ("      elsif Zone = ""Europe/Dublin""");
         L ("        or else Zone = ""Europe/Lisbon""");
         L ("        or else Zone = ""Atlantic/Canary""");
         L ("      then");
         L ("         return ""europe-london"";");
         L ("      elsif Zone = ""Europe/Athens""");
         L ("        or else Zone = ""Europe/Helsinki""");
         L ("        or else Zone = ""Europe/Bucharest""");
         L ("        or else Zone = ""Europe/Sofia""");
         L ("        or else Zone = ""Europe/Vilnius""");
         L ("        or else Zone = ""Europe/Riga""");
         L ("        or else Zone = ""Europe/Tallinn""");
         L ("        or else Zone = ""Europe/Kyiv""");
         L ("        or else Zone = ""Europe/Chisinau""");
         L ("        or else Zone = ""Asia/Nicosia""");
         L ("      then");
         L ("         return ""europe-eastern"";");
         L ("      elsif Zone = ""America/New_York""");
         L ("        or else Zone = ""America/Toronto""");
         L ("        or else Zone = ""America/Montreal""");
         L ("        or else Zone = ""America/Detroit""");
         L ("        or else Zone = ""America/Indiana/Indianapolis""");
         L ("        or else Zone = ""America/Kentucky/Louisville""");
         L ("        or else Zone = ""America/Nassau""");
         L ("      then");
         L ("         return ""america-eastern"";");
         L ("      elsif Zone = ""America/Chicago""");
         L ("        or else Zone = ""America/Winnipeg""");
         L ("      then");
         L ("         return ""america-central"";");
         L ("      elsif Zone = ""America/Mexico_City"" then");
         L ("         return ""america-mexico-city"";");
         L ("      elsif Zone = ""America/Sao_Paulo"" then");
         L ("         return ""america-sao-paulo"";");
         L ("      elsif Zone = ""America/Denver""");
         L ("        or else Zone = ""America/Edmonton""");
         L ("        or else Zone = ""America/Boise""");
         L ("      then");
         L ("         return ""america-mountain"";");
         L ("      elsif Zone = ""America/Los_Angeles""");
         L ("        or else Zone = ""America/Vancouver""");
         L ("        or else Zone = ""America/Tijuana""");
         L ("      then");
         L ("         return ""america-pacific"";");
         L ("      elsif Zone = ""Pacific/Auckland"" then");
         L ("         return ""pacific-new-zealand"";");
         L ("      elsif Zone = ""Australia/Sydney""");
         L ("        or else Zone = ""Australia/Melbourne""");
         L ("        or else Zone = ""Australia/Hobart""");
         L ("      then");
         L ("         return ""australia-eastern"";");
         L ("      elsif Zone = ""Australia/Adelaide"" then");
         L ("         return ""australia-central"";");
         L ("      elsif Zone = ""Australia/Brisbane"" then");
         L ("         return ""australia-eastern"";");
         L ("      elsif Zone = ""Australia/Darwin"" then");
         L ("         return ""australia-central"";");
         L ("      elsif Zone = ""Australia/Eucla"" then");
         L ("         return ""australia-central-western"";");
         L ("      elsif Zone = ""Australia/Perth"" then");
         L ("         return ""australia-western"";");
         L ("      elsif Zone = ""Australia/Lord_Howe"" then");
         L ("         return ""australia-lord-howe"";");
         L ("      elsif Zone = ""Asia/Jerusalem"" then");
         L ("         return ""asia-jerusalem"";");
         L ("      elsif Zone = ""Asia/Tehran"" then");
         L ("         return ""asia-tehran"";");
         L ("      else");
         L ("         return ""none"";");
         L ("      end if;");
         L ("   end Time_Zone_DST_Family;");
         L;
         --  Two blobs, each walked whole on each of two passes. One
         --  segment per locale for each, and the locale field drops out.
         --  A family is one of 17 and a zone one of 36, so each is a single
         --  coded character in the record; the scanner below is the same for
         --  both, since by then a key is just a code.
         Collect_Labels ("zone_family_display", 2,
                         Family_Labels, Family_Label_Count);
         Collect_Labels ("zone_display", 2, Display_Zones, Display_Zone_Count);
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  Grouped by locale, so a change of locale ends the segment.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_family_display") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Family_Labels, Family_Label_Count,
                                 S (Rules (Index).B), 1)
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).C)) & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Zone_Family_Display_Row", """""", Raw => True,
            Walk_Parents => False);

         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  Grouped by locale, so a change of locale ends the segment.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_display") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Display_Zones, Display_Zone_Count,
                                 S (Rules (Index).B), 1)
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).C)) & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Zone_Display_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   function Time_Zone_Display_Name");
         L ("     (Locale : String;");
         L ("      Zone   : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang   : constant String := Language (Locale);");
         L ("      Family : constant String := Time_Zone_DST_Family (Zone);");
         L;
         L;
         Emit_Label_Chain ("Family_Code", "Family",
                           Family_Labels, Family_Label_Count, 1);
         L;
         Emit_Label_Chain ("Zone_Code", "Zone",
                           Display_Zones, Display_Zone_Count, 1);
         L;
         L ("      --  One coded character, then the hex. The same scan serves");
         L ("      --  both tables: by here a key is only a code.");
         L ("      function Search (Rows : String; Wanted : String) return String is");
         L ("         Start : Positive := Rows'First;");
         L ("      begin");
         L ("         if Wanted = "" "" then");
         L ("            return """";");
         L ("         end if;");
         L;
         L ("         while Start <= Rows'Last loop");
         L ("            declare");
         L ("               Stop : Natural := Rows'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Rows'Last loop");
         L ("                  if Rows (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Stop > Start + 1");
         L ("                 and then Rows (Start .. Start) = Wanted");
         L ("               then");
         L ("                  return VB (Rows (Start + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      --  The locale, then each parent, longest first.");
         L ("      function Family_Display return String is");
         L ("         Exact : constant String :=");
         L ("           Search (Zone_Family_Display_Row (Locale), Family_Code);");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L;
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    Search");
         L ("                      (Zone_Family_Display_Row (Canon (Canon'First .. Cut - 1)),");
         L ("                       Family_Code);");
         L ("               begin");
         L ("                  if Hit /= """" then");
         L ("                     return Hit;");
         L ("                  end if;");
         L ("               end;");
         L ("            end if;");
         L ("            Cut := Cut - 1;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Family_Display;");
         L;
         L ("      --  The locale, then each parent, longest first.");
         L ("      function Zone_Display return String is");
         L ("         Exact : constant String :=");
         L ("           Search (Zone_Display_Row (Locale), Zone_Code);");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L;
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    Search");
         L ("                      (Zone_Display_Row (Canon (Canon'First .. Cut - 1)),");
         L ("                       Zone_Code);");
         L ("               begin");
         L ("                  if Hit /= """" then");
         L ("                     return Hit;");
         L ("                  end if;");
         L ("               end;");
         L ("            end if;");
         L ("            Cut := Cut - 1;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Zone_Display;");

         L ("      Family_Value : constant String := Family_Display;");
         L ("   begin");
         L ("      if Family_Value /= """" then");
         L ("         return Family_Value;");
         L ("      end if;");
         L;
         L ("      declare");
         L ("         Zone_Value : constant String := Zone_Display;");
         L ("      begin");
         L ("         if Zone_Value /= """" then");
         L ("            return Zone_Value;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      if Zone = """"");
         L ("        or else Zone = ""UTC""");
         L ("        or else Zone = ""Z""");
         L ("        or else Zone = ""GMT""");
         L ("      then");
         L ("         return ""UTC"";");
         L ("      end if;");
         L;
         L ("      if Lang = ""de"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return ""Mitteleurop"" & U (16#E4#) & ""ische Zeit"";");
         L ("         elsif Family = ""europe-london"" then");
         L ("            return ""Westeurop"" & U (16#E4#) & ""ische Zeit"";");
         L ("         elsif Family = ""europe-eastern"" then");
         L ("            return ""Osteurop"" & U (16#E4#) & ""ische Zeit"";");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return ""Nordamerikanische Ostk"" & U (16#FC#)");
         L ("              & ""stenzeit"";");
         L ("         elsif Family = ""america-central"" then");
         L ("            return ""Nordamerikanische Zentralzeit"";");
         L ("         elsif Family = ""america-mountain"" then");
         L ("            return ""Rocky-Mountain-Zeit"";");
         L ("         elsif Family = ""america-pacific"" then");
         L ("            return ""Nordamerikanische Westk"" & U (16#FC#)");
         L ("              & ""stenzeit"";");
         L ("         elsif Family = ""pacific-new-zealand"" then");
         L ("            return ""Neuseeland-Zeit"";");
         L ("         elsif Family = ""australia-eastern"" then");
         L ("            return ""Ostaustralische Zeit"";");
         L ("         elsif Family = ""australia-central"" then");
         L ("            return ""Zentralaustralische Zeit"";");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return UTF8 ([16#446#, 16#435#, 16#43D#, 16#442#,");
         L ("              16#440#, 16#430#, 16#43B#, 16#44C#, 16#43D#,");
         L ("              16#43E#, 16#435#, 16#432#, 16#440#, 16#43E#,");
         L ("              16#43F#, 16#435#, 16#439#, 16#441#, 16#43A#,");
         L ("              16#43E#, 16#435#, 16#20#, 16#432#, 16#440#,");
         L ("              16#435#, 16#43C#, 16#44F#]);");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return UTF8 ([16#432#, 16#43E#, 16#441#, 16#442#,");
         L ("              16#43E#, 16#447#, 16#43D#, 16#43E#, 16#435#,");
         L ("              16#20#, 16#432#, 16#440#, 16#435#, 16#43C#,");
         L ("              16#44F#]);");
         L ("         elsif Family /= ""none"" then");
         L ("            return UTF8 ([16#447#, 16#430#, 16#441#, 16#43E#,");
         L ("              16#432#, 16#43E#, 16#439#, 16#20#, 16#43F#,");
         L ("              16#43E#, 16#44F#, 16#441#]);");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return UTF8 ([16#62A#, 16#648#, 16#642#, 16#64A#,");
         L ("              16#62A#, 16#20#, 16#648#, 16#633#, 16#637#,");
         L ("              16#20#, 16#623#, 16#648#, 16#631#, 16#648#,");
         L ("              16#628#, 16#627#]);");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return UTF8 ([16#627#, 16#644#, 16#62A#, 16#648#,");
         L ("              16#642#, 16#64A#, 16#62A#, 16#20#, 16#627#,");
         L ("              16#644#, 16#634#, 16#631#, 16#642#, 16#64A#]);");
         L ("         elsif Family /= ""none"" then");
         L ("            return UTF8 ([16#62A#, 16#648#, 16#642#, 16#64A#,");
         L ("              16#62A#, 16#20#, 16#639#, 16#627#, 16#645#]);");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return UTF8 ([16#4E2D#, 16#592E#, 16#30E8#,");
         L ("              16#30FC#, 16#30ED#, 16#30C3#, 16#30D1#,");
         L ("              16#6642#, 16#9593#]);");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return UTF8 ([16#30A2#, 16#30E1#, 16#30EA#,");
         L ("              16#30AB#, 16#6771#, 16#90E8#, 16#6642#,");
         L ("              16#9593#]);");
         L ("         elsif Family /= ""none"" then");
         L ("            return UTF8 ([16#5730#, 16#57DF#, 16#6642#,");
         L ("              16#9593#]);");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return UTF8 ([16#4E2D#, 16#6B27#, 16#65F6#,");
         L ("              16#95F4#]);");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return UTF8 ([16#5317#, 16#7F8E#, 16#4E1C#,");
         L ("              16#90E8#, 16#65F6#, 16#95F4#]);");
         L ("         elsif Family /= ""none"" then");
         L ("            return UTF8 ([16#533A#, 16#57DF#, 16#65F6#,");
         L ("              16#95F4#]);");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Family = ""europe-central"" then");
         L ("            return UTF8 ([16#C911#, 16#C559#, 16#20#,");
         L ("              16#C720#, 16#B7FD#, 16#20#, 16#C2DC#,");
         L ("              16#AC04#]);");
         L ("         elsif Family = ""america-eastern"" then");
         L ("            return UTF8 ([16#BD81#, 16#BBF8#, 16#20#,");
         L ("              16#B3D9#, 16#BD80#, 16#20#, 16#C2DC#,");
         L ("              16#AC04#]);");
         L ("         elsif Family /= ""none"" then");
         L ("            return UTF8 ([16#C9C0#, 16#C5ED#, 16#20#,");
         L ("              16#C2DC#, 16#AC04#]);");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      if Family = ""europe-central"" then");
         L ("         return ""Central European Time"";");
         L ("      elsif Family = ""europe-london"" then");
         L ("         return ""Western European Time"";");
         L ("      elsif Family = ""europe-eastern"" then");
         L ("         return ""Eastern European Time"";");
         L ("      elsif Family = ""america-eastern"" then");
         L ("         return ""Eastern Time"";");
         L ("      elsif Family = ""america-central"" then");
         L ("         return ""Central Time"";");
         L ("      elsif Family = ""america-mountain"" then");
         L ("         return ""Mountain Time"";");
         L ("      elsif Family = ""america-pacific"" then");
         L ("         return ""Pacific Time"";");
         L ("      elsif Family = ""america-sao-paulo"" then");
         L ("         return ""Brasilia Time"";");
         L ("      elsif Family = ""pacific-new-zealand"" then");
         L ("         return ""New Zealand Time"";");
         L ("      elsif Family = ""australia-eastern"" then");
         L ("         return ""Eastern Australia Time"";");
         L ("      elsif Family = ""australia-central"" then");
         L ("         return ""Central Australia Time"";");
         L ("      elsif Zone = ""Europe/Moscow"" then");
         L ("         return ""Moscow Time"";");
         L ("      elsif Zone = ""Europe/Istanbul"" then");
         L ("         return ""Turkey Time"";");
         L ("      elsif Zone = ""America/Phoenix"" then");
         L ("         return ""Mountain Standard Time"";");
         L ("      elsif Zone = ""America/Mexico_City"" then");
         L ("         return ""Central Mexico Time"";");
         L ("      elsif Zone = ""America/Bogota"" then");
         L ("         return ""Colombia Time"";");
         L ("      elsif Zone = ""America/Lima"" then");
         L ("         return ""Peru Time"";");
         L ("      elsif Zone = ""America/Sao_Paulo"" then");
         L ("         return ""Brasilia Time"";");
         L ("      elsif Zone = ""America/Argentina/Buenos_Aires"" then");
         L ("         return ""Argentina Time"";");
         L ("      elsif Zone = ""Africa/Johannesburg"" then");
         L ("         return ""South Africa Time"";");
         L ("      elsif Zone = ""Africa/Accra"" then");
         L ("         return ""Ghana Time"";");
         L ("      elsif Zone = ""Africa/Abidjan"" then");
         L ("         return ""Greenwich Mean Time"";");
         L ("      elsif Zone = ""Africa/Algiers"" then");
         L ("         return ""Central European Time"";");
         L ("      elsif Zone = ""Africa/Tunis"" then");
         L ("         return ""Central European Time"";");
         L ("      elsif Zone = ""Africa/Nairobi"" then");
         L ("         return ""East Africa Time"";");
         L ("      elsif Zone = ""Africa/Lagos"" then");
         L ("         return ""West Africa Time"";");
         L ("      elsif Zone = ""Asia/Dubai"" then");
         L ("         return ""Gulf Time"";");
         L ("      elsif Zone = ""Asia/Yerevan"" then");
         L ("         return ""Armenia Time"";");
         L ("      elsif Zone = ""Asia/Tbilisi"" then");
         L ("         return ""Georgia Time"";");
         L ("      elsif Zone = ""Asia/Baku"" then");
         L ("         return ""Azerbaijan Time"";");
         L ("      elsif Zone = ""Asia/Tashkent"" then");
         L ("         return ""Uzbekistan Time"";");
         L ("      elsif Zone = ""Asia/Riyadh"" then");
         L ("         return ""Arabian Time"";");
         L ("      elsif Family = ""asia-jerusalem"" then");
         L ("         return ""Israel Time"";");
         L ("      elsif Family = ""asia-tehran"" then");
         L ("         return ""Iran Time"";");
         L ("      elsif Zone = ""Asia/Shanghai"" then");
         L ("         return ""China Time"";");
         L ("      elsif Zone = ""Asia/Singapore"" then");
         L ("         return ""Singapore Time"";");
         L ("      elsif Zone = ""Asia/Hong_Kong"" then");
         L ("         return ""Hong Kong Time"";");
         L ("      elsif Zone = ""Asia/Taipei"" then");
         L ("         return ""Taipei Time"";");
         L ("      elsif Zone = ""Asia/Kuala_Lumpur"" then");
         L ("         return ""Malaysia Time"";");
         L ("      elsif Zone = ""Asia/Manila"" then");
         L ("         return ""Philippine Time"";");
         L ("      elsif Zone = ""Asia/Bangkok"" then");
         L ("         return ""Indochina Time"";");
         L ("      elsif Zone = ""Asia/Jakarta"" then");
         L ("         return ""Western Indonesia Time"";");
         L ("      elsif Zone = ""Asia/Ho_Chi_Minh"" then");
         L ("         return ""Vietnam Time"";");
         L ("      elsif Zone = ""Asia/Karachi"" then");
         L ("         return ""Pakistan Time"";");
         L ("      elsif Zone = ""Asia/Colombo"" then");
         L ("         return ""Sri Lanka Time"";");
         L ("      elsif Zone = ""Asia/Dhaka"" then");
         L ("         return ""Bangladesh Time"";");
         L ("      elsif Zone = ""Asia/Yangon"" then");
         L ("         return ""Myanmar Time"";");
         L ("      elsif Zone = ""Asia/Kathmandu"" then");
         L ("         return ""Nepal Time"";");
         L ("      elsif Zone = ""Asia/Tokyo"" then");
         L ("         return ""Japan Time"";");
         L ("      elsif Zone = ""Asia/Seoul"" then");
         L ("         return ""Korea Time"";");
         L ("      elsif Zone = ""Asia/Kolkata"" then");
         L ("         return ""India Time"";");
         L ("      elsif Zone = ""Asia/Ulaanbaatar"" then");
         L ("         return ""Ulaanbaatar Time"";");
         L ("      elsif Zone = ""Pacific/Honolulu"" then");
         L ("         return ""Hawaii-Aleutian Time"";");
         L ("      elsif Zone = ""Australia/Brisbane"" then");
         L ("         return ""Eastern Australia Time"";");
         L ("      elsif Zone = ""Australia/Perth"" then");
         L ("         return ""Western Australia Time"";");
         L ("      elsif Zone = ""Australia/Darwin"" then");
         L ("         return ""Central Australia Time"";");
         L ("      else");
         L ("         return Zone;");
         L ("      end if;");
         L ("   end Time_Zone_Display_Name;");
         L;
         --  Both zone functions read the same rows -- standard and daylight
         --  in one pair of fields, generic in the next -- so one payload per
         --  locale serves both rather than emitting the rows twice.
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  Grouped by locale, so a change of locale ends the segment.
            --  Scanning back for a locale already seen walks the whole rule
            --  array per row, which is quadratic over a hundred thousand
            --  rules.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_short_family") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  if US.Length (Rows) > 0 then
                     US.Append (Rows, ";");
                  end if;

                  US.Append
                    (Rows,
                     S (Rules (Index).B) & ","
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).C)) & ","
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).D)) & ","
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).E)));
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Zone_Family_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   --  Which: 1 standard, 2 daylight, 3 generic.");
         L ("   function Zone_Family_Value");
         L ("     (Payload : String;");
         L ("      Family  : String;");
         L ("      Which   : Positive)");
         L ("      return String");
         L ("   is");
         L ("      Start : Positive := Payload'First;");
         L ("      Stop  : Natural;");
         L ("      Last  : Natural;");
         L ("   begin");
         L ("      while Start <= Payload'Last loop");
         L ("         Stop := Start;");
         L ("         while Stop <= Payload'Last and then Payload (Stop) /= ';' loop");
         L ("            Stop := Stop + 1;");
         L ("         end loop;");
         L ("         Last := Stop - 1;");
         L;
         L ("         declare");
         L ("            Sep_1 : Natural := 0;");
         L ("            Sep_2 : Natural := 0;");
         L ("            Sep_3 : Natural := 0;");
         L ("         begin");
         L ("            for Index in Start .. Last loop");
         L ("               if Payload (Index) = ',' then");
         L ("                  if Sep_1 = 0 then");
         L ("                     Sep_1 := Index;");
         L ("                  elsif Sep_2 = 0 then");
         L ("                     Sep_2 := Index;");
         L ("                  else");
         L ("                     Sep_3 := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end if;");
         L ("            end loop;");
         L;
         L ("            if Sep_3 > 0");
         L ("              and then Payload (Start .. Sep_1 - 1) = Family");
         L ("            then");
         L ("               case Which is");
         L ("                  when 1 => return VB (Payload (Sep_1 + 1 .. Sep_2 - 1));");
         L ("                  when 2 => return VB (Payload (Sep_2 + 1 .. Sep_3 - 1));");
         L ("                  when others => return VB (Payload (Sep_3 + 1 .. Last));");
         L ("               end case;");
         L ("            end if;");
         L ("         end;");
         L ("         Start := Stop + 1;");
         L ("      end loop;");
         L;
         L ("      return """";");
         L ("   end Zone_Family_Value;");
         L;
         L ("   function Time_Zone_Short_Name");
         L ("     (Locale   : String;");
         L ("      Family   : String;");
         L ("      Daylight : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      function Find (Cand : String) return String is");
         L ("         Row : constant String := Zone_Family_Row (Cand);");
         L ("      begin");
         L ("         if Row = """" then");
         L ("            return """";");
         L ("         end if;");
         L ("         return Zone_Family_Value (Row, Family, (if Daylight then 2 else 1));");
         L ("      end Find;");
         L;
         L ("      Canon : constant String := Canonical_Locale (Locale);");
         L ("      Exact : constant String := Find (Locale);");
         L ("      Cut : Natural := Canon'Last;");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      while Cut > Canon'First loop");
         L ("         if Canon (Cut) = '-' then");
         L ("            declare");
         L ("               Hit : constant String :=");
         L ("                 Find (Canon (Canon'First .. Cut - 1));");
         L ("            begin");
         L ("               if Hit /= """" then");
         L ("                  return Hit;");
         L ("               end if;");
         L ("            end;");
         L ("         end if;");
         L ("         Cut := Cut - 1;");
         L ("      end loop;");
         L;
         L ("      --  The chain ended on en's rows, which the table holds too.");
         L ("      return Find (""en"");");
         L ("   end Time_Zone_Short_Name;");
         L;
         L ("   function Time_Zone_Generic_Short_Name");
         L ("     (Locale : String;");
         L ("      Family : String)");
         L ("      return String");
         L ("   is");
         L ("      function Find (Cand : String) return String is");
         L ("         Row : constant String := Zone_Family_Row (Cand);");
         L ("      begin");
         L ("         if Row = """" then");
         L ("            return """";");
         L ("         end if;");
         L ("         return Zone_Family_Value (Row, Family, 3);");
         L ("      end Find;");
         L;
         L ("      Canon : constant String := Canonical_Locale (Locale);");
         L ("      Exact : constant String := Find (Locale);");
         L ("      Cut : Natural := Canon'Last;");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      while Cut > Canon'First loop");
         L ("         if Canon (Cut) = '-' then");
         L ("            declare");
         L ("               Hit : constant String :=");
         L ("                 Find (Canon (Canon'First .. Cut - 1));");
         L ("            begin");
         L ("               if Hit /= """" then");
         L ("                  return Hit;");
         L ("               end if;");
         L ("            end;");
         L ("         end if;");
         L ("         Cut := Cut - 1;");
         L ("      end loop;");
         L;
         L ("      --  The chain ended on en's rows, which the table holds too.");
         L ("      return Find (""en"");");
         L ("   end Time_Zone_Generic_Short_Name;");
         L;
         Emit_Locale_Return_Table
           ("Time_Zone_Location_Pattern", "zone_location_pattern",
            """{0} Time""");
         Emit_Locale_Return_Table
           ("GMT_Offset_Prefix", "zone_gmt_prefix", """GMT""");
         L;
         L ("   function Time_Zone_UTC_Designator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""Z"";");
         L ("   end Time_Zone_UTC_Designator;");
         L;
         L ("   function Time_Zone_Offset_Separator (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            declare
               Opened : Boolean := False;
            begin
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "zone_offset_separator") then
                     L
                       ("      "
                        & (if Opened then "elsif " else "if ")
                        & (if Pass = 1
                           then "Locale_Equals"
                           else "Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).A)
                        & """) then");
                     L ("         return " & S (Rules (Index).B) & ";");
                     Opened := True;
                  end if;
               end loop;

               if Opened then
                  L ("      end if;");
                  L;
               end if;
            end;
         end loop;
         L ("      return "":"";");
         L ("   end Time_Zone_Offset_Separator;");
      end Emit_Time_Zone_Data;

      --  Every entry carries one form per plural category, and for most
      --  currencies that is the same word repeated six times: 54% of the
      --  entries are all-identical, and the forms across the whole table
      --  fall from 13.5 million characters to 3.5 million once the repeats
      --  go. Trailing repeats are dropped here; the reader takes the last
      --  form for any category past the end.
      procedure Emit_Symbol_First is
      begin
         L;
         L ("   function Currency_Symbol_First (Locale : String) return Boolean is");
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "symbol_first") then
               L ("      return In_List (Language (Locale), """ & S (Rules (Index).A) & """);");
            end if;
         end loop;
         L ("   end Currency_Symbol_First;");
      end Emit_Symbol_First;

      procedure Emit_Currency_Format_Patterns is
      begin
         L;
         L ("   function Currency_Amount_Separator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return "" "";");
         L ("   end Currency_Amount_Separator;");
         L;
         L ("   function Currency_Accounting_Prefix (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""("";");
         L ("   end Currency_Accounting_Prefix;");
         L;
         L ("   function Currency_Accounting_Suffix (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return "")"";");
         L ("   end Currency_Accounting_Suffix;");
      end Emit_Currency_Format_Patterns;

      procedure Emit_Per_Unit_Separator is
      begin
         --  CLDR root (und) per-unit separator is "/", not English " per ". Only
         --  locales without their own unit_separator rule reach this fallback (en has
         --  an explicit " per " entry), so they must fall back to und, not en.
         Emit_Family_Locale_Table
           ("Per_Unit_Separator", "unit_separator", "per", """/""");
      end Emit_Per_Unit_Separator;

      procedure Emit_Unit_Separators is
      begin
         L;
         L ("   function Unit_Value_Separator (Locale : String) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang = ""ja"" or else Lang = ""zh"" or else Lang = ""ko"" then");
         L ("         return """";");
         L ("      else");
         L ("         return "" "";");
         L ("      end if;");
         L ("   end Unit_Value_Separator;");
         L;
         L ("   function Unit_Short_Per_Separator (Locale : String) return String is");
         L ("      pragma Unreferenced (Locale);");
         L ("   begin");
         L ("      return ""/"";");
         L ("   end Unit_Short_Per_Separator;");
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

      --  18,385 records, scanned whole on each of up to four passes. Same
      --  remedy as the relative time patterns: one segment per locale, and
      --  the locale field drops out of the record.
      --  5,579 rows keyed on locale, base and category. One payload per
      --  locale holds that locale's rows, which is about seven of them, so a
      --  short scan inside the payload replaces a second index.
      --
      --  The order the chain resolved in has to survive: every wanted
      --  category, over the locale and then its parents, before any "other"
      --  row -- so a category found on a parent beats "other" on the locale
      --  itself. That is why the walk is here rather than in the table: the
      --  payload has to be retested at each parent, not just found.
      --  63,970 records, scanned from the first character on every pass and
      --  up to four passes to a lookup, which came to a quarter of a million
      --  record parses to answer one call. The records arrive grouped by
      --  locale, so each locale becomes one segment of the table and a
      --  lookup scans its eighty-odd records instead of all of them. The
      --  locale field goes with it: the segment already says which it is.
      --  The same table, built the other way round: a family names the
      --  locales that use it, so each list is exploded into one entry per
      --  locale. The families themselves repeat across hundreds of locales
      --  and are packed once.
      procedure Emit_Rule_Family (Name : String; Kind : String) is
      begin
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind) then
               declare
                  Locales : constant String := S (Rules (Index).B);
                  Family : constant String :=
                    Ada_Expression_UTF8_Hex
                      ("""" & S (Rules (Index).A) & """");
                  Start : Positive := Locales'First;
               begin
                  for Position in Locales'Range loop
                     if Locales (Position) = ',' then
                        Add_Table_Entry
                          (Locales (Start .. Position - 1), Family);
                        Start := Position + 1;
                     end if;
                  end loop;

                  if Start <= Locales'Last then
                     Add_Table_Entry (Locales (Start .. Locales'Last), Family);
                  end if;
               end;
            end if;
         end loop;

         Emit_Locale_Table (Name, """other-only""");
      end Emit_Rule_Family;

   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Current_File := Output'Unchecked_Access;
      Emit_Static_Prelude;
      Emit_Locale_Return_Table ("Decimal_Separator", "decimal", """.""");
      Emit_Locale_Return_Table ("Group_Separator", "group", """,""");
      Emit_Grouping;
      Emit_Day_Month_Year;
      Emit_Week_Data;
      Emit_Time_Style_Pattern;
      Emit_Date_Time_Field_Separator;
      Emit_Date_Time_Style_Separator;
      Emit_Digits;
      Emit_Number_Display_Affixes;
      Emit_Era_Name;
      Emit_Time_Zone_Data;
      Emit_Currency_Field ("Currency_Minor_Units", 2, "Natural", "2");
      Emit_Currency_Field ("Currency_Cash_Increment", 3, "Natural", "1");
      Emit_Currency_Field ("Currency_Symbol", 4, "String", "Code");
      Emit_Currency_Field ("Currency_Narrow_Symbol", 5, "String", "Currency_Symbol (Code)");
      Emit_Symbol_First;
      Emit_Currency_Format_Patterns;
      Emit_Per_Unit_Separator;
      Emit_Unit_Separators;
      Emit_Byte_Size_Unit_Label;
      Emit_Number_Spellout_Words;
      Emit_Rule_Family ("Cardinal_Rule_Family", "cardinal");
      Emit_Rule_Family ("Ordinal_Rule_Family", "ordinal");
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
   Load_TZDB_Links;
   if Errors = 0 then
      Load_TZDB_Transitions;
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
         Emit_Shards (Unit_Entries, Unit_Count, Units_Dir, "unit");
         Emit_Shards (Zone_Entries, Zone_Count, Zones_Dir, "exemplar");
         Emit_Shards
           (Currency_Entries, Currency_Count, Currency_Dir, "currency");
         Ada.Text_IO.Put_Line ("generated src/i18n-cldr_data.adb");
      end if;
   end;
exception
   when others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to generate CLDR data");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Generate_CLDR_Data;
