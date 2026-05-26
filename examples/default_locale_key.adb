with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Default_Locale_Key is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "name", "Ada");

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "fr-CA", "plain.default", Args);
   begin
      Example_Support.Print_Result ("unqualified catalog key uses default locale", Result);
   end;
end Default_Locale_Key;
