with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with I18N.Data_Store;
with I18N.Normalization;
with I18N.Casing;

package body I18N.Transliteration is

   type CP is range -1 .. 16#10FFFF#;    --  -1 marks "cursor"/sentinel
   subtype Code is CP range 0 .. 16#10FFFF#;

   type Range_T is record
      Lo, Hi : Code;
   end record;
   package Range_Vec is new Ada.Containers.Vectors (Positive, Range_T);
   package Set_Vec is new Ada.Containers.Vectors (Positive, Range_Vec.Vector,
                                                  Range_Vec."=");

   --  Elements of a rule pattern / output.
   type Elem_Kind is (E_Char, E_Set, E_Cursor, E_Seg_Open, E_Seg_Close, E_Ref);
   type Element is record
      Kind    : Elem_Kind := E_Char;
      Ch      : Code := 0;      --  E_Char
      Set_Idx : Natural := 0;   --  E_Set (index into the transform's Sets)
      Ref     : Natural := 0;   --  E_Ref ($1..$9)
      Quant   : Character := '1';   --  '1' | '?' | '*' | '+'
   end record;
   package Elem_Vec is new Ada.Containers.Vectors (Positive, Element);

   type Rule is record
      Before, Key, After, Output : Elem_Vec.Vector;
   end record;
   package Rule_Vec is new Ada.Containers.Vectors (Positive, Rule);

   type Step_Kind is (S_Rules, S_Filter, S_Call);
   type Step is record
      Kind     : Step_Kind;
      Rules    : Rule_Vec.Vector;
      Set_Idx  : Natural := 0;                 --  S_Filter
      Call     : Unbounded_String;             --  S_Call target
   end record;
   package Step_Vec is new Ada.Containers.Vectors (Positive, Step);

   --  ------------------------------------------------------------------
   --  uprops (script / general category) for UnicodeSet properties
   --  ------------------------------------------------------------------

   type PRange is record
      Lo, Hi : Code;
      Val    : Unbounded_String;
   end record;
   package PRange_Vec is new Ada.Containers.Vectors (Positive, PRange);
   Script_Ranges, GC_Ranges : PRange_Vec.Vector;
   UProps_Loaded : Boolean := False;

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

   procedure Load_PRanges (Key : String; Into : in out PRange_Vec.Vector) is
      S : constant String := I18N.Data_Store.Lookup ("uprops", "prop", Key);
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
               Into.Append
                 (PRange'(Lo  => Code (Hex_Val (Tok (Tok'First .. C1 - 1))),
                          Hi  => Code (Hex_Val (Tok (C1 + 1 .. C2 - 1))),
                          Val => To_Unbounded_String (Tok (C2 + 1 .. Tok'Last))));
            end;
            I := J + 1;
         end;
      end loop;
   end Load_PRanges;

   procedure Ensure_UProps is
   begin
      if UProps_Loaded then
         return;
      end if;
      UProps_Loaded := True;
      if not I18N.Data_Store.Available ("uprops") then
         return;
      end if;
      Load_PRanges ("script", Script_Ranges);
      Load_PRanges ("gc", GC_Ranges);
   end Ensure_UProps;

   --  ------------------------------------------------------------------
   --  Set operations (normalized sorted range vectors)
   --  ------------------------------------------------------------------

   procedure Add_R (V : in out Range_Vec.Vector; Lo, Hi : Code) is
   begin
      if Lo <= Hi then
         V.Append (Range_T'(Lo, Hi));
      end if;
   end Add_R;

   function Range_Less (A, B : Range_T) return Boolean is (A.Lo < B.Lo);
   package Range_Sorting is new Range_Vec.Generic_Sorting ("<" => Range_Less);

   procedure Normalize (V : in out Range_Vec.Vector) is
      Out_V : Range_Vec.Vector;
   begin
      Range_Sorting.Sort (V);
      for R of V loop
         if not Out_V.Is_Empty
           and then R.Lo <= Out_V.Last_Element.Hi + 1
         then
            declare
               L : Range_T := Out_V.Last_Element;
            begin
               if R.Hi > L.Hi then
                  L.Hi := R.Hi;
                  Out_V.Replace_Element (Out_V.Last_Index, L);
               end if;
            end;
         else
            Out_V.Append (R);
         end if;
      end loop;
      V := Out_V;
   end Normalize;

   function In_Set (V : Range_Vec.Vector; C : Code) return Boolean is
      Lo : Integer := V.First_Index;
      Hi : Integer := V.Last_Index;
   begin
      while Lo <= Hi loop
         declare
            Mid : constant Integer := (Lo + Hi) / 2;
            R   : constant Range_T := V (Mid);
         begin
            if C < R.Lo then
               Hi := Mid - 1;
            elsif C > R.Hi then
               Lo := Mid + 1;
            else
               return True;
            end if;
         end;
      end loop;
      return False;
   end In_Set;

   function Complement (V : Range_Vec.Vector) return Range_Vec.Vector is
      Out_V : Range_Vec.Vector;
      Next  : Integer := 0;   --  next as-yet-uncovered code point
   begin
      for R of V loop
         if Integer (R.Lo) > Next then
            Add_R (Out_V, Code (Next), R.Lo - 1);
         end if;
         Next := Integer (R.Hi) + 1;
      end loop;
      if Next <= Integer (Code'Last) then
         Add_R (Out_V, Code (Next), Code'Last);
      end if;
      return Out_V;
   end Complement;

   function Intersect (A, B : Range_Vec.Vector) return Range_Vec.Vector is
      Out_V : Range_Vec.Vector;
   begin
      for Ra of A loop
         for Rb of B loop
            declare
               Lo : constant Code := Code'Max (Ra.Lo, Rb.Lo);
               Hi : constant Code := Code'Min (Ra.Hi, Rb.Hi);
            begin
               Add_R (Out_V, Lo, Hi);
            end;
         end loop;
      end loop;
      Normalize (Out_V);
      return Out_V;
   end Intersect;

   function Difference (A, B : Range_Vec.Vector) return Range_Vec.Vector is
     (Intersect (A, Complement (B)));

   --  Property set: scan the loaded uprops ranges.
   function Prop_Set (Name : String) return Range_Vec.Vector is
      V : Range_Vec.Vector;

      function Match_GC (GC, Q : String) return Boolean is
      begin
         if Q'Length = 1 then                 --  a category group like L, M, N
            return GC (GC'First) = Q (Q'First);
         else
            return GC = Q;
         end if;
      end Match_GC;
   begin
      Ensure_UProps;
      --  Try script first, then general category.
      for R of Script_Ranges loop
         if To_String (R.Val) = Name then
            Add_R (V, R.Lo, R.Hi);
         end if;
      end loop;
      if V.Is_Empty then
         for R of GC_Ranges loop
            if Match_GC (To_String (R.Val), Name) then
               Add_R (V, R.Lo, R.Hi);
            end if;
         end loop;
      end if;
      Normalize (V);
      return V;
   end Prop_Set;

   --  ------------------------------------------------------------------
   --  A compiled transform
   --  ------------------------------------------------------------------

   type Compiled is record
      Sets      : Set_Vec.Vector;
      Steps     : Step_Vec.Vector;
      OK        : Boolean := True;   --  False if an unsupported construct hit
   end record;

   --  ------------------------------------------------------------------
   --  Parsing helpers
   --  ------------------------------------------------------------------

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = ASCII.HT or else C = ASCII.LF or else C = ASCII.CR);

   --  Decode one code point from a UTF-8 string at I (advances I).
   procedure Next_CP (S : String; I : in out Natural; C : out Code) is
      B  : constant Natural := Character'Pos (S (I));
      Nb : Natural;
      V  : Code;
   begin
      if B < 16#80# then
         V := Code (B); Nb := 0;
      elsif B < 16#E0# then
         V := Code (B - 16#C0#); Nb := 1;
      elsif B < 16#F0# then
         V := Code (B - 16#E0#); Nb := 2;
      else
         V := Code (B - 16#F0#); Nb := 3;
      end if;
      for K in 1 .. Nb loop
         exit when I + K > S'Last;
         V := V * 64 + Code (Character'Pos (S (I + K)) - 16#80#);
      end loop;
      I := I + Nb + 1;
      C := V;
   end Next_CP;

   --  Parse a \-escape at I (I points just past '\'); returns the code point.
   procedure Parse_Escape (S : String; I : in out Natural; C : out Code) is
   begin
      if I > S'Last then
         C := Code (Character'Pos ('\')); return;
      end if;
      case S (I) is
         when 'u' =>
            C := Code (Hex_Val (S (I + 1 .. Natural'Min (I + 4, S'Last))));
            I := I + 5;
         when 'U' =>
            C := Code (Hex_Val (S (I + 1 .. Natural'Min (I + 8, S'Last))));
            I := I + 9;
         when 'n' => C := 10; I := I + 1;
         when 't' => C := 9;  I := I + 1;
         when 'r' => C := 13; I := I + 1;
         when others =>
            Next_CP (S, I, C);
      end case;
   end Parse_Escape;

   --  Arrows (UTF-8): → E2 86 92, ← E2 86 90, ↔ E2 86 94.
   function Arrow_At (S : String; I : Natural) return Character is
      --  Returns 'F' (forward →), 'R' (reverse ←), 'B' (both ↔), or ' '.
   begin
      if I + 2 <= S'Last and then Character'Pos (S (I)) = 16#E2#
        and then Character'Pos (S (I + 1)) = 16#86#
      then
         case Character'Pos (S (I + 2)) is
            when 16#92# => return 'F';
            when 16#90# => return 'R';
            when 16#94# => return 'B';
            when others => return ' ';
         end case;
      end if;
      return ' ';
   end Arrow_At;

   --  First occurrence of Ch outside single quotes and outside '[' brackets.
   function Index_Non_Quoted (S : String; Ch : Character) return Natural is
      In_Q  : Boolean := False;
      Depth : Natural := 0;
      I     : Natural := S'First;
   begin
      while I <= S'Last loop
         if In_Q then
            if S (I) = ''' then
               In_Q := False;
            end if;
         elsif S (I) = '\' then
            I := I + 1;
         elsif S (I) = ''' then
            In_Q := True;
         elsif S (I) = '[' then
            Depth := Depth + 1;
         elsif S (I) = ']' then
            if Depth > 0 then
               Depth := Depth - 1;
            end if;
         elsif Depth = 0 and then S (I) = Ch then
            return I;
         end if;
         I := I + 1;
      end loop;
      return 0;
   end Index_Non_Quoted;

   --  ------------------------------------------------------------------
   --  Compilation
   --  ------------------------------------------------------------------

   --  Variables: name -> element sequence, kept in parallel lists.
   package Name_Vec is new Ada.Containers.Vectors
     (Positive, Unbounded_String, "=");
   package Seq_Vec is new Ada.Containers.Vectors (Positive, Elem_Vec.Vector,
                                                  Elem_Vec."=");

   function Compile (Rules : String; Reverse_Dir : Boolean) return Compiled is
      T          : Compiled;
      Var_Names  : Name_Vec.Vector;
      Var_Seqs   : Seq_Vec.Vector;

      --  Add a set to the table, return its index.
      function Add_Set (V : Range_Vec.Vector) return Natural is
      begin
         T.Sets.Append (V);
         return T.Sets.Last_Index;
      end Add_Set;

      --  Parse a UnicodeSet starting at S(I) = '['. Advances I past ']'.
      function Parse_Set (S : String; I : in out Natural) return Range_Vec.Vector
      is
         Acc    : Range_Vec.Vector;   --  accumulated result
         Op     : Character := '|';   --  pending operator: | & -
         Negate : Boolean := False;

         procedure Apply (Cur : Range_Vec.Vector) is
         begin
            case Op is
               when '&' => Acc := Intersect (Acc, Cur);
               when '-' => Acc := Difference (Acc, Cur);
               when others =>
                  for R of Cur loop
                     Acc.Append (R);
                  end loop;
                  Normalize (Acc);
            end case;
            Op := '|';
         end Apply;
      begin
         I := I + 1;  --  past '['
         if I <= S'Last and then S (I) = '^' then
            Negate := True; I := I + 1;
         end if;
         while I <= S'Last and then S (I) /= ']' loop
            if Is_Space (S (I)) then
               I := I + 1;
            elsif S (I) = '&' then
               Op := '&'; I := I + 1;
            elsif S (I) = '-' and then I + 1 <= S'Last
              and then (S (I + 1) = '[' or else S (I + 1) = '\'
                        or else S (I + 1) = ':')
            then
               Op := '-'; I := I + 1;
            elsif S (I) = '[' then
               Apply (Parse_Set (S, I));
            elsif S (I) = ':' or else
              (S (I) = '\' and then I + 1 <= S'Last
               and then (S (I + 1) = 'p' or else S (I + 1) = 'P'))
            then
               --  Property: [:Name:] or \p{Name}.
               declare
                  Neg  : Boolean := False;
                  Name : Unbounded_String;
               begin
                  if S (I) = ':' then
                     I := I + 1;
                     if I <= S'Last and then S (I) = '^' then
                        Neg := True; I := I + 1;
                     end if;
                     while I <= S'Last and then S (I) /= ':' loop
                        Append (Name, S (I)); I := I + 1;
                     end loop;
                     I := I + 1;  --  past ':'  (then ']' consumed by loop? no)
                  else
                     I := I + 2;  --  past \p
                     if I <= S'Last and then S (I) = '{' then
                        I := I + 1;
                     end if;
                     if I <= S'Last and then S (I) = '^' then
                        Neg := True; I := I + 1;
                     end if;
                     while I <= S'Last and then S (I) /= '}' loop
                        Append (Name, S (I)); I := I + 1;
                     end loop;
                     I := I + 1;
                  end if;
                  declare
                     PS : Range_Vec.Vector := Prop_Set (To_String (Name));
                  begin
                     if Neg then
                        PS := Complement (PS);
                     end if;
                     Apply (PS);
                  end;
               end;
            elsif S (I) = '$' then
               --  Variable reference: expand its (single-set) sequence.
               declare
                  Nm : Unbounded_String;
               begin
                  I := I + 1;
                  while I <= S'Last and then
                    (S (I) in 'A' .. 'Z' or else S (I) in 'a' .. 'z'
                     or else S (I) in '0' .. '9' or else S (I) = '_')
                  loop
                     Append (Nm, S (I)); I := I + 1;
                  end loop;
                  for K in Var_Names.First_Index .. Var_Names.Last_Index loop
                     if Var_Names (K) = Nm then
                        for E of Var_Seqs (K) loop
                           if E.Kind = E_Set then
                              Apply (T.Sets (E.Set_Idx));
                           elsif E.Kind = E_Char then
                              declare
                                 One : Range_Vec.Vector;
                              begin
                                 Add_R (One, E.Ch, E.Ch);
                                 Apply (One);
                              end;
                           end if;
                        end loop;
                     end if;
                  end loop;
               end;
            else
               --  A character or a range c-c.
               declare
                  C1, C2 : Code;
                  One    : Range_Vec.Vector;
               begin
                  if S (I) = '\' then
                     I := I + 1; Parse_Escape (S, I, C1);
                  elsif S (I) = ''' then
                     I := I + 1; Next_CP (S, I, C1);
                     if I <= S'Last and then S (I) = ''' then
                        I := I + 1;
                     end if;
                  else
                     Next_CP (S, I, C1);
                  end if;
                  C2 := C1;
                  if I <= S'Last and then S (I) = '-'
                    and then I + 1 <= S'Last and then S (I + 1) /= '['
                  then
                     I := I + 1;
                     if S (I) = '\' then
                        I := I + 1; Parse_Escape (S, I, C2);
                     else
                        Next_CP (S, I, C2);
                     end if;
                  end if;
                  Add_R (One, C1, C2);
                  Apply (One);
               end;
            end if;
         end loop;
         if I <= S'Last then
            I := I + 1;  --  past ']'
         end if;
         if Negate then
            Acc := Complement (Acc);
         end if;
         return Acc;
      end Parse_Set;

      --  Parse an element sequence from S (I .. Stop-1) into Into. Handles
      --  literals, quotes, escapes, [sets], $vars, () segments, | cursor,
      --  and $1..$9 references.
      procedure Parse_Seq
        (S : String; I : in out Natural; Stop : Natural;
         Into : in out Elem_Vec.Vector)
      is
      begin
         while I < Stop loop
            if Is_Space (S (I)) then
               I := I + 1;
            elsif (S (I) = '+' or else S (I) = '*' or else S (I) = '?')
              and then not Into.Is_Empty
            then
               declare
                  L : Element := Into.Last_Element;
               begin
                  L.Quant := S (I);
                  Into.Replace_Element (Into.Last_Index, L);
               end;
               I := I + 1;
            elsif S (I) = '[' then
               Into.Append (Element'(Kind => E_Set, Set_Idx => Add_Set (Parse_Set (S, I)),
                             others => <>));
            elsif S (I) = '{' or else S (I) = '}' then
               I := I + 1;   --  context braces handled by the caller's split
            elsif S (I) = '|' then
               Into.Append (Element'(Kind => E_Cursor, others => <>));
               I := I + 1;
            elsif S (I) = '(' then
               Into.Append (Element'(Kind => E_Seg_Open, others => <>));
               I := I + 1;
            elsif S (I) = ')' then
               Into.Append (Element'(Kind => E_Seg_Close, others => <>));
               I := I + 1;
            elsif S (I) = ''' then
               --  Quoted literal run.
               I := I + 1;
               while I < Stop and then S (I) /= ''' loop
                  declare
                     C : Code;
                  begin
                     Next_CP (S, I, C);
                     Into.Append (Element'(Kind => E_Char, Ch => C, others => <>));
                  end;
               end loop;
               if I < Stop then
                  I := I + 1;
               end if;
            elsif S (I) = '\' then
               I := I + 1;
               declare
                  C : Code;
               begin
                  Parse_Escape (S, I, C);
                  Into.Append (Element'(Kind => E_Char, Ch => C, others => <>));
               end;
            elsif S (I) = '$' then
               I := I + 1;
               if I < Stop and then S (I) in '1' .. '9' then
                  Into.Append (Element'(Kind => E_Ref,
                                Ref => Character'Pos (S (I)) - 48, others => <>));
                  I := I + 1;
               else
                  declare
                     Nm : Unbounded_String;
                  begin
                     while I < Stop and then
                       (S (I) in 'A' .. 'Z' or else S (I) in 'a' .. 'z'
                        or else S (I) in '0' .. '9' or else S (I) = '_')
                     loop
                        Append (Nm, S (I)); I := I + 1;
                     end loop;
                     for K in Var_Names.First_Index .. Var_Names.Last_Index loop
                        if Var_Names (K) = Nm then
                           for E of Var_Seqs (K) loop
                              Into.Append (E);
                           end loop;
                        end if;
                     end loop;
                  end;
               end if;
            else
               declare
                  C : Code;
               begin
                  Next_CP (S, I, C);
                  Into.Append (Element'(Kind => E_Char, Ch => C, others => <>));
               end;
            end if;
         end loop;
      end Parse_Seq;

      --  Split rules text into statements at top-level ';', stripping comments.
      Cur_Rules : Rule_Vec.Vector;

      procedure Flush_Rules is
      begin
         if not Cur_Rules.Is_Empty then
            T.Steps.Append
              (Step'(Kind => S_Rules, Rules => Cur_Rules, Set_Idx => 0,
                Call => Null_Unbounded_String));
            Cur_Rules.Clear;
         end if;
      end Flush_Rules;

      procedure Process_Statement (St : String) is
         F, L : Natural;
      begin
         F := St'First;
         while F <= St'Last and then Is_Space (St (F)) loop
            F := F + 1;
         end loop;
         L := St'Last;
         while L >= F and then Is_Space (St (L)) loop
            L := L - 1;
         end loop;
         if F > L then
            return;
         end if;
         declare
            Body_S : String renames St (F .. L);
         begin
            if Body_S'Length >= 2
              and then Body_S (Body_S'First .. Body_S'First + 1) = "::"
            then
               --  Directive.
               Flush_Rules;
               declare
                  P : Natural := Body_S'First + 2;
               begin
                  while P <= Body_S'Last and then Is_Space (Body_S (P)) loop
                     P := P + 1;
                  end loop;
                  if P <= Body_S'Last and then Body_S (P) = '[' then
                     T.Steps.Append
                       (Step'(Kind => S_Filter,
                         Set_Idx => Add_Set (Parse_Set (Body_S, P)),
                         Rules => Rule_Vec.Empty_Vector,
                         Call => Null_Unbounded_String));
                  else
                     --  Name, or Name (Inverse).
                     declare
                        Fwd, Rev : Unbounded_String;
                        In_Paren : Boolean := False;
                     begin
                        while P <= Body_S'Last loop
                           if Body_S (P) = '(' then
                              In_Paren := True;
                           elsif Body_S (P) = ')' then
                              In_Paren := False;
                           elsif not Is_Space (Body_S (P)) then
                              if In_Paren then
                                 Append (Rev, Body_S (P));
                              else
                                 Append (Fwd, Body_S (P));
                              end if;
                           end if;
                           P := P + 1;
                        end loop;
                        declare
                           Nm : constant Unbounded_String :=
                             (if Reverse_Dir and then Length (Rev) > 0 then Rev
                              elsif Reverse_Dir then
                                 Fwd else Fwd);
                        begin
                           if Length (Nm) > 0 then
                              T.Steps.Append
                                (Step'(Kind => S_Call, Call => Nm,
                                  Rules => Rule_Vec.Empty_Vector, Set_Idx => 0));
                           end if;
                        end;
                     end;
                  end if;
               end;
            elsif Body_S (Body_S'First) = '$'
              and then (for some K in Body_S'Range => Body_S (K) = '=')
              and then (for all K in Body_S'First .. Body_S'Last =>
                          Arrow_At (Body_S, K) = ' ')
            then
               --  Variable definition: $name = value
               declare
                  Eq : Natural := Body_S'First;
               begin
                  while Eq <= Body_S'Last and then Body_S (Eq) /= '=' loop
                     Eq := Eq + 1;
                  end loop;
                  declare
                     Nm : Unbounded_String;
                     K  : Natural := Body_S'First + 1;
                     Seq : Elem_Vec.Vector;
                     VI  : Natural := Eq + 1;
                  begin
                     while K < Eq and then not Is_Space (Body_S (K)) loop
                        Append (Nm, Body_S (K)); K := K + 1;
                     end loop;
                     Parse_Seq (Body_S, VI, Body_S'Last + 1, Seq);
                     Var_Names.Append (Nm);
                     Var_Seqs.Append (Seq);
                  end;
               end;
            else
               --  Conversion rule: find the arrow.
               declare
                  Ar_Pos : Natural := 0;
                  Ar     : Character := ' ';
                  P      : Natural := Body_S'First;
               begin
                  while P <= Body_S'Last loop
                     if Body_S (P) = ''' then
                        P := P + 1;
                        while P <= Body_S'Last and then Body_S (P) /= ''' loop
                           P := P + 1;
                        end loop;
                        P := P + 1;   --  past the closing quote
                     elsif Body_S (P) = '\' then
                        P := P + 2;
                     else
                        declare
                           A : constant Character := Arrow_At (Body_S, P);
                        begin
                           if A /= ' ' then
                              Ar_Pos := P; Ar := A; exit;
                           end if;
                        end;
                        P := P + 1;
                     end if;
                  end loop;
                  if Ar_Pos = 0 then
                     return;   --  not a rule we understand
                  end if;
                  --  Applicability by direction.
                  if (not Reverse_Dir and then Ar = 'R')
                    or else (Reverse_Dir and then Ar = 'F')
                  then
                     return;
                  end if;
                  declare
                     Left_S  : constant String :=
                       Body_S (Body_S'First .. Ar_Pos - 1);
                     Right_S : constant String :=
                       Body_S (Ar_Pos + 3 .. Body_S'Last);
                     --  For reverse, swap the two sides.
                     Pat_S   : constant String :=
                       (if Reverse_Dir then
                          Right_S else Left_S);
                     Out_S   : constant String :=
                       (if Reverse_Dir then
                          Left_S else Right_S);
                     R       : Rule;
                     --  Split Pat_S into before { key } after.
                     Ob : constant Natural := Index_Non_Quoted (Pat_S, '{');
                     Cb : constant Natural := Index_Non_Quoted (Pat_S, '}');
                     KI : Natural;
                  begin
                     declare
                        Key_Lo : constant Natural :=
                          (if Ob /= 0 then
                             Ob + 1 else Pat_S'First);
                        Key_Hi : constant Natural :=
                          (if Cb /= 0 then
                             Cb - 1 else Pat_S'Last);
                     begin
                        if Ob /= 0 then
                           KI := Pat_S'First;
                           Parse_Seq (Pat_S, KI, Ob, R.Before);
                        end if;
                        KI := Key_Lo;
                        Parse_Seq (Pat_S, KI, Key_Hi + 1, R.Key);
                        if Cb /= 0 then
                           KI := Cb + 1;
                           Parse_Seq (Pat_S, KI, Pat_S'Last + 1, R.After);
                        end if;
                     end;
                     declare
                        OI : Natural := Out_S'First;
                     begin
                        Parse_Seq (Out_S, OI, Out_S'Last + 1, R.Output);
                     end;
                     if not R.Key.Is_Empty then
                        Cur_Rules.Append (R);
                     end if;
                  end;
               end;
            end if;
         end;
      end Process_Statement;

      --  Statement splitting with quote/escape/bracket awareness.
      I     : Natural := Rules'First;
      Start : Natural := Rules'First;
      Depth : Natural := 0;
      In_Q  : Boolean := False;
   begin
      while I <= Rules'Last loop
         declare
            C : constant Character := Rules (I);
         begin
            if In_Q then
               if C = ''' then
                  In_Q := False;
               end if;
               I := I + 1;
            elsif C = '\' then
               I := I + 2;
            elsif C = ''' then
               In_Q := True; I := I + 1;
            elsif C = '#' then
               --  comment to end of line
               while I <= Rules'Last and then Rules (I) /= ASCII.LF loop
                  I := I + 1;
               end loop;
            elsif C = '[' then
               Depth := Depth + 1; I := I + 1;
            elsif C = ']' then
               if Depth > 0 then
                  Depth := Depth - 1;
               end if;
               I := I + 1;
            elsif C = ';' and then Depth = 0 then
               Process_Statement (Rules (Start .. I - 1));
               I := I + 1; Start := I;
            else
               I := I + 1;
            end if;
         end;
      end loop;
      if Start <= Rules'Last then
         Process_Statement (Rules (Start .. Rules'Last));
      end if;
      Flush_Rules;
      return T;
   end Compile;

   --  ------------------------------------------------------------------
   --  Evaluation
   --  ------------------------------------------------------------------

   type Seg_Array is array (1 .. 9) of Natural;

   package Code_Vec is new Ada.Containers.Vectors (Positive, Code);

   procedure Encode (C : Code; Into : in out String; Last : in out Natural) is
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

   function Encode_All (V : Code_Vec.Vector) return String is
      Out_S : String (1 .. 4 * Natural (V.Length) + 4);
      Last  : Natural := 0;
   begin
      for C of V loop
         Encode (C, Out_S, Last);
      end loop;
      return Out_S (1 .. Last);
   end Encode_All;

   function Decode_All (Text : String) return Code_Vec.Vector is
      V : Code_Vec.Vector;
      I : Natural := Text'First;
   begin
      while I <= Text'Last loop
         declare
            C : Code;
         begin
            Next_CP (Text, I, C);
            V.Append (C);
         end;
      end loop;
      return V;
   end Decode_All;

   --  Forward declaration for recursive sub-transform calls.
   function Transform_Impl
     (Text : String; Name : String; Depth : Natural) return String;

   --  Apply one rule-set step with a cursor over Buf.
   procedure Apply_Rules
     (T : Compiled; Rules : Rule_Vec.Vector; Filter_Idx : Natural;
      Buf : in out Code_Vec.Vector)
   is
      I : Positive := 1;

      --  Match Elems forward against Buf starting at P; returns consumed count
      --  or -1 on failure. Records segment spans (open/close cp indices).
      function Match_Fwd
        (Elems : Elem_Vec.Vector; P : Positive;
         Seg_Lo, Seg_Hi : in out Seg_Array;
         Seg_N : in out Natural) return Integer
      is
         Q : Integer := P;

         function Test (E : Element; At_Q : Integer) return Boolean is
           (At_Q <= Natural (Buf.Length)
            and then (case E.Kind is
                         when E_Char => Buf (At_Q) = E.Ch,
                         when E_Set  => In_Set (T.Sets (E.Set_Idx), Buf (At_Q)),
                         when others => False));
      begin
         for E of Elems loop
            case E.Kind is
               when E_Char | E_Set =>
                  case E.Quant is
                     when '?' =>
                        if Test (E, Q) then
                           Q := Q + 1;
                        end if;
                     when '*' =>
                        while Test (E, Q) loop Q := Q + 1; end loop;
                     when '+' =>
                        if not Test (E, Q) then
                           return -1;
                        end if;
                        while Test (E, Q) loop Q := Q + 1; end loop;
                     when others =>
                        if not Test (E, Q) then
                           return -1;
                        end if;
                        Q := Q + 1;
                  end case;
               when E_Seg_Open =>
                  Seg_N := Seg_N + 1;
                  if Seg_N <= 9 then
                     Seg_Lo (Seg_N) := Q;
                  end if;
               when E_Seg_Close =>
                  if Seg_N <= 9 and then Seg_N >= 1 then
                     Seg_Hi (Seg_N) := Q - 1;
                  end if;
               when others =>
                  null;
            end case;
         end loop;
         return Q - P;
      end Match_Fwd;

      --  Match Elems (a context) against Buf ending just before P (backward).
      function Match_Bwd (Elems : Elem_Vec.Vector; P : Positive) return Boolean is
         Q : Integer := P - 1;
         function Test (E : Element; At_Q : Integer) return Boolean is
           (At_Q >= 1
            and then (case E.Kind is
                         when E_Char => Buf (At_Q) = E.Ch,
                         when E_Set  => In_Set (T.Sets (E.Set_Idx), Buf (At_Q)),
                         when others => False));
      begin
         for K in reverse Elems.First_Index .. Elems.Last_Index loop
            declare
               E : constant Element := Elems (K);
            begin
               case E.Kind is
                  when E_Char | E_Set =>
                     case E.Quant is
                        when '?' =>
                           if Test (E, Q) then
                              Q := Q - 1;
                           end if;
                        when '*' =>
                           while Test (E, Q) loop Q := Q - 1; end loop;
                        when '+' =>
                           if not Test (E, Q) then
                              return False;
                           end if;
                           while Test (E, Q) loop Q := Q - 1; end loop;
                        when others =>
                           if not Test (E, Q) then
                              return False;
                           end if;
                           Q := Q - 1;
                     end case;
                  when others =>
                     null;
               end case;
            end;
         end loop;
         return True;
      end Match_Bwd;
   begin
      while I <= Natural (Buf.Length) loop
         if Filter_Idx /= 0
           and then not In_Set (T.Sets (Filter_Idx), Buf (I))
         then
            I := I + 1;
         else
            declare
               Applied : Boolean := False;
            begin
               for R of Rules loop
                  declare
                     Seg_Lo, Seg_Hi : Seg_Array := [others => 0];
                     Seg_N : Natural := 0;
                     KLen  : constant Integer :=
                       Match_Fwd (R.Key, I, Seg_Lo, Seg_Hi, Seg_N);
                  begin
                     if KLen >= 0 then
                        declare
                           After_Dummy_Lo, After_Dummy_Hi :
                             Seg_Array := [others => 0];
                           After_N : Natural := 9;   --  don't record after segs
                           ALen : constant Integer :=
                             Match_Fwd (R.After, I + KLen, After_Dummy_Lo,
                                        After_Dummy_Hi, After_N);
                        begin
                           if ALen >= 0 and then Match_Bwd (R.Before, I) then
                              --  Build the output.
                              declare
                                 Out_C  : Code_Vec.Vector;
                                 Cursor : Natural := 0;   --  cps before '|'
                                 Seen_Cur : Boolean := False;
                              begin
                                 for E of R.Output loop
                                    case E.Kind is
                                       when E_Char =>
                                          Out_C.Append (E.Ch);
                                          if not Seen_Cur then
                                             Cursor := Cursor + 1;
                                          end if;
                                       when E_Cursor =>
                                          Seen_Cur := True;
                                       when E_Ref =>
                                          if E.Ref <= Seg_N
                                            and then Seg_Lo (E.Ref) > 0
                                          then
                                             for X in Seg_Lo (E.Ref) .. Seg_Hi (E.Ref)
                                             loop
                                                Out_C.Append (Buf (X));
                                                if not Seen_Cur then
                                                   Cursor := Cursor + 1;
                                                end if;
                                             end loop;
                                          end if;
                                       when others =>
                                          null;
                                    end case;
                                 end loop;
                                 --  Replace Buf (I .. I+KLen-1) with Out_C.
                                 for X in reverse 1 .. KLen loop
                                    Buf.Delete (I);
                                 end loop;
                                 declare
                                    Ins : Natural := I;
                                 begin
                                    for C of Out_C loop
                                       Buf.Insert (Ins, C);
                                       Ins := Ins + 1;
                                    end loop;
                                 end;
                                 if not Seen_Cur then
                                    Cursor := Natural (Out_C.Length);
                                 end if;
                                 I := I + Cursor;
                                 Applied := True;
                              end;
                           end if;
                        end;
                     end if;
                  end;
                  exit when Applied;
               end loop;
               if not Applied then
                  I := I + 1;
               end if;
            end;
         end if;
      end loop;
   end Apply_Rules;

   function Eq_Ci (A, B : String) return Boolean is
      function Lc (C : Character) return Character is
        (if C in 'A' .. 'Z' then
           Character'Val (Character'Pos (C) + 32) else C);
   begin
      if A'Length /= B'Length then
         return False;
      end if;
      for K in 0 .. A'Length - 1 loop
         if Lc (A (A'First + K)) /= Lc (B (B'First + K)) then
            return False;
         end if;
      end loop;
      return True;
   end Eq_Ci;

   function Run (T : Compiled; Text : String; Depth : Natural) return String is
      Buf : Code_Vec.Vector := Decode_All (Text);
      Cur_Filter : Natural := 0;
      use type I18N.Normalization.Form;
   begin
      for S of T.Steps loop
         case S.Kind is
            when S_Filter =>
               Cur_Filter := S.Set_Idx;
            when S_Rules =>
               Apply_Rules (T, S.Rules, Cur_Filter, Buf);
            when S_Call =>
               declare
                  Name : constant String := To_String (S.Call);
                  Cur  : constant String := Encode_All (Buf);
                  Res  : Unbounded_String;
               begin
                  if Eq_Ci (Name, "NFD") then
                     Res := To_Unbounded_String
                       (I18N.Normalization.Normalize (Cur, I18N.Normalization.NFD));
                  elsif Eq_Ci (Name, "NFC") then
                     Res := To_Unbounded_String
                       (I18N.Normalization.Normalize (Cur, I18N.Normalization.NFC));
                  elsif Eq_Ci (Name, "NFKD") then
                     Res := To_Unbounded_String
                       (I18N.Normalization.Normalize (Cur, I18N.Normalization.NFKD));
                  elsif Eq_Ci (Name, "NFKC") then
                     Res := To_Unbounded_String
                       (I18N.Normalization.Normalize (Cur, I18N.Normalization.NFKC));
                  elsif Eq_Ci (Name, "Lower") or else Eq_Ci (Name, "Any-Lower") then
                     Res := To_Unbounded_String (I18N.Casing.To_Lower (Cur));
                  elsif Eq_Ci (Name, "Upper") or else Eq_Ci (Name, "Any-Upper") then
                     Res := To_Unbounded_String (I18N.Casing.To_Upper (Cur));
                  elsif Eq_Ci (Name, "Title") or else Eq_Ci (Name, "Any-Title") then
                     Res := To_Unbounded_String (I18N.Casing.To_Title (Cur));
                  elsif Eq_Ci (Name, "Null") then
                     Res := To_Unbounded_String (Cur);
                  elsif Eq_Ci (Name, "Remove") then
                     Res := Null_Unbounded_String;
                  elsif Depth < 16 then
                     Res := To_Unbounded_String (Transform_Impl (Cur, Name, Depth + 1));
                  else
                     Res := To_Unbounded_String (Cur);
                  end if;
                  Buf := Decode_All (To_String (Res));
               end;
         end case;
      end loop;
      return Encode_All (Buf);
   end Run;

   --  ------------------------------------------------------------------
   --  Transform index and shard loading
   --  ------------------------------------------------------------------

   Index_Loaded : Boolean := False;
   Index_Have   : Boolean := False;
   Idx_Names    : Name_Vec.Vector;   --  alias name
   Idx_Files    : Name_Vec.Vector;   --  "basename:D"

   --  Compiled-transform cache, keyed by "basename:D".
   package Compiled_Vec is new Ada.Containers.Vectors (Positive, Compiled);
   Cache_Keys : Name_Vec.Vector;
   Cache_Vals : Compiled_Vec.Vector;

   procedure Ensure_Index is
   begin
      if Index_Loaded then
         return;
      end if;
      Index_Loaded := True;
      if not I18N.Data_Store.Available ("transforms/_index") then
         return;
      end if;
      Index_Have := True;
      declare
         S : constant String :=
           I18N.Data_Store.Lookup ("transforms/_index", "meta", "map");
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
                  Eq  : Natural := Tok'First;
               begin
                  while Eq <= Tok'Last and then Tok (Eq) /= '=' loop
                     Eq := Eq + 1;
                  end loop;
                  if Eq <= Tok'Last then
                     Idx_Names.Append
                       (To_Unbounded_String (Tok (Tok'First .. Eq - 1)));
                     Idx_Files.Append
                       (To_Unbounded_String (Tok (Eq + 1 .. Tok'Last)));
                  end if;
               end;
               I := J + 1;
            end;
         end loop;
      end;
   end Ensure_Index;

   function Transform_Impl
     (Text : String; Name : String; Depth : Natural) return String
   is
      File_Spec : Unbounded_String;
   begin
      Ensure_Index;
      if not Index_Have then
         return Text;
      end if;
      for K in Idx_Names.First_Index .. Idx_Names.Last_Index loop
         if To_String (Idx_Names (K)) = Name then
            File_Spec := Idx_Files (K);
            exit;
         end if;
      end loop;
      if Length (File_Spec) = 0 then
         return Text;   --  unknown transform: pass through
      end if;
      declare
         Spec  : constant String := To_String (File_Spec);
         Colon : Natural := Spec'Last;
      begin
         while Colon >= Spec'First and then Spec (Colon) /= ':' loop
            Colon := Colon - 1;
         end loop;
         declare
            Base : constant String := Spec (Spec'First .. Colon - 1);
            Dir  : constant Boolean := Spec (Spec'Last) = 'R';
         begin
            for K in Cache_Keys.First_Index .. Cache_Keys.Last_Index loop
               if To_String (Cache_Keys (K)) = Spec then
                  --  Copy out first: Run's recursive sub-transform calls append
                  --  to the cache and can reallocate it, dangling the element.
                  declare
                     TC : constant Compiled := Cache_Vals (K);
                  begin
                     return Run (TC, Text, Depth);
                  end;
               end if;
            end loop;
            declare
               Rules : constant String :=
                 I18N.Data_Store.Lookup ("transforms/" & Base, "meta", "rules");
               T : constant Compiled := Compile (Rules, Dir);
            begin
               Cache_Keys.Append (To_Unbounded_String (Spec));
               Cache_Vals.Append (T);
               return Run (T, Text, Depth);
            end;
         end;
      end;
   end Transform_Impl;

   function Transform (Text : String; Name : String) return String is
     (Transform_Impl (Text, Name, 0));

   function Available return Boolean is
   begin
      Ensure_Index;
      return Index_Have;
   end Available;

end I18N.Transliteration;
