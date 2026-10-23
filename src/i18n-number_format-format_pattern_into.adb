separate (I18N.Number_Format)
procedure Format_Pattern_Into
  (Pattern    : String;
   First      : String;
   Second     : String;
   Locale     : String;
   Style      : String;
   Target     : in out String;
   Last       : out Natural;
   Ok         : out Boolean;
   Overflow   : out Boolean)
is
   En_Dash : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#93#)];
   Joining : constant String :=
     (if Pattern /= "" then Pattern elsif Second = "" then "~{0}" else "{0}" & En_Dash & "{1}");
   I       : Positive := Joining'First;

   procedure Put (Text : String) is
   begin
      if Last + Text'Length > Target'Last then
         Overflow := True;
      else
         Target (Last + 1 .. Last + Text'Length) := Text;
         Last := Last + Text'Length;
      end if;
   end Put;
begin
   Last := Target'First - 1;
   Ok := False;
   Overflow := False;
   while I <= Joining'Last and then not Overflow loop
      if I + 2 <= Joining'Last and then Joining (I) = '{' and then Joining (I + 2) = '}'
        and then Joining (I + 1) in '0' | '1'
      then
         declare
            Value       : constant String := (if Joining (I + 1) = '0' then First else Second);
            Buffer      : String (1 .. Max_Formatted_Length);
            Buffer_Last : Natural;
            Done, Full  : Boolean;
         begin
            if Value = "" then
               return;
            end if;
            Format_Into (Value, Locale, Style, Buffer, Buffer_Last, Done, Full);
            if not Done or else Full then
               Overflow := Full;
               return;
            end if;
            Put (Buffer (1 .. Buffer_Last));
         end;
         I := I + 3;
      else
         Put ([1 => Joining (I)]);
         I := I + 1;
      end if;
   end loop;
   Ok := not Overflow;
end Format_Pattern_Into;
