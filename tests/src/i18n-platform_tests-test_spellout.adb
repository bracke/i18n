with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Spellout;

--  Self-contained: writes a tiny English-like spellout ruleset and exercises the
--  interpreter -- quotient/remainder substitution, the optional [...], recursion,
--  and the negative rule -- independently of the real RBNF data.
separate (I18N.Platform_Tests)
procedure Test_Spellout
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   US : constant Character := Character'Val (16#1F#);
   RS : constant Character := Character'Val (16#1E#);

   --  Arrow substitutions (U+2190 / U+2192 as UTF-8).
   La : constant String :=
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#90#);
   Ra : constant String :=
     Character'Val (16#E2#) & Character'Val (16#86#) & Character'Val (16#92#);
   Quot : constant String := La & La;   --  <<
   Rmd  : constant String := Ra & Ra;   --  >>

   function Rule (Base, Text : String) return String is (Base & US & Text);

   Rules : constant String :=
     Rule ("-x", "minus " & Rmd)
     & RS & Rule ("0", "zero")
     & RS & Rule ("1", "one")
     & RS & Rule ("2", "two")
     & RS & Rule ("3", "three")
     & RS & Rule ("20", "twenty[-" & Rmd & "]")
     & RS & Rule ("100", Quot & " hundred[ " & Rmd & "]");

   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@ruleset|1" & LF
     & "%spellout-cardinal" & HT & Rules & LF;

   Dir  : constant String := Ada.Directories.Current_Directory & "/obj";
   Path : constant String := Dir & "/rbnf/xx.i18ndata";
   File : Ada.Streams.Stream_IO.File_Type;
   SE   : Ada.Streams.Stream_Element_Array
            (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));

   function Spell (V : Long_Long_Integer) return String is
     (I18N.Spellout.Spell ("xx", V));
begin
   Ada.Directories.Create_Path (Dir & "/rbnf");
   for I in Content'Range loop
      SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Content (I)));
   end loop;
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Path);
   Ada.Streams.Stream_IO.Write (File, SE);
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);

   Assert (I18N.Spellout.Available ("xx"), "the rbnf shard must load");

   Assert (Spell (0) = "zero", "0");
   Assert (Spell (3) = "three", "3");
   Assert (Spell (20) = "twenty", "20 omits the optional remainder");
   Assert (Spell (21) = "twenty-one", "21 includes the optional remainder");
   Assert (Spell (100) = "one hundred", "100 (quotient + omitted remainder)");
   Assert (Spell (123) = "one hundred twenty-three",
           "123 (recursive quotient and remainder)");
   Assert (Spell (-3) = "minus three", "negative via the -x rule");
end Test_Spellout;
