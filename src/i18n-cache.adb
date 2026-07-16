with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with I18N.AST;
with I18N.Compiler;
with I18N.Parser;
with I18N.Validation;

package body I18N.Cache is

   use I18N.Compiled;

   package Message_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => I18N.Compiled.Message_Reference,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   --  Cache model:
   --
   --  * Get_Or_Compile and Clear are initialization/build operations.
   --  * After initialization, Contains/Get/Compile_Count are plain read-only map
   --    accesses over immutable compiled-message references.
   --  * There is intentionally no protected object or mutex in Get.
   --
   --  Concurrent cache mutation is outside the execution contract. Shared
   --  runtimes bind Message_Reference handles before concurrent Render calls.
   Messages : Message_Maps.Map;
   Compiles : Natural := 0;

   function Get_Or_Compile
     (Key     : String;
      Message : out I18N.Compiled.Compiled_Message)
      return I18N.Errors.Result
   is
      Root : I18N.AST.Node_Access := null;
   begin
      I18N.Compiled.Clear (Message);

      if Messages.Contains (Key) then
         I18N.Compiled.Set_Reference (Message, Messages.Element (Key));
         return I18N.Errors.Success ("");
      end if;

      begin
         Root := I18N.Parser.Parse (Key);
      exception
         when I18N.Parser.Unbalanced_Braces =>
            I18N.AST.Free (Root);
            return I18N.Errors.Failure (I18N.Errors.Unbalanced_Braces);
         when I18N.Parser.Parse_Error =>
            I18N.AST.Free (Root);
            return I18N.Errors.Failure (I18N.Errors.Parse_Error);
         when others =>
            I18N.AST.Free (Root);
            return I18N.Errors.Failure (I18N.Errors.Parse_Error);
      end;

      declare
         Validation_Result : constant I18N.Errors.Result :=
           I18N.Validation.Validate (Root);
      begin
         if not Validation_Result.Ok then
            I18N.AST.Free (Root);
            return I18N.Errors.Failure (Validation_Result.Error);
         end if;
      end;

      begin
         declare
            Compiled : constant I18N.Compiled.Compiled_Message :=
              I18N.Compiler.Compile (Root);
         begin
            I18N.Compiled.Set_Reference
              (Message, I18N.Compiled.Reference (Compiled));
         end;
      exception
         when others =>
            I18N.AST.Free (Root);
            return I18N.Errors.Failure (I18N.Errors.Parse_Error);
      end;

      I18N.AST.Free (Root);

      if not Messages.Contains (Key) then
         Messages.Insert (Key, I18N.Compiled.Reference (Message));
         Compiles := Compiles + 1;
      end if;

      I18N.Compiled.Set_Reference (Message, Messages.Element (Key));
      return I18N.Errors.Success ("");
   end Get_Or_Compile;

   function Contains
     (Key : String)
      return Boolean
   is
   begin
      return Messages.Contains (Key);
   end Contains;

   function Get
     (Key : String)
      return I18N.Compiled.Compiled_Message
   is
   begin
      return Message : I18N.Compiled.Compiled_Message do
         I18N.Compiled.Set_Reference (Message, Messages.Element (Key));
      end return;
   end Get;

   procedure Clear is
   begin
      Messages.Clear;
      Compiles := 0;
   end Clear;

   function Compile_Count return Natural is
   begin
      return Compiles;
   end Compile_Count;

end I18N.Cache;
