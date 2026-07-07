with Ada.Strings.Hash;
with Ada.Strings.Unbounded;

with I18N.Validation;
with I18N.Errors;

package body I18N.Compiler is

   use Ada.Strings.Unbounded;
   use I18N.AST;
   use type I18N.Compiled.Op_Kind;

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

   function Branch_Count
     (Branches : I18N.AST.Branch_Access)
      return Natural
   is
      Count   : Natural := 0;
      Current : I18N.AST.Branch_Access := Branches;
   begin
      while Current /= null loop
         Count := Count + 1;
         Current := Current.Next;
      end loop;

      return Count;
   end Branch_Count;

   function Select_Target_Count
     (Branches : I18N.AST.Branch_Access)
      return Natural
   is
      Count   : Natural := 0;
      Current : I18N.AST.Branch_Access := Branches;
   begin
      while Current /= null loop
         if To_String (Current.Name) /= "other" then
            Count := Count + 1;
         end if;

         Current := Current.Next;
      end loop;

      return Count;
   end Select_Target_Count;

   procedure Patch_Branch_Stops
     (Build : in out I18N.Compiled.Builder;
      First : Positive;
      Last  : Natural;
      Target : Positive)
   is
   begin
      if Last < First then
         return;
      end if;

      for Index in First .. Last loop
         declare
            Item : I18N.Compiled.Op := I18N.Compiled.Element (Build, Index);
         begin
            if Item.Kind = I18N.Compiled.Stop_Branch
              and then Item.End_Target = 0
            then
               Item.End_Target := Target;
               Patch (Build, Index, Item);
            end if;
         end;
      end loop;
   end Patch_Branch_Stops;

   procedure Compile_Plural
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder)
   is
      Jump_Index : Positive;
      Jump       : I18N.Compiled.Op;
      Stop_Zero  : Natural := 0;
      Stop_One   : Natural := 0;
      Stop_Two   : Natural := 0;
      Stop_Few   : Natural := 0;
      Stop_Many  : Natural := 0;
      Stop_Other : Natural;
      End_Index  : Positive;
      Exact_Count : constant Natural := Branch_Count (Node.Plural_Exact);
   begin
      Jump.Kind := I18N.Compiled.Jump_Plural;
      Jump.Key := new String'(To_String (Node.Name));
      Jump.Plural_Offset := Node.Plural_Offset;
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      --  Only "other" is mandatory; absent category targets remain 0 so the
      --  renderer falls back to "other".
      if Exact_Count > 0 then
         declare
            Exact_Targets : I18N.Compiled.Exact_Target_Array (1 .. Exact_Count);
            Exact_Stops   : array (1 .. Exact_Count) of Natural := [others => 0];
            Branch        : I18N.AST.Branch_Access := Node.Plural_Exact;
            Index         : Positive := Exact_Targets'First;
         begin
            while Branch /= null loop
               Exact_Targets (Index).Value :=
                 Long_Long_Integer'Value (To_String (Branch.Name));
               Exact_Targets (Index).Target := Next_Index (Build);
               Compile_Nodes (Branch.Body_Root, Build, Substitute => True);
               Append_Stop (Build, Exact_Stops (Index), Restores => True);
               Branch := Branch.Next;
               Index := Index + 1;
            end loop;

            Jump.Exact_Targets :=
              new I18N.Compiled.Exact_Target_Array'(Exact_Targets);
         end;
      end if;

      if Node.Plural_Zero /= null then
         Jump.Zero_Target := Next_Index (Build);
         Compile_Nodes (Node.Plural_Zero, Build, Substitute => True);
         Append_Stop (Build, Stop_Zero, Restores => True);
      end if;

      if Node.One /= null then
         Jump.One_Target := Next_Index (Build);
         Compile_Nodes (Node.One, Build, Substitute => True);
         Append_Stop (Build, Stop_One, Restores => True);
      end if;

      if Node.Plural_Two /= null then
         Jump.Two_Target := Next_Index (Build);
         Compile_Nodes (Node.Plural_Two, Build, Substitute => True);
         Append_Stop (Build, Stop_Two, Restores => True);
      end if;

      if Node.Plural_Few /= null then
         Jump.Few_Target := Next_Index (Build);
         Compile_Nodes (Node.Plural_Few, Build, Substitute => True);
         Append_Stop (Build, Stop_Few, Restores => True);
      end if;

      if Node.Plural_Many /= null then
         Jump.Many_Target := Next_Index (Build);
         Compile_Nodes (Node.Plural_Many, Build, Substitute => True);
         Append_Stop (Build, Stop_Many, Restores => True);
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Node.Other, Build, Substitute => True);
      Append_Stop (Build, Stop_Other, Restores => True);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Branch_Stops
        (Build  => Build,
         First  => Jump_Index + 1,
         Last   => End_Index - 1,
         Target => End_Index);
   end Compile_Plural;

   procedure Compile_Select
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder;
      Substitute : Boolean)
   is
      Jump         : I18N.Compiled.Op;
      Jump_Index   : Positive;
      Stop_Other   : Natural;
      End_Index    : Positive;
      Select_Count : constant Natural := Select_Target_Count (Node.Branches);
      Other_Body   : constant I18N.AST.Node_Access :=
        I18N.AST.Branch_Body (Node.Branches, "other");
   begin
      Jump.Kind := I18N.Compiled.Jump_Select;
      Jump.Key := new String'(To_String (Node.Name));
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      if Select_Count > 0 then
         declare
            Select_Targets : I18N.Compiled.Select_Target_Array
              (1 .. Select_Count);
            Stop_Index     : Natural;
            Branch         : I18N.AST.Branch_Access := Node.Branches;
            Index          : Positive := Select_Targets'First;
         begin
            while Branch /= null loop
               declare
                  Name_Text : constant String := To_String (Branch.Name);
               begin
                  if Name_Text /= "other" then
                     Select_Targets (Index).Name := new String'(Name_Text);
                     Select_Targets (Index).Hash := Ada.Strings.Hash (Name_Text);
                     Select_Targets (Index).Target := Next_Index (Build);
                     Compile_Nodes (Branch.Body_Root, Build, Substitute);
                     Append_Stop (Build, Stop_Index, Restores => False);
                     Index := Index + 1;
                  end if;
               end;

               Branch := Branch.Next;
            end loop;

            Jump.Select_Targets :=
              new I18N.Compiled.Select_Target_Array'(Select_Targets);
         end;
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Other_Body, Build, Substitute);
      Append_Stop (Build, Stop_Other, Restores => False);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Branch_Stops
        (Build  => Build,
         First  => Jump_Index + 1,
         Last   => End_Index - 1,
         Target => End_Index);
   end Compile_Select;

   procedure Compile_Ordinal
     (Node       : I18N.AST.Node;
      Build      : in out I18N.Compiled.Builder)
   is
      Jump       : I18N.Compiled.Op;
      Jump_Index : Positive;
      Stop_Zero  : Natural := 0;
      Stop_One   : Natural := 0;
      Stop_Two   : Natural := 0;
      Stop_Few   : Natural := 0;
      Stop_Many  : Natural := 0;
      Stop_Other : Natural;
      End_Index  : Positive;
      Exact_Count : constant Natural := Branch_Count (Node.Ord_Exact);
   begin
      Jump.Kind := I18N.Compiled.Jump_Ordinal;
      Jump.Key := new String'(To_String (Node.Name));
      I18N.Compiled.Append (Build, Jump);
      Jump_Index := I18N.Compiled.Last_Index (Build);

      --  Only "other" is mandatory; absent category branches leave their
      --  targets 0 so the renderer falls back to "other".
      if Exact_Count > 0 then
         declare
            Exact_Targets : I18N.Compiled.Exact_Target_Array (1 .. Exact_Count);
            Exact_Stops   : array (1 .. Exact_Count) of Natural := [others => 0];
            Branch        : I18N.AST.Branch_Access := Node.Ord_Exact;
            Index         : Positive := Exact_Targets'First;
         begin
            while Branch /= null loop
               Exact_Targets (Index).Value :=
                 Long_Long_Integer'Value (To_String (Branch.Name));
               Exact_Targets (Index).Target := Next_Index (Build);
               Compile_Nodes (Branch.Body_Root, Build, Substitute => True);
               Append_Stop (Build, Exact_Stops (Index), Restores => True);
               Branch := Branch.Next;
               Index := Index + 1;
            end loop;

            Jump.Exact_Targets :=
              new I18N.Compiled.Exact_Target_Array'(Exact_Targets);
         end;
      end if;

      if Node.Ord_Zero /= null then
         Jump.Zero_Target := Next_Index (Build);
         Compile_Nodes (Node.Ord_Zero, Build, Substitute => True);
         Append_Stop (Build, Stop_Zero, Restores => True);
      end if;

      if Node.Ord_One /= null then
         Jump.One_Target := Next_Index (Build);
         Compile_Nodes (Node.Ord_One, Build, Substitute => True);
         Append_Stop (Build, Stop_One, Restores => True);
      end if;

      if Node.Ord_Two /= null then
         Jump.Two_Target := Next_Index (Build);
         Compile_Nodes (Node.Ord_Two, Build, Substitute => True);
         Append_Stop (Build, Stop_Two, Restores => True);
      end if;

      if Node.Ord_Few /= null then
         Jump.Few_Target := Next_Index (Build);
         Compile_Nodes (Node.Ord_Few, Build, Substitute => True);
         Append_Stop (Build, Stop_Few, Restores => True);
      end if;

      if Node.Ord_Many /= null then
         Jump.Many_Target := Next_Index (Build);
         Compile_Nodes (Node.Ord_Many, Build, Substitute => True);
         Append_Stop (Build, Stop_Many, Restores => True);
      end if;

      Jump.Other_Target := Next_Index (Build);
      Compile_Nodes (Node.Ord_Other, Build, Substitute => True);
      Append_Stop (Build, Stop_Other, Restores => True);

      End_Index := Next_Index (Build);
      Jump.End_Target := End_Index;
      Patch (Build, Jump_Index, Jump);
      Patch_Branch_Stops
        (Build  => Build,
         First  => Jump_Index + 1,
         Last   => End_Index - 1,
         Target => End_Index);
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
                        Currency_Code => null,
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
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
                        Currency_Code => null,
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => False,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Number =>
               Item := (Kind => I18N.Compiled.Number,
                        Text_Value => null,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => False,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Date_Format | I18N.AST.Time_Format
               | I18N.AST.Date_Time_Format =>
               Item := (Kind =>
                          (if Current.Kind = I18N.AST.Date_Format
                           then I18N.Compiled.Date_Format
                           elsif Current.Kind = I18N.AST.Time_Format
                           then I18N.Compiled.Time_Format
                           else I18N.Compiled.Date_Time_Format),
                        Text_Value => null,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => False,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Currency =>
               Item := (Kind => I18N.Compiled.Currency,
                        Text_Value => null,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
                        Male_Target => 0,
                        Female_Target => 0,
                        Male_Hash => 0,
                        Female_Hash => 0,
                        End_Target => 0,
                        Substitute_Number_Sign => False,
                        Restores_Number_Context => False);
               I18N.Compiled.Append (Build, Item);

            when I18N.AST.Duration_Format | I18N.AST.Byte_Size_Format
               | I18N.AST.Unit_Format | I18N.AST.Relative_Time_Format
               | I18N.AST.List_Format =>
               Item := (Kind =>
                          (case Current.Kind is
                              when I18N.AST.Duration_Format =>
                                 I18N.Compiled.Duration_Format,
                              when I18N.AST.Byte_Size_Format =>
                                 I18N.Compiled.Byte_Size_Format,
                              when I18N.AST.Unit_Format =>
                                 I18N.Compiled.Unit_Format,
                              when I18N.AST.Relative_Time_Format =>
                                 I18N.Compiled.Relative_Time_Format,
                              when others =>
                                 I18N.Compiled.List_Format),
                        Text_Value => null,
                        Key => new String'(To_String (Current.Name)),
                        Currency_Code =>
                          new String'(To_String (Current.Currency_Code)),
                        Plural_Offset => 0,
                        Zero_Target => 0,
                        One_Target => 0,
                        Two_Target => 0,
                        Few_Target => 0,
                        Many_Target => 0,
                        Other_Target => 0,
                        Exact_Targets => null,
                        Select_Targets => null,
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
