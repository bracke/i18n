with Ada.Calendar;
with Ada.Strings.Unbounded;

with I18N.CLDR_Data;
with I18N.Data_Store;
with I18N.TZ_Rules;

package body I18N.Time_Zone_Data is

   --  A zone's record, keyed by its canonical id in section "zone":
   --
   --     <initial offset>;<rule from>;<final rule>;<transitions>
   --
   --  where the transitions are fixed-width, Record_Width characters each: the
   --  UTC instant as YYYYMMDDhhmmss, the offset from that instant as a sign
   --  ('-' or '0') and six digits, and '1' when daylight saving time is in
   --  effect from then on. Rule from is the instant (same form, or 0 for
   --  none) from which the final rule answers instead.
   Key_Width    : constant := 14;
   Record_Width : constant := Key_Width + 8;

   --  The last few zones' records. A program formats its dates in one zone or
   --  a handful, and a store lookup costs about ten times what reading the
   --  record does, so each is fetched once. Filled outside the protected
   --  object: the store's first lookup reads the file.
   Cache_Size : constant := 16;

   type Cached is record
      Zone : Ada.Strings.Unbounded.Unbounded_String;
      Item : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Cached_Array is array (1 .. Cache_Size) of Cached;

   protected Cache is
      function Find (Zone : String; Found : out Boolean) return String;
      procedure Keep (Zone : String; Item : String);
   private
      Entries : Cached_Array;
      Next    : Positive := 1;
   end Cache;

   protected body Cache is
      function Find (Zone : String; Found : out Boolean) return String is
         use type Ada.Strings.Unbounded.Unbounded_String;
      begin
         for E of Entries loop
            if E.Zone = Zone then
               Found := True;
               return Ada.Strings.Unbounded.To_String (E.Item);
            end if;
         end loop;
         Found := False;
         return "";
      end Find;

      procedure Keep (Zone : String; Item : String) is
      begin
         Entries (Next) :=
           (Zone => Ada.Strings.Unbounded.To_Unbounded_String (Zone),
            Item => Ada.Strings.Unbounded.To_Unbounded_String (Item));
         Next := (if Next = Cache_Size then 1 else Next + 1);
      end Keep;
   end Cache;

   function Record_Of (Zone : String) return String is
      Found  : Boolean;
      Cached : constant String := Cache.Find (Zone, Found);
   begin
      if Found then
         return Cached;
      end if;
      declare
         Item : constant String := I18N.Data_Store.Lookup ("tzdb", "zone", Zone);
      begin
         if Item /= "" then
            Cache.Keep (Zone, Item);
         end if;
         return Item;
      end;
   end Record_Of;

   function Key_Of
     (Year, Month, Day, Hour, Minute, Second : Natural)
      return Long_Long_Integer is
     (((((Long_Long_Integer (Year) * 100 + Long_Long_Integer (Month)) * 100
         + Long_Long_Integer (Day)) * 100 + Long_Long_Integer (Hour)) * 100
       + Long_Long_Integer (Minute)) * 100 + Long_Long_Integer (Second));

   function Is_UTC (Zone : String) return Boolean is
     (Zone = "" or else Zone = "UTC" or else Zone = "Z" or else Zone = "GMT"
      or else Zone = "Etc/UTC" or else Zone = "Etc/GMT");

   --  What Zone does at Key, the instant's YYYYMMDDhhmmss: its offset and
   --  whether that is daylight time; or, with Near > 0, whether daylight time
   --  is in effect at any moment within Near seconds either side.
   procedure Read_State
     (Zone     : String;
      Year, Month, Day, Hour, Minute, Second : Natural;
      Near     : Long_Long_Integer;
      Offset   : out Integer;
      Daylight : out Boolean;
      Valid    : out Boolean)
   is
      Item  : constant String := Record_Of (I18N.CLDR_Data.Canonical_Time_Zone (Zone));
      Key   : constant Long_Long_Integer := Key_Of (Year, Month, Day, Hour, Minute, Second);
      Semis : array (1 .. 3) of Natural := [others => 0];
      Count : Natural := 0;
   begin
      Offset := 0;
      Daylight := False;
      Valid := False;
      for Index in Item'Range loop
         exit when Count = Semis'Last;
         if Item (Index) = ';' then
            Count := Count + 1;
            Semis (Count) := Index;
         end if;
      end loop;
      if Count < Semis'Last then
         return;
      end if;

      declare
         Initial   : constant Integer := Integer'Value (Item (Item'First .. Semis (1) - 1));
         Rule_From : constant Long_Long_Integer :=
           Long_Long_Integer'Value (Item (Semis (1) + 1 .. Semis (2) - 1));
         Rule      : constant String := Item (Semis (2) + 1 .. Semis (3) - 1);
         First     : constant Positive := Semis (3) + 1;
         Records   : constant Natural := (Item'Last - First + 1) / Record_Width;
         Instant   : constant Long_Long_Integer :=
           I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second);

         function At_Record (N : Positive) return Natural is (First + (N - 1) * Record_Width);

         function Record_Key (N : Positive) return Long_Long_Integer is
           (Long_Long_Integer'Value (Item (At_Record (N) .. At_Record (N) + Key_Width - 1)));

         function Record_Offset (N : Positive) return Integer is
           (Integer'Value (Item (At_Record (N) + Key_Width .. At_Record (N) + Key_Width + 6)));

         function Record_Daylight (N : Positive) return Boolean is
           (Item (At_Record (N) + Key_Width + 7) = '1');

         function Epoch_Of (Key_Value : Long_Long_Integer) return Long_Long_Integer is
           (I18N.TZ_Rules.Epoch_Seconds
              (Integer (Key_Value / 10_000_000_000),
               Integer ((Key_Value / 100_000_000) mod 100),
               Integer ((Key_Value / 1_000_000) mod 100),
               Integer ((Key_Value / 10_000) mod 100),
               Integer ((Key_Value / 100) mod 100),
               Integer (Key_Value mod 100)));

         --  The last record at or before Key; 0 before the first.
         function Found_At (Wanted : Long_Long_Integer) return Natural is
            Low   : Natural := 1;
            High  : Natural := Records;
            Mid   : Natural;
            Found : Natural := 0;
         begin
            while Low <= High loop
               Mid := Low + (High - Low) / 2;
               if Record_Key (Mid) <= Wanted then
                  Found := Mid;
                  Low := Mid + 1;
               else
                  High := Mid - 1;
               end if;
            end loop;
            return Found;
         end Found_At;

         Rule_From_Instant : constant Long_Long_Integer :=
           (if Rule_From = 0 then Long_Long_Integer'Last else Epoch_Of (Rule_From));
         Rule_Valid : Boolean;
      begin
         Valid := True;

         --  Past its recorded transitions a zone follows its final rule.
         if Instant >= Rule_From_Instant then
            Offset := I18N.TZ_Rules.Offset_At (Rule, Instant, Rule_Valid);
            Daylight := I18N.TZ_Rules.Daylight_At (Rule, Instant, Rule_Valid);
            Valid := Rule_Valid;
         else
            declare
               Found : constant Natural := Found_At (Key);
            begin
               Offset := (if Found = 0 then Initial else Record_Offset (Found));
               Daylight := Found /= 0 and then Record_Daylight (Found);
            end;
         end if;

         if Near > 0 and then Valid and then not Daylight then
            declare
               From : constant Long_Long_Integer := Instant - Near;
               To   : constant Long_Long_Integer := Instant + Near;
            begin
               --  The recorded part of the span: in effect at its start, or
               --  turned on by a record inside it.
               if From < Rule_From_Instant then
                  declare
                     Start_Found : Natural := 0;
                  begin
                     for N in 1 .. Records loop
                        exit when Epoch_Of (Record_Key (N)) > To or else Epoch_Of (Record_Key (N)) >= Rule_From_Instant;
                        if Epoch_Of (Record_Key (N)) <= From then
                           Start_Found := N;
                        elsif Record_Daylight (N) then
                           Daylight := True;
                        end if;
                     end loop;
                     if Start_Found /= 0 and then Record_Daylight (Start_Found) then
                        Daylight := True;
                     end if;
                  end;
               end if;
               --  The ruled part.
               if not Daylight and then To >= Rule_From_Instant and then Rule /= "" then
                  Daylight :=
                    I18N.TZ_Rules.Daylight_Within
                      (Rule, Long_Long_Integer'Max (From, Rule_From_Instant), To, Rule_Valid);
               end if;
            end;
         end if;
      end;
   exception
      when Constraint_Error =>
         --  A record this does not read is no zone at all.
         Offset := 0;
         Daylight := False;
         Valid := False;
   end Read_State;

   function Offset_Seconds_At_UTC
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
      Offset   : Integer;
      Daylight : Boolean;
   begin
      if Is_UTC (Zone) then
         Valid := True;
         return 0;
      end if;
      Read_State (Zone, Year, Month, Day, Hour, Minute, Second, 0, Offset, Daylight, Valid);
      return Offset;
   end Offset_Seconds_At_UTC;

   function Daylight_At_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Valid  : out Boolean)
      return Boolean
   is
      Offset   : Integer;
      Daylight : Boolean;
   begin
      if Is_UTC (Zone) then
         Valid := True;
         return False;
      end if;
      Read_State (Zone, Year, Month, Day, Hour, Minute, Second, 0, Offset, Daylight, Valid);
      pragma Unreferenced (Offset);
      return Daylight;
   end Daylight_At_UTC;

   function Standard_Offset_Seconds
     (Zone  : String;
      Valid : out Boolean)
      return Integer
   is
      Year     : constant Natural := Natural (Ada.Calendar.Year (Ada.Calendar.Clock));
      Offset   : Integer;
      Daylight : Boolean;
   begin
      if Is_UTC (Zone) then
         Valid := True;
         return 0;
      end if;
      Read_State (Zone, Year, 1, 1, 0, 0, 0, 0, Offset, Daylight, Valid);
      if Valid and then Daylight then
         declare
            July_Offset   : Integer;
            July_Daylight : Boolean;
            July_Valid    : Boolean;
         begin
            Read_State (Zone, Year, 7, 1, 0, 0, 0, 0, July_Offset, July_Daylight, July_Valid);
            if July_Valid and then not July_Daylight then
               return July_Offset;
            end if;
         end;
      end if;
      return Offset;
   end Standard_Offset_Seconds;

   function Daylight_Near_UTC
     (Zone   : String;
      Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Days   : Natural)
      return Boolean
   is
      Offset   : Integer;
      Daylight : Boolean;
      Valid    : Boolean;
   begin
      if Is_UTC (Zone) then
         return False;
      end if;
      Read_State
        (Zone, Year, Month, Day, Hour, Minute, Second, Long_Long_Integer (Days) * 86_400,
         Offset, Daylight, Valid);
      pragma Unreferenced (Offset);
      return Valid and then Daylight;
   end Daylight_Near_UTC;

end I18N.Time_Zone_Data;
