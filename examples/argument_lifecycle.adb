with Ada.Text_IO;
with I18N.Arguments;

procedure Argument_Lifecycle is
   Args : I18N.Arguments.Arguments;
begin
   I18N.Arguments.Set (Args, "name", "Ada");
   Ada.Text_IO.Put_Line
     ("has name after set: " & Boolean'Image (I18N.Arguments.Has (Args, "name")));
   Ada.Text_IO.Put_Line
     ("name value: " & I18N.Arguments.Get (Args, "name"));

   I18N.Arguments.Clear (Args);
   Ada.Text_IO.Put_Line
     ("has name after clear: " & Boolean'Image (I18N.Arguments.Has (Args, "name")));
end Argument_Lifecycle;
