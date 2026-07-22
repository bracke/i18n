with Ada.Directories;
with Ada.Streams.Stream_IO;
with I18N.Data_Store;
with I18N.Emoji;

--  Self-contained: writes small base + derived annotation shards for a made-up
--  locale, points the loader at them, and exercises name/keyword lookup, the
--  keyword splitter, parent-locale fallback, the derived tree, and the '@'
--  emoji key (which collides with the section-header sentinel and so proves the
--  loader's header/record disambiguation).
separate (I18N.Runtime.Tests.Features)
procedure Test_Emoji_Annotations
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   US : constant Character := Character'Val (16#1F#);

   function R (Key, Value : String) return String is (Key & HT & Value & LF);

   Grin : constant String :=      --  U+1F600
     Character'Val (16#F0#) & Character'Val (16#9F#)
     & Character'Val (16#98#) & Character'Val (16#80#);
   Wave_LT : constant String :=   --  U+1F44B U+1F3FB (a derived sequence)
     Character'Val (16#F0#) & Character'Val (16#9F#)
     & Character'Val (16#91#) & Character'Val (16#8B#)
     & Character'Val (16#F0#) & Character'Val (16#9F#)
     & Character'Val (16#8F#) & Character'Val (16#BB#);

   --  "@" (0x40) sorts before the F0.. emoji, so it comes first in each section.
   Base : constant String :=
     "I18NDATA|1|test" & LF
     & "@name|2" & LF
     & R ("@", "at sign")
     & R (Grin, "grinning face")
     & "@keyword|2" & LF
     & R ("@", "at" & US & "sign")
     & R (Grin, "happy" & US & "smile");

   Derived : constant String :=
     "I18NDATA|1|test" & LF
     & "@name|1" & LF
     & R (Wave_LT, "waving hand: light skin tone")
     & "@keyword|1" & LF
     & R (Wave_LT, "hand" & US & "wave");

   Dir : constant String :=
     Ada.Directories.Compose (Ada.Directories.Current_Directory, "obj");

   procedure Write (Rel : String; Content : String) is
      Path : constant String := Dir & "/" & Rel;
      File : Ada.Streams.Stream_IO.File_Type;
      SE   : Ada.Streams.Stream_Element_Array
               (1 .. Ada.Streams.Stream_Element_Offset (Content'Length));
   begin
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      for I in Content'Range loop
         SE (Ada.Streams.Stream_Element_Offset (I - Content'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (I)));
      end loop;
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (File, SE);
      Ada.Streams.Stream_IO.Close (File);
   end Write;
begin
   Write ("annotations/xx.i18ndata", Base);
   Write ("annotations-derived/xx.i18ndata", Derived);
   I18N.Data_Store.Configure_Data_Dir (Dir);

   Assert (I18N.Emoji.Available ("xx"), "the xx annotation shard must load");

   --  Names.
   Assert (I18N.Emoji.Name ("xx", Grin) = "grinning face",
           "emoji display name");
   --  Parent-locale fallback (xx-YY -> xx).
   Assert (I18N.Emoji.Name ("xx-YY", Grin) = "grinning face",
           "emoji name falls back through the locale's parents");

   --  The '@' key collides with the section-header sentinel; the loader must
   --  still treat it as a record.
   Assert (I18N.Emoji.Name ("xx", "@") = "at sign",
           "the '@' emoji key is a record, not a section header");

   --  Keywords + splitter.
   Assert (I18N.Emoji.Keyword_Count ("xx", Grin) = 2, "two keywords");
   Assert (I18N.Emoji.Keyword ("xx", Grin, 1) = "happy", "first keyword");
   Assert (I18N.Emoji.Keyword ("xx", Grin, 2) = "smile", "second keyword");
   Assert (I18N.Emoji.Keyword ("xx", Grin, 3) = "", "out-of-range keyword");

   --  Derived tree.
   Assert (I18N.Emoji.Name ("xx", Wave_LT) = "waving hand: light skin tone",
           "derived sequence resolves from the derived shard");

   --  Missing emoji.
   Assert (I18N.Emoji.Name ("xx", "nope") = "", "unknown emoji yields empty");
end Test_Emoji_Annotations;
