with I18N.Result;

package Example_Support is
   Catalog_Path : constant String := "examples/catalogs/messages.catalog";

   --  Print a render result in the shared example output format.
   --
   --  @param Label Human-readable label printed before the result.
   --  @param Result Public render result to display.
   procedure Print_Result
     (Label  : String;
      Result : I18N.Result.Render_Result);

   --  Print only the status portion of a render result.
   --
   --  @param Label Human-readable label printed before the status.
   --  @param Result Public render result whose status is displayed.
   procedure Print_Status
     (Label  : String;
      Result : I18N.Result.Render_Result);
end Example_Support;
