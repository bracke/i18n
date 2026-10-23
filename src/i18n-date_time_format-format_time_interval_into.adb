separate (I18N.Date_Time_Format)
procedure Format_Time_Interval_Into
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

   type Time_Fields is record
      Hour, Minute, Second : Natural := 0;
   end record;

   function Read (Text : String; Item : out Time_Fields) return Boolean is
      Year, Month, Day, Nanosecond : Natural;
      Has_Second, Parsed           : Boolean;
   begin
      Item := (others => 0);
      Parse_Date_Time_Value
        (Value_Text => Text, Option => Effective_Style, Locale => Locale, Need_Date => False, Need_Time => True,
         Year => Year, Month => Month, Day => Day, Hour => Item.Hour, Minute => Item.Minute,
         Second => Item.Second, Nanosecond => Nanosecond, Has_Second => Has_Second, Ok => Parsed);
      return Parsed;
   end Read;

   --  The style's skeleton with "j" as the locale's hour symbol ("hm", "Hm").
   function Skeleton return String is
      Text : String := Skeleton_Text (Style_Only);
   begin
      for C of Text loop
         if C = 'j' then
            C := Preferred_Hour (Locale);
         end if;
      end loop;
      return Text;
   end Skeleton;

   procedure Write (Pattern : String; Item : Time_Fields; Done : out Boolean) is
   begin
      Format_Skeleton_Into
        (Skeleton => Pattern, Style => Effective_Style, Locale => Locale, Year => 2000, Related_Year => 2000,
         Month => 1, Day => 1, Hour => Item.Hour, Minute => Item.Minute, Second => Item.Second, Nanosecond => 0,
         Target => Target, Last => Last, Overflow => Overflow, Ok => Done, Raw_Pattern => True);
   end Write;

   From, To : Time_Fields;
   Done     : Boolean;
begin
   Last := Target'First - 1;
   Ok := False;
   Overflow := False;
   if not Read (From_Text, From) or else not Read (To_Text, To) then
      return;
   end if;
   if From.Hour = To.Hour and then From.Minute = To.Minute then
      Format_Time_Into (From_Text, Locale, Style, Target, Last, Ok, Overflow);
      return;
   end if;

   if Is_Skeleton (Style_Only) then
      declare
         Skel    : constant String := Skeleton;
         Twelve  : constant Boolean := (for some C of Skel => C in 'h' | 'K');
         Field   : constant Character :=
           (if Twelve and then (From.Hour < 12) /= (To.Hour < 12) then 'a'
            elsif From.Hour /= To.Hour then (if Twelve then 'h' else 'H')
            else 'm');
         Found   : Boolean;
         Pattern : constant String :=
           I18N.Locale_Data.Lookup ("date_interval", Locale, Skel & ":" & Field, Found);
         Split   : constant Natural := (if Found then Interval_Second_Half (Pattern) else 0);
      begin
         if Split > Pattern'First
           and then Interval_Writes_Field (Pattern (Pattern'First .. Split - 1), (if Field = 'a' then 'h' else Field))
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

   --  The fallback: both times whole, joined by "{0} – {1}".
   declare
      First_Buffer, Second_Buffer : String (1 .. Max_Formatted_Length);
      First_Last, Second_Last     : Natural;
      First_Ok, Second_Ok         : Boolean;
      Full                        : Boolean;
   begin
      Format_Time_Into (From_Text, Locale, Style, First_Buffer, First_Last, First_Ok, Full);
      Format_Time_Into (To_Text, Locale, Style, Second_Buffer, Second_Last, Second_Ok, Full);
      if not First_Ok or else not Second_Ok then
         return;
      end if;
      Join_Interval
        (Interval_Fallback (Locale),
         First_Buffer (1 .. First_Last), Second_Buffer (1 .. Second_Last), Target, Last, Overflow);
      Ok := not Overflow;
   end;
end Format_Time_Interval_Into;
