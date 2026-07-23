with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Person_Names;

--  Self-contained: writes a small person-name shard (patterns + config), then
--  checks field substitution, the -initial modifier, missing-field/literal
--  removal, addressing/informal selection, and order derivation from the name's
--  own locale.
separate (I18N.Platform_Tests)
procedure Test_Person_Names
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   use I18N.Person_Names;

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   US : constant Character := Character'Val (16#1F#);

   function R (Key, Value : String) return String is (Key & HT & Value & LF);

   Content : constant String :=
     "I18NDATA|1|test" & LF
     & "@pattern|4" & LF
     & R ("givenFirst" & US & "long" & US & "referring" & US & "formal",
          "{title} {given} {surname}, {credentials}")
     & R ("givenFirst" & US & "medium" & US & "addressing" & US & "informal",
          "{given-informal}")
     & R ("givenFirst" & US & "medium" & US & "referring" & US & "formal",
          "{given-initial} {surname}")
     & R ("surnameFirst" & US & "medium" & US & "referring" & US & "formal",
          "{surname} {given}")
     & "@config|2" & LF
     & R ("initial", "{0}.")
     & R ("surnameFirst", "ja" & US & "zz");

   Dir  : constant String := Ada.Directories.Current_Directory & "/obj";
   Path : constant String := Dir & "/person-names/xx.i18ndata";
   File : Ada.Streams.Stream_IO.File_Type;
   SE   : Ada.Streams.Stream_Element_Array
            (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));

   N : I18N.Person_Names.Name;
begin
   Ada.Directories.Create_Path (Dir & "/person-names");
   for I in Content'Range loop
      SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
        Ada.Streams.Stream_Element (Character'Pos (Content (I)));
   end loop;
   Ada.Streams.Stream_IO.Create
     (File, Ada.Streams.Stream_IO.Out_File, Path);
   Ada.Streams.Stream_IO.Write (File, SE);
   Ada.Streams.Stream_IO.Close (File);

   I18N.Data_Store.Configure_Data_Dir (Dir);

   Assert (Available ("xx"), "the person-name shard must load");

   Set_Locale (N, "xx");
   Set_Field (N, "title", "Dr.");
   Set_Field (N, "given", "Ann");
   Set_Field (N, "given-informal", "Annie");
   Set_Field (N, "surname", "Lee");

   --  Missing {credentials}: the field and its leading ", " literal drop.
   Assert (Format ("xx", N, Length => Long) = "Dr. Ann Lee",
           "missing credentials drops the field and its literal");

   --  -initial modifier.
   Assert (Format ("xx", N, Length => Medium) = "A. Lee",
           "given-initial resolves to the initial");

   --  Addressing / informal selection.
   Assert (Format ("xx", N, Length => Medium, Usage => Addressing,
                   Formality => Informal) = "Annie",
           "addressing informal uses given-informal");

   --  A missing leading field drops with its trailing literal.
   declare
      M : I18N.Person_Names.Name;
   begin
      Set_Locale (M, "xx");
      Set_Field (M, "given", "Ann");
      Set_Field (M, "surname", "Lee");
      Assert (Format ("xx", M, Length => Long) = "Ann Lee",
              "missing leading title drops with its trailing space");
   end;

   --  Order derivation: a name whose locale is in surnameFirst -> surname first.
   declare
      J : I18N.Person_Names.Name;
   begin
      Set_Locale (J, "ja");
      Set_Field (J, "given", "Ichiro");
      Set_Field (J, "surname", "Suzuki");
      Assert (Format ("xx", J, Length => Medium) = "Suzuki Ichiro",
              "a ja-locale name is ordered surname-first");
   end;
end Test_Person_Names;
