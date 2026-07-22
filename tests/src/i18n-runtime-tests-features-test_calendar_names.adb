with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Calendars;  use I18N.Calendars;

--  Self-contained: writes a small calendar shard with known content and checks
--  month/era lookup, width fallback (narrow -> wide), and parent-locale
--  fallback.
separate (I18N.Runtime.Tests.Features)
procedure Test_Calendar_Names
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   US : constant Character := Character'Val (16#1F#);

   function R (Key, Value : String) return String is (Key & HT & Value & LF);
   C : constant String := "testcal";

   --  Sorted by key: "era" < "month".
   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@name|3" & LF
     & R (C & US & "era" & US & "format" & US & "abbreviated" & US & "0",
          "T.E.")
     & R (C & US & "month" & US & "format" & US & "wide" & US & "1",
          "Firstmonth")
     & R (C & US & "month" & US & "format" & US & "wide" & US & "2",
          "Secondmonth");

   Dir  : constant String :=
     Ada.Directories.Current_Directory & "/obj";
   Path : constant String := Dir & "/calendars/xx.i18ndata";
   File : Ada.Streams.Stream_IO.File_Type;
   SE   : Ada.Streams.Stream_Element_Array
            (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
begin
   Ada.Directories.Create_Path (Dir & "/calendars");
   for I in Content'Range loop
      SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Content (I)));
   end loop;
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Path);
   Ada.Streams.Stream_IO.Write (File, SE);
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);

   Assert (Available ("xx"), "the calendar shard must load");
   Assert (Month_Name ("xx", C, 1) = "Firstmonth", "wide month name");
   Assert (Month_Name ("xx", C, 2, Width => Narrow) = "Secondmonth",
           "narrow month falls back to wide");
   Assert (Month_Name ("xx-YY", C, 1) = "Firstmonth",
           "month name falls back through the locale's parents");
   Assert (Era_Name ("xx", C, 0) = "T.E.", "era name (default abbreviated)");
   Assert (Month_Name ("xx", C, 9) = "", "missing month yields empty");
end Test_Calendar_Names;
