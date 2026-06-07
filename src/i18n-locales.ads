--  Stable v1.0 public locale identifiers and fallback helpers.
--
--  Purpose:
--  This package defines the public locale identifier type used by catalog
--  rendering and the deterministic parent-locale helper used by fallback.
--
--  Locale identifiers are BCP-47-style strings such as "en", "de", or
--  "de-AT". v1.0 fallback removes the rightmost hyphen-separated subtag and
--  finally falls back to the runtime default locale.
--
--  Error behavior:
--  Locale parsing is deliberately simple. Invalid or unknown locale names are
--  treated as keys into the catalog/fallback chain; missing entries are reported
--  by render as Missing_Key.
--
--  Thread-safety and allocation:
--  Locale_Id is a String subtype. Parent returns a String value derived from
--  its input and has no global state.
--
--  Example:
--     Parent ("de-AT") = "de"
--     Parent ("de")    = ""
package I18N.Locales is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   --  Public locale identifier used by the stable render API.
   subtype Locale_Id is String;

   --  Built-in default locale name used when a catalog omits default_locale.
   Default_Locale_Name : constant String := "default";

   --  Return the parent locale for Item.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Parent locale or empty string when no parent exists.
   function Parent
     (Item : Locale_Id)
      return String
   with
     Global => null,
     Post   => Parent'Result'Length <= Item'Length;
end I18N.Locales;
