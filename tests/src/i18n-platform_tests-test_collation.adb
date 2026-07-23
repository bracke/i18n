with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Collation;  use I18N.Collation;

--  Self-contained: writes a tiny DUCET-style root (a, b, c) plus one locale
--  tailoring shard (locale "xx" sorts b after c) and checks comparison, sort-key
--  ordering, and that the tailoring overrides the root. The exhaustive UCA
--  conformance is validated separately by the offline harness. ASCII inputs
--  need no normalization data (NFD is identity).
separate (I18N.Platform_Tests)
procedure Test_Collation
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);

   Root : constant String :=
     "I18NDATA|1|16.0.0" & LF
     & "@ce|3" & LF
     & "000061" & HT & "0206.0020.0002" & LF
     & "000062" & HT & "0207.0020.0002" & LF
     & "000063" & HT & "0208.0020.0002" & LF
     & "@meta|4" & LF
     & "cstart" & HT & "" & LF
     & "impl" & HT & "" & LF
     & "uideo" & HT & "" & LF
     & "ver" & HT & "16.0.0" & LF;

   --  Locale "xx": b (000062) takes a primary just after c (0208).
   Xx : constant String :=
     "I18NDATA|1|16.0.0" & LF
     & "@meta|1" & LF
     & "tab" & HT & "000062=0208.01.0020..0002." & LF;

   Dir : constant String := Ada.Directories.Current_Directory & "/obj";

   procedure Write_File (Path, Content : String) is
      F  : Ada.Streams.Stream_IO.File_Type;
      SE : Ada.Streams.Stream_Element_Array
             (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
   begin
      for I in Content'Range loop
         SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (I)));
      end loop;
      Ada.Streams.Stream_IO.Create
        (F, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (F, SE);
      Ada.Streams.Stream_IO.Close (F);
   end Write_File;
begin
   Ada.Directories.Create_Path (Dir);
   Ada.Directories.Create_Path (Dir & "/collation");
   Write_File (Dir & "/collation.i18ndata", Root);
   Write_File (Dir & "/collation/xx.i18ndata", Xx);

   I18N.Data_Store.Configure_Data_Dir (Dir);
   Assert (Available, "the collation data must load");

   --  Root comparison and equality.
   Assert (Compare ("a", "b") < 0, "a sorts before b");
   Assert (Compare ("b", "a") > 0, "b sorts after a");
   Assert (Compare ("a", "a") = 0, "a equals a");
   Assert (Compare ("b", "c") < 0, "b sorts before c in the root");
   Assert (Compare ("ab", "ac") < 0, "ab sorts before ac");

   --  Sort keys reproduce the order via ordinary String comparison.
   Assert (Sort_Key ("a") < Sort_Key ("b"), "sort key of a < sort key of b");

   --  Locale tailoring overrides the root: b now sorts after c.
   Assert (Compare ("b", "c", Locale => "xx") > 0,
           "locale xx sorts b after c");
   Assert (Compare ("a", "b", Locale => "xx") < 0, "a still before b in xx");

   --  Strength: at Primary level, a case/accent-only difference would tie, but
   --  distinct primaries still differ.
   Assert (Compare ("a", "c", Level => Primary) < 0, "primary a < c");
end Test_Collation;
