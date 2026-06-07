with Ada.Unchecked_Deallocation;

package body I18N.AST is

   use Ada.Strings.Unbounded;

   procedure Free_Node is new Ada.Unchecked_Deallocation
     (Object => Node,
      Name   => Node_Access);

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
              One    => null,
              Other  => null,
              Male   => null,
              Female => null,
              Select_Other => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Other => null,
              Next   => null));
   end Append_Text;

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
              One    => null,
              Other  => null,
              Male   => null,
              Female => null,
              Select_Other => null,
              Ord_One   => null,
              Ord_Two   => null,
              Ord_Few   => null,
              Ord_Other => null,
              Next   => null));
   end Append_Variable;

   procedure Append_Plural
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      One   : in out Node_Access;
      Other : in out Node_Access)
   is
      Item : Node_Access;
   begin
      pragma Assert (Name'Length > 0, "Plural selector name must not be empty");

      if Name'Length = 0 then
         raise Constraint_Error with "Plural selector name must not be empty";
      end if;

      Item :=
        new Node'
          (Kind  => I18N.AST.Plural,
           Text  => Null_Unbounded_String,
           Name  => To_Unbounded_String (Name),
           One    => One,
           Other  => Other,
           Male   => null,
           Female => null,
           Select_Other => null,
           Ord_One   => null,
           Ord_Two   => null,
           Ord_Few   => null,
           Ord_Other => null,
           Next   => null);

      One := null;
      Other := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Plural;

   procedure Append_Select
     (Head   : in out Node_Access;
      Tail   : in out Node_Access;
      Name   : String;
      Male   : in out Node_Access;
      Female : in out Node_Access;
      Other  : in out Node_Access)
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
           One    => null,
           Other  => null,
           Male   => Male,
           Female => Female,
           Select_Other => Other,
           Ord_One   => null,
           Ord_Two   => null,
           Ord_Few   => null,
           Ord_Other => null,
           Next   => null);

      Male := null;
      Female := null;
      Other := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Select;

   procedure Append_Select_Ordinal
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      One   : in out Node_Access;
      Two   : in out Node_Access;
      Few   : in out Node_Access;
      Other : in out Node_Access)
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
           One       => null,
           Other     => null,
           Male      => null,
           Female    => null,
           Select_Other    => null,
           Ord_One   => One,
           Ord_Two   => Two,
           Ord_Few   => Few,
           Ord_Other => Other,
           Next      => null);

      One := null;
      Two := null;
      Few := null;
      Other := null;

      Append_Node
        (Head => Head,
         Tail => Tail,
         Item => Item);
   end Append_Select_Ordinal;

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
            Free (Current.One);
            Free (Current.Other);
         elsif Current.Kind = I18N.AST.Select_Node then
            Free (Current.Male);
            Free (Current.Female);
            Free (Current.Select_Other);
         elsif Current.Kind = I18N.AST.SelectOrdinal then
            Free (Current.Ord_One);
            Free (Current.Ord_Two);
            Free (Current.Ord_Few);
            Free (Current.Ord_Other);
         end if;

         Free_Node (Current);
         Current := Next;
      end loop;

      Root := null;
   end Free;

end I18N.AST;
