with Ada.Strings.Unbounded;

private package I18N.AST is
   pragma Preelaborate;

   --  Kind of a parsed message node.
   type Node_Kind is
     (Text,
      Variable,
      Number,
      Date_Format,
      Time_Format,
      Date_Time_Format,
      Currency,
      Duration_Format,
      Byte_Size_Format,
      Unit_Format,
      Relative_Time_Format,
      List_Format,
      Plural,
      Select_Node,
      SelectOrdinal);

   type Node;
   type Node_Access is access all Node;

   type Select_Branch;
   type Branch_Access is access all Select_Branch;

   --  One named branch of a generalized select node.
   --
   --  Name is a validated identifier (for example "male", "female", "full",
   --  "short", "other"). Body_Root is the branch's AST root. Next preserves
   --  source order of branches. The mandatory fallback branch is named "other".
   type Select_Branch is record
      Name      : Ada.Strings.Unbounded.Unbounded_String;
      Body_Root : Node_Access := null;
      Next      : Branch_Access := null;
   end record;

   --  Single node in the linked-list AST.
   --
   --  Text nodes use Text. Variable and Number nodes use Name. Date_Format,
   --  Time_Format, and Date_Time_Format nodes use Name plus Currency_Code as
   --  private style/zone storage.
   --  Currency nodes use Name as the amount argument and Currency_Code as the
   --  ISO currency code. Plural nodes use Name as the selector argument,
   --  Plural_Offset for ICU offset:N, and Plural_* fields as branch AST roots.
   --  Select
   --  nodes use Name as the selector argument and use Branches, a list of
   --  named branches, as their dispatch table. SelectOrdinal nodes use Name as
   --  the numeric selector argument and use Ord_* as branch AST roots. Next
   --  preserves source order at the current nesting level.
   type Node is record
      Kind  : Node_Kind;
      Text  : Ada.Strings.Unbounded.Unbounded_String;
      Name  : Ada.Strings.Unbounded.Unbounded_String;
      Currency_Code : Ada.Strings.Unbounded.Unbounded_String;
      Plural_Offset : Long_Long_Integer := 0;
      Plural_Zero : Node_Access := null;
      One    : Node_Access := null;
      Plural_Two  : Node_Access := null;
      Plural_Few  : Node_Access := null;
      Plural_Many : Node_Access := null;
      Other  : Node_Access := null;
      Plural_Exact : Branch_Access := null;
      Branches : Branch_Access := null;
      Ord_Zero  : Node_Access := null;
      Ord_One   : Node_Access := null;
      Ord_Two   : Node_Access := null;
      Ord_Few   : Node_Access := null;
      Ord_Many  : Node_Access := null;
      Ord_Other : Node_Access := null;
      Ord_Exact : Branch_Access := null;
      Next   : Node_Access := null;
   end record;

   --  Append a named branch to a select branch list.
   --
   --  Ownership of Body_Root is transferred to the new branch and Body_Root is
   --  set to null. Branches preserve source order.
   --
   --  @param Head First branch in the list. Updated when the list is empty.
   --  @param Tail Last branch in the list. Updated to the newly appended branch.
   --  @param Name Validated branch identifier.
   --  @param Body_Root AST root for the branch. May be null for an empty branch.
   procedure Append_Branch
     (Head      : in out Branch_Access;
      Tail      : in out Branch_Access;
      Name      : String;
      Body_Root : in out Node_Access);

   --  Report whether a select branch list already contains a branch named Name.
   --
   --  @param Branches First branch in the list.
   --  @param Name Branch identifier to find.
   --  @return True when Name is present.
   function Has_Branch
     (Branches : Branch_Access;
      Name     : String)
      return Boolean;

   --  Return the body AST for a named branch, or null when absent.
   --
   --  @param Branches First branch in the list.
   --  @param Name Branch identifier to resolve.
   --  @return Branch body root, or null when Name is absent.
   function Branch_Body
     (Branches : Branch_Access;
      Name     : String)
      return Node_Access;

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

   --  Append a number-formatting node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Numeric argument name to resolve during rendering.
   procedure Append_Number
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "");

   --  Append a date-formatting node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Date argument name to resolve during rendering.
   --  @param Style Optional date style: empty, short, medium, or long.
   procedure Append_Date
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "");

   --  Append a time-formatting node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Time argument name to resolve during rendering.
   --  @param Style Optional time style: empty, short, medium, or long.
   procedure Append_Time
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "");

   --  Append a date-time-formatting node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Date-time argument name to resolve during rendering.
   --  @param Style Optional style/zone option.
   procedure Append_Date_Time
     (Head : in out Node_Access;
      Tail : in out Node_Access;
      Name : String;
      Style : String := "");

   --  Append a currency-formatting node to a linked AST.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Amount argument name to resolve during rendering.
   --  @param Currency_Code Three-letter uppercase ISO currency code, optionally
   --  followed by a supported display/cash/accounting option suffix.
   procedure Append_Currency
     (Head          : in out Node_Access;
      Tail          : in out Node_Access;
      Name          : String;
      Currency_Code : String);

   procedure Append_Extra_Format
     (Head   : in out Node_Access;
      Tail   : in out Node_Access;
      Kind   : Node_Kind;
      Name   : String;
      Option : String := "");

   --  Append a plural node to a linked AST.
   --
   --  Ownership of category branches is transferred to the appended plural
   --  node. Validation requires only the Other branch; absent category branches
   --  are valid and fall back to Other at render time.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Selector argument name. Must not be empty.
   --  @param Zero AST root for the zero branch. May be null when absent.
   --  @param One AST root for the one branch. May be null when absent.
   --  @param Two AST root for the two branch. May be null when absent.
   --  @param Few AST root for the few branch. May be null when absent.
   --  @param Many AST root for the many branch. May be null when absent.
   --  @param Other AST root for the fallback branch. May be null for an empty branch.
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
      Exact : in out Branch_Access);

   --  Release every branch in a select branch list, including each branch body,
   --  and set Branches to null.
   --
   --  @param Branches First branch to release.
   procedure Free_Branches
     (Branches : in out Branch_Access);

   --  Append a generalized select node to a linked AST.
   --
   --  Ownership of the Branches list is transferred to the appended select node
   --  and Branches is set to null. Branch names are arbitrary validated
   --  identifiers; the mandatory fallback branch named "other" is enforced by
   --  I18N.Validation before evaluation.
   --
   --  @param Head First node in the AST. Updated when the list is empty.
   --  @param Tail Last node in the AST. Updated to the newly appended node.
   --  @param Name Selector argument name. Must not be empty.
   --  @param Branches Named branch list. Ownership is transferred.
   procedure Append_Select
     (Head     : in out Node_Access;
      Tail     : in out Node_Access;
      Name     : String;
      Branches : in out Branch_Access);

   --  Append a selectordinal node to a linked AST.
   --
   --  Ownership of Zero, One, Two, Few, Many, and Other is transferred to the
   --  appended selectordinal node. Validation requires only the Other branch;
   --  absent category branches are valid and fall back to Other at render time.
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
      Zero  : in out Node_Access;
      One   : in out Node_Access;
      Two   : in out Node_Access;
      Few   : in out Node_Access;
      Many  : in out Node_Access;
      Other : in out Node_Access;
      Exact : in out Branch_Access);

   --  Release every node in a linked AST and set Root to null. Plural, select,
   --  and selectordinal branch subtrees are released recursively.
   --
   --  @param Root First AST node to release.
   procedure Free
     (Root : in out Node_Access);

end I18N.AST;
