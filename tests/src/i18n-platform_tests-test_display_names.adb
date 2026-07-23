with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Display_Names;
with I18N.Delimiters;
with I18N.Measurement;

--  Self-contained: writes a small display-names data file with known content,
--  points the loader at it, and exercises the full stack (bisection, parent
--  walk, composition, fallbacks) against those known values -- so the test does
--  not depend on the multi-megabyte generated file or the runner's directory.
separate (I18N.Platform_Tests)
procedure Test_Display_Names
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   use type I18N.Measurement.Measurement_System;

   US : constant Character := Character'Val (16#1F#);
   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);

   function R (Key, Value : String) return String is (Key & HT & Value & LF);

   LDQ_DE : constant String :=      --  U+201E
     Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#9E#);

   --  Records must be sorted by key within each section (the loader bisects).
   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@language|6" & LF
     & R ("de" & US & "de", "Deutsch")
     & R ("en" & US & "de", "German")
     & R ("en" & US & "fr", "French")
     & R ("en" & US & "zh", "Chinese")
     & R ("fr" & US & "en", "anglais")
     & "@script|2" & LF
     & R ("en" & US & "Hant", "Traditional")
     & R ("en" & US & "Latn", "Latin")
     & "@territory|4" & LF
     & R ("de" & US & "US", "Vereinigte Staaten")
     & R ("en" & US & "FR", "France")
     & R ("en" & US & "HK", "Hong Kong SAR China")
     & R ("en" & US & "US", "United States")
     & "@locale-pattern|2" & LF
     & R ("en" & US & "localePattern", "{0} ({1})")
     & R ("en" & US & "localeSeparator", "{0}, {1}")
     & "@delimiter|1" & LF
     & R ("de" & US & "quotationStart", LDQ_DE)
     & "@measurement-system|4" & LF
     & R ("001", "metric")
     & R ("DE", "metric")
     & R ("GB", "UK")
     & R ("US", "US")
     & "@measurement-name|1" & LF
     & R ("en" & US & "US", "US");

   Dir  : constant String :=
     Ada.Directories.Compose (Ada.Directories.Current_Directory, "obj");
   Path : constant String :=
     Ada.Directories.Compose (Dir, "display-names", "i18ndata");
   File : Ada.Streams.Stream_IO.File_Type;
begin
   --  Write the raw bytes with Stream_IO: the test crate is compiled -gnatW8,
   --  under which Text_IO would re-encode the non-ASCII values (the "„" mark).
   Ada.Directories.Create_Path (Dir);
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Path);
   declare
      SE : Ada.Streams.Stream_Element_Array
             (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
   begin
      for I in Content'Range loop
         SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (I)));
      end loop;
      Ada.Streams.Stream_IO.Write (File, SE);
   end;
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);

   Assert (I18N.Display_Names.Available,
           "the display-names data file must load");

   --  Direct names in several locales.
   Assert (I18N.Display_Names.Language_Name ("en", "de") = "German",
           "English name of language 'de'");
   Assert (I18N.Display_Names.Language_Name ("de", "de") = "Deutsch",
           "German name of language 'de'");
   Assert (I18N.Display_Names.Language_Name ("fr", "en") = "anglais",
           "French name of language 'en'");
   Assert (I18N.Display_Names.Script_Name ("en", "Latn") = "Latin",
           "English name of script 'Latn'");
   Assert (I18N.Display_Names.Territory_Name ("de", "US") =
             "Vereinigte Staaten",
           "German name of territory 'US'");

   --  Parent-locale fallback: "en-US-x" has no rows, walks to "en".
   Assert (I18N.Display_Names.Territory_Name ("en-US-x", "FR") = "France",
           "territory name falls back through the locale's parents");

   --  Unknown code returns the code itself.
   Assert (I18N.Display_Names.Language_Name ("en", "zzz") = "zzz",
           "unknown language code returns the code");

   --  Full-locale composition using the pattern + separator.
   Assert (I18N.Display_Names.Locale_Display_Name ("en", "zh-Hant-HK") =
             "Chinese (Traditional, Hong Kong SAR China)",
           "composed display name of zh-Hant-HK");
   Assert (I18N.Display_Names.Locale_Display_Name ("en", "de") = "German",
           "composition of a bare language is just its name");

   --  Delimiters (parent walk to 'de').
   Assert (I18N.Delimiters.Quotation_Start ("de-AT") = LDQ_DE,
           "German opening quotation mark via parent fallback");

   --  Measurement systems.
   Assert (I18N.Measurement.System ("US") = I18N.Measurement.US,
           "US uses the US measurement system");
   Assert (I18N.Measurement.System ("DE") = I18N.Measurement.Metric,
           "DE uses the metric system");
   Assert (I18N.Measurement.System ("GB") = I18N.Measurement.UK,
           "GB uses the UK system");
   Assert (I18N.Measurement.System ("ZZ") = I18N.Measurement.Metric,
           "unknown territory falls back to the world default (metric)");
   Assert (I18N.Measurement.System_Name ("en", I18N.Measurement.US) = "US",
           "English name of the US measurement system");
end Test_Display_Names;
