with I18N.Data_Store;

package body I18N.Display_Names is

   File : constant String := "display-names";
   Sep  : constant Character := I18N.Data_Store.Key_Separator;

   --  '_' -> '-'; CLDR keys otherwise keep their canonical casing, so no
   --  case folding here (the stored keys are "zh-Hant", not "zh-hant").
   function Normalize (Locale : String) return String is
      Result : String := Locale;
   begin
      for I in Result'Range loop
         if Result (I) = '_' then
            Result (I) := '-';
         end if;
      end loop;
      return Result;
   end Normalize;

   --  Look up Code in Section, walking the locale's parents then root.
   function Resolve
     (Section : String;
      Locale  : String;
      Code    : String)
      return String
   is
      Cand : constant String := Normalize (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                (File, Section, Cand (Cand'First .. Last) & Sep & Code);
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;

         --  Drop the last subtag.
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

      return I18N.Data_Store.Lookup (File, Section, "root" & Sep & Code);
   end Resolve;

   function Language_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("language", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Language_Name;

   function Script_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("script", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Script_Name;

   function Territory_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("territory", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Territory_Name;

   function Variant_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("variant", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Variant_Name;

   function Key_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("key", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Key_Name;

   function Type_Name (Locale : String; Code : String) return String is
      Hit : constant String := Resolve ("type", Locale, Code);
   begin
      return (if Hit /= "" then Hit else Code);
   end Type_Name;

   --  ------------------------------------------------------------------
   --  Locale display composition
   --  ------------------------------------------------------------------

   --  Replace the first "{0}" and "{1}" in Pattern with A and B.
   function Fill (Pattern : String; A : String; B : String) return String is
      Result : String (1 .. Pattern'Length + A'Length + B'Length);
      Last   : Natural := 0;
      I      : Natural := Pattern'First;

      procedure Emit (S : String) is
      begin
         Result (Last + 1 .. Last + S'Length) := S;
         Last := Last + S'Length;
      end Emit;
   begin
      while I <= Pattern'Last loop
         if I + 2 <= Pattern'Last + 1
           and then I + 1 <= Pattern'Last
           and then Pattern (I) = '{'
           and then Pattern (I + 2) = '}'
           and then Pattern (I + 1) in '0' | '1'
         then
            if Pattern (I + 1) = '0' then
               Emit (A);
            else
               Emit (B);
            end if;
            I := I + 3;
         else
            Last := Last + 1;
            Result (Last) := Pattern (I);
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Last);
   end Fill;

   function Pattern (Locale : String; Which : String; Default : String)
      return String
   is
      Hit : constant String := Resolve ("locale-pattern", Locale, Which);
   begin
      return (if Hit /= "" then Hit else Default);
   end Pattern;

   function Locale_Display_Name
     (Locale    : String;
      Of_Locale : String)
      return String
   is
      Norm : constant String := Normalize (Of_Locale);

      --  Whole-locale language names exist for some ids ("en-GB", "ar-001").
      Whole : constant String := Resolve ("language", Locale, Norm);

      Lang_End : Natural := Norm'Last;

      Sep_Pat  : constant String :=
        Pattern (Locale, "localeSeparator", "{0}, {1}");
      Main_Pat : constant String :=
        Pattern (Locale, "localePattern", "{0} ({1})");
   begin
      if Whole /= "" then
         return Whole;
      end if;

      --  language[-Script][-REGION][-VARIANT...]
      for I in Norm'Range loop
         if Norm (I) = '-' then
            Lang_End := I - 1;
            exit;
         end if;
      end loop;

      declare
         Lang  : constant String := Norm (Norm'First .. Lang_End);
         Base  : constant String := Language_Name (Locale, Lang);
         Quals : String (1 .. Norm'Length * 4);
         Q_Last : Natural := 0;

         procedure Add_Qual (Text : String) is
         begin
            if Text = "" then
               return;
            elsif Q_Last = 0 then
               Quals (1 .. Text'Length) := Text;
               Q_Last := Text'Length;
            else
               declare
                  Merged : constant String := Fill (Sep_Pat, Quals (1 .. Q_Last), Text);
               begin
                  Quals (1 .. Merged'Length) := Merged;
                  Q_Last := Merged'Length;
               end;
            end if;
         end Add_Qual;

         Pos   : Natural := Lang_End + 2;
      begin
         --  Walk remaining subtags, classifying by shape.
         while Pos <= Norm'Last loop
            declare
               Stop : Natural := Pos;
            begin
               while Stop <= Norm'Last and then Norm (Stop) /= '-' loop
                  Stop := Stop + 1;
               end loop;
               declare
                  Sub : constant String := Norm (Pos .. Stop - 1);
               begin
                  if Sub'Length = 4 then                 --  script
                     Add_Qual (Script_Name (Locale, Sub));
                  elsif Sub'Length = 2
                    or else (Sub'Length = 3
                             and then Sub (Sub'First) in '0' .. '9')
                  then                                    --  region (alpha2 / M49)
                     Add_Qual (Territory_Name (Locale, Sub));
                  else                                    --  variant
                     Add_Qual (Variant_Name (Locale, Sub));
                  end if;
               end;
               Pos := Stop + 1;
            end;
         end loop;

         if Q_Last = 0 then
            return Base;
         else
            return Fill (Main_Pat, Base, Quals (1 .. Q_Last));
         end if;
      end;
   end Locale_Display_Name;

   function Available return Boolean is
   begin
      return I18N.Data_Store.Available (File);
   end Available;

end I18N.Display_Names;
