--  CLDR quotation delimiters per locale, from the "display-names" data file.
--  Falls back through the locale's parents to root, then to the English marks,
--  so a value is always returned.
package I18N.Delimiters is

   function Quotation_Start (Locale : String) return String;
   function Quotation_End (Locale : String) return String;
   function Alternate_Quotation_Start (Locale : String) return String;
   function Alternate_Quotation_End (Locale : String) return String;

end I18N.Delimiters;
