with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Invalid_Argument is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "count", "not-a-number");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Status ("invalid numeric argument", Result);
   end;
end Invalid_Argument;
