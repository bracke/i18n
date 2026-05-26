with Ada.Text_IO;

package body Example_Support is

   use I18N.Result;
   procedure Print_Result
     (Label  : String;
      Result : I18N.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put (Label & ": ");
      if Result.Status = I18N.Result.Success then
         Put_Line (I18N.Result.Output_Text (Result.Text));
      else
         Put_Line (I18N.Result.Render_Status'Image (Result.Status));
      end if;
   end Print_Result;

   procedure Print_Status
     (Label  : String;
      Result : I18N.Result.Render_Result)
   is
      use Ada.Text_IO;
   begin
      Put_Line
        (Label & ": " & I18N.Result.Render_Status'Image (Result.Status));
   end Print_Status;

end Example_Support;
