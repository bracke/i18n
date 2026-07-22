with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with I18N.Data_Store;
with I18N.Plurals;

package body I18N.Spellout is

   Max_Depth : constant := 64;

   --  UTF-8 for the RBNF substitution arrows.
   L1 : constant Character := Character'Val (16#E2#);
   L2 : constant Character := Character'Val (16#86#);
   L3 : constant Character := Character'Val (16#90#);   --  U+2190 <-
   R3 : constant Character := Character'Val (16#92#);   --  U+2192 ->

   function Is_L (T : String; I : Natural) return Boolean is
     (I + 2 <= T'Last and then T (I) = L1 and then T (I + 1) = L2
      and then T (I + 2) = L3);
   function Is_R (T : String; I : Natural) return Boolean is
     (I + 2 <= T'Last and then T (I) = L1 and then T (I + 1) = L2
      and then T (I + 2) = R3);

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

   --  Load a ruleset's serialized rules, walking the locale's parents.
   function Load (Locale, Ruleset : String) return String is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                ("rbnf/" & Cand (Cand'First .. Last), "ruleset", Ruleset);
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
   end Load;

   --  ------------------------------------------------------------------
   --  Rule parsing over the serialized "base US text RS base US text ..."
   --  ------------------------------------------------------------------

   RS : constant Character := Character'Val (16#1E#);
   US : constant Character := Character'Val (16#1F#);

   --  Rule text ends with the ';' terminator; drop it before interpreting.
   function Without_Semi (S : String) return String is
     (if S'Length > 0 and then S (S'Last) = ';' then S (S'First .. S'Last - 1)
      else S);

   generic
      with procedure On_Rule (Base : String; Text : String);
   procedure Iterate_Rules (Serialized : String);

   procedure Iterate_Rules (Serialized : String) is
      I : Natural := Serialized'First;
   begin
      while I <= Serialized'Last loop
         declare
            RS_At : Natural := I;
            US_At : Natural := 0;
         begin
            while RS_At <= Serialized'Last and then Serialized (RS_At) /= RS loop
               if Serialized (RS_At) = US and then US_At = 0 then
                  US_At := RS_At;
               end if;
               RS_At := RS_At + 1;
            end loop;
            if US_At /= 0 then
               On_Rule (Serialized (I .. US_At - 1),
                        Serialized (US_At + 1 .. RS_At - 1));
            end if;
            I := RS_At + 1;
         end;
      end loop;
   end Iterate_Rules;

   --  Value of a decimal string (no sign, no override).
   function To_Int (S : String) return Long_Long_Integer is
      V : Long_Long_Integer := 0;
   begin
      for C of S loop
         exit when C not in '0' .. '9';
         V := V * 10 + Long_Long_Integer (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return V;
   end To_Int;

   function Digits_Of (V : Long_Long_Integer) return Natural is
      N : Natural := 1;
      X : Long_Long_Integer := V;
   begin
      while X >= 10 loop
         X := X / 10;
         N := N + 1;
      end loop;
      return N;
   end Digits_Of;

   --  ------------------------------------------------------------------
   --  Interpreter
   --  ------------------------------------------------------------------

   function Format
     (Locale : String; Value : Long_Long_Integer;
      Ruleset : String; Depth : Natural) return String;

   function Category_Id (C : I18N.Plurals.Plural_Category) return String is
     (case C is
         when I18N.Plurals.Zero => "zero", when I18N.Plurals.One => "one",
         when I18N.Plurals.Two => "two",   when I18N.Plurals.Few => "few",
         when I18N.Plurals.Many => "many", when I18N.Plurals.Other => "other");

   --  Apply a rule's text for Value with the given Divisor.
   function Apply
     (Text : String; Value, Divisor : Long_Long_Integer;
      Locale, Ruleset : String; Depth : Natural) return String
   is
      Result : Unbounded_String;
      I      : Natural := Text'First;

      function Quotient return Long_Long_Integer is
        (if Divisor = 0 then 0 else Value / Divisor);
      function Remainder return Long_Long_Integer is
        (if Divisor = 0 then 0 else Value mod Divisor);

      --  Contents of a plural token "$(type,cat{..}cat{..})$".
      function Plural (Content : String) return String is
         Comma : Natural := Content'First;
         Ordinal_Kind : Boolean;
         Wanted : Unbounded_String;
      begin
         while Comma <= Content'Last and then Content (Comma) /= ',' loop
            Comma := Comma + 1;
         end loop;
         Ordinal_Kind :=
           Comma > Content'First
           and then Content (Content'First .. Comma - 1) = "ordinal";
         declare
            Cat : constant I18N.Plurals.Plural_Category :=
              (if Ordinal_Kind then I18N.Plurals.Ordinal (Locale, Value)
               else I18N.Plurals.Cardinal (Locale, Value));
            Want : constant String := Category_Id (Cat);
            J    : Natural := Comma + 1;
            Other_Text : Unbounded_String;
         begin
            --  Scan "cat{...}" groups.
            while J <= Content'Last loop
               declare
                  Name_Start : constant Natural := J;
                  Brace      : Natural := J;
               begin
                  while Brace <= Content'Last
                    and then Content (Brace) /= '{'
                  loop
                     Brace := Brace + 1;
                  end loop;
                  exit when Brace > Content'Last;
                  declare
                     Name  : constant String :=
                       Content (Name_Start .. Brace - 1);
                     Close : Natural := Brace + 1;
                     Level : Natural := 1;
                  begin
                     while Close <= Content'Last and then Level > 0 loop
                        if Content (Close) = '{' then
                           Level := Level + 1;
                        elsif Content (Close) = '}' then
                           Level := Level - 1;
                        end if;
                        exit when Level = 0;
                        Close := Close + 1;
                     end loop;
                     declare
                        Body_Text : constant String :=
                          Content (Brace + 1 .. Close - 1);
                     begin
                        if Name = Want then
                           Wanted := To_Unbounded_String (Body_Text);
                        elsif Name = "other" then
                           Other_Text := To_Unbounded_String (Body_Text);
                        end if;
                     end;
                     J := Close + 1;
                  end;
               end;
            end loop;
            if Length (Wanted) = 0 then
               Wanted := Other_Text;
            end if;
            return Apply (To_String (Wanted), Value, Divisor,
                          Locale, Ruleset, Depth);
         end;
      end Plural;

   begin
      while I <= Text'Last loop
         if Is_L (Text, I) then
            if Is_L (Text, I + 3) then
               Append (Result, Format (Locale, Quotient, Ruleset, Depth + 1));
               I := I + 6;
            else
               declare
                  J : Natural := I + 3;
               begin
                  while J <= Text'Last and then not Is_L (Text, J) loop
                     J := J + 1;
                  end loop;
                  Append (Result,
                          Format (Locale, Quotient, Text (I + 3 .. J - 1),
                                  Depth + 1));
                  I := J + 3;
               end;
            end if;
         elsif Is_R (Text, I) then
            if Is_R (Text, I + 3) then
               Append (Result, Format (Locale, Remainder, Ruleset, Depth + 1));
               I := I + 6;
            else
               declare
                  J : Natural := I + 3;
               begin
                  while J <= Text'Last and then not Is_R (Text, J) loop
                     J := J + 1;
                  end loop;
                  Append (Result,
                          Format (Locale, Remainder, Text (I + 3 .. J - 1),
                                  Depth + 1));
                  I := J + 3;
               end;
            end if;
         elsif Text (I) = '=' then
            declare
               J : Natural := I + 1;
            begin
               while J <= Text'Last and then Text (J) /= '=' loop
                  J := J + 1;
               end loop;
               declare
                  Content : constant String := Text (I + 1 .. J - 1);
               begin
                  if Content'Length > 0 and then Content (Content'First) = '%'
                  then
                     Append (Result,
                             Format (Locale, Value, Content, Depth + 1));
                  else
                     --  Decimal-pattern substitution: v1 emits the integer.
                     declare
                        Img : constant String := Long_Long_Integer'Image (Value);
                     begin
                        Append (Result,
                                (if Img (Img'First) = ' '
                                 then Img (Img'First + 1 .. Img'Last) else Img));
                     end;
                  end if;
                  I := J + 1;
               end;
            end;
         elsif Text (I) = '[' then
            declare
               J : Natural := I + 1;
            begin
               while J <= Text'Last and then Text (J) /= ']' loop
                  J := J + 1;
               end loop;
               declare
                  Content : constant String := Text (I + 1 .. J - 1);
                  Has_R   : Boolean := False;
                  Has_L   : Boolean := False;
               begin
                  for K in Content'Range loop
                     if Is_R (Content, K) then
                        Has_R := True;
                     elsif Is_L (Content, K) then
                        Has_L := True;
                     end if;
                  end loop;
                  if (Has_R and then Remainder /= 0)
                    or else (Has_L and then not Has_R and then Quotient /= 0)
                    or else (not Has_R and then not Has_L)
                  then
                     Append (Result,
                             Apply (Content, Value, Divisor, Locale, Ruleset,
                                    Depth));
                  end if;
                  I := J + 1;
               end;
            end;
         elsif Text (I) = '$' and then I < Text'Last
           and then Text (I + 1) = '('
         then
            declare
               J : Natural := I + 2;
            begin
               while J < Text'Last
                 and then not (Text (J) = ')' and then Text (J + 1) = '$')
               loop
                  J := J + 1;
               end loop;
               Append (Result, Plural (Text (I + 2 .. J - 1)));
               I := J + 2;
            end;
         elsif Text (I) = ''' then
            I := I + 1;   --  literal-protection quote: drop it
         else
            Append (Result, Text (I));
            I := I + 1;
         end if;
      end loop;
      return To_String (Result);
   end Apply;

   function Format
     (Locale : String; Value : Long_Long_Integer;
      Ruleset : String; Depth : Natural) return String
   is
      Serialized : constant String := Load (Locale, Ruleset);
   begin
      if Depth > Max_Depth or else Serialized = "" then
         return "";
      end if;

      --  Negative: use the -x rule if present.
      if Value < 0 then
         declare
            Neg : Unbounded_String;
            procedure Find (Base, Text : String) is
            begin
               if Base = "-x" then
                  Neg := To_Unbounded_String (Text);
               end if;
            end Find;
            procedure It is new Iterate_Rules (Find);
         begin
            It (Serialized);
            if Value = Long_Long_Integer'First then
               return "";
            elsif Length (Neg) > 0 then
               return Apply (Without_Semi (To_String (Neg)), -Value,
                             Long_Long_Integer'Last, Locale, Ruleset, Depth);
            else
               return "-" & Format (Locale, -Value, Ruleset, Depth + 1);
            end if;
         end;
      end if;

      --  Pick the numeric rule with the largest base <= Value.
      declare
         Best_Base : Long_Long_Integer := -1;
         Best_Div  : Long_Long_Integer := 1;
         Best_Text : Unbounded_String;
         Found     : Boolean := False;

         procedure Consider (Base, Text : String) is
            Slash : Natural := 0;
         begin
            --  Skip special (non-numeric) base tokens.
            if Base'Length = 0
              or else Base (Base'First) not in '0' .. '9'
            then
               return;
            end if;
            for K in Base'Range loop
               if Base (K) = '/' then
                  Slash := K;
                  exit;
               end if;
            end loop;
            declare
               Base_Str : constant String :=
                 (if Slash = 0 then Base else Base (Base'First .. Slash - 1));
               Base_Val : constant Long_Long_Integer := To_Int (Base_Str);
            begin
               if Base_Val <= Value and then Base_Val > Best_Base then
                  Best_Base := Base_Val;
                  Best_Text := To_Unbounded_String (Text);
                  Found     := True;
                  if Slash /= 0 then
                     Best_Div := To_Int (Base (Slash + 1 .. Base'Last));
                  elsif Base_Val >= 1 then
                     Best_Div := 10 ** (Digits_Of (Base_Val) - 1);
                  else
                     Best_Div := 1;
                  end if;
               end if;
            end;
         end Consider;

         procedure It is new Iterate_Rules (Consider);
      begin
         It (Serialized);
         if not Found then
            return "";
         end if;
         declare
            T : constant String := To_String (Best_Text);
            --  Drop a single trailing ';' rule terminator.
            Last : constant Natural :=
              (if T'Length > 0 and then T (T'Last) = ';' then T'Last - 1
               else T'Last);
         begin
            return Apply (T (T'First .. Last), Value, Best_Div,
                          Locale, Ruleset, Depth);
         end;
      end;
   end Format;

   --  ------------------------------------------------------------------
   --  Public
   --  ------------------------------------------------------------------

   function Spell
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "%spellout-cardinal")
      return String
   is
      Direct : constant String := Format (Locale, Value, Ruleset, 0);
   begin
      --  Many locales have no plain %spellout-cardinal (only gendered variants);
      --  fall back to %spellout-numbering, the neutral counting form.
      if Direct = "" and then Ruleset = "%spellout-cardinal" then
         return Format (Locale, Value, "%spellout-numbering", 0);
      end if;
      return Direct;
   end Spell;

   function Ordinal
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "%spellout-ordinal")
      return String
   is (Format (Locale, Value, Ruleset, 0));

   function Available (Locale : String) return Boolean is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         if I18N.Data_Store.Available
              ("rbnf/" & Cand (Cand'First .. Last))
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

end I18N.Spellout;
