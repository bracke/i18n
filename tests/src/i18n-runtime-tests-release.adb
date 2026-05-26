with Ada.Text_IO;
with AUnit.Assertions;

with I18N.Arguments;
with I18N.Result; use I18N.Result;
with I18N.Runtime;
with I18N.Diagnostics;

package body I18N.Runtime.Tests.Release is

   Trace_Count : Natural := 0;

   procedure Capture_Trace
     (Event : I18N.Diagnostics.Trace_Event_Kind; Key : String)
   is
      pragma Unreferenced (Event, Key);
   begin
      Trace_Count := Trace_Count + 1;
   end Capture_Trace;

   procedure Raising_Trace
     (Event : I18N.Diagnostics.Trace_Event_Kind; Key : String)
   is
      pragma Unreferenced (Event, Key);
   begin
      raise Constraint_Error with "intentional diagnostic callback failure";
   end Raising_Trace;

   procedure Write_File (Path : String; Text : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Text);
      Ada.Text_IO.Close (File);
   end Write_File;

   procedure Add_Arg
     (Args : in out I18N.Arguments.Arguments; Key : String; Value : String) is
   begin
      I18N.Arguments.Set (Args, Key, Value);
   end Add_Arg;

   procedure Test_Public_Catalog_Render_Uses_Only_Frozen_API
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Locale_Fallback_Is_Deterministic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Missing_Key_Returns_Public_Status
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Invalid_Catalog_Fails_Deterministically
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Default_Locale_Fallback_Is_Last
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Public_Status_Mapping_Is_Stable
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Duplicate_Catalog_Entry_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Default_Locale_May_Appear_After_Entries
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Empty_Catalog_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Duplicate_Default_Locale_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Empty_Default_Locale_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Empty_Locale_And_Key_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Default_Qualified_Duplicate_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Malformed_Catalog_Line_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Catalog_Value_Can_Contain_Equals
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Empty_Message_Value_Renders_As_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Diagnostics_Do_Not_Change_Public_Render_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Callback_Exception_Cannot_Crash_Public_Render
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N public API/release contract tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
      use AUnit.Test_Cases;
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Public_Catalog_Render_Uses_Only_Frozen_API'Access,
         "catalog render compiles using only v1.0 public packages");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Locale_Fallback_Is_Deterministic'Access,
         "locale fallback follows de-AT -> de -> default locale");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Key_Returns_Public_Status'Access,
         "missing key after fallback returns Missing_Key");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Catalog_Fails_Deterministically'Access,
         "invalid catalog produces deterministic initialization failure");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Default_Locale_Fallback_Is_Last'Access,
         "missing locale falls back to configured default locale");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Public_Status_Mapping_Is_Stable'Access,
         "missing and invalid arguments map to stable public statuses");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Duplicate_Catalog_Entry_Is_Rejected'Access,
         "duplicate catalog entries are deterministic initialization failures");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Default_Locale_May_Appear_After_Entries'Access,
         "default_locale may appear after message entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Empty_Catalog_Is_Rejected'Access,
         "empty catalogs are deterministic initialization failures");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Duplicate_Default_Locale_Is_Rejected'Access,
         "duplicate default_locale lines are rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Empty_Default_Locale_Is_Rejected'Access,
         "empty default_locale is rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Empty_Locale_And_Key_Are_Rejected'Access,
         "empty locale and empty key catalog entries are rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Default_Qualified_Duplicate_Is_Rejected'Access,
         "unqualified and default-qualified duplicate keys are rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Malformed_Catalog_Line_Is_Rejected'Access,
         "malformed catalog lines are rejected");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Catalog_Value_Can_Contain_Equals'Access,
         "catalog values may contain '=' characters");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Empty_Message_Value_Renders_As_Success'Access,
         "empty catalog message values render as successful empty text");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Diagnostics_Do_Not_Change_Public_Render_Result'Access,
         "diagnostics do not change public catalog render results");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Callback_Exception_Cannot_Crash_Public_Render'Access,
         "callback exceptions cannot crash public catalog rendering");
   end Register_Tests;

   procedure Test_Public_Catalog_Render_Uses_Only_Frozen_API
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_public_api.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome, {name}!"""
         & ASCII.LF);

      Add_Arg (Args, "name", "Ada");
      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "title",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "Welcome, Ada!",
            Message   =>
              "frozen public API render should succeed; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Public_Catalog_Render_Uses_Only_Frozen_API;

   procedure Test_Locale_Fallback_Is_Deterministic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_locale_fallback.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome"""
         & ASCII.LF
         & "de.title = ""Willkommen"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "de-AT",
              Key       => "title",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "Willkommen",
            Message   =>
              "de-AT should fall back to de before default locale; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Locale_Fallback_Is_Deterministic;

   procedure Test_Missing_Key_Returns_Public_Status
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_missing_key.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "de-AT",
              Key       => "missing",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Result.Status = I18N.Result.Missing_Key,
            Message   => "missing key after fallback must return Missing_Key");
      end;
   end Test_Missing_Key_Returns_Public_Status;

   procedure Test_Invalid_Catalog_Fails_Deterministically
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_invalid_catalog.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.bad = ""Hello {name"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "invalid catalog must fail during deterministic initialization");
   end Test_Invalid_Catalog_Fails_Deterministically;

   procedure Test_Default_Locale_Fallback_Is_Last
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_default_locale.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Default title"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "fr-CA",
              Key       => "title",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "Default title",
            Message   =>
              "missing locale must fall back to configured default locale; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Default_Locale_Fallback_Is_Last;

   procedure Test_Public_Status_Mapping_Is_Stable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_status_mapping.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.welcome = ""Welcome, {name}!"""
         & ASCII.LF
         & "en.items = ""{count, plural, one {One item} other {# items}}"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Missing : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "welcome",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Missing.Status = I18N.Result.Missing_Argument,
            Message   =>
              "missing public argument must map to Missing_Argument");
      end;

      Add_Arg (Args, "count", "not-a-number");

      declare
         Invalid : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "items",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Invalid.Status = I18N.Result.Invalid_Argument,
            Message   =>
              "non-numeric plural selector must map to Invalid_Argument");
      end;
   end Test_Public_Status_Mapping_Is_Stable;

   procedure Test_Duplicate_Catalog_Entry_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_duplicate_entry.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""First"""
         & ASCII.LF
         & "en.title = ""Second"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "duplicate locale/key entries must make catalog initialization invalid");
   end Test_Duplicate_Catalog_Entry_Is_Rejected;

   procedure Test_Default_Locale_May_Appear_After_Entries
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_late_default_locale.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "title = ""Hallo""" & ASCII.LF & "default_locale = de" & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "fr-CA",
              Key       => "title",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "Hallo",
            Message   =>
              "unqualified entries must bind to default_locale even if it appears later; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Default_Locale_May_Appear_After_Entries;

   procedure Test_Empty_Catalog_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_empty_catalog.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File (Path, "# no messages" & ASCII.LF);
      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "empty catalog must be rejected as a validation failure");
   end Test_Empty_Catalog_Is_Rejected;

   procedure Test_Duplicate_Default_Locale_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_duplicate_default.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome"""
         & ASCII.LF
         & "default_locale = de"
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "duplicate default_locale declarations must be rejected");
   end Test_Duplicate_Default_Locale_Is_Rejected;

   procedure Test_Empty_Default_Locale_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_empty_default.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "default_locale = " & ASCII.LF & "en.title = ""Welcome""" & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   => "empty default_locale must be rejected");
   end Test_Empty_Default_Locale_Is_Rejected;

   procedure Test_Empty_Locale_And_Key_Are_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Empty_Locale_Path : constant String := "release_empty_locale.catalog";
      Empty_Key_Path    : constant String := "release_empty_key.catalog";
      Runtime           : I18N.Runtime.Instance;
   begin
      Write_File
        (Empty_Locale_Path,
         "default_locale = en" & ASCII.LF & ".title = ""Welcome""" & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Empty_Locale_Path);
      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   => "empty locale before dot must be rejected");

      I18N.Runtime.Finalize (Runtime);
      Write_File
        (Empty_Key_Path,
         "default_locale = en" & ASCII.LF & "en. = ""Welcome""" & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Empty_Key_Path);
      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   => "empty key after dot must be rejected");
   end Test_Empty_Locale_And_Key_Are_Rejected;

   procedure Test_Default_Qualified_Duplicate_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_default_duplicate.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "title = ""First"""
         & ASCII.LF
         & "default_locale = en"
         & ASCII.LF
         & "en.title = ""Second"""
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "unqualified default-locale key and explicit default-locale key must collide");
   end Test_Default_Qualified_Duplicate_Is_Rejected;

   procedure Test_Malformed_Catalog_Line_Is_Rejected
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_malformed_line.catalog";
      Runtime : I18N.Runtime.Instance;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "this line has no separator"
         & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   =>
           "catalog lines without '=' must be rejected deterministically");
   end Test_Malformed_Catalog_Line_Is_Rejected;

   procedure Test_Catalog_Value_Can_Contain_Equals
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_equals_value.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""A = {name}"""
         & ASCII.LF);

      Add_Arg (Args, "name", "Ada");
      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "title",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "A = Ada",
            Message   =>
              "only the first '=' separates catalog key and value; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Catalog_Value_Can_Contain_Equals;

   procedure Test_Empty_Message_Value_Renders_As_Success
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_empty_message.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path, "default_locale = en" & ASCII.LF & "en.empty = " & ASCII.LF);

      I18N.Runtime.Initialize (Runtime, Path);

      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "empty",
              Arguments => Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "",
            Message   =>
              "an explicitly present empty message must not be treated as Missing_Key; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   end Test_Empty_Message_Value_Renders_As_Success;

   procedure Test_Diagnostics_Do_Not_Change_Public_Render_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_diagnostics_no_change.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome, {name}!"""
         & ASCII.LF);

      Add_Arg (Args, "name", "Ada");
      I18N.Runtime.Initialize (Runtime, Path);

      I18N.Diagnostics.Set_Trace_Callback (null);
      declare
         Without_Callback : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "title",
              Arguments => Args);
      begin
         Trace_Count := 0;
         I18N.Diagnostics.Set_Trace_Callback (Capture_Trace'Access);
         declare
            With_Callback : constant I18N.Result.Render_Result :=
              I18N.Runtime.Render
                (Item      => Runtime,
                 Locale    => "en",
                 Key       => "title",
                 Arguments => Args);
         begin
            I18N.Diagnostics.Set_Trace_Callback (null);
            AUnit.Assertions.Assert
              (Condition =>
                 Without_Callback.Status = With_Callback.Status
                 and then
                   I18N.Result.Output_Text (Without_Callback.Text)
                   = I18N.Result.Output_Text (With_Callback.Text),
               Message   =>
                 "enabling diagnostics must not change public render status or text");
         end;
      end;
   end Test_Diagnostics_Do_Not_Change_Public_Render_Result;

   procedure Test_Callback_Exception_Cannot_Crash_Public_Render
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Path    : constant String := "release_callback_exception.catalog";
      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
   begin
      Write_File
        (Path,
         "default_locale = en"
         & ASCII.LF
         & "en.title = ""Welcome, {name}!"""
         & ASCII.LF);

      Add_Arg (Args, "name", "Ada");
      I18N.Runtime.Initialize (Runtime, Path);

      I18N.Diagnostics.Set_Trace_Callback (Raising_Trace'Access);
      declare
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render
             (Item      => Runtime,
              Locale    => "en",
              Key       => "title",
              Arguments => Args);
      begin
         I18N.Diagnostics.Set_Trace_Callback (null);
         AUnit.Assertions.Assert
           (Condition =>
              Result.Status = I18N.Result.Success
              and then I18N.Result.Output_Text (Result.Text) = "Welcome, Ada!",
            Message   =>
              "callback exceptions must not escape or alter public rendering; status="
              & I18N.Result.Render_Status'Image (Result.Status)
              & "; text="" & I18N.Result.Output_Text (Result.Text) & """);
      end;
   exception
      when others =>
         I18N.Diagnostics.Set_Trace_Callback (null);
         raise;
   end Test_Callback_Exception_Cannot_Crash_Public_Render;

end I18N.Runtime.Tests.Release;
