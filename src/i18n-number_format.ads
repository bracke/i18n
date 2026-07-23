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

end I18N.Number_Format;
