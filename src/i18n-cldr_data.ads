package I18N.CLDR_Data is
   pragma Preelaborate;

   --  Generated-data boundary for the deterministic CLDR subset shipped with
   --  this crate. The body is currently checked in as curated generated data;
   --  formatter packages consume this unit instead of embedding data tables.

   --  Return the primary language subtag used for built-in data lookup.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return The first two locale characters, or an empty string.
   function Language (Locale : String) return String;

   --  Return the generated first day of week for a locale.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Weekday key: sun, mon, fri, or sat.
   function First_Day_Of_Week (Locale : String) return String;

   --  Return the generated minimum days required in the first week.
   --  @param Locale Locale identifier or catalog locale key.
   --  @return Minimum first-week day count, usually 1 or 4.
   function First_Week_Min_Days (Locale : String) return Natural;

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

end I18N.CLDR_Data;
