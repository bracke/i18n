--  Unicode case mapping (simple + full, from UnicodeData and SpecialCasing),
--  backed by share/i18n/uprops.i18ndata. Handles one-to-many mappings (ß → SS)
--  and the context/locale-sensitive rules (Greek final sigma, Turkish/Azeri
--  dotless i, Lithuanian). Input and output are UTF-8.
package I18N.Casing is

   function To_Lower (Text : String; Locale : String := "") return String;
   function To_Upper (Text : String; Locale : String := "") return String;
   function To_Title (Text : String; Locale : String := "") return String;

   function Available return Boolean;

   --  The Unicode General_Category of a code point ("Sc", "Lu", "Zs"), from
   --  the same UCD data; "Cn" where the data is missing or the code point is
   --  unassigned.
   function General_Category (Code_Point : Natural) return String;

end I18N.Casing;
