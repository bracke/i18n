with Ada.Text_IO;
with I18N.Arguments;
with I18N.Result; use I18N.Result;
with I18N.Runtime;

procedure Public_API_Example is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, "examples/catalogs/messages.catalog");
   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => "de-AT",
           Key       => "hello",
           Arguments => Args);
   begin
      if Result.Status = I18N.Result.Success then
         Ada.Text_IO.Put_Line
           ("public API render: "
            & I18N.Result.Output_Text (Result.Text));
      else
         Ada.Text_IO.Put_Line
           ("public API render status: "
            & I18N.Result.Render_Status'Image (Result.Status));
      end if;
   end;
end Public_API_Example;
