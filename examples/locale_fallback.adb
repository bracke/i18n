with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Locale_Fallback is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "name", "Ada");
   I18N.Arguments.Set (Args, "count", "3");

   declare
      Exact_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de-AT", "hello", Args);
      Parent_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de-AT", "cart.items", Args);
      Default_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "fr-CA", "fallback.only", Args);
   begin
      Example_Support.Print_Result ("exact de-AT", Exact_Result);
      Example_Support.Print_Result ("parent de", Parent_Result);
      Example_Support.Print_Result ("default en", Default_Result);
   end;
end Locale_Fallback;
