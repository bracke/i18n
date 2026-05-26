with Ada.Text_IO;
with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Empty_Message is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "empty.message", Args);
   begin
      Example_Support.Print_Status ("empty message status", Result);
      Ada.Text_IO.Put_Line ("empty message length:" & Natural'Image (Result.Text.Length));
   end;
end Empty_Message;
