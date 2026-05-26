--  Root namespace for ICU Messages Ada.
--
--  The stable v1.0 public API includes this root package and these child packages:
--
--  * I18N.Runtime
--  * I18N.Result
--  * I18N.Diagnostics
--  * I18N.Arguments
--  * I18N.Locales
--
--  Parser, validator, compiler, IR, cache, and execution child packages are
--  internal implementation details and are not part of the application-facing
--  compatibility contract.
package I18N is
   pragma Preelaborate;
end I18N;
