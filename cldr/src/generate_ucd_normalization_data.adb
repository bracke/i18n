--  Builds share/i18n/normalization.i18ndata from the Unicode Character Database
--  (UnicodeData.txt, DerivedNormalizationProps.txt). Global (per-code-point,
--  not per-locale). One section "table" with four whole-table values the
--  I18N.Normalization engine parses once:
--     ccc      "<hexcp> <ccc> ..."            (non-zero combining classes)
--     canon    "<hexcp>:<hc>,<hc>,... ..."    (full canonical decompositions)
--     compat   "<hexcp>:<hc>,<hc>,... ..."    (full compatibility decompositions)
--     compose  "<ha>,<hb>:<hc> ..."           (canonical (a,b)->composite)

with Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Containers.Ordered_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Strings;
with Ada.Strings.Fixed;  use Ada.Strings.Fixed;

procedure Generate_UCD_Normalization_Data is

   CLDR_Version : constant String := "17.0.0";

   UCD : constant String := "upstream/ucd";

   package Nat_Maps is new Ada.Containers.Ordered_Maps (Natural, Natural);
   package Str_Maps is new Ada.Containers.Ordered_Maps
     (Natural, Unbounded_String);
   package Nat_Sets is new Ada.Containers.Ordered_Sets (Natural);

   CCC       : Nat_Maps.Map;    --  cp -> combining class (non-zero only)
   Canon_Raw : Str_Maps.Map;    --  cp -> direct canonical decomp ("a,b")
   Compat_Raw : Str_Maps.Map;   --  cp -> direct compatibility decomp
   Excl      : Nat_Sets.Set;    --  Full_Composition_Exclusion

   function Hex_Val (S : String) return Natural is
      V : Natural := 0;
   begin
      for C of S loop
         case C is
            when '0' .. '9' =>
               V := V * 16 + (Character'Pos (C) - Character'Pos ('0'));
            when 'A' .. 'F' =>
               V := V * 16 + (10 + Character'Pos (C) - Character'Pos ('A'));
            when 'a' .. 'f' =>
               V := V * 16 + (10 + Character'Pos (C) - Character'Pos ('a'));
            when others => null;
         end case;
      end loop;
      return V;
   end Hex_Val;

   function Hex (V : Natural) return String is
      Digits_S : constant String := "0123456789ABCDEF";
      Buf : String (1 .. 8);
      N   : Natural := 8;
      X   : Natural := V;
   begin
      if V = 0 then
         return "0";
      end if;
      while X > 0 loop
         Buf (N) := Digits_S (X mod 16 + 1);
         X := X / 16;
         N := N - 1;
      end loop;
      return Buf (N + 1 .. 8);
   end Hex;

   function Field (Line : String; N : Positive) return String is
      Start : Natural := Line'First;
      Count : Positive := 1;
   begin
      for I in Line'Range loop
         if Line (I) = ';' then
            if Count = N then
               return Line (Start .. I - 1);
            end if;
            Count := Count + 1;
            Start := I + 1;
         end if;
      end loop;
      if Count = N then
         return Line (Start .. Line'Last);
      end if;
      return "";
   end Field;

   --  ------------------------------------------------------------------
   --  Parse UnicodeData.txt
   --  ------------------------------------------------------------------

   procedure Read_Unicode_Data is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, UCD & "/UnicodeData.txt");
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (F);
         begin
            if Line'Length > 0 then
               declare
                  CP     : constant Natural := Hex_Val (Field (Line, 1));
                  Ccc_S  : constant String := Field (Line, 4);
                  Decomp : constant String := Field (Line, 6);
               begin
                  if Ccc_S /= "" then
                     declare
                        C : Natural := 0;
                     begin
                        for Ch of Ccc_S loop
                           exit when Ch not in '0' .. '9';
                           C := C * 10 + (Character'Pos (Ch)
                                          - Character'Pos ('0'));
                        end loop;
                        if C /= 0 then
                           CCC.Include (CP, C);
                        end if;
                     end;
                  end if;

                  if Decomp /= "" then
                     declare
                        Compat : constant Boolean :=
                          Decomp (Decomp'First) = '<';
                        --  Skip the "<tag> " prefix for compatibility decomps.
                        First : Natural := Decomp'First;
                        Seq   : Unbounded_String;
                     begin
                        if Compat then
                           while First <= Decomp'Last
                             and then Decomp (First) /= '>'
                           loop
                              First := First + 1;
                           end loop;
                           First := First + 2;   --  past "> "
                        end if;
                        --  Convert the space-separated hex list to "a,b,...".
                        declare
                           I : Natural := First;
                        begin
                           while I <= Decomp'Last loop
                              declare
                                 J : Natural := I;
                              begin
                                 while J <= Decomp'Last
                                   and then Decomp (J) /= ' '
                                 loop
                                    J := J + 1;
                                 end loop;
                                 if J > I then
                                    if Length (Seq) > 0 then
                                       Append (Seq, ",");
                                    end if;
                                    Append (Seq,
                                            Hex (Hex_Val (Decomp (I .. J - 1))));
                                 end if;
                                 I := J + 1;
                              end;
                           end loop;
                        end;
                        if Compat then
                           Compat_Raw.Include (CP, Seq);
                        else
                           Canon_Raw.Include (CP, Seq);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   end Read_Unicode_Data;

   procedure Read_Exclusions is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open
        (F, Ada.Text_IO.In_File, UCD & "/DerivedNormalizationProps.txt");
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (F);
            Hash : Natural := 0;
            Semi : Natural := 0;
         begin
            for I in Line'Range loop
               if Line (I) = '#' and then Hash = 0 then
                  Hash := I;
               elsif Line (I) = ';' and then Semi = 0 then
                  Semi := I;
               end if;
            end loop;
            declare
               Body_End : constant Natural :=
                 (if Hash = 0 then Line'Last else Hash - 1);
            begin
               if Semi /= 0 and then Semi < Body_End then
                  declare
                     Prop : constant String := Trim
                       (Line (Semi + 1 .. Body_End), Ada.Strings.Both);
                     Codes : constant String := Trim
                       (Line (Line'First .. Semi - 1), Ada.Strings.Both);
                  begin
                     if Prop = "Full_Composition_Exclusion"
                       and then Codes'Length > 0
                     then
                        --  "X" or "X..Y".
                        declare
                           Dot : Natural := 0;
                        begin
                           for I in Codes'Range loop
                              if Codes (I) = '.' then
                                 Dot := I;
                                 exit;
                              end if;
                           end loop;
                           if Dot = 0 then
                              Excl.Include (Hex_Val (Codes));
                           else
                              for V in Hex_Val (Codes (Codes'First .. Dot - 1))
                                .. Hex_Val (Codes (Dot + 2 .. Codes'Last))
                              loop
                                 Excl.Include (V);
                              end loop;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   end Read_Exclusions;

   --  ------------------------------------------------------------------
   --  Recursive full decomposition
   --  ------------------------------------------------------------------

   --  Split "a,b,c" into code points, appending each (fully expanded) to Out.
   procedure Expand
     (CP : Natural; Compatibility : Boolean; Out_S : in out Unbounded_String);

   procedure Expand_Seq
     (Seq : String; Compatibility : Boolean; Out_S : in out Unbounded_String)
   is
      I : Natural := Seq'First;
   begin
      while I <= Seq'Last loop
         declare
            J : Natural := I;
         begin
            while J <= Seq'Last and then Seq (J) /= ',' loop
               J := J + 1;
            end loop;
            Expand (Hex_Val (Seq (I .. J - 1)), Compatibility, Out_S);
            I := J + 1;
         end;
      end loop;
   end Expand_Seq;

   procedure Expand
     (CP : Natural; Compatibility : Boolean; Out_S : in out Unbounded_String)
   is
      use Str_Maps;
      Cur : constant Cursor := Canon_Raw.Find (CP);
   begin
      if Compatibility and then Compat_Raw.Contains (CP) then
         Expand_Seq (To_String (Compat_Raw.Element (CP)), True, Out_S);
      elsif Cur /= No_Element then
         Expand_Seq (To_String (Element (Cur)), Compatibility, Out_S);
      else
         if Length (Out_S) > 0 then
            Append (Out_S, ",");
         end if;
         Append (Out_S, Hex (CP));
      end if;
   end Expand;

   --  ------------------------------------------------------------------
   --  Emit
   --  ------------------------------------------------------------------

   Output : Ada.Text_IO.File_Type;

   procedure Emit_CCC is
      First : Boolean := True;
   begin
      Ada.Text_IO.Put (Output, "ccc" & Character'Val (16#09#));
      for C in CCC.Iterate loop
         if not First then
            Ada.Text_IO.Put (Output, " ");
         end if;
         First := False;
         Ada.Text_IO.Put
           (Output, Hex (Nat_Maps.Key (C)) & " " & Hex (Nat_Maps.Element (C)));
      end loop;
      Ada.Text_IO.New_Line (Output);
   end Emit_CCC;

   Emit_First : Boolean;

   procedure Put_Decomp (CP : Natural; Compatibility : Boolean) is
      Full : Unbounded_String;
   begin
      Expand (CP, Compatibility, Full);
      if not Emit_First then
         Ada.Text_IO.Put (Output, " ");
      end if;
      Emit_First := False;
      Ada.Text_IO.Put (Output, Hex (CP) & ":" & To_String (Full));
   end Put_Decomp;

   procedure Emit_Canon is
   begin
      Ada.Text_IO.Put (Output, "canon" & Character'Val (16#09#));
      Emit_First := True;
      for C in Canon_Raw.Iterate loop
         Put_Decomp (Str_Maps.Key (C), False);
      end loop;
      Ada.Text_IO.New_Line (Output);
   end Emit_Canon;

   --  Compatibility decomposition covers every decomposable code point
   --  (compat >= canonical), so iterate both source maps.
   procedure Emit_Compat is
   begin
      Ada.Text_IO.Put (Output, "compat" & Character'Val (16#09#));
      Emit_First := True;
      for C in Canon_Raw.Iterate loop
         Put_Decomp (Str_Maps.Key (C), True);
      end loop;
      for C in Compat_Raw.Iterate loop
         Put_Decomp (Str_Maps.Key (C), True);
      end loop;
      Ada.Text_IO.New_Line (Output);
   end Emit_Compat;

   procedure Emit_Compose is
      First : Boolean := True;
   begin
      Ada.Text_IO.Put (Output, "compose" & Character'Val (16#09#));
      for C in Canon_Raw.Iterate loop
         declare
            CP  : constant Natural := Str_Maps.Key (C);
            Seq : constant String := To_String (Str_Maps.Element (C));
            Comma : Natural := 0;
         begin
            for I in Seq'Range loop
               if Seq (I) = ',' then
                  Comma := I;
                  exit;
               end if;
            end loop;
            --  Two-code-point canonical decomposition, not excluded.
            if Comma /= 0 and then not Excl.Contains (CP)
              and then (for all Ch of Seq (Comma + 1 .. Seq'Last) => Ch /= ',')
            then
               if not First then
                  Ada.Text_IO.Put (Output, " ");
               end if;
               First := False;
               Ada.Text_IO.Put
                 (Output,
                  Seq (Seq'First .. Comma - 1) & "," & Seq (Comma + 1 .. Seq'Last)
                  & ":" & Hex (CP));
            end if;
         end;
      end loop;
      Ada.Text_IO.New_Line (Output);
   end Emit_Compose;

begin
   if not Ada.Directories.Exists (UCD & "/UnicodeData.txt") then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "no vendored UCD (upstream/ucd)");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   Read_Unicode_Data;
   Read_Exclusions;

   declare
      Out_Path : constant String :=
        (if Ada.Command_Line.Argument_Count >= 1
         then Ada.Command_Line.Argument (1)
         else "../share/i18n/normalization.i18ndata");
   begin
      Ada.Directories.Create_Path
        (Ada.Directories.Containing_Directory (Out_Path));
      Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Out_Path);
      Ada.Text_IO.Put_Line (Output, "I18NDATA|1|" & CLDR_Version);
      Ada.Text_IO.Put_Line (Output, "@table|4");
      --  Records must be emitted in sorted key order for the loader bisection.
      Emit_Canon;
      Emit_CCC;
      Emit_Compat;
      Emit_Compose;
      Ada.Text_IO.Close (Output);
   end;

   Ada.Text_IO.Put_Line ("generated normalization.i18ndata");
end Generate_UCD_Normalization_Data;
