with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Missing_Key is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "does.not.exist", Args);
   begin
      Example_Support.Print_Status ("missing key", Result);
   end;
end Missing_Key;
