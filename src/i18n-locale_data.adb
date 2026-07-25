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
     (Section  : String;
      Locale   : String;
      Compiled : not null access function (L : String) return String)
      return String
   is
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
         if Found then
            return From_Store;
         end if;
      end;

      return Compiled (Locale);
   end Field;

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
end I18N.Locale_Data;
