with I18N.Data_Store;

package body I18N.Measurement is

   File : constant String := "display-names";
   Sep  : constant Character := I18N.Data_Store.Key_Separator;

   --  CLDR spells the systems "metric", "US", "UK".
   function Code (System : Measurement_System) return String is
     (case System is
         when Metric => "metric",
         when US     => "US",
         when UK     => "UK");

   function System (Territory : String) return Measurement_System is
      Direct : constant String :=
        I18N.Data_Store.Lookup (File, "measurement-system", Territory);
      Value  : constant String :=
        (if Direct /= "" then Direct
         else I18N.Data_Store.Lookup (File, "measurement-system", "001"));
   begin
      if Value = "US" then
         return US;
      elsif Value = "UK" then
         return UK;
      else
         return Metric;
      end if;
   end System;

   function System_Name
     (Locale : String;
      System : Measurement_System)
      return String
   is
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
                (File, "measurement-name",
                 Cand (Cand'First .. Last) & Sep & Code (System));
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

      declare
         Root : constant String :=
           I18N.Data_Store.Lookup
             (File, "measurement-name", "root" & Sep & Code (System));
      begin
         return (if Root /= "" then Root else Code (System));
      end;
   end System_Name;

end I18N.Measurement;
