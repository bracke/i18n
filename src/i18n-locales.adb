package body I18N.Locales is

   function Parent
     (Item : Locale_Id)
      return String
   is
   begin
      for Index in reverse Item'Range loop
         if Item (Index) = '-' then
            if Index = Item'First then
               return "";
            end if;
            return Item (Item'First .. Index - 1);
         end if;
      end loop;

      return "";
   end Parent;

end I18N.Locales;
