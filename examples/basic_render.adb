with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Basic_Render is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Item      => Runtime,
           Locale    => "en",
           Key       => "hello",
           Arguments => Args);
   begin
      Example_Support.Print_Result ("basic", Result);
   end;
end Basic_Render;
