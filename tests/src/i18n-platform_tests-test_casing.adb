with I18N.Data_Store;
with I18N.Casing;

--  Uses the generated uprops.i18ndata (built into share/i18n). Points the loader
--  at the real data directory relative to the tests crate.
separate (I18N.Platform_Tests)
procedure Test_Casing
  (T : in out AUnit.Test_Cases.Test_Case'Class)
is
   pragma Unreferenced (T);
   Sharp_S : constant String := Character'Val (16#C3#) & Character'Val (16#9F#);
begin
   I18N.Data_Store.Configure_Data_Dir ("../share/i18n");
   if not I18N.Casing.Available then
      I18N.Data_Store.Configure_Data_Dir ("share/i18n");
   end if;
   if not I18N.Casing.Available then
      return;   --  data not generated in this build environment; skip
   end if;

   Assert (I18N.Casing.To_Upper ("abc") = "ABC", "upper of abc");
   Assert (I18N.Casing.To_Lower ("ABC") = "abc", "lower of ABC");
   --  Full case mapping: sharp s uppercases to SS.
   Assert (I18N.Casing.To_Upper (Sharp_S) = "SS", "upper of sharp s is SS");
   Assert (I18N.Casing.To_Title ("hello world") = "Hello World",
           "title-case of a sentence");
end Test_Casing;
