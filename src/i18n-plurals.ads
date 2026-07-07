with I18N.Locales;

--  Stable v1.1.0 public plural-category foundation.
--
--  Purpose:
--  This package classifies whole values and explicit CLDR fractional operands
--  into plural categories for a given locale. It provides the generic
--  plural/selectordinal mechanics the message engine and downstream libraries
--  build on. It does NOT implement any application-domain wording, number
--  formatting, or unit-humanization policy.
--
--  Coverage:
--  Cardinal and ordinal rule-family mappings are generated from the checked
--  CLDR 46.1 source subset and evaluated by built-in deterministic families.
--  The checked-in tables cover all 219 CLDR cardinal locale IDs and all 104
--  CLDR ordinal locale IDs from that source, with exact locale matching before
--  parent fallback. The integer Cardinal/Ordinal take a whole value; an
--  overloaded Cardinal also accepts CLDR fractional operands (i, v, f) for
--  decimal quantities. Locales outside the generated CLDR set use the root
--  rule, which returns Other.
--
--  Value model:
--  The absolute value of the argument is used, matching the CLDR operand n. The
--  integer entry points treat fraction digits as zero; the operand Cardinal
--  applies the visible-fraction-digit rules (for example English "1.5" -> Other,
--  French "1,5" -> One).
--
--  Error behavior:
--  These are total functions. They never raise. If runtime plural-category
--  overrides have been loaded through I18N.Runtime, exact integer cardinal and
--  ordinal classifications consult those overrides before bounded runtime
--  plural-rule expressions and generated fallback rules.
--
--  Example:
--     Cardinal ("en", 1) = One
--     Cardinal ("en", 5) = Other
--     Ordinal  ("en", 2) = Two     --  "2nd"
--     Ordinal  ("en", 3) = Few     --  "3rd"
package I18N.Plurals is

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
      return Plural_Category;

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
      return Plural_Category;

   --  Ordinal plural category (1st / 2nd / 3rd / 4th ...).
   --
   --  @param Locale Locale identifier; only the language subtag is significant.
   --  @param Value Integer quantity to classify.
   --  @return Plural category for Value under Locale's ordinal rules.
   function Ordinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category;

end I18N.Plurals;
