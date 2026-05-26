package body I18N.Errors is

   function Success_Status
      return Status
   is
   begin
      return (Ok => True, Error => Parse_Error);
   end Success_Status;

   function Failure_Status
     (Kind : Error_Kind)
      return Status
   is
   begin
      return (Ok => False, Error => Kind);
   end Failure_Status;

   function Success
     (Value : String)
      return Result
   is
      Empty : I18N.Diagnostics.Diagnostic_List;
   begin
      return
        (Ok          => True,
         Value       => Ada.Strings.Unbounded.To_Unbounded_String (Value),
         Error       => Parse_Error,
         Diagnostics => Empty);
   end Success;

   function Value_Text
     (Item : Result)
      return String
   is
   begin
      return Ada.Strings.Unbounded.To_String (Item.Value);
   end Value_Text;

   function Diagnostic_Message
     (Error : Error_Kind)
      return String
   is
   begin
      case Error is
         when Parse_Error =>
            return "parse error";
         when Validation_Error =>
            return "validation error";
         when Missing_Branch =>
            return "missing required branch";
         when Missing_Variable =>
            return "missing variable";
         when Invalid_Selector =>
            return "invalid selector";
         when Invalid_Ordinal =>
            return "invalid ordinal";
         when Buffer_Overflow =>
            return "output buffer overflow";
         when Unbalanced_Braces =>
            return "unbalanced braces";
      end case;
   end Diagnostic_Message;

   function To_Diagnostic_Kind
     (Error : Error_Kind)
      return I18N.Diagnostics.Diagnostic_Kind
   is
   begin
      case Error is
         when Parse_Error | Unbalanced_Braces =>
            return I18N.Diagnostics.Parse_Error;
         when Validation_Error =>
            return I18N.Diagnostics.Validation_Error;
         when Missing_Branch =>
            return I18N.Diagnostics.Missing_Branch;
         when Missing_Variable =>
            return I18N.Diagnostics.Missing_Variable;
         when Invalid_Selector =>
            return I18N.Diagnostics.Invalid_Selector;
         when Invalid_Ordinal =>
            return I18N.Diagnostics.Invalid_Ordinal;
         when Buffer_Overflow =>
            return I18N.Diagnostics.Overflow_Warning;
      end case;
   end To_Diagnostic_Kind;

   function Failure
     (Error : Error_Kind)
      return Result
   is
   begin
      return Failure (Error => Error, Key => "");
   end Failure;

   function Failure
     (Error : Error_Kind;
      Key   : String)
      return Result
   is
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   begin
      I18N.Diagnostics.Add
        (List    => Diagnostics,
         Kind    => To_Diagnostic_Kind (Error),
         Message => Diagnostic_Message (Error),
         Key     => Key);

      return
        (Ok          => False,
         Value       => Ada.Strings.Unbounded.Null_Unbounded_String,
         Error       => Error,
         Diagnostics => Diagnostics);
   end Failure;

end I18N.Errors;
