package I18N.Number_Format is

   Max_Formatted_Length : constant := 160;

   function Is_Valid_Style (Style : String) return Boolean;

   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String := "";
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

   --  On-the-fly-aware number primitives, for callers that render digits or a
   --  decimal point themselves (e.g. inside a unit or relative-time pattern)
   --  rather than through Format_Into. Both consult the narrowed-out locale
   --  data file before the compiled tables.

   --  The locale's glyph for a Latin digit '0' .. '9'.
   function Digit_Text (Locale : String; Digit : Character) return String;

   --  The locale's decimal separator.
   function Decimal_Separator (Locale : String) return String;

end I18N.Number_Format;
