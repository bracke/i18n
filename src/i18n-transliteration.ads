--  Transliteration: the CLDR/ICU transform engine (UTS #35 Part 3) -- a
--  rule-based rewriting system for script conversion and text transforms.
--  Rules load from share/i18n/transforms/*.i18ndata; ::NFx steps reuse
--  I18N.Normalization and ::Lower/Upper/Title reuse I18N.Case.
--
--  Transform (Text, Name) applies the named transform (e.g. "Greek-Latin",
--  "Latin-ASCII", "Any-Latin"); Name is resolved through the transform index.
package I18N.Transliteration is

   function Transform (Text : String; Name : String) return String;

   --  True when the transform data (index + at least the named transform) loads.
   function Available return Boolean;

end I18N.Transliteration;
