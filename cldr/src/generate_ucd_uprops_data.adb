--  Build share/i18n/uprops.i18ndata: the Unicode properties the transform
--  engine's UnicodeSets need (Script, General_Category) plus the case mappings
--  its ::Lower/::Upper/::Title built-ins need (simple, from UnicodeData, and full
--  context/locale-sensitive, from SpecialCasing).
--
--  Section "prop": records "gc" and "script", each a sorted "lo:hi:VALUE" range
--  list. Section "case": records "lower"/"upper"/"title" (simple, "cp:cp ..."),
--  and "special" ("cp:lower:upper:title:condition ..." with '.'-joined hex seqs).
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Strings;             use Ada.Strings;
with Ada.Strings.Fixed;       use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;

procedure Generate_UCD_Uprops_Data is
   UCD : constant String := "upstream/ucd16/";
   Out_Path : constant String := "../share/i18n/uprops.i18ndata";

   HT : constant Character := Character'Val (16#09#);

   function Hex (S : String) return Natural is
      V : Natural := 0;
   begin
      for C of S loop
         case C is
            when '0' .. '9' => V := V * 16 + (Character'Pos (C) - 48);
            when 'A' .. 'F' => V := V * 16 + (Character'Pos (C) - 55);
            when 'a' .. 'f' => V := V * 16 + (Character'Pos (C) - 87);
            when others => null;
         end case;
      end loop;
      return V;
   end Hex;

   Digs : constant String := "0123456789ABCDEF";
   function H6 (V : Natural) return String is
      R : String (1 .. 6);
      N : Natural := V;
   begin
      for I in reverse R'Range loop
         R (I) := Digs (N mod 16 + 1);
         N := N / 16;
      end loop;
      return R;
   end H6;

   function Field (Line : String; N : Natural) return String is
      Start : Natural := Line'First;
      Idx   : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) = ';' then
            if Idx = N then
               return Trim (Line (Start .. I - 1), Both);
            end if;
            Idx := Idx + 1;
            Start := I + 1;
         end if;
      end loop;
      return (if Idx = N then Trim (Line (Start .. Line'Last), Both) else "");
   end Field;

   --  Read a "START..END ; VALUE # ..." property file into a range list value.
   function Ranges_Of (Name : String) return String is
      F   : File_Type;
      Out_S : Unbounded_String;
   begin
      Open (F, In_File, UCD & Name);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1 else Index (Line, "#"));
            Bdy  : constant String := Line (Line'First .. Hash - 1);
            Semi : constant Natural := Index (Bdy, ";");
         begin
            if Semi /= 0 then
               declare
                  CPs  : constant String := Trim (Bdy (Bdy'First .. Semi - 1), Both);
                  Val  : constant String := Trim (Bdy (Semi + 1 .. Bdy'Last), Both);
                  Dots : constant Natural := Index (CPs, "..");
                  Lo   : constant Natural :=
                    (if Dots = 0 then Hex (CPs) else Hex (CPs (CPs'First .. Dots - 1)));
                  Hi   : constant Natural :=
                    (if Dots = 0 then Lo else Hex (CPs (Dots + 2 .. CPs'Last)));
               begin
                  if Val /= "" then
                     if Length (Out_S) > 0 then
                        Append (Out_S, " ");
                     end if;
                     Append (Out_S, H6 (Lo) & ":" & H6 (Hi) & ":" & Val);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
      return To_String (Out_S);
   end Ranges_Of;

   --  Ranges of one binary property (e.g. "Lowercase") from a
   --  "START..END ; Property" file such as DerivedCoreProperties.txt. Each range
   --  is tagged with Prop so the loader can filter by property name.
   function Prop_Ranges (Name, Prop : String) return String is
      F   : File_Type;
      Out_S : Unbounded_String;
   begin
      Open (F, In_File, UCD & Name);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1 else Index (Line, "#"));
            Bdy  : constant String := Line (Line'First .. Hash - 1);
            Semi : constant Natural := Index (Bdy, ";");
         begin
            if Semi /= 0 then
               declare
                  CPs  : constant String := Trim (Bdy (Bdy'First .. Semi - 1), Both);
                  Val  : constant String := Trim (Bdy (Semi + 1 .. Bdy'Last), Both);
                  Dots : constant Natural := Index (CPs, "..");
                  Lo   : constant Natural :=
                    (if Dots = 0 then Hex (CPs) else Hex (CPs (CPs'First .. Dots - 1)));
                  Hi   : constant Natural :=
                    (if Dots = 0 then Lo else Hex (CPs (Dots + 2 .. CPs'Last)));
               begin
                  if Val = Prop then
                     if Length (Out_S) > 0 then
                        Append (Out_S, " ");
                     end if;
                     Append (Out_S, H6 (Lo) & ":" & H6 (Hi) & ":" & Prop);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
      return To_String (Out_S);
   end Prop_Ranges;

   --  Simple case mappings from UnicodeData (fields 12 upper, 13 lower, 14 title).
   Lower_S, Upper_S, Title_S : Unbounded_String;
   procedure Load_Simple_Case is
      F : File_Type;
      procedure Add (Buf : in out Unbounded_String; CPs, Mapped : String) is
      begin
         if Length (Buf) > 0 then
            Append (Buf, " ");
         end if;
         Append (Buf, CPs & ":" & H6 (Hex (Mapped)));
      end Add;
   begin
      Open (F, In_File, UCD & "UnicodeData.txt");
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            CPs  : constant String := Field (Line, 0);
            Up   : constant String := Field (Line, 12);
            Lo   : constant String := Field (Line, 13);
            Ti   : constant String := Field (Line, 14);
         begin
            if CPs /= "" then
               if Up /= "" then
                  Add (Upper_S, CPs, Up);
               end if;
               if Lo /= "" then
                  Add (Lower_S, CPs, Lo);
               end if;
               if Ti /= "" then
                  Add (Title_S, CPs, Ti);
               end if;
            end if;
         end;
      end loop;
      Close (F);
   end Load_Simple_Case;

   --  Full case mappings from SpecialCasing (skip lines with conditions we do not
   --  model? no -- keep the condition string so the engine can apply it).
   Special_S : Unbounded_String;
   procedure Load_Special_Case is
      F : File_Type;
      function Seq (S : String) return String is
         R : Unbounded_String;
         I : Natural := S'First;
      begin
         while I <= S'Last loop
            declare
               J : Natural := I;
            begin
               while J <= S'Last and then S (J) /= ' ' loop
                  J := J + 1;
               end loop;
               if Length (R) > 0 then
                  Append (R, ".");
               end if;
               Append (R, H6 (Hex (S (I .. J - 1))));
               I := J + 1;
            end;
         end loop;
         return To_String (R);
      end Seq;
   begin
      Open (F, In_File, UCD & "SpecialCasing.txt");
      while not End_Of_File (F) loop
         declare
            Raw  : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Raw, "#") = 0 then Raw'Last + 1 else Index (Raw, "#"));
            Line : constant String := Trim (Raw (Raw'First .. Hash - 1), Both);
         begin
            if Line'Length > 0 and then Index (Line, ";") /= 0 then
               declare
                  CPs  : constant String := Field (Line, 0);
                  LowS : constant String := Field (Line, 1);
                  TitS : constant String := Field (Line, 2);
                  UppS : constant String := Field (Line, 3);
                  Raw  : constant String := Field (Line, 4);
                  Cond : String := Raw;   --  spaces -> '_' (kept as one token)
               begin
                  for K in Cond'Range loop
                     if Cond (K) = ' ' then
                        Cond (K) := '_';
                     end if;
                  end loop;
                  if Length (Special_S) > 0 then
                     Append (Special_S, " ");
                  end if;
                  Append (Special_S,
                          H6 (Hex (CPs)) & ":" & Seq (LowS) & ":" & Seq (UppS)
                          & ":" & Seq (TitS) & ":" & Cond);
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Load_Special_Case;

   --  Script short-code -> long-name aliases (PropertyValueAliases "sc" lines),
   --  so UnicodeSets written [:sc=Cher:] resolve to the long Scripts.txt names.
   function Script_Aliases return String is
      F : File_Type;
      Out_S : Unbounded_String;
   begin
      Open (F, In_File, UCD & "PropertyValueAliases.txt");
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
         begin
            if Line'Length > 3 and then Line (Line'First .. Line'First + 2) = "sc "
            then
               declare
                  Short : constant String := Field (Line, 1);
                  Long  : constant String := Field (Line, 2);
               begin
                  if Short /= "" and then Long /= "" then
                     if Length (Out_S) > 0 then
                        Append (Out_S, " ");
                     end if;
                     Append (Out_S, Short & ":" & Long);
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
      return To_String (Out_S);
   end Script_Aliases;

   Out_F : File_Type;
begin
   Load_Simple_Case;
   Load_Special_Case;
   Create (Out_F, Out_File, Out_Path);
   Put_Line (Out_F, "I18NDATA|1|16.0.0");
   --  Records within a section must be in sorted key order for the loader's
   --  bisection: Cased < Lowercase < Uppercase < gc < script < scriptalias.
   Put_Line (Out_F, "@prop|6");
   Put_Line (Out_F, "Cased" & HT
             & Prop_Ranges ("DerivedCoreProperties.txt", "Cased"));
   Put_Line (Out_F, "Lowercase" & HT
             & Prop_Ranges ("DerivedCoreProperties.txt", "Lowercase"));
   Put_Line (Out_F, "Uppercase" & HT
             & Prop_Ranges ("DerivedCoreProperties.txt", "Uppercase"));
   Put_Line (Out_F, "gc" & HT & Ranges_Of ("DerivedGeneralCategory.txt"));
   Put_Line (Out_F, "script" & HT & Ranges_Of ("Scripts.txt"));
   Put_Line (Out_F, "scriptalias" & HT & Script_Aliases);
   Put_Line (Out_F, "@case|4");
   Put_Line (Out_F, "lower" & HT & To_String (Lower_S));
   Put_Line (Out_F, "special" & HT & To_String (Special_S));
   Put_Line (Out_F, "title" & HT & To_String (Title_S));
   Put_Line (Out_F, "upper" & HT & To_String (Upper_S));
   Close (Out_F);
   Put_Line ("uprops.i18ndata written");
end Generate_UCD_Uprops_Data;
