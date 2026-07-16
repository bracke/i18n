with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

with Project_Tools.Files;
with Project_Tools.Text;

procedure Check_Conformance is
   package US renames Ada.Strings.Unbounded;
   use type I18N.Result.Render_Status;
   use type I18N.Runtime.Load_Status;

   Manifest_Path : constant String := "conformance/fixtures/manifest.txt";
   Max_Items     : constant := 64;

   type String_Slots is array (Positive range <>) of US.Unbounded_String;

   Suites       : String_Slots (1 .. Max_Items);
   Suite_Count  : Natural := 0;
   Fixtures     : String_Slots (1 .. Max_Items);
   Fixture_Sets : String_Slots (1 .. Max_Items);
   Fixture_Count : Natural := 0;
   Errors       : Natural := 0;
   Cases        : Natural := 0;

   Has_Unicode_Baseline : Boolean := False;
   Has_CLDR_Baseline    : Boolean := False;
   Has_ICU_Baseline     : Boolean := False;

   function S (Value : US.Unbounded_String) return String renames US.To_String;

   procedure Error (Message : String) is
   begin
      Errors := Errors + 1;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "error: " & Message);
   end Error;

   function Trim (Value : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Value, Ada.Strings.Both);
   end Trim;

   function Field_Count (Line : String; Separator : Character := '|') return Natural is
      Count : Natural := 1;
      Escaped : Boolean := False;
   begin
      if Line'Length = 0 then
         return 0;
      end if;

      for C of Line loop
         if Escaped then
            Escaped := False;
         elsif C = '\' then
            Escaped := True;
         elsif C = Separator then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Field_Count;

   function Field
     (Line      : String;
      Number    : Positive;
      Separator : Character := '|') return String
   is
      Start : Positive := Line'First;
      Count : Positive := 1;
      Escaped : Boolean := False;
   begin
      for Index in Line'Range loop
         if Escaped then
            Escaped := False;
         elsif Line (Index) = '\' then
            Escaped := True;
         elsif Line (Index) = Separator then
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

   function Unescape (Value : String) return String is
      Result : US.Unbounded_String;
      Index  : Positive := Value'First;
   begin
      while Index <= Value'Last loop
         if Value (Index) = '\' and then Index < Value'Last then
            declare
               Next : constant Character := Value (Index + 1);
            begin
               if Next = 'n' then
                  US.Append (Result, ASCII.LF);
               elsif Next = 't' then
                  US.Append (Result, ASCII.HT);
               else
                  US.Append (Result, Next);
               end if;
               Index := Index + 2;
            end;
         else
            US.Append (Result, Value (Index));
            Index := Index + 1;
         end if;
      end loop;

      return S (Result);
   end Unescape;

   function Has_Suite (Name : String) return Boolean is
   begin
      for Index in 1 .. Suite_Count loop
         if S (Suites (Index)) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Has_Suite;

   procedure Add_Suite (Name : String) is
   begin
      if Name = "" then
         Error ("manifest has an empty suite name");
      elsif Has_Suite (Name) then
         Error ("manifest has duplicate suite: " & Name);
      elsif Suite_Count = Max_Items then
         Error ("manifest has too many suites");
      else
         Suite_Count := Suite_Count + 1;
         Suites (Suite_Count) := US.To_Unbounded_String (Name);
      end if;
   end Add_Suite;

   procedure Add_Fixture (Suite : String; Path : String) is
   begin
      if Suite = "" or else Path = "" then
         Error ("manifest has an invalid fixture row");
      elsif Fixture_Count = Max_Items then
         Error ("manifest has too many fixtures");
      else
         Fixture_Count := Fixture_Count + 1;
         Fixture_Sets (Fixture_Count) := US.To_Unbounded_String (Suite);
         Fixtures (Fixture_Count) := US.To_Unbounded_String (Path);
      end if;
   end Add_Fixture;

   procedure Require_Suite (Name : String) is
   begin
      if not Has_Suite (Name) then
         Error ("manifest is missing required suite: " & Name);
      end if;
   end Require_Suite;

   procedure Parse_Arguments
     (Text : String;
      Args : in out I18N.Arguments.Arguments)
   is
   begin
      I18N.Arguments.Clear (Args);
      if Text = "-" or else Text = "" then
         return;
      end if;

      for Index in 1 .. Field_Count (Text, ';') loop
         declare
            Pair : constant String := Field (Text, Index, ';');
            Eq   : constant Natural := Project_Tools.Text.Index (Pair, "=");
         begin
            if Eq = 0 or else Eq = Pair'First or else Eq = Pair'Last then
               Error ("invalid argument pair: " & Pair);
            else
               I18N.Arguments.Set
                 (Args,
                  Pair (Pair'First .. Eq - 1),
                  Unescape (Pair (Eq + 1 .. Pair'Last)));
            end if;
         end;
      end loop;
   end Parse_Arguments;

   function Status_Text (Status : I18N.Result.Render_Status) return String is
   begin
      return I18N.Result.Render_Status'Image (Status);
   end Status_Text;

   procedure Run_Render_Case
     (Fixture_Path : String;
      Line_Number  : Positive;
      Line         : String)
   is
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Loaded  : I18N.Runtime.Load_Result;
   begin
      if Field_Count (Line) /= 8 then
         Error
           (Fixture_Path & ": line" & Positive'Image (Line_Number)
            & ": invalid render case row");
         return;
      end if;

      declare
         Case_Id         : constant String := Field (Line, 2);
         Catalog         : constant String := Unescape (Field (Line, 3));
         Locale          : constant String := Field (Line, 4);
         Key             : constant String := Field (Line, 5);
         Args_Text       : constant String := Field (Line, 6);
         Expected_Status : constant String := Field (Line, 7);
         Expected_Text   : constant String := Unescape (Field (Line, 8));
      begin
         I18N.Runtime.Load_Text
           (Runtime,
            Source_Name => Fixture_Path & ":" & Case_Id,
            Text        => Catalog,
            Result      => Loaded);

         if Loaded.Status /= I18N.Runtime.Loaded then
            Error
              (Fixture_Path & ": line" & Positive'Image (Line_Number)
               & ": case " & Case_Id & " catalog did not load");
            return;
         end if;

         Parse_Arguments (Args_Text, Args);

         declare
            Rendered : constant I18N.Result.Render_Result :=
              I18N.Runtime.Render (Runtime, Locale, Key, Args);
            Actual_Status : constant String := Status_Text (Rendered.Status);
            Actual_Text   : constant String :=
              I18N.Result.Output_Text (Rendered.Text);
         begin
            Cases := Cases + 1;
            if Actual_Status /= Expected_Status then
               Error
                 (Fixture_Path & ": line" & Positive'Image (Line_Number)
                  & ": case " & Case_Id & " status mismatch: expected "
                  & Expected_Status & ", got " & Actual_Status);
            elsif Rendered.Status = I18N.Result.Success
              and then Actual_Text /= Expected_Text
            then
               Error
                 (Fixture_Path & ": line" & Positive'Image (Line_Number)
                  & ": case " & Case_Id & " text mismatch: expected """
                  & Expected_Text & """, got """ & Actual_Text & """");
            end if;
         end;
      end;
   end Run_Render_Case;

   procedure Parse_Fixture (Relative_Path : String) is
      Path : constant String := "conformance/" & Relative_Path;
      Text : constant String := Project_Tools.Files.Read_Raw_File (Path);
      Start : Positive := Text'First;
      Line_Number : Positive := 1;
   begin
      if not Project_Tools.Files.File_Exists (Path) then
         Error ("missing conformance fixture: " & Path);
         return;
      end if;

      while Start <= Text'Last loop
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;

            declare
               Line : constant String :=
                 Trim (if Stop = Start then "" else Text (Start .. Stop - 1));
            begin
               if Line = "" or else Line (Line'First) = '#' then
                  null;
               elsif Field (Line, 1) = "case" then
                  Run_Render_Case (Path, Line_Number, Line);
               else
                  Error
                    (Path & ": line" & Positive'Image (Line_Number)
                     & ": unknown fixture row kind");
               end if;
            end;

            Line_Number := Line_Number + 1;
            Start := Stop + 1;
         end;
      end loop;
   end Parse_Fixture;

   procedure Parse_Manifest is
      Text : constant String := Project_Tools.Files.Read_Raw_File (Manifest_Path);
      Start : Positive := Text'First;
      Line_Number : Positive := 1;
   begin
      if not Project_Tools.Files.File_Exists (Manifest_Path) then
         Error ("missing conformance manifest: " & Manifest_Path);
         return;
      end if;

      while Start <= Text'Last loop
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;

            declare
               Line : constant String :=
                 Trim (if Stop = Start then "" else Text (Start .. Stop - 1));
               Kind : constant String := Field (Line, 1);
            begin
               if Line = "" or else Line (Line'First) = '#' then
                  null;
               elsif Kind = "baseline" then
                  if Field_Count (Line) /= 3 then
                     Error ("manifest line" & Positive'Image (Line_Number) & ": invalid baseline row");
                  elsif Field (Line, 2) = "unicode" and then Field (Line, 3) = "17.0.0" then
                     Has_Unicode_Baseline := True;
                  elsif Field (Line, 2) = "cldr" and then Field (Line, 3) = "48.2" then
                     Has_CLDR_Baseline := True;
                  elsif Field (Line, 2) = "icu" and then Field (Line, 3) = "78.3" then
                     Has_ICU_Baseline := True;
                  else
                     Error ("manifest line" & Positive'Image (Line_Number) & ": unexpected baseline");
                  end if;
               elsif Kind = "suite" then
                  if Field_Count (Line) /= 2 then
                     Error ("manifest line" & Positive'Image (Line_Number) & ": invalid suite row");
                  else
                     Add_Suite (Field (Line, 2));
                  end if;
               elsif Kind = "fixture" then
                  if Field_Count (Line) /= 3 then
                     Error ("manifest line" & Positive'Image (Line_Number) & ": invalid fixture row");
                  else
                     Add_Fixture (Field (Line, 2), Field (Line, 3));
                  end if;
               else
                  Error ("manifest line" & Positive'Image (Line_Number) & ": unknown row kind");
               end if;
            end;

            Line_Number := Line_Number + 1;
            Start := Stop + 1;
         end;
      end loop;
   end Parse_Manifest;

begin
   if Ada.Command_Line.Argument_Count > 0 then
      Error ("check_conformance takes no arguments");
   end if;

   Parse_Manifest;

   if not Has_Unicode_Baseline then
      Error ("manifest is missing Unicode 17.0.0 baseline");
   end if;
   if not Has_CLDR_Baseline then
      Error ("manifest is missing CLDR 48.2 baseline");
   end if;
   if not Has_ICU_Baseline then
      Error ("manifest is missing ICU 78.3 baseline");
   end if;

   Require_Suite ("unicode_core");
   Require_Suite ("normalization");
   Require_Suite ("case_transforms");
   Require_Suite ("segmentation");
   Require_Suite ("collation_search");
   Require_Suite ("locale_ids");
   Require_Suite ("plurals");
   Require_Suite ("number_currency");
   Require_Suite ("date_time_calendar_tz");
   Require_Suite ("message_format");
   Require_Suite ("rbnf");
   Require_Suite ("units_lists_names");

   for Index in 1 .. Fixture_Count loop
      if not Has_Suite (S (Fixture_Sets (Index))) then
         Error ("fixture references unknown suite: " & S (Fixture_Sets (Index)));
      end if;
      Parse_Fixture (S (Fixtures (Index)));
   end loop;

   if Cases = 0 then
      Error ("conformance harness did not execute any render cases");
   end if;

   if Errors = 0 then
      Ada.Text_IO.Put_Line
        ("ICU/CLDR conformance harness passed:"
         & Natural'Image (Suite_Count) & " suites,"
         & Natural'Image (Fixture_Count) & " fixture files,"
         & Natural'Image (Cases) & " render cases");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   else
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "ICU/CLDR conformance harness failed:"
         & Natural'Image (Errors) & " error(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Check_Conformance;
