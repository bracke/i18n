with Ada.Text_IO;
with Example_Support;
with Example_Trace_Callbacks;
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Result;
with I18N.Runtime;

procedure Diagnostics_Non_Interference is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);
   I18N.Arguments.Set (Args, "name", "Ada");

   I18N.Diagnostics.Set_Trace_Callback (Example_Trace_Callbacks.Raising_Callback'Access);

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Result ("trace callback cannot affect render", Result);
      Ada.Text_IO.Put_Line
        ("diagnostic count:" & Natural'Image (I18N.Diagnostics.Length (Result.Diagnostics)));
   end;

   I18N.Diagnostics.Set_Trace_Callback (null);
end Diagnostics_Non_Interference;
