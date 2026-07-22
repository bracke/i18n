with Ada.Containers.Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with I18N.Data_Store;

package body I18N.Normalization is

   type CP is range 0 .. 16#10FFFF#;
   type CP_Array is array (Positive range <>) of CP;

   function Hash_CP (K : CP) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (K));
   function Hash_LLI (K : Long_Long_Integer) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (K mod 2 ** 31));

   package CCC_Maps is new Ada.Containers.Hashed_Maps
     (CP, Natural, Hash_CP, "=");
   package Decomp_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (CP, CP_Array, Hash_CP, "=");
   package Compose_Maps is new Ada.Containers.Hashed_Maps
     (Long_Long_Integer, CP, Hash_LLI, "=");
   package CP_Vectors is new Ada.Containers.Vectors (Positive, CP);

   CCC_Table     : CCC_Maps.Map;
   Canon_Table   : Decomp_Maps.Map;
   Compat_Table  : Decomp_Maps.Map;
   Compose_Table : Compose_Maps.Map;
   Loaded        : Boolean := False;
   Have_Data     : Boolean := False;

   Base : constant Long_Long_Integer := 16#200000#;

   --  ------------------------------------------------------------------
   --  Hangul (algorithmic; not in the tables)
   --  ------------------------------------------------------------------

   S_Base : constant CP := 16#AC00#;
   L_Base : constant CP := 16#1100#;
   V_Base : constant CP := 16#1161#;
   T_Base : constant CP := 16#11A7#;
   L_Count : constant := 19;
   V_Count : constant := 21;
   T_Count : constant := 28;
   N_Count : constant := V_Count * T_Count;      --  588
   S_Count : constant := L_Count * N_Count;      --  11172

   function Is_Hangul_Syllable (C : CP) return Boolean is
     (C >= S_Base and then C < S_Base + S_Count);

   --  ------------------------------------------------------------------
   --  Table loading
   --  ------------------------------------------------------------------

   function Hex_Val (S : String) return Long_Long_Integer is
      V : Long_Long_Integer := 0;
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

   --  Parse "cp v cp v ..." into CCC_Table.
   procedure Parse_CCC (S : String) is
      I : Natural := S'First;
      function Token return String is
         J : Natural := I;
      begin
         while J <= S'Last and then S (J) /= ' ' loop
            J := J + 1;
         end loop;
         declare
            R : constant String := S (I .. J - 1);
         begin
            I := J + 1;
            return R;
         end;
      end Token;
   begin
      while I <= S'Last loop
         declare
            K : constant String := Token;
            V : constant String := Token;
         begin
            if K /= "" and then V /= "" then
               CCC_Table.Include (CP (Hex_Val (K)), Natural (Hex_Val (V)));
            end if;
         end;
      end loop;
   end Parse_CCC;

   --  Parse "cp:c1,c2,... cp:c1,c2,... " into a decomposition map.
   procedure Parse_Decomp (S : String; Into : in out Decomp_Maps.Map) is
      I : Natural := S'First;
   begin
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= ' ' loop
               J := J + 1;
            end loop;
            --  Token S (I .. J-1) is "cp:c1,c2,...".
            declare
               Tok   : String renames S (I .. J - 1);
               Colon : Natural := Tok'First;
               Count : Positive := 1;
            begin
               while Colon <= Tok'Last and then Tok (Colon) /= ':' loop
                  Colon := Colon + 1;
               end loop;
               if Colon <= Tok'Last then
                  for K in Colon + 1 .. Tok'Last loop
                     if Tok (K) = ',' then
                        Count := Count + 1;
                     end if;
                  end loop;
                  declare
                     Seq   : CP_Array (1 .. Count);
                     Idx   : Positive := 1;
                     Start : Natural := Colon + 1;
                  begin
                     for K in Colon + 1 .. Tok'Last + 1 loop
                        if K > Tok'Last or else Tok (K) = ',' then
                           Seq (Idx) := CP (Hex_Val (Tok (Start .. K - 1)));
                           Idx := Idx + 1;
                           Start := K + 1;
                        end if;
                     end loop;
                     Into.Include (CP (Hex_Val (Tok (Tok'First .. Colon - 1))),
                                   Seq);
                  end;
               end if;
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_Decomp;

   --  Parse "a,b:c a,b:c ..." into Compose_Table.
   procedure Parse_Compose (S : String) is
      I : Natural := S'First;
   begin
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= ' ' loop
               J := J + 1;
            end loop;
            declare
               Tok   : String renames S (I .. J - 1);
               Comma : Natural := Tok'First;
               Colon : Natural := Tok'First;
            begin
               while Comma <= Tok'Last and then Tok (Comma) /= ',' loop
                  Comma := Comma + 1;
               end loop;
               Colon := Comma;
               while Colon <= Tok'Last and then Tok (Colon) /= ':' loop
                  Colon := Colon + 1;
               end loop;
               if Comma <= Tok'Last and then Colon <= Tok'Last then
                  declare
                     A : constant Long_Long_Integer :=
                       Hex_Val (Tok (Tok'First .. Comma - 1));
                     B : constant Long_Long_Integer :=
                       Hex_Val (Tok (Comma + 1 .. Colon - 1));
                     C : constant CP :=
                       CP (Hex_Val (Tok (Colon + 1 .. Tok'Last)));
                  begin
                     Compose_Table.Include (A * Base + B, C);
                  end;
               end if;
            end;
            I := J + 1;
         end;
      end loop;
   end Parse_Compose;

   procedure Ensure_Loaded is
   begin
      if Loaded then
         return;
      end if;
      Loaded := True;
      if not I18N.Data_Store.Available ("normalization") then
         return;
      end if;
      Have_Data := True;
      Parse_CCC (I18N.Data_Store.Lookup ("normalization", "table", "ccc"));
      Parse_Decomp
        (I18N.Data_Store.Lookup ("normalization", "table", "canon"),
         Canon_Table);
      Parse_Decomp
        (I18N.Data_Store.Lookup ("normalization", "table", "compat"),
         Compat_Table);
      Parse_Compose
        (I18N.Data_Store.Lookup ("normalization", "table", "compose"));
   end Ensure_Loaded;

   function CCC_Of (C : CP) return Natural is
      use CCC_Maps;
      Cur : constant Cursor := CCC_Table.Find (C);
   begin
      return (if Cur = No_Element then 0 else Element (Cur));
   end CCC_Of;

   --  ------------------------------------------------------------------
   --  UTF-8 codec
   --  ------------------------------------------------------------------

   procedure Decode (Text : String; Into : out CP_Vectors.Vector) is
      I : Natural := Text'First;
   begin
      Into.Clear;
      while I <= Text'Last loop
         declare
            B : constant Natural := Character'Pos (Text (I));
            V : CP;
            N : Natural;
         begin
            if B < 16#80# then
               V := CP (B); N := 0;
            elsif B < 16#E0# then
               V := CP (B - 16#C0#); N := 1;
            elsif B < 16#F0# then
               V := CP (B - 16#E0#); N := 2;
            else
               V := CP (B - 16#F0#); N := 3;
            end if;
            for K in 1 .. N loop
               exit when I + K > Text'Last;
               V := V * 64 + CP (Character'Pos (Text (I + K)) - 16#80#);
            end loop;
            Into.Append (V);
            I := I + N + 1;
         end;
      end loop;
   end Decode;

   procedure Encode (C : CP; Into : in out String; Last : in out Natural) is
      procedure Put (X : Natural) is
      begin
         Last := Last + 1;
         Into (Last) := Character'Val (X);
      end Put;
   begin
      if C < 16#80# then
         Put (Natural (C));
      elsif C < 16#800# then
         Put (16#C0# + Natural (C / 16#40#));
         Put (16#80# + Natural (C mod 16#40#));
      elsif C < 16#10000# then
         Put (16#E0# + Natural (C / 16#1000#));
         Put (16#80# + Natural ((C / 16#40#) mod 16#40#));
         Put (16#80# + Natural (C mod 16#40#));
      else
         Put (16#F0# + Natural (C / 16#40000#));
         Put (16#80# + Natural ((C / 16#1000#) mod 16#40#));
         Put (16#80# + Natural ((C / 16#40#) mod 16#40#));
         Put (16#80# + Natural (C mod 16#40#));
      end if;
   end Encode;

   --  ------------------------------------------------------------------
   --  Normalization steps
   --  ------------------------------------------------------------------

   procedure Append_Decomp
     (C : CP; Compatibility : Boolean; Into : in out CP_Vectors.Vector)
   is
      use Decomp_Maps;
   begin
      if Is_Hangul_Syllable (C) then
         declare
            SIndex : constant Natural := Natural (C - S_Base);
            L : constant CP := L_Base + CP (SIndex / N_Count);
            V : constant CP := V_Base + CP ((SIndex mod N_Count) / T_Count);
            T : constant CP := T_Base + CP (SIndex mod T_Count);
         begin
            Into.Append (L);
            Into.Append (V);
            if T /= T_Base then
               Into.Append (T);
            end if;
            return;
         end;
      end if;
      if Compatibility then
         declare
            Cur : constant Cursor := Compat_Table.Find (C);
         begin
            if Cur /= No_Element then
               for X of Element (Cur) loop
                  Into.Append (X);
               end loop;
               return;
            end if;
         end;
      end if;
      declare
         Cur : constant Cursor := Canon_Table.Find (C);
      begin
         if not Compatibility and then Cur /= No_Element then
            for X of Element (Cur) loop
               Into.Append (X);
            end loop;
            return;
         end if;
      end;
      Into.Append (C);
   end Append_Decomp;

   --  Stable canonical ordering: sort each run of non-starters by CCC.
   procedure Canonical_Order (V : in out CP_Vectors.Vector) is
      I : Positive := 1;
   begin
      while I <= Natural (V.Length) loop
         if CCC_Of (V (I)) = 0 then
            I := I + 1;
         else
            declare
               J : Positive := I;
            begin
               while J <= Natural (V.Length) and then CCC_Of (V (J)) /= 0 loop
                  J := J + 1;
               end loop;
               --  Insertion sort V (I .. J-1) by CCC (stable).
               for P in I + 1 .. J - 1 loop
                  declare
                     Val  : constant CP := V (P);
                     VC   : constant Natural := CCC_Of (Val);
                     Q    : Integer := P - 1;
                  begin
                     while Q >= I and then CCC_Of (V (Q)) > VC loop
                        V.Replace_Element (Q + 1, V (Q));
                        Q := Q - 1;
                     end loop;
                     V.Replace_Element (Q + 1, Val);
                  end;
               end loop;
               I := J;
            end;
         end if;
      end loop;
   end Canonical_Order;

   function Pair_Compose (A, B : CP) return CP is
      use Compose_Maps;
      --  Hangul.
      LI : constant Long_Long_Integer := Long_Long_Integer (A);
      VI : constant Long_Long_Integer := Long_Long_Integer (B);
      Cur : Cursor;
   begin
      if A >= L_Base and then A < L_Base + L_Count
        and then B >= V_Base and then B < V_Base + V_Count
      then
         return S_Base
           + CP ((Natural (A - L_Base) * N_Count)
                 + (Natural (B - V_Base) * T_Count));
      end if;
      if Is_Hangul_Syllable (A)
        and then Natural (A - S_Base) mod T_Count = 0
        and then B > T_Base and then B < T_Base + T_Count
      then
         return A + (B - T_Base);
      end if;
      Cur := Compose_Table.Find (LI * Base + VI);
      return (if Cur = No_Element then CP'Last else Element (Cur));
   end Pair_Compose;

   procedure Compose (V : in out CP_Vectors.Vector) is
      Result       : CP_Vectors.Vector;
      Last_Starter : Integer := -1;   --  index in Result of the last starter
      Prev_CCC     : Natural := 0;
   begin
      for I in 1 .. Natural (V.Length) loop
         declare
            C  : constant CP := V (I);
            CC : constant Natural := CCC_Of (C);
            Composed : CP := CP'Last;
         begin
            if Last_Starter >= 0 and then (Prev_CCC = 0 or else Prev_CCC < CC)
            then
               Composed := Pair_Compose (Result (Last_Starter), C);
            end if;

            if Composed /= CP'Last then
               Result.Replace_Element (Last_Starter, Composed);
               --  C consumed; Prev_CCC unchanged.
            else
               Result.Append (C);
               if CC = 0 then
                  Last_Starter := Natural (Result.Length);
                  Prev_CCC := 0;
               else
                  Prev_CCC := CC;
               end if;
            end if;
         end;
      end loop;
      V := Result;
   end Compose;

   --  ------------------------------------------------------------------
   --  Public
   --  ------------------------------------------------------------------

   function Normalize (Text : String; To : Form) return String is
      Src  : CP_Vectors.Vector;
      Dec  : CP_Vectors.Vector;
      Compatibility : constant Boolean := To in NFKC | NFKD;
      Composing     : constant Boolean := To in NFC | NFKC;
   begin
      Ensure_Loaded;
      if not Have_Data then
         return Text;
      end if;

      Decode (Text, Src);
      for C of Src loop
         Append_Decomp (C, Compatibility, Dec);
      end loop;
      Canonical_Order (Dec);
      if Composing then
         Compose (Dec);
      end if;

      declare
         Out_S : String (1 .. 4 * Natural (Dec.Length) + 4);
         Last  : Natural := 0;
      begin
         for C of Dec loop
            Encode (C, Out_S, Last);
         end loop;
         return Out_S (1 .. Last);
      end;
   end Normalize;

   function Is_Normalized (Text : String; To : Form) return Boolean is
     (Normalize (Text, To) = Text);

   function Available return Boolean is
   begin
      Ensure_Loaded;
      return Have_Data;
   end Available;

end I18N.Normalization;
