with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Normalization;  use I18N.Normalization;

--  Self-contained: writes a small normalization table (é, a reordering pair, the
--  fi ligature) and checks NFC/NFD/NFKC/NFKD plus algorithmic Hangul, without
--  the full generated data file.
separate (I18N.Runtime.Tests.Features)
procedure Test_Normalization
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);

   function U8 (Bytes : String) return String is (Bytes);
   function Ch (V : Natural) return Character is (Character'Val (V));

   --  Records sorted by key: canon < ccc < compat < compose.
   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@table|4" & LF
     & "canon" & HT & "E9:65,301" & LF
     & "ccc" & HT & "301 E6 307 E6 323 DC" & LF
     & "compat" & HT & "E9:65,301 FB01:66,69" & LF
     & "compose" & HT & "65,301:E9" & LF;

   --  UTF-8 building blocks.
   E_Acute  : constant String := Ch (16#C3#) & Ch (16#A9#);              --  é
   E_Comb   : constant String := "e" & Ch (16#CC#) & Ch (16#81#);        --  e+U+0301
   Dot_Above : constant String := Ch (16#CC#) & Ch (16#87#);            --  U+0307
   Dot_Below : constant String := Ch (16#CC#) & Ch (16#A3#);            --  U+0323
   FI_Lig   : constant String := Ch (16#EF#) & Ch (16#AC#) & Ch (16#81#); --  U+FB01
   Ga       : constant String := Ch (16#EA#) & Ch (16#B0#) & Ch (16#80#); --  U+AC00
   Ga_Decmp : constant String :=
     Ch (16#E1#) & Ch (16#84#) & Ch (16#80#)     --  U+1100
     & Ch (16#E1#) & Ch (16#85#) & Ch (16#A1#);  --  U+1161

   Dir  : constant String := Ada.Directories.Current_Directory & "/obj";
   Path : constant String := Dir & "/normalization.i18ndata";
   File : Ada.Streams.Stream_IO.File_Type;
   SE   : Ada.Streams.Stream_Element_Array
            (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
begin
   Ada.Directories.Create_Path (Dir);
   for I in Content'Range loop
      SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Content (I)));
   end loop;
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Path);
   Ada.Streams.Stream_IO.Write (File, SE);
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);
   Assert (Available, "the normalization data must load");

   --  Canonical decomposition / composition.
   Assert (Normalize (E_Acute, NFD) = E_Comb, "NFD decomposes é");
   Assert (Normalize (E_Comb, NFC) = E_Acute, "NFC composes e + acute");
   Assert (Normalize (E_Acute, NFC) = E_Acute, "NFC of é is idempotent");

   --  Canonical ordering: dot-above (ccc 230) after dot-below (ccc 220).
   Assert (Normalize ("D" & Dot_Above & Dot_Below, NFD) =
             "D" & Dot_Below & Dot_Above,
           "combining marks reorder by combining class");

   --  Compatibility.
   Assert (Normalize (FI_Lig, NFKD) = U8 ("fi"), "NFKD expands the fi ligature");
   Assert (Normalize (FI_Lig, NFKC) = U8 ("fi"), "NFKC expands the fi ligature");
   Assert (Normalize (FI_Lig, NFC) = FI_Lig, "NFC leaves the fi ligature");

   --  Hangul (algorithmic).
   Assert (Normalize (Ga, NFD) = Ga_Decmp, "NFD decomposes a Hangul syllable");
   Assert (Normalize (Ga_Decmp, NFC) = Ga, "NFC composes Hangul jamo");

   Assert (Is_Normalized (E_Comb, NFD), "Is_Normalized reports NFD");
   Assert (not Is_Normalized (E_Comb, NFC), "e+acute is not NFC");
end Test_Normalization;
