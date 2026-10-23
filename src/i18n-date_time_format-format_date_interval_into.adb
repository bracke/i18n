separate (I18N.Date_Time_Format)
procedure Format_Date_Interval_Into
  (From_Text : String;
   To_Text   : String;
   Locale    : String;
   Style     : String;
   Target    : in out String;
   Last      : out Natural;
   Ok        : out Boolean;
   Overflow  : out Boolean)
is
   Effective_Style : constant String := Normalize_Skeleton_Style_Alias (Style);
   Style_Only      : constant String := Style_Name (Effective_Style);

   type Date_Fields is record
      Year, Month, Day                         : Natural := 0;
      Display_Year, Display_Month, Display_Day : Natural := 0;
   end record;

   --  Text as a date, with its fields in the locale's calendar.
   function Read (Text : String; Item : out Date_Fields) return Boolean is
      Hour, Minute, Second, Nanosecond : Natural;
      Has_Second, Parsed, Supported     : Boolean;
   begin
      Item := (others => 0);
      Parse_Date_Time_Value
        (Value_Text => Text, Option => Effective_Style, Locale => Locale, Need_Date => True, Need_Time => False,
         Year => Item.Year, Month => Item.Month, Day => Item.Day, Hour => Hour, Minute => Minute,
         Second => Second, Nanosecond => Nanosecond, Has_Second => Has_Second, Ok => Parsed);
      if not Parsed then
         return False;
      end if;
      Item.Display_Year := Item.Year;
      Item.Display_Month := Item.Month;
      Item.Display_Day := Item.Day;
      To_Display_Calendar (Locale, Item.Display_Year, Item.Display_Month, Item.Display_Day, Supported);
      return Supported;
   end Read;

   procedure Write (Pattern : String; Item : Date_Fields; Done : out Boolean) is
   begin
      Format_Skeleton_Into
        (Skeleton => Pattern, Style => Effective_Style, Locale => Locale, Year => Item.Display_Year,
         Related_Year => Item.Year, Month => Item.Display_Month, Day => Item.Display_Day, Hour => 0,
         Minute => 0, Second => 0, Nanosecond => 0, Target => Target, Last => Last, Overflow => Overflow,
         Ok => Done, Raw_Pattern => True);
   end Write;

   --  Text formatted whole in Style, appended to Target.
   procedure Write_Whole (Text : String; Done : out Boolean) is
      Buffer       : String (1 .. Max_Formatted_Length);
      Buffer_Last  : Natural;
      Buffer_Full  : Boolean;
   begin
      Format_Date_Into (Text, Locale, Style, Buffer, Buffer_Last, Done, Buffer_Full);
      if not Done or else Buffer_Full then
         Done := False;
      elsif Last + Buffer_Last > Target'Last then
         Overflow := True;
         Done := False;
      else
         Target (Last + 1 .. Last + Buffer_Last) := Buffer (1 .. Buffer_Last);
         Last := Last + Buffer_Last;
      end if;
   end Write_Whole;

   procedure Write_Text (Text : String) is
   begin
      if Last + Text'Length > Target'Last then
         Overflow := True;
      else
         Target (Last + 1 .. Last + Text'Length) := Text;
         Last := Last + Text'Length;
      end if;
   end Write_Text;

   From, To : Date_Fields;
   Done     : Boolean;
begin
   Last := Target'First - 1;
   Ok := False;
   Overflow := False;
   if not Read (From_Text, From) or else not Read (To_Text, To) then
      return;
   end if;
   if From.Display_Year = To.Display_Year and then From.Display_Month = To.Display_Month
     and then From.Display_Day = To.Display_Day
   then
      Format_Date_Into (From_Text, Locale, Style, Target, Last, Ok, Overflow);
      return;
   end if;

   if Is_Skeleton (Style_Only) then
      declare
         Field   : constant String :=
           (if From.Display_Year /= To.Display_Year then "y"
            elsif From.Display_Month /= To.Display_Month then "M" else "d");
         Found   : Boolean;
         Pattern : constant String :=
           I18N.Locale_Data.Lookup ("date_interval", Locale, Skeleton_Text (Style_Only) & ":" & Field, Found);
         Split   : constant Natural := (if Found then Interval_Second_Half (Pattern) else 0);

      begin
         if Split > Pattern'First
           and then Interval_Writes_Field (Pattern (Pattern'First .. Split - 1), Field (Field'First))
         then
            Write (Pattern (Pattern'First .. Split - 1), From, Done);
            if Done and then not Overflow then
               Write (Pattern (Split .. Pattern'Last), To, Done);
               Ok := Done and then not Overflow;
               if Ok then
                  return;
               end if;
            end if;
            Last := Target'First - 1;
            Overflow := False;
         end if;
      end;
   end if;

   --  The fallback: both dates whole, joined by "{0} – {1}".
   declare
      Found    : Boolean;
      Fallback : constant String := I18N.Locale_Data.Lookup ("date_interval", Locale, "fallback", Found);
      En_Dash  : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#93#)];
      Joining  : constant String := (if Found and then Fallback /= "" then Fallback else "{0} " & En_Dash & " {1}");
      I        : Positive := Joining'First;
   begin
      while I <= Joining'Last loop
         if I + 2 <= Joining'Last and then Joining (I) = '{' and then Joining (I + 2) = '}'
           and then Joining (I + 1) in '0' | '1'
         then
            Write_Whole ((if Joining (I + 1) = '0' then From_Text else To_Text), Done);
            if not Done then
               return;
            end if;
            I := I + 3;
         else
            Write_Text ([1 => Joining (I)]);
            I := I + 1;
         end if;
      end loop;
      Ok := not Overflow;
   end;
end Format_Date_Interval_Into;
