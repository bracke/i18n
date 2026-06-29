with I18N.Buffer;
with I18N.Compiled;
with I18N.Diagnostics;
with I18N.Errors;
with I18N.Observability;
with I18N.Arguments;

private package I18N.Fast_Render is

   --  Regression-only legacy renderer. This executes the compiled IR for the
   --  in-tree compatibility/differential tests. It is locale-agnostic and
   --  supports only male/female/other select branches and a hardcoded
   --  plural/ordinal category mapping (one iff n = 1; ordinal by 1/2/3). The
   --  stable public render path is I18N.Runtime (generalized select plus
   --  locale-aware I18N.Plurals selection). Both share the "only other is
   --  mandatory; absent category branches fall back to other" policy.

   --  Render a compiled message into caller-owned fixed output storage and
   --  return only status metadata. This is the strict no-result-
   --  materialization path.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg    : I18N.Compiled.Compiled_Message;
      Buffer : in out I18N.Buffer.Buffer;
      Args   : I18N.Arguments.Arguments)
      return I18N.Errors.Status;

   --  Render into caller-owned storage while collecting bounded structured
   --  diagnostics. Diagnostics storage is caller-owned and preallocated.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @param Diagnostics Caller-owned preallocated diagnostic list.
   --  @param Metadata Caller-owned execution metadata used for start-event trace context.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg         : I18N.Compiled.Compiled_Message;
      Buffer      : in out I18N.Buffer.Buffer;
      Args        : I18N.Arguments.Arguments;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Metadata    : I18N.Observability.Execution_Metadata)
      return I18N.Errors.Status;

   --  Convenience overload for callers that do not provide execution metadata.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @param Diagnostics Caller-owned preallocated diagnostic list.
   --  @return Allocation-free render status.
   function Render_Into
     (Msg         : I18N.Compiled.Compiled_Message;
      Buffer      : in out I18N.Buffer.Buffer;
      Args        : I18N.Arguments.Arguments;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List)
      return I18N.Errors.Status;

   --  Render a compiled message using caller-owned fixed output storage.
   --
   --  Evaluation is a linear program-counter loop over precompiled operations.
   --  Branch operations jump directly to precomputed target indexes and never
   --  traverse AST nodes. The render loop writes only to Buffer and stack-local
   --  state.
   --
   --  @param Msg Compiled message to render.
   --  @param Buffer Fixed output buffer owned by the caller's thread/context.
   --  @param Args Runtime argument map.
   --  @return Structured render result.
   function Render
     (Msg    : I18N.Compiled.Compiled_Message;
      Buffer : in out I18N.Buffer.Buffer;
      Args   : I18N.Arguments.Arguments)
      return I18N.Errors.Result;

   --  Compatibility wrapper for callers that do not manage buffers directly.
   --  The wrapper creates a stack-local fixed buffer.
   --
   --  @param Msg Compiled message to render.
   --  @param Args Runtime argument map.
   --  @return Structured render result.
   function Render
     (Msg  : I18N.Compiled.Compiled_Message;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result;

end I18N.Fast_Render;
