--  Build share/i18n/collation.i18ndata from the UCA DUCET (allkeys.txt) plus the
--  Unified_Ideograph ranges (PropList.txt) that the implicit-weight formula needs.
--
--  Section "ce": one record per collation key (single code point or a 2-3 code
--  point contraction), key = 6-hex code points joined by '-', value = the
--  collation elements, each "[*]PPPP.SSSS.TTTT" (leading '*' = variable) joined
--  by ','. Records sorted by key for the loader bisection.
--
--  Section "meta": whole-table records the engine parses once --
--    cstart  space-separated first code points that begin a contraction
--    impl    "start:end:base" @implicitweights blocks (Tangut/Nushu/Khitan)
--    uideo   "start:end" Unified_Ideograph ranges
--    ver     the UCA version
with Ada.Text_IO;                     use Ada.Text_IO;
with Ada.Strings;                     use Ada.Strings;
with Ada.Strings.Fixed;               use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;           use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Ordered_Sets;

procedure Generate_UCA_Collation_Data is

   Allkeys  : constant String := "upstream/uca/allkeys.txt";
   Proplist : constant String := "upstream/uca/PropList.txt";
   Out_Path : constant String := "../share/i18n/collation.i18ndata";

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

   function H6 (V : Natural) return String is
      D : constant String := "0123456789ABCDEF";
      R : String (1 .. 6);
      N : Natural := V;
   begin
      for I in reverse R'Range loop
         R (I) := D (N mod 16 + 1);
         N := N / 16;
      end loop;
      return R;
   end H6;

   type Rec is record
      Key, Val : Unbounded_String;
   end record;
   package Rec_Vectors is new Ada.Containers.Vectors (Positive, Rec);
   function Less (A, B : Rec) return Boolean is (A.Key < B.Key);
   package Rec_Sorting is new Rec_Vectors.Generic_Sorting ("<" => Less);
   CE : Rec_Vectors.Vector;

   package Nat_Sets is new Ada.Containers.Ordered_Sets (Natural);
   Cstart : Nat_Sets.Set;

   Impl_Blocks : Unbounded_String;
   UIdeo       : Unbounded_String;
   Version     : Unbounded_String := To_Unbounded_String ("16.0.0");

   --  Parse the bracketed collation elements after ';' into "CE,CE,...".
   function Parse_Elements (S : String) return String is
      Result : Unbounded_String;
      I      : Natural := S'First;
      First  : Boolean := True;
   begin
      while I <= S'Last loop
         if S (I) = '[' then
            declare
               J : Natural := I + 1;
            begin
               while J <= S'Last and then S (J) /= ']' loop
                  J := J + 1;
               end loop;
               --  S (I+1 .. J-1) = "<X>PPPP.SSSS.TTTT", X = '.' or '*'.
               declare
                  Body_S : constant String := S (I + 1 .. J - 1);
                  Var    : constant Boolean := Body_S (Body_S'First) = '*';
                  Wts    : constant String := Body_S (Body_S'First + 1 .. Body_S'Last);
               begin
                  if not First then
                     Append (Result, ",");
                  end if;
                  First := False;
                  if Var then
                     Append (Result, "*");
                  end if;
                  Append (Result, Wts);
               end;
               I := J + 1;
            end;
         else
            I := I + 1;
         end if;
      end loop;
      return To_String (Result);
   end Parse_Elements;

begin
   --  ---- allkeys.txt ----
   declare
      F : File_Type;
   begin
      Open (F, In_File, Allkeys);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1 else Index (Line, "#"));
            Bdy  : constant String := Trim (Line (Line'First .. Hash - 1), Both);
         begin
            if Bdy'Length = 0 then
               null;
            elsif Bdy (Bdy'First) = '@' then
               if Index (Bdy, "@version") = Bdy'First then
                  Version := To_Unbounded_String (Trim (Bdy (Bdy'First + 8 .. Bdy'Last), Both));
               elsif Index (Bdy, "@implicitweights") = Bdy'First then
                  --  "@implicitweights START..END; BASE"
                  declare
                     Rest : constant String := Trim (Bdy (Bdy'First + 16 .. Bdy'Last), Both);
                     Dots : constant Natural := Index (Rest, "..");
                     Semi : constant Natural := Index (Rest, ";");
                     Lo   : constant Natural := Hex (Rest (Rest'First .. Dots - 1));
                     Hi   : constant Natural := Hex (Rest (Dots + 2 .. Semi - 1));
                     Base : constant Natural := Hex (Trim (Rest (Semi + 1 .. Rest'Last), Both));
                  begin
                     if Length (Impl_Blocks) > 0 then
                        Append (Impl_Blocks, " ");
                     end if;
                     Append (Impl_Blocks, H6 (Lo) & ":" & H6 (Hi) & ":" & H6 (Base));
                  end;
               end if;
            else
               declare
                  Semi : constant Natural := Index (Bdy, ";");
                  CPs  : constant String := Trim (Bdy (Bdy'First .. Semi - 1), Both);
                  Els  : constant String := Bdy (Semi + 1 .. Bdy'Last);
                  Key  : Unbounded_String;
                  Cnt  : Natural := 0;
                  First_CP : Natural := 0;
                  I : Natural := CPs'First;
               begin
                  while I <= CPs'Last loop
                     declare
                        J : Natural := I;
                     begin
                        while J <= CPs'Last and then CPs (J) /= ' ' loop
                           J := J + 1;
                        end loop;
                        declare
                           V : constant Natural := Hex (CPs (I .. J - 1));
                        begin
                           if Cnt > 0 then
                              Append (Key, "-");
                           else
                              First_CP := V;
                           end if;
                           Append (Key, H6 (V));
                           Cnt := Cnt + 1;
                        end;
                        I := J + 1;
                     end;
                  end loop;
                  if Cnt >= 2 then
                     Cstart.Include (First_CP);
                  end if;
                  CE.Append
                    (Rec'(Key => Key,
                          Val => To_Unbounded_String (Parse_Elements (Els))));
               end;
            end if;
         end;
      end loop;
      Close (F);
   end;

   --  ---- PropList.txt: Unified_Ideograph ranges ----
   declare
      F : File_Type;
   begin
      Open (F, In_File, Proplist);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1 else Index (Line, "#"));
            Bdy  : constant String := Line (Line'First .. Hash - 1);
            Semi : constant Natural := Index (Bdy, ";");
         begin
            if Semi /= 0
              and then Index (Bdy (Semi + 1 .. Bdy'Last), "Unified_Ideograph") /= 0
            then
               declare
                  CPs  : constant String := Trim (Bdy (Bdy'First .. Semi - 1), Both);
                  Dots : constant Natural := Index (CPs, "..");
                  Lo   : constant Natural :=
                    (if Dots = 0 then Hex (CPs) else Hex (CPs (CPs'First .. Dots - 1)));
                  Hi   : constant Natural :=
                    (if Dots = 0 then Lo else Hex (CPs (Dots + 2 .. CPs'Last)));
               begin
                  if Length (UIdeo) > 0 then
                     Append (UIdeo, " ");
                  end if;
                  Append (UIdeo, H6 (Lo) & ":" & H6 (Hi));
               end;
            end if;
         end;
      end loop;
      Close (F);
   end;

   --  ---- emit ----
   Rec_Sorting.Sort (CE);
   declare
      Out_F   : File_Type;
      Cstart_S : Unbounded_String;
      First    : Boolean := True;
   begin
      for CP of Cstart loop
         if not First then
            Append (Cstart_S, " ");
         end if;
         First := False;
         Append (Cstart_S, H6 (CP));
      end loop;

      Create (Out_F, Out_File, Out_Path);
      Put_Line (Out_F, "I18NDATA|1|" & To_String (Version));
      Put_Line (Out_F, "@ce|" & Trim (Integer'Image (Integer (CE.Length)), Both));
      for R of CE loop
         Put_Line (Out_F, To_String (R.Key) & Character'Val (16#09#) & To_String (R.Val));
      end loop;
      --  Sorted meta keys: cstart < impl < uideo < ver.
      Put_Line (Out_F, "@meta|4");
      Put_Line (Out_F, "cstart" & Character'Val (16#09#) & To_String (Cstart_S));
      Put_Line (Out_F, "impl" & Character'Val (16#09#) & To_String (Impl_Blocks));
      Put_Line (Out_F, "uideo" & Character'Val (16#09#) & To_String (UIdeo));
      Put_Line (Out_F, "ver" & Character'Val (16#09#) & To_String (Version));
      Close (Out_F);
   end;

   Put_Line ("collation.i18ndata:" & Integer'Image (Integer (CE.Length))
             & " CE records," & Integer'Image (Integer (Cstart.Length))
             & " contraction starters");
end Generate_UCA_Collation_Data;
