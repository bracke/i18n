package body Example_Trace_Callbacks is
   procedure Raising_Callback
     (Event : I18N.Diagnostics.Trace_Event_Kind;
      Key   : String)
   is
      pragma Unreferenced (Event, Key);
   begin
      raise Program_Error;
   end Raising_Callback;
end Example_Trace_Callbacks;
