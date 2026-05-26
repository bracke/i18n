with Ada.Strings.Unbounded;
with I18N.Compiled; use I18N.Compiled;
with Ada.Containers; use Ada.Containers;
with Ada.Strings.Hash;

package body I18N.Fast_Render is

   type Ordinal_Category is (One, Two, Few, Other);

   type Error_State is record
      Failed   : Boolean := False;
      Kind     : I18N.Errors.Error_Kind := I18N.Errors.Parse_Error;
      Key      : String (1 .. I18N.Diagnostics.Key_Capacity) :=
        [others => Character'Val (0)];
      Key_Last : Natural := 0;
   end record;

   procedure Store_Error_Key
     (State : in out Error_State;
      Key   : String)
   is
      Copy_Last : Natural := 0;
   begin
      State.Key := [others => Character'Val (0)];
      if Key'Length > 0 then
         Copy_Last := Natural'Min (Key'Length, State.Key'Length);
         State.Key (1 .. Copy_Last) := Key (Key'First .. Key'First + Copy_Last - 1);
      end if;
      State.Key_Last := Copy_Last;
   end Store_Error_Key;

   function Error_Key
     (State : Error_State)
      return String
   is
   begin
      if State.Key_Last = 0 then
         return "";
      end if;
      return State.Key (1 .. State.Key_Last);
   end Error_Key;

   procedure Fail
     (State : in out Error_State;
      Kind  : I18N.Errors.Error_Kind;
      Key   : String := "")
   is
   begin
      if not State.Failed then
         State.Failed := True;
         State.Kind := Kind;
         Store_Error_Key (State, Key);
      end if;
   end Fail;

   function Is_Decimal_Integer
     (Text : String)
      return Boolean
   is
      Start : Positive;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Decimal_Integer;

   function To_Long_Long_Integer_Strict
     (Text  : String;
      State : in out Error_State;
      Kind  : I18N.Errors.Error_Kind;
      Key   : String := "")
      return Long_Long_Integer
   is
   begin
      if not Is_Decimal_Integer (Text) then
         Fail (State, Kind, Key);
         return 0;
      end if;

      return Long_Long_Integer'Value (Text);
   exception
      when Constraint_Error =>
         Fail (State, Kind, Key);
         return 0;
   end To_Long_Long_Integer_Strict;

   procedure Append_Integer_No_Leading_Space
     (Output : in out I18N.Buffer.Buffer;
      Value  : Long_Long_Integer)
   is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         Output.Append (Image (Image'First + 1 .. Image'Last));
      else
         Output.Append (Image);
      end if;
   end Append_Integer_No_Leading_Space;

   function Category_For_Ordinal
     (Value : Long_Long_Integer)
      return Ordinal_Category
   is
   begin
      if Value = 1 then
         return One;
      elsif Value = 2 then
         return Two;
      elsif Value = 3 then
         return Few;
      else
         return Other;
      end if;
   end Category_For_Ordinal;

   procedure Append_Text_With_Number_Substitution
     (Output        : in out I18N.Buffer.Buffer;
      Text          : String;
      Number_Value  : Long_Long_Integer;
      Number_Active : Boolean)
   is
   begin
      for C of Text loop
         if C = '#' and then Number_Active then
            Append_Integer_No_Leading_Space (Output, Number_Value);
         else
            Output.Append (C);
         end if;
      end loop;
   end Append_Text_With_Number_Substitution;

   type Number_Value_Stack is array (Positive range <>) of Long_Long_Integer;
   type Number_Active_Stack is array (Positive range <>) of Boolean;

   procedure Push_Number_Context
     (Values         : in out Number_Value_Stack;
      Active         : in out Number_Active_Stack;
      Top            : in out Natural;
      Current_Value  : Long_Long_Integer;
      Current_Active : Boolean;
      State          : in out Error_State)
   is
   begin
      if Top = Values'Last then
         Fail (State, I18N.Errors.Parse_Error);
      else
         Top := Top + 1;
         Values (Top) := Current_Value;
         Active (Top) := Current_Active;
      end if;
   end Push_Number_Context;

   procedure Pop_Number_Context
     (Values         : Number_Value_Stack;
      Active         : Number_Active_Stack;
      Top            : in out Natural;
      Current_Value  : in out Long_Long_Integer;
      Current_Active : in out Boolean;
      State          : in out Error_State)
   is
   begin
      if Top = 0 then
         Fail (State, I18N.Errors.Parse_Error);
      else
         Current_Value := Values (Top);
         Current_Active := Active (Top);
         Top := Top - 1;
      end if;
   end Pop_Number_Context;

   procedure Copy_Argument
     (Args     : I18N.Arguments.Arguments;
      Key      : String;
      Scratch  : out String;
      Last     : out Natural;
      Found    : out Boolean;
      Overflow : out Boolean)
   is
   begin
      I18N.Arguments.Copy_Value
        (Args     => Args,
         Key      => Key,
         Target   => Scratch,
         Last     => Last,
         Found    => Found,
         Overflow => Overflow);
   end Copy_Argument;

   function Render_Into
     (Msg         : I18N.Compiled.Compiled_Message;
      Buffer      : in out I18N.Buffer.Buffer;
      Args        : I18N.Arguments.Arguments;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Metadata    : I18N.Observability.Execution_Metadata)
      return I18N.Errors.Status
   is
      State          : Error_State;
      IP             : Positive := 1;
      Last           : constant Natural := I18N.Compiled.Last_Index (Msg);
      Number_Value   : Long_Long_Integer := 0;
      Number_Active  : Boolean := False;
      Number_Values  : Number_Value_Stack (1 .. 128) := [others => 0];
      Number_Actives : Number_Active_Stack (1 .. 128) := [others => False];
      Stack_Top      : Natural := 0;
      Arg_Buffer     : String (1 .. I18N.Buffer.Default_Capacity);
      Arg_Last       : Natural := 0;
      Arg_Found      : Boolean := False;
      Arg_Overflow   : Boolean := False;
   begin
      Buffer.Clear;
      I18N.Diagnostics.Clear (Diagnostics);
      I18N.Observability.Emit
        (I18N.Observability.Message_Start,
         I18N.Observability.Message_Key (Metadata));

      while IP <= Last loop
         declare
            Operation : constant I18N.Compiled.Op := I18N.Compiled.Element (Msg, IP);
         begin
            case Operation.Kind is
               when I18N.Compiled.Text =>
                  I18N.Observability.Emit (I18N.Observability.Op_Text);
               when I18N.Compiled.Var =>
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when I18N.Compiled.Jump_Plural =>
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Plural,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when I18N.Compiled.Jump_Select =>
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Select,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when I18N.Compiled.Jump_Ordinal =>
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Ordinal,
                     (if Operation.Key = null then "" else Operation.Key.all));
               when I18N.Compiled.Stop_Branch =>
                  null;
            end case;

            case Operation.Kind is
               when I18N.Compiled.Text =>
                  if Operation.Text_Value = null then
                     Fail (State, I18N.Errors.Parse_Error);
                  elsif Operation.Substitute_Number_Sign then
                     Append_Text_With_Number_Substitution
                       (Output        => Buffer,
                        Text          => Operation.Text_Value.all,
                        Number_Value  => Number_Value,
                        Number_Active => Number_Active);
                  else
                     Buffer.Append (Operation.Text_Value.all);
                  end if;
                  IP := IP + 1;

               when I18N.Compiled.Var =>
                  if Operation.Key = null then
                     Fail (State, I18N.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, I18N.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow then
                        Fail (State, I18N.Errors.Buffer_Overflow);
                     elsif Arg_Last > 0 then
                        Buffer.Append (Arg_Buffer (1 .. Arg_Last));
                        IP := IP + 1;
                     else
                        IP := IP + 1;
                     end if;
                  end if;

               when I18N.Compiled.Jump_Plural =>
                  if Operation.Key = null then
                     Fail (State, I18N.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, I18N.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow or else Arg_Last = 0 then
                        Fail (State, I18N.Errors.Invalid_Selector, Operation.Key.all);
                     else
                        declare
                           Numeric_Value : constant Long_Long_Integer :=
                             To_Long_Long_Integer_Strict
                               (Text  => Arg_Buffer (1 .. Arg_Last),
                                State => State,
                                Kind  => I18N.Errors.Invalid_Selector,
                                Key   => Operation.Key.all);
                        begin
                           if not State.Failed then
                              Push_Number_Context
                                (Values         => Number_Values,
                                 Active         => Number_Actives,
                                 Top            => Stack_Top,
                                 Current_Value  => Number_Value,
                                 Current_Active => Number_Active,
                                 State          => State);
                              Number_Value := Numeric_Value;
                              Number_Active := True;
                              if Numeric_Value = 1 then
                                 IP := Positive (Operation.One_Target);
                              else
                                 IP := Positive (Operation.Other_Target);
                              end if;
                           end if;
                        end;
                     end if;
                  end if;

               when I18N.Compiled.Jump_Select =>
                  if Operation.Key = null then
                     Fail (State, I18N.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, I18N.Errors.Missing_Variable, Operation.Key.all);
                     else
                        declare
                           Target   : I18N.Compiled.Op_Index := Operation.Other_Target;
                           Arg_Hash : constant Ada.Containers.Hash_Type :=
                             (if Arg_Overflow or else Arg_Last = 0
                              then 0
                              else Ada.Strings.Hash (Arg_Buffer (1 .. Arg_Last)));
                        begin
                           if not Arg_Overflow
                             and then Operation.Male_Target /= 0
                             and then Arg_Hash = Operation.Male_Hash
                             and then Arg_Last = 4
                             and then Arg_Buffer (1 .. Arg_Last) = "male"
                           then
                              Target := Operation.Male_Target;
                           elsif not Arg_Overflow
                             and then Operation.Female_Target /= 0
                             and then Arg_Hash = Operation.Female_Hash
                             and then Arg_Last = 6
                             and then Arg_Buffer (1 .. Arg_Last) = "female"
                           then
                              Target := Operation.Female_Target;
                           end if;

                           if Target = 0 then
                              Fail (State, I18N.Errors.Missing_Branch, Operation.Key.all);
                           else
                              IP := Positive (Target);
                           end if;
                        end;
                     end if;
                  end if;

               when I18N.Compiled.Jump_Ordinal =>
                  if Operation.Key = null then
                     Fail (State, I18N.Errors.Parse_Error);
                  else
                     Copy_Argument
                       (Args     => Args,
                        Key      => Operation.Key.all,
                        Scratch  => Arg_Buffer,
                        Last     => Arg_Last,
                        Found    => Arg_Found,
                        Overflow => Arg_Overflow);

                     if not Arg_Found then
                        Fail (State, I18N.Errors.Missing_Variable, Operation.Key.all);
                     elsif Arg_Overflow or else Arg_Last = 0 then
                        Fail (State, I18N.Errors.Invalid_Ordinal, Operation.Key.all);
                     else
                        declare
                           Numeric_Value : constant Long_Long_Integer :=
                             To_Long_Long_Integer_Strict
                               (Text  => Arg_Buffer (1 .. Arg_Last),
                                State => State,
                                Kind  => I18N.Errors.Invalid_Ordinal,
                                Key   => Operation.Key.all);
                        begin
                           if not State.Failed then
                              Push_Number_Context
                                (Values         => Number_Values,
                                 Active         => Number_Actives,
                                 Top            => Stack_Top,
                                 Current_Value  => Number_Value,
                                 Current_Active => Number_Active,
                                 State          => State);
                              Number_Value := Numeric_Value;
                              Number_Active := True;
                              case Category_For_Ordinal (Numeric_Value) is
                                 when One =>
                                    IP := Positive (Operation.One_Target);
                                 when Two =>
                                    IP := Positive (Operation.Two_Target);
                                 when Few =>
                                    IP := Positive (Operation.Few_Target);
                                 when Other =>
                                    IP := Positive (Operation.Other_Target);
                              end case;
                           end if;
                        end;
                     end if;
                  end if;

               when I18N.Compiled.Stop_Branch =>
                  if Operation.Restores_Number_Context then
                     Pop_Number_Context
                       (Values         => Number_Values,
                        Active         => Number_Actives,
                        Top            => Stack_Top,
                        Current_Value  => Number_Value,
                        Current_Active => Number_Active,
                        State          => State);
                  end if;

                  if not State.Failed then
                     IP := Positive (Operation.End_Target);
                  end if;
            end case;
         end;

         if Buffer.Overflowed then
            Fail (State, I18N.Errors.Buffer_Overflow);
         end if;

         exit when State.Failed;
      end loop;

      I18N.Observability.Emit (I18N.Observability.Message_End);

      if State.Failed then
         I18N.Diagnostics.Add
           (List    => Diagnostics,
            Kind    => I18N.Errors.To_Diagnostic_Kind (State.Kind),
            Message => "render failure",
            Key     => Error_Key (State));
         return I18N.Errors.Failure_Status (State.Kind);
      end if;

      return I18N.Errors.Success_Status;
   exception
      when others =>
         I18N.Diagnostics.Add
           (List    => Diagnostics,
            Kind    => I18N.Diagnostics.Parse_Error,
            Message => "render exception");
         I18N.Observability.Emit (I18N.Observability.Message_End);
         return I18N.Errors.Failure_Status (I18N.Errors.Parse_Error);
   end Render_Into;

   function Render_Into
     (Msg         : I18N.Compiled.Compiled_Message;
      Buffer      : in out I18N.Buffer.Buffer;
      Args        : I18N.Arguments.Arguments;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List)
      return I18N.Errors.Status
   is
      Metadata : I18N.Observability.Execution_Metadata;
   begin
      return Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics,
         Metadata    => Metadata);
   end Render_Into;

   function Render_Into
     (Msg    : I18N.Compiled.Compiled_Message;
      Buffer : in out I18N.Buffer.Buffer;
      Args   : I18N.Arguments.Arguments)
      return I18N.Errors.Status
   is
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   begin
      return Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics);
   end Render_Into;

   function Render
     (Msg    : I18N.Compiled.Compiled_Message;
      Buffer : in out I18N.Buffer.Buffer;
      Args   : I18N.Arguments.Arguments)
      return I18N.Errors.Result
   is
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
      Status      : I18N.Errors.Status;
   begin
      Status := Render_Into
        (Msg         => Msg,
         Buffer      => Buffer,
         Args        => Args,
         Diagnostics => Diagnostics);

      if not Status.Ok then
         declare
            Result : constant I18N.Errors.Result := I18N.Errors.Failure (Status.Error);
         begin
            return
              (Ok          => Result.Ok,
               Value       => Result.Value,
               Error       => Result.Error,
               Diagnostics => Diagnostics);
         end;
      end if;

      declare
         Value : constant String := Buffer.To_String;
      begin
         return
           (Ok          => True,
            Value       => Ada.Strings.Unbounded.To_Unbounded_String (Value),
            Error       => I18N.Errors.Parse_Error,
            Diagnostics => Diagnostics);
      end;
   end Render;

   function Render
     (Msg  : I18N.Compiled.Compiled_Message;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result
   is
      Buffer : I18N.Buffer.Buffer;
   begin
      return Render (Msg => Msg, Buffer => Buffer, Args => Args);
   end Render;

end I18N.Fast_Render;
