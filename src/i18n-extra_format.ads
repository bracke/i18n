private package I18N.Extra_Format is

   Max_Formatted_Length : constant := 256;

   type Extra_Kind is
     (Duration,
      Byte_Size,
      Unit,
      Relative_Time,
      List);

   function Is_Valid_Option
     (Kind   : Extra_Kind;
      Option : String)
      return Boolean;

   procedure Format_Into
     (Kind     : Extra_Kind;
      Value    : String;
      Locale   : String;
      Option   : String;
      Target   : in out String;
      Last     : out Natural;
      Ok       : out Boolean;
      Overflow : out Boolean);

end I18N.Extra_Format;
