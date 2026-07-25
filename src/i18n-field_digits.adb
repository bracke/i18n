with I18N.Number_Format;
with I18N.Runtime_Data;

package body I18N.Field_Digits is

   function Integer_Image (Value : Long_Long_Integer) return String is
      Raw : constant String := Long_Long_Integer'Image (Value);
   begin
      --  Long_Long_Integer'Image prefixes a space on non-negative values; the
      --  callers only pass non-negative values, so drop that leading space.
      return Raw (Raw'First + 1 .. Raw'Last);
   end Integer_Image;

   procedure Put
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Text     : String)
   is
   begin
      for C of Text loop
         if Last >= Target'Length then
            Overflow := True;
            return;
         end if;

         Target (Target'First + Last) := C;
         Last := Last + 1;
      end loop;
   end Put;

   procedure Put_Digit
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Digit    : Character)
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           "digit",
           Character'Pos (Digit) - Character'Pos ('0'),
           Found);
   begin
      Put
        (Target,
         Last,
         Overflow,
         (if Found then Value
          else I18N.Number_Format.Digit_Text (Locale, Digit)));
   end Put_Digit;

   procedure Put_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Natural;
      Width    : Natural := 1)
   is
      Raw : constant String := Integer_Image (Long_Long_Integer (Value));
   begin
      if Raw'Length < Width then
         for Pad in 1 .. Width - Raw'Length loop
            Put_Digit (Target, Last, Overflow, Locale, '0');
         end loop;
      end if;

      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Natural;

   procedure Put_Long_Long_Natural
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Value    : Long_Long_Integer)
   is
      Raw : constant String := Integer_Image (Value);
   begin
      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Long_Long_Natural;

end I18N.Field_Digits;
