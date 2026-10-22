with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with I18N.Data_Store;
with I18N.Parent_Locales;
with I18N.Runtime_Data;

package body I18N.Locale_Data is
   Store_File : constant String := "formats";
   Sep        : constant Character := I18N.Data_Store.Key_Separator;

   function To_Store_Locale (Locale : String) return String is
      Result : String := Locale;
   begin
      for Index in Result'Range loop
         if Result (Index) in 'A' .. 'Z' then
            Result (Index) :=
              Character'Val (Character'Pos (Result (Index)) + 32);
         elsif Result (Index) = '_' then
            Result (Index) := '-';
         end if;
      end loop;
      return Result;
   end To_Store_Locale;

   --  The next locale up the CLDR fallback chain: the supplemental parentLocale
   --  override when there is one (en-AU -> en-001, az-arab -> root), otherwise
   --  drop the last subtag, otherwise root. Returns "" once root is reached, so
   --  callers can bisect exactly the CLDR-defined chain rather than the naive
   --  "strip a subtag at a time" walk, which is wrong for region and
   --  non-likely-script variants.
   function Next_Locale (Loc : String) return String is
      Override : constant String := I18N.Parent_Locales.Parent (Loc);
   begin
      if Override /= "" then
         return Override;
      elsif Loc = "root" then
         return "";
      end if;

      for Index in reverse Loc'Range loop
         if Loc (Index) = '-' then
            return Loc (Loc'First .. Index - 1);
         end if;
      end loop;

      return "root";
   end Next_Locale;

   function Lookup
     (Section : String;
      Locale  : String;
      Sub     : String;
      Found   : out Boolean)
      return String
   is
      function Try (Loc : String) return String is
        (I18N.Data_Store.Lookup
           (Store_File, Section,
            (if Sub = "" then Loc else Loc & Sep & Sub)));

      Cur : Unbounded_String :=
        To_Unbounded_String (To_Store_Locale (Locale));
   begin
      Found := False;
      if not I18N.Data_Store.Available (Store_File) then
         return "";
      end if;

      loop
         declare
            Loc   : constant String := To_String (Cur);
            Value : constant String := Try (Loc);
         begin
            if Value /= "" then
               Found := True;
               return Value;
            end if;
            exit when Loc = "root";

            declare
               Up : constant String := Next_Locale (Loc);
            begin
               exit when Up = "";
               Cur := To_Unbounded_String (Up);
            end;
         end;
      end loop;

      --  The parentLocale walk terminates at root, but CLDR keeps the base
      --  data under the und key (root and und name the same locale). Try it
      --  explicitly so the minimized sections -- which store only the rows a
      --  locale overrides -- resolve their inherited base instead of missing.
      declare
         Value : constant String := Try ("und");
      begin
         if Value /= "" then
            Found := True;
            return Value;
         end if;
      end;

      return "";
   end Lookup;

   function Lookup_Exact
     (Section : String; Locale : String; Found : out Boolean) return String
   is
      Value : constant String :=
        (if I18N.Data_Store.Available (Store_File)
         then I18N.Data_Store.Lookup
                (Store_File, Section, To_Store_Locale (Locale))
         else "");
   begin
      Found := Value /= "";
      return Value;
   end Lookup_Exact;

   function Field
     (Section : String;
      Locale  : String)
      return String
   is
      No_Value      : constant String :=
        Character'Val (16#E2#) & Character'Val (16#88#) & Character'Val (16#85#);
      Found         : Boolean;
      Runtime_Value : constant String :=
        I18N.Runtime_Data.Locale_Text (Locale, Section, Found);
   begin
      if Found then
         return Runtime_Value;
      end if;

      declare
         From_Store : constant String := Lookup (Section, Locale, "", Found);
      begin
         return (if From_Store = No_Value & No_Value & No_Value then "" else From_Store);
      end;
   end Field;

   function Numbering_Digit
     (System : String;
      Digit  : Character;
      Found  : out Boolean)
      return String
   is
   begin
      if System = "latn" or else Digit not in '0' .. '9' then
         Found := True;
         return [1 => Digit];
      end if;
      return Lookup ("numbering_digits", "und", System & ":" & Digit, Found);
   end Numbering_Digit;

   function Locale_Digit (Locale : String; Digit : Character) return String is
      --  The system a -u-nu- or @numbers= override names: up to the next
      --  subtag, or keyword.
      function Named_System return String is
         function After (Marker : String; Stop : Character) return String is
         begin
            for Index in Locale'First .. Locale'Last - Marker'Length + 1 loop
               if Locale (Index .. Index + Marker'Length - 1) = Marker then
                  declare
                     First : constant Positive := Index + Marker'Length;
                     Last  : Natural := First - 1;
                  begin
                     while Last < Locale'Last and then Locale (Last + 1) /= Stop loop
                        Last := Last + 1;
                     end loop;
                     return Locale (First .. Last);
                  end;
               end if;
            end loop;
            return "";
         end After;

         From_Extension : constant String := After ("-u-nu-", '-');
      begin
         return (if From_Extension /= "" then From_Extension else After ("@numbers=", ';'));
      end Named_System;

      System : constant String := Named_System;
      Found  : Boolean;
   begin
      if Digit not in '0' .. '9' then
         return [1 => Digit];
      elsif System /= "" then
         --  A system is chosen by name, not inherited: ar-u-nu-latn is Latin.
         declare
            Value : constant String := Numbering_Digit (System, Digit, Found);
         begin
            return (if Found then Value else [1 => Digit]);
         end;
      end if;
      declare
         Value : constant String := Lookup ("digit_text", Locale, [1 => Digit], Found);
      begin
         return (if Found then Value else [1 => Digit]);
      end;
   end Locale_Digit;

   function Plural_Family (Section : String; Locale : String) return String is
      Found : Boolean;
      Exact : constant String := Lookup_Exact (Section, Locale, Found);
      Last  : Natural := Locale'Last;
   begin
      if Found then
         return Exact;
      end if;
      for Index in Locale'Range loop
         if Locale (Index) in '-' | '_' then
            Last := Index - 1;
            exit;
         end if;
      end loop;
      declare
         Of_Language : constant String := Lookup_Exact (Section, Locale (Locale'First .. Last), Found);
      begin
         return (if Found then Of_Language else "other-only");
      end;
   end Plural_Family;

   function Language_Member
     (Section : String; Locale : String; Found : out Boolean) return String
   is
      Lang : constant String :=
        (if Locale'Length >= 2
         then To_Store_Locale (Locale (Locale'First .. Locale'First + 1))
         else "");
   begin
      Found := False;
      if Lang = "" or else not I18N.Data_Store.Available (Store_File) then
         return "";
      end if;

      declare
         Value : constant String :=
           I18N.Data_Store.Lookup (Store_File, Section, Lang);
      begin
         if Value /= "" then
            Found := True;
            return Value;
         end if;
      end;

      return "";
   end Language_Member;

   function Shard_Lookup
     (Dir     : String;
      Section : String;
      Locale  : String;
      Key     : String;
      Found   : out Boolean)
      return String
   is
      function Try (Loc : String) return String is
        (if I18N.Data_Store.Available (Dir & "/" & Loc)
         then I18N.Data_Store.Lookup (Dir & "/" & Loc, Section, Key)
         else "");

      Cur : Unbounded_String :=
        To_Unbounded_String (To_Store_Locale (Locale));
   begin
      Found := False;

      loop
         declare
            Loc   : constant String := To_String (Cur);
            Value : constant String := Try (Loc);
         begin
            if Value /= "" then
               Found := True;
               return Value;
            end if;
            exit when Loc = "root";

            declare
               Up : constant String := Next_Locale (Loc);
            begin
               exit when Up = "";
               Cur := To_Unbounded_String (Up);
            end;
         end;
      end loop;

      return "";
   end Shard_Lookup;

   function Resolved_Shard_Lookup
     (Dir     : String;
      Section : String;
      Locale  : String;
      Key     : String;
      Found   : out Boolean)
      return String
   is
      Cur : Unbounded_String := To_Unbounded_String (To_Store_Locale (Locale));
   begin
      Found := False;
      loop
         declare
            Loc : constant String := To_String (Cur);
         begin
            if I18N.Data_Store.Available (Dir & "/" & Loc) then
               declare
                  Value : constant String := I18N.Data_Store.Lookup (Dir & "/" & Loc, Section, Key);
               begin
                  Found := Value /= "";
                  return Value;
               end;
            end if;
            exit when Loc = "root";
            declare
               Up : constant String := Next_Locale (Loc);
            begin
               exit when Up = "";
               Cur := To_Unbounded_String (Up);
            end;
         end;
      end loop;
      return "";
   end Resolved_Shard_Lookup;
end I18N.Locale_Data;
