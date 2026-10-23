--  On-the-fly-aware measurement-unit display names.
--
--  A peer of I18N.Number_Format and I18N.Date_Time_Format: it returns a
--  localized unit name (kilometer -> "kilometers" / "Kilometer" /
--  "kilomètres") from the per-locale units/<locale>.i18ndata shard. Message
--  renderers delegate here instead of reading I18N.CLDR_Data directly.
--
--  The unit data is by far the largest CLDR block, so it is sharded one file
--  per locale; only the locales actually formatted are loaded at runtime.
package I18N.Unit_Format is

   --  Localized display name for Base at Width, selected by CLDR plural
   --  Category. Width accepts the CLDR "unit-width-*" spellings and the bare
   --  "full-name"/"long"/"short"/"narrow" aliases.
   function Display_Name
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String)
      return String;

   --  The locale's "per" separator for compound units (miles per hour).
   function Per_Unit_Separator (Locale : String) return String;

   --  CLDR's whole pattern for a value of Base in Width and plural Category
   --  where it is not the value, a space and Display_Name: "{0} heures" with
   --  French's no-break space, Japanese narrow "{0}秒", Arabic's "ساعتان"
   --  that names the count in words. Found is False where the plain
   --  composition is CLDR's own.
   function Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Found    : out Boolean)
      return String;

   --  CLDR's pattern for Base as a rate's denominator in Width -- "{0}/s",
   --  German "{0} pro Stunde" -- into which the numerator's whole text goes.
   --  Found is False where the locale has none, and the rate is composed
   --  with Per_Unit_Separator / Short_Per_Separator.
   function Per_Pattern
     (Locale : String;
      Base   : String;
      Width  : String;
      Found  : out Boolean)
      return String;

   --  Canonicalize an ICU unit id -- with or without its CLDR category prefix
   --  (length-, volume-, ...) and in British or American spelling -- to the
   --  bare base name Display_Name and English_Name key on. Returns "" for an
   --  unrecognized unit, so it also serves as the canonical is-this-a-known-unit
   --  gate (which the message parser validates against).
   function Canonical_Base (Unit_Id : String) return String;

   --  The locale's separator between a measured value and its unit name.
   function Value_Separator (Locale : String) return String;

   --  The locale's "per" separator for compound units at short/narrow width.
   function Short_Per_Separator (Locale : String) return String;

   --  Built-in English name for Base at Width: the compiled English CLDR name
   --  when present, otherwise the crate's hardcoded extras -- custom and
   --  aliased units such as fortnight, decade, or square-inch that CLDR does
   --  not name. Singular selects the singular vs plural form. Returns "" for an
   --  unrecognized unit or an unsupported Width, which also serves as the
   --  canonical "is this a known unit?" test. This is the language-independent
   --  last resort behind Display_Name's localized lookup, so callers seat it
   --  after Display_Name rather than in place of it.
   function English_Name
     (Base     : String;
      Width    : String;
      Singular : Boolean)
      return String;

end I18N.Unit_Format;
