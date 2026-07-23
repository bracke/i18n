with Ada.Containers.Indefinite_Vectors;

private package I18N.Runtime_Data is

   --  Process-wide deterministic runtime data overrides loaded from external
   --  text. Formatters consult this package before generated CLDR/tzdb data.

   --  Parse errors from Load_Text, each a formatted message. The platform data
   --  layer reports errors this way rather than depending on the message-layer
   --  I18N.Diagnostics contract; callers adapt these to their own diagnostics.
   package Error_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   procedure Clear;

   function Load_Text
     (Source_Name : String;
      Text        : String;
      Errors      : in out Error_Vectors.Vector)
      return Boolean;

   function Locale_Text
     (Locale : String;
      Field  : String;
      Found  : out Boolean)
      return String;

   function Locale_Indexed_Text
     (Locale : String;
      Field  : String;
      Index  : Natural;
      Found  : out Boolean)
      return String;

   function Locale_Digit_Text
     (Locale : String;
      Digit  : Character;
      Found  : out Boolean)
      return String;

   function Locale_Boolean
     (Locale : String;
      Field  : String;
      Found  : out Boolean)
      return Boolean;

   function Time_Zone_Base_Offset_Minutes
     (Zone  : String;
      Found : out Boolean)
      return Integer;

   function Time_Zone_Offset_Seconds_At_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Found  : out Boolean)
      return Integer;

   function Currency_Text
     (Code  : String;
      Field : String;
      Found : out Boolean)
      return String;

   function Currency_Text
     (Locale : String;
      Code   : String;
      Field  : String;
      Found  : out Boolean)
      return String;

   function Currency_Natural
     (Code  : String;
      Field : String;
      Found : out Boolean)
      return Natural;

   function Plural_Category
     (Kind   : String;
      Locale : String;
      Value  : Long_Long_Integer;
      Found  : out Boolean)
      return String;

   function Plural_Rule_Family
     (Kind   : String;
      Locale : String;
      Found  : out Boolean)
      return String;

   function Plural_Category_Rule
     (Kind     : String;
      Locale   : String;
      Category : String;
      Found    : out Boolean)
      return String;

   function Spellout_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Found  : out Boolean)
      return String;

   function Spellout_Signed_Text
     (Locale : String;
      Kind   : String;
      Value  : Integer;
      Found  : out Boolean)
      return String;

   function Spellout_Value_Text
     (Locale     : String;
      Kind       : String;
      Value_Text : String;
      Found      : out Boolean)
      return String;

   function Spellout_Decimal_Separator
     (Locale : String;
      Found  : out Boolean)
      return String;

   function Spellout_Rule_Text
     (Locale : String;
      Kind   : String;
      Value  : Natural;
      Base   : out Natural;
      Divisor : out Natural;
      Found  : out Boolean)
      return String;

   function Spellout_Special_Rule_Text
     (Locale : String;
      Kind   : String;
      Name   : String;
      Found  : out Boolean)
      return String;

end I18N.Runtime_Data;
