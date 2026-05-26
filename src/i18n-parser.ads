with I18N.AST;

private package I18N.Parser is

   --  Raised internally when the strict grammar is violated.
   Parse_Error : exception;

   --  Parse a message source into a linked-list AST.
   --
   --  Valid variables have the form {identifier}. Valid plurals have the form
   --  {identifier, plural, one {message} other {message}}. Valid selects have
   --  the form {identifier, select, male {message} female {message}
   --  other {message}}. Valid selectordinals have the form
   --  {identifier, selectordinal, one {message} two {message} few {message}
   --  other {message}}. Branch messages may contain nested variables, plural
   --  blocks, select blocks, and selectordinal blocks. Invalid braces, empty
   --  variables, malformed blocks, duplicate branches, and unknown branch names
   --  raise Parse_Error. Mandatory branch completeness is enforced by
   --  I18N.Validation so runtime callers receive Missing_Branch where
   --  appropriate. Explicit empty branch blocks, such as male {}, are preserved
   --  as empty branch ASTs rather than treated as absent branches.
   --
   --  @param Source Message source to parse.
   --  @return Root node of the parsed AST, or null for the empty source.
   function Parse
     (Source : String)
      return I18N.AST.Node_Access;

end I18N.Parser;
