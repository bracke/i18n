package body I18N.Buffer is

   procedure Clear
     (Item : in out Buffer)
   is
   begin
      Item.Used := 0;
      Item.Had_Overflow := False;
   end Clear;

   procedure Append
     (Item : in out Buffer;
      Text : String)
   is
      Remaining : constant Natural := Default_Capacity - Item.Used;
   begin
      if Text'Length > Remaining then
         if Remaining > 0 then
            Item.Data (Item.Used + 1 .. Default_Capacity) :=
              Text (Text'First .. Text'First + Remaining - 1);
            Item.Used := Default_Capacity;
         end if;
         Item.Had_Overflow := True;
      elsif Text'Length > 0 then
         Item.Data (Item.Used + 1 .. Item.Used + Text'Length) := Text;
         Item.Used := Item.Used + Text'Length;
      end if;
   end Append;

   procedure Append
     (Item : in out Buffer;
      C    : Character)
   is
   begin
      if Item.Used = Default_Capacity then
         Item.Had_Overflow := True;
      else
         Item.Used := Item.Used + 1;
         Item.Data (Item.Used) := C;
      end if;
   end Append;

   function Overflowed
     (Item : Buffer)
      return Boolean
   is
   begin
      return Item.Had_Overflow;
   end Overflowed;

   function Length
     (Item : Buffer)
      return Natural
   is
   begin
      return Item.Used;
   end Length;

   function To_String
     (Item : Buffer)
      return String
   is
   begin
      if Item.Used = 0 then
         return "";
      end if;

      return Item.Data (1 .. Item.Used);
   end To_String;

end I18N.Buffer;
