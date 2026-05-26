with Ada.Strings.Unbounded;

private package I18N.AST is
   pragma Preelaborate;

   --  Kind of a parsed message node.
   type Node_Kind is
     (Text,
      Variable,
      Plural,
      Select_Node,
      SelectOrdinal);

   type Node;
   type Node_Access is access all Node;

   --  Single node in the linked-list AST.
   --
   --  Text nodes use Text. Variable nodes use Name. Plural nodes use Name as
   --  the selector argument and use One and Other as branch AST roots. Select
   --  nodes use Name as the selector argument and use Male, Female, and Select_Other
   --  as branch AST roots. SelectOrdinal nodes use Name as the numeric
   --  selector argument and use Ord_One, Ord_Two, Ord_Few, and Ord_Other
   --  as branch AST roots. Next preserves source order at the current nesting
   --  level.
   type Node is record
      Kind  : Node_Kind;
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      One    : Node_Access := null;
      Other  : Node_Access := null;
      Male   : Node_Access := null;
      Female : Node_Access := null;
      Select_Other : Node_Access := null;
      Ord_One   : Node_Access := null;
      Ord_Two   : Node_Access := null;
      Ord_Few   : Node_Access := null;
      Ord_Other : Node_Access := null;
      Next   : Node_Access := null;
   end record;

   --  Append a non-empty text node to a linked AST. Empty text is ignored.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Text Literal text to append.
   procedure Append_Text
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Text : String);

   --  Append a variable node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Variable name to resolve during rendering. Must not be empty.
   procedure Append_Variable
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String);

   --  Append a plural node to a linked AST.
   --
   --  Ownership of One and Other is transferred to the appended plural node.
   --  validation requires both branches before evaluation; callers may
   --  still pass null when constructing incomplete ASTs for validation tests.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Selector argument name. Must not be empty.
   --  @param One AST root for the one branch. May be null for an empty branch.
   --  @param Other AST root for the fallback branch. May be null for an empty branch.
   procedure Append_Plural
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      One   : in out Node_Access;
      Other : in out Node_Access);

   --  Append a select node to a linked AST.
   --
   --  Ownership of Male, Female, and Other is transferred to the appended select
   --  node. Parser-produced explicit empty branches use a non-null empty text
   --  node. Null Male/Female means the optional branch is absent.
   --  Validation requires Other as the fallback before evaluation.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Selector argument name. Must not be empty.
   --  @param Male AST root for the male branch. May be null when absent.
   --  @param Female AST root for the female branch. May be null when absent.
   --  @param Other AST root for the mandatory fallback branch.
   procedure Append_Select
     (Head   : in out Node_Access;
      Tail   : in out Node_Access;
      Name   : String;
      Male   : in out Node_Access;
      Female : in out Node_Access;
      Other  : in out Node_Access);

   --  Append a selectordinal node to a linked AST.
   --
   --  Ownership of One, Two, Few, and Other is transferred to the appended
   --  selectordinal node. validation requires One, Two, Few, and Other
   --  before evaluation; callers may still pass null when constructing
   --  incomplete ASTs for validation tests.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Numeric selector argument name. Must not be empty.
   --  @param One AST root for the one branch. May be null when absent.
   --  @param Two AST root for the two branch. May be null when absent.
   --  @param Few AST root for the few branch. May be null when absent.
   --  @param Other AST root for the mandatory fallback branch.
   procedure Append_Select_Ordinal
     (Head  : in out Node_Access;
      Tail  : in out Node_Access;
      Name  : String;
      One   : in out Node_Access;
      Two   : in out Node_Access;
      Few   : in out Node_Access;
      Other : in out Node_Access);

   --  Release every node in a linked AST and set Root to null. Plural, select,
   --  and selectordinal branch subtrees are released recursively.
   --
   --  @param Root First AST node to release.
   procedure Free
     (Root : in out Node_Access);

end I18N.AST;
