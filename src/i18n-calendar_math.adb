package body I18N.Calendar_Math is

   subtype LI is Long_Long_Integer;

   --  Floor division and modulus (unlike Ada '/', 'rem' which truncate).
   function FDiv (A, B : LI) return LI is
      Q : constant LI := A / B;
      R : constant LI := A rem B;
   begin
      if R /= 0 and then ((R < 0) /= (B < 0)) then
         return Q - 1;
      else
         return Q;
      end if;
   end FDiv;

   function FMod (A, B : LI) return LI is (A - B * FDiv (A, B));

   function Ceil (A, B : LI) return LI is (FDiv (A + B - 1, B));

   --  Epochs (Rata Die).
   Julian_Epoch   : constant LI := -1;
   Islamic_Epoch  : constant LI := 227015;
   Coptic_Epoch   : constant LI := 103605;
   Ethiopic_Epoch : constant LI := 2796;
   Persian_Epoch  : constant LI := 226896;
   Hebrew_Epoch   : constant LI := -1373427;

   function Mk (Y : LI; M, D : LI) return Date is
     (Year => Y, Month => Positive (M), Day => Positive (D));

   --  ------------------------------------------------------------------
   --  Gregorian
   --  ------------------------------------------------------------------

   function Greg_Leap (Y : LI) return Boolean is
     (FMod (Y, 4) = 0
      and then (FMod (Y, 100) /= 0 or else FMod (Y, 400) = 0));

   function Greg_Fixed (Y, M, D : LI) return LI is
     (365 * (Y - 1) + FDiv (Y - 1, 4) - FDiv (Y - 1, 100) + FDiv (Y - 1, 400)
      + FDiv (367 * M - 362, 12)
      + (if M <= 2 then 0 elsif Greg_Leap (Y) then -1 else -2)
      + D);

   function Greg_Year (RD : LI) return LI is
      D0   : constant LI := RD - 1;
      N400 : constant LI := FDiv (D0, 146097);
      D1   : constant LI := FMod (D0, 146097);
      N100 : constant LI := FDiv (D1, 36524);
      D2   : constant LI := FMod (D1, 36524);
      N4   : constant LI := FDiv (D2, 1461);
      D3   : constant LI := FMod (D2, 1461);
      N1   : constant LI := FDiv (D3, 365);
      Y    : constant LI := 400 * N400 + 100 * N100 + 4 * N4 + N1;
   begin
      return (if N100 = 4 or else N1 = 4 then Y else Y + 1);
   end Greg_Year;

   function Greg_From (RD : LI) return Date is
      Y     : constant LI := Greg_Year (RD);
      Prior : constant LI := RD - Greg_Fixed (Y, 1, 1);
      Corr  : constant LI :=
        (if RD < Greg_Fixed (Y, 3, 1) then 0
         elsif Greg_Leap (Y) then 1 else 2);
      M : constant LI := FDiv (12 * (Prior + Corr) + 373, 367);
   begin
      return Mk (Y, M, RD - Greg_Fixed (Y, M, 1) + 1);
   end Greg_From;

   --  ------------------------------------------------------------------
   --  Julian
   --  ------------------------------------------------------------------

   function Jul_Leap (Y : LI) return Boolean is
     (FMod (Y, 4) = (if Y > 0 then 0 else 3));

   function Jul_Fixed (Y, M, D : LI) return LI is
      Y2 : constant LI := (if Y < 0 then Y + 1 else Y);
   begin
      return Julian_Epoch - 1 + 365 * (Y2 - 1) + FDiv (Y2 - 1, 4)
        + FDiv (367 * M - 362, 12)
        + (if M <= 2 then 0 elsif Jul_Leap (Y) then -1 else -2)
        + D;
   end Jul_Fixed;

   function Jul_From (RD : LI) return Date is
      Approx : constant LI := FDiv (4 * (RD - Julian_Epoch) + 1464, 1461);
      Y      : constant LI := (if Approx <= 0 then Approx - 1 else Approx);
      Prior  : constant LI := RD - Jul_Fixed (Y, 1, 1);
      Corr   : constant LI :=
        (if RD < Jul_Fixed (Y, 3, 1) then 0
         elsif Jul_Leap (Y) then 1 else 2);
      M : constant LI := FDiv (12 * (Prior + Corr) + 373, 367);
   begin
      return Mk (Y, M, RD - Jul_Fixed (Y, M, 1) + 1);
   end Jul_From;

   --  ------------------------------------------------------------------
   --  Islamic (tabular / civil)
   --  ------------------------------------------------------------------

   function Isl_Leap (Y : LI) return Boolean is (FMod (14 + 11 * Y, 30) < 11);

   function Isl_Fixed (Y, M, D : LI) return LI is
     (Islamic_Epoch - 1 + (Y - 1) * 354 + FDiv (3 + 11 * Y, 30)
      + 29 * (M - 1) + FDiv (M, 2) + D);

   function Isl_From (RD : LI) return Date is
      Y     : constant LI := FDiv (30 * (RD - Islamic_Epoch) + 10646, 10631);
      Prior : constant LI := RD - Isl_Fixed (Y, 1, 1);
      M     : constant LI := FDiv (11 * Prior + 330, 325);
   begin
      return Mk (Y, M, RD - Isl_Fixed (Y, M, 1) + 1);
   end Isl_From;

   --  ------------------------------------------------------------------
   --  Coptic / Ethiopic
   --  ------------------------------------------------------------------

   function Copt_Fixed (Y, M, D : LI) return LI is
     (Coptic_Epoch - 1 + 365 * (Y - 1) + FDiv (Y, 4) + 30 * (M - 1) + D);

   function Copt_From (RD : LI) return Date is
      Y : constant LI := FDiv (4 * (RD - Coptic_Epoch) + 1463, 1461);
      M : constant LI := FDiv (RD - Copt_Fixed (Y, 1, 1), 30) + 1;
   begin
      return Mk (Y, M, RD + 1 - Copt_Fixed (Y, M, 1));
   end Copt_From;

   function Ethi_Fixed (Y, M, D : LI) return LI is
     (Ethiopic_Epoch + (Copt_Fixed (Y, M, D) - Coptic_Epoch));

   function Ethi_From (RD : LI) return Date is
     (Copt_From (RD + (Coptic_Epoch - Ethiopic_Epoch)));

   --  ------------------------------------------------------------------
   --  Persian (arithmetic)
   --  ------------------------------------------------------------------

   function Pers_Fixed (Y, M, D : LI) return LI is
      Y1   : constant LI := (if Y > 0 then Y - 474 else Y - 473);
      Year : constant LI := FMod (Y1, 2820) + 474;
   begin
      return Persian_Epoch - 1
        + 1029983 * FDiv (Y1, 2820)
        + 365 * (Year - 1)
        + FDiv (31 * Year - 5, 128)
        + (if M <= 7 then 31 * (M - 1) else 30 * (M - 1) + 6)
        + D;
   end Pers_Fixed;

   function Pers_Year (RD : LI) return LI is
      D0    : constant LI := RD - Pers_Fixed (475, 1, 1);
      N2820 : constant LI := FDiv (D0, 1029983);
      D1    : constant LI := FMod (D0, 1029983);
      Y2820 : constant LI :=
        (if D1 = 1029982 then 2820 else FDiv (128 * D1 + 46878, 46751));
      Year  : constant LI := 474 + 2820 * N2820 + Y2820;
   begin
      return (if Year > 0 then Year else Year - 1);
   end Pers_Year;

   function Pers_From (RD : LI) return Date is
      Y   : constant LI := Pers_Year (RD);
      DOY : constant LI := RD - Pers_Fixed (Y, 1, 1) + 1;
      M   : constant LI :=
        (if DOY <= 186 then Ceil (DOY, 31) else Ceil (DOY - 6, 30));
   begin
      return Mk (Y, M, RD - Pers_Fixed (Y, M, 1) + 1);
   end Pers_From;

   --  ------------------------------------------------------------------
   --  Hebrew
   --  ------------------------------------------------------------------

   function Heb_Leap (Y : LI) return Boolean is (FMod (7 * Y + 1, 19) < 7);

   function Heb_Last_Month (Y : LI) return LI is (if Heb_Leap (Y) then 13 else 12);

   function Heb_Elapsed_Days (Y : LI) return LI is
      Months : constant LI := FDiv (235 * Y - 234, 19);
      Parts  : constant LI := 12084 + 13753 * Months;
      Day    : constant LI := 29 * Months + FDiv (Parts, 25920);
   begin
      return (if FMod (3 * (Day + 1), 7) < 3 then Day + 1 else Day);
   end Heb_Elapsed_Days;

   function Heb_New_Year (Y : LI) return LI is
      E0 : constant LI := Heb_Elapsed_Days (Y - 1);
      E1 : constant LI := Heb_Elapsed_Days (Y);
      E2 : constant LI := Heb_Elapsed_Days (Y + 1);
   begin
      return Hebrew_Epoch + E1
        + (if E2 - E1 = 356 then 2 elsif E1 - E0 = 382 then 1 else 0);
   end Heb_New_Year;

   function Heb_Days_In_Year (Y : LI) return LI is
     (Heb_New_Year (Y + 1) - Heb_New_Year (Y));

   function Heb_Long_Marheshvan (Y : LI) return Boolean is
      L : constant LI := Heb_Days_In_Year (Y);
   begin
      return L = 355 or else L = 385;
   end Heb_Long_Marheshvan;

   function Heb_Short_Kislev (Y : LI) return Boolean is
      L : constant LI := Heb_Days_In_Year (Y);
   begin
      return L = 353 or else L = 383;
   end Heb_Short_Kislev;

   function Heb_Last_Day (Y, M : LI) return LI is
   begin
      if M = 2 or else M = 4 or else M = 6 or else M = 10 or else M = 13 then
         return 29;
      elsif M = 12 and then not Heb_Leap (Y) then
         return 29;
      elsif M = 8 and then not Heb_Long_Marheshvan (Y) then
         return 29;
      elsif M = 9 and then Heb_Short_Kislev (Y) then
         return 29;
      else
         return 30;
      end if;
   end Heb_Last_Day;

   function Heb_Fixed (Y, M, D : LI) return LI is
      R : LI := Heb_New_Year (Y) + D - 1;
   begin
      if M < 7 then
         for MM in 7 .. Heb_Last_Month (Y) loop
            R := R + Heb_Last_Day (Y, MM);
         end loop;
         for MM in 1 .. M - 1 loop
            R := R + Heb_Last_Day (Y, MM);
         end loop;
      else
         for MM in 7 .. M - 1 loop
            R := R + Heb_Last_Day (Y, MM);
         end loop;
      end if;
      return R;
   end Heb_Fixed;

   function Heb_From (RD : LI) return Date is
      Y : LI := FDiv (98496 * (RD - Hebrew_Epoch), 35975351);
      M : LI;
   begin
      while Heb_New_Year (Y + 1) <= RD loop
         Y := Y + 1;
      end loop;
      M := (if RD < Heb_Fixed (Y, 1, 1) then 7 else 1);
      while RD > Heb_Fixed (Y, M, Heb_Last_Day (Y, M)) loop
         M := M + 1;
      end loop;
      return Mk (Y, M, RD - Heb_Fixed (Y, M, 1) + 1);
   end Heb_From;

   --  ------------------------------------------------------------------
   --  Indian national (Saka)
   --  ------------------------------------------------------------------

   function Indian_Fixed (Y, M, D : LI) return LI is
      Greg_Y : constant LI := Y + 78;
      Leap   : constant Boolean := Greg_Leap (Greg_Y);
      Start  : constant LI := Greg_Fixed (Greg_Y, 3, (if Leap then 21 else 22));
      Off    : LI;
   begin
      if M = 1 then
         Off := D - 1;
      else
         Off := (if Leap then 31 else 30);   --  Chaitra length
         for MM in 2 .. M - 1 loop
            Off := Off + (if MM <= 6 then 31 else 30);
         end loop;
         Off := Off + D - 1;
      end if;
      return Start + Off;
   end Indian_Fixed;

   function Indian_From (RD : LI) return Date is
      G : constant Date := Greg_From (RD);
      Y : LI := G.Year - 78;
      M : LI := 1;
   begin
      if RD < Indian_Fixed (Y, 1, 1) then
         Y := Y - 1;
      end if;
      --  Walk months.
      while M < 13
        and then RD >= Indian_Fixed (Y, M + 1, 1)
      loop
         M := M + 1;
      end loop;
      return Mk (Y, M, RD - Indian_Fixed (Y, M, 1) + 1);
   end Indian_From;

   --  ------------------------------------------------------------------
   --  Dispatch
   --  ------------------------------------------------------------------

   function To_Fixed (Cal : Calendar_Kind; D : Date) return LI is
      Y : constant LI := D.Year;
      M : constant LI := LI (D.Month);
      Da : constant LI := LI (D.Day);
   begin
      case Cal is
         when Gregorian => return Greg_Fixed (Y, M, Da);
         when Julian    => return Jul_Fixed (Y, M, Da);
         when Islamic   => return Isl_Fixed (Y, M, Da);
         when Hebrew    => return Heb_Fixed (Y, M, Da);
         when Coptic    => return Copt_Fixed (Y, M, Da);
         when Ethiopic  => return Ethi_Fixed (Y, M, Da);
         when Persian   => return Pers_Fixed (Y, M, Da);
         when Indian    => return Indian_Fixed (Y, M, Da);
         when Buddhist  => return Greg_Fixed (Y - 543, M, Da);
         when ROC       => return Greg_Fixed (Y + 1911, M, Da);
      end case;
   end To_Fixed;

   function From_Fixed (Cal : Calendar_Kind; RD : LI) return Date is
   begin
      case Cal is
         when Gregorian => return Greg_From (RD);
         when Julian    => return Jul_From (RD);
         when Islamic   => return Isl_From (RD);
         when Hebrew    => return Heb_From (RD);
         when Coptic    => return Copt_From (RD);
         when Ethiopic  => return Ethi_From (RD);
         when Persian   => return Pers_From (RD);
         when Indian    => return Indian_From (RD);
         when Buddhist  =>
            declare
               G : constant Date := Greg_From (RD);
            begin
               return (G.Year + 543, G.Month, G.Day);
            end;
         when ROC =>
            declare
               G : constant Date := Greg_From (RD);
            begin
               return (G.Year - 1911, G.Month, G.Day);
            end;
      end case;
   end From_Fixed;

   function Convert (From, To : Calendar_Kind; D : Date) return Date is
     (From_Fixed (To, To_Fixed (From, D)));

   function Day_Of_Week (RD : LI) return Natural is
     (Natural (FMod (RD, 7)));

   function Day_Of_Week (Cal : Calendar_Kind; D : Date) return Natural is
     (Day_Of_Week (To_Fixed (Cal, D)));

   function Is_Leap_Year
     (Cal : Calendar_Kind; Year : LI) return Boolean is
   begin
      case Cal is
         when Gregorian | Buddhist => return Greg_Leap (Year);
         when Julian               => return Jul_Leap (Year);
         when Islamic              => return Isl_Leap (Year);
         when Hebrew               => return Heb_Leap (Year);
         when Coptic | Ethiopic    => return FMod (Year, 4) = 3;
         when Persian              =>
            return Pers_Fixed (Year + 1, 1, 1) - Pers_Fixed (Year, 1, 1) = 366;
         when Indian               => return Greg_Leap (Year + 78);
         when ROC                  => return Greg_Leap (Year + 1911);
      end case;
   end Is_Leap_Year;

   function Months_In_Year
     (Cal : Calendar_Kind; Year : LI) return Positive is
   begin
      case Cal is
         when Hebrew             => return Positive (Heb_Last_Month (Year));
         when Coptic | Ethiopic  => return 13;   --  12 + epagomenal
         when others             => return 12;
      end case;
   end Months_In_Year;

   function Days_In_Month
     (Cal : Calendar_Kind; Year : LI; Month : Positive) return Positive
   is
      --  Walk forward from the first of the month until the month number
      --  changes. This is calendar-agnostic -- it does not assume months are
      --  numbered in chronological order (Hebrew numbers Nisan..Elul as 1..6
      --  yet the civil year opens at Tishri = 7), nor a fixed count per year.
      RD0 : constant LI := To_Fixed (Cal, (Year, Month, 1));
      Len : LI := 1;
   begin
      while Len <= 40
        and then From_Fixed (Cal, RD0 + Len).Month = Month
      loop
         Len := Len + 1;
      end loop;
      return Positive (Len);
   end Days_In_Month;

end I18N.Calendar_Math;
