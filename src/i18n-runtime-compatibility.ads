with I18N.Buffer;
with I18N.Diagnostics;
with I18N.Errors;
with I18N.Observability;
with I18N.Arguments;

--  Internal/test compatibility API for in-tree regression tests.
--
--  This child package is not part of the stable application API. It keeps
--  the single-message, fixed-buffer, and internal-error entry points
--  available for regression and differential tests without exposing them from
--  I18N.Runtime itself.
--
--  Semantics note: this path drives the legacy compiled IR (I18N.Compiler /
--  I18N.Fast_Render), which is locale-agnostic and supports only male/female/
--  other select branches and a hardcoded plural/ordinal category mapping. The
--  authoritative public path is I18N.Runtime.Render / Render_Into, which adds
--  generalized select branches and locale-aware plural/selectordinal selection
--  through I18N.Plurals. Both share the "only other is mandatory" branch
--  policy. Do not treat the compatibility path as a reference for public
--  rendering semantics.
private package I18N.Runtime.Compatibility is

   --  Initialize the compatibility single-message runtime path.
   --
   --  @param Item Runtime instance to initialize.
   --  @param Source ICU message source to parse, validate, and compile.
   procedure Initialize_Message
     (Item   : in out Runtime;
      Source : String);

   type Execution_Context is record
      Buffer      : aliased I18N.Buffer.Buffer;
      Args        : I18N.Arguments.Arguments;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
      Metadata    : I18N.Observability.Execution_Metadata;
   end record;

   --  Install the compatibility trace callback.
   --
   --  @param CB Callback to invoke for trace events, or null to disable tracing.
   procedure Set_Trace_Callback
     (CB : I18N.Observability.Trace_Callback);

   --  Render the initialized compatibility message with the supplied arguments.
   --
   --  @param Item Initialized runtime instance.
   --  @param Args Runtime argument map.
   --  @return Internal structured render result for regression tests.
   function Render
     (Item : Runtime;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result;

   --  Render using caller-owned compatibility execution context.
   --
   --  @param Item Initialized runtime instance.
   --  @param Context Caller-owned execution context, buffer, and diagnostics.
   --  @return Internal structured render result for regression tests.
   function Render
     (Item    : Runtime;
      Context : in out Execution_Context)
      return I18N.Errors.Result;

   --  Render into the fixed buffer stored in Context.
   --
   --  @param Item Initialized runtime instance.
   --  @param Context Caller-owned execution context and output buffer.
   --  @return Internal render status for the fixed-buffer path.
   function Render_Into
     (Item    : Runtime;
      Context : in out Execution_Context)
      return I18N.Errors.Status;

   --  Report whether the compatibility single-message runtime has a compiled root.
   --
   --  @param Item Runtime instance to inspect.
   --  @return True when the compatibility message root is initialized.
   function Has_Root
     (Item : Runtime)
      return Boolean;

   --  Return the last deterministic compatibility error.
   --
   --  @param Item Runtime instance to inspect.
   --  @return Last internal error kind recorded by compatibility initialization/rendering.
   function Last_Error
     (Item : Runtime)
      return I18N.Errors.Error_Kind;

end I18N.Runtime.Compatibility;
