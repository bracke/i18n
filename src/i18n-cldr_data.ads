package I18N.CLDR_Data is
   pragma Preelaborate;

   --  Generated-data boundary for the deterministic CLDR subset shipped with
   --  this crate. The body is currently checked in as curated generated data;
   --  formatter packages consume this unit instead of embedding data tables.

   --  Return the primary language subtag used for built-in data lookup.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return The first two locale characters, or an empty string.
   function Language (Locale : String) return String;

   --  Return the locale decimal separator.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 decimal separator text.
   function Decimal_Separator (Locale : String) return String;

   --  Return the locale grouping separator.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 grouping separator text.
   function Group_Separator (Locale : String) return String;

   --  Report whether the locale uses Indian primary/secondary grouping.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return True when Indian grouping should be used.
   function Uses_Indian_Grouping (Locale : String) return Boolean;

   --  Report whether date styles use day-month-year ordering.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return True when built-in date styles use day-month-year ordering.
   function Uses_Day_Month_Year (Locale : String) return Boolean;

   --  Return the generated first day of week for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Weekday key: sun, mon, fri, or sat.
   function First_Day_Of_Week (Locale : String) return String;

   --  Return the generated minimum days required in the first week.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Minimum first-week day count, usually 1 or 4.
   function First_Week_Min_Days (Locale : String) return Natural;

   --  Return the deterministic date style pattern for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Style Date style: default, short, medium, long, or full.
   --  @return Pattern text consumed by the date/time formatter.
   function Date_Style_Pattern
     (Locale : String;
      Style  : String)
      return String;

   --  Return the date style pattern a calendar writes for a locale.
   --
   --  The calendar is part of the pattern, not just of the year it prints:
   --  Thai gregorian long is "d MMMM G y" and Thai buddhist long is
   --  "d MMMM y" -- the era belongs to one and not the other. A calendar with
   --  no pattern of its own follows the locale's gregorian one.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Calendar Stable calendar key, such as gregorian or buddhist.
   --  @param Style Date style: default, short, medium, long, or full.
   --  @return Pattern text consumed by the date/time formatter.
   function Date_Style_Pattern
     (Locale   : String;
      Calendar : String;
      Style    : String)
      return String;

   --  Return the deterministic time style pattern for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Style Time style: default, short, medium, long, or full.
   --  @param Has_Second True when default/medium output should preserve seconds.
   --  @return Pattern text consumed by the date/time formatter.
   function Time_Style_Pattern
     (Locale     : String;
      Style      : String;
      Has_Second : Boolean)
      return String;

   --  Return the exact CLDR availableFormats pattern for a skeleton.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Skeleton CLDR availableFormats skeleton key.
   --  @return Pattern text consumed by the date/time formatter, or empty.
   function Available_Format_Pattern
     (Locale   : String;
      Skeleton : String)
      return String;

   --  Return the deterministic separator between adjacent date/time fields.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Last_Class Previous field class: D for date or T for time.
   --  @param Class Current field class: D for date or T for time.
   --  @param Last_Field Previous skeleton field character.
   --  @param Field Current skeleton field character.
   --  @return Separator text to emit between the fields.
   function Date_Time_Field_Separator
     (Locale     : String;
      Last_Class : Character;
      Class      : Character;
      Last_Field : Character;
      Field      : Character)
      return String;

   --  Return the separator between separately formatted date and time values.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text.
   function Date_Time_Style_Separator (Locale : String) return String;

   --  Return a locale-specific digit.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Digit ASCII digit to localize.
   --  @return UTF-8 digit text, or Digit unchanged for unsupported inputs.
   function Digit_Text (Locale : String; Digit : Character) return String;

   --  Return the localized percent suffix for number formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 suffix text appended to percent-formatted numbers.
   function Number_Percent_Suffix (Locale : String) return String;

   --  Return the localized plus sign for numeric display.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 plus sign text.
   function Number_Plus_Sign (Locale : String) return String;

   --  Return the localized minus sign for numeric display.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 minus sign text.
   function Number_Minus_Sign (Locale : String) return String;

   --  Return the accounting prefix for negative numbers.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 prefix text.
   function Number_Accounting_Prefix (Locale : String) return String;

   --  Return the accounting suffix for negative numbers.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 suffix text.
   function Number_Accounting_Suffix (Locale : String) return String;

   --  Return the localized permille suffix for number formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 suffix text appended to permille-formatted numbers.
   function Number_Permille_Suffix (Locale : String) return String;

   --  Return the localized compact-number suffix.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Scale Compact scale value, including 10000 and 100000000 for
   --    CJK locales and 1000, 1000000, 1000000000, or 1000000000000 for
   --    western-style compact notation.
   --  @param Long_Form True for compact-long text, False for compact-short.
   --  @return UTF-8 suffix text, including spacing when required.
   function Number_Compact_Suffix
     (Locale    : String;
      Scale     : Long_Long_Integer;
      Long_Form : Boolean)
      return String;

   --  Return the scientific/engineering exponent separator.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 exponent separator text.
   function Number_Exponent_Separator (Locale : String) return String;

   --  Return a localized full month name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Month Gregorian month number, 1 through 12.
   --  @return UTF-8 month name, English fallback, or empty string.
   function Month_Name (Locale : String; Month : Natural) return String;

   --  Return a localized abbreviated month name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Month Gregorian month number, 1 through 12.
   --  @return UTF-8 abbreviated month name, English fallback, or empty string.
   function Month_Name_Short (Locale : String; Month : Natural) return String;

   --  Return a localized full weekday name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Day Weekday number, 0 Sunday through 6 Saturday.
   --  @return UTF-8 weekday name, English fallback, or empty string.
   function Weekday_Name (Locale : String; Day : Natural) return String;

   --  Return a localized abbreviated weekday name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Day Weekday number, 0 Sunday through 6 Saturday.
   --  @return UTF-8 abbreviated weekday name, English fallback, or empty string.
   function Weekday_Name_Short (Locale : String; Day : Natural) return String;

   --  Return a localized wide quarter name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Quarter Quarter number, 1 through 4.
   --  @param Quarter_Text Already-localized quarter number text.
   --  @return UTF-8 wide quarter name.
   function Quarter_Name
     (Locale       : String;
      Quarter      : Natural;
      Quarter_Text : String)
      return String;

   --  Return a localized abbreviated quarter name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Quarter Quarter number, 1 through 4.
   --  @param Quarter_Text Already-localized quarter number text.
   --  @return UTF-8 abbreviated quarter name.
   function Quarter_Name_Short
     (Locale       : String;
      Quarter      : Natural;
      Quarter_Text : String)
      return String;

   --  Return a localized day-period display name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Period Stable period key: midnight, noon, am, pm, morning1,
   --  afternoon1, evening1, or night1.
   --  @param Wide True for wide text, False for abbreviated text.
   --  @return UTF-8 day-period display name.
   function Day_Period_Name
     (Locale : String;
      Period : String;
      Wide   : Boolean)
      return String;

   --  Return a localized era display name.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Calendar Stable calendar key, such as gregorian or japanese.
   --  @param Era Stable era key, such as ad or reiwa.
   --  @return UTF-8 era name, or empty string when not built in.
   function Era_Name
     (Locale   : String;
      Calendar : String;
      Era      : String)
      return String;

   --  Return the separator between era name and era year.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Calendar Stable calendar key, such as japanese.
   --  @return UTF-8 separator text.
   function Era_Year_Separator
     (Locale   : String;
      Calendar : String)
      return String;

   --  Return the primary tzdb identifier for a zone alias.
   --  @param Zone IANA-style zone identifier, alias, or empty UTC default.
   --  @return Canonical tzdb zone identifier, or Zone unchanged.
   function Canonical_Time_Zone (Zone : String) return String;

   --  Return the built-in base offset for a named time zone.
   --  @param Zone IANA-style zone identifier or UTC/Z.
   --  @param Valid Set to True when Zone is built into the deterministic data.
   --  @return Offset minutes east of UTC, or 0 when Zone is unknown.
   function Time_Zone_Base_Offset_Minutes
     (Zone  : String;
      Valid : out Boolean)
      return Integer;

   --  Return generated tzdb offset seconds for a UTC instant.
   --  @param Zone IANA-style zone identifier or generated alias.
   --  @param Year UTC Gregorian year.
   --  @param Month UTC Gregorian month.
   --  @param Day UTC Gregorian day.
   --  @param Hour UTC hour.
   --  @param Minute UTC minute.
   --  @param Second UTC second.
   --  @param Valid Set to True when generated tzdb data covers Zone.
   --  @return Offset seconds east of UTC, or 0 when Zone is unknown.
   function Time_Zone_Offset_Seconds_At_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Valid  : out Boolean)
      return Integer;

   --  Return the deterministic DST rule family for a named time zone.
   --  @param Zone IANA-style zone identifier.
   --  @return Stable family key consumed by the date/time formatter.
   function Time_Zone_DST_Family (Zone : String) return String;

   --  Return the localized display name for a time zone in the built-in subset.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Zone IANA-style zone identifier or UTC/Z.
   --  @return Display text used by zone-name skeleton fields.
   function Time_Zone_Display_Name
     (Locale : String;
      Zone   : String)
      return String;

   --  Return the localized exemplar location for a time zone.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Zone IANA-style zone identifier or UTC/Z.
   --  @return Localized exemplar city/location text, or empty.
   function Time_Zone_Exemplar_Location
     (Locale : String;
      Zone   : String)
      return String;

   --  Return the short standard/daylight display name for a DST family.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Family Stable DST family key from Time_Zone_DST_Family.
   --  @param Daylight True when the instant is in daylight time.
   --  @return Short display text used by z skeleton fields, or empty.
   function Time_Zone_Short_Name
     (Locale   : String;
      Family   : String;
      Daylight : Boolean)
      return String;

   --  Return the short generic display name for a DST family.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Family Stable DST family key from Time_Zone_DST_Family.
   --  @return Short display text used by v skeleton fields, or empty.
   function Time_Zone_Generic_Short_Name
     (Locale : String;
      Family : String)
      return String;

   --  Return the localized generic location pattern for VVVV zone output.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Pattern containing {0} for the exemplar location.
   function Time_Zone_Location_Pattern (Locale : String) return String;

   --  Return the localized GMT offset prefix.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Prefix text used by GMT-style offset skeleton fields.
   function GMT_Offset_Prefix (Locale : String) return String;

   --  Return the UTC zero-offset designator for ISO-style zone fields.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 zone designator text.
   function Time_Zone_UTC_Designator (Locale : String) return String;

   --  Return the separator between hours and minutes in zone offsets.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text.
   function Time_Zone_Offset_Separator (Locale : String) return String;

   --  Return ISO 4217 minor units for built-in currency metadata.
   --  @param Code Three-letter uppercase currency code.
   --  @return Number of fractional digits used for normal rounding.
   function Currency_Minor_Units (Code : String) return Natural;

   --  Return the integer cash increment in minor units.
   --  @param Code Three-letter uppercase currency code.
   --  @return Cash rounding increment in minor units.
   function Currency_Cash_Increment (Code : String) return Natural;

   --  Return the standard currency symbol.
   --  @param Code Three-letter uppercase currency code.
   --  @return UTF-8 symbol text, or Code when no symbol is built in.
   function Currency_Symbol (Code : String) return String;

   --  Return the narrow currency symbol.
   --  @param Code Three-letter uppercase currency code.
   --  @return UTF-8 narrow symbol text, or the standard symbol fallback.
   function Currency_Narrow_Symbol (Code : String) return String;

   --  Return the English plural currency display name.
   --  @param Code Three-letter uppercase currency code.
   --  @return Display name text, or Code when no name is built in.
   function Currency_Display_Name (Code : String) return String;

   --  Return a localized currency display name from generated CLDR data.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Code Three-letter uppercase currency code.
   --  @param Category CLDR plural category name: zero, one, two, few, many,
   --    or other.
   --  @return Localized display name text, or English/code fallback.
   function Currency_Display_Name
     (Locale   : String;
      Code     : String;
      Category : String := "other")
      return String;

   --  Report whether currency symbols are formatted before the amount.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return True when symbol-first formatting is built in for Locale.
   function Currency_Symbol_First (Locale : String) return Boolean;

   --  Return the separator between currency display text and amount.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including spacing when needed.
   function Currency_Amount_Separator (Locale : String) return String;

   --  Return the accounting prefix for negative currency amounts.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 prefix text.
   function Currency_Accounting_Prefix (Locale : String) return String;

   --  Return the accounting suffix for negative currency amounts.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 suffix text.
   function Currency_Accounting_Suffix (Locale : String) return String;

   --  Return the localized final conjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Final_Separator (Locale : String) return String;

   --  Return the localized two-item conjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Pair_Separator (Locale : String) return String;

   --  Return the localized start separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Start_Separator (Locale : String) return String;

   --  Return the localized middle separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Middle_Separator (Locale : String) return String;

   --  Return the localized non-final item separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Item_Separator (Locale : String) return String;

   --  Return the localized final disjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Or_Final_Separator (Locale : String) return String;

   --  Return the localized two-item disjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Or_Pair_Separator (Locale : String) return String;

   --  Return the localized start disjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Or_Start_Separator (Locale : String) return String;

   --  Return the localized middle disjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Or_Middle_Separator (Locale : String) return String;

   --  Return the localized item disjunction separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Or_Item_Separator (Locale : String) return String;

   --  Return the localized final unit-list separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Unit_Final_Separator (Locale : String) return String;

   --  Return the localized two-item unit-list separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Unit_Pair_Separator (Locale : String) return String;

   --  Return the localized start unit-list separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Unit_Start_Separator (Locale : String) return String;

   --  Return the localized middle unit-list separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Unit_Middle_Separator (Locale : String) return String;

   --  Return the localized item unit-list separator for list formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function List_Unit_Item_Separator (Locale : String) return String;

   --  Return the localized separator for compound unit formatting.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including surrounding spaces.
   function Per_Unit_Separator (Locale : String) return String;

   --  Return the localized separator between a number and a unit.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text including spacing when needed.
   function Unit_Value_Separator (Locale : String) return String;

   --  Return the localized short/narrow separator for compound units.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text.
   function Unit_Short_Per_Separator (Locale : String) return String;

   --  Return a deterministic byte-size unit label.
   --  @param Scale Binary byte scale from B through PiB.
   --  @return Display label for the byte-size formatter.
   function Byte_Size_Unit_Label (Scale : Long_Long_Integer) return String;

   --  Return the deterministic duration field separator.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return UTF-8 separator text.
   function Duration_Field_Separator (Locale : String) return String;

   --  Return deterministic spellout words for whole numbers below 20.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Value Whole number, 0 through 19.
   --  @return Locale-specific spellout word, or empty string when unsupported.
   function Spellout_Cardinal_Under_20
     (Locale : String;
      Value  : Natural)
      return String;

   --  Return deterministic spellout words for tens.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Value Tens digit, 2 through 9.
   --  @return Locale-specific tens word, or empty string when unsupported.
   function Spellout_Cardinal_Tens
     (Locale : String;
      Value  : Natural)
      return String;

   --  Return deterministic ordinal spellout words for whole numbers below 20.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Value Whole number, 0 through 19.
   --  @return Locale-specific ordinal word, or empty string when unsupported.
   function Spellout_Ordinal_Under_20
     (Locale : String;
      Value  : Natural)
      return String;

   --  Return deterministic ordinal spellout words for whole tens.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Value Tens digit, 2 through 9.
   --  @return Locale-specific ordinal tens word, or empty string when unsupported.
   function Spellout_Ordinal_Tens
     (Locale : String;
      Value  : Natural)
      return String;

   --  Return deterministic scale words for locale-specific spellout.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Scale Scale value: 100, 1000, or 1000000.
   --  @param Ordinal True for ordinal scale names.
   --  @return Locale-specific scale word, or empty string when unsupported.
   function Spellout_Scale_Name
     (Locale  : String;
      Scale   : Natural;
      Ordinal : Boolean := False)
      return String;

   --  Return the localized zero-offset relative-time label.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Base Canonical unit base name, such as day or year.
   --  @return UTF-8 relative label, such as today, or now as fallback.
   function Relative_Current_Name
     (Locale : String;
      Base   : String;
      Width  : String)
      return String;

   --  Return the localized relative-time prefix for nonzero offsets.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Future True for future offsets, False for past offsets.
   --  @return UTF-8 prefix text, including spacing when needed.
   function Relative_Offset_Prefix
     (Locale : String;
      Future : Boolean)
      return String;

   --  Return the localized relative-time suffix for nonzero offsets.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Future True for future offsets, False for past offsets.
   --  @return UTF-8 suffix text, including spacing when needed.
   function Relative_Offset_Suffix
     (Locale : String;
      Future : Boolean)
      return String;

   --  Return a relative-time unit name by CLDR plural category.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Base Canonical unit base name, such as day or year.
   --  @param Category CLDR plural category name.
   --  @return UTF-8 unit text, or empty string when no category row exists.
   function Relative_Unit_Category_Name
     (Locale   : String;
      Base     : String;
      Category : String)
      return String;

   --  Return a complete CLDR relative-time pattern for a nonzero offset.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Base Canonical unit base name, such as day or year.
   --  @param Category CLDR plural category name for the absolute offset.
   --  @param Future True for future offsets, False for past offsets.
   --  @return UTF-8 pattern containing {0}, or empty string when absent.
   function Relative_Time_Pattern
     (Locale   : String;
      Base     : String;
      Width    : String;
      Category : String;
      Future   : Boolean)
      return String;

   --  Return a relative-time-specific unit display override.
   --  @param Locale Locale identifier or catalog locale key.
   --  @param Base Canonical unit base name, such as day or year.
   --  @param Singular True when the relative amount is exactly one.
   --  @return UTF-8 unit text, or empty string when normal unit data applies.
   function Relative_Unit_Display_Name
     (Locale   : String;
      Base     : String;
      Singular : Boolean)
      return String;

   --  Return the CLDR cardinal plural rule family for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Stable internal family name consumed by I18N.Plurals.
   function Cardinal_Rule_Family (Locale : String) return String;

   --  Return the CLDR ordinal plural rule family for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Stable internal family name consumed by I18N.Plurals.
   function Ordinal_Rule_Family (Locale : String) return String;

end I18N.CLDR_Data;
