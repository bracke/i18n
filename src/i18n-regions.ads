--  The region a locale belongs to: the one it names ("de-AT" Austria), else
--  its language's likely one from CLDR's likelySubtags ("dv" the Maldives,
--  "zh-Hant" Taiwan) -- what region-keyed data (week, hour cycle) goes by.
package I18N.Regions is

   --  @param Locale A BCP 47 locale.
   --  @return Its region subtag, upper case ("AT", "419"); "" when neither it
   --          nor CLDR names one.
   function Region (Locale : String) return String;

end I18N.Regions;
