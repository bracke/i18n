--  Build per-locale collation tailoring shards share/i18n/collation/<loc>.i18ndata
--  from the CLDR standard collation rules (common/collation/<loc>.xml).
--
--  The rules are the ICU tailoring syntax (&reset < << <<< = , [before N], /
--  expansion). Each tailored character is assigned weights just after its anchor
--  at the relation's level, using a fractional byte appended to the anchor's
--  weight so it interleaves correctly with the (DUCET) root. A shard is one
--  "meta" record "tab": entries "cpseq=elem,elem;cpseq=..." where each element is
--  "prim.pfrac.sec.sfrac.ter.tfrac" (4-hex base weights; frac = hex bytes).
with Ada.Text_IO;                 use Ada.Text_IO;
with Ada.Strings;                 use Ada.Strings;
with Ada.Strings.Fixed;           use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;       use Ada.Strings.Unbounded;
with Ada.Directories;             use Ada.Directories;
with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

procedure Generate_CLDR_Collation_Tailoring is

   Allkeys : constant String := "upstream/uca/allkeys.txt";
   Col_Dir : constant String := "upstream/collation";
   Out_Dir : constant String := "../share/i18n/collation";

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

   Digits_S : constant String := "0123456789ABCDEF";
   function H (V, N : Natural) return String is
      R : String (1 .. N);
      M : Natural := V;
   begin
      for I in reverse R'Range loop
         R (I) := Digits_S (M mod 16 + 1);
         M := M / 16;
      end loop;
      return R;
   end H;
   function H4 (V : Natural) return String is (H (V, 4));
   function H6 (V : Natural) return String is (H (V, 6));
   function H2 (V : Natural) return String is (H (V, 2));

   type WTS is record
      P, S, T : Natural;
   end record;
   package Root_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, WTS, Ada.Strings.Hash, "=");
   Root : Root_Maps.Map;

   --  Canonical decompositions and combining classes (UnicodeData.txt), used to
   --  NFD-normalize tailored target keys so they match the engine's NFD input.
   use type Ada.Containers.Hash_Type;
   function NHash (N : Natural) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (N));
   package Decomp_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Natural, String, NHash, "=");
   package CCC_Maps is new Ada.Containers.Hashed_Maps
     (Natural, Natural, NHash, "=");
   Decomp : Decomp_Maps.Map;   --  cp -> space-separated hex of canonical decomp
   CCC    : CCC_Maps.Map;      --  cp -> combining class

   --  ---- Load allkeys first-element weights, keyed by cpseq (dash 6-hex) ----
   procedure Load_Root is
      F : File_Type;
   begin
      Open (F, In_File, Allkeys);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1 else Index (Line, "#"));
            Bdy  : constant String := Trim (Line (Line'First .. Hash - 1), Both);
            Semi : constant Natural := Index (Bdy, ";");
         begin
            if Semi /= 0 and then Bdy (Bdy'First) /= '@' then
               declare
                  CPs : constant String := Trim (Bdy (Bdy'First .. Semi - 1), Both);
                  Key : Unbounded_String;
                  Cnt : Natural := 0;
                  I   : Natural := CPs'First;
                  --  First collation element after ';'.
                  Br  : constant Natural := Index (Bdy, "[");
               begin
                  while I <= CPs'Last loop
                     declare
                        J : Natural := I;
                     begin
                        while J <= CPs'Last and then CPs (J) /= ' ' loop
                           J := J + 1;
                        end loop;
                        if Cnt > 0 then
                           Append (Key, "-");
                        end if;
                        Append (Key, H6 (Hex (CPs (I .. J - 1))));
                        Cnt := Cnt + 1;
                        I := J + 1;
                     end;
                  end loop;
                  if Br /= 0 then
                     declare
                        Cl   : constant Natural := Index (Bdy (Br .. Bdy'Last), "]");
                        Elem : constant String := Bdy (Br + 2 .. Cl - 1);
                        D1   : constant Natural := Index (Elem, ".");
                        D2   : constant Natural :=
                          Index (Elem (D1 + 1 .. Elem'Last), ".");
                     begin
                        Root.Include
                          (To_String (Key),
                           (P => Hex (Elem (Elem'First .. D1 - 1)),
                            S => Hex (Elem (D1 + 1 .. D2 - 1)),
                            T => Hex (Elem (D2 + 1 .. Elem'Last))));
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Load_Root;

   --  Return field N (0-based) of a ';'-delimited line.
   function Field (Line : String; N : Natural) return String is
      Start : Natural := Line'First;
      Idx   : Natural := 0;
   begin
      for I in Line'Range loop
         if Line (I) = ';' then
            if Idx = N then
               return Line (Start .. I - 1);
            end if;
            Idx := Idx + 1;
            Start := I + 1;
         end if;
      end loop;
      return (if Idx = N then Line (Start .. Line'Last) else "");
   end Field;

   --  ---- Canonical decompositions + combining classes (UnicodeData.txt) ----
   procedure Load_Decomp is
      F : File_Type;
   begin
      Open (F, In_File, "upstream/ucd/UnicodeData.txt");
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
         begin
            if Index (Line, ";") /= 0 then
               declare
                  CPv : constant Natural := Hex (Field (Line, 0));
                  Dec : constant String := Field (Line, 5);   --  decomposition
               begin
                  CCC.Include (CPv, Hex (Field (Line, 3)));    --  combining class
                  if Dec /= "" and then Dec (Dec'First) /= '<' then
                     Decomp.Include (CPv, Dec);                --  canonical only
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Load_Decomp;

   type CP_Rec is record
      CPv, Cls : Natural;
   end record;
   type CP_Buf is array (1 .. 32) of CP_Rec;

   procedure Expand (CPv : Natural; Buf : in out CP_Buf; N : in out Natural) is
   begin
      if Decomp.Contains (CPv) then
         declare
            S : constant String := Decomp.Element (CPv);
            I : Natural := S'First;
         begin
            while I <= S'Last loop
               declare
                  J : Natural := I;
               begin
                  while J <= S'Last and then S (J) /= ' ' loop
                     J := J + 1;
                  end loop;
                  Expand (Hex (S (I .. J - 1)), Buf, N);
                  I := J + 1;
               end;
            end loop;
         end;
      else
         N := N + 1;
         Buf (N) := (CPv, (if CCC.Contains (CPv) then CCC.Element (CPv) else 0));
      end if;
   end Expand;

   --  NFD-normalize a '-'-joined hex code point key.
   function NFD_Key (Key : String) return String is
      Buf : CP_Buf;
      N   : Natural := 0;
      I   : Natural := Key'First;
      Res : Unbounded_String;
   begin
      while I <= Key'Last loop
         declare
            J : Natural := I;
         begin
            while J <= Key'Last and then Key (J) /= '-' loop
               J := J + 1;
            end loop;
            Expand (Hex (Key (I .. J - 1)), Buf, N);
            I := J + 1;
         end;
      end loop;
      --  Canonical ordering: stable insertion sort of non-starter runs by ccc.
      for P in 2 .. N loop
         if Buf (P).Cls /= 0 then
            declare
               V : constant CP_Rec := Buf (P);
               Q : Integer := P - 1;
            begin
               while Q >= 1 and then Buf (Q).Cls > V.Cls and then Buf (Q).Cls /= 0
               loop
                  Buf (Q + 1) := Buf (Q);
                  Q := Q - 1;
               end loop;
               Buf (Q + 1) := V;
            end;
         end if;
      end loop;
      for K in 1 .. N loop
         if K > 1 then
            Append (Res, "-");
         end if;
         Append (Res, H6 (Buf (K).CPv));
      end loop;
      return To_String (Res);
   end NFD_Key;

   --  ---- UTF-8 decode one code point ----
   procedure Decode_CP (S : String; I : in out Natural; CPv : out Natural) is
      B  : constant Natural := Character'Pos (S (I));
      Nb : Natural;
   begin
      if B < 16#80# then
         CPv := B; Nb := 0;
      elsif B < 16#E0# then
         CPv := B - 16#C0#; Nb := 1;
      elsif B < 16#F0# then
         CPv := B - 16#E0#; Nb := 2;
      else
         CPv := B - 16#F0#; Nb := 3;
      end if;
      for K in 1 .. Nb loop
         exit when I + K > S'Last;
         CPv := CPv * 64 + (Character'Pos (S (I + K)) - 16#80#);
      end loop;
      I := I + Nb + 1;
   end Decode_CP;

   --  Read a run of code points forming one collation token (until a delimiter).
   procedure Read_Seq (S : String; I : in out Natural; Key : out Unbounded_String) is
      Cnt : Natural := 0;
   begin
      Key := Null_Unbounded_String;
      while I <= S'Last loop
         declare
            C : constant Character := S (I);
         begin
            exit when C = ' ' or else C = ASCII.HT or else C = ASCII.LF
              or else C = ASCII.CR or else C = '<' or else C = '='
              or else C = '&' or else C = '/' or else C = '[' or else C = '#';
            declare
               CPv : Natural;
            begin
               Decode_CP (S, I, CPv);
               if Cnt > 0 then
                  Append (Key, "-");
               end if;
               Append (Key, H6 (CPv));
               Cnt := Cnt + 1;
            end;
         end;
      end loop;
   end Read_Seq;

   --  ---- process one locale's rules into a shard ----
   function Build_Shard (Rules : String) return String is
      Out_S : Unbounded_String;

      Cur_P, Cur_S, Cur_T : Natural := 0;
      Cur_E1, Cur_E2, Cur_E3 : Unbounded_String;
      P_Ctr, S_Ctr, T_Ctr : Natural := 1;
      Active : Boolean := False;   --  a valid reset anchor is in effect
      I : Natural := Rules'First;

      procedure Emit (Key : String; Expansion : String) is
         E : Unbounded_String;
      begin
         Append (E, H4 (Cur_P) & "." & To_String (Cur_E1) & "."
                 & H4 (Cur_S) & "." & To_String (Cur_E2) & "."
                 & H4 (Cur_T) & "." & To_String (Cur_E3));
         if Expansion /= "" and then Root.Contains (Expansion) then
            declare
               W : constant WTS := Root.Element (Expansion);
            begin
               Append (E, "," & H4 (W.P) & ".." & H4 (W.S) & ".." & H4 (W.T) & ".");
            end;
         end if;
         if Length (Out_S) > 0 then
            Append (Out_S, ";");
         end if;
         Append (Out_S, Key & "=" & To_String (E));
      end Emit;
   begin
      while I <= Rules'Last loop
         declare
            C : constant Character := Rules (I);
         begin
            if C = ' ' or else C = ASCII.HT or else C = ASCII.LF
              or else C = ASCII.CR
            then
               I := I + 1;
            elsif C = '#' then
               while I <= Rules'Last and then Rules (I) /= ASCII.LF loop
                  I := I + 1;
               end loop;
            elsif C = '&' then
               I := I + 1;
               --  Optional [before N].
               declare
                  Before : Natural := 0;
               begin
                  while I <= Rules'Last and then
                    (Rules (I) = ' ' or else Rules (I) = ASCII.HT)
                  loop
                     I := I + 1;
                  end loop;
                  if I + 7 <= Rules'Last
                    and then Rules (I .. I + 6) = "[before"
                  then
                     Before := Character'Pos (Rules (I + 8)) - 48;
                     while I <= Rules'Last and then Rules (I) /= ']' loop
                        I := I + 1;
                     end loop;
                     I := I + 1;
                     while I <= Rules'Last and then Rules (I) = ' ' loop
                        I := I + 1;
                     end loop;
                  end if;
                  --  Anchor sequence.
                  declare
                     Anchor : Unbounded_String;
                  begin
                     Read_Seq (Rules, I, Anchor);
                     if Root.Contains (To_String (Anchor)) then
                        declare
                           W : constant WTS := Root.Element (To_String (Anchor));
                        begin
                           Cur_P := W.P; Cur_S := W.S; Cur_T := W.T;
                           Cur_E1 := Null_Unbounded_String;
                           Cur_E2 := Null_Unbounded_String;
                           Cur_E3 := Null_Unbounded_String;
                           P_Ctr := 1; S_Ctr := 1; T_Ctr := 1;
                           if Before = 1 and then Cur_P > 0 then
                              Cur_P := Cur_P - 1;
                           elsif Before = 2 and then Cur_S > 0 then
                              Cur_S := Cur_S - 1;
                           elsif Before = 3 and then Cur_T > 0 then
                              Cur_T := Cur_T - 1;
                           end if;
                           Active := True;
                        end;
                     else
                        Active := False;
                     end if;
                  end;
               end;
            elsif C = '<' then
               declare
                  Lvl : Natural := 0;
               begin
                  while I <= Rules'Last and then Rules (I) = '<' loop
                     Lvl := Lvl + 1; I := I + 1;
                  end loop;
                  while I <= Rules'Last and then Rules (I) = ' ' loop
                     I := I + 1;
                  end loop;
                  declare
                     Target, Expan : Unbounded_String;
                  begin
                     Read_Seq (Rules, I, Target);
                     if I <= Rules'Last and then Rules (I) = '/' then
                        I := I + 1;
                        Read_Seq (Rules, I, Expan);
                     end if;
                     if Active and then Length (Target) > 0 then
                        if Lvl = 1 then
                           Cur_E1 := To_Unbounded_String (H2 (P_Ctr));
                           P_Ctr := P_Ctr + 1;
                           Cur_S := 16#0020#; Cur_E2 := Null_Unbounded_String;
                           S_Ctr := 1;
                           Cur_T := 16#0002#; Cur_E3 := Null_Unbounded_String;
                           T_Ctr := 1;
                        elsif Lvl = 2 then
                           Cur_E2 := To_Unbounded_String (H2 (S_Ctr));
                           S_Ctr := S_Ctr + 1;
                           Cur_T := 16#0002#; Cur_E3 := Null_Unbounded_String;
                           T_Ctr := 1;
                        else
                           Cur_E3 := To_Unbounded_String (H2 (T_Ctr));
                           T_Ctr := T_Ctr + 1;
                        end if;
                        Emit (NFD_Key (To_String (Target)), To_String (Expan));
                     end if;
                  end;
               end;
            elsif C = '=' then
               I := I + 1;
               while I <= Rules'Last and then Rules (I) = ' ' loop
                  I := I + 1;
               end loop;
               declare
                  Target, Expan : Unbounded_String;
               begin
                  Read_Seq (Rules, I, Target);
                  if I <= Rules'Last and then Rules (I) = '/' then
                     I := I + 1;
                     Read_Seq (Rules, I, Expan);
                  end if;
                  if Active and then Length (Target) > 0 then
                     Emit (NFD_Key (To_String (Target)), To_String (Expan));
                  end if;
               end;
            elsif C = '[' then
               --  Directive we do not model (import/reorder/strength/...): skip.
               while I <= Rules'Last and then Rules (I) /= ']' loop
                  I := I + 1;
               end loop;
               I := I + 1;
            else
               I := I + 1;
            end if;
         end;
      end loop;
      return To_String (Out_S);
   end Build_Shard;

   --  ---- extract the standard collation <cr> rules from a locale XML ----
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

   function Standard_Rules (Xml : String) return String is
      Std : constant Natural := Index (Xml, "<collation type=""standard""");
      Result : Unbounded_String;
      P : Natural;
   begin
      if Std = 0 then
         return "";
      end if;
      P := Std;
      loop
         declare
            Cr : constant Natural := Index (Xml (P .. Xml'Last), "<cr>");
            End_Col : constant Natural :=
              Index (Xml (P .. Xml'Last), "</collation>");
         begin
            exit when Cr = 0 or else (End_Col /= 0 and then Cr > End_Col);
            declare
               C1 : constant Natural := Index (Xml (Cr .. Xml'Last), "[CDATA[");
               C2 : constant Natural := Index (Xml (Cr .. Xml'Last), "]]>");
            begin
               exit when C1 = 0 or else C2 = 0;
               Append (Result, Xml (C1 + 7 .. C2 - 1));
               Append (Result, ASCII.LF);
               P := C2 + 3;
            end;
         end;
      end loop;
      return To_String (Result);
   end Standard_Rules;

   Search : Search_Type;
   Item   : Directory_Entry_Type;
   Count  : Natural := 0;
begin
   Load_Root;
   Load_Decomp;
   Create_Path (Out_Dir);
   Start_Search (Search, Col_Dir, "*.xml");
   while More_Entries (Search) loop
      Get_Next_Entry (Search, Item);
      declare
         Name  : constant String := Simple_Name (Item);
         Loc   : constant String := Name (Name'First .. Name'Last - 4);
         Xml   : constant String := Read_File (Full_Name (Item));
         Rules : constant String := Standard_Rules (Xml);
      begin
         if Rules /= "" then
            declare
               Shard : constant String := Build_Shard (Rules);
            begin
               if Shard /= "" then
                  declare
                     Out_F : File_Type;
                  begin
                     Create (Out_F, Out_File, Out_Dir & "/" & Loc & ".i18ndata");
                     Put_Line (Out_F, "I18NDATA|1|16.0.0");
                     Put_Line (Out_F, "@meta|1");
                     Put_Line (Out_F, "tab" & ASCII.HT & Shard);
                     Close (Out_F);
                     Count := Count + 1;
                  end;
               end if;
            end;
         end if;
      end;
   end loop;
   End_Search (Search);
   Put_Line ("collation tailoring shards written:" & Count'Image);
end Generate_CLDR_Collation_Tailoring;
