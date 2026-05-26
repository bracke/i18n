with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Fallback_Chain is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "name", "Ada");
   I18N.Arguments.Set (Args, "count", "3");

   declare
      Region_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de-AT", "hello", Args);
      Parent_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de-AT", "cart.items", Args);
      Default_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de-AT", "fallback.only", Args);
   begin
      Example_Support.Print_Result ("fallback de-AT exact", Region_Result);
      Example_Support.Print_Result ("fallback de parent", Parent_Result);
      Example_Support.Print_Result ("fallback default en", Default_Result);
   end;
end Fallback_Chain;
