with AUnit.Assertions;

with I18N.AST;
with I18N.Cache;
with I18N.Compiled;
with I18N.Compiler;
with I18N.Errors; use I18N.Errors;
with I18N.Fast_Render;
with I18N.Parser;
with I18N.Render;
with I18N.Runtime.Compatibility;
with I18N.Arguments;

package body I18N.Runtime.Tests.Compilation is

   procedure Add_Arg
     (Args : in out I18N.Arguments.Arguments; Key : String; Value : String) is
   begin
      I18N.Arguments.Set (Args => Args, Key => Key, Value => Value);
   end Add_Arg;
   procedure Test_Render_Does_Not_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
      Source  : constant String := "Hello {name}";
   begin
      I18N.Cache.Clear;
      Add_Arg (Args, "name", "Ada");

      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   => "initialization should compile exactly once");

      for Iteration in 1 .. 5 loop
         declare
            Result : constant I18N.Errors.Result :=
              I18N.Runtime.Compatibility.Render (Runtime, Args);
         begin
            AUnit.Assertions.Assert
              (Condition =>
                 Result.Ok
                 and then I18N.Errors.Value_Text (Result) = "Hello Ada",
               Message   =>
                 "cached runtime render should succeed on iteration"
                 & Integer'Image (Iteration));
         end;
      end loop;

      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   =>
           "rendering must not parse or recompile the cached message");
      I18N.Runtime.Finalize (Runtime);
   end Test_Render_Does_Not_Recompile;

   procedure Test_Cache_Clear_Forces_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source  : constant String := "Hello {name}";
   begin
      I18N.Cache.Clear;

      declare
         Message : I18N.Compiled.Compiled_Message;
         Result  : constant I18N.Errors.Result :=
           I18N.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Compiled.Op_Count (Message) > 0,
            Message   => "first cache compile should produce IR");
      end;

      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   => "first cache miss should compile once");

      I18N.Cache.Clear;
      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 0,
         Message   => "cache clear should reset compile count");

      declare
         Message : I18N.Compiled.Compiled_Message;
         Result  : constant I18N.Errors.Result :=
           I18N.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Compiled.Op_Count (Message) > 0,
            Message   => "compile after cache clear should produce IR");
      end;

      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   => "cache miss after clear should compile once again");
   end Test_Cache_Clear_Forces_Recompile;

   procedure Test_Invalid_Message_Is_Not_Cached
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Message : I18N.Compiled.Compiled_Message;
      Source  : constant String := "{count, plural, one {# item}}";
   begin
      I18N.Cache.Clear;

      declare
         Result : constant I18N.Errors.Result :=
           I18N.Cache.Get_Or_Compile (Source, Message);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              not Result.Ok and then Result.Error = I18N.Errors.Missing_Branch,
            Message   =>
              "invalid incomplete plural should fail validation and not compile");
      end;

      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 0,
         Message   =>
           "invalid messages must not increment compile count or enter cache");
   end Test_Invalid_Message_Is_Not_Cached;

   procedure Test_Compiler_Produces_Linear_IR
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Root : I18N.AST.Node_Access :=
        I18N.Parser.Parse
          ("Hello {name}, {count, plural, one {# item} other {# items}}");
      Msg  : constant I18N.Compiled.Compiled_Message :=
        I18N.Compiler.Compile (Root);
   begin
      AUnit.Assertions.Assert
        (Condition => I18N.Compiled.Op_Count (Msg) >= 6,
         Message   =>
           "compiled message should contain flattened text, var, branch, and stop operations");
      I18N.AST.Free (Root);
   exception
      when others =>
         I18N.AST.Free (Root);
         raise;
   end Test_Compiler_Produces_Linear_IR;

   procedure Test_Runtime_Uses_Cache_Without_Recompile
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime_1 : I18N.Runtime.Runtime;
      Runtime_2 : I18N.Runtime.Runtime;
      Args      : I18N.Arguments.Arguments;
      Source    : constant String := "Hello {name}";
   begin
      I18N.Cache.Clear;
      Add_Arg (Args, "name", "Ada");

      I18N.Runtime.Compatibility.Initialize_Message (Runtime_1, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   => "first initialization should compile exactly once");

      I18N.Runtime.Compatibility.Initialize_Message (Runtime_2, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Cache.Compile_Count = 1,
         Message   =>
           "second initialization of same message should be a cache hit");

      declare
         Result_1 : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime_1, Args);
         Result_2 : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime_2, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result_1.Ok
              and then I18N.Errors.Value_Text (Result_1) = "Hello Ada",
            Message   => "first cached runtime should render correctly");
         AUnit.Assertions.Assert
           (Condition =>
              Result_2.Ok
              and then I18N.Errors.Value_Text (Result_2) = "Hello Ada",
            Message   => "second cached runtime should render correctly");
      end;

      I18N.Runtime.Finalize (Runtime_1);
      I18N.Runtime.Finalize (Runtime_2);
   end Test_Runtime_Uses_Cache_Without_Recompile;

   procedure Test_Plural_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime, "{count, plural, one {# item} other {# items}}");
      Add_Arg (Args, "count", "2");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "2 items",
            Message   =>
              "compiled plural should select other and substitute #");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Plural_IR_Renders_Correctly;

   procedure Test_Select_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{width, select, full {hour} short {hr} narrow {h} other {hour}}");
      Add_Arg (Args, "width", "short");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "hr",
            Message   =>
              "compiled select should jump to an arbitrary named branch");
      end;

      Add_Arg (Args, "width", "unmatched");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "hour",
            Message   =>
              "compiled select should fall back to the other branch");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Select_IR_Renders_Correctly;

   procedure Test_Selectordinal_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{num, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}");
      Add_Arg (Args, "num", "3");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "3rd",
            Message   => "compiled selectordinal should select few for 3");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Selectordinal_IR_Renders_Correctly;

   procedure Test_Plural_Offset_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "{count, plural, offset:1 one {# item} other {# items}}");
      Add_Arg (Args, "count", "2");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "1 item",
            Message   => "compiled plural offset should adjust # and branch");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Plural_Offset_IR_Renders_Correctly;

   procedure Test_Currency_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime, "Total {amount, currency, USD}");
      Add_Arg (Args, "amount", "7.5");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then I18N.Errors.Value_Text (Result) = "Total $7.50",
            Message   => "compiled currency should format the amount");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Currency_IR_Renders_Correctly;

   procedure Test_Number_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime, "Total {value, number}");
      Add_Arg (Args, "value", "12345.5");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then I18N.Errors.Value_Text (Result) = "Total 12,345.5",
            Message   => "compiled number should format the value");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Number_IR_Renders_Correctly;

   procedure Test_Date_Time_IR_Renders_Correctly
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime, "On {day, date} at {clock, time}");
      Add_Arg (Args, "day", "2026-06-29");
      Add_Arg (Args, "clock", "14:30");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then I18N.Errors.Value_Text (Result) =
                "On 2026-06-29 at 14:30",
            Message   => "compiled date/time should format values");
      end;
      I18N.Runtime.Finalize (Runtime);
   end Test_Date_Time_IR_Renders_Correctly;

   procedure Test_AST_And_IR_Render_Are_Equivalent
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "{count, plural, "
        & "=0 {Nobody has items} "
        & "one {{gender, select, "
        & "male {He has # item} "
        & "female {She has # item} "
        & "other {They have # item}}} "
        & "other {{gender, select, "
        & "male {He has # items} "
        & "female {She has # items} "
        & "other {They have # items}}}}";
      Root   : I18N.AST.Node_Access := I18N.Parser.Parse (Source);
      Msg    : constant I18N.Compiled.Compiled_Message :=
        I18N.Compiler.Compile (Root);
      Args   : I18N.Arguments.Arguments;
   begin
      Add_Arg (Args, "count", "0");
      Add_Arg (Args, "gender", "male");

      declare
         AST_Result : constant I18N.Errors.Result :=
           I18N.Render.Render (Root, Args);
         IR_Result  : constant I18N.Errors.Result :=
           I18N.Fast_Render.Render (Msg, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => AST_Result.Ok,
            Message   => "AST renderer should succeed");
         AUnit.Assertions.Assert
           (Condition => IR_Result.Ok,
            Message   => "IR renderer should succeed");
         AUnit.Assertions.Assert
           (Condition =>
              I18N.Errors.Value_Text (AST_Result)
              = I18N.Errors.Value_Text (IR_Result),
            Message   => "IR result must match AST result exactly");
      end;

      I18N.AST.Free (Root);
   exception
      when others =>
         I18N.AST.Free (Root);
         raise;
   end Test_AST_And_IR_Render_Are_Equivalent;

   procedure Test_Nested_Number_Context_Is_Restored
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
      Source  : constant String :=
        "{count, plural, "
        & "one {{num, selectordinal, "
        & "one {#st inner} "
        & "two {#nd inner} "
        & "few {#rd inner} "
        & "other {#th inner}} outer #} "
        & "other {outer #}}";
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      Add_Arg (Args, "count", "1");
      Add_Arg (Args, "num", "2");

      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then I18N.Errors.Value_Text (Result) = "2nd inner outer 1",
            Message   =>
              "inner ordinal # substitution must not corrupt outer plural # context");
      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Nested_Number_Context_Is_Restored;

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N compiled IR/cache tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Compiler_Produces_Linear_IR'Access,
         "compiler emits flattened operations");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Runtime_Uses_Cache_Without_Recompile'Access,
         "repeated runtime initialization reuses cached compiled message");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Render_Does_Not_Recompile'Access,
         "repeated renders do not recompile cached message");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Cache_Clear_Forces_Recompile'Access,
         "explicit cache clear forces later recompilation");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Invalid_Message_Is_Not_Cached'Access,
         "invalid messages are not cached as compiled entries");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Plural_IR_Renders_Correctly'Access,
         "compiled plural renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Select_IR_Renders_Correctly'Access,
         "compiled select renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Selectordinal_IR_Renders_Correctly'Access,
         "compiled selectordinal renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Plural_Offset_IR_Renders_Correctly'Access,
         "compiled plural offset renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Currency_IR_Renders_Correctly'Access,
         "compiled currency renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Number_IR_Renders_Correctly'Access,
         "compiled number renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Date_Time_IR_Renders_Correctly'Access,
         "compiled date/time renders correctly");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_AST_And_IR_Render_Are_Equivalent'Access,
         "AST renderer and IR renderer are exactly equivalent");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Nested_Number_Context_Is_Restored'Access,
         "nested plural/selectordinal number context is restored");
   end Register_Tests;

end I18N.Runtime.Tests.Compilation;
