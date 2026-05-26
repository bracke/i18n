with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with I18N.Validation;
with I18N.Errors;

package body I18N.Compiler is

   use Ada.Strings.Unbounded;
   use I18N.AST;

   function Next_Index
     (Build : I18N.Compiled.Builder)
      return Positive
   is
   begin
      return I18N.Compiled.Op_Count (Build) + 1;
   end Next_Index;

   procedure Patch
     (Build : in out I18N.Compiled.Builder;
      Index : Positive;
      Item  : I18N.Compiled.Op)
   is
   begin
      I18N.Compiled.Replace_Element (Build, Index, Item);
   end Patch;

   procedure Append_Stop
     (Build      : in out I18N.Compiled.Builder;
      Stop_Index : out Natural;
      Restores   : Boolean)
   is
      Item : I18N.Compiled.Op;
   begin
      Item.Kind := I18N.Compiled.Stop_Branch;
      Item.Restores_Number_Context := Restores;
      I18N.Compiled.Append (Build, Item);
      Stop_Index := I18N.Compiled.Last_Index (Build);
   end Append_Stop;

   procedure Compile_Nodes
     (Root        : I18N.AST.Node_Access;
      Build       : in out I18N.Compiled.Builder;
      Substitute  : Boolean);

   procedure Patch_Stop_Target
     (Build      : in out I18N.Compiled.Builder;
      Stop_Index : Natural;
      Target     : Positive)
   is
      Stop : I18N.Compiled.Op := I18N.Compiled.Element (Build, Positive (Stop_Index));
   begin
      Stop.End_Target := Target;
      Patch (Build, Positive (Stop_Index), Stop);
   end Patch_Stop_Target;

   procedure Compile_Plural
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder)
   is
      Jump_Index : Positive;
      Jump       : I18N.Compiled.Op;
      Stop_One   : Natural;
      Stop_Other : Natural;
      End_Index  : Positive;
   begin
      Jump.Kind := I18N.Compiled.Jump_Plural;
      Jump.Key := new String'(To_String (Node.Name));
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      Jump.One_Target := Next_Index (Build);
      Compile_Nodes (Node.One, Build, Substitute => True);
      Append_Stop (Build, Stop_One, Restores => True);

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Node.Other, Build, Substitute => True);
      Append_Stop (Build, Stop_Other, Restores => True);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Stop_Target (Build, Positive (Stop_One), End_Index);
      Patch_Stop_Target (Build, Positive (Stop_Other), End_Index);
   end Compile_Plural;

   procedure Compile_Select
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder;
      Substitute : Boolean)
   is
      Jump        : I18N.Compiled.Op;
      Jump_Index  : Positive;
      Stop_Male   : Natural := 0;
      Stop_Female : Natural := 0;
      Stop_Other  : Positive;
      End_Index   : Positive;
   begin
      Jump.Kind := I18N.Compiled.Jump_Select;
      Jump.Key := new String'(To_String (Node.Name));
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      if Node.Male /= null then
         Jump.Male_Hash := Ada.Strings.Hash ("male");
         Jump.Male_Target := Next_Index (Build);
         Compile_Nodes (Node.Male, Build, Substitute);
         Append_Stop (Build, Stop_Male, Restores => False);
      end if;

      if Node.Female /= null then
         Jump.Female_Hash := Ada.Strings.Hash ("female");
         Jump.Female_Target := Next_Index (Build);
         Compile_Nodes (Node.Female, Build, Substitute);
         Append_Stop (Build, Stop_Female, Restores => False);
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Node.Select_Other, Build, Substitute);
      Append_Stop (Build, Stop_Other, Restores => False);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      if Stop_Male /= 0 then
         Patch_Stop_Target (Build, Positive (Stop_Male), End_Index);
      end if;
      if Stop_Female /= 0 then
         Patch_Stop_Target (Build, Positive (Stop_Female), End_Index);
      end if;
      Patch_Stop_Target (Build, Stop_Other, End_Index);
   end Compile_Select;

   procedure Compile_Ordinal
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder)
   is
      Jump       : I18N.Compiled.Op;
      Jump_Index : Positive;
      Stop_One   : Natural;
      Stop_Two   : Natural;
      Stop_Few   : Natural;
      Stop_Other : Natural;
      End_Index  : Positive;
   begin
      Jump.Kind := I18N.Compiled.Jump_Ordinal;
      Jump.Key := new String'(To_String (Node.Name));
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      Jump.One_Target := Next_Index (Build);
      Compile_Nodes (Node.Ord_One, Build, Substitute => True);
      Append_Stop (Build, Stop_One, Restores => True);

      Jump.Two_Target := Next_Index (Build);
      Compile_Nodes (Node.Ord_Two, Build, Substitute => True);
      Append_Stop (Build, Stop_Two, Restores => True);

      Jump.Few_Target := Next_Index (Build);
      Compile_Nodes (Node.Ord_Few, Build, Substitute => True);
      Append_Stop (Build, Stop_Few, Restores => True);

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Node.Ord_Other, Build, Substitute => True);
      Append_Stop (Build, Stop_Other, Restores => True);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Stop_Target (Build, Positive (Stop_One), End_Index);
      Patch_Stop_Target (Build, Positive (Stop_Two), End_Index);
      Patch_Stop_Target (Build, Positive (Stop_Few), End_Index);
      Patch_Stop_Target (Build, Positive (Stop_Other), End_Index);
   end Compile_Ordinal;

   procedure Compile_Nodes
     (Root        : I18N.AST.Node_Access;
      Build       : in out I18N.Compiled.Builder;
      Substitute  : Boolean)
   is
      Current : I18N.AST.Node_Access := Root;
      Item    : I18N.Compiled.Op;
   begin
      while Current /= null loop
         case Current.Kind is
            when I18N.AST.Text =>
               Item := (Kind => I18N.Compiled.Text,
                        Text_Value => new String'(To_String (Current.Text)),
                        Key => null,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Other_Target => 0,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => Substitute,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Variable =>
               Item := (Kind => I18N.Compiled.Var,
                        Text_Value => null,
                        Key => new String'(To_String (Current.Name)),
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Other_Target => 0,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => False,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Plural =>
               Compile_Plural (Current.all, Build);

            when I18N.AST.Select_Node =>
               Compile_Select (Current.all, Build, Substitute);

            when I18N.AST.SelectOrdinal =>
               Compile_Ordinal (Current.all, Build);
         end case;

         Current := Current.Next;
      end loop;
   end Compile_Nodes;

   function Compile
     (N : I18N.AST.Node_Access)
      return I18N.Compiled.Compiled_Message
   is
      Validation_Result : constant I18N.Errors.Result :=
        I18N.Validation.Validate (N);
      Build : I18N.Compiled.Builder;
   begin
      if not Validation_Result.Ok then
         raise Constraint_Error with "cannot compile invalid ICU AST";
      end if;

      Compile_Nodes (N, Build, Substitute => False);
      return I18N.Compiled.Freeze (Build);
   end Compile;

end I18N.Compiler;
