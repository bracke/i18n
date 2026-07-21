with I18N.Data_Store;

package body I18N.Delimiters is

   File : constant String := "display-names";
   Sep  : constant Character := I18N.Data_Store.Key_Separator;

   --  Locale parent-walk lookup in the "delimiter" section, then root.
   function Resolve (Locale : String; Which : String) return String is
      Cand : String := Locale;
      Last : Natural := Cand'Last;
   begin
      for I in Cand'Range loop
         if Cand (I) = '_' then
            Cand (I) := '-';
         end if;
      end loop;

      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                (File, "delimiter", Cand (Cand'First .. Last) & Sep & Which);
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

      return I18N.Data_Store.Lookup (File, "delimiter", "root" & Sep & Which);
   end Resolve;

   function Or_Default (Locale, Which, Default : String) return String is
      Hit : constant String := Resolve (Locale, Which);
   begin
      return (if Hit /= "" then Hit else Default);
   end Or_Default;

   --  English defaults (U+201C/U+201D and U+2018/U+2019) as the final fallback.
   LDQ : constant String := Character'Val (16#E2#) & Character'Val (16#80#)
     & Character'Val (16#9C#);
   RDQ : constant String := Character'Val (16#E2#) & Character'Val (16#80#)
     & Character'Val (16#9D#);
   LSQ : constant String := Character'Val (16#E2#) & Character'Val (16#80#)
     & Character'Val (16#98#);
   RSQ : constant String := Character'Val (16#E2#) & Character'Val (16#80#)
     & Character'Val (16#99#);

   function Quotation_Start (Locale : String) return String is
     (Or_Default (Locale, "quotationStart", LDQ));

   function Quotation_End (Locale : String) return String is
     (Or_Default (Locale, "quotationEnd", RDQ));

   function Alternate_Quotation_Start (Locale : String) return String is
     (Or_Default (Locale, "alternateQuotationStart", LSQ));

   function Alternate_Quotation_End (Locale : String) return String is
     (Or_Default (Locale, "alternateQuotationEnd", RSQ));

end I18N.Delimiters;
