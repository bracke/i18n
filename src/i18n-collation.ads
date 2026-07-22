--  Collation: locale-aware string comparison and sort keys, the Unicode
--  Collation Algorithm (UTS #10) over the DUCET, reusing the Phase-0
--  normalization engine (input is NFD-normalized first). CLDR root and locale
--  tailorings layer on top (Locale parameter).
--
--  Sort_Key returns an opaque byte string whose ordinary String "<" reproduces
--  the collation order; Compare returns -1/0/1.
package I18N.Collation is

   type Strength is (Primary, Secondary, Tertiary, Quaternary, Identical);

   type Variable_Handling is (Non_Ignorable, Shifted);

   function Sort_Key
     (Text     : String;
      Locale   : String := "";
      Level    : Strength := Tertiary;
      Variable : Variable_Handling := Shifted) return String;

   function Compare
     (A, B     : String;
      Locale   : String := "";
      Level    : Strength := Tertiary;
      Variable : Variable_Handling := Shifted) return Integer;

   function Available return Boolean;

end I18N.Collation;
