private package I18N.Date_Time_Format is

   Max_Formatted_Length : constant := 256;

   procedure Format_Date_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

   procedure Format_Time_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

   procedure Format_Date_Time_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean);

end I18N.Date_Time_Format;
