with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Currency_Formatting is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "amount", "1234.5");

   declare
      En_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.total", Args);
      De_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "de", "currency.total", Args);
      Name_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.name", Args);
      Narrow_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.narrow", Args);
      ISO_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.iso", Args);
   begin
      Example_Support.Print_Result ("currency en", En_Result);
      Example_Support.Print_Result ("currency de", De_Result);
      Example_Support.Print_Result ("currency name", Name_Result);
      Example_Support.Print_Result ("currency narrow", Narrow_Result);
      Example_Support.Print_Result ("currency iso", ISO_Result);
   end;

   I18N.Arguments.Set (Args, "amount", "1.03");

   declare
      Cash_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.cash", Args);
   begin
      Example_Support.Print_Result ("currency cash", Cash_Result);
   end;

   I18N.Arguments.Set (Args, "amount", "-1234.5");

   declare
      Accounting_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.accounting", Args);
   begin
      Example_Support.Print_Result ("currency accounting", Accounting_Result);
   end;

   I18N.Arguments.Set (Args, "amount", "1234");

   declare
      Yen_Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "currency.yen", Args);
   begin
      Example_Support.Print_Result ("currency yen", Yen_Result);
   end;
end Currency_Formatting;
