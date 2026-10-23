separate (I18N.Date_Time_Format)
procedure Format_Date_Time_Interval_Into
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

   --  The moment's day and time where the style shows it (its zone applied).
   procedure Read
     (Text : String; Year, Month, Day : out Natural; Clock : out String; Good : out Boolean)
   is
      Hour, Minute, Second, Nanosecond : Natural;
      Has_Second                       : Boolean;

      function Two (Value : Natural) return String is
        ([Character'Val (Character'Pos ('0') + Value / 10), Character'Val (Character'Pos ('0') + Value mod 10)]);
   begin
      Parse_Date_Time_Value
        (Value_Text => Text, Option => Effective_Style, Locale => Locale, Need_Date => True, Need_Time => True,
         Year => Year, Month => Month, Day => Day, Hour => Hour, Minute => Minute,
         Second => Second, Nanosecond => Nanosecond, Has_Second => Has_Second, Ok => Good);
      Clock := (if Good then Two (Hour mod 100) & ":" & Two (Minute mod 100) & ":" & Two (Second mod 100)
                else "00:00:00");
   end Read;

   --  The style's time fields alone ("::yMMMdjm" -> "::jm").
   function Time_Style return String is
      Skeleton : constant String := Skeleton_Text (Style_Only);
      Result   : String (1 .. Skeleton'Length + 2);
      Count    : Natural := 2;
   begin
      Result (1 .. 2) := "::";
      for C of Skeleton loop
         if C in 'h' | 'H' | 'k' | 'K' | 'j' | 'J' | 'C' | 'm' | 's' | 'a' | 'b' | 'B' then
            Count := Count + 1;
            Result (Count) := C;
         end if;
      end loop;
      return Result (1 .. Count);
   end Time_Style;

   Year_1, Month_1, Day_1, Year_2, Month_2, Day_2 : Natural;
   Clock_1, Clock_2                               : String (1 .. 8);
   Good_1, Good_2                                 : Boolean;
   Whole_1, Whole_2 : String (1 .. Max_Formatted_Length);
   Last_1, Last_2   : Natural;
   Ok_1, Ok_2, Full : Boolean;
begin
   Last := Target'First - 1;
   Ok := False;
   Overflow := False;
   Read (From_Text, Year_1, Month_1, Day_1, Clock_1, Good_1);
   Read (To_Text, Year_2, Month_2, Day_2, Clock_2, Good_2);
   if not Good_1 or else not Good_2 then
      return;
   end if;
   Format_Date_Time_Into (From_Text, Locale, Style, Whole_1, Last_1, Ok_1, Full);
   Format_Date_Time_Into (To_Text, Locale, Style, Whole_2, Last_2, Ok_2, Full);
   if not Ok_1 or else not Ok_2 then
      return;
   end if;

   --  One day: the first moment as written, its time replaced by the
   --  interval of the two times.
   if Year_1 = Year_2 and then Month_1 = Month_2 and then Day_1 = Day_2 and then Is_Skeleton (Style_Only) then
      declare
         Time_Only  : String (1 .. Max_Formatted_Length);
         Time_Last  : Natural;
         Times      : String (1 .. Max_Formatted_Length);
         Times_Last : Natural;
         Done, Long : Boolean;
         Whole      : constant String := Whole_1 (1 .. Last_1);
      begin
         Format_Time_Into (Clock_1, Locale, Time_Style, Time_Only, Time_Last, Done, Long);
         if Done and then Time_Last > 0 and then Time_Last <= Whole'Length then
            Format_Time_Interval_Into
              (Clock_1, Clock_2, Locale, Time_Style, Times, Times_Last, Done, Long);
            if Done and then Whole (Whole'Last - Time_Last + 1 .. Whole'Last) = Time_Only (1 .. Time_Last) then
               Join_Interval
                 ("{0}{1}", Whole (Whole'First .. Whole'Last - Time_Last), Times (1 .. Times_Last), Target, Last,
                  Overflow);
               Ok := not Overflow;
               return;
            elsif Done and then Whole (Whole'First .. Whole'First + Time_Last - 1) = Time_Only (1 .. Time_Last) then
               Join_Interval
                 ("{0}{1}", Times (1 .. Times_Last), Whole (Whole'First + Time_Last .. Whole'Last), Target, Last,
                  Overflow);
               Ok := not Overflow;
               return;
            end if;
         end if;
      end;
   end if;

   Join_Interval
     (Interval_Fallback (Locale),
      Whole_1 (1 .. Last_1), Whole_2 (1 .. Last_2), Target, Last, Overflow);
   Ok := not Overflow;
end Format_Date_Time_Interval_Into;
