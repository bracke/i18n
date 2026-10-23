--  RBNF spellout: render a number as words, e.g. Spell ("en", 123) =
--  "one hundred twenty-three", Ordinal ("en", 3) = "third". A recursive
--  interpreter over the CLDR rule-based number-format rules, backed by
--  per-locale shards share/i18n/rbnf/<locale>.i18ndata.
--
--  Scope (v1): integer values (Long_Long_Integer) via any ruleset the locale
--  defines -- %spellout-cardinal / %spellout-ordinal by default, and gendered /
--  case variants by passing their name. Fractions, non-decimal numbering-system
--  radices, and arbitrary precision are a documented follow-up.
package I18N.Spellout is

   --  Spell Value in words using Ruleset (default the cardinal spellout).
   --  Returns "" when the locale has no RBNF data or the ruleset is absent.
   function Spell
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "%spellout-cardinal")
      return String;

   --  Words, the spelled-out magnitude of a negative number, under the
   --  ruleset's negative rule: Negative_Words ("en", "zero point five") =
   --  "minus zero point five", German "minus ...", Ewe's suffix. "" where the
   --  locale has no such rule.
   function Negative_Words
     (Locale  : String;
      Words   : String;
      Ruleset : String := "%spellout-cardinal")
      return String;

   --  Ordinal words, e.g. Ordinal ("en", 21) = "twenty-first"; Ruleset ""
   --  is the locale's Ordinal_Ruleset.
   --  A decimal in words by the ruleset's fraction rule ("x.x", or "0.x"
   --  for a zero integer part): Decimal_Words ("de", 12, "5") = "zwölf Komma
   --  fünf", the fraction digit by digit as ICU spells it. "" where the
   --  locale has no such rule.
   function Decimal_Words
     (Locale          : String;
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : String;
      Ruleset         : String := "")
      return String;

   --  The ordinal ruleset a locale spells with: %spellout-ordinal, or for a
   --  language that only has gendered ones (French, Russian) the masculine.
   function Ordinal_Ruleset (Locale : String) return String;

   function Ordinal
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "")
      return String;

   --  True when an RBNF shard is installed for the locale (or a parent).
   function Available (Locale : String) return Boolean;

end I18N.Spellout;
