with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Plural_Render is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "count", "1");
   declare
      One_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Result ("plural one", One_Result);
   end;

   I18N.Arguments.Set (Args, "count", "5");
   declare
      Other_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "cart.items", Args);
   begin
      Example_Support.Print_Result ("plural other", Other_Result);
   end;
end Plural_Render;
