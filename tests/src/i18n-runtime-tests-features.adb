with Ada.Strings.Fixed;
with AUnit.Assertions;

with Project_Tools.Files;

with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Plurals;
with I18N.Result; use I18N.Result;

package body I18N.Runtime.Tests.Features is

   use AUnit.Assertions;
   use type I18N.Locales.Text_Direction;
   use type I18N.Locales.Collation_Order;

   ---------------------------------------------------------------------------
   --  Small helpers.
   ---------------------------------------------------------------------------

   function U (Code : Natural) return String is
   begin
      if Code <= 16#7F# then
         return [1 => Character'Val (Code)];
      elsif Code <= 16#7FF# then
         return
           [1 => Character'Val (16#C0# + Code / 64),
            2 => Character'Val (16#80# + Code mod 64)];
      elsif Code <= 16#FFFF# then
         return
           [1 => Character'Val (16#E0# + Code / 4096),
            2 => Character'Val (16#80# + (Code / 64) mod 64),
            3 => Character'Val (16#80# + Code mod 64)];
      else
         return
           [1 => Character'Val (16#F0# + Code / 262144),
            2 => Character'Val (16#80# + (Code / 4096) mod 64),
            3 => Character'Val (16#80# + (Code / 64) mod 64),
            4 => Character'Val (16#80# + Code mod 64)];
      end if;
   end U;

   type Codepoint_Array is array (Positive range <>) of Natural;

   function UTF8 (Codes : Codepoint_Array) return String is
   begin
      if Codes'Length = 0 then
         return "";
      elsif Codes'Length = 1 then
         return U (Codes (Codes'First));
      else
         return
           U (Codes (Codes'First))
           & UTF8 (Codes (Codes'First + 1 .. Codes'Last));
      end if;
   end UTF8;

   function Rendered
     (Item   : I18N.Runtime.Instance;
      Locale : String;
      Key    : String;
      Args   : I18N.Arguments.Arguments)
      return String
   is
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Item, Locale, Key, Args);
   begin
      if Result.Status = I18N.Result.Success then
         return I18N.Result.Output_Text (Result.Text);
      else
         return "<" & I18N.Result.Render_Status'Image (Result.Status) & ">";
      end if;
   end Rendered;

   function Status_Of
     (Item   : I18N.Runtime.Instance;
      Locale : String;
      Key    : String;
      Args   : I18N.Arguments.Arguments)
      return I18N.Result.Render_Status
   is
   begin
      return I18N.Runtime.Render (Item, Locale, Key, Args).Status;
   end Status_Of;

   ---------------------------------------------------------------------------
   --  1. Shard loading.
   ---------------------------------------------------------------------------

   procedure Test_Load_Text_Adds_Shard
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "default_locale = en" & ASCII.LF & "en.title = ""Welcome""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded, "base Load_Text should load");
      Assert (Result.Entries_Added = 1, "base should add one entry");

      I18N.Runtime.Load_Text
        (Runtime, "lib", "en.help = ""Help""" & ASCII.LF, Result);
      Assert (Result.Status = I18N.Runtime.Loaded, "shard Load_Text should load");

      Assert (Rendered (Runtime, "en", "title", Args) = "Welcome",
              "base shard message should render");
      Assert (Rendered (Runtime, "en", "help", Args) = "Help",
              "library shard message should render");
   end Test_Load_Text_Adds_Shard;

   procedure Test_Load_Text_Honors_Default_Locale
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      --  A runtime built purely from Load_Text adopts the default_locale
      --  directive, so unqualified keys bind to it and fallback uses it.
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "default_locale = de" & ASCII.LF & "greeting = ""Hallo""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded, "standalone Load_Text loads");

      --  fr-CA has no entry, so it falls back to the de default locale.
      Assert (Rendered (Runtime, "fr-CA", "greeting", Args) = "Hallo",
              "unqualified key binds to the Load_Text default locale");

      --  A later shard does not change the established default locale.
      I18N.Runtime.Load_Text
        (Runtime, "shard",
         "default_locale = en" & ASCII.LF & "en.greeting = ""Hi""" & ASCII.LF,
         Result);
      Assert (Rendered (Runtime, "xx", "greeting", Args) = "Hallo",
              "an established default locale is not changed by a later shard");
   end Test_Load_Text_Honors_Default_Locale;

   procedure Test_Load_File_Layers_Shards
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Base    : constant String := "/tmp/i18n_feat_base.catalog";
      Shard   : constant String := "/tmp/i18n_feat_shard.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      Project_Tools.Files.Write_Text_File
        (Base, "default_locale = en" & ASCII.LF & "en.a = ""A""" & ASCII.LF);
      Project_Tools.Files.Write_Text_File
        (Shard, "en.b = ""B""" & ASCII.LF & "de.a = ""DA""" & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Base);
      I18N.Runtime.Load_File (Runtime, Shard, Result);

      Assert (Result.Status = I18N.Runtime.Loaded, "Load_File shard should load");
      Assert (Result.Entries_Added = 2, "shard adds two entries");
      Assert (Rendered (Runtime, "en", "a", Args) = "A", "base entry preserved");
      Assert (Rendered (Runtime, "en", "b", Args) = "B", "shard entry added");
      Assert (Rendered (Runtime, "de", "a", Args) = "DA", "shard de entry added");
   end Test_Load_File_Layers_Shards;

   procedure Test_Load_File_Missing_Is_Reported
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.title = ""Hi""" & ASCII.LF, Result);
      I18N.Runtime.Load_File
        (Runtime, "/tmp/i18n_feat_does_not_exist.catalog", Result);

      Assert (Result.Status = I18N.Runtime.Source_Not_Found,
              "missing shard file must report Source_Not_Found");
      Assert (I18N.Runtime.Is_Valid (Runtime),
              "failed shard load must not corrupt the runtime");
      Assert (Rendered (Runtime, "en", "title", Args) = "Hi",
              "runtime still renders after a failed shard load");
   end Test_Load_File_Missing_Is_Reported;

   ---------------------------------------------------------------------------
   --  2. Duplicate policy.
   ---------------------------------------------------------------------------

   procedure Test_Reject_Duplicates_Is_Nondestructive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.title = ""First""" & ASCII.LF, Result);
      I18N.Runtime.Load_Text
        (Runtime, "dup", "en.title = ""Second""" & ASCII.LF, Result,
         I18N.Runtime.Reject_Duplicates);

      Assert (Result.Status = I18N.Runtime.Duplicate_Rejected,
              "duplicate key under Reject_Duplicates must be rejected");
      Assert (Result.Entries_Added = 0, "rejected load adds nothing");
      Assert (Rendered (Runtime, "en", "title", Args) = "First",
              "rejected duplicate must leave the prior entry unchanged");
   end Test_Reject_Duplicates_Is_Nondestructive;

   procedure Test_Keep_First_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.title = ""First""" & ASCII.LF, Result);
      I18N.Runtime.Load_Text
        (Runtime, "dup",
         "en.title = ""Second""" & ASCII.LF & "en.extra = ""X""" & ASCII.LF,
         Result, I18N.Runtime.Keep_First);

      Assert (Result.Status = I18N.Runtime.Loaded, "Keep_First load succeeds");
      Assert (Result.Entries_Added = 1, "Keep_First adds only the new key");
      Assert (Result.Entries_Ignored = 1, "Keep_First reports the ignored duplicate");
      Assert (Result.Entries_Replaced = 0, "Keep_First replaces nothing");
      Assert (Rendered (Runtime, "en", "title", Args) = "First",
              "Keep_First keeps the existing entry");
      Assert (Rendered (Runtime, "en", "extra", Args) = "X",
              "Keep_First still adds non-colliding entries");
   end Test_Keep_First_Policy;

   procedure Test_Override_Previous_Policy
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.title = ""First""" & ASCII.LF, Result);
      I18N.Runtime.Load_Text
        (Runtime, "override", "en.title = ""Second""" & ASCII.LF, Result,
         I18N.Runtime.Override_Previous);

      Assert (Result.Status = I18N.Runtime.Loaded, "Override load succeeds");
      Assert (Result.Entries_Replaced = 1, "Override reports the replaced entry");
      Assert (Result.Entries_Added = 0, "Override of an existing key adds nothing");
      Assert (Rendered (Runtime, "en", "title", Args) = "Second",
              "Override_Previous replaces the prior entry");
   end Test_Override_Previous_Policy;

   ---------------------------------------------------------------------------
   --  3. Validation (non-destructive).
   ---------------------------------------------------------------------------

   procedure Test_Validate_Text_Accepts_Good_Catalog
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      VR : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("good",
           "default_locale = en" & ASCII.LF
           & "en.a = ""Hello {name}""" & ASCII.LF
           & "en.b = ""{n, plural, one {# item} other {# items}}""" & ASCII.LF);
   begin
      Assert (VR.Valid, "a well-formed catalog must validate");
      Assert (VR.Entry_Count = 2, "validation counts entries");
   end Test_Validate_Text_Accepts_Good_Catalog;

   procedure Test_Validate_Text_Rejects_Bad_Message
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      VR : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad", "en.a = ""Hello {name""" & ASCII.LF);
   begin
      Assert (not VR.Valid, "an unbalanced ICU message must fail validation");
   end Test_Validate_Text_Rejects_Bad_Message;

   procedure Test_Validate_Text_Rejects_Duplicate
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      VR : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("dup",
           "en.a = ""One""" & ASCII.LF & "en.a = ""Two""" & ASCII.LF);
   begin
      Assert (not VR.Valid, "a duplicate key within input must fail validation");
      Assert (I18N.Diagnostics.Has_Kind
                (VR.Diagnostics, I18N.Diagnostics.Validation_Error),
              "duplicate validation must report a diagnostic");
   end Test_Validate_Text_Rejects_Duplicate;

   --  True when some diagnostic's message text contains Needle.
   function Any_Message_Contains
     (List   : I18N.Diagnostics.Diagnostic_List;
      Needle : String)
      return Boolean
   is
   begin
      for I in 1 .. I18N.Diagnostics.Length (List) loop
         if Ada.Strings.Fixed.Index
              (I18N.Diagnostics.Message_Text
                 (I18N.Diagnostics.Element (List, I)),
               Needle) /= 0
         then
            return True;
         end if;
      end loop;
      return False;
   end Any_Message_Contains;

   procedure Test_Diagnostics_Report_Line_Numbers
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      --  The invalid ICU message is on line 3.
      Bad : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("cat",
           "default_locale = en" & ASCII.LF   -- line 1
           & "en.ok = ""fine""" & ASCII.LF    -- line 2
           & "en.bad = ""{oops""" & ASCII.LF);  -- line 3
      --  The duplicate key is on line 2.
      Dup : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("cat",
           "en.a = ""one""" & ASCII.LF        -- line 1
           & "en.a = ""two""" & ASCII.LF);     -- line 2

      --  The malformed default locale is on line 3.
      Bad_Default : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("cat",
           "default_locale = en" & ASCII.LF    -- line 1
           & "title = ""Start""" & ASCII.LF   -- line 2
           & "default_locale = zz--" & ASCII.LF);   -- line 3

      --  The duplicate default locale is on line 3.
      Duplicate_Default : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("cat",
           "default_locale = en" & ASCII.LF   -- line 1
           & "title = ""Start""" & ASCII.LF  -- line 2
           & "default_locale = de" & ASCII.LF); -- line 3
   begin
      Assert (not Bad.Valid, "invalid message fails validation");
      Assert (Any_Message_Contains (Bad.Diagnostics, "line 3"),
              "the diagnostic must name the offending line (3)");

      Assert (not Dup.Valid, "duplicate key fails validation");
      Assert (Any_Message_Contains (Dup.Diagnostics, "line 2"),
              "the duplicate diagnostic must name the offending line (2)");

      Assert (not Bad_Default.Valid, "malformed default locale fails validation");
      Assert (Any_Message_Contains
                (Bad_Default.Diagnostics, "line 3"),
              "malformed default locale diagnostic must name offending line (3)");

      Assert (not Duplicate_Default.Valid,
              "duplicate default locale fails validation");
      Assert (Any_Message_Contains
                (Duplicate_Default.Diagnostics, "line 3"),
              "duplicate default locale diagnostic must name offending line (3)");
   end Test_Diagnostics_Report_Line_Numbers;

   procedure Test_Validation_Does_Not_Touch_Runtime
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      VR      : I18N.Runtime.Catalog_Validation_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.title = ""Stable""" & ASCII.LF, Result);

      VR := I18N.Runtime.Validate_Catalog_Text
              ("invalid", "en.x = ""{bad""" & ASCII.LF);

      Assert (not VR.Valid, "validation of bad catalog fails");
      Assert (I18N.Runtime.Is_Valid (Runtime),
              "validation failure must not invalidate an existing runtime");
      Assert (Rendered (Runtime, "en", "title", Args) = "Stable",
              "render after a failed validation behaves exactly as before");
   end Test_Validation_Does_Not_Touch_Runtime;

   procedure Test_Validate_Rejects_Bad_Locale_And_Key
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (not I18N.Runtime.Validate_Catalog_Text
                    ("badloc", "en-.title = ""X""" & ASCII.LF).Valid,
              "a malformed locale subtag must be rejected");
      Assert (not I18N.Runtime.Validate_Catalog_Text
                    ("badloc", "e n.title = ""X""" & ASCII.LF).Valid,
              "a locale with whitespace must be rejected");
      Assert (not I18N.Runtime.Validate_Catalog_Text
                    ("badkey", "en.a b = ""X""" & ASCII.LF).Valid,
              "a key with whitespace must be rejected");
      --  Dotted keys remain valid (split uses only the first dot).
      Assert (I18N.Runtime.Validate_Catalog_Text
                ("dotted", "en.cart.items = ""X""" & ASCII.LF).Valid,
              "a dotted key such as cart.items stays valid");
   end Test_Validate_Rejects_Bad_Locale_And_Key;

   procedure Test_Validate_File
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "/tmp/i18n_feat_validate.catalog";
      VR   : I18N.Runtime.Catalog_Validation_Result;
   begin
      Project_Tools.Files.Write_Text_File
        (Path, "default_locale = en" & ASCII.LF & "en.a = ""A""" & ASCII.LF);
      VR := I18N.Runtime.Validate_Catalog_File (Path);
      Assert (VR.Valid, "valid catalog file validates");

      VR := I18N.Runtime.Validate_Catalog_File ("/tmp/i18n_feat_no_such.catalog");
      Assert (not VR.Valid, "missing catalog file fails validation");
   end Test_Validate_File;

   procedure Test_Binary_Catalogs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path : constant String := "/tmp/i18n_feat_binary.i18nb";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Valid_Binary : constant String :=
        "I18N-CATALOG-BINARY" & ASCII.LF
        & "format_version=1" & ASCII.LF
        & "ir_version=1" & ASCII.LF
        & "payload=text" & ASCII.LF
        & ASCII.LF
        & "default_locale = en" & ASCII.LF
        & "en.title = ""Binary {name}""" & ASCII.LF
        & "de.title = ""Binaer {name}""" & ASCII.LF;
      Invalid_Version : constant String :=
        "I18N-CATALOG-BINARY" & ASCII.LF
        & "format_version=2" & ASCII.LF
        & "ir_version=1" & ASCII.LF
        & "payload=text" & ASCII.LF
        & ASCII.LF
        & "en.title = ""Bad""" & ASCII.LF;
      Hex_Binary : constant String :=
        "I18N-CATALOG-BINARY" & ASCII.LF
        & "format_version=1" & ASCII.LF
        & "ir_version=1" & ASCII.LF
        & "payload=hex-text" & ASCII.LF
        & ASCII.LF
        & "64656661756c745f6c6f63616c65203d20656e0a"
        & "656e2e686578203d2022486578207b6e616d657d220a"
        & "64652e686578203d20224865782d4445207b6e616d657d220a";
      Invalid_Hex_Binary : constant String :=
        "I18N-CATALOG-BINARY" & ASCII.LF
        & "format_version=1" & ASCII.LF
        & "ir_version=1" & ASCII.LF
        & "payload=hex-text" & ASCII.LF
        & ASCII.LF
        & "not-hex" & ASCII.LF;
      Shard : constant String :=
        "I18N-CATALOG-BINARY" & ASCII.LF
        & "format_version=1" & ASCII.LF
        & "ir_version=1" & ASCII.LF
        & "payload=text" & ASCII.LF
        & ASCII.LF
        & "en.extra = ""Extra {name}""" & ASCII.LF;
      VR : I18N.Runtime.Catalog_Validation_Result;
   begin
      VR := I18N.Runtime.Validate_Binary_Catalog_Text
        ("valid_binary", Valid_Binary);
      Assert (VR.Valid, "valid binary catalog text validates");
      Assert (VR.Entry_Count = 2, "binary payload entry count is reported");

      VR := I18N.Runtime.Validate_Binary_Catalog_Text
        ("hex_binary", Hex_Binary);
      Assert (VR.Valid, "hex-text binary catalog validates");
      Assert (VR.Entry_Count = 2,
              "hex-text binary payload entry count is reported");

      VR := I18N.Runtime.Validate_Binary_Catalog_Text
        ("bad_hex_binary", Invalid_Hex_Binary);
      Assert (not VR.Valid, "malformed hex-text binary payloads are rejected");

      VR := I18N.Runtime.Validate_Binary_Catalog_Text
        ("bad_binary", Invalid_Version);
      Assert (not VR.Valid,
              "unsupported binary catalog versions are rejected");

      Project_Tools.Files.Write_Text_File (Path, Valid_Binary);
      VR := I18N.Runtime.Validate_Binary_Catalog_File (Path);
      Assert (VR.Valid, "valid binary catalog file validates");

      I18N.Runtime.Initialize_Binary_File (Runtime, Path);
      Assert (I18N.Runtime.Is_Valid (Runtime),
              "runtime initializes from a binary catalog");
      I18N.Arguments.Set (Args, "name", "Ada");
      Assert (Rendered (Runtime, "de-AT", "title", Args) = "Binaer Ada",
              "binary catalog render uses locale fallback");

      Project_Tools.Files.Write_Text_File (Path, Hex_Binary);
      I18N.Runtime.Initialize_Binary_File (Runtime, Path);
      Assert (I18N.Runtime.Is_Valid (Runtime),
              "runtime initializes from a hex-text binary catalog");
      Assert (Rendered (Runtime, "de-AT", "hex", Args) = "Hex-DE Ada",
              "hex-text binary catalog render uses locale fallback");

      Project_Tools.Files.Write_Text_File (Path, Valid_Binary);
      I18N.Runtime.Initialize_Binary_File (Runtime, Path);
      Assert (I18N.Runtime.Is_Valid (Runtime),
              "runtime reinitializes from a text binary catalog");

      Project_Tools.Files.Write_Text_File (Path, Shard);
      I18N.Runtime.Load_Binary_File (Runtime, Path, Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "binary catalog shard loads");
      Assert (Rendered (Runtime, "en", "extra", Args) = "Extra Ada",
              "binary shard entry renders");

      Project_Tools.Files.Write_Text_File (Path, Invalid_Version);
      I18N.Runtime.Load_Binary_File (Runtime, Path, Result);
      Assert (Result.Status = I18N.Runtime.Invalid_Catalog,
              "invalid binary shard reports Invalid_Catalog");
      Assert (Rendered (Runtime, "en", "title", Args) = "Binary Ada",
              "failed binary shard load is non-destructive");
   end Test_Binary_Catalogs;

   ---------------------------------------------------------------------------
   --  4. Resolution.
   ---------------------------------------------------------------------------

   procedure Test_Resolve_Found_Through_Fallback
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "default_locale = en" & ASCII.LF
         & "en.title = ""EN""" & ASCII.LF
         & "de.title = ""DE""" & ASCII.LF,
         Result);

      declare
         R : constant I18N.Runtime.Resolve_Result :=
           I18N.Runtime.Resolve (Runtime, "de-AT", "title");
      begin
         Assert (R.Status = I18N.Runtime.Found,
                 "de-AT.title must resolve through fallback");
         Assert (I18N.Runtime.Resolved_Locale (R) = "de",
                 "de-AT resolves at the de parent locale");
      end;
   end Test_Resolve_Found_Through_Fallback;

   procedure Test_Locale_Canonicalization_And_Aliases
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Resolve_Missing_And_Invalid
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "default_locale = en" & ASCII.LF & "en.title = ""EN""" & ASCII.LF,
         Result);

      declare
         R : constant I18N.Runtime.Resolve_Result :=
           I18N.Runtime.Resolve (Runtime, "en", "absent");
      begin
         Assert (R.Status = I18N.Runtime.Missing_Key,
                 "an absent key resolves as Missing_Key");
         Assert (I18N.Runtime.Resolved_Locale (R) = "",
                 "a missing resolution has an empty resolved locale");
      end;

      --  An invalid runtime resolves as Runtime_Invalid.
      declare
         Bad     : I18N.Runtime.Instance;
         Bad_Res : I18N.Runtime.Load_Result;
      begin
         I18N.Runtime.Load_Text (Bad, "bad", "no separator" & ASCII.LF, Bad_Res);
         --  Bad load is non-destructive; force an invalid runtime via Initialize.
         I18N.Runtime.Initialize (Bad, "/tmp/i18n_feat_no_such_init.catalog");
         Assert (not I18N.Runtime.Is_Valid (Bad), "runtime should be invalid");
         Assert (I18N.Runtime.Resolve (Bad, "en", "title").Status
                   = I18N.Runtime.Runtime_Invalid,
                 "resolving on an invalid runtime reports Runtime_Invalid");
      end;
   end Test_Resolve_Missing_And_Invalid;

   procedure Test_Locale_Fallback_Formatting_Matrix
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;

      function Persian_Number return String is
      begin
         return
           U (16#6F1#) & U (16#66C#) & U (16#6F2#) & U (16#6F3#)
           & U (16#6F4#) & U (16#66C#) & U (16#6F5#)
           & U (16#6F6#) & U (16#6F7#) & U (16#66B#)
           & U (16#6F8#) & U (16#6F9#);
      end Persian_Number;

      function Persian_Currency return String is
      begin
         return
           "$" & U (16#6F1#) & U (16#66C#) & U (16#6F2#) & U (16#6F3#)
           & U (16#6F4#) & U (16#66C#) & U (16#6F5#)
           & U (16#6F6#) & U (16#6F7#) & U (16#66B#)
           & U (16#6F8#) & U (16#6F0#);
      end Persian_Currency;

      function Persian_Date return String is
      begin
         return
           U (16#6F2#) & U (16#6F0#) & U (16#6F2#) & U (16#6F4#)
           & "-" & U (16#6F0#) & U (16#6F2#) & "-"
           & U (16#6F2#) & U (16#6F9#);
      end Persian_Date;

      function Persian_Time return String is
      begin
         return U (16#6F0#) & U (16#6F9#) & ":" & U (16#6F0#) & U (16#6F5#);
      end Persian_Time;

      procedure Set_Common (Count : String) is
      begin
         I18N.Arguments.Clear (Args);
         I18N.Arguments.Set (Args, "value", "1234567.89");
         I18N.Arguments.Set (Args, "amount", "1234567.8");
         I18N.Arguments.Set (Args, "day", "2024-02-29");
         I18N.Arguments.Set (Args, "clock", "09:05:07");
         I18N.Arguments.Set (Args, "count", Count);
      end Set_Common;

      procedure Assert_Resolved
        (Requested : String;
         Expected  : String) is
         R : constant I18N.Runtime.Resolve_Result :=
           I18N.Runtime.Resolve (Runtime, Requested, "matrix");
      begin
         Assert (R.Status = I18N.Runtime.Found,
                 Requested & " should resolve matrix");
         Assert (I18N.Runtime.Resolved_Locale (R) = Expected,
                 Requested & " resolved locale");
      end Assert_Resolved;

      procedure Assert_Render
        (Requested : String;
         Count     : String;
         Expected  : String) is
      begin
         Set_Common (Count);
         Assert (Rendered (Runtime, Requested, "matrix", Args) = Expected,
                 Requested & " formatted output");
      end Assert_Render;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "locale-matrix",
         "default_locale = en" & ASCII.LF
         & "en.matrix = ""en {value, number} {amount, currency, USD} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF
         & "de.matrix = ""de {value, number} {amount, currency, EUR} "
         & "{day, date, short} {clock, time, short} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF
         & "fr.matrix = ""fr {value, number} {amount, currency, EUR} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF
         & "hi-IN.matrix = ""hi {value, number} {amount, currency, INR} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF
         & "ar.matrix = ""ar {value, number} {amount, currency, USD} "
         & "{day, date, short} {clock, time, short} "
         & "{count, plural, zero {zero} one {one} two {two} "
         & "few {few} many {many} other {other}}""" & ASCII.LF
         & "fa.matrix = ""fa {value, number} {amount, currency, USD} "
         & "{day, date} {clock, time, short} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF
         & "ro.matrix = ""ro {value, number} {amount, currency, EUR} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} few {few} other {other}}"""
         & ASCII.LF
         & "lt.matrix = ""lt {value, number} {amount, currency, EUR} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} few {few} many {many} other {other}}"""
         & ASCII.LF
         & "sl.matrix = ""sl {value, number} {amount, currency, EUR} "
         & "{day, date, long} {clock, time, short} "
         & "{count, plural, one {one} two {two} few {few} other {other}}"""
         & ASCII.LF
         & "th-u-ca-buddhist.matrix = ""th {day, date, long}"""
         & ASCII.LF
         & "ja-u-ca-japanese.matrix = ""ja {day, date, long}"""
         & ASCII.LF
         & "zz.matrix = ""zz {value, number} "
         & "{count, plural, one {one} other {other}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "locale matrix catalog should load");

      Assert_Resolved ("de-AT", "de");
      Assert_Resolved ("fr-CA", "fr");
      Assert_Resolved ("hi-IN-x-test", "hi-IN");
      Assert_Resolved ("ar-EG", "ar");
      Assert_Resolved ("fa-IR", "fa");
      Assert_Resolved ("ro-MD", "ro");
      Assert_Resolved ("lt-LT", "lt");
      Assert_Resolved ("sl-SI", "sl");
      Assert_Resolved ("th-u-ca-buddhist-extra", "th-u-ca-buddhist");
      Assert_Resolved ("ja-u-ca-japanese-extra", "ja-u-ca-japanese");
      Assert_Resolved ("zz-ZZ", "zz");
      Assert_Resolved ("es-MX", "en");

      Assert_Render
        ("de-AT", "1",
         "de 1.234.567,89 1.234.567,80 " & U (16#20AC#)
         & " 29.02.24 09:05 one");
      Assert_Render
        ("fr-CA", "0",
         "fr 1" & U (16#202F#) & "234" & U (16#202F#) & "567,89 1"
         & U (16#202F#) & "234" & U (16#202F#) & "567,80 " & U (16#20AC#)
         & " 29 f" & U (16#E9#) & "vrier 2024 09:05 one");
      Assert_Render
        ("hi-IN-x-test", "2",
         "hi 12,34,567.89 " & U (16#20B9#) & "12,34,567.80 29 "
         & U (16#92B#) & U (16#93C#) & U (16#930#) & U (16#935#)
         & U (16#930#) & U (16#940#) & " 2024 09:05 other");
      Assert_Render
        ("ar-EG", "3",
         "ar " & U (16#661#) & U (16#66C#) & U (16#662#) & U (16#663#)
         & U (16#664#) & U (16#66C#) & U (16#665#) & U (16#666#)
         & U (16#667#) & U (16#66B#) & U (16#668#) & U (16#669#) & " "
         & U (16#661#) & U (16#66C#) & U (16#662#) & U (16#663#)
         & U (16#664#) & U (16#66C#) & U (16#665#) & U (16#666#)
         & U (16#667#) & U (16#66B#) & U (16#668#) & U (16#660#) & " $ "
         & U (16#662#) & U (16#669#) & U (16#200F#) & "/" & U (16#662#)
         & U (16#200F#) & "/" & U (16#662#) & U (16#660#) & U (16#662#)
         & U (16#664#) & " " & U (16#660#) & U (16#669#) & ":"
         & U (16#660#) & U (16#665#) & " few");
      Assert_Render
        ("fa-IR", "1",
         "fa " & Persian_Number & " " & Persian_Currency & " "
         & Persian_Date & " " & Persian_Time & " one");
      Assert_Render
        ("ro-MD", "2",
         "ro 1.234.567,89 1.234.567,80 " & U (16#20AC#)
         & " 29 februarie 2024 09:05 few");
      Assert_Render
        ("lt-LT", "2",
         "lt 1" & U (16#A0#) & "234" & U (16#A0#) & "567,89 1"
         & U (16#A0#) & "234" & U (16#A0#) & "567,80 " & U (16#20AC#)
         & " 2024 m. vasario 29 d. 09:05 few");
      Assert_Render
        ("sl-SI", "2",
         "sl 1.234.567,89 1.234.567,80 " & U (16#20AC#)
         & " 29. februar 2024 09:05 two");
      Assert_Render
        ("th-u-ca-buddhist-extra", "2",
         "th " & U (16#E52#) & U (16#E59#) & " " & U (16#E01#)
         & U (16#E38#) & U (16#E21#) & U (16#E20#) & U (16#E32#)
         & U (16#E1E#) & U (16#E31#) & U (16#E19#) & U (16#E18#)
         & U (16#E4C#) & " " & U (16#E52#) & U (16#E55#) & U (16#E56#)
         & U (16#E57#));
      Assert_Render
        ("ja-u-ca-japanese-extra", "2",
         "ja " & U (16#4EE4#) & U (16#548C#) & " 6"
         & U (16#5E74#) & "2" & U (16#6708#) & "29"
         & U (16#65E5#));
      Assert_Render
        ("zz-ZZ", "1",
         "zz 1,234,567.89 other");
      Assert_Render
        ("es-MX", "1",
         "en 1,234,567.89 $1,234,567.80 February 29, 2024 09:05 one");
   end Test_Locale_Fallback_Formatting_Matrix;

   ---------------------------------------------------------------------------
   --  5. Argument helper setters.
   ---------------------------------------------------------------------------

   procedure Test_Integer_Helper_Formatting
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.n = ""{value}""" & ASCII.LF, Result);

      I18N.Arguments.Set_Integer (Args, "value", -42);
      Assert (Rendered (Runtime, "en", "n", Args) = "-42",
              "Set_Integer renders a strict decimal with no leading space");

      I18N.Arguments.Set_Integer (Args, "value", 7);
      Assert (Rendered (Runtime, "en", "n", Args) = "7",
              "Set_Integer of a positive value has no leading space");
   end Test_Integer_Helper_Formatting;

   procedure Test_Natural_Helper_Formatting
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.n = ""{value}""" & ASCII.LF, Result);

      I18N.Arguments.Set_Natural (Args, "value", 0);
      Assert (Rendered (Runtime, "en", "n", Args) = "0",
              "Set_Natural renders zero as ""0""");

      I18N.Arguments.Set_Natural (Args, "value", 100);
      Assert (Rendered (Runtime, "en", "n", Args) = "100",
              "Set_Natural renders a strict decimal");
   end Test_Natural_Helper_Formatting;

   procedure Test_Boolean_Helper_Formatting
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.flag = ""{on, select, true {YES} false {NO} other {?}}""" & ASCII.LF,
         Result);

      I18N.Arguments.Set_Boolean (Args, "on", True);
      Assert (Rendered (Runtime, "en", "flag", Args) = "YES",
              "Set_Boolean True selects the true branch");

      I18N.Arguments.Set_Boolean (Args, "on", False);
      Assert (Rendered (Runtime, "en", "flag", Args) = "NO",
              "Set_Boolean False selects the false branch");
   end Test_Boolean_Helper_Formatting;

   ---------------------------------------------------------------------------
   --  6. Generalized select branches.
   ---------------------------------------------------------------------------

   procedure Test_Generalized_Select
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.w = ""{width, select, full {hour} short {hr} narrow {h} "
         & "other {hour}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "a generalized select catalog must load");

      I18N.Arguments.Set (Args, "width", "full");
      Assert (Rendered (Runtime, "en", "w", Args) = "hour", "full branch");
      I18N.Arguments.Set (Args, "width", "short");
      Assert (Rendered (Runtime, "en", "w", Args) = "hr", "short branch");
      I18N.Arguments.Set (Args, "width", "narrow");
      Assert (Rendered (Runtime, "en", "w", Args) = "h", "narrow branch");
      I18N.Arguments.Set (Args, "width", "unmatched");
      Assert (Rendered (Runtime, "en", "w", Args) = "hour",
              "an unmatched selector falls back to other");
   end Test_Generalized_Select;

   procedure Test_Legacy_Gender_Select_Still_Works
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.g = ""{gender, select, male {He} female {She} other {They}}"""
         & ASCII.LF,
         Result);

      I18N.Arguments.Set (Args, "gender", "female");
      Assert (Rendered (Runtime, "en", "g", Args) = "She",
              "existing male/female/other selects must keep working");
   end Test_Legacy_Gender_Select_Still_Works;

   procedure Test_Selectordinal_Optional_Branches_Fall_Back
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;

      function Rank (Value : String) return String is
      begin
         I18N.Arguments.Set (Args, "rank", Value);
         return Rendered (Runtime, "en", "place", Args);
      end Rank;
   begin
      --  Only "other" is provided; every value falls back to it.
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.place = ""{rank, selectordinal, other {#th}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "a selectordinal with only other is valid");
      Assert (Rank ("1") = "1th", "missing one falls back to other");
      Assert (Rank ("2") = "2th", "missing two falls back to other");

      --  one/other only; the few-category value (3) falls back to other.
      I18N.Runtime.Load_Text
        (Runtime, "base2",
         "en.r2 = ""{rank, selectordinal, one {#st} other {#th}}""" & ASCII.LF,
         Result);
      I18N.Arguments.Set (Args, "rank", "21");
      Assert (Rendered (Runtime, "en", "r2", Args) = "21st",
              "present one branch still used (21 -> one)");
      I18N.Arguments.Set (Args, "rank", "3");
      Assert (Rendered (Runtime, "en", "r2", Args) = "3th",
              "few category with no few branch falls back to other");
   end Test_Selectordinal_Optional_Branches_Fall_Back;

   procedure Test_Selectordinal_All_Category_Branches
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Target  : String (1 .. 32) := [others => Character'Val (0)];
      Last    : Natural := 0;
      Status  : I18N.Result.Render_Status;
      Duplicate_Many : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("duplicate_selectordinal_many",
           "it.place = ""{rank, selectordinal, many {many} "
           & "many {again} other {other}}""" & ASCII.LF);
   begin
      I18N.Runtime.Load_Text
        (Runtime, "ordinal-categories",
         "it.place = ""{rank, selectordinal, zero {zero #} one {one #} "
         & "two {two #} few {few #} many {many #} other {other #}}"""
         & ASCII.LF
         & "it.fallback = ""{rank, selectordinal, one {one #} "
         & "other {other #}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "selectordinal accepts all category branch names");
      Assert (not Duplicate_Many.Valid,
              "duplicate many selectordinal branches are rejected");

      I18N.Arguments.Set (Args, "rank", "8");
      Assert (Rendered (Runtime, "it", "place", Args) = "many 8",
              "Italian ordinal many branch is selected");
      I18N.Runtime.Render_Into
        (Runtime, "it", "place", Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              "bounded selectordinal many branch succeeds");
      Assert (Target (1 .. Last) = "many 8",
              "bounded selectordinal many branch matches materialized output");
      Assert (Rendered (Runtime, "it", "fallback", Args) = "other 8",
              "missing selectordinal many branch falls back to other");
      I18N.Arguments.Set (Args, "rank", "1");
      Assert (Rendered (Runtime, "it", "place", Args) = "other 1",
              "unsupported ordinal one categories still fall back to other");
   end Test_Selectordinal_All_Category_Branches;

   procedure Test_Plural_Only_Other_Is_Valid
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.items = ""{count, plural, other {# items}}""" & ASCII.LF, Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "a plural with only other is valid");
      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "items", Args) = "1 items",
              "missing one branch falls back to other");
   end Test_Plural_Only_Other_Is_Valid;

   procedure Test_Plural_Offset
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      VR      : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_offset",
           "en.items = ""{count, plural, one {#} offset:1 other {#}}"""
           & ASCII.LF);
   begin
      Assert (not VR.Valid,
              "plural offset must appear before plural branches");

      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.items = ""{count, plural, offset:1 one {# item} other {# items}}"""
         & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "a plural with an offset should load");

      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "en", "items", Args) = "1 item",
              "offset adjusted value selects one and substitutes #");

      I18N.Arguments.Set (Args, "count", "5");
      Assert (Rendered (Runtime, "en", "items", Args) = "4 items",
              "offset adjusted value selects other and substitutes #");

      I18N.Arguments.Set (Args, "count", "2.0");
      Assert (Status_Of (Runtime, "en", "items", Args) =
                I18N.Result.Invalid_Argument,
              "offset plural requires an integer selector");
   end Test_Plural_Offset;

   procedure Test_Exact_Plural_And_Ordinal_Branches
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Target  : String (1 .. 40) := [others => Character'Val (0)];
      Last    : Natural := 0;
      Status  : I18N.Result.Render_Status;
      Duplicate : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("duplicate_exact",
           "en.items = ""{count, plural, =01 {a} =1 {b} other {c}}"""
           & ASCII.LF);
   begin
      I18N.Runtime.Load_Text
        (Runtime, "exact-branches",
         "en.items = ""{count, plural, =0 {no items} "
         & "=1 {one exact} one {one category} other {# items}}"""
         & ASCII.LF
         & "en.invites = ""{count, plural, offset:1 =0 {nobody} "
         & "=1 {you} one {you and # guest} other {you and # guests}}"""
         & ASCII.LF
         & "en.place = ""{rank, selectordinal, =11 {11th exact} "
         & "one {#st} two {#nd} few {#rd} other {#th}}"""
         & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "exact plural and selectordinal branches should load");
      Assert (not Duplicate.Valid,
              "duplicate normalized exact plural branches are rejected");

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "en", "items", Args) = "no items",
              "exact plural =0 branch has precedence");
      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "items", Args) = "one exact",
              "exact plural =1 branch has precedence over category one");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "en", "items", Args) = "2 items",
              "plural without exact match falls back to category/other");

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "en", "invites", Args) = "nobody",
              "exact plural matching uses the original selector before offset");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "en", "invites", Args) = "you and 1 guest",
              "offset still controls # substitution after exact checks");

      I18N.Arguments.Set (Args, "rank", "11");
      Assert (Rendered (Runtime, "en", "place", Args) = "11th exact",
              "exact selectordinal branch has precedence");
      I18N.Arguments.Set (Args, "rank", "21");
      Assert (Rendered (Runtime, "en", "place", Args) = "21st",
              "selectordinal without exact match uses ordinal category");
      I18N.Runtime.Render_Into
        (Runtime, "en", "place", Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              "bounded exact/selectordinal render succeeds");
      Assert (Target (1 .. Last) = "21st",
              "bounded exact/selectordinal render matches materialized output");
   end Test_Exact_Plural_And_Ordinal_Branches;

   procedure Test_Decimal_Plural_Operands
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Target  : String (1 .. 40) := [others => Character'Val (0)];
      Last    : Natural := 0;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "decimal-plurals",
         "en.items = ""{count, plural, =1 {exact #} one {one #} "
         & "other {other #}}""" & ASCII.LF
         & "fr.items = ""{count, plural, =1 {exact #} one {one #} "
         & "other {other #}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "decimal plural catalog should load");

      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "items", Args) = "exact 1",
              "integer plural still selects exact branches first");

      I18N.Arguments.Set (Args, "count", "1.0");
      Assert (Rendered (Runtime, "en", "items", Args) = "other 1.0",
              "English decimal 1.0 uses fractional cardinal operands");

      I18N.Arguments.Set (Args, "count", "1.5");
      Assert (Rendered (Runtime, "fr", "items", Args) = "one 1.5",
              "French decimal 1.5 uses CLDR fractional operands");

      I18N.Runtime.Render_Into
        (Runtime, "en", "items", Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              "bounded decimal plural render succeeds");
      Assert (Target (1 .. Last) = "other 1.5",
              "bounded decimal plural render preserves decimal # text");
   end Test_Decimal_Plural_Operands;

   procedure Test_Apostrophe_Escaping
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Status  : I18N.Result.Render_Status;
      Target  : String (1 .. 40);
      Last    : Natural := 0;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.text = ""Don''t parse '{name}'""" & ASCII.LF
         & "en.tail = ""This is '{literal""" & ASCII.LF
         & "en.literal_apostrophe = ""I don't quote""" & ASCII.LF
         & "en.items = ""{count, plural, one {'#' item} "
         & "other {'#' items and # raw}}""" & ASCII.LF
         & "en.implicit = ""{count, plural, one {'# item} "
         & "other {'# items}}""" & ASCII.LF
         & "en.nested_quote = ""{gender, select, "
         & "female {{count, plural, one {She has '{#}' file} "
         & "other {She has '#'/# files}}} "
         & "other {They have ''{count}'' files}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "apostrophe-escaped catalog should load");

      I18N.Arguments.Set (Args, "name", "Ada");
      Assert (Rendered (Runtime, "en", "text", Args) =
                "Don't parse {name}",
              "doubled apostrophe and quoted braces render literally");
      Assert (Rendered (Runtime, "en", "tail", Args) = "This is {literal",
              "unterminated quoted text closes at message end");
      Assert (Rendered (Runtime, "en", "literal_apostrophe", Args) =
                "I don't quote",
              "apostrophe before non-syntax text stays literal");

      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "items", Args) = "# item",
              "quoted # is literal in a plural one branch");
      I18N.Arguments.Set (Args, "gender", "female");
      Assert (Rendered (Runtime, "en", "nested_quote", Args) =
                "She has {#} file",
              "quoted braces and # render literally in nested plural branches");

      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "en", "items", Args) =
                "# items and 2 raw",
              "quoted # stays literal and unquoted # substitutes");
      Assert (Rendered (Runtime, "en", "implicit", Args) = "# items",
              "unterminated quoted text closes at plural branch end");
      Assert (Rendered (Runtime, "en", "nested_quote", Args) =
                "She has #/2 files",
              "quoted # and substituted # coexist in nested plural branches");
      I18N.Arguments.Set (Args, "gender", "other");
      I18N.Arguments.Set (Args, "count", "3");
      Assert (Rendered (Runtime, "en", "nested_quote", Args) =
                "They have '3' files",
              "doubled apostrophes render around nested formatted arguments");

      I18N.Runtime.Render_Into
        (Runtime, "en", "implicit", Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              "bounded render handles branch-end implicit quote close");
      Assert (Target (1 .. Last) = "# items",
              "bounded render preserves branch-end literal #");
   end Test_Apostrophe_Escaping;

   procedure Test_Select_Missing_Other_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.g = ""{gender, select, male {He}}""" & ASCII.LF, Result);
      Assert (Result.Status = I18N.Runtime.Invalid_Catalog,
              "a select without an other branch must be rejected");
   end Test_Select_Missing_Other_Is_Rejected;

   procedure Test_Duplicate_Select_Branch_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      VR : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("dupbranch",
           "en.g = ""{g, select, full {a} full {b} other {c}}""" & ASCII.LF);
   begin
      Assert (not VR.Valid,
              "a duplicate select branch must be rejected");
   end Test_Duplicate_Select_Branch_Is_Rejected;

   ---------------------------------------------------------------------------
   --  7. Plural-category API.
   ---------------------------------------------------------------------------

   procedure Test_Plural_Cardinal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type I18N.Plurals.Plural_Category;
   begin
      Assert (I18N.Plurals.Cardinal ("en", 1) = I18N.Plurals.One,
              "en cardinal 1 is one");
      Assert (I18N.Plurals.Cardinal ("en", 2) = I18N.Plurals.Other,
              "en cardinal 2 is other");
      Assert (I18N.Plurals.Cardinal ("en", 0) = I18N.Plurals.Other,
              "en cardinal 0 is other");
      Assert (I18N.Plurals.Cardinal ("de-AT", 1) = I18N.Plurals.One,
              "de cardinal resolves via language subtag");
      Assert (I18N.Plurals.Cardinal ("fr", 0) = I18N.Plurals.One,
              "fr cardinal 0 is one");
      Assert (I18N.Plurals.Cardinal ("fr", 2) = I18N.Plurals.Other,
              "fr cardinal 2 is other");
      Assert (I18N.Plurals.Cardinal ("xx", 5) = I18N.Plurals.Other,
              "an unsupported locale falls back to the root rule (other)");

      --  Fractional operands (i, v, f). v = 0 matches the integer rule.
      Assert (I18N.Plurals.Cardinal ("en", 1, 0, 0) = I18N.Plurals.One,
              "en 1 (v=0) is one");
      Assert (I18N.Plurals.Cardinal ("en", 1, 1, 5) = I18N.Plurals.Other,
              "en 1.5 (v>0) is other");
      Assert (I18N.Plurals.Cardinal ("de", 2, 1, 0) = I18N.Plurals.Other,
              "de 2.0 is other");
      --  French: one iff i in {0,1} regardless of the fraction.
      Assert (I18N.Plurals.Cardinal ("fr", 1, 1, 5) = I18N.Plurals.One,
              "fr 1.5 is one (i=1)");
      Assert (I18N.Plurals.Cardinal ("fr", 0, 1, 5) = I18N.Plurals.One,
              "fr 0.5 is one (i=0)");
      Assert (I18N.Plurals.Cardinal ("fr", 2, 1, 5) = I18N.Plurals.Other,
              "fr 2.5 is other (i=2)");
      Assert (I18N.Plurals.Cardinal ("ro", 1, 0, 0) = I18N.Plurals.One,
              "ro 1 is one");
      Assert (I18N.Plurals.Cardinal ("ro", 0, 0, 0) = I18N.Plurals.Few,
              "ro 0 is few");
      Assert (I18N.Plurals.Cardinal ("ro", 20, 0, 0) = I18N.Plurals.Other,
              "ro 20 is other");
      Assert (I18N.Plurals.Cardinal ("ro", 2, 1, 5) = I18N.Plurals.Few,
              "ro 2.5 is few");
      Assert (I18N.Plurals.Cardinal ("lt", 1, 0, 0) = I18N.Plurals.One,
              "lt 1 is one");
      Assert (I18N.Plurals.Cardinal ("lt", 2, 0, 0) = I18N.Plurals.Few,
              "lt 2 is few");
      Assert (I18N.Plurals.Cardinal ("lt", 11, 0, 0) = I18N.Plurals.Other,
              "lt 11 is other");
      Assert (I18N.Plurals.Cardinal ("lt", 2, 1, 5) = I18N.Plurals.Many,
              "lt 2.5 is many");
      Assert (I18N.Plurals.Cardinal ("sl", 1, 0, 0) = I18N.Plurals.One,
              "sl 1 is one");
      Assert (I18N.Plurals.Cardinal ("sl", 2, 0, 0) = I18N.Plurals.Two,
              "sl 2 is two");
      Assert (I18N.Plurals.Cardinal ("sl", 3, 0, 0) = I18N.Plurals.Few,
              "sl 3 is few");
      Assert (I18N.Plurals.Cardinal ("sl", 5, 0, 0) = I18N.Plurals.Other,
              "sl 5 is other");
      Assert (I18N.Plurals.Cardinal ("sl", 1, 1, 5) = I18N.Plurals.Few,
              "sl 1.5 is few");
      Assert (I18N.Plurals.Cardinal ("pt", 0) = I18N.Plurals.One,
              "pt 0 follows the CLDR i=0..1 family");
      Assert (I18N.Plurals.Cardinal ("pt-BR", 0) = I18N.Plurals.One,
              "pt-BR falls back to pt plural rules");
      Assert (I18N.Plurals.Cardinal ("pt-PT", 0) = I18N.Plurals.Other,
              "pt-PT uses its exact regional plural rule");
      Assert (I18N.Plurals.Cardinal ("br", 2) = I18N.Plurals.Two,
              "br 2 is two");
      Assert (I18N.Plurals.Cardinal ("br", 3) = I18N.Plurals.Few,
              "br 3 is few");
      Assert (I18N.Plurals.Cardinal ("br", 1_000_000) = I18N.Plurals.Many,
              "br 1000000 is many");
      Assert (I18N.Plurals.Cardinal ("lv", 0) = I18N.Plurals.Zero,
              "lv 0 is zero");
      Assert (I18N.Plurals.Cardinal ("lv", 21) = I18N.Plurals.One,
              "lv 21 is one");
      Assert (I18N.Plurals.Cardinal ("he", 2) = I18N.Plurals.Two,
              "he 2 is two");
      Assert (I18N.Plurals.Cardinal ("kw", 0) = I18N.Plurals.Zero,
              "kw 0 is zero");
      Assert (I18N.Plurals.Cardinal ("kw", 23) = I18N.Plurals.Few,
              "kw 23 is few");
      Assert (I18N.Plurals.Cardinal ("kw", 21) = I18N.Plurals.Many,
              "kw 21 is many");
      Assert (I18N.Plurals.Cardinal ("mt", 2) = I18N.Plurals.Two,
              "mt 2 is two");
      Assert (I18N.Plurals.Cardinal ("mt", 11) = I18N.Plurals.Many,
              "mt 11 is many");
      Assert (I18N.Plurals.Cardinal ("shi", 3) = I18N.Plurals.Few,
              "shi 3 is few");
      Assert (I18N.Plurals.Cardinal ("da", 0, 1, 5) = I18N.Plurals.One,
              "da 0.5 is one through t != 0");
      Assert (I18N.Plurals.Cardinal ("is", 2, 1, 1) = I18N.Plurals.One,
              "is 2.1 is one through t mod 10");
      Assert (I18N.Plurals.Cardinal ("gv", 2, 1, 5) = I18N.Plurals.Many,
              "gv visible fractions are many");
   end Test_Plural_Cardinal;

   procedure Test_Plural_Ordinal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type I18N.Plurals.Plural_Category;
   begin
      Assert (I18N.Plurals.Ordinal ("en", 1) = I18N.Plurals.One, "1st -> one");
      Assert (I18N.Plurals.Ordinal ("en", 2) = I18N.Plurals.Two, "2nd -> two");
      Assert (I18N.Plurals.Ordinal ("en", 3) = I18N.Plurals.Few, "3rd -> few");
      Assert (I18N.Plurals.Ordinal ("en", 4) = I18N.Plurals.Other, "4th -> other");
      Assert (I18N.Plurals.Ordinal ("en", 11) = I18N.Plurals.Other,
              "11th -> other (teen exception)");
      Assert (I18N.Plurals.Ordinal ("en", 21) = I18N.Plurals.One, "21st -> one");
      Assert (I18N.Plurals.Ordinal ("de", 3) = I18N.Plurals.Other,
              "German ordinals are all other");
      Assert (I18N.Plurals.Ordinal ("fr", 1) = I18N.Plurals.One, "fr 1 -> one");
      Assert (I18N.Plurals.Ordinal ("fr", 2) = I18N.Plurals.Other, "fr 2 -> other");
      Assert (I18N.Plurals.Ordinal ("it", 8) = I18N.Plurals.Many, "it 8 -> many");
      Assert (I18N.Plurals.Ordinal ("it", 11) = I18N.Plurals.Many, "it 11 -> many");
      Assert (I18N.Plurals.Ordinal ("it", 5) = I18N.Plurals.Other, "it 5 -> other");
      Assert (I18N.Plurals.Ordinal ("az", 1) = I18N.Plurals.One,
              "az ordinal 1 -> one");
      Assert (I18N.Plurals.Ordinal ("az", 3) = I18N.Plurals.Few,
              "az ordinal 3 -> few");
      Assert (I18N.Plurals.Ordinal ("az", 0) = I18N.Plurals.Many,
              "az ordinal 0 -> many");
      Assert (I18N.Plurals.Ordinal ("blo", 0) = I18N.Plurals.Zero,
              "blo ordinal 0 -> zero");
      Assert (I18N.Plurals.Ordinal ("cy", 7) = I18N.Plurals.Zero,
              "cy ordinal 7 -> zero");
      Assert (I18N.Plurals.Ordinal ("cy", 5) = I18N.Plurals.Many,
              "cy ordinal 5 -> many");
      Assert (I18N.Plurals.Ordinal ("ka", 20) = I18N.Plurals.Many,
              "ka ordinal 20 -> many");
      Assert (I18N.Plurals.Ordinal ("kw", 24) = I18N.Plurals.One,
              "kw ordinal 24 -> one");
      Assert (I18N.Plurals.Ordinal ("lij", 88) = I18N.Plurals.Many,
              "lij ordinal 88 -> many");
      Assert (I18N.Plurals.Ordinal ("mk", 2) = I18N.Plurals.Two,
              "mk ordinal 2 -> two");
      Assert (I18N.Plurals.Ordinal ("or", 6) = I18N.Plurals.Many,
              "or ordinal 6 -> many");
      Assert (I18N.Plurals.Ordinal ("sv", 2) = I18N.Plurals.One,
              "sv ordinal 2 -> one");
      Assert (I18N.Plurals.Ordinal ("tk", 10) = I18N.Plurals.Few,
              "tk ordinal 10 -> few");
   end Test_Plural_Ordinal;

   procedure Test_Plural_Cardinal_Slavic_Arabic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use type I18N.Plurals.Plural_Category;
   begin
      --  Russian: one / few / many.
      Assert (I18N.Plurals.Cardinal ("ru", 1) = I18N.Plurals.One, "ru 1 one");
      Assert (I18N.Plurals.Cardinal ("ru", 21) = I18N.Plurals.One, "ru 21 one");
      Assert (I18N.Plurals.Cardinal ("ru", 2) = I18N.Plurals.Few, "ru 2 few");
      Assert (I18N.Plurals.Cardinal ("ru", 23) = I18N.Plurals.Few, "ru 23 few");
      Assert (I18N.Plurals.Cardinal ("ru", 5) = I18N.Plurals.Many, "ru 5 many");
      Assert (I18N.Plurals.Cardinal ("ru", 11) = I18N.Plurals.Many, "ru 11 many");
      Assert (I18N.Plurals.Cardinal ("ru", 12) = I18N.Plurals.Many, "ru 12 many");
      Assert (I18N.Plurals.Cardinal ("ru", 0) = I18N.Plurals.Many, "ru 0 many");
      Assert (I18N.Plurals.Cardinal ("uk", 1) = I18N.Plurals.One, "uk 1 one");
      Assert (I18N.Plurals.Cardinal ("uk", 3) = I18N.Plurals.Few, "uk 3 few");
      Assert (I18N.Plurals.Cardinal ("uk", 11) = I18N.Plurals.Many, "uk 11 many");

      --  Polish: one (=1) / few / many.
      Assert (I18N.Plurals.Cardinal ("pl", 1) = I18N.Plurals.One, "pl 1 one");
      Assert (I18N.Plurals.Cardinal ("pl", 2) = I18N.Plurals.Few, "pl 2 few");
      Assert (I18N.Plurals.Cardinal ("pl", 22) = I18N.Plurals.Few, "pl 22 few");
      Assert (I18N.Plurals.Cardinal ("pl", 5) = I18N.Plurals.Many, "pl 5 many");
      Assert (I18N.Plurals.Cardinal ("pl", 12) = I18N.Plurals.Many, "pl 12 many");
      Assert (I18N.Plurals.Cardinal ("pl", 21) = I18N.Plurals.Many, "pl 21 many");

      --  Czech: one / few (2..4) / other.
      Assert (I18N.Plurals.Cardinal ("cs", 1) = I18N.Plurals.One, "cs 1 one");
      Assert (I18N.Plurals.Cardinal ("cs", 3) = I18N.Plurals.Few, "cs 3 few");
      Assert (I18N.Plurals.Cardinal ("cs", 5) = I18N.Plurals.Other, "cs 5 other");
      Assert (I18N.Plurals.Cardinal ("ro", 0) = I18N.Plurals.Few, "ro 0 few");
      Assert (I18N.Plurals.Cardinal ("ro", 20) = I18N.Plurals.Other,
              "ro 20 other");
      Assert (I18N.Plurals.Cardinal ("lt", 22) = I18N.Plurals.Few, "lt 22 few");
      Assert (I18N.Plurals.Cardinal ("lt", 19) = I18N.Plurals.Other,
              "lt 19 other");
      Assert (I18N.Plurals.Cardinal ("sl", 102) = I18N.Plurals.Two,
              "sl 102 two");
      Assert (I18N.Plurals.Cardinal ("sl", 104) = I18N.Plurals.Few,
              "sl 104 few");

      --  Arabic exercises every category.
      Assert (I18N.Plurals.Cardinal ("ar", 0) = I18N.Plurals.Zero, "ar 0 zero");
      Assert (I18N.Plurals.Cardinal ("ar", 1) = I18N.Plurals.One, "ar 1 one");
      Assert (I18N.Plurals.Cardinal ("ar", 2) = I18N.Plurals.Two, "ar 2 two");
      Assert (I18N.Plurals.Cardinal ("ar", 3) = I18N.Plurals.Few, "ar 3 few");
      Assert (I18N.Plurals.Cardinal ("ar", 11) = I18N.Plurals.Many, "ar 11 many");
      Assert (I18N.Plurals.Cardinal ("ar", 100) = I18N.Plurals.Other, "ar 100 other");

      --  Romance / Germanic additions and CJK other-only.
      Assert (I18N.Plurals.Cardinal ("es", 1) = I18N.Plurals.One, "es 1 one");
      Assert (I18N.Plurals.Cardinal ("pt", 0) = I18N.Plurals.One, "pt 0 one");
      Assert (I18N.Plurals.Cardinal ("sv", 1) = I18N.Plurals.One, "sv 1 one");
      Assert (I18N.Plurals.Cardinal ("nb", 2) = I18N.Plurals.Other, "nb 2 other");
      Assert (I18N.Plurals.Cardinal ("fi", 1) = I18N.Plurals.One, "fi 1 one");
      Assert (I18N.Plurals.Cardinal ("tr", 2) = I18N.Plurals.Other, "tr 2 other");
      Assert (I18N.Plurals.Cardinal ("ja", 1) = I18N.Plurals.Other, "ja other-only");
      Assert (I18N.Plurals.Cardinal ("zh", 5) = I18N.Plurals.Other, "zh other-only");
   end Test_Plural_Cardinal_Slavic_Arabic;

   procedure Test_Plural_All_Category_Branches
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;

      function Count (Value : String) return String is
      begin
         I18N.Arguments.Set (Args, "count", Value);
         return Rendered (Runtime, "ar", "items", Args);
      end Count;

      function Slovene_Count (Value : String) return String is
      begin
         I18N.Arguments.Set (Args, "count", Value);
         return Rendered (Runtime, "sl", "items", Args);
      end Slovene_Count;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "ar.items = ""{count, plural, zero {zero/#} one {one/#} "
         & "two {two/#} few {few/#} many {many/#} other {other/#}}"""
         & ASCII.LF
         & "sl.items = ""{count, plural, one {one/#} two {two/#} "
         & "few {few/#} other {other/#}}"""
         & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "plural with all category branches should load");

      Assert (Count ("0") = "zero/0", "zero branch renders");
      Assert (Count ("1") = "one/1", "one branch renders");
      Assert (Count ("2") = "two/2", "two branch renders");
      Assert (Count ("3") = "few/3", "few branch renders");
      Assert (Count ("11") = "many/11", "many branch renders");
      Assert (Count ("100") = "other/100", "other branch renders");
      Assert (Slovene_Count ("1") = "one/1", "sl one branch renders");
      Assert (Slovene_Count ("2") = "two/2", "sl two branch renders");
      Assert (Slovene_Count ("3") = "few/3", "sl few branch renders");
      Assert (Slovene_Count ("5") = "other/5", "sl other branch renders");
   end Test_Plural_All_Category_Branches;

   ---------------------------------------------------------------------------
   --  8. Bounded render API.
   ---------------------------------------------------------------------------

   procedure Test_Render_Into_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Buffer  : String (1 .. 32);
      Last    : Natural;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.hi = ""Hi {name}""" & ASCII.LF, Result);
      I18N.Arguments.Set (Args, "name", "Ada");

      I18N.Runtime.Render_Into
        (Runtime, "en", "hi", Args, Buffer, Last, Status);

      Assert (Status = I18N.Result.Success, "bounded render succeeds");
      Assert (Last = 6, "Last is the final written index");
      Assert (Buffer (1 .. Last) = "Hi Ada", "bounded render writes the output");
   end Test_Render_Into_Success;

   procedure Test_Render_Into_Overflow
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Buffer  : String (1 .. 3);
      Last    : Natural;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.hi = ""Hello""" & ASCII.LF, Result);

      I18N.Runtime.Render_Into
        (Runtime, "en", "hi", Args, Buffer, Last, Status);

      Assert (Status = I18N.Result.Buffer_Overflow,
              "an output longer than the buffer reports Buffer_Overflow");
      Assert (Last = 3, "overflow writes the prefix that fits");
      Assert (Buffer (1 .. 3) = "Hel", "overflow leaves the partial prefix");
   end Test_Render_Into_Overflow;

   procedure Test_Render_Into_Missing_Key
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Buffer  : String (1 .. 16);
      Last    : Natural;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base", "en.hi = ""Hi""" & ASCII.LF, Result);

      I18N.Runtime.Render_Into
        (Runtime, "en", "absent", Args, Buffer, Last, Status);

      Assert (Status = I18N.Result.Missing_Key,
              "a missing key reports Missing_Key from Render_Into");
      Assert (Last = 0, "no partial output on a non-overflow failure");
   end Test_Render_Into_Missing_Key;

   procedure Test_Render_Into_Complex_Construct
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Buffer  : String (1 .. 32);
      Last    : Natural;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.place = ""You came {rank, selectordinal, one {#st} two {#nd} "
         & "few {#rd} other {#th}}""" & ASCII.LF,
         Result);

      I18N.Arguments.Set_Natural (Args, "rank", 22);
      I18N.Runtime.Render_Into
        (Runtime, "en", "place", Args, Buffer, Last, Status);

      Assert (Status = I18N.Result.Success,
              "bounded render of a selectordinal succeeds");
      Assert (Buffer (1 .. Last) = "You came 22nd",
              "bounded render selects the locale-correct ordinal branch");
   end Test_Render_Into_Complex_Construct;

   procedure Test_Currency_Rendering
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Currency_Invalid_Input
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      VR      : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_currency",
           "en.price = ""{amount, currency, usd}""" & ASCII.LF);
      Bad_Skeleton : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_number_skeleton",
           "en.price = ""{amount, number, ::bogus}""" & ASCII.LF);
      Bad_Integer_Width : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_number_integer_width",
           "en.price = ""{amount, number, ::integer-width/###}"""
           & ASCII.LF);
      Bad_Currency_Option : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_option",
           "en.price = ""{amount, currency, USD/bogus}""" & ASCII.LF);
      Bad_Currency_Skeleton_Token
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_skeleton_token",
           "en.price = ""{amount, number, ::currency/USD unit-width-medium}"""
           & ASCII.LF);
      Bad_Currency_Skeleton_Precision
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_skeleton_precision",
           "en.price = ""{amount, number, "
           & "::currency/USD precision-currency-random}"""
           & ASCII.LF);
      Bad_Currency_Skeleton_Code
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_skeleton_code",
           "en.price = ""{amount, number, ::currency/usd}"""
           & ASCII.LF);
      Bad_Currency_Skeleton_Duplicate
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_skeleton_duplicate",
           "en.price = ""{amount, number, ::currency/USD ::currency/EUR}"""
           & ASCII.LF);
      Bad_Unit_Width : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
         ("bad_currency_unit_width",
           "en.price = ""{amount, currency, USD/unit-width-medium}"""
           & ASCII.LF);
      Bad_Minor_Units : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("minor_units",
           "en.price = ""{amount, currency, KWD}""" & ASCII.LF);

      procedure Expect_Invalid (Value : String; Message : String) is
      begin
         I18N.Arguments.Set (Args, "amount", Value);
         Assert (Status_Of (Runtime, "en", "price", Args) =
                   I18N.Result.Invalid_Argument,
                 Message);
      end Expect_Invalid;
   begin
      Assert (not VR.Valid,
              "currency codes must be three uppercase ASCII letters");
      Assert (not Bad_Skeleton.Valid,
              "unsupported number skeletons are rejected");
      Assert (not Bad_Integer_Width.Valid,
              "integer-width skeletons require at least one zero digit");
      Assert (not Bad_Currency_Option.Valid,
              "unsupported currency display options are rejected");
      Assert (not Bad_Currency_Skeleton_Token.Valid,
              "unsupported separate currency skeleton tokens are rejected");
      Assert (not Bad_Currency_Skeleton_Precision.Valid,
              "unsupported currency precision skeletons are rejected");
      Assert (not Bad_Currency_Skeleton_Code.Valid,
              "currency skeleton codes must be uppercase ISO codes");
      Assert (not Bad_Currency_Skeleton_Duplicate.Valid,
              "duplicate currency skeleton code tokens are rejected");
      Assert (not Bad_Unit_Width.Valid,
              "unsupported currency unit-width options are rejected");
      Assert (Bad_Minor_Units.Valid,
              "known three-minor-unit currencies are accepted");

      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.price = ""{amount, currency, USD}""" & ASCII.LF
         & "en.clf_price = ""{amount, currency, CLF}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "valid currency catalog should load");

      Expect_Invalid ("12.345", "too many fractional digits are invalid");
      I18N.Arguments.Set (Args, "amount", "12.34567");
      Assert (Status_Of (Runtime, "en", "clf_price", Args) =
                I18N.Result.Invalid_Argument,
              "four-minor-unit currencies reject five fractional digits");
      Expect_Invalid ("", "empty currency amount is invalid");
      Expect_Invalid ("+", "sign-only currency amount is invalid");
      Expect_Invalid (".99", "currency amount requires an integer part");
      Expect_Invalid ("12.", "currency amount requires fractional digits");
      Expect_Invalid ("12,34", "currency amount rejects comma decimal input");
      Expect_Invalid ("1.2.3", "currency amount rejects duplicate decimals");
      Expect_Invalid ("1e3", "currency amount rejects exponent notation");
      Expect_Invalid ("12 USD", "currency amount rejects unit suffix text");
      Expect_Invalid ("-12.345", "negative amounts still obey minor units");
      Expect_Invalid ("--12", "currency amount rejects duplicate signs");

      I18N.Arguments.Clear (Args);
      Assert (Status_Of (Runtime, "en", "price", Args) =
                I18N.Result.Missing_Argument,
              "missing currency amount maps to Missing_Argument");
   end Test_Currency_Invalid_Input;

   procedure Test_Number_Rendering
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Number_Invalid_Input
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Bad_Compound : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_compound",
           "en.total = ""{value, number, ::percent bogus}""" & ASCII.LF);
      Bad_Scale_Zero : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_scale_zero",
           "en.total = ""{value, number, ::scale/0}""" & ASCII.LF);
      Bad_Scale_Text : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_scale_text",
           "en.total = ""{value, number, ::scale/x}""" & ASCII.LF);
      Bad_Scale_Decimal_Zero
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_scale_decimal_zero",
           "en.total = ""{value, number, ::scale/0.0}""" & ASCII.LF);
      Bad_Scale_Decimal_Syntax
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_scale_decimal_syntax",
           "en.total = ""{value, number, ::scale/1.2.3}""" & ASCII.LF);
      Bad_Integer_Width : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_integer_width",
           "en.total = ""{value, number, ::integer-width/+00x}"""
           & ASCII.LF);
      Bad_Integer_Width_Star
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_integer_width_star",
           "en.total = ""{value, number, ::integer-width/*00x}"""
           & ASCII.LF);
      Bad_Notation : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_notation",
           "en.total = ""{value, number, ::notation-compact-medium}"""
           & ASCII.LF);
      Bad_Rounding : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_rounding",
           "en.total = ""{value, number, ::rounding-mode-random}"""
           & ASCII.LF);
      Bad_Fraction_Range_Order
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_fraction_range_order",
           "en.total = ""{value, number, ::precision-fraction/3-2}"""
           & ASCII.LF);
      Bad_Fraction_Range_Syntax
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_fraction_range_syntax",
           "en.total = ""{value, number, ::precision-fraction/1--2}"""
           & ASCII.LF);
      Bad_Fraction_Range_Limit
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_fraction_range_limit",
           "en.total = ""{value, number, ::precision-fraction/0-10}"""
           & ASCII.LF);
      Bad_Significant_Range_Zero
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_significant_range_zero",
           "en.total = ""{value, number, ::precision-significant/0-2}"""
           & ASCII.LF);
      Bad_Significant_Range_Order
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_significant_range_order",
           "en.total = ""{value, number, ::precision-significant/4-2}"""
           & ASCII.LF);
      Bad_Significant_Range_Syntax
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_significant_range_syntax",
           "en.total = ""{value, number, ::precision-significant/1-x}"""
           & ASCII.LF);
      Bad_Sign_Accounting : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_sign_accounting",
           "en.total = ""{value, number, ::sign-accounting-sometimes}"""
           & ASCII.LF);
      Bad_Trailing_Zero : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_trailing_zero",
           "en.total = ""{value, number, ::trailing-zero-display/random}"""
           & ASCII.LF);
      Bad_Rounding_Increment_Zero
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_rounding_increment_zero",
           "en.total = ""{value, number, ::rounding-increment/0}"""
           & ASCII.LF);
      Bad_Rounding_Increment_Syntax
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_rounding_increment_syntax",
           "en.total = ""{value, number, ::rounding-increment/1.2.3}"""
           & ASCII.LF);
      Bad_Rounding_Increment_Empty
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_rounding_increment_empty",
           "en.total = ""{value, number, ::rounding-increment/}"""
           & ASCII.LF);
      Bad_Precision_Increment_Zero
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_precision_increment_zero",
           "en.total = ""{value, number, ::precision-increment/0}"""
           & ASCII.LF);
      Bad_Precision_Increment_Syntax
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_precision_increment_syntax",
           "en.total = ""{value, number, ::precision-increment/1.2.3}"""
           & ASCII.LF);
      Bad_Precision_Increment_Empty
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_number_precision_increment_empty",
           "en.total = ""{value, number, ::precision-increment/}"""
           & ASCII.LF);

      procedure Expect_Invalid (Value : String; Message : String) is
      begin
         I18N.Arguments.Set (Args, "value", Value);
         Assert (Status_Of (Runtime, "en", "total", Args) =
                   I18N.Result.Invalid_Argument,
                 Message);
      end Expect_Invalid;
   begin
      Assert (not Bad_Compound.Valid,
              "unsupported compound number skeleton tokens are rejected");
      Assert (not Bad_Scale_Zero.Valid,
              "zero number skeleton scales are rejected");
      Assert (not Bad_Scale_Text.Valid,
              "non-numeric number skeleton scales are rejected");
      Assert (not Bad_Scale_Decimal_Zero.Valid,
              "zero decimal number skeleton scales are rejected");
      Assert (not Bad_Scale_Decimal_Syntax.Valid,
              "malformed decimal number skeleton scales are rejected");
      Assert (not Bad_Integer_Width.Valid,
              "malformed integer-width number skeletons are rejected");
      Assert (not Bad_Integer_Width_Star.Valid,
              "malformed starred integer-width skeletons are rejected");
      Assert (not Bad_Notation.Valid,
              "unsupported notation skeletons are rejected");
      Assert (not Bad_Rounding.Valid,
              "unsupported rounding-mode skeletons are rejected");
      Assert (not Bad_Fraction_Range_Order.Valid,
              "descending precision-fraction ranges are rejected");
      Assert (not Bad_Fraction_Range_Syntax.Valid,
              "malformed precision-fraction ranges are rejected");
      Assert (not Bad_Fraction_Range_Limit.Valid,
              "oversized precision-fraction ranges are rejected");
      Assert (not Bad_Significant_Range_Zero.Valid,
              "zero-minimum precision-significant ranges are rejected");
      Assert (not Bad_Significant_Range_Order.Valid,
              "descending precision-significant ranges are rejected");
      Assert (not Bad_Significant_Range_Syntax.Valid,
              "malformed precision-significant ranges are rejected");
      Assert (not Bad_Sign_Accounting.Valid,
              "unsupported sign-accounting skeletons are rejected");
      Assert (not Bad_Trailing_Zero.Valid,
              "unsupported trailing-zero-display skeletons are rejected");
      Assert (not Bad_Rounding_Increment_Zero.Valid,
              "zero rounding-increment skeletons are rejected");
      Assert (not Bad_Rounding_Increment_Syntax.Valid,
              "malformed rounding-increment skeletons are rejected");
      Assert (not Bad_Rounding_Increment_Empty.Valid,
              "empty rounding-increment skeletons are rejected");
      Assert (not Bad_Precision_Increment_Zero.Valid,
              "zero precision-increment skeletons are rejected");
      Assert (not Bad_Precision_Increment_Syntax.Valid,
              "malformed precision-increment skeletons are rejected");
      Assert (not Bad_Precision_Increment_Empty.Valid,
              "empty precision-increment skeletons are rejected");

      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.total = ""{value, number}""" & ASCII.LF
         & "en.spellout = ""{value, number, ::spellout}""" & ASCII.LF
         & "en.ordinal_words = ""{value, number, ::ordinal-words}"""
         & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "valid number catalog should load");

      Expect_Invalid ("12,345.67",
                      "grouped input is rejected; grouping is output-only");
      Expect_Invalid ("", "empty number text is invalid");
      Expect_Invalid ("+", "sign-only number text is invalid");
      Expect_Invalid (".5", "number text requires an integer part");
      Expect_Invalid ("12.", "empty fractional part is invalid");
      Expect_Invalid ("1.2.3", "duplicate decimal points are invalid");
      Expect_Invalid ("1e3", "exponent notation is invalid");
      Expect_Invalid ("12 345", "space grouping in input is invalid");
      Expect_Invalid ("12a", "alphabetic suffixes are invalid");

      I18N.Arguments.Set (Args, "value", "1.5");
      Assert (Rendered (Runtime, "en", "spellout", Args) =
                "one point five",
              "spellout number skeleton accepts decimal input");
      Assert (Status_Of (Runtime, "en", "ordinal_words", Args) =
                I18N.Result.Invalid_Argument,
              "ordinal-word number skeleton rejects decimal input");
      I18N.Arguments.Set (Args, "value", "1000000000");
      Assert (Status_Of (Runtime, "en", "spellout", Args) =
                I18N.Result.Invalid_Argument,
              "spellout number skeleton rejects values beyond the supported range");

      I18N.Arguments.Clear (Args);
      Assert (Status_Of (Runtime, "en", "total", Args) =
                I18N.Result.Missing_Argument,
              "missing number value maps to Missing_Argument");
   end Test_Number_Invalid_Input;

   procedure Test_Date_Time_Rendering
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Date_Time_Invalid_Input
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Bad_Style : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_date_style",
           "en.d = ""{day, date, full}""" & ASCII.LF);
      Bad_Skeleton : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_date_skeleton",
           "en.d = ""{day, date, ::y%}""" & ASCII.LF);
      Bad_Quoted_Skeleton : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_date_quoted_skeleton",
           "en.d = ""{day, date, ::yyyy'-'MM'-dd}""" & ASCII.LF);
      Bad_Date_Empty_Skeleton
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_date_empty_skeleton",
           "en.d = ""{day, date, ::}""" & ASCII.LF);
      Bad_Time_Unknown_Style
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_time_unknown_style",
           "en.t = ""{clock, time, narrow}""" & ASCII.LF);
      Bad_Date_Time_Unknown_Style
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_datetime_unknown_style",
           "en.dt = ""{instant, datetime, tiny}""" & ASCII.LF);
      Bad_Date_Empty_Zone
        : constant I18N.Runtime.Catalog_Validation_Result :=
        I18N.Runtime.Validate_Catalog_Text
          ("bad_date_empty_zone",
           "en.d = ""{day, date, long, }""" & ASCII.LF);

      procedure Expect_Invalid
        (Key     : String;
         Name    : String;
         Value   : String;
         Message : String) is
      begin
         I18N.Arguments.Set (Args, Name, Value);
         Assert (Status_Of (Runtime, "en", Key, Args) =
                   I18N.Result.Invalid_Argument,
                 Message);
      end Expect_Invalid;
   begin
      Assert (Bad_Style.Valid,
              "full date style is accepted");
      Assert (not Bad_Skeleton.Valid,
              "unsupported date/time skeleton fields are rejected");
      Assert (not Bad_Quoted_Skeleton.Valid,
              "unterminated quoted date/time skeletons are rejected");
      Assert (not Bad_Date_Empty_Skeleton.Valid,
              "empty date/time skeletons are rejected");
      Assert (not Bad_Time_Unknown_Style.Valid,
              "unsupported time styles are rejected");
      Assert (not Bad_Date_Time_Unknown_Style.Valid,
              "unsupported datetime styles are rejected");
      Assert (not Bad_Date_Empty_Zone.Valid,
              "date format rejects empty zone options");

      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.d = ""{day, date}""" & ASCII.LF
         & "en.t = ""{clock, time}""" & ASCII.LF
         & "en.dt = ""{instant, datetime, short, UTC}""" & ASCII.LF
         & "en.tz = ""{instant, time, long, +02:00}""" & ASCII.LF
         & "en.date_bad_time_field = ""{day, date, ::yMdH}""" & ASCII.LF
         & "en.time_bad_date_field = ""{clock, time, ::Hmsd}""" & ASCII.LF
         & "en.bad_zone_name = ""{instant, datetime, short, Not/A_Zone}"""
         & ASCII.LF
         & "en.bad_zone_offset = ""{instant, datetime, short, +24:00}"""
         & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "valid date/time catalog should load");

      Expect_Invalid ("d", "day", "2023-02-29",
                      "invalid calendar date is rejected");
      Expect_Invalid ("d", "day", "2024/02/29",
                      "non-ISO date syntax is rejected");
      Expect_Invalid ("d", "day", "2024-13-01",
                      "out-of-range month is rejected");
      Expect_Invalid ("d", "day", "2024-00-10",
                      "zero month is rejected");
      Expect_Invalid ("d", "day", "2024-01-00",
                      "zero day is rejected");
      Expect_Invalid ("d", "day", "2024-2-9",
                      "unpadded date fields are rejected");
      Expect_Invalid ("d", "day", "2024-02-29T09:05",
                      "date instant input requires an explicit offset");

      Expect_Invalid ("t", "clock", "24:00",
                      "invalid hour is rejected");
      Expect_Invalid ("t", "clock", "23:60",
                      "invalid minute is rejected");
      Expect_Invalid ("t", "clock", "23:59:60",
                      "invalid second is rejected");
      Expect_Invalid ("t", "clock", "9:05",
                      "unpadded time fields are rejected");
      Expect_Invalid ("t", "clock", "09:05 PM",
                      "12-hour clock suffixes are rejected");
      Expect_Invalid ("t", "clock", "09:05.1",
                      "fractional minutes are rejected");
      Expect_Invalid ("t", "clock", "09:05:07.",
                      "empty fractional seconds are rejected");
      Expect_Invalid ("t", "clock", "09:05:07.1234567890",
                      "oversized fractional seconds are rejected");

      Expect_Invalid ("dt", "instant", "2024-02-29T09:05",
                      "datetime input requires an explicit offset");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+2:00",
                      "single-hour colon offset is rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+2",
                      "unpadded compact zone hours are rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+2360",
                      "out-of-range compact zone offset minute is rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+24",
                      "out-of-range compact zone offset hour is rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+02:00:60",
                      "out-of-range zone offset seconds is rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05.1Z",
                      "instant fractional minutes are rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05:07.Z",
                      "instant empty fractional seconds are rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05:07.1234567890Z",
                      "instant oversized fractional seconds are rejected");
      Expect_Invalid ("dt", "instant", "2024-02-29T09:05+02:60",
                      "out-of-range zone offset minute is rejected");
      Expect_Invalid ("tz", "instant", "2024-02-30T09:05:00Z",
                      "invalid instant date is rejected");
      Expect_Invalid ("date_bad_time_field", "day", "2024-02-29",
                      "date skeletons reject time-only fields");
      Expect_Invalid ("time_bad_date_field", "clock", "09:05:00",
                      "time skeletons reject date-only fields");
      Expect_Invalid ("bad_zone_name", "instant",
                      "2024-02-29T09:05:00Z",
                      "unknown datetime target zones are invalid arguments");
      Expect_Invalid ("bad_zone_offset", "instant",
                      "2024-02-29T09:05:00Z",
                      "out-of-range datetime target offsets are invalid");

      I18N.Arguments.Clear (Args);
      Assert (Status_Of (Runtime, "en", "d", Args) =
                I18N.Result.Missing_Argument,
              "missing date value maps to Missing_Argument");
   end Test_Date_Time_Invalid_Input;

   procedure Test_Runtime_Data_Overrides
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Normalized_CLDR_Runtime_Data
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Ecosystem_Formatters
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Display_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Emoji_Annotations
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Calendar_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Person_Names
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Spellout
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Normalization
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Calendar_Math
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   procedure Test_Segmentation
     (T : in out AUnit.Test_Cases.Test_Case'Class) is separate;

   ---------------------------------------------------------------------------
   --  9. Compiled / indexed path preservation.
   ---------------------------------------------------------------------------

   procedure Test_Compiled_Path_Is_Stable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.items = ""{count, plural, one {# item} other {# items}}"""
         & ASCII.LF,
         Result);

      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "items", Args) = "1 item",
              "compiled plural entry renders the one branch");

      I18N.Arguments.Set (Args, "count", "5");
      --  Re-rendering reuses the stored compiled entry deterministically.
      Assert (Rendered (Runtime, "en", "items", Args) = "5 items",
              "re-rendering the compiled entry stays deterministic");

      Assert (Status_Of (Runtime, "en", "items", Args) = I18N.Result.Success,
              "compiled-path render status is Success");
   end Test_Compiled_Path_Is_Stable;

   procedure Test_Ordinal_Render_Is_Locale_Correct
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;

      function Rank (Value : String) return String is
      begin
         I18N.Arguments.Set (Args, "rank", Value);
         return Rendered (Runtime, "en", "place", Args);
      end Rank;

      function Rank_In (Locale : String; Value : String) return String is
      begin
         I18N.Arguments.Set (Args, "rank", Value);
         return Rendered (Runtime, Locale, "place", Args);
      end Rank_In;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.place = ""{rank, selectordinal, one {#st} two {#nd} few {#rd} "
         & "other {#th}}""" & ASCII.LF
         & "bn.place = ""{rank, selectordinal, one {one} two {two} "
         & "few {few} many {many} other {other}}""" & ASCII.LF
         & "hi.place = ""{rank, selectordinal, one {one} two {two} "
         & "few {few} many {many} other {other}}""" & ASCII.LF,
         Result);

      --  The renderer now consults I18N.Plurals for the locale's CLDR ordinal
      --  rules instead of a hardcoded 1/2/3 mapping.
      Assert (Rank ("1") = "1st", "1 -> 1st");
      Assert (Rank ("2") = "2nd", "2 -> 2nd");
      Assert (Rank ("3") = "3rd", "3 -> 3rd");
      Assert (Rank ("4") = "4th", "4 -> 4th");
      Assert (Rank ("11") = "11th", "11 -> 11th (teen exception)");
      Assert (Rank ("12") = "12th", "12 -> 12th");
      Assert (Rank ("13") = "13th", "13 -> 13th");
      Assert (Rank ("21") = "21st", "21 -> 21st (was wrongly 21th before)");
      Assert (Rank ("22") = "22nd", "22 -> 22nd");
      Assert (Rank ("23") = "23rd", "23 -> 23rd");
      Assert (Rank ("101") = "101st", "101 -> 101st");
      Assert (Rank_In ("bn", "1") = "one",
              "Bengali ordinal 1 uses one");
      Assert (Rank_In ("bn", "2") = "two",
              "Bengali ordinal 2 uses two");
      Assert (Rank_In ("bn", "4") = "few",
              "Bengali ordinal 4 uses few");
      Assert (Rank_In ("bn", "6") = "many",
              "Bengali ordinal 6 uses many");
      Assert (Rank_In ("hi", "1") = "one",
              "Hindi ordinal 1 uses one");
      Assert (Rank_In ("hi", "2") = "two",
              "Hindi ordinal 2 uses two");
      Assert (Rank_In ("hi", "4") = "few",
              "Hindi ordinal 4 uses few");
      Assert (Rank_In ("hi", "6") = "many",
              "Hindi ordinal 6 uses many");
      Assert (Rank_In ("hi", "5") = "other",
              "Hindi ordinal 5 uses other");
   end Test_Ordinal_Render_Is_Locale_Correct;

   procedure Test_Plural_Render_Uses_Locale_Rules
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
   begin
      --  French cardinal: 0 and 1 are "one"; everything else is "other".
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "fr.items = ""{count, plural, one {un item} other {# items}}"""
         & ASCII.LF
         & "cy.items = ""{count, plural, zero {zero} one {one} two {two} "
         & "few {few} many {many} other {other}}"""
         & ASCII.LF
         & "sr.items = ""{count, plural, one {one} few {few} other {other}}"""
         & ASCII.LF
         & "hi.items = ""{count, plural, one {one} other {other}}"""
         & ASCII.LF,
         Result);

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "fr", "items", Args) = "un item",
              "fr cardinal 0 uses the one branch");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "fr", "items", Args) = "2 items",
              "fr cardinal 2 uses the other branch");

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "cy", "items", Args) = "zero",
              "Welsh cardinal 0 uses the zero branch");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "cy", "items", Args) = "two",
              "Welsh cardinal 2 uses the two branch");
      I18N.Arguments.Set (Args, "count", "3");
      Assert (Rendered (Runtime, "cy", "items", Args) = "few",
              "Welsh cardinal 3 uses the few branch");
      I18N.Arguments.Set (Args, "count", "6");
      Assert (Rendered (Runtime, "cy", "items", Args) = "many",
              "Welsh cardinal 6 uses the many branch");

      I18N.Arguments.Set (Args, "count", "1.1");
      Assert (Rendered (Runtime, "sr", "items", Args) = "one",
              "Serbian decimal fraction ending in 1 uses one");
      I18N.Arguments.Set (Args, "count", "1.2");
      Assert (Rendered (Runtime, "sr", "items", Args) = "few",
              "Serbian decimal fraction ending in 2 uses few");
      I18N.Arguments.Set (Args, "count", "1.5");
      Assert (Rendered (Runtime, "sr", "items", Args) = "other",
              "Serbian decimal fraction ending in 5 uses other");

      I18N.Arguments.Set (Args, "count", "0.5");
      Assert (Rendered (Runtime, "hi", "items", Args) = "one",
              "Hindi cardinal i = 0 uses one for visible fractions");
      I18N.Arguments.Set (Args, "count", "1.0");
      Assert (Rendered (Runtime, "hi", "items", Args) = "one",
              "Hindi cardinal n = 1 includes 1.0");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "hi", "items", Args) = "other",
              "Hindi cardinal 2 uses other");
   end Test_Plural_Render_Uses_Locale_Rules;

   procedure Test_Localized_Select_Plural_Corpus
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Result  : I18N.Runtime.Load_Result;
      Target  : String (1 .. 80) := [others => Character'Val (0)];
      Last    : Natural := 0;
      Status  : I18N.Result.Render_Status;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "localized-corpus",
         "en.summary = ""{count, plural, one {{channel, select, "
         & "email {one email for {amount, number}} "
         & "sms {one sms at {clock, time, short}} "
         & "other {one alert}}} other {{channel, select, "
         & "email {# emails for {amount, currency, USD}} "
         & "other {# alerts on {day, date, long}}}}}""" & ASCII.LF
         & "fr.summary = ""{count, plural, one {{channel, select, "
         & "email {un courriel pour {amount, currency, EUR}} "
         & "other {une alerte}}} other {{channel, select, "
         & "email {# courriels pour {amount, number}} "
         & "other {# alertes a {clock, time, short}}}}}""" & ASCII.LF
         & "ru.summary = ""{count, plural, one {one {count, number}} "
         & "few {few {amount, number}} many {many {day, date, long}} "
         & "other {other {clock, time, short}}}""" & ASCII.LF
         & "ar.summary = ""{count, plural, zero {zero {count, number}} "
         & "one {one {amount, number}} two {two {count, number}} "
         & "few {few {amount, currency, USD}} "
         & "many {many {day, date, long}} "
         & "other {other {clock, time, short}}}""" & ASCII.LF,
         Result);
      Assert (Result.Status = I18N.Runtime.Loaded,
              "localized select/plural corpus should load");

      I18N.Arguments.Set (Args, "amount", "1234.5");
      I18N.Arguments.Set (Args, "day", "2024-02-29");
      I18N.Arguments.Set (Args, "clock", "09:05:07");
      I18N.Arguments.Set (Args, "channel", "email");

      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "summary", Args) =
                "one email for 1,234.5",
              "English one branch nests select and number formatting");

      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "en", "summary", Args) =
                "2 emails for $1,234.50",
              "English other branch nests select and currency formatting");

      I18N.Arguments.Set (Args, "channel", "push");
      Assert (Rendered (Runtime, "en", "summary", Args) =
                "2 alerts on February 29, 2024",
              "English select fallback nests long date formatting");

      I18N.Arguments.Set (Args, "channel", "sms");
      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "en", "summary", Args) =
                "one sms at 09:05",
              "English select branch nests short time formatting");

      I18N.Arguments.Set (Args, "channel", "email");
      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "fr", "summary", Args) =
                "un courriel pour 1" & U (16#202F#) & "234,50 "
                & U (16#20AC#),
              "French cardinal zero uses one branch with currency formatting");

      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "fr", "summary", Args) =
                "2 courriels pour 1" & U (16#202F#) & "234,5",
              "French other branch nests locale number formatting");

      I18N.Arguments.Set (Args, "count", "1");
      Assert (Rendered (Runtime, "ru", "summary", Args) = "one 1",
              "Russian one branch is selected");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "ru", "summary", Args) =
                "few 1" & U (16#A0#) & "234,5",
              "Russian few branch nests number formatting");
      I18N.Arguments.Set (Args, "count", "5");
      Assert (Rendered (Runtime, "ru", "summary", Args) =
                --  CLDR ru long is "d MMMM y 'г'." -- the year carries a
                --  "г." (god, year) suffix and no point after the day.
                --  CLDR ru long is "d MMMM y\u202F'г'." -- the year carries a
                --  "г." (year) suffix, joined by a narrow no-break space, and
                --  there is no point after the day.
                "many 29 " & U (16#444#) & U (16#435#) & U (16#432#)
                & U (16#440#) & U (16#430#) & U (16#43B#)
                & U (16#44F#) & " 2024" & U (16#202F#) & U (16#433#) & ".",
              "Russian many branch nests localized long date formatting");

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "ar", "summary", Args) =
                "zero " & U (16#660#),
              "Arabic zero branch nests localized number formatting");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "ar", "summary", Args) =
                "two " & U (16#662#),
              "Arabic two branch nests localized number formatting");
      I18N.Arguments.Set (Args, "count", "3");
      Assert (Rendered (Runtime, "ar", "summary", Args) =
                "few " & U (16#661#) & U (16#66C#) & U (16#662#)
                & U (16#663#) & U (16#664#) & U (16#66B#)
                & U (16#665#) & U (16#660#) & " $",
              "Arabic few branch nests localized currency formatting");

      I18N.Runtime.Render_Into
        (Runtime, "ar", "summary", Args, Target, Last, Status);
      Assert (Status = I18N.Result.Success,
              "bounded localized corpus render succeeds");
      Assert (Target (1 .. Last) =
                "few " & U (16#661#) & U (16#66C#) & U (16#662#)
                & U (16#663#) & U (16#664#) & U (16#66B#)
                & U (16#665#) & U (16#660#) & " $",
              "bounded localized corpus render matches materialized output");
   end Test_Localized_Select_Plural_Corpus;

   ---------------------------------------------------------------------------
   --  Registration.
   ---------------------------------------------------------------------------

   overriding function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N runtime feature tests");
   end Name;

   overriding procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Load_Text_Adds_Shard'Access,
        "Load_Text layers catalog shards");
      Register_Routine (T, Test_Load_Text_Honors_Default_Locale'Access,
        "Load_Text adopts default_locale for a standalone runtime");
      Register_Routine (T, Test_Load_File_Layers_Shards'Access,
        "Load_File layers catalog shards onto a base catalog");
      Register_Routine (T, Test_Load_File_Missing_Is_Reported'Access,
        "a missing shard file is reported without corrupting the runtime");
      Register_Routine (T, Test_Reject_Duplicates_Is_Nondestructive'Access,
        "Reject_Duplicates leaves prior entries unchanged");
      Register_Routine (T, Test_Keep_First_Policy'Access,
        "Keep_First keeps the existing entry");
      Register_Routine (T, Test_Override_Previous_Policy'Access,
        "Override_Previous replaces the existing entry");
      Register_Routine (T, Test_Validate_Text_Accepts_Good_Catalog'Access,
        "Validate_Catalog_Text accepts a well-formed catalog");
      Register_Routine (T, Test_Validate_Text_Rejects_Bad_Message'Access,
        "Validate_Catalog_Text rejects an invalid ICU message");
      Register_Routine (T, Test_Validate_Text_Rejects_Duplicate'Access,
        "Validate_Catalog_Text rejects duplicate keys within input");
      Register_Routine (T, Test_Diagnostics_Report_Line_Numbers'Access,
        "load/validation diagnostics name the offending line number");
      Register_Routine (T, Test_Validation_Does_Not_Touch_Runtime'Access,
        "validation failure does not invalidate an existing runtime");
      Register_Routine (T, Test_Validate_Rejects_Bad_Locale_And_Key'Access,
        "validation rejects malformed locales and keys but allows dotted keys");
      Register_Routine (T, Test_Validate_File'Access,
        "Validate_Catalog_File validates files and reports missing files");
      Register_Routine (T, Test_Binary_Catalogs'Access,
        "versioned binary catalogs validate, initialize, and load deterministically");
      Register_Routine (T, Test_Resolve_Found_Through_Fallback'Access,
        "Resolve finds keys through the locale fallback chain");
      Register_Routine (T, Test_Locale_Canonicalization_And_Aliases'Access,
        "locale canonicalization and aliases feed fallback resolution");
      Register_Routine (T, Test_Resolve_Missing_And_Invalid'Access,
        "Resolve reports Missing_Key and Runtime_Invalid");
      Register_Routine (T, Test_Locale_Fallback_Formatting_Matrix'Access,
        "locale fallback matrix preserves formatter behavior");
      Register_Routine (T, Test_Integer_Helper_Formatting'Access,
        "Set_Integer formats strict decimals");
      Register_Routine (T, Test_Natural_Helper_Formatting'Access,
        "Set_Natural formats strict decimals");
      Register_Routine (T, Test_Boolean_Helper_Formatting'Access,
        "Set_Boolean formats true/false");
      Register_Routine (T, Test_Generalized_Select'Access,
        "generalized select branches dispatch and fall back to other");
      Register_Routine (T, Test_Legacy_Gender_Select_Still_Works'Access,
        "legacy male/female/other selects keep working");
      Register_Routine (T, Test_Selectordinal_Optional_Branches_Fall_Back'Access,
        "selectordinal optional branches fall back to other (Option A)");
      Register_Routine (T, Test_Selectordinal_All_Category_Branches'Access,
        "selectordinal messages render all ordinal category branches");
      Register_Routine (T, Test_Plural_Only_Other_Is_Valid'Access,
        "a plural with only an other branch is valid");
      Register_Routine (T, Test_Plural_Offset'Access,
        "plural offset adjusts branch selection and # substitution");
      Register_Routine (T, Test_Exact_Plural_And_Ordinal_Branches'Access,
        "exact plural/selectordinal branches take precedence");
      Register_Routine (T, Test_Decimal_Plural_Operands'Access,
        "decimal plural operands use CLDR fractional categories");
      Register_Routine (T, Test_Apostrophe_Escaping'Access,
        "apostrophe escaping follows ICU-style literal quoting");
      Register_Routine (T, Test_Select_Missing_Other_Is_Rejected'Access,
        "a select without other is rejected");
      Register_Routine (T, Test_Duplicate_Select_Branch_Is_Rejected'Access,
        "a duplicate select branch is rejected");
      Register_Routine (T, Test_Plural_Cardinal'Access,
        "cardinal plural categories for supported locales");
      Register_Routine (T, Test_Plural_Ordinal'Access,
        "ordinal plural categories for supported locales");
      Register_Routine (T, Test_Plural_Cardinal_Slavic_Arabic'Access,
        "Slavic/Arabic cardinal categories exercise few/many/zero/two");
      Register_Routine (T, Test_Plural_All_Category_Branches'Access,
        "plural messages render all cardinal category branches");
      Register_Routine (T, Test_Render_Into_Success'Access,
        "Render_Into writes into caller-owned storage");
      Register_Routine (T, Test_Render_Into_Overflow'Access,
        "Render_Into reports Buffer_Overflow with a partial prefix");
      Register_Routine (T, Test_Render_Into_Missing_Key'Access,
        "Render_Into reports Missing_Key with no partial output");
      Register_Routine (T, Test_Render_Into_Complex_Construct'Access,
        "Render_Into renders selectordinal directly into caller storage");
      Register_Routine (T, Test_Currency_Rendering'Access,
        "currency format renders by locale and bounded output");
      Register_Routine (T, Test_Currency_Invalid_Input'Access,
        "currency format validates codes and amount syntax");
      Register_Routine (T, Test_Number_Rendering'Access,
        "number format renders by locale and bounded output");
      Register_Routine (T, Test_Number_Invalid_Input'Access,
        "number format validates decimal syntax");
      Register_Routine (T, Test_Date_Time_Rendering'Access,
        "date and time formats render by locale and bounded output");
      Register_Routine (T, Test_Date_Time_Invalid_Input'Access,
        "date and time formats validate input syntax and ranges");
      Register_Routine (T, Test_Runtime_Data_Overrides'Access,
        "runtime locale/tzdb data overrides generated formatter data");
      Register_Routine (T, Test_Normalized_CLDR_Runtime_Data'Access,
        "normalized CLDR rows load as runtime formatter data");
      Register_Routine (T, Test_Ecosystem_Formatters'Access,
        "ecosystem formatters render duration, bytes, units, relative time, and lists");
      Register_Routine (T, Test_Compiled_Path_Is_Stable'Access,
        "the compiled/indexed render path is deterministic");
      Register_Routine (T, Test_Ordinal_Render_Is_Locale_Correct'Access,
        "selectordinal rendering follows the locale's CLDR ordinal rules");
      Register_Routine (T, Test_Plural_Render_Uses_Locale_Rules'Access,
        "plural rendering follows the locale's CLDR cardinal rules");
      Register_Routine (T, Test_Display_Names'Access,
                        "CLDR display names, delimiters, and measurement "
                        & "from the runtime data file");
      Register_Routine (T, Test_Emoji_Annotations'Access,
                        "CLDR emoji annotations (names + keywords) from "
                        & "per-locale runtime shards");
      Register_Routine (T, Test_Calendar_Names'Access,
                        "CLDR non-Gregorian calendar names from per-locale "
                        & "runtime shards");
      Register_Routine (T, Test_Person_Names'Access,
                        "CLDR person-name formatting (TR35) from per-locale "
                        & "runtime shards");
      Register_Routine (T, Test_Spellout'Access,
                        "RBNF spellout: numbers to words via the recursive "
                        & "rule interpreter");
      Register_Routine (T, Test_Normalization'Access,
                        "Unicode normalization (UAX #15): NFC/NFD/NFKC/NFKD");
      Register_Routine (T, Test_Calendar_Math'Access,
                        "Calendar arithmetic: date conversion across calendars");
      Register_Routine (T, Test_Segmentation'Access,
                        "Text segmentation (UAX #29/#14): grapheme/word/"
                        & "sentence/line boundaries");
      Register_Routine (T, Test_Localized_Select_Plural_Corpus'Access,
        "localized select/plural corpus covers nested formatted arguments");
   end Register_Tests;

end I18N.Runtime.Tests.Features;
