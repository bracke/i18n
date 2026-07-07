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
with I18N.Result;
with I18N.Runtime.Compatibility;
with I18N.Validation;
with I18N.Arguments;

package body I18N.Runtime.Tests.Corpus is
   use type I18N.Result.Render_Status;

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
      I18N.Arguments.Set (Args, "value", "12345.67");
      I18N.Arguments.Set (Args, "amount", "123.45");
      I18N.Arguments.Set (Args, "day", "2024-02-29");
      I18N.Arguments.Set (Args, "clock", "09:05:07");
      I18N.Arguments.Set (Args, "instant", "2024-02-29T23:30:00Z");
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
                  case Seed mod 4 is
                     when 0 =>
                        return "Total {value, number}";
                     when 1 =>
                        return "Due {amount, currency, USD}";
                     when 2 =>
                        return "When {day, date, long} {clock, time, short}";
                     when others =>
                        return "Instant {instant, datetime, short, UTC}";
                  end case;
               when others =>
                  return "";
            end case;

         when Invalid_Syntax =>
            case Seed mod 14 is
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
               when 7 =>
                  return "{count, number, ::percent'}";
               when 8 =>
                  return "{amount, currency, }";
               when 9 =>
                  return "{day, date, ::yyyy'-'MM";
               when 10 =>
                  return "{count, number, ::precision}";
               when 11 =>
                  return "{amount, number, ::currency/}";
               when 12 =>
                  return "{day, date, short,}";
               when 13 =>
                  return "{clock, time, ::hh-mm, Europe/Berlin, UTC}";
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

   function Parser_Format_Source (Seed : Positive) return String is
   begin
      case Seed mod 60 is
         when 0 =>
            return "{value, number}";
         when 1 =>
            return "{amount, number, ::currency/USD}";
         when 2 =>
            return "{amount, currency, USD}";
         when 3 =>
            return "{day, date, short}";
         when 4 =>
            return "{day, date, medium, UTC}";
         when 5 =>
            return "{clock, time, long, Europe/Berlin}";
         when 6 =>
            return "{instant, datetime, full, America/New_York}";
         when 7 =>
            return "{day, date, ::yMMMd}";
         when 8 =>
            return "{clock, time, ::hhmmssa}";
         when 9 =>
            return "{instant, datetime, ::yMdHHmmssz, UTC}";
         when 10 =>
            return "{amount, currency, USD/accounting}";
         when 11 =>
            return "{amount, number, ::currency/CHF/cash}";
         when 12 =>
            return "{value, number, ::percent}";
         when 13 =>
            return "{value, number, ::scientific}";
         when 14 =>
            return "{value, number, ::precision-fraction/2}";
         when 15 =>
            return "{value, number, ::currency/usd}";
         when 16 =>
            return "{amount, currency, US}";
         when 17 =>
            return "{day, date, compact}";
         when 18 =>
            return "{clock, time, long, Mars/Base}";
         when 19 =>
            return "{instant, datetime, full, +25:00}";
         when 20 =>
            return "{value, number, ::currency/USDX}";
         when 21 =>
            return "{amount, currency, 12A}";
         when 22 =>
            return "{amount, currency, USD/bogus}";
         when 23 =>
            return "{day, date, short, UTC, extra}";
         when 24 =>
            return "{day, date, ::y%}";
         when 25 =>
            return "{day, date, ::short}";
         when 26 =>
            return "{clock, time, ::long}";
         when 27 =>
            return "{instant, datetime, ::short, UTC}";
         when 28 =>
            return "{value, number, ::scale/x}";
         when 29 =>
            return "{amount, currency, USD/}";
         when 30 =>
            return "{value, number, ::precision-fraction/a}";
         when 31 =>
            return "{day, date, ::yyyy'Q'Q}";
         when 32 =>
            return "{value, number, ::precision/increment/-1}";
         when 33 =>
            return "{amount, currency, XXX}";
         when 34 =>
            return "{day, date, ::'";
         when 35 =>
            return "{count, plural, one {x} two {y} other {z}";
         when 36 =>
            return "{value, number, ::scale/x}";
         when 37 =>
            return "{clock, time, ::long, Europe/Berlin, UTC}";
         when 38 =>
            return "{instant, datetime, ::short, Not/A_Zone}";
         when 39 =>
            return "{clock, time, ::short, UTC, extra}";
         when 40 =>
            return "{amount, number, ::currency/USD cash unit-width-narrow}";
         when 41 =>
            return "{day, date, ::yyyy-MM}";
         when 42 =>
            return "{day, date, ::'yyyy-'}";
         when 43 =>
            return "{value, number, ::currency/USD/precision}";
         when 44 =>
            return "{value, number, ::currency/USD/abc}";
         when 45 =>
            return "{count, number, ::precision-fraction}";
         when 46 =>
            return "{value, number, ::scale/1+}";
         when 47 =>
            return "{day, date, ::yyyy-MM-#}";
         when 48 =>
            return "{clock, time, ::HH-m }";
         when 49 =>
            return "{value, number, ::unit-width-full-name}";
         when 50 =>
            return "{value, number, ::group-min2 precision-fraction/0-2}";
         when 51 =>
            return "{value, number, ::sign/accounting precision-increment/0.05}";
         when 52 =>
            return "{amount, number, ::currency/JPY precision-currency/standard}";
         when 53 =>
            return "{amount, number, ::currency/CHF precision-currency/cash sign/accounting}";
         when 54 =>
            return "{day, date, ::QQQQQ'/'MMMMM'/'ccccc}";
         when 55 =>
            return "{clock, time, ::HH':'mm':'ss'.'SSSSSSSSS}";
         when 56 =>
            return "{instant, datetime, ::yyyyMMdd'T'HHmmssXXXXX, Europe/Berlin}";
         when 57 =>
            return "{value, number, ::precision-significant/3-1}";
         when 58 =>
            return "{amount, number, ::currency/USD precision-currency/cash/extra}";
         when 59 =>
            return "{instant, datetime, ::yyyy-MM-dd HH:mm, UTC}";
         when others =>
            return "{clock, time,}";
      end case;
   end Parser_Format_Source;

   procedure Test_Parser_Format_Fuzz
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      for Seed in 1 .. 256 loop
         declare
            Source : constant String := Parser_Format_Source (Seed);
            First  : constant Classification := Classify_Source (Source);
            Second : constant Classification := Classify_Source (Source);
            First_Catalog : constant I18N.Runtime.Catalog_Validation_Result :=
              I18N.Runtime.Validate_Catalog_Text
                ("parser_format_fuzz",
                 "en.case = """ & Source & """" & ASCII.LF);
            Second_Catalog : constant I18N.Runtime.Catalog_Validation_Result :=
              I18N.Runtime.Validate_Catalog_Text
                ("parser_format_fuzz",
                 "en.case = """ & Source & """" & ASCII.LF);
         begin
            AUnit.Assertions.Assert
              (Condition => First.Ok = Second.Ok
                and then First.Error = Second.Error,
               Message   =>
                 "formatted parser fuzz classification changed for: " &
                 Source);
            AUnit.Assertions.Assert
              (Condition => First.Ok = First_Catalog.Valid
                and then First_Catalog.Valid = Second_Catalog.Valid,
               Message   =>
                 "catalog validation disagrees with parser fuzz for: " &
                 Source);
         end;
      end loop;
   end Test_Parser_Format_Fuzz;

   procedure Test_Formatted_Value_Fuzz
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      Runtime : I18N.Runtime.Instance;
      Args    : I18N.Arguments.Arguments;
      Load    : I18N.Runtime.Load_Result;

      function Status_Of (Key : String) return I18N.Result.Render_Status is
         Result : constant I18N.Result.Render_Result :=
           I18N.Runtime.Render (Runtime, "en", Key, Args);
      begin
         return Result.Status;
      end Status_Of;

      procedure Expect
        (Key    : String;
         Name   : String;
         Value  : String;
         Status : I18N.Result.Render_Status;
         Label  : String) is
      begin
         I18N.Arguments.Clear (Args);
         I18N.Arguments.Set (Args, Name, Value);
         AUnit.Assertions.Assert
           (Condition => Status_Of (Key) = Status,
            Message   => Label & " value=" & Value);
      end Expect;
   begin
      I18N.Runtime.Load_Text
        (Runtime, "formatted-value-fuzz",
         "en.number = ""{value, number}""" & ASCII.LF
         & "en.currency = ""{amount, currency, USD}""" & ASCII.LF
         & "en.date = ""{day, date}""" & ASCII.LF
         & "en.time = ""{clock, time}""" & ASCII.LF
         & "en.datetime = ""{instant, datetime, short, UTC}""" & ASCII.LF
         & "en.date_bad_time_field = ""{day, date, ::yMdH}""" & ASCII.LF
         & "en.time_bad_date_field = ""{clock, time, ::Hmsd}""" & ASCII.LF
         & "en.datetime_bad_zone = ""{instant, datetime, short, Not/A_Zone}"""
         & ASCII.LF
         & "en.datetime_bad_offset = ""{instant, datetime, short, +24:00}"""
         & ASCII.LF
         & "en.datetime_ut_time = ""{instant, time, long, UT}""" & ASCII.LF
         & "en.datetime_ut_lower_time = ""{instant, time, long, ut}""" & ASCII.LF
         & ASCII.LF
         & "en.duration = ""{seconds, duration}""" & ASCII.LF
         & "en.bytes = ""{size, bytes}""" & ASCII.LF
         & "en.unit = ""{distance, unit, kilometer}""" & ASCII.LF
         & "en.unit_rate = ""{distance, unit, meter/unit-width-short/second}"""
         & ASCII.LF
         & "en.measure = ""{distance, number, ::measure-unit/length-kilometer "
         & "unit-width-short per-measure-unit/duration-hour}"""
         & ASCII.LF
         & "en.relative = ""{offset, relative, day}""" & ASCII.LF
         & "en.list = ""{items, list}""" & ASCII.LF,
         Load);
      AUnit.Assertions.Assert
        (Condition => Load.Status = I18N.Runtime.Loaded,
         Message   => "formatted-value fuzz catalog should load");

      for Seed in 1 .. 1440 loop
         case Seed mod 144 is
            when 0 =>
               Expect ("number", "value", "12345.67", I18N.Result.Success,
                       "valid decimal should render");
            when 1 =>
               Expect ("number", "value", "", I18N.Result.Invalid_Argument,
                       "empty decimal should fail");
            when 2 =>
               Expect ("number", "value", "1e3", I18N.Result.Invalid_Argument,
                       "exponent decimal should fail");
            when 3 =>
               Expect ("number", "value", "12 345", I18N.Result.Invalid_Argument,
                       "spaced decimal should fail");
            when 4 =>
               Expect ("number", "value", ".12", I18N.Result.Invalid_Argument,
                       "missing leading digit should fail");
            when 5 =>
               Expect ("number", "value", "+1", I18N.Result.Success,
                       "leading plus number should render");
            when 6 =>
               Expect ("number", "value", "-1", I18N.Result.Success,
                       "leading minus number should render");
            when 7 =>
               Expect ("number", "value", "++1", I18N.Result.Invalid_Argument,
                       "double-plus number should fail");
            when 8 =>
               Expect ("number", "value", "--1", I18N.Result.Invalid_Argument,
                       "double-minus number should fail");
            when 9 =>
               Expect ("number", "value", " +123", I18N.Result.Invalid_Argument,
                       "leading-space number should fail");
            when 10 =>
               Expect ("currency", "amount", "123.45", I18N.Result.Success,
                       "valid currency amount should render");
            when 11 =>
               Expect ("currency", "amount", "+123.45", I18N.Result.Success,
                       "leading plus currency amount should render");
            when 12 =>
               Expect ("currency", "amount", "1e3", I18N.Result.Invalid_Argument,
                       "currency exponent amount should fail");
            when 13 =>
               Expect ("currency", "amount", "12.", I18N.Result.Invalid_Argument,
                       "empty currency fraction should fail");
            when 14 =>
               Expect ("currency", "amount", ".12", I18N.Result.Invalid_Argument,
                       "missing currency integer should fail");
            when 15 =>
               Expect ("currency", "amount", "12a", I18N.Result.Invalid_Argument,
                       "currency suffix should fail");
            when 16 =>
               Expect ("currency", "amount", "12.34.56",
                       I18N.Result.Invalid_Argument,
                       "double-decimal currency should fail");
            when 17 =>
               Expect ("currency", "amount", " 12.34", I18N.Result.Invalid_Argument,
                       "leading-space currency should fail");
            when 18 =>
               Expect ("date", "day", "2024-02-29", I18N.Result.Success,
                       "valid leap-day date should render");
            when 19 =>
               Expect ("date", "day", "2024-02-30", I18N.Result.Invalid_Argument,
                        "invalid calendar day should fail");
            when 20 =>
               Expect ("date", "day", "2024-2-29", I18N.Result.Invalid_Argument,
                        "unpadded date should fail");
            when 21 =>
               Expect ("date", "day", "2024/02/29", I18N.Result.Invalid_Argument,
                        "slash date should fail");
            when 22 =>
               Expect ("date", "day", "2024-13-01", I18N.Result.Invalid_Argument,
                       "invalid calendar month should fail");
            when 23 =>
               Expect ("time", "clock", "09:05:07", I18N.Result.Success,
                        "valid time should render");
            when 24 =>
               Expect ("time", "clock", "24:00", I18N.Result.Invalid_Argument,
                        "invalid hour should fail");
            when 25 =>
               Expect ("time", "clock", "09:60", I18N.Result.Invalid_Argument,
                        "invalid minute should fail");
            when 26 =>
               Expect ("time", "clock", "09:00:60", I18N.Result.Invalid_Argument,
                       "invalid second should fail");
            when 27 =>
               Expect ("time", "clock", "09:05:07.123456789", I18N.Result.Success,
                       "max nanosecond precision should render");
            when 28 =>
               Expect ("time", "clock", "09:05:07.1234567890",
                       I18N.Result.Invalid_Argument,
                       "excessive time fraction should fail");
            when 29 =>
               Expect ("time", "clock", "9:05", I18N.Result.Invalid_Argument,
                        "unpadded time should fail");
            when 30 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00Z",
                        I18N.Result.Success,
                        "valid instant should render");
            when 31 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00",
                        I18N.Result.Invalid_Argument,
                        "offset-free instant should fail");
            when 32 =>
               Expect ("datetime", "instant", "2024-02-30T23:30:00Z",
                        I18N.Result.Invalid_Argument,
                        "invalid instant date should fail");
            when 33 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+2:00",
                        I18N.Result.Invalid_Argument,
                        "single-hour colon instant offset should fail");
            when 34 =>
               Expect ("datetime", "instant", "2024-02-29 23:30:00Z",
                       I18N.Result.Success,
                       "space separator instant should render");
            when 35 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01:00:00",
                       I18N.Result.Success,
                       "instant accepts second-precision offsets");
            when 36 =>
               Expect ("duration", "seconds", "3661", I18N.Result.Success,
                        "valid duration seconds should render");
            when 37 =>
               Expect ("duration", "seconds", "1.5",
                        I18N.Result.Invalid_Argument,
                        "fractional duration seconds should fail");
            when 38 =>
               Expect ("duration", "seconds", "abc",
                        I18N.Result.Invalid_Argument,
                        "non-numeric duration seconds should fail");
            when 39 =>
               Expect ("duration", "seconds", "9223372036854775808",
                        I18N.Result.Invalid_Argument,
                        "overflowing duration seconds should fail");
            when 40 =>
               Expect ("bytes", "size", "2048", I18N.Result.Success,
                        "valid byte size should render");
            when 41 =>
               Expect ("bytes", "size", "12.5",
                        I18N.Result.Invalid_Argument,
                        "fractional byte size should fail");
            when 42 =>
               Expect ("bytes", "size", "-1",
                        I18N.Result.Invalid_Argument,
                        "negative byte size should fail");
            when 43 =>
               Expect ("bytes", "size", "2 KiB",
                        I18N.Result.Invalid_Argument,
                        "byte size with unit text should fail");
            when 44 =>
               Expect ("unit", "distance", "1.5", I18N.Result.Success,
                        "valid unit decimal should render");
            when 45 =>
               Expect ("unit", "distance", "1.2.3",
                        I18N.Result.Invalid_Argument,
                        "malformed unit decimal should fail");
            when 46 =>
               Expect ("unit", "distance", "",
                        I18N.Result.Invalid_Argument,
                        "empty unit decimal should fail");
            when 47 =>
               Expect ("unit", "distance", "1e3",
                        I18N.Result.Invalid_Argument,
                        "unit decimal exponent notation should fail");
            when 48 =>
               Expect ("relative", "offset", "-2", I18N.Result.Success,
                        "valid relative offset should render");
            when 49 =>
               Expect ("relative", "offset", "1.5",
                        I18N.Result.Invalid_Argument,
                        "fractional relative offset should fail");
            when 50 =>
               Expect ("relative", "offset", "+",
                        I18N.Result.Invalid_Argument,
                        "sign-only relative offset should fail");
            when 51 =>
               Expect ("relative", "offset", "tomorrow",
                        I18N.Result.Invalid_Argument,
                        "word relative offset should fail");
            when 52 =>
               Expect ("list", "items", "red|green|blue",
                        I18N.Result.Success,
                        "valid pipe-delimited list should render");
            when 53 =>
               Expect ("list", "items", "",
                        I18N.Result.Invalid_Argument,
                        "empty list should fail");
            when 54 =>
               Expect ("list", "items", "red||blue",
                        I18N.Result.Invalid_Argument,
                        "empty list item should fail");
            when 55 =>
               Expect ("list", "items", "|red",
                        I18N.Result.Invalid_Argument,
                        "leading empty list item should fail");
            when 56 =>
               Expect ("date_bad_time_field", "day", "2024-02-29",
                        I18N.Result.Invalid_Argument,
                        "date skeleton with time fields should fail");
            when 57 =>
               Expect ("time_bad_date_field", "clock", "09:05:07",
                        I18N.Result.Invalid_Argument,
                        "time skeleton with date fields should fail");
            when 58 =>
               Expect ("datetime_bad_zone", "instant",
                        "2024-02-29T23:30:00Z",
                        I18N.Result.Invalid_Argument,
                        "unknown datetime target zone should fail");
            when 59 =>
               Expect ("datetime_bad_offset", "instant",
                        "2024-02-29T23:30:00Z",
                        I18N.Result.Invalid_Argument,
                        "out-of-range datetime target offset should fail");
            when 60 =>
               Expect ("duration", "seconds", "",
                       I18N.Result.Invalid_Argument,
                       "empty duration seconds should fail");
            when 61 =>
               Expect ("bytes", "size", "",
                       I18N.Result.Invalid_Argument,
                       "empty byte size should fail");
            when 62 =>
               Expect ("relative", "offset", "",
                       I18N.Result.Invalid_Argument,
                       "empty relative offset should fail");
            when 63 =>
               Expect ("number", "value", "+0", I18N.Result.Success,
                       "positive zero should render");
            when 64 =>
               Expect ("number", "value", "-0.00", I18N.Result.Success,
                       "negative zero with fraction should render");
            when 65 =>
               Expect ("number", "value", "0.",
                       I18N.Result.Invalid_Argument,
                       "empty number fraction should fail");
            when 66 =>
               Expect ("currency", "amount", "000", I18N.Result.Success,
                       "leading-zero currency amount should render");
            when 67 =>
               Expect ("currency", "amount", "1,00",
                       I18N.Result.Invalid_Argument,
                       "currency grouping punctuation should fail");
            when 68 =>
               Expect ("currency", "amount", "1e2", I18N.Result.Invalid_Argument,
                       "currency exponent notation should fail");
            when 69 =>
               Expect ("date", "day", "2000-02-29", I18N.Result.Success,
                       "valid leap date from non-century year should render");
            when 70 =>
               Expect ("date", "day", "2019-02-29", I18N.Result.Invalid_Argument,
                       "invalid leap date should fail");
            when 71 =>
               Expect ("date", "day", "2024-04-31", I18N.Result.Invalid_Argument,
                       "invalid month day should fail");
               Expect ("datetime_ut_time", "instant",
                       "2024-02-29T23:30:00Z",
                       I18N.Result.Success,
                       "UT target-zone alias should render");
            when 72 =>
               Expect ("time", "clock", "23:59:59.999999999",
                       I18N.Result.Success,
                       "max precision time fraction should render");
               Expect ("datetime_ut_lower_time", "instant",
                       "2024-02-29T23:30:00Z",
                       I18N.Result.Success,
                       "lowercase ut target-zone alias should render");
            when 73 =>
               Expect ("time", "clock", "23:59:59.000000000",
                       I18N.Result.Success,
                       "zeroed max precision time fraction should render");
            when 74 =>
               Expect ("time", "clock", "23:59:60.000",
                       I18N.Result.Invalid_Argument,
                       "overflow instant second should fail");
            when 75 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01:00",
                       I18N.Result.Success,
                       "offset instant with colons should render");
            when 76 =>
               Expect ("datetime", "instant", "2024-02-29 23:30:00+0100",
                       I18N.Result.Success,
                       "offset instant with hhmm should render");
            when 77 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01",
                       I18N.Result.Success,
                       "offset instant with hour-only should render");
            when 78 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00-0",
                       I18N.Result.Invalid_Argument,
                       "malformed instant offset should fail");
            when 79 =>
               Expect ("datetime", "instant", "2024-02-29T23:60:00Z",
                       I18N.Result.Invalid_Argument,
                       "invalid instant minute should fail");
            when 80 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01:00:00",
                       I18N.Result.Success,
                       "instant accepts second-precision offsets");
            when 81 =>
               Expect ("datetime", "instant", "2024-02-29 23:30:00+01:00",
                       I18N.Result.Success,
                       "space-separator instant with colons should render");
            when 82 =>
               Expect ("datetime", "instant", "2024-02-29t23:30:00Z",
                       I18N.Result.Invalid_Argument,
                       "lowercase separator instant should fail");
            when 83 =>
               Expect ("duration", "seconds", "0", I18N.Result.Success,
                       "zero duration should render");
            when 84 =>
               Expect ("number", "value", "000123", I18N.Result.Success,
                       "leading-zero number should render");
            when 85 =>
               Expect ("number", "value", "+0.00", I18N.Result.Success,
                       "positive zero fraction should render");
            when 86 =>
               Expect ("number", "value", "-.5", I18N.Result.Invalid_Argument,
                       "missing integer negative decimal should fail");
            when 87 =>
               Expect ("number", "value", "1_000", I18N.Result.Invalid_Argument,
                       "underscore grouped number should fail");
            when 88 =>
               Expect ("currency", "amount", "-0.01", I18N.Result.Success,
                       "negative fractional currency amount should render");
            when 89 =>
               Expect ("currency", "amount", "+0.00", I18N.Result.Success,
                       "positive zero currency amount should render");
            when 90 =>
               Expect ("currency", "amount", "NaN", I18N.Result.Invalid_Argument,
                       "NaN currency amount should fail");
            when 91 =>
               Expect ("currency", "amount", "Infinity",
                       I18N.Result.Invalid_Argument,
                       "infinite currency amount should fail");
            when 92 =>
               Expect ("date", "day", "1900-02-29",
                       I18N.Result.Invalid_Argument,
                       "non-leap century date should fail");
            when 93 =>
               Expect ("date", "day", "2400-02-29", I18N.Result.Success,
                       "leap century date should render");
            when 94 =>
               Expect ("date", "day", "2024-00-01",
                       I18N.Result.Invalid_Argument,
                       "zero month should fail");
            when 95 =>
               Expect ("date", "day", "2024-01-00",
                       I18N.Result.Invalid_Argument,
                       "zero day should fail");
            when 96 =>
               Expect ("time", "clock", "00:00", I18N.Result.Success,
                       "midnight minute precision should render");
            when 97 =>
               Expect ("time", "clock", "00:00:00.1", I18N.Result.Success,
                       "single fractional second digit should render");
            when 98 =>
               Expect ("time", "clock", "00:00:00.",
                       I18N.Result.Invalid_Argument,
                       "empty time fraction should fail");
            when 99 =>
               Expect ("time", "clock", "09:05:",
                       I18N.Result.Invalid_Argument,
                       "missing second should fail");
            when 100 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00.123Z",
                       I18N.Result.Success,
                       "fractional UTC instant should render");
            when 101 =>
               Expect ("datetime", "instant",
                       "2024-02-29T23:30:00.123456789+0130",
                       I18N.Result.Success,
                       "fractional hhmm offset instant should render");
            when 102 =>
               Expect ("datetime", "instant",
                       "2024-02-29T23:30:00.1234567890Z",
                       I18N.Result.Invalid_Argument,
                       "overprecise fractional instant should fail");
            when 103 =>
               Expect ("relative", "offset", "+2", I18N.Result.Success,
                       "positive signed relative offset should render");
            when 104 =>
               Expect ("list", "items", "single", I18N.Result.Success,
                       "single list item should render");
            when 105 =>
               Expect ("unit", "distance", "+1.25", I18N.Result.Success,
                       "positive signed unit decimal should render");
            when 106 =>
               Expect ("unit", "distance", "-1.25", I18N.Result.Success,
                       "negative signed unit decimal should render");
            when 107 =>
               Expect ("unit", "distance", "+", I18N.Result.Invalid_Argument,
                       "sign-only unit decimal should fail");
            when 108 =>
               Expect ("unit", "distance", "-.25", I18N.Result.Invalid_Argument,
                       "missing integer unit decimal should fail");
            when 109 =>
               Expect ("unit_rate", "distance", "3.5", I18N.Result.Success,
                       "per-unit decimal should render");
            when 110 =>
               Expect ("unit_rate", "distance", "3.", I18N.Result.Invalid_Argument,
                       "per-unit empty fraction should fail");
            when 111 =>
               Expect ("unit_rate", "distance", "3,5",
                       I18N.Result.Invalid_Argument,
                       "per-unit localized decimal input should fail");
            when 112 =>
               Expect ("measure", "distance", "12.5", I18N.Result.Success,
                       "measure-unit number skeleton should render");
            when 113 =>
               Expect ("measure", "distance", "+12.5", I18N.Result.Success,
                       "signed measure-unit number should render");
            when 114 =>
               Expect ("measure", "distance", "12.5.1",
                       I18N.Result.Invalid_Argument,
                       "malformed measure-unit number should fail");
            when 115 =>
               Expect ("measure", "distance", "12 km",
                       I18N.Result.Invalid_Argument,
                       "measure-unit value with unit suffix should fail");
            when 116 =>
               Expect ("relative", "offset", "-0", I18N.Result.Success,
                       "negative zero relative offset should render");
            when 117 =>
               Expect ("relative", "offset", "0002", I18N.Result.Success,
                       "leading-zero relative offset should render");
            when 118 =>
               Expect ("relative", "offset", "--2",
                       I18N.Result.Invalid_Argument,
                       "double-signed relative offset should fail");
            when 119 =>
               Expect ("relative", "offset", "2 days",
                       I18N.Result.Invalid_Argument,
                       "relative offset with unit suffix should fail");
            when 120 =>
               Expect ("list", "items", "red|green", I18N.Result.Success,
                       "two-item list should render");
            when 121 =>
               Expect ("list", "items", "red |green", I18N.Result.Success,
                       "list item spaces are literal content");
            when 122 =>
               Expect ("list", "items", "red| green", I18N.Result.Success,
                       "leading item space is literal content");
            when 123 =>
               Expect ("list", "items", "red| |blue", I18N.Result.Success,
                       "space-only list item is literal content");
            when 124 =>
               Expect ("bytes", "size", "+2048", I18N.Result.Invalid_Argument,
                       "positive signed byte size should fail");
            when 125 =>
               Expect ("duration", "seconds", "+3661",
                       I18N.Result.Invalid_Argument,
                       "positive signed duration should fail");
            when 126 =>
               Expect ("number", "value", "-+1",
                       I18N.Result.Invalid_Argument,
                       "double-signed number should fail");
            when 127 =>
               Expect ("number", "value", "0..1",
                       I18N.Result.Invalid_Argument,
                       "multiple decimal points should fail");
            when 128 =>
               Expect ("currency", "amount", "-+1.00",
                       I18N.Result.Invalid_Argument,
                       "double-signed currency amount should fail");
            when 129 =>
               Expect ("currency", "amount", "+1.",
                       I18N.Result.Invalid_Argument,
                       "trailing decimal point currency should fail");
            when 130 =>
               Expect ("date", "day", "24-02-29",
                       I18N.Result.Invalid_Argument,
                       "short year date should fail");
            when 131 =>
               Expect ("datetime", "instant", "2024-02-29 23:30:00+24:00",
                       I18N.Result.Invalid_Argument,
                       "out-of-range instant hour offset should fail");
            when 132 =>
               Expect ("number", "value", "+.5",
                       I18N.Result.Invalid_Argument,
                       "number with missing integer and leading dot should fail");
            when 133 =>
               Expect ("number", "value", "1e+2",
                       I18N.Result.Invalid_Argument,
                       "number exponent notation should fail");
            when 134 =>
               Expect ("number", "value", "1,234",
                       I18N.Result.Invalid_Argument,
                       "number grouping punctuation should fail");
            when 135 =>
               Expect ("currency", "amount", "1,234.56",
                       I18N.Result.Invalid_Argument,
                       "currency grouping punctuation should fail");
            when 136 =>
               Expect ("currency", "amount", "-",
                       I18N.Result.Invalid_Argument,
                       "sign-only currency amount should fail");
            when 137 =>
               Expect ("date", "day", "2024-02-29",
                       I18N.Result.Success,
                       "valid date baseline in fuzz remains");
            when 138 =>
               Expect ("datetime", "instant", "2024-02-29T23:30",
                       I18N.Result.Invalid_Argument,
                       "instant missing seconds should fail");
            when 139 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01:60",
                       I18N.Result.Invalid_Argument,
                       "instant with out-of-range offset minutes should fail");
            when 140 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+2400",
                       I18N.Result.Invalid_Argument,
                       "instant with out-of-range offset hour should fail");
            when 141 =>
               Expect ("datetime", "instant", "2024-02-29T23:30:00+01:00:0",
                       I18N.Result.Invalid_Argument,
                       "instant with malformed offset seconds should fail");
            when 142 =>
               Expect ("time", "clock", "09:05:07.",
                       I18N.Result.Invalid_Argument,
                       "clock with dangling decimal point should fail");
            when 143 =>
               Expect ("time", "clock", "09:05:07.  ",
                       I18N.Result.Invalid_Argument,
                       "clock fraction with trailing spaces should fail");
            when others =>
               Expect ("list", "items", "red|green|",
                       I18N.Result.Invalid_Argument,
                       "trailing empty list item should fail");
         end case;
      end loop;
   end Test_Formatted_Value_Fuzz;

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
      I18N.Arguments.Set (Args, "count", "1.5");
      Assert_AST_IR_Equivalent
        ("{count, plural, =1 {exact #} one {one #} other {other #}}",
         Args);
      I18N.Arguments.Set (Args, "count", "2");
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
        ("{count, plural, zero {0} zero {z} other {n}}",
         I18N.Errors.Parse_Error);
      --  Generalized select accepts arbitrary identifier branch names, so a
      --  duplicate generalized branch (not an unknown one) is the malformed
      --  case here.
      Assert_Invalid_Source
        ("{gender, select, unknown {U} unknown {V} other {O}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{rank, selectordinal, many {M} many {N} other {O}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{rank, selectordinal, zero {Z} zero {N} other {O}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{day, date, ::yyyy{MM}}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{clock, time, ::HH' oclock}",
         I18N.Errors.Unbalanced_Braces);
      Assert_Invalid_Source
        ("{instant, datetime, ::yyyy','MM, }",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{value, number, ::scale/0}",
         I18N.Errors.Parse_Error);
      Assert_Invalid_Source
        ("{amount, number, ::currency/US}",
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
        (T, Test_Parser_Format_Fuzz'Access,
         "parser fuzz covers formatted argument syntax deterministically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Formatted_Value_Fuzz'Access,
         "formatted-value fuzz validates malformed formatted arguments");
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
