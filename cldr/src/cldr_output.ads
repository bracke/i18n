--  Where a CLDR generator writes its output before publishing it, and how it
--  publishes it. Every run gets its own temp file, and the target is replaced
--  in one rename, so a generator running alongside another (a --check, a
--  second regen) neither shares a temp file with it nor reads a half-copied
--  target.
package Cldr_Output is

   --  @param Name A file name ("i18n_cldr_export.generated.jsonl").
   --  @return A path in the temp directory unique to this process.
   function Temp_Path (Name : String) return String;

   --  Replace Target with a copy of Generated, atomically, and remove Generated.
   --  @param Generated The completed output (Temp_Path).
   --  @param Target The file to publish it as.
   procedure Publish (Generated : String; Target : String);

   --  Remove Generated if it exists; for runs that do not publish.
   --  @param Generated The output to discard.
   procedure Discard (Generated : String);

end Cldr_Output;
