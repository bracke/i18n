separate (I18N.Runtime.Tests.Features)
procedure Test_Ecosystem_Formatters
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Result  : I18N.Runtime.Load_Result;
   Target  : String (1 .. 128);
   Last    : Natural;
   Status  : I18N.Result.Render_Status;

   procedure Assert_Localized_Relative
     (Locale  : String;
      Message : String)
   is
      English : constant String := Rendered (Runtime, "en", "relative", Args);
      Local   : constant String := Rendered (Runtime, Locale, "relative", Args);
   begin
      Assert (Local'Length > 0, Message & " renders non-empty output");
      Assert (Local (Local'First) /= '<',
              Message & " does not report a render failure");
      Assert (Local /= English,
              Message & " uses localized CLDR data instead of English");
   end Assert_Localized_Relative;

   Bad_Measure_Unit : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_measure_unit",
        "en.distance = ""{distance, number, ::measure-unit/length-warp}"""
        & ASCII.LF);
   Bad_Measure_Width : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_measure_width",
        "en.distance = ""{distance, number, "
        & "::measure-unit/length-meter unit-width-medium}"""
        & ASCII.LF);
   Bad_Measure_Per_Unit : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_measure_per_unit",
        "en.distance = ""{distance, number, "
        & "::measure-unit/length-kilometer "
        & "per-measure-unit/duration-blink}"""
        & ASCII.LF);
   Bad_Measure_Duplicate_Per
     : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_measure_duplicate_per",
        "en.distance = ""{distance, number, "
        & "::measure-unit/length-kilometer per-measure-unit/duration-hour "
        & "per-measure-unit/duration-second}"""
        & ASCII.LF);
   Bad_Duration_Option : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_duration_option",
        "en.duration = ""{seconds, duration, short}""" & ASCII.LF);
   Bad_Bytes_Option : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_bytes_option",
        "en.bytes = ""{size, bytes, short}""" & ASCII.LF);
   Bad_List_Option : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_list_option",
        "en.list = ""{items, list, xor}""" & ASCII.LF);
   Bad_Unit_Missing : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_unit_missing",
        "en.unit = ""{distance, unit}""" & ASCII.LF);
   Bad_Relative_Missing
     : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_relative_missing",
        "en.relative = ""{offset, relative}""" & ASCII.LF);
   Bad_Relative_Unit : constant I18N.Runtime.Catalog_Validation_Result :=
     I18N.Runtime.Validate_Catalog_Text
       ("bad_relative_unit",
        "en.relative = ""{offset, relative, fortnight}""" & ASCII.LF);

   procedure Expect_Bounded
     (Locale  : String;
      Key     : String;
      Output  : String;
      Message : String)
   is
   begin
      I18N.Runtime.Render_Into
        (Runtime, Locale, Key, Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              Message & " succeeds through Render_Into");
      Assert (Target (1 .. Last) = Output,
              Message & " matches materialized output");
   end Expect_Bounded;
begin
   Assert (not Bad_Measure_Unit.Valid,
           "unsupported measure-unit skeleton units are rejected");
   Assert (not Bad_Measure_Width.Valid,
           "unsupported measure-unit width tokens are rejected");
   Assert (not Bad_Measure_Per_Unit.Valid,
           "unsupported per-measure-unit skeleton units are rejected");
   Assert (not Bad_Measure_Duplicate_Per.Valid,
           "duplicate per-measure-unit skeleton tokens are rejected");
   Assert (not Bad_Duration_Option.Valid,
           "duration formatter rejects unsupported options");
   Assert (not Bad_Bytes_Option.Valid,
           "byte-size formatter rejects unsupported options");
   Assert (not Bad_List_Option.Valid,
           "list formatter rejects unsupported options");
   Assert (not Bad_Unit_Missing.Valid,
           "unit formatter requires an explicit unit");
   Assert (not Bad_Relative_Missing.Valid,
           "relative-time formatter requires an explicit unit");
   Assert (not Bad_Relative_Unit.Valid,
           "relative-time formatter rejects unsupported units");

   I18N.Runtime.Load_Text
     (Runtime, "ecosystem",
      "en.duration = ""{seconds, duration}""" & ASCII.LF
      & "ar.duration = ""{seconds, duration}""" & ASCII.LF
      & "en-u-nu-beng.duration = ""{seconds, duration}""" & ASCII.LF
      & "ar-u-nu-latn.duration = ""{seconds, duration}""" & ASCII.LF
      & "en.bytes = ""{size, bytes}""" & ASCII.LF
      & "ar.bytes = ""{size, bytes}""" & ASCII.LF
      & "en-u-nu-beng.bytes = ""{size, bytes}""" & ASCII.LF
      & "en.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "en.unit_long_width = ""{distance, unit, kilometer/unit-width-long}"""
      & ASCII.LF
      & "en.unit_long_width_slash = ""{distance, unit, kilometer/unit-width/long}"""
      & ASCII.LF
      & "de.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "fr.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "es.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "it.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "pt.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "nl.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "ro.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "lt.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "sl.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "pl.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "cs.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "ru.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "ar.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "ja.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "zh.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "ko.unit = ""{distance, unit, kilometer}""" & ASCII.LF
      & "en.unit_decimal = ""{distance, unit, kilometer}"""
      & ASCII.LF
      & "ar.unit_decimal = ""{distance, unit, kilometer}"""
      & ASCII.LF
      & "en-u-nu-beng.unit_decimal = ""{distance, unit, kilometer}"""
      & ASCII.LF
      & "ar-u-nu-latn.unit_decimal = ""{distance, unit, kilometer}"""
      & ASCII.LF
      & "en.unit_mile_alias = ""{distance, unit, length-mile}"""
      & ASCII.LF
      & "en.unit_metre_alias = ""{distance, unit, length-metre}"""
      & ASCII.LF
      & "en.unit_kilometre_alias = ""{distance, unit, length-kilometre}"""
      & ASCII.LF
      & "en.unit_yard_alias = ""{distance, unit, length-yard}"""
      & ASCII.LF
      & "en.unit_foot_alias = ""{distance, unit, length-foot}"""
      & ASCII.LF
      & "en.unit_inch_alias = ""{distance, unit, length-inch}"""
      & ASCII.LF
      & "de.unit_centimetre_alias = ""{distance, unit, length-centimetre}"""
      & ASCII.LF
      & "en.unit_litre_alias = ""{volume, unit, volume-litre}"""
      & ASCII.LF
      & "en.unit_pound_alias = ""{weight, unit, mass-pound}"""
      & ASCII.LF
      & "en.unit_tonne_alias = ""{weight, unit, mass-tonne}"""
      & ASCII.LF
      & "en.unit_nanosecond_alias = ""{elapsed, unit, duration-nanosecond}"""
      & ASCII.LF
      & "en.unit_microsecond_alias = ""{elapsed, unit, duration-microsecond}"""
      & ASCII.LF
      & "en.unit_millisecond_alias = ""{elapsed, unit, duration-millisecond}"""
      & ASCII.LF
      & "en.unit_fortnight = ""{elapsed, unit, duration-fortnight}"""
      & ASCII.LF
      & "en.unit_square_meter_alias = ""{area, unit, area-square-meter}"""
      & ASCII.LF
      & "en.unit_celsius_alias = ""{temperature, unit, temperature-celsius}"""
      & ASCII.LF
      & "en.unit_degree_alias = ""{angle, unit, angle-degree}"""
      & ASCII.LF
      & "en.unit_radian_alias = ""{angle, unit, angle-radian}"""
      & ASCII.LF
      & "en.unit_revolution_short = ""{angle, unit, angle-revolution/unit-width-short}"""
      & ASCII.LF
      & "en.unit_arc_minute = ""{angle, unit, angle-arc-minute}"""
      & ASCII.LF
      & "en.unit_arc_second_short = ""{angle, unit, angle-arc-second/unit-width-short}"""
      & ASCII.LF
      & "en.unit_g_force = ""{acceleration, unit, acceleration-g-force}"""
      & ASCII.LF
      & "en.unit_acceleration_short = ""{acceleration, unit, "
      & "acceleration-metre-per-square-second/unit-width-short}"""
      & ASCII.LF
      & "en.unit_newton = ""{force, unit, force-newton}"""
      & ASCII.LF
      & "en.unit_pound_force_short = ""{force, unit, "
      & "force-pound-force/unit-width-short}"""
      & ASCII.LF
      & "en.unit_torque = ""{torque, unit, torque-newton-metre}"""
      & ASCII.LF
      & "en.unit_quarter = ""{elapsed, unit, duration-quarter}"""
      & ASCII.LF
      & "en.unit_decade = ""{elapsed, unit, duration-decade}"""
      & ASCII.LF
      & "en.unit_century = ""{elapsed, unit, duration-century}"""
      & ASCII.LF
      & "en.unit_byte_alias = ""{size, unit, digital-byte}"""
      & ASCII.LF
      & "en.unit_megabyte_short = ""{size, unit, digital-megabyte/unit-width-short}"""
      & ASCII.LF
      & "en.unit_kilometre_per_hour = ""{speed, unit, speed-kilometre-per-hour}"""
      & ASCII.LF
      & "en.unit_metre_per_second_short = ""{speed, unit, "
      & "speed-metre-per-second/unit-width-short}"""
      & ASCII.LF
      & "en.unit_metre_per_second_short_slash = ""{speed, unit, "
      & "speed-metre-per-second/unit-width/short}"""
      & ASCII.LF
      & "en.unit_l_per_100km_short = ""{consumption, unit, "
      & "consumption-litre-per-100-kilometre/unit-width-short}"""
      & ASCII.LF
      & "en.unit_mpg = ""{consumption, unit, consumption-mile-per-gallon}"""
      & ASCII.LF
      & "en.unit_mpg_imperial = ""{consumption, unit, "
      & "consumption-mile-per-gallon-imperial}"""
      & ASCII.LF
      & "en.unit_electronvolt_short = ""{energy, unit, "
      & "energy-electronvolt/unit-width-short}"""
      & ASCII.LF
      & "en.unit_btu = ""{energy, unit, energy-british-thermal-unit}"""
      & ASCII.LF
      & "en.unit_therm_us = ""{energy, unit, energy-therm-us}"""
      & ASCII.LF
      & "en.unit_permille_short = ""{share, unit, "
      & "concentr-permille/unit-width-short}"""
      & ASCII.LF
      & "en.unit_permillion = ""{share, unit, concentr-permillion}"""
      & ASCII.LF
      & "en.unit_karat_short = ""{share, unit, "
      & "concentr-karat/unit-width-short}"""
      & ASCII.LF
      & "en.unit_dot = ""{graphics, unit, graphics-dot}"""
      & ASCII.LF
      & "en.unit_megapixel_short = ""{graphics, unit, "
      & "graphics-megapixel/unit-width-short}"""
      & ASCII.LF
      & "en.unit_pixel_per_inch_short = ""{graphics, unit, "
      & "graphics-pixel-per-inch/unit-width-short}"""
      & ASCII.LF
      & "en.unit_dot_per_cm = ""{graphics, unit, "
      & "graphics-dot-per-centimetre}"""
      & ASCII.LF
      & "en.unit_earth_radius_short = ""{distance, unit, "
      & "length-earth-radius/unit-width-short}"""
      & ASCII.LF
      & "en.unit_decimetre_short = ""{distance, unit, "
      & "length-decimetre/unit-width-short}"""
      & ASCII.LF
      & "en.unit_micrometer = ""{distance, unit, length-micrometer}"""
      & ASCII.LF
      & "en.unit_nanometre_short = ""{distance, unit, "
      & "length-nanometre/unit-width-short}"""
      & ASCII.LF
      & "en.unit_picometer = ""{distance, unit, length-picometer}"""
      & ASCII.LF
      & "en.unit_barrel = ""{volume, unit, volume-barrel}"""
      & ASCII.LF
      & "en.unit_ton = ""{weight, unit, mass-ton}"""
      & ASCII.LF
      & "en.unit_dalton_short = ""{weight, unit, "
      & "mass-dalton/unit-width-short}"""
      & ASCII.LF
      & "en.unit_kelvin_short = ""{temperature, unit, "
      & "temperature-kelvin/unit-width-short}"""
      & ASCII.LF
      & "en.unit_horsepower_short = ""{power, unit, "
      & "power-horsepower/unit-width-short}"""
      & ASCII.LF
      & "en.unit_kilobit_short = ""{size, unit, "
      & "digital-kilobit/unit-width-short}"""
      & ASCII.LF
      & "en.unit_terabit = ""{size, unit, digital-terabit}"""
      & ASCII.LF
      & "en.unit_petabit_short = ""{size, unit, "
      & "digital-petabit/unit-width-short}"""
      & ASCII.LF
      & "en.unit_exabyte = ""{size, unit, digital-exabyte}"""
      & ASCII.LF
      & "en.unit_exabit_short = ""{size, unit, "
      & "digital-exabit/unit-width-short}"""
      & ASCII.LF
      & "en.unit_knot_short = ""{speed, unit, "
      & "speed-knot/unit-width-short}"""
      & ASCII.LF
      & "en.unit_beaufort = ""{speed, unit, speed-beaufort}"""
      & ASCII.LF
      & "en.unit_psi_short = ""{pressure, unit, "
      & "pressure-pound-force-per-square-inch/unit-width-short}"""
      & ASCII.LF
      & "en.unit_milliampere_short = ""{electric, unit, "
      & "electric-milliampere/unit-width-short}"""
      & ASCII.LF
      & "en.unit_millivolt = ""{electric, unit, electric-millivolt}"""
      & ASCII.LF
      & "en.unit_candela_short = ""{light, unit, "
      & "light-candela/unit-width-short}"""
      & ASCII.LF
      & "en.unit_solar_luminosity = ""{light, unit, "
      & "light-solar-luminosity}"""
      & ASCII.LF
      & "en.measure_unit = ""{distance, number, ::measure-unit/length-kilometer}"""
      & ASCII.LF
      & "en.measure_kilometre = ""{distance, number, ::measure-unit/length-kilometre}"""
      & ASCII.LF
      & "en.measure_metre = ""{distance, number, ::measure-unit/length-metre}"""
      & ASCII.LF
      & "en.measure_full_name_slash = ""{distance, number, "
      & "::measure-unit/length-kilometer unit-width/full-name}"""
      & ASCII.LF
      & "en.measure_acceleration = ""{acceleration, number, "
      & "::measure-unit/acceleration-meter-per-square-second}"""
      & ASCII.LF
      & "en.measure_radian_short = ""{angle, number, ::measure-unit/angle-radian unit-width-short}"""
      & ASCII.LF
      & "en.measure_force_short = ""{force, number, "
      & "::measure-unit/force-newton unit-width-short}"""
      & ASCII.LF
      & "en.measure_torque = ""{torque, number, "
      & "::measure-unit/torque-newton-meter}"""
      & ASCII.LF
      & "en.measure_consumption = ""{consumption, number, "
      & "::measure-unit/consumption-liter-per-100-kilometer}"""
      & ASCII.LF
      & "en.measure_mpg_short = ""{consumption, number, "
      & "::measure-unit/consumption-mile-per-gallon unit-width-short}"""
      & ASCII.LF
      & "en.measure_per_century = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-century}"""
      & ASCII.LF
      & "en.measure_per_fortnight = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-fortnight}"""
      & ASCII.LF
      & "en.measure_short = ""{distance, number, ::measure-unit/length-kilometer unit-width-short}"""
      & ASCII.LF
      & "en.measure_short_slash = ""{distance, number, ::measure-unit/length-kilometer unit-width/short}"""
      & ASCII.LF
      & "en.measure_long_slash = ""{distance, number, ::measure-unit/length-kilometer unit-width/long}"""
      & ASCII.LF
      & "en.measure_mile = ""{distance, number, ::measure-unit/length-mile}"""
      & ASCII.LF
      & "en.measure_yard = ""{distance, number, ::measure-unit/length-yard}"""
      & ASCII.LF
      & "en.measure_foot_short = ""{distance, number, ::measure-unit/length-foot unit-width-short}"""
      & ASCII.LF
      & "en.measure_inch = ""{distance, number, ::measure-unit/length-inch}"""
      & ASCII.LF
      & "de.measure_mile = ""{distance, number, ::measure-unit/length-mile}"""
      & ASCII.LF
      & "it.measure_mile = ""{distance, number, ::measure-unit/length-mile}"""
      & ASCII.LF
      & "en.measure_mile_short = ""{distance, number, ::measure-unit/length-mile unit-width-short}"""
      & ASCII.LF
      & "en.measure_centimeter = ""{distance, number, ::measure-unit/length-centimeter}"""
      & ASCII.LF
      & "de.measure_centimetre = ""{distance, number, ::measure-unit/length-centimetre}"""
      & ASCII.LF
      & "ro.measure_meter = ""{distance, number, ::measure-unit/length-meter}"""
      & ASCII.LF
      & "en.measure_millimeter_short = ""{distance, number, ::measure-unit/length-millimeter unit-width-short}"""
      & ASCII.LF
      & "en.measure_decimeter = ""{distance, number, "
      & "::measure-unit/length-decimeter}"""
      & ASCII.LF
      & "en.measure_micrometre_short = ""{distance, number, "
      & "::measure-unit/length-micrometre unit-width-short}"""
      & ASCII.LF
      & "en.measure_nanometer = ""{distance, number, "
      & "::measure-unit/length-nanometer}"""
      & ASCII.LF
      & "en.measure_picometre_short = ""{distance, number, "
      & "::measure-unit/length-picometre unit-width-short}"""
      & ASCII.LF
      & "en.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "de.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "fr.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "es.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "it.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "pt.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "nl.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "ro.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "lt.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "sl.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "pl.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "cs.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "ru.measure_nautical_mile = ""{distance, number, ::measure-unit/length-nautical-mile}"""
      & ASCII.LF
      & "de.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "fr.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "es.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "it.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "pt.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "nl.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "ro.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "lt.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "sl.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "pl.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "cs.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "ru.measure_astronomical_unit = ""{distance, number, ::measure-unit/length-astronomical-unit}"""
      & ASCII.LF
      & "de.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "fr.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "es.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "it.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "pt.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "nl.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "ro.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "lt.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "sl.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "pl.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "cs.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "ru.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "en.measure_astronomical_unit_short = ""{distance, number, "
      & "::measure-unit/length-astronomical-unit unit-width-short}"""
      & ASCII.LF
      & "en.measure_light_year = ""{distance, number, ::measure-unit/length-light-year}"""
      & ASCII.LF
      & "de.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "fr.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "es.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "it.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "pt.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "nl.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "ro.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "lt.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "sl.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "pl.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "cs.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "ru.measure_parsec = ""{distance, number, ::measure-unit/length-parsec}"""
      & ASCII.LF
      & "en.measure_parsec_short = ""{distance, number, ::measure-unit/length-parsec unit-width-short}"""
      & ASCII.LF
      & "en.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "de.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "fr.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "es.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "it.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "pt.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "nl.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "ro.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "lt.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "sl.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "pl.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "cs.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "ru.unit_fathom_alias = ""{distance, unit, length-fathom}"""
      & ASCII.LF
      & "en.measure_furlong_short = ""{distance, number, ::measure-unit/length-furlong unit-width-short}"""
      & ASCII.LF
      & "en.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "de.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "fr.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "es.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "it.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "pt.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "nl.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "ro.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "lt.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "sl.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "pl.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "cs.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "ru.measure_pixel = ""{distance, number, ::measure-unit/length-pixel}"""
      & ASCII.LF
      & "en.measure_point_short = ""{distance, number, ::measure-unit/length-point unit-width-short}"""
      & ASCII.LF
      & "de.measure_point = ""{distance, number, ::measure-unit/length-point}"""
      & ASCII.LF
      & "en.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "de.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "fr.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "es.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "it.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "pt.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "nl.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "ro.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "lt.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "sl.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "pl.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "cs.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "ru.measure_solar_radius = ""{distance, number, ::measure-unit/length-solar-radius}"""
      & ASCII.LF
      & "en.measure_liter = ""{volume, number, ::measure-unit/volume-liter}"""
      & ASCII.LF
      & "fr.measure_liter = ""{volume, number, ::measure-unit/volume-liter}"""
      & ASCII.LF
      & "es.measure_liter = ""{volume, number, ::measure-unit/volume-liter}"""
      & ASCII.LF
      & "lt.measure_liter = ""{volume, number, ::measure-unit/volume-liter}"""
      & ASCII.LF
      & "en.measure_litre_short = ""{volume, number, ::measure-unit/volume-litre unit-width-short}"""
      & ASCII.LF
      & "en.measure_milliliter = ""{volume, number, ::measure-unit/volume-milliliter}"""
      & ASCII.LF
      & "fr.measure_millilitre = ""{volume, number, ::measure-unit/volume-millilitre}"""
      & ASCII.LF
      & "en.measure_gallon_short = ""{volume, number, ::measure-unit/volume-gallon unit-width-short}"""
      & ASCII.LF
      & "en.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "en.unit_tablespoon_alias = ""{volume, unit, volume-tablespoon}"""
      & ASCII.LF
      & "en.unit_teaspoon = ""{volume, unit, teaspoon}"""
      & ASCII.LF
      & "de.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "fr.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "es.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "it.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "pt.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "nl.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "ro.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "lt.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "sl.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "pl.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "cs.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "ru.unit_cup_alias = ""{volume, unit, volume-cup}"""
      & ASCII.LF
      & "en.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "en.measure_tablespoon_short = ""{volume, number, ::measure-unit/volume-tablespoon unit-width-short}"""
      & ASCII.LF
      & "en.measure_teaspoon = ""{volume, number, ::measure-unit/volume-teaspoon}"""
      & ASCII.LF
      & "de.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "fr.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "es.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "it.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "pt.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "nl.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "ro.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "lt.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "sl.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "pl.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "cs.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "ru.measure_fluid_ounce = ""{volume, number, ::measure-unit/volume-fluid-ounce}"""
      & ASCII.LF
      & "en.measure_pint_short = ""{volume, number, ::measure-unit/volume-pint unit-width-short}"""
      & ASCII.LF
      & "en.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "de.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "fr.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "es.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "it.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "pt.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "nl.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "ro.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "lt.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "sl.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "pl.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "cs.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "ru.measure_quart = ""{volume, number, ::measure-unit/volume-quart}"""
      & ASCII.LF
      & "en.unit_cubic_meter_short = ""{volume, unit, "
      & "volume-cubic-metre/unit-width-short}"""
      & ASCII.LF
      & "en.unit_cubic_inch = ""{volume, unit, volume-cubic-inch}"""
      & ASCII.LF
      & "en.unit_acre_foot_short = ""{volume, unit, "
      & "volume-acre-foot/unit-width-short}"""
      & ASCII.LF
      & "en.measure_cubic_centimeter = ""{volume, number, "
      & "::measure-unit/volume-cubic-centimeter}"""
      & ASCII.LF
      & "en.measure_cubic_foot_short = ""{volume, number, "
      & "::measure-unit/volume-cubic-foot unit-width-short}"""
      & ASCII.LF
      & "en.measure_cubic_yard = ""{volume, number, "
      & "::measure-unit/volume-cubic-yard}"""
      & ASCII.LF
      & "en.measure_narrow = ""{weight, number, ::measure-unit/mass-kilogram unit-width-narrow}"""
      & ASCII.LF
      & "en.measure_narrow_slash = ""{weight, number, ::measure-unit/mass-kilogram unit-width/narrow}"""
      & ASCII.LF
      & "sl.measure_kilogram = ""{weight, number, ::measure-unit/mass-kilogram}"""
      & ASCII.LF
      & "en.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "de.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "fr.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "es.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "it.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "pt.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "nl.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "ro.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "lt.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "sl.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "pl.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "cs.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "ru.unit_milligram_alias = ""{weight, unit, mass-milligram}"""
      & ASCII.LF
      & "en.measure_milligram_short = ""{weight, number, ::measure-unit/mass-milligram unit-width-short}"""
      & ASCII.LF
      & "en.measure_pound = ""{weight, number, ::measure-unit/mass-pound}"""
      & ASCII.LF
      & "en.measure_tonne_short = ""{weight, number, ::measure-unit/mass-tonne unit-width-short}"""
      & ASCII.LF
      & "de.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "fr.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "es.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "it.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "pt.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "nl.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "ro.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "lt.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "sl.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "pl.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "cs.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "ru.measure_tonne = ""{weight, number, ::measure-unit/mass-tonne}"""
      & ASCII.LF
      & "es.measure_ounce = ""{weight, number, ::measure-unit/mass-ounce}"""
      & ASCII.LF
      & "en.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "de.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "fr.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "es.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "it.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "pt.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "nl.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "ro.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "lt.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "sl.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "pl.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "cs.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "ru.unit_stone_alias = ""{weight, unit, mass-stone}"""
      & ASCII.LF
      & "en.measure_carat_short = ""{weight, number, ::measure-unit/mass-carat unit-width-short}"""
      & ASCII.LF
      & "en.measure_millisecond = ""{elapsed, number, ::measure-unit/duration-millisecond}"""
      & ASCII.LF
      & "en.measure_microsecond = ""{elapsed, number, ::measure-unit/duration-microsecond}"""
      & ASCII.LF
      & "en.measure_nanosecond_short = ""{elapsed, number, ::measure-unit/duration-nanosecond unit-width-short}"""
      & ASCII.LF
      & "en.measure_fortnight_short = ""{elapsed, number, "
      & "::measure-unit/duration-fortnight unit-width-short}"""
      & ASCII.LF
      & "en.measure_square_meter_short = ""{area, number, ::measure-unit/area-square-meter unit-width-short}"""
      & ASCII.LF
      & "en.measure_square_kilometre = ""{area, number, ::measure-unit/area-square-kilometre}"""
      & ASCII.LF
      & "en.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "de.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "it.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "pt.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "nl.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "ro.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "lt.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "sl.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "pl.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "cs.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "ru.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "ar.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "ja.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "zh.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "ko.unit_acre_alias = ""{area, unit, area-acre}"""
      & ASCII.LF
      & "en.measure_acre_short = ""{area, number, ::measure-unit/area-acre unit-width-short}"""
      & ASCII.LF
      & "en.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "en.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "en.unit_square_centimeter_short = ""{area, unit, "
      & "area-square-centimetre/unit-width-short}"""
      & ASCII.LF
      & "en.unit_square_yard = ""{area, unit, area-square-yard}"""
      & ASCII.LF
      & "en.measure_square_inch_short = ""{area, number, "
      & "::measure-unit/area-square-inch unit-width-short}"""
      & ASCII.LF
      & "de.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "fr.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "es.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "it.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "pt.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "nl.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "ro.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "lt.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "sl.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "pl.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "cs.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "ru.measure_square_foot = ""{area, number, ::measure-unit/area-square-foot}"""
      & ASCII.LF
      & "en.measure_square_mile_short = ""{area, number, ::measure-unit/area-square-mile unit-width-short}"""
      & ASCII.LF
      & "de.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "fr.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "es.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "it.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "pt.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "nl.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "ro.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "lt.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "sl.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "pl.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "cs.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "ru.measure_square_mile = ""{area, number, ::measure-unit/area-square-mile}"""
      & ASCII.LF
      & "de.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "fr.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "es.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "it.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "ru.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "ko.measure_hectare = ""{area, number, ::measure-unit/area-hectare}"""
      & ASCII.LF
      & "en.measure_celsius = ""{temperature, number, ::measure-unit/temperature-celsius}"""
      & ASCII.LF
      & "en.measure_fahrenheit_short = ""{temperature, number, "
      & "::measure-unit/temperature-fahrenheit unit-width-short}"""
      & ASCII.LF
      & "en.measure_degree_short = ""{angle, number, ::measure-unit/angle-degree unit-width-short}"""
      & ASCII.LF
      & "en.measure_byte_short = ""{size, number, ::measure-unit/digital-byte unit-width-short}"""
      & ASCII.LF
      & "en.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "de.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "fr.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "es.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "it.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "pt.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "nl.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "ro.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "lt.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "sl.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "pl.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "cs.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "ru.unit_bit_alias = ""{size, unit, digital-bit}"""
      & ASCII.LF
      & "en.measure_gigabyte = ""{size, number, ::measure-unit/digital-gigabyte}"""
      & ASCII.LF
      & "en.measure_megabit_short = ""{size, number, ::measure-unit/digital-megabit unit-width-short}"""
      & ASCII.LF
      & "en.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "de.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "fr.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "es.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "it.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "pt.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "nl.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "ro.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "lt.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "sl.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "pl.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "cs.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "ru.measure_gigabit = ""{size, number, ::measure-unit/digital-gigabit}"""
      & ASCII.LF
      & "en.measure_petabyte_short = ""{size, number, ::measure-unit/digital-petabyte unit-width-short}"""
      & ASCII.LF
      & "en.measure_kilometer_per_hour_short = ""{speed, number, "
      & "::measure-unit/speed-kilometer-per-hour unit-width-short}"""
      & ASCII.LF
      & "en.measure_mile_per_hour = ""{speed, number, "
      & "::measure-unit/speed-mile-per-hour}"""
      & ASCII.LF
      & "en.measure_joule = ""{energy, number, ::measure-unit/energy-joule}"""
      & ASCII.LF
      & "en.measure_kilojoule_short = ""{energy, number, ::measure-unit/energy-kilojoule unit-width-short}"""
      & ASCII.LF
      & "en.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "en.measure_kilocalorie_short = ""{energy, number, ::measure-unit/energy-kilocalorie unit-width-short}"""
      & ASCII.LF
      & "en.measure_kilowatt_hour = ""{energy, number, ::measure-unit/energy-kilowatt-hour}"""
      & ASCII.LF
      & "en.measure_electronvolt_short = ""{energy, number, "
      & "::measure-unit/energy-electronvolt unit-width-short}"""
      & ASCII.LF
      & "en.measure_btu = ""{energy, number, "
      & "::measure-unit/energy-british-thermal-unit}"""
      & ASCII.LF
      & "en.measure_therm_us = ""{energy, number, "
      & "::measure-unit/energy-therm-us}"""
      & ASCII.LF
      & "de.measure_kilowatt_hour = ""{energy, number, ::measure-unit/energy-kilowatt-hour}"""
      & ASCII.LF
      & "fr.measure_joule = ""{energy, number, ::measure-unit/energy-joule}"""
      & ASCII.LF
      & "es.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "pt.measure_kilowatt_hour = ""{energy, number, ::measure-unit/energy-kilowatt-hour}"""
      & ASCII.LF
      & "nl.measure_joule = ""{energy, number, ::measure-unit/energy-joule}"""
      & ASCII.LF
      & "pl.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "ru.measure_joule = ""{energy, number, ::measure-unit/energy-joule}"""
      & ASCII.LF
      & "ar.measure_joule = ""{energy, number, ::measure-unit/energy-joule}"""
      & ASCII.LF
      & "ar.measure_kilowatt_hour = ""{energy, number, ::measure-unit/energy-kilowatt-hour}"""
      & ASCII.LF
      & "ja.measure_kilojoule = ""{energy, number, ::measure-unit/energy-kilojoule}"""
      & ASCII.LF
      & "ko.measure_kilowatt_hour = ""{energy, number, ::measure-unit/energy-kilowatt-hour}"""
      & ASCII.LF
      & "ru.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "ja.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "ko.measure_calorie = ""{energy, number, ::measure-unit/energy-calorie}"""
      & ASCII.LF
      & "en.unit_watt_alias = ""{power, unit, power-watt}"""
      & ASCII.LF
      & "es.unit_watt_alias = ""{power, unit, power-watt}"""
      & ASCII.LF
      & "ro.unit_watt_alias = ""{power, unit, power-watt}"""
      & ASCII.LF
      & "ja.unit_watt_alias = ""{power, unit, power-watt}"""
      & ASCII.LF
      & "en.measure_kilowatt_short = ""{power, number, ::measure-unit/power-kilowatt unit-width-short}"""
      & ASCII.LF
      & "ru.measure_kilowatt = ""{power, number, ::measure-unit/power-kilowatt}"""
      & ASCII.LF
      & "ar.measure_kilowatt = ""{power, number, ::measure-unit/power-kilowatt}"""
      & ASCII.LF
      & "ja.measure_kilowatt = ""{power, number, ::measure-unit/power-kilowatt}"""
      & ASCII.LF
      & "ko.measure_kilowatt = ""{power, number, ::measure-unit/power-kilowatt}"""
      & ASCII.LF
      & "cs.measure_kilowatt = ""{power, number, ::measure-unit/power-kilowatt}"""
      & ASCII.LF
      & "en.measure_hertz = ""{frequency, number, ::measure-unit/frequency-hertz}"""
      & ASCII.LF
      & "en.measure_kilohertz_short = ""{frequency, number, ::measure-unit/frequency-kilohertz unit-width-short}"""
      & ASCII.LF
      & "en.measure_megahertz = ""{frequency, number, ::measure-unit/frequency-megahertz}"""
      & ASCII.LF
      & "ru.measure_megahertz = ""{frequency, number, ::measure-unit/frequency-megahertz}"""
      & ASCII.LF
      & "ar.measure_megahertz = ""{frequency, number, ::measure-unit/frequency-megahertz}"""
      & ASCII.LF
      & "ja.measure_megahertz = ""{frequency, number, ::measure-unit/frequency-megahertz}"""
      & ASCII.LF
      & "ko.measure_megahertz = ""{frequency, number, ::measure-unit/frequency-megahertz}"""
      & ASCII.LF
      & "en.measure_hectopascal_short = ""{pressure, number, ::measure-unit/pressure-hectopascal unit-width-short}"""
      & ASCII.LF
      & "en.measure_pascal = ""{pressure, number, ::measure-unit/pressure-pascal}"""
      & ASCII.LF
      & "en.measure_kilopascal_short = ""{pressure, number, ::measure-unit/pressure-kilopascal unit-width-short}"""
      & ASCII.LF
      & "en.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "de.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "sl.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "ru.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "ar.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "ja.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "ko.measure_millibar = ""{pressure, number, ::measure-unit/pressure-millibar}"""
      & ASCII.LF
      & "en.unit_ampere_alias = ""{electric, unit, electric-ampere}"""
      & ASCII.LF
      & "en.measure_ampere_short = ""{electric, number, ::measure-unit/electric-ampere unit-width-short}"""
      & ASCII.LF
      & "en.measure_volt = ""{electric, number, ::measure-unit/electric-volt}"""
      & ASCII.LF
      & "en.measure_ohm_short = ""{electric, number, ::measure-unit/electric-ohm unit-width-short}"""
      & ASCII.LF
      & "en.measure_lumen = ""{light, number, ::measure-unit/light-lumen}"""
      & ASCII.LF
      & "en.measure_lux_short = ""{light, number, ::measure-unit/light-lux unit-width-short}"""
      & ASCII.LF
      & "en.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "fr.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "lt.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "zh.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "ru.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "ar.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "ja.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "ko.measure_percent = ""{share, number, ::measure-unit/concentr-percent}"""
      & ASCII.LF
      & "en.measure_percent_short = ""{share, number, ::measure-unit/percent unit-width-short}"""
      & ASCII.LF
      & "en.measure_permille = ""{share, number, ::measure-unit/concentr-permille}"""
      & ASCII.LF
      & "en.measure_permillion_short = ""{share, number, "
      & "::measure-unit/concentr-permillion unit-width-short}"""
      & ASCII.LF
      & "en.measure_portion = ""{share, number, ::measure-unit/concentr-portion}"""
      & ASCII.LF
      & "en.measure_karat_short = ""{share, number, "
      & "::measure-unit/concentr-karat unit-width-short}"""
      & ASCII.LF
      & "en.measure_dot = ""{graphics, number, ::measure-unit/graphics-dot}"""
      & ASCII.LF
      & "en.measure_megapixel_short = ""{graphics, number, "
      & "::measure-unit/graphics-megapixel unit-width-short}"""
      & ASCII.LF
      & "en.measure_pixel_per_cm = ""{graphics, number, "
      & "::measure-unit/graphics-pixel-per-centimeter}"""
      & ASCII.LF
      & "en.measure_dot_per_inch_short = ""{graphics, number, "
      & "::measure-unit/graphics-dot-per-inch unit-width-short}"""
      & ASCII.LF
      & "en.measure_earth_mass = ""{weight, number, "
      & "::measure-unit/mass-earth-mass}"""
      & ASCII.LF
      & "en.measure_solar_mass_short = ""{weight, number, "
      & "::measure-unit/mass-solar-mass unit-width-short}"""
      & ASCII.LF
      & "en.measure_barrel_short = ""{volume, number, "
      & "::measure-unit/volume-barrel unit-width-short}"""
      & ASCII.LF
      & "en.measure_kelvin = ""{temperature, number, "
      & "::measure-unit/temperature-kelvin}"""
      & ASCII.LF
      & "en.measure_horsepower_short = ""{power, number, "
      & "::measure-unit/power-horsepower unit-width-short}"""
      & ASCII.LF
      & "en.measure_kilobit = ""{size, number, ::measure-unit/digital-kilobit}"""
      & ASCII.LF
      & "en.measure_terabit_short = ""{size, number, "
      & "::measure-unit/digital-terabit unit-width-short}"""
      & ASCII.LF
      & "en.measure_petabit = ""{size, number, ::measure-unit/digital-petabit}"""
      & ASCII.LF
      & "en.measure_exabyte_short = ""{size, number, "
      & "::measure-unit/digital-exabyte unit-width-short}"""
      & ASCII.LF
      & "en.measure_exabit = ""{size, number, ::measure-unit/digital-exabit}"""
      & ASCII.LF
      & "en.measure_knot = ""{speed, number, ::measure-unit/speed-knot}"""
      & ASCII.LF
      & "en.measure_beaufort_short = ""{speed, number, "
      & "::measure-unit/speed-beaufort unit-width-short}"""
      & ASCII.LF
      & "en.measure_psi = ""{pressure, number, "
      & "::measure-unit/pressure-pound-force-per-square-inch}"""
      & ASCII.LF
      & "en.measure_milliampere = ""{electric, number, "
      & "::measure-unit/electric-milliampere}"""
      & ASCII.LF
      & "en.measure_millivolt_short = ""{electric, number, "
      & "::measure-unit/electric-millivolt unit-width-short}"""
      & ASCII.LF
      & "en.measure_candela = ""{light, number, "
      & "::measure-unit/light-candela}"""
      & ASCII.LF
      & "en.measure_solar_luminosity_short = ""{light, number, "
      & "::measure-unit/light-solar-luminosity unit-width-short}"""
      & ASCII.LF
      & "en.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "en-u-nu-beng.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "de.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "fr.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "es.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "it.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "pt.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "nl.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ro.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "lt.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "sl.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "pl.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "cs.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ru.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ar.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ar-u-nu-latn.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ja.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "zh.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "ko.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "tr.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "da.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "hi.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "el.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "he.measure_per = ""{distance, number, "
      & "::measure-unit/length-kilometer per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "en.measure_per_short = ""{distance, number, "
      & "::measure-unit/length-kilometer unit-width-short "
      & "per-measure-unit/duration-hour}"""
      & ASCII.LF
      & "en.relative = ""{offset, relative, day}""" & ASCII.LF
      & "bn.relative = ""{offset, relative, day}""" & ASCII.LF
      & "en-u-nu-beng.relative = ""{offset, relative, day}"""
      & ASCII.LF
      & "ar-u-nu-latn.relative = ""{offset, relative, day}"""
      & ASCII.LF
      & "ar.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ja.relative = ""{offset, relative, day}""" & ASCII.LF
      & "zh.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ko.relative = ""{offset, relative, day}""" & ASCII.LF
      & "de.relative = ""{offset, relative, day}""" & ASCII.LF
      & "fr.relative = ""{offset, relative, day}""" & ASCII.LF
      & "es.relative = ""{offset, relative, day}""" & ASCII.LF
      & "it.relative = ""{offset, relative, day}""" & ASCII.LF
      & "pt.relative = ""{offset, relative, day}""" & ASCII.LF
      & "nl.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ro.relative = ""{offset, relative, day}""" & ASCII.LF
      & "lt.relative = ""{offset, relative, day}""" & ASCII.LF
      & "sl.relative = ""{offset, relative, day}""" & ASCII.LF
      & "pl.relative = ""{offset, relative, day}""" & ASCII.LF
      & "cs.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ru.relative = ""{offset, relative, day}""" & ASCII.LF
      & "tr.relative = ""{offset, relative, day}""" & ASCII.LF
      & "sv.relative = ""{offset, relative, day}""" & ASCII.LF
      & "da.relative = ""{offset, relative, day}""" & ASCII.LF
      & "fi.relative = ""{offset, relative, day}""" & ASCII.LF
      & "eo.relative = ""{offset, relative, day}""" & ASCII.LF
      & "vi.relative = ""{offset, relative, day}""" & ASCII.LF
      & "hu.relative = ""{offset, relative, day}""" & ASCII.LF
      & "sk.relative = ""{offset, relative, day}""" & ASCII.LF
      & "no.relative = ""{offset, relative, day}""" & ASCII.LF
      & "id.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ms.relative = ""{offset, relative, day}""" & ASCII.LF
      & "af.relative = ""{offset, relative, day}""" & ASCII.LF
      & "sw.relative = ""{offset, relative, day}""" & ASCII.LF
      & "eu.relative = ""{offset, relative, day}""" & ASCII.LF
      & "bg.relative = ""{offset, relative, day}""" & ASCII.LF
      & "uk.relative = ""{offset, relative, day}""" & ASCII.LF
      & "fa.relative = ""{offset, relative, day}""" & ASCII.LF
      & "th.relative = ""{offset, relative, day}""" & ASCII.LF
      & "hi.relative = ""{offset, relative, day}""" & ASCII.LF
      & "el.relative = ""{offset, relative, day}""" & ASCII.LF
      & "he.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ca.relative = ""{offset, relative, day}""" & ASCII.LF
      & "az.relative = ""{offset, relative, day}""" & ASCII.LF
      & "ur.relative = ""{offset, relative, day}""" & ASCII.LF
      & "sr.relative = ""{offset, relative, day}""" & ASCII.LF
      & "de.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "fr.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "es.relative_year = ""{offset, relative, year}""" & ASCII.LF
      & "it.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "pt.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "nl.relative_year = ""{offset, relative, year}""" & ASCII.LF
      & "pl.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "cs.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "ru.relative_year = ""{offset, relative, year}""" & ASCII.LF
      & "ar.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "de.relative_quarter_short = ""{offset, relative, quarter/short}""" & ASCII.LF
      & "tr.relative_year = ""{offset, relative, year}""" & ASCII.LF
      & "sv.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "da.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "fi.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "eo.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "vi.relative_year = ""{offset, relative, year}""" & ASCII.LF
      & "hu.relative_month = ""{offset, relative, month}""" & ASCII.LF
      & "sk.relative_week = ""{offset, relative, week}""" & ASCII.LF
      & "en.relative_quarter = ""{offset, relative, quarter}""" & ASCII.LF
      & "en.relative_quarter_short = ""{offset, relative, quarter/short}""" & ASCII.LF
      & "en.relative_quarter_short_slash = ""{offset, relative, quarter/unit-width/short}""" & ASCII.LF
      & "en.relative_quarter_narrow = ""{offset, relative, quarter/narrow}""" & ASCII.LF
      & "en.relative_quarter_narrow_slash = ""{offset, relative, quarter/unit-width/narrow}""" & ASCII.LF
      & "en.relative_hour = ""{offset, relative, hour}""" & ASCII.LF
      & "en.relative_minute = ""{offset, relative, minute}""" & ASCII.LF
      & "en.relative_second = ""{offset, relative, second}""" & ASCII.LF
      & "en.relative_second_short = ""{offset, relative, second/short}""" & ASCII.LF
      & "en.relative_second_narrow = ""{offset, relative, second/narrow}""" & ASCII.LF
      & "en.list = ""{items, list}""" & ASCII.LF
      & "en.list_standard = ""{items, list, standard}""" & ASCII.LF
      & "en.list_and = ""{items, list, and}""" & ASCII.LF
      & "en.list_or = ""{items, list, or}""" & ASCII.LF
      & "en.list_disjunction = ""{items, list, disjunction}""" & ASCII.LF
      & "en.list_unit = ""{items, list, unit}""" & ASCII.LF
      & "de.list_or = ""{items, list, or}""" & ASCII.LF
      & "fr.list_or = ""{items, list, or}""" & ASCII.LF
      & "pl.list_or = ""{items, list, or}""" & ASCII.LF
      & "vi.list_or = ""{items, list, or}""" & ASCII.LF
      & "ja.list_unit = ""{items, list, unit}""" & ASCII.LF
      & "de.list = ""{items, list}""" & ASCII.LF
      & "fr.list = ""{items, list}""" & ASCII.LF
      & "es.list = ""{items, list}""" & ASCII.LF
      & "it.list = ""{items, list}""" & ASCII.LF
      & "pt.list = ""{items, list}""" & ASCII.LF
      & "nl.list = ""{items, list}""" & ASCII.LF
      & "ro.list = ""{items, list}""" & ASCII.LF
      & "lt.list = ""{items, list}""" & ASCII.LF
      & "sl.list = ""{items, list}""" & ASCII.LF
      & "pl.list = ""{items, list}""" & ASCII.LF
      & "cs.list = ""{items, list}""" & ASCII.LF
      & "ru.list = ""{items, list}""" & ASCII.LF
      & "ar.list = ""{items, list}""" & ASCII.LF
      & "ja.list = ""{items, list}""" & ASCII.LF
      & "zh.list = ""{items, list}""" & ASCII.LF
      & "ko.list = ""{items, list}""" & ASCII.LF
      & "tr.list = ""{items, list}""" & ASCII.LF
      & "sv.list = ""{items, list}""" & ASCII.LF
      & "da.list = ""{items, list}""" & ASCII.LF
      & "no.list = ""{items, list}""" & ASCII.LF
      & "fi.list = ""{items, list}""" & ASCII.LF
      & "id.list = ""{items, list}""" & ASCII.LF
      & "ms.list = ""{items, list}""" & ASCII.LF
      & "eo.list = ""{items, list}""" & ASCII.LF
      & "vi.list = ""{items, list}""" & ASCII.LF
      & "sw.list = ""{items, list}""" & ASCII.LF
      & "af.list = ""{items, list}""" & ASCII.LF
      & "eu.list = ""{items, list}""" & ASCII.LF
      & "hu.list = ""{items, list}""" & ASCII.LF
      & "sk.list = ""{items, list}""" & ASCII.LF
      & "bg.list = ""{items, list}""" & ASCII.LF
      & "uk.list = ""{items, list}""" & ASCII.LF
      & "fa.list = ""{items, list}""" & ASCII.LF
      & "th.list = ""{items, list}""" & ASCII.LF
      & "hi.list = ""{items, list}""" & ASCII.LF
      & "el.list = ""{items, list}""" & ASCII.LF
      & "he.list = ""{items, list}""" & ASCII.LF
      & "en.bad_duration = ""{bad, duration}""" & ASCII.LF
      & "en.bad_bytes = ""{bad, bytes}""" & ASCII.LF
      & "en.bad_unit = ""{bad, unit, meter}""" & ASCII.LF
      & "en.bad_relative = ""{bad, relative, day}""" & ASCII.LF
      & "en.bad_list = ""{bad, list}""" & ASCII.LF,
      Result);

   Assert (Result.Status = I18N.Runtime.Loaded,
           "ecosystem formatter catalog should load");

   I18N.Arguments.Set (Args, "seconds", "3661");
   Assert (Rendered (Runtime, "en", "duration", Args) = "1:01:01",
           "duration formatter renders seconds as H:MM:SS");
   Assert (Rendered (Runtime, "ar", "duration", Args) =
           U (16#0661#) & ":" & U (16#0660#) & U (16#0661#) & ":"
           & U (16#0660#) & U (16#0661#),
           "duration formatter localizes digits");
   Assert (Rendered (Runtime, "en-u-nu-beng", "duration", Args) =
           U (16#09E7#) & ":" & U (16#09E6#) & U (16#09E7#) & ":"
           & U (16#09E6#) & U (16#09E7#),
           "duration formatter honors explicit numbering-system digits");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "duration", Args) =
           "1:01:01",
           "duration formatter honors explicit Latin digits");
   Expect_Bounded
     ("en", "duration", "1:01:01",
      "bounded duration formatting");

   I18N.Arguments.Set (Args, "size", "1536");
   Assert (Rendered (Runtime, "en", "bytes", Args) = "2 KiB",
           "byte formatter renders deterministic binary units");
   I18N.Arguments.Set (Args, "size", "1649267441664");
   Assert (Rendered (Runtime, "en", "bytes", Args) = "2 TiB",
           "byte formatter renders tebibyte units");
   Assert (Rendered (Runtime, "ar", "bytes", Args) =
             U (16#0662#) & " TiB",
           "byte formatter localizes large-unit digits");
   Assert (Rendered (Runtime, "en-u-nu-beng", "bytes", Args) =
             U (16#09E8#) & " TiB",
           "byte formatter honors explicit numbering-system digits");
   Expect_Bounded
     ("en", "bytes", "2 TiB",
      "bounded byte-size formatting");
   I18N.Arguments.Set (Args, "size", "1688849860263936");
   Assert (Rendered (Runtime, "en", "bytes", Args) = "2 PiB",
           "byte formatter renders pebibyte units");

   I18N.Arguments.Set (Args, "distance", "2");
   Assert (Rendered (Runtime, "en", "unit", Args) = "2 kilometers",
           "unit formatter pluralizes supported units");
   Assert (Rendered (Runtime, "en", "unit_long_width", Args) =
             "2 kilometers",
           "unit formatter accepts unit-width-long alias");
   Assert (Rendered (Runtime, "en", "unit_long_width_slash", Args) =
             Rendered (Runtime, "en", "unit_long_width", Args),
           "unit formatter accepts unit-width/long alias");
   Assert (Rendered (Runtime, "de", "unit", Args) = "2 Kilometer",
           "unit formatter localizes German full unit names");
   Assert (Rendered (Runtime, "fr", "unit", Args) =
             "2 kilom" & U (16#E8#) & "tres",
           "unit formatter localizes French full unit names");
   Assert (Rendered (Runtime, "es", "unit", Args) =
             "2 kil" & U (16#F3#) & "metros",
           "unit formatter localizes Spanish full unit names");
   Assert (Rendered (Runtime, "it", "unit", Args) = "2 chilometri",
           "unit formatter localizes Italian full unit names");
   Assert (Rendered (Runtime, "pt", "unit", Args) =
             "2 quil" & U (16#F4#) & "metros",
           "unit formatter localizes Portuguese full unit names");
   Assert (Rendered (Runtime, "nl", "unit", Args) = "2 kilometer",
           "unit formatter localizes Dutch full unit names");
   Assert (Rendered (Runtime, "ro", "unit", Args) = "2 kilometri",
           "unit formatter localizes Romanian full unit names");
   Assert (Rendered (Runtime, "lt", "unit", Args) = "2 kilometrai",
           "unit formatter localizes Lithuanian full unit names");
   Assert (Rendered (Runtime, "sl", "unit", Args) = "2 kilometra",
           "unit formatter localizes Slovenian full unit names");
   Assert (Rendered (Runtime, "pl", "unit", Args) = "2 kilometry",
           "unit formatter localizes Polish full unit names");
   Assert (Rendered (Runtime, "cs", "unit", Args) = "2 kilometry",
           "unit formatter localizes Czech full unit names");
   Assert (Rendered (Runtime, "ru", "unit", Args) =
             "2 " & UTF8 ([16#43A#, 16#438#, 16#43B#, 16#43E#,
                            16#43C#, 16#435#, 16#442#, 16#440#,
                            16#430#]),
           "unit formatter localizes Russian full unit names");
   Assert (Rendered (Runtime, "ar", "unit", Args) =
             U (16#0662#) & " "
             & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#, 16#645#,
                       16#62A#, 16#631#]),
           "unit formatter localizes Arabic full unit names");
   Assert (Rendered (Runtime, "ja", "unit", Args) =
             "2" & UTF8 ([16#30AD#, 16#30ED#, 16#30E1#, 16#30FC#,
                           16#30C8#, 16#30EB#]),
           "unit formatter localizes Japanese full unit names");
   Assert (Rendered (Runtime, "zh", "unit", Args) =
             "2" & UTF8 ([16#516C#, 16#91CC#]),
           "unit formatter localizes Chinese full unit names");
   Assert (Rendered (Runtime, "ko", "unit", Args) =
             "2" & UTF8 ([16#D0AC#, 16#B85C#, 16#BBF8#, 16#D130#]),
           "unit formatter localizes Korean full unit names");
   I18N.Arguments.Set (Args, "distance", "1.5");
   Assert (Rendered (Runtime, "en", "unit_decimal", Args) =
             "1.5 kilometers",
           "unit formatter accepts strict decimal values");
   Assert (Rendered (Runtime, "ar", "unit_decimal", Args) =
             U (16#0661#) & U (16#066B#) & U (16#0665#)
             & " " & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#,
                             16#645#, 16#62A#, 16#631#]),
           "unit formatter localizes decimal digits and separator");
   Assert (Rendered (Runtime, "en-u-nu-beng", "unit_decimal", Args) =
             U (16#09E7#) & "." & U (16#09EB#) & " kilometers",
           "unit formatter honors explicit numbering-system digits");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "unit_decimal", Args) =
             "1" & U (16#066B#) & "5 "
             & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#,
                      16#645#, 16#62A#, 16#631#]),
           "unit formatter honors explicit Latin digits");
   Expect_Bounded
     ("en", "unit_decimal", "1.5 kilometers",
      "bounded unit formatting");
   Assert (Rendered (Runtime, "en", "unit_mile_alias", Args) =
             "1.5 miles",
           "unit formatter accepts ICU-style length-mile alias");
   Assert (Rendered (Runtime, "en", "unit_metre_alias", Args) =
             "1.5 meters",
           "unit formatter accepts British length-metre alias");
   Assert (Rendered (Runtime, "en", "unit_kilometre_alias", Args) =
             "1.5 kilometers",
           "unit formatter accepts British length-kilometre alias");
   Assert (Rendered (Runtime, "en", "unit_yard_alias", Args) =
             "1.5 yards",
           "unit formatter accepts ICU-style length-yard alias");
   Assert (Rendered (Runtime, "en", "unit_foot_alias", Args) =
             "1.5 feet",
           "unit formatter accepts ICU-style length-foot alias");
   Assert (Rendered (Runtime, "en", "unit_inch_alias", Args) =
             "1.5 inches",
           "unit formatter accepts ICU-style length-inch alias");
   Assert (Rendered (Runtime, "de", "unit_centimetre_alias", Args) =
             "1,5 Zentimeter",
           "unit formatter accepts British length-centimetre alias");
   I18N.Arguments.Set (Args, "volume", "2");
   Assert (Rendered (Runtime, "en", "unit_litre_alias", Args) =
             "2 liters",
           "unit formatter accepts volume-litre alias");
   I18N.Arguments.Set (Args, "weight", "2");
   Assert (Rendered (Runtime, "en", "unit_pound_alias", Args) =
             "2 pounds",
           "unit formatter accepts mass-pound alias");
   Assert (Rendered (Runtime, "en", "unit_tonne_alias", Args) =
             "2 metric tons",
           "unit formatter accepts mass-tonne alias");
   I18N.Arguments.Set (Args, "elapsed", "1");
   Assert (Rendered (Runtime, "en", "unit_nanosecond_alias", Args) =
             "1 nanosecond",
           "unit formatter accepts duration-nanosecond alias");
   Assert (Rendered (Runtime, "en", "unit_microsecond_alias", Args) =
             "1 microsecond",
           "unit formatter accepts duration-microsecond alias");
   Assert (Rendered (Runtime, "en", "unit_millisecond_alias", Args) =
             "1 millisecond",
           "unit formatter accepts duration-millisecond alias");
   I18N.Arguments.Set (Args, "elapsed", "2");
   Assert (Rendered (Runtime, "en", "unit_fortnight", Args) =
             "2 fortnights",
           "unit formatter accepts duration-fortnight alias");
   I18N.Arguments.Set (Args, "elapsed", "1");
   Assert (Rendered (Runtime, "en", "unit_quarter", Args) =
             "1 quarter",
           "unit formatter accepts duration-quarter alias");
   Assert (Rendered (Runtime, "en", "unit_decade", Args) =
             "1 decade",
           "unit formatter accepts duration-decade alias");
   Assert (Rendered (Runtime, "en", "unit_century", Args) =
             "1 century",
           "unit formatter accepts duration-century alias");
   I18N.Arguments.Set (Args, "area", "2");
   Assert (Rendered (Runtime, "en", "unit_square_meter_alias", Args) =
             "2 square meters",
           "unit formatter accepts area-square-meter alias");
   I18N.Arguments.Set (Args, "temperature", "1");
   Assert (Rendered (Runtime, "en", "unit_celsius_alias", Args) =
             "1 degree Celsius",
           "unit formatter accepts temperature-celsius alias");
   I18N.Arguments.Set (Args, "angle", "45");
   Assert (Rendered (Runtime, "en", "unit_degree_alias", Args) =
             "45 degrees",
           "unit formatter accepts angle-degree alias");
   Assert (Rendered (Runtime, "en", "unit_radian_alias", Args) =
             "45 radians",
           "unit formatter accepts angle-radian alias");
   Assert (Rendered (Runtime, "en", "unit_revolution_short", Args) =
             "45 rev",
           "unit formatter accepts short angle-revolution alias");
   Assert (Rendered (Runtime, "en", "unit_arc_minute", Args) =
             "45 arcminutes",
           "unit formatter accepts angle-arc-minute alias");
   Assert (Rendered (Runtime, "en", "unit_arc_second_short", Args) =
             "45 arcsecs",
           "unit formatter accepts short angle-arc-second alias");
   I18N.Arguments.Set (Args, "acceleration", "2");
   Assert (Rendered (Runtime, "en", "unit_g_force", Args) =
             "2 g-force",
           "unit formatter accepts acceleration-g-force alias");
   Assert (Rendered (Runtime, "en", "unit_acceleration_short", Args) =
             "2 m/s" & U (16#B2#),
           "unit formatter accepts acceleration metre-per-square-second alias");
   I18N.Arguments.Set (Args, "force", "2");
   Assert (Rendered (Runtime, "en", "unit_newton", Args) =
             "2 newtons",
           "unit formatter accepts force-newton alias");
   Assert (Rendered (Runtime, "en", "unit_pound_force_short", Args) =
             "2 lbf",
           "unit formatter accepts short force-pound-force alias");
   I18N.Arguments.Set (Args, "torque", "2");
   Assert (Rendered (Runtime, "en", "unit_torque", Args) =
             "2 newton-meters",
           "unit formatter accepts torque-newton-metre alias");
   I18N.Arguments.Set (Args, "size", "2");
   Assert (Rendered (Runtime, "en", "unit_byte_alias", Args) =
             "2 bytes",
           "unit formatter accepts digital-byte alias");
   Assert (Rendered (Runtime, "en", "unit_megabyte_short", Args) =
             "2 MB",
           "unit formatter accepts digital-megabyte short alias");
   I18N.Arguments.Set (Args, "speed", "90");
   Assert (Rendered (Runtime, "en", "unit_kilometre_per_hour", Args) =
             "90 kilometers per hour",
           "unit formatter accepts speed-kilometre-per-hour alias");
   Assert (Rendered (Runtime, "en", "unit_metre_per_second_short", Args) =
             "90 m/s",
           "unit formatter accepts speed-metre-per-second short alias");
   Assert (Rendered (Runtime, "en",
             "unit_metre_per_second_short_slash", Args) =
             Rendered (Runtime, "en", "unit_metre_per_second_short",
               Args),
           "unit formatter accepts unit-width/short alias");
   I18N.Arguments.Set (Args, "consumption", "5.5");
   Assert (Rendered (Runtime, "en", "unit_l_per_100km_short", Args) =
             "5.5 L/100 km",
           "unit formatter accepts short consumption litre-per-100-kilometre alias");
   Assert (Rendered (Runtime, "en", "unit_mpg", Args) =
             "5.5 miles per gallon",
           "unit formatter accepts consumption-mile-per-gallon alias");
   Assert (Rendered (Runtime, "en", "unit_mpg_imperial", Args) =
             "5.5 miles per Imp. gallon",
           "unit formatter accepts imperial gallon consumption alias");
   I18N.Arguments.Set (Args, "energy", "2");
   Assert (Rendered (Runtime, "en", "unit_electronvolt_short", Args) =
             "2 eV",
           "unit formatter accepts short energy-electronvolt alias");
   Assert (Rendered (Runtime, "en", "unit_btu", Args) =
             "2 British thermal units",
           "unit formatter accepts energy-british-thermal-unit alias");
   Assert (Rendered (Runtime, "en", "unit_therm_us", Args) =
             "2 US therms",
           "unit formatter accepts energy-therm-us alias");
   I18N.Arguments.Set (Args, "share", "50");
   Assert (Rendered (Runtime, "en", "unit_permille_short", Args) =
             "50 " & U (16#2030#),
           "unit formatter accepts short concentr-permille alias");
   Assert (Rendered (Runtime, "en", "unit_permillion", Args) =
             "50 parts per million",
           "unit formatter accepts concentr-permillion alias");
   Assert (Rendered (Runtime, "en", "unit_karat_short", Args) =
             "50 kt",
           "unit formatter accepts short concentr-karat alias");
   I18N.Arguments.Set (Args, "graphics", "2");
   Assert (Rendered (Runtime, "en", "unit_dot", Args) =
             "2 dots",
           "unit formatter accepts graphics-dot alias");
   Assert (Rendered (Runtime, "en", "unit_megapixel_short", Args) =
             "2 MP",
           "unit formatter accepts short graphics-megapixel alias");
   Assert (Rendered (Runtime, "en", "unit_pixel_per_inch_short", Args) =
             "2 ppi",
           "unit formatter accepts short graphics-pixel-per-inch alias");
   Assert (Rendered (Runtime, "en", "unit_dot_per_cm", Args) =
             "2 dots per centimeter",
           "unit formatter accepts graphics-dot-per-centimetre alias");
   I18N.Arguments.Set (Args, "distance", "2");
   Assert (Rendered (Runtime, "en", "unit_earth_radius_short", Args) =
             "2 R" & U (16#2295#),
           "unit formatter accepts short length-earth-radius alias");
   Assert (Rendered (Runtime, "en", "unit_decimetre_short", Args) =
             "2 dm",
           "unit formatter accepts short length-decimetre alias");
   Assert (Rendered (Runtime, "en", "unit_micrometer", Args) =
             "2 micrometers",
           "unit formatter accepts length-micrometer alias");
   Assert (Rendered (Runtime, "en", "unit_nanometre_short", Args) =
             "2 nm",
           "unit formatter accepts short length-nanometre alias");
   Assert (Rendered (Runtime, "en", "unit_picometer", Args) =
             "2 picometers",
           "unit formatter accepts length-picometer alias");
   I18N.Arguments.Set (Args, "volume", "2");
   Assert (Rendered (Runtime, "en", "unit_barrel", Args) =
             "2 barrels",
           "unit formatter accepts volume-barrel alias");
   I18N.Arguments.Set (Args, "weight", "2");
   Assert (Rendered (Runtime, "en", "unit_ton", Args) =
             "2 tons",
           "unit formatter accepts mass-ton alias");
   Assert (Rendered (Runtime, "en", "unit_dalton_short", Args) =
             "2 Da",
           "unit formatter accepts short mass-dalton alias");
   I18N.Arguments.Set (Args, "temperature", "2");
   Assert (Rendered (Runtime, "en", "unit_kelvin_short", Args) =
             "2 K",
           "unit formatter accepts short temperature-kelvin alias");
   I18N.Arguments.Set (Args, "power", "2");
   Assert (Rendered (Runtime, "en", "unit_horsepower_short", Args) =
             "2 hp",
           "unit formatter accepts short power-horsepower alias");
   I18N.Arguments.Set (Args, "size", "2");
   Assert (Rendered (Runtime, "en", "unit_kilobit_short", Args) =
             "2 kb",
           "unit formatter accepts short digital-kilobit alias");
   Assert (Rendered (Runtime, "en", "unit_terabit", Args) =
             "2 terabits",
           "unit formatter accepts digital-terabit alias");
   Assert (Rendered (Runtime, "en", "unit_petabit_short", Args) =
             "2 Pb",
           "unit formatter accepts short digital-petabit alias");
   Assert (Rendered (Runtime, "en", "unit_exabyte", Args) =
             "2 exabytes",
           "unit formatter accepts digital-exabyte alias");
   Assert (Rendered (Runtime, "en", "unit_exabit_short", Args) =
             "2 Eb",
           "unit formatter accepts short digital-exabit alias");
   I18N.Arguments.Set (Args, "speed", "2");
   Assert (Rendered (Runtime, "en", "unit_knot_short", Args) =
             "2 kn",
           "unit formatter accepts short speed-knot alias");
   Assert (Rendered (Runtime, "en", "unit_beaufort", Args) =
             "2 Beaufort",
           "unit formatter accepts speed-beaufort alias");
   I18N.Arguments.Set (Args, "pressure", "2");
   Assert (Rendered (Runtime, "en", "unit_psi_short", Args) =
             "2 psi",
           "unit formatter accepts short pressure PSI alias");
   I18N.Arguments.Set (Args, "electric", "2");
   Assert (Rendered (Runtime, "en", "unit_milliampere_short", Args) =
             "2 mA",
           "unit formatter accepts short electric-milliampere alias");
   Assert (Rendered (Runtime, "en", "unit_millivolt", Args) =
             "2 millivolts",
           "unit formatter accepts electric-millivolt alias");
   I18N.Arguments.Set (Args, "light", "2");
   Assert (Rendered (Runtime, "en", "unit_candela_short", Args) =
             "2 cd",
           "unit formatter accepts short light-candela alias");
   Assert (Rendered (Runtime, "en", "unit_solar_luminosity", Args) =
             "2 solar luminosities",
           "unit formatter accepts light-solar-luminosity alias");
   I18N.Arguments.Set (Args, "distance", "1.5");
   Assert (Rendered (Runtime, "en", "measure_unit", Args) =
             "1.5 kilometers",
           "number measure-unit skeleton maps to unit formatting");
   Assert (Rendered (Runtime, "en", "measure_full_name_slash", Args) =
             Rendered (Runtime, "en", "measure_unit", Args),
           "measure-unit skeleton accepts unit-width/full-name");
   Assert (Rendered (Runtime, "en", "measure_kilometre", Args) =
             "1.5 kilometers",
           "measure-unit skeleton accepts length-kilometre alias");
   Assert (Rendered (Runtime, "en", "measure_metre", Args) =
             "1.5 meters",
           "measure-unit skeleton accepts length-metre alias");
   I18N.Arguments.Set (Args, "acceleration", "1.5");
   Assert (Rendered (Runtime, "en", "measure_acceleration", Args) =
             "1.5 meters per second squared",
           "measure-unit skeleton accepts acceleration units");
   I18N.Arguments.Set (Args, "angle", "1.5");
   Assert (Rendered (Runtime, "en", "measure_radian_short", Args) =
             "1.5 rad",
           "measure-unit skeleton accepts short angle units");
   I18N.Arguments.Set (Args, "force", "1.5");
   Assert (Rendered (Runtime, "en", "measure_force_short", Args) =
             "1.5 N",
           "measure-unit skeleton accepts short force units");
   I18N.Arguments.Set (Args, "torque", "1.5");
   Assert (Rendered (Runtime, "en", "measure_torque", Args) =
             "1.5 newton-meters",
           "measure-unit skeleton accepts torque units");
   I18N.Arguments.Set (Args, "consumption", "5.5");
   Assert (Rendered (Runtime, "en", "measure_consumption", Args) =
             "5.5 liters per 100 kilometers",
           "measure-unit skeleton accepts consumption units");
   Assert (Rendered (Runtime, "en", "measure_mpg_short", Args) =
             "5.5 mpg",
           "measure-unit skeleton accepts short mpg consumption units");
   I18N.Arguments.Set (Args, "distance", "1.5");
   Assert (Rendered (Runtime, "en", "measure_per_century", Args) =
             "1.5 kilometers per century",
           "measure-unit skeleton accepts duration-century per units");
   Assert (Rendered (Runtime, "en", "measure_per_fortnight", Args) =
             "1.5 kilometers per fortnight",
           "measure-unit skeleton accepts duration-fortnight per units");
   Assert (Rendered (Runtime, "en", "measure_short", Args) = "1.5 km",
           "measure-unit skeleton accepts unit-width-short");
   Assert (Rendered (Runtime, "en", "measure_short_slash", Args) =
             Rendered (Runtime, "en", "measure_short", Args),
           "measure-unit skeleton accepts unit-width/short");
   Assert (Rendered (Runtime, "en", "measure_long_slash", Args) =
             Rendered (Runtime, "en", "measure_unit", Args),
           "measure-unit skeleton accepts unit-width/long");
   Assert (Rendered (Runtime, "en", "measure_mile", Args) =
             "1.5 miles",
           "measure-unit skeleton accepts length-mile");
   Assert (Rendered (Runtime, "en", "measure_yard", Args) =
             "1.5 yards",
           "measure-unit skeleton accepts length-yard");
   Assert (Rendered (Runtime, "en", "measure_foot_short", Args) =
             "1.5 ft",
           "measure-unit skeleton accepts short length-foot output");
   Assert (Rendered (Runtime, "en", "measure_inch", Args) =
             "1.5 inches",
           "measure-unit skeleton accepts length-inch");
   Assert (Rendered (Runtime, "de", "measure_mile", Args) =
             "1,5 Meilen",
           "measure-unit skeleton localizes German miles");
   Assert (Rendered (Runtime, "it", "measure_mile", Args) =
             "1,5 miglia",
           "measure-unit skeleton localizes Italian miles");
   Assert (Rendered (Runtime, "en", "measure_mile_short", Args) =
             "1.5 mi",
           "measure-unit skeleton accepts short length-mile output");
   Assert (Rendered (Runtime, "en", "measure_centimeter", Args) =
             "1.5 centimeters",
           "measure-unit skeleton accepts length-centimeter");
   Assert (Rendered (Runtime, "de", "measure_centimetre", Args) =
             "1,5 Zentimeter",
           "measure-unit skeleton accepts length-centimetre alias");
   Assert (Rendered (Runtime, "ro", "measure_meter", Args) =
             "1,5 metri",
           "measure-unit skeleton localizes Romanian meters");
   Assert (Rendered (Runtime, "en", "measure_millimeter_short", Args) =
             "1.5 mm",
           "measure-unit skeleton accepts short length-millimeter output");
   Assert (Rendered (Runtime, "en", "measure_decimeter", Args) =
             "1.5 decimeters",
           "measure-unit skeleton accepts length-decimeter");
   Assert (Rendered (Runtime, "en", "measure_micrometre_short", Args) =
             "1.5 " & U (16#3BC#) & "m",
           "measure-unit skeleton accepts short length-micrometre output");
   Assert (Rendered (Runtime, "en", "measure_nanometer", Args) =
             "1.5 nanometers",
           "measure-unit skeleton accepts length-nanometer");
   Assert (Rendered (Runtime, "en", "measure_picometre_short", Args) =
             "1.5 pm",
           "measure-unit skeleton accepts short length-picometre output");
   Assert (Rendered (Runtime, "en", "measure_nautical_mile", Args) =
             "1.5 nautical miles",
           "measure-unit skeleton accepts length-nautical-mile");
   Assert (Rendered (Runtime, "de", "measure_nautical_mile", Args) =
             "1,5 Seemeilen",
           "measure-unit skeleton localizes German nautical miles");
   Assert (Rendered (Runtime, "fr", "measure_nautical_mile", Args) =
             "1,5 mille marin",
           "measure-unit skeleton localizes French nautical miles");
   Assert (Rendered (Runtime, "es", "measure_nautical_mile", Args) =
             "1,5 millas n" & U (16#E1#) & "uticas",
           "measure-unit skeleton localizes Spanish nautical miles");
   Assert (Rendered (Runtime, "it", "measure_nautical_mile", Args) =
             "1,5 miglia nautiche",
           "measure-unit skeleton localizes Italian nautical miles");
   Assert (Rendered (Runtime, "pt", "measure_nautical_mile", Args) =
             "1,5 milha n" & U (16#E1#) & "utica",
           "measure-unit skeleton localizes Portuguese nautical miles");
   Assert (Rendered (Runtime, "nl", "measure_nautical_mile", Args) =
             "1,5 zeemijlen",
           "measure-unit skeleton localizes Dutch nautical miles");
   Assert (Rendered (Runtime, "ro", "measure_nautical_mile", Args) =
             "1,5 mile nautice",
           "measure-unit skeleton localizes Romanian nautical miles");
   Assert (Rendered (Runtime, "lt", "measure_nautical_mile", Args) =
             "1,5 j" & U (16#16B#) & "rmyl" & U (16#117#) & "s",
           "measure-unit skeleton localizes Lithuanian nautical miles");
   Assert (Rendered (Runtime, "sl", "measure_nautical_mile", Args) =
             "1,5 navti" & U (16#10D#) & "ne milje",
           "measure-unit skeleton localizes Slovenian nautical miles");
   Assert (Rendered (Runtime, "pl", "measure_nautical_mile", Args) =
             "1,5 mili morskiej",
           "measure-unit skeleton localizes Polish nautical miles");
   Assert (Rendered (Runtime, "cs", "measure_nautical_mile", Args) =
             "1,5 n" & U (16#E1#) & "mo" & U (16#159#)
             & "n" & U (16#ED#) & " m" & U (16#ED#) & "le",
           "measure-unit skeleton localizes Czech nautical miles");
   Assert (Rendered (Runtime, "ru", "measure_nautical_mile", Args) =
             "1,5 " & UTF8 ([16#43C#, 16#43E#, 16#440#, 16#441#,
                               16#43A#, 16#43E#, 16#439#, 16#20#,
                               16#43C#, 16#438#, 16#43B#, 16#438#]),
           "measure-unit skeleton localizes Russian nautical miles");
   Assert (Rendered (Runtime, "de", "measure_astronomical_unit", Args) =
             "1,5 Astronomische Einheiten",
           "measure-unit skeleton localizes German astronomical units");
   Assert (Rendered (Runtime, "fr", "measure_astronomical_unit", Args) =
             "1,5 unit" & U (16#E9#) & " astronomique",
           "measure-unit skeleton localizes French astronomical units");
   Assert (Rendered (Runtime, "es", "measure_astronomical_unit", Args) =
             "1,5 unidades astron" & U (16#F3#) & "micas",
           "measure-unit skeleton localizes Spanish astronomical units");
   Assert (Rendered (Runtime, "it", "measure_astronomical_unit", Args) =
             "1,5 unit" & U (16#E0#) & " astronomiche",
           "measure-unit skeleton localizes Italian astronomical units");
   Assert (Rendered (Runtime, "pt", "measure_astronomical_unit", Args) =
             "1,5 unidade astron" & U (16#F4#) & "mica",
           "measure-unit skeleton localizes Portuguese astronomical units");
   Assert (Rendered (Runtime, "nl", "measure_astronomical_unit", Args) =
             "1,5 astronomische eenheden",
           "measure-unit skeleton localizes Dutch astronomical units");
   Assert (Rendered (Runtime, "ro", "measure_astronomical_unit", Args) =
             "1,5 unit" & U (16#103#) & U (16#21B#)
             & "i astronomice",
           "measure-unit skeleton localizes Romanian astronomical units");
   Assert (Rendered (Runtime, "lt", "measure_astronomical_unit", Args) =
             "1,5 astronominio vieneto",
           "measure-unit skeleton localizes Lithuanian astronomical units");
   Assert (Rendered (Runtime, "sl", "measure_astronomical_unit", Args) =
             "1,5 astronomske enote",
           "measure-unit skeleton localizes Slovenian astronomical units");
   Assert (Rendered (Runtime, "pl", "measure_astronomical_unit", Args) =
             "1,5 jednostki astronomicznej",
           "measure-unit skeleton localizes Polish astronomical units");
   Assert (Rendered (Runtime, "cs", "measure_astronomical_unit", Args) =
             "1,5 astronomick" & U (16#E9#) & " jednotky",
           "measure-unit skeleton localizes Czech astronomical units");
   Assert (Rendered (Runtime, "ru", "measure_astronomical_unit", Args) =
             "1,5 "
             & UTF8 ([16#430#, 16#441#, 16#442#, 16#440#, 16#43E#,
                       16#43D#, 16#43E#, 16#43C#, 16#438#, 16#447#,
                       16#435#, 16#441#, 16#43A#, 16#43E#, 16#439#,
                       16#20#, 16#435#, 16#434#, 16#438#, 16#43D#,
                       16#438#, 16#446#, 16#44B#]),
           "measure-unit skeleton localizes Russian astronomical units");
   Assert (Rendered (Runtime, "de", "measure_light_year", Args) =
             "1,5 Lichtjahre",
           "measure-unit skeleton localizes German light years");
   Assert (Rendered (Runtime, "fr", "measure_light_year", Args) =
             "1,5 ann" & U (16#E9#) & "e-lumi" & U (16#E8#) & "re",
           "measure-unit skeleton localizes French light years");
   Assert (Rendered (Runtime, "es", "measure_light_year", Args) =
             "1,5 a" & U (16#F1#) & "os luz",
           "measure-unit skeleton localizes Spanish light years");
   Assert (Rendered (Runtime, "it", "measure_light_year", Args) =
             "1,5 anni luce",
           "measure-unit skeleton localizes Italian light years");
   Assert (Rendered (Runtime, "pt", "measure_light_year", Args) =
             "1,5 ano-luz",
           "measure-unit skeleton localizes Portuguese light years");
   Assert (Rendered (Runtime, "nl", "measure_light_year", Args) =
             "1,5 lichtjaar",
           "measure-unit skeleton localizes Dutch light years");
   Assert (Rendered (Runtime, "ro", "measure_light_year", Args) =
             "1,5 ani lumin" & U (16#103#),
           "measure-unit skeleton localizes Romanian light years");
   Assert (Rendered (Runtime, "lt", "measure_light_year", Args) =
             "1,5 " & U (16#161#) & "viesme" & U (16#10D#) & "io",
           "measure-unit skeleton localizes Lithuanian light years");
   Assert (Rendered (Runtime, "sl", "measure_light_year", Args) =
             "1,5 svetlobna leta",
           "measure-unit skeleton localizes Slovenian light years");
   Assert (Rendered (Runtime, "pl", "measure_light_year", Args) =
             "1,5 roku " & U (16#15B#) & "wietlnego",
           "measure-unit skeleton localizes Polish light years");
   Assert (Rendered (Runtime, "cs", "measure_light_year", Args) =
             "1,5 sv" & U (16#11B#) & "teln" & U (16#E9#) & "ho roku",
           "measure-unit skeleton localizes Czech light years");
   Assert (Rendered (Runtime, "ru", "measure_light_year", Args) =
             "1,5 " & UTF8 ([16#441#, 16#432#, 16#435#, 16#442#,
                               16#43E#, 16#432#, 16#43E#, 16#433#,
                               16#43E#, 16#20#, 16#433#, 16#43E#,
                               16#434#, 16#430#]),
           "measure-unit skeleton localizes Russian light years");
   Assert
     (Rendered (Runtime, "en", "measure_astronomical_unit_short", Args) =
        "1.5 au",
      "measure-unit skeleton accepts short length-astronomical-unit output");
   Assert (Rendered (Runtime, "en", "measure_light_year", Args) =
             "1.5 light years",
           "measure-unit skeleton accepts length-light-year");
   Assert (Rendered (Runtime, "de", "measure_parsec", Args) =
             "1,5 Parsec",
           "measure-unit skeleton localizes German parsecs");
   Assert (Rendered (Runtime, "fr", "measure_parsec", Args) =
             "1,5 parsec",
           "measure-unit skeleton localizes French parsecs");
   Assert (Rendered (Runtime, "es", "measure_parsec", Args) =
             "1,5 parsecs",
           "measure-unit skeleton localizes Spanish parsecs");
   Assert (Rendered (Runtime, "it", "measure_parsec", Args) =
             "1,5 parsec",
           "measure-unit skeleton localizes Italian parsecs");
   Assert (Rendered (Runtime, "pt", "measure_parsec", Args) =
             "1,5 parsec",
           "measure-unit skeleton localizes Portuguese parsecs");
   Assert (Rendered (Runtime, "nl", "measure_parsec", Args) =
             "1,5 parsecs",
           "measure-unit skeleton localizes Dutch parsecs");
   Assert (Rendered (Runtime, "ro", "measure_parsec", Args) =
             "1,5 parseci",
           "measure-unit skeleton localizes Romanian parsecs");
   Assert (Rendered (Runtime, "lt", "measure_parsec", Args) =
             "1,5 parseko",
           "measure-unit skeleton localizes Lithuanian parsecs");
   Assert (Rendered (Runtime, "sl", "measure_parsec", Args) =
             "1,5 parseki",
           "measure-unit skeleton localizes Slovenian parsecs");
   Assert (Rendered (Runtime, "pl", "measure_parsec", Args) =
             "1,5 parseka",
           "measure-unit skeleton localizes Polish parsecs");
   Assert (Rendered (Runtime, "cs", "measure_parsec", Args) =
             "1,5 parseku",
           "measure-unit skeleton localizes Czech parsecs");
   Assert (Rendered (Runtime, "ru", "measure_parsec", Args) =
             "1,5 " & UTF8 ([16#43F#, 16#430#, 16#440#, 16#441#,
                               16#435#, 16#43A#, 16#430#]),
           "measure-unit skeleton localizes Russian parsecs");
   Assert (Rendered (Runtime, "en", "measure_parsec_short", Args) =
             "1.5 pc",
           "measure-unit skeleton accepts short length-parsec output");
   Assert (Rendered (Runtime, "en", "unit_fathom_alias", Args) =
             "1.5 fathoms",
           "unit formatter accepts length-fathom alias");
   Assert (Rendered (Runtime, "de", "unit_fathom_alias", Args) =
             "1,5 Faden",
           "unit formatter localizes German fathoms");
   Assert (Rendered (Runtime, "fr", "unit_fathom_alias", Args) =
             "1,5 brasse",
           "unit formatter localizes French fathoms");
   Assert (Rendered (Runtime, "es", "unit_fathom_alias", Args) =
             "1,5 brazas",
           "unit formatter localizes Spanish fathoms");
   Assert (Rendered (Runtime, "it", "unit_fathom_alias", Args) =
             "1,5 braccia",
           "unit formatter localizes Italian fathoms");
   Assert (Rendered (Runtime, "pt", "unit_fathom_alias", Args) =
             "1,5 bra" & U (16#E7#) & "a",
           "unit formatter localizes Portuguese fathoms");
   Assert (Rendered (Runtime, "nl", "unit_fathom_alias", Args) =
             "1,5 vadems",
           "unit formatter localizes Dutch fathoms");
   Assert (Rendered (Runtime, "ro", "unit_fathom_alias", Args) =
             "1,5 fathomi",
           "unit formatter localizes Romanian fathoms");
   Assert (Rendered (Runtime, "lt", "unit_fathom_alias", Args) =
             "1,5 fadomo",
           "unit formatter localizes Lithuanian fathoms");
   Assert (Rendered (Runtime, "sl", "unit_fathom_alias", Args) =
             "1,5 se" & U (16#17E#) & "nji",
           "unit formatter localizes Slovenian fathoms");
   Assert (Rendered (Runtime, "pl", "unit_fathom_alias", Args) =
             "1,5 s" & U (16#105#) & U (16#17C#) & "nia",
           "unit formatter localizes Polish fathoms");
   Assert (Rendered (Runtime, "cs", "unit_fathom_alias", Args) =
             "1,5 s" & U (16#E1#) & "hu",
           "unit formatter localizes Czech fathoms");
   Assert (Rendered (Runtime, "ru", "unit_fathom_alias", Args) =
             "1,5 " & UTF8 ([16#43C#, 16#43E#, 16#440#, 16#441#,
                               16#43A#, 16#43E#, 16#439#, 16#20#,
                               16#441#, 16#430#, 16#436#, 16#435#,
                               16#43D#, 16#438#]),
           "unit formatter localizes Russian fathoms");
   Assert (Rendered (Runtime, "en", "measure_furlong_short", Args) =
             "1.5 fur",
           "measure-unit skeleton accepts short length-furlong output");
   Assert (Rendered (Runtime, "en", "measure_pixel", Args) =
             "1.5 pixels",
           "measure-unit skeleton accepts length-pixel");
   Assert (Rendered (Runtime, "de", "measure_pixel", Args) =
             "1,5 Pixel",
           "measure-unit skeleton localizes German pixels");
   Assert (Rendered (Runtime, "fr", "measure_pixel", Args) =
             "1,5 pixel",
           "measure-unit skeleton localizes French pixels");
   Assert (Rendered (Runtime, "es", "measure_pixel", Args) =
             "1,5 p" & U (16#ED#) & "xeles",
           "measure-unit skeleton localizes Spanish pixels");
   Assert (Rendered (Runtime, "it", "measure_pixel", Args) =
             "1,5 pixel",
           "measure-unit skeleton localizes Italian pixels");
   Assert (Rendered (Runtime, "pt", "measure_pixel", Args) =
             "1,5 pixel",
           "measure-unit skeleton localizes Portuguese pixels");
   Assert (Rendered (Runtime, "nl", "measure_pixel", Args) =
             "1,5 pixels",
           "measure-unit skeleton localizes Dutch pixels");
   Assert (Rendered (Runtime, "ro", "measure_pixel", Args) =
             "1,5 pixeli",
           "measure-unit skeleton localizes Romanian pixels");
   Assert (Rendered (Runtime, "lt", "measure_pixel", Args) =
             "1,5 pikselio",
           "measure-unit skeleton localizes Lithuanian pixels");
   Assert (Rendered (Runtime, "sl", "measure_pixel", Args) =
             "1,5 piksli",
           "measure-unit skeleton localizes Slovenian pixels");
   Assert (Rendered (Runtime, "pl", "measure_pixel", Args) =
             "1,5 piksela",
           "measure-unit skeleton localizes Polish pixels");
   Assert (Rendered (Runtime, "cs", "measure_pixel", Args) =
             "1,5 pixelu",
           "measure-unit skeleton localizes Czech pixels");
   Assert (Rendered (Runtime, "ru", "measure_pixel", Args) =
             "1,5 " & UTF8 ([16#43F#, 16#438#, 16#43A#, 16#441#,
                               16#435#, 16#43B#, 16#44F#]),
           "measure-unit skeleton localizes Russian pixels");
   Assert (Rendered (Runtime, "en", "measure_point_short", Args) =
             "1.5 pt",
           "measure-unit skeleton accepts short length-point output");
   Assert (Rendered (Runtime, "de", "measure_point", Args) =
             "1,5 DTP-Punkte",
           "measure-unit skeleton localizes German points");
   Assert (Rendered (Runtime, "en", "measure_solar_radius", Args) =
             "1.5 solar radii",
           "measure-unit skeleton accepts length-solar-radius");
   Assert (Rendered (Runtime, "de", "measure_solar_radius", Args) =
             "1,5 Sonnenradien",
           "measure-unit skeleton localizes German solar radii");
   Assert (Rendered (Runtime, "fr", "measure_solar_radius", Args) =
             "1,5 rayon solaire",
           "measure-unit skeleton localizes French solar radii");
   Assert (Rendered (Runtime, "es", "measure_solar_radius", Args) =
             "1,5 radios solares",
           "measure-unit skeleton localizes Spanish solar radii");
   Assert (Rendered (Runtime, "it", "measure_solar_radius", Args) =
             "1,5 raggi solari",
           "measure-unit skeleton localizes Italian solar radii");
   Assert (Rendered (Runtime, "pt", "measure_solar_radius", Args) =
             "1,5 raio solar",
           "measure-unit skeleton localizes Portuguese solar radii");
   Assert (Rendered (Runtime, "nl", "measure_solar_radius", Args) =
             "1,5 solar radii",
           "measure-unit skeleton localizes Dutch solar radii");
   Assert (Rendered (Runtime, "ro", "measure_solar_radius", Args) =
             "1,5 raze solare",
           "measure-unit skeleton localizes Romanian solar radii");
   Assert (Rendered (Runtime, "lt", "measure_solar_radius", Args) =
             "1,5 R" & U (16#2609#),
           "measure-unit skeleton localizes Lithuanian solar radii");
   Assert (Rendered (Runtime, "sl", "measure_solar_radius", Args) =
             "1,5 polmeri sonca",
           "measure-unit skeleton localizes Slovenian solar radii");
   Assert (Rendered (Runtime, "pl", "measure_solar_radius", Args) =
             "1,5 promienia S" & U (16#142#) & "o" & U (16#144#) & "ca",
           "measure-unit skeleton localizes Polish solar radii");
   Assert (Rendered (Runtime, "cs", "measure_solar_radius", Args) =
             "1,5 polom" & U (16#11B#) & "ru Slunce",
           "measure-unit skeleton localizes Czech solar radii");
   Assert (Rendered (Runtime, "ru", "measure_solar_radius", Args) =
             "1,5 "
             & UTF8 ([16#441#, 16#43E#, 16#43B#, 16#43D#, 16#435#,
                       16#447#, 16#43D#, 16#43E#, 16#433#, 16#43E#,
                       16#20#, 16#440#, 16#430#, 16#434#, 16#438#,
                       16#443#, 16#441#, 16#430#]),
           "measure-unit skeleton localizes Russian solar radii");
   I18N.Arguments.Set (Args, "volume", "1");
   Assert (Rendered (Runtime, "en", "measure_liter", Args) = "1 liter",
           "measure-unit skeleton accepts volume-liter");
   Assert (Rendered (Runtime, "fr", "measure_liter", Args) = "1 litre",
           "measure-unit skeleton localizes French liters");
   I18N.Arguments.Set (Args, "volume", "2");
   Assert (Rendered (Runtime, "es", "measure_liter", Args) = "2 litros",
           "measure-unit skeleton localizes Spanish liters");
   Assert (Rendered (Runtime, "lt", "measure_liter", Args) = "2 litrai",
           "measure-unit skeleton localizes Lithuanian liters");
   Assert (Rendered (Runtime, "en", "measure_litre_short", Args) = "2 L",
           "measure-unit skeleton accepts volume-litre alias");
   Assert (Rendered (Runtime, "en", "measure_milliliter", Args) =
             "2 milliliters",
           "measure-unit skeleton accepts volume-milliliter");
   Assert (Rendered (Runtime, "fr", "measure_millilitre", Args) =
             "2 millilitres",
           "measure-unit skeleton accepts volume-millilitre alias");
   Assert (Rendered (Runtime, "en", "measure_gallon_short", Args) =
             "2 gal",
           "measure-unit skeleton accepts short volume-gallon output");
   Assert (Rendered (Runtime, "en", "unit_cup_alias", Args) =
             "2 cups",
           "unit formatter accepts volume-cup alias");
   Assert (Rendered (Runtime, "en", "unit_tablespoon_alias", Args) =
             "2 tablespoons",
           "unit formatter accepts volume-tablespoon alias");
   Assert (Rendered (Runtime, "en", "unit_teaspoon", Args) =
             "2 teaspoons",
           "unit formatter accepts direct teaspoon unit");
   Assert (Rendered (Runtime, "de", "unit_cup_alias", Args) =
             "2 Tassen",
           "unit formatter localizes German cups");
   Assert (Rendered (Runtime, "fr", "unit_cup_alias", Args) =
             "2 tasses",
           "unit formatter localizes French cups");
   Assert (Rendered (Runtime, "es", "unit_cup_alias", Args) =
             "2 tazas",
           "unit formatter localizes Spanish cups");
   Assert (Rendered (Runtime, "it", "unit_cup_alias", Args) =
             "2 tazze",
           "unit formatter localizes Italian cups");
   Assert (Rendered (Runtime, "pt", "unit_cup_alias", Args) =
             "2 x" & U (16#ED#) & "caras",
           "unit formatter localizes Portuguese cups");
   Assert (Rendered (Runtime, "nl", "unit_cup_alias", Args) =
             "2 cup",
           "unit formatter localizes Dutch cups");
   Assert (Rendered (Runtime, "ro", "unit_cup_alias", Args) =
             "2 c" & U (16#103#) & "ni",
           "unit formatter localizes Romanian cups");
   Assert (Rendered (Runtime, "lt", "unit_cup_alias", Args) =
             "2 stiklin" & U (16#117#) & "s",
           "unit formatter localizes Lithuanian cups");
   Assert (Rendered (Runtime, "sl", "unit_cup_alias", Args) =
             "2 skodelici",
           "unit formatter localizes Slovenian cups");
   Assert (Rendered (Runtime, "pl", "unit_cup_alias", Args) =
             "2 " & U (16#107#) & "wier" & U (16#107#) & "kwarty ameryka" &
             U (16#144#) & "skie",
           "unit formatter localizes Polish cups");
   Assert (Rendered (Runtime, "cs", "unit_cup_alias", Args) =
             "2 " & U (16#161#) & U (16#E1#) & "lky",
           "unit formatter localizes Czech cups");
   Assert (Rendered (Runtime, "ru", "unit_cup_alias", Args) =
             "2 " & UTF8 ([16#430#, 16#43C#, 16#435#, 16#440#, 16#2E#,
                            16#20#, 16#447#, 16#430#, 16#448#, 16#43A#,
                            16#438#]),
           "unit formatter localizes Russian cups");
   Assert (Rendered (Runtime, "en", "measure_fluid_ounce", Args) =
             "2 fluid ounces",
           "measure-unit skeleton accepts volume-fluid-ounce");
   Assert (Rendered (Runtime, "en", "measure_tablespoon_short", Args) =
             "2 tbsp",
           "measure-unit skeleton accepts short volume-tablespoon output");
   Assert (Rendered (Runtime, "en", "measure_teaspoon", Args) =
             "2 teaspoons",
           "measure-unit skeleton accepts volume-teaspoon");
   Assert (Rendered (Runtime, "de", "measure_fluid_ounce", Args) =
             "2 Fl" & U (16#FC#) & "ssigunzen",
           "measure-unit skeleton localizes German fluid ounces");
   Assert (Rendered (Runtime, "fr", "measure_fluid_ounce", Args) =
             "2 onces liquides",
           "measure-unit skeleton localizes French fluid ounces");
   Assert (Rendered (Runtime, "es", "measure_fluid_ounce", Args) =
             "2 onzas l" & U (16#ED#) & "quidas",
           "measure-unit skeleton localizes Spanish fluid ounces");
   Assert (Rendered (Runtime, "it", "measure_fluid_ounce", Args) =
             "2 once liquide",
           "measure-unit skeleton localizes Italian fluid ounces");
   Assert (Rendered (Runtime, "pt", "measure_fluid_ounce", Args) =
             "2 on" & U (16#E7#) & "as fluidas",
           "measure-unit skeleton localizes Portuguese fluid ounces");
   Assert (Rendered (Runtime, "nl", "measure_fluid_ounce", Args) =
             "2 fluid ounce",
           "measure-unit skeleton localizes Dutch fluid ounces");
   Assert (Rendered (Runtime, "ro", "measure_fluid_ounce", Args) =
             "2 uncii lichide",
           "measure-unit skeleton localizes Romanian fluid ounces");
   Assert (Rendered (Runtime, "lt", "measure_fluid_ounce", Args) =
             "2 skys" & U (16#10D#) & "io uncijos",
           "measure-unit skeleton localizes Lithuanian fluid ounces");
   Assert (Rendered (Runtime, "sl", "measure_fluid_ounce", Args) =
             "2 teko" & U (16#10D#) & "i un" & U (16#10D#) & "i",
           "measure-unit skeleton localizes Slovenian fluid ounces");
   Assert (Rendered (Runtime, "pl", "measure_fluid_ounce", Args) =
             "2 uncje p" & U (16#142#) & "ynu ameryka" & U (16#144#) & "skie",
           "measure-unit skeleton localizes Polish fluid ounces");
   Assert (Rendered (Runtime, "cs", "measure_fluid_ounce", Args) =
             "2 dut" & U (16#E9#) & " unce",
           "measure-unit skeleton localizes Czech fluid ounces");
   Assert (Rendered (Runtime, "ru", "measure_fluid_ounce", Args) =
             "2 " & UTF8 ([16#430#, 16#43C#, 16#435#, 16#440#]) & ". " &
             UTF8 ([16#436#, 16#438#, 16#434#, 16#43A#, 16#438#, 16#435#]) & " " &
             UTF8 ([16#443#, 16#43D#, 16#446#, 16#438#, 16#438#]),
           "measure-unit skeleton localizes Russian fluid ounces");
   Assert (Rendered (Runtime, "en", "measure_pint_short", Args) =
             "2 pt",
           "measure-unit skeleton accepts short volume-pint output");
   Assert (Rendered (Runtime, "en", "measure_quart", Args) =
             "2 quarts",
           "measure-unit skeleton accepts volume-quart");
   Assert (Rendered (Runtime, "de", "measure_quart", Args) =
             "2 Quart",
           "measure-unit skeleton localizes German quarts");
   Assert (Rendered (Runtime, "fr", "measure_quart", Args) =
             "2 quarts",
           "measure-unit skeleton localizes French quarts");
   Assert (Rendered (Runtime, "es", "measure_quart", Args) =
             "2 cuartos",
           "measure-unit skeleton localizes Spanish quarts");
   Assert (Rendered (Runtime, "it", "measure_quart", Args) =
             "2 quarti",
           "measure-unit skeleton localizes Italian quarts");
   Assert (Rendered (Runtime, "pt", "measure_quart", Args) =
             "2 quartos",
           "measure-unit skeleton localizes Portuguese quarts");
   Assert (Rendered (Runtime, "nl", "measure_quart", Args) =
             "2 quart",
           "measure-unit skeleton localizes Dutch quarts");
   Assert (Rendered (Runtime, "ro", "measure_quart", Args) =
             "2 quarte",
           "measure-unit skeleton localizes Romanian quarts");
   Assert (Rendered (Runtime, "lt", "measure_quart", Args) =
             "2 kvortos",
           "measure-unit skeleton localizes Lithuanian quarts");
   Assert (Rendered (Runtime, "sl", "measure_quart", Args) =
             "2 " & U (16#10D#) & "etrtini",
           "measure-unit skeleton localizes Slovenian quarts");
   Assert (Rendered (Runtime, "pl", "measure_quart", Args) =
             "2 kwarty ameryka" & U (16#144#) & "skie",
           "measure-unit skeleton localizes Polish quarts");
   Assert (Rendered (Runtime, "cs", "measure_quart", Args) =
             "2 kvarty",
           "measure-unit skeleton localizes Czech quarts");
   Assert (Rendered (Runtime, "ru", "measure_quart", Args) =
             "2 " & UTF8 ([16#430#, 16#43C#, 16#435#, 16#440#]) & ". " &
             UTF8 ([16#43A#, 16#432#, 16#430#, 16#440#, 16#442#, 16#44B#]),
           "measure-unit skeleton localizes Russian quarts");
   Assert (Rendered (Runtime, "en", "unit_cubic_meter_short", Args) =
             "2 m" & U (16#B3#),
           "unit formatter accepts short volume-cubic-metre alias");
   Assert (Rendered (Runtime, "en", "unit_cubic_inch", Args) =
             "2 cubic inches",
           "unit formatter accepts volume-cubic-inch alias");
   Assert (Rendered (Runtime, "en", "unit_acre_foot_short", Args) =
             "2 ac ft",
           "unit formatter accepts short volume-acre-foot alias");
   Assert (Rendered (Runtime, "en", "measure_cubic_centimeter", Args) =
             "2 cubic centimeters",
           "measure-unit skeleton accepts volume-cubic-centimeter");
   Assert (Rendered (Runtime, "en", "measure_cubic_foot_short", Args) =
             "2 ft" & U (16#B3#),
           "measure-unit skeleton accepts short volume-cubic-foot");
   Assert (Rendered (Runtime, "en", "measure_cubic_yard", Args) =
             "2 cubic yards",
           "measure-unit skeleton accepts volume-cubic-yard");
   I18N.Arguments.Set (Args, "distance", "1.5");
   Assert (Rendered (Runtime, "en", "measure_per", Args) =
             "1.5 kilometers per hour",
           "measure-unit skeleton accepts per-measure-unit");
   Assert (Rendered (Runtime, "en-u-nu-beng", "measure_per", Args) =
             U (16#09E7#) & "." & U (16#09EB#)
             & " kilometers per hour",
           "measure-unit skeleton honors explicit numbering-system digits");
   Expect_Bounded
     ("en", "measure_per", "1.5 kilometers per hour",
      "bounded measure-unit rate formatting");
   Assert (Rendered (Runtime, "de", "measure_per", Args) =
             "1,5 Kilometer pro Stunde",
           "measure-unit skeleton localizes German per-unit output");
   Assert (Rendered (Runtime, "fr", "measure_per", Args) =
             "1,5 kilom" & U (16#E8#) & "tre par heure",
           "measure-unit skeleton localizes French per-unit output");
   Assert (Rendered (Runtime, "es", "measure_per", Args) =
             "1,5 kil" & U (16#F3#) & "metros por hora",
           "measure-unit skeleton localizes Spanish per-unit output");
   Assert (Rendered (Runtime, "it", "measure_per", Args) =
             "1,5 chilometri al ora",
           "measure-unit skeleton localizes Italian per-unit output");
   Assert (Rendered (Runtime, "pt", "measure_per", Args) =
             "1,5 quil" & U (16#F4#) & "metro por hora",
           "measure-unit skeleton localizes Portuguese per-unit output");
   Assert (Rendered (Runtime, "nl", "measure_per", Args) =
             "1,5 kilometer per uur",
           "measure-unit skeleton localizes Dutch per-unit output");
   Assert (Rendered (Runtime, "ro", "measure_per", Args) =
             "1,5 kilometri pe or" & U (16#103#),
           "measure-unit skeleton localizes Romanian per-unit output");
   Assert (Rendered (Runtime, "lt", "measure_per", Args) =
             "1,5 kilometro/valanda",
           "measure-unit skeleton localizes Lithuanian per-unit output");
   Assert (Rendered (Runtime, "sl", "measure_per", Args) =
             "1,5 kilometri/ura",
           "measure-unit skeleton localizes Slovenian per-unit output");
   Assert (Rendered (Runtime, "pl", "measure_per", Args) =
             "1,5 kilometra na godzina",
           "measure-unit skeleton localizes Polish per-unit output");
   Assert (Rendered (Runtime, "cs", "measure_per", Args) =
             "1,5 kilometru/hodina",
           "measure-unit skeleton localizes Czech per-unit output");
   Assert (Rendered (Runtime, "ru", "measure_per", Args) =
             "1,5 "
             & UTF8 ([16#43A#, 16#438#, 16#43B#, 16#43E#, 16#43C#,
                       16#435#, 16#442#, 16#440#, 16#430#])
             & "/" & UTF8 ([16#447#, 16#430#, 16#441#]),
           "measure-unit skeleton localizes Russian per-unit output");
   Assert (Rendered (Runtime, "ar", "measure_per", Args) =
             U (16#0661#) & U (16#066B#) & U (16#0665#) & " "
             & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#, 16#645#,
                       16#62A#, 16#631#])
             & " " & UTF8 ([16#644#, 16#643#, 16#644#]) & " "
             & UTF8 ([16#633#, 16#627#, 16#639#, 16#629#]),
           "measure-unit skeleton localizes Arabic per-unit output");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "measure_per", Args) =
             "1" & U (16#066B#) & "5 "
             & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#, 16#645#,
                       16#62A#, 16#631#])
             & " " & UTF8 ([16#644#, 16#643#, 16#644#]) & " "
             & UTF8 ([16#633#, 16#627#, 16#639#, 16#629#]),
           "measure-unit skeleton honors explicit Latin digits");
   Assert (Rendered (Runtime, "ja", "measure_per", Args) =
             "1.5" & UTF8 ([16#30AD#, 16#30ED#, 16#30E1#, 16#30FC#,
                              16#30C8#, 16#30EB#])
             & U (16#6BCE#) & UTF8 ([16#6642#, 16#9593#]),
           "measure-unit skeleton localizes Japanese per-unit output");
   Assert (Rendered (Runtime, "zh", "measure_per", Args) =
             "1.5" & UTF8 ([16#516C#, 16#91CC#])
             & "/" & UTF8 ([16#5C0F#, 16#65F6#]),
           "measure-unit skeleton localizes Chinese per-unit output");
   Assert (Rendered (Runtime, "ko", "measure_per", Args) =
             "1.5" & UTF8 ([16#D0AC#, 16#B85C#, 16#BBF8#, 16#D130#])
             & "/" & UTF8 ([16#C2DC#, 16#AC04#]),
           "measure-unit skeleton localizes Korean per-unit output");
   Assert (Rendered (Runtime, "tr", "measure_per", Args) =
             "1,5 kilometre/saat",
           "measure-unit skeleton uses source-backed Turkish per separator");
   Assert (Rendered (Runtime, "da", "measure_per", Args) =
             "1,5 kilometer pr. time",
           "measure-unit skeleton uses source-backed Danish per separator");
   Assert (Rendered (Runtime, "hi", "measure_per", Args) =
             "1.5 "
             & UTF8 ([16#915#, 16#93F#, 16#932#, 16#94B#, 16#92E#, 16#940#,
                       16#91F#, 16#930#])
             & " "
             & UTF8 ([16#92A#, 16#94D#, 16#930#, 16#924#, 16#93F#])
             & " " & UTF8 ([16#918#, 16#902#, 16#91F#, 16#93E#]),
           "measure-unit skeleton uses source-backed Hindi per separator");
   Assert (Rendered (Runtime, "el", "measure_per", Args) =
             "1,5 "
             & UTF8 ([16#3C7#, 16#3B9#, 16#3BB#, 16#3B9#, 16#3CC#, 16#3BC#,
                       16#3B5#, 16#3C4#, 16#3C1#, 16#3B1#])
             & " " & UTF8 ([16#3B1#, 16#3BD#, 16#3AC#])
             & " " & UTF8 ([16#3CE#, 16#3C1#, 16#3B1#]),
           "measure-unit skeleton uses source-backed Greek per separator");
   Assert (Rendered (Runtime, "he", "measure_per", Args) =
             "1.5 "
             & UTF8 ([16#5E7#, 16#5D9#, 16#5DC#, 16#5D5#, 16#5DE#, 16#5D8#,
                       16#5E8#, 16#5D9#, 16#5DD#])
             & " " & UTF8 ([16#5DC#, 16#5E9#, 16#5E2#, 16#5D4#]),
           "measure-unit skeleton uses source-backed Hebrew per separator");
   Assert (Rendered (Runtime, "en", "measure_per_short", Args) =
             "1.5 km/hr",
           "short measure-unit skeleton renders slash per-unit form");
   I18N.Arguments.Set (Args, "weight", "2");
   Assert (Rendered (Runtime, "en", "measure_narrow", Args) = "2 kg",
           "measure-unit skeleton accepts mass units and narrow width");
   Assert (Rendered (Runtime, "en", "measure_narrow_slash", Args) =
             Rendered (Runtime, "en", "measure_narrow", Args),
           "measure-unit skeleton accepts unit-width/narrow");
   Assert (Rendered (Runtime, "sl", "measure_kilogram", Args) =
             "2 kilograma",
           "measure-unit skeleton localizes Slovenian kilograms");
   Assert (Rendered (Runtime, "en", "unit_milligram_alias", Args) =
             "2 milligrams",
           "unit formatter accepts mass-milligram alias");
   Assert (Rendered (Runtime, "de", "unit_milligram_alias", Args) =
             "2 Milligramm",
           "unit formatter localizes German milligrams");
   Assert (Rendered (Runtime, "fr", "unit_milligram_alias", Args) =
             "2 milligrammes",
           "unit formatter localizes French milligrams");
   Assert (Rendered (Runtime, "es", "unit_milligram_alias", Args) =
             "2 miligramos",
           "unit formatter localizes Spanish milligrams");
   Assert (Rendered (Runtime, "it", "unit_milligram_alias", Args) =
             "2 milligrammi",
           "unit formatter localizes Italian milligrams");
   Assert (Rendered (Runtime, "pt", "unit_milligram_alias", Args) =
             "2 miligramas",
           "unit formatter localizes Portuguese milligrams");
   Assert (Rendered (Runtime, "nl", "unit_milligram_alias", Args) =
             "2 milligram",
           "unit formatter localizes Dutch milligrams");
   Assert (Rendered (Runtime, "ro", "unit_milligram_alias", Args) =
             "2 miligrame",
           "unit formatter localizes Romanian milligrams");
   Assert (Rendered (Runtime, "lt", "unit_milligram_alias", Args) =
             "2 miligramai",
           "unit formatter localizes Lithuanian milligrams");
   Assert (Rendered (Runtime, "sl", "unit_milligram_alias", Args) =
             "2 miligrama",
           "unit formatter localizes Slovenian milligrams");
   Assert (Rendered (Runtime, "pl", "unit_milligram_alias", Args) =
             "2 miligramy",
           "unit formatter localizes Polish milligrams");
   Assert (Rendered (Runtime, "cs", "unit_milligram_alias", Args) =
             "2 miligramy",
           "unit formatter localizes Czech milligrams");
   Assert (Rendered (Runtime, "ru", "unit_milligram_alias", Args) =
             "2 " &
             UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#433#, 16#440#, 16#430#, 16#43C#, 16#43C#, 16#430#]),
           "unit formatter localizes Russian milligrams");
   Assert (Rendered (Runtime, "en", "measure_milligram_short", Args) =
             "2 mg",
           "measure-unit skeleton accepts short mass-milligram output");
   Assert (Rendered (Runtime, "en", "measure_pound", Args) = "2 pounds",
           "measure-unit skeleton accepts mass-pound");
   Assert (Rendered (Runtime, "en", "measure_tonne_short", Args) = "2 t",
           "measure-unit skeleton accepts mass-tonne short output");
   Assert (Rendered (Runtime, "de", "measure_tonne", Args) =
             "2 Tonnen",
           "measure-unit skeleton localizes German tonnes");
   Assert (Rendered (Runtime, "fr", "measure_tonne", Args) =
             "2 tonnes",
           "measure-unit skeleton localizes French tonnes");
   Assert (Rendered (Runtime, "es", "measure_tonne", Args) =
             "2 toneladas",
           "measure-unit skeleton localizes Spanish tonnes");
   Assert (Rendered (Runtime, "it", "measure_tonne", Args) =
             "2 tonnellate metriche",
           "measure-unit skeleton localizes Italian tonnes");
   Assert (Rendered (Runtime, "pt", "measure_tonne", Args) =
             "2 toneladas m" & U (16#E9#) & "tricas",
           "measure-unit skeleton localizes Portuguese tonnes");
   Assert (Rendered (Runtime, "nl", "measure_tonne", Args) =
             "2 metrische ton",
           "measure-unit skeleton localizes Dutch tonnes");
   Assert (Rendered (Runtime, "ro", "measure_tonne", Args) =
             "2 tone metrice",
           "measure-unit skeleton localizes Romanian tonnes");
   Assert (Rendered (Runtime, "lt", "measure_tonne", Args) =
             "2 metrin" & U (16#117#) & "s tonos",
           "measure-unit skeleton localizes Lithuanian tonnes");
   Assert (Rendered (Runtime, "sl", "measure_tonne", Args) =
             "2 metri" & U (16#10D#) & "ni toni",
           "measure-unit skeleton localizes Slovenian tonnes");
   Assert (Rendered (Runtime, "pl", "measure_tonne", Args) =
             "2 tony",
           "measure-unit skeleton localizes Polish tonnes");
   Assert (Rendered (Runtime, "cs", "measure_tonne", Args) =
             "2 tuny",
           "measure-unit skeleton localizes Czech tonnes");
   Assert (Rendered (Runtime, "ru", "measure_tonne", Args) =
             "2 " & UTF8 ([16#442#, 16#43E#, 16#43D#, 16#43D#,
                            16#44B#]),
           "measure-unit skeleton localizes Russian tonnes");
   Assert (Rendered (Runtime, "es", "measure_ounce", Args) = "2 onzas",
           "measure-unit skeleton localizes Spanish ounces");
   Assert (Rendered (Runtime, "en", "unit_stone_alias", Args) =
             "2 stones",
           "unit formatter accepts mass-stone alias");
   Assert (Rendered (Runtime, "de", "unit_stone_alias", Args) =
             "2 Stones",
           "unit formatter localizes German stones");
   Assert (Rendered (Runtime, "fr", "unit_stone_alias", Args) =
             "2 stones",
           "unit formatter localizes French stones");
   Assert (Rendered (Runtime, "es", "unit_stone_alias", Args) =
             "2 stones",
           "unit formatter localizes Spanish stones");
   Assert (Rendered (Runtime, "it", "unit_stone_alias", Args) =
             "2 stone",
           "unit formatter localizes Italian stones");
   Assert (Rendered (Runtime, "pt", "unit_stone_alias", Args) =
             "2 stones",
           "unit formatter localizes Portuguese stones");
   Assert (Rendered (Runtime, "nl", "unit_stone_alias", Args) =
             "2 stone",
           "unit formatter localizes Dutch stones");
   Assert (Rendered (Runtime, "ro", "unit_stone_alias", Args) =
             "2 stone",
           "unit formatter localizes Romanian stones");
   Assert (Rendered (Runtime, "lt", "unit_stone_alias", Args) =
             "2 stonai",
           "unit formatter localizes Lithuanian stones");
   Assert (Rendered (Runtime, "sl", "unit_stone_alias", Args) =
             "2 stona",
           "unit formatter localizes Slovenian stones");
   Assert (Rendered (Runtime, "pl", "unit_stone_alias", Args) =
             "2 kamienie",
           "unit formatter localizes Polish stones");
   Assert (Rendered (Runtime, "cs", "unit_stone_alias", Args) =
             "2 kameny",
           "unit formatter localizes Czech stones");
   Assert (Rendered (Runtime, "ru", "unit_stone_alias", Args) =
             "2 " & UTF8 ([16#441#, 16#442#, 16#43E#, 16#443#, 16#43D#, 16#430#]),
           "unit formatter localizes Russian stones");
   Assert (Rendered (Runtime, "en", "measure_carat_short", Args) =
             "2 CD",
           "measure-unit skeleton accepts short mass-carat output");
   I18N.Arguments.Set (Args, "elapsed", "2");
   Assert (Rendered (Runtime, "en", "measure_millisecond", Args) =
             "2 milliseconds",
           "measure-unit skeleton accepts duration-millisecond");
   Assert (Rendered (Runtime, "en", "measure_microsecond", Args) =
             "2 microseconds",
           "measure-unit skeleton accepts duration-microsecond");
   Assert (Rendered (Runtime, "en", "measure_nanosecond_short", Args) =
             "2 ns",
           "measure-unit skeleton accepts short duration-nanosecond output");
   Assert (Rendered (Runtime, "en", "measure_fortnight_short", Args) =
             "2 fw",
           "measure-unit skeleton accepts short duration-fortnight output");
   I18N.Arguments.Set (Args, "area", "12.5");
   Assert (Rendered (Runtime, "en", "measure_square_meter_short", Args) =
             "12.5 m" & U (16#B2#),
           "measure-unit skeleton accepts area-square-meter short output");
   Assert (Rendered (Runtime, "en", "measure_square_kilometre", Args) =
             "12.5 square kilometers",
           "measure-unit skeleton accepts British area-square-kilometre");
   Assert (Rendered (Runtime, "en", "unit_acre_alias", Args) =
             "12.5 acres",
           "unit formatter accepts area-acre alias");
   Assert (Rendered (Runtime, "en", "measure_acre_short", Args) =
             "12.5 ac",
           "measure-unit skeleton accepts short area-acre output");
   Assert (Rendered (Runtime, "en", "measure_hectare", Args) =
             "12.5 hectares",
           "measure-unit skeleton accepts area-hectare");
   I18N.Arguments.Set (Args, "area", "1");
   Assert (Rendered (Runtime, "de", "unit_acre_alias", Args) =
             "1 Acre",
           "unit formatter uses source-backed German acre one form");
   Assert (Rendered (Runtime, "it", "unit_acre_alias", Args) =
             "1 acro",
           "unit formatter uses source-backed Italian acre one form");
   Assert (Rendered (Runtime, "pt", "unit_acre_alias", Args) =
             "1 acre",
           "unit formatter uses source-backed Portuguese acre one form");
   Assert (Rendered (Runtime, "nl", "unit_acre_alias", Args) =
             "1 acre",
           "unit formatter uses source-backed Dutch acre one form");
   Assert (Rendered (Runtime, "ro", "unit_acre_alias", Args) =
             "1 acru",
           "unit formatter uses source-backed Romanian acre one form");
   Assert (Rendered (Runtime, "lt", "unit_acre_alias", Args) =
             "1 akras",
           "unit formatter uses source-backed Lithuanian acre one form");
   Assert (Rendered (Runtime, "sl", "unit_acre_alias", Args) =
             "1 aker",
           "unit formatter uses source-backed Slovenian acre one form");
   Assert (Rendered (Runtime, "pl", "unit_acre_alias", Args) =
             "1 akr",
           "unit formatter uses source-backed Polish acre one form");
   Assert (Rendered (Runtime, "cs", "unit_acre_alias", Args) =
             "1 akr",
           "unit formatter uses source-backed Czech acre one form");
   Assert (Rendered (Runtime, "ru", "unit_acre_alias", Args) =
             "1 " & UTF8 ([16#430#, 16#43A#, 16#440#]),
           "unit formatter uses source-backed Russian acre one form");
   Assert (Rendered (Runtime, "ar", "unit_acre_alias", Args) =
             U (16#661#) & " " & UTF8 ([16#641#, 16#62F#, 16#627#, 16#646#]),
           "unit formatter uses source-backed Arabic acre one form");
   Assert (Rendered (Runtime, "ja", "unit_acre_alias", Args) =
             "1" & UTF8 ([16#30A8#, 16#30FC#, 16#30AB#, 16#30FC#]),
           "unit formatter uses source-backed Japanese acre one form");
   Assert (Rendered (Runtime, "zh", "unit_acre_alias", Args) =
             "1" & UTF8 ([16#82F1#, 16#4EA9#]),
           "unit formatter uses source-backed Chinese acre one form");
   Assert (Rendered (Runtime, "ko", "unit_acre_alias", Args) =
             "1" & UTF8 ([16#C5D0#, 16#C774#, 16#CEE4#]),
           "unit formatter uses source-backed Korean acre one form");
   I18N.Arguments.Set (Args, "area", "12.5");
   Assert (Rendered (Runtime, "en", "measure_square_foot", Args) =
             "12.5 square feet",
           "measure-unit skeleton accepts area-square-foot");
   Assert (Rendered (Runtime, "en", "unit_square_centimeter_short", Args) =
             "12.5 cm" & U (16#B2#),
           "unit formatter accepts short area-square-centimetre alias");
   Assert (Rendered (Runtime, "en", "unit_square_yard", Args) =
             "12.5 square yards",
           "unit formatter accepts area-square-yard alias");
   Assert (Rendered (Runtime, "en", "measure_square_inch_short", Args) =
             "12.5 in" & U (16#B2#),
           "measure-unit skeleton accepts short area-square-inch");
   Assert (Rendered (Runtime, "de", "measure_square_foot", Args) =
             "12,5 Quadratfu" & U (16#DF#),
           "measure-unit skeleton localizes German square feet");
   Assert (Rendered (Runtime, "fr", "measure_square_foot", Args) =
             "12,5 pieds carr" & U (16#E9#) & "s",
           "measure-unit skeleton localizes French square feet");
   Assert (Rendered (Runtime, "es", "measure_square_foot", Args) =
             "12,5 pies cuadrados",
           "measure-unit skeleton localizes Spanish square feet");
   Assert (Rendered (Runtime, "it", "measure_square_foot", Args) =
             "12,5 piedi quadrati",
           "measure-unit skeleton localizes Italian square feet");
   Assert (Rendered (Runtime, "pt", "measure_square_foot", Args) =
             "12,5 p" & U (16#E9#) & "s quadrados",
           "measure-unit skeleton localizes Portuguese square feet");
   Assert (Rendered (Runtime, "nl", "measure_square_foot", Args) =
             "12,5 vierkante voet",
           "measure-unit skeleton localizes Dutch square feet");
   Assert (Rendered (Runtime, "ro", "measure_square_foot", Args) =
             "12,5 picioare p" & U (16#103#) & "trate",
           "measure-unit skeleton localizes Romanian square feet");
   Assert (Rendered (Runtime, "lt", "measure_square_foot", Args) =
             "12,5 kvadratin" & U (16#117#) & "s p"
             & U (16#117#) & "dos",
           "measure-unit skeleton localizes Lithuanian square feet");
   Assert (Rendered (Runtime, "sl", "measure_square_foot", Args) =
             "12,5 kvadratni " & U (16#10D#) & "evlji",
           "measure-unit skeleton localizes Slovenian square feet");
   Assert (Rendered (Runtime, "pl", "measure_square_foot", Args) =
             "12,5 stopy kwadratowej",
           "measure-unit skeleton localizes Polish square feet");
   Assert (Rendered (Runtime, "cs", "measure_square_foot", Args) =
             "12,5 stopy " & U (16#10D#) & "tvere"
             & U (16#10D#) & "n" & U (16#ED#),
           "measure-unit skeleton localizes Czech square feet");
   Assert (Rendered (Runtime, "ru", "measure_square_foot", Args) =
             "12,5 " &
             UTF8 ([16#43A#, 16#432#, 16#430#, 16#434#, 16#440#, 16#430#,
                    16#442#, 16#43D#, 16#43E#, 16#433#, 16#43E#]) &
             " " & UTF8 ([16#444#, 16#443#, 16#442#, 16#430#]),
           "measure-unit skeleton localizes Russian square feet");
   Assert (Rendered (Runtime, "en", "measure_square_mile_short", Args) =
             "12.5 sq mi",
           "measure-unit skeleton accepts short area-square-mile output");
   Assert (Rendered (Runtime, "de", "measure_square_mile", Args) =
             "12,5 Quadratmeilen",
           "measure-unit skeleton localizes German square miles");
   Assert (Rendered (Runtime, "fr", "measure_square_mile", Args) =
             "12,5 milles carr" & U (16#E9#) & "s",
           "measure-unit skeleton localizes French square miles");
   Assert (Rendered (Runtime, "es", "measure_square_mile", Args) =
             "12,5 millas cuadradas",
           "measure-unit skeleton localizes Spanish square miles");
   Assert (Rendered (Runtime, "it", "measure_square_mile", Args) =
             "12,5 miglia quadrate",
           "measure-unit skeleton localizes Italian square miles");
   Assert (Rendered (Runtime, "pt", "measure_square_mile", Args) =
             "12,5 milhas quadradas",
           "measure-unit skeleton localizes Portuguese square miles");
   Assert (Rendered (Runtime, "nl", "measure_square_mile", Args) =
             "12,5 vierkante mijl",
           "measure-unit skeleton localizes Dutch square miles");
   Assert (Rendered (Runtime, "ro", "measure_square_mile", Args) =
             "12,5 mile p" & U (16#103#) & "trate",
           "measure-unit skeleton localizes Romanian square miles");
   Assert (Rendered (Runtime, "lt", "measure_square_mile", Args) =
             "12,5 kvadratin" & U (16#117#) & "s mylios",
           "measure-unit skeleton localizes Lithuanian square miles");
   Assert (Rendered (Runtime, "sl", "measure_square_mile", Args) =
             "12,5 kvadratne milje",
           "measure-unit skeleton localizes Slovenian square miles");
   Assert (Rendered (Runtime, "pl", "measure_square_mile", Args) =
             "12,5 mili kwadratowej",
           "measure-unit skeleton localizes Polish square miles");
   Assert (Rendered (Runtime, "cs", "measure_square_mile", Args) =
             "12,5 m" & U (16#ED#) & "le " & U (16#10D#)
             & "tvere" & U (16#10D#) & "n" & U (16#ED#),
           "measure-unit skeleton localizes Czech square miles");
   Assert (Rendered (Runtime, "ru", "measure_square_mile", Args) =
             "12,5 " &
             UTF8 ([16#43A#, 16#432#, 16#430#, 16#434#, 16#440#, 16#430#, 16#442#, 16#43D#, 16#43E#, 16#439#]) & " " &
             UTF8 ([16#43C#, 16#438#, 16#43B#, 16#438#]),
           "measure-unit skeleton localizes Russian square miles");
   Assert (Rendered (Runtime, "de", "measure_hectare", Args) =
             "12,5 Hektar",
           "measure-unit skeleton localizes German hectares");
   Assert (Rendered (Runtime, "fr", "measure_hectare", Args) =
             "12,5 hectares",
           "measure-unit skeleton localizes French hectares");
   Assert (Rendered (Runtime, "es", "measure_hectare", Args) =
             "12,5 hect" & U (16#E1#) & "reas",
           "measure-unit skeleton localizes Spanish hectares");
   Assert (Rendered (Runtime, "it", "measure_hectare", Args) =
             "12,5 ettari",
           "measure-unit skeleton localizes Italian hectares");
   Assert (Rendered (Runtime, "ru", "measure_hectare", Args) =
             "12,5 " & UTF8 ([16#433#, 16#435#, 16#43A#, 16#442#, 16#430#, 16#440#, 16#430#]),
           "measure-unit skeleton localizes Russian hectares");
   Assert (Rendered (Runtime, "ko", "measure_hectare", Args) =
             "12.5" & UTF8 ([16#D5E5#, 16#D0C0#, 16#B974#]),
           "measure-unit skeleton localizes Korean hectares");
   I18N.Arguments.Set (Args, "temperature", "21");
   Assert (Rendered (Runtime, "en", "measure_celsius", Args) =
             "21 degrees Celsius",
           "measure-unit skeleton accepts temperature-celsius");
   Assert (Rendered (Runtime, "en", "measure_fahrenheit_short", Args) =
             "21 " & U (16#B0#) & "F",
           "measure-unit skeleton accepts temperature-fahrenheit short output");
   I18N.Arguments.Set (Args, "angle", "90");
   Assert (Rendered (Runtime, "en", "measure_degree_short", Args) =
             "90 deg",
           "measure-unit skeleton accepts angle-degree short output");
   I18N.Arguments.Set (Args, "size", "2");
   Assert (Rendered (Runtime, "en", "measure_byte_short", Args) =
             "2 byte",
           "measure-unit skeleton accepts digital-byte short output");
   Assert (Rendered (Runtime, "en", "unit_bit_alias", Args) = "2 bits",
           "unit formatter accepts digital-bit alias");
   Assert (Rendered (Runtime, "de", "unit_bit_alias", Args) = "2 Bit",
           "unit formatter localizes German bits");
   Assert (Rendered (Runtime, "fr", "unit_bit_alias", Args) = "2 bits",
           "unit formatter localizes French bits");
   Assert (Rendered (Runtime, "es", "unit_bit_alias", Args) = "2 bits",
           "unit formatter localizes Spanish bits");
   Assert (Rendered (Runtime, "it", "unit_bit_alias", Args) = "2 bit",
           "unit formatter localizes Italian bits");
   Assert (Rendered (Runtime, "pt", "unit_bit_alias", Args) = "2 bits",
           "unit formatter localizes Portuguese bits");
   Assert (Rendered (Runtime, "nl", "unit_bit_alias", Args) = "2 bits",
           "unit formatter localizes Dutch bits");
   Assert (Rendered (Runtime, "ro", "unit_bit_alias", Args) =
             "2 bi" & U (16#21B#) & "i",
           "unit formatter localizes Romanian bits");
   Assert (Rendered (Runtime, "lt", "unit_bit_alias", Args) = "2 bitai",
           "unit formatter localizes Lithuanian bits");
   Assert (Rendered (Runtime, "sl", "unit_bit_alias", Args) = "2 bita",
           "unit formatter localizes Slovenian bits");
   Assert (Rendered (Runtime, "pl", "unit_bit_alias", Args) = "2 bity",
           "unit formatter localizes Polish bits");
   Assert (Rendered (Runtime, "cs", "unit_bit_alias", Args) = "2 bity",
           "unit formatter localizes Czech bits");
   Assert (Rendered (Runtime, "ru", "unit_bit_alias", Args) =
             "2 " & UTF8 ([16#431#, 16#438#, 16#442#, 16#430#]),
           "unit formatter localizes Russian bits");
   Assert (Rendered (Runtime, "en", "measure_gigabyte", Args) =
             "2 gigabytes",
           "measure-unit skeleton accepts digital-gigabyte");
   Assert (Rendered (Runtime, "en", "measure_megabit_short", Args) =
             "2 Mb",
           "measure-unit skeleton accepts short digital-megabit output");
   Assert (Rendered (Runtime, "en", "measure_gigabit", Args) =
             "2 gigabits",
           "measure-unit skeleton accepts digital-gigabit");
   Assert (Rendered (Runtime, "de", "measure_gigabit", Args) =
             "2 Gigabit",
           "measure-unit skeleton localizes German gigabits");
   Assert (Rendered (Runtime, "fr", "measure_gigabit", Args) =
             "2 gigabits",
           "measure-unit skeleton localizes French gigabits");
   Assert (Rendered (Runtime, "es", "measure_gigabit", Args) =
             "2 gigabits",
           "measure-unit skeleton localizes Spanish gigabits");
   Assert (Rendered (Runtime, "it", "measure_gigabit", Args) =
             "2 gigabit",
           "measure-unit skeleton localizes Italian gigabits");
   Assert (Rendered (Runtime, "pt", "measure_gigabit", Args) =
             "2 gigabits",
           "measure-unit skeleton localizes Portuguese gigabits");
   Assert (Rendered (Runtime, "nl", "measure_gigabit", Args) =
             "2 gigabits",
           "measure-unit skeleton localizes Dutch gigabits");
   Assert (Rendered (Runtime, "ro", "measure_gigabit", Args) =
             "2 gigabi" & U (16#21B#) & "i",
           "measure-unit skeleton localizes Romanian gigabits");
   Assert (Rendered (Runtime, "lt", "measure_gigabit", Args) =
             "2 gigabitai",
           "measure-unit skeleton localizes Lithuanian gigabits");
   Assert (Rendered (Runtime, "sl", "measure_gigabit", Args) =
             "2 gigabita",
           "measure-unit skeleton localizes Slovenian gigabits");
   Assert (Rendered (Runtime, "pl", "measure_gigabit", Args) =
             "2 gigabity",
           "measure-unit skeleton localizes Polish gigabits");
   Assert (Rendered (Runtime, "cs", "measure_gigabit", Args) =
             "2 gigabity",
           "measure-unit skeleton localizes Czech gigabits");
   Assert (Rendered (Runtime, "ru", "measure_gigabit", Args) =
             "2 " & UTF8 ([16#433#, 16#438#, 16#433#, 16#430#, 16#431#, 16#438#, 16#442#, 16#430#]),
           "measure-unit skeleton localizes Russian gigabits");
   Assert (Rendered (Runtime, "en", "measure_petabyte_short", Args) =
             "2 PB",
           "measure-unit skeleton accepts short digital-petabyte output");
   I18N.Arguments.Set (Args, "speed", "90");
   Assert
     (Rendered (Runtime, "en", "measure_kilometer_per_hour_short", Args) =
        "90 km/h",
      "measure-unit skeleton accepts speed-kilometer-per-hour short output");
   Assert (Rendered (Runtime, "en", "measure_mile_per_hour", Args) =
             "90 miles per hour",
           "measure-unit skeleton accepts speed-mile-per-hour");
   I18N.Arguments.Set (Args, "energy", "2");
   Assert (Rendered (Runtime, "en", "measure_joule", Args) =
             "2 joules",
           "measure-unit skeleton accepts energy-joule");
   Assert (Rendered (Runtime, "en", "measure_kilojoule_short", Args) =
             "2 kJ",
           "measure-unit skeleton accepts short energy-kilojoule output");
   Assert (Rendered (Runtime, "en", "measure_calorie", Args) =
             "2 calories",
           "measure-unit skeleton accepts energy-calorie");
   Assert (Rendered (Runtime, "en", "measure_kilocalorie_short", Args) =
             "2 kcal",
           "measure-unit skeleton accepts short energy-kilocalorie output");
   Assert (Rendered (Runtime, "en", "measure_kilowatt_hour", Args) =
             "2 kilowatt-hours",
           "measure-unit skeleton accepts energy-kilowatt-hour");
   Assert (Rendered (Runtime, "en", "measure_electronvolt_short", Args) =
             "2 eV",
           "measure-unit skeleton accepts short energy-electronvolt output");
   Assert (Rendered (Runtime, "en", "measure_btu", Args) =
             "2 British thermal units",
           "measure-unit skeleton accepts energy-british-thermal-unit");
   Assert (Rendered (Runtime, "en", "measure_therm_us", Args) =
             "2 US therms",
           "measure-unit skeleton accepts energy-therm-us");
   Assert (Rendered (Runtime, "de", "measure_kilowatt_hour", Args) =
             "2 Kilowattstunden",
           "measure-unit skeleton localizes German kilowatt-hours");
   Assert (Rendered (Runtime, "fr", "measure_joule", Args) =
             "2 joules",
           "measure-unit skeleton localizes French joules");
   Assert (Rendered (Runtime, "es", "measure_calorie", Args) =
             "2 calor" & U (16#ED#) & "as",
           "measure-unit skeleton localizes Spanish calories");
   Assert (Rendered (Runtime, "pt", "measure_kilowatt_hour", Args) =
             "2 quilowatts-hora",
           "measure-unit skeleton localizes Portuguese kilowatt-hours");
   Assert (Rendered (Runtime, "nl", "measure_joule", Args) =
             "2 joules",
           "measure-unit skeleton localizes Dutch joules");
   Assert (Rendered (Runtime, "pl", "measure_calorie", Args) =
             "2 kalorie",
           "measure-unit skeleton localizes Polish calories");
   Assert (Rendered (Runtime, "ru", "measure_joule", Args) =
             "2 " & UTF8 ([16#434#, 16#436#, 16#43E#, 16#443#, 16#43B#, 16#44F#]),
           "measure-unit skeleton localizes Russian joules");
   Assert (Rendered (Runtime, "ar", "measure_joule", Args) =
             U (16#0662#) & " "
             & UTF8 ([16#62C#, 16#648#, 16#644#]),
           "measure-unit skeleton localizes Arabic joules");
   Assert (Rendered (Runtime, "ar", "measure_kilowatt_hour", Args) =
             U (16#662#) & " " & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#]) & " " &
             UTF8 ([16#648#, 16#627#, 16#637#]) & "/" & UTF8 ([16#633#, 16#627#, 16#639#, 16#629#]),
           "measure-unit skeleton localizes Arabic kilowatt-hours");
   Assert (Rendered (Runtime, "ja", "measure_kilojoule", Args) =
             "2" & UTF8 ([16#30AD#, 16#30ED#, 16#30B8#,
                           16#30E5#, 16#30FC#, 16#30EB#]),
           "measure-unit skeleton localizes Japanese kilojoules");
   Assert (Rendered (Runtime, "ko", "measure_kilowatt_hour", Args) =
             "2" & UTF8 ([16#D0AC#, 16#B85C#, 16#C640#,
                           16#D2B8#, 16#C2DC#]),
           "measure-unit skeleton localizes Korean kilowatt-hours");
   Assert (Rendered (Runtime, "ru", "measure_calorie", Args) =
             "2 " & UTF8 ([16#43A#, 16#430#, 16#43B#, 16#43E#,
                            16#440#, 16#438#, 16#438#]),
           "measure-unit skeleton localizes Russian calories");
   Assert (Rendered (Runtime, "ja", "measure_calorie", Args) =
             "2" & UTF8 ([16#30AB#, 16#30ED#, 16#30EA#, 16#30FC#]),
           "measure-unit skeleton localizes Japanese calories");
   Assert (Rendered (Runtime, "ko", "measure_calorie", Args) =
             "2" & UTF8 ([16#CE7C#, 16#B85C#, 16#B9AC#]),
           "measure-unit skeleton localizes Korean calories");
   I18N.Arguments.Set (Args, "power", "1");
   Assert (Rendered (Runtime, "en", "unit_watt_alias", Args) =
             "1 watt",
           "unit formatter accepts power-watt alias");
   Assert (Rendered (Runtime, "es", "unit_watt_alias", Args) =
             "1 vatio",
           "unit formatter localizes Spanish power-watt alias");
   Assert (Rendered (Runtime, "ro", "unit_watt_alias", Args) =
             "1 watt",
           "unit formatter localizes Romanian power-watt alias");
   Assert (Rendered (Runtime, "ja", "unit_watt_alias", Args) =
             "1" & UTF8 ([16#30EF#, 16#30C3#, 16#30C8#]),
           "unit formatter localizes Japanese power-watt alias");
   I18N.Arguments.Set (Args, "power", "2");
   Assert (Rendered (Runtime, "en", "measure_kilowatt_short", Args) =
             "2 kW",
           "measure-unit skeleton accepts short power-kilowatt output");
   Assert (Rendered (Runtime, "ru", "measure_kilowatt", Args) =
             "2 " & UTF8 ([16#43A#, 16#438#, 16#43B#, 16#43E#, 16#432#, 16#430#, 16#442#, 16#442#, 16#430#]),
           "measure-unit skeleton localizes Russian kilowatts");
   Assert (Rendered (Runtime, "ar", "measure_kilowatt", Args) =
             U (16#0662#) & " "
             & UTF8 ([16#643#, 16#64A#, 16#644#, 16#648#,
                       16#648#, 16#627#, 16#637#]),
           "measure-unit skeleton localizes Arabic kilowatts");
   Assert (Rendered (Runtime, "ja", "measure_kilowatt", Args) =
             "2" & UTF8 ([16#30AD#, 16#30ED#, 16#30EF#,
                           16#30C3#, 16#30C8#]),
           "measure-unit skeleton localizes Japanese kilowatts");
   Assert (Rendered (Runtime, "ko", "measure_kilowatt", Args) =
             "2" & UTF8 ([16#D0AC#, 16#B85C#, 16#C640#, 16#D2B8#]),
           "measure-unit skeleton localizes Korean kilowatts");
   Assert (Rendered (Runtime, "cs", "measure_kilowatt", Args) =
             "2 kilowatty",
           "measure-unit skeleton localizes Czech kilowatts");
   I18N.Arguments.Set (Args, "frequency", "1");
   Assert (Rendered (Runtime, "en", "measure_hertz", Args) =
             "1 hertz",
           "measure-unit skeleton accepts frequency-hertz");
   I18N.Arguments.Set (Args, "frequency", "2");
   Assert (Rendered (Runtime, "en", "measure_kilohertz_short", Args) =
             "2 kHz",
           "measure-unit skeleton accepts short frequency-kilohertz output");
   Assert (Rendered (Runtime, "en", "measure_megahertz", Args) =
             "2 megahertz",
           "measure-unit skeleton accepts frequency-megahertz");
   Assert (Rendered (Runtime, "ru", "measure_megahertz", Args) =
             "2 " & UTF8 ([16#43C#, 16#435#, 16#433#, 16#430#,
                            16#433#, 16#435#, 16#440#, 16#446#,
                            16#430#]),
           "measure-unit skeleton localizes Russian megahertz");
   Assert (Rendered (Runtime, "ar", "measure_megahertz", Args) =
             U (16#662#) & " " & UTF8 ([16#645#, 16#64A#, 16#63A#, 16#627#]) & " " &
             UTF8 ([16#647#, 16#631#, 16#62A#, 16#632#]),
           "measure-unit skeleton localizes Arabic megahertz");
   Assert (Rendered (Runtime, "ja", "measure_megahertz", Args) =
             "2" & UTF8 ([16#30E1#, 16#30AC#, 16#30D8#,
                           16#30EB#, 16#30C4#]),
           "measure-unit skeleton localizes Japanese megahertz");
   Assert (Rendered (Runtime, "ko", "measure_megahertz", Args) =
             "2" & UTF8 ([16#BA54#, 16#AC00#, 16#D5E4#,
                           16#B974#, 16#CE20#]),
           "measure-unit skeleton localizes Korean megahertz");
   I18N.Arguments.Set (Args, "pressure", "1013");
   Assert (Rendered (Runtime, "en", "measure_hectopascal_short", Args) =
             "1013 hPa",
           "measure-unit skeleton accepts short pressure-hectopascal output");
   Assert (Rendered (Runtime, "en", "measure_pascal", Args) =
             "1013 pascals",
           "measure-unit skeleton accepts pressure-pascal");
   Assert (Rendered (Runtime, "en", "measure_kilopascal_short", Args) =
             "1013 kPa",
           "measure-unit skeleton accepts short pressure-kilopascal output");
   Assert (Rendered (Runtime, "en", "measure_millibar", Args) =
             "1013 millibars",
           "measure-unit skeleton accepts pressure-millibar");
   Assert (Rendered (Runtime, "de", "measure_millibar", Args) =
             "1013 Millibar",
           "measure-unit skeleton localizes German millibars");
   Assert (Rendered (Runtime, "sl", "measure_millibar", Args) =
             "1013 milibarov",
           "measure-unit skeleton localizes Slovenian millibars");
   Assert (Rendered (Runtime, "ru", "measure_millibar", Args) =
             "1013 " & UTF8 ([16#43C#, 16#438#, 16#43B#, 16#43B#, 16#438#, 16#431#, 16#430#, 16#440#]),
           "measure-unit skeleton localizes Russian millibars");
   Assert (Rendered (Runtime, "ar", "measure_millibar", Args) =
             UTF8 ([16#661#, 16#660#, 16#661#, 16#663#]) & " " & UTF8 ([16#645#, 16#644#, 16#64A#]) & " " &
             UTF8 ([16#628#, 16#627#, 16#631#]),
           "measure-unit skeleton localizes Arabic millibars");
   Assert (Rendered (Runtime, "ja", "measure_millibar", Args) =
             "1013" & UTF8 ([16#30DF#, 16#30EA#, 16#30D0#,
                              16#30FC#, 16#30EB#]),
           "measure-unit skeleton localizes Japanese millibars");
   Assert (Rendered (Runtime, "ko", "measure_millibar", Args) =
             "1013" & UTF8 ([16#BC00#, 16#B9AC#, 16#BC14#]),
           "measure-unit skeleton localizes Korean millibars");
   I18N.Arguments.Set (Args, "electric", "2");
   Assert (Rendered (Runtime, "en", "unit_ampere_alias", Args) =
             "2 amperes",
           "unit formatter accepts electric-ampere alias");
   Assert (Rendered (Runtime, "en", "measure_ampere_short", Args) =
             "2 A",
           "measure-unit skeleton accepts short electric-ampere output");
   Assert (Rendered (Runtime, "en", "measure_volt", Args) =
             "2 volts",
           "measure-unit skeleton accepts electric-volt");
   Assert (Rendered (Runtime, "en", "measure_ohm_short", Args) =
             "2 " & U (16#3A9#),
           "measure-unit skeleton accepts short electric-ohm output");
   I18N.Arguments.Set (Args, "light", "2");
   Assert (Rendered (Runtime, "en", "measure_lumen", Args) =
             "2 lumen",
           "measure-unit skeleton accepts light-lumen");
   Assert (Rendered (Runtime, "en", "measure_lux_short", Args) =
             "2 lx",
           "measure-unit skeleton accepts short light-lux output");
   I18N.Arguments.Set (Args, "share", "50");
   Assert (Rendered (Runtime, "en", "measure_percent", Args) =
             "50 percent",
           "measure-unit skeleton accepts concentr-percent alias");
   Assert (Rendered (Runtime, "fr", "measure_percent", Args) =
             "50 pour cent",
           "measure-unit skeleton localizes French percent");
   Assert (Rendered (Runtime, "lt", "measure_percent", Args) =
             "50 procentas",
           "measure-unit skeleton localizes Lithuanian percent");
   Assert (Rendered (Runtime, "zh", "measure_percent", Args) =
             "50%",
           "measure-unit skeleton localizes Chinese percent");
   Assert (Rendered (Runtime, "ru", "measure_percent", Args) =
             "50 " & UTF8 ([16#43F#, 16#440#, 16#43E#, 16#446#, 16#435#, 16#43D#, 16#442#, 16#43E#, 16#432#]),
           "measure-unit skeleton localizes Russian percent");
   Assert (Rendered (Runtime, "ar", "measure_percent", Args) =
             UTF8 ([16#665#, 16#660#]) & " " & U (16#66A#),
           "measure-unit skeleton localizes Arabic percent");
   Assert (Rendered (Runtime, "ja", "measure_percent", Args) =
             "50" & UTF8 ([16#30D1#, 16#30FC#, 16#30BB#,
                            16#30F3#, 16#30C8#]),
           "measure-unit skeleton localizes Japanese percent");
   Assert (Rendered (Runtime, "ko", "measure_percent", Args) =
             "50%",
           "measure-unit skeleton localizes Korean percent");
   Assert (Rendered (Runtime, "en", "measure_percent_short", Args) =
             "50 %",
           "measure-unit skeleton accepts direct percent short output");
   Assert (Rendered (Runtime, "en", "measure_permille", Args) =
             "50 permille",
           "measure-unit skeleton accepts concentr-permille");
   Assert (Rendered (Runtime, "en", "measure_permillion_short", Args) =
             "50 ppm",
           "measure-unit skeleton accepts short concentr-permillion");
   Assert (Rendered (Runtime, "en", "measure_portion", Args) =
             "50 portions",
           "measure-unit skeleton accepts concentr-portion");
   Assert (Rendered (Runtime, "en", "measure_karat_short", Args) =
             "50 kt",
           "measure-unit skeleton accepts short concentr-karat");
   I18N.Arguments.Set (Args, "graphics", "2");
   Assert (Rendered (Runtime, "en", "measure_dot", Args) =
             "2 dots",
           "measure-unit skeleton accepts graphics-dot");
   Assert (Rendered (Runtime, "en", "measure_megapixel_short", Args) =
             "2 MP",
           "measure-unit skeleton accepts short graphics-megapixel");
   Assert (Rendered (Runtime, "en", "measure_pixel_per_cm", Args) =
             "2 pixels per centimeter",
           "measure-unit skeleton accepts graphics-pixel-per-centimeter");
   Assert (Rendered (Runtime, "en", "measure_dot_per_inch_short", Args) =
             "2 dpi",
           "measure-unit skeleton accepts short graphics-dot-per-inch");
   I18N.Arguments.Set (Args, "weight", "2");
   Assert (Rendered (Runtime, "en", "measure_earth_mass", Args) =
             "2 Earth masses",
           "measure-unit skeleton accepts mass-earth-mass");
   Assert (Rendered (Runtime, "en", "measure_solar_mass_short", Args) =
             "2 M" & U (16#2609#),
           "measure-unit skeleton accepts short mass-solar-mass");
   I18N.Arguments.Set (Args, "volume", "2");
   Assert (Rendered (Runtime, "en", "measure_barrel_short", Args) =
             "2 bbl",
           "measure-unit skeleton accepts short volume-barrel");
   I18N.Arguments.Set (Args, "temperature", "2");
   Assert (Rendered (Runtime, "en", "measure_kelvin", Args) =
             "2 kelvins",
           "measure-unit skeleton accepts temperature-kelvin");
   I18N.Arguments.Set (Args, "power", "2");
   Assert (Rendered (Runtime, "en", "measure_horsepower_short", Args) =
             "2 hp",
           "measure-unit skeleton accepts short power-horsepower");
   I18N.Arguments.Set (Args, "size", "2");
   Assert (Rendered (Runtime, "en", "measure_kilobit", Args) =
             "2 kilobits",
           "measure-unit skeleton accepts digital-kilobit");
   Assert (Rendered (Runtime, "en", "measure_terabit_short", Args) =
             "2 Tb",
           "measure-unit skeleton accepts short digital-terabit");
   Assert (Rendered (Runtime, "en", "measure_petabit", Args) =
             "2 petabits",
           "measure-unit skeleton accepts digital-petabit");
   Assert (Rendered (Runtime, "en", "measure_exabyte_short", Args) =
             "2 EB",
           "measure-unit skeleton accepts short digital-exabyte");
   Assert (Rendered (Runtime, "en", "measure_exabit", Args) =
             "2 exabits",
           "measure-unit skeleton accepts digital-exabit");
   I18N.Arguments.Set (Args, "speed", "2");
   Assert (Rendered (Runtime, "en", "measure_knot", Args) =
             "2 knots",
           "measure-unit skeleton accepts speed-knot");
   Assert (Rendered (Runtime, "en", "measure_beaufort_short", Args) =
             "2 B",
           "measure-unit skeleton accepts short speed-beaufort");
   I18N.Arguments.Set (Args, "pressure", "2");
   Assert (Rendered (Runtime, "en", "measure_psi", Args) =
             "2 pounds-force per square inch",
           "measure-unit skeleton accepts pressure PSI");
   I18N.Arguments.Set (Args, "electric", "2");
   Assert (Rendered (Runtime, "en", "measure_milliampere", Args) =
             "2 milliamperes",
           "measure-unit skeleton accepts electric-milliampere");
   Assert (Rendered (Runtime, "en", "measure_millivolt_short", Args) =
             "2 mV",
           "measure-unit skeleton accepts short electric-millivolt");
   I18N.Arguments.Set (Args, "light", "2");
   Assert (Rendered (Runtime, "en", "measure_candela", Args) =
             "2 candela",
           "measure-unit skeleton accepts light-candela");
   Assert (Rendered (Runtime, "en", "measure_solar_luminosity_short", Args) =
             "2 L" & U (16#2609#),
           "measure-unit skeleton accepts short light-solar-luminosity");

   I18N.Arguments.Set (Args, "offset", "-3");
   Assert (Rendered (Runtime, "en", "relative", Args) = "3 days ago",
           "relative-time formatter renders past offsets");
   Assert (Rendered (Runtime, "en-u-nu-beng", "relative", Args) =
             U (16#09E9#) & " days ago",
           "relative-time formatter honors explicit numbering-system digits");
   Expect_Bounded
     ("en", "relative", "3 days ago",
      "bounded relative-time formatting");
   I18N.Arguments.Set (Args, "offset", "0");
   Assert (Rendered (Runtime, "bn", "relative", Args) =
             U (16#986#) & U (16#99C#),
           "relative-time formatter uses generated Bengali current names");
   I18N.Arguments.Set (Args, "offset", "-3");
   Assert (Rendered (Runtime, "de", "relative", Args) = "vor 3 Tagen",
           "relative-time formatter localizes German past offsets");
   Assert (Rendered (Runtime, "fr", "relative", Args) =
             "il y a 3 jours",
           "relative-time formatter localizes French past offsets");
   Assert (Rendered (Runtime, "es", "relative", Args) =
             "hace 3 d" & U (16#ED#) & "as",
           "relative-time formatter localizes Spanish past offsets");
   Assert (Rendered (Runtime, "it", "relative", Args) =
             "3 giorni fa",
           "relative-time formatter localizes Italian past offsets");
   Assert (Rendered (Runtime, "pt", "relative", Args) =
             "h" & U (16#E1#) & " 3 dias",
           "relative-time formatter localizes Portuguese past offsets");
   Assert (Rendered (Runtime, "nl", "relative", Args) =
             "3 dagen geleden",
           "relative-time formatter localizes Dutch past offsets");
   Assert (Rendered (Runtime, "ro", "relative", Args) = "acum 3 zile",
           "relative-time formatter localizes Romanian past offsets");
   Assert (Rendered (Runtime, "lt", "relative", Args) =
             "prie" & U (16#161#) & " 3 dienas",
           "relative-time formatter localizes Lithuanian past offsets");
   Assert (Rendered (Runtime, "sl", "relative", Args) =
             "pred 3 dnevi",
           "relative-time formatter localizes Slovenian past offsets");
   Assert (Rendered (Runtime, "pl", "relative", Args) = "3 dni temu",
           "relative-time formatter localizes Polish past offsets");
   Assert (Rendered (Runtime, "cs", "relative", Args) =
             "p" & U (16#159#) & "ed 3 dny",
           "relative-time formatter localizes Czech past offsets");
   Assert (Rendered (Runtime, "ru", "relative", Args) =
             "3 " & UTF8 ([16#434#, 16#43D#, 16#44F#]) & " "
             & UTF8 ([16#43D#, 16#430#, 16#437#, 16#430#, 16#434#]),
           "relative-time formatter localizes Russian past offsets");
   Assert (Rendered (Runtime, "ar", "relative", Args) =
             UTF8 ([16#642#, 16#628#, 16#644#]) & " "
             & U (16#0663#) & " "
             & UTF8 ([16#623#, 16#64A#, 16#627#, 16#645#]),
           "relative-time formatter localizes Arabic past offsets");
   Assert (Rendered (Runtime, "ar-u-nu-latn", "relative", Args) =
             UTF8 ([16#642#, 16#628#, 16#644#]) & " 3 "
             & UTF8 ([16#623#, 16#64A#, 16#627#, 16#645#]),
           "relative-time formatter honors explicit Latin digits");
   Assert (Rendered (Runtime, "ja", "relative", Args) =
             "3 " & UTF8 ([16#65E5#, 16#524D#]),
           "relative-time formatter localizes Japanese past offsets");
   Assert (Rendered (Runtime, "zh", "relative", Args) =
             "3" & UTF8 ([16#5929#, 16#524D#]),
           "relative-time formatter localizes Chinese past offsets");
   Assert (Rendered (Runtime, "ko", "relative", Args) =
             "3" & U (16#C77C#) & " " & U (16#C804#),
           "relative-time formatter localizes Korean past offsets");
   Assert (Rendered (Runtime, "tr", "relative", Args) =
             "3 " & UTF8 ([16#67#, 16#FC#, 16#6E#])
             & UTF8 ([16#20#, 16#F6#, 16#6E#, 16#63#, 16#65#]),
           "relative-time formatter localizes Turkish past offsets");
   Assert (Rendered (Runtime, "sv", "relative", Args) =
             UTF8 ([16#66#, 16#F6#, 16#72#, 16#20#]) & "3 dagar sedan",
           "relative-time formatter localizes Swedish past offsets");
   Assert (Rendered (Runtime, "da", "relative", Args) =
             "for 3 dage siden",
           "relative-time formatter localizes Danish past offsets");
   Assert (Rendered (Runtime, "eo", "relative", Args) =
             "anta" & U (16#16D#) & " 3 tagoj",
           "relative-time formatter localizes Esperanto past offsets");
   Assert (Rendered (Runtime, "vi", "relative", Args) =
             "3 " & UTF8 ([16#6E#, 16#67#, 16#E0#, 16#79#])
             & UTF8 ([16#20#, 16#74#, 16#72#, 16#1B0#, 16#1EDB#, 16#63#]),
           "relative-time formatter localizes Vietnamese past offsets");
   Assert (Rendered (Runtime, "hu", "relative", Args) =
             "3 nappal"
             & UTF8 ([16#20#, 16#65#, 16#7A#, 16#65#, 16#6C#,
                      16#151#, 16#74#, 16#74#]),
           "relative-time formatter localizes Hungarian past offsets");
   Assert (Rendered (Runtime, "sk", "relative", Args) =
             "pred 3 d" & U (16#148#) & "ami",
           "relative-time formatter localizes Slovak past offsets");
   Assert (Rendered (Runtime, "fi", "relative", Args) =
             "3 " & UTF8 ([16#70#, 16#E4#, 16#69#, 16#76#,
                           16#E4#, 16#E4#]) & " sitten",
           "relative-time formatter localizes Finnish past offsets");
   Assert (Rendered (Runtime, "no", "relative", Args) =
             "for 3 d" & U (16#F8#) & "gn siden",
           "relative-time formatter localizes Norwegian past offsets");
   Assert (Rendered (Runtime, "id", "relative", Args) =
             "3 hari yang lalu",
           "relative-time formatter localizes Indonesian past offsets");
   Assert (Rendered (Runtime, "ms", "relative", Args) = "3 hari lalu",
           "relative-time formatter localizes Malay past offsets");
   Assert (Rendered (Runtime, "af", "relative", Args) = "3 dae gelede",
           "relative-time formatter localizes Afrikaans past offsets");
   Assert (Rendered (Runtime, "sw", "relative", Args) =
             "siku 3 zilizopita",
           "relative-time formatter localizes Swahili past offsets");
   Assert (Rendered (Runtime, "eu", "relative", Args) = "duela 3 egun",
           "relative-time formatter localizes Basque past offsets");
   Assert_Localized_Relative
     ("bg", "relative-time formatter localizes Bulgarian past offsets");
   Assert_Localized_Relative
     ("uk", "relative-time formatter localizes Ukrainian past offsets");
   Assert_Localized_Relative
     ("fa", "relative-time formatter localizes Persian past offsets");
   Assert_Localized_Relative
     ("th", "relative-time formatter localizes Thai past offsets");
   Assert_Localized_Relative
     ("hi", "relative-time formatter localizes Hindi past offsets");
   Assert_Localized_Relative
     ("el", "relative-time formatter localizes Greek past offsets");
   Assert_Localized_Relative
     ("he", "relative-time formatter localizes Hebrew past offsets");
   Assert_Localized_Relative
     ("ca", "relative-time formatter localizes Catalan past offsets");
   Assert_Localized_Relative
     ("az", "relative-time formatter localizes Azerbaijani past offsets");
   Assert_Localized_Relative
     ("ur", "relative-time formatter localizes Urdu past offsets");
   Assert_Localized_Relative
     ("sr", "relative-time formatter localizes Serbian past offsets");
   I18N.Arguments.Set (Args, "offset", "2");
   Assert (Rendered (Runtime, "bn", "relative", Args) =
             U (16#9E8#) & " " & U (16#9A6#) & U (16#9BF#)
             & U (16#9A8#) & U (16#9C7#) & U (16#9B0#)
             & " " & U (16#9AE#) & U (16#9A7#) & U (16#9CD#)
             & U (16#9AF#) & U (16#9C7#),
           "relative-time formatter uses generated Bengali future pattern");
   Assert (Rendered (Runtime, "de", "relative", Args) = "in 2 Tagen",
           "relative-time formatter localizes German future offsets");
   Assert (Rendered (Runtime, "fr", "relative", Args) =
             "dans 2 jours",
           "relative-time formatter localizes French future offsets");
   Assert (Rendered (Runtime, "es", "relative", Args) =
             "dentro de 2 d" & U (16#ED#) & "as",
           "relative-time formatter localizes Spanish future offsets");
   Assert (Rendered (Runtime, "it", "relative", Args) =
             "tra 2 giorni",
           "relative-time formatter localizes Italian future offsets");
   Assert (Rendered (Runtime, "pt", "relative", Args) = "em 2 dias",
           "relative-time formatter localizes Portuguese future offsets");
   Assert (Rendered (Runtime, "nl", "relative", Args) = "over 2 dagen",
           "relative-time formatter localizes Dutch future offsets");
   Assert (Rendered (Runtime, "ro", "relative", Args) = "peste 2 zile",
           "relative-time formatter localizes Romanian future offsets");
   Assert (Rendered (Runtime, "lt", "relative", Args) =
             "po 2 dien" & U (16#173#),
           "relative-time formatter localizes Lithuanian future offsets");
   Assert (Rendered (Runtime, "sl", "relative", Args) =
             U (16#10D#) & "ez 2 dneva",
           "relative-time formatter localizes Slovenian future offsets");
   Assert (Rendered (Runtime, "pl", "relative", Args) = "za 2 dni",
           "relative-time formatter localizes Polish future offsets");
   Assert (Rendered (Runtime, "cs", "relative", Args) = "za 2 dny",
           "relative-time formatter localizes Czech future offsets");
   Assert (Rendered (Runtime, "ru", "relative", Args) =
             UTF8 ([16#447#, 16#435#, 16#440#, 16#435#, 16#437#])
             & " 2 " & UTF8 ([16#434#, 16#43D#, 16#44F#]),
           "relative-time formatter localizes Russian future offsets");
   Assert (Rendered (Runtime, "ar", "relative", Args) =
             UTF8 ([16#62E#, 16#644#, 16#627#, 16#644#]) & " "
             & U (16#0662#) & " "
             & UTF8 ([16#64A#, 16#648#, 16#645#]),
           "relative-time formatter localizes Arabic future offsets");
   Assert (Rendered (Runtime, "ja", "relative", Args) =
             "2 " & UTF8 ([16#65E5#, 16#5F8C#]),
           "relative-time formatter localizes Japanese future offsets");
   Assert (Rendered (Runtime, "zh", "relative", Args) =
             "2" & UTF8 ([16#5929#, 16#540E#]),
           "relative-time formatter localizes Chinese future offsets");
   Assert (Rendered (Runtime, "ko", "relative", Args) =
             "2" & U (16#C77C#) & " " & U (16#D6C4#),
           "relative-time formatter localizes Korean future offsets");
   Assert (Rendered (Runtime, "tr", "relative", Args) =
             "2 " & UTF8 ([16#67#, 16#FC#, 16#6E#]) & " sonra",
           "relative-time formatter localizes Turkish future offsets");
   Assert (Rendered (Runtime, "sv", "relative", Args) = "om 2 dagar",
           "relative-time formatter localizes Swedish future offsets");
   Assert (Rendered (Runtime, "da", "relative", Args) = "om 2 dage",
           "relative-time formatter localizes Danish future offsets");
   Assert (Rendered (Runtime, "eo", "relative", Args) = "post 2 tagoj",
           "relative-time formatter localizes Esperanto future offsets");
   Assert (Rendered (Runtime, "vi", "relative", Args) =
             "sau 2 " & UTF8 ([16#6E#, 16#67#, 16#E0#, 16#79#])
             & " n" & U (16#1EEF#) & "a",
           "relative-time formatter localizes Vietnamese future offsets");
   Assert (Rendered (Runtime, "hu", "relative", Args) =
             "2 nap" & UTF8 ([16#20#, 16#6D#, 16#FA#, 16#6C#,
                              16#76#, 16#61#]),
           "relative-time formatter localizes Hungarian future offsets");
   Assert (Rendered (Runtime, "sk", "relative", Args) = "o 2 dni",
           "relative-time formatter localizes Slovak future offsets");
   Assert (Rendered (Runtime, "fi", "relative", Args) =
             "2 " & UTF8 ([16#70#, 16#E4#, 16#69#, 16#76#,
                           16#E4#, 16#6E#])
             & UTF8 ([16#20#, 16#70#, 16#E4#, 16#E4#,
                      16#73#, 16#74#, 16#E4#]),
           "relative-time formatter localizes Finnish future offsets");
   Assert (Rendered (Runtime, "no", "relative", Args) =
             "om 2 d" & U (16#F8#) & "gn",
           "relative-time formatter localizes Norwegian future offsets");
   Assert (Rendered (Runtime, "id", "relative", Args) = "dalam 2 hari",
           "relative-time formatter localizes Indonesian future offsets");
   Assert (Rendered (Runtime, "ms", "relative", Args) = "dalam 2 hari",
           "relative-time formatter localizes Malay future offsets");
   Assert (Rendered (Runtime, "af", "relative", Args) = "oor 2 dae",
           "relative-time formatter localizes Afrikaans future offsets");
   Assert (Rendered (Runtime, "sw", "relative", Args) =
             "baada ya siku 2",
           "relative-time formatter localizes Swahili future offsets");
   Assert (Rendered (Runtime, "eu", "relative", Args) = "2 egun barru",
           "relative-time formatter localizes Basque future offsets");
   Assert_Localized_Relative
     ("bg", "relative-time formatter localizes Bulgarian future offsets");
   Assert_Localized_Relative
     ("uk", "relative-time formatter localizes Ukrainian future offsets");
   Assert_Localized_Relative
     ("fa", "relative-time formatter localizes Persian future offsets");
   Assert_Localized_Relative
     ("th", "relative-time formatter localizes Thai future offsets");
   Assert_Localized_Relative
     ("hi", "relative-time formatter localizes Hindi future offsets");
   Assert_Localized_Relative
     ("el", "relative-time formatter localizes Greek future offsets");
   Assert_Localized_Relative
     ("he", "relative-time formatter localizes Hebrew future offsets");
   Assert_Localized_Relative
     ("ca", "relative-time formatter localizes Catalan future offsets");
   Assert_Localized_Relative
     ("az", "relative-time formatter localizes Azerbaijani future offsets");
   Assert_Localized_Relative
     ("ur", "relative-time formatter localizes Urdu future offsets");
   Assert_Localized_Relative
     ("sr", "relative-time formatter localizes Serbian future offsets");
   Assert (Rendered (Runtime, "de", "relative_week", Args) =
             "in 2 Wochen",
           "relative-time formatter localizes German week offsets");
   Assert (Rendered (Runtime, "fr", "relative_month", Args) =
             "dans 2 mois",
           "relative-time formatter localizes French month offsets");
   Assert (Rendered (Runtime, "es", "relative_year", Args) =
             "dentro de 2 a" & U (16#F1#) & "os",
           "relative-time formatter localizes Spanish year offsets");
   Assert (Rendered (Runtime, "it", "relative_week", Args) =
             "tra 2 settimane",
           "relative-time formatter localizes Italian week offsets");
   Assert (Rendered (Runtime, "pt", "relative_month", Args) =
             "em 2 meses",
           "relative-time formatter localizes Portuguese month offsets");
   Assert (Rendered (Runtime, "nl", "relative_year", Args) =
             "over 2 jaar",
           "relative-time formatter localizes Dutch year offsets");
   Assert (Rendered (Runtime, "pl", "relative_month", Args) =
             "za 2 miesi" & U (16#105#) & "ce",
           "relative-time formatter localizes Polish month offsets");
   Assert (Rendered (Runtime, "cs", "relative_week", Args) =
             "za 2 t" & U (16#FD#) & "dny",
           "relative-time formatter localizes Czech week offsets");
   Assert (Rendered (Runtime, "ru", "relative_year", Args) =
             UTF8 ([16#447#, 16#435#, 16#440#, 16#435#, 16#437#])
             & " 2 " & UTF8 ([16#433#, 16#43E#, 16#434#, 16#430#]),
           "relative-time formatter localizes Russian year offsets");
   Assert (Rendered (Runtime, "ar", "relative_week", Args) =
             UTF8 ([16#62E#, 16#644#, 16#627#, 16#644#]) & " "
             & U (16#0662#) & " "
             & UTF8 ([16#623#, 16#633#, 16#628#, 16#648#, 16#639#]),
           "relative-time formatter localizes Arabic week offsets");
   Assert (Rendered (Runtime, "de", "relative_quarter_short", Args) =
           "in 2 Quart.",
           "relative-time formatter localizes German short quarter offsets");
   Assert (Rendered (Runtime, "en", "relative_quarter", Args) =
           "in 2 quarters",
           "relative-time formatter renders CLDR quarter offsets");
   Assert (Rendered (Runtime, "en", "relative_quarter_short", Args) =
           "in 2 qtrs.",
           "relative-time formatter renders short CLDR quarter offsets");
   Assert (Rendered (Runtime, "en", "relative_quarter_short_slash",
             Args) =
           Rendered (Runtime, "en", "relative_quarter_short", Args),
           "relative-time formatter accepts unit-width/short alias");
   Assert (Rendered (Runtime, "en", "relative_quarter_narrow", Args) =
           "in 2q",
           "relative-time formatter renders narrow CLDR quarter offsets");
   Assert (Rendered (Runtime, "en", "relative_quarter_narrow_slash",
             Args) =
           Rendered (Runtime, "en", "relative_quarter_narrow", Args),
           "relative-time formatter accepts unit-width/narrow alias");
   Assert (Rendered (Runtime, "en", "relative_minute", Args) =
           "in 2 minutes",
           "relative-time formatter renders CLDR minute offsets");
   I18N.Arguments.Set (Args, "offset", "5");
   Assert (Rendered (Runtime, "pl", "relative_month", Args) =
             "za 5 miesi" & U (16#119#) & "cy",
           "relative-time formatter uses Polish many month form");
   Assert (Rendered (Runtime, "ru", "relative", Args) =
             UTF8 ([16#447#, 16#435#, 16#440#, 16#435#, 16#437#])
             & " 5 " & UTF8 ([16#434#, 16#43D#, 16#435#, 16#439#]),
           "relative-time formatter uses Russian many day form");
   Assert (Rendered (Runtime, "ru", "relative_year", Args) =
             UTF8 ([16#447#, 16#435#, 16#440#, 16#435#, 16#437#])
             & " 5 " & UTF8 ([16#43B#, 16#435#, 16#442#]),
           "relative-time formatter uses Russian many year form");
   Assert (Rendered (Runtime, "en", "relative_second", Args) =
           "in 5 seconds",
           "relative-time formatter renders CLDR second offsets");
   Assert (Rendered (Runtime, "en", "relative_second_short", Args) =
           "in 5 sec.",
           "relative-time formatter renders short CLDR second offsets");
   Assert (Rendered (Runtime, "en", "relative_second_narrow", Args) =
           "in 5s",
           "relative-time formatter renders narrow CLDR second offsets");
   I18N.Arguments.Set (Args, "offset", "-1");
   Assert (Rendered (Runtime, "en", "relative_hour", Args) =
             "1 hour ago",
           "relative-time formatter renders CLDR hour offsets");
   I18N.Arguments.Set (Args, "offset", "0");
   Assert (Rendered (Runtime, "en", "relative", Args) = "today",
           "relative-time formatter renders zero day specially");
   Assert (Rendered (Runtime, "en", "relative_quarter", Args) =
             "this quarter",
           "relative-time formatter renders CLDR current quarter");
   Assert (Rendered (Runtime, "en", "relative_hour", Args) =
             "this hour",
           "relative-time formatter renders CLDR current hour");
   Assert (Rendered (Runtime, "en", "relative_minute", Args) =
             "this minute",
           "relative-time formatter renders CLDR current minute");
   Assert (Rendered (Runtime, "en", "relative_second", Args) = "now",
           "relative-time formatter renders CLDR current second");
   Assert (Rendered (Runtime, "de", "relative", Args) = "heute",
           "relative-time formatter localizes German zero day");
   Assert (Rendered (Runtime, "fr", "relative", Args) =
             "aujourd" & U (16#2019#) & "hui",
           "relative-time formatter localizes French zero day");
   Assert (Rendered (Runtime, "es", "relative", Args) = "hoy",
           "relative-time formatter localizes Spanish zero day");
   Assert (Rendered (Runtime, "it", "relative", Args) = "oggi",
           "relative-time formatter localizes Italian zero day");
   Assert (Rendered (Runtime, "pt", "relative", Args) = "hoje",
           "relative-time formatter localizes Portuguese zero day");
   Assert (Rendered (Runtime, "nl", "relative", Args) = "vandaag",
           "relative-time formatter localizes Dutch zero day");
   Assert (Rendered (Runtime, "ro", "relative", Args) = "azi",
           "relative-time formatter localizes Romanian zero day");
   Assert (Rendered (Runtime, "lt", "relative", Args) =
             U (16#161#) & "iandien",
           "relative-time formatter localizes Lithuanian zero day");
   Assert (Rendered (Runtime, "sl", "relative", Args) = "danes",
           "relative-time formatter localizes Slovenian zero day");
   Assert (Rendered (Runtime, "pl", "relative", Args) = "dzisiaj",
           "relative-time formatter localizes Polish zero day");
   Assert (Rendered (Runtime, "cs", "relative", Args) = "dnes",
           "relative-time formatter localizes Czech zero day");
   Assert (Rendered (Runtime, "ru", "relative", Args) =
             UTF8 ([16#441#, 16#435#, 16#433#, 16#43E#, 16#434#,
                    16#43D#, 16#44F#]),
           "relative-time formatter localizes Russian zero day");
   Assert (Rendered (Runtime, "ar", "relative", Args) =
             UTF8 ([16#627#, 16#644#, 16#64A#, 16#648#, 16#645#]),
           "relative-time formatter localizes Arabic zero day");
   Assert (Rendered (Runtime, "ja", "relative", Args) =
             UTF8 ([16#4ECA#, 16#65E5#]),
           "relative-time formatter localizes Japanese zero day");
   Assert (Rendered (Runtime, "zh", "relative", Args) =
             UTF8 ([16#4ECA#, 16#5929#]),
           "relative-time formatter localizes Chinese zero day");
   Assert (Rendered (Runtime, "ko", "relative", Args) =
             UTF8 ([16#C624#, 16#B298#]),
           "relative-time formatter localizes Korean zero day");
   Assert (Rendered (Runtime, "tr", "relative", Args) =
             UTF8 ([16#62#, 16#75#, 16#67#, 16#FC#, 16#6E#]),
           "relative-time formatter localizes Turkish zero day");
   Assert (Rendered (Runtime, "sv", "relative", Args) = "i dag",
           "relative-time formatter localizes Swedish zero day");
   Assert (Rendered (Runtime, "da", "relative", Args) = "i dag",
           "relative-time formatter localizes Danish zero day");
   Assert (Rendered (Runtime, "fi", "relative", Args) =
             UTF8 ([16#74#, 16#E4#, 16#6E#, 16#E4#, 16#E4#, 16#6E#]),
           "relative-time formatter localizes Finnish zero day");
   Assert (Rendered (Runtime, "eo", "relative", Args) =
             UTF8 ([16#68#, 16#6F#, 16#64#, 16#69#, 16#61#, 16#16D#]),
           "relative-time formatter localizes Esperanto zero day");
   Assert (Rendered (Runtime, "vi", "relative", Args) =
             UTF8 ([16#48#, 16#F4#, 16#6D#, 16#20#, 16#6E#, 16#61#,
                    16#79#]),
           "relative-time formatter localizes Vietnamese zero day");
   Assert (Rendered (Runtime, "hu", "relative", Args) = "ma",
           "relative-time formatter localizes Hungarian zero day");
   Assert (Rendered (Runtime, "sk", "relative", Args) = "dnes",
           "relative-time formatter localizes Slovak zero day");
   Assert (Rendered (Runtime, "de", "relative_week", Args) =
             "diese Woche",
           "relative-time formatter localizes German current week");
   Assert (Rendered (Runtime, "fr", "relative_month", Args) = "ce mois-ci",
           "relative-time formatter localizes French current month");
   Assert (Rendered (Runtime, "es", "relative_year", Args) =
             "este a" & U (16#F1#) & "o",
           "relative-time formatter localizes Spanish current year");
   Assert (Rendered (Runtime, "it", "relative_week", Args) =
             "questa settimana",
           "relative-time formatter localizes Italian current week");
   Assert (Rendered (Runtime, "pt", "relative_month", Args) =
             "este m" & U (16#EA#) & "s",
           "relative-time formatter localizes Portuguese current month");
   Assert (Rendered (Runtime, "nl", "relative_year", Args) = "dit jaar",
           "relative-time formatter localizes Dutch current year");
   Assert (Rendered (Runtime, "pl", "relative_month", Args) =
             "w tym miesi" & U (16#105#) & "cu",
           "relative-time formatter localizes Polish current month");
   Assert (Rendered (Runtime, "cs", "relative_week", Args) =
             "tento t" & U (16#FD#) & "den",
           "relative-time formatter localizes Czech current week");
   Assert (Rendered (Runtime, "ru", "relative_year", Args) =
             UTF8 ([16#432#, 16#20#, 16#44D#, 16#442#, 16#43E#, 16#43C#,
                    16#20#, 16#433#, 16#43E#, 16#434#, 16#443#]),
           "relative-time formatter localizes Russian current year");
   Assert (Rendered (Runtime, "ar", "relative_week", Args) =
             UTF8 ([16#647#, 16#630#, 16#627#, 16#20#, 16#627#, 16#644#,
                    16#623#, 16#633#, 16#628#, 16#648#, 16#639#]),
           "relative-time formatter localizes Arabic current week");
   Assert (Rendered (Runtime, "tr", "relative_year", Args) =
             UTF8 ([16#62#, 16#75#, 16#20#, 16#79#, 16#131#, 16#6C#]),
           "relative-time formatter localizes Turkish current year");
   Assert (Rendered (Runtime, "sv", "relative_week", Args) =
             "denna vecka",
           "relative-time formatter localizes Swedish current week");
   Assert (Rendered (Runtime, "da", "relative_month", Args) =
             UTF8 ([16#64#, 16#65#, 16#6E#, 16#6E#, 16#65#, 16#20#,
                    16#6D#, 16#E5#, 16#6E#, 16#65#, 16#64#]),
           "relative-time formatter localizes Danish current month");
   Assert (Rendered (Runtime, "fi", "relative_week", Args) =
             UTF8 ([16#74#, 16#E4#, 16#6C#, 16#6C#, 16#E4#, 16#20#,
                    16#76#, 16#69#, 16#69#, 16#6B#, 16#6F#, 16#6C#,
                    16#6C#, 16#61#]),
           "relative-time formatter localizes Finnish current week");
   Assert (Rendered (Runtime, "eo", "relative_month", Args) =
             "nuna monato",
           "relative-time formatter localizes Esperanto current month");
   Assert (Rendered (Runtime, "vi", "relative_year", Args) =
             UTF8 ([16#6E#, 16#103#, 16#6D#, 16#20#, 16#6E#, 16#61#,
                    16#79#]),
           "relative-time formatter localizes Vietnamese current year");
   Assert (Rendered (Runtime, "hu", "relative_month", Args) =
             "ez a h" & U (16#F3#) & "nap",
           "relative-time formatter localizes Hungarian current month");
   Assert (Rendered (Runtime, "sk", "relative_week", Args) =
             UTF8 ([16#74#, 16#65#, 16#6E#, 16#74#, 16#6F#, 16#20#,
                    16#74#, 16#FD#, 16#17E#, 16#64#, 16#65#, 16#148#]),
           "relative-time formatter localizes Slovak current week");
   Assert_Localized_Relative
     ("bg", "relative-time formatter localizes Bulgarian current day");
   Assert_Localized_Relative
     ("uk", "relative-time formatter localizes Ukrainian current day");
   Assert_Localized_Relative
     ("fa", "relative-time formatter localizes Persian current day");
   Assert_Localized_Relative
     ("th", "relative-time formatter localizes Thai current day");
   Assert_Localized_Relative
     ("hi", "relative-time formatter localizes Hindi current day");
   Assert_Localized_Relative
     ("el", "relative-time formatter localizes Greek current day");
   Assert_Localized_Relative
     ("he", "relative-time formatter localizes Hebrew current day");
   Assert_Localized_Relative
     ("ca", "relative-time formatter localizes Catalan current day");
   Assert_Localized_Relative
     ("az", "relative-time formatter localizes Azerbaijani current day");
   Assert_Localized_Relative
     ("ur", "relative-time formatter localizes Urdu current day");
   Assert_Localized_Relative
     ("sr", "relative-time formatter localizes Serbian current day");

   I18N.Arguments.Set (Args, "items", "red|green|blue");
   Assert (Rendered (Runtime, "en", "list", Args) =
           "red, green, and blue",
           "list formatter renders deterministic conjunction lists");
   Assert (Rendered (Runtime, "en", "list_standard", Args) =
           Rendered (Runtime, "en", "list", Args),
           "list formatter accepts explicit standard option");
   Assert (Rendered (Runtime, "en", "list_and", Args) =
           Rendered (Runtime, "en", "list", Args),
           "list formatter accepts explicit and option");
   Assert (Rendered (Runtime, "en", "list_or", Args) =
           "red, green, or blue",
           "list formatter renders deterministic disjunction lists");
   Assert (Rendered (Runtime, "en", "list_disjunction", Args) =
           Rendered (Runtime, "en", "list_or", Args),
           "list formatter accepts disjunction alias");
   Assert (Rendered (Runtime, "en", "list_unit", Args) =
           "red, green, blue",
           "list formatter renders deterministic unit lists");
   Assert (Rendered (Runtime, "de", "list_or", Args) =
           "red, green oder blue",
           "list formatter localizes German disjunction");
   Assert (Rendered (Runtime, "fr", "list_or", Args) =
           "red, green ou blue",
           "list formatter localizes French disjunction");
   Assert (Rendered (Runtime, "pl", "list_or", Args) =
           "red, green lub blue",
           "list formatter uses generated Polish disjunction");
   Assert (Rendered (Runtime, "vi", "list_or", Args) =
           "red, green ho" & U (16#1EB7#) & "c blue",
           "list formatter uses generated Vietnamese disjunction");
   Assert (Rendered (Runtime, "ja", "list_unit", Args) =
           "red green blue",
           "list formatter uses generated Japanese unit list separators");
   Assert (Rendered (Runtime, "de", "list", Args) =
           "red, green und blue",
           "list formatter localizes German conjunction");
   Assert (Rendered (Runtime, "fr", "list", Args) =
           "red, green et blue",
           "list formatter localizes French conjunction");
   Assert (Rendered (Runtime, "es", "list", Args) =
           "red, green y blue",
           "list formatter localizes Spanish conjunction");
   Assert (Rendered (Runtime, "it", "list", Args) =
           "red, green e blue",
           "list formatter localizes Italian conjunction");
   Assert (Rendered (Runtime, "pt", "list", Args) =
           "red, green e blue",
           "list formatter localizes Portuguese conjunction");
   Assert (Rendered (Runtime, "nl", "list", Args) =
           "red, green en blue",
           "list formatter localizes Dutch conjunction");
   Assert (Rendered (Runtime, "ro", "list", Args) =
           "red, green " & U (16#219#) & "i blue",
           "list formatter localizes Romanian conjunction");
   Assert (Rendered (Runtime, "lt", "list", Args) =
           "red, green ir blue",
           "list formatter localizes Lithuanian conjunction");
   Assert (Rendered (Runtime, "sl", "list", Args) =
           "red, green in blue",
           "list formatter localizes Slovenian conjunction");
   Assert (Rendered (Runtime, "pl", "list", Args) =
           "red, green i blue",
           "list formatter localizes Polish conjunction");
   Assert (Rendered (Runtime, "cs", "list", Args) =
           "red, green a" & U (16#A0#) & "blue",
           "list formatter localizes Czech conjunction");
   Assert (Rendered (Runtime, "ru", "list", Args) =
           "red, green " & U (16#438#) & " blue",
           "list formatter localizes Russian conjunction");
   Assert (Rendered (Runtime, "ar", "list", Args) =
           "red " & U (16#648#) & "green " & U (16#648#) & "blue",
           "list formatter localizes Arabic conjunction");
   Assert (Rendered (Runtime, "ja", "list", Args) =
           "red" & U (16#3001#) & "green" & U (16#3001#) & "blue",
           "list formatter localizes Japanese conjunction");
   Assert (Rendered (Runtime, "zh", "list", Args) =
           "red" & U (16#3001#) & "green" & U (16#548C#) & "blue",
           "list formatter localizes Chinese conjunction");
   I18N.Arguments.Set (Args, "items", "red|green");
   Assert (Rendered (Runtime, "zh", "list", Args) =
           "red" & U (16#548C#) & "green",
           "list formatter uses source-backed Chinese pair separator");
   I18N.Arguments.Set (Args, "items", "red|green|blue|gold");
   Assert (Rendered (Runtime, "zh", "list", Args) =
           "red" & U (16#3001#) & "green" & U (16#3001#)
           & "blue" & U (16#548C#) & "gold",
           "list formatter uses source-backed Chinese middle separator");
   I18N.Arguments.Set (Args, "items", "red|green|blue");
   Assert (Rendered (Runtime, "ko", "list", Args) =
           "red, green " & U (16#BC0F#) & " blue",
           "list formatter localizes Korean conjunction");
   Assert (Rendered (Runtime, "tr", "list", Args) =
           "red, green ve blue",
           "list formatter localizes Turkish conjunction");
   Assert (Rendered (Runtime, "sv", "list", Args) =
           "red, green och blue",
           "list formatter localizes Swedish conjunction");
   Assert (Rendered (Runtime, "da", "list", Args) =
           "red, green og blue",
           "list formatter localizes Danish conjunction");
   Assert (Rendered (Runtime, "no", "list", Args) =
           "red, green og blue",
           "list formatter localizes Norwegian conjunction");
   Assert (Rendered (Runtime, "fi", "list", Args) =
           "red, green ja blue",
           "list formatter localizes Finnish conjunction");
   Assert (Rendered (Runtime, "id", "list", Args) =
           "red, green, dan blue",
           "list formatter localizes Indonesian conjunction");
   Assert (Rendered (Runtime, "ms", "list", Args) =
           "red, green dan blue",
           "list formatter localizes Malay conjunction");
   Assert (Rendered (Runtime, "eo", "list", Args) =
           "red, green kaj blue",
           "list formatter localizes Esperanto conjunction");
   Assert (Rendered (Runtime, "vi", "list", Args) =
           "red, green v" & U (16#E0#) & " blue",
           "list formatter localizes Vietnamese conjunction");
   Assert (Rendered (Runtime, "sw", "list", Args) =
           "red, green na blue",
           "list formatter localizes Swahili conjunction");
   Assert (Rendered (Runtime, "af", "list", Args) =
           "red, green en blue",
           "list formatter localizes Afrikaans conjunction");
   Assert (Rendered (Runtime, "eu", "list", Args) =
           "red, green eta blue",
           "list formatter localizes Basque conjunction");
   Assert (Rendered (Runtime, "hu", "list", Args) =
           "red, green " & U (16#E9#) & "s blue",
           "list formatter localizes Hungarian conjunction");
   Assert (Rendered (Runtime, "sk", "list", Args) =
           "red, green a blue",
           "list formatter localizes Slovak conjunction");
   Assert (Rendered (Runtime, "bg", "list", Args) =
           "red, green " & U (16#438#) & " blue",
           "list formatter localizes Bulgarian conjunction");
   Assert (Rendered (Runtime, "uk", "list", Args) =
           "red, green " & U (16#456#) & " blue",
           "list formatter localizes Ukrainian conjunction");
   Assert (Rendered (Runtime, "fa", "list", Args) =
           "red" & U (16#60C#) & U (16#200F#) & " green" & U (16#60C#)
           & " " & U (16#648#) & " blue",
           "list formatter localizes Persian conjunction");
   Assert (Rendered (Runtime, "th", "list", Args) =
           "red green " & U (16#E41#) & U (16#E25#) & U (16#E30#) & "blue",
           "list formatter localizes Thai conjunction");
   Assert (Rendered (Runtime, "hi", "list", Args) =
           "red, green, " & U (16#914#) & U (16#930#) & " blue",
           "list formatter localizes Hindi conjunction");
   Assert (Rendered (Runtime, "el", "list", Args) =
           "red, green " & U (16#3BA#) & U (16#3B1#)
           & U (16#3B9#) & " blue",
           "list formatter localizes Greek conjunction");
   Assert (Rendered (Runtime, "he", "list", Args) =
           "red, green " & U (16#5D5#) & "blue",
           "list formatter localizes Hebrew conjunction");

   I18N.Runtime.Render_Into
     (Runtime, "en", "list", Args, Target, Last, Status);
   Assert (Status = I18N.Result.Success,
           "bounded list formatting succeeds");
   Assert (Target (1 .. Last) = "red, green, and blue",
           "bounded list output matches materialized output");

   I18N.Arguments.Set (Args, "bad", "1.2.3");
   Assert (Status_Of (Runtime, "en", "bad_duration", Args) =
           I18N.Result.Invalid_Argument,
           "malformed duration input is rejected");
   I18N.Arguments.Set (Args, "bad", "-1");
   Assert (Status_Of (Runtime, "en", "bad_duration", Args) =
           I18N.Result.Invalid_Argument,
           "negative duration input is rejected");
   I18N.Arguments.Set (Args, "bad", "");
   Assert (Status_Of (Runtime, "en", "bad_duration", Args) =
           I18N.Result.Invalid_Argument,
           "empty duration input is rejected");
   I18N.Arguments.Set (Args, "bad", "9223372036854775808");
   Assert (Status_Of (Runtime, "en", "bad_bytes", Args) =
           I18N.Result.Invalid_Argument,
           "overflowing byte-size input is rejected");
   I18N.Arguments.Set (Args, "bad", "-1");
   Assert (Status_Of (Runtime, "en", "bad_bytes", Args) =
           I18N.Result.Invalid_Argument,
           "negative byte-size input is rejected");
   I18N.Arguments.Set (Args, "bad", "");
   Assert (Status_Of (Runtime, "en", "bad_bytes", Args) =
           I18N.Result.Invalid_Argument,
           "empty byte-size input is rejected");
   I18N.Arguments.Set (Args, "bad", "1.2.3");
   Assert (Status_Of (Runtime, "en", "bad_unit", Args) =
           I18N.Result.Invalid_Argument,
           "malformed unit input is rejected");
   I18N.Arguments.Set (Args, "bad", "");
   Assert (Status_Of (Runtime, "en", "bad_unit", Args) =
           I18N.Result.Invalid_Argument,
           "empty unit input is rejected");
   I18N.Arguments.Set (Args, "bad", "1.5");
   Assert (Status_Of (Runtime, "en", "bad_relative", Args) =
           I18N.Result.Invalid_Argument,
           "malformed relative-time input is rejected");
   I18N.Arguments.Set (Args, "bad", "");
   Assert (Status_Of (Runtime, "en", "bad_relative", Args) =
           I18N.Result.Invalid_Argument,
           "empty relative-time input is rejected");
   I18N.Arguments.Set (Args, "bad", "red||blue");
   Assert (Status_Of (Runtime, "en", "bad_list", Args) =
           I18N.Result.Invalid_Argument,
           "malformed list input is rejected");
   I18N.Arguments.Set (Args, "bad", "");
   Assert (Status_Of (Runtime, "en", "bad_list", Args) =
           I18N.Result.Invalid_Argument,
           "empty list input is rejected");
   I18N.Arguments.Set (Args, "bad", "|red|blue");
   Assert (Status_Of (Runtime, "en", "bad_list", Args) =
           I18N.Result.Invalid_Argument,
           "leading-empty list input is rejected");
   I18N.Arguments.Set (Args, "bad", "red|blue|");
   Assert (Status_Of (Runtime, "en", "bad_list", Args) =
           I18N.Result.Invalid_Argument,
           "trailing-empty list input is rejected");
end Test_Ecosystem_Formatters;
