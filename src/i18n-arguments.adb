package body I18N.Arguments is

   --  Render a signed integer as a strict decimal string without the leading
   --  space that Long_Long_Integer'Image produces for non-negative values.
   function Decimal_Image (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Decimal_Image;

   procedure Clear
     (Args : in out Arguments)
   is
   begin
      Args.Values.Clear;
   end Clear;

   procedure Set
     (Args  : in out Arguments;
      Key   : String;
      Value : String)
   is
   begin
      if Key'Length = 0 then
         return;
      end if;

      if Args.Values.Contains (Key) then
         Args.Values.Replace (Key, Value);
      else
         Args.Values.Insert (Key, Value);
      end if;
   end Set;

   procedure Set_Integer
     (Args  : in out Arguments;
      Key   : String;
      Value : Long_Long_Integer)
   is
   begin
      Set (Args, Key, Decimal_Image (Value));
   end Set_Integer;

   procedure Set_Natural
     (Args  : in out Arguments;
      Key   : String;
      Value : Natural)
   is
   begin
      Set (Args, Key, Decimal_Image (Long_Long_Integer (Value)));
   end Set_Natural;

   procedure Set_Boolean
     (Args  : in out Arguments;
      Key   : String;
      Value : Boolean)
   is
   begin
      Set (Args, Key, (if Value then "true" else "false"));
   end Set_Boolean;

   procedure Copy
     (Source      : Arguments;
      Destination : in out Arguments)
   is
   begin
      Destination.Values.Clear;

      for Cursor in Source.Values.Iterate loop
         Destination.Values.Insert
           (Key      => Maps.Key (Cursor),
            New_Item => Maps.Element (Cursor));
      end loop;
   end Copy;

   function Has
     (Args : Arguments;
      Key  : String)
      return Boolean
   is
   begin
      return Args.Values.Contains (Key);
   end Has;

   function Get
     (Args : Arguments;
      Key  : String)
      return String
   is
   begin
      return Args.Values.Element (Key);
   end Get;

   procedure Copy_Value
     (Args     : Arguments;
      Key      : String;
      Target   : out String;
      Last     : out Natural;
      Found    : out Boolean;
      Overflow : out Boolean)
   is
   begin
      Target := [others => Character'Val (0)];

      if not Args.Values.Contains (Key) then
         Last := 0;
         Found := False;
         Overflow := False;
         return;
      end if;

      declare
         Value : constant String := Args.Values.Element (Key);
         Count : constant Natural := Natural'Min (Target'Length, Value'Length);
      begin
         if Count > 0 then
            Target (Target'First .. Target'First + Count - 1) :=
              Value (Value'First .. Value'First + Count - 1);
         end if;

         Last := Count;
         Found := True;
         Overflow := Value'Length > Target'Length;
      end;
   end Copy_Value;

end I18N.Arguments;
