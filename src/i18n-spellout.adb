with Ada.Strings.Hash;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with I18N.Data_Store;
with I18N.Number_Format;
with I18N.Parent_Locales;
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
      --  Up CLDR's chain: its parent where it names one ("nb" reads "no"),
      --  else the tag less its last subtag.
      function From (Cand : String; Depth : Natural) return String is
         Hit : constant String := I18N.Data_Store.Lookup ("rbnf/" & Cand, "ruleset", Ruleset);
         Parent : constant String := I18N.Parent_Locales.Parent (Cand);
         Cut : Natural := 0;
      begin
         if Hit /= "" or else Depth > 8 then
            return Hit;
         elsif Parent /= "" and then Parent /= "root" and then Parent /= Cand then
            return From (Parent, Depth + 1);
         end if;
         for I in reverse Cand'Range loop
            if Cand (I) = '-' then
               Cut := I;
               exit;
            end if;
         end loop;
         return (if Cut = 0 then "" else From (Cand (Cand'First .. Cut - 1), Depth + 1));
      end From;
   begin
      return From (Norm (Locale), 0);
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
            --  A rule's plural agrees with the count of its divisor, as ICU's
            --  does: 1234 is one thousand ("одна тысяча"), not a few.
            Counted : constant Long_Long_Integer :=
              (if Divisor > 1 then Quotient else Value);
            Cat : constant I18N.Plurals.Plural_Category :=
              (if Ordinal_Kind then I18N.Plurals.Ordinal (Locale, Counted)
               else I18N.Plurals.Cardinal (Locale, Counted));
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
                     --  Decimal-pattern substitution ("=#,##0="): the number
                     --  in the locale's own format, grouping included, as ICU
                     --  writes Tamil "1,000ாவது".
                     declare
                        Img : constant String := Long_Long_Integer'Image (Value);
                        Digits_Text : constant String :=
                          (if Img (Img'First) = ' '
                           then Img (Img'First + 1 .. Img'Last) else Img);
                        Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Number_Format.Format_Into
                          (Value_Text => Digits_Text, Locale => Locale, Style => "",
                           Target => Formatted, Last => Last, Ok => Ok, Overflow => Overflow);
                        Append (Result,
                                (if Ok and then not Overflow and then Last > 0
                                 then Formatted (1 .. Last) else Digits_Text));
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
                  Bar     : Natural := 0;
               begin
                  for K in Content'Range loop
                     if Content (K) = '|' then
                        Bar := K;
                        exit;
                     end if;
                  end loop;
                  --  "[A|B]": A where the number is not an exact multiple of
                  --  the rule's divisor, B where it is (Polish "[sto ->->|
                  --  setny]"), as ICU reads it.
                  if Bar /= 0 then
                     Append (Result,
                             Apply ((if Remainder /= 0 then Content (Content'First .. Bar - 1)
                                     else Content (Bar + 1 .. Content'Last)),
                                    Value, Divisor, Locale, Ruleset, Depth));
                  else
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

   --  The ruleset the rule for Magnitude hands the number to whole --
   --  "1=%spellout-cardinal-sinokorean=" -- or "". Without a negative rule
   --  ICU applies that rule to the signed number, so the delegate's own
   --  negative rule spells the sign.
   function Delegate_For (Serialized : String; Magnitude : Long_Long_Integer) return String is
      Best   : Long_Long_Integer := -1;
      Target : Unbounded_String;
      procedure Find (Base, Text : String) is
         T : constant String := Without_Semi (Text);
      begin
         if Base'Length = 0 or else (for some C of Base => C not in '0' .. '9') then
            return;
         end if;
         declare
            Value : constant Long_Long_Integer := To_Int (Base);
         begin
            if Value <= Magnitude and then Value > Best then
               Best := Value;
               Target :=
                 (if T'Length > 3 and then T (T'First) = '=' and then T (T'First + 1) = '%'
                    and then T (T'Last) = '='
                  then To_Unbounded_String (T (T'First + 1 .. T'Last - 1))
                  else Null_Unbounded_String);
            end if;
         end;
      end Find;
      procedure It is new Iterate_Rules (Find);
   begin
      It (Serialized);
      return To_String (Target);
   end Delegate_For;

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
            elsif Delegate_For (Serialized, -Value) /= "" then
               return Format (Locale, Value, Delegate_For (Serialized, -Value), Depth + 1);
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
         --  The rule before the best, for ICU's roll-back.
         Prev_Base : Long_Long_Integer := -1;
         Prev_Div  : Long_Long_Integer := 1;
         Prev_Text : Unbounded_String;

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
               --  "0.x" and "x.x" are fraction rules, never an integer's.
               if (for some C of Base_Str => C not in '0' .. '9') then
                  return;
               end if;
               if Base_Val <= Value and then Base_Val > Best_Base then
                  Prev_Base := Best_Base;
                  Prev_Div  := Best_Div;
                  Prev_Text := Best_Text;
                  Best_Base := Base_Val;
                  Best_Text := To_Unbounded_String (Text);
                  Found     := True;
                  if Slash /= 0 then
                     --  The largest power of the radix not above the base.
                     declare
                        Radix : constant Long_Long_Integer :=
                          To_Int (Base (Slash + 1 .. Base'Last));
                     begin
                        Best_Div := 1;
                        if Radix > 1 then
                           while Best_Div <= Base_Val / Radix loop
                              Best_Div := Best_Div * Radix;
                           end loop;
                        end if;
                     end;
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
         --  A rule with a remainder substitution whose base is not a
         --  multiple of its divisor (1001) yields an exact multiple (2000)
         --  to the rule before it, as ICU does.
         if Prev_Base >= 0
           and then Best_Div > 1
           and then Value mod Best_Div = 0
           and then Best_Base mod Best_Div /= 0
           and then (for some K in 1 .. Length (Best_Text) =>
                       Is_R (To_String (Best_Text), K))
         then
            Best_Text := Prev_Text;
            Best_Div  := Prev_Div;
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

   function Negative_Words
     (Locale  : String;
      Words   : String;
      Ruleset : String := "%spellout-cardinal")
      return String
   is
      Direct     : constant String := Load (Locale, Ruleset);
      Serialized : constant String :=
        (if Direct = "" and then Ruleset = "%spellout-cardinal"
         then Load (Locale, "%spellout-numbering") else Direct);
      Neg : Unbounded_String;
      procedure Find (Base, Text : String) is
      begin
         if Base = "-x" then
            Neg := To_Unbounded_String (Without_Semi (Text));
         end if;
      end Find;
      procedure It is new Iterate_Rules (Find);
   begin
      if Serialized = "" then
         return "";
      end if;
      It (Serialized);
      --  A magnitude in words has no number left to choose a rule by: the
      --  rule for one stands in, as it hands every count to the same ruleset.
      if Length (Neg) = 0 and then Delegate_For (Serialized, 1) /= ""
        and then Delegate_For (Serialized, 1) /= Ruleset
      then
         return Negative_Words (Locale, Words, Delegate_For (Serialized, 1));
      end if;
      declare
         Rule : constant String := To_String (Neg);
      begin
         --  The magnitude goes where the rule's "->->" stands; a rule that
         --  names another ruleset there is left to Spell.
         for I in Rule'First .. Rule'Last - 5 loop
            if Is_R (Rule, I) and then Is_R (Rule, I + 3) then
               return Rule (Rule'First .. I - 1) & Words & Rule (I + 6 .. Rule'Last);
            end if;
         end loop;
      end;
      return "";
   end Negative_Words;

   function Decimal_Words
     (Locale          : String;
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : String;
      Ruleset         : String := "")
      return String
   is
      Chosen : constant String :=
        (if Ruleset /= "" then Ruleset
         elsif Load (Locale, "%spellout-cardinal") /= "" then "%spellout-cardinal"
         else "%spellout-numbering");
      Serialized : constant String := Load (Locale, Chosen);
      Whole_Rule : Unbounded_String;
      Zero_Rule  : Unbounded_String;
      --  ICU takes the rule whose separator is the locale's decimal mark:
      --  Spanish has "x.x ... punto" and "x,x ... coma", and writes ",".
      Comma : constant Boolean := I18N.Number_Format.Decimal_Separator (Locale) = ",";
      Whole_Comma : Unbounded_String;
      Zero_Comma  : Unbounded_String;
      procedure Find (Base, Text : String) is
      begin
         if Base = "x.x" then
            Whole_Rule := To_Unbounded_String (Without_Semi (Text));
         elsif Base = "0.x" then
            Zero_Rule := To_Unbounded_String (Without_Semi (Text));
         elsif Base = "x,x" then
            Whole_Comma := To_Unbounded_String (Without_Semi (Text));
         elsif Base = "0,x" then
            Zero_Comma := To_Unbounded_String (Without_Semi (Text));
         end if;
      end Find;
      procedure It is new Iterate_Rules (Find);
   begin
      if Serialized = "" then
         return "";
      end if;
      It (Serialized);
      if Comma and then Length (Whole_Comma) > 0 then
         Whole_Rule := Whole_Comma;
      end if;
      if Comma and then Length (Zero_Comma) > 0 then
         Zero_Rule := Zero_Comma;
      end if;
      declare
         Rule : constant String :=
           (if Integer_Part = 0 and then Length (Zero_Rule) > 0 then To_String (Zero_Rule)
            else To_String (Whole_Rule));
         Result : Unbounded_String;
         I      : Natural := Rule'First;

         --  The fraction digit by digit in Digit_Set, Separator between.
         function Fraction (Digit_Set : String; Separator : String) return String is
            Words : Unbounded_String;
         begin
            for Index in Fraction_Digits'Range loop
               declare
                  Word : constant String :=
                    Format (Locale,
                            Long_Long_Integer (Character'Pos (Fraction_Digits (Index)) - Character'Pos ('0')),
                            Digit_Set, 1);
               begin
                  if Word = "" then
                     return "";
                  end if;
                  if Index > Fraction_Digits'First then
                     Append (Words, Separator);
                  end if;
                  Append (Words, Word);
               end;
            end loop;
            return To_String (Words);
         end Fraction;

         --  The fraction as a number over its denominator by Name's rule for
         --  10 ** digits, as ICU reads a fraction ruleset; "" where Name has no
         --  such rule (it reads digit by digit then).
         function Over_Denominator (Name : String) return String is
            Base_Text : constant String := "1" & [1 .. Fraction_Digits'Length => '0'];
            Found     : Unbounded_String;
            procedure Look (Base, Text : String) is
            begin
               if Base = Base_Text and then Length (Found) = 0 then
                  Found := To_Unbounded_String (Without_Semi (Text));
               end if;
            end Look;
            procedure Each is new Iterate_Rules (Look);
            Serialized_Set : constant String := Load (Locale, Name);
         begin
            if Serialized_Set = "" or else Fraction_Digits'Length > 9 then
               return "";
            end if;
            Each (Serialized_Set);
            declare
               Text : constant String := To_String (Found);
               --  Polish writes "<%rs<<": the numerator, then nothing more.
               Trimmed : constant String :=
                 (if Text'Length >= 6 and then Is_L (Text, Text'Last - 2) and then Is_L (Text, Text'Last - 5)
                    and then Text'Length >= 9 and then Is_L (Text, Text'Last - 8) = False
                  then Text (Text'First .. Text'Last - 3) else Text);
               Base : constant Long_Long_Integer := Long_Long_Integer'Value (Base_Text);
               Numerator : constant Long_Long_Integer := Long_Long_Integer'Value (Fraction_Digits);
            begin
               if Text = "" or else (for some C of Text => C = '#' or else C = '0') then
                  return "";
               end if;
               return Apply (Trimmed, Numerator * Base, Base, Locale, Name, 1);
            end;
         end Over_Denominator;

         --  The ruleset a substitution names ("<%rs<"), or the chosen one.
         function Named (From, To : Natural) return String is
           (if To > From then Rule (From .. To) else Chosen);
      begin
         if Rule = "" then
            --  A ruleset that hands numbers on whole names the rule in the
            --  one it hands them to (French, Russian numbering).
            if Delegate_For (Serialized, 1) /= "" and then Delegate_For (Serialized, 1) /= Chosen then
               return Decimal_Words (Locale, Integer_Part, Fraction_Digits, Delegate_For (Serialized, 1));
            end if;
            return "";
         end if;
         --  "=%rs=": the whole number by another ruleset (Russian masculine
         --  hands decimals to the feminine).
         if Rule'Length > 3 and then Rule (Rule'First) = '=' and then Rule (Rule'Last) = '='
           and then Rule (Rule'First + 1) = '%'
           and then Rule (Rule'First + 1 .. Rule'Last - 1) /= Chosen
         then
            return Decimal_Words (Locale, Integer_Part, Fraction_Digits, Rule (Rule'First + 1 .. Rule'Last - 1));
         end if;
         while I <= Rule'Last loop
            if Is_L (Rule, I) then
               declare
                  J : Natural := I + 3;
               begin
                  while J <= Rule'Last and then not Is_L (Rule, J) loop
                     J := J + 1;
                  end loop;
                  if J > Rule'Last then
                     return "";
                  end if;
                  Append (Result, Format (Locale, Integer_Part, Named (I + 3, J - 1), 1));
                  I := J + 3;
               end;
            elsif Is_R (Rule, I) then
               if Is_R (Rule, I + 3) and then Is_R (Rule, I + 6) then
                  --  ">>>": the digits with nothing between (Japanese).
                  Append (Result, Fraction (Chosen, ""));
                  I := I + 9;
               else
                  declare
                     J : Natural := I + 3;
                  begin
                     while J <= Rule'Last and then not Is_R (Rule, J) loop
                        J := J + 1;
                     end loop;
                     if J > Rule'Last then
                        return "";
                     elsif J > I + 3 and then Over_Denominator (Named (I + 3, J - 1)) /= "" then
                        --  A fraction ruleset reads the fraction as a number
                        --  over its denominator: Russian "пять десятых",
                        --  Kazakh "оннан бес".
                        Append (Result, Over_Denominator (Named (I + 3, J - 1)));
                     elsif J > I + 3 then
                        return "";
                     else
                        Append (Result, Fraction (Named (I + 3, J - 1), " "));
                     end if;
                     I := J + 3;
                  end;
               end if;
            elsif Rule (I) = '[' then
               --  Text only a number with a whole part has ("одна целая ...").
               if Integer_Part = 0 then
                  while I <= Rule'Last and then Rule (I) /= ']' loop
                     I := I + 1;
                  end loop;
               end if;
               I := I + 1;
            elsif Rule (I) = ']' then
               I := I + 1;
            elsif Rule (I) = '$' and then I < Rule'Last and then Rule (I + 1) = '(' then
               --  A plural on the whole part: "$(cardinal,one{целая}other{целых})$".
               declare
                  Close : Natural := I + 2;
               begin
                  while Close < Rule'Last and then not (Rule (Close) = ')' and then Rule (Close + 1) = '$') loop
                     Close := Close + 1;
                  end loop;
                  if Close >= Rule'Last then
                     return "";
                  end if;
                  Append (Result, Apply (Rule (I .. Close + 1), Integer_Part, 1, Locale, Chosen, 1));
                  I := Close + 2;
               end;
            elsif Rule (I) in '=' | '$' then
               --  A decimal-pattern substitution: not a spelled form.
               return "";
            else
               Append (Result, Rule (I));
               I := I + 1;
            end if;
         end loop;
         return To_String (Result);
      end;
   end Decimal_Words;

   function Ordinal_Ruleset (Locale : String) return String is
     (if Load (Locale, "%spellout-ordinal") /= "" then "%spellout-ordinal"
      elsif Load (Locale, "%spellout-ordinal-masculine") /= "" then "%spellout-ordinal-masculine"
      elsif Load (Locale, "%spellout-ordinal-common") /= "" then "%spellout-ordinal-common"
      elsif Load (Locale, "%spellout-ordinal-native") /= "" then "%spellout-ordinal-native"
      else "");

   function Ordinal
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "")
      return String
   is
      Chosen : constant String := (if Ruleset = "" then Ordinal_Ruleset (Locale) else Ruleset);
   begin
      return (if Chosen = "" then "" else Format (Locale, Value, Chosen, 0));
   end Ordinal;

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

   --  ------------------------------------------------------------------
   --  Parsing: the rules read backwards, as ICU's RBNF parse does.
   --  ------------------------------------------------------------------

   type Match is record
      Ok    : Boolean := False;
      Value : Long_Long_Integer := 0;
      Next  : Natural := 0;
   end record;

   Soft_Hyphen : constant String := Character'Val (16#C2#) & Character'Val (16#AD#);

   --  The divisor a numeric rule base implies, as Format computes it.
   function Base_Divisor (Base : String) return Long_Long_Integer is
      Slash : Natural := 0;
   begin
      for K in Base'Range loop
         if Base (K) = '/' then
            Slash := K;
         end if;
      end loop;
      declare
         Value : constant Long_Long_Integer :=
           To_Int (if Slash = 0 then Base else Base (Base'First .. Slash - 1));
         Div   : Long_Long_Integer := 1;
      begin
         if Slash /= 0 then
            declare
               Radix : constant Long_Long_Integer := To_Int (Base (Slash + 1 .. Base'Last));
            begin
               if Radix > 1 then
                  while Div <= Value / Radix loop
                     Div := Div * Radix;
                  end loop;
               end if;
            end;
         elsif Value >= 1 then
            Div := 10 ** (Digits_Of (Value) - 1);
         end if;
         return Div;
      end;
   end Base_Divisor;

   --  S indexed from 1, as the matcher restarts a rewritten rule there.
   function From_One (S : String) return String is
      Result : constant String (1 .. S'Length) := S;
   begin
      return Result;
   end From_One;

   procedure Parse
     (Locale   : String;
      Text     : String;
      Value    : out Long_Long_Integer;
      Consumed : out Natural;
      Ruleset  : String := "")
   is
      --  One ruleset's rules, read once per parse.
      type Rule_Entry is record
         Base      : Long_Long_Integer := 0;
         Divisor   : Long_Long_Integer := 1;
         Negative  : Boolean := False;
         Body_Text : Unbounded_String;
      end record;
      package Rule_Vectors is new Ada.Containers.Vectors (Positive, Rule_Entry);
      package Rule_Sets is new Ada.Containers.Indefinite_Hashed_Maps
        (String, Rule_Vectors.Vector, Ada.Strings.Hash, "=", Rule_Vectors."=");
      --  Every way a text can be read from one position: a reading per end.
      package Readings is new Ada.Containers.Vectors (Positive, Match);
      package Memos is new Ada.Containers.Indefinite_Hashed_Maps
        (String, Readings.Vector, Ada.Strings.Hash, "=", Readings."=");
      Sets : Rule_Sets.Map;
      Memo : Memos.Map;
      Plain : Unbounded_String;

      --  Readings that end alike but read different values are both kept:
      --  Irish "dhá" is 2 or, before "mhíle dhéag", 12.
      procedure Add (List : in out Readings.Vector; Item : Match) is
      begin
         for Existing of List loop
            if Existing.Next = Item.Next and then Existing.Value = Item.Value then
               return;
            end if;
         end loop;
         List.Append (Item);
      end Add;

      procedure Add_All (List : in out Readings.Vector; More : Readings.Vector) is
      begin
         for Item of More loop
            Add (List, Item);
         end loop;
      end Add_All;

      function Rules_Of (Set : String) return Rule_Vectors.Vector is
         Rules : Rule_Vectors.Vector;
         procedure Consider (Base, Rule_Text : String) is
            Entry_Item : Rule_Entry;
         begin
            Entry_Item.Body_Text := To_Unbounded_String (Without_Semi (Rule_Text));
            if Base = "-x" then
               Entry_Item.Negative := True;
               Rules.Append (Entry_Item);
            elsif Base'Length > 0 and then (for all C of Base => C in '0' .. '9' | '/') then
               declare
                  Slash : Natural := 0;
               begin
                  for K in Base'Range loop
                     if Base (K) = '/' then
                        Slash := K;
                     end if;
                  end loop;
                  Entry_Item.Base := To_Int (if Slash = 0 then Base else Base (Base'First .. Slash - 1));
                  Entry_Item.Divisor := Base_Divisor (Base);
                  Rules.Append (Entry_Item);
               end;
            end if;
         end Consider;
         procedure It is new Iterate_Rules (Consider);
      begin
         if not Sets.Contains (Set) then
            It (Load (Locale, Set));
            Sets.Insert (Set, Rules);
         end if;
         return Sets.Element (Set);
      end Rules_Of;

      function Parse_Ruleset
        (Set : String; Source : String; Pos : Positive;
         Upper : Long_Long_Integer; Depth : Natural) return Readings.Vector;

      --  Every reading of Rule against Source from Pos: literals verbatim
      --  (quotes and soft hyphens aside), substitutions parsed under ICU's
      --  bound -- below the rule's divisor -- and each of their readings
      --  tried in turn.
      function Match_Rule
        (Set, Rule, Source : String; Pos : Positive;
         Base, Divisor, Upper : Long_Long_Integer; Negative : Boolean; Depth : Natural)
         return Readings.Vector
      is
         function Walk
           (R : String; RI : Positive; TI : Positive;
            Q, Remain, Eq : Long_Long_Integer; Has_Q, Has_Eq : Boolean) return Readings.Vector
         is
            Result : Readings.Vector;
         begin
            if RI > R'Last then
               Result.Append
                 (Match'(Ok    => True,
                   Value => (if Has_Eq then Eq
                             elsif Negative then -Remain
                             elsif Has_Q then Q * Divisor + Remain
                             elsif Remain /= 0 then Base - Base mod Divisor + Remain
                             else Base),
                   Next  => TI));
               return Result;
            elsif RI < R'Last and then R (RI .. RI + 1) = Soft_Hyphen then
               return Walk (R, RI + 2, TI, Q, Remain, Eq, Has_Q, Has_Eq);
            elsif R (RI) = ''' then
               return Walk (R, RI + 1, TI, Q, Remain, Eq, Has_Q, Has_Eq);
            elsif R (RI) = '[' then
               declare
                  Close : Natural := RI + 1;
               begin
                  while Close <= R'Last and then R (Close) /= ']' loop
                     Close := Close + 1;
                  end loop;
                  if Close > R'Last then
                     return Result;
                  end if;
                  declare
                     Inner : constant String := R (RI + 1 .. Close - 1);
                     Rest  : constant String := (if Close < R'Last then R (Close + 1 .. R'Last) else "");
                     Bar   : Natural := 0;
                  begin
                     for K in Inner'Range loop
                        if Inner (K) = '|' then
                           Bar := K;
                        end if;
                     end loop;
                     if Bar /= 0 then
                        Add_All (Result, Walk (From_One (Inner (Inner'First .. Bar - 1) & Rest), 1, TI,
                                               Q, Remain, Eq, Has_Q, Has_Eq));
                        Add_All (Result, Walk (From_One (Inner (Bar + 1 .. Inner'Last) & Rest), 1, TI,
                                               Q, Remain, Eq, Has_Q, Has_Eq));
                     else
                        Add_All (Result, Walk (From_One (Inner & Rest), 1, TI, Q, Remain, Eq, Has_Q, Has_Eq));
                        Add_All (Result, Walk (From_One (Rest & ""), 1, TI, Q, Remain, Eq, Has_Q, Has_Eq));
                     end if;
                     return Result;
                  end;
               end;
            elsif R (RI) = '$' and then RI < R'Last and then R (RI + 1) = '(' then
               --  "$(cardinal,one{tysiąc}few{tysiące}other{tysięcy})$": any form.
               declare
                  Close : Natural := RI + 2;
               begin
                  while Close < R'Last and then not (R (Close) = ')' and then R (Close + 1) = '$') loop
                     Close := Close + 1;
                  end loop;
                  declare
                     Rest : constant String := (if Close + 1 < R'Last then R (Close + 2 .. R'Last) else "");
                     K    : Natural := RI + 2;
                  begin
                     while K < Close loop
                        if R (K) = '{' then
                           declare
                              E : Natural := K + 1;
                           begin
                              while E < Close and then R (E) /= '}' loop
                                 E := E + 1;
                              end loop;
                              Add_All (Result, Walk (From_One (R (K + 1 .. E - 1) & Rest), 1, TI,
                                                     Q, Remain, Eq, Has_Q, Has_Eq));
                              K := E + 1;
                           end;
                        else
                           K := K + 1;
                        end if;
                     end loop;
                     return Result;
                  end;
               end;
            elsif Is_L (R, RI) or else Is_R (R, RI) or else R (RI) = '=' then
               declare
                  Left  : constant Boolean := Is_L (R, RI);
                  Equal : constant Boolean := R (RI) = '=';
                  Width : constant Positive := (if Equal then 1 else 3);
                  J     : Natural := RI + Width;
               begin
                  while J <= R'Last
                    and then not (if Equal then R (J) = '=' elsif Left then Is_L (R, J) else Is_R (R, J))
                  loop
                     J := J + 1;
                  end loop;
                  if J > R'Last then
                     return Result;
                  end if;
                  declare
                     Name   : constant String := R (RI + Width .. J - 1);
                     Target : constant String :=
                       (if Name'Length > 0 and then Name (Name'First) = '%' then Name else Set);
                     Subs   : Readings.Vector;
                     After  : constant Positive := J + Width;
                  begin
                     if Name'Length > 0 and then Name (Name'First) /= '%' then
                        --  A decimal pattern ("=#,##0="): the digits as written.
                        declare
                           E : Natural := TI;
                           V : Long_Long_Integer := 0;
                        begin
                           while E <= Source'Last and then Source (E) in '0' .. '9' | ',' loop
                              if Source (E) /= ',' then
                                 V := V * 10 + Long_Long_Integer (Character'Pos (Source (E)) - Character'Pos ('0'));
                              end if;
                              E := E + 1;
                           end loop;
                           if E > TI then
                              Subs.Append (Match'(Ok => True, Value => V, Next => E));
                           end if;
                        end;
                     else
                        Subs := Parse_Ruleset
                          (Target, Source, TI,
                           (if Negative then Long_Long_Integer'Last
                            elsif Equal then (if Target = Set then Base else Upper)
                            else Divisor),
                           Depth + 1);
                     end if;
                     for Sub of Subs loop
                        if Equal then
                           --  A second "=" writes the same number in another
                           --  part (Irish "=%%prefixpart= =%%thousandp=":
                           --  "dhá" 2, "mhíle dhéag" the teen): each reads a
                           --  bound of it, the larger the number.
                           Add_All (Result, Walk (R, After, Sub.Next, Q, Remain,
                                                  (if Has_Eq then Long_Long_Integer'Max (Eq, Sub.Value)
                                                   else Sub.Value), Has_Q, True));
                        elsif Left then
                           Add_All (Result, Walk (R, After, Sub.Next, Sub.Value, Remain, Eq, True, Has_Eq));
                        else
                           Add_All (Result, Walk (R, After, Sub.Next, Q, Sub.Value, Eq, Has_Q, Has_Eq));
                        end if;
                     end loop;
                     return Result;
                  end;
               end;
            elsif TI <= Source'Last and then Source (TI) = R (RI) then
               return Walk (R, RI + 1, TI + 1, Q, Remain, Eq, Has_Q, Has_Eq);
            end if;
            return Result;
         end Walk;
      begin
         if Depth > Max_Depth or else Rule = "" then
            return Readings.Empty_Vector;
         end if;
         return Walk (From_One (Rule), 1, Pos, 0, 0, 0, False, False);
      end Match_Rule;

      function Parse_Ruleset
        (Set : String; Source : String; Pos : Positive;
         Upper : Long_Long_Integer; Depth : Natural) return Readings.Vector
      is
         Key    : constant String := Set & Pos'Image & Upper'Image;
         Result : Readings.Vector;
      begin
         if Depth > Max_Depth or else Pos > Source'Last then
            return Result;
         elsif Memo.Contains (Key) then
            return Memo.Element (Key);
         end if;
         --  Empty while it runs, so a rule cannot reach itself.
         Memo.Insert (Key, Result);
         for Item of Rules_Of (Set) loop
            if (Item.Negative and then Upper = Long_Long_Integer'Last)
              or else (not Item.Negative and then Item.Base < Upper)
            then
               Add_All (Result,
                        Match_Rule (Set, To_String (Item.Body_Text), Source, Pos,
                                    Item.Base, Item.Divisor, Upper, Item.Negative, Depth));
            end if;
         end loop;
         Memo.Replace (Key, Result);
         return Result;
      end Parse_Ruleset;

      I : Natural := Text'First;
   begin
      --  The text read without its soft hyphens; Consumed counts its bytes.
      while I <= Text'Last loop
         if I < Text'Last and then Text (I .. I + 1) = Soft_Hyphen then
            I := I + 2;
         else
            Append (Plain, Text (I));
            I := I + 1;
         end if;
      end loop;
      declare
         Source : constant String := From_One (To_String (Plain));
         Chosen : constant String :=
           (if Ruleset /= "" then Ruleset
            elsif Load (Locale, "%spellout-cardinal") /= "" then "%spellout-cardinal"
            else "%spellout-numbering");
         --  Unnamed, a number may be written by the cardinal or the numbering
         --  rules (Cantonese spells 10 "十" by the latter): either reading.
         function Both return Readings.Vector is
            Result : Readings.Vector := Parse_Ruleset (Chosen, Source, 1, Long_Long_Integer'Last, 0);
         begin
            if Ruleset = "" and then Chosen /= "%spellout-numbering"
              and then Load (Locale, "%spellout-numbering") /= ""
            then
               Add_All (Result, Parse_Ruleset ("%spellout-numbering", Source, 1, Long_Long_Integer'Last, 0));
            end if;
            return Result;
         end Both;
         All_Readings : constant Readings.Vector :=
           (if Source = "" then Readings.Empty_Vector else Both);
         M : Match;

         function Unhyphenated (Text : String) return String is
            Result : Unbounded_String;
            K      : Natural := Text'First;
         begin
            while K <= Text'Last loop
               if K < Text'Last and then Text (K .. K + 1) = Soft_Hyphen then
                  K := K + 2;
               else
                  Append (Result, Text (K));
                  K := K + 1;
               end if;
            end loop;
            return To_String (Result);
         end Unhyphenated;
      begin
         --  The longest reading; of readings as long, one that spells back to
         --  the text itself.
         for Item of All_Readings loop
            if not M.Ok or else Item.Next > M.Next then
               M := Item;
            end if;
         end loop;
         if M.Ok then
            for Item of All_Readings loop
               if Item.Next = M.Next and then Item.Value /= M.Value
                 and then Unhyphenated (Spell (Locale, M.Value)) /= Source (Source'First .. M.Next - 1)
                 and then Unhyphenated (Spell (Locale, Item.Value)) = Source (Source'First .. Item.Next - 1)
               then
                  M := Item;
               end if;
            end loop;
         end if;
         Value := (if M.Ok then M.Value else 0);
         Consumed := 0;
         if M.Ok then
            --  Back to the caller's bytes, soft hyphens included.
            declare
               Kept : Natural := 0;
               J    : Natural := Text'First;
            begin
               while J <= Text'Last and then Kept < M.Next - 1 loop
                  if J < Text'Last and then Text (J .. J + 1) = Soft_Hyphen then
                     J := J + 2;
                  else
                     Kept := Kept + 1;
                     J := J + 1;
                  end if;
               end loop;
               while J < Text'Last and then Text (J .. J + 1) = Soft_Hyphen loop
                  J := J + 2;
               end loop;
               Consumed := J - Text'First;
            end;
         end if;
      end;
   end Parse;

end I18N.Spellout;
