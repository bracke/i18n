with I18N.Observability;

package body I18N.Diagnostics.Callbacks is
   pragma SPARK_Mode (Off);

   protected Callback_State is
      procedure Set
        (CB : Trace_Callback);

      function Get
         return Trace_Callback;
   private
      Current_CB : Trace_Callback := null;
   end Callback_State;

   protected body Callback_State is
      procedure Set
        (CB : Trace_Callback)
      is
      begin
         Current_CB := CB;
      end Set;

      function Get
         return Trace_Callback
      is
      begin
         return Current_CB;
      end Get;
   end Callback_State;

   function To_Public
     (Event : I18N.Observability.Trace_Event_Kind)
      return Trace_Event_Kind
   is
   begin
      case Event is
         when I18N.Observability.Message_Start => return Message_Start;
         when I18N.Observability.Op_Text       => return Op_Text;
         when I18N.Observability.Op_Variable   => return Op_Variable;
         when I18N.Observability.Op_Plural     => return Op_Plural;
         when I18N.Observability.Op_Select     => return Op_Select;
         when I18N.Observability.Op_Ordinal    => return Op_Ordinal;
         when I18N.Observability.Message_End   => return Message_End;
      end case;
   end To_Public;

   procedure Public_Trace_Trampoline
     (Event : I18N.Observability.Trace_Event_Kind;
      Key   : String)
   is
      CB : constant Trace_Callback := Callback_State.Get;
   begin
      if CB /= null then
         CB.all (To_Public (Event), Key);
      end if;
   exception
      when others =>
         null;
   end Public_Trace_Trampoline;

   procedure Set
     (CB : Trace_Callback)
   is
   begin
      Callback_State.Set (CB);
      if CB = null then
         I18N.Observability.Set_Trace_Callback (null);
      else
         I18N.Observability.Set_Trace_Callback (Public_Trace_Trampoline'Access);
      end if;
   end Set;

end I18N.Diagnostics.Callbacks;
