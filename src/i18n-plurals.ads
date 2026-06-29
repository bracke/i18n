with I18N.Locales;

--  Stable v1.0 public plural-category foundation.
--
--  Purpose:
--  This package classifies an integer value into a CLDR plural category for a
--  given locale. It provides the generic plural/selectordinal mechanics the
--  message engine and downstream libraries build on. It does NOT implement any
--  application-domain wording, number formatting, or unit-humanization policy.
--
--  Coverage:
--  Cardinal rules cover en, de, nl, da, es, it, fr, pt, ru, pl, cs, and ar -- the
--  Slavic (ru, pl, cs) and Arabic (ar) rules cover all six categories. Ordinal
--  rules are modelled for en, fr, and it. The integer Cardinal/Ordinal take a
--  whole value; an overloaded Cardinal also accepts CLDR fractional operands
--  (i, v, f) for decimal quantities. Locales resolve through their two-letter
--  language subtag; any locale outside these sets (including the CJK languages
--  ja, zh, ko) uses the root rule, which returns Other.
--
--  Value model:
--  The absolute value of the argument is used, matching the CLDR operand n. The
--  integer entry points treat fraction digits as zero; the operand Cardinal
--  applies the visible-fraction-digit rules (for example English "1.5" -> Other,
--  French "1,5" -> One).
--
--  Error behavior:
--  These are pure total functions. They never raise and never allocate.
--
--  Example:
--     Cardinal ("en", 1) = One
--     Cardinal ("en", 5) = Other
--     Ordinal  ("en", 2) = Two     --  "2nd"
--     Ordinal  ("en", 3) = Few     --  "3rd"
package I18N.Plurals is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   --  CLDR plural categories.
   type Plural_Category is
     (Zero,
      One,
      Two,
      Few,
      Many,
      Other);

   --  Cardinal plural category (one item / many items).
   --
   --  @param Locale Locale identifier; only the language subtag is significant.
   --  @param Value Integer quantity to classify.
   --  @return Plural category for Value under Locale's cardinal rules.
   function Cardinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   with
     Global => null;

   --  Cardinal category from CLDR fractional operands.
   --
   --  @param Locale          Locale identifier; only the language subtag counts.
   --  @param Integer_Part    Absolute integer part (CLDR operand i).
   --  @param Fraction_Digits Count of visible fraction digits (CLDR operand v).
   --  @param Fraction_Value  Those digits as an integer (CLDR operand f).
   --  @return Plural category. With Fraction_Digits = 0 this exactly matches the
   --          integer Cardinal above.
   function Cardinal
     (Locale          : I18N.Locales.Locale_Id;
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : Natural;
      Fraction_Value  : Long_Long_Integer)
      return Plural_Category
   with
     Global => null;

   --  Ordinal plural category (1st / 2nd / 3rd / 4th ...).
   --
   --  @param Locale Locale identifier; only the language subtag is significant.
   --  @param Value Integer quantity to classify.
   --  @return Plural category for Value under Locale's ordinal rules.
   function Ordinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   with
     Global => null;

end I18N.Plurals;
