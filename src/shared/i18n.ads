--  Root namespace for the I18N internationalization platform: a native Ada
--  implementation of the Unicode/CLDR stack. ICU-style message formatting now
--  lives in the separate `messages` crate, which depends on this one.
--
--  Public platform packages include (among others):
--
--  * I18N.Normalization, I18N.Casing, I18N.Segmentation, I18N.Collation,
--    I18N.Transliteration        -- Unicode text algorithms
--  * I18N.Number_Format, I18N.Currency, I18N.Date_Time_Format, I18N.Plurals,
--    I18N.Calendars, I18N.Calendar_Math, I18N.Spellout, I18N.Display_Names,
--    I18N.Emoji, I18N.Measurement, I18N.Delimiters, I18N.Person_Names
--                                -- CLDR formatting, names and data
--  * I18N.Locales, I18N.Data_Store, I18N.Runtime_Data, I18N.CLDR_Data
--                                -- locale identity and the runtime data layer
package I18N is
   pragma Preelaborate;
   pragma SPARK_Mode (On);
end I18N;
