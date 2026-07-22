with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Segmentation;  use I18N.Segmentation;

--  Self-contained: writes a tiny break-property table (just the code points the
--  cases below touch) and checks one boundary of each kind. The exhaustive UCD
--  conformance is validated separately by the offline test harness.
separate (I18N.Runtime.Tests.Features)
procedure Test_Segmentation
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   function Ch (V : Natural) return Character is (Character'Val (V));

   --  Records sorted by key; each value's ranges sorted by low code point.
   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@seg|9" & LF
     & "eaw" & HT & "" & LF
     & "extcn" & HT & "" & LF
     & "extpict" & HT & "" & LF
     & "gc" & HT & "" & LF
     & "gcb" & HT & "A:A:LF D:D:CR 301:301:Extend" & LF
     & "incb" & HT & "" & LF
     & "line" & HT & "20:20:SP 61:64:AL" & LF
     & "sentence" & HT & "20:20:Sp 3F:3F:STerm 41:42:Upper" & LF
     & "word" & HT & "20:20:WSegSpace 61:64:ALetter" & LF;

   E_Acute : constant String := "e" & Ch (16#CC#) & Ch (16#81#);  --  e + U+0301
   CRLF    : constant String := Ch (16#0D#) & Ch (16#0A#);

   Dir  : constant String := Ada.Directories.Current_Directory & "/obj";
   Path : constant String := Dir & "/segmentation.i18ndata";
   File : Ada.Streams.Stream_IO.File_Type;
   SE   : Ada.Streams.Stream_Element_Array
            (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
begin
   Ada.Directories.Create_Path (Dir);
   for I in Content'Range loop
      SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Content (I)));
   end loop;
   Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
   Ada.Streams.Stream_IO.Write (File, SE);
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);
   Assert (Available, "the segmentation data must load");

   --  Grapheme: base + combining mark is one cluster; CR+LF is one cluster.
   Assert (Count (E_Acute, Grapheme) = 1, "e + acute is one grapheme");
   Assert (Count (CRLF, Grapheme) = 1, "CR LF is one grapheme");
   Assert (Count ("ab", Grapheme) = 2, "ab is two graphemes");

   --  Word: letters cohere, the space is its own segment.
   Assert (Count ("ab cd", Word) = 3, "'ab cd' is three word segments");

   --  Sentence: a terminator plus trailing space ends the sentence.
   Assert (Count ("A? B", Sentence) = 2, "'A? B' is two sentences");

   --  Line: no break before a space, a break opportunity after it.
   declare
      B : constant Offset_Array := Boundaries ("a b", Line);
   begin
      Assert (B'Length = 3, "'a b' has one interior line-break opportunity");
      Assert (B (2) = 3, "the break opportunity is before the second word");
   end;
end Test_Segmentation;
