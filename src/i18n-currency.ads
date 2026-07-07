private package I18N.Currency is

   Max_Formatted_Length : constant := 160;

   function Is_Valid_Code (Code : String) return Boolean;

   procedure Format_Into
     (Amount_Text   : String;
      Currency_Code : String;
      Locale        : String;
      Target        : in out String;
      Last          : out Natural;
      Ok            : out Boolean;
      Overflow      : out Boolean);

end I18N.Currency;
