with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Project_Tools.Files;

procedure Check_TZDB_Sources is
   package US renames Ada.Strings.Unbounded;

   Manifest_Path : constant String := "upstream/tzdb/source_manifest.txt";
   TZData_Path   : constant String := "upstream/tzdb/tzdata.zi";
   Zone1970_Path : constant String := "upstream/tzdb/zone1970.tab";
   Zone_Path     : constant String := "upstream/tzdb/zone.tab";
   Leap_Path     : constant String := "upstream/tzdb/leapseconds";

   Max_Zones : constant := 1_000;

   type String_Table is array (Positive range <>) of US.Unbounded_String;

   Errors       : Natural := 0;
   Zone_Names   : String_Table (1 .. Max_Zones);
   Zone_Count   : Natural := 0;
   Link_Names   : String_Table (1 .. Max_Zones);
   Link_Targets : String_Table (1 .. Max_Zones);
   Link_Count   : Natural := 0;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   procedure Add_Error (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
   end Add_Error;

   procedure Add_Line_Error
     (Path        : String;
      Line_Number : Positive;
      Message     : String)
   is
   begin
      Add_Error (Path & ": line" & Positive'Image (Line_Number) & ": " & Message);
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

   function Starts_With (Value : String; Prefix : String) return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

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

   function Field
     (Line      : String;
      Number    : Positive;
      Separator : Character := ASCII.HT) return String
   is
      Start : Positive := Line'First;
      Count : Positive := 1;
   begin
      for Index in Line'Range loop
         if Line (Index) = Separator then
            if Count = Number then
               return (if Index = Start then "" else Line (Start .. Index - 1));
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
         return (if Start > Line'Last then "" else Line (Start .. Line'Last));
      end if;

      return "";
   end Field;

   function Field_Count
     (Line      : String;
      Separator : Character := ASCII.HT) return Natural
   is
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

   procedure Add_Name
     (Names : in out String_Table;
      Count : in out Natural;
      Name  : String)
   is
   begin
      for Index in 1 .. Count loop
         if S (Names (Index)) = Name then
            return;
         end if;
      end loop;

      if Count = Names'Last then
         Add_Error ("too many tzdb zone/link names");
         return;
      end if;

      Count := Count + 1;
      Names (Count) := US.To_Unbounded_String (Name);
   end Add_Name;

   procedure Add_Link
     (Target : String;
      Link   : String)
   is
   begin
      for Index in 1 .. Link_Count loop
         if S (Link_Names (Index)) = Link then
            if S (Link_Targets (Index)) /= Target then
               Add_Error ("tzdb link has conflicting targets: " & Link);
            end if;
            return;
         end if;
      end loop;

      if Link_Count = Link_Names'Last then
         Add_Error ("too many tzdb zone/link names");
         return;
      end if;

      Link_Count := Link_Count + 1;
      Link_Names (Link_Count) := US.To_Unbounded_String (Link);
      Link_Targets (Link_Count) := US.To_Unbounded_String (Target);
   end Add_Link;

   function Has_Name
     (Names : String_Table;
      Count : Natural;
      Name  : String) return Boolean
   is
   begin
      for Index in 1 .. Count loop
         if S (Names (Index)) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Has_Name;

   function Non_Comment_Line_Count (Text : String) return Natural is
      Start  : Positive := Text'First;
      Stop   : Natural;
      Result : Natural := 0;
   begin
      while Start <= Text'Last loop
         Stop := Start;
         while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
            Stop := Stop + 1;
         end loop;

         if Stop > Start and then Text (Start) /= '#' then
            Result := Result + 1;
         end if;

         Start := Stop + 1;
      end loop;

      return Result;
   end Non_Comment_Line_Count;

   procedure Require_File (Path : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path) then
         Add_Error ("missing checked tzdb source file: " & Path);
      end if;
   end Require_File;

   procedure Validate_Manifest is
      Text : constant String := Project_Tools.Files.Read_Raw_File (Manifest_Path);
   begin
      if not Contains (Text, "tzdb_version=2026a" & ASCII.LF) then
         Add_Error ("tzdb manifest must declare tzdb_version=2026a");
      end if;

      if not Contains (Text, "source_family=iana-tzdb" & ASCII.LF) then
         Add_Error ("tzdb manifest must declare source_family=iana-tzdb");
      end if;

      if not Contains (Text, "dataform=rearguard" & ASCII.LF) then
         Add_Error ("tzdb manifest must declare dataform=rearguard");
      end if;

      if not Contains (Text, "source_file_count=4" & ASCII.LF) then
         Add_Error ("tzdb manifest must declare source_file_count=4");
      end if;
   exception
      when others =>
         Add_Error ("failed to read tzdb manifest: " & Manifest_Path);
   end Validate_Manifest;

   procedure Load_TZData is
      Text        : constant String := Project_Tools.Files.Read_Raw_File (TZData_Path);
      Start       : Positive := Text'First;
      Stop        : Natural;
      Line_Number : Positive := 1;
   begin
      if not Starts_With (Text, "# version 2026a" & ASCII.LF) then
         Add_Error ("tzdata.zi must start with '# version 2026a'");
      end if;

      if not Contains (Text, "# dataform rearguard" & ASCII.LF) then
         Add_Error ("tzdata.zi must declare rearguard dataform");
      end if;

      if not Contains (Text, "This zic input file is in the public domain.") then
         Add_Error ("tzdata.zi must retain public-domain provenance");
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
               if Starts_With (Line, "Z ") then
                  declare
                     Name : constant String := Field (Line, 2, ' ');
                  begin
                     if Valid_Zone_Name (Name) then
                        Add_Name (Zone_Names, Zone_Count, Name);
                     else
                        Add_Line_Error (TZData_Path, Line_Number, "invalid zone name");
                     end if;
                  end;
               elsif Starts_With (Line, "L ") then
                  declare
                     Target : constant String := Field (Line, 2, ' ');
                     Link   : constant String := Field (Line, 3, ' ');
                  begin
                     if not Valid_Zone_Name (Target) or else not Valid_Zone_Name (Link) then
                        Add_Line_Error (TZData_Path, Line_Number, "invalid link row");
                     else
                        Add_Link (Target, Link);
                     end if;
                  end;
               end if;
            end;
         end if;

         Start := Stop + 1;
         Line_Number := Line_Number + 1;
      end loop;

      if Zone_Count < 300 then
         Add_Error ("tzdata.zi exposes too few primary zone rows");
      end if;

      for Index in 1 .. Link_Count loop
         if not Has_Name (Zone_Names, Zone_Count, S (Link_Targets (Index))) then
            Add_Error
              ("tzdb link target is absent from primary zones: "
               & S (Link_Names (Index)) & " -> " & S (Link_Targets (Index)));
         end if;
      end loop;
   exception
      when others =>
         Add_Error ("failed to parse tzdata.zi");
   end Load_TZData;

   procedure Validate_Zone_Table (Path : String) is
      Text        : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Start       : Positive := Text'First;
      Stop        : Natural;
      Line_Number : Positive := 1;
      Data_Lines  : Natural := 0;
   begin
      if not Contains (Text, "public domain") then
         Add_Error (Path & " must retain public-domain provenance");
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
               if Line (Line'First) /= '#' then
                  Data_Lines := Data_Lines + 1;
                  if Field_Count (Line, ASCII.HT) < 3 then
                     Add_Line_Error (Path, Line_Number, "invalid zone table row");
                  else
                     declare
                        Name : constant String := Field (Line, 3, ASCII.HT);
                     begin
                        if not Valid_Zone_Name (Name) then
                           Add_Line_Error (Path, Line_Number, "invalid table zone name");
                        elsif not Has_Name (Zone_Names, Zone_Count, Name)
                          and then not Has_Name (Link_Names, Link_Count, Name)
                        then
                           Add_Line_Error
                             (Path, Line_Number,
                              "zone table name is absent from tzdata.zi: " & Name);
                        end if;
                     end;
                  end if;
               end if;
            end;
         end if;

         Start := Stop + 1;
         Line_Number := Line_Number + 1;
      end loop;

      if Data_Lines < 300 then
         Add_Error (Path & " exposes too few zone table rows");
      end if;
   exception
      when others =>
         Add_Error ("failed to parse tzdb zone table: " & Path);
   end Validate_Zone_Table;

   procedure Validate_Leap_Seconds is
      Text : constant String := Project_Tools.Files.Read_Raw_File (Leap_Path);
   begin
      if Non_Comment_Line_Count (Text) < 20 then
         Add_Error ("leapseconds exposes too few leap-second rows");
      end if;

      if not Contains (Text, "public domain") then
         Add_Error ("leapseconds must retain public-domain provenance");
      end if;
   exception
      when others =>
         Add_Error ("failed to parse leapseconds");
   end Validate_Leap_Seconds;
begin
   Require_File (Manifest_Path);
   Require_File (TZData_Path);
   Require_File (Zone1970_Path);
   Require_File (Zone_Path);
   Require_File (Leap_Path);

   if Errors = 0 then
      Validate_Manifest;
      Load_TZData;
      Validate_Zone_Table (Zone1970_Path);
      Validate_Zone_Table (Zone_Path);
      Validate_Leap_Seconds;
   end if;

   if Errors = 0 then
      if not Has_Argument ("--check") then
         Ada.Text_IO.Put_Line
           ("IANA tzdb sources valid: 2026a, "
            & Natural'Image (Zone_Count) & " zones,"
            & Natural'Image (Link_Count) & " links");
      end if;
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Check_TZDB_Sources;
