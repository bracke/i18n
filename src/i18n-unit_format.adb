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

end I18N.Unit_Format;
