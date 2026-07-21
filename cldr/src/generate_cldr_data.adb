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

   --  The two largest lookup functions are emitted as subunits: inline they made the
   --  single body file exceed GitHub's 100 MB per-file limit, so each goes in its own
   --  source file (each well under the limit).
   Currency_Sub_Target    : constant String :=
     "../src/i18n-cldr_data-currency_display_name.adb";
   Currency_Sub_Generated : constant String :=
     "/tmp/i18n_cldr_data-currency_display_name.generated.adb";
   Unit_Sub_Target        : constant String :=
     "../src/i18n-cldr_data-unit_display_name.adb";
   Unit_Sub_Generated     : constant String :=
     "/tmp/i18n_cldr_data-unit_display_name.generated.adb";

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

   --  Set from --locales=; "all" is every locale in the pinned subset.
   Wanted_Locales : US.Unbounded_String := US.To_Unbounded_String ("all");

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
   function Hex_Points_To_Base64 (Hex : String) return String is
      Bytes : US.Unbounded_String;
      Index : Natural := Hex'First;
   begin
      while Index + 3 <= Hex'Last loop
         declare
            Point : constant Natural := Hex_Value (Hex (Index .. Index + 3));
         begin
            if Point <= 16#7F# then
               US.Append (Bytes, Character'Val (Point));
            elsif Point <= 16#7FF# then
               US.Append (Bytes, Character'Val (16#C0# + Point / 64));
               US.Append (Bytes, Character'Val (16#80# + Point mod 64));
            else
               US.Append (Bytes, Character'Val (16#E0# + Point / 4096));
               US.Append
                 (Bytes, Character'Val (16#80# + (Point / 64) mod 64));
               US.Append (Bytes, Character'Val (16#80# + Point mod 64));
            end if;
         end;
         Index := Index + 4;
      end loop;

      return To_Base64 (S (Bytes));
   end Hex_Points_To_Base64;

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

   --  A "~"-separated list of four-hex-digit code points, recoded item by
   --  item so Hex_List_Item still finds its boundaries.
   function Recoded_Point_List (Items : String) return String is
      Result : US.Unbounded_String;
      Start : Positive := Items'First;
   begin
      while Start <= Items'Last loop
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Items'Last and then Items (Stop) /= '~' loop
               Stop := Stop + 1;
            end loop;
            if US.Length (Result) > 0 then
               US.Append (Result, "~");
            end if;
            US.Append
              (Result, Hex_Points_To_Base64 (Items (Start .. Stop - 1)));
            Start := Stop + 1;
         end;
      end loop;

      return S (Result);
   end Recoded_Point_List;

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

   --  --locales=en,de,fr narrows the generated tables; the default is every
   --  locale in the pinned subset. The value comes from the crate
   --  configuration variable of the same name.
   procedure Read_Wanted_Locales is
      Prefix : constant String := "--locales=";
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Argument : constant String := Ada.Command_Line.Argument (Index);
         begin
            if Argument'Length > Prefix'Length
              and then Argument (Argument'First ..
                                   Argument'First + Prefix'Length - 1) = Prefix
            then
               Wanted_Locales :=
                 US.To_Unbounded_String
                   (Argument (Argument'First + Prefix'Length .. Argument'Last));
            end if;
         end;
      end loop;
   end Read_Wanted_Locales;

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

   --  Which locales the generated tables carry. "all" is every locale in the
   --  pinned subset; otherwise a comma-separated list from the crate
   --  configuration. Filtering happens here, at the one place every row
   --  enters, so no emitter has to know about it.
   --
   --  The locale is not in a fixed field, and for some kinds it is a list:
   --
   --    cardinal, ordinal                      field B, a list
   --    digits, day_month_year, indian_grouping,
   --    symbol_first                           field A, a list
   --    name_set_hex                           field B
   --    currency, unit_short                   no locale -- always kept
   --    everything else                        field A
   function Locale_Wanted (Value : String) return Boolean is
      List : constant String := S (Wanted_Locales);
      Start : Positive := List'First;
   begin
      --  Numbering systems and the root rows are not locales and always stay.
      if List = "all"
        or else Value'Length = 0
        or else Starts_With (Value, "nu-")
        or else Value = "und"
        or else Value = "root"
      then
         return True;
      end if;

      for Index in List'Range loop
         if List (Index) = ',' then
            if List (Start .. Index - 1) = Value then
               return True;
            end if;
            Start := Index + 1;
         end if;
      end loop;

      return List (Start .. List'Last) = Value;
   end Locale_Wanted;

   --  A locale list keeps the wanted entries; empty means drop the row.
   function Wanted_Subset (Value : String) return String is
      Result : US.Unbounded_String;
      Start  : Positive := Value'First;

      procedure Take (Item : String) is
      begin
         if Item'Length > 0 and then Locale_Wanted (Item) then
            if US.Length (Result) > 0 then
               US.Append (Result, ",");
            end if;
            US.Append (Result, Item);
         end if;
      end Take;
   begin
      for Index in Value'Range loop
         if Value (Index) = ',' then
            Take (Value (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;
      Take (Value (Start .. Value'Last));

      return S (Result);
   end Wanted_Subset;

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

      if S (Wanted_Locales) /= "all" then
         if Kind = "currency" or else Kind = "unit_short" then
            null;                       --  no locale of its own
         elsif Kind = "cardinal" or else Kind = "ordinal" then
            if Wanted_Subset (B) = "" then
               return;
            end if;
         elsif Kind = "digits"
           or else Kind = "day_month_year"
           or else Kind = "indian_grouping"
           or else Kind = "symbol_first"
         then
            if Wanted_Subset (A) = "" then
               return;
            end if;
         elsif Kind = "name_set_hex" then
            if not Locale_Wanted (B) then
               return;
            end if;
         elsif not Locale_Wanted (A) then
            return;
         end if;
      end if;

      Rule_Count := Rule_Count + 1;
      Rules (Rule_Count) :=
        (Kind => US.To_Unbounded_String (Kind),
         A    =>
           US.To_Unbounded_String
             (if S (Wanted_Locales) /= "all"
                and then (Kind = "digits"
                          or else Kind = "day_month_year"
                          or else Kind = "indian_grouping"
                          or else Kind = "symbol_first")
              then Wanted_Subset (A) else A),
         B    =>
           US.To_Unbounded_String
             (if S (Wanted_Locales) /= "all"
                and then (Kind = "cardinal" or else Kind = "ordinal")
              then Wanted_Subset (B) else B),
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
      Currency_Sub : aliased Ada.Text_IO.File_Type;
      Unit_Sub     : aliased Ada.Text_IO.File_Type;
      --  L writes to whichever file is current: the main body, or a subunit while one is
      --  being emitted.
      Current_File : Ada.Text_IO.File_Access;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Current_File.all, Text);
      end L;

      --  Write the standard subunit header (L must already point at the subunit file).
      procedure Subunit_Header is
      begin
         L ("pragma Style_Checks (Off);");
         L ("pragma Warnings (Off);");
         L ("separate (I18N.CLDR_Data)");
      end Subunit_Header;

      procedure Emit_Static_Prelude is
      begin
         L ("package body I18N.CLDR_Data is");
         L;
         L ("   --  Generated by cldr/src/generate_cldr_data.adb.");
         L ("   --  Source: cldr/data/cldr_subset.txt.");
         L ("   --  Large generated lookup tables intentionally do not follow");
         L ("   --  handwritten Ada style layout.");
         L ("   pragma Style_Checks (Off);");
         L ("   pragma Warnings (Off);");
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
         L ("   function Hex_Value (C : Character) return Natural is");
         L ("   begin");
         L ("      if C in '0' .. '9' then");
         L ("         return Character'Pos (C) - Character'Pos ('0');");
         L ("      elsif C in 'A' .. 'F' then");
         L ("         return Character'Pos (C) - Character'Pos ('A') + 10;");
         L ("      else");
         L ("         return Character'Pos (C) - Character'Pos ('a') + 10;");
         L ("      end if;");
         L ("   end Hex_Value;");
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
         L ("   function H (Hex : String) return String is");
         L ("      First : constant Positive := Hex'First;");
         L ("   begin");
         L ("      if Hex'Length = 0 then");
         L ("         return """";");
         L ("      else");
         L ("         return");
         L ("           U (Hex_Value (Hex (First)) * 4096");
         L ("              + Hex_Value (Hex (First + 1)) * 256");
         L ("              + Hex_Value (Hex (First + 2)) * 16");
         L ("              + Hex_Value (Hex (First + 3)))");
         L ("           & H (Hex (First + 4 .. Hex'Last));");
         L ("      end if;");
         L ("   end H;");
         L;
         L ("   function HB (Hex : String) return String is");
         L ("   begin");
         L ("      if Hex'Length = 0 then");
         L ("         return """";");
         L ("      else");
         L ("         declare");
         L ("            Result : String (1 .. Hex'Length / 2);");
         L ("            Source : Natural;");
         L ("         begin");
         L ("            for Index in Result'Range loop");
         L ("               Source := Hex'First + (Index - Result'First) * 2;");
         L ("               Result (Index) :=");
         L ("                 Character'Val");
         L ("                   (Hex_Value (Hex (Source)) * 16");
         L ("                    + Hex_Value (Hex (Source + 1)));");
         L ("            end loop;");
         L ("            return Result;");
         L ("         end;");
         L ("      end if;");
         L ("   end HB;");
         L;
         L ("   function Currency_Name_From_Payload");
         L ("     (Payload  : String;");
         L ("      Code     : String;");
         L ("      Category : String)");
         L ("      return String");
         L ("   is");
         L ("      Start : Positive := Payload'First;");
         L ("      Stop  : Natural;");
         L ("      Last  : Natural;");
         L ("      Slot_Start : Natural;");
         L ("      Slot_End   : Natural;");
         L ("      Slot       : Positive;");
         L ("   begin");
         L ("      if Code'Length /= 3 then");
         L ("         return """";");
         L ("      end if;");
         L;
         L ("      if Category = ""zero"" then");
         L ("         Slot := 1;");
         L ("      elsif Category = ""one"" then");
         L ("         Slot := 2;");
         L ("      elsif Category = ""two"" then");
         L ("         Slot := 3;");
         L ("      elsif Category = ""few"" then");
         L ("         Slot := 4;");
         L ("      elsif Category = ""many"" then");
         L ("         Slot := 5;");
         L ("      else");
         L ("         Slot := 6;");
         L ("      end if;");
         L;
         L ("      while Start <= Payload'Last loop");
         L ("         Stop := Start;");
         L ("         while Stop <= Payload'Last and then Payload (Stop) /= ';' loop");
         L ("            Stop := Stop + 1;");
         L ("         end loop;");
         L ("         Last := Stop - 1;");
         L;
         L ("         if Last >= Start + 4");
         L ("           and then Payload (Start .. Start + 2) = Code");
         L ("           and then Payload (Start + 3) = ':'");
         L ("         then");
         L ("            Slot_Start := Start + 4;");
         L ("            Slot_End := Last;");
         L ("            for Current in 1 .. Slot loop");
         L ("               Slot_End := Last;");
         L ("               for Index in Slot_Start .. Last loop");
         L ("                  if Payload (Index) = ',' then");
         L ("                     Slot_End := Index - 1;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Current = Slot then");
         L ("                  if Slot_End >= Slot_Start then");
         L ("                     return VB (Payload (Slot_Start .. Slot_End));");
         L ("                  end if;");
         L ("                  return """";");
         L ("               end if;");
         L;
         L ("               --  Fewer forms than categories means the trailing");
         L ("               --  ones repeated the last, so the last answers for");
         L ("               --  every category past the end.");
         L ("               if Slot_End = Last then");
         L ("                  if Slot_End >= Slot_Start then");
         L ("                     return VB (Payload (Slot_Start .. Slot_End));");
         L ("                  end if;");
         L ("                  return """";");
         L ("               end if;");
         L ("               Slot_Start := Slot_End + 2;");
         L ("            end loop;");
         L ("         end if;");
         L;
         L ("         Start := Stop + 1;");
         L ("      end loop;");
         L;
         L ("      return """";");
         L ("   end Currency_Name_From_Payload;");
         L;
         L ("   function Hex_List_Item (Items : String; Number : Positive) return String is");
         L ("      Start : Positive := Items'First;");
         L ("      Count : Positive := 1;");
         L ("   begin");
         L ("      for Index in Items'Range loop");
         L ("         if Items (Index) = '~' then");
         L ("            if Count = Number then");
         L ("               if Index = Start then");
         L ("                  return """";");
         L ("               else");
         L ("                  return VB (Items (Start .. Index - 1));");
         L ("               end if;");
         L ("            end if;");
         L;
         L ("            Count := Count + 1;");
         L ("            if Index < Items'Last then");
         L ("               Start := Index + 1;");
         L ("            else");
         L ("               Start := Items'Last;");
         L ("            end if;");
         L ("         end if;");
         L ("      end loop;");
         L;
         L ("      if Count = Number and then Start <= Items'Last then");
         L ("         return VB (Items (Start .. Items'Last));");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Hex_List_Item;");
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
      procedure Emit_Label_Index
        (Literal_Name : String;
         Names        : Label_Array;
         Count        : Natural;
         Key_Width    : Positive;
         Code_Width   : Positive)
      is
         Index_Text : US.Unbounded_String;
      begin
         for Position in 1 .. Count loop
            declare
               Name : constant String := S (Names (Position));
            begin
               if Name'Length > Key_Width then
                  Add_Error ("label does not fit the index: " & Name);
               end if;
               US.Append (Index_Text, Name);
               US.Append (Index_Text, [1 .. Key_Width - Name'Length => ' ']);
               US.Append
                 (Index_Text, Label_Code (Names, Count, Name, Code_Width));
            end;
         end loop;

         L ("      " & Literal_Name & " : constant String :=");
         Emit_Unit_String_Expression ("        ", S (Index_Text), ";");
      end Emit_Label_Index;

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
         L ("         else Cand & (1 .. 14 - Cand'Length => ' '));");
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
         L ("         if Cand'Length = 0 or else Count = 0 then");
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
      procedure Emit_Selected_Locale_Table
        (Name         : String;
         Kind         : String;
         Family       : String;
         Part         : String;
         Default_Expr : String)
      is
      begin
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind)
              and then S (Rules (Index).B) = Family
              and then S (Rules (Index).C) = Part
            then
               Add_Table_Entry
                 (S (Rules (Index).A),
                  Ada_Expression_UTF8_Hex (S (Rules (Index).D)));
            end if;
         end loop;
         Emit_Locale_Table (Name, Default_Expr);
      end Emit_Selected_Locale_Table;

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
      begin
         L;
         L ("   function Uses_Indian_Grouping (Locale : String) return Boolean is");
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "indian_grouping") then
               L ("      return In_List (Language (Locale), """ & S (Rules (Index).A) & """)");
               L ("        or else Contains (Locale, """ & S (Rules (Index).B) & """);");
            end if;
         end loop;
         L ("   end Uses_Indian_Grouping;");
      end Emit_Grouping;

      procedure Emit_Day_Month_Year is
      begin
         L;
         L ("   function Uses_Day_Month_Year (Locale : String) return Boolean is");
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "day_month_year") then
               L ("      return In_List (Language (Locale), """ & S (Rules (Index).A) & """);");
            end if;
         end loop;
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
      procedure Emit_Date_Style_Pattern is
         Cal_Names : Label_Array;
         Cal_Count : Natural;
         Style_Names : Label_Array;
         Style_Count : Natural;
      begin
         Collect_Labels ("date_style_pattern", 2, Cal_Names, Cal_Count);
         Collect_Labels ("date_style_pattern", 3, Style_Names, Style_Count);
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  Grouped by locale, so a change of locale ends the segment.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "date_style_pattern") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Cal_Names, Cal_Count, S (Rules (Index).B), 1)
                     & Label_Code (Style_Names, Style_Count,
                                   S (Rules (Index).C), 1)
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).D)) & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Date_Style_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   --  CLDR's own dateFormats, by locale and calendar. The heuristic");
         L ("   --  below is the fallback for locales outside the pinned subset:");
         L ("   --  it can only choose between a day-month-year and a");
         L ("   --  month-day-year shape, which is not what every locale writes.");
         L ("   function Date_Style_Pattern");
         L ("     (Locale   : String;");
         L ("      Calendar : String;");
         L ("      Style    : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      DMY : constant Boolean := Uses_Day_Month_Year (Locale);");
         L;
         L ("      --  calendar|style|pattern, one run per locale. A calendar");
         L ("      --  the locale does not carry falls back to gregorian, which");
         L ("      --  is why the scan finishes the segment before answering.");
         L ("      function Cal_Code (Want : String) return String is");
         for Position in 1 .. Cal_Count loop
            L ("        " & (if Position = 1 then "(if" else " elsif")
               & " Want = """ & S (Cal_Names (Position)) & """ then """
               & Label_Code (Cal_Names, Cal_Count,
                             S (Cal_Names (Position)), 1) & """");
         end loop;
         L ("         else "" "");");
         L;
         Emit_Label_Chain ("Style_Code", "Style", Style_Names, Style_Count, 1);
         L;
         L ("      Gregorian_Code : constant String := """
            & Label_Code (Cal_Names, Cal_Count, "gregorian", 1) & """;");
         L;
         L ("      --  calendar and style as one coded character each, then the");
         L ("      --  hex. A calendar the locale does not carry falls back to");
         L ("      --  gregorian, so the scan finishes before answering.");
         L ("      function In_Rows (Rows : String; Wanted_Calendar : String)");
         L ("         return String");
         L ("      is");
         L ("         Start : Positive := Rows'First;");
         L ("         Fallback_First : Natural := 0;");
         L ("         Fallback_Last : Natural := 0;");
         L ("         Wanted : constant String := Cal_Code (Wanted_Calendar);");
         L ("         Styled : constant String := Style_Code;");
         L ("      begin");
         L ("         if Styled = "" "" then");
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
         L ("               exit when Stop <= Start + 2;");
         L ("               if Rows (Start + 1) = Styled (Styled'First) then");
         L ("                  declare");
         L ("                     Cal : constant String := Rows (Start .. Start);");
         L ("                  begin");
         L ("                     if Cal = Wanted then");
         L ("                        return VB (Rows (Start + 2 .. Stop - 1));");
         L ("                     elsif Cal = Gregorian_Code then");
         L ("                        Fallback_First := Start + 2;");
         L ("                        Fallback_Last := Stop - 1;");
         L ("                     end if;");
         L ("                  end;");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         if Fallback_First /= 0 then");
         L ("            return VB (Rows (Fallback_First .. Fallback_Last));");
         L ("         end if;");
         L ("         return """";");
         L ("      end In_Rows;");
         L;
         L ("      --  The locale, then each parent, longest first.");
         L ("      function Search (Wanted_Calendar : String) return String is");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("         Exact : constant String :=");
         L ("           In_Rows (Date_Style_Row (Locale), Wanted_Calendar);");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L;
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    In_Rows");
         L ("                      (Date_Style_Row (Canon (Canon'First .. Cut - 1)),");
         L ("                       Wanted_Calendar);");
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
         L ("      end Search;");
         L;
         L ("      Effective_Calendar : constant String :=");
         L ("        (if Calendar = """" then ""gregorian"" else Calendar);");
         L ("      Found : constant String := Search (Effective_Calendar);");
         L ("   begin");
         L ("      if Found /= """" then");
         L ("         return Found;");
         L ("      end if;");
         L;
         L ("      --  Outside the pinned subset, fall back to the old shape rule.");
         L ("      if In_List (Lang, ""ja,zh"") then");
         L ("         if Style = ""short"" then");
         L ("            return ""yy'/'M'/'d"";");
         L ("         elsif Style = ""full"" then");
         L ("            return ""y'"" & U (16#5E74#) & ""'M'"" "
            & "& U (16#6708#) & ""'d'"" & U (16#65E5#) & ""'EEEE"";");
         L ("         else");
         L ("            return ""y'"" & U (16#5E74#) & ""'M'"" "
            & "& U (16#6708#) & ""'d'"" & U (16#65E5#) & ""'"";");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Style = ""short"" then");
         L ("            return ""yy'/'M'/'d"";");
         L ("         elsif Style = ""full"" then");
         L ("            return ""y'"" & U (16#B144#) & "" 'M'"" "
            & "& U (16#C6D4#) & "" 'd'"" & U (16#C77C#) "
            & "& "" 'EEEE"";");
         L ("         else");
         L ("            return ""y'"" & U (16#B144#) & "" 'M'"" "
            & "& U (16#C6D4#) & "" 'd'"" & U (16#C77C#) & ""'"";");
         L ("         end if;");
         L ("      elsif DMY then");
         L ("         if Style = ""short"" then");
         L ("            return ""dd'.'MM'.'yy"";");
         L ("         elsif Style = ""long"" or else Style = ""full"" then");
         L ("            if Style = ""full"" then");
         L ("               return ""EEEE', 'd'. 'MMMM' 'yyyy"";");
         L ("            else");
         L ("               return ""d'. 'MMMM' 'yyyy"";");
         L ("            end if;");
         L ("         else");
         L ("            return ""dd'.'MM'.'yyyy"";");
         L ("         end if;");
         L ("      else");
         L ("         if Style = ""short"" then");
         L ("            return ""M'/'d'/'yy"";");
         L ("         elsif Style = ""long"" or else Style = ""full"" then");
         L ("            if Style = ""full"" then");
         L ("               return ""EEEE', 'MMMM' 'd', 'yyyy"";");
         L ("            else");
         L ("               return ""MMMM' 'd', 'yyyy"";");
         L ("            end if;");
         L ("         elsif Style = ""medium"" then");
         L ("            return ""MMMM' 'd', 'yyyy"";");
         L ("         else");
         L ("            return ""yyyy'-'MM'-'dd"";");
         L ("         end if;");
         L ("      end if;");
         L ("   end Date_Style_Pattern;");
         L;
         L ("   function Date_Style_Pattern");
         L ("     (Locale : String;");
         L ("      Style  : String)");
         L ("      return String is");
         L ("   begin");
         L ("      return Date_Style_Pattern (Locale, ""gregorian"", Style);");
         L ("   end Date_Style_Pattern;");
      end Emit_Date_Style_Pattern;

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
      procedure Emit_Available_Format_Pattern is
         Values : US.Unbounded_String;
         Locale_Index : US.Unbounded_String;
         Skeleton_Index : US.Unbounded_String;

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

         function Skeleton_Seen_Before (Index : Positive) return Boolean is
         begin
            for Prior in 1 .. Index - 1 loop
               if Is_Kind (Prior, "available_format")
                 and then S (Rules (Prior).B) = S (Rules (Index).B)
               then
                  return True;
               end if;
            end loop;

            return False;
         end Skeleton_Seen_Before;
      begin
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "available_format")
              and then not Skeleton_Seen_Before (Index)
            then
               declare
                  Skeleton : constant String := S (Rules (Index).B);
                  --  Row numbers, so this must track the index record
                  --  width that Pack_Table writes.
                  First_Row : constant Natural :=
                    US.Length (Locale_Index) / Index_Record_Width + 1;
                  Last_Row : Natural;
               begin
                  if Skeleton'Length > 8 then
                     Add_Error ("skeleton does not fit the index: " & Skeleton);
                  end if;

                  Reset_Table;
                  for Row in 1 .. Rule_Count loop
                     if Is_Kind (Row, "available_format")
                       and then S (Rules (Row).B) = Skeleton
                     then
                        Add_Table_Entry
                          (S (Rules (Row).A),
                           Ada_Expression_UTF8_Hex (S (Rules (Row).C)));
                     end if;
                  end loop;

                  --  Values and the locale index accumulate across skeletons,
                  --  so a pattern already packed for an earlier skeleton is
                  --  reused rather than stored again.
                  Pack_Table (Values, Locale_Index);
                  Last_Row := US.Length (Locale_Index) / Index_Record_Width;

                  declare
                     F : constant String := Trim (Natural'Image (First_Row));
                     T : constant String := Trim (Natural'Image (Last_Row));
                  begin
                     US.Append (Skeleton_Index, Skeleton);
                     US.Append
                       (Skeleton_Index, [1 .. 8 - Skeleton'Length => ' ']);
                     US.Append (Skeleton_Index, [1 .. 7 - F'Length => '0']);
                     US.Append (Skeleton_Index, F);
                     US.Append (Skeleton_Index, [1 .. 7 - T'Length => '0']);
                     US.Append (Skeleton_Index, T);
                  end;
               end;
            end if;
         end loop;

         L;
         L ("   function Available_Format_Pattern");
         L ("     (Locale   : String;");
         L ("      Skeleton : String)");
         L ("      return String");
         L ("   is");
         L ("      Values : constant String :=");
         Emit_String_Expression ("        ", S (Values), ";");
         L ("      Locale_Index : constant String :=");
         Emit_String_Expression ("        ", S (Locale_Index), ";");
         L ("      Skeleton_Index : constant String :=");
         Emit_String_Expression ("        ", S (Skeleton_Index), ";");
         L ("      Width : constant := " & Trim (Integer'Image (Index_Record_Width)) & ";");
         L ("      Skeleton_Width : constant := 22;");
         L ("      Skeleton_Count : constant Natural :=");
         L ("        Skeleton_Index'Length / Skeleton_Width;");
         L;
         L ("      --  The segment of Locale_Index holding the wanted skeleton.");
         L ("      Segment_First : Natural := 0;");
         L ("      Segment_Last : Natural := 0;");
         L;
         L ("      function Key (N : Positive) return String is");
         L ("        (Locale_Index (Locale_Index'First + (N - 1) * Width ..");
         L ("                      Locale_Index'First + (N - 1) * Width + 13));");
         L;
         L ("      function Padded (Cand : String) return String is");
         L ("        (if Cand'Length >= 14 then Cand (Cand'First .. Cand'First + 13)");
         L ("         else Cand & (1 .. 14 - Cand'Length => ' '));");
         L;
         L ("      function Value_At (N : Positive) return String is");
         L ("         Base : constant Natural :=");
         L ("           Locale_Index'First + (N - 1) * Width + 14;");
         L ("         F : constant Natural :=");
         L ("           N62 (Locale_Index (Base .. Base + 4));");
         L ("         T : constant Natural :=");
         L ("           N62 (Locale_Index (Base + 5 .. Base + 9));");
         L ("      begin");
         L ("         return VB (Values (F .. T));");
         L ("      end Value_At;");
         L;
         L ("      function Lookup (Cand : String) return String is");
         L ("         Low : Natural := Segment_First;");
         L ("         High : Natural := Segment_Last;");
         L ("         Mid : Natural;");
         L ("      begin");
         L ("         if Cand'Length = 0 or else Segment_First = 0 then");
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

         L ("   begin");
         L ("      --  A couple of dozen skeletons: a scan costs less than the");
         L ("      --  arithmetic to bisect them.");
         L ("      for N in 1 .. Skeleton_Count loop");
         L ("         declare");
         L ("            Base : constant Natural :=");
         L ("              Skeleton_Index'First + (N - 1) * Skeleton_Width;");
         L ("            Name : constant String :=");
         L ("              Skeleton_Index (Base .. Base + 7);");
         L ("            Stop : Natural := Name'Last;");
         L ("         begin");
         L ("            while Stop >= Name'First and then Name (Stop) = ' ' loop");
         L ("               Stop := Stop - 1;");
         L ("            end loop;");
         L ("            if Name (Name'First .. Stop) = Skeleton then");
         L ("               Segment_First :=");
         L ("                 Natural'Value");
         L ("                   (Skeleton_Index (Base + 8 .. Base + 14));");
         L ("               Segment_Last :=");
         L ("                 Natural'Value");
         L ("                   (Skeleton_Index (Base + 15 .. Base + 21));");
         L ("               exit;");
         L ("            end if;");
         L ("         end;");
         L ("      end loop;");
         L;
         L ("      if Segment_First = 0 then");
         L ("         return """";");
         L ("      end if;");
         L;
         L ("      declare");
         L ("         Exact : constant String := Lookup (Locale);");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      --  Then each parent, longest first, which is the order the");
         L ("      --  Fallback_Depth loop went in.");
         L ("      declare");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    Lookup (Canon (Canon'First .. Cut - 1));");
         L ("               begin");
         L ("                  if Hit /= """" then");
         L ("                     return Hit;");
         L ("                  end if;");
         L ("               end;");
         L ("            end if;");
         L ("            Cut := Cut - 1;");
         L ("         end loop;");
         L ("      end;");
         L;
         L ("      return """";");
         L ("   end Available_Format_Pattern;");
      end Emit_Available_Format_Pattern;

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

      procedure Emit_Date_Name_Function
        (Name         : String;
         Kind         : String;
         Index_Name   : String;
         Default_Kind : String)
      is
         Start_Index : Integer := -1;

         procedure Emit_Return
           (Expression : String;
            Indent     : String := "         ")
         is
            Term_Number : Positive := 1;
         begin
            if Field (Expression, 2, '&') = "" then
               L (Indent & "return " & Expression & ";");
               return;
            end if;

            L (Indent & "return");
            while Field (Expression, Term_Number, '&') /= "" loop
               declare
                  Current : constant String := Trim (Field (Expression, Term_Number, '&'));
                  Next    : constant String := Field (Expression, Term_Number + 1, '&');
               begin
                  L (Indent & "  " & (if Term_Number = 1 then "" else "& ")
                     & Current & (if Next = "" then ";" else ""));
               end;
               Term_Number := Term_Number + 1;
            end loop;
         end Emit_Return;

         --  A handful of languages (Chakma, Adlam, ...) carry names the packed
         --  locale rows do not, keyed by language and index. The chain that
         --  compared Lang to each in turn becomes a bisected override table:
         --  the key is the language left-justified in a fixed field followed by
         --  one index character (so it orders by language, then index), and the
         --  name is the row's evaluated UTF-8, packed once and VB-decoded. A
         --  miss falls through to the English case, exactly as the chain did.
         procedure Emit_Override_Table is
            Max_Overrides : constant := 512;
            type Override_Entry is record
               Key   : US.Unbounded_String;
               Value : US.Unbounded_String;
               First : Natural := 0;
               Last  : Natural := 0;
            end record;

            Items      : array (1 .. Max_Overrides) of Override_Entry;
            Count      : Natural := 0;
            Lang_Width : Natural := 0;
            Max_Index  : Natural := 0;

            Names     : US.Unbounded_String;
            Overrides : US.Unbounded_String;
         begin
            --  Widths first: the language field is as wide as the widest code,
            --  and the guard below rejects an index the table never carries.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, Kind) then
                  Lang_Width :=
                    Natural'Max (Lang_Width, S (Rules (Index).A)'Length);
                  Max_Index :=
                    Natural'Max
                      (Max_Index, Decimal_Value (S (Rules (Index).B)));
               end if;
            end loop;

            if Lang_Width = 0 then
               return;
            end if;

            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, Kind) then
                  declare
                     Lang : constant String := S (Rules (Index).A);
                     Idx  : constant Natural :=
                       Decimal_Value (S (Rules (Index).B));
                  begin
                     Count := Count + 1;
                     Items (Count).Key :=
                       US.To_Unbounded_String
                         (Lang & (1 .. Lang_Width - Lang'Length => ' ')
                          & (1 => Character'Val (Character'Pos ('0') + Idx)));
                     Items (Count).Value :=
                       US.To_Unbounded_String
                         (Ada_Expression_UTF8_Hex (S (Rules (Index).C)));
                  end;
               end if;
            end loop;

            --  Sorted by key so the emitted body can bisect.
            for Outer in 2 .. Count loop
               declare
                  Current     : constant Override_Entry := Items (Outer);
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

            --  Pack the value store and the fixed-width index; repeats share
            --  one copy.
            for N in 1 .. Count loop
               US.Append (Overrides, S (Items (N).Key));
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
                     Items (N).First := US.Length (Names) + 1;
                     Items (N).Last := US.Length (Names) + Packed'Length;
                     US.Append (Names, Packed);
                  end;
               end if;

               US.Append (Overrides, To_Base62 (Items (N).First, 5));
               US.Append (Overrides, To_Base62 (Items (N).Last, 5));
            end loop;

            L ("      declare");
            L ("         Names : constant String :=");
            Emit_Unit_String_Expression ("           ", S (Names), ";");
            L ("         Overrides : constant String :=");
            Emit_Unit_String_Expression ("           ", S (Overrides), ";");
            L ("         Lang_Width : constant := "
               & Trim (Integer'Image (Lang_Width)) & ";");
            L ("         Width : constant := Lang_Width + 11;");
            L ("         Count : constant Natural := Overrides'Length / Width;");
            L;
            L ("         function Key (N : Positive) return String is");
            L ("           (Overrides (Overrides'First + (N - 1) * Width ..");
            L ("                       Overrides'First + (N - 1) * Width"
               & " + Lang_Width));");
            L;
            L ("         function Value_At (N : Positive) return String is");
            L ("            Base : constant Natural :=");
            L ("              Overrides'First + (N - 1) * Width + Lang_Width + 1;");
            L ("            F : constant Natural :=");
            L ("              N62 (Overrides (Base .. Base + 4));");
            L ("            T : constant Natural :=");
            L ("              N62 (Overrides (Base + 5 .. Base + 9));");
            L ("         begin");
            L ("            return VB (Names (F .. T));");
            L ("         end Value_At;");
            L;
            L ("         Low : Natural := 1;");
            L ("         High : Natural := Count;");
            L ("         Mid : Natural;");
            L ("      begin");
            L ("         if Lang'Length <= Lang_Width and then " & Index_Name
               & " <= " & Trim (Integer'Image (Max_Index)) & " then");
            L ("            declare");
            L ("               Wanted : constant String :=");
            L ("                 Lang & (1 .. Lang_Width - Lang'Length => ' ')");
            L ("                 & (1 => Character'Val (Character'Pos ('0') + "
               & Index_Name & "));");
            L ("            begin");
            L ("               while Low <= High loop");
            L ("                  Mid := (Low + High) / 2;");
            L ("                  if Key (Mid) = Wanted then");
            L ("                     return Value_At (Mid);");
            L ("                  elsif Key (Mid) < Wanted then");
            L ("                     Low := Mid + 1;");
            L ("                  else");
            L ("                     High := Mid - 1;");
            L ("                  end if;");
            L ("               end loop;");
            L ("            end;");
            L ("         end if;");
            L ("      end;");
            L;
         end Emit_Override_Table;
      begin
         --  The start index is the same for every locale of a kind, so it is
         --  a literal in the emitted function rather than a column.
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "name_set_hex")
              and then S (Rules (Index).A) = Kind
            then
               if Start_Index < 0 then
                  Start_Index := Decimal_Value (S (Rules (Index).C));
               elsif Decimal_Value (S (Rules (Index).C)) /= Start_Index then
                  Add_Error ("start index varies by locale for " & Kind);
               end if;

               --  Raw: the row is already a hex blob that Hex_List_Item
               --  parses, so it is stored as it stands.
               Add_Table_Entry
                 (S (Rules (Index).B),
                  Recoded_Point_List (S (Rules (Index).D)));
            end if;
         end loop;

         if Start_Index < 0 then
            Start_Index := 0;
         end if;
         Emit_Locale_Table (Name & "_Row", """""", Raw => True);

         L;
         L ("   function " & Name & " (Locale : String; " & Index_Name & " : Natural) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Row : constant String := " & Name & "_Row (Locale);");
         L ("   begin");
         L ("      if Row /= """" then");
         L ("         if " & Index_Name & " < " & Trim (Integer'Image (Start_Index))
            & " then");
         L ("            return """";");
         L ("         end if;");
         L;
         L ("         --  Hex_List_Item answers """" past the end of the row, so");
         L ("         --  only the low bound needs a guard here -- and it does");
         L ("         --  need one, since Number is Positive.");
         L ("         return Hex_List_Item");
         L ("           (Row, " & Index_Name & " - " & Trim (Integer'Image (Start_Index))
            & " + 1);");
         L ("      end if;");
         L;
         Emit_Override_Table;

         L ("      case " & Index_Name & " is");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Default_Kind) and then S (Rules (Index).A) = "en" then
               L ("         when " & S (Rules (Index).B) & " =>");
               Emit_Return (S (Rules (Index).C), "            ");
            end if;
         end loop;
         L ("         when others => return """";");
         L ("      end case;");
         L ("   end " & Name & ";");
      end Emit_Date_Name_Function;

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

      procedure Emit_Quarter_Name is
         Quarter_Start : Integer := -1;
         Quarter_Short_Start : Integer := -1;

         --  The start index is the same for every locale of a kind, as it is
         --  for the month and weekday rows.
         procedure Collect_Quarter_Rows (Kind : String; Start : in out Integer)
         is
         begin
            Reset_Table;
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "name_set_hex")
                 and then S (Rules (Index).A) = Kind
               then
                  if Start < 0 then
                     Start := Decimal_Value (S (Rules (Index).C));
                  elsif Decimal_Value (S (Rules (Index).C)) /= Start then
                     Add_Error ("start index varies by locale for " & Kind);
                  end if;

                  Add_Table_Entry
                    (S (Rules (Index).B),
                     Recoded_Point_List (S (Rules (Index).D)));
               end if;
            end loop;

            if Start < 0 then
               Start := 1;
            end if;
         end Collect_Quarter_Rows;

         --  A few languages carry per-quarter names the packed locale rows do
         --  not. The old body scanned them twice -- every row for an exact
         --  locale match, then every row for a fallback match. Both passes
         --  become one bisected table keyed on the canonical locale (in a fixed
         --  field) plus one quarter character; the emitted body probes the
         --  exact locale, then each parent, which is the exact/fallback order
         --  the two passes had and the shape every other locale table already
         --  uses. A miss falls through to the language block below.
         procedure Emit_Override_Table (Kind : String) is
            Max_Overrides : constant := 512;
            type Override_Entry is record
               Key   : US.Unbounded_String;
               Value : US.Unbounded_String;
               First : Natural := 0;
               Last  : Natural := 0;
            end record;

            Items     : array (1 .. Max_Overrides) of Override_Entry;
            Count     : Natural := 0;
            Loc_Width : Natural := 0;
            Max_Index : Natural := 0;

            Names     : US.Unbounded_String;
            Overrides : US.Unbounded_String;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, Kind) then
                  Loc_Width :=
                    Natural'Max
                      (Loc_Width, Canonical_Key (S (Rules (Index).A))'Length);
                  Max_Index :=
                    Natural'Max
                      (Max_Index, Decimal_Value (S (Rules (Index).B)));
               end if;
            end loop;

            if Loc_Width = 0 then
               return;
            end if;

            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, Kind) then
                  declare
                     Loc : constant String :=
                       Canonical_Key (S (Rules (Index).A));
                     Idx : constant Natural :=
                       Decimal_Value (S (Rules (Index).B));
                  begin
                     Count := Count + 1;
                     Items (Count).Key :=
                       US.To_Unbounded_String
                         (Loc & (1 .. Loc_Width - Loc'Length => ' ')
                          & (1 => Character'Val (Character'Pos ('0') + Idx)));
                     Items (Count).Value :=
                       US.To_Unbounded_String
                         (Ada_Expression_UTF8_Hex (S (Rules (Index).C)));
                  end;
               end if;
            end loop;

            --  Sorted by key so the emitted body can bisect.
            for Outer in 2 .. Count loop
               declare
                  Current     : constant Override_Entry := Items (Outer);
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
               US.Append (Overrides, S (Items (N).Key));
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
                     Items (N).First := US.Length (Names) + 1;
                     Items (N).Last := US.Length (Names) + Packed'Length;
                     US.Append (Names, Packed);
                  end;
               end if;

               US.Append (Overrides, To_Base62 (Items (N).First, 5));
               US.Append (Overrides, To_Base62 (Items (N).Last, 5));
            end loop;

            L ("      declare");
            L ("         Names : constant String :=");
            Emit_Unit_String_Expression ("           ", S (Names), ";");
            L ("         Overrides : constant String :=");
            Emit_Unit_String_Expression ("           ", S (Overrides), ";");
            L ("         Loc_Width : constant := "
               & Trim (Integer'Image (Loc_Width)) & ";");
            L ("         Width : constant := Loc_Width + 11;");
            L ("         Count : constant Natural := Overrides'Length / Width;");
            L;
            L ("         function Key (N : Positive) return String is");
            L ("           (Overrides (Overrides'First + (N - 1) * Width ..");
            L ("                       Overrides'First + (N - 1) * Width"
               & " + Loc_Width));");
            L;
            L ("         function Value_At (N : Positive) return String is");
            L ("            Base : constant Natural :=");
            L ("              Overrides'First + (N - 1) * Width + Loc_Width + 1;");
            L ("            F : constant Natural :=");
            L ("              N62 (Overrides (Base .. Base + 4));");
            L ("            T : constant Natural :=");
            L ("              N62 (Overrides (Base + 5 .. Base + 9));");
            L ("         begin");
            L ("            return VB (Names (F .. T));");
            L ("         end Value_At;");
            L;
            L ("         function Lookup (Cand : String) return String is");
            L ("            Low : Natural := 1;");
            L ("            High : Natural := Count;");
            L ("            Mid : Natural;");
            L ("         begin");
            L ("            if Cand'Length = 0 or else Cand'Length > Loc_Width"
               & " then");
            L ("               return """";");
            L ("            end if;");
            L ("            declare");
            L ("               Wanted : constant String :=");
            L ("                 Cand & (1 .. Loc_Width - Cand'Length => ' ')");
            L ("                 & (1 => Character'Val"
               & " (Character'Pos ('0') + Quarter));");
            L ("            begin");
            L ("               while Low <= High loop");
            L ("                  Mid := (Low + High) / 2;");
            L ("                  if Key (Mid) = Wanted then");
            L ("                     return Value_At (Mid);");
            L ("                  elsif Key (Mid) < Wanted then");
            L ("                     Low := Mid + 1;");
            L ("                  else");
            L ("                     High := Mid - 1;");
            L ("                  end if;");
            L ("               end loop;");
            L ("            end;");
            L ("            return """";");
            L ("         end Lookup;");
            L;
            L ("         Canon : constant String := Canonical_Locale (Locale);");
            L ("         Cut : Natural := Canon'Last;");
            L ("      begin");
            L ("         if Quarter <= " & Trim (Integer'Image (Max_Index))
               & " then");
            L ("            declare");
            L ("               Hit : constant String := Lookup (Canon);");
            L ("            begin");
            L ("               if Hit /= """" then");
            L ("                  return Hit;");
            L ("               end if;");
            L ("            end;");
            L;
            L ("            while Cut > Canon'First loop");
            L ("               if Canon (Cut) = '-' then");
            L ("                  declare");
            L ("                     Hit : constant String :=");
            L ("                       Lookup (Canon (Canon'First .. Cut - 1));");
            L ("                  begin");
            L ("                     if Hit /= """" then");
            L ("                        return Hit;");
            L ("                     end if;");
            L ("                  end;");
            L ("               end if;");
            L ("               Cut := Cut - 1;");
            L ("            end loop;");
            L ("         end if;");
            L ("      end;");
         end Emit_Override_Table;
      begin
         Collect_Quarter_Rows ("quarter", Quarter_Start);
         Emit_Locale_Table ("Quarter_Name_Row", """""", Raw => True);

         L;
         L ("   function Quarter_Name");
         L ("     (Locale       : String;");
         L ("      Quarter      : Natural;");
         L ("      Quarter_Text : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Row : constant String := Quarter_Name_Row (Locale);");
         L ("   begin");
         --  A row with no entry for this quarter answers "", and the chains
         --  below still get their turn -- which is what the range test in the
         --  old branch condition did.
         L ("      if Row /= """" and then Quarter >= "
            & Trim (Integer'Image (Quarter_Start)) & " then");
         L ("         declare");
         L ("            Value : constant String :=");
         L ("              Hex_List_Item (Row, Quarter - "
            & Trim (Integer'Image (Quarter_Start)) & " + 1);");
         L ("         begin");
         L ("            if Value /= """" then");
         L ("               return Value;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         Emit_Override_Table ("quarter");
         L ("      if Lang = ""de"" then");
         L ("         return Quarter_Text & "". Quartal"";");
         L ("      elsif Lang = ""fr"" then");
         L ("         return Quarter_Text & ""e trimestre"";");
         L ("      elsif Lang = ""es"" then");
         L ("         return Quarter_Text & ""."" & U (16#BA#) & "" trimestre"";");
         L ("      elsif Lang = ""it"" then");
         L ("         return Quarter_Text & U (16#B0#) & "" trimestre"";");
         L ("      elsif Lang = ""pt"" then");
         L ("         return Quarter_Text & ""."" & U (16#BA#) & "" trimestre"";");
         L ("      elsif Lang = ""nl"" then");
         L ("         return Quarter_Text & ""e kwartaal"";");
         L ("      elsif Lang = ""ro"" then");
         L ("         return ""trimestrul "" & Quarter_Text;");
         L ("      elsif Lang = ""lt"" then");
         L ("         return Quarter_Text & "" ketvirtis"";");
         L ("      elsif Lang = ""sl"" then");
         L ("         return Quarter_Text & "". "" & U (16#10D#) & ""etrtletje"";");
         L ("      elsif Lang = ""pl"" then");
         L ("         return Quarter_Text & "". kwarta"" & U (16#142#);");
         L ("      elsif Lang = ""cs"" then");
         L ("         return Quarter_Text & "". "" & U (16#10D#) & ""tvrtlet""");
         L ("           & U (16#ED#);");
         L ("      elsif Lang = ""ru"" then");
         L ("         return Quarter_Text & ""-"" & U (16#439#) & "" """);
         L ("           & U (16#43A#) & U (16#432#) & U (16#430#)");
         L ("           & U (16#440#) & U (16#442#) & U (16#430#)");
         L ("           & U (16#43B#);");
         L ("      elsif Lang = ""ar"" then");
         L ("         return U (16#627#) & U (16#644#) & U (16#631#)");
         L ("           & U (16#628#) & U (16#639#) & "" "" & Quarter_Text;");
         L ("      elsif Lang = ""ja"" then");
         L ("         return U (16#7B2C#) & Quarter_Text & U (16#56DB#)");
         L ("           & U (16#534A#) & U (16#671F#);");
         L ("      elsif Lang = ""zh"" then");
         L ("         return U (16#7B2C#) & Quarter_Text & U (16#5B63#)");
         L ("           & U (16#5EA6#);");
         L ("      elsif Lang = ""ko"" then");
         L ("         return U (16#C81C#) & Quarter_Text & U (16#BD84#)");
         L ("           & U (16#AE30#);");
         L ("      else");
         L ("         return ""Quarter "" & Quarter_Text;");
         L ("      end if;");
         L ("   end Quarter_Name;");
         Collect_Quarter_Rows ("quarter_short", Quarter_Short_Start);
         Emit_Locale_Table ("Quarter_Name_Short_Row", """""", Raw => True);

         L;
         L ("   function Quarter_Name_Short");
         L ("     (Locale       : String;");
         L ("      Quarter      : Natural;");
         L ("      Quarter_Text : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Row : constant String := Quarter_Name_Short_Row (Locale);");
         L ("   begin");
         L ("      if Row /= """" and then Quarter >= "
            & Trim (Integer'Image (Quarter_Short_Start)) & " then");
         L ("         declare");
         L ("            Value : constant String :=");
         L ("              Hex_List_Item (Row, Quarter - "
            & Trim (Integer'Image (Quarter_Short_Start)) & " + 1);");
         L ("         begin");
         L ("            if Value /= """" then");
         L ("               return Value;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         Emit_Override_Table ("quarter_short");
         L ("      if Lang = ""fr"" or else Lang = ""es""");
         L ("        or else Lang = ""it"" or else Lang = ""pt""");
         L ("      then");
         L ("         return ""T"" & Quarter_Text;");
         L ("      elsif Lang = ""nl"" then");
         L ("         return ""K"" & Quarter_Text;");
         L ("      elsif Lang = ""ro"" then");
         L ("         return ""trim. "" & Quarter_Text;");
         L ("      elsif Lang = ""lt"" then");
         L ("         return Quarter_Text & "" ketv."";");
         L ("      elsif Lang = ""sl"" then");
         L ("         return Quarter_Text & "". "" & U (16#10D#) & ""et."";");
         L ("      elsif Lang = ""pl"" then");
         L ("         return Quarter_Text & "". kw."";");
         L ("      elsif Lang = ""cs"" then");
         L ("         return Quarter_Text & "". "" & U (16#10D#) & ""tvrt."";");
         L ("      elsif Lang = ""ru"" then");
         L ("         return Quarter_Text & ""-"" & U (16#439#) & "" """);
         L ("           & U (16#43A#) & U (16#432#) & ""."";");
         L ("      elsif Lang = ""ar"" then");
         L ("         return U (16#627#) & U (16#644#) & U (16#631#)");
         L ("           & U (16#628#) & U (16#639#) & "" "" & Quarter_Text;");
         L ("      elsif Lang = ""zh"" then");
         L ("         return Quarter_Text & U (16#5B63#) & U (16#5EA6#);");
         L ("      elsif Lang = ""ko"" then");
         L ("         return Quarter_Text & U (16#BD84#) & U (16#AE30#);");
         L ("      end if;");
         L;
         L ("      return ""Q"" & Quarter_Text;");
         L ("   end Quarter_Name_Short;");
      end Emit_Quarter_Name;

      procedure Emit_Day_Period_Name is
      begin
         L;
         L ("   function Day_Period_Payload_Value");
         L ("     (Payload : String;");
         L ("      Period  : String;");
         L ("      Width   : String)");
         L ("      return String");
         L ("   is");
         L ("      Start : Positive := Payload'First;");
         L ("      Stop  : Natural;");
         L ("      Last  : Natural;");
         L ("      Sep_1 : Natural;");
         L ("      Sep_2 : Natural;");
         L ("   begin");
         L ("      while Start <= Payload'Last loop");
         L ("         Stop := Start;");
         L ("         while Stop <= Payload'Last and then Payload (Stop) /= ';' loop");
         L ("            Stop := Stop + 1;");
         L ("         end loop;");
         L ("         Last := Stop - 1;");
         L ("         Sep_1 := 0;");
         L ("         Sep_2 := 0;");
         L ("         for Index in Start .. Last loop");
         L ("            if Payload (Index) = ',' then");
         L ("               if Sep_1 = 0 then");
         L ("                  Sep_1 := Index;");
         L ("               else");
         L ("                  Sep_2 := Index;");
         L ("                  exit;");
         L ("               end if;");
         L ("            end if;");
         L ("         end loop;");
         L ("         if Sep_1 > Start");
         L ("           and then Sep_2 > Sep_1 + 1");
         L ("           and then Payload (Start .. Sep_1 - 1) = Period");
         L ("           and then Payload (Sep_1 + 1 .. Sep_2 - 1) = Width");
         L ("         then");
         L ("            return VB (Payload (Sep_2 + 1 .. Last));");
         L ("         end if;");
         L ("         Start := Stop + 1;");
         L ("      end loop;");
         L ("      return """";");
         L ("   end Day_Period_Payload_Value;");
         --  One payload per locale: the period, the width and the text of
         --  every row that locale has, which Day_Period_Payload_Value picks
         --  apart. Collected here rather than rebuilt per branch.
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
               if Is_Kind (Index, "day_period_hex") then
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
                     & S (Rules (Index).C) & ","
                     & Hex_Bytes_To_Base64 (S (Rules (Index).D)));
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table ("Day_Period_Row", """""", Raw => True);

         L;
         L ("   function Day_Period_Name");
         L ("     (Locale : String;");
         L ("      Period : String;");
         L ("      Wide   : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Row : constant String := Day_Period_Row (Locale);");
         L ("   begin");
         L ("      if Row /= """" then");
         L ("         declare");
         L ("            Value : constant String :=");
         L ("              Day_Period_Payload_Value");
         L ("                (Row, Period, (if Wide then ""wide"" else ""abbreviated""));");
         L ("         begin");
         L ("            if Value /= """" then");
         L ("               return Value;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "day_period") then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("        and then Period = """ & S (Rules (Index).B) & """");
                  L
                    ("        and then "
                     & (if S (Rules (Index).C) = "wide" then "Wide" else "not Wide"));
                  L ("      then");
                  L ("         return " & S (Rules (Index).D) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
         L;
         L ("      if Lang = ""de"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return (if Wide then ""Mitternacht"" else ""Mittern."");");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""Mittag"";");
         L ("         elsif Period = ""am"" then");
         L ("            return (if Wide then ""vormittags"" else ""vorm."");");
         L ("         elsif Period = ""pm"" then");
         L ("            return (if Wide then ""nachmittags"" else ""nachm."");");
         L ("         end if;");
         L ("      elsif Lang = ""fr"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""minuit"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""midi"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""AM"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""PM"";");
         L ("         end if;");
         L ("      elsif Lang = ""es"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""medianoche"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""mediod"" & U (16#ED#) & ""a"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""a. m."";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""p. m."";");
         L ("         end if;");
         L ("      elsif Lang = ""it"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""mezzanotte"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""mezzogiorno"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""AM"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""PM"";");
         L ("         end if;");
         L ("      elsif Lang = ""pt"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""meia-noite"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""meio-dia"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""AM"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""PM"";");
         L ("         end if;");
         L ("      elsif Lang = ""nl"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""middernacht"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""middag"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""a.m."";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""p.m."";");
         L ("         end if;");
         L ("      elsif Lang = ""ro"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""miezul nop"" & U (16#21B#) & ""ii"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""amiaz"" & U (16#103#);");
         L ("         elsif Period = ""am"" then");
         L ("            return ""a.m."";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""p.m."";");
         L ("         end if;");
         L ("      elsif Lang = ""lt"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""vidurnaktis"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""vidurdienis"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""prie"" & U (16#161#) & ""piet"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""popiet"";");
         L ("         end if;");
         L ("      elsif Lang = ""sl"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""polno"" & U (16#10D#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""poldan"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""dop."";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""pop."";");
         L ("         end if;");
         L ("      elsif Lang = ""pl"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""p"" & U (16#F3#) & U (16#142#) & ""noc"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""po"" & U (16#142#) & ""udnie"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""AM"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""PM"";");
         L ("         end if;");
         L ("      elsif Lang = ""cs"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return ""p"" & U (16#16F#) & ""lnoc"";");
         L ("         elsif Period = ""noon"" then");
         L ("            return ""poledne"";");
         L ("         elsif Period = ""am"" then");
         L ("            return ""dop."";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""odp."";");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return U (16#43F#) & U (16#43E#) & U (16#43B#)");
         L ("              & U (16#43D#) & U (16#43E#) & U (16#447#)");
         L ("              & U (16#44C#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return U (16#43F#) & U (16#43E#) & U (16#43B#)");
         L ("              & U (16#434#) & U (16#435#) & U (16#43D#)");
         L ("              & U (16#44C#);");
         L ("         elsif Period = ""am"" then");
         L ("            return ""AM"";");
         L ("         elsif Period = ""pm"" then");
         L ("            return ""PM"";");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return U (16#645#) & U (16#646#) & U (16#62A#)");
         L ("              & U (16#635#) & U (16#641#) & "" """);
         L ("              & U (16#627#) & U (16#644#) & U (16#644#)");
         L ("              & U (16#64A#) & U (16#644#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return U (16#638#) & U (16#647#) & U (16#631#)");
         L ("              & U (16#64B#) & U (16#627#);");
         L ("         elsif Period = ""am"" then");
         L ("            return U (16#635#);");
         L ("         elsif Period = ""pm"" then");
         L ("            return U (16#645#);");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return U (16#771F#) & U (16#591C#) & U (16#4E2D#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return U (16#6B63#) & U (16#5348#);");
         L ("         elsif Period = ""am"" then");
         L ("            return U (16#5348#) & U (16#524D#);");
         L ("         elsif Period = ""pm"" then");
         L ("            return U (16#5348#) & U (16#5F8C#);");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return U (16#5348#) & U (16#591C#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return U (16#4E2D#) & U (16#5348#);");
         L ("         elsif Period = ""am"" then");
         L ("            return U (16#4E0A#) & U (16#5348#);");
         L ("         elsif Period = ""pm"" then");
         L ("            return U (16#4E0B#) & U (16#5348#);");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Period = ""midnight"" then");
         L ("            return U (16#C790#) & U (16#C815#);");
         L ("         elsif Period = ""noon"" then");
         L ("            return U (16#C815#) & U (16#C624#);");
         L ("         elsif Period = ""am"" then");
         L ("            return U (16#C624#) & U (16#C804#);");
         L ("         elsif Period = ""pm"" then");
         L ("            return U (16#C624#) & U (16#D6C4#);");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      if Period = ""midnight"" then");
         L ("         return (if Wide then ""midnight"" else ""mid."");");
         L ("      elsif Period = ""noon"" then");
         L ("         return ""noon"";");
         L ("      elsif Period = ""am"" then");
         L ("         return ""AM"";");
         L ("      elsif Period = ""pm"" then");
         L ("         return ""PM"";");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Day_Period_Name;");
      end Emit_Day_Period_Name;

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
         Zone_Names : Label_Array;
         Zone_Count : Natural;
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
         L ("   TZDB_Zones : constant array (Positive range <>) of TZDB_Zone_Data :=");
         L ("     (");
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

               L ("      " & Natural'Image (Zone_Index) & " => "
                  & "(Initial_Offset =>"
                  & Integer'Image (TZDB_Zone_Initial_Offsets (Zone_Index))
                  & ", First =>" & Natural'Image (First)
                  & ", Last =>" & Natural'Image (Last) & ")"
                  & (if Zone_Index = TZDB_Zone_Count then "" else ","));
            end;
         end loop;
         L ("     );");
         L;
         L ("   TZDB_Transitions : constant array (Positive range <>) of TZDB_Transition :=");
         L ("     (");
         for Transition_Index in 1 .. TZDB_Transition_Count loop
            L ("      " & Natural'Image (Transition_Index) & " => "
               & "(Key =>"
               & Long_Long_Integer'Image (TZDB_Transition_Keys (Transition_Index))
               & ", Offset =>"
               & Integer'Image (TZDB_Transition_Offsets (Transition_Index))
               & ")"
               & (if Transition_Index = TZDB_Transition_Count then "" else ","));
         end loop;
         L ("     );");
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
            L ("              Zone & (1 .. Link_Width - Zone'Length => ' ');");
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
            L ("           Canonical & (1 .. Zone_Width - Canonical'Length => ' ');");
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
         L ("            for Transition_Index in reverse First .. Last loop");
         L ("               if TZDB_Transitions (Transition_Index).Key <= Key then");
         L ("                  return TZDB_Transitions (Transition_Index).Offset;");
         L ("               end if;");
         L ("            end loop;");
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
         --  128,821 records over 6.7 MB, walked from the first character on
         --  each of two passes. Grouped by locale, so each locale is a
         --  segment and the locale field leaves the record.
         Collect_Labels ("zone_exemplar_hex", 2, Zone_Names, Zone_Count);
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  Grouped by locale, so a change of locale ends the segment.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_exemplar_hex") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Zone_Names, Zone_Count,
                                 S (Rules (Index).B), 2)
                     & Hex_Bytes_To_Base64 (S (Rules (Index).C)) & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Zone_Exemplar_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   function Time_Zone_Exemplar_Location");
         L ("     (Locale : String;");
         L ("      Zone   : String)");
         L ("      return String");
         L ("   is");
         Emit_Label_Index ("Zone_Index", Zone_Names, Zone_Count, 32, 2);
         L ("      Zone_Key_Width : constant := 34;");
         L ("      Zone_Key_Count : constant Natural :=");
         L ("        Zone_Index'Length / Zone_Key_Width;");
         L;
         L ("      --  A zone name is thirty characters for one of 419, so the");
         L ("      --  record carries a two-character code and the name is");
         L ("      --  mapped once per call rather than compared per record.");
         L ("      function Zone_Code return String is");
         L ("         Low : Natural := 1;");
         L ("         High : Natural := Zone_Key_Count;");
         L ("         Mid : Natural;");
         L ("         Wanted : constant String :=");
         L ("           (if Zone'Length >= 32 then Zone (Zone'First .. Zone'First + 31)");
         L ("            else Zone & (1 .. 32 - Zone'Length => ' '));");
         L ("      begin");
         L ("         while Low <= High loop");
         L ("            Mid := (Low + High) / 2;");
         L ("            declare");
         L ("               At_Key : constant Natural :=");
         L ("                 Zone_Index'First + (Mid - 1) * Zone_Key_Width;");
         L ("               Key : constant String :=");
         L ("                 Zone_Index (At_Key .. At_Key + 31);");
         L ("            begin");
         L ("               if Key = Wanted then");
         L ("                  return Zone_Index (At_Key + 32 .. At_Key + 33);");
         L ("               elsif Key < Wanted then");
         L ("                  Low := Mid + 1;");
         L ("               else");
         L ("                  High := Mid - 1;");
         L ("               end if;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return ""  "";");
         L ("      end Zone_Code;");
         L;
         L ("      function Search (Rows : String; Wanted : String) return String is");
         L ("         Start : Positive := Rows'First;");
         L ("      begin");
         L ("         if Wanted = ""  "" then");
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
         L ("               if Stop > Start + 2");
         L ("                 and then Rows (Start .. Start + 1) = Wanted");
         L ("               then");
         L ("                  return VB (Rows (Start + 2 .. Stop - 1));");
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
         L ("      function Resolve return String is");
         L ("         Wanted_Zone : constant String := Zone_Code;");
         L ("         Exact : constant String :=");
         L ("           Search (Zone_Exemplar_Row (Locale), Wanted_Zone);");
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
         L ("                      (Zone_Exemplar_Row (Canon (Canon'First .. Cut - 1)),");
         L ("                       Wanted_Zone);");
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
         L ("      end Resolve;");
         L ("   begin");
         L ("      return Resolve;");
         L ("   end Time_Zone_Exemplar_Location;");
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
      function Trimmed_Currency_Payload (Payload : String) return String is
         Max_Forms : constant := 64;
         Result : US.Unbounded_String;
         Start : Positive := Payload'First;
      begin
         while Start <= Payload'Last loop
            declare
               Stop : Natural := Start;
            begin
               while Stop <= Payload'Last and then Payload (Stop) /= ';' loop
                  Stop := Stop + 1;
               end loop;

               declare
                  Item : constant String := Payload (Start .. Stop - 1);
                  Colon : Natural := 0;
               begin
                  for Index in Item'Range loop
                     if Item (Index) = ':' then
                        Colon := Index;
                        exit;
                     end if;
                  end loop;

                  if US.Length (Result) > 0 then
                     US.Append (Result, ";");
                  end if;

                  if Colon = 0 or else Item'Length = 0 then
                     US.Append (Result, Item);
                  else
                     declare
                        Forms : array (1 .. Max_Forms) of US.Unbounded_String;
                        Count : Natural := 0;
                        From  : Positive := Colon + 1;
                     begin
                        for Index in Colon + 1 .. Item'Last + 1 loop
                           if Index > Item'Last
                             or else Item (Index) = ','
                           then
                              if Count < Max_Forms then
                                 Count := Count + 1;
                                 Forms (Count) :=
                                   US.To_Unbounded_String
                                     (Hex_Bytes_To_Base64
                                        (Item (From .. Index - 1)));
                              end if;
                              From := Index + 1;
                           end if;
                        end loop;

                        while Count > 1
                          and then US."=" (Forms (Count), Forms (Count - 1))
                        loop
                           Count := Count - 1;
                        end loop;

                        US.Append (Result, Item (Item'First .. Colon));
                        for Index in 1 .. Count loop
                           if Index > 1 then
                              US.Append (Result, ",");
                           end if;
                           US.Append (Result, Forms (Index));
                        end loop;
                     end;
                  end if;
               end;

               Start := Stop + 1;
            end;
         end loop;

         return S (Result);
      end Trimmed_Currency_Payload;

      procedure Emit_Localized_Currency_Display_Name is
         procedure Emit_String_Argument
           (Value  : String;
            Indent : String)
         is
            Chunk_Size : constant := Data_Chunk;
            First      : Positive := Value'First;
            Last       : Natural;
            Term       : Positive := 1;
         begin
            while First <= Value'Last loop
               Last := Natural'Min (First + Chunk_Size - 1, Value'Last);
               L (Indent & (if Term = 1 then " " else "& ")
                  & """" & Value (First .. Last) & """"
                  & (if Last = Value'Last then "," else ""));
               First := Last + 1;
               Term := Term + 1;
            end loop;
         end Emit_String_Argument;
         pragma Unreferenced (Emit_String_Argument);
      begin
         L;
         L ("   function Currency_Display_Name");
         L ("     (Locale   : String;");
         L ("      Code     : String;");
         L ("      Category : String := ""other"")");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Singular : constant Boolean := Category = ""one"";");

         --  405 payloads, each written out twice -- once for the exact pass
         --  and once for the fallback -- and most of them repeats: 808
         --  literals, 258 of them distinct. As a table they are stored once
         --  and the repeats collapse.
         Reset_Table;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "currency_name_payload") then
               Add_Table_Entry
                 (S (Rules (Index).A),
                  Trimmed_Currency_Payload (S (Rules (Index).B)));
            end if;
         end loop;

         --  Nested, as a subunit holds one subprogram.
         Emit_Locale_Table
           ("Currency_Payload_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("      function Find (Cand : String) return String is");
         L ("         Payload : constant String := Currency_Payload_Row (Cand);");
         L ("      begin");
         L ("         if Payload = """" then");
         L ("            return """";");
         L ("         end if;");
         L ("         return Currency_Name_From_Payload (Payload, Code, Category);");
         L ("      end Find;");
         L;
         L ("      Exact : constant String := Find (Locale);");
         L ("      Canon : constant String := Canonical_Locale (Locale);");
         L ("      Cut : Natural := Canon'Last;");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      --  Then each parent, longest first.");
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
         L ("      if Lang = ""de"" then");
         L ("         if Code = ""USD"" then");
         L ("            return ""US-Dollar"";");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""Kanadischer Dollar"" else ""Kanadische Dollar"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""Australischer Dollar"" else ""Australische Dollar"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return ""Neuseeland-Dollar"";");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""Euro"";");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""Britisches Pfund"" else ""Britische Pfund"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return ""Japanischer Yen"";");
         L ("         elsif Code = ""CNY"" then");
         L ("            return ""Chinesischer Yuan"";");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""Indische Rupie"" else ""Indische Rupien"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return ""S"" & U (16#FC#) & ""dkoreanischer Won"";");
         L ("         elsif Code = ""CHF"" then");
         L ("            return ""Schweizer Franken"";");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""Brasilianischer Real"" else ""Brasilianische Real"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""Mexikanischer Peso"" else ""Mexikanische Pesos"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""D"" & U (16#E4#) & ""nische Krone""");
         L ("               else ""D"" & U (16#E4#) & ""nische Kronen"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""Norwegische Krone"" else ""Norwegische Kronen"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""Schwedische Krone"" else ""Schwedische Kronen"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return ""T"" & U (16#FC#) & ""rkische Lira"";");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return ""S"" & U (16#FC#) & ""dafrikanischer Rand"";");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""Russischer Rubel"" else ""Russische Rubel"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""Polnischer Z"" & U (16#142#) & ""oty""");
         L ("               else ""Polnische Z"" & U (16#142#) & ""oty"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""Tschechische Krone"" else ""Tschechische Kronen"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return ""Kuwait-Dinar"";");
         L ("         end if;");
         L ("      elsif Lang = ""fr"" then");
         L ("         if Code = ""USD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""dollar des "" & U (16#C9#) & ""tats-Unis""");
         L ("               else ""dollars des "" & U (16#C9#) & ""tats-Unis"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""dollar canadien"" else ""dollars canadiens"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""dollar australien"" else ""dollars australiens"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""dollar n"" & U (16#E9#) & ""o-z"" & U (16#E9#) & ""landais""");
         L ("               else ""dollars n"" & U (16#E9#) & ""o-z"" & U (16#E9#) & ""landais"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return (if Singular then ""euro"" else ""euros"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""livre sterling"" else ""livres sterling"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""yen japonais"" else ""yens japonais"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return ""yuan chinois"";");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""roupie indienne"" else ""roupies indiennes"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""won sud-cor"" & U (16#E9#) & ""en""");
         L ("               else ""wons sud-cor"" & U (16#E9#) & ""ens"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then ""franc suisse"" else ""francs suisses"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""r"" & U (16#E9#) & ""al br""");
         L ("                    & U (16#E9#) & ""silien""");
         L ("               else ""r"" & U (16#E9#) & ""als br""");
         L ("                    & U (16#E9#) & ""siliens"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""peso mexicain"" else ""pesos mexicains"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""couronne danoise"" else ""couronnes danoises"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""couronne norv"" & U (16#E9#) & ""gienne""");
         L ("               else ""couronnes norv"" & U (16#E9#) & ""giennes"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""couronne su"" & U (16#E9#) & ""doise""");
         L ("               else ""couronnes su"" & U (16#E9#) & ""doises"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""livre turque"" else ""livres turques"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""rand sud-africain"" else ""rands sud-africains"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rouble russe"" else ""roubles russes"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return ""zloty polonais"";");
         L ("         elsif Code = ""CZK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""couronne tch"" & U (16#E8#) & ""que""");
         L ("               else ""couronnes tch"" & U (16#E8#) & ""ques"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""dinar kowe"" & U (16#EF#) & ""tien""");
         L ("               else ""dinars kowe"" & U (16#EF#) & ""tiens"");");
         L ("         end if;");
         L ("      elsif Lang = ""es"" then");
         L ("         if Code = ""USD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar estadounidense""");
         L ("               else ""d"" & U (16#F3#) & ""lares estadounidenses"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar canadiense""");
         L ("               else ""d"" & U (16#F3#) & ""lares canadienses"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar australiano""");
         L ("               else ""d"" & U (16#F3#) & ""lares australianos"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar neozeland"" & U (16#E9#) & ""s""");
         L ("               else ""d"" & U (16#F3#) & ""lares neozelandeses"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return (if Singular then ""euro"" else ""euros"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""libra esterlina"" else ""libras esterlinas"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""yen japon"" & U (16#E9#) & ""s""");
         L ("               else ""yenes japoneses"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""yuan chino"" else ""yuanes chinos"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""rupia india"" else ""rupias indias"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return (if Singular then ""won surcoreano"" else ""wones surcoreanos"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then ""franco suizo"" else ""francos suizos"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""real brasile"" & U (16#F1#) & ""o""");
         L ("               else ""reales brasile"" & U (16#F1#) & ""os"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""peso mexicano"" else ""pesos mexicanos"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""corona danesa"" else ""coronas danesas"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""corona noruega"" else ""coronas noruegas"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""corona sueca"" else ""coronas suecas"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""lira turca"" else ""liras turcas"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""rand sudafricano"" else ""rands sudafricanos"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rublo ruso"" else ""rublos rusos"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""esloti polaco"" else ""eslotis polacos"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""corona checa"" else ""coronas checas"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""dinar kuwait"" & U (16#ED#)");
         L ("               else ""dinares kuwait"" & U (16#ED#) & ""es"");");
         L ("         end if;");
         L ("      elsif Lang = ""it"" then");
         L ("         if Code = ""USD"" then");
         L ("            return (if Singular then ""dollaro statunitense"" else ""dollari statunitensi"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""dollaro canadese"" else ""dollari canadesi"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""dollaro australiano"" else ""dollari australiani"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return (if Singular then ""dollaro neozelandese"" else ""dollari neozelandesi"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""euro"";");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""sterlina britannica"" else ""sterline britanniche"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""yen giapponese"" else ""yen giapponesi"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""yuan cinese"" else ""yuan cinesi"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""rupia indiana"" else ""rupie indiane"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return (if Singular then ""won sudcoreano"" else ""won sudcoreani"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then ""franco svizzero"" else ""franchi svizzeri"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""real brasiliano"" else ""real brasiliani"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""peso messicano"" else ""pesos messicani"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""corona danese"" else ""corone danesi"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""corona norvegese"" else ""corone norvegesi"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""corona svedese"" else ""corone svedesi"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""lira turca"" else ""lire turche"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""rand sudafricano"" else ""rand sudafricani"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rublo russo"" else ""rubli russi"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""zloty polacco"" else ""zloty polacchi"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""corona ceca"" else ""corone ceche"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""dinaro kuwaitiano"" else ""dinari kuwaitiani"");");
         L ("         end if;");
         L ("      elsif Lang = ""pt"" then");
         L ("         if Code = ""USD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar americano""");
         L ("               else ""d"" & U (16#F3#) & ""lares americanos"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar canadense""");
         L ("               else ""d"" & U (16#F3#) & ""lares canadenses"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar australiano""");
         L ("               else ""d"" & U (16#F3#) & ""lares australianos"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""d"" & U (16#F3#) & ""lar neozeland"" & U (16#EA#) & ""s""");
         L ("               else ""d"" & U (16#F3#) & ""lares neozelandeses"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""euro"" & (if Singular then """" else ""s"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""libra esterlina"" else ""libras esterlinas"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""iene japon"" & U (16#EA#) & ""s""");
         L ("               else ""ienes japoneses"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""yuan chin"" & U (16#EA#) & ""s"" else ""yuans chineses"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""r"" & U (16#FA#) & ""pia indiana""");
         L ("               else ""r"" & U (16#FA#) & ""pias indianas"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return (if Singular then ""won sul-coreano"" else ""wons sul-coreanos"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""franco su"" & U (16#ED#) & U (16#E7#) & ""o""");
         L ("               else ""francos su"" & U (16#ED#) & U (16#E7#) & ""os"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""real brasileiro"" else ""reais brasileiros"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""peso mexicano"" else ""pesos mexicanos"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""coroa dinamarquesa"" else ""coroas dinamarquesas"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""coroa norueguesa"" else ""coroas norueguesas"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""coroa sueca"" else ""coroas suecas"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""lira turca"" else ""liras turcas"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""rand sul-africano"" else ""rands sul-africanos"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rublo russo"" else ""rublos russos"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""zloty polon"" & U (16#EA#) & ""s""");
         L ("               else ""zlotys poloneses"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""coroa tcheca"" else ""coroas tchecas"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""dinar kuwaitiano"" else ""dinares kuwaitianos"");");
         L ("         end if;");
         L ("      elsif Lang = ""nl"" then");
         L ("         if Code = ""USD"" then");
         L ("            return (if Singular then ""Amerikaanse dollar"" else ""Amerikaanse dollars"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""Canadese dollar"" else ""Canadese dollars"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""Australische dollar"" else ""Australische dollars"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return (if Singular then ""Nieuw-Zeelandse dollar"" else ""Nieuw-Zeelandse dollars"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""euro"";");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""Brits pond"" else ""Britse ponden"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return ""Japanse yen"";");
         L ("         elsif Code = ""CNY"" then");
         L ("            return ""Chinese yuan"";");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""Indiase roepie"" else ""Indiase roepies"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return ""Zuid-Koreaanse won"";");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then ""Zwitserse frank"" else ""Zwitserse franken"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""Braziliaanse real"" else ""Braziliaanse reals"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""Mexicaanse peso"" else ""Mexicaanse peso's"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""Deense kroon"" else ""Deense kronen"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""Noorse kroon"" else ""Noorse kronen"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""Zweedse kroon"" else ""Zweedse kronen"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""Turkse lira"" else ""Turkse lira's"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return ""Zuid-Afrikaanse rand"";");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""Russische roebel"" else ""Russische roebels"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""Poolse zloty"" else ""Poolse zloty's"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""Tsjechische kroon"" else ""Tsjechische kronen"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""Koeweitse dinar"" else ""Koeweitse dinars"");");
         L ("         end if;");
         L ("      elsif Lang = ""ro"" then");
         L ("         if Code = ""USD"" then");
         L ("            return (if Singular then ""dolar american"" else ""dolari americani"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""dolar canadian"" else ""dolari canadieni"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""dolar australian"" else ""dolari australieni"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return (if Singular then ""dolar neozeelandez"" else ""dolari neozeelandezi"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""euro"";");
         L ("         elsif Code = ""GBP"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""lir"" & U (16#103#) & "" sterlin"" & U (16#103#)");
         L ("               else ""lire sterline"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""yen japonez"" else ""yeni japonezi"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""yuan chinezesc"" else ""yuani chineze"" & U (16#219#) & ""ti"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""rupie indian"" & U (16#103#) else ""rupii indiene"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return (if Singular then ""won sud-coreean"" else ""woni sud-coreeni"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""franc elve"" & U (16#21B#) & ""ian""");
         L ("               else ""franci elve"" & U (16#21B#) & ""ieni"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""real brazilian"" else ""reali brazilieni"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""peso mexican"" else ""pesos mexicani"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""coroan"" & U (16#103#) & "" danez"" & U (16#103#)");
         L ("               else ""coroane daneze"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""coroan"" & U (16#103#) & "" norvegian""");
         L ("                    & U (16#103#)");
         L ("               else ""coroane norvegiene"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""coroan"" & U (16#103#) & "" suedez"" & U (16#103#)");
         L ("               else ""coroane suedeze"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""lir"" & U (16#103#) & "" turceasc"" & U (16#103#)");
         L ("               else ""lire turce"" & U (16#219#) & ""ti"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""rand sud-african"" else ""ranzi sud-africani"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""rubl"" & U (16#103#) & "" ruseasc"" & U (16#103#)");
         L ("               else ""ruble ruse"" & U (16#219#) & ""ti"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""zlot polonez"" else ""zlo"" & U (16#21B#) & ""i polonezi"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""coroan"" & U (16#103#) & "" ceh"" & U (16#103#)");
         L ("               else ""coroane cehe"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""dinar kuweitian"" else ""dinari kuweitieni"");");
         L ("         end if;");
         L ("      elsif Lang = ""lt"" then");
         L ("         if Code = ""USD"" then");
         L ("            return (if Singular then ""JAV doleris"" else ""JAV doleriai"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""Kanados doleris"" else ""Kanados doleriai"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""Australijos doleris"" else ""Australijos doleriai"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""Naujosios Zelandijos doleris""");
         L ("               else ""Naujosios Zelandijos doleriai"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return (if Singular then ""euras"" else ""eurai"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""svaras sterling"" & U (16#173#)");
         L ("               else ""svarai sterling"" & U (16#173#));");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""Japonijos jena"" else ""Japonijos jenos"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""Kinijos juanis"" else ""Kinijos juaniai"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""Indijos rupija"" else ""Indijos rupijos"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""Piet"" & U (16#173#) & "" Kor""");
         L ("                    & U (16#117#) & ""jos vonas""");
         L ("               else ""Piet"" & U (16#173#) & "" Kor""");
         L ("                    & U (16#117#) & ""jos vonai"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#160#) & ""veicarijos frankas""");
         L ("               else U (16#160#) & ""veicarijos frankai"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""Brazilijos realas"" else ""Brazilijos realai"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""Meksikos pesas"" else ""Meksikos pesai"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""Danijos krona"" else ""Danijos kronos"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""Norvegijos krona"" else ""Norvegijos kronos"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#160#) & ""vedijos krona""");
         L ("               else U (16#160#) & ""vedijos kronos"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""Turkijos lira"" else ""Turkijos liros"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""Piet"" & U (16#173#) & "" Afrikos randas""");
         L ("               else ""Piet"" & U (16#173#) & "" Afrikos randai"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""Rusijos rublis"" else ""Rusijos rubliai"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""Lenkijos zlotas"" else ""Lenkijos zlotai"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#10C#) & ""ekijos krona""");
         L ("               else U (16#10C#) & ""ekijos kronos"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""Kuveito dinaras"" else ""Kuveito dinarai"");");
         L ("         end if;");
         L ("      elsif Lang = ""sl"" then");
         L ("         if Code = ""USD"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""ameri"" & U (16#161#) & ""ki dolar""");
         L ("               else ""ameri"" & U (16#161#) & ""ka dolarja"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""kanadski dolar"" else ""kanadska dolarja"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""avstralski dolar"" else ""avstralska dolarja"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return (if Singular then ""novozelandski dolar"" else ""novozelandska dolarja"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return (if Singular then ""evro"" else ""evra"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""britanski funt""");
         L ("               else ""britanska funta"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""japonski jen"" else ""japonska jena"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""kitajski juan"" else ""kitajska juana"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""indijska rupija"" else ""indijski rupiji"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""ju"" & U (16#17E#) & ""nokorejski von""");
         L ("               else ""ju"" & U (16#17E#) & ""nokorejska vona"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#161#) & ""vicarski frank""");
         L ("               else U (16#161#) & ""vicarska franka"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""brazilski real"" else ""brazilska reala"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""mehi"" & U (16#161#) & ""ki peso""");
         L ("               else ""mehi"" & U (16#161#) & ""ka pesa"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""danska krona"" else ""danski kroni"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""norve"" & U (16#161#) & ""ka krona""");
         L ("               else ""norve"" & U (16#161#) & ""ki kroni"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#161#) & ""vedska krona""");
         L ("               else U (16#161#) & ""vedski kroni"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""tur"" & U (16#161#) & ""ka lira""");
         L ("               else ""tur"" & U (16#161#) & ""ki liri"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""ju"" & U (16#17E#) & ""noafri""");
         L ("                    & U (16#161#) & ""ki rand""");
         L ("               else ""ju"" & U (16#17E#) & ""noafri""");
         L ("                    & U (16#161#) & ""ka randa"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""ruski rubelj"" else ""ruska rublja"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""poljski zlot"" else ""poljska zlota"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then U (16#10D#) & ""e"" & U (16#161#) & ""ka krona""");
         L ("               else U (16#10D#) & ""e"" & U (16#161#) & ""ki kroni"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""kuvajtski dinar"" else ""kuvajtska dinarja"");");
         L ("         end if;");
         L ("      elsif Lang = ""pl"" then");
         L ("         if Code = ""USD"" then");
         L ("            return");
         L ("              (if Singular then ""dolar ameryka"" & U (16#144#) & ""ski""");
         L ("               else ""dolary ameryka"" & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""dolar kanadyjski"" else ""dolary kanadyjskie"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""dolar australijski"" else ""dolary australijskie"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return");
         L ("              (if Singular then ""dolar nowozelandzki""");
         L ("               else ""dolary nowozelandzkie"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return ""euro"";");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""funt szterling"" else ""funty szterlingi"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""jen japo"" & U (16#144#) & ""ski""");
         L ("                    else ""jeny japo"" & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then ""juan chi"" & U (16#144#) & ""ski""");
         L ("                    else ""juany chi"" & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""rupia indyjska"" else ""rupie indyjskie"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""won po"" & U (16#142#) & ""udniowokorea""");
         L ("                    & U (16#144#) & ""ski""");
         L ("               else ""wony po"" & U (16#142#) & ""udniowokorea""");
         L ("                    & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then ""frank szwajcarski"" else ""franki szwajcarskie"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""real brazylijski"" else ""reale brazylijskie"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return ""peso meksyka"" & U (16#144#) & ""skie"";");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""korona du"" & U (16#144#) & ""ska""");
         L ("                    else ""korony du"" & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""korona norweska"" else ""korony norweskie"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then ""korona szwedzka"" else ""korony szwedzkie"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""lira turecka"" else ""liry tureckie"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""rand po"" & U (16#142#) & ""udniowoafryka""");
         L ("                    & U (16#144#) & ""ski""");
         L ("               else ""randy po"" & U (16#142#) & ""udniowoafryka""");
         L ("                    & U (16#144#) & ""skie"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rubel rosyjski"" else ""ruble rosyjskie"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""polski z"" & U (16#142#) & ""oty""");
         L ("                    else ""polskie z"" & U (16#142#) & ""ote"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then ""korona czeska"" else ""korony czeskie"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""dinar kuwejcki"" else ""dinary kuwejckie"");");
         L ("         end if;");
         L ("      elsif Lang = ""cs"" then");
         L ("         if Code = ""USD"" then");
         L ("            return (if Singular then ""americk"" & U (16#FD#) & "" dolar""");
         L ("                    else ""americk"" & U (16#E9#) & "" dolary"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return (if Singular then ""kanadsk"" & U (16#FD#) & "" dolar""");
         L ("                    else ""kanadsk"" & U (16#E9#) & "" dolary"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return (if Singular then ""australsk"" & U (16#FD#) & "" dolar""");
         L ("                    else ""australsk"" & U (16#E9#) & "" dolary"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return (if Singular then ""novoz"" & U (16#E9#) & ""landsk""");
         L ("                    & U (16#FD#) & "" dolar"" else ""novoz""");
         L ("                    & U (16#E9#) & ""landsk"" & U (16#E9#) & "" dolary"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return (if Singular then ""euro"" else ""eura"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return (if Singular then ""britsk"" & U (16#E1#) & "" libra""");
         L ("                    else ""britsk"" & U (16#E9#) & "" libry"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return (if Singular then ""japonsk"" & U (16#FD#) & "" jen""");
         L ("                    else ""japonsk"" & U (16#E9#) & "" jeny"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return (if Singular then U (16#10D#) & """"");
         L ("                    & U (16#ED#) & ""nsk"" & U (16#FD#) & "" j""");
         L ("                    & U (16#FC#) & ""an"" else U (16#10D#)");
         L ("                    & U (16#ED#) & ""nsk"" & U (16#E9#) & "" j""");
         L ("                    & U (16#FC#) & ""any"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return (if Singular then ""indick"" & U (16#E1#) & "" rupie""");
         L ("                    else ""indick"" & U (16#E9#) & "" rupie"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return (if Singular then ""jihokorejsk"" & U (16#FD#) & "" won""");
         L ("                    else ""jihokorejsk"" & U (16#E9#) & "" wony"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return (if Singular then U (16#161#) & ""v""");
         L ("                    & U (16#FD#) & ""carsk"" & U (16#FD#) & "" frank""");
         L ("                    else U (16#161#) & ""v"" & U (16#FD#)");
         L ("                    & ""carsk"" & U (16#E9#) & "" franky"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return (if Singular then ""brazilsk"" & U (16#FD#) & "" real""");
         L ("                    else ""brazilsk"" & U (16#E9#) & "" realy"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return (if Singular then ""mexick"" & U (16#E9#) & "" peso""");
         L ("                    else ""mexick"" & U (16#E1#) & "" pesa"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return (if Singular then ""d"" & U (16#E1#) & ""nsk""");
         L ("                    & U (16#E1#) & "" koruna"" else ""d""");
         L ("                    & U (16#E1#) & ""nsk"" & U (16#E9#) & "" koruny"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return (if Singular then ""norsk"" & U (16#E1#) & "" koruna""");
         L ("                    else ""norsk"" & U (16#E9#) & "" koruny"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return (if Singular then U (16#161#) & ""v""");
         L ("                    & U (16#E9#) & ""dsk"" & U (16#E1#) & "" koruna""");
         L ("                    else U (16#161#) & ""v"" & U (16#E9#)");
         L ("                    & ""dsk"" & U (16#E9#) & "" koruny"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return (if Singular then ""tureck"" & U (16#E1#) & "" lira""");
         L ("                    else ""tureck"" & U (16#E9#) & "" liry"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return (if Singular then ""jihoafrick"" & U (16#FD#) & "" rand""");
         L ("                    else ""jihoafrick"" & U (16#E9#) & "" randy"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return (if Singular then ""rusk"" & U (16#FD#) & "" rubl""");
         L ("                    else ""rusk"" & U (16#E9#) & "" rubly"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return (if Singular then ""polsk"" & U (16#FD#) & "" zlot""");
         L ("                    & U (16#FD#) else ""polsk"" & U (16#E9#)");
         L ("                    & "" zlot"" & U (16#E9#));");
         L ("         elsif Code = ""CZK"" then");
         L ("            return (if Singular then U (16#10D#) & ""esk""");
         L ("                    & U (16#E1#) & "" koruna"" else U (16#10D#)");
         L ("                    & ""esk"" & U (16#E9#) & "" koruny"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return (if Singular then ""kuvajtsk"" & U (16#FD#) & "" din""");
         L ("                    & U (16#E1#) & ""r"" else ""kuvajtsk""");
         L ("                    & U (16#E9#) & "" din"" & U (16#E1#) & ""ry"");");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Code = ""USD"" then");
         L ("            if Singular then");
         L ("               return H (""0434043E043B043B043004400020042104280410"");");
         L ("            else");
         L ("               return H (""0434043E043B043B04300440044B0020042104280410"");");
         L ("            end if;");
         L ("         elsif Code = ""CAD"" then");
         L ("            if Singular then");
         L ("               return H (""043A0430043D043004340441043A0438043900200434043E043B043B04300440"");");
         L ("            else");
         L ("               return H");
         L ("                 (""043A0430043D043004340441043A0438043500200434043E043B043B04300440""");
         L ("                  & ""044B"");");
         L ("            end if;");
         L ("         elsif Code = ""AUD"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""043004320441044204400430043B043804390441043A0438043900200434043E""");
         L ("                  & ""043B043B04300440"");");
         L ("            else");
         L ("               return H");
         L ("                 (""043004320441044204400430043B043804390441043A0438043500200434043E""");
         L ("                  & ""043B043B04300440044B"");");
         L ("            end if;");
         L ("         elsif Code = ""NZD"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""043D043E0432043E04370435043B0430043D04340441043A0438043900200434""");
         L ("                  & ""043E043B043B04300440"");");
         L ("            else");
         L ("               return H");
         L ("                 (""043D043E0432043E04370435043B0430043D04340441043A0438043500200434""");
         L ("                  & ""043E043B043B04300440044B"");");
         L ("            end if;");
         L ("         elsif Code = ""EUR"" then");
         L ("            return H (""043504320440043E"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            if Singular then");
         L ("               return H (""04310440043804420430043D0441043A04380439002004440443043D0442"");");
         L ("            else");
         L ("               return H (""04310440043804420430043D0441043A04380435002004440443043D0442044B"");");
         L ("            end if;");
         L ("         elsif Code = ""JPY"" then");
         L ("            if Singular then");
         L ("               return H (""044F043F043E043D0441043A0430044F002004380435043D0430"");");
         L ("            else");
         L ("               return H (""044F043F043E043D0441043A04380435002004380435043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""CNY"" then");
         L ("            if Singular then");
         L ("               return H (""043A04380442043004390441043A043804390020044E0430043D044C"");");
         L ("            else");
         L ("               return H (""043A04380442043004390441043A043804350020044E0430043D0438"");");
         L ("            end if;");
         L ("         elsif Code = ""INR"" then");
         L ("            if Singular then");
         L ("               return H (""0438043D0434043804390441043A0430044F002004400443043F0438044F"");");
         L ("            else");
         L ("               return H (""0438043D0434043804390441043A04380435002004400443043F04380438"");");
         L ("            end if;");
         L ("         elsif Code = ""KRW"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""044E0436043D043E043A043E0440043504390441043A0430044F00200432043E""");
         L ("                  & ""043D0430"");");
         L ("            else");
         L ("               return H");
         L ("                 (""044E0436043D043E043A043E0440043504390441043A0438043500200432043E""");
         L ("                  & ""043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""CHF"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""04480432043504390446043004400441043A043804390020044404400430043D""");
         L ("                  & ""043A"");");
         L ("            else");
         L ("               return H");
         L ("                 (""04480432043504390446043004400441043A043804350020044404400430043D""");
         L ("                  & ""043A0438"");");
         L ("            end if;");
         L ("         elsif Code = ""BRL"" then");
         L ("            if Singular then");
         L ("               return H (""04310440043004370438043B044C0441043A043804390020044004350430043B"");");
         L ("            else");
         L ("               return H");
         L ("                 (""04310440043004370438043B044C0441043A043804350020044004350430043B""");
         L ("                  & ""044B"");");
         L ("            end if;");
         L ("         elsif Code = ""MXN"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""043C0435043A04410438043A0430043D0441043A043804390020043F04350441""");
         L ("                  & ""043E"");");
         L ("            else");
         L ("               return H");
         L ("                 (""043C0435043A04410438043A0430043D0441043A043804350020043F04350441""");
         L ("                  & ""043E"");");
         L ("            end if;");
         L ("         elsif Code = ""DKK"" then");
         L ("            if Singular then");
         L ("               return H (""0434043004420441043A0430044F0020043A0440043E043D0430"");");
         L ("            else");
         L ("               return H (""0434043004420441043A043804350020043A0440043E043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""NOK"" then");
         L ("            if Singular then");
         L ("               return H (""043D043E04400432043504360441043A0430044F0020043A0440043E043D0430"");");
         L ("            else");
         L ("               return H (""043D043E04400432043504360441043A043804350020043A0440043E043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""SEK"" then");
         L ("            if Singular then");
         L ("               return H (""04480432043504340441043A0430044F0020043A0440043E043D0430"");");
         L ("            else");
         L ("               return H (""04480432043504340441043A043804350020043A0440043E043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""TRY"" then");
         L ("            if Singular then");
         L ("               return H (""04420443044004350446043A0430044F0020043B043804400430"");");
         L ("            else");
         L ("               return H (""04420443044004350446043A043804350020043B04380440044B"");");
         L ("            end if;");
         L ("         elsif Code = ""ZAR"" then");
         L ("            if Singular then");
         L ("               return H");
         L ("                 (""044E0436043D043E0430044404400438043A0430043D0441043A043804390020""");
         L ("                  & ""04400430043D0434"");");
         L ("            else");
         L ("               return H");
         L ("                 (""044E0436043D043E0430044404400438043A0430043D0441043A043804350020""");
         L ("                  & ""04400430043D0434044B"");");
         L ("            end if;");
         L ("         elsif Code = ""RUB"" then");
         L ("            if Singular then");
         L ("               return H (""0440043E04410441043804390441043A043804390020044004430431043B044C"");");
         L ("            else");
         L ("               return H (""0440043E04410441043804390441043A043804350020044004430431043B0438"");");
         L ("            end if;");
         L ("         elsif Code = ""PLN"" then");
         L ("            if Singular then");
         L ("               return H (""043F043E043B044C0441043A0438043900200437043B043E0442044B0439"");");
         L ("            else");
         L ("               return H (""043F043E043B044C0441043A0438043500200437043B043E0442044B0435"");");
         L ("            end if;");
         L ("         elsif Code = ""CZK"" then");
         L ("            if Singular then");
         L ("               return H (""0447043504480441043A0430044F0020043A0440043E043D0430"");");
         L ("            else");
         L ("               return H (""0447043504480441043A043804350020043A0440043E043D044B"");");
         L ("            end if;");
         L ("         elsif Code = ""KWD"" then");
         L ("            if Singular then");
         L ("               return H (""043A044304320435043904420441043A04380439002004340438043D04300440"");");
         L ("            else");
         L ("               return H");
         L ("                 (""043A044304320435043904420441043A04380435002004340438043D04300440""");
         L ("                  & ""044B"");");
         L ("            end if;");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Code = ""USD"" then");
         L ("            if Singular then");
         L ("               return H (""062F06480644062706310020062306450631064A0643064A"");");
         L ("            else");
         L ("               return H (""062F06480644062706310627062A0020062306450631064A0643064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""CAD"" then");
         L ("            if Singular then");
         L ("               return H (""062F0648064406270631002006430646062F064A"");");
         L ("            else");
         L ("               return H (""062F06480644062706310627062A002006430646062F064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""AUD"" then");
         L ("            if Singular then");
         L ("               return H (""062F0648064406270631002006230633062A063106270644064A"");");
         L ("            else");
         L ("               return H (""062F06480644062706310627062A002006230633062A063106270644064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""NZD"" then");
         L ("            if Singular then");
         L ("               return H (""062F064806440627063100200646064A06480632064A06440646062F064A"");");
         L ("            else");
         L ("               return H");
         L ("                 (""062F06480644062706310627062A00200646064A06480632064A06440646062F""");
         L ("                  & ""064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""EUR"" then");
         L ("            if Singular then");
         L ("               return H (""064A064806310648"");");
         L ("            else");
         L ("               return H (""064A06480631064806470627062A"");");
         L ("            end if;");
         L ("         elsif Code = ""GBP"" then");
         L ("            if Singular then");
         L ("               return H (""062C0646064A0647002006250633062A06310644064A0646064A"");");
         L ("            else");
         L ("               return H (""062C0646064A06470627062A002006250633062A06310644064A0646064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""JPY"" then");
         L ("            if Singular then");
         L ("               return H (""064A06460020064A0627062806270646064A"");");
         L ("            else");
         L ("               return H (""064A06460627062A0020064A0627062806270646064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""CNY"" then");
         L ("            if Singular then");
         L ("               return H (""064A06480627064600200635064A0646064A"");");
         L ("            else");
         L ("               return H (""064A0648062706460627062A00200635064A0646064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""INR"" then");
         L ("            if Singular then");
         L ("               return H (""063106480628064A0629002006470646062F064A0629"");");
         L ("            else");
         L ("               return H (""063106480628064A0627062A002006470646062F064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""KRW"" then");
         L ("            if Singular then");
         L ("               return H (""0648064806460020064306480631064A0020062C064606480628064A"");");
         L ("            else");
         L ("               return H");
         L ("                 (""0648064806460627062A0020064306480631064A06290020062C064606480628""");
         L ("                  & ""064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""CHF"" then");
         L ("            if Singular then");
         L ("               return H (""0641063106460643002006330648064A06330631064A"");");
         L ("            else");
         L ("               return H (""06410631064606430627062A002006330648064A06330631064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""BRL"" then");
         L ("            if Singular then");
         L ("               return H (""0631064A0627064400200628063106270632064A0644064A"");");
         L ("            else");
         L ("               return H (""0631064A062706440627062A00200628063106270632064A0644064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""MXN"" then");
         L ("            if Singular then");
         L ("               return H (""0628064A063206480020064506430633064A0643064A"");");
         L ("            else");
         L ("               return H (""0628064A063206480627062A0020064506430633064A0643064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""DKK"" then");
         L ("            if Singular then");
         L ("               return H (""064306310648064606290020062F06460645062706310643064A0629"");");
         L ("            else");
         L ("               return H (""06430631064806460627062A0020062F06460645062706310643064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""NOK"" then");
         L ("            if Singular then");
         L ("               return H (""064306310648064606290020064606310648064A062C064A0629"");");
         L ("            else");
         L ("               return H (""06430631064806460627062A0020064606310648064A062C064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""SEK"" then");
         L ("            if Singular then");
         L ("               return H (""06430631064806460629002006330648064A062F064A0629"");");
         L ("            else");
         L ("               return H (""06430631064806460627062A002006330648064A062F064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""TRY"" then");
         L ("            if Singular then");
         L ("               return H (""0644064A063106290020062A06310643064A0629"");");
         L ("            else");
         L ("               return H (""0644064A06310627062A0020062A06310643064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""ZAR"" then");
         L ("            if Singular then");
         L ("               return H (""063106270646062F0020062C0646064806280020062306410631064A0642064A"");");
         L ("            else");
         L ("               return H");
         L ("                 (""063106270646062F0627062A0020062C0646064806280020062306410631064A""");
         L ("                  & ""0642064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""RUB"" then");
         L ("            if Singular then");
         L ("               return H (""06310648062806440020063106480633064A"");");
         L ("            else");
         L ("               return H (""06310648062806440627062A0020063106480633064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""PLN"" then");
         L ("            if Singular then");
         L ("               return H (""063206440648062A064A00200628064806440646062F064A"");");
         L ("            else");
         L ("               return H (""063206440648062A064A0627062A00200628064806440646062F064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""CZK"" then");
         L ("            if Singular then");
         L ("               return H (""064306310648064606290020062A0634064A0643064A0629"");");
         L ("            else");
         L ("               return H (""06430631064806460627062A0020062A0634064A0643064A0629"");");
         L ("            end if;");
         L ("         elsif Code = ""KWD"" then");
         L ("            if Singular then");
         L ("               return H (""062F064A064606270631002006430648064A062A064A"");");
         L ("            else");
         L ("               return H (""062F064606270646064A0631002006430648064A062A064A0629"");");
         L ("            end if;");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Code = ""USD"" then");
         L ("            return H (""7C7330C930EB"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return H (""30AB30CA30C030C930EB"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return H (""30AA30FC30B930C830E930EA30A230C930EB"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return H (""30CB30E530FC30B830FC30E930F330C930C930EB"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return H (""30E630FC30ED"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return H (""82F130DD30F330C9"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return H (""65E5672C5186"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return H (""4E2D56FD5143"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return H (""30A430F330C930EB30D430FC"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return H (""97D356FD30A630A930F3"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return H (""30B930A430B930D530E930F3"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return H (""30D630E930B830EB30EC30A230EB"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return H (""30E130AD30B730B330DA30BD"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return H (""30C730F330DE30FC30AF30AF30ED30FC30CD"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return H (""30CE30EB30A630A730FC30AF30ED30FC30CD"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return H (""30B930A630A730FC30C730F330AF30ED30FC30CA"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return H (""30C830EB30B330EA30E9"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return H (""535730A230D530EA30AB30E930F330C9"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return H (""30ED30B730A230EB30FC30D630EB"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return H (""30DD30FC30E930F330C930BA30ED30C1"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return H (""30C130A730B330B330EB30CA"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return H (""30AF30A630A730FC30C830C730A330CA30FC30EB"");");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Code = ""USD"" then");
         L ("            return H (""7F8E5143"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return H (""52A062FF59275143"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return H (""6FB3592752294E9A5143"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return H (""65B0897F51705143"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return H (""6B275143"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return H (""82F19551"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return H (""65E55143"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return H (""4EBA6C115E01"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return H (""53705EA653626BD4"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return H (""97E95143"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return H (""745E58EB6CD590CE"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return H (""5DF4897F96F74E9A5C14"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return H (""58A8897F54E56BD47D22"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return H (""4E399EA6514B6717"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return H (""632A5A01514B6717"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return H (""745E5178514B6717"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return H (""571F8033517691CC62C9"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return H (""5357975E51707279"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return H (""4FC47F5765AF53625E03"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return H (""6CE2517051797F5763D0"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return H (""6377514B514B6717"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return H (""79D15A0172797B2C7EB35C14"");");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Code = ""USD"" then");
         L ("            return H (""BBF8AD6D0020B2ECB7EC"");");
         L ("         elsif Code = ""CAD"" then");
         L ("            return H (""CE90B098B2E40020B2ECB7EC"");");
         L ("         elsif Code = ""AUD"" then");
         L ("            return H (""D638C8FC0020B2ECB7EC"");");
         L ("         elsif Code = ""NZD"" then");
         L ("            return H (""B274C9C8B79CB4DC0020B2ECB7EC"");");
         L ("         elsif Code = ""EUR"" then");
         L ("            return H (""C720B85C"");");
         L ("         elsif Code = ""GBP"" then");
         L ("            return H (""C601AD6D0020D30CC6B4B4DC"");");
         L ("         elsif Code = ""JPY"" then");
         L ("            return H (""C77CBCF80020C5D4"");");
         L ("         elsif Code = ""CNY"" then");
         L ("            return H (""C911AD6D0020C704C548"");");
         L ("         elsif Code = ""INR"" then");
         L ("            return H (""C778B3C40020B8E8D53C"");");
         L ("         elsif Code = ""KRW"" then");
         L ("            return H (""B300D55CBBFCAD6D0020C6D0"");");
         L ("         elsif Code = ""CHF"" then");
         L ("            return H (""C2A4C704C2A40020D504B791"");");
         L ("         elsif Code = ""BRL"" then");
         L ("            return H (""BE0CB77CC9C80020D5E4C54C"");");
         L ("         elsif Code = ""MXN"" then");
         L ("            return H (""BA55C2DCCF540020D398C18C"");");
         L ("         elsif Code = ""DKK"" then");
         L ("            return H (""B374B9C8D06C0020D06CB85CB124"");");
         L ("         elsif Code = ""NOK"" then");
         L ("            return H (""B178B974C6E8C7740020D06CB85CB124"");");
         L ("         elsif Code = ""SEK"" then");
         L ("            return H (""C2A4C6E8B3740020D06CB85CB098"");");
         L ("         elsif Code = ""TRY"" then");
         L ("            return H (""D280B974D0A4C6080020B9ACB77C"");");
         L ("         elsif Code = ""ZAR"" then");
         L ("            return H (""B0A8C544D504B9ACCE740020B79CB4DC"");");
         L ("         elsif Code = ""RUB"" then");
         L ("            return H (""B7ECC2DCC5440020B8E8BE14"");");
         L ("         elsif Code = ""PLN"" then");
         L ("            return H (""D3F4B780B4DC0020C988C6CCD2F0"");");
         L ("         elsif Code = ""CZK"" then");
         L ("            return H (""CCB4CF540020CF54B8E8B098"");");
         L ("         elsif Code = ""KWD"" then");
         L ("            return H (""CFE0C6E8C774D2B80020B514B098B974"");");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      if not Singular then");
         L ("         return Currency_Display_Name (Code);");
         L ("      elsif Code = ""USD"" then");
         L ("         return ""US dollar"";");
         L ("      elsif Code = ""CAD"" then");
         L ("         return ""Canadian dollar"";");
         L ("      elsif Code = ""AUD"" then");
         L ("         return ""Australian dollar"";");
         L ("      elsif Code = ""NZD"" then");
         L ("         return ""New Zealand dollar"";");
         L ("      elsif Code = ""EUR"" then");
         L ("         return ""euro"";");
         L ("      elsif Code = ""GBP"" then");
         L ("         return ""British pound"";");
         L ("      elsif Code = ""JPY"" then");
         L ("         return ""Japanese yen"";");
         L ("      elsif Code = ""CNY"" then");
         L ("         return ""Chinese yuan"";");
         L ("      elsif Code = ""INR"" then");
         L ("         return ""Indian rupee"";");
         L ("      elsif Code = ""KRW"" then");
         L ("         return ""South Korean won"";");
         L ("      elsif Code = ""CHF"" then");
         L ("         return ""Swiss franc"";");
         L ("      elsif Code = ""BRL"" then");
         L ("         return ""Brazilian real"";");
         L ("      elsif Code = ""MXN"" then");
         L ("         return ""Mexican peso"";");
         L ("      elsif Code = ""DKK"" then");
         L ("         return ""Danish krone"";");
         L ("      elsif Code = ""NOK"" then");
         L ("         return ""Norwegian krone"";");
         L ("      elsif Code = ""SEK"" then");
         L ("         return ""Swedish krona"";");
         L ("      elsif Code = ""TRY"" then");
         L ("         return ""Turkish lira"";");
         L ("      elsif Code = ""ZAR"" then");
         L ("         return ""South African rand"";");
         L ("      elsif Code = ""RUB"" then");
         L ("         return ""Russian ruble"";");
         L ("      elsif Code = ""PLN"" then");
         L ("         return ""Polish zloty"";");
         L ("      elsif Code = ""CZK"" then");
         L ("         return ""Czech koruna"";");
         L ("      elsif Code = ""KWD"" then");
         L ("         return ""Kuwaiti dinar"";");
         L ("      elsif Code = ""CLP"" then");
         L ("         return ""Chilean peso"";");
         L ("      elsif Code = ""COP"" then");
         L ("         return ""Colombian peso"";");
         L ("      elsif Code = ""ISK"" then");
         L ("         return ""Icelandic krona"";");
         L ("      elsif Code = ""MGA"" then");
         L ("         return ""Malagasy ariary"";");
         L ("      elsif Code = ""PYG"" then");
         L ("         return ""Paraguayan guarani"";");
         L ("      elsif Code = ""RWF"" then");
         L ("         return ""Rwandan franc"";");
         L ("      elsif Code = ""UGX"" then");
         L ("         return ""Ugandan shilling"";");
         L ("      elsif Code = ""UYI"" then");
         L ("         return ""Uruguayan indexed unit"";");
         L ("      elsif Code = ""VND"" then");
         L ("         return ""Vietnamese dong"";");
         L ("      elsif Code = ""XAF"" then");
         L ("         return ""Central African CFA franc"";");
         L ("      elsif Code = ""XOF"" then");
         L ("         return ""West African CFA franc"";");
         L ("      elsif Code = ""XPF"" then");
         L ("         return ""CFP franc"";");
         L ("      elsif Code = ""BHD"" then");
         L ("         return ""Bahraini dinar"";");
         L ("      elsif Code = ""JOD"" then");
         L ("         return ""Jordanian dinar"";");
         L ("      elsif Code = ""LYD"" then");
         L ("         return ""Libyan dinar"";");
         L ("      elsif Code = ""OMR"" then");
         L ("         return ""Omani rial"";");
         L ("      elsif Code = ""TND"" then");
         L ("         return ""Tunisian dinar"";");
         L ("      elsif Code = ""CLF"" then");
         L ("         return ""Chilean unit of account"";");
         L ("      elsif Code = ""HUF"" then");
         L ("         return ""Hungarian forint"";");
         L ("      elsif Code = ""AED"" then");
         L ("         return ""UAE dirham"";");
         L ("      elsif Code = ""SAR"" then");
         L ("         return ""Saudi riyal"";");
         L ("      elsif Code = ""SGD"" then");
         L ("         return ""Singapore dollar"";");
         L ("      elsif Code = ""HKD"" then");
         L ("         return ""Hong Kong dollar"";");
         L ("      elsif Code = ""TWD"" then");
         L ("         return ""New Taiwan dollar"";");
         L ("      elsif Code = ""IDR"" then");
         L ("         return ""Indonesian rupiah"";");
         L ("      elsif Code = ""MYR"" then");
         L ("         return ""Malaysian ringgit"";");
         L ("      elsif Code = ""PHP"" then");
         L ("         return ""Philippine peso"";");
         L ("      elsif Code = ""THB"" then");
         L ("         return ""Thai baht"";");
         L ("      elsif Code = ""PKR"" then");
         L ("         return ""Pakistani rupee"";");
         L ("      elsif Code = ""NPR"" then");
         L ("         return ""Nepalese rupee"";");
         L ("      elsif Code = ""ILS"" then");
         L ("         return ""Israeli new shekel"";");
         L ("      elsif Code = ""EGP"" then");
         L ("         return ""Egyptian pound"";");
         L ("      elsif Code = ""NGN"" then");
         L ("         return ""Nigerian naira"";");
         L ("      elsif Code = ""KES"" then");
         L ("         return ""Kenyan shilling"";");
         L ("      elsif Code = ""BIF"" then");
         L ("         return ""Burundian franc"";");
         L ("      elsif Code = ""DJF"" then");
         L ("         return ""Djiboutian franc"";");
         L ("      elsif Code = ""GNF"" then");
         L ("         return ""Guinean franc"";");
         L ("      elsif Code = ""KMF"" then");
         L ("         return ""Comorian franc"";");
         L ("      elsif Code = ""IQD"" then");
         L ("         return ""Iraqi dinar"";");
         L ("      elsif Code = ""ARS"" then");
         L ("         return ""Argentine peso"";");
         L ("      elsif Code = ""PEN"" then");
         L ("         return ""Peruvian sol"";");
         L ("      elsif Code = ""UYU"" then");
         L ("         return ""Uruguayan peso"";");
         L ("      elsif Code = ""CRC"" then");
         L ("         return ""Costa Rican colon"";");
         L ("      elsif Code = ""DOP"" then");
         L ("         return ""Dominican peso"";");
         L ("      elsif Code = ""GTQ"" then");
         L ("         return ""Guatemalan quetzal"";");
         L ("      elsif Code = ""HNL"" then");
         L ("         return ""Honduran lempira"";");
         L ("      elsif Code = ""NIO"" then");
         L ("         return ""Nicaraguan cordoba"";");
         L ("      elsif Code = ""PAB"" then");
         L ("         return ""Panamanian balboa"";");
         L ("      elsif Code = ""QAR"" then");
         L ("         return ""Qatari riyal"";");
         L ("      elsif Code = ""BDT"" then");
         L ("         return ""Bangladeshi taka"";");
         L ("      elsif Code = ""LKR"" then");
         L ("         return ""Sri Lankan rupee"";");
         L ("      elsif Code = ""MMK"" then");
         L ("         return ""Myanmar kyat"";");
         L ("      elsif Code = ""KHR"" then");
         L ("         return ""Cambodian riel"";");
         L ("      elsif Code = ""LAK"" then");
         L ("         return ""Lao kip"";");
         L ("      elsif Code = ""MNT"" then");
         L ("         return ""Mongolian togrog"";");
         L ("      elsif Code = ""MOP"" then");
         L ("         return ""Macanese pataca"";");
         L ("      elsif Code = ""BND"" then");
         L ("         return ""Brunei dollar"";");
         L ("      elsif Code = ""FJD"" then");
         L ("         return ""Fijian dollar"";");
         L ("      elsif Code = ""GEL"" then");
         L ("         return ""Georgian lari"";");
         L ("      else");
         L ("         return Currency_Display_Name (Code);");
         L ("      end if;");
         L ("   end Currency_Display_Name;");
      end Emit_Localized_Currency_Display_Name;

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

      procedure Emit_List_Final_Separator is
      begin
         Emit_Selected_Locale_Table
           ("List_Final_Separator", "list_separator", "standard", "final",
            """ and """);
      end Emit_List_Final_Separator;

      procedure Emit_List_Item_Separator is
      begin
         Emit_Selected_Locale_Table
           ("List_Item_Separator", "list_separator", "standard", "item",
            """, """);
      end Emit_List_Item_Separator;

      procedure Emit_List_Pattern_Separators is
         procedure Emit_List_Pattern_Function
           (Function_Name : String;
            Family        : String;
            Part          : String;
            Fallback_Call : String)
         is
         begin
            Emit_Selected_Locale_Table
              (Function_Name, "list_separator", Family, Part, Fallback_Call);
         end Emit_List_Pattern_Function;
      begin
         L;
         Emit_List_Pattern_Function
           ("List_Pair_Separator", "standard", "pair", "List_Final_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Start_Separator", "standard", "start", "List_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Middle_Separator", "standard", "middle", "List_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Or_Final_Separator", "or", "final", """ or """);
         L;
         Emit_List_Pattern_Function
           ("List_Or_Pair_Separator", "or", "pair", "List_Or_Final_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Or_Start_Separator", "or", "start", "List_Start_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Or_Middle_Separator", "or", "middle", "List_Middle_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Or_Item_Separator", "or", "item", "List_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Unit_Item_Separator", "unit", "item", "List_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Unit_Final_Separator", "unit", "final", "List_Unit_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Unit_Pair_Separator", "unit", "pair", "List_Unit_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Unit_Start_Separator", "unit", "start", "List_Unit_Item_Separator (Locale)");
         L;
         Emit_List_Pattern_Function
           ("List_Unit_Middle_Separator", "unit", "middle", "List_Unit_Item_Separator (Locale)");
      end Emit_List_Pattern_Separators;

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

      --  A unit record used to spell out its base, width and category:
      --  "unit-width-full-name" alone accounted for 3.8 million characters
      --  of the table, for three distinct values. Each field becomes a code
      --  instead -- two characters for the base, one each for the width and
      --  the category -- which the generated body maps its arguments to
      --  once per call rather than comparing per record.
      Max_Unit_Bases : constant := 512;
      Unit_Base_Names : array (1 .. Max_Unit_Bases) of US.Unbounded_String;
      Unit_Base_Count : Natural := 0;

      procedure Collect_Unit_Bases is
      begin
         --  Sorted, so the generated body can bisect them.
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "unit_name") then
               declare
                  Name : constant String := S (Rules (Index).B);
                  Slot : Natural := 0;
               begin
                  for Position in 1 .. Unit_Base_Count loop
                     if S (Unit_Base_Names (Position)) = Name then
                        Slot := Position;
                        exit;
                     end if;
                  end loop;

                  if Slot = 0 then
                     if Name'Length > 33 then
                        Add_Error ("unit base does not fit the index: " & Name);
                     elsif Unit_Base_Count = Max_Unit_Bases then
                        Add_Error ("too many unit bases");
                     else
                        Unit_Base_Count := Unit_Base_Count + 1;
                        Unit_Base_Names (Unit_Base_Count) :=
                          US.To_Unbounded_String (Name);
                     end if;
                  end if;
               end;
            end if;
         end loop;

         for Outer in 2 .. Unit_Base_Count loop
            declare
               Current : constant US.Unbounded_String :=
                 Unit_Base_Names (Outer);
               Probe : Natural := Outer - 1;
            begin
               while Probe >= 1
                 and then S (Unit_Base_Names (Probe)) > S (Current)
               loop
                  Unit_Base_Names (Probe + 1) := Unit_Base_Names (Probe);
                  Probe := Probe - 1;
               end loop;
               Unit_Base_Names (Probe + 1) := Current;
            end;
         end loop;
      end Collect_Unit_Bases;

      function Unit_Base_Code (Name : String) return String is
      begin
         for Position in 1 .. Unit_Base_Count loop
            if S (Unit_Base_Names (Position)) = Name then
               return
                 [1 => Code_Alphabet
                         (Code_Alphabet'First + (Position - 1) / 62),
                  2 => Code_Alphabet
                         (Code_Alphabet'First + (Position - 1) mod 62)];
            end if;
         end loop;

         return "  ";
      end Unit_Base_Code;

      function Unit_Width_Code (Value : String) return String is
        (if Value = "unit-width-full-name" then "f"
         elsif Value = "unit-width-short" then "s"
         elsif Value = "unit-width-narrow" then "n"
         else " ");

      function Unit_Category_Code (Value : String) return String is
        (if Value = "other" then "o"
         elsif Value = "one" then "1"
         elsif Value = "zero" then "z"
         elsif Value = "two" then "2"
         elsif Value = "few" then "w"
         elsif Value = "many" then "m"
         else " ");

      procedure Emit_Unit_Display_Name is
         procedure Emit_String_Term (Value : String) is
            Chunk_Size : constant := Data_Chunk;
            Start      : Positive := Value'First;
            Stop       : Natural;
         begin
            if Value'Length = 0 then
               return;
            end if;

            while Start <= Value'Last loop
               Stop := Natural'Min (Start + Chunk_Size - 1, Value'Last);
               L ("        & """ & Value (Start .. Stop) & """");
               Start := Stop + 1;
            end loop;
         end Emit_String_Term;
         pragma Unreferenced (Emit_String_Term);
      begin
         Collect_Unit_Bases;
         L;
         L ("   function Unit_Display_Name");
         L ("     (Locale   : String;");
         L ("      Base     : String;");
         L ("      Width    : String;");
         L ("      Category : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang     : constant String := Language (Locale);");
         L ("      Singular : constant Boolean := Category = ""one"";");
         L ("      Plural   : constant Boolean := not Singular;");
         --  847,585 records, and Search walked all of them from the first
         --  character on every pass -- as many as nine passes to a lookup,
         --  so some seven million record parses to answer one call. Grouped
         --  by locale, so each locale becomes a segment of about eleven
         --  hundred records and the locale field leaves the record.
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "unit_name") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Unit_Base_Code (S (Rules (Index).B))
                     & Unit_Width_Code (S (Rules (Index).C))
                     & Unit_Category_Code (S (Rules (Index).D))
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).E)) & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;

         --  Nested in the function, as the packed data already was: a
         --  subunit holds one subprogram, so the table cannot be a sibling.
         Emit_Locale_Table
           ("Unit_Name_Row", """""", Raw => True, Walk_Parents => False);

         --  The base names, so a record can carry a two-character code
         --  instead of the name. Bisected on a 33-character padded key.
         L;
         L ("      Base_Index : constant String :=");
         declare
            Index_Text : US.Unbounded_String;
         begin
            for Position in 1 .. Unit_Base_Count loop
               declare
                  Name : constant String := S (Unit_Base_Names (Position));
               begin
                  US.Append (Index_Text, Name);
                  US.Append (Index_Text, [1 .. 33 - Name'Length => ' ']);
                  US.Append (Index_Text, Unit_Base_Code (Name));
               end;
            end loop;
            Emit_Unit_String_Expression ("        ", S (Index_Text), ";");
         end;
         L ("      Base_Width : constant := 35;");
         L ("      Base_Count : constant Natural :=");
         L ("        Base_Index'Length / Base_Width;");
         L;
         L ("      --  "" "" is not a code, so an unknown base matches nothing --");
         L ("      --  which is what comparing an unknown name did before.");
         L ("      function Base_Code return String is");
         L ("         Low : Natural := 1;");
         L ("         High : Natural := Base_Count;");
         L ("         Mid : Natural;");
         L ("         Wanted : constant String :=");
         L ("           (if Base'Length >= 33 then Base (Base'First .. Base'First + 32)");
         L ("            else Base & (1 .. 33 - Base'Length => ' '));");
         L ("      begin");
         L ("         while Low <= High loop");
         L ("            Mid := (Low + High) / 2;");
         L ("            declare");
         L ("               At_Key : constant Natural :=");
         L ("                 Base_Index'First + (Mid - 1) * Base_Width;");
         L ("               Key : constant String :=");
         L ("                 Base_Index (At_Key .. At_Key + 32);");
         L ("            begin");
         L ("               if Key = Wanted then");
         L ("                  return Base_Index (At_Key + 33 .. At_Key + 34);");
         L ("               elsif Key < Wanted then");
         L ("                  Low := Mid + 1;");
         L ("               else");
         L ("                  High := Mid - 1;");
         L ("               end if;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return ""  "";");
         L ("      end Base_Code;");
         L;
         L ("      function Width_Code return String is");
         L ("        (if Width = ""unit-width-full-name"" then ""f""");
         L ("         elsif Width = ""unit-width-short"" then ""s""");
         L ("         elsif Width = ""unit-width-narrow"" then ""n""");
         L ("         else "" "");");
         L;
         L ("      function Category_Code (Want : String) return String is");
         L ("        (if Want = ""other"" then ""o""");
         L ("         elsif Want = ""one"" then ""1""");
         L ("         elsif Want = ""zero"" then ""z""");
         L ("         elsif Want = ""two"" then ""2""");
         L ("         elsif Want = ""few"" then ""w""");
         L ("         elsif Want = ""many"" then ""m""");
         L ("         else "" "");");
         L;
         L ("      Wanted_Base : constant String := Base_Code;");
         L ("      Wanted_Width : constant String := Width_Code;");

         L;
         L ("      function Extended_Unit_Name return String is");
         L ("      begin");
         L ("         return """";");
         L ("      end Extended_Unit_Name;");
         L;
         L ("      --  Records are a four-character key -- two for the base,");
         L ("      --  one for the width, one for the category -- then the hex.");
         L ("      --  The labels themselves were four fifths of this table.");
         L ("      function Search (Rows : String; Want : String) return String is");
         L ("         Start : Positive := Rows'First;");
         L ("         Key : constant String :=");
         L ("           Wanted_Base & Wanted_Width & Category_Code (Want);");
         L ("      begin");
         L ("         if Key (Key'First) = ' ' or else Key (Key'Last) = ' ' then");
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
         L ("               if Stop > Start + 4");
         L ("                 and then Rows (Start .. Start + 3) = Key");
         L ("               then");
         L ("                  return VB (Rows (Start + 4 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      function Category_Row (Want : String) return String is");
         L ("         Exact : constant String :=");
         L ("           Search (Unit_Name_Row (Locale), Want);");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L;
         L ("         --  Then each parent, longest first.");
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    Search");
         L ("                      (Unit_Name_Row (Canon (Canon'First .. Cut - 1)),");
         L ("                       Want);");
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
         L ("      end Category_Row;");
         L;
         L ("      --  Root (und) rows carry the CLDR abbreviated forms used by any");
         L ("      --  locale that supplies no data of its own. They are the final");
         L ("      --  resort before the built-in English defaults, and only the");
         L ("      --  abbreviated (short/narrow) widths consult them -- full names");
         L ("      --  keep falling through to the English word forms.");
         L ("      --");
         L ("      --  root before und, the order the records were in.");
         L ("      function Root_Category_Row (Want : String) return String is");
         L ("         Rooted : constant String := Search (Unit_Name_Row (""root""), Want);");
         L ("      begin");
         L ("         if Rooted /= """" then");
         L ("            return Rooted;");
         L ("         end if;");
         L ("         return Search (Unit_Name_Row (""und""), Want);");
         L ("      end Root_Category_Row;");
         L;
         L ("      function Root_Row return String is");
         L ("         Primary : constant String := Root_Category_Row (Category);");
         L ("      begin");
         L ("         if Primary /= """" then");
         L ("            return Primary;");
         L ("         end if;");
         L ("         if Category /= ""other"" then");
         L ("            declare");
         L ("               Other_Row : constant String :=");
         L ("                 Root_Category_Row (""other"");");
         L ("            begin");
         L ("               if Other_Row /= """" then");
         L ("                  return Other_Row;");
         L ("               end if;");
         L ("            end;");
         L ("         end if;");
         L ("         if Category /= ""one"" then");
         L ("            return Root_Category_Row (""one"");");
         L ("         end if;");
         L ("         return """";");
         L ("      end Root_Row;");
         L;
         L ("      function Localized_Row return String is");
         L ("         Primary : constant String := Category_Row (Category);");
         L ("      begin");
         L ("         if Primary /= """" then");
         L ("            return Primary;");
         L ("         end if;");
         L ("         if Category /= ""other"" then");
         L ("            declare");
         L ("               Other_Row : constant String := Category_Row (""other"");");
         L ("            begin");
         L ("               if Other_Row /= """" then");
         L ("                  return Other_Row;");
         L ("               end if;");
         L ("            end;");
         L ("         end if;");
         L ("         if Category /= ""one"" then");
         L ("            return Category_Row (""one"");");
         L ("         end if;");
         L ("         return """";");
         L ("      end Localized_Row;");
         L ("   begin");
         L ("      if Width = ""unit-width-short""");
         L ("        or else Width = ""short""");
         L ("        or else Width = ""unit-width-narrow""");
         L ("        or else Width = ""narrow""");
         L ("      then");
         L ("         declare");
         L ("            Localized : constant String := Localized_Row;");
         L ("         begin");
         L ("            if Localized /= """" then");
         L ("               return Localized;");
         L ("            end if;");
         L ("         end;");
         L ("         declare");
         L ("            Root_Value : constant String := Root_Row;");
         L ("         begin");
         L ("            if Root_Value /= """" then");
         L ("               return Root_Value;");
         L ("            end if;");
         L ("         end;");
         declare
            Opened : Boolean := False;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "unit_short") then
                  L
                    ("         "
                     & (if Opened then "elsif " else "if ")
                     & "Base = """ & S (Rules (Index).A) & """ then");
                  L ("            return " & S (Rules (Index).B) & ";");
                  Opened := True;
               end if;
            end loop;

            if Opened then
               L ("         end if;");
            end if;
         end;
         L ("         if Base = ""meter"" then");
         L ("            return ""m"";");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return ""km"";");
         L ("         elsif Base = ""mile"" then");
         L ("            return ""mi"";");
         L ("         elsif Base = ""yard"" then");
         L ("            return ""yd"";");
         L ("         elsif Base = ""foot"" then");
         L ("            return ""ft"";");
         L ("         elsif Base = ""inch"" then");
         L ("            return ""in"";");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return ""cm"";");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return ""mm"";");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return ""nmi"";");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return ""au"";");
         L ("         elsif Base = ""light-year"" then");
         L ("            return ""ly"";");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""pc"";");
         L ("         elsif Base = ""fathom"" then");
         L ("            return ""fth"";");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""fur"";");
         L ("         elsif Base = ""pixel"" then");
         L ("            return ""px"";");
         L ("         elsif Base = ""point"" then");
         L ("            return ""pt"";");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return ""Rsun"";");
         L ("         elsif Base = ""liter"" then");
         L ("            return ""L"";");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return ""mL"";");
         L ("         elsif Base = ""gallon"" then");
         L ("            return ""gal"";");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return ""fl oz"";");
         L ("         elsif Base = ""cup"" then");
         L ("            return ""c"";");
         L ("         elsif Base = ""pint"" then");
         L ("            return ""pt"";");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""qt"";");
         L ("         elsif Base = ""gram"" then");
         L ("            return ""g"";");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return ""kg"";");
         L ("         elsif Base = ""milligram"" then");
         L ("            return ""mg"";");
         L ("         elsif Base = ""tonne"" then");
         L ("            return ""t"";");
         L ("         elsif Base = ""pound"" then");
         L ("            return ""lb"";");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""oz"";");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""st"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return ""ct"";");
         L ("         elsif Base = ""nanosecond"" then");
         L ("            return ""ns"";");
         L ("         elsif Base = ""microsecond"" then");
         L ("            return ""us"";");
         L ("         elsif Base = ""millisecond"" then");
         L ("            return ""ms"";");
         L ("         elsif Base = ""second"" then");
         L ("            return ""s"";");
         L ("         elsif Base = ""minute"" then");
         L ("            return ""min"";");
         L ("         elsif Base = ""hour"" then");
         L ("            return ""h"";");
         L ("         elsif Base = ""day"" then");
         L ("            return ""d"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""wk"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""mo"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""yr"";");
         L ("         elsif Base = ""square-meter"" then");
         L ("            return ""m2"";");
         L ("         elsif Base = ""square-kilometer"" then");
         L ("            return ""km2"";");
         L ("         elsif Base = ""acre"" then");
         L ("            return ""ac"";");
         L ("         elsif Base = ""hectare"" then");
         L ("            return ""ha"";");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return ""ft2"";");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return ""mi2"";");
         L ("         elsif Base = ""celsius"" then");
         L ("            return ""C"";");
         L ("         elsif Base = ""fahrenheit"" then");
         L ("            return ""F"";");
         L ("         elsif Base = ""degree"" then");
         L ("            return ""deg"";");
         L ("         elsif Base = ""byte"" then");
         L ("            return ""B"";");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"";");
         L ("         elsif Base = ""kilobyte"" then");
         L ("            return ""KB"";");
         L ("         elsif Base = ""megabyte"" then");
         L ("            return ""MB"";");
         L ("         elsif Base = ""gigabyte"" then");
         L ("            return ""GB"";");
         L ("         elsif Base = ""terabyte"" then");
         L ("            return ""TB"";");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""Mbit"";");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""Gbit"";");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""PB"";");
         L ("         elsif Base = ""kilometer-per-hour"" then");
         L ("            return ""km/h"";");
         L ("         elsif Base = ""mile-per-hour"" then");
         L ("            return ""mph"";");
         L ("         elsif Base = ""meter-per-second"" then");
         L ("            return ""m/s"";");
         L ("         elsif Base = ""joule"" then");
         L ("            return ""J"";");
         L ("         elsif Base = ""kilojoule"" then");
         L ("            return ""kJ"";");
         L ("         elsif Base = ""calorie"" then");
         L ("            return ""cal"";");
         L ("         elsif Base = ""kilocalorie"" then");
         L ("            return ""kcal"";");
         L ("         elsif Base = ""kilowatt-hour"" then");
         L ("            return ""kWh"";");
         L ("         elsif Base = ""watt"" then");
         L ("            return ""W"";");
         L ("         elsif Base = ""kilowatt"" then");
         L ("            return ""kW"";");
         L ("         elsif Base = ""hertz"" then");
         L ("            return ""Hz"";");
         L ("         elsif Base = ""kilohertz"" then");
         L ("            return ""kHz"";");
         L ("         elsif Base = ""megahertz"" then");
         L ("            return ""MHz"";");
         L ("         elsif Base = ""hectopascal"" then");
         L ("            return ""hPa"";");
         L ("         elsif Base = ""pascal"" then");
         L ("            return ""Pa"";");
         L ("         elsif Base = ""kilopascal"" then");
         L ("            return ""kPa"";");
         L ("         elsif Base = ""millibar"" then");
         L ("            return ""mbar"";");
         L ("         elsif Base = ""bar"" then");
         L ("            return ""bar"";");
         L ("         elsif Base = ""atmosphere"" then");
         L ("            return ""atm"";");
         L ("         elsif Base = ""inch-ofhg"" then");
         L ("            return ""inHg"";");
         L ("         elsif Base = ""millimeter-ofhg"" then");
         L ("            return ""mmHg"";");
         L ("         elsif Base = ""ampere"" then");
         L ("            return ""A"";");
         L ("         elsif Base = ""volt"" then");
         L ("            return ""V"";");
         L ("         elsif Base = ""ohm"" then");
         L ("            return ""ohm"";");
         L ("         elsif Base = ""lumen"" then");
         L ("            return ""lm"";");
         L ("         elsif Base = ""lux"" then");
         L ("            return ""lx"";");
         L ("         elsif Base = ""percent"" then");
         L ("            return ""%"";");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      else");
         L ("         declare");
         L ("            Localized : constant String := Localized_Row;");
         L ("         begin");
         L ("            if Localized /= """" then");
         L ("               return Localized;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L;
         L ("      if Extended_Unit_Name /= """" then");
         L ("         return Extended_Unit_Name;");
         L ("      elsif Lang = ""fr"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then U (16#E9#) & ""l"" & U (16#E9#)");
         L ("                    & ""ments"" else U (16#E9#) & ""l"" & U (16#E9#)");
         L ("                    & ""ment"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return ""m"" & U (16#E8#) & ""tre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return ""kilom"" & U (16#E8#) & ""tre""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""mile"" then");
         L ("            return ""mille"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then ""milles marins"" else ""mille marin"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""unit"" & U (16#E9#) & ""s astronomiques""");
         L ("                    else ""unit"" & U (16#E9#) & "" astronomique"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural");
         L ("                    then ""ann"" & U (16#E9#) & ""es-lumi"" & U (16#E8#) & ""re""");
         L ("                    else ""ann"" & U (16#E9#) & ""e-lumi"" & U (16#E8#) & ""re"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""parsec"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return ""brasse"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""furlong"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return ""pixel"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""point"" then");
         L ("            return ""point"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural then ""rayons solaires"" else ""rayon solaire"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return ""centim"" & U (16#E8#) & ""tre""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return ""millim"" & U (16#E8#) & ""tre""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""pieds carr"" & U (16#E9#) & ""s""");
         L ("                    else ""pied carr"" & U (16#E9#));");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""milles carr"" & U (16#E9#) & ""s""");
         L ("                    else ""mille carr"" & U (16#E9#));");
         L ("         elsif Base = ""liter"" then");
         L ("            return ""litre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return ""millilitre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return ""gallon"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural then ""onces liquides"" else ""once liquide"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return ""tasse"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pint"" then");
         L ("            return ""pinte"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""quart"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return ""gramme"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return ""kilogramme"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return ""milligramme"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return ""tonne"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pound"" then");
         L ("            return ""livre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""once"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""carat"" then");
         L ("            return ""carat"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""second"" then");
         L ("            return ""seconde"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""minute"" then");
         L ("            return ""minute"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hour"" then");
         L ("            return ""heure"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""day"" then");
         L ("            return ""jour"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""week"" then");
         L ("            return ""semaine"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""month"" then");
         L ("            return ""mois"";");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""ans"" else ""an"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""m"" & U (16#E9#) & ""gabit""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""gigabit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""p"" & U (16#E9#) & ""taoctet""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""acre"" then");
         L ("            return ""acre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hectare"" then");
         L ("            return ""hectare"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""joule"" then");
         L ("            return ""joule"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilojoule"" then");
         L ("            return ""kilojoule"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""calorie"" then");
         L ("            return ""calorie"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilocalorie"" then");
         L ("            return ""kilocalorie"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilowatt-hour"" then");
         L ("            return ""kilowatt-heure"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""watt"" then");
         L ("            return ""watt"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilowatt"" then");
         L ("            return ""kilowatt"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hertz"" then");
         L ("            return ""hertz"";");
         L ("         elsif Base = ""kilohertz"" then");
         L ("            return ""kilohertz"";");
         L ("         elsif Base = ""megahertz"" then");
         L ("            return ""m"" & U (16#E9#) & ""gahertz"";");
         L ("         elsif Base = ""hectopascal"" then");
         L ("            return ""hectopascal"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""millibar"" then");
         L ("            return ""millibar"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""percent"" then");
         L ("            return ""pour cent"";");
         L ("         end if;");
         L ("      elsif Lang = ""es"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elementos"" else ""elemento"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return ""metro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return U (16#6B#) & ""il"" & U (16#F3#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""mile"" then");
         L ("            return ""milla"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""millas n"" & U (16#E1#) & ""uticas""");
         L ("                    else ""milla n"" & U (16#E1#) & ""utica"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""unidades astron"" & U (16#F3#) & ""micas""");
         L ("                    else ""unidad astron"" & U (16#F3#) & ""mica"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""a"" & U (16#F1#) & ""os luz"" else ""a"" & U (16#F1#) & ""o luz"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""p"" & U (16#E1#) & ""rsec"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return ""braza"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""estadio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""p"" & U (16#ED#) & ""xeles"" else ""p"" & U (16#ED#) & ""xel"");");
         L ("         elsif Base = ""point"" then");
         L ("            return ""punto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return ""radio"" & (if Plural then ""s solares"" else "" solar"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return ""cent"" & U (16#ED#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return ""mil"" & U (16#ED#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural then ""pies cuadrados"" else ""pie cuadrado"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""millas cuadradas"" else ""milla cuadrada"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return ""litro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return ""mililitro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return ""gal"" & U (16#F3#) & ""n"" & (if Plural then ""es"" else """");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural");
         L ("                    then ""onzas l"" & U (16#ED#) & ""quidas""");
         L ("                    else ""onza l"" & U (16#ED#) & ""quida"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return ""taza"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pint"" then");
         L ("            return ""pinta"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""cuarto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return ""gramo"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return ""kilogramo"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return ""miligramo"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return ""tonelada"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pound"" then");
         L ("            return ""libra"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""onza"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return ""quilate"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""second"" then");
         L ("            return ""segundo"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""minute"" then");
         L ("            return ""minuto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hour"" then");
         L ("            return ""hora"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then U (16#64#) & U (16#ED#) & ""as""");
         L ("                    else U (16#64#) & U (16#ED#) & ""a"");");
         L ("         elsif Base = ""week"" then");
         L ("            return ""semana"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""meses"" else ""mes"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""a"" & U (16#F1#) & ""o"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""megabit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""gigabit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""petabyte"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""acre"" then");
         L ("            return ""acre"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hectare"" then");
         L ("            return ""hect"" & U (16#E1#) & ""rea"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""joule"" then");
         L ("            return ""julio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilojoule"" then");
         L ("            return ""kilojulio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""calorie"" then");
         L ("            return ""calor"" & U (16#ED#) & ""a"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilocalorie"" then");
         L ("            return ""kilocalor"" & U (16#ED#) & ""a"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilowatt-hour"" then");
         L ("            return ""kilovatio hora"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""watt"" then");
         L ("            return ""vatio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilowatt"" then");
         L ("            return ""kilovatio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hertz"" then");
         L ("            return ""hercio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilohertz"" then");
         L ("            return ""kilohercio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""megahertz"" then");
         L ("            return ""megahercio"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hectopascal"" then");
         L ("            return ""hectopascal"" & (if Plural then ""es"" else """");");
         L ("         elsif Base = ""millibar"" then");
         L ("            return ""millibar"" & (if Plural then ""es"" else """");");
         L ("         elsif Base = ""percent"" then");
         L ("            return ""por ciento"";");
         L ("         end if;");
         L ("      elsif Lang = ""it"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elementi"" else ""elemento"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metri"" else ""metro"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""chilometri"" else ""chilometro"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""miglia"" else ""miglio"");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then ""miglia nautiche"" else ""miglio nautico"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""unit"" & U (16#E0#) & "" astronomiche""");
         L ("                    else ""unit"" & U (16#E0#) & "" astronomica"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""anni luce"" else ""anno luce"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""parsec"";");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then ""braccia"" else ""braccio"");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""furlong"";");
         L ("         elsif Base = ""pixel"" then");
         L ("            return ""pixel"";");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""punti"" else ""punto"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural then ""raggi solari"" else ""raggio solare"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centimetri"" else ""centimetro"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""millimetri"" else ""millimetro"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural then ""piedi quadrati"" else ""piede quadrato"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""miglia quadrate"" else ""miglio quadrato"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litri"" else ""litro"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""millilitri"" else ""millilitro"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galloni"" else ""gallone"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural then ""once fluide"" else ""oncia fluida"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""tazze"" else ""tazza"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pinte"" else ""pinta"");");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then ""quarti"" else ""quarto"");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""grammi"" else ""grammo"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""chilogrammi"" else ""chilogrammo"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""milligrammi"" else ""milligrammo"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""tonnellate"" else ""tonnellata"");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""libbre"" else ""libbra"");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then ""once"" else ""oncia"");");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""carati"" else ""carato"");");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then ""secondi"" else ""secondo"");");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minuti"" else ""minuto"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then ""ore"" else ""ora"");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""giorni"" else ""giorno"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then ""settimane"" else ""settimana"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""mesi"" else ""mese"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""anni"" else ""anno"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"";");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""megabit"";");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""gigabit"";");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""petabyte"";");
         L ("         end if;");
         L ("      elsif Lang = ""pt"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""itens"" else ""item"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return ""metro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return ""quil"" & U (16#F4#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""mile"" then");
         L ("            return ""milha"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""milhas n"" & U (16#E1#) & ""uticas""");
         L ("                    else ""milha n"" & U (16#E1#) & ""utica"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""unidades astron"" & U (16#F4#) & ""micas""");
         L ("                    else ""unidade astron"" & U (16#F4#) & ""mica"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""anos-luz"" else ""ano-luz"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""parsec"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return ""bra"" & U (16#E7#) & ""a""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""furlong"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""pixels"" else ""pixel"");");
         L ("         elsif Base = ""point"" then");
         L ("            return ""ponto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return ""raio"" & (if Plural then ""s solares"" else "" solar"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return ""cent"" & U (16#ED#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return ""mil"" & U (16#ED#) & ""metro""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""p"" & U (16#E9#) & ""s quadrados""");
         L ("                    else ""p"" & U (16#E9#) & "" quadrado"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""milhas quadradas"" else ""milha quadrada"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return ""litro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return ""mililitro"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return ""gal"" & U (16#E3#) & ""o"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural");
         L ("                    then ""on"" & U (16#E7#) & ""as fluidas""");
         L ("                    else ""on"" & U (16#E7#) & ""a fluida"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return ""x"" & U (16#ED#) & ""cara""");
         L ("              & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pint"" then");
         L ("            return ""pinta"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""quarto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return ""grama"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return ""quilograma"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return ""miligrama"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return ""tonelada"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pound"" then");
         L ("            return ""libra"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""on"" & U (16#E7#) & ""a"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return ""quilate"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""second"" then");
         L ("            return ""segundo"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""minute"" then");
         L ("            return ""minuto"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""hour"" then");
         L ("            return ""hora"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""day"" then");
         L ("            return ""dia"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""week"" then");
         L ("            return ""semana"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""meses"" else ""m"" & U (16#EA#) & ""s"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""ano"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""megabit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""gigabit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""petabyte"" & (if Plural then ""s"" else """");");
         L ("         end if;");
         L ("      elsif Lang = ""nl"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""items"" else ""item"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return ""meter"";");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return ""kilometer"";");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""mijlen"" else ""mijl"");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then ""zeemijlen"" else ""zeemijl"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""astronomische eenheden""");
         L ("                    else ""astronomische eenheid"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""lichtjaren"" else ""lichtjaar"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""parsec"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return ""vadem"";");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""furlong"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return ""pixel"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""point"" then");
         L ("            return ""punt"" & (if Plural then ""en"" else """");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural then ""zonsstralen"" else ""zonsstraal"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return ""centimeter"";");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return ""millimeter"";");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return ""vierkante voet"";");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""vierkante mijlen"" else ""vierkante mijl"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return ""liter"";");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return ""milliliter"";");
         L ("         elsif Base = ""gallon"" then");
         L ("            return ""gallon"";");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return ""fluid ounce"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""kopjes"" else ""kopje"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return ""pint"" & (if Plural then ""en"" else """");");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""quart"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return ""gram"";");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return ""kilogram"";");
         L ("         elsif Base = ""milligram"" then");
         L ("            return ""milligram"";");
         L ("         elsif Base = ""tonne"" then");
         L ("            return ""ton"";");
         L ("         elsif Base = ""pound"" then");
         L ("            return ""pond"";");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""ons"";");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return ""karaat"";");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then ""seconden"" else ""seconde"");");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minuten"" else ""minuut"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return ""uur"";");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""dagen"" else ""dag"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then ""weken"" else ""week"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""maanden"" else ""maand"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""jaar"";");
         L ("         elsif Base = ""bit"" then");
         L ("            return ""bit"" & (if Plural then ""s"" else """");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return ""megabit"";");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return ""gigabit"";");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""petabyte"";");
         L ("         end if;");
         L ("      elsif Lang = ""ro"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elemente"" else ""element"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metri"" else ""metru"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""kilometri"" else ""kilometru"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""mile"" else ""mil"" & U (16#103#));");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""mile nautice""");
         L ("                    else ""mil"" & U (16#103#) & "" nautic""");
         L ("                         & U (16#103#));");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""unit"" & U (16#103#) & U (16#21B#)");
         L ("                         & ""i astronomice""");
         L ("                    else ""unitate astronomic"" & U (16#103#));");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""ani-lumin"" & U (16#103#)");
         L ("                    else ""an-lumin"" & U (16#103#));");
         L ("         elsif Base = ""parsec"" then");
         L ("            return ""parsec"" & (if Plural then ""i"" else """");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then ""st"" & U (16#E2#) & ""njeni""");
         L ("                    else ""st"" & U (16#E2#) & ""njen"");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return ""furlong"" & (if Plural then ""i"" else """");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return ""pixel"" & (if Plural then ""i"" else """");");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""puncte"" else ""punct"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural then ""raze solare"" else ""raz""");
         L ("                    & U (16#103#) & "" solar"" & U (16#103#));");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centimetri"" else ""centimetru"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""milimetri"" else ""milimetru"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""picioare p"" & U (16#103#) & ""trate""");
         L ("                    else ""picior p"" & U (16#103#) & ""trat"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""mile p"" & U (16#103#) & ""trate""");
         L ("                    else ""mil"" & U (16#103#) & "" p""");
         L ("                         & U (16#103#) & ""trat"" & U (16#103#));");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litri"" else ""litru"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""mililitri"" else ""mililitru"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galoane"" else ""galon"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural then ""uncii lichide"" else ""uncie lichid""");
         L ("                    & U (16#103#));");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""ce"" & U (16#219#) & ""ti""");
         L ("                    else ""cea"" & U (16#219#) & ""c"" & U (16#103#));");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pinte"" else ""pint"" & U (16#103#));");
         L ("         elsif Base = ""quart"" then");
         L ("            return ""quart"" & (if Plural then ""uri"" else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""grame"" else ""gram"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""kilograme"" else ""kilogram"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""miligrame"" else ""miligram"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""tone"" else ""ton"" & U (16#103#));");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""livre"" else ""livr"" & U (16#103#));");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then ""uncii"" else ""uncie"");");
         L ("         elsif Base = ""stone"" then");
         L ("            return ""stone"";");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""carate"" else ""carat"");");
         L ("         elsif Base = ""second"" then");
         L ("            return");
         L ("              (if Plural then ""secunde"" else ""secund"" & U (16#103#));");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minute"" else ""minut"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""ore""");
         L ("               else ""or"" & U (16#103#));");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""zile"" else ""zi"");");
         L ("         elsif Base = ""week"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""s"" & U (16#103#) & ""pt"" & U (16#103#)");
         L ("                    & ""m"" & U (16#E2#) & ""ni""");
         L ("               else ""s"" & U (16#103#) & ""pt"" & U (16#103#)");
         L ("                    & ""m"" & U (16#E2#) & ""n"" & U (16#103#));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""luni"" else ""lun"" & U (16#103#));");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""ani"" else ""an"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then ""bi"" & U (16#21B#) & ""i""");
         L ("                    else ""bit"");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return (if Plural then ""megabi"" & U (16#21B#) & ""i""");
         L ("                    else ""megabit"");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then ""gigabi"" & U (16#21B#) & ""i""");
         L ("                    else ""gigabit"");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return ""petabyte"";");
         L ("         end if;");
         L ("      elsif Lang = ""lt"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elementai"" else ""elementas"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metrai"" else ""metras"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""kilometrai"" else ""kilometras"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""mylios"" else ""mylia"");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""j"" & U (16#16B#) & ""rmyl""");
         L ("                         & U (16#117#) & ""s""");
         L ("                    else ""j"" & U (16#16B#) & ""rmyl""");
         L ("                         & U (16#117#));");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""astronominiai vienetai""");
         L ("                    else ""astronominis vienetas"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural");
         L ("                    then U (16#161#) & ""viesme"" & U (16#10D#)");
         L ("                         & ""iai""");
         L ("                    else U (16#161#) & ""viesmetis"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return (if Plural then ""parsekai"" else ""parsekas"");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then ""sieksniai"" else ""sieksnis"");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return (if Plural then ""furlongai"" else ""furlongas"");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""pikseliai"" else ""pikselis"");");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""punktai"" else ""punktas"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural");
         L ("                    then ""saul"" & U (16#117#) & ""s spinduliai""");
         L ("                    else ""saul"" & U (16#117#) & ""s spindulys"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centimetrai"" else ""centimetras"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""milimetrai"" else ""milimetras"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""kvadratin"" & U (16#117#) & ""s p""");
         L ("                         & U (16#117#) & ""dos""");
         L ("                    else ""kvadratin"" & U (16#117#) & "" p""");
         L ("                         & U (16#117#) & ""da"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""kvadratin"" & U (16#117#) & ""s mylios""");
         L ("                    else ""kvadratin"" & U (16#117#) & "" mylia"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litrai"" else ""litras"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""mililitrai"" else ""mililitras"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galonai"" else ""galonas"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural");
         L ("                    then ""skys"" & U (16#10D#) & ""io uncijos""");
         L ("                    else ""skys"" & U (16#10D#) & ""io uncija"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""puodeliai"" else ""puodelis"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pintos"" else ""pinta"");");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then ""kvortos"" else ""kvorta"");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""gramai"" else ""gramas"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""kilogramai"" else ""kilogramas"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""miligramai"" else ""miligramas"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""tonos"" else ""tona"");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""svarai"" else ""svaras"");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then ""uncijos"" else ""uncija"");");
         L ("         elsif Base = ""stone"" then");
         L ("            return (if Plural then ""stonai"" else ""stonas"");");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""karatai"" else ""karatas"");");
         L ("         elsif Base = ""second"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""sekund"" & U (16#117#) & ""s""");
         L ("               else ""sekund"" & U (16#117#));");
         L ("         elsif Base = ""minute"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""minut"" & U (16#117#) & ""s""");
         L ("               else ""minut"" & U (16#117#));");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then ""valandos"" else ""valanda"");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""dienos"" else ""diena"");");
         L ("         elsif Base = ""week"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""savait"" & U (16#117#) & ""s""");
         L ("               else ""savait"" & U (16#117#));");
         L ("         elsif Base = ""month"" then");
         L ("            return");
         L ("              (if Plural");
         L ("               then ""m"" & U (16#117#) & ""nesiai""");
         L ("               else ""m"" & U (16#117#) & ""nuo"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""metai"";");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then ""bitai"" else ""bitas"");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return (if Plural then ""megabitai"" else ""megabitas"");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then ""gigabitai"" else ""gigabitas"");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return (if Plural then ""petabaitai"" else ""petabaitas"");");
         L ("         end if;");
         L ("      elsif Lang = ""sl"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elementa"" else ""element"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metra"" else ""meter"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""kilometra"" else ""kilometer"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""milji"" else ""milja"");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""navti"" & U (16#10D#) & ""ne milje""");
         L ("                    else ""navti"" & U (16#10D#) & ""na milja"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""astronomske enote""");
         L ("                    else ""astronomska enota"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""svetlobna leta""");
         L ("                    else ""svetlobno leto"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return (if Plural then ""parseki"" else ""parsek"");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then ""se"" & U (16#17E#) & ""nji""");
         L ("                    else ""se"" & U (16#17E#) & ""enj"");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return (if Plural then ""furlongi"" else ""furlong"");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""slikovne pike""");
         L ("                    else ""slikovna pika"");");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""to"" & U (16#10D#) & ""ke""");
         L ("                    else ""to"" & U (16#10D#) & ""ka"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural");
         L ("                    then ""son"" & U (16#10D#) & ""evi polmeri""");
         L ("                    else ""son"" & U (16#10D#) & ""ev polmer"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centimetra"" else ""centimeter"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""milimetra"" else ""milimeter"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""kvadratni "" & U (16#10D#) & ""evlji""");
         L ("                    else ""kvadratni "" & U (16#10D#) & ""evelj"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""kvadratne milje""");
         L ("                    else ""kvadratna milja"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litra"" else ""liter"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""mililitra"" else ""mililiter"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galoni"" else ""galona"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural");
         L ("                    then ""teko"" & U (16#10D#) & ""inske un""");
         L ("                         & U (16#10D#) & ""e""");
         L ("                    else ""teko"" & U (16#10D#) & ""inska un""");
         L ("                         & U (16#10D#) & ""a"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""skodelici"" else ""skodelica"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pinti"" else ""pinta"");");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then ""kvarti"" else ""kvart"");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""grama"" else ""gram"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""kilograma"" else ""kilogram"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""miligrami"" else ""miligram"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""toni"" else ""tona"");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""funta"" else ""funt"");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then ""unci"" else ""unca"");");
         L ("         elsif Base = ""stone"" then");
         L ("            return (if Plural then ""stoni"" else ""ston"");");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""karati"" else ""karat"");");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then ""sekundi"" else ""sekunda"");");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minuti"" else ""minuta"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then ""ure"" else ""ura"");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""dneva"" else ""dan"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then ""tedna"" else ""teden"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""meseca"" else ""mesec"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""leti"" else ""leto"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then ""biti"" else ""bit"");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return (if Plural then ""megabiti"" else ""megabit"");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then ""gigabiti"" else ""gigabit"");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return (if Plural then ""petabajti"" else ""petabajt"");");
         L ("         end if;");
         L ("      elsif Lang = ""pl"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""elementy"" else ""element"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metry"" else ""metr"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""kilometry"" else ""kilometr"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then ""mile"" else ""mila"");");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then ""mile morskie"" else ""mila morska"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""jednostki astronomiczne""");
         L ("                    else ""jednostka astronomiczna"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural");
         L ("                    then ""lata "" & U (16#15B#) & ""wietlne""");
         L ("                    else ""rok "" & U (16#15B#) & ""wietlny"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return (if Plural then ""parseki"" else ""parsek"");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural");
         L ("                    then ""s"" & U (16#105#) & U (16#17C#) & ""nie""");
         L ("                    else ""s"" & U (16#105#) & U (16#17C#)");
         L ("                         & ""e"" & U (16#144#));");
         L ("         elsif Base = ""furlong"" then");
         L ("            return (if Plural then ""furlongi"" else ""furlong"");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""piksele"" else ""piksel"");");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""punkty"" else ""punkt"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural");
         L ("                    then ""promienie s"" & U (16#142#) & ""oneczne""");
         L ("                    else ""promie"" & U (16#144#) & "" s""");
         L ("                         & U (16#142#) & ""oneczny"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centymetry"" else ""centymetr"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""milimetry"" else ""milimetr"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural");
         L ("                    then ""stopy kwadratowe""");
         L ("                    else ""stopa kwadratowa"");");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural");
         L ("                    then ""mile kwadratowe""");
         L ("                    else ""mila kwadratowa"");");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litry"" else ""litr"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""mililitry"" else ""mililitr"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galony"" else ""galon"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural");
         L ("                    then ""uncje p"" & U (16#142#) & ""ynu""");
         L ("                    else ""uncja p"" & U (16#142#) & ""ynu"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""kubki"" else ""kubek"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pinty"" else ""pinta"");");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then ""kwarty"" else ""kwarta"");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""gramy"" else ""gram"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""kilogramy"" else ""kilogram"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""miligramy"" else ""miligram"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""tony"" else ""tona"");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""funty"" else ""funt"");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then ""uncje"" else ""uncja"");");
         L ("         elsif Base = ""stone"" then");
         L ("            return (if Plural then ""stony"" else ""ston"");");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""karaty"" else ""karat"");");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then ""sekundy"" else ""sekunda"");");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minuty"" else ""minuta"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then ""godziny"" else ""godzina"");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""dni"" else ""dzie"" & U (16#144#));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then ""tygodnie"" else ""tydzie"" & U (16#144#));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""miesi"" & U (16#105#) & ""ce""");
         L ("                    else ""miesi"" & U (16#105#) & ""c"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""lata"" else ""rok"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then ""bity"" else ""bit"");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return (if Plural then ""megabity"" else ""megabit"");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then ""gigabity"" else ""gigabit"");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return (if Plural then ""petabajty"" else ""petabajt"");");
         L ("         end if;");
         L ("      elsif Lang = ""cs"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then ""polo"" & U (16#17E#) & ""ky""");
         L ("                    else ""polo"" & U (16#17E#) & ""ka"");");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then ""metry"" else ""metr"");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return (if Plural then ""kilometry"" else ""kilometr"");");
         L ("         elsif Base = ""mile"" then");
         L ("            return ""m"" & U (16#ED#) & ""le"";");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then ""n"" & U (16#E1#)");
         L ("                    & ""mo"" & U (16#159#) & ""n"" & U (16#ED#)");
         L ("                    & "" m"" & U (16#ED#) & ""le""");
         L ("                    else ""n"" & U (16#E1#) & ""mo""");
         L ("                    & U (16#159#) & ""n"" & U (16#ED#)");
         L ("                    & "" m"" & U (16#ED#) & ""le"");");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural");
         L ("                    then ""astronomick"" & U (16#E9#) & "" jednotky""");
         L ("                    else ""astronomick"" & U (16#E1#) & "" jednotka"");");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then ""sv"" & U (16#11B#)");
         L ("                    & ""teln"" & U (16#E9#) & "" roky""");
         L ("                    else ""sv"" & U (16#11B#) & ""teln""");
         L ("                    & U (16#FD#) & "" rok"");");
         L ("         elsif Base = ""parsec"" then");
         L ("            return (if Plural then ""parseky"" else ""parsek"");");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then ""s"" & U (16#E1#) & ""hy""");
         L ("                    else ""s"" & U (16#E1#) & ""h"");");
         L ("         elsif Base = ""furlong"" then");
         L ("            return (if Plural then ""furlongy"" else ""furlong"");");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then ""pixely"" else ""pixel"");");
         L ("         elsif Base = ""point"" then");
         L ("            return (if Plural then ""body"" else ""bod"");");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural");
         L ("                    then ""slune"" & U (16#10D#) & ""n""");
         L ("                         & U (16#ED#) & "" polom"" & U (16#11B#)");
         L ("                         & ""ry""");
         L ("                    else ""slune"" & U (16#10D#) & ""n""");
         L ("                         & U (16#ED#) & "" polom"" & U (16#11B#)");
         L ("                         & ""r"");");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return (if Plural then ""centimetry"" else ""centimetr"");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return (if Plural then ""milimetry"" else ""milimetr"");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural then ""stopy """);
         L ("                    & U (16#10D#) & ""tvere"" & U (16#10D#)");
         L ("                    & ""n"" & U (16#ED#)");
         L ("                    else ""stopa "" & U (16#10D#) & ""tvere""");
         L ("                    & U (16#10D#) & ""n"" & U (16#ED#));");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then ""m"" & U (16#ED#) & ""le """);
         L ("                    & U (16#10D#) & ""tvere"" & U (16#10D#)");
         L ("                    & ""n"" & U (16#ED#)");
         L ("                    else ""m"" & U (16#ED#) & ""le """);
         L ("                    & U (16#10D#) & ""tvere"" & U (16#10D#)");
         L ("                    & ""n"" & U (16#ED#));");
         L ("         elsif Base = ""liter"" then");
         L ("            return (if Plural then ""litry"" else ""litr"");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return (if Plural then ""mililitry"" else ""mililitr"");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return (if Plural then ""galony"" else ""galon"");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural then ""kapaln"" & U (16#E9#)");
         L ("                    & "" unce""");
         L ("                    else ""kapaln"" & U (16#E1#) & "" unce"");");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then ""hrnky"" else ""hrnek"");");
         L ("         elsif Base = ""pint"" then");
         L ("            return (if Plural then ""pinty"" else ""pinta"");");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then ""kvarty"" else ""kvart"");");
         L ("         elsif Base = ""gram"" then");
         L ("            return (if Plural then ""gramy"" else ""gram"");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return (if Plural then ""kilogramy"" else ""kilogram"");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return (if Plural then ""miligramy"" else ""miligram"");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then ""tuny"" else ""tuna"");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then ""libry"" else ""libra"");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return ""unce"";");
         L ("         elsif Base = ""stone"" then");
         L ("            return (if Plural then ""stony"" else ""ston"");");
         L ("         elsif Base = ""carat"" then");
         L ("            return (if Plural then ""kar"" & U (16#E1#) & ""ty""");
         L ("                    else ""kar"" & U (16#E1#) & ""t"");");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then ""sekundy"" else ""sekunda"");");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then ""minuty"" else ""minuta"");");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then ""hodiny"" else ""hodina"");");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then ""dny"" else ""den"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then ""t"" & U (16#FD#) & ""dny""");
         L ("                    else ""t"" & U (16#FD#) & ""den"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then ""m"" & U (16#11B#) & ""s""");
         L ("                    & U (16#ED#) & ""ce"" else ""m"" & U (16#11B#)");
         L ("                    & ""s"" & U (16#ED#) & ""c"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then ""roky"" else ""rok"");");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then ""bity"" else ""bit"");");
         L ("         elsif Base = ""megabit"" then");
         L ("            return (if Plural then ""megabity"" else ""megabit"");");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then ""gigabity"" else ""gigabit"");");
         L ("         elsif Base = ""petabyte"" then");
         L ("            return (if Plural then ""petabajty"" else ""petabajt"");");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then UTF8 ([16#44D#, 16#43B#, 16#435#,");
         L ("                    16#43C#, 16#435#, 16#43D#, 16#442#, 16#44B#])");
         L ("                    else UTF8 ([16#44D#, 16#43B#, 16#435#, 16#43C#,");
         L ("                    16#435#, 16#43D#, 16#442#]));");
         L ("         elsif Base = ""meter"" then");
         L ("            return UTF8 ([16#43C#, 16#435#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return UTF8 ([16#43A#, 16#438#, 16#43B#, 16#43E#,");
         L ("                    16#43C#, 16#435#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then UTF8 ([16#43C#, 16#438#, 16#43B#,");
         L ("                    16#438#]) else UTF8 ([16#43C#, 16#438#, 16#43B#,");
         L ("                    16#44F#]));");
         L ("         elsif Base = ""nautical-mile"" then");
         L ("            return (if Plural then UTF8 ([16#43C#, 16#43E#, 16#440#,");
         L ("                    16#441#, 16#43A#, 16#438#, 16#435#, 16#20#,");
         L ("                    16#43C#, 16#438#, 16#43B#, 16#438#])");
         L ("                    else UTF8 ([16#43C#, 16#43E#, 16#440#, 16#441#,");
         L ("                    16#43A#, 16#430#, 16#44F#, 16#20#, 16#43C#,");
         L ("                    16#438#, 16#43B#, 16#44F#]));");
         L ("         elsif Base = ""astronomical-unit"" then");
         L ("            return (if Plural then UTF8 ([16#430#, 16#441#, 16#442#,");
         L ("                    16#440#, 16#43E#, 16#43D#, 16#43E#, 16#43C#,");
         L ("                    16#438#, 16#447#, 16#435#, 16#441#, 16#43A#,");
         L ("                    16#438#, 16#435#, 16#20#, 16#435#, 16#434#,");
         L ("                    16#438#, 16#43D#, 16#438#, 16#446#, 16#44B#])");
         L ("                    else UTF8 ([16#430#, 16#441#, 16#442#, 16#440#,");
         L ("                    16#43E#, 16#43D#, 16#43E#, 16#43C#, 16#438#,");
         L ("                    16#447#, 16#435#, 16#441#, 16#43A#, 16#430#,");
         L ("                    16#44F#, 16#20#, 16#435#, 16#434#, 16#438#,");
         L ("                    16#43D#, 16#438#, 16#446#, 16#430#]));");
         L ("         elsif Base = ""light-year"" then");
         L ("            return (if Plural then UTF8 ([16#441#, 16#432#, 16#435#,");
         L ("                    16#442#, 16#43E#, 16#432#, 16#44B#, 16#435#,");
         L ("                    16#20#, 16#433#, 16#43E#, 16#434#, 16#44B#])");
         L ("                    else UTF8 ([16#441#, 16#432#, 16#435#, 16#442#,");
         L ("                    16#43E#, 16#432#, 16#43E#, 16#439#, 16#20#,");
         L ("                    16#433#, 16#43E#, 16#434#]));");
         L ("         elsif Base = ""parsec"" then");
         L ("            return (if Plural then UTF8 ([16#43F#, 16#430#, 16#440#,");
         L ("                    16#441#, 16#435#, 16#43A#, 16#438#])");
         L ("                    else UTF8 ([16#43F#, 16#430#, 16#440#, 16#441#,");
         L ("                    16#435#, 16#43A#]));");
         L ("         elsif Base = ""fathom"" then");
         L ("            return (if Plural then UTF8 ([16#441#, 16#430#, 16#436#,");
         L ("                    16#435#, 16#43D#, 16#438#])");
         L ("                    else UTF8 ([16#441#, 16#430#, 16#436#, 16#435#,");
         L ("                    16#43D#, 16#44C#]));");
         L ("         elsif Base = ""furlong"" then");
         L ("            return (if Plural then UTF8 ([16#444#, 16#443#, 16#440#,");
         L ("                    16#43B#, 16#43E#, 16#43D#, 16#433#, 16#438#])");
         L ("                    else UTF8 ([16#444#, 16#443#, 16#440#, 16#43B#,");
         L ("                    16#43E#, 16#43D#, 16#433#]));");
         L ("         elsif Base = ""pixel"" then");
         L ("            return (if Plural then UTF8 ([16#43F#, 16#438#, 16#43A#,");
         L ("                    16#441#, 16#435#, 16#43B#, 16#438#])");
         L ("                    else UTF8 ([16#43F#, 16#438#, 16#43A#, 16#441#,");
         L ("                    16#435#, 16#43B#, 16#44C#]));");
         L ("         elsif Base = ""solar-radius"" then");
         L ("            return (if Plural then UTF8 ([16#441#, 16#43E#, 16#43B#,");
         L ("                    16#43D#, 16#435#, 16#447#, 16#43D#, 16#44B#,");
         L ("                    16#435#, 16#20#, 16#440#, 16#430#, 16#434#,");
         L ("                    16#438#, 16#443#, 16#441#, 16#44B#])");
         L ("                    else UTF8 ([16#441#, 16#43E#, 16#43B#, 16#43D#,");
         L ("                    16#435#, 16#447#, 16#43D#, 16#44B#, 16#439#,");
         L ("                    16#20#, 16#440#, 16#430#, 16#434#, 16#438#,");
         L ("                    16#443#, 16#441#]));");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return UTF8 ([16#441#, 16#430#, 16#43D#, 16#442#, 16#438#,");
         L ("                    16#43C#, 16#435#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#,");
         L ("                    16#43C#, 16#435#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""square-foot"" then");
         L ("            return (if Plural then UTF8 ([16#43A#, 16#432#, 16#430#,");
         L ("                    16#434#, 16#440#, 16#430#, 16#442#, 16#43D#,");
         L ("                    16#44B#, 16#435#, 16#20#, 16#444#, 16#443#,");
         L ("                    16#442#, 16#44B#])");
         L ("                    else UTF8 ([16#43A#, 16#432#, 16#430#, 16#434#,");
         L ("                    16#440#, 16#430#, 16#442#, 16#43D#, 16#44B#,");
         L ("                    16#439#, 16#20#, 16#444#, 16#443#, 16#442#]));");
         L ("         elsif Base = ""square-mile"" then");
         L ("            return (if Plural then UTF8 ([16#43A#, 16#432#, 16#430#,");
         L ("                    16#434#, 16#440#, 16#430#, 16#442#, 16#43D#,");
         L ("                    16#44B#, 16#435#, 16#20#, 16#43C#, 16#438#,");
         L ("                    16#43B#, 16#438#])");
         L ("                    else UTF8 ([16#43A#, 16#432#, 16#430#, 16#434#,");
         L ("                    16#440#, 16#430#, 16#442#, 16#43D#, 16#430#,");
         L ("                    16#44F#, 16#20#, 16#43C#, 16#438#, 16#43B#,");
         L ("                    16#44F#]));");
         L ("         elsif Base = ""liter"" then");
         L ("            return UTF8 ([16#43B#, 16#438#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#,");
         L ("                    16#43B#, 16#438#, 16#442#, 16#440#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return UTF8 ([16#433#, 16#430#, 16#43B#, 16#43B#, 16#43E#,");
         L ("                    16#43D#]) & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""fluid-ounce"" then");
         L ("            return (if Plural then UTF8 ([16#436#, 16#438#, 16#434#,");
         L ("                    16#43A#, 16#438#, 16#435#, 16#20#, 16#443#,");
         L ("                    16#43D#, 16#446#, 16#438#, 16#438#])");
         L ("                    else UTF8 ([16#436#, 16#438#, 16#434#, 16#43A#,");
         L ("                    16#430#, 16#44F#, 16#20#, 16#443#, 16#43D#,");
         L ("                    16#446#, 16#438#, 16#44F#]));");
         L ("         elsif Base = ""cup"" then");
         L ("            return (if Plural then UTF8 ([16#447#, 16#430#, 16#448#,");
         L ("                    16#43A#, 16#438#]) else UTF8 ([16#447#, 16#430#,");
         L ("                    16#448#, 16#43A#, 16#430#]));");
         L ("         elsif Base = ""quart"" then");
         L ("            return (if Plural then UTF8 ([16#43A#, 16#432#, 16#430#,");
         L ("                    16#440#, 16#442#, 16#44B#]) else UTF8 ([16#43A#,");
         L ("                    16#432#, 16#430#, 16#440#, 16#442#, 16#430#]));");
         L ("         elsif Base = ""gram"" then");
         L ("            return UTF8 ([16#433#, 16#440#, 16#430#, 16#43C#, 16#43C#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return UTF8 ([16#43A#, 16#438#, 16#43B#, 16#43E#, 16#433#,");
         L ("                    16#440#, 16#430#, 16#43C#, 16#43C#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""milligram"" then");
         L ("            return UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#,");
         L ("                    16#438#, 16#433#, 16#440#, 16#430#, 16#43C#,");
         L ("                    16#43C#]) & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""tonne"" then");
         L ("            return (if Plural then UTF8 ([16#442#, 16#43E#, 16#43D#,");
         L ("                    16#43D#, 16#44B#]) else UTF8 ([16#442#, 16#43E#,");
         L ("                    16#43D#, 16#43D#, 16#430#]));");
         L ("         elsif Base = ""pound"" then");
         L ("            return UTF8 ([16#444#, 16#443#, 16#43D#, 16#442#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then UTF8 ([16#443#, 16#43D#, 16#446#,");
         L ("                    16#438#, 16#438#]) else UTF8 ([16#443#, 16#43D#,");
         L ("                    16#446#, 16#438#, 16#44F#]));");
         L ("         elsif Base = ""stone"" then");
         L ("            return (if Plural then UTF8 ([16#441#, 16#442#, 16#43E#,");
         L ("                    16#443#, 16#43D#, 16#44B#]) else UTF8 ([16#441#,");
         L ("                    16#442#, 16#43E#, 16#443#, 16#43D#]));");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then UTF8 ([16#441#, 16#435#, 16#43A#,");
         L ("                    16#443#, 16#43D#, 16#434#, 16#44B#])");
         L ("                    else UTF8 ([16#441#, 16#435#, 16#43A#, 16#443#,");
         L ("                    16#43D#, 16#434#, 16#430#]));");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then UTF8 ([16#43C#, 16#438#, 16#43D#,");
         L ("                    16#443#, 16#442#, 16#44B#]) else UTF8 ([16#43C#,");
         L ("                    16#438#, 16#43D#, 16#443#, 16#442#, 16#430#]));");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then UTF8 ([16#447#, 16#430#, 16#441#,");
         L ("                    16#44B#]) else UTF8 ([16#447#, 16#430#, 16#441#]));");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then UTF8 ([16#434#, 16#43D#, 16#438#])");
         L ("                    else UTF8 ([16#434#, 16#435#, 16#43D#, 16#44C#]));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then UTF8 ([16#43D#, 16#435#, 16#434#,");
         L ("                    16#435#, 16#43B#, 16#438#]) else UTF8 ([16#43D#,");
         L ("                    16#435#, 16#434#, 16#435#, 16#43B#, 16#44F#]));");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#43C#, 16#435#, 16#441#, 16#44F#, 16#446#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#433#, 16#43E#, 16#434#])");
         L ("              & (if Plural then U (16#44B#) else """");");
         L ("         elsif Base = ""bit"" then");
         L ("            return (if Plural then UTF8 ([16#431#, 16#438#, 16#442#,");
         L ("                    16#44B#]) else UTF8 ([16#431#, 16#438#, 16#442#]));");
         L ("         elsif Base = ""gigabit"" then");
         L ("            return (if Plural then UTF8 ([16#433#, 16#438#, 16#433#,");
         L ("                    16#430#, 16#431#, 16#438#, 16#442#, 16#44B#])");
         L ("                    else UTF8 ([16#433#, 16#438#, 16#433#, 16#430#,");
         L ("                    16#431#, 16#438#, 16#442#]));");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Base = ""item"" then");
         L ("            return (if Plural then UTF8 ([16#639#, 16#646#, 16#627#,");
         L ("                    16#635#, 16#631#]) else UTF8 ([16#639#, 16#646#,");
         L ("                    16#635#, 16#631#]));");
         L ("         elsif Base = ""meter"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#645#, 16#62A#,");
         L ("                    16#627#, 16#631#]) else UTF8 ([16#645#, 16#62A#,");
         L ("                    16#631#]));");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#,");
         L ("                    16#645#, 16#62A#, 16#631#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""mile"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#645#, 16#64A#,");
         L ("                    16#627#, 16#644#]) else UTF8 ([16#645#, 16#64A#,");
         L ("                    16#644#]));");
         L ("         elsif Base = ""centimeter"" then");
         L ("            return UTF8 ([16#633#, 16#646#, 16#62A#, 16#64A#,");
         L ("                    16#645#, 16#62A#, 16#631#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""millimeter"" then");
         L ("            return UTF8 ([16#645#, 16#644#, 16#64A#, 16#645#,");
         L ("                    16#62A#, 16#631#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""liter"" then");
         L ("            return UTF8 ([16#644#, 16#62A#, 16#631#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""milliliter"" then");
         L ("            return UTF8 ([16#645#, 16#644#, 16#64A#, 16#644#,");
         L ("                    16#62A#, 16#631#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""gallon"" then");
         L ("            return UTF8 ([16#63A#, 16#627#, 16#644#, 16#648#, 16#646#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""gram"" then");
         L ("            return UTF8 ([16#63A#, 16#631#, 16#627#, 16#645#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""kilogram"" then");
         L ("            return UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#, 16#63A#,");
         L ("                    16#631#, 16#627#, 16#645#])");
         L ("              & (if Plural then UTF8 ([16#627#, 16#62A#]) else """");");
         L ("         elsif Base = ""pound"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#631#, 16#637#,");
         L ("                    16#627#, 16#644#]) else UTF8 ([16#631#, 16#637#,");
         L ("                    16#644#]));");
         L ("         elsif Base = ""ounce"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#648#, 16#646#,");
         L ("                    16#635#, 16#627#, 16#62A#]) else UTF8 ([16#623#,");
         L ("                    16#648#, 16#646#, 16#635#, 16#629#]));");
         L ("         elsif Base = ""second"" then");
         L ("            return (if Plural then UTF8 ([16#62B#, 16#648#, 16#627#,");
         L ("                    16#646#]) else UTF8 ([16#62B#, 16#627#, 16#646#,");
         L ("                    16#64A#, 16#629#]));");
         L ("         elsif Base = ""minute"" then");
         L ("            return (if Plural then UTF8 ([16#62F#, 16#642#, 16#627#,");
         L ("                    16#626#, 16#642#]) else UTF8 ([16#62F#, 16#642#,");
         L ("                    16#64A#, 16#642#, 16#629#]));");
         L ("         elsif Base = ""hour"" then");
         L ("            return (if Plural then UTF8 ([16#633#, 16#627#, 16#639#,");
         L ("                    16#627#, 16#62A#]) else UTF8 ([16#633#, 16#627#,");
         L ("                    16#639#, 16#629#]));");
         L ("         elsif Base = ""day"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#64A#, 16#627#,");
         L ("                    16#645#]) else UTF8 ([16#64A#, 16#648#, 16#645#]));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#633#, 16#627#,");
         L ("                    16#628#, 16#64A#, 16#639#]) else UTF8 ([16#623#,");
         L ("                    16#633#, 16#628#, 16#648#, 16#639#]));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Plural then UTF8 ([16#623#, 16#634#, 16#647#,");
         L ("                    16#631#]) else UTF8 ([16#634#, 16#647#, 16#631#]));");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Plural then UTF8 ([16#633#, 16#646#, 16#648#,");
         L ("                    16#627#, 16#62A#]) else UTF8 ([16#633#, 16#646#,");
         L ("                    16#629#]));");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Base = ""item"" then");
         L ("            return U (16#9805#) & U (16#76EE#);");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return U (16#30AD#) & U (16#30ED#) & U (16#30E1#)");
         L ("                   & U (16#30FC#) & U (16#30C8#) & U (16#30EB#);");
         L ("         elsif Base = ""hour"" then");
         L ("            return U (16#6642#) & U (16#9593#);");
         L ("         elsif Base = ""day"" then");
         L ("            return U (16#65E5#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#9031#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#30F6#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#5E74#);");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Base = ""item"" then");
         L ("            return U (16#9879#);");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return U (16#516C#) & U (16#91CC#);");
         L ("         elsif Base = ""hour"" then");
         L ("            return U (16#5C0F#) & U (16#65F6#);");
         L ("         elsif Base = ""day"" then");
         L ("            return U (16#5929#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#5468#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#4E2A#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#5E74#);");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Base = ""item"" then");
         L ("            return U (16#D56D#) & U (16#BAA9#);");
         L ("         elsif Base = ""kilometer"" then");
         L ("            return U (16#D0AC#) & U (16#B85C#) & U (16#BBF8#) & U (16#D130#);");
         L ("         elsif Base = ""hour"" then");
         L ("            return U (16#C2DC#) & U (16#AC04#);");
         L ("         elsif Base = ""day"" then");
         L ("            return U (16#C77C#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#C8FC#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#AC1C#) & U (16#C6D4#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#B144#);");
         L ("         end if;");
         L ("      elsif Lang = ""tr"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#67#, 16#FC#, 16#6E#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return ""hafta"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""ay"";");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#79#, 16#131#, 16#6C#]);");
         L ("         end if;");
         L ("      elsif Lang = ""sv"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dagar"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""vecka"" else ""veckor"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then");
         L ("               UTF8 ([16#6D#, 16#E5#, 16#6E#, 16#61#, 16#64#])");
         L ("            else UTF8 ([16#6D#, 16#E5#, 16#6E#, 16#61#,");
         L ("                        16#64#, 16#65#, 16#72#]));");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#E5#, 16#72#]);");
         L ("         end if;");
         L ("      elsif Lang = ""da"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dage"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""uge"" else ""uger"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then");
         L ("               UTF8 ([16#6D#, 16#E5#, 16#6E#, 16#65#, 16#64#])");
         L ("            else UTF8 ([16#6D#, 16#E5#, 16#6E#, 16#65#,");
         L ("                        16#64#, 16#65#, 16#72#]));");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#E5#, 16#72#]);");
         L ("         end if;");
         L ("      elsif Lang = ""eo"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""tago"" else ""tagoj"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""semajno"" else ""semajnoj"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""monato"" else ""monatoj"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""jaro"" else ""jaroj"");");
         L ("         end if;");
         L ("      elsif Lang = ""vi"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#6E#, 16#67#, 16#E0#, 16#79#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#74#, 16#75#, 16#1EA7#, 16#6E#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#74#, 16#68#, 16#E1#, 16#6E#, 16#67#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#6E#, 16#103#, 16#6D#]);");
         L ("         end if;");
         L ("      elsif Lang = ""hu"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""nap"";");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#68#, 16#E9#, 16#74#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#68#, 16#F3#, 16#6E#, 16#61#, 16#70#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#E9#, 16#76#]);");
         L ("         end if;");
         L ("      elsif Lang = ""sk"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then");
         L ("               UTF8 ([16#64#, 16#65#, 16#148#]) else ""dni"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then");
         L ("               UTF8 ([16#74#, 16#FD#, 16#17E#, 16#64#,");
         L ("                      16#65#, 16#148#])");
         L ("            else UTF8 ([16#74#, 16#FD#, 16#17E#, 16#64#,");
         L ("                        16#6E#, 16#65#]));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""mesiac"" else ""mesiace"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""rok"" else ""roky"");");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      if Base = """" or else Base = ""item"" then");
         L ("         return (if Plural then ""items"" else ""item"");");
         L ("      elsif Base = ""meter"" then");
         L ("         return (if Plural then ""meters"" else ""meter"");");
         L ("      elsif Base = ""kilometer"" then");
         L ("         return (if Plural then ""kilometers"" else ""kilometer"");");
         L ("      elsif Base = ""mile"" then");
         L ("         return (if Plural then ""miles"" else ""mile"");");
         L ("      elsif Base = ""yard"" then");
         L ("         return (if Plural then ""yards"" else ""yard"");");
         L ("      elsif Base = ""foot"" then");
         L ("         return (if Plural then ""feet"" else ""foot"");");
         L ("      elsif Base = ""inch"" then");
         L ("         return (if Plural then ""inches"" else ""inch"");");
         L ("      elsif Base = ""centimeter"" then");
         L ("         return (if Plural then ""centimeters"" else ""centimeter"");");
         L ("      elsif Base = ""millimeter"" then");
         L ("         return (if Plural then ""millimeters"" else ""millimeter"");");
         L ("      elsif Base = ""nautical-mile"" then");
         L ("         return (if Plural then ""nautical miles"" else ""nautical mile"");");
         L ("      elsif Base = ""astronomical-unit"" then");
         L ("         return (if Plural then ""astronomical units"" else ""astronomical unit"");");
         L ("      elsif Base = ""light-year"" then");
         L ("         return (if Plural then ""light years"" else ""light year"");");
         L ("      elsif Base = ""parsec"" then");
         L ("         return (if Plural then ""parsecs"" else ""parsec"");");
         L ("      elsif Base = ""fathom"" then");
         L ("         return (if Plural then ""fathoms"" else ""fathom"");");
         L ("      elsif Base = ""furlong"" then");
         L ("         return (if Plural then ""furlongs"" else ""furlong"");");
         L ("      elsif Base = ""pixel"" then");
         L ("         return (if Plural then ""pixels"" else ""pixel"");");
         L ("      elsif Base = ""point"" then");
         L ("         return (if Plural then ""points"" else ""point"");");
         L ("      elsif Base = ""solar-radius"" then");
         L ("         return (if Plural then ""solar radii"" else ""solar radius"");");
         L ("      elsif Base = ""liter"" then");
         L ("         return (if Plural then ""liters"" else ""liter"");");
         L ("      elsif Base = ""milliliter"" then");
         L ("         return (if Plural then ""milliliters"" else ""milliliter"");");
         L ("      elsif Base = ""gallon"" then");
         L ("         return (if Plural then ""gallons"" else ""gallon"");");
         L ("      elsif Base = ""fluid-ounce"" then");
         L ("         return (if Plural then ""fluid ounces"" else ""fluid ounce"");");
         L ("      elsif Base = ""cup"" then");
         L ("         return (if Plural then ""cups"" else ""cup"");");
         L ("      elsif Base = ""pint"" then");
         L ("         return (if Plural then ""pints"" else ""pint"");");
         L ("      elsif Base = ""quart"" then");
         L ("         return (if Plural then ""quarts"" else ""quart"");");
         L ("      elsif Base = ""gram"" then");
         L ("         return (if Plural then ""grams"" else ""gram"");");
         L ("      elsif Base = ""kilogram"" then");
         L ("         return (if Plural then ""kilograms"" else ""kilogram"");");
         L ("      elsif Base = ""milligram"" then");
         L ("         return (if Plural then ""milligrams"" else ""milligram"");");
         L ("      elsif Base = ""tonne"" then");
         L ("         return (if Plural then ""tonnes"" else ""tonne"");");
         L ("      elsif Base = ""pound"" then");
         L ("         return (if Plural then ""pounds"" else ""pound"");");
         L ("      elsif Base = ""ounce"" then");
         L ("         return (if Plural then ""ounces"" else ""ounce"");");
         L ("      elsif Base = ""stone"" then");
         L ("         return (if Plural then ""stones"" else ""stone"");");
         L ("      elsif Base = ""carat"" then");
         L ("         return (if Plural then ""carats"" else ""carat"");");
         L ("      elsif Base = ""nanosecond"" then");
         L ("         return (if Plural then ""nanoseconds"" else ""nanosecond"");");
         L ("      elsif Base = ""microsecond"" then");
         L ("         return (if Plural then ""microseconds"" else ""microsecond"");");
         L ("      elsif Base = ""millisecond"" then");
         L ("         return (if Plural then ""milliseconds"" else ""millisecond"");");
         L ("      elsif Base = ""second"" then");
         L ("         return (if Plural then ""seconds"" else ""second"");");
         L ("      elsif Base = ""minute"" then");
         L ("         return (if Plural then ""minutes"" else ""minute"");");
         L ("      elsif Base = ""hour"" then");
         L ("         return (if Plural then ""hours"" else ""hour"");");
         L ("      elsif Base = ""day"" then");
         L ("         return (if Plural then ""days"" else ""day"");");
         L ("      elsif Base = ""week"" then");
         L ("         return (if Plural then ""weeks"" else ""week"");");
         L ("      elsif Base = ""month"" then");
         L ("         return (if Plural then ""months"" else ""month"");");
         L ("      elsif Base = ""year"" then");
         L ("         return (if Plural then ""years"" else ""year"");");
         L ("      elsif Base = ""square-meter"" then");
         L ("         return (if Plural then ""square meters"" else ""square meter"");");
         L ("      elsif Base = ""square-kilometer"" then");
         L ("         return (if Plural then ""square kilometers"" else ""square kilometer"");");
         L ("      elsif Base = ""acre"" then");
         L ("         return (if Plural then ""acres"" else ""acre"");");
         L ("      elsif Base = ""hectare"" then");
         L ("         return (if Plural then ""hectares"" else ""hectare"");");
         L ("      elsif Base = ""square-foot"" then");
         L ("         return (if Plural then ""square feet"" else ""square foot"");");
         L ("      elsif Base = ""square-mile"" then");
         L ("         return (if Plural then ""square miles"" else ""square mile"");");
         L ("      elsif Base = ""celsius"" then");
         L ("         return ""degree"" & (if Plural then ""s"" else """") & "" Celsius"";");
         L ("      elsif Base = ""fahrenheit"" then");
         L ("         return ""degree"" & (if Plural then ""s"" else """") & "" Fahrenheit"";");
         L ("      elsif Base = ""degree"" then");
         L ("         return (if Plural then ""degrees"" else ""degree"");");
         L ("      elsif Base = ""byte"" then");
         L ("         return (if Plural then ""bytes"" else ""byte"");");
         L ("      elsif Base = ""bit"" then");
         L ("         return (if Plural then ""bits"" else ""bit"");");
         L ("      elsif Base = ""kilobyte"" then");
         L ("         return (if Plural then ""kilobytes"" else ""kilobyte"");");
         L ("      elsif Base = ""megabyte"" then");
         L ("         return (if Plural then ""megabytes"" else ""megabyte"");");
         L ("      elsif Base = ""gigabyte"" then");
         L ("         return (if Plural then ""gigabytes"" else ""gigabyte"");");
         L ("      elsif Base = ""terabyte"" then");
         L ("         return (if Plural then ""terabytes"" else ""terabyte"");");
         L ("      elsif Base = ""megabit"" then");
         L ("         return (if Plural then ""megabits"" else ""megabit"");");
         L ("      elsif Base = ""gigabit"" then");
         L ("         return (if Plural then ""gigabits"" else ""gigabit"");");
         L ("      elsif Base = ""petabyte"" then");
         L ("         return (if Plural then ""petabytes"" else ""petabyte"");");
         L ("      elsif Base = ""kilometer-per-hour"" then");
         L ("         return (if Plural then ""kilometers per hour"" else ""kilometer per hour"");");
         L ("      elsif Base = ""mile-per-hour"" then");
         L ("         return (if Plural then ""miles per hour"" else ""mile per hour"");");
         L ("      elsif Base = ""meter-per-second"" then");
         L ("         return (if Plural then ""meters per second"" else ""meter per second"");");
         L ("      elsif Base = ""joule"" then");
         L ("         return (if Plural then ""joules"" else ""joule"");");
         L ("      elsif Base = ""kilojoule"" then");
         L ("         return (if Plural then ""kilojoules"" else ""kilojoule"");");
         L ("      elsif Base = ""calorie"" then");
         L ("         return (if Plural then ""calories"" else ""calorie"");");
         L ("      elsif Base = ""kilocalorie"" then");
         L ("         return (if Plural then ""kilocalories"" else ""kilocalorie"");");
         L ("      elsif Base = ""kilowatt-hour"" then");
         L ("         return (if Plural then ""kilowatt-hours"" else ""kilowatt-hour"");");
         L ("      elsif Base = ""watt"" then");
         L ("         return (if Plural then ""watts"" else ""watt"");");
         L ("      elsif Base = ""kilowatt"" then");
         L ("         return (if Plural then ""kilowatts"" else ""kilowatt"");");
         L ("      elsif Base = ""hertz"" then");
         L ("         return ""hertz"";");
         L ("      elsif Base = ""kilohertz"" then");
         L ("         return ""kilohertz"";");
         L ("      elsif Base = ""megahertz"" then");
         L ("         return ""megahertz"";");
         L ("      elsif Base = ""hectopascal"" then");
         L ("         return (if Plural then ""hectopascals"" else ""hectopascal"");");
         L ("      elsif Base = ""pascal"" then");
         L ("         return (if Plural then ""pascals"" else ""pascal"");");
         L ("      elsif Base = ""kilopascal"" then");
         L ("         return (if Plural then ""kilopascals"" else ""kilopascal"");");
         L ("      elsif Base = ""millibar"" then");
         L ("         return (if Plural then ""millibars"" else ""millibar"");");
         L ("      elsif Base = ""bar"" then");
         L ("         return (if Plural then ""bars"" else ""bar"");");
         L ("      elsif Base = ""atmosphere"" then");
         L ("         return (if Plural then ""atmospheres"" else ""atmosphere"");");
         L ("      elsif Base = ""inch-ofhg"" then");
         L ("         return (if Plural then ""inches of mercury"" else ""inch of mercury"");");
         L ("      elsif Base = ""millimeter-ofhg"" then");
         L ("         return (if Plural then ""millimeters of mercury"" else ""millimeter of mercury"");");
         L ("      elsif Base = ""ampere"" then");
         L ("         return (if Plural then ""amperes"" else ""ampere"");");
         L ("      elsif Base = ""volt"" then");
         L ("         return (if Plural then ""volts"" else ""volt"");");
         L ("      elsif Base = ""ohm"" then");
         L ("         return (if Plural then ""ohms"" else ""ohm"");");
         L ("      elsif Base = ""lumen"" then");
         L ("         return (if Plural then ""lumens"" else ""lumen"");");
         L ("      elsif Base = ""lux"" then");
         L ("         return ""lux"";");
         L ("      elsif Base = ""percent"" then");
         L ("         return ""percent"";");
         L ("      end if;");
         L;
         L ("      return """";");
         L ("   end Unit_Display_Name;");
      end Emit_Unit_Display_Name;

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
      procedure Emit_Relative_Current_Name is
         Current_Base : Label_Array;
         Current_Base_Count : Natural;
         Current_Width : Label_Array;
         Current_Width_Count : Natural;
      begin
         Collect_Labels ("relative_current", 2,
                         Current_Base, Current_Base_Count);
         Collect_Labels ("relative_current", 3,
                         Current_Width, Current_Width_Count);
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  The rows arrive grouped by locale, so a change of locale ends
            --  the segment. Scanning back for a locale already seen would be
            --  quadratic, and this kind has tens of thousands of rows.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "relative_current") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Current_Base, Current_Base_Count,
                                 S (Rules (Index).B), 1)
                     & Label_Code (Current_Width, Current_Width_Count,
                                   S (Rules (Index).C), 1)
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).D))
                     & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Relative_Current_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   function Relative_Current_Name");
         L ("     (Locale : String;");
         L ("      Base   : String;");
         L ("      Width  : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L;
         Emit_Label_Chain ("Base_Code", "Base",
                           Current_Base, Current_Base_Count, 1);
         L;
         L ("      function Width_Code (Want : String) return String is");
         for Position in 1 .. Current_Width_Count loop
            L ("        " & (if Position = 1 then "(if" else " elsif")
               & " Want = """ & S (Current_Width (Position)) & """ then """
               & Label_Code (Current_Width, Current_Width_Count,
                             S (Current_Width (Position)), 1) & """");
         end loop;
         L ("         else "" "");");
         L;
         L ("      function Search (Rows : String; Wanted : String) return String is");
         L ("         Start : Positive := Rows'First;");
         L ("         Key : constant String := Base_Code & Width_Code (Wanted);");
         L ("      begin");
         L ("         if Key (Key'First) = ' ' or else Key (Key'Last) = ' ' then");
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
         L ("               if Stop > Start + 2");
         L ("                 and then Rows (Start .. Start + 1) = Key");
         L ("               then");
         L ("                  return VB (Rows (Start + 2 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      --  Each parent in turn, longest first.");
         L ("      function Walk (Wanted : String) return String is");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Rows : constant String :=");
         L ("                    Relative_Current_Row (Canon (Canon'First .. Cut - 1));");
         L ("                  Hit : constant String := Search (Rows, Wanted);");
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
         L ("      end Walk;");
         L;
         L ("      Rows : constant String := Relative_Current_Row (Locale);");
         L ("      Exact : constant String := Search (Rows, Width);");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      --  The wanted width over the locale, then the full name,");
         L ("      --  and only then the same two over its parents.");
         L ("      if Width /= ""unit-width-full-name"" then");
         L ("         declare");
         L ("            Full_Exact : constant String :=");
         L ("              Search (Rows, ""unit-width-full-name"");");
         L ("         begin");
         L ("            if Full_Exact /= """" then");
         L ("               return Full_Exact;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L;
         L ("      declare");
         L ("         Fallback_Result : constant String := Walk (Width);");
         L ("      begin");
         L ("         if Fallback_Result /= """" then");
         L ("            return Fallback_Result;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      if Width /= ""unit-width-full-name"" then");
         L ("         declare");
         L ("            Full_Fallback : constant String :=");
         L ("              Walk (""unit-width-full-name"");");
         L ("         begin");
         L ("            if Full_Fallback /= """" then");
         L ("               return Full_Fallback;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L;
         L ("      if Lang = ""de"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""heute"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""diese Woche"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""diesen Monat"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""dieses Jahr"";");
         L ("         else");
         L ("            return ""jetzt"";");
         L ("         end if;");
         L ("      elsif Lang = ""fr"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""aujourd'hui"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""cette semaine"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""ce mois"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""cette ann"" & U (16#E9#) & ""e"";");
         L ("         else");
         L ("            return ""maintenant"";");
         L ("         end if;");
         L ("      elsif Lang = ""es"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""hoy"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""esta semana"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""este mes"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""este a"" & U (16#F1#) & ""o"";");
         L ("         else");
         L ("            return ""ahora"";");
         L ("         end if;");
         L ("      elsif Lang = ""it"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""oggi"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""questa settimana"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""questo mese"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""quest'anno"";");
         L ("         else");
         L ("            return ""ora"";");
         L ("         end if;");
         L ("      elsif Lang = ""pt"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""hoje"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""esta semana"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""este m"" & U (16#EA#) & ""s"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""este ano"";");
         L ("         else");
         L ("            return ""agora"";");
         L ("         end if;");
         L ("      elsif Lang = ""nl"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""vandaag"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""deze week"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""deze maand"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""dit jaar"";");
         L ("         else");
         L ("            return ""nu"";");
         L ("         end if;");
         L ("      elsif Lang = ""ro"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""azi"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""s"" & U (16#103#) & ""pt""");
         L ("              & U (16#103#) & ""m"" & U (16#E2#)");
         L ("              & ""na aceasta"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""luna aceasta"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""anul acesta"";");
         L ("         else");
         L ("            return ""acum"";");
         L ("         end if;");
         L ("      elsif Lang = ""lt"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#161#) & ""iandien"";");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#161#) & ""i"" & U (16#105#) & "" savait"" & U (16#119#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#161#) & ""is m"" & U (16#117#) & ""nuo"";");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#161#) & ""ie metai"";");
         L ("         else");
         L ("            return ""dabar"";");
         L ("         end if;");
         L ("      elsif Lang = ""sl"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""danes"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""ta teden"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""ta mesec"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""letos"";");
         L ("         else");
         L ("            return ""zdaj"";");
         L ("         end if;");
         L ("      elsif Lang = ""pl"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""dzisiaj"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""w tym tygodniu"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""w tym miesi"" & U (16#105#) & ""cu"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""w tym roku"";");
         L ("         else");
         L ("            return ""teraz"";");
         L ("         end if;");
         L ("      elsif Lang = ""cs"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""dnes"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""tento t"" & U (16#FD#) & ""den"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""tento m"" & U (16#11B#) & ""s"" & U (16#ED#) & ""c"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""letos"";");
         L ("         else");
         L ("            return ""nyn"" & U (16#ED#);");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#441#) & U (16#435#) & U (16#433#)");
         L ("              & U (16#43E#) & U (16#434#) & U (16#43D#)");
         L ("              & U (16#44F#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#43D#) & U (16#430#) & "" """);
         L ("              & U (16#44D#) & U (16#442#) & U (16#43E#)");
         L ("              & U (16#439#) & "" "" & U (16#43D#) & U (16#435#)");
         L ("              & U (16#434#) & U (16#435#) & U (16#43B#)");
         L ("              & U (16#435#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#432#) & "" "" & U (16#44D#)");
         L ("              & U (16#442#) & U (16#43E#) & U (16#43C#)");
         L ("              & "" "" & U (16#43C#) & U (16#435#) & U (16#441#)");
         L ("              & U (16#44F#) & U (16#446#) & U (16#435#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#432#) & "" "" & U (16#44D#)");
         L ("              & U (16#442#) & U (16#43E#) & U (16#43C#)");
         L ("              & "" "" & U (16#433#) & U (16#43E#) & U (16#434#)");
         L ("              & U (16#443#);");
         L ("         else");
         L ("            return U (16#441#) & U (16#435#) & U (16#439#)");
         L ("              & U (16#447#) & U (16#430#) & U (16#441#);");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#627#) & U (16#644#) & U (16#64A#)");
         L ("              & U (16#648#) & U (16#645#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#647#) & U (16#630#) & U (16#627#)");
         L ("              & "" "" & U (16#627#) & U (16#644#) & U (16#623#)");
         L ("              & U (16#633#) & U (16#628#) & U (16#648#)");
         L ("              & U (16#639#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#647#) & U (16#630#) & U (16#627#)");
         L ("              & "" "" & U (16#627#) & U (16#644#) & U (16#634#)");
         L ("              & U (16#647#) & U (16#631#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#647#) & U (16#630#) & U (16#647#)");
         L ("              & "" "" & U (16#627#) & U (16#644#) & U (16#633#)");
         L ("              & U (16#646#) & U (16#629#);");
         L ("         else");
         L ("            return U (16#627#) & U (16#644#) & U (16#622#)");
         L ("              & U (16#646#);");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#4ECA#) & U (16#65E5#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#4ECA#) & U (16#9031#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#4ECA#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#4ECA#) & U (16#5E74#);");
         L ("         else");
         L ("            return U (16#4ECA#);");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#4ECA#) & U (16#5929#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#672C#) & U (16#5468#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#672C#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#4ECA#) & U (16#5E74#);");
         L ("         else");
         L ("            return U (16#73B0#) & U (16#5728#);");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#C624#) & U (16#B298#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#C774#) & U (16#BC88#) & "" "" & U (16#C8FC#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#C774#) & U (16#BC88#) & "" "" & U (16#B2EC#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#C62C#) & U (16#D574#);");
         L ("         else");
         L ("            return U (16#C9C0#) & U (16#AE08#);");
         L ("         end if;");
         L ("      elsif Lang = ""tr"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#62#, 16#75#, 16#67#, 16#FC#, 16#6E#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return ""bu hafta"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""bu ay"";");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#62#, 16#75#, 16#20#, 16#79#, 16#131#, 16#6C#]);");
         L ("         else");
         L ("            return UTF8 ([16#15F#, 16#69#, 16#6D#, 16#64#, 16#69#]);");
         L ("         end if;");
         L ("      elsif Lang = ""sv"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""idag"";");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#64#, 16#65#, 16#6E#, 16#20#,");
         L ("                          16#68#, 16#E4#, 16#72#, 16#20#,");
         L ("                          16#76#, 16#65#, 16#63#, 16#6B#,");
         L ("                          16#61#, 16#6E#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#64#, 16#65#, 16#6E#, 16#6E#,");
         L ("                          16#61#, 16#20#, 16#6D#, 16#E5#,");
         L ("                          16#6E#, 16#61#, 16#64#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#69#, 16#20#, 16#E5#, 16#72#]);");
         L ("         else");
         L ("            return ""nu"";");
         L ("         end if;");
         L ("      elsif Lang = ""da"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""i dag"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""denne uge"";");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#64#, 16#65#, 16#6E#, 16#6E#,");
         L ("                          16#65#, 16#20#, 16#6D#, 16#E5#,");
         L ("                          16#6E#, 16#65#, 16#64#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#69#, 16#20#, 16#E5#, 16#72#]);");
         L ("         else");
         L ("            return ""nu"";");
         L ("         end if;");
         L ("      elsif Lang = ""fi"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#74#, 16#E4#, 16#6E#, 16#E4#, 16#E4#, 16#6E#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#74#, 16#E4#, 16#6C#, 16#6C#,");
         L ("                          16#E4#, 16#20#, 16#76#, 16#69#,");
         L ("                          16#69#, 16#6B#, 16#6F#, 16#6C#,");
         L ("                          16#6C#, 16#61#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#74#, 16#E4#, 16#73#, 16#73#,");
         L ("                          16#E4#, 16#20#, 16#6B#, 16#75#,");
         L ("                          16#75#, 16#73#, 16#73#, 16#61#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#74#, 16#E4#, 16#6E#, 16#E4#,");
         L ("                          16#20#, 16#76#, 16#75#, 16#6F#,");
         L ("                          16#6E#, 16#6E#, 16#61#]);");
         L ("         else");
         L ("            return ""nyt"";");
         L ("         end if;");
         L ("      elsif Lang = ""eo"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#68#, 16#6F#, 16#64#, 16#69#, 16#61#, 16#16D#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#109#, 16#69#, 16#20#, 16#74#,");
         L ("                          16#69#, 16#75#, 16#20#, 16#73#,");
         L ("                          16#65#, 16#6D#, 16#61#, 16#6A#,");
         L ("                          16#6E#, 16#6F#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#109#, 16#69#, 16#20#, 16#74#,");
         L ("                          16#69#, 16#75#, 16#20#, 16#6D#,");
         L ("                          16#6F#, 16#6E#, 16#61#, 16#74#,");
         L ("                          16#6F#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#109#, 16#69#, 16#20#, 16#74#,");
         L ("                          16#69#, 16#75#, 16#20#, 16#6A#,");
         L ("                          16#61#, 16#72#, 16#6F#]);");
         L ("         else");
         L ("            return ""nun"";");
         L ("         end if;");
         L ("      elsif Lang = ""vi"" then");
         L ("         if Base = ""day"" then");
         L ("            return UTF8 ([16#68#, 16#F4#, 16#6D#, 16#20#, 16#6E#, 16#61#, 16#79#]);");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#74#, 16#75#, 16#1EA7#, 16#6E#,");
         L ("                          16#20#, 16#6E#, 16#E0#, 16#79#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#74#, 16#68#, 16#E1#, 16#6E#,");
         L ("                          16#67#, 16#20#, 16#6E#, 16#E0#, 16#79#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#6E#, 16#103#, 16#6D#, 16#20#, 16#6E#, 16#61#, 16#79#]);");
         L ("         else");
         L ("            return UTF8 ([16#62#, 16#E2#, 16#79#, 16#20#, 16#67#, 16#69#, 16#1EDD#]);");
         L ("         end if;");
         L ("      elsif Lang = ""hu"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""ma"";");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#65#, 16#7A#, 16#65#, 16#6E#,");
         L ("                          16#20#, 16#61#, 16#20#, 16#68#,");
         L ("                          16#E9#, 16#74#, 16#65#, 16#6E#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return UTF8 ([16#65#, 16#62#, 16#62#, 16#65#,");
         L ("                          16#6E#, 16#20#, 16#61#, 16#20#,");
         L ("                          16#68#, 16#F3#, 16#6E#, 16#61#,");
         L ("                          16#70#, 16#62#, 16#61#, 16#6E#]);");
         L ("         elsif Base = ""year"" then");
         L ("            return UTF8 ([16#65#, 16#62#, 16#62#, 16#65#,");
         L ("                          16#6E#, 16#20#, 16#61#, 16#7A#,");
         L ("                          16#20#, 16#E9#, 16#76#, 16#62#,");
         L ("                          16#65#, 16#6E#]);");
         L ("         else");
         L ("            return ""most"";");
         L ("         end if;");
         L ("      elsif Lang = ""sk"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""dnes"";");
         L ("         elsif Base = ""week"" then");
         L ("            return UTF8 ([16#74#, 16#65#, 16#6E#, 16#74#,");
         L ("                          16#6F#, 16#20#, 16#74#, 16#FD#,");
         L ("                          16#17E#, 16#64#, 16#65#, 16#148#]);");
         L ("         elsif Base = ""month"" then");
         L ("            return ""tento mesiac"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""tento rok"";");
         L ("         else");
         L ("            return ""teraz"";");
         L ("         end if;");
         L ("      elsif Base = ""day"" then");
         L ("         return ""today"";");
         L ("      elsif Base = ""week"" then");
         L ("         return ""this week"";");
         L ("      elsif Base = ""month"" then");
         L ("         return ""this month"";");
         L ("      elsif Base = ""year"" then");
         L ("         return ""this year"";");
         L ("      else");
         L ("         return ""now"";");
         L ("      end if;");
         L ("   end Relative_Current_Name;");
      end Emit_Relative_Current_Name;

      procedure Emit_Relative_Offset_Affixes is
      begin
         --  "" is a real prefix for 387 of these locales, so absence has to
         --  be something a value cannot be: no CLDR text holds a NUL.
         Emit_Family_Locale_Table
           ("Relative_Offset_Prefix_Future_Row", "relative_offset", "future",
            "[1 => Character'Val (0)]", Value_Field => 'C');
         Emit_Family_Locale_Table
           ("Relative_Offset_Prefix_Past_Row", "relative_offset", "past",
            "[1 => Character'Val (0)]", Value_Field => 'C');
         L;
         L ("   function Relative_Offset_Prefix");
         L ("     (Locale : String;");
         L ("      Future : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      declare");
         L ("         Absent : constant String := [1 => Character'Val (0)];");
         L ("         Row : constant String :=");
         L ("           (if Future then Relative_Offset_Prefix_Future_Row (Locale)");
         L ("            else Relative_Offset_Prefix_Past_Row (Locale));");
         L ("      begin");
         L ("         if Row /= Absent then");
         L ("            return Row;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      if Future then");
         L ("         if Lang = ""fr"" then");
         L ("            return ""dans "";");
         L ("         elsif Lang = ""es"" then");
         L ("            return ""dentro de "";");
         L ("         elsif Lang = ""it"" then");
         L ("            return ""tra "";");
         L ("         elsif Lang = ""pt"" then");
         L ("            return ""em "";");
         L ("         elsif Lang = ""nl"" then");
         L ("            return ""over "";");
         L ("         elsif Lang = ""ro"" then");
         L ("            return ""peste "";");
         L ("         elsif Lang = ""lt"" then");
         L ("            return ""po "";");
         L ("         elsif Lang = ""sl"" then");
         L ("            return U (16#10D#) & ""ez "";");
         L ("         elsif Lang = ""pl"" or else Lang = ""cs"" then");
         L ("            return ""za "";");
         L ("         elsif Lang = ""ru"" then");
         L ("            return U (16#447#) & U (16#435#) & U (16#440#)");
         L ("              & U (16#435#) & U (16#437#) & "" "";");
         L ("         elsif Lang = ""ar"" then");
         L ("            return U (16#628#) & U (16#639#) & U (16#62F#) & "" "";");
         L ("         elsif Lang = ""sv"" or else Lang = ""da"" then");
         L ("            return ""om "";");
         L ("         elsif Lang = ""eo"" then");
         L ("            return ""post "";");
         L ("         elsif Lang = ""vi"" then");
         L ("            return ""trong "";");
         L ("         elsif Lang = ""sk"" then");
         L ("            return ""o "";");
         L ("         elsif Lang = ""no"" then");
         L ("            return ""om "";");
         L ("         elsif Lang = ""id"" or else Lang = ""ms"" then");
         L ("            return ""dalam "";");
         L ("         elsif Lang = ""af"" then");
         L ("            return ""oor "";");
         L ("         elsif Lang = ""sw"" then");
         L ("            return ""baada ya "";");
         L ("         elsif Lang = ""fi"" or else Lang = ""eu"" then");
         L ("            return """";");
         L ("         elsif Lang = ""tr"" or else Lang = ""hu"" then");
         L ("            return """";");
         L ("         elsif Lang = ""ja"" or else Lang = ""zh"" or else Lang = ""ko"" then");
         L ("            return """";");
         L ("         else");
         L ("            return ""in "";");
         L ("         end if;");
         L ("      elsif Lang = ""pt"" then");
         L ("         return ""h"" & U (16#E1#) & "" "";");
         L ("      elsif Lang = ""de"" then");
         L ("         return ""vor "";");
         L ("      elsif Lang = ""fr"" then");
         L ("         return ""il y a "";");
         L ("      elsif Lang = ""es"" then");
         L ("         return ""hace "";");
         L ("      elsif Lang = ""ro"" then");
         L ("         return ""acum "";");
         L ("      elsif Lang = ""lt"" then");
         L ("         return ""prie"" & U (16#161#) & "" "";");
         L ("      elsif Lang = ""sl"" then");
         L ("         return ""pred "";");
         L ("      elsif Lang = ""cs"" then");
         L ("         return ""p"" & U (16#159#) & ""ed "";");
         L ("      elsif Lang = ""ar"" then");
         L ("         return U (16#642#) & U (16#628#) & U (16#644#) & "" "";");
         L ("      elsif Lang = ""sv"" then");
         L ("         return UTF8 ([16#66#, 16#F6#, 16#72#, 16#20#]);");
         L ("      elsif Lang = ""da"" then");
         L ("         return ""for "";");
         L ("      elsif Lang = ""eo"" then");
         L ("         return UTF8 ([16#61#, 16#6E#, 16#74#, 16#61#, 16#16D#, 16#20#]);");
         L ("      elsif Lang = ""sk"" then");
         L ("         return ""pred "";");
         L ("      elsif Lang = ""no"" then");
         L ("         return ""for "";");
         L ("      elsif Lang = ""eu"" then");
         L ("         return ""duela "";");
         L ("      else");
         L ("         return """";");
         L ("      end if;");
         L ("   end Relative_Offset_Prefix;");
         --  "" is a real prefix for 387 of these locales, so absence has to
         --  be something a value cannot be: no CLDR text holds a NUL.
         Emit_Family_Locale_Table
           ("Relative_Offset_Suffix_Future_Row", "relative_offset", "future",
            "[1 => Character'Val (0)]", Value_Field => 'D');
         Emit_Family_Locale_Table
           ("Relative_Offset_Suffix_Past_Row", "relative_offset", "past",
            "[1 => Character'Val (0)]", Value_Field => 'D');
         L;
         L ("   function Relative_Offset_Suffix");
         L ("     (Locale : String;");
         L ("      Future : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      declare");
         L ("         Absent : constant String := [1 => Character'Val (0)];");
         L ("         Row : constant String :=");
         L ("           (if Future then Relative_Offset_Suffix_Future_Row (Locale)");
         L ("            else Relative_Offset_Suffix_Past_Row (Locale));");
         L ("      begin");
         L ("         if Row /= Absent then");
         L ("            return Row;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      if Future then");
         L ("         if Lang = ""ja"" then");
         L ("            return U (16#5F8C#);");
         L ("         elsif Lang = ""zh"" then");
         L ("            return U (16#540E#);");
         L ("         elsif Lang = ""ko"" then");
         L ("            return "" "" & U (16#D6C4#);");
         L ("         elsif Lang = ""tr"" then");
         L ("            return "" sonra"";");
         L ("         elsif Lang = ""hu"" then");
         L ("            return UTF8 ([16#20#, 16#6D#, 16#FA#, 16#6C#, 16#76#, 16#61#]);");
         L ("         elsif Lang = ""fi"" then");
         L ("            return UTF8 ([16#20#, 16#70#, 16#E4#, 16#E4#, 16#73#, 16#74#, 16#E4#]);");
         L ("         elsif Lang = ""eu"" then");
         L ("            return "" barru"";");
         L ("         else");
         L ("            return """";");
         L ("         end if;");
         L ("      elsif Lang = ""it"" then");
         L ("         return "" fa"";");
         L ("      elsif Lang = ""nl"" then");
         L ("         return "" geleden"";");
         L ("      elsif Lang = ""de"" or else Lang = ""fr"" or else Lang = ""es"" or else Lang = ""pt"" then");
         L ("         return """";");
         L ("      elsif Lang = ""ro"" or else Lang = ""lt"" or else Lang = ""sl"" then");
         L ("         return """";");
         L ("      elsif Lang = ""pl"" then");
         L ("         return "" temu"";");
         L ("      elsif Lang = ""ru"" then");
         L ("         return "" "" & U (16#43D#) & U (16#430#) & U (16#437#)");
         L ("           & U (16#430#) & U (16#434#);");
         L ("      elsif Lang = ""cs"" or else Lang = ""ar"" then");
         L ("         return """";");
         L ("      elsif Lang = ""ja"" or else Lang = ""zh"" then");
         L ("         return U (16#524D#);");
         L ("      elsif Lang = ""ko"" then");
         L ("         return "" "" & U (16#C804#);");
         L ("      elsif Lang = ""tr"" then");
         L ("         return UTF8 ([16#20#, 16#F6#, 16#6E#, 16#63#, 16#65#]);");
         L ("      elsif Lang = ""sv"" then");
         L ("         return "" sedan"";");
         L ("      elsif Lang = ""da"" then");
         L ("         return "" siden"";");
         L ("      elsif Lang = ""vi"" then");
         L ("         return UTF8 ([16#20#, 16#74#, 16#72#, 16#1B0#, 16#1EDB#, 16#63#]);");
         L ("      elsif Lang = ""hu"" then");
         L ("         return UTF8 ([16#20#, 16#65#, 16#7A#, 16#65#, 16#6C#, 16#151#, 16#74#, 16#74#]);");
         L ("      elsif Lang = ""eo"" or else Lang = ""sk"" or else Lang = ""eu"" then");
         L ("         return """";");
         L ("      elsif Lang = ""fi"" then");
         L ("         return "" sitten"";");
         L ("      elsif Lang = ""no"" then");
         L ("         return "" siden"";");
         L ("      elsif Lang = ""id"" then");
         L ("         return "" yang lalu"";");
         L ("      elsif Lang = ""ms"" then");
         L ("         return "" lalu"";");
         L ("      elsif Lang = ""af"" then");
         L ("         return "" gelede"";");
         L ("      elsif Lang = ""sw"" then");
         L ("         return "" iliyopita"";");
         L ("      else");
         L ("         return "" ago"";");
         L ("      end if;");
         L ("   end Relative_Offset_Suffix;");
      end Emit_Relative_Offset_Affixes;

      --  5,579 rows keyed on locale, base and category. One payload per
      --  locale holds that locale's rows, which is about seven of them, so a
      --  short scan inside the payload replaces a second index.
      --
      --  The order the chain resolved in has to survive: every wanted
      --  category, over the locale and then its parents, before any "other"
      --  row -- so a category found on a parent beats "other" on the locale
      --  itself. That is why the walk is here rather than in the table: the
      --  payload has to be retested at each parent, not just found.
      procedure Emit_Relative_Unit_Category_Name is
      begin
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
               if Is_Kind (Index, "relative_unit_category") then
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
                     & S (Rules (Index).C) & ","
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).D)));
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Relative_Unit_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   function Relative_Unit_Payload_Value");
         L ("     (Payload  : String;");
         L ("      Base     : String;");
         L ("      Category : String)");
         L ("      return String");
         L ("   is");
         L ("      Start : Positive := Payload'First;");
         L ("      Stop  : Natural;");
         L ("      Last  : Natural;");
         L ("      Sep_1 : Natural;");
         L ("      Sep_2 : Natural;");
         L ("   begin");
         L ("      while Start <= Payload'Last loop");
         L ("         Stop := Start;");
         L ("         while Stop <= Payload'Last and then Payload (Stop) /= ';' loop");
         L ("            Stop := Stop + 1;");
         L ("         end loop;");
         L ("         Last := Stop - 1;");
         L ("         Sep_1 := 0;");
         L ("         Sep_2 := 0;");
         L ("         for Index in Start .. Last loop");
         L ("            if Payload (Index) = ',' then");
         L ("               if Sep_1 = 0 then");
         L ("                  Sep_1 := Index;");
         L ("               else");
         L ("                  Sep_2 := Index;");
         L ("                  exit;");
         L ("               end if;");
         L ("            end if;");
         L ("         end loop;");
         L;
         L ("         if Sep_1 > 0 and then Sep_2 > 0");
         L ("           and then Payload (Start .. Sep_1 - 1) = Base");
         L ("           and then Payload (Sep_1 + 1 .. Sep_2 - 1) = Category");
         L ("         then");
         L ("            return VB (Payload (Sep_2 + 1 .. Last));");
         L ("         end if;");
         L ("         Start := Stop + 1;");
         L ("      end loop;");
         L;
         L ("      return """";");
         L ("   end Relative_Unit_Payload_Value;");
         L;
         L ("   function Relative_Unit_Category_Name");
         L ("     (Locale   : String;");
         L ("      Base     : String;");
         L ("      Category : String)");
         L ("      return String");
         L ("   is");
         L ("      function Find (Cand : String; Wanted : String) return String is");
         L ("         Row : constant String := Relative_Unit_Row (Cand);");
         L ("      begin");
         L ("         if Row = """" then");
         L ("            return """";");
         L ("         end if;");
         L ("         return Relative_Unit_Payload_Value (Row, Base, Wanted);");
         L ("      end Find;");
         L;
         L ("      --  The locale, then each parent, longest first.");
         L ("      function Resolve (Wanted : String) return String is");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Exact : constant String := Find (Locale, Wanted);");
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
         L ("                    Find (Canon (Canon'First .. Cut - 1), Wanted);");
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
         L ("      end Resolve;");
         L;
         L ("      Wanted : constant String := Resolve (Category);");
         L ("   begin");
         L ("      if Wanted /= """" then");
         L ("         return Wanted;");
         L ("      end if;");
         L;
         L ("      --  Only once no locale has the category does ""other"" answer,");
         L ("      --  and an ""other"" row answers whatever category was asked.");
         L ("      return Resolve (""other"");");
         L ("   end Relative_Unit_Category_Name;");
      end Emit_Relative_Unit_Category_Name;

      --  63,970 records, scanned from the first character on every pass and
      --  up to four passes to a lookup, which came to a quarter of a million
      --  record parses to answer one call. The records arrive grouped by
      --  locale, so each locale becomes one segment of the table and a
      --  lookup scans its eighty-odd records instead of all of them. The
      --  locale field goes with it: the segment already says which it is.
      procedure Emit_Relative_Time_Pattern is
         Pattern_Base : Label_Array;
         Pattern_Base_Count : Natural;
         Pattern_Width : Label_Array;
         Pattern_Width_Count : Natural;
         Pattern_Dir : Label_Array;
         Pattern_Dir_Count : Natural;
         Pattern_Cat : Label_Array;
         Pattern_Cat_Count : Natural;
      begin
         Collect_Labels ("relative_time_pattern", 2,
                         Pattern_Base, Pattern_Base_Count);
         Collect_Labels ("relative_time_pattern", 3,
                         Pattern_Width, Pattern_Width_Count);
         Collect_Labels ("relative_time_pattern", 4,
                         Pattern_Dir, Pattern_Dir_Count);
         Collect_Labels ("relative_time_pattern", 5,
                         Pattern_Cat, Pattern_Cat_Count);
         Reset_Table;
         declare
            Current : US.Unbounded_String;
            Rows : US.Unbounded_String;
         begin
            --  The rows arrive grouped by locale, so a change of locale ends
            --  the segment. Scanning back for a locale already seen would be
            --  quadratic, and this kind has tens of thousands of rows.
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "relative_time_pattern") then
                  if S (Rules (Index).A) /= S (Current) then
                     if US.Length (Rows) > 0 then
                        Add_Table_Entry (S (Current), S (Rows));
                     end if;

                     Current := Rules (Index).A;
                     Rows := US.Null_Unbounded_String;
                  end if;

                  US.Append
                    (Rows,
                     Label_Code (Pattern_Base, Pattern_Base_Count,
                                 S (Rules (Index).B), 1)
                     & Label_Code (Pattern_Width, Pattern_Width_Count,
                                   S (Rules (Index).C), 1)
                     & Label_Code (Pattern_Dir, Pattern_Dir_Count,
                                   S (Rules (Index).D), 1)
                     & Label_Code (Pattern_Cat, Pattern_Cat_Count,
                                   S (Rules (Index).E), 1)
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).F))
                     & "~");
               end if;
            end loop;

            if US.Length (Rows) > 0 then
               Add_Table_Entry (S (Current), S (Rows));
            end if;
         end;
         Emit_Locale_Table
           ("Relative_Pattern_Row", """""", Raw => True, Walk_Parents => False);

         L;
         L ("   function Relative_Time_Pattern");
         L ("     (Locale   : String;");
         L ("      Base     : String;");
         L ("      Width    : String;");
         L ("      Category : String;");
         L ("      Future   : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Direction : constant String :=");
         L ("        (if Future then ""future"" else ""past"");");
         L;
         Emit_Label_Chain ("Base_Code", "Base",
                           Pattern_Base, Pattern_Base_Count, 1);
         Emit_Label_Chain ("Width_Code", "Width",
                           Pattern_Width, Pattern_Width_Count, 1);
         Emit_Label_Chain ("Dir_Code", "Direction",
                           Pattern_Dir, Pattern_Dir_Count, 1);
         L;
         L ("      function Cat_Code (Want : String) return String is");
         for Position in 1 .. Pattern_Cat_Count loop
            L ("        " & (if Position = 1 then "(if" else " elsif")
               & " Want = """ & S (Pattern_Cat (Position)) & """ then """
               & Label_Code (Pattern_Cat, Pattern_Cat_Count,
                             S (Pattern_Cat (Position)), 1) & """");
         end loop;
         L ("         else "" "");");
         L;
         L ("      Fixed : constant String := Base_Code & Width_Code & Dir_Code;");
         L;
         L ("      --  Four coded characters, then the hex. The labels they");
         L ("      --  replace were nearly half of this table.");
         L ("      function Search (Rows : String; Wanted : String) return String is");
         L ("         Start : Positive := Rows'First;");
         L ("         Key : constant String := Fixed & Cat_Code (Wanted);");
         L ("      begin");
         L ("         for Index in Key'Range loop");
         L ("            if Key (Index) = ' ' then");
         L ("               return """";");
         L ("            end if;");
         L ("         end loop;");
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
         L ("               if Stop > Start + 4");
         L ("                 and then Rows (Start .. Start + 3) = Key");
         L ("               then");
         L ("                  return VB (Rows (Start + 4 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      --  Each parent in turn, longest first.");
         L ("      function Walk (Wanted : String) return String is");
         L ("         Canon : constant String := Canonical_Locale (Locale);");
         L ("         Cut : Natural := Canon'Last;");
         L ("      begin");
         L ("         while Cut > Canon'First loop");
         L ("            if Canon (Cut) = '-' then");
         L ("               declare");
         L ("                  Rows : constant String :=");
         L ("                    Relative_Pattern_Row (Canon (Canon'First .. Cut - 1));");
         L ("                  Hit : constant String := Search (Rows, Wanted);");
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
         L ("      end Walk;");
         L;
         L ("      Rows : constant String := Relative_Pattern_Row (Locale);");
         L ("      Exact : constant String := Search (Rows, Category);");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L;
         L ("      --  The wanted category over the locale, then the wider");
         L ("      --  ""other"", and only then the same two over its parents.");
         L ("      if Category /= ""other"" then");
         L ("         declare");
         L ("            Other_Exact : constant String := Search (Rows, ""other"");");
         L ("         begin");
         L ("            if Other_Exact /= """" then");
         L ("               return Other_Exact;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L;
         L ("      declare");
         L ("         Fallback_Result : constant String := Walk (Category);");
         L ("      begin");
         L ("         if Fallback_Result /= """" then");
         L ("            return Fallback_Result;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      if Category /= ""other"" then");
         L ("         return Walk (""other"");");
         L ("      end if;");
         L;
         L ("      return """";");
         L ("   end Relative_Time_Pattern;");
      end Emit_Relative_Time_Pattern;

      procedure Emit_Relative_Unit_Display_Name is
      begin
         L;
         L ("   function Relative_Unit_Display_Name");
         L ("     (Locale   : String;");
         L ("      Base     : String;");
         L ("      Singular : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Lang /= ""ru"" and then Lang /= ""uk"" and then Lang /= ""pl"" then");
         L ("         declare");
         L ("            Generated : constant String :=");
         L ("              Relative_Unit_Category_Name");
         L ("                (Locale, Base, (if Singular then ""one"" else ""other""));");
         L ("         begin");
         L ("            if Generated /= """" then");
         L ("               return Generated;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L;
         L ("      if Lang = ""ro"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""zi"" else ""zile"");");
         L ("         elsif Base = ""week"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""s"" & U (16#103#) & ""pt""");
         L ("                    & U (16#103#) & ""m"" & U (16#E2#)");
         L ("                    & ""n"" & U (16#103#)");
         L ("               else ""s"" & U (16#103#) & ""pt""");
         L ("                    & U (16#103#) & ""m"" & U (16#E2#) & ""ni"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""lun"" & U (16#103#) else ""luni"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""an"" else ""ani"");");
         L ("         end if;");
         L ("      elsif Lang = ""lt"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dien"" & U (16#105#) else ""dienas"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""savait"" & U (16#119#) else ""savaites"");");
         L ("         elsif Base = ""month"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""m"" & U (16#117#) & ""nes"" & U (16#12F#)");
         L ("               else ""m"" & U (16#117#) & ""nesius"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""metus"";");
         L ("         end if;");
         L ("      elsif Lang = ""sl"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dan"" else ""dnevi"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""teden"" else ""tedni"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""mesec"" else ""meseci"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""leto"" else ""leta"");");
         L ("         end if;");
         L ("      elsif Lang = ""pl"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dzie"" & U (16#144#) else ""dni"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""tydzie"" & U (16#144#) else ""tygodnie"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""miesi"" & U (16#105#) & ""c""");
         L ("                    else ""miesi"" & U (16#105#) & ""ce"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""rok"" else ""lata"");");
         L ("         end if;");
         L ("      elsif Lang = ""cs"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""den"" else ""dny"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""t"" & U (16#FD#) & ""den""");
         L ("                    else ""t"" & U (16#FD#) & ""dny"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""m"" & U (16#11B#) & ""s""");
         L ("                    & U (16#ED#) & ""c"" else ""m"" & U (16#11B#)");
         L ("                    & ""s"" & U (16#ED#) & ""ce"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""rok"" else ""roky"");");
         L ("         end if;");
         L ("      elsif Lang = ""ru"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then U (16#434#) & U (16#435#)");
         L ("                    & U (16#43D#) & U (16#44C#) else U (16#434#)");
         L ("                    & U (16#43D#) & U (16#44F#));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then U (16#43D#) & U (16#435#)");
         L ("                    & U (16#434#) & U (16#435#) & U (16#43B#)");
         L ("                    & U (16#44E#) else U (16#43D#) & U (16#435#)");
         L ("                    & U (16#434#) & U (16#435#) & U (16#43B#)");
         L ("                    & U (16#438#));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then U (16#43C#) & U (16#435#)");
         L ("                    & U (16#441#) & U (16#44F#) & U (16#446#)");
         L ("                    else U (16#43C#) & U (16#435#) & U (16#441#)");
         L ("                    & U (16#44F#) & U (16#446#) & U (16#430#));");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then U (16#433#) & U (16#43E#)");
         L ("                    & U (16#434#) else U (16#433#) & U (16#43E#)");
         L ("                    & U (16#434#) & U (16#430#));");
         L ("         end if;");
         L ("      elsif Lang = ""ar"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then U (16#64A#) & U (16#648#)");
         L ("                    & U (16#645#) else U (16#623#) & U (16#64A#)");
         L ("                    & U (16#627#) & U (16#645#));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then U (16#623#) & U (16#633#)");
         L ("                    & U (16#628#) & U (16#648#) & U (16#639#)");
         L ("                    else U (16#623#) & U (16#633#) & U (16#627#)");
         L ("                    & U (16#628#) & U (16#64A#) & U (16#639#));");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then U (16#634#) & U (16#647#)");
         L ("                    & U (16#631#) else U (16#623#) & U (16#634#)");
         L ("                    & U (16#647#) & U (16#631#));");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then U (16#633#) & U (16#646#)");
         L ("                    & U (16#629#) else U (16#633#) & U (16#646#)");
         L ("                    & U (16#648#) & U (16#627#) & U (16#62A#));");
         L ("         end if;");
         L ("      elsif Lang = ""tr"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""g"" & U (16#FC#) & ""n"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""hafta"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""ay"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""y"" & U (16#131#) & ""l"";");
         L ("         end if;");
         L ("      elsif Lang = ""sv"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dagar"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""vecka"" else ""veckor"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""m"" & U (16#E5#) & ""nad"" else ""m"" & U (16#E5#) & ""nader"");");
         L ("         elsif Base = ""year"" then");
         L ("            return """" & U (16#E5#) & ""r"";");
         L ("         end if;");
         L ("      elsif Lang = ""da"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dage"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""uge"" else ""uger"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""m"" & U (16#E5#) & ""ned"" else ""m"" & U (16#E5#) & ""neder"");");
         L ("         elsif Base = ""year"" then");
         L ("            return """" & U (16#E5#) & ""r"";");
         L ("         end if;");
         L ("      elsif Lang = ""eo"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""tago"" else ""tagoj"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""semajno"" else ""semajnoj"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""monato"" else ""monatoj"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""jaro"" else ""jaroj"");");
         L ("         end if;");
         L ("      elsif Lang = ""vi"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""ng"" & U (16#E0#) & ""y"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""tu"" & U (16#1EA7#) & ""n"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""th"" & U (16#E1#) & ""ng"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""n"" & U (16#103#) & ""m"";");
         L ("         end if;");
         L ("      elsif Lang = ""hu"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""nap"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""h"" & U (16#E9#) & ""t"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""h"" & U (16#F3#) & ""nap"";");
         L ("         elsif Base = ""year"" then");
         L ("            return """" & U (16#E9#) & ""v"";");
         L ("         end if;");
         L ("      elsif Lang = ""sk"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""de"" & U (16#148#) else ""dni"");");
         L ("         elsif Base = ""week"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""t"" & U (16#FD#) & U (16#17E#) & ""de"" & U (16#148#)");
         L ("               else ""t"" & U (16#FD#) & U (16#17E#) & ""dne"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""mesiac"" else ""mesiace"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""rok"" else ""roky"");");
         L ("         end if;");
         L ("      elsif Lang = ""fi"" then");
         L ("         if Base = ""day"" then");
         L ("            return");
         L ("              (if Singular");
         L ("               then ""p"" & U (16#E4#) & ""iv"" & U (16#E4#)");
         L ("               else ""p"" & U (16#E4#) & ""iv"" & U (16#E4#) & U (16#E4#));");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""viikko"" else ""viikkoa"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""kuukausi"" else ""kuukautta"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""vuosi"" else ""vuotta"");");
         L ("         end if;");
         L ("      elsif Lang = ""no"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dager"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""uke"" else ""uker"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""m"" & U (16#E5#) & ""ned"" else ""m"" & U (16#E5#) & ""neder"");");
         L ("         elsif Base = ""year"" then");
         L ("            return """" & U (16#E5#) & ""r"";");
         L ("         end if;");
         L ("      elsif Lang = ""id"" or else Lang = ""ms"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""hari"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""minggu"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""bulan"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""tahun"";");
         L ("         end if;");
         L ("      elsif Lang = ""af"" then");
         L ("         if Base = ""day"" then");
         L ("            return (if Singular then ""dag"" else ""dae"");");
         L ("         elsif Base = ""week"" then");
         L ("            return (if Singular then ""week"" else ""weke"");");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""maand"" else ""maande"");");
         L ("         elsif Base = ""year"" then");
         L ("            return ""jaar"";");
         L ("         end if;");
         L ("      elsif Lang = ""sw"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""siku"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""wiki"";");
         L ("         elsif Base = ""month"" then");
         L ("            return (if Singular then ""mwezi"" else ""miezi"");");
         L ("         elsif Base = ""year"" then");
         L ("            return (if Singular then ""mwaka"" else ""miaka"");");
         L ("         end if;");
         L ("      elsif Lang = ""eu"" then");
         L ("         if Base = ""day"" then");
         L ("            return ""egun"";");
         L ("         elsif Base = ""week"" then");
         L ("            return ""aste"";");
         L ("         elsif Base = ""month"" then");
         L ("            return ""hilabete"";");
         L ("         elsif Base = ""year"" then");
         L ("            return ""urte"";");
         L ("         end if;");
         L ("      elsif Lang = ""ja"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#65E5#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#9031#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#30F6#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#5E74#);");
         L ("         end if;");
         L ("      elsif Lang = ""zh"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#5929#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#5468#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#4E2A#) & U (16#6708#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#5E74#);");
         L ("         end if;");
         L ("      elsif Lang = ""ko"" then");
         L ("         if Base = ""day"" then");
         L ("            return U (16#C77C#);");
         L ("         elsif Base = ""week"" then");
         L ("            return U (16#C8FC#);");
         L ("         elsif Base = ""month"" then");
         L ("            return U (16#AC1C#) & U (16#C6D4#);");
         L ("         elsif Base = ""year"" then");
         L ("            return U (16#B144#);");
         L ("         end if;");
         L ("      end if;");
         L;
         L ("      return """";");
         L ("   end Relative_Unit_Display_Name;");
      end Emit_Relative_Unit_Display_Name;

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
      Emit_Date_Style_Pattern;
      Emit_Time_Style_Pattern;
      Emit_Available_Format_Pattern;
      Emit_Date_Time_Field_Separator;
      Emit_Date_Time_Style_Separator;
      Emit_Digits;
      Emit_Number_Display_Affixes;
      Emit_Date_Name_Function ("Month_Name", "month_full", "Month", "month_full");
      Emit_Date_Name_Function ("Month_Name_Short", "month_short", "Month", "month_short");
      Emit_Date_Name_Function ("Weekday_Name", "weekday_full", "Day", "weekday_full");
      Emit_Date_Name_Function ("Weekday_Name_Short", "weekday_short", "Day", "weekday_short");
      Emit_Quarter_Name;
      Emit_Day_Period_Name;
      Emit_Era_Name;
      Emit_Time_Zone_Data;
      Emit_Currency_Field ("Currency_Minor_Units", 2, "Natural", "2");
      Emit_Currency_Field ("Currency_Cash_Increment", 3, "Natural", "1");
      Emit_Currency_Field ("Currency_Symbol", 4, "String", "Code");
      Emit_Currency_Field ("Currency_Narrow_Symbol", 5, "String", "Currency_Symbol (Code)");
      Emit_Currency_Field ("Currency_Display_Name", 6, "String", "Code");
      --  Emit Currency_Display_Name as a subunit (see the subunit paths above).
      L;
      L ("   function Currency_Display_Name");
      L ("     (Locale   : String;");
      L ("      Code     : String;");
      L ("      Category : String := ""other"")");
      L ("      return String");
      L ("   is separate;");
      Ada.Text_IO.Create
        (Currency_Sub, Ada.Text_IO.Out_File, Currency_Sub_Generated);
      Current_File := Currency_Sub'Unchecked_Access;
      Subunit_Header;
      Emit_Localized_Currency_Display_Name;
      Current_File := Output'Unchecked_Access;
      Ada.Text_IO.Close (Currency_Sub);
      Emit_Symbol_First;
      Emit_Currency_Format_Patterns;
      Emit_List_Final_Separator;
      Emit_List_Item_Separator;
      Emit_List_Pattern_Separators;
      Emit_Per_Unit_Separator;
      Emit_Unit_Separators;
      --  Emit Unit_Display_Name as a subunit (see the subunit paths above).
      L;
      L ("   function Unit_Display_Name");
      L ("     (Locale   : String;");
      L ("      Base     : String;");
      L ("      Width    : String;");
      L ("      Category : String)");
      L ("      return String");
      L ("   is separate;");
      Ada.Text_IO.Create (Unit_Sub, Ada.Text_IO.Out_File, Unit_Sub_Generated);
      Current_File := Unit_Sub'Unchecked_Access;
      Subunit_Header;
      Emit_Unit_Display_Name;
      Current_File := Output'Unchecked_Access;
      Ada.Text_IO.Close (Unit_Sub);
      Emit_Byte_Size_Unit_Label;
      Emit_Number_Spellout_Words;
      Emit_Relative_Current_Name;
      Emit_Relative_Offset_Affixes;
      Emit_Relative_Unit_Category_Name;
      Emit_Relative_Time_Pattern;
      Emit_Relative_Unit_Display_Name;
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

begin
   Read_Wanted_Locales;
   if Has_Argument ("--help") then
      Ada.Text_IO.Put_Line
        ("usage: generate_cldr_data [--check] [--locales=en,de,...]" & ASCII.LF
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
           and then File_Equals_File (Currency_Sub_Generated, Currency_Sub_Target)
           and then File_Equals_File (Unit_Sub_Generated, Unit_Sub_Target)
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
         Ada.Directories.Copy_File (Currency_Sub_Generated, Currency_Sub_Target);
         Ada.Directories.Copy_File (Unit_Sub_Generated, Unit_Sub_Target);
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
