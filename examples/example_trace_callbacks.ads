with I18N.Diagnostics;

package Example_Trace_Callbacks is
   --  Trace callback used by examples to demonstrate callback isolation.
   --
   --  @param Event Trace event kind emitted by the runtime.
   --  @param Key Message or operation key associated with the event.
   procedure Raising_Callback
     (Event : I18N.Diagnostics.Trace_Event_Kind;
      Key   : String);
end Example_Trace_Callbacks;
