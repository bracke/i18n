with Ada.Directories;
with Ada.Strings.Fixed;

with Hostkit.Fs;
with Hostkit.Host;

package body Cldr_Output is

   function Process_Tag return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Hostkit.Host.Own_Process_Id), Ada.Strings.Both));

   function Temp_Path (Name : String) return String is
     (Hostkit.Fs.Temp_Directory & "/" & Process_Tag & "-" & Name);

   procedure Publish (Generated : String; Target : String) is
      --  Next to Target, so the rename stays on one filesystem.
      Staged : constant String := Target & "." & Process_Tag & ".tmp";
   begin
      Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Target));
      Ada.Directories.Copy_File (Generated, Staged);
      if not Hostkit.Fs.Replace_File (Staged, Target) then
         Discard (Staged);
         raise Ada.Directories.Use_Error with "cannot replace " & Target;
      end if;
      Discard (Generated);
   end Publish;

   procedure Discard (Generated : String) is
   begin
      if Ada.Directories.Exists (Generated) then
         Ada.Directories.Delete_File (Generated);
      end if;
   end Discard;

end Cldr_Output;
