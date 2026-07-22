with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Transliteration;  use I18N.Transliteration;

--  Self-contained: writes a tiny transform (index + one shard with a couple of
--  context rules) and checks the rule engine. Exhaustive CLDR-catalog coverage
--  is validated separately by the offline testData harness.
separate (I18N.Runtime.Tests.Features)
procedure Test_Transliteration
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);

   Arrow : constant String :=      --  U+2192 RIGHTWARDS ARROW
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#92#);
   Index : constant String :=
     "I18NDATA|1|1" & LF & "@meta|1" & LF & "map" & HT & "Test=Test:F" & LF;
   --  a -> x ; double space collapses ; b before c -> B.
   Shard : constant String :=
     "I18NDATA|1|1" & LF & "@meta|1" & LF
     & "rules" & HT & "a " & Arrow & " x ; ' ' { ' ' " & Arrow & " ; b } c "
     & Arrow & " B ;" & LF;

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
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (F, SE);
      Ada.Streams.Stream_IO.Close (F);
   end Write_File;
begin
   Ada.Directories.Create_Path (Dir & "/transforms");
   Write_File (Dir & "/transforms/_index.i18ndata", Index);
   Write_File (Dir & "/transforms/Test.i18ndata", Shard);
   I18N.Data_Store.Configure_Data_Dir (Dir);
   Assert (Available, "the transform index must load");

   --  Simple substitution a -> x.
   Assert (Transform ("banana", "Test") = "bxnxnx", "a maps to x");
   --  Double space collapses (a -> x, then the second space is removed).
   Assert (Transform ("a  b", "Test") = "x b", "double space collapses");
   --  Context rule: b before c becomes B.
   Assert (Transform ("bc", "Test") = "Bc", "b before c becomes B");
   Assert (Transform ("bd", "Test") = "bd", "b not before c is unchanged");
   --  Unknown transform passes text through unchanged.
   Assert (Transform ("abc", "Nonexistent") = "abc", "unknown transform is a no-op");
end Test_Transliteration;
