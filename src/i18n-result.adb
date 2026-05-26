package body I18N.Result is

   function To_Output_View
     (Text : String)
      return Output_View
   is
      View  : Output_View;
      Count : constant Natural := Natural'Min (Text'Length, Max_Output_Length);
   begin
      if Count > 0 then
         View.Text (1 .. Count) := Text (Text'First .. Text'First + Count - 1);
      end if;
      View.Length := Count;
      return View;
   end To_Output_View;

   function Output_Text
     (View : Output_View)
      return String
   is
   begin
      if View.Length = 0 then
         return "";
      end if;
      return View.Text (1 .. View.Length);
   end Output_Text;

   function Failure
     (Status : Render_Status)
      return Render_Result
   is
      Empty : I18N.Diagnostics.Diagnostic_List;
   begin
      return
        (Status      => Status,
         Text        => To_Output_View (""),
         Diagnostics => Empty);
   end Failure;

end I18N.Result;
