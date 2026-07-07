with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.JSON;

procedure Generate_CLDR_Export is
   package US renames Ada.Strings.Unbounded;

   Target_Path : constant String := "upstream/cldr_export.jsonl";

   Errors : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   Generated_Path : constant String := "/tmp/i18n_cldr_export.generated.jsonl";

   procedure Add_Error (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Add_Error;

   function Has_Argument (Value : String) return Boolean is
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (Index) = Value then
            return True;
         end if;
      end loop;

      return False;
   end Has_Argument;

   function Source_Value (Path : String; Field : String) return String is
      Text  : constant String := Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
      Value : constant String := Project_Tools.JSON.Object_Field_Value (Text, Field);
   begin
      if Value = "" then
         Add_Error ("missing CLDR export source field " & Field & " in " & Path);
      end if;

      return Value;
   exception
      when others =>
         Add_Error ("failed to read CLDR export source " & Path);
      return "";
   end Source_Value;

   function Field
     (Line      : String;
      Number    : Positive;
      Separator : Character) return String
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

   function Field_Count (Line : String; Separator : Character) return Natural is
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

   function Contains (Text : String; Pattern : String) return Boolean is
   begin
      if Pattern'Length = 0 or else Text'Length < Pattern'Length then
         return False;
      end if;

      for Index in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

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

   function Object_Field_Object (Text : String; Field : String) return String is
      Pattern : constant String := """" & Field & """";
      Key     : Natural := 0;
      Open    : Natural := 0;
      Depth   : Natural := 0;
      Index   : Natural;
      In_Text : Boolean := False;
   begin
      if Text'Length < Pattern'Length then
         return "";
      end if;

      for Pos in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (Pos .. Pos + Pattern'Length - 1) = Pattern then
            Key := Pos;
            exit;
         end if;
      end loop;

      if Key = 0 then
         return "";
      end if;

      Index := Key + Pattern'Length;
      while Index <= Text'Last and then Text (Index) /= ':' loop
         Index := Index + 1;
      end loop;
      Index := Index + 1;

      while Index <= Text'Last loop
         if Text (Index) = '{' then
            Open := Index;
            exit;
         elsif Text (Index) not in ' ' | ASCII.HT | ASCII.CR | ASCII.LF then
            return "";
         end if;
         Index := Index + 1;
      end loop;

      if Open = 0 then
         return "";
      end if;

      Index := Open;
      while Index <= Text'Last loop
         if Text (Index) = '"' then
            In_Text := not In_Text;
         elsif not In_Text then
            if Text (Index) = '{' then
               Depth := Depth + 1;
            elsif Text (Index) = '}' then
               Depth := Depth - 1;
               if Depth = 0 then
                  return Text (Open .. Index);
               end if;
            end if;
         elsif Text (Index) = '\' then
            Index := Index + 1;
         end if;

         Index := Index + 1;
      end loop;

      return "";
   end Object_Field_Object;

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

   function Hex_4 (Value : Natural) return String is
   begin
      return
        [1 => Hex_Digit ((Value / 4096) mod 16),
         2 => Hex_Digit ((Value / 256) mod 16),
         3 => Hex_Digit ((Value / 16) mod 16),
         4 => Hex_Digit (Value mod 16)];
   end Hex_4;

   function Hex_Byte (Value : Natural) return String is
   begin
      return [1 => Hex_Digit (Value / 16), 2 => Hex_Digit (Value mod 16)];
   end Hex_Byte;

   function Hex_Bytes (Text : String) return String is
      Output : US.Unbounded_String;
   begin
      for C of Text loop
         US.Append (Output, Hex_Byte (Character'Pos (C)));
      end loop;

      return S (Output);
   end Hex_Bytes;

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

   function Codepoint_List (Text : String) return String is
      Output : US.Unbounded_String;
      Index  : Positive := Text'First;
      Count  : Natural := 0;
   begin
      while Index <= Text'Last loop
         declare
            Valid : Boolean;
            Code  : constant Natural := Decode_UTF8 (Text, Index, Valid);
         begin
            if not Valid then
               return "";
            end if;

            if Count > 0 then
               US.Append (Output, ",");
            end if;
            US.Append (Output, Hex_Image (Code));
            Count := Count + 1;
         end;
      end loop;

      if Count = 10 then
         return S (Output);
      else
         return "";
      end if;
   end Codepoint_List;

   function Codepoint_Hex_String (Text : String) return String is
      Output : US.Unbounded_String;
      Index  : Positive := Text'First;
   begin
      while Index <= Text'Last loop
         declare
            Valid : Boolean;
            Code  : constant Natural := Decode_UTF8 (Text, Index, Valid);
         begin
            if not Valid or else Code > 16#FFFF# then
               return "";
            end if;

            US.Append (Output, Hex_4 (Code));
         end;
      end loop;

      return S (Output);
   end Codepoint_Hex_String;

   function Codepoint_Hex_List (Items : String) return String is
      Output : US.Unbounded_String;
   begin
      for Index in 1 .. Field_Count (Items, '~') loop
         declare
            Item : constant String := Field (Items, Index, '~');
            Hex  : constant String := Codepoint_Hex_String (Item);
         begin
            if Hex = "" then
               return "";
            end if;

            if Index > 1 then
               US.Append (Output, "~");
            end if;
            US.Append (Output, Hex);
         end;
      end loop;

      return S (Output);
   end Codepoint_Hex_List;

   function JSON_Escape (Text : String) return String is
      Output : US.Unbounded_String;
   begin
      for C of Text loop
         if C = '"' then
            US.Append (Output, '\');
            US.Append (Output, '"');
         elsif C = '\' then
            US.Append (Output, "\\");
         elsif C = ASCII.LF then
            US.Append (Output, "\n");
         elsif C = ASCII.CR then
            US.Append (Output, "\r");
         elsif C = ASCII.HT then
            US.Append (Output, "\t");
         else
            US.Append (Output, C);
         end if;
      end loop;

      return S (Output);
   end JSON_Escape;

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

   function Generate return String is
      Output : Ada.Text_IO.File_Type;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Output, Text);
      end L;

      procedure Emit_JSON (Text : String) renames L;

      procedure Emit_Header is
      begin
         L ("# Deterministic CLDR upstream export fixture for the built-in subset.");
         L ("# Generated by cldr/src/generate_cldr_export.adb from cldr-json source fragments.");
      end Emit_Header;

      procedure Emit_Migrated_Number_Rows is
      begin
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""decimal"",""locales"":""ar"",""value"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/ar/numbers.json", "decimalSymbol")
            & """}");
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""decimal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/cs/numbers.json", "decimalLocales")
            & """,""value"":"",""}");
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""group"",""locales"":""ar"",""value"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/ar/numbers.json", "groupSymbol")
            & """}");
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""group"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/de/numbers.json", "groupLocales")
            & """,""value"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/de/numbers.json", "groupSymbol")
            & """}");
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""group"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/fr/numbers.json", "groupLocales")
            & """,""value"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/fr/numbers.json", "groupSymbol")
            & """}");
         Emit_JSON
           ("{""type"":""symbol"",""kind"":""group"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/cs/numbers.json", "groupLocales")
            & """,""value"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/cs/numbers.json", "groupSymbol")
            & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""indian_grouping"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/hi/numbers.json", "indianGroupingLocales")
            & """,""suffix"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/hi/numbers.json", "indianGroupingSuffix")
            & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""day_month_year"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-dates-modern/main/en/ca-gregorian.json", "dayMonthYearLocales")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""ar"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/ar/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""fa"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/fa/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""th"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/th/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""nu-arabext"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/fa/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""nu-arab"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/ar/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""nu-thai"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/th/numbers.json", "digits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""nu-deva"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/numberingSystems.json",
                 "devaDigits")
            & """}");
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""nu-beng"",""digits"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/numberingSystems.json",
                 "bengDigits")
            & """}");
      end Emit_Migrated_Number_Rows;

      procedure Emit_Full_Number_Rows is
         Root              : constant String := "upstream/cldr-json/cldr-numbers-full/main";
         Numbering_Source  : constant String :=
           Project_Tools.Files.Read_Raw_File
             ("upstream/cldr-json/cldr-core/supplemental/numberingSystems.json");
         Numbering_Root    : constant String :=
           Object_Field_Object (Numbering_Source, "numberingSystems");
         Max_Locales       : constant := 1_000;
         Locales           : array (1 .. Max_Locales) of US.Unbounded_String;
         Locale_Count      : Natural := 0;

         procedure Add_Locale (Locale : String) is
            Insert : Positive := 1;
         begin
            if Locale_Count = Max_Locales then
               Add_Error ("too many CLDR number locale directories");
               return;
            end if;

            while Insert <= Locale_Count and then S (Locales (Insert)) < Locale loop
               Insert := Insert + 1;
            end loop;

            for Index in reverse Insert .. Locale_Count loop
               Locales (Index + 1) := Locales (Index);
            end loop;

            Locale_Count := Locale_Count + 1;
            Locales (Insert) := US.To_Unbounded_String (Locale);
         end Add_Locale;

         function Numbering_Digits (System : String) return String is
            Object : constant String := Object_Field_Object (Numbering_Source, System);
            Digit_Text : constant String :=
              Project_Tools.JSON.Object_Field_Value (Object, "_digits");
         begin
            if Digit_Text = "" then
               return "";
            else
               return Codepoint_List (Digit_Text);
            end if;
         end Numbering_Digits;

         procedure Emit_Numeric_Numbering_System_Rows is
            Max_Systems : constant := 128;
            Names       : array (1 .. Max_Systems) of US.Unbounded_String;
            Codes       : array (1 .. Max_Systems) of US.Unbounded_String;
            Count       : Natural := 0;
            Index : Natural := Numbering_Root'First;

            procedure Add_System (System : String; Digit_Codes : String) is
               Insert : Positive := 1;
            begin
               if Count = Max_Systems then
                  Add_Error ("too many CLDR numeric numbering systems");
                  return;
               end if;

               while Insert <= Count loop
                  declare
                     Existing : constant String := S (Names (Insert));
                  begin
                     exit when System'Length > Existing'Length
                       or else (System'Length = Existing'Length
                                and then System < Existing);
                  end;
                  Insert := Insert + 1;
               end loop;

               for Position in reverse Insert .. Count loop
                  Names (Position + 1) := Names (Position);
                  Codes (Position + 1) := Codes (Position);
               end loop;

               Count := Count + 1;
               Names (Insert) := US.To_Unbounded_String (System);
               Codes (Insert) := US.To_Unbounded_String (Digit_Codes);
            end Add_System;
         begin
            while Index <= Numbering_Root'Last loop
               if Numbering_Root (Index) = '"' then
                  declare
                     Name_First : constant Natural := Index + 1;
                     Name_Last  : Natural := Name_First;
                  begin
                     while Name_Last <= Numbering_Root'Last
                       and then Numbering_Root (Name_Last) /= '"'
                     loop
                        Name_Last := Name_Last + 1;
                     end loop;

                     if Name_Last <= Numbering_Root'Last then
                        declare
                           System : constant String :=
                             Numbering_Root (Name_First .. Name_Last - 1);
                           Colon_Pos : Natural := Name_Last + 1;
                           Object_Pos : Natural := 0;
                           Digit_Codes : constant String := Numbering_Digits (System);
                        begin
                           while Colon_Pos <= Numbering_Root'Last
                             and then Numbering_Root (Colon_Pos) /= ':'
                           loop
                              if Numbering_Root (Colon_Pos)
                                not in ' ' | ASCII.HT | ASCII.CR | ASCII.LF
                              then
                                 exit;
                              end if;
                              Colon_Pos := Colon_Pos + 1;
                           end loop;

                           if Colon_Pos <= Numbering_Root'Last
                             and then Numbering_Root (Colon_Pos) = ':'
                           then
                              Object_Pos := Colon_Pos + 1;
                              while Object_Pos <= Numbering_Root'Last
                                and then Numbering_Root (Object_Pos)
                                  in ' ' | ASCII.HT | ASCII.CR | ASCII.LF
                              loop
                                 Object_Pos := Object_Pos + 1;
                              end loop;
                           end if;

                           if Object_Pos /= 0
                             and then Object_Pos <= Numbering_Root'Last
                             and then Numbering_Root (Object_Pos) = '{'
                             and then System /= "latn"
                             and then Digit_Codes /= ""
                           then
                              Add_System (System, Digit_Codes);
                           end if;
                        end;

                        Index := Name_Last + 1;
                     else
                        Index := Index + 1;
                     end if;
                  end;
               else
                  Index := Index + 1;
               end if;
            end loop;

            for Position in 1 .. Count loop
               Emit_JSON
                 ("{""type"":""numbering_system"",""locale"":""nu-"
                  & S (Names (Position)) & """,""digits"":"""
                  & S (Codes (Position)) & """}");
            end loop;
         end Emit_Numeric_Numbering_System_Rows;

         procedure Load_Locales is
            Search : Ada.Directories.Search_Type;
            Dir_Entry  : Ada.Directories.Directory_Entry_Type;
            Filter : constant Ada.Directories.Filter_Type :=
              [Ada.Directories.Ordinary_File => False,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False];
         begin
            if not Project_Tools.Files.Directory_Exists (Root) then
               Add_Error ("missing CLDR full number source directory");
               return;
            end if;

            Ada.Directories.Start_Search (Search, Root, "*", Filter);
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Locale : constant String := Ada.Directories.Simple_Name (Dir_Entry);
                  Path   : constant String :=
                    Root & "/" & Locale & "/numbers.json";
               begin
                  if Locale /= "." and then Locale /= ".."
                    and then Project_Tools.Files.File_Exists (Path)
                  then
                     Add_Locale (Locale);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         end Load_Locales;
      begin
         Load_Locales;

         for Index in 1 .. Locale_Count loop
            declare
               Locale      : constant String := S (Locales (Index));
               Path        : constant String :=
                 "cldr-json/cldr-numbers-full/main/" & Locale & "/numbers.json";
               Text        : constant String := Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
               Raw_System  : constant String :=
                 Project_Tools.JSON.Field_Value (Text, "defaultNumberingSystem");
               System      : constant String :=
                 (if Locale = "ar" then "arab" else Raw_System);
               Symbols     : constant String :=
                 Object_Field_Object (Text, "symbols-numberSystem-" & System);
               Decimal     : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Symbols, "decimal");
               Group       : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Symbols, "group");
               Digit_Codes : constant String :=
                 (if System = "latn" then "" else Numbering_Digits (System));
            begin
               if System = "" or else Symbols = "" or else Decimal = "" or else Group = "" then
                  Add_Error ("missing CLDR number symbols for locale " & Locale);
               else
                  Emit_JSON
                    ("{""type"":""symbol"",""kind"":""decimal"",""locales"":"""
                     & Locale & """,""value"":""" & Decimal & """}");
                  Emit_JSON
                    ("{""type"":""symbol"",""kind"":""group"",""locales"":"""
                     & Locale & """,""value"":""" & Group & """}");

                  if System /= "latn" then
                     if Digit_Codes = "" then
                        Add_Error
                          ("missing numeric digit data for numbering system "
                           & System & " in locale " & Locale);
                     else
                        Emit_JSON
                          ("{""type"":""numbering_system"",""locale"":"""
                           & Locale & """,""digits"":""" & Digit_Codes & """}");
                     end if;
                  end if;
               end if;
            exception
               when others =>
                  Add_Error ("failed to import CLDR number source " & Locale);
            end;
         end loop;

         Emit_Numeric_Numbering_System_Rows;
         Emit_JSON
           ("{""type"":""numbering_system"",""locale"":""th"",""digits"":"""
            & Numbering_Digits ("thai") & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""indian_grouping"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/hi/numbers.json", "indianGroupingLocales")
            & """,""suffix"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/hi/numbers.json", "indianGroupingSuffix")
            & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""day_month_year"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-dates-modern/main/en/ca-gregorian.json", "dayMonthYearLocales")
            & """}");
      end Emit_Full_Number_Rows;

      procedure Emit_Full_Currency_Name_Rows is
         Root           : constant String := "upstream/cldr-json/cldr-numbers-full/main";
         Currency_Rows  : constant String :=
           Source_Value ("cldr-json/cldr-core/supplemental/currencyData.json", "currencyRows");
         Max_Locales    : constant := 1_000;
         Locales        : array (1 .. Max_Locales) of US.Unbounded_String;
         Payloads       : array (1 .. Max_Locales) of US.Unbounded_String;
         Payload_Loaded : array (1 .. Max_Locales) of Boolean := [others => False];
         Locale_Count   : Natural := 0;

         procedure Add_Locale (Locale : String) is
            Insert : Positive := 1;
         begin
            if Locale_Count = Max_Locales then
               Add_Error ("too many CLDR currency locale directories");
               return;
            end if;

            while Insert <= Locale_Count and then S (Locales (Insert)) < Locale loop
               Insert := Insert + 1;
            end loop;

            for Index in reverse Insert .. Locale_Count loop
               Locales (Index + 1) := Locales (Index);
            end loop;

            Locale_Count := Locale_Count + 1;
            Locales (Insert) := US.To_Unbounded_String (Locale);
         end Add_Locale;

         procedure Load_Locales is
            Search    : Ada.Directories.Search_Type;
            Dir_Entry : Ada.Directories.Directory_Entry_Type;
            Filter    : constant Ada.Directories.Filter_Type :=
              [Ada.Directories.Ordinary_File => False,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False];
         begin
            if not Project_Tools.Files.Directory_Exists (Root) then
               Add_Error ("missing CLDR full currency source directory");
               return;
            end if;

            Ada.Directories.Start_Search (Search, Root, "*", Filter);
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Locale : constant String := Ada.Directories.Simple_Name (Dir_Entry);
                  Path   : constant String :=
                    Root & "/" & Locale & "/currencies.json";
               begin
                  if Locale /= "." and then Locale /= ".."
                    and then Project_Tools.Files.File_Exists (Path)
                  then
                     Add_Locale (Locale);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         end Load_Locales;

         function Currency_Payload (Locale : String) return String is
            Path    : constant String :=
              "cldr-json/cldr-numbers-full/main/" & Locale & "/currencies.json";
            Text    : constant String := Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
            Payload : US.Unbounded_String;
         begin
            for Code_Index in 1 .. Field_Count (Currency_Rows, ';') loop
               declare
                  Row    : constant String := Field (Currency_Rows, Code_Index, ';');
                  Code   : constant String := Field (Row, 1, ',');
                  Object : constant String := Object_Field_Object (Text, Code);
                  Base   : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Object, "displayName");
                  Zero   : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-zero");
                  One    : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-one");
                  Two    : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-two");
                  Few    : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-few");
                  Many   : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-many");
                  Other  : constant String :=
                    Project_Tools.JSON.Object_Field_Value
                      (Object, "displayName-count-other");
                  Fallback   : constant String := (if Other = "" then Base else Other);
                  Zero_Name  : constant String := (if Zero = "" then Fallback else Zero);
                  One_Name   : constant String := (if One = "" then Fallback else One);
                  Two_Name   : constant String := (if Two = "" then Fallback else Two);
                  Few_Name   : constant String := (if Few = "" then Fallback else Few);
                  Many_Name  : constant String := (if Many = "" then Fallback else Many);
                  Other_Name : constant String := Fallback;
               begin
                  if Fallback /= "" then
                     if US.Length (Payload) > 0 then
                        US.Append (Payload, ";");
                     end if;
                     US.Append
                       (Payload,
                        Code & ":" & Hex_Bytes (Zero_Name) & ","
                        & Hex_Bytes (One_Name) & ","
                        & Hex_Bytes (Two_Name) & ","
                        & Hex_Bytes (Few_Name) & ","
                        & Hex_Bytes (Many_Name) & ","
                        & Hex_Bytes (Other_Name));
                  end if;
               end;
            end loop;

            return S (Payload);
         end Currency_Payload;

         function Locale_Index (Locale : String) return Natural is
         begin
            for Index in 1 .. Locale_Count loop
               if S (Locales (Index)) = Locale then
                  return Index;
               end if;
            end loop;

            return 0;
         end Locale_Index;

         procedure Load_Payload (Index : Positive) is
         begin
            if not Payload_Loaded (Index) then
               Payloads (Index) := US.To_Unbounded_String (Currency_Payload (S (Locales (Index))));
               Payload_Loaded (Index) := True;
            end if;
         end Load_Payload;

         function Parent_Payload (Locale : String) return String is
            Last : Natural := Locale'Last;
         begin
            loop
               declare
                  Dash : Natural := 0;
               begin
                  for Index in reverse Locale'First .. Last loop
                     if Locale (Index) = '-' then
                        Dash := Index;
                        exit;
                     end if;
                  end loop;

                  exit when Dash = 0;
                  Last := Dash - 1;

                  declare
                     Candidate : constant String := Locale (Locale'First .. Last);
                     Candidate_Index : constant Natural := Locale_Index (Candidate);
                  begin
                     if Candidate_Index > 0 then
                        Load_Payload (Candidate_Index);
                        if S (Payloads (Candidate_Index)) /= "" then
                           return S (Payloads (Candidate_Index));
                        end if;
                     end if;
                  end;
               end;
            end loop;

            if Locale /= "en" then
               declare
                  English_Index : constant Natural := Locale_Index ("en");
               begin
                  if English_Index > 0 then
                     Load_Payload (English_Index);
                     return S (Payloads (English_Index));
                  end if;
               end;
            end if;

            return "";
         end Parent_Payload;
      begin
         Load_Locales;

         for Index in 1 .. Locale_Count loop
            declare
               Locale : constant String := S (Locales (Index));
            begin
               Load_Payload (Index);
               declare
                  Payload_Text : constant String := S (Payloads (Index));
               begin
                  if Payload_Text /= ""
                    and then (Locale = "en" or else Payload_Text /= Parent_Payload (Locale))
                  then
                     Emit_JSON
                       ("{""type"":""currency_name_payload"",""locale"":"""
                        & Locale & """,""payload"":""" & Payload_Text & """}");
                  end if;
               end;
            exception
               when others =>
                  Add_Error ("failed to import CLDR currency display names for " & Locale);
            end;
         end loop;
      end Emit_Full_Currency_Name_Rows;

      procedure Emit_Migrated_Supplemental_Rows is
         procedure Emit_Plural_Family
           (Kind   : String;
            Family : String;
            Path   : String;
            Field  : String)
         is
         begin
            Emit_JSON
              ("{""type"":""plural_family"",""kind"":""" & Kind
               & """,""family"":""" & Family
               & """,""locales"":"""
               & Source_Value (Path, Field)
               & """}");
         end Emit_Plural_Family;
      begin
         Emit_JSON
           ("{""type"":""policy"",""name"":""symbol_first"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-numbers-modern/main/ar/numbers.json", "symbolFirstLocales")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""n-is-1"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalNOneIs1")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""one-is-1"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalIOneVZero")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""one-is-0-or-1"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalNZeroOrOne")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""i-0-or-n-1"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalIZeroOrNOne")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""n-one-two"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalNOneTwo")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""n-is-1-compact-many"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalNOneCompactMany")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""i-0-1-compact-many"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalI01CompactMany")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""i-0-to-1-compact-many"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalI0To1CompactMany")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""i-1-v0-compact-many"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalI1V0CompactMany")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""ru"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalRu")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""pl"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalPl")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""cs"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalCs")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""ar"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalAr")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""ro"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalRo")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""lt"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalLt")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""sl"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalSl")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""sr"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalSr")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""cy"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalCy")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""cardinal"",""family"":""zero-one"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/plurals.json", "cardinalKsh")
            & """}");
         Emit_Plural_Family
           ("cardinal", "ceb", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalCeb");
         Emit_Plural_Family
           ("cardinal", "ff", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalFf");
         Emit_Plural_Family
           ("cardinal", "dsb", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalDsb");
         Emit_Plural_Family
           ("cardinal", "lv", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalLv");
         Emit_Plural_Family
           ("cardinal", "be", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalBe");
         Emit_Plural_Family
           ("cardinal", "br", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalBr");
         Emit_Plural_Family
           ("cardinal", "da", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalDa");
         Emit_Plural_Family
           ("cardinal", "ga", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalGa");
         Emit_Plural_Family
           ("cardinal", "gd", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalGd");
         Emit_Plural_Family
           ("cardinal", "gv", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalGv");
         Emit_Plural_Family
           ("cardinal", "he", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalHe");
         Emit_Plural_Family
           ("cardinal", "is", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalIs");
         Emit_Plural_Family
           ("cardinal", "kw", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalKw");
         Emit_Plural_Family
           ("cardinal", "lag", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalLag");
         Emit_Plural_Family
           ("cardinal", "mk", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalMk");
         Emit_Plural_Family
           ("cardinal", "mt", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalMt");
         Emit_Plural_Family
           ("cardinal", "shi", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalShi");
         Emit_Plural_Family
           ("cardinal", "si", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalSi");
         Emit_Plural_Family
           ("cardinal", "tzm", "cldr-json/cldr-core/supplemental/plurals.json",
            "cardinalTzm");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""ordinal"",""family"":""en-ordinal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/ordinals.json", "ordinalEn")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""ordinal"",""family"":""n-one-ordinal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/ordinals.json", "ordinalNOne")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""ordinal"",""family"":""it-ordinal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/ordinals.json", "ordinalItalianMany")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""ordinal"",""family"":""indic-ordinal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/ordinals.json", "ordinalIndic")
            & """}");
         Emit_JSON
           ("{""type"":""plural_family"",""kind"":""ordinal"",""family"":""hi-ordinal"",""locales"":"""
            & Source_Value
                ("cldr-json/cldr-core/supplemental/ordinals.json", "ordinalHi")
            & """}");
         Emit_Plural_Family
           ("ordinal", "az-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalAz");
         Emit_Plural_Family
           ("ordinal", "be-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalBe");
         Emit_Plural_Family
           ("ordinal", "blo-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalBlo");
         Emit_Plural_Family
           ("ordinal", "ca-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalCa");
         Emit_Plural_Family
           ("ordinal", "cy-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalCy");
         Emit_Plural_Family
           ("ordinal", "gd-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalGd");
         Emit_Plural_Family
           ("ordinal", "hu-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalHu");
         Emit_Plural_Family
           ("ordinal", "ka-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalKa");
         Emit_Plural_Family
           ("ordinal", "kk-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalKk");
         Emit_Plural_Family
           ("ordinal", "kw-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalKw");
         Emit_Plural_Family
           ("ordinal", "lij-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalLij");
         Emit_Plural_Family
           ("ordinal", "mk-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalMk");
         Emit_Plural_Family
           ("ordinal", "mr-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalMr");
         Emit_Plural_Family
           ("ordinal", "ne-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalNe");
         Emit_Plural_Family
           ("ordinal", "or-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalOr");
         Emit_Plural_Family
           ("ordinal", "sq-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalSq");
         Emit_Plural_Family
           ("ordinal", "sv-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalSv");
         Emit_Plural_Family
           ("ordinal", "tk-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalTk");
         Emit_Plural_Family
           ("ordinal", "uk-ordinal", "cldr-json/cldr-core/supplemental/ordinals.json",
            "ordinalUk");
      end Emit_Migrated_Supplemental_Rows;

      procedure Emit_Migrated_Currency_Rows is
         Rows : constant String :=
           Source_Value
             ("cldr-json/cldr-core/supplemental/currencyData.json", "currencyRows");

         function Display_Name (Code : String; Fallback : String) return String is
         begin
            if Code = "CLP" then
               return "Chilean pesos";
            elsif Code = "COP" then
               return "Colombian pesos";
            elsif Code = "ISK" then
               return "Icelandic kronur";
            elsif Code = "MGA" then
               return "Malagasy ariary";
            elsif Code = "PYG" then
               return "Paraguayan guarani";
            elsif Code = "RWF" then
               return "Rwandan francs";
            elsif Code = "UGX" then
               return "Ugandan shillings";
            elsif Code = "UYI" then
               return "Uruguayan indexed units";
            elsif Code = "VND" then
               return "Vietnamese dong";
            elsif Code = "XAF" then
               return "Central African CFA francs";
            elsif Code = "XOF" then
               return "West African CFA francs";
            elsif Code = "XPF" then
               return "CFP francs";
            elsif Code = "BHD" then
               return "Bahraini dinars";
            elsif Code = "JOD" then
               return "Jordanian dinars";
            elsif Code = "LYD" then
               return "Libyan dinars";
            elsif Code = "OMR" then
               return "Omani rials";
            elsif Code = "TND" then
               return "Tunisian dinars";
            elsif Code = "CLF" then
               return "Chilean units of account";
            elsif Code = "HUF" then
               return "Hungarian forints";
            else
               return Fallback;
            end if;
         end Display_Name;
      begin
         for Index in 1 .. Field_Count (Rows, ';') loop
            declare
               Row    : constant String := Field (Rows, Index, ';');
               Code   : constant String := Field (Row, 1, ',');
               Units  : constant String := Field (Row, 2, ',');
               Cash   : constant String := Field (Row, 3, ',');
               Symbol : constant String := Field (Row, 4, ',');
               Narrow : constant String := Field (Row, 5, ',');
               Name   : constant String := Field (Row, 6, ',');
            begin
               if Field_Count (Row, ',') /= 6 then
                  Add_Error ("invalid currency row in CLDR source: " & Row);
               else
                  Emit_JSON
                    ("{""type"":""currency"",""code"":""" & Code
                     & """,""digits"":""" & Units
                     & """,""cash"":""" & Cash
                     & """,""symbol"":""" & Symbol
                     & """,""narrow"":""" & Narrow
                     & """,""name"":""" & Display_Name (Code, Name) & """}");
               end if;
            end;
         end loop;
      end Emit_Migrated_Currency_Rows;

      procedure Emit_Migrated_Date_Name_Rows is
         Date_Root      : constant String :=
           "upstream/cldr-json/cldr-dates-full/main";
         Max_Locales    : constant := 1_000;
         Date_Locales   : array (1 .. Max_Locales) of US.Unbounded_String;
         Date_Count     : Natural := 0;

         procedure Add_Date_Locale (Locale : String) is
            Insert : Positive := 1;
         begin
            if Date_Count = Max_Locales then
               Add_Error ("too many CLDR date locale directories");
               return;
            end if;

            while Insert <= Date_Count and then S (Date_Locales (Insert)) < Locale loop
               Insert := Insert + 1;
            end loop;

            for Index in reverse Insert .. Date_Count loop
               Date_Locales (Index + 1) := Date_Locales (Index);
            end loop;

            Date_Count := Date_Count + 1;
            Date_Locales (Insert) := US.To_Unbounded_String (Locale);
         end Add_Date_Locale;

         procedure Load_Date_Locales is
            Search    : Ada.Directories.Search_Type;
            Dir_Entry : Ada.Directories.Directory_Entry_Type;
            Filter    : constant Ada.Directories.Filter_Type :=
              [Ada.Directories.Ordinary_File => False,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False];
         begin
            if not Project_Tools.Files.Directory_Exists (Date_Root) then
               Add_Error ("missing CLDR date source directory");
               return;
            end if;

            Ada.Directories.Start_Search (Search, Date_Root, "*", Filter);
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Locale : constant String := Ada.Directories.Simple_Name (Dir_Entry);
                  Path   : constant String :=
                    Date_Root & "/" & Locale & "/ca-gregorian.json";
               begin
                  if Locale /= "." and then Locale /= ".."
                    and then Project_Tools.Files.File_Exists (Path)
                  then
                     Add_Date_Locale (Locale);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         end Load_Date_Locales;

         function Date_Source_Path (Locale : String) return String is
         begin
            return "cldr-json/cldr-dates-full/main/" & Locale & "/ca-gregorian.json";
         end Date_Source_Path;

         function Date_Fields_Source_Path (Locale : String) return String is
         begin
            return "cldr-json/cldr-dates-full/main/" & Locale & "/dateFields.json";
         end Date_Fields_Source_Path;

         function Time_Zone_Source_Path (Locale : String) return String is
         begin
            return "cldr-json/cldr-dates-full/main/" & Locale & "/timeZoneNames.json";
         end Time_Zone_Source_Path;

         function Gregorian_Object (Locale : String) return String is
            Path      : constant String := Date_Source_Path (Locale);
            Text      : constant String :=
              Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
            Main      : constant String := Object_Field_Object (Text, "main");
            Locale_Obj : constant String := Object_Field_Object (Main, Locale);
            Dates     : constant String := Object_Field_Object (Locale_Obj, "dates");
            Calendars : constant String := Object_Field_Object (Dates, "calendars");
            Gregorian : constant String := Object_Field_Object (Calendars, "gregorian");
         begin
            if Gregorian = "" then
               Add_Error ("missing CLDR gregorian date data for locale " & Locale);
            end if;

            return Gregorian;
         exception
            when others =>
               Add_Error ("failed to read CLDR full date source " & Path);
               return "";
         end Gregorian_Object;

         function Date_Fields_Object (Locale : String) return String is
            Path      : constant String := Date_Fields_Source_Path (Locale);
            Text      : constant String :=
              Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
            Main      : constant String := Object_Field_Object (Text, "main");
            Locale_Obj : constant String := Object_Field_Object (Main, Locale);
            Dates     : constant String := Object_Field_Object (Locale_Obj, "dates");
            Fields    : constant String := Object_Field_Object (Dates, "fields");
         begin
            if Fields = "" then
               Add_Error ("missing CLDR date-field data for locale " & Locale);
            end if;

            return Fields;
         exception
            when others =>
               Add_Error ("failed to read CLDR date-field source " & Path);
               return "";
         end Date_Fields_Object;

         function Time_Zone_Names_Object (Locale : String) return String is
            Path      : constant String := Time_Zone_Source_Path (Locale);
            Text      : constant String :=
              Project_Tools.Files.Read_Raw_File ("upstream/" & Path);
            Main      : constant String := Object_Field_Object (Text, "main");
            Locale_Obj : constant String := Object_Field_Object (Main, Locale);
            Dates     : constant String := Object_Field_Object (Locale_Obj, "dates");
            Names     : constant String := Object_Field_Object (Dates, "timeZoneNames");
         begin
            if Names = "" then
               Add_Error ("missing CLDR time-zone names data for locale " & Locale);
            end if;

            return Names;
         exception
            when others =>
               Add_Error ("failed to read CLDR time-zone source " & Path);
               return "";
         end Time_Zone_Names_Object;

         function Parent_Locale (Locale : String) return String is
         begin
            for Index in reverse Locale'Range loop
               if Locale (Index) = '-' then
                  if Index = Locale'First then
                     return "";
                  else
                     return Locale (Locale'First .. Index - 1);
                  end if;
               end if;
            end loop;

            return "";
         end Parent_Locale;

         function Available_Formats_Object (Locale : String) return String is
            Gregorian : constant String := Gregorian_Object (Locale);
            Date_Time : constant String :=
              Object_Field_Object (Gregorian, "dateTimeFormats");
            Available : constant String :=
              Object_Field_Object (Date_Time, "availableFormats");
         begin
            if Available = "" then
               Add_Error ("missing CLDR availableFormats for locale " & Locale);
            end if;

            return Available;
         end Available_Formats_Object;

         function Prefix_Before_Placeholder (Pattern : String) return String is
            Marker : constant String := "{0}";
         begin
            if Pattern'Length < Marker'Length then
               return "";
            end if;

            for Index in Pattern'First .. Pattern'Last - Marker'Length + 1 loop
               if Pattern (Index .. Index + Marker'Length - 1) = Marker then
                  if Index + Marker'Length - 1 = Pattern'Last then
                     if Index = Pattern'First then
                        return "";
                     else
                        return Pattern (Pattern'First .. Index - 1);
                     end if;
                  else
                     return "";
                  end if;
               end if;
            end loop;

            return "";
         end Prefix_Before_Placeholder;

         function Hour_Separator (Pattern : String) return String is
            First_H : Natural := 0;
            Last_H  : Natural := 0;
            First_M : Natural := 0;
         begin
            for Index in Pattern'Range loop
               if Pattern (Index) = 'H' then
                  if First_H = 0 then
                     First_H := Index;
                  end if;
                  Last_H := Index;
               elsif First_H /= 0 and then Pattern (Index) = 'm' then
                  First_M := Index;
                  exit;
               elsif First_H /= 0 and then Pattern (Index) = ';' then
                  exit;
               end if;
            end loop;

            if First_H = 0 or else Last_H = 0 or else First_M = 0 then
               return "";
            elsif First_M = Last_H + 1 then
               return "";
            else
               return Pattern (Last_H + 1 .. First_M - 1);
            end if;
         end Hour_Separator;

         Literal_Quote : constant Character := Character'Val (39);

         function Is_Supported_Field (C : Character) return Boolean is
         begin
            case C is
               when 'G' | 'y' | 'Y' | 'u' | 'U' | 'r' | 'Q' | 'q'
                  | 'M' | 'L' | 'l' | 'w' | 'W' | 'd' | 'D' | 'F'
                  | 'g' | 'E' | 'e' | 'c' | 'a' | 'b' | 'B' | 'h'
                  | 'H' | 'K' | 'k' | 'j' | 'J' | 'C' | 'm' | 's'
                  | 'S' | 'A' | 'n' | 'N' | 'z' | 'Z' | 'O' | 'v'
                  | 'V' | 'X' | 'x' =>
                  return True;
               when others =>
                  return False;
            end case;
         end Is_Supported_Field;

         function Is_ASCII_Letter (C : Character) return Boolean is
         begin
            return C in 'A' .. 'Z' or else C in 'a' .. 'z';
         end Is_ASCII_Letter;

         function Is_Exported_Available_Skeleton (Skeleton : String) return Boolean is
         begin
            return Skeleton = "yMd"
              or else Skeleton = "yMEd"
              or else Skeleton = "yMMMd"
              or else Skeleton = "yMMMEd"
              or else Skeleton = "Gy"
              or else Skeleton = "GyMd"
              or else Skeleton = "GyMMMd"
              or else Skeleton = "GyMMMEd"
              or else Skeleton = "Md"
              or else Skeleton = "MEd"
              or else Skeleton = "MMMd"
              or else Skeleton = "MMMEd"
              or else Skeleton = "MMMMd"
              or else Skeleton = "Ed"
              or else Skeleton = "Hm"
              or else Skeleton = "Hms"
              or else Skeleton = "Hmv"
              or else Skeleton = "Hmsv"
              or else Skeleton = "hm"
              or else Skeleton = "hms"
              or else Skeleton = "hmv"
              or else Skeleton = "hmsv"
              or else Skeleton = "Bhm"
              or else Skeleton = "Bhms"
              or else Skeleton = "EBhm"
              or else Skeleton = "EBhms"
              or else Skeleton = "ms";
         end Is_Exported_Available_Skeleton;

         function Internal_Pattern (Pattern : String) return String is
            Output      : US.Unbounded_String;
            Literal_Run : US.Unbounded_String;
            Index       : Natural := Pattern'First;

            procedure Flush_Literal is
            begin
               if US.Length (Literal_Run) > 0 then
                  US.Append (Output, "'");
                  US.Append (Output, S (Literal_Run));
                  US.Append (Output, "'");
                  Literal_Run := US.Null_Unbounded_String;
               end if;
            end Flush_Literal;
         begin
            while Index <= Pattern'Last loop
               declare
                  C : constant Character := Pattern (Index);
               begin
                  if C = Literal_Quote then
                     Index := Index + 1;
                     if Index <= Pattern'Last and then Pattern (Index) = Literal_Quote then
                        US.Append (Literal_Run, Literal_Quote);
                        Index := Index + 1;
                     else
                        while Index <= Pattern'Last loop
                           if Pattern (Index) = Literal_Quote then
                              if Index < Pattern'Last
                             and then Pattern (Index + 1) = Literal_Quote
                              then
                                 US.Append (Literal_Run, Literal_Quote);
                                 Index := Index + 2;
                              else
                                 Index := Index + 1;
                                 exit;
                              end if;
                           else
                              US.Append (Literal_Run, Pattern (Index));
                              Index := Index + 1;
                           end if;
                        end loop;
                     end if;
                  elsif Is_Supported_Field (C) then
                     Flush_Literal;
                     US.Append (Output, C);
                     Index := Index + 1;
                  elsif Is_ASCII_Letter (C) then
                     return "";
                  else
                     US.Append (Literal_Run, C);
                     Index := Index + 1;
                  end if;
               end;
            end loop;

            Flush_Literal;
            return S (Output);
         end Internal_Pattern;

         procedure Emit_Available_Format_Rows (Locale : String) is
            Available : constant String := Available_Formats_Object (Locale);
            Parent    : constant String := Parent_Locale (Locale);
            Parent_Available : constant String :=
              (if Parent /= ""
                 and then Project_Tools.Files.File_Exists
                   ("upstream/" & Date_Source_Path (Parent))
               then Available_Formats_Object (Parent)
               else "");
            Index     : Natural := Available'First;
         begin
            if Available = "" then
               return;
            end if;

            while Index <= Available'Last loop
               while Index <= Available'Last and then Available (Index) /= '"' loop
                  Index := Index + 1;
               end loop;

               exit when Index > Available'Last;

               declare
                  Key_First : constant Natural := Index + 1;
                  Key_Last  : Natural := 0;
               begin
                  Index := Key_First;
                  while Index <= Available'Last loop
                     if Available (Index) = '\' then
                        Index := Index + 2;
                     elsif Available (Index) = '"' then
                        Key_Last := Index - 1;
                        exit;
                     else
                        Index := Index + 1;
                     end if;
                  end loop;

                  exit when Key_Last = 0;

                  declare
                     Skeleton : constant String :=
                       (if Key_First <= Key_Last
                        then Available (Key_First .. Key_Last)
                        else "");
                     Pattern  : constant String :=
                       Project_Tools.JSON.Object_Field_Value
                         (Available, Skeleton);
                     Internal : constant String := Internal_Pattern (Pattern);
                     Parent_Pattern : constant String :=
                       (if Parent_Available /= ""
                        then Project_Tools.JSON.Object_Field_Value
                          (Parent_Available, Skeleton)
                        else "");
                     Parent_Internal : constant String :=
                       (if Parent_Pattern /= ""
                        then Internal_Pattern (Parent_Pattern)
                        else "");
                     Value_Last : Natural := Key_Last + 1;
                  begin
                     if Is_Exported_Available_Skeleton (Skeleton)
                       and then Pattern /= ""
                       and then Internal /= ""
                       and then Internal /= Skeleton
                       and then Internal /= Parent_Internal
                     then
                        Emit_JSON
                          ("{""type"":""available_format"",""locale"":"""
                           & Locale & """,""skeleton"":""" & Skeleton
                           & """,""pattern"":"""
                           & JSON_Escape (Internal) & """}");
                     end if;

                     while Value_Last <= Available'Last
                       and then Available (Value_Last) /= ':'
                     loop
                        Value_Last := Value_Last + 1;
                     end loop;

                     Value_Last := Value_Last + 1;
                     while Value_Last <= Available'Last
                       and then Available (Value_Last) /= '"'
                     loop
                        Value_Last := Value_Last + 1;
                     end loop;

                     if Value_Last <= Available'Last then
                        Value_Last := Value_Last + 1;
                        while Value_Last <= Available'Last loop
                           if Available (Value_Last) = '\' then
                              Value_Last := Value_Last + 2;
                           elsif Available (Value_Last) = '"' then
                              exit;
                           else
                              Value_Last := Value_Last + 1;
                           end if;
                        end loop;
                     end if;

                     Index := Value_Last;
                  end;
               end;

               Index := Index + 1;
            end loop;
         end Emit_Available_Format_Rows;

         procedure Emit_List_Separator_Rows is
            Path : constant String := "cldr-json/cldr-full/listData.json";

            procedure Emit_Pairs
              (Record_Type : String;
               Family      : String;
               Part        : String;
               Field_Name  : String)
            is
               Pairs : constant String := Source_Value (Path, Field_Name);
            begin
               for Index in 1 .. Field_Count (Pairs, '~') loop
                  declare
                     Pair   : constant String := Field (Pairs, Index, '~');
                     Locale : constant String := Field (Pair, 1, ':');
                     Value  : constant String := Field (Pair, 2, ':');
                  begin
                     if Field_Count (Pair, ':') /= 2 then
                        Add_Error ("invalid list-separator pair in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""" & Record_Type & """,""locale"":"""
                           & Locale & """,""family"":""" & Family
                           & """,""part"":""" & Part
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end Emit_Pairs;
         begin
            Emit_Pairs ("list_separator", "standard", "final", "listFinalRows");
            Emit_Pairs ("list_separator", "standard", "pair", "listPairRows");
            Emit_Pairs ("list_separator", "standard", "start", "listStartRows");
            Emit_Pairs ("list_separator", "standard", "middle", "listMiddleRows");
            Emit_Pairs ("list_separator", "standard", "item", "listItemRows");
            Emit_Pairs ("list_separator", "or", "final", "listOrFinalRows");
            Emit_Pairs ("list_separator", "or", "pair", "listOrPairRows");
            Emit_Pairs ("list_separator", "or", "start", "listOrStartRows");
            Emit_Pairs ("list_separator", "or", "middle", "listOrMiddleRows");
            Emit_Pairs ("list_separator", "or", "item", "listOrItemRows");
            Emit_Pairs ("list_separator", "unit", "final", "listUnitFinalRows");
            Emit_Pairs ("list_separator", "unit", "pair", "listUnitPairRows");
            Emit_Pairs ("list_separator", "unit", "start", "listUnitStartRows");
            Emit_Pairs ("list_separator", "unit", "middle", "listUnitMiddleRows");
            Emit_Pairs ("list_separator", "unit", "item", "listUnitItemRows");
            Emit_Pairs ("unit_separator", "standard", "per", "unitPerRows");

            declare
               Rows : constant String := Source_Value (Path, "unitShortRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row   : constant String := Field (Rows, Index, '~');
                     Base  : constant String := Field (Row, 1, ':');
                     Value : constant String := Field (Row, 2, ':');
                  begin
                     if Field_Count (Row, ':') /= 2 then
                        Add_Error ("invalid unit-short row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""unit_short"",""base"":"""
                           & Base & """,""value"":"""
                           & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end;

            declare
               Rows : constant String := Source_Value (Path, "unitNameRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row      : constant String := Field (Rows, Index, '~');
                     Locale   : constant String := Field (Row, 1, ':');
                     Base     : constant String := Field (Row, 2, ':');
                     Width    : constant String := Field (Row, 3, ':');
                     Category : constant String := Field (Row, 4, ':');
                     Value    : constant String := Field (Row, 5, ':');
                  begin
                     if Field_Count (Row, ':') /= 5 then
                        Add_Error ("invalid unit-name row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""unit_name"",""locale"":"""
                           & Locale & """,""base"":""" & Base
                           & """,""width"":""" & Width
                           & """,""category"":""" & Category
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end;

            declare
               Rows : constant String := Source_Value (Path, "relativeCurrentRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row    : constant String := Field (Rows, Index, '~');
                     Locale : constant String := Field (Row, 1, ':');
                     Base   : constant String := Field (Row, 2, ':');
                     Value  : constant String := Field (Row, 3, ':');
                  begin
                     if Field_Count (Row, ':') /= 3 then
                        Add_Error ("invalid relative-current row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""relative_current"",""locale"":"""
                           & Locale & """,""base"":""" & Base
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end;

            declare
               Rows : constant String := Source_Value (Path, "relativeOffsetRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row     : constant String := Field (Rows, Index, '~');
                     Locale  : constant String := Field (Row, 1, ':');
                     Offset  : constant String := Field (Row, 2, ':');
                     Pattern : constant String := Field (Row, 3, ':');
                  begin
                     if Field_Count (Row, ':') /= 3 then
                        Add_Error ("invalid relative-offset row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""relative_offset"",""locale"":"""
                           & Locale & """,""offset"":""" & Offset
                           & """,""pattern"":"""
                           & JSON_Escape (Pattern) & """}");
                     end if;
                  end;
               end loop;
            end;

            declare
               Rows : constant String := Source_Value (Path, "relativeUnitRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row      : constant String := Field (Rows, Index, '~');
                     Locale   : constant String := Field (Row, 1, ':');
                     Base     : constant String := Field (Row, 2, ':');
                     Category : constant String := Field (Row, 3, ':');
                     Value    : constant String := Field (Row, 4, ':');
                  begin
                     if Field_Count (Row, ':') /= 4 then
                        Add_Error ("invalid relative-unit row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""relative_unit_category"",""locale"":"""
                           & Locale & """,""base"":""" & Base
                           & """,""category"":""" & Category
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end;
         end Emit_List_Separator_Rows;

         function Relative_Field_Key (Base : String; Width : String) return String is
         begin
            if Width = "unit-width-full-name" then
               return Base;
            elsif Width = "unit-width-short" then
               return Base & "-short";
            elsif Width = "unit-width-narrow" then
               return Base & "-narrow";
            else
               return "";
            end if;
         end Relative_Field_Key;

         function Compact_Relative_Current_Exists
           (Locale : String;
            Base   : String;
            Width  : String)
            return Boolean
         is
            Path : constant String := "cldr-json/cldr-full/listData.json";
            Rows : constant String := Source_Value (Path, "relativeCurrentRows");
         begin
            for Index in 1 .. Field_Count (Rows, '~') loop
               declare
                  Row : constant String := Field (Rows, Index, '~');
               begin
                  if Field_Count (Row, ':') = 3
                    and then Field (Row, 1, ':') = Locale
                    and then Field (Row, 2, ':') = Base
                    and then Width = "unit-width-full-name"
                  then
                     return True;
                  end if;
               end;
            end loop;

            return False;
         end Compact_Relative_Current_Exists;

         procedure Emit_Relative_Current_Rows (Locale : String) is
            Fields : constant String := Date_Fields_Object (Locale);

            procedure Emit_Base (Base : String; Width : String) is
               Key    : constant String := Relative_Field_Key (Base, Width);
               Object : constant String := Object_Field_Object (Fields, Key);
               Value  : constant String :=
                 Project_Tools.JSON.Object_Field_Value
                   (Object, "relative-type-0");
            begin
               if Value /= ""
                 and then not Compact_Relative_Current_Exists
                   (Locale, Base, Width)
               then
                  Emit_JSON
                    ("{""type"":""relative_current"",""locale"":"""
                     & Locale & """,""base"":""" & Base
                     & """,""width"":""" & Width
                     & """,""value"":""" & JSON_Escape (Value) & """}");
               end if;
            end Emit_Base;

            procedure Emit_Base_Widths (Base : String) is
            begin
               Emit_Base (Base, "unit-width-full-name");
               Emit_Base (Base, "unit-width-short");
               Emit_Base (Base, "unit-width-narrow");
            end Emit_Base_Widths;
         begin
            if Fields = "" then
               return;
            end if;

            Emit_Base_Widths ("day");
            Emit_Base_Widths ("quarter");
            Emit_Base_Widths ("week");
            Emit_Base_Widths ("month");
            Emit_Base_Widths ("year");
            Emit_Base_Widths ("hour");
            Emit_Base_Widths ("minute");
            Emit_Base_Widths ("second");
         end Emit_Relative_Current_Rows;

         procedure Emit_Relative_Time_Pattern_Rows (Locale : String) is
            Fields : constant String := Date_Fields_Object (Locale);

            procedure Emit_Pattern
              (Base      : String;
               Width     : String;
               Direction : String;
               Category  : String)
            is
               Key    : constant String := Relative_Field_Key (Base, Width);
               Object : constant String := Object_Field_Object (Fields, Key);
               Group  : constant String :=
                 Object_Field_Object
                   (Object, "relativeTime-type-" & Direction);
               Value  : constant String :=
                 Project_Tools.JSON.Object_Field_Value
                   (Group, "relativeTimePattern-count-" & Category);
            begin
               if Value /= "" and then Contains (Value, "{0}") then
                  Emit_JSON
                    ("{""type"":""relative_time_pattern"",""locale"":"""
                     & Locale & """,""base"":""" & Base
                     & """,""width"":""" & Width
                     & """,""direction"":""" & Direction
                     & """,""category"":""" & Category
                     & """,""pattern"":""" & JSON_Escape (Value) & """}");
               end if;
            end Emit_Pattern;

            procedure Emit_Base (Base : String; Width : String) is
            begin
               for Direction_Index in 1 .. 2 loop
                  declare
                     Direction : constant String :=
                       (if Direction_Index = 1 then "future" else "past");
                  begin
                     Emit_Pattern (Base, Width, Direction, "zero");
                     Emit_Pattern (Base, Width, Direction, "one");
                     Emit_Pattern (Base, Width, Direction, "two");
                     Emit_Pattern (Base, Width, Direction, "few");
                     Emit_Pattern (Base, Width, Direction, "many");
                     Emit_Pattern (Base, Width, Direction, "other");
                  end;
               end loop;
            end Emit_Base;

            procedure Emit_Base_Widths (Base : String) is
            begin
               Emit_Base (Base, "unit-width-full-name");
               Emit_Base (Base, "unit-width-short");
               Emit_Base (Base, "unit-width-narrow");
            end Emit_Base_Widths;
         begin
            if Fields = "" then
               return;
            end if;

            Emit_Base_Widths ("day");
            Emit_Base_Widths ("quarter");
            Emit_Base_Widths ("week");
            Emit_Base_Widths ("month");
            Emit_Base_Widths ("year");
            Emit_Base_Widths ("hour");
            Emit_Base_Widths ("minute");
            Emit_Base_Widths ("second");
         end Emit_Relative_Time_Pattern_Rows;

         procedure Emit_Quarter_Rows (Locale : String) is
            Gregorian : constant String := Gregorian_Object (Locale);
            Quarters  : constant String := Object_Field_Object (Gregorian, "quarters");
            Format    : constant String := Object_Field_Object (Quarters, "format");

            function Quarter_Values (Width : String) return String is
               Object : constant String := Object_Field_Object (Format, Width);
               Result : US.Unbounded_String;
            begin
               for Quarter in 1 .. 4 loop
                  declare
                     Key   : constant String := Natural'Image (Quarter);
                     Value : constant String :=
                       Project_Tools.JSON.Object_Field_Value
                         (Object, Key (Key'First + 1 .. Key'Last));
                  begin
                     if Value = "" then
                        Add_Error
                          ("missing " & Width & " CLDR quarter "
                           & Key (Key'First + 1 .. Key'Last)
                           & " for locale " & Locale);
                        return "";
                     end if;

                     if Quarter > 1 then
                        US.Append (Result, "~");
                     end if;
                     US.Append (Result, Value);
                  end;
               end loop;

               return S (Result);
            end Quarter_Values;

            Wide        : constant String := Quarter_Values ("wide");
            Abbreviated : constant String := Quarter_Values ("abbreviated");
            Wide_Hex    : constant String := Codepoint_Hex_List (Wide);
            Abbr_Hex    : constant String := Codepoint_Hex_List (Abbreviated);
         begin
            if Wide /= "" and then Wide_Hex /= "" then
               Emit_JSON
                 ("{""type"":""name_hex"",""kind"":""quarter"",""locale"":"""
                  & Locale & """,""start"":""1"",""values"":"""
                  & Wide_Hex & """}");
            elsif Wide /= "" then
               Emit_JSON
                 ("{""type"":""name_set"",""kind"":""quarter"",""locale"":"""
                  & Locale & """,""start"":""1"",""values"":"""
                  & JSON_Escape (Wide) & """}");
            end if;

            if Abbreviated /= "" and then Abbr_Hex /= "" then
               Emit_JSON
                 ("{""type"":""name_hex"",""kind"":""quarter_short"",""locale"":"""
                  & Locale & """,""start"":""1"",""values"":"""
                  & Abbr_Hex & """}");
            elsif Abbreviated /= "" then
               Emit_JSON
                 ("{""type"":""name_set"",""kind"":""quarter_short"",""locale"":"""
                  & Locale & """,""start"":""1"",""values"":"""
                  & JSON_Escape (Abbreviated) & """}");
            end if;
         end Emit_Quarter_Rows;

         procedure Emit_Day_Period_Rows (Locale : String) is
            Gregorian   : constant String := Gregorian_Object (Locale);
            Day_Periods : constant String := Object_Field_Object (Gregorian, "dayPeriods");
            Format      : constant String := Object_Field_Object (Day_Periods, "format");

            procedure Emit_Values (Width : String) is
               Object : constant String := Object_Field_Object (Format, Width);
            begin
               if Object = "" then
                  Add_Error
                    ("missing " & Width & " CLDR day-period data for locale "
                     & Locale);
                  return;
               end if;

               for Index in 1 .. 8 loop
                  declare
                     Period : constant String :=
                       (case Index is
                          when 1 => "midnight",
                          when 2 => "noon",
                          when 3 => "am",
                          when 4 => "pm",
                          when 5 => "morning1",
                          when 6 => "afternoon1",
                          when 7 => "evening1",
                          when others => "night1");
                     Value : constant String :=
                       Project_Tools.JSON.Object_Field_Value (Object, Period);
                  begin
                     if Value /= "" then
                        Emit_JSON
                          ("{""type"":""day_period"",""locale"":"""
                           & Locale & """,""period"":""" & Period
                           & """,""width"":""" & Width
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end Emit_Values;
         begin
            Emit_Values ("wide");
            Emit_Values ("abbreviated");
         end Emit_Day_Period_Rows;

         procedure Emit_Time_Zone_Format_Rows (Locale : String) is
            Names       : constant String := Time_Zone_Names_Object (Locale);
            GMT_Format  : constant String :=
              Project_Tools.JSON.Object_Field_Value (Names, "gmtFormat");
            Hour_Format : constant String :=
              Project_Tools.JSON.Object_Field_Value (Names, "hourFormat");
            Region      : constant String :=
              Project_Tools.JSON.Object_Field_Value (Names, "regionFormat");
            Prefix      : constant String := Prefix_Before_Placeholder (GMT_Format);
            Separator   : constant String := Hour_Separator (Hour_Format);
         begin
            if GMT_Format = "" then
               Add_Error ("missing CLDR gmtFormat for locale " & Locale);
            elsif Prefix /= "" then
               Emit_JSON
                 ("{""type"":""zone_gmt_prefix"",""locale"":"""
                  & Locale & """,""value"":""" & JSON_Escape (Prefix) & """}");
            end if;

            if Hour_Format = "" then
               Add_Error ("missing CLDR hourFormat for locale " & Locale);
            elsif Separator /= "" and then Separator /= ":" then
               Emit_JSON
                 ("{""type"":""zone_offset_separator"",""locale"":"""
                  & Locale & """,""value"":""" & JSON_Escape (Separator) & """}");
            end if;

            if Region = "" then
               Add_Error ("missing CLDR regionFormat for locale " & Locale);
            elsif Contains (Region, "{0}") and then Region /= "{0} Time" then
               Emit_JSON
                 ("{""type"":""zone_location_pattern"",""locale"":"""
                  & Locale & """,""value"":""" & JSON_Escape (Region) & """}");
            end if;
         end Emit_Time_Zone_Format_Rows;

         procedure Emit_Time_Zone_Exemplar_Rows (Locale : String) is
            Names : constant String := Time_Zone_Names_Object (Locale);
            Zones : constant String := Object_Field_Object (Names, "zone");

            function Closing_Brace
              (Text : String;
               Open : Positive)
               return Natural
            is
               Depth   : Natural := 0;
               In_Text : Boolean := False;
               Escape  : Boolean := False;
            begin
               for Index in Open .. Text'Last loop
                  if In_Text then
                     if Escape then
                        Escape := False;
                     elsif Text (Index) = '\' then
                        Escape := True;
                     elsif Text (Index) = '"' then
                        In_Text := False;
                     end if;
                  elsif Text (Index) = '"' then
                     In_Text := True;
                  elsif Text (Index) = '{' then
                     Depth := Depth + 1;
                  elsif Text (Index) = '}' then
                     if Depth = 0 then
                        return 0;
                     elsif Depth = 1 then
                        return Index;
                     else
                        Depth := Depth - 1;
                     end if;
                  end if;
               end loop;

               return 0;
            end Closing_Brace;

            function Next_Object_Start
              (Text  : String;
               Colon : Positive)
               return Natural
            is
               Index : Natural := Colon + 1;
            begin
               while Index <= Text'Last
                 and then Text (Index) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
               loop
                  Index := Index + 1;
               end loop;

               if Index <= Text'Last and then Text (Index) = '{' then
                  return Index;
               else
                  return 0;
               end if;
            end Next_Object_Start;

            function Canonical_Zone_For_CLDR (Zone : String) return String is
            begin
               if Zone = "Asia/Calcutta" then
                  return "Asia/Kolkata";
               elsif Zone = "Asia/Katmandu" then
                  return "Asia/Kathmandu";
               elsif Zone = "Asia/Rangoon" then
                  return "Asia/Yangon";
               elsif Zone = "Asia/Saigon" then
                  return "Asia/Ho_Chi_Minh";
               elsif Zone = "Asia/Macao" then
                  return "Asia/Macau";
               elsif Zone = "Europe/Kiev" then
                  return "Europe/Kyiv";
               elsif Zone = "Atlantic/Faeroe" then
                  return "Atlantic/Faroe";
               elsif Zone = "Pacific/Ponape" then
                  return "Pacific/Pohnpei";
               elsif Zone = "Pacific/Truk" then
                  return "Pacific/Chuuk";
               else
                  return Zone;
               end if;
            end Canonical_Zone_For_CLDR;

            function Derived_Zone_Location (Zone : String) return String is
               Start : Positive := Zone'First;
            begin
               for Index in Zone'Range loop
                  if Zone (Index) = '/' and then Index < Zone'Last then
                     Start := Index + 1;
                  end if;
               end loop;

               declare
                  Result : String := Zone (Start .. Zone'Last);
               begin
                  for Index in Result'Range loop
                     if Result (Index) = '_' then
                        Result (Index) := ' ';
                     end if;
                  end loop;

                  return Result;
               end;
            end Derived_Zone_Location;

            function Compact_Zone_Display_Exists
              (Locale : String;
               Zone   : String)
               return Boolean
            is
               Path : constant String := "cldr-json/cldr-full/timeZoneData.json";
               Rows : constant String := Source_Value (Path, "zoneDisplayRows");
            begin
               for Index in 1 .. Field_Count (Rows, '~') loop
                  declare
                     Row : constant String := Field (Rows, Index, '~');
                  begin
                     if Field_Count (Row, ':') = 3
                       and then Field (Row, 1, ':') = Locale
                       and then Field (Row, 2, ':') = Zone
                     then
                        return True;
                     end if;
                  end;
               end loop;

               return False;
            end Compact_Zone_Display_Exists;

            procedure Scan_Zone_Object
              (Object : String;
               Prefix : String)
            is
               Index : Natural := Object'First;
            begin
               while Index <= Object'Last loop
                  while Index <= Object'Last and then Object (Index) /= '"' loop
                     Index := Index + 1;
                  end loop;

                  exit when Index > Object'Last;

                  declare
                     Key_First : constant Natural := Index + 1;
                     Key_Last  : Natural := 0;
                  begin
                     Index := Key_First;
                     while Index <= Object'Last loop
                        if Object (Index) = '\' then
                           Index := Index + 2;
                        elsif Object (Index) = '"' then
                           Key_Last := Index - 1;
                           exit;
                        else
                           Index := Index + 1;
                        end if;
                     end loop;

                     exit when Key_Last = 0;

                     declare
                        Key    : constant String :=
                          (if Key_First <= Key_Last
                           then Object (Key_First .. Key_Last)
                           else "");
                        Colon  : Natural := Index + 1;
                     begin
                        while Colon <= Object'Last and then Object (Colon) /= ':' loop
                           Colon := Colon + 1;
                        end loop;

                        if Colon <= Object'Last then
                           declare
                              Open : constant Natural :=
                                Next_Object_Start (Object, Colon);
                              Close : constant Natural :=
                                (if Open = 0 then 0 else Closing_Brace (Object, Open));
                           begin
                              if Open /= 0 and then Close /= 0 then
                                 declare
                                    Child : constant String := Object (Open .. Close);
                                    Zone  : constant String :=
                                      (if Prefix = "" then Key else Prefix & "/" & Key);
                                    Canonical : constant String :=
                                      Canonical_Zone_For_CLDR (Zone);
                                    City : constant String :=
                                      Project_Tools.JSON.Object_Field_Value
                                        (Child, "exemplarCity");
                                    Long : constant String :=
                                      Object_Field_Object (Child, "long");
                                    Generic_Name : constant String :=
                                      Project_Tools.JSON.Object_Field_Value
                                        (Long, "generic");
                                    Standard_Name : constant String :=
                                      Project_Tools.JSON.Object_Field_Value
                                        (Long, "standard");
                                    Display_Name : constant String :=
                                      (if Generic_Name /= ""
                                       then Generic_Name
                                       else Standard_Name);
                                 begin
                                    if City /= ""
                                      and then Valid_Zone_Name (Canonical)
                                      and then City /= Derived_Zone_Location (Canonical)
                                    then
                                       Emit_JSON
                                         ("{""type"":""zone_exemplar"",""locale"":"""
                                          & Locale & """,""zone"":""" & Canonical
                                          & """,""value"":""" & JSON_Escape (City)
                                          & """}");
                                    end if;

                                    if Display_Name /= ""
                                      and then Valid_Zone_Name (Canonical)
                                      and then Contains (Canonical, "/")
                                      and then not Compact_Zone_Display_Exists
                                        (Locale, Canonical)
                                    then
                                       Emit_JSON
                                         ("{""type"":""zone_display"",""locale"":"""
                                          & Locale & """,""zone"":""" & Canonical
                                          & """,""value"":""" & JSON_Escape
                                            (Display_Name)
                                          & """}");
                                    end if;

                                    if Key /= "long" and then Key /= "short" then
                                       Scan_Zone_Object (Child, Zone);
                                    end if;
                                 end;

                                 Index := Close + 1;
                              else
                                 Index := Colon + 1;
                              end if;
                           end;
                        else
                           Index := Index + 1;
                        end if;
                     end;
                  end;
               end loop;
            end Scan_Zone_Object;
         begin
            if Zones /= "" then
               Scan_Zone_Object (Zones, "");
            end if;
         end Emit_Time_Zone_Exemplar_Rows;

         procedure Emit_Time_Zone_Display_Rows is
            Path : constant String := "cldr-json/cldr-full/timeZoneData.json";
            Rows : constant String := Source_Value (Path, "zoneDisplayRows");
         begin
            for Index in 1 .. Field_Count (Rows, '~') loop
               declare
                  Row    : constant String := Field (Rows, Index, '~');
                  Locale : constant String := Field (Row, 1, ':');
                  Zone   : constant String := Field (Row, 2, ':');
                  Value  : constant String := Field (Row, 3, ':');
               begin
                  if Field_Count (Row, ':') /= 3 then
                     Add_Error ("invalid zone-display row in " & Path);
                  else
                     Emit_JSON
                       ("{""type"":""zone_display"",""locale"":"""
                        & Locale & """,""zone"":""" & Zone
                        & """,""value"":""" & JSON_Escape (Value) & """}");
                  end if;
               end;
            end loop;

            declare
               Family_Rows : constant String :=
                 Source_Value (Path, "zoneFamilyDisplayRows");
            begin
               for Index in 1 .. Field_Count (Family_Rows, '~') loop
                  declare
                     Row    : constant String := Field (Family_Rows, Index, '~');
                     Locale : constant String := Field (Row, 1, ':');
                     Family : constant String := Field (Row, 2, ':');
                     Value  : constant String := Field (Row, 3, ':');
                  begin
                     if Field_Count (Row, ':') /= 3 then
                        Add_Error ("invalid zone-family-display row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""zone_family_display"",""locale"":"""
                           & Locale & """,""family"":""" & Family
                           & """,""value"":""" & JSON_Escape (Value) & """}");
                     end if;
                  end;
               end loop;
            end;

            declare
               Short_Rows : constant String :=
                 Source_Value (Path, "zoneShortFamilyRows");
            begin
               for Index in 1 .. Field_Count (Short_Rows, '~') loop
                  declare
                     Row       : constant String := Field (Short_Rows, Index, '~');
                     Locale    : constant String := Field (Row, 1, ':');
                     Family    : constant String := Field (Row, 2, ':');
                     Standard  : constant String := Field (Row, 3, ':');
                     Daylight  : constant String := Field (Row, 4, ':');
                     Generic_Label : constant String := Field (Row, 5, ':');
                  begin
                     if Field_Count (Row, ':') /= 5 then
                        Add_Error ("invalid zone-short-family row in " & Path);
                     else
                        Emit_JSON
                          ("{""type"":""zone_short_family"",""locale"":"""
                           & Locale & """,""family"":""" & Family
                           & """,""standard"":""" & JSON_Escape (Standard)
                           & """,""daylight"":""" & JSON_Escape (Daylight)
                           & """,""generic"":""" & JSON_Escape (Generic_Label)
                           & """}");
                     end if;
                  end;
               end loop;
            end;
         end Emit_Time_Zone_Display_Rows;

         function Compact_Zone_Family_Display_Exists
           (Locale : String;
            Family : String)
            return Boolean
         is
            Path : constant String := "cldr-json/cldr-full/timeZoneData.json";
            Rows : constant String := Source_Value (Path, "zoneFamilyDisplayRows");
         begin
            for Index in 1 .. Field_Count (Rows, '~') loop
               declare
                  Row : constant String := Field (Rows, Index, '~');
               begin
                  if Field_Count (Row, ':') = 3
                    and then Field (Row, 1, ':') = Locale
                    and then Field (Row, 2, ':') = Family
                  then
                     return True;
                  end if;
               end;
            end loop;

            return False;
         end Compact_Zone_Family_Display_Exists;

         function Compact_Zone_Display_Exists
           (Locale : String;
            Zone   : String)
            return Boolean
         is
            Path : constant String := "cldr-json/cldr-full/timeZoneData.json";
            Rows : constant String := Source_Value (Path, "zoneDisplayRows");
         begin
            for Index in 1 .. Field_Count (Rows, '~') loop
               declare
                  Row : constant String := Field (Rows, Index, '~');
               begin
                  if Field_Count (Row, ':') = 3
                    and then Field (Row, 1, ':') = Locale
                    and then Field (Row, 2, ':') = Zone
                  then
                     return True;
                  end if;
               end;
            end loop;

            return False;
         end Compact_Zone_Display_Exists;

         function Compact_Zone_Short_Family_Exists
           (Locale : String;
            Family : String)
            return Boolean
         is
            Path : constant String := "cldr-json/cldr-full/timeZoneData.json";
            Rows : constant String := Source_Value (Path, "zoneShortFamilyRows");
         begin
            for Index in 1 .. Field_Count (Rows, '~') loop
               declare
                  Row : constant String := Field (Rows, Index, '~');
               begin
                  if Field_Count (Row, ':') = 5
                    and then Field (Row, 1, ':') = Locale
                    and then Field (Row, 2, ':') = Family
                  then
                     return True;
                  end if;
               end;
            end loop;

            return False;
         end Compact_Zone_Short_Family_Exists;

         procedure Emit_Time_Zone_Metazone_Rows (Locale : String) is
            Names     : constant String := Time_Zone_Names_Object (Locale);
            Metazones : constant String := Object_Field_Object (Names, "metazone");

            procedure Emit_Family
              (Family  : String;
               CLDR_ID : String)
            is
               Object  : constant String := Object_Field_Object (Metazones, CLDR_ID);
               Long    : constant String := Object_Field_Object (Object, "long");
               Short   : constant String := Object_Field_Object (Object, "short");
               Generic_Label : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Long, "generic");
               Standard : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Long, "standard");
               Short_Generic : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Short, "generic");
               Short_Standard : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Short, "standard");
               Short_Daylight : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Short, "daylight");
               Display : constant String :=
                 (if Generic_Label /= "" then Generic_Label else Standard);
            begin
               if Display /= ""
                 and then not Compact_Zone_Family_Display_Exists
                   (Locale, Family)
               then
                  Emit_JSON
                    ("{""type"":""zone_family_display"",""locale"":"""
                     & Locale & """,""family"":""" & Family
                     & """,""value"":""" & JSON_Escape (Display) & """}");
               end if;

               if Short_Generic /= ""
                 and then Short_Standard /= ""
                 and then Short_Daylight /= ""
                 and then not Compact_Zone_Short_Family_Exists
                   (Locale, Family)
               then
                  Emit_JSON
                    ("{""type"":""zone_short_family"",""locale"":"""
                     & Locale & """,""family"":""" & Family
                     & """,""standard"":""" & JSON_Escape (Short_Standard)
                     & """,""daylight"":""" & JSON_Escape (Short_Daylight)
                     & """,""generic"":""" & JSON_Escape (Short_Generic)
                     & """}");
               end if;
            end Emit_Family;
         begin
            if Metazones = "" then
               return;
            end if;

            Emit_Family ("europe-central", "Europe_Central");
            Emit_Family ("europe-london", "Europe_Western");
            Emit_Family ("europe-eastern", "Europe_Eastern");
            Emit_Family ("america-eastern", "America_Eastern");
            Emit_Family ("america-central", "America_Central");
            Emit_Family ("america-mexico-city", "America_Central");
            Emit_Family ("america-mountain", "America_Mountain");
            Emit_Family ("america-pacific", "America_Pacific");
            Emit_Family ("america-sao-paulo", "Brasilia");
            Emit_Family ("pacific-new-zealand", "New_Zealand");
            Emit_Family ("australia-eastern", "Australia_Eastern");
            Emit_Family ("australia-central", "Australia_Central");
            Emit_Family ("australia-central-western", "Australia_CentralWestern");
            Emit_Family ("australia-western", "Australia_Western");
            Emit_Family ("australia-lord-howe", "Lord_Howe");
            Emit_Family ("asia-jerusalem", "Israel");
            Emit_Family ("asia-tehran", "Iran");

            declare
               procedure Emit_Fixed_Zone
                 (Zone    : String;
                  CLDR_ID : String)
               is
                  Object  : constant String := Object_Field_Object
                    (Metazones, CLDR_ID);
                  Long    : constant String := Object_Field_Object
                    (Object, "long");
                  Generic_Label : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Long, "generic");
                  Standard : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Long, "standard");
                  Display : constant String :=
                    (if Generic_Label /= "" then Generic_Label else Standard);
               begin
                  if Display /= ""
                    and then not Compact_Zone_Display_Exists (Locale, Zone)
                  then
                     Emit_JSON
                       ("{""type"":""zone_display"",""locale"":"""
                        & Locale & """,""zone"":""" & Zone
                        & """,""value"":""" & JSON_Escape (Display) & """}");
                  end if;
               end Emit_Fixed_Zone;
            begin
               Emit_Fixed_Zone ("Asia/Tokyo", "Japan");
               Emit_Fixed_Zone ("Europe/Moscow", "Moscow");
               Emit_Fixed_Zone ("America/Bogota", "Colombia");
               Emit_Fixed_Zone ("America/Lima", "Peru");
               Emit_Fixed_Zone ("America/Argentina/Buenos_Aires", "Argentina");
               Emit_Fixed_Zone ("Africa/Johannesburg", "Africa_Southern");
               Emit_Fixed_Zone ("Africa/Accra", "Ghana");
               Emit_Fixed_Zone ("Africa/Abidjan", "GMT");
               Emit_Fixed_Zone ("Africa/Algiers", "Europe_Central");
               Emit_Fixed_Zone ("Africa/Tunis", "Europe_Central");
               Emit_Fixed_Zone ("Africa/Nairobi", "Africa_Eastern");
               Emit_Fixed_Zone ("Africa/Lagos", "Africa_Western");
               Emit_Fixed_Zone ("Asia/Dubai", "Gulf");
               Emit_Fixed_Zone ("Asia/Yerevan", "Armenia");
               Emit_Fixed_Zone ("Asia/Tbilisi", "Georgia");
               Emit_Fixed_Zone ("Asia/Baku", "Azerbaijan");
               Emit_Fixed_Zone ("Asia/Tashkent", "Uzbekistan");
               Emit_Fixed_Zone ("Asia/Riyadh", "Arabian");
               Emit_Fixed_Zone ("Asia/Shanghai", "China");
               Emit_Fixed_Zone ("Asia/Singapore", "Singapore");
               Emit_Fixed_Zone ("Asia/Hong_Kong", "Hong_Kong");
               Emit_Fixed_Zone ("Asia/Taipei", "Taipei");
               Emit_Fixed_Zone ("Asia/Kuala_Lumpur", "Malaysia");
               Emit_Fixed_Zone ("Asia/Manila", "Philippines");
               Emit_Fixed_Zone ("Asia/Bangkok", "Indochina");
               Emit_Fixed_Zone ("Asia/Jakarta", "Indonesia_Western");
               Emit_Fixed_Zone ("Asia/Ho_Chi_Minh", "Indochina");
               Emit_Fixed_Zone ("Asia/Karachi", "Pakistan");
               Emit_Fixed_Zone ("Asia/Colombo", "Lanka");
               Emit_Fixed_Zone ("Asia/Dhaka", "Bangladesh");
               Emit_Fixed_Zone ("Asia/Yangon", "Myanmar");
               Emit_Fixed_Zone ("Asia/Seoul", "Korea");
               Emit_Fixed_Zone ("Asia/Kolkata", "India");
               Emit_Fixed_Zone ("Asia/Kathmandu", "Nepal");
               Emit_Fixed_Zone ("Asia/Ulaanbaatar", "Mongolia");
               Emit_Fixed_Zone ("Pacific/Honolulu", "Hawaii_Aleutian");
            end;
         end Emit_Time_Zone_Metazone_Rows;
      begin
         declare
            Rows : constant String :=
              Source_Value ("cldr-json/cldr-full/allLocaleData.json", "dateNameRows");
         begin
            for Index in 1 .. Field_Count (Rows, ';') loop
               declare
                  Row        : constant String := Field (Rows, Index, ';');
                  Name_Kind  : constant String := Field (Row, 1, ASCII.HT);
                  Locale     : constant String := Field (Row, 2, ASCII.HT);
                  Start_Text : constant String := Field (Row, 3, ASCII.HT);
                  Values     : constant String := Field (Row, 4, ASCII.HT);
               begin
                  if Field_Count (Row, ASCII.HT) /= 4 then
                     Add_Error ("invalid all-locale date-name row in CLDR source");
                  else
                     Emit_JSON
                       ("{""type"":""name_hex"",""kind"":""" & Name_Kind
                        & """,""locale"":""" & Locale
                        & """,""start"":""" & Start_Text
                        & """,""values"":""" & Values & """}");
                  end if;
               end;
            end loop;
         end;

         Load_Date_Locales;
         for Index in 1 .. Date_Count loop
            declare
               Locale : constant String := S (Date_Locales (Index));
            begin
               Emit_Quarter_Rows (Locale);
               Emit_Day_Period_Rows (Locale);
               Emit_Relative_Current_Rows (Locale);
               Emit_Relative_Time_Pattern_Rows (Locale);
               Emit_Available_Format_Rows (Locale);
               Emit_Time_Zone_Format_Rows (Locale);
               Emit_Time_Zone_Exemplar_Rows (Locale);
               Emit_Time_Zone_Metazone_Rows (Locale);
            end;
         end loop;
         Emit_List_Separator_Rows;
         Emit_Time_Zone_Display_Rows;
      end Emit_Migrated_Date_Name_Rows;
   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Emit_Header;
      if Project_Tools.Files.Directory_Exists
           ("upstream/cldr-json/cldr-numbers-full/main")
      then
         Emit_Full_Number_Rows;
      else
         Emit_Migrated_Number_Rows;
      end if;
      L;
      Emit_Migrated_Date_Name_Rows;
      L;
      Emit_Migrated_Currency_Rows;
      L;
      Emit_Full_Currency_Name_Rows;
      L;
      Emit_Migrated_Supplemental_Rows;

      Ada.Text_IO.Close (Output);
      return "";
   exception
      when Error : others =>
         if Ada.Text_IO.Is_Open (Output) then
            Ada.Text_IO.Close (Output);
         end if;
         Add_Error ("failed to generate CLDR export");
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Information (Error));
         return "";
   end Generate;

begin
   if Has_Argument ("--help") then
      Ada.Text_IO.Put_Line
        ("usage: generate_cldr_export [--check]" & ASCII.LF
         & "Generates upstream/cldr_export.jsonl from CLDR source fragments.");
      return;
   end if;

   declare
      Generated : constant String := Generate;
   begin
      if Errors /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      elsif Has_Argument ("--check") then
         if File_Equals_File (Generated_Path, Target_Path) then
            Ada.Text_IO.Put_Line ("CLDR staged export is current");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "cldr/upstream/cldr_export.jsonl is not current; run cldr/bin/generate_cldr_export");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      else
         Ada.Directories.Copy_File (Generated_Path, Target_Path);
         Ada.Text_IO.Put_Line ("generated cldr/upstream/cldr_export.jsonl");
      end if;
   end;
exception
   when Error : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to generate CLDR export");
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, Ada.Exceptions.Exception_Information (Error));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Generate_CLDR_Export;
