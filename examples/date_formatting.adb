with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Date_Formatting is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "day", "2024-02-29");

   declare
      En_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "date.long", Args);
      De_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de", "date.full", Args);
      Skeleton_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "date.skeleton", Args);
      Numeric_Skeleton_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Runtime, "en", "date.numeric_skeleton", Args);
      Japanese_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Runtime, "ja-u-ca-japanese", "date.japanese", Args);
      Buddhist_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Runtime, "th-u-ca-buddhist", "date.buddhist", Args);
   begin
      Example_Support.Print_Result ("date en", En_Result);
      Example_Support.Print_Result ("date de", De_Result);
      Example_Support.Print_Result ("date skeleton", Skeleton_Result);
      Example_Support.Print_Result
        ("date numeric skeleton", Numeric_Skeleton_Result);
      Example_Support.Print_Result ("date japanese calendar", Japanese_Result);
      Example_Support.Print_Result ("date buddhist calendar", Buddhist_Result);
   end;

   I18N.Arguments.Set (Args, "day", "2016-01-01");

   declare
      Week_Year_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "date.week_year", Args);
   begin
      Example_Support.Print_Result ("date locale week", Week_Year_Result);
   end;

   I18N.Arguments.Set (Args, "day", "2024-03-20");

   declare
      Persian_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render
          (Runtime, "en-u-ca-persian", "date.persian", Args);
   begin
      Example_Support.Print_Result ("date persian calendar", Persian_Result);
   end;
end Date_Formatting;
