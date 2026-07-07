with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with I18N.CLDR_Data;

package body I18N.Runtime_Data is

   package String_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Locale_Overrides : String_Maps.Map;
   Zone_Overrides   : String_Maps.Map;
   Currency_Overrides : String_Maps.Map;
   Locale_Currency_Overrides : String_Maps.Map;
   Plural_Overrides : String_Maps.Map;
   Plural_Family_Overrides : String_Maps.Map;
   Plural_Rule_Overrides : String_Maps.Map;
   Spellout_Overrides : String_Maps.Map;
   Spellout_Rule_Overrides : String_Maps.Map;
   Locale_Prefix    : constant String := "locale.";
   Timezone_Prefix  : constant String := "timezone.";
   Currency_Prefix  : constant String := "currency.";
   Plural_Prefix    : constant String := "plural.";
   RBNF_Prefix      : constant String := "rbnf.";
   RBNF_Rule_Prefix : constant String := "rbnf_rule.";

   function Trimmed (Text : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Trimmed;

   function Unquote (Text : String) return String is
      T : constant String := Trimmed (Text);
   begin
      if T'Length >= 2 and then T (T'First) = '"' and then T (T'Last) = '"'
      then
         return T (T'First + 1 .. T'Last - 1);
      end if;

      return T;
   end Unquote;

   function Equals_Index (Text : String) return Natural is
   begin
      for Index in Text'Range loop
         if Text (Index) = '=' then
            return Index;
         end if;
      end loop;

      return 0;
   end Equals_Index;

   function Field_Count
     (Text      : String;
      Separator : Character := '|')
      return Natural
   is
      Count : Natural := 1;
   begin
      if Text'Length = 0 then
         return 0;
      end if;

      for Index in Text'Range loop
         if Text (Index) = Separator then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Field_Count;

   function Field
     (Text      : String;
      Number    : Positive;
      Separator : Character := '|')
      return String
   is
      Current : Positive := 1;
      Start   : Positive := Text'First;
   begin
      for Index in Text'Range loop
         if Text (Index) = Separator then
            if Current = Number then
               return Text (Start .. Index - 1);
            end if;
            Current := Current + 1;
            Start := Index + 1;
         end if;
      end loop;

      if Current = Number then
         return Text (Start .. Text'Last);
      end if;

      return "";
   end Field;

   function Dot_Index (Text : String; From : Positive) return Natural is
   begin
      if From > Text'Last then
         return 0;
      end if;

      for Index in From .. Text'Last loop
         if Text (Index) = '.' then
            return Index;
         end if;
      end loop;

      return 0;
   end Dot_Index;

   function Char_Index
     (Text : String;
      From : Positive;
      Char : Character)
      return Natural
   is
   begin
      if From > Text'Last then
         return 0;
      end if;

      for Index in From .. Text'Last loop
         if Text (Index) = Char then
            return Index;
         end if;
      end loop;

      return 0;
   end Char_Index;

   function Last_Dot_Index (Text : String) return Natural is
   begin
      for Index in reverse Text'Range loop
         if Text (Index) = '.' then
            return Index;
         end if;
      end loop;

      return 0;
   end Last_Dot_Index;

   function Has_Prefix (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Has_Prefix;

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Has_Prefix (Text, Prefix);
   end Starts_With;

   function Has_Suffix (Text : String; Suffix : String) return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Has_Suffix;

   function Index_Of (Text : String; Pattern : String) return Natural is
   begin
      if Pattern'Length = 0 or else Pattern'Length > Text'Length then
         return 0;
      end if;

      for Index in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            return Index;
         end if;
      end loop;

      return 0;
   end Index_Of;

   function Occurrence_Count (Text : String; Pattern : String) return Natural is
      Count : Natural := 0;
   begin
      if Pattern'Length = 0 or else Pattern'Length > Text'Length then
         return 0;
      end if;

      for Index in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Occurrence_Count;

   function List_Pattern_Separator
     (Text  : String;
      Valid : out Boolean)
      return String
   is
      First_Arg  : constant Natural := Index_Of (Text, "{0}");
      Second_Arg : constant Natural := Index_Of (Text, "{1}");
   begin
      if First_Arg = 0 and then Second_Arg = 0 then
         Valid := True;
         return Text;
      end if;

      Valid :=
        First_Arg = Text'First
        and then Second_Arg > First_Arg + 2
        and then Second_Arg + 2 = Text'Last
        and then Occurrence_Count (Text, "{0}") = 1
        and then Occurrence_Count (Text, "{1}") = 1;

      if not Valid then
         return "";
      end if;

      return Text (First_Arg + 3 .. Second_Arg - 1);
   end List_Pattern_Separator;

   function Normalize_List_Pattern_Type (Raw_Type : String) return String is
   begin
      if Raw_Type = ""
        or else Raw_Type = "standard"
        or else Raw_Type = "and"
      then
         return "standard";
      elsif Raw_Type = "or" or else Raw_Type = "disjunction" then
         return "or";
      elsif Raw_Type = "unit" then
         return "unit";
      else
         return "";
      end if;
   end Normalize_List_Pattern_Type;

   function List_Separator_Field
     (Kind       : String;
      Parent_Type : String)
      return String
   is
      Family : constant String := Normalize_List_Pattern_Type (Parent_Type);
      Suffix : constant String :=
        (if Kind = "final" then "final_separator"
         elsif Kind = "end" then "final_separator"
         elsif Kind = "2" then "pair_separator"
         elsif Kind = "two" then "pair_separator"
         elsif Kind = "pair" then "pair_separator"
         elsif Kind = "start" then "start_separator"
         elsif Kind = "middle" then "middle_separator"
         elsif Kind = "item" then "item_separator"
         else "");
   begin
      if Family = "" or else Suffix = "" then
         return "";
      elsif Family = "standard" then
         return "list_" & Suffix;
      else
         return "list_" & Family & "_" & Suffix;
      end if;
   end List_Separator_Field;

   function Relative_Pattern_Affix
     (Text   : String;
      Prefix : Boolean;
      Valid  : out Boolean)
      return String
   is
      Arg : constant Natural := Index_Of (Text, "{0}");
   begin
      Valid :=
        Arg /= 0
        and then Occurrence_Count (Text, "{0}") = 1;

      if not Valid then
         return "";
      elsif Prefix then
         if Arg = Text'First then
            return "";
         else
            return Text (Text'First .. Arg - 1);
         end if;
      elsif Arg + 2 = Text'Last then
         return "";
      else
         return Text (Arg + 3 .. Text'Last);
      end if;
   end Relative_Pattern_Affix;

   function Unit_Pattern_Name
     (Text  : String;
      Valid : out Boolean)
      return String
   is
      Arg : constant Natural := Index_Of (Text, "{0}");
   begin
      if Arg = 0 then
         Valid := Text'Length > 0;
         return Text;
      end if;

      Valid :=
        Arg = Text'First
        and then Occurrence_Count (Text, "{0}") = 1
        and then Arg + 2 < Text'Last;

      if not Valid then
         return "";
      end if;

      return Trimmed (Text (Arg + 3 .. Text'Last));
   end Unit_Pattern_Name;

   function Is_Unit_Pattern (Text : String) return Boolean is
   begin
      return Text'Length > 0
        and then Index_Of (Text, "{0}") /= 0
        and then Occurrence_Count (Text, "{0}") = 1;
   end Is_Unit_Pattern;

   function Normalize_Unit_Base (Raw : String) return String is
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
   end Normalize_Unit_Base;

   function Is_Supported_Unit_Base (Unit : String) return Boolean is
   begin
      return Unit = "item"
        or else Unit = "meter"
        or else Unit = "kilometer"
        or else Unit = "mile"
        or else Unit = "yard"
        or else Unit = "foot"
        or else Unit = "inch"
        or else Unit = "centimeter"
        or else Unit = "millimeter"
        or else Unit = "decimeter"
        or else Unit = "micrometer"
        or else Unit = "nanometer"
        or else Unit = "picometer"
        or else Unit = "nautical-mile"
        or else Unit = "astronomical-unit"
        or else Unit = "light-year"
        or else Unit = "parsec"
        or else Unit = "fathom"
        or else Unit = "furlong"
        or else Unit = "pixel"
        or else Unit = "point"
        or else Unit = "solar-radius"
        or else Unit = "earth-radius"
        or else Unit = "dot"
        or else Unit = "megapixel"
        or else Unit = "pixel-per-centimeter"
        or else Unit = "pixel-per-inch"
        or else Unit = "dot-per-centimeter"
        or else Unit = "dot-per-inch"
        or else Unit = "liter"
        or else Unit = "milliliter"
        or else Unit = "gallon"
        or else Unit = "fluid-ounce"
        or else Unit = "cup"
        or else Unit = "tablespoon"
        or else Unit = "teaspoon"
        or else Unit = "pint"
        or else Unit = "quart"
        or else Unit = "barrel"
        or else Unit = "cubic-meter"
        or else Unit = "cubic-centimeter"
        or else Unit = "cubic-inch"
        or else Unit = "cubic-foot"
        or else Unit = "cubic-yard"
        or else Unit = "acre-foot"
        or else Unit = "gram"
        or else Unit = "kilogram"
        or else Unit = "milligram"
        or else Unit = "tonne"
        or else Unit = "pound"
        or else Unit = "ounce"
        or else Unit = "stone"
        or else Unit = "carat"
        or else Unit = "ton"
        or else Unit = "dalton"
        or else Unit = "earth-mass"
        or else Unit = "solar-mass"
        or else Unit = "nanosecond"
        or else Unit = "microsecond"
        or else Unit = "millisecond"
        or else Unit = "second"
        or else Unit = "minute"
        or else Unit = "hour"
        or else Unit = "day"
        or else Unit = "week"
        or else Unit = "month"
        or else Unit = "year"
        or else Unit = "quarter"
        or else Unit = "decade"
        or else Unit = "century"
        or else Unit = "fortnight"
        or else Unit = "square-meter"
        or else Unit = "square-kilometer"
        or else Unit = "acre"
        or else Unit = "hectare"
        or else Unit = "square-foot"
        or else Unit = "square-mile"
        or else Unit = "square-centimeter"
        or else Unit = "square-inch"
        or else Unit = "square-yard"
        or else Unit = "celsius"
        or else Unit = "fahrenheit"
        or else Unit = "kelvin"
        or else Unit = "degree"
        or else Unit = "radian"
        or else Unit = "revolution"
        or else Unit = "arc-minute"
        or else Unit = "arc-second"
        or else Unit = "g-force"
        or else Unit = "meter-per-square-second"
        or else Unit = "newton"
        or else Unit = "pound-force"
        or else Unit = "newton-meter"
        or else Unit = "byte"
        or else Unit = "bit"
        or else Unit = "kilobyte"
        or else Unit = "kilobit"
        or else Unit = "megabyte"
        or else Unit = "gigabyte"
        or else Unit = "terabyte"
        or else Unit = "terabit"
        or else Unit = "megabit"
        or else Unit = "gigabit"
        or else Unit = "petabyte"
        or else Unit = "petabit"
        or else Unit = "exabyte"
        or else Unit = "exabit"
        or else Unit = "kilometer-per-hour"
        or else Unit = "mile-per-hour"
        or else Unit = "knot"
        or else Unit = "beaufort"
        or else Unit = "meter-per-second"
        or else Unit = "liter-per-100-kilometer"
        or else Unit = "mile-per-gallon"
        or else Unit = "mile-per-gallon-imperial"
        or else Unit = "joule"
        or else Unit = "kilojoule"
        or else Unit = "calorie"
        or else Unit = "kilocalorie"
        or else Unit = "kilowatt-hour"
        or else Unit = "electronvolt"
        or else Unit = "british-thermal-unit"
        or else Unit = "therm-us"
        or else Unit = "watt"
        or else Unit = "kilowatt"
        or else Unit = "horsepower"
        or else Unit = "hertz"
        or else Unit = "kilohertz"
        or else Unit = "megahertz"
        or else Unit = "hectopascal"
        or else Unit = "pascal"
        or else Unit = "kilopascal"
        or else Unit = "millibar"
        or else Unit = "bar"
        or else Unit = "atmosphere"
        or else Unit = "inch-ofhg"
        or else Unit = "millimeter-ofhg"
        or else Unit = "pound-force-per-square-inch"
        or else Unit = "ampere"
        or else Unit = "milliampere"
        or else Unit = "volt"
        or else Unit = "millivolt"
        or else Unit = "ohm"
        or else Unit = "lumen"
        or else Unit = "lux"
        or else Unit = "candela"
        or else Unit = "solar-luminosity"
        or else Unit = "percent"
        or else Unit = "permille"
        or else Unit = "permillion"
        or else Unit = "portion"
        or else Unit = "karat";
   end Is_Supported_Unit_Base;

   function Normalize_Unit_Width (Raw : String) return String is
   begin
      if Raw = "" or else Raw = "long" or else Raw = "full-name" then
         return "unit-width-full-name";
      elsif Raw = "short" then
         return "unit-width-short";
      elsif Raw = "narrow" then
         return "unit-width-narrow";
      else
         return Raw;
      end if;
   end Normalize_Unit_Width;

   function Weekday_Type_Index (Raw : String) return String is
   begin
      if Raw = "sun" then
         return "0";
      elsif Raw = "mon" then
         return "1";
      elsif Raw = "tue" then
         return "2";
      elsif Raw = "wed" then
         return "3";
      elsif Raw = "thu" then
         return "4";
      elsif Raw = "fri" then
         return "5";
      elsif Raw = "sat" then
         return "6";
      else
         return "";
      end if;
   end Weekday_Type_Index;

   function Normalize_Calendar_Name (Raw : String) return String is
   begin
      if Raw = "gregory" then
         return "gregorian";
      elsif Raw = "islamicc" then
         return "islamic-civil";
      else
         return Raw;
      end if;
   end Normalize_Calendar_Name;

   function Normalize_Era_Name (Calendar : String; Raw : String) return String is
   begin
      if Calendar = "gregorian" then
         if Raw = "0" then
            return "bc";
         elsif Raw = "1" then
            return "ad";
         end if;
      elsif Calendar = "roc" then
         if Raw = "1" then
            return "minguo";
         end if;
      end if;

      return Raw;
   end Normalize_Era_Name;

   function Has_Explicit_Numbering_System (Locale : String) return Boolean is
   begin
      return Index_Of (Locale, "-u-nu-") /= 0
        or else Index_Of (Locale, "@numbers=") /= 0;
   end Has_Explicit_Numbering_System;

   function Is_Supported_Numbering_System (Name : String) return Boolean is
   begin
      return Name = "latn"
        or else I18N.CLDR_Data.Digit_Text ("x-u-nu-" & Name, '0') /= "0";
   end Is_Supported_Numbering_System;

   function Numbering_System_Digit
     (Name  : String;
      Digit : Character)
      return String
   is begin
      if not (Digit in '0' .. '9') then
         return [1 => Digit];
      elsif Name = "latn" then
         return [1 => Digit];
      elsif Is_Supported_Numbering_System (Name) then
         return I18N.CLDR_Data.Digit_Text ("x-u-nu-" & Name, Digit);
      else
         return [1 => Digit];
      end if;
   end Numbering_System_Digit;

   function Decode_XML_Entities (Text : String) return String;

   function Attribute_Value (Line : String; Name : String) return String is
      function Is_Name_Character (C : Character) return Boolean is
      begin
         return C in 'A' .. 'Z'
           or else C in 'a' .. 'z'
           or else C in '0' .. '9'
           or else C = '_'
           or else C = '-'
           or else C = ':';
      end Is_Name_Character;

      function Is_XML_Space (C : Character) return Boolean is
      begin
         return C = ' ' or else C = ASCII.HT;
      end Is_XML_Space;

      Pos : Natural := Line'First;
   begin
      while Pos <= Line'Last loop
         if Pos + Name'Length - 1 <= Line'Last
           and then Line (Pos .. Pos + Name'Length - 1) = Name
           and then (Pos = Line'First
                     or else not Is_Name_Character (Line (Pos - 1)))
         then
            declare
               Cursor : Natural := Pos + Name'Length;
            begin
               if Cursor <= Line'Last
                 and then (not Is_Name_Character (Line (Cursor)))
               then
                  while Cursor <= Line'Last
                    and then Is_XML_Space (Line (Cursor))
                  loop
                     Cursor := Cursor + 1;
                  end loop;

                  if Cursor <= Line'Last and then Line (Cursor) = '=' then
                     Cursor := Cursor + 1;

                     while Cursor <= Line'Last
                       and then Is_XML_Space (Line (Cursor))
                     loop
                        Cursor := Cursor + 1;
                     end loop;

                     if Cursor <= Line'Last
                       and then (Line (Cursor) = Character'Val (34)
                                 or else Line (Cursor) = Character'Val (39))
                     then
                        declare
                           Quote : constant Character := Line (Cursor);
                           First : constant Natural := Cursor + 1;
                        begin
                           if First > Line'Last then
                              return "";
                           end if;

                           for Last in First .. Line'Last loop
                              if Line (Last) = Quote then
                                 if Last = First then
                                    return "";
                                 else
                                    return Decode_XML_Entities
                                      (Line (First .. Last - 1));
                                 end if;
                              end if;
                           end loop;
                        end;
                     end if;
                  end if;
               end if;
            end;
         end if;

         Pos := Pos + 1;
      end loop;

      return "";
   end Attribute_Value;

   function Attribute_Value
     (Line    : String;
      Primary : String;
      Alias   : String)
      return String
   is
      Value : constant String := Attribute_Value (Line, Primary);
   begin
      if Value /= "" then
         return Value;
      else
         return Attribute_Value (Line, Alias);
      end if;
   end Attribute_Value;

   function Element_Text (Line : String) return String is
      Open_End    : constant Natural := Char_Index (Line, Line'First, '>');
      Close_Start : constant Natural := Index_Of (Line, "</");

      function Decode_XML_Text (Text : String) return String is
         CDATA_Start : constant String := "<![CDATA[";
         CDATA_End   : constant String := "]]>";
         Result      : Unbounded_String;
         Cursor      : Natural := Text'First;

         function Index_Of_From
           (Pattern : String;
            From    : Natural)
            return Natural
         is
         begin
            if Pattern'Length = 0
              or else Text'Length = 0
              or else From > Text'Last
              or else Pattern'Length > Text'Last - From + 1
            then
               return 0;
            end if;

            for Index in From .. Text'Last - Pattern'Length + 1 loop
               if Text (Index .. Index + Pattern'Length - 1) = Pattern then
                  return Index;
               end if;
            end loop;

            return 0;
         end Index_Of_From;
      begin
         if Text'Length = 0 then
            return "";
         end if;

         while Cursor <= Text'Last loop
            declare
               Next_CDATA : constant Natural :=
                 Index_Of_From (CDATA_Start, Cursor);
            begin
               if Next_CDATA = 0 then
                  Append (Result, Decode_XML_Entities
                            (Text (Cursor .. Text'Last)));
                  Cursor := Text'Last + 1;
               else
                  if Next_CDATA > Cursor then
                     Append (Result, Decode_XML_Entities
                               (Text (Cursor .. Next_CDATA - 1)));
                  end if;

                  declare
                     Content_Start : constant Natural :=
                       Next_CDATA + CDATA_Start'Length;
                     Content_End   : constant Natural :=
                       Index_Of_From (CDATA_End, Content_Start);
                  begin
                     if Content_End = 0 then
                        return "";
                     elsif Content_End > Content_Start then
                        Append (Result,
                                Text (Content_Start .. Content_End - 1));
                     end if;

                     Cursor := Content_End + CDATA_End'Length;
                  end;
               end if;
            end;
         end loop;

         return To_String (Result);
      end Decode_XML_Text;
   begin
      if Open_End = 0 or else Close_Start = 0 or else Close_Start <= Open_End + 1
      then
         return "";
      end if;

      return Decode_XML_Text (Line (Open_End + 1 .. Close_Start - 1));
   end Element_Text;

   function Date_Time_Separator_From_Pattern
     (Pattern : String;
      Found   : out Boolean)
      return String
   is
      Date_Pos : constant Natural := Index_Of (Pattern, "{1}");
      Time_Pos : constant Natural := Index_Of (Pattern, "{0}");
   begin
      Found := False;

      if Date_Pos = 0
        or else Time_Pos = 0
        or else Date_Pos /= Pattern'First
        or else Time_Pos + 2 /= Pattern'Last
        or else Date_Pos + 3 > Time_Pos
      then
         return "";
      end if;

      if Occurrence_Count (Pattern, "{1}") /= 1
        or else Occurrence_Count (Pattern, "{0}") /= 1
      then
         return "";
      end if;

      Found := True;
      return Pattern (Date_Pos + 3 .. Time_Pos - 1);
   end Date_Time_Separator_From_Pattern;

   procedure Currency_Fields_From_Pattern
     (Pattern              : String;
      Symbol_First         : out Boolean;
      Separator            : out Unbounded_String;
      Accounting_Prefix    : out Unbounded_String;
      Accounting_Suffix    : out Unbounded_String;
      Has_Accounting       : out Boolean;
      Found                : out Boolean)
   is
      Currency_Sign : constant String :=
        Character'Val (16#C2#) & Character'Val (16#A4#);
      Sep : constant Natural := Char_Index (Pattern, Pattern'First, ';');
      Positive_Pattern : constant String :=
        (if Sep = 0 then Pattern else Pattern (Pattern'First .. Sep - 1));
      Negative_Pattern : constant String :=
        (if Sep = 0 or else Sep = Pattern'Last
         then "" else Pattern (Sep + 1 .. Pattern'Last));

      function Is_Amount_Char (Item : Character) return Boolean is
      begin
         return Item = '#'
           or else Item = '0'
           or else Item = ','
           or else Item = '.';
      end Is_Amount_Char;

      function Analyze_Positive
        (Item         : String;
         First_Symbol : out Boolean;
         Gap          : out Unbounded_String)
         return Boolean
      is
         Symbol_Pos : constant Natural := Index_Of (Item, Currency_Sign);
         Symbol_End : constant Natural :=
           (if Symbol_Pos = 0 then 0
            else Symbol_Pos + Currency_Sign'Length - 1);
         Amount_First : Natural := 0;
         Amount_Last  : Natural := 0;
      begin
         for Index in Item'Range loop
            if Is_Amount_Char (Item (Index)) then
               if Amount_First = 0 then
                  Amount_First := Index;
               end if;
               Amount_Last := Index;
            end if;
         end loop;

         if Symbol_Pos = 0
           or else Amount_First = 0
           or else Amount_Last = 0
           or else (Symbol_Pos <= Amount_Last
                    and then Symbol_End >= Amount_First)
         then
            return False;
         elsif Symbol_Pos < Amount_First then
            First_Symbol := True;
            if Symbol_End + 1 < Amount_First then
               Gap := To_Unbounded_String
                 (Item (Symbol_End + 1 .. Amount_First - 1));
            else
               Gap := Null_Unbounded_String;
            end if;
         else
            First_Symbol := False;
            if Amount_Last + 1 < Symbol_Pos then
               Gap := To_Unbounded_String
                 (Item (Amount_Last + 1 .. Symbol_Pos - 1));
            else
               Gap := Null_Unbounded_String;
            end if;
         end if;

         return True;
      end Analyze_Positive;
   begin
      Symbol_First := True;
      Separator := Null_Unbounded_String;
      Accounting_Prefix := Null_Unbounded_String;
      Accounting_Suffix := Null_Unbounded_String;
      Has_Accounting := False;
      Found := False;

      if Positive_Pattern'Length = 0
        or else not Analyze_Positive
          (Positive_Pattern, Symbol_First, Separator)
      then
         return;
      end if;

      if Negative_Pattern /= "" then
         declare
            Symbol_Pos : constant Natural :=
              Index_Of (Negative_Pattern, Currency_Sign);
            Symbol_End : constant Natural :=
              (if Symbol_Pos = 0 then 0
               else Symbol_Pos + Currency_Sign'Length - 1);
            Amount_First : Natural := 0;
            Amount_Last  : Natural := 0;
            Content_First : Natural;
            Content_Last  : Natural;
         begin
            for Index in Negative_Pattern'Range loop
               if Is_Amount_Char (Negative_Pattern (Index)) then
                  if Amount_First = 0 then
                     Amount_First := Index;
                  end if;
                  Amount_Last := Index;
               end if;
            end loop;

            if Symbol_Pos = 0
              or else Amount_First = 0
              or else Amount_Last = 0
            then
               return;
            end if;

            Content_First := Natural'Min (Symbol_Pos, Amount_First);
            Content_Last := Natural'Max (Symbol_End, Amount_Last);
            Accounting_Prefix := To_Unbounded_String
              (Negative_Pattern
                 (Negative_Pattern'First .. Content_First - 1));
            Accounting_Suffix := To_Unbounded_String
              (Negative_Pattern (Content_Last + 1 .. Negative_Pattern'Last));
            Has_Accounting := True;
         end;
      end if;

      Found := True;
   end Currency_Fields_From_Pattern;

   function Append_Item_Separator_From_Pattern
     (Pattern : String;
      Found   : out Boolean)
      return String
   is
      Base_Pos   : constant Natural := Index_Of (Pattern, "{0}");
      Append_Pos : constant Natural := Index_Of (Pattern, "{1}");
   begin
      Found := False;

      if Base_Pos = 0
        or else Append_Pos = 0
        or else Base_Pos /= Pattern'First
        or else Append_Pos + 2 /= Pattern'Last
        or else Base_Pos + 3 > Append_Pos
      then
         return "";
      end if;

      if Occurrence_Count (Pattern, "{0}") /= 1
        or else Occurrence_Count (Pattern, "{1}") /= 1
      then
         return "";
      end if;

      Found := True;
      return Pattern (Base_Pos + 3 .. Append_Pos - 1);
   end Append_Item_Separator_From_Pattern;

   function GMT_Format_Prefix_From_Pattern
     (Pattern : String;
      Found   : out Boolean)
      return String
   is
      Offset_Pos : constant Natural := Index_Of (Pattern, "{0}");
   begin
      Found := False;

      if Offset_Pos = 0
        or else Offset_Pos + 2 /= Pattern'Last
        or else Occurrence_Count (Pattern, "{0}") /= 1
      then
         return "";
      end if;

      Found := True;
      return Pattern (Pattern'First .. Offset_Pos - 1);
   end GMT_Format_Prefix_From_Pattern;

   function Hour_Format_Separator_From_Pattern
     (Pattern : String;
      Found   : out Boolean)
      return String
   is
      Sep_Pos : Natural := 0;
   begin
      Found := False;

      if Pattern'Length < 12
        or else Pattern (Pattern'First .. Pattern'First + 2) /= "+HH"
      then
         return "";
      end if;

      for Index in Pattern'First + 3 .. Pattern'Last - 9 loop
         if Pattern (Index + 1 .. Index + 6) = "mm;-HH" then
            Sep_Pos := Index;
            exit;
         end if;
      end loop;

      if Sep_Pos = 0
        or else Sep_Pos + 9 > Pattern'Last
        or else Pattern (Sep_Pos + 7) /= Pattern (Sep_Pos)
        or else Pattern (Sep_Pos + 8 .. Sep_Pos + 9) /= "mm"
        or else Sep_Pos + 9 /= Pattern'Last
      then
         return "";
      end if;

      Found := True;
      return Pattern (Sep_Pos .. Sep_Pos);
   end Hour_Format_Separator_From_Pattern;

   function Parent_Locale (Locale : String) return String is
   begin
      for Index in Locale'Range loop
         if Locale (Index) = '-' or else Locale (Index) = '_' then
            if Index = Locale'First then
               return "";
            end if;

            return Locale (Locale'First .. Index - 1);
         end if;
      end loop;

      return "";
   end Parent_Locale;

   function Locale_Key (Locale : String; Field : String) return String is
   begin
      return Locale & Character'Val (0) & Field;
   end Locale_Key;

   function Zone_Key (Zone : String; Field : String) return String is
   begin
      return Zone & Character'Val (0) & Field;
   end Zone_Key;

   function Zone_Transition_Field (UTC_Key : String) return String is
   begin
      return "transition." & UTC_Key;
   end Zone_Transition_Field;

   function Currency_Key (Code : String; Field : String) return String is
   begin
      return Code & Character'Val (0) & Field;
   end Currency_Key;

   function Locale_Currency_Key
     (Locale : String;
      Code   : String;
      Field  : String)
      return String
   is
   begin
      return Locale & Character'Val (0) & Code & Character'Val (0) & Field;
   end Locale_Currency_Key;

   function Plural_Key
     (Kind   : String;
      Locale : String;
      Value  : String)
      return String
   is
   begin
      return Kind & Character'Val (0) & Locale & Character'Val (0) & Value;
   end Plural_Key;

   function Plural_Family_Key (Kind : String; Locale : String) return String is
   begin
      return Kind & Character'Val (0) & Locale;
   end Plural_Family_Key;

   function Plural_Category_Rule_Key
     (Kind     : String;
      Locale   : String;
      Category : String)
      return String
   is
   begin
      return Kind & Character'Val (0) & Locale & Character'Val (0) & Category;
   end Plural_Category_Rule_Key;

   function Spellout_Key
     (Locale : String;
      Kind   : String;
      Value  : String)
      return String
   is
   begin
      return Locale & Character'Val (0) & Kind & Character'Val (0) & Value;
   end Spellout_Key;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Text;

   function Integer_Text (Value : Integer) return String is
      Image : constant String := Integer'Image (Value);
   begin
      if Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      else
         return Image;
      end if;
   end Integer_Text;

   function Hex_Value (C : Character) return Integer is
   begin
      if C in '0' .. '9' then
         return Character'Pos (C) - Character'Pos ('0');
      elsif C in 'A' .. 'F' then
         return 10 + Character'Pos (C) - Character'Pos ('A');
      elsif C in 'a' .. 'f' then
         return 10 + Character'Pos (C) - Character'Pos ('a');
      else
         return -1;
      end if;
   end Hex_Value;

   function Is_Hex_Text (Text : String) return Boolean is
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for Index in Text'Range loop
         if Hex_Value (Text (Index)) < 0 then
            return False;
         end if;
      end loop;

      return True;
   end Is_Hex_Text;

   function Hex_Number (Text : String) return Natural is
      Value : Natural := 0;
   begin
      for Index in Text'Range loop
         Value := Value * 16 + Hex_Value (Text (Index));
      end loop;
      return Value;
   end Hex_Number;

   function UTF8 (Code : Natural) return String is
   begin
      if Code <= 16#7F# then
         return String'(1 => Character'Val (Code));
      elsif Code <= 16#7FF# then
         return String'
           (1 => Character'Val (16#C0# + Code / 64),
            2 => Character'Val (16#80# + Code mod 64));
      elsif Code <= 16#FFFF# then
         return String'
           (1 => Character'Val (16#E0# + Code / 4096),
            2 => Character'Val (16#80# + (Code / 64) mod 64),
            3 => Character'Val (16#80# + Code mod 64));
      elsif Code <= 16#10FFFF# then
         return String'
           (1 => Character'Val (16#F0# + Code / 262144),
            2 => Character'Val (16#80# + (Code / 4096) mod 64),
            3 => Character'Val (16#80# + (Code / 64) mod 64),
            4 => Character'Val (16#80# + Code mod 64));
      else
         return "";
      end if;
   end UTF8;

   function Decode_XML_Entities (Text : String) return String is
      Result : Unbounded_String := Null_Unbounded_String;
      Index  : Natural := Text'First;

      function Numeric_Entity (Entity_Body : String) return String is
      begin
         if Entity_Body'Length >= 2
           and then Entity_Body (Entity_Body'First) = '#'
           and then (Entity_Body (Entity_Body'First + 1) = 'x'
                     or else Entity_Body (Entity_Body'First + 1) = 'X')
         then
            declare
               Hex : constant String :=
                 Entity_Body (Entity_Body'First + 2 .. Entity_Body'Last);
            begin
               if Is_Hex_Text (Hex) then
                  return UTF8 (Hex_Number (Hex));
               end if;
            end;
         elsif Entity_Body'Length >= 2
           and then Entity_Body (Entity_Body'First) = '#'
         then
            declare
               Value : Natural := 0;
            begin
               for Pos in Entity_Body'First + 1 .. Entity_Body'Last loop
                  if Entity_Body (Pos) not in '0' .. '9' then
                     return "";
                  end if;

                  Value :=
                    Value * 10
                    + Character'Pos (Entity_Body (Pos))
                    - Character'Pos ('0');
               end loop;

               return UTF8 (Value);
            exception
               when Constraint_Error =>
                  return "";
            end;
         end if;

         return "";
      end Numeric_Entity;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      while Index <= Text'Last loop
         if Text (Index) /= '&' then
            Append (Result, Text (Index));
            Index := Index + 1;
         else
            declare
               Semi : Natural := 0;
            begin
               for Pos in Index + 1 .. Text'Last loop
                  if Text (Pos) = ';' then
                     Semi := Pos;
                     exit;
                  end if;
               end loop;

               if Semi = 0 then
                  Append (Result, Text (Index));
                  Index := Index + 1;
               else
                  declare
                     Entity_Body : constant String :=
                       Text (Index + 1 .. Semi - 1);
                     Decoded : constant String :=
                       (if Entity_Body = "amp" then "&"
                        elsif Entity_Body = "lt" then "<"
                        elsif Entity_Body = "gt" then ">"
                        elsif Entity_Body = "quot" then [1 => Character'Val (34)]
                        elsif Entity_Body = "apos" then "'"
                        else Numeric_Entity (Entity_Body));
                  begin
                     if Decoded'Length = 0 then
                        Append (Result, Text (Index .. Semi));
                     else
                        Append (Result, Decoded);
                     end if;

                     Index := Semi + 1;
                  end;
               end if;
            end;
         end if;
      end loop;

      return To_String (Result);
   end Decode_XML_Entities;

   function Codepoint_List_To_UTF8
     (Text      : String;
      Separator : Character := ',')
      return String
   is
      Result : String (1 .. Text'Length * 4);
      Last   : Natural := 0;
   begin
      for Index in 1 .. Field_Count (Text, Separator) loop
         declare
            Item : constant String := Field (Text, Index, Separator);
         begin
            if not Is_Hex_Text (Item) then
               return "";
            end if;

            declare
               Encoded : constant String := UTF8 (Hex_Number (Item));
            begin
               if Encoded'Length = 0 or else Last + Encoded'Length > Result'Length
               then
                  return "";
               end if;
               Result (Last + 1 .. Last + Encoded'Length) := Encoded;
               Last := Last + Encoded'Length;
            end;
         end;
      end loop;

      return Result (1 .. Last);
   end Codepoint_List_To_UTF8;

   function Hex_Bytes_To_UTF8 (Text : String) return String is
      Result : String (1 .. Text'Length / 2);
      Last   : Natural := 0;
   begin
      if Text'Length = 0 or else Text'Length mod 2 /= 0
        or else not Is_Hex_Text (Text)
      then
         return "";
      end if;

      declare
         Index : Natural := Text'First;
      begin
         while Index <= Text'Last loop
            Last := Last + 1;
            Result (Last) :=
              Character'Val
                (Hex_Number (Text (Index .. Index + 1)));
            Index := Index + 2;
         end loop;
      end;

      return Result (1 .. Last);
   end Hex_Bytes_To_UTF8;

   function Hex_Scalars_To_UTF8 (Text : String) return String is
      Result : String (1 .. Text'Length);
      Last   : Natural := 0;
      Index  : Natural := Text'First;
   begin
      if Text'Length = 0 or else not Is_Hex_Text (Text) then
         return "";
      end if;

      while Index <= Text'Last loop
         declare
            Remaining : constant Natural := Text'Last - Index + 1;
            Width     : constant Natural :=
              (if Remaining mod 4 = 0 then 4
               elsif Remaining mod 5 = 0 then 5
               elsif Remaining >= 4 then 4
               else 0);
         begin
            if Width = 0 or else Index + Width - 1 > Text'Last then
               return "";
            end if;

            declare
               Encoded : constant String :=
                 UTF8 (Hex_Number (Text (Index .. Index + Width - 1)));
            begin
               if Encoded'Length = 0 or else Last + Encoded'Length > Result'Length
               then
                  return "";
               end if;
               Result (Last + 1 .. Last + Encoded'Length) := Encoded;
               Last := Last + Encoded'Length;
            end;

            Index := Index + Width;
         end;
      end loop;

      return Result (1 .. Last);
   end Hex_Scalars_To_UTF8;

   function Is_Integer_Text (Text : String) return Boolean is
      First : Positive := Text'First;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      if Text (First) = '-' or else Text (First) = '+' then
         if Text'Length = 1 then
            return False;
         end if;

         First := First + 1;
      end if;

      for Index in First .. Text'Last loop
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Integer_Text;

   function In_Integer_Range (Text : String) return Boolean is
      Dummy : Integer;
   begin
      if not Is_Integer_Text (Text) then
         return False;
      end if;

      Dummy := Integer'Value (Text);
      return True;
   exception
      when Constraint_Error =>
         return False;
   end In_Integer_Range;

   function Is_Spellout_Decimal_Text (Text : String) return Boolean is
      Start       : Positive := Text'First;
      Dot         : Natural := 0;
      Whole_Value : Natural := 0;
   begin
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
         elsif Text (Index) not in '0' .. '9' then
            return False;
         elsif Dot = 0 then
            Whole_Value :=
              Whole_Value * 10
              + Character'Pos (Text (Index)) - Character'Pos ('0');
            if Whole_Value > 999_999_999 then
               return False;
            end if;
         end if;
      end loop;

      return Dot /= 0 and then Dot /= Start and then Dot /= Text'Last;
   exception
      when Constraint_Error =>
         return False;
   end Is_Spellout_Decimal_Text;

   function Parse_Offset_Seconds (Text : String; Seconds : out Integer)
                                  return Boolean is
      Start    : Positive := Text'First;
      Negative : Boolean := False;
      First_Sep : Natural := 0;
      Second_Sep : Natural := 0;
      Colon_Count : Natural := 0;
   begin
      Seconds := 0;

      if Text'Length = 0 then
         return False;
      end if;

      if Text = "Z" or else Text = "z"
        or else Text = "UTC" or else Text = "utc"
        or else Text = "GMT" or else Text = "gmt"
      then
         return True;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         Negative := Text (Start) = '-';
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = ':' then
            Colon_Count := Colon_Count + 1;
            if Colon_Count > 2 then
               return False;
            elsif First_Sep = 0 then
               First_Sep := Index;
            else
               Second_Sep := Index;
            end if;
         elsif Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      declare
         Digit_Length : constant Natural := Text'Last - Start + 1;
         Hours_Text   : constant String :=
           (if First_Sep /= 0 then Text (Start .. First_Sep - 1)
            elsif Digit_Length = 1 or else Digit_Length = 2
            then Text (Start .. Text'Last)
            elsif Digit_Length = 3 then Text (Start .. Start)
            elsif Digit_Length = 4 then Text (Start .. Start + 1)
            else "");
         Mins_Text    : constant String :=
           (if First_Sep /= 0 and then Second_Sep = 0
            then Text (First_Sep + 1 .. Text'Last)
            elsif First_Sep /= 0
            then Text (First_Sep + 1 .. Second_Sep - 1)
            elsif Digit_Length = 1 or else Digit_Length = 2 then "00"
            elsif Digit_Length = 3 then Text (Start + 1 .. Text'Last)
            elsif Digit_Length = 4 then Text (Start + 2 .. Text'Last)
            else "");
         Seconds_Text : constant String :=
           (if Second_Sep = 0 then "00"
            else Text (Second_Sep + 1 .. Text'Last));
      begin
         if Hours_Text'Length = 0
           or else Mins_Text'Length = 0
           or else Seconds_Text'Length = 0
           or else Hours_Text'Length > 2
           or else Mins_Text'Length /= 2
           or else Seconds_Text'Length /= 2
           or else not In_Integer_Range (Hours_Text)
           or else not In_Integer_Range (Mins_Text)
           or else not In_Integer_Range (Seconds_Text)
         then
            return False;
         end if;

         declare
            Hours : constant Integer := Integer'Value (Hours_Text);
            Mins  : constant Integer := Integer'Value (Mins_Text);
            Secs  : constant Integer := Integer'Value (Seconds_Text);
         begin
            if Hours not in 0 .. 23
              or else Mins not in 0 .. 59
              or else Secs not in 0 .. 59
            then
               return False;
            end if;

            Seconds := Hours * 3_600 + Mins * 60 + Secs;
            if Negative then
               Seconds := -Seconds;
            end if;
            return True;
         end;
      end;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Offset_Seconds;

   function Parse_Offset_Minutes (Text : String; Minutes : out Integer)
                                  return Boolean is
      Seconds : Integer;
   begin
      Minutes := 0;
      if not Parse_Offset_Seconds (Text, Seconds)
        or else Seconds mod 60 /= 0
      then
         return False;
      end if;

      Minutes := Seconds / 60;
      return True;
   end Parse_Offset_Minutes;

   function Is_Leap_Year (Year : Natural) return Boolean is
   begin
      return (Year mod 4 = 0 and then Year mod 100 /= 0)
        or else Year mod 400 = 0;
   end Is_Leap_Year;

   function Days_In_Month (Year : Natural; Month : Natural) return Natural is
   begin
      case Month is
         when 1 | 3 | 5 | 7 | 8 | 10 | 12 =>
            return 31;
         when 4 | 6 | 9 | 11 =>
            return 30;
         when 2 =>
            return (if Is_Leap_Year (Year) then 29 else 28);
         when others =>
            return 0;
      end case;
   end Days_In_Month;

   function Two_Digits (Text : String; Pos : Positive) return Natural is
   begin
      return
        (Character'Pos (Text (Pos)) - Character'Pos ('0')) * 10
        + Character'Pos (Text (Pos + 1)) - Character'Pos ('0');
   end Two_Digits;

   function Four_Digits (Text : String; Pos : Positive) return Natural is
   begin
      return Two_Digits (Text, Pos) * 100 + Two_Digits (Text, Pos + 2);
   end Four_Digits;

   function Valid_UTC_Fields
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural)
      return Boolean
   is
   begin
      return Year in 1 .. 9999
        and then Month in 1 .. 12
        and then Day in 1 .. Days_In_Month (Year, Month)
        and then Hour in 0 .. 23
        and then Minute in 0 .. 59
        and then Second in 0 .. 59;
   end Valid_UTC_Fields;

   function UTC_Key
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural)
      return String
   is
      Result : String (1 .. 14);

      procedure Put_2 (Pos : Positive; Value : Natural) is
      begin
         Result (Pos) := Character'Val
           (Character'Pos ('0') + (Value / 10) mod 10);
         Result (Pos + 1) := Character'Val
           (Character'Pos ('0') + Value mod 10);
      end Put_2;

      procedure Put_4 (Pos : Positive; Value : Natural) is
      begin
         Result (Pos) := Character'Val
           (Character'Pos ('0') + (Value / 1000) mod 10);
         Result (Pos + 1) := Character'Val
           (Character'Pos ('0') + (Value / 100) mod 10);
         Result (Pos + 2) := Character'Val
           (Character'Pos ('0') + (Value / 10) mod 10);
         Result (Pos + 3) := Character'Val
           (Character'Pos ('0') + Value mod 10);
      end Put_4;
   begin
      Put_4 (1, Year);
      Put_2 (5, Month);
      Put_2 (7, Day);
      Put_2 (9, Hour);
      Put_2 (11, Minute);
      Put_2 (13, Second);
      return Result;
   end UTC_Key;

   function Adjusted_UTC_Key
     (Year           : Natural;
      Month          : Natural;
      Day            : Natural;
      Hour           : Natural;
      Minute         : Natural;
      Second         : Natural;
      Offset_Seconds : Integer)
      return String
   is
      Y     : Natural := Year;
      M     : Natural := Month;
      D     : Natural := Day;
      Total : Integer :=
        Integer (Hour) * 3_600
        + Integer (Minute) * 60
        + Integer (Second)
        - Offset_Seconds;

      procedure Step_Back is
      begin
         if D > 1 then
            D := D - 1;
         elsif M > 1 then
            M := M - 1;
            D := Days_In_Month (Y, M);
         elsif Y > 1 then
            Y := Y - 1;
            M := 12;
            D := 31;
         end if;
      end Step_Back;

      procedure Step_Forward is
      begin
         if D < Days_In_Month (Y, M) then
            D := D + 1;
         elsif M < 12 then
            M := M + 1;
            D := 1;
         else
            Y := Y + 1;
            M := 1;
            D := 1;
         end if;
      end Step_Forward;
   begin
      if not Valid_UTC_Fields (Year, Month, Day, Hour, Minute, Second) then
         return "";
      end if;

      while Total < 0 loop
         if Y = 1 and then M = 1 and then D = 1 then
            return "";
         end if;
         Step_Back;
         Total := Total + 86_400;
      end loop;

      while Total >= 86_400 loop
         if Y = 9999 and then M = 12 and then D = 31 then
            return "";
         end if;
         Step_Forward;
         Total := Total - 86_400;
      end loop;

      return UTC_Key
        (Y, M, D,
         Natural (Total / 3_600),
         Natural ((Total mod 3_600) / 60),
         Natural (Total mod 60));
   exception
      when Constraint_Error =>
         return "";
   end Adjusted_UTC_Key;

   function Is_UTC_Key_Text (Text : String) return Boolean is
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
   begin
      if Text'Length /= 14 then
         return False;
      end if;

      for Index in Text'Range loop
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      Year := Four_Digits (Text, Text'First);
      Month := Two_Digits (Text, Text'First + 4);
      Day := Two_Digits (Text, Text'First + 6);
      Hour := Two_Digits (Text, Text'First + 8);
      Minute := Two_Digits (Text, Text'First + 10);
      Second := Two_Digits (Text, Text'First + 12);
      return Valid_UTC_Fields (Year, Month, Day, Hour, Minute, Second);
   exception
      when Constraint_Error =>
         return False;
   end Is_UTC_Key_Text;

   function Parse_UTC_Key (Text : String; Key : out String) return Boolean is
   begin
      Key := [others => '0'];

      if Text'Length = 14 and then Is_UTC_Key_Text (Text) then
         Key := Text;
         return True;
      elsif Text'Length in 17 .. 20
        and then Text (Text'First + 4) = '-'
        and then Text (Text'First + 7) = '-'
        and then (Text (Text'First + 10) = 'T'
                  or else Text (Text'First + 10) = 't')
        and then Text (Text'First + 13) = ':'
        and then Text (Text'Last) = 'Z'
      then
         declare
            Year   : Natural;
            Month  : Natural;
            Day    : Natural;
            Hour   : Natural;
            Minute : Natural;
            Second : Natural := 0;
         begin
            if Text'Length = 17 then
               null;
            elsif Text'Length = 20 and then Text (Text'First + 16) = ':' then
               Second := Two_Digits (Text, Text'First + 17);
            else
               return False;
            end if;

            for Index in Text'First .. Text'Last loop
               if Index = Text'First + 4
                 or else Index = Text'First + 7
                 or else Index = Text'First + 10
                 or else Index = Text'First + 13
                 or else (Text'Length = 20 and then Index = Text'First + 16)
                 or else Index = Text'Last
               then
                  null;
               elsif Text (Index) not in '0' .. '9' then
                  return False;
               end if;
            end loop;

            Year := Four_Digits (Text, Text'First);
            Month := Two_Digits (Text, Text'First + 5);
            Day := Two_Digits (Text, Text'First + 8);
            Hour := Two_Digits (Text, Text'First + 11);
            Minute := Two_Digits (Text, Text'First + 14);
            if Valid_UTC_Fields (Year, Month, Day, Hour, Minute, Second) then
               Key := UTC_Key (Year, Month, Day, Hour, Minute, Second);
               return True;
            end if;
         end;
      end if;

      return False;
   exception
      when Constraint_Error =>
         return False;
   end Parse_UTC_Key;

   function In_Long_Long_Integer_Range (Text : String) return Boolean is
      Dummy : Long_Long_Integer;
   begin
      if not Is_Integer_Text (Text) then
         return False;
      end if;

      Dummy := Long_Long_Integer'Value (Text);
      return True;
   exception
      when Constraint_Error =>
         return False;
   end In_Long_Long_Integer_Range;

   function Is_Plural_Category (Text : String) return Boolean is
   begin
      return Text = "zero"
        or else Text = "one"
        or else Text = "two"
        or else Text = "few"
        or else Text = "many"
        or else Text = "other";
   end Is_Plural_Category;

   function Is_Bounded_Plural_Rule_Text (Text : String) return Boolean is
      Sample : constant Natural := Ada.Strings.Fixed.Index (Text, "@");
      Rule   : constant String :=
        (if Sample = 0 then Text
         elsif Sample = Text'First then ""
         else Text (Text'First .. Sample - 1));
   begin
      if Rule'Length = 0 or else Rule'Length > 240 then
         return False;
      end if;

      for Ch of Rule loop
         if not (Ch in 'a' .. 'z'
                 or else Ch in 'A' .. 'Z'
                 or else Ch in '0' .. '9'
                 or else Ch = ' '
                 or else Ch = ASCII.HT
                 or else Ch = '%'
                 or else Ch = '='
                 or else Ch = '!'
                 or else Ch = '.'
                 or else Ch = ','
                 or else Ch = '-')
         then
            return False;
         end if;
      end loop;

      return True;
   end Is_Bounded_Plural_Rule_Text;

   function Is_Plural_Rule_Family
     (Kind   : String;
      Family : String)
      return Boolean
   is
   begin
      if Kind = "cardinal" then
         return Family = "other"
           or else Family = "n-is-1"
           or else Family = "one-is-1"
           or else Family = "one-is-0-or-1"
           or else Family = "i-0-or-n-1"
           or else Family = "n-one-two"
           or else Family = "n-is-1-compact-many"
           or else Family = "i-0-1-compact-many"
           or else Family = "i-0-to-1-compact-many"
           or else Family = "i-1-v0-compact-many"
           or else Family = "ru"
           or else Family = "pl"
           or else Family = "cs"
           or else Family = "ar"
           or else Family = "ro"
           or else Family = "lt"
           or else Family = "sl"
           or else Family = "sr"
           or else Family = "cy"
           or else Family = "zero-one"
           or else Family = "ceb"
           or else Family = "ff"
           or else Family = "dsb"
           or else Family = "lv"
           or else Family = "be"
           or else Family = "br"
           or else Family = "da"
           or else Family = "ga"
           or else Family = "gd"
           or else Family = "gv"
           or else Family = "he"
           or else Family = "is"
           or else Family = "kw"
           or else Family = "lag"
           or else Family = "mk"
           or else Family = "mt"
           or else Family = "shi"
           or else Family = "si"
           or else Family = "tzm";
      elsif Kind = "ordinal" then
         return Family = "other"
           or else Family = "en-ordinal"
           or else Family = "n-one-ordinal"
           or else Family = "it-ordinal"
           or else Family = "indic-ordinal"
           or else Family = "hi-ordinal"
           or else Family = "az-ordinal"
           or else Family = "be-ordinal"
           or else Family = "blo-ordinal"
           or else Family = "ca-ordinal"
           or else Family = "cy-ordinal"
           or else Family = "gd-ordinal"
           or else Family = "hu-ordinal"
           or else Family = "ka-ordinal"
           or else Family = "kk-ordinal"
           or else Family = "kw-ordinal"
           or else Family = "lij-ordinal"
           or else Family = "mk-ordinal"
           or else Family = "mr-ordinal"
           or else Family = "ne-ordinal"
           or else Family = "or-ordinal"
           or else Family = "sq-ordinal"
           or else Family = "sv-ordinal"
           or else Family = "tk-ordinal"
           or else Family = "uk-ordinal";
      else
         return False;
      end if;
   end Is_Plural_Rule_Family;

   procedure Add_Error
     (Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Source_Name : String;
      Line        : Natural;
      Message     : String)
   is
   begin
      I18N.Diagnostics.Add
        (List    => Diagnostics,
         Kind    => I18N.Diagnostics.Parse_Error,
         Message => Message & " in " & Source_Name & " at line"
                    & Natural'Image (Line));
   end Add_Error;

   procedure Store
     (Map   : in out String_Maps.Map;
      Key   : String;
      Value : String)
   is
   begin
      if Map.Contains (Key) then
         Map.Replace (Key, Value);
      else
         Map.Insert (Key, Value);
      end if;
   end Store;

   function Is_CLDR_Count_Name (Value : String) return Boolean is
   begin
      return Value = "zero"
        or else Value = "one"
        or else Value = "two"
        or else Value = "few"
        or else Value = "many"
        or else Value = "other";
   end Is_CLDR_Count_Name;

   function Is_Spellout_Kind (Value : String) return Boolean is
   begin
      return Value = "cardinal"
        or else Value = "ordinal"
        or else Value = "decimal_separator";
   end Is_Spellout_Kind;

   function Is_RBNF_Plural_Affix_Pattern (Value : String) return Boolean is
      Index : Natural := Value'First;

      function Is_Space (C : Character) return Boolean is
      begin
         return C = ' ' or else C = ASCII.HT;
      end Is_Space;

      function Trimmed (Text : String) return String is
         First : Natural := Text'First;
         Last  : Natural := Text'Last;
      begin
         while First <= Last and then Is_Space (Text (First)) loop
            First := First + 1;
         end loop;
         while Last >= First and then Is_Space (Text (Last)) loop
            Last := Last - 1;
         end loop;
         if Last < First then
            return "";
         end if;
         return Text (First .. Last);
      end Trimmed;

      function Matching_Close (Open_Pos : Natural) return Natural is
         Pos   : Natural := Open_Pos + 2;
         Depth : Natural := 0;
      begin
         while Pos < Value'Last loop
            if Value (Pos) = '{' then
               Depth := Depth + 1;
            elsif Value (Pos) = '}' then
               if Depth = 0 then
                  return 0;
               end if;
               Depth := Depth - 1;
            elsif Value (Pos) = ')' and then Value (Pos + 1) = '$'
              and then Depth = 0
            then
               return Pos;
            end if;
            Pos := Pos + 1;
         end loop;
         return 0;
      end Matching_Close;

      function Valid_Body (Text : String) return Boolean is
         Comma     : Natural := 0;
         Branch    : Natural;
         Open      : Natural;
         Close     : Natural;
         Has_Other : Boolean := False;
      begin
         for Pos in Text'Range loop
            if Text (Pos) = ',' then
               Comma := Pos;
               exit;
            end if;
         end loop;

         if Comma = 0 then
            return False;
         end if;

         declare
            Selector : constant String := Trimmed (Text (Text'First .. Comma - 1));
         begin
            if Selector /= "cardinal" and then Selector /= "ordinal" then
               return False;
            end if;
         end;

         Branch := Comma + 1;
         while Branch <= Text'Last loop
            while Branch <= Text'Last and then Is_Space (Text (Branch)) loop
               Branch := Branch + 1;
            end loop;
            exit when Branch > Text'Last;

            Open := Branch;
            while Open <= Text'Last
              and then not Is_Space (Text (Open))
              and then Text (Open) /= '{'
            loop
               Open := Open + 1;
            end loop;

            declare
               Name : constant String := Trimmed (Text (Branch .. Open - 1));
            begin
               if not Is_CLDR_Count_Name (Name) then
                  return False;
               end if;
               if Name = "other" then
                  Has_Other := True;
               end if;
            end;

            while Open <= Text'Last and then Is_Space (Text (Open)) loop
               Open := Open + 1;
            end loop;
            if Open > Text'Last or else Text (Open) /= '{' then
               return False;
            end if;

            Close := Open + 1;
            while Close <= Text'Last and then Text (Close) /= '}' loop
               Close := Close + 1;
            end loop;
            if Close > Text'Last then
               return False;
            end if;

            Branch := Close + 1;
         end loop;

         return Has_Other;
      end Valid_Body;
   begin
      while Index <= Value'Last loop
         if Index < Value'Last
           and then Value (Index) = '$'
           and then Value (Index + 1) = '('
         then
            declare
               Close : constant Natural := Matching_Close (Index);
            begin
               if Close = 0
                 or else not Valid_Body (Value (Index + 2 .. Close - 1))
               then
                  return False;
               end if;
               Index := Close + 2;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;

      return True;
   end Is_RBNF_Plural_Affix_Pattern;

   function Is_RBNF_Rule_Pattern (Value : String) return Boolean is
      Left_Arrow  : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#90#);
      Right_Arrow : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#92#);
   begin
      return Value'Length > 0
        and then Is_RBNF_Plural_Affix_Pattern (Value)
        and then (Ada.Strings.Fixed.Index (Value, "<<") /= 0
                  or else Ada.Strings.Fixed.Index (Value, ">>") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "<C<") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "<O<") /= 0
                  or else Ada.Strings.Fixed.Index (Value, ">C>") /= 0
                  or else Ada.Strings.Fixed.Index (Value, ">O>") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "=%") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "==") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "=C=") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "=O=") /= 0
                  or else Ada.Strings.Fixed.Index (Value, "$(") /= 0
                  or else Ada.Strings.Fixed.Index
                    (Value, Left_Arrow & Left_Arrow) /= 0
                  or else Ada.Strings.Fixed.Index
                    (Value, Right_Arrow & Right_Arrow) /= 0
                  or else Ada.Strings.Fixed.Index (Value, "[") /= 0);
   end Is_RBNF_Rule_Pattern;

   function Normalize_Spellout_Kind (Raw : String) return String;

   function RBNF_Substitution_Target (Raw : String) return Character is
      Normal : constant String := Normalize_Spellout_Kind (Raw);
   begin
      if Normal = "cardinal" then
         return 'C';
      elsif Normal = "ordinal" then
         return 'O';
      else
         return Character'Val (0);
      end if;
   end RBNF_Substitution_Target;

   function Normalize_RBNF_Pattern_Tokens (Value : String) return String is
      Left_Arrow  : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#90#);
      Right_Arrow : constant String :=
        Character'Val (16#E2#) & Character'Val (16#86#)
        & Character'Val (16#92#);
      Result      : Unbounded_String := Null_Unbounded_String;
      Index       : Natural := Value'First;

      function Named_Substitution_Close
        (Open_Arrow : String;
         Start      : Natural)
         return Natural
      is
         Scan : Natural := Start + Open_Arrow'Length + 1;
      begin
         if Start + Open_Arrow'Length > Value'Last
           or else Value (Start + Open_Arrow'Length) /= '%'
         then
            return 0;
         end if;

         while Scan + Open_Arrow'Length - 1 <= Value'Last loop
            if Value (Scan .. Scan + Open_Arrow'Length - 1) = Open_Arrow then
               if Scan = Start + Open_Arrow'Length + 1 then
                  return 0;
               else
                  return Scan;
               end if;
            end if;
            Scan := Scan + 1;
         end loop;

         return 0;
      end Named_Substitution_Close;

      procedure Append_Named_Substitution
        (Open_Token   : String;
         Close_Token  : String;
         Start        : Natural;
         Default_Text : String;
         Prefix       : Character;
         Suffix       : Character;
         Consumed     : out Boolean)
      is
         Close : constant Natural :=
           Named_Substitution_Close (Open_Token, Start);
      begin
         Consumed := False;
         if Close /= 0 then
            declare
               Raw_Name : constant String :=
                 Value
                   (Start + Open_Token'Length + 1 .. Close - 1);
               Target   : constant Character :=
                 RBNF_Substitution_Target (Raw_Name);
            begin
               if Target = Character'Val (0) then
                  Append (Result, Default_Text);
               else
                  Append (Result, Prefix);
                  Append (Result, Target);
                  Append (Result, Suffix);
               end if;
            end;
            Index := Close + Close_Token'Length;
            Consumed := True;
         end if;
      end Append_Named_Substitution;
   begin
      while Index <= Value'Last loop
         if Index + (Left_Arrow'Length * 2) - 1 <= Value'Last
           and then Value
             (Index .. Index + (Left_Arrow'Length * 2) - 1)
             = Left_Arrow & Left_Arrow
         then
            Append (Result, "<<");
            Index := Index + Left_Arrow'Length * 2;
         elsif Index + Left_Arrow'Length - 1 <= Value'Last
           and then Value (Index .. Index + Left_Arrow'Length - 1)
                    = Left_Arrow
         then
            declare
               Consumed : Boolean := False;
            begin
               Append_Named_Substitution
                 (Left_Arrow, Left_Arrow, Index, "<<", '<', '<', Consumed);
               if Consumed then
                  null;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         elsif Value (Index) = '<' then
            declare
               Consumed : Boolean := False;
            begin
               Append_Named_Substitution
                 ("<", "<", Index, "<<", '<', '<', Consumed);
               if Consumed then
                  null;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         elsif Index + (Right_Arrow'Length * 3) - 1 <= Value'Last
           and then Value
             (Index .. Index + (Right_Arrow'Length * 3) - 1)
             = Right_Arrow & Right_Arrow & Right_Arrow
         then
            Append (Result, ">>>");
            Index := Index + Right_Arrow'Length * 3;
         elsif Index + (Right_Arrow'Length * 2) - 1 <= Value'Last
           and then Value
             (Index .. Index + (Right_Arrow'Length * 2) - 1)
             = Right_Arrow & Right_Arrow
         then
            Append (Result, ">>");
            Index := Index + Right_Arrow'Length * 2;
         elsif Index + Right_Arrow'Length - 1 <= Value'Last
           and then Value (Index .. Index + Right_Arrow'Length - 1)
                    = Right_Arrow
         then
            declare
               Consumed : Boolean := False;
            begin
               Append_Named_Substitution
                 (Right_Arrow, Right_Arrow, Index, ">>", '>', '>', Consumed);
               if Consumed then
                  null;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         elsif Value (Index) = '>' then
            declare
               Consumed : Boolean := False;
            begin
               Append_Named_Substitution
                 (">", ">", Index, ">>", '>', '>', Consumed);
               if Consumed then
                  null;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         elsif Index < Value'Last
           and then Value (Index) = '='
           and then Value (Index + 1) = '='
         then
            Append (Result, "==");
            Index := Index + 2;
         elsif Value (Index) = '=' then
            declare
               Consumed : Boolean := False;
            begin
               Append_Named_Substitution
                 ("=", "=", Index, "==", '=', '=', Consumed);
               if Consumed then
                  null;
               else
                  Append (Result, Value (Index));
                  Index := Index + 1;
               end if;
            end;
         else
            Append (Result, Value (Index));
            Index := Index + 1;
         end if;
      end loop;

      return To_String (Result);
   end Normalize_RBNF_Pattern_Tokens;

   function Normalize_RBNF_Rule_Text (Value : String) return String is
      Trimmed_Value : constant String := Trimmed (Value);
   begin
      if Trimmed_Value'Length > 0
        and then Trimmed_Value (Trimmed_Value'Last) = ';'
      then
         if Trimmed_Value'Length = 1 then
            return "";
         else
            return Trimmed
              (Trimmed_Value
                 (Trimmed_Value'First .. Trimmed_Value'Last - 1));
         end if;
      else
         return Trimmed_Value;
      end if;
   end Normalize_RBNF_Rule_Text;

   function Normalize_RBNF_Exact_Text (Value : String) return String is
   begin
      return Normalize_RBNF_Rule_Text (Value);
   end Normalize_RBNF_Exact_Text;

   function RBNF_Rule_Descriptor_Values
     (Descriptor : String;
      Base       : out Natural;
      Divisor    : out Natural)
      return Boolean
   is
      Body_Last      : Natural := Descriptor'Last;
      Marker_Count   : Natural := 0;

      function Default_Divisor (Rule_Base : Natural) return Natural is
         Result : Natural := 1;
      begin
         if Rule_Base = 0 then
            return 0;
         end if;

         while Result <= Rule_Base / 10 loop
            Result := Result * 10;
         end loop;

         return Result;
      end Default_Divisor;

      function Ungrouped_Positive_Text (Text : String) return String is
         Result : String (1 .. Text'Length);
         Last   : Natural := 0;
         Index  : Natural := Text'First;
      begin
         if Text'Length = 0 then
            return "";
         end if;

         while Index <= Text'Last loop
            if Text (Index) = ',' then
               return "";
            end if;

            if Text (Index) not in '0' .. '9' then
               return "";
            end if;

            Last := Last + 1;
            Result (Last) := Text (Index);
            Index := Index + 1;

            if Index <= Text'Last and then Text (Index) = ',' then
               if Last > 3 then
                  return "";
               end if;

               Index := Index + 1;
               while Index <= Text'Last loop
                  for Offset in 0 .. 2 loop
                     if Index + Offset > Text'Last
                       or else Text (Index + Offset) not in '0' .. '9'
                     then
                        return "";
                     end if;
                  end loop;

                  Result (Last + 1 .. Last + 3) :=
                    Text (Index .. Index + 2);
                  Last := Last + 3;
                  Index := Index + 3;

                  if Index <= Text'Last then
                     if Text (Index) /= ',' then
                        return "";
                     end if;
                     Index := Index + 1;
                  end if;
               end loop;
            end if;
         end loop;

         return Result (1 .. Last);
      end Ungrouped_Positive_Text;

      function Valid_Positive (Text : String; Value : out Natural)
                               return Boolean
      is
         Clean_Text : constant String := Ungrouped_Positive_Text (Text);
      begin
         if Clean_Text = "" or else not In_Integer_Range (Clean_Text) then
            Value := 0;
            return False;
         end if;

         declare
            Parsed : constant Integer := Integer'Value (Clean_Text);
         begin
            if Parsed <= 0 or else Parsed > 999_999_999 then
               Value := 0;
               return False;
            else
               Value := Natural (Parsed);
               return True;
            end if;
         end;
      end Valid_Positive;

      function Apply_Divisor_Markers
        (Parsed_Base    : Natural;
         Parsed_Divisor : Natural)
         return Boolean
      is
         Effective : Natural :=
           (if Parsed_Divisor = 0
            then Default_Divisor (Parsed_Base)
            else Parsed_Divisor);
      begin
         if Marker_Count = 0 then
            Base := Parsed_Base;
            Divisor := Parsed_Divisor;
            return True;
         end if;

         for Marker in 1 .. Marker_Count loop
            if Effective < 10 then
               return False;
            end if;
            Effective := Effective / 10;
         end loop;

         if Effective = 0 or else Effective > Parsed_Base then
            return False;
         end if;

         Base := Parsed_Base;
         Divisor := Effective;
         return True;
      end Apply_Divisor_Markers;
   begin
      Base := 0;
      Divisor := 0;

      while Body_Last >= Descriptor'First
        and then Descriptor (Body_Last) = '>'
      loop
         Marker_Count := Marker_Count + 1;
         Body_Last := Body_Last - 1;
      end loop;

      if Body_Last < Descriptor'First then
         return False;
      end if;

      declare
         Descriptor_Body : constant String :=
           Descriptor (Descriptor'First .. Body_Last);
         Slash : constant Natural :=
           Ada.Strings.Fixed.Index (Descriptor_Body, "/");
      begin
         if Slash = 0 then
            declare
               Parsed_Base : Natural := 0;
            begin
               return Valid_Positive (Descriptor_Body, Parsed_Base)
                 and then Apply_Divisor_Markers (Parsed_Base, 0);
            end;
         elsif Slash = Descriptor_Body'First
           or else Slash = Descriptor_Body'Last
           or else Ada.Strings.Fixed.Index
             (Descriptor_Body (Slash + 1 .. Descriptor_Body'Last), "/") /= 0
         then
            return False;
         else
            declare
               Parsed_Base    : Natural := 0;
               Parsed_Divisor : Natural := 0;
            begin
               if Valid_Positive
                    (Descriptor_Body
                       (Descriptor_Body'First .. Slash - 1),
                     Parsed_Base)
                 and then Valid_Positive
                    (Descriptor_Body
                       (Slash + 1 .. Descriptor_Body'Last),
                     Parsed_Divisor)
                 and then Parsed_Divisor <= Parsed_Base
               then
                  return Apply_Divisor_Markers
                    (Parsed_Base, Parsed_Divisor);
               else
                  return False;
               end if;
            end;
         end if;
      end;
   end RBNF_Rule_Descriptor_Values;

   function RBNF_Rule_Descriptor_Text
     (Base    : Natural;
      Divisor : Natural)
      return String
   is
   begin
      if Divisor = 0 then
         return Natural_Text (Base);
      else
         return Natural_Text (Base) & "/" & Natural_Text (Divisor);
      end if;
   end RBNF_Rule_Descriptor_Text;

   function Normalize_Spellout_Kind (Raw : String) return String is
      First : Natural := Raw'First;
   begin
      while First <= Raw'Last and then Raw (First) = '%' loop
         First := First + 1;
      end loop;

      if First > Raw'Last then
         return Raw;
      end if;

      declare
         Name : constant String := Raw (First .. Raw'Last);
      begin
         if Name = "spellout-cardinal"
           or else Name = "spellout"
           or else Name = "spellout-numbering"
           or else Name = "spellout-numbering-year"
           or else Name = "spellout-year"
           or else Name = "spellout-numbering-verbose"
           or else Name = "spellout-numbering-financial"
           or else Name = "spellout-cardinal-verbose"
           or else Name = "spellout-cardinal-masculine"
           or else Name = "spellout-cardinal-feminine"
           or else Name = "spellout-cardinal-neuter"
         then
            return "cardinal";
         elsif Name = "spellout-ordinal"
           or else Name = "spellout-ordinal-verbose"
           or else Name = "spellout-ordinal-masculine"
           or else Name = "spellout-ordinal-feminine"
           or else Name = "spellout-ordinal-neuter"
           or else Name = "ordinal"
           or else Name = "ordinal-words"
         then
            return "ordinal";
         elsif Name = "decimal"
           or else Name = "decimal-separator"
           or else Name = "decimal_separator"
         then
            return "decimal_separator";
         else
            return Name;
         end if;
      end;
   end Normalize_Spellout_Kind;

   function Normalize_Relative_Unit (Raw : String) return String is
   begin
      if Raw = "duration-second" then
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
      elsif Raw = "duration-quarter" then
         return "quarter";
      elsif Raw = "duration-year" then
         return "year";
      else
         return Raw;
      end if;
   end Normalize_Relative_Unit;

   function Is_Supported_Relative_Unit (Unit : String) return Boolean is
   begin
      return Unit = "second"
        or else Unit = "minute"
        or else Unit = "hour"
        or else Unit = "day"
        or else Unit = "week"
        or else Unit = "month"
        or else Unit = "quarter"
        or else Unit = "year";
   end Is_Supported_Relative_Unit;

   function Is_Day_Period_Name (Value : String) return Boolean is
   begin
      return Value = "am"
        or else Value = "pm"
        or else Value = "noon"
        or else Value = "midnight"
        or else Value = "morning1"
        or else Value = "afternoon1"
        or else Value = "evening1"
        or else Value = "night1";
   end Is_Day_Period_Name;

   function Is_HH_MM (Value : String) return Boolean is
      Hour : Natural;
      Minute : Natural;
   begin
      if Value'Length /= 5
        or else Value (Value'First + 2) /= ':'
      then
         return False;
      end if;

      for Index in Value'Range loop
         if Index /= Value'First + 2
           and then Value (Index) not in '0' .. '9'
         then
            return False;
         end if;
      end loop;

      Hour :=
        (Character'Pos (Value (Value'First)) - Character'Pos ('0')) * 10
        + Character'Pos (Value (Value'First + 1)) - Character'Pos ('0');
      Minute :=
        (Character'Pos (Value (Value'First + 3)) - Character'Pos ('0')) * 10
        + Character'Pos (Value (Value'First + 4)) - Character'Pos ('0');

      return Hour <= 24
        and then Minute <= 59
        and then (if Hour = 24 then Minute = 0 else True);
   end Is_HH_MM;

   function Is_Day_Period_Range (Value : String) return Boolean is
      Sep : Natural := 0;
   begin
      for Index in Value'Range loop
         if Value (Index) = '-' then
            if Sep /= 0 then
               return False;
            end if;
            Sep := Index;
         end if;
      end loop;

      return Sep > Value'First
        and then Sep < Value'Last
        and then Is_HH_MM (Value (Value'First .. Sep - 1))
        and then Is_HH_MM (Value (Sep + 1 .. Value'Last))
        and then Value (Value'First .. Sep - 1)
                 /= Value (Sep + 1 .. Value'Last);
   end Is_Day_Period_Range;

   function Valid_Locale_Field (Field : String; Value : String) return Boolean is
   begin
      if Field = "decimal_separator"
        or else Field = "group_separator"
        or else Field = "number_percent_suffix"
        or else Field = "number_plus_sign"
        or else Field = "number_minus_sign"
        or else Field = "number_accounting_prefix"
        or else Field = "number_accounting_suffix"
        or else Field = "number_permille_suffix"
        or else Field = "number_exponent_separator"
        or else Field = "date_style.default"
        or else Field = "date_style.short"
        or else Field = "date_style.medium"
        or else Field = "date_style.long"
        or else Field = "date_style.full"
        or else Field = "time_style.default"
        or else Field = "time_style.short"
        or else Field = "time_style.medium"
        or else Field = "time_style.long"
        or else Field = "time_style.full"
        or else Field = "date_time_style_separator"
        or else Field = "date_time_field_separator"
        or else Field = "currency_amount_separator"
        or else Field = "currency_accounting_prefix"
        or else Field = "currency_accounting_suffix"
        or else Field = "unit_value_separator"
        or else Field = "per_unit_separator"
        or else Field = "unit_short_per_separator"
        or else Field = "list_final_separator"
        or else Field = "list_pair_separator"
        or else Field = "list_start_separator"
        or else Field = "list_middle_separator"
        or else Field = "list_item_separator"
        or else Field = "list_or_final_separator"
        or else Field = "list_or_pair_separator"
        or else Field = "list_or_start_separator"
        or else Field = "list_or_middle_separator"
        or else Field = "list_or_item_separator"
        or else Field = "list_unit_final_separator"
        or else Field = "list_unit_pair_separator"
        or else Field = "list_unit_start_separator"
        or else Field = "list_unit_middle_separator"
        or else Field = "list_unit_item_separator"
        or else Field = "gmt_offset_prefix"
        or else Field = "timezone_utc_designator"
        or else Field = "timezone_offset_separator"
        or else Field = "timezone_location_pattern_standard"
        or else Field = "timezone_location_pattern_daylight"
        or else Field = "default_timezone"
      then
         return Value'Length > 0;
      elsif Field = "default_calendar" then
         return Value = "gregory"
           or else Value = "gregorian"
           or else Value = "iso8601"
           or else Value = "buddhist"
           or else Value = "japanese"
           or else Value = "julian"
           or else Value = "roc"
           or else Value = "coptic"
           or else Value = "ethiopic"
           or else Value = "ethioaa"
           or else Value = "ethiopic-amete-alem"
           or else Value = "islamic"
           or else Value = "islamic-civil"
           or else Value = "islamic-tbla"
           or else Value = "islamicc"
           or else Value = "indian"
           or else Value = "persian"
           or else Value = "hebrew";
      elsif Field = "default_numbering_system" then
         return Is_Supported_Numbering_System (Value);
      elsif Field = "default_hour_cycle" then
         return Value = "h11"
           or else Value = "h12"
           or else Value = "h23"
           or else Value = "h24";
      elsif Field = "first_day_of_week" then
         return Value = "sun"
           or else Value = "mon"
           or else Value = "tue"
           or else Value = "wed"
           or else Value = "thu"
           or else Value = "fri"
           or else Value = "sat";
      elsif Field = "first_week_min_days" then
         return Value'Length = 1 and then Value (Value'First) in '1' .. '7';
      elsif Field = "uses_indian_grouping"
        or else Field = "uses_day_month_year"
        or else Field = "currency_symbol_first"
      then
         return Value = "true" or else Value = "false";
      end if;

      for Index in 0 .. 9 loop
         if Field = "digit." & Natural_Text (Index) then
            return Value'Length > 0;
         end if;
      end loop;

      for Index in 1 .. 12 loop
         if Field = "month." & Natural_Text (Index)
           or else Field = "month_short." & Natural_Text (Index)
           or else Field = "month_narrow." & Natural_Text (Index)
           or else Field = "month_standalone." & Natural_Text (Index)
           or else Field = "month_standalone_short." & Natural_Text (Index)
           or else Field = "month_standalone_narrow." & Natural_Text (Index)
         then
            return Value'Length > 0;
         end if;
      end loop;

      for Index in 1 .. 4 loop
         if Field = "quarter." & Natural_Text (Index)
           or else Field = "quarter_short." & Natural_Text (Index)
           or else Field = "quarter_narrow." & Natural_Text (Index)
           or else Field = "quarter_standalone." & Natural_Text (Index)
           or else Field = "quarter_standalone_short." & Natural_Text (Index)
           or else Field = "quarter_standalone_narrow." & Natural_Text (Index)
         then
            return Value'Length > 0;
         end if;
      end loop;

      for Index in 0 .. 6 loop
         if Field = "weekday." & Natural_Text (Index)
           or else Field = "weekday_short." & Natural_Text (Index)
           or else Field = "weekday_narrow." & Natural_Text (Index)
           or else Field = "weekday_standalone." & Natural_Text (Index)
           or else Field = "weekday_standalone_short." & Natural_Text (Index)
           or else Field = "weekday_standalone_narrow." & Natural_Text (Index)
         then
            return Value'Length > 0;
         end if;
      end loop;

      if Starts_With (Field, "day_period.")
        or else Starts_With (Field, "day_period_wide.")
        or else Starts_With (Field, "day_period_narrow.")
      then
         declare
            Prefix_Length : constant Natural :=
              (if Starts_With (Field, "day_period_wide.")
               then 16
               elsif Starts_With (Field, "day_period_narrow.")
               then 18
               else 11);
            Name : constant String :=
              Field (Field'First + Prefix_Length .. Field'Last);
         begin
            return Value'Length > 0
              and then Is_Day_Period_Name (Name);
         end;
      end if;

      if Starts_With (Field, "day_period_rule.") then
         declare
            Name : constant String :=
              Field (Field'First + 16 .. Field'Last);
         begin
            return Is_Day_Period_Name (Name)
              and then Is_Day_Period_Range (Value);
         end;
      end if;

      if Starts_With (Field, "day_period_exact.") then
         declare
            Name : constant String :=
              Field (Field'First + 17 .. Field'Last);
         begin
            return Is_Day_Period_Name (Name)
              and then Is_HH_MM (Value);
         end;
      end if;

      if Starts_With (Field, "available_format.") then
         return Value'Length > 0;
      end if;

      if Starts_With (Field, "era.")
        or else Starts_With (Field, "era_separator.")
        or else Starts_With (Field, "timezone_display.")
        or else Starts_With (Field, "timezone_display_standard.")
        or else Starts_With (Field, "timezone_display_daylight.")
        or else Starts_With (Field, "timezone_exemplar.")
        or else Starts_With (Field, "timezone_short.")
        or else Starts_With (Field, "timezone_short_daylight.")
        or else Starts_With (Field, "timezone_generic_short.")
        or else Starts_With (Field, "unit.")
        or else Starts_With (Field, "unit_pattern.")
        or else Starts_With (Field, "relative_exact.")
        or else Starts_With (Field, "relative_current.")
        or else Starts_With (Field, "relative_unit.")
      then
         return Value'Length > 0
           and then
             (if Starts_With (Field, "unit_pattern.")
              then Is_Unit_Pattern (Value)
              else True);
      end if;

      if Field = "timezone_location_pattern"
        or else Field = "timezone_location_pattern_standard"
        or else Field = "timezone_location_pattern_daylight"
      then
         return Value'Length > 0
           and then Ada.Strings.Fixed.Index (Value, "{0}") /= 0;
      end if;

      if Starts_With (Field, "relative_prefix.")
        or else Starts_With (Field, "relative_suffix.")
        or else Starts_With (Field, "relative_time_pattern.")
      then
         declare
            Dot : constant Natural := Last_Dot_Index (Field);
         begin
            return Value'Length > 0
              and then Dot /= 0
              and then (Field (Dot + 1 .. Field'Last) = "future"
                        or else Field (Dot + 1 .. Field'Last) = "past"
                        or else Starts_With (Field, "relative_time_pattern."))
              and then
                (if Starts_With (Field, "relative_time_pattern.")
                 then Occurrence_Count (Value, "{0}") <= 1
                 else True);
         end;
      end if;

      return False;
   end Valid_Locale_Field;

   procedure Clear is
   begin
      Locale_Overrides.Clear;
      Zone_Overrides.Clear;
      Currency_Overrides.Clear;
      Locale_Currency_Overrides.Clear;
      Plural_Overrides.Clear;
      Plural_Family_Overrides.Clear;
      Plural_Rule_Overrides.Clear;
      Spellout_Overrides.Clear;
      Spellout_Rule_Overrides.Clear;
   end Clear;

   function Load_Text
     (Source_Name : String;
      Text        : String;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List)
      return Boolean
   is
      Pending_Locales : String_Maps.Map := Locale_Overrides;
      Pending_Zones   : String_Maps.Map := Zone_Overrides;
      Pending_Currencies : String_Maps.Map := Currency_Overrides;
      Pending_Locale_Currencies : String_Maps.Map := Locale_Currency_Overrides;
      Pending_Plurals : String_Maps.Map := Plural_Overrides;
      Pending_Plural_Families : String_Maps.Map := Plural_Family_Overrides;
      Pending_Plural_Rules : String_Maps.Map := Plural_Rule_Overrides;
      Pending_Spellouts : String_Maps.Map := Spellout_Overrides;
      Pending_Spellout_Rules : String_Maps.Map := Spellout_Rule_Overrides;
      Start           : Positive := Text'First;
      Line_No         : Natural := 1;
      Ok              : Boolean := True;
      LDML_Block_Open : Boolean := False;
      LDML_Block_Start_Line : Natural := 0;
      LDML_Block_Open_Tag : Unbounded_String;
      LDML_Block_End_Tag : Unbounded_String;
      LDML_Block_Text : Unbounded_String;
      LDML_Context_Open : Boolean := False;
      LDML_Context_Start_Line : Natural := 0;
      LDML_Context_End_Tag : Unbounded_String;
      LDML_Context_Locale : Unbounded_String;
      LDML_Context_Explicit_Locale : Boolean := False;
      LDML_Context_Calendar : Unbounded_String;
      LDML_Context_Date_Name_Context : Unbounded_String;
      LDML_Context_Date_Name_Width : Unbounded_String;
      LDML_Context_Day_Period_Width : Unbounded_String;
      LDML_Context_Zone : Unbounded_String;
      LDML_Context_Zone_Width : Unbounded_String;
      LDML_Context_Unit : Unbounded_String;
      LDML_Context_Unit_Width : Unbounded_String;
      LDML_Context_Compound_Unit : Unbounded_String;
      LDML_Context_Number_System : Unbounded_String;
      LDML_Context_Relative_Unit : Unbounded_String;
      LDML_Context_Relative_Width : Unbounded_String;
      LDML_Context_Relative_Direction : Unbounded_String;
      LDML_Context_List_Pattern : Unbounded_String;
      LDML_Context_Currency : Unbounded_String;
      LDML_Context_Currency_Format : Unbounded_String;
      LDML_Context_Currency_Spacing : Unbounded_String;
      LDML_Context_Date_Time_Kind : Unbounded_String;
      LDML_Context_Date_Time_Style : Unbounded_String;
      LDML_Context_Plurals_Kind : Unbounded_String;
      LDML_Context_Plural_Rules_Kind : Unbounded_String;
      LDML_Context_Plural_Rules_Locales : Unbounded_String;
      LDML_Context_Day_Period_Rule_Set_Locales : Unbounded_String;
      LDML_Context_Day_Period_Rules_Locales : Unbounded_String;
      LDML_Context_RBNF_Ruleset : Unbounded_String;
      TZDB_Pending_Zone : Unbounded_String;
      TZDB_Pending_Until : Unbounded_String;
      TZDB_Rules : String_Maps.Map;
      TZDB_Rule_Applications : String_Maps.Map;
      LDML_Identity_Language : Unbounded_String;
      LDML_Identity_Script : Unbounded_String;
      LDML_Identity_Territory : Unbounded_String;
      Max_LDML_Container_Depth : constant Natural := 16;
      type LDML_Container_Stack is
        array (Positive range <>) of Unbounded_String;
      type LDML_Container_Line_Stack is
        array (Positive range <>) of Natural;
      LDML_Containers : LDML_Container_Stack (1 .. Max_LDML_Container_Depth);
      LDML_Container_Lines :
        LDML_Container_Line_Stack (1 .. Max_LDML_Container_Depth);
      LDML_Container_Depth : Natural := 0;

      procedure Store_CSV_Boolean
        (Locales : String;
         Field_Name : String)
      is
      begin
         for Index in 1 .. Field_Count (Locales, ',') loop
            declare
               Locale : constant String := Field (Locales, Index, ',');
            begin
               if Locale'Length > 0 then
                  Store
                    (Pending_Locales, Locale_Key (Locale, Field_Name), "true");
               end if;
            end;
         end loop;
      end Store_CSV_Boolean;

      procedure Store_Plural_Families
        (Kind    : String;
         Family  : String;
         Locales : String)
      is
      begin
         for Index in 1 .. Field_Count (Locales, ',') loop
            declare
               Locale : constant String := Field (Locales, Index, ',');
            begin
               if Locale'Length > 0 then
                  Store
                    (Pending_Plural_Families,
                     Plural_Family_Key (Kind, Locale),
                     Family);
               end if;
            end;
         end loop;
      end Store_Plural_Families;

      procedure Store_Plural_Families_List
        (Kind    : String;
         Family  : String;
         Locales : String;
         Source  : String;
         Line    : Natural)
      is
         Saw_Locale : Boolean := False;
         Token      : Unbounded_String := Null_Unbounded_String;

         procedure Flush_Token is
            Locale : constant String := To_String (Token);
         begin
            if Locale /= "" then
               Saw_Locale := True;
               Store
                 (Pending_Plural_Families,
                  Plural_Family_Key (Kind, Locale),
                  Family);
               Token := Null_Unbounded_String;
            end if;
         end Flush_Token;
      begin
         if not Is_Plural_Rule_Family (Kind, Family) then
            Add_Error (Diagnostics, Source, Line,
                       "invalid LDML plural-rule row");
            Ok := False;
            return;
         end if;

         for Index in Locales'Range loop
            if Locales (Index) = ' '
              or else Locales (Index) = ','
              or else Locales (Index) = ASCII.HT
            then
               Flush_Token;
            else
               Append (Token, Locales (Index));
            end if;
         end loop;

         Flush_Token;

         if not Saw_Locale then
            Add_Error (Diagnostics, Source, Line,
                       "invalid LDML plural-rule row");
            Ok := False;
         end if;
      end Store_Plural_Families_List;

      procedure Store_Plural_Category_Rule
        (Kind      : String;
         Locale    : String;
         Category  : String;
         Rule_Text : String;
         Source    : String;
         Line      : Natural)
      is
      begin
         if (Kind /= "cardinal" and then Kind /= "ordinal")
           or else Locale = ""
           or else not Is_Plural_Category (Category)
           or else Category = "other"
           or else not Is_Bounded_Plural_Rule_Text (Rule_Text)
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid runtime plural-rule expression row");
            Ok := False;
         else
            Store
              (Pending_Plural_Rules,
               Plural_Category_Rule_Key (Kind, Locale, Category),
              Rule_Text);
         end if;
      end Store_Plural_Category_Rule;

      procedure Store_Plural_Category_Rule_List
        (Kind      : String;
         Locales   : String;
         Category  : String;
         Rule_Text : String;
         Source    : String;
         Line      : Natural)
      is
         Saw_Locale : Boolean := False;
         Token      : Unbounded_String := Null_Unbounded_String;

         procedure Flush_Token is
            Locale : constant String := To_String (Token);
         begin
            if Locale /= "" then
               Saw_Locale := True;
               Store_Plural_Category_Rule
                 (Kind, Locale, Category, Rule_Text, Source, Line);
               Token := Null_Unbounded_String;
            end if;
         end Flush_Token;
      begin
         for Index in Locales'Range loop
            if Locales (Index) = ' '
              or else Locales (Index) = ','
              or else Locales (Index) = ASCII.HT
            then
               Flush_Token;
            else
               Append (Token, Locales (Index));
            end if;
         end loop;

         Flush_Token;

         if not Saw_Locale then
            Store_Plural_Category_Rule
              (Kind, "", Category, Rule_Text, Source, Line);
         end if;
      end Store_Plural_Category_Rule_List;

      procedure Store_Day_Period_Rule_List
        (Locales    : String;
         Period     : String;
         From_Time  : String;
         Before_Time : String;
         Source     : String;
         Line       : Natural)
      is
         Saw_Locale : Boolean := False;
         Token      : Unbounded_String := Null_Unbounded_String;
         Field_Name : constant String := "day_period_rule." & Period;
         Value      : constant String := From_Time & "-" & Before_Time;

         procedure Store_One (Locale : String) is
         begin
            if Locale = ""
              or else Period = ""
              or else From_Time = ""
              or else Before_Time = ""
              or else not Valid_Locale_Field (Field_Name, Value)
            then
               Add_Error (Diagnostics, Source, Line,
                          "invalid LDML dayPeriodRule row");
               Ok := False;
            else
               Store
                 (Pending_Locales,
                  Locale_Key (Locale, Field_Name),
                  Value);
            end if;
         end Store_One;

         procedure Flush_Token is
            Locale : constant String := To_String (Token);
         begin
            if Locale /= "" then
               Saw_Locale := True;
               Store_One (Locale);
               Token := Null_Unbounded_String;
            end if;
         end Flush_Token;
      begin
         for Index in Locales'Range loop
            if Locales (Index) = ' '
              or else Locales (Index) = ','
              or else Locales (Index) = ASCII.HT
            then
               Flush_Token;
            else
               Append (Token, Locales (Index));
            end if;
         end loop;

         Flush_Token;

         if not Saw_Locale then
            Store_One ("");
         end if;
      end Store_Day_Period_Rule_List;

      procedure Store_Day_Period_At_Rule_List
        (Locales : String;
         Period  : String;
         At_Time : String;
         Source  : String;
         Line    : Natural)
      is
         Saw_Locale : Boolean := False;
         Token      : Unbounded_String := Null_Unbounded_String;
         Field_Name : constant String := "day_period_exact." & Period;

         procedure Store_One (Locale : String) is
         begin
            if Locale = ""
              or else Period = ""
              or else At_Time = ""
              or else not Valid_Locale_Field (Field_Name, At_Time)
            then
               Add_Error (Diagnostics, Source, Line,
                          "invalid LDML dayPeriodRule row");
               Ok := False;
            else
               Store
                 (Pending_Locales,
                  Locale_Key (Locale, Field_Name),
                  At_Time);
            end if;
         end Store_One;

         procedure Flush_Token is
            Locale : constant String := To_String (Token);
         begin
            if Locale /= "" then
               Saw_Locale := True;
               Store_One (Locale);
               Token := Null_Unbounded_String;
            end if;
         end Flush_Token;
      begin
         if not Is_HH_MM (At_Time) then
            Add_Error (Diagnostics, Source, Line,
                       "invalid LDML dayPeriodRule row");
            Ok := False;
            return;
         end if;

         for Index in Locales'Range loop
            if Locales (Index) = ' '
              or else Locales (Index) = ','
              or else Locales (Index) = ASCII.HT
            then
               Flush_Token;
            else
               Append (Token, Locales (Index));
            end if;
         end loop;

         Flush_Token;

         if not Saw_Locale then
            Store_One ("");
         end if;
      end Store_Day_Period_At_Rule_List;

      procedure Store_Name_Set
        (Name_Kind  : String;
         Locale     : String;
         Start_Text : String;
         Items      : String;
         Source     : String;
         Line       : Natural)
      is
         Target_Field : constant String :=
           (if Name_Kind = "month_full" then "month"
            elsif Name_Kind = "month_short" then "month_short"
            elsif Name_Kind = "month_narrow" then "month_narrow"
            elsif Name_Kind = "quarter_full" then "quarter"
            elsif Name_Kind = "quarter_short" then "quarter_short"
            elsif Name_Kind = "quarter_narrow" then "quarter_narrow"
            elsif Name_Kind = "weekday_full" then "weekday"
            elsif Name_Kind = "weekday_short" then "weekday_short"
            elsif Name_Kind = "weekday_narrow" then "weekday_narrow"
            else "");
      begin
         if Target_Field = ""
           or else not Is_Integer_Text (Start_Text)
           or else not In_Integer_Range (Start_Text)
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid normalized CLDR name row");
            Ok := False;
            return;
         end if;

         declare
            Start_Index : constant Integer := Integer'Value (Start_Text);
            Count       : constant Natural := Field_Count (Items, '~');
         begin
            if (Name_Kind = "month_full"
                  or else Name_Kind = "month_short"
                  or else Name_Kind = "month_narrow")
              and then (Start_Index /= 1 or else Count /= 12)
            then
               Add_Error (Diagnostics, Source, Line,
                          "invalid normalized CLDR month row");
               Ok := False;
               return;
            elsif (Name_Kind = "quarter_full"
                     or else Name_Kind = "quarter_short"
                     or else Name_Kind = "quarter_narrow")
              and then (Start_Index /= 1 or else Count /= 4)
            then
               Add_Error (Diagnostics, Source, Line,
                          "invalid normalized CLDR quarter row");
               Ok := False;
               return;
            elsif (Name_Kind = "weekday_full"
                     or else Name_Kind = "weekday_short"
                     or else Name_Kind = "weekday_narrow")
              and then (Start_Index /= 0 or else Count /= 7)
            then
               Add_Error (Diagnostics, Source, Line,
                          "invalid normalized CLDR weekday row");
               Ok := False;
               return;
            end if;

            for Index in 1 .. Count loop
               declare
                  Item_Text : constant String :=
                    Hex_Scalars_To_UTF8 (Field (Items, Index, '~'));
               begin
                  if Item_Text'Length = 0 then
                     Add_Error (Diagnostics, Source, Line,
                                "invalid normalized CLDR name text");
                     Ok := False;
                     return;
                  end if;

                  Store
                    (Pending_Locales,
                     Locale_Key
                       (Locale,
                        Target_Field & "."
                        & Natural_Text
                          (Natural (Start_Index + Integer (Index) - 1))),
                     Item_Text);
               end;
            end loop;
         end;
      end Store_Name_Set;

      procedure Store_Currency_Name_Payload
        (Locale  : String;
         Payload : String;
         Source  : String;
         Line    : Natural)
      is
         function Category_Field (Index : Positive) return String is
         begin
            case Index is
               when 1 => return "display_name.zero";
               when 2 => return "display_name.one";
               when 3 => return "display_name.two";
               when 4 => return "display_name.few";
               when 5 => return "display_name.many";
               when others => return "display_name.other";
            end case;
         end Category_Field;
      begin
         for Entry_Index in 1 .. Field_Count (Payload, ';') loop
            declare
               Item  : constant String := Field (Payload, Entry_Index, ';');
               Sep   : constant Natural :=
                 Char_Index (Item, Item'First, ':');
            begin
               if Item'Length = 0 then
                  null;
               elsif Sep = 0 or else Sep /= Item'First + 3 then
                  Add_Error (Diagnostics, Source, Line,
                             "invalid normalized CLDR currency-name payload");
                  Ok := False;
                  return;
               else
                  declare
                     Code  : constant String := Item (Item'First .. Sep - 1);
                     Names : constant String := Item (Sep + 1 .. Item'Last);
                  begin
                     if Field_Count (Names, ',') /= 6 then
                        Add_Error
                          (Diagnostics, Source, Line,
                           "invalid normalized CLDR currency-name categories");
                        Ok := False;
                        return;
                     end if;

                     for Category_Index in 1 .. 6 loop
                        declare
                           Value : constant String :=
                             Hex_Bytes_To_UTF8
                               (Field (Names, Category_Index, ','));
                        begin
                           if Value'Length = 0 then
                              Add_Error
                                (Diagnostics, Source, Line,
                                 "invalid normalized CLDR currency-name text");
                              Ok := False;
                              return;
                           end if;

                           Store
                             (Pending_Locale_Currencies,
                              Locale_Currency_Key
                                (Locale, Code,
                                 Category_Field (Category_Index)),
                              Value);
                        end;
                     end loop;
                  end;
               end if;
            end;
         end loop;
      end Store_Currency_Name_Payload;

      procedure Store_Spellout_Text
        (Locale     : String;
         Kind       : String;
         Value_Text : String;
         Text_Value : String;
         Source     : String;
         Line       : Natural)
      is
         Normal_Kind : constant String := Normalize_Spellout_Kind (Kind);
         Normal_Text : constant String := Normalize_RBNF_Exact_Text (Text_Value);
      begin
         if Locale'Length = 0
           or else not Is_Spellout_Kind (Normal_Kind)
           or else Normal_Text'Length = 0
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid runtime RBNF spellout row");
            Ok := False;
         elsif Normal_Kind = "decimal_separator" then
            if Value_Text'Length /= 0 then
               Add_Error (Diagnostics, Source, Line,
                          "invalid runtime RBNF decimal row");
               Ok := False;
            else
               Store
                 (Pending_Spellouts,
                  Spellout_Key (Locale, Normal_Kind, ""),
                  Normal_Text);
            end if;
         elsif Is_Spellout_Decimal_Text (Value_Text)
         then
            Store
              (Pending_Spellouts,
               Spellout_Key (Locale, Normal_Kind, Value_Text),
               Normal_Text);
         elsif not In_Integer_Range (Value_Text) then
            Add_Error (Diagnostics, Source, Line,
                       "invalid runtime RBNF spellout value");
            Ok := False;
         else
            declare
               Value : constant Integer := Integer'Value (Value_Text);
            begin
               if Value < -999_999_999 or else Value > 999_999_999 then
                  Add_Error (Diagnostics, Source, Line,
                             "invalid runtime RBNF spellout value");
                  Ok := False;
               else
                  Store
                    (Pending_Spellouts,
                     Spellout_Key (Locale, Normal_Kind, Integer_Text (Value)),
                     Normal_Text);
               end if;
            end;
         end if;
      end Store_Spellout_Text;

      procedure Store_Spellout_Rule
        (Locale     : String;
         Kind       : String;
         Base_Text  : String;
         Text_Value : String;
         Source     : String;
         Line       : Natural)
      is
         Normal_Kind : constant String := Normalize_Spellout_Kind (Kind);
         Unicode_Minus_X : constant String :=
           Character'Val (16#E2#) & Character'Val (16#88#)
           & Character'Val (16#92#) & "x";
         Normal_Base : constant String :=
           (if Base_Text = "-x"
              or else Base_Text = Unicode_Minus_X
              or else Base_Text = "minus"
            then "negative"
            elsif Base_Text = "x.x" or else Base_Text = "decimal-rule"
            then "decimal"
            elsif Base_Text = "0.x"
            then "zero-decimal"
            elsif Base_Text = "x.0"
            then "integer-decimal"
            else Base_Text);
         Normal_Text : constant String :=
           Normalize_RBNF_Pattern_Tokens
             (Normalize_RBNF_Rule_Text (Text_Value));
      begin
         if Locale'Length = 0
           or else not (Normal_Kind = "cardinal" or else Normal_Kind = "ordinal")
           or else Normal_Text'Length = 0
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid runtime RBNF rule row");
            Ok := False;
         elsif Ada.Strings.Fixed.Index (Normal_Text, "$(") /= 0
           and then not Is_RBNF_Plural_Affix_Pattern (Normal_Text)
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid runtime RBNF rule row");
            Ok := False;
         elsif Normal_Base = "negative"
           or else Normal_Base = "decimal"
           or else Normal_Base = "zero-decimal"
           or else Normal_Base = "integer-decimal"
         then
            if not Is_RBNF_Rule_Pattern (Normal_Text) then
               Add_Error (Diagnostics, Source, Line,
                          "invalid runtime RBNF rule row");
               Ok := False;
            else
               Store
                 (Pending_Spellout_Rules,
                  Spellout_Key (Locale, Normal_Kind, Normal_Base),
                  Normal_Text);
            end if;
         else
            declare
               Base    : Natural := 0;
               Divisor : Natural := 0;
            begin
               if not RBNF_Rule_Descriptor_Values
                        (Normal_Base, Base, Divisor)
               then
                  Add_Error (Diagnostics, Source, Line,
                             "invalid runtime RBNF rule base");
                  Ok := False;
               elsif Is_RBNF_Rule_Pattern (Normal_Text) then
                  Store
                    (Pending_Spellout_Rules,
                     Spellout_Key
                       (Locale, Normal_Kind,
                        RBNF_Rule_Descriptor_Text (Base, Divisor)),
                     Normal_Text);
               elsif Divisor = 0
                 and then RBNF_Rule_Descriptor_Text (Base, Divisor)
                          = Natural_Text (Base)
               then
                  Store
                    (Pending_Spellouts,
                     Spellout_Key
                       (Locale, Normal_Kind, Natural_Text (Base)),
                     Normal_Text);
               else
                  Add_Error (Diagnostics, Source, Line,
                             "invalid runtime RBNF rule row");
                  Ok := False;
               end if;
            end;
         end if;
      end Store_Spellout_Rule;

      procedure Store_Normalized_Locale_Text
        (Locale : String;
         Name   : String;
         Hex    : String;
         Source : String;
         Line   : Natural)
      is
         Value : constant String := Hex_Bytes_To_UTF8 (Hex);
      begin
         if Locale = ""
           or else Name = ""
           or else Value = ""
           or else not Valid_Locale_Field (Name, Value)
         then
            Add_Error (Diagnostics, Source, Line,
                       "invalid normalized CLDR locale text row");
            Ok := False;
         else
            Store (Pending_Locales, Locale_Key (Locale, Name), Value);
         end if;
      end Store_Normalized_Locale_Text;

      procedure Parse_Normalized_CLDR_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Kind : constant String := Field (Line, 1);
      begin
         if Kind = "decimal_text" or else Kind = "group_text" then
            if Field_Count (Line) /= 3 or else Field (Line, 2) = ""
              or else Field (Line, 3) = ""
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR symbol row");
               Ok := False;
            else
               Store
                 (Pending_Locales,
                  Locale_Key
                    (Field (Line, 2),
                     (if Kind = "decimal_text"
                      then "decimal_separator"
                      else "group_separator")),
                  Field (Line, 3));
            end if;
         elsif Kind = "digits_codepoints" then
            if Field_Count (Line) /= 3 or else Field_Count (Field (Line, 3), ',') /= 10
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR digits row");
               Ok := False;
            else
               for Digit in 0 .. 9 loop
                  declare
                     Value : constant String :=
                       Codepoint_List_To_UTF8
                         (Field (Field (Line, 3), Digit + 1, ','));
                  begin
                     if Value'Length = 0 then
                        Add_Error (Diagnostics, Source, Number,
                                   "invalid normalized CLDR digit");
                        Ok := False;
                        return;
                     end if;

                     Store
                       (Pending_Locales,
                        Locale_Key
                          (Field (Line, 2),
                           "digit." & Natural_Text (Digit)),
                        Value);
                  end;
               end loop;
            end if;
         elsif Kind = "names_hex" then
            if Field_Count (Line) /= 5 then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR names row");
               Ok := False;
            else
               Store_Name_Set
                 (Field (Line, 2), Field (Line, 3), Field (Line, 4),
                  Field (Line, 5), Source, Number);
            end if;
         elsif Kind = "locale_text" then
            if Field_Count (Line) /= 4 then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR locale text row");
               Ok := False;
            else
               Store_Normalized_Locale_Text
                 (Field (Line, 2), Field (Line, 3), Field (Line, 4),
                  Source, Number);
            end if;
         elsif Kind = "currency_text" then
            if Field_Count (Line) /= 7
              or else Field (Line, 2)'Length /= 3
              or else not In_Integer_Range (Field (Line, 3))
              or else not In_Integer_Range (Field (Line, 4))
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR currency row");
               Ok := False;
            else
               Store
                 (Pending_Currencies,
                  Currency_Key (Field (Line, 2), "minor_units"),
                  Field (Line, 3));
               Store
                 (Pending_Currencies,
                  Currency_Key (Field (Line, 2), "cash_increment"),
                  Field (Line, 4));
               Store
                 (Pending_Currencies,
                  Currency_Key (Field (Line, 2), "symbol"),
                  Field (Line, 5));
               Store
                 (Pending_Currencies,
                  Currency_Key (Field (Line, 2), "narrow_symbol"),
                  Field (Line, 6));
               Store
                 (Pending_Currencies,
                  Currency_Key (Field (Line, 2), "display_name"),
                  Field (Line, 7));
            end if;
         elsif Kind = "plural_rule" then
            if Field_Count (Line) /= 4
              or else (Field (Line, 2) /= "cardinal"
                         and then Field (Line, 2) /= "ordinal")
              or else Field (Line, 3) = ""
              or else not Is_Plural_Rule_Family
                (Field (Line, 2), Field (Line, 4))
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR plural-rule row");
               Ok := False;
            else
               Store
                 (Pending_Plural_Families,
                 Plural_Family_Key (Field (Line, 2), Field (Line, 3)),
                  Field (Line, 4));
            end if;
         elsif Kind = "plural_rule_text" then
            if Field_Count (Line) /= 5 then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR plural-rule expression row");
               Ok := False;
            else
               Store_Plural_Category_Rule
                 (Field (Line, 2),
                  Field (Line, 3),
                  Field (Line, 4),
                  Field (Line, 5),
                  Source,
                  Number);
            end if;
         elsif Kind = "rbnf_text" then
            if Field_Count (Line) /= 5 then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR RBNF row");
               Ok := False;
            else
               declare
                  Text_Value : constant String :=
                    Hex_Bytes_To_UTF8 (Field (Line, 5));
               begin
                  Store_Spellout_Text
                    (Field (Line, 2),
                     Field (Line, 3),
                     Field (Line, 4),
                     Text_Value,
                     Source,
                     Number);
               end;
            end if;
         elsif Kind = "rbnf_rule_text" then
            if Field_Count (Line) /= 5 then
               Add_Error (Diagnostics, Source, Number,
                          "invalid normalized CLDR RBNF rule row");
               Ok := False;
            else
               declare
                  Text_Value : constant String :=
                    Hex_Bytes_To_UTF8 (Field (Line, 5));
               begin
                  Store_Spellout_Rule
                    (Field (Line, 2),
                     Field (Line, 3),
                     Field (Line, 4),
                     Text_Value,
                     Source,
                     Number);
               end;
            end if;
         elsif Kind = "raw" then
            if Field_Count (Line) >= 2 and then Field (Line, 2) = "indian_grouping"
            then
               if Field_Count (Line) /= 4 then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid normalized CLDR grouping row");
                  Ok := False;
               else
                  Store_CSV_Boolean (Field (Line, 3), "uses_indian_grouping");
                  --  Store the suffix marker as a deterministic key for
                  --  callers that load a locale matching the checked suffix.
                  if Field (Line, 4)'Length > 0 then
                     Store
                       (Pending_Locales,
                        Locale_Key ("*" & Field (Line, 4),
                                    "uses_indian_grouping"),
                        "true");
                  end if;
               end if;
            elsif Field_Count (Line) >= 2
              and then Field (Line, 2) = "day_month_year"
            then
               if Field_Count (Line) /= 3 then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid normalized CLDR date-order row");
                  Ok := False;
               else
                  Store_CSV_Boolean (Field (Line, 3), "uses_day_month_year");
               end if;
            elsif Field_Count (Line) >= 2
              and then Field (Line, 2) = "symbol_first"
            then
               if Field_Count (Line) /= 3 then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid normalized CLDR symbol-first row");
                  Ok := False;
               else
                  Store_CSV_Boolean (Field (Line, 3), "currency_symbol_first");
               end if;
            elsif Field_Count (Line) >= 2
              and then (Field (Line, 2) = "cardinal"
                          or else Field (Line, 2) = "ordinal")
            then
               if Field_Count (Line) /= 4 then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid normalized CLDR plural-family row");
                  Ok := False;
               else
                  Store_Plural_Families
                    (Field (Line, 2), Field (Line, 3), Field (Line, 4));
               end if;
            elsif Field_Count (Line) >= 2
              and then Field (Line, 2) = "currency_name_payload"
            then
               if Field_Count (Line) /= 4 then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid normalized CLDR currency-name row");
                  Ok := False;
               else
                  Store_Currency_Name_Payload
                    (Field (Line, 3), Field (Line, 4), Source, Number);
               end if;
            else
               Add_Error (Diagnostics, Source, Number,
                          "unsupported normalized CLDR raw row");
               Ok := False;
            end if;
         else
            Add_Error (Diagnostics, Source, Number,
                       "unsupported normalized CLDR row");
            Ok := False;
         end if;
      end Parse_Normalized_CLDR_Row;

      function Is_Normalized_CLDR_Row (Line : String) return Boolean is
         Kind : constant String := Field (Line, 1);
      begin
         return Kind = "decimal_text"
           or else Kind = "group_text"
           or else Kind = "digits_codepoints"
           or else Kind = "names_hex"
           or else Kind = "locale_text"
           or else Kind = "currency_text"
           or else Kind = "plural_rule"
           or else Kind = "plural_rule_text"
           or else Kind = "rbnf_text"
           or else Kind = "rbnf_rule_text"
           or else Kind = "raw";
      end Is_Normalized_CLDR_Row;

      function Is_LDML_Row (Line : String) return Boolean is
         function Is_Single_Line_Element (Name : String) return Boolean is
         begin
            return Line (Line'Last - 1) = '/'
              or else Index_Of (Line, "</" & Name & ">") /= 0;
         end Is_Single_Line_Element;
      begin
         return (Starts_With (Line, "<symbols ")
                 and then Is_Single_Line_Element ("symbols"))
           or else Starts_With (Line, "<defaultNumberingSystem ")
           or else Starts_With (Line, "<defaultNumberingSystem>")
           or else Starts_With (Line, "<decimal ")
           or else Starts_With (Line, "<decimal>")
           or else Starts_With (Line, "<group ")
           or else Starts_With (Line, "<group>")
           or else Starts_With (Line, "<percentSign ")
           or else Starts_With (Line, "<percentSign>")
           or else Starts_With (Line, "<perMille ")
           or else Starts_With (Line, "<perMille>")
           or else Starts_With (Line, "<plusSign ")
           or else Starts_With (Line, "<plusSign>")
           or else Starts_With (Line, "<minusSign ")
           or else Starts_With (Line, "<minusSign>")
           or else Starts_With (Line, "<exponential ")
           or else Starts_With (Line, "<exponential>")
           or else Starts_With (Line, "<month ")
           or else Starts_With (Line, "<quarter ")
           or else Starts_With (Line, "<weekday ")
           or else Starts_With (Line, "<day ")
           or else Starts_With (Line, "<dayPeriod ")
           or else Starts_With (Line, "<dayPeriodRule ")
           or else Starts_With (Line, "<era ")
           or else Starts_With (Line, "<eraSeparator ")
           or else Starts_With (Line, "<zoneName ")
           or else Starts_With (Line, "<timeZoneName ")
           or else Starts_With (Line, "<zoneExemplar ")
           or else Starts_With (Line, "<exemplarCity ")
           or else Starts_With (Line, "<exemplarCity>")
           or else Starts_With (Line, "<zoneShort ")
           or else Starts_With (Line, "<zoneShortStandard ")
           or else Starts_With (Line, "<zoneStandardShort ")
           or else Starts_With (Line, "<zoneShortDaylight ")
           or else Starts_With (Line, "<zoneDaylightShort ")
           or else Starts_With (Line, "<zoneGenericShort ")
           or else Starts_With (Line, "<zoneShortGeneric ")
           or else Starts_With (Line, "<generic ")
           or else Starts_With (Line, "<generic>")
           or else Starts_With (Line, "<standard ")
           or else Starts_With (Line, "<standard>")
           or else Starts_With (Line, "<daylight ")
           or else Starts_With (Line, "<daylight>")
           or else Starts_With (Line, "<zoneLocationPattern ")
           or else Starts_With (Line, "<regionFormat ")
           or else Starts_With (Line, "<regionFormat>")
           or else Starts_With (Line, "<gmtFormat ")
           or else Starts_With (Line, "<gmtZeroFormat ")
           or else Starts_With (Line, "<hourFormat ")
           or else Starts_With (Line, "<unitName ")
           or else Starts_With (Line, "<unitDisplayName ")
           or else Starts_With (Line, "<displayName ")
           or else Starts_With (Line, "<displayName>")
           or else Starts_With (Line, "<unitPattern ")
           or else Starts_With (Line, "<compoundUnitPattern ")
           or else Starts_With (Line, "<compoundUnitPattern>")
           or else Starts_With (Line, "<relativeName ")
           or else Starts_With (Line, "<relativePeriod ")
           or else Starts_With (Line, "<relativeUnit ")
           or else Starts_With (Line, "<relativePattern ")
           or else (Starts_With (Line, "<relativeTime ")
                    and then Is_Single_Line_Element ("relativeTime"))
           or else Starts_With (Line, "<relativeTimePattern ")
           or else Starts_With (Line, "<relative ")
           or else Starts_With (Line, "<relative>")
           or else (Starts_With (Line, "<listPattern ")
                    and then Is_Single_Line_Element ("listPattern"))
           or else Starts_With (Line, "<listPatternPart ")
           or else (Starts_With (Line, "<dateFormat ")
                    and then Is_Single_Line_Element ("dateFormat"))
           or else (Starts_With (Line, "<dateFormatLength ")
                    and then Is_Single_Line_Element ("dateFormatLength"))
           or else (Starts_With (Line, "<timeFormat ")
                    and then Is_Single_Line_Element ("timeFormat"))
           or else (Starts_With (Line, "<timeFormatLength ")
                    and then Is_Single_Line_Element ("timeFormatLength"))
           or else (Starts_With (Line, "<dateTimeFormat ")
                    and then Is_Single_Line_Element ("dateTimeFormat"))
           or else (Starts_With (Line, "<dateTimeFormatLength ")
                    and then Is_Single_Line_Element ("dateTimeFormatLength"))
           or else Starts_With (Line, "<dateStyle ")
           or else Starts_With (Line, "<timeStyle ")
           or else Starts_With (Line, "<dateTimeStyle ")
           or else Starts_With (Line, "<availableFormat ")
           or else Starts_With (Line, "<dateFormatItem ")
           or else Starts_With (Line, "<appendItem ")
           or else Starts_With (Line, "<calendarPreference ")
           or else Starts_With (Line, "<timeZonePreference ")
           or else Starts_With (Line, "<numberingSystemPreference ")
           or else Starts_With (Line, "<hourCyclePreference ")
           or else (Starts_With (Line, "<weekData ")
                    and then Is_Single_Line_Element ("weekData"))
           or else Starts_With (Line, "<firstDay ")
           or else Starts_With (Line, "<minDays ")
           or else (Starts_With (Line, "<currencyFormat ")
                    and then Is_Single_Line_Element ("currencyFormat"))
           or else Starts_With (Line, "<pattern ")
           or else Starts_With (Line, "<pattern>")
           or else (Starts_With (Line, "<currencySpacing ")
                    and then Is_Single_Line_Element ("currencySpacing"))
           or else Starts_With (Line, "<currencyMatch ")
           or else Starts_With (Line, "<currencyMatch>")
           or else Starts_With (Line, "<surroundingMatch ")
           or else Starts_With (Line, "<surroundingMatch>")
           or else Starts_With (Line, "<insertBetween ")
           or else Starts_With (Line, "<insertBetween>")
           or else (Starts_With (Line, "<currency ")
                    and then
                      (Line (Line'Last - 1) = '/'
                       or else Index_Of (Line, "</currency>") /= 0))
           or else Starts_With (Line, "<symbol ")
           or else Starts_With (Line, "<symbol>")
           or else Starts_With (Line, "<currencySymbol ")
           or else Starts_With (Line, "<currencyName ")
           or else Starts_With (Line, "<pluralRule ")
           or else Starts_With (Line, "<rbnf ")
           or else Starts_With (Line, "<rbnfRule ")
           or else Starts_With (Line, "<rbnfRule>")
           or else Starts_With (Line, "<rbnfrule ")
           or else Starts_With (Line, "<rbnfrule>")
           or else Starts_With (Line, "<timeZone ");
      end Is_LDML_Row;

      function LDML_Block_Close_Tag (Line : String) return String is
      begin
         if Is_LDML_Row (Line) and then Line'Length > 2
           and then Line (Line'First) = '<'
           and then Line (Line'Last) = '>'
           and then Line (Line'Last - 1) /= '/'
         then
            for Index in Line'First + 1 .. Line'Last loop
               if Line (Index) = ' ' or else Line (Index) = '>' then
                  return "</" & Line (Line'First + 1 .. Index - 1) & ">";
               end if;
            end loop;
         end if;

         return "";
      end LDML_Block_Close_Tag;

      function Is_LDML_Block_Start (Line : String) return Boolean is
         Close_Tag : constant String := LDML_Block_Close_Tag (Line);
      begin
         return Close_Tag /= ""
           and then Ada.Strings.Fixed.Index (Line, Close_Tag) = 0
           and then Line (Line'Last) = '>';
      end Is_LDML_Block_Start;

      function Is_LDML_Block_Close (Line : String) return Boolean is
      begin
         return Line'Length > 3
           and then Line (Line'First .. Line'First + 1) = "</"
           and then Line (Line'Last) = '>';
      end Is_LDML_Block_Close;

      function Is_LDML_Context_Start (Line : String) return Boolean is
      begin
         return (Line = "<ldml>"
                 or else Starts_With (Line, "<ldml ")
                 or else Starts_With (Line, "<locale "))
           and then Line (Line'Last) = '>'
           and then Line (Line'Last - 1) /= '/';
      end Is_LDML_Context_Start;

      function LDML_Context_Close_Tag (Line : String) return String is
      begin
         if Line = "<ldml>" or else Starts_With (Line, "<ldml ") then
            return "</ldml>";
         elsif Starts_With (Line, "<locale ") then
            return "</locale>";
         end if;

         return "";
      end LDML_Context_Close_Tag;

      function LDML_Context_Start_Locale (Line : String) return String is
         Locale : constant String := Attribute_Value (Line, "locale");
         Id     : constant String := Attribute_Value (Line, "id");
      begin
         if Locale /= "" then
            return Locale;
         end if;

         return Id;
      end LDML_Context_Start_Locale;

      function Is_XML_Ignorable_Line (Line : String) return Boolean is
      begin
         if Starts_With (Line, "<?xml") then
            return Line'Length >= 5
              and then Line (Line'Last - 1 .. Line'Last) = "?>";
         elsif Starts_With (Line, "<!--") then
            return Line'Length >= 7
              and then Line (Line'Last - 2 .. Line'Last) = "-->";
         end if;

         return False;
      end Is_XML_Ignorable_Line;

      function XML_Element_Name (Line : String) return String is
         First : Natural := Line'First + 1;
      begin
         if Line'Length < 3 or else Line (Line'First) /= '<' then
            return "";
         end if;

         if Line (First) = '/' then
            First := First + 1;
         end if;

         if First > Line'Last then
            return "";
         end if;

         for Index in First .. Line'Last loop
            if Line (Index) = ' '
              or else Line (Index) = '>'
              or else Line (Index) = '/'
            then
               if Index = First then
                  return "";
               end if;

               return Line (First .. Index - 1);
            end if;
         end loop;

         return "";
      end XML_Element_Name;

      function Is_LDML_Identity_Row (Line : String) return Boolean is
         Name : constant String := XML_Element_Name (Line);
      begin
         return LDML_Context_Open
           and then (Name = "language"
                     or else Name = "script"
                     or else Name = "territory")
           and then Line (Line'First) = '<'
           and then Line (Line'Last) = '>'
           and then Line (Line'Last - 1) = '/'
           and then Attribute_Value (Line, "type") /= "";
      end Is_LDML_Identity_Row;

      procedure Reset_LDML_Identity_Context is
      begin
         LDML_Context_Open := False;
         LDML_Context_Start_Line := 0;
         LDML_Context_End_Tag := Null_Unbounded_String;
         LDML_Context_Locale := Null_Unbounded_String;
         LDML_Context_Explicit_Locale := False;
         LDML_Context_Calendar := Null_Unbounded_String;
         LDML_Context_Date_Name_Context := Null_Unbounded_String;
         LDML_Context_Date_Name_Width := Null_Unbounded_String;
         LDML_Context_Day_Period_Width := Null_Unbounded_String;
         LDML_Context_Zone := Null_Unbounded_String;
         LDML_Context_Zone_Width := Null_Unbounded_String;
         LDML_Context_Unit := Null_Unbounded_String;
         LDML_Context_Unit_Width := Null_Unbounded_String;
         LDML_Context_Compound_Unit := Null_Unbounded_String;
         LDML_Context_Number_System := Null_Unbounded_String;
         LDML_Context_List_Pattern := Null_Unbounded_String;
         LDML_Context_Currency := Null_Unbounded_String;
         LDML_Context_Currency_Format := Null_Unbounded_String;
         LDML_Context_Currency_Spacing := Null_Unbounded_String;
         LDML_Context_Date_Time_Kind := Null_Unbounded_String;
         LDML_Context_Date_Time_Style := Null_Unbounded_String;
         LDML_Context_Plurals_Kind := Null_Unbounded_String;
         LDML_Context_Plural_Rules_Kind := Null_Unbounded_String;
         LDML_Context_Plural_Rules_Locales := Null_Unbounded_String;
         LDML_Context_Day_Period_Rule_Set_Locales := Null_Unbounded_String;
         LDML_Context_Day_Period_Rules_Locales := Null_Unbounded_String;
         LDML_Context_RBNF_Ruleset := Null_Unbounded_String;
         LDML_Identity_Language := Null_Unbounded_String;
         LDML_Identity_Script := Null_Unbounded_String;
         LDML_Identity_Territory := Null_Unbounded_String;
      end Reset_LDML_Identity_Context;

      procedure Refresh_LDML_Identity_Locale is
         Language  : constant String := To_String (LDML_Identity_Language);
         Script    : constant String := To_String (LDML_Identity_Script);
         Territory : constant String := To_String (LDML_Identity_Territory);
      begin
         if LDML_Context_Explicit_Locale or else Language = "" then
            return;
         end if;

         LDML_Context_Locale :=
           To_Unbounded_String
             (Language
              & (if Script /= "" then "-" & Script else "")
              & (if Territory /= "" then "-" & Territory else ""));
      end Refresh_LDML_Identity_Locale;

      procedure Apply_LDML_Identity_Row (Line : String) is
         Name  : constant String := XML_Element_Name (Line);
         Value : constant String := Attribute_Value (Line, "type");
      begin
         if Name = "language" then
            LDML_Identity_Language := To_Unbounded_String (Value);
         elsif Name = "script" then
            LDML_Identity_Script := To_Unbounded_String (Value);
         elsif Name = "territory" then
            LDML_Identity_Territory := To_Unbounded_String (Value);
         end if;

         Refresh_LDML_Identity_Locale;
      end Apply_LDML_Identity_Row;

      function Is_Inert_LDML_Container_Name (Name : String) return Boolean is
      begin
         return Name = "identity"
           or else Name = "localeDisplayNames"
           or else Name = "numbers"
           or else Name = "symbols"
           or else Name = "dates"
           or else Name = "calendars"
           or else Name = "calendar"
           or else Name = "months"
           or else Name = "monthContext"
           or else Name = "monthWidth"
           or else Name = "days"
           or else Name = "dayContext"
           or else Name = "dayWidth"
           or else Name = "quarters"
           or else Name = "quarterContext"
           or else Name = "quarterWidth"
           or else Name = "dayPeriods"
           or else Name = "dayPeriodContext"
           or else Name = "dayPeriodWidth"
           or else Name = "dayPeriodRuleSet"
           or else Name = "dayPeriodRules"
           or else Name = "eras"
           or else Name = "eraAbbr"
           or else Name = "eraNames"
           or else Name = "eraNarrow"
           or else Name = "dateFormats"
           or else Name = "dateFormatLength"
           or else Name = "dateFormat"
           or else Name = "timeFormats"
           or else Name = "timeFormatLength"
           or else Name = "timeFormat"
           or else Name = "dateTimeFormats"
           or else Name = "dateTimeFormatLength"
           or else Name = "dateTimeFormat"
           or else Name = "availableFormats"
           or else Name = "appendItems"
           or else Name = "timeZoneNames"
           or else Name = "zone"
           or else Name = "long"
           or else Name = "short"
           or else Name = "units"
           or else Name = "unitLength"
           or else Name = "unit"
           or else Name = "compoundUnit"
           or else Name = "fields"
           or else Name = "relativeFields"
           or else Name = "field"
           or else Name = "relativeTime"
           or else Name = "listPatterns"
           or else Name = "listPattern"
           or else Name = "currencyFormats"
           or else Name = "currencyFormatLength"
           or else Name = "currencyFormat"
           or else Name = "currencySpacing"
           or else Name = "beforeCurrency"
           or else Name = "afterCurrency"
           or else Name = "currencies"
           or else Name = "currency"
           or else Name = "currencyNames"
           or else Name = "plurals"
           or else Name = "weekData"
           or else Name = "pluralRules"
           or else Name = "rbnf"
           or else Name = "rulesetGrouping"
           or else Name = "ruleSetGrouping"
           or else Name = "ruleset"
           or else Name = "ruleSet"
           or else Name = "rules";
      end Is_Inert_LDML_Container_Name;

      function Is_Inert_LDML_Container_Start (Line : String) return Boolean is
         Name : constant String := XML_Element_Name (Line);
      begin
         return Name /= ""
           and then Is_Inert_LDML_Container_Name (Name)
           and then not Is_LDML_Row (Line)
           and then Line (Line'First) = '<'
           and then Line (Line'First + 1) /= '/'
           and then Line (Line'Last) = '>'
           and then Line (Line'Last - 1) /= '/';
      end Is_Inert_LDML_Container_Start;

      function Is_Inert_LDML_Container_Close (Line : String) return Boolean is
         Name : constant String := XML_Element_Name (Line);
      begin
         return Name /= ""
           and then Is_Inert_LDML_Container_Name (Name)
           and then Line (Line'First) = '<'
           and then Line (Line'First + 1) = '/'
           and then Line (Line'Last) = '>';
      end Is_Inert_LDML_Container_Close;

      function With_LDML_Context_Locale (Line : String) return String is
         function Inject_Attribute
           (Base : String;
            Name : String;
            Value : String) return String
         is
         begin
            for Index in Base'Range loop
               if Base (Index) = '>' then
                  if Index > Base'First and then Base (Index - 1) = '/' then
                     return Base (Base'First .. Index - 2)
                       & " " & Name & "=""" & Value & """/>";
                  end if;

                  return Base (Base'First .. Index - 1)
                    & " " & Name & "=""" & Value & """"
                    & Base (Index .. Base'Last);
               end if;
            end loop;

            return Base;
         end Inject_Attribute;

         Locale_Value : constant String := To_String (LDML_Context_Locale);
         Calendar_Value : constant String :=
           To_String (LDML_Context_Calendar);
         Date_Name_Context_Value : constant String :=
           To_String (LDML_Context_Date_Name_Context);
         Date_Name_Width_Value : constant String :=
           To_String (LDML_Context_Date_Name_Width);
         Day_Period_Width_Value : constant String :=
           To_String (LDML_Context_Day_Period_Width);
         Zone_Value : constant String := To_String (LDML_Context_Zone);
         Unit_Value : constant String := To_String (LDML_Context_Unit);
         Unit_Width_Value : constant String :=
           To_String (LDML_Context_Unit_Width);
         Compound_Unit_Value : constant String :=
           To_String (LDML_Context_Compound_Unit);
         Number_System_Value : constant String :=
           To_String (LDML_Context_Number_System);
         Relative_Unit_Value : constant String :=
           To_String (LDML_Context_Relative_Unit);
         Relative_Width_Value : constant String :=
           To_String (LDML_Context_Relative_Width);
         Relative_Direction_Value : constant String :=
           To_String (LDML_Context_Relative_Direction);
         List_Pattern_Value : constant String :=
           To_String (LDML_Context_List_Pattern);
         Currency_Value : constant String :=
           To_String (LDML_Context_Currency);
         Currency_Spacing_Value : constant String :=
           To_String (LDML_Context_Currency_Spacing);
      begin
         declare
            With_Locale : constant String :=
              (if LDML_Context_Open
                 and then Locale_Value /= ""
                 and then Is_LDML_Row (Line)
                 and then Attribute_Value (Line, "locale") = ""
               then Inject_Attribute (Line, "locale", Locale_Value)
               else Line);
         begin
            if LDML_Context_Open
              and then Calendar_Value /= ""
              and then (Starts_With (With_Locale, "<era ")
                        or else Starts_With (With_Locale, "<eraSeparator "))
              and then Attribute_Value (With_Locale, "calendar") = ""
            then
               return Inject_Attribute
                 (With_Locale, "calendar", Calendar_Value);
            elsif LDML_Context_Open
              and then Zone_Value /= ""
              and then Attribute_Value (With_Locale, "id", "zone") = ""
              and then
                (Starts_With (With_Locale, "<zoneName ")
                 or else Starts_With (With_Locale, "<timeZoneName ")
                 or else Starts_With (With_Locale, "<zoneExemplar ")
                 or else Starts_With (With_Locale, "<exemplarCity ")
                 or else Starts_With (With_Locale, "<zoneShort ")
                 or else Starts_With (With_Locale, "<zoneShortStandard ")
                 or else Starts_With (With_Locale, "<zoneStandardShort ")
                 or else Starts_With (With_Locale, "<zoneShortDaylight ")
                 or else Starts_With (With_Locale, "<zoneDaylightShort ")
                 or else Starts_With (With_Locale, "<zoneGenericShort ")
                 or else Starts_With (With_Locale, "<zoneShortGeneric ")
                 or else Starts_With (With_Locale, "<generic ")
                 or else Starts_With (With_Locale, "<generic>")
                 or else Starts_With (With_Locale, "<standard ")
                 or else Starts_With (With_Locale, "<standard>")
                 or else Starts_With (With_Locale, "<daylight ")
                 or else Starts_With (With_Locale, "<daylight>"))
            then
               return Inject_Attribute (With_Locale, "zone", Zone_Value);
            end if;

            declare
               Needs_Date_Name_Context : constant Boolean :=
                 Starts_With (With_Locale, "<month ")
                 or else Starts_With (With_Locale, "<quarter ")
                 or else Starts_With (With_Locale, "<weekday ")
                 or else Starts_With (With_Locale, "<day ");
               With_Date_Name_Context : constant String :=
                 (if LDML_Context_Open
                    and then Date_Name_Context_Value /= ""
                    and then Needs_Date_Name_Context
                    and then Attribute_Value (With_Locale, "context") = ""
                  then Inject_Attribute
                    (With_Locale, "context", Date_Name_Context_Value)
                  else With_Locale);
               With_Date_Name_Width : constant String :=
                 (if LDML_Context_Open
                    and then Date_Name_Width_Value /= ""
                    and then Needs_Date_Name_Context
                    and then Attribute_Value
                      (With_Date_Name_Context, "width") = ""
                  then Inject_Attribute
                    (With_Date_Name_Context, "width", Date_Name_Width_Value)
                  else With_Date_Name_Context);
               With_Day_Period_Width : constant String :=
                 (if LDML_Context_Open
                    and then Day_Period_Width_Value /= ""
                    and then Starts_With (With_Date_Name_Width, "<dayPeriod ")
                    and then Attribute_Value
                      (With_Date_Name_Width, "width") = ""
                  then Inject_Attribute
                    (With_Date_Name_Width, "width",
                     Day_Period_Width_Value)
                  else With_Date_Name_Width);
               Needs_Symbol_Context : constant Boolean :=
                 Starts_With (With_Day_Period_Width, "<decimal ")
                 or else Starts_With (With_Day_Period_Width, "<decimal>")
                 or else Starts_With (With_Day_Period_Width, "<group ")
                 or else Starts_With (With_Day_Period_Width, "<group>")
                 or else Starts_With (With_Day_Period_Width, "<percentSign ")
                 or else Starts_With (With_Day_Period_Width, "<percentSign>")
                 or else Starts_With (With_Day_Period_Width, "<perMille ")
                 or else Starts_With (With_Day_Period_Width, "<perMille>")
                 or else Starts_With (With_Day_Period_Width, "<plusSign ")
                 or else Starts_With (With_Day_Period_Width, "<plusSign>")
                 or else Starts_With (With_Day_Period_Width, "<minusSign ")
                 or else Starts_With (With_Day_Period_Width, "<minusSign>")
                 or else Starts_With (With_Day_Period_Width, "<exponential ")
                 or else Starts_With (With_Day_Period_Width, "<exponential>");
               With_Number_System : constant String :=
                 (if LDML_Context_Open
                    and then Number_System_Value /= ""
                    and then Needs_Symbol_Context
                    and then Attribute_Value
                      (With_Day_Period_Width, "numberSystem") = ""
                  then Inject_Attribute
                    (With_Day_Period_Width, "numberSystem",
                     Number_System_Value)
                  else With_Day_Period_Width);
               Needs_Unit_Context : constant Boolean :=
                 Starts_With (With_Number_System, "<unitName ")
                 or else Starts_With (With_Number_System, "<unitDisplayName ")
                 or else Starts_With (With_Number_System, "<displayName ")
                 or else Starts_With (With_Number_System, "<displayName>")
                 or else Starts_With (With_Number_System, "<unitPattern ");
               With_Unit : constant String :=
                 (if LDML_Context_Open
                    and then Unit_Value /= ""
                    and then Needs_Unit_Context
                    and then Attribute_Value (With_Number_System, "unit") = ""
                    and then Attribute_Value (With_Number_System, "type") = ""
                  then Inject_Attribute
                    (With_Number_System, "unit", Unit_Value)
                  else With_Number_System);
               With_Unit_Width : constant String :=
                 (if LDML_Context_Open
                    and then Unit_Width_Value /= ""
                    and then Needs_Unit_Context
                    and then Attribute_Value (With_Unit, "width") = ""
                 then Inject_Attribute
                    (With_Unit, "width", Unit_Width_Value)
                  else With_Unit);
            begin
               if LDML_Context_Open
                 and then
                   (Starts_With (With_Unit_Width, "<compoundUnitPattern ")
                    or else
                      Starts_With (With_Unit_Width, "<compoundUnitPattern>"))
               then
                  declare
                     With_Compound_Type : constant String :=
                       (if Compound_Unit_Value /= ""
                          and then
                            Attribute_Value (With_Unit_Width, "type") = ""
                        then Inject_Attribute
                          (With_Unit_Width, "type", Compound_Unit_Value)
                        else With_Unit_Width);
                  begin
                     if Unit_Width_Value /= ""
                       and then
                         Attribute_Value (With_Compound_Type, "width") = ""
                     then
                        return Inject_Attribute
                          (With_Compound_Type, "width", Unit_Width_Value);
                     else
                        return With_Compound_Type;
                     end if;
                  end;
               else
                  declare
                     Needs_Relative_Context : constant Boolean :=
                       Starts_With (With_Unit_Width, "<relative ")
                       or else Starts_With (With_Unit_Width, "<relative>")
                       or else Starts_With
                         (With_Unit_Width, "<relativeUnit ")
                       or else Starts_With
                         (With_Unit_Width, "<relativeTimePattern ")
                       or else Starts_With
                         (With_Unit_Width, "<relativeTime ");
                     With_Relative_Unit : constant String :=
                       (if Relative_Unit_Value /= ""
                          and then Needs_Relative_Context
                          and then Attribute_Value
                            (With_Unit_Width, "unit") = ""
                          and then Attribute_Value
                            (With_Unit_Width, "relativeUnit") = ""
                          and then
                            (Attribute_Value (With_Unit_Width, "type") = ""
                             or else Starts_With
                               (With_Unit_Width, "<relative "))
                        then Inject_Attribute
                          (With_Unit_Width, "unit", Relative_Unit_Value)
                        else With_Unit_Width);
                     With_Relative_Width : constant String :=
                       (if Relative_Width_Value /= ""
                          and then Needs_Relative_Context
                          and then Attribute_Value
                            (With_Relative_Unit, "width") = ""
                          and then Attribute_Value
                            (With_Relative_Unit, "unitWidth") = ""
                        then Inject_Attribute
                          (With_Relative_Unit, "unitWidth",
                           Relative_Width_Value)
                        else With_Relative_Unit);
                     With_Relative_Direction : constant String :=
                       (if Relative_Direction_Value /= ""
                          and then
                            (Starts_With
                               (With_Relative_Width,
                                "<relativeTimePattern ")
                             or else Starts_With
                               (With_Relative_Width, "<relativeTime "))
                          and then Attribute_Value
                            (With_Relative_Width, "type") = ""
                        then Inject_Attribute
                          (With_Relative_Width, "type",
                           Relative_Direction_Value)
                        else With_Relative_Width);
                     With_List_Type : constant String :=
                       (if List_Pattern_Value /= ""
                          and then
                            Starts_With
                              (With_Relative_Direction,
                               "<listPatternPart ")
                          and then
                            Attribute_Value
                              (With_Relative_Direction,
                               "listPatternType") = ""
                        then Inject_Attribute
                          (With_Relative_Direction, "listPatternType",
                           List_Pattern_Value)
                        else With_Relative_Direction);
                     With_Currency_Code : constant String :=
                       (if Currency_Value /= ""
                          and then
                            (Starts_With (With_List_Type, "<displayName ")
                             or else Starts_With (With_List_Type,
                                                  "<displayName>")
                             or else Starts_With (With_List_Type, "<symbol ")
                             or else Starts_With (With_List_Type,
                                                  "<symbol>"))
                          and then
                            Attribute_Value (With_List_Type, "type") = ""
                          and then
                            Attribute_Value (With_List_Type, "code") = ""
                          and then
                            Attribute_Value (With_List_Type, "iso4217") = ""
                        then Inject_Attribute
                          (With_List_Type, "code", Currency_Value)
                        else With_List_Type);
                  begin
                     if Currency_Spacing_Value /= ""
                       and then
                         (Starts_With
                            (With_Currency_Code, "<insertBetween ")
                          or else Starts_With
                            (With_Currency_Code, "<insertBetween>"))
                       and then
                         Attribute_Value
                           (With_Currency_Code, "beforeCurrency") = ""
                     then
                        return Inject_Attribute
                          (With_Currency_Code, "beforeCurrency",
                           (if Currency_Spacing_Value = "before"
                            then "true" else "false"));
                     else
                        return With_Currency_Code;
                     end if;
                  end;
               end if;
            end;
         end;
      end With_LDML_Context_Locale;

      function With_LDML_Context (Line : String) return String is
         function Inject_Attribute
           (Base : String;
            Name : String;
            Value : String) return String
         is
         begin
            for Index in Base'Range loop
               if Base (Index) = '>' then
                  if Index > Base'First and then Base (Index - 1) = '/' then
                     return Base (Base'First .. Index - 2)
                       & " " & Name & "=""" & Value & """/>";
                  end if;

                  return Base (Base'First .. Index - 1)
                    & " " & Name & "=""" & Value & """"
                    & Base (Index .. Base'Last);
               end if;
            end loop;

            return Base;
         end Inject_Attribute;

         With_Locale : constant String := With_LDML_Context_Locale (Line);
         Plurals_Kind_Value : constant String :=
           To_String (LDML_Context_Plurals_Kind);
         Plural_Rules_Kind_Value : constant String :=
           To_String (LDML_Context_Plural_Rules_Kind);
         Plural_Rules_Locales_Value : constant String :=
           To_String (LDML_Context_Plural_Rules_Locales);
         Plural_Kind_Value : constant String :=
           (if Plural_Rules_Kind_Value /= "" then Plural_Rules_Kind_Value
            else Plurals_Kind_Value);
         Day_Period_Rules_Locales_Value : constant String :=
           (if To_String (LDML_Context_Day_Period_Rules_Locales) /= ""
            then To_String (LDML_Context_Day_Period_Rules_Locales)
            else To_String (LDML_Context_Day_Period_Rule_Set_Locales));
         RBNF_Ruleset_Value : constant String :=
           To_String (LDML_Context_RBNF_Ruleset);
      begin
         declare
            With_Plural_Kind : constant String :=
              (if Plural_Kind_Value /= ""
                 and then Starts_With (With_Locale, "<pluralRule ")
                 and then Attribute_Value (With_Locale, "type", "kind") = ""
               then Inject_Attribute
                 (With_Locale, "type", Plural_Kind_Value)
               else With_Locale);
            With_Plural_Locales : constant String :=
              (if Plural_Rules_Locales_Value /= ""
                 and then Starts_With (With_Plural_Kind, "<pluralRule ")
                 and then Attribute_Value (With_Plural_Kind, "locale") = ""
                 and then Attribute_Value (With_Plural_Kind, "locales") = ""
               then Inject_Attribute
                 (With_Plural_Kind, "locales", Plural_Rules_Locales_Value)
               else With_Plural_Kind);
            With_Day_Period_Locales : constant String :=
              (if Day_Period_Rules_Locales_Value /= ""
                 and then Starts_With
                   (With_Plural_Locales, "<dayPeriodRule ")
                 and then Attribute_Value
                   (With_Plural_Locales, "locale") = ""
                 and then Attribute_Value
                   (With_Plural_Locales, "locales") = ""
               then Inject_Attribute
                 (With_Plural_Locales, "locales",
                  Day_Period_Rules_Locales_Value)
               else With_Plural_Locales);
         begin
            if LDML_Context_Open
              and then RBNF_Ruleset_Value /= ""
              and then
                (Starts_With (With_Day_Period_Locales, "<rbnf ")
                 or else Starts_With (With_Day_Period_Locales, "<rbnfRule ")
                 or else Starts_With (With_Day_Period_Locales, "<rbnfRule>")
                 or else Starts_With (With_Day_Period_Locales, "<rbnfrule ")
                 or else Starts_With (With_Day_Period_Locales, "<rbnfrule>"))
              and then Attribute_Value (With_Day_Period_Locales, "type") = ""
              and then Attribute_Value (With_Day_Period_Locales, "ruleSet") = ""
              and then Attribute_Value (With_Day_Period_Locales, "ruleset") = ""
            then
               return Inject_Attribute
                 (With_Day_Period_Locales, "ruleSet", RBNF_Ruleset_Value);
            else
               return With_Day_Period_Locales;
            end if;
         end;
      end With_LDML_Context;

      procedure Append_LDML_Block_Text (Line : String) is
         Current : constant String := To_String (LDML_Block_Text);
      begin
         if Current'Length > 0 and then Line'Length > 0 then
            Append (LDML_Block_Text, " ");
         end if;

         Append (LDML_Block_Text, Line);
      end Append_LDML_Block_Text;

      procedure Reset_LDML_Block is
      begin
         LDML_Block_Open := False;
         LDML_Block_Start_Line := 0;
         LDML_Block_Open_Tag := Null_Unbounded_String;
         LDML_Block_End_Tag := Null_Unbounded_String;
         LDML_Block_Text := Null_Unbounded_String;
      end Reset_LDML_Block;

      function Loaded_Default_Numbering_System (Locale : String) return String is
         Key : constant String := Locale_Key (Locale, "default_numbering_system");
      begin
         if Pending_Locales.Contains (Key) then
            return Pending_Locales.Element (Key);
         elsif Locale_Overrides.Contains (Key) then
            return Locale_Overrides.Element (Key);
         end if;

         return "";
      end Loaded_Default_Numbering_System;

      function Should_Apply_Symbol_Row
        (Locale        : String;
         Number_System : String)
         return Boolean
      is
         Default_System : constant String :=
           Loaded_Default_Numbering_System (Locale);
      begin
         return Number_System = ""
           or else (Default_System = "" and then Number_System = "latn")
           or else (Default_System /= ""
                    and then Number_System = Default_System);
      end Should_Apply_Symbol_Row;

      procedure Store_LDML_Number_Symbol
        (Locale        : String;
         Number_System : String;
         Field_Name    : String;
         Value         : String;
         Source        : String;
         Number        : Natural)
      is
      begin
         if Locale = "" then
            Add_Error (Diagnostics, Source, Number,
                       "invalid LDML number-symbol row");
            Ok := False;
         elsif not Should_Apply_Symbol_Row (Locale, Number_System) then
            null;
         elsif Value = "" then
            Add_Error (Diagnostics, Source, Number,
                       "invalid LDML number-symbol row");
            Ok := False;
         else
            Store (Pending_Locales, Locale_Key (Locale, Field_Name), Value);
         end if;
      end Store_LDML_Number_Symbol;

      procedure Parse_LDML_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Locale : constant String := Attribute_Value (Line, "locale");
      begin
         if Starts_With (Line, "<symbols ") then
            declare
               Number_System : constant String :=
                 Attribute_Value (Line, "numberSystem");
               Decimal : constant String := Attribute_Value (Line, "decimal");
               Group   : constant String := Attribute_Value (Line, "group");
               Percent : constant String :=
                 Attribute_Value (Line, "percent", "percentSign");
               Permille : constant String :=
                 Attribute_Value (Line, "permille", "perMille");
               Plus    : constant String :=
                 Attribute_Value (Line, "plus", "plusSign");
               Minus   : constant String :=
                 Attribute_Value (Line, "minus", "minusSign");
               Exponent : constant String :=
                 Attribute_Value (Line, "exponent", "exponential");
               Accounting_Prefix : constant String :=
                 Attribute_Value (Line, "accountingPrefix");
               Accounting_Suffix : constant String :=
                 Attribute_Value (Line, "accountingSuffix");
            begin
               if Locale = "" then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML symbols row");
                  Ok := False;
               elsif not Should_Apply_Symbol_Row (Locale, Number_System) then
                  null;
               elsif Decimal = "" or else Group = "" then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML symbols row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "decimal_separator"), Decimal);
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "group_separator"), Group);
                  if Percent /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_percent_suffix"),
                        Percent);
                  end if;
                  if Permille /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_permille_suffix"),
                        Permille);
                  end if;
                  if Plus /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_plus_sign"), Plus);
                  end if;
                  if Minus /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_minus_sign"), Minus);
                  end if;
                  if Exponent /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_exponent_separator"),
                        Exponent);
                  end if;
                  if Accounting_Prefix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_accounting_prefix"),
                        Accounting_Prefix);
                  end if;
                  if Accounting_Suffix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "number_accounting_suffix"),
                        Accounting_Suffix);
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<defaultNumberingSystem ")
           or else Starts_With (Line, "<defaultNumberingSystem>")
         then
            declare
               Value : constant String := Element_Text (Line);
            begin
               if Locale = ""
                 or else not Valid_Locale_Field
                   ("default_numbering_system", Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML default numbering-system row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "default_numbering_system"),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<decimal ")
           or else Starts_With (Line, "<decimal>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "decimal_separator", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<group ")
           or else Starts_With (Line, "<group>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "group_separator", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<percentSign ")
           or else Starts_With (Line, "<percentSign>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "number_percent_suffix", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<perMille ")
           or else Starts_With (Line, "<perMille>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "number_permille_suffix", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<plusSign ")
           or else Starts_With (Line, "<plusSign>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "number_plus_sign", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<minusSign ")
           or else Starts_With (Line, "<minusSign>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "number_minus_sign", Element_Text (Line), Source, Number);
         elsif Starts_With (Line, "<exponential ")
           or else Starts_With (Line, "<exponential>")
         then
            Store_LDML_Number_Symbol
              (Locale, Attribute_Value (Line, "numberSystem"),
               "number_exponent_separator", Element_Text (Line),
               Source, Number);
         elsif Starts_With (Line, "<month ")
           or else Starts_With (Line, "<quarter ")
           or else Starts_With (Line, "<weekday ")
           or else Starts_With (Line, "<day ")
         then
            declare
               Raw_Type   : constant String := Attribute_Value (Line, "type");
               Raw_Width  : constant String := Attribute_Value (Line, "width");
               Raw_Context : constant String :=
                 Attribute_Value (Line, "context");
               Value      : constant String := Element_Text (Line);
               Base       : constant String :=
                 (if Starts_With (Line, "<month ") then "month"
                  elsif Starts_With (Line, "<quarter ") then "quarter"
                  else "weekday");
               Is_Standalone : constant Boolean :=
                 Raw_Context = "stand-alone"
                 or else Raw_Context = "standalone";
               Explicit_Index : constant String :=
                 Attribute_Value (Line, "index");
               Index_Text : constant String :=
                 (if Explicit_Index /= "" then Explicit_Index
                  elsif In_Integer_Range (Raw_Type) then Raw_Type
                  elsif Base = "weekday" then Weekday_Type_Index (Raw_Type)
                  else "");
               Width      : constant String :=
                 (if Raw_Width /= "" then Raw_Width
                  elsif Explicit_Index /= "" then Raw_Type
                  elsif In_Integer_Range (Raw_Type) then ""
                  else Raw_Type);
               Field_Name : constant String :=
                 Base
                 & (if Is_Standalone then "_standalone" else "")
                 & (if Width = "abbreviated" or else Width = "short"
                       or else Width = "abbrev"
                    then "_short"
                    elsif Width = "narrow"
                    then "_narrow"
                    else "");
            begin
               if Locale = ""
                 or else Value = ""
                 or else not In_Integer_Range (Index_Text)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML name row");
                  Ok := False;
               else
                  declare
                     Name_Index : constant Integer :=
                       Integer'Value (Index_Text);
                  begin
                     if (Base = "month" and then Name_Index not in 1 .. 12)
                       or else
                         (Base = "quarter" and then Name_Index not in 1 .. 4)
                       or else
                         (Base = "weekday" and then Name_Index not in 0 .. 6)
                     then
                        Add_Error (Diagnostics, Source, Number,
                                   "invalid LDML name index");
                        Ok := False;
                        return;
                     end if;
                  end;

                  Store
                    (Pending_Locales,
                     Locale_Key
                       (Locale,
                        Field_Name & "." & Natural_Text
                          (Natural (Integer'Value (Index_Text)))),
                     Value);
               end if;
            exception
               when Constraint_Error =>
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML name index");
                  Ok := False;
            end;
         elsif Starts_With (Line, "<dayPeriod ") then
            declare
               Period : constant String := Attribute_Value (Line, "type");
               Width  : constant String := Attribute_Value (Line, "width");
               Value  : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 (if Width = "wide" then "day_period_wide."
                  elsif Width = "narrow" then "day_period_narrow."
                  else "day_period.") & Period;
            begin
               if Locale = ""
                 or else Value = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML day-period row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<dayPeriodRule ") then
            declare
               Period : constant String := Attribute_Value (Line, "type");
               From   : constant String := Attribute_Value (Line, "from");
               Before : constant String := Attribute_Value (Line, "before");
               At_Time : constant String := Attribute_Value (Line, "at");
               Locales : constant String :=
                 (if Attribute_Value (Line, "locales") /= ""
                  then Attribute_Value (Line, "locales")
                  else Locale);
            begin
               if Element_Text (Line) /= "" then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML dayPeriodRule row");
                  Ok := False;
               elsif At_Time /= "" then
                  if From /= "" or else Before /= "" then
                     Add_Error (Diagnostics, Source, Number,
                                "invalid LDML dayPeriodRule row");
                     Ok := False;
                  else
                     Store_Day_Period_At_Rule_List
                       (Locales, Period, At_Time, Source, Number);
                  end if;
               else
                  Store_Day_Period_Rule_List
                    (Locales, Period, From, Before, Source, Number);
               end if;
            end;
         elsif Starts_With (Line, "<era ") then
            declare
               Calendar : constant String :=
                 Normalize_Calendar_Name (Attribute_Value (Line, "calendar"));
               Era      : constant String :=
                 Normalize_Era_Name
                   (Calendar, Attribute_Value (Line, "type"));
               Value    : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "era." & Calendar & "." & Era;
            begin
               if Locale = ""
                 or else Calendar = ""
                 or else Era = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML era row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<eraSeparator ") then
            declare
               Calendar : constant String :=
                 Normalize_Calendar_Name (Attribute_Value (Line, "calendar"));
               Value    : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "era_separator." & Calendar;
            begin
               if Locale = ""
                 or else Calendar = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML era-separator row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<zoneName ")
           or else Starts_With (Line, "<timeZoneName ")
         then
            declare
               Zone  : constant String := Attribute_Value (Line, "id", "zone");
               Name_Type : constant String := Attribute_Value (Line, "type");
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 (if Name_Type = ""
                    or else Name_Type = "long"
                    or else Name_Type = "generic"
                  then "timezone_display."
                  elsif Name_Type = "standard"
                    or else Name_Type = "long-standard"
                    or else Name_Type = "standard-long"
                    or else Name_Type = "standardLong"
                    or else Name_Type = "longStandard"
                  then "timezone_display_standard."
                  elsif Name_Type = "daylight"
                    or else Name_Type = "long-daylight"
                    or else Name_Type = "daylight-long"
                    or else Name_Type = "daylightLong"
                    or else Name_Type = "longDaylight"
                  then "timezone_display_daylight."
                  elsif Name_Type = "short"
                    or else Name_Type = "standard-short"
                    or else Name_Type = "short-standard"
                    or else Name_Type = "standardShort"
                    or else Name_Type = "shortStandard"
                  then "timezone_short."
                  elsif Name_Type = "daylight-short"
                    or else Name_Type = "short-daylight"
                    or else Name_Type = "daylightShort"
                    or else Name_Type = "shortDaylight"
                  then "timezone_short_daylight."
                  elsif Name_Type = "generic-short"
                    or else Name_Type = "short-generic"
                    or else Name_Type = "genericShort"
                    or else Name_Type = "shortGeneric"
                  then "timezone_generic_short."
                  else "") & Zone;
            begin
               if Locale = ""
                 or else Zone = ""
                 or else Field_Name = Zone
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML zone-name row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<zoneExemplar ")
           or else Starts_With (Line, "<exemplarCity ")
         then
            declare
               Zone  : constant String := Attribute_Value (Line, "id", "zone");
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "timezone_exemplar." & Zone;
            begin
               if Locale = ""
                 or else Zone = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML zone-exemplar row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<zoneShort ")
           or else Starts_With (Line, "<zoneShortStandard ")
           or else Starts_With (Line, "<zoneStandardShort ")
           or else Starts_With (Line, "<zoneShortDaylight ")
           or else Starts_With (Line, "<zoneDaylightShort ")
           or else Starts_With (Line, "<zoneGenericShort ")
           or else Starts_With (Line, "<zoneShortGeneric ")
         then
            declare
               Zone  : constant String := Attribute_Value (Line, "id", "zone");
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 (if Starts_With (Line, "<zoneShortDaylight ")
                    or else Starts_With (Line, "<zoneDaylightShort ")
                  then "timezone_short_daylight."
                  elsif Starts_With (Line, "<zoneGenericShort ")
                    or else Starts_With (Line, "<zoneShortGeneric ")
                  then "timezone_generic_short."
                  else "timezone_short.") & Zone;
            begin
               if Locale = ""
                 or else Zone = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML short-zone row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<generic ")
           or else Starts_With (Line, "<generic>")
           or else Starts_With (Line, "<standard ")
           or else Starts_With (Line, "<standard>")
           or else Starts_With (Line, "<daylight ")
           or else Starts_With (Line, "<daylight>")
         then
            declare
               Zone  : constant String := Attribute_Value (Line, "id", "zone");
               Value : constant String := Element_Text (Line);
               Width : constant String :=
                 To_String (LDML_Context_Zone_Width);
               Is_Short : constant Boolean := Width = "short";
               Field_Name : constant String :=
                 (if Starts_With (Line, "<generic")
                  then (if Is_Short
                        then "timezone_generic_short."
                        else "timezone_display.")
                  elsif Starts_With (Line, "<daylight")
                  then (if Is_Short
                        then "timezone_short_daylight."
                        else "timezone_display_daylight.")
                  else (if Is_Short
                        then "timezone_short."
                        else "timezone_display_standard."))
                 & Zone;
            begin
               if Locale = ""
                 or else Zone = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML CLDR zone-name row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<zoneLocationPattern ")
           or else Starts_With (Line, "<regionFormat ")
         then
            declare
               Value : constant String := Element_Text (Line);
               Region_Type : constant String := Attribute_Value (Line, "type");
               Field_Name : constant String :=
                 (if Region_Type = "standard"
                  then "timezone_location_pattern_standard"
                  elsif Region_Type = "daylight"
                  then "timezone_location_pattern_daylight"
                  else "timezone_location_pattern");
               Row_Name : constant String :=
                 (if Starts_With (Line, "<regionFormat ")
                  then "region-format"
                  else "zone-location-pattern");
            begin
               if Locale = ""
                 or else (Starts_With (Line, "<regionFormat ")
                          and then Region_Type /= ""
                          and then Region_Type /= "generic"
                          and then Region_Type /= "standard"
                          and then Region_Type /= "daylight")
                 or else Occurrence_Count (Value, "{0}") /= 1
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML " & Row_Name & " row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<gmtFormat ")
           or else Starts_With (Line, "<gmtZeroFormat ")
           or else Starts_With (Line, "<hourFormat ")
         then
            declare
               Value : constant String := Element_Text (Line);
               Pattern_OK : Boolean := True;
               Field_Name : constant String :=
                 (if Starts_With (Line, "<gmtFormat ")
                  then "gmt_offset_prefix"
                  elsif Starts_With (Line, "<gmtZeroFormat ")
                  then "timezone_utc_designator"
                  else "timezone_offset_separator");
               Field_Value : constant String :=
                 (if Starts_With (Line, "<gmtFormat ")
                  then GMT_Format_Prefix_From_Pattern (Value, Pattern_OK)
                  elsif Starts_With (Line, "<hourFormat ")
                  then Hour_Format_Separator_From_Pattern (Value, Pattern_OK)
                  else Value);
               Row_Name : constant String :=
                 (if Starts_With (Line, "<gmtFormat ")
                  then "gmt-format"
                  elsif Starts_With (Line, "<gmtZeroFormat ")
                  then "gmt-zero-format"
                  else "hour-format");
            begin
               if Locale = ""
                 or else not Pattern_OK
                 or else not Valid_Locale_Field (Field_Name, Field_Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML " & Row_Name & " row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Field_Value);
               end if;
            end;
         elsif (Starts_With (Line, "<displayName ")
                or else Starts_With (Line, "<displayName>"))
           and then (Attribute_Value (Line, "code") /= ""
                     or else Attribute_Value (Line, "iso4217") /= "")
         then
            declare
               Raw_Code : constant String := Attribute_Value (Line, "code");
               Code     : constant String :=
                 (if Raw_Code /= "" then Raw_Code
                  else Attribute_Value (Line, "iso4217"));
               Raw_Category : constant String :=
                 Attribute_Value (Line, "category", "count");
               Category : constant String :=
                 (if Raw_Category /= "" then Raw_Category else "other");
               Value    : constant String := Element_Text (Line);
            begin
               if Locale = ""
                 or else Code'Length /= 3
                 or else not Is_Plural_Category (Category)
                 or else Value = ""
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML currency-name row");
                  Ok := False;
               else
                  Store
                    (Pending_Locale_Currencies,
                     Locale_Currency_Key
                       (Locale, Code, "display_name." & Category),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<unitName ")
           or else Starts_With (Line, "<unitDisplayName ")
           or else Starts_With (Line, "<displayName ")
           or else Starts_With (Line, "<displayName>")
           or else Starts_With (Line, "<unitPattern ")
         then
            declare
               Pattern_Row : constant Boolean :=
                 Starts_With (Line, "<unitPattern ");
               Display_Name_Row : constant Boolean :=
                 Starts_With (Line, "<unitDisplayName ")
                 or else Starts_With (Line, "<displayName ")
                 or else Starts_With (Line, "<displayName>");
               Raw_Unit : constant String := Attribute_Value (Line, "unit");
               Raw_Type : constant String := Attribute_Value (Line, "type");
               Unit  : constant String :=
                 Normalize_Unit_Base
                   ((if Raw_Unit /= "" then Raw_Unit else Raw_Type));
               Raw_Width : constant String := Attribute_Value (Line, "width");
               Width : constant String :=
                 Normalize_Unit_Width
                   ((if Raw_Width /= "" then Raw_Width
                     elsif Raw_Unit /= "" and then Raw_Type /= ""
                     then Raw_Type
                     else ""));
               Raw_Count : constant String := Attribute_Value (Line, "count");
               Count : constant String :=
                 (if Raw_Count /= "" then Raw_Count
                  elsif Display_Name_Row or else not Pattern_Row then "other"
                  else "");
               Raw_Value : constant String := Element_Text (Line);
               Valid_Pattern : Boolean := True;
               Value : constant String :=
                 (if Pattern_Row
                  then Unit_Pattern_Name (Raw_Value, Valid_Pattern)
                  else Raw_Value);
               Field_Name : constant String :=
                 "unit." & Unit & "." & Width & "." & Count;
               Pattern_Field : constant String :=
                 "unit_pattern." & Unit & "." & Width & "." & Count;
            begin
               if Locale = ""
                 or else Unit = ""
                 or else not Is_Supported_Unit_Base (Unit)
                 or else Width = ""
                 or else not Is_CLDR_Count_Name (Count)
                 or else (Pattern_Row
                          and then not Valid_Locale_Field
                            (Pattern_Field, Raw_Value))
                 or else ((not Pattern_Row or else Valid_Pattern)
                          and then
                            not Valid_Locale_Field (Field_Name, Value))
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML unit row");
                  Ok := False;
               else
                  if Pattern_Row then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, Pattern_Field),
                        Raw_Value);
                  end if;

                  if not Pattern_Row or else Valid_Pattern then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, Field_Name),
                        Value);
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<compoundUnitPattern ")
           or else Starts_With (Line, "<compoundUnitPattern>")
         then
            declare
               Kind : constant String := Attribute_Value (Line, "type");
               Width_Text : constant String :=
                 Attribute_Value (Line, "width", "unitWidth");
               Width : constant String := Normalize_Unit_Width (Width_Text);
               Raw_Value : constant String := Element_Text (Line);
               Valid_Pattern : Boolean := True;
               Value : constant String :=
                 List_Pattern_Separator (Raw_Value, Valid_Pattern);
               Field_Name : constant String :=
                 (if Width = "unit-width-short"
                     or else Width = "unit-width-narrow"
                  then "unit_short_per_separator"
                  else "per_unit_separator");
            begin
               if Locale = ""
                 or else Kind /= "per"
                 or else Value = ""
                 or else not Valid_Pattern
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML compound-unit-pattern row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<relativeName ")
           or else Starts_With (Line, "<relativePeriod ")
         then
            declare
               Unit  : constant String :=
                 Normalize_Relative_Unit
                   (Attribute_Value (Line, "unit", "type"));
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "relative_current." & Unit;
            begin
               if Locale = ""
                 or else Unit = ""
                 or else not Is_Supported_Relative_Unit (Unit)
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML relative-period row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<relative ")
           or else Starts_With (Line, "<relative>")
         then
            declare
               Raw_Unit : constant String := Attribute_Value (Line, "unit");
               Unit  : constant String :=
                 Normalize_Relative_Unit
                   ((if Raw_Unit /= "" then Raw_Unit
                     else Attribute_Value (Line, "relativeUnit")));
               Offset : constant String := Attribute_Value (Line, "type");
               Width_Text : constant String :=
                 Attribute_Value (Line, "width", "unitWidth");
               Width : constant String :=
                 (if Width_Text = "" then "unit-width-full-name"
                  elsif Width_Text = "short" then "unit-width-short"
                  elsif Width_Text = "narrow" then "unit-width-narrow"
                  elsif Width_Text = "long" then "unit-width-full-name"
                  elsif Width_Text = "full-name" then "unit-width-full-name"
                  else Width_Text);
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "relative_exact." & Unit & "." & Width & "." & Offset;
            begin
               if Locale = ""
                 or else Unit = ""
                 or else not Is_Supported_Relative_Unit (Unit)
                 or else not Is_Integer_Text (Offset)
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML relative row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<relativeUnit ") then
            declare
               Unit  : constant String :=
                 Normalize_Relative_Unit
                   (Attribute_Value (Line, "unit", "type"));
               Count : constant String := Attribute_Value (Line, "count");
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "relative_unit." & Unit & "." & Count;
            begin
               if Locale = ""
                 or else Unit = ""
                 or else not Is_Supported_Relative_Unit (Unit)
                 or else not Is_CLDR_Count_Name (Count)
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML relative-unit row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<relativePattern ")
           or else Starts_With (Line, "<relativeTime ")
           or else Starts_With (Line, "<relativeTimePattern ")
         then
            declare
               Direction : constant String := Attribute_Value (Line, "type");
               Raw_Unit  : constant String := Attribute_Value (Line, "unit");
               Unit      : constant String :=
                 Normalize_Relative_Unit
                   ((if Raw_Unit /= ""
                     then Raw_Unit
                     else Attribute_Value (Line, "relativeUnit")));
               Width_Text : constant String :=
                 Attribute_Value (Line, "width", "unitWidth");
               Width      : constant String :=
                 (if Width_Text = "" then "unit-width-full-name"
                  elsif Width_Text = "short" then "unit-width-short"
                  elsif Width_Text = "narrow" then "unit-width-narrow"
                  elsif Width_Text = "long" then "unit-width-full-name"
                  elsif Width_Text = "full-name" then "unit-width-full-name"
                  else Width_Text);
               Count     : constant String := Attribute_Value (Line, "count");
               Raw_Value : constant String := Element_Text (Line);
               Valid_Prefix : Boolean := True;
               Valid_Suffix : Boolean := True;
               Direct_Row : constant Boolean :=
                 (Starts_With (Line, "<relativeTimePattern ")
                  or else Starts_With (Line, "<relativeTime "))
                 and then Unit /= ""
                 and then Count /= "";
               Pattern_Field : constant String :=
                 "relative_time_pattern."
                 & Unit & "." & Width & "." & Direction & "." & Count;
               Prefix    : constant String :=
                 (if not Direct_Row and then Raw_Value /= ""
                  then Relative_Pattern_Affix
                    (Raw_Value, True, Valid_Prefix)
                  else Attribute_Value (Line, "prefix"));
               Suffix    : constant String :=
                 (if not Direct_Row and then Raw_Value /= ""
                  then Relative_Pattern_Affix
                    (Raw_Value, False, Valid_Suffix)
                  else Attribute_Value (Line, "suffix"));
            begin
               if Locale = ""
                 or else (Direction /= "future" and then Direction /= "past")
                 or else (Direct_Row
                          and then
                            (not Is_CLDR_Count_Name (Count)
                             or else Unit = ""
                             or else not Is_Supported_Relative_Unit (Unit)
                             or else not Valid_Locale_Field
                               (Pattern_Field, Raw_Value)))
                 or else ((not Direct_Row)
                          and then
                            (not Valid_Prefix
                             or else not Valid_Suffix
                             or else (Prefix = "" and then Suffix = "")))
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML relative-pattern row");
                  Ok := False;
               else
                  if Direct_Row then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, Pattern_Field),
                        Raw_Value);
                  elsif Prefix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key
                          (Locale, "relative_prefix." & Direction),
                        Prefix);
                  end if;
                  if Suffix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key
                          (Locale, "relative_suffix." & Direction),
                        Suffix);
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<listPattern ")
           or else Starts_With (Line, "<listPatternPart ")
         then
            declare
               Kind  : constant String := Attribute_Value (Line, "type");
               Parent_Type : constant String :=
                 Attribute_Value (Line, "listPatternType");
               Raw_Value : constant String := Element_Text (Line);
               Valid_Pattern : Boolean := False;
               Value : constant String :=
                 List_Pattern_Separator (Raw_Value, Valid_Pattern);
               Field_Name : constant String :=
                 List_Separator_Field (Kind, Parent_Type);
            begin
               if Locale = ""
                 or else Field_Name = ""
                 or else not Valid_Pattern
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML list-pattern row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<dateFormat ")
           or else Starts_With (Line, "<dateFormatLength ")
           or else Starts_With (Line, "<timeFormat ")
           or else Starts_With (Line, "<timeFormatLength ")
           or else Starts_With (Line, "<dateTimeFormat ")
           or else Starts_With (Line, "<dateTimeFormatLength ")
           or else Starts_With (Line, "<dateStyle ")
           or else Starts_With (Line, "<timeStyle ")
           or else Starts_With (Line, "<dateTimeStyle ")
         then
            declare
               Raw_Style : constant String :=
                 Attribute_Value (Line, "type", "style");
               Style : constant String :=
                 (if Raw_Style /= "" then Raw_Style
                  else Attribute_Value (Line, "length"));
               Raw_Value : constant String := Element_Text (Line);
               Is_Date_Time : constant Boolean :=
                 Starts_With (Line, "<dateTimeFormat ")
                 or else Starts_With (Line, "<dateTimeFormatLength ")
                 or else Starts_With (Line, "<dateTimeStyle ");
               Extracted : Boolean;
               Value : constant String :=
                 (if Is_Date_Time
                  then Date_Time_Separator_From_Pattern
                         (Raw_Value, Extracted)
                  else Raw_Value);
               Prefix : constant String :=
                 (if Starts_With (Line, "<dateFormat ")
                    or else Starts_With (Line, "<dateFormatLength ")
                    or else Starts_With (Line, "<dateStyle ")
                  then "date_style."
                  elsif Is_Date_Time
                  then "date_time_style_"
                  else "time_style.");
               Field_Name : constant String :=
                 (if Is_Date_Time
                  then Prefix & "separator"
                  else Prefix & Style);
            begin
               if Locale = ""
                 or else Value = ""
                 or else (Is_Date_Time and then not Extracted)
                 or else (Style /= "default"
                          and then Style /= "short"
                          and then Style /= "medium"
                          and then Style /= "long"
                          and then Style /= "full")
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML date/time format row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<availableFormat ")
           or else Starts_With (Line, "<dateFormatItem ")
         then
            declare
               Raw_Skeleton : constant String :=
                 Attribute_Value (Line, "id", "skeleton");
               Value : constant String := Element_Text (Line);
               Field_Name : constant String :=
                 "available_format." & Raw_Skeleton;
            begin
               if Locale = ""
                 or else Raw_Skeleton = ""
                 or else Value = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML available-format row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<appendItem ") then
            declare
               Request : constant String := Attribute_Value (Line, "request");
               Raw_Value : constant String := Element_Text (Line);
               Extracted : Boolean;
               Value : constant String :=
                 Append_Item_Separator_From_Pattern (Raw_Value, Extracted);
               Field_Name : constant String := "date_time_field_separator";
            begin
               if Locale = ""
                 or else Value = ""
                 or else not Extracted
                 or else (Request /= "Time"
                          and then Request /= "time"
                          and then Request /= "Timezone"
                          and then Request /= "timezone")
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML append-item row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<calendarPreference ")
           or else Starts_With (Line, "<timeZonePreference ")
           or else Starts_With (Line, "<numberingSystemPreference ")
           or else Starts_With (Line, "<hourCyclePreference ")
         then
            declare
               Field_Name : constant String :=
                 (if Starts_With (Line, "<calendarPreference ")
                  then "default_calendar"
                  elsif Starts_With (Line, "<numberingSystemPreference ")
                  then "default_numbering_system"
                  elsif Starts_With (Line, "<hourCyclePreference ")
                  then "default_hour_cycle"
                  else "default_timezone");
               Raw_Value : constant String :=
                 (if Field_Name = "default_calendar"
                  then Attribute_Value (Line, "calendar", "type")
                  elsif Field_Name = "default_numbering_system"
                  then Attribute_Value (Line, "system", "type")
                  elsif Field_Name = "default_hour_cycle"
                  then Attribute_Value (Line, "cycle", "type")
                  else Attribute_Value
                    (Line,
                     (if Attribute_Value (Line, "id") /= ""
                      then "id" else "zone"),
                     "type"));
               Value : constant String :=
                 (if Field_Name = "default_calendar"
                  then Normalize_Calendar_Name (Raw_Value)
                  else Raw_Value);
            begin
               if Locale = ""
                 or else not Valid_Locale_Field (Field_Name, Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML locale preference row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, Field_Name),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<weekData ") then
            declare
               Value    : constant String :=
                 Attribute_Value (Line, "firstDay", "day");
               Min_Days : constant String :=
                 Attribute_Value (Line, "minDays", "count");
            begin
               if Locale = ""
                 or else not Valid_Locale_Field ("first_day_of_week", Value)
                 or else (Min_Days /= ""
                          and then not Valid_Locale_Field
                            ("first_week_min_days", Min_Days))
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML week-data row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "first_day_of_week"),
                     Value);
                  if Min_Days /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "first_week_min_days"),
                        Min_Days);
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<firstDay ") then
            declare
               Value : constant String := Attribute_Value (Line, "day");
            begin
               if Locale = ""
                 or else not Valid_Locale_Field ("first_day_of_week", Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML first-day row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "first_day_of_week"),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<minDays ") then
            declare
               Value : constant String := Attribute_Value (Line, "count");
            begin
               if Locale = ""
                 or else not Valid_Locale_Field ("first_week_min_days", Value)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML minimum-days row");
                  Ok := False;
               else
                  Store
                    (Pending_Locales,
                     Locale_Key (Locale, "first_week_min_days"),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<pattern ")
           or else Starts_With (Line, "<pattern>")
         then
            declare
               Date_Time_Kind : constant String :=
                 To_String (LDML_Context_Date_Time_Kind);
               Date_Time_Context_Style : constant String :=
                 To_String (LDML_Context_Date_Time_Style);
               Raw_Kind : constant String :=
                 Attribute_Value (Line, "type", "style");
               Kind : constant String :=
                 (if Raw_Kind /= "" then Raw_Kind
                  else To_String (LDML_Context_Currency_Format));
               Raw_Date_Time_Style : constant String :=
                 (if Raw_Kind /= "" then Raw_Kind
                  elsif Attribute_Value (Line, "length") /= ""
                  then Attribute_Value (Line, "length")
                  else Date_Time_Context_Style);
               Pattern : constant String := Element_Text (Line);
               Symbol_First : Boolean;
               Separator : Unbounded_String;
               Accounting_Prefix : Unbounded_String;
               Accounting_Suffix : Unbounded_String;
               Has_Accounting : Boolean;
               Extracted : Boolean;
            begin
               if Date_Time_Kind /= "" then
                  declare
                     Is_Date_Time : constant Boolean :=
                       Date_Time_Kind = "datetime";
                     Extracted_Date_Time : Boolean := False;
                     Value : constant String :=
                       (if Is_Date_Time
                        then Date_Time_Separator_From_Pattern
                          (Pattern, Extracted_Date_Time)
                        else Pattern);
                     Prefix : constant String :=
                       (if Date_Time_Kind = "date" then "date_style."
                        elsif Date_Time_Kind = "datetime"
                        then "date_time_style_"
                        else "time_style.");
                     Field_Name : constant String :=
                       (if Is_Date_Time
                        then Prefix & "separator"
                        else Prefix & Raw_Date_Time_Style);
                  begin
                     if Locale = ""
                       or else Value = ""
                       or else (Is_Date_Time and then not Extracted_Date_Time)
                       or else (Raw_Date_Time_Style /= "default"
                                and then Raw_Date_Time_Style /= "short"
                                and then Raw_Date_Time_Style /= "medium"
                                and then Raw_Date_Time_Style /= "long"
                                and then Raw_Date_Time_Style /= "full")
                     then
                        Add_Error (Diagnostics, Source, Number,
                                   "invalid LDML date/time pattern row");
                        Ok := False;
                     else
                        Store
                          (Pending_Locales,
                           Locale_Key (Locale, Field_Name),
                           Value);
                     end if;
                  end;
               else
                  Currency_Fields_From_Pattern
                    (Pattern, Symbol_First, Separator, Accounting_Prefix,
                     Accounting_Suffix, Has_Accounting, Extracted);

                  if Locale = ""
                    or else Pattern = ""
                    or else not Extracted
                    or else (Kind /= "standard" and then Kind /= "accounting")
                    or else (Kind = "accounting" and then not Has_Accounting)
                    or else (To_String (Separator) /= ""
                             and then not Valid_Locale_Field
                               ("currency_amount_separator",
                                To_String (Separator)))
                    or else (Has_Accounting
                             and then
                               (not Valid_Locale_Field
                                  ("currency_accounting_prefix",
                                   To_String (Accounting_Prefix))
                                or else not Valid_Locale_Field
                                  ("currency_accounting_suffix",
                                   To_String (Accounting_Suffix))))
                  then
                     Add_Error (Diagnostics, Source, Number,
                                "invalid LDML currency pattern row");
                     Ok := False;
                  else
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "currency_symbol_first"),
                        (if Symbol_First then "true" else "false"));
                     if To_String (Separator) /= "" then
                        Store
                          (Pending_Locales,
                           Locale_Key (Locale, "currency_amount_separator"),
                           To_String (Separator));
                     end if;

                     if Kind = "accounting" then
                        Store
                          (Pending_Locales,
                           Locale_Key (Locale, "currency_accounting_prefix"),
                           To_String (Accounting_Prefix));
                        Store
                          (Pending_Locales,
                           Locale_Key (Locale, "currency_accounting_suffix"),
                           To_String (Accounting_Suffix));
                     end if;
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<currencyMatch ")
           or else Starts_With (Line, "<currencyMatch>")
           or else Starts_With (Line, "<surroundingMatch ")
           or else Starts_With (Line, "<surroundingMatch>")
         then
            declare
               Value : constant String := Element_Text (Line);
            begin
               if Locale = ""
                 or else To_String (LDML_Context_Currency_Spacing) = ""
                 or else Value = ""
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML currency-spacing match row");
                  Ok := False;
               end if;
            end;
         elsif Starts_With (Line, "<currencyFormat ")
           or else Starts_With (Line, "<currencySpacing ")
           or else Starts_With (Line, "<insertBetween ")
           or else Starts_With (Line, "<insertBetween>")
         then
            declare
               Format_Row : constant Boolean :=
                 Starts_With (Line, "<currencyFormat ");
               Insert_Between_Row : constant Boolean :=
                 Starts_With (Line, "<insertBetween ")
                 or else Starts_With (Line, "<insertBetween>");
               Symbol_First_Text : constant String :=
                 (if Format_Row
                  then Attribute_Value (Line, "symbolFirst")
                  elsif Insert_Between_Row
                  then Attribute_Value (Line, "beforeCurrency")
                  else Attribute_Value (Line, "beforeCurrency"));
               Separator : constant String :=
                 (if Format_Row
                  then Attribute_Value (Line, "separator")
                  elsif Insert_Between_Row
                  then Element_Text (Line)
                  else Attribute_Value (Line, "insertBetween"));
               Accounting_Prefix : constant String :=
                 Attribute_Value (Line, "accountingPrefix");
               Accounting_Suffix : constant String :=
                 Attribute_Value (Line, "accountingSuffix");
               Row_Name : constant String :=
                 (if Format_Row then "currency-format"
                  elsif Insert_Between_Row then "currency-spacing"
                  else "currency-spacing");
               Saw_Field : Boolean := False;
            begin
               if Locale = ""
                 or else (Insert_Between_Row and then Symbol_First_Text = "")
                 or else (Symbol_First_Text /= ""
                          and then Symbol_First_Text /= "true"
                          and then Symbol_First_Text /= "false")
                 or else (Separator /= ""
                          and then not Valid_Locale_Field
                            ("currency_amount_separator", Separator))
                 or else (Accounting_Prefix /= ""
                          and then not Valid_Locale_Field
                            ("currency_accounting_prefix",
                             Accounting_Prefix))
                 or else (Accounting_Suffix /= ""
                          and then not Valid_Locale_Field
                            ("currency_accounting_suffix",
                             Accounting_Suffix))
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML " & Row_Name & " row");
                  Ok := False;
               else
                  if Symbol_First_Text /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "currency_symbol_first"),
                        Symbol_First_Text);
                     Saw_Field := True;
                  end if;
                  if Separator /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "currency_amount_separator"),
                        Separator);
                     Saw_Field := True;
                  end if;
                  if Accounting_Prefix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "currency_accounting_prefix"),
                        Accounting_Prefix);
                     Saw_Field := True;
                  end if;
                  if Accounting_Suffix /= "" then
                     Store
                       (Pending_Locales,
                        Locale_Key (Locale, "currency_accounting_suffix"),
                        Accounting_Suffix);
                     Saw_Field := True;
                  end if;

                  if not Saw_Field then
                     Add_Error (Diagnostics, Source, Number,
                                "invalid LDML " & Row_Name & " row");
                     Ok := False;
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<currency ") then
            declare
               Code  : constant String :=
                 Attribute_Value
                   (Line,
                    (if Attribute_Value (Line, "code") /= ""
                     then "code" else "type"),
                    "iso4217");
               Minor : constant String :=
                 Attribute_Value (Line, "minor", "digits");
               Cash  : constant String :=
                 Attribute_Value
                   (Line,
                    (if Attribute_Value (Line, "cash") /= ""
                     then "cash" else "cashRounding"),
                    "rounding");
               Sym   : constant String := Attribute_Value (Line, "symbol");
               Narrow : constant String :=
                 Attribute_Value (Line, "narrow", "narrowSymbol");
               Name  : constant String :=
                 Attribute_Value (Line, "name", "displayName");
               Saw_Field : Boolean := False;
            begin
               if Code'Length /= 3
                 or else (Minor /= "" and then not In_Integer_Range (Minor))
                 or else (Cash /= "" and then not In_Integer_Range (Cash))
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML currency row");
                  Ok := False;
               else
                  if Minor /= "" then
                     Store (Pending_Currencies,
                            Currency_Key (Code, "minor_units"), Minor);
                     Saw_Field := True;
                  end if;
                  if Cash /= "" then
                     Store (Pending_Currencies,
                            Currency_Key (Code, "cash_increment"), Cash);
                     Saw_Field := True;
                  end if;
                  if Sym /= "" then
                     Store (Pending_Currencies,
                            Currency_Key (Code, "symbol"), Sym);
                     Saw_Field := True;
                  end if;
                  if Narrow /= "" then
                     Store (Pending_Currencies,
                            Currency_Key (Code, "narrow_symbol"), Narrow);
                     Saw_Field := True;
                  end if;
                  if Name /= "" then
                     Store (Pending_Currencies,
                            Currency_Key (Code, "display_name"), Name);
                     Saw_Field := True;
                  end if;

                  if not Saw_Field then
                     Add_Error (Diagnostics, Source, Number,
                                "invalid LDML currency row");
                     Ok := False;
                  end if;
               end if;
            end;
         elsif Starts_With (Line, "<currencySymbol ")
           or else Starts_With (Line, "<symbol ")
           or else Starts_With (Line, "<symbol>")
         then
            declare
               Raw_Code : constant String :=
                 Attribute_Value (Line, "code", "type");
               Code     : constant String :=
                 (if Raw_Code /= "" then Raw_Code
                  else Attribute_Value (Line, "iso4217"));
               Alt      : constant String := Attribute_Value (Line, "alt");
               Value    : constant String := Element_Text (Line);
               Field    : constant String :=
                 (if Alt = "narrow" then "narrow_symbol" else "symbol");
            begin
               if Code'Length /= 3
                 or else Value = ""
                 or else (Alt /= "" and then Alt /= "standard"
                          and then Alt /= "narrow")
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML currency-symbol row");
                  Ok := False;
               else
                  Store (Pending_Currencies, Currency_Key (Code, Field),
                         Value);
               end if;
            end;
         elsif Starts_With (Line, "<currencyName ") then
            declare
               Raw_Code : constant String :=
                 Attribute_Value (Line, "code", "type");
               Code     : constant String :=
                 (if Raw_Code /= "" then Raw_Code
                  else Attribute_Value (Line, "iso4217"));
               Category : constant String :=
                 Attribute_Value (Line, "category", "count");
               Value    : constant String := Element_Text (Line);
            begin
               if Locale = ""
                 or else Code'Length /= 3
                 or else not Is_Plural_Category (Category)
                 or else Value = ""
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML currency-name row");
                  Ok := False;
               else
                  Store
                    (Pending_Locale_Currencies,
                     Locale_Currency_Key
                       (Locale, Code, "display_name." & Category),
                     Value);
               end if;
            end;
         elsif Starts_With (Line, "<pluralRule ") then
            declare
               Kind   : constant String := Attribute_Value (Line, "type", "kind");
               Family : constant String := Attribute_Value (Line, "family");
               Category : constant String :=
                 Attribute_Value (Line, "count", "category");
               Locales : constant String :=
                 (if Attribute_Value (Line, "locales") /= ""
                  then Attribute_Value (Line, "locales")
                  else Locale);
               Rule_Text : constant String := Element_Text (Line);
            begin
               if Category /= "" or else Rule_Text /= "" then
                  Store_Plural_Category_Rule_List
                    (Kind, Locales, Category, Rule_Text, Source, Number);
               elsif Locales = "" then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML plural-rule row");
                  Ok := False;
               else
                  Store_Plural_Families_List
                    (Kind, Family, Locales, Source, Number);
               end if;
            end;
         elsif Starts_With (Line, "<rbnf ")
           or else Starts_With (Line, "<rbnfRule ")
           or else Starts_With (Line, "<rbnfRule>")
           or else Starts_With (Line, "<rbnfrule ")
           or else Starts_With (Line, "<rbnfrule>")
         then
            declare
               Kind : constant String :=
                 (if Attribute_Value (Line, "type") /= ""
                  then Attribute_Value (Line, "type")
                  elsif Attribute_Value (Line, "ruleSet") /= ""
                  then Attribute_Value (Line, "ruleSet")
                  else Attribute_Value (Line, "ruleset"));
               Value_Text : constant String :=
                 Attribute_Value (Line, "value");
               Radix_Text : constant String :=
                 Attribute_Value (Line, "radix");
               Raw_Text : constant String := Element_Text (Line);
               Inline_Separator : constant Natural :=
                 Ada.Strings.Fixed.Index (Raw_Text, ":");
               Inline_Value_Text : constant String :=
                 (if Value_Text /= "" or else Inline_Separator = 0
                  then Value_Text
                  else Trimmed
                    (Raw_Text (Raw_Text'First .. Inline_Separator - 1)));
               Text_Value : constant String :=
                 (if Value_Text /= "" or else Inline_Separator = 0
                  then Raw_Text
                  else Trimmed
                    (Raw_Text (Inline_Separator + 1 .. Raw_Text'Last)));
               Rule_Base_Text : constant String :=
                 (if Radix_Text = "" then Inline_Value_Text
                  else Inline_Value_Text & "/" & Radix_Text);
            begin
               if Radix_Text /= "" or else Is_RBNF_Rule_Pattern (Text_Value)
               then
                  Store_Spellout_Rule
                    (Locale, Kind, Rule_Base_Text, Text_Value, Source, Number);
               else
                  Store_Spellout_Text
                    (Locale, Kind, Inline_Value_Text, Text_Value,
                     Source, Number);
               end if;
            end;
         elsif Starts_With (Line, "<timeZone ") then
            declare
               Zone   : constant String := Attribute_Value (Line, "id", "zone");
               Raw_Offset : constant String :=
                 Attribute_Value (Line, "offset");
               Offset : constant String :=
                 (if Raw_Offset /= "" then Raw_Offset
                  elsif Attribute_Value (Line, "gmtOffset") /= ""
                  then Attribute_Value (Line, "gmtOffset")
                  else Attribute_Value (Line, "utcOffset"));
               Minutes : Integer;
            begin
               if Zone = "" or else not Parse_Offset_Minutes (Offset, Minutes)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "invalid LDML time-zone row");
                  Ok := False;
               else
                  Store
                    (Pending_Zones,
                     Zone_Key (Zone, "base_offset_minutes"),
                     Integer'Image (Minutes));
               end if;
            end;
         else
            Add_Error (Diagnostics, Source, Number,
                       "unsupported LDML row");
            Ok := False;
         end if;
      end Parse_LDML_Row;

      function Is_TZDB_Zone_Row (Line : String) return Boolean is
      begin
         return Starts_With (Line, "Zone ")
           or else Starts_With (Line, "Zone" & ASCII.HT);
      end Is_TZDB_Zone_Row;

      function Is_TZDB_Link_Row (Line : String) return Boolean is
      begin
         return Starts_With (Line, "Link ")
           or else Starts_With (Line, "Link" & ASCII.HT);
      end Is_TZDB_Link_Row;

      function Is_TZDB_Rule_Row (Line : String) return Boolean is
      begin
         return Starts_With (Line, "Rule ")
           or else Starts_With (Line, "Rule" & ASCII.HT);
      end Is_TZDB_Rule_Row;

      procedure Read_TZDB_Parts
        (Line  : String;
         Parts : in out String_Maps.Map;
         Count : out Natural)
      is
         Normalized : String (1 .. Line'Length) := Line;
      begin
         Parts.Clear;
         Count := 0;

         for Index in Normalized'Range loop
            if Normalized (Index) = ASCII.HT then
               Normalized (Index) := ' ';
            elsif Normalized (Index) = '#' then
               Normalized (Index .. Normalized'Last) := [others => ' '];
               exit;
            end if;
         end loop;

         declare
            P : Positive := Normalized'First;
         begin
            while P <= Normalized'Last loop
               while P <= Normalized'Last and then Normalized (P) = ' ' loop
                  P := P + 1;
               end loop;
               exit when P > Normalized'Last;

               declare
                  Start_P : constant Positive := P;
               begin
                  while P <= Normalized'Last and then Normalized (P) /= ' ' loop
                     P := P + 1;
                  end loop;
                  Count := Count + 1;
                  Store
                    (Parts, Natural_Text (Count),
                     Normalized (Start_P .. P - 1));
               end;
            end loop;
         end;
      end Read_TZDB_Parts;

      function ASCII_Lower (Value : String) return String is
         Result : String := Value;
      begin
         for Index in Result'Range loop
            if Result (Index) in 'A' .. 'Z' then
               Result (Index) := Character'Val
                 (Character'Pos (Result (Index))
                  - Character'Pos ('A') + Character'Pos ('a'));
            end if;
         end loop;
         return Result;
      end ASCII_Lower;

      function TZDB_Month_Number (Text : String) return Natural is
         Normal : constant String := ASCII_Lower (Text);
      begin
         if Text = "1" or else Text = "01" or else Normal = "jan" then
            return 1;
         elsif Text = "2" or else Text = "02" or else Normal = "feb" then
            return 2;
         elsif Text = "3" or else Text = "03" or else Normal = "mar" then
            return 3;
         elsif Text = "4" or else Text = "04" or else Normal = "apr" then
            return 4;
         elsif Text = "5" or else Text = "05" or else Normal = "may" then
            return 5;
         elsif Text = "6" or else Text = "06" or else Normal = "jun" then
            return 6;
         elsif Text = "7" or else Text = "07" or else Normal = "jul" then
            return 7;
         elsif Text = "8" or else Text = "08" or else Normal = "aug" then
            return 8;
         elsif Text = "9" or else Text = "09" or else Normal = "sep" then
            return 9;
         elsif Text = "10" or else Normal = "oct" then
            return 10;
         elsif Text = "11" or else Normal = "nov" then
            return 11;
         elsif Text = "12" or else Normal = "dec" then
            return 12;
         else
            return 0;
         end if;
      end TZDB_Month_Number;

      function TZDB_Weekday_Number (Text : String) return Natural is
         Normal : constant String := ASCII_Lower (Text);
      begin
         if Normal = "sun" then
            return 0;
         elsif Normal = "mon" then
            return 1;
         elsif Normal = "tue" then
            return 2;
         elsif Normal = "wed" then
            return 3;
         elsif Normal = "thu" then
            return 4;
         elsif Normal = "fri" then
            return 5;
         elsif Normal = "sat" then
            return 6;
         else
            return 7;
         end if;
      end TZDB_Weekday_Number;

      function TZDB_Day_Of_Week
        (Year  : Natural;
         Month : Natural;
         Day   : Natural)
         return Natural
      is
         Y : Integer := Integer (Year);
         M : Integer := Integer (Month);
         K : Integer;
         J : Integer;
         H : Integer;
      begin
         if M < 3 then
            M := M + 12;
            Y := Y - 1;
         end if;

         K := Y mod 100;
         J := Y / 100;
         H :=
           (Integer (Day)
            + (13 * (M + 1)) / 5
            + K
            + K / 4
            + J / 4
            + 5 * J)
           mod 7;

         return Natural ((H + 6) mod 7);
      end TZDB_Day_Of_Week;

      function Resolve_TZDB_On_Day
        (Year    : Natural;
         Month   : Natural;
         On_Text : String)
         return Natural
      is
      begin
         if Is_Integer_Text (On_Text) and then In_Integer_Range (On_Text) then
            declare
               Day : constant Natural := Natural'Value (On_Text);
            begin
               if Day in 1 .. Days_In_Month (Year, Month) then
                  return Day;
               end if;
            end;
         elsif On_Text'Length = 7
           and then On_Text (On_Text'First .. On_Text'First + 3) = "last"
         then
            declare
               Weekday : constant Natural :=
                 TZDB_Weekday_Number
                   (On_Text (On_Text'First + 4 .. On_Text'Last));
               Day     : Natural := Days_In_Month (Year, Month);
            begin
               if Weekday <= 6 then
                  while Day >= 1 loop
                     if TZDB_Day_Of_Week (Year, Month, Day) = Weekday then
                        return Day;
                     end if;
                     Day := Day - 1;
                  end loop;
               end if;
            end;
         elsif On_Text'Length > 5 then
            declare
               Op : Natural := 0;
            begin
               for Index in On_Text'Range loop
                  if On_Text (Index) = '>' or else On_Text (Index) = '<' then
                     Op := Index;
                     exit;
                  end if;
               end loop;

               if Op > On_Text'First
                 and then Op + 1 <= On_Text'Last
                 and then On_Text (Op + 1) = '='
               then
                  declare
                     Weekday_Text : constant String :=
                       On_Text (On_Text'First .. Op - 1);
                     Day_Text : constant String :=
                       On_Text (Op + 2 .. On_Text'Last);
                     Weekday : constant Natural :=
                       TZDB_Weekday_Number (Weekday_Text);
                  begin
                     if Weekday <= 6
                       and then Is_Integer_Text (Day_Text)
                       and then In_Integer_Range (Day_Text)
                     then
                        declare
                           Day : Natural := Natural'Value (Day_Text);
                        begin
                           if On_Text (Op) = '>' then
                              while Day <= Days_In_Month (Year, Month) loop
                                 if TZDB_Day_Of_Week (Year, Month, Day)
                                   = Weekday
                                 then
                                    return Day;
                                 end if;
                                 Day := Day + 1;
                              end loop;
                           elsif Day in 1 .. Days_In_Month (Year, Month) then
                              loop
                                 if TZDB_Day_Of_Week (Year, Month, Day)
                                   = Weekday
                                 then
                                    return Day;
                                 end if;
                                 exit when Day = 1;
                                 Day := Day - 1;
                              end loop;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;

         return 0;
      exception
         when Constraint_Error =>
            return 0;
      end Resolve_TZDB_On_Day;

      function Parse_TZDB_Time
        (Text   : String;
         Hour   : out Natural;
         Minute : out Natural;
         Second : out Natural)
         return Boolean
      is
         Clean_Last : Natural := Text'Last;
         First_Sep  : Natural := 0;
         Second_Sep : Natural := 0;
      begin
         Hour := 0;
         Minute := 0;
         Second := 0;

         if Text'Length = 0 then
            return False;
         end if;

         if Text (Clean_Last) = 'u'
           or else Text (Clean_Last) = 'U'
           or else Text (Clean_Last) = 'g'
           or else Text (Clean_Last) = 'G'
           or else Text (Clean_Last) = 'z'
           or else Text (Clean_Last) = 'Z'
           or else Text (Clean_Last) = 's'
           or else Text (Clean_Last) = 'S'
           or else Text (Clean_Last) = 'w'
           or else Text (Clean_Last) = 'W'
         then
            if Clean_Last = Text'First then
               return False;
            end if;
            Clean_Last := Clean_Last - 1;
         end if;

         for Index in Text'First .. Clean_Last loop
            if Text (Index) = ':' then
               if First_Sep = 0 then
                  First_Sep := Index;
               elsif Second_Sep = 0 then
                  Second_Sep := Index;
               else
                  return False;
               end if;
            elsif Text (Index) not in '0' .. '9' then
               return False;
            end if;
         end loop;

         if First_Sep = 0 then
            if not Is_Integer_Text (Text (Text'First .. Clean_Last)) then
               return False;
            end if;
            Hour := Natural'Value (Text (Text'First .. Clean_Last));
         else
            if First_Sep = Text'First
              or else First_Sep = Clean_Last
              or else (Second_Sep /= 0
                       and then (Second_Sep = First_Sep + 1
                                 or else Second_Sep = Clean_Last))
            then
               return False;
            end if;

            Hour := Natural'Value (Text (Text'First .. First_Sep - 1));
            if Second_Sep = 0 then
               Minute := Natural'Value (Text (First_Sep + 1 .. Clean_Last));
            else
               Minute :=
                 Natural'Value (Text (First_Sep + 1 .. Second_Sep - 1));
               Second := Natural'Value (Text (Second_Sep + 1 .. Clean_Last));
            end if;
         end if;

         return Hour in 0 .. 24
           and then Minute in 0 .. 59
           and then Second in 0 .. 59;
      exception
         when Constraint_Error =>
            return False;
      end Parse_TZDB_Time;

      function Normalize_TZDB_Date_Time
        (Year   : in out Natural;
         Month  : in out Natural;
         Day    : in out Natural;
         Hour   : in out Natural;
         Minute : Natural;
         Second : Natural)
         return Boolean
      is
      begin
         if Hour = 24 then
            if Minute /= 0 or else Second /= 0 then
               return False;
            elsif Year = 9999 and then Month = 12 and then Day = 31 then
               return False;
            elsif not Valid_UTC_Fields (Year, Month, Day, 23, 59, 59) then
               return False;
            end if;

            Hour := 0;
            if Day < Days_In_Month (Year, Month) then
               Day := Day + 1;
            elsif Month < 12 then
               Month := Month + 1;
               Day := 1;
            else
               Year := Year + 1;
               Month := 1;
               Day := 1;
            end if;
         end if;

         return Valid_UTC_Fields (Year, Month, Day, Hour, Minute, Second);
      exception
         when Constraint_Error =>
            return False;
      end Normalize_TZDB_Date_Time;

      function TZDB_Time_Mode (Text : String) return Character is
      begin
         if Text'Length = 0 then
            return 'w';
         elsif Text (Text'Last) = 'u'
           or else Text (Text'Last) = 'U'
           or else Text (Text'Last) = 'g'
           or else Text (Text'Last) = 'G'
           or else Text (Text'Last) = 'z'
           or else Text (Text'Last) = 'Z'
         then
            return 'u';
         elsif Text (Text'Last) = 's'
           or else Text (Text'Last) = 'S'
         then
            return 's';
         else
            return 'w';
         end if;
      end TZDB_Time_Mode;

      function Parse_TZDB_Until
        (Parts       : String_Maps.Map;
         Count       : Natural;
         Start_Index : Positive;
         Standard_Seconds : Integer;
         Wall_Seconds     : Integer;
         Key         : out String)
         return Boolean
      is
         Year   : Natural;
         Month  : Natural := 1;
         Day    : Natural := 1;
         Hour   : Natural := 0;
         Minute : Natural := 0;
         Second : Natural := 0;
         Mode   : Character := 'w';
      begin
         Key := [others => '0'];

         if Count < Start_Index
           or else Count > Start_Index + 3
           or else not Parts.Contains (Natural_Text (Start_Index))
         then
            return False;
         end if;

         declare
            Year_Text  : constant String :=
              Parts.Element (Natural_Text (Start_Index));
         begin
            if not Is_Integer_Text (Year_Text)
              or else not In_Integer_Range (Year_Text)
            then
               return False;
            end if;

            Year := Natural'Value (Year_Text);
         end;

         if Count >= Start_Index + 1 then
            if not Parts.Contains (Natural_Text (Start_Index + 1)) then
               return False;
            end if;

            Month :=
              TZDB_Month_Number
                (Parts.Element (Natural_Text (Start_Index + 1)));
         end if;

         if Count >= Start_Index + 2 then
            declare
               Day_Text : constant String :=
                 Parts.Element (Natural_Text (Start_Index + 2));
            begin
               Day := Resolve_TZDB_On_Day (Year, Month, Day_Text);
               if Day = 0 then
                  return False;
               end if;
            end;
         end if;

         if Count >= Start_Index + 3 then
            if not Parts.Contains (Natural_Text (Start_Index + 3))
              or else not Parse_TZDB_Time
                (Parts.Element (Natural_Text (Start_Index + 3)),
                 Hour, Minute, Second)
            then
               return False;
            end if;

            declare
               Until_Time : constant String :=
                 Parts.Element (Natural_Text (Start_Index + 3));
            begin
               Mode := TZDB_Time_Mode (Until_Time);
            end;
         end if;

         if not Normalize_TZDB_Date_Time
           (Year, Month, Day, Hour, Minute, Second)
         then
            return False;
         end if;

         Key :=
           Adjusted_UTC_Key
             (Year, Month, Day, Hour, Minute, Second,
              (if Mode = 'u' then 0
               elsif Mode = 's' then Standard_Seconds
               else Wall_Seconds));
         if Key = "" then
            return False;
         end if;

         return True;
      exception
         when Constraint_Error =>
            return False;
      end Parse_TZDB_Until;

      procedure Store_TZDB_Transition
        (Zone        : String;
         Until_Key   : String;
         New_Seconds : Integer)
      is
      begin
         Store
           (Pending_Zones,
            Zone_Key (Zone, Zone_Transition_Field (Until_Key)),
            Integer_Text (New_Seconds));
      end Store_TZDB_Transition;

      procedure Store_TZDB_Base_Offset
        (Zone    : String;
         Seconds : Integer)
      is
      begin
         Store
           (Pending_Zones,
            Zone_Key (Zone, "base_offset_seconds"),
            Integer_Text (Seconds));
         if Seconds mod 60 = 0 then
            Store
              (Pending_Zones,
               Zone_Key (Zone, "base_offset_minutes"),
               Integer_Text (Seconds / 60));
         end if;
      end Store_TZDB_Base_Offset;

      function TZDB_Rule_Count_Key (Name : String) return String is
      begin
         return Name & Character'Val (0) & "count";
      end TZDB_Rule_Count_Key;

      function TZDB_Rule_Key (Name : String; Index : Natural) return String is
      begin
         return Name & Character'Val (0) & Natural_Text (Index);
      end TZDB_Rule_Key;

      function TZDB_Rule_Application_Count_Key return String is
      begin
         return "application" & Character'Val (0) & "count";
      end TZDB_Rule_Application_Count_Key;

      function TZDB_Rule_Application_Key (Index : Natural) return String is
      begin
         return "application" & Character'Val (0) & Natural_Text (Index);
      end TZDB_Rule_Application_Key;

      function TZDB_Time_Basis_Supported (Text : String) return Boolean is
      begin
         return Text'Length > 0
           and then (TZDB_Time_Mode (Text) in 'u' | 's' | 'w');
      end TZDB_Time_Basis_Supported;

      function TZDB_Rule_Year_Text_Valid
        (Text     : String;
         Position : String)
         return Boolean
      is
         Normal_Text : constant String := ASCII_Lower (Text);
      begin
         if Position = "from"
           and then (Normal_Text = "minimum" or else Normal_Text = "min")
         then
            return True;
         elsif Position = "to"
           and then (Normal_Text = "maximum" or else Normal_Text = "max")
         then
            return True;
         else
            return Is_Integer_Text (Text) and then In_Integer_Range (Text);
         end if;
      end TZDB_Rule_Year_Text_Valid;

      function TZDB_Rule_Year_Value
        (Text     : String;
         Position : String)
         return Natural
      is
         Normal_Text : constant String := ASCII_Lower (Text);
      begin
         if Position = "from"
           and then (Normal_Text = "minimum" or else Normal_Text = "min")
         then
            return 1900;
         elsif Position = "to"
           and then (Normal_Text = "maximum" or else Normal_Text = "max")
         then
            return 2050;
         else
            return Natural'Value (Text);
         end if;
      end TZDB_Rule_Year_Value;

      function TZDB_Rule_Record
        (From_Year : Natural;
         To_Year   : Natural;
         Month     : Natural;
         On_Text   : String;
         Hour      : Natural;
         Minute    : Natural;
         Second    : Natural;
         Mode      : Character;
         Save_Seconds : Integer)
         return String
      is
      begin
         return Natural_Text (From_Year) & "|"
           & Natural_Text (To_Year) & "|"
           & Natural_Text (Month) & "|"
           & On_Text & "|"
           & Natural_Text (Hour) & "|"
           & Natural_Text (Minute) & "|"
           & Natural_Text (Second) & "|"
           & Mode & "|"
           & Integer_Text (Save_Seconds);
      end TZDB_Rule_Record;

      function TZDB_Rule_Field
        (Record_Text : String;
         Index       : Positive)
         return String
      is
      begin
         return Field (Record_Text, Index);
      end TZDB_Rule_Field;

      procedure Parse_TZDB_Rule_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Parts  : String_Maps.Map;
         Count  : Natural;
         Hour   : Natural;
         Minute : Natural;
         Second : Natural;
         Save_Seconds : Integer;
      begin
         Read_TZDB_Parts (Line, Parts, Count);

         if Count < 9
           or else not Parts.Contains ("1")
           or else Parts.Element ("1") /= "Rule"
           or else not Parts.Contains ("2")
           or else not Parts.Contains ("3")
           or else not Parts.Contains ("4")
           or else not Parts.Contains ("6")
           or else not Parts.Contains ("7")
           or else not Parts.Contains ("8")
           or else not Parts.Contains ("9")
         then
            Add_Error (Diagnostics, Source, Number,
                       "invalid tzdb Rule row");
            Ok := False;
            return;
         end if;

         declare
            Name      : constant String := Parts.Element ("2");
            From_Text : constant String := Parts.Element ("3");
            To_Text   : constant String := Parts.Element ("4");
            Month     : constant Natural := TZDB_Month_Number
              (Parts.Element ("6"));
            Day_Text  : constant String := Parts.Element ("7");
            At_Text   : constant String := Parts.Element ("8");
            Mode      : constant Character := TZDB_Time_Mode (At_Text);
            Save_Text : constant String := Parts.Element ("9");
            Normal_To_Text : constant String := ASCII_Lower (To_Text);
         begin
            if Name = ""
              or else not TZDB_Rule_Year_Text_Valid (From_Text, "from")
              or else (Normal_To_Text /= "only"
                       and then not TZDB_Rule_Year_Text_Valid
                         (Normal_To_Text, "to"))
              or else Month = 0
              or else not TZDB_Time_Basis_Supported (At_Text)
              or else not Parse_TZDB_Time (At_Text, Hour, Minute, Second)
              or else not Parse_Offset_Seconds (Save_Text, Save_Seconds)
            then
               Add_Error (Diagnostics, Source, Number,
                          "unsupported tzdb Rule row");
               Ok := False;
               return;
            end if;

            declare
               From_Year : constant Natural :=
                 TZDB_Rule_Year_Value (From_Text, "from");
               To_Year   : constant Natural :=
                 (if Normal_To_Text = "only" then From_Year
                  else TZDB_Rule_Year_Value (Normal_To_Text, "to"));
               From_Day  : constant Natural :=
                 Resolve_TZDB_On_Day (From_Year, Month, Day_Text);
               To_Day    : constant Natural :=
                 Resolve_TZDB_On_Day (To_Year, Month, Day_Text);
               Check_From_Year  : Natural := From_Year;
               Check_From_Month : Natural := Month;
               Check_From_Day   : Natural := From_Day;
               Check_From_Hour  : Natural := Hour;
               Check_To_Year    : Natural := To_Year;
               Check_To_Month   : Natural := Month;
               Check_To_Day     : Natural := To_Day;
               Check_To_Hour    : Natural := Hour;
               Count_Key : constant String := TZDB_Rule_Count_Key (Name);
               Old_Count : constant Natural :=
                 (if TZDB_Rules.Contains (Count_Key)
                  then Natural'Value (TZDB_Rules.Element (Count_Key))
                  else 0);
               New_Count : constant Natural := Old_Count + 1;
            begin
               if To_Year < From_Year
                 or else To_Year - From_Year > 400
                 or else From_Day = 0
                 or else To_Day = 0
                 or else not Normalize_TZDB_Date_Time
                   (Check_From_Year, Check_From_Month, Check_From_Day,
                    Check_From_Hour, Minute, Second)
                 or else not Normalize_TZDB_Date_Time
                   (Check_To_Year, Check_To_Month, Check_To_Day,
                    Check_To_Hour, Minute, Second)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "unsupported tzdb Rule row");
                  Ok := False;
               else
                  Store (TZDB_Rules, Count_Key, Natural_Text (New_Count));
                  Store
                    (TZDB_Rules, TZDB_Rule_Key (Name, New_Count),
                     TZDB_Rule_Record
                       (From_Year, To_Year, Month, Day_Text,
                        Hour, Minute, Second, Mode, Save_Seconds));
               end if;
            end;
         end;
      exception
         when Constraint_Error =>
            Add_Error (Diagnostics, Source, Number,
                       "invalid tzdb Rule row");
            Ok := False;
      end Parse_TZDB_Rule_Row;

      procedure Apply_TZDB_Rules
        (Zone         : String;
         Rule_Name    : String;
         Base_Seconds : Integer)
      is
         Count_Key : constant String := TZDB_Rule_Count_Key (Rule_Name);
      begin
         if Rule_Name = "-" then
            return;
         end if;

         if not TZDB_Rules.Contains (Count_Key) then
            return;
         end if;

         declare
            Count : constant Natural :=
              Natural'Value (TZDB_Rules.Element (Count_Key));
            Min_Year : Natural := Natural'Last;
            Max_Year : Natural := Natural'First;
         begin
            for Rule_Index in 1 .. Count loop
               declare
                  Record_Text : constant String :=
                    TZDB_Rules.Element
                      (TZDB_Rule_Key (Rule_Name, Rule_Index));
                  From_Year : constant Natural :=
                    Natural'Value (TZDB_Rule_Field (Record_Text, 1));
                  To_Year : constant Natural :=
                    Natural'Value (TZDB_Rule_Field (Record_Text, 2));
               begin
                  if From_Year < Min_Year then
                     Min_Year := From_Year;
                  end if;

                  if To_Year > Max_Year then
                     Max_Year := To_Year;
                  end if;
               end;
            end loop;

            if Max_Year < Min_Year then
               return;
            end if;

            declare
               type TZDB_Event is record
                  Local_Key    : String (1 .. 14);
                  Sort_Key     : String (1 .. 14);
                  Year         : Natural;
                  Month        : Natural;
                  Day          : Natural;
                  Hour         : Natural;
                  Minute       : Natural;
                  Second       : Natural;
                  Mode         : Character;
                  Save_Seconds : Integer;
               end record;

               type TZDB_Event_Array is
                 array (Positive range <>) of TZDB_Event;

               Max_Events : constant Positive :=
                 Positive (Count * (Max_Year - Min_Year + 1));
               Invalid_Sort_Key : constant String := "99999999999999";
               Events     : TZDB_Event_Array (1 .. Max_Events);
               Event_Count : Natural := 0;

               procedure Add_Event (Item : TZDB_Event) is
                  Pos : Natural;
               begin
                  if Event_Count = Max_Events then
                     return;
                  end if;

                  Event_Count := Event_Count + 1;
                  Pos := Event_Count;
                  while Pos > 1
                    and then Item.Local_Key < Events (Pos - 1).Local_Key
                  loop
                     Events (Pos) := Events (Pos - 1);
                     Pos := Pos - 1;
                  end loop;
                  Events (Pos) := Item;
               end Add_Event;

               procedure Sort_Events is
               begin
                  for Index in 2 .. Event_Count loop
                     declare
                        Item : constant TZDB_Event := Events (Index);
                        Pos  : Natural := Index;
                     begin
                        while Pos > 1
                          and then
                            (Item.Sort_Key < Events (Pos - 1).Sort_Key
                             or else
                               (Item.Sort_Key = Events (Pos - 1).Sort_Key
                                and then
                                  Item.Local_Key < Events (Pos - 1).Local_Key))
                        loop
                           Events (Pos) := Events (Pos - 1);
                           Pos := Pos - 1;
                        end loop;
                        Events (Pos) := Item;
                     end;
                  end loop;
               end Sort_Events;

               function Recompute_Event_Sort_Keys return Boolean is
                  Prior_Save : Integer := 0;
                  Changed    : Boolean := False;
               begin
                  for Index in 1 .. Event_Count loop
                     declare
                        Offset_Seconds : constant Integer :=
                          (if Events (Index).Mode = 'u' then 0
                           elsif Events (Index).Mode = 's' then Base_Seconds
                           else Base_Seconds + Prior_Save);
                        Key : constant String :=
                          Adjusted_UTC_Key
                            (Events (Index).Year, Events (Index).Month,
                             Events (Index).Day, Events (Index).Hour,
                             Events (Index).Minute, Events (Index).Second,
                             Offset_Seconds);
                        New_Key : constant String :=
                          (if Key = "" then Invalid_Sort_Key else Key);
                     begin
                        if Events (Index).Sort_Key /= New_Key then
                           Events (Index).Sort_Key := New_Key;
                           Changed := True;
                        end if;

                        Prior_Save := Events (Index).Save_Seconds;
                     end;
                  end loop;

                  return Changed;
               end Recompute_Event_Sort_Keys;
            begin
               for Rule_Index in 1 .. Count loop
                  declare
                     Record_Text : constant String :=
                       TZDB_Rules.Element
                         (TZDB_Rule_Key (Rule_Name, Rule_Index));
                     From_Year : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 1));
                     To_Year : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 2));
                     Month : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 3));
                     On_Text : constant String :=
                       TZDB_Rule_Field (Record_Text, 4);
                     Hour : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 5));
                     Minute : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 6));
                     Second : constant Natural :=
                       Natural'Value (TZDB_Rule_Field (Record_Text, 7));
                     Mode : constant String :=
                       TZDB_Rule_Field (Record_Text, 8);
                     Save_Seconds : constant Integer :=
                       Integer'Value (TZDB_Rule_Field (Record_Text, 9));
                  begin
                     for Year in From_Year .. To_Year loop
                        declare
                           Key_Year : Natural := Year;
                           Key_Month : Natural := Month;
                           Day : Natural :=
                             Resolve_TZDB_On_Day (Year, Month, On_Text);
                           Key_Hour : Natural := Hour;
                        begin
                           if Day /= 0
                             and then Normalize_TZDB_Date_Time
                               (Key_Year, Key_Month, Day, Key_Hour,
                                Minute, Second)
                           then
                              Add_Event
                                ((Local_Key =>
                                    UTC_Key
                                      (Key_Year, Key_Month, Day, Key_Hour,
                                       Minute, Second),
                                  Sort_Key =>
                                    UTC_Key
                                      (Key_Year, Key_Month, Day, Key_Hour,
                                       Minute, Second),
                                  Year => Key_Year,
                                  Month => Key_Month,
                                  Day => Day,
                                  Hour => Key_Hour,
                                  Minute => Minute,
                                  Second => Second,
                                  Mode => Mode (Mode'First),
                                  Save_Seconds => Save_Seconds));
                           end if;
                        end;
                     end loop;
                  end;
               end loop;

               for Pass in 1 .. Event_Count loop
                  Sort_Events;
                  exit when not Recompute_Event_Sort_Keys;
               end loop;

               Sort_Events;

               for Index in 1 .. Event_Count loop
                  if Events (Index).Sort_Key /= Invalid_Sort_Key then
                     Store_TZDB_Transition
                       (Zone, Events (Index).Sort_Key,
                        Base_Seconds + Events (Index).Save_Seconds);
                  end if;
               end loop;
            end;
         end;
      exception
         when Constraint_Error =>
            null;
      end Apply_TZDB_Rules;

      procedure Queue_TZDB_Rule_Application
        (Zone         : String;
         Rule_Name    : String;
         Base_Seconds : Integer)
      is
         Count_Key : constant String := TZDB_Rule_Application_Count_Key;
         Old_Count : constant Natural :=
           (if TZDB_Rule_Applications.Contains (Count_Key)
            then Natural'Value (TZDB_Rule_Applications.Element (Count_Key))
            else 0);
         New_Count : constant Natural := Old_Count + 1;
      begin
         if Rule_Name = "-" then
            return;
         end if;

         Store
           (TZDB_Rule_Applications, Count_Key, Natural_Text (New_Count));
         Store
          (TZDB_Rule_Applications, TZDB_Rule_Application_Key (New_Count),
            Zone & "|" & Rule_Name & "|" & Integer_Text (Base_Seconds));
      exception
         when Constraint_Error =>
            null;
      end Queue_TZDB_Rule_Application;

      procedure Apply_Queued_TZDB_Rules is
         Count_Key : constant String := TZDB_Rule_Application_Count_Key;
      begin
         if not TZDB_Rule_Applications.Contains (Count_Key) then
            return;
         end if;

         declare
            Count : constant Natural :=
              Natural'Value (TZDB_Rule_Applications.Element (Count_Key));
         begin
            for Index in 1 .. Count loop
               declare
                  Record_Text : constant String :=
                    TZDB_Rule_Applications.Element
                      (TZDB_Rule_Application_Key (Index));
               begin
                  if Field_Count (Record_Text) = 3 then
                     Apply_TZDB_Rules
                       (Field (Record_Text, 1),
                        Field (Record_Text, 2),
                        Integer'Value (Field (Record_Text, 3)));
                  end if;
               end;
            end loop;
         end;
      exception
         when Constraint_Error =>
            null;
      end Apply_Queued_TZDB_Rules;

      function TZDB_Direct_Save_Seconds
        (Rule_Text : String;
         Seconds   : out Integer)
         return Boolean
      is
      begin
         if Rule_Text = "-" then
            Seconds := 0;
            return True;
         end if;

         return Parse_Offset_Seconds (Rule_Text, Seconds);
      end TZDB_Direct_Save_Seconds;

      procedure Parse_TZDB_Zone_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Parts : String_Maps.Map;
         Count : Natural;
      begin
         Read_TZDB_Parts (Line, Parts, Count);

         declare
            Seconds : Integer;
            Save_Seconds : Integer := 0;
            Effective_Seconds : Integer;
         begin
            if Count < 3
              or else not Parts.Contains ("1")
              or else Parts.Element ("1") /= "Zone"
              or else not Parse_Offset_Seconds (Parts.Element ("3"), Seconds)
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid tzdb Zone row");
               Ok := False;
            else
               if Count >= 4
                 and then TZDB_Direct_Save_Seconds
                   (Parts.Element ("4"), Save_Seconds)
               then
                  Effective_Seconds := Seconds + Save_Seconds;
               else
                  Effective_Seconds := Seconds;
               end if;

               TZDB_Pending_Zone := Null_Unbounded_String;
               TZDB_Pending_Until := Null_Unbounded_String;
               Store_TZDB_Base_Offset (Parts.Element ("2"), Effective_Seconds);
               if Count >= 4
                 and then not TZDB_Direct_Save_Seconds
                   (Parts.Element ("4"), Save_Seconds)
               then
                  Queue_TZDB_Rule_Application
                    (Parts.Element ("2"), Parts.Element ("4"), Seconds);
               end if;

               if Count > 5 then
                  declare
                     Until_Key : String (1 .. 14);
                  begin
                     if not Parse_TZDB_Until
                       (Parts, Count, 6,
                        Seconds, Effective_Seconds, Until_Key)
                     then
                        Add_Error (Diagnostics, Source, Number,
                                   "invalid tzdb Zone until fields");
                        Ok := False;
                     else
                        TZDB_Pending_Zone :=
                          To_Unbounded_String (Parts.Element ("2"));
                        TZDB_Pending_Until := To_Unbounded_String (Until_Key);
                     end if;
                  end;
               end if;
            end if;
         end;
      end Parse_TZDB_Zone_Row;

      procedure Parse_TZDB_Continuation_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Parts : String_Maps.Map;
         Count : Natural;
      begin
         Read_TZDB_Parts (Line, Parts, Count);

         declare
            Seconds : Integer;
            Save_Seconds : Integer := 0;
            Effective_Seconds : Integer;
            Zone    : constant String := To_String (TZDB_Pending_Zone);
            Until_Key_Text : constant String := To_String (TZDB_Pending_Until);
         begin
            if Zone = ""
              or else Until_Key_Text'Length /= 14
              or else Count < 3
              or else not Parts.Contains ("1")
              or else not Parse_Offset_Seconds (Parts.Element ("1"), Seconds)
            then
               Add_Error (Diagnostics, Source, Number,
                          "invalid tzdb Zone continuation row");
               Ok := False;
            else
               if TZDB_Direct_Save_Seconds
                 (Parts.Element ("2"), Save_Seconds)
               then
                  Effective_Seconds := Seconds + Save_Seconds;
               else
                  Effective_Seconds := Seconds;
               end if;

               Store_TZDB_Transition
                 (Zone, Until_Key_Text, Effective_Seconds);
               if not TZDB_Direct_Save_Seconds
                 (Parts.Element ("2"), Save_Seconds)
               then
                  Queue_TZDB_Rule_Application
                    (Zone, Parts.Element ("2"), Seconds);
               end if;
               TZDB_Pending_Until := Null_Unbounded_String;

               if Count > 3 then
                  declare
                     Until_Key : String (1 .. 14);
                  begin
                     if not Parse_TZDB_Until
                       (Parts, Count, 4,
                        Seconds, Effective_Seconds, Until_Key)
                     then
                        Add_Error (Diagnostics, Source, Number,
                                   "invalid tzdb Zone continuation until fields");
                        Ok := False;
                        TZDB_Pending_Zone := Null_Unbounded_String;
                     else
                        TZDB_Pending_Until :=
                          To_Unbounded_String (Until_Key);
                     end if;
                  end;
               else
                  TZDB_Pending_Zone := Null_Unbounded_String;
               end if;
            end if;
         end;
      end Parse_TZDB_Continuation_Row;

      procedure Parse_TZDB_Link_Row
        (Line   : String;
         Source : String;
         Number : Natural)
      is
         Parts : String_Maps.Map;
         Count : Natural;
      begin
         Read_TZDB_Parts (Line, Parts, Count);

         if Count < 3
           or else not Parts.Contains ("1")
           or else Parts.Element ("1") /= "Link"
         then
            Add_Error (Diagnostics, Source, Number,
                       "invalid tzdb Link row");
            Ok := False;
         else
            declare
               Target_Minutes_Key : constant String :=
                 Zone_Key (Parts.Element ("2"), "base_offset_minutes");
               Target_Seconds_Key : constant String :=
                 Zone_Key (Parts.Element ("2"), "base_offset_seconds");
               Target_Transition_Prefix : constant String :=
                 Zone_Key (Parts.Element ("2"), Zone_Transition_Field (""));
               Alias_Transition_Prefix : constant String :=
                 Zone_Key (Parts.Element ("3"), Zone_Transition_Field (""));
               Link_Copies : String_Maps.Map;
            begin
               if not Pending_Zones.Contains (Target_Minutes_Key)
                 and then not Pending_Zones.Contains (Target_Seconds_Key)
               then
                  Add_Error (Diagnostics, Source, Number,
                             "tzdb Link target has no loaded fixed offset");
                  Ok := False;
               else
                  if Pending_Zones.Contains (Target_Minutes_Key) then
                     Store
                       (Pending_Zones,
                        Zone_Key (Parts.Element ("3"), "base_offset_minutes"),
                        Pending_Zones.Element (Target_Minutes_Key));
                  end if;

                  if Pending_Zones.Contains (Target_Seconds_Key) then
                     Store
                       (Pending_Zones,
                        Zone_Key (Parts.Element ("3"), "base_offset_seconds"),
                        Pending_Zones.Element (Target_Seconds_Key));
                  end if;

                  for Cursor in Pending_Zones.Iterate loop
                     declare
                        Key : constant String := String_Maps.Key (Cursor);
                     begin
                        if Key'Length >= Target_Transition_Prefix'Length
                          and then Key
                            (Key'First
                             .. Key'First + Target_Transition_Prefix'Length - 1)
                            = Target_Transition_Prefix
                        then
                           Store
                             (Link_Copies,
                              Alias_Transition_Prefix
                              & Key
                                (Key'First + Target_Transition_Prefix'Length
                                 .. Key'Last),
                              String_Maps.Element (Cursor));
                        end if;
                     end;
                  end loop;

                  for Cursor in Link_Copies.Iterate loop
                     Store
                       (Pending_Zones,
                        String_Maps.Key (Cursor),
                        String_Maps.Element (Cursor));
                  end loop;
               end if;
            end;
         end if;
      end Parse_TZDB_Link_Row;

      function Is_TZDB_Continuation_Row (Raw : String) return Boolean is
      begin
         return Raw'Length > 0
           and then (Raw (Raw'First) = ' '
                     or else Raw (Raw'First) = ASCII.HT)
           and then To_String (TZDB_Pending_Zone) /= "";
      end Is_TZDB_Continuation_Row;
   begin
      I18N.Diagnostics.Clear (Diagnostics);

      while Start <= Text'Last loop
         declare
            Stop : Natural := Start;
         begin
            while Stop <= Text'Last
              and then Text (Stop) /= ASCII.LF
              and then Text (Stop) /= ASCII.CR
            loop
               Stop := Stop + 1;
            end loop;

            declare
               Raw  : constant String := Text (Start .. Stop - 1);
               Line : constant String := Trimmed (Raw);
            begin
               if Line'Length = 0
                 or else (Line'Length > 0 and then Line (Line'First) = '#')
               then
                  null;
               elsif Is_XML_Ignorable_Line (Line) then
                  null;
               elsif not LDML_Block_Open
                 and then Is_Inert_LDML_Container_Start (Line)
               then
                  if LDML_Block_Open then
                     Add_Error
                       (Diagnostics, Source_Name, Line_No,
                        "nested LDML container inside multi-line row");
                     Ok := False;
                  elsif LDML_Container_Depth = Max_LDML_Container_Depth then
                     Add_Error
                       (Diagnostics, Source_Name, Line_No,
                        "LDML container nesting too deep");
                     Ok := False;
                  else
                     LDML_Container_Depth := LDML_Container_Depth + 1;
                     LDML_Containers (LDML_Container_Depth) :=
                       To_Unbounded_String (XML_Element_Name (Line));
                     LDML_Container_Lines (LDML_Container_Depth) := Line_No;
                     if XML_Element_Name (Line) = "calendar" then
                        LDML_Context_Calendar :=
                          To_Unbounded_String
                            (Normalize_Calendar_Name
                               (Attribute_Value (Line, "type")));
                     elsif XML_Element_Name (Line) = "monthContext"
                       or else XML_Element_Name (Line) = "dayContext"
                       or else XML_Element_Name (Line) = "quarterContext"
                     then
                        LDML_Context_Date_Name_Context :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "monthWidth"
                       or else XML_Element_Name (Line) = "dayWidth"
                       or else XML_Element_Name (Line) = "quarterWidth"
                     then
                        LDML_Context_Date_Name_Width :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "dayPeriodWidth" then
                        LDML_Context_Day_Period_Width :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "zone" then
                        declare
                           Zone_Type : constant String :=
                             Attribute_Value (Line, "type");
                           Zone_Id : constant String :=
                             Attribute_Value (Line, "id", "zone");
                        begin
                           LDML_Context_Zone :=
                             To_Unbounded_String
                               (if Zone_Type /= "" then Zone_Type else Zone_Id);
                        end;
                     elsif XML_Element_Name (Line) = "long" then
                        LDML_Context_Zone_Width :=
                          To_Unbounded_String ("long");
                     elsif XML_Element_Name (Line) = "short" then
                        LDML_Context_Zone_Width :=
                          To_Unbounded_String ("short");
                     elsif XML_Element_Name (Line) = "unitLength" then
                        LDML_Context_Unit_Width :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "unit" then
                        declare
                           Unit_Type : constant String :=
                             Attribute_Value (Line, "type");
                           Unit_Id : constant String :=
                             Attribute_Value (Line, "unit");
                        begin
                           LDML_Context_Unit :=
                             To_Unbounded_String
                               (if Unit_Type /= "" then Unit_Type else Unit_Id);
                        end;
                     elsif XML_Element_Name (Line) = "compoundUnit" then
                        LDML_Context_Compound_Unit :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "symbols" then
                        LDML_Context_Number_System :=
                          To_Unbounded_String
                            (Attribute_Value (Line, "numberSystem"));
                     elsif XML_Element_Name (Line) = "field" then
                        declare
                           Field_Type : constant String :=
                             Attribute_Value (Line, "type");
                           Has_Narrow : constant Boolean :=
                             Field_Type'Length > 7
                             and then Field_Type
                               (Field_Type'Last - 6 .. Field_Type'Last)
                               = "-narrow";
                           Has_Short : constant Boolean :=
                             Field_Type'Length > 6
                             and then Field_Type
                               (Field_Type'Last - 5 .. Field_Type'Last)
                               = "-short";
                           Unit_Text : constant String :=
                             (if Has_Narrow
                              then Field_Type
                                (Field_Type'First .. Field_Type'Last - 7)
                              elsif Has_Short
                              then Field_Type
                                (Field_Type'First .. Field_Type'Last - 6)
                              else Field_Type);
                           Width_Text : constant String :=
                             (if Has_Narrow then "unit-width-narrow"
                              elsif Has_Short then "unit-width-short"
                              else "unit-width-full-name");
                        begin
                           LDML_Context_Relative_Unit :=
                             To_Unbounded_String
                               (Normalize_Relative_Unit (Unit_Text));
                           LDML_Context_Relative_Width :=
                             To_Unbounded_String (Width_Text);
                        end;
                     elsif XML_Element_Name (Line) = "relativeTime" then
                        LDML_Context_Relative_Direction :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "listPattern" then
                        LDML_Context_List_Pattern :=
                          To_Unbounded_String (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "currency" then
                        declare
                           Currency_Code : constant String :=
                             Attribute_Value (Line, "code", "type");
                           Currency_Iso : constant String :=
                             Attribute_Value (Line, "iso4217");
                        begin
                           LDML_Context_Currency :=
                             To_Unbounded_String
                               (if Currency_Code /= "" then Currency_Code
                                else Currency_Iso);
                        end;
                     elsif XML_Element_Name (Line) = "currencyFormat" then
                        LDML_Context_Currency_Format :=
                          To_Unbounded_String
                            (Attribute_Value (Line, "type"));
                     elsif XML_Element_Name (Line) = "beforeCurrency" then
                        LDML_Context_Currency_Spacing :=
                          To_Unbounded_String ("before");
                     elsif XML_Element_Name (Line) = "afterCurrency" then
                        LDML_Context_Currency_Spacing :=
                          To_Unbounded_String ("after");
                     elsif XML_Element_Name (Line) = "dateFormatLength"
                       or else XML_Element_Name (Line) = "timeFormatLength"
                       or else XML_Element_Name (Line) = "dateTimeFormatLength"
                     then
                        declare
                           Element : constant String := XML_Element_Name (Line);
                           Raw_Style : constant String :=
                             Attribute_Value (Line, "type", "style");
                           Style : constant String :=
                             (if Raw_Style /= "" then Raw_Style
                              else Attribute_Value (Line, "length"));
                        begin
                           LDML_Context_Date_Time_Style :=
                             To_Unbounded_String (Style);
                           LDML_Context_Date_Time_Kind :=
                             To_Unbounded_String
                               (if Element = "dateFormatLength" then "date"
                                elsif Element = "timeFormatLength" then "time"
                                else "datetime");
                        end;
                     elsif XML_Element_Name (Line) = "dateFormat"
                       or else XML_Element_Name (Line) = "timeFormat"
                       or else XML_Element_Name (Line) = "dateTimeFormat"
                     then
                        declare
                           Element : constant String := XML_Element_Name (Line);
                           Raw_Style : constant String :=
                             Attribute_Value (Line, "type", "style");
                           Style : constant String :=
                             (if Raw_Style /= "" then Raw_Style
                              else Attribute_Value (Line, "length"));
                        begin
                           if Style /= "" then
                              LDML_Context_Date_Time_Style :=
                                To_Unbounded_String (Style);
                           end if;
                           LDML_Context_Date_Time_Kind :=
                             To_Unbounded_String
                               (if Element = "dateFormat" then "date"
                                elsif Element = "timeFormat" then "time"
                                else "datetime");
                        end;
                     elsif XML_Element_Name (Line) = "plurals" then
                        LDML_Context_Plurals_Kind :=
                          To_Unbounded_String
                            (Attribute_Value (Line, "type", "kind"));
                     elsif XML_Element_Name (Line) = "pluralRules" then
                        declare
                           Rule_Kind : constant String :=
                             Attribute_Value (Line, "type", "kind");
                           Rule_Locales : constant String :=
                             Attribute_Value (Line, "locales", "locale");
                        begin
                           LDML_Context_Plural_Rules_Kind :=
                             To_Unbounded_String (Rule_Kind);
                           LDML_Context_Plural_Rules_Locales :=
                             To_Unbounded_String (Rule_Locales);
                        end;
                     elsif XML_Element_Name (Line) = "dayPeriodRuleSet" then
                        LDML_Context_Day_Period_Rule_Set_Locales :=
                          To_Unbounded_String
                            (Attribute_Value (Line, "locales", "locale"));
                     elsif XML_Element_Name (Line) = "dayPeriodRules" then
                        LDML_Context_Day_Period_Rules_Locales :=
                          To_Unbounded_String
                            (Attribute_Value (Line, "locales", "locale"));
                     elsif XML_Element_Name (Line) = "ruleset"
                       or else XML_Element_Name (Line) = "ruleSet"
                     then
                        declare
                           Ruleset_Type : constant String :=
                             Attribute_Value (Line, "type", "ruleSet");
                           Ruleset_Name : constant String :=
                             (if Ruleset_Type /= "" then Ruleset_Type
                              else Attribute_Value (Line, "ruleset"));
                        begin
                           LDML_Context_RBNF_Ruleset :=
                             To_Unbounded_String (Ruleset_Name);
                        end;
                     end if;
                  end if;
               elsif not LDML_Block_Open
                 and then Is_Inert_LDML_Container_Close (Line)
               then
                  if LDML_Container_Depth = 0 then
                     Add_Error
                       (Diagnostics, Source_Name, Line_No,
                        "unmatched LDML container close");
                     Ok := False;
                  elsif To_String (LDML_Containers (LDML_Container_Depth))
                    /= XML_Element_Name (Line)
                  then
                     Add_Error
                       (Diagnostics, Source_Name, Line_No,
                        "mismatched LDML container close");
                     Ok := False;
                  else
                     if XML_Element_Name (Line) = "calendar" then
                        LDML_Context_Calendar := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "monthContext"
                       or else XML_Element_Name (Line) = "dayContext"
                       or else XML_Element_Name (Line) = "quarterContext"
                     then
                        LDML_Context_Date_Name_Context :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "monthWidth"
                       or else XML_Element_Name (Line) = "dayWidth"
                       or else XML_Element_Name (Line) = "quarterWidth"
                     then
                        LDML_Context_Date_Name_Width :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "dayPeriodWidth" then
                        LDML_Context_Day_Period_Width :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "zone" then
                        LDML_Context_Zone := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "long"
                       or else XML_Element_Name (Line) = "short"
                     then
                        LDML_Context_Zone_Width := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "unitLength" then
                        LDML_Context_Unit_Width := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "unit" then
                        LDML_Context_Unit := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "compoundUnit" then
                        LDML_Context_Compound_Unit := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "symbols" then
                        LDML_Context_Number_System := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "field" then
                        LDML_Context_Relative_Unit := Null_Unbounded_String;
                        LDML_Context_Relative_Width := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "relativeTime" then
                        LDML_Context_Relative_Direction :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "listPattern" then
                        LDML_Context_List_Pattern := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "currency" then
                        LDML_Context_Currency := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "currencyFormat" then
                        LDML_Context_Currency_Format :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "beforeCurrency"
                       or else XML_Element_Name (Line) = "afterCurrency"
                     then
                        LDML_Context_Currency_Spacing :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "dateFormatLength"
                       or else XML_Element_Name (Line) = "timeFormatLength"
                       or else XML_Element_Name (Line) = "dateTimeFormatLength"
                     then
                        LDML_Context_Date_Time_Kind := Null_Unbounded_String;
                        LDML_Context_Date_Time_Style := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "dateFormat"
                       or else XML_Element_Name (Line) = "timeFormat"
                       or else XML_Element_Name (Line) = "dateTimeFormat"
                     then
                        LDML_Context_Date_Time_Kind := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "plurals" then
                        LDML_Context_Plurals_Kind := Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "pluralRules" then
                        LDML_Context_Plural_Rules_Kind :=
                          Null_Unbounded_String;
                        LDML_Context_Plural_Rules_Locales :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "dayPeriodRuleSet" then
                        LDML_Context_Day_Period_Rule_Set_Locales :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "dayPeriodRules" then
                        LDML_Context_Day_Period_Rules_Locales :=
                          Null_Unbounded_String;
                     elsif XML_Element_Name (Line) = "ruleset"
                       or else XML_Element_Name (Line) = "ruleSet"
                     then
                        LDML_Context_RBNF_Ruleset := Null_Unbounded_String;
                     end if;
                     LDML_Containers (LDML_Container_Depth) :=
                       Null_Unbounded_String;
                     LDML_Container_Lines (LDML_Container_Depth) := 0;
                     LDML_Container_Depth := LDML_Container_Depth - 1;
                  end if;
               elsif Is_LDML_Identity_Row (Line) then
                  Apply_LDML_Identity_Row (Line);
               elsif Is_LDML_Context_Start (Line) then
                  declare
                     Context_Locale : constant String :=
                       LDML_Context_Start_Locale (Line);
                  begin
                     if LDML_Context_Open then
                        Add_Error
                          (Diagnostics, Source_Name, Line_No,
                           "nested LDML locale context");
                        Ok := False;
                     elsif Context_Locale = "" and then Line /= "<ldml>" then
                        Add_Error
                          (Diagnostics, Source_Name, Line_No,
                           "missing LDML locale context");
                        Ok := False;
                     else
                        LDML_Context_Open := True;
                        LDML_Context_Start_Line := Line_No;
                        LDML_Context_End_Tag :=
                          To_Unbounded_String (LDML_Context_Close_Tag (Line));
                        LDML_Context_Locale :=
                          To_Unbounded_String (Context_Locale);
                        LDML_Context_Explicit_Locale := Context_Locale /= "";
                     end if;
                  end;
               elsif LDML_Context_Open
                 and then Line = To_String (LDML_Context_End_Tag)
               then
                  Reset_LDML_Identity_Context;
               elsif LDML_Block_Open then
                  declare
                     Expected_Close : constant String :=
                       To_String (LDML_Block_End_Tag);
                  begin
                     if Line = Expected_Close then
                        declare
                           Logical_Line : constant String :=
                             To_String (LDML_Block_Open_Tag)
                             & To_String (LDML_Block_Text)
                             & Expected_Close;
                           Start_Line : constant Natural :=
                             LDML_Block_Start_Line;
                        begin
                           Reset_LDML_Block;
                           Parse_LDML_Row
                             (Logical_Line, Source_Name, Start_Line);
                        end;
                     elsif Is_LDML_Block_Close (Line) then
                        Add_Error
                          (Diagnostics, Source_Name, Line_No,
                           "mismatched multi-line LDML closing tag");
                        Ok := False;
                        Reset_LDML_Block;
                     elsif Is_LDML_Block_Start (Line) then
                        Add_Error
                          (Diagnostics, Source_Name, Line_No,
                           "nested multi-line LDML row");
                        Ok := False;
                        Reset_LDML_Block;
                     elsif To_String (LDML_Block_Text)'Length
                       + Line'Length > 4096
                     then
                        Add_Error
                          (Diagnostics, Source_Name, Line_No,
                           "multi-line LDML row too long");
                        Ok := False;
                        Reset_LDML_Block;
                     else
                        Append_LDML_Block_Text (Line);
                     end if;
                  end;
               else
                  declare
                     Logical_Line : constant String :=
                       With_LDML_Context (Line);
                     Eq           : constant Natural :=
                       Equals_Index (Logical_Line);
                  begin
                     if Is_LDML_Block_Start (Logical_Line) then
                        LDML_Block_Open := True;
                        LDML_Block_Start_Line := Line_No;
                        LDML_Block_Open_Tag :=
                          To_Unbounded_String (Logical_Line);
                        LDML_Block_End_Tag :=
                          To_Unbounded_String
                            (LDML_Block_Close_Tag (Logical_Line));
                        LDML_Block_Text := Null_Unbounded_String;
                     elsif Is_Normalized_CLDR_Row (Logical_Line) then
                        Parse_Normalized_CLDR_Row
                          (Logical_Line, Source_Name, Line_No);
                     elsif Is_LDML_Row (Logical_Line) then
                        Parse_LDML_Row (Logical_Line, Source_Name, Line_No);
                     elsif Is_TZDB_Continuation_Row (Raw) then
                        Parse_TZDB_Continuation_Row
                          (Logical_Line, Source_Name, Line_No);
                     elsif Is_TZDB_Zone_Row (Logical_Line) then
                        Parse_TZDB_Zone_Row
                          (Logical_Line, Source_Name, Line_No);
                     elsif Is_TZDB_Rule_Row (Logical_Line) then
                        Parse_TZDB_Rule_Row
                          (Logical_Line, Source_Name, Line_No);
                     elsif Is_TZDB_Link_Row (Logical_Line) then
                        Parse_TZDB_Link_Row
                          (Logical_Line, Source_Name, Line_No);
                     elsif Eq = 0 then
                        Add_Error (Diagnostics, Source_Name, Line_No,
                                   "missing '=' in runtime data");
                        Ok := False;
                     else
                        declare
                           Key   : constant String :=
                             Trimmed
                               (Logical_Line
                                  (Logical_Line'First .. Eq - 1));
                           Value : constant String :=
                             Unquote
                               (Logical_Line
                                  (Eq + 1 .. Logical_Line'Last));
                        begin
                           if Has_Prefix (Key, Locale_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + Locale_Prefix'Length;
                                 Sep        : constant Natural :=
                                   Dot_Index (Key, Rest_First);
                              begin
                                 if Sep = 0 or else Sep = Rest_First then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid locale runtime data key");
                                    Ok := False;
                                 else
                                    declare
                                       Locale : constant String :=
                                         Key (Rest_First .. Sep - 1);
                                       Field  : constant String :=
                                         Key (Sep + 1 .. Key'Last);
                                    begin
                                       if not Valid_Locale_Field
                                                (Field, Value)
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "unsupported locale runtime data field");
                                          Ok := False;
                                       else
                                          Store
                                            (Pending_Locales,
                                             Locale_Key (Locale, Field),
                                             Value);
                                       end if;
                                    end;
                                 end if;
                              end;
                           elsif Has_Prefix (Key, Timezone_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + Timezone_Prefix'Length;
                                 Sep        : constant Natural := Last_Dot_Index (Key);
                                 Transition_Marker : constant String :=
                                   ".transition.";
                                 Transition_Index : constant Natural :=
                                   Ada.Strings.Fixed.Index
                                     (Key, Transition_Marker, Rest_First);
                              begin
                                 if Transition_Index /= 0 then
                                    declare
                                       Zone : constant String :=
                                         Key (Rest_First .. Transition_Index - 1);
                                       Raw_Key : constant String :=
                                         Key
                                           (Transition_Index
                                            + Transition_Marker'Length
                                            .. Key'Last);
                                       Parsed_Key : String (1 .. 14);
                                    begin
                                       if Zone = ""
                                         or else not Parse_UTC_Key
                                           (Raw_Key, Parsed_Key)
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid timezone transition key");
                                          Ok := False;
                                       elsif not Is_Integer_Text (Value)
                                         or else not In_Integer_Range (Value)
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid timezone transition value");
                                          Ok := False;
                                       else
                                          declare
                                             Seconds : constant Integer :=
                                               Integer'Value (Value);
                                          begin
                                             if Seconds not in -86_400 .. 86_400 then
                                                Add_Error
                                                  (Diagnostics, Source_Name, Line_No,
                                                   "timezone transition value out of range");
                                                Ok := False;
                                             else
                                                Store
                                                  (Pending_Zones,
                                                   Zone_Key
                                                     (Zone,
                                                      Zone_Transition_Field
                                                        (Parsed_Key)),
                                                   Integer_Text (Seconds));
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 elsif Sep = 0 or else Sep <= Rest_First then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid timezone runtime data key");
                                    Ok := False;
                                 elsif Key (Sep + 1 .. Key'Last)
                                   /= "base_offset_minutes"
                                   and then Key (Sep + 1 .. Key'Last)
                                     /= "base_offset_seconds"
                                 then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "unsupported timezone runtime data field");
                                    Ok := False;
                                 elsif not Is_Integer_Text (Value) then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid timezone offset value");
                                    Ok := False;
                                 elsif not In_Integer_Range (Value) then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "timezone offset value out of range");
                                    Ok := False;
                                 else
                                    declare
                                       Field : constant String :=
                                         Key (Sep + 1 .. Key'Last);
                                       Offset : constant Integer :=
                                         Integer'Value (Value);
                                    begin
                                       if Field = "base_offset_seconds"
                                         and then Offset not in
                                           -86_400 .. 86_400
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "timezone offset value out of range");
                                          Ok := False;
                                       elsif Field = "base_offset_minutes"
                                         and then Offset not in -1_440 .. 1_440
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "timezone offset value out of range");
                                          Ok := False;
                                       else
                                          Store
                                            (Pending_Zones,
                                             Zone_Key
                                               (Key (Rest_First .. Sep - 1),
                                                Field),
                                             Value);
                                       end if;
                                    end;
                                 end if;
                              end;
                           elsif Has_Prefix (Key, Currency_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + Currency_Prefix'Length;
                                 Sep        : constant Natural :=
                                   Dot_Index (Key, Rest_First);
                              begin
                                 if Sep = 0 or else Sep /= Rest_First + 3 then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid currency runtime data key");
                                    Ok := False;
                                 else
                                    declare
                                       Code  : constant String :=
                                         Key (Rest_First .. Sep - 1);
                                       Field : constant String :=
                                         Key (Sep + 1 .. Key'Last);
                                    begin
                                       if Code'Length /= 3
                                         or else Field'Length = 0
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid currency runtime data key");
                                          Ok := False;
                                       elsif Field = "minor_units"
                                         or else Field = "cash_increment"
                                       then
                                          if not In_Integer_Range (Value)
                                            or else Integer'Value (Value) < 0
                                          then
                                             Add_Error
                                               (Diagnostics, Source_Name, Line_No,
                                                "invalid currency numeric metadata");
                                             Ok := False;
                                          else
                                             Store
                                               (Pending_Currencies,
                                                Currency_Key (Code, Field),
                                                Value);
                                          end if;
                                       elsif Field = "symbol"
                                         or else Field = "narrow_symbol"
                                         or else Field = "display_name"
                                         or else Field = "display_name.zero"
                                         or else Field = "display_name.one"
                                         or else Field = "display_name.two"
                                         or else Field = "display_name.few"
                                         or else Field = "display_name.many"
                                         or else Field = "display_name.other"
                                       then
                                          if Value'Length = 0 then
                                             Add_Error
                                               (Diagnostics, Source_Name, Line_No,
                                                "empty currency text metadata");
                                             Ok := False;
                                          else
                                             Store
                                               (Pending_Currencies,
                                                Currency_Key (Code, Field),
                                                Value);
                                          end if;
                                       else
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "unsupported currency runtime data field");
                                          Ok := False;
                                       end if;
                                    end;
                                 end if;
                              end;
                           elsif Has_Prefix (Key, Plural_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + Plural_Prefix'Length;
                                 Kind_End   : constant Natural :=
                                   Dot_Index (Key, Rest_First);
                              begin
                                 if Key'Length > Plural_Prefix'Length + 11
                                   and then Key
                                     (Rest_First .. Rest_First + 10)
                                     = "rule_family"
                                 then
                                    declare
                                       Kind_First : constant Positive :=
                                         Rest_First + 11 + 1;
                                       Kind_Stop  : constant Natural :=
                                         Dot_Index (Key, Kind_First);
                                    begin
                                       if Kind_Stop = 0
                                         or else Kind_Stop = Kind_First
                                         or else Kind_Stop = Key'Last
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid plural rule-family key");
                                          Ok := False;
                                       else
                                          declare
                                             Kind : constant String :=
                                               Key (Kind_First .. Kind_Stop - 1);
                                             Locale : constant String :=
                                               Key (Kind_Stop + 1 .. Key'Last);
                                          begin
                                             if not Is_Plural_Rule_Family
                                               (Kind, Value)
                                             then
                                                Add_Error
                                                  (Diagnostics, Source_Name, Line_No,
                                                   "invalid plural rule-family value");
                                                Ok := False;
                                             else
                                                Store
                                                  (Pending_Plural_Families,
                                                   Plural_Family_Key (Kind, Locale),
                                                   Value);
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 elsif Key'Length > Plural_Prefix'Length + 4
                                   and then Key
                                     (Rest_First .. Rest_First + 3)
                                     = "rule"
                                 then
                                    declare
                                       Kind_First : constant Positive :=
                                         Rest_First + 4 + 1;
                                       Kind_Stop  : constant Natural :=
                                         Dot_Index (Key, Kind_First);
                                       Category_Start : constant Natural :=
                                         Last_Dot_Index (Key);
                                    begin
                                       if Kind_Stop = 0
                                         or else Kind_Stop = Kind_First
                                         or else Category_Start <= Kind_Stop + 1
                                         or else Category_Start = Key'Last
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid plural rule-expression key");
                                          Ok := False;
                                       else
                                          Store_Plural_Category_Rule
                                            (Key (Kind_First .. Kind_Stop - 1),
                                             Key (Kind_Stop + 1
                                                  .. Category_Start - 1),
                                             Key (Category_Start + 1 .. Key'Last),
                                             Value,
                                             Source_Name,
                                             Line_No);
                                       end if;
                                    end;
                                 elsif Kind_End = 0 or else Kind_End = Rest_First then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid plural runtime data key");
                                    Ok := False;
                                 else
                                    declare
                                       Kind         : constant String :=
                                         Key (Rest_First .. Kind_End - 1);
                                       Locale_First : constant Positive :=
                                         Kind_End + 1;
                                       Value_Start  : constant Natural :=
                                         Last_Dot_Index (Key);
                                    begin
                                       if (Kind /= "cardinal"
                                             and then Kind /= "ordinal")
                                         or else Value_Start <= Locale_First
                                         or else Value_Start = Key'Last
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid plural runtime data key");
                                          Ok := False;
                                       elsif not In_Long_Long_Integer_Range
                                         (Key (Value_Start + 1 .. Key'Last))
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid plural override value");
                                          Ok := False;
                                       elsif not Is_Plural_Category (Value) then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid plural override category");
                                          Ok := False;
                                       else
                                          declare
                                             Operand : constant Long_Long_Integer :=
                                               Long_Long_Integer'Value
                                                 (Key (Value_Start + 1
                                                  .. Key'Last));
                                          begin
                                             if Operand < 0 then
                                                Add_Error
                                                  (Diagnostics, Source_Name, Line_No,
                                                   "negative plural override value");
                                                Ok := False;
                                             else
                                                Store
                                                  (Pending_Plurals,
                                                   Plural_Key
                                                     (Kind,
                                                      Key (Locale_First
                                                       .. Value_Start - 1),
                                                      Long_Long_Integer'Image
                                                        (Operand)),
                                                   Value);
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end if;
                              end;
                           elsif Has_Prefix (Key, RBNF_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + RBNF_Prefix'Length;
                                 Locale_End : constant Natural :=
                                   Dot_Index (Key, Rest_First);
                              begin
                                 if Locale_End = 0
                                   or else Locale_End = Rest_First
                                   or else Locale_End = Key'Last
                                 then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid RBNF runtime data key");
                                    Ok := False;
                                 else
                                    declare
                                       Locale : constant String :=
                                         Key (Rest_First .. Locale_End - 1);
                                       Rest   : constant String :=
                                         Key (Locale_End + 1 .. Key'Last);
                                    begin
                                       if Rest = "decimal_separator" then
                                          Store_Spellout_Text
                                            (Locale,
                                             Rest,
                                             "",
                                             Value,
                                             Source_Name,
                                             Line_No);
                                       else
                                          declare
                                             Value_Start : constant Natural :=
                                               Dot_Index (Rest, Rest'First);
                                          begin
                                             if Value_Start = 0
                                               or else Value_Start = Rest'First
                                               or else Value_Start = Rest'Last
                                             then
                                                Add_Error
                                                  (Diagnostics, Source_Name, Line_No,
                                                   "invalid RBNF runtime data key");
                                                Ok := False;
                                             else
                                                Store_Spellout_Text
                                                  (Locale,
                                                   Rest (Rest'First
                                                         .. Value_Start - 1),
                                                   Rest (Value_Start + 1
                                                         .. Rest'Last),
                                                   Value,
                                                   Source_Name,
                                                   Line_No);
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end if;
                              end;
                           elsif Has_Prefix (Key, RBNF_Rule_Prefix) then
                              declare
                                 Rest_First : constant Positive :=
                                   Key'First + RBNF_Rule_Prefix'Length;
                                 Locale_End : constant Natural :=
                                   Dot_Index (Key, Rest_First);
                              begin
                                 if Locale_End = 0
                                   or else Locale_End = Rest_First
                                   or else Locale_End = Key'Last
                                 then
                                    Add_Error
                                      (Diagnostics, Source_Name, Line_No,
                                       "invalid RBNF rule runtime data key");
                                    Ok := False;
                                 else
                                    declare
                                       Locale : constant String :=
                                         Key (Rest_First .. Locale_End - 1);
                                       Rest   : constant String :=
                                         Key (Locale_End + 1 .. Key'Last);
                                       Base_Start : constant Natural :=
                                         Dot_Index (Rest, Rest'First);
                                    begin
                                       if Base_Start = 0
                                         or else Base_Start = Rest'First
                                         or else Base_Start = Rest'Last
                                       then
                                          Add_Error
                                            (Diagnostics, Source_Name, Line_No,
                                             "invalid RBNF rule runtime data key");
                                          Ok := False;
                                       else
                                          Store_Spellout_Rule
                                            (Locale,
                                             Rest (Rest'First .. Base_Start - 1),
                                             Rest (Base_Start + 1 .. Rest'Last),
                                             Value,
                                             Source_Name,
                                             Line_No);
                                       end if;
                                    end;
                                 end if;
                              end;
                           else
                              Add_Error
                                (Diagnostics, Source_Name, Line_No,
                                 "unsupported runtime data key");
                              Ok := False;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;

            Start := Stop;
            while Start <= Text'Last
              and then (Text (Start) = ASCII.LF or else Text (Start) = ASCII.CR)
            loop
               Start := Start + 1;
            end loop;
            Line_No := Line_No + 1;
         end;
      end loop;

      if LDML_Block_Open then
         Add_Error
           (Diagnostics, Source_Name, LDML_Block_Start_Line,
            "unterminated multi-line LDML row");
         Ok := False;
         Reset_LDML_Block;
      end if;

      if LDML_Context_Open then
         Add_Error
           (Diagnostics, Source_Name, LDML_Context_Start_Line,
            "unterminated LDML locale context");
         Ok := False;
         Reset_LDML_Identity_Context;
      end if;

      if LDML_Container_Depth > 0 then
         Add_Error
           (Diagnostics, Source_Name,
            LDML_Container_Lines (LDML_Container_Depth),
            "unterminated LDML container");
         Ok := False;
         while LDML_Container_Depth > 0 loop
            LDML_Containers (LDML_Container_Depth) :=
              Null_Unbounded_String;
            LDML_Container_Lines (LDML_Container_Depth) := 0;
            LDML_Container_Depth := LDML_Container_Depth - 1;
         end loop;
      end if;

      if Ok then
         Apply_Queued_TZDB_Rules;
         Locale_Overrides := Pending_Locales;
         Zone_Overrides := Pending_Zones;
         Currency_Overrides := Pending_Currencies;
         Locale_Currency_Overrides := Pending_Locale_Currencies;
         Plural_Overrides := Pending_Plurals;
         Plural_Family_Overrides := Pending_Plural_Families;
         Plural_Rule_Overrides := Pending_Plural_Rules;
         Spellout_Overrides := Pending_Spellouts;
         Spellout_Rule_Overrides := Pending_Spellout_Rules;
      end if;

      return Ok;
   end Load_Text;

   function Locale_Text
     (Locale : String;
      Field  : String;
      Found  : out Boolean)
      return String
   is
      Key    : constant String := Locale_Key (Locale, Field);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Locale_Overrides.Contains (Key) then
         Found := True;
         return Locale_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Locale_Overrides.Contains (Locale_Key (Parent, Field))
      then
         Found := True;
         return Locale_Overrides.Element (Locale_Key (Parent, Field));
      else
         Found := False;
         return "";
      end if;
   end Locale_Text;

   function Locale_Indexed_Text
     (Locale : String;
      Field  : String;
      Index  : Natural;
      Found  : out Boolean)
      return String
   is
   begin
      return Locale_Text (Locale, Field & "." & Natural_Text (Index), Found);
   end Locale_Indexed_Text;

   function Locale_Digit_Text
     (Locale : String;
      Digit  : Character;
      Found  : out Boolean)
      return String
   is
      Direct_Found : Boolean;
      Direct_Value : constant String :=
        Locale_Indexed_Text
          (Locale,
           "digit",
           Character'Pos (Digit) - Character'Pos ('0'),
           Direct_Found);
   begin
      if Direct_Found then
         Found := True;
         return Direct_Value;
      elsif Has_Explicit_Numbering_System (Locale) then
         Found := False;
         return "";
      else
         declare
            System_Found : Boolean;
            System_Name  : constant String :=
              Locale_Text (Locale, "default_numbering_system", System_Found);
         begin
            if System_Found and then Is_Supported_Numbering_System (System_Name)
            then
               Found := True;
               return Numbering_System_Digit (System_Name, Digit);
            else
               Found := False;
               return "";
            end if;
         end;
      end if;
   end Locale_Digit_Text;

   function Locale_Boolean
     (Locale : String;
      Field  : String;
      Found  : out Boolean)
      return Boolean
   is
      Value : constant String := Locale_Text (Locale, Field, Found);
      Wildcard_IN_Key : constant String := Locale_Key ("*-IN", Field);
   begin
      if Found then
         return Value = "true";
      elsif Has_Suffix (Locale, "-IN")
        and then Locale_Overrides.Contains (Wildcard_IN_Key)
      then
         Found := True;
         return Locale_Overrides.Element (Wildcard_IN_Key) = "true";
      else
         return False;
      end if;
   end Locale_Boolean;

   function Time_Zone_Base_Offset_Minutes
     (Zone  : String;
      Found : out Boolean)
      return Integer
   is
      Key : constant String := Zone_Key (Zone, "base_offset_minutes");
      Seconds_Key : constant String := Zone_Key (Zone, "base_offset_seconds");
   begin
      if Zone_Overrides.Contains (Key) then
         Found := True;
         return Integer'Value (Zone_Overrides.Element (Key));
      elsif Zone_Overrides.Contains (Seconds_Key)
        and then Integer'Value (Zone_Overrides.Element (Seconds_Key)) mod 60 = 0
      then
         Found := True;
         return Integer'Value (Zone_Overrides.Element (Seconds_Key)) / 60;
      else
         Found := False;
         return 0;
      end if;
   end Time_Zone_Base_Offset_Minutes;

   function Time_Zone_Offset_Seconds_At_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Found  : out Boolean)
      return Integer
   is
      Query_Key : constant String :=
        UTC_Key (Year, Month, Day, Hour, Minute, Second);
      Prefix : constant String :=
        Zone_Key (Zone, Zone_Transition_Field (""));
      Best_Key   : Unbounded_String;
      Best_Value : Unbounded_String;
   begin
      Found := False;

      if not Valid_UTC_Fields (Year, Month, Day, Hour, Minute, Second) then
         return 0;
      end if;

      for Cursor in Zone_Overrides.Iterate loop
         declare
            Key : constant String := String_Maps.Key (Cursor);
         begin
            if Key'Length = Prefix'Length + 14
              and then Key (Key'First .. Key'First + Prefix'Length - 1)
                       = Prefix
            then
               declare
                  Transition_Key : constant String :=
                    Key (Key'First + Prefix'Length .. Key'Last);
               begin
                  if Transition_Key <= Query_Key
                    and then (To_String (Best_Key) = ""
                              or else Transition_Key > To_String (Best_Key))
                  then
                     Best_Key := To_Unbounded_String (Transition_Key);
                     Best_Value :=
                       To_Unbounded_String (String_Maps.Element (Cursor));
                  end if;
               end;
            end if;
         end;
      end loop;

      if To_String (Best_Key) /= "" then
         Found := True;
         return Integer'Value (To_String (Best_Value));
      elsif Zone_Overrides.Contains (Zone_Key (Zone, "base_offset_seconds")) then
         Found := True;
         return Integer'Value
           (Zone_Overrides.Element (Zone_Key (Zone, "base_offset_seconds")));
      else
         return 0;
      end if;
   end Time_Zone_Offset_Seconds_At_UTC;

   function Currency_Text
     (Code  : String;
      Field : String;
      Found : out Boolean)
      return String
   is
      Key : constant String := Currency_Key (Code, Field);
   begin
      if Currency_Overrides.Contains (Key) then
         Found := True;
         return Currency_Overrides.Element (Key);
      else
         Found := False;
         return "";
      end if;
   end Currency_Text;

   function Currency_Text
     (Locale : String;
      Code   : String;
      Field  : String;
      Found  : out Boolean)
      return String
   is
      Key    : constant String := Locale_Currency_Key (Locale, Code, Field);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Locale_Currency_Overrides.Contains (Key) then
         Found := True;
         return Locale_Currency_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Locale_Currency_Overrides.Contains
          (Locale_Currency_Key (Parent, Code, Field))
      then
         Found := True;
         return
           Locale_Currency_Overrides.Element
             (Locale_Currency_Key (Parent, Code, Field));
      else
         Found := False;
         return "";
      end if;
   end Currency_Text;

   function Currency_Natural
     (Code  : String;
      Field : String;
      Found : out Boolean)
      return Natural
   is
      Value : constant String := Currency_Text (Code, Field, Found);
   begin
      if Found then
         return Natural'Value (Value);
      else
         return 0;
      end if;
   end Currency_Natural;

   function Plural_Category
     (Kind   : String;
      Locale : String;
      Value  : Long_Long_Integer;
      Found  : out Boolean)
      return String
   is
      Image  : constant String := Long_Long_Integer'Image (Value);
      Key    : constant String := Plural_Key (Kind, Locale, Image);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Plural_Overrides.Contains (Key) then
         Found := True;
         return Plural_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Plural_Overrides.Contains (Plural_Key (Kind, Parent, Image))
      then
         Found := True;
         return Plural_Overrides.Element (Plural_Key (Kind, Parent, Image));
      else
         Found := False;
         return "";
      end if;
   end Plural_Category;

   function Plural_Rule_Family
     (Kind   : String;
      Locale : String;
      Found  : out Boolean)
      return String
   is
      Key    : constant String := Plural_Family_Key (Kind, Locale);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Plural_Family_Overrides.Contains (Key) then
         Found := True;
         return Plural_Family_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Plural_Family_Overrides.Contains
          (Plural_Family_Key (Kind, Parent))
      then
         Found := True;
         return Plural_Family_Overrides.Element (Plural_Family_Key (Kind, Parent));
      else
         Found := False;
         return "";
      end if;
   end Plural_Rule_Family;

   function Plural_Category_Rule
     (Kind     : String;
      Locale   : String;
      Category : String;
      Found    : out Boolean)
      return String
   is
      Key    : constant String :=
        Plural_Category_Rule_Key (Kind, Locale, Category);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Plural_Rule_Overrides.Contains (Key) then
         Found := True;
         return Plural_Rule_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Plural_Rule_Overrides.Contains
          (Plural_Category_Rule_Key (Kind, Parent, Category))
      then
         Found := True;
         return
           Plural_Rule_Overrides.Element
             (Plural_Category_Rule_Key (Kind, Parent, Category));
      else
         Found := False;
         return "";
      end if;
   end Plural_Category_Rule;

   function Spellout_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Found  : out Boolean)
      return String
   is
      Value_Text : constant String := Natural_Text (Value);
      Key        : constant String := Spellout_Key (Locale, Kind, Value_Text);
      Parent     : constant String := Parent_Locale (Locale);
   begin
      if Spellout_Overrides.Contains (Key) then
         Found := True;
         return Spellout_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Spellout_Overrides.Contains
          (Spellout_Key (Parent, Kind, Value_Text))
      then
         Found := True;
         return
           Spellout_Overrides.Element
             (Spellout_Key (Parent, Kind, Value_Text));
      else
         Found := False;
         return "";
      end if;
   end Spellout_Text;

   function Spellout_Signed_Text
     (Locale : String;
      Kind   : String;
      Value  : Integer;
      Found  : out Boolean)
      return String
   is
      Value_Text : constant String := Integer_Text (Value);
      Key        : constant String := Spellout_Key (Locale, Kind, Value_Text);
      Parent     : constant String := Parent_Locale (Locale);
   begin
      if Spellout_Overrides.Contains (Key) then
         Found := True;
         return Spellout_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Spellout_Overrides.Contains
          (Spellout_Key (Parent, Kind, Value_Text))
      then
         Found := True;
         return
           Spellout_Overrides.Element
             (Spellout_Key (Parent, Kind, Value_Text));
      else
         Found := False;
         return "";
      end if;
   end Spellout_Signed_Text;

   function Spellout_Value_Text
     (Locale     : String;
      Kind       : String;
      Value_Text : String;
      Found      : out Boolean)
      return String
   is
      Key    : constant String := Spellout_Key (Locale, Kind, Value_Text);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Spellout_Overrides.Contains (Key) then
         Found := True;
         return Spellout_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Spellout_Overrides.Contains
          (Spellout_Key (Parent, Kind, Value_Text))
      then
         Found := True;
         return
           Spellout_Overrides.Element
             (Spellout_Key (Parent, Kind, Value_Text));
      else
         Found := False;
         return "";
      end if;
   end Spellout_Value_Text;

   function Spellout_Decimal_Separator
     (Locale : String;
      Found  : out Boolean)
      return String
   is
      Key    : constant String :=
        Spellout_Key (Locale, "decimal_separator", "");
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Spellout_Overrides.Contains (Key) then
         Found := True;
         return Spellout_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Spellout_Overrides.Contains
          (Spellout_Key (Parent, "decimal_separator", ""))
      then
         Found := True;
         return
           Spellout_Overrides.Element
             (Spellout_Key (Parent, "decimal_separator", ""));
      else
         Found := False;
         return "";
      end if;
   end Spellout_Decimal_Separator;

   function Spellout_Rule_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Base   : out Natural;
      Divisor : out Natural;
      Found  : out Boolean)
      return String
   is
      function Search
        (Search_Locale   : String;
         Search_Base     : out Natural;
         Search_Divisor  : out Natural)
         return String
      is
         Best_Base    : Natural := 0;
         Best_Divisor : Natural := 0;
         Best_Text    : Unbounded_String;
         Prefix       : constant String :=
           Search_Locale & Character'Val (0) & Kind & Character'Val (0);
      begin
         for Cursor in Spellout_Rule_Overrides.Iterate loop
            declare
               Key : constant String := String_Maps.Key (Cursor);
            begin
               if Key'Length > Prefix'Length
                 and then Key (Key'First .. Key'First + Prefix'Length - 1)
                          = Prefix
               then
                  declare
                     Base_Text : constant String :=
                       Key (Key'First + Prefix'Length .. Key'Last);
                     Candidate_Base    : Natural := 0;
                     Candidate_Divisor : Natural := 0;
                  begin
                     if RBNF_Rule_Descriptor_Values
                          (Base_Text, Candidate_Base, Candidate_Divisor)
                       and then Candidate_Base <= Value
                       and then Candidate_Base > Best_Base
                     then
                        Best_Base := Candidate_Base;
                        Best_Divisor := Candidate_Divisor;
                        Best_Text :=
                          To_Unbounded_String (String_Maps.Element (Cursor));
                     end if;
                  end;
               end if;
            end;
         end loop;

         Search_Base := Best_Base;
         Search_Divisor := Best_Divisor;
         return To_String (Best_Text);
      end Search;

      Parent : constant String := Parent_Locale (Locale);
      Text   : Unbounded_String :=
        To_Unbounded_String (Search (Locale, Base, Divisor));
   begin
      if To_String (Text) /= "" then
         Found := True;
         return To_String (Text);
      elsif Parent'Length > 0 then
         Text := To_Unbounded_String (Search (Parent, Base, Divisor));
         if To_String (Text) /= "" then
            Found := True;
            return To_String (Text);
         end if;
      end if;

      Base := 0;
      Divisor := 0;
      Found := False;
      return "";
   end Spellout_Rule_Text;

   function Spellout_Special_Rule_Text
     (Locale : String;
      Kind   : String;
      Name   : String;
      Found  : out Boolean)
      return String
   is
      Key    : constant String := Spellout_Key (Locale, Kind, Name);
      Parent : constant String := Parent_Locale (Locale);
   begin
      if Spellout_Rule_Overrides.Contains (Key) then
         Found := True;
         return Spellout_Rule_Overrides.Element (Key);
      elsif Parent'Length > 0
        and then Spellout_Rule_Overrides.Contains
          (Spellout_Key (Parent, Kind, Name))
      then
         Found := True;
         return
           Spellout_Rule_Overrides.Element
             (Spellout_Key (Parent, Kind, Name));
      else
         Found := False;
         return "";
      end if;
   end Spellout_Special_Rule_Text;

end I18N.Runtime_Data;
