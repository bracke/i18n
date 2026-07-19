with Ada.Command_Line;
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

   function Ada_Expression_UTF8_Hex (Expr : String) return String is
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
   end Ada_Expression_UTF8_Hex;

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
                 or else C in '_' | '-' | '+' | '/') then
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
      use type US.Unbounded_String;

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
         Args : GNAT.OS_Lib.Argument_List (1 .. 3) :=
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
            Args_I    : GNAT.OS_Lib.Argument_List (1 .. 4) :=
              [new String'("-i"), new String'("-c"), new String'("1900,2051"),
               new String'(Zone_Path)];
            Args_V    : GNAT.OS_Lib.Argument_List (1 .. 4) :=
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
         L ("                     return HB (Payload (Slot_Start .. Slot_End));");
         L ("                  end if;");
         L ("                  return """";");
         L ("               end if;");
         L;
         L ("               exit when Slot_End = Last;");
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
         L ("                  return H (Items (Start .. Index - 1));");
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
         L ("         return H (Items (Start .. Items'Last));");
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

      procedure Emit_Locale_Return_Function
        (Name         : String;
         Kind         : String;
         Default_Expr : String)
      is
         First : Boolean := True;
      begin
         L;
         L ("   function " & Name & " (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, Kind) then
                  L ("      " & (if First then "if" else "elsif")
                     & " Locale_In_List");
                  L ("        (Locale => Locale,");
                  L ("         List => """ & S (Rules (Index).A) & """,");
                  L ("         Include_Fallback => " & (if Pass = 1 then "False" else "True")
                     & ") then");
                  L ("         return " & S (Rules (Index).B) & ";");
                  First := False;
               end if;
            end loop;
         end loop;
         L ("      else");
         L ("         return " & Default_Expr & ";");
         L ("      end if;");
         L ("   end " & Name & ";");
      end Emit_Locale_Return_Function;

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

      procedure Emit_Date_Style_Pattern is
         Style_Data : US.Unbounded_String;
         Index_Data : US.Unbounded_String;

         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := 72;
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
      begin
         --  Rows arrive grouped by locale, so each locale occupies one run of
         --  the packed table. Record where each run starts and ends: a lookup
         --  then reads the handful of rows for one locale instead of walking
         --  all of them.
         declare
            Current : US.Unbounded_String;
            Seg_First : Natural := 1;

            procedure Close_Segment is
            begin
               if US.Length (Current) > 0 then
                  US.Append
                    (Index_Data,
                     S (Current) & "|" & Trim (Seg_First'Image) & "|"
                     & Trim (Natural'Image (US.Length (Style_Data))) & "~");
               end if;
            end Close_Segment;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "date_style_pattern") then
                  if S (Rules (Index).A) /= S (Current) then
                     Close_Segment;
                     Current := Rules (Index).A;
                     Seg_First := US.Length (Style_Data) + 1;
                  end if;
                  US.Append
                    (Style_Data,
                     S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                     & S (Rules (Index).C) & "|"
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).D)) & "~");
               end if;
            end loop;
            Close_Segment;
         end;

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
         L ("      Style_Data : constant String :=");
         Emit_String_Expression ("        ", S (Style_Data), ";");
         L;
         L ("      --  locale|first|last~ into Style_Data, one run per locale.");
         L ("      Index_Data : constant String :=");
         Emit_String_Expression ("        ", S (Index_Data), ";");
         L;
         --  Locale strings in the index come from CLDR and are already in
         --  canonical form, so a plain comparison answers almost every call.
         --  Canonical => True is the retry for a caller that spelled the
         --  locale differently ("EN_gb"), which Locale_Equals still accepts.
         L ("      procedure Segment");
         L ("        (Cand      : String;");
         L ("         Canonical : Boolean;");
         L ("         First     : out Natural;");
         L ("         Last      : out Natural)");
         L ("      is");
         L ("         Start : Positive := Index_Data'First;");
         L ("      begin");
         L ("         First := 0;");
         L ("         Last := 0;");
         L ("         while Start <= Index_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Stop : Natural := Index_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Index_Data'Last loop");
         L ("                  if Index_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     end if;");
         L ("                  elsif Index_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L ("               exit when Sep1 = 0 or else Sep2 = 0;");
         L ("               if (if Canonical then");
         L ("                     Locale_Equals (Cand, Index_Data (Start .. Sep1 - 1))");
         L ("                   else Index_Data (Start .. Sep1 - 1) = Cand)");
         L ("               then");
         L ("                  First :=");
         L ("                    Natural'Value (Index_Data (Sep1 + 1 .. Sep2 - 1));");
         L ("                  Last :=");
         L ("                    Natural'Value (Index_Data (Sep2 + 1 .. Stop - 1));");
         L ("                  return;");
         L ("               end if;");
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L ("      end Segment;");
         L;
         --  Within one locale's run there are at most a few dozen rows, so the
         --  calendar and style match is a short scan rather than a table walk.
         L ("      function In_Segment");
         L ("        (First, Last : Natural;");
         L ("         Wanted_Calendar : String)");
         L ("         return String");
         L ("      is");
         L ("         Start : Natural := First;");
         L ("         Fallback_First : Natural := 0;");
         L ("         Fallback_Last : Natural := 0;");
         L ("      begin");
         L ("         if First = 0 then");
         L ("            return """";");
         L ("         end if;");
         L ("         while Start <= Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Sep3 : Natural := 0;");
         L ("               Stop : Natural := Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Last loop");
         L ("                  if Style_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     elsif Sep3 = 0 then");
         L ("                        Sep3 := Index;");
         L ("                     end if;");
         L ("                  elsif Style_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L ("               exit when Sep1 = 0 or else Sep2 = 0 or else Sep3 = 0;");
         L ("               if Style_Data (Sep2 + 1 .. Sep3 - 1) = Style then");
         L ("                  declare");
         L ("                     Cal : constant String :=");
         L ("                       Style_Data (Sep1 + 1 .. Sep2 - 1);");
         L ("                  begin");
         L ("                     if Cal = Wanted_Calendar then");
         L ("                        return HB (Style_Data (Sep3 + 1 .. Stop - 1));");
         L ("                     elsif Cal = ""gregorian"" then");
         L ("                        Fallback_First := Sep3 + 1;");
         L ("                        Fallback_Last := Stop - 1;");
         L ("                     end if;");
         L ("                  end;");
         L ("               end if;");
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L ("         if Fallback_First /= 0 then");
         L ("            return HB (Style_Data (Fallback_First .. Fallback_Last));");
         L ("         end if;");
         L ("         return """";");
         L ("      end In_Segment;");
         L;
         --  Exact locale first, then each parent -- "en-GB" before "en" --
         --  which is what the old fallback pass amounted to.
         L ("      function Search (Wanted_Calendar : String) return String is");
         L ("         First, Last : Natural;");
         L ("         Cut : Natural := Locale'Last;");
         L ("      begin");
         L ("         Segment (Locale, False, First, Last);");
         L ("         declare");
         L ("            Hit : constant String :=");
         L ("              In_Segment (First, Last, Wanted_Calendar);");
         L ("         begin");
         L ("            if Hit /= """" then");
         L ("               return Hit;");
         L ("            end if;");
         L ("         end;");
         L;
         L ("         while Cut > Locale'First loop");
         L ("            if Locale (Cut) = '-' then");
         L ("               Segment");
         L ("                 (Locale (Locale'First .. Cut - 1), False, First, Last);");
         L ("               declare");
         L ("                  Hit : constant String :=");
         L ("                    In_Segment (First, Last, Wanted_Calendar);");
         L ("               begin");
         L ("                  if Hit /= """" then");
         L ("                     return Hit;");
         L ("                  end if;");
         L ("               end;");
         L ("            end if;");
         L ("            Cut := Cut - 1;");
         L ("         end loop;");
         L;
         L ("         --  Nothing matched as spelled; retry accepting any");
         L ("         --  spelling of the same locale.");
         L ("         Segment (Locale, True, First, Last);");
         L ("         return In_Segment (First, Last, Wanted_Calendar);");
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

      procedure Emit_Available_Format_Pattern is
         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := 72;
            Start      : Positive := Value'First;
            Stop       : Natural;
            Term       : Positive := 1;
         begin
            if Value'Length <= Chunk_Size then
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

         procedure Emit_Locale_List_Test
           (First_Branch : in out Boolean;
            Locales      : String)
         is
         begin
            L ("                  " & (if First_Branch then "if" else "elsif")
               & " Locale_In_List_For_Pass");
            L ("                    (List =>");
            Emit_String_Expression ("                       ", Locales, ",");
            L ("                     Include_Fallback => Include_Fallback,");
            L ("                     Fallback_Depth => Fallback_Depth)");
            L ("                  then");
            First_Branch := False;
         end Emit_Locale_List_Test;

         function Has_Available_Format_Skeleton
           (Index : Positive)
            return Boolean
         is
         begin
            for Prior in 1 .. Index - 1 loop
               if Is_Kind (Prior, "available_format")
                 and then S (Rules (Prior).B) = S (Rules (Index).B)
               then
                  return True;
               end if;
            end loop;

            return False;
         end Has_Available_Format_Skeleton;

         function Has_Available_Format_Pattern
           (Index : Positive)
            return Boolean
         is
         begin
            for Prior in 1 .. Index - 1 loop
               if Is_Kind (Prior, "available_format")
                 and then S (Rules (Prior).B) = S (Rules (Index).B)
                 and then S (Rules (Prior).C) = S (Rules (Index).C)
               then
                  return True;
               end if;
            end loop;

            return False;
         end Has_Available_Format_Pattern;

         function Locale_List_For
           (Skeleton : String;
            Pattern  : String)
            return String
         is
            Result : US.Unbounded_String;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "available_format")
                 and then S (Rules (Index).B) = Skeleton
                 and then S (Rules (Index).C) = Pattern
               then
                  if US.Length (Result) > 0 then
                     US.Append (Result, ",");
                  end if;
                  US.Append (Result, S (Rules (Index).A));
               end if;
            end loop;

            return S (Result);
         end Locale_List_For;
      begin
         L;
         L ("   function Available_Format_Pattern");
         L ("     (Locale   : String;");
         L ("      Skeleton : String)");
         L ("      return String");
         L ("   is");
         L;
         L ("      function Dash_Count (Value : String) return Natural is");
         L ("         Count : Natural := 0;");
         L ("      begin");
         L ("         for C of Value loop");
         L ("            if C = '-' then");
         L ("               Count := Count + 1;");
         L ("            end if;");
         L ("         end loop;");
         L ("         return Count;");
         L ("      end Dash_Count;");
         L;
         L ("      function Locale_In_List_For_Pass");
         L ("        (List             : String;");
         L ("         Include_Fallback : Boolean;");
         L ("         Fallback_Depth   : Natural)");
         L ("         return Boolean");
         L ("      is");
         L ("         Start : Positive := List'First;");
         L;
         L ("         function Matches (Candidate : String) return Boolean is");
         L ("         begin");
         L ("            if Include_Fallback then");
         L ("               return Dash_Count (Candidate) = Fallback_Depth");
         L ("                 and then Locale_Fallback_Matches (Locale, Candidate);");
         L ("            else");
         L ("               return Locale_Equals (Locale, Candidate);");
         L ("            end if;");
         L ("         end Matches;");
         L ("      begin");
         L ("         for Index in List'Range loop");
         L ("            if List (Index) = ',' then");
         L ("               if Matches (List (Start .. Index - 1)) then");
         L ("                  return True;");
         L ("               end if;");
         L ("               Start := Index + 1;");
         L ("            end if;");
         L ("         end loop;");
         L;
         L ("         return Matches (List (Start .. List'Last));");
         L ("      end Locale_In_List_For_Pass;");
         L ("   begin");

         for Skeleton_Index in 1 .. Rule_Count loop
            if Is_Kind (Skeleton_Index, "available_format")
              and then not Has_Available_Format_Skeleton (Skeleton_Index)
            then
               L ("      if Skeleton = """ & S (Rules (Skeleton_Index).B) & """ then");
               L ("         for Pass in 1 .. 2 loop");
               L ("            declare");
               L ("               Include_Fallback : constant Boolean := Pass = 2;");
               L ("            begin");
               L ("               for Fallback_Depth in reverse 0 .. 8 loop");
               L ("                  if Include_Fallback or else Fallback_Depth = 8 then");
               declare
                  First_Branch : Boolean := True;
               begin
                  for Pattern_Index in 1 .. Rule_Count loop
                     if Is_Kind (Pattern_Index, "available_format")
                       and then S (Rules (Pattern_Index).B) =
                         S (Rules (Skeleton_Index).B)
                       and then not Has_Available_Format_Pattern
                         (Pattern_Index)
                     then
                        Emit_Locale_List_Test
                          (First_Branch,
                           Locale_List_For
                             (S (Rules (Pattern_Index).B),
                              S (Rules (Pattern_Index).C)));
                        L ("                     return "
                           & S (Rules (Pattern_Index).C) & ";");
                     end if;
                  end loop;
               end;
               L ("                  end if;");
               L ("                  end if;");
               L ("               end loop;");
               L ("            end;");
               L ("         end loop;");
               L ("      end if;");
            end if;
         end loop;

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
      begin
         L;
         L ("   function Digit_Text (Locale : String; Digit : Character) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         L ("      if Contains (Locale, ""-u-nu-latn"")");
         L ("        or else Contains (Locale, ""@numbers=latn"")");
         L ("      then");
         L ("         return [1 => Digit];");
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
                  L ("      " & (if First then "if" else "elsif")
                     & " Contains (Locale, ""-u-" & Key & """)");
                  L ("        or else Contains (Locale, ""@numbers="
                     & Number_System & """)");
                  L ("      then");
               end;
               Emit_Digit_Case (Index);
            end if;
         end loop;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "digits")
              and then S (Rules (Index).A) = "nu-beng"
            then
               L ("      elsif Lang = ""bn"" then");
               Emit_Digit_Case (Index);
            end if;
         end loop;
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "digits")
                 and then not Starts_With (S (Rules (Index).A), "nu-")
               then
                  L ("      " & (if First then "if" else "elsif")
                     & " Locale_In_List");
                  L ("        (Locale => Locale,");
                  L ("         List => """ & S (Rules (Index).A) & """,");
                  L ("         Include_Fallback => " & (if Pass = 1 then "False" else "True")
                     & ") then");
                  Emit_Digit_Case (Index);
               end if;
            end loop;
         end loop;
         L ("      else");
         L ("         return [1 => Digit];");
         L ("      end if;");
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
         First : Boolean := True;

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

         procedure Emit_String_Argument
           (Value  : String;
            Indent : String)
         is
            Chunk_Size : constant := 72;
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
      begin
         L;
         L ("   function " & Name & " (Locale : String; " & Index_Name & " : Natural) return String is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "name_set_hex") and then S (Rules (Index).A) = Kind then
                  L ("      " & (if First then "if" else "elsif")
                     & (if Pass = 1 then " Locale_Equals" else " Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).B) & """) then");
                  declare
                     Start : constant Natural := Decimal_Value (S (Rules (Index).C));
                     Count : constant Natural := Expr_Item_Count (S (Rules (Index).D));
                  begin
                     L ("         if " & Index_Name & " < "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last)
                        & " or else " & Index_Name & " > "
                        & Natural'Image (Start + Count - 1)
                          (2 .. Natural'Image (Start + Count - 1)'Last)
                        & " then");
                     L ("            return """";");
                     L ("         else");
                     L ("            return Hex_List_Item");
                     L ("              (");
                     Emit_String_Argument (S (Rules (Index).D), "               ");
                     L ("               " & Index_Name & " - "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last)
                        & " + 1);");
                     L ("         end if;");
                  end;
                  First := False;
               end if;
            end loop;
         end loop;
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind) then
               L ("      " & (if First then "if" else "elsif")
                  & " Lang = """ & S (Rules (Index).A) & """ and then "
                  & Index_Name & " = " & S (Rules (Index).B) & " then");
               Emit_Return (S (Rules (Index).C));
               First := False;
            end if;
         end loop;
         L ("      else");
         L ("         case " & Index_Name & " is");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Default_Kind) and then S (Rules (Index).A) = "en" then
               L ("            when " & S (Rules (Index).B) & " =>");
               Emit_Return (S (Rules (Index).C), "               ");
            end if;
         end loop;
         L ("            when others => return """";");
         L ("         end case;");
         L ("      end if;");
         L ("   end " & Name & ";");
      end Emit_Date_Name_Function;

      procedure Emit_Currency_Field
        (Name         : String;
         Field_Number : Positive;
         Return_Type  : String;
         Default_Expr : String)
      is
         First : Boolean := True;

         procedure Emit_Return (Expression : String) is
            Term_Number : Positive := 1;

            function Next_Concat (Start : Positive) return Natural is
               In_String : Boolean := False;
               Index     : Natural := Start;
            begin
               while Index <= Expression'Last loop
                  if Expression (Index) = '"' then
                     if In_String
                       and then Index < Expression'Last
                       and then Expression (Index + 1) = '"'
                     then
                        Index := Index + 2;
                     else
                        In_String := not In_String;
                        Index := Index + 1;
                     end if;
                  elsif Expression (Index) = '&' and then not In_String then
                     return Index;
                  else
                     Index := Index + 1;
                  end if;
               end loop;

               return 0;
            end Next_Concat;

            Start : Positive := Expression'First;
            Split : Natural := Next_Concat (Start);
         begin
            if Split = 0 then
               L ("         return " & Expression & ";");
               return;
            end if;

            L ("         return");
            loop
               declare
                  Current : constant String :=
                    Trim
                      (Expression
                         (Start .. (if Split = 0 then Expression'Last else Split - 1)));
               begin
                  L ("           " & (if Term_Number = 1 then "" else "& ")
                     & Current & (if Split = 0 then ";" else ""));
               end;
               exit when Split = 0;

               Start := Split + 1;
               Term_Number := Term_Number + 1;
               Split := Next_Concat (Start);
            end loop;
         end Emit_Return;
      begin
         L;
         L ("   function " & Name & " (Code : String) return " & Return_Type & " is");
         L ("   begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "currency") then
               declare
                  Value : constant String :=
                    (case Field_Number is
                       when 2 => S (Rules (Index).B),
                       when 3 => S (Rules (Index).C),
                       when 4 => S (Rules (Index).D),
                       when 5 => S (Rules (Index).E),
                       when 6 => S (Rules (Index).F),
                       when others => "");
               begin
                  if Value /= Default_Expr then
                     L ("      " & (if First then "if" else "elsif")
                        & " Code = """ & S (Rules (Index).A) & """ then");
                     Emit_Return (Value);
                     First := False;
                  end if;
               end;
            end if;
         end loop;
         L ("      else");
         L ("         return " & Default_Expr & ";");
         L ("      end if;");
         L ("   end " & Name & ";");
      end Emit_Currency_Field;

      procedure Emit_Quarter_Name is
      begin
         L;
         L ("   function Quarter_Name");
         L ("     (Locale       : String;");
         L ("      Quarter      : Natural;");
         L ("      Quarter_Text : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "name_set_hex")
                 and then S (Rules (Index).A) = "quarter"
               then
                  declare
                     Start : constant Natural := Decimal_Value (S (Rules (Index).C));
                     Count : constant Natural := Expr_Item_Count (S (Rules (Index).D));
                  begin
                     L ("      "
                        & (if Pass = 1 then "if Locale_Equals" else "if Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).B) & """)");
                     L ("        and then Quarter >= "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last));
                     L ("        and then Quarter <= "
                        & Natural'Image (Start + Count - 1)
                          (2 .. Natural'Image (Start + Count - 1)'Last));
                     L ("      then");
                     L ("         return Hex_List_Item (""" & S (Rules (Index).D)
                        & """, Quarter - "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last)
                        & " + 1);");
                     L ("      end if;");
                  end;
               end if;
            end loop;
         end loop;
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "quarter") then
                  L ("      if "
                     & (if Pass = 1 then "Locale_Equals" else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("        and then Quarter = " & S (Rules (Index).B));
                  L ("      then");
                  L ("         return " & S (Rules (Index).C) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
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
         L;
         L ("   function Quarter_Name_Short");
         L ("     (Locale       : String;");
         L ("      Quarter      : Natural;");
         L ("      Quarter_Text : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "name_set_hex")
                 and then S (Rules (Index).A) = "quarter_short"
               then
                  declare
                     Start : constant Natural := Decimal_Value (S (Rules (Index).C));
                     Count : constant Natural := Expr_Item_Count (S (Rules (Index).D));
                  begin
                     L ("      "
                        & (if Pass = 1 then "if Locale_Equals" else "if Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).B) & """)");
                     L ("        and then Quarter >= "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last));
                     L ("        and then Quarter <= "
                        & Natural'Image (Start + Count - 1)
                          (2 .. Natural'Image (Start + Count - 1)'Last));
                     L ("      then");
                     L ("         return Hex_List_Item (""" & S (Rules (Index).D)
                        & """, Quarter - "
                        & Natural'Image (Start) (2 .. Natural'Image (Start)'Last)
                        & " + 1);");
                     L ("      end if;");
                  end;
               end if;
            end loop;
         end loop;
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "quarter_short") then
                  L ("      if "
                     & (if Pass = 1 then "Locale_Equals" else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("        and then Quarter = " & S (Rules (Index).B));
                  L ("      then");
                  L ("         return " & S (Rules (Index).C) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
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
         L ("            return HB (Payload (Sep_2 + 1 .. Last));");
         L ("         end if;");
         L ("         Start := Stop + 1;");
         L ("      end loop;");
         L ("      return """";");
         L ("   end Day_Period_Payload_Value;");
         L;
         L ("   function Day_Period_Name");
         L ("     (Locale : String;");
         L ("      Period : String;");
         L ("      Wide   : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "day_period_hex") then
                  declare
                     Locale : constant String := S (Rules (Index).A);
                     Seen   : Boolean := False;
                     Payload : US.Unbounded_String;
                  begin
                     for Previous in 1 .. Index - 1 loop
                        if Is_Kind (Previous, "day_period_hex")
                          and then S (Rules (Previous).A) = Locale
                        then
                           Seen := True;
                           exit;
                        end if;
                     end loop;

                     if not Seen then
                        for Candidate in Index .. Rule_Count loop
                           if Is_Kind (Candidate, "day_period_hex")
                             and then S (Rules (Candidate).A) = Locale
                           then
                              if US.Length (Payload) > 0 then
                                 US.Append (Payload, ";");
                              end if;
                              US.Append
                                (Payload,
                                 S (Rules (Candidate).B) & ","
                                 & S (Rules (Candidate).C) & ","
                                 & S (Rules (Candidate).D));
                           end if;
                        end loop;

                        L
                          ("      if "
                           & (if Pass = 1
                              then "Locale_Equals"
                              else "Locale_Fallback_Matches")
                           & " (Locale, """ & Locale & """)");
                        L ("      then");
                        L ("         declare");
                        L ("            Value : constant String :=");
                        L ("              Day_Period_Payload_Value");
                        L ("                (""" & S (Payload)
                           & """, Period, (if Wide then ""wide"" else ""abbreviated""));");
                        L ("         begin");
                        L ("            if Value /= """" then");
                        L ("               return Value;");
                        L ("            end if;");
                        L ("         end;");
                        L ("      end if;");
                     end if;
                  end;
               elsif Is_Kind (Index, "day_period") then
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
         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := 72;
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
         L ("   function Canonical_Time_Zone (Zone : String) return String is");
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
         L ("      elsif Zone = ""GMT"" then");
         L ("         return ""GMT"";");
         for Index in 1 .. TZDB_Link_Count loop
            L ("      elsif Zone = """ & S (TZDB_Link_Names (Index)) & """ then");
            L ("         return """ & S (TZDB_Link_Targets (Index)) & """;");
         end loop;
         L ("      else");
         L ("         return Zone;");
         L ("      end if;");
         L ("   end Canonical_Time_Zone;");
         L;
         L ("   function Time_Zone_TZDB_Index (Zone : String) return Natural is");
         L ("      Canonical : constant String := Canonical_Time_Zone (Zone);");
         L ("   begin");
         L ("      if Canonical = ""UTC""");
         L ("        or else Canonical = ""Z""");
         L ("        or else Canonical = ""GMT""");
         L ("        or else Canonical = ""Etc/UTC""");
         L ("        or else Canonical = ""Etc/GMT""");
         L ("      then");
         L ("         return 0;");
         for Zone_Index in 1 .. TZDB_Zone_Count loop
            L ("      elsif Canonical = """ & S (TZDB_Zone_Names (Zone_Index)) & """ then");
            L ("         return" & Natural'Image (Zone_Index) & ";");
         end loop;
         L ("      else");
         L ("         return 0;");
         L ("      end if;");
         L ("   end Time_Zone_TZDB_Index;");
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
         declare
            Zone_Family_Display_Data : US.Unbounded_String;
            Zone_Display_Data        : US.Unbounded_String;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_family_display") then
                  US.Append
                    (Zone_Family_Display_Data,
                     S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).C)) & "~");
               elsif Is_Kind (Index, "zone_display") then
                  US.Append
                    (Zone_Display_Data,
                     S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                     & Ada_Expression_UTF8_Hex (S (Rules (Index).C)) & "~");
               end if;
            end loop;

         L ("   function Time_Zone_Display_Name");
         L ("     (Locale : String;");
         L ("      Zone   : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang   : constant String := Language (Locale);");
         L ("      Family : constant String := Time_Zone_DST_Family (Zone);");
         L ("      Family_Data : constant String :=");
         Emit_String_Expression ("        ", S (Zone_Family_Display_Data), ";");
         L ("      Zone_Data : constant String :=");
         Emit_String_Expression ("        ", S (Zone_Display_Data), ";");
         L;
         L ("      function Hex_Value (C : Character) return Natural is");
         L ("      begin");
         L ("         if C in '0' .. '9' then");
         L ("            return Character'Pos (C) - Character'Pos ('0');");
         L ("         elsif C in 'A' .. 'F' then");
         L ("            return 10 + Character'Pos (C) - Character'Pos ('A');");
         L ("         elsif C in 'a' .. 'f' then");
         L ("            return 10 + Character'Pos (C) - Character'Pos ('a');");
         L ("         else");
         L ("            return 0;");
         L ("         end if;");
         L ("      end Hex_Value;");
         L;
         L ("      function Hex_To_String (Hex : String) return String is");
         L ("         Result : String (1 .. Hex'Length / 2);");
         L ("         Out_Index : Natural := 0;");
         L ("         Index : Natural := Hex'First;");
         L ("      begin");
         L ("         while Index < Hex'Last loop");
         L ("            Out_Index := Out_Index + 1;");
         L ("            Result (Out_Index) := Character'Val");
         L ("              (Hex_Value (Hex (Index)) * 16");
         L ("               + Hex_Value (Hex (Index + 1)));");
         L ("            Index := Index + 2;");
         L ("         end loop;");
         L ("         return Result;");
         L ("      end Hex_To_String;");
         L;
         L ("      function Matches_Locale");
         L ("        (Candidate : String;");
         L ("         Fallback  : Boolean)");
         L ("         return Boolean is");
         L ("      begin");
         L ("         if Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return Locale_Equals (Locale, Candidate);");
         L ("         end if;");
         L ("      end Matches_Locale;");
         L;
         L ("      function Search_Family (Fallback : Boolean) return String is");
         L ("         Start : Positive := Family_Data'First;");
         L ("      begin");
         L ("         while Start <= Family_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Stop : Natural := Family_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Family_Data'Last loop");
         L ("                  if Family_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     end if;");
         L ("                  elsif Family_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Stop > Sep2 + 1");
         L ("                 and then Family_Data (Sep1 + 1 .. Sep2 - 1) = Family");
         L ("                 and then Matches_Locale");
         L ("                   (Family_Data (Start .. Sep1 - 1), Fallback)");
         L ("               then");
         L ("                  return Hex_To_String");
         L ("                    (Family_Data (Sep2 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search_Family;");
         L;
         L ("      function Search_Zone (Fallback : Boolean) return String is");
         L ("         Start : Positive := Zone_Data'First;");
         L ("      begin");
         L ("         while Start <= Zone_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Stop : Natural := Zone_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Zone_Data'Last loop");
         L ("                  if Zone_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     end if;");
         L ("                  elsif Zone_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Stop > Sep2 + 1");
         L ("                 and then Zone_Data (Sep1 + 1 .. Sep2 - 1) = Zone");
         L ("                 and then Matches_Locale");
         L ("                   (Zone_Data (Start .. Sep1 - 1), Fallback)");
         L ("               then");
         L ("                  return Hex_To_String");
         L ("                    (Zone_Data (Sep2 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search_Zone;");
         L;
         L ("      Exact_Family_Display : constant String := Search_Family (False);");
         L ("   begin");
         L ("      if Exact_Family_Display /= """" then");
         L ("         return Exact_Family_Display;");
         L ("      end if;");
         L ("      declare");
         L ("         Fallback_Family_Display : constant String := Search_Family (True);");
         L ("      begin");
         L ("         if Fallback_Family_Display /= """" then");
         L ("            return Fallback_Family_Display;");
         L ("         end if;");
         L ("      end;");
         L;
         L ("      declare");
         L ("         Exact_Zone_Display : constant String := Search_Zone (False);");
         L ("      begin");
         L ("         if Exact_Zone_Display /= """" then");
         L ("            return Exact_Zone_Display;");
         L ("         end if;");
         L ("      end;");
         L ("      declare");
         L ("         Fallback_Zone_Display : constant String := Search_Zone (True);");
         L ("      begin");
         L ("         if Fallback_Zone_Display /= """" then");
         L ("            return Fallback_Zone_Display;");
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
         end;
         L;
         L ("   function Time_Zone_Exemplar_Location");
         L ("     (Locale : String;");
         L ("      Zone   : String)");
         L ("      return String");
         L ("   is");
         L ("      Data : constant String :=");
         Emit_String_Expression ("        ", Zone_Exemplar_Data, ";");
         L;
         L ("      function Hex_Value (C : Character) return Natural is");
         L ("      begin");
         L ("         if C in '0' .. '9' then");
         L ("            return Character'Pos (C) - Character'Pos ('0');");
         L ("         elsif C in 'A' .. 'F' then");
         L ("            return 10 + Character'Pos (C) - Character'Pos ('A');");
         L ("         elsif C in 'a' .. 'f' then");
         L ("            return 10 + Character'Pos (C) - Character'Pos ('a');");
         L ("         else");
         L ("            return 0;");
         L ("         end if;");
         L ("      end Hex_Value;");
         L;
         L ("      function Hex_To_String (Hex : String) return String is");
         L ("         Result : String (1 .. Hex'Length / 2);");
         L ("         Out_Index : Natural := 0;");
         L ("         Index : Natural := Hex'First;");
         L ("      begin");
         L ("         while Index < Hex'Last loop");
         L ("            Out_Index := Out_Index + 1;");
         L ("            Result (Out_Index) := Character'Val");
         L ("              (Hex_Value (Hex (Index)) * 16");
         L ("               + Hex_Value (Hex (Index + 1)));");
         L ("            Index := Index + 2;");
         L ("         end loop;");
         L ("         return Result;");
         L ("      end Hex_To_String;");
         L;
         L ("      function Matches_Locale");
         L ("        (Candidate : String;");
         L ("         Fallback  : Boolean)");
         L ("         return Boolean is");
         L ("      begin");
         L ("         if Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return Locale_Equals (Locale, Candidate);");
         L ("         end if;");
         L ("      end Matches_Locale;");
         L;
         L ("      function Search (Fallback : Boolean) return String is");
         L ("         Start : Positive := Data'First;");
         L ("      begin");
         L ("         while Start <= Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Stop : Natural := Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Data'Last loop");
         L ("                  if Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     end if;");
         L ("                  elsif Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Stop > Sep2 + 1");
         L ("                 and then Data (Sep1 + 1 .. Sep2 - 1) = Zone");
         L ("                 and then Matches_Locale");
         L ("                   (Data (Start .. Sep1 - 1), Fallback)");
         L ("               then");
         L ("                  return Hex_To_String (Data (Sep2 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      Exact : constant String := Search (False);");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      else");
         L ("         return Search (True);");
         L ("      end if;");
         L ("   end Time_Zone_Exemplar_Location;");
         L;
         L ("   function Time_Zone_Short_Name");
         L ("     (Locale   : String;");
         L ("      Family   : String;");
         L ("      Daylight : Boolean)");
         L ("      return String");
         L ("   is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            declare
               Opened : Boolean := False;
            begin
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "zone_short_family") then
                     L
                       ("      "
                        & (if Opened then "elsif " else "if ")
                        & (if Pass = 1
                           then "Locale_Equals"
                           else "Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).A)
                        & """) and then Family = """
                        & S (Rules (Index).B) & """ then");
                     L ("         return (if Daylight then "
                        & S (Rules (Index).D) & " else "
                        & S (Rules (Index).C) & ");");
                     Opened := True;
                  end if;
               end loop;

               if Opened then
                  L ("      end if;");
                  L;
               end if;
            end;
         end loop;
         declare
            Opened : Boolean := False;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_short_family")
                 and then S (Rules (Index).A) = "en"
               then
                  L
                    ("      "
                     & (if Opened then "elsif " else "if ")
                     & "Family = """ & S (Rules (Index).B) & """ then");
                  L ("         return (if Daylight then "
                     & S (Rules (Index).D) & " else "
                     & S (Rules (Index).C) & ");");
                  Opened := True;
               end if;
            end loop;

            if Opened then
               L ("      end if;");
               L;
            end if;
         end;
         L ("      return """";");
         L ("   end Time_Zone_Short_Name;");
         L;
         L ("   function Time_Zone_Generic_Short_Name");
         L ("     (Locale : String;");
         L ("      Family : String)");
         L ("      return String");
         L ("   is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            declare
               Opened : Boolean := False;
            begin
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "zone_short_family") then
                     L
                       ("      "
                        & (if Opened then "elsif " else "if ")
                        & (if Pass = 1
                           then "Locale_Equals"
                           else "Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).A)
                        & """) and then Family = """
                        & S (Rules (Index).B) & """ then");
                     L ("         return " & S (Rules (Index).E) & ";");
                     Opened := True;
                  end if;
               end loop;

               if Opened then
                  L ("      end if;");
                  L;
               end if;
            end;
         end loop;
         declare
            Opened : Boolean := False;
         begin
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "zone_short_family")
                 and then S (Rules (Index).A) = "en"
               then
                  L
                    ("      "
                     & (if Opened then "elsif " else "if ")
                     & "Family = """ & S (Rules (Index).B) & """ then");
                  L ("         return " & S (Rules (Index).E) & ";");
                  Opened := True;
               end if;
            end loop;

            if Opened then
               L ("      end if;");
               L;
            end if;
         end;
         L ("      return """";");
         L ("   end Time_Zone_Generic_Short_Name;");
         L;
         L ("   function Time_Zone_Location_Pattern (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            declare
               Opened : Boolean := False;
            begin
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "zone_location_pattern") then
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
         L ("      return ""{0} Time"";");
         L ("   end Time_Zone_Location_Pattern;");
         L;
         L ("   function GMT_Offset_Prefix (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            declare
               Opened : Boolean := False;
            begin
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "zone_gmt_prefix") then
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
         L ("      return ""GMT"";");
         L ("   end GMT_Offset_Prefix;");
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

      procedure Emit_Localized_Currency_Display_Name is
         procedure Emit_String_Argument
           (Value  : String;
            Indent : String)
         is
            Chunk_Size : constant := 72;
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
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "currency_name_payload") then
                  L ("      if "
                     & (if Pass = 1 then "Locale_Equals" else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("      then");
                  L ("         declare");
                  L ("            Name : constant String := Currency_Name_From_Payload");
                  L ("              (");
                  Emit_String_Argument (S (Rules (Index).B), "               ");
                  L ("               Code, Category);");
                  L ("         begin");
                  L ("            if Name /= """" then");
                  L ("               return Name;");
                  L ("            end if;");
                  L ("         end;");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
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
         L;
         L ("   function List_Final_Separator (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "list_separator")
                 and then S (Rules (Index).B) = "standard"
                 and then S (Rules (Index).C) = "final"
               then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("      then");
                  L ("         return " & S (Rules (Index).D) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
         L;
         L ("      return "" and "";");
         L ("   end List_Final_Separator;");
      end Emit_List_Final_Separator;

      procedure Emit_List_Item_Separator is
      begin
         L;
         L ("   function List_Item_Separator (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "list_separator")
                 and then S (Rules (Index).B) = "standard"
                 and then S (Rules (Index).C) = "item"
               then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("      then");
                  L ("         return " & S (Rules (Index).D) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
         L;
         L ("      return "", "";");
         L ("   end List_Item_Separator;");
      end Emit_List_Item_Separator;

      procedure Emit_List_Pattern_Separators is
         procedure Emit_List_Pattern_Function
           (Function_Name : String;
            Family        : String;
            Part          : String;
            Fallback_Call : String)
         is
         begin
            L ("   function " & Function_Name & " (Locale : String) return String is");
            L ("   begin");
            for Pass in 1 .. 2 loop
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "list_separator")
                    and then S (Rules (Index).B) = Family
                    and then S (Rules (Index).C) = Part
                  then
                     L
                       ("      if "
                        & (if Pass = 1
                           then "Locale_Equals"
                           else "Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).A) & """)");
                     L ("      then");
                     L ("         return " & S (Rules (Index).D) & ";");
                     L ("      end if;");
                  end if;
               end loop;
            end loop;
            L;
            L ("      return " & Fallback_Call & ";");
            L ("   end " & Function_Name & ";");
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
         L;
         L ("   function Per_Unit_Separator (Locale : String) return String is");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "unit_separator")
                 and then S (Rules (Index).B) = "per"
               then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L ("      then");
                  L ("         return " & S (Rules (Index).C) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
         L;
         --  CLDR root (und) per-unit separator is "/", not English " per ". Only
         --  locales without their own unit_separator rule reach this fallback (en has
         --  an explicit " per " entry), so they must fall back to und, not en.
         L ("      return ""/"";");
         L ("   end Per_Unit_Separator;");
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

      procedure Emit_Unit_Display_Name is
         procedure Emit_String_Term (Value : String) is
            Chunk_Size : constant := 72;
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
      begin
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
         L ("      Unit_Name_Data : constant String :=");
         L ("        """"");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "unit_name") then
               Emit_String_Term
                 (S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                  & S (Rules (Index).C) & "|" & S (Rules (Index).D)
                  & "|" & Ada_Expression_UTF8_Hex (S (Rules (Index).E))
                  & "~");
            end if;
         end loop;
         L ("        ;");
         L;
         L ("      function Extended_Unit_Name return String is");
         L ("      begin");
         L ("         return """";");
         L ("      end Extended_Unit_Name;");
         L;
         L ("      function Matches_Locale");
         L ("        (Candidate : String;");
         L ("         Fallback  : Boolean;");
         L ("         Root      : Boolean)");
         L ("         return Boolean is");
         L ("      begin");
         L ("         if Root then");
         L ("            return Candidate = ""und"" or else Candidate = ""root"";");
         L ("         elsif Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return Locale_Equals (Locale, Candidate);");
         L ("         end if;");
         L ("      end Matches_Locale;");
         L;
         L ("      function Search_Unit_Name");
         L ("        (Fallback : Boolean;");
         L ("         Root     : Boolean;");
         L ("         Want     : String)");
         L ("         return String");
         L ("      is");
         L ("         Start : Positive := Unit_Name_Data'First;");
         L ("      begin");
         L ("         while Start <= Unit_Name_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Sep3 : Natural := 0;");
         L ("               Sep4 : Natural := 0;");
         L ("               Stop : Natural := Unit_Name_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Unit_Name_Data'Last loop");
         L ("                  if Unit_Name_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     elsif Sep3 = 0 then");
         L ("                        Sep3 := Index;");
         L ("                     elsif Sep4 = 0 then");
         L ("                        Sep4 := Index;");
         L ("                     end if;");
         L ("                  elsif Unit_Name_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep3 /= 0");
         L ("                 and then Sep4 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Sep3 > Sep2 + 1");
         L ("                 and then Sep4 > Sep3 + 1");
         L ("                 and then Stop > Sep4 + 1");
         L ("                 and then Unit_Name_Data (Sep1 + 1 .. Sep2 - 1) = Base");
         L ("                 and then Unit_Name_Data (Sep2 + 1 .. Sep3 - 1) = Width");
         L ("                 and then Unit_Name_Data (Sep3 + 1 .. Sep4 - 1) = Want");
         L ("                 and then Matches_Locale");
         L ("                   (Unit_Name_Data (Start .. Sep1 - 1), Fallback, Root)");
         L ("               then");
         L ("                  return HB (Unit_Name_Data (Sep4 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search_Unit_Name;");
         L;
         L ("      function Category_Row (Want : String) return String is");
         L ("         Exact : constant String := Search_Unit_Name (False, False, Want);");
         L ("      begin");
         L ("         if Exact /= """" then");
         L ("            return Exact;");
         L ("         end if;");
         L ("         return Search_Unit_Name (True, False, Want);");
         L ("      end Category_Row;");
         L;
         L ("      --  Root (und) rows carry the CLDR abbreviated forms used by any");
         L ("      --  locale that supplies no data of its own. They are the final");
         L ("      --  resort before the built-in English defaults, and only the");
         L ("      --  abbreviated (short/narrow) widths consult them -- full names");
         L ("      --  keep falling through to the English word forms.");
         L ("      function Root_Category_Row (Want : String) return String is");
         L ("      begin");
         L ("         return Search_Unit_Name (False, True, Want);");
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

      procedure Emit_Relative_Current_Name is
         Current_Data : US.Unbounded_String;

         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := 72;
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
      begin
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "relative_current") then
               US.Append
                 (Current_Data,
                  S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                  & S (Rules (Index).C) & "|"
                  & Ada_Expression_UTF8_Hex (S (Rules (Index).D)) & "~");
            end if;
         end loop;

         L;
         L ("   function Relative_Current_Name");
         L ("     (Locale : String;");
         L ("      Base   : String;");
         L ("      Width  : String)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("      Current_Data : constant String :=");
         Emit_String_Expression ("        ", S (Current_Data), ";");
         L;
         L ("      function Matches_Locale");
         L ("        (Candidate : String;");
         L ("         Fallback  : Boolean)");
         L ("         return Boolean is");
         L ("      begin");
         L ("         if Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return Locale_Equals (Locale, Candidate);");
         L ("         end if;");
         L ("      end Matches_Locale;");
         L;
         L ("      function Search");
         L ("        (Fallback     : Boolean;");
         L ("         Wanted_Width : String)");
         L ("         return String");
         L ("      is");
         L ("         Start : Positive := Current_Data'First;");
         L ("      begin");
         L ("         while Start <= Current_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Sep3 : Natural := 0;");
         L ("               Stop : Natural := Current_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Current_Data'Last loop");
         L ("                  if Current_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     elsif Sep3 = 0 then");
         L ("                        Sep3 := Index;");
         L ("                     end if;");
         L ("                  elsif Current_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep3 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Sep3 > Sep2 + 1");
         L ("                 and then Stop > Sep3 + 1");
         L ("                 and then Current_Data (Sep1 + 1 .. Sep2 - 1) = Base");
         L ("                 and then Current_Data (Sep2 + 1 .. Sep3 - 1)");
         L ("                   = Wanted_Width");
         L ("                 and then Matches_Locale");
         L ("                   (Current_Data (Start .. Sep1 - 1), Fallback)");
         L ("               then");
         L ("                  return HB (Current_Data (Sep3 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      Exact : constant String := Search (False, Width);");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L ("      if Width /= ""unit-width-full-name"" then");
         L ("         declare");
         L ("            Full_Exact : constant String :=");
         L ("              Search (False, ""unit-width-full-name"");");
         L ("         begin");
         L ("            if Full_Exact /= """" then");
         L ("               return Full_Exact;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L ("      declare");
         L ("         Fallback_Result : constant String := Search (True, Width);");
         L ("      begin");
         L ("         if Fallback_Result /= """" then");
         L ("            return Fallback_Result;");
         L ("         end if;");
         L ("      end;");
         L ("      if Width /= ""unit-width-full-name"" then");
         L ("         declare");
         L ("            Full_Fallback : constant String :=");
         L ("              Search (True, ""unit-width-full-name"");");
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
         L;
         L ("   function Relative_Offset_Prefix");
         L ("     (Locale : String;");
         L ("      Future : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "relative_offset") then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L
                    ("        and then Future = "
                     & (if S (Rules (Index).B) = "future" then "True" else "False"));
                  L ("      then");
                  L ("         return " & S (Rules (Index).C) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
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
         L;
         L ("   function Relative_Offset_Suffix");
         L ("     (Locale : String;");
         L ("      Future : Boolean)");
         L ("      return String");
         L ("   is");
         L ("      Lang : constant String := Language (Locale);");
         L ("   begin");
         for Pass in 1 .. 2 loop
            for Index in 1 .. Rule_Count loop
               if Is_Kind (Index, "relative_offset") then
                  L
                    ("      if "
                     & (if Pass = 1
                        then "Locale_Equals"
                        else "Locale_Fallback_Matches")
                     & " (Locale, """ & S (Rules (Index).A) & """)");
                  L
                    ("        and then Future = "
                     & (if S (Rules (Index).B) = "future" then "True" else "False"));
                  L ("      then");
                  L ("         return " & S (Rules (Index).D) & ";");
                  L ("      end if;");
               end if;
            end loop;
         end loop;
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

      procedure Emit_Relative_Unit_Category_Name is
      begin
         L;
         L ("   function Relative_Unit_Category_Name");
         L ("     (Locale   : String;");
         L ("      Base     : String;");
         L ("      Category : String)");
         L ("      return String");
         L ("   is");
         L ("   begin");
         for Wanted in 1 .. 2 loop
            for Pass in 1 .. 2 loop
               for Index in 1 .. Rule_Count loop
                  if Is_Kind (Index, "relative_unit_category")
                    and then
                      ((Wanted = 1 and then S (Rules (Index).C) /= "other")
                       or else
                       (Wanted = 2 and then S (Rules (Index).C) = "other"))
                  then
                     L
                       ("      if "
                        & (if Pass = 1
                           then "Locale_Equals"
                           else "Locale_Fallback_Matches")
                        & " (Locale, """ & S (Rules (Index).A) & """)");
                     L ("        and then Base = """ & S (Rules (Index).B) & """");
                     if Wanted = 1 then
                        L
                          ("        and then Category = """
                           & S (Rules (Index).C) & """");
                     end if;
                     L ("      then");
                     L ("         return " & S (Rules (Index).D) & ";");
                     L ("      end if;");
                  end if;
               end loop;
            end loop;
         end loop;
         L;
         L ("      return """";");
         L ("   end Relative_Unit_Category_Name;");
      end Emit_Relative_Unit_Category_Name;

      procedure Emit_Relative_Time_Pattern is
         Pattern_Data : US.Unbounded_String;

         procedure Emit_String_Expression
           (Indent : String;
            Value  : String;
            Suffix : String := "")
         is
            Chunk_Size : constant := 72;
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
      begin
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, "relative_time_pattern") then
               US.Append
                 (Pattern_Data,
                  S (Rules (Index).A) & "|" & S (Rules (Index).B) & "|"
                  & S (Rules (Index).C) & "|" & S (Rules (Index).D) & "|"
                  & S (Rules (Index).E) & "|"
                  & Ada_Expression_UTF8_Hex (S (Rules (Index).F)) & "~");
            end if;
         end loop;

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
         L ("      Pattern_Data : constant String :=");
         Emit_String_Expression ("        ", S (Pattern_Data), ";");
         L;
         L ("      function Matches_Locale");
         L ("        (Candidate : String;");
         L ("         Fallback  : Boolean)");
         L ("         return Boolean is");
         L ("      begin");
         L ("         if Fallback then");
         L ("            return Locale_Fallback_Matches (Locale, Candidate);");
         L ("         else");
         L ("            return Locale_Equals (Locale, Candidate);");
         L ("         end if;");
         L ("      end Matches_Locale;");
         L;
         L ("      function Search");
         L ("        (Fallback        : Boolean;");
         L ("         Wanted_Category : String)");
         L ("         return String");
         L ("      is");
         L ("         Start : Positive := Pattern_Data'First;");
         L ("      begin");
         L ("         while Start <= Pattern_Data'Last loop");
         L ("            declare");
         L ("               Sep1 : Natural := 0;");
         L ("               Sep2 : Natural := 0;");
         L ("               Sep3 : Natural := 0;");
         L ("               Sep4 : Natural := 0;");
         L ("               Sep5 : Natural := 0;");
         L ("               Stop : Natural := Pattern_Data'Last + 1;");
         L ("            begin");
         L ("               for Index in Start .. Pattern_Data'Last loop");
         L ("                  if Pattern_Data (Index) = '|' then");
         L ("                     if Sep1 = 0 then");
         L ("                        Sep1 := Index;");
         L ("                     elsif Sep2 = 0 then");
         L ("                        Sep2 := Index;");
         L ("                     elsif Sep3 = 0 then");
         L ("                        Sep3 := Index;");
         L ("                     elsif Sep4 = 0 then");
         L ("                        Sep4 := Index;");
         L ("                     elsif Sep5 = 0 then");
         L ("                        Sep5 := Index;");
         L ("                     end if;");
         L ("                  elsif Pattern_Data (Index) = '~' then");
         L ("                     Stop := Index;");
         L ("                     exit;");
         L ("                  end if;");
         L ("               end loop;");
         L;
         L ("               if Sep1 /= 0");
         L ("                 and then Sep2 /= 0");
         L ("                 and then Sep3 /= 0");
         L ("                 and then Sep4 /= 0");
         L ("                 and then Sep5 /= 0");
         L ("                 and then Sep1 > Start");
         L ("                 and then Sep2 > Sep1 + 1");
         L ("                 and then Sep3 > Sep2 + 1");
         L ("                 and then Sep4 > Sep3 + 1");
         L ("                 and then Sep5 > Sep4 + 1");
         L ("                 and then Stop > Sep5 + 1");
         L ("                 and then Pattern_Data (Sep1 + 1 .. Sep2 - 1) = Base");
         L ("                 and then Pattern_Data (Sep2 + 1 .. Sep3 - 1) = Width");
         L ("                 and then Pattern_Data (Sep3 + 1 .. Sep4 - 1) = Direction");
         L ("                 and then Pattern_Data (Sep4 + 1 .. Sep5 - 1)");
         L ("                   = Wanted_Category");
         L ("                 and then Matches_Locale");
         L ("                   (Pattern_Data (Start .. Sep1 - 1), Fallback)");
         L ("               then");
         L ("                  return HB (Pattern_Data (Sep5 + 1 .. Stop - 1));");
         L ("               end if;");
         L;
         L ("               Start := Stop + 1;");
         L ("            end;");
         L ("         end loop;");
         L;
         L ("         return """";");
         L ("      end Search;");
         L;
         L ("      Exact : constant String := Search (False, Category);");
         L ("   begin");
         L ("      if Exact /= """" then");
         L ("         return Exact;");
         L ("      end if;");
         L ("      if Category /= ""other"" then");
         L ("         declare");
         L ("            Other_Exact : constant String := Search (False, ""other"");");
         L ("         begin");
         L ("            if Other_Exact /= """" then");
         L ("               return Other_Exact;");
         L ("            end if;");
         L ("         end;");
         L ("      end if;");
         L ("      declare");
         L ("         Fallback_Result : constant String := Search (True, Category);");
         L ("      begin");
         L ("         if Fallback_Result /= """" then");
         L ("            return Fallback_Result;");
         L ("         end if;");
         L ("      end;");
         L ("      if Category /= ""other"" then");
         L ("         return Search (True, ""other"");");
         L ("      end if;");
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

      procedure Emit_Rule_Family (Name : String; Kind : String) is
         First : Boolean := True;

         procedure Emit_In_List_Branch
           (Keyword : String;
            Locales : String)
         is
            Chunk_Size : constant := 72;
            Start      : Positive := Locales'First;
            Stop       : Natural;
            Term       : Positive := 1;
         begin
            if Locales'Length <= Chunk_Size then
               L ("            " & Keyword & " Locale_In_List");
               L ("              (Locale => Locale,");
               L ("               List => """ & Locales & """,");
               L ("               Include_Fallback => Include_Fallback)");
               L ("            then");
               return;
            end if;

            L ("            " & Keyword & " Locale_In_List");
            L ("              (Locale => Locale,");
            L ("               List =>");
            while Start <= Locales'Last loop
               Stop := Natural'Min (Start + Chunk_Size - 1, Locales'Last);
               L ("                 " & (if Term = 1 then "" else "& ")
                  & """" & Locales (Start .. Stop) & """"
                  & (if Stop = Locales'Last then "," else ""));
               Start := Stop + 1;
               Term := Term + 1;
            end loop;
            L ("               Include_Fallback => Include_Fallback)");
            L ("            then");
         end Emit_In_List_Branch;
      begin
         L;
         L ("   function " & Name & " (Locale : String) return String is");
         L ("   begin");
         L ("      for Pass in 1 .. 2 loop");
         L ("         declare");
         L ("            Include_Fallback : constant Boolean := Pass = 2;");
         L ("         begin");
         for Index in 1 .. Rule_Count loop
            if Is_Kind (Index, Kind) then
               Emit_In_List_Branch
                 ((if First then "if" else "elsif"), S (Rules (Index).B));
               L ("               return """ & S (Rules (Index).A) & """;");
               First := False;
            end if;
         end loop;
         if not First then
            L ("            end if;");
         end if;
         L ("         end;");
         L ("      end loop;");
         L;
         L ("      return ""other-only"";");
         L ("   end " & Name & ";");
      end Emit_Rule_Family;

   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Current_File := Output'Unchecked_Access;
      Emit_Static_Prelude;
      Emit_Locale_Return_Function ("Decimal_Separator", "decimal", """.""");
      Emit_Locale_Return_Function ("Group_Separator", "group", """,""");
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
