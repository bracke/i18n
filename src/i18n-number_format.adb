with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with I18N.CLDR_Data;
with I18N.Data_Store;
with I18N.Plurals;
with I18N.Runtime_Data;

package body I18N.Number_Format is

   type Number_Mode is
     (Decimal_Mode,
      Percent_Mode,
      Permille_Mode,
      Compact_Short_Mode,
      Compact_Long_Mode,
      Scientific_Mode,
      Engineering_Mode,
      Spellout_Mode,
      Ordinal_Words_Mode);

   type Rounding_Mode is
     (Half_Up,
      Half_Even,
      Half_Down,
      Half_Ceiling,
      Half_Floor,
      Down,
      Up,
      Ceiling,
      Floor);
   type Sign_Display is
     (Auto_Sign,
      Always_Sign,
      Except_Zero_Sign,
      Never_Sign,
      Accounting_Sign,
      Accounting_Always_Sign,
      Accounting_Except_Zero_Sign);
   type Decimal_Display is (Auto_Decimal, Always_Decimal);
   type Trailing_Zero_Display is
     (Auto_Trailing_Zero, Strip_If_Integer_Trailing_Zero);
   type Grouping_Display is (No_Grouping, Auto_Grouping, Min_2_Grouping);

   type Number_Style is record
      Mode       : Number_Mode := Decimal_Mode;
      Min_Frac   : Natural := 0;
      Max_Frac   : Natural := Natural'Last;
      Min_Sig    : Natural := 0;
      Sig_Digits : Natural := 0;
      Rounding   : Rounding_Mode := Half_Up;
      Padded     : Natural := 0;
      Sign       : Sign_Display := Auto_Sign;
      Grouping   : Grouping_Display := Auto_Grouping;
      Decimal    : Decimal_Display := Auto_Decimal;
      Trailing   : Trailing_Zero_Display := Auto_Trailing_Zero;
      Scale      : Long_Long_Float := 1.0;
      Increment  : Long_Long_Float := 0.0;
   end record;

   function Language (Locale : String) return String is
   begin
      return I18N.CLDR_Data.Language (Locale);
   end Language;

   function U (Code : Natural) return String is
   begin
      if Code <= 16#7F# then
         return [1 => Character'Val (Code)];
      elsif Code <= 16#7FF# then
         return
           [1 => Character'Val (16#C0# + Code / 64),
            2 => Character'Val (16#80# + Code mod 64)];
      elsif Code <= 16#FFFF# then
         return
           [1 => Character'Val (16#E0# + Code / 4096),
            2 => Character'Val (16#80# + (Code / 64) mod 64),
            3 => Character'Val (16#80# + Code mod 64)];
      else
         return
           [1 => Character'Val (16#F0# + Code / 262144),
            2 => Character'Val (16#80# + (Code / 4096) mod 64),
            3 => Character'Val (16#80# + (Code / 64) mod 64),
            4 => Character'Val (16#80# + Code mod 64)];
      end if;
   end U;

   type Codepoint_Array is array (Positive range <>) of Natural;

   function UTF8 (Codes : Codepoint_Array) return String is
   begin
      if Codes'Length = 0 then
         return "";
      elsif Codes'Length = 1 then
         return U (Codes (Codes'First));
      else
         return
           U (Codes (Codes'First))
           & UTF8 (Codes (Codes'First + 1 .. Codes'Last));
      end if;
   end UTF8;

   --  Base name of the on-the-fly number-symbol data file (I18N.Data_Store
   --  resolves it to "<data-dir>/numbers.i18ndata", loaded lazily on first use).
   Store_File : constant String := "numbers";

   function To_Store_Key (Locale : String) return String is
      Result : String := Locale;
   begin
      for Index in Result'Range loop
         if Result (Index) in 'A' .. 'Z' then
            Result (Index) :=
              Character'Val (Character'Pos (Result (Index)) + 32);
         elsif Result (Index) = '_' then
            Result (Index) := '-';
         end if;
      end loop;
      return Result;
   end To_Store_Key;

   --  Look a symbol field up in the on-the-fly file, with the same
   --  exact -> parent -> root fallback the compiled tables use. Returns "" when
   --  the file, section, or locale (and its parents and root) are all absent.
   function Store_Lookup (Section : String; Locale : String) return String is
      Key : constant String := To_Store_Key (Locale);
      Cut : Natural := Key'Last;
   begin
      declare
         Exact : constant String :=
           I18N.Data_Store.Lookup (Store_File, Section, Key);
      begin
         if Exact /= "" then
            return Exact;
         end if;
      end;

      while Cut > Key'First loop
         if Key (Cut) = '-' then
            declare
               Parent : constant String :=
                 I18N.Data_Store.Lookup
                   (Store_File, Section, Key (Key'First .. Cut - 1));
            begin
               if Parent /= "" then
                  return Parent;
               end if;
            end;
         end if;
         Cut := Cut - 1;
      end loop;

      return I18N.Data_Store.Lookup (Store_File, Section, "root");
   end Store_Lookup;

   --  Resolve a locale symbol field with three tiers, highest priority first:
   --  process-wide runtime overrides, then the on-the-fly data file (present
   --  only when the compiled tables were narrowed via the `locales` config),
   --  then the compiled tables. When no file is installed the middle tier is a
   --  no-op, so behaviour is identical to consulting the compiled tables.
   function Locale_Field
     (Key      : String;
      Locale   : String;
      Compiled : not null access function (L : String) return String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Key, Found);
   begin
      if Found then
         return Value;
      end if;

      if I18N.Data_Store.Available (Store_File) then
         declare
            From_Store : constant String := Store_Lookup (Key, Locale);
         begin
            if From_Store /= "" then
               return From_Store;
            end if;
         end;
      end if;

      return Compiled (Locale);
   end Locale_Field;

   function Decimal_Separator (Locale : String) return String is
     (Locale_Field
        ("decimal_separator", Locale, I18N.CLDR_Data.Decimal_Separator'Access));

   function Group_Separator (Locale : String) return String is
     (Locale_Field
        ("group_separator", Locale, I18N.CLDR_Data.Group_Separator'Access));

   function Uses_Indian_Grouping (Locale : String) return Boolean is
      Found : Boolean;
      Value : constant Boolean :=
        I18N.Runtime_Data.Locale_Boolean
          (Locale, "uses_indian_grouping", Found);
   begin
      return
        (if Found then Value else I18N.CLDR_Data.Uses_Indian_Grouping (Locale));
   end Uses_Indian_Grouping;

   function Number_Percent_Suffix (Locale : String) return String is
     (Locale_Field
        ("number_percent_suffix", Locale,
         I18N.CLDR_Data.Number_Percent_Suffix'Access));

   function Number_Permille_Suffix (Locale : String) return String is
     (Locale_Field
        ("number_permille_suffix", Locale,
         I18N.CLDR_Data.Number_Permille_Suffix'Access));

   function Number_Plus_Sign (Locale : String) return String is
     (Locale_Field
        ("number_plus_sign", Locale, I18N.CLDR_Data.Number_Plus_Sign'Access));

   function Number_Minus_Sign (Locale : String) return String is
     (Locale_Field
        ("number_minus_sign", Locale, I18N.CLDR_Data.Number_Minus_Sign'Access));

   function Number_Accounting_Prefix (Locale : String) return String is
     (Locale_Field
        ("number_accounting_prefix", Locale,
         I18N.CLDR_Data.Number_Accounting_Prefix'Access));

   function Number_Accounting_Suffix (Locale : String) return String is
     (Locale_Field
        ("number_accounting_suffix", Locale,
         I18N.CLDR_Data.Number_Accounting_Suffix'Access));

   function Number_Exponent_Separator (Locale : String) return String is
     (Locale_Field
        ("number_exponent_separator", Locale,
         I18N.CLDR_Data.Number_Exponent_Separator'Access));

   procedure Put
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Text     : String)
   is
   begin
      for C of Text loop
         if Last >= Target'Length then
            Overflow := True;
            return;
         end if;

         Target (Target'First + Last) := C;
         Last := Last + 1;
      end loop;
   end Put;

   procedure Put_Char
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      C        : Character) is
   begin
      Put (Target, Last, Overflow, [1 => C]);
   end Put_Char;

   procedure Put_Digit
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit    : Character)
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Digit_Text (Locale, Digit, Found);
   begin
      Put
        (Target,
         Last,
         Overflow,
         (if Found then Value else I18N.CLDR_Data.Digit_Text (Locale, Digit)));
   end Put_Digit;

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Is_Natural_Text (Text : String) return Boolean is
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if not Is_Digit (C) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Natural_Text;

   function Parse_Integer_Width
     (Text  : String;
      Width : out Natural)
      return Boolean
   is
      Pattern_First : Natural := Text'First;
   begin
      Width := 0;

      if Text'Length = 0 then
         return False;
      end if;

      if Text (Text'First) = '+' or else Text (Text'First) = '*' then
         if Text'Length < 2 then
            return False;
         end if;

         Pattern_First := Text'First + 1;
      end if;

      for Index in Pattern_First .. Text'Last loop
         if Text (Index) = '0' then
            Width := Width + 1;
         elsif Text (Index) = '#' then
            null;
         else
            return False;
         end if;
      end loop;

      return Width in 1 .. 18;
   end Parse_Integer_Width;

   function Natural_Value (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Text loop
         Result := Result * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;
      return Result;
   end Natural_Value;

   function Parse_Spellout_Integer
     (Text     : String;
      Negative : out Boolean;
      Amount   : out Natural)
      return Boolean
   is
      Start : Positive;
      Value : Natural := 0;
   begin
      Negative := False;
      Amount := 0;

      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         Negative := Text (Start) = '-';
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if not Is_Digit (Text (Index)) then
            return False;
         end if;

         Value :=
           Value * 10
           + Character'Pos (Text (Index)) - Character'Pos ('0');
         if Value > 999_999_999 then
            return False;
         end if;
      end loop;

      Amount := Value;
      if Amount = 0 then
         Negative := False;
      end if;
      return True;
   exception
      when Constraint_Error =>
         Negative := False;
         Amount := 0;
      return False;
   end Parse_Spellout_Integer;

   procedure Parse_Spellout_Decimal
     (Text          : String;
      Negative      : out Boolean;
      Integer_Part  : out Natural;
      Fraction_From : out Natural;
      Fraction_To   : out Natural;
      Valid         : out Boolean)
   is
      Start : Natural := Text'First;
      Dot   : Natural := 0;
      Value : Natural := 0;
      Nonzero : Boolean := False;
   begin
      Negative := False;
      Integer_Part := 0;
      Fraction_From := 0;
      Fraction_To := 0;
      Valid := False;

      if Text'Length = 0 then
         return;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         Negative := Text (Start) = '-';
         if Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return;
            end if;
            Dot := Index;
         elsif not Is_Digit (Text (Index)) then
            return;
         elsif Dot = 0 then
            Value :=
              Value * 10
              + Character'Pos (Text (Index)) - Character'Pos ('0');
            if Value > 999_999_999 then
               return;
            end if;
            if Text (Index) /= '0' then
               Nonzero := True;
            end if;
         else
            if Text (Index) /= '0' then
               Nonzero := True;
            end if;
         end if;
      end loop;

      if Dot = 0 or else Dot = Start or else Dot = Text'Last then
         return;
      end if;

      Integer_Part := Value;
      Fraction_From := Dot + 1;
      Fraction_To := Text'Last;
      if not Nonzero then
         Negative := False;
      end if;
      Valid := True;
   exception
      when Constraint_Error =>
         Negative := False;
         Integer_Part := 0;
         Fraction_From := 0;
         Fraction_To := 0;
         Valid := False;
   end Parse_Spellout_Decimal;

   function Parse_Positive_Scale
     (Text   : String;
      Amount : out Long_Long_Float)
      return Boolean
   is
      Dot          : Boolean := False;
      Seen_Digit   : Boolean := False;
      Seen_Nonzero : Boolean := False;
      Divisor      : Long_Long_Float := 1.0;
   begin
      Amount := 0.0;

      if Text'Length = 0 then
         return False;
      end if;

      for Index in Text'Range loop
         if Text (Index) = '.' then
            if Dot or else Index = Text'First or else Index = Text'Last then
               return False;
            end if;

            Dot := True;
         elsif Is_Digit (Text (Index)) then
            Seen_Digit := True;
            if Text (Index) /= '0' then
               Seen_Nonzero := True;
            end if;

            if Dot then
               Divisor := Divisor * 10.0;
               Amount := Amount
                 + Long_Long_Float
                     (Character'Pos (Text (Index)) - Character'Pos ('0'))
                   / Divisor;
            else
               Amount := Amount * 10.0
                 + Long_Long_Float
                     (Character'Pos (Text (Index)) - Character'Pos ('0'));
            end if;
         else
            return False;
         end if;
      end loop;

      return Seen_Digit
        and then Seen_Nonzero
        and then Amount <= 1_000_000.0;
   end Parse_Positive_Scale;

   function Decimal_Fraction_Length (Text : String) return Natural is
      Dot : Natural := 0;
   begin
      for Index in Text'Range loop
         if Text (Index) = '.' then
            Dot := Index;
         end if;
      end loop;

      return (if Dot = 0 then 0 else Text'Last - Dot);
   end Decimal_Fraction_Length;

   function Parse_Fraction_Precision
     (Text : String;
      Min  : out Natural;
      Max  : out Natural)
      return Boolean
   is
      Dash : Natural := 0;
   begin
      Min := 0;
      Max := 0;

      if Text'Length = 0 then
         return False;
      end if;

      for Index in Text'Range loop
         if Text (Index) = '-' then
            if Dash /= 0 then
               return False;
            end if;

            Dash := Index;
         elsif not Is_Digit (Text (Index)) then
            return False;
         end if;
      end loop;

      if Dash = 0 then
         if not Is_Natural_Text (Text) then
            return False;
         end if;

         Min := Natural_Value (Text);
         Max := Min;
      else
         if Dash = Text'First or else Dash = Text'Last then
            return False;
         end if;

         declare
            Min_Text : constant String := Text (Text'First .. Dash - 1);
            Max_Text : constant String := Text (Dash + 1 .. Text'Last);
         begin
            if not Is_Natural_Text (Min_Text)
              or else not Is_Natural_Text (Max_Text)
            then
               return False;
            end if;

            Min := Natural_Value (Min_Text);
            Max := Natural_Value (Max_Text);
         end;
      end if;

      return Max <= 9 and then Min <= Max;
   end Parse_Fraction_Precision;

   function Parse_Significant_Precision
     (Text : String;
      Min  : out Natural;
      Max  : out Natural)
      return Boolean
   is
   begin
      if not Parse_Fraction_Precision (Text, Min, Max) then
         return False;
      end if;

      return Min >= 1;
   end Parse_Significant_Precision;

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Parse_Style (Text : String; Style : out Number_Style)
                         return Boolean is
      function Apply_Token (Token : String) return Boolean is
      begin
         if Token = "" then
            return False;
         elsif Token = "percent" or else Token = "::percent" then
            Style.Mode := Percent_Mode;
            Style.Max_Frac := 0;
         elsif Token = "permille" or else Token = "::permille" then
            Style.Mode := Permille_Mode;
            Style.Max_Frac := 0;
         elsif Token = "compact-short"
           or else Token = "::compact-short"
           or else Token = "compact/short"
           or else Token = "::compact/short"
           or else Token = "notation-compact-short"
           or else Token = "::notation-compact-short"
           or else Token = "notation/compact-short"
           or else Token = "::notation/compact-short"
           or else Token = "notation/compact/short"
           or else Token = "::notation/compact/short"
         then
            Style.Mode := Compact_Short_Mode;
            Style.Max_Frac := 1;
         elsif Token = "compact-long"
           or else Token = "::compact-long"
           or else Token = "compact/long"
           or else Token = "::compact/long"
           or else Token = "notation-compact-long"
           or else Token = "::notation-compact-long"
           or else Token = "notation/compact-long"
           or else Token = "::notation/compact-long"
           or else Token = "notation/compact/long"
           or else Token = "::notation/compact/long"
         then
            Style.Mode := Compact_Long_Mode;
            Style.Max_Frac := 1;
         elsif Token = "scientific"
           or else Token = "::scientific"
           or else Token = "notation-scientific"
           or else Token = "::notation-scientific"
           or else Token = "notation/scientific"
           or else Token = "::notation/scientific"
         then
            Style.Mode := Scientific_Mode;
            Style.Sig_Digits := 3;
         elsif Token = "engineering"
           or else Token = "::engineering"
           or else Token = "notation-engineering"
           or else Token = "::notation-engineering"
           or else Token = "notation/engineering"
           or else Token = "::notation/engineering"
         then
            Style.Mode := Engineering_Mode;
            Style.Sig_Digits := 3;
         elsif Token = "notation-simple"
           or else Token = "::notation-simple"
           or else Token = "notation-standard"
           or else Token = "::notation-standard"
           or else Token = "notation/simple"
           or else Token = "::notation/simple"
           or else Token = "notation/standard"
           or else Token = "::notation/standard"
         then
            Style.Mode := Decimal_Mode;
         elsif Token = "spellout"
           or else Token = "::spellout"
           or else Token = "spellout-cardinal"
           or else Token = "::spellout-cardinal"
           or else Token = "spellout-numbering"
           or else Token = "::spellout-numbering"
           or else Token = "spellout-numbering-year"
           or else Token = "::spellout-numbering-year"
           or else Token = "spellout-year"
           or else Token = "::spellout-year"
           or else Token = "spellout-numbering-verbose"
           or else Token = "::spellout-numbering-verbose"
           or else Token = "spellout-numbering-financial"
           or else Token = "::spellout-numbering-financial"
           or else Token = "spellout-cardinal-verbose"
           or else Token = "::spellout-cardinal-verbose"
           or else Token = "spellout-cardinal-masculine"
           or else Token = "::spellout-cardinal-masculine"
           or else Token = "spellout-cardinal-feminine"
           or else Token = "::spellout-cardinal-feminine"
           or else Token = "spellout-cardinal-neuter"
           or else Token = "::spellout-cardinal-neuter"
         then
            Style.Mode := Spellout_Mode;
         elsif Token = "ordinal-words"
           or else Token = "::ordinal-words"
           or else Token = "spellout-ordinal"
           or else Token = "::spellout-ordinal"
           or else Token = "spellout-ordinal-verbose"
           or else Token = "::spellout-ordinal-verbose"
           or else Token = "spellout-ordinal-masculine"
           or else Token = "::spellout-ordinal-masculine"
           or else Token = "spellout-ordinal-feminine"
           or else Token = "::spellout-ordinal-feminine"
           or else Token = "spellout-ordinal-neuter"
           or else Token = "::spellout-ordinal-neuter"
         then
            Style.Mode := Ordinal_Words_Mode;
         elsif Token = "precision-integer"
           or else Token = "::precision-integer"
           or else Token = "precision/integer"
           or else Token = "::precision/integer"
         then
            Style.Max_Frac := 0;
            Style.Min_Sig := 0;
            Style.Sig_Digits := 0;
         elsif Token = "precision-unlimited"
           or else Token = "::precision-unlimited"
           or else Token = "precision/unlimited"
           or else Token = "::precision/unlimited"
         then
            Style.Min_Frac := 0;
            Style.Max_Frac := Natural'Last;
            Style.Min_Sig := 0;
            Style.Sig_Digits := 0;
         elsif Starts_With (Token, "precision-fraction/")
           or else Starts_With (Token, "::precision-fraction/")
           or else Starts_With (Token, "precision/fraction/")
           or else Starts_With (Token, "::precision/fraction/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::precision-fraction/")
                    or else Starts_With (Token, "::precision/fraction/")
                  then 21 else 19);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  N : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
                  Min : Natural;
                  Max : Natural;
               begin
                  if not Parse_Fraction_Precision (N, Min, Max) then
                     return False;
                  end if;

                  Style.Min_Frac := Min;
                  Style.Max_Frac := Max;
                  Style.Min_Sig := 0;
                  Style.Sig_Digits := 0;
                  return True;
               end;
            end;
         elsif Starts_With (Token, "precision-significant/")
           or else Starts_With (Token, "::precision-significant/")
           or else Starts_With (Token, "precision/significant/")
           or else Starts_With (Token, "::precision/significant/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::precision-significant/")
                    or else Starts_With (Token, "::precision/significant/")
                  then 24 else 22);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  N : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
                  Min : Natural;
                  Max : Natural;
               begin
                  if not Parse_Significant_Precision (N, Min, Max) then
                     return False;
                  end if;

                  Style.Min_Frac := 0;
                  Style.Max_Frac := Natural'Last;
                  Style.Min_Sig := Min;
                  Style.Sig_Digits := Max;
                  return True;
               end;
            end;
         elsif Starts_With (Token, "pad-integer/")
           or else Starts_With (Token, "::pad-integer/")
           or else Starts_With (Token, "padding/integer/")
           or else Starts_With (Token, "::padding/integer/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::padding/integer/") then 18
                  elsif Starts_With (Token, "padding/integer/") then 16
                  elsif Starts_With (Token, "::pad-integer/") then 14
                  else 12);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  N : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
               begin
                  if not Is_Natural_Text (N) then
                     return False;
                  end if;
                  Style.Padded := Natural_Value (N);
                  return Style.Padded <= 18;
               end;
            end;
         elsif Starts_With (Token, "integer-width/")
           or else Starts_With (Token, "::integer-width/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::integer-width/") then 16 else 14);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  Pattern : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
                  Width   : Natural;
               begin
                  if not Parse_Integer_Width (Pattern, Width) then
                     return False;
                  end if;

                  Style.Padded := Width;
               end;
            end;
         elsif Token = "rounding-mode-down"
           or else Token = "::rounding-mode-down"
           or else Token = "rounding-mode/down"
           or else Token = "::rounding-mode/down"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Down;
         elsif Token = "rounding-mode-up"
           or else Token = "::rounding-mode-up"
           or else Token = "rounding-mode/up"
           or else Token = "::rounding-mode/up"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Up;
         elsif Token = "rounding-mode-half-up"
           or else Token = "::rounding-mode-half-up"
           or else Token = "rounding-mode/half-up"
           or else Token = "::rounding-mode/half-up"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Half_Up;
         elsif Token = "rounding-mode-half-even"
           or else Token = "::rounding-mode-half-even"
           or else Token = "rounding-mode/half-even"
           or else Token = "::rounding-mode/half-even"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Half_Even;
         elsif Token = "rounding-mode-half-down"
           or else Token = "::rounding-mode-half-down"
           or else Token = "rounding-mode/half-down"
           or else Token = "::rounding-mode/half-down"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Half_Down;
         elsif Token = "rounding-mode-half-ceiling"
           or else Token = "::rounding-mode-half-ceiling"
           or else Token = "rounding-mode/half-ceiling"
           or else Token = "::rounding-mode/half-ceiling"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Half_Ceiling;
         elsif Token = "rounding-mode-half-floor"
           or else Token = "::rounding-mode-half-floor"
           or else Token = "rounding-mode/half-floor"
           or else Token = "::rounding-mode/half-floor"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Half_Floor;
         elsif Token = "rounding-mode-ceiling"
           or else Token = "::rounding-mode-ceiling"
           or else Token = "rounding-mode/ceiling"
           or else Token = "::rounding-mode/ceiling"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Ceiling;
         elsif Token = "rounding-mode-floor"
           or else Token = "::rounding-mode-floor"
           or else Token = "rounding-mode/floor"
           or else Token = "::rounding-mode/floor"
         then
            if Style.Max_Frac = Natural'Last then
               Style.Max_Frac := 0;
            end if;
            Style.Rounding := Floor;
         elsif Token = "sign-always"
           or else Token = "::sign-always"
           or else Token = "sign/always"
           or else Token = "::sign/always"
           or else Token = "sign-display-always"
           or else Token = "::sign-display-always"
           or else Token = "sign-display/always"
           or else Token = "::sign-display/always"
         then
            Style.Sign := Always_Sign;
         elsif Token = "sign-except-zero"
           or else Token = "::sign-except-zero"
           or else Token = "sign/except-zero"
           or else Token = "::sign/except-zero"
           or else Token = "sign-display-except-zero"
           or else Token = "::sign-display-except-zero"
           or else Token = "sign-display/except-zero"
           or else Token = "::sign-display/except-zero"
         then
            Style.Sign := Except_Zero_Sign;
         elsif Token = "sign-never"
           or else Token = "::sign-never"
           or else Token = "sign/never"
           or else Token = "::sign/never"
           or else Token = "sign-display-never"
           or else Token = "::sign-display-never"
           or else Token = "sign-display/never"
           or else Token = "::sign-display/never"
         then
            Style.Sign := Never_Sign;
         elsif Token = "sign-accounting"
           or else Token = "::sign-accounting"
           or else Token = "sign/accounting"
           or else Token = "::sign/accounting"
           or else Token = "sign-accounting-negative"
           or else Token = "::sign-accounting-negative"
           or else Token = "sign/accounting-negative"
           or else Token = "::sign/accounting-negative"
           or else Token = "sign-display-accounting"
           or else Token = "::sign-display-accounting"
           or else Token = "sign-display-accounting-negative"
           or else Token = "::sign-display-accounting-negative"
           or else Token = "sign-display/accounting"
           or else Token = "::sign-display/accounting"
           or else Token = "sign-display/accounting-negative"
           or else Token = "::sign-display/accounting-negative"
         then
            Style.Sign := Accounting_Sign;
         elsif Token = "sign-accounting-always"
           or else Token = "::sign-accounting-always"
           or else Token = "sign/accounting-always"
           or else Token = "::sign/accounting-always"
           or else Token = "sign-display-accounting-always"
           or else Token = "::sign-display-accounting-always"
           or else Token = "sign-display/accounting-always"
           or else Token = "::sign-display/accounting-always"
         then
            Style.Sign := Accounting_Always_Sign;
         elsif Token = "sign-accounting-except-zero"
           or else Token = "::sign-accounting-except-zero"
           or else Token = "sign/accounting-except-zero"
           or else Token = "::sign/accounting-except-zero"
           or else Token = "sign-display-accounting-except-zero"
           or else Token = "::sign-display-accounting-except-zero"
           or else Token = "sign-display/accounting-except-zero"
           or else Token = "::sign-display/accounting-except-zero"
         then
            Style.Sign := Accounting_Except_Zero_Sign;
         elsif Token = "sign-auto"
           or else Token = "::sign-auto"
           or else Token = "sign/auto"
           or else Token = "::sign/auto"
           or else Token = "sign-negative"
           or else Token = "::sign-negative"
           or else Token = "sign/negative"
           or else Token = "::sign/negative"
           or else Token = "sign-display-auto"
           or else Token = "::sign-display-auto"
           or else Token = "sign-display-negative"
           or else Token = "::sign-display-negative"
           or else Token = "sign-display/auto"
           or else Token = "::sign-display/auto"
           or else Token = "sign-display/negative"
           or else Token = "::sign-display/negative"
         then
            Style.Sign := Auto_Sign;
         elsif Token = "group-off"
           or else Token = "::group-off"
           or else Token = "group/off"
           or else Token = "::group/off"
           or else Token = "grouping-off"
           or else Token = "::grouping-off"
           or else Token = "grouping/off"
           or else Token = "::grouping/off"
         then
            Style.Grouping := No_Grouping;
         elsif Token = "group-auto"
           or else Token = "::group-auto"
           or else Token = "group-on-aligned"
           or else Token = "::group-on-aligned"
           or else Token = "group-thousands"
           or else Token = "::group-thousands"
           or else Token = "grouping-auto"
           or else Token = "::grouping-auto"
           or else Token = "grouping-on-aligned"
           or else Token = "::grouping-on-aligned"
           or else Token = "grouping-thousands"
           or else Token = "::grouping-thousands"
           or else Token = "group/auto"
           or else Token = "::group/auto"
           or else Token = "group/on-aligned"
           or else Token = "::group/on-aligned"
           or else Token = "group/thousands"
           or else Token = "::group/thousands"
           or else Token = "grouping/auto"
           or else Token = "::grouping/auto"
           or else Token = "grouping/on-aligned"
           or else Token = "::grouping/on-aligned"
           or else Token = "grouping/thousands"
           or else Token = "::grouping/thousands"
         then
            Style.Grouping := Auto_Grouping;
         elsif Token = "group-min2"
           or else Token = "::group-min2"
           or else Token = "group/min2"
           or else Token = "::group/min2"
           or else Token = "grouping-min2"
           or else Token = "::grouping-min2"
           or else Token = "grouping/min2"
           or else Token = "::grouping/min2"
         then
            Style.Grouping := Min_2_Grouping;
         elsif Token = "decimal-auto"
           or else Token = "::decimal-auto"
           or else Token = "decimal/auto"
           or else Token = "::decimal/auto"
           or else Token = "decimal-display-auto"
           or else Token = "::decimal-display-auto"
           or else Token = "decimal-display/auto"
           or else Token = "::decimal-display/auto"
         then
            Style.Decimal := Auto_Decimal;
         elsif Token = "decimal-always"
           or else Token = "::decimal-always"
           or else Token = "decimal/always"
           or else Token = "::decimal/always"
           or else Token = "decimal-display-always"
           or else Token = "::decimal-display-always"
           or else Token = "decimal-display/always"
           or else Token = "::decimal-display/always"
         then
            Style.Decimal := Always_Decimal;
         elsif Token = "trailing-zero-display/auto"
           or else Token = "::trailing-zero-display/auto"
           or else Token = "trailing-zero-display-auto"
           or else Token = "::trailing-zero-display-auto"
         then
            Style.Trailing := Auto_Trailing_Zero;
         elsif Token = "trailing-zero-display/stripIfInteger"
           or else Token = "::trailing-zero-display/stripIfInteger"
           or else Token = "trailing-zero-display/strip-if-integer"
           or else Token = "::trailing-zero-display/strip-if-integer"
           or else Token = "trailing-zero-display-stripIfInteger"
           or else Token = "::trailing-zero-display-stripIfInteger"
           or else Token = "trailing-zero-display-strip-if-integer"
           or else Token = "::trailing-zero-display-strip-if-integer"
         then
            Style.Trailing := Strip_If_Integer_Trailing_Zero;
         elsif Starts_With (Token, "scale/")
           or else Starts_With (Token, "::scale/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::scale/") then 8 else 6);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  N : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
                  Amount : Long_Long_Float;
               begin
                  if not Parse_Positive_Scale (N, Amount) then
                     return False;
                  end if;

                  Style.Scale := Amount;
               end;
            end;
         elsif Starts_With (Token, "rounding-increment/")
           or else Starts_With (Token, "::rounding-increment/")
           or else Starts_With (Token, "precision-increment/")
           or else Starts_With (Token, "::precision-increment/")
           or else Starts_With (Token, "rounding/increment/")
           or else Starts_With (Token, "::rounding/increment/")
           or else Starts_With (Token, "precision/increment/")
           or else Starts_With (Token, "::precision/increment/")
         then
            declare
               Prefix_Length : constant Natural :=
                 (if Starts_With (Token, "::rounding-increment/")
                  then 21
                  elsif Starts_With (Token, "rounding-increment/")
                  then 19
                  elsif Starts_With (Token, "::precision-increment/")
                  then 22
                  elsif Starts_With (Token, "precision-increment/")
                  then 20
                  elsif Starts_With (Token, "::rounding/increment/")
                  then 21
                  elsif Starts_With (Token, "rounding/increment/")
                  then 19
                  elsif Starts_With (Token, "::precision/increment/")
                  then 22
                  else 20);
            begin
               if Token'Length = Prefix_Length then
                  return False;
               end if;

               declare
                  N      : constant String :=
                    Token (Token'First + Prefix_Length .. Token'Last);
                  Amount : Long_Long_Float;
                  Width  : constant Natural := Decimal_Fraction_Length (N);
               begin
                  if not Parse_Positive_Scale (N, Amount) then
                     return False;
                  end if;

                  Style.Increment := Amount;
                  Style.Min_Frac := Natural'Max (Style.Min_Frac, Width);
                  Style.Max_Frac :=
                    (if Style.Max_Frac = Natural'Last
                     then Width
                     else Natural'Max (Style.Max_Frac, Width));
                  Style.Min_Sig := 0;
                  Style.Sig_Digits := 0;
               end;
            end;
         else
            return False;
         end if;

         return True;
      end Apply_Token;

      Pos       : Positive;
      Token_End : Natural;
      Saw_Token : Boolean := False;
   begin
      Style :=
        (Mode => Decimal_Mode, Min_Frac => 0, Max_Frac => Natural'Last,
         Min_Sig => 0, Sig_Digits => 0, Rounding => Half_Up, Padded => 0,
         Sign => Auto_Sign, Grouping => Auto_Grouping, Decimal => Auto_Decimal,
         Trailing => Auto_Trailing_Zero, Scale => 1.0, Increment => 0.0);

      if Text = "" then
         return True;
      elsif not Starts_With (Text, "::") then
         return False;
      end if;

      Pos := Text'First + 2;
      while Pos <= Text'Last loop
         while Pos <= Text'Last and then Text (Pos) = ' ' loop
            Pos := Pos + 1;
         end loop;

         exit when Pos > Text'Last;

         Token_End := Pos;
         while Token_End <= Text'Last and then Text (Token_End) /= ' ' loop
            Token_End := Token_End + 1;
         end loop;

         if not Apply_Token (Text (Pos .. Token_End - 1)) then
            return False;
         end if;

         Saw_Token := True;
         Pos := Token_End;
      end loop;

      return Saw_Token;
   end Parse_Style;

   function Is_Valid_Style (Style : String) return Boolean is
      Parsed : Number_Style;
   begin
      return Parse_Style (Style, Parsed);
   end Is_Valid_Style;

   function Power_10 (N : Natural) return Long_Long_Float is
      Result : Long_Long_Float := 1.0;
   begin
      for I in 1 .. N loop
         Result := Result * 10.0;
      end loop;
      return Result;
   end Power_10;

   function Parse_Value
     (Text     : String;
      Value    : out Long_Long_Float;
      Negative : out Boolean;
      Had_Frac : out Boolean;
      Frac_Len : out Natural)
      return Boolean
   is
      Start : Positive;
      Dot   : Natural := 0;
      Acc   : Long_Long_Float := 0.0;
      Scale : Long_Long_Float := 1.0;
   begin
      Value := 0.0;
      Negative := False;
      Had_Frac := False;
      Frac_Len := 0;

      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         Negative := Text (Start) = '-';
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return False;
            end if;
            Dot := Index;
            Had_Frac := True;
         elsif not Is_Digit (Text (Index)) then
            return False;
         elsif Dot = 0 then
            Acc := Acc * 10.0
              + Long_Long_Float
                  (Character'Pos (Text (Index)) - Character'Pos ('0'));
         else
            Scale := Scale * 10.0;
            Frac_Len := Frac_Len + 1;
            Acc := Acc
              + Long_Long_Float
                  (Character'Pos (Text (Index)) - Character'Pos ('0')) / Scale;
         end if;
      end loop;

      if Dot = Start or else Dot = Text'Last then
         return False;
      end if;

      Value := Acc;
      return True;
   end Parse_Value;

   function Rounded_Integer
     (Value : Long_Long_Float;
      Mode  : Rounding_Mode;
      Negative : Boolean)
      return Long_Long_Integer
   is
      Base : constant Long_Long_Integer :=
        Long_Long_Integer (Long_Long_Float'Floor (Value));
      Fraction : constant Long_Long_Float := Value - Long_Long_Float (Base);
      Is_Integer : constant Boolean := Fraction = 0.0;
      Rounded_Up : constant Long_Long_Integer :=
        (if Is_Integer then Base else Base + 1);
      Epsilon : constant Long_Long_Float := 0.000_000_000_1;
   begin
      case Mode is
         when Half_Up =>
            return
              Long_Long_Integer
                (Long_Long_Float'Floor (Value + 0.500_000_000_1));
         when Half_Even =>
            if Fraction > 0.5 + Epsilon then
               return Base + 1;
            elsif Fraction < 0.5 - Epsilon then
               return Base;
            elsif Base mod 2 = 0 then
               return Base;
            else
               return Base + 1;
            end if;
         when Half_Down =>
            if Fraction > 0.5 + Epsilon then
               return Base + 1;
            else
               return Base;
            end if;
         when Half_Ceiling =>
            if Fraction > 0.5 + Epsilon then
               return Base + 1;
            elsif Fraction < 0.5 - Epsilon then
               return Base;
            else
               return (if Negative then Base else Base + 1);
            end if;
         when Half_Floor =>
            if Fraction > 0.5 + Epsilon then
               return Base + 1;
            elsif Fraction < 0.5 - Epsilon then
               return Base;
            else
               return (if Negative then Base + 1 else Base);
            end if;
         when Down =>
            return Base;
         when Up =>
            return Rounded_Up;
         when Ceiling =>
            return (if Negative then Base else Rounded_Up);
         when Floor =>
            return (if Negative then Rounded_Up else Base);
      end case;
   end Rounded_Integer;

   procedure Decimal_Parts
     (Value      : Long_Long_Float;
      Scale      : Natural;
      Mode       : Rounding_Mode;
      Negative   : Boolean;
      Integer    : out Long_Long_Integer;
      Fraction   : out Long_Long_Integer)
   is
      Factor : constant Long_Long_Float := Power_10 (Scale);
      Total  : constant Long_Long_Integer :=
        Rounded_Integer (Value * Factor, Mode, Negative);
      Divisor : constant Long_Long_Integer := Long_Long_Integer (Factor);
   begin
      Integer := Total / Divisor;
      Fraction := Total mod Divisor;
   end Decimal_Parts;

   function Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Integer_Image;

   function Digit_Count (Value : Long_Long_Integer) return Natural is
      V     : Long_Long_Integer := Value;
      Count : Natural := 1;
   begin
      while V >= 10 loop
         V := V / 10;
         Count := Count + 1;
      end loop;

      return Count;
   end Digit_Count;

   function Digit_Count (Value : Long_Long_Float) return Natural is
      V     : Long_Long_Float := (if Value < 1.0 then 1.0 else Value);
      Count : Natural := 1;
   begin
      while V >= 10.0 loop
         V := V / 10.0;
         Count := Count + 1;
      end loop;

      return Count;
   end Digit_Count;

   function Fraction_Leading_Zeroes
     (Fraction : Long_Long_Integer;
      Width    : Natural)
      return Natural
   is
      Divisor : Long_Long_Integer := Long_Long_Integer (Power_10 (Width));
      Rest    : Long_Long_Integer := Fraction;
      Count   : Natural := 0;
   begin
      if Width = 0 or else Fraction = 0 then
         return 0;
      end if;

      for Index in 1 .. Width loop
         Divisor := Divisor / 10;
         exit when Rest / Divisor /= 0;
         Count := Count + 1;
         Rest := Rest mod Divisor;
      end loop;

      return Count;
   end Fraction_Leading_Zeroes;

   procedure Put_Grouped_Integer
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit_Text : String;
      Pad_To   : Natural;
      Grouping : Grouping_Display := Auto_Grouping)
   is
      Group_Sep        : constant String := Group_Separator (Locale);
      Digit_Count      : constant Natural := Natural'Max (Digit_Text'Length, Pad_To);
      Primary_Group    : constant Natural := 3;
      Secondary_Group  : constant Natural :=
        (if Uses_Indian_Grouping (Locale) then 2 else 3);
      First_Group      : Natural;
      Written_In_Group : Natural := 0;
      Remaining        : Natural := Digit_Count;
      Pad_Count        : constant Natural := Digit_Count - Digit_Text'Length;
   begin
      if Grouping = No_Grouping
        or else (Grouping = Min_2_Grouping
                 and then Digit_Count <= Primary_Group + 1)
      then
         for Index in 1 .. Digit_Count loop
            if Index <= Pad_Count then
               Put_Digit (Target, Last, Overflow, Locale, '0');
            else
               Put_Digit
                 (Target, Last, Overflow, Locale,
                  Digit_Text (Digit_Text'First + Index - Pad_Count - 1));
            end if;
         end loop;
         return;
      end if;

      if Digit_Count <= Primary_Group then
         First_Group := Digit_Count;
      else
         First_Group := (Digit_Count - Primary_Group) mod Secondary_Group;
         if First_Group = 0 then
            First_Group := Secondary_Group;
         end if;
      end if;

      for Index in 1 .. Digit_Count loop
         if Index <= Pad_Count then
            Put_Digit (Target, Last, Overflow, Locale, '0');
         else
            Put_Digit
              (Target, Last, Overflow, Locale,
               Digit_Text (Digit_Text'First + Index - Pad_Count - 1));
         end if;

         Written_In_Group := Written_In_Group + 1;
         Remaining := Remaining - 1;
         if Remaining > 0 and then Written_In_Group = First_Group then
            Put (Target, Last, Overflow, Group_Sep);
            Written_In_Group := 0;
            if Remaining > Primary_Group then
               First_Group := Secondary_Group;
            else
               First_Group := Primary_Group;
            end if;
         end if;
      end loop;
   end Put_Grouped_Integer;

   procedure Put_Fraction
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Long_Long_Integer;
      Scale    : Natural)
   is
      Divisor : Long_Long_Integer := Long_Long_Integer (Power_10 (Scale));
      Rest    : Long_Long_Integer := Value;
   begin
      for Index in 1 .. Scale loop
         Divisor := Divisor / 10;
         Put_Digit
           (Target, Last, Overflow, Locale,
            Character'Val
              (Character'Pos ('0') + Integer (Rest / Divisor)));
         Rest := Rest mod Divisor;
      end loop;
   end Put_Fraction;

   function Fraction_Width
     (Style    : Number_Style;
      Value    : Long_Long_Float;
      Had_Frac : Boolean;
      Frac_Len : Natural)
      return Natural
   is
   begin
      if Style.Sig_Digits /= 0 then
         if Value = 0.0 then
            return Style.Sig_Digits - 1;
         elsif Value < 1.0 then
            declare
               V       : Long_Long_Float := Value;
               Leading : Natural := 0;
            begin
               while V < 1.0 loop
                  V := V * 10.0;
                  Leading := Leading + 1;
               end loop;

               return Leading + Style.Sig_Digits - 1;
            end;
         else
            declare
               Int_Digits : constant Natural := Digit_Count (Value);
            begin
               if Style.Sig_Digits > Int_Digits then
                  return Style.Sig_Digits - Int_Digits;
               else
                  return 0;
               end if;
            end;
         end if;
      elsif Style.Max_Frac /= Natural'Last then
         return Style.Max_Frac;
      elsif Had_Frac then
         return Frac_Len;
      elsif Style.Decimal = Always_Decimal then
         return 1;
      else
         return 0;
      end if;
   end Fraction_Width;

   procedure Emit_Decimal
     (Value      : Long_Long_Float;
      Negative   : Boolean;
      Locale     : String;
      Style      : Number_Style;
      Had_Frac   : Boolean;
      Frac_Len   : Natural;
      Suffix      : String;
      Target     : in out String;
      Last       : in out Natural;
      Overflow   : in out Boolean)
   is
      Width : Natural :=
        Fraction_Width (Style, Value, Had_Frac, Frac_Len);
      Display_Value : Long_Long_Float := Value;
      Int_Part  : Long_Long_Integer;
      Frac_Part : Long_Long_Integer;
      Is_Zero   : Boolean;
      Accounting_Negative : Boolean;
   begin
      if Style.Increment > 0.0 then
         Display_Value :=
           Long_Long_Float
             (Rounded_Integer
                (Value / Style.Increment, Style.Rounding, Negative))
           * Style.Increment;
      end if;

      if Style.Sig_Digits /= 0
        and then Digit_Count (Display_Value) > Style.Sig_Digits
      then
         declare
            Shift  : constant Natural :=
              Digit_Count (Display_Value) - Style.Sig_Digits;
            Factor : constant Long_Long_Float := Power_10 (Shift);
         begin
            Int_Part :=
              Rounded_Integer
                (Display_Value / Factor, Style.Rounding, Negative)
              * Long_Long_Integer (Factor);
            Frac_Part := 0;
            Width := 0;
         end;
      else
         Decimal_Parts
           (Display_Value, Width, Style.Rounding, Negative, Int_Part,
            Frac_Part);
      end if;

      if Style.Max_Frac /= Natural'Last then
         while Width > Style.Min_Frac
           and then Frac_Part mod 10 = 0
         loop
            Frac_Part := Frac_Part / 10;
            Width := Width - 1;
         end loop;
      end if;

      if Style.Sig_Digits /= 0 then
         declare
            Int_Digits : constant Natural := Digit_Count (Int_Part);
            Min_Width  : Natural;
         begin
            if Int_Part > 0 then
               Min_Width :=
                 (if Style.Min_Sig > Int_Digits
                  then Style.Min_Sig - Int_Digits
                  else 0);
            elsif Frac_Part = 0 then
               Min_Width :=
                 (if Style.Min_Sig > 0 then Style.Min_Sig - 1 else 0);
            else
               Min_Width :=
                 Fraction_Leading_Zeroes (Frac_Part, Width)
                 + Style.Min_Sig;
            end if;

            while Width > Min_Width
              and then Frac_Part mod 10 = 0
            loop
               Frac_Part := Frac_Part / 10;
               Width := Width - 1;
            end loop;
         end;
      end if;

      if Style.Trailing = Strip_If_Integer_Trailing_Zero
        and then Frac_Part = 0
      then
         Width := 0;
      end if;

      Is_Zero := Int_Part = 0 and then Frac_Part = 0;

      Accounting_Negative :=
        Negative
        and then
          (Style.Sign = Accounting_Sign
           or else Style.Sign = Accounting_Always_Sign
           or else
             (Style.Sign = Accounting_Except_Zero_Sign and then not Is_Zero));

      if Negative then
         if Accounting_Negative then
            Put
              (Target, Last, Overflow,
               Number_Accounting_Prefix (Locale));
         elsif Style.Sign /= Never_Sign
           and then (Style.Sign /= Except_Zero_Sign or else not Is_Zero)
           and then Style.Sign /= Accounting_Sign
           and then Style.Sign /= Accounting_Always_Sign
           and then Style.Sign /= Accounting_Except_Zero_Sign
         then
            Put
              (Target, Last, Overflow,
               Number_Minus_Sign (Locale));
         end if;
      elsif Style.Sign = Always_Sign
        or else (Style.Sign = Except_Zero_Sign and then not Is_Zero)
        or else Style.Sign = Accounting_Always_Sign
        or else
          (Style.Sign = Accounting_Except_Zero_Sign and then not Is_Zero)
      then
         Put
           (Target, Last, Overflow,
            Number_Plus_Sign (Locale));
      end if;

      Put_Grouped_Integer
        (Target, Last, Overflow, Locale, Integer_Image (Int_Part),
         Style.Padded, Style.Grouping);

      if Width > 0 then
         Put (Target, Last, Overflow, Decimal_Separator (Locale));
         Put_Fraction (Target, Last, Overflow, Locale, Frac_Part, Width);
      end if;

      Put (Target, Last, Overflow, Suffix);

      if Accounting_Negative then
         Put
           (Target, Last, Overflow,
            Number_Accounting_Suffix (Locale));
      end if;
   end Emit_Decimal;

   procedure Emit_Compact
     (Value      : Long_Long_Float;
      Negative   : Boolean;
      Locale     : String;
      Long_Form  : Boolean;
      Source     : Number_Style;
      Target     : in out String;
      Last       : in out Natural;
      Overflow   : in out Boolean)
   is
      Lang    : constant String := Language (Locale);
      Divisor : Long_Long_Float := 1.0;
      Scale   : Long_Long_Integer := 1;
      Style   : constant Number_Style :=
        (Mode => Decimal_Mode, Min_Frac => Source.Min_Frac,
         Max_Frac => Source.Max_Frac, Min_Sig => Source.Min_Sig,
         Sig_Digits => Source.Sig_Digits, Rounding => Source.Rounding,
         Padded => Source.Padded, Sign => Source.Sign,
         Grouping => Source.Grouping, Decimal => Source.Decimal,
         Trailing => Source.Trailing, Scale => 1.0,
         Increment => Source.Increment);
   begin
      if Lang = "ja" or else Lang = "zh" or else Lang = "ko" then
         if Value >= 1_000_000_000_000.0 then
            Divisor := 1_000_000_000_000.0;
            Scale := 1_000_000_000_000;
         elsif Value >= 100_000_000.0 then
            Divisor := 100_000_000.0;
            Scale := 100_000_000;
         elsif Value >= 10_000.0 then
            Divisor := 10_000.0;
            Scale := 10_000;
         end if;
      else
         if Value >= 1_000_000_000_000.0 then
            Divisor := 1_000_000_000_000.0;
            Scale := 1_000_000_000_000;
         elsif Value >= 1_000_000_000.0 then
            Divisor := 1_000_000_000.0;
            Scale := 1_000_000_000;
         elsif Value >= 1_000_000.0 then
            Divisor := 1_000_000.0;
            Scale := 1_000_000;
         elsif Value >= 1_000.0 then
            Divisor := 1_000.0;
            Scale := 1_000;
         end if;
      end if;

      if Divisor = 1.0 then
         Emit_Decimal
           (Value, Negative, Locale, Style, False, 0, "", Target, Last,
            Overflow);
      else
         Emit_Decimal
           (Value / Divisor, Negative, Locale, Style, True, 1,
            I18N.CLDR_Data.Number_Compact_Suffix
              (Locale, Scale, Long_Form),
            Target, Last, Overflow);
      end if;
   end Emit_Compact;

   procedure Emit_Exponent
     (Value       : Long_Long_Float;
      Negative    : Boolean;
      Locale      : String;
      Engineering : Boolean;
      Source      : Number_Style;
      Target      : in out String;
      Last        : in out Natural;
      Overflow    : in out Boolean)
   is
      Exponent : Integer := 0;
      Mantissa : Long_Long_Float := Value;
      Style    : Number_Style :=
        (Mode => Decimal_Mode, Min_Frac => 2, Max_Frac => 2,
         Min_Sig => 0, Sig_Digits => 0, Rounding => Half_Up, Padded => 0,
         Sign => Auto_Sign, Grouping => Auto_Grouping, Decimal => Auto_Decimal,
         Trailing => Auto_Trailing_Zero, Scale => 1.0, Increment => 0.0);
   begin
      Style.Sign := Source.Sign;
      Style.Grouping := Source.Grouping;
      Style.Trailing := Source.Trailing;
      Style.Rounding := Source.Rounding;
      Style.Increment := Source.Increment;
      if Source.Max_Frac /= Natural'Last or else Source.Sig_Digits = 0 then
         Style.Min_Frac := Source.Min_Frac;
         Style.Max_Frac := Source.Max_Frac;
         Style.Min_Sig := Source.Min_Sig;
         Style.Sig_Digits := Source.Sig_Digits;
      elsif not Engineering then
         Style.Min_Frac := Source.Min_Frac;
         Style.Max_Frac := Source.Max_Frac;
         Style.Min_Sig := Source.Min_Sig;
         Style.Sig_Digits := Source.Sig_Digits;
      end if;

      if Mantissa = 0.0 then
         Emit_Decimal
           (0.0, Negative, Locale, Style, True, 2, "", Target, Last,
            Overflow);
         Put
           (Target, Last, Overflow,
            Number_Exponent_Separator (Locale));
         Put
           (Target, Last, Overflow,
            Number_Plus_Sign (Locale));
         Put_Char (Target, Last, Overflow, '0');
         return;
      end if;

      while Mantissa >= 10.0 loop
         Mantissa := Mantissa / 10.0;
         Exponent := Exponent + 1;
      end loop;

      while Engineering and then Exponent mod 3 /= 0 loop
         Mantissa := Mantissa * 10.0;
         Exponent := Exponent - 1;
      end loop;

      Emit_Decimal
        (Mantissa, Negative, Locale, Style, True, 2, "", Target, Last,
         Overflow);
      Put
        (Target, Last, Overflow,
         Number_Exponent_Separator (Locale));
      if Exponent >= 0 then
         Put
           (Target, Last, Overflow,
            Number_Plus_Sign (Locale));
      else
         Put
           (Target, Last, Overflow,
            Number_Minus_Sign (Locale));
      end if;
      Put (Target, Last, Overflow,
           Integer_Image (Long_Long_Integer (abs Exponent)));
   end Emit_Exponent;

   function English_Under_20 (Locale : String; Value : Natural) return String is
   begin
      return I18N.CLDR_Data.Spellout_Cardinal_Under_20 (Locale, Value);
   end English_Under_20;

   function English_Tens (Locale : String; Value : Natural) return String is
   begin
      return I18N.CLDR_Data.Spellout_Cardinal_Tens (Locale, Value);
   end English_Tens;

   function English_Number (Locale : String; Value : Natural) return String is
   begin
      if Value < 20 then
         return English_Under_20 (Locale, Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return English_Tens (Locale, Value / 10);
         else
            return
              English_Tens (Locale, Value / 10) & "-"
              & English_Number (Locale, Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return
              English_Number (Locale, Value / 100) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 100);
         else
            return
              English_Number (Locale, Value / 100) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 100) & " "
              & English_Number (Locale, Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return
              English_Number (Locale, Value / 1_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000);
         else
            return
              English_Number (Locale, Value / 1_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000) & " "
              & English_Number (Locale, Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              English_Number (Locale, Value / 1_000_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000_000);
         else
            return
              English_Number (Locale, Value / 1_000_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000_000) & " "
              & English_Number (Locale, Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end English_Number;

   function English_Ordinal_Under_20
     (Locale : String;
      Value  : Natural)
      return String
   is
   begin
      return I18N.CLDR_Data.Spellout_Ordinal_Under_20 (Locale, Value);
   end English_Ordinal_Under_20;

   function English_Ordinal (Locale : String; Value : Natural) return String is
   begin
      if Value < 20 then
         return English_Ordinal_Under_20 (Locale, Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return I18N.CLDR_Data.Spellout_Ordinal_Tens (Locale, Value / 10);
         else
            return
              English_Tens (Locale, Value / 10) & "-"
              & English_Ordinal (Locale, Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return
              English_Number (Locale, Value / 100) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 100, True);
         else
            return
              English_Number (Locale, Value / 100) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 100) & " "
              & English_Ordinal (Locale, Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return
              English_Number (Locale, Value / 1_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000, True);
         else
            return
              English_Number (Locale, Value / 1_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000) & " "
              & English_Ordinal (Locale, Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              English_Number (Locale, Value / 1_000_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name
                  (Locale, 1_000_000, True);
         else
            return
              English_Number (Locale, Value / 1_000_000) & " "
              & I18N.CLDR_Data.Spellout_Scale_Name (Locale, 1_000_000)
              & " " & English_Ordinal (Locale, Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end English_Ordinal;

   function German_Under_20
     (Value      : Natural;
      One_As_Ein : Boolean := False)
      return String
   is
   begin
      case Value is
         when 0 =>
            return "null";
         when 1 =>
            return (if One_As_Ein then "ein" else "eins");
         when 2 =>
            return "zwei";
         when 3 =>
            return "drei";
         when 4 =>
            return "vier";
         when 5 =>
            return "f" & U (16#FC#) & "nf";
         when 6 =>
            return "sechs";
         when 7 =>
            return "sieben";
         when 8 =>
            return "acht";
         when 9 =>
            return "neun";
         when 10 =>
            return "zehn";
         when 11 =>
            return "elf";
         when 12 =>
            return "zw" & U (16#F6#) & "lf";
         when 13 =>
            return "dreizehn";
         when 14 =>
            return "vierzehn";
         when 15 =>
            return "f" & U (16#FC#) & "nfzehn";
         when 16 =>
            return "sechzehn";
         when 17 =>
            return "siebzehn";
         when 18 =>
            return "achtzehn";
         when 19 =>
            return "neunzehn";
         when others =>
            return "";
      end case;
   end German_Under_20;

   function German_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "zwanzig";
         when 3 =>
            return "drei" & U (16#DF#) & "ig";
         when 4 =>
            return "vierzig";
         when 5 =>
            return "f" & U (16#FC#) & "nfzig";
         when 6 =>
            return "sechzig";
         when 7 =>
            return "siebzig";
         when 8 =>
            return "achtzig";
         when 9 =>
            return "neunzig";
         when others =>
            return "";
      end case;
   end German_Tens;

   function German_Number
     (Value      : Natural;
      One_As_Ein : Boolean := False)
      return String
   is
   begin
      if Value < 20 then
         return German_Under_20 (Value, One_As_Ein);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return German_Tens (Value / 10);
         else
            return
              German_Under_20 (Value mod 10, True) & "und"
              & German_Tens (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return German_Number (Value / 100, True) & "hundert";
         else
            return
              German_Number (Value / 100, True) & "hundert"
              & German_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return German_Number (Value / 1_000, True) & "tausend";
         else
            return
              German_Number (Value / 1_000, True) & "tausend"
              & German_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "eine Million";
            else
               return "eine Million " & German_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return German_Number (Value / 1_000_000) & " Millionen";
         else
            return
              German_Number (Value / 1_000_000) & " Millionen "
              & German_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end German_Number;

   function German_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nullte";
         when 1 =>
            return "erste";
         when 2 =>
            return "zweite";
         when 3 =>
            return "dritte";
         when 4 =>
            return "vierte";
         when 5 =>
            return "f" & U (16#FC#) & "nfte";
         when 6 =>
            return "sechste";
         when 7 =>
            return "siebte";
         when 8 =>
            return "achte";
         when 9 =>
            return "neunte";
         when 10 =>
            return "zehnte";
         when 11 =>
            return "elfte";
         when 12 =>
            return "zw" & U (16#F6#) & "lfte";
         when 13 =>
            return "dreizehnte";
         when 14 =>
            return "vierzehnte";
         when 15 =>
            return "f" & U (16#FC#) & "nfzehnte";
         when 16 =>
            return "sechzehnte";
         when 17 =>
            return "siebzehnte";
         when 18 =>
            return "achtzehnte";
         when 19 =>
            return "neunzehnte";
         when others =>
            return "";
      end case;
   end German_Ordinal_Under_20;

   function German_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return German_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return German_Tens (Value / 10) & "ste";
         else
            return
              German_Under_20 (Value mod 10, True) & "und"
              & German_Tens (Value / 10) & "ste";
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return German_Number (Value, True) & "ste";
         else
            return
              German_Number (Value / 100, True) & "hundert"
              & German_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return German_Number (Value, True) & "ste";
         else
            return
              German_Number (Value / 1_000, True) & "tausend"
              & German_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return German_Number (Value / 1_000_000, True) & "millionste";
         elsif Value / 1_000_000 = 1 then
            return "eine Million " & German_Ordinal (Value mod 1_000_000);
         else
            return
              German_Number (Value / 1_000_000) & " Millionen "
              & German_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end German_Ordinal;

   function French_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "z" & U (16#E9#) & "ro";
         when 1 =>
            return "un";
         when 2 =>
            return "deux";
         when 3 =>
            return "trois";
         when 4 =>
            return "quatre";
         when 5 =>
            return "cinq";
         when 6 =>
            return "six";
         when 7 =>
            return "sept";
         when 8 =>
            return "huit";
         when 9 =>
            return "neuf";
         when 10 =>
            return "dix";
         when 11 =>
            return "onze";
         when 12 =>
            return "douze";
         when 13 =>
            return "treize";
         when 14 =>
            return "quatorze";
         when 15 =>
            return "quinze";
         when 16 =>
            return "seize";
         when 17 =>
            return "dix-sept";
         when 18 =>
            return "dix-huit";
         when 19 =>
            return "dix-neuf";
         when others =>
            return "";
      end case;
   end French_Under_20;

   function French_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vingt";
         when 3 =>
            return "trente";
         when 4 =>
            return "quarante";
         when 5 =>
            return "cinquante";
         when 6 =>
            return "soixante";
         when others =>
            return "";
      end case;
   end French_Tens;

   function French_Under_100 (Value : Natural) return String is
   begin
      if Value < 20 then
         return French_Under_20 (Value);
      elsif Value < 70 then
         if Value mod 10 = 0 then
            return French_Tens (Value / 10);
         elsif Value mod 10 = 1 then
            return French_Tens (Value / 10) & " et un";
         else
            return French_Tens (Value / 10) & "-" & French_Under_20 (Value mod 10);
         end if;
      elsif Value < 80 then
         if Value = 71 then
            return "soixante et onze";
         else
            return "soixante-" & French_Under_20 (Value - 60);
         end if;
      elsif Value < 100 then
         if Value = 80 then
            return "quatre-vingts";
         elsif Value < 90 then
            return "quatre-vingt-" & French_Under_20 (Value - 80);
         else
            return "quatre-vingt-" & French_Under_20 (Value - 80);
         end if;
      else
         return "";
      end if;
   end French_Under_100;

   function French_Number (Value : Natural) return String is
   begin
      if Value < 100 then
         return French_Under_100 (Value);
      elsif Value < 1_000 then
         if Value = 100 then
            return "cent";
         elsif Value mod 100 = 0 then
            return French_Number (Value / 100) & " cents";
         elsif Value < 200 then
            return "cent " & French_Number (Value mod 100);
         else
            return
              French_Number (Value / 100) & " cent "
              & French_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mille";
         elsif Value mod 1_000 = 0 then
            return French_Number (Value / 1_000) & " mille";
         elsif Value < 2_000 then
            return "mille " & French_Number (Value mod 1_000);
         else
            return
              French_Number (Value / 1_000) & " mille "
              & French_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "un million";
            else
               return "un million " & French_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return French_Number (Value / 1_000_000) & " millions";
         else
            return
              French_Number (Value / 1_000_000) & " millions "
              & French_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end French_Number;

   function French_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "z" & U (16#E9#) & "roti" & U (16#E8#) & "me";
         when 1 =>
            return "premier";
         when 2 =>
            return "deuxi" & U (16#E8#) & "me";
         when 3 =>
            return "troisi" & U (16#E8#) & "me";
         when 4 =>
            return "quatri" & U (16#E8#) & "me";
         when 5 =>
            return "cinqui" & U (16#E8#) & "me";
         when 6 =>
            return "sixi" & U (16#E8#) & "me";
         when 7 =>
            return "septi" & U (16#E8#) & "me";
         when 8 =>
            return "huiti" & U (16#E8#) & "me";
         when 9 =>
            return "neuvi" & U (16#E8#) & "me";
         when 10 =>
            return "dixi" & U (16#E8#) & "me";
         when 11 =>
            return "onzi" & U (16#E8#) & "me";
         when 12 =>
            return "douzi" & U (16#E8#) & "me";
         when 13 =>
            return "treizi" & U (16#E8#) & "me";
         when 14 =>
            return "quatorzi" & U (16#E8#) & "me";
         when 15 =>
            return "quinzi" & U (16#E8#) & "me";
         when 16 =>
            return "seizi" & U (16#E8#) & "me";
         when 17 =>
            return "dix-septi" & U (16#E8#) & "me";
         when 18 =>
            return "dix-huiti" & U (16#E8#) & "me";
         when 19 =>
            return "dix-neuvi" & U (16#E8#) & "me";
         when others =>
            return "";
      end case;
   end French_Ordinal_Under_20;

   function French_Ordinal (Value : Natural) return String is
      Base : constant String := French_Number (Value);
   begin
      if Value < 20 then
         return French_Ordinal_Under_20 (Value);
      elsif Value mod 100 = 1 and then Value /= 71 and then Value /= 91 then
         return Base & "i" & U (16#E8#) & "me";
      elsif Value mod 10 = 5 then
         return Base (Base'First .. Base'Last - 1) & "qui" & U (16#E8#) & "me";
      elsif Value mod 10 = 9 then
         return Base (Base'First .. Base'Last - 1) & "vi" & U (16#E8#) & "me";
      elsif Base'Length >= 1 and then Base (Base'Last) = 'e' then
         return Base (Base'First .. Base'Last - 1) & "i" & U (16#E8#) & "me";
      elsif Base'Length >= 1 and then Base (Base'Last) = 's' then
         return Base (Base'First .. Base'Last - 1) & "i" & U (16#E8#) & "me";
      else
         return Base & "i" & U (16#E8#) & "me";
      end if;
   end French_Ordinal;

   function Spanish_Under_30 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "cero";
         when 1 =>
            return "uno";
         when 2 =>
            return "dos";
         when 3 =>
            return "tres";
         when 4 =>
            return "cuatro";
         when 5 =>
            return "cinco";
         when 6 =>
            return "seis";
         when 7 =>
            return "siete";
         when 8 =>
            return "ocho";
         when 9 =>
            return "nueve";
         when 10 =>
            return "diez";
         when 11 =>
            return "once";
         when 12 =>
            return "doce";
         when 13 =>
            return "trece";
         when 14 =>
            return "catorce";
         when 15 =>
            return "quince";
         when 16 =>
            return "diecis" & U (16#E9#) & "is";
         when 17 =>
            return "diecisiete";
         when 18 =>
            return "dieciocho";
         when 19 =>
            return "diecinueve";
         when 20 =>
            return "veinte";
         when 21 =>
            return "veintiuno";
         when 22 =>
            return "veintid" & U (16#F3#) & "s";
         when 23 =>
            return "veintitr" & U (16#E9#) & "s";
         when 24 =>
            return "veinticuatro";
         when 25 =>
            return "veinticinco";
         when 26 =>
            return "veintis" & U (16#E9#) & "is";
         when 27 =>
            return "veintisiete";
         when 28 =>
            return "veintiocho";
         when 29 =>
            return "veintinueve";
         when others =>
            return "";
      end case;
   end Spanish_Under_30;

   function Spanish_Tens (Value : Natural) return String is
   begin
      case Value is
         when 3 =>
            return "treinta";
         when 4 =>
            return "cuarenta";
         when 5 =>
            return "cincuenta";
         when 6 =>
            return "sesenta";
         when 7 =>
            return "setenta";
         when 8 =>
            return "ochenta";
         when 9 =>
            return "noventa";
         when others =>
            return "";
      end case;
   end Spanish_Tens;

   function Spanish_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "ciento";
         when 2 =>
            return "doscientos";
         when 3 =>
            return "trescientos";
         when 4 =>
            return "cuatrocientos";
         when 5 =>
            return "quinientos";
         when 6 =>
            return "seiscientos";
         when 7 =>
            return "setecientos";
         when 8 =>
            return "ochocientos";
         when 9 =>
            return "novecientos";
         when others =>
            return "";
      end case;
   end Spanish_Hundreds;

   function Spanish_Number (Value : Natural) return String is
   begin
      if Value < 30 then
         return Spanish_Under_30 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Spanish_Tens (Value / 10);
         else
            return
              Spanish_Tens (Value / 10) & " y "
              & Spanish_Under_30 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value = 100 then
            return "cien";
         elsif Value mod 100 = 0 then
            return Spanish_Hundreds (Value / 100);
         else
            return
              Spanish_Hundreds (Value / 100) & " "
              & Spanish_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mil";
         elsif Value mod 1_000 = 0 then
            return Spanish_Number (Value / 1_000) & " mil";
         elsif Value < 2_000 then
            return "mil " & Spanish_Number (Value mod 1_000);
         else
            return
              Spanish_Number (Value / 1_000) & " mil "
              & Spanish_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "un mill" & U (16#F3#) & "n";
            else
               return
                 "un mill" & U (16#F3#) & "n "
                 & Spanish_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return Spanish_Number (Value / 1_000_000) & " millones";
         else
            return
              Spanish_Number (Value / 1_000_000) & " millones "
              & Spanish_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Spanish_Number;

   function Spanish_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "cero";
         when 1 =>
            return "primero";
         when 2 =>
            return "segundo";
         when 3 =>
            return "tercero";
         when 4 =>
            return "cuarto";
         when 5 =>
            return "quinto";
         when 6 =>
            return "sexto";
         when 7 =>
            return "s" & U (16#E9#) & "ptimo";
         when 8 =>
            return "octavo";
         when 9 =>
            return "noveno";
         when 10 =>
            return "d" & U (16#E9#) & "cimo";
         when 11 =>
            return "und" & U (16#E9#) & "cimo";
         when 12 =>
            return "duod" & U (16#E9#) & "cimo";
         when 13 =>
            return "decimotercero";
         when 14 =>
            return "decimocuarto";
         when 15 =>
            return "decimoquinto";
         when 16 =>
            return "decimosexto";
         when 17 =>
            return "decimos" & U (16#E9#) & "ptimo";
         when 18 =>
            return "decimoctavo";
         when 19 =>
            return "decimonoveno";
         when others =>
            return "";
      end case;
   end Spanish_Ordinal_Under_20;

   function Spanish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vig" & U (16#E9#) & "simo";
         when 3 =>
            return "trig" & U (16#E9#) & "simo";
         when 4 =>
            return "cuadrag" & U (16#E9#) & "simo";
         when 5 =>
            return "quincuag" & U (16#E9#) & "simo";
         when 6 =>
            return "sexag" & U (16#E9#) & "simo";
         when 7 =>
            return "septuag" & U (16#E9#) & "simo";
         when 8 =>
            return "octog" & U (16#E9#) & "simo";
         when 9 =>
            return "nonag" & U (16#E9#) & "simo";
         when others =>
            return "";
      end case;
   end Spanish_Tens_Ordinal;

   function Spanish_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "cent" & U (16#E9#) & "simo";
         when 2 =>
            return "ducent" & U (16#E9#) & "simo";
         when 3 =>
            return "tricent" & U (16#E9#) & "simo";
         when 4 =>
            return "cuadringent" & U (16#E9#) & "simo";
         when 5 =>
            return "quingent" & U (16#E9#) & "simo";
         when 6 =>
            return "sexcent" & U (16#E9#) & "simo";
         when 7 =>
            return "septingent" & U (16#E9#) & "simo";
         when 8 =>
            return "octingent" & U (16#E9#) & "simo";
         when 9 =>
            return "noningent" & U (16#E9#) & "simo";
         when others =>
            return "";
      end case;
   end Spanish_Hundreds_Ordinal;

   function Spanish_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Spanish_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Spanish_Tens_Ordinal (Value / 10);
         else
            return
              Spanish_Tens_Ordinal (Value / 10) & " "
              & Spanish_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Spanish_Hundreds_Ordinal (Value / 100);
         else
            return
              Spanish_Hundreds (Value / 100) & " "
              & Spanish_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mil" & U (16#E9#) & "simo";
         elsif Value mod 1_000 = 0 then
            return
              Spanish_Number (Value / 1_000) & " mil"
              & U (16#E9#) & "simo";
         elsif Value < 2_000 then
            return "mil " & Spanish_Ordinal (Value mod 1_000);
         else
            return
              Spanish_Number (Value / 1_000) & " mil "
              & Spanish_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "millon" & U (16#E9#) & "simo";
         elsif Value mod 1_000_000 = 0 then
            return
              Spanish_Number (Value / 1_000_000) & " millon"
              & U (16#E9#) & "simo";
         elsif Value / 1_000_000 = 1 then
            return
              "un mill" & U (16#F3#) & "n "
              & Spanish_Ordinal (Value mod 1_000_000);
         else
            return
              Spanish_Number (Value / 1_000_000) & " millones "
              & Spanish_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Spanish_Ordinal;

   function Italian_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "uno";
         when 2 =>
            return "due";
         when 3 =>
            return "tre";
         when 4 =>
            return "quattro";
         when 5 =>
            return "cinque";
         when 6 =>
            return "sei";
         when 7 =>
            return "sette";
         when 8 =>
            return "otto";
         when 9 =>
            return "nove";
         when 10 =>
            return "dieci";
         when 11 =>
            return "undici";
         when 12 =>
            return "dodici";
         when 13 =>
            return "tredici";
         when 14 =>
            return "quattordici";
         when 15 =>
            return "quindici";
         when 16 =>
            return "sedici";
         when 17 =>
            return "diciassette";
         when 18 =>
            return "diciotto";
         when 19 =>
            return "diciannove";
         when others =>
            return "";
      end case;
   end Italian_Under_20;

   function Italian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "venti";
         when 3 =>
            return "trenta";
         when 4 =>
            return "quaranta";
         when 5 =>
            return "cinquanta";
         when 6 =>
            return "sessanta";
         when 7 =>
            return "settanta";
         when 8 =>
            return "ottanta";
         when 9 =>
            return "novanta";
         when others =>
            return "";
      end case;
   end Italian_Tens;

   function Italian_Under_100 (Value : Natural) return String is
      Tens : constant String := Italian_Tens (Value / 10);
      Ones : constant Natural := Value mod 10;
   begin
      if Value < 20 then
         return Italian_Under_20 (Value);
      elsif Ones = 0 then
         return Tens;
      elsif Ones = 1 or else Ones = 8 then
         return Tens (Tens'First .. Tens'Last - 1) & Italian_Under_20 (Ones);
      elsif Ones = 3 then
         return Tens & "tr" & U (16#E9#);
      else
         return Tens & Italian_Under_20 (Ones);
      end if;
   end Italian_Under_100;

   function Italian_Number (Value : Natural) return String is
   begin
      if Value < 100 then
         return Italian_Under_100 (Value);
      elsif Value < 1_000 then
         if Value = 100 then
            return "cento";
         elsif Value mod 100 = 0 then
            return Italian_Number (Value / 100) & "cento";
         elsif (Value mod 100) / 10 = 8 then
            return
              Italian_Number (Value / 100) & "cent"
              & Italian_Number (Value mod 100);
         else
            return
              Italian_Number (Value / 100) & "cento"
              & Italian_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mille";
         elsif Value mod 1_000 = 0 then
            return Italian_Number (Value / 1_000) & "mila";
         elsif Value < 2_000 then
            return "mille" & Italian_Number (Value mod 1_000);
         else
            return
              Italian_Number (Value / 1_000) & "mila"
              & Italian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "un milione";
            else
               return
                 "un milione " & Italian_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return Italian_Number (Value / 1_000_000) & " milioni";
         else
            return
              Italian_Number (Value / 1_000_000) & " milioni "
              & Italian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Italian_Number;

   function Italian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "primo";
         when 2 =>
            return "secondo";
         when 3 =>
            return "terzo";
         when 4 =>
            return "quarto";
         when 5 =>
            return "quinto";
         when 6 =>
            return "sesto";
         when 7 =>
            return "settimo";
         when 8 =>
            return "ottavo";
         when 9 =>
            return "nono";
         when 10 =>
            return "decimo";
         when 11 =>
            return "undicesimo";
         when 12 =>
            return "dodicesimo";
         when others =>
            return "";
      end case;
   end Italian_Ordinal_Under_20;

   function Italian_Ordinal (Value : Natural) return String is
      Base : constant String := Italian_Number (Value);
   begin
      if Value < 13 then
         return Italian_Ordinal_Under_20 (Value);
      elsif Value = 1_000 then
         return "millesimo";
      elsif Value = 1_000_000 then
         return "milionesimo";
      elsif Base'Length >= 2
        and then Base (Base'Last - 1 .. Base'Last) = U (16#E9#)
      then
         return Base (Base'First .. Base'Last - 2) & "eesimo";
      elsif Base (Base'Last) = 'a'
        or else Base (Base'Last) = 'e'
        or else Base (Base'Last) = 'i'
        or else Base (Base'Last) = 'o'
      then
         return Base (Base'First .. Base'Last - 1) & "esimo";
      else
         return Base & "esimo";
      end if;
   end Italian_Ordinal;

   function Portuguese_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "um";
         when 2 =>
            return "dois";
         when 3 =>
            return "tr" & U (16#EA#) & "s";
         when 4 =>
            return "quatro";
         when 5 =>
            return "cinco";
         when 6 =>
            return "seis";
         when 7 =>
            return "sete";
         when 8 =>
            return "oito";
         when 9 =>
            return "nove";
         when 10 =>
            return "dez";
         when 11 =>
            return "onze";
         when 12 =>
            return "doze";
         when 13 =>
            return "treze";
         when 14 =>
            return "catorze";
         when 15 =>
            return "quinze";
         when 16 =>
            return "dezesseis";
         when 17 =>
            return "dezessete";
         when 18 =>
            return "dezoito";
         when 19 =>
            return "dezenove";
         when others =>
            return "";
      end case;
   end Portuguese_Under_20;

   function Portuguese_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vinte";
         when 3 =>
            return "trinta";
         when 4 =>
            return "quarenta";
         when 5 =>
            return "cinquenta";
         when 6 =>
            return "sessenta";
         when 7 =>
            return "setenta";
         when 8 =>
            return "oitenta";
         when 9 =>
            return "noventa";
         when others =>
            return "";
      end case;
   end Portuguese_Tens;

   function Portuguese_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "cento";
         when 2 =>
            return "duzentos";
         when 3 =>
            return "trezentos";
         when 4 =>
            return "quatrocentos";
         when 5 =>
            return "quinhentos";
         when 6 =>
            return "seiscentos";
         when 7 =>
            return "setecentos";
         when 8 =>
            return "oitocentos";
         when 9 =>
            return "novecentos";
         when others =>
            return "";
      end case;
   end Portuguese_Hundreds;

   function Portuguese_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Portuguese_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Portuguese_Tens (Value / 10);
         else
            return
              Portuguese_Tens (Value / 10) & " e "
              & Portuguese_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value = 100 then
            return "cem";
         elsif Value mod 100 = 0 then
            return Portuguese_Hundreds (Value / 100);
         else
            return
              Portuguese_Hundreds (Value / 100) & " e "
              & Portuguese_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mil";
         elsif Value mod 1_000 = 0 then
            return Portuguese_Number (Value / 1_000) & " mil";
         elsif Value < 2_000 then
            return "mil " & Portuguese_Number (Value mod 1_000);
         else
            return
              Portuguese_Number (Value / 1_000) & " mil "
              & Portuguese_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "um milh" & U (16#E3#) & "o";
            else
               return
                 "um milh" & U (16#E3#) & "o "
                 & Portuguese_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return
              Portuguese_Number (Value / 1_000_000) & " milh"
              & U (16#F5#) & "es";
         else
            return
              Portuguese_Number (Value / 1_000_000) & " milh"
              & U (16#F5#) & "es "
              & Portuguese_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Portuguese_Number;

   function Portuguese_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "primeiro";
         when 2 =>
            return "segundo";
         when 3 =>
            return "terceiro";
         when 4 =>
            return "quarto";
         when 5 =>
            return "quinto";
         when 6 =>
            return "sexto";
         when 7 =>
            return "s" & U (16#E9#) & "timo";
         when 8 =>
            return "oitavo";
         when 9 =>
            return "nono";
         when 10 =>
            return "d" & U (16#E9#) & "cimo";
         when 11 =>
            return "d" & U (16#E9#) & "cimo primeiro";
         when 12 =>
            return "d" & U (16#E9#) & "cimo segundo";
         when 13 =>
            return "d" & U (16#E9#) & "cimo terceiro";
         when 14 =>
            return "d" & U (16#E9#) & "cimo quarto";
         when 15 =>
            return "d" & U (16#E9#) & "cimo quinto";
         when 16 =>
            return "d" & U (16#E9#) & "cimo sexto";
         when 17 =>
            return "d" & U (16#E9#) & "cimo s" & U (16#E9#) & "timo";
         when 18 =>
            return "d" & U (16#E9#) & "cimo oitavo";
         when 19 =>
            return "d" & U (16#E9#) & "cimo nono";
         when others =>
            return "";
      end case;
   end Portuguese_Ordinal_Under_20;

   function Portuguese_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vig" & U (16#E9#) & "simo";
         when 3 =>
            return "trig" & U (16#E9#) & "simo";
         when 4 =>
            return "quadrag" & U (16#E9#) & "simo";
         when 5 =>
            return "quinquag" & U (16#E9#) & "simo";
         when 6 =>
            return "sexag" & U (16#E9#) & "simo";
         when 7 =>
            return "septuag" & U (16#E9#) & "simo";
         when 8 =>
            return "octog" & U (16#E9#) & "simo";
         when 9 =>
            return "nonag" & U (16#E9#) & "simo";
         when others =>
            return "";
      end case;
   end Portuguese_Tens_Ordinal;

   function Portuguese_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "cent" & U (16#E9#) & "simo";
         when 2 =>
            return "ducent" & U (16#E9#) & "simo";
         when 3 =>
            return "trecent" & U (16#E9#) & "simo";
         when 4 =>
            return "quadringent" & U (16#E9#) & "simo";
         when 5 =>
            return "quingent" & U (16#E9#) & "simo";
         when 6 =>
            return "sexcent" & U (16#E9#) & "simo";
         when 7 =>
            return "septingent" & U (16#E9#) & "simo";
         when 8 =>
            return "octingent" & U (16#E9#) & "simo";
         when 9 =>
            return "nongent" & U (16#E9#) & "simo";
         when others =>
            return "";
      end case;
   end Portuguese_Hundreds_Ordinal;

   function Portuguese_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Portuguese_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Portuguese_Tens_Ordinal (Value / 10);
         else
            return
              Portuguese_Tens_Ordinal (Value / 10) & " "
              & Portuguese_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Portuguese_Hundreds_Ordinal (Value / 100);
         else
            return
              Portuguese_Hundreds (Value / 100) & " "
              & Portuguese_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mil" & U (16#E9#) & "simo";
         elsif Value mod 1_000 = 0 then
            return
              Portuguese_Number (Value / 1_000) & " mil"
              & U (16#E9#) & "simo";
         elsif Value < 2_000 then
            return "mil " & Portuguese_Ordinal (Value mod 1_000);
         else
            return
              Portuguese_Number (Value / 1_000) & " mil "
              & Portuguese_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "milion" & U (16#E9#) & "simo";
         elsif Value mod 1_000_000 = 0 then
            return
              Portuguese_Number (Value / 1_000_000) & " milion"
              & U (16#E9#) & "simo";
         elsif Value / 1_000_000 = 1 then
            return
              "um milh" & U (16#E3#) & "o "
              & Portuguese_Ordinal (Value mod 1_000_000);
         else
            return
              Portuguese_Number (Value / 1_000_000) & " milh"
              & U (16#F5#) & "es "
              & Portuguese_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Portuguese_Ordinal;

   function Dutch_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nul";
         when 1 =>
            return "een";
         when 2 =>
            return "twee";
         when 3 =>
            return "drie";
         when 4 =>
            return "vier";
         when 5 =>
            return "vijf";
         when 6 =>
            return "zes";
         when 7 =>
            return "zeven";
         when 8 =>
            return "acht";
         when 9 =>
            return "negen";
         when 10 =>
            return "tien";
         when 11 =>
            return "elf";
         when 12 =>
            return "twaalf";
         when 13 =>
            return "dertien";
         when 14 =>
            return "veertien";
         when 15 =>
            return "vijftien";
         when 16 =>
            return "zestien";
         when 17 =>
            return "zeventien";
         when 18 =>
            return "achttien";
         when 19 =>
            return "negentien";
         when others =>
            return "";
      end case;
   end Dutch_Under_20;

   function Dutch_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "twintig";
         when 3 =>
            return "dertig";
         when 4 =>
            return "veertig";
         when 5 =>
            return "vijftig";
         when 6 =>
            return "zestig";
         when 7 =>
            return "zeventig";
         when 8 =>
            return "tachtig";
         when 9 =>
            return "negentig";
         when others =>
            return "";
      end case;
   end Dutch_Tens;

   function Dutch_Ones_Before_Tens (Value : Natural) return String is
   begin
      if Value = 2 or else Value = 3 then
         return Dutch_Under_20 (Value) & U (16#EB#) & "n";
      else
         return Dutch_Under_20 (Value) & "en";
      end if;
   end Dutch_Ones_Before_Tens;

   function Dutch_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Dutch_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Dutch_Tens (Value / 10);
         else
            return
              Dutch_Ones_Before_Tens (Value mod 10)
              & Dutch_Tens (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value = 100 then
            return "honderd";
         elsif Value mod 100 = 0 then
            return Dutch_Number (Value / 100) & "honderd";
         elsif Value < 200 then
            return "honderd " & Dutch_Number (Value mod 100);
         else
            return
              Dutch_Number (Value / 100) & "honderd "
              & Dutch_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "duizend";
         elsif Value mod 1_000 = 0 then
            return Dutch_Number (Value / 1_000) & "duizend";
         elsif Value < 2_000 then
            return "duizend " & Dutch_Number (Value mod 1_000);
         else
            return
              Dutch_Number (Value / 1_000) & "duizend "
              & Dutch_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value / 1_000_000 = 1 then
            if Value mod 1_000_000 = 0 then
               return "een miljoen";
            else
               return "een miljoen " & Dutch_Number (Value mod 1_000_000);
            end if;
         elsif Value mod 1_000_000 = 0 then
            return Dutch_Number (Value / 1_000_000) & " miljoen";
         else
            return
              Dutch_Number (Value / 1_000_000) & " miljoen "
              & Dutch_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Dutch_Number;

   function Dutch_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nulde";
         when 1 =>
            return "eerste";
         when 2 =>
            return "tweede";
         when 3 =>
            return "derde";
         when 4 =>
            return "vierde";
         when 5 =>
            return "vijfde";
         when 6 =>
            return "zesde";
         when 7 =>
            return "zevende";
         when 8 =>
            return "achtste";
         when 9 =>
            return "negende";
         when 10 =>
            return "tiende";
         when 11 =>
            return "elfde";
         when 12 =>
            return "twaalfde";
         when 13 =>
            return "dertiende";
         when 14 =>
            return "veertiende";
         when 15 =>
            return "vijftiende";
         when 16 =>
            return "zestiende";
         when 17 =>
            return "zeventiende";
         when 18 =>
            return "achttiende";
         when 19 =>
            return "negentiende";
         when others =>
            return "";
      end case;
   end Dutch_Ordinal_Under_20;

   function Dutch_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Dutch_Ordinal_Under_20 (Value);
      elsif Value <= 999_999_999 then
         return Dutch_Number (Value) & "ste";
      else
         return "";
      end if;
   end Dutch_Ordinal;

   function Polish_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "jeden";
         when 2 =>
            return "dwa";
         when 3 =>
            return "trzy";
         when 4 =>
            return "cztery";
         when 5 =>
            return "pi" & U (16#119#) & U (16#107#);
         when 6 =>
            return "sze" & U (16#15B#) & U (16#107#);
         when 7 =>
            return "siedem";
         when 8 =>
            return "osiem";
         when 9 =>
            return "dziewi" & U (16#119#) & U (16#107#);
         when 10 =>
            return "dziesi" & U (16#119#) & U (16#107#);
         when 11 =>
            return "jedena" & U (16#15B#) & "cie";
         when 12 =>
            return "dwana" & U (16#15B#) & "cie";
         when 13 =>
            return "trzyna" & U (16#15B#) & "cie";
         when 14 =>
            return "czterna" & U (16#15B#) & "cie";
         when 15 =>
            return "pi" & U (16#119#) & "tna" & U (16#15B#) & "cie";
         when 16 =>
            return "szesna" & U (16#15B#) & "cie";
         when 17 =>
            return "siedemna" & U (16#15B#) & "cie";
         when 18 =>
            return "osiemna" & U (16#15B#) & "cie";
         when 19 =>
            return
              "dziewi" & U (16#119#) & "tna" & U (16#15B#) & "cie";
         when others =>
            return "";
      end case;
   end Polish_Under_20;

   function Polish_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dwadzie" & U (16#15B#) & "cia";
         when 3 =>
            return "trzydzie" & U (16#15B#) & "ci";
         when 4 =>
            return "czterdzie" & U (16#15B#) & "ci";
         when 5 =>
            return
              "pi" & U (16#119#) & U (16#107#) & "dziesi"
              & U (16#105#) & "t";
         when 6 =>
            return
              "sze" & U (16#15B#) & U (16#107#) & "dziesi"
              & U (16#105#) & "t";
         when 7 =>
            return "siedemdziesi" & U (16#105#) & "t";
         when 8 =>
            return "osiemdziesi" & U (16#105#) & "t";
         when 9 =>
            return
              "dziewi" & U (16#119#) & U (16#107#) & "dziesi"
              & U (16#105#) & "t";
         when others =>
            return "";
      end case;
   end Polish_Tens;

   function Polish_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "sto";
         when 2 =>
            return "dwie" & U (16#15B#) & "cie";
         when 3 =>
            return "trzysta";
         when 4 =>
            return "czterysta";
         when 5 =>
            return "pi" & U (16#119#) & U (16#107#) & "set";
         when 6 =>
            return "sze" & U (16#15B#) & U (16#107#) & "set";
         when 7 =>
            return "siedemset";
         when 8 =>
            return "osiemset";
         when 9 =>
            return "dziewi" & U (16#119#) & U (16#107#) & "set";
         when others =>
            return "";
      end case;
   end Polish_Hundreds;

   function Polish_Scale_Form
     (Count    : Natural;
      Singular : String;
      Few      : String;
      Many     : String)
      return String
   is
      Last_Two : constant Natural := Count mod 100;
      Last_One : constant Natural := Count mod 10;
   begin
      if Count = 1 then
         return Singular;
      elsif Last_One in 2 .. 4 and then not (Last_Two in 12 .. 14) then
         return Few;
      else
         return Many;
      end if;
   end Polish_Scale_Form;

   function Polish_Thousands_Form (Count : Natural) return String is
   begin
      return
        Polish_Scale_Form
          (Count, "tysi" & U (16#105#) & "c",
           "tysi" & U (16#105#) & "ce",
           "tysi" & U (16#119#) & "cy");
   end Polish_Thousands_Form;

   function Polish_Millions_Form (Count : Natural) return String is
   begin
      return
        Polish_Scale_Form
          (Count, "milion", "miliony", "milion" & U (16#F3#) & "w");
   end Polish_Millions_Form;

   function Polish_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Polish_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Polish_Tens (Value / 10);
         else
            return
              Polish_Tens (Value / 10) & " "
              & Polish_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Polish_Hundreds (Value / 100);
         else
            return
              Polish_Hundreds (Value / 100) & " "
              & Polish_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Polish_Thousands_Form (1);
         elsif Value mod 1_000 = 0 then
            return
              Polish_Number (Value / 1_000) & " "
              & Polish_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return
              Polish_Thousands_Form (1) & " "
              & Polish_Number (Value mod 1_000);
         else
            return
              Polish_Number (Value / 1_000) & " "
              & Polish_Thousands_Form (Value / 1_000) & " "
              & Polish_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              Polish_Number (Value / 1_000_000) & " "
              & Polish_Millions_Form (Value / 1_000_000);
         else
            return
              Polish_Number (Value / 1_000_000) & " "
              & Polish_Millions_Form (Value / 1_000_000) & " "
              & Polish_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Polish_Number;

   function Polish_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zerowy";
         when 1 =>
            return "pierwszy";
         when 2 =>
            return "drugi";
         when 3 =>
            return "trzeci";
         when 4 =>
            return "czwarty";
         when 5 =>
            return "pi" & U (16#105#) & "ty";
         when 6 =>
            return "sz" & U (16#F3#) & "sty";
         when 7 =>
            return "si" & U (16#F3#) & "dmy";
         when 8 =>
            return U (16#F3#) & "smy";
         when 9 =>
            return "dziewi" & U (16#105#) & "ty";
         when 10 =>
            return "dziesi" & U (16#105#) & "ty";
         when 11 =>
            return "jedenasty";
         when 12 =>
            return "dwunasty";
         when 13 =>
            return "trzynasty";
         when 14 =>
            return "czternasty";
         when 15 =>
            return "pi" & U (16#119#) & "tnasty";
         when 16 =>
            return "szesnasty";
         when 17 =>
            return "siedemnasty";
         when 18 =>
            return "osiemnasty";
         when 19 =>
            return "dziewi" & U (16#119#) & "tnasty";
         when others =>
            return "";
      end case;
   end Polish_Ordinal_Under_20;

   function Polish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dwudziesty";
         when 3 =>
            return "trzydziesty";
         when 4 =>
            return "czterdziesty";
         when 5 =>
            return
              "pi" & U (16#119#) & U (16#107#) & "dziesi"
              & U (16#105#) & "ty";
         when 6 =>
            return
              "sze" & U (16#15B#) & U (16#107#) & "dziesi"
              & U (16#105#) & "ty";
         when 7 =>
            return "siedemdziesi" & U (16#105#) & "ty";
         when 8 =>
            return "osiemdziesi" & U (16#105#) & "ty";
         when 9 =>
            return
              "dziewi" & U (16#119#) & U (16#107#) & "dziesi"
              & U (16#105#) & "ty";
         when others =>
            return "";
      end case;
   end Polish_Tens_Ordinal;

   function Polish_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "setny";
         when 2 =>
            return "dwusetny";
         when 3 =>
            return "trzechsetny";
         when 4 =>
            return "czterysetny";
         when 5 =>
            return "pi" & U (16#119#) & U (16#107#) & "setny";
         when 6 =>
            return "sze" & U (16#15B#) & U (16#107#) & "setny";
         when 7 =>
            return "siedemsetny";
         when 8 =>
            return "osiemsetny";
         when 9 =>
            return "dziewi" & U (16#119#) & U (16#107#) & "setny";
         when others =>
            return "";
      end case;
   end Polish_Hundreds_Ordinal;

   function Polish_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Polish_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Polish_Tens_Ordinal (Value / 10);
         else
            return
              Polish_Tens_Ordinal (Value / 10) & " "
              & Polish_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Polish_Hundreds_Ordinal (Value / 100);
         else
            return
              Polish_Hundreds (Value / 100) & " "
              & Polish_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "tysi" & U (16#119#) & "czny";
         elsif Value mod 1_000 = 0 then
            return Polish_Number (Value / 1_000) & " tysi" & U (16#119#) & "czny";
         elsif Value < 2_000 then
            return Polish_Thousands_Form (1) & " " & Polish_Ordinal (Value mod 1_000);
         else
            return
              Polish_Number (Value / 1_000) & " "
              & Polish_Thousands_Form (Value / 1_000) & " "
              & Polish_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "milionowy";
         elsif Value mod 1_000_000 = 0 then
            return Polish_Number (Value / 1_000_000) & " milionowy";
         else
            return
              Polish_Number (Value / 1_000_000) & " "
              & Polish_Millions_Form (Value / 1_000_000) & " "
              & Polish_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Polish_Ordinal;

   function Czech_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nula";
         when 1 =>
            return "jeden";
         when 2 =>
            return "dva";
         when 3 =>
            return "t" & U (16#159#) & "i";
         when 4 =>
            return U (16#10D#) & "ty" & U (16#159#) & "i";
         when 5 =>
            return "p" & U (16#11B#) & "t";
         when 6 =>
            return U (16#161#) & "est";
         when 7 =>
            return "sedm";
         when 8 =>
            return "osm";
         when 9 =>
            return "dev" & U (16#11B#) & "t";
         when 10 =>
            return "deset";
         when 11 =>
            return "jeden" & U (16#E1#) & "ct";
         when 12 =>
            return "dvan" & U (16#E1#) & "ct";
         when 13 =>
            return "t" & U (16#159#) & "in" & U (16#E1#) & "ct";
         when 14 =>
            return U (16#10D#) & "trn" & U (16#E1#) & "ct";
         when 15 =>
            return "patn" & U (16#E1#) & "ct";
         when 16 =>
            return U (16#161#) & "estn" & U (16#E1#) & "ct";
         when 17 =>
            return "sedmn" & U (16#E1#) & "ct";
         when 18 =>
            return "osmn" & U (16#E1#) & "ct";
         when 19 =>
            return "devaten" & U (16#E1#) & "ct";
         when others =>
            return "";
      end case;
   end Czech_Under_20;

   function Czech_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dvacet";
         when 3 =>
            return "t" & U (16#159#) & "icet";
         when 4 =>
            return U (16#10D#) & "ty" & U (16#159#) & "icet";
         when 5 =>
            return "pades" & U (16#E1#) & "t";
         when 6 =>
            return U (16#161#) & "edes" & U (16#E1#) & "t";
         when 7 =>
            return "sedmdes" & U (16#E1#) & "t";
         when 8 =>
            return "osmdes" & U (16#E1#) & "t";
         when 9 =>
            return "devades" & U (16#E1#) & "t";
         when others =>
            return "";
      end case;
   end Czech_Tens;

   function Czech_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "sto";
         when 2 =>
            return "dv" & U (16#11B#) & " st" & U (16#11B#);
         when 3 =>
            return "t" & U (16#159#) & "i sta";
         when 4 =>
            return U (16#10D#) & "ty" & U (16#159#) & "i sta";
         when 5 =>
            return "p" & U (16#11B#) & "t set";
         when 6 =>
            return U (16#161#) & "est set";
         when 7 =>
            return "sedm set";
         when 8 =>
            return "osm set";
         when 9 =>
            return "dev" & U (16#11B#) & "t set";
         when others =>
            return "";
      end case;
   end Czech_Hundreds;

   function Czech_Scale_Form
     (Count    : Natural;
      Singular : String;
      Few      : String;
      Many     : String)
      return String
   is
   begin
      if Count = 1 then
         return Singular;
      elsif Count in 2 .. 4 then
         return Few;
      else
         return Many;
      end if;
   end Czech_Scale_Form;

   function Czech_Thousands_Form (Count : Natural) return String is
   begin
      return
        Czech_Scale_Form
          (Count, "tis" & U (16#ED#) & "c",
           "tis" & U (16#ED#) & "ce",
           "tis" & U (16#ED#) & "c");
   end Czech_Thousands_Form;

   function Czech_Millions_Form (Count : Natural) return String is
   begin
      return
        Czech_Scale_Form
          (Count, "milion", "miliony", "milion" & U (16#16F#));
   end Czech_Millions_Form;

   function Czech_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Czech_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Czech_Tens (Value / 10);
         else
            return Czech_Tens (Value / 10) & " " & Czech_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Czech_Hundreds (Value / 100);
         else
            return
              Czech_Hundreds (Value / 100) & " "
              & Czech_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Czech_Thousands_Form (1);
         elsif Value mod 1_000 = 0 then
            return
              Czech_Number (Value / 1_000) & " "
              & Czech_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return
              Czech_Thousands_Form (1) & " "
              & Czech_Number (Value mod 1_000);
         else
            return
              Czech_Number (Value / 1_000) & " "
              & Czech_Thousands_Form (Value / 1_000) & " "
              & Czech_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              Czech_Number (Value / 1_000_000) & " "
              & Czech_Millions_Form (Value / 1_000_000);
         else
            return
              Czech_Number (Value / 1_000_000) & " "
              & Czech_Millions_Form (Value / 1_000_000) & " "
              & Czech_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Czech_Number;

   function Czech_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nult" & U (16#FD#);
         when 1 =>
            return "prvn" & U (16#ED#);
         when 2 =>
            return "druh" & U (16#FD#);
         when 3 =>
            return "t" & U (16#159#) & "et" & U (16#ED#);
         when 4 =>
            return U (16#10D#) & "tvrt" & U (16#FD#);
         when 5 =>
            return "p" & U (16#E1#) & "t" & U (16#FD#);
         when 6 =>
            return U (16#161#) & "est" & U (16#FD#);
         when 7 =>
            return "sedm" & U (16#FD#);
         when 8 =>
            return "osm" & U (16#FD#);
         when 9 =>
            return "dev" & U (16#E1#) & "t" & U (16#FD#);
         when 10 =>
            return "des" & U (16#E1#) & "t" & U (16#FD#);
         when 11 =>
            return "jeden" & U (16#E1#) & "ct" & U (16#FD#);
         when 12 =>
            return "dvan" & U (16#E1#) & "ct" & U (16#FD#);
         when 13 =>
            return
              "t" & U (16#159#) & "in" & U (16#E1#) & "ct"
              & U (16#FD#);
         when 14 =>
            return U (16#10D#) & "trn" & U (16#E1#) & "ct" & U (16#FD#);
         when 15 =>
            return "patn" & U (16#E1#) & "ct" & U (16#FD#);
         when 16 =>
            return U (16#161#) & "estn" & U (16#E1#) & "ct" & U (16#FD#);
         when 17 =>
            return "sedmn" & U (16#E1#) & "ct" & U (16#FD#);
         when 18 =>
            return "osmn" & U (16#E1#) & "ct" & U (16#FD#);
         when 19 =>
            return "devaten" & U (16#E1#) & "ct" & U (16#FD#);
         when others =>
            return "";
      end case;
   end Czech_Ordinal_Under_20;

   function Czech_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dvac" & U (16#E1#) & "t" & U (16#FD#);
         when 3 =>
            return "t" & U (16#159#) & "ic" & U (16#E1#) & "t" & U (16#FD#);
         when 4 =>
            return
              U (16#10D#) & "ty" & U (16#159#) & "ic" & U (16#E1#)
              & "t" & U (16#FD#);
         when 5 =>
            return "pades" & U (16#E1#) & "t" & U (16#FD#);
         when 6 =>
            return U (16#161#) & "edes" & U (16#E1#) & "t" & U (16#FD#);
         when 7 =>
            return "sedmdes" & U (16#E1#) & "t" & U (16#FD#);
         when 8 =>
            return "osmdes" & U (16#E1#) & "t" & U (16#FD#);
         when 9 =>
            return "devades" & U (16#E1#) & "t" & U (16#FD#);
         when others =>
            return "";
      end case;
   end Czech_Tens_Ordinal;

   function Czech_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "st" & U (16#FD#);
         when 2 =>
            return "dvoust" & U (16#FD#);
         when 3 =>
            return "t" & U (16#159#) & U (16#ED#) & "st" & U (16#FD#);
         when 4 =>
            return U (16#10D#) & "ty" & U (16#159#) & "st" & U (16#FD#);
         when 5 =>
            return "p" & U (16#11B#) & "tist" & U (16#FD#);
         when 6 =>
            return U (16#161#) & "estist" & U (16#FD#);
         when 7 =>
            return "sedmist" & U (16#FD#);
         when 8 =>
            return "osmist" & U (16#FD#);
         when 9 =>
            return "dev" & U (16#ED#) & "tist" & U (16#FD#);
         when others =>
            return "";
      end case;
   end Czech_Hundreds_Ordinal;

   function Czech_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Czech_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Czech_Tens_Ordinal (Value / 10);
         else
            return
              Czech_Tens_Ordinal (Value / 10) & " "
              & Czech_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Czech_Hundreds_Ordinal (Value / 100);
         else
            return
              Czech_Hundreds (Value / 100) & " "
              & Czech_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "tis" & U (16#ED#) & "c" & U (16#ED#);
         elsif Value mod 1_000 = 0 then
            return
              Czech_Number (Value / 1_000) & " tis"
              & U (16#ED#) & "c" & U (16#ED#);
         elsif Value < 2_000 then
            return
              Czech_Thousands_Form (1) & " "
              & Czech_Ordinal (Value mod 1_000);
         else
            return
              Czech_Number (Value / 1_000) & " "
              & Czech_Thousands_Form (Value / 1_000) & " "
              & Czech_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "miliont" & U (16#FD#);
         elsif Value mod 1_000_000 = 0 then
            return Czech_Number (Value / 1_000_000) & " miliont" & U (16#FD#);
         else
            return
              Czech_Number (Value / 1_000_000) & " "
              & Czech_Millions_Form (Value / 1_000_000) & " "
              & Czech_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Czech_Ordinal;

   function Russian_Under_20
     (Value    : Natural;
      Feminine : Boolean := False)
      return String
   is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#43D#, 16#43E#, 16#43B#, 16#44C#]);
         when 1 =>
            if Feminine then
               return UTF8 ([16#43E#, 16#434#, 16#43D#, 16#430#]);
            else
               return UTF8 ([16#43E#, 16#434#, 16#438#, 16#43D#]);
            end if;
         when 2 =>
            if Feminine then
               return UTF8 ([16#434#, 16#432#, 16#435#]);
            else
               return UTF8 ([16#434#, 16#432#, 16#430#]);
            end if;
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#]);
         when 4 =>
            return UTF8 ([16#447#, 16#435#, 16#442#, 16#44B#, 16#440#, 16#435#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#44F#, 16#442#, 16#44C#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#44C#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#43C#, 16#44C#]);
         when 8 =>
            return UTF8 ([16#432#, 16#43E#, 16#441#, 16#435#, 16#43C#, 16#44C#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#44C#]);
         when 10 =>
            return UTF8 ([16#434#, 16#435#, 16#441#, 16#44F#, 16#442#, 16#44C#]);
         when 11 =>
            return
              UTF8
                ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#43D#, 16#430#,
                  16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 12 =>
            return
              UTF8
                ([16#434#, 16#432#, 16#435#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44C#]);
         when 13 =>
            return
              UTF8
                ([16#442#, 16#440#, 16#438#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44C#]);
         when 14 =>
            return
              UTF8
                ([16#447#, 16#435#, 16#442#, 16#44B#, 16#440#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 15 =>
            return
              UTF8
                ([16#43F#, 16#44F#, 16#442#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44C#]);
         when 16 =>
            return
              UTF8
                ([16#448#, 16#435#, 16#441#, 16#442#, 16#43D#, 16#430#,
                  16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 17 =>
            return
              UTF8
                ([16#441#, 16#435#, 16#43C#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44C#]);
         when 18 =>
            return
              UTF8
                ([16#432#, 16#43E#, 16#441#, 16#435#, 16#43C#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 19 =>
            return
              UTF8
                ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when others =>
            return "";
      end case;
   end Russian_Under_20;

   function Russian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44C#]);
         when 4 =>
            return UTF8 ([16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#44F#, 16#442#, 16#44C#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#44C#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#43C#, 16#44C#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 8 =>
            return
              UTF8
                ([16#432#, 16#43E#, 16#441#, 16#435#, 16#43C#, 16#44C#,
                  16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#44F#, 16#43D#, 16#43E#, 16#441#, 16#442#, 16#43E#]);
         when others =>
            return "";
      end case;
   end Russian_Tens;

   function Russian_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#441#, 16#442#, 16#43E#]);
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#435#, 16#441#, 16#442#, 16#438#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#441#, 16#442#, 16#430#]);
         when 4 =>
            return UTF8 ([16#447#, 16#435#, 16#442#, 16#44B#, 16#440#, 16#435#, 16#441#, 16#442#, 16#430#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#44F#, 16#442#, 16#44C#, 16#441#, 16#43E#, 16#442#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#44C#, 16#441#, 16#43E#, 16#442#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#43C#, 16#44C#, 16#441#, 16#43E#, 16#442#]);
         when 8 =>
            return UTF8 ([16#432#, 16#43E#, 16#441#, 16#435#, 16#43C#, 16#44C#, 16#441#, 16#43E#, 16#442#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#44C#, 16#441#, 16#43E#, 16#442#]);
         when others =>
            return "";
      end case;
   end Russian_Hundreds;

   function Russian_Scale_Form
     (Count    : Natural;
      Singular : String;
      Few      : String;
      Many     : String)
      return String
   is
      Last_Two : constant Natural := Count mod 100;
      Last_One : constant Natural := Count mod 10;
   begin
      if Last_One = 1 and then Last_Two /= 11 then
         return Singular;
      elsif Last_One in 2 .. 4 and then not (Last_Two in 12 .. 14) then
         return Few;
      else
         return Many;
      end if;
   end Russian_Scale_Form;

   function Russian_Thousands_Form (Count : Natural) return String is
   begin
      return
        Russian_Scale_Form
          (Count,
           UTF8 ([16#442#, 16#44B#, 16#441#, 16#44F#, 16#447#, 16#430#]),
           UTF8 ([16#442#, 16#44B#, 16#441#, 16#44F#, 16#447#, 16#438#]),
           UTF8 ([16#442#, 16#44B#, 16#441#, 16#44F#, 16#447#]));
   end Russian_Thousands_Form;

   function Russian_Millions_Form (Count : Natural) return String is
   begin
      return
        Russian_Scale_Form
          (Count,
           UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#]),
           UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#, 16#430#]),
           UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#, 16#43E#, 16#432#]));
   end Russian_Millions_Form;

   function Russian_Number
     (Value    : Natural;
      Feminine : Boolean := False)
      return String
   is
   begin
      if Value < 20 then
         return Russian_Under_20 (Value, Feminine);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Russian_Tens (Value / 10);
         else
            return
              Russian_Tens (Value / 10) & " "
              & Russian_Under_20 (Value mod 10, Feminine);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Russian_Hundreds (Value / 100);
         else
            return
              Russian_Hundreds (Value / 100) & " "
              & Russian_Number (Value mod 100, Feminine);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Russian_Thousands_Form (1);
         elsif Value mod 1_000 = 0 then
            return
              Russian_Number (Value / 1_000, True) & " "
              & Russian_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return
              Russian_Thousands_Form (1) & " "
              & Russian_Number (Value mod 1_000);
         else
            return
              Russian_Number (Value / 1_000, True) & " "
              & Russian_Thousands_Form (Value / 1_000) & " "
              & Russian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              Russian_Number (Value / 1_000_000) & " "
              & Russian_Millions_Form (Value / 1_000_000);
         else
            return
              Russian_Number (Value / 1_000_000) & " "
              & Russian_Millions_Form (Value / 1_000_000) & " "
              & Russian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Russian_Number;

   function Russian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#43D#, 16#443#, 16#43B#, 16#435#, 16#432#, 16#43E#, 16#439#]);
         when 1 =>
            return UTF8 ([16#43F#, 16#435#, 16#440#, 16#432#, 16#44B#, 16#439#]);
         when 2 =>
            return UTF8 ([16#432#, 16#442#, 16#43E#, 16#440#, 16#43E#, 16#439#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#435#, 16#442#, 16#438#, 16#439#]);
         when 4 =>
            return UTF8 ([16#447#, 16#435#, 16#442#, 16#432#, 16#435#, 16#440#, 16#442#, 16#44B#, 16#439#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#43E#, 16#439#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#434#, 16#44C#, 16#43C#, 16#43E#, 16#439#]);
         when 8 =>
            return UTF8 ([16#432#, 16#43E#, 16#441#, 16#44C#, 16#43C#, 16#43E#, 16#439#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 10 =>
            return UTF8 ([16#434#, 16#435#, 16#441#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 11 =>
            return
              UTF8
                ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#43D#, 16#430#,
                  16#434#, 16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 12 =>
            return
              UTF8
                ([16#434#, 16#432#, 16#435#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 13 =>
            return
              UTF8
                ([16#442#, 16#440#, 16#438#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 14 =>
            return
              UTF8
                ([16#447#, 16#435#, 16#442#, 16#44B#, 16#440#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44B#,
                  16#439#]);
         when 15 =>
            return
              UTF8
                ([16#43F#, 16#44F#, 16#442#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 16 =>
            return
              UTF8
                ([16#448#, 16#435#, 16#441#, 16#442#, 16#43D#, 16#430#,
                  16#434#, 16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 17 =>
            return
              UTF8
                ([16#441#, 16#435#, 16#43C#, 16#43D#, 16#430#, 16#434#,
                  16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 18 =>
            return
              UTF8
                ([16#432#, 16#43E#, 16#441#, 16#435#, 16#43C#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44B#,
                  16#439#]);
         when 19 =>
            return
              UTF8
                ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#43D#,
                  16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44B#,
                  16#439#]);
         when others =>
            return "";
      end case;
   end Russian_Ordinal_Under_20;

   function Russian_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#434#, 16#446#, 16#430#, 16#442#, 16#44B#, 16#439#]);
         when 4 =>
            return UTF8 ([16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#, 16#43E#, 16#432#, 16#43E#, 16#439#]);
         when 5 =>
            return
              UTF8
                ([16#43F#, 16#44F#, 16#442#, 16#438#, 16#434#, 16#435#,
                  16#441#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 6 =>
            return
              UTF8
                ([16#448#, 16#435#, 16#441#, 16#442#, 16#438#, 16#434#,
                  16#435#, 16#441#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 7 =>
            return
              UTF8
                ([16#441#, 16#435#, 16#43C#, 16#438#, 16#434#, 16#435#,
                  16#441#, 16#44F#, 16#442#, 16#44B#, 16#439#]);
         when 8 =>
            return
              UTF8
                ([16#432#, 16#43E#, 16#441#, 16#44C#, 16#43C#, 16#438#,
                  16#434#, 16#435#, 16#441#, 16#44F#, 16#442#, 16#44B#,
                  16#439#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#44F#, 16#43D#, 16#43E#, 16#441#, 16#442#, 16#44B#, 16#439#]);
         when others =>
            return "";
      end case;
   end Russian_Tens_Ordinal;

   function Russian_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#443#, 16#445#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#435#, 16#445#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 4 =>
            return
              UTF8
                ([16#447#, 16#435#, 16#442#, 16#44B#, 16#440#, 16#435#,
                  16#445#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#44F#, 16#442#, 16#438#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#438#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#43C#, 16#438#, 16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 8 =>
            return
              UTF8
                ([16#432#, 16#43E#, 16#441#, 16#44C#, 16#43C#, 16#438#,
                  16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when 9 =>
            return
              UTF8
                ([16#434#, 16#435#, 16#432#, 16#44F#, 16#442#, 16#438#,
                  16#441#, 16#43E#, 16#442#, 16#44B#, 16#439#]);
         when others =>
            return "";
      end case;
   end Russian_Hundreds_Ordinal;

   function Russian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Russian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Russian_Tens_Ordinal (Value / 10);
         else
            return
              Russian_Tens (Value / 10) & " "
              & Russian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Russian_Hundreds_Ordinal (Value / 100);
         else
            return
              Russian_Hundreds (Value / 100) & " "
              & Russian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return UTF8 ([16#442#, 16#44B#, 16#441#, 16#44F#, 16#447#, 16#43D#, 16#44B#, 16#439#]);
         elsif Value mod 1_000 = 0 then
            return
              Russian_Number (Value / 1_000, True) & " "
              & UTF8 ([16#442#, 16#44B#, 16#441#, 16#44F#, 16#447#, 16#43D#, 16#44B#, 16#439#]);
         elsif Value < 2_000 then
            return Russian_Thousands_Form (1) & " " & Russian_Ordinal (Value mod 1_000);
         else
            return
              Russian_Number (Value / 1_000, True) & " "
              & Russian_Thousands_Form (Value / 1_000) & " "
              & Russian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#, 16#43D#, 16#44B#, 16#439#]);
         elsif Value mod 1_000_000 = 0 then
            return
              Russian_Number (Value / 1_000_000) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#43E#, 16#43D#, 16#43D#, 16#44B#, 16#439#]);
         else
            return
              Russian_Number (Value / 1_000_000) & " "
              & Russian_Millions_Form (Value / 1_000_000) & " "
              & Russian_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Russian_Ordinal;

   function Ukrainian_Under_20
     (Value      : Natural;
      Feminine   : Boolean := False)
      return String
   is
   begin
      case Value is
         when 0 => return UTF8 ([16#43D#, 16#443#, 16#43B#, 16#44C#]);
         when 1 =>
            return
              (if Feminine then
                 UTF8 ([16#43E#, 16#434#, 16#43D#, 16#430#])
               else
                 UTF8 ([16#43E#, 16#434#, 16#438#, 16#43D#]));
         when 2 =>
            return
              (if Feminine then
                 UTF8 ([16#434#, 16#432#, 16#456#])
               else
                 UTF8 ([16#434#, 16#432#, 16#430#]));
         when 3 => return UTF8 ([16#442#, 16#440#, 16#438#]);
         when 4 => return UTF8 ([16#447#, 16#43E#, 16#442#, 16#438#, 16#440#, 16#438#]);
         when 5 => return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#44C#]);
         when 6 => return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#44C#]);
         when 7 => return UTF8 ([16#441#, 16#456#, 16#43C#]);
         when 8 => return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#]);
         when 9 => return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#, 16#442#, 16#44C#]);
         when 10 => return UTF8 ([16#434#, 16#435#, 16#441#, 16#44F#, 16#442#, 16#44C#]);
         when 11 =>
            return UTF8 ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 12 =>
            return UTF8 ([16#434#, 16#432#, 16#430#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 13 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 14 =>
            return UTF8 ([16#447#, 16#43E#, 16#442#, 16#438#, 16#440#,
                          16#43D#, 16#430#, 16#434#, 16#446#, 16#44F#,
                          16#442#, 16#44C#]);
         when 15 =>
            return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#43D#,
                          16#430#, 16#434#, 16#446#, 16#44F#, 16#442#,
                          16#44C#]);
         when 16 =>
            return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#43D#,
                          16#430#, 16#434#, 16#446#, 16#44F#, 16#442#,
                          16#44C#]);
         when 17 =>
            return UTF8 ([16#441#, 16#456#, 16#43C#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 18 =>
            return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#,
                          16#43D#, 16#430#, 16#434#, 16#446#, 16#44F#,
                          16#442#, 16#44C#]);
         when 19 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                          16#442#, 16#43D#, 16#430#, 16#434#, 16#446#,
                          16#44F#, 16#442#, 16#44C#]);
         when others => return "";
      end case;
   end Ukrainian_Under_20;

   function Ukrainian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 => return UTF8 ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 3 => return UTF8 ([16#442#, 16#440#, 16#438#, 16#434#, 16#446#, 16#44F#, 16#442#, 16#44C#]);
         when 4 => return UTF8 ([16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#]);
         when 5 => return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 6 => return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 7 => return UTF8 ([16#441#, 16#456#, 16#43C#, 16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 8 =>
            return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#,
                          16#434#, 16#435#, 16#441#, 16#44F#, 16#442#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                          16#43D#, 16#43E#, 16#441#, 16#442#, 16#43E#]);
         when others => return "";
      end case;
   end Ukrainian_Tens;

   function Ukrainian_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 => return UTF8 ([16#441#, 16#442#, 16#43E#]);
         when 2 => return UTF8 ([16#434#, 16#432#, 16#456#, 16#441#, 16#442#, 16#456#]);
         when 3 => return UTF8 ([16#442#, 16#440#, 16#438#, 16#441#, 16#442#, 16#430#]);
         when 4 => return UTF8 ([16#447#, 16#43E#, 16#442#, 16#438#, 16#440#, 16#438#, 16#441#, 16#442#, 16#430#]);
         when 5 => return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#441#, 16#43E#, 16#442#]);
         when 6 => return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#441#, 16#43E#, 16#442#]);
         when 7 => return UTF8 ([16#441#, 16#456#, 16#43C#, 16#441#, 16#43E#, 16#442#]);
         when 8 => return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#, 16#441#, 16#43E#, 16#442#]);
         when 9 => return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#, 16#442#, 16#441#, 16#43E#, 16#442#]);
         when others => return "";
      end case;
   end Ukrainian_Hundreds;

   function Ukrainian_Scale_Form
     (Count    : Natural;
      Singular : String;
      Few      : String;
      Many     : String)
      return String
   is
      Last_Two : constant Natural := Count mod 100;
      Last_One : constant Natural := Count mod 10;
   begin
      if Last_One = 1 and then Last_Two /= 11 then
         return Singular;
      elsif Last_One in 2 .. 4 and then not (Last_Two in 12 .. 14) then
         return Few;
      else
         return Many;
      end if;
   end Ukrainian_Scale_Form;

   function Ukrainian_Thousands_Form (Count : Natural) return String is
   begin
      return
        Ukrainian_Scale_Form
          (Count,
           UTF8 ([16#442#, 16#438#, 16#441#, 16#44F#, 16#447#, 16#430#]),
           UTF8 ([16#442#, 16#438#, 16#441#, 16#44F#, 16#447#, 16#456#]),
           UTF8 ([16#442#, 16#438#, 16#441#, 16#44F#, 16#447#]));
   end Ukrainian_Thousands_Form;

   function Ukrainian_Millions_Form (Count : Natural) return String is
   begin
      return
        Ukrainian_Scale_Form
          (Count,
           UTF8 ([16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#, 16#43E#, 16#43D#]),
           UTF8 ([16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#, 16#43E#, 16#43D#, 16#438#]),
           UTF8 ([16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#, 16#43E#, 16#43D#, 16#456#, 16#432#]));
   end Ukrainian_Millions_Form;

   function Ukrainian_Number
     (Value    : Natural;
      Feminine : Boolean := False)
      return String
   is
   begin
      if Value < 20 then
         return Ukrainian_Under_20 (Value, Feminine);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Ukrainian_Tens (Value / 10);
         else
            return
              Ukrainian_Tens (Value / 10) & " "
              & Ukrainian_Under_20 (Value mod 10, Feminine);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Ukrainian_Hundreds (Value / 100);
         else
            return
              Ukrainian_Hundreds (Value / 100) & " "
              & Ukrainian_Number (Value mod 100, Feminine);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Ukrainian_Thousands_Form (1);
         elsif Value mod 1_000 = 0 then
            return
              Ukrainian_Number (Value / 1_000, True) & " "
              & Ukrainian_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return
              Ukrainian_Thousands_Form (1) & " "
              & Ukrainian_Number (Value mod 1_000);
         else
            return
              Ukrainian_Number (Value / 1_000, True) & " "
              & Ukrainian_Thousands_Form (Value / 1_000) & " "
              & Ukrainian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return
              Ukrainian_Number (Value / 1_000_000) & " "
              & Ukrainian_Millions_Form (Value / 1_000_000);
         else
            return
              Ukrainian_Number (Value / 1_000_000) & " "
              & Ukrainian_Millions_Form (Value / 1_000_000) & " "
              & Ukrainian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Ukrainian_Number;

   function Ukrainian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 => return UTF8 ([16#43D#, 16#443#, 16#43B#, 16#44C#, 16#43E#, 16#432#, 16#438#, 16#439#]);
         when 1 => return UTF8 ([16#43F#, 16#435#, 16#440#, 16#448#, 16#438#, 16#439#]);
         when 2 => return UTF8 ([16#434#, 16#440#, 16#443#, 16#433#, 16#438#, 16#439#]);
         when 3 => return UTF8 ([16#442#, 16#440#, 16#435#, 16#442#, 16#456#, 16#439#]);
         when 4 => return UTF8 ([16#447#, 16#435#, 16#442#, 16#432#, 16#435#, 16#440#, 16#442#, 16#438#, 16#439#]);
         when 5 => return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 6 => return UTF8 ([16#448#, 16#43E#, 16#441#, 16#442#, 16#438#, 16#439#]);
         when 7 => return UTF8 ([16#441#, 16#44C#, 16#43E#, 16#43C#, 16#438#, 16#439#]);
         when 8 => return UTF8 ([16#432#, 16#43E#, 16#441#, 16#44C#, 16#43C#, 16#438#, 16#439#]);
         when 9 => return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 10 => return UTF8 ([16#434#, 16#435#, 16#441#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 11 =>
            return UTF8 ([16#43E#, 16#434#, 16#438#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 12 =>
            return UTF8 ([16#434#, 16#432#, 16#430#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 13 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 14 =>
            return UTF8 ([16#447#, 16#43E#, 16#442#, 16#438#, 16#440#,
                          16#43D#, 16#430#, 16#434#, 16#446#, 16#44F#,
                          16#442#, 16#438#, 16#439#]);
         when 15 =>
            return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#43D#,
                          16#430#, 16#434#, 16#446#, 16#44F#, 16#442#,
                          16#438#, 16#439#]);
         when 16 =>
            return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#43D#,
                          16#430#, 16#434#, 16#446#, 16#44F#, 16#442#,
                          16#438#, 16#439#]);
         when 17 =>
            return UTF8 ([16#441#, 16#456#, 16#43C#, 16#43D#, 16#430#,
                          16#434#, 16#446#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 18 =>
            return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#,
                          16#43D#, 16#430#, 16#434#, 16#446#, 16#44F#,
                          16#442#, 16#438#, 16#439#]);
         when 19 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                          16#442#, 16#43D#, 16#430#, 16#434#, 16#446#,
                          16#44F#, 16#442#, 16#438#, 16#439#]);
         when others => return "";
      end case;
   end Ukrainian_Ordinal_Under_20;

   function Ukrainian_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 => return UTF8 ([16#434#, 16#432#, 16#430#, 16#434#, 16#446#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 3 => return UTF8 ([16#442#, 16#440#, 16#438#, 16#434#, 16#446#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 4 => return UTF8 ([16#441#, 16#43E#, 16#440#, 16#43E#, 16#43A#, 16#43E#, 16#432#, 16#438#, 16#439#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#434#,
                          16#435#, 16#441#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 6 =>
            return UTF8 ([16#448#, 16#456#, 16#441#, 16#442#, 16#434#,
                          16#435#, 16#441#, 16#44F#, 16#442#, 16#438#,
                          16#439#]);
         when 7 =>
            return UTF8 ([16#441#, 16#456#, 16#43C#, 16#434#, 16#435#,
                          16#441#, 16#44F#, 16#442#, 16#438#, 16#439#]);
         when 8 =>
            return UTF8 ([16#432#, 16#456#, 16#441#, 16#456#, 16#43C#,
                          16#434#, 16#435#, 16#441#, 16#44F#, 16#442#,
                          16#438#, 16#439#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                          16#43D#, 16#43E#, 16#441#, 16#442#, 16#438#,
                          16#439#]);
         when others => return "";
      end case;
   end Ukrainian_Tens_Ordinal;

   function Ukrainian_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#441#, 16#43E#, 16#442#, 16#438#, 16#439#]);
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#43E#, 16#445#, 16#441#,
                          16#43E#, 16#442#, 16#438#, 16#439#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#44C#, 16#43E#, 16#445#,
                          16#441#, 16#43E#, 16#442#, 16#438#, 16#439#]);
         when 4 =>
            return UTF8 ([16#447#, 16#43E#, 16#442#, 16#438#, 16#440#,
                          16#44C#, 16#43E#, 16#445#, 16#441#, 16#43E#,
                          16#442#, 16#438#, 16#439#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#27#, 16#44F#, 16#442#, 16#438#,
                          16#441#, 16#43E#, 16#442#, 16#438#, 16#439#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#438#,
                          16#441#, 16#43E#, 16#442#, 16#438#, 16#439#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#43C#, 16#438#, 16#441#,
                          16#43E#, 16#442#, 16#438#, 16#439#]);
         when 8 =>
            return UTF8 ([16#432#, 16#43E#, 16#441#, 16#44C#, 16#43C#,
                          16#438#, 16#441#, 16#43E#, 16#442#, 16#438#,
                          16#439#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#27#, 16#44F#,
                          16#442#, 16#438#, 16#441#, 16#43E#, 16#442#,
                          16#438#, 16#439#]);
         when others => return "";
      end case;
   end Ukrainian_Hundreds_Ordinal;

   function Ukrainian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Ukrainian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Ukrainian_Tens_Ordinal (Value / 10);
         else
            return
              Ukrainian_Tens (Value / 10) & " "
              & Ukrainian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Ukrainian_Hundreds_Ordinal (Value / 100);
         else
            return
              Ukrainian_Hundreds (Value / 100) & " "
              & Ukrainian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return UTF8 ([16#442#, 16#438#, 16#441#, 16#44F#, 16#447#, 16#43D#, 16#438#, 16#439#]);
         elsif Value mod 1_000 = 0 then
            return
              Ukrainian_Number (Value / 1_000, True) & " "
              & UTF8 ([16#442#, 16#438#, 16#441#, 16#44F#, 16#447#, 16#43D#, 16#438#, 16#439#]);
         else
            return
              Ukrainian_Number (Value / 1_000, True) & " "
              & Ukrainian_Thousands_Form (Value / 1_000) & " "
              & Ukrainian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return UTF8 ([16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#, 16#43E#, 16#43D#, 16#43D#, 16#438#, 16#439#]);
         elsif Value mod 1_000_000 = 0 then
            return
              Ukrainian_Number (Value / 1_000_000) & " "
              & UTF8 ([16#43C#, 16#456#, 16#43B#, 16#44C#, 16#439#, 16#43E#, 16#43D#, 16#43D#, 16#438#, 16#439#]);
         else
            return
              Ukrainian_Number (Value / 1_000_000) & " "
              & Ukrainian_Millions_Form (Value / 1_000_000) & " "
              & Ukrainian_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Ukrainian_Ordinal;

   function Japanese_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#96F6#]);
         when 1 =>
            return UTF8 ([16#4E00#]);
         when 2 =>
            return UTF8 ([16#4E8C#]);
         when 3 =>
            return UTF8 ([16#4E09#]);
         when 4 =>
            return UTF8 ([16#56DB#]);
         when 5 =>
            return UTF8 ([16#4E94#]);
         when 6 =>
            return UTF8 ([16#516D#]);
         when 7 =>
            return UTF8 ([16#4E03#]);
         when 8 =>
            return UTF8 ([16#516B#]);
         when 9 =>
            return UTF8 ([16#4E5D#]);
         when others =>
            return "";
      end case;
   end Japanese_Digit;

   function Japanese_Section (Value : Natural) return String is
      Result    : Unbounded_String := Null_Unbounded_String;
      Remaining : Natural := Value;
      Digit     : Natural;

      procedure Append_Unit
        (Unit_Digit : Natural;
         Unit       : String;
         Omit_One   : Boolean := True)
      is
      begin
         if Unit_Digit = 0 then
            return;
         end if;

         if not (Omit_One and then Unit_Digit = 1) then
            Append (Result, Japanese_Digit (Unit_Digit));
         end if;

         Append (Result, Unit);
      end Append_Unit;
   begin
      if Value = 0 then
         return "";
      end if;

      Digit := Remaining / 1_000;
      Append_Unit (Digit, UTF8 ([16#5343#]));
      Remaining := Remaining mod 1_000;

      Digit := Remaining / 100;
      Append_Unit (Digit, UTF8 ([16#767E#]));
      Remaining := Remaining mod 100;

      Digit := Remaining / 10;
      Append_Unit (Digit, UTF8 ([16#5341#]));
      Remaining := Remaining mod 10;

      if Remaining /= 0 then
         Append (Result, Japanese_Digit (Remaining));
      end if;

      return To_String (Result);
   end Japanese_Section;

   function Japanese_Number (Value : Natural) return String is
      Result    : Unbounded_String := Null_Unbounded_String;
      Remaining : Natural := Value;
      Section   : Natural;
   begin
      if Value = 0 then
         return Japanese_Digit (0);
      end if;

      Section := Remaining / 100_000_000;
      if Section /= 0 then
         Append (Result, Japanese_Section (Section));
         Append (Result, UTF8 ([16#5104#]));
         Remaining := Remaining mod 100_000_000;
      end if;

      Section := Remaining / 10_000;
      if Section /= 0 then
         Append (Result, Japanese_Section (Section));
         Append (Result, UTF8 ([16#4E07#]));
         Remaining := Remaining mod 10_000;
      end if;

      if Remaining /= 0 then
         Append (Result, Japanese_Section (Remaining));
      end if;

      return To_String (Result);
   end Japanese_Number;

   function Japanese_Ordinal (Value : Natural) return String is
   begin
      return UTF8 ([16#7B2C#]) & Japanese_Number (Value);
   end Japanese_Ordinal;

   function Chinese_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#96F6#]);
         when 1 =>
            return UTF8 ([16#4E00#]);
         when 2 =>
            return UTF8 ([16#4E8C#]);
         when 3 =>
            return UTF8 ([16#4E09#]);
         when 4 =>
            return UTF8 ([16#56DB#]);
         when 5 =>
            return UTF8 ([16#4E94#]);
         when 6 =>
            return UTF8 ([16#516D#]);
         when 7 =>
            return UTF8 ([16#4E03#]);
         when 8 =>
            return UTF8 ([16#516B#]);
         when 9 =>
            return UTF8 ([16#4E5D#]);
         when others =>
            return "";
      end case;
   end Chinese_Digit;

   function Chinese_Section (Value : Natural) return String is
      Result       : Unbounded_String := Null_Unbounded_String;
      Thousands    : constant Natural := Value / 1_000;
      Hundreds     : constant Natural := (Value / 100) mod 10;
      Tens         : constant Natural := (Value / 10) mod 10;
      Ones         : constant Natural := Value mod 10;
      Seen_Nonzero : Boolean := False;
      Pending_Zero : Boolean := False;

      procedure Append_Part
        (Digit      : Natural;
         Unit       : String;
         Later_Used : Boolean;
         Omit_One   : Boolean := False)
      is
      begin
         if Digit = 0 then
            if Seen_Nonzero and then Later_Used then
               Pending_Zero := True;
            end if;
            return;
         end if;

         if Pending_Zero then
            Append (Result, Chinese_Digit (0));
            Pending_Zero := False;
         end if;

         if not (Omit_One and then Digit = 1 and then not Seen_Nonzero) then
            Append (Result, Chinese_Digit (Digit));
         end if;

         Append (Result, Unit);
         Seen_Nonzero := True;
      end Append_Part;
   begin
      if Value = 0 then
         return "";
      end if;

      Append_Part
        (Thousands, UTF8 ([16#5343#]),
         Hundreds /= 0 or else Tens /= 0 or else Ones /= 0);
      Append_Part
        (Hundreds, UTF8 ([16#767E#]), Tens /= 0 or else Ones /= 0);
      Append_Part
        (Tens, UTF8 ([16#5341#]), Ones /= 0, Omit_One => True);
      Append_Part (Ones, "", False);

      return To_String (Result);
   end Chinese_Section;

   function Chinese_Number (Value : Natural) return String is
      Result       : Unbounded_String := Null_Unbounded_String;
      Yi           : constant Natural := Value / 100_000_000;
      Wan          : constant Natural := (Value / 10_000) mod 10_000;
      Rest         : constant Natural := Value mod 10_000;
      Need_Zero    : Boolean := False;
      Seen_Section : Boolean := False;
   begin
      if Value = 0 then
         return Chinese_Digit (0);
      end if;

      if Yi /= 0 then
         Append (Result, Chinese_Section (Yi));
         Append (Result, UTF8 ([16#4EBF#]));
         Seen_Section := True;
         Need_Zero := Wan = 0 and then Rest /= 0;
      end if;

      if Wan /= 0 then
         if Seen_Section and then Wan < 1_000 then
            Append (Result, Chinese_Digit (0));
         end if;
         Append (Result, Chinese_Section (Wan));
         Append (Result, UTF8 ([16#4E07#]));
         Seen_Section := True;
         Need_Zero := Rest /= 0 and then Rest < 1_000;
      end if;

      if Rest /= 0 then
         if Need_Zero then
            Append (Result, Chinese_Digit (0));
         end if;
         Append (Result, Chinese_Section (Rest));
      end if;

      return To_String (Result);
   end Chinese_Number;

   function Chinese_Ordinal (Value : Natural) return String is
   begin
      return UTF8 ([16#7B2C#]) & Chinese_Number (Value);
   end Chinese_Ordinal;

   function Korean_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#C601#]);
         when 1 =>
            return UTF8 ([16#C77C#]);
         when 2 =>
            return UTF8 ([16#C774#]);
         when 3 =>
            return UTF8 ([16#C0BC#]);
         when 4 =>
            return UTF8 ([16#C0AC#]);
         when 5 =>
            return UTF8 ([16#C624#]);
         when 6 =>
            return UTF8 ([16#C721#]);
         when 7 =>
            return UTF8 ([16#CE60#]);
         when 8 =>
            return UTF8 ([16#D314#]);
         when 9 =>
            return UTF8 ([16#AD6C#]);
         when others =>
            return "";
      end case;
   end Korean_Digit;

   function Korean_Section (Value : Natural) return String is
      Result    : Unbounded_String := Null_Unbounded_String;
      Remaining : Natural := Value;
      Digit     : Natural;

      procedure Append_Unit
        (Unit_Digit : Natural;
         Unit       : String;
         Omit_One   : Boolean := True)
      is
      begin
         if Unit_Digit = 0 then
            return;
         end if;

         if not (Omit_One and then Unit_Digit = 1) then
            Append (Result, Korean_Digit (Unit_Digit));
         end if;

         Append (Result, Unit);
      end Append_Unit;
   begin
      if Value = 0 then
         return "";
      end if;

      Digit := Remaining / 1_000;
      Append_Unit (Digit, UTF8 ([16#CC9C#]));
      Remaining := Remaining mod 1_000;

      Digit := Remaining / 100;
      Append_Unit (Digit, UTF8 ([16#BC31#]));
      Remaining := Remaining mod 100;

      Digit := Remaining / 10;
      Append_Unit (Digit, UTF8 ([16#C2ED#]));
      Remaining := Remaining mod 10;

      if Remaining /= 0 then
         Append (Result, Korean_Digit (Remaining));
      end if;

      return To_String (Result);
   end Korean_Section;

   function Korean_Number (Value : Natural) return String is
      Result    : Unbounded_String := Null_Unbounded_String;
      Remaining : Natural := Value;
      Section   : Natural;
   begin
      if Value = 0 then
         return Korean_Digit (0);
      end if;

      Section := Remaining / 100_000_000;
      if Section /= 0 then
         Append (Result, Korean_Section (Section));
         Append (Result, UTF8 ([16#C5B5#]));
         Remaining := Remaining mod 100_000_000;
      end if;

      Section := Remaining / 10_000;
      if Section /= 0 then
         if Section /= 1 then
            Append (Result, Korean_Section (Section));
         end if;
         Append (Result, UTF8 ([16#B9CC#]));
         Remaining := Remaining mod 10_000;
      end if;

      if Remaining /= 0 then
         Append (Result, Korean_Section (Remaining));
      end if;

      return To_String (Result);
   end Korean_Number;

   function Korean_Ordinal (Value : Natural) return String is
   begin
      return UTF8 ([16#C81C#]) & Korean_Number (Value);
   end Korean_Ordinal;

   function Turkish_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "s" & U (16#131#) & "f" & U (16#131#) & "r";
         when 1 =>
            return "bir";
         when 2 =>
            return "iki";
         when 3 =>
            return U (16#FC#) & U (16#E7#);
         when 4 =>
            return "d" & U (16#F6#) & "rt";
         when 5 =>
            return "be" & U (16#15F#);
         when 6 =>
            return "alt" & U (16#131#);
         when 7 =>
            return "yedi";
         when 8 =>
            return "sekiz";
         when 9 =>
            return "dokuz";
         when others =>
            return "";
      end case;
   end Turkish_Digit;

   function Turkish_Tens (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "on";
         when 2 =>
            return "yirmi";
         when 3 =>
            return "otuz";
         when 4 =>
            return "k" & U (16#131#) & "rk";
         when 5 =>
            return "elli";
         when 6 =>
            return "altm" & U (16#131#) & U (16#15F#);
         when 7 =>
            return "yetmi" & U (16#15F#);
         when 8 =>
            return "seksen";
         when 9 =>
            return "doksan";
         when others =>
            return "";
      end case;
   end Turkish_Tens;

   function Turkish_Hundreds (Count : Natural) return String is
   begin
      if Count = 1 then
         return "y" & U (16#FC#) & "z";
      else
         return Turkish_Digit (Count) & " y" & U (16#FC#) & "z";
      end if;
   end Turkish_Hundreds;

   function Turkish_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Turkish_Digit (Value);
      elsif Value < 20 then
         if Value = 10 then
            return Turkish_Tens (1);
         else
            return Turkish_Tens (1) & " " & Turkish_Digit (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Turkish_Tens (Value / 10);
         else
            return Turkish_Tens (Value / 10) & " "
              & Turkish_Digit (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Turkish_Hundreds (Value / 100);
         else
            return Turkish_Hundreds (Value / 100) & " "
              & Turkish_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "bin";
         elsif Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "bin";
            else
               return Turkish_Number (Value / 1_000) & " bin";
            end if;
         elsif Value < 2_000 then
            return "bin " & Turkish_Number (Value mod 1_000);
         else
            return Turkish_Number (Value / 1_000) & " bin "
              & Turkish_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Turkish_Number (Value / 1_000_000) & " milyon";
         else
            return Turkish_Number (Value / 1_000_000) & " milyon "
              & Turkish_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Turkish_Number;

   function Turkish_Ordinal_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "s" & U (16#131#) & "f" & U (16#131#)
              & "r" & U (16#131#) & "nc" & U (16#131#);
         when 1 =>
            return "birinci";
         when 2 =>
            return "ikinci";
         when 3 =>
            return U (16#FC#) & U (16#E7#) & U (16#FC#)
              & "nc" & U (16#FC#);
         when 4 =>
            return "d" & U (16#F6#) & "rd" & U (16#FC#)
              & "nc" & U (16#FC#);
         when 5 =>
            return "be" & U (16#15F#) & "inci";
         when 6 =>
            return "alt" & U (16#131#) & "nc" & U (16#131#);
         when 7 =>
            return "yedinci";
         when 8 =>
            return "sekizinci";
         when 9 =>
            return "dokuzuncu";
         when others =>
            return "";
      end case;
   end Turkish_Ordinal_Digit;

   function Turkish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "onuncu";
         when 2 =>
            return "yirminci";
         when 3 =>
            return "otuzuncu";
         when 4 =>
            return "k" & U (16#131#) & "rk" & U (16#131#)
              & "nc" & U (16#131#);
         when 5 =>
            return "ellinci";
         when 6 =>
            return "altm" & U (16#131#) & U (16#15F#)
              & U (16#131#) & "nc" & U (16#131#);
         when 7 =>
            return "yetmi" & U (16#15F#) & "inci";
         when 8 =>
            return "sekseninci";
         when 9 =>
            return "doksan" & U (16#131#) & "nc" & U (16#131#);
         when others =>
            return "";
      end case;
   end Turkish_Tens_Ordinal;

   function Turkish_Ordinal (Value : Natural) return String is
   begin
      if Value < 10 then
         return Turkish_Ordinal_Digit (Value);
      elsif Value < 20 then
         if Value = 10 then
            return Turkish_Tens_Ordinal (1);
         else
            return Turkish_Tens (1) & " "
              & Turkish_Ordinal_Digit (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Turkish_Tens_Ordinal (Value / 10);
         else
            return Turkish_Tens (Value / 10) & " "
              & Turkish_Ordinal_Digit (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Turkish_Hundreds (Value / 100) & U (16#FC#) & "nc"
              & U (16#FC#);
         else
            return Turkish_Hundreds (Value / 100) & " "
              & Turkish_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "bininci";
         elsif Value mod 1_000 = 0 then
            return Turkish_Number (Value / 1_000) & " bininci";
         elsif Value < 2_000 then
            return "bin " & Turkish_Ordinal (Value mod 1_000);
         else
            return Turkish_Number (Value / 1_000) & " bin "
              & Turkish_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Turkish_Number (Value / 1_000_000) & " milyonuncu";
         else
            return Turkish_Number (Value / 1_000_000) & " milyon "
              & Turkish_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Turkish_Ordinal;

   function Swedish_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "noll";
         when 1 =>
            return "ett";
         when 2 =>
            return "tv" & U (16#E5#);
         when 3 =>
            return "tre";
         when 4 =>
            return "fyra";
         when 5 =>
            return "fem";
         when 6 =>
            return "sex";
         when 7 =>
            return "sju";
         when 8 =>
            return U (16#E5#) & "tta";
         when 9 =>
            return "nio";
         when 10 =>
            return "tio";
         when 11 =>
            return "elva";
         when 12 =>
            return "tolv";
         when 13 =>
            return "tretton";
         when 14 =>
            return "fjorton";
         when 15 =>
            return "femton";
         when 16 =>
            return "sexton";
         when 17 =>
            return "sjutton";
         when 18 =>
            return "arton";
         when 19 =>
            return "nitton";
         when others =>
            return "";
      end case;
   end Swedish_Under_20;

   function Swedish_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tjugo";
         when 3 =>
            return "trettio";
         when 4 =>
            return "fyrtio";
         when 5 =>
            return "femtio";
         when 6 =>
            return "sextio";
         when 7 =>
            return "sjuttio";
         when 8 =>
            return U (16#E5#) & "ttio";
         when 9 =>
            return "nittio";
         when others =>
            return "";
      end case;
   end Swedish_Tens;

   function Swedish_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Swedish_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Swedish_Tens (Value / 10);
         else
            return Swedish_Tens (Value / 10) & " "
              & Swedish_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Swedish_Under_20 (Value / 100) & " hundra";
         else
            return Swedish_Under_20 (Value / 100) & " hundra "
              & Swedish_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Swedish_Number (Value / 1_000) & " tusen";
         else
            return Swedish_Number (Value / 1_000) & " tusen "
              & Swedish_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "en miljon";
            else
               return Swedish_Number (Value / 1_000_000) & " miljoner";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "en miljon " & Swedish_Number (Value mod 1_000_000);
            else
               return Swedish_Number (Value / 1_000_000) & " miljoner "
                 & Swedish_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Swedish_Number;

   function Swedish_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nollte";
         when 1 =>
            return "f" & U (16#F6#) & "rsta";
         when 2 =>
            return "andra";
         when 3 =>
            return "tredje";
         when 4 =>
            return "fj" & U (16#E4#) & "rde";
         when 5 =>
            return "femte";
         when 6 =>
            return "sj" & U (16#E4#) & "tte";
         when 7 =>
            return "sjunde";
         when 8 =>
            return U (16#E5#) & "ttonde";
         when 9 =>
            return "nionde";
         when 10 =>
            return "tionde";
         when 11 =>
            return "elfte";
         when 12 =>
            return "tolfte";
         when 13 =>
            return "trettonde";
         when 14 =>
            return "fjortonde";
         when 15 =>
            return "femtonde";
         when 16 =>
            return "sextonde";
         when 17 =>
            return "sjuttonde";
         when 18 =>
            return "artonde";
         when 19 =>
            return "nittonde";
         when others =>
            return "";
      end case;
   end Swedish_Ordinal_Under_20;

   function Swedish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tjugonde";
         when 3 =>
            return "trettionde";
         when 4 =>
            return "fyrtionde";
         when 5 =>
            return "femtionde";
         when 6 =>
            return "sextionde";
         when 7 =>
            return "sjuttionde";
         when 8 =>
            return U (16#E5#) & "ttionde";
         when 9 =>
            return "nittionde";
         when others =>
            return "";
      end case;
   end Swedish_Tens_Ordinal;

   function Swedish_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Swedish_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Swedish_Tens_Ordinal (Value / 10);
         else
            return Swedish_Tens (Value / 10) & " "
              & Swedish_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Swedish_Under_20 (Value / 100) & " hundrade";
         else
            return Swedish_Under_20 (Value / 100) & " hundra "
              & Swedish_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Swedish_Number (Value / 1_000) & " tusende";
         else
            return Swedish_Number (Value / 1_000) & " tusen "
              & Swedish_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "miljonte";
            else
               return Swedish_Number (Value / 1_000_000) & " miljonte";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "en miljon " & Swedish_Ordinal (Value mod 1_000_000);
            else
               return Swedish_Number (Value / 1_000_000) & " miljoner "
                 & Swedish_Ordinal (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Swedish_Ordinal;

   function Danish_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nul";
         when 1 =>
            return "en";
         when 2 =>
            return "to";
         when 3 =>
            return "tre";
         when 4 =>
            return "fire";
         when 5 =>
            return "fem";
         when 6 =>
            return "seks";
         when 7 =>
            return "syv";
         when 8 =>
            return "otte";
         when 9 =>
            return "ni";
         when 10 =>
            return "ti";
         when 11 =>
            return "elleve";
         when 12 =>
            return "tolv";
         when 13 =>
            return "tretten";
         when 14 =>
            return "fjorten";
         when 15 =>
            return "femten";
         when 16 =>
            return "seksten";
         when 17 =>
            return "sytten";
         when 18 =>
            return "atten";
         when 19 =>
            return "nitten";
         when others =>
            return "";
      end case;
   end Danish_Under_20;

   function Danish_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tyve";
         when 3 =>
            return "tredive";
         when 4 =>
            return "fyrre";
         when 5 =>
            return "halvtreds";
         when 6 =>
            return "tres";
         when 7 =>
            return "halvfjerds";
         when 8 =>
            return "firs";
         when 9 =>
            return "halvfems";
         when others =>
            return "";
      end case;
   end Danish_Tens;

   function Danish_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Danish_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Danish_Tens (Value / 10);
         else
            return Danish_Under_20 (Value mod 10) & "og"
              & Danish_Tens (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "et hundrede";
            else
               return Danish_Under_20 (Value / 100) & " hundrede";
            end if;
         else
            if Value / 100 = 1 then
               return "et hundrede " & Danish_Number (Value mod 100);
            else
               return Danish_Under_20 (Value / 100) & " hundrede "
                 & Danish_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "et tusind";
            else
               return Danish_Number (Value / 1_000) & " tusind";
            end if;
         else
            if Value / 1_000 = 1 then
               return "et tusind " & Danish_Number (Value mod 1_000);
            else
               return Danish_Number (Value / 1_000) & " tusind "
                 & Danish_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "en million";
            else
               return Danish_Number (Value / 1_000_000) & " millioner";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "en million " & Danish_Number (Value mod 1_000_000);
            else
               return Danish_Number (Value / 1_000_000) & " millioner "
                 & Danish_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Danish_Number;

   function Danish_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nulende";
         when 1 =>
            return "f" & U (16#F8#) & "rste";
         when 2 =>
            return "anden";
         when 3 =>
            return "tredje";
         when 4 =>
            return "fjerde";
         when 5 =>
            return "femte";
         when 6 =>
            return "sjette";
         when 7 =>
            return "syvende";
         when 8 =>
            return "ottende";
         when 9 =>
            return "niende";
         when 10 =>
            return "tiende";
         when 11 =>
            return "ellevte";
         when 12 =>
            return "tolvte";
         when 13 =>
            return "trettende";
         when 14 =>
            return "fjortende";
         when 15 =>
            return "femtende";
         when 16 =>
            return "sekstende";
         when 17 =>
            return "syttende";
         when 18 =>
            return "attende";
         when 19 =>
            return "nittende";
         when others =>
            return "";
      end case;
   end Danish_Ordinal_Under_20;

   function Danish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tyvende";
         when 3 =>
            return "tredivte";
         when 4 =>
            return "fyrretyvende";
         when 5 =>
            return "halvtredsindstyvende";
         when 6 =>
            return "tresindstyvende";
         when 7 =>
            return "halvfjerdsindstyvende";
         when 8 =>
            return "firsindstyvende";
         when 9 =>
            return "halvfemsindstyvende";
         when others =>
            return "";
      end case;
   end Danish_Tens_Ordinal;

   function Danish_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Danish_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Danish_Tens_Ordinal (Value / 10);
         else
            return Danish_Under_20 (Value mod 10) & "og"
              & Danish_Tens_Ordinal (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Danish_Number (Value / 100) & " hundrede";
         else
            return Danish_Number (Value / 100) & " hundrede "
              & Danish_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Danish_Number (Value / 1_000) & " tusinde";
         else
            return Danish_Number (Value / 1_000) & " tusind "
              & Danish_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Danish_Number (Value / 1_000_000) & " millionte";
         else
            if Value / 1_000_000 = 1 then
               return "en million " & Danish_Ordinal (Value mod 1_000_000);
            else
               return Danish_Number (Value / 1_000_000) & " millioner "
                 & Danish_Ordinal (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Danish_Ordinal;

   function Norwegian_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "null";
         when 1 =>
            return "en";
         when 2 =>
            return "to";
         when 3 =>
            return "tre";
         when 4 =>
            return "fire";
         when 5 =>
            return "fem";
         when 6 =>
            return "seks";
         when 7 =>
            return "sju";
         when 8 =>
            return U (16#E5#) & "tte";
         when 9 =>
            return "ni";
         when 10 =>
            return "ti";
         when 11 =>
            return "elleve";
         when 12 =>
            return "tolv";
         when 13 =>
            return "tretten";
         when 14 =>
            return "fjorten";
         when 15 =>
            return "femten";
         when 16 =>
            return "seksten";
         when 17 =>
            return "sytten";
         when 18 =>
            return "atten";
         when 19 =>
            return "nitten";
         when others =>
            return "";
      end case;
   end Norwegian_Under_20;

   function Norwegian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tjue";
         when 3 =>
            return "tretti";
         when 4 =>
            return "f" & U (16#F8#) & "rti";
         when 5 =>
            return "femti";
         when 6 =>
            return "seksti";
         when 7 =>
            return "sytti";
         when 8 =>
            return U (16#E5#) & "tti";
         when 9 =>
            return "nitti";
         when others =>
            return "";
      end case;
   end Norwegian_Tens;

   function Norwegian_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Norwegian_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Norwegian_Tens (Value / 10);
         else
            return Norwegian_Tens (Value / 10)
              & Norwegian_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "ett hundre";
            else
               return Norwegian_Under_20 (Value / 100) & " hundre";
            end if;
         else
            if Value / 100 = 1 then
               return "ett hundre " & Norwegian_Number (Value mod 100);
            else
               return Norwegian_Under_20 (Value / 100) & " hundre "
                 & Norwegian_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "ett tusen";
            else
               return Norwegian_Number (Value / 1_000) & " tusen";
            end if;
         else
            if Value / 1_000 = 1 then
               return "ett tusen " & Norwegian_Number (Value mod 1_000);
            else
               return Norwegian_Number (Value / 1_000) & " tusen "
                 & Norwegian_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "en million";
            else
               return Norwegian_Number (Value / 1_000_000) & " millioner";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "en million "
                 & Norwegian_Number (Value mod 1_000_000);
            else
               return Norwegian_Number (Value / 1_000_000) & " millioner "
                 & Norwegian_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Norwegian_Number;

   function Norwegian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nullte";
         when 1 =>
            return "f" & U (16#F8#) & "rste";
         when 2 =>
            return "andre";
         when 3 =>
            return "tredje";
         when 4 =>
            return "fjerde";
         when 5 =>
            return "femte";
         when 6 =>
            return "sjette";
         when 7 =>
            return "sjuende";
         when 8 =>
            return U (16#E5#) & "ttende";
         when 9 =>
            return "niende";
         when 10 =>
            return "tiende";
         when 11 =>
            return "ellevte";
         when 12 =>
            return "tolvte";
         when 13 =>
            return "trettende";
         when 14 =>
            return "fjortende";
         when 15 =>
            return "femtende";
         when 16 =>
            return "sekstende";
         when 17 =>
            return "syttende";
         when 18 =>
            return "attende";
         when 19 =>
            return "nittende";
         when others =>
            return "";
      end case;
   end Norwegian_Ordinal_Under_20;

   function Norwegian_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "tjuende";
         when 3 =>
            return "trettiende";
         when 4 =>
            return "f" & U (16#F8#) & "rtiende";
         when 5 =>
            return "femtiende";
         when 6 =>
            return "sekstiende";
         when 7 =>
            return "syttiende";
         when 8 =>
            return U (16#E5#) & "ttiende";
         when 9 =>
            return "nittiende";
         when others =>
            return "";
      end case;
   end Norwegian_Tens_Ordinal;

   function Norwegian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Norwegian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Norwegian_Tens_Ordinal (Value / 10);
         else
            return Norwegian_Tens (Value / 10)
              & Norwegian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Norwegian_Number (Value / 100) & " hundrede";
         else
            return Norwegian_Number (Value / 100) & " hundre "
              & Norwegian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Norwegian_Number (Value / 1_000) & " tusende";
         else
            return Norwegian_Number (Value / 1_000) & " tusen "
              & Norwegian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Norwegian_Number (Value / 1_000_000) & " millionte";
         else
            if Value / 1_000_000 = 1 then
               return "en million "
                 & Norwegian_Ordinal (Value mod 1_000_000);
            else
               return Norwegian_Number (Value / 1_000_000) & " millioner "
                 & Norwegian_Ordinal (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Norwegian_Ordinal;

   function Finnish_Under_10 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nolla";
         when 1 =>
            return "yksi";
         when 2 =>
            return "kaksi";
         when 3 =>
            return "kolme";
         when 4 =>
            return "nelj" & U (16#E4#);
         when 5 =>
            return "viisi";
         when 6 =>
            return "kuusi";
         when 7 =>
            return "seitsem" & U (16#E4#) & "n";
         when 8 =>
            return "kahdeksan";
         when 9 =>
            return "yhdeks" & U (16#E4#) & "n";
         when others =>
            return "";
      end case;
   end Finnish_Under_10;

   function Finnish_Under_20 (Value : Natural) return String is
   begin
      if Value < 10 then
         return Finnish_Under_10 (Value);
      elsif Value = 10 then
         return "kymmenen";
      else
         return Finnish_Under_10 (Value mod 10) & "toista";
      end if;
   end Finnish_Under_20;

   function Finnish_Tens (Value : Natural) return String is
   begin
      if Value = 1 then
         return "kymmenen";
      elsif Value in 2 .. 9 then
         return Finnish_Under_10 (Value) & "kymment" & U (16#E4#);
      else
         return "";
      end if;
   end Finnish_Tens;

   function Finnish_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Finnish_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Finnish_Tens (Value / 10);
         else
            return Finnish_Tens (Value / 10)
              & Finnish_Under_10 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "sata";
            else
               return Finnish_Under_10 (Value / 100) & "sataa";
            end if;
         else
            if Value / 100 = 1 then
               return "sata " & Finnish_Number (Value mod 100);
            else
               return Finnish_Under_10 (Value / 100) & "sataa "
                 & Finnish_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "tuhat";
            else
               return Finnish_Number (Value / 1_000) & "tuhatta";
            end if;
         else
            if Value / 1_000 = 1 then
               return "tuhat " & Finnish_Number (Value mod 1_000);
            else
               return Finnish_Number (Value / 1_000) & "tuhatta "
                 & Finnish_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "miljoona";
            else
               return Finnish_Number (Value / 1_000_000) & " miljoonaa";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "miljoona " & Finnish_Number (Value mod 1_000_000);
            else
               return Finnish_Number (Value / 1_000_000) & " miljoonaa "
                 & Finnish_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Finnish_Number;

   function Finnish_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nollas";
         when 1 =>
            return "ensimm" & U (16#E4#) & "inen";
         when 2 =>
            return "toinen";
         when 3 =>
            return "kolmas";
         when 4 =>
            return "nelj" & U (16#E4#) & "s";
         when 5 =>
            return "viides";
         when 6 =>
            return "kuudes";
         when 7 =>
            return "seitsem" & U (16#E4#) & "s";
         when 8 =>
            return "kahdeksas";
         when 9 =>
            return "yhdeks" & U (16#E4#) & "s";
         when 10 =>
            return "kymmenes";
         when 11 =>
            return "yhdestoista";
         when 12 =>
            return "kahdestoista";
         when 13 =>
            return "kolmastoista";
         when 14 =>
            return "nelj" & U (16#E4#) & "stoista";
         when 15 =>
            return "viidestoista";
         when 16 =>
            return "kuudestoista";
         when 17 =>
            return "seitsem" & U (16#E4#) & "stoista";
         when 18 =>
            return "kahdeksastoista";
         when 19 =>
            return "yhdeks" & U (16#E4#) & "stoista";
         when others =>
            return "";
      end case;
   end Finnish_Ordinal_Under_20;

   function Finnish_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "kahdeskymmenes";
         when 3 =>
            return "kolmaskymmenes";
         when 4 =>
            return "nelj" & U (16#E4#) & "skymmenes";
         when 5 =>
            return "viideskymmenes";
         when 6 =>
            return "kuudeskymmenes";
         when 7 =>
            return "seitsem" & U (16#E4#) & "skymmenes";
         when 8 =>
            return "kahdeksaskymmenes";
         when 9 =>
            return "yhdeks" & U (16#E4#) & "skymmenes";
         when others =>
            return "";
      end case;
   end Finnish_Tens_Ordinal;

   function Finnish_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Finnish_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Finnish_Tens_Ordinal (Value / 10);
         else
            return Finnish_Tens_Ordinal (Value / 10) & " "
              & Finnish_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value = 100 then
               return "sadas";
            else
               return Finnish_Number (Value / 100) & "sadas";
            end if;
         else
            if Value / 100 = 1 then
               return "sata " & Finnish_Ordinal (Value mod 100);
            else
               return Finnish_Number (Value / 100) & "sataa "
                 & Finnish_Ordinal (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value = 1_000 then
               return "tuhannes";
            else
               return Finnish_Number (Value / 1_000) & "tuhannes";
            end if;
         else
            if Value / 1_000 = 1 then
               return "tuhat " & Finnish_Ordinal (Value mod 1_000);
            else
               return Finnish_Number (Value / 1_000) & "tuhatta "
                 & Finnish_Ordinal (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value = 1_000_000 then
               return "miljoonas";
            else
               return Finnish_Number (Value / 1_000_000) & " miljoonas";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "miljoona " & Finnish_Ordinal (Value mod 1_000_000);
            else
               return Finnish_Number (Value / 1_000_000) & " miljoonaa "
                 & Finnish_Ordinal (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Finnish_Ordinal;

   function Indonesian_Under_10 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nol";
         when 1 =>
            return "satu";
         when 2 =>
            return "dua";
         when 3 =>
            return "tiga";
         when 4 =>
            return "empat";
         when 5 =>
            return "lima";
         when 6 =>
            return "enam";
         when 7 =>
            return "tujuh";
         when 8 =>
            return "delapan";
         when 9 =>
            return "sembilan";
         when others =>
            return "";
      end case;
   end Indonesian_Under_10;

   function Indonesian_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Indonesian_Under_10 (Value);
      elsif Value = 10 then
         return "sepuluh";
      elsif Value = 11 then
         return "sebelas";
      elsif Value < 20 then
         return Indonesian_Under_10 (Value mod 10) & " belas";
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Indonesian_Under_10 (Value / 10) & " puluh";
         else
            return Indonesian_Under_10 (Value / 10) & " puluh "
              & Indonesian_Under_10 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "seratus";
            else
               return Indonesian_Under_10 (Value / 100) & " ratus";
            end if;
         else
            if Value / 100 = 1 then
               return "seratus " & Indonesian_Number (Value mod 100);
            else
               return Indonesian_Under_10 (Value / 100) & " ratus "
                 & Indonesian_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "seribu";
            else
               return Indonesian_Number (Value / 1_000) & " ribu";
            end if;
         else
            if Value / 1_000 = 1 then
               return "seribu " & Indonesian_Number (Value mod 1_000);
            else
               return Indonesian_Number (Value / 1_000) & " ribu "
                 & Indonesian_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "sejuta";
            else
               return Indonesian_Number (Value / 1_000_000) & " juta";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "sejuta " & Indonesian_Number (Value mod 1_000_000);
            else
               return Indonesian_Number (Value / 1_000_000) & " juta "
                 & Indonesian_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Indonesian_Number;

   function Indonesian_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "pertama";
      else
         return "ke-" & Indonesian_Number (Value);
      end if;
   end Indonesian_Ordinal;

   function Malay_Under_10 (Value : Natural) return String is
   begin
      if Value = 0 then
         return "sifar";
      else
         return Indonesian_Under_10 (Value);
      end if;
   end Malay_Under_10;

   function Malay_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Malay_Under_10 (Value);
      elsif Value = 10 then
         return "sepuluh";
      elsif Value = 11 then
         return "sebelas";
      elsif Value < 20 then
         return Malay_Under_10 (Value mod 10) & " belas";
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Malay_Under_10 (Value / 10) & " puluh";
         else
            return Malay_Under_10 (Value / 10) & " puluh "
              & Malay_Under_10 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "seratus";
            else
               return Malay_Under_10 (Value / 100) & " ratus";
            end if;
         else
            if Value / 100 = 1 then
               return "seratus " & Malay_Number (Value mod 100);
            else
               return Malay_Under_10 (Value / 100) & " ratus "
                 & Malay_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "seribu";
            else
               return Malay_Number (Value / 1_000) & " ribu";
            end if;
         else
            if Value / 1_000 = 1 then
               return "seribu " & Malay_Number (Value mod 1_000);
            else
               return Malay_Number (Value / 1_000) & " ribu "
                 & Malay_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "sejuta";
            else
               return Malay_Number (Value / 1_000_000) & " juta";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "sejuta " & Malay_Number (Value mod 1_000_000);
            else
               return Malay_Number (Value / 1_000_000) & " juta "
                 & Malay_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Malay_Number;

   function Malay_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "pertama";
      else
         return "ke-" & Malay_Number (Value);
      end if;
   end Malay_Ordinal;

   function Esperanto_Under_10 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nulo";
         when 1 =>
            return "unu";
         when 2 =>
            return "du";
         when 3 =>
            return "tri";
         when 4 =>
            return "kvar";
         when 5 =>
            return "kvin";
         when 6 =>
            return "ses";
         when 7 =>
            return "sep";
         when 8 =>
            return "ok";
         when 9 =>
            return "na" & U (16#16D#);
         when others =>
            return "";
      end case;
   end Esperanto_Under_10;

   function Esperanto_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Esperanto_Under_10 (Value);
      elsif Value < 20 then
         if Value = 10 then
            return "dek";
         else
            return "dek " & Esperanto_Under_10 (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Esperanto_Under_10 (Value / 10) & "dek";
         else
            return Esperanto_Under_10 (Value / 10) & "dek "
              & Esperanto_Under_10 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "cent";
            else
               return Esperanto_Under_10 (Value / 100) & "cent";
            end if;
         else
            if Value / 100 = 1 then
               return "cent " & Esperanto_Number (Value mod 100);
            else
               return Esperanto_Under_10 (Value / 100) & "cent "
                 & Esperanto_Number (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "mil";
            else
               return Esperanto_Number (Value / 1_000) & " mil";
            end if;
         else
            if Value / 1_000 = 1 then
               return "mil " & Esperanto_Number (Value mod 1_000);
            else
               return Esperanto_Number (Value / 1_000) & " mil "
                 & Esperanto_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "miliono";
            else
               return Esperanto_Number (Value / 1_000_000) & " milionoj";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "miliono " & Esperanto_Number (Value mod 1_000_000);
            else
               return Esperanto_Number (Value / 1_000_000) & " milionoj "
                 & Esperanto_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Esperanto_Number;

   function Esperanto_Ordinal (Value : Natural) return String is
   begin
      if Value < 10 then
         case Value is
            when 0 =>
               return "nula";
            when 1 =>
               return "unua";
            when 2 =>
               return "dua";
            when 3 =>
               return "tria";
            when 4 =>
               return "kvara";
            when 5 =>
               return "kvina";
            when 6 =>
               return "sesa";
            when 7 =>
               return "sepa";
            when 8 =>
               return "oka";
            when 9 =>
               return "na" & U (16#16D#) & "a";
            when others =>
               return "";
         end case;
      elsif Value < 20 then
         if Value = 10 then
            return "deka";
         else
            return "dek " & Esperanto_Ordinal (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Esperanto_Under_10 (Value / 10) & "deka";
         else
            return Esperanto_Under_10 (Value / 10) & "dek "
              & Esperanto_Ordinal (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            if Value / 100 = 1 then
               return "centa";
            else
               return Esperanto_Under_10 (Value / 100) & "centa";
            end if;
         else
            if Value / 100 = 1 then
               return "cent " & Esperanto_Ordinal (Value mod 100);
            else
               return Esperanto_Under_10 (Value / 100) & "cent "
                 & Esperanto_Ordinal (Value mod 100);
            end if;
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "mila";
            else
               return Esperanto_Number (Value / 1_000) & " mila";
            end if;
         else
            if Value / 1_000 = 1 then
               return "mil " & Esperanto_Ordinal (Value mod 1_000);
            else
               return Esperanto_Number (Value / 1_000) & " mil "
                 & Esperanto_Ordinal (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "miliona";
            else
               return Esperanto_Number (Value / 1_000_000) & " miliona";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "miliono " & Esperanto_Ordinal (Value mod 1_000_000);
            else
               return Esperanto_Number (Value / 1_000_000) & " milionoj "
                 & Esperanto_Ordinal (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Esperanto_Ordinal;

   function Vietnamese_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "kh" & U (16#F4#) & "ng";
         when 1 =>
            return "m" & U (16#1ED9#) & "t";
         when 2 =>
            return "hai";
         when 3 =>
            return "ba";
         when 4 =>
            return "b" & U (16#1ED1#) & "n";
         when 5 =>
            return "n" & U (16#103#) & "m";
         when 6 =>
            return "s" & U (16#E1#) & "u";
         when 7 =>
            return "b" & U (16#1EA3#) & "y";
         when 8 =>
            return "t" & U (16#E1#) & "m";
         when 9 =>
            return "ch" & U (16#ED#) & "n";
         when others =>
            return "";
      end case;
   end Vietnamese_Digit;

   function Vietnamese_Ten return String is
   begin
      return "m" & U (16#1B0#) & U (16#1EDD#) & "i";
   end Vietnamese_Ten;

   function Vietnamese_Tens_Unit (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "m" & U (16#1ED1#) & "t";
         when 5 =>
            return "l" & U (16#103#) & "m";
         when others =>
            return Vietnamese_Digit (Value);
      end case;
   end Vietnamese_Tens_Unit;

   function Vietnamese_Under_100 (Value : Natural) return String is
      Tens_Word : constant String := "m" & U (16#1B0#) & U (16#1A1#) & "i";
   begin
      if Value < 10 then
         return Vietnamese_Digit (Value);
      elsif Value < 20 then
         if Value = 10 then
            return Vietnamese_Ten;
         elsif Value = 15 then
            return Vietnamese_Ten & " " & Vietnamese_Tens_Unit (5);
         else
            return Vietnamese_Ten & " " & Vietnamese_Digit (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Vietnamese_Digit (Value / 10) & " " & Tens_Word;
         else
            return Vietnamese_Digit (Value / 10) & " " & Tens_Word & " "
              & Vietnamese_Tens_Unit (Value mod 10);
         end if;
      else
         return "";
      end if;
   end Vietnamese_Under_100;

   function Vietnamese_Number (Value : Natural) return String is
   begin
      if Value < 100 then
         return Vietnamese_Under_100 (Value);
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Vietnamese_Digit (Value / 100) & " tr" & U (16#103#) & "m";
         elsif Value mod 100 < 10 then
            return Vietnamese_Digit (Value / 100) & " tr" & U (16#103#)
              & "m linh " & Vietnamese_Digit (Value mod 100);
         else
            return Vietnamese_Digit (Value / 100) & " tr" & U (16#103#)
              & "m " & Vietnamese_Under_100 (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Vietnamese_Number (Value / 1_000) & " ngh" & U (16#EC#)
              & "n";
         else
            return Vietnamese_Number (Value / 1_000) & " ngh" & U (16#EC#)
              & "n " & Vietnamese_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Vietnamese_Number (Value / 1_000_000) & " tri" & U (16#1EC7#)
              & "u";
         else
            return Vietnamese_Number (Value / 1_000_000) & " tri" & U (16#1EC7#)
              & "u " & Vietnamese_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Vietnamese_Number;

   function Vietnamese_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "th" & U (16#1EE9#) & " nh" & U (16#1EA5#) & "t";
      else
         return "th" & U (16#1EE9#) & " " & Vietnamese_Number (Value);
      end if;
   end Vietnamese_Ordinal;

   function Swahili_Under_10 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "sifuri";
         when 1 =>
            return "moja";
         when 2 =>
            return "mbili";
         when 3 =>
            return "tatu";
         when 4 =>
            return "nne";
         when 5 =>
            return "tano";
         when 6 =>
            return "sita";
         when 7 =>
            return "saba";
         when 8 =>
            return "nane";
         when 9 =>
            return "tisa";
         when others =>
            return "";
      end case;
   end Swahili_Under_10;

   function Swahili_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "ishirini";
         when 3 =>
            return "thelathini";
         when 4 =>
            return "arobaini";
         when 5 =>
            return "hamsini";
         when 6 =>
            return "sitini";
         when 7 =>
            return "sabini";
         when 8 =>
            return "themanini";
         when 9 =>
            return "tisini";
         when others =>
            return "";
      end case;
   end Swahili_Tens;

   function Swahili_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Swahili_Under_10 (Value);
      elsif Value < 20 then
         if Value = 10 then
            return "kumi";
         else
            return "kumi na " & Swahili_Under_10 (Value mod 10);
         end if;
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Swahili_Tens (Value / 10);
         else
            return Swahili_Tens (Value / 10) & " na "
              & Swahili_Under_10 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return "mia " & Swahili_Under_10 (Value / 100);
         else
            return "mia " & Swahili_Under_10 (Value / 100) & " "
              & Swahili_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return "elfu " & Swahili_Number (Value / 1_000);
         else
            return "elfu " & Swahili_Number (Value / 1_000) & " "
              & Swahili_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return "milioni " & Swahili_Number (Value / 1_000_000);
         else
            return "milioni " & Swahili_Number (Value / 1_000_000) & " "
              & Swahili_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Swahili_Number;

   function Swahili_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "kwanza";
      else
         return "wa " & Swahili_Number (Value);
      end if;
   end Swahili_Ordinal;

   function Afrikaans_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nul";
         when 1 =>
            return "een";
         when 2 =>
            return "twee";
         when 3 =>
            return "drie";
         when 4 =>
            return "vier";
         when 5 =>
            return "vyf";
         when 6 =>
            return "ses";
         when 7 =>
            return "sewe";
         when 8 =>
            return "agt";
         when 9 =>
            return "nege";
         when 10 =>
            return "tien";
         when 11 =>
            return "elf";
         when 12 =>
            return "twaalf";
         when 13 =>
            return "dertien";
         when 14 =>
            return "veertien";
         when 15 =>
            return "vyftien";
         when 16 =>
            return "sestien";
         when 17 =>
            return "sewentien";
         when 18 =>
            return "agtien";
         when 19 =>
            return "negentien";
         when others =>
            return "";
      end case;
   end Afrikaans_Under_20;

   function Afrikaans_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "twintig";
         when 3 =>
            return "dertig";
         when 4 =>
            return "veertig";
         when 5 =>
            return "vyftig";
         when 6 =>
            return "sestig";
         when 7 =>
            return "sewentig";
         when 8 =>
            return "tagtig";
         when 9 =>
            return "negentig";
         when others =>
            return "";
      end case;
   end Afrikaans_Tens;

   function Afrikaans_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Afrikaans_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Afrikaans_Tens (Value / 10);
         else
            return Afrikaans_Under_20 (Value mod 10) & " en "
              & Afrikaans_Tens (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Afrikaans_Under_20 (Value / 100) & " honderd";
         else
            return Afrikaans_Under_20 (Value / 100) & " honderd "
              & Afrikaans_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Afrikaans_Number (Value / 1_000) & " duisend";
         else
            return Afrikaans_Number (Value / 1_000) & " duisend "
              & Afrikaans_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Afrikaans_Number (Value / 1_000_000) & " miljoen";
         else
            return Afrikaans_Number (Value / 1_000_000) & " miljoen "
              & Afrikaans_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Afrikaans_Number;

   function Afrikaans_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nulde";
         when 1 =>
            return "eerste";
         when 2 =>
            return "tweede";
         when 3 =>
            return "derde";
         when 4 =>
            return "vierde";
         when 5 =>
            return "vyfde";
         when 6 =>
            return "sesde";
         when 7 =>
            return "sewende";
         when 8 =>
            return "agtste";
         when 9 =>
            return "negende";
         when 10 =>
            return "tiende";
         when 11 =>
            return "elfde";
         when 12 =>
            return "twaalfde";
         when 13 =>
            return "dertiende";
         when 14 =>
            return "veertiende";
         when 15 =>
            return "vyftiende";
         when 16 =>
            return "sestiende";
         when 17 =>
            return "sewentiende";
         when 18 =>
            return "agtiende";
         when 19 =>
            return "negentiende";
         when others =>
            return "";
      end case;
   end Afrikaans_Ordinal_Under_20;

   function Afrikaans_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "twintigste";
         when 3 =>
            return "dertigste";
         when 4 =>
            return "veertigste";
         when 5 =>
            return "vyftigste";
         when 6 =>
            return "sestigste";
         when 7 =>
            return "sewentigste";
         when 8 =>
            return "tagtigste";
         when 9 =>
            return "negentigste";
         when others =>
            return "";
      end case;
   end Afrikaans_Tens_Ordinal;

   function Afrikaans_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Afrikaans_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Afrikaans_Tens_Ordinal (Value / 10);
         else
            return Afrikaans_Under_20 (Value mod 10) & " en "
              & Afrikaans_Tens_Ordinal (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Afrikaans_Number (Value / 100) & " honderdste";
         else
            return Afrikaans_Number (Value / 100) & " honderd "
              & Afrikaans_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Afrikaans_Number (Value / 1_000) & " duisendste";
         else
            return Afrikaans_Number (Value / 1_000) & " duisend "
              & Afrikaans_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Afrikaans_Number (Value / 1_000_000) & " miljoenste";
         else
            return Afrikaans_Number (Value / 1_000_000) & " miljoen "
              & Afrikaans_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Afrikaans_Ordinal;

   function Basque_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "bat";
         when 2 =>
            return "bi";
         when 3 =>
            return "hiru";
         when 4 =>
            return "lau";
         when 5 =>
            return "bost";
         when 6 =>
            return "sei";
         when 7 =>
            return "zazpi";
         when 8 =>
            return "zortzi";
         when 9 =>
            return "bederatzi";
         when 10 =>
            return "hamar";
         when 11 =>
            return "hamaika";
         when 12 =>
            return "hamabi";
         when 13 =>
            return "hamahiru";
         when 14 =>
            return "hamalau";
         when 15 =>
            return "hamabost";
         when 16 =>
            return "hamasei";
         when 17 =>
            return "hamazazpi";
         when 18 =>
            return "hemezortzi";
         when 19 =>
            return "hemeretzi";
         when others =>
            return "";
      end case;
   end Basque_Under_20;

   function Basque_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Basque_Under_20 (Value);
      elsif Value < 100 then
         if Value < 40 then
            if Value = 20 then
               return "hogei";
            else
               return "hogeita " & Basque_Under_20 (Value - 20);
            end if;
         elsif Value < 60 then
            if Value = 40 then
               return "berrogei";
            elsif Value = 50 then
               return "berrogeita hamar";
            elsif Value < 50 then
               return "berrogeita " & Basque_Under_20 (Value - 40);
            else
               return "berrogeita " & Basque_Under_20 (Value - 40);
            end if;
         elsif Value < 80 then
            if Value = 60 then
               return "hirurogei";
            else
               return "hirurogeita " & Basque_Under_20 (Value - 60);
            end if;
         else
            if Value = 80 then
               return "laurogei";
            else
               return "laurogeita " & Basque_Under_20 (Value - 80);
            end if;
         end if;
      elsif Value < 1_000 then
         declare
            Hundreds : constant Natural := Value / 100;
            Remainder : constant Natural := Value mod 100;
            Prefix : constant String :=
              (case Hundreds is
                  when 1 => "ehun",
                  when 2 => "berrehun",
                  when 3 => "hirurehun",
                  when 4 => "laurehun",
                  when 5 => "bostehun",
                  when 6 => "seiehun",
                  when 7 => "zazpiehun",
                  when 8 => "zortziehun",
                  when 9 => "bederatziehun",
                  when others => "");
         begin
            if Remainder = 0 then
               return Prefix;
            else
               return Prefix & " eta " & Basque_Number (Remainder);
            end if;
         end;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            if Value / 1_000 = 1 then
               return "mila";
            else
               return Basque_Number (Value / 1_000) & " mila";
            end if;
         else
            if Value / 1_000 = 1 then
               return "mila " & Basque_Number (Value mod 1_000);
            else
               return Basque_Number (Value / 1_000) & " mila "
                 & Basque_Number (Value mod 1_000);
            end if;
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            if Value / 1_000_000 = 1 then
               return "milioi bat";
            else
               return Basque_Number (Value / 1_000_000) & " milioi";
            end if;
         else
            if Value / 1_000_000 = 1 then
               return "milioi bat " & Basque_Number (Value mod 1_000_000);
            else
               return Basque_Number (Value / 1_000_000) & " milioi "
                 & Basque_Number (Value mod 1_000_000);
            end if;
         end if;
      else
         return "";
      end if;
   end Basque_Number;

   function Basque_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "lehen";
      elsif Value = 2 then
         return "bigarren";
      else
         return Basque_Number (Value) & "garren";
      end if;
   end Basque_Ordinal;

   function Romanian_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "unu";
         when 2 =>
            return "doi";
         when 3 =>
            return "trei";
         when 4 =>
            return "patru";
         when 5 =>
            return "cinci";
         when 6 =>
            return U (16#219#) & "ase";
         when 7 =>
            return U (16#219#) & "apte";
         when 8 =>
            return "opt";
         when 9 =>
            return "nou" & U (16#103#);
         when 10 =>
            return "zece";
         when 11 =>
            return "unsprezece";
         when 12 =>
            return "doisprezece";
         when 13 =>
            return "treisprezece";
         when 14 =>
            return "paisprezece";
         when 15 =>
            return "cincisprezece";
         when 16 =>
            return U (16#219#) & "aisprezece";
         when 17 =>
            return U (16#219#) & "aptesprezece";
         when 18 =>
            return "optsprezece";
         when 19 =>
            return "nou" & U (16#103#) & "sprezece";
         when others =>
            return "";
      end case;
   end Romanian_Under_20;

   function Romanian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dou" & U (16#103#) & "zeci";
         when 3 =>
            return "treizeci";
         when 4 =>
            return "patruzeci";
         when 5 =>
            return "cincizeci";
         when 6 =>
            return U (16#219#) & "aizeci";
         when 7 =>
            return U (16#219#) & "aptezeci";
         when 8 =>
            return "optzeci";
         when 9 =>
            return "nou" & U (16#103#) & "zeci";
         when others =>
            return "";
      end case;
   end Romanian_Tens;

   function Romanian_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Romanian_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Romanian_Tens (Value / 10);
         else
            return Romanian_Tens (Value / 10) & " " & U (16#219#) & "i "
              & Romanian_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value = 100 then
            return "o sut" & U (16#103#);
         elsif Value mod 100 = 0 then
            return Romanian_Under_20 (Value / 100) & " sute";
         elsif Value < 200 then
            return "o sut" & U (16#103#) & " "
              & Romanian_Number (Value mod 100);
         else
            return Romanian_Under_20 (Value / 100) & " sute "
              & Romanian_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "o mie";
         elsif Value mod 1_000 = 0 then
            return Romanian_Number (Value / 1_000) & " mii";
         elsif Value < 2_000 then
            return "o mie " & Romanian_Number (Value mod 1_000);
         else
            return Romanian_Number (Value / 1_000) & " mii "
              & Romanian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "un milion";
         elsif Value mod 1_000_000 = 0 then
            return Romanian_Number (Value / 1_000_000) & " milioane";
         elsif Value < 2_000_000 then
            return "un milion " & Romanian_Number (Value mod 1_000_000);
         else
            return Romanian_Number (Value / 1_000_000) & " milioane "
              & Romanian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Romanian_Number;

   function Romanian_Ordinal_Tail (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zerolea";
         when 1 =>
            return "unulea";
         when 2 =>
            return "doilea";
         when 3 =>
            return "treilea";
         when 4 =>
            return "patrulea";
         when 5 =>
            return "cincilea";
         when 6 =>
            return U (16#219#) & "aselea";
         when 7 =>
            return U (16#219#) & "aptelea";
         when 8 =>
            return "optulea";
         when 9 =>
            return "nou" & U (16#103#) & "lea";
         when 10 =>
            return "zecelea";
         when 11 =>
            return "unsprezecelea";
         when 12 =>
            return "doisprezecelea";
         when 13 =>
            return "treisprezecelea";
         when 14 =>
            return "paisprezecelea";
         when 15 =>
            return "cincisprezecelea";
         when 16 =>
            return U (16#219#) & "aisprezecelea";
         when 17 =>
            return U (16#219#) & "aptesprezecelea";
         when 18 =>
            return "optsprezecelea";
         when 19 =>
            return "nou" & U (16#103#) & "sprezecelea";
         when others =>
            return "";
      end case;
   end Romanian_Ordinal_Tail;

   function Romanian_Ordinal_Remainder (Value : Natural) return String is
   begin
      if Value < 20 then
         return Romanian_Ordinal_Tail (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Romanian_Tens (Value / 10) & "lea";
         else
            return Romanian_Tens (Value / 10) & " " & U (16#219#) & "i "
              & Romanian_Ordinal_Tail (Value mod 10);
         end if;
      else
         return Romanian_Number (Value);
      end if;
   end Romanian_Ordinal_Remainder;

   function Romanian_Ordinal_Body (Value : Natural) return String is
      Remainder : Natural;
   begin
      if Value < 100 then
         return Romanian_Ordinal_Remainder (Value);
      elsif Value < 1_000 then
         Remainder := Value mod 100;
      elsif Value < 1_000_000 then
         Remainder := Value mod 1_000;
      else
         Remainder := Value mod 1_000_000;
      end if;

      if Remainder = 0 then
         return Romanian_Number (Value) & "lea";
      else
         return Romanian_Number (Value - Remainder) & " "
           & Romanian_Ordinal_Body (Remainder);
      end if;
   end Romanian_Ordinal_Body;

   function Romanian_Ordinal (Value : Natural) return String is
   begin
      if Value = 1 then
         return "primul";
      elsif Value <= 999_999_999 then
         return "al " & Romanian_Ordinal_Body (Value);
      else
         return "";
      end if;
   end Romanian_Ordinal;

   function Catalan_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zero";
         when 1 =>
            return "un";
         when 2 =>
            return "dos";
         when 3 =>
            return "tres";
         when 4 =>
            return "quatre";
         when 5 =>
            return "cinc";
         when 6 =>
            return "sis";
         when 7 =>
            return "set";
         when 8 =>
            return "vuit";
         when 9 =>
            return "nou";
         when 10 =>
            return "deu";
         when 11 =>
            return "onze";
         when 12 =>
            return "dotze";
         when 13 =>
            return "tretze";
         when 14 =>
            return "catorze";
         when 15 =>
            return "quinze";
         when 16 =>
            return "setze";
         when 17 =>
            return "disset";
         when 18 =>
            return "divuit";
         when 19 =>
            return "dinou";
         when others =>
            return "";
      end case;
   end Catalan_Under_20;

   function Catalan_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vint";
         when 3 =>
            return "trenta";
         when 4 =>
            return "quaranta";
         when 5 =>
            return "cinquanta";
         when 6 =>
            return "seixanta";
         when 7 =>
            return "setanta";
         when 8 =>
            return "vuitanta";
         when 9 =>
            return "noranta";
         when others =>
            return "";
      end case;
   end Catalan_Tens;

   function Catalan_Hundreds (Value : Natural) return String is
   begin
      if Value = 1 then
         return "cent";
      else
         return Catalan_Under_20 (Value) & "-cents";
      end if;
   end Catalan_Hundreds;

   function Catalan_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Catalan_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Catalan_Tens (Value / 10);
         elsif Value / 10 = 2 then
            return "vint-i-" & Catalan_Under_20 (Value mod 10);
         else
            return Catalan_Tens (Value / 10) & "-"
              & Catalan_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Catalan_Hundreds (Value / 100);
         else
            return Catalan_Hundreds (Value / 100) & " "
              & Catalan_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "mil";
         elsif Value mod 1_000 = 0 then
            return Catalan_Number (Value / 1_000) & " mil";
         elsif Value < 2_000 then
            return "mil " & Catalan_Number (Value mod 1_000);
         else
            return Catalan_Number (Value / 1_000) & " mil "
              & Catalan_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "un mili" & U (16#F3#);
         elsif Value mod 1_000_000 = 0 then
            return Catalan_Number (Value / 1_000_000) & " milions";
         elsif Value < 2_000_000 then
            return "un mili" & U (16#F3#) & " "
              & Catalan_Number (Value mod 1_000_000);
         else
            return Catalan_Number (Value / 1_000_000) & " milions "
              & Catalan_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Catalan_Number;

   function Catalan_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "zer" & U (16#E8#);
         when 1 =>
            return "primer";
         when 2 =>
            return "segon";
         when 3 =>
            return "tercer";
         when 4 =>
            return "quart";
         when 5 =>
            return "cinqu" & U (16#E8#);
         when 6 =>
            return "sis" & U (16#E8#);
         when 7 =>
            return "set" & U (16#E8#);
         when 8 =>
            return "vuit" & U (16#E8#);
         when 9 =>
            return "nov" & U (16#E8#);
         when 10 =>
            return "des" & U (16#E8#);
         when 11 =>
            return "onz" & U (16#E8#);
         when 12 =>
            return "dotz" & U (16#E8#);
         when 13 =>
            return "tretz" & U (16#E8#);
         when 14 =>
            return "catorz" & U (16#E8#);
         when 15 =>
            return "quinz" & U (16#E8#);
         when 16 =>
            return "setz" & U (16#E8#);
         when 17 =>
            return "disset" & U (16#E8#);
         when 18 =>
            return "divuit" & U (16#E8#);
         when 19 =>
            return "dinov" & U (16#E8#);
         when others =>
            return "";
      end case;
   end Catalan_Ordinal_Under_20;

   function Catalan_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "vint" & U (16#E8#);
         when 3 =>
            return "trent" & U (16#E8#);
         when 4 =>
            return "quarant" & U (16#E8#);
         when 5 =>
            return "cinquant" & U (16#E8#);
         when 6 =>
            return "seixant" & U (16#E8#);
         when 7 =>
            return "setant" & U (16#E8#);
         when 8 =>
            return "vuitant" & U (16#E8#);
         when 9 =>
            return "norant" & U (16#E8#);
         when others =>
            return "";
      end case;
   end Catalan_Tens_Ordinal;

   function Catalan_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Catalan_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Catalan_Tens_Ordinal (Value / 10);
         elsif Value / 10 = 2 then
            return "vint-i-" & Catalan_Ordinal_Under_20 (Value mod 10);
         else
            return Catalan_Tens (Value / 10) & "-"
              & Catalan_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Catalan_Hundreds (Value / 100) & U (16#E8#);
         else
            return Catalan_Hundreds (Value / 100) & " "
              & Catalan_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Catalan_Number (Value / 1_000) & " mil" & U (16#E8#);
         elsif Value < 2_000 then
            return "mil " & Catalan_Ordinal (Value mod 1_000);
         else
            return Catalan_Number (Value / 1_000) & " mil "
              & Catalan_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Catalan_Number (Value / 1_000_000) & " milion" & U (16#E8#);
         elsif Value < 2_000_000 then
            return "un mili" & U (16#F3#) & " "
              & Catalan_Ordinal (Value mod 1_000_000);
         else
            return Catalan_Number (Value / 1_000_000) & " milions "
              & Catalan_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Catalan_Ordinal;

   function Hungarian_Digit (Value : Natural; Compound : Boolean := False)
      return String
   is
   begin
      case Value is
         when 0 =>
            return "nulla";
         when 1 =>
            return "egy";
         when 2 =>
            return (if Compound then "k" & U (16#E9#) & "t"
                    else "kett" & U (16#151#));
         when 3 =>
            return "h" & U (16#E1#) & "rom";
         when 4 =>
            return "n" & U (16#E9#) & "gy";
         when 5 =>
            return U (16#F6#) & "t";
         when 6 =>
            return "hat";
         when 7 =>
            return "h" & U (16#E9#) & "t";
         when 8 =>
            return "nyolc";
         when 9 =>
            return "kilenc";
         when others =>
            return "";
      end case;
   end Hungarian_Digit;

   function Hungarian_Under_20 (Value : Natural) return String is
   begin
      if Value < 10 then
         return Hungarian_Digit (Value);
      end if;

      case Value is
         when 10 =>
            return "t" & U (16#ED#) & "z";
         when 11 =>
            return "tizenegy";
         when 12 =>
            return "tizenkett" & U (16#151#);
         when 13 =>
            return "tizenh" & U (16#E1#) & "rom";
         when 14 =>
            return "tizenn" & U (16#E9#) & "gy";
         when 15 =>
            return "tizen" & U (16#F6#) & "t";
         when 16 =>
            return "tizenhat";
         when 17 =>
            return "tizenh" & U (16#E9#) & "t";
         when 18 =>
            return "tizennyolc";
         when 19 =>
            return "tizenkilenc";
         when others =>
            return "";
      end case;
   end Hungarian_Under_20;

   function Hungarian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "h" & U (16#FA#) & "sz";
         when 3 =>
            return "harminc";
         when 4 =>
            return "negyven";
         when 5 =>
            return U (16#F6#) & "tven";
         when 6 =>
            return "hatvan";
         when 7 =>
            return "hetven";
         when 8 =>
            return "nyolcvan";
         when 9 =>
            return "kilencven";
         when others =>
            return "";
      end case;
   end Hungarian_Tens;

   function Hungarian_Number (Value : Natural) return String is
      function Scale_Prefix (Amount : Natural) return String is
      begin
         if Amount < 10 then
            return Hungarian_Digit (Amount, True);
         else
            return Hungarian_Number (Amount);
         end if;
      end Scale_Prefix;
   begin
      if Value < 20 then
         return Hungarian_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Hungarian_Tens (Value / 10);
         elsif Value / 10 = 2 then
            return "huszon" & Hungarian_Digit (Value mod 10);
         else
            return Hungarian_Tens (Value / 10)
              & Hungarian_Digit (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Hungarian_Digit (Value / 100, True)
              & "sz" & U (16#E1#) & "z";
         else
            return Hungarian_Digit (Value / 100, True)
              & "sz" & U (16#E1#) & "z"
              & Hungarian_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "ezer";
         elsif Value mod 1_000 = 0 then
            return Scale_Prefix (Value / 1_000) & "ezer";
         elsif Value < 2_000 then
            return "ezer-" & Hungarian_Number (Value mod 1_000);
         else
            return Scale_Prefix (Value / 1_000) & "ezer-"
              & Hungarian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "egymilli" & U (16#F3#);
         elsif Value mod 1_000_000 = 0 then
            return Scale_Prefix (Value / 1_000_000) & "milli" & U (16#F3#);
         elsif Value < 2_000_000 then
            return "egymilli" & U (16#F3#) & "-"
              & Hungarian_Number (Value mod 1_000_000);
         else
            return Scale_Prefix (Value / 1_000_000) & "milli" & U (16#F3#)
              & "-" & Hungarian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Hungarian_Number;

   function Hungarian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nulladik";
         when 1 =>
            return "els" & U (16#151#);
         when 2 =>
            return "m" & U (16#E1#) & "sodik";
         when 3 =>
            return "harmadik";
         when 4 =>
            return "negyedik";
         when 5 =>
            return U (16#F6#) & "t" & U (16#F6#) & "dik";
         when 6 =>
            return "hatodik";
         when 7 =>
            return "hetedik";
         when 8 =>
            return "nyolcadik";
         when 9 =>
            return "kilencedik";
         when 10 =>
            return "tizedik";
         when 11 =>
            return "tizenegyedik";
         when 12 =>
            return "tizenkettedik";
         when 13 =>
            return "tizenharmadik";
         when 14 =>
            return "tizennegyedik";
         when 15 =>
            return "tizen" & U (16#F6#) & "t" & U (16#F6#) & "dik";
         when 16 =>
            return "tizenhatodik";
         when 17 =>
            return "tizenhetedik";
         when 18 =>
            return "tizennyolcadik";
         when 19 =>
            return "tizenkilencedik";
         when others =>
            return "";
      end case;
   end Hungarian_Ordinal_Under_20;

   function Hungarian_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "huszadik";
         when 3 =>
            return "harmincadik";
         when 4 =>
            return "negyvenedik";
         when 5 =>
            return U (16#F6#) & "tvenedik";
         when 6 =>
            return "hatvanadik";
         when 7 =>
            return "hetvenedik";
         when 8 =>
            return "nyolcvanadik";
         when 9 =>
            return "kilencvenedik";
         when others =>
            return "";
      end case;
   end Hungarian_Tens_Ordinal;

   function Hungarian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Hungarian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Hungarian_Tens_Ordinal (Value / 10);
         elsif Value / 10 = 2 then
            return "huszon" & Hungarian_Ordinal_Under_20 (Value mod 10);
         else
            return Hungarian_Tens (Value / 10)
              & Hungarian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Hungarian_Number (Value) & "adik";
         else
            return Hungarian_Number (Value - Value mod 100)
              & Hungarian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Hungarian_Number (Value) & "edik";
         else
            return Hungarian_Number (Value - Value mod 1_000) & "-"
              & Hungarian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Hungarian_Number (Value) & "dik";
         else
            return Hungarian_Number (Value - Value mod 1_000_000) & "-"
              & Hungarian_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Hungarian_Ordinal;

   function Slovak_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nula";
         when 1 =>
            return "jeden";
         when 2 =>
            return "dva";
         when 3 =>
            return "tri";
         when 4 =>
            return U (16#161#) & "tyri";
         when 5 =>
            return "p" & U (16#E4#) & U (16#165#);
         when 6 =>
            return U (16#161#) & "es" & U (16#165#);
         when 7 =>
            return "sedem";
         when 8 =>
            return "osem";
         when 9 =>
            return "dev" & U (16#E4#) & U (16#165#);
         when 10 =>
            return "desa" & U (16#165#);
         when 11 =>
            return "jeden" & U (16#E1#) & "s" & U (16#165#);
         when 12 =>
            return "dvan" & U (16#E1#) & "s" & U (16#165#);
         when 13 =>
            return "trin" & U (16#E1#) & "s" & U (16#165#);
         when 14 =>
            return U (16#161#) & "trn" & U (16#E1#) & "s" & U (16#165#);
         when 15 =>
            return "p" & U (16#E4#) & "tn" & U (16#E1#) & "s"
              & U (16#165#);
         when 16 =>
            return U (16#161#) & "estn" & U (16#E1#) & "s" & U (16#165#);
         when 17 =>
            return "sedemn" & U (16#E1#) & "s" & U (16#165#);
         when 18 =>
            return "osemn" & U (16#E1#) & "s" & U (16#165#);
         when 19 =>
            return "dev" & U (16#E4#) & "tn" & U (16#E1#) & "s"
              & U (16#165#);
         when others =>
            return "";
      end case;
   end Slovak_Under_20;

   function Slovak_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dvadsa" & U (16#165#);
         when 3 =>
            return "tridsa" & U (16#165#);
         when 4 =>
            return U (16#161#) & "tyridsa" & U (16#165#);
         when 5 =>
            return "p" & U (16#E4#) & U (16#165#) & "desiat";
         when 6 =>
            return U (16#161#) & "es" & U (16#165#) & "desiat";
         when 7 =>
            return "sedemdesiat";
         when 8 =>
            return "osemdesiat";
         when 9 =>
            return "dev" & U (16#E4#) & U (16#165#) & "desiat";
         when others =>
            return "";
      end case;
   end Slovak_Tens;

   function Slovak_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "sto";
         when 2 =>
            return "dvesto";
         when 3 =>
            return "tristo";
         when 4 =>
            return U (16#161#) & "tyristo";
         when 5 =>
            return "p" & U (16#E4#) & U (16#165#) & "sto";
         when 6 =>
            return U (16#161#) & "es" & U (16#165#) & "sto";
         when 7 =>
            return "sedemsto";
         when 8 =>
            return "osemsto";
         when 9 =>
            return "dev" & U (16#E4#) & U (16#165#) & "sto";
         when others =>
            return "";
      end case;
   end Slovak_Hundreds;

   function Slovak_Scale_Form
     (Count    : Natural;
      Singular : String;
      Few      : String;
      Many     : String)
      return String
   is
   begin
      if Count = 1 then
         return Singular;
      elsif Count in 2 .. 4 then
         return Few;
      else
         return Many;
      end if;
   end Slovak_Scale_Form;

   function Slovak_Thousands_Form (Count : Natural) return String is
   begin
      return
        Slovak_Scale_Form
          (Count,
           "tis" & U (16#ED#) & "c",
           "tis" & U (16#ED#) & "ce",
           "tis" & U (16#ED#) & "c");
   end Slovak_Thousands_Form;

   function Slovak_Millions_Form (Count : Natural) return String is
   begin
      return
        Slovak_Scale_Form
          (Count,
           "mili" & U (16#F3#) & "n",
           "mili" & U (16#F3#) & "ny",
           "mili" & U (16#F3#) & "nov");
   end Slovak_Millions_Form;

   function Slovak_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Slovak_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Slovak_Tens (Value / 10);
         else
            return Slovak_Tens (Value / 10) & " "
              & Slovak_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Slovak_Hundreds (Value / 100);
         else
            return Slovak_Hundreds (Value / 100) & " "
              & Slovak_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Slovak_Thousands_Form (1);
         elsif Value mod 1_000 = 0 then
            return Slovak_Number (Value / 1_000) & " "
              & Slovak_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return Slovak_Thousands_Form (1) & " "
              & Slovak_Number (Value mod 1_000);
         else
            return Slovak_Number (Value / 1_000) & " "
              & Slovak_Thousands_Form (Value / 1_000) & " "
              & Slovak_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Slovak_Number (Value / 1_000_000) & " "
              & Slovak_Millions_Form (Value / 1_000_000);
         else
            return Slovak_Number (Value / 1_000_000) & " "
              & Slovak_Millions_Form (Value / 1_000_000) & " "
              & Slovak_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Slovak_Number;

   function Slovak_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return "nult" & U (16#FD#);
         when 1 =>
            return "prv" & U (16#FD#);
         when 2 =>
            return "druh" & U (16#FD#);
         when 3 =>
            return "tret" & U (16#ED#);
         when 4 =>
            return U (16#161#) & "tvrt" & U (16#FD#);
         when 5 =>
            return "piaty";
         when 6 =>
            return U (16#161#) & "iesty";
         when 7 =>
            return "siedmy";
         when 8 =>
            return U (16#F4#) & "smy";
         when 9 =>
            return "deviaty";
         when 10 =>
            return "desiaty";
         when 11 =>
            return "jeden" & U (16#E1#) & "sty";
         when 12 =>
            return "dvan" & U (16#E1#) & "sty";
         when 13 =>
            return "trin" & U (16#E1#) & "sty";
         when 14 =>
            return U (16#161#) & "trn" & U (16#E1#) & "sty";
         when 15 =>
            return "p" & U (16#E4#) & "tn" & U (16#E1#) & "sty";
         when 16 =>
            return U (16#161#) & "estn" & U (16#E1#) & "sty";
         when 17 =>
            return "sedemn" & U (16#E1#) & "sty";
         when 18 =>
            return "osemn" & U (16#E1#) & "sty";
         when 19 =>
            return "dev" & U (16#E4#) & "tn" & U (16#E1#) & "sty";
         when others =>
            return "";
      end case;
   end Slovak_Ordinal_Under_20;

   function Slovak_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return "dvadsiaty";
         when 3 =>
            return "tridsiaty";
         when 4 =>
            return U (16#161#) & "tyridsiaty";
         when 5 =>
            return "p" & U (16#E4#) & U (16#165#) & "desiaty";
         when 6 =>
            return U (16#161#) & "es" & U (16#165#) & "desiaty";
         when 7 =>
            return "sedemdesiaty";
         when 8 =>
            return "osemdesiaty";
         when 9 =>
            return "dev" & U (16#E4#) & U (16#165#) & "desiaty";
         when others =>
            return "";
      end case;
   end Slovak_Tens_Ordinal;

   function Slovak_Hundreds_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return "st" & U (16#FD#);
         when 2 =>
            return "dvest" & U (16#FD#);
         when 3 =>
            return "trist" & U (16#FD#);
         when 4 =>
            return U (16#161#) & "tyrist" & U (16#FD#);
         when 5 =>
            return "p" & U (16#E4#) & U (16#165#) & "st" & U (16#FD#);
         when 6 =>
            return U (16#161#) & "es" & U (16#165#) & "st" & U (16#FD#);
         when 7 =>
            return "sedemst" & U (16#FD#);
         when 8 =>
            return "osemst" & U (16#FD#);
         when 9 =>
            return "dev" & U (16#E4#) & U (16#165#) & "st" & U (16#FD#);
         when others =>
            return "";
      end case;
   end Slovak_Hundreds_Ordinal;

   function Slovak_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Slovak_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Slovak_Tens_Ordinal (Value / 10);
         else
            return Slovak_Tens_Ordinal (Value / 10) & " "
              & Slovak_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Slovak_Hundreds_Ordinal (Value / 100);
         else
            return Slovak_Hundreds (Value / 100) & " "
              & Slovak_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return "tis" & U (16#ED#) & "ci";
         elsif Value mod 1_000 = 0 then
            return Slovak_Number (Value / 1_000) & " tis" & U (16#ED#) & "ci";
         elsif Value < 2_000 then
            return Slovak_Thousands_Form (1) & " "
              & Slovak_Ordinal (Value mod 1_000);
         else
            return Slovak_Number (Value / 1_000) & " "
              & Slovak_Thousands_Form (Value / 1_000) & " "
              & Slovak_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return "mili" & U (16#F3#) & "nty";
         elsif Value mod 1_000_000 = 0 then
            return Slovak_Number (Value / 1_000_000) & " mili"
              & U (16#F3#) & "nty";
         else
            return Slovak_Number (Value / 1_000_000) & " "
              & Slovak_Millions_Form (Value / 1_000_000) & " "
              & Slovak_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Slovak_Ordinal;

   function Bulgarian_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#43D#, 16#443#, 16#43B#, 16#430#]);
         when 1 =>
            return UTF8 ([16#435#, 16#434#, 16#43D#, 16#43E#]);
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#435#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#]);
         when 4 =>
            return UTF8 ([16#447#, 16#435#, 16#442#, 16#438#, 16#440#, 16#438#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#435#, 16#442#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#434#, 16#435#, 16#43C#]);
         when 8 =>
            return UTF8 ([16#43E#, 16#441#, 16#435#, 16#43C#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#435#, 16#442#]);
         when 10 =>
            return UTF8 ([16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when 11 =>
            return UTF8
              ([16#435#, 16#434#, 16#438#, 16#43D#, 16#430#, 16#434#,
                16#435#, 16#441#, 16#435#, 16#442#]);
         when 12 =>
            return UTF8
              ([16#434#, 16#432#, 16#430#, 16#43D#, 16#430#, 16#434#,
                16#435#, 16#441#, 16#435#, 16#442#]);
         when 13 =>
            return UTF8
              ([16#442#, 16#440#, 16#438#, 16#43D#, 16#430#, 16#434#,
                16#435#, 16#441#, 16#435#, 16#442#]);
         when 14 =>
            return UTF8
              ([16#447#, 16#435#, 16#442#, 16#438#, 16#440#, 16#438#,
                16#43D#, 16#430#, 16#434#, 16#435#, 16#441#, 16#435#,
                16#442#]);
         when 15 =>
            return UTF8
              ([16#43F#, 16#435#, 16#442#, 16#43D#, 16#430#, 16#434#,
                16#435#, 16#441#, 16#435#, 16#442#]);
         when 16 =>
            return UTF8
              ([16#448#, 16#435#, 16#441#, 16#442#, 16#43D#, 16#430#,
                16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when 17 =>
            return UTF8
              ([16#441#, 16#435#, 16#434#, 16#435#, 16#43C#, 16#43D#,
                16#430#, 16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when 18 =>
            return UTF8
              ([16#43E#, 16#441#, 16#435#, 16#43C#, 16#43D#, 16#430#,
                16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when 19 =>
            return UTF8
              ([16#434#, 16#435#, 16#432#, 16#435#, 16#442#, 16#43D#,
                16#430#, 16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when others =>
            return "";
      end case;
   end Bulgarian_Under_20;

   function Bulgarian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#430#, 16#434#, 16#435#,
                          16#441#, 16#435#, 16#442#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#434#, 16#435#,
                          16#441#, 16#435#, 16#442#]);
         when 4 =>
            return UTF8
              ([16#447#, 16#435#, 16#442#, 16#438#, 16#440#, 16#438#,
                16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#435#, 16#442#, 16#434#, 16#435#,
                          16#441#, 16#435#, 16#442#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#434#,
                          16#435#, 16#441#, 16#435#, 16#442#]);
         when 7 =>
            return UTF8
              ([16#441#, 16#435#, 16#434#, 16#435#, 16#43C#, 16#434#,
                16#435#, 16#441#, 16#435#, 16#442#]);
         when 8 =>
            return UTF8 ([16#43E#, 16#441#, 16#435#, 16#43C#, 16#434#,
                          16#435#, 16#441#, 16#435#, 16#442#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#435#, 16#442#,
                          16#434#, 16#435#, 16#441#, 16#435#, 16#442#]);
         when others =>
            return "";
      end case;
   end Bulgarian_Tens;

   function Bulgarian_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#441#, 16#442#, 16#43E#]);
         when 2 =>
            return UTF8 ([16#434#, 16#432#, 16#435#, 16#441#, 16#442#,
                          16#430#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#438#, 16#441#, 16#442#,
                          16#430#]);
         when 4 =>
            return UTF8
              ([16#447#, 16#435#, 16#442#, 16#438#, 16#440#, 16#438#,
                16#441#, 16#442#, 16#43E#, 16#442#, 16#438#, 16#43D#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#435#, 16#442#, 16#441#, 16#442#,
                          16#43E#, 16#442#, 16#438#, 16#43D#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#441#,
                          16#442#, 16#43E#, 16#442#, 16#438#, 16#43D#]);
         when 7 =>
            return UTF8
              ([16#441#, 16#435#, 16#434#, 16#435#, 16#43C#, 16#441#,
                16#442#, 16#43E#, 16#442#, 16#438#, 16#43D#]);
         when 8 =>
            return UTF8 ([16#43E#, 16#441#, 16#435#, 16#43C#, 16#441#,
                          16#442#, 16#43E#, 16#442#, 16#438#, 16#43D#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#435#, 16#442#,
                          16#441#, 16#442#, 16#43E#, 16#442#, 16#438#,
                          16#43D#]);
         when others =>
            return "";
      end case;
   end Bulgarian_Hundreds;

   function Bulgarian_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Bulgarian_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Bulgarian_Tens (Value / 10);
         else
            return Bulgarian_Tens (Value / 10) & " "
              & U (16#438#) & " " & Bulgarian_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Bulgarian_Hundreds (Value / 100);
         else
            return Bulgarian_Hundreds (Value / 100) & " "
              & Bulgarian_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#, 16#434#,
                          16#430#]);
         elsif Value mod 1_000 = 0 then
            return Bulgarian_Number (Value / 1_000) & " "
              & UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#, 16#434#,
                       16#438#]);
         else
            return (if Value < 2_000
                    then UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#,
                                16#434#, 16#430#])
                    else Bulgarian_Number (Value / 1_000) & " "
                      & UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#,
                               16#434#, 16#438#]))
              & " " & Bulgarian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return UTF8 ([16#435#, 16#434#, 16#438#, 16#43D#]) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                       16#43D#]);
         elsif Value < 2_000_000 then
            return UTF8 ([16#435#, 16#434#, 16#438#, 16#43D#]) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                       16#43D#]) & " "
              & Bulgarian_Number (Value mod 1_000_000);
         elsif Value mod 1_000_000 = 0 then
            return Bulgarian_Number (Value / 1_000_000) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                       16#43D#, 16#430#]);
         else
            return Bulgarian_Number (Value / 1_000_000) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                       16#43D#, 16#430#]) & " "
              & Bulgarian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Bulgarian_Number;

   function Bulgarian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return Bulgarian_Under_20 (0);
         when 1 =>
            return UTF8 ([16#43F#, 16#44A#, 16#440#, 16#432#, 16#438#]);
         when 2 =>
            return UTF8 ([16#432#, 16#442#, 16#43E#, 16#440#, 16#438#]);
         when 3 =>
            return UTF8 ([16#442#, 16#440#, 16#435#, 16#442#, 16#438#]);
         when 4 =>
            return UTF8 ([16#447#, 16#435#, 16#442#, 16#432#, 16#44A#,
                          16#440#, 16#442#, 16#438#]);
         when 5 =>
            return UTF8 ([16#43F#, 16#435#, 16#442#, 16#438#]);
         when 6 =>
            return UTF8 ([16#448#, 16#435#, 16#441#, 16#442#, 16#438#]);
         when 7 =>
            return UTF8 ([16#441#, 16#435#, 16#434#, 16#43C#, 16#438#]);
         when 8 =>
            return UTF8 ([16#43E#, 16#441#, 16#43C#, 16#438#]);
         when 9 =>
            return UTF8 ([16#434#, 16#435#, 16#432#, 16#435#, 16#442#,
                          16#438#]);
         when 10 =>
            return UTF8 ([16#434#, 16#435#, 16#441#, 16#435#, 16#442#,
                          16#438#]);
         when others =>
            return Bulgarian_Under_20 (Value) & U (16#438#);
      end case;
   end Bulgarian_Ordinal_Under_20;

   function Bulgarian_Tens_Ordinal (Value : Natural) return String is
   begin
      return Bulgarian_Tens (Value) & U (16#438#);
   end Bulgarian_Tens_Ordinal;

   function Bulgarian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Bulgarian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Bulgarian_Tens_Ordinal (Value / 10);
         else
            return Bulgarian_Tens (Value / 10) & " "
              & U (16#438#) & " "
              & Bulgarian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Bulgarian_Number (Value) & U (16#438#);
         else
            return Bulgarian_Hundreds (Value / 100) & " "
              & Bulgarian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Bulgarian_Number (Value) & U (16#438#);
         else
            return (if Value < 2_000
                    then UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#,
                                16#434#, 16#430#])
                    else Bulgarian_Number (Value / 1_000) & " "
                      & UTF8 ([16#445#, 16#438#, 16#43B#, 16#44F#,
                               16#434#, 16#438#]))
              & " " & Bulgarian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Bulgarian_Number (Value) & U (16#438#);
         else
            return Bulgarian_Number (Value / 1_000_000) & " "
              & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#, 16#43E#,
                       16#43D#, 16#430#]) & " "
              & Bulgarian_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Bulgarian_Ordinal;

   function Arabic_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#635#, 16#641#, 16#631#]);
         when 1 =>
            return UTF8 ([16#648#, 16#627#, 16#62D#, 16#62F#]);
         when 2 =>
            return UTF8 ([16#627#, 16#62B#, 16#646#, 16#627#, 16#646#]);
         when 3 =>
            return UTF8 ([16#62B#, 16#644#, 16#627#, 16#62B#, 16#629#]);
         when 4 =>
            return UTF8 ([16#623#, 16#631#, 16#628#, 16#639#, 16#629#]);
         when 5 =>
            return UTF8 ([16#62E#, 16#645#, 16#633#, 16#629#]);
         when 6 =>
            return UTF8 ([16#633#, 16#62A#, 16#629#]);
         when 7 =>
            return UTF8 ([16#633#, 16#628#, 16#639#, 16#629#]);
         when 8 =>
            return UTF8 ([16#62B#, 16#645#, 16#627#, 16#646#, 16#64A#,
                          16#629#]);
         when 9 =>
            return UTF8 ([16#62A#, 16#633#, 16#639#, 16#629#]);
         when 10 =>
            return UTF8 ([16#639#, 16#634#, 16#631#, 16#629#]);
         when 11 =>
            return UTF8 ([16#623#, 16#62D#, 16#62F#, 16#20#, 16#639#,
                          16#634#, 16#631#]);
         when 12 =>
            return UTF8 ([16#627#, 16#62B#, 16#646#, 16#627#, 16#20#,
                          16#639#, 16#634#, 16#631#]);
         when 13 =>
            return Arabic_Under_20 (3) & " " & Arabic_Under_20 (10);
         when 14 =>
            return Arabic_Under_20 (4) & " " & Arabic_Under_20 (10);
         when 15 =>
            return Arabic_Under_20 (5) & " " & Arabic_Under_20 (10);
         when 16 =>
            return Arabic_Under_20 (6) & " " & Arabic_Under_20 (10);
         when 17 =>
            return Arabic_Under_20 (7) & " " & Arabic_Under_20 (10);
         when 18 =>
            return Arabic_Under_20 (8) & " " & Arabic_Under_20 (10);
         when 19 =>
            return Arabic_Under_20 (9) & " " & Arabic_Under_20 (10);
         when others =>
            return "";
      end case;
   end Arabic_Under_20;

   function Arabic_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#639#, 16#634#, 16#631#, 16#648#, 16#646#]);
         when 3 =>
            return UTF8 ([16#62B#, 16#644#, 16#627#, 16#62B#, 16#648#,
                          16#646#]);
         when 4 =>
            return UTF8 ([16#623#, 16#631#, 16#628#, 16#639#, 16#648#,
                          16#646#]);
         when 5 =>
            return UTF8 ([16#62E#, 16#645#, 16#633#, 16#648#, 16#646#]);
         when 6 =>
            return UTF8 ([16#633#, 16#62A#, 16#648#, 16#646#]);
         when 7 =>
            return UTF8 ([16#633#, 16#628#, 16#639#, 16#648#, 16#646#]);
         when 8 =>
            return UTF8 ([16#62B#, 16#645#, 16#627#, 16#646#, 16#648#,
                          16#646#]);
         when 9 =>
            return UTF8 ([16#62A#, 16#633#, 16#639#, 16#648#, 16#646#]);
         when others =>
            return "";
      end case;
   end Arabic_Tens;

   function Arabic_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#645#, 16#627#, 16#626#, 16#629#]);
         when 2 =>
            return UTF8 ([16#645#, 16#626#, 16#62A#, 16#627#, 16#646#]);
         when 3 =>
            return UTF8 ([16#62B#, 16#644#, 16#627#, 16#62B#, 16#645#,
                          16#627#, 16#626#, 16#629#]);
         when 4 =>
            return UTF8 ([16#623#, 16#631#, 16#628#, 16#639#, 16#645#,
                          16#627#, 16#626#, 16#629#]);
         when 5 =>
            return UTF8 ([16#62E#, 16#645#, 16#633#, 16#645#, 16#627#,
                          16#626#, 16#629#]);
         when 6 =>
            return UTF8 ([16#633#, 16#62A#, 16#645#, 16#627#, 16#626#,
                          16#629#]);
         when 7 =>
            return UTF8 ([16#633#, 16#628#, 16#639#, 16#645#, 16#627#,
                          16#626#, 16#629#]);
         when 8 =>
            return UTF8 ([16#62B#, 16#645#, 16#627#, 16#646#, 16#645#,
                          16#627#, 16#626#, 16#629#]);
         when 9 =>
            return UTF8 ([16#62A#, 16#633#, 16#639#, 16#645#, 16#627#,
                          16#626#, 16#629#]);
         when others =>
            return "";
      end case;
   end Arabic_Hundreds;

   function Arabic_And return String is
   begin
      return U (16#648#);
   end Arabic_And;

   function Arabic_Thousands_Form (Count : Natural) return String is
   begin
      if Count = 1 then
         return UTF8 ([16#623#, 16#644#, 16#641#]);
      elsif Count = 2 then
         return UTF8 ([16#623#, 16#644#, 16#641#, 16#627#, 16#646#]);
      elsif Count in 3 .. 10 then
         return UTF8 ([16#622#, 16#644#, 16#627#, 16#641#]);
      else
         return UTF8 ([16#623#, 16#644#, 16#641#]);
      end if;
   end Arabic_Thousands_Form;

   function Arabic_Millions_Form (Count : Natural) return String is
   begin
      if Count = 1 then
         return UTF8 ([16#645#, 16#644#, 16#64A#, 16#648#, 16#646#]);
      elsif Count = 2 then
         return UTF8 ([16#645#, 16#644#, 16#64A#, 16#648#, 16#646#,
                       16#627#, 16#646#]);
      elsif Count in 3 .. 10 then
         return UTF8 ([16#645#, 16#644#, 16#627#, 16#64A#, 16#64A#,
                       16#646#]);
      else
         return UTF8 ([16#645#, 16#644#, 16#64A#, 16#648#, 16#646#]);
      end if;
   end Arabic_Millions_Form;

   function Arabic_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Arabic_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Arabic_Tens (Value / 10);
         else
            return Arabic_Under_20 (Value mod 10) & " " & Arabic_And
              & Arabic_Tens (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Arabic_Hundreds (Value / 100);
         else
            return Arabic_Hundreds (Value / 100) & " " & Arabic_And
              & Arabic_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value = 1_000 then
            return Arabic_Thousands_Form (1);
         elsif Value = 2_000 then
            return Arabic_Thousands_Form (2);
         elsif Value mod 1_000 = 0 then
            return Arabic_Number (Value / 1_000) & " "
              & Arabic_Thousands_Form (Value / 1_000);
         elsif Value < 2_000 then
            return Arabic_Thousands_Form (1) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000);
         elsif Value < 3_000 then
            return Arabic_Thousands_Form (2) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000);
         else
            return Arabic_Number (Value / 1_000) & " "
              & Arabic_Thousands_Form (Value / 1_000) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value = 1_000_000 then
            return Arabic_Millions_Form (1);
         elsif Value = 2_000_000 then
            return Arabic_Millions_Form (2);
         elsif Value mod 1_000_000 = 0 then
            return Arabic_Number (Value / 1_000_000) & " "
              & Arabic_Millions_Form (Value / 1_000_000);
         elsif Value < 2_000_000 then
            return Arabic_Millions_Form (1) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000_000);
         elsif Value < 3_000_000 then
            return Arabic_Millions_Form (2) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000_000);
         else
            return Arabic_Number (Value / 1_000_000) & " "
              & Arabic_Millions_Form (Value / 1_000_000) & " " & Arabic_And
              & Arabic_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Arabic_Number;

   function Arabic_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return Arabic_Under_20 (0);
         when 1 =>
            return UTF8 ([16#627#, 16#644#, 16#623#, 16#648#, 16#644#]);
         when 2 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#646#,
                          16#64A#]);
         when 3 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#644#,
                          16#62B#]);
         when 4 =>
            return UTF8 ([16#627#, 16#644#, 16#631#, 16#627#, 16#628#,
                          16#639#]);
         when 5 =>
            return UTF8 ([16#627#, 16#644#, 16#62E#, 16#627#, 16#645#,
                          16#633#]);
         when 6 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#627#, 16#62F#,
                          16#633#]);
         when 7 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#627#, 16#628#,
                          16#639#]);
         when 8 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#645#,
                          16#646#]);
         when 9 =>
            return UTF8 ([16#627#, 16#644#, 16#62A#, 16#627#, 16#633#,
                          16#639#]);
         when 10 =>
            return UTF8 ([16#627#, 16#644#, 16#639#, 16#627#, 16#634#,
                          16#631#]);
         when 11 =>
            return UTF8 ([16#627#, 16#644#, 16#62D#, 16#627#, 16#62F#,
                          16#64A#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 12 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#646#,
                          16#64A#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 13 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#644#,
                          16#62B#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 14 =>
            return UTF8 ([16#627#, 16#644#, 16#631#, 16#627#, 16#628#,
                          16#639#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 15 =>
            return UTF8 ([16#627#, 16#644#, 16#62E#, 16#627#, 16#645#,
                          16#633#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 16 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#627#, 16#62F#,
                          16#633#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 17 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#627#, 16#628#,
                          16#639#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 18 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#627#, 16#645#,
                          16#646#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when 19 =>
            return UTF8 ([16#627#, 16#644#, 16#62A#, 16#627#, 16#633#,
                          16#639#, 16#20#, 16#639#, 16#634#, 16#631#]);
         when others =>
            return "";
      end case;
   end Arabic_Ordinal_Under_20;

   function Arabic_Ordinal_Compound_Unit (Value : Natural) return String is
   begin
      if Value = 1 then
         return UTF8 ([16#627#, 16#644#, 16#62D#, 16#627#, 16#62F#,
                       16#64A#]);
      else
         return Arabic_Ordinal_Under_20 (Value);
      end if;
   end Arabic_Ordinal_Compound_Unit;

   function Arabic_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#627#, 16#644#, 16#639#, 16#634#, 16#631#,
                          16#648#, 16#646#]);
         when 3 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#644#, 16#627#,
                          16#62B#, 16#648#, 16#646#]);
         when 4 =>
            return UTF8 ([16#627#, 16#644#, 16#623#, 16#631#, 16#628#,
                          16#639#, 16#648#, 16#646#]);
         when 5 =>
            return UTF8 ([16#627#, 16#644#, 16#62E#, 16#645#, 16#633#,
                          16#648#, 16#646#]);
         when 6 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#62A#, 16#648#,
                          16#646#]);
         when 7 =>
            return UTF8 ([16#627#, 16#644#, 16#633#, 16#628#, 16#639#,
                          16#648#, 16#646#]);
         when 8 =>
            return UTF8 ([16#627#, 16#644#, 16#62B#, 16#645#, 16#627#,
                          16#646#, 16#648#, 16#646#]);
         when 9 =>
            return UTF8 ([16#627#, 16#644#, 16#62A#, 16#633#, 16#639#,
                          16#648#, 16#646#]);
         when others =>
            return "";
      end case;
   end Arabic_Tens_Ordinal;

   function Arabic_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Arabic_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Arabic_Tens_Ordinal (Value / 10);
         else
            return Arabic_Ordinal_Compound_Unit (Value mod 10) & " "
              & Arabic_And & Arabic_Tens_Ordinal (Value / 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Arabic_Number (Value);
         else
            return Arabic_Hundreds (Value / 100) & " " & Arabic_And
              & Arabic_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Arabic_Number (Value);
         elsif Value < 2_000 then
            return Arabic_Thousands_Form (1) & " " & Arabic_And
              & Arabic_Ordinal (Value mod 1_000);
         elsif Value < 3_000 then
            return Arabic_Thousands_Form (2) & " " & Arabic_And
              & Arabic_Ordinal (Value mod 1_000);
         else
            return Arabic_Number (Value / 1_000) & " "
              & Arabic_Thousands_Form (Value / 1_000) & " " & Arabic_And
              & Arabic_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Arabic_Number (Value);
         else
            return Arabic_Number (Value / 1_000_000) & " "
              & Arabic_Millions_Form (Value / 1_000_000) & " "
              & Arabic_And & Arabic_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Arabic_Ordinal;

   function Persian_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#635#, 16#641#, 16#631#]);
         when 1 =>
            return UTF8 ([16#6CC#, 16#6A9#]);
         when 2 =>
            return UTF8 ([16#62F#, 16#648#]);
         when 3 =>
            return UTF8 ([16#633#, 16#647#]);
         when 4 =>
            return UTF8 ([16#686#, 16#647#, 16#627#, 16#631#]);
         when 5 =>
            return UTF8 ([16#67E#, 16#646#, 16#62C#]);
         when 6 =>
            return UTF8 ([16#634#, 16#634#]);
         when 7 =>
            return UTF8 ([16#647#, 16#641#, 16#62A#]);
         when 8 =>
            return UTF8 ([16#647#, 16#634#, 16#62A#]);
         when 9 =>
            return UTF8 ([16#646#, 16#647#]);
         when 10 =>
            return UTF8 ([16#62F#, 16#647#]);
         when 11 =>
            return UTF8 ([16#6CC#, 16#627#, 16#632#, 16#62F#, 16#647#]);
         when 12 =>
            return UTF8 ([16#62F#, 16#648#, 16#627#, 16#632#, 16#62F#,
                          16#647#]);
         when 13 =>
            return UTF8 ([16#633#, 16#6CC#, 16#632#, 16#62F#, 16#647#]);
         when 14 =>
            return UTF8 ([16#686#, 16#647#, 16#627#, 16#631#, 16#62F#,
                          16#647#]);
         when 15 =>
            return UTF8 ([16#67E#, 16#627#, 16#646#, 16#632#, 16#62F#,
                          16#647#]);
         when 16 =>
            return UTF8 ([16#634#, 16#627#, 16#646#, 16#632#, 16#62F#,
                          16#647#]);
         when 17 =>
            return UTF8 ([16#647#, 16#641#, 16#62F#, 16#647#]);
         when 18 =>
            return UTF8 ([16#647#, 16#62C#, 16#62F#, 16#647#]);
         when 19 =>
            return UTF8 ([16#646#, 16#648#, 16#632#, 16#62F#, 16#647#]);
         when others =>
            return "";
      end case;
   end Persian_Under_20;

   function Persian_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#628#, 16#6CC#, 16#633#, 16#62A#]);
         when 3 =>
            return UTF8 ([16#633#, 16#6CC#]);
         when 4 =>
            return UTF8 ([16#686#, 16#647#, 16#644#]);
         when 5 =>
            return UTF8 ([16#67E#, 16#646#, 16#62C#, 16#627#, 16#647#]);
         when 6 =>
            return UTF8 ([16#634#, 16#635#, 16#62A#]);
         when 7 =>
            return UTF8 ([16#647#, 16#641#, 16#62A#, 16#627#, 16#62F#]);
         when 8 =>
            return UTF8 ([16#647#, 16#634#, 16#62A#, 16#627#, 16#62F#]);
         when 9 =>
            return UTF8 ([16#646#, 16#648#, 16#62F#]);
         when others =>
            return "";
      end case;
   end Persian_Tens;

   function Persian_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#635#, 16#62F#]);
         when 2 =>
            return UTF8 ([16#62F#, 16#648#, 16#6CC#, 16#633#, 16#62A#]);
         when 3 =>
            return UTF8 ([16#633#, 16#6CC#, 16#635#, 16#62F#]);
         when 4 =>
            return UTF8 ([16#686#, 16#647#, 16#627#, 16#631#, 16#635#,
                          16#62F#]);
         when 5 =>
            return UTF8 ([16#67E#, 16#627#, 16#646#, 16#635#, 16#62F#]);
         when 6 =>
            return UTF8 ([16#634#, 16#634#, 16#635#, 16#62F#]);
         when 7 =>
            return UTF8 ([16#647#, 16#641#, 16#62A#, 16#635#, 16#62F#]);
         when 8 =>
            return UTF8 ([16#647#, 16#634#, 16#62A#, 16#635#, 16#62F#]);
         when 9 =>
            return UTF8 ([16#646#, 16#647#, 16#635#, 16#62F#]);
         when others =>
            return "";
      end case;
   end Persian_Hundreds;

   function Persian_And return String is
   begin
      return " " & U (16#648#) & " ";
   end Persian_And;

   function Persian_Thousand return String is
   begin
      return UTF8 ([16#647#, 16#632#, 16#627#, 16#631#]);
   end Persian_Thousand;

   function Persian_Million return String is
   begin
      return UTF8 ([16#645#, 16#6CC#, 16#644#, 16#6CC#, 16#648#, 16#646#]);
   end Persian_Million;

   function Persian_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Persian_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Persian_Tens (Value / 10);
         else
            return Persian_Tens (Value / 10) & Persian_And
              & Persian_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Persian_Hundreds (Value / 100);
         else
            return Persian_Hundreds (Value / 100) & Persian_And
              & Persian_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Persian_Number (Value / 1_000) & " " & Persian_Thousand;
         else
            return Persian_Number (Value / 1_000) & " " & Persian_Thousand
              & Persian_And & Persian_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Persian_Number (Value / 1_000_000) & " "
              & Persian_Million;
         else
            return Persian_Number (Value / 1_000_000) & " "
              & Persian_Million & Persian_And
              & Persian_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Persian_Number;

   function Persian_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return Persian_Under_20 (0);
         when 1 =>
            return UTF8 ([16#6CC#, 16#6A9#, 16#645#]);
         when 2 =>
            return UTF8 ([16#62F#, 16#648#, 16#645#]);
         when 3 =>
            return UTF8 ([16#633#, 16#648#, 16#645#]);
         when 4 =>
            return UTF8 ([16#686#, 16#647#, 16#627#, 16#631#, 16#645#]);
         when 5 =>
            return UTF8 ([16#67E#, 16#646#, 16#62C#, 16#645#]);
         when 6 =>
            return UTF8 ([16#634#, 16#634#, 16#645#]);
         when 7 =>
            return UTF8 ([16#647#, 16#641#, 16#62A#, 16#645#]);
         when 8 =>
            return UTF8 ([16#647#, 16#634#, 16#62A#, 16#645#]);
         when 9 =>
            return UTF8 ([16#646#, 16#647#, 16#645#]);
         when 10 =>
            return UTF8 ([16#62F#, 16#647#, 16#645#]);
         when 11 =>
            return UTF8 ([16#6CC#, 16#627#, 16#632#, 16#62F#, 16#647#,
                          16#645#]);
         when 12 =>
            return UTF8 ([16#62F#, 16#648#, 16#627#, 16#632#, 16#62F#,
                          16#647#, 16#645#]);
         when 13 =>
            return UTF8 ([16#633#, 16#6CC#, 16#632#, 16#62F#, 16#647#,
                          16#645#]);
         when 14 =>
            return UTF8 ([16#686#, 16#647#, 16#627#, 16#631#, 16#62F#,
                          16#647#, 16#645#]);
         when 15 =>
            return UTF8 ([16#67E#, 16#627#, 16#646#, 16#632#, 16#62F#,
                          16#647#, 16#645#]);
         when 16 =>
            return UTF8 ([16#634#, 16#627#, 16#646#, 16#632#, 16#62F#,
                          16#647#, 16#645#]);
         when 17 =>
            return UTF8 ([16#647#, 16#641#, 16#62F#, 16#647#, 16#645#]);
         when 18 =>
            return UTF8 ([16#647#, 16#62C#, 16#62F#, 16#647#, 16#645#]);
         when 19 =>
            return UTF8 ([16#646#, 16#648#, 16#632#, 16#62F#, 16#647#,
                          16#645#]);
         when others =>
            return "";
      end case;
   end Persian_Ordinal_Under_20;

   function Persian_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#628#, 16#6CC#, 16#633#, 16#62A#, 16#645#]);
         when 3 =>
            return UTF8 ([16#633#, 16#6CC#, 16#20#, 16#627#, 16#645#]);
         when 4 =>
            return UTF8 ([16#686#, 16#647#, 16#644#, 16#645#]);
         when 5 =>
            return UTF8 ([16#67E#, 16#646#, 16#62C#, 16#627#, 16#647#,
                          16#645#]);
         when 6 =>
            return UTF8 ([16#634#, 16#635#, 16#62A#, 16#645#]);
         when 7 =>
            return UTF8 ([16#647#, 16#641#, 16#62A#, 16#627#, 16#62F#,
                          16#645#]);
         when 8 =>
            return UTF8 ([16#647#, 16#634#, 16#62A#, 16#627#, 16#62F#,
                          16#645#]);
         when 9 =>
            return UTF8 ([16#646#, 16#648#, 16#62F#, 16#645#]);
         when others =>
            return "";
      end case;
   end Persian_Tens_Ordinal;

   function Persian_Ordinal (Value : Natural) return String is
   begin
      if Value < 20 then
         return Persian_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Persian_Tens_Ordinal (Value / 10);
         else
            return Persian_Tens (Value / 10) & Persian_And
              & Persian_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Persian_Number (Value) & U (16#645#);
         else
            return Persian_Hundreds (Value / 100) & Persian_And
              & Persian_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Persian_Number (Value) & U (16#645#);
         else
            return Persian_Number (Value / 1_000) & " " & Persian_Thousand
              & Persian_And & Persian_Ordinal (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Persian_Number (Value) & U (16#645#);
         else
            return Persian_Number (Value / 1_000_000) & " "
              & Persian_Million & Persian_And
              & Persian_Ordinal (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Persian_Ordinal;

   function Thai_Digit (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#E28#, 16#E39#, 16#E19#, 16#E22#, 16#E4C#]);
         when 1 =>
            return UTF8 ([16#E2B#, 16#E19#, 16#E36#, 16#E48#, 16#E07#]);
         when 2 =>
            return UTF8 ([16#E2A#, 16#E2D#, 16#E07#]);
         when 3 =>
            return UTF8 ([16#E2A#, 16#E32#, 16#E21#]);
         when 4 =>
            return UTF8 ([16#E2A#, 16#E35#, 16#E48#]);
         when 5 =>
            return UTF8 ([16#E2B#, 16#E49#, 16#E32#]);
         when 6 =>
            return UTF8 ([16#E2B#, 16#E01#]);
         when 7 =>
            return UTF8 ([16#E40#, 16#E08#, 16#E47#, 16#E14#]);
         when 8 =>
            return UTF8 ([16#E41#, 16#E1B#, 16#E14#]);
         when 9 =>
            return UTF8 ([16#E40#, 16#E01#, 16#E49#, 16#E32#]);
         when others =>
            return "";
      end case;
   end Thai_Digit;

   function Thai_Ten return String is
   begin
      return UTF8 ([16#E2A#, 16#E34#, 16#E1A#]);
   end Thai_Ten;

   function Thai_Twenty return String is
   begin
      return UTF8 ([16#E22#, 16#E35#, 16#E48#, 16#E2A#, 16#E34#,
                    16#E1A#]);
   end Thai_Twenty;

   function Thai_One_After_Tens return String is
   begin
      return UTF8 ([16#E40#, 16#E2D#, 16#E47#, 16#E14#]);
   end Thai_One_After_Tens;

   function Thai_Hundred return String is
   begin
      return UTF8 ([16#E23#, 16#E49#, 16#E2D#, 16#E22#]);
   end Thai_Hundred;

   function Thai_Thousand return String is
   begin
      return UTF8 ([16#E1E#, 16#E31#, 16#E19#]);
   end Thai_Thousand;

   function Thai_Million return String is
   begin
      return UTF8 ([16#E25#, 16#E49#, 16#E32#, 16#E19#]);
   end Thai_Million;

   function Thai_Number (Value : Natural) return String is
   begin
      if Value < 10 then
         return Thai_Digit (Value);
      elsif Value < 20 then
         if Value = 10 then
            return Thai_Ten;
         elsif Value = 11 then
            return Thai_Ten & Thai_One_After_Tens;
         else
            return Thai_Ten & Thai_Digit (Value mod 10);
         end if;
      elsif Value < 100 then
         declare
            Tens  : constant Natural := Value / 10;
            Units : constant Natural := Value mod 10;
            Head  : constant String :=
              (if Tens = 2 then Thai_Twenty else Thai_Digit (Tens) & Thai_Ten);
         begin
            if Units = 0 then
               return Head;
            elsif Units = 1 then
               return Head & Thai_One_After_Tens;
            else
               return Head & Thai_Digit (Units);
            end if;
         end;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Thai_Digit (Value / 100) & Thai_Hundred;
         else
            return Thai_Digit (Value / 100) & Thai_Hundred
              & Thai_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Thai_Number (Value / 1_000) & Thai_Thousand;
         else
            return Thai_Number (Value / 1_000) & Thai_Thousand
              & Thai_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Thai_Number (Value / 1_000_000) & Thai_Million;
         else
            return Thai_Number (Value / 1_000_000) & Thai_Million
              & Thai_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Thai_Number;

   function Thai_Ordinal (Value : Natural) return String is
   begin
      return UTF8 ([16#E17#, 16#E35#, 16#E48#]) & Thai_Number (Value);
   end Thai_Ordinal;

   function Hindi_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#936#, 16#942#, 16#928#, 16#94D#, 16#92F#]);
         when 1 =>
            return UTF8 ([16#90F#, 16#915#]);
         when 2 =>
            return UTF8 ([16#926#, 16#94B#]);
         when 3 =>
            return UTF8 ([16#924#, 16#940#, 16#928#]);
         when 4 =>
            return UTF8 ([16#91A#, 16#93E#, 16#930#]);
         when 5 =>
            return UTF8 ([16#92A#, 16#93E#, 16#901#, 16#91A#]);
         when 6 =>
            return UTF8 ([16#91B#, 16#939#]);
         when 7 =>
            return UTF8 ([16#938#, 16#93E#, 16#924#]);
         when 8 =>
            return UTF8 ([16#906#, 16#920#]);
         when 9 =>
            return UTF8 ([16#928#, 16#94C#]);
         when 10 =>
            return UTF8 ([16#926#, 16#938#]);
         when 11 =>
            return UTF8 ([16#917#, 16#94D#, 16#92F#, 16#93E#, 16#930#,
                          16#939#]);
         when 12 =>
            return UTF8 ([16#92C#, 16#93E#, 16#930#, 16#939#]);
         when 13 =>
            return UTF8 ([16#924#, 16#947#, 16#930#, 16#939#]);
         when 14 =>
            return UTF8 ([16#91A#, 16#94C#, 16#926#, 16#939#]);
         when 15 =>
            return UTF8 ([16#92A#, 16#902#, 16#926#, 16#94D#, 16#930#,
                          16#939#]);
         when 16 =>
            return UTF8 ([16#938#, 16#94B#, 16#932#, 16#939#]);
         when 17 =>
            return UTF8 ([16#938#, 16#924#, 16#94D#, 16#930#, 16#939#]);
         when 18 =>
            return UTF8 ([16#905#, 16#920#, 16#93E#, 16#930#, 16#939#]);
         when 19 =>
            return UTF8 ([16#909#, 16#928#, 16#94D#, 16#928#, 16#940#,
                          16#938#]);
         when others =>
            return "";
      end case;
   end Hindi_Under_20;

   function Hindi_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#92C#, 16#940#, 16#938#]);
         when 3 =>
            return UTF8 ([16#924#, 16#940#, 16#938#]);
         when 4 =>
            return UTF8 ([16#91A#, 16#93E#, 16#932#, 16#940#, 16#938#]);
         when 5 =>
            return UTF8 ([16#92A#, 16#91A#, 16#93E#, 16#938#]);
         when 6 =>
            return UTF8 ([16#938#, 16#93E#, 16#920#]);
         when 7 =>
            return UTF8 ([16#938#, 16#924#, 16#94D#, 16#924#, 16#930#]);
         when 8 =>
            return UTF8 ([16#905#, 16#938#, 16#94D#, 16#938#, 16#940#]);
         when 9 =>
            return UTF8 ([16#928#, 16#92C#, 16#94D#, 16#92C#, 16#947#]);
         when others =>
            return "";
      end case;
   end Hindi_Tens;

   function Hindi_Hundred return String is
   begin
      return UTF8 ([16#938#, 16#94C#]);
   end Hindi_Hundred;

   function Hindi_Thousand return String is
   begin
      return UTF8 ([16#939#, 16#91C#, 16#93C#, 16#93E#, 16#930#]);
   end Hindi_Thousand;

   function Hindi_Lakh return String is
   begin
      return UTF8 ([16#932#, 16#93E#, 16#916#]);
   end Hindi_Lakh;

   function Hindi_Crore return String is
   begin
      return UTF8 ([16#915#, 16#930#, 16#94B#, 16#921#, 16#93C#]);
   end Hindi_Crore;

   function Hindi_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Hindi_Under_20 (Value);
      elsif Value < 100 then
         if Value = 21 then
            return UTF8 ([16#907#, 16#915#, 16#94D#, 16#915#, 16#940#,
                          16#938#]);
         elsif Value mod 10 = 0 then
            return Hindi_Tens (Value / 10);
         else
            return Hindi_Tens (Value / 10) & " "
              & Hindi_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Hindi_Under_20 (Value / 100) & " " & Hindi_Hundred;
         else
            return Hindi_Under_20 (Value / 100) & " " & Hindi_Hundred
              & " " & Hindi_Number (Value mod 100);
         end if;
      elsif Value < 100_000 then
         if Value mod 1_000 = 0 then
            return Hindi_Number (Value / 1_000) & " " & Hindi_Thousand;
         else
            return Hindi_Number (Value / 1_000) & " " & Hindi_Thousand
              & " " & Hindi_Number (Value mod 1_000);
         end if;
      elsif Value < 10_000_000 then
         if Value mod 100_000 = 0 then
            return Hindi_Number (Value / 100_000) & " " & Hindi_Lakh;
         else
            return Hindi_Number (Value / 100_000) & " " & Hindi_Lakh
              & " " & Hindi_Number (Value mod 100_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 10_000_000 = 0 then
            return Hindi_Number (Value / 10_000_000) & " " & Hindi_Crore;
         else
            return Hindi_Number (Value / 10_000_000) & " " & Hindi_Crore
              & " " & Hindi_Number (Value mod 10_000_000);
         end if;
      else
         return "";
      end if;
   end Hindi_Number;

   function Hindi_Ordinal (Value : Natural) return String is
   begin
      return Hindi_Number (Value) & UTF8 ([16#935#, 16#93E#, 16#901#]);
   end Hindi_Ordinal;

   function Greek_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#3BC#, 16#3B7#, 16#3B4#, 16#3AD#, 16#3BD#]);
         when 1 =>
            return UTF8 ([16#3AD#, 16#3BD#, 16#3B1#]);
         when 2 =>
            return UTF8 ([16#3B4#, 16#3CD#, 16#3BF#]);
         when 3 =>
            return UTF8 ([16#3C4#, 16#3C1#, 16#3B5#, 16#3B9#,
                          16#3C2#]);
         when 4 =>
            return UTF8 ([16#3C4#, 16#3AD#, 16#3C3#, 16#3C3#,
                          16#3B5#, 16#3C1#, 16#3B1#]);
         when 5 =>
            return UTF8 ([16#3C0#, 16#3AD#, 16#3BD#, 16#3C4#, 16#3B5#]);
         when 6 =>
            return UTF8 ([16#3AD#, 16#3BE#, 16#3B9#]);
         when 7 =>
            return UTF8 ([16#3B5#, 16#3C0#, 16#3C4#, 16#3AC#]);
         when 8 =>
            return UTF8 ([16#3BF#, 16#3BA#, 16#3C4#, 16#3CE#]);
         when 9 =>
            return UTF8 ([16#3B5#, 16#3BD#, 16#3BD#, 16#3AD#, 16#3B1#]);
         when 10 =>
            return UTF8 ([16#3B4#, 16#3AD#, 16#3BA#, 16#3B1#]);
         when 11 =>
            return UTF8 ([16#3AD#, 16#3BD#, 16#3C4#, 16#3B5#,
                          16#3BA#, 16#3B1#]);
         when 12 =>
            return UTF8 ([16#3B4#, 16#3CE#, 16#3B4#, 16#3B5#,
                          16#3BA#, 16#3B1#]);
         when 13 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3C4#, 16#3C1#, 16#3AF#, 16#3B1#]);
         when 14 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3C4#, 16#3AD#, 16#3C3#, 16#3C3#,
                          16#3B5#, 16#3C1#, 16#3B1#]);
         when 15 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3C0#, 16#3AD#, 16#3BD#, 16#3C4#, 16#3B5#]);
         when 16 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3AD#, 16#3BE#, 16#3B9#]);
         when 17 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3B5#, 16#3C0#, 16#3C4#, 16#3AC#]);
         when 18 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3BF#, 16#3BA#, 16#3C4#, 16#3CE#]);
         when 19 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3BA#, 16#3B1#,
                          16#3B5#, 16#3BD#, 16#3BD#, 16#3AD#,
                          16#3B1#]);
         when others =>
            return "";
      end case;
   end Greek_Under_20;

   function Greek_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#3B5#, 16#3AF#, 16#3BA#, 16#3BF#,
                          16#3C3#, 16#3B9#]);
         when 3 =>
            return UTF8 ([16#3C4#, 16#3C1#, 16#3B9#, 16#3AC#,
                          16#3BD#, 16#3C4#, 16#3B1#]);
         when 4 =>
            return UTF8 ([16#3C3#, 16#3B1#, 16#3C1#, 16#3AC#,
                          16#3BD#, 16#3C4#, 16#3B1#]);
         when 5 =>
            return UTF8 ([16#3C0#, 16#3B5#, 16#3BD#, 16#3AE#,
                          16#3BD#, 16#3C4#, 16#3B1#]);
         when 6 =>
            return UTF8 ([16#3B5#, 16#3BE#, 16#3AE#, 16#3BD#,
                          16#3C4#, 16#3B1#]);
         when 7 =>
            return UTF8 ([16#3B5#, 16#3B2#, 16#3B4#, 16#3BF#,
                          16#3BC#, 16#3AE#, 16#3BD#, 16#3C4#,
                          16#3B1#]);
         when 8 =>
            return UTF8 ([16#3BF#, 16#3B3#, 16#3B4#, 16#3CC#,
                          16#3BD#, 16#3C4#, 16#3B1#]);
         when 9 =>
            return UTF8 ([16#3B5#, 16#3BD#, 16#3B5#, 16#3BD#,
                          16#3AE#, 16#3BD#, 16#3C4#, 16#3B1#]);
         when others =>
            return "";
      end case;
   end Greek_Tens;

   function Greek_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#3B5#, 16#3BA#, 16#3B1#, 16#3C4#, 16#3CC#]);
         when 2 =>
            return UTF8 ([16#3B4#, 16#3B9#, 16#3B1#, 16#3BA#,
                          16#3CC#, 16#3C3#, 16#3B9#, 16#3B1#]);
         when 3 =>
            return UTF8 ([16#3C4#, 16#3C1#, 16#3B9#, 16#3B1#,
                          16#3BA#, 16#3CC#, 16#3C3#, 16#3B9#,
                          16#3B1#]);
         when 4 =>
            return UTF8 ([16#3C4#, 16#3B5#, 16#3C4#, 16#3C1#,
                          16#3B1#, 16#3BA#, 16#3CC#, 16#3C3#,
                          16#3B9#, 16#3B1#]);
         when 5 =>
            return UTF8 ([16#3C0#, 16#3B5#, 16#3BD#, 16#3C4#,
                          16#3B1#, 16#3BA#, 16#3CC#, 16#3C3#,
                          16#3B9#, 16#3B1#]);
         when 6 =>
            return UTF8 ([16#3B5#, 16#3BE#, 16#3B1#, 16#3BA#,
                          16#3CC#, 16#3C3#, 16#3B9#, 16#3B1#]);
         when 7 =>
            return UTF8 ([16#3B5#, 16#3C0#, 16#3C4#, 16#3B1#,
                          16#3BA#, 16#3CC#, 16#3C3#, 16#3B9#,
                          16#3B1#]);
         when 8 =>
            return UTF8 ([16#3BF#, 16#3BA#, 16#3C4#, 16#3B1#,
                          16#3BA#, 16#3CC#, 16#3C3#, 16#3B9#,
                          16#3B1#]);
         when 9 =>
            return UTF8 ([16#3B5#, 16#3BD#, 16#3BD#, 16#3B9#,
                          16#3B1#, 16#3BA#, 16#3CC#, 16#3C3#,
                          16#3B9#, 16#3B1#]);
         when others =>
            return "";
      end case;
   end Greek_Hundreds;

   function Greek_Number (Value : Natural) return String;

   function Greek_Ordinal (Value : Natural) return String;

   function Greek_Thousand (Count : Natural) return String is
   begin
      if Count = 1 then
         return UTF8 ([16#3C7#, 16#3AF#, 16#3BB#, 16#3B9#, 16#3B1#]);
      else
         return Greek_Number (Count) & " "
           & UTF8 ([16#3C7#, 16#3B9#, 16#3BB#, 16#3B9#, 16#3AC#,
                    16#3B4#, 16#3B5#, 16#3C2#]);
      end if;
   end Greek_Thousand;

   function Greek_Million (Count : Natural) return String is
   begin
      if Count = 1 then
         return Greek_Under_20 (1) & " "
           & UTF8 ([16#3B5#, 16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#,
                    16#3BC#, 16#3BC#, 16#3CD#, 16#3C1#, 16#3B9#,
                    16#3BF#]);
      else
         return Greek_Number (Count) & " "
           & UTF8 ([16#3B5#, 16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#,
                    16#3BC#, 16#3BC#, 16#3CD#, 16#3C1#, 16#3B9#,
                    16#3B1#]);
      end if;
   end Greek_Million;

   function Greek_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Greek_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Greek_Tens (Value / 10);
         else
            return Greek_Tens (Value / 10) & " "
              & Greek_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Greek_Hundreds (Value / 100);
         else
            return Greek_Hundreds (Value / 100) & " "
              & Greek_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Greek_Thousand (Value / 1_000);
         else
            return Greek_Thousand (Value / 1_000) & " "
              & Greek_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Greek_Million (Value / 1_000_000);
         else
            return Greek_Million (Value / 1_000_000) & " "
              & Greek_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Greek_Number;

   function Greek_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#3C0#, 16#3C1#, 16#3CE#, 16#3C4#, 16#3BF#]);
         when 2 =>
            return UTF8 ([16#3B4#, 16#3B5#, 16#3CD#, 16#3C4#,
                          16#3B5#, 16#3C1#, 16#3BF#]);
         when 3 =>
            return UTF8 ([16#3C4#, 16#3C1#, 16#3AF#, 16#3C4#, 16#3BF#]);
         when 4 =>
            return UTF8 ([16#3C4#, 16#3AD#, 16#3C4#, 16#3B1#,
                          16#3C1#, 16#3C4#, 16#3BF#]);
         when 5 =>
            return UTF8 ([16#3C0#, 16#3AD#, 16#3BC#, 16#3C0#,
                          16#3C4#, 16#3BF#]);
         when 6 =>
            return UTF8 ([16#3AD#, 16#3BA#, 16#3C4#, 16#3BF#]);
         when 7 =>
            return UTF8 ([16#3AD#, 16#3B2#, 16#3B4#, 16#3BF#, 16#3BC#,
                          16#3BF#]);
         when 8 =>
            return UTF8 ([16#3CC#, 16#3B3#, 16#3B4#, 16#3BF#, 16#3BF#]);
         when 9 =>
            return UTF8 ([16#3AD#, 16#3BD#, 16#3B1#, 16#3C4#, 16#3BF#]);
         when 10 =>
            return UTF8 ([16#3B4#, 16#3AD#, 16#3BA#, 16#3B1#,
                          16#3C4#, 16#3BF#]);
         when 11 =>
            return UTF8 ([16#3B5#, 16#3BD#, 16#3B4#, 16#3AD#,
                          16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#]);
         when 12 =>
            return UTF8 ([16#3B4#, 16#3C9#, 16#3B4#, 16#3AD#,
                          16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#]);
         when 13 .. 19 =>
            return Greek_Ordinal_Under_20 (10) & " "
              & Greek_Ordinal_Under_20 (Value - 10);
         when others =>
            return "";
      end case;
   end Greek_Ordinal_Under_20;

   function Greek_Tens_Ordinal (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#3B5#, 16#3B9#, 16#3BA#, 16#3BF#, 16#3C3#,
                          16#3C4#, 16#3CC#]);
         when 3 =>
            return UTF8 ([16#3C4#, 16#3C1#, 16#3B9#, 16#3B1#, 16#3BA#,
                          16#3BF#, 16#3C3#, 16#3C4#, 16#3CC#]);
         when 4 =>
            return UTF8 ([16#3C4#, 16#3B5#, 16#3C3#, 16#3C3#, 16#3B1#,
                          16#3C1#, 16#3B1#, 16#3BA#, 16#3BF#, 16#3C3#,
                          16#3C4#, 16#3CC#]);
         when 5 =>
            return UTF8 ([16#3C0#, 16#3B5#, 16#3BD#, 16#3C4#, 16#3B7#,
                          16#3BA#, 16#3BF#, 16#3C3#, 16#3C4#, 16#3CC#]);
         when 6 =>
            return UTF8 ([16#3B5#, 16#3BE#, 16#3B7#, 16#3BA#, 16#3BF#,
                          16#3C3#, 16#3C4#, 16#3CC#]);
         when 7 =>
            return UTF8 ([16#3B5#, 16#3B2#, 16#3B4#, 16#3BF#, 16#3BC#,
                          16#3B7#, 16#3BA#, 16#3BF#, 16#3C3#, 16#3C4#,
                          16#3CC#]);
         when 8 =>
            return UTF8 ([16#3BF#, 16#3B3#, 16#3B4#, 16#3BF#, 16#3B7#,
                          16#3BA#, 16#3BF#, 16#3C3#, 16#3C4#, 16#3CC#]);
         when 9 =>
            return UTF8 ([16#3B5#, 16#3BD#, 16#3B5#, 16#3BD#, 16#3B7#,
                          16#3BA#, 16#3BF#, 16#3C3#, 16#3C4#, 16#3CC#]);
         when others =>
            return "";
      end case;
   end Greek_Tens_Ordinal;

   function Greek_Ordinal (Value : Natural) return String is
   begin
      if Value = 0 then
         return Greek_Number (Value);
      elsif Value < 20 then
         return Greek_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Greek_Tens_Ordinal (Value / 10);
         else
            return Greek_Tens (Value / 10) & " "
              & Greek_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value mod 100 = 0 and then Value < 1_000 then
         if Value = 100 then
            return UTF8 ([16#3B5#, 16#3BA#, 16#3B1#, 16#3C4#, 16#3BF#,
                          16#3C3#, 16#3C4#, 16#3CC#]);
         else
            return Greek_Number (Value);
         end if;
      elsif Value < 1_000 then
         return Greek_Hundreds (Value / 100) & " "
           & Greek_Ordinal (Value mod 100);
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Greek_Thousand (Value / 1_000);
         else
            return Greek_Thousand (Value / 1_000) & " "
              & Greek_Ordinal (Value mod 1_000);
         end if;
      else
         if Value mod 1_000_000 = 0 then
            return Greek_Million (Value / 1_000_000);
         else
            return Greek_Million (Value / 1_000_000) & " "
              & Greek_Ordinal (Value mod 1_000_000);
         end if;
      end if;
   end Greek_Ordinal;

   function Hebrew_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 0 =>
            return UTF8 ([16#5D0#, 16#5E4#, 16#5E1#]);
         when 1 =>
            return UTF8 ([16#5D0#, 16#5D7#, 16#5D3#]);
         when 2 =>
            return UTF8 ([16#5E9#, 16#5EA#, 16#5D9#, 16#5D9#,
                          16#5DD#]);
         when 3 =>
            return UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5E9#]);
         when 4 =>
            return UTF8 ([16#5D0#, 16#5E8#, 16#5D1#, 16#5E2#]);
         when 5 =>
            return UTF8 ([16#5D7#, 16#5DE#, 16#5E9#]);
         when 6 =>
            return UTF8 ([16#5E9#, 16#5E9#]);
         when 7 =>
            return UTF8 ([16#5E9#, 16#5D1#, 16#5E2#]);
         when 8 =>
            return UTF8 ([16#5E9#, 16#5DE#, 16#5D5#, 16#5E0#,
                          16#5D4#]);
         when 9 =>
            return UTF8 ([16#5EA#, 16#5E9#, 16#5E2#]);
         when 10 =>
            return UTF8 ([16#5E2#, 16#5E9#, 16#5E8#]);
         when 11 =>
            return UTF8 ([16#5D0#, 16#5D7#, 16#5EA#, 16#20#,
                          16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 12 =>
            return UTF8 ([16#5E9#, 16#5EA#, 16#5D9#, 16#5DD#,
                          16#20#, 16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 13 =>
            return Hebrew_Under_20 (3) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 14 =>
            return Hebrew_Under_20 (4) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 15 =>
            return Hebrew_Under_20 (5) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 16 =>
            return Hebrew_Under_20 (6) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 17 =>
            return Hebrew_Under_20 (7) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 18 =>
            return Hebrew_Under_20 (8) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when 19 =>
            return Hebrew_Under_20 (9) & " "
              & UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D4#]);
         when others =>
            return "";
      end case;
   end Hebrew_Under_20;

   function Hebrew_Tens (Value : Natural) return String is
   begin
      case Value is
         when 2 =>
            return UTF8 ([16#5E2#, 16#5E9#, 16#5E8#, 16#5D9#, 16#5DD#]);
         when 3 =>
            return UTF8 ([16#5E9#, 16#5DC#, 16#5D5#, 16#5E9#,
                          16#5D9#, 16#5DD#]);
         when 4 =>
            return UTF8 ([16#5D0#, 16#5E8#, 16#5D1#, 16#5E2#,
                          16#5D9#, 16#5DD#]);
         when 5 =>
            return UTF8 ([16#5D7#, 16#5DE#, 16#5D9#, 16#5E9#,
                          16#5D9#, 16#5DD#]);
         when 6 =>
            return UTF8 ([16#5E9#, 16#5D9#, 16#5E9#, 16#5D9#, 16#5DD#]);
         when 7 =>
            return UTF8 ([16#5E9#, 16#5D1#, 16#5E2#, 16#5D9#, 16#5DD#]);
         when 8 =>
            return UTF8 ([16#5E9#, 16#5DE#, 16#5D5#, 16#5E0#,
                          16#5D9#, 16#5DD#]);
         when 9 =>
            return UTF8 ([16#5EA#, 16#5E9#, 16#5E2#, 16#5D9#, 16#5DD#]);
         when others =>
            return "";
      end case;
   end Hebrew_Tens;

   function Hebrew_Hundreds (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#5DE#, 16#5D0#, 16#5D4#]);
         when 2 =>
            return UTF8 ([16#5DE#, 16#5D0#, 16#5EA#, 16#5D9#,
                          16#5D9#, 16#5DD#]);
         when 3 .. 9 =>
            return Hebrew_Under_20 (Value) & " "
              & UTF8 ([16#5DE#, 16#5D0#, 16#5D5#, 16#5EA#]);
         when others =>
            return "";
      end case;
   end Hebrew_Hundreds;

   function Hebrew_Number (Value : Natural) return String;

   function Hebrew_Thousand (Count : Natural) return String is
   begin
      if Count = 1 then
         return UTF8 ([16#5D0#, 16#5DC#, 16#5E3#]);
      elsif Count = 2 then
         return UTF8 ([16#5D0#, 16#5DC#, 16#5E4#, 16#5D9#, 16#5D9#,
                       16#5DD#]);
      else
         return Hebrew_Number (Count) & " "
           & UTF8 ([16#5D0#, 16#5DC#, 16#5E3#]);
      end if;
   end Hebrew_Thousand;

   function Hebrew_Million (Count : Natural) return String is
   begin
      if Count = 1 then
         return Hebrew_Under_20 (1) & " "
           & UTF8 ([16#5DE#, 16#5D9#, 16#5DC#, 16#5D9#, 16#5D5#,
                    16#5DF#]);
      else
         return Hebrew_Number (Count) & " "
           & UTF8 ([16#5DE#, 16#5D9#, 16#5DC#, 16#5D9#, 16#5D5#,
                    16#5E0#, 16#5D9#, 16#5DD#]);
      end if;
   end Hebrew_Million;

   function Hebrew_Number (Value : Natural) return String is
   begin
      if Value < 20 then
         return Hebrew_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Hebrew_Tens (Value / 10);
         else
            return Hebrew_Tens (Value / 10) & " "
              & Hebrew_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Hebrew_Hundreds (Value / 100);
         else
            return Hebrew_Hundreds (Value / 100) & " "
              & Hebrew_Number (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Hebrew_Thousand (Value / 1_000);
         else
            return Hebrew_Thousand (Value / 1_000) & " "
              & Hebrew_Number (Value mod 1_000);
         end if;
      elsif Value <= 999_999_999 then
         if Value mod 1_000_000 = 0 then
            return Hebrew_Million (Value / 1_000_000);
         else
            return Hebrew_Million (Value / 1_000_000) & " "
              & Hebrew_Number (Value mod 1_000_000);
         end if;
      else
         return "";
      end if;
   end Hebrew_Number;

   function Hebrew_Ordinal_Under_20 (Value : Natural) return String is
   begin
      case Value is
         when 1 =>
            return UTF8 ([16#5E8#, 16#5D0#, 16#5E9#, 16#5D5#, 16#5DF#]);
         when 2 =>
            return UTF8 ([16#5E9#, 16#5E0#, 16#5D9#]);
         when 3 =>
            return UTF8 ([16#5E9#, 16#5DC#, 16#5D9#, 16#5E9#, 16#5D9#]);
         when 4 =>
            return UTF8 ([16#5E8#, 16#5D1#, 16#5D9#, 16#5E2#, 16#5D9#]);
         when 5 =>
            return UTF8 ([16#5D7#, 16#5DE#, 16#5D9#, 16#5E9#, 16#5D9#]);
         when 6 =>
            return UTF8 ([16#5E9#, 16#5D9#, 16#5E9#, 16#5D9#]);
         when 7 =>
            return UTF8 ([16#5E9#, 16#5D1#, 16#5D9#, 16#5E2#, 16#5D9#]);
         when 8 =>
            return UTF8 ([16#5E9#, 16#5DE#, 16#5D9#, 16#5E0#, 16#5D9#]);
         when 9 =>
            return UTF8 ([16#5EA#, 16#5E9#, 16#5D9#, 16#5E2#, 16#5D9#]);
         when 10 =>
            return UTF8 ([16#5E2#, 16#5E9#, 16#5D9#, 16#5E8#, 16#5D9#]);
         when 11 .. 19 =>
            return Hebrew_Under_20 (Value);
         when others =>
            return "";
      end case;
   end Hebrew_Ordinal_Under_20;

   function Hebrew_Ordinal (Value : Natural) return String is
   begin
      if Value = 0 then
         return Hebrew_Number (Value);
      elsif Value < 20 then
         return Hebrew_Ordinal_Under_20 (Value);
      elsif Value < 100 then
         if Value mod 10 = 0 then
            return Hebrew_Tens (Value / 10);
         else
            return Hebrew_Tens (Value / 10) & " "
              & Hebrew_Ordinal_Under_20 (Value mod 10);
         end if;
      elsif Value < 1_000 then
         if Value mod 100 = 0 then
            return Hebrew_Number (Value);
         else
            return Hebrew_Hundreds (Value / 100) & " "
              & Hebrew_Ordinal (Value mod 100);
         end if;
      elsif Value < 1_000_000 then
         if Value mod 1_000 = 0 then
            return Hebrew_Thousand (Value / 1_000);
         else
            return Hebrew_Thousand (Value / 1_000) & " "
              & Hebrew_Ordinal (Value mod 1_000);
         end if;
      else
         if Value mod 1_000_000 = 0 then
            return Hebrew_Million (Value / 1_000_000);
         else
            return Hebrew_Million (Value / 1_000_000) & " "
              & Hebrew_Ordinal (Value mod 1_000_000);
         end if;
      end if;
   end Hebrew_Ordinal;

   function Localized_Number (Locale : String; Value : Natural) return String;
   function Localized_Ordinal (Locale : String; Value : Natural) return String;

   function Rule_Based_Spellout
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Depth  : Natural)
      return String;

   function RBNF_Default_Divisor (Base : Natural) return Natural is
      Divisor : Natural := 1;
   begin
      if Base = 0 then
         return 0;
      end if;

      while Divisor <= Base / 10 loop
         Divisor := Divisor * 10;
      end loop;

      return Divisor;
   end RBNF_Default_Divisor;

   function RBNF_Substitution_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Depth  : Natural)
      return String;

   function RBNF_Target_Kind
     (Current : String;
      Marker  : Character)
      return String
   is
   begin
      if Marker = 'C' then
         return "cardinal";
      elsif Marker = 'O' then
         return "ordinal";
      else
         return Current;
      end if;
   end RBNF_Target_Kind;

   function Plural_Category_Name
     (Category : I18N.Plurals.Plural_Category)
      return String
   is
   begin
      case Category is
         when I18N.Plurals.Zero =>
            return "zero";
         when I18N.Plurals.One =>
            return "one";
         when I18N.Plurals.Two =>
            return "two";
         when I18N.Plurals.Few =>
            return "few";
         when I18N.Plurals.Many =>
            return "many";
         when I18N.Plurals.Other =>
            return "other";
      end case;
   end Plural_Category_Name;

   function RBNF_Plural_Affix
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Payload : String;
      Success : out Boolean)
      return String
   is
      Comma : Natural := 0;

      function Trim_Spaces (Text : String) return String is
         First : Natural := Text'First;
         Last  : Natural := Text'Last;
      begin
         while First <= Last and then Text (First) = ' ' loop
            First := First + 1;
         end loop;

         while Last >= First and then Text (Last) = ' ' loop
            Last := Last - 1;
         end loop;

         if First > Last then
            return "";
         else
            return Text (First .. Last);
         end if;
      end Trim_Spaces;

      function Branch_For
        (Name     : String;
         Branches : String;
         Found    : out Boolean)
         return String
      is
         Pos : Natural := Branches'First;
      begin
         Found := False;
         while Pos <= Branches'Last loop
            while Pos <= Branches'Last and then Branches (Pos) = ' ' loop
               Pos := Pos + 1;
            end loop;

            exit when Pos > Branches'Last;

            declare
               Name_Start : constant Natural := Pos;
            begin
               while Pos <= Branches'Last
                 and then Branches (Pos) in 'a' .. 'z'
               loop
                  Pos := Pos + 1;
               end loop;

               while Pos <= Branches'Last and then Branches (Pos) = ' ' loop
                  Pos := Pos + 1;
               end loop;

               if Pos > Branches'Last
                 or else Pos = Name_Start
                 or else Branches (Pos) /= '{'
               then
                  return "";
               end if;

               declare
                  Branch_Name : constant String :=
                    Branches (Name_Start .. Pos - 1);
                  Text_Start  : constant Natural := Pos + 1;
                  Close       : Natural := 0;
               begin
                  Pos := Pos + 1;
                  while Pos <= Branches'Last loop
                     if Branches (Pos) = '}' then
                        Close := Pos;
                        exit;
                     end if;
                     Pos := Pos + 1;
                  end loop;

                  if Close = 0 then
                     return "";
                  elsif Branch_Name = Name then
                     Found := True;
                     return Branches (Text_Start .. Close - 1);
                  end if;

                  Pos := Close + 1;
               end;
            end;
         end loop;

         return "";
      end Branch_For;
   begin
      Success := False;

      for Index in Payload'Range loop
         if Payload (Index) = ',' then
            Comma := Index;
            exit;
         end if;
      end loop;

      if Comma = 0
        or else Comma = Payload'First
        or else Comma = Payload'Last
      then
         return "";
      end if;

      declare
         Selector : constant String :=
           Trim_Spaces (Payload (Payload'First .. Comma - 1));
         Branches : constant String :=
           Trim_Spaces (Payload (Comma + 1 .. Payload'Last));
         Category : constant String :=
           (if Selector = "cardinal" then
              Plural_Category_Name
                (I18N.Plurals.Cardinal
                   (Locale, Long_Long_Integer (Value)))
            elsif Selector = "ordinal" then
              Plural_Category_Name
                (I18N.Plurals.Ordinal
                   (Locale, Long_Long_Integer (Value)))
            elsif Kind = "ordinal" then
              Plural_Category_Name
                (I18N.Plurals.Ordinal
                   (Locale, Long_Long_Integer (Value)))
            else
              "");
      begin
         if Category /= "" then
            declare
               Found_Selected : Boolean := False;
               Selected : constant String :=
                 Branch_For (Category, Branches, Found_Selected);
            begin
               if Found_Selected then
                  Success := True;
                  return Selected;
               end if;
            end;
         end if;

         if Category /= "" then
            declare
               Found_Other : Boolean := False;
               Other_Text : constant String :=
                 Branch_For ("other", Branches, Found_Other);
            begin
               Success := Found_Other;
               return Other_Text;
            end;
         else
            return "";
         end if;
      end;
   end RBNF_Plural_Affix;

   function Fraction_Digit_Words
     (Locale        : String;
      Kind          : String;
      Fraction_Text : String;
      Depth         : Natural)
      return String
   is
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      if Depth > 16 then
         return "";
      end if;

      for Index in Fraction_Text'Range loop
         declare
            Digit_Value : constant Natural :=
              Character'Pos (Fraction_Text (Index)) - Character'Pos ('0');
            Text        : constant String :=
              RBNF_Substitution_Text (Locale, Kind, Digit_Value, Depth + 1);
         begin
            if Text = "" then
               return "";
            elsif Length (Result) > 0 then
               Append (Result, " ");
            end if;
            Append (Result, Text);
         end;
      end loop;

      return To_String (Result);
   end Fraction_Digit_Words;

   function RBNF_Substitution_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Depth  : Natural)
      return String
   is
   begin
      if Depth > 16 then
         return "";
      elsif Kind = "ordinal" then
         return Localized_Ordinal (Locale, Value);
      else
         return Localized_Number (Locale, Value);
      end if;
   end RBNF_Substitution_Text;

   function Evaluate_RBNF_Pattern
     (Locale    : String;
      Kind      : String;
      Value     : Natural;
      Base      : Natural;
      Pattern   : String;
      Depth     : Natural;
      Remainder : Natural)
      return String
   is
      Result : Unbounded_String := Null_Unbounded_String;
      Index  : Natural := Pattern'First;
   begin
      if Depth > 16 or else Pattern'Length = 0 then
         return "";
      end if;

      while Index <= Pattern'Last loop
         if Index + 2 <= Pattern'Last
           and then Pattern (Index) = '>'
           and then Pattern (Index + 1) = '>'
           and then Pattern (Index + 2) = '>'
         then
            declare
               Text : constant String :=
                 RBNF_Substitution_Text
                   (Locale, Kind, Remainder, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 3;
            end;
         elsif Index + 2 <= Pattern'Last
           and then Pattern (Index) = '<'
           and then (Pattern (Index + 1) = 'C'
                     or else Pattern (Index + 1) = 'O')
           and then Pattern (Index + 2) = '<'
         then
            declare
               Quotient : constant Natural := Value / Base;
               Text     : constant String :=
                 RBNF_Substitution_Text
                   (Locale, RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                    Quotient, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 3;
            end;
         elsif Index < Pattern'Last
           and then Pattern (Index) = '<'
           and then Pattern (Index + 1) = '<'
         then
            declare
               Quotient : constant Natural := Value / Base;
               Text     : constant String :=
                 RBNF_Substitution_Text
                   (Locale, Kind, Quotient, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 2;
            end;
         elsif Index + 2 <= Pattern'Last
           and then Pattern (Index) = '>'
           and then (Pattern (Index + 1) = 'C'
                     or else Pattern (Index + 1) = 'O')
           and then Pattern (Index + 2) = '>'
         then
            declare
               Text : constant String :=
                 RBNF_Substitution_Text
                   (Locale, RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                    Remainder, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 3;
            end;
         elsif Index < Pattern'Last
           and then Pattern (Index) = '>'
           and then Pattern (Index + 1) = '>'
         then
            declare
               Text : constant String :=
                 RBNF_Substitution_Text
                   (Locale, Kind, Remainder, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 2;
            end;
         elsif Index + 2 <= Pattern'Last
           and then Pattern (Index) = '='
           and then (Pattern (Index + 1) = 'C'
                     or else Pattern (Index + 1) = 'O')
           and then Pattern (Index + 2) = '='
         then
            declare
               Text : constant String :=
                 RBNF_Substitution_Text
                   (Locale, RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                    Value, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 3;
            end;
         elsif Index < Pattern'Last
           and then Pattern (Index) = '='
           and then Pattern (Index + 1) = '='
         then
            declare
               Text : constant String :=
                 RBNF_Substitution_Text
                   (Locale, Kind, Value, Depth + 1);
            begin
               if Text = "" then
                  return "";
               end if;
               Append (Result, Text);
               Index := Index + 2;
            end;
         elsif Index < Pattern'Last
           and then Pattern (Index) = '$'
           and then Pattern (Index + 1) = '('
         then
            declare
               Close : Natural := 0;
            begin
               for Scan in Index + 2 .. Pattern'Last - 1 loop
                  if Pattern (Scan) = ')'
                    and then Pattern (Scan + 1) = '$'
                  then
                     Close := Scan;
                     exit;
                  end if;
               end loop;

               if Close = 0 then
                  return "";
               end if;

               declare
                  Success : Boolean := False;
                  Text : constant String :=
                    RBNF_Plural_Affix
                      (Locale, Kind, Value,
                       Pattern (Index + 2 .. Close - 1),
                       Success);
               begin
                  if not Success then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Close + 2;
               end;
            end;
         elsif Pattern (Index) = '[' then
            declare
               Close : Natural := 0;
            begin
               for Scan in Index + 1 .. Pattern'Last loop
                  if Pattern (Scan) = ']' then
                     Close := Scan;
                     exit;
                  end if;
               end loop;

               if Close = 0 then
                  return "";
               elsif Remainder /= 0 then
                  declare
                     Text : constant String :=
                       Evaluate_RBNF_Pattern
                         (Locale, Kind, Value, Base,
                          Pattern (Index + 1 .. Close - 1),
                          Depth + 1, Remainder);
                  begin
                     if Text = "" then
                        return "";
                     end if;
                     Append (Result, Text);
                  end;
               end if;

               Index := Close + 1;
            end;
         else
            Append (Result, Pattern (Index));
            Index := Index + 1;
         end if;
      end loop;

      return To_String (Result);
   end Evaluate_RBNF_Pattern;

   function Rule_Based_Spellout
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Depth  : Natural)
      return String
   is
      Found    : Boolean;
      Base     : Natural;
      Divisor  : Natural;
      Rule     : constant String :=
        I18N.Runtime_Data.Spellout_Rule_Text
          (Locale, Kind, Value, Base, Divisor, Found);
   begin
      if not Found or else Base = 0 or else Base > Value or else Depth > 16 then
         return "";
      end if;

      declare
         Effective_Divisor : constant Natural :=
           (if Divisor = 0 then RBNF_Default_Divisor (Base) else Divisor);
      begin
         if Effective_Divisor = 0 then
            return "";
         end if;

         return Evaluate_RBNF_Pattern
           (Locale, Kind, Value, Effective_Divisor, Rule, Depth,
            Value mod Effective_Divisor);
      end;
   end Rule_Based_Spellout;

   function Special_Rule_Based_Spellout
     (Locale        : String;
      Kind          : String;
      Rule_Name     : String;
      Integer_Value : Natural;
      Fraction_Text : String := "")
      return String
   is
      Found : Boolean;
      Rule  : constant String :=
        I18N.Runtime_Data.Spellout_Special_Rule_Text
          (Locale, Kind, Rule_Name, Found);
      function Evaluate_Special_Pattern
        (Pattern : String;
         Depth   : Natural)
         return String
      is
         Result : Unbounded_String := Null_Unbounded_String;
         Index  : Natural := Pattern'First;
      begin
         if Depth > 16 or else Pattern = "" then
            return "";
         end if;

         while Index <= Pattern'Last loop
            if Index + 2 <= Pattern'Last
              and then Pattern (Index) = '>'
              and then Pattern (Index + 1) = '>'
              and then Pattern (Index + 2) = '>'
            then
               declare
                  Text : constant String :=
                    (if Fraction_Text = ""
                     then RBNF_Substitution_Text
                            (Locale, Kind, Integer_Value, Depth + 1)
                     else Fraction_Digit_Words
                            (Locale, Kind, Fraction_Text, Depth + 1));
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 3;
               end;
            elsif Index + 2 <= Pattern'Last
              and then Pattern (Index) = '<'
              and then (Pattern (Index + 1) = 'C'
                        or else Pattern (Index + 1) = 'O')
              and then Pattern (Index + 2) = '<'
            then
               declare
                  Text : constant String :=
                    RBNF_Substitution_Text
                      (Locale, RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                       Integer_Value, Depth + 1);
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 3;
               end;
            elsif Index < Pattern'Last
              and then Pattern (Index) = '<'
              and then Pattern (Index + 1) = '<'
            then
               declare
                  Text : constant String :=
                    RBNF_Substitution_Text
                      (Locale, Kind, Integer_Value, Depth + 1);
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 2;
               end;
            elsif Index + 2 <= Pattern'Last
              and then Pattern (Index) = '>'
              and then (Pattern (Index + 1) = 'C'
                        or else Pattern (Index + 1) = 'O')
              and then Pattern (Index + 2) = '>'
            then
               declare
                  Text : constant String :=
                    (if Fraction_Text = ""
                     then RBNF_Substitution_Text
                            (Locale,
                             RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                             Integer_Value, Depth + 1)
                     else Fraction_Digit_Words
                            (Locale,
                             RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                             Fraction_Text, Depth + 1));
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 3;
               end;
            elsif Index < Pattern'Last
              and then Pattern (Index) = '>'
              and then Pattern (Index + 1) = '>'
            then
               declare
                  Text : constant String :=
                    (if Fraction_Text = ""
                     then RBNF_Substitution_Text
                            (Locale, Kind, Integer_Value, Depth + 1)
                     else Fraction_Digit_Words
                            (Locale, Kind, Fraction_Text, Depth + 1));
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 2;
               end;
            elsif Index + 2 <= Pattern'Last
              and then Pattern (Index) = '='
              and then (Pattern (Index + 1) = 'C'
                        or else Pattern (Index + 1) = 'O')
              and then Pattern (Index + 2) = '='
            then
               declare
                  Text : constant String :=
                    RBNF_Substitution_Text
                      (Locale, RBNF_Target_Kind (Kind, Pattern (Index + 1)),
                       Integer_Value, Depth + 1);
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 3;
               end;
            elsif Index < Pattern'Last
              and then Pattern (Index) = '='
              and then Pattern (Index + 1) = '='
            then
               declare
                  Text : constant String :=
                    RBNF_Substitution_Text
                      (Locale, Kind, Integer_Value, Depth + 1);
               begin
                  if Text = "" then
                     return "";
                  end if;
                  Append (Result, Text);
                  Index := Index + 2;
               end;
            elsif Index < Pattern'Last
              and then Pattern (Index) = '$'
              and then Pattern (Index + 1) = '('
            then
               declare
                  Close : Natural := 0;
               begin
                  for Scan in Index + 2 .. Pattern'Last - 1 loop
                     if Pattern (Scan) = ')'
                       and then Pattern (Scan + 1) = '$'
                     then
                        Close := Scan;
                        exit;
                     end if;
                  end loop;

                  if Close = 0 then
                     return "";
                  end if;

                  declare
                     Success : Boolean := False;
                     Text : constant String :=
                       RBNF_Plural_Affix
                         (Locale, Kind, Integer_Value,
                          Pattern (Index + 2 .. Close - 1),
                          Success);
                  begin
                     if not Success then
                        return "";
                     end if;
                     Append (Result, Text);
                     Index := Close + 2;
                  end;
               end;
            elsif Pattern (Index) = '[' then
               declare
                  Close : Natural := 0;
               begin
                  for Scan in Index + 1 .. Pattern'Last loop
                     if Pattern (Scan) = ']' then
                        Close := Scan;
                        exit;
                     end if;
                  end loop;

                  if Close = 0 then
                     return "";
                  elsif Fraction_Text /= "" or else Integer_Value /= 0 then
                     declare
                        Text : constant String :=
                          Evaluate_Special_Pattern
                            (Pattern (Index + 1 .. Close - 1), Depth + 1);
                     begin
                        if Text = "" then
                           return "";
                        end if;
                        Append (Result, Text);
                     end;
                  end if;

                  Index := Close + 1;
               end;
            else
               Append (Result, Pattern (Index));
               Index := Index + 1;
            end if;
         end loop;

         return To_String (Result);
      end Evaluate_Special_Pattern;
   begin
      if not Found or else Rule = "" then
         return "";
      end if;

      return Evaluate_Special_Pattern (Rule, 0);
   end Special_Rule_Based_Spellout;

   function Localized_Number (Locale : String; Value : Natural) return String is
      Found : Boolean;
      Override : constant String :=
        I18N.Runtime_Data.Spellout_Text
          (Locale, "cardinal", Value, Found);
   begin
      if Found then
         return Override;
      end if;

      declare
         Rule_Text : constant String :=
           Rule_Based_Spellout (Locale, "cardinal", Value, 0);
      begin
         if Rule_Text /= "" then
            return Rule_Text;
         end if;
      end;

      if Language (Locale) = "de" then
         return German_Number (Value);
      elsif Language (Locale) = "fr" then
         return French_Number (Value);
      elsif Language (Locale) = "es" then
         return Spanish_Number (Value);
      elsif Language (Locale) = "it" then
         return Italian_Number (Value);
      elsif Language (Locale) = "pt" then
         return Portuguese_Number (Value);
      elsif Language (Locale) = "nl" then
         return Dutch_Number (Value);
      elsif Language (Locale) = "pl" then
         return Polish_Number (Value);
      elsif Language (Locale) = "cs" then
         return Czech_Number (Value);
      elsif Language (Locale) = "ru" then
         return Russian_Number (Value);
      elsif Language (Locale) = "uk" then
         return Ukrainian_Number (Value);
      elsif Language (Locale) = "ja" then
         return Japanese_Number (Value);
      elsif Language (Locale) = "zh" then
         return Chinese_Number (Value);
      elsif Language (Locale) = "ko" then
         return Korean_Number (Value);
      elsif Language (Locale) = "tr" then
         return Turkish_Number (Value);
      elsif Language (Locale) = "sv" then
         return Swedish_Number (Value);
      elsif Language (Locale) = "da" then
         return Danish_Number (Value);
      elsif Language (Locale) = "no" or else Language (Locale) = "nb" then
         return Norwegian_Number (Value);
      elsif Language (Locale) = "fi" then
         return Finnish_Number (Value);
      elsif Language (Locale) = "id" then
         return Indonesian_Number (Value);
      elsif Language (Locale) = "ms" then
         return Malay_Number (Value);
      elsif Language (Locale) = "eo" then
         return Esperanto_Number (Value);
      elsif Language (Locale) = "vi" then
         return Vietnamese_Number (Value);
      elsif Language (Locale) = "sw" then
         return Swahili_Number (Value);
      elsif Language (Locale) = "af" then
         return Afrikaans_Number (Value);
      elsif Language (Locale) = "eu" then
         return Basque_Number (Value);
      elsif Language (Locale) = "ro" then
         return Romanian_Number (Value);
      elsif Language (Locale) = "ca" then
         return Catalan_Number (Value);
      elsif Language (Locale) = "hu" then
         return Hungarian_Number (Value);
      elsif Language (Locale) = "sk" then
         return Slovak_Number (Value);
      elsif Language (Locale) = "bg" then
         return Bulgarian_Number (Value);
      elsif Language (Locale) = "ar" then
         return Arabic_Number (Value);
      elsif Language (Locale) = "fa" then
         return Persian_Number (Value);
      elsif Language (Locale) = "th" then
         return Thai_Number (Value);
      elsif Language (Locale) = "hi" then
         return Hindi_Number (Value);
      elsif Language (Locale) = "el" then
         return Greek_Number (Value);
      elsif Language (Locale) = "he" then
         return Hebrew_Number (Value);
      else
         return English_Number (Locale, Value);
      end if;
   end Localized_Number;

   function Spellout_Decimal_Separator_Word (Locale : String) return String is
      Found : Boolean;
      Override : constant String :=
        I18N.Runtime_Data.Spellout_Decimal_Separator (Locale, Found);
      Lang : constant String := Language (Locale);
   begin
      if Found then
         return Override;
      end if;

      if Lang = "de" or else Lang = "da" or else Lang = "no"
        or else Lang = "nb" or else Lang = "sv" or else Lang = "fi"
      then
         return "komma";
      elsif Lang = "fr" then
         return "virgule";
      elsif Lang = "es" then
         return "coma";
      elsif Lang = "it" then
         return "virgola";
      elsif Lang = "pt" then
         return "v" & U (16#00ED#) & "rgula";
      elsif Lang = "nl" or else Lang = "af" then
         return "komma";
      elsif Lang = "pl" then
         return "przecinek";
      elsif Lang = "cs" or else Lang = "sk" then
         return U (16#010D#) & U (16#00E1#) & "rka";
      elsif Lang = "ru" or else Lang = "uk" then
         return UTF8 ([16#0437#, 16#0430#, 16#043F#, 16#044F#,
                       16#0442#, 16#0430#, 16#044F#]);
      elsif Lang = "tr" then
         return "virg" & U (16#00FC#) & "l";
      elsif Lang = "id" or else Lang = "ms" then
         return "koma";
      elsif Lang = "eo" then
         return "komo";
      elsif Lang = "vi" then
         return "ph" & U (16#1EA9#) & "y";
      elsif Lang = "sw" then
         return "nukta";
      elsif Lang = "eu" then
         return "koma";
      elsif Lang = "ro" then
         return "virgul" & U (16#0103#);
      elsif Lang = "ca" then
         return "coma";
      elsif Lang = "hu" then
         return "vessz" & U (16#0151#);
      elsif Lang = "bg" then
         return UTF8 ([16#0437#, 16#0430#, 16#043F#, 16#0435#,
                       16#0442#, 16#0430#, 16#044F#]);
      elsif Lang = "ar" then
         return UTF8 ([16#0641#, 16#0627#, 16#0635#, 16#0644#,
                       16#0629#]);
      elsif Lang = "fa" then
         return UTF8 ([16#0645#, 16#0645#, 16#06CC#, 16#0632#]);
      elsif Lang = "th" then
         return UTF8 ([16#0E08#, 16#0E38#, 16#0E14#]);
      elsif Lang = "hi" then
         return UTF8 ([16#0926#, 16#0936#, 16#092E#, 16#0932#,
                       16#0935#]);
      elsif Lang = "el" then
         return UTF8 ([16#03BA#, 16#03CC#, 16#03BC#, 16#03BC#,
                       16#03B1#]);
      elsif Lang = "he" then
         return UTF8 ([16#05E0#, 16#05E7#, 16#05D5#, 16#05D3#,
                       16#05D4#]);
      else
         return "point";
      end if;
   end Spellout_Decimal_Separator_Word;

   function Signed_Spellout_Override
     (Locale   : String;
      Kind     : String;
      Negative : Boolean;
      Amount   : Natural;
      Found    : out Boolean)
      return String;

   function Localized_Decimal_Number
     (Locale        : String;
      Negative      : Boolean;
      Integer_Part  : Natural;
      Fraction_Text : String;
      Found_Exact   : out Boolean)
      return String
   is
      function Fraction_Is_Zero return Boolean is
      begin
         for Index in Fraction_Text'Range loop
            if Fraction_Text (Index) /= '0' then
               return False;
            end if;
         end loop;

         return Fraction_Text'Length > 0;
      end Fraction_Is_Zero;

      function Decimal_Rule_Text return String is
         Selected : constant String :=
           (if Integer_Part = 0 and then not Fraction_Is_Zero
            then Special_Rule_Based_Spellout
                   (Locale, "cardinal", "zero-decimal", Integer_Part,
                    Fraction_Text)
            elsif Fraction_Is_Zero
            then Special_Rule_Based_Spellout
                   (Locale, "cardinal", "integer-decimal", Integer_Part,
                    Fraction_Text)
            else "");
      begin
         if Selected /= "" then
            return Selected;
         else
            return Special_Rule_Based_Spellout
              (Locale, "cardinal", "decimal", Integer_Part, Fraction_Text);
         end if;
      end Decimal_Rule_Text;

      Integer_Found : Boolean := False;
      Integer_Text  : constant String :=
        (if Negative
         then Signed_Spellout_Override
                (Locale, "cardinal", True, Integer_Part, Integer_Found)
         else "");
      Integer_Words : constant String :=
        (if Integer_Found
         then Integer_Text
         else Localized_Number (Locale, Integer_Part));
      Decimal_Rule : constant String :=
        (if Integer_Found
         then ""
         else Decimal_Rule_Text);
      Result : Unbounded_String :=
        To_Unbounded_String
          (if Decimal_Rule /= ""
           then Decimal_Rule
           else Integer_Words & " " & Spellout_Decimal_Separator_Word (Locale));
   begin
      Found_Exact := Integer_Found;

      if Integer_Words = "" then
         return "";
      end if;

      if Decimal_Rule /= "" then
         return Decimal_Rule;
      end if;

      for Index in Fraction_Text'Range loop
         declare
            Digit_Value : constant Natural :=
              Character'Pos (Fraction_Text (Index)) - Character'Pos ('0');
            Digit_Word  : constant String :=
              Localized_Number (Locale, Digit_Value);
         begin
            if Digit_Word = "" then
               return "";
            end if;
            Append (Result, " ");
            Append (Result, Digit_Word);
         end;
      end loop;

      return To_String (Result);
   end Localized_Decimal_Number;

   function Localized_Ordinal (Locale : String; Value : Natural) return String is
      Found : Boolean;
      Override : constant String :=
        I18N.Runtime_Data.Spellout_Text
          (Locale, "ordinal", Value, Found);
   begin
      if Found then
         return Override;
      end if;

      declare
         Rule_Text : constant String :=
           Rule_Based_Spellout (Locale, "ordinal", Value, 0);
      begin
         if Rule_Text /= "" then
            return Rule_Text;
         end if;
      end;

      if Language (Locale) = "de" then
         return German_Ordinal (Value);
      elsif Language (Locale) = "fr" then
         return French_Ordinal (Value);
      elsif Language (Locale) = "es" then
         return Spanish_Ordinal (Value);
      elsif Language (Locale) = "it" then
         return Italian_Ordinal (Value);
      elsif Language (Locale) = "pt" then
         return Portuguese_Ordinal (Value);
      elsif Language (Locale) = "nl" then
         return Dutch_Ordinal (Value);
      elsif Language (Locale) = "pl" then
         return Polish_Ordinal (Value);
      elsif Language (Locale) = "cs" then
         return Czech_Ordinal (Value);
      elsif Language (Locale) = "ru" then
         return Russian_Ordinal (Value);
      elsif Language (Locale) = "uk" then
         return Ukrainian_Ordinal (Value);
      elsif Language (Locale) = "ja" then
         return Japanese_Ordinal (Value);
      elsif Language (Locale) = "zh" then
         return Chinese_Ordinal (Value);
      elsif Language (Locale) = "ko" then
         return Korean_Ordinal (Value);
      elsif Language (Locale) = "tr" then
         return Turkish_Ordinal (Value);
      elsif Language (Locale) = "sv" then
         return Swedish_Ordinal (Value);
      elsif Language (Locale) = "da" then
         return Danish_Ordinal (Value);
      elsif Language (Locale) = "no" or else Language (Locale) = "nb" then
         return Norwegian_Ordinal (Value);
      elsif Language (Locale) = "fi" then
         return Finnish_Ordinal (Value);
      elsif Language (Locale) = "id" then
         return Indonesian_Ordinal (Value);
      elsif Language (Locale) = "ms" then
         return Malay_Ordinal (Value);
      elsif Language (Locale) = "eo" then
         return Esperanto_Ordinal (Value);
      elsif Language (Locale) = "vi" then
         return Vietnamese_Ordinal (Value);
      elsif Language (Locale) = "sw" then
         return Swahili_Ordinal (Value);
      elsif Language (Locale) = "af" then
         return Afrikaans_Ordinal (Value);
      elsif Language (Locale) = "eu" then
         return Basque_Ordinal (Value);
      elsif Language (Locale) = "ro" then
         return Romanian_Ordinal (Value);
      elsif Language (Locale) = "ca" then
         return Catalan_Ordinal (Value);
      elsif Language (Locale) = "hu" then
         return Hungarian_Ordinal (Value);
      elsif Language (Locale) = "sk" then
         return Slovak_Ordinal (Value);
      elsif Language (Locale) = "bg" then
         return Bulgarian_Ordinal (Value);
      elsif Language (Locale) = "ar" then
         return Arabic_Ordinal (Value);
      elsif Language (Locale) = "fa" then
         return Persian_Ordinal (Value);
      elsif Language (Locale) = "th" then
         return Thai_Ordinal (Value);
      elsif Language (Locale) = "hi" then
         return Hindi_Ordinal (Value);
      elsif Language (Locale) = "el" then
         return Greek_Ordinal (Value);
      elsif Language (Locale) = "he" then
         return Hebrew_Ordinal (Value);
      else
         return English_Ordinal (Locale, Value);
      end if;
   end Localized_Ordinal;

   function Signed_Spellout_Override
     (Locale   : String;
      Kind     : String;
      Negative : Boolean;
      Amount   : Natural;
      Found    : out Boolean)
      return String
   is
   begin
      if Negative and then Amount /= 0 then
         declare
            Exact : constant String :=
              I18N.Runtime_Data.Spellout_Signed_Text
                (Locale, Kind, -Integer (Amount), Found);
         begin
            if Found then
               return Exact;
            else
               declare
                  Rule_Text : constant String :=
                    Special_Rule_Based_Spellout
                      (Locale, Kind, "negative", Amount);
               begin
                  if Rule_Text /= "" then
                     Found := True;
                     return Rule_Text;
                  end if;
               end;
            end if;
         end;
         Found := False;
         return "";
      else
         Found := False;
         return "";
      end if;
   end Signed_Spellout_Override;

   procedure Format_Plain_Into
     (Value_Text : String;
      Locale     : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Start        : Positive;
      Integer_From : Positive;
      Integer_To   : Natural := 0;
      Dot_Pos      : Natural := 0;
      Frac_From    : Positive := Value_Text'First;
      Frac_To      : Natural := 0;
      Negative     : Boolean := False;
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      if Value_Text'Length = 0 then
         return;
      end if;

      Start := Value_Text'First;
      if Value_Text (Start) = '-' or else Value_Text (Start) = '+' then
         Negative := Value_Text (Start) = '-';
         if Value_Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      Integer_From := Start;
      for Index in Start .. Value_Text'Last loop
         if Value_Text (Index) = '.' then
            if Dot_Pos /= 0 then
               return;
            end if;
            Dot_Pos := Index;
         elsif not Is_Digit (Value_Text (Index)) then
            return;
         end if;
      end loop;

      if Dot_Pos = 0 then
         Integer_To := Value_Text'Last;
      else
         Integer_To := Dot_Pos - 1;
         Frac_From := Dot_Pos + 1;
         Frac_To := Value_Text'Last;
      end if;

      if Integer_To < Integer_From
        or else (Dot_Pos /= 0 and then Frac_To < Frac_From)
      then
         return;
      end if;

      while Integer_From < Integer_To
        and then Value_Text (Integer_From) = '0'
      loop
         Integer_From := Integer_From + 1;
      end loop;

      if Negative then
         Put
           (Target, Last, Overflow,
            Number_Minus_Sign (Locale));
      end if;

      Put_Grouped_Integer
        (Target, Last, Overflow, Locale,
         Value_Text (Integer_From .. Integer_To), 0);

      if Dot_Pos /= 0 then
         Put (Target, Last, Overflow, Decimal_Separator (Locale));
         for Index in Frac_From .. Frac_To loop
            Put_Digit (Target, Last, Overflow, Locale, Value_Text (Index));
         end loop;
      end if;

      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Plain_Into;

   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String := "";
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Parsed_Style : Number_Style;
      Value        : Long_Long_Float;
      Negative     : Boolean;
      Had_Frac     : Boolean;
      Frac_Len     : Natural;
      Abs_Value    : Long_Long_Float;
   begin
      if Style = "" then
         Format_Plain_Into
           (Value_Text => Value_Text,
            Locale     => Locale,
            Target     => Target,
            Last       => Last,
            Ok         => Ok,
            Overflow   => Overflow);
         return;
      end if;

      Last := 0;
      Ok := False;
      Overflow := False;

      if not Parse_Style (Style, Parsed_Style) then
         return;
      end if;

      if Parsed_Style.Mode = Ordinal_Words_Mode then
         declare
            Spellout_Negative : Boolean;
            Amount            : Natural;
            Exact_Found       : Boolean;
            Exact_Text        : constant String :=
              I18N.Runtime_Data.Spellout_Value_Text
                (Locale, "ordinal", Value_Text, Exact_Found);
         begin
            if Exact_Found then
               Put (Target, Last, Overflow, Exact_Text);
               Ok := not Overflow;
               return;
            end if;

            if not Parse_Spellout_Integer
              (Value_Text, Spellout_Negative, Amount)
            then
               return;
            end if;

            declare
               Found_Exact : Boolean;
               Exact_Text  : constant String :=
                 Signed_Spellout_Override
                   (Locale, "ordinal", Spellout_Negative, Amount,
                    Found_Exact);
               Text : constant String :=
                 (if Found_Exact
                  then Exact_Text
                  else Localized_Ordinal (Locale, Amount));
            begin
               if Text = "" then
                  return;
               end if;

               if Spellout_Negative and then not Found_Exact then
                  Put (Target, Last, Overflow, Number_Minus_Sign (Locale));
                  Put (Target, Last, Overflow, " ");
               end if;

               Put (Target, Last, Overflow, Text);
               Ok := not Overflow;
               return;
            end;
         end;
      elsif Parsed_Style.Mode = Spellout_Mode then
         declare
            Spellout_Negative : Boolean;
            Amount            : Natural;
            Exact_Found       : Boolean;
            Exact_Text        : constant String :=
              I18N.Runtime_Data.Spellout_Value_Text
                (Locale, "cardinal", Value_Text, Exact_Found);
         begin
            if Exact_Found then
               Put (Target, Last, Overflow, Exact_Text);
               Ok := not Overflow;
               return;
            end if;

            if Parse_Spellout_Integer
              (Value_Text, Spellout_Negative, Amount)
            then
               declare
                  Found_Exact : Boolean;
                  Exact_Text  : constant String :=
                    Signed_Spellout_Override
                      (Locale, "cardinal", Spellout_Negative, Amount,
                       Found_Exact);
                  Text : constant String :=
                    (if Found_Exact
                     then Exact_Text
                     else Localized_Number (Locale, Amount));
               begin
                  if Text = "" then
                     return;
                  end if;

                  if Spellout_Negative and then not Found_Exact then
                     Put (Target, Last, Overflow, Number_Minus_Sign (Locale));
                     Put (Target, Last, Overflow, " ");
                  end if;

                  Put (Target, Last, Overflow, Text);
                  Ok := not Overflow;
                  return;
               end;
            else
               declare
                  Integer_Part  : Natural;
                  Fraction_From : Natural;
                  Fraction_To   : Natural;
                  Valid         : Boolean;
               begin
                  Parse_Spellout_Decimal
                    (Value_Text, Spellout_Negative, Integer_Part,
                     Fraction_From, Fraction_To, Valid);
                  if not Valid then
                     return;
                  end if;

                  declare
                     Found_Exact : Boolean;
                     Text : constant String :=
                       Localized_Decimal_Number
                         (Locale, Spellout_Negative, Integer_Part,
                          Value_Text (Fraction_From .. Fraction_To),
                          Found_Exact);
                  begin
                     if Text = "" then
                        return;
                     end if;

                     if Spellout_Negative and then not Found_Exact then
                        Put
                          (Target, Last, Overflow, Number_Minus_Sign (Locale));
                        Put (Target, Last, Overflow, " ");
                     end if;

                     Put (Target, Last, Overflow, Text);
                     Ok := not Overflow;
                     return;
                  end;
               end;
            end if;
         end;
      end if;

      if not Parse_Value (Value_Text, Value, Negative, Had_Frac, Frac_Len) then
         return;
      end if;

      Abs_Value := Value * Parsed_Style.Scale;
      case Parsed_Style.Mode is
         when Decimal_Mode =>
            Emit_Decimal
              (Abs_Value, Negative, Locale, Parsed_Style, Had_Frac, Frac_Len,
               "", Target, Last, Overflow);
         when Percent_Mode =>
            Emit_Decimal
              (Abs_Value * 100.0, Negative, Locale, Parsed_Style, False, 0,
               Number_Percent_Suffix (Locale),
               Target, Last, Overflow);
         when Permille_Mode =>
            Emit_Decimal
              (Abs_Value * 1_000.0, Negative, Locale, Parsed_Style, False, 0,
               Number_Permille_Suffix (Locale),
               Target, Last, Overflow);
         when Compact_Short_Mode =>
            Emit_Compact
              (Abs_Value, Negative, Locale, False, Parsed_Style, Target,
               Last, Overflow);
         when Compact_Long_Mode =>
            Emit_Compact
              (Abs_Value, Negative, Locale, True, Parsed_Style, Target, Last,
               Overflow);
         when Scientific_Mode =>
            Emit_Exponent
              (Abs_Value, Negative, Locale, False, Parsed_Style, Target,
               Last, Overflow);
         when Engineering_Mode =>
            Emit_Exponent
              (Abs_Value, Negative, Locale, True, Parsed_Style, Target, Last,
               Overflow);
         when Spellout_Mode | Ordinal_Words_Mode =>
            null;
      end case;

      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Into;

end I18N.Number_Format;
