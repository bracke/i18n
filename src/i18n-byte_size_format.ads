--  On-the-fly-aware binary byte-size formatting.
--
--  A peer of I18N.Number_Format and I18N.Unit_Format: it renders a byte count
--  as an exact IEC binary size -- the value scaled to the largest fitting
--  1024-power with localized digits, the locale's value separator, and the IEC
--  unit label (B, KiB, MiB, ...). This is the exact, deterministic form (not
--  the approximate human "2.5 MB" phrasing, which is editorial and belongs
--  elsewhere). Message renderers delegate here instead of scaling the value and
--  reading I18N.CLDR_Data directly.
package I18N.Byte_Size_Format is

   Max_Formatted_Length : constant := 64;

   --  Render Value_Text -- a non-negative whole number of bytes in canonical
   --  decimal -- into Target as a localized IEC binary size for Locale. Last is
   --  the byte length written from Target'First. Ok is False (and nothing
   --  meaningful written) when Value_Text is not a natural number. Overflow is
   --  True when Target was too small to hold the result.
   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

end I18N.Byte_Size_Format;
