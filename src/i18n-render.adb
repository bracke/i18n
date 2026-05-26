with Ada.Strings.Unbounded;
with I18N.AST; use I18N.AST;
with I18N.Buffer;

package body I18N.Render is

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
         if C = '#' then
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

            when I18N.AST.Plural =>
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
                             Kind  => I18N.Errors.Invalid_Selector);
                     begin
                        if not State.Failed then
                           declare
                              Rendered_Value : constant String :=
                                Integer_Image_No_Leading_Space (Numeric_Value);
                              Selected_AST : constant I18N.AST.Node_Access :=
                                (if Numeric_Value = 1 then Current.One else Current.Other);
                           begin
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

            when I18N.AST.Select_Node =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  if not Args.Has (Key) then
                     Fail (State, I18N.Errors.Missing_Variable);
                  else
                     declare
                        Value : constant String := Args.Get (Key);
                        Selected_AST : constant I18N.AST.Node_Access :=
                          (if Value = "male" then Current.Male
                           elsif Value = "female" then Current.Female
                           else Current.Select_Other);
                     begin
                        if Selected_AST = null then
                           if Current.Select_Other = null then
                              Fail (State, I18N.Errors.Missing_Branch);
                           else
                              Render_Nodes
                                (Root                   => Current.Select_Other,
                                 Args                   => Args,
                                 Output                 => Output,
                                 State                  => State,
                                 Number_Text            => Number_Text,
                                 Substitute_Number_Sign => Substitute_Number_Sign);
                           end if;
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
                              Selected_AST : constant I18N.AST.Node_Access :=
                                (case Category_For_Ordinal (Numeric_Value) is
                                    when One   => Current.Ord_One,
                                    when Two   => Current.Ord_Two,
                                    when Few   => Current.Ord_Few,
                                    when Other => Current.Ord_Other);
                           begin
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
