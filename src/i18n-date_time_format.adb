with Ada.Characters.Handling;
with Ada.Strings.Unbounded;
with I18N.CLDR_Data;
with I18N.Display_Names;
with I18N.Locales;
with I18N.TZ_Rules;
with I18N.Locale_Data;
with I18N.Time_Zone_Data;
with I18N.Regions;
with I18N.Runtime_Data;
with I18N.Week_Data;

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

   function Preferred_Hour (Locale : String) return Character;

   function Hour_Cycle_For (Locale : String) return Hour_Cycle is
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
            end if;
            --  The region's preferred hour from CLDR's timeData.
            case Preferred_Hour (Locale) is
               when 'h' => return H12;
               when 'K' => return H11;
               when 'k' => return H24;
               when others => return H23;
            end case;
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
         return Weekday_From_Name (I18N.Week_Data.First_Day (Locale));
      end if;
   end First_Day_Of_Week;

   --  Whether week fields ("w", "e") have week data to go by: always, since
   --  CLDR's weekData answers for every locale (the world's where its region
   --  has none); the parameter stays for the callers' shape.
   function Week_Data_Overridden (Locale : String) return Boolean is
      pragma Unreferenced (Locale);
   begin
      return True;
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
         return I18N.Week_Data.Minimal_Days (Locale);
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
      Pattern_Found : Boolean;
      Pattern_Value : constant String :=
        I18N.Locale_Data.Lookup
          ("date_style_pattern", Locale,
           Calendar_Key (Locale) & ":" & Style, Pattern_Found);
      Found : Boolean;
      DMY   : Boolean :=
        I18N.Runtime_Data.Locale_Boolean
          (Locale, "uses_day_month_year", Found);
   begin
      --  An exact per-locale CLDR pattern beats the day-month-year template --
      --  but a runtime uses_day_month_year override (Found is set only from the
      --  runtime store) is explicit and wins over a file-based pattern, which
      --  for a locale absent from the data is merely inherited from root. File
      --  locales report Found=False here and keep the exact-pattern precedence.
      if not Found and then Pattern_Found then
         return Pattern_Value;
      end if;

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

      --  The uses_day_month_year data lists only the locales that do use
      --  day-month-year order; a locale absent from it (en, en-US, ...) uses
      --  month-day-year or year-month-day. Treat an unknown flag as False and
      --  fall through to the non-DMY templates rather than returning an empty
      --  pattern, which would fail the format with Invalid_Argument.
      if not Found then
         DMY := False;
      end if;

      if DMY then
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
         (if Found then Value else I18N.Locale_Data.Locale_Digit (Locale, Digit)));
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
               else "");
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
               else "");
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

   --  Whether the zone metadata (zone_meta, und) has Key.
   function Zone_Meta_Has (Key : String) return Boolean;

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

      --  A zone CLDR names by its own id keeps it, though the tz database has
      --  made it a link (Europe/Busingen is named for Busingen, not Zurich).
      if Zone_Meta_Has ("mz:" & Zone) or else Zone_Meta_Has ("cc:" & Zone) then
         return Zone;
      end if;
      return I18N.Time_Zone_Data.Canonical_Zone (Zone);
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

   function Resolve_Plain_Skeleton_Pattern
     (Locale   : String;
      Skeleton : String)
      return String;

   --  The hour symbol a skeleton's "j" stands for in Locale: its region's
   --  preferred one from CLDR's timeData ("h" in the United States, "H" in
   --  Germany), else the world's.
   function Preferred_Hour (Locale : String) return Character is
      Region : constant Ada.Strings.Unbounded.Unbounded_String :=
        Ada.Strings.Unbounded.To_Unbounded_String (I18N.Regions.Region (Locale));
   begin
      declare
         Found : Boolean;
         Of_Region : constant String :=
           (if Ada.Strings.Unbounded.Length (Region) = 0 then ""
            else I18N.Locale_Data.Lookup
                   ("hour_cycle", "und", Ada.Strings.Unbounded.To_String (Region), Found));
         World : constant String := I18N.Locale_Data.Lookup ("hour_cycle", "und", "001", Found);
      begin
         if Of_Region'Length > 0 then
            return Of_Region (Of_Region'First);
         elsif World'Length > 0 then
            return World (World'First);
         end if;
      end;
      return 'H';
   end Preferred_Hour;

   function Resolve_Skeleton_Pattern
     (Locale   : String;
      Skeleton : String)
      return String
   is
      --  CLDR's available formats are keyed by concrete hour symbols; a "j"
      --  asks for the locale's own.
      function With_Hour (Text : String) return String is
         Result : String := Text;
         Hour   : Character := ' ';
      begin
         for C of Result loop
            if C = 'j' then
               if Hour = ' ' then
                  --  The locale's hour cycle, with its -u-hc- and runtime
                  --  overrides, as a concrete symbol.
                  Hour :=
                    (case Hour_Cycle_For (Locale) is
                        when H11 => 'K', when H12 => 'h', when H23 => 'H', when H24 => 'k');
               end if;
               C := Hour;
            end if;
         end loop;
         return Result;
      end With_Hour;
   begin
      for C of Skeleton loop
         if C = 'j' then
            declare
               Concrete : constant String := With_Hour (Skeleton);
               Pattern  : constant String := Resolve_Plain_Skeleton_Pattern (Locale, Concrete);
            begin
               --  CLDR's format for the concrete skeleton ("hm" -> "h:mm a");
               --  where it has none, the j skeleton itself, whose hour and day
               --  period the formatter fills in.
               if Pattern /= Concrete then
                  return Pattern;
               end if;
               exit;
            end;
         end if;
      end loop;
      return Resolve_Plain_Skeleton_Pattern (Locale, Skeleton);
   end Resolve_Skeleton_Pattern;

   function Resolve_Plain_Skeleton_Pattern
     (Locale   : String;
      Skeleton : String)
      return String
   is
      Override_Found : Boolean;
      Override_Pattern : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale, "available_format." & Skeleton, Override_Found);
      Store_Found : Boolean := False;
      Store_Pattern : constant String :=
        (if Override_Found then ""
         else I18N.Locale_Data.Lookup
                ("available_format", Locale, Skeleton, Store_Found));
      Pattern : constant String :=
        (if Store_Found then Store_Pattern else "");
   begin
      if Override_Found then
         return Override_Pattern;
      else
         return (if Pattern = "" then Skeleton else Pattern);
      end if;
   end Resolve_Plain_Skeleton_Pattern;

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
               else "");
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
               else "");
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
               else "");
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
               else "");
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
         declare
            Wide : constant Boolean := Width = 4 or else Width > 5;
            SF   : Boolean;
            SV   : constant String :=
              I18N.Locale_Data.Lookup
                ("day_period_name", Base_Locale (Locale),
                 (if Wide then "wide" else "abbreviated") & ":" & Period, SF);
         begin
            return
              (if SF then SV
               else "");
         end;
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

   function Time_Zone_Exemplar_Location
     (Locale : String;
      Zone   : String)
      return String;

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
         Store_Found : Boolean;
         Store_Value : constant String :=
           I18N.Locale_Data.Shard_Lookup
             ("zones", "exemplar", Locale, Zone, Store_Found);
      begin
         if Store_Found then
            return Store_Value;
         end if;
      end;

      --  No shard row: the exemplar city defaults to the zone id's last
      --  segment (CLDR's own fallback). A script variant that CLDR routes to
      --  root -- az-Arab, sr-Latn, mn-Mong -- lands here too, correctly, in
      --  place of the compiled table's wrong-script inheritance from the base
      --  language (it wrote Cyrillic "Асмера" under Latin sr-Latn).

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
        ("timezone_location_pattern", Locale));

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

   function GMT_Offset_Prefix (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("gmt_offset_prefix", Locale));

   function Time_Zone_UTC_Designator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("timezone_utc_designator", Locale));

   function Time_Zone_Offset_Separator (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("timezone_offset_separator", Locale));

   function Number_Plus_Sign (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("number_plus_sign", Locale));

   function Number_Minus_Sign (Locale : String) return String is
     (I18N.Locale_Data.Field
        ("number_minus_sign", Locale));

   ---------------------------------------------------------------------
   --  Time zone names, by TR35's rules as ICU applies them. The names come
   --  from the locale's zone shard (lg/ls/ld: long generic, standard,
   --  daylight; sg/ss/sd: short), keyed "zone:<id>" for a zone's own and
   --  "mz:<metazone>" for its metazone's; zone_meta holds each zone's
   --  metazones over time, each metazone's zone per region, and each zone's
   --  country.
   ---------------------------------------------------------------------

   function Zone_Shard (Locale : String; Key : String) return String is
      Found : Boolean;
      Value : constant String :=
        I18N.Locale_Data.Resolved_Shard_Lookup ("zones", "exemplar", Locale, Key, Found);
   begin
      return (if Found then Value else "");
   end Zone_Shard;

   function Zone_Meta (Key : String) return String is
      Found : Boolean;
      Value : constant String := I18N.Locale_Data.Lookup ("zone_meta", "und", Key, Found);
   begin
      return (if Found then Value else "");
   end Zone_Meta;

   --  The id the names are filed under: UTC's own zone for the UTC spellings.
   --  A zone the data knows by its own id keeps it: CLDR keeps zones apart
   --  that the tz database has made links (Europe/Busingen, which the tz
   --  database now sends to Europe/Zurich).
   function Name_Zone (Zone : String) return String is
     (if Zone = "" or else Zone = "UTC" or else Zone = "Z" or else Zone = "Etc/UTC"
      then "Etc/UTC"
      elsif Zone_Meta_Has ("mz:" & Zone) or else Zone_Meta_Has ("cc:" & Zone) then Zone
      else I18N.Time_Zone_Data.Canonical_Zone (Zone));

   function Zone_Meta_Has (Key : String) return Boolean is
      Found : Boolean;
      Value : constant String := I18N.Locale_Data.Lookup ("zone_meta", "und", Key, Found);
      pragma Unreferenced (Value);
   begin
      return Found;
   end Zone_Meta_Has;

   --  The zone's metazone at Instant (UTC seconds since the epoch): zones move
   --  between metazones (London was "British" until 1971).
   function Metazone_At (Zone : String; Instant : Long_Long_Integer) return String is
      Periods : constant String := Zone_Meta ("mz:" & Name_Zone (Zone));
      Start   : Positive := Periods'First;

      --  CLDR's "YYYY-MM-DD hh:mm", UTC.
      function Epoch_Of (Text : String) return Long_Long_Integer is
        (I18N.TZ_Rules.Epoch_Seconds
           (Integer'Value (Text (Text'First .. Text'First + 3)),
            Integer'Value (Text (Text'First + 5 .. Text'First + 6)),
            Integer'Value (Text (Text'First + 8 .. Text'First + 9)),
            Integer'Value (Text (Text'First + 11 .. Text'First + 12)),
            Integer'Value (Text (Text'First + 14 .. Text'First + 15))));
   begin
      while Start <= Periods'Last loop
         declare
            Stop  : Natural := Start;
            First : Natural := 0;
            Second_At : Natural := 0;
         begin
            while Stop <= Periods'Last and then Periods (Stop) /= ';' loop
               if Periods (Stop) = '@' then
                  if First = 0 then
                     First := Stop;
                  else
                     Second_At := Stop;
                  end if;
               end if;
               Stop := Stop + 1;
            end loop;
            if First /= 0 and then Second_At /= 0 then
               declare
                  Name : constant String := Periods (Start .. First - 1);
                  From : constant String := Periods (First + 1 .. Second_At - 1);
                  To   : constant String := Periods (Second_At + 1 .. Stop - 1);
               begin
                  if (From = "" or else Epoch_Of (From) <= Instant)
                    and then (To = "" or else Instant < Epoch_Of (To))
                  then
                     return Name;
                  end if;
               end;
            end if;
            Start := Stop + 1;
         end;
      end loop;
      return "";
   exception
      when Constraint_Error =>
         return "";
   end Metazone_At;

   --  The locale's region, for a metazone's zone there.
   function Region_Of (Locale : String) return String is
      Full  : constant String := I18N.Locales.Maximize (Locale);
      Start : Positive := Full'First;
      Found : Natural := 0;
      Found_Last : Natural := 0;
   begin
      for Index in Full'Range loop
         if Full (Index) = '-' or else Full (Index) = '_' or else Index = Full'Last then
            declare
               Stop : constant Natural := (if Index = Full'Last then Index else Index - 1);
               Part : constant String := Full (Start .. Stop);
            begin
               if Start > Full'First
                 and then ((Part'Length = 2 and then (for all C of Part => C in 'A' .. 'Z' | 'a' .. 'z'))
                           or else (Part'Length = 3 and then (for all C of Part => C in '0' .. '9')))
               then
                  Found := Start;
                  Found_Last := Stop;
               end if;
            end;
            Start := Index + 1;
         end if;
      end loop;
      return (if Found = 0 then "001" else Ada.Characters.Handling.To_Upper (Full (Found .. Found_Last)));
   end Region_Of;

   --  A zone's specific name (TR35 z / zzzz): its own, else its metazone's,
   --  standard or daylight as the zone keeps time at Instant; "" for none.
   function Specific_Zone_Name
     (Locale   : String;
      Zone     : String;
      Long     : Boolean;
      Daylight : Boolean;
      Instant  : Long_Long_Integer)
      return String
   is
      Prefix : constant String :=
        (if Long then (if Daylight then "ld:" else "ls:") else (if Daylight then "sd:" else "ss:"));
      Own    : constant String := Zone_Shard (Locale, Prefix & "zone:" & Name_Zone (Zone));
   begin
      if Own /= "" then
         return Own;
      end if;
      declare
         Metazone : constant String := Metazone_At (Zone, Instant);
      begin
         return (if Metazone = "" then "" else Zone_Shard (Locale, Prefix & "mz:" & Metazone));
      end;
   end Specific_Zone_Name;

   --  A zone's generic location name (TR35 VVVV): "{0} Time" with its
   --  country when it is its country's primary zone, its city otherwise;
   --  "" for a zone with no country (Etc/GMT+5).
   function Generic_Location_Name (Locale : String; Zone : String) return String is
      Country : constant String := Zone_Meta ("cc:" & Name_Zone (Zone));
   begin
      if Country = "" then
         --  A zone with no country (Etc/GMT+5) has no location -- unless a
         --  locale's data gives it an exemplar city outright.
         declare
            Found : Boolean;
            Value : constant String :=
              I18N.Runtime_Data.Locale_Text (Locale, "timezone_exemplar." & Zone, Found);
         begin
            if Found then
               return Apply_Time_Zone_Location_Pattern (Locale, Value);
            end if;
         end;
         return "";
      elsif Country (Country'Last) = '*' then
         return Apply_Time_Zone_Location_Pattern
           (Locale, I18N.Display_Names.Territory_Name (Locale, Country (Country'First .. Country'Last - 1)));
      else
         return Apply_Time_Zone_Location_Pattern (Locale, Time_Zone_Exemplar_Location (Locale, Zone));
      end if;
   end Generic_Location_Name;

   --  A zone's generic name (TR35 v / vvvv), as ICU's TimeZoneGenericNames
   --  gives it at Instant; "" when the location name must stand in.
   function Generic_Zone_Name
     (Locale  : String;
      Zone    : String;
      Long    : Boolean;
      Year, Month, Day, Hour, Minute, Second : Natural)
      return String
   is
      Canonical : constant String := Name_Zone (Zone);
      Generic_Prefix  : constant String := (if Long then "lg:" else "sg:");
      Standard_Prefix : constant String := (if Long then "ls:" else "ss:");
      Instant   : constant Long_Long_Integer :=
        I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second);
      Own       : constant String := Zone_Shard (Locale, Generic_Prefix & "zone:" & Canonical);
   begin
      if Own /= "" then
         return Own;
      end if;

      declare
         Metazone : constant String := Metazone_At (Zone, Instant);
         Metazone_Generic : constant String :=
           (if Metazone = "" then "" else Zone_Shard (Locale, Generic_Prefix & "mz:" & Metazone));
      begin
         if Metazone = "" then
            return "";
         end if;

         --  A zone keeping no daylight time within half a year of the date is
         --  named by its standard time ("India Standard Time").
         if not I18N.Time_Zone_Data.Daylight_Near_UTC
                  (Zone, Year, Month, Day, Hour, Minute, Second, 184)
         then
            declare
               Own_Standard : constant String :=
                 Zone_Shard (Locale, Standard_Prefix & "zone:" & Canonical);
               Standard     : constant String :=
                 (if Own_Standard /= "" then Own_Standard
                  else Zone_Shard (Locale, Standard_Prefix & "mz:" & Metazone));
            begin
               if Standard /= "" and then Standard /= Metazone_Generic then
                  return Standard;
               end if;
            end;
         end if;

         if Metazone_Generic = "" then
            return "";
         end if;

         --  Where the metazone's own zone for the locale's region keeps other
         --  time, the name says which place: "Central Time (Mexico City)".
         declare
            Region  : constant String := Region_Of (Locale);
            Regional : constant String := Zone_Meta ("golden:" & Metazone & ":" & Region);
            Golden  : constant String :=
              (if Regional /= "" then Regional else Zone_Meta ("golden:" & Metazone & ":001"));
         begin
            if Golden /= "" and then Golden /= Canonical then
               declare
                  Own_Valid, Golden_Valid, Own_D_Valid, Golden_D_Valid : Boolean;
                  Own_Offset    : constant Integer :=
                    I18N.Time_Zone_Data.Offset_Seconds_At_UTC
                      (Zone, Year, Month, Day, Hour, Minute, Second, Own_Valid);
                  Golden_Offset : constant Integer :=
                    I18N.Time_Zone_Data.Offset_Seconds_At_UTC
                      (Golden, Year, Month, Day, Hour, Minute, Second, Golden_Valid);
                  Own_Daylight  : constant Boolean :=
                    I18N.Time_Zone_Data.Daylight_At_UTC
                      (Zone, Year, Month, Day, Hour, Minute, Second, Own_D_Valid);
                  Golden_Daylight : constant Boolean :=
                    I18N.Time_Zone_Data.Daylight_At_UTC
                      (Golden, Year, Month, Day, Hour, Minute, Second, Golden_D_Valid);
               begin
                  if Own_Valid and then Golden_Valid
                    and then (Own_Offset /= Golden_Offset or else Own_Daylight /= Golden_Daylight)
                  then
                     declare
                        Country_Text : constant String := Zone_Meta ("cc:" & Canonical);
                        Country : constant String :=
                          (if Country_Text /= "" and then Country_Text (Country_Text'Last) = '*'
                           then Country_Text (Country_Text'First .. Country_Text'Last - 1)
                           else Country_Text);
                        Place   : constant String :=
                          (if Country /= ""
                             and then Zone_Meta ("golden:" & Metazone & ":" & Country) = Canonical
                           then I18N.Display_Names.Territory_Name (Locale, Country)
                           else Time_Zone_Exemplar_Location (Locale, Zone));
                        Pattern_Found : Boolean;
                        Pattern_Text  : constant String :=
                          I18N.Locale_Data.Lookup ("zone_text", Locale, "fallback", Pattern_Found);
                        Pattern : constant String := (if Pattern_Found then Pattern_Text else "{1} ({0})");
                        Result  : Ada.Strings.Unbounded.Unbounded_String;
                        Index   : Positive := Pattern'First;
                     begin
                        while Index <= Pattern'Last loop
                           if Index + 2 <= Pattern'Last and then Pattern (Index .. Index + 2) = "{0}" then
                              Ada.Strings.Unbounded.Append (Result, Place);
                              Index := Index + 3;
                           elsif Index + 2 <= Pattern'Last and then Pattern (Index .. Index + 2) = "{1}" then
                              Ada.Strings.Unbounded.Append (Result, Metazone_Generic);
                              Index := Index + 3;
                           else
                              Ada.Strings.Unbounded.Append (Result, Pattern (Index));
                              Index := Index + 1;
                           end if;
                        end loop;
                        return Ada.Strings.Unbounded.To_String (Result);
                     end;
                  end if;
               end;
            end if;
         end;
         return Metazone_Generic;
      end;
   end Generic_Zone_Name;

   --  zzzz (Specific) and vvvv: a runtime override, else TR35's name, else ""
   --  (the caller writes the localized GMT format).
   function Long_Zone_Name
     (Style    : String;
      Locale   : String;
      Specific : Boolean;
      Year, Month, Day, Hour, Minute, Second : Natural)
      return String
   is
      Zone     : constant String := Zone_Name (Style, Locale);
      D_Valid  : Boolean;
      Daylight : constant Boolean :=
        I18N.Time_Zone_Data.Daylight_At_UTC (Zone, Year, Month, Day, Hour, Minute, Second, D_Valid);
      Found    : Boolean;
      Override : constant String :=
        I18N.Runtime_Data.Locale_Text
          (Locale,
           (if not Specific then "timezone_display."
            elsif Daylight then "timezone_display_daylight."
            else "timezone_display_standard.") & Zone,
           Found);
      --  A zone given one display name, with no standard or daylight one,
      --  goes by it in the specific forms too.
      Plain_Found : Boolean := False;
      Plain       : constant String :=
        (if Specific and then not Found
         then I18N.Runtime_Data.Locale_Text (Locale, "timezone_display." & Zone, Plain_Found)
         else "");
   begin
      if Found then
         return Override;
      elsif Plain_Found then
         return Plain;
      elsif Specific then
         declare
            Name : constant String :=
              Specific_Zone_Name
                (Locale, Zone, True, Daylight,
                 I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second));
            Pattern_Found, City_Found : Boolean;
            Pattern : constant String :=
              (if Name /= "" then ""
               else I18N.Runtime_Data.Locale_Text
                      (Locale,
                       (if Daylight then "timezone_location_pattern_daylight"
                        else "timezone_location_pattern_standard"),
                       Pattern_Found));
            City    : constant String :=
              (if Name /= "" or else not Pattern_Found then ""
               else I18N.Runtime_Data.Locale_Text (Locale, "timezone_exemplar." & Zone, City_Found));
         begin
            --  A zone known only from a locale's runtime data, given a city
            --  and a standard or daylight region format, is named by them.
            if Name = "" and then Pattern_Found and then City_Found then
               for Index in Pattern'First .. Pattern'Last - 2 loop
                  if Pattern (Index .. Index + 2) = "{0}" then
                     return Pattern (Pattern'First .. Index - 1) & City & Pattern (Index + 3 .. Pattern'Last);
                  end if;
               end loop;
            end if;
            return Name;
         end;
      else
         declare
            Name : constant String :=
              Generic_Zone_Name (Locale, Zone, True, Year, Month, Day, Hour, Minute, Second);
         begin
            return (if Name /= "" then Name else Generic_Location_Name (Locale, Zone));
         end;
      end if;
   end Long_Zone_Name;

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
      Ok         : out Boolean;
      --  A CLDR pattern as written, not a generated one: fields side by
      --  side stay side by side ("MMMd" in "y年MMMd日").
      Raw_Pattern : Boolean := False)
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
         if Need_Sep and then not Raw_Pattern then
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

      --  The instant in UTC. Year .. Second are its local time in the zone,
      --  so the zone's offset is taken off again -- and once more when the
      --  offset at the instant first found differs, near a change.
      type UTC_Time is record
         Year, Month, Day, Hour, Minute, Second : Natural := 0;
      end record;

      function To_UTC return UTC_Time is
         Zone  : constant String := Zone_Name (Style, Locale);
         Local : constant Long_Long_Integer :=
           I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second);

         function Offset_At (Instant : Long_Long_Integer) return Long_Long_Integer is
            Y, Mo, D, H, Mi, S : Integer;
            Valid : Boolean;
            Offset : Integer;
         begin
            I18N.TZ_Rules.Civil_Of (Instant, Y, Mo, D, H, Mi, S);
            Offset := Zone_Offset_Seconds_At (Zone, Y, Mo, D, H, Mi, S, Valid);
            return (if Valid then Long_Long_Integer (Offset) else 0);
         end Offset_At;

         Guess  : constant Long_Long_Integer := Local - Offset_At (Local);
         Result : constant Long_Long_Integer := Local - Offset_At (Guess);
         Y, Mo, D, H, Mi, S : Integer;
      begin
         I18N.TZ_Rules.Civil_Of (Result, Y, Mo, D, H, Mi, S);
         return (Natural (Y), Natural (Mo), Natural (D), Natural (H), Natural (Mi), Natural (S));
      exception
         when Constraint_Error =>
            return (Year, Month, Day, Hour, Minute, Second);
      end To_UTC;

      UTC : constant UTC_Time := To_UTC;

      function UTC_Instant return Long_Long_Integer is
        (I18N.TZ_Rules.Epoch_Seconds (UTC.Year, UTC.Month, UTC.Day, UTC.Hour, UTC.Minute, UTC.Second));

      --  z: a runtime override, else TR35's short specific name; "" for the
      --  localized GMT format.
      function Short_Zone_Display return String is
         Zone     : constant String := Zone_Name (Style, Locale);
         D_Valid  : Boolean;
         Daylight : constant Boolean :=
           I18N.Time_Zone_Data.Daylight_At_UTC
             (Zone, UTC.Year, UTC.Month, UTC.Day, UTC.Hour, UTC.Minute, UTC.Second, D_Valid);
         Override_Name : constant String := Time_Zone_Short_Name (Locale, Zone, Daylight);
      begin
         if Override_Name /= "" then
            return Override_Name;
         end if;
         return Specific_Zone_Name (Locale, Zone, False, Daylight, UTC_Instant);
      end Short_Zone_Display;

      --  v: a runtime override, else TR35's short generic name, else the
      --  generic location name; "" for the localized GMT format.
      function Short_Generic_Zone_Display return String is
         Zone          : constant String := Zone_Name (Style, Locale);
         Override_Name : constant String := Time_Zone_Generic_Short_Name (Locale, Zone);
      begin
         if Override_Name /= "" then
            return Override_Name;
         end if;
         declare
            Name : constant String :=
              Generic_Zone_Name
                (Locale, Zone, False, UTC.Year, UTC.Month, UTC.Day, UTC.Hour, UTC.Minute, UTC.Second);
         begin
            return (if Name /= "" then Name else Generic_Location_Name (Locale, Zone));
         end;
      end Short_Generic_Zone_Display;

      procedure Put_Offset
        (Width : Natural;
         Field : Character)
      is
         Valid        : Boolean;
         Offset       : constant Integer :=
           Zone_Offset_Seconds_At
             (Zone_Name (Style, Locale), UTC.Year, UTC.Month, UTC.Day, UTC.Hour, UTC.Minute,
              UTC.Second, Valid);
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
            --  No offset is the locale's zero format ("GMT", "UTC"), short or
            --  long alike.
            if Offset = 0 then
               declare
                  Found : Boolean;
                  Zero  : constant String := I18N.Locale_Data.Lookup ("zone_text", Locale, "gmt_zero", Found);
               begin
                  Put (Target, Last, Overflow, (if Found then Zero else GMT_Offset_Prefix (Locale)));
                  return;
               end;
            end if;
            Put
              (Target, Last, Overflow,
               GMT_Offset_Prefix (Locale));
         end if;

         Abs_Offset := Natural (abs Offset);
         Hours := Abs_Offset / 3_600;
         Minutes := (Abs_Offset mod 3_600) / 60;
         Seconds := Abs_Offset mod 60;
         Use_Seconds :=
           (((Field in 'X' | 'x' and then Width >= 5)
             or else (Field = 'Z' and then Width = 5))
            and then Seconds /= 0);

         --  The localized GMT format takes its signs from the locale's hour
         --  format (U+2212 in French); the ISO formats keep the number signs,
         --  as does a locale whose runtime data gives its own.
         declare
            Overridden : Boolean;
            Unused     : constant String :=
              I18N.Runtime_Data.Locale_Text
                (Locale, (if Offset < 0 then "number_minus_sign" else "number_plus_sign"), Overridden);
            pragma Unreferenced (Unused);
            Found : Boolean := False;
            Sign  : constant String :=
              (if Use_GMT and then not Overridden
               then I18N.Locale_Data.Lookup ("zone_text", Locale, (if Offset < 0 then "minus" else "plus"), Found)
               else "");
         begin
            if Found then
               Put (Target, Last, Overflow, Sign);
            elsif Offset < 0 then
               Put
                 (Target, Last, Overflow,
                  Number_Minus_Sign (Locale));
            else
               Put
                 (Target, Last, Overflow,
                  Number_Plus_Sign (Locale));
            end if;
         end;
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
               --  VVVV: the generic location name ("United Kingdom Time").
               declare
                  Name : constant String := Generic_Location_Name (Locale, Zone);
               begin
                  if Name = "" then
                     Put_Offset (4, 'O');
                  else
                     Put (Target, Last, Overflow, Name);
                  end if;
               end;
            end if;
         else
            --  vvvv: the long generic name, else the location name.
            declare
               Name : constant String :=
                 Long_Zone_Name
                   (Style, Locale, False, UTC.Year, UTC.Month, UTC.Day, UTC.Hour, UTC.Minute, UTC.Second);
            begin
               if Name = "" then
                  Put_Offset (4, 'O');
               else
                  Put (Target, Last, Overflow, Name);
               end if;
            end;
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
                        --  zzzz: the long specific name, else the localized
                        --  GMT format ("GMT+01:00").
                        declare
                           Name : constant String :=
                             Long_Zone_Name
                               (Style, Locale, True, UTC.Year, UTC.Month, UTC.Day,
                                UTC.Hour, UTC.Minute, UTC.Second);
                        begin
                           if Name = "" then
                              Put_Offset (4, 'O');
                           else
                              Put (Target, Last, Overflow, Name);
                           end if;
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

      --  A time of day with no date: the zone's standard time.
      declare
         Offset_Seconds : constant Integer :=
           I18N.Time_Zone_Data.Standard_Offset_Seconds (Zone, Valid);
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

      --  A time of day with no date: the zone's standard time.
      declare
         Offset_Seconds : constant Integer :=
           I18N.Time_Zone_Data.Standard_Offset_Seconds (Zone, Valid);
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

      --  The tz database: the hand-written per-family rules that stood here
      --  applied today's daylight dates to every year.
      declare
         Generated_Valid : Boolean;
         Generated       : constant Integer :=
           I18N.Time_Zone_Data.Offset_Seconds_At_UTC
             (Zone, Year, Month, Day, Hour, Minute, 0, Generated_Valid);
      begin
         if Generated_Valid then
            Valid := True;
            return Generated / 60;
         end if;
      end;

      return Zone_Offset_Minutes (Zone, Valid);
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
           I18N.Time_Zone_Data.Offset_Seconds_At_UTC
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
              I18N.Time_Zone_Data.Offset_Seconds_At_UTC
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

   --  Year, Month and Day (Gregorian) in Locale's calendar; Supported is
   --  False for a calendar this formatter cannot write.
   procedure To_Display_Calendar
     (Locale        : String;
      Display_Year  : in out Natural;
      Display_Month : in out Natural;
      Display_Day   : in out Natural;
      Supported     : out Boolean)
   is
   begin
      Supported := True;
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
            Supported := False;
         when others =>
            null;
      end case;
   end To_Display_Calendar;

   --  Where an interval pattern's second moment starts: its first field
   --  letter of a kind already seen ("d'.–'" | "d'. 'MMM' 'y"); 0 when none
   --  repeats.
   function Interval_Second_Half (Pattern : String) return Natural is
      function Kind (C : Character) return Character is
        (case C is
            when 'L' => 'M',
            when 'c' | 'e' => 'E',
            when 'k' | 'K' => 'h',
            when others => C);
      Seen     : String (1 .. 32) := [others => ' '];
      Count    : Natural := 0;
      Quoted   : Boolean := False;
      Previous : Character := ' ';
   begin
      for I in Pattern'Range loop
         if Pattern (I) = ''' then
            Quoted := not Quoted;
            Previous := ' ';
         elsif not Quoted and then Pattern (I) in 'A' .. 'Z' | 'a' .. 'z' then
            if Pattern (I) /= Previous then
               if (for some J in 1 .. Count => Seen (J) = Kind (Pattern (I))) then
                  return I;
               end if;
               if Count < Seen'Last then
                  Count := Count + 1;
                  Seen (Count) := Kind (Pattern (I));
               end if;
            end if;
            Previous := Pattern (I);
         else
            Previous := ' ';
         end if;
      end loop;
      return 0;
   end Interval_Second_Half;

   --  Whether Half (the first moment's part of an interval pattern) writes
   --  Field, the greatest one that differs: a pattern that does not ("d – d
   --  MMM y" for months apart, CLDR 48's Swahili) cannot tell the moments
   --  apart.
   function Interval_Writes_Field (Half : String; Field : Character) return Boolean is
      Quoted : Boolean := False;
   begin
      for C of Half loop
         if C = ''' then
            Quoted := not Quoted;
         elsif not Quoted
           and then (C = Field or else (Field = 'M' and then C = 'L')
                     or else (Field = 'h' and then C in 'K' | 'k' | 'H'))
         then
            return True;
         end if;
      end loop;
      return False;
   end Interval_Writes_Field;

   --  Whether a runtime override (an LDML appendItem for Time) says how the
   --  locale joins a date and a time; it then wins over CLDR's glue.
   function Runtime_Date_Time_Join (Locale : String) return Boolean is
      Found   : Boolean;
      Ignored : constant String := I18N.Runtime_Data.Locale_Text (Locale, "date_time_field_separator", Found);
      pragma Unreferenced (Ignored);
   begin
      return Found;
   end Runtime_Date_Time_Join;

   --  The locale's pattern joining two whole moments ("{0} – {1}"); "" when
   --  no data says.
   function Interval_Fallback (Locale : String) return String is
      Found : Boolean;
      Text  : constant String := I18N.Locale_Data.Lookup ("date_interval", Locale, "fallback", Found);
   begin
      return (if Found then Text else "");
   end Interval_Fallback;

   --  Pattern ("{0} – {1}") with {0} and {1} as First and Second; a missing
   --  pattern reads as CLDR root's.
   procedure Join_Interval
     (Pattern  : String;
      First    : String;
      Second   : String;
      Target   : in out String;
      Last     : in out Natural;
      Overflow : in out Boolean)
   is
      En_Dash : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#93#)];
      Joining : constant String := (if Pattern /= "" then Pattern else "{0} " & En_Dash & " {1}");
      I       : Positive := Joining'First;

      procedure Put_Text (Text : String) is
      begin
         if Last + Text'Length > Target'Last then
            Overflow := True;
         else
            Target (Last + 1 .. Last + Text'Length) := Text;
            Last := Last + Text'Length;
         end if;
      end Put_Text;
   begin
      while I <= Joining'Last and then not Overflow loop
         if I + 2 <= Joining'Last and then Joining (I) = '{' and then Joining (I + 2) = '}'
           and then Joining (I + 1) in '0' | '1'
         then
            Put_Text ((if Joining (I + 1) = '0' then First else Second));
            I := I + 3;
         else
            Put_Text ([1 => Joining (I)]);
            I := I + 1;
         end if;
      end loop;
   end Join_Interval;

   --  A time interval ("14:00:00/15:30:00") in Locale and Style: CLDR's
   --  interval pattern for the style's skeleton ("j" as the locale's hour
   --  cycle) and the greatest field that differs ("14:00–15:30", "2:00 –
   --  3:30 PM"), else the locale's fallback joining the two times whole.
   procedure Format_Time_Interval_Into
     (From_Text : String;
      To_Text   : String;
      Locale    : String;
      Style     : String;
      Target    : in out String;
      Last      : out Natural;
      Ok        : out Boolean;
      Overflow  : out Boolean) is separate;

   --  A date-time interval: on one day, the day as the style writes it and
   --  the time interval in place of its time ("9. Okt. 2026, 14:00–15:30");
   --  on two days, the fallback joining both whole.
   procedure Format_Date_Time_Interval_Into
     (From_Text : String;
      To_Text   : String;
      Locale    : String;
      Style     : String;
      Target    : in out String;
      Last      : out Natural;
      Ok        : out Boolean;
      Overflow  : out Boolean) is separate;

   --  A date interval ("2026-10-09/2026-10-15") in Locale and Style: CLDR's
   --  interval pattern for the style's skeleton and the greatest field that
   --  differs ("9.–15. Okt. 2026"), else the locale's fallback joining the
   --  two dates whole ("09.10.26 – 15.10.26").
   procedure Format_Date_Interval_Into
     (From_Text : String;
      To_Text   : String;
      Locale    : String;
      Style     : String;
      Target    : in out String;
      Last      : out Natural;
      Ok        : out Boolean;
      Overflow  : out Boolean) is separate;

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

      --  An ISO 8601 interval: two dates joined by "/".
      for Slash in Value_Text'First + 1 .. Value_Text'Last - 1 loop
         if Value_Text (Slash) = '/' then
            Format_Date_Interval_Into
              (Value_Text (Value_Text'First .. Slash - 1), Value_Text (Slash + 1 .. Value_Text'Last),
               Locale, Style, Target, Last, Ok, Overflow);
            return;
         end if;
      end loop;

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
      declare
         Supported : Boolean;
      begin
         To_Display_Calendar (Locale, Display_Year, Display_Month, Display_Day, Supported);
         if not Supported then
            return;
         end if;
      end;

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

      --  An ISO 8601 interval: two moments joined by "/".
      for Slash in Value_Text'First + 1 .. Value_Text'Last - 1 loop
         if Value_Text (Slash) = '/' then
            Format_Time_Interval_Into
              (Value_Text (Value_Text'First .. Slash - 1), Value_Text (Slash + 1 .. Value_Text'Last),
               Locale, Style, Target, Last, Ok, Overflow);
            return;
         end if;
      end loop;

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
         --  CLDR's time style for the locale; a medium (or default) time of
         --  a value without seconds is written as the short one.
         CLDR_Style : constant String :=
           (if Style_Only = "" or else Style_Only = "medium"
            then (if Has_Second then "medium" else "short")
            else Style_Only);
         CLDR_Found : Boolean;
         CLDR_Pattern : constant String :=
           I18N.Locale_Data.Lookup ("time_style_pattern", Locale, CLDR_Style, CLDR_Found);
         Pattern : constant String :=
           (if Override_Found then Override_Pattern
            elsif CLDR_Found then CLDR_Pattern
            else "HH':'mm");
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

      --  An ISO 8601 interval: two moments joined by "/".
      for Slash in Value_Text'First + 1 .. Value_Text'Last - 1 loop
         if Value_Text (Slash) = '/' then
            Format_Date_Time_Interval_Into
              (Value_Text (Value_Text'First .. Slash - 1), Value_Text (Slash + 1 .. Value_Text'Last),
               Locale, Style, Target, Last, Ok, Overflow);
            return;
         end if;
      end loop;

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
            --  A skeleton with a date and a time ("yMMMdjm"): each resolved on
            --  its own and joined as the locale joins them for the date's
            --  width ("{1}, {0}"), as ICU does -- the field-by-field resolution
            --  below has no separator between them.
            declare
               Requested  : constant String := Skeleton_Text (Style_Only);
               Date_Part  : String (1 .. Requested'Length);
               Time_Part  : String (1 .. Requested'Length);
               Date_Count : Natural := 0;
               Time_Count : Natural := 0;
               Has_Day    : Boolean := False;
               Months     : Natural := 0;
            begin
               for C of Requested loop
                  if C in 'h' | 'H' | 'k' | 'K' | 'j' | 'J' | 'C' | 'm' | 's' | 'S' | 'a' | 'b' | 'B' | 'A'
                    | 'z' | 'Z' | 'O' | 'v' | 'V' | 'X' | 'x'
                  then
                     Time_Count := Time_Count + 1;
                     Time_Part (Time_Count) := C;
                  else
                     Date_Count := Date_Count + 1;
                     Date_Part (Date_Count) := C;
                     Has_Day := Has_Day or else C in 'y' | 'M' | 'L' | 'd' | 'D' | 'Q' | 'q' | 'u' | 'U' | 'G' | 'w';
                     Months := Months + (if C in 'M' | 'L' then 1 else 0);
                  end if;
               end loop;
               --  Not for a skeleton with quoted literals: it spells its own
               --  layout ("yyyy-MM-dd'T'HH:mm").
               if Has_Day and then Time_Count > 0 and then (for all C of Requested => C /= ''')
                 and then not Runtime_Date_Time_Join (Locale)
               then
                  declare
                     Width : constant String :=
                       (if Months >= 4 and then (for some C of Requested => C in 'E' | 'c' | 'e') then "full"
                        elsif Months >= 4 then "long"
                        elsif Months = 3 then "medium" else "short");
                     Found : Boolean;
                     Glue  : constant String := I18N.Locale_Data.Lookup ("date_time_glue", Locale, Width, Found);
                     Day_Text, Clock_Text : String (1 .. Max_Formatted_Length);
                     Day_Last, Clock_Last : Natural := 0;
                     Day_Ok, Clock_Ok     : Boolean;
                     Full                 : Boolean := False;
                  begin
                     Format_Skeleton_Into
                       (Skeleton => Resolve_Skeleton_Pattern (Locale, Date_Part (1 .. Date_Count)),
                        Style => Effective_Style, Locale => Locale, Year => Display_Year, Related_Year => Year,
                        Month => Display_Month, Day => Display_Day, Hour => Hour, Minute => Minute,
                        Second => Second, Nanosecond => Nanosecond, Target => Day_Text, Last => Day_Last,
                        Overflow => Full, Ok => Day_Ok);
                     Format_Skeleton_Into
                       (Skeleton => Resolve_Skeleton_Pattern (Locale, Time_Part (1 .. Time_Count)),
                        Style => Effective_Style, Locale => Locale, Year => Display_Year, Related_Year => Year,
                        Month => Display_Month, Day => Display_Day, Hour => Hour, Minute => Minute,
                        Second => Second, Nanosecond => Nanosecond, Target => Clock_Text, Last => Clock_Last,
                        Overflow => Full, Ok => Clock_Ok);
                     if Day_Ok and then Clock_Ok and then not Full then
                        Join_Interval
                          ((if Found and then Glue /= "" then Glue else "{1}, {0}"), Clock_Text (1 .. Clock_Last),
                           Day_Text (1 .. Day_Last), Target, Last, Overflow);
                        Ok := not Overflow;
                     end if;
                     return;
                  end;
               end if;
            end;
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

   function Short_Zone_Name
     (Locale : String;
      Zone   : String;
      Year, Month, Day, Hour, Minute, Second : Natural)
      return String
   is
      Named    : constant String := Canonical_Zone_Name (Zone);
      Valid    : Boolean;
      Daylight : constant Boolean :=
        I18N.Time_Zone_Data.Daylight_At_UTC (Named, Year, Month, Day, Hour, Minute, Second, Valid);
   begin
      return Specific_Zone_Name
        (Locale, Named, False, Valid and then Daylight,
         I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second));
   end Short_Zone_Name;

end I18N.Date_Time_Format;
