with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Strings.Hash;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with I18N.Data_Store;
with I18N.Normalization;

package body I18N.Collation is

   type CP is range 0 .. 16#10FFFF#;
   type CP_Array is array (Positive range <>) of CP;

   --  A collation element: three base weights, the variable flag, and optional
   --  fractional byte suffixes (empty for root elements; set for tailored ones,
   --  where they order a character just after its anchor within a weight).
   type Element is record
      P, S, T    : Natural;
      Var        : Boolean;
      E1, E2, E3 : Unbounded_String := Null_Unbounded_String;
   end record;
   package Element_Vectors is new Ada.Containers.Vectors (Positive, Element);

   type Range_Rec is record
      Lo, Hi, Base : CP;
   end record;
   type Range_Array is array (Positive range <>) of Range_Rec;
   type Range_Access is access Range_Array;
   type CP_List is array (Positive range <>) of CP;
   type CP_List_Access is access CP_List;

   Impl_Ranges  : Range_Access;
   UIdeo_Ranges : Range_Access;
   Cstart       : CP_List_Access;
   Loaded       : Boolean := False;
   Have_Data    : Boolean := False;

   --  ------------------------------------------------------------------
   --  Small helpers
   --  ------------------------------------------------------------------

   function Hex_Val (S : String) return Natural is
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
   end Hex_Val;

   function H6 (V : CP) return String is
      D : constant String := "0123456789ABCDEF";
      R : String (1 .. 6);
      N : Natural := Natural (V);
   begin
      for I in reverse R'Range loop
         R (I) := D (N mod 16 + 1);
         N := N / 16;
      end loop;
      return R;
   end H6;

   function Token_Count (S : String) return Natural is
      N : Natural := 0;
   begin
      if S'Length > 0 then
         N := 1;
         for C of S loop
            if C = ' ' then
               N := N + 1;
            end if;
         end loop;
      end if;
      return N;
   end Token_Count;

   --  Parse "lo:hi[:base] lo:hi[:base] ..." into a Range_Array.
   function Parse_Ranges (S : String) return Range_Access is
      Result : constant Range_Access := new Range_Array (1 .. Token_Count (S));
      I      : Natural := S'First;
      K      : Natural := 0;
   begin
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= ' ' loop
               J := J + 1;
            end loop;
            declare
               Tok : String renames S (I .. J - 1);
               C1  : Natural := Tok'First;
               C2  : Natural;
            begin
               while C1 <= Tok'Last and then Tok (C1) /= ':' loop
                  C1 := C1 + 1;
               end loop;
               C2 := C1 + 1;
               while C2 <= Tok'Last and then Tok (C2) /= ':' loop
                  C2 := C2 + 1;
               end loop;
               K := K + 1;
               Result (K) :=
                 (Lo   => CP (Hex_Val (Tok (Tok'First .. C1 - 1))),
                  Hi   => CP (Hex_Val (Tok (C1 + 1 .. C2 - 1))),
                  Base =>
                    (if C2 <= Tok'Last then CP (Hex_Val (Tok (C2 + 1 .. Tok'Last)))
                     else 0));
            end;
            I := J + 1;
         end;
      end loop;
      return Result;
   end Parse_Ranges;

   --  ------------------------------------------------------------------
   --  Loading
   --  ------------------------------------------------------------------

   procedure Ensure_Loaded is
   begin
      if Loaded then
         return;
      end if;
      Loaded := True;
      if not I18N.Data_Store.Available ("collation") then
         return;
      end if;
      Have_Data := True;

      declare
         S : constant String :=
           I18N.Data_Store.Lookup ("collation", "meta", "cstart");
         I : Natural := S'First;
         K : Natural := 0;
      begin
         Cstart := new CP_List (1 .. Token_Count (S));
         while I <= S'Last loop
            declare
               J : Natural := I;
            begin
               while J <= S'Last and then S (J) /= ' ' loop
                  J := J + 1;
               end loop;
               K := K + 1;
               Cstart (K) := CP (Hex_Val (S (I .. J - 1)));
               I := J + 1;
            end;
         end loop;
      end;

      Impl_Ranges  := Parse_Ranges
        (I18N.Data_Store.Lookup ("collation", "meta", "impl"));
      UIdeo_Ranges := Parse_Ranges
        (I18N.Data_Store.Lookup ("collation", "meta", "uideo"));
   end Ensure_Loaded;

   function Is_Cstart (C : CP) return Boolean is
      Lo : Natural := Cstart'First;
      Hi : Natural := Cstart'Last;
   begin
      while Lo <= Hi loop
         declare
            Mid : constant Natural := (Lo + Hi) / 2;
         begin
            if C < Cstart (Mid) then
               Hi := Mid - 1;
            elsif C > Cstart (Mid) then
               Lo := Mid + 1;
            else
               return True;
            end if;
         end;
      end loop;
      return False;
   end Is_Cstart;

   function In_Ranges (T : Range_Access; C : CP) return Boolean is
   begin
      for R of T.all loop
         if C >= R.Lo and then C <= R.Hi then
            return True;
         end if;
      end loop;
      return False;
   end In_Ranges;

   --  ------------------------------------------------------------------
   --  Tailoring (per-locale overrides on the root)
   --  ------------------------------------------------------------------

   package Tail_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (String, String, Ada.Strings.Hash, "=");
   Tail_Map    : Tail_Maps.Map;
   Tail_Locale : Unbounded_String;
   Tail_Active : Boolean := False;
   Tail_Max    : Natural := 1;      --  longest key, in code points

   function Bytes_Of_Hex (H : String) return String is
      R : String (1 .. H'Length / 2);
      K : Natural := 0;
      I : Natural := H'First;
   begin
      while I + 1 <= H'Last loop
         K := K + 1;
         R (K) := Character'Val (Hex_Val (H (I .. I + 1)));
         I := I + 2;
      end loop;
      return R (1 .. K);
   end Bytes_Of_Hex;

   --  Parse a tailored value "prim.pfrac.sec.sfrac.ter.tfrac[,next]" into
   --  elements with fractional suffixes.
   procedure Parse_Tailored
     (Value : String; Into : in out Element_Vectors.Vector)
   is
      I : Natural := Value'First;
   begin
      while I <= Value'Last loop
         declare
            J : Natural := I;
         begin
            while J <= Value'Last and then Value (J) /= ',' loop
               J := J + 1;
            end loop;
            declare
               Tok : String renames Value (I .. J - 1);
               F   : array (1 .. 6) of Unbounded_String;
               N   : Natural := 1;
               P   : Natural := Tok'First;
            begin
               for K in Tok'Range loop
                  if Tok (K) = '.' then
                     N := N + 1;
                     P := K + 1;
                  else
                     Append (F (N), Tok (K));
                  end if;
               end loop;
               pragma Unreferenced (P);
               Into.Append
                 (Element'(P   => Hex_Val (To_String (F (1))),
                           S   => Hex_Val (To_String (F (3))),
                           T   => Hex_Val (To_String (F (5))),
                           Var => False,
                           E1  => To_Unbounded_String
                             (Bytes_Of_Hex (To_String (F (2)))),
                           E2  => To_Unbounded_String
                             (Bytes_Of_Hex (To_String (F (4)))),
                           E3  => To_Unbounded_String
                             (Bytes_Of_Hex (To_String (F (6))))));
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_Tailored;

   procedure Load_Tailoring (Locale : String) is
   begin
      if Locale = "" then
         Tail_Active := False;
         return;
      end if;
      if Tail_Active and then Tail_Locale = Locale then
         return;
      end if;
      Tail_Map.Clear;
      Tail_Active := False;
      Tail_Max := 1;
      Tail_Locale := To_Unbounded_String (Locale);
      if not I18N.Data_Store.Available ("collation/" & Locale) then
         return;
      end if;
      declare
         Val : constant String :=
           I18N.Data_Store.Lookup ("collation/" & Locale, "meta", "tab");
         I   : Natural := Val'First;
      begin
         while I <= Val'Last loop
            declare
               J : Natural := I;
            begin
               while J <= Val'Last and then Val (J) /= ';' loop
                  J := J + 1;
               end loop;
               declare
                  Entry_S : String renames Val (I .. J - 1);
                  Eq      : Natural := Entry_S'First;
                  Cps     : Natural := 1;
               begin
                  while Eq <= Entry_S'Last and then Entry_S (Eq) /= '=' loop
                     if Entry_S (Eq) = '-' then
                        Cps := Cps + 1;
                     end if;
                     Eq := Eq + 1;
                  end loop;
                  if Eq <= Entry_S'Last then
                     Tail_Map.Include
                       (Entry_S (Entry_S'First .. Eq - 1),
                        Entry_S (Eq + 1 .. Entry_S'Last));
                     if Cps > Tail_Max then
                        Tail_Max := Cps;
                     end if;
                  end if;
               end;
               I := J + 1;
            end;
         end loop;
      end;
      Tail_Active := not Tail_Map.Is_Empty;
   end Load_Tailoring;

   --  ------------------------------------------------------------------
   --  Collation elements
   --  ------------------------------------------------------------------

   --  Append the parsed collation elements of Value to Into.
   procedure Parse_CEs (Value : String; Into : in out Element_Vectors.Vector) is
      I : Natural := Value'First;
   begin
      while I <= Value'Last loop
         declare
            J : Natural := I;
         begin
            while J <= Value'Last and then Value (J) /= ',' loop
               J := J + 1;
            end loop;
            --  Token Value (I .. J-1) = "[*]P.S.T".
            declare
               Tok : String renames Value (I .. J - 1);
               K   : Natural := Tok'First;
               Var : constant Boolean := Tok (Tok'First) = '*';
               D1, D2 : Natural;
            begin
               if Var then
                  K := K + 1;
               end if;
               D1 := K;
               while D1 <= Tok'Last and then Tok (D1) /= '.' loop
                  D1 := D1 + 1;
               end loop;
               D2 := D1 + 1;
               while D2 <= Tok'Last and then Tok (D2) /= '.' loop
                  D2 := D2 + 1;
               end loop;
               Into.Append
                 (Element'(P   => Hex_Val (Tok (K .. D1 - 1)),
                           S   => Hex_Val (Tok (D1 + 1 .. D2 - 1)),
                           T   => Hex_Val (Tok (D2 + 1 .. Tok'Last)),
                           Var => Var, others => <>));
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_CEs;

   --  Implicit weights (UCA 10.1.3): two elements for a code point absent from
   --  the table.
   procedure Implicit (C : CP; Into : in out Element_Vectors.Vector) is
      AAAA, BBBB : Natural;
   begin
      if In_Ranges (Impl_Ranges, C) then
         for R of Impl_Ranges.all loop
            if C >= R.Lo and then C <= R.Hi then
               --  Blocks sharing a base offset from their common first block,
               --  so a supplement continues its main block's weight range.
               declare
                  Origin : CP := R.Lo;
               begin
                  for Q of Impl_Ranges.all loop
                     if Q.Base = R.Base and then Q.Lo < Origin then
                        Origin := Q.Lo;
                     end if;
                  end loop;
                  AAAA := Natural (R.Base);
                  BBBB := Natural (C - Origin) + 16#8000#;
               end;
               exit;
            end if;
         end loop;
      elsif In_Ranges (UIdeo_Ranges, C) then
         if (C >= 16#4E00# and then C <= 16#9FFF#)
           or else (C >= 16#F900# and then C <= 16#FAFF#)
         then
            AAAA := 16#FB40# + Natural (C / 16#8000#);
         else
            AAAA := 16#FB80# + Natural (C / 16#8000#);
         end if;
         BBBB := (Natural (C) mod 16#8000#) + 16#8000#;
      else
         AAAA := 16#FBC0# + Natural (C / 16#8000#);
         BBBB := (Natural (C) mod 16#8000#) + 16#8000#;
      end if;
      Into.Append
        (Element'(P => AAAA, S => 16#0020#, T => 16#0002#, Var => False,
                 others => <>));
      Into.Append
        (Element'(P => BBBB, S => 0, T => 0, Var => False, others => <>));
   end Implicit;

   function CCC (C : CP) return Natural is
     (I18N.Normalization.Combining_Class (Natural (C)));

   function Lookup_CE (Key : String) return String is
     (I18N.Data_Store.Lookup ("collation", "ce", Key));

   --  Build the full collation-element list for an NFD code-point array,
   --  implementing UCA S2.1 including discontiguous contractions.
   procedure Collation_Elements
     (C : CP_Array; Into : in out Element_Vectors.Vector)
   is
      Consumed : array (C'Range) of Boolean := (others => False);
      I        : Natural := C'First;

      --  Try the longest locale-tailoring override starting at I; on a match,
      --  emit it, consume the positions, advance I, and return True.
      function Apply_Tailoring return Boolean is
      begin
         for Len in reverse 1 .. Natural'Min (Tail_Max, C'Last - I + 1) loop
            declare
               Blocked : Boolean := False;
            begin
               for M in 0 .. Len - 1 loop
                  Blocked := Blocked or else Consumed (I + M);
               end loop;
               if not Blocked then
                  declare
                     Key : String (1 .. 7 * Len);
                     Pos : Natural := 0;
                  begin
                     for M in 0 .. Len - 1 loop
                        if M > 0 then
                           Pos := Pos + 1; Key (Pos) := '-';
                        end if;
                        Key (Pos + 1 .. Pos + 6) := H6 (C (I + M));
                        Pos := Pos + 6;
                     end loop;
                     if Tail_Map.Contains (Key (1 .. Pos)) then
                        Parse_Tailored (Tail_Map.Element (Key (1 .. Pos)), Into);
                        for K in I .. I + Len - 1 loop
                           Consumed (K) := True;
                        end loop;
                        I := I + Len;
                        return True;
                     end if;
                  end;
               end if;
            end;
         end loop;
         return False;
      end Apply_Tailoring;
   begin
      while I <= C'Last loop
         if Consumed (I) then
            I := I + 1;
         elsif Tail_Active and then Apply_Tailoring then
            null;   --  Apply_Tailoring advanced I and consumed the match
         else
            declare
               S_Key : String (1 .. 64);
               S_Len : Natural := 6;
               S_End : Natural := I;                 --  last contiguous position
               S_Val : Unbounded_String;
            begin
               S_Key (1 .. 6) := H6 (C (I));
               S_Val := To_Unbounded_String (Lookup_CE (S_Key (1 .. 6)));

               --  Longest contiguous contraction (max 3 code points).
               if Is_Cstart (C (I)) then
                  for Len in 2 .. Natural'Min (3, C'Last - I + 1) loop
                     exit when Consumed (I + Len - 1);
                     declare
                        K   : String (1 .. 7 * Len);
                        Pos : Natural := 0;
                     begin
                        for M in 0 .. Len - 1 loop
                           if M > 0 then
                              Pos := Pos + 1; K (Pos) := '-';
                           end if;
                           K (Pos + 1 .. Pos + 6) := H6 (C (I + M));
                           Pos := Pos + 6;
                        end loop;
                        declare
                           V : constant String := Lookup_CE (K (1 .. Pos));
                        begin
                           if V /= "" then
                              S_Key (1 .. Pos) := K (1 .. Pos);
                              S_Len := Pos;
                              S_End := I + Len - 1;
                              S_Val := To_Unbounded_String (V);
                           end if;
                        end;
                     end;
                  end loop;
               end if;

               if S_Val = "" then
                  Implicit (C (I), Into);
                  Consumed (I) := True;
                  I := I + 1;
               else
                  --  Discontiguous extension: append following non-starters
                  --  that are not blocked and whose combined key matches.
                  declare
                     Last_CCC : Natural := 0;
                     P        : Natural := S_End + 1;
                  begin
                     while P <= C'Last and then CCC (C (P)) > 0 loop
                        if not Consumed (P) and then CCC (C (P)) > Last_CCC then
                           declare
                              Cand : constant String :=
                                S_Key (1 .. S_Len) & "-" & H6 (C (P));
                              V : constant String := Lookup_CE (Cand);
                           begin
                              if V /= "" then
                                 S_Key (1 .. Cand'Length) := Cand;
                                 S_Len := Cand'Length;
                                 S_Val := To_Unbounded_String (V);
                                 Consumed (P) := True;
                                 Last_CCC := 0;
                              else
                                 Last_CCC := CCC (C (P));
                              end if;
                           end;
                        elsif not Consumed (P) then
                           Last_CCC := Natural'Max (Last_CCC, CCC (C (P)));
                        end if;
                        P := P + 1;
                     end loop;
                  end;
                  Parse_CEs (To_String (S_Val), Into);
                  for K in I .. S_End loop
                     Consumed (K) := True;
                  end loop;
                  I := S_End + 1;
               end if;
            end;
         end if;
      end loop;
   end Collation_Elements;

   --  ------------------------------------------------------------------
   --  UTF-8 decode
   --  ------------------------------------------------------------------

   procedure Decode (Text : String; C : out CP_Array; N : out Natural) is
      I : Natural := Text'First;
   begin
      N := 0;
      while I <= Text'Last loop
         declare
            B  : constant Natural := Character'Pos (Text (I));
            V  : CP;
            Nb : Natural;
         begin
            if B < 16#80# then
               V := CP (B); Nb := 0;
            elsif B < 16#E0# then
               V := CP (B - 16#C0#); Nb := 1;
            elsif B < 16#F0# then
               V := CP (B - 16#E0#); Nb := 2;
            else
               V := CP (B - 16#F0#); Nb := 3;
            end if;
            for K in 1 .. Nb loop
               exit when I + K > Text'Last;
               V := V * 64 + CP (Character'Pos (Text (I + K)) - 16#80#);
            end loop;
            N := N + 1;
            C (N) := V;
            I := I + Nb + 1;
         end;
      end loop;
   end Decode;

   --  ------------------------------------------------------------------
   --  Sort key
   --  ------------------------------------------------------------------

   Max_Q : constant := 16#FFFF#;

   function Sort_Key
     (Text     : String;
      Locale   : String := "";
      Level    : Strength := Tertiary;
      Variable : Variable_Handling := Shifted) return String
   is
      NFD : constant String := I18N.Normalization.Normalize
        (Text, I18N.Normalization.NFD);
      C   : CP_Array (1 .. NFD'Length);
      N   : Natural;
      Els : Element_Vectors.Vector;
      Last : Natural := 0;

      --  Weighted levels after variable handling (with fractional suffixes).
      type W4 is record
         L1, L2, L3, L4 : Natural;
         E1, E2, E3     : Unbounded_String;
      end record;
      package W4_Vectors is new Ada.Containers.Vectors (Positive, W4);
      W : W4_Vectors.Vector;

      Levels : constant Natural :=
        (case Level is
            when Primary => 1, when Secondary => 2, when Tertiary => 3,
            when Quaternary | Identical => 4);
   begin
      Ensure_Loaded;
      if not Have_Data then
         return Text;
      end if;
      Load_Tailoring (Locale);

      Decode (NFD, C, N);
      Collation_Elements (C (1 .. N), Els);

      --  Variable weighting (carrying any fractional suffixes through).
      declare
         Last_Var : Boolean := False;
      begin
         for E of Els loop
            if Variable = Shifted then
               if E.Var then
                  W.Append (W4'(0, 0, 0, E.P, E.E1, E.E2, E.E3));
                  Last_Var := True;
               elsif E.P = 0 and then E.S = 0 and then E.T = 0 then
                  W.Append (W4'(0, 0, 0, 0, E.E1, E.E2, E.E3));
               elsif E.P = 0 then
                  if Last_Var then
                     W.Append (W4'(0, 0, 0, 0, E.E1, E.E2, E.E3));
                  else
                     W.Append (W4'(0, E.S, E.T, Max_Q, E.E1, E.E2, E.E3));
                  end if;
               else
                  W.Append (W4'(E.P, E.S, E.T, Max_Q, E.E1, E.E2, E.E3));
                  Last_Var := False;
               end if;
            else
               W.Append (W4'(E.P, E.S, E.T, Max_Q, E.E1, E.E2, E.E3));
            end if;
         end loop;
      end;

      --  Build the key: concatenate each level's non-zero weights, separated by
      --  a 0000 weight. Grow the result buffer as needed.
      declare
         Buf : String (1 .. 16 * Natural (W.Length) + 4 * N + 32);
         procedure Put (Wt : Natural) is
         begin
            Last := Last + 1; Buf (Last) := Character'Val (Wt / 256);
            Last := Last + 1; Buf (Last) := Character'Val (Wt mod 256);
         end Put;
      begin
         for Lvl in 1 .. Levels loop
            if Lvl > 1 then
               Put (0);
            end if;
            for X of W loop
               declare
                  Wt : constant Natural :=
                    (case Lvl is
                        when 1 => X.L1, when 2 => X.L2,
                        when 3 => X.L3, when others => X.L4);
               begin
                  if Wt /= 0 then
                     Put (Wt);
                     --  Append the fractional suffix for this level, if any.
                     declare
                        Ef : constant String :=
                          (case Lvl is
                              when 1 => To_String (X.E1),
                              when 2 => To_String (X.E2),
                              when 3 => To_String (X.E3),
                              when others => "");
                     begin
                        for B of Ef loop
                           Last := Last + 1; Buf (Last) := B;
                        end loop;
                     end;
                  end if;
               end;
            end loop;
         end loop;
         --  Identical level: append the NFD code points.
         if Level = Identical then
            Put (0);
            for K in 1 .. N loop
               Put (Natural (C (K)) / 16#10000#);
               Put (Natural (C (K)) mod 16#10000#);
            end loop;
         end if;
         return Buf (1 .. Last);
      end;
   end Sort_Key;

   function Compare
     (A, B     : String;
      Locale   : String := "";
      Level    : Strength := Tertiary;
      Variable : Variable_Handling := Shifted) return Integer
   is
      Ka : constant String := Sort_Key (A, Locale, Level, Variable);
      Kb : constant String := Sort_Key (B, Locale, Level, Variable);
   begin
      if Ka < Kb then
         return -1;
      elsif Ka > Kb then
         return 1;
      else
         return 0;
      end if;
   end Compare;

   function Available return Boolean is
   begin
      Ensure_Loaded;
      return Have_Data;
   end Available;

end I18N.Collation;
