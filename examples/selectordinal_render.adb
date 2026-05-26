with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Selectordinal_Render is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "rank", "1");
   declare
      First_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "rank.label", Args);
   begin
      Example_Support.Print_Result ("ordinal one", First_Result);
   end;

   I18N.Arguments.Set (Args, "rank", "4");
   declare
      Other_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "rank.label", Args);
   begin
      Example_Support.Print_Result ("ordinal other", Other_Result);
   end;
end Selectordinal_Render;
