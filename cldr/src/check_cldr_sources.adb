with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;
with Project_Tools.JSON;

procedure Check_CLDR_Sources is
   package US renames Ada.Strings.Unbounded;

   Manifest_Path : constant String := "upstream/source_manifest.txt";
   Source_Path   : constant String := "upstream/source_files.txt";
   Source        : constant String := Project_Tools.Files.Read_Raw_File (Source_Path);

   Max_Sources : constant := 5_000;

   Errors           : Natural := 0;
   Paths            : array (1 .. Max_Sources) of US.Unbounded_String;
   Path_Count       : Natural := 0;
   Expected_Version : US.Unbounded_String;
   Has_Numbers      : Boolean := False;
   Has_Dates        : Boolean := False;
   Has_Supplemental : Boolean := False;
   Has_Misc         : Boolean := False;
   Has_Units        : Boolean := False;

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

   function Starts_With (Value : String; Prefix : String) return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Ends_With (Value : String; Suffix : String) return Boolean is
   begin
      return Value'Length >= Suffix'Length
        and then Value (Value'Last - Suffix'Length + 1 .. Value'Last) = Suffix;
   end Ends_With;

   function CLDR_Major (Value : String) return String is
   begin
      for Index in Value'Range loop
         if Value (Index) = '.' then
            if Index = Value'First then
               return "";
            else
               return Value (Value'First .. Index - 1);
            end if;
         end if;
      end loop;

      return Value;
   end CLDR_Major;

   function Path_In_Inventory (Path : String) return Boolean is
   begin
      for Index in 1 .. Path_Count loop
         if S (Paths (Index)) = Path then
            return True;
         end if;
      end loop;

      return False;
   end Path_In_Inventory;

   procedure Require_Path (Path : String) is
   begin
      if not Path_In_Inventory (Path) then
         Add_Error ("upstream CLDR source inventory is missing required path: " & Path);
      end if;
   end Require_Path;

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

   procedure Validate_Full_Date_Source (Path : String; Text : String) is
      Full_Path : constant String := "upstream/" & Path;
      Prefix    : constant String := "cldr-json/cldr-dates-full/main/";
      Suffix    : constant String := "/ca-gregorian.json";
      Locale_Last : constant Natural := Path'Last - Suffix'Length;
      Locale    : constant String :=
        Path (Path'First + Prefix'Length .. Locale_Last);
      Main      : constant String := Object_Field_Object (Text, "main");
      Locale_Obj : constant String := Object_Field_Object (Main, Locale);
      Dates     : constant String := Object_Field_Object (Locale_Obj, "dates");
      Calendars : constant String := Object_Field_Object (Dates, "calendars");
      Gregorian : constant String := Object_Field_Object (Calendars, "gregorian");
      Quarters  : constant String := Object_Field_Object (Gregorian, "quarters");
      Quarter_Format : constant String := Object_Field_Object (Quarters, "format");
      Day_Periods : constant String := Object_Field_Object (Gregorian, "dayPeriods");
      Day_Format  : constant String := Object_Field_Object (Day_Periods, "format");

      procedure Require_Quarter_Width (Width : String) is
         Object : constant String := Object_Field_Object (Quarter_Format, Width);
      begin
         if Object = "" then
            Add_Error
              ("upstream CLDR source " & Full_Path
               & " must declare gregorian quarter format/" & Width);
            return;
         end if;

         for Quarter in 1 .. 4 loop
            declare
               Key   : constant String := Natural'Image (Quarter);
               Value : constant String :=
                 Project_Tools.JSON.Object_Field_Value
                   (Object, Key (Key'First + 1 .. Key'Last));
            begin
               if Value = "" then
                  Add_Error
                    ("upstream CLDR source " & Full_Path
                     & " must declare gregorian quarter format/" & Width
                     & "/" & Key (Key'First + 1 .. Key'Last));
               end if;
            end;
         end loop;
      end Require_Quarter_Width;

      procedure Require_Day_Period_Width (Width : String) is
         Object : constant String := Object_Field_Object (Day_Format, Width);
      begin
         if Object = "" then
            Add_Error
              ("upstream CLDR source " & Full_Path
               & " must declare gregorian dayPeriods format/" & Width);
            return;
         end if;

         if Project_Tools.JSON.Object_Field_Value (Object, "am") = ""
           or else Project_Tools.JSON.Object_Field_Value (Object, "pm") = ""
         then
            Add_Error
              ("upstream CLDR source " & Full_Path
               & " must declare gregorian am/pm day periods for "
               & Width);
         end if;
      end Require_Day_Period_Width;
   begin
      if Locale = "" or else Gregorian = "" then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare nested main/<locale>/dates/calendars/gregorian data");
         return;
      end if;

      Require_Quarter_Width ("wide");
      Require_Quarter_Width ("abbreviated");
      Require_Day_Period_Width ("wide");
      Require_Day_Period_Width ("abbreviated");
   end Validate_Full_Date_Source;

   procedure Validate_Full_Time_Zone_Source (Path : String; Text : String) is
      Full_Path  : constant String := "upstream/" & Path;
      Locale     : constant String :=
        Path
          (Path'First + String'("cldr-json/cldr-dates-full/main/")'Length
           .. Path'Last - String'("/timeZoneNames.json")'Length);
      Main       : constant String := Object_Field_Object (Text, "main");
      Locale_Obj : constant String := Object_Field_Object (Main, Locale);
      Dates      : constant String := Object_Field_Object (Locale_Obj, "dates");
      Names      : constant String := Object_Field_Object (Dates, "timeZoneNames");
   begin
      if Locale = "" or else Names = "" then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare nested main/<locale>/dates/timeZoneNames data");
         return;
      end if;

      if Project_Tools.JSON.Object_Field_Value (Names, "gmtFormat") = "" then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare timeZoneNames/gmtFormat");
      end if;

      if Project_Tools.JSON.Object_Field_Value (Names, "hourFormat") = "" then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare timeZoneNames/hourFormat");
      end if;

      if Project_Tools.JSON.Object_Field_Value (Names, "regionFormat") = "" then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare timeZoneNames/regionFormat");
      end if;
   end Validate_Full_Time_Zone_Source;

   procedure Add_Path (Path : String; Line_Number : Positive) is
      Full_Path : constant String := "upstream/" & Path;
   begin
      for Index in 1 .. Path_Count loop
         if S (Paths (Index)) = Path then
            Add_Line_Error (Line_Number, "duplicate upstream CLDR source path: " & Path);
            return;
         end if;
      end loop;

      if Path_Count = Max_Sources then
         Add_Line_Error (Line_Number, "too many upstream CLDR source paths");
         return;
      end if;

      Path_Count := Path_Count + 1;
      Paths (Path_Count) := US.To_Unbounded_String (Path);

      if not Project_Tools.Files.File_Exists (Full_Path) then
         Add_Line_Error (Line_Number, "missing upstream CLDR source file: " & Full_Path);
      end if;
   end Add_Path;

   procedure Validate_Source_File (Path : String) is
      Full_Path : constant String := "upstream/" & Path;
      Text      : constant String := Project_Tools.Files.Read_Raw_File (Full_Path);
      Version   : constant String := Project_Tools.JSON.Object_Field_Value (Text, "cldrVersion");
      Nested_Version : constant String := Project_Tools.JSON.Field_Value (Text, "_cldrVersion");
      Effective_Version : constant String :=
        (if Version /= "" then Version else Nested_Version);
   begin
      if Effective_Version /= ""
        and then Effective_Version /= S (Expected_Version)
        and then Effective_Version /= CLDR_Major (S (Expected_Version))
      then
         Add_Error
           ("upstream CLDR source " & Full_Path
            & " must declare cldrVersion=" & S (Expected_Version));
      end if;

      if Starts_With (Path, "cldr-json/cldr-dates-full/main/")
        and then Ends_With (Path, "/ca-gregorian.json")
      then
         Validate_Full_Date_Source (Path, Text);
      elsif Starts_With (Path, "cldr-json/cldr-dates-full/main/")
        and then Ends_With (Path, "/timeZoneNames.json")
      then
         Validate_Full_Time_Zone_Source (Path, Text);
      end if;
   exception
      when others =>
         Add_Error ("failed to read upstream CLDR source file: " & Full_Path);
   end Validate_Source_File;

   procedure Validate_Source_Files is
   begin
      for Index in 1 .. Path_Count loop
         Validate_Source_File (S (Paths (Index)));
      end loop;
   end Validate_Source_Files;

   procedure Parse_Line (Line : String; Line_Number : Positive) is
      Kind   : constant String := Field (Line, 1);
      Family : constant String := Field (Line, 2);
      Path   : constant String := Field (Line, 3);
   begin
      if Line'Length = 0 or else Line (Line'First) = '#' then
         return;
      end if;

      if Field_Count (Line) /= 3
        or else Kind /= "source"
        or else Path = ""
        or else not Starts_With (Path, "cldr-json/")
      then
         Add_Line_Error (Line_Number, "invalid upstream CLDR source row");
         return;
      end if;

      if Family = "numbers" then
         Has_Numbers := True;
      elsif Family = "dates" then
         Has_Dates := True;
      elsif Family = "supplemental" then
         Has_Supplemental := True;
      elsif Family = "misc" then
         Has_Misc := True;
      elsif Family = "units" then
         Has_Units := True;
      else
         Add_Line_Error (Line_Number, "unknown upstream CLDR source family: " & Family);
         return;
      end if;

      Add_Path (Path, Line_Number);
   end Parse_Line;

   procedure Parse_Source_File is
      Start       : Positive := Source'First;
      Stop        : Natural;
      Line_Number : Positive := 1;
   begin
      while Start <= Source'Last loop
         Stop := Start;
         while Stop <= Source'Last and then Source (Stop) /= ASCII.LF loop
            Stop := Stop + 1;
         end loop;

         if Stop > Start and then Source (Stop - 1) = ASCII.CR then
            Parse_Line (Source (Start .. Stop - 2), Line_Number);
         elsif Stop > Start then
            Parse_Line (Source (Start .. Stop - 1), Line_Number);
         else
            Parse_Line ("", Line_Number);
         end if;

         Start := Stop + 1;
         Line_Number := Line_Number + 1;
      end loop;
   end Parse_Source_File;

   procedure Validate_Manifest is
      Version    : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "cldr_version");
      Family     : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_family");
      Count_Text : constant String := Project_Tools.Files.Value_Of (Manifest_Path, "source_file_count");
   begin
      if Version = "" then
         Add_Error ("upstream CLDR source manifest must declare cldr_version");
      else
         Expected_Version := US.To_Unbounded_String (Version);
      end if;

      if Family /= "cldr-json" then
         Add_Error ("upstream CLDR source manifest must declare source_family=cldr-json");
      end if;

      if not Is_Decimal_Text (Count_Text) then
         Add_Error ("upstream CLDR source manifest must declare decimal source_file_count");
      elsif Path_Count /= Natural'Value (Count_Text) then
         Add_Error
           ("upstream CLDR source file count mismatch: expected "
            & Count_Text & " got" & Natural'Image (Path_Count));
      end if;
   end Validate_Manifest;

begin
   if Has_Argument ("--help") then
      Ada.Text_IO.Put_Line
        ("usage: check_cldr_sources [--check]" & ASCII.LF
         & "Validates upstream/source_files.txt against upstream/source_manifest.txt.");
      return;
   end if;

   Parse_Source_File;
   Validate_Manifest;
   Require_Path ("cldr-json/cldr-dates-full/main/en/ca-gregorian.json");
   Require_Path ("cldr-json/cldr-dates-full/main/de/ca-gregorian.json");
   Require_Path ("cldr-json/cldr-dates-full/main/fr/ca-gregorian.json");
   Require_Path ("cldr-json/cldr-dates-full/main/en/timeZoneNames.json");
   Require_Path ("cldr-json/cldr-dates-full/main/de/timeZoneNames.json");
   Require_Path ("cldr-json/cldr-dates-full/main/fr/timeZoneNames.json");
   Require_Path ("cldr-json/cldr-misc-full/main/en/listPatterns.json");
   Require_Path ("cldr-json/cldr-units-full/main/en/units.json");
   if Errors = 0 then
      Validate_Source_Files;
   end if;

   if not Has_Numbers then
      Add_Error ("upstream CLDR source inventory is missing numbers family");
   end if;

   if not Has_Dates then
      Add_Error ("upstream CLDR source inventory is missing dates family");
   end if;

   if not Has_Supplemental then
      Add_Error ("upstream CLDR source inventory is missing supplemental family");
   end if;

   if not Has_Misc then
      Add_Error ("upstream CLDR source inventory is missing misc family");
   end if;

   if not Has_Units then
      Add_Error ("upstream CLDR source inventory is missing units family");
   end if;

   if Errors = 0 then
      Ada.Text_IO.Put_Line ("CLDR upstream source inventory is valid");
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
exception
   when others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "failed to validate upstream CLDR source inventory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Check_CLDR_Sources;
