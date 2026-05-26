with I18N.AST;
with I18N.Errors;
with I18N.Arguments;

private package I18N.Render is

   --  Safely render a validated AST into a structured Result.
   --
   --  Missing variables fail with Missing_Variable. Plural selectors must be
   --  present and numeric. Select selectors are strings. Selectordinal selectors
   --  must be present and numeric. Rendering catches failures and reports them
   --  through Result rather than propagating runtime exceptions.
   --
   --  @param Root First AST node to render. Null renders as the empty string.
   --  @param Args Variable argument map.
   --  @return Structured render result.
   function Render
     (Root : I18N.AST.Node_Access;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result;

end I18N.Render;
