--  Build the transform shards share/i18n/transforms/<basename>.i18ndata (one
--  "meta" record "rules" = the concatenated <tRule> CDATA) and the index
--  share/i18n/transforms/_index.i18ndata ("meta"/"map" = "alias=basename:D ..."
--  where D is F for a forward alias, R for a backward one). testData files are
--  named by these aliases, so the engine resolves a transform name to a shard +
--  direction through the index.
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Directories;         use Ada.Directories;

procedure Generate_CLDR_Transform_Data is
   In_Dir  : constant String := "upstream/transforms";
   Out_Dir : constant String := "../share/i18n/transforms";
   HT      : constant Character := Character'Val (16#09#);

   Idx_Map : Unbounded_String;

   function Read_File (Path : String) return String is
      F   : File_Type;
      Buf : Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Append (Buf, Get_Line (F));
         Append (Buf, ASCII.LF);
      end loop;
      Close (F);
      return To_String (Buf);
   end Read_File;

   --  Value of attribute Name within the first "<transform ...>" tag.
   function Attr (Xml, Name : String) return String is
      T : constant Natural := Index (Xml, "<transform");
      P : Natural;
   begin
      if T = 0 then
         return "";
      end if;
      P := Index (Xml (T .. Xml'Last), Name & "=""");
      if P = 0 then
         return "";
      end if;
      P := P + Name'Length + 2;
      declare
         Q : Natural := P;
      begin
         while Q <= Xml'Last and then Xml (Q) /= '"' loop
            Q := Q + 1;
         end loop;
         return Xml (P .. Q - 1);
      end;
   end Attr;

   --  Flatten a CDATA block to a single line: strip '#' comments (outside quotes
   --  and '[' sets) and turn every newline/tab into a space, since the data-file
   --  format is line-based and rule newlines are only whitespace.
   procedure Flatten (Cdata : String; Into : in out Unbounded_String) is
      In_Q  : Boolean := False;
      Depth : Natural := 0;
      I     : Natural := Cdata'First;
   begin
      while I <= Cdata'Last loop
         declare
            C : constant Character := Cdata (I);
         begin
            if In_Q then
               Append (Into, C);
               if C = ''' then
                  In_Q := False;
               end if;
               I := I + 1;
            elsif C = '\' then
               Append (Into, C);
               if I + 1 <= Cdata'Last then
                  Append (Into, Cdata (I + 1));
               end if;
               I := I + 2;
            elsif C = ''' then
               In_Q := True; Append (Into, C); I := I + 1;
            elsif C = '#' and then Depth = 0 then
               while I <= Cdata'Last and then Cdata (I) /= ASCII.LF loop
                  I := I + 1;
               end loop;
            elsif C = ASCII.LF or else C = ASCII.CR or else C = ASCII.HT then
               Append (Into, ' '); I := I + 1;
            else
               if C = '[' then
                  Depth := Depth + 1;
               elsif C = ']' and then Depth > 0 then
                  Depth := Depth - 1;
               end if;
               Append (Into, C); I := I + 1;
            end if;
         end;
      end loop;
   end Flatten;

   --  Concatenate every <tRule> in the file (flattened). A rule body is either
   --  a <![CDATA[ ... ]]> section or plain text (pure ::-chains use the latter).
   function All_Rules (Xml : String) return String is
      Res : Unbounded_String;
      P   : Natural := Xml'First;
   begin
      loop
         declare
            Cr : constant Natural := Index (Xml (P .. Xml'Last), "<tRule");
         begin
            exit when Cr = 0;
            declare
               GT  : constant Natural := Index (Xml (Cr .. Xml'Last), ">");
               End_T : constant Natural := Index (Xml (Cr .. Xml'Last), "</tRule>");
            begin
               exit when GT = 0 or else End_T = 0;
               declare
                  Inner : String renames Xml (GT + 1 .. End_T - 1);
                  C1    : constant Natural := Index (Inner, "[CDATA[");
                  C2    : constant Natural := Index (Inner, "]]>");
               begin
                  if C1 /= 0 and then C2 /= 0 then
                     Flatten (Inner (C1 + 7 .. C2 - 1), Res);
                  else
                     Flatten (Inner, Res);
                  end if;
                  Append (Res, ' ');
                  P := End_T + 8;
               end;
            end;
         end;
      end loop;
      return To_String (Res);
   end All_Rules;

   --  Register each whitespace-separated alias token in the index.
   procedure Register (Aliases, Base : String; Dir : Character) is
      I : Natural := Aliases'First;
   begin
      while I <= Aliases'Last loop
         while I <= Aliases'Last and then Aliases (I) = ' ' loop
            I := I + 1;
         end loop;
         exit when I > Aliases'Last;
         declare
            J : Natural := I;
         begin
            while J <= Aliases'Last and then Aliases (J) /= ' ' loop
               J := J + 1;
            end loop;
            if Length (Idx_Map) > 0 then
               Append (Idx_Map, " ");
            end if;
            Append (Idx_Map, Aliases (I .. J - 1) & "=" & Base & ":" & Dir);
            I := J + 1;
         end;
      end loop;
   end Register;

   Search : Search_Type;
   Item   : Directory_Entry_Type;
   Count  : Natural := 0;
begin
   Create_Path (Out_Dir);
   Start_Search (Search, In_Dir, "*.xml");
   while More_Entries (Search) loop
      Get_Next_Entry (Search, Item);
      declare
         Name  : constant String := Simple_Name (Item);
         Base  : constant String := Name (Name'First .. Name'Last - 4);
         Xml   : constant String := Read_File (Full_Name (Item));
         Rules : constant String := All_Rules (Xml);
         Src   : constant String := Attr (Xml, "source");
         Tgt   : constant String := Attr (Xml, "target");
         Dir   : constant String := Attr (Xml, "direction");
         FAli  : constant String := Attr (Xml, "alias");
         BAli  : constant String := Attr (Xml, "backwardAlias");
      begin
         if Rules /= "" then
            declare
               Out_F : File_Type;
            begin
               Create (Out_F, Out_File, Out_Dir & "/" & Base & ".i18ndata");
               Put_Line (Out_F, "I18NDATA|1|16.0.0");
               Put_Line (Out_F, "@meta|1");
               Put_Line (Out_F, "rules" & HT & Rules);
               Close (Out_F);
               Count := Count + 1;
            end;
            --  The file basename and Source-Target are forward names too.
            Register (Base, Base, 'F');
            if Src /= "" and then Tgt /= "" then
               Register (Src & "-" & Tgt, Base, 'F');
            end if;
            Register (FAli, Base, 'F');
            if Dir = "both" then
               Register (BAli, Base, 'R');
               if Src /= "" and then Tgt /= "" then
                  Register (Tgt & "-" & Src, Base, 'R');
               end if;
            end if;
         end if;
      end;
   end loop;
   End_Search (Search);

   declare
      Out_F : File_Type;
   begin
      Create (Out_F, Out_File, Out_Dir & "/_index.i18ndata");
      Put_Line (Out_F, "I18NDATA|1|16.0.0");
      Put_Line (Out_F, "@meta|1");
      Put_Line (Out_F, "map" & HT & To_String (Idx_Map));
      Close (Out_F);
   end;
   Put_Line ("transform shards written:" & Count'Image);
end Generate_CLDR_Transform_Data;
