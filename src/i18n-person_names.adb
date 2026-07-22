with I18N.Data_Store;

package body I18N.Person_Names is

   Sep : constant Character := I18N.Data_Store.Key_Separator;

   --  ------------------------------------------------------------------
   --  Name construction
   --  ------------------------------------------------------------------

   procedure Set_Field (N : in out Name; Field : String; Value : String) is
   begin
      for I in 1 .. N.Count loop
         if To_String (N.Fields (I).Key) = Field then
            N.Fields (I).Value := To_Unbounded_String (Value);
            return;
         end if;
      end loop;
      if N.Count < Max_Fields then
         N.Count := N.Count + 1;
         N.Fields (N.Count) :=
           (To_Unbounded_String (Field), To_Unbounded_String (Value));
      end if;
   end Set_Field;

   procedure Set_Locale (N : in out Name; Locale : String) is
   begin
      N.Locale := To_Unbounded_String (Locale);
   end Set_Locale;

   procedure Clear (N : in out Name) is
   begin
      N.Count := 0;
      N.Locale := Null_Unbounded_String;
   end Clear;

   function Get (N : Name; Key : String) return String is
   begin
      for I in 1 .. N.Count loop
         if To_String (N.Fields (I).Key) = Key then
            return To_String (N.Fields (I).Value);
         end if;
      end loop;
      return "";
   end Get;

   --  ------------------------------------------------------------------
   --  Locale helpers and shard lookups
   --  ------------------------------------------------------------------

   function Norm (Locale : String) return String is
      R : String := Locale;
   begin
      for I in R'Range loop
         if R (I) = '_' then
            R (I) := '-';
         end if;
      end loop;
      return R;
   end Norm;

   function Language_Of (Locale : String) return String is
   begin
      for I in Locale'Range loop
         if Locale (I) = '-' then
            return Locale (Locale'First .. I - 1);
         end if;
      end loop;
      return Locale;
   end Language_Of;

   --  Look up Key in Section of the locale's person-name shard, walking parents.
   function Walk (Locale, Section, Key : String) return String is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                ("person-names/" & Cand (Cand'First .. Last), Section, Key);
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return "";
   end Walk;

   --  Membership of Lang in a Sep-joined list.
   function In_List (List, Lang : String) return Boolean is
      Start : Natural := List'First;
   begin
      for I in List'Range loop
         if List (I) = Sep then
            if List (Start .. I - 1) = Lang then
               return True;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return Start <= List'Last and then List (Start .. List'Last) = Lang;
   end In_List;

   --  ------------------------------------------------------------------
   --  Field modifiers
   --  ------------------------------------------------------------------

   --  Length in bytes of the UTF-8 code point starting at Lead.
   function CP_Length (Lead : Character) return Positive is
      B : constant Natural := Character'Pos (Lead);
   begin
      if B < 16#80# then
         return 1;
      elsif B < 16#E0# then
         return 2;
      elsif B < 16#F0# then
         return 3;
      else
         return 4;
      end if;
   end CP_Length;

   function First_Grapheme (S : String) return String is
   begin
      if S'Length = 0 then
         return "";
      end if;
      return S (S'First .. Natural'Min (S'Last,
                                        S'First + CP_Length (S (S'First)) - 1));
   end First_Grapheme;

   function Upper (S : String) return String is
      R : String := S;
   begin
      for I in R'Range loop
         if R (I) in 'a' .. 'z' then
            R (I) := Character'Val (Character'Pos (R (I)) - 32);
         end if;
      end loop;
      return R;
   end Upper;

   --  Substitute {0} in Pattern with A.
   function Fill0 (Pattern, A : String) return String is
      Result : String (1 .. Pattern'Length + A'Length);
      Last   : Natural := 0;
      I      : Natural := Pattern'First;
   begin
      if Pattern = "" then
         return A & ".";
      end if;
      while I <= Pattern'Last loop
         if I + 2 <= Pattern'Last + 1
           and then Pattern (I) = '{'
           and then Pattern (I + 1) = '0'
           and then Pattern (I + 2) = '}'
         then
            Result (Last + 1 .. Last + A'Length) := A;
            Last := Last + A'Length;
            I := I + 3;
         else
            Last := Last + 1;
            Result (Last) := Pattern (I);
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Last);
   end Fill0;

   --  Resolve a pattern field key to its value (with modifiers).
   function Resolve_Field
     (N : Name; Key : String; Initial_Pat : String) return String
   is
      Direct : constant String := Get (N, Key);
   begin
      if Direct /= "" then
         return Direct;
      end if;

      declare
         Dash : Natural := 0;
      begin
         for I in Key'Range loop
            if Key (I) = '-' then
               Dash := I;
               exit;
            end if;
         end loop;

         declare
            Base : constant String :=
              (if Dash = 0 then Key else Key (Key'First .. Dash - 1));
            Val  : Unbounded_String := To_Unbounded_String (Get (N, Base));
         begin
            --  Compose a missing surname from its parts.
            if Length (Val) = 0 and then Base = "surname" then
               declare
                  Core   : constant String := Get (N, "surname-core");
                  Prefix : constant String := Get (N, "surname-prefix");
               begin
                  if Core /= "" then
                     Val := To_Unbounded_String
                       (if Prefix /= "" then Prefix & " " & Core else Core);
                  end if;
               end;
            end if;

            if Length (Val) = 0 then
               return "";
            end if;

            --  Apply modifiers left to right.
            if Dash /= 0 then
               declare
                  Mods  : constant String := Key (Dash + 1 .. Key'Last);
                  Start : Natural := Mods'First;

                  procedure Apply (M : String) is
                  begin
                     if M = "initial" then
                        Val := To_Unbounded_String
                          (Fill0 (Initial_Pat, First_Grapheme (To_String (Val))));
                     elsif M = "monogram" then
                        Val := To_Unbounded_String
                          (First_Grapheme (To_String (Val)));
                     elsif M = "allCaps" then
                        Val := To_Unbounded_String (Upper (To_String (Val)));
                     end if;
                     --  core / prefix / informal / genitive / vocative /
                     --  abbreviated / initialCap: use the base value as-is.
                  end Apply;
               begin
                  for I in Mods'Range loop
                     if Mods (I) = '-' then
                        Apply (Mods (Start .. I - 1));
                        Start := I + 1;
                     end if;
                  end loop;
                  Apply (Mods (Start .. Mods'Last));
               end;
            end if;

            return To_String (Val);
         end;
      end;
   end Resolve_Field;

   --  ------------------------------------------------------------------
   --  Order and pattern selection
   --  ------------------------------------------------------------------

   function Order_Id (O : Order_Kind) return String is
     (case O is
         when Given_First   => "givenFirst",
         when Surname_First => "surnameFirst",
         when Sorting       => "sorting",
         when Order_Auto    => "givenFirst");

   function Length_Id (L : Length_Kind) return String is
     (case L is when Long => "long", when Medium => "medium",
        when Short => "short");

   function Usage_Id (U : Usage_Kind) return String is
     (case U is when Referring => "referring", when Addressing => "addressing",
        when Monogram => "monogram");

   function Formality_Id (F : Formality_Kind) return String is
     (case F is when Formal => "formal", when Informal => "informal");

   function Resolved_Order
     (Formatter : String; N : Name; Order : Order_Kind) return Order_Kind
   is
   begin
      if Order /= Order_Auto then
         return Order;
      end if;
      declare
         Loc : constant String := To_String (N.Locale);
      begin
         if Loc = "" then
            return Given_First;
         end if;
         if In_List (Walk (Formatter, "config", "surnameFirst"),
                     Language_Of (Norm (Loc)))
         then
            return Surname_First;
         else
            return Given_First;
         end if;
      end;
   end Resolved_Order;

   --  Select a pattern, falling back over formality then length.
   function Select_Pattern
     (Formatter  : String;
      Order      : Order_Kind;
      Length     : Length_Kind;
      Usage      : Usage_Kind;
      Formality  : Formality_Kind)
      return String
   is
      Lengths : constant array (1 .. 4) of Length_Kind :=
        [Length, Medium, Long, Short];
      Forms   : constant array (1 .. 2) of Formality_Kind :=
        [Formality,
         (if Formality = Formal then Informal else Formal)];

      function Try (O : Order_Kind; U : Usage_Kind) return String is
      begin
         for F of Forms loop
            for L of Lengths loop
               declare
                  Hit : constant String :=
                    Walk (Formatter, "pattern",
                          Order_Id (O) & Sep & Length_Id (L) & Sep
                          & Usage_Id (U) & Sep & Formality_Id (F));
               begin
                  if Hit /= "" then
                     return Hit;
                  end if;
               end;
            end loop;
         end loop;
         return "";
      end Try;

      Direct : constant String := Try (Order, Usage);
   begin
      if Direct /= "" then
         return Direct;
      end if;
      --  Usage fallback (monogram -> referring) and order fallback
      --  (sorting -> givenFirst).
      if Usage = Monogram then
         declare
            R : constant String := Try (Order, Referring);
         begin
            if R /= "" then
               return R;
            end if;
         end;
      end if;
      if Order = Sorting then
         return Try (Given_First, Usage);
      end if;
      return "";
   end Select_Pattern;

   --  ------------------------------------------------------------------
   --  Pattern filling with missing-field handling
   --  ------------------------------------------------------------------

   function Fill_Pattern
     (Pattern : String; N : Name; Initial_Pat : String) return String
   is
      Max_Tok : constant := 64;
      type Token is record
         Is_Field : Boolean;
         Text     : Unbounded_String;   --  literal text, or resolved value
         Empty    : Boolean := False;
         Keep     : Boolean := True;
      end record;
      Toks : array (1 .. Max_Tok) of Token;
      NT   : Natural := 0;

      procedure Push (Is_Field : Boolean; Text : String; Empty : Boolean) is
      begin
         if NT < Max_Tok then
            NT := NT + 1;
            Toks (NT) := (Is_Field, To_Unbounded_String (Text), Empty, True);
         end if;
      end Push;

      I : Natural := Pattern'First;
   begin
      --  Tokenize.
      while I <= Pattern'Last loop
         if Pattern (I) = '{' then
            declare
               J : Natural := I + 1;
            begin
               while J <= Pattern'Last and then Pattern (J) /= '}' loop
                  J := J + 1;
               end loop;
               declare
                  V : constant String :=
                    Resolve_Field (N, Pattern (I + 1 .. J - 1), Initial_Pat);
               begin
                  Push (True, V, V = "");
               end;
               I := J + 1;
            end;
         else
            declare
               J : Natural := I;
            begin
               while J <= Pattern'Last and then Pattern (J) /= '{' loop
                  J := J + 1;
               end loop;
               Push (False, Pattern (I .. J - 1), False);
               I := J;
            end;
         end if;
      end loop;

      --  Drop each empty field plus one adjacent literal (the following one, or
      --  the preceding one if the field is at the end).
      for K in 1 .. NT loop
         if Toks (K).Is_Field and then Toks (K).Empty then
            Toks (K).Keep := False;
            if K < NT and then not Toks (K + 1).Is_Field
              and then Toks (K + 1).Keep
            then
               Toks (K + 1).Keep := False;
            elsif K > 1 and then not Toks (K - 1).Is_Field
              and then Toks (K - 1).Keep
            then
               Toks (K - 1).Keep := False;
            end if;
         end if;
      end loop;

      --  Concatenate kept tokens.
      declare
         Result : Unbounded_String;
      begin
         for K in 1 .. NT loop
            if Toks (K).Keep then
               Append (Result, Toks (K).Text);
            end if;
         end loop;

         --  Trim leading/trailing spaces and collapse internal doubles.
         declare
            S     : constant String := To_String (Result);
            Out_S : String (1 .. S'Length);
            Last  : Natural := 0;
            Prev_Space : Boolean := True;   --  drop leading spaces
         begin
            for C of S loop
               if C = ' ' then
                  if not Prev_Space then
                     Last := Last + 1;
                     Out_S (Last) := ' ';
                     Prev_Space := True;
                  end if;
               else
                  Last := Last + 1;
                  Out_S (Last) := C;
                  Prev_Space := False;
               end if;
            end loop;
            while Last > 0 and then Out_S (Last) = ' ' loop
               Last := Last - 1;
            end loop;
            return Out_S (1 .. Last);
         end;
      end;
   end Fill_Pattern;

   --  ------------------------------------------------------------------
   --  Public
   --  ------------------------------------------------------------------

   function Format
     (Formatter_Locale : String;
      N                : Name;
      Order            : Order_Kind := Order_Auto;
      Length           : Length_Kind := Medium;
      Usage            : Usage_Kind := Referring;
      Formality        : Formality_Kind := Formal)
      return String
   is
      Eff_Order : constant Order_Kind :=
        Resolved_Order (Formatter_Locale, N, Order);
      Pattern   : constant String :=
        Select_Pattern (Formatter_Locale, Eff_Order, Length, Usage, Formality);
      Init_Pat  : constant String :=
        Walk (Formatter_Locale, "config", "initial");
   begin
      if Pattern = "" then
         return "";
      end if;
      return Fill_Pattern (Pattern, N, Init_Pat);
   end Format;

   function Available (Locale : String) return Boolean is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         if I18N.Data_Store.Available
              ("person-names/" & Cand (Cand'First .. Last))
         then
            return True;
         end if;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return False;
   end Available;

end I18N.Person_Names;
