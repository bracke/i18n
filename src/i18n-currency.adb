with I18N.Number_Format;
with I18N.CLDR_Data;
with I18N.Locale_Data;
with I18N.Plurals;
with I18N.Runtime_Data;

package body I18N.Currency is

   type Currency_Display is
     (Symbol, Narrow_Symbol, Name_Display, ISO_Code_Display);

   type Currency_Style is record
      Code       : String (1 .. 3) := "USD";
      Display    : Currency_Display := Symbol;
      Accounting : Boolean := False;
      Cash       : Boolean := False;
   end record;

   function Is_Valid_Raw_Code (Code : String) return Boolean is
   begin
      if Code'Length /= 3 then
         return False;
      end if;

      for C of Code loop
         if C not in 'A' .. 'Z' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Raw_Code;

   function Parse_Style (Option : String; Style : out Currency_Style)
                         return Boolean is
      Slash : Natural := 0;
   begin
      Style := (Code => "USD", Display => Symbol, Accounting => False,
                Cash => False);

      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash := Index;
            exit;
         end if;
      end loop;

      declare
         Code : constant String :=
           (if Slash = 0 then Option else Option (Option'First .. Slash - 1));
      begin
         if not Is_Valid_Raw_Code (Code) then
            return False;
         end if;

         Style.Code := Code;
      end;

      if Slash = 0 then
         return True;
      end if;

      declare
         Variant : constant String := Option (Slash + 1 .. Option'Last);
         Start   : Positive := Variant'First;

         --  Every option word the currency variant grammar accepts. "unit",
         --  "width", "full", "code", "precision", "currency", and "standard"
         --  are structural or name the default; the rest carry a flag.
         function Known_Word (W : String) return Boolean is
           (W = "symbol" or else W = "unit" or else W = "width"
            or else W = "short" or else W = "narrow" or else W = "full"
            or else W = "name" or else W = "long" or else W = "iso"
            or else W = "code" or else W = "accounting" or else W = "cash"
            or else W = "precision" or else W = "currency"
            or else W = "standard");

         procedure Apply_Word (W : String) is
         begin
            if W = "accounting" then
               Style.Accounting := True;
            elsif W = "cash" then
               Style.Cash := True;
            elsif W = "narrow" then
               Style.Display := Narrow_Symbol;
            elsif W = "iso" then
               Style.Display := ISO_Code_Display;
            elsif W = "name" or else W = "long" then
               Style.Display := Name_Display;
            elsif W = "symbol" or else W = "short" then
               Style.Display := Symbol;
            end if;
         end Apply_Word;
      begin
         --  Accept any '-'/'/'-separated run of the known words in any order.
         --  Width words override left to right (last wins); accounting and
         --  cash are orthogonal flags. Any unknown word rejects the whole
         --  variant, so "USD/bogus" and "USD/unit-width-medium" still fail.
         if Variant'Length = 0 then
            return False;
         end if;

         for Index in Variant'Range loop
            if Variant (Index) = '-' or else Variant (Index) = '/' then
               declare
                  Word : constant String := Variant (Start .. Index - 1);
               begin
                  if Word'Length = 0 or else not Known_Word (Word) then
                     return False;
                  end if;
                  Apply_Word (Word);
               end;
               Start := Index + 1;
            end if;
         end loop;

         declare
            Word : constant String := Variant (Start .. Variant'Last);
         begin
            if Word'Length = 0 or else not Known_Word (Word) then
               return False;
            end if;
            Apply_Word (Word);
         end;
      end;

      return True;
   end Parse_Style;

   function Is_Valid_Code (Code : String) return Boolean is
      Style : Currency_Style;
   begin
      return Parse_Style (Code, Style);
   end Is_Valid_Code;

   function Minor_Units (Code : String) return Natural is
      Found : Boolean;
      Value : constant Natural :=
        I18N.Runtime_Data.Currency_Natural (Code, "minor_units", Found);
   begin
      return (if Found then Value else I18N.CLDR_Data.Currency_Minor_Units (Code));
   end Minor_Units;

   function Cash_Increment (Code : String) return Natural is
      Found : Boolean;
      Value : constant Natural :=
        I18N.Runtime_Data.Currency_Natural (Code, "cash_increment", Found);
   begin
      return
        (if Found then Value else I18N.CLDR_Data.Currency_Cash_Increment (Code));
   end Cash_Increment;

   function Decimal_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("decimal_separator", Locale, I18N.CLDR_Data.Decimal_Separator'Access));

   function Group_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("group_separator", Locale, I18N.CLDR_Data.Group_Separator'Access));

   function Number_Minus_Sign (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("number_minus_sign", Locale, I18N.CLDR_Data.Number_Minus_Sign'Access));

   function Uses_Indian_Grouping (Locale : String) return Boolean is
      Found : Boolean;
      Value : constant Boolean :=
        I18N.Runtime_Data.Locale_Boolean
          (Locale, "uses_indian_grouping", Found);
      Store_Found : Boolean := False;
      Store_Value : constant String :=
        (if Found then ""
         else I18N.Locale_Data.Language_Member ("indian_grouping", Locale,
                                                Store_Found));
   begin
      if Found then
         return Value;
      elsif Store_Found then
         return Store_Value = "1";
      end if;

      --  India uses Indian grouping whatever the language; the compiled table
      --  carries this as a "-IN" rule that narrowing drops with the Indian
      --  languages, so apply it here to stay faithful.
      for Index in Locale'First .. Locale'Last - 2 loop
         if Locale (Index .. Index + 2) = "-IN" then
            return True;
         end if;
      end loop;

      return I18N.CLDR_Data.Uses_Indian_Grouping (Locale);
   end Uses_Indian_Grouping;

   function Currency_Symbol (Code : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Currency_Text (Code, "symbol", Found);
   begin
      return (if Found then Value else I18N.CLDR_Data.Currency_Symbol (Code));
   end Currency_Symbol;

   function Currency_Narrow_Symbol (Code : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Currency_Text (Code, "narrow_symbol", Found);
   begin
      return
        (if Found then Value else I18N.CLDR_Data.Currency_Narrow_Symbol (Code));
   end Currency_Narrow_Symbol;

   function Currency_Display_Name
     (Locale   : String;
      Code     : String;
      Category : I18N.Plurals.Plural_Category := I18N.Plurals.Other)
      return String
   is
      Category_Name : constant String :=
        (case Category is
           when I18N.Plurals.Zero  => "zero",
           when I18N.Plurals.One   => "one",
           when I18N.Plurals.Two   => "two",
           when I18N.Plurals.Few   => "few",
           when I18N.Plurals.Many  => "many",
           when I18N.Plurals.Other => "other");
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Currency_Text
          (Locale, Code, "display_name." & Category_Name, Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Global_Found : Boolean;
         Global_Value : constant String :=
           I18N.Runtime_Data.Currency_Text
             (Code, "display_name." & Category_Name, Global_Found);
      begin
         if Global_Found then
            return Global_Value;
         end if;
      end;

      declare
         Generic_Found : Boolean;
         Generic_Value : constant String :=
           I18N.Runtime_Data.Currency_Text
             (Locale, Code, "display_name", Generic_Found);
      begin
         if Generic_Found then
            return Generic_Value;
         end if;
      end;

      declare
         Global_Generic_Found : Boolean;
         Global_Generic_Value : constant String :=
           I18N.Runtime_Data.Currency_Text
             (Code, "display_name", Global_Generic_Found);
      begin
         if Global_Generic_Found then
            return Global_Generic_Value;
         end if;
      end;

      declare
         Store_Found : Boolean;
         Store_Value : constant String :=
           I18N.Locale_Data.Shard_Lookup
             ("currency", "currency", Locale, Code & ":" & Category_Name,
              Store_Found);
      begin
         if Store_Found then
            return Store_Value;
         end if;
      end;

      return
        I18N.CLDR_Data.Currency_Display_Name
          (Locale, Code, Category_Name);
   end Currency_Display_Name;

   function Display_Text
     (Style    : Currency_Style;
      Locale   : String;
      Category : I18N.Plurals.Plural_Category := I18N.Plurals.Other)
      return String
   is
   begin
      case Style.Display is
         when Symbol =>
            return Currency_Symbol (Style.Code);
         when Narrow_Symbol =>
            return Currency_Narrow_Symbol (Style.Code);
         when Name_Display =>
            return Currency_Display_Name (Locale, Style.Code, Category);
         when ISO_Code_Display =>
            return Style.Code;
      end case;
   end Display_Text;

   function Symbol_First (Locale : String) return Boolean is
      Found : Boolean;
      Value : constant Boolean :=
        I18N.Runtime_Data.Locale_Boolean
          (Locale, "currency_symbol_first", Found);
      Store_Found : Boolean := False;
      Store_Value : constant String :=
        (if Found then ""
         else I18N.Locale_Data.Language_Member ("currency_symbol_first",
                                                Locale, Store_Found));
   begin
      if Found then
         return Value;
      elsif Store_Found then
         return Store_Value = "1";
      end if;
      return I18N.CLDR_Data.Currency_Symbol_First (Locale);
   end Symbol_First;

   function Amount_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("currency_amount_separator", Locale,
         I18N.CLDR_Data.Currency_Amount_Separator'Access));

   function Accounting_Prefix (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("currency_accounting_prefix", Locale,
         I18N.CLDR_Data.Currency_Accounting_Prefix'Access));

   function Accounting_Suffix (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("currency_accounting_suffix", Locale,
         I18N.CLDR_Data.Currency_Accounting_Suffix'Access));

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

   procedure Put_Digit
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit    : Character)
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           "digit",
           Character'Pos (Digit) - Character'Pos ('0'),
           Found);
   begin
      Put
        (Target,
         Last,
         Overflow,
         (if Found then Value
          else I18N.Number_Format.Digit_Text (Locale, Digit)));
   end Put_Digit;

   procedure Put_Integer_With_Grouping
     (Target       : in out String;
      Last         : in out Natural;
      Overflow     : in out Boolean;
      Locale       : String;
      Amount_Text  : String;
      Integer_From : Positive;
      Integer_To   : Natural)
   is
      Digit_Count      : constant Natural := Integer_To - Integer_From + 1;
      Primary_Group    : constant Natural := 3;
      Secondary_Group  : constant Natural :=
        (if Uses_Indian_Grouping (Locale) then 2 else 3);
      First_Group      : Natural;
      Written_In_Group : Natural := 0;
      Remaining        : Natural := Digit_Count;
      Group_Sep        : constant String := Group_Separator (Locale);
   begin
      if Digit_Count <= Primary_Group then
         First_Group := Digit_Count;
      else
         First_Group := (Digit_Count - Primary_Group) mod Secondary_Group;
         if First_Group = 0 then
            First_Group := Secondary_Group;
         end if;
      end if;

      for Index in Integer_From .. Integer_To loop
         Put_Digit (Target, Last, Overflow, Locale, Amount_Text (Index));
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
   end Put_Integer_With_Grouping;

   function Power_10 (Scale : Natural) return Natural is
      Result : Natural := 1;
   begin
      for Index in 1 .. Scale loop
         Result := Result * 10;
      end loop;

      return Result;
   end Power_10;

   function Saturating_Integer_Value
     (Text : String;
      Last : Natural)
      return Long_Long_Integer
   is
      Result : Long_Long_Integer := 0;
   begin
      for Index in Text'First .. Text'First + Last - 1 loop
         declare
            Digit : constant Long_Long_Integer :=
              Long_Long_Integer
                (Character'Pos (Text (Index)) - Character'Pos ('0'));
         begin
            if Result > (Long_Long_Integer'Last - Digit) / 10 then
               return Long_Long_Integer'Last;
            end if;

            Result := Result * 10 + Digit;
         end;
      end loop;

      return Result;
   end Saturating_Integer_Value;

   procedure Normalize_Integer
     (Source       : String;
      Integer_From : Positive;
      Integer_To   : Natural;
      Add_One      : Boolean;
      Target       : out String;
      Last         : out Natural)
   is
      Carry : Natural := (if Add_One then 1 else 0);
      First : Positive := Integer_From;
   begin
      while First < Integer_To and then Source (First) = '0' loop
         First := First + 1;
      end loop;

      Last := 0;
      for Index in First .. Integer_To loop
         Last := Last + 1;
         Target (Target'First + Last - 1) := Source (Index);
      end loop;

      if Last = 0 then
         Last := 1;
         Target (Target'First) := '0';
      end if;

      if Carry = 1 then
         for Offset in reverse 0 .. Last - 1 loop
            declare
               Index : constant Positive := Target'First + Offset;
               Digit : constant Natural :=
                 Character'Pos (Target (Index)) - Character'Pos ('0');
            begin
               if Digit = 9 then
                  Target (Index) := '0';
               else
                  Target (Index) :=
                    Character'Val (Character'Pos ('0') + Digit + 1);
                  Carry := 0;
                  exit;
               end if;
            end;
         end loop;

         if Carry = 1 then
            for Offset in reverse 0 .. Last - 1 loop
               declare
                  Index : constant Positive := Target'First + Offset;
               begin
                  Target (Index + 1) := Target (Index);
               end;
            end loop;
            Target (Target'First) := '1';
            Last := Last + 1;
         end if;
      end if;
   end Normalize_Integer;

   procedure Put_Fraction
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Natural;
      Scale    : Natural)
   is
      Divisor : Natural := Power_10 (Scale);
      Rest    : Natural := Value;
   begin
      for Index in 1 .. Scale loop
         Divisor := Divisor / 10;
         Put_Digit
           (Target, Last, Overflow, Locale,
            Character'Val (Character'Pos ('0') + Rest / Divisor));
         Rest := Rest mod Divisor;
      end loop;
   end Put_Fraction;

   procedure Format_Into
     (Amount_Text   : String;
      Currency_Code : String;
      Locale        : String;
      Target        : in out String;
      Last          : out Natural;
      Ok            : out Boolean;
      Overflow      : out Boolean)
   is
      Style        : Currency_Style;
      Scale        : Natural;
      Start        : Positive;
      Integer_From : Positive;
      Integer_To   : Natural := 0;
      Dot_Pos      : Natural := 0;
      Frac_From    : Positive := Amount_Text'First;
      Frac_To      : Natural := 0;
      Negative     : Boolean := False;
      Decimal_Sep  : constant String := Decimal_Separator (Locale);
      Display      : String (1 .. 96);
      Display_Last : Natural := 0;
      Frac_Value   : Natural := 0;
      Extra_Digit  : Natural := 0;
      Unit         : Natural;
      Increment    : Natural;
      Carry        : Boolean := False;
      Integer_Text : String (1 .. Amount_Text'Length + 1);
      Integer_Last : Natural := 0;

      procedure Put_Display (Add_Trailing_Space : Boolean) is
         Text : constant String := Display (1 .. Display_Last);
      begin
         Put (Target, Last, Overflow, Text);
         if Add_Trailing_Space
           and then
             (Style.Display = ISO_Code_Display
              or else (Style.Display = Symbol and then Text = Style.Code))
         then
            Put (Target, Last, Overflow, Amount_Separator (Locale));
         end if;
      end Put_Display;

      procedure Load_Display
        (Category : I18N.Plurals.Plural_Category := I18N.Plurals.Other)
      is
         Text : constant String := Display_Text (Style, Locale, Category);
      begin
         if Text'Length > Display'Length then
            Display_Last := 0;
         else
            Display_Last := Text'Length;
            Display (1 .. Display_Last) := Text;
         end if;
      end Load_Display;

      procedure Set_Rounded (Value : Long_Long_Integer) is
         Digits_Buf : String (1 .. 32);
         Count      : Natural := 0;
         Rest       : Long_Long_Integer := Value;
      begin
         if Rest <= 0 then
            Integer_Text (Integer_Text'First) := '0';
            Integer_Last := 1;
            return;
         end if;

         while Rest > 0 loop
            Count := Count + 1;
            Digits_Buf (Count) :=
              Character'Val
                (Character'Pos ('0') + Natural (Rest mod 10));
            Rest := Rest / 10;
         end loop;

         Integer_Last := Count;
         for Offset in 1 .. Count loop
            Integer_Text (Integer_Text'First + Offset - 1) :=
              Digits_Buf (Count - Offset + 1);
         end loop;
      end Set_Rounded;
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      if not Parse_Style (Currency_Code, Style) or else Amount_Text'Length = 0 then
         return;
      end if;

      Scale := Minor_Units (Style.Code);
      Start := Amount_Text'First;

      if Amount_Text (Start) = '-' or else Amount_Text (Start) = '+' then
         Negative := Amount_Text (Start) = '-';
         if Amount_Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      Integer_From := Start;
      for Index in Start .. Amount_Text'Last loop
         if Amount_Text (Index) = '.' then
            if Dot_Pos /= 0 then
               return;
            end if;
            Dot_Pos := Index;
         elsif Amount_Text (Index) not in '0' .. '9' then
            return;
         end if;
      end loop;

      if Dot_Pos = 0 then
         Integer_To := Amount_Text'Last;
      else
         Integer_To := Dot_Pos - 1;
         Frac_From := Dot_Pos + 1;
         Frac_To := Amount_Text'Last;
      end if;

      if Integer_To < Integer_From then
         return;
      end if;

      if Dot_Pos /= 0 then
         if Frac_To < Frac_From then
            return;
         elsif not (Style.Cash and then Scale = 0)
           and then Natural (Frac_To - Frac_From + 1) >
             Scale + (if Style.Cash then 1 else 0)
         then
            --  A zero-decimal cash currency (for example HUF with a cash
            --  increment of 5) accepts a fractional amount and rounds it into
            --  the integer part below; every other style keeps the strict
            --  precision limit.
            return;
         end if;
      end if;

      if Scale > 0 then
         for Offset in 0 .. Scale - 1 loop
            Frac_Value := Frac_Value * 10;
            declare
               Source_Index : constant Natural :=
                 (if Dot_Pos = 0 then 0 else Dot_Pos + 1 + Offset);
            begin
               if Source_Index /= 0 and then Source_Index <= Frac_To then
                  Frac_Value :=
                    Frac_Value
                    + Character'Pos (Amount_Text (Source_Index))
                    - Character'Pos ('0');
               end if;
            end;
         end loop;
      end if;

      if Style.Cash and then Dot_Pos /= 0 and then Frac_To >= Dot_Pos + 1 + Scale then
         Extra_Digit :=
           Character'Pos (Amount_Text (Dot_Pos + 1 + Scale))
           - Character'Pos ('0');
      end if;

      Unit := Power_10 (Scale);
      Increment := (if Style.Cash then Cash_Increment (Style.Code) else 1);

      if Style.Cash and then Scale = 0 and then Increment > 1 then
         --  Zero-decimal cash currency: the cash increment applies to whole
         --  units, so round the integer amount to the nearest increment using
         --  the fractional part to decide the direction (round half up).
         Normalize_Integer
           (Source       => Amount_Text,
            Integer_From => Integer_From,
            Integer_To   => Integer_To,
            Add_One      => False,
            Target       => Integer_Text,
            Last         => Integer_Last);
         declare
            Value     : constant Long_Long_Integer :=
              Saturating_Integer_Value (Integer_Text, Integer_Last);
            Inc       : constant Long_Long_Integer :=
              Long_Long_Integer (Increment);
            Remainder : constant Long_Long_Integer := Value mod Inc;
            Denom     : Long_Long_Integer := 1;
            Frac_Num  : Long_Long_Integer := 0;
         begin
            if Dot_Pos /= 0 then
               for Index in Frac_From .. Frac_To loop
                  exit when Denom >= 1_000_000_000;
                  Denom := Denom * 10;
                  Frac_Num :=
                    Frac_Num * 10
                    + Long_Long_Integer
                        (Character'Pos (Amount_Text (Index))
                         - Character'Pos ('0'));
               end loop;
            end if;

            if (Remainder * Denom + Frac_Num) * 2 >= Inc * Denom then
               Set_Rounded (Value - Remainder + Inc);
            else
               Set_Rounded (Value - Remainder);
            end if;
         end;
         Frac_Value := 0;
      else
         if Style.Cash then
            if Extra_Digit >= 5 then
               Frac_Value := Frac_Value + 1;
            end if;

            if Increment > 1 then
               declare
                  Remainder : constant Natural := Frac_Value mod Increment;
               begin
                  if Remainder * 2 >= Increment then
                     Frac_Value := Frac_Value + Increment - Remainder;
                  else
                     Frac_Value := Frac_Value - Remainder;
                  end if;
               end;
            end if;
         end if;

         if Frac_Value >= Unit then
            Carry := True;
            Frac_Value := Frac_Value - Unit;
         end if;

         Normalize_Integer
           (Source       => Amount_Text,
            Integer_From => Integer_From,
            Integer_To   => Integer_To,
            Add_One      => Carry,
            Target       => Integer_Text,
            Last         => Integer_Last);
      end if;

      if Style.Display = Name_Display then
         Load_Display
           (I18N.Plurals.Cardinal
              (Locale          => Locale,
               Integer_Part    =>
                 Saturating_Integer_Value (Integer_Text, Integer_Last),
               Fraction_Digits => (if Frac_Value = 0 then 0 else Scale),
               Fraction_Value  => Long_Long_Integer (Frac_Value)));
      else
         Load_Display;
      end if;
      if Display_Last = 0 then
         return;
      end if;

      if Negative and then Style.Accounting then
         Put (Target, Last, Overflow, Accounting_Prefix (Locale));
      elsif Negative then
         Put (Target, Last, Overflow, Number_Minus_Sign (Locale));
      end if;

      if Symbol_First (Locale) and then Style.Display /= Name_Display then
         Put_Display (Add_Trailing_Space => True);
      end if;

      Put_Integer_With_Grouping
        (Target       => Target,
         Last         => Last,
         Overflow     => Overflow,
         Locale       => Locale,
         Amount_Text  => Integer_Text,
         Integer_From => 1,
         Integer_To   => Integer_Last);

      if Scale > 0 then
         Put (Target, Last, Overflow, Decimal_Sep);
         Put_Fraction (Target, Last, Overflow, Locale, Frac_Value, Scale);
      end if;

      if Style.Display = Name_Display then
         Put (Target, Last, Overflow, Amount_Separator (Locale));
         Put_Display (Add_Trailing_Space => False);
      elsif not Symbol_First (Locale) then
         Put (Target, Last, Overflow, Amount_Separator (Locale));
         Put_Display (Add_Trailing_Space => False);
      end if;

      if Negative and then Style.Accounting then
         Put (Target, Last, Overflow, Accounting_Suffix (Locale));
      end if;

      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Into;

end I18N.Currency;
