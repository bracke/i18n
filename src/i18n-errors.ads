with Ada.Strings.Unbounded;

with I18N.Diagnostics;

private package I18N.Errors is
   --  Deterministic deterministic error kind returned by strict parsing,
   --  validation, and safe rendering.
   type Error_Kind is
     (Parse_Error,
      Validation_Error,
      Missing_Branch,
      Missing_Variable,
      Invalid_Selector,
      Invalid_Ordinal,
      Buffer_Overflow,
      Unbalanced_Braces);

   --  Allocation-free render status. Used by strict fixed-buffer render paths
   --  that write only into caller-owned buffers.
   type Status is record
      Ok    : Boolean := False;
      Error : Error_Kind := Parse_Error;
   end record;

   --  Explicit render result.
   --
   --  Successful results have Ok = True and Value contains the rendered text.
   --  Failed results have Ok = False, Value is empty, and Error identifies the
   --  deterministic failure class. The Error field is intentionally still
   --  present on successful results so callers can use one uniform record type.
   --
   --  The value uses Unbounded_String instead of a discriminated String field so
   --  declaring a default Result object cannot raise Storage_Error and callers do
   --  not accidentally attempt to mutate discriminants through assignment.
   type Result is record
      Ok          : Boolean := False;
      Value       : Ada.Strings.Unbounded.Unbounded_String;
      Error       : Error_Kind := Parse_Error;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   end record;

   --  Return the rendered value as a String.
   --
   --  @param Item Result to inspect.
   --  @return Rendered value text, or empty string for failed results.
   function Value_Text
     (Item : Result)
      return String;

   --  Build a successful allocation-free status.
   --
   --  @return Successful status.
   function Success_Status
      return Status;

   --  Build a failed allocation-free status.
   --
   --  @param Kind Deterministic failure kind.
   --  @return Failed status.
   function Failure_Status
     (Kind : Error_Kind)
      return Status;

   --  Build a successful Result.
   --
   --  @param Value Rendered message text.
   --  @return Successful Result containing Value.
   function Success
     (Value : String)
      return Result;

   --  Build a failed Result.
   --
   --  @param Error Deterministic failure kind.
   --  @return Failed Result with an empty value.
   function Failure
     (Error : Error_Kind)
      return Result;

   --  Build a failed Result with a specific diagnostic key.
   --
   --  @param Error Deterministic failure kind.
   --  @param Key ICU variable or selector key associated with the failure.
   --  @return Failed Result with one structured diagnostic.
   function Failure
     (Error : Error_Kind;
      Key   : String)
      return Result;

   --  Convert a internal error kind to its diagnostic kind.
   --
   --  @param Error Deterministic failure kind.
   --  @return Matching diagnostic kind.
   function To_Diagnostic_Kind
     (Error : Error_Kind)
      return I18N.Diagnostics.Diagnostic_Kind;

end I18N.Errors;
