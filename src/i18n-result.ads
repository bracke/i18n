with I18N.Diagnostics;

--  Stable v1.1.0 public render result model.
--
--  Purpose:
--  This package defines the only result type returned by the v1.1.0 public
--  catalog render API. It intentionally hides parser, compiler, cache, IR,
--  formatter implementation, generated CLDR data, and internal error details
--  behind a small frozen status enumeration.
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
--  storage. Output_Text returns the meaningful prefix. The public
--  I18N.Runtime.Render_Into facade is the allocation-free render path: it
--  writes directly into caller-owned fixed storage.
--
--  Example:
--     if Result.Status = I18N.Result.Success then
--        Put_Line (I18N.Result.Output_Text (Result.Text));
--     end if;
package I18N.Result is
   pragma SPARK_Mode (On);
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
      return Output_View
   with
     Global => null,
     Post   => To_Output_View'Result.Length <= Max_Output_Length;

   --  Return the meaningful prefix of an output view.
   --
   --  @param View Output view to inspect.
   --  @return Rendered output text without fixed-storage padding.
   function Output_Text
     (View : Output_View)
      return String
   with
     Global => null,
     Pre    => View.Length <= Max_Output_Length,
     Post   => Output_Text'Result'Length = View.Length;

   --  Build a public failure without rendered text.
   --
   --  @param Status Stable public failure status.
   --  @return Public failed render result with empty text and empty diagnostics.
   function Failure
     (Status : Render_Status)
      return Render_Result
   with
     Global => null,
     Post   => Failure'Result.Status = Status
       and then Failure'Result.Text.Length = 0
       and then I18N.Diagnostics.Length (Failure'Result.Diagnostics) = 0;

end I18N.Result;
