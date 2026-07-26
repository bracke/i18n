with Ada.Exceptions;
with Ada.Command_Line;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.JSON;

procedure Import_CLDR_Raw is
   package US renames Ada.Strings.Unbounded;
   package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   Manifest_Path : constant String := "upstream/source_manifest.txt";
   Source_Path   : constant String := "upstream/cldr_export.jsonl";
   Target_Path   : constant String := "raw/cldr_records.txt";
   Generated_Path : constant String := Project_Tools.Files.Temp_Dir & "/i18n_cldr_records.generated.txt";

   Max_Keys : constant := 2_000_000;

   Errors              : Natural := 0;
   Key_Count           : Natural := 0;
   Keys                : String_Sets.Set;
   Source_Record_Count : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;
   pragma Unreferenced (S);

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
      Separator : Character := ',') return String
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

   function Field_Count (Line : String; Separator : Character := ',') return Natural is
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

   function Is_Even_Hex_Text (Value : String) return Boolean is
   begin
      return Value'Length > 0
        and then Value'Length mod 2 = 0
        and then Is_Hex_Text (Value);
   end Is_Even_Hex_Text;

   function Is_Currency_Code (Value : String) return Boolean is
   begin
      if Value'Length /= 3 then
         return False;
      end if;

      for C of Value loop
         if C not in 'A' .. 'Z' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Currency_Code;

   function Is_Currency_Name_Payload (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;

      for Index in 1 .. Field_Count (Value, ';') loop
         declare
            Item  : constant String := Field (Value, Index, ';');
            Code  : constant String := Field (Item, 1, ':');
            Names : constant String := Field (Item, 2, ':');
            Zero  : constant String := Field (Names, 1, ',');
            One   : constant String := Field (Names, 2, ',');
            Two   : constant String := Field (Names, 3, ',');
            Few   : constant String := Field (Names, 4, ',');
            Many  : constant String := Field (Names, 5, ',');
            Other : constant String := Field (Names, 6, ',');
         begin
            if Field_Count (Item, ':') /= 2
              or else Field_Count (Names, ',') /= 6
              or else not Is_Currency_Code (Code)
              or else not Is_Even_Hex_Text (Zero)
              or else not Is_Even_Hex_Text (One)
              or else not Is_Even_Hex_Text (Two)
              or else not Is_Even_Hex_Text (Few)
              or else not Is_Even_Hex_Text (Many)
              or else not Is_Even_Hex_Text (Other)
            then
               return False;
            end if;
         end;
      end loop;

      return True;
   end Is_Currency_Name_Payload;

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

   function Is_Zone_Id (Value : String) return Boolean is
   begin
      if Value = "" then
         return False;
      end if;

      for C of Value loop
         if C = '|'
           or else C = ASCII.LF
           or else C = ASCII.CR
           or else C = '"'
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

   function Is_Hex_List (Value : String) return Boolean is
   begin
      if Value'Length = 0 then
         return False;
      end if;

      for Index in 1 .. Field_Count (Value, '~') loop
         if not Is_Hex_Text (Field (Value, Index, '~')) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Hex_List;

   function Has_Raw_Separator (Value : String) return Boolean is
   begin
      for C of Value loop
         if C = '|' or else C = ASCII.LF or else C = ASCII.CR then
            return True;
         end if;
      end loop;

      return False;
   end Has_Raw_Separator;

   function JSON_Value (Line : String; Name : String) return String is
   begin
      return Project_Tools.JSON.Object_Field_Value (Line, Name);
   end JSON_Value;

   function Valid_Value (Value : String) return Boolean is
   begin
      return Value /= "" and then not Has_Raw_Separator (Value);
   end Valid_Value;

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

   procedure Add_Key (Key : String; Line_Number : Positive) is
   begin
      if Key = "" then
         Add_Line_Error (Line_Number, "cannot derive staged CLDR key");
         return;
      end if;

      if Keys.Contains (Key) then
         Add_Line_Error (Line_Number, "duplicate staged CLDR key: " & Key);
         return;
      end if;

      if Key_Count = Max_Keys then
         Add_Line_Error (Line_Number, "too many staged CLDR keys");
         return;
      end if;

      Key_Count := Key_Count + 1;
      Keys.Include (Key);
   end Add_Key;

   procedure Validate_Source_Manifest is
      Version      : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "cldr_version");
      Source_Family : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_family");
      Export       : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "export");
      Count_Text   : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "record_count");
   begin
      if Version = "" then
         Add_Error ("staged CLDR source manifest must declare cldr_version");
      end if;

      if Source_Family /= "cldr-json" then
         Add_Error ("staged CLDR source manifest must declare source_family=cldr-json");
      end if;

      if Export /= Source_Path then
         Add_Error ("staged CLDR source manifest export path does not match importer source");
      end if;

      if not Is_Decimal_Text (Count_Text) then
         Add_Error ("staged CLDR source manifest must declare decimal record_count");
      elsif Source_Record_Count /= Natural'Value (Count_Text) then
         Add_Error
           ("staged CLDR source record count mismatch: expected "
            & Count_Text & " got" & Natural'Image (Source_Record_Count));
      end if;
   end Validate_Source_Manifest;

   function Generate return String is
      Output      : Ada.Text_IO.File_Type;
      Seen_Output : Boolean := False;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Output, Text);
      end L;

      procedure Emit_Header is
      begin
         L ("# Deterministic raw CLDR extract fixture.");
         L ("#");
         L ("# Generated from cldr/upstream/cldr_export.jsonl by cldr/src/import_cldr_raw.adb.");
         L ("# This file stages the narrow upstream CLDR records currently covered by the");
         L ("# shipped subset. The extractor normalizes these records into");
         L ("# cldr/import/normalized_cldr.txt.");
         L;
      end Emit_Header;

      procedure Emit_Blank is
      begin
         if Seen_Output then
            L;
         end if;
      end Emit_Blank;

      procedure Emit_Record (Text : String) is
      begin
         L (Text);
         Seen_Output := True;
         Source_Record_Count := Source_Record_Count + 1;
      end Emit_Record;

      procedure Parse_Line (Line : String; Line_Number : Positive) is
         Kind : constant String := JSON_Value (Line, "type");
      begin
         if Line'Length = 0 then
            Emit_Blank;
            return;
         elsif Line (Line'First) = '#' then
            return;
         elsif Kind = "symbol" then
            declare
               Symbol_Kind : constant String := JSON_Value (Line, "kind");
               Locales     : constant String := JSON_Value (Line, "locales");
               Value       : constant String := JSON_Value (Line, "value");
            begin
               if (Symbol_Kind /= "decimal" and then Symbol_Kind /= "group")
                 or else not Valid_Value (Locales)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged symbol record");
                  return;
               end if;
               Add_Key ("symbol|" & Symbol_Kind & "|" & Locales, Line_Number);
               Emit_Record ("symbol|" & Symbol_Kind & "|" & Locales & "|" & Value);
            end;
         elsif Kind = "policy" then
            declare
               Name    : constant String := JSON_Value (Line, "name");
               Locales : constant String := JSON_Value (Line, "locales");
               Suffix  : constant String := JSON_Value (Line, "suffix");
            begin
               if Name = "indian_grouping" then
                  if not Valid_Value (Locales) or else not Valid_Value (Suffix) then
                     Add_Line_Error (Line_Number, "invalid staged indian_grouping policy");
                     return;
                  end if;
                  Add_Key ("policy|indian_grouping", Line_Number);
                  Emit_Record ("policy|indian_grouping|" & Locales & "|" & Suffix);
               elsif Name = "day_month_year" or else Name = "symbol_first" then
                  if not Valid_Value (Locales) then
                     Add_Line_Error (Line_Number, "invalid staged " & Name & " policy");
                     return;
                  end if;
                  Add_Key ("policy|" & Name, Line_Number);
                  Emit_Record ("policy|" & Name & "|" & Locales);
               else
                  Add_Line_Error (Line_Number, "unknown staged policy record");
                  return;
               end if;
            end;
         elsif Kind = "numbering_system" then
            declare
               Locale      : constant String := JSON_Value (Line, "locale");
               Digit_Codes : constant String := JSON_Value (Line, "digits");
            begin
               if not Valid_Value (Locale) or else Field_Count (Digit_Codes) /= 10 then
                  Add_Line_Error (Line_Number, "invalid staged numbering_system record");
                  return;
               end if;
               for Index in 1 .. 10 loop
                  if not Is_Hex_Text (Field (Digit_Codes, Index)) then
                     Add_Line_Error (Line_Number, "invalid staged numbering_system digit");
                     return;
                  end if;
               end loop;
               Add_Key ("numbering_system|" & Locale, Line_Number);
               Emit_Record ("numbering_system|" & Locale & "|" & Digit_Codes);
            end;
         elsif Kind = "name_set" then
            declare
               Name_Kind  : constant String := JSON_Value (Line, "kind");
               Locale     : constant String := JSON_Value (Line, "locale");
               Start_Text : constant String := JSON_Value (Line, "start");
               Values     : constant String := JSON_Value (Line, "values");
            begin
               if not Is_Name_Kind (Name_Kind)
                 or else not Valid_Value (Locale)
                 or else not Is_Decimal_Text (Start_Text)
                 or else not Valid_Value (Values)
               then
                  Add_Line_Error (Line_Number, "invalid staged name_set record");
                  return;
               end if;
               Add_Key ("name_set|" & Name_Kind & "|" & Locale, Line_Number);
               Emit_Record
                 ("name_set|" & Name_Kind & "|" & Locale & "|" & Start_Text & "|" & Values);
            end;
         elsif Kind = "name_hex" then
            declare
               Name_Kind  : constant String := JSON_Value (Line, "kind");
               Locale     : constant String := JSON_Value (Line, "locale");
               Start_Text : constant String := JSON_Value (Line, "start");
               Values     : constant String := JSON_Value (Line, "values");
            begin
               if not Is_Name_Kind (Name_Kind)
                 or else not Valid_Value (Locale)
                 or else not Is_Decimal_Text (Start_Text)
                 or else not Valid_Value (Values)
                 or else not Is_Hex_List (Values)
               then
                  Add_Line_Error (Line_Number, "invalid staged name_hex record");
                  return;
               end if;
               Add_Key ("name_set|" & Name_Kind & "|" & Locale, Line_Number);
               Emit_Record
                 ("name_hex|" & Name_Kind & "|" & Locale & "|" & Start_Text & "|" & Values);
            end;
         elsif Kind = "day_period" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Period : constant String := JSON_Value (Line, "period");
               Width  : constant String := JSON_Value (Line, "width");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Day_Period (Period)
                 or else not Is_Day_Period_Width (Width)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged day_period record");
                  return;
               end if;
               Add_Key
                 ("day_period|" & Locale & "|" & Period & "|" & Width,
                  Line_Number);
               Emit_Record
                 ("day_period|" & Locale & "|" & Period & "|" & Width
                 & "|" & Value);
            end;
         elsif Kind = "zone_display" or else Kind = "zone_exemplar" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Zone   : constant String := JSON_Value (Line, "zone");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Zone_Id (Zone)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged " & Kind & " record");
                  return;
               end if;
               Add_Key (Kind & "|" & Locale & "|" & Zone, Line_Number);
               Emit_Record (Kind & "|" & Locale & "|" & Zone & "|" & Value);
            end;
         elsif Kind = "zone_family_display" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Family : constant String := JSON_Value (Line, "family");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Zone_Family (Family)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged zone_family_display record");
                  return;
               end if;
               Add_Key ("zone_family_display|" & Locale & "|" & Family, Line_Number);
               Emit_Record
                 ("zone_family_display|" & Locale & "|" & Family & "|" & Value);
            end;
         elsif Kind = "zone_short_family" then
            declare
               Locale   : constant String := JSON_Value (Line, "locale");
               Family   : constant String := JSON_Value (Line, "family");
               Standard : constant String := JSON_Value (Line, "standard");
               Daylight : constant String := JSON_Value (Line, "daylight");
               Generic_Label : constant String := JSON_Value (Line, "generic");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Zone_Family (Family)
                 or else not Valid_Value (Standard)
                 or else not Valid_Value (Daylight)
                 or else not Valid_Value (Generic_Label)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged zone_short_family record");
                  return;
               end if;
               Add_Key ("zone_short_family|" & Locale & "|" & Family, Line_Number);
               Emit_Record
                 ("zone_short_family|" & Locale & "|" & Family & "|"
                  & Standard & "|" & Daylight & "|" & Generic_Label);
            end;
         elsif Kind = "zone_gmt_prefix"
           or else Kind = "zone_offset_separator"
           or else Kind = "zone_location_pattern"
         then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale) or else not Valid_Value (Value) then
                  Add_Line_Error
                    (Line_Number, "invalid staged " & Kind & " record");
                  return;
               end if;
               Add_Key (Kind & "|" & Locale, Line_Number);
               Emit_Record (Kind & "|" & Locale & "|" & Value);
            end;
         elsif Kind = "available_format" then
            declare
               Locale   : constant String := JSON_Value (Line, "locale");
               Skeleton : constant String := JSON_Value (Line, "skeleton");
               Pattern  : constant String := JSON_Value (Line, "pattern");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Skeleton_Key (Skeleton)
                 or else not Valid_Value (Pattern)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged available_format record");
                  return;
               end if;
               Add_Key
                 ("available_format|" & Locale & "|" & Skeleton,
                  Line_Number);
               Emit_Record
                 ("available_format|" & Locale & "|" & Skeleton
                  & "|" & Pattern);
            end;
         elsif Kind = "date_style_pattern" then
            declare
               Locale   : constant String := JSON_Value (Line, "locale");
               Calendar : constant String := JSON_Value (Line, "calendar");
               Style    : constant String := JSON_Value (Line, "style");
               Pattern  : constant String := JSON_Value (Line, "pattern");
            begin
               if not Valid_Value (Locale)
                 or else not Valid_Value (Calendar)
                 or else (Style /= "full" and then Style /= "long"
                          and then Style /= "medium" and then Style /= "short")
                 or else not Valid_Value (Pattern)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged date_style_pattern record");
                  return;
               end if;
               Add_Key
                 ("date_style_pattern|" & Locale & "|" & Calendar
                  & "|" & Style,
                  Line_Number);
               Emit_Record
                 ("date_style_pattern|" & Locale & "|" & Calendar
                  & "|" & Style & "|" & Pattern);
            end;
         elsif Kind = "list_separator" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Raw_Family : constant String := JSON_Value (Line, "family");
               Family : constant String :=
                 (if Raw_Family = "" then "standard" else Raw_Family);
               Part   : constant String := JSON_Value (Line, "part");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_List_Separator_Family (Family)
                 or else not Is_List_Separator_Part (Part)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged list_separator record");
                  return;
               end if;
               Add_Key
                 ("list_separator|" & Locale & "|" & Family & "|" & Part,
                  Line_Number);
               Emit_Record
                 ("list_separator|" & Locale & "|" & Family
                  & "|" & Part & "|" & Value);
            end;
         elsif Kind = "unit_separator" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Part   : constant String := JSON_Value (Line, "part");
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Unit_Separator_Part (Part)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged unit_separator record");
                  return;
               end if;
               Add_Key
                 ("unit_separator|" & Locale & "|" & Part,
                  Line_Number);
               Emit_Record
                 ("unit_separator|" & Locale & "|" & Part & "|" & Value);
            end;
         elsif Kind = "unit_short" then
            declare
               Base  : constant String := JSON_Value (Line, "base");
               Value : constant String := JSON_Value (Line, "value");
            begin
               if not Is_Unit_Base (Base)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged unit_short record");
                  return;
               end if;
               Add_Key ("unit_short|" & Base, Line_Number);
               Emit_Record ("unit_short|" & Base & "|" & Value);
            end;
         elsif Kind = "unit_name" then
            declare
               Locale   : constant String := JSON_Value (Line, "locale");
               Base     : constant String := JSON_Value (Line, "base");
               Width    : constant String := JSON_Value (Line, "width");
               Category : constant String := JSON_Value (Line, "category");
               Value    : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Unit_Base (Base)
                 or else not Is_Relative_Width (Width)
                 or else not Is_Plural_Category (Category)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged unit_name record");
                  return;
               end if;
               Add_Key
                 ("unit_name|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category,
                  Line_Number);
               Emit_Record
                 ("unit_name|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category & "|" & Value);
            end;
         elsif Kind = "relative_current" then
            declare
               Locale : constant String := JSON_Value (Line, "locale");
               Base   : constant String := JSON_Value (Line, "base");
               Width  : constant String :=
                 (if JSON_Value (Line, "width") = ""
                  then "unit-width-full-name"
                  else JSON_Value (Line, "width"));
               Value  : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Relative_Base (Base)
                 or else not Is_Relative_Width (Width)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error (Line_Number, "invalid staged relative_current record");
                  return;
               end if;
               Add_Key
                 ("relative_current|" & Locale & "|" & Base & "|" & Width,
                  Line_Number);
               Emit_Record
                 ("relative_current|" & Locale & "|" & Base & "|"
                  & Width & "|" & Value);
            end;
         elsif Kind = "relative_offset" then
            declare
               Locale  : constant String := JSON_Value (Line, "locale");
               Offset  : constant String := JSON_Value (Line, "offset");
               Pattern : constant String := JSON_Value (Line, "pattern");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Relative_Offset (Offset)
                 or else not Valid_Value (Pattern)
                 or else not Contains (Pattern, "{0}")
               then
                  Add_Line_Error (Line_Number, "invalid staged relative_offset record");
                  return;
               end if;
               Add_Key
                 ("relative_offset|" & Locale & "|" & Offset,
                  Line_Number);
               Emit_Record
                 ("relative_offset|" & Locale & "|" & Offset & "|" & Pattern);
            end;
         elsif Kind = "relative_unit_category" then
            declare
               Locale   : constant String := JSON_Value (Line, "locale");
               Base     : constant String := JSON_Value (Line, "base");
               Category : constant String := JSON_Value (Line, "category");
               Value    : constant String := JSON_Value (Line, "value");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Relative_Base (Base)
                 or else not Is_Plural_Category (Category)
                 or else not Valid_Value (Value)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged relative_unit_category record");
                  return;
               end if;
               Add_Key
                 ("relative_unit_category|" & Locale & "|" & Base & "|" & Category,
                  Line_Number);
               Emit_Record
                 ("relative_unit_category|" & Locale & "|" & Base & "|"
                  & Category & "|" & Value);
            end;
         elsif Kind = "relative_time_pattern" then
            declare
               Locale    : constant String := JSON_Value (Line, "locale");
               Base      : constant String := JSON_Value (Line, "base");
               Width     : constant String :=
                 (if JSON_Value (Line, "width") = ""
                  then "unit-width-full-name"
                  else JSON_Value (Line, "width"));
               Direction : constant String := JSON_Value (Line, "direction");
               Category  : constant String := JSON_Value (Line, "category");
               Pattern   : constant String := JSON_Value (Line, "pattern");
            begin
               if not Valid_Value (Locale)
                 or else not Is_Relative_Base (Base)
                 or else not Valid_Value (Width)
                 or else not Is_Relative_Offset (Direction)
                 or else not Is_Plural_Category (Category)
                 or else not Valid_Value (Pattern)
                 or else not Contains (Pattern, "{0}")
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged relative_time_pattern record");
                  return;
               end if;
               Add_Key
                 ("relative_time_pattern|" & Locale & "|" & Base & "|"
                  & Width & "|"
                  & Direction & "|" & Category,
                  Line_Number);
               Emit_Record
                 ("relative_time_pattern|" & Locale & "|" & Base & "|"
                  & Width & "|"
                  & Direction & "|" & Category & "|" & Pattern);
            end;
         elsif Kind = "currency" then
            declare
               Code   : constant String := JSON_Value (Line, "code");
               Units  : constant String := JSON_Value (Line, "digits");
               Cash   : constant String := JSON_Value (Line, "cash");
               Symbol : constant String := JSON_Value (Line, "symbol");
               Narrow : constant String := JSON_Value (Line, "narrow");
               Name   : constant String := JSON_Value (Line, "name");
            begin
               if Code'Length /= 3
                 or else not Is_Decimal_Text (Units)
                 or else not Is_Decimal_Text (Cash)
                 or else not Valid_Value (Symbol)
                 or else not Valid_Value (Narrow)
                 or else not Valid_Value (Name)
               then
                  Add_Line_Error (Line_Number, "invalid staged currency record");
                  return;
               end if;
               Add_Key ("currency|" & Code, Line_Number);
               Emit_Record
                 ("currency|" & Code & "|" & Units & "|" & Cash & "|"
                  & Symbol & "|" & Narrow & "|" & Name);
            end;
         elsif Kind = "currency_name_payload" then
            declare
               Locale  : constant String := JSON_Value (Line, "locale");
               Payload : constant String := JSON_Value (Line, "payload");
            begin
               if not Valid_Value (Locale)
                 or else not Valid_Value (Payload)
                 or else not Is_Currency_Name_Payload (Payload)
               then
                  Add_Line_Error
                    (Line_Number, "invalid staged currency_name_payload record");
                  return;
               end if;
               Add_Key ("currency_name_payload|" & Locale, Line_Number);
               Emit_Record ("currency_name_payload|" & Locale & "|" & Payload);
            end;
         elsif Kind = "plural_family" then
            declare
               Plural_Kind : constant String := JSON_Value (Line, "kind");
               Family      : constant String := JSON_Value (Line, "family");
               Locales     : constant String := JSON_Value (Line, "locales");
            begin
               if (Plural_Kind /= "cardinal" and then Plural_Kind /= "ordinal")
                 or else not Valid_Value (Family)
                 or else not Valid_Value (Locales)
               then
                  Add_Line_Error (Line_Number, "invalid staged plural_family record");
                  return;
               end if;
               Add_Key ("plural_family|" & Plural_Kind & "|" & Family, Line_Number);
               Emit_Record ("plural_family|" & Plural_Kind & "|" & Family & "|" & Locales);
            end;
         else
            Add_Line_Error (Line_Number, "invalid staged CLDR JSONL record: " & Line);
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
        ("usage: import_cldr_raw [--check]" & ASCII.LF
         & "Imports raw/cldr_records.txt from upstream/cldr_export.jsonl.");
      return;
   end if;

   declare
      Generated : constant String := Generate;
      pragma Unreferenced (Generated);
   begin
      if Errors = 0 then
         Validate_Source_Manifest;
      end if;

      if Errors /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      elsif Has_Argument ("--check") then
         if File_Equals_File (Generated_Path, Target_Path) then
            Ada.Text_IO.Put_Line ("CLDR raw import is current");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "cldr/raw/cldr_records.txt is not current; run cldr/bin/import_cldr_raw");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      else
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Target_Path));
         Ada.Directories.Copy_File (Generated_Path, Target_Path);
         Ada.Text_IO.Put_Line ("imported cldr/raw/cldr_records.txt");
      end if;
   end;
exception
   when E : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to import raw CLDR data: " & Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Import_CLDR_Raw;
