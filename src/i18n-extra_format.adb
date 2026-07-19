with I18N.CLDR_Data;
with I18N.Plurals;
with I18N.Runtime_Data;

package body I18N.Extra_Format is
   use type I18N.Plurals.Plural_Category;

   function Is_Digit (C : Character) return Boolean is (C in '0' .. '9');

   function Is_Integer_Text (Text : String) return Boolean is
      Start : Positive;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if not Is_Digit (Text (Index)) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Integer_Text;

   function Is_Decimal_Text (Text : String) return Boolean is
      Start    : Positive;
      Dot      : Natural := 0;
      Saw_Digit : Boolean := False;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
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
         elsif Is_Digit (Text (Index)) then
            Saw_Digit := True;
         else
            return False;
         end if;
      end loop;

      return Saw_Digit
        and then Dot /= Start
        and then Dot /= Text'Last;
   end Is_Decimal_Text;

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

   function Natural_Value (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Text loop
         Result := Result * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;
      return Result;
   end Natural_Value;

   function Long_Long_Natural_Value (Text : String) return Long_Long_Integer is
      Result : Long_Long_Integer := 0;
   begin
      for C of Text loop
         Result :=
           Result * 10
           + Long_Long_Integer (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Result;
   end Long_Long_Natural_Value;

   function Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      return Raw (Raw'First + 1 .. Raw'Last);
   end Integer_Image;

   function Signed_Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      if Raw (Raw'First) = ' ' then
         return Raw (Raw'First + 1 .. Raw'Last);
      else
         return Raw;
      end if;
   end Signed_Integer_Image;

   function Plural_Category_Name
     (Category : I18N.Plurals.Plural_Category)
      return String
   is
   begin
      return
        (case Category is
           when I18N.Plurals.Zero  => "zero",
           when I18N.Plurals.One   => "one",
           when I18N.Plurals.Two   => "two",
           when I18N.Plurals.Few   => "few",
           when I18N.Plurals.Many  => "many",
           when I18N.Plurals.Other => "other");
   end Plural_Category_Name;

   function Decimal_Operands
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer)
      return Boolean
   is
      Start       : Positive := Text'First;
      Dot         : Natural := 0;
      Saw_Digit   : Boolean := False;
      Integer_Acc : Long_Long_Integer := 0;
      Fraction_Acc : Long_Long_Integer := 0;
   begin
      Integer_Part := 0;
      Fraction_Digits := 0;
      Fraction_Value := 0;

      if Text'Length = 0 then
         return False;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
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
         elsif Is_Digit (Text (Index)) then
            Saw_Digit := True;
            if Dot = 0 then
               Integer_Acc :=
                 Integer_Acc * 10
                 + Long_Long_Integer
                   (Character'Pos (Text (Index)) - Character'Pos ('0'));
            else
               Fraction_Digits := Fraction_Digits + 1;
               Fraction_Acc :=
                 Fraction_Acc * 10
                 + Long_Long_Integer
                   (Character'Pos (Text (Index)) - Character'Pos ('0'));
            end if;
         else
            return False;
         end if;
      end loop;

      if not Saw_Digit
        or else Dot = Start
        or else Dot = Text'Last
      then
         return False;
      end if;

      Integer_Part := Integer_Acc;
      Fraction_Value := Fraction_Acc;
      return True;
   exception
      when Constraint_Error =>
         Integer_Part := 0;
         Fraction_Digits := 0;
         Fraction_Value := 0;
         return False;
   end Decimal_Operands;

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
         (if Found then Value else I18N.CLDR_Data.Digit_Text (Locale, Digit)));
   end Put_Digit;

   function Number_Minus_Sign (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "number_minus_sign", Found);
   begin
      return
        (if Found then Value else I18N.CLDR_Data.Number_Minus_Sign (Locale));
   end Number_Minus_Sign;

   procedure Put_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Natural;
      Width    : Natural := 1)
   is
      Raw : constant String := Integer_Image (Long_Long_Integer (Value));
   begin
      if Raw'Length < Width then
         for Pad in 1 .. Width - Raw'Length loop
            Put_Digit (Target, Last, Overflow, Locale, '0');
         end loop;
      end if;

      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Natural;

   procedure Put_Long_Long_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Long_Long_Integer)
   is
      Raw : constant String := Integer_Image (Value);
   begin
      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Long_Long_Natural;

   procedure Put_Decimal_Text
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : String)
   is
      Start        : Positive := Value'First;
      Integer_From : Positive;
      Integer_To   : Natural;
      Dot          : Natural := 0;
   begin
      if Value (Start) = '-' then
         Put (Target, Last, Overflow, Number_Minus_Sign (Locale));
         Start := Start + 1;
      elsif Value (Start) = '+' then
         Start := Start + 1;
      end if;

      Integer_From := Start;
      for Index in Start .. Value'Last loop
         if Value (Index) = '.' then
            Dot := Index;
            exit;
         end if;
      end loop;

      Integer_To := (if Dot = 0 then Value'Last else Dot - 1);
      while Integer_From < Integer_To
        and then Value (Integer_From) = '0'
      loop
         Integer_From := Integer_From + 1;
      end loop;

      for Index in Integer_From .. Integer_To loop
         Put_Digit (Target, Last, Overflow, Locale, Value (Index));
      end loop;

      if Dot /= 0 then
         declare
            Found : Boolean;
            Sep   : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, "decimal_separator", Found);
         begin
            Put
              (Target,
               Last,
               Overflow,
               (if Found then Sep else I18N.CLDR_Data.Decimal_Separator (Locale)));
         end;
         for Index in Dot + 1 .. Value'Last loop
            Put_Digit (Target, Last, Overflow, Locale, Value (Index));
         end loop;
      end if;
   end Put_Decimal_Text;

   function Option_Base (Option : String) return String is
      Slash : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash := Index;
            exit;
         end if;
      end loop;

      declare
         Raw : constant String :=
           (if Slash = 0 then Option else Option (Option'First .. Slash - 1));
      begin
         if Raw = "length-meter" or else Raw = "length-metre" then
            return "meter";
         elsif Raw = "metre" then
            return "meter";
         elsif Raw = "length-kilometer" or else Raw = "length-kilometre" then
            return "kilometer";
         elsif Raw = "kilometre" then
            return "kilometer";
         elsif Raw = "length-mile" then
            return "mile";
         elsif Raw = "length-yard" then
            return "yard";
         elsif Raw = "length-foot" then
            return "foot";
         elsif Raw = "length-inch" then
            return "inch";
         elsif Raw = "length-centimeter" or else Raw = "length-centimetre" then
            return "centimeter";
         elsif Raw = "centimetre" then
            return "centimeter";
         elsif Raw = "length-millimeter" or else Raw = "length-millimetre" then
            return "millimeter";
         elsif Raw = "millimetre" then
            return "millimeter";
         elsif Raw = "length-decimeter" or else Raw = "length-decimetre" then
            return "decimeter";
         elsif Raw = "decimetre" then
            return "decimeter";
         elsif Raw = "length-micrometer" or else Raw = "length-micrometre" then
            return "micrometer";
         elsif Raw = "micrometre" then
            return "micrometer";
         elsif Raw = "length-nanometer" or else Raw = "length-nanometre" then
            return "nanometer";
         elsif Raw = "nanometre" then
            return "nanometer";
         elsif Raw = "length-picometer" or else Raw = "length-picometre" then
            return "picometer";
         elsif Raw = "picometre" then
            return "picometer";
         elsif Raw = "length-nautical-mile" then
            return "nautical-mile";
         elsif Raw = "length-astronomical-unit" then
            return "astronomical-unit";
         elsif Raw = "length-light-year" then
            return "light-year";
         elsif Raw = "length-parsec" then
            return "parsec";
         elsif Raw = "length-fathom" then
            return "fathom";
         elsif Raw = "length-furlong" then
            return "furlong";
         elsif Raw = "length-pixel" then
            return "pixel";
         elsif Raw = "length-point" then
            return "point";
         elsif Raw = "length-solar-radius" then
            return "solar-radius";
         elsif Raw = "length-earth-radius" then
            return "earth-radius";
         elsif Raw = "graphics-dot" then
            return "dot";
         elsif Raw = "graphics-megapixel" then
            return "megapixel";
         elsif Raw = "graphics-pixel-per-centimeter"
           or else Raw = "graphics-pixel-per-centimetre"
         then
            return "pixel-per-centimeter";
         elsif Raw = "pixel-per-centimetre" then
            return "pixel-per-centimeter";
         elsif Raw = "graphics-pixel-per-inch" then
            return "pixel-per-inch";
         elsif Raw = "graphics-dot-per-centimeter"
           or else Raw = "graphics-dot-per-centimetre"
         then
            return "dot-per-centimeter";
         elsif Raw = "dot-per-centimetre" then
            return "dot-per-centimeter";
         elsif Raw = "graphics-dot-per-inch" then
            return "dot-per-inch";
         elsif Raw = "volume-liter" or else Raw = "volume-litre" then
            return "liter";
         elsif Raw = "litre" then
            return "liter";
         elsif Raw = "volume-milliliter" or else Raw = "volume-millilitre" then
            return "milliliter";
         elsif Raw = "millilitre" then
            return "milliliter";
         elsif Raw = "volume-gallon" then
            return "gallon";
         elsif Raw = "volume-fluid-ounce" then
            return "fluid-ounce";
         elsif Raw = "volume-cup" then
            return "cup";
         elsif Raw = "volume-tablespoon" then
            return "tablespoon";
         elsif Raw = "volume-teaspoon" then
            return "teaspoon";
         elsif Raw = "volume-pint" then
            return "pint";
         elsif Raw = "volume-quart" then
            return "quart";
         elsif Raw = "volume-barrel" then
            return "barrel";
         elsif Raw = "volume-cubic-meter"
           or else Raw = "volume-cubic-metre"
         then
            return "cubic-meter";
         elsif Raw = "cubic-metre" then
            return "cubic-meter";
         elsif Raw = "volume-cubic-centimeter"
           or else Raw = "volume-cubic-centimetre"
         then
            return "cubic-centimeter";
         elsif Raw = "cubic-centimetre" then
            return "cubic-centimeter";
         elsif Raw = "volume-cubic-inch" then
            return "cubic-inch";
         elsif Raw = "volume-cubic-foot" then
            return "cubic-foot";
         elsif Raw = "volume-cubic-yard" then
            return "cubic-yard";
         elsif Raw = "volume-acre-foot" then
            return "acre-foot";
         elsif Raw = "mass-gram" then
            return "gram";
         elsif Raw = "mass-kilogram" then
            return "kilogram";
         elsif Raw = "mass-milligram" then
            return "milligram";
         elsif Raw = "mass-tonne" then
            return "tonne";
         elsif Raw = "mass-pound" then
            return "pound";
         elsif Raw = "mass-ounce" then
            return "ounce";
         elsif Raw = "mass-stone" then
            return "stone";
         elsif Raw = "mass-carat" then
            return "carat";
         elsif Raw = "mass-ton" then
            return "ton";
         elsif Raw = "mass-dalton" then
            return "dalton";
         elsif Raw = "mass-earth-mass" then
            return "earth-mass";
         elsif Raw = "mass-solar-mass" then
            return "solar-mass";
         elsif Raw = "duration-nanosecond" then
            return "nanosecond";
         elsif Raw = "duration-microsecond" then
            return "microsecond";
         elsif Raw = "duration-millisecond" then
            return "millisecond";
         elsif Raw = "duration-second" then
            return "second";
         elsif Raw = "duration-minute" then
            return "minute";
         elsif Raw = "duration-hour" then
            return "hour";
         elsif Raw = "duration-day" then
            return "day";
         elsif Raw = "duration-week" then
            return "week";
         elsif Raw = "duration-month" then
            return "month";
         elsif Raw = "duration-year" then
            return "year";
         elsif Raw = "duration-quarter" then
            return "quarter";
         elsif Raw = "duration-decade" then
            return "decade";
         elsif Raw = "duration-century" then
            return "century";
         elsif Raw = "duration-fortnight" then
            return "fortnight";
         elsif Raw = "area-square-meter" or else Raw = "area-square-metre" then
            return "square-meter";
         elsif Raw = "square-metre" then
            return "square-meter";
         elsif Raw = "area-square-kilometer"
           or else Raw = "area-square-kilometre"
         then
            return "square-kilometer";
         elsif Raw = "square-kilometre" then
            return "square-kilometer";
         elsif Raw = "area-acre" then
            return "acre";
         elsif Raw = "area-hectare" then
            return "hectare";
         elsif Raw = "area-square-foot" then
            return "square-foot";
         elsif Raw = "area-square-mile" then
            return "square-mile";
         elsif Raw = "area-square-centimeter"
           or else Raw = "area-square-centimetre"
         then
            return "square-centimeter";
         elsif Raw = "square-centimetre" then
            return "square-centimeter";
         elsif Raw = "area-square-inch" then
            return "square-inch";
         elsif Raw = "area-square-yard" then
            return "square-yard";
         elsif Raw = "temperature-celsius" then
            return "celsius";
         elsif Raw = "temperature-fahrenheit" then
            return "fahrenheit";
         elsif Raw = "temperature-kelvin" then
            return "kelvin";
         elsif Raw = "angle-degree" then
            return "degree";
         elsif Raw = "angle-radian" then
            return "radian";
         elsif Raw = "angle-revolution" then
            return "revolution";
         elsif Raw = "angle-arc-minute" then
            return "arc-minute";
         elsif Raw = "angle-arc-second" then
            return "arc-second";
         elsif Raw = "acceleration-g-force" then
            return "g-force";
         elsif Raw = "acceleration-meter-per-square-second"
           or else Raw = "acceleration-metre-per-square-second"
         then
            return "meter-per-square-second";
         elsif Raw = "metre-per-square-second" then
            return "meter-per-square-second";
         elsif Raw = "force-newton" then
            return "newton";
         elsif Raw = "force-pound-force" then
            return "pound-force";
         elsif Raw = "torque-newton-meter"
           or else Raw = "torque-newton-metre"
         then
            return "newton-meter";
         elsif Raw = "newton-metre" then
            return "newton-meter";
         elsif Raw = "digital-byte" then
            return "byte";
         elsif Raw = "digital-bit" then
            return "bit";
         elsif Raw = "digital-kilobyte" then
            return "kilobyte";
         elsif Raw = "digital-kilobit" then
            return "kilobit";
         elsif Raw = "digital-megabyte" then
            return "megabyte";
         elsif Raw = "digital-gigabyte" then
            return "gigabyte";
         elsif Raw = "digital-terabyte" then
            return "terabyte";
         elsif Raw = "digital-terabit" then
            return "terabit";
         elsif Raw = "digital-megabit" then
            return "megabit";
         elsif Raw = "digital-gigabit" then
            return "gigabit";
         elsif Raw = "digital-petabyte" then
            return "petabyte";
         elsif Raw = "digital-petabit" then
            return "petabit";
         elsif Raw = "digital-exabyte" then
            return "exabyte";
         elsif Raw = "digital-exabit" then
            return "exabit";
         elsif Raw = "speed-kilometer-per-hour"
           or else Raw = "speed-kilometre-per-hour"
         then
            return "kilometer-per-hour";
         elsif Raw = "kilometre-per-hour" then
            return "kilometer-per-hour";
         elsif Raw = "speed-mile-per-hour" then
            return "mile-per-hour";
         elsif Raw = "speed-knot" then
            return "knot";
         elsif Raw = "speed-beaufort" then
            return "beaufort";
         elsif Raw = "speed-meter-per-second"
           or else Raw = "speed-metre-per-second"
         then
            return "meter-per-second";
         elsif Raw = "metre-per-second" then
            return "meter-per-second";
         elsif Raw = "consumption-liter-per-100-kilometer"
           or else Raw = "consumption-litre-per-100-kilometre"
           or else Raw = "consumption-litre-per-100-kilometer"
           or else Raw = "consumption-liter-per-100-kilometre"
         then
            return "liter-per-100-kilometer";
         elsif Raw = "litre-per-100-kilometre"
           or else Raw = "litre-per-100-kilometer"
           or else Raw = "liter-per-100-kilometre"
         then
            return "liter-per-100-kilometer";
         elsif Raw = "consumption-mile-per-gallon" then
            return "mile-per-gallon";
         elsif Raw = "consumption-mile-per-gallon-imperial" then
            return "mile-per-gallon-imperial";
         elsif Raw = "energy-joule" then
            return "joule";
         elsif Raw = "energy-kilojoule" then
            return "kilojoule";
         elsif Raw = "energy-calorie" then
            return "calorie";
         elsif Raw = "energy-kilocalorie" then
            return "kilocalorie";
         elsif Raw = "energy-kilowatt-hour" then
            return "kilowatt-hour";
         elsif Raw = "energy-electronvolt" then
            return "electronvolt";
         elsif Raw = "energy-british-thermal-unit" then
            return "british-thermal-unit";
         elsif Raw = "energy-therm-us" then
            return "therm-us";
         elsif Raw = "power-watt" then
            return "watt";
         elsif Raw = "power-kilowatt" then
            return "kilowatt";
         elsif Raw = "power-horsepower" then
            return "horsepower";
         elsif Raw = "frequency-hertz" then
            return "hertz";
         elsif Raw = "frequency-kilohertz" then
            return "kilohertz";
         elsif Raw = "frequency-megahertz" then
            return "megahertz";
         elsif Raw = "pressure-hectopascal" then
            return "hectopascal";
         elsif Raw = "pressure-pascal" then
            return "pascal";
         elsif Raw = "pressure-kilopascal" then
            return "kilopascal";
         elsif Raw = "pressure-millibar" then
            return "millibar";
         elsif Raw = "pressure-bar" then
            return "bar";
         elsif Raw = "pressure-atmosphere" then
            return "atmosphere";
         elsif Raw = "pressure-inch-ofhg" then
            return "inch-ofhg";
         elsif Raw = "pressure-millimeter-ofhg" then
            return "millimeter-ofhg";
         elsif Raw = "pressure-pound-force-per-square-inch" then
            return "pound-force-per-square-inch";
         elsif Raw = "electric-ampere" then
            return "ampere";
         elsif Raw = "electric-milliampere" then
            return "milliampere";
         elsif Raw = "electric-volt" then
            return "volt";
         elsif Raw = "electric-millivolt" then
            return "millivolt";
         elsif Raw = "electric-ohm" then
            return "ohm";
         elsif Raw = "light-lumen" then
            return "lumen";
         elsif Raw = "light-lux" then
            return "lux";
         elsif Raw = "light-candela" then
            return "candela";
         elsif Raw = "light-solar-luminosity" then
            return "solar-luminosity";
         elsif Raw = "concentr-percent" then
            return "percent";
         elsif Raw = "concentr-permille" then
            return "permille";
         elsif Raw = "concentr-permillion" then
            return "permillion";
         elsif Raw = "concentr-portion" then
            return "portion";
         elsif Raw = "concentr-karat" then
            return "karat";
         else
            return Raw;
         end if;
      end;
   end Option_Base;

   function Option_Second_Slash (Option : String) return Natural is
      Seen_First : Boolean := False;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            if Seen_First then
               return Index;
            end if;

            Seen_First := True;
         end if;
      end loop;

      return 0;
   end Option_Second_Slash;

   function Option_Third_Slash (Option : String) return Natural is
      Slash_Count : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash_Count := Slash_Count + 1;
            if Slash_Count = 3 then
               return Index;
            end if;
         end if;
      end loop;

      return 0;
   end Option_Third_Slash;

   function Option_Width (Option : String) return String is
      Slash        : Natural := 0;
      Second_Slash : constant Natural := Option_Second_Slash (Option);
      Third_Slash  : constant Natural := Option_Third_Slash (Option);
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            Slash := Index;
            exit;
         end if;
      end loop;

      return
        (if Slash = 0 then "unit-width-full-name"
         elsif Second_Slash = 0 then Option (Slash + 1 .. Option'Last)
         elsif Option (Slash + 1 .. Second_Slash - 1) = "unit-width"
           and then Third_Slash = 0
         then "unit-width-" & Option (Second_Slash + 1 .. Option'Last)
         elsif Option (Slash + 1 .. Second_Slash - 1) = "unit-width"
         then "unit-width-" & Option (Second_Slash + 1 .. Third_Slash - 1)
         else Option (Slash + 1 .. Second_Slash - 1));
   end Option_Width;

   function Option_Per_Unit (Option : String) return String is
      Second_Slash : constant Natural := Option_Second_Slash (Option);
      Third_Slash  : constant Natural := Option_Third_Slash (Option);
      First_Slash  : Natural := 0;
   begin
      for Index in Option'Range loop
         if Option (Index) = '/' then
            First_Slash := Index;
            exit;
         end if;
      end loop;

      return
        (if Second_Slash = 0 then ""
         elsif First_Slash /= 0
           and then Option (First_Slash + 1 .. Second_Slash - 1)
             = "unit-width"
           and then Third_Slash = 0
         then ""
         elsif First_Slash /= 0
           and then Option (First_Slash + 1 .. Second_Slash - 1)
             = "unit-width"
         then Option (Third_Slash + 1 .. Option'Last)
         else Option (Second_Slash + 1 .. Option'Last));
   end Option_Per_Unit;

   function Unit_Name
     (Unit     : String;
      Singular : Boolean)
      return String
   is
      Base   : constant String := Option_Base (Unit);
      Width  : constant String := Option_Width (Unit);

      function Fallback_Name return String is
         Short : constant Boolean :=
           Width = "unit-width-short"
           or else Width = "short"
           or else Width = "unit-width-narrow"
           or else Width = "narrow";
      begin
         if Short then
            if Base = "quarter" then
               return "qtr";
            elsif Base = "decade" then
               return "dec";
            elsif Base = "century" then
               return "c";
            elsif Base = "fortnight" then
               return "fortnight";
            elsif Base = "decimeter" then
               return "dm";
            elsif Base = "micrometer" then
               return "um";
            elsif Base = "nanometer" then
               return "nm";
            elsif Base = "picometer" then
               return "pm";
            elsif Base = "radian" then
               return "rad";
            elsif Base = "revolution" then
               return "rev";
            elsif Base = "arc-minute" then
               return "arcmin";
            elsif Base = "arc-second" then
               return "arcsec";
            elsif Base = "g-force" then
               return "G";
            elsif Base = "meter-per-square-second" then
               return "m/s2";
            elsif Base = "newton" then
               return "N";
            elsif Base = "pound-force" then
               return "lbf";
            elsif Base = "newton-meter" then
               return "N*m";
            elsif Base = "liter-per-100-kilometer" then
               return "L/100km";
            elsif Base = "mile-per-gallon" then
               return "mpg";
            elsif Base = "mile-per-gallon-imperial" then
               return "mpg Imp";
            elsif Base = "electronvolt" then
               return "eV";
            elsif Base = "british-thermal-unit" then
               return "Btu";
            elsif Base = "therm-us" then
               return "US therm";
            elsif Base = "permille" then
               return "permille";
            elsif Base = "permillion" then
               return "ppm";
            elsif Base = "portion" then
               return "pt";
            elsif Base = "karat" then
               return "kt";
            elsif Base = "dot" then
               return "dot";
            elsif Base = "megapixel" then
               return "MP";
            elsif Base = "pixel-per-centimeter" then
               return "px/cm";
            elsif Base = "pixel-per-inch" then
               return "ppi";
            elsif Base = "dot-per-centimeter" then
               return "dpcm";
            elsif Base = "dot-per-inch" then
               return "dpi";
            elsif Base = "earth-radius" then
               return "R_E";
            elsif Base = "barrel" then
               return "bbl";
            elsif Base = "ton" then
               return "tn";
            elsif Base = "dalton" then
               return "Da";
            elsif Base = "earth-mass" then
               return "M_E";
            elsif Base = "solar-mass" then
               return "M_sun";
            elsif Base = "kelvin" then
               return "K";
            elsif Base = "horsepower" then
               return "hp";
            elsif Base = "kilobit" then
               return "kb";
            elsif Base = "terabit" then
               return "Tb";
            elsif Base = "petabit" then
               return "Pb";
            elsif Base = "exabyte" then
               return "EB";
            elsif Base = "exabit" then
               return "Eb";
            elsif Base = "knot" then
               return "kn";
            elsif Base = "beaufort" then
               return "Bft";
            elsif Base = "pound-force-per-square-inch" then
               return "psi";
            elsif Base = "milliampere" then
               return "mA";
            elsif Base = "millivolt" then
               return "mV";
            elsif Base = "candela" then
               return "cd";
            elsif Base = "solar-luminosity" then
               return "L_sun";
            elsif Base = "square-centimeter" then
               return "cm2";
            elsif Base = "square-inch" then
               return "in2";
            elsif Base = "square-yard" then
               return "yd2";
            elsif Base = "cubic-meter" then
               return "m3";
            elsif Base = "cubic-centimeter" then
               return "cm3";
            elsif Base = "cubic-inch" then
               return "in3";
            elsif Base = "cubic-foot" then
               return "ft3";
            elsif Base = "cubic-yard" then
               return "yd3";
            elsif Base = "acre-foot" then
               return "ac ft";
            else
               return "";
            end if;
         elsif Base = "quarter" then
            return (if Singular then "quarter" else "quarters");
         elsif Base = "decade" then
            return (if Singular then "decade" else "decades");
         elsif Base = "century" then
            return (if Singular then "century" else "centuries");
         elsif Base = "fortnight" then
            return (if Singular then "fortnight" else "fortnights");
         elsif Base = "decimeter" then
            return (if Singular then "decimeter" else "decimeters");
         elsif Base = "micrometer" then
            return (if Singular then "micrometer" else "micrometers");
         elsif Base = "nanometer" then
            return (if Singular then "nanometer" else "nanometers");
         elsif Base = "picometer" then
            return (if Singular then "picometer" else "picometers");
         elsif Base = "radian" then
            return (if Singular then "radian" else "radians");
         elsif Base = "revolution" then
            return (if Singular then "revolution" else "revolutions");
         elsif Base = "arc-minute" then
            return (if Singular then "arc minute" else "arc minutes");
         elsif Base = "arc-second" then
            return (if Singular then "arc second" else "arc seconds");
         elsif Base = "g-force" then
            return (if Singular then "g-force" else "g-forces");
         elsif Base = "meter-per-square-second" then
            return
              (if Singular
               then "meter per square second"
               else "meters per square second");
         elsif Base = "newton" then
            return (if Singular then "newton" else "newtons");
         elsif Base = "pound-force" then
            return (if Singular then "pound-force" else "pound-force");
         elsif Base = "newton-meter" then
            return (if Singular then "newton meter" else "newton meters");
         elsif Base = "liter-per-100-kilometer" then
            return "liters per 100 kilometers";
         elsif Base = "mile-per-gallon" then
            return "miles per gallon";
         elsif Base = "mile-per-gallon-imperial" then
            return "miles per imperial gallon";
         elsif Base = "electronvolt" then
            return (if Singular then "electronvolt" else "electronvolts");
         elsif Base = "british-thermal-unit" then
            return
              (if Singular
               then "British thermal unit"
               else "British thermal units");
         elsif Base = "therm-us" then
            return (if Singular then "US therm" else "US therms");
         elsif Base = "permille" then
            return "permille";
         elsif Base = "permillion" then
            return "parts per million";
         elsif Base = "portion" then
            return (if Singular then "portion" else "portions");
         elsif Base = "karat" then
            return (if Singular then "karat" else "karats");
         elsif Base = "dot" then
            return (if Singular then "dot" else "dots");
         elsif Base = "megapixel" then
            return (if Singular then "megapixel" else "megapixels");
         elsif Base = "pixel-per-centimeter" then
            return "pixels per centimeter";
         elsif Base = "pixel-per-inch" then
            return "pixels per inch";
         elsif Base = "dot-per-centimeter" then
            return "dots per centimeter";
         elsif Base = "dot-per-inch" then
            return "dots per inch";
         elsif Base = "earth-radius" then
            return (if Singular then "Earth radius" else "Earth radii");
         elsif Base = "barrel" then
            return (if Singular then "barrel" else "barrels");
         elsif Base = "ton" then
            return (if Singular then "ton" else "tons");
         elsif Base = "dalton" then
            return (if Singular then "dalton" else "daltons");
         elsif Base = "earth-mass" then
            return (if Singular then "Earth mass" else "Earth masses");
         elsif Base = "solar-mass" then
            return (if Singular then "solar mass" else "solar masses");
         elsif Base = "kelvin" then
            return "kelvin";
         elsif Base = "horsepower" then
            return "horsepower";
         elsif Base = "kilobit" then
            return (if Singular then "kilobit" else "kilobits");
         elsif Base = "terabit" then
            return (if Singular then "terabit" else "terabits");
         elsif Base = "petabit" then
            return (if Singular then "petabit" else "petabits");
         elsif Base = "exabyte" then
            return (if Singular then "exabyte" else "exabytes");
         elsif Base = "exabit" then
            return (if Singular then "exabit" else "exabits");
         elsif Base = "knot" then
            return (if Singular then "knot" else "knots");
         elsif Base = "beaufort" then
            return "Beaufort";
         elsif Base = "pound-force-per-square-inch" then
            return "pounds per square inch";
         elsif Base = "milliampere" then
            return (if Singular then "milliampere" else "milliamperes");
         elsif Base = "millivolt" then
            return (if Singular then "millivolt" else "millivolts");
         elsif Base = "candela" then
            return (if Singular then "candela" else "candelas");
         elsif Base = "solar-luminosity" then
            return
              (if Singular then "solar luminosity" else "solar luminosities");
         elsif Base = "square-centimeter" then
            return
              (if Singular
               then "square centimeter"
               else "square centimeters");
         elsif Base = "square-inch" then
            return (if Singular then "square inch" else "square inches");
         elsif Base = "square-yard" then
            return (if Singular then "square yard" else "square yards");
         elsif Base = "cubic-meter" then
            return (if Singular then "cubic meter" else "cubic meters");
         elsif Base = "cubic-centimeter" then
            return
              (if Singular
               then "cubic centimeter"
               else "cubic centimeters");
         elsif Base = "cubic-inch" then
            return (if Singular then "cubic inch" else "cubic inches");
         elsif Base = "cubic-foot" then
            return (if Singular then "cubic foot" else "cubic feet");
         elsif Base = "cubic-yard" then
            return (if Singular then "cubic yard" else "cubic yards");
         elsif Base = "acre-foot" then
            return (if Singular then "acre-foot" else "acre-feet");
         else
            return "";
         end if;
      end Fallback_Name;

      Generated : constant String :=
        I18N.CLDR_Data.Unit_Display_Name
          ("en", Base, Width, (if Singular then "one" else "other"));
   begin
      if Width /= "unit-width-full-name"
        and then Width /= "full-name"
        and then Width /= "unit-width-long"
        and then Width /= "long"
        and then Width /= "unit-width-short"
        and then Width /= "short"
        and then Width /= "unit-width-narrow"
        and then Width /= "narrow"
      then
         return "";
      end if;

      return (if Generated /= "" then Generated else Fallback_Name);
   end Unit_Name;

   function Locale_Unit_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Singular : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "unit." & Base & "." & Width & "."
           & (if Singular then "one" else "other"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Display_Name
           (Locale, Base, Width, (if Singular then "one" else "other")));
   end Locale_Unit_Name;

   function Locale_Unit_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : I18N.Plurals.Plural_Category)
      return String
   is
      Prefix : constant String := "unit." & Base & "." & Width & ".";

      function Runtime_Name
        (Suffix : String;
         Found  : out Boolean)
         return String
      is
      begin
         return I18N.Runtime_Data.Locale_Text (Locale, Prefix & Suffix, Found);
      end Runtime_Name;

      Found : Boolean;
      Value : constant String :=
        Runtime_Name (Plural_Category_Name (Category), Found);
   begin
      --  A runtime-provided unit name is selected by plural category, with the
      --  CLDR category fallback (category -> other -> one) so that a value
      --  whose category (for example "two" under Arabic-style rules) has no
      --  explicit row still resolves through the catalog before the built-in
      --  data is consulted.
      if Found then
         return Value;
      end if;

      if Category /= I18N.Plurals.Other then
         declare
            Other_Value : constant String := Runtime_Name ("other", Found);
         begin
            if Found then
               return Other_Value;
            end if;
         end;
      end if;

      if Category /= I18N.Plurals.One then
         declare
            One_Value : constant String := Runtime_Name ("one", Found);
         begin
            if Found then
               return One_Value;
            end if;
         end;
      end if;

      return I18N.CLDR_Data.Unit_Display_Name
        (Locale, Base, Width, Plural_Category_Name (Category));
   end Locale_Unit_Name;

   function Unit_Category_For_Value
     (Locale : String;
      Value  : String)
      return I18N.Plurals.Plural_Category
   is
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : Natural;
      Fraction_Value  : Long_Long_Integer;
   begin
      if Decimal_Operands
        (Value, Integer_Part, Fraction_Digits, Fraction_Value)
      then
         return I18N.Plurals.Cardinal
           (Locale, Integer_Part, Fraction_Digits, Fraction_Value);
      else
         return I18N.Plurals.Other;
      end if;
   end Unit_Category_For_Value;

   function Runtime_Unit_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : I18N.Plurals.Plural_Category;
      Found    : out Boolean)
      return String
   is
      Field : constant String :=
        "unit_pattern." & Base & "." & Width & "."
        & Plural_Category_Name (Category);
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Field, Found);
   begin
      if Found then
         return Value;
      elsif Category /= I18N.Plurals.Other then
         declare
            Other_Value : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 "unit_pattern." & Base & "." & Width & ".other",
                 Found);
         begin
            return Other_Value;
         end;
      else
         return "";
      end if;
   end Runtime_Unit_Pattern;

   function Unit_Option_Is_Valid (Option : String) return Boolean is
      Per_Unit : constant String := Option_Per_Unit (Option);
      Width    : constant String := Option_Width (Option);
   begin
      return Unit_Name (Option, True) /= ""
        and then
          (Per_Unit = ""
           or else Unit_Name (Per_Unit & "/" & Width, True) /= "");
   end Unit_Option_Is_Valid;

   function Relative_Option_Is_Valid (Option : String) return Boolean is
      Base : constant String := Option_Base (Option);
      Width : constant String := Option_Width (Option);
   begin
      return Option_Per_Unit (Option) = ""
        and then
          (Width = "unit-width-full-name"
           or else Width = "full-name"
           or else Width = "unit-width-long"
           or else Width = "long"
           or else Width = "unit-width-short"
           or else Width = "short"
           or else Width = "unit-width-narrow"
           or else Width = "narrow")
        and then
          (Base = "second"
           or else Base = "minute"
           or else Base = "hour"
           or else Base = "day"
           or else Base = "week"
           or else Base = "month"
           or else Base = "quarter"
           or else Base = "year");
   end Relative_Option_Is_Valid;

   function Relative_Width_Key (Option : String) return String is
      Width : constant String := Option_Width (Option);
   begin
      if Width = "unit-width-short" or else Width = "short" then
         return "unit-width-short";
      elsif Width = "unit-width-narrow" or else Width = "narrow" then
         return "unit-width-narrow";
      else
         return "unit-width-full-name";
      end if;
   end Relative_Width_Key;

   function Localized_Unit_Name
     (Locale   : String;
      Unit     : String;
      Singular : Boolean)
      return String
   is
      Base   : constant String := Option_Base (Unit);
      Width  : constant String := Option_Width (Unit);
      Localized : constant String :=
        Locale_Unit_Name (Locale, Base, Width, Singular);
   begin
      if Localized /= "" then
         return Localized;
      end if;

      return Unit_Name (Unit, Singular);
   end Localized_Unit_Name;

   function Localized_Unit_Name
     (Locale   : String;
      Unit     : String;
      Category : I18N.Plurals.Plural_Category)
      return String
   is
      Base  : constant String := Option_Base (Unit);
      Width : constant String := Option_Width (Unit);
      Localized : constant String :=
        Locale_Unit_Name (Locale, Base, Width, Category);
   begin
      if Localized /= "" then
         return Localized;
      end if;

      return Unit_Name (Unit, Category = I18N.Plurals.One);
   end Localized_Unit_Name;

   function Localized_Unit_Name_For_Value
     (Locale : String;
      Unit   : String;
      Value  : String)
      return String
   is
   begin
      return Localized_Unit_Name
        (Locale, Unit, Unit_Category_For_Value (Locale, Value));
   end Localized_Unit_Name_For_Value;

   procedure Put_Runtime_Unit_Pattern
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Pattern  : String;
      Value    : String)
   is
      Arg : Natural := 0;
      Number_Buffer : String (1 .. 128);
      Number_Last   : Natural := 0;
      Number_Overflow : Boolean := False;
   begin
      for Index in Pattern'Range loop
         if Index <= Pattern'Last - 2
           and then Pattern (Index .. Index + 2) = "{0}"
         then
            Arg := Index;
            exit;
         end if;
      end loop;

      if Arg = 0 then
         Overflow := True;
         return;
      end if;

      Put_Decimal_Text
        (Number_Buffer, Number_Last, Number_Overflow, Locale, Value);
      if Number_Overflow then
         Overflow := True;
         return;
      end if;

      if Arg > Pattern'First then
         Put (Target, Last, Overflow, Pattern (Pattern'First .. Arg - 1));
      end if;
      Put (Target, Last, Overflow, Number_Buffer (1 .. Number_Last));
      if Arg + 2 < Pattern'Last then
         Put (Target, Last, Overflow, Pattern (Arg + 3 .. Pattern'Last));
      end if;
   end Put_Runtime_Unit_Pattern;

   function Relative_Current (Locale : String; Option : String) return String is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Width = "unit-width-full-name"
            then "relative_current." & Base
            else "relative_current." & Base & "." & Width),
           Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Current_Name (Locale, Base, Width));
   end Relative_Current;

   function Relative_Exact
     (Locale : String;
      Option : String;
      Offset : Long_Long_Integer;
      Found  : out Boolean)
      return String
   is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
   begin
      return I18N.Runtime_Data.Locale_Text
        (Locale,
         "relative_exact." & Base & "." & Width & "."
         & Signed_Integer_Image (Offset),
         Found);
   end Relative_Exact;

   function Relative_Unit_Name
     (Locale   : String;
      Base     : String;
      Singular : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_unit." & Base & "."
           & (if Singular then "one" else "other"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Unit_Display_Name
           (Locale, Base, Singular));
   end Relative_Unit_Name;

   function Relative_Unit_Name
     (Locale : String;
      Base   : String;
      Amount : Natural)
      return String
   is
      Category : constant I18N.Plurals.Plural_Category :=
        I18N.Plurals.Cardinal (Locale, Long_Long_Integer (Amount));
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
        I18N.Runtime_Data.Locale_Text
          (Locale, "relative_unit." & Base & "." & Category_Name, Found);
      Generated : constant String :=
        I18N.CLDR_Data.Relative_Unit_Category_Name
          (Locale, Base, Category_Name);
   begin
      if Found then
         return Value;
      end if;

      if Generated /= "" then
         return Generated;
      end if;

      if Category /= I18N.Plurals.Other then
         declare
            Other : constant String :=
              I18N.CLDR_Data.Relative_Unit_Category_Name
                (Locale, Base, "other");
         begin
            if Other /= "" then
               return Other;
            end if;
         end;
      end if;

      return Relative_Unit_Name
        (Locale, Base, Category = I18N.Plurals.One);
   end Relative_Unit_Name;

   function Relative_Offset_Prefix
     (Locale : String;
      Future : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_prefix." & (if Future then "future" else "past"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Offset_Prefix (Locale, Future));
   end Relative_Offset_Prefix;

   function Relative_Offset_Suffix
     (Locale : String;
      Future : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           "relative_suffix." & (if Future then "future" else "past"),
           Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Relative_Offset_Suffix (Locale, Future));
   end Relative_Offset_Suffix;

   function Runtime_Relative_Override_Present
     (Locale   : String;
      Base     : String;
      Category : String;
      Future   : Boolean)
      return Boolean
   is
      Found : Boolean;
   begin
      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale,
              "relative_prefix." & (if Future then "future" else "past"),
              Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale,
              "relative_suffix." & (if Future then "future" else "past"),
              Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "relative_unit." & Base & "." & Category, Found);
      begin
         if Found or else Ignored'Length > 0 then
            return True;
         end if;
      end;

      declare
         Ignored : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "relative_unit." & Base & ".other", Found);
      begin
         return Found or else Ignored'Length > 0;
      end;
   end Runtime_Relative_Override_Present;

   function Runtime_Relative_Time_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Future   : Boolean;
      Found    : out Boolean)
      return String
   is
      Direction : constant String := (if Future then "future" else "past");
      Field : constant String :=
        "relative_time_pattern." & Base & "." & Width & "."
        & Direction & "." & Category;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Field, Found);
   begin
      if Found then
         return Value;
      elsif Category /= "other" then
         declare
            Other_Value : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 "relative_time_pattern." & Base & "." & Width & "."
                 & Direction & ".other",
                 Found);
         begin
            return Other_Value;
         end;
      else
         return "";
      end if;
   end Runtime_Relative_Time_Pattern;

   procedure Put_Relative_Time_Pattern
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Pattern  : String;
      Amount   : String)
   is
      Index : Natural := Pattern'First;
   begin
      while Index <= Pattern'Last loop
         if Index + 2 <= Pattern'Last
           and then Pattern (Index .. Index + 2) = "{0}"
         then
            Put (Target, Last, Overflow, Amount);
            Index := Index + 3;
         else
            Put (Target, Last, Overflow, Pattern (Index .. Index));
            Index := Index + 1;
         end if;
      end loop;
   end Put_Relative_Time_Pattern;

   function Unit_Value_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "unit_value_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Value_Separator (Locale));
   end Unit_Value_Separator;

   function Per_Unit_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "per_unit_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Per_Unit_Separator (Locale));
   end Per_Unit_Separator;

   function Unit_Short_Per_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "unit_short_per_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Short_Per_Separator (Locale));
   end Unit_Short_Per_Separator;

   --  Does this text carry the value's placeholder -- that is, is it a pattern
   --  rather than a plain name?
   function Has_Placeholder (Text : String) return Boolean is
   begin
      for Index in Text'Range loop
         if Index <= Text'Last - 2
           and then Text (Index .. Index + 2) = "{0}"
         then
            return True;
         end if;
      end loop;

      return False;
   end Has_Placeholder;

   --  Did the caller supply this locale's per pattern at runtime? Such a row is
   --  an explicit instruction to compose the rate from its parts, so it outranks
   --  a compound name that only the generated data knows about.
   function Has_Runtime_Per_Separator (Locale : String) return Boolean is
      Found : Boolean;
      Long_Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "per_unit_separator", Found);
      Long_Found : constant Boolean := Found;
      Short_Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "unit_short_per_separator", Found);
   begin
      pragma Unreferenced (Long_Value, Short_Value);
      return Long_Found or else Found;
   end Has_Runtime_Per_Separator;

   function List_Final_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_final_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.List_Final_Separator (Locale));
   end List_Final_Separator;

   function List_Pair_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_pair_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Final_Found : Boolean;
         Final_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_final_separator", Final_Found);
      begin
         if Final_Found then
            return Final_Value;
         end if;
      end;

      return I18N.CLDR_Data.List_Pair_Separator (Locale);
   end List_Pair_Separator;

   function List_Start_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_start_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Item_Found : Boolean;
         Item_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_item_separator", Item_Found);
      begin
         if Item_Found then
            return Item_Value;
         end if;
      end;

      return I18N.CLDR_Data.List_Start_Separator (Locale);
   end List_Start_Separator;

   function List_Middle_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "list_middle_separator", Found);
   begin
      if Found then
         return Value;
      end if;

      declare
         Item_Found : Boolean;
         Item_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "list_item_separator", Item_Found);
      begin
         if Item_Found then
            return Item_Value;
         end if;
      end;

      return I18N.CLDR_Data.List_Middle_Separator (Locale);
   end List_Middle_Separator;

   function Runtime_List_Separator
     (Locale : String;
      Family : String;
      Part   : String;
      Found  : out Boolean)
      return String
   is
   begin
      if Family = "standard" then
         return I18N.Runtime_Data.Locale_Text
           (Locale, "list_" & Part & "_separator", Found);
      else
         return I18N.Runtime_Data.Locale_Text
           (Locale, "list_" & Family & "_" & Part & "_separator", Found);
      end if;
   end Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale   : String;
      Family   : String;
      Part     : String;
      Fallback : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      return (if Found then Value else Fallback);
   end Typed_Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale    : String;
      Family    : String;
      Part      : String;
      Alternate : String;
      Fallback  : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      if Found then
         return Value;
      end if;

      return Typed_Runtime_List_Separator
        (Locale, Family, Alternate, Fallback);
   end Typed_Runtime_List_Separator;

   function Typed_Runtime_List_Separator
     (Locale     : String;
      Family     : String;
      Part       : String;
      Alternate1 : String;
      Alternate2 : String;
      Fallback   : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        Runtime_List_Separator (Locale, Family, Part, Found);
   begin
      if Found then
         return Value;
      end if;

      return Typed_Runtime_List_Separator
        (Locale, Family, Alternate1, Alternate2, Fallback);
   end Typed_Runtime_List_Separator;

   function List_Option_Is_Valid (Option : String) return Boolean is
   begin
      return Option = ""
        or else Option = "standard"
        or else Option = "and"
        or else Option = "or"
        or else Option = "disjunction"
        or else Option = "unit";
   end List_Option_Is_Valid;

   function List_Type (Option : String) return String is
   begin
      if Option = "or" or else Option = "disjunction" then
         return "or";
      elsif Option = "unit" then
         return "unit";
      else
         return "standard";
      end if;
   end List_Type;

   function Typed_List_Separator
     (Locale : String;
      Option : String;
      Count  : Natural;
      Total  : Natural)
      return String
   is
      Kind : constant String := List_Type (Option);
   begin
      if Kind = "or" then
         if Total = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "or", "pair", "final",
               I18N.CLDR_Data.List_Or_Pair_Separator (Locale));
         elsif Count = Total then
            return Typed_Runtime_List_Separator
              (Locale, "or", "final",
               I18N.CLDR_Data.List_Or_Final_Separator (Locale));
         elsif Count = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "or", "start",
               I18N.CLDR_Data.List_Or_Start_Separator (Locale));
         else
            return Typed_Runtime_List_Separator
              (Locale, "or", "middle",
               I18N.CLDR_Data.List_Or_Middle_Separator (Locale));
         end if;
      elsif Kind = "unit" then
         if Total = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "pair", "item",
               I18N.CLDR_Data.List_Unit_Pair_Separator (Locale));
         elsif Count = 2 then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "start", "item",
               I18N.CLDR_Data.List_Unit_Start_Separator (Locale));
         elsif Count = Total then
            return Typed_Runtime_List_Separator
              (Locale, "unit", "final", "middle", "item",
               I18N.CLDR_Data.List_Unit_Final_Separator (Locale));
         else
            return Typed_Runtime_List_Separator
              (Locale, "unit", "middle", "item",
               I18N.CLDR_Data.List_Unit_Middle_Separator (Locale));
         end if;
      elsif Total = 2 then
         return List_Pair_Separator (Locale);
      elsif Count = 2 then
         return List_Start_Separator (Locale);
      elsif Count = Total then
         return List_Final_Separator (Locale);
      else
         return List_Middle_Separator (Locale);
      end if;
   end Typed_List_Separator;

   procedure Put_Relative_Offset
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Option   : String;
      Amount   : Natural;
      Future   : Boolean)
   is
      Base : constant String := Option_Base (Option);
      Width : constant String := Relative_Width_Key (Option);
      Category : constant I18N.Plurals.Plural_Category :=
        I18N.Plurals.Cardinal (Locale, Long_Long_Integer (Amount));
      Category_Name : constant String := Plural_Category_Name (Category);
      Pattern : constant String :=
        I18N.CLDR_Data.Relative_Time_Pattern
          (Locale, Base, Width, Category_Name, Future);
      Relative_Unit : constant String :=
        Relative_Unit_Name (Locale, Base, Amount);
      Unit : constant String :=
        (if Relative_Unit /= ""
         then Relative_Unit
         else Localized_Unit_Name
           (Locale, Option, I18N.Plurals.Cardinal
              (Locale, Long_Long_Integer (Amount)) = I18N.Plurals.One));
      Runtime_Pattern_Found : Boolean;
      Runtime_Pattern : constant String :=
        Runtime_Relative_Time_Pattern
          (Locale, Base, Width, Category_Name, Future,
           Runtime_Pattern_Found);
   begin
      if Runtime_Pattern_Found then
         declare
            Amount_Buffer : String (1 .. 64);
            Amount_Last   : Natural := 0;
            Amount_Overflow : Boolean := False;
         begin
            Put_Natural
              (Amount_Buffer, Amount_Last, Amount_Overflow, Locale, Amount);
            if not Amount_Overflow then
               Put_Relative_Time_Pattern
                 (Target,
                  Last,
                  Overflow,
                  Runtime_Pattern,
                  Amount_Buffer (1 .. Amount_Last));
               return;
            end if;
         end;
      end if;

      if Pattern /= ""
        and then not Runtime_Relative_Override_Present
          (Locale, Base, Category_Name, Future)
      then
         declare
            Amount_Buffer : String (1 .. 64);
            Amount_Last   : Natural := 0;
            Amount_Overflow : Boolean := False;
         begin
            Put_Natural
              (Amount_Buffer, Amount_Last, Amount_Overflow, Locale, Amount);
            if not Amount_Overflow then
               Put_Relative_Time_Pattern
                 (Target,
                  Last,
                  Overflow,
                  Pattern,
                  Amount_Buffer (1 .. Amount_Last));
               return;
            end if;
         end;
      end if;

      Put
        (Target, Last, Overflow,
         Relative_Offset_Prefix (Locale, Future));
      Put_Natural (Target, Last, Overflow, Locale, Amount);
      Put
        (Target, Last, Overflow,
         Unit_Value_Separator (Locale));
      Put (Target, Last, Overflow, Unit);
      Put
        (Target, Last, Overflow,
         Relative_Offset_Suffix (Locale, Future));
   end Put_Relative_Offset;

   function Is_Valid_Option
     (Kind   : Extra_Kind;
      Option : String)
      return Boolean
   is
   begin
      case Kind is
         when Duration | Byte_Size =>
            return Option = "";
         when List =>
            return List_Option_Is_Valid (Option);
         when Unit =>
            return Unit_Option_Is_Valid (Option);
         when Relative_Time =>
            return Relative_Option_Is_Valid (Option);
      end case;
   end Is_Valid_Option;

   procedure Format_Duration
     (Value    : String;
      Locale   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Total   : Natural;
      Hours   : Natural;
      Minutes : Natural;
      Seconds : Natural;
   begin
      Ok := False;
      if not Is_Natural_Text (Value) then
         return;
      end if;

      Total := Natural_Value (Value);
      Hours := Total / 3_600;
      Minutes := (Total mod 3_600) / 60;
      Seconds := Total mod 60;

      Put_Natural (Target, Last, Overflow, Locale, Hours);
      Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Duration_Field_Separator (Locale));
      Put_Natural (Target, Last, Overflow, Locale, Minutes, 2);
      Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Duration_Field_Separator (Locale));
      Put_Natural (Target, Last, Overflow, Locale, Seconds, 2);
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Duration;

   procedure Format_Bytes
     (Value    : String;
      Locale   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Amount : Long_Long_Integer;
      Scaled : Long_Long_Integer;
      Scale  : Long_Long_Integer := 1;
   begin
      Ok := False;
      if not Is_Natural_Text (Value) then
         return;
      end if;

      Amount := Long_Long_Natural_Value (Value);
      if Amount >= 1_125_899_906_842_624 then
         Scale := 1_125_899_906_842_624;
         Scaled :=
           (Amount + 562_949_953_421_312) / 1_125_899_906_842_624;
      elsif Amount >= 1_099_511_627_776 then
         Scale := 1_099_511_627_776;
         Scaled := (Amount + 549_755_813_888) / 1_099_511_627_776;
      elsif Amount >= 1_073_741_824 then
         Scale := 1_073_741_824;
         Scaled := (Amount + 536_870_912) / 1_073_741_824;
      elsif Amount >= 1_048_576 then
         Scale := 1_048_576;
         Scaled := (Amount + 524_288) / 1_048_576;
      elsif Amount >= 1_024 then
         Scale := 1_024;
         Scaled := (Amount + 512) / 1_024;
      else
         Scaled := Amount;
      end if;

      Put_Long_Long_Natural (Target, Last, Overflow, Locale, Scaled);
      Put
        (Target, Last, Overflow,
         Unit_Value_Separator (Locale));
      Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Byte_Size_Unit_Label (Scale));
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Bytes;

   procedure Format_Unit
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Name     : String (1 .. 64);
      Name_Last : Natural;
   begin
      Ok := False;
      if not Is_Decimal_Text (Value)
        or else not Unit_Option_Is_Valid (Option)
      then
         return;
      end if;

      declare
         Base     : constant String := Option_Base (Option);
         Text : constant String :=
           Localized_Unit_Name_For_Value (Locale, Option, Value);
         Per_Unit : constant String := Option_Per_Unit (Option);
         Width    : constant String := Option_Width (Option);
         Category : constant I18N.Plurals.Plural_Category :=
           Unit_Category_For_Value (Locale, Value);
         Pattern_Found : Boolean;
         Pattern : constant String :=
           Runtime_Unit_Pattern
             (Locale, Base, Width, Category, Pattern_Found);

         --  CLDR gives some rates a name of their own -- en short
         --  kilometer-per-hour is "km/h", not "km" joined to "hr" by the per
         --  pattern. Composing the parts is the fallback for the rates that
         --  have no such name, not the rule.
         Compound : constant String :=
           (if Per_Unit = "" then ""
            else Base & "-per-" & Option_Base (Per_Unit));
         Compound_Name : constant String :=
           (if Compound = "" or else Has_Runtime_Per_Separator (Locale) then ""
            else Locale_Unit_Name (Locale, Compound, Width, Category));
      begin
         Name_Last := Text'Length;
         if Name_Last > Name'Length then
            return;
         end if;
         Name (1 .. Name_Last) := Text;

         if Compound_Name /= "" then
            --  Some languages seat the value inside the rate's name rather than
            --  in front of it -- Japanese "時速 {0} キロメートル". Such a row is
            --  exported whole, so render it as the pattern it is.
            if Has_Placeholder (Compound_Name) then
               Put_Runtime_Unit_Pattern
                 (Target, Last, Overflow, Locale, Compound_Name, Value);
            else
               Put_Decimal_Text (Target, Last, Overflow, Locale, Value);
               Put
                 (Target, Last, Overflow,
                  Unit_Value_Separator (Locale));
               Put (Target, Last, Overflow, Compound_Name);
            end if;
         elsif Pattern_Found and then Per_Unit = "" then
            Put_Runtime_Unit_Pattern
              (Target, Last, Overflow, Locale, Pattern, Value);
         else
            Put_Decimal_Text (Target, Last, Overflow, Locale, Value);
            Put
              (Target, Last, Overflow,
               Unit_Value_Separator (Locale));
            Put (Target, Last, Overflow, Name (1 .. Name_Last));
         end if;

         if Per_Unit /= "" and then Compound_Name = "" then
            if Width = "unit-width-short"
              or else Width = "short"
              or else Width = "unit-width-narrow"
              or else Width = "narrow"
            then
               Put
                 (Target, Last, Overflow,
                  Unit_Short_Per_Separator (Locale));
               Put
                 (Target, Last, Overflow,
                  Localized_Unit_Name
                    (Locale, Per_Unit & "/" & Width, True));
            else
               Put
                 (Target, Last, Overflow,
                  Per_Unit_Separator (Locale));
               Put
                 (Target, Last, Overflow,
                  Localized_Unit_Name
                    (Locale, Per_Unit & "/" & Width, True));
            end if;
         end if;
      end;

      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Unit;

   procedure Format_Relative
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Offset : Long_Long_Integer;
   begin
      Ok := False;
      if not Is_Integer_Text (Value)
        or else not Relative_Option_Is_Valid (Option)
      then
         return;
      end if;

      Offset := Long_Long_Integer'Value (Value);
      declare
         Exact_Found : Boolean;
         Exact_Value : constant String :=
           Relative_Exact (Locale, Option, Offset, Exact_Found);
      begin
         if Exact_Found then
            Put (Target, Last, Overflow, Exact_Value);
            Ok := not Overflow;
            return;
         end if;
      end;

      if Offset = 0 then
         Put (Target, Last, Overflow, Relative_Current (Locale, Option));
      elsif Offset < 0 then
         Put_Relative_Offset
           (Target, Last, Overflow, Locale, Option, Natural (abs Offset),
            False);
      else
         Put_Relative_Offset
           (Target, Last, Overflow, Locale, Option, Natural (Offset),
            True);
      end if;
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Relative;

   procedure Format_List
     (Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : in out Natural;
      Ok       : out Boolean;
      Overflow : in out Boolean)
   is
      Count : Natural := 1;
      Start : Positive := Value'First;

      function Item_Count return Natural is
         Result : Natural := 1;
      begin
         if Value'Length = 0 then
            return 0;
         end if;
         for C of Value loop
            if C = '|' then
               Result := Result + 1;
            end if;
         end loop;
         return Result;
      end Item_Count;

      Total : constant Natural := Item_Count;
      procedure Put_Item (Text : String) is
      begin
         if Count > 1 then
            Put
              (Target,
               Last,
               Overflow,
               Typed_List_Separator (Locale, Option, Count, Total));
         end if;
         Put (Target, Last, Overflow, Text);
         Count := Count + 1;
      end Put_Item;
   begin
      Ok := False;
      if Total = 0 then
         return;
      end if;

      for Index in Value'Range loop
         if Value (Index) = '|' then
            if Index = Start then
               return;
            end if;
            Put_Item (Value (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;

      if Start > Value'Last then
         return;
      end if;
      Put_Item (Value (Start .. Value'Last));
      Ok := not Overflow;
   end Format_List;

   procedure Format_Into
     (Kind     : Extra_Kind;
      Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : out Natural;
      Ok       : out Boolean;
      Overflow : out Boolean)
   is
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      if not Is_Valid_Option (Kind, Option) then
         return;
      end if;

      case Kind is
         when Duration =>
            Format_Duration (Value, Locale, Target, Last, Ok, Overflow);
         when Byte_Size =>
            Format_Bytes (Value, Locale, Target, Last, Ok, Overflow);
         when Unit =>
            Format_Unit (Value, Locale, Option, Target, Last, Ok, Overflow);
         when Relative_Time =>
            Format_Relative
              (Value, Locale, Option, Target, Last, Ok, Overflow);
         when List =>
            Format_List (Value, Locale, Option, Target, Last, Ok, Overflow);
      end case;
   end Format_Into;

end I18N.Extra_Format;
