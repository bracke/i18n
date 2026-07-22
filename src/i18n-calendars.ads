--  Localized names for the 11 non-Gregorian CLDR calendars: month, day,
--  quarter, day-period and era names. Backed by per-locale runtime shards
--  share/i18n/calendars/<locale>.i18ndata.
--
--  NAMES ONLY. This package localizes a caller-supplied calendar index -- it
--  does not convert or compute dates (that is a later phase). Gregorian names
--  are served by the date formatter, not here.
--
--  Calendar is a CLDR calendar id (use the constants below, or a variant string
--  such as "islamic-civil"). Widths fall back narrow -> abbreviated -> wide, and
--  stand-alone -> format, then through the locale's parents.
package I18N.Calendars is

   type Context_Kind is (Format, Stand_Alone);
   type Width_Kind is (Wide, Abbreviated, Narrow);
   type Weekday is (Sun, Mon, Tue, Wed, Thu, Fri, Sat);

   --  Month name (Month is the calendar's 1-based month index).
   function Month_Name
     (Locale, Calendar : String;
      Month            : Positive;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String;

   function Day_Name
     (Locale, Calendar : String;
      Day              : Weekday;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String;

   function Quarter_Name
     (Locale, Calendar : String;
      Quarter          : Positive;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String;

   --  Period is a CLDR day-period key: "am", "pm", "midnight", "noon",
   --  "morning1", "afternoon1", "evening1", "night1", ...
   function Day_Period_Name
     (Locale, Calendar : String;
      Period           : String;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String;

   --  Era name (Era is the calendar's 0-based era index).
   function Era_Name
     (Locale, Calendar : String;
      Era              : Natural;
      Width            : Width_Kind := Abbreviated)
      return String;

   --  True when a calendar shard is installed for the locale (or a parent).
   function Available (Locale : String) return Boolean;

   Buddhist         : constant String := "buddhist";
   Chinese          : constant String := "chinese";
   Coptic           : constant String := "coptic";
   Dangi            : constant String := "dangi";
   Ethiopic         : constant String := "ethiopic";
   Hebrew           : constant String := "hebrew";
   Indian           : constant String := "indian";
   Islamic          : constant String := "islamic-umalqura";
   Islamic_Civil    : constant String := "islamic-civil";
   Japanese         : constant String := "japanese";
   Persian          : constant String := "persian";
   ROC              : constant String := "roc";

end I18N.Calendars;
