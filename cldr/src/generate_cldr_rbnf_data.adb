--  Builds RBNF (spellout / ordinal) rules into per-locale shards
--  share/i18n/rbnf/<locale>.i18ndata. The interpreter lives in I18N.Spellout;
--  this just serializes the CLDR rule lists.
--
--  Section "ruleset": key <%ruleset-name>, value the ruleset's rules in order,
--     base1 \x1f text1 \x1e base2 \x1f text2 \x1e ...

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Vectors;
with Cldr_Json;

procedure Generate_CLDR_RBNF_Data is

   HT : constant Character := Character'Val (16#09#);
   US : constant Character := Character'Val (16#1F#);
   RS : constant Character := Character'Val (16#1E#);
   CLDR_Version : constant String := "48.2";

   Root : constant String := "upstream/cldr-json/cldr-rbnf/rbnf";

   package Rec_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   package Rec_Sort is new Rec_Vectors.Generic_Sorting;
   Rulesets : Rec_Vectors.Vector;

   Current_Value : Unbounded_String;

   procedure On_Rule (Base : String; Text : String) is
   begin
      if Length (Current_Value) > 0 then
         Append (Current_Value, RS);
      end if;
      Append (Current_Value, Base & US & Cldr_Json.Unescape (Text));
   end On_Rule;

   procedure On_Ruleset (Name : String; Value : String) is
   begin
      Current_Value := Null_Unbounded_String;
      Cldr_Json.For_Each_Pair (Value, On_Rule'Access);
      if Length (Current_Value) > 0 then
         Rulesets.Append (To_Unbounded_String (Name) & HT & Current_Value);
      end if;
   end On_Ruleset;

   procedure On_Group (Name : String; Value : String) is
      pragma Unreferenced (Name);
   begin
      Cldr_Json.For_Each (Value, On_Ruleset'Access);
   end On_Group;

   Shards : Natural := 0;

   procedure Write_Shard (Path : String) is
      Output : Ada.Text_IO.File_Type;
   begin
      Rec_Sort.Sort (Rulesets);
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Output, "@ruleset|" & Rulesets.Length'Image);
      for R of Rulesets loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Close (Output);
      Rulesets.Clear;
      Shards := Shards + 1;
   end Write_Shard;

begin
   if not Ada.Directories.Exists (Root) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "no vendored rbnf data");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   declare
      Out_Root : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1)
         else "../share/i18n");
      use Ada.Directories;
      Search : Search_Type;
      Item   : Directory_Entry_Type;
   begin
      Start_Search (Search, Root, "*.json",
                    [Ordinary_File => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Base : constant String := Base_Name (Simple_Name (Item));
         begin
            if Base /= "bower" and then Base /= "package" then
               declare
                  Text  : constant String := Cldr_Json.Read_File
                    (Full_Name (Item));
                  Group : constant String :=
                    Cldr_Json.Field (Cldr_Json.Field (Text, "rbnf"), "rbnf");
               begin
                  if Group /= "" then
                     Cldr_Json.For_Each (Group, On_Group'Access);
                     if not Rulesets.Is_Empty then
                        Write_Shard
                          (Out_Root & "/rbnf/" & Base & ".i18ndata");
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end;

   Ada.Text_IO.Put_Line ("generated" & Shards'Image & " rbnf shard(s)");
end Generate_CLDR_RBNF_Data;
