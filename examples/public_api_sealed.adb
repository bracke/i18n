with Ada.Text_IO;
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Result;
with I18N.Runtime;

procedure Public_API_Sealed is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
   Locale  : constant I18N.Locales.Locale_Id := "en-US";
begin
   I18N.Diagnostics.Set_Trace_Callback (null);
   I18N.Arguments.Set (Args, "name", "Ada");
   I18N.Runtime.Initialize (Runtime, "examples/catalogs/messages.catalog");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, Locale, "hello", Args);
   begin
      case Result.Status is
         when I18N.Result.Success |
              I18N.Result.Missing_Key |
              I18N.Result.Missing_Argument |
              I18N.Result.Invalid_Argument |
              I18N.Result.Formatting_Error |
              I18N.Result.Execution_Error |
              I18N.Result.Buffer_Overflow |
              I18N.Result.Internal_Error =>
            null;
      end case;

      Ada.Text_IO.Put_Line
        ("public API sealed smoke: "
         & I18N.Result.Render_Status'Image (Result.Status));
   end;

   I18N.Runtime.Finalize (Runtime);
end Public_API_Sealed;
