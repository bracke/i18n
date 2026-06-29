with AUnit.Assertions;
with I18N.Errors; use I18N.Errors;
with I18N.Runtime.Compatibility;
with I18N.Arguments;

package body I18N.Runtime.Tests.Strict is

   procedure Assert_Render_OK
     (Source   : String;
      Key_1    : String := "";
      Value_1  : String := "";
      Key_2    : String := "";
      Value_2  : String := "";
      Expected : String);

   procedure Assert_Render_Error
     (Source  : String;
      Error   : I18N.Errors.Error_Kind;
      Key_1   : String := "";
      Value_1 : String := "";
      Key_2   : String := "";
      Value_2 : String := "");

   procedure Add_Arg
     (Args : in out I18N.Arguments.Arguments; Key : String; Value : String) is
   begin
      if Key'Length > 0 then
         I18N.Arguments.Set (Args => Args, Key => Key, Value => Value);
      end if;
   end Add_Arg;

   procedure Assert_Render_OK
     (Source   : String;
      Key_1    : String := "";
      Value_1  : String := "";
      Key_2    : String := "";
      Value_2  : String := "";
      Expected : String)
   is
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      Add_Arg (Args, Key_1, Value_1);
      Add_Arg (Args, Key_2, Value_2);

      declare
         Actual : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Actual.Ok,
            Message   => "Source '" & Source & "' should render successfully");
         AUnit.Assertions.Assert
           (Condition => I18N.Errors.Value_Text (Actual) = Expected,
            Message   =>
              "Source '"
              & Source
              & "' expected '"
              & Expected
              & "' but got '"
              & I18N.Errors.Value_Text (Actual)
              & "'");
      end;

      I18N.Runtime.Finalize (Runtime);
   end Assert_Render_OK;

   procedure Assert_Render_Error
     (Source  : String;
      Error   : I18N.Errors.Error_Kind;
      Key_1   : String := "";
      Value_1 : String := "";
      Key_2   : String := "";
      Value_2 : String := "")
   is
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      Add_Arg (Args, Key_1, Value_1);
      Add_Arg (Args, Key_2, Value_2);

      declare
         Actual : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => not Actual.Ok,
            Message   => "Source '" & Source & "' should fail");
         AUnit.Assertions.Assert
           (Condition => Actual.Error = Error,
            Message   => "Source '" & Source & "' returned wrong error kind");
      end;

      I18N.Runtime.Finalize (Runtime);
   end Assert_Render_Error;

   procedure Test_Valid_Variable_Returns_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   => "Hello {name}",
         Key_1    => "name",
         Value_1  => "Ada",
         Expected => "Hello Ada");
   end Test_Valid_Variable_Returns_Result;

   procedure Test_Missing_Brace_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source => "Hello {name", Error => I18N.Errors.Unbalanced_Braces);
   end Test_Missing_Brace_Returns_Parse_Error;

   procedure Test_Unmatched_Close_Brace_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source => "Hello } name", Error => I18N.Errors.Unbalanced_Braces);
   end Test_Unmatched_Close_Brace_Returns_Parse_Error;

   procedure Test_Unknown_Keyword_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{count, plura, one {1} other {#}}",
         Error   => I18N.Errors.Parse_Error,
         Key_1   => "count",
         Value_1 => "1");
   end Test_Unknown_Keyword_Returns_Parse_Error;

   procedure Test_Valid_Plural_Returns_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   => "{count, plural, one {1 item} other {# items}}",
         Key_1    => "count",
         Value_1  => "4",
         Expected => "4 items");
   end Test_Valid_Plural_Returns_Result;

   procedure Test_Valid_Select_Fallback_Returns_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   => "{gender, select, male {He} female {She} other {They}}",
         Key_1    => "gender",
         Value_1  => "neutral",
         Expected => "They");
   end Test_Valid_Select_Fallback_Returns_Result;

   procedure Test_Valid_Selectordinal_Returns_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   =>
           "{num, selectordinal, one {1st} two {2nd} few {3rd} other {#th}}",
         Key_1    => "num",
         Value_1  => "9",
         Expected => "9th");
   end Test_Valid_Selectordinal_Returns_Result;

   procedure Test_Empty_Message_Returns_Empty_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK (Source => "", Expected => "");
   end Test_Empty_Message_Returns_Empty_Result;

   procedure Test_Missing_Plural_Branch_Returns_Missing_Branch
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{count, plural, one {1 item}}",
         Error   => I18N.Errors.Missing_Branch,
         Key_1   => "count",
         Value_1 => "1");
   end Test_Missing_Plural_Branch_Returns_Missing_Branch;

   procedure Test_Invalid_Plural_Category_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{count, plural, few {x}}",
         Error   => I18N.Errors.Parse_Error,
         Key_1   => "count",
         Value_1 => "3");
   end Test_Invalid_Plural_Category_Returns_Parse_Error;

   procedure Test_Missing_Variable_Returns_Missing_Variable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source => "{name}", Error => I18N.Errors.Missing_Variable);
   end Test_Missing_Variable_Returns_Missing_Variable;

   procedure Test_Invalid_Plural_Selector_Returns_Invalid_Selector
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{count, plural, one {one} other {# items}}",
         Error   => I18N.Errors.Invalid_Selector,
         Key_1   => "count",
         Value_1 => "many");
   end Test_Invalid_Plural_Selector_Returns_Invalid_Selector;

   procedure Test_Invalid_Ordinal_Selector_Returns_Invalid_Ordinal
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  =>
           "{num, selectordinal, one {1st} two {2nd} few {3rd} other {#th}}",
         Error   => I18N.Errors.Invalid_Ordinal,
         Key_1   => "num",
         Value_1 => "first");
   end Test_Invalid_Ordinal_Selector_Returns_Invalid_Ordinal;

   procedure Test_Select_Missing_Other_Returns_Missing_Branch
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{gender, select, male {He}}",
         Error   => I18N.Errors.Missing_Branch,
         Key_1   => "gender",
         Value_1 => "male");
   end Test_Select_Missing_Other_Returns_Missing_Branch;

   procedure Test_Selectordinal_Missing_Required_Branch_Returns_Missing_Branch
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      --  Only "other" is mandatory; a selectordinal that omits "other" is the
      --  missing-branch case (missing one/two/few fall back to "other").
      Assert_Render_Error
        (Source  => "{num, selectordinal, one {1st} two {2nd} few {3rd}}",
         Error   => I18N.Errors.Missing_Branch,
         Key_1   => "num",
         Value_1 => "1");
   end Test_Selectordinal_Missing_Required_Branch_Returns_Missing_Branch;

   procedure Test_Valid_Nested_Constructs_Return_Result
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   =>
           "{count, plural, one {{gender, select, male {He has one item} " &
           "female {She has one item} other {They have one item}}}" &
           " other {{gender, select, male {He has # items} female {She has # items} other {They have # items}}}}",
         Key_1    => "count",
         Value_1  => "2",
         Key_2    => "gender",
         Value_2  => "female",
         Expected => "She has 2 items");
   end Test_Valid_Nested_Constructs_Return_Result;

   procedure Test_Runtime_Validity_State_Exposes_Initialization_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name");

      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime),
         Message   => "runtime should record invalid initialization state");
      AUnit.Assertions.Assert
        (Condition =>
           I18N.Runtime.Compatibility.Last_Error (Runtime)
           = I18N.Errors.Unbalanced_Braces,
         Message   =>
           "runtime should expose Unbalanced_Braces after failed parse");
      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Compatibility.Has_Root (Runtime),
         Message   =>
           "runtime should not keep an AST root after failed initialization");

      I18N.Runtime.Finalize (Runtime);
   end Test_Runtime_Validity_State_Exposes_Initialization_Error;

   procedure Test_Duplicate_Plural_Branch_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source  => "{count, plural, one {1} one {again} other {#}}",
         Error   => I18N.Errors.Parse_Error,
         Key_1   => "count",
         Value_1 => "1");
   end Test_Duplicate_Plural_Branch_Returns_Parse_Error;

   procedure Test_Invalid_Variable_Identifier_Returns_Parse_Error
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        (Source => "{a b}", Error => I18N.Errors.Parse_Error);
   end Test_Invalid_Variable_Identifier_Returns_Parse_Error;

   procedure Test_Explicit_Empty_Select_Other_Renders_Empty
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_OK
        (Source   => "{gender, select, other {}}",
         Key_1    => "gender",
         Value_1  => "unknown",
         Expected => "");
   end Test_Explicit_Empty_Select_Other_Renders_Empty;
   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N strict result/error tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Valid_Variable_Returns_Result'Access,
         "valid variable returns successful Result");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Brace_Returns_Parse_Error'Access,
         "missing closing brace returns Unbalanced_Braces");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Unmatched_Close_Brace_Returns_Parse_Error'Access,
         "unmatched closing brace returns Unbalanced_Braces");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Unknown_Keyword_Returns_Parse_Error'Access,
         "unknown ICU keyword returns Parse_Error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Valid_Plural_Returns_Result'Access,
         "valid plural branches render successfully");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Valid_Select_Fallback_Returns_Result'Access,
         "valid select fallback renders successfully");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Valid_Selectordinal_Returns_Result'Access,
         "valid selectordinal branches render successfully");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Empty_Message_Returns_Empty_Result'Access,
         "empty message returns empty successful Result");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Plural_Branch_Returns_Missing_Branch'Access,
         "missing plural branch returns Missing_Branch");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Plural_Category_Returns_Parse_Error'Access,
         "invalid plural category returns Parse_Error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Variable_Returns_Missing_Variable'Access,
         "missing variable returns Missing_Variable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Plural_Selector_Returns_Invalid_Selector'Access,
         "non-numeric plural selector returns Invalid_Selector");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Ordinal_Selector_Returns_Invalid_Ordinal'Access,
         "non-numeric selectordinal selector returns Invalid_Ordinal");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Select_Missing_Other_Returns_Missing_Branch'Access,
         "select without other returns Missing_Branch");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Selectordinal_Missing_Required_Branch_Returns_Missing_Branch'Access,
         "selectordinal missing required branch returns Missing_Branch");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Valid_Nested_Constructs_Return_Result'Access,
         "valid nested constructs render safely");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Runtime_Validity_State_Exposes_Initialization_Error'Access,
         "runtime exposes initialization validity and error state");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Duplicate_Plural_Branch_Returns_Parse_Error'Access,
         "duplicate plural branches return Parse_Error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Variable_Identifier_Returns_Parse_Error'Access,
         "invalid variable identifier returns Parse_Error");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Explicit_Empty_Select_Other_Renders_Empty'Access,
         "explicit empty select fallback renders empty text");
   end Register_Tests;

end I18N.Runtime.Tests.Strict;
