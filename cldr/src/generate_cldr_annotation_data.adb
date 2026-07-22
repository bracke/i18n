--  Builds the emoji-annotation runtime data: one shard per locale under
--  share/i18n/annotations/<locale>.i18ndata (and annotations-derived/... for the
--  derived skin-tone / ZWJ / flag sequences). Per-locale sharding keeps the
--  loader's cost proportional to the locales actually used, not to the ~150 MB
--  corpus. Reads the upstream cldr-annotations JSON directly.
--
--  Each shard has two sections keyed on the emoji (UTF-8):
--     name    <emoji> -> display name        (CLDR "tts"[0])
--     keyword <emoji> -> \x1f-joined keywords (CLDR "default"[])

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Vectors;
with Cldr_Json;

procedure Generate_CLDR_Annotation_Data is

   HT : constant Character := Character'Val (16#09#);
   US : constant Character := Character'Val (16#1F#);

   CLDR_Version : constant String := "48.2";

   Base    : constant String :=
     "upstream/cldr-json/cldr-annotations-full/annotations";
   Derived : constant String :=
     "upstream/cldr-json/cldr-annotations-derived-full/annotationsDerived";

   Errors : Natural := 0;
   Shards : Natural := 0;

   package Rec_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   package Rec_Sort is new Rec_Vectors.Generic_Sorting;

   Names    : Rec_Vectors.Vector;
   Keywords : Rec_Vectors.Vector;

   --  Per-emoji extraction (For_Each callback over the emoji map).
   Current_Emoji : Unbounded_String;
   Kw_Join       : Unbounded_String;
   Name_Value    : Unbounded_String;

   procedure Take_Name (Value : String) is
   begin
      if Length (Name_Value) = 0 then
         Name_Value := To_Unbounded_String (Cldr_Json.Unescape (Value));
      end if;
   end Take_Name;

   procedure Take_Keyword (Value : String) is
   begin
      if Length (Kw_Join) > 0 then
         Append (Kw_Join, US);
      end if;
      Append (Kw_Join, Cldr_Json.Unescape (Value));
   end Take_Keyword;

   procedure On_Emoji (Name : String; Value : String) is
   begin
      Current_Emoji := To_Unbounded_String (Cldr_Json.Unescape (Name));
      Name_Value := Null_Unbounded_String;
      Kw_Join := Null_Unbounded_String;
      Cldr_Json.For_Each_String (Cldr_Json.Field (Value, "tts"),
                                 Take_Name'Access);
      Cldr_Json.For_Each_String (Cldr_Json.Field (Value, "default"),
                                 Take_Keyword'Access);
      if Length (Name_Value) > 0 then
         Names.Append (Current_Emoji & HT & Name_Value);
      end if;
      if Length (Kw_Join) > 0 then
         Keywords.Append (Current_Emoji & HT & Kw_Join);
      end if;
   end On_Emoji;

   procedure Write_Shard (Path : String) is
      Output : Ada.Text_IO.File_Type;
   begin
      Rec_Sort.Sort (Names);
      Rec_Sort.Sort (Keywords);
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Output, "@name|" & Names.Length'Image);
      for R of Names loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Put_Line (Output, "@keyword|" & Keywords.Length'Image);
      for R of Keywords loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Close (Output);
      Names.Clear;
      Keywords.Clear;
      Shards := Shards + 1;
   end Write_Shard;

   procedure Generate_Tree
     (Root : String; Out_Dir : String; Top_Field : String)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      use Ada.Directories;
   begin
      if not Exists (Root) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error, "missing annotation tree: " & Root);
         Errors := Errors + 1;
         return;
      end if;
      Start_Search (Search, Root, "", [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Loc : constant String := Simple_Name (Item);
         begin
            if Loc /= "." and then Loc /= ".." then
               declare
                  Text : constant String :=
                    Cldr_Json.Read_File (Root & "/" & Loc & "/annotations.json");
               begin
                  if Text /= "" then
                     declare
                        Emoji_Map : constant String :=
                          Cldr_Json.Field
                            (Cldr_Json.Field (Text, Top_Field),
                             "annotations");
                     begin
                        if Emoji_Map /= "" then
                           Cldr_Json.For_Each (Emoji_Map, On_Emoji'Access);
                           Write_Shard
                             (Out_Dir & "/" & Loc & ".i18ndata");
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Generate_Tree;

begin
   declare
      Out_Root : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1)
         else "../share/i18n");
   begin
      Generate_Tree (Base, Out_Root & "/annotations", "annotations");
      Generate_Tree (Derived, Out_Root & "/annotations-derived", "annotationsDerived");
   end;

   if Errors > 0 then
      Ada.Command_Line.Set_Exit_Status (1);
   else
      Ada.Text_IO.Put_Line
        ("generated" & Shards'Image & " annotation shard(s)");
   end if;
end Generate_CLDR_Annotation_Data;
