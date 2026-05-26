with I18N.Diagnostics;

--  Stable v1.0 public render result model.
--
--  Purpose:
--  This package defines the only result type returned by the v1.0 public
--  catalog render API. It intentionally hides parser, compiler, cache, IR, and
--  internal error details behind a small frozen status enumeration.
--
--  Error behavior:
--  Normal ICU/render failures are represented by Render_Status values. Future
--  versions may add richer diagnostic detail, but the meaning of existing
--  statuses must not change.
--
--  Thread-safety:
--  Values of these types are ordinary Ada values. Sharing a value for read-only
--  inspection is safe; concurrent mutation of the same object is the caller's
--  responsibility.
--
--  Allocation behavior:
--  Output_View stores the materialized final String in bounded public result
--  storage. Output_Text returns the meaningful prefix. The lower-level
--  Render_Into path is the checked fixed-buffer no-allocation render path.
--
--  Example:
--     if Result.Status = I18N.Result.Success then
--        Put_Line (I18N.Result.Output_Text (Result.Text));
--     end if;
package I18N.Result is
   --  Frozen public render status set.
   type Render_Status is
     (Success,
      Missing_Key,
      Missing_Argument,
      Invalid_Argument,
      Formatting_Error,
      Execution_Error,
      Buffer_Overflow,
      Internal_Error);

   Max_Output_Length : constant Positive := 4096;

   --  Public bounded output view.
   --
   --  Text contains fixed storage. Length identifies the meaningful prefix.
   --  Output_Text returns the visible rendered value as a normal String.
   type Output_View is record
      Text   : String (1 .. Max_Output_Length) := [others => Character'Val (0)];
      Length : Natural := 0;
   end record;

   --  Public render result returned by I18N.Runtime.Render.
   --
   --  Diagnostics are optional detail. They never change the Status or Text
   --  semantics.
   type Render_Result is record
      Status      : Render_Status := Internal_Error;
      Text        : Output_View;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   end record;

   --  Build an Output_View from a rendered string.
   --
   --  @param Text Rendered output text.
   --  @return Bounded public output view. Text longer than Max_Output_Length is truncated.
   function To_Output_View
     (Text : String)
      return Output_View;

   --  Return the meaningful prefix of an output view.
   --
   --  @param View Output view to inspect.
   --  @return Rendered output text without fixed-storage padding.
   function Output_Text
     (View : Output_View)
      return String;

   --  Build a public failure without rendered text.
   --
   --  @param Status Stable public failure status.
   --  @return Public failed render result with empty text and empty diagnostics.
   function Failure
     (Status : Render_Status)
      return Render_Result;

end I18N.Result;
