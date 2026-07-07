with Ada.Strings.Unbounded;
with I18N.AST; use I18N.AST;
with I18N.Buffer;
with I18N.Currency;
with I18N.Date_Time_Format;
with I18N.Extra_Format;
with I18N.Number_Format;
with I18N.Plurals;

package body I18N.Render is

   Escaped_Number_Sign : constant Character := Character'Val (1);

   use Ada.Strings.Unbounded;

   type Ordinal_Category is (One, Two, Few, Other);

   type Error_State is record
      Failed : Boolean := False;
      Kind   : I18N.Errors.Error_Kind := I18N.Errors.Parse_Error;
   end record;

   procedure Fail
     (State : in out Error_State;
      Kind  : I18N.Errors.Error_Kind)
   is
   begin
      if not State.Failed then
         State.Failed := True;
         State.Kind := Kind;
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
      Kind  : I18N.Errors.Error_Kind)
      return Long_Long_Integer
   is
   begin
      if not Is_Decimal_Integer (Text) then
         Fail (State, Kind);
         return 0;
      end if;

      return Long_Long_Integer'Value (Text);
   exception
      when Constraint_Error =>
         Fail (State, Kind);
      return 0;
   end To_Long_Long_Integer_Strict;

   procedure Split_Decimal
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer;
      Valid           : out Boolean)
   is
      Start : Natural := Text'First;
      Dot   : Natural := 0;
   begin
      Integer_Part := 0;
      Fraction_Digits := 0;
      Fraction_Value := 0;
      Valid := False;

      if Text'Length = 0 then
         return;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return;
            end if;
            Dot := Index;
         elsif Text (Index) not in '0' .. '9' then
            return;
         end if;
      end loop;

      if Dot = 0 or else Dot = Start or else Dot = Text'Last then
         return;
      end if;

      Integer_Part := Long_Long_Integer'Value (Text (Start .. Dot - 1));
      Fraction_Digits := Text'Last - Dot;
      Fraction_Value := Long_Long_Integer'Value (Text (Dot + 1 .. Text'Last));
      Valid := True;
   exception
      when Constraint_Error =>
         Valid := False;
   end Split_Decimal;

   function Integer_Image_No_Leading_Space
     (Value : Long_Long_Integer)
      return String
   is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Integer_Image_No_Leading_Space;

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
     (Output      : in out I18N.Buffer.Buffer;
      Text        : String;
      Number_Text : String)
   is
   begin
      for C of Text loop
         if C = Escaped_Number_Sign then
            Output.Append ("#");
         elsif C = '#' then
            Output.Append (Number_Text);
         else
            Output.Append ([1 => C]);
         end if;
      end loop;
   end Append_Text_With_Number_Substitution;

   procedure Render_Nodes
     (Root                   : I18N.AST.Node_Access;
      Args                   : I18N.Arguments.Arguments;
      Output                 : in out I18N.Buffer.Buffer;
      State                  : in out Error_State;
      Number_Text            : String := "";
      Substitute_Number_Sign : Boolean := False)
   is
      Current : I18N.AST.Node_Access := Root;
   begin
      while Current /= null loop
         exit when State.Failed;

         case Current.Kind is
            when I18N.AST.Text =>
               if Substitute_Number_Sign then
                  Append_Text_With_Number_Substitution
                    (Output      => Output,
                     Text        => To_String (Current.Text),
                     Number_Text => Number_Text);
               else
                  Output.Append (To_String (Current.Text));
               end if;

            when I18N.AST.Variable =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if Args.Has (Key) then
                     Output.Append (Args.Get (Key));
                  else
                     Fail (State, I18N.Errors.Missing_Variable);
                  end if;
               end;

            when I18N.AST.Number =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if Args.Has (Key) then
                     declare
                        Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Number_Format.Format_Into
                          (Value_Text => Args.Get (Key),
                           Locale     => "en",
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Overflow);

                        if Overflow then
                           Fail (State, I18N.Errors.Buffer_Overflow);
                        elsif not Ok then
                           Fail (State, I18N.Errors.Invalid_Selector);
                        elsif Last > 0 then
                           Output.Append (Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Fail (State, I18N.Errors.Missing_Variable);
                  end if;
               end;

            when I18N.AST.Date_Format | I18N.AST.Time_Format
               | I18N.AST.Date_Time_Format =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if Args.Has (Key) then
                     declare
                        Formatted : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        if Current.Kind = I18N.AST.Date_Format then
                           I18N.Date_Time_Format.Format_Date_Into
                             (Value_Text => Args.Get (Key),
                              Locale     => "en",
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        elsif Current.Kind = I18N.AST.Time_Format then
                           I18N.Date_Time_Format.Format_Time_Into
                             (Value_Text => Args.Get (Key),
                              Locale     => "en",
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        else
                           I18N.Date_Time_Format.Format_Date_Time_Into
                             (Value_Text => Args.Get (Key),
                              Locale     => "en",
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        end if;

                        if Overflow then
                           Fail (State, I18N.Errors.Buffer_Overflow);
                        elsif not Ok then
                           Fail (State, I18N.Errors.Invalid_Selector);
                        elsif Last > 0 then
                           Output.Append (Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Fail (State, I18N.Errors.Missing_Variable);
                  end if;
               end;

            when I18N.AST.Currency =>
               declare
                  Key  : constant String := To_String (Current.Name);
                  Code : constant String := To_String (Current.Currency_Code);
               begin
                  if Args.Has (Key) then
                     declare
                        Formatted : String (1 .. I18N.Currency.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Currency.Format_Into
                          (Amount_Text   => Args.Get (Key),
                           Currency_Code => Code,
                           Locale        => "en",
                           Target        => Formatted,
                           Last          => Last,
                           Ok            => Ok,
                           Overflow      => Overflow);

                        if Overflow then
                           Fail (State, I18N.Errors.Buffer_Overflow);
                        elsif not Ok then
                           Fail (State, I18N.Errors.Invalid_Selector);
                        elsif Last > 0 then
                           Output.Append (Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Fail (State, I18N.Errors.Missing_Variable);
                  end if;
               end;

            when I18N.AST.Duration_Format | I18N.AST.Byte_Size_Format
               | I18N.AST.Unit_Format | I18N.AST.Relative_Time_Format
               | I18N.AST.List_Format =>
               declare
                  Key : constant String := To_String (Current.Name);

                  function Kind return I18N.Extra_Format.Extra_Kind is
                  begin
                     case Current.Kind is
                        when I18N.AST.Duration_Format =>
                           return I18N.Extra_Format.Duration;
                        when I18N.AST.Byte_Size_Format =>
                           return I18N.Extra_Format.Byte_Size;
                        when I18N.AST.Unit_Format =>
                           return I18N.Extra_Format.Unit;
                        when I18N.AST.Relative_Time_Format =>
                           return I18N.Extra_Format.Relative_Time;
                        when others =>
                           return I18N.Extra_Format.List;
                     end case;
                  end Kind;
               begin
                  if Args.Has (Key) then
                     declare
                        Formatted : String (1 .. I18N.Extra_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Extra_Format.Format_Into
                          (Kind     => Kind,
                           Value    => Args.Get (Key),
                           Locale   => "en",
                           Option   => To_String (Current.Currency_Code),
                           Target   => Formatted,
                           Last     => Last,
                           Ok       => Ok,
                           Overflow => Overflow);

                        if Overflow then
                           Fail (State, I18N.Errors.Buffer_Overflow);
                        elsif not Ok then
                           Fail (State, I18N.Errors.Invalid_Selector);
                        elsif Last > 0 then
                           Output.Append (Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Fail (State, I18N.Errors.Missing_Variable);
                  end if;
               end;

            when I18N.AST.Plural =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if not Args.Has (Key) then
                     Fail (State, I18N.Errors.Missing_Variable);
                  else
                     declare
                        Raw_Value : constant String := Args.Get (Key);
                        Category : I18N.Plurals.Plural_Category :=
                          I18N.Plurals.Other;
                        Rendered_Value : Unbounded_String;
                        Exact_Value : Unbounded_String;
                        Valid : Boolean := True;
                     begin
                        if Current.Plural_Offset /= 0 then
                           declare
                              Numeric_Value : constant Long_Long_Integer :=
                                To_Long_Long_Integer_Strict
                                  (Text  => Raw_Value,
                                   State => State,
                                   Kind  => I18N.Errors.Invalid_Selector);
                              Adjusted_Value : constant Long_Long_Integer :=
                                Numeric_Value - Current.Plural_Offset;
                           begin
                              if not State.Failed then
                                 Category :=
                                   I18N.Plurals.Cardinal ("en", Adjusted_Value);
                                 Rendered_Value :=
                                   To_Unbounded_String
                                     (Integer_Image_No_Leading_Space
                                        (Adjusted_Value));
                                 Exact_Value :=
                                   To_Unbounded_String
                                     (Integer_Image_No_Leading_Space
                                        (Numeric_Value));
                              end if;
                           end;
                        elsif Is_Decimal_Integer (Raw_Value) then
                           declare
                              Numeric_Value : constant Long_Long_Integer :=
                                To_Long_Long_Integer_Strict
                                  (Text  => Raw_Value,
                                   State => State,
                                   Kind  => I18N.Errors.Invalid_Selector);
                           begin
                              if not State.Failed then
                                 Category :=
                                   I18N.Plurals.Cardinal ("en", Numeric_Value);
                                 Rendered_Value :=
                                   To_Unbounded_String
                                     (Integer_Image_No_Leading_Space
                                        (Numeric_Value));
                                 Exact_Value := Rendered_Value;
                              end if;
                           end;
                        else
                           declare
                              I_Part      : Long_Long_Integer;
                              Digit_Count : Natural;
                              F_Val       : Long_Long_Integer;
                           begin
                              Split_Decimal
                                (Raw_Value, I_Part, Digit_Count, F_Val, Valid);
                              if Valid then
                                 Category :=
                                   I18N.Plurals.Cardinal
                                     ("en", I_Part, Digit_Count, F_Val);
                                 Rendered_Value := To_Unbounded_String (Raw_Value);
                              else
                                 Fail (State, I18N.Errors.Invalid_Selector);
                              end if;
                           end;
                        end if;

                        if not State.Failed then
                           declare
                              Exact_Text : constant String :=
                                To_String (Exact_Value);
                              Selected_AST : I18N.AST.Node_Access :=
                                (if Exact_Text'Length > 0
                                 then I18N.AST.Branch_Body
                                        (Current.Plural_Exact, Exact_Text)
                                 else null);
                           begin
                              if Selected_AST = null then
                                 Selected_AST :=
                                   (case Category is
                                      when I18N.Plurals.Zero =>
                                         Current.Plural_Zero,
                                      when I18N.Plurals.One =>
                                         Current.One,
                                      when I18N.Plurals.Two =>
                                         Current.Plural_Two,
                                      when I18N.Plurals.Few =>
                                         Current.Plural_Few,
                                      when I18N.Plurals.Many =>
                                         Current.Plural_Many,
                                      when I18N.Plurals.Other =>
                                         Current.Other);
                              end if;

                              if Selected_AST = null then
                                 Selected_AST := Current.Other;
                              end if;

                              if Selected_AST = null then
                                 Fail (State, I18N.Errors.Missing_Branch);
                              else
                                 Render_Nodes
                                   (Root                   => Selected_AST,
                                    Args                   => Args,
                                    Output                 => Output,
                                    State                  => State,
                                    Number_Text => To_String (Rendered_Value),
                                    Substitute_Number_Sign => True);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.Select_Node =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if not Args.Has (Key) then
                     Fail (State, I18N.Errors.Missing_Variable);
                  else
                     declare
                        Value : constant String := Args.Get (Key);
                        Matched : constant Boolean :=
                          I18N.AST.Has_Branch (Current.Branches, Value);
                        Selected_AST : constant I18N.AST.Node_Access :=
                          (if Matched
                           then I18N.AST.Branch_Body (Current.Branches, Value)
                           else I18N.AST.Branch_Body (Current.Branches, "other"));
                     begin
                        if not Matched
                          and then not I18N.AST.Has_Branch
                                         (Current.Branches, "other")
                        then
                           Fail (State, I18N.Errors.Missing_Branch);
                        elsif Selected_AST = null then
                           --  Present-but-empty branch renders as empty text.
                           null;
                        else
                           Render_Nodes
                             (Root                   => Selected_AST,
                              Args                   => Args,
                              Output                 => Output,
                              State                  => State,
                              Number_Text            => Number_Text,
                              Substitute_Number_Sign => Substitute_Number_Sign);
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.SelectOrdinal =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if not Args.Has (Key) then
                     Fail (State, I18N.Errors.Missing_Variable);
                  else
                     declare
                        Raw_Value : constant String := Args.Get (Key);
                        Numeric_Value : constant Long_Long_Integer :=
                          To_Long_Long_Integer_Strict
                            (Text  => Raw_Value,
                             State => State,
                             Kind  => I18N.Errors.Invalid_Ordinal);
                     begin
                        if not State.Failed then
                           declare
                              Rendered_Value : constant String :=
                                Integer_Image_No_Leading_Space (Numeric_Value);
                              --  Only "other" is mandatory; an absent category
                              --  branch falls back to "other".
                              Selected_AST : I18N.AST.Node_Access :=
                                I18N.AST.Branch_Body
                                  (Current.Ord_Exact, Rendered_Value);
                           begin
                              if Selected_AST = null then
                                 Selected_AST :=
                                   (case Category_For_Ordinal (Numeric_Value) is
                                       when One   => Current.Ord_One,
                                       when Two   => Current.Ord_Two,
                                       when Few   => Current.Ord_Few,
                                       when Other => Current.Ord_Other);
                              end if;

                              if Selected_AST = null then
                                 Selected_AST := Current.Ord_Other;
                              end if;

                              if Selected_AST = null then
                                 Fail (State, I18N.Errors.Missing_Branch);
                              else
                                 Render_Nodes
                                   (Root                   => Selected_AST,
                                    Args                   => Args,
                                    Output                 => Output,
                                    State                  => State,
                                    Number_Text            => Rendered_Value,
                                    Substitute_Number_Sign => True);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
         end case;

         Current := Current.Next;
      end loop;
   end Render_Nodes;

   function Render
     (Root : I18N.AST.Node_Access;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result
   is
      Output : I18N.Buffer.Buffer;
      State  : Error_State;
   begin
      Render_Nodes
        (Root   => Root,
         Args   => Args,
         Output => Output,
         State  => State);

      if State.Failed then
         return I18N.Errors.Failure (State.Kind);
      elsif Output.Overflowed then
         return I18N.Errors.Failure (I18N.Errors.Buffer_Overflow);
      end if;

      return I18N.Errors.Success (Output.To_String);
   exception
      when others =>
         return I18N.Errors.Failure (I18N.Errors.Parse_Error);
   end Render;

end I18N.Render;
