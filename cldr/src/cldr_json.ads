--  Minimal JSON reader shared by the runtime-data generators
--  (generate_cldr_display_data, generate_cldr_annotation_data). Handles the
--  shape CLDR-JSON uses: nested objects of string / array / object values.
package Cldr_Json is

   --  Whole file as a byte string ("" if absent/unreadable).
   function Read_File (Path : String) return String;

   --  Iterate the members of the object in Text, calling Process (name, value).
   --  String values are returned unquoted (escapes intact); object/array values
   --  keep their braces so navigation and nesting checks still work.
   procedure For_Each
     (Text    : String;
      Process : not null access procedure (Name : String; Value : String));

   --  Value of the named field of the object in Text ("" if absent).
   function Field (Text : String; Name : String) return String;

   --  Iterate the string elements of the JSON array in Array_Text, calling
   --  Process with each (unquoted, escapes intact).
   procedure For_Each_String
     (Array_Text : String;
      Process    : not null access procedure (Value : String));

   --  Iterate a JSON array whose elements are 2-element string arrays
   --  ([["a","b"],...]), calling Process with each pair (unquoted).
   procedure For_Each_Pair
     (Array_Text : String;
      Process    : not null access procedure (A : String; B : String));

   --  Decode JSON string escapes (\", \\, \/, \n, \t, \uXXXX incl. surrogate
   --  pairs, ...) to raw UTF-8 bytes.
   function Unescape (Raw : String) return String;

end Cldr_Json;
