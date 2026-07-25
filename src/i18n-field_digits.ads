private package I18N.Field_Digits is
   --  Shared numeric-field rendering for the composite formatters that seat
   --  their own digits inside a fixed layout (a duration's H:MM:SS, a byte
   --  size's scaled count) rather than going through I18N.Number_Format's full
   --  pattern engine. Each digit is localized the same way a top-level number's
   --  digits are -- process-wide "digit" override, then the on-the-fly-aware
   --  I18N.Number_Format.Digit_Text -- so a composite formatter matches the
   --  glyphs a bare {number} would produce.

   --  Append Text to Target, tracking the write position in Last and setting
   --  Overflow once Target is full (further writes are dropped).
   procedure Put
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Text     : String);

   --  Append the localized glyph for a Latin digit '0' .. '9'.
   procedure Put_Digit
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit    : Character);

   --  Append Value as localized digits, left-padded with localized zeros to at
   --  least Width digits.
   procedure Put_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Natural;
      Width    : Natural := 1);

   --  Append a wide non-negative Value as localized digits.
   procedure Put_Long_Long_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Long_Long_Integer);

end I18N.Field_Digits;
