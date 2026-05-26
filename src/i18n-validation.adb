with I18N.AST; use I18N.AST;
with Ada.Strings.Unbounded;

package body I18N.Validation is

   use Ada.Strings.Unbounded;

   function Is_Identifier_Character
     (C : Character)
      return Boolean
   is
   begin
      return
        (C in 'A' .. 'Z')
        or else (C in 'a' .. 'z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Identifier_Character;

   function Is_Valid_Identifier
     (Text : String)
      return Boolean
   is
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if not Is_Identifier_Character (C) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Identifier;

   function Validate_Nodes
     (N : I18N.AST.Node_Access)
      return I18N.Errors.Result;

   function Validate_Branch
     (N : I18N.AST.Node_Access)
      return I18N.Errors.Result
   is
   begin
      if N = null then
         return I18N.Errors.Failure (I18N.Errors.Missing_Branch);
      end if;

      return Validate_Nodes (N);
   end Validate_Branch;

   function Validate_Nodes
     (N : I18N.AST.Node_Access)
      return I18N.Errors.Result
   is
      Current : I18N.AST.Node_Access := N;
   begin
      while Current /= null loop
         case Current.Kind is
            when I18N.AST.Text =>
               null;

            when I18N.AST.Variable =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return I18N.Errors.Failure (I18N.Errors.Validation_Error);
               end if;

            when I18N.AST.Plural =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return I18N.Errors.Failure (I18N.Errors.Validation_Error);
               end if;

               declare
                  One_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.One);
               begin
                  if not One_Result.Ok then
                     return One_Result;
                  end if;
               end;

               declare
                  Other_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Other);
               begin
                  if not Other_Result.Ok then
                     return Other_Result;
                  end if;
               end;

            when I18N.AST.Select_Node =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return I18N.Errors.Failure (I18N.Errors.Validation_Error);
               end if;

               if Current.Male /= null then
                  declare
                     Male_Result : constant I18N.Errors.Result :=
                       Validate_Nodes (Current.Male);
                  begin
                     if not Male_Result.Ok then
                        return Male_Result;
                     end if;
                  end;
               end if;

               if Current.Female /= null then
                  declare
                     Female_Result : constant I18N.Errors.Result :=
                       Validate_Nodes (Current.Female);
                  begin
                     if not Female_Result.Ok then
                        return Female_Result;
                     end if;
                  end;
               end if;

               declare
                  Other_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Select_Other);
               begin
                  if not Other_Result.Ok then
                     return Other_Result;
                  end if;
               end;

            when I18N.AST.SelectOrdinal =>
               if not Is_Valid_Identifier (To_String (Current.Name)) then
                  return I18N.Errors.Failure (I18N.Errors.Validation_Error);
               end if;

               declare
                  One_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Ord_One);
               begin
                  if not One_Result.Ok then
                     return One_Result;
                  end if;
               end;

               declare
                  Two_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Ord_Two);
               begin
                  if not Two_Result.Ok then
                     return Two_Result;
                  end if;
               end;

               declare
                  Few_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Ord_Few);
               begin
                  if not Few_Result.Ok then
                     return Few_Result;
                  end if;
               end;

               declare
                  Other_Result : constant I18N.Errors.Result :=
                    Validate_Branch (Current.Ord_Other);
               begin
                  if not Other_Result.Ok then
                     return Other_Result;
                  end if;
               end;
         end case;

         Current := Current.Next;
      end loop;

      return I18N.Errors.Success ("");
   end Validate_Nodes;

   function Validate
     (N : I18N.AST.Node_Access)
      return I18N.Errors.Result
   is
   begin
      return Validate_Nodes (N);
   exception
      when others =>
         return I18N.Errors.Failure (I18N.Errors.Validation_Error);
   end Validate;

end I18N.Validation;
