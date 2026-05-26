with Ada.Text_IO;
with Example_Support;
with I18N.Arguments;
with I18N.Result;
with I18N.Runtime;

procedure Invalid_Catalog is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize
     (Runtime, "examples/catalogs/invalid_duplicate.catalog");

   Ada.Text_IO.Put_Line
     ("duplicate catalog valid: " & Boolean'Image (I18N.Runtime.Is_Valid (Runtime)));

   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("render after invalid catalog", Result);
   end;

   I18N.Runtime.Initialize
     (Runtime, "examples/catalogs/invalid_syntax.catalog");

   Ada.Text_IO.Put_Line
     ("syntax catalog valid: " & Boolean'Image (I18N.Runtime.Is_Valid (Runtime)));
end Invalid_Catalog;
