with I18N.Plurals;

--  The plural category of a range of numbers ("1–2 hours"), by CLDR's
--  pluralRanges for the locale's language: Arabic "one" to "two" is "other",
--  French "one" to "one" stays "one". A language CLDR gives no ranges for
--  takes the end's category.
package I18N.Plural_Ranges is

   --  @param Locale A BCP 47 locale.
   --  @param Start The category of the range's first number.
   --  @param Finish The category of its last.
   --  @return The category the range takes.
   function Category
     (Locale : String;
      Start  : I18N.Plurals.Plural_Category;
      Finish : I18N.Plurals.Plural_Category)
      return I18N.Plurals.Plural_Category;

end I18N.Plural_Ranges;
