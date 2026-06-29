with Ada.Strings.Fixed;
with AUnit.Assertions;

with Project_Tools.Files;

with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Plurals;
with I18N.Result; use I18N.Result;

package body I18N.Runtime.Tests.Features is

   use AUnit.Assertions;

   ---------------------------------------------------------------------------
   --  Small helpers.
   ---------------------------------------------------------------------------

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
   begin
      Assert (not Bad.Valid, "invalid message fails validation");
      Assert (Any_Message_Contains (Bad.Diagnostics, "line 3"),
              "the diagnostic must name the offending line (3)");

      Assert (not Dup.Valid, "duplicate key fails validation");
      Assert (Any_Message_Contains (Dup.Diagnostics, "line 2"),
              "the duplicate diagnostic must name the offending line (2)");
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
      Assert (I18N.Plurals.Cardinal ("ja", 1) = I18N.Plurals.Other, "ja other-only");
      Assert (I18N.Plurals.Cardinal ("zh", 5) = I18N.Plurals.Other, "zh other-only");
   end Test_Plural_Cardinal_Slavic_Arabic;

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
   begin
      I18N.Runtime.Load_Text
        (Runtime, "base",
         "en.place = ""{rank, selectordinal, one {#st} two {#nd} few {#rd} "
         & "other {#th}}""" & ASCII.LF,
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
         & ASCII.LF,
         Result);

      I18N.Arguments.Set (Args, "count", "0");
      Assert (Rendered (Runtime, "fr", "items", Args) = "un item",
              "fr cardinal 0 uses the one branch");
      I18N.Arguments.Set (Args, "count", "2");
      Assert (Rendered (Runtime, "fr", "items", Args) = "2 items",
              "fr cardinal 2 uses the other branch");
   end Test_Plural_Render_Uses_Locale_Rules;

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
      Register_Routine (T, Test_Resolve_Found_Through_Fallback'Access,
        "Resolve finds keys through the locale fallback chain");
      Register_Routine (T, Test_Resolve_Missing_And_Invalid'Access,
        "Resolve reports Missing_Key and Runtime_Invalid");
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
      Register_Routine (T, Test_Plural_Only_Other_Is_Valid'Access,
        "a plural with only an other branch is valid");
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
      Register_Routine (T, Test_Render_Into_Success'Access,
        "Render_Into writes into caller-owned storage");
      Register_Routine (T, Test_Render_Into_Overflow'Access,
        "Render_Into reports Buffer_Overflow with a partial prefix");
      Register_Routine (T, Test_Render_Into_Missing_Key'Access,
        "Render_Into reports Missing_Key with no partial output");
      Register_Routine (T, Test_Render_Into_Complex_Construct'Access,
        "Render_Into renders selectordinal directly into caller storage");
      Register_Routine (T, Test_Compiled_Path_Is_Stable'Access,
        "the compiled/indexed render path is deterministic");
      Register_Routine (T, Test_Ordinal_Render_Is_Locale_Correct'Access,
        "selectordinal rendering follows the locale's CLDR ordinal rules");
      Register_Routine (T, Test_Plural_Render_Uses_Locale_Rules'Access,
        "plural rendering follows the locale's CLDR cardinal rules");
   end Register_Tests;

end I18N.Runtime.Tests.Features;
