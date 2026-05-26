with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Select_Render is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "animal", "male");
   declare
      Cat_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "pet.label", Args);
   begin
      Example_Support.Print_Result ("select male", Cat_Result);
   end;

   I18N.Arguments.Set (Args, "animal", "unknown");
   declare
      Other_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "pet.label", Args);
   begin
      Example_Support.Print_Result ("select fallback branch", Other_Result);
   end;
end Select_Render;
