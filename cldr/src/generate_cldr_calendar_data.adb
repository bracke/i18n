--  Builds localized non-Gregorian calendar names into per-locale shards
--  share/i18n/calendars/<locale>.i18ndata. NAMES ONLY -- month / day / quarter /
--  day-period / era names for the 11 CLDR calendars; date arithmetic is a later
--  phase. Reads the upstream cldr-cal-* JSON directly.
--
--  One section "name"; composite key
--     <calendar>\x1f<field>\x1f<context>\x1f<width>\x1f<index>
--        field   = month | day | quarter | day-period | era
--        context = format | stand-alone   (era: always format)
--        width   = wide | abbreviated | narrow
--        index   = the CLDR key (1.., sun.., am.., 0..)

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Containers.Vectors;
with Cldr_Json;

procedure Generate_CLDR_Calendar_Data is

   HT : constant Character := Character'Val (16#09#);
   US : constant Character := Character'Val (16#1F#);
   CLDR_Version : constant String := "48.2";

   type Pkg_List is array (Positive range <>) of Unbounded_String;
   function P (S : String) return Unbounded_String renames To_Unbounded_String;

   Packages : constant Pkg_List :=
     [P ("buddhist"), P ("chinese"), P ("coptic"), P ("dangi"),
      P ("ethiopic"), P ("hebrew"), P ("indian"), P ("islamic"),
      P ("japanese"), P ("persian"), P ("roc")];

   function Pkg_Main (Cal : String) return String is
     ("upstream/cldr-json/cldr-cal-" & Cal & "-full/main");

   package Rec_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   package Rec_Sort is new Rec_Vectors.Generic_Sorting;
   Records : Rec_Vectors.Vector;

   Current_Prefix : Unbounded_String;

   procedure On_Index (Index : String; Name : String) is
   begin
      if Name'Length > 0 and then Name (Name'First) not in '{' | '[' then
         Records.Append
           (Current_Prefix & Index & HT & Cldr_Json.Unescape (Name));
      end if;
   end On_Index;

   Contexts : constant array (1 .. 2) of Unbounded_String :=
     [P ("format"), P ("stand-alone")];
   Widths   : constant array (1 .. 3) of Unbounded_String :=
     [P ("wide"), P ("abbreviated"), P ("narrow")];

   Current_Cal : Unbounded_String;

   procedure Emit_Widths (Cal_Obj : String; Json_Field, Our_Field : String) is
      Sub : constant String := Cldr_Json.Field (Cal_Obj, Json_Field);
   begin
      for C of Contexts loop
         declare
            Ctx_Obj : constant String := Cldr_Json.Field (Sub, To_String (C));
         begin
            for W of Widths loop
               declare
                  W_Obj : constant String :=
                    Cldr_Json.Field (Ctx_Obj, To_String (W));
               begin
                  if W_Obj /= "" then
                     Current_Prefix :=
                       Current_Cal & US & Our_Field & US & C & US & W & US;
                     Cldr_Json.For_Each (W_Obj, On_Index'Access);
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Emit_Widths;

   procedure Emit_Eras (Cal_Obj : String) is
      Eras : constant String := Cldr_Json.Field (Cal_Obj, "eras");
      type Era_Map is record
         Json  : Unbounded_String;
         Width : Unbounded_String;
      end record;
      Maps : constant array (1 .. 3) of Era_Map :=
        [(P ("eraNames"), P ("wide")),
         (P ("eraAbbr"), P ("abbreviated")),
         (P ("eraNarrow"), P ("narrow"))];
   begin
      for M of Maps loop
         declare
            Obj : constant String :=
              Cldr_Json.Field (Eras, To_String (M.Json));
         begin
            if Obj /= "" then
               Current_Prefix :=
                 Current_Cal & US & "era" & US & "format" & US
                 & M.Width & US;
               Cldr_Json.For_Each (Obj, On_Index'Access);
            end if;
         end;
      end loop;
   end Emit_Eras;

   procedure On_Calendar (Name : String; Value : String) is
   begin
      Current_Cal := To_Unbounded_String (Name);
      Emit_Widths (Value, "months", "month");
      Emit_Widths (Value, "days", "day");
      Emit_Widths (Value, "quarters", "quarter");
      Emit_Widths (Value, "dayPeriods", "day-period");
      Emit_Eras (Value);
   end On_Calendar;

   --  Union of locale directory names across all calendar packages.
   package Locale_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);
   Locales : Locale_Sets.Set;

   procedure Collect_Locales (Main : String) is
      use Ada.Directories;
      Search : Search_Type;
      Item   : Directory_Entry_Type;
   begin
      if not Exists (Main) then
         return;
      end if;
      Start_Search (Search, Main, "", [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            L : constant String := Simple_Name (Item);
         begin
            if L /= "." and then L /= ".." then
               Locales.Include (L);
            end if;
         end;
      end loop;
      End_Search (Search);
   end Collect_Locales;

   Shards : Natural := 0;

   procedure Write_Shard (Path : String) is
      Output : Ada.Text_IO.File_Type;
   begin
      Rec_Sort.Sort (Records);
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Output, "@name|" & Records.Length'Image);
      for R of Records loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Close (Output);
      Records.Clear;
      Shards := Shards + 1;
   end Write_Shard;

   Any_Upstream : Boolean := False;

begin
   for Pkg of Packages loop
      if Ada.Directories.Exists (Pkg_Main (To_String (Pkg))) then
         Any_Upstream := True;
         Collect_Locales (Pkg_Main (To_String (Pkg)));
      end if;
   end loop;

   if not Any_Upstream then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "no vendored calendar packages");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   declare
      Out_Root : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1)
         else "../share/i18n");
   begin
      for Locale of Locales loop
         for Pkg of Packages loop
            declare
               use Ada.Directories;
               Dir : constant String :=
                 Pkg_Main (To_String (Pkg)) & "/" & Locale;
            begin
               if Exists (Dir) then
                  declare
                     Search : Search_Type;
                     Item   : Directory_Entry_Type;
                  begin
                     Start_Search
                       (Search, Dir, "*.json",
                        [Ordinary_File => True, others => False]);
                     while More_Entries (Search) loop
                        Get_Next_Entry (Search, Item);
                        declare
                           Text : constant String :=
                             Cldr_Json.Read_File (Full_Name (Item));
                           Cals : constant String :=
                             Cldr_Json.Field
                               (Cldr_Json.Field
                                  (Cldr_Json.Field
                                     (Cldr_Json.Field (Text, "main"), Locale),
                                   "dates"),
                                "calendars");
                        begin
                           if Cals /= "" then
                              Cldr_Json.For_Each (Cals, On_Calendar'Access);
                           end if;
                        end;
                     end loop;
                     End_Search (Search);
                  end;
               end if;
            end;
         end loop;

         if not Records.Is_Empty then
            Write_Shard (Out_Root & "/calendars/" & Locale & ".i18ndata");
         end if;
      end loop;
   end;

   Ada.Text_IO.Put_Line ("generated" & Shards'Image & " calendar shard(s)");
end Generate_CLDR_Calendar_Data;
