package body I18N.TZ_Rules is

   --  What a TZ string says, once read. Offsets are east of Greenwich in
   --  seconds (POSIX writes them the other way round, west positive).
   type Date_Form is (Julian_No_Leap, Zero_Based, Month_Week_Day);

   type Change is record
      Form    : Date_Form := Month_Week_Day;
      Day     : Integer := 0;  --  Julian day, or zero-based day
      Month   : Integer := 0;
      Week    : Integer := 0;  --  1 .. 5, 5 meaning the last
      Weekday : Integer := 0;  --  0 = Sunday
      Time    : Integer := 7_200;  --  local seconds after midnight
   end record;

   type Parsed is record
      Ok           : Boolean := False;
      Standard     : Integer := 0;
      Daylight     : Integer := 0;
      Has_Daylight : Boolean := False;
      Start_Rule   : Change;
      End_Rule     : Change;
   end record;

   function Days_From_Civil (Year, Month, Day : Integer) return Long_Long_Integer is
      --  Howard Hinnant's days_from_civil: proleptic Gregorian, any year.
      Y   : constant Long_Long_Integer :=
        Long_Long_Integer (Year) - (if Month <= 2 then 1 else 0);
      Era : constant Long_Long_Integer := (if Y >= 0 then Y else Y - 399) / 400;
      YoE : constant Long_Long_Integer := Y - Era * 400;
      M   : constant Long_Long_Integer := Long_Long_Integer (Month);
      DoY : constant Long_Long_Integer :=
        (153 * (if M > 2 then M - 3 else M + 9) + 2) / 5 + Long_Long_Integer (Day) - 1;
      DoE : constant Long_Long_Integer := YoE * 365 + YoE / 4 - YoE / 100 + DoY;
   begin
      return Era * 146_097 + DoE - 719_468;
   end Days_From_Civil;

   function Epoch_Seconds
     (Year, Month, Day : Integer;
      Hour, Minute, Second : Integer := 0)
      return Long_Long_Integer is
   begin
      return Days_From_Civil (Year, Month, 1) * 86_400
        + Long_Long_Integer (Day - 1) * 86_400
        + Long_Long_Integer (Hour) * 3_600
        + Long_Long_Integer (Minute) * 60
        + Long_Long_Integer (Second);
   end Epoch_Seconds;

   procedure Civil_Of
     (Instant : Long_Long_Integer;
      Year, Month, Day, Hour, Minute, Second : out Integer)
   is
      --  Howard Hinnant's civil_from_days.
      Days   : constant Long_Long_Integer :=
        (if Instant >= 0 then Instant / 86_400 else (Instant - 86_399) / 86_400);
      Within : constant Long_Long_Integer := Instant - Days * 86_400;
      Z      : constant Long_Long_Integer := Days + 719_468;
      Era    : constant Long_Long_Integer := (if Z >= 0 then Z else Z - 146_096) / 146_097;
      DoE    : constant Long_Long_Integer := Z - Era * 146_097;
      YoE    : constant Long_Long_Integer := (DoE - DoE / 1_460 + DoE / 36_524 - DoE / 146_096) / 365;
      DoY    : constant Long_Long_Integer := DoE - (365 * YoE + YoE / 4 - YoE / 100);
      MP     : constant Long_Long_Integer := (5 * DoY + 2) / 153;
      M      : constant Long_Long_Integer := (if MP < 10 then MP + 3 else MP - 9);
   begin
      Year   := Integer (YoE + Era * 400 + (if M <= 2 then 1 else 0));
      Month  := Integer (M);
      Day    := Integer (DoY - (153 * MP + 2) / 5 + 1);
      Hour   := Integer (Within / 3_600);
      Minute := Integer ((Within mod 3_600) / 60);
      Second := Integer (Within mod 60);
   end Civil_Of;

   function Is_Leap (Year : Integer) return Boolean is
     (Year mod 4 = 0 and then (Year mod 100 /= 0 or else Year mod 400 = 0));

   function Days_In_Month (Year, Month : Integer) return Integer is
     (case Month is
         when 2 => (if Is_Leap (Year) then 29 else 28),
         when 4 | 6 | 9 | 11 => 30,
         when others => 31);

   function Read (Rule : String) return Parsed is
      Result : Parsed;
      P      : Natural := Rule'First;

      function At_End return Boolean is (P > Rule'Last);

      function Digit return Boolean is
        (not At_End and then Rule (P) in '0' .. '9');

      --  An unsigned decimal; False when there is none.
      function Number (Value : out Integer) return Boolean is
      begin
         Value := 0;
         if not Digit then
            return False;
         end if;
         while Digit loop
            Value := Value * 10 + (Character'Pos (Rule (P)) - Character'Pos ('0'));
            if Value > 100_000 then
               return False;
            end if;
            P := P + 1;
         end loop;
         return True;
      end Number;

      --  [+-]hh[:mm[:ss]] as seconds.
      function Clock (Value : out Integer) return Boolean is
         type Units is array (1 .. 2) of Integer;
         Minutes_Then_Seconds : constant Units := [60, 1];
         Sign  : Integer := 1;
         Part  : Integer;
      begin
         Value := 0;
         if not At_End and then Rule (P) in '+' | '-' then
            Sign := (if Rule (P) = '-' then -1 else 1);
            P := P + 1;
         end if;
         if not Number (Part) then
            return False;
         end if;
         Value := Part * 3_600;
         for Unit of Minutes_Then_Seconds loop
            exit when At_End or else Rule (P) /= ':';
            P := P + 1;
            if not Number (Part) then
               return False;
            end if;
            Value := Value + Part * Unit;
         end loop;
         Value := Sign * Value;
         return True;
      end Clock;

      --  An abbreviation: letters, or anything between < and >.
      function Name return Boolean is
         Start : constant Natural := P;
      begin
         if At_End then
            return False;
         elsif Rule (P) = '<' then
            while not At_End and then Rule (P) /= '>' loop
               P := P + 1;
            end loop;
            if At_End then
               return False;
            end if;
            P := P + 1;
            return P - Start >= 3;
         end if;
         while not At_End and then Rule (P) in 'A' .. 'Z' | 'a' .. 'z' loop
            P := P + 1;
         end loop;
         return P - Start >= 3;
      end Name;

      function Date (Item : out Change) return Boolean is
         Value : Integer;
      begin
         Item := (others => <>);
         if At_End then
            return False;
         elsif Rule (P) = 'J' then
            P := P + 1;
            Item.Form := Julian_No_Leap;
            if not Number (Value) or else Value not in 1 .. 365 then
               return False;
            end if;
            Item.Day := Value;
         elsif Rule (P) = 'M' then
            P := P + 1;
            Item.Form := Month_Week_Day;
            if not Number (Item.Month) or else Item.Month not in 1 .. 12
              or else At_End or else Rule (P) /= '.'
            then
               return False;
            end if;
            P := P + 1;
            if not Number (Item.Week) or else Item.Week not in 1 .. 5
              or else At_End or else Rule (P) /= '.'
            then
               return False;
            end if;
            P := P + 1;
            if not Number (Item.Weekday) or else Item.Weekday not in 0 .. 6 then
               return False;
            end if;
         else
            Item.Form := Zero_Based;
            if not Number (Value) or else Value not in 0 .. 365 then
               return False;
            end if;
            Item.Day := Value;
         end if;
         if not At_End and then Rule (P) = '/' then
            P := P + 1;
            if not Clock (Item.Time) then
               return False;
            end if;
         end if;
         return True;
      end Date;

      West : Integer;
   begin
      if not Name or else not Clock (West) then
         return Result;
      end if;
      Result.Standard := -West;
      Result.Daylight := Result.Standard;
      if At_End then
         Result.Ok := True;
         return Result;
      end if;

      if not Name then
         return Result;
      end if;
      Result.Has_Daylight := True;
      Result.Daylight := Result.Standard + 3_600;
      if not At_End and then Rule (P) /= ',' then
         if not Clock (West) then
            return Result;
         end if;
         Result.Daylight := -West;
      end if;

      --  zic always writes the rules out; a string without them leaves the
      --  dates to the implementation, which this does not guess at.
      if At_End or else Rule (P) /= ',' then
         return Result;
      end if;
      P := P + 1;
      if not Date (Result.Start_Rule) or else At_End or else Rule (P) /= ',' then
         return Result;
      end if;
      P := P + 1;
      if not Date (Result.End_Rule) or else not At_End then
         return Result;
      end if;
      Result.Ok := True;
      return Result;
   end Read;

   --  The UTC instant at which Item happens in Year, its time read as local
   --  time at Offset.
   function Instant_Of (Item : Change; Year : Integer; Offset : Integer) return Long_Long_Integer is
      Day_Start : Long_Long_Integer;
   begin
      case Item.Form is
         when Julian_No_Leap =>
            --  Day 1 .. 365, February 29 never counted.
            Day_Start :=
              Days_From_Civil (Year, 1, 1)
              + Long_Long_Integer (Item.Day - 1)
              + (if Is_Leap (Year) and then Item.Day >= 60 then 1 else 0);
         when Zero_Based =>
            Day_Start := Days_From_Civil (Year, 1, 1) + Long_Long_Integer (Item.Day);
         when Month_Week_Day =>
            declare
               First      : constant Long_Long_Integer := Days_From_Civil (Year, Item.Month, 1);
               --  1970-01-01 was a Thursday.
               First_Day  : constant Integer := Integer ((First + 4) mod 7);
               Day        : Integer := 1 + (Item.Weekday - First_Day + 7) mod 7 + (Item.Week - 1) * 7;
            begin
               while Day > Days_In_Month (Year, Item.Month) loop
                  Day := Day - 7;
               end loop;
               Day_Start := First + Long_Long_Integer (Day - 1);
            end;
      end case;
      return Day_Start * 86_400 + Long_Long_Integer (Item.Time) - Long_Long_Integer (Offset);
   end Instant_Of;

   procedure Changes_In
     (Rule         : String;
      Year         : Integer;
      Starts       : out Long_Long_Integer;
      Ends         : out Long_Long_Integer;
      Has_Daylight : out Boolean;
      Valid        : out Boolean)
   is
      Read_Rule : constant Parsed := Read (Rule);
   begin
      Starts := 0;
      Ends := 0;
      Valid := Read_Rule.Ok;
      Has_Daylight := Read_Rule.Ok and then Read_Rule.Has_Daylight;
      if Has_Daylight then
         --  Daylight time starts at a standard-time clock reading and ends at
         --  a daylight-time one.
         Starts := Instant_Of (Read_Rule.Start_Rule, Year, Read_Rule.Standard);
         Ends := Instant_Of (Read_Rule.End_Rule, Year, Read_Rule.Daylight);
      end if;
   end Changes_In;

   function Year_Of (Instant : Long_Long_Integer) return Integer is
      --  Within a year of the truth, then corrected: the boundary of a year
      --  is a date, and Epoch_Seconds knows where it is.
      Year : Integer := 1970 + Integer (Instant / 31_556_952);
   begin
      while Epoch_Seconds (Year, 1, 1) > Instant loop
         Year := Year - 1;
      end loop;
      while Epoch_Seconds (Year + 1, 1, 1) <= Instant loop
         Year := Year + 1;
      end loop;
      return Year;
   end Year_Of;

   --  Whether daylight time is in effect at Instant under a read rule: the
   --  latest change among the year before, this one and the next, at or
   --  before the instant, decides. A rule may end daylight time on the last
   --  evening of one year and start it again at the same moment for the next
   --  (Casablanca, written by an older zic as "XXX-2<+01>-1,0/0,J365/23"),
   --  so a year's own two changes alone do not decide its last hours; at a
   --  tie the start wins.
   function In_Daylight (Read_Rule : Parsed; Instant : Long_Long_Integer) return Boolean is
      Year        : constant Integer := Year_Of (Instant);
      Latest      : Long_Long_Integer := Long_Long_Integer'First;
      Daylight    : Boolean := False;
   begin
      if not Read_Rule.Has_Daylight then
         return False;
      end if;
      for Around in Year - 1 .. Year + 1 loop
         declare
            Starts : constant Long_Long_Integer :=
              Instant_Of (Read_Rule.Start_Rule, Around, Read_Rule.Standard);
            Ends   : constant Long_Long_Integer :=
              Instant_Of (Read_Rule.End_Rule, Around, Read_Rule.Daylight);
         begin
            if Ends <= Instant and then Ends > Latest then
               Latest := Ends;
               Daylight := False;
            end if;
            if Starts <= Instant and then Starts >= Latest then
               Latest := Starts;
               Daylight := True;
            end if;
         end;
      end loop;
      return Daylight;
   end In_Daylight;

   function Offset_At
     (Rule    : String;
      Instant : Long_Long_Integer;
      Valid   : out Boolean)
      return Integer
   is
      Read_Rule : constant Parsed := Read (Rule);
   begin
      Valid := Read_Rule.Ok;
      if not Read_Rule.Ok then
         return 0;
      end if;
      return (if In_Daylight (Read_Rule, Instant) then Read_Rule.Daylight else Read_Rule.Standard);
   end Offset_At;

   function Daylight_At
     (Rule    : String;
      Instant : Long_Long_Integer;
      Valid   : out Boolean)
      return Boolean
   is
      Read_Rule : constant Parsed := Read (Rule);
   begin
      Valid := Read_Rule.Ok;
      return Read_Rule.Ok and then In_Daylight (Read_Rule, Instant);
   end Daylight_At;

   function Daylight_Within
     (Rule     : String;
      From, To : Long_Long_Integer;
      Valid    : out Boolean)
      return Boolean
   is
      Read_Rule : constant Parsed := Read (Rule);
   begin
      Valid := Read_Rule.Ok;
      if not Read_Rule.Ok or else not Read_Rule.Has_Daylight then
         return False;
      elsif In_Daylight (Read_Rule, From) then
         return True;
      end if;
      --  Otherwise daylight time is in effect in the span exactly when one
      --  of its starts falls in it.
      for Year in Year_Of (From) - 1 .. Year_Of (To) + 1 loop
         declare
            Starts : constant Long_Long_Integer :=
              Instant_Of (Read_Rule.Start_Rule, Year, Read_Rule.Standard);
         begin
            if Starts > From and then Starts <= To and then In_Daylight (Read_Rule, Starts) then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Daylight_Within;

end I18N.TZ_Rules;
