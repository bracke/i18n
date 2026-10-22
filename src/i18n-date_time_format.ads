package I18N.Date_Time_Format is

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

   --  Zone's short specific name ("EST", "BST") in Locale at the given UTC
   --  date and time, from CLDR: the zone's own short name, else its
   --  metazone's at that date, standard or daylight as the zone keeps then.
   --  "" when CLDR gives the zone none there -- where "z" in a pattern would
   --  write the localized GMT format instead.
   function Short_Zone_Name
     (Locale : String;
      Zone   : String;
      Year, Month, Day, Hour, Minute, Second : Natural)
      return String;

end I18N.Date_Time_Format;
