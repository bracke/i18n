with Ada.Exceptions;
with Ada.Strings.Fixed;

with AUnit.Assertions;

with I18N.AST;
with I18N.Buffer;
with I18N.Compiled;
with I18N.Compiler;
with I18N.Errors; use I18N.Errors;
with I18N.Fast_Render;
with I18N.Parser;
with I18N.Render;
with I18N.Runtime.Compatibility;
with I18N.Validation;
with I18N.Arguments;

package body I18N.Runtime.Tests.Corpus is

   type Fuzz_Category is
     (Valid,
      Invalid_Syntax,
      Invalid_Structure,
      Edge_Case_Nesting);

   type Argument_Profile is
     (Default_Profile,
      Count_One_Profile,
      Count_Two_Profile,
      Count_Zero_Profile,
      Gender_Male_Profile,
      Gender_Female_Profile,
      Gender_Other_Profile,
      Ordinal_One_Profile,
      Ordinal_Two_Profile,
      Ordinal_Three_Profile,
      Ordinal_Eleven_Profile,
      Ordinal_Twelve_Profile,
      Ordinal_Thirteen_Profile,
      Missing_Name_Profile,
      Non_Numeric_Count_Profile,
      Non_Numeric_Ordinal_Profile);

   type Classification is record
      Ok    : Boolean := False;
      Error : I18N.Errors.Error_Kind := I18N.Errors.Parse_Error;
   end record;

   procedure Add_Default_Args
     (Args : in out I18N.Arguments.Arguments)
   is
   begin
      I18N.Arguments.Clear (Args);
      I18N.Arguments.Set (Args, "name", "Ada");
      I18N.Arguments.Set (Args, "count", "2");
      I18N.Arguments.Set (Args, "rank", "13");
      I18N.Arguments.Set (Args, "gender", "female");
      I18N.Arguments.Set (Args, "kind", "other");
   end Add_Default_Args;

   procedure Configure_Args
     (Args    : in out I18N.Arguments.Arguments;
      Profile : Argument_Profile)
   is
   begin
      Add_Default_Args (Args);

      case Profile is
         when Default_Profile =>
            null;
         when Count_One_Profile =>
            I18N.Arguments.Set (Args, "count", "1");
         when Count_Two_Profile =>
            I18N.Arguments.Set (Args, "count", "2");
         when Count_Zero_Profile =>
            I18N.Arguments.Set (Args, "count", "0");
         when Gender_Male_Profile =>
            I18N.Arguments.Set (Args, "gender", "male");
         when Gender_Female_Profile =>
            I18N.Arguments.Set (Args, "gender", "female");
         when Gender_Other_Profile =>
            I18N.Arguments.Set (Args, "gender", "robot");
         when Ordinal_One_Profile =>
            I18N.Arguments.Set (Args, "rank", "1");
         when Ordinal_Two_Profile =>
            I18N.Arguments.Set (Args, "rank", "2");
         when Ordinal_Three_Profile =>
            I18N.Arguments.Set (Args, "rank", "3");
         when Ordinal_Eleven_Profile =>
            I18N.Arguments.Set (Args, "rank", "11");
         when Ordinal_Twelve_Profile =>
            I18N.Arguments.Set (Args, "rank", "12");
         when Ordinal_Thirteen_Profile =>
            I18N.Arguments.Set (Args, "rank", "13");
         when Missing_Name_Profile =>
            I18N.Arguments.Clear (Args);
            I18N.Arguments.Set (Args, "count", "2");
            I18N.Arguments.Set (Args, "rank", "13");
            I18N.Arguments.Set (Args, "gender", "female");
         when Non_Numeric_Count_Profile =>
            I18N.Arguments.Set (Args, "count", "two");
         when Non_Numeric_Ordinal_Profile =>
            I18N.Arguments.Set (Args, "rank", "thirteen");
      end case;
   end Configure_Args;

   function Parse_Failure_Kind
     (Occurrence : Ada.Exceptions.Exception_Occurrence)
      return I18N.Errors.Error_Kind
   is
      Message : constant String := Ada.Exceptions.Exception_Message (Occurrence);
      use Ada.Strings.Fixed;
   begin
      if Index (Message, "Unmatched") /= 0
        or else Index (Message, "Unclosed") /= 0
        or else Index (Message, "brace") /= 0
      then
         return I18N.Errors.Unbalanced_Braces;
      end if;

      return I18N.Errors.Parse_Error;
   end Parse_Failure_Kind;

   function Same_Result
     (Left  : I18N.Errors.Result;
      Right : I18N.Errors.Result)
      return Boolean
   is
   begin
      if Left.Ok /= Right.Ok then
         return False;
      end if;

      if Left.Ok then
         return I18N.Errors.Value_Text (Left) = I18N.Errors.Value_Text (Right);
      end if;

      return Left.Error = Right.Error;
   end Same_Result;

   procedure Assert_AST_IR_Equivalent
     (Source : String;
      Args   : I18N.Arguments.Arguments)
   is
      Root : I18N.AST.Node_Access := null;
   begin
      Root := I18N.Parser.Parse (Source);

      declare
         Validation_Result : constant I18N.Errors.Result :=
           I18N.Validation.Validate (Root);
      begin
         AUnit.Assertions.Assert
           (Condition => Validation_Result.Ok,
            Message   => "differential source should validate: " & Source);
      end;

      declare
         AST_Result : constant I18N.Errors.Result :=
           I18N.Render.Render (Root, Args);
         Msg : constant I18N.Compiled.Compiled_Message :=
           I18N.Compiler.Compile (Root);
         IR_Result : constant I18N.Errors.Result :=
           I18N.Fast_Render.Render (Msg, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Same_Result (AST_Result, IR_Result),
            Message   => "AST and IR render results diverged for: " & Source);
      end;

      I18N.AST.Free (Root);
   exception
      when others =>
         I18N.AST.Free (Root);
         raise;
   end Assert_AST_IR_Equivalent;

   function Classify_Source
     (Source : String)
      return Classification
   is
      Root : I18N.AST.Node_Access := null;
   begin
      Root := I18N.Parser.Parse (Source);

      declare
         Validation_Result : constant I18N.Errors.Result :=
           I18N.Validation.Validate (Root);
      begin
         I18N.AST.Free (Root);
         if Validation_Result.Ok then
            return (Ok => True, Error => I18N.Errors.Parse_Error);
         end if;

         return (Ok => False, Error => Validation_Result.Error);
      end;
   exception
      when Failure : I18N.Parser.Parse_Error =>
         I18N.AST.Free (Root);
         return (Ok => False, Error => Parse_Failure_Kind (Failure));
      when others =>
         I18N.AST.Free (Root);
         return (Ok => False, Error => I18N.Errors.Parse_Error);
   end Classify_Source;

   procedure Assert_Invalid_Source
     (Source         : String;
      Expected_Error : I18N.Errors.Error_Kind)
   is
      First   : constant Classification := Classify_Source (Source);
      Second  : constant Classification := Classify_Source (Source);
      Runtime : I18N.Runtime.Runtime;
   begin
      AUnit.Assertions.Assert
        (Condition => First.Ok = Second.Ok and then First.Error = Second.Error,
         Message   => "invalid classification changed across runs: " & Source);
      AUnit.Assertions.Assert
        (Condition => not First.Ok and then First.Error = Expected_Error,
         Message   => "unexpected invalid classification for: " & Source);

      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => not I18N.Runtime.Is_Valid (Runtime)
          and then I18N.Runtime.Compatibility.Last_Error (Runtime) = Expected_Error,
         Message   => "runtime invalid init classification changed: " & Source);
      I18N.Runtime.Finalize (Runtime);
   end Assert_Invalid_Source;

   procedure Assert_Runtime_Paths_Equivalent
     (Source : String;
      Args   : I18N.Arguments.Arguments);

   procedure Assert_Golden_Output
     (Source   : String;
      Profile  : Argument_Profile;
      Expected : String)
   is
      Args       : I18N.Arguments.Arguments;
      Runtime    : I18N.Runtime.Runtime;
      Root       : I18N.AST.Node_Access := null;
   begin
      Configure_Args (Args, Profile);
      Assert_AST_IR_Equivalent (Source, Args);
      Assert_Runtime_Paths_Equivalent (Source, Args);

      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Runtime.Is_Valid (Runtime),
         Message   => "corpus source should initialize: " & Source);

      declare
         First  : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
         Second : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Same_Result (First, Second),
            Message   => "runtime output was not deterministic: " & Source);
         AUnit.Assertions.Assert
           (Condition => First.Ok and then I18N.Errors.Value_Text (First) = Expected,
            Message   => "golden output changed for: " & Source);

         Root := I18N.Parser.Parse (Source);
         declare
            AST_Result : constant I18N.Errors.Result :=
              I18N.Render.Render (Root, Args);
         begin
            AUnit.Assertions.Assert
              (Condition => Same_Result (First, AST_Result),
               Message   => "runtime and AST result diverged: " & Source);
         end;
      end;

      I18N.AST.Free (Root);
      I18N.Runtime.Finalize (Runtime);
   exception
      when others =>
         I18N.AST.Free (Root);
         I18N.Runtime.Finalize (Runtime);
         raise;
   end Assert_Golden_Output;

   procedure Assert_Runtime_Paths_Equivalent
     (Source : String;
      Args   : I18N.Arguments.Arguments)
   is
      Runtime : I18N.Runtime.Runtime;
      Context : I18N.Runtime.Compatibility.Execution_Context;
      Status  : I18N.Errors.Status;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Runtime.Is_Valid (Runtime),
         Message   => "runtime path source should initialize: " & Source);

      declare
         Direct_Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         I18N.Arguments.Copy (Source => Args, Destination => Context.Args);
         I18N.Buffer.Clear (Context.Buffer);

         declare
            Context_Result : constant I18N.Errors.Result :=
              I18N.Runtime.Compatibility.Render (Runtime, Context);
         begin
            AUnit.Assertions.Assert
              (Condition => Same_Result (Direct_Result, Context_Result),
               Message   => "direct runtime and context runtime diverged: " & Source);
         end;

         I18N.Arguments.Copy (Source => Args, Destination => Context.Args);
         I18N.Buffer.Clear (Context.Buffer);
         Status := I18N.Runtime.Compatibility.Render_Into (Runtime, Context);

         if Direct_Result.Ok then
            AUnit.Assertions.Assert
              (Condition => Status.Ok
                and then I18N.Buffer.To_String (Context.Buffer) = I18N.Errors.Value_Text (Direct_Result),
               Message   => "Render_Into output diverged: " & Source);
         else
            AUnit.Assertions.Assert
              (Condition => not Status.Ok and then Status.Error = Direct_Result.Error,
               Message   => "Render_Into error classification diverged: " & Source);
         end if;
      end;

      I18N.Runtime.Finalize (Runtime);
   exception
      when others =>
         I18N.Runtime.Finalize (Runtime);
         raise;
   end Assert_Runtime_Paths_Equivalent;

   procedure Assert_Render_Error
     (Source         : String;
      Profile        : Argument_Profile;
      Expected_Error : I18N.Errors.Error_Kind)
   is
      Args    : I18N.Arguments.Arguments;
      Runtime : I18N.Runtime.Runtime;

   begin
      Configure_Args (Args, Profile);
      Assert_AST_IR_Equivalent (Source, Args);
      Assert_Runtime_Paths_Equivalent (Source, Args);
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Runtime.Is_Valid (Runtime),
         Message   => "render-error source should initialize: " & Source);

      declare
         First  : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
         Second : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Same_Result (First, Second),
            Message   => "render error changed across runs: " & Source);
         AUnit.Assertions.Assert
           (Condition => not First.Ok and then First.Error = Expected_Error,
            Message   => "unexpected render error for: " & Source);
      end;

      I18N.Runtime.Finalize (Runtime);
   exception
      when others =>
         I18N.Runtime.Finalize (Runtime);
         raise;
   end Assert_Render_Error;

   function Large_Valid_Message
     (Seed : Positive)
      return String
   is
   begin
      case Seed mod 4 is
         when 0 =>
            return
              "A {name} B {count, plural, one {# file} other {# files}} C " &
              "{gender, select, male {M} female {F} other {O}} D " &
              "{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}";
         when 1 =>
            return
              "{gender, select, male {He has {count, plural, one {# file} " &
              "other {# files}}} female {She has {count, plural, " &
              "one {# file} other {# files}}} other {They have " &
              "{count, plural, one {# file} other {# files}}}}";
         when 2 =>
            return
              "{count, plural, one {{rank, selectordinal, one {#st} " &
              "two {#nd} few {#rd} other {#th}}} other {{gender, select, " &
              "male {M} female {F} other {O}}}}";
         when others =>
            return
              "prefix {name} {name} {name} {count, plural, one {#} " &
              "other {#}} suffix";
      end case;
   end Large_Valid_Message;

   function Large_Repeated_Message
      return String
   is
      Acc : Unbounded_String;
   begin
      for Index in 1 .. 12 loop
         Append
           (Acc,
            Integer'Image (Index) &
            " {name} {count, plural, one {# file} other {# files}}" &
            " {gender, select, male {M} female {F} other {O}}");
      end loop;

      return To_String (Acc);
   end Large_Repeated_Message;

   function Generated_Source
     (Category : Fuzz_Category;
      Seed     : Positive)
      return String
   is
   begin
      case Category is
         when Valid =>
            case Seed mod 8 is
               when 0 =>
                  return "Hello {name}";
               when 1 =>
                  return "{count, plural, one {# file} other {# files}}";
               when 2 =>
                  return
                    "{gender, select, male {He} female {She} other {They}}" &
                    " wrote {count, plural, one {# line} other {# lines}}";
               when 3 =>
                  return
                    "{rank, selectordinal, one {#st} two {#nd} " &
                    "few {#rd} other {#th}}";
               when 4 =>
                  return
                    "Outer {gender, select, male {{count, plural, " &
                    "one {# item} other {# items}}} female {ok} " &
                    "other {fallback}}";
               when 5 =>
                  if Seed mod 16 = 5 then
                     return Large_Repeated_Message;
                  else
                     return Large_Valid_Message (Seed);
                  end if;
               when 6 =>
                  return "Literal text without placeholders";
               when others =>
                  return "";
            end case;

         when Invalid_Syntax =>
            case Seed mod 8 is
               when 0 =>
                  return "Hello {";
               when 1 =>
                  return "Hello }";
               when 2 =>
                  return "{, plural, one {x} other {y}}";
               when 3 =>
                  return "{count, unknown, one {x} other {y}}";
               when 4 =>
                  return "{count, plural, one {x} other {y}";
               when 5 =>
                  return "{name";
               when 6 =>
                  return "{count, plural, one x other {y}}";
               when others =>
                  return "{gender, select, male {M} female {F} other O}";
            end case;

         when Invalid_Structure =>
            case Seed mod 7 is
               when 0 =>
                  return "{count, plural, one {# file}}";
               when 1 =>
                  return "{gender, select, male {He}}";
               when 2 =>
                  return
                    "{rank, selectordinal, one {#st} two {#nd} other {#th}}";
               when 3 =>
                  return
                    "{rank, selectordinal, one {#st} few {#rd} other {#th}}";
               when 4 =>
                  return
                    "{rank, selectordinal, two {#nd} few {#rd} other {#th}}";
               when 5 =>
                  return "{bad name}";
               when others =>
                  return "{count, plural, other {# files}}";
            end case;

         when Edge_Case_Nesting =>
            case Seed mod 6 is
               when 0 =>
                  return
                    "{gender, select, male {{count, plural, one {{rank, " &
                    "selectordinal, one {#st} two {#nd} few {#rd} " &
                    "other {#th}}} other {many}}} female {F} other {O}}";
               when 1 =>
                  return "{{{{";
               when 2 =>
                  return Large_Valid_Message (Seed);
               when 3 =>
                  return
                    "{count, plural, one {# {name}} other {# {gender, " &
                    "select, male {m} female {f} other {o}}}}";
               when 4 =>
                  return
                    "{gender, select, male {{gender, select, male {M} " &
                    "female {F} other {O}}} female {F} other {O}}";
               when others =>
                  return
                    "{count, plural, one {{count, plural, one {#} " &
                    "other {#}}} other {{count, plural, one {#} other {#}}}}";
            end case;
      end case;
   end Generated_Source;

   procedure Fuzz_Run
   is
      Args : I18N.Arguments.Arguments;
      Runtime : I18N.Runtime.Runtime;
   begin
      for Category in Fuzz_Category loop
         for Seed in 1 .. 128 loop
            declare
               Source : constant String := Generated_Source (Category, Seed);
               First  : constant Classification := Classify_Source (Source);
               Second : constant Classification := Classify_Source (Source);
            begin
               AUnit.Assertions.Assert
                 (Condition => First.Ok = Second.Ok
                   and then First.Error = Second.Error,
                  Message   =>
                    "fuzz classification should be deterministic for: " &
                    Source);

               I18N.Runtime.Compatibility.Initialize_Message (Runtime, Source);
               AUnit.Assertions.Assert
                 (Condition => I18N.Runtime.Is_Valid (Runtime) = First.Ok,
                  Message   =>
                    "runtime validity disagrees with parser/validator for: " &
                    Source);

               if not First.Ok then
                  AUnit.Assertions.Assert
                    (Condition => I18N.Runtime.Compatibility.Last_Error (Runtime) = First.Error,
                     Message   =>
                       "runtime fuzz error classification disagrees for: " &
                       Source);
               end if;
               I18N.Runtime.Finalize (Runtime);

               if First.Ok then
                  Configure_Args (Args, Default_Profile);
                  Assert_AST_IR_Equivalent (Source, Args);
                  Assert_Runtime_Paths_Equivalent (Source, Args);

                  Configure_Args (Args, Count_One_Profile);
                  Assert_AST_IR_Equivalent (Source, Args);
                  Assert_Runtime_Paths_Equivalent (Source, Args);

                  Configure_Args (Args, Gender_Male_Profile);
                  Assert_AST_IR_Equivalent (Source, Args);
                  Assert_Runtime_Paths_Equivalent (Source, Args);

                  Configure_Args (Args, Ordinal_Three_Profile);
                  Assert_AST_IR_Equivalent (Source, Args);
                  Assert_Runtime_Paths_Equivalent (Source, Args);
               end if;
            end;
         end loop;
      end loop;
   end Fuzz_Run;

   procedure Test_Corpus_Golden_Outputs
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Golden_Output ("Hello {name}", Default_Profile, "Hello Ada");
      Assert_Golden_Output
        ("{count, plural, one {# file} other {# files}}",
         Count_One_Profile,
         "1 file");
      Assert_Golden_Output
        ("{count, plural, one {# file} other {# files}}",
         Count_Two_Profile,
         "2 files");
      Assert_Golden_Output
        ("{count, plural, one {# file} other {# files}}",
         Count_Zero_Profile,
         "0 files");
      Assert_Golden_Output
        ("{gender, select, male {He} female {She} other {They}}",
         Gender_Male_Profile,
         "He");
      Assert_Golden_Output
        ("{gender, select, male {He} female {She} other {They}}",
         Gender_Female_Profile,
         "She");
      Assert_Golden_Output
        ("{gender, select, male {He} female {She} other {They}}",
         Gender_Other_Profile,
         "They");
      Assert_Golden_Output
        ("{gender, select, male {He} female {She} other {They}} wrote " &
         "{count, plural, one {# line} other {# lines}}",
         Default_Profile,
         "She wrote 2 lines");
   end Test_Corpus_Golden_Outputs;

   procedure Test_Ordinal_Boundary_Corpus
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Source : constant String :=
        "{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}";
   begin
      Assert_Golden_Output (Source, Ordinal_One_Profile, "1st");
      Assert_Golden_Output (Source, Ordinal_Two_Profile, "2nd");
      Assert_Golden_Output (Source, Ordinal_Three_Profile, "3rd");
      Assert_Golden_Output (Source, Ordinal_Eleven_Profile, "11th");
      Assert_Golden_Output (Source, Ordinal_Twelve_Profile, "12th");
      Assert_Golden_Output (Source, Ordinal_Thirteen_Profile, "13th");
   end Test_Ordinal_Boundary_Corpus;

   procedure Test_Corpus_AST_IR_Differential
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : I18N.Arguments.Arguments;
   begin
      Configure_Args (Args, Default_Profile);
      Assert_AST_IR_Equivalent ("Hello {name}", Args);
      Assert_AST_IR_Equivalent
        ("{count, plural, one {# file} other {# files}}", Args);
      Assert_AST_IR_Equivalent
        ("{gender, select, male {He} female {She} other {They}}", Args);
      Assert_AST_IR_Equivalent
        ("{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",
         Args);
      Assert_AST_IR_Equivalent
        ("{count, plural, one {{rank, selectordinal, one {#st} " &
         "two {#nd} few {#rd} other {#th}}} other {{gender, select, " &
         "male {M} female {F} other {O}}}}",
         Args);
      Assert_AST_IR_Equivalent (Large_Valid_Message (17), Args);
      Assert_AST_IR_Equivalent (Large_Repeated_Message, Args);
   end Test_Corpus_AST_IR_Differential;

   procedure Test_Fuzz_Run_Is_Robust
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Fuzz_Run;
   end Test_Fuzz_Run_Is_Robust;

   procedure Test_Error_Classification_Is_Stable
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Invalid_Source
        ("{count, plural, one {# file}}",
         I18N.Errors.Missing_Branch);
      Assert_Invalid_Source
        ("{gender, select, male {He}}",
         I18N.Errors.Missing_Branch);
      --  Only "other" is mandatory for selectordinal; a selectordinal that
      --  omits "other" is the missing-branch case (missing one/two/few are
      --  valid and fall back to "other").
      Assert_Invalid_Source
        ("{rank, selectordinal, one {#st} two {#nd} few {#rd}}",
         I18N.Errors.Missing_Branch);
      Assert_Invalid_Source
        ("Hello {",
         I18N.Errors.Unbalanced_Braces);
      Assert_Invalid_Source
        ("Hello }",
         I18N.Errors.Unbalanced_Braces);
      Assert_Invalid_Source
        ("{bad name}",
         I18N.Errors.Parse_Error);
   end Test_Error_Classification_Is_Stable;

   procedure Test_Runtime_Render_Error_Invariants
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Render_Error
        ("Hello {name}",
         Missing_Name_Profile,
         I18N.Errors.Missing_Variable);
      Assert_Render_Error
        ("{count, plural, one {# file} other {# files}}",
         Non_Numeric_Count_Profile,
         I18N.Errors.Invalid_Selector);
      Assert_Render_Error
        ("{rank, selectordinal, one {#st} two {#nd} few {#rd} other {#th}}",
         Non_Numeric_Ordinal_Profile,
         I18N.Errors.Invalid_Ordinal);
   end Test_Runtime_Render_Error_Invariants;

   procedure Test_Runtime_Context_And_Cache_Invariants
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Args : I18N.Arguments.Arguments;
      Source : constant String :=
        "{gender, select, male {He} female {She} other {They}} has " &
        "{count, plural, one {# file} other {# files}}";
      First_Runtime  : I18N.Runtime.Runtime;
      Second_Runtime : I18N.Runtime.Runtime;
   begin
      Configure_Args (Args, Default_Profile);
      Assert_Runtime_Paths_Equivalent (Source, Args);

      I18N.Runtime.Compatibility.Initialize_Message (First_Runtime, Source);
      I18N.Runtime.Compatibility.Initialize_Message (Second_Runtime, Source);
      AUnit.Assertions.Assert
        (Condition => I18N.Runtime.Is_Valid (First_Runtime)
          and then I18N.Runtime.Is_Valid (Second_Runtime),
         Message   => "repeated initialization should remain valid");

      declare
         First_Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (First_Runtime, Args);
         Second_Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Second_Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => Same_Result (First_Result, Second_Result),
            Message   => "cache-backed repeated initialization changed output");
      end;

      I18N.Runtime.Finalize (First_Runtime);
      I18N.Runtime.Finalize (Second_Runtime);
   exception
      when others =>
         I18N.Runtime.Finalize (First_Runtime);
         I18N.Runtime.Finalize (Second_Runtime);
         raise;
   end Test_Runtime_Context_And_Cache_Invariants;

   procedure Test_Additional_Invalid_Grammar_Corpus
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Invalid_Source
        ("{count, plural, one {x} one {y} other {z}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{gender, select, male {M} male {X} other {O}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{rank, selectordinal, one {1} two {2} few {3} few {4} other {o}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{count, plural, zero {0} other {n}}",
         I18N.Errors.Parse_Error);
      --  Generalized select accepts arbitrary identifier branch names, so a
      --  duplicate generalized branch (not an unknown one) is the malformed
      --  case here.
      Assert_Invalid_Source
        ("{gender, select, unknown {U} unknown {V} other {O}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{rank, selectordinal, many {M} other {O}}",
         I18N.Errors.Parse_Error);
   end Test_Additional_Invalid_Grammar_Corpus;

   procedure Test_Deterministic_Runtime_Rendering
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert_Golden_Output
        ("{gender, select, male {He} female {She} other {They}} has " &
         "{count, plural, one {# file} other {# files}}",
         Default_Profile,
         "She has 2 files");
   end Test_Deterministic_Runtime_Rendering;

   overriding function Name
     (T : Test_Case)
      return AUnit.Message_String
   is
      pragma Unreferenced (T);
   begin
      return AUnit.Format
        ("I18N fuzz/corpus/differential validation tests");
   end Name;

   overriding procedure Register_Tests
     (T : in out Test_Case)
   is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Corpus_Golden_Outputs'Access,
         "corpus golden outputs stay stable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Ordinal_Boundary_Corpus'Access,
         "ordinal boundary corpus remains stable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Corpus_AST_IR_Differential'Access,
         "AST renderer and IR renderer match on corpus cases");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Fuzz_Run_Is_Robust'Access,
         "deterministic fuzz harness does not crash and preserves equivalence");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Error_Classification_Is_Stable'Access,
         "invalid corpus classification remains stable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Runtime_Render_Error_Invariants'Access,
         "runtime render error classifications stay stable");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Runtime_Context_And_Cache_Invariants'Access,
         "runtime context render, Render_Into, and cache reuse remain equivalent");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Additional_Invalid_Grammar_Corpus'Access,
         "additional malformed grammar corpus remains deterministic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Deterministic_Runtime_Rendering'Access,
         "same source and args produce deterministic output");
   end Register_Tests;

end I18N.Runtime.Tests.Corpus;
