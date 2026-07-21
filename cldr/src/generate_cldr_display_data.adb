--  Builds share/i18n/display-names.i18ndata from the upstream cldr-localenames /
--  cldr-misc / cldr-units / cldr-core JSON, in the packed, sorted, bisectable
--  format that I18n.Data_Store loads at runtime. Decoupled from the compiled
--  subset pipeline: display names are served from a runtime data file, so this
--  tool reads upstream directly rather than threading new kinds through the
--  export/normalize/subset stages.
--
--  Sections: language, script, territory, variant, key, type, locale-pattern,
--  delimiter, measurement-system, measurement-name. Keys are
--  "<locale>\x1f<code>" (or plain "<territory>" for measurement-system).

with Ada.Text_IO;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Vectors;

procedure Generate_CLDR_Display_Data is

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   US : constant Character := Character'Val (16#1F#);   --  intra-key separator

   CLDR_Version : constant String := "48.2";

   Localenames : constant String := "upstream/cldr-json/cldr-localenames-full/main";
   Misc        : constant String := "upstream/cldr-json/cldr-misc-full/main";
   Units       : constant String := "upstream/cldr-json/cldr-units-full/main";
   Supplemental : constant String :=
     "upstream/cldr-json/cldr-core/supplemental/measurementData.json";

   type Dir_Names is array (Positive range <>) of Unbounded_String;

   Errors : Natural := 0;
   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
      Errors := Errors + 1;
   end Fail;

   --  ------------------------------------------------------------------
   --  Minimal JSON reader (objects of string/object values, escapes handled)
   --  ------------------------------------------------------------------

   function Read_File (Path : String) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      Len : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Open (F, In_File, Path);
      Len := Natural (Ada.Directories.Size (Path));
      declare
         SE     : Stream_Element_Array (1 .. Stream_Element_Offset (Len));
         Last   : Stream_Element_Offset := 0;
         Filled : Stream_Element_Offset := 0;
         Result : String (1 .. Len);
      begin
         while Filled < SE'Last loop
            Read (F, SE (Filled + 1 .. SE'Last), Last);
            exit when Last < Filled + 1;
            Filled := Last;
         end loop;
         Close (F);
         for I in 1 .. Natural (Filled) loop
            Result (I) := Character'Val (SE (Stream_Element_Offset (I)));
         end loop;
         return Result (1 .. Natural (Filled));
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
         return "";
   end Read_File;

   --  Iterate the members of the object in Text, calling Process (name, raw
   --  value). Raw value keeps JSON escapes; string values exclude the quotes.
   procedure For_Each
     (Text    : String;
      Process : not null access procedure (Name : String; Value : String))
   is
      Index   : Natural := Text'First;
      In_Text : Boolean;

      procedure Skip_WS is
      begin
         while Index <= Text'Last
           and then Text (Index) in ' ' | HT | Character'Val (13) | LF
         loop
            Index := Index + 1;
         end loop;
      end Skip_WS;

      function Read_String return String is
         First : Natural;
      begin
         if Index > Text'Last or else Text (Index) /= '"' then
            return "";
         end if;
         Index := Index + 1;
         First := Index;
         while Index <= Text'Last loop
            if Text (Index) = '\' then
               Index := Index + 2;
            elsif Text (Index) = '"' then
               declare
                  Result : constant String := Text (First .. Index - 1);
               begin
                  Index := Index + 1;
                  return Result;
               end;
            else
               Index := Index + 1;
            end if;
         end loop;
         return "";
      end Read_String;

      function Read_Value return String is
         First : constant Natural := Index;
         Depth : Natural := 0;
      begin
         if Index > Text'Last then
            return "";
         elsif Text (Index) = '{' or else Text (Index) = '[' then
            In_Text := False;
            while Index <= Text'Last loop
               if Text (Index) = '"' then
                  In_Text := not In_Text;
               elsif In_Text and then Text (Index) = '\' then
                  Index := Index + 1;
               elsif not In_Text then
                  if Text (Index) in '{' | '[' then
                     Depth := Depth + 1;
                  elsif Text (Index) in '}' | ']' then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        Index := Index + 1;
                        return Text (First .. Index - 1);
                     end if;
                  end if;
               end if;
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '"' then
            --  Return the string content (no quotes); object/array values below
            --  keep their braces so navigation and the nesting guard still work.
            return Read_String;
         else
            while Index <= Text'Last and then Text (Index) not in ',' | '}' loop
               Index := Index + 1;
            end loop;
            return Text (First .. Index - 1);
         end if;
         return "";
      end Read_Value;
   begin
      Skip_WS;
      if Index > Text'Last or else Text (Index) /= '{' then
         return;
      end if;
      Index := Index + 1;
      loop
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) = '}';
         declare
            Name : constant String := Read_String;
         begin
            Skip_WS;
            exit when Index > Text'Last or else Text (Index) /= ':';
            Index := Index + 1;
            Skip_WS;
            declare
               Value : constant String := Read_Value;
            begin
               Process (Name, Value);
            end;
         end;
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) /= ',';
         Index := Index + 1;
      end loop;
   end For_Each;

   --  Value text of the named field of the object in Text ("" if absent). For a
   --  string field this is the string content (an object/array, its braces).
   Found_Value : Unbounded_String;
   Want_Field  : Unbounded_String;
   procedure Capture (Name : String; Value : String) is
   begin
      if Name = To_String (Want_Field) then
         Found_Value := To_Unbounded_String (Value);
      end if;
   end Capture;

   function Field (Text : String; Name : String) return String is
   begin
      Want_Field := To_Unbounded_String (Name);
      Found_Value := Null_Unbounded_String;
      For_Each (Text, Capture'Access);
      return To_String (Found_Value);
   end Field;

   --  Decode JSON string escapes to raw UTF-8 bytes.
   function Unescape (Raw : String) return String is
      Result : String (1 .. Raw'Length * 2);
      Last   : Natural := 0;
      I      : Natural := Raw'First;

      procedure Put (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Put;

      procedure Put_Code_Point (CP : Natural) is
      begin
         if CP <= 16#7F# then
            Put (Character'Val (CP));
         elsif CP <= 16#7FF# then
            Put (Character'Val (16#C0# + CP / 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         elsif CP <= 16#FFFF# then
            Put (Character'Val (16#E0# + CP / 16#1000#));
            Put (Character'Val (16#80# + (CP / 16#40#) mod 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         else
            Put (Character'Val (16#F0# + CP / 16#40000#));
            Put (Character'Val (16#80# + (CP / 16#1000#) mod 16#40#));
            Put (Character'Val (16#80# + (CP / 16#40#) mod 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         end if;
      end Put_Code_Point;

      function Hex (C : Character) return Natural is
        (case C is
            when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
            when 'a' .. 'f' => 10 + Character'Pos (C) - Character'Pos ('a'),
            when 'A' .. 'F' => 10 + Character'Pos (C) - Character'Pos ('A'),
            when others     => 0);
   begin
      while I <= Raw'Last loop
         if Raw (I) = '\' and then I < Raw'Last then
            case Raw (I + 1) is
               when '"'  => Put ('"'); I := I + 2;
               when '\'  => Put ('\'); I := I + 2;
               when '/'  => Put ('/'); I := I + 2;
               when 'n'  => Put (LF);  I := I + 2;
               when 't'  => Put (HT);  I := I + 2;
               when 'r'  => Put (Character'Val (13)); I := I + 2;
               when 'b'  => Put (Character'Val (8));  I := I + 2;
               when 'f'  => Put (Character'Val (12)); I := I + 2;
               when 'u'  =>
                  if I + 5 <= Raw'Last then
                     declare
                        CP : constant Natural :=
                          Hex (Raw (I + 2)) * 16#1000#
                          + Hex (Raw (I + 3)) * 16#100#
                          + Hex (Raw (I + 4)) * 16#10#
                          + Hex (Raw (I + 5));
                        Lo : Natural;
                     begin
                        --  UTF-16 surrogate pair.
                        if CP in 16#D800# .. 16#DBFF#
                          and then I + 11 <= Raw'Last
                          and then Raw (I + 6) = '\' and then Raw (I + 7) = 'u'
                        then
                           Lo := Hex (Raw (I + 8)) * 16#1000#
                             + Hex (Raw (I + 9)) * 16#100#
                             + Hex (Raw (I + 10)) * 16#10#
                             + Hex (Raw (I + 11));
                           Put_Code_Point
                             (16#10000#
                              + (CP - 16#D800#) * 16#400#
                              + (Lo - 16#DC00#));
                           I := I + 12;
                        else
                           Put_Code_Point (CP);
                           I := I + 6;
                        end if;
                     end;
                  else
                     I := I + 2;
                  end if;
               when others => Put (Raw (I + 1)); I := I + 2;
            end case;
         else
            Put (Raw (I));
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Last);
   end Unescape;

   --  ------------------------------------------------------------------
   --  Record collection, sorting, section output
   --  ------------------------------------------------------------------

   package Rec_Vectors is new Ada.Containers.Vectors
     (Positive, Unbounded_String);
   package Rec_Sort is new Rec_Vectors.Generic_Sorting ("<" => "<");

   Records : Rec_Vectors.Vector;

   procedure Add (Key : String; Value : String) is
   begin
      --  Skip empties and keys/values that would break the framing.
      if Value = "" then
         return;
      end if;
      Records.Append (To_Unbounded_String (Key & HT & Value));
   end Add;

   Output : Ada.Text_IO.File_Type;

   procedure Write_Section (Name : String) is
   begin
      Rec_Sort.Sort (Records);
      Ada.Text_IO.Put_Line
        (Output, "@" & Name & "|" & Records.Length'Image);
      for R of Records loop
         Ada.Text_IO.Put_Line (Output, To_String (R));
      end loop;
      Records.Clear;
   end Write_Section;

   --  ------------------------------------------------------------------
   --  Locale enumeration and per-section extraction
   --  ------------------------------------------------------------------

   Current_Locale : Unbounded_String;

   procedure Add_Code (Name : String; Value : String) is
   begin
      --  Only leaf string names; skip nested objects/arrays (e.g. a nested
      --  "types" grouping), whose raw value would start with a brace.
      if Value'Length > 0 and then Value (Value'First) in '{' | '[' then
         return;
      end if;
      Add (To_String (Current_Locale) & US & Name, Unescape (Value));
   end Add_Code;

   --  For each locale directory under Root, read File and pass the object found
   --  at localeDisplayNames.<Group> (or Group_Path) to Add_Code.
   procedure Collect_Display
     (Root : String; File : String; Group : String)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      use Ada.Directories;
   begin
      if not Exists (Root) then
         Fail ("missing CLDR directory: " & Root);
         return;
      end if;
      Start_Search (Search, Root, "",
                    [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Loc : constant String := Simple_Name (Item);
         begin
            if Loc /= "." and then Loc /= ".." then
               declare
                  Path : constant String := Root & "/" & Loc & "/" & File;
                  Text : constant String := Read_File (Path);
               begin
                  if Text /= "" then
                     Current_Locale := To_Unbounded_String (Loc);
                     declare
                        Main  : constant String := Field (Text, "main");
                        L_Obj : constant String := Field (Main, Loc);
                        LDN   : constant String :=
                          Field (L_Obj, "localeDisplayNames");
                        Grp   : constant String := Field (LDN, Group);
                     begin
                        if Grp /= "" then
                           For_Each (Grp, Add_Code'Access);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Collect_Display;

   procedure Collect_Delimiters is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      use Ada.Directories;
   begin
      if not Exists (Misc) then
         Fail ("missing CLDR misc directory: " & Misc);
         return;
      end if;
      Start_Search (Search, Misc, "", [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Loc : constant String := Simple_Name (Item);
         begin
            if Loc /= "." and then Loc /= ".." then
               declare
                  Text : constant String :=
                    Read_File (Misc & "/" & Loc & "/delimiters.json");
               begin
                  if Text /= "" then
                     declare
                        D : constant String :=
                          Field (Field (Field (Text, "main"), Loc),
                                 "delimiters");
                     begin
                        for Mark of Dir_Names'
                          (To_Unbounded_String ("quotationStart"),
                           To_Unbounded_String ("quotationEnd"),
                           To_Unbounded_String ("alternateQuotationStart"),
                           To_Unbounded_String ("alternateQuotationEnd"))
                        loop
                           Add (Loc & US & To_String (Mark),
                                Unescape (Field (D, To_String (Mark))));
                        end loop;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Collect_Delimiters;

   procedure Collect_Measurement_Names is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      use Ada.Directories;
   begin
      if not Exists (Units) then
         return;
      end if;
      Start_Search (Search, Units, "", [Directory => True, others => False]);
      while More_Entries (Search) loop
         Get_Next_Entry (Search, Item);
         declare
            Loc : constant String := Simple_Name (Item);
         begin
            if Loc /= "." and then Loc /= ".." then
               declare
                  Text : constant String :=
                    Read_File (Units & "/" & Loc & "/measurementSystemNames.json");
               begin
                  if Text /= "" then
                     Current_Locale := To_Unbounded_String (Loc);
                     declare
                        M : constant String :=
                          Field (Field (Field (Field (Text, "main"), Loc),
                                        "localeDisplayNames"),
                                 "measurementSystemNames");
                     begin
                        if M /= "" then
                           For_Each (M, Add_Code'Access);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      End_Search (Search);
   end Collect_Measurement_Names;

   procedure Add_Territory_System (Name : String; Value : String) is
   begin
      Add (Name, Unescape (Value));
   end Add_Territory_System;

   procedure Collect_Measurement_System is
      Text : constant String := Read_File (Supplemental);
      MS   : constant String :=
        Field (Field (Field (Text, "supplemental"), "measurementData"),
               "measurementSystem");
   begin
      if MS /= "" then
         For_Each (MS, Add_Territory_System'Access);
      end if;
   end Collect_Measurement_System;

begin
   --  Run from the cldr crate root (Alire pre-build actions are).
   declare
      Out_Path : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1)
         else "../share/i18n/display-names.i18ndata");
   begin
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Out_Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Out_Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);

      Collect_Display (Localenames, "languages.json", "languages");
      Write_Section ("language");
      Collect_Display (Localenames, "scripts.json", "scripts");
      Write_Section ("script");
      Collect_Display (Localenames, "territories.json", "territories");
      Write_Section ("territory");
      Collect_Display (Localenames, "variants.json", "variants");
      Write_Section ("variant");
      Collect_Display (Localenames, "localeDisplayNames.json", "keys");
      Write_Section ("key");
      Collect_Display (Localenames, "localeDisplayNames.json", "types");
      Write_Section ("type");
      Collect_Display (Localenames, "localeDisplayNames.json", "localeDisplayPattern");
      Write_Section ("locale-pattern");
      Collect_Delimiters;
      Write_Section ("delimiter");
      Collect_Measurement_System;
      Write_Section ("measurement-system");
      Collect_Measurement_Names;
      Write_Section ("measurement-name");

      Ada.Text_IO.Close (Output);
   end;

   if Errors > 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "display-data generation had" & Errors'Image & " error(s)");
      Ada.Command_Line.Set_Exit_Status (1);
   else
      Ada.Text_IO.Put_Line ("generated display-names.i18ndata");
   end if;
end Generate_CLDR_Display_Data;
