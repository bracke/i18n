with I18N.CLDR_Data;
with I18N.Field_Digits;

package body I18N.Duration_Format is

   function Is_Natural_Text (Text : String) return Boolean is
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if C not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Natural_Text;

   function Natural_Value (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for C of Text loop
         Result := Result * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;
      return Result;
   end Natural_Value;

   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Total   : Natural;
      Hours   : Natural;
      Minutes : Natural;
      Seconds : Natural;
   begin
      Last := 0;
      Overflow := False;
      Ok := False;
      if not Is_Natural_Text (Value_Text) then
         return;
      end if;

      Total := Natural_Value (Value_Text);
      Hours := Total / 3_600;
      Minutes := (Total mod 3_600) / 60;
      Seconds := Total mod 60;

      I18N.Field_Digits.Put_Natural (Target, Last, Overflow, Locale, Hours);
      I18N.Field_Digits.Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Duration_Field_Separator (Locale));
      I18N.Field_Digits.Put_Natural
        (Target, Last, Overflow, Locale, Minutes, 2);
      I18N.Field_Digits.Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Duration_Field_Separator (Locale));
      I18N.Field_Digits.Put_Natural
        (Target, Last, Overflow, Locale, Seconds, 2);
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Into;

end I18N.Duration_Format;
