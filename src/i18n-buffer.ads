private package I18N.Buffer is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   Default_Capacity : constant Positive := 4096;

   type Buffer is tagged private;

   --  Reset the buffer to empty without releasing or reallocating storage.
   --
   --  @param Item Buffer to clear.
   procedure Clear
     (Item : in out Buffer)
   with
     Global => null,
     Post   => Length (Item) = 0 and then not Overflowed (Item);

   --  Append text to the fixed-size buffer. When the append would exceed the
   --  fixed capacity, the buffer records overflow and leaves existing content
   --  deterministic and unchanged past capacity.
   --
   --  @param Item Buffer to update.
   --  @param Text Text segment to append.
   procedure Append
     (Item : in out Buffer;
      Text : String)
   with
     Global => null,
     Post   => Length (Item) <= Default_Capacity;

   --  Append one character to the fixed-size buffer.
   --
   --  @param Item Buffer to update.
   --  @param C Character to append.
   procedure Append
     (Item : in out Buffer;
      C    : Character)
   with
     Global => null,
     Post   => Length (Item) <= Default_Capacity;

   --  Report whether a previous append overflowed the fixed-size buffer.
   --
   --  @param Item Buffer to inspect.
   --  @return True when content did not fit in the fixed capacity.
   function Overflowed
     (Item : Buffer)
      return Boolean
   with
     Global => null;

   --  Return the current number of stored characters.
   --
   --  @param Item Buffer to inspect.
   --  @return Current buffer length.
   function Length
     (Item : Buffer)
      return Natural
   with
     Global => null,
     Post   => Length'Result <= Default_Capacity;

   --  Return the accumulated buffer content.
   --
   --  This conversion is intentionally the only unavoidable materialization of
   --  a String result. The render loop itself does not grow dynamic storage.
   --
   --  @param Item Buffer to read.
   --  @return Current buffer content as a String.
   function To_String
     (Item : Buffer)
      return String
   with
     Global => null,
     Post   => To_String'Result'Length = Length (Item);

private

   type Buffer is tagged record
      Data       : String (1 .. Default_Capacity) := [others => Character'Val (0)];
      Used       : Natural range 0 .. Default_Capacity := 0;
      Had_Overflow : Boolean := False;
   end record;

   function Overflowed
     (Item : Buffer)
      return Boolean is (Item.Had_Overflow);

   function Length
     (Item : Buffer)
      return Natural is (Item.Used);

end I18N.Buffer;
