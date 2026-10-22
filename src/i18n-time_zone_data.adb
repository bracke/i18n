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
   --  UTC instant as YYYYMMDDhhmmss, then the offset from that instant as a
   --  sign and six digits. Rule from is the instant (same form, or 0 for
   --  none) from which the final rule answers instead.
   Key_Width    : constant := 14;
   Record_Width : constant := Key_Width + 7;

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
   begin
      Valid := False;
      if Zone = ""
        or else Zone = "UTC"
        or else Zone = "Z"
        or else Zone = "GMT"
        or else Zone = "Etc/UTC"
        or else Zone = "Etc/GMT"
      then
         Valid := True;
         return 0;
      end if;

      declare
         Item : constant String := Record_Of (I18N.CLDR_Data.Canonical_Time_Zone (Zone));
         Key  : constant Long_Long_Integer := Key_Of (Year, Month, Day, Hour, Minute, Second);

         --  The fields before the transitions, by their semicolons.
         Semis : array (1 .. 3) of Natural := [others => 0];
         Count : Natural := 0;
      begin
         for Index in Item'Range loop
            exit when Count = Semis'Last;
            if Item (Index) = ';' then
               Count := Count + 1;
               Semis (Count) := Index;
            end if;
         end loop;
         if Count < Semis'Last then
            return 0;
         end if;

         declare
            Initial   : constant Integer := Integer'Value (Item (Item'First .. Semis (1) - 1));
            Rule_From : constant Long_Long_Integer :=
              Long_Long_Integer'Value (Item (Semis (1) + 1 .. Semis (2) - 1));
            Rule      : constant String := Item (Semis (2) + 1 .. Semis (3) - 1);
            First     : constant Positive := Semis (3) + 1;
            Records   : constant Natural := (Item'Last - First + 1) / Record_Width;

            function Record_Key (N : Positive) return Long_Long_Integer is
              (Long_Long_Integer'Value
                 (Item (First + (N - 1) * Record_Width .. First + (N - 1) * Record_Width + Key_Width - 1)));

            function Record_Offset (N : Positive) return Integer is
              (Integer'Value
                 (Item (First + (N - 1) * Record_Width + Key_Width .. First + N * Record_Width - 1)));
         begin
            Valid := True;

            --  Past its recorded transitions a zone follows its final rule.
            if Rule_From /= 0 and then Key >= Rule_From then
               declare
                  Rule_Valid : Boolean;
                  Offset     : constant Integer :=
                    I18N.TZ_Rules.Offset_At
                      (Rule,
                       I18N.TZ_Rules.Epoch_Seconds (Year, Month, Day, Hour, Minute, Second),
                       Rule_Valid);
               begin
                  if Rule_Valid then
                     return Offset;
                  end if;
               end;
            end if;

            --  The last transition at or before the instant; before the first,
            --  the zone's initial offset.
            declare
               Low   : Natural := 1;
               High  : Natural := Records;
               Mid   : Natural;
               Found : Natural := 0;
            begin
               while Low <= High loop
                  Mid := Low + (High - Low) / 2;
                  if Record_Key (Mid) <= Key then
                     Found := Mid;
                     Low := Mid + 1;
                  else
                     High := Mid - 1;
                  end if;
               end loop;
               return (if Found = 0 then Initial else Record_Offset (Found));
            end;
         end;
      end;
   exception
      when Constraint_Error =>
         --  A record this does not read is no zone at all.
         Valid := False;
         return 0;
   end Offset_Seconds_At_UTC;

end I18N.Time_Zone_Data;
