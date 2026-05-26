with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Missing_Argument is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("missing argument", Result);
   end;
end Missing_Argument;
