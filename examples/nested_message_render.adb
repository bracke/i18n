with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Nested_Message_Render is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "gender", "female");
   I18N.Arguments.Set (Args, "name", "Grace");
   I18N.Arguments.Set (Args, "count", "2");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "upload.summary", Args);
   begin
      Example_Support.Print_Result ("nested select/plural", Result);
   end;
end Nested_Message_Render;
