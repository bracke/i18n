with Ada.Text_IO;
with Example_Support;
with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Result;
with I18N.Runtime;

procedure Diagnostics_Inspection is
   Runtime : I18N.Runtime.Instance;
   Args    : I18N.Arguments.Arguments;
begin
   I18N.Runtime.Initialize (Runtime, Example_Support.Catalog_Path);

   --  Intentionally omit the required "name" argument so the example shows
   --  diagnostics attached to an error result.
   declare
      Result : constant I18N.Result.Render_Result :=
        I18N.Runtime.Render (Runtime, "en", "hello", Args);
   begin
      Example_Support.Print_Status ("render status", Result);

      Ada.Text_IO.Put_Line
        ("has missing-variable diagnostic: "
         & Boolean'Image
             (I18N.Diagnostics.Has_Kind
                (Result.Diagnostics,
                 I18N.Diagnostics.Missing_Variable)));

      Ada.Text_IO.Put_Line
        ("diagnostic count:" & Natural'Image (I18N.Diagnostics.Length (Result.Diagnostics)));

      for Index in 1 .. I18N.Diagnostics.Length (Result.Diagnostics) loop
         declare
            Item : constant I18N.Diagnostics.Diagnostic :=
              I18N.Diagnostics.Element (Result.Diagnostics, Index);
         begin
            Ada.Text_IO.Put_Line
              ("diagnostic"
               & Positive'Image (Index)
               & ": "
               & I18N.Diagnostics.Diagnostic_Kind'Image (Item.Kind)
               & " key="
               & I18N.Diagnostics.Key_Text (Item)
               & " message="
               & I18N.Diagnostics.Message_Text (Item));
         end;
      end loop;
   end;
end Diagnostics_Inspection;
