with Ada.Unchecked_Deallocation;

package body I18N.AST is

   use Ada.Strings.Unbounded;

   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Object => Node,
      Name   => Node_Access);

   procedure Free_Branch is new Ada.Unchecked_Deallocation
     (Object => Select_Branch,
      Name   => Branch_Access);

   procedure Append_Node
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Item : Node_Access)
   is
   begin
      pragma Assert (Item /= null, "Cannot append null AST node");
      pragma Assert (Item.Next = null, "Appended AST node must not already be linked");

      if Head = null then
         Head := Item;
         Tail := Item;
      else
         pragma Assert (Tail /= null, "AST tail missing while head exists");
         pragma Assert (Tail.Next = null, "AST tail must terminate the chain");

         Tail.Next := Item;
         Tail := Item;
      end if;

      pragma Assert (Tail /= null, "AST append failed to set tail");
      pragma Assert (Tail.Next = null, "AST tail must remain terminal after append");
   end Append_Node;

   procedure Append_Text
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Text : String)
   is
   begin
      if Text'Length = 0 then
         return;
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Text,
              Text  => To_Unbounded_String (Text),
              Name  => Null_Unbounded_String,
              Currency_Code => Null_Unbounded_String,
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Text;

   procedure Append_Branch
     (Head      : in out Branch_Access;
      Tail      : in out Branch_Access;
      Name      : String;
      Body_Root : in out Node_Access)
   is
      Item : constant Branch_Access :=
        new Select_Branch'
          (Name      => To_Unbounded_String (Name),
           Body_Root => Body_Root,
           Next      => null);
   begin
      Body_Root := null;

      if Head = null then
         Head := Item;
         Tail := Item;
      else
         Tail.Next := Item;
         Tail := Item;
      end if;
   end Append_Branch;

   function Has_Branch
     (Branches : Branch_Access;
      Name     : String)
      return Boolean
   is
      Current : Branch_Access := Branches;
   begin
      while Current /= null loop
         if To_String (Current.Name) = Name then
            return True;
         end if;
         Current := Current.Next;
      end loop;
      return False;
   end Has_Branch;

   function Branch_Body
     (Branches : Branch_Access;
      Name     : String)
      return Node_Access
   is
      Current : Branch_Access := Branches;
   begin
      while Current /= null loop
         if To_String (Current.Name) = Name then
            return Current.Body_Root;
         end if;
         Current := Current.Next;
      end loop;
      return null;
   end Branch_Body;

   procedure Append_Variable
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String)
   is
   begin
      pragma Assert (Name'Length > 0, "Variable node name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Variable node name must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Variable,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => Null_Unbounded_String,
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Variable;

   procedure Append_Number
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "")
   is
   begin
      pragma Assert (Name'Length > 0, "Number argument name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Number argument name must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Number,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Style),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Number;

   procedure Append_Date
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "")
   is
   begin
      pragma Assert (Name'Length > 0, "Date argument name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Date argument name must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Date_Format,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Style),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Date;

   procedure Append_Time
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "")
   is
   begin
      pragma Assert (Name'Length > 0, "Time argument name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Time argument name must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Time_Format,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Style),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Time;

   procedure Append_Date_Time
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "")
   is
   begin
      pragma Assert
        (Name'Length > 0, "Date-time argument name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Date-time argument name must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Date_Time_Format,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Style),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Date_Time;

   procedure Append_Currency
     (Head          : in out Node_Access;
      Tail          : in out Node_Access;
      Name          : String;
      Currency_Code : String)
   is
   begin
      pragma Assert (Name'Length > 0, "Currency amount name must not be empty");
      pragma Assert
        (Currency_Code'Length > 0, "Currency code must not be empty");

      if Name'Length = 0 or else Currency_Code'Length = 0 then
         raise Constraint_Error with "Currency node fields must not be empty";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => I18N.AST.Currency,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Currency_Code),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Currency;

   procedure Append_Extra_Format
     (Head   : in out Node_Access;
      Tail   : in out Node_Access;
      Kind   : Node_Kind;
      Name   : String;
      Option : String := "")
   is
   begin
      pragma Assert (Name'Length > 0, "Formatted argument name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Formatted argument name must not be empty";
      elsif Kind not in Duration_Format | Byte_Size_Format | Unit_Format
        | Relative_Time_Format | List_Format
      then
         raise Constraint_Error with "Invalid extra formatter node kind";
      end if;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item =>
           new Node'
             (Kind  => Kind,
              Text  => Null_Unbounded_String,
              Name  => To_Unbounded_String (Name),
              Currency_Code => To_Unbounded_String (Option),
              Plural_Offset => 0,
              Plural_Zero => null,
              One    => null,
              Plural_Two  => null,
              Plural_Few  => null,
              Plural_Many => null,
              Other  => null,
              Plural_Exact => null,
              Branches => null,
              Ord_Zero  => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Many  => null,
              Ord_Other => null,
              Ord_Exact => null,
              Next   => null));
   end Append_Extra_Format;

   procedure Append_Plural
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      Offset : Long_Long_Integer;
      Zero  : in out Node_Access;
      One   : in out Node_Access;
      Two   : in out Node_Access;
      Few   : in out Node_Access;
      Many  : in out Node_Access;
      Other : in out Node_Access;
      Exact : in out Branch_Access)
   is
      Item : Node_Access;
   begin
      pragma Assert (Name'Length > 0, "Plural selector name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Plural selector name must not be empty";
      elsif Offset < 0 then
         raise Constraint_Error with "Plural offset must not be negative";
      end if;

      Item :=
        new Node'
          (Kind  => I18N.AST.Plural,
           Text  => Null_Unbounded_String,
           Name  => To_Unbounded_String (Name),
           Currency_Code => Null_Unbounded_String,
           Plural_Offset => Offset,
           Plural_Zero => Zero,
           One    => One,
           Plural_Two  => Two,
           Plural_Few  => Few,
           Plural_Many => Many,
           Other  => Other,
           Plural_Exact => Exact,
           Branches => null,
           Ord_Zero  => null,
           Ord_One   => null,
           Ord_Two   => null,
           Ord_Few   => null,
           Ord_Many  => null,
           Ord_Other => null,
           Ord_Exact => null,
           Next   => null);

      Zero := null;
      One := null;
      Two := null;
      Few := null;
      Many := null;
      Other := null;
      Exact := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Plural;

   procedure Append_Select
     (Head     : in out Node_Access;
      Tail     : in out Node_Access;
      Name     : String;
      Branches : in out Branch_Access)
   is
      Item : Node_Access;
   begin
      pragma Assert (Name'Length > 0, "Select selector name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Select selector name must not be empty";
      end if;

      Item :=
        new Node'
          (Kind   => I18N.AST.Select_Node,
           Text   => Null_Unbounded_String,
           Name   => To_Unbounded_String (Name),
           Currency_Code => Null_Unbounded_String,
           Plural_Offset => 0,
           Plural_Zero => null,
           One    => null,
           Plural_Two  => null,
           Plural_Few  => null,
           Plural_Many => null,
           Other  => null,
           Plural_Exact => null,
           Branches => Branches,
           Ord_Zero  => null,
           Ord_One   => null,
           Ord_Two   => null,
           Ord_Few   => null,
           Ord_Many  => null,
           Ord_Other => null,
           Ord_Exact => null,
           Next   => null);

      Branches := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Select;

   procedure Append_Select_Ordinal
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      Zero  : in out Node_Access;
      One   : in out Node_Access;
      Two   : in out Node_Access;
      Few   : in out Node_Access;
      Many  : in out Node_Access;
      Other : in out Node_Access;
      Exact : in out Branch_Access)
   is
      Item : Node_Access;
   begin
      pragma Assert (Name'Length > 0, "Selectordinal selector name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Selectordinal selector name must not be empty";
      end if;

      Item :=
        new Node'
          (Kind      => I18N.AST.SelectOrdinal,
           Text      => Null_Unbounded_String,
           Name      => To_Unbounded_String (Name),
           Currency_Code => Null_Unbounded_String,
           Plural_Offset => 0,
           Plural_Zero => null,
           One       => null,
           Plural_Two  => null,
           Plural_Few  => null,
           Plural_Many => null,
           Other     => null,
           Plural_Exact => null,
           Branches  => null,
           Ord_Zero  => Zero,
           Ord_One   => One,
           Ord_Two   => Two,
           Ord_Few   => Few,
           Ord_Many  => Many,
           Ord_Other => Other,
           Ord_Exact => Exact,
           Next      => null);

      Zero := null;
      One := null;
      Two := null;
      Few := null;
      Many := null;
      Other := null;
      Exact := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Select_Ordinal;

   procedure Free_Branches
     (Branches : in out Branch_Access)
   is
      Current : Branch_Access := Branches;
      Next    : Branch_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Free (Current.Body_Root);
         Free_Branch (Current);
         Current := Next;
      end loop;
      Branches := null;
   end Free_Branches;

   procedure Free
     (Root : in out Node_Access)
   is
      Current : Node_Access := Root;
      Next    : Node_Access;
   begin
      while Current /= null loop
         Next := Current.Next;
         Current.Next := null;

         if Current.Kind = I18N.AST.Plural then
            Free (Current.Plural_Zero);
            Free (Current.One);
            Free (Current.Plural_Two);
            Free (Current.Plural_Few);
            Free (Current.Plural_Many);
            Free (Current.Other);
            Free_Branches (Current.Plural_Exact);
         elsif Current.Kind = I18N.AST.Select_Node then
            Free_Branches (Current.Branches);
         elsif Current.Kind = I18N.AST.SelectOrdinal then
            Free (Current.Ord_Zero);
            Free (Current.Ord_One);
            Free (Current.Ord_Two);
            Free (Current.Ord_Few);
            Free (Current.Ord_Many);
            Free (Current.Ord_Other);
            Free_Branches (Current.Ord_Exact);
         end if;

         Free_Node (Current);
         Current := Next;
      end loop;

      Root := null;
   end Free;

end I18N.AST;
