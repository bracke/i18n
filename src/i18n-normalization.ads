--  Unicode normalization (UAX #15): NFC / NFD / NFKC / NFKD over UTF-8 text.
--  Backed by the global data file share/i18n/normalization.i18ndata (canonical
--  and compatibility decompositions, combining classes, and the canonical
--  composition table), loaded once. Hangul is handled algorithmically.
--
--  Foundational for collation, segmentation, and transliteration. When the data
--  file is absent, Normalize returns its input unchanged and Available is False.
package I18N.Normalization is

   type Form is (NFC, NFD, NFKC, NFKD);

   --  Normalize UTF-8 Text to the given form.
   function Normalize (Text : String; To : Form) return String;

   --  True when Text is already in the given normal form.
   function Is_Normalized (Text : String; To : Form) return Boolean;

   --  Canonical combining class of a code point (0 for starters). Exposed for
   --  the collation engine's discontiguous-contraction rule.
   function Combining_Class (Code_Point : Natural) return Natural;

   --  True when the normalization data file is installed and loaded.
   function Available return Boolean;

end I18N.Normalization;
