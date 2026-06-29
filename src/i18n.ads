--  Root namespace for ICU Messages Ada.
--
--  The stable public API includes this root package and these child packages:
--
--  * I18N.Runtime
--  * I18N.Result
--  * I18N.Diagnostics
--  * I18N.Arguments
--  * I18N.Locales
--  * I18N.Plurals
--
--  Parser, validator, compiler, IR, AST, cache, and execution child packages are
--  internal implementation details and are not part of the application-facing
--  compatibility contract.
package I18N is
   pragma Preelaborate;
   pragma SPARK_Mode (On);
end I18N;
