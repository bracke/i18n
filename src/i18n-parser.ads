with I18N.AST;

private package I18N.Parser is

   --  Raised internally when the strict grammar is violated.
   Parse_Error : exception;

   --  Parse a message source into a linked-list AST.
   --
   --  Valid variables have the form {identifier}. Plurals have the form
   --  {identifier, plural, one {message} other {message}} where the parser
   --  accepts the one and other branch names. Selects have the form
   --  {identifier, select, name {message} ... other {message}} with arbitrary
   --  validated identifier branch names. Selectordinals have the form
   --  {identifier, selectordinal, one {message} two {message} few {message}
   --  other {message}} where the parser accepts the one, two, few, and other
   --  branch names. Branch messages may contain nested variables, plural
   --  blocks, select blocks, and selectordinal blocks. Invalid braces, empty
   --  variables, malformed blocks, duplicate branches, and unaccepted branch
   --  names raise Parse_Error. Only the other branch is mandatory; completeness
   --  is enforced by I18N.Validation, which returns Missing_Branch when other is
   --  absent (other categories fall back to other at render time). Explicit
   --  empty branch blocks, such as full {}, are preserved as empty branch ASTs
   --  rather than treated as absent branches.
   --
   --  @param Source Message source to parse.
   --  @return Root node of the parsed AST, or null for the empty source.
   function Parse
     (Source : String)
      return I18N.AST.Node_Access;

end I18N.Parser;
