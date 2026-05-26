with I18N.AST;
with I18N.Compiled;

private package I18N.Compiler is

   --  Compile a validated AST into the immutable flattened IR.
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
