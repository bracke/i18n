with Ada.Containers.Hashed_Maps;
with Ada.Containers.Vectors;
with I18N.Data_Store;

package body I18N.Casing is

   type CP is range 0 .. 16#10FFFF#;

   function Hash_CP (K : CP) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (K));
   package CP_Maps is new Ada.Containers.Hashed_Maps (CP, CP, Hash_CP, "=");

   type Special_Rec is record
      Src   : CP;
      Lower, Upper, Title : String (1 .. 24);   --  '.'-joined hex sequences
      LL, UL, TL : Natural;
      Cond  : String (1 .. 48);
      CL    : Natural;
   end record;
   package Special_Vectors is new Ada.Containers.Vectors (Positive, Special_Rec);

   type CP_Seq is array (Positive range <>) of CP;

   Lower_Map, Upper_Map, Title_Map : CP_Maps.Map;
   Specials : Special_Vectors.Vector;

   type Range_Rec is record
      Lo, Hi : CP;
      GC     : String (1 .. 2);
   end record;
   type Range_Array is array (Positive range <>) of Range_Rec;
   type Range_Access is access Range_Array;
   GC_Tab : Range_Access;

   Loaded    : Boolean := False;
   Have_Data : Boolean := False;

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

   --  Decode a '.'-joined hex sequence into code points, into a fixed buffer.
   procedure Decode_Seq
     (S : String; Buf : out String; Codes : out CP_Seq; N : out Natural)
   is
      pragma Unreferenced (Buf);
      I : Natural := S'First;
   begin
      N := 0;
      while I <= S'Last loop
         declare
            J : Natural := I;
         begin
            while J <= S'Last and then S (J) /= '.' loop
               J := J + 1;
            end loop;
            N := N + 1;
            Codes (N) := CP (Hex_Val (S (I .. J - 1)));
            I := J + 1;
         end;
      end loop;
   end Decode_Seq;

   --  ------------------------------------------------------------------
   --  Loading
   --  ------------------------------------------------------------------

   procedure Load_Simple (Section, Key : String; M : in out CP_Maps.Map) is
      S : constant String := I18N.Data_Store.Lookup ("uprops", Section, Key);
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
               Tok : String renames S (I .. J - 1);
               Col : Natural := Tok'First;
            begin
               while Col <= Tok'Last and then Tok (Col) /= ':' loop
                  Col := Col + 1;
               end loop;
               if Col <= Tok'Last then
                  M.Include (CP (Hex_Val (Tok (Tok'First .. Col - 1))),
                             CP (Hex_Val (Tok (Col + 1 .. Tok'Last))));
               end if;
            end;
            I := J + 1;
         end;
      end loop;
   end Load_Simple;

   procedure Ensure_Loaded is
   begin
      if Loaded then
         return;
      end if;
      Loaded := True;
      if not I18N.Data_Store.Available ("uprops") then
         return;
      end if;
      Have_Data := True;
      Load_Simple ("case", "lower", Lower_Map);
      Load_Simple ("case", "upper", Upper_Map);
      Load_Simple ("case", "title", Title_Map);

      --  Specials: "cp:lseq:useq:tseq:cond ..."
      declare
         S : constant String := I18N.Data_Store.Lookup ("uprops", "case", "special");
         I : Natural := S'First;
         function Field (T : String; N : Natural) return String is
            Start : Natural := T'First; Idx : Natural := 0;
         begin
            for K in T'Range loop
               if T (K) = ':' then
                  if Idx = N then
                     return T (Start .. K - 1);
                  end if;
                  Idx := Idx + 1; Start := K + 1;
               end if;
            end loop;
            return (if Idx = N then
               T (Start .. T'Last) else "");
         end Field;
      begin
         while I <= S'Last loop
            declare
               J : Natural := I;
            begin
               while J <= S'Last and then S (J) /= ' ' loop
                  J := J + 1;
               end loop;
               declare
                  Tok  : String renames S (I .. J - 1);
                  R    : Special_Rec;
                  L    : constant String := Field (Tok, 1);
                  U    : constant String := Field (Tok, 2);
                  T    : constant String := Field (Tok, 3);
                  C    : constant String := Field (Tok, 4);
               begin
                  R.Src := CP (Hex_Val (Field (Tok, 0)));
                  R.Lower (1 .. L'Length) := L; R.LL := L'Length;
                  R.Upper (1 .. U'Length) := U; R.UL := U'Length;
                  R.Title (1 .. T'Length) := T; R.TL := T'Length;
                  R.Cond (1 .. C'Length) := C;  R.CL := C'Length;
                  Specials.Append (R);
               end;
               I := J + 1;
            end;
         end loop;
      end;

      --  GC ranges (for cased / case-ignorable tests).
      declare
         S : constant String := I18N.Data_Store.Lookup ("uprops", "prop", "gc");
         Count : Natural := 0;
         I : Natural := S'First;
      begin
         if S'Length > 0 then
            Count := 1;
            for C of S loop
               if C = ' ' then
                  Count := Count + 1;
               end if;
            end loop;
         end if;
         GC_Tab := new Range_Array (1 .. Count);
         declare
            K : Natural := 0;
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
                     GC_Tab (K).Lo := CP (Hex_Val (Tok (Tok'First .. C1 - 1)));
                     GC_Tab (K).Hi := CP (Hex_Val (Tok (C1 + 1 .. C2 - 1)));
                     GC_Tab (K).GC := (if C2 + 2 <= Tok'Last + 1
                                       then
                                          Tok (C2 + 1 .. C2 + 2) else "Cn");
                  end;
                  I := J + 1;
               end;
            end loop;
         end;
      end;
   end Ensure_Loaded;

   function GC_Of (C : CP) return String is
      Lo : Natural := GC_Tab'First;
      Hi : Natural := GC_Tab'Last;
   begin
      while Lo <= Hi loop
         declare
            Mid : constant Natural := (Lo + Hi) / 2;
         begin
            if C < GC_Tab (Mid).Lo then
               Hi := Mid - 1;
            elsif C > GC_Tab (Mid).Hi then
               Lo := Mid + 1;
            else
               return GC_Tab (Mid).GC;
            end if;
         end;
      end loop;
      return "Cn";
   end GC_Of;

   function Is_Cased (C : CP) return Boolean is
      G : constant String := GC_Of (C);
   begin
      return G = "Lu" or else G = "Ll" or else G = "Lt"
        or else Lower_Map.Contains (C) or else Upper_Map.Contains (C);
   end Is_Cased;

   function Is_Ignorable (C : CP) return Boolean is
      G : constant String := GC_Of (C);
   begin
      return G = "Mn" or else G = "Me" or else G = "Cf" or else G = "Lm"
        or else G = "Sk";
   end Is_Ignorable;

   --  ------------------------------------------------------------------
   --  UTF-8
   --  ------------------------------------------------------------------

   procedure Decode (Text : String; C : out CP_Seq; N : out Natural) is
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

   procedure Encode (C : CP; Into : in out String; Last : in out Natural) is
      procedure P (X : Natural) is
      begin
         Last := Last + 1; Into (Last) := Character'Val (X);
      end P;
   begin
      if C < 16#80# then
         P (Natural (C));
      elsif C < 16#800# then
         P (16#C0# + Natural (C / 16#40#)); P (16#80# + Natural (C mod 16#40#));
      elsif C < 16#10000# then
         P (16#E0# + Natural (C / 16#1000#));
         P (16#80# + Natural ((C / 16#40#) mod 16#40#));
         P (16#80# + Natural (C mod 16#40#));
      else
         P (16#F0# + Natural (C / 16#40000#));
         P (16#80# + Natural ((C / 16#1000#) mod 16#40#));
         P (16#80# + Natural ((C / 16#40#) mod 16#40#));
         P (16#80# + Natural (C mod 16#40#));
      end if;
   end Encode;

   --  ------------------------------------------------------------------
   --  Case operations
   --  ------------------------------------------------------------------

   type Kind is (K_Lower, K_Upper, K_Title);

   function Cond_Holds
     (Cond, Locale : String; C : CP_Seq; Pos, N : Natural) return Boolean
   is
   begin
      if Cond = "" then
         return True;
      elsif Cond = "Final_Sigma" then
         --  Preceded by a cased char, not followed by one (ignoring ignorables).
         declare
            Before : Boolean := False;
            After  : Boolean := False;
            K : Integer := Pos - 1;
         begin
            while K >= 1 and then Is_Ignorable (C (K)) loop
               K := K - 1;
            end loop;
            Before := K >= 1 and then
               Is_Cased (C (K));
            K := Pos + 1;
            while K <= N and then Is_Ignorable (C (K)) loop
               K := K + 1;
            end loop;
            After := K <= N and then
               Is_Cased (C (K));
            return Before and then not After;
         end;
      elsif Cond'Length >= 2
        and then (Cond (Cond'First .. Cond'First + 1) = "tr"
                  or else Cond (Cond'First .. Cond'First + 1) = "az")
      then
         return Locale'Length >= 2
           and then Locale (Locale'First .. Locale'First + 1)
                    = Cond (Cond'First .. Cond'First + 1);
      elsif Cond'Length >= 2 and then Cond (Cond'First .. Cond'First + 1) = "lt"
      then
         return Locale'Length >= 2
           and then Locale (Locale'First .. Locale'First + 1) = "lt";
      else
         return False;   --  unmodelled condition -> fall back to simple
      end if;
   end Cond_Holds;

   function Map_One
     (What : Kind; Locale : String; C : CP_Seq; Pos, N : Natural;
      Out_S : in out String; Last : in out Natural) return Boolean
   is
      Src : constant CP := C (Pos);
   begin
      --  Try special (conditional first, then unconditional).
      for Pass in 1 .. 2 loop
         for R of Specials loop
            if R.Src = Src then
               declare
                  Cond : constant String := R.Cond (1 .. R.CL);
                  Want_Cond : constant Boolean := (Pass = 1);
               begin
                  if (Cond /= "") = Want_Cond
                    and then Cond_Holds (Cond, Locale, C, Pos, N)
                  then
                     declare
                        Seq : constant String :=
                          (case What is
                              when K_Lower => R.Lower (1 .. R.LL),
                              when K_Upper => R.Upper (1 .. R.UL),
                              when K_Title => R.Title (1 .. R.TL));
                        Codes : CP_Seq (1 .. 12);
                        Dummy : String (1 .. 1);
                        Cnt   : Natural;
                     begin
                        if Seq /= "" then
                           Decode_Seq (Seq, Dummy, Codes, Cnt);
                           for K in 1 .. Cnt loop
                              Encode (Codes (K), Out_S, Last);
                           end loop;
                           return True;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      return False;
   end Map_One;

   function Apply (What : Kind; Text, Locale : String) return String is
      C     : CP_Seq (1 .. Text'Length);
      N     : Natural;
      Out_S : String (1 .. Text'Length * 4 + 8);
      Last  : Natural := 0;
      Word_Start : Boolean := True;
   begin
      Ensure_Loaded;
      if not Have_Data then
         return Text;
      end if;
      Decode (Text, C, N);
      for I in 1 .. N loop
         declare
            Eff : Kind := What;
         begin
            if What = K_Title then
               Eff := (if Word_Start then
                  K_Title else K_Lower);
               if Is_Cased (C (I)) then
                  Word_Start := False;
               elsif GC_Of (C (I)) = "Zs" or else C (I) = 16#20#
                 or else GC_Of (C (I)) (1) = 'P'
               then
                  Word_Start := True;
               end if;
            end if;
            if not Map_One (Eff, Locale, C, I, N, Out_S, Last) then
               declare
                  M : constant CP :=
                    (case Eff is
                        when K_Lower =>
                          (if Lower_Map.Contains (C (I)) then Lower_Map.Element (C (I))
                           else C (I)),
                        when K_Upper =>
                          (if Upper_Map.Contains (C (I)) then Upper_Map.Element (C (I))
                           else C (I)),
                        when K_Title =>
                          (if Title_Map.Contains (C (I)) then Title_Map.Element (C (I))
                           elsif Upper_Map.Contains (C (I)) then Upper_Map.Element (C (I))
                           else
                              C (I)));
               begin
                  Encode (M, Out_S, Last);
               end;
            end if;
         end;
      end loop;
      return Out_S (1 .. Last);
   end Apply;

   function To_Lower (Text : String; Locale : String := "") return String is
     (Apply (K_Lower, Text, Locale));
   function To_Upper (Text : String; Locale : String := "") return String is
     (Apply (K_Upper, Text, Locale));
   function To_Title (Text : String; Locale : String := "") return String is
     (Apply (K_Title, Text, Locale));

   function Available return Boolean is
   begin
      Ensure_Loaded;
      return Have_Data;
   end Available;

end I18N.Casing;
