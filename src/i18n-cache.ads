with I18N.Compiled;
with I18N.Errors;

private package I18N.Cache is

   type Map is limited private;

   --  Return the cached compiled message for Key, compiling Key as ICU source
   --  on the first request.
   --
   --  @param Key Message identifier and source text used for compilation.
   --  @param Message Cached or newly compiled message. Meaningful when returned Result is Ok.
   --  @return Success on a cache hit or successful compile; otherwise the parse/validation failure.
   function Get_Or_Compile
     (Key     : String;
      Message : out I18N.Compiled.Compiled_Message)
      return I18N.Errors.Result;

   --  Report whether Key is already present in the compiled-message cache.
   --
   --  @param Key Message key/source to look up.
   --  @return True when Key has already been compiled and cached.
   function Contains
     (Key : String)
      return Boolean;

   --  Return an already cached compiled message. This operation is intended for
   --  initialized/read-only cache use; it does not parse, validate, compile,
   --  mutate the cache, or acquire a synchronization lock.
   --
   --  @param Key Message key/source to look up.
   --  @return Cached compiled message for Key.
   function Get
     (Key : String)
      return I18N.Compiled.Compiled_Message
   with
     Pre => Contains (Key);

   --  Clear every cached compiled message. Initialization-only operation only;
   --  do not call concurrently with read-only cache access or rendering.
   procedure Clear;

   --  @return Number of successful cache misses that performed real compilation.
   function Compile_Count return Natural;

private
   type Map is limited null record;
end I18N.Cache;
