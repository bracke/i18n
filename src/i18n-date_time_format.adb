with I18N.CLDR_Data;
with I18N.Locale_Data;
with I18N.Runtime_Data;

package body I18N.Date_Time_Format is

   type Calendar_System is
     (Gregorian, Buddhist, Japanese, Julian, ROC, Coptic, Ethiopic,
      Ethiopic_Amete_Alem, Islamic_Civil, Islamic_TBLA, Indian, Persian,
      Hebrew, ISO8601, Unsupported_Calendar);

   type Hour_Cycle is (H11, H12, H23, H24);

   function Contains (Text : String; Fragment : String) return Boolean is
   begin
      if Fragment'Length = 0 or else Text'Length < Fragment'Length then
         return False;
      end if;

      for Index in Text'First .. Text'Last - Fragment'Length + 1 loop
         if Text (Index .. Index + Fragment'Length - 1) = Fragment then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   --  Return Locale without its BCP-47 singleton extension (e.g. drop
   --  "-u-ca-buddhist" from "th-u-ca-buddhist", yielding "th"). The CLDR
   --  name/era tables are keyed by canonical locale WITHOUT extensions, so an
   --  extended locale must be reduced before those lookups or it matches
   --  nothing. The extension keywords themselves (calendar, numbering system,
   --  hour cycle) are read separately from the raw Locale, so stripping here is
   --  safe. Mirrors I18N.Locales.Base_Locale, which is private to that unit.
   --  The on-the-fly composite sub-key for an indexed name: the bare decimal.
   function Index_Key (N : Natural) return String is
      Image : constant String := Natural'Image (N);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Index_Key;

   function Base_Locale (Locale : String) return String is
      Subtag_First : Positive := Locale'First;
      Ext          : Natural := 0;
   begin
      if Locale'Length = 0 then
         return Locale;
      end if;

      for Index in Locale'Range loop
         if Locale (Index) = '-' then
            if Index - Subtag_First = 1 then
               Ext := Subtag_First;
               exit;
            end if;
            Subtag_First := Index + 1;
         end if;
      end loop;

      if Ext = 0 and then Locale'Last - Subtag_First + 1 = 1 then
         Ext := Subtag_First;
      end if;

      if Ext = 0 then
         return Locale;
      elsif Ext = Locale'First then
         return "";
      else
         return Locale (Locale'First .. Ext - 2);
      end if;
   end Base_Locale;

   function Calendar_From_Name (Name : String) return Calendar_System is
   begin
      if Name = "buddhist" then
         return Buddhist;
      elsif Name = "gregory" or else Name = "gregorian" then
         return Gregorian;
      elsif Name = "iso8601" then
         return ISO8601;
      elsif Name = "japanese" then
         return Japanese;
      elsif Name = "julian" then
         return Julian;
      elsif Name = "roc" then
         return ROC;
      elsif Name = "coptic" then
         return Coptic;
      elsif Name = "ethiopic" then
         return Ethiopic;
      elsif Name = "ethioaa" or else Name = "ethiopic-amete-alem" then
         return Ethiopic_Amete_Alem;
      elsif Name = "islamic-civil"
        or else Name = "islamic"
        or else Name = "islamicc"
      then
         return Islamic_Civil;
      elsif Name = "islamic-tbla" then
         return Islamic_TBLA;
      elsif Name = "indian" then
         return Indian;
      elsif Name = "persian" then
         return Persian;
      elsif Name = "hebrew" then
         return Hebrew;
      else
         return Unsupported_Calendar;
      end if;
   end Calendar_From_Name;

   function First_UTF8_Character (Text : String) return String is
      First : constant Positive := Text'First;
      Lead  : Natural;
      Count : Natural := 1;
   begin
      if Text'Length = 0 then
         return "";
      end if;

      Lead := Character'Pos (Text (First));
      if Lead in 16#C0# .. 16#DF# then
         Count := 2;
      elsif Lead in 16#E0# .. 16#EF# then
         Count := 3;
      elsif Lead in 16#F0# .. 16#F7# then
         Count := 4;
      end if;

      if First + Count - 1 <= Text'Last then
         return Text (First .. First + Count - 1);
      else
         return Text (First .. First);
      end if;
   end First_UTF8_Character;

   function Hour_Cycle_From_Name (Name : String) return Hour_Cycle is
   begin
      if Name = "h11" then
         return H11;
      elsif Name = "h12" then
         return H12;
      elsif Name = "h24" then
         return H24;
      else
         return H23;
      end if;
   end Hour_Cycle_From_Name;

   function Hour_Cycle_For (Locale : String) return Hour_Cycle is
      Lang : constant String := I18N.CLDR_Data.Language (Locale);
   begin
      if Contains (Locale, "-u-hc-h11")
        or else Contains (Locale, "@hours=h11")
      then
         return H11;
      elsif Contains (Locale, "-u-hc-h12")
        or else Contains (Locale, "@hours=h12")
      then
         return H12;
      elsif Contains (Locale, "-u-hc-h24")
        or else Contains (Locale, "@hours=h24")
      then
         return H24;
      elsif Contains (Locale, "-u-hc-h23")
        or else Contains (Locale, "@hours=h23")
      then
         return H23;
      else
         declare
            Found : Boolean;
            Name  : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, "default_hour_cycle", Found);
         begin
            if Found then
               return Hour_Cycle_From_Name (Name);
            elsif Lang = "en" or else Lang = "ar" or else Lang = "ko" then
               return H12;
            else
               return H23;
            end if;
         end;
      end if;
   end Hour_Cycle_For;

   function Calendar_For (Locale : String) return Calendar_System is
   begin
      if Contains (Locale, "-u-ca-buddhist")
        or else Contains (Locale, "@calendar=buddhist")
      then
         return Buddhist;
      elsif Contains (Locale, "-u-ca-gregory")
        or else Contains (Locale, "@calendar=gregory")
        or else Contains (Locale, "-u-ca-gregorian")
        or else Contains (Locale, "@calendar=gregorian")
      then
         return Gregorian;
      elsif Contains (Locale, "-u-ca-iso8601")
        or else Contains (Locale, "@calendar=iso8601")
      then
         return ISO8601;
      elsif Contains (Locale, "-u-ca-japanese")
        or else Contains (Locale, "@calendar=japanese")
      then
         return Japanese;
      elsif Contains (Locale, "-u-ca-julian")
        or else Contains (Locale, "@calendar=julian")
      then
         return Julian;
      elsif Contains (Locale, "-u-ca-roc")
        or else Contains (Locale, "@calendar=roc")
      then
         return ROC;
      elsif Contains (Locale, "-u-ca-coptic")
        or else Contains (Locale, "@calendar=coptic")
      then
         return Coptic;
      elsif Contains (Locale, "-u-ca-ethioaa")
        or else Contains (Locale, "@calendar=ethioaa")
        or else Contains (Locale, "-u-ca-ethiopic-amete-alem")
        or else Contains (Locale, "@calendar=ethiopic-amete-alem")
      then
         return Ethiopic_Amete_Alem;
      elsif Contains (Locale, "-u-ca-ethiopic")
        or else Contains (Locale, "@calendar=ethiopic")
      then
         return Ethiopic;
      elsif Contains (Locale, "-u-ca-islamic-tbla")
        or else Contains (Locale, "@calendar=islamic-tbla")
      then
         return Islamic_TBLA;
      elsif Contains (Locale, "-u-ca-islamic-civil")
        or else Contains (Locale, "@calendar=islamic-civil")
        or else Contains (Locale, "-u-ca-islamic")
        or else Contains (Locale, "@calendar=islamic")
        or else Contains (Locale, "-u-ca-islamicc")
        or else Contains (Locale, "@calendar=islamicc")
      then
         return Islamic_Civil;
      elsif Contains (Locale, "-u-ca-indian")
        or else Contains (Locale, "@calendar=indian")
      then
         return Indian;
      elsif Contains (Locale, "-u-ca-persian")
        or else Contains (Locale, "@calendar=persian")
      then
         return Persian;
      elsif Contains (Locale, "-u-ca-hebrew")
        or else Contains (Locale, "@calendar=hebrew")
      then
         return Hebrew;
      elsif Contains (Locale, "-u-ca-")
        or else Contains (Locale, "@calendar=")
      then
         return Unsupported_Calendar;
      else
         declare
            Found : Boolean;
            Name  : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, "default_calendar", Found);
         begin
            return
              (if Found then Calendar_From_Name (Name) else Gregorian);
         end;
      end if;
   end Calendar_For;

   function Weekday_From_Name (Name : String) return Natural is
   begin
      if Name = "mon" then
         return 1;
      elsif Name = "tue" then
         return 2;
      elsif Name = "wed" then
         return 3;
      elsif Name = "thu" then
         return 4;
      elsif Name = "fri" then
         return 5;
      elsif Name = "sat" then
         return 6;
      else
         return 0;
      end if;
   end Weekday_From_Name;

   function First_Day_Of_Week (Locale : String) return Natural is
      Found : Boolean;
      Name  : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "first_day_of_week", Found);
   begin
      if Calendar_For (Locale) = ISO8601 then
         return 1;
      elsif Found then
         return Weekday_From_Name (Name);
      else
         return Weekday_From_Name
           (I18N.CLDR_Data.First_Day_Of_Week (Locale));
      end if;
   end First_Day_Of_Week;

   function Week_Data_Overridden (Locale : String) return Boolean is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, "first_day_of_week", Found);
      pragma Unreferenced (Value);
   begin
      if Calendar_For (Locale) = ISO8601 then
         return True;
      end if;

      if Found then
         return True;
      end if;

      declare
         Min_Found : Boolean;
         Min_Value : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "first_week_min_days", Min_Found);
         pragma Unreferenced (Min_Value);
      begin
         return Min_Found
           or else I18N.CLDR_Data.First_Day_Of_Week (Locale) /= ""
           or else I18N.CLDR_Data.First_Week_Min_Days (Locale) > 0;
      end;
   end Week_Data_Overridden;

   function First_Week_Min_Days (Locale : String) return Natural is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "first_week_min_days", Found);
   begin
      if Calendar_For (Locale) = ISO8601 then
         return 4;
      elsif Found
        and then Value'Length = 1
        and then Value (Value'First) in '1' .. '7'
      then
         return Character'Pos (Value (Value'First)) - Character'Pos ('0');
      else
         return I18N.CLDR_Data.First_Week_Min_Days (Locale);
      end if;
   end First_Week_Min_Days;

   --  The CLDR key for the calendar this locale selects, so the pattern comes
   --  from the calendar actually being rendered rather than from gregorian.
   function Calendar_Key (Locale : String) return String is
   begin
      case Calendar_For (Locale) is
         when Buddhist            => return "buddhist";
         when Japanese            => return "japanese";
         when Persian             => return "persian";
         when Coptic              => return "coptic";
         when Ethiopic
            | Ethiopic_Amete_Alem => return "ethiopic";
         when Hebrew              => return "hebrew";
         when Indian              => return "indian";
         when ROC                 => return "roc";
         when others              => return "gregorian";
      end case;
   end Calendar_Key;

   function Date_Style_Pattern
     (Locale : String;
      Style  : String)
      return String
   is
      Found : Boolean;
      DMY   : Boolean :=
        I18N.Runtime_Data.Locale_Boolean
          (Locale, "uses_day_month_year", Found);
   begin
      if not Found then
         declare
            Store_Found : Boolean;
            Store_Value : constant String :=
              I18N.Locale_Data.Lookup
                ("uses_day_month_year", Locale, "", Store_Found);
         begin
            if Store_Found then
               DMY := Store_Value = "1";
               Found := True;
            end if;
         end;
      end if;

      if not Found then
         return I18N.CLDR_Data.Date_Style_Pattern
           (Locale, Calendar_Key (Locale), Style);
      elsif DMY then
         if Style = "short" then
            return "dd'.'MM'.'yy";
         elsif Style = "long" or else Style = "full" then
            if Style = "full" then
               return "EEEE', 'd'. 'MMMM' 'yyyy";
            else
               return "d'. 'MMMM' 'yyyy";
            end if;
         else
            return "dd'.'MM'.'yyyy";
         end if;
      else
         if Style = "short" then
            return "M'/'d'/'yy";
         elsif Style = "long" or else Style = "full" then
            if Style = "full" then
               return "EEEE', 'MMMM' 'd', 'yyyy";
            else
               return "MMMM' 'd', 'yyyy";
            end if;
         elsif Style = "medium" then
            return "MMMM' 'd', 'yyyy";
         else
            return "yyyy'-'MM'-'dd";
         end if;
      end if;
   end Date_Style_Pattern;

   function Is_Digit (C : Character) return Boolean is
   begin
      return C in '0' .. '9';
   end Is_Digit;

   function Two_Digits (Text : String; Index : Positive) return Natural is
   begin
      return
        (Character'Pos (Text (Index)) - Character'Pos ('0')) * 10
        + (Character'Pos (Text (Index + 1)) - Character'Pos ('0'));
   end Two_Digits;

   function Four_Digits (Text : String; Index : Positive) return Natural is
   begin
      return
        (Character'Pos (Text (Index)) - Character'Pos ('0')) * 1000
        + (Character'Pos (Text (Index + 1)) - Character'Pos ('0')) * 100
        + (Character'Pos (Text (Index + 2)) - Character'Pos ('0')) * 10
        + (Character'Pos (Text (Index + 3)) - Character'Pos ('0'));
   end Four_Digits;

   function Leap_Year (Year : Natural) return Boolean is
   begin
      return
        (Year mod 4 = 0 and then Year mod 100 /= 0)
        or else Year mod 400 = 0;
   end Leap_Year;

   function Days_In_Month (Year : Natural; Month : Natural) return Natural is
   begin
      case Month is
         when 1 | 3 | 5 | 7 | 8 | 10 | 12 =>
            return 31;
         when 4 | 6 | 9 | 11 =>
            return 30;
         when 2 =>
            return (if Leap_Year (Year) then 29 else 28);
         when others =>
            return 0;
      end case;
   end Days_In_Month;

   function Day_Of_Week
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      Y : Integer := Integer (Year);
      M : Integer := Integer (Month);
      K : Integer;
      J : Integer;
      H : Integer;
   begin
      if M < 3 then
         M := M + 12;
         Y := Y - 1;
      end if;

      K := Y mod 100;
      J := Y / 100;
      H :=
        (Integer (Day)
         + (13 * (M + 1)) / 5
         + K
         + K / 4
         + J / 4
         + 5 * J)
        mod 7;

      return Natural ((H + 6) mod 7);
   end Day_Of_Week;

   function Day_Of_Year
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      Result : Natural := Day;
   begin
      if Month > 1 then
         for M in 1 .. Month - 1 loop
            Result := Result + Days_In_Month (Year, M);
         end loop;
      end if;

      return Result;
   end Day_Of_Year;

   function Day_Of_Week_In_Month (Day : Natural) return Natural is
   begin
      return ((Day - 1) / 7) + 1;
   end Day_Of_Week_In_Month;

   function ISO_Day_Of_Week
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural;

   function Week_Of_Month
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      First_DOW       : constant Natural := ISO_Day_Of_Week (Year, Month, 1);
      First_Week_Start : constant Integer :=
        (if First_DOW <= 4
         then 2 - Integer (First_DOW)
         else 9 - Integer (First_DOW));
   begin
      if Integer (Day) < First_Week_Start then
         return 0;
      else
         return Natural ((Integer (Day) - First_Week_Start) / 7) + 1;
      end if;
   end Week_Of_Month;

   function ISO_Day_Of_Week
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      DOW : constant Natural := Day_Of_Week (Year, Month, Day);
   begin
      return (if DOW = 0 then 7 else DOW);
   end ISO_Day_Of_Week;

   function ISO_Weeks_In_Year (Year : Natural) return Natural is
      Jan_1 : constant Natural := ISO_Day_Of_Week (Year, 1, 1);
   begin
      if Jan_1 = 4 or else (Jan_1 = 3 and then Leap_Year (Year)) then
         return 53;
      else
         return 52;
      end if;
   end ISO_Weeks_In_Year;

   function Week_Based_Year
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      Week : constant Integer :=
        (Integer (Day_Of_Year (Year, Month, Day))
         - Integer (ISO_Day_Of_Week (Year, Month, Day))
         + 10)
        / 7;
   begin
      if Week < 1 then
         return (if Year = 0 then 0 else Year - 1);
      elsif Week > Integer (ISO_Weeks_In_Year (Year)) then
         return Year + 1;
      else
         return Year;
      end if;
   end Week_Based_Year;

   function ISO_Week_Of_Year
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      Week : constant Integer :=
        (Integer (Day_Of_Year (Year, Month, Day))
         - Integer (ISO_Day_Of_Week (Year, Month, Day))
         + 10)
        / 7;
   begin
      if Week < 1 then
         return ISO_Weeks_In_Year ((if Year = 0 then 0 else Year - 1));
      elsif Week > Integer (ISO_Weeks_In_Year (Year)) then
         return 1;
      else
         return Natural (Week);
      end if;
   end ISO_Week_Of_Year;

   function Days_In_Year (Year : Natural) return Natural is
   begin
      return (if Leap_Year (Year) then 366 else 365);
   end Days_In_Year;

   function Week_1_Start_Day
     (Year     : Natural;
      First_Day : Natural;
      Min_Days  : Natural)
      return Integer
   is
      Jan_1_DOW        : constant Natural := Day_Of_Week (Year, 1, 1);
      Days_Before_First : constant Natural :=
        (Jan_1_DOW + 7 - First_Day) mod 7;
      Days_In_First_Week : constant Natural := 7 - Days_Before_First;
   begin
      if Days_In_First_Week >= Min_Days then
         return 1 - Integer (Days_Before_First);
      else
         return 1 + Integer (Days_In_First_Week);
      end if;
   end Week_1_Start_Day;

   procedure Week_Data_Year_And_Number
     (Year        : Natural;
      Month       : Natural;
      Day         : Natural;
      First_Day   : Natural;
      Min_Days    : Natural;
      Week_Year   : out Natural;
      Week_Number : out Natural)
   is
      DOY        : constant Integer := Integer (Day_Of_Year (Year, Month, Day));
      This_Start : constant Integer :=
        Week_1_Start_Day (Year, First_Day, Min_Days);
      Next_Start : constant Integer :=
        Integer (Days_In_Year (Year))
        + Week_1_Start_Day (Year + 1, First_Day, Min_Days);
   begin
      if DOY < This_Start then
         declare
            Prev_Year  : constant Natural := (if Year = 0 then 0 else Year - 1);
            Prev_Start : constant Integer :=
              Week_1_Start_Day (Prev_Year, First_Day, Min_Days);
            Prev_DOY   : constant Integer :=
              Integer (Days_In_Year (Prev_Year)) + DOY;
         begin
            Week_Year := Prev_Year;
            Week_Number := Natural ((Prev_DOY - Prev_Start) / 7) + 1;
         end;
      elsif DOY >= Next_Start then
         Week_Year := Year + 1;
         Week_Number := Natural ((DOY - Next_Start) / 7) + 1;
      else
         Week_Year := Year;
         Week_Number := Natural ((DOY - This_Start) / 7) + 1;
      end if;
   end Week_Data_Year_And_Number;

   function Week_Data_Week_Based_Year
     (Year      : Natural;
      Month     : Natural;
      Day       : Natural;
      First_Day : Natural;
      Min_Days  : Natural)
      return Natural
   is
      Week_Year   : Natural;
      Week_Number : Natural;
   begin
      Week_Data_Year_And_Number
        (Year, Month, Day, First_Day, Min_Days, Week_Year, Week_Number);
      return Week_Year;
   end Week_Data_Week_Based_Year;

   function Week_Data_Week_Of_Year
     (Year      : Natural;
      Month     : Natural;
      Day       : Natural;
      First_Day : Natural;
      Min_Days  : Natural)
      return Natural
   is
      Week_Year   : Natural;
      Week_Number : Natural;
   begin
      Week_Data_Year_And_Number
        (Year, Month, Day, First_Day, Min_Days, Week_Year, Week_Number);
      return Week_Number;
   end Week_Data_Week_Of_Year;

   function Week_Data_Week_Of_Month
     (Year      : Natural;
      Month     : Natural;
      Day       : Natural;
      First_Day : Natural;
      Min_Days  : Natural)
      return Natural
   is
      First_DOW   : constant Natural := Day_Of_Week (Year, Month, 1);
      Days_Before : constant Natural := (First_DOW + 7 - First_Day) mod 7;
      Days_In_First : constant Natural := 7 - Days_Before;
      Week_1_Start  : constant Integer :=
        (if Days_In_First >= Min_Days
         then 1 - Integer (Days_Before)
         else 1 + Integer (Days_In_First));
   begin
      if Integer (Day) < Week_1_Start then
         return 0;
      else
         return Natural ((Integer (Day) - Week_1_Start) / 7) + 1;
      end if;
   end Week_Data_Week_Of_Month;

   function Modified_Julian_Day
     (Year : Natural;
      Month : Natural;
      Day : Natural)
      return Natural
   is
      A : constant Integer := (14 - Integer (Month)) / 12;
      Y : constant Integer := Integer (Year) + 4800 - A;
      M : constant Integer := Integer (Month) + 12 * A - 3;
      Julian_Day_Number : constant Integer :=
        Integer (Day)
        + (153 * M + 2) / 5
        + 365 * Y
        + Y / 4
        - Y / 100
        + Y / 400
        - 32045;
   begin
      return Natural (Julian_Day_Number - 2_400_001);
   end Modified_Julian_Day;

   procedure Gregorian_To_Julian
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      A : constant Integer := (14 - Integer (Month)) / 12;
      Y : constant Integer := Integer (Year) + 4800 - A;
      M : constant Integer := Integer (Month) + 12 * A - 3;
      JDN : constant Integer :=
        Integer (Day)
        + (153 * M + 2) / 5
        + 365 * Y
        + Y / 4
        - Y / 100
        + Y / 400
        - 32045;
      C : constant Integer := JDN + 32082;
      D : constant Integer := (4 * C + 3) / 1461;
      E : constant Integer := C - (1461 * D) / 4;
      M2 : constant Integer := (5 * E + 2) / 153;
   begin
      Day := Natural (E - (153 * M2 + 2) / 5 + 1);
      Month := Natural (M2 + 3 - 12 * (M2 / 10));
      Year := Natural (D - 4800 + M2 / 10);
   end Gregorian_To_Julian;

   procedure Gregorian_To_Coptic
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      Coptic_Epoch : constant Integer := 1_825_030;
      JDN          : constant Integer :=
        Integer (Modified_Julian_Day (Year, Month, Day)) + 2_400_001;
      Days         : constant Integer := JDN - Coptic_Epoch;
      Coptic_Year  : Integer := (4 * Days + 1_463) / 1_461;
      Year_Start   : Integer :=
        Coptic_Epoch + 365 * (Coptic_Year - 1) + Coptic_Year / 4;
      Day_Offset   : Integer := JDN - Year_Start;
   begin
      if Day_Offset < 0 then
         Coptic_Year := Coptic_Year - 1;
         Year_Start :=
           Coptic_Epoch + 365 * (Coptic_Year - 1) + Coptic_Year / 4;
         Day_Offset := JDN - Year_Start;
      end if;

      Year := Natural (Coptic_Year);
      Month := Natural (Day_Offset / 30) + 1;
      Day := Natural (Day_Offset mod 30) + 1;
   end Gregorian_To_Coptic;

   procedure Gregorian_To_Ethiopic
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
   begin
      Gregorian_To_Coptic (Year, Month, Day);
      Year := Year + 276;
   end Gregorian_To_Ethiopic;

   procedure Gregorian_To_Ethiopic_Amete_Alem
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
   begin
      Gregorian_To_Ethiopic (Year, Month, Day);
      Year := Year + 5_500;
   end Gregorian_To_Ethiopic_Amete_Alem;

   procedure Gregorian_To_Islamic_Civil
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      JDN            : constant Integer :=
        Integer (Modified_Julian_Day (Year, Month, Day)) + 2_400_001;
      L              : Integer := JDN - 1_948_440 + 10_632;
      N              : constant Integer := (L - 1) / 10_631;
      J              : Integer;
      Islamic_Month  : Integer;
   begin
      L := L - 10_631 * N + 354;
      J :=
        ((10_985 - L) / 5_316) * ((50 * L) / 17_719)
        + (L / 5_670) * ((43 * L) / 15_238);
      L :=
        L
        - ((30 - J) / 15) * ((17_719 * J) / 50)
        - (J / 16) * ((15_238 * J) / 43)
        + 29;
      Islamic_Month := (24 * L) / 709;

      Year := Natural (30 * N + J - 30);
      Month := Natural (Islamic_Month);
      Day := Natural (L - (709 * Islamic_Month) / 24);
   end Gregorian_To_Islamic_Civil;

   procedure Gregorian_To_Islamic_TBLA
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      function Ceil_Month_Days (Month_Index : Integer) return Integer is
      begin
         return (59 * Month_Index + 1) / 2;
      end Ceil_Month_Days;

      function Islamic_To_JDN
        (I_Year  : Integer;
         I_Month : Integer;
         I_Day   : Integer)
         return Integer
      is
         Astronomical_Epoch : constant Integer := 1_948_439;
      begin
         return I_Day
           + Ceil_Month_Days (I_Month - 1)
           + (I_Year - 1) * 354
           + (3 + 11 * I_Year) / 30
           + Astronomical_Epoch - 1;
      end Islamic_To_JDN;

      Astronomical_Epoch : constant Integer := 1_948_439;
      JDN                : constant Integer :=
        Integer (Modified_Julian_Day (Year, Month, Day)) + 2_400_001;
      I_Year             : constant Integer :=
        (30 * (JDN - Astronomical_Epoch) + 10_646) / 10_631;
      I_Month            : constant Integer :=
        Integer'Min
          (12,
           (2 * (JDN - (29 + Islamic_To_JDN (I_Year, 1, 1))) + 58) / 59
           + 1);
      I_Day              : constant Integer :=
        JDN - Islamic_To_JDN (I_Year, I_Month, 1) + 1;
   begin
      Year := Natural (I_Year);
      Month := Natural (I_Month);
      Day := Natural (I_Day);
   end Gregorian_To_Islamic_TBLA;

   procedure Gregorian_To_Indian
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      Current_DOY       : constant Natural := Day_Of_Year (Year, Month, Day);
      Current_Leap      : constant Boolean := Leap_Year (Year);
      Previous_Leap     : constant Boolean :=
        Year > 0 and then Leap_Year (Year - 1);
      Saka_Year         : Natural;
      Saka_Day          : Natural;
      Chaitra_Length    : Natural;
      Remaining         : Natural;
   begin
      if Current_DOY >= 81 then
         Saka_Year := (if Year >= 78 then Year - 78 else 0);
         Saka_Day := Current_DOY - 80;
         Chaitra_Length := (if Current_Leap then 31 else 30);
      else
         Saka_Year := (if Year >= 79 then Year - 79 else 0);
         Saka_Day :=
           (if Previous_Leap then 286 else 285) + Current_DOY;
         Chaitra_Length := (if Previous_Leap then 31 else 30);
      end if;

      Year := Saka_Year;
      if Saka_Day <= Chaitra_Length then
         Month := 1;
         Day := Saka_Day;
      else
         Remaining := Saka_Day - Chaitra_Length;
         if Remaining <= 155 then
            Month := ((Remaining - 1) / 31) + 2;
            Day := ((Remaining - 1) mod 31) + 1;
         else
            Remaining := Remaining - 155;
            Month := ((Remaining - 1) / 30) + 7;
            Day := ((Remaining - 1) mod 30) + 1;
         end if;
      end if;
   end Gregorian_To_Indian;

   function Persian_To_JDN
     (Year  : Natural;
      Month : Natural;
      Day   : Natural)
      return Integer
   is
      Persian_Epoch : constant Integer := 1_948_321;
      Epbase        : constant Integer := Integer (Year) - 474;
      Epyear        : constant Integer := 474 + (Epbase mod 2_820);
      Month_Days    : constant Integer :=
        (if Month <= 7
         then (Integer (Month) - 1) * 31
         else (Integer (Month) - 1) * 30 + 6);
   begin
      return
        Integer (Day)
        + Month_Days
        + (Epyear * 682 - 110) / 2_816
        + (Epyear - 1) * 365
        + (Epbase / 2_820) * 1_029_983
        + Persian_Epoch
        - 1;
   end Persian_To_JDN;

   procedure Gregorian_To_Persian
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      JDN     : constant Integer :=
        Integer (Modified_Julian_Day (Year, Month, Day)) + 2_400_001;
      Depoch  : constant Integer := JDN - Persian_To_JDN (475, 1, 1);
      Cycle   : constant Integer := Depoch / 1_029_983;
      Cyear   : constant Integer := Depoch mod 1_029_983;
      Aux1    : constant Integer := Cyear / 366;
      Aux2    : constant Integer := Cyear mod 366;
      Ycycle  : constant Integer :=
        (if Cyear = 1_029_982
         then 2_820
         else ((2_134 * Aux1 + 2_816 * Aux2 + 2_815) / 1_028_522)
              + Aux1
              + 1);
      PYear   : constant Natural := Natural (Ycycle + 2_820 * Cycle + 474);
      YDay    : constant Integer := JDN - Persian_To_JDN (PYear, 1, 1) + 1;
      PMonth  : Natural;
   begin
      if YDay <= 186 then
         PMonth := Natural ((YDay + 30) / 31);
      else
         PMonth := Natural ((YDay - 187) / 30) + 7;
      end if;

      Year := PYear;
      Month := PMonth;
      Day := Natural (JDN - Persian_To_JDN (PYear, PMonth, 1) + 1);
   end Gregorian_To_Persian;

   function Hebrew_Leap_Year (Year : Natural) return Boolean is
   begin
      return ((7 * Year + 1) mod 19) < 7;
   end Hebrew_Leap_Year;

   function Hebrew_Elapsed_Days (Year : Natural) return Integer is
      Previous_Year  : constant Natural := Year - 1;
      Cycle_Months   : constant Integer :=
        235 * Integer (Previous_Year / 19);
      Year_Months    : constant Integer :=
        12 * Integer (Previous_Year mod 19)
        + Integer ((7 * (Previous_Year mod 19) + 1) / 19);
      Months_Elapsed : constant Integer := Cycle_Months + Year_Months;
      Parts_Elapsed  : constant Integer :=
        204 + 793 * (Months_Elapsed mod 1080);
      Hours_Elapsed  : constant Integer :=
        5
        + 12 * Months_Elapsed
        + 793 * (Months_Elapsed / 1080)
        + Parts_Elapsed / 1080;
      Day            : Integer :=
        1 + 29 * Months_Elapsed + Hours_Elapsed / 24;
      Parts          : constant Integer :=
        1080 * (Hours_Elapsed mod 24) + (Parts_Elapsed mod 1080);
   begin
      if Parts >= 19_440
        or else
          (Day mod 7 = 2
           and then Parts >= 9_924
           and then not Hebrew_Leap_Year (Year))
        or else
          (Day mod 7 = 1
           and then Parts >= 16_789
           and then Hebrew_Leap_Year (Year - 1))
      then
         Day := Day + 1;
      end if;

      if Day mod 7 = 0 or else Day mod 7 = 3 or else Day mod 7 = 5 then
         Day := Day + 1;
      end if;

      return Day;
   end Hebrew_Elapsed_Days;

   function Hebrew_Year_Length (Year : Natural) return Natural is
   begin
      return Natural (Hebrew_Elapsed_Days (Year + 1)
                      - Hebrew_Elapsed_Days (Year));
   end Hebrew_Year_Length;

   function Hebrew_Long_Cheshvan (Year : Natural) return Boolean is
   begin
      return Hebrew_Year_Length (Year) mod 10 = 5;
   end Hebrew_Long_Cheshvan;

   function Hebrew_Short_Kislev (Year : Natural) return Boolean is
   begin
      return Hebrew_Year_Length (Year) mod 10 = 3;
   end Hebrew_Short_Kislev;

   function Hebrew_Month_Count (Year : Natural) return Natural is
   begin
      return (if Hebrew_Leap_Year (Year) then 13 else 12);
   end Hebrew_Month_Count;

   function Hebrew_Month_Length
     (Year  : Natural;
      Month : Natural)
      return Natural
   is
   begin
      case Month is
         when 1 | 5 | 8 | 10 | 12 =>
            return 30;
         when 4 | 7 | 9 | 11 | 13 =>
            return 29;
         when 2 =>
            return (if Hebrew_Long_Cheshvan (Year) then 30 else 29);
         when 3 =>
            return (if Hebrew_Short_Kislev (Year) then 29 else 30);
         when 6 =>
            return (if Hebrew_Leap_Year (Year) then 30 else 29);
         when others =>
            return 0;
      end case;
   end Hebrew_Month_Length;

   function Hebrew_To_JDN
     (Year  : Natural;
      Month : Natural;
      Day   : Natural)
      return Integer
   is
      Hebrew_Epoch_JDN : constant Integer := 347_997;
      Result           : Integer :=
        Hebrew_Epoch_JDN + Hebrew_Elapsed_Days (Year) + Integer (Day) - 1;
   begin
      if Month > 1 then
         for M in 1 .. Month - 1 loop
            Result := Result + Integer (Hebrew_Month_Length (Year, M));
         end loop;
      end if;

      return Result;
   end Hebrew_To_JDN;

   procedure Gregorian_To_Hebrew
     (Year  : in out Natural;
      Month : in out Natural;
      Day   : in out Natural)
   is
      JDN          : constant Integer :=
        Integer (Modified_Julian_Day (Year, Month, Day)) + 2_400_001;
      Hebrew_Year  : Natural := Natural ((JDN - 347_997) / 366) + 1;
      Hebrew_Month : Natural;
   begin
      while JDN >= Hebrew_To_JDN (Hebrew_Year + 1, 1, 1) loop
         Hebrew_Year := Hebrew_Year + 1;
      end loop;

      while JDN < Hebrew_To_JDN (Hebrew_Year, 1, 1) loop
         Hebrew_Year := Hebrew_Year - 1;
      end loop;

      Hebrew_Month := 1;
      while Hebrew_Month < Hebrew_Month_Count (Hebrew_Year)
        and then JDN >=
          Hebrew_To_JDN (Hebrew_Year, Hebrew_Month, 1)
          + Integer (Hebrew_Month_Length (Hebrew_Year, Hebrew_Month))
      loop
         Hebrew_Month := Hebrew_Month + 1;
      end loop;

      Year := Hebrew_Year;
      Month := Hebrew_Month;
      Day := Natural (JDN - Hebrew_To_JDN (Hebrew_Year, Hebrew_Month, 1)) + 1;
   end Gregorian_To_Hebrew;

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
        I18N.Runtime_Data.Locale_Digit_Text (Locale, Digit, Found);
   begin
      Put
        (Target,
         Last,
         Overflow,
         (if Found then Value else I18N.CLDR_Data.Digit_Text (Locale, Digit)));
   end Put_Digit;

   procedure Put_Number
     (Target    : in out String;
      Last      : in out Natural;
      Overflow  : in out Boolean;
      Locale    : String;
      Value     : Natural;
      Min_Width : Natural := 1)
   is
      Image : constant String := Natural'Image (Value);
      Raw   : constant String := Image (Image'First + 1 .. Image'Last);
   begin
      if Raw'Length < Min_Width then
         for Pad in 1 .. Min_Width - Raw'Length loop
            Put_Digit (Target, Last, Overflow, Locale, '0');
         end loop;
      end if;

      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Number;

   procedure Put_Long_Long_Natural
     (Target    : in out String;
      Last      : in out Natural;
      Overflow  : in out Boolean;
      Locale    : String;
      Value     : Long_Long_Integer;
      Min_Width : Natural := 1)
   is
      Image : constant String := Long_Long_Integer'Image (Value);
      Raw   : constant String := Image (Image'First + 1 .. Image'Last);
   begin
      if Raw'Length < Min_Width then
         for Pad in 1 .. Min_Width - Raw'Length loop
            Put_Digit (Target, Last, Overflow, Locale, '0');
         end loop;
      end if;

      for C of Raw loop
         Put_Digit (Target, Last, Overflow, Locale, C);
      end loop;
   end Put_Long_Long_Natural;

   function Month_Name
     (Locale     : String;
      Month      : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale, (if Standalone then "month_standalone" else "month"),
           Month, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Month_Name (Locale, Month);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("month_name", Base_Locale (Locale), Index_Key (Month), SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Month_Name (Base_Locale (Locale), Month));
         end;
      end if;
   end Month_Name;

   function Weekday_Name
     (Locale     : String;
      Day        : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale, (if Standalone then "weekday_standalone" else "weekday"),
           Day, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Weekday_Name (Locale, Day);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("weekday_name", Base_Locale (Locale), Index_Key (Day), SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Weekday_Name (Base_Locale (Locale), Day));
         end;
      end if;
   end Weekday_Name;

   function Era_Name
     (Locale   : String;
      Calendar : String;
      Era      : String)
      return String;

   function Era_Year_Separator
     (Locale   : String;
      Calendar : String)
      return String;

   function Japanese_Era
     (Year  : Natural;
      Month : Natural;
      Day   : Natural)
      return String
   is
   begin
      if Year > 2019
        or else (Year = 2019
                 and then (Month > 5
                           or else (Month = 5 and then Day >= 1)))
      then
         return "reiwa";
      elsif Year > 1989
        or else (Year = 1989
                 and then (Month > 1
                           or else (Month = 1 and then Day >= 8)))
      then
         return "heisei";
      elsif Year > 1926
        or else (Year = 1926
                 and then (Month > 12
                           or else (Month = 12 and then Day >= 25)))
      then
         return "showa";
      elsif Year > 1912
        or else (Year = 1912
                 and then (Month > 7
                           or else (Month = 7 and then Day >= 30)))
      then
         return "taisho";
      elsif Year > 1868
        or else (Year = 1868
                 and then (Month > 9
                           or else (Month = 9 and then Day >= 8)))
      then
         return "meiji";
      elsif Year > 1865
        or else (Year = 1865
                 and then (Month > 5
                           or else (Month = 5 and then Day >= 1)))
      then
         return "keio";
      else
         return "";
      end if;
   end Japanese_Era;

   function Japanese_Era_Year
     (Era  : String;
      Year : Natural)
      return Natural
   is
   begin
      if Era = "reiwa" then
         return Year - 2018;
      elsif Era = "heisei" then
         return Year - 1988;
      elsif Era = "showa" then
         return Year - 1925;
      elsif Era = "taisho" then
         return Year - 1911;
      elsif Era = "meiji" then
         return Year - 1867;
      elsif Era = "keio" then
         return Year - 1864;
      else
         return Year;
      end if;
   end Japanese_Era_Year;

   procedure Put_Year
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Locale   : String;
      Year     : Natural;
      Month    : Natural;
      Day      : Natural;
      Width    : Natural := 4;
      Emit_Era : Boolean := True)
   is
      Calendar : constant Calendar_System := Calendar_For (Locale);
      Out_Year : Natural := Year;
   begin
      case Calendar is
         when Gregorian | ISO8601 =>
            null;
         when Buddhist =>
            Out_Year := Year + 543;
         when Japanese =>
            declare
               Era : constant String := Japanese_Era (Year, Month, Day);
            begin
               if Era /= "" then
                  if Emit_Era then
                     Put
                       (Target, Last, Overflow,
                        Era_Name (Locale, "japanese", Era));
                     Put
                       (Target, Last, Overflow,
                        Era_Year_Separator (Locale, "japanese"));
                  end if;
                  Out_Year := Japanese_Era_Year (Era, Year);
               end if;
            end;
         when Julian =>
            null;
         when ROC =>
            Out_Year := (if Year > 1911 then Year - 1911 else 1);
         when Coptic | Ethiopic | Ethiopic_Amete_Alem | Islamic_Civil
            | Islamic_TBLA | Indian | Persian | Hebrew =>
            null;
         when Unsupported_Calendar =>
            null;
      end case;

      Put_Number
        (Target    => Target,
         Last      => Last,
         Overflow  => Overflow,
         Locale    => Locale,
         Value     => (if Width = 2 then Out_Year mod 100 else Out_Year),
         Min_Width => Width);
   end Put_Year;

   function Calendar_Era_Name
     (Locale : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural)
      return String
   is
      Calendar : constant Calendar_System := Calendar_For (Locale);
   begin
      case Calendar is
         when Gregorian | ISO8601 | Buddhist | Julian =>
            return Era_Name (Locale, "gregorian", "ad");
         when ROC =>
            return Era_Name (Locale, "roc", "minguo");
         when Coptic | Ethiopic =>
            return "A.M.";
         when Ethiopic_Amete_Alem =>
            return "A.A.";
         when Islamic_Civil | Islamic_TBLA =>
            return "AH";
         when Indian =>
            return "Saka";
         when Persian =>
            return "AP";
         when Hebrew =>
            return "AM";
         when Unsupported_Calendar =>
            return "";
         when Japanese =>
            declare
               Era : constant String := Japanese_Era (Year, Month, Day);
            begin
               return
                 (if Era /= ""
                  then Era_Name (Locale, "japanese", Era)
                  else Era_Name (Locale, "gregorian", "ad"));
            end;
      end case;
   end Calendar_Era_Name;

   function Zone_Name (Option : String; Locale : String := "") return String;

   function Canonical_Zone_Name (Zone : String) return String is
   begin
      if Zone = "utc"
        or else Zone = "Utc"
        or else Zone = "UT"
        or else Zone = "ut"
      then
         return "UTC";
      elsif Zone = "z" then
         return "Z";
      elsif Zone = "zulu" then
         return "Zulu";
      elsif Zone = "Etc/UTC"
        or else Zone = "Etc/utc"
      then
         return "Etc/UTC";
      elsif Zone = "gmt"
        or else Zone = "Gmt"
      then
         return "GMT";
      elsif Zone = "Etc/GMT"
        or else Zone = "Etc/gmt"
      then
         return "Etc/GMT";
      end if;

      return I18N.CLDR_Data.Canonical_Time_Zone (Zone);
   end Canonical_Zone_Name;

   function Zone_Offset_Minutes
     (Zone  : String;
      Valid : out Boolean)
      return Integer;

   function Zone_Offset_Seconds
     (Zone  : String;
      Valid : out Boolean)
      return Integer;

   function Zone_Offset_Minutes_At
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Valid  : out Boolean)
      return Integer;

   function Zone_Offset_Seconds_At
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Valid  : out Boolean)
      return Integer;

   function First_Unquoted_Comma (Text : String) return Natural is
      Index    : Natural := Text'First;
      In_Quote : Boolean := False;
   begin
      while Index <= Text'Last loop
         if Text (Index) = Character'Val (39) then
            if Index < Text'Last
              and then Text (Index + 1) = Character'Val (39)
            then
               Index := Index + 2;
            else
               In_Quote := not In_Quote;
               Index := Index + 1;
            end if;
         elsif Text (Index) = ',' and then not In_Quote then
            return Index;
         else
            Index := Index + 1;
         end if;
      end loop;

      return 0;
   end First_Unquoted_Comma;

   function Style_Name (Option : String) return String is
      Comma : constant Natural := First_Unquoted_Comma (Option);
   begin
      if Comma /= 0 then
         declare
            Last : Natural := Comma - 1;
         begin
            while Last >= Option'First and then Option (Last) = ' ' loop
               Last := Last - 1;
            end loop;

            if Last < Option'First then
               return "";
            end if;

            return Option (Option'First .. Last);
         end;
      end if;

      return Option;
   end Style_Name;

   function Is_Skeleton (Style : String) return Boolean is
   begin
      return Style'Length >= 3
        and then Style (Style'First .. Style'First + 1) = "::";
   end Is_Skeleton;

   function Skeleton_Text (Style : String) return String is
   begin
      if Is_Skeleton (Style) then
         return Style (Style'First + 2 .. Style'Last);
      else
         return "";
      end if;
   end Skeleton_Text;

   function Resolve_Skeleton_Pattern
     (Locale   : String;
      Skeleton : String)
      return String
   is
      Override_Found : Boolean;
      Override_Pattern : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "available_format." & Skeleton, Override_Found);
      Pattern : constant String :=
        I18N.CLDR_Data.Available_Format_Pattern (Locale, Skeleton);
   begin
      if Override_Found then
         return Override_Pattern;
      else
         return (if Pattern = "" then Skeleton else Pattern);
      end if;
   end Resolve_Skeleton_Pattern;

   function Style_Tail (Style : String) return String is
      Comma : constant Natural := First_Unquoted_Comma (Style);
   begin
      if Comma /= 0 then
         return Style (Comma .. Style'Last);
      end if;

      return "";
   end Style_Tail;

   function Normalize_Skeleton_Style_Alias (Style : String) return String is
      Style_Only : constant String := Style_Name (Style);
   begin
      if Is_Skeleton (Style_Only) then
         declare
            Skeleton : constant String := Skeleton_Text (Style_Only);
         begin
            if Skeleton = "short"
              or else Skeleton = "medium"
              or else Skeleton = "long"
              or else Skeleton = "full"
            then
               return Skeleton & Style_Tail (Style);
            elsif Skeleton = "date-short"
              or else Skeleton = "time-short"
              or else Skeleton = "datetime-short"
              or else Skeleton = "dateTime-short"
            then
               return "short" & Style_Tail (Style);
            elsif Skeleton = "date/short"
              or else Skeleton = "time/short"
              or else Skeleton = "datetime/short"
              or else Skeleton = "dateTime/short"
            then
               return "short" & Style_Tail (Style);
            elsif Skeleton = "date-medium"
              or else Skeleton = "time-medium"
              or else Skeleton = "datetime-medium"
              or else Skeleton = "dateTime-medium"
            then
               return "medium" & Style_Tail (Style);
            elsif Skeleton = "date/medium"
              or else Skeleton = "time/medium"
              or else Skeleton = "datetime/medium"
              or else Skeleton = "dateTime/medium"
            then
               return "medium" & Style_Tail (Style);
            elsif Skeleton = "date-long"
              or else Skeleton = "time-long"
              or else Skeleton = "datetime-long"
              or else Skeleton = "dateTime-long"
            then
               return "long" & Style_Tail (Style);
            elsif Skeleton = "date/long"
              or else Skeleton = "time/long"
              or else Skeleton = "datetime/long"
              or else Skeleton = "dateTime/long"
            then
               return "long" & Style_Tail (Style);
            elsif Skeleton = "date-full"
              or else Skeleton = "time-full"
              or else Skeleton = "datetime-full"
              or else Skeleton = "dateTime-full"
            then
               return "full" & Style_Tail (Style);
            elsif Skeleton = "date/full"
              or else Skeleton = "time/full"
              or else Skeleton = "datetime/full"
              or else Skeleton = "dateTime/full"
            then
               return "full" & Style_Tail (Style);
            end if;
         end;
      end if;

      return Style;
   end Normalize_Skeleton_Style_Alias;

   Apostrophe : constant Character := Character'Val (39);

   function Is_Date_Field (C : Character) return Boolean is
   begin
      case C is
         when 'G' | 'y' | 'Y' | 'u' | 'U' | 'r' | 'Q' | 'q'
            | 'M' | 'L' | 'l' | 'w' | 'W' | 'd' | 'D' | 'F'
            | 'g' | 'E' | 'e' | 'c' =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Date_Field;

   function Is_Time_Field (C : Character) return Boolean is
   begin
      case C is
         when 'a' | 'b' | 'B' | 'h' | 'H' | 'K' | 'k' | 'j' | 'J'
            | 'C' | 'm' | 's' | 'S' | 'A' | 'n' | 'N' | 'z' | 'Z'
            | 'O' | 'v' | 'V' | 'X' | 'x' =>
            return True;
         when others =>
            return False;
      end case;
   end Is_Time_Field;

   function Is_Field (C : Character) return Boolean is
     (Is_Date_Field (C) or else Is_Time_Field (C));

   function Has_Date_Field (Skeleton : String) return Boolean is
      Index : Natural := Skeleton'First;
   begin
      while Index <= Skeleton'Last loop
         if Skeleton (Index) = Apostrophe then
            if Index < Skeleton'Last and then Skeleton (Index + 1) = Apostrophe
            then
               Index := Index + 2;
            else
               Index := Index + 1;
               while Index <= Skeleton'Last
                 and then Skeleton (Index) /= Apostrophe
               loop
                  Index := Index + 1;
               end loop;
               Index := Index + 1;
            end if;
         elsif Is_Date_Field (Skeleton (Index)) then
            return True;
         else
            Index := Index + 1;
         end if;
      end loop;
      return False;
   end Has_Date_Field;

   function Has_Time_Field (Skeleton : String) return Boolean is
      Index : Natural := Skeleton'First;
   begin
      while Index <= Skeleton'Last loop
         if Skeleton (Index) = Apostrophe then
            if Index < Skeleton'Last and then Skeleton (Index + 1) = Apostrophe
            then
               Index := Index + 2;
            else
               Index := Index + 1;
               while Index <= Skeleton'Last
                 and then Skeleton (Index) /= Apostrophe
               loop
                  Index := Index + 1;
               end loop;
               Index := Index + 1;
            end if;
         elsif Is_Time_Field (Skeleton (Index)) then
            return True;
         else
            Index := Index + 1;
         end if;
      end loop;
      return False;
   end Has_Time_Field;

   function Is_Supported_Skeleton (Skeleton : String) return Boolean is
      Index : Natural := Skeleton'First;
   begin
      if Skeleton'Length = 0 then
         return False;
      end if;

      while Index <= Skeleton'Last loop
         if Skeleton (Index) = Apostrophe then
            if Index < Skeleton'Last and then Skeleton (Index + 1) = Apostrophe
            then
               Index := Index + 2;
            else
               declare
                  Closed : Boolean := False;
               begin
                  Index := Index + 1;
                  while Index <= Skeleton'Last loop
                     if Skeleton (Index) = Apostrophe then
                        if Index < Skeleton'Last
                          and then Skeleton (Index + 1) = Apostrophe
                        then
                           Index := Index + 2;
                        else
                           Closed := True;
                           Index := Index + 1;
                           exit;
                        end if;
                     else
                        Index := Index + 1;
                     end if;
                  end loop;

                  if not Closed then
                     return False;
                  end if;
               end;
            end if;
         elsif Is_Field (Skeleton (Index)) then
            Index := Index + 1;
         else
            return False;
         end if;
      end loop;

      return True;
   end Is_Supported_Skeleton;

   function Month_Name_Short
     (Locale     : String;
      Month      : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone then "month_standalone_short" else "month_short"),
           Month, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Month_Name_Short (Locale, Month);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("month_name_short", Base_Locale (Locale), Index_Key (Month),
                 SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Month_Name_Short
                      (Base_Locale (Locale), Month));
         end;
      end if;
   end Month_Name_Short;

   function Month_Name_Narrow
     (Locale     : String;
      Month      : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone then "month_standalone_narrow" else "month_narrow"),
           Month, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Month_Name_Narrow (Locale, Month);
      else
         return First_UTF8_Character (Month_Name (Locale, Month));
      end if;
   end Month_Name_Narrow;

   function Weekday_Name_Short
     (Locale     : String;
      Day        : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone then "weekday_standalone_short" else "weekday_short"),
           Day, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Weekday_Name_Short (Locale, Day);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("weekday_name_short", Base_Locale (Locale), Index_Key (Day),
                 SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Weekday_Name_Short
                      (Base_Locale (Locale), Day));
         end;
      end if;
   end Weekday_Name_Short;

   function Weekday_Name_Narrow
     (Locale     : String;
      Day        : Natural;
      Standalone : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone
            then "weekday_standalone_narrow"
            else "weekday_narrow"),
           Day, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Weekday_Name_Narrow (Locale, Day);
      else
         return First_UTF8_Character (Weekday_Name (Locale, Day));
      end if;
   end Weekday_Name_Narrow;

   function Quarter_Name
     (Locale       : String;
      Quarter      : Natural;
      Quarter_Text : String;
      Standalone   : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale, (if Standalone then "quarter_standalone" else "quarter"),
           Quarter, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Quarter_Name (Locale, Quarter, Quarter_Text);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("quarter_name", Locale, Index_Key (Quarter), SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Quarter_Name
                      (Locale, Quarter, Quarter_Text));
         end;
      end if;
   end Quarter_Name;

   function Quarter_Name_Short
     (Locale       : String;
      Quarter      : Natural;
      Quarter_Text : String;
      Standalone   : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone then "quarter_standalone_short" else "quarter_short"),
           Quarter, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Quarter_Name_Short (Locale, Quarter, Quarter_Text);
      else
         declare
            SF : Boolean;
            SV : constant String :=
              I18N.Locale_Data.Lookup
                ("quarter_name_short", Locale, Index_Key (Quarter), SF);
         begin
            return
              (if SF then SV
               else I18N.CLDR_Data.Quarter_Name_Short
                      (Locale, Quarter, Quarter_Text));
         end;
      end if;
   end Quarter_Name_Short;

   function Quarter_Name_Narrow
     (Locale       : String;
      Quarter      : Natural;
      Quarter_Text : String;
      Standalone   : Boolean := False)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Indexed_Text
          (Locale,
           (if Standalone
            then "quarter_standalone_narrow"
            else "quarter_narrow"),
           Quarter, Found);
   begin
      if Found then
         return Value;
      elsif Standalone then
         return Quarter_Name_Narrow (Locale, Quarter, Quarter_Text);
      else
         return Quarter_Text;
      end if;
   end Quarter_Name_Narrow;

   function Day_Period_Name
     (Locale : String;
      Period : String;
      Width  : Natural)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Width = 4 or else Width > 5
            then "day_period_wide."
            elsif Width = 5
            then "day_period_narrow."
            else "day_period.") & Period,
           Found);
   begin
      if Found then
         return Value;
      elsif Width = 5 then
         return Day_Period_Name (Locale, Period, 3);
      else
         return
           I18N.CLDR_Data.Day_Period_Name
             (Base_Locale (Locale), Period, Width = 4 or else Width > 5);
      end if;
   end Day_Period_Name;

   function Era_Name
     (Locale   : String;
      Calendar : String;
      Era      : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "era." & Calendar & "." & Era, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Era_Name (Base_Locale (Locale), Calendar, Era));
   end Era_Name;

   function Era_Year_Separator
     (Locale   : String;
      Calendar : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "era_separator." & Calendar, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Era_Year_Separator (Locale, Calendar));
   end Era_Year_Separator;

   function Time_Zone_Display_Name
     (Locale : String;
      Zone   : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "timezone_display." & Zone, Found);
   begin
      return
        (if Found then Value
         else I18N.CLDR_Data.Time_Zone_Display_Name (Locale, Zone));
   end Time_Zone_Display_Name;

   function Time_Zone_Exemplar_Location
     (Locale : String;
      Zone   : String)
      return String;

   function Time_Zone_Specific_Display_Name
     (Locale   : String;
      Zone     : String;
      Daylight : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Daylight then "timezone_display_daylight."
            else "timezone_display_standard.") & Zone,
           Found);
   begin
      if Found then
         return Value;
      else
         declare
            Pattern_Found : Boolean;
            Pattern       : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale,
                 (if Daylight then "timezone_location_pattern_daylight"
                  else "timezone_location_pattern_standard"),
                 Pattern_Found);
         begin
            if Pattern_Found then
               declare
                  Location : constant String :=
                    Time_Zone_Exemplar_Location (Locale, Zone);
               begin
                  if Location = "UTC" then
                     return Location;
                  end if;

                  for Index in Pattern'First .. Pattern'Last - 2 loop
                     if Pattern (Index .. Index + 2) = "{0}" then
                        return Pattern (Pattern'First .. Index - 1)
                          & Location
                          & Pattern (Index + 3 .. Pattern'Last);
                     end if;
                  end loop;
               end;
            end if;
         end;
      end if;

      return Time_Zone_Display_Name (Locale, Zone);
   end Time_Zone_Specific_Display_Name;

   function Time_Zone_Exemplar_Location
     (Locale : String;
      Zone   : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "timezone_exemplar." & Zone, Found);
      Start : Positive := Zone'First;
   begin
      if Found then
         return Value;
      end if;

      declare
         Generated : constant String :=
           I18N.CLDR_Data.Time_Zone_Exemplar_Location (Locale, Zone);
      begin
         if Generated /= "" then
            return Generated;
         end if;
      end;

      if Zone = ""
        or else Zone = "UTC"
        or else Zone = "Z"
        or else Zone = "GMT"
        or else Zone = "Etc/UTC"
        or else Zone = "Etc/GMT"
      then
         return "UTC";
      end if;

      for Index in Zone'Range loop
         if Zone (Index) = '/' and then Index < Zone'Last then
            Start := Index + 1;
         end if;
      end loop;

      declare
         Result : String := Zone (Start .. Zone'Last);
      begin
         for Index in Result'Range loop
            if Result (Index) = '_' then
               Result (Index) := ' ';
            end if;
         end loop;

         return Result;
      end;
   end Time_Zone_Exemplar_Location;

   function Time_Zone_Short_Name
     (Locale   : String;
      Zone     : String;
      Daylight : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Daylight then "timezone_short_daylight."
            else "timezone_short.") & Zone,
           Found);
   begin
      return (if Found then Value else "");
   end Time_Zone_Short_Name;

   function Time_Zone_Generic_Short_Name
     (Locale : String;
      Zone   : String)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "timezone_generic_short." & Zone, Found);
   begin
      return (if Found then Value else "");
   end Time_Zone_Generic_Short_Name;

   function Time_Zone_Location_Pattern (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("timezone_location_pattern", Locale,
         I18N.CLDR_Data.Time_Zone_Location_Pattern'Access));

   function Time_Zone_Specific_Location_Pattern
     (Locale   : String;
      Daylight : Boolean)
      return String
   is
      Found : Boolean;
      Value : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if Daylight then "timezone_location_pattern_daylight"
            else "timezone_location_pattern_standard"),
           Found);
   begin
      return (if Found then Value else Time_Zone_Location_Pattern (Locale));
   end Time_Zone_Specific_Location_Pattern;

   function Apply_Time_Zone_Location_Pattern
     (Locale   : String;
      Location : String)
      return String
   is
      Pattern : constant String := Time_Zone_Location_Pattern (Locale);
   begin
      for Index in Pattern'First .. Pattern'Last - 2 loop
         if Pattern (Index .. Index + 2) = "{0}" then
            return Pattern (Pattern'First .. Index - 1)
              & Location
              & Pattern (Index + 3 .. Pattern'Last);
         end if;
      end loop;

      return Location & " Time";
   end Apply_Time_Zone_Location_Pattern;

   function Apply_Time_Zone_Specific_Location_Pattern
     (Locale   : String;
      Location : String;
      Daylight : Boolean)
      return String
   is
      Pattern : constant String :=
        Time_Zone_Specific_Location_Pattern (Locale, Daylight);
   begin
      for Index in Pattern'First .. Pattern'Last - 2 loop
         if Pattern (Index .. Index + 2) = "{0}" then
            return Pattern (Pattern'First .. Index - 1)
              & Location
              & Pattern (Index + 3 .. Pattern'Last);
         end if;
      end loop;

      return Apply_Time_Zone_Location_Pattern (Locale, Location);
   end Apply_Time_Zone_Specific_Location_Pattern;

   function GMT_Offset_Prefix (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("gmt_offset_prefix", Locale, I18N.CLDR_Data.GMT_Offset_Prefix'Access));

   function Time_Zone_UTC_Designator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("timezone_utc_designator", Locale,
         I18N.CLDR_Data.Time_Zone_UTC_Designator'Access));

   function Time_Zone_Offset_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("timezone_offset_separator", Locale,
         I18N.CLDR_Data.Time_Zone_Offset_Separator'Access));

   function Number_Plus_Sign (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("number_plus_sign", Locale, I18N.CLDR_Data.Number_Plus_Sign'Access));

   function Number_Minus_Sign (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("number_minus_sign", Locale, I18N.CLDR_Data.Number_Minus_Sign'Access));

   procedure Put_Zone
     (Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean;
      Style    : String;
      Locale   : String;
      Specific : Boolean;
      Daylight : Boolean)
   is
      Zone : constant String := Zone_Name (Style, Locale);
      Name : constant String :=
        (if Specific
         then Time_Zone_Specific_Display_Name (Locale, Zone, Daylight)
         else Time_Zone_Display_Name (Locale, Zone));
   begin
      if Name /= "" then
         Put (Target, Last, Overflow, Name);
      elsif Specific and then Zone /= "" then
         declare
            Location : constant String :=
              Time_Zone_Exemplar_Location (Locale, Zone);
         begin
            if Location = "UTC" then
               Put (Target, Last, Overflow, Location);
            else
               Put
                 (Target, Last, Overflow,
                  Apply_Time_Zone_Specific_Location_Pattern
                    (Locale, Location, Daylight));
            end if;
         end;
      end if;
   end Put_Zone;

   procedure Format_Skeleton_Into
     (Skeleton   : String;
      Style      : String;
      Locale     : String;
      Year       : Natural;
      Related_Year : Natural;
      Month      : Natural;
      Day        : Natural;
      Hour       : Natural;
      Minute     : Natural;
      Second     : Natural;
      Nanosecond : Natural;
      Target     : in out String;
      Last       : in out Natural;
      Overflow   : in out Boolean;
      Ok         : out Boolean)
   is
      Index      : Positive := Skeleton'First;
      Need_Sep   : Boolean := False;
      Last_Class : Character := Character'Val (0);
      Last_Field : Character := Character'Val (0);

      function Contains_Field (Field : Character) return Boolean is
      begin
         for Index in Skeleton'Range loop
            if Skeleton (Index) = Field then
               return True;
            end if;
         end loop;

         return False;
      end Contains_Field;

      Preferred_Hour_Cycle : constant Hour_Cycle := Hour_Cycle_For (Locale);
      Preferred_12_Hour : constant Boolean :=
        Preferred_Hour_Cycle = H11 or else Preferred_Hour_Cycle = H12;
      Add_Preferred_Day_Period  : constant Boolean :=
        Preferred_12_Hour
        and then (Contains_Field ('j') or else Contains_Field ('C'))
        and then not Contains_Field ('a')
        and then not Contains_Field ('b')
        and then not Contains_Field ('B');
      Has_Week_Data : constant Boolean := Week_Data_Overridden (Locale);
      Week_First_Day : constant Natural := First_Day_Of_Week (Locale);
      Week_Min_Days  : constant Natural := First_Week_Min_Days (Locale);
      Has_Era_Field : constant Boolean := Contains_Field ('G');

      function Field_Class (C : Character) return Character is
      begin
         case C is
            when 'G' | 'y' | 'Y' | 'u' | 'U' | 'r' | 'Q' | 'q'
               | 'M' | 'L' | 'l' | 'w' | 'W' | 'd' | 'D' | 'F'
               | 'g' | 'E' | 'e' | 'c' =>
               return 'D';
            when 'a' | 'b' | 'B' | 'h' | 'H' | 'K' | 'k' | 'j' | 'J'
               | 'C' | 'm' | 's' | 'S' | 'A' | 'n' | 'N' | 'z' | 'Z'
               | 'O' | 'v' | 'V' | 'X' | 'x' =>
               return 'T';
            when others =>
               return '?';
         end case;
      end Field_Class;

      procedure Put_Separator (Class : Character; Field : Character) is
      begin
         if Need_Sep then
            declare
               Override_Found : Boolean;
               Override       : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "date_time_field_separator", Override_Found);
            begin
               Put
                 (Target, Last, Overflow,
                  (if Override_Found
                       and then Last_Class = 'D'
                       and then Class = 'T'
                   then Override
                   else I18N.CLDR_Data.Date_Time_Field_Separator
                          (Locale, Last_Class, Class, Last_Field, Field)));
            end;
         end if;
         Need_Sep := True;
         Last_Class := Class;
         Last_Field := Field;
      end Put_Separator;

      procedure Put_Month (Width : Natural; Standalone : Boolean := False) is
      begin
         if Width <= 1 then
            Put_Number (Target, Last, Overflow, Locale, Month);
         elsif Width = 2 then
            Put_Number (Target, Last, Overflow, Locale, Month, 2);
         elsif Width = 3 then
            Put
              (Target, Last, Overflow,
               Month_Name_Short (Locale, Month, Standalone));
         elsif Width = 4 then
            Put
              (Target, Last, Overflow,
               Month_Name (Locale, Month, Standalone));
         else
            Put
              (Target, Last, Overflow,
               Month_Name_Narrow (Locale, Month, Standalone));
         end if;
      end Put_Month;

      procedure Put_Weekday (Width : Natural; Standalone : Boolean := False) is
         DOW : constant Natural := Day_Of_Week (Year, Month, Day);
      begin
         if Width = 5 then
            Put
              (Target, Last, Overflow,
               Weekday_Name_Narrow (Locale, DOW, Standalone));
         elsif Width = 6 then
            Put
              (Target, Last, Overflow,
               Weekday_Name_Short (Locale, DOW, Standalone));
         elsif Width >= 4 then
            Put
              (Target, Last, Overflow,
               Weekday_Name (Locale, DOW, Standalone));
         else
            Put
              (Target, Last, Overflow,
               Weekday_Name_Short (Locale, DOW, Standalone));
         end if;
      end Put_Weekday;

      procedure Put_Local_Weekday_Number (Width : Natural) is
         DOW   : constant Natural := Day_Of_Week (Year, Month, Day);
         First : constant Natural := First_Day_Of_Week (Locale);
         Value : constant Natural :=
           ((DOW + 7 - First) mod 7) + 1;
      begin
         Put_Number
           (Target, Last, Overflow, Locale, Value,
            (if Width >= 2 then 2 else 1));
      end Put_Local_Weekday_Number;

      procedure Put_Quarter (Width : Natural; Standalone : Boolean := False) is
         Quarter : constant Natural := ((Month - 1) / 3) + 1;
      begin
         if Width <= 2 then
            Put_Number
              (Target, Last, Overflow, Locale, Quarter,
               (if Width = 2 then 2 else 1));
         elsif Width = 3 then
            declare
               Quarter_Text : String (1 .. 8);
               Quarter_Last : Natural := 0;
               Quarter_Overflow : Boolean := False;
            begin
               Put_Number
                 (Quarter_Text, Quarter_Last, Quarter_Overflow, Locale,
                  Quarter);
               if not Quarter_Overflow then
                  Put
                    (Target, Last, Overflow,
                     Quarter_Name_Short
                       (Locale, Quarter, Quarter_Text (1 .. Quarter_Last),
                        Standalone));
               else
                  Overflow := True;
               end if;
            end;
         elsif Width = 4 then
            declare
               Quarter_Text : String (1 .. 8);
               Quarter_Last : Natural := 0;
               Quarter_Overflow : Boolean := False;
            begin
               Put_Number
                 (Quarter_Text, Quarter_Last, Quarter_Overflow, Locale,
                  Quarter);
               if not Quarter_Overflow then
                  Put
                    (Target, Last, Overflow,
                     Quarter_Name
                       (Locale, Quarter, Quarter_Text (1 .. Quarter_Last),
                        Standalone));
               else
                  Overflow := True;
               end if;
            end;
         else
            declare
               Quarter_Text : String (1 .. 8);
               Quarter_Last : Natural := 0;
               Quarter_Overflow : Boolean := False;
            begin
               Put_Number
                 (Quarter_Text, Quarter_Last, Quarter_Overflow, Locale,
                  Quarter);
               if not Quarter_Overflow then
                  Put
                    (Target, Last, Overflow,
                     Quarter_Name_Narrow
                       (Locale, Quarter, Quarter_Text (1 .. Quarter_Last),
                        Standalone));
               else
                  Overflow := True;
               end if;
            end;
         end if;
      end Put_Quarter;

      procedure Put_Day_Period (Width : Natural; Flexible : Boolean) is
         Minute_Of_Day : constant Natural := Hour * 60 + Minute;

         function Source_Period_Name (Period : String) return String is
            Value : constant String := Day_Period_Name (Locale, Period, Width);
         begin
            if Value /= "" then
               return Value;
            elsif Hour < 12 then
               return Day_Period_Name (Locale, "am", Width);
            else
               return Day_Period_Name (Locale, "pm", Width);
            end if;
         end Source_Period_Name;

         function Minute_From_HH_MM (Text : String) return Natural is
            Hour_Value : constant Natural :=
              (Character'Pos (Text (Text'First)) - Character'Pos ('0')) * 10
              + Character'Pos (Text (Text'First + 1)) - Character'Pos ('0');
            Minute_Value : constant Natural :=
              (Character'Pos (Text (Text'First + 3)) - Character'Pos ('0')) * 10
              + Character'Pos (Text (Text'First + 4)) - Character'Pos ('0');
         begin
            return Hour_Value * 60 + Minute_Value;
         end Minute_From_HH_MM;

         function Rule_Matches (Range_Text : String) return Boolean is
            Sep : Natural := 0;
         begin
            for Index in Range_Text'Range loop
               if Range_Text (Index) = '-' then
                  Sep := Index;
                  exit;
               end if;
            end loop;

            if Sep = 0 then
               return False;
            end if;

            declare
               Start_Minute : constant Natural :=
                 Minute_From_HH_MM (Range_Text (Range_Text'First .. Sep - 1));
               Stop_Minute  : constant Natural :=
                 Minute_From_HH_MM (Range_Text (Sep + 1 .. Range_Text'Last));
            begin
               if Start_Minute < Stop_Minute then
                  return Minute_Of_Day >= Start_Minute
                    and then Minute_Of_Day < Stop_Minute;
               else
                  return Minute_Of_Day >= Start_Minute
                    or else Minute_Of_Day < Stop_Minute;
               end if;
            end;
         end Rule_Matches;

         function Runtime_Rule_Period return String is
            function Exact_Matches (Period : String) return Boolean is
               Found : Boolean;
               Value : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "day_period_exact." & Period, Found);
            begin
               return Found
                 and then Minute_From_HH_MM (Value) = Minute_Of_Day;
            end Exact_Matches;
         begin
            if Exact_Matches ("midnight") then
               return "midnight";
            elsif Exact_Matches ("noon") then
               return "noon";
            elsif Exact_Matches ("night1") then
               return "night1";
            elsif Exact_Matches ("morning1") then
               return "morning1";
            elsif Exact_Matches ("afternoon1") then
               return "afternoon1";
            elsif Exact_Matches ("evening1") then
               return "evening1";
            elsif Exact_Matches ("am") then
               return "am";
            elsif Exact_Matches ("pm") then
               return "pm";
            end if;

            declare
               Found : Boolean;
               Value : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "day_period_rule.night1", Found);
            begin
               if Found and then Rule_Matches (Value) then
                  return "night1";
               end if;
            end;

            declare
               Found : Boolean;
               Value : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "day_period_rule.morning1", Found);
            begin
               if Found and then Rule_Matches (Value) then
                  return "morning1";
               end if;
            end;

            declare
               Found : Boolean;
               Value : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "day_period_rule.afternoon1", Found);
            begin
               if Found and then Rule_Matches (Value) then
                  return "afternoon1";
               end if;
            end;

            declare
               Found : Boolean;
               Value : constant String :=
                 I18N.Runtime_Data.Locale_Text
                   (Locale, "day_period_rule.evening1", Found);
            begin
               if Found and then Rule_Matches (Value) then
                  return "evening1";
               end if;
            end;

            return "";
         end Runtime_Rule_Period;
      begin
         if Flexible and then Hour = 0 and then Minute = 0 and then Second = 0 then
            Put
              (Target, Last, Overflow,
               Day_Period_Name (Locale, "midnight", Width));
         elsif Flexible and then Hour = 12 and then Minute = 0 and then Second = 0 then
            Put
              (Target, Last, Overflow,
               Day_Period_Name (Locale, "noon", Width));
         elsif Flexible and then Runtime_Rule_Period /= "" then
            Put
              (Target, Last, Overflow,
               Source_Period_Name (Runtime_Rule_Period));
         elsif Flexible and then Hour < 6 then
            Put
              (Target, Last, Overflow,
               Source_Period_Name ("night1"));
         elsif Flexible and then Hour < 12 then
            Put
              (Target, Last, Overflow,
               Source_Period_Name ("morning1"));
         elsif Flexible and then Hour < 18 then
            Put
              (Target, Last, Overflow,
               Source_Period_Name ("afternoon1"));
         elsif Flexible then
            Put
              (Target, Last, Overflow,
               Source_Period_Name ("evening1"));
         elsif Hour < 12 then
            Put
              (Target, Last, Overflow,
               Day_Period_Name (Locale, "am", Width));
         else
            Put
              (Target, Last, Overflow,
               Day_Period_Name (Locale, "pm", Width));
         end if;
      end Put_Day_Period;

      procedure Put_Fractional_Second (Width : Natural) is
         Scale : Natural;
         Digit : Natural;
      begin
         for Pos in 1 .. Width loop
            if Pos <= 9 then
               Scale := 1;
               for Step in 1 .. 9 - Pos loop
                  Scale := Scale * 10;
               end loop;
               Digit := (Nanosecond / Scale) mod 10;
               Put_Digit
                 (Target, Last, Overflow, Locale,
                  Character'Val (Character'Pos ('0') + Digit));
            else
               Put_Digit (Target, Last, Overflow, Locale, '0');
            end if;
         end loop;
      end Put_Fractional_Second;

      function Short_Zone_Display return String is
         Zone          : constant String := Zone_Name (Style, Locale);
         Family        : constant String :=
           I18N.CLDR_Data.Time_Zone_DST_Family (Zone);
         Current_Valid : Boolean;
         Base_Valid    : Boolean;
         Current       : constant Integer :=
           Zone_Offset_Minutes_At
             (Zone, Year, Month, Day, Hour, Minute, Current_Valid);
         Base          : constant Integer :=
           Zone_Offset_Minutes (Zone, Base_Valid);
         Daylight      : constant Boolean :=
           Current_Valid and then Base_Valid and then Current /= Base;
         Override_Name : constant String :=
           Time_Zone_Short_Name (Locale, Zone, Daylight);
         CLDR_Name     : constant String :=
           I18N.CLDR_Data.Time_Zone_Short_Name (Locale, Family, Daylight);
      begin
         if Override_Name /= "" then
            return Override_Name;
         elsif Zone = ""
           or else Zone = "UTC"
           or else Zone = "Z"
           or else Zone = "GMT"
           or else Zone = "Etc/UTC"
           or else Zone = "Etc/GMT"
         then
            return "UTC";
         elsif CLDR_Name /= "" then
            return CLDR_Name;
         else
            return "";
         end if;
      end Short_Zone_Display;

      function Short_Generic_Zone_Display return String is
         Zone   : constant String := Zone_Name (Style, Locale);
         Family : constant String :=
           I18N.CLDR_Data.Time_Zone_DST_Family (Zone);
         Override_Name : constant String :=
           Time_Zone_Generic_Short_Name (Locale, Zone);
         CLDR_Name     : constant String :=
           I18N.CLDR_Data.Time_Zone_Generic_Short_Name (Locale, Family);
      begin
         if Override_Name /= "" then
            return Override_Name;
         elsif Zone = ""
           or else Zone = "UTC"
           or else Zone = "Z"
           or else Zone = "GMT"
           or else Zone = "Etc/UTC"
           or else Zone = "Etc/GMT"
         then
            return "UTC";
         elsif CLDR_Name /= "" then
            return CLDR_Name;
         else
            return "";
         end if;
      end Short_Generic_Zone_Display;

      procedure Put_Offset
        (Width : Natural;
         Field : Character)
      is
         Valid        : Boolean;
         Offset       : constant Integer :=
           Zone_Offset_Seconds_At
             (Zone_Name (Style, Locale), Year, Month, Day, Hour, Minute,
              Second, Valid);
         Abs_Offset   : Natural;
         Hours        : Natural;
         Minutes      : Natural;
         Seconds      : Natural;
         Short_GMT    : constant Boolean := Field = 'O' and then Width < 4;
         Use_Colon    : constant Boolean :=
           (Field in 'X' | 'x' and then Width in 3 | 5)
           or else (Field = 'O' and then Width >= 4)
           or else (Field = 'Z' and then Width in 4 | 5);
         Use_GMT      : constant Boolean :=
           Field = 'O' or else (Field = 'Z' and then Width = 4);
         Use_Seconds  : Boolean;
      begin
         if not Valid then
            return;
         end if;

         if Field in 'X' | 'Z' and then Offset = 0
           and then (Field = 'X' or else Width = 5)
         then
            Put
              (Target, Last, Overflow,
               Time_Zone_UTC_Designator (Locale));
            return;
         end if;

         if Use_GMT then
            Put
              (Target, Last, Overflow,
               GMT_Offset_Prefix (Locale));

            if Short_GMT and then Offset = 0 then
               return;
            end if;
         end if;

         Abs_Offset := Natural (abs Offset);
         Hours := Abs_Offset / 3_600;
         Minutes := (Abs_Offset mod 3_600) / 60;
         Seconds := Abs_Offset mod 60;
         Use_Seconds :=
           (((Field in 'X' | 'x' and then Width >= 5)
             or else (Field = 'Z' and then Width = 5))
            and then Seconds /= 0);

         if Offset < 0 then
            Put
              (Target, Last, Overflow,
               Number_Minus_Sign (Locale));
         else
            Put
              (Target, Last, Overflow,
               Number_Plus_Sign (Locale));
         end if;
         Put_Number
           (Target, Last, Overflow, Locale, Hours,
            (if Short_GMT then 1 else 2));

         if Use_Colon or else (Short_GMT and then Minutes /= 0) then
            Put
              (Target, Last, Overflow,
               Time_Zone_Offset_Separator (Locale));
         end if;

         if Width >= 2 or else Minutes /= 0 or else Field = 'Z' then
            Put_Number (Target, Last, Overflow, Locale, Minutes, 2);
         end if;

         if Use_Seconds then
            if Use_Colon then
               Put
                 (Target, Last, Overflow,
                  Time_Zone_Offset_Separator (Locale));
            end if;
            Put_Number (Target, Last, Overflow, Locale, Seconds, 2);
         end if;
      end Put_Offset;

      procedure Put_Zone_Field (Width : Natural; Field : Character) is
         Zone : constant String := Zone_Name (Style);
      begin
         if Field = 'V' then
            if Width <= 2 then
               Put (Target, Last, Overflow, Zone);
            elsif Width = 3 then
               Put
                 (Target, Last, Overflow,
                  Time_Zone_Exemplar_Location (Locale, Zone));
            else
               declare
                  Location : constant String :=
                    Time_Zone_Exemplar_Location (Locale, Zone);
               begin
                  if Location = "UTC" then
                     Put (Target, Last, Overflow, Location);
                  else
                     Put
                       (Target, Last, Overflow,
                        Apply_Time_Zone_Location_Pattern
                          (Locale, Location));
                  end if;
               end;
            end if;
         else
            Put_Zone
              (Target, Last, Overflow, Style, Locale,
               Specific => False, Daylight => False);
         end if;
      end Put_Zone_Field;

      procedure Put_Short_Zone is
         Short_Name : constant String := Short_Zone_Display;
      begin
         if Short_Name = "" then
            Put_Offset (1, 'O');
         else
            Put (Target, Last, Overflow, Short_Name);
         end if;
      end Put_Short_Zone;

      procedure Put_Short_Generic_Zone is
         Short_Name : constant String := Short_Generic_Zone_Display;
      begin
         if Short_Name = "" then
            Put_Offset (1, 'O');
         else
            Put (Target, Last, Overflow, Short_Name);
         end if;
      end Put_Short_Generic_Zone;
   begin
      Ok := False;
      if not Is_Supported_Skeleton (Skeleton) then
         return;
      end if;

      while Index <= Skeleton'Last loop
         if Skeleton (Index) = Apostrophe then
            if Index < Skeleton'Last and then Skeleton (Index + 1) = Apostrophe
            then
               Put (Target, Last, Overflow, [1 => Apostrophe]);
               Index := Index + 2;
            else
               Index := Index + 1;
               while Index <= Skeleton'Last loop
                  if Skeleton (Index) = Apostrophe then
                     if Index < Skeleton'Last
                       and then Skeleton (Index + 1) = Apostrophe
                     then
                        Put (Target, Last, Overflow, [1 => Apostrophe]);
                        Index := Index + 2;
                     else
                        Index := Index + 1;
                        exit;
                     end if;
                  else
                     Put (Target, Last, Overflow, [1 => Skeleton (Index)]);
                     Index := Index + 1;
                  end if;
               end loop;
            end if;

            Need_Sep := False;
            Last_Class := Character'Val (0);
            Last_Field := Character'Val (0);
         else
            declare
               C     : constant Character := Skeleton (Index);
               Start : constant Positive := Index;
               Width : Natural;
               Value : Natural;
               Class : constant Character := Field_Class (C);
            begin
               while Index <= Skeleton'Last and then Skeleton (Index) = C loop
                  Index := Index + 1;
               end loop;
               Width := Index - Start;

               Put_Separator (Class, C);

               case C is
                  when 'G' =>
                     Put
                       (Target, Last, Overflow,
                        Calendar_Era_Name (Locale, Year, Month, Day));
                  when 'y' | 'u' | 'U' =>
                     Put_Year
                       (Target, Last, Overflow, Locale, Year, Month, Day,
                        (if Width = 2 then 2 else Width),
                        Emit_Era => not Has_Era_Field);
                  when 'r' =>
                     Put_Year
                       (Target, Last, Overflow, Locale, Related_Year,
                        Month, Day, (if Width = 2 then 2 else Width));
                  when 'Y' =>
                     Put_Year
                       (Target, Last, Overflow, Locale,
                        (if Has_Week_Data
                         then Week_Data_Week_Based_Year
                           (Year, Month, Day, Week_First_Day, Week_Min_Days)
                         else Week_Based_Year (Year, Month, Day)),
                        Month, Day,
                        (if Width = 2 then 2 else Width));
                  when 'Q' =>
                     Put_Quarter (Width);
                  when 'q' =>
                     Put_Quarter (Width, Standalone => True);
                  when 'M' =>
                     Put_Month (Width);
                  when 'L' =>
                     Put_Month (Width, Standalone => True);
                  when 'l' =>
                     Put_Number (Target, Last, Overflow, Locale, Month);
                  when 'w' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        (if Has_Week_Data
                         then Week_Data_Week_Of_Year
                           (Year, Month, Day, Week_First_Day, Week_Min_Days)
                         else ISO_Week_Of_Year (Year, Month, Day)),
                        (if Width >= 2 then 2 else 1));
                  when 'W' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        (if Has_Week_Data
                         then Week_Data_Week_Of_Month
                           (Year, Month, Day, Week_First_Day, Week_Min_Days)
                         else Week_Of_Month (Year, Month, Day)));
                  when 'd' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Day,
                        (if Width >= 2 then 2 else 1));
                  when 'D' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        Day_Of_Year (Year, Month, Day),
                        (if Width >= 2 then Width else 1));
                  when 'F' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        Day_Of_Week_In_Month (Day));
                  when 'g' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        Modified_Julian_Day (Year, Month, Day));
                  when 'E' =>
                     Put_Weekday (Width);
                  when 'e' | 'c' =>
                     if Width <= 2 then
                        Put_Local_Weekday_Number (Width);
                     else
                        Put_Weekday (Width, Standalone => C = 'c');
                     end if;
                  when 'H' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Hour,
                        (if Width >= 2 then 2 else 1));
                  when 'j' | 'J' | 'C' =>
                     case Preferred_Hour_Cycle is
                        when H11 =>
                           Value := Hour mod 12;
                        when H12 =>
                           Value := Hour mod 12;
                           if Value = 0 then
                              Value := 12;
                           end if;
                        when H23 =>
                           Value := Hour;
                        when H24 =>
                           Value := (if Hour = 0 then 24 else Hour);
                     end case;
                     Put_Number
                       (Target, Last, Overflow, Locale, Value,
                        (if Width >= 2 then 2 else 1));
                  when 'k' =>
                     Value := (if Hour = 0 then 24 else Hour);
                     Put_Number
                       (Target, Last, Overflow, Locale, Value,
                        (if Width >= 2 then 2 else 1));
                  when 'h' =>
                     Value := Hour mod 12;
                     if Value = 0 then
                        Value := 12;
                     end if;
                     Put_Number
                       (Target, Last, Overflow, Locale, Value,
                        (if Width >= 2 then 2 else 1));
                  when 'K' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Hour mod 12,
                        (if Width >= 2 then 2 else 1));
                  when 'm' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Minute,
                        (if Width >= 2 then 2 else 1));
                  when 's' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Second,
                        (if Width >= 2 then 2 else 1));
                  when 'S' =>
                     Put_Fractional_Second (Width);
                  when 'A' =>
                     Put_Number
                       (Target, Last, Overflow, Locale,
                        ((Hour * 60) + Minute) * 60_000 + Second * 1_000
                        + Nanosecond / 1_000_000);
                  when 'n' =>
                     Put_Number
                       (Target, Last, Overflow, Locale, Nanosecond,
                        (if Width >= 2 then Width else 1));
                  when 'N' =>
                     Put_Long_Long_Natural
                       (Target, Last, Overflow, Locale,
                        ((Long_Long_Integer (Hour) * 60
                          + Long_Long_Integer (Minute)) * 60
                         + Long_Long_Integer (Second)) * 1_000_000_000
                        + Long_Long_Integer (Nanosecond),
                        (if Width >= 2 then Width else 1));
                  when 'a' =>
                     Put_Day_Period (Width, Flexible => False);
                  when 'b' | 'B' =>
                     Put_Day_Period (Width, Flexible => True);
                  when 'z' | 'Z' =>
                     if C = 'Z' then
                        Put_Offset (Width, C);
                     elsif Width <= 3 then
                        Put_Short_Zone;
                     else
                        declare
                           Current_Valid : Boolean;
                           Base_Valid    : Boolean;
                           Zone_Id       : constant String :=
                             Zone_Name (Style, Locale);
                           Current       : constant Integer :=
                             Zone_Offset_Minutes_At
                               (Zone_Id, Year, Month, Day, Hour, Minute,
                                Current_Valid);
                           Base          : constant Integer :=
                             Zone_Offset_Minutes (Zone_Id, Base_Valid);
                           Daylight      : constant Boolean :=
                             Current_Valid
                             and then Base_Valid
                             and then Current /= Base;
                        begin
                           Put_Zone
                             (Target, Last, Overflow, Style, Locale,
                              Specific => True, Daylight => Daylight);
                        end;
                     end if;
                  when 'O' | 'X' | 'x' =>
                     Put_Offset (Width, C);
                  when 'v' | 'V' =>
                     if C = 'v' and then Width <= 3 then
                        Put_Short_Generic_Zone;
                     else
                        Put_Zone_Field (Width, C);
                     end if;
                  when others =>
                     return;
               end case;
            end;
         end if;
      end loop;

      if Add_Preferred_Day_Period then
         Put_Separator ('T', 'a');
         Put_Day_Period (1, Flexible => False);
      end if;

      Ok := not Overflow;
   end Format_Skeleton_Into;

   function Zone_Name (Option : String; Locale : String := "") return String is
      Comma : constant Natural := First_Unquoted_Comma (Option);
   begin
      if Comma /= 0 then
         declare
            First : Natural := Comma + 1;
            Last  : Natural := Option'Last;
         begin
            while First <= Option'Last and then Option (First) = ' ' loop
               First := First + 1;
            end loop;

            while Last >= First and then Option (Last) = ' ' loop
               Last := Last - 1;
            end loop;

            if Last < First then
               return "";
            end if;

            return Canonical_Zone_Name (Option (First .. Last));
         end;
      end if;

      if Locale /= "" then
         declare
            Found : Boolean;
            Zone  : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, "default_timezone", Found);
         begin
            if Found then
               return Canonical_Zone_Name (Zone);
            end if;
         end;
      end if;

      return "";
   end Zone_Name;

   function Parse_Offset_Seconds_Text
     (Text    : String;
      Seconds : out Integer)
      return Boolean
   is
      Start       : Positive := Text'First;
      Negative    : Boolean := False;
      First_Sep   : Natural := 0;
      Second_Sep  : Natural := 0;
      Colon_Count : Natural := 0;
   begin
      Seconds := 0;

      if Text'Length = 0 then
         return False;
      end if;

      if Text = "Z" or else Text = "z"
        or else Text = "UTC" or else Text = "utc"
        or else Text = "GMT" or else Text = "gmt"
      then
         return True;
      end if;

      if Text (Text'First) = '-' or else Text (Text'First) = '+' then
         Negative := Text (Text'First) = '-';
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = ':' then
            Colon_Count := Colon_Count + 1;
            if Colon_Count > 2 then
               return False;
            elsif First_Sep = 0 then
               First_Sep := Index;
            else
               Second_Sep := Index;
            end if;
         elsif Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;
      if First_Sep /= 0 and then First_Sep - Start /= 2 then
         return False;
      end if;

      declare
         Digit_Length : constant Natural := Text'Last - Start + 1;
         Hours_Text   : constant String :=
           (if First_Sep /= 0 then Text (Start .. First_Sep - 1)
            elsif Digit_Length = 1 or else Digit_Length = 2
            then Text (Start .. Text'Last)
            elsif Digit_Length = 3 then Text (Start .. Start)
            elsif Digit_Length = 4 then Text (Start .. Start + 1)
            else "");
         Mins_Text    : constant String :=
           (if First_Sep /= 0 and then Second_Sep = 0
            then Text (First_Sep + 1 .. Text'Last)
            elsif First_Sep /= 0
            then Text (First_Sep + 1 .. Second_Sep - 1)
            elsif Digit_Length = 1 or else Digit_Length = 2 then "00"
            elsif Digit_Length = 3 then Text (Start + 1 .. Text'Last)
            elsif Digit_Length = 4 then Text (Start + 2 .. Text'Last)
            else "");
         Secs_Text : constant String :=
           (if Second_Sep = 0 then "00"
            else Text (Second_Sep + 1 .. Text'Last));
      begin
         if Hours_Text'Length = 0
           or else Mins_Text'Length = 0
           or else Secs_Text'Length = 0
           or else Hours_Text'Length > 2
           or else Mins_Text'Length /= 2
           or else Secs_Text'Length /= 2
         then
            return False;
         end if;

         declare
            Hours : constant Integer := Integer'Value (Hours_Text);
            Mins  : constant Integer := Integer'Value (Mins_Text);
            Secs  : constant Integer := Integer'Value (Secs_Text);
         begin
            if Hours not in 0 .. 23
              or else Mins not in 0 .. 59
              or else Secs not in 0 .. 59
            then
               return False;
            end if;

            Seconds := Hours * 3_600 + Mins * 60 + Secs;
            if Negative then
               Seconds := -Seconds;
            end if;
            return True;
         end;
      end;
   exception
      when Constraint_Error =>
         return False;
   end Parse_Offset_Seconds_Text;

   function Zone_Offset_Seconds
     (Zone : String;
      Valid : out Boolean)
      return Integer
   is
   begin
      declare
         Override_Found : Boolean;
         Override_Offset : constant Integer :=
           I18N.Runtime_Data.Time_Zone_Base_Offset_Minutes
             (Zone, Override_Found);
      begin
         if Override_Found then
            Valid := True;
            return Override_Offset * 60;
         end if;
      end;

      declare
         Offset : constant Integer :=
           I18N.CLDR_Data.Time_Zone_Base_Offset_Minutes (Zone, Valid);
      begin
         if Valid then
            return Offset * 60;
         end if;
      end;

      declare
         Offset_Seconds : constant Integer :=
           I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
             (Zone, 2000, 1, 1, 0, 0, 0, Valid);
      begin
         if Valid then
            return Offset_Seconds;
         end if;
      end;

      declare
         Offset_Seconds : Integer;
      begin
         if Parse_Offset_Seconds_Text (Zone, Offset_Seconds) then
            Valid := True;
            return Offset_Seconds;
         else
            Valid := False;
            return 0;
         end if;
      end;
   end Zone_Offset_Seconds;

   function Zone_Offset_Minutes
     (Zone : String;
      Valid : out Boolean)
      return Integer
   is
   begin
      declare
         Override_Found : Boolean;
         Override_Offset : constant Integer :=
           I18N.Runtime_Data.Time_Zone_Base_Offset_Minutes
             (Zone, Override_Found);
      begin
         if Override_Found then
            Valid := True;
            return Override_Offset;
         end if;
      end;

      declare
         Offset : constant Integer :=
           I18N.CLDR_Data.Time_Zone_Base_Offset_Minutes (Zone, Valid);
      begin
         if Valid then
            return Offset;
         end if;
      end;

      declare
         Offset_Seconds : constant Integer :=
           I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
             (Zone, 2000, 1, 1, 0, 0, 0, Valid);
      begin
         if Valid then
            return Offset_Seconds / 60;
         end if;
      end;

      declare
         Offset_Seconds : Integer;
      begin
         if Parse_Offset_Seconds_Text (Zone, Offset_Seconds) then
            if Offset_Seconds mod 60 /= 0 then
               Valid := False;
               return 0;
            end if;
            Valid := True;
            return Offset_Seconds / 60;
         else
            Valid := False;
            return 0;
         end if;
      end;
   end Zone_Offset_Minutes;

   function Last_Sunday (Year : Natural; Month : Natural) return Natural is
      Day : Natural := Days_In_Month (Year, Month);
   begin
      while Day_Of_Week (Year, Month, Day) /= 0 loop
         Day := Day - 1;
      end loop;
      return Day;
   end Last_Sunday;

   function Nth_Sunday
     (Year  : Natural;
      Month : Natural;
      N     : Positive)
      return Natural
   is
      Day   : Natural := 1;
      Count : Natural := 0;
   begin
      while Day <= Days_In_Month (Year, Month) loop
         if Day_Of_Week (Year, Month, Day) = 0 then
            Count := Count + 1;
            if Count = N then
               return Day;
            end if;
         end if;
         Day := Day + 1;
      end loop;
      return 0;
   end Nth_Sunday;

   function On_Or_After
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Ref_Month : Natural;
      Ref_Day   : Natural;
      Ref_Hour  : Natural)
      return Boolean
   is
      pragma Unreferenced (Year, Minute);
   begin
      return Month > Ref_Month
        or else (Month = Ref_Month
                 and then
                   (Day > Ref_Day
                    or else (Day = Ref_Day
                             and then
                               Hour >= Ref_Hour)));
   end On_Or_After;

   function Before
     (Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Ref_Month : Natural;
      Ref_Day   : Natural;
      Ref_Hour  : Natural)
      return Boolean
   is
   begin
      return Month < Ref_Month
        or else (Month = Ref_Month
                 and then
                   (Day < Ref_Day
                    or else (Day = Ref_Day and then Hour < Ref_Hour)));
   end Before;

   function Zone_Offset_Minutes_At
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Valid  : out Boolean)
      return Integer
   is
      Start_Day : Natural;
      End_Day   : Natural;
      Family    : constant String := I18N.CLDR_Data.Time_Zone_DST_Family (Zone);
   begin
      declare
         Runtime_Valid : Boolean;
         Runtime_Offset : constant Integer :=
           I18N.Runtime_Data.Time_Zone_Offset_Seconds_At_UTC
             (Zone, Year, Month, Day, Hour, Minute, 0, Runtime_Valid);
      begin
         if Runtime_Valid then
            Valid := True;
            return Runtime_Offset / 60;
         end if;
      end;

      if Family = "europe-central" then
         Valid := True;
         Start_Day := Last_Sunday (Year, 3);
         End_Day := Last_Sunday (Year, 10);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 1)
           and then Before (Month, Day, Hour, 10, End_Day, 1)
         then
            return 120;
         else
            return 60;
         end if;
      elsif Family = "europe-london" then
         Valid := True;
         Start_Day := Last_Sunday (Year, 3);
         End_Day := Last_Sunday (Year, 10);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 1)
           and then Before (Month, Day, Hour, 10, End_Day, 1)
         then
            return 60;
         else
            return 0;
         end if;
      elsif Family = "europe-eastern" then
         Valid := True;
         Start_Day := Last_Sunday (Year, 3);
         End_Day := Last_Sunday (Year, 10);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 1)
           and then Before (Month, Day, Hour, 10, End_Day, 1)
         then
            return 180;
         else
            return 120;
         end if;
      elsif Family = "america-eastern" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 3, 2);
         End_Day := Nth_Sunday (Year, 11, 1);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 7)
           and then Before (Month, Day, Hour, 11, End_Day, 6)
         then
            return -240;
         else
            return -300;
         end if;
      elsif Family = "america-central" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 3, 2);
         End_Day := Nth_Sunday (Year, 11, 1);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 8)
           and then Before (Month, Day, Hour, 11, End_Day, 7)
         then
            return -300;
         else
            return -360;
         end if;
      elsif Family = "america-mexico-city" then
         Valid := True;
         if Year in 1996 .. 2022 then
            Start_Day := Nth_Sunday (Year, 4, 1);
            End_Day := Last_Sunday (Year, 10);
            if On_Or_After
                 (Year, Month, Day, Hour, Minute, 4, Start_Day, 8)
              and then Before (Month, Day, Hour, 10, End_Day, 7)
            then
               return -300;
            end if;
         end if;
         return -360;
      elsif Family = "america-sao-paulo" then
         Valid := True;
         if Year in 2008 .. 2018 then
            if Year = 2018 then
               Start_Day := Nth_Sunday (Year, 11, 1);
               if On_Or_After
                    (Year, Month, Day, Hour, Minute, 11, Start_Day, 3)
               then
                  return -120;
               end if;
            else
               Start_Day := Nth_Sunday (Year, 10, 3);
               if On_Or_After
                    (Year, Month, Day, Hour, Minute, 10, Start_Day, 3)
               then
                  return -120;
               end if;
            end if;
         end if;

         if Year in 2009 .. 2019 then
            End_Day := Nth_Sunday (Year, 2, 3);
            if Before (Month, Day, Hour, 2, End_Day, 2) then
               return -120;
            end if;
         end if;

         return -180;
      elsif Family = "america-mountain" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 3, 2);
         End_Day := Nth_Sunday (Year, 11, 1);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 9)
           and then Before (Month, Day, Hour, 11, End_Day, 8)
         then
            return -360;
         else
            return -420;
         end if;
      elsif Family = "america-pacific" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 3, 2);
         End_Day := Nth_Sunday (Year, 11, 1);
         if On_Or_After
              (Year, Month, Day, Hour, Minute, 3, Start_Day, 10)
           and then Before (Month, Day, Hour, 11, End_Day, 9)
         then
            return -420;
         else
            return -480;
         end if;
      elsif Family = "pacific-new-zealand" then
         Valid := True;
         Start_Day := Last_Sunday (Year, 9);
         End_Day := Nth_Sunday (Year, 4, 1);
         if Month < 4
           or else Month > 9
           or else (Month = 4 and then Day < End_Day)
           or else (Month = 9 and then Day >= Start_Day)
         then
            return 780;
         else
            return 720;
         end if;
      elsif Family = "australia-eastern" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 10, 1) - 1;
         End_Day := Nth_Sunday (Year, 4, 1) - 1;
         if Month < 4
           or else Month > 10
           or else (Month = 4
                    and then
                      (Day < End_Day
                       or else (Day = End_Day and then Hour < 16)))
           or else (Month = 10
                    and then
                      (Day > Start_Day
                       or else (Day = Start_Day and then Hour >= 16)))
         then
            return 660;
         else
            return 600;
         end if;
      elsif Family = "australia-central" then
         Valid := True;
         Start_Day := Nth_Sunday (Year, 10, 1) - 1;
         End_Day := Nth_Sunday (Year, 4, 1) - 1;
         if Month < 4
           or else Month > 10
           or else (Month = 4
                    and then
                      (Day < End_Day
                       or else (Day = End_Day and then Hour < 16)))
           or else (Month = 10
                    and then
                      (Day > Start_Day
                       or else (Day = Start_Day and then Hour >= 16)))
         then
            return 630;
         else
            return 570;
         end if;
      elsif Family = "asia-jerusalem" then
         Valid := True;
         if Year >= 2013 then
            Start_Day := Last_Sunday (Year, 3) - 2;
            End_Day := Last_Sunday (Year, 10);
            if On_Or_After
                 (Year, Month, Day, Hour, Minute, 3, Start_Day, 0)
              and then Before (Month, Day, Hour, 10, End_Day, 23)
            then
               return 180;
            end if;
         end if;
         return 120;
      elsif Family = "asia-tehran" then
         Valid := True;
         if Year in 2008 .. 2022
           and then
             ((Month > 3 and then Month < 9)
              or else (Month = 3 and then Day >= 22)
              or else (Month = 9 and then Day < 22))
         then
            return 270;
         end if;
         return 210;
      else
         declare
            Generated_Valid : Boolean;
            Generated       : constant Integer :=
              I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
                (Zone, Year, Month, Day, Hour, Minute, 0, Generated_Valid);
         begin
            if Generated_Valid then
               Valid := True;
               return Generated / 60;
            end if;
         end;

         return Zone_Offset_Minutes (Zone, Valid);
      end if;
   end Zone_Offset_Minutes_At;

   function Zone_Offset_Seconds_At
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Valid  : out Boolean)
      return Integer
   is
      Runtime_Valid : Boolean;
      Runtime_Offset : constant Integer :=
        I18N.Runtime_Data.Time_Zone_Offset_Seconds_At_UTC
          (Zone, Year, Month, Day, Hour, Minute, Second, Runtime_Valid);
   begin
      if Runtime_Valid then
         Valid := True;
         return Runtime_Offset;
      end if;

      declare
         Generated_Valid : Boolean;
         Generated_Offset : constant Integer :=
           I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
             (Zone, Year, Month, Day, Hour, Minute, Second, Generated_Valid);
      begin
         if Generated_Valid then
            Valid := True;
            return Generated_Offset;
         end if;
      end;

      declare
         Offset_Seconds : Integer;
      begin
         if Parse_Offset_Seconds_Text (Zone, Offset_Seconds) then
            Valid := True;
            return Offset_Seconds;
         end if;
      end;

      declare
         Fallback_Minutes : constant Integer :=
           Zone_Offset_Minutes_At (Zone, Year, Month, Day, Hour, Minute, Valid);
         Fallback_Seconds : constant Integer := Fallback_Minutes * 60;
      begin
         if not Valid
           and then
             (Zone = "Z" or else Zone = "z"
              or else Zone = "UTC" or else Zone = "utc"
              or else Zone = "GMT" or else Zone = "gmt")
         then
            Valid := True;
            return 0;
         end if;

         return Fallback_Seconds;
      end;
   end Zone_Offset_Seconds_At;

   procedure Shift_Date_Time
     (Year         : in out Natural;
      Month        : in out Natural;
      Day          : in out Natural;
      Hour         : in out Natural;
      Minute       : in out Natural;
      Second       : in out Natural;
      Source_Off   : Integer;
      Target_Off   : Integer)
   is
      Total : Integer :=
        Integer (Hour) * 3_600 + Integer (Minute) * 60 + Integer (Second)
        - Source_Off + Target_Off;
   begin
      while Total < 0 loop
         Total := Total + 86_400;
         if Day > 1 then
            Day := Day - 1;
         elsif Month > 1 then
            Month := Month - 1;
            Day := Days_In_Month (Year, Month);
         else
            Year := Year - 1;
            Month := 12;
            Day := 31;
         end if;
      end loop;

      while Total >= 86_400 loop
         Total := Total - 86_400;
         if Day < Days_In_Month (Year, Month) then
            Day := Day + 1;
         elsif Month < 12 then
            Month := Month + 1;
            Day := 1;
         else
            Year := Year + 1;
            Month := 1;
            Day := 1;
         end if;
      end loop;

      Hour := Natural (Total / 3_600);
      Minute := Natural ((Total mod 3_600) / 60);
      Second := Natural (Total mod 60);
   end Shift_Date_Time;

   procedure Parse_Date_Time_Value
     (Value_Text  : String;
      Option      : String;
      Locale      : String;
      Need_Date   : Boolean;
      Need_Time   : Boolean;
      Year        : out Natural;
      Month       : out Natural;
      Day         : out Natural;
      Hour        : out Natural;
      Minute      : out Natural;
      Second      : out Natural;
      Nanosecond  : out Natural;
      Has_Second  : out Boolean;
      Ok          : out Boolean)
   is
      Zone         : constant String := Zone_Name (Option, Locale);
      Zone_Valid   : Boolean;
      Target_Off   : Integer := Zone_Offset_Seconds (Zone, Zone_Valid);
      Source_Off : Integer := Target_Off;
      Time_Start : Positive;
      Time_Len   : Natural;
      After_Time : Natural := 0;
      Fraction_Start : Natural := 0;
      Fraction_End   : Natural := 0;
      Zone_Start     : Natural := 0;
      Is_Instant : Boolean := False;
   begin
      Year := 0;
      Month := 0;
      Day := 0;
      Hour := 0;
      Minute := 0;
      Second := 0;
      Nanosecond := 0;
      Has_Second := False;
      Ok := False;

      if Need_Date
        and then not Need_Time
        and then Value_Text'Length = 10
      then
         for Index in Value_Text'Range loop
            if Index = Value_Text'First + 4
              or else Index = Value_Text'First + 7
            then
               if Value_Text (Index) /= '-' then
                  return;
               end if;
            elsif not Is_Digit (Value_Text (Index)) then
               return;
            end if;
         end loop;

         Year := Four_Digits (Value_Text, Value_Text'First);
         Month := Two_Digits (Value_Text, Value_Text'First + 5);
         Day := Two_Digits (Value_Text, Value_Text'First + 8);
         Ok := Year > 0
           and then Month in 1 .. 12
           and then Day in 1 .. Days_In_Month (Year, Month);
         return;
      end if;

      if Need_Time
        and then not Need_Date
        and then Value_Text'Length >= 5
        and then Value_Text (Value_Text'First + 2) = ':'
      then
         Time_Start := Value_Text'First;
         if Value_Text'Length = 5 then
            Time_Len := 5;
         elsif Value_Text'Length >= 8 then
            Time_Len := 8;
            After_Time := Time_Start + 8;
            if After_Time <= Value_Text'Last then
               if Value_Text (After_Time) /= '.' then
                  return;
               end if;
               Fraction_Start := After_Time + 1;
               Fraction_End := Value_Text'Last;
            end if;
         else
            return;
         end if;
      elsif Value_Text'Length >= 17
        and then Value_Text (Value_Text'First + 4) = '-'
        and then Value_Text (Value_Text'First + 7) = '-'
        and then (Value_Text (Value_Text'First + 10) = 'T'
                  or else Value_Text (Value_Text'First + 10) = ' ')
      then
         for Index in Value_Text'First .. Value_Text'First + 9 loop
            if Index = Value_Text'First + 4
              or else Index = Value_Text'First + 7
            then
               null;
            elsif not Is_Digit (Value_Text (Index)) then
               return;
            end if;
         end loop;

         Year := Four_Digits (Value_Text, Value_Text'First);
         Month := Two_Digits (Value_Text, Value_Text'First + 5);
         Day := Two_Digits (Value_Text, Value_Text'First + 8);
         Time_Start := Value_Text'First + 11;

         if Value_Text (Time_Start + 2) /= ':'
           or else not Is_Digit (Value_Text (Time_Start))
           or else not Is_Digit (Value_Text (Time_Start + 1))
           or else not Is_Digit (Value_Text (Time_Start + 3))
           or else not Is_Digit (Value_Text (Time_Start + 4))
         then
            return;
         end if;

         if Value_Text'Last >= Time_Start + 7
           and then Value_Text (Time_Start + 5) = ':'
         then
            Time_Len := 8;
            After_Time := Time_Start + 8;
         else
            Time_Len := 5;
            After_Time := Time_Start + 5;
         end if;

         if After_Time <= Value_Text'Last
           and then Value_Text (After_Time) = '.'
         then
            if Time_Len /= 8 then
               return;
            end if;

            Fraction_Start := After_Time + 1;
            Zone_Start := Fraction_Start;
            while Zone_Start <= Value_Text'Last
              and then Is_Digit (Value_Text (Zone_Start))
            loop
               Zone_Start := Zone_Start + 1;
            end loop;

            if Zone_Start = Fraction_Start then
               return;
            end if;

            Fraction_End := Zone_Start - 1;
         else
            Zone_Start := After_Time;
         end if;

         if Zone_Start <= Value_Text'Last
           and then Value_Text (Zone_Start) in '+' | '-'
           and then (Zone_Start + 2 = Value_Text'Last
                     or else Zone_Start + 4 = Value_Text'Last
                     or else Zone_Start + 5 = Value_Text'Last
                     or else Zone_Start + 8 = Value_Text'Last)
         then
            declare
               Source_Valid : Boolean;
               Source_Offset_Seconds : Integer;
            begin
               if Parse_Offset_Seconds_Text
                 (Value_Text (Zone_Start .. Value_Text'Last),
                  Source_Offset_Seconds)
               then
                  Source_Off := Source_Offset_Seconds;
                  Source_Valid := True;
               else
                  Source_Valid := False;
               end if;
               if not Source_Valid then
                  return;
               end if;
            end;
         elsif Zone_Start = Value_Text'Last
            and then Value_Text (Zone_Start) = 'Z'
         then
            Source_Off := 0;
         else
            return;
         end if;
         Is_Instant := True;
      else
         return;
      end if;

      if Value_Text (Time_Start + 2) /= ':'
        or else not Is_Digit (Value_Text (Time_Start))
        or else not Is_Digit (Value_Text (Time_Start + 1))
        or else not Is_Digit (Value_Text (Time_Start + 3))
        or else not Is_Digit (Value_Text (Time_Start + 4))
      then
         return;
      end if;

      Hour := Two_Digits (Value_Text, Time_Start);
      Minute := Two_Digits (Value_Text, Time_Start + 3);

      if Time_Len = 8 then
         if Value_Text (Time_Start + 5) /= ':'
           or else not Is_Digit (Value_Text (Time_Start + 6))
           or else not Is_Digit (Value_Text (Time_Start + 7))
         then
            return;
         end if;
         Second := Two_Digits (Value_Text, Time_Start + 6);
         Has_Second := True;
      end if;

      if Fraction_Start /= 0 then
         if Time_Len /= 8
           or else Fraction_End < Fraction_Start
           or else Fraction_End - Fraction_Start + 1 > 9
         then
            return;
         end if;

         for Index in Fraction_Start .. Fraction_End loop
            if not Is_Digit (Value_Text (Index)) then
               return;
            end if;

            Nanosecond :=
              Nanosecond * 10
              + Character'Pos (Value_Text (Index)) - Character'Pos ('0');
         end loop;

         for Pad in 1 .. 9 - (Fraction_End - Fraction_Start + 1) loop
            Nanosecond := Nanosecond * 10;
         end loop;
         Has_Second := True;
      end if;

      if Hour > 23 or else Minute > 59 or else Second > 59 then
         return;
      end if;

      if Year = 0 then
         Year := 2000;
         Month := 1;
         Day := 1;
      elsif Month not in 1 .. 12
        or else Day = 0
        or else Day > Days_In_Month (Year, Month)
      then
         return;
      end if;

      if Is_Instant then
         Shift_Date_Time
           (Year, Month, Day, Hour, Minute, Second, Source_Off, 0);
         Target_Off :=
           I18N.Runtime_Data.Time_Zone_Offset_Seconds_At_UTC
             (Zone, Year, Month, Day, Hour, Minute, Second, Zone_Valid);
         if not Zone_Valid then
            Target_Off :=
              I18N.CLDR_Data.Time_Zone_Offset_Seconds_At_UTC
                (Zone, Year, Month, Day, Hour, Minute, Second, Zone_Valid);
            if not Zone_Valid then
               Target_Off := Zone_Offset_Seconds_At
                 (Zone, Year, Month, Day, Hour, Minute, Second, Zone_Valid);
            end if;
         end if;
         if not Zone_Valid then
            return;
         end if;
         Shift_Date_Time
           (Year, Month, Day, Hour, Minute, Second, 0, Target_Off);
      elsif not Zone_Valid then
         return;
      end if;
      Ok := True;
   exception
      when Constraint_Error =>
         Ok := False;
   end Parse_Date_Time_Value;

   procedure Format_Date_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Year  : Natural;
      Month : Natural;
      Day   : Natural;
      Hour  : Natural;
      Minute : Natural;
      Second : Natural;
      Nanosecond : Natural;
      Has_Second : Boolean;
      Display_Year : Natural;
      Display_Month : Natural;
      Display_Day : Natural;
      Effective_Style : constant String := Normalize_Skeleton_Style_Alias (Style);
      Style_Only : constant String := Style_Name (Effective_Style);
      Parsed : Boolean;
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      Parse_Date_Time_Value
        (Value_Text => Value_Text,
         Option     => Effective_Style,
         Locale     => Locale,
         Need_Date  => True,
         Need_Time  => False,
         Year       => Year,
         Month      => Month,
         Day        => Day,
         Hour       => Hour,
         Minute     => Minute,
         Second     => Second,
         Nanosecond => Nanosecond,
         Has_Second => Has_Second,
         Ok         => Parsed);

      if not Parsed then
         return;
      end if;

      Display_Year := Year;
      Display_Month := Month;
      Display_Day := Day;
      case Calendar_For (Locale) is
         when Julian =>
            Gregorian_To_Julian (Display_Year, Display_Month, Display_Day);
         when Coptic =>
            Gregorian_To_Coptic (Display_Year, Display_Month, Display_Day);
         when Ethiopic =>
            Gregorian_To_Ethiopic (Display_Year, Display_Month, Display_Day);
         when Ethiopic_Amete_Alem =>
            Gregorian_To_Ethiopic_Amete_Alem
              (Display_Year, Display_Month, Display_Day);
         when Islamic_Civil =>
            Gregorian_To_Islamic_Civil
              (Display_Year, Display_Month, Display_Day);
         when Islamic_TBLA =>
            Gregorian_To_Islamic_TBLA
              (Display_Year, Display_Month, Display_Day);
         when Indian =>
            Gregorian_To_Indian (Display_Year, Display_Month, Display_Day);
         when Persian =>
            Gregorian_To_Persian (Display_Year, Display_Month, Display_Day);
         when Hebrew =>
            Gregorian_To_Hebrew (Display_Year, Display_Month, Display_Day);
         when Unsupported_Calendar =>
            return;
         when others =>
            null;
      end case;

      if Is_Skeleton (Style_Only) then
         declare
            Skeleton : constant String :=
              Resolve_Skeleton_Pattern
                (Locale, Skeleton_Text (Style_Only));
         begin
            if Has_Time_Field (Skeleton) or else not Has_Date_Field (Skeleton) then
               return;
            end if;

            Format_Skeleton_Into
              (Skeleton => Skeleton,
               Style    => Effective_Style,
               Locale   => Locale,
               Year     => Display_Year,
               Related_Year => Year,
               Month    => Display_Month,
               Day      => Display_Day,
               Hour     => Hour,
               Minute   => Minute,
               Second   => Second,
               Nanosecond => Nanosecond,
               Target   => Target,
               Last     => Last,
               Overflow => Overflow,
               Ok       => Ok);
            return;
         end;
      end if;

      if Style_Only /= ""
        and then Style_Only /= "short"
        and then Style_Only /= "medium"
        and then Style_Only /= "long"
        and then Style_Only /= "full"
      then
         return;
      end if;

      declare
         Style_Field : constant String :=
           (if Style_Only = "" then "default" else Style_Only);
         Override_Found : Boolean;
         Override_Pattern : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "date_style." & Style_Field, Override_Found);
         Pattern : constant String :=
           (if Override_Found
            then Override_Pattern
            else Date_Style_Pattern (Locale, Style_Only));
      begin
         if Pattern = "" then
            return;
         end if;

         Format_Skeleton_Into
           (Skeleton => Pattern,
            Style    => Effective_Style,
            Locale   => Locale,
            Year     => Display_Year,
            Related_Year => Year,
            Month    => Display_Month,
            Day      => Display_Day,
            Hour     => Hour,
            Minute   => Minute,
            Second   => Second,
            Nanosecond => Nanosecond,
            Target   => Target,
            Last     => Last,
            Overflow => Overflow,
            Ok       => Ok);
      end;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Date_Into;

   procedure Format_Time_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Hour   : Natural;
      Minute : Natural;
      Second : Natural := 0;
      Nanosecond : Natural;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Has_Second : Boolean;
      Effective_Style : constant String := Normalize_Skeleton_Style_Alias (Style);
      Style_Only : constant String := Style_Name (Effective_Style);
      Parsed : Boolean;
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      Parse_Date_Time_Value
        (Value_Text => Value_Text,
         Option     => Effective_Style,
         Locale     => Locale,
         Need_Date  => False,
         Need_Time  => True,
         Year       => Year,
         Month      => Month,
         Day        => Day,
         Hour       => Hour,
         Minute     => Minute,
         Second     => Second,
         Nanosecond => Nanosecond,
         Has_Second => Has_Second,
         Ok         => Parsed);

      if not Parsed then
         return;
      end if;

      if Is_Skeleton (Style_Only) then
         declare
            Skeleton : constant String :=
              Resolve_Skeleton_Pattern
                (Locale, Skeleton_Text (Style_Only));
         begin
            if Has_Date_Field (Skeleton) or else not Has_Time_Field (Skeleton) then
               return;
            end if;

            Format_Skeleton_Into
              (Skeleton => Skeleton,
               Style    => Effective_Style,
               Locale   => Locale,
               Year     => Year,
               Related_Year => Year,
               Month    => Month,
               Day      => Day,
               Hour     => Hour,
               Minute   => Minute,
               Second   => Second,
               Nanosecond => Nanosecond,
               Target   => Target,
               Last     => Last,
               Overflow => Overflow,
               Ok       => Ok);
            return;
         end;
      end if;

      if Style_Only /= ""
        and then Style_Only /= "short"
        and then Style_Only /= "medium"
        and then Style_Only /= "long"
        and then Style_Only /= "full"
      then
         return;
      end if;

      declare
         Style_Field : constant String :=
           (if Style_Only = "" then "default" else Style_Only);
         Override_Found : Boolean;
         Override_Pattern : constant String :=
           I18N.Runtime_Data.Locale_Text
             (Locale, "time_style." & Style_Field, Override_Found);
         Pattern : constant String :=
           (if Override_Found
            then Override_Pattern
            else I18N.CLDR_Data.Time_Style_Pattern
              (Locale, Style_Only, Has_Second));
      begin
         if Pattern = "" then
            return;
         end if;

         Format_Skeleton_Into
           (Skeleton => Pattern,
            Style    => Effective_Style,
           Locale   => Locale,
           Year     => Year,
           Related_Year => Year,
           Month    => Month,
            Day      => Day,
            Hour     => Hour,
            Minute   => Minute,
            Second   => Second,
            Nanosecond => Nanosecond,
            Target   => Target,
            Last     => Last,
            Overflow => Overflow,
            Ok       => Ok);
      end;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Time_Into;

   procedure Format_Date_Time_Into
     (Value_Text : String;
      Locale     : String;
      Style      : String;
      Target     : in out String;
      Last       : out Natural;
      Ok         : out Boolean;
      Overflow   : out Boolean)
   is
      Year       : Natural;
      Month      : Natural;
      Day        : Natural;
      Hour       : Natural;
      Minute     : Natural;
      Second     : Natural;
      Nanosecond : Natural;
      Has_Second : Boolean;
      Parsed     : Boolean;
      Date_Text  : String (1 .. Max_Formatted_Length);
      Time_Text  : String (1 .. Max_Formatted_Length);
      Date_Last  : Natural;
      Time_Last  : Natural;
      Date_Ok    : Boolean;
      Time_Ok    : Boolean;
      Date_Over  : Boolean;
      Time_Over  : Boolean;
      Effective_Style : constant String := Normalize_Skeleton_Style_Alias (Style);
      Display_Year    : Natural;
      Display_Month   : Natural;
      Display_Day     : Natural;
   begin
      Last := 0;
      Ok := False;
      Overflow := False;

      Parse_Date_Time_Value
        (Value_Text => Value_Text,
         Option     => Effective_Style,
         Locale     => Locale,
         Need_Date  => True,
         Need_Time  => True,
         Year       => Year,
         Month      => Month,
         Day        => Day,
         Hour       => Hour,
         Minute     => Minute,
         Second     => Second,
         Nanosecond => Nanosecond,
         Has_Second => Has_Second,
         Ok         => Parsed);

      if not Parsed then
         return;
      end if;

      Display_Year := Year;
      Display_Month := Month;
      Display_Day := Day;
      case Calendar_For (Locale) is
         when Julian =>
            Gregorian_To_Julian (Display_Year, Display_Month, Display_Day);
         when Coptic =>
            Gregorian_To_Coptic (Display_Year, Display_Month, Display_Day);
         when Ethiopic =>
            Gregorian_To_Ethiopic (Display_Year, Display_Month, Display_Day);
         when Ethiopic_Amete_Alem =>
            Gregorian_To_Ethiopic_Amete_Alem
              (Display_Year, Display_Month, Display_Day);
         when Islamic_Civil =>
            Gregorian_To_Islamic_Civil
              (Display_Year, Display_Month, Display_Day);
         when Islamic_TBLA =>
            Gregorian_To_Islamic_TBLA
              (Display_Year, Display_Month, Display_Day);
         when Indian =>
            Gregorian_To_Indian (Display_Year, Display_Month, Display_Day);
         when Persian =>
            Gregorian_To_Persian (Display_Year, Display_Month, Display_Day);
         when Hebrew =>
            Gregorian_To_Hebrew (Display_Year, Display_Month, Display_Day);
         when Unsupported_Calendar =>
            return;
         when others =>
            null;
      end case;

      declare
         Style_Only : constant String := Style_Name (Effective_Style);
      begin
         if Is_Skeleton (Style_Only) then
            declare
               Skeleton : constant String :=
                 Resolve_Skeleton_Pattern
                   (Locale, Skeleton_Text (Style_Only));
            begin
               if not Has_Date_Field (Skeleton) and then not Has_Time_Field (Skeleton) then
                  return;
               end if;

                  Format_Skeleton_Into
                 (Skeleton => Skeleton,
                  Style    => Effective_Style,
                  Locale   => Locale,
                  Year     => Display_Year,
                  Related_Year => Year,
                  Month    => Display_Month,
                  Day      => Display_Day,
                  Hour     => Hour,
                  Minute   => Minute,
                  Second   => Second,
                  Nanosecond => Nanosecond,
                  Target   => Target,
                  Last     => Last,
                  Overflow => Overflow,
                  Ok       => Ok);
               return;
            end;
         end if;
      end;

      Format_Date_Into
        (Value_Text => Value_Text,
         Locale     => Locale,
         Style      => Effective_Style,
         Target     => Date_Text,
         Last       => Date_Last,
         Ok         => Date_Ok,
         Overflow   => Date_Over);
      Format_Time_Into
        (Value_Text => Value_Text,
         Locale     => Locale,
         Style      => Effective_Style,
         Target     => Time_Text,
         Last       => Time_Last,
         Ok         => Time_Ok,
         Overflow   => Time_Over);

      if Date_Over or else Time_Over then
         Overflow := True;
      elsif not Date_Ok or else not Time_Ok then
         return;
      else
         Put (Target, Last, Overflow, Date_Text (1 .. Date_Last));
         declare
            Separator_Found : Boolean;
            Separator       : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, "date_time_style_separator", Separator_Found);
         begin
            Put
              (Target, Last, Overflow,
               (if Separator_Found
                then Separator
                else I18N.CLDR_Data.Date_Time_Style_Separator (Locale)));
         end;
         Put (Target, Last, Overflow, Time_Text (1 .. Time_Last));
         Ok := not Overflow;
      end if;
   exception
      when Constraint_Error =>
         Last := 0;
         Ok := False;
         Overflow := False;
   end Format_Date_Time_Into;

end I18N.Date_Time_Format;
