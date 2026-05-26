with Ada.Text_IO;
with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Status_Handling is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;

   procedure Explain
     (Label  : String;
      Result : I18N.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put (Label & ": ");
      case Result.Status is
         when I18N.Result.Success =>
            Put_Line ("success => " & I18N.Result.Output_Text (Result.Text));
         when I18N.Result.Missing_Key =>
            Put_Line ("message key not found after locale fallback");
         when I18N.Result.Missing_Argument =>
            Put_Line ("required render argument was not supplied");
         when I18N.Result.Invalid_Argument =>
            Put_Line ("argument text could not be interpreted for branch selection");
         when I18N.Result.Formatting_Error =>
            Put_Line ("validated message could not be formatted");
         when I18N.Result.Execution_Error =>
            Put_Line ("runtime or catalog is invalid");
         when I18N.Result.Buffer_Overflow =>
            Put_Line ("internal fixed render buffer was too small");
         when I18N.Result.Internal_Error =>
            Put_Line ("unexpected internal failure was contained");
      end case;
   end Explain;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "name", "Ada");
   Explain
     ("success status",
      I18N.Runtime.Render (Runtime, "en", "hello", Args));

   I18N.Arguments.Clear (Args);
   Explain
     ("missing argument status",
      I18N.Runtime.Render (Runtime, "en", "hello", Args));

   Explain
     ("missing key status",
      I18N.Runtime.Render (Runtime, "en", "no.such.key", Args));
end Status_Handling;
