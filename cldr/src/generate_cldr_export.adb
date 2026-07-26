with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;
with Hostkit.Fs;
with Project_Tools.JSON;

procedure Generate_CLDR_Export is
   package US renames Ada.Strings.Unbounded;

   Target_Path : constant String := "upstream/cldr_export.jsonl";

   Errors : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   Generated_Path : constant String := Hostkit.Fs.Temp_Directory & "/i18n_cldr_export.generated.jsonl";

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

   function First_Index (Text : String; Pattern : String) return Natural is
   begin
      if Pattern'Length = 0 or else Text'Length < Pattern'Length then
         return 0;
      end if;

      for Index in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            return Index;
         end if;
      end loop;

      return 0;
   end First_Index;

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

   procedure For_Each_Object_Field
     (Text    : String;
      Process : not null access procedure (Name : String; Value : String))
   is
      Index   : Natural := Text'First;
      In_Text : Boolean;

      procedure Skip_WS is
      begin
         while Index <= Text'Last
           and then Text (Index) in ' ' | ASCII.HT | ASCII.CR | ASCII.LF
         loop
            Index := Index + 1;
         end loop;
      end Skip_WS;

      function Read_String return String is
         First : Natural;
      begin
         if Index > Text'Last or else Text (Index) /= '"' then
            return "";
         end if;

         Index := Index + 1;
         First := Index;
         while Index <= Text'Last loop
            if Text (Index) = '\' then
               Index := Index + 2;
            elsif Text (Index) = '"' then
               declare
                  Result : constant String := Text (First .. Index - 1);
               begin
                  Index := Index + 1;
                  return Result;
               end;
            else
               Index := Index + 1;
            end if;
         end loop;

         return "";
      end Read_String;

      function Read_Value return String is
         First : constant Natural := Index;
         Depth : Natural := 0;
      begin
         if Index > Text'Last then
            return "";
         elsif Text (Index) = '{' then
            In_Text := False;
            while Index <= Text'Last loop
               if Text (Index) = '"' then
                  In_Text := not In_Text;
               elsif In_Text and then Text (Index) = '\' then
                  Index := Index + 1;
               elsif not In_Text then
                  if Text (Index) = '{' then
                     Depth := Depth + 1;
                  elsif Text (Index) = '}' then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        Index := Index + 1;
                        return Text (First .. Index - 1);
                     end if;
                  end if;
               end if;
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '[' then
            In_Text := False;
            while Index <= Text'Last loop
               if Text (Index) = '"' then
                  In_Text := not In_Text;
               elsif In_Text and then Text (Index) = '\' then
                  Index := Index + 1;
               elsif not In_Text then
                  if Text (Index) = '[' then
                     Depth := Depth + 1;
                  elsif Text (Index) = ']' then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        Index := Index + 1;
                        return Text (First .. Index - 1);
                     end if;
                  end if;
               end if;
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '"' then
            declare
               Ignored : constant String := Read_String;
            begin
               return Text (First .. Index - 1);
            end;
         else
            while Index <= Text'Last
              and then Text (Index) not in ',' | '}'
            loop
               Index := Index + 1;
            end loop;
            return Text (First .. Index - 1);
         end if;

         return "";
      end Read_Value;
   begin
      Skip_WS;
      if Index > Text'Last or else Text (Index) /= '{' then
         return;
      end if;

      Index := Index + 1;
      loop
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) = '}';
         declare
            Name : constant String := Read_String;
         begin
            Skip_WS;
            exit when Index > Text'Last or else Text (Index) /= ':';
            Index := Index + 1;
            Skip_WS;
            declare
               Value : constant String := Read_Value;
            begin
               Process (Name, Value);
            end;
         end;
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) /= ',';
         Index := Index + 1;
      end loop;
   end For_Each_Object_Field;

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

         procedure Append_CSV (List : in out US.Unbounded_String; Value : String) is
         begin
            if Value = "" then
               return;
            end if;

            if US.Length (List) > 0 then
               US.Append (List, ",");
            end if;
            US.Append (List, Value);
         end Append_CSV;

         function Default_Number_System (Text : String; Locale : String) return String is
            Raw : constant String :=
              Project_Tools.JSON.Field_Value (Text, "defaultNumberingSystem");
         begin
            if Locale = "ar" then
               return "arab";
            else
               return Raw;
            end if;
         end Default_Number_System;

         function First_Pattern_Field (Pattern : String) return Character is
            Index    : Natural := Pattern'First;
            In_Quote : Boolean := False;
         begin
            while Index <= Pattern'Last loop
               if Pattern (Index) = ''' then
                  if Index < Pattern'Last and then Pattern (Index + 1) = ''' then
                     Index := Index + 2;
                  else
                     In_Quote := not In_Quote;
                     Index := Index + 1;
                  end if;
               else
                  if not In_Quote
                    and then Pattern (Index) in 'd' | 'M' | 'L' | 'y'
                  then
                     return Pattern (Index);
                  end if;
                  Index := Index + 1;
               end if;
            end loop;

            return ASCII.NUL;
         end First_Pattern_Field;

         function Indian_Grouping_Locales return String is
            Result : US.Unbounded_String;
         begin
            for Index in 1 .. Locale_Count loop
               declare
                  Locale : constant String := S (Locales (Index));
                  Text   : constant String :=
                    Project_Tools.Files.Read_Raw_File
                      ("upstream/cldr-json/cldr-numbers-full/main/"
                       & Locale & "/numbers.json");
                  System : constant String := Default_Number_System (Text, Locale);
                  Formats : constant String :=
                    Object_Field_Object
                      (Text, "decimalFormats-numberSystem-" & System);
                  Pattern : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Formats, "standard");
               begin
                  if Contains (Pattern, "#,##,##0") then
                     Append_CSV (Result, Locale);
                  end if;
               exception
                  when others =>
                     Add_Error
                       ("failed to derive CLDR grouping policy for " & Locale);
               end;
            end loop;

            return S (Result);
         end Indian_Grouping_Locales;

         function Symbol_First_Locales return String is
            Result          : US.Unbounded_String;
            Currency_Marker : constant String :=
              Character'Val (16#C2#) & Character'Val (16#A4#);
         begin
            for Index in 1 .. Locale_Count loop
               declare
                  Locale : constant String := S (Locales (Index));
                  Text   : constant String :=
                    Project_Tools.Files.Read_Raw_File
                      ("upstream/cldr-json/cldr-numbers-full/main/"
                       & Locale & "/numbers.json");
                  System : constant String := Default_Number_System (Text, Locale);
                  Formats : constant String :=
                    Object_Field_Object
                      (Text, "currencyFormats-numberSystem-" & System);
                  Pattern : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Formats, "standard");
                  Symbol_Pos : constant Natural :=
                    First_Index (Pattern, Currency_Marker);
                  Hash_Pos   : constant Natural := First_Index (Pattern, "#");
                  Zero_Pos   : constant Natural := First_Index (Pattern, "0");
                  Digit_Pos  : constant Natural :=
                    (if Hash_Pos = 0 then Zero_Pos
                     elsif Zero_Pos = 0 then Hash_Pos
                     elsif Hash_Pos < Zero_Pos then Hash_Pos
                     else Zero_Pos);
               begin
                  if Symbol_Pos > 0
                    and then (Digit_Pos = 0 or else Symbol_Pos < Digit_Pos)
                  then
                     Append_CSV (Result, Locale);
                  end if;
               exception
                  when others =>
                     Add_Error
                       ("failed to derive CLDR currency placement policy for "
                        & Locale);
               end;
            end loop;

            return S (Result);
         end Symbol_First_Locales;

         function Day_Month_Year_Locales return String is
            Result : US.Unbounded_String;
            Date_Root : constant String := "upstream/cldr-json/cldr-dates-full/main";
            Search    : Ada.Directories.Search_Type;
            Dir_Entry : Ada.Directories.Directory_Entry_Type;
            Filter    : constant Ada.Directories.Filter_Type :=
              [Ada.Directories.Ordinary_File => False,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => False];
         begin
            if not Project_Tools.Files.Directory_Exists (Date_Root) then
               Add_Error ("missing CLDR full date source directory");
               return "";
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
                     declare
                        Text : constant String :=
                          Project_Tools.Files.Read_Raw_File (Path);
                        Available : constant String :=
                          Object_Field_Object (Text, "availableFormats");
                        Pattern : constant String :=
                          Project_Tools.JSON.Object_Field_Value
                            (Available, "yMd");
                     begin
                        if First_Pattern_Field (Pattern) = 'd' then
                           Append_CSV (Result, Locale);
                        end if;
                     end;
                  end if;
               exception
                  when others =>
                     Add_Error
                       ("failed to derive CLDR date order policy for " & Locale);
               end;
            end loop;
            Ada.Directories.End_Search (Search);

            return S (Result);
         exception
            when others =>
               if Ada.Directories.More_Entries (Search) then
                  Ada.Directories.End_Search (Search);
               end if;
               raise;
         end Day_Month_Year_Locales;
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
            & Indian_Grouping_Locales
            & """,""suffix"":"""
            & "-IN"
            & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""day_month_year"",""locales"":"""
            & Day_Month_Year_Locales
            & """}");
         Emit_JSON
           ("{""type"":""policy"",""name"":""symbol_first"",""locales"":"""
            & Symbol_First_Locales
            & """}");
      end Emit_Full_Number_Rows;

      procedure Emit_Full_Currency_Name_Rows is
         Root           : constant String := "upstream/cldr-json/cldr-numbers-full/main";
         Currency_Source : constant String :=
           Project_Tools.Files.Read_Raw_File
             ("upstream/cldr-json/cldr-core/supplemental/currencyData.json");
         Fractions      : constant String :=
           Object_Field_Object (Currency_Source, "fractions");
         pragma Unreferenced (Fractions);
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
            Currency_Data : constant String := Object_Field_Object (Text, "currencies");
            English_Text : constant String :=
              Object_Field_Object
                (Project_Tools.Files.Read_Raw_File
                   ("upstream/cldr-json/cldr-numbers-full/main/en/currencies.json"),
                 "currencies");
            Payload : US.Unbounded_String;

            procedure Add_Code (Code : String; Value : String) is
               pragma Unreferenced (Value);
               Object : constant String := Object_Field_Object (Currency_Data, Code);
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
               if Code /= "DEFAULT" and then Fallback /= "" then
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
            end Add_Code;
         begin
            For_Each_Object_Field (English_Text, Add_Code'Access);

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
         pragma Unreferenced (Emit_Plural_Family);

         function Rule_Body (Rule : String) return String is
         begin
            for Index in Rule'Range loop
               if Rule (Index) = '@' then
                  if Index = Rule'First then
                     return "";
                  else
                     return Rule (Rule'First .. Index - 1);
                  end if;
               end if;
            end loop;

            return Rule;
         end Rule_Body;

         function Plural_Signature (Locale_Rules : String) return String is
         begin
            return "zero="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-zero"))
              & ";one="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-one"))
              & ";two="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-two"))
              & ";few="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-few"))
              & ";many="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-many"))
              & ";other="
              & Rule_Body
                  (Project_Tools.JSON.Object_Field_Value
                     (Locale_Rules, "pluralRule-count-other"));
         end Plural_Signature;

         function Matching_Plural_Locales
           (Root : String;
            Representative : String) return String
         is
            Reference : constant String :=
              Object_Field_Object (Root, Representative);
            Reference_Signature : constant String := Plural_Signature (Reference);
            Result : US.Unbounded_String;

            procedure Add_Match (Locale : String; Rules : String) is
            begin
               if Plural_Signature (Rules) = Reference_Signature then
                  if US.Length (Result) > 0 then
                     US.Append (Result, ",");
                  end if;
                  US.Append (Result, Locale);
               end if;
            end Add_Match;
         begin
            if Reference = "" then
               Add_Error
                 ("missing representative CLDR plural rules for "
                  & Representative);
               return "";
            end if;

            For_Each_Object_Field (Root, Add_Match'Access);
            return S (Result);
         end Matching_Plural_Locales;

         procedure Emit_Real_Plural_Family
           (Kind : String;
            Family : String;
            Root : String;
            Representative : String)
         is
            Locales : constant String :=
              Matching_Plural_Locales (Root, Representative);
         begin
            if Locales = "" then
               Add_Error
                 ("empty real CLDR plural family " & Kind & "/" & Family);
            else
               Emit_JSON
                 ("{""type"":""plural_family"",""kind"":""" & Kind
                  & """,""family"":""" & Family
                  & """,""locales"":""" & Locales & """}");
            end if;
         end Emit_Real_Plural_Family;
      begin
         declare
            Plural_Source : constant String :=
              Project_Tools.Files.Read_Raw_File
                ("upstream/cldr-json/cldr-core/supplemental/plurals.json");
            Ordinal_Source : constant String :=
              Project_Tools.Files.Read_Raw_File
                ("upstream/cldr-json/cldr-core/supplemental/ordinals.json");
            Cardinal_Root : constant String :=
              Object_Field_Object (Plural_Source, "plurals-type-cardinal");
            Ordinal_Root : constant String :=
              Object_Field_Object (Ordinal_Source, "plurals-type-ordinal");
         begin
            Emit_Real_Plural_Family ("cardinal", "n-is-1", Cardinal_Root, "af");
            Emit_Real_Plural_Family ("cardinal", "one-is-1", Cardinal_Root, "en");
            Emit_Real_Plural_Family ("cardinal", "one-is-0-or-1", Cardinal_Root, "ak");
            Emit_Real_Plural_Family ("cardinal", "i-0-or-n-1", Cardinal_Root, "am");
            Emit_Real_Plural_Family ("cardinal", "n-one-two", Cardinal_Root, "iu");
            Emit_Real_Plural_Family ("cardinal", "n-is-1-compact-many", Cardinal_Root, "es");
            Emit_Real_Plural_Family ("cardinal", "i-0-1-compact-many", Cardinal_Root, "fr");
            Emit_Real_Plural_Family ("cardinal", "i-0-to-1-compact-many", Cardinal_Root, "pt");
            Emit_Real_Plural_Family ("cardinal", "i-1-v0-compact-many", Cardinal_Root, "it");
            Emit_Real_Plural_Family ("cardinal", "ru", Cardinal_Root, "ru");
            Emit_Real_Plural_Family ("cardinal", "pl", Cardinal_Root, "pl");
            Emit_Real_Plural_Family ("cardinal", "cs", Cardinal_Root, "cs");
            Emit_Real_Plural_Family ("cardinal", "ar", Cardinal_Root, "ar");
            Emit_Real_Plural_Family ("cardinal", "ro", Cardinal_Root, "ro");
            Emit_Real_Plural_Family ("cardinal", "lt", Cardinal_Root, "lt");
            Emit_Real_Plural_Family ("cardinal", "sl", Cardinal_Root, "sl");
            Emit_Real_Plural_Family ("cardinal", "sr", Cardinal_Root, "sr");
            Emit_Real_Plural_Family ("cardinal", "cy", Cardinal_Root, "cy");
            Emit_Real_Plural_Family ("cardinal", "zero-one", Cardinal_Root, "cv");
            Emit_Real_Plural_Family ("cardinal", "ceb", Cardinal_Root, "ceb");
            Emit_Real_Plural_Family ("cardinal", "ff", Cardinal_Root, "ff");
            Emit_Real_Plural_Family ("cardinal", "dsb", Cardinal_Root, "dsb");
            Emit_Real_Plural_Family ("cardinal", "lv", Cardinal_Root, "lv");
            Emit_Real_Plural_Family ("cardinal", "be", Cardinal_Root, "be");
            Emit_Real_Plural_Family ("cardinal", "br", Cardinal_Root, "br");
            Emit_Real_Plural_Family ("cardinal", "da", Cardinal_Root, "da");
            Emit_Real_Plural_Family ("cardinal", "ga", Cardinal_Root, "ga");
            Emit_Real_Plural_Family ("cardinal", "gd", Cardinal_Root, "gd");
            Emit_Real_Plural_Family ("cardinal", "gv", Cardinal_Root, "gv");
            Emit_Real_Plural_Family ("cardinal", "he", Cardinal_Root, "he");
            Emit_Real_Plural_Family ("cardinal", "is", Cardinal_Root, "is");
            Emit_Real_Plural_Family ("cardinal", "kw", Cardinal_Root, "kw");
            Emit_Real_Plural_Family ("cardinal", "lag", Cardinal_Root, "lag");
            Emit_Real_Plural_Family ("cardinal", "mk", Cardinal_Root, "mk");
            Emit_Real_Plural_Family ("cardinal", "mt", Cardinal_Root, "mt");
            Emit_Real_Plural_Family ("cardinal", "shi", Cardinal_Root, "shi");
            Emit_Real_Plural_Family ("cardinal", "si", Cardinal_Root, "si");
            Emit_Real_Plural_Family ("cardinal", "tzm", Cardinal_Root, "tzm");
            Emit_Real_Plural_Family ("ordinal", "en-ordinal", Ordinal_Root, "en");
            Emit_Real_Plural_Family ("ordinal", "n-one-ordinal", Ordinal_Root, "fil");
            Emit_Real_Plural_Family ("ordinal", "it-ordinal", Ordinal_Root, "it");
            Emit_Real_Plural_Family ("ordinal", "indic-ordinal", Ordinal_Root, "as");
            Emit_Real_Plural_Family ("ordinal", "hi-ordinal", Ordinal_Root, "hi");
            Emit_Real_Plural_Family ("ordinal", "az-ordinal", Ordinal_Root, "az");
            Emit_Real_Plural_Family ("ordinal", "be-ordinal", Ordinal_Root, "be");
            Emit_Real_Plural_Family ("ordinal", "blo-ordinal", Ordinal_Root, "blo");
            Emit_Real_Plural_Family ("ordinal", "ca-ordinal", Ordinal_Root, "ca");
            Emit_Real_Plural_Family ("ordinal", "cy-ordinal", Ordinal_Root, "cy");
            Emit_Real_Plural_Family ("ordinal", "gd-ordinal", Ordinal_Root, "gd");
            Emit_Real_Plural_Family ("ordinal", "hu-ordinal", Ordinal_Root, "hu");
            Emit_Real_Plural_Family ("ordinal", "ka-ordinal", Ordinal_Root, "ka");
            Emit_Real_Plural_Family ("ordinal", "kk-ordinal", Ordinal_Root, "kk");
            Emit_Real_Plural_Family ("ordinal", "kw-ordinal", Ordinal_Root, "kw");
            Emit_Real_Plural_Family ("ordinal", "lij-ordinal", Ordinal_Root, "lij");
            Emit_Real_Plural_Family ("ordinal", "mk-ordinal", Ordinal_Root, "mk");
            Emit_Real_Plural_Family ("ordinal", "mr-ordinal", Ordinal_Root, "mr");
            Emit_Real_Plural_Family ("ordinal", "ne-ordinal", Ordinal_Root, "ne");
            Emit_Real_Plural_Family ("ordinal", "or-ordinal", Ordinal_Root, "or");
            Emit_Real_Plural_Family ("ordinal", "sq-ordinal", Ordinal_Root, "sq");
            Emit_Real_Plural_Family ("ordinal", "sv-ordinal", Ordinal_Root, "sv");
            Emit_Real_Plural_Family ("ordinal", "tk-ordinal", Ordinal_Root, "tk");
            Emit_Real_Plural_Family ("ordinal", "uk-ordinal", Ordinal_Root, "uk");
         end;
         return;
      end Emit_Migrated_Supplemental_Rows;

      procedure Emit_Migrated_Currency_Rows is
         Source : constant String :=
           Project_Tools.Files.Read_Raw_File
             ("upstream/cldr-json/cldr-core/supplemental/currencyData.json");
         Fractions : constant String := Object_Field_Object (Source, "fractions");
         English_Currencies : constant String :=
           Object_Field_Object
             (Project_Tools.Files.Read_Raw_File
                ("upstream/cldr-json/cldr-numbers-full/main/en/currencies.json"),
              "currencies");
         Default_Fraction : constant String := Object_Field_Object (Fractions, "DEFAULT");

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

         procedure Emit_Currency (Code : String; Value : String) is
            Fraction : constant String :=
              (if Object_Field_Object (Fractions, Code) /= ""
               then Object_Field_Object (Fractions, Code)
               else Default_Fraction);
            Units : constant String :=
              Project_Tools.JSON.Object_Field_Value (Fraction, "_digits");
            Cash_Digits : constant String :=
              Project_Tools.JSON.Object_Field_Value (Fraction, "_cashDigits");
            Cash_Rounding : constant String :=
              Project_Tools.JSON.Object_Field_Value (Fraction, "_cashRounding");
            Cash : constant String :=
              (if Cash_Rounding /= "" and then Cash_Rounding /= "0" then Cash_Rounding
               elsif Cash_Digits /= "" and then Cash_Digits /= Units then Cash_Digits
               else "1");
            Symbol : constant String :=
              Project_Tools.JSON.Object_Field_Value (Value, "symbol");
            Narrow : constant String :=
              Project_Tools.JSON.Object_Field_Value (Value, "symbol-alt-narrow");
            Name : constant String :=
              Project_Tools.JSON.Object_Field_Value (Value, "displayName");
         begin
            if Code = "DEFAULT" then
               return;
            elsif Units = "" then
               Add_Error ("missing CLDR currency fraction digits for " & Code);
            else
               Emit_JSON
                 ("{""type"":""currency"",""code"":""" & Code
                  & """,""digits"":""" & Units
                  & """,""cash"":""" & Cash
                  & """,""symbol"":""" & (if Symbol = "" then Code else Symbol)
                  & """,""narrow"":""" & (if Narrow = "" then (if Symbol = "" then Code else Symbol) else Narrow)
                  & """,""name"":""" & Display_Name (Code, (if Name = "" then Code else Name)) & """}");
            end if;
         end Emit_Currency;
      begin
         if Fractions = "" then
            Add_Error ("missing CLDR currency fractions");
         else
            For_Each_Object_Field (English_Currencies, Emit_Currency'Access);
         end if;
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

         --  The four dateFormats styles, straight from CLDR. Without these the
         --  generated Date_Style_Pattern has to guess a locale's date order from
         --  a day-month-year flag and hand back one of two Western shapes, so a
         --  locale whose long form is neither -- Thai writes "d MMMM y", with no
         --  comma and no point -- could not be rendered at all.
         procedure Emit_Date_Style_Pattern_Rows (Locale : String) is
            --  Calendars carry their own date formats, and the difference is not
            --  cosmetic: Thai gregorian long is "d MMMM G y" but Thai buddhist
            --  long is "d MMMM y" -- the era belongs to one and not the other.
            --  A gregorian-only table would put an era on every buddhist date.
            type Constant_String_Access is access constant String;
            type Calendar_Source is record
               Name    : Constant_String_Access;
               Source  : Constant_String_Access;
            end record;

            Calendars : constant array (1 .. 9) of Calendar_Source :=
              [(new String'("gregorian"), new String'("cldr-dates-full")),
               (new String'("buddhist"),  new String'("cldr-cal-buddhist-full")),
               (new String'("japanese"),  new String'("cldr-cal-japanese-full")),
               (new String'("persian"),   new String'("cldr-cal-persian-full")),
               (new String'("coptic"),    new String'("cldr-cal-coptic-full")),
               (new String'("ethiopic"),  new String'("cldr-cal-ethiopic-full")),
               (new String'("hebrew"),    new String'("cldr-cal-hebrew-full")),
               (new String'("indian"),    new String'("cldr-cal-indian-full")),
               (new String'("roc"),       new String'("cldr-cal-roc-full"))];

            procedure Emit_Calendar (Calendar : String; Pkg : String) is
               Path : constant String :=
                 "cldr-json/" & Pkg & "/main/" & Locale
                 & "/ca-" & Calendar & ".json";
               Text : constant String :=
                 (if Project_Tools.Files.File_Exists ("upstream/" & Path)
                  then Project_Tools.Files.Read_Raw_File ("upstream/" & Path)
                  else "");
               Main      : constant String := Object_Field_Object (Text, "main");
               Locale_Obj : constant String :=
                 Object_Field_Object (Main, Locale);
               Dates     : constant String :=
                 Object_Field_Object (Locale_Obj, "dates");
               Cals      : constant String :=
                 Object_Field_Object (Dates, "calendars");
               Cal_Obj   : constant String :=
                 Object_Field_Object (Cals, Calendar);
               Formats   : constant String :=
                 Object_Field_Object (Cal_Obj, "dateFormats");

               procedure Emit_Style (Style : String) is
                  --  A style is normally a pattern string, but CLDR writes an
                  --  object when the pattern pins a numbering system -- Yiddish
                  --  hebrew is {"_value": "d 'ב'MMMM y", "_numbers": "hebr"}.
                  --  Take the pattern out of the object; the numbering system
                  --  is chosen elsewhere and is not part of the pattern.
                  Nested : constant String :=
                    Object_Field_Object (Formats, Style);
                  Raw : constant String :=
                    (if Nested /= ""
                     then Project_Tools.JSON.Object_Field_Value
                       (Nested, "_value")
                     else Project_Tools.JSON.Object_Field_Value
                       (Formats, Style));
                  Pattern : constant String := Raw;
                  Internal : constant String :=
                    (if Pattern /= "" then Internal_Pattern (Pattern) else "");
               begin
                  if Internal /= "" then
                     Emit_JSON
                       ("{""type"":""date_style_pattern"",""locale"":"""
                        & Locale & """,""calendar"":""" & Calendar
                        & """,""style"":""" & Style
                        & """,""pattern"":"""
                        & JSON_Escape (Internal) & """}");
                  end if;
               end Emit_Style;
            begin
               if Formats = "" then
                  return;
               end if;

               Emit_Style ("full");
               Emit_Style ("long");
               Emit_Style ("medium");
               Emit_Style ("short");
            end Emit_Calendar;
         begin
            for Source of Calendars loop
               Emit_Calendar (Source.Name.all, Source.Source.all);
            end loop;
         end Emit_Date_Style_Pattern_Rows;

         procedure Emit_List_Separator_Rows is
            function Trim_Spaces (Value : String) return String is
               First : Natural := Value'First;
               Last  : Natural := Value'Last;
            begin
               while First <= Last loop
                  if Value (First) = ' ' or else Value (First) = ASCII.HT then
                     First := First + 1;
                  elsif First + 1 <= Last
                    and then Value (First) = Character'Val (16#C2#)
                    and then Value (First + 1) = Character'Val (16#A0#)
                  then
                     First := First + 2;
                  elsif First + 2 <= Last
                    and then Value (First) = Character'Val (16#E2#)
                    and then Value (First + 1) = Character'Val (16#80#)
                    and then Value (First + 2) = Character'Val (16#AF#)
                  then
                     First := First + 3;
                  else
                     exit;
                  end if;
               end loop;
               while Last >= First loop
                  if Value (Last) = ' ' or else Value (Last) = ASCII.HT then
                     Last := Last - 1;
                  elsif Last >= First + 1
                    and then Value (Last - 1) = Character'Val (16#C2#)
                    and then Value (Last) = Character'Val (16#A0#)
                  then
                     Last := Last - 2;
                  elsif Last >= First + 2
                    and then Value (Last - 2) = Character'Val (16#E2#)
                    and then Value (Last - 1) = Character'Val (16#80#)
                    and then Value (Last) = Character'Val (16#AF#)
                  then
                     Last := Last - 3;
                  else
                     exit;
                  end if;
               end loop;

               if First > Last then
                  return "";
               else
                  return Value (First .. Last);
               end if;
            end Trim_Spaces;

            function Separator_From_Pattern (Pattern : String) return String is
               Left  : constant Natural := First_Index (Pattern, "{0}");
               Right : constant Natural := First_Index (Pattern, "{1}");
            begin
               if Left = 0 or else Right = 0 or else Right <= Left + 2 then
                  return "";
               else
                  return Pattern (Left + 3 .. Right - 1);
               end if;
            end Separator_From_Pattern;

            --  A unit name is its pattern with the value taken out, which works
            --  as long as the value leads: "{0} km/h" names "km/h". It does not
            --  work when the value sits inside the name -- Japanese writes
            --  "時速 {0} キロメートル" and Chinese "每小时{0}公里", where cutting
            --  the placeholder out both loses where the number goes and, in the
            --  Japanese case, leaves the two spaces that surrounded it.
            --
            --  For those, keep the pattern whole. A value carrying "{0}" is a
            --  pattern rather than a name, and the formatter renders it as one.
            --  Only compound units are treated this way: a simple unit name is
            --  read by callers that have no business substituting into it.
            function Unit_Name_From_Pattern
              (Pattern : String;
               Base    : String)
               return String
            is
               Marker : constant Natural := First_Index (Pattern, "{0}");
            begin
               if Marker = 0 then
                  return Pattern;
               elsif Marker = Pattern'First then
                  return Trim_Spaces (Pattern (Marker + 3 .. Pattern'Last));
               elsif Contains (Base, "-per-") then
                  return Pattern;
               elsif Marker + 2 = Pattern'Last then
                  return Trim_Spaces (Pattern (Pattern'First .. Marker - 1));
               else
                  return Trim_Spaces
                    (Pattern (Pattern'First .. Marker - 1)
                     & Pattern (Marker + 3 .. Pattern'Last));
               end if;
            end Unit_Name_From_Pattern;

            function Unit_Base (CLDR_Key : String) return String is
            begin
               for Index in CLDR_Key'Range loop
                  if CLDR_Key (Index) = '-' and then Index < CLDR_Key'Last then
                     return CLDR_Key (Index + 1 .. CLDR_Key'Last);
                  end if;
               end loop;

               return CLDR_Key;
            end Unit_Base;

            function Valid_Unit_Base (Value : String) return Boolean is
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
            end Valid_Unit_Base;

            function Locale_Object
              (Root : String;
               Locale : String;
               File_Name : String;
               Child : String) return String
            is
               Text : constant String :=
                 Project_Tools.Files.Read_Raw_File
                   (Root & "/" & Locale & "/" & File_Name);
               Main : constant String := Object_Field_Object (Text, "main");
               Locale_Data : constant String := Object_Field_Object (Main, Locale);
            begin
               return Object_Field_Object (Locale_Data, Child);
            end Locale_Object;

            procedure Emit_List_Part
              (Locale : String;
               Family : String;
               Part   : String;
               Pattern : String)
            is
               Value : constant String := Separator_From_Pattern (Pattern);
            begin
               if Value /= "" then
                  Emit_JSON
                    ("{""type"":""list_separator"",""locale"":"""
                     & Locale & """,""family"":""" & Family
                     & """,""part"":""" & Part
                     & """,""value"":""" & JSON_Escape (Value) & """}");
               end if;
            end Emit_List_Part;

            procedure Emit_List_Family
              (Locale : String;
               Patterns : String;
               Family : String;
               CLDR_Type : String)
            is
               Object : constant String :=
                 Object_Field_Object (Patterns, CLDR_Type);
               Middle : constant String :=
                 Project_Tools.JSON.Object_Field_Value (Object, "middle");
            begin
               if Object = "" then
                  return;
               end if;

               Emit_List_Part
                 (Locale, Family, "final",
                  Project_Tools.JSON.Object_Field_Value (Object, "end"));
               Emit_List_Part
                 (Locale, Family, "pair",
                  Project_Tools.JSON.Object_Field_Value (Object, "2"));
               Emit_List_Part
                 (Locale, Family, "start",
                  Project_Tools.JSON.Object_Field_Value (Object, "start"));
               Emit_List_Part (Locale, Family, "middle", Middle);
               Emit_List_Part (Locale, Family, "item", Middle);
            end Emit_List_Family;

            procedure Emit_Unit_Names
              (Locale : String;
               Width_Object : String;
               Width : String;
               Emit_Short : Boolean := False)
            is
               procedure Emit_Unit (Name : String; Value : String) is
                  Base : constant String := Unit_Base (Name);
                  Display : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Value, "displayName");

                  procedure Emit_Category (Category : String) is
                     Pattern : constant String :=
                       Project_Tools.JSON.Object_Field_Value
                         (Value, "unitPattern-count-" & Category);
                     Unit_Name : constant String :=
                       Unit_Name_From_Pattern (Pattern, Base);
                  begin
                     if Unit_Name /= "" then
                        Emit_JSON
                          ("{""type"":""unit_name"",""locale"":"""
                           & Locale & """,""base"":""" & Base
                           & """,""width"":""" & Width
                           & """,""category"":""" & Category
                           & """,""value"":""" & JSON_Escape (Unit_Name) & """}");
                        if Width = "unit-width-full-name"
                          and then
                            (Base = "day" or else Base = "week"
                             or else Base = "month" or else Base = "year")
                        then
                           Emit_JSON
                             ("{""type"":""relative_unit_category"",""locale"":"""
                              & Locale & """,""base"":""" & Base
                              & """,""category"":""" & Category
                              & """,""value"":""" & JSON_Escape (Unit_Name)
                              & """}");
                        end if;
                     end if;
                  end Emit_Category;
               begin
                  if not Valid_Unit_Base (Base) then
                     return;
                  end if;

                  if Object_Field_Object (Value, "per") /= "" then
                     return;
                  end if;

                  if Emit_Short and then Display /= "" then
                     Emit_JSON
                       ("{""type"":""unit_short"",""base"":""" & Base
                        & """,""value"":""" & JSON_Escape (Display) & """}");
                  end if;

                  Emit_Category ("zero");
                  Emit_Category ("one");
                  Emit_Category ("two");
                  Emit_Category ("few");
                  Emit_Category ("many");
                  Emit_Category ("other");
               end Emit_Unit;
            begin
               For_Each_Object_Field (Width_Object, Emit_Unit'Access);
            end Emit_Unit_Names;
         begin
            for Index in 1 .. Date_Count loop
               declare
                  Locale : constant String := S (Date_Locales (Index));
                  List_Path : constant String :=
                    "upstream/cldr-json/cldr-misc-full/main/"
                    & Locale & "/listPatterns.json";
                  Unit_Path : constant String :=
                    "upstream/cldr-json/cldr-units-full/main/"
                    & Locale & "/units.json";
               begin
                  if Project_Tools.Files.File_Exists (List_Path) then
                     declare
                        Patterns : constant String :=
                          Locale_Object
                            ("upstream/cldr-json/cldr-misc-full/main",
                             Locale, "listPatterns.json", "listPatterns");
                     begin
                        Emit_List_Family
                          (Locale, Patterns, "standard",
                           "listPattern-type-standard");
                        Emit_List_Family
                          (Locale, Patterns, "or", "listPattern-type-or");
                        Emit_List_Family
                          (Locale, Patterns, "unit", "listPattern-type-unit");
                     end;
                  end if;

                  if Project_Tools.Files.File_Exists (Unit_Path) then
                     declare
                        Units : constant String :=
                          Locale_Object
                            ("upstream/cldr-json/cldr-units-full/main",
                             Locale, "units.json", "units");
                        Long_Units : constant String :=
                          Object_Field_Object (Units, "long");
                        Short_Units : constant String :=
                          Object_Field_Object (Units, "short");
                        Narrow_Units : constant String :=
                          Object_Field_Object (Units, "narrow");
                        Per_Pattern : constant String :=
                          Project_Tools.JSON.Object_Field_Value
                            (Object_Field_Object (Long_Units, "per"),
                             "compoundUnitPattern");
                        Per_Value : constant String :=
                          Separator_From_Pattern (Per_Pattern);
                     begin
                        if Per_Value /= "" then
                           Emit_JSON
                             ("{""type"":""unit_separator"",""locale"":"""
                              & Locale & """,""part"":""per"",""value"":"""
                              & JSON_Escape (Per_Value) & """}");
                        end if;

                        Emit_Unit_Names
                          (Locale, Long_Units, "unit-width-full-name");
                        Emit_Unit_Names
                          (Locale, Short_Units, "unit-width-short",
                           Locale = "en");
                        Emit_Unit_Names
                          (Locale, Narrow_Units, "unit-width-narrow");
                     end;
                  end if;
               exception
                  when others =>
                     Add_Error
                       ("failed to emit CLDR list/unit rows for " & Locale);
               end;
            end loop;
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

         procedure Emit_Relative_Current_Rows (Locale : String) is
            Fields : constant String := Date_Fields_Object (Locale);

            procedure Emit_Base (Base : String; Width : String) is
               Key    : constant String := Relative_Field_Key (Base, Width);
               Object : constant String := Object_Field_Object (Fields, Key);
               Value  : constant String :=
                 Project_Tools.JSON.Object_Field_Value
                   (Object, "relative-type-0");
            begin
               if Value /= "" then
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

            procedure Emit_Offset (Direction : String) is
               Object : constant String :=
                 Object_Field_Object (Fields, "day");
               Group  : constant String :=
                 Object_Field_Object
                   (Object, "relativeTime-type-" & Direction);
               Pattern : constant String :=
                 Project_Tools.JSON.Object_Field_Value
                   (Group, "relativeTimePattern-count-other");
               Marker : constant Natural := First_Index (Pattern, "{0}");
               Prefix : constant String :=
                 (if Marker > Pattern'First
                  then Pattern (Pattern'First .. Marker - 1)
                  else "");
               Suffix : constant String :=
                 (if Marker > 0 and then Marker + 2 < Pattern'Last
                  then Pattern (Marker + 3 .. Pattern'Last)
                  else "");
            begin
               if Marker > 0 then
                  Emit_JSON
                    ("{""type"":""relative_offset"",""locale"":"""
                     & Locale & """,""offset"":""" & Direction
                     & """,""pattern"":"""
                     & JSON_Escape (Prefix & "{0}" & Suffix) & """}");
               end if;
            end Emit_Offset;

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

            Emit_Offset ("future");
            Emit_Offset ("past");
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

         procedure Emit_Month_Weekday_Rows (Locale : String) is
            Gregorian : constant String := Gregorian_Object (Locale);
            Months    : constant String := Object_Field_Object (Gregorian, "months");
            Month_Format : constant String := Object_Field_Object (Months, "format");
            Days      : constant String := Object_Field_Object (Gregorian, "days");
            Day_Format : constant String := Object_Field_Object (Days, "format");

            procedure Emit_Name_Row
              (Kind       : String;
               Start_Text : String;
               Values     : String)
            is
               Hex : constant String := Codepoint_Hex_List (Values);
            begin
               if Values /= "" and then Hex /= "" then
                  Emit_JSON
                    ("{""type"":""name_hex"",""kind"":""" & Kind
                     & """,""locale"":""" & Locale
                     & """,""start"":""" & Start_Text
                     & """,""values"":""" & Hex & """}");
               elsif Values /= "" then
                  Emit_JSON
                    ("{""type"":""name_set"",""kind"":""" & Kind
                     & """,""locale"":""" & Locale
                     & """,""start"":""" & Start_Text
                     & """,""values"":""" & JSON_Escape (Values) & """}");
               end if;
            end Emit_Name_Row;

            function Month_Values (Width : String) return String is
               Object : constant String := Object_Field_Object (Month_Format, Width);
               Result : US.Unbounded_String;
            begin
               for Month in 1 .. 12 loop
                  declare
                     Key   : constant String := Natural'Image (Month);
                     Value : constant String :=
                       Project_Tools.JSON.Object_Field_Value
                         (Object, Key (Key'First + 1 .. Key'Last));
                  begin
                     if Value = "" then
                        Add_Error
                          ("missing " & Width & " CLDR month "
                           & Key (Key'First + 1 .. Key'Last)
                           & " for locale " & Locale);
                        return "";
                     end if;

                     if Month > 1 then
                        US.Append (Result, "~");
                     end if;
                     US.Append (Result, Value);
                  end;
               end loop;

               return S (Result);
            end Month_Values;

            function Weekday_Values (Width : String) return String is
               Object : constant String := Object_Field_Object (Day_Format, Width);
               Result : US.Unbounded_String;

               procedure Add_Day (Key : String) is
                  Value : constant String :=
                    Project_Tools.JSON.Object_Field_Value (Object, Key);
               begin
                  if Value = "" then
                     Add_Error
                       ("missing " & Width & " CLDR weekday "
                        & Key & " for locale " & Locale);
                  else
                     if US.Length (Result) > 0 then
                        US.Append (Result, "~");
                     end if;
                     US.Append (Result, Value);
                  end if;
               end Add_Day;
            begin
               Add_Day ("sun");
               Add_Day ("mon");
               Add_Day ("tue");
               Add_Day ("wed");
               Add_Day ("thu");
               Add_Day ("fri");
               Add_Day ("sat");

               if Field_Count (S (Result), '~') /= 7 then
                  return "";
               end if;

               return S (Result);
            end Weekday_Values;
         begin
            Emit_Name_Row ("month_full", "1", Month_Values ("wide"));
            Emit_Name_Row ("month_short", "1", Month_Values ("abbreviated"));
            Emit_Name_Row ("weekday_full", "0", Weekday_Values ("wide"));
            Emit_Name_Row ("weekday_short", "0", Weekday_Values ("abbreviated"));
         end Emit_Month_Weekday_Rows;

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
               if Display /= "" then
                  Emit_JSON
                    ("{""type"":""zone_family_display"",""locale"":"""
                     & Locale & """,""family"":""" & Family
                     & """,""value"":""" & JSON_Escape (Display) & """}");
               end if;

               if Short_Generic /= ""
                 and then Short_Standard /= ""
                 and then Short_Daylight /= ""
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
                  if Display /= "" then
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
         Load_Date_Locales;
         for Index in 1 .. Date_Count loop
            declare
               Locale : constant String := S (Date_Locales (Index));
            begin
               Emit_Month_Weekday_Rows (Locale);
               Emit_Quarter_Rows (Locale);
               Emit_Day_Period_Rows (Locale);
               Emit_Relative_Current_Rows (Locale);
               Emit_Relative_Time_Pattern_Rows (Locale);
               Emit_Available_Format_Rows (Locale);
               Emit_Date_Style_Pattern_Rows (Locale);
               Emit_Time_Zone_Format_Rows (Locale);
               Emit_Time_Zone_Exemplar_Rows (Locale);
               Emit_Time_Zone_Metazone_Rows (Locale);
            end;
         end loop;
         Emit_List_Separator_Rows;
      end Emit_Migrated_Date_Name_Rows;
   begin
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Generated_Path);
      Emit_Header;
      Emit_Full_Number_Rows;
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
      pragma Unreferenced (Generated);
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
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Target_Path));
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
