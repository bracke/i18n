with I18N.Data_Store;
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

   function Lookup
     (Section : String;
      Locale  : String;
      Sub     : String;
      Found   : out Boolean)
      return String
   is
      Base : constant String := To_Store_Locale (Locale);
      Cut  : Natural := Base'Last;

      function Try (Loc : String) return String is
        (I18N.Data_Store.Lookup
           (Store_File, Section,
            (if Sub = "" then Loc else Loc & Sep & Sub)));
   begin
      Found := False;
      if not I18N.Data_Store.Available (Store_File) then
         return "";
      end if;

      declare
         Exact : constant String := Try (Base);
      begin
         if Exact /= "" then
            Found := True;
            return Exact;
         end if;
      end;

      while Cut > Base'First loop
         if Base (Cut) = '-' then
            declare
               Parent : constant String := Try (Base (Base'First .. Cut - 1));
            begin
               if Parent /= "" then
                  Found := True;
                  return Parent;
               end if;
            end;
         end if;
         Cut := Cut - 1;
      end loop;

      declare
         Root : constant String := Try ("root");
      begin
         if Root /= "" then
            Found := True;
            return Root;
         end if;
      end;

      return "";
   end Lookup;

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
end I18N.Locale_Data;
