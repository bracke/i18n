private package I18N.Buffer is
   pragma Preelaborate;

   Default_Capacity : constant Positive := 4096;

   type Buffer is tagged private;

   --  Reset the buffer to empty without releasing or reallocating storage.
   --
   --  @param Item Buffer to clear.
   procedure Clear
     (Item : in out Buffer);

   --  Append text to the fixed-size buffer. When the append would exceed the
   --  fixed capacity, the buffer records overflow and leaves existing content
   --  deterministic and unchanged past capacity.
   --
   --  @param Item Buffer to update.
   --  @param Text Text segment to append.
   procedure Append
     (Item : in out Buffer;
      Text : String);

   --  Append one character to the fixed-size buffer.
   --
   --  @param Item Buffer to update.
   --  @param C Character to append.
   procedure Append
     (Item : in out Buffer;
      C    : Character);

   --  Report whether a previous append overflowed the fixed-size buffer.
   --
   --  @param Item Buffer to inspect.
   --  @return True when content did not fit in the fixed capacity.
   function Overflowed
     (Item : Buffer)
      return Boolean;

   --  Return the current number of stored characters.
   --
   --  @param Item Buffer to inspect.
   --  @return Current buffer length.
   function Length
     (Item : Buffer)
      return Natural;

   --  Return the accumulated buffer content.
   --
   --  This conversion is intentionally the only unavoidable materialization of
   --  a String result. The render loop itself does not grow dynamic storage.
   --
   --  @param Item Buffer to read.
   --  @return Current buffer content as a String.
   function To_String
     (Item : Buffer)
      return String;

private

   type Buffer is tagged record
      Data       : String (1 .. Default_Capacity) := [others => Character'Val (0)];
      Used       : Natural := 0;
      Had_Overflow : Boolean := False;
   end record;

end I18N.Buffer;
