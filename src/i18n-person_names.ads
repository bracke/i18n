--  CLDR person-name formatting (TR35). Given a set of name fields and a
--  formatter locale, produce a formatted name -- choosing order, selecting a
--  pattern across the length/usage/formality fallback, resolving field
--  modifiers (e.g. -initial), dropping missing fields with their adjacent
--  literals, and applying native/foreign spacing. Backed by per-locale shards
--  share/i18n/person-names/<locale>.i18ndata.
--
--  Scope (v1): the referring and addressing usages, with order derivation,
--  pattern fallback, field substitution incl. the -initial/-informal modifiers,
--  and missing-field handling. Monograms, the full modifier set, and Unicode
--  upper-casing are a documented follow-up.
private with Ada.Strings.Unbounded;
package I18N.Person_Names is

   --  A name is a set of CLDR fields plus the name's own locale. Field keys are
   --  CLDR keys: "title", "given", "given2", "surname", "surname-core",
   --  "surname-prefix", "given-informal", "generation", "credentials", ...
   type Name is private;

   procedure Set_Field (N : in out Name; Field : String; Value : String);

   --  The name's own locale, used to derive order and native-vs-foreign
   --  spacing. Optional; defaults to given-first order when unset.
   procedure Set_Locale (N : in out Name; Locale : String);

   procedure Clear (N : in out Name);

   type Order_Kind is
     (Order_Auto, Given_First, Surname_First, Sorting);
   type Length_Kind is (Long, Medium, Short);
   type Usage_Kind is (Referring, Addressing, Monogram);
   type Formality_Kind is (Formal, Informal);

   --  Format N for display in Formatter_Locale.
   function Format
     (Formatter_Locale : String;
      N                : Name;
      Order            : Order_Kind := Order_Auto;
      Length           : Length_Kind := Medium;
      Usage            : Usage_Kind := Referring;
      Formality        : Formality_Kind := Formal)
      return String;

   --  True when a person-name shard is installed for the locale (or a parent).
   function Available (Locale : String) return Boolean;

private
   use Ada.Strings.Unbounded;

   Max_Fields : constant := 24;
   type Field_Pair is record
      Key   : Unbounded_String;
      Value : Unbounded_String;
   end record;
   type Field_Array is array (1 .. Max_Fields) of Field_Pair;

   type Name is record
      Fields : Field_Array;
      Count  : Natural := 0;
      Locale : Unbounded_String;
   end record;

end I18N.Person_Names;
