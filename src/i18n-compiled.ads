with Ada.Containers;
with Ada.Containers.Vectors;

private package I18N.Compiled is
   --  Linear operation kind.
   type Op_Kind is
     (Text,
      Var,
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
      Jump_Plural,
      Jump_Select,
      Jump_Ordinal,
      Stop_Branch);

   subtype Op_Index is Natural;

   --  Immutable string storage owned by compiled IR construction.
   --
   --  Values of this type are allocated during compilation/cache fill only and
   --  are treated as read-only during execution. The render loop dereferences
   --  them directly and never materializes Unbounded_String values.
   type Interned_String is access constant String;

   type Exact_Target is record
      Value  : Long_Long_Integer := 0;
      Target : Op_Index := 0;
   end record;

   type Exact_Target_Array is array (Positive range <>) of Exact_Target;
   type Exact_Target_Array_Access is access constant Exact_Target_Array;

   type Select_Target is record
      Name   : Interned_String := null;
      Hash   : Ada.Containers.Hash_Type := 0;
      Target : Op_Index := 0;
   end record;

   type Select_Target_Array is array (Positive range <>) of Select_Target;
   type Select_Target_Array_Access is access constant Select_Target_Array;

   --  One flattened operation in a compiled ICU message.
   --
   --  Text operations use Text_Value. Var, Number, Date_Format, Time_Format,
   --  Date_Time_Format, and branch operations use Key. Currency operations use Key plus
   --  Currency_Code. Branch operations use
   --  precomputed target indexes. Select operations also store precomputed
   --  selector hashes for constant-time branch dispatch. Stop_Branch jumps to
   --  End_Target and optionally restores the previous active number substitution
   --  context. Text_Value, Key, and Currency_Code are immutable references
   --  allocated during compilation.
   type Op is record
      Kind : Op_Kind := Text;
      Text_Value : Interned_String := null;
      Key  : Interned_String := null;
      Currency_Code : Interned_String := null;
      Plural_Offset : Long_Long_Integer := 0;
      Zero_Target   : Op_Index := 0;
      One_Target    : Op_Index := 0;
      Two_Target    : Op_Index := 0;
      Few_Target    : Op_Index := 0;
      Many_Target   : Op_Index := 0;
      Other_Target  : Op_Index := 0;
      Exact_Targets : Exact_Target_Array_Access := null;
      Select_Targets : Select_Target_Array_Access := null;
      Male_Target   : Op_Index := 0;
      Female_Target : Op_Index := 0;
      Male_Hash     : Ada.Containers.Hash_Type := 0;
      Female_Hash   : Ada.Containers.Hash_Type := 0;
      End_Target    : Op_Index := 0;
      Substitute_Number_Sign : Boolean := False;
      Restores_Number_Context : Boolean := False;
   end record;

   --  Flattened compiled message IR. Limited by construction so user code
   --  cannot copy or assign compiled message objects directly. Operation storage
   --  is an immutable array snapshot once a message is created.
   type Compiled_Message is limited private;

   --  Opaque shared reference to immutable compiled operation storage. This is
   --  used by the cache/runtime to bind handles without copying IR arrays.
   type Message_Reference is private;

   --  Mutable construction-only IR builder used by the compiler before Freeze.
   --  It is not used by the execution engine or cache hot path.
   type Builder is limited private;

   --  @param Msg Compiled message to inspect.
   --  @return Number of linear operations in Msg.
   function Op_Count
     (Msg : Compiled_Message)
      return Natural;

   --  @param Msg Compiled message to inspect.
   --  @return Last operation index or 0 for an empty message.
   function Last_Index
     (Msg : Compiled_Message)
      return Natural;

   --  @param Msg Compiled message to inspect.
   --  @param Index Operation index to read.
   --  @return Operation stored at Index.
   function Element
     (Msg   : Compiled_Message;
      Index : Positive)
      return Op;

   --  Remove this handle's operation reference. This does not reclaim interned
   --  literal storage because compiled literals may be shared by cached immutable
   --  message references.
   --
   --  @param Msg Compiled message to clear.
   procedure Clear
     (Msg : in out Compiled_Message);

   --  Return a shared immutable reference to Msg's operation storage.
   --
   --  @param Msg Compiled message to reference.
   --  @return Shared immutable operation-storage reference.
   function Reference
     (Msg : Compiled_Message)
      return Message_Reference;

   --  Bind Msg to an existing immutable operation-storage reference.
   --
   --  @param Msg Compiled message handle to update.
   --  @param Ref Shared immutable operation-storage reference.
   procedure Set_Reference
     (Msg : out Compiled_Message;
      Ref : Message_Reference);

   --  @param Build Builder to inspect.
   --  @return Number of operations currently stored in Build.
   function Op_Count
     (Build : Builder)
      return Natural;

   --  @param Build Builder to inspect.
   --  @return Last builder operation index or 0 for an empty builder.
   function Last_Index
     (Build : Builder)
      return Natural;

   --  @param Build Builder to inspect.
   --  @param Index Operation index to read.
   --  @return Operation stored at Index.
   function Element
     (Build : Builder;
      Index : Positive)
      return Op;

   --  Append one operation. Intended for compiler/cache construction only.
   --
   --  @param Build Builder under construction.
   --  @param Item Operation to append.
   procedure Append
     (Build : in out Builder;
      Item  : Op);

   --  Replace one operation during compiler backpatching.
   --
   --  @param Build Builder under construction.
   --  @param Index Operation index to replace.
   --  @param Item Replacement operation.
   procedure Replace_Element
     (Build : in out Builder;
      Index : Positive;
      Item  : Op);

   --  Freeze builder operations into an immutable compiled-message snapshot.
   --
   --  @param Build Construction builder to freeze.
   --  @return Immutable compiled message.
   function Freeze
     (Build : Builder)
      return Compiled_Message;

private

   package Op_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Op);

   type Op_Array is array (Positive range <>) of Op;
   type Operation_Array_Access is access constant Op_Array;
   type Message_Reference is record
      Ops : Operation_Array_Access := null;
   end record;

   type Compiled_Message is limited record
      Ops : Operation_Array_Access := null;
   end record;

   type Builder is limited record
      Ops : Op_Vectors.Vector;
   end record;

end I18N.Compiled;
