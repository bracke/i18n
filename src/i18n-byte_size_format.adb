with I18N.CLDR_Data;
with I18N.Field_Digits;
with I18N.Runtime_Data;

package body I18N.Byte_Size_Format is

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

   function Natural_Value (Text : String) return Long_Long_Integer is
      Result : Long_Long_Integer := 0;
   begin
      for C of Text loop
         Result :=
           Result * 10
           + Long_Long_Integer (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Result;
   end Natural_Value;

   --  The locale's separator between the scaled value and its unit label, with
   --  the process-wide runtime override taking precedence over the compiled
   --  table.
   function Value_Separator (Locale : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "unit_value_separator", Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Unit_Value_Separator (Locale));
   end Value_Separator;

   procedure Format_Into
     (Value_Text : String;
      Locale     : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Amount : Long_Long_Integer;
      Scaled : Long_Long_Integer;
      Scale  : Long_Long_Integer := 1;
   begin
      Last := 0;
      Overflow := False;
      Ok := False;
      if not Is_Natural_Text (Value_Text) then
         return;
      end if;

      Amount := Natural_Value (Value_Text);
      if Amount >= 1_125_899_906_842_624 then
         Scale := 1_125_899_906_842_624;
         Scaled :=
           (Amount + 562_949_953_421_312) / 1_125_899_906_842_624;
      elsif Amount >= 1_099_511_627_776 then
         Scale := 1_099_511_627_776;
         Scaled := (Amount + 549_755_813_888) / 1_099_511_627_776;
      elsif Amount >= 1_073_741_824 then
         Scale := 1_073_741_824;
         Scaled := (Amount + 536_870_912) / 1_073_741_824;
      elsif Amount >= 1_048_576 then
         Scale := 1_048_576;
         Scaled := (Amount + 524_288) / 1_048_576;
      elsif Amount >= 1_024 then
         Scale := 1_024;
         Scaled := (Amount + 512) / 1_024;
      else
         Scaled := Amount;
      end if;

      I18N.Field_Digits.Put_Long_Long_Natural
        (Target, Last, Overflow, Locale, Scaled);
      I18N.Field_Digits.Put (Target, Last, Overflow, Value_Separator (Locale));
      I18N.Field_Digits.Put
        (Target, Last, Overflow,
         I18N.CLDR_Data.Byte_Size_Unit_Label (Scale));
      Ok := not Overflow;
   exception
      when Constraint_Error =>
         Ok := False;
   end Format_Into;

end I18N.Byte_Size_Format;
