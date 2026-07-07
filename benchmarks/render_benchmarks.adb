with Ada.Calendar;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Render_Benchmarks is
   use Ada.Text_IO;
   use type Ada.Calendar.Time;
   use type I18N.Result.Render_Status;

   Default_Iterations : constant Positive := 20_000;
   Smoke_Iterations   : constant Positive := 250;

   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;

   function Trimmed (Text : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Trimmed;

   function Catalog_Path return String is
   begin
      if Ada.Directories.Exists ("benchmarks/catalogs/render_hot_paths.catalog") then
         return "benchmarks/catalogs/render_hot_paths.catalog";
      elsif Ada.Directories.Exists ("catalogs/render_hot_paths.catalog") then
         return "catalogs/render_hot_paths.catalog";
      elsif Ada.Directories.Exists ("../benchmarks/catalogs/render_hot_paths.catalog") then
         return "../benchmarks/catalogs/render_hot_paths.catalog";
      end if;

      Put_Line
        (Standard_Error,
         "benchmark catalog not found: benchmarks/catalogs/render_hot_paths.catalog");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      raise Program_Error;
   end Catalog_Path;

   function Iterations return Positive is
   begin
      for Index in 1 .. Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Ada.Command_Line.Argument (Index);
         begin
            if Arg = "--smoke" then
               return Smoke_Iterations;
            elsif Arg'Length > 13 and then Arg (Arg'First .. Arg'First + 12) = "--iterations=" then
               return Positive'Value (Arg (Arg'First + 13 .. Arg'Last));
            end if;
         end;
      end loop;

      return Default_Iterations;
   end Iterations;

   procedure Print_Result
     (Label      : String;
      Count      : Positive;
      Elapsed    : Duration;
      Checksum   : Natural;
      Failures   : Natural) is
      Per_Op_Us : constant Long_Float :=
        Long_Float (Elapsed) * 1_000_000.0 / Long_Float (Count);
   begin
      Put_Line
        (Label
         & " iterations=" & Trimmed (Positive'Image (Count))
         & " elapsed_s=" & Trimmed (Duration'Image (Elapsed))
         & " per_op_us=" & Trimmed (Long_Float'Image (Per_Op_Us))
         & " checksum=" & Trimmed (Natural'Image (Checksum))
         & " failures=" & Trimmed (Natural'Image (Failures)));
   end Print_Result;

   procedure Run_Render
     (Label : String;
      Key   : String;
      Count : Positive) is
      Start    : Ada.Calendar.Time;
      Elapsed  : Duration;
      Checksum : Natural := 0;
      Failures : Natural := 0;
   begin
      Start := Ada.Calendar.Clock;
      for Index in 1 .. Count loop
         declare
            Result : constant I18N.Result.Render_Result :=
              I18N.Runtime.Render (Runtime, "en", Key, Args);
         begin
            if Result.Status = I18N.Result.Success then
               Checksum := Checksum + Result.Text.Length + Index mod 7;
            else
               Failures := Failures + 1;
            end if;
         end;
      end loop;
      Elapsed := Ada.Calendar.Clock - Start;
      Print_Result ("render/" & Label, Count, Elapsed, Checksum, Failures);
   end Run_Render;

   procedure Run_Render_Into
     (Label : String;
      Key   : String;
      Count : Positive) is
      Start    : Ada.Calendar.Time;
      Elapsed  : Duration;
      Checksum : Natural := 0;
      Failures : Natural := 0;
   begin
      Start := Ada.Calendar.Clock;
      for Index in 1 .. Count loop
         declare
            Target : String (1 .. 256);
            Last   : Natural := 0;
            Status : I18N.Result.Render_Status := I18N.Result.Internal_Error;
         begin
            I18N.Runtime.Render_Into (Runtime, "en", Key, Args, Target, Last, Status);
            if Status = I18N.Result.Success then
               Checksum := Checksum + Last + Index mod 7;
            else
               Failures := Failures + 1;
            end if;
         end;
      end loop;
      Elapsed := Ada.Calendar.Clock - Start;
      Print_Result ("render_into/" & Label, Count, Elapsed, Checksum, Failures);
   end Run_Render_Into;

   Count : constant Positive := Iterations;
begin
   I18N.Runtime.Initialize (Runtime, Catalog_Path);

   if not I18N.Runtime.Is_Valid (Runtime) then
      Put_Line (Standard_Error, "benchmark runtime initialization failed");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   I18N.Arguments.Set (Args, "name", "Ada");
   I18N.Arguments.Set (Args, "count", "42");
   I18N.Arguments.Set (Args, "gender", "female");
   I18N.Arguments.Set (Args, "value", "1234567.89");
   I18N.Arguments.Set (Args, "amount", "12345.67");
   I18N.Arguments.Set (Args, "day", "2026-06-29");
   I18N.Arguments.Set (Args, "clock", "13:45:30");

   Put_Line ("I18N render benchmarks");
   Put_Line ("iterations per case: " & Trimmed (Positive'Image (Count)));

   Run_Render ("simple", "simple", Count);
   Run_Render ("plural", "plural", Count);
   Run_Render ("select", "select", Count);
   Run_Render ("nested", "nested", Count);
   Run_Render ("number", "number", Count);
   Run_Render ("currency", "currency", Count);
   Run_Render ("date", "date", Count);
   Run_Render ("time", "time", Count);

   Run_Render_Into ("simple", "simple", Count);
   Run_Render_Into ("plural", "plural", Count);
   Run_Render_Into ("select", "select", Count);
   Run_Render_Into ("nested", "nested", Count);
   Run_Render_Into ("number", "number", Count);
   Run_Render_Into ("currency", "currency", Count);
   Run_Render_Into ("date", "date", Count);
   Run_Render_Into ("time", "time", Count);
end Render_Benchmarks;
