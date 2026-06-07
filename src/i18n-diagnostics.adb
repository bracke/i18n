with I18N.Diagnostics.Callbacks;

package body I18N.Diagnostics is
   pragma SPARK_Mode (On);

   procedure Set_Trace_Callback
     (CB : Trace_Callback)
   with
     SPARK_Mode => Off
   is
   begin
      I18N.Diagnostics.Callbacks.Set (CB);
   end Set_Trace_Callback;

   procedure Copy_Text
     (Source : String;
      Target : out String;
      Last   : out Natural)
   is
      Copy_Last : constant Natural := Natural'Min (Source'Length, Target'Length);
   begin
      Target := [others => Character'Val (0)];

      for Offset in 1 .. Copy_Last loop
         Target (Target'First + (Offset - 1)) :=
           Source (Source'First + (Offset - 1));
      end loop;

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
      Slot               : Positive;
      Effective_Kind     : Diagnostic_Kind := Kind;
      pragma Warnings (Off, "initialization of * has no effect*");
      Effective_Message  : String (1 .. Message_Capacity) :=
        [others => Character'Val (0)];
      Effective_Last     : Natural range 0 .. Message_Capacity := 0;
      Effective_Key      : String (1 .. Key_Capacity) :=
        [others => Character'Val (0)];
      Effective_Key_Last : Natural range 0 .. Key_Capacity := 0;
      pragma Warnings (On, "initialization of * has no effect*");
   begin
      if List.Count = Max_Diagnostics then
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
