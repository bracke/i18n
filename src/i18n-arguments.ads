with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

--  Stable v1.0 public argument-map API.
--
--  Purpose:
--  This package is the public namespace applications use for render arguments.
--  The representation is owned by the I18N public facade and does not expose any
--  implementation package or duplicate namespace. Future versions may change the
--  private representation without requiring application source changes, provided
--  the operations below keep their meanings.
--
--  Error behavior:
--  Missing render arguments are reported by I18N.Runtime.Render as
--  Missing_Argument. Plural and selectordinal arguments are supplied as strings
--  and parsed as strict decimal integers during render; invalid numeric syntax
--  is reported as Invalid_Argument.
--
--  Thread-safety and allocation:
--  Argument maps are mutable, noncopyable containers. Do not mutate the same
--  Arguments object concurrently with render calls that read it. Set/Clear may allocate
--  according to the implementation container. Read-only use by render is
--  stable.
--
--  Example:
--     I18N.Arguments.Set (Args, "name", "Ada");
--     I18N.Arguments.Set (Args, "count", "3");
package I18N.Arguments is

   type Arguments is tagged limited private;

   --  Remove all stored arguments.
   --
   --  @param Args Argument map to clear.
   procedure Clear
     (Args : in out Arguments);

   --  Store or replace a string argument value.
   --
   --  @param Args Argument map to update.
   --  @param Key Variable name. Must not be empty.
   --  @param Value Replacement text used during rendering.
   procedure Set
     (Args  : in out Arguments;
      Key   : String;
      Value : String);

   --  Store or replace a signed integer argument value.
   --
   --  The value is serialized as a strict decimal string with no Ada 'Image
   --  leading space (for example -3, 0, 42). Negative values keep a leading
   --  '-'. This helper is intentionally not locale-aware: it produces the
   --  canonical selector/argument text consumed by the message engine.
   --
   --  @param Args Argument map to update.
   --  @param Key Variable name. Must not be empty.
   --  @param Value Signed integer value to store.
   procedure Set_Integer
     (Args  : in out Arguments;
      Key   : String;
      Value : Long_Long_Integer);

   --  Store or replace a non-negative integer argument value.
   --
   --  The value is serialized as a strict decimal string with no Ada 'Image
   --  leading space. This helper is not locale-aware.
   --
   --  @param Args Argument map to update.
   --  @param Key Variable name. Must not be empty.
   --  @param Value Non-negative integer value to store.
   procedure Set_Natural
     (Args  : in out Arguments;
      Key   : String;
      Value : Natural);

   --  Store or replace a boolean argument value.
   --
   --  The value is serialized deterministically as the lowercase text "true"
   --  or "false". This helper is not locale-aware and is intended to feed
   --  generic select branches.
   --
   --  @param Args Argument map to update.
   --  @param Key Variable name. Must not be empty.
   --  @param Value Boolean value to store.
   procedure Set_Boolean
     (Args  : in out Arguments;
      Key   : String;
      Value : Boolean);

   --  Replace Destination with a copy of Source.
   --
   --  @param Source Argument map to copy from.
   --  @param Destination Argument map to replace.
   procedure Copy
     (Source      : Arguments;
      Destination : in out Arguments);

   --  Report whether a key exists in the argument map.
   --
   --  @param Args Argument map to inspect.
   --  @param Key Variable name to find.
   --  @return True when Key exists.
   function Has
     (Args : Arguments;
      Key  : String)
      return Boolean;

   --  Return a stored argument value.
   --
   --  @param Args Argument map to inspect.
   --  @param Key Existing variable name.
   --  @return Stored replacement text.
   function Get
     (Args : Arguments;
      Key  : String)
      return String
   with
     Pre => Has (Args, Key);

   --  Copy a stored argument value into caller-owned storage.
   --
   --  If Found is False, Last is 0 and Overflow is False. If the value is
   --  longer than Target, the prefix that fits is copied, Last is set to
   --  Target'Length, and Overflow is True.
   --
   --  @param Args Argument map to inspect.
   --  @param Key Existing variable name.
   --  @param Target Caller-owned destination buffer.
   --  @param Last Number of characters copied into Target.
   --  @param Found True when Key exists.
   --  @param Overflow True when Target was too small for the value.
   procedure Copy_Value
     (Args     : Arguments;
      Key      : String;
      Target   : out String;
      Last     : out Natural;
      Found    : out Boolean;
      Overflow : out Boolean);

private

   package Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Arguments is tagged limited record
      Values : Maps.Map;
   end record;

end I18N.Arguments;
