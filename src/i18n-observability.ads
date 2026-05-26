private package I18N.Observability is
   --  Optional trace event kind.
   type Trace_Event_Kind is
     (Message_Start,
      Op_Text,
      Op_Variable,
      Op_Plural,
      Op_Select,
      Op_Ordinal,
      Message_End);

   type Trace_Callback is access procedure
     (Event : Trace_Event_Kind;
      Key   : String);

   Message_Key_Capacity : constant Positive := 128;
   Locale_Capacity      : constant Positive := 32;

   --  Caller-owned execution metadata. Fixed storage preserves the fixed-buffer
   --  no-allocation render-path contract.
   type Execution_Metadata is record
      Message_Key      : String (1 .. Message_Key_Capacity) := [others => Character'Val (0)];
      Message_Key_Last : Natural := 0;
      Locale           : String (1 .. Locale_Capacity) := [others => Character'Val (0)];
      Locale_Last      : Natural := 0;
      Depth            : Natural := 0;
   end record;

   --  Set the process-wide optional trace callback. Passing null disables
   --  tracing. The callback itself must be thread-safe when used by multiple
   --  rendering tasks.
   --
   --  @param CB Callback to invoke for trace events, or null.
   procedure Set_Trace_Callback
     (CB : Trace_Callback);

   --  Return the currently configured callback.
   --
   --  @return Current optional trace callback.
   function Current_Trace_Callback
      return Trace_Callback;

   --  Emit an event when a callback is configured. This routine performs no
   --  allocation; the Key argument is passed through as a borrowed slice.
   --  Exceptions raised by callbacks are swallowed so tracing remains strictly
   --  observational and cannot change render correctness.
   --
   --  @param Event Event kind to emit.
   --  @param Key Operation or message key associated with the event.
   procedure Emit
     (Event : Trace_Event_Kind;
      Key   : String := "");

   --  Store message key metadata in fixed storage.
   --
   --  @param Metadata Metadata record to update.
   --  @param Value Message key text to copy.
   procedure Set_Message_Key
     (Metadata : in out Execution_Metadata;
      Value    : String);

   --  Store locale metadata in fixed storage.
   --
   --  @param Metadata Metadata record to update.
   --  @param Value Locale text to copy.
   procedure Set_Locale
     (Metadata : in out Execution_Metadata;
      Value    : String);

   --  @param Metadata Metadata record to inspect.
   --  @return Message key slice without padding.
   function Message_Key
     (Metadata : Execution_Metadata)
      return String;

   --  @param Metadata Metadata record to inspect.
   --  @return Locale slice without padding.
   function Locale
     (Metadata : Execution_Metadata)
      return String;

end I18N.Observability;
