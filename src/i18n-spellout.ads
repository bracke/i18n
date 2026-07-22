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

   --  Ordinal words, e.g. Ordinal ("en", 21) = "twenty-first".
   function Ordinal
     (Locale  : String;
      Value   : Long_Long_Integer;
      Ruleset : String := "%spellout-ordinal")
      return String;

   --  True when an RBNF shard is installed for the locale (or a parent).
   function Available (Locale : String) return Boolean;

end I18N.Spellout;
