with I18N.CLDR_Data;
with I18N.Locale_Data;

package body I18N.Unit_Format is

   --  The shards are keyed by the three canonical source widths; fold the
   --  aliases the callers use onto them.
   function Canonical_Width (Width : String) return String is
     (if Width = "unit-width-short" or else Width = "short"
      then "unit-width-short"
      elsif Width = "unit-width-narrow" or else Width = "narrow"
      then "unit-width-narrow"
      else "unit-width-full-name");

   function Display_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Shard_Lookup
          ("units", "unit", Locale,
           Base & ":" & Canonical_Width (Width) & ":" & Category, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Display_Name
                (Locale, Base, Canonical_Width (Width), Category));
   end Display_Name;

   function Per_Unit_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("per_unit_separator", Locale,
         I18N.CLDR_Data.Per_Unit_Separator'Access));

   function Value_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("unit_value_separator", Locale,
         I18N.CLDR_Data.Unit_Value_Separator'Access));

   function Short_Per_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("unit_short_per_separator", Locale,
         I18N.CLDR_Data.Unit_Short_Per_Separator'Access));

   --  The built-in English fallback name for a measurement unit: the
   --  compiled English CLDR name when present, otherwise a hardcoded
   --  table of the custom and aliased units CLDR does not carry.
   function English_Name
     (Base     : String;
      Width    : String;
      Singular : Boolean)
      return String
   is
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
        Display_Name
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
   end English_Name;

   --  Canonicalize an ICU unit id -- with or without its CLDR category
   --  prefix (length-, volume-, ...) and in British or American spelling --
   --  to the bare base name Display_Name and English_Name key on. Returns ""
   --  for an unrecognized unit, so it doubles as the canonical
   --  is-this-a-known-unit gate the message parser validates against.
   function Canonical_Base (Unit_Id : String) return String is
   begin
      if Unit_Id = "length-meter"
        or else Unit_Id = "length-metre"
        or else Unit_Id = "meter"
        or else Unit_Id = "metre"
      then
         return "meter";
      elsif Unit_Id = "length-kilometer"
        or else Unit_Id = "length-kilometre"
        or else Unit_Id = "kilometer"
        or else Unit_Id = "kilometre"
      then
         return "kilometer";
      elsif Unit_Id = "length-mile" or else Unit_Id = "mile" then
         return "mile";
      elsif Unit_Id = "length-yard" or else Unit_Id = "yard" then
         return "yard";
      elsif Unit_Id = "length-foot" or else Unit_Id = "foot" then
         return "foot";
      elsif Unit_Id = "length-inch" or else Unit_Id = "inch" then
         return "inch";
      elsif Unit_Id = "length-centimeter" or else Unit_Id = "centimeter" then
         return "centimeter";
      elsif Unit_Id = "length-centimetre" or else Unit_Id = "centimetre" then
         return "centimeter";
      elsif Unit_Id = "length-millimeter" or else Unit_Id = "millimeter" then
         return "millimeter";
      elsif Unit_Id = "length-millimetre" or else Unit_Id = "millimetre" then
         return "millimeter";
      elsif Unit_Id = "length-decimeter" or else Unit_Id = "decimeter" then
         return "decimeter";
      elsif Unit_Id = "length-decimetre" or else Unit_Id = "decimetre" then
         return "decimeter";
      elsif Unit_Id = "length-micrometer" or else Unit_Id = "micrometer" then
         return "micrometer";
      elsif Unit_Id = "length-micrometre" or else Unit_Id = "micrometre" then
         return "micrometer";
      elsif Unit_Id = "length-nanometer" or else Unit_Id = "nanometer" then
         return "nanometer";
      elsif Unit_Id = "length-nanometre" or else Unit_Id = "nanometre" then
         return "nanometer";
      elsif Unit_Id = "length-picometer" or else Unit_Id = "picometer" then
         return "picometer";
      elsif Unit_Id = "length-picometre" or else Unit_Id = "picometre" then
         return "picometer";
      elsif Unit_Id = "length-nautical-mile"
        or else Unit_Id = "nautical-mile"
      then
         return "nautical-mile";
      elsif Unit_Id = "length-astronomical-unit"
        or else Unit_Id = "astronomical-unit"
      then
         return "astronomical-unit";
      elsif Unit_Id = "length-light-year" or else Unit_Id = "light-year" then
         return "light-year";
      elsif Unit_Id = "length-parsec" or else Unit_Id = "parsec" then
         return "parsec";
      elsif Unit_Id = "length-fathom" or else Unit_Id = "fathom" then
         return "fathom";
      elsif Unit_Id = "length-furlong" or else Unit_Id = "furlong" then
         return "furlong";
      elsif Unit_Id = "length-pixel" or else Unit_Id = "pixel" then
         return "pixel";
      elsif Unit_Id = "length-point" or else Unit_Id = "point" then
         return "point";
      elsif Unit_Id = "length-solar-radius"
        or else Unit_Id = "solar-radius"
      then
         return "solar-radius";
      elsif Unit_Id = "length-earth-radius"
        or else Unit_Id = "earth-radius"
      then
         return "earth-radius";
      elsif Unit_Id = "graphics-dot" or else Unit_Id = "dot" then
         return "dot";
      elsif Unit_Id = "graphics-megapixel"
        or else Unit_Id = "megapixel"
      then
         return "megapixel";
      elsif Unit_Id = "graphics-pixel-per-centimeter"
        or else Unit_Id = "graphics-pixel-per-centimetre"
        or else Unit_Id = "pixel-per-centimeter"
        or else Unit_Id = "pixel-per-centimetre"
      then
         return "pixel-per-centimeter";
      elsif Unit_Id = "graphics-pixel-per-inch"
        or else Unit_Id = "pixel-per-inch"
      then
         return "pixel-per-inch";
      elsif Unit_Id = "graphics-dot-per-centimeter"
        or else Unit_Id = "graphics-dot-per-centimetre"
        or else Unit_Id = "dot-per-centimeter"
        or else Unit_Id = "dot-per-centimetre"
      then
         return "dot-per-centimeter";
      elsif Unit_Id = "graphics-dot-per-inch"
        or else Unit_Id = "dot-per-inch"
      then
         return "dot-per-inch";
      elsif Unit_Id = "volume-liter"
        or else Unit_Id = "volume-litre"
        or else Unit_Id = "liter"
        or else Unit_Id = "litre"
      then
         return "liter";
      elsif Unit_Id = "volume-milliliter"
        or else Unit_Id = "volume-millilitre"
        or else Unit_Id = "milliliter"
        or else Unit_Id = "millilitre"
      then
         return "milliliter";
      elsif Unit_Id = "volume-gallon" or else Unit_Id = "gallon" then
         return "gallon";
      elsif Unit_Id = "volume-fluid-ounce"
        or else Unit_Id = "fluid-ounce"
      then
         return "fluid-ounce";
      elsif Unit_Id = "volume-cup" or else Unit_Id = "cup" then
         return "cup";
      elsif Unit_Id = "volume-tablespoon"
        or else Unit_Id = "tablespoon"
      then
         return "tablespoon";
      elsif Unit_Id = "volume-teaspoon"
        or else Unit_Id = "teaspoon"
      then
         return "teaspoon";
      elsif Unit_Id = "volume-pint" or else Unit_Id = "pint" then
         return "pint";
      elsif Unit_Id = "volume-quart" or else Unit_Id = "quart" then
         return "quart";
      elsif Unit_Id = "volume-barrel" or else Unit_Id = "barrel" then
         return "barrel";
      elsif Unit_Id = "volume-cubic-meter"
        or else Unit_Id = "volume-cubic-metre"
        or else Unit_Id = "cubic-meter"
        or else Unit_Id = "cubic-metre"
      then
         return "cubic-meter";
      elsif Unit_Id = "volume-cubic-centimeter"
        or else Unit_Id = "volume-cubic-centimetre"
        or else Unit_Id = "cubic-centimeter"
        or else Unit_Id = "cubic-centimetre"
      then
         return "cubic-centimeter";
      elsif Unit_Id = "volume-cubic-inch"
        or else Unit_Id = "cubic-inch"
      then
         return "cubic-inch";
      elsif Unit_Id = "volume-cubic-foot"
        or else Unit_Id = "cubic-foot"
      then
         return "cubic-foot";
      elsif Unit_Id = "volume-cubic-yard"
        or else Unit_Id = "cubic-yard"
      then
         return "cubic-yard";
      elsif Unit_Id = "volume-acre-foot"
        or else Unit_Id = "acre-foot"
      then
         return "acre-foot";
      elsif Unit_Id = "mass-gram" or else Unit_Id = "gram" then
         return "gram";
      elsif Unit_Id = "mass-kilogram" or else Unit_Id = "kilogram" then
         return "kilogram";
      elsif Unit_Id = "mass-milligram" or else Unit_Id = "milligram" then
         return "milligram";
      elsif Unit_Id = "mass-tonne" or else Unit_Id = "tonne" then
         return "tonne";
      elsif Unit_Id = "mass-pound" or else Unit_Id = "pound" then
         return "pound";
      elsif Unit_Id = "mass-ounce" or else Unit_Id = "ounce" then
         return "ounce";
      elsif Unit_Id = "mass-stone" or else Unit_Id = "stone" then
         return "stone";
      elsif Unit_Id = "mass-carat" or else Unit_Id = "carat" then
         return "carat";
      elsif Unit_Id = "mass-ton" or else Unit_Id = "ton" then
         return "ton";
      elsif Unit_Id = "mass-dalton" or else Unit_Id = "dalton" then
         return "dalton";
      elsif Unit_Id = "mass-earth-mass" or else Unit_Id = "earth-mass" then
         return "earth-mass";
      elsif Unit_Id = "mass-solar-mass" or else Unit_Id = "solar-mass" then
         return "solar-mass";
      elsif Unit_Id = "duration-nanosecond"
        or else Unit_Id = "nanosecond"
      then
         return "nanosecond";
      elsif Unit_Id = "duration-microsecond"
        or else Unit_Id = "microsecond"
      then
         return "microsecond";
      elsif Unit_Id = "duration-millisecond" or else Unit_Id = "millisecond" then
         return "millisecond";
      elsif Unit_Id = "duration-second" or else Unit_Id = "second" then
         return "second";
      elsif Unit_Id = "duration-minute" or else Unit_Id = "minute" then
         return "minute";
      elsif Unit_Id = "duration-hour" or else Unit_Id = "hour" then
         return "hour";
      elsif Unit_Id = "duration-day" or else Unit_Id = "day" then
         return "day";
      elsif Unit_Id = "duration-week" or else Unit_Id = "week" then
         return "week";
      elsif Unit_Id = "duration-month" or else Unit_Id = "month" then
         return "month";
      elsif Unit_Id = "duration-year" or else Unit_Id = "year" then
         return "year";
      elsif Unit_Id = "duration-quarter" or else Unit_Id = "quarter" then
         return "quarter";
      elsif Unit_Id = "duration-decade" or else Unit_Id = "decade" then
         return "decade";
      elsif Unit_Id = "duration-century" or else Unit_Id = "century" then
         return "century";
      elsif Unit_Id = "duration-fortnight" or else Unit_Id = "fortnight" then
         return "fortnight";
      elsif Unit_Id = "area-square-meter"
        or else Unit_Id = "area-square-metre"
        or else Unit_Id = "square-meter"
        or else Unit_Id = "square-metre"
      then
         return "square-meter";
      elsif Unit_Id = "area-square-kilometer"
        or else Unit_Id = "area-square-kilometre"
        or else Unit_Id = "square-kilometer"
        or else Unit_Id = "square-kilometre"
      then
         return "square-kilometer";
      elsif Unit_Id = "area-acre" or else Unit_Id = "acre" then
         return "acre";
      elsif Unit_Id = "area-hectare" or else Unit_Id = "hectare" then
         return "hectare";
      elsif Unit_Id = "area-square-foot"
        or else Unit_Id = "square-foot"
      then
         return "square-foot";
      elsif Unit_Id = "area-square-mile"
        or else Unit_Id = "square-mile"
      then
         return "square-mile";
      elsif Unit_Id = "area-square-centimeter"
        or else Unit_Id = "area-square-centimetre"
        or else Unit_Id = "square-centimeter"
        or else Unit_Id = "square-centimetre"
      then
         return "square-centimeter";
      elsif Unit_Id = "area-square-inch"
        or else Unit_Id = "square-inch"
      then
         return "square-inch";
      elsif Unit_Id = "area-square-yard"
        or else Unit_Id = "square-yard"
      then
         return "square-yard";
      elsif Unit_Id = "temperature-celsius" or else Unit_Id = "celsius" then
         return "celsius";
      elsif Unit_Id = "temperature-fahrenheit" or else Unit_Id = "fahrenheit" then
         return "fahrenheit";
      elsif Unit_Id = "temperature-kelvin" or else Unit_Id = "kelvin" then
         return "kelvin";
      elsif Unit_Id = "angle-degree" or else Unit_Id = "degree" then
         return "degree";
      elsif Unit_Id = "angle-radian" or else Unit_Id = "radian" then
         return "radian";
      elsif Unit_Id = "angle-revolution" or else Unit_Id = "revolution" then
         return "revolution";
      elsif Unit_Id = "angle-arc-minute"
        or else Unit_Id = "arc-minute"
      then
         return "arc-minute";
      elsif Unit_Id = "angle-arc-second"
        or else Unit_Id = "arc-second"
      then
         return "arc-second";
      elsif Unit_Id = "acceleration-g-force"
        or else Unit_Id = "g-force"
      then
         return "g-force";
      elsif Unit_Id = "acceleration-meter-per-square-second"
        or else Unit_Id = "acceleration-metre-per-square-second"
        or else Unit_Id = "meter-per-square-second"
        or else Unit_Id = "metre-per-square-second"
      then
         return "meter-per-square-second";
      elsif Unit_Id = "force-newton"
        or else Unit_Id = "newton"
      then
         return "newton";
      elsif Unit_Id = "force-pound-force"
        or else Unit_Id = "pound-force"
      then
         return "pound-force";
      elsif Unit_Id = "torque-newton-meter"
        or else Unit_Id = "torque-newton-metre"
        or else Unit_Id = "newton-meter"
        or else Unit_Id = "newton-metre"
      then
         return "newton-meter";
      elsif Unit_Id = "digital-byte" or else Unit_Id = "byte" then
         return "byte";
      elsif Unit_Id = "digital-bit" or else Unit_Id = "bit" then
         return "bit";
      elsif Unit_Id = "digital-kilobyte" or else Unit_Id = "kilobyte" then
         return "kilobyte";
      elsif Unit_Id = "digital-kilobit" or else Unit_Id = "kilobit" then
         return "kilobit";
      elsif Unit_Id = "digital-megabyte" or else Unit_Id = "megabyte" then
         return "megabyte";
      elsif Unit_Id = "digital-gigabyte" or else Unit_Id = "gigabyte" then
         return "gigabyte";
      elsif Unit_Id = "digital-terabyte" or else Unit_Id = "terabyte" then
         return "terabyte";
      elsif Unit_Id = "digital-terabit" or else Unit_Id = "terabit" then
         return "terabit";
      elsif Unit_Id = "digital-megabit" or else Unit_Id = "megabit" then
         return "megabit";
      elsif Unit_Id = "digital-gigabit" or else Unit_Id = "gigabit" then
         return "gigabit";
      elsif Unit_Id = "digital-petabyte" or else Unit_Id = "petabyte" then
         return "petabyte";
      elsif Unit_Id = "digital-petabit" or else Unit_Id = "petabit" then
         return "petabit";
      elsif Unit_Id = "digital-exabyte" or else Unit_Id = "exabyte" then
         return "exabyte";
      elsif Unit_Id = "digital-exabit" or else Unit_Id = "exabit" then
         return "exabit";
      elsif Unit_Id = "speed-kilometer-per-hour"
        or else Unit_Id = "speed-kilometre-per-hour"
        or else Unit_Id = "kilometer-per-hour"
        or else Unit_Id = "kilometre-per-hour"
      then
         return "kilometer-per-hour";
      elsif Unit_Id = "speed-mile-per-hour"
        or else Unit_Id = "mile-per-hour"
      then
         return "mile-per-hour";
      elsif Unit_Id = "speed-knot" or else Unit_Id = "knot" then
         return "knot";
      elsif Unit_Id = "speed-beaufort" or else Unit_Id = "beaufort" then
         return "beaufort";
      elsif Unit_Id = "speed-meter-per-second"
        or else Unit_Id = "speed-metre-per-second"
        or else Unit_Id = "meter-per-second"
        or else Unit_Id = "metre-per-second"
      then
         return "meter-per-second";
      elsif Unit_Id = "consumption-liter-per-100-kilometer"
        or else Unit_Id = "consumption-litre-per-100-kilometre"
        or else Unit_Id = "consumption-litre-per-100-kilometer"
        or else Unit_Id = "consumption-liter-per-100-kilometre"
        or else Unit_Id = "liter-per-100-kilometer"
        or else Unit_Id = "litre-per-100-kilometre"
        or else Unit_Id = "litre-per-100-kilometer"
        or else Unit_Id = "liter-per-100-kilometre"
      then
         return "liter-per-100-kilometer";
      elsif Unit_Id = "consumption-mile-per-gallon"
        or else Unit_Id = "mile-per-gallon"
      then
         return "mile-per-gallon";
      elsif Unit_Id = "consumption-mile-per-gallon-imperial"
        or else Unit_Id = "mile-per-gallon-imperial"
      then
         return "mile-per-gallon-imperial";
      elsif Unit_Id = "energy-joule" or else Unit_Id = "joule" then
         return "joule";
      elsif Unit_Id = "energy-kilojoule" or else Unit_Id = "kilojoule" then
         return "kilojoule";
      elsif Unit_Id = "energy-calorie" or else Unit_Id = "calorie" then
         return "calorie";
      elsif Unit_Id = "energy-kilocalorie" or else Unit_Id = "kilocalorie" then
         return "kilocalorie";
      elsif Unit_Id = "energy-kilowatt-hour"
        or else Unit_Id = "kilowatt-hour"
      then
         return "kilowatt-hour";
      elsif Unit_Id = "energy-electronvolt"
        or else Unit_Id = "electronvolt"
      then
         return "electronvolt";
      elsif Unit_Id = "energy-british-thermal-unit"
        or else Unit_Id = "british-thermal-unit"
      then
         return "british-thermal-unit";
      elsif Unit_Id = "energy-therm-us"
        or else Unit_Id = "therm-us"
      then
         return "therm-us";
      elsif Unit_Id = "power-watt" or else Unit_Id = "watt" then
         return "watt";
      elsif Unit_Id = "power-kilowatt" or else Unit_Id = "kilowatt" then
         return "kilowatt";
      elsif Unit_Id = "power-horsepower"
        or else Unit_Id = "horsepower"
      then
         return "horsepower";
      elsif Unit_Id = "frequency-hertz" or else Unit_Id = "hertz" then
         return "hertz";
      elsif Unit_Id = "frequency-kilohertz" or else Unit_Id = "kilohertz" then
         return "kilohertz";
      elsif Unit_Id = "frequency-megahertz" or else Unit_Id = "megahertz" then
         return "megahertz";
      elsif Unit_Id = "pressure-hectopascal"
        or else Unit_Id = "hectopascal"
      then
         return "hectopascal";
      elsif Unit_Id = "pressure-pascal" or else Unit_Id = "pascal" then
         return "pascal";
      elsif Unit_Id = "pressure-kilopascal" or else Unit_Id = "kilopascal" then
         return "kilopascal";
      elsif Unit_Id = "pressure-millibar" or else Unit_Id = "millibar" then
         return "millibar";
      elsif Unit_Id = "pressure-bar" or else Unit_Id = "bar" then
         return "bar";
      elsif Unit_Id = "pressure-atmosphere" or else Unit_Id = "atmosphere" then
         return "atmosphere";
      elsif Unit_Id = "pressure-inch-ofhg" or else Unit_Id = "inch-ofhg" then
         return "inch-ofhg";
      elsif Unit_Id = "pressure-millimeter-ofhg"
        or else Unit_Id = "millimeter-ofhg"
      then
         return "millimeter-ofhg";
      elsif Unit_Id = "pressure-pound-force-per-square-inch"
        or else Unit_Id = "pound-force-per-square-inch"
      then
         return "pound-force-per-square-inch";
      elsif Unit_Id = "electric-ampere" or else Unit_Id = "ampere" then
         return "ampere";
      elsif Unit_Id = "electric-milliampere"
        or else Unit_Id = "milliampere"
      then
         return "milliampere";
      elsif Unit_Id = "electric-volt" or else Unit_Id = "volt" then
         return "volt";
      elsif Unit_Id = "electric-millivolt"
        or else Unit_Id = "millivolt"
      then
         return "millivolt";
      elsif Unit_Id = "electric-ohm" or else Unit_Id = "ohm" then
         return "ohm";
      elsif Unit_Id = "light-lumen" or else Unit_Id = "lumen" then
         return "lumen";
      elsif Unit_Id = "light-lux" or else Unit_Id = "lux" then
         return "lux";
      elsif Unit_Id = "light-candela" or else Unit_Id = "candela" then
         return "candela";
      elsif Unit_Id = "light-solar-luminosity"
        or else Unit_Id = "solar-luminosity"
      then
         return "solar-luminosity";
      elsif Unit_Id = "concentr-percent" or else Unit_Id = "percent" then
         return "percent";
      elsif Unit_Id = "concentr-permille" or else Unit_Id = "permille" then
         return "permille";
      elsif Unit_Id = "concentr-permillion"
        or else Unit_Id = "permillion"
      then
         return "permillion";
      elsif Unit_Id = "concentr-portion" or else Unit_Id = "portion" then
         return "portion";
      elsif Unit_Id = "concentr-karat" or else Unit_Id = "karat" then
         return "karat";
      else
         return "";
      end if;
   end Canonical_Base;

end I18N.Unit_Format;
