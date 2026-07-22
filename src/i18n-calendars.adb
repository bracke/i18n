with I18N.Data_Store;

package body I18N.Calendars is

   Sep : constant Character := I18N.Data_Store.Key_Separator;

   function Norm (Locale : String) return String is
      R : String := Locale;
   begin
      for I in R'Range loop
         if R (I) = '_' then
            R (I) := '-';
         end if;
      end loop;
      return R;
   end Norm;

   function Trim (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      return S (S'First + 1 .. S'Last);   --  drop the leading space
   end Trim;

   function Context_Id (C : Context_Kind) return String is
     (case C is when Format => "format", when Stand_Alone => "stand-alone");

   function Width_Id (W : Width_Kind) return String is
     (case W is
         when Wide => "wide",
         when Abbreviated => "abbreviated",
         when Narrow => "narrow");

   --  Look up Key in a locale's shard, walking the locale's parents.
   function Walk (Locale, Key : String) return String is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                ("calendars/" & Cand (Cand'First .. Last), "name", Key);
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return "";
   end Walk;

   function Key (Calendar, Field, Context, Width, Index : String)
      return String
   is (Calendar & Sep & Field & Sep & Context & Sep & Width & Sep & Index);

   --  Try (Context, Width) then the width and context fallbacks, each with the
   --  locale parent walk.
   function Resolve
     (Locale, Calendar, Field, Index : String;
      Context : Context_Kind;
      Width   : Width_Kind)
      return String
   is
      type Attempt is record
         C : Context_Kind;
         W : Width_Kind;
      end record;
      type Attempt_List is array (Positive range <>) of Attempt;

      --  Width fallback narrow -> abbreviated -> wide; context stand-alone ->
      --  format. Requested first, then the widenings, then format context.
      Attempts : constant Attempt_List :=
        [(Context, Width),
         (Context, Abbreviated),
         (Context, Wide),
         (Format, Width),
         (Format, Abbreviated),
         (Format, Wide)];
   begin
      for A of Attempts loop
         declare
            Hit : constant String :=
              Walk (Locale,
                    Key (Calendar, Field, Context_Id (A.C), Width_Id (A.W),
                         Index));
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
      end loop;
      return "";
   end Resolve;

   function Month_Name
     (Locale, Calendar : String;
      Month            : Positive;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String
   is (Resolve (Locale, Calendar, "month", Trim (Month), Context, Width));

   function Day_Name
     (Locale, Calendar : String;
      Day              : Weekday;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String
   is
      Keys : constant array (Weekday) of String (1 .. 3) :=
        [Sun => "sun", Mon => "mon", Tue => "tue", Wed => "wed",
         Thu => "thu", Fri => "fri", Sat => "sat"];
   begin
      return Resolve (Locale, Calendar, "day", Keys (Day), Context, Width);
   end Day_Name;

   function Quarter_Name
     (Locale, Calendar : String;
      Quarter          : Positive;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String
   is (Resolve (Locale, Calendar, "quarter", Trim (Quarter), Context, Width));

   function Day_Period_Name
     (Locale, Calendar : String;
      Period           : String;
      Context          : Context_Kind := Format;
      Width            : Width_Kind := Wide)
      return String
   is (Resolve (Locale, Calendar, "day-period", Period, Context, Width));

   function Era_Name
     (Locale, Calendar : String;
      Era              : Natural;
      Width            : Width_Kind := Abbreviated)
      return String
   is (Resolve (Locale, Calendar, "era", Trim (Era), Format, Width));

   function Available (Locale : String) return Boolean is
      Cand : constant String := Norm (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         if I18N.Data_Store.Available
              ("calendars/" & Cand (Cand'First .. Last))
         then
            return True;
         end if;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return False;
   end Available;

end I18N.Calendars;
