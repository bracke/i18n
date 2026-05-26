with I18N.AST;
with I18N.Errors;

private package I18N.Validation is

   --  Validate a parsed AST before evaluation.
   --
   --  This pass enforces structural integrity: valid identifiers,
   --  mandatory branches, non-null required branch roots, and recursive branch
   --  consistency. It does not inspect runtime argument values.
   --
   --  @param N Root node to validate. Null is valid and represents an empty message.
   --  @return Ok=True when the AST is complete; otherwise Error identifies the issue.
   function Validate
     (N : I18N.AST.Node_Access)
      return I18N.Errors.Result;

end I18N.Validation;
