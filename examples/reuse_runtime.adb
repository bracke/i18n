with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Reuse_Runtime is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "name", "Ada");
   declare
      First : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Result ("first render", First);
   end;

   I18N.Arguments.Clear (Args);
   I18N.Arguments.Set (Args, "count", "7");
   declare
      Second : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de", "cart.items", Args);
   begin
      Example_Support.Print_Result ("second render", Second);
   end;
end Reuse_Runtime;
