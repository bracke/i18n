package body I18N.Compiled is

   function Op_Count
     (Msg : Compiled_Message)
      return Natural
   is
   begin
      if Msg.Ops = null then
         return 0;
      end if;

      return Msg.Ops.all'Length;
   end Op_Count;

   function Last_Index
     (Msg : Compiled_Message)
      return Natural
   is
   begin
      if Msg.Ops = null then
         return 0;
      end if;

      return Msg.Ops.all'Last;
   end Last_Index;

   function Element
     (Msg   : Compiled_Message;
      Index : Positive)
      return Op
   is
   begin
      return Msg.Ops.all (Index);
   end Element;

   procedure Clear
     (Msg : in out Compiled_Message)
   is
   begin
      Msg.Ops := null;
   end Clear;

   function Reference
     (Msg : Compiled_Message)
      return Message_Reference
   is
   begin
      return (Ops => Msg.Ops);
   end Reference;

   procedure Set_Reference
     (Msg : out Compiled_Message;
      Ref : Message_Reference)
   is
   begin
      Msg.Ops := Ref.Ops;
   end Set_Reference;

   function Op_Count
     (Build : Builder)
      return Natural
   is
   begin
      return Natural (Build.Ops.Length);
   end Op_Count;

   function Last_Index
     (Build : Builder)
      return Natural
   is
   begin
      if Build.Ops.Is_Empty then
         return 0;
      end if;

      return Natural (Build.Ops.Last_Index);
   end Last_Index;

   function Element
     (Build : Builder;
      Index : Positive)
      return Op
   is
   begin
      return Build.Ops.Element (Index);
   end Element;

   procedure Append
     (Build : in out Builder;
      Item  : Op)
   is
   begin
      Build.Ops.Append (Item);
   end Append;

   procedure Replace_Element
     (Build : in out Builder;
      Index : Positive;
      Item  : Op)
   is
   begin
      Build.Ops.Replace_Element (Index, Item);
   end Replace_Element;

   function Freeze
     (Build : Builder)
      return Compiled_Message
   is
      Count : constant Natural := Op_Count (Build);
   begin
      if Count = 0 then
         return Empty : Compiled_Message do
            Empty.Ops := null;
         end return;
      end if;

      declare
         Temp : Op_Array (1 .. Count);
      begin
         for Index in Temp'Range loop
            Temp (Index) := Build.Ops.Element (Index);
         end loop;

         return Frozen : Compiled_Message do
            Frozen.Ops := new Op_Array'(Temp);
         end return;
      end;
   end Freeze;

end I18N.Compiled;
