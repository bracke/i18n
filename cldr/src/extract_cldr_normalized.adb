with Ada.Command_Line;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;

procedure Extract_CLDR_Normalized is
   package US renames Ada.Strings.Unbounded;
   package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");
   package String_Natural_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Source_Path   : constant String := "raw/cldr_records.txt";
   Coverage_Path : constant String := "raw/coverage.txt";
   Target_Path   : constant String := "import/normalized_cldr.txt";
   Coverage      : constant String := Project_Tools.Files.Read_Raw_File (Coverage_Path);
   Generated_Path : constant String := "/tmp/i18n_normalized_cldr.generated.txt";

   Max_Keys : constant := 2_000_000;
   Max_Coverage_Keys : constant := 400_000;

   Errors             : Natural := 0;
   Keys               : String_Sets.Set;
   Raw_Counts         : String_Natural_Maps.Map;
   Key_Count          : Natural := 0;
   Coverage_Keys      : array (1 .. Max_Coverage_Keys) of US.Unbounded_String;
   Coverage_Key_Count : Natural := 0;
   Currency_Count     : Natural := 0;
   Currency_Name_Count : Natural := 0;
   Decimal_Symbol_Count : Natural := 0;
   Group_Symbol_Count : Natural := 0;
   Unit_Short_Count   : Natural := 0;
   Month_Full_Count    : Natural := 0;
   Month_Short_Count   : Natural := 0;
   Weekday_Full_Count  : Natural := 0;
   Weekday_Short_Count : Natural := 0;
   Quarter_Count       : Natural := 0;
   Quarter_Short_Count : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   procedure Increment_Raw_Count (Kind : String) is
   begin
      if Raw_Counts.Contains (Kind) then
         Raw_Counts.Replace (Kind, Raw_Counts.Element (Kind) + 1);
      else
         Raw_Counts.Insert (Kind, 1);
      end if;
   end Increment_Raw_Count;

   function Raw_Count (Kind : String) return Natural is
   begin
      if Raw_Counts.Contains (Kind) then
         return Raw_Counts.Element (Kind);
      else
         return 0;
      end if;
   end Raw_Count;

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

   function Expected_Name_Count (Kind : String; Start : Natural) return Natural is
   begin
      if Kind = "month_full" or else Kind = "month_short" then
         return (if Start = 1 then 12 else 0);
      elsif Kind = "weekday_full" or else Kind = "weekday_short" then
         return (if Start = 0 then 7 else 0);
      elsif Kind = "quarter" or else Kind = "quarter_short" then
         return (if Start = 1 then 4 else 0);
      else
         return 0;
      end if;
   end Expected_Name_Count;

   function Name_Set_Count (Kind : String) return Natural is
   begin
      if Kind = "month_full" then
         return Month_Full_Count;
      elsif Kind = "month_short" then
         return Month_Short_Count;
      elsif Kind = "weekday_full" then
         return Weekday_Full_Count;
      elsif Kind = "weekday_short" then
         return Weekday_Short_Count;
      elsif Kind = "quarter" then
         return Quarter_Count;
      elsif Kind = "quarter_short" then
         return Quarter_Short_Count;
      else
         return 0;
      end if;
   end Name_Set_Count;

   procedure Increment_Name_Set_Count (Kind : String) is
   begin
      if Kind = "month_full" then
         Month_Full_Count := Month_Full_Count + 1;
      elsif Kind = "month_short" then
         Month_Short_Count := Month_Short_Count + 1;
      elsif Kind = "weekday_full" then
         Weekday_Full_Count := Weekday_Full_Count + 1;
      elsif Kind = "weekday_short" then
         Weekday_Short_Count := Weekday_Short_Count + 1;
      elsif Kind = "quarter" then
         Quarter_Count := Quarter_Count + 1;
      elsif Kind = "quarter_short" then
         Quarter_Short_Count := Quarter_Short_Count + 1;
      end if;
   end Increment_Name_Set_Count;

   function Symbol_Count (Kind : String) return Natural is
   begin
      if Kind = "decimal" then
         return Decimal_Symbol_Count;
      elsif Kind = "group" then
         return Group_Symbol_Count;
      else
         return 0;
      end if;
   end Symbol_Count;

   procedure Increment_Symbol_Count (Kind : String) is
   begin
      if Kind = "decimal" then
         Decimal_Symbol_Count := Decimal_Symbol_Count + 1;
      elsif Kind = "group" then
         Group_Symbol_Count := Group_Symbol_Count + 1;
      end if;
   end Increment_Symbol_Count;

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
         Add_Line_Error (Line_Number, "cannot derive raw CLDR key");
         return;
      end if;

      if Keys.Contains (Key) then
         Add_Line_Error (Line_Number, "duplicate raw CLDR key: " & Key);
         return;
      end if;

      if Key_Count = Max_Keys then
         Add_Line_Error (Line_Number, "too many raw CLDR keys");
         return;
      end if;

      Key_Count := Key_Count + 1;
      Keys.Include (Key);
   end Add_Key;

   function Has_Key (Key : String) return Boolean is
   begin
      return Keys.Contains (Key);
   end Has_Key;

   procedure Require_Key (Key : String; Line_Number : Positive) is
   begin
      if not Has_Key (Key) then
         Add_Line_Error (Line_Number, "missing raw CLDR coverage key: " & Key);
      end if;
   end Require_Key;

   function Has_Empty_Field (Line : String) return Boolean is
   begin
      for Index in 1 .. Field_Count (Line) loop
         if Field (Line, Index) = "" then
            return True;
         end if;
      end loop;

      return False;
   end Has_Empty_Field;

   procedure Add_Coverage_Key (Key : String; Line_Number : Positive) is
   begin
      for Index in 1 .. Coverage_Key_Count loop
         if S (Coverage_Keys (Index)) = Key then
            Add_Line_Error (Line_Number, "duplicate raw CLDR coverage requirement: " & Key);
            return;
         end if;
      end loop;

      if Coverage_Key_Count = Max_Coverage_Keys then
         Add_Line_Error (Line_Number, "too many raw CLDR coverage requirements");
         return;
      end if;

      Coverage_Key_Count := Coverage_Key_Count + 1;
      Coverage_Keys (Coverage_Key_Count) := US.To_Unbounded_String (Key);
   end Add_Coverage_Key;

   procedure Parse_Coverage_Line (Line : String; Line_Number : Positive) is
      Kind : constant String := Field (Line, 1);
   begin
      if Line'Length = 0 or else Line (Line'First) = '#' then
         return;
      elsif Has_Empty_Field (Line) then
         Add_Line_Error (Line_Number, "invalid coverage row with empty field: " & Line);
         return;
      elsif Kind = "require_symbol" then
         if Field_Count (Line) /= 3 then
            Add_Line_Error (Line_Number, "invalid require_symbol row");
         else
            Add_Coverage_Key (Line, Line_Number);
            Require_Key ("symbol|" & Field (Line, 2) & "|" & Field (Line, 3), Line_Number);
         end if;
      elsif Kind = "require_raw_count" then
         if Field_Count (Line) /= 3
           or else Field (Line, 2) = ""
           or else not Is_Decimal_Text (Field (Line, 3))
         then
            Add_Line_Error (Line_Number, "invalid require_raw_count row");
         elsif Raw_Count (Field (Line, 2)) /= Decimal_Value (Field (Line, 3)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR record count mismatch for " & Field (Line, 2)
               & ": expected " & Field (Line, 3) & " got"
               & Natural'Image (Raw_Count (Field (Line, 2))));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_symbol_count" then
         if Field_Count (Line) /= 3
           or else (Field (Line, 2) /= "decimal" and then Field (Line, 2) /= "group")
           or else not Is_Decimal_Text (Field (Line, 3))
         then
            Add_Line_Error (Line_Number, "invalid require_symbol_count row");
         elsif Symbol_Count (Field (Line, 2)) /= Decimal_Value (Field (Line, 3)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR symbol count mismatch for " & Field (Line, 2)
               & ": expected " & Field (Line, 3) & " got"
               & Natural'Image (Symbol_Count (Field (Line, 2))));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_policy" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_policy row");
         else
            Add_Coverage_Key (Line, Line_Number);
            Require_Key ("policy|" & Field (Line, 2), Line_Number);
         end if;
      elsif Kind = "require_numbering_system" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_numbering_system row");
         else
            Add_Coverage_Key (Line, Line_Number);
            Require_Key ("numbering_system|" & Field (Line, 2), Line_Number);
         end if;
      elsif Kind = "require_name_locales" then
         if Field_Count (Line) /= 3 or else not Is_Name_Kind (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_name_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("name_set|" & Field (Line, 2) & "|" & Field (Field (Line, 3), Index, ','),
                  Line_Number);
            end loop;
         end if;
      elsif Kind = "require_name_count" then
         if Field_Count (Line) /= 3
           or else not Is_Name_Kind (Field (Line, 2))
           or else not Is_Decimal_Text (Field (Line, 3))
         then
            Add_Line_Error (Line_Number, "invalid require_name_count row");
         elsif Name_Set_Count (Field (Line, 2)) /= Decimal_Value (Field (Line, 3)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR name count mismatch for " & Field (Line, 2)
               & ": expected " & Field (Line, 3) & " got"
               & Natural'Image (Name_Set_Count (Field (Line, 2))));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_day_period_locales" then
         if Field_Count (Line) /= 2 and then Field_Count (Line) /= 3 then
            Add_Line_Error (Line_Number, "invalid require_day_period_locales row");
         elsif Field_Count (Line) = 2 then
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  for Period_Index in 1 .. 4 loop
                     declare
                        Period : constant String :=
                          (case Period_Index is
                             when 1 => "midnight",
                             when 2 => "noon",
                             when 3 => "am",
                             when others => "pm");
                     begin
                        Require_Key
                          ("day_period|" & Locale & "|" & Period & "|wide",
                           Line_Number);
                        Require_Key
                          ("day_period|" & Locale & "|" & Period & "|abbreviated",
                           Line_Number);
                     end;
                  end loop;
               end;
            end loop;
         else
            declare
               Requirement : constant String := Field (Line, 2);
               Locales     : constant String := Field (Line, 3);
            begin
               if Requirement /= "am_pm"
                 and then not Is_Day_Period (Requirement)
               then
                  Add_Line_Error
                    (Line_Number, "invalid require_day_period_locales period");
                  return;
               end if;

               Add_Coverage_Key (Line, Line_Number);
               for Index in 1 .. Field_Count (Locales, ',') loop
                  declare
                     Locale : constant String := Field (Locales, Index, ',');
                  begin
                     if Requirement = "am_pm" then
                        Require_Key
                          ("day_period|" & Locale & "|am|wide",
                           Line_Number);
                        Require_Key
                          ("day_period|" & Locale & "|am|abbreviated",
                           Line_Number);
                        Require_Key
                          ("day_period|" & Locale & "|pm|wide",
                           Line_Number);
                        Require_Key
                          ("day_period|" & Locale & "|pm|abbreviated",
                           Line_Number);
                     else
                        Require_Key
                          ("day_period|" & Locale & "|" & Requirement & "|wide",
                           Line_Number);
                        Require_Key
                          ("day_period|" & Locale & "|" & Requirement
                           & "|abbreviated",
                           Line_Number);
                     end if;
                  end;
               end loop;
            end;
         end if;
      elsif Kind = "require_list_separator_locales" then
         if Field_Count (Line) = 3
           and then Is_List_Separator_Part (Field (Line, 2))
         then
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("list_separator|" & Field (Field (Line, 3), Index, ',')
                  & "|standard|" & Field (Line, 2),
                  Line_Number);
            end loop;
         elsif Field_Count (Line) = 4
           and then Is_List_Separator_Family (Field (Line, 2))
           and then Is_List_Separator_Part (Field (Line, 3))
         then
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 4), ',') loop
               Require_Key
                 ("list_separator|" & Field (Field (Line, 4), Index, ',')
                  & "|" & Field (Line, 2) & "|" & Field (Line, 3),
                  Line_Number);
            end loop;
         else
            Add_Line_Error (Line_Number, "invalid require_list_separator_locales row");
         end if;
      elsif Kind = "require_available_format_locales" then
         if Field_Count (Line) /= 3 then
            Add_Line_Error
              (Line_Number, "invalid require_available_format_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Skeleton_Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Skeleton : constant String :=
                    Field (Field (Line, 2), Skeleton_Index, ',');
               begin
                  for Locale_Index in 1 .. Field_Count (Field (Line, 3), ',') loop
                     Require_Key
                       ("available_format|"
                        & Field (Field (Line, 3), Locale_Index, ',')
                        & "|" & Skeleton,
                        Line_Number);
                  end loop;
               end;
            end loop;
         end if;
      elsif Kind = "require_unit_separator_locales" then
         if Field_Count (Line) /= 3 or else not Is_Unit_Separator_Part (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_unit_separator_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("unit_separator|" & Field (Field (Line, 3), Index, ',')
                  & "|" & Field (Line, 2),
                  Line_Number);
            end loop;
         end if;
      elsif Kind = "require_unit_name_locale" then
         if Field_Count (Line) /= 3 or else Field (Line, 2) = "" then
            Add_Line_Error (Line_Number, "invalid require_unit_name_locale row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               declare
                  Base : constant String := Field (Field (Line, 3), Index, ',');
               begin
                  if not Is_Unit_Base (Base) then
                     Add_Line_Error (Line_Number, "invalid required unit name base");
                  else
                     Require_Key
                       ("unit_name|" & Field (Line, 2) & "|" & Base
                        & "|unit-width-full-name|one",
                        Line_Number);
                     Require_Key
                       ("unit_name|" & Field (Line, 2) & "|" & Base
                        & "|unit-width-full-name|other",
                        Line_Number);
                  end if;
               end;
            end loop;
         end if;
      elsif Kind = "require_relative_current_locales" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_relative_current_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  Require_Key
                    ("relative_current|" & Locale
                     & "|day|unit-width-full-name",
                     Line_Number);
                  Require_Key
                    ("relative_current|" & Locale
                     & "|week|unit-width-full-name",
                     Line_Number);
                  Require_Key
                    ("relative_current|" & Locale
                     & "|month|unit-width-full-name",
                     Line_Number);
                  Require_Key
                    ("relative_current|" & Locale
                     & "|year|unit-width-full-name",
                     Line_Number);
               end;
            end loop;
         end if;
      elsif Kind = "require_relative_day_pattern_locales" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error
              (Line_Number,
               "invalid require_relative_day_pattern_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  Require_Key
                    ("relative_time_pattern|" & Locale
                     & "|day|unit-width-full-name|future|other",
                     Line_Number);
                  Require_Key
                    ("relative_time_pattern|" & Locale
                     & "|day|unit-width-full-name|past|other",
                     Line_Number);
               end;
            end loop;
         end if;
      elsif Kind = "require_relative_offset_locales" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_relative_offset_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  Require_Key ("relative_offset|" & Locale & "|future", Line_Number);
                  Require_Key ("relative_offset|" & Locale & "|past", Line_Number);
               end;
            end loop;
         end if;
      elsif Kind = "require_relative_unit_category_locales" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error
              (Line_Number, "invalid require_relative_unit_category_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  for Base_Index in 1 .. 4 loop
                     declare
                        Base : constant String :=
                          (case Base_Index is
                             when 1 => "day",
                             when 2 => "week",
                             when 3 => "month",
                             when others => "year");
                     begin
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|one",
                           Line_Number);
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|few",
                           Line_Number);
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|many",
                           Line_Number);
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|other",
                           Line_Number);
                     end;
                  end loop;
               end;
            end loop;
         end if;
      elsif Kind = "require_relative_unit_display_locales" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error
              (Line_Number, "invalid require_relative_unit_display_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               declare
                  Locale : constant String := Field (Field (Line, 2), Index, ',');
               begin
                  for Base_Index in 1 .. 4 loop
                     declare
                        Base : constant String :=
                          (case Base_Index is
                             when 1 => "day",
                             when 2 => "week",
                             when 3 => "month",
                             when others => "year");
                     begin
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|one",
                           Line_Number);
                        Require_Key
                          ("relative_unit_category|" & Locale & "|" & Base
                           & "|other",
                           Line_Number);
                     end;
                  end loop;
               end;
            end loop;
         end if;
      elsif Kind = "require_unit_short_count" then
         if Field_Count (Line) /= 2 or else not Is_Decimal_Text (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_unit_short_count row");
         elsif Unit_Short_Count /= Decimal_Value (Field (Line, 2)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR unit short count mismatch: expected "
               & Field (Line, 2) & " got" & Natural'Image (Unit_Short_Count));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_zone_display_locales" then
         if Field_Count (Line) /= 3 or else not Is_Zone_Id (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_zone_display_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("zone_display|" & Field (Field (Line, 3), Index, ',')
                  & "|" & Field (Line, 2),
                 Line_Number);
            end loop;
         end if;
      elsif Kind = "require_zone_family_display_locales" then
         if Field_Count (Line) /= 3 or else not Is_Zone_Family (Field (Line, 2)) then
            Add_Line_Error
              (Line_Number, "invalid require_zone_family_display_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("zone_family_display|" & Field (Field (Line, 3), Index, ',')
                  & "|" & Field (Line, 2),
                  Line_Number);
            end loop;
         end if;
      elsif Kind = "require_zone_short_family_locales" then
         if Field_Count (Line) /= 3 or else not Is_Zone_Family (Field (Line, 2)) then
            Add_Line_Error
              (Line_Number, "invalid require_zone_short_family_locales row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("zone_short_family|" & Field (Field (Line, 3), Index, ',')
                  & "|" & Field (Line, 2),
                  Line_Number);
            end loop;
         end if;
      elsif Kind = "require_currency_count" then
         if Field_Count (Line) /= 2 or else not Is_Decimal_Text (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_currency_count row");
         elsif Currency_Count /= Decimal_Value (Field (Line, 2)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR currency count mismatch: expected "
               & Field (Line, 2) & " got" & Natural'Image (Currency_Count));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_currency_name_count" then
         if Field_Count (Line) /= 2 or else not Is_Decimal_Text (Field (Line, 2)) then
            Add_Line_Error (Line_Number, "invalid require_currency_name_count row");
         elsif Currency_Name_Count /= Decimal_Value (Field (Line, 2)) then
            Add_Coverage_Key (Line, Line_Number);
            Add_Line_Error
              (Line_Number,
               "raw CLDR currency name payload count mismatch: expected "
               & Field (Line, 2) & " got" & Natural'Image (Currency_Name_Count));
         else
            Add_Coverage_Key (Line, Line_Number);
         end if;
      elsif Kind = "require_currency" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_currency row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 2), ',') loop
               Require_Key ("currency|" & Field (Field (Line, 2), Index, ','), Line_Number);
            end loop;
         end if;
      elsif Kind = "require_currency_name_locale" then
         if Field_Count (Line) /= 2 then
            Add_Line_Error (Line_Number, "invalid require_currency_name_locale row");
         else
            Add_Coverage_Key (Line, Line_Number);
            Require_Key ("currency_name_payload|" & Field (Line, 2), Line_Number);
         end if;
      elsif Kind = "require_plural_family" then
         if Field_Count (Line) /= 3 then
            Add_Line_Error (Line_Number, "invalid require_plural_family row");
         else
            Add_Coverage_Key (Line, Line_Number);
            for Index in 1 .. Field_Count (Field (Line, 3), ',') loop
               Require_Key
                 ("plural_family|" & Field (Line, 2) & "|" & Field (Field (Line, 3), Index, ','),
                  Line_Number);
            end loop;
         end if;
      else
         Add_Line_Error (Line_Number, "invalid coverage row: " & Line);
      end if;
   end Parse_Coverage_Line;

   procedure Validate_Coverage is
      Start       : Positive := Coverage'First;
      Stop        : Natural;
      Line_Number : Positive := 1;
   begin
      while Start <= Coverage'Last loop
         Stop := Start;
         while Stop <= Coverage'Last and then Coverage (Stop) /= ASCII.LF loop
            Stop := Stop + 1;
         end loop;

         if Stop > Start and then Coverage (Stop - 1) = ASCII.CR then
            Parse_Coverage_Line (Coverage (Start .. Stop - 2), Line_Number);
         elsif Stop > Start then
            Parse_Coverage_Line (Coverage (Start .. Stop - 1), Line_Number);
         else
            Parse_Coverage_Line ("", Line_Number);
         end if;

         Start := Stop + 1;
         Line_Number := Line_Number + 1;
      end loop;
   end Validate_Coverage;

   function Generate return String is
      Output      : Ada.Text_IO.File_Type;
      Seen_Output : Boolean := False;

      procedure L (Text : String := "") is
      begin
         Ada.Text_IO.Put_Line (Output, Text);
      end L;

      procedure Emit_Header is
      begin
         L ("# Normalized deterministic CLDR-derived import source.");
         L ("#");
         L ("# raw|... rows are copied into cldr/data/cldr_subset.txt after validation.");
         L ("# *_text rows contain UTF-8 text and are converted to Ada string expressions.");
         L ("# digits_codepoints rows contain comma-separated Unicode code points.");
         L ("# names_text|kind|locale|start|item~item... rows expand indexed UTF-8 name data.");
         L;
      end Emit_Header;

      procedure Emit_Blank is
      begin
         if Seen_Output then
            L;
         end if;
      end Emit_Blank;

      procedure Parse_Line (Line : String; Line_Number : Positive) is
         Kind : constant String := Field (Line, 1);
      begin
         if Line'Length = 0 then
            Emit_Blank;
            return;
         elsif Line (Line'First) = '#' then
            return;
         else
            Increment_Raw_Count (Kind);
         end if;

         if Kind = "symbol" then
            declare
               Symbol_Kind : constant String := Field (Line, 2);
               Locales     : constant String := Field (Line, 3);
               Text        : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else (Symbol_Kind /= "decimal" and then Symbol_Kind /= "group")
                 or else Locales = ""
                 or else Text = ""
               then
                  Add_Line_Error (Line_Number, "invalid symbol record");
                  return;
               end if;
               Add_Key ("symbol|" & Symbol_Kind & "|" & Locales, Line_Number);
               Increment_Symbol_Count (Symbol_Kind);
               L (Symbol_Kind & "_text|" & Locales & "|" & Text);
               Seen_Output := True;
            end;
         elsif Kind = "policy" then
            declare
               Policy : constant String := Field (Line, 2);
               A      : constant String := Field (Line, 3);
               B      : constant String := Field (Line, 4);
            begin
               if Policy = "indian_grouping" then
                  if Field_Count (Line) /= 4 or else A = "" or else B = "" then
                     Add_Line_Error (Line_Number, "invalid indian_grouping policy record");
                     return;
                  end if;
                  Add_Key ("policy|indian_grouping", Line_Number);
                  L ("raw|indian_grouping|" & A & "|" & B);
               elsif Policy = "day_month_year" or else Policy = "symbol_first" then
                  if Field_Count (Line) /= 3 or else A = "" then
                     Add_Line_Error (Line_Number, "invalid " & Policy & " policy record");
                     return;
                  end if;
                  Add_Key ("policy|" & Policy, Line_Number);
                  L ("raw|" & Policy & "|" & A);
               else
                  Add_Line_Error (Line_Number, "unknown policy record");
                  return;
               end if;
               Seen_Output := True;
            end;
         elsif Kind = "numbering_system" then
            declare
               Locale : constant String := Field (Line, 2);
               Codes  : constant String := Field (Line, 3);
            begin
               if Field_Count (Line) /= 3 or else Locale = "" or else Field_Count (Codes, ',') /= 10 then
                  Add_Line_Error (Line_Number, "invalid numbering_system record");
                  return;
               end if;
               for Index in 1 .. 10 loop
                  if not Is_Hex_Text (Field (Codes, Index, ',')) then
                     Add_Line_Error (Line_Number, "invalid numbering_system code point");
                     return;
                  end if;
               end loop;
               Add_Key ("numbering_system|" & Locale, Line_Number);
               L ("digits_codepoints|" & Locale & "|" & Codes);
               Seen_Output := True;
            end;
         elsif Kind = "name_set" then
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
                  Add_Line_Error (Line_Number, "invalid name_set record");
                  return;
               end if;
               declare
                  Start : constant Natural := Decimal_Value (Start_Text);
                  Count : constant Natural := Field_Count (Items, '~');
               begin
                  if Count /= Expected_Name_Count (Name_Kind, Start) then
                     Add_Line_Error (Line_Number, "unexpected name_set count");
                     return;
                  end if;
               end;
               Add_Key ("name_set|" & Name_Kind & "|" & Locale, Line_Number);
               Increment_Name_Set_Count (Name_Kind);
               L ("names_text|" & Name_Kind & "|" & Locale & "|" & Start_Text & "|" & Items);
               Seen_Output := True;
            end;
         elsif Kind = "name_hex" then
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
                 or else not Is_Hex_List (Items)
               then
                  Add_Line_Error (Line_Number, "invalid name_hex record");
                  return;
               end if;
               declare
                  Start : constant Natural := Decimal_Value (Start_Text);
                  Count : constant Natural := Field_Count (Items, '~');
               begin
                  if Count /= Expected_Name_Count (Name_Kind, Start) then
                     Add_Line_Error (Line_Number, "unexpected name_hex count");
                     return;
                  end if;
               end;
               Add_Key ("name_set|" & Name_Kind & "|" & Locale, Line_Number);
               Increment_Name_Set_Count (Name_Kind);
               L ("names_hex|" & Name_Kind & "|" & Locale & "|" & Start_Text & "|" & Items);
               Seen_Output := True;
            end;
         elsif Kind = "day_period" then
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
                  Add_Line_Error (Line_Number, "invalid day_period record");
                  return;
               end if;
               Add_Key ("day_period|" & Locale & "|" & Period & "|" & Width, Line_Number);
               L ("day_period_text|" & Locale & "|" & Period & "|" & Width & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "zone_display" or else Kind = "zone_exemplar" then
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
                  Add_Line_Error (Line_Number, "invalid " & Kind & " record");
                  return;
               end if;
               Add_Key (Kind & "|" & Locale & "|" & Zone, Line_Number);
               L (Kind & "_text|" & Locale & "|" & Zone & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "zone_family_display" then
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
                  Add_Line_Error (Line_Number, "invalid zone_family_display record");
                  return;
               end if;
               Add_Key ("zone_family_display|" & Locale & "|" & Family, Line_Number);
               L
                 ("zone_family_display_text|" & Locale & "|" & Family
                  & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "zone_short_family" then
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
                  Add_Line_Error (Line_Number, "invalid zone_short_family record");
                  return;
               end if;
               Add_Key ("zone_short_family|" & Locale & "|" & Family, Line_Number);
               L
                 ("zone_short_family_text|" & Locale & "|" & Family & "|"
                  & Standard & "|" & Daylight & "|" & Generic_Label);
               Seen_Output := True;
            end;
         elsif Kind = "zone_gmt_prefix"
           or else Kind = "zone_offset_separator"
           or else Kind = "zone_location_pattern"
         then
            declare
               Locale : constant String := Field (Line, 2);
               Value  : constant String := Field (Line, 3);
            begin
               if Field_Count (Line) /= 3
                 or else Locale = ""
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid " & Kind & " record");
                  return;
               end if;
               Add_Key (Kind & "|" & Locale, Line_Number);
               L (Kind & "_text|" & Locale & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "available_format" then
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
                    (Line_Number, "invalid available_format record");
                  return;
               end if;
               Add_Key
                 ("available_format|" & Locale & "|" & Skeleton,
                  Line_Number);
               L
                 ("available_format_text|" & Locale & "|" & Skeleton
                  & "|" & Pattern);
               Seen_Output := True;
            end;
         elsif Kind = "list_separator" then
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
                  Add_Line_Error (Line_Number, "invalid list_separator record");
                  return;
               end if;
               Add_Key
                 ("list_separator|" & Locale & "|" & Family & "|" & Part,
                  Line_Number);
               L
                 ("list_separator_text|" & Locale & "|" & Family
                  & "|" & Part & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "unit_separator" then
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
                  Add_Line_Error (Line_Number, "invalid unit_separator record");
                  return;
               end if;
               Add_Key ("unit_separator|" & Locale & "|" & Part, Line_Number);
               L ("unit_separator_text|" & Locale & "|" & Part & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "unit_short" then
            declare
               Base  : constant String := Field (Line, 2);
               Value : constant String := Field (Line, 3);
            begin
               if Field_Count (Line) /= 3
                 or else not Is_Unit_Base (Base)
                 or else Value = ""
               then
                  Add_Line_Error (Line_Number, "invalid unit_short record");
                  return;
               end if;
               Unit_Short_Count := Unit_Short_Count + 1;
               Add_Key ("unit_short|" & Base, Line_Number);
               L ("unit_short_text|" & Base & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "unit_name" then
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
                  Add_Line_Error (Line_Number, "invalid unit_name record");
                  return;
               end if;
               Add_Key
                 ("unit_name|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category,
                  Line_Number);
               L
                 ("unit_name_text|" & Locale & "|" & Base & "|" & Width
                  & "|" & Category & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "relative_current" then
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
                  Add_Line_Error (Line_Number, "invalid relative_current record");
                  return;
               end if;
               Add_Key
                 ("relative_current|" & Locale & "|" & Base & "|" & Width,
                  Line_Number);
               L
                 ("relative_current_text|" & Locale & "|" & Base & "|"
                  & Width & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "relative_offset" then
            declare
               Locale  : constant String := Field (Line, 2);
               Offset  : constant String := Field (Line, 3);
               Pattern : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else Locale = ""
                 or else not Is_Relative_Offset (Offset)
                 or else Pattern = ""
                 or else not Contains (Pattern, "{0}")
               then
                  Add_Line_Error (Line_Number, "invalid relative_offset record");
                  return;
               end if;
               Add_Key ("relative_offset|" & Locale & "|" & Offset, Line_Number);
               L ("relative_offset_text|" & Locale & "|" & Offset & "|" & Pattern);
               Seen_Output := True;
            end;
         elsif Kind = "relative_unit_category" then
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
                    (Line_Number, "invalid relative_unit_category record");
                  return;
               end if;
               Add_Key
                 ("relative_unit_category|" & Locale & "|" & Base & "|"
                  & Category,
                  Line_Number);
               L
                 ("relative_unit_category_text|" & Locale & "|" & Base & "|"
                  & Category & "|" & Value);
               Seen_Output := True;
            end;
         elsif Kind = "relative_time_pattern" then
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
                 or else not Contains (Pattern, "{0}")
               then
                  Add_Line_Error
                    (Line_Number, "invalid relative_time_pattern record");
                  return;
               end if;
               Add_Key
                 ("relative_time_pattern|" & Locale & "|" & Base & "|"
                  & Width & "|" & Direction & "|" & Category,
                  Line_Number);
               L
                 ("relative_time_pattern_text|" & Locale & "|" & Base & "|"
                  & Width & "|" & Direction & "|" & Category & "|"
                  & Pattern);
               Seen_Output := True;
            end;
         elsif Kind = "currency" then
            if Field_Count (Line) /= 7
              or else Field (Line, 2)'Length /= 3
              or else not Is_Decimal_Text (Field (Line, 3))
              or else not Is_Decimal_Text (Field (Line, 4))
              or else Field (Line, 5) = ""
              or else Field (Line, 6) = ""
              or else Field (Line, 7) = ""
            then
               Add_Line_Error (Line_Number, "invalid currency record");
               return;
            end if;
            Add_Key ("currency|" & Field (Line, 2), Line_Number);
            Currency_Count := Currency_Count + 1;
            L
              ("currency_text|" & Field (Line, 2) & "|" & Field (Line, 3)
              & "|" & Field (Line, 4) & "|" & Field (Line, 5)
               & "|" & Field (Line, 6) & "|" & Field (Line, 7));
            Seen_Output := True;
         elsif Kind = "currency_name_payload" then
            if Field_Count (Line) /= 3
              or else Field (Line, 2) = ""
              or else Field (Line, 3) = ""
            then
               Add_Line_Error (Line_Number, "invalid currency_name_payload record");
               return;
            end if;
            Add_Key ("currency_name_payload|" & Field (Line, 2), Line_Number);
            Currency_Name_Count := Currency_Name_Count + 1;
            L ("raw|currency_name_payload|" & Field (Line, 2) & "|" & Field (Line, 3));
            Seen_Output := True;
         elsif Kind = "plural_family" then
            declare
               Plural_Kind : constant String := Field (Line, 2);
               Family      : constant String := Field (Line, 3);
               Locales     : constant String := Field (Line, 4);
            begin
               if Field_Count (Line) /= 4
                 or else (Plural_Kind /= "cardinal" and then Plural_Kind /= "ordinal")
                 or else Family = ""
                 or else Locales = ""
               then
                  Add_Line_Error (Line_Number, "invalid plural_family record");
                  return;
               end if;
               Add_Key ("plural_family|" & Plural_Kind & "|" & Family, Line_Number);
               L ("raw|" & Plural_Kind & "|" & Family & "|" & Locales);
               Seen_Output := True;
            end;
         else
            Add_Line_Error (Line_Number, "invalid raw CLDR record: " & Line);
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
        ("usage: extract_cldr_normalized [--check]" & ASCII.LF
         & "Extracts import/normalized_cldr.txt from raw/cldr_records.txt.");
      return;
   end if;

   declare
      Generated : constant String := Generate;
   begin
      if Errors /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      else
         Validate_Coverage;
      end if;

      if Errors /= 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      elsif Has_Argument ("--check") then
         if File_Equals_File (Generated_Path, Target_Path) then
            Ada.Text_IO.Put_Line ("CLDR normalized import is current");
         else
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "cldr/import/normalized_cldr.txt is not current; run cldr/bin/extract_cldr_normalized");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         end if;
      else
         Ada.Directories.Copy_File (Generated_Path, Target_Path);
         Ada.Text_IO.Put_Line ("extracted cldr/import/normalized_cldr.txt");
      end if;
   end;
exception
   when others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to extract normalized CLDR data");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Extract_CLDR_Normalized;
