package body I18N.Result is
   pragma SPARK_Mode (On);

   function To_Output_View
     (Text : String)
      return Output_View
   is
      View  : Output_View;
      Count : constant Natural := Natural'Min (Text'Length, Max_Output_Length);
   begin
      if Count > 0 then
         declare
            Target_Index : Positive := 1;
         begin
            for Source_Index in Text'Range loop
               exit when Target_Index > Count;
               View.Text (Target_Index) := Text (Source_Index);
               if Target_Index < Count then
                  Target_Index := Target_Index + 1;
               else
                  exit;
               end if;
            end loop;
         end;
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
         Text        => (Text => [others => Character'Val (0)], Length => 0),
         Diagnostics => Empty);
   end Failure;

end I18N.Result;
