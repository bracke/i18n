--  Runtime loader for the CLDR data files that back the "heavy/optional" areas
--  (display names, and later annotations, collation, ...). A data file is the
--  same packed, sorted, bisectable representation the compiled tables use, only
--  written to a file and loaded on demand instead of compiled into the body.
--
--  Format (all ASCII framing; values are raw UTF-8 bytes):
--
--     I18NDATA|1|<cldr-version>\n              -- header
--     @<section>|<count>\n                     -- one per section
--     <key>\t<value>\n                         -- records, sorted by <key>
--     ...
--     @<section>|<count>\n
--     ...
--
--  Records within a section are sorted by <key> so a lookup bisects in place
--  over the loaded bytes -- no per-record index is built at load time, which
--  matters because a full-locale display-name file is ~10^6 records. Keys are
--  composed by the caller (e.g. "<locale>\x1f<code>"); parent-locale fallback
--  is the caller's job (see I18N.Display_Names), keeping this layer a pure
--  key -> value map.
package I18N.Data_Store is

   --  Override where data files are looked for. Highest priority in the search
   --  order (see the body): this, then $I18N_DATA_DIR, then the install
   --  default, then the running executable's directory + "share/i18n".
   procedure Configure_Data_Dir (Path : String);

   --  Look up Key in Section of the named data file (base name without
   --  extension, e.g. "display-names"). Returns the value, or "" when the file,
   --  section, or key is absent. The file is loaded and indexed once, lazily,
   --  and cached for the process; concurrent first use is safe.
   function Lookup
     (File    : String;
      Section : String;
      Key     : String)
      return String;

   --  True when the named data file was found and loaded. Lets a feature report
   --  "not installed" rather than silently returning fallbacks forever.
   function Available (File : String) return Boolean;

   --  The intra-key separator the callers use to build composite keys.
   Key_Separator : constant Character := Character'Val (16#1F#);

end I18N.Data_Store;
