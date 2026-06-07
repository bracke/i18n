--  Stable v1.0 public diagnostics API.
--
--  Purpose:
--  Diagnostics provide optional, fixed-storage detail about rendering and
--  validation outcomes. They are observational only: disabling diagnostics or
--  changing callbacks must not change output text, render status, runtime
--  contents, cache contents, or IR contents.
--
--  Error behavior:
--  Diagnostic callback exceptions are contained by the runtime. A full
--  Diagnostic_List records Overflow_Warning in the final slot instead of
--  allocating more storage.
--
--  Thread-safety:
--  Diagnostic_List is mutable caller-owned storage. Do not mutate the same list
--  from multiple tasks without external synchronization. Shared callbacks must
--  be externally thread-safe.
--
--  Allocation behavior:
--  Diagnostic entries use fixed-size strings stored inside the record. Clear,
--  Add, Length, Element, Message_Text, Key_Text, and Has_Kind do not grow
--  diagnostic storage.
--
--  Example:
--     if I18N.Diagnostics.Has_Kind
--          (Result.Diagnostics, I18N.Diagnostics.Missing_Variable)
--     then
--        null;
--     end if;
package I18N.Diagnostics is
   pragma SPARK_Mode (On);
   --  Stable public trace event kind.
   type Trace_Event_Kind is
     (Message_Start,
      Op_Text,
      Op_Variable,
      Op_Plural,
      Op_Select,
      Op_Ordinal,
      Message_End);

   --  Optional public trace callback. Callback exceptions are contained by the
   --  runtime and never escape into rendering.
   type Trace_Callback is access procedure
     (Event : Trace_Event_Kind;
      Key   : String);

   --  Install or clear the optional execution trace callback. Passing null
   --  disables tracing. Callback exceptions are contained and never escape into
   --  the renderer.
   --
   --  @param CB Callback to invoke for trace events, or null.
   procedure Set_Trace_Callback
     (CB : Trace_Callback)
   with
     SPARK_Mode => Off;

   --  Structured public diagnostic classification.
   type Diagnostic_Kind is
     (Parse_Error,
      Validation_Error,
      Missing_Variable,
      Missing_Branch,
      Invalid_Ordinal,
      Invalid_Selector,
      Overflow_Warning);

   Max_Diagnostics  : constant Positive := 8;
   Message_Capacity : constant Positive := 96;
   Key_Capacity     : constant Positive := 64;

   --  Fixed-storage diagnostic entry.
   --
   --  Message and Key are bounded slices stored directly in the record.
   --  Message_Last and Key_Last identify the meaningful prefix.
   type Diagnostic is record
      Kind         : Diagnostic_Kind := Parse_Error;
      Message      : String (1 .. Message_Capacity) := [others => Character'Val (0)];
      Message_Last : Natural range 0 .. Message_Capacity := 0;
      Key          : String (1 .. Key_Capacity) := [others => Character'Val (0)];
      Key_Last     : Natural range 0 .. Key_Capacity := 0;
   end record;

   --  Public diagnostic array type.
   type Diagnostic_Array is array (Positive range <>) of Diagnostic;

   --  Preallocated diagnostic list used by Result and execution contexts.
   type Diagnostic_List is record
      Items : Diagnostic_Array (1 .. Max_Diagnostics);
      Count : Natural range 0 .. Max_Diagnostics := 0;
   end record;

   --  Reset a diagnostic list without releasing storage.
   --
   --  @param List Diagnostic list to clear.
   procedure Clear
     (List : in out Diagnostic_List)
   with
     Global => null,
     Post   => Length (List) = 0;

   --  Append one diagnostic if capacity remains.
   --
   --  If capacity is already full, overwrite the final slot with
   --  Overflow_Warning so truncation remains visible without growing storage.
   --
   --  @param List Diagnostic list to update.
   --  @param Kind Structured diagnostic kind.
   --  @param Message Static or caller-owned message text to copy.
   --  @param Key Optional ICU argument/message key to copy.
   procedure Add
     (List    : in out Diagnostic_List;
      Kind    : Diagnostic_Kind;
      Message : String := "";
      Key     : String := "")
   with
     Global => null,
     Post   => Length (List) <= Max_Diagnostics;

   --  @param List Diagnostic list to inspect.
   --  @return Number of stored diagnostics.
   function Length
     (List : Diagnostic_List)
      return Natural is (List.Count)
   with
     Global => null,
     Post   => Length'Result <= Max_Diagnostics;

   --  @param List Diagnostic list to inspect.
   --  @param Index One-based diagnostic index.
   --  @return Diagnostic at Index.
   function Element
     (List  : Diagnostic_List;
      Index : Positive)
      return Diagnostic
   with
     Global => null;

   --  @param Item Diagnostic to inspect.
   --  @return Message slice without fixed-storage padding.
   function Message_Text
     (Item : Diagnostic)
      return String
   with
     Global => null,
     Post   => Message_Text'Result'Length = Item.Message_Last;

   --  @param Item Diagnostic to inspect.
   --  @return Key slice without fixed-storage padding.
   function Key_Text
     (Item : Diagnostic)
      return String
   with
     Global => null,
     Post   => Key_Text'Result'Length = Item.Key_Last;

   --  @param List Diagnostic list to inspect.
   --  @param Kind Diagnostic kind to find.
   --  @return True when a diagnostic of Kind is present.
   function Has_Kind
     (List : Diagnostic_List;
      Kind : Diagnostic_Kind)
      return Boolean
   with
     Global => null;

end I18N.Diagnostics;
