--  On-the-fly-aware digital-clock duration formatting.
--
--  A peer of I18N.Number_Format and I18N.Unit_Format: it renders a whole-second
--  count as the locale's H:MM:SS clock layout -- localized digits and the
--  locale's duration field separator. This is the exact, deterministic clock
--  form (not the human "3 hours 5 minutes" phrasing, which is editorial and
--  belongs elsewhere). Message renderers delegate here instead of composing the
--  fields and reading I18N.CLDR_Data directly.
package I18N.Duration_Format is

   Max_Formatted_Length : constant := 64;

   --  Render Value_Text -- a non-negative whole number of seconds in canonical
   --  decimal -- into Target as H:MM:SS for Locale. Last is the byte length
   --  written from Target'First. Ok is False (and nothing meaningful written)
   --  when Value_Text is not a natural number. Overflow is True when Target was
   --  too small to hold the result.
   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

end I18N.Duration_Format;
