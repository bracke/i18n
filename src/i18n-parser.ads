with I18N.AST;

private package I18N.Parser is

   --  Raised internally when the strict grammar is violated.
   Parse_Error : exception;

   --  Raised for deterministic unmatched brace/formatted-quote conditions.
   Unbalanced_Braces : exception;

   --  Parse a message source into a linked-list AST.
   --
   --  Valid variables have the form {identifier}. Plurals have the form
   --  {identifier, plural, offset:N zero {message} one {message}
   --  two {message} few {message} many {message} other {message}} where
   --  offset:N is optional and must appear before branches; the parser accepts
   --  zero, one, two, few, many, and other branch names. Selects have the form
   --  {identifier, select, name {message} ... other {message}} with arbitrary
   --  validated identifier branch names. Selectordinals have the form
   --  {identifier, selectordinal, zero {message} one {message} two {message}
   --  few {message} many {message} other {message}} where the parser accepts
   --  all CLDR category branch names. Branch messages may contain nested variables, plural
   --  blocks, select blocks, selectordinal blocks, number/date/time formats of
   --  the form {identifier, number}, {identifier, number, ::percent},
   --  {identifier, number, ::compact-short}, {identifier, number, ::currency/USD},
   --  {identifier, date, short}, {identifier, date, ::yMMMd},
   --  {identifier, time, long}, {identifier, time, ::hhmmssa}, or
   --  {identifier, datetime, ::GyyyyQQQDDDwWFEBhmsSAZ, UTC}, and currency
   --  formats of the form {identifier, currency, USD/accounting}. ICU-style apostrophe escaping is resolved
   --  while parsing: doubled apostrophes render as one apostrophe, quoted
   --  syntax characters render literally, quoted # does not trigger
   --  plural/selectordinal number substitution, and an unterminated quoted
   --  span closes at the current message or branch boundary. Invalid braces, empty
   --  variables, malformed
   --  blocks, duplicate branches, and unaccepted branch names raise
   --  Parse_Error. Only the other branch is mandatory; completeness is enforced
   --  by I18N.Validation, which returns Missing_Branch when other is absent
   --  (other categories fall back to other at render time). Explicit
   --  empty branch blocks, such as full {}, are preserved as empty branch ASTs
   --  rather than treated as absent branches.
   --
   --  @param Source Message source to parse.
   --  @return Root node of the parsed AST, or null for the empty source.
   function Parse
     (Source : String)
      return I18N.AST.Node_Access;

end I18N.Parser;
