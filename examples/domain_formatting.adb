with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Domain_Formatting is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   I18N.Arguments.Set (Args, "seconds", "3661");
   I18N.Arguments.Set (Args, "size", "1649267441664");
   I18N.Arguments.Set (Args, "distance", "1.5");
   I18N.Arguments.Set (Args, "offset", "-3");
   I18N.Arguments.Set (Args, "items", "red|green|blue");

   declare
      Duration : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.duration", Args);
      Bytes : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.bytes", Args);
      Unit : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.unit", Args);
      Rate : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.rate", Args);
      Short_Rate : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.short_rate", Args);
      Relative : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.relative", Args);
      Relative_De : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de", "domain.relative", Args);
      List : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "domain.list", Args);
      List_De : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de", "domain.list", Args);
   begin
      Example_Support.Print_Result ("domain duration", Duration);
      Example_Support.Print_Result ("domain bytes", Bytes);
      Example_Support.Print_Result ("domain unit", Unit);
      Example_Support.Print_Result ("domain rate", Rate);
      Example_Support.Print_Result ("domain short rate", Short_Rate);
      Example_Support.Print_Result ("domain relative", Relative);
      Example_Support.Print_Result ("domain relative de", Relative_De);
      Example_Support.Print_Result ("domain list", List);
      Example_Support.Print_Result ("domain list de", List_De);
   end;
end Domain_Formatting;
