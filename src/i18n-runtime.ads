private with Ada.Containers.Vectors;
private with Ada.Strings.Unbounded;

with I18N.Arguments;
with I18N.Locales;
with I18N.Result;

private with I18N.Errors;
private with I18N.Compiled;

--  Stable v1.0 runtime API.
--
--  Purpose:
--  This package owns runtime initialization, catalog lookup, locale fallback,
--  and the stable public Render facade. Applications should use Instance,
--  Initialize, Render, Is_Valid, and Finalize. Parser, validator, compiler,
--  IR, cache, execution, internal error, buffer, and observability packages are
--  implementation details and are not part of the v1.0 public contract.
--
--  Error behavior:
--  Initialize records deterministic validity state. Public catalog Render returns
--  I18N.Result.Render_Result and does not raise for normal ICU/catalog/render
--  failures. Invalid runtimes render as Execution_Error.
--
--  Thread-safety:
--  Initialize and Finalize are setup/teardown operations and must not run
--  concurrently with renders on the same object. After successful
--  initialization, concurrent read-only public renders against the same runtime
--  are intended to be safe. Shared diagnostic callbacks must be externally
--  thread-safe.
--
--  Allocation behavior:
--  Initialization may allocate for catalog storage and catalog validation. Public Render returns a structured result
--  containing a text view; strict fixed-buffer compatibility rendering is kept
--  outside the stable v1.0 public API.
--
--  Example:
--     I18N.Runtime.Initialize (Runtime, "messages.catalog");
--     Result := I18N.Runtime.Render (Runtime, "de-AT", "welcome", Args);
package I18N.Runtime is

   type Runtime is tagged limited private;
   subtype Instance is Runtime;

   --  Initialize a v1.0 runtime from the canonical catalog file format.
   --
   --  Catalog format is UTF-8-compatible ASCII text with one message per line:
   --
   --     locale.key = ICU message string
   --
   --  Blank lines and lines beginning with '#' are ignored. Quoted values are
   --  accepted and have their surrounding quotes removed. The reserved key
   --  "default_locale" sets the deterministic default locale used by fallback.
   --
   --  During initialization catalog structure and brace balance are validated,
   --  and entries are recorded behind a private normalized locale/key table.
   --  Invalid catalogs fail deterministically:
   --  Is_Valid becomes False and public catalog Render returns Execution_Error.
   --
   --  @param Item Runtime instance to initialize.
   --  @param Catalog_Path Path to a catalog file.
   procedure Initialize
     (Item         : in out Runtime;
      Catalog_Path : String);

   --  Stable v1.0 catalog render API.
   --
   --  Rendering does not mutate Runtime. It resolves Locale using deterministic
   --  fallback (for example de-AT -> de -> default locale), selects Key, and
   --  renders the selected ICU message. Normal ICU/render
   --  failures are returned as structured statuses and do not raise exceptions.
   --
   --  @param Item Initialized runtime instance.
   --  @param Locale Requested locale.
   --  @param Key Message key.
   --  @param Arguments Public argument map.
   --  @return Stable v1.0 public render result.
   function Render
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments)
      return I18N.Result.Render_Result;

   --  Return whether the last initialization produced a valid runtime.
   --
   --  @param Item Runtime instance to inspect.
   --  @return True when the catalog is valid for public rendering.
   function Is_Valid
     (Item : Runtime)
      return Boolean;

   --  Drop this runtime's references to catalog/message data. The global cache
   --  is intentionally not cleared by Finalize.
   --
   --  @param Item Runtime instance to finalize.
   procedure Finalize
     (Item : in out Runtime);

private

   use Ada.Strings.Unbounded;

   type Catalog_Entry is record
      Locale      : Unbounded_String;
      Message_Key : Unbounded_String;
      Source      : Unbounded_String;
   end record;

   package Catalog_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Catalog_Entry);

   type Runtime is tagged limited record
      Valid               : Boolean := True;
      Error               : I18N.Errors.Error_Kind := I18N.Errors.Parse_Error;

      --  Compatibility single-message state used only by the private
      --  I18N.Runtime.Compatibility child package and in-tree regression tests.
      --  The stable public catalog API does not expose or depend on this state.
      Message             : I18N.Compiled.Compiled_Message;
      Has_Message         : Boolean := False;

      Catalog             : Catalog_Vectors.Vector;
      Default_Locale      : Unbounded_String := To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Default_Locale_Seen : Boolean := False;
   end record;

end I18N.Runtime;
