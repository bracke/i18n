with I18N.Observability;

package body I18N.Diagnostics is

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

   procedure Set_Trace_Callback
     (CB : Trace_Callback)
   is
   begin
      Callback_State.Set (CB);
      if CB = null then
         I18N.Observability.Set_Trace_Callback (null);
      else
         I18N.Observability.Set_Trace_Callback (Public_Trace_Trampoline'Access);
      end if;
   end Set_Trace_Callback;

   procedure Copy_Text
     (Source : String;
      Target : out String;
      Last   : out Natural)
   is
      Copy_Last : Natural := 0;
   begin
      Target := [others => Character'Val (0)];
      if Source'Length > 0 then
         Copy_Last := Natural'Min (Source'Length, Target'Length);
         Target (Target'First .. Target'First + Copy_Last - 1) :=
           Source (Source'First .. Source'First + Copy_Last - 1);
      end if;
      Last := Copy_Last;
   end Copy_Text;

   procedure Clear
     (List : in out Diagnostic_List)
   is
   begin
      List.Count := 0;
   end Clear;

   procedure Add
     (List    : in out Diagnostic_List;
      Kind    : Diagnostic_Kind;
      Message : String := "";
      Key     : String := "")
   is
      Slot             : Positive;
      Effective_Kind   : Diagnostic_Kind := Kind;
      Effective_Message : String (1 .. Message_Capacity) :=
        [others => Character'Val (0)];
      Effective_Last   : Natural := 0;
      Effective_Key    : String (1 .. Key_Capacity) :=
        (others => Character'Val (0));
      Effective_Key_Last : Natural := 0;
   begin
      if List.Count >= Max_Diagnostics then
         --  Preserve bounded storage while still surfacing the fact that
         --  diagnostics were truncated. The last slot is reserved/reused as a
         --  deterministic overflow warning rather than growing the list.
         Slot := Max_Diagnostics;
         Effective_Kind := Overflow_Warning;
         Copy_Text
           (Source => "diagnostic list capacity exceeded",
            Target => Effective_Message,
            Last   => Effective_Last);
         Copy_Text
           (Source => "diagnostics",
            Target => Effective_Key,
            Last   => Effective_Key_Last);
      else
         List.Count := List.Count + 1;
         Slot := List.Count;
         Copy_Text
           (Source => Message,
            Target => Effective_Message,
            Last   => Effective_Last);
         Copy_Text
           (Source => Key,
            Target => Effective_Key,
            Last   => Effective_Key_Last);
      end if;

      List.Items (Slot).Kind := Effective_Kind;
      List.Items (Slot).Message := Effective_Message;
      List.Items (Slot).Message_Last := Effective_Last;
      List.Items (Slot).Key := Effective_Key;
      List.Items (Slot).Key_Last := Effective_Key_Last;
   end Add;

   function Length
     (List : Diagnostic_List)
      return Natural
   is
   begin
      return List.Count;
   end Length;

   function Element
     (List  : Diagnostic_List;
      Index : Positive)
      return Diagnostic
   is
   begin
      if Index > List.Count then
         return (Kind => Parse_Error,
                 Message => [others => Character'Val (0)],
                 Message_Last => 0,
                 Key => [others => Character'Val (0)],
                 Key_Last => 0);
      end if;
      return List.Items (Index);
   end Element;

   function Message_Text
     (Item : Diagnostic)
      return String
   is
   begin
      if Item.Message_Last = 0 then
         return "";
      end if;
      return Item.Message (1 .. Item.Message_Last);
   end Message_Text;

   function Key_Text
     (Item : Diagnostic)
      return String
   is
   begin
      if Item.Key_Last = 0 then
         return "";
      end if;
      return Item.Key (1 .. Item.Key_Last);
   end Key_Text;

   function Has_Kind
     (List : Diagnostic_List;
      Kind : Diagnostic_Kind)
      return Boolean
   is
   begin
      for Index in 1 .. List.Count loop
         if List.Items (Index).Kind = Kind then
            return True;
         end if;
      end loop;
      return False;
   end Has_Kind;

end I18N.Diagnostics;
