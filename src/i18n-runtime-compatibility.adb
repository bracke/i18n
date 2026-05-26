with Ada.Strings.Unbounded;
with I18N.Cache;
with I18N.Compiled;
with I18N.Fast_Render;

package body I18N.Runtime.Compatibility is

   procedure Initialize_Message
     (Item   : in out Runtime;
      Source : String)
   is
      Compiled : I18N.Compiled.Compiled_Message;
   begin
      Finalize (Item);
      declare
         Status : constant I18N.Errors.Result :=
           I18N.Cache.Get_Or_Compile
             (Key     => Source,
              Message => Compiled);
      begin
         if Status.Ok then
            I18N.Compiled.Set_Reference
              (Item.Message, I18N.Compiled.Reference (Compiled));
            Item.Has_Message := True;
            Item.Valid := True;
         else
            Item.Has_Message := False;
            Item.Valid := False;
            Item.Error := Status.Error;
         end if;
      end;
   exception
      when others =>
         Item.Has_Message := False;
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
   end Initialize_Message;

   procedure Set_Trace_Callback
     (CB : I18N.Observability.Trace_Callback)
   is
   begin
      I18N.Observability.Set_Trace_Callback (CB);
   end Set_Trace_Callback;

   function Render
     (Item : Runtime;
      Args : I18N.Arguments.Arguments)
      return I18N.Errors.Result
   is
      Buffer : I18N.Buffer.Buffer;
   begin
      if not Item.Valid then
         return I18N.Errors.Failure (Item.Error);
      end if;

      return I18N.Fast_Render.Render
        (Msg    => Item.Message,
         Buffer => Buffer,
         Args   => Args);
   exception
      when others =>
         return I18N.Errors.Failure (I18N.Errors.Parse_Error);
   end Render;

   function Render_Into
     (Item    : Runtime;
      Context : in out Execution_Context)
      return I18N.Errors.Status
   is
   begin
      if not Item.Valid then
         I18N.Diagnostics.Clear (Context.Diagnostics);
         I18N.Diagnostics.Add
           (List    => Context.Diagnostics,
            Kind    => I18N.Errors.To_Diagnostic_Kind (Item.Error),
            Message => "initialization failure");
         return I18N.Errors.Failure_Status (Item.Error);
      end if;

      return I18N.Fast_Render.Render_Into
        (Msg         => Item.Message,
         Buffer      => Context.Buffer,
         Args        => Context.Args,
         Diagnostics => Context.Diagnostics,
         Metadata    => Context.Metadata);
   exception
      when others =>
         I18N.Diagnostics.Clear (Context.Diagnostics);
         I18N.Diagnostics.Add
           (List    => Context.Diagnostics,
            Kind    => I18N.Diagnostics.Parse_Error,
            Message => "runtime exception");
         return I18N.Errors.Failure_Status (I18N.Errors.Parse_Error);
   end Render_Into;

   function Render
     (Item    : Runtime;
      Context : in out Execution_Context)
      return I18N.Errors.Result
   is
      Status : constant I18N.Errors.Status :=
        Render_Into (Item => Item, Context => Context);
   begin
      if not Status.Ok then
         declare
            Result : constant I18N.Errors.Result := I18N.Errors.Failure (Status.Error);
         begin
            return
              (Ok          => Result.Ok,
               Value       => Result.Value,
               Error       => Result.Error,
               Diagnostics => Context.Diagnostics);
         end;
      end if;

      declare
         Value : constant String := I18N.Buffer.To_String (Context.Buffer);
      begin
         return
           (Ok          => True,
            Value       => Ada.Strings.Unbounded.To_Unbounded_String (Value),
            Error       => I18N.Errors.Parse_Error,
            Diagnostics => Context.Diagnostics);
      end;
   end Render;

   function Has_Root
     (Item : Runtime)
      return Boolean
   is
   begin
      return Item.Has_Message
        and then I18N.Compiled.Op_Count (Item.Message) > 0;
   end Has_Root;

   function Last_Error
     (Item : Runtime)
      return I18N.Errors.Error_Kind
   is
   begin
      return Item.Error;
   end Last_Error;

end I18N.Runtime.Compatibility;
