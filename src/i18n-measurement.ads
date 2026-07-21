--  CLDR measurement systems: which system a territory uses, and its localized
--  name. Backed by the "display-names" data file.
package I18N.Measurement is

   type Measurement_System is (Metric, US, UK);

   --  The measurement system a territory uses (default Metric, via CLDR's "001"
   --  world value). Territory is an ISO 3166 / UN M.49 region code, e.g. "US".
   function System (Territory : String) return Measurement_System;

   --  Localized name of a system (System_Name ("en", US) = "US"). Returns a
   --  stable English word when no localized name is installed.
   function System_Name
     (Locale : String;
      System : Measurement_System)
      return String;

end I18N.Measurement;
