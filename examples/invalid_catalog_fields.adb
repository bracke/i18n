with Ada.Text_IO;
with I18N.Runtime;

procedure Invalid_Catalog_Fields is
   Runtime : I18N.Runtime.Instance;

   procedure Check
     (Label : String;
      Path  : String)
   is
   begin
      I18N.Runtime.Initialize (Runtime, Path);
      Ada.Text_IO.Put_Line
        (Label & " valid: " & Boolean'Image (I18N.Runtime.Is_Valid (Runtime)));
      I18N.Runtime.Finalize (Runtime);
   end Check;
begin
   Check ("empty locale", "examples/catalogs/invalid_empty_locale.catalog");
   Check ("empty key", "examples/catalogs/invalid_empty_key.catalog");
   Check ("empty default locale", "examples/catalogs/invalid_empty_default_locale.catalog");
end Invalid_Catalog_Fields;
