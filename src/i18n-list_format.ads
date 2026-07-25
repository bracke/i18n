--  On-the-fly-aware list separators.
--
--  A peer of I18N.Number_Format and I18N.Date_Time_Format: it returns the
--  localized separators used to join list items ("a, b, and c" / "a, b et
--  c") from the runtime "formats" data file. Message renderers delegate here
--  instead of reading I18N.CLDR_Data directly.
package I18N.List_Format is

   --  The separator for the given list Family ("standard" or "or") and Part
   --  ("start", "middle", "end"/"final", "pair", "item").
   function Separator (Locale : String; Family : String; Part : String)
     return String;

end I18N.List_Format;
