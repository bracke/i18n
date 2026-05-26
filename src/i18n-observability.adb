package body I18N.Observability is

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

   procedure Set_Trace_Callback
     (CB : Trace_Callback)
   is
   begin
      Callback_State.Set (CB);
   end Set_Trace_Callback;

   function Current_Trace_Callback
      return Trace_Callback
   is
   begin
      return Callback_State.Get;
   end Current_Trace_Callback;

   procedure Emit
     (Event : Trace_Event_Kind;
      Key   : String := "")
   is
      CB : constant Trace_Callback := Callback_State.Get;
   begin
      if CB /= null then
         begin
            CB.all (Event, Key);
         exception
            when others =>
               --  Trace callbacks are explicitly observational. A faulty
               --  callback must not alter render success, render output, or
               --  diagnostics collection.
               null;
         end;
      end if;
   end Emit;

   procedure Set_Message_Key
     (Metadata : in out Execution_Metadata;
      Value    : String)
   is
   begin
      Copy_Text
        (Source => Value,
         Target => Metadata.Message_Key,
         Last   => Metadata.Message_Key_Last);
   end Set_Message_Key;

   procedure Set_Locale
     (Metadata : in out Execution_Metadata;
      Value    : String)
   is
   begin
      Copy_Text
        (Source => Value,
         Target => Metadata.Locale,
         Last   => Metadata.Locale_Last);
   end Set_Locale;

   function Message_Key
     (Metadata : Execution_Metadata)
      return String
   is
   begin
      if Metadata.Message_Key_Last = 0 then
         return "";
      end if;
      return Metadata.Message_Key (1 .. Metadata.Message_Key_Last);
   end Message_Key;

   function Locale
     (Metadata : Execution_Metadata)
      return String
   is
   begin
      if Metadata.Locale_Last = 0 then
         return "";
      end if;
      return Metadata.Locale (1 .. Metadata.Locale_Last);
   end Locale;

end I18N.Observability;
