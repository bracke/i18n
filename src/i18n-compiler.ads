with I18N.AST;
with I18N.Compiled;

private package I18N.Compiler is

   --  Compile a validated AST into the immutable flattened IR.
   --
   --  Scope and semantics (regression-only legacy path):
   --  This compiler and its companion I18N.Fast_Render are an internal pipeline
   --  exercised only through I18N.Runtime.Compatibility and the in-tree
   --  regression suites. They are NOT the stable public render path. Compared
   --  with the authoritative public I18N.Runtime path they are intentionally
   --  legacy:
   --    * select dispatch uses generalized named branches;
   --    * plural/selectordinal category selection is locale-agnostic (one iff
   --      n = 1; ordinal by the literal 1/2/3 mapping), not the locale-aware
   --      I18N.Plurals rules used by the public path.
   --  Both paths do share the "only other is mandatory; absent category branches
   --  fall back to other" branch policy.
   --
   --  The compiler defensively re-runs validation before emitting IR.
   --  Invalid input raises Constraint_Error so normal runtime construction can
   --  continue to report deterministic validation errors before compilation.
   --
   --  @param N Root AST node to compile. Null compiles to an empty message.
   --  @return Immutable, limited compiled message handle.
   function Compile
     (N : I18N.AST.Node_Access)
      return I18N.Compiled.Compiled_Message;

end I18N.Compiler;
