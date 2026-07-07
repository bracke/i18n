with Ada.Command_Line;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;

procedure Import_CLDR_Subset is
   package US renames Ada.Strings.Unbounded;
   package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   Source_Path : constant String := "import/normalized_cldr.txt";
   Target_Path : constant String := "data/cldr_subset.txt";
   Generated_Path : constant String := "/tmp/i18n_cldr_subset.generated.txt";

   Max_Keys : constant := 250_000;

   Errors    : Natural := 0;
   Key_Count : Natural := 0;
   Keys      : String_Sets.Set;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   procedure Add_Error (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Add_Error;

   procedure Add_Line_Error (Line_Number : Positive; Message : String) is
   begin
      Add_Error ("line" & Positive'Image (Line_Number) & ": " & Message);
   end Add_Line_Error;

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

   function Field_Count (Line : String; Separator : Character := '|') return Natural is
      Count : Natural := 1;
   begin
      if Line'Length = 0 then
         return 0;
      end if;

      for C of Line loop
         if C = Separator then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Field_Count;

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

   function Is_Hex_Text (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;

      for C of Value loop
         if C not in '0' .. '9' and then C not in 'A' .. 'F' and then C not in 'a' .. 'f' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Hex_Text;

   function Hex_Value (Value : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Value loop
         Result := Result * 16;
         if C in '0' .. '9' then
            Result := Result + Character'Pos (C) - Character'Pos ('0');
         elsif C in 'A' .. 'F' then
            Result := Result + 10 + Character'Pos (C) - Character'Pos ('A');
         else
            Result := Result + 10 + Character'Pos (C) - Character'Pos ('a');
         end if;
      end loop;

      return Result;
   end Hex_Value;

   function Hex_Digit (Value : Natural) return Character is
   begin
      if Value < 10 then
         return Character'Val (Character'Pos ('0') + Value);
      else
         return Character'Val (Character'Pos ('A') + Value - 10);
      end if;
   end Hex_Digit;

   function Hex_Image (Value : Natural) return String is
      Buffer : String (1 .. 8);
      First  : Natural := Buffer'Last + 1;
      Work   : Natural := Value;
   begin
      if Work = 0 then
         return "0";
      end if;

      while Work > 0 loop
         First := First - 1;
         Buffer (First) := Hex_Digit (Work mod 16);
         Work := Work / 16;
      end loop;

      return Buffer (First .. Buffer'Last);
   end Hex_Image;

   function Hex_Byte (Value : Natural) return String is
   begin
      return
        [1 => Hex_Digit (Value / 16),
         2 => Hex_Digit (Value mod 16)];
   end Hex_Byte;

   function Hex_Bytes (Text : String) return String is
      Output : US.Unbounded_String;
   begin
      for C of Text loop
         US.Append (Output, Hex_Byte (Character'Pos (C)));
      end loop;

      return S (Output);
   end Hex_Bytes;

   function Code_Point_Expr (Code : Natural) return String is
   begin
      return "U (16#" & Hex_Image (Code) & "#)";
   end Code_Point_Expr;

   function Decode_UTF8
     (Text  : String;
      Index : in out Positive;
      Valid : out Boolean)
      return Natural
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : Natural;
      B3 : Natural;
      B4 : Natural;
   begin
      Valid := True;

      if B1 <= 16#7F# then
         Index := Index + 1;
         return B1;
      elsif B1 in 16#C2# .. 16#DF# and then Index + 1 <= Text'Last then
         B2 := Character'Pos (Text (Index + 1));
         if B2 not in 16#80# .. 16#BF# then
            Valid := False;
            return 0;
         end if;
         Index := Index + 2;
         return (B1 mod 32) * 64 + (B2 mod 64);
      elsif B1 in 16#E0# .. 16#EF# and then Index + 2 <= Text'Last then
         B2 := Character'Pos (Text (Index + 1));
         B3 := Character'Pos (Text (Index + 2));
         if B2 not in 16#80# .. 16#BF# or else B3 not in 16#80# .. 16#BF# then
            Valid := False;
            return 0;
         end if;
         Index := Index + 3;
         return (B1 mod 16) * 4096 + (B2 mod 64) * 64 + (B3 mod 64);
      elsif B1 in 16#F0# .. 16#F4# and then Index + 3 <= Text'Last then
         B2 := Character'Pos (Text (Index + 1));
         B3 := Character'Pos (Text (Index + 2));
         B4 := Character'Pos (Text (Index + 3));
         if B2 not in 16#80# .. 16#BF#
           or else B3 not in 16#80# .. 16#BF#
           or else B4 not in 16#80# .. 16#BF#
         then
            Valid := False;
            return 0;
         end if;
         Index := Index + 4;
         return (B1 mod 8) * 262144 + (B2 mod 64) * 4096 + (B3 mod 64) * 64 + (B4 mod 64);
      else
         Valid := False;
         return 0;
      end if;
   end Decode_UTF8;

   function Ada_String_Literal (Text : String) return String is
      Output : US.Unbounded_String;
   begin
      US.Append (Output, """");
      for C of Text loop
         if C = '"' then
            US.Append (Output, """""");
         else
            US.Append (Output, C);
         end if;
      end loop;
      US.Append (Output, """");
      return S (Output);
   end Ada_String_Literal;

   function Text_Expr (Text : String) return String is
      Output     : US.Unbounded_String;
      ASCII_Run  : US.Unbounded_String;
      Index      : Positive := Text'First;
      First_Term : Boolean := True;

      procedure Append_Term (Term : String) is
      begin
         if not First_Term then
            US.Append (Output, " & ");
         end if;

         US.Append (Output, Term);
         First_Term := False;
      end Append_Term;

      procedure Flush_ASCII is
      begin
         if US.Length (ASCII_Run) > 0 then
            Append_Term (Ada_String_Literal (S (ASCII_Run)));
            ASCII_Run := US.Null_Unbounded_String;
         end if;
      end Flush_ASCII;
   begin
      if Text'Length = 0 then
         return """""";
      end if;

      while Index <= Text'Last loop
         declare
            Original_Index : constant Positive := Index;
            Valid          : Boolean;
            Code           : constant Natural := Decode_UTF8 (Text, Index, Valid);
         begin
            if not Valid then
               Add_Error ("invalid UTF-8 in normalized CLDR text");
               return """""";
            elsif Code <= 16#7F# then
               US.Append (ASCII_Run, Text (Original_Index));
            else
               Flush_ASCII;
               Append_Term (Code_Point_Expr (Code));
            end if;
         end;
      end loop;

      Flush_ASCII;

      if First_Term then
         return """""";
      else
         return S (Output);
      end if;
   end Text_Expr;

   function Codepoint_List_Expr (Text : String; Valid : out Boolean) return String is
      Output : US.Unbounded_String;
   begin
      Valid := True;
      for Index in 1 .. Field_Count (Text, ',') loop
         declare
            Code : constant String := Field (Text, Index, ',');
         begin
            if not Is_Hex_Text (Code) then
               Valid := False;
               return "";
            end if;

            if Index > 1 then
               US.Append (Output, ",");
            end if;
            US.Append (Output, "16#" & Hex_Image (Hex_Value (Code)) & "#");
         end;
      end loop;

      return S (Output);
   end Codepoint_List_Expr;

   function Raw_Payload (Line : String) return String is
   begin
      if Line'Length <= 4 then
         return "";
      else
         return Line (Line'First + 4 .. Line'Last);
      end if;
   end Raw_Payload;

   function Is_Name_Kind (Kind : String) return Boolean is
   begin
      return Kind = "month_full"
        or else Kind = "month_short"
        or else Kind = "weekday_full"
        or else Kind = "weekday_short"
        or else Kind = "quarter"
        or else Kind = "quarter_short";
   end Is_Name_Kind;

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
         if C not in 'a' .. 'z' and then C not in '0' .. '9' and then C /= '-' then
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

   function Is_Relative_Offset (Value : String) return Boolean is
   begin
      return Value = "future" or else Value = "past";
   end Is_Relative_Offset;

   function Is_Plural_Category (Value : String) return Boolean is
   begin
      return Value = "zero"
        or else Value = "one"
        or else Value = "two"
        or else Value = "few"
        or else Value = "many"
        or else Value = "other";
   end Is_Plural_Category;

   function Placeholder_Index (Pattern : String) return Natural is
   begin
      if Pattern'Length < 3 then
         return 0;
      end if;

      for Index in Pattern'First .. Pattern'Last - 2 loop
         if Pattern (Index .. Index + 2) = "{0}" then
            return Index;
         end if;
      end loop;

      return 0;
   end Placeholder_Index;

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
         if C not in 'a' .. 'z' and then C not in '0' .. '9' and then C /= '-' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Zone_Family;

   function Valid_Hex_List (Text : String) return Boolean is
   begin
      for Index in 1 .. Field_Count (Text, '~') loop
         declare
            Item : constant String := Field (Text, Index, '~');
         begin
            if not Is_Hex_Text (Item) then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Valid_Hex_List;

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

   function Raw_Key (Payload : String) return String is
      Kind : constant String := Field (Payload, 1);
   begin
      if Kind = "day_month_year" or else Kind = "symbol_first" then
         return Kind;
      elsif Kind = "decimal"
        or else Kind = "decimal_text"
        or else Kind = "group"
        or else Kind = "group_text"
        or else Kind = "digits"
        or else Kind = "digits_codepoints"
        or else Kind = "indian_grouping"
        or else Kind = "currency"
        or else Kind = "currency_text"
        or else Kind = "currency_name_payload"
        or else Kind = "cardinal"
        or else Kind = "ordinal"
      then
         if Kind = "decimal_text" then
            return "decimal|" & Field (Payload, 2);
         elsif Kind = "group_text" then
            return "group|" & Field (Payload, 2);
         elsif Kind = "digits_codepoints" then
            return "digits|" & Field (Payload, 2);
         elsif Kind = "currency_text" then
            return "currency|" & Field (Payload, 2);
         elsif Kind = "currency_name_payload" then
            return "currency_name_payload|" & Field (Payload, 2);
         else
            return Kind & "|" & Field (Payload, 2);
         end if;
      elsif Is_Name_Kind (Kind) then
         return Kind & "|" & Field (Payload, 2) & "|" & Field (Payload, 3);
      elsif Kind = "day_period" or else Kind = "day_period_text" then
         return "day_period|" & Field (Payload, 2) & "|" & Field (Payload, 3)
           & "|" & Field (Payload, 4);
      elsif Kind = "list_separator" or else Kind = "list_separator_text" then
         if Field_Count (Payload) = 4 then
            return "list_separator|" & Field (Payload, 2)
              & "|standard|" & Field (Payload, 3);
         else
            return "list_separator|" & Field (Payload, 2) & "|"
              & Field (Payload, 3) & "|" & Field (Payload, 4);
         end if;
      elsif Kind = "unit_separator" or else Kind = "unit_separator_text" then
         return "unit_separator|" & Field (Payload, 2) & "|" & Field (Payload, 3);
      elsif Kind = "unit_short" or else Kind = "unit_short_text" then
         return "unit_short|" & Field (Payload, 2);
      elsif Kind = "unit_name" or else Kind = "unit_name_text" then
         return "unit_name|" & Field (Payload, 2)
           & "|" & Field (Payload, 3) & "|" & Field (Payload, 4)
           & "|" & Field (Payload, 5);
      elsif Kind = "relative_current" or else Kind = "relative_current_text" then
         return "relative_current|" & Field (Payload, 2) & "|" & Field (Payload, 3)
           & "|"
           & (if Field_Count (Payload) = 4
              then "unit-width-full-name"
              else Field (Payload, 4));
      elsif Kind = "relative_offset" or else Kind = "relative_offset_text" then
         return "relative_offset|" & Field (Payload, 2) & "|" & Field (Payload, 3);
      elsif Kind = "relative_unit_category"
        or else Kind = "relative_unit_category_text"
      then
         return "relative_unit_category|" & Field (Payload, 2)
           & "|" & Field (Payload, 3) & "|" & Field (Payload, 4);
      elsif Kind = "relative_time_pattern"
        or else Kind = "relative_time_pattern_text"
      then
         return "relative_time_pattern|" & Field (Payload, 2)
           & "|" & Field (Payload, 3) & "|"
           & (if Field_Count (Payload) = 6
              then "unit-width-full-name"
              else Field (Payload, 4))
           & "|"
           & (if Field_Count (Payload) = 6
              then Field (Payload, 4)
              else Field (Payload, 5))
           & "|"
           & (if Field_Count (Payload) = 6
              then Field (Payload, 5)
              else Field (Payload, 6));
      elsif Kind = "zone_display" or else Kind = "zone_display_text" then
         return "zone_display|" & Field (Payload, 2) & "|" & Field (Payload, 3);
      elsif Kind = "zone_exemplar"
        or else Kind = "zone_exemplar_text"
        or else Kind = "zone_exemplar_hex"
      then
         return "zone_exemplar|" & Field (Payload, 2) & "|" & Field (Payload, 3);
      elsif Kind = "zone_family_display"
        or else Kind = "zone_family_display_text"
      then
         return "zone_family_display|" & Field (Payload, 2)
           & "|" & Field (Payload, 3);
      elsif Kind = "zone_short_family"
        or else Kind = "zone_short_family_text"
      then
         return "zone_short_family|" & Field (Payload, 2)
           & "|" & Field (Payload, 3);
      elsif Kind = "zone_gmt_prefix"
        or else Kind = "zone_gmt_prefix_text"
      then
         return "zone_gmt_prefix|" & Field (Payload, 2);
      elsif Kind = "zone_offset_separator"
        or else Kind = "zone_offset_separator_text"
      then
         return "zone_offset_separator|" & Field (Payload, 2);
      elsif Kind = "zone_location_pattern"
        or else Kind = "zone_location_pattern_text"
      then
         return "zone_location_pattern|" & Field (Payload, 2);
      elsif Kind = "available_format"
        or else Kind = "available_format_text"
      then
         return "available_format|" & Field (Payload, 2)
           & "|" & Field (Payload, 3);
      else
         return "";
      end if;
   end Raw_Key;

   function Expected_Name_Count (Kind : String; Start : Natural) return Natural is
   begin
      if Kind = "month_full" or else Kind = "month_short" then
         if Start /= 1 then
            return 0;
         end if;

         return 12;
      elsif Kind = "weekday_full" or else Kind = "weekday_short" then
         if Start /= 0 then
            return 0;
         end if;

         return 7;
      elsif Kind = "quarter" or else Kind = "quarter_short" then
         if Start /= 1 then
            return 0;
         end if;

         return 4;
      else
         return 0;
      end if;
   end Expected_Name_Count;

   procedure Add_Key (Key : String; Line_Number : Positive) is
   begin
      if Key = "" then
         Add_Line_Error (Line_Number, "cannot derive normalized data key");
         return;
      end if;

      if Keys.Contains (Key) then
         Add_Line_Error (Line_Number, "duplicate normalized data key: " & Key);
         return;
      end if;

      if Key_Count = Max_Keys then
         Add_Line_Error (Line_Number, "too many normalized data keys");
         return;
      end if;

      Key_Count := Key_Count + 1;
      Keys.Include (Key);
   end Add_Key;

   function Generate return String is
      Output      : Ada.Text_IO.File_Type;
      Seen_Output : Boolean := False;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Output, Text);
      end L;

      procedure Emit_Header is
      begin
         L ("# Deterministic CLDR-derived subset for I18N.CLDR_Data.");
         L ("#");
         L ("# Pipe-delimited source rows consumed by cldr/src/generate_cldr_data.adb.");
         L ("# Fields that begin with U (...) or quoted text are Ada expressions emitted into");
         L ("# the generated private package body.");
         L;
      end Emit_Header;

      procedure Parse_Line (Line : String; Line_Number : Positive) is
         Kind : constant String := Field (Line, 1);
      begin
         if Line'Length = 0 then
            if Seen_Output then
               L;
            end if;
            return;
         elsif Line (Line'First) = '#' then
            return;
         elsif Kind = "decimal_text" or else Kind = "group_text" then
            declare
               Target_Kind : constant String := (if Kind = "decimal_text" then "decimal" else "group");
               Locale      : constant String := Field (Line, 2);
               Text        : constant String := Field (Line, 3);
            begin
               if Field_Count (Line) /= 3 or else Locale = "" or else Text = "" then
                  Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
                  return;
               end if;

               Add_Key (Target_Kind & "|" & Locale, Line_Number);
               L (Target_Kind & "|" & Locale & "|" & Text_Expr (Text));
               Seen_Output := True;
            end;
         elsif Kind = "digits_codepoints" then
            declare
               Locale : constant String := Field (Line, 2);
               Codes  : constant String := Field (Line, 3);
               Valid  : Boolean;
            begin
               if Field_Count (Line) /= 3 or else Locale = "" or else Field_Count (Codes, ',') /= 10 then
                  Add_Line_Error (Line_Number, "invalid digits_codepoints row shape");
                  return;
               end if;

               declare
                  Converted : constant String := Codepoint_List_Expr (Codes, Valid);
               begin
                  if not Valid then
                     Add_Line_Error (Line_Number, "invalid digits_codepoints code point");
                     return;
                  end if;

                  Add_Key ("digits|" & Locale, Line_Number);
                  L ("digits|" & Locale & "|" & Converted);
                  Seen_Output := True;
               end;
            end;
         elsif Kind = "currency_text" then
            declare
               Code   : constant String := Field (Line, 2);
               Minor  : constant String := Field (Line, 3);
               Cash   : constant String := Field (Line, 4);
               Symbol : constant String := Field (Line, 5);
               Narrow : constant String := Field (Line, 6);
               Name   : constant String := Field (Line, 7);
            begin
               if Field_Count (Line) /= 7
                 or else Code'Length /= 3
                 or else not Is_Decimal_Text (Minor)
                 or else not Is_Decimal_Text (Cash)
                 or else Symbol = ""
                 or else Narrow = ""
                 or else Name = ""
               then
                  Add_Line_Error (Line_Number, "invalid currency_text row shape");
                  return;
               end if;

               Add_Key ("currency|" & Code, Line_Number);
               L
                 ("currency|" & Code & "|" & Minor & "|" & Cash & "|"
                  & Text_Expr (Symbol) & "|" & Text_Expr (Narrow) & "|" & Text_Expr (Name));
               Seen_Output := True;
            end;
         elsif Kind = "names_text" then
            declare
               Name_Kind  : constant String := Field (Line, 2);
               Locale     : constant String := Field (Line, 3);
               Start_Text : constant String := Field (Line, 4);
               Items      : constant String := Field (Line, 5);
            begin
               if Field_Count (Line) /= 5
                 or else not Is_Name_Kind (Name_Kind)
                 or else Locale = ""
                 or else not Is_Decimal_Text (Start_Text)
                 or else Items = ""
               then
                  Add_Line_Error (Line_Number, "invalid names_text row shape");
                  return;
               end if;

               declare
                  Start : constant Natural := Decimal_Value (Start_Text);
                  Count : constant Natural := Field_Count (Items, '~');
               begin
                  if Count /= Expected_Name_Count (Name_Kind, Start) then
                     Add_Line_Error (Line_Number, "unexpected names_text row count");
                     return;
                  end if;

                  for Index in 1 .. Count loop
                     declare
                        Position : constant String :=
                          Natural'Image (Start + Index - 1) (2 .. Natural'Image (Start + Index - 1)'Last);
                     begin
                        Add_Key (Name_Kind & "|" & Locale & "|" & Position, Line_Number);
                        L
                          (Name_Kind & "|" & Locale & "|" & Position & "|"
                           & Text_Expr (Field (Items, Index, '~')));
                     end;
                  end loop;
                  Seen_Output := True;
               end;
            end;
         elsif Kind = "names_hex" then
            declare
               Name_Kind  : constant String := Field (Line, 2);
               Locale     : constant String := Field (Line, 3);
               Start_Text : constant String := Field (Line, 4);
               Items      : constant String := Field (Line, 5);
            begin
               if Field_Count (Line) /= 5
                 or else not Is_Name_Kind (Name_Kind)
                 or else Locale = ""
                 or else not Is_Decimal_Text (Start_Text)
                 or else Items = ""
               then
                  Add_Line_Error (Line_Number, "invalid names_hex row shape");
                  return;
               end if;

               declare
                  Start     : constant Natural := Decimal_Value (Start_Text);
                  Count     : constant Natural := Field_Count (Items, '~');
               begin
                  if Count /= Expected_Name_Count (Name_Kind, Start) then
                     Add_Line_Error (Line_Number, "unexpected names_hex row count");
                     return;
                  elsif not Valid_Hex_List (Items) then
                     Add_Line_Error (Line_Number, "invalid names_hex item");
                     return;
                  end if;

                  Add_Key (Name_Kind & "|" & Locale, Line_Number);
                  L
                    ("name_set_hex|" & Name_Kind & "|" & Locale & "|"
                     & Start_Text & "|" & Items);
                  Seen_Output := True;
               end;
            end;
         elsif Kind = "day_period_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Period : constant String := Field (Line, 3);
               Width  : constant String := Field (Line, 4);
               Value  : constant String := Field (Line, 5);
            begin
               if Field_Count (Line) /= 5
                 or else Locale = ""
                 or else not Is_Day_Period (Period)
                 or else not Is_Day_Period_Width (Width)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid day_period_text row shape");
                  return;
               end if;

               Add_Key ("day_period|" & Locale & "|" & Period & "|" & Width, Line_Number);
               L
                 ("day_period_hex|" & Locale & "|" & Period & "|" & Width & "|"
                  & Hex_Bytes (Value));
               Seen_Output := True;
            end;
         elsif Kind = "list_separator_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Family : constant String :=
                 (if Field_Count (Line) = 4 then "standard" else Field (Line, 3));
               Part   : constant String :=
                 (if Field_Count (Line) = 4 then Field (Line, 3) else Field (Line, 4));
               Value  : constant String :=
                 (if Field_Count (Line) = 4 then Field (Line, 4) else Field (Line, 5));
            begin
               if Field_Count (Line) not in 4 | 5
                 or else Locale = ""
                 or else not Is_List_Separator_Family (Family)
                 or else not Is_List_Separator_Part (Part)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid list_separator_text row shape");
                  return;
               end if;

               Add_Key
                 ("list_separator|" & Locale & "|" & Family & "|" & Part,
                  Line_Number);
               L
                 ("list_separator|" & Locale & "|" & Family & "|" & Part & "|"
                  & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "unit_separator_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Part   : constant String := Field (Line, 3);
               Value  : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Unit_Separator_Part (Part)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid unit_separator_text row shape");
                  return;
               end if;

               Add_Key ("unit_separator|" & Locale & "|" & Part, Line_Number);
               L
                 ("unit_separator|" & Locale & "|" & Part & "|"
                  & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "unit_short_text" then
            declare
               Base  : constant String := Field (Line, 2);
               Value : constant String := Field (Line, 3);
            begin
               if Field_Count (Line) /= 3
                 or else not Is_Unit_Base (Base)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid unit_short_text row shape");
                  return;
               end if;

               Add_Key ("unit_short|" & Base, Line_Number);
               L ("unit_short|" & Base & "|" & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "unit_name_text" then
            declare
               Locale   : constant String := Field (Line, 2);
               Base     : constant String := Field (Line, 3);
               Width    : constant String := Field (Line, 4);
               Category : constant String := Field (Line, 5);
               Value    : constant String := Field (Line, 6);
            begin
               if Field_Count (Line) /= 6
                 or else Locale = ""
                 or else not Is_Unit_Base (Base)
                 or else Width = ""
                 or else not Is_Plural_Category (Category)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid unit_name_text row shape");
                  return;
               end if;

               Add_Key
                 ("unit_name|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category,
                  Line_Number);
               L
                 ("unit_name|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category & "|" & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "relative_current_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Base   : constant String := Field (Line, 3);
               Width  : constant String :=
                 (if Field_Count (Line) = 4
                  then "unit-width-full-name"
                  else Field (Line, 4));
               Value  : constant String :=
                 (if Field_Count (Line) = 4
                  then Field (Line, 4)
                  else Field (Line, 5));
            begin
               if Field_Count (Line) not in 4 .. 5
                 or else Locale = ""
                 or else not Is_Relative_Base (Base)
                 or else not Is_Relative_Width (Width)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid relative_current_text row shape");
                  return;
               end if;

               Add_Key
                 ("relative_current|" & Locale & "|" & Base & "|" & Width,
                  Line_Number);
               L
                 ("relative_current|" & Locale & "|" & Base & "|"
                  & Width & "|" & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "relative_offset_text" then
            declare
               Locale  : constant String := Field (Line, 2);
               Offset  : constant String := Field (Line, 3);
               Pattern : constant String := Field (Line, 4);
               Marker  : constant Natural := Placeholder_Index (Pattern);
               Prefix  : constant String :=
                 (if Marker = 0
                  then ""
                  elsif Marker = Pattern'First
                  then ""
                  else Pattern (Pattern'First .. Marker - 1));
               Suffix  : constant String :=
                 (if Marker = 0
                  then ""
                  elsif Marker + 3 > Pattern'Last
                  then ""
                  else Pattern (Marker + 3 .. Pattern'Last));
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Relative_Offset (Offset)
                 or else Pattern = ""
                 or else Marker = 0
               then
                  Add_Line_Error (Line_Number, "invalid relative_offset_text row shape");
                  return;
               end if;

               Add_Key ("relative_offset|" & Locale & "|" & Offset, Line_Number);
               L
                 ("relative_offset|" & Locale & "|" & Offset & "|"
                 & Text_Expr (Prefix) & "|" & Text_Expr (Suffix));
               Seen_Output := True;
            end;
         elsif Kind = "relative_unit_category_text" then
            declare
               Locale   : constant String := Field (Line, 2);
               Base     : constant String := Field (Line, 3);
               Category : constant String := Field (Line, 4);
               Value    : constant String := Field (Line, 5);
            begin
               if Field_Count (Line) /= 5
                 or else Locale = ""
                 or else not Is_Relative_Base (Base)
                 or else not Is_Plural_Category (Category)
                 or else Value = ""
               then
                  Add_Line_Error
                    (Line_Number, "invalid relative_unit_category_text row shape");
                  return;
               end if;

               Add_Key
                 ("relative_unit_category|" & Locale & "|" & Base & "|"
                  & Category,
                  Line_Number);
               L
                 ("relative_unit_category|" & Locale & "|" & Base & "|"
                  & Category & "|" & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "relative_time_pattern_text" then
            declare
               Locale    : constant String := Field (Line, 2);
               Base      : constant String := Field (Line, 3);
               Width     : constant String :=
                 (if Field_Count (Line) = 6
                  then "unit-width-full-name"
                  else Field (Line, 4));
               Direction : constant String :=
                 (if Field_Count (Line) = 6
                  then Field (Line, 4)
                  else Field (Line, 5));
               Category  : constant String :=
                 (if Field_Count (Line) = 6
                  then Field (Line, 5)
                  else Field (Line, 6));
               Pattern   : constant String :=
                 (if Field_Count (Line) = 6
                  then Field (Line, 6)
                  else Field (Line, 7));
            begin
               if Field_Count (Line) not in 6 .. 7
                 or else Locale = ""
                 or else not Is_Relative_Base (Base)
                 or else not Is_Relative_Width (Width)
                 or else not Is_Relative_Offset (Direction)
                 or else not Is_Plural_Category (Category)
                 or else Pattern = ""
                 or else Placeholder_Index (Pattern) = 0
               then
                  Add_Line_Error
                    (Line_Number, "invalid relative_time_pattern_text row shape");
                  return;
               end if;

               Add_Key
                 ("relative_time_pattern|" & Locale & "|" & Base & "|"
                  & Width & "|" & Direction & "|" & Category,
                  Line_Number);
               L
                 ("relative_time_pattern|" & Locale & "|" & Base & "|"
                  & Width & "|" & Direction & "|" & Category & "|"
                  & Text_Expr (Pattern));
               Seen_Output := True;
            end;
         elsif Kind = "zone_display_text" or else Kind = "zone_exemplar_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Zone   : constant String := Field (Line, 3);
               Value  : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Zone_Id (Zone)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid " & Kind & " row shape");
                  return;
               end if;

               if Kind = "zone_display_text" then
                  Add_Key ("zone_display|" & Locale & "|" & Zone, Line_Number);
                  L
                    ("zone_display|" & Locale & "|" & Zone & "|"
                     & Text_Expr (Value));
               else
                  Add_Key ("zone_exemplar|" & Locale & "|" & Zone, Line_Number);
                  L
                    ("zone_exemplar_hex|" & Locale & "|" & Zone & "|"
                     & Hex_Bytes (Value));
               end if;
               Seen_Output := True;
            end;
         elsif Kind = "zone_family_display_text" then
            declare
               Locale : constant String := Field (Line, 2);
               Family : constant String := Field (Line, 3);
               Value  : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Zone_Family (Family)
                 or else Value = ""
               then
                  Add_Line_Error
                    (Line_Number, "invalid zone_family_display_text row shape");
                  return;
               end if;

               Add_Key
                 ("zone_family_display|" & Locale & "|" & Family,
                  Line_Number);
               L
                 ("zone_family_display|" & Locale & "|" & Family & "|"
                  & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "zone_short_family_text" then
            declare
               Locale   : constant String := Field (Line, 2);
               Family   : constant String := Field (Line, 3);
               Standard : constant String := Field (Line, 4);
               Daylight : constant String := Field (Line, 5);
               Generic_Label : constant String := Field (Line, 6);
            begin
               if Field_Count (Line) /= 6
                 or else Locale = ""
                 or else not Is_Zone_Family (Family)
                 or else Standard = ""
                 or else Daylight = ""
                 or else Generic_Label = ""
               then
                  Add_Line_Error
                    (Line_Number, "invalid zone_short_family_text row shape");
                  return;
               end if;

               Add_Key
                 ("zone_short_family|" & Locale & "|" & Family,
                  Line_Number);
               L
                 ("zone_short_family|" & Locale & "|" & Family & "|"
                  & Text_Expr (Standard) & "|" & Text_Expr (Daylight)
                  & "|" & Text_Expr (Generic_Label));
               Seen_Output := True;
            end;
         elsif Kind = "zone_gmt_prefix_text"
           or else Kind = "zone_offset_separator_text"
           or else Kind = "zone_location_pattern_text"
         then
            declare
               Locale : constant String := Field (Line, 2);
               Value  : constant String := Field (Line, 3);
               Output_Kind : constant String :=
                 (if Kind = "zone_gmt_prefix_text" then "zone_gmt_prefix"
                  elsif Kind = "zone_offset_separator_text" then "zone_offset_separator"
                  else "zone_location_pattern");
            begin
               if Field_Count (Line) /= 3
                 or else Locale = ""
                 or else Value = ""
               then
                  Add_Line_Error
                    (Line_Number, "invalid " & Kind & " row shape");
                  return;
               end if;

               Add_Key (Output_Kind & "|" & Locale, Line_Number);
               L (Output_Kind & "|" & Locale & "|" & Text_Expr (Value));
               Seen_Output := True;
            end;
         elsif Kind = "available_format_text" then
            declare
               Locale   : constant String := Field (Line, 2);
               Skeleton : constant String := Field (Line, 3);
               Pattern  : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Skeleton_Key (Skeleton)
                 or else Pattern = ""
               then
                  Add_Line_Error
                    (Line_Number, "invalid available_format_text row shape");
                  return;
               end if;

               Add_Key
                 ("available_format|" & Locale & "|" & Skeleton,
                  Line_Number);
               L
                 ("available_format|" & Locale & "|" & Skeleton
                  & "|" & Text_Expr (Pattern));
               Seen_Output := True;
            end;
         elsif Kind = "raw" then
            if Raw_Payload (Line) = "" then
               Add_Line_Error (Line_Number, "raw row must contain a subset row");
            else
               Add_Key (Raw_Key (Raw_Payload (Line)), Line_Number);
               L (Raw_Payload (Line));
               Seen_Output := True;
            end if;
         elsif Kind = "names" then
            declare
               Name_Kind : constant String := Field (Line, 2);
               Locale    : constant String := Field (Line, 3);
               Start_Text : constant String := Field (Line, 4);
               Items     : constant String := Field (Line, 5);
            begin
               if Field_Count (Line) /= 5
                 or else not Is_Name_Kind (Name_Kind)
                 or else Locale = ""
                 or else not Is_Decimal_Text (Start_Text)
                 or else Items = ""
               then
                  Add_Line_Error (Line_Number, "invalid names row shape");
                  return;
               end if;

               declare
                  Start : constant Natural := Decimal_Value (Start_Text);
                  Count : constant Natural := Field_Count (Items, '~');
               begin
                  if Count /= Expected_Name_Count (Name_Kind, Start) then
                     Add_Line_Error (Line_Number, "unexpected names row count");
                     return;
                  end if;

                  for Index in 1 .. Count loop
                     Add_Key
                       (Name_Kind & "|" & Locale & "|"
                        & Natural'Image (Start + Index - 1) (2 .. Natural'Image (Start + Index - 1)'Last),
                        Line_Number);
                     L
                       (Name_Kind & "|" & Locale & "|"
                        & Natural'Image (Start + Index - 1) (2 .. Natural'Image (Start + Index - 1)'Last)
                        & "|" & Field (Items, Index, '~'));
                  end loop;
                  Seen_Output := True;
               end;
            end;
         else
            Add_Line_Error (Line_Number, "invalid normalized CLDR row: " & Line);
         end if;
      end Parse_Line;

      Input       : Ada.Text_IO.File_Type;
      Line_Number : Positive := 1;
   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Emit_Header;

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
      Ada.Text_IO.Close (Output);

      return "";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (Input) then
            Ada.Text_IO.Close (Input);
         end if;
         if Ada.Text_IO.Is_Open (Output) then
            Ada.Text_IO.Close (Output);
         end if;
         raise;
   end Generate;

begin
   if Has_Argument ("--help") then
      Ada.Text_IO.Put_Line
        ("usage: import_cldr_subset [--check]" & ASCII.LF
         & "Imports cldr/data/cldr_subset.txt from import/normalized_cldr.txt.");
      return;
   end if;

   declare
      Generated : constant String := Generate;
   begin
      if Errors /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif Has_Argument ("--check") then
         if File_Equals_File (Generated_Path, Target_Path) then
            Ada.Text_IO.Put_Line ("CLDR subset import is current");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "cldr/data/cldr_subset.txt is not current; run cldr/bin/import_cldr_subset");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      else
         Ada.Directories.Copy_File (Generated_Path, Target_Path);
         Ada.Text_IO.Put_Line ("imported cldr/data/cldr_subset.txt");
      end if;
   end;
exception
   when others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to import CLDR subset");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Import_CLDR_Subset;
