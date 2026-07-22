--  Builds person-name formatting data into per-locale shards
--  share/i18n/person-names/<locale>.i18ndata. Holds the CLDR name patterns and
--  the per-locale config the formatter needs; the formatting algorithm lives in
--  I18N.Person_Names.
--
--  Sections:
--     pattern  <order>\x1f<length>\x1f<usage>\x1f<formality>  -> pattern
--     config   {initial|initialSequence|nativeSpace|foreignSpace|surnameFirst}

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Vectors;
with Cldr_Json;

procedure Generate_CLDR_Personname_Data is

   HT : constant Character := Character'Val (16#09#);
   US : constant Character := Character'Val (16#1F#);
   CLDR_Version : constant String := "48.2";

   Root : constant String :=
     "upstream/cldr-json/cldr-person-names-full/main";

   package Rec_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   package Rec_Sort is new Rec_Vectors.Generic_Sorting;
   Patterns : Rec_Vectors.Vector;
   Config   : Rec_Vectors.Vector;

   type Str_List is array (Positive range <>) of Unbounded_String;
   function U (S : String) return Unbounded_String renames To_Unbounded_String;

   Orders     : constant Str_List :=
     [U ("givenFirst"), U ("surnameFirst"), U ("sorting")];
   Lengths    : constant Str_List := [U ("long"), U ("medium"), U ("short")];
   Usages     : constant Str_List :=
     [U ("referring"), U ("addressing"), U ("monogram")];
   Formalities : constant Str_List := [U ("formal"), U ("informal")];

   Joined : Unbounded_String;
   procedure Join_Elem (Value : String) is
   begin
      if Length (Joined) > 0 then
         Append (Joined, US);
      end if;
      Append (Joined, Cldr_Json.Unescape (Value));
   end Join_Elem;

   Shards : Natural := 0;

   procedure Write_Shard (Path : String) is
      Output : Ada.Text_IO.File_Type;
   begin
      Rec_Sort.Sort (Patterns);
      Rec_Sort.Sort (Config);
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Output, "@pattern|" & Patterns.Length'Image);
      for R of Patterns loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Put_Line (Output, "@config|" & Config.Length'Image);
      for R of Config loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Ada.Text_IO.Close (Output);
      Patterns.Clear;
      Config.Clear;
      Shards := Shards + 1;
   end Write_Shard;

   procedure Add_Config (Key, Value : String) is
   begin
      if Value /= "" then
         Config.Append (To_Unbounded_String (Key & HT & Value));
      end if;
   end Add_Config;

begin
   if not Ada.Directories.Exists (Root) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "no vendored person-names data");
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
      Start_Search (Search, Root, "", [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Locale : constant String := Simple_Name (Item);
         begin
            if Locale /= "." and then Locale /= ".." then
               declare
                  Text : constant String :=
                    Cldr_Json.Read_File
                      (Root & "/" & Locale & "/personNames.json");
                  PN   : constant String :=
                    Cldr_Json.Field
                      (Cldr_Json.Field
                         (Cldr_Json.Field (Text, "main"), Locale),
                       "personNames");
               begin
                  if PN /= "" then
                     Extract_And_Write :
                     declare
                        Names : constant String :=
                          Cldr_Json.Field (PN, "personName");
                     begin
                        for O of Orders loop
                           declare
                              O_Obj : constant String :=
                                Cldr_Json.Field (Names, To_String (O));
                           begin
                              for L of Lengths loop
                                 declare
                                    L_Obj : constant String :=
                                      Cldr_Json.Field (O_Obj, To_String (L));
                                 begin
                                    for Usg of Usages loop
                                       declare
                                          U_Obj : constant String :=
                                            Cldr_Json.Field
                                              (L_Obj, To_String (Usg));
                                       begin
                                          for F of Formalities loop
                                             declare
                                                Pat : constant String :=
                                                  Cldr_Json.Unescape
                                                    (Cldr_Json.Field
                                                       (U_Obj, To_String (F)));
                                             begin
                                                if Pat /= "" then
                                                   Patterns.Append
                                                     (O & US & L & US & Usg
                                                      & US & F & HT & Pat);
                                                end if;
                                             end;
                                          end loop;
                                       end;
                                    end loop;
                                 end;
                              end loop;
                           end;
                        end loop;

                        Add_Config
                          ("initial",
                           Cldr_Json.Unescape (Cldr_Json.Field (PN, "initial")));
                        Add_Config
                          ("initialSequence",
                           Cldr_Json.Unescape
                             (Cldr_Json.Field (PN, "initialSequence")));
                        Add_Config
                          ("nativeSpace",
                           Cldr_Json.Unescape
                             (Cldr_Json.Field (PN, "nativeSpaceReplacement")));
                        Add_Config
                          ("foreignSpace",
                           Cldr_Json.Unescape
                             (Cldr_Json.Field (PN, "foreignSpaceReplacement")));
                        Joined := Null_Unbounded_String;
                        Cldr_Json.For_Each_String
                          (Cldr_Json.Field (PN, "surnameFirst"),
                           Join_Elem'Access);
                        Add_Config ("surnameFirst", To_String (Joined));

                        if not Patterns.Is_Empty then
                           Write_Shard
                             (Out_Root & "/person-names/" & Locale
                              & ".i18ndata");
                        else
                           Patterns.Clear;
                           Config.Clear;
                        end if;
                     end Extract_And_Write;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end;

   Ada.Text_IO.Put_Line ("generated" & Shards'Image & " person-name shard(s)");
end Generate_CLDR_Personname_Data;
