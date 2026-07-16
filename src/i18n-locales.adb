with Ada.Strings;
with Ada.Strings.Fixed;

package body I18N.Locales is
   pragma SPARK_Mode (On);

   function Lower_ASCII (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val
           (Character'Pos (C) - Character'Pos ('A') + Character'Pos ('a'));
      end if;

      return C;
   end Lower_ASCII;

   function Upper_ASCII (C : Character) return Character is
   begin
      if C in 'a' .. 'z' then
         return Character'Val
           (Character'Pos (C) - Character'Pos ('a') + Character'Pos ('A'));
      end if;

      return C;
   end Upper_ASCII;

   function Is_Alpha_ASCII (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z');

   function Is_Digit_ASCII (C : Character) return Boolean is
     (C in '0' .. '9');

   function Is_Alnum_ASCII (C : Character) return Boolean is
     (Is_Alpha_ASCII (C) or else Is_Digit_ASCII (C));

   function Lower_ASCII (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Lower_ASCII (Text (Index));
      end loop;

      return Result;
   end Lower_ASCII;

   function Upper_ASCII (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Upper_ASCII (Text (Index));
      end loop;

      return Result;
   end Upper_ASCII;

   function Title_ASCII (Text : String) return String is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         if Index = Text'First then
            Result (Index) := Upper_ASCII (Text (Index));
         else
            Result (Index) := Lower_ASCII (Text (Index));
         end if;
      end loop;

      return Result;
   end Title_ASCII;

   function All_Alpha_ASCII (Text : String) return Boolean is
   begin
      for C of Text loop
         if not Is_Alpha_ASCII (C) then
            return False;
         end if;
      end loop;

      return Text'Length > 0;
   end All_Alpha_ASCII;

   function All_Digit_ASCII (Text : String) return Boolean is
   begin
      for C of Text loop
         if not Is_Digit_ASCII (C) then
            return False;
         end if;
      end loop;

      return Text'Length > 0;
   end All_Digit_ASCII;

   function Language_Alias (Language : String) return String is
      Lower : constant String := Lower_ASCII (Language);
   begin
      if Lower = "iw" then
         return "he";
      elsif Lower = "in" then
         return "id";
      elsif Lower = "ji" then
         return "yi";
      elsif Lower = "mo" then
         return "ro";
      else
         return Lower;
      end if;
   end Language_Alias;

   function Canonicalize
     (Item : Locale_Id)
      return String
   is
      Clean           : constant String :=
        Ada.Strings.Fixed.Trim (Item, Ada.Strings.Both);
      Result          : String (1 .. Clean'Length + 5);
      Last            : Natural := 0;
      Subtag_First    : Positive;
      Subtag_Index    : Natural := 0;
      In_Extension    : Boolean := False;
      Primary_Was_Sh  : Boolean := False;

      function Canonical_Subtag (Subtag : String) return String is
      begin
         if Subtag_Index = 1 then
            Primary_Was_Sh := Lower_ASCII (Subtag) = "sh";
            if Primary_Was_Sh then
               return "sr";
            end if;

            return Language_Alias (Subtag);
         elsif In_Extension then
            return Lower_ASCII (Subtag);
         elsif Subtag'Length = 4 and then All_Alpha_ASCII (Subtag) then
            return Title_ASCII (Subtag);
         elsif (Subtag'Length = 2 and then All_Alpha_ASCII (Subtag))
           or else (Subtag'Length = 3 and then All_Digit_ASCII (Subtag))
         then
            return Upper_ASCII (Subtag);
         else
            return Lower_ASCII (Subtag);
         end if;
      end Canonical_Subtag;

      procedure Append_Text (Text : String) is
      begin
         if Text'Length > 0 then
            Result (Last + 1 .. Last + Text'Length) := Text;
            Last := Last + Text'Length;
         end if;
      end Append_Text;

      procedure Append_Subtag (Subtag : String) is
         Canonical : constant String := Canonical_Subtag (Subtag);
      begin
         if Last > 0 then
            Last := Last + 1;
            Result (Last) := '-';
         end if;

         Append_Text (Canonical);

         if Primary_Was_Sh and then Subtag_Index = 1 then
            Append_Text ("-Latn");
         end if;

         if Subtag'Length = 1 then
            In_Extension := True;
         end if;
      end Append_Subtag;
   begin
      if Clean'Length = 0 then
         return "";
      end if;

      Subtag_First := Clean'First;
      for Index in Clean'Range loop
         if Clean (Index) = '-' or else Clean (Index) = '_' then
            if Index > Subtag_First then
               Subtag_Index := Subtag_Index + 1;
               Append_Subtag (Clean (Subtag_First .. Index - 1));
            end if;
            Subtag_First := Index + 1;
         end if;
      end loop;

      if Subtag_First <= Clean'Last then
         Subtag_Index := Subtag_Index + 1;
         Append_Subtag (Clean (Subtag_First .. Clean'Last));
      end if;

      return Result (1 .. Last);
   end Canonicalize;

   function Extension_Start (Item : String) return Natural is
      Subtag_First : Positive := Item'First;
   begin
      if Item'Length = 0 then
         return 0;
      end if;

      for Index in Item'Range loop
         if Item (Index) = '-' then
            if Index - Subtag_First = 1 then
               return Subtag_First;
            end if;
            Subtag_First := Index + 1;
         end if;
      end loop;

      if Item'Last - Subtag_First + 1 = 1 then
         return Subtag_First;
      end if;

      return 0;
   end Extension_Start;

   function Base_Locale (Item : String) return String is
      Ext : constant Natural := Extension_Start (Item);
   begin
      if Ext = 0 then
         return Item;
      elsif Ext = Item'First then
         return "";
      else
         return Item (Item'First .. Ext - 2);
      end if;
   end Base_Locale;

   function Base_Name
     (Item : Locale_Id)
      return String
   is
   begin
      return Base_Locale (Canonicalize (Item));
   end Base_Name;

   function Language
     (Item : Locale_Id)
      return String
   is
      Base : constant String := Base_Name (Item);
   begin
      if Base'Length = 0 then
         return "";
      end if;

      for Index in Base'Range loop
         if Base (Index) = '-' then
            if Index = Base'First then
               return "";
            else
               return Base (Base'First .. Index - 1);
            end if;
         end if;
      end loop;

      return Base;
   end Language;

   function Component
     (Item : Locale_Id;
      Want_Script : Boolean)
      return String
   is
      Base  : constant String := Base_Name (Item);
      Start : Positive;
      Order : Natural := 0;
   begin
      if Base'Length = 0 then
         return "";
      end if;

      Start := Base'First;
      while Start <= Base'Last loop
         declare
            Finish : Natural := Base'Last;
         begin
            for Index in Start .. Base'Last loop
               if Base (Index) = '-' then
                  Finish := Index - 1;
                  exit;
               end if;
            end loop;

            Order := Order + 1;
            if Order > 1 then
               declare
                  Part : constant String := Base (Start .. Finish);
               begin
                  if Want_Script
                    and then Part'Length = 4
                    and then All_Alpha_ASCII (Part)
                  then
                     return Part;
                  elsif not Want_Script
                    and then ((Part'Length = 2 and then All_Alpha_ASCII (Part))
                              or else
                                (Part'Length = 3 and then All_Digit_ASCII (Part)))
                  then
                     return Part;
                  end if;
               end;
            end if;

            Start := Finish + 2;
         end;
      end loop;

      return "";
   end Component;

   function Script
     (Item : Locale_Id)
      return String
   is
   begin
      return Component (Item, True);
   end Script;

   function Region
     (Item : Locale_Id)
      return String
   is
   begin
      return Component (Item, False);
   end Region;

   function Name_Input_Component
     (Item : Locale_Id;
      Kind : Character)
      return String
   is
      Canonical : constant String := Canonicalize (Item);
      Base      : constant String := Base_Locale (Canonical);
   begin
      if Base'Length = 0 then
         return "";
      elsif Kind = 'L' then
         if Base'Length = 2 or else Base'Length = 3 then
            return Language_Alias (Base);
         else
            return Language (Base);
         end if;
      elsif Kind = 'S' then
         if Base'Length = 4 and then All_Alpha_ASCII (Base) then
            return Title_ASCII (Base);
         else
            return Script (Base);
         end if;
      else
         if (Base'Length = 2 and then All_Alpha_ASCII (Base))
           or else (Base'Length = 3 and then All_Digit_ASCII (Base))
         then
            return (if All_Alpha_ASCII (Base) then Upper_ASCII (Base) else Base);
         else
            return Region (Base);
         end if;
      end if;
   end Name_Input_Component;

   function Language_Display_Name
     (Item : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'L');
   begin
      if Code = "af" then
         return "Afrikaans";
      elsif Code = "ar" then
         return "Arabic";
      elsif Code = "az" then
         return "Azerbaijani";
      elsif Code = "bg" then
         return "Bulgarian";
      elsif Code = "bn" then
         return "Bengali";
      elsif Code = "ca" then
         return "Catalan";
      elsif Code = "cs" then
         return "Czech";
      elsif Code = "da" then
         return "Danish";
      elsif Code = "de" then
         return "German";
      elsif Code = "el" then
         return "Greek";
      elsif Code = "en" then
         return "English";
      elsif Code = "eo" then
         return "Esperanto";
      elsif Code = "es" then
         return "Spanish";
      elsif Code = "eu" then
         return "Basque";
      elsif Code = "fa" then
         return "Persian";
      elsif Code = "fi" then
         return "Finnish";
      elsif Code = "fr" then
         return "French";
      elsif Code = "he" then
         return "Hebrew";
      elsif Code = "hi" then
         return "Hindi";
      elsif Code = "hu" then
         return "Hungarian";
      elsif Code = "id" then
         return "Indonesian";
      elsif Code = "it" then
         return "Italian";
      elsif Code = "ja" then
         return "Japanese";
      elsif Code = "ko" then
         return "Korean";
      elsif Code = "lt" then
         return "Lithuanian";
      elsif Code = "ms" then
         return "Malay";
      elsif Code = "nl" then
         return "Dutch";
      elsif Code = "no" then
         return "Norwegian";
      elsif Code = "pl" then
         return "Polish";
      elsif Code = "pt" then
         return "Portuguese";
      elsif Code = "ps" then
         return "Pashto";
      elsif Code = "ro" then
         return "Romanian";
      elsif Code = "ru" then
         return "Russian";
      elsif Code = "sd" then
         return "Sindhi";
      elsif Code = "sk" then
         return "Slovak";
      elsif Code = "sl" then
         return "Slovenian";
      elsif Code = "sr" then
         return "Serbian";
      elsif Code = "sv" then
         return "Swedish";
      elsif Code = "sw" then
         return "Swahili";
      elsif Code = "th" then
         return "Thai";
      elsif Code = "tr" then
         return "Turkish";
      elsif Code = "ug" then
         return "Uyghur";
      elsif Code = "uk" then
         return "Ukrainian";
      elsif Code = "ur" then
         return "Urdu";
      elsif Code = "vi" then
         return "Vietnamese";
      elsif Code = "yi" then
         return "Yiddish";
      elsif Code = "zh" then
         return "Chinese";
      else
         return Code;
      end if;
   end Language_Display_Name;

   function German_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arabisch";
      elsif Code = "de" then
         return "Deutsch";
      elsif Code = "en" then
         return "Englisch";
      elsif Code = "es" then
         return "Spanisch";
      elsif Code = "fa" then
         return "Persisch";
      elsif Code = "fr" then
         return "Franzoesisch";
      elsif Code = "he" then
         return "Hebraeisch";
      elsif Code = "it" then
         return "Italienisch";
      elsif Code = "ja" then
         return "Japanisch";
      elsif Code = "pt" then
         return "Portugiesisch";
      elsif Code = "ru" then
         return "Russisch";
      elsif Code = "sr" then
         return "Serbisch";
      elsif Code = "tr" then
         return "Tuerkisch";
      elsif Code = "uk" then
         return "Ukrainisch";
      elsif Code = "zh" then
         return "Chinesisch";
      else
         return Language_Display_Name (Code);
      end if;
   end German_Language_Display_Name;

   function French_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabe";
      elsif Code = "de" then
         return "allemand";
      elsif Code = "en" then
         return "anglais";
      elsif Code = "es" then
         return "espagnol";
      elsif Code = "fa" then
         return "persan";
      elsif Code = "fr" then
         return "francais";
      elsif Code = "he" then
         return "hebreu";
      elsif Code = "it" then
         return "italien";
      elsif Code = "ja" then
         return "japonais";
      elsif Code = "pt" then
         return "portugais";
      elsif Code = "ru" then
         return "russe";
      elsif Code = "sr" then
         return "serbe";
      elsif Code = "tr" then
         return "turc";
      elsif Code = "uk" then
         return "ukrainien";
      elsif Code = "zh" then
         return "chinois";
      else
         return Language_Display_Name (Code);
      end if;
   end French_Language_Display_Name;

   function Spanish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabe";
      elsif Code = "de" then
         return "aleman";
      elsif Code = "en" then
         return "ingles";
      elsif Code = "es" then
         return "espanol";
      elsif Code = "fa" then
         return "persa";
      elsif Code = "fr" then
         return "frances";
      elsif Code = "he" then
         return "hebreo";
      elsif Code = "it" then
         return "italiano";
      elsif Code = "ja" then
         return "japones";
      elsif Code = "pt" then
         return "portugues";
      elsif Code = "ru" then
         return "ruso";
      elsif Code = "sr" then
         return "serbio";
      elsif Code = "tr" then
         return "turco";
      elsif Code = "uk" then
         return "ucraniano";
      elsif Code = "zh" then
         return "chino";
      else
         return Language_Display_Name (Code);
      end if;
   end Spanish_Language_Display_Name;

   function Italian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabo";
      elsif Code = "de" then
         return "tedesco";
      elsif Code = "en" then
         return "inglese";
      elsif Code = "es" then
         return "spagnolo";
      elsif Code = "fa" then
         return "persiano";
      elsif Code = "fr" then
         return "francese";
      elsif Code = "he" then
         return "ebraico";
      elsif Code = "it" then
         return "italiano";
      elsif Code = "ja" then
         return "giapponese";
      elsif Code = "pt" then
         return "portoghese";
      elsif Code = "ru" then
         return "russo";
      elsif Code = "sr" then
         return "serbo";
      elsif Code = "tr" then
         return "turco";
      elsif Code = "uk" then
         return "ucraino";
      elsif Code = "zh" then
         return "cinese";
      else
         return Language_Display_Name (Code);
      end if;
   end Italian_Language_Display_Name;

   function Portuguese_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabe";
      elsif Code = "de" then
         return "alemao";
      elsif Code = "en" then
         return "ingles";
      elsif Code = "es" then
         return "espanhol";
      elsif Code = "fa" then
         return "persa";
      elsif Code = "fr" then
         return "frances";
      elsif Code = "he" then
         return "hebraico";
      elsif Code = "it" then
         return "italiano";
      elsif Code = "ja" then
         return "japones";
      elsif Code = "pt" then
         return "portugues";
      elsif Code = "ru" then
         return "russo";
      elsif Code = "sr" then
         return "servio";
      elsif Code = "tr" then
         return "turco";
      elsif Code = "uk" then
         return "ucraniano";
      elsif Code = "zh" then
         return "chines";
      else
         return Language_Display_Name (Code);
      end if;
   end Portuguese_Language_Display_Name;

   function Dutch_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arabisch";
      elsif Code = "de" then
         return "Duits";
      elsif Code = "en" then
         return "Engels";
      elsif Code = "es" then
         return "Spaans";
      elsif Code = "fa" then
         return "Perzisch";
      elsif Code = "fr" then
         return "Frans";
      elsif Code = "he" then
         return "Hebreeuws";
      elsif Code = "it" then
         return "Italiaans";
      elsif Code = "ja" then
         return "Japans";
      elsif Code = "pt" then
         return "Portugees";
      elsif Code = "ru" then
         return "Russisch";
      elsif Code = "sr" then
         return "Servisch";
      elsif Code = "tr" then
         return "Turks";
      elsif Code = "uk" then
         return "Oekraiens";
      elsif Code = "zh" then
         return "Chinees";
      else
         return Language_Display_Name (Code);
      end if;
   end Dutch_Language_Display_Name;

   function Polish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabski";
      elsif Code = "de" then
         return "niemiecki";
      elsif Code = "en" then
         return "angielski";
      elsif Code = "es" then
         return "hiszpanski";
      elsif Code = "fa" then
         return "perski";
      elsif Code = "fr" then
         return "francuski";
      elsif Code = "he" then
         return "hebrajski";
      elsif Code = "it" then
         return "wloski";
      elsif Code = "ja" then
         return "japonski";
      elsif Code = "pt" then
         return "portugalski";
      elsif Code = "ru" then
         return "rosyjski";
      elsif Code = "sr" then
         return "serbski";
      elsif Code = "tr" then
         return "turecki";
      elsif Code = "uk" then
         return "ukrainski";
      elsif Code = "zh" then
         return "chinski";
      else
         return Language_Display_Name (Code);
      end if;
   end Polish_Language_Display_Name;

   function Czech_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabstina";
      elsif Code = "de" then
         return "nemcina";
      elsif Code = "en" then
         return "anglictina";
      elsif Code = "es" then
         return "spanelstina";
      elsif Code = "fa" then
         return "perstina";
      elsif Code = "fr" then
         return "francouzstina";
      elsif Code = "he" then
         return "hebrejstina";
      elsif Code = "it" then
         return "italstina";
      elsif Code = "ja" then
         return "japonstina";
      elsif Code = "pt" then
         return "portugalstina";
      elsif Code = "ru" then
         return "rustina";
      elsif Code = "sr" then
         return "srbstina";
      elsif Code = "tr" then
         return "turectina";
      elsif Code = "uk" then
         return "ukrajinstina";
      elsif Code = "zh" then
         return "cinstina";
      else
         return Language_Display_Name (Code);
      end if;
   end Czech_Language_Display_Name;

   function Russian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabskiy";
      elsif Code = "de" then
         return "nemetskiy";
      elsif Code = "en" then
         return "angliyskiy";
      elsif Code = "es" then
         return "ispanskiy";
      elsif Code = "fa" then
         return "persidskiy";
      elsif Code = "fr" then
         return "frantsuzskiy";
      elsif Code = "he" then
         return "ivrit";
      elsif Code = "it" then
         return "italyanskiy";
      elsif Code = "ja" then
         return "yaponskiy";
      elsif Code = "pt" then
         return "portugalskiy";
      elsif Code = "ru" then
         return "russkiy";
      elsif Code = "sr" then
         return "serbskiy";
      elsif Code = "tr" then
         return "turetskiy";
      elsif Code = "uk" then
         return "ukrainskiy";
      elsif Code = "zh" then
         return "kitayskiy";
      else
         return Language_Display_Name (Code);
      end if;
   end Russian_Language_Display_Name;

   function Turkish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arapca";
      elsif Code = "de" then
         return "Almanca";
      elsif Code = "en" then
         return "Ingilizce";
      elsif Code = "es" then
         return "Ispanyolca";
      elsif Code = "fa" then
         return "Farsca";
      elsif Code = "fr" then
         return "Fransizca";
      elsif Code = "he" then
         return "Ibranice";
      elsif Code = "it" then
         return "Italyanca";
      elsif Code = "ja" then
         return "Japonca";
      elsif Code = "pt" then
         return "Portekizce";
      elsif Code = "ru" then
         return "Rusca";
      elsif Code = "sr" then
         return "Sirpca";
      elsif Code = "tr" then
         return "Turkce";
      elsif Code = "uk" then
         return "Ukraynaca";
      elsif Code = "zh" then
         return "Cince";
      else
         return Language_Display_Name (Code);
      end if;
   end Turkish_Language_Display_Name;

   function Swedish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabiska";
      elsif Code = "de" then
         return "tyska";
      elsif Code = "en" then
         return "engelska";
      elsif Code = "es" then
         return "spanska";
      elsif Code = "fa" then
         return "persiska";
      elsif Code = "fr" then
         return "franska";
      elsif Code = "he" then
         return "hebreiska";
      elsif Code = "it" then
         return "italienska";
      elsif Code = "ja" then
         return "japanska";
      elsif Code = "pt" then
         return "portugisiska";
      elsif Code = "ru" then
         return "ryska";
      elsif Code = "sr" then
         return "serbiska";
      elsif Code = "tr" then
         return "turkiska";
      elsif Code = "uk" then
         return "ukrainska";
      elsif Code = "zh" then
         return "kinesiska";
      else
         return Language_Display_Name (Code);
      end if;
   end Swedish_Language_Display_Name;

   function Danish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabisk";
      elsif Code = "de" then
         return "tysk";
      elsif Code = "en" then
         return "engelsk";
      elsif Code = "es" then
         return "spansk";
      elsif Code = "fa" then
         return "persisk";
      elsif Code = "fr" then
         return "fransk";
      elsif Code = "he" then
         return "hebraisk";
      elsif Code = "it" then
         return "italiensk";
      elsif Code = "ja" then
         return "japansk";
      elsif Code = "pt" then
         return "portugisisk";
      elsif Code = "ru" then
         return "russisk";
      elsif Code = "sr" then
         return "serbisk";
      elsif Code = "tr" then
         return "tyrkisk";
      elsif Code = "uk" then
         return "ukrainsk";
      elsif Code = "zh" then
         return "kinesisk";
      else
         return Language_Display_Name (Code);
      end if;
   end Danish_Language_Display_Name;

   function Finnish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabia";
      elsif Code = "de" then
         return "saksa";
      elsif Code = "en" then
         return "englanti";
      elsif Code = "es" then
         return "espanja";
      elsif Code = "fa" then
         return "persia";
      elsif Code = "fr" then
         return "ranska";
      elsif Code = "he" then
         return "heprea";
      elsif Code = "it" then
         return "italia";
      elsif Code = "ja" then
         return "japani";
      elsif Code = "pt" then
         return "portugali";
      elsif Code = "ru" then
         return "venaja";
      elsif Code = "sr" then
         return "serbia";
      elsif Code = "tr" then
         return "turkki";
      elsif Code = "uk" then
         return "ukraina";
      elsif Code = "zh" then
         return "kiina";
      else
         return Language_Display_Name (Code);
      end if;
   end Finnish_Language_Display_Name;

   function Norwegian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabisk";
      elsif Code = "de" then
         return "tysk";
      elsif Code = "en" then
         return "engelsk";
      elsif Code = "es" then
         return "spansk";
      elsif Code = "fa" then
         return "persisk";
      elsif Code = "fr" then
         return "fransk";
      elsif Code = "he" then
         return "hebraisk";
      elsif Code = "it" then
         return "italiensk";
      elsif Code = "ja" then
         return "japansk";
      elsif Code = "pt" then
         return "portugisisk";
      elsif Code = "ru" then
         return "russisk";
      elsif Code = "sr" then
         return "serbisk";
      elsif Code = "tr" then
         return "tyrkisk";
      elsif Code = "uk" then
         return "ukrainsk";
      elsif Code = "zh" then
         return "kinesisk";
      else
         return Language_Display_Name (Code);
      end if;
   end Norwegian_Language_Display_Name;

   function Indonesian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arab";
      elsif Code = "de" then
         return "Jerman";
      elsif Code = "en" then
         return "Inggris";
      elsif Code = "es" then
         return "Spanyol";
      elsif Code = "fa" then
         return "Persia";
      elsif Code = "fr" then
         return "Prancis";
      elsif Code = "he" then
         return "Ibrani";
      elsif Code = "it" then
         return "Italia";
      elsif Code = "ja" then
         return "Jepang";
      elsif Code = "pt" then
         return "Portugis";
      elsif Code = "ru" then
         return "Rusia";
      elsif Code = "sr" then
         return "Serbia";
      elsif Code = "tr" then
         return "Turki";
      elsif Code = "uk" then
         return "Ukraina";
      elsif Code = "zh" then
         return "Tionghoa";
      else
         return Language_Display_Name (Code);
      end if;
   end Indonesian_Language_Display_Name;

   function Malay_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arab";
      elsif Code = "de" then
         return "Jerman";
      elsif Code = "en" then
         return "Inggeris";
      elsif Code = "es" then
         return "Sepanyol";
      elsif Code = "fa" then
         return "Parsi";
      elsif Code = "fr" then
         return "Perancis";
      elsif Code = "he" then
         return "Ibrani";
      elsif Code = "it" then
         return "Itali";
      elsif Code = "ja" then
         return "Jepun";
      elsif Code = "pt" then
         return "Portugis";
      elsif Code = "ru" then
         return "Rusia";
      elsif Code = "sr" then
         return "Serbia";
      elsif Code = "tr" then
         return "Turki";
      elsif Code = "uk" then
         return "Ukraine";
      elsif Code = "zh" then
         return "Cina";
      else
         return Language_Display_Name (Code);
      end if;
   end Malay_Language_Display_Name;

   function Esperanto_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "araba";
      elsif Code = "de" then
         return "germana";
      elsif Code = "en" then
         return "angla";
      elsif Code = "es" then
         return "hispana";
      elsif Code = "fa" then
         return "persa";
      elsif Code = "fr" then
         return "franca";
      elsif Code = "he" then
         return "hebrea";
      elsif Code = "it" then
         return "itala";
      elsif Code = "ja" then
         return "japana";
      elsif Code = "pt" then
         return "portugala";
      elsif Code = "ru" then
         return "rusa";
      elsif Code = "sr" then
         return "serba";
      elsif Code = "tr" then
         return "turka";
      elsif Code = "uk" then
         return "ukraina";
      elsif Code = "zh" then
         return "china";
      else
         return Language_Display_Name (Code);
      end if;
   end Esperanto_Language_Display_Name;

   function Vietnamese_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "A Rap";
      elsif Code = "de" then
         return "Duc";
      elsif Code = "en" then
         return "Anh";
      elsif Code = "es" then
         return "Tay Ban Nha";
      elsif Code = "fa" then
         return "Ba Tu";
      elsif Code = "fr" then
         return "Phap";
      elsif Code = "he" then
         return "Do Thai";
      elsif Code = "it" then
         return "Y";
      elsif Code = "ja" then
         return "Nhat";
      elsif Code = "pt" then
         return "Bo Dao Nha";
      elsif Code = "ru" then
         return "Nga";
      elsif Code = "sr" then
         return "Serbia";
      elsif Code = "tr" then
         return "Tho Nhi Ky";
      elsif Code = "uk" then
         return "Ukraina";
      elsif Code = "zh" then
         return "Trung";
      else
         return Language_Display_Name (Code);
      end if;
   end Vietnamese_Language_Display_Name;

   function Swahili_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Kiarabu";
      elsif Code = "de" then
         return "Kijerumani";
      elsif Code = "en" then
         return "Kiingereza";
      elsif Code = "es" then
         return "Kihispania";
      elsif Code = "fa" then
         return "Kiajemi";
      elsif Code = "fr" then
         return "Kifaransa";
      elsif Code = "he" then
         return "Kiebrania";
      elsif Code = "it" then
         return "Kiitaliano";
      elsif Code = "ja" then
         return "Kijapani";
      elsif Code = "pt" then
         return "Kireno";
      elsif Code = "ru" then
         return "Kirusi";
      elsif Code = "sr" then
         return "Kiserbia";
      elsif Code = "tr" then
         return "Kituruki";
      elsif Code = "uk" then
         return "Kiukraini";
      elsif Code = "zh" then
         return "Kichina";
      else
         return Language_Display_Name (Code);
      end if;
   end Swahili_Language_Display_Name;

   function Afrikaans_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "Arabies";
      elsif Code = "de" then
         return "Duits";
      elsif Code = "en" then
         return "Engels";
      elsif Code = "es" then
         return "Spaans";
      elsif Code = "fa" then
         return "Persies";
      elsif Code = "fr" then
         return "Frans";
      elsif Code = "he" then
         return "Hebreeus";
      elsif Code = "it" then
         return "Italiaans";
      elsif Code = "ja" then
         return "Japannees";
      elsif Code = "pt" then
         return "Portugees";
      elsif Code = "ru" then
         return "Russies";
      elsif Code = "sr" then
         return "Serwies";
      elsif Code = "tr" then
         return "Turks";
      elsif Code = "uk" then
         return "Oekraiens";
      elsif Code = "zh" then
         return "Chinees";
      else
         return Language_Display_Name (Code);
      end if;
   end Afrikaans_Language_Display_Name;

   function Basque_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabiera";
      elsif Code = "de" then
         return "alemana";
      elsif Code = "en" then
         return "ingelesa";
      elsif Code = "es" then
         return "gaztelania";
      elsif Code = "fa" then
         return "pertsiera";
      elsif Code = "fr" then
         return "frantsesa";
      elsif Code = "he" then
         return "hebreera";
      elsif Code = "it" then
         return "italiera";
      elsif Code = "ja" then
         return "japoniera";
      elsif Code = "pt" then
         return "portugesa";
      elsif Code = "ru" then
         return "errusiera";
      elsif Code = "sr" then
         return "serbiera";
      elsif Code = "tr" then
         return "turkiera";
      elsif Code = "uk" then
         return "ukrainera";
      elsif Code = "zh" then
         return "txinera";
      else
         return Language_Display_Name (Code);
      end if;
   end Basque_Language_Display_Name;

   function Romanian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "araba";
      elsif Code = "de" then
         return "germana";
      elsif Code = "en" then
         return "engleza";
      elsif Code = "es" then
         return "spaniola";
      elsif Code = "fa" then
         return "persana";
      elsif Code = "fr" then
         return "franceza";
      elsif Code = "he" then
         return "ebraica";
      elsif Code = "it" then
         return "italiana";
      elsif Code = "ja" then
         return "japoneza";
      elsif Code = "pt" then
         return "portugheza";
      elsif Code = "ru" then
         return "rusa";
      elsif Code = "sr" then
         return "sarba";
      elsif Code = "tr" then
         return "turca";
      elsif Code = "uk" then
         return "ucraineana";
      elsif Code = "zh" then
         return "chineza";
      else
         return Language_Display_Name (Code);
      end if;
   end Romanian_Language_Display_Name;

   function Lithuanian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabu";
      elsif Code = "de" then
         return "vokieciu";
      elsif Code = "en" then
         return "anglu";
      elsif Code = "es" then
         return "ispanu";
      elsif Code = "fa" then
         return "persu";
      elsif Code = "fr" then
         return "prancuzu";
      elsif Code = "he" then
         return "hebraju";
      elsif Code = "it" then
         return "italu";
      elsif Code = "ja" then
         return "japonu";
      elsif Code = "pt" then
         return "portugalu";
      elsif Code = "ru" then
         return "rusu";
      elsif Code = "sr" then
         return "serbu";
      elsif Code = "tr" then
         return "turku";
      elsif Code = "uk" then
         return "ukrainieciu";
      elsif Code = "zh" then
         return "kinu";
      else
         return Language_Display_Name (Code);
      end if;
   end Lithuanian_Language_Display_Name;

   function Slovenian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabscina";
      elsif Code = "de" then
         return "nemscina";
      elsif Code = "en" then
         return "anglescina";
      elsif Code = "es" then
         return "spanscina";
      elsif Code = "fa" then
         return "perzijscina";
      elsif Code = "fr" then
         return "francoscina";
      elsif Code = "he" then
         return "hebrejscina";
      elsif Code = "it" then
         return "italijanscina";
      elsif Code = "ja" then
         return "japonscina";
      elsif Code = "pt" then
         return "portugalscina";
      elsif Code = "ru" then
         return "ruscina";
      elsif Code = "sr" then
         return "srbscina";
      elsif Code = "tr" then
         return "turscina";
      elsif Code = "uk" then
         return "ukrajinscina";
      elsif Code = "zh" then
         return "kitajscina";
      else
         return Language_Display_Name (Code);
      end if;
   end Slovenian_Language_Display_Name;

   function Hungarian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arab";
      elsif Code = "de" then
         return "nemet";
      elsif Code = "en" then
         return "angol";
      elsif Code = "es" then
         return "spanyol";
      elsif Code = "fa" then
         return "perzsa";
      elsif Code = "fr" then
         return "francia";
      elsif Code = "he" then
         return "heber";
      elsif Code = "it" then
         return "olasz";
      elsif Code = "ja" then
         return "japan";
      elsif Code = "pt" then
         return "portugal";
      elsif Code = "ru" then
         return "orosz";
      elsif Code = "sr" then
         return "szerb";
      elsif Code = "tr" then
         return "torok";
      elsif Code = "uk" then
         return "ukran";
      elsif Code = "zh" then
         return "kinai";
      else
         return Language_Display_Name (Code);
      end if;
   end Hungarian_Language_Display_Name;

   function Slovak_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabcina";
      elsif Code = "de" then
         return "nemcina";
      elsif Code = "en" then
         return "anglictina";
      elsif Code = "es" then
         return "spanielcina";
      elsif Code = "fa" then
         return "perzcina";
      elsif Code = "fr" then
         return "francuzstina";
      elsif Code = "he" then
         return "hebrejcina";
      elsif Code = "it" then
         return "taliancina";
      elsif Code = "ja" then
         return "japoncina";
      elsif Code = "pt" then
         return "portugalcina";
      elsif Code = "ru" then
         return "rustina";
      elsif Code = "sr" then
         return "srbcina";
      elsif Code = "tr" then
         return "turectina";
      elsif Code = "uk" then
         return "ukrajincina";
      elsif Code = "zh" then
         return "cinstina";
      else
         return Language_Display_Name (Code);
      end if;
   end Slovak_Language_Display_Name;

   function Bulgarian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabski";
      elsif Code = "de" then
         return "nemski";
      elsif Code = "en" then
         return "angliyski";
      elsif Code = "es" then
         return "ispanski";
      elsif Code = "fa" then
         return "persiyski";
      elsif Code = "fr" then
         return "frenski";
      elsif Code = "he" then
         return "ivrit";
      elsif Code = "it" then
         return "italianski";
      elsif Code = "ja" then
         return "yaponski";
      elsif Code = "pt" then
         return "portugalski";
      elsif Code = "ru" then
         return "ruski";
      elsif Code = "sr" then
         return "srabski";
      elsif Code = "tr" then
         return "turski";
      elsif Code = "uk" then
         return "ukrainski";
      elsif Code = "zh" then
         return "kitayski";
      else
         return Language_Display_Name (Code);
      end if;
   end Bulgarian_Language_Display_Name;

   function Ukrainian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabska";
      elsif Code = "de" then
         return "nimetska";
      elsif Code = "en" then
         return "anhliyska";
      elsif Code = "es" then
         return "ispanska";
      elsif Code = "fa" then
         return "perska";
      elsif Code = "fr" then
         return "frantsuzka";
      elsif Code = "he" then
         return "ivryt";
      elsif Code = "it" then
         return "italiyska";
      elsif Code = "ja" then
         return "yaponska";
      elsif Code = "pt" then
         return "portuhalska";
      elsif Code = "ru" then
         return "rosiyska";
      elsif Code = "sr" then
         return "serbska";
      elsif Code = "tr" then
         return "turetska";
      elsif Code = "uk" then
         return "ukrayinska";
      elsif Code = "zh" then
         return "kytayska";
      else
         return Language_Display_Name (Code);
      end if;
   end Ukrainian_Language_Display_Name;

   function Arabic_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "al-arabiya";
      elsif Code = "de" then
         return "al-almaniya";
      elsif Code = "en" then
         return "al-ingliziya";
      elsif Code = "es" then
         return "al-isbaniya";
      elsif Code = "fa" then
         return "al-farisiya";
      elsif Code = "fr" then
         return "al-faransiya";
      elsif Code = "he" then
         return "al-ibriya";
      elsif Code = "it" then
         return "al-italiya";
      elsif Code = "ja" then
         return "al-yabaniya";
      elsif Code = "pt" then
         return "al-burtughaliya";
      elsif Code = "ru" then
         return "al-rusiya";
      elsif Code = "sr" then
         return "al-sirbiya";
      elsif Code = "tr" then
         return "al-turkiya";
      elsif Code = "uk" then
         return "al-ukraniya";
      elsif Code = "zh" then
         return "al-siniya";
      else
         return Language_Display_Name (Code);
      end if;
   end Arabic_Language_Display_Name;

   function Persian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "de" then
         return "almani";
      elsif Code = "en" then
         return "englisi";
      elsif Code = "es" then
         return "espaniaei";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "fr" then
         return "faranse";
      elsif Code = "he" then
         return "ebri";
      elsif Code = "it" then
         return "italiaei";
      elsif Code = "ja" then
         return "japoni";
      elsif Code = "pt" then
         return "portoghali";
      elsif Code = "ru" then
         return "rusi";
      elsif Code = "sr" then
         return "serbi";
      elsif Code = "tr" then
         return "torki";
      elsif Code = "uk" then
         return "okrayni";
      elsif Code = "zh" then
         return "chini";
      else
         return Language_Display_Name (Code);
      end if;
   end Persian_Language_Display_Name;

   function Thai_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "de" then
         return "yoeraman";
      elsif Code = "en" then
         return "angkrit";
      elsif Code = "es" then
         return "sapen";
      elsif Code = "fa" then
         return "persia";
      elsif Code = "fr" then
         return "farangset";
      elsif Code = "he" then
         return "hibru";
      elsif Code = "it" then
         return "itali";
      elsif Code = "ja" then
         return "yipun";
      elsif Code = "pt" then
         return "protuket";
      elsif Code = "ru" then
         return "ratsia";
      elsif Code = "sr" then
         return "soebia";
      elsif Code = "tr" then
         return "toeki";
      elsif Code = "uk" then
         return "yukren";
      elsif Code = "zh" then
         return "chin";
      else
         return Language_Display_Name (Code);
      end if;
   end Thai_Language_Display_Name;

   function Hindi_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "de" then
         return "jarman";
      elsif Code = "en" then
         return "angrezi";
      elsif Code = "es" then
         return "speni";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "fr" then
         return "fransisi";
      elsif Code = "he" then
         return "hibru";
      elsif Code = "it" then
         return "italvi";
      elsif Code = "ja" then
         return "japani";
      elsif Code = "pt" then
         return "purtagali";
      elsif Code = "ru" then
         return "rusi";
      elsif Code = "sr" then
         return "sarbiayi";
      elsif Code = "tr" then
         return "turki";
      elsif Code = "uk" then
         return "ukreni";
      elsif Code = "zh" then
         return "chini";
      else
         return Language_Display_Name (Code);
      end if;
   end Hindi_Language_Display_Name;

   function Greek_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "aravika";
      elsif Code = "de" then
         return "germanika";
      elsif Code = "en" then
         return "anglika";
      elsif Code = "es" then
         return "ispanika";
      elsif Code = "fa" then
         return "persika";
      elsif Code = "fr" then
         return "gallika";
      elsif Code = "he" then
         return "evraika";
      elsif Code = "it" then
         return "italika";
      elsif Code = "ja" then
         return "iaponika";
      elsif Code = "pt" then
         return "portogalika";
      elsif Code = "ru" then
         return "rosika";
      elsif Code = "sr" then
         return "servika";
      elsif Code = "tr" then
         return "tourkika";
      elsif Code = "uk" then
         return "oukranika";
      elsif Code = "zh" then
         return "kinezika";
      else
         return Language_Display_Name (Code);
      end if;
   end Greek_Language_Display_Name;

   function Hebrew_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "aravit";
      elsif Code = "de" then
         return "germanit";
      elsif Code = "en" then
         return "anglit";
      elsif Code = "es" then
         return "sfaradit";
      elsif Code = "fa" then
         return "parsit";
      elsif Code = "fr" then
         return "tsarfatit";
      elsif Code = "he" then
         return "ivrit";
      elsif Code = "it" then
         return "italkit";
      elsif Code = "ja" then
         return "yapanit";
      elsif Code = "pt" then
         return "portugezit";
      elsif Code = "ru" then
         return "rusit";
      elsif Code = "sr" then
         return "serbit";
      elsif Code = "tr" then
         return "turkit";
      elsif Code = "uk" then
         return "ukrainit";
      elsif Code = "zh" then
         return "sinit";
      else
         return Language_Display_Name (Code);
      end if;
   end Hebrew_Language_Display_Name;

   function Catalan_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arab";
      elsif Code = "ca" then
         return "catala";
      elsif Code = "de" then
         return "alemany";
      elsif Code = "en" then
         return "angles";
      elsif Code = "es" then
         return "espanyol";
      elsif Code = "fa" then
         return "persa";
      elsif Code = "fr" then
         return "frances";
      elsif Code = "he" then
         return "hebreu";
      elsif Code = "it" then
         return "italia";
      elsif Code = "ja" then
         return "japones";
      elsif Code = "ko" then
         return "corea";
      elsif Code = "pt" then
         return "portugues";
      elsif Code = "ru" then
         return "rus";
      elsif Code = "sr" then
         return "serbi";
      elsif Code = "tr" then
         return "turc";
      elsif Code = "uk" then
         return "ucraines";
      elsif Code = "zh" then
         return "xines";
      else
         return Language_Display_Name (Code);
      end if;
   end Catalan_Language_Display_Name;

   function Japanese_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabugo";
      elsif Code = "ca" then
         return "katarangogo";
      elsif Code = "de" then
         return "doitsugo";
      elsif Code = "en" then
         return "eigo";
      elsif Code = "es" then
         return "supeingo";
      elsif Code = "fa" then
         return "perushiago";
      elsif Code = "fr" then
         return "furansugo";
      elsif Code = "he" then
         return "heburaigo";
      elsif Code = "it" then
         return "itariago";
      elsif Code = "ja" then
         return "nihongo";
      elsif Code = "ko" then
         return "kankokugo";
      elsif Code = "pt" then
         return "porutogarugo";
      elsif Code = "ru" then
         return "roshiago";
      elsif Code = "sr" then
         return "serubiago";
      elsif Code = "tr" then
         return "torukogo";
      elsif Code = "uk" then
         return "ukurainago";
      elsif Code = "zh" then
         return "chugokugo";
      else
         return Language_Display_Name (Code);
      end if;
   end Japanese_Language_Display_Name;

   function Chinese_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "alaboyu";
      elsif Code = "ca" then
         return "jialuoluniya yu";
      elsif Code = "de" then
         return "deyu";
      elsif Code = "en" then
         return "yingyu";
      elsif Code = "es" then
         return "xibanyayu";
      elsif Code = "fa" then
         return "bosiyu";
      elsif Code = "fr" then
         return "fayu";
      elsif Code = "he" then
         return "xibolaiyu";
      elsif Code = "it" then
         return "yidaliyu";
      elsif Code = "ja" then
         return "riyu";
      elsif Code = "ko" then
         return "hanyu";
      elsif Code = "pt" then
         return "putaoyayu";
      elsif Code = "ru" then
         return "eyu";
      elsif Code = "sr" then
         return "saierweiyayu";
      elsif Code = "tr" then
         return "tuerqiyu";
      elsif Code = "uk" then
         return "wukelanyu";
      elsif Code = "zh" then
         return "zhongwen";
      else
         return Language_Display_Name (Code);
      end if;
   end Chinese_Language_Display_Name;

   function Korean_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabeo";
      elsif Code = "ca" then
         return "katalloniaeo";
      elsif Code = "de" then
         return "dogireo";
      elsif Code = "en" then
         return "yeongeo";
      elsif Code = "es" then
         return "seupeineo";
      elsif Code = "fa" then
         return "pereusiaeo";
      elsif Code = "fr" then
         return "peullangseueo";
      elsif Code = "he" then
         return "hibeullieo";
      elsif Code = "it" then
         return "italliaeo";
      elsif Code = "ja" then
         return "ilboneo";
      elsif Code = "ko" then
         return "hangugeo";
      elsif Code = "pt" then
         return "poreutugareo";
      elsif Code = "ru" then
         return "reosiaeo";
      elsif Code = "sr" then
         return "seuleubiaeo";
      elsif Code = "tr" then
         return "teoki";
      elsif Code = "uk" then
         return "ukeurainaeo";
      elsif Code = "zh" then
         return "junggugeo";
      else
         return Language_Display_Name (Code);
      end if;
   end Korean_Language_Display_Name;

   function Bengali_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arbi";
      elsif Code = "az" then
         return "azarbaijani";
      elsif Code = "bn" then
         return "bangla";
      elsif Code = "ca" then
         return "katalan";
      elsif Code = "de" then
         return "jarman";
      elsif Code = "en" then
         return "ingreji";
      elsif Code = "es" then
         return "spanish";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "fr" then
         return "farashi";
      elsif Code = "he" then
         return "hibru";
      elsif Code = "hi" then
         return "hindi";
      elsif Code = "it" then
         return "italian";
      elsif Code = "ja" then
         return "japani";
      elsif Code = "ko" then
         return "korean";
      elsif Code = "pt" then
         return "portugij";
      elsif Code = "ru" then
         return "rushi";
      elsif Code = "sr" then
         return "sarbian";
      elsif Code = "tr" then
         return "turki";
      elsif Code = "uk" then
         return "ukrenian";
      elsif Code = "zh" then
         return "china";
      else
         return Language_Display_Name (Code);
      end if;
   end Bengali_Language_Display_Name;

   function Azerbaijani_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "ereb";
      elsif Code = "az" then
         return "azerbaycan";
      elsif Code = "bn" then
         return "benqal";
      elsif Code = "ca" then
         return "katalan";
      elsif Code = "de" then
         return "alman";
      elsif Code = "en" then
         return "ingilis";
      elsif Code = "es" then
         return "ispan";
      elsif Code = "fa" then
         return "fars";
      elsif Code = "fr" then
         return "fransiz";
      elsif Code = "he" then
         return "ivrit";
      elsif Code = "hi" then
         return "hindi";
      elsif Code = "it" then
         return "italyan";
      elsif Code = "ja" then
         return "yapon";
      elsif Code = "ko" then
         return "koreya";
      elsif Code = "pt" then
         return "portuqal";
      elsif Code = "ru" then
         return "rus";
      elsif Code = "sr" then
         return "serb";
      elsif Code = "tr" then
         return "turk";
      elsif Code = "uk" then
         return "ukrayna";
      elsif Code = "zh" then
         return "cin";
      else
         return Language_Display_Name (Code);
      end if;
   end Azerbaijani_Language_Display_Name;

   function Urdu_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "az" then
         return "azarbaijani";
      elsif Code = "bn" then
         return "bangali";
      elsif Code = "ca" then
         return "katalan";
      elsif Code = "de" then
         return "jarman";
      elsif Code = "en" then
         return "angrezi";
      elsif Code = "es" then
         return "hispanvi";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "fr" then
         return "fransisi";
      elsif Code = "he" then
         return "ibrani";
      elsif Code = "hi" then
         return "hindi";
      elsif Code = "it" then
         return "italvi";
      elsif Code = "ja" then
         return "japani";
      elsif Code = "ko" then
         return "koreyai";
      elsif Code = "pt" then
         return "purtagali";
      elsif Code = "ru" then
         return "rusi";
      elsif Code = "sr" then
         return "sarbi";
      elsif Code = "tr" then
         return "turki";
      elsif Code = "uk" then
         return "ukreni";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "yi" then
         return "yiddish";
      elsif Code = "zh" then
         return "chini";
      else
         return Language_Display_Name (Code);
      end if;
   end Urdu_Language_Display_Name;

   function Yiddish_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabish";
      elsif Code = "az" then
         return "azerbaydzhanish";
      elsif Code = "bn" then
         return "bengalish";
      elsif Code = "ca" then
         return "katalanish";
      elsif Code = "de" then
         return "daytsh";
      elsif Code = "en" then
         return "english";
      elsif Code = "es" then
         return "spanish";
      elsif Code = "fa" then
         return "persish";
      elsif Code = "fr" then
         return "frantseyzish";
      elsif Code = "he" then
         return "hebreish";
      elsif Code = "hi" then
         return "hindi";
      elsif Code = "it" then
         return "italyenish";
      elsif Code = "ja" then
         return "yapanish";
      elsif Code = "ko" then
         return "koreish";
      elsif Code = "pt" then
         return "portugizish";
      elsif Code = "ru" then
         return "rusish";
      elsif Code = "sr" then
         return "serbish";
      elsif Code = "tr" then
         return "turkish";
      elsif Code = "uk" then
         return "ukrainish";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "yi" then
         return "yidish";
      elsif Code = "zh" then
         return "khinezish";
      else
         return Language_Display_Name (Code);
      end if;
   end Yiddish_Language_Display_Name;

   function Serbian_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arapski";
      elsif Code = "az" then
         return "azerbejdzanski";
      elsif Code = "bn" then
         return "bengalski";
      elsif Code = "ca" then
         return "katalonski";
      elsif Code = "de" then
         return "nemacki";
      elsif Code = "en" then
         return "engleski";
      elsif Code = "es" then
         return "spanski";
      elsif Code = "fa" then
         return "persijski";
      elsif Code = "fr" then
         return "francuski";
      elsif Code = "he" then
         return "hebrejski";
      elsif Code = "hi" then
         return "hindi";
      elsif Code = "it" then
         return "italijanski";
      elsif Code = "ja" then
         return "japanski";
      elsif Code = "ko" then
         return "korejski";
      elsif Code = "pt" then
         return "portugalski";
      elsif Code = "ru" then
         return "ruski";
      elsif Code = "sr" then
         return "srpski";
      elsif Code = "tr" then
         return "turski";
      elsif Code = "uk" then
         return "ukrajinski";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "yi" then
         return "jidis";
      elsif Code = "zh" then
         return "kineski";
      else
         return Language_Display_Name (Code);
      end if;
   end Serbian_Language_Display_Name;

   function Pashto_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "az" then
         return "azarbaijani";
      elsif Code = "bn" then
         return "bangali";
      elsif Code = "de" then
         return "almani";
      elsif Code = "en" then
         return "inglisi";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "ps" then
         return "pashto";
      elsif Code = "sd" then
         return "sindhi";
      elsif Code = "tr" then
         return "turki";
      elsif Code = "ug" then
         return "uyghur";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "zh" then
         return "chini";
      else
         return Language_Display_Name (Code);
      end if;
   end Pashto_Language_Display_Name;

   function Sindhi_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "arabi";
      elsif Code = "az" then
         return "azarbaijani";
      elsif Code = "bn" then
         return "bangali";
      elsif Code = "de" then
         return "jarman";
      elsif Code = "en" then
         return "angrezi";
      elsif Code = "fa" then
         return "farsi";
      elsif Code = "ps" then
         return "pashto";
      elsif Code = "sd" then
         return "sindhi";
      elsif Code = "tr" then
         return "turki";
      elsif Code = "ug" then
         return "uyghur";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "zh" then
         return "chini";
      else
         return Language_Display_Name (Code);
      end if;
   end Sindhi_Language_Display_Name;

   function Uyghur_Language_Display_Name (Code : String) return String is
   begin
      if Code = "ar" then
         return "erebche";
      elsif Code = "az" then
         return "azerbayjan";
      elsif Code = "bn" then
         return "bengal";
      elsif Code = "de" then
         return "nemis";
      elsif Code = "en" then
         return "ingliz";
      elsif Code = "fa" then
         return "pars";
      elsif Code = "ps" then
         return "pashto";
      elsif Code = "sd" then
         return "sindhi";
      elsif Code = "tr" then
         return "turk";
      elsif Code = "ug" then
         return "uyghur";
      elsif Code = "ur" then
         return "urdu";
      elsif Code = "zh" then
         return "xitay";
      else
         return Language_Display_Name (Code);
      end if;
   end Uyghur_Language_Display_Name;

   function Language_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'L');
   begin
      if Language (Display_Locale) = "de" then
         return German_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "fr" then
         return French_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "es" then
         return Spanish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "it" then
         return Italian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "pt" then
         return Portuguese_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "nl" then
         return Dutch_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "pl" then
         return Polish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "cs" then
         return Czech_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ru" then
         return Russian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "tr" then
         return Turkish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sv" then
         return Swedish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "da" then
         return Danish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "fi" then
         return Finnish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "no" then
         return Norwegian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "id" then
         return Indonesian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ms" then
         return Malay_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "eo" then
         return Esperanto_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "vi" then
         return Vietnamese_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sw" then
         return Swahili_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "af" then
         return Afrikaans_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "eu" then
         return Basque_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ro" then
         return Romanian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "lt" then
         return Lithuanian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sl" then
         return Slovenian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "hu" then
         return Hungarian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sk" then
         return Slovak_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "bg" then
         return Bulgarian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "uk" then
         return Ukrainian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ar" then
         return Arabic_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "fa" then
         return Persian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "th" then
         return Thai_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "hi" then
         return Hindi_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "el" then
         return Greek_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "he" then
         return Hebrew_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ca" then
         return Catalan_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ja" then
         return Japanese_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "zh" then
         return Chinese_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ko" then
         return Korean_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "bn" then
         return Bengali_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "az" then
         return Azerbaijani_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ur" then
         return Urdu_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "yi" then
         return Yiddish_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sr" then
         return Serbian_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ps" then
         return Pashto_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "sd" then
         return Sindhi_Language_Display_Name (Code);
      elsif Language (Display_Locale) = "ug" then
         return Uyghur_Language_Display_Name (Code);
      else
         return Language_Display_Name (Code);
      end if;
   end Language_Display_Name;

   function Script_Display_Name
     (Item : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'S');
   begin
      if Code = "Adlm" then
         return "Adlam";
      elsif Code = "Arab" then
         return "Arabic";
      elsif Code = "Beng" then
         return "Bengali";
      elsif Code = "Cyrl" then
         return "Cyrillic";
      elsif Code = "Deva" then
         return "Devanagari";
      elsif Code = "Grek" then
         return "Greek";
      elsif Code = "Hans" then
         return "Simplified Han";
      elsif Code = "Hant" then
         return "Traditional Han";
      elsif Code = "Hebr" then
         return "Hebrew";
      elsif Code = "Jpan" then
         return "Japanese";
      elsif Code = "Kore" then
         return "Korean";
      elsif Code = "Latn" then
         return "Latin";
      elsif Code = "Mand" then
         return "Mandaic";
      elsif Code = "Mymr" then
         return "Myanmar";
      elsif Code = "Nkoo" then
         return "Nko";
      elsif Code = "Rohg" then
         return "Hanifi Rohingya";
      elsif Code = "Syrc" then
         return "Syriac";
      elsif Code = "Thai" then
         return "Thai";
      elsif Code = "Thaa" then
         return "Thaana";
      else
         return Code;
      end if;
   end Script_Display_Name;

   function German_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arabisch";
      elsif Code = "Cyrl" then
         return "Kyrillisch";
      elsif Code = "Hans" then
         return "Vereinfachtes Han";
      elsif Code = "Hant" then
         return "Traditionelles Han";
      elsif Code = "Hebr" then
         return "Hebraeisch";
      elsif Code = "Latn" then
         return "Lateinisch";
      else
         return Script_Display_Name (Code);
      end if;
   end German_Script_Display_Name;

   function French_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabe";
      elsif Code = "Cyrl" then
         return "cyrillique";
      elsif Code = "Hans" then
         return "han simplifie";
      elsif Code = "Hant" then
         return "han traditionnel";
      elsif Code = "Hebr" then
         return "hebreu";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end French_Script_Display_Name;

   function Spanish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabe";
      elsif Code = "Cyrl" then
         return "cirilico";
      elsif Code = "Hans" then
         return "han simplificado";
      elsif Code = "Hant" then
         return "han tradicional";
      elsif Code = "Hebr" then
         return "hebreo";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Spanish_Script_Display_Name;

   function Italian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabo";
      elsif Code = "Cyrl" then
         return "cirillico";
      elsif Code = "Hans" then
         return "han semplificato";
      elsif Code = "Hant" then
         return "han tradizionale";
      elsif Code = "Hebr" then
         return "ebraico";
      elsif Code = "Latn" then
         return "latino";
      else
         return Script_Display_Name (Code);
      end if;
   end Italian_Script_Display_Name;

   function Portuguese_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabe";
      elsif Code = "Cyrl" then
         return "cirilico";
      elsif Code = "Hans" then
         return "han simplificado";
      elsif Code = "Hant" then
         return "han tradicional";
      elsif Code = "Hebr" then
         return "hebraico";
      elsif Code = "Latn" then
         return "latino";
      else
         return Script_Display_Name (Code);
      end if;
   end Portuguese_Script_Display_Name;

   function Dutch_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arabisch";
      elsif Code = "Cyrl" then
         return "Cyrillisch";
      elsif Code = "Hans" then
         return "vereenvoudigd Han";
      elsif Code = "Hant" then
         return "traditioneel Han";
      elsif Code = "Hebr" then
         return "Hebreeuws";
      elsif Code = "Latn" then
         return "Latijn";
      else
         return Script_Display_Name (Code);
      end if;
   end Dutch_Script_Display_Name;

   function Polish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabski";
      elsif Code = "Cyrl" then
         return "cyrylica";
      elsif Code = "Hans" then
         return "uproszczony han";
      elsif Code = "Hant" then
         return "tradycyjny han";
      elsif Code = "Hebr" then
         return "hebrajski";
      elsif Code = "Latn" then
         return "lacinski";
      else
         return Script_Display_Name (Code);
      end if;
   end Polish_Script_Display_Name;

   function Czech_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabske";
      elsif Code = "Cyrl" then
         return "cyrilice";
      elsif Code = "Hans" then
         return "zjednodusene han";
      elsif Code = "Hant" then
         return "tradicni han";
      elsif Code = "Hebr" then
         return "hebrejske";
      elsif Code = "Latn" then
         return "latinka";
      else
         return Script_Display_Name (Code);
      end if;
   end Czech_Script_Display_Name;

   function Russian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabskaya";
      elsif Code = "Cyrl" then
         return "kirillitsa";
      elsif Code = "Hans" then
         return "uproshchennaya khan";
      elsif Code = "Hant" then
         return "traditsionnaya khan";
      elsif Code = "Hebr" then
         return "evreyskaya";
      elsif Code = "Latn" then
         return "latinitsa";
      else
         return Script_Display_Name (Code);
      end if;
   end Russian_Script_Display_Name;

   function Turkish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arap";
      elsif Code = "Cyrl" then
         return "Kiril";
      elsif Code = "Hans" then
         return "basitlestirilmis Han";
      elsif Code = "Hant" then
         return "geleneksel Han";
      elsif Code = "Hebr" then
         return "Ibrani";
      elsif Code = "Latn" then
         return "Latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Turkish_Script_Display_Name;

   function Swedish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabiska";
      elsif Code = "Cyrl" then
         return "kyrilliska";
      elsif Code = "Hans" then
         return "forenklad han";
      elsif Code = "Hant" then
         return "traditionell han";
      elsif Code = "Hebr" then
         return "hebreiska";
      elsif Code = "Latn" then
         return "latinska";
      else
         return Script_Display_Name (Code);
      end if;
   end Swedish_Script_Display_Name;

   function Danish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabisk";
      elsif Code = "Cyrl" then
         return "kyrillisk";
      elsif Code = "Hans" then
         return "forenklet han";
      elsif Code = "Hant" then
         return "traditionel han";
      elsif Code = "Hebr" then
         return "hebraisk";
      elsif Code = "Latn" then
         return "latinsk";
      else
         return Script_Display_Name (Code);
      end if;
   end Danish_Script_Display_Name;

   function Finnish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabialainen";
      elsif Code = "Cyrl" then
         return "kyrillinen";
      elsif Code = "Hans" then
         return "yksinkertaistettu han";
      elsif Code = "Hant" then
         return "perinteinen han";
      elsif Code = "Hebr" then
         return "heprealainen";
      elsif Code = "Latn" then
         return "latinalainen";
      else
         return Script_Display_Name (Code);
      end if;
   end Finnish_Script_Display_Name;

   function Norwegian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabisk";
      elsif Code = "Cyrl" then
         return "kyrillisk";
      elsif Code = "Hans" then
         return "forenklet han";
      elsif Code = "Hant" then
         return "tradisjonell han";
      elsif Code = "Hebr" then
         return "hebraisk";
      elsif Code = "Latn" then
         return "latinsk";
      else
         return Script_Display_Name (Code);
      end if;
   end Norwegian_Script_Display_Name;

   function Indonesian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arab";
      elsif Code = "Cyrl" then
         return "Sirilik";
      elsif Code = "Hans" then
         return "Han sederhana";
      elsif Code = "Hant" then
         return "Han tradisional";
      elsif Code = "Hebr" then
         return "Ibrani";
      elsif Code = "Latn" then
         return "Latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Indonesian_Script_Display_Name;

   function Malay_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arab";
      elsif Code = "Cyrl" then
         return "Siril";
      elsif Code = "Hans" then
         return "Han ringkas";
      elsif Code = "Hant" then
         return "Han tradisional";
      elsif Code = "Hebr" then
         return "Ibrani";
      elsif Code = "Latn" then
         return "Latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Malay_Script_Display_Name;

   function Esperanto_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "araba";
      elsif Code = "Cyrl" then
         return "cirila";
      elsif Code = "Hans" then
         return "simpligita han";
      elsif Code = "Hant" then
         return "tradicia han";
      elsif Code = "Hebr" then
         return "hebrea";
      elsif Code = "Latn" then
         return "latina";
      else
         return Script_Display_Name (Code);
      end if;
   end Esperanto_Script_Display_Name;

   function Vietnamese_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "A Rap";
      elsif Code = "Cyrl" then
         return "Kirin";
      elsif Code = "Hans" then
         return "Han gian the";
      elsif Code = "Hant" then
         return "Han phun the";
      elsif Code = "Hebr" then
         return "Do Thai";
      elsif Code = "Latn" then
         return "La-tinh";
      else
         return Script_Display_Name (Code);
      end if;
   end Vietnamese_Script_Display_Name;

   function Swahili_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Kiarabu";
      elsif Code = "Cyrl" then
         return "Kisirili";
      elsif Code = "Hans" then
         return "Han rahisi";
      elsif Code = "Hant" then
         return "Han ya jadi";
      elsif Code = "Hebr" then
         return "Kiebrania";
      elsif Code = "Latn" then
         return "Kilatini";
      else
         return Script_Display_Name (Code);
      end if;
   end Swahili_Script_Display_Name;

   function Afrikaans_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "Arabies";
      elsif Code = "Cyrl" then
         return "Cyrillies";
      elsif Code = "Hans" then
         return "vereenvoudigde Han";
      elsif Code = "Hant" then
         return "tradisionele Han";
      elsif Code = "Hebr" then
         return "Hebreeus";
      elsif Code = "Latn" then
         return "Latyn";
      else
         return Script_Display_Name (Code);
      end if;
   end Afrikaans_Script_Display_Name;

   function Basque_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabiarra";
      elsif Code = "Cyrl" then
         return "zirilikoa";
      elsif Code = "Hans" then
         return "han sinplifikatua";
      elsif Code = "Hant" then
         return "han tradizionala";
      elsif Code = "Hebr" then
         return "hebrearra";
      elsif Code = "Latn" then
         return "latina";
      else
         return Script_Display_Name (Code);
      end if;
   end Basque_Script_Display_Name;

   function Romanian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "araba";
      elsif Code = "Cyrl" then
         return "chirilica";
      elsif Code = "Hans" then
         return "han simplificat";
      elsif Code = "Hant" then
         return "han traditional";
      elsif Code = "Hebr" then
         return "ebraica";
      elsif Code = "Latn" then
         return "latina";
      else
         return Script_Display_Name (Code);
      end if;
   end Romanian_Script_Display_Name;

   function Lithuanian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabu";
      elsif Code = "Cyrl" then
         return "kirilica";
      elsif Code = "Hans" then
         return "supaprastinta hanu";
      elsif Code = "Hant" then
         return "tradicine hanu";
      elsif Code = "Hebr" then
         return "hebraju";
      elsif Code = "Latn" then
         return "lotynu";
      else
         return Script_Display_Name (Code);
      end if;
   end Lithuanian_Script_Display_Name;

   function Slovenian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabska";
      elsif Code = "Cyrl" then
         return "cirilica";
      elsif Code = "Hans" then
         return "poenostavljena han";
      elsif Code = "Hant" then
         return "tradicionalna han";
      elsif Code = "Hebr" then
         return "hebrejska";
      elsif Code = "Latn" then
         return "latinica";
      else
         return Script_Display_Name (Code);
      end if;
   end Slovenian_Script_Display_Name;

   function Hungarian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arab";
      elsif Code = "Cyrl" then
         return "cirill";
      elsif Code = "Hans" then
         return "egyszerusitett han";
      elsif Code = "Hant" then
         return "hagyomanyos han";
      elsif Code = "Hebr" then
         return "heber";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Hungarian_Script_Display_Name;

   function Slovak_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabske";
      elsif Code = "Cyrl" then
         return "cyrilika";
      elsif Code = "Hans" then
         return "zjednodusene han";
      elsif Code = "Hant" then
         return "tradicne han";
      elsif Code = "Hebr" then
         return "hebrejske";
      elsif Code = "Latn" then
         return "latinka";
      else
         return Script_Display_Name (Code);
      end if;
   end Slovak_Script_Display_Name;

   function Bulgarian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabska";
      elsif Code = "Cyrl" then
         return "kirilitsa";
      elsif Code = "Hans" then
         return "oprostena han";
      elsif Code = "Hant" then
         return "traditsionna han";
      elsif Code = "Hebr" then
         return "ivrit";
      elsif Code = "Latn" then
         return "latinitsa";
      else
         return Script_Display_Name (Code);
      end if;
   end Bulgarian_Script_Display_Name;

   function Ukrainian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabska";
      elsif Code = "Cyrl" then
         return "kyrylytsia";
      elsif Code = "Hans" then
         return "sproshchena han";
      elsif Code = "Hant" then
         return "tradytsiyna han";
      elsif Code = "Hebr" then
         return "ivryt";
      elsif Code = "Latn" then
         return "latynytsia";
      else
         return Script_Display_Name (Code);
      end if;
   end Ukrainian_Script_Display_Name;

   function Arabic_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "al-arabiya";
      elsif Code = "Cyrl" then
         return "al-kiriliya";
      elsif Code = "Hans" then
         return "han al-mubassata";
      elsif Code = "Hant" then
         return "han al-taqlidiya";
      elsif Code = "Hebr" then
         return "al-ibriya";
      elsif Code = "Latn" then
         return "al-latiniya";
      else
         return Script_Display_Name (Code);
      end if;
   end Arabic_Script_Display_Name;

   function Persian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "han-e sade";
      elsif Code = "Hant" then
         return "han-e sonnati";
      elsif Code = "Hebr" then
         return "ebri";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Persian_Script_Display_Name;

   function Thai_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "akson arap";
      elsif Code = "Cyrl" then
         return "akson sirilik";
      elsif Code = "Hans" then
         return "han baep ngaai";
      elsif Code = "Hant" then
         return "han baep dangdoem";
      elsif Code = "Hebr" then
         return "akson hibru";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Thai_Script_Display_Name;

   function Hindi_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "saral han";
      elsif Code = "Hant" then
         return "paramparik han";
      elsif Code = "Hebr" then
         return "hibru";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Hindi_Script_Display_Name;

   function Greek_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "araviko";
      elsif Code = "Cyrl" then
         return "kyrilliko";
      elsif Code = "Hans" then
         return "aplopoiimeno han";
      elsif Code = "Hant" then
         return "paradosiako han";
      elsif Code = "Hebr" then
         return "evraiko";
      elsif Code = "Latn" then
         return "latiniko";
      else
         return Script_Display_Name (Code);
      end if;
   end Greek_Script_Display_Name;

   function Hebrew_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "aravi";
      elsif Code = "Cyrl" then
         return "kirili";
      elsif Code = "Hans" then
         return "han mefushat";
      elsif Code = "Hant" then
         return "han masorti";
      elsif Code = "Hebr" then
         return "ivri";
      elsif Code = "Latn" then
         return "latini";
      else
         return Script_Display_Name (Code);
      end if;
   end Hebrew_Script_Display_Name;

   function Catalan_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arab";
      elsif Code = "Cyrl" then
         return "cirillic";
      elsif Code = "Hans" then
         return "han simplificat";
      elsif Code = "Hant" then
         return "han tradicional";
      elsif Code = "Hebr" then
         return "hebreu";
      elsif Code = "Latn" then
         return "llati";
      else
         return Script_Display_Name (Code);
      end if;
   end Catalan_Script_Display_Name;

   function Japanese_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabia moji";
      elsif Code = "Cyrl" then
         return "kiriru moji";
      elsif Code = "Hans" then
         return "kantai han";
      elsif Code = "Hant" then
         return "hantai han";
      elsif Code = "Hebr" then
         return "heburaigo moji";
      elsif Code = "Latn" then
         return "raten moji";
      else
         return Script_Display_Name (Code);
      end if;
   end Japanese_Script_Display_Name;

   function Chinese_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "alabo zi";
      elsif Code = "Cyrl" then
         return "xilier zi";
      elsif Code = "Hans" then
         return "jianhua hanzi";
      elsif Code = "Hant" then
         return "fanti hanzi";
      elsif Code = "Hebr" then
         return "xibolai zi";
      elsif Code = "Latn" then
         return "lading zi";
      else
         return Script_Display_Name (Code);
      end if;
   end Chinese_Script_Display_Name;

   function Korean_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabeu munja";
      elsif Code = "Cyrl" then
         return "kirill munja";
      elsif Code = "Hans" then
         return "ganchihwa hanja";
      elsif Code = "Hant" then
         return "jeontong hanja";
      elsif Code = "Hebr" then
         return "hibeuli munja";
      elsif Code = "Latn" then
         return "latin munja";
      else
         return Script_Display_Name (Code);
      end if;
   end Korean_Script_Display_Name;

   function Bengali_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arbi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "sorol han";
      elsif Code = "Hant" then
         return "oitihyabahi han";
      elsif Code = "Hebr" then
         return "hibru";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Bengali_Script_Display_Name;

   function Azerbaijani_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "ereb";
      elsif Code = "Cyrl" then
         return "kiril";
      elsif Code = "Hans" then
         return "sade han";
      elsif Code = "Hant" then
         return "enenevi han";
      elsif Code = "Hebr" then
         return "ivrit";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Azerbaijani_Script_Display_Name;

   function Urdu_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "sada han";
      elsif Code = "Hant" then
         return "riwayati han";
      elsif Code = "Hebr" then
         return "ibrani";
      elsif Code = "Latn" then
         return "latini";
      else
         return Script_Display_Name (Code);
      end if;
   end Urdu_Script_Display_Name;

   function Yiddish_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabish";
      elsif Code = "Cyrl" then
         return "kirillish";
      elsif Code = "Hans" then
         return "vereinfachter han";
      elsif Code = "Hant" then
         return "traditsyoneler han";
      elsif Code = "Hebr" then
         return "hebreish";
      elsif Code = "Latn" then
         return "lataynish";
      else
         return Script_Display_Name (Code);
      end if;
   end Yiddish_Script_Display_Name;

   function Serbian_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arapsko";
      elsif Code = "Cyrl" then
         return "cirilica";
      elsif Code = "Hans" then
         return "pojednostavljeni han";
      elsif Code = "Hant" then
         return "tradicionalni han";
      elsif Code = "Hebr" then
         return "hebrejsko";
      elsif Code = "Latn" then
         return "latinica";
      else
         return Script_Display_Name (Code);
      end if;
   end Serbian_Script_Display_Name;

   function Pashto_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "sada han";
      elsif Code = "Hant" then
         return "riwayati han";
      elsif Code = "Hebr" then
         return "ibrani";
      elsif Code = "Latn" then
         return "latini";
      else
         return Script_Display_Name (Code);
      end if;
   end Pashto_Script_Display_Name;

   function Sindhi_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "arabi";
      elsif Code = "Cyrl" then
         return "sirilik";
      elsif Code = "Hans" then
         return "sado han";
      elsif Code = "Hant" then
         return "riwayati han";
      elsif Code = "Hebr" then
         return "ibrani";
      elsif Code = "Latn" then
         return "latini";
      else
         return Script_Display_Name (Code);
      end if;
   end Sindhi_Script_Display_Name;

   function Uyghur_Script_Display_Name (Code : String) return String is
   begin
      if Code = "Arab" then
         return "ereb";
      elsif Code = "Cyrl" then
         return "kirill";
      elsif Code = "Hans" then
         return "addeylashturulghan han";
      elsif Code = "Hant" then
         return "eneniwi han";
      elsif Code = "Hebr" then
         return "ibrani";
      elsif Code = "Latn" then
         return "latin";
      else
         return Script_Display_Name (Code);
      end if;
   end Uyghur_Script_Display_Name;

   function Script_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'S');
   begin
      if Language (Display_Locale) = "de" then
         return German_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "fr" then
         return French_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "es" then
         return Spanish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "it" then
         return Italian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "pt" then
         return Portuguese_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "nl" then
         return Dutch_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "pl" then
         return Polish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "cs" then
         return Czech_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ru" then
         return Russian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "tr" then
         return Turkish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sv" then
         return Swedish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "da" then
         return Danish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "fi" then
         return Finnish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "no" then
         return Norwegian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "id" then
         return Indonesian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ms" then
         return Malay_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "eo" then
         return Esperanto_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "vi" then
         return Vietnamese_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sw" then
         return Swahili_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "af" then
         return Afrikaans_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "eu" then
         return Basque_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ro" then
         return Romanian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "lt" then
         return Lithuanian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sl" then
         return Slovenian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "hu" then
         return Hungarian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sk" then
         return Slovak_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "bg" then
         return Bulgarian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "uk" then
         return Ukrainian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ar" then
         return Arabic_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "fa" then
         return Persian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "th" then
         return Thai_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "hi" then
         return Hindi_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "el" then
         return Greek_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "he" then
         return Hebrew_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ca" then
         return Catalan_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ja" then
         return Japanese_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "zh" then
         return Chinese_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ko" then
         return Korean_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "bn" then
         return Bengali_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "az" then
         return Azerbaijani_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ur" then
         return Urdu_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "yi" then
         return Yiddish_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sr" then
         return Serbian_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ps" then
         return Pashto_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "sd" then
         return Sindhi_Script_Display_Name (Code);
      elsif Language (Display_Locale) = "ug" then
         return Uyghur_Script_Display_Name (Code);
      else
         return Script_Display_Name (Code);
      end if;
   end Script_Display_Name;

   function Region_Display_Name
     (Item : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'R');
   begin
      if Code = "001" then
         return "World";
      elsif Code = "419" then
         return "Latin America";
      elsif Code = "AF" then
         return "Afghanistan";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "AU" then
         return "Australia";
      elsif Code = "AZ" then
         return "Azerbaijan";
      elsif Code = "BA" then
         return "Bosnia and Herzegovina";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CA" then
         return "Canada";
      elsif Code = "CH" then
         return "Switzerland";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Germany";
      elsif Code = "DK" then
         return "Denmark";
      elsif Code = "EG" then
         return "Egypt";
      elsif Code = "ES" then
         return "Spain";
      elsif Code = "FI" then
         return "Finland";
      elsif Code = "FR" then
         return "France";
      elsif Code = "GB" then
         return "United Kingdom";
      elsif Code = "HK" then
         return "Hong Kong";
      elsif Code = "ID" then
         return "Indonesia";
      elsif Code = "IL" then
         return "Israel";
      elsif Code = "IN" then
         return "India";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italy";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "KR" then
         return "South Korea";
      elsif Code = "MX" then
         return "Mexico";
      elsif Code = "NL" then
         return "Netherlands";
      elsif Code = "NO" then
         return "Norway";
      elsif Code = "PL" then
         return "Poland";
      elsif Code = "PK" then
         return "Pakistan";
      elsif Code = "PT" then
         return "Portugal";
      elsif Code = "RO" then
         return "Romania";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Russia";
      elsif Code = "SE" then
         return "Sweden";
      elsif Code = "TH" then
         return "Thailand";
      elsif Code = "TR" then
         return "Turkey";
      elsif Code = "TW" then
         return "Taiwan";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "United States";
      elsif Code = "UZ" then
         return "Uzbekistan";
      elsif Code = "VN" then
         return "Vietnam";
      else
         return Code;
      end if;
   end Region_Display_Name;

   function German_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Welt";
      elsif Code = "419" then
         return "Lateinamerika";
      elsif Code = "AT" then
         return "Oesterreich";
      elsif Code = "BR" then
         return "Brasilien";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Deutschland";
      elsif Code = "ES" then
         return "Spanien";
      elsif Code = "FR" then
         return "Frankreich";
      elsif Code = "GB" then
         return "Vereinigtes Koenigreich";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italien";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Serbien";
      elsif Code = "RU" then
         return "Russland";
      elsif Code = "TR" then
         return "Tuerkei";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "Vereinigte Staaten";
      else
         return Region_Display_Name (Code);
      end if;
   end German_Region_Display_Name;

   function French_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Monde";
      elsif Code = "419" then
         return "Amerique latine";
      elsif Code = "AT" then
         return "Autriche";
      elsif Code = "BR" then
         return "Bresil";
      elsif Code = "CN" then
         return "Chine";
      elsif Code = "DE" then
         return "Allemagne";
      elsif Code = "ES" then
         return "Espagne";
      elsif Code = "FR" then
         return "France";
      elsif Code = "GB" then
         return "Royaume-Uni";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italie";
      elsif Code = "JP" then
         return "Japon";
      elsif Code = "RS" then
         return "Serbie";
      elsif Code = "RU" then
         return "Russie";
      elsif Code = "TR" then
         return "Turquie";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "Etats-Unis";
      else
         return Region_Display_Name (Code);
      end if;
   end French_Region_Display_Name;

   function Spanish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mundo";
      elsif Code = "419" then
         return "Latinoamerica";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Alemania";
      elsif Code = "ES" then
         return "Espana";
      elsif Code = "FR" then
         return "Francia";
      elsif Code = "GB" then
         return "Reino Unido";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japon";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rusia";
      elsif Code = "TR" then
         return "Turquia";
      elsif Code = "UA" then
         return "Ucrania";
      elsif Code = "US" then
         return "Estados Unidos";
      else
         return Region_Display_Name (Code);
      end if;
   end Spanish_Region_Display_Name;

   function Italian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mondo";
      elsif Code = "419" then
         return "America Latina";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasile";
      elsif Code = "CN" then
         return "Cina";
      elsif Code = "DE" then
         return "Germania";
      elsif Code = "ES" then
         return "Spagna";
      elsif Code = "FR" then
         return "Francia";
      elsif Code = "GB" then
         return "Regno Unito";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Giappone";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Russia";
      elsif Code = "TR" then
         return "Turchia";
      elsif Code = "UA" then
         return "Ucraina";
      elsif Code = "US" then
         return "Stati Uniti";
      else
         return Region_Display_Name (Code);
      end if;
   end Italian_Region_Display_Name;

   function Portuguese_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mundo";
      elsif Code = "419" then
         return "America Latina";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Alemanha";
      elsif Code = "ES" then
         return "Espanha";
      elsif Code = "FR" then
         return "Franca";
      elsif Code = "GB" then
         return "Reino Unido";
      elsif Code = "IR" then
         return "Ira";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japao";
      elsif Code = "RS" then
         return "Servia";
      elsif Code = "RU" then
         return "Russia";
      elsif Code = "TR" then
         return "Turquia";
      elsif Code = "UA" then
         return "Ucrania";
      elsif Code = "US" then
         return "Estados Unidos";
      else
         return Region_Display_Name (Code);
      end if;
   end Portuguese_Region_Display_Name;

   function Dutch_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Wereld";
      elsif Code = "419" then
         return "Latijns-Amerika";
      elsif Code = "AT" then
         return "Oostenrijk";
      elsif Code = "BR" then
         return "Brazilie";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Duitsland";
      elsif Code = "ES" then
         return "Spanje";
      elsif Code = "FR" then
         return "Frankrijk";
      elsif Code = "GB" then
         return "Verenigd Koninkrijk";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italie";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Servie";
      elsif Code = "RU" then
         return "Rusland";
      elsif Code = "TR" then
         return "Turkije";
      elsif Code = "UA" then
         return "Oekraine";
      elsif Code = "US" then
         return "Verenigde Staten";
      else
         return Region_Display_Name (Code);
      end if;
   end Dutch_Region_Display_Name;

   function Polish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Swiat";
      elsif Code = "419" then
         return "Ameryka Lacinska";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brazylia";
      elsif Code = "CN" then
         return "Chiny";
      elsif Code = "DE" then
         return "Niemcy";
      elsif Code = "ES" then
         return "Hiszpania";
      elsif Code = "FR" then
         return "Francja";
      elsif Code = "GB" then
         return "Wielka Brytania";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Wlochy";
      elsif Code = "JP" then
         return "Japonia";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rosja";
      elsif Code = "TR" then
         return "Turcja";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Stany Zjednoczone";
      else
         return Region_Display_Name (Code);
      end if;
   end Polish_Region_Display_Name;

   function Czech_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svet";
      elsif Code = "419" then
         return "Latinska Amerika";
      elsif Code = "AT" then
         return "Rakousko";
      elsif Code = "BR" then
         return "Brazilie";
      elsif Code = "CN" then
         return "Cina";
      elsif Code = "DE" then
         return "Nemecko";
      elsif Code = "ES" then
         return "Spanelsko";
      elsif Code = "FR" then
         return "Francie";
      elsif Code = "GB" then
         return "Spojene kralovstvi";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italie";
      elsif Code = "JP" then
         return "Japonsko";
      elsif Code = "RS" then
         return "Srbsko";
      elsif Code = "RU" then
         return "Rusko";
      elsif Code = "TR" then
         return "Turecko";
      elsif Code = "UA" then
         return "Ukrajina";
      elsif Code = "US" then
         return "Spojene staty";
      else
         return Region_Display_Name (Code);
      end if;
   end Czech_Region_Display_Name;

   function Russian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mir";
      elsif Code = "419" then
         return "Latinskaya Amerika";
      elsif Code = "AT" then
         return "Avstriya";
      elsif Code = "BR" then
         return "Braziliya";
      elsif Code = "CN" then
         return "Kitay";
      elsif Code = "DE" then
         return "Germaniya";
      elsif Code = "ES" then
         return "Ispaniya";
      elsif Code = "FR" then
         return "Frantsiya";
      elsif Code = "GB" then
         return "Velikobritaniya";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italiya";
      elsif Code = "JP" then
         return "Yaponiya";
      elsif Code = "RS" then
         return "Serbiya";
      elsif Code = "RU" then
         return "Rossiya";
      elsif Code = "TR" then
         return "Turtsiya";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Soedinennye Shtaty";
      else
         return Region_Display_Name (Code);
      end if;
   end Russian_Region_Display_Name;

   function Turkish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Dunya";
      elsif Code = "419" then
         return "Latin Amerika";
      elsif Code = "AT" then
         return "Avusturya";
      elsif Code = "BR" then
         return "Brezilya";
      elsif Code = "CN" then
         return "Cin";
      elsif Code = "DE" then
         return "Almanya";
      elsif Code = "ES" then
         return "Ispanya";
      elsif Code = "FR" then
         return "Fransa";
      elsif Code = "GB" then
         return "Birlesik Krallik";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italya";
      elsif Code = "JP" then
         return "Japonya";
      elsif Code = "RS" then
         return "Sirbistan";
      elsif Code = "RU" then
         return "Rusya";
      elsif Code = "TR" then
         return "Turkiye";
      elsif Code = "UA" then
         return "Ukrayna";
      elsif Code = "US" then
         return "Amerika Birlesik Devletleri";
      else
         return Region_Display_Name (Code);
      end if;
   end Turkish_Region_Display_Name;

   function Swedish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Varlden";
      elsif Code = "419" then
         return "Latinamerika";
      elsif Code = "AT" then
         return "Osterrike";
      elsif Code = "BR" then
         return "Brasilien";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Tyskland";
      elsif Code = "ES" then
         return "Spanien";
      elsif Code = "FR" then
         return "Frankrike";
      elsif Code = "GB" then
         return "Storbritannien";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italien";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Serbien";
      elsif Code = "RU" then
         return "Ryssland";
      elsif Code = "TR" then
         return "Turkiet";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "USA";
      else
         return Region_Display_Name (Code);
      end if;
   end Swedish_Region_Display_Name;

   function Danish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Verden";
      elsif Code = "419" then
         return "Latinamerika";
      elsif Code = "AT" then
         return "Ostrig";
      elsif Code = "BR" then
         return "Brasilien";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Tyskland";
      elsif Code = "ES" then
         return "Spanien";
      elsif Code = "FR" then
         return "Frankrig";
      elsif Code = "GB" then
         return "Storbritannien";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italien";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Serbien";
      elsif Code = "RU" then
         return "Rusland";
      elsif Code = "TR" then
         return "Tyrkiet";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "USA";
      else
         return Region_Display_Name (Code);
      end if;
   end Danish_Region_Display_Name;

   function Finnish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Maailma";
      elsif Code = "419" then
         return "Latinalainen Amerikka";
      elsif Code = "AT" then
         return "Itavalta";
      elsif Code = "BR" then
         return "Brasilia";
      elsif Code = "CN" then
         return "Kiina";
      elsif Code = "DE" then
         return "Saksa";
      elsif Code = "ES" then
         return "Espanja";
      elsif Code = "FR" then
         return "Ranska";
      elsif Code = "GB" then
         return "Yhdistynyt kuningaskunta";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japani";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Venaja";
      elsif Code = "TR" then
         return "Turkki";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Yhdysvallat";
      else
         return Region_Display_Name (Code);
      end if;
   end Finnish_Region_Display_Name;

   function Norwegian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Verden";
      elsif Code = "419" then
         return "Latin-Amerika";
      elsif Code = "AT" then
         return "Osterrike";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Tyskland";
      elsif Code = "ES" then
         return "Spania";
      elsif Code = "FR" then
         return "Frankrike";
      elsif Code = "GB" then
         return "Storbritannia";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Russland";
      elsif Code = "TR" then
         return "Tyrkia";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "USA";
      else
         return Region_Display_Name (Code);
      end if;
   end Norwegian_Region_Display_Name;

   function Indonesian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Dunia";
      elsif Code = "419" then
         return "Amerika Latin";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Jerman";
      elsif Code = "ES" then
         return "Spanyol";
      elsif Code = "FR" then
         return "Prancis";
      elsif Code = "GB" then
         return "Britania Raya";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Jepang";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rusia";
      elsif Code = "TR" then
         return "Turki";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Amerika Serikat";
      else
         return Region_Display_Name (Code);
      end if;
   end Indonesian_Region_Display_Name;

   function Malay_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Dunia";
      elsif Code = "419" then
         return "Amerika Latin";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Jerman";
      elsif Code = "ES" then
         return "Sepanyol";
      elsif Code = "FR" then
         return "Perancis";
      elsif Code = "GB" then
         return "United Kingdom";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Itali";
      elsif Code = "JP" then
         return "Jepun";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rusia";
      elsif Code = "TR" then
         return "Turki";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "Amerika Syarikat";
      else
         return Region_Display_Name (Code);
      end if;
   end Malay_Region_Display_Name;

   function Esperanto_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mondo";
      elsif Code = "419" then
         return "Latin-Ameriko";
      elsif Code = "AT" then
         return "Austrio";
      elsif Code = "BR" then
         return "Brazilo";
      elsif Code = "CN" then
         return "Chinio";
      elsif Code = "DE" then
         return "Germanio";
      elsif Code = "ES" then
         return "Hispanio";
      elsif Code = "FR" then
         return "Francio";
      elsif Code = "GB" then
         return "Unuiginta Regno";
      elsif Code = "IR" then
         return "Irano";
      elsif Code = "IT" then
         return "Italio";
      elsif Code = "JP" then
         return "Japanio";
      elsif Code = "RS" then
         return "Serbio";
      elsif Code = "RU" then
         return "Rusio";
      elsif Code = "TR" then
         return "Turkio";
      elsif Code = "UA" then
         return "Ukrainio";
      elsif Code = "US" then
         return "Usono";
      else
         return Region_Display_Name (Code);
      end if;
   end Esperanto_Region_Display_Name;

   function Vietnamese_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "The gioi";
      elsif Code = "419" then
         return "My La-tinh";
      elsif Code = "AT" then
         return "Ao";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "Trung Quoc";
      elsif Code = "DE" then
         return "Duc";
      elsif Code = "ES" then
         return "Tay Ban Nha";
      elsif Code = "FR" then
         return "Phap";
      elsif Code = "GB" then
         return "Vuong quoc Anh";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Y";
      elsif Code = "JP" then
         return "Nhat Ban";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Nga";
      elsif Code = "TR" then
         return "Tho Nhi Ky";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Hoa Ky";
      else
         return Region_Display_Name (Code);
      end if;
   end Vietnamese_Region_Display_Name;

   function Swahili_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Dunia";
      elsif Code = "419" then
         return "Amerika ya Kilatini";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Ujerumani";
      elsif Code = "ES" then
         return "Uhispania";
      elsif Code = "FR" then
         return "Ufaransa";
      elsif Code = "GB" then
         return "Uingereza";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japani";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Urusi";
      elsif Code = "TR" then
         return "Uturuki";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Marekani";
      else
         return Region_Display_Name (Code);
      end if;
   end Swahili_Region_Display_Name;

   function Afrikaans_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Wereld";
      elsif Code = "419" then
         return "Latyns-Amerika";
      elsif Code = "AT" then
         return "Oostenryk";
      elsif Code = "BR" then
         return "Brasilie";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Duitsland";
      elsif Code = "ES" then
         return "Spanje";
      elsif Code = "FR" then
         return "Frankryk";
      elsif Code = "GB" then
         return "Verenigde Koninkryk";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italie";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "RS" then
         return "Serbie";
      elsif Code = "RU" then
         return "Rusland";
      elsif Code = "TR" then
         return "Turkye";
      elsif Code = "UA" then
         return "Oekraine";
      elsif Code = "US" then
         return "Verenigde State";
      else
         return Region_Display_Name (Code);
      end if;
   end Afrikaans_Region_Display_Name;

   function Basque_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Mundua";
      elsif Code = "419" then
         return "Latinoamerika";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "Txina";
      elsif Code = "DE" then
         return "Alemania";
      elsif Code = "ES" then
         return "Espainia";
      elsif Code = "FR" then
         return "Frantzia";
      elsif Code = "GB" then
         return "Erresuma Batua";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japonia";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Errusia";
      elsif Code = "TR" then
         return "Turkia";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "AEB";
      else
         return Region_Display_Name (Code);
      end if;
   end Basque_Region_Display_Name;

   function Romanian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Lume";
      elsif Code = "419" then
         return "America Latina";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brazilia";
      elsif Code = "CN" then
         return "China";
      elsif Code = "DE" then
         return "Germania";
      elsif Code = "ES" then
         return "Spania";
      elsif Code = "FR" then
         return "Franta";
      elsif Code = "GB" then
         return "Regatul Unit";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japonia";
      elsif Code = "PT" then
         return "Portugalia";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rusia";
      elsif Code = "TR" then
         return "Turcia";
      elsif Code = "UA" then
         return "Ucraina";
      elsif Code = "US" then
         return "Statele Unite";
      else
         return Region_Display_Name (Code);
      end if;
   end Romanian_Region_Display_Name;

   function Lithuanian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Pasaulis";
      elsif Code = "419" then
         return "Lotynu Amerika";
      elsif Code = "AT" then
         return "Austrija";
      elsif Code = "BR" then
         return "Brazilija";
      elsif Code = "CN" then
         return "Kinija";
      elsif Code = "DE" then
         return "Vokietija";
      elsif Code = "ES" then
         return "Ispanija";
      elsif Code = "FR" then
         return "Prancuzija";
      elsif Code = "GB" then
         return "Jungtine Karalyste";
      elsif Code = "IR" then
         return "Iranas";
      elsif Code = "IT" then
         return "Italija";
      elsif Code = "JP" then
         return "Japonija";
      elsif Code = "PT" then
         return "Portugalija";
      elsif Code = "RS" then
         return "Serbija";
      elsif Code = "RU" then
         return "Rusija";
      elsif Code = "TR" then
         return "Turkija";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Jungtines Valstijos";
      else
         return Region_Display_Name (Code);
      end if;
   end Lithuanian_Region_Display_Name;

   function Slovenian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svet";
      elsif Code = "419" then
         return "Latinska Amerika";
      elsif Code = "AT" then
         return "Avstrija";
      elsif Code = "BR" then
         return "Brazilija";
      elsif Code = "CN" then
         return "Kitajska";
      elsif Code = "DE" then
         return "Nemcija";
      elsif Code = "ES" then
         return "Spanija";
      elsif Code = "FR" then
         return "Francija";
      elsif Code = "GB" then
         return "Zdruzeno kraljestvo";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italija";
      elsif Code = "JP" then
         return "Japonska";
      elsif Code = "PT" then
         return "Portugalska";
      elsif Code = "RS" then
         return "Srbija";
      elsif Code = "RU" then
         return "Rusija";
      elsif Code = "TR" then
         return "Turcija";
      elsif Code = "UA" then
         return "Ukrajina";
      elsif Code = "US" then
         return "Zdruzene drzave";
      else
         return Region_Display_Name (Code);
      end if;
   end Slovenian_Region_Display_Name;

   function Hungarian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Vilag";
      elsif Code = "419" then
         return "Latin-Amerika";
      elsif Code = "AT" then
         return "Ausztria";
      elsif Code = "BR" then
         return "Brazilia";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Nemetorszag";
      elsif Code = "ES" then
         return "Spanyolorszag";
      elsif Code = "FR" then
         return "Franciaorszag";
      elsif Code = "GB" then
         return "Egyesult Kiralysag";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Olaszorszag";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "PT" then
         return "Portugalia";
      elsif Code = "RS" then
         return "Szerbia";
      elsif Code = "RU" then
         return "Oroszorszag";
      elsif Code = "TR" then
         return "Torokorszag";
      elsif Code = "UA" then
         return "Ukrajna";
      elsif Code = "US" then
         return "Egyesult Allamok";
      else
         return Region_Display_Name (Code);
      end if;
   end Hungarian_Region_Display_Name;

   function Slovak_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svet";
      elsif Code = "419" then
         return "Latinska Amerika";
      elsif Code = "AT" then
         return "Rakusko";
      elsif Code = "BR" then
         return "Brazilia";
      elsif Code = "CN" then
         return "Cina";
      elsif Code = "DE" then
         return "Nemecko";
      elsif Code = "ES" then
         return "Spanielsko";
      elsif Code = "FR" then
         return "Francuzsko";
      elsif Code = "GB" then
         return "Spojene kralovstvo";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Taliansko";
      elsif Code = "JP" then
         return "Japonsko";
      elsif Code = "PT" then
         return "Portugalsko";
      elsif Code = "RS" then
         return "Srbsko";
      elsif Code = "RU" then
         return "Rusko";
      elsif Code = "TR" then
         return "Turecko";
      elsif Code = "UA" then
         return "Ukrajina";
      elsif Code = "US" then
         return "Spojene staty";
      else
         return Region_Display_Name (Code);
      end if;
   end Slovak_Region_Display_Name;

   function Bulgarian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svyat";
      elsif Code = "419" then
         return "Latinska Amerika";
      elsif Code = "AT" then
         return "Avstriya";
      elsif Code = "BR" then
         return "Braziliya";
      elsif Code = "CN" then
         return "Kitay";
      elsif Code = "DE" then
         return "Germaniya";
      elsif Code = "ES" then
         return "Ispaniya";
      elsif Code = "FR" then
         return "Frantsiya";
      elsif Code = "GB" then
         return "Obedinoto kralstvo";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italiya";
      elsif Code = "JP" then
         return "Yaponiya";
      elsif Code = "PT" then
         return "Portugaliya";
      elsif Code = "RS" then
         return "Sarbija";
      elsif Code = "RU" then
         return "Rusiya";
      elsif Code = "TR" then
         return "Turtsiya";
      elsif Code = "UA" then
         return "Ukrayna";
      elsif Code = "US" then
         return "Saedinenite shtati";
      else
         return Region_Display_Name (Code);
      end if;
   end Bulgarian_Region_Display_Name;

   function Ukrainian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svit";
      elsif Code = "419" then
         return "Latynska Ameryka";
      elsif Code = "AT" then
         return "Avstriya";
      elsif Code = "BR" then
         return "Brazyliya";
      elsif Code = "CN" then
         return "Kytay";
      elsif Code = "DE" then
         return "Nimechchyna";
      elsif Code = "ES" then
         return "Ispaniya";
      elsif Code = "FR" then
         return "Frantsiya";
      elsif Code = "GB" then
         return "Velyka Brytaniya";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italiya";
      elsif Code = "JP" then
         return "Yaponiya";
      elsif Code = "PT" then
         return "Portuhaliya";
      elsif Code = "RS" then
         return "Serbiya";
      elsif Code = "RU" then
         return "Rosiya";
      elsif Code = "TR" then
         return "Turechchyna";
      elsif Code = "UA" then
         return "Ukrayina";
      elsif Code = "US" then
         return "Spolucheni Shtaty";
      else
         return Region_Display_Name (Code);
      end if;
   end Ukrainian_Region_Display_Name;

   function Arabic_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "al-alam";
      elsif Code = "419" then
         return "Amrika al-Latiniya";
      elsif Code = "AT" then
         return "al-Namsa";
      elsif Code = "BR" then
         return "al-Barazil";
      elsif Code = "CN" then
         return "al-Sin";
      elsif Code = "DE" then
         return "Almanya";
      elsif Code = "ES" then
         return "Isbanya";
      elsif Code = "FR" then
         return "Faransa";
      elsif Code = "GB" then
         return "al-Mamlaka al-Muttahida";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italya";
      elsif Code = "JP" then
         return "al-Yaban";
      elsif Code = "PT" then
         return "al-Burtughal";
      elsif Code = "RS" then
         return "Sirbiya";
      elsif Code = "RU" then
         return "Rusiya";
      elsif Code = "TR" then
         return "Turkiya";
      elsif Code = "UA" then
         return "Ukraniya";
      elsif Code = "US" then
         return "al-Wilayat al-Muttahida";
      else
         return Region_Display_Name (Code);
      end if;
   end Arabic_Region_Display_Name;

   function Persian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "jahan";
      elsif Code = "419" then
         return "Amrikaye Latin";
      elsif Code = "AT" then
         return "Otrish";
      elsif Code = "BR" then
         return "Berazil";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Alman";
      elsif Code = "ES" then
         return "Espania";
      elsif Code = "FR" then
         return "Farance";
      elsif Code = "GB" then
         return "Padeshahi-ye Mottahed";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japon";
      elsif Code = "PT" then
         return "Porteghal";
      elsif Code = "RS" then
         return "Serbi";
      elsif Code = "RU" then
         return "Rusiye";
      elsif Code = "TR" then
         return "Torkiye";
      elsif Code = "UA" then
         return "Okrayn";
      elsif Code = "US" then
         return "Eyatat-e Mottahed";
      else
         return Region_Display_Name (Code);
      end if;
   end Persian_Region_Display_Name;

   function Thai_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "lok";
      elsif Code = "419" then
         return "Amerika Latin";
      elsif Code = "AT" then
         return "Ostria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Yoeramani";
      elsif Code = "ES" then
         return "Sapen";
      elsif Code = "FR" then
         return "Farangset";
      elsif Code = "GB" then
         return "Saharat Anachak";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Itali";
      elsif Code = "JP" then
         return "Yipun";
      elsif Code = "PT" then
         return "Protuket";
      elsif Code = "RS" then
         return "Soebia";
      elsif Code = "RU" then
         return "Ratsia";
      elsif Code = "TR" then
         return "Toeki";
      elsif Code = "UA" then
         return "Yukren";
      elsif Code = "US" then
         return "Saharat";
      else
         return Region_Display_Name (Code);
      end if;
   end Thai_Region_Display_Name;

   function Hindi_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "vishva";
      elsif Code = "419" then
         return "Latin Amerika";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Jarmani";
      elsif Code = "ES" then
         return "Spen";
      elsif Code = "FR" then
         return "Frans";
      elsif Code = "GB" then
         return "United Kingdom";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Itali";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "PT" then
         return "Purtagal";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rus";
      elsif Code = "TR" then
         return "Turkiye";
      elsif Code = "UA" then
         return "Ukren";
      elsif Code = "US" then
         return "Sanyukt Rajya";
      else
         return Region_Display_Name (Code);
      end if;
   end Hindi_Region_Display_Name;

   function Greek_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Kosmos";
      elsif Code = "419" then
         return "Latiniki Ameriki";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Vrazilia";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Germania";
      elsif Code = "ES" then
         return "Ispania";
      elsif Code = "FR" then
         return "Gallia";
      elsif Code = "GB" then
         return "Inomeno Vasileio";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Iaponia";
      elsif Code = "PT" then
         return "Portogalia";
      elsif Code = "RS" then
         return "Servia";
      elsif Code = "RU" then
         return "Rosia";
      elsif Code = "TR" then
         return "Tourkia";
      elsif Code = "UA" then
         return "Oukrania";
      elsif Code = "US" then
         return "Inomenes Politeies";
      else
         return Region_Display_Name (Code);
      end if;
   end Greek_Region_Display_Name;

   function Hebrew_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "olam";
      elsif Code = "419" then
         return "Amerika haLatinit";
      elsif Code = "AT" then
         return "Ostriya";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "Sin";
      elsif Code = "DE" then
         return "Germania";
      elsif Code = "ES" then
         return "Sfarad";
      elsif Code = "FR" then
         return "Tsarfat";
      elsif Code = "GB" then
         return "HaMamlakha HaMeuhedet";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Yapan";
      elsif Code = "PT" then
         return "Portugal";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Rusiya";
      elsif Code = "TR" then
         return "Turkiya";
      elsif Code = "UA" then
         return "Ukraina";
      elsif Code = "US" then
         return "Artsot HaBrit";
      else
         return Region_Display_Name (Code);
      end if;
   end Hebrew_Region_Display_Name;

   function Catalan_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "mon";
      elsif Code = "419" then
         return "America Llatina";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "BR" then
         return "Brasil";
      elsif Code = "CN" then
         return "Xina";
      elsif Code = "DE" then
         return "Alemanya";
      elsif Code = "ES" then
         return "Espanya";
      elsif Code = "FR" then
         return "Franca";
      elsif Code = "GB" then
         return "Regne Unit";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italia";
      elsif Code = "JP" then
         return "Japo";
      elsif Code = "KR" then
         return "Corea del Sud";
      elsif Code = "PT" then
         return "Portugal";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Russia";
      elsif Code = "TR" then
         return "Turquia";
      elsif Code = "UA" then
         return "Ucraina";
      elsif Code = "US" then
         return "Estats Units";
      else
         return Region_Display_Name (Code);
      end if;
   end Catalan_Region_Display_Name;

   function Japanese_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "sekai";
      elsif Code = "419" then
         return "Raten Amerika";
      elsif Code = "AT" then
         return "Osutoria";
      elsif Code = "BR" then
         return "Burajiru";
      elsif Code = "CN" then
         return "Chugoku";
      elsif Code = "DE" then
         return "Doitsu";
      elsif Code = "ES" then
         return "Supein";
      elsif Code = "FR" then
         return "Furansu";
      elsif Code = "GB" then
         return "Igirisu";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Itaria";
      elsif Code = "JP" then
         return "Nihon";
      elsif Code = "KR" then
         return "Kankoku";
      elsif Code = "PT" then
         return "Porutogaru";
      elsif Code = "RS" then
         return "Serubia";
      elsif Code = "RU" then
         return "Roshia";
      elsif Code = "TR" then
         return "Toruko";
      elsif Code = "UA" then
         return "Ukuraina";
      elsif Code = "US" then
         return "Amerika";
      else
         return Region_Display_Name (Code);
      end if;
   end Japanese_Region_Display_Name;

   function Chinese_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "shijie";
      elsif Code = "419" then
         return "Lading Meizhou";
      elsif Code = "AT" then
         return "Aodili";
      elsif Code = "BR" then
         return "Baxi";
      elsif Code = "CN" then
         return "Zhongguo";
      elsif Code = "DE" then
         return "Deguo";
      elsif Code = "ES" then
         return "Xibanya";
      elsif Code = "FR" then
         return "Faguo";
      elsif Code = "GB" then
         return "Yingguo";
      elsif Code = "IR" then
         return "Yilang";
      elsif Code = "IT" then
         return "Yidali";
      elsif Code = "JP" then
         return "Riben";
      elsif Code = "KR" then
         return "Hanguo";
      elsif Code = "PT" then
         return "Putaoya";
      elsif Code = "RS" then
         return "Saierweiya";
      elsif Code = "RU" then
         return "Eluosi";
      elsif Code = "TR" then
         return "Tuerqi";
      elsif Code = "UA" then
         return "Wukelan";
      elsif Code = "US" then
         return "Meiguo";
      else
         return Region_Display_Name (Code);
      end if;
   end Chinese_Region_Display_Name;

   function Korean_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "segye";
      elsif Code = "419" then
         return "Ratein Amerika";
      elsif Code = "AT" then
         return "Oseuteuria";
      elsif Code = "BR" then
         return "Beurajil";
      elsif Code = "CN" then
         return "Jungguk";
      elsif Code = "DE" then
         return "Dogil";
      elsif Code = "ES" then
         return "Seupein";
      elsif Code = "FR" then
         return "Peurangseu";
      elsif Code = "GB" then
         return "Yeongguk";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Itallia";
      elsif Code = "JP" then
         return "Ilbon";
      elsif Code = "KR" then
         return "Hanguk";
      elsif Code = "PT" then
         return "Poreutugal";
      elsif Code = "RS" then
         return "Seleubia";
      elsif Code = "RU" then
         return "Reosia";
      elsif Code = "TR" then
         return "Teoki";
      elsif Code = "UA" then
         return "Ukeuraina";
      elsif Code = "US" then
         return "Miguk";
      else
         return Region_Display_Name (Code);
      end if;
   end Korean_Region_Display_Name;

   function Bengali_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "bishsho";
      elsif Code = "419" then
         return "Latin America";
      elsif Code = "AT" then
         return "Austria";
      elsif Code = "AZ" then
         return "Azarbaijan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "BR" then
         return "Brazil";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Jarmani";
      elsif Code = "ES" then
         return "Spain";
      elsif Code = "FR" then
         return "France";
      elsif Code = "GB" then
         return "Juktorajjo";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italy";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "KR" then
         return "Dakshin Korea";
      elsif Code = "PT" then
         return "Portugal";
      elsif Code = "RS" then
         return "Serbia";
      elsif Code = "RU" then
         return "Russia";
      elsif Code = "TR" then
         return "Turki";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "Juktorastro";
      else
         return Region_Display_Name (Code);
      end if;
   end Bengali_Region_Display_Name;

   function Azerbaijani_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "dunya";
      elsif Code = "419" then
         return "Latin Amerikasi";
      elsif Code = "AT" then
         return "Avstriya";
      elsif Code = "AZ" then
         return "Azerbaycan";
      elsif Code = "BD" then
         return "Banqlades";
      elsif Code = "BR" then
         return "Braziliya";
      elsif Code = "CN" then
         return "Cin";
      elsif Code = "DE" then
         return "Almaniya";
      elsif Code = "ES" then
         return "Ispaniya";
      elsif Code = "FR" then
         return "Fransa";
      elsif Code = "GB" then
         return "Birlashmis Kralliq";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "IT" then
         return "Italiya";
      elsif Code = "JP" then
         return "Yaponiya";
      elsif Code = "KR" then
         return "Cenubi Koreya";
      elsif Code = "PT" then
         return "Portuqaliya";
      elsif Code = "RS" then
         return "Serbiya";
      elsif Code = "RU" then
         return "Rusiya";
      elsif Code = "TR" then
         return "Turkiye";
      elsif Code = "UA" then
         return "Ukrayna";
      elsif Code = "US" then
         return "Amerika Birlashmis Statlari";
      else
         return Region_Display_Name (Code);
      end if;
   end Azerbaijani_Region_Display_Name;

   function Urdu_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "dunya";
      elsif Code = "419" then
         return "Latin America";
      elsif Code = "AZ" then
         return "Azerbaijan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Jarmani";
      elsif Code = "FR" then
         return "France";
      elsif Code = "GB" then
         return "Bartaniya";
      elsif Code = "IL" then
         return "Israel";
      elsif Code = "IN" then
         return "Bharat";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "KR" then
         return "Junubi Korea";
      elsif Code = "RU" then
         return "Rus";
      elsif Code = "TR" then
         return "Turkiya";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "America";
      else
         return Region_Display_Name (Code);
      end if;
   end Urdu_Region_Display_Name;

   function Yiddish_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "velt";
      elsif Code = "419" then
         return "Latayn Amerike";
      elsif Code = "AZ" then
         return "Azerbaydzhan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "CN" then
         return "Khine";
      elsif Code = "DE" then
         return "Daytshland";
      elsif Code = "FR" then
         return "Frankraykh";
      elsif Code = "GB" then
         return "Fareynikte Kenigreyekh";
      elsif Code = "IL" then
         return "Yisroel";
      elsif Code = "IN" then
         return "Indye";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "JP" then
         return "Yapan";
      elsif Code = "KR" then
         return "Koreye";
      elsif Code = "RU" then
         return "Rusland";
      elsif Code = "TR" then
         return "Turkaye";
      elsif Code = "UA" then
         return "Ukraine";
      elsif Code = "US" then
         return "Fareynikte Shtatn";
      else
         return Region_Display_Name (Code);
      end if;
   end Yiddish_Region_Display_Name;

   function Serbian_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "Svet";
      elsif Code = "419" then
         return "Latinska Amerika";
      elsif Code = "AZ" then
         return "Azerbejdzan";
      elsif Code = "BD" then
         return "Banglades";
      elsif Code = "CN" then
         return "Kina";
      elsif Code = "DE" then
         return "Nemacka";
      elsif Code = "FR" then
         return "Francuska";
      elsif Code = "GB" then
         return "Ujedinjeno Kraljevstvo";
      elsif Code = "IL" then
         return "Izrael";
      elsif Code = "IN" then
         return "Indija";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "JP" then
         return "Japan";
      elsif Code = "KR" then
         return "Juzna Koreja";
      elsif Code = "RS" then
         return "Srbija";
      elsif Code = "RU" then
         return "Rusija";
      elsif Code = "TR" then
         return "Turska";
      elsif Code = "UA" then
         return "Ukrajina";
      elsif Code = "US" then
         return "Sjedinjene Drzave";
      else
         return Region_Display_Name (Code);
      end if;
   end Serbian_Region_Display_Name;

   function Pashto_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "nari";
      elsif Code = "419" then
         return "Latin America";
      elsif Code = "AF" then
         return "Afghanistan";
      elsif Code = "AZ" then
         return "Azerbaijan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Alman";
      elsif Code = "GB" then
         return "Bartaniya";
      elsif Code = "IL" then
         return "Israel";
      elsif Code = "IN" then
         return "Hindustan";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "PK" then
         return "Pakistan";
      elsif Code = "TR" then
         return "Turkiya";
      elsif Code = "US" then
         return "America";
      else
         return Region_Display_Name (Code);
      end if;
   end Pashto_Region_Display_Name;

   function Sindhi_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "dunya";
      elsif Code = "419" then
         return "Latin America";
      elsif Code = "AF" then
         return "Afghanistan";
      elsif Code = "AZ" then
         return "Azerbaijan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "CN" then
         return "Chin";
      elsif Code = "DE" then
         return "Jarmani";
      elsif Code = "GB" then
         return "Bartaniya";
      elsif Code = "IL" then
         return "Israel";
      elsif Code = "IN" then
         return "Bharat";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "PK" then
         return "Pakistan";
      elsif Code = "TR" then
         return "Turkiya";
      elsif Code = "US" then
         return "America";
      else
         return Region_Display_Name (Code);
      end if;
   end Sindhi_Region_Display_Name;

   function Uyghur_Region_Display_Name (Code : String) return String is
   begin
      if Code = "001" then
         return "dunya";
      elsif Code = "419" then
         return "Latin Amerikisi";
      elsif Code = "AF" then
         return "Afghanistan";
      elsif Code = "AZ" then
         return "Azerbayjan";
      elsif Code = "BD" then
         return "Bangladesh";
      elsif Code = "CN" then
         return "Xitay";
      elsif Code = "DE" then
         return "Germaniye";
      elsif Code = "GB" then
         return "Britaniye";
      elsif Code = "IL" then
         return "Israel";
      elsif Code = "IN" then
         return "Hindistan";
      elsif Code = "IR" then
         return "Iran";
      elsif Code = "PK" then
         return "Pakistan";
      elsif Code = "TR" then
         return "Turkiye";
      elsif Code = "US" then
         return "Amerika";
      else
         return Region_Display_Name (Code);
      end if;
   end Uyghur_Region_Display_Name;

   function Region_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   is
      Code : constant String := Name_Input_Component (Item, 'R');
   begin
      if Language (Display_Locale) = "de" then
         return German_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "fr" then
         return French_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "es" then
         return Spanish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "it" then
         return Italian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "pt" then
         return Portuguese_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "nl" then
         return Dutch_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "pl" then
         return Polish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "cs" then
         return Czech_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ru" then
         return Russian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "tr" then
         return Turkish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sv" then
         return Swedish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "da" then
         return Danish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "fi" then
         return Finnish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "no" then
         return Norwegian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "id" then
         return Indonesian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ms" then
         return Malay_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "eo" then
         return Esperanto_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "vi" then
         return Vietnamese_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sw" then
         return Swahili_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "af" then
         return Afrikaans_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "eu" then
         return Basque_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ro" then
         return Romanian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "lt" then
         return Lithuanian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sl" then
         return Slovenian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "hu" then
         return Hungarian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sk" then
         return Slovak_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "bg" then
         return Bulgarian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "uk" then
         return Ukrainian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ar" then
         return Arabic_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "fa" then
         return Persian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "th" then
         return Thai_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "hi" then
         return Hindi_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "el" then
         return Greek_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "he" then
         return Hebrew_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ca" then
         return Catalan_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ja" then
         return Japanese_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "zh" then
         return Chinese_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ko" then
         return Korean_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "bn" then
         return Bengali_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "az" then
         return Azerbaijani_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ur" then
         return Urdu_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "yi" then
         return Yiddish_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sr" then
         return Serbian_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ps" then
         return Pashto_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "sd" then
         return Sindhi_Region_Display_Name (Code);
      elsif Language (Display_Locale) = "ug" then
         return Uyghur_Region_Display_Name (Code);
      else
         return Region_Display_Name (Code);
      end if;
   end Region_Display_Name;

   function Display_Name
     (Item : Locale_Id)
      return String
   is
      Lang_Code : constant String := Language (Item);
      Script_Code : constant String := Script (Item);
      Region_Code : constant String := Region (Item);
      Lang_Name : constant String := Language_Display_Name (Lang_Code);
      Script_Name : constant String := Script_Display_Name (Script_Code);
      Region_Name : constant String := Region_Display_Name (Region_Code);
      Qualifier_Length : constant Natural :=
        (if Script_Code'Length > 0 and then Region_Code'Length > 0 then
            Script_Name'Length + Region_Name'Length + 2
         elsif Script_Code'Length > 0 then Script_Name'Length
         elsif Region_Code'Length > 0 then Region_Name'Length
         else 0);
      Result : String (1 .. Natural'Max
        (Lang_Name'Length + Qualifier_Length + 3, 1));
      Last : Natural := 0;

      procedure Append_Text (Text : String) is
      begin
         if Text'Length > 0 then
            Result (Last + 1 .. Last + Text'Length) := Text;
            Last := Last + Text'Length;
         end if;
      end Append_Text;
   begin
      if Lang_Code'Length = 0 then
         return "";
      end if;

      Append_Text (Lang_Name);
      if Qualifier_Length > 0 then
         Append_Text (" (");
         if Script_Code'Length > 0 then
            Append_Text (Script_Name);
            if Region_Code'Length > 0 then
               Append_Text (", ");
            end if;
         end if;
         if Region_Code'Length > 0 then
            Append_Text (Region_Name);
         end if;
         Append_Text (")");
      end if;

      return Result (1 .. Last);
   end Display_Name;

   function Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   is
      Lang_Code : constant String := Language (Item);
      Script_Code : constant String := Script (Item);
      Region_Code : constant String := Region (Item);
      Lang_Name : constant String :=
        Language_Display_Name (Lang_Code, Display_Locale);
      Script_Name : constant String :=
        Script_Display_Name (Script_Code, Display_Locale);
      Region_Name : constant String :=
        Region_Display_Name (Region_Code, Display_Locale);
      Qualifier_Length : constant Natural :=
        (if Script_Code'Length > 0 and then Region_Code'Length > 0 then
            Script_Name'Length + Region_Name'Length + 2
         elsif Script_Code'Length > 0 then Script_Name'Length
         elsif Region_Code'Length > 0 then Region_Name'Length
         else 0);
      Result : String (1 .. Natural'Max
        (Lang_Name'Length + Qualifier_Length + 3, 1));
      Last : Natural := 0;

      procedure Append_Text (Text : String) is
      begin
         if Text'Length > 0 then
            Result (Last + 1 .. Last + Text'Length) := Text;
            Last := Last + Text'Length;
         end if;
      end Append_Text;
   begin
      if Lang_Code'Length = 0 then
         return "";
      end if;

      Append_Text (Lang_Name);
      if Qualifier_Length > 0 then
         Append_Text (" (");
         if Script_Code'Length > 0 then
            Append_Text (Script_Name);
            if Region_Code'Length > 0 then
               Append_Text (", ");
            end if;
         end if;
         if Region_Code'Length > 0 then
            Append_Text (Region_Name);
         end if;
         Append_Text (")");
      end if;

      return Result (1 .. Last);
   end Display_Name;

   function Extension_Locale (Item : String) return String is
      Ext : constant Natural := Extension_Start (Item);
   begin
      if Ext = 0 then
         return "";
      else
         return Item (Ext .. Item'Last);
      end if;
   end Extension_Locale;

   function Is_Unicode_Key (Text : String) return Boolean is
   begin
      if Text'Length /= 2 then
         return False;
      end if;

      for C of Text loop
         if not Is_Alnum_ASCII (C) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Unicode_Key;

   function Unicode_Extension
     (Item : Locale_Id;
      Key  : String)
      return String
   is
      Canonical : constant String := Canonicalize (Item);
      Clean_Key : constant String := Lower_ASCII
        (Ada.Strings.Fixed.Trim (Key, Ada.Strings.Both));
      Result    : String (1 .. Natural'Max (Canonical'Length, 1));
      Last      : Natural := 0;
      Start     : Natural;
      In_U      : Boolean := False;
      Found     : Boolean := False;

      procedure Append_Value (Value : String) is
      begin
         if Last > 0 then
            Last := Last + 1;
            Result (Last) := '-';
         end if;

         if Value'Length > 0 then
            Result (Last + 1 .. Last + Value'Length) := Value;
            Last := Last + Value'Length;
         end if;
      end Append_Value;
   begin
      if Canonical'Length = 0 or else not Is_Unicode_Key (Clean_Key) then
         return "";
      end if;

      Start := Canonical'First;
      while Start <= Canonical'Last loop
         declare
            Finish : Natural := Canonical'Last;
         begin
            for Index in Start .. Canonical'Last loop
               if Canonical (Index) = '-' then
                  Finish := Index - 1;
                  exit;
               end if;
            end loop;

            declare
               Part : constant String := Canonical (Start .. Finish);
            begin
               if not In_U then
                  if Part = "u" then
                     In_U := True;
                  end if;
               elsif Part'Length = 1 then
                  exit;
               elsif Is_Unicode_Key (Part) then
                  if Found then
                     exit;
                  end if;

                  Found := Part = Clean_Key;
                  if Found then
                     Last := 0;
                  end if;
               elsif Found then
                  Append_Value (Part);
               end if;
            end;

            Start := Finish + 2;
         end;
      end loop;

      if not Found then
         return "";
      elsif Last = 0 then
         return "true";
      else
         return Result (1 .. Last);
      end if;
   end Unicode_Extension;

   function Primary_Language (Item : String) return String is
   begin
      return Language (Item);
   end Primary_Language;

   function UTF8_Unit_Length (Text : String; Index : Natural) return Natural;

   function To_Lower
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   is
      Lang : constant String := Primary_Language (Locale);
      Turkic : constant Boolean := Lang = "tr" or else Lang = "az";
      Result : String (1 .. Natural'Max (Text'Length * 2, 1));
      Last   : Natural := 0;
      Index  : Natural := (if Text'Length = 0 then Text'Last + 1
                            else Text'First);

      procedure Append_Byte (Value : Natural)
        with Pre => Value <= 16#FF#
      is
      begin
         Last := Last + 1;
         Result (Last) := Character'Val (Value);
      end Append_Byte;

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Code_Point (Code : Natural)
        with Pre => Code <= 16#FFFF#
      is
      begin
         if Code < 16#80# then
            Append_Byte (Code);
         elsif Code < 16#800# then
            Append_Byte (16#C0# + Code / 64);
            Append_Byte (16#80# + Code mod 64);
         else
            Append_Byte (16#E0# + Code / 4096);
            Append_Byte (16#80# + (Code / 64) mod 64);
            Append_Byte (16#80# + Code mod 64);
         end if;
      end Append_Code_Point;

      procedure Append_Original (Count : Positive) is
      begin
         for Offset in 0 .. Count - 1 loop
            Append_Char (Text (Index + Offset));
         end loop;
      end Append_Original;

      function Is_Combining_Mark_At (Position : Natural) return Boolean is
      begin
         return Position < Text'Last
           and then Character'Pos (Text (Position)) = 16#CC#
           and then Character'Pos (Text (Position + 1)) in 16#80# .. 16#BF#;
      end Is_Combining_Mark_At;

      function Is_Cased_At (Position : Natural) return Boolean is
         B1 : constant Natural := Character'Pos (Text (Position));
         B2 : constant Natural :=
           (if Position < Text'Last then Character'Pos (Text (Position + 1))
            else 0);
         B3 : constant Natural :=
           (if Position + 2 <= Text'Last
            then Character'Pos (Text (Position + 2))
            else 0);
      begin
         if Text (Position) in 'A' .. 'Z'
           or else Text (Position) in 'a' .. 'z'
         then
            return True;
         elsif Position < Text'Last and then B1 = 16#C3# then
            return B2 in 16#80# .. 16#96#
              or else B2 in 16#98# .. 16#B6#
              or else B2 in 16#B8# .. 16#BE#
              or else B2 = 16#BF#;
         elsif Position < Text'Last
           and then (B1 = 16#C4# or else B1 = 16#C5#)
         then
            return True;
         elsif Position < Text'Last and then B1 = 16#CE# then
            return B2 in 16#86# .. 16#8F#
              or else B2 in 16#91# .. 16#A1#
              or else B2 in 16#A3# .. 16#BF#;
         elsif Position < Text'Last and then B1 = 16#CF# then
            return B2 in 16#80# .. 16#8E#;
         elsif Position < Text'Last and then B1 = 16#D0# then
            return B2 = 16#81#
              or else B2 in 16#90# .. 16#BF#;
         elsif Position < Text'Last and then B1 = 16#D1# then
            return B2 in 16#80# .. 16#8F#
              or else B2 = 16#91#;
         elsif Position < Text'Last and then B1 = 16#D4# then
            return B2 in 16#B1# .. 16#BF#;
         elsif Position < Text'Last and then B1 = 16#D5# then
            return B2 in 16#80# .. 16#96#
              or else B2 in 16#A1# .. 16#BF#;
         elsif Position < Text'Last and then B1 = 16#D6# then
            return B2 in 16#80# .. 16#86#;
         elsif Position + 2 <= Text'Last
           and then B1 = 16#E1#
           and then (B2 = 16#82# or else B2 = 16#83# or else B2 = 16#B2#)
         then
            return (B2 = 16#82# and then B3 in 16#A0# .. 16#BF#)
              or else (B2 = 16#83#
                       and then (B3 in 16#80# .. 16#85#
                                 or else B3 = 16#87#
                                 or else B3 = 16#8D#
                                 or else B3 in 16#90# .. 16#BA#
                                 or else B3 in 16#BC# .. 16#BF#))
              or else (B2 = 16#B2# and then B3 in 16#90# .. 16#BF#);
         elsif Position + 2 <= Text'Last
           and then B1 = 16#E2#
           and then B2 = 16#B4#
         then
            return B3 in 16#80# .. 16#A5#
              or else B3 = 16#A7#
              or else B3 = 16#AD#;
         else
            return False;
         end if;
      end Is_Cased_At;

      function Is_Word_Continuing_At (Position : Natural) return Boolean is
      begin
         return Is_Cased_At (Position)
           or else Is_Combining_Mark_At (Position)
           or else Text (Position) in '0' .. '9'
           or else Text (Position) = '_'
           or else Character'Pos (Text (Position)) = 16#27#;
      end Is_Word_Continuing_At;

      function Has_Cased_Before_In_Word (Position : Natural) return Boolean is
         Scan : Natural := Text'First;
         Seen : Boolean := False;
      begin
         while Scan < Position loop
            if Is_Cased_At (Scan) then
               Seen := True;
            elsif not Is_Word_Continuing_At (Scan) then
               Seen := False;
            end if;

            Scan := Scan + UTF8_Unit_Length (Text, Scan);
         end loop;

         return Seen;
      end Has_Cased_Before_In_Word;

      function Has_Cased_After_In_Word (Position : Natural) return Boolean is
         Scan : Natural := Position + 2;
      begin
         while Scan <= Text'Last loop
            if Is_Cased_At (Scan) then
               return True;
            elsif not Is_Word_Continuing_At (Scan) then
               return False;
            end if;

            Scan := Scan + UTF8_Unit_Length (Text, Scan);
         end loop;

         return False;
      end Has_Cased_After_In_Word;

      function Greek_Sigma_Is_Final return Boolean is
      begin
         return Has_Cased_Before_In_Word (Index)
           and then not Has_Cased_After_In_Word (Index);
      end Greek_Sigma_Is_Final;
   begin
      while Index <= Text'Last loop
         declare
            B1 : constant Natural := Character'Pos (Text (Index));
            B2 : constant Natural :=
              (if Index < Text'Last then Character'Pos (Text (Index + 1))
               else 0);
         begin
            if Text (Index) in 'A' .. 'Z' then
               if Turkic and then Text (Index) = 'I' then
                  Append_Code_Point (16#131#);
               else
                  Append_Char (Lower_ASCII (Text (Index)));
               end if;
               Index := Index + 1;
            elsif Index < Text'Last and then B1 = 16#C3# then
               case B2 is
                  when 16#80# .. 16#96# | 16#98# .. 16#9E# =>
                     Append_Byte (B1);
                     Append_Byte (B2 + 32);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#C4# then
               case B2 is
                  when 16#B0# =>
                     Append_Char ('i');
                  when 16#80# | 16#82# | 16#84# | 16#86# | 16#88#
                     | 16#8A# | 16#8C# | 16#8E# | 16#90# | 16#92#
                     | 16#94# | 16#96# | 16#98# | 16#9A# | 16#9C#
                     | 16#9E# | 16#A0# | 16#A2# | 16#A4# | 16#A6#
                     | 16#A8# | 16#AA# | 16#AC# | 16#AE# | 16#B2#
                     | 16#B4# | 16#B6# | 16#B9# | 16#BB# | 16#BD# =>
                     Append_Byte (B1);
                     Append_Byte (B2 + 1);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#C5# then
               case B2 is
                  when 16#81# | 16#83# | 16#85# | 16#87# | 16#8A#
                     | 16#8C# | 16#8E# | 16#90# | 16#94# | 16#96#
                     | 16#98# | 16#9A# | 16#9C# | 16#9E# | 16#A0#
                     | 16#A2# | 16#A4# | 16#A6# | 16#A8# | 16#AA#
                     | 16#AC# | 16#AE# | 16#B0# | 16#B2# | 16#B4#
                     | 16#B6# | 16#B9# | 16#BB# | 16#BD# =>
                     Append_Byte (B1);
                     Append_Byte (B2 + 1);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#CE# then
               case B2 is
                  when 16#86# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AC#);
                  when 16#88# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AD#);
                  when 16#89# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AE#);
                  when 16#8A# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AF#);
                  when 16#8C# =>
                     Append_Byte (16#CF#);
                     Append_Byte (16#8C#);
                  when 16#8E# =>
                     Append_Byte (16#CF#);
                     Append_Byte (16#8D#);
                  when 16#8F# =>
                     Append_Byte (16#CF#);
                     Append_Byte (16#8E#);
                  when 16#91# .. 16#A1# =>
                     Append_Byte (16#CE#);
                     Append_Byte (B2 + 32);
                  when 16#A3# .. 16#A9# =>
                     Append_Byte (16#CF#);
                     if B2 = 16#A3# and then Greek_Sigma_Is_Final then
                        Append_Byte (16#82#);
                     else
                        Append_Byte (B2 - 32);
                     end if;
                  when 16#AA# =>
                     Append_Byte (16#CF#);
                     Append_Byte (16#8A#);
                  when 16#AB# =>
                     Append_Byte (16#CF#);
                     Append_Byte (16#8B#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D0# then
               case B2 is
                  when 16#81# =>
                     Append_Byte (16#D1#);
                     Append_Byte (16#91#);
                  when 16#90# .. 16#9F# =>
                     Append_Byte (16#D0#);
                     Append_Byte (B2 + 32);
                  when 16#A0# .. 16#AF# =>
                     Append_Byte (16#D1#);
                     Append_Byte (B2 - 32);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D4# then
               case B2 is
                  when 16#B1# .. 16#BF# =>
                     Append_Byte (16#D5#);
                     Append_Byte (B2 - 16#10#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D5# then
               case B2 is
                  when 16#80# .. 16#8F# =>
                     Append_Byte (16#D5#);
                     Append_Byte (B2 + 16#30#);
                  when 16#90# .. 16#96# =>
                     Append_Byte (16#D6#);
                     Append_Byte (B2 - 16#10#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index + 2 <= Text'Last
              and then B1 = 16#E1#
              and then B2 = 16#82#
            then
               case Character'Pos (Text (Index + 2)) is
                  when 16#A0# .. 16#BF# =>
                     Append_Code_Point
                       (16#2D00# + Character'Pos (Text (Index + 2)) - 16#A0#);
                  when others =>
                     Append_Original (3);
               end case;
               Index := Index + 3;
            elsif Index + 2 <= Text'Last
              and then B1 = 16#E1#
              and then B2 = 16#83#
            then
               case Character'Pos (Text (Index + 2)) is
                  when 16#80# .. 16#85# =>
                     Append_Code_Point
                       (16#2D20# + Character'Pos (Text (Index + 2)) - 16#80#);
                  when 16#87# =>
                     Append_Code_Point (16#2D27#);
                  when 16#8D# =>
                     Append_Code_Point (16#2D2D#);
                  when others =>
                     Append_Original (3);
               end case;
               Index := Index + 3;
            elsif Index + 2 <= Text'Last
              and then B1 = 16#E1#
              and then B2 = 16#B2#
            then
               case Character'Pos (Text (Index + 2)) is
                  when 16#90# .. 16#BF# =>
                     Append_Byte (16#E1#);
                     Append_Byte (16#83#);
                     Append_Byte (Character'Pos (Text (Index + 2)));
                  when others =>
                     Append_Original (3);
               end case;
               Index := Index + 3;
            else
               Append_Char (Text (Index));
               Index := Index + 1;
            end if;
         end;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end To_Lower;

   function To_Upper
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   is
      Lang : constant String := Primary_Language (Locale);
      Turkic : constant Boolean := Lang = "tr" or else Lang = "az";
      Result : String (1 .. Natural'Max (Text'Length * 3, 1));
      Last   : Natural := 0;
      Index  : Natural := (if Text'Length = 0 then Text'Last + 1
                            else Text'First);

      procedure Append_Byte (Value : Natural)
        with Pre => Value <= 16#FF#
      is
      begin
         Last := Last + 1;
         Result (Last) := Character'Val (Value);
      end Append_Byte;

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Code_Point (Code : Natural)
        with Pre => Code <= 16#FFFF#
      is
      begin
         if Code < 16#80# then
            Append_Byte (Code);
         elsif Code < 16#800# then
            Append_Byte (16#C0# + Code / 64);
            Append_Byte (16#80# + Code mod 64);
         else
            Append_Byte (16#E0# + Code / 4096);
            Append_Byte (16#80# + (Code / 64) mod 64);
            Append_Byte (16#80# + Code mod 64);
         end if;
      end Append_Code_Point;

      procedure Append_Original (Count : Positive) is
      begin
         for Offset in 0 .. Count - 1 loop
            Append_Char (Text (Index + Offset));
         end loop;
      end Append_Original;
   begin
      while Index <= Text'Last loop
         declare
            B1 : constant Natural := Character'Pos (Text (Index));
            B2 : constant Natural :=
              (if Index < Text'Last then Character'Pos (Text (Index + 1))
               else 0);
         begin
            if Text (Index) in 'a' .. 'z' then
               if Turkic and then Text (Index) = 'i' then
                  Append_Code_Point (16#130#);
               else
                  Append_Char (Upper_ASCII (Text (Index)));
               end if;
               Index := Index + 1;
            elsif Index < Text'Last and then B1 = 16#C3# then
               case B2 is
                  when 16#9F# =>
                     Append_Char ('S');
                     Append_Char ('S');
                  when 16#A0# .. 16#B6# | 16#B8# .. 16#BE# =>
                     Append_Byte (B1);
                     Append_Byte (B2 - 32);
                  when 16#BF# =>
                     Append_Byte (16#C5#);
                     Append_Byte (16#B8#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#C4# then
               case B2 is
                  when 16#B1# =>
                     Append_Char ('I');
                  when 16#81# | 16#83# | 16#85# | 16#87# | 16#89#
                     | 16#8B# | 16#8D# | 16#8F# | 16#91# | 16#93#
                     | 16#95# | 16#97# | 16#99# | 16#9B# | 16#9D#
                     | 16#9F# | 16#A1# | 16#A3# | 16#A5# | 16#A7#
                     | 16#A9# | 16#AB# | 16#AD# | 16#AF# | 16#B3#
                     | 16#B5# | 16#B7# | 16#BA# | 16#BC# | 16#BE# =>
                     Append_Byte (B1);
                     Append_Byte (B2 - 1);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#C5# then
               case B2 is
                  when 16#82# | 16#84# | 16#86# | 16#88# | 16#8B#
                     | 16#8D# | 16#8F# | 16#91# | 16#95# | 16#97#
                     | 16#99# | 16#9B# | 16#9D# | 16#9F# | 16#A1#
                     | 16#A3# | 16#A5# | 16#A7# | 16#A9# | 16#AB#
                     | 16#AD# | 16#AF# | 16#B1# | 16#B3# | 16#B5#
                     | 16#B7# | 16#BA# | 16#BC# | 16#BE# =>
                     Append_Byte (B1);
                     Append_Byte (B2 - 1);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#CE# then
               case B2 is
                  when 16#90# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#99#);
                     Append_Byte (16#CC#);
                     Append_Byte (16#88#);
                     Append_Byte (16#CC#);
                     Append_Byte (16#81#);
                  when 16#AC# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#86#);
                  when 16#AD# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#88#);
                  when 16#AE# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#89#);
                  when 16#AF# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#8A#);
                  when 16#B0# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#A5#);
                     Append_Byte (16#CC#);
                     Append_Byte (16#88#);
                     Append_Byte (16#CC#);
                     Append_Byte (16#81#);
                  when 16#B1# .. 16#BF# =>
                     Append_Byte (16#CE#);
                     Append_Byte (B2 - 32);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#CF# then
               case B2 is
                  when 16#82# | 16#83# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#A3#);
                  when 16#8A# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AA#);
                  when 16#8B# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#AB#);
                  when 16#8C# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#8C#);
                  when 16#8D# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#8E#);
                  when 16#8E# =>
                     Append_Byte (16#CE#);
                     Append_Byte (16#8F#);
                  when 16#80# .. 16#81# | 16#84# .. 16#89# =>
                     Append_Byte (16#CE#);
                     Append_Byte (B2 + 32);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D0# then
               case B2 is
                  when 16#B0# .. 16#BF# =>
                     Append_Byte (16#D0#);
                     Append_Byte (B2 - 32);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D1# then
               case B2 is
                  when 16#80# .. 16#8F# =>
                     Append_Byte (16#D0#);
                     Append_Byte (B2 + 32);
                  when 16#91# =>
                     Append_Byte (16#D0#);
                     Append_Byte (16#81#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D5# then
               case B2 is
                  when 16#A1# .. 16#AF# =>
                     Append_Byte (16#D4#);
                     Append_Byte (B2 + 16#10#);
                  when 16#B0# .. 16#BF# =>
                     Append_Byte (16#D5#);
                     Append_Byte (B2 - 16#30#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index < Text'Last and then B1 = 16#D6# then
               case B2 is
                  when 16#80# .. 16#86# =>
                     Append_Byte (16#D5#);
                     Append_Byte (B2 + 16#10#);
                  when others =>
                     Append_Original (2);
               end case;
               Index := Index + 2;
            elsif Index + 2 <= Text'Last
              and then B1 = 16#E1#
              and then B2 = 16#83#
            then
               case Character'Pos (Text (Index + 2)) is
                  when 16#90# .. 16#BF# =>
                     Append_Byte (16#E1#);
                     Append_Byte (16#B2#);
                     Append_Byte (Character'Pos (Text (Index + 2)));
                  when others =>
                     Append_Original (3);
               end case;
               Index := Index + 3;
            elsif Index + 2 <= Text'Last
              and then B1 = 16#E2#
              and then B2 = 16#B4#
            then
               case Character'Pos (Text (Index + 2)) is
                  when 16#80# .. 16#9F# =>
                     Append_Code_Point
                       (16#10A0# + Character'Pos (Text (Index + 2)) - 16#80#);
                  when 16#A0# .. 16#A5# =>
                     Append_Code_Point
                       (16#10C0# + Character'Pos (Text (Index + 2)) - 16#A0#);
                  when 16#A7# =>
                     Append_Code_Point (16#10C7#);
                  when 16#AD# =>
                     Append_Code_Point (16#10CD#);
                  when others =>
                     Append_Original (3);
               end case;
               Index := Index + 3;
            else
               Append_Char (Text (Index));
               Index := Index + 1;
            end if;
         end;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end To_Upper;

   function Normalize_NFC
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Result : String (1 .. Natural'Max (Text'Length, 1));
      Last   : Natural := 0;
      Index  : Natural := (if Text'Length = 0 then Text'Last + 1
                            else Text'First);

      procedure Append_Byte (Value : Natural) is
      begin
         Last := Last + 1;
         Result (Last) := Character'Val (Value);
      end Append_Byte;

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Composed_Code (Code : Natural) is
      begin
         if Code <= 16#FFFF# then
            Append_Byte (Code / 256);
            Append_Byte (Code mod 256);
         else
            Append_Byte (Code / 16#10000#);
            Append_Byte ((Code / 256) mod 256);
            Append_Byte (Code mod 256);
         end if;
      end Append_Composed_Code;

      procedure Append_Original (Count : Positive) is
      begin
         for Offset in 0 .. Count - 1 loop
            Append_Char (Text (Index + Offset));
         end loop;
      end Append_Original;

      function Combining_Tail return Natural is
      begin
         if Index + 2 <= Text'Last
           and then Character'Pos (Text (Index + 1)) = 16#CC#
         then
            return Character'Pos (Text (Index + 2));
         else
            return 0;
         end if;
      end Combining_Tail;

      function Combining_Tail_After_First return Natural is
      begin
         if Index + 4 <= Text'Last
           and then Character'Pos (Text (Index + 3)) = 16#CC#
         then
            return Character'Pos (Text (Index + 4));
         else
            return 0;
         end if;
      end Combining_Tail_After_First;

      function Greek_Combining_Tail return Natural is
      begin
         if Index + 3 <= Text'Last
           and then Character'Pos (Text (Index + 2)) = 16#CC#
         then
            return Character'Pos (Text (Index + 3));
         else
            return 0;
         end if;
      end Greek_Combining_Tail;

      function Greek_Combining_Tail_After_First return Natural is
      begin
         if Index + 5 <= Text'Last
           and then Character'Pos (Text (Index + 4)) = 16#CC#
         then
            return Character'Pos (Text (Index + 5));
         else
            return 0;
         end if;
      end Greek_Combining_Tail_After_First;

      function Composed_Code (Base : Character; Mark : Natural) return Natural is
      begin
         case Base is
            when 'A' =>
               case Mark is
                  when 16#80# => return 16#C380#;
                  when 16#81# => return 16#C381#;
                  when 16#82# => return 16#C382#;
                  when 16#83# => return 16#C383#;
                  when 16#84# => return 16#C480#;
                  when 16#86# => return 16#C482#;
                  when 16#88# => return 16#C384#;
                  when 16#8A# => return 16#C385#;
                  when 16#A3# => return 16#E1BAA0#;
                  when 16#A8# => return 16#C484#;
                  when others => return 0;
               end case;
            when 'C' =>
               case Mark is
                  when 16#81# => return 16#C486#;
                  when 16#87# => return 16#C48A#;
                  when 16#8C# => return 16#C48C#;
                  when 16#A7# => return 16#C387#;
                  when others => return 0;
               end case;
            when 'D' =>
               if Mark = 16#8C# then
                  return 16#C48E#;
               end if;
            when 'E' =>
               case Mark is
                  when 16#80# => return 16#C388#;
                  when 16#81# => return 16#C389#;
                  when 16#82# => return 16#C38A#;
                  when 16#84# => return 16#C492#;
                  when 16#86# => return 16#C494#;
                  when 16#87# => return 16#C496#;
                  when 16#88# => return 16#C38B#;
                  when 16#8C# => return 16#C49A#;
                  when 16#A3# => return 16#E1BAB8#;
                  when 16#A8# => return 16#C498#;
                  when others => return 0;
               end case;
            when 'G' =>
               case Mark is
                  when 16#86# => return 16#C49E#;
                  when 16#87# => return 16#C4A0#;
                  when 16#A7# => return 16#C4A2#;
                  when others => return 0;
               end case;
            when 'I' =>
               case Mark is
                  when 16#80# => return 16#C38C#;
                  when 16#81# => return 16#C38D#;
                  when 16#82# => return 16#C38E#;
                  when 16#84# => return 16#C4AA#;
                  when 16#86# => return 16#C4AC#;
                  when 16#87# => return 16#C4B0#;
                  when 16#88# => return 16#C38F#;
                  when 16#A3# => return 16#E1BB8A#;
                  when 16#A8# => return 16#C4AE#;
                  when others => return 0;
               end case;
            when 'L' =>
               case Mark is
                  when 16#81# => return 16#C4B9#;
                  when 16#A7# => return 16#C4BB#;
                  when 16#8C# => return 16#C4BD#;
                  when others => return 0;
               end case;
            when 'N' =>
               case Mark is
                  when 16#81# => return 16#C583#;
                  when 16#83# => return 16#C391#;
                  when 16#A7# => return 16#C585#;
                  when 16#8C# => return 16#C587#;
                  when others => return 0;
               end case;
            when 'O' =>
               case Mark is
                  when 16#80# => return 16#C392#;
                  when 16#81# => return 16#C393#;
                  when 16#82# => return 16#C394#;
                  when 16#83# => return 16#C395#;
                  when 16#84# => return 16#C58C#;
                  when 16#86# => return 16#C58E#;
                  when 16#88# => return 16#C396#;
                  when 16#9B# => return 16#C6A0#;
                  when 16#A3# => return 16#E1BB8C#;
                  when others => return 0;
               end case;
            when 'R' =>
               case Mark is
                  when 16#81# => return 16#C594#;
                  when 16#A7# => return 16#C596#;
                  when 16#8C# => return 16#C598#;
                  when others => return 0;
               end case;
            when 'S' =>
               case Mark is
                  when 16#81# => return 16#C59A#;
                  when 16#A7# => return 16#C59E#;
                  when 16#8C# => return 16#C5A0#;
                  when others => return 0;
               end case;
            when 'T' =>
               case Mark is
                  when 16#A7# => return 16#C5A2#;
                  when 16#8C# => return 16#C5A4#;
                  when others => return 0;
               end case;
            when 'U' =>
               case Mark is
                  when 16#80# => return 16#C399#;
                  when 16#81# => return 16#C39A#;
                  when 16#82# => return 16#C39B#;
                  when 16#84# => return 16#C5AA#;
                  when 16#86# => return 16#C5AC#;
                  when 16#88# => return 16#C39C#;
                  when 16#9B# => return 16#C6AF#;
                  when 16#A3# => return 16#E1BBA4#;
                  when 16#A8# => return 16#C5B2#;
                  when others => return 0;
               end case;
            when 'Y' =>
               case Mark is
                  when 16#81# => return 16#C39D#;
                  when 16#A3# => return 16#E1BBB4#;
                  when others => return 0;
               end case;
            when 'Z' =>
               case Mark is
                  when 16#81# => return 16#C5B9#;
                  when 16#87# => return 16#C5BB#;
                  when 16#8C# => return 16#C5BD#;
                  when others => return 0;
               end case;
            when 'a' =>
               case Mark is
                  when 16#80# => return 16#C3A0#;
                  when 16#81# => return 16#C3A1#;
                  when 16#82# => return 16#C3A2#;
                  when 16#83# => return 16#C3A3#;
                  when 16#84# => return 16#C481#;
                  when 16#86# => return 16#C483#;
                  when 16#88# => return 16#C3A4#;
                  when 16#8A# => return 16#C3A5#;
                  when 16#A3# => return 16#E1BAA1#;
                  when 16#A8# => return 16#C485#;
                  when others => return 0;
               end case;
            when 'c' =>
               case Mark is
                  when 16#81# => return 16#C487#;
                  when 16#87# => return 16#C48B#;
                  when 16#8C# => return 16#C48D#;
                  when 16#A7# => return 16#C3A7#;
                  when others => return 0;
               end case;
            when 'd' =>
               if Mark = 16#8C# then
                  return 16#C48F#;
               end if;
            when 'e' =>
               case Mark is
                  when 16#80# => return 16#C3A8#;
                  when 16#81# => return 16#C3A9#;
                  when 16#82# => return 16#C3AA#;
                  when 16#84# => return 16#C493#;
                  when 16#86# => return 16#C495#;
                  when 16#87# => return 16#C497#;
                  when 16#88# => return 16#C3AB#;
                  when 16#8C# => return 16#C49B#;
                  when 16#A3# => return 16#E1BAB9#;
                  when 16#A8# => return 16#C499#;
                  when others => return 0;
               end case;
            when 'g' =>
               case Mark is
                  when 16#86# => return 16#C49F#;
                  when 16#87# => return 16#C4A1#;
                  when 16#A7# => return 16#C4A3#;
                  when others => return 0;
               end case;
            when 'i' =>
               case Mark is
                  when 16#80# => return 16#C3AC#;
                  when 16#81# => return 16#C3AD#;
                  when 16#82# => return 16#C3AE#;
                  when 16#84# => return 16#C4AB#;
                  when 16#86# => return 16#C4AD#;
                  when 16#88# => return 16#C3AF#;
                  when 16#A3# => return 16#E1BB8B#;
                  when 16#A8# => return 16#C4AF#;
                  when others => return 0;
               end case;
            when 'l' =>
               case Mark is
                  when 16#81# => return 16#C4BA#;
                  when 16#A7# => return 16#C4BC#;
                  when 16#8C# => return 16#C4BE#;
                  when others => return 0;
               end case;
            when 'n' =>
               case Mark is
                  when 16#81# => return 16#C584#;
                  when 16#83# => return 16#C3B1#;
                  when 16#A7# => return 16#C586#;
                  when 16#8C# => return 16#C588#;
                  when others => return 0;
               end case;
            when 'o' =>
               case Mark is
                  when 16#80# => return 16#C3B2#;
                  when 16#81# => return 16#C3B3#;
                  when 16#82# => return 16#C3B4#;
                  when 16#83# => return 16#C3B5#;
                  when 16#84# => return 16#C58D#;
                  when 16#86# => return 16#C58F#;
                  when 16#88# => return 16#C3B6#;
                  when 16#9B# => return 16#C6A1#;
                  when 16#A3# => return 16#E1BB8D#;
                  when others => return 0;
               end case;
            when 'r' =>
               case Mark is
                  when 16#81# => return 16#C595#;
                  when 16#A7# => return 16#C597#;
                  when 16#8C# => return 16#C599#;
                  when others => return 0;
               end case;
            when 's' =>
               case Mark is
                  when 16#81# => return 16#C59B#;
                  when 16#A7# => return 16#C59F#;
                  when 16#8C# => return 16#C5A1#;
                  when others => return 0;
               end case;
            when 't' =>
               case Mark is
                  when 16#A7# => return 16#C5A3#;
                  when 16#8C# => return 16#C5A5#;
                  when others => return 0;
               end case;
            when 'u' =>
               case Mark is
                  when 16#80# => return 16#C3B9#;
                  when 16#81# => return 16#C3BA#;
                  when 16#82# => return 16#C3BB#;
                  when 16#84# => return 16#C5AB#;
                  when 16#86# => return 16#C5AD#;
                  when 16#88# => return 16#C3BC#;
                  when 16#9B# => return 16#C6B0#;
                  when 16#A3# => return 16#E1BBA5#;
                  when 16#A8# => return 16#C5B3#;
                  when others => return 0;
               end case;
            when 'y' =>
               case Mark is
                  when 16#81# => return 16#C3BD#;
                  when 16#88# => return 16#C3BF#;
                  when 16#A3# => return 16#E1BBB5#;
                  when others => return 0;
               end case;
            when 'z' =>
               case Mark is
                  when 16#81# => return 16#C5BA#;
                  when 16#87# => return 16#C5BC#;
                  when 16#8C# => return 16#C5BE#;
                  when others => return 0;
               end case;
            when others =>
               return 0;
         end case;

         return 0;
      end Composed_Code;

      function Vietnamese_Tone_Code
        (Base : Character;
         Mark : Natural;
         Tone : Natural)
         return Natural
      is
      begin
         case Base is
            when 'A' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BAA4#;
                     when 16#80# => return 16#E1BAA6#;
                     when 16#89# => return 16#E1BAA8#;
                     when 16#83# => return 16#E1BAAA#;
                     when 16#A3# => return 16#E1BAAC#;
                     when others => return 0;
                  end case;
               elsif Mark = 16#86# then
                  case Tone is
                     when 16#81# => return 16#E1BAAE#;
                     when 16#80# => return 16#E1BAB0#;
                     when 16#89# => return 16#E1BAB2#;
                     when 16#83# => return 16#E1BAB4#;
                     when 16#A3# => return 16#E1BAB6#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'a' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BAA5#;
                     when 16#80# => return 16#E1BAA7#;
                     when 16#89# => return 16#E1BAA9#;
                     when 16#83# => return 16#E1BAAB#;
                     when 16#A3# => return 16#E1BAAD#;
                     when others => return 0;
                  end case;
               elsif Mark = 16#86# then
                  case Tone is
                     when 16#81# => return 16#E1BAAF#;
                     when 16#80# => return 16#E1BAB1#;
                     when 16#89# => return 16#E1BAB3#;
                     when 16#83# => return 16#E1BAB5#;
                     when 16#A3# => return 16#E1BAB7#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'E' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BABE#;
                     when 16#80# => return 16#E1BB80#;
                     when 16#89# => return 16#E1BB82#;
                     when 16#83# => return 16#E1BB84#;
                     when 16#A3# => return 16#E1BB86#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'e' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BABF#;
                     when 16#80# => return 16#E1BB81#;
                     when 16#89# => return 16#E1BB83#;
                     when 16#83# => return 16#E1BB85#;
                     when 16#A3# => return 16#E1BB87#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'O' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BB90#;
                     when 16#80# => return 16#E1BB92#;
                     when 16#89# => return 16#E1BB94#;
                     when 16#83# => return 16#E1BB96#;
                     when 16#A3# => return 16#E1BB98#;
                     when others => return 0;
                  end case;
               elsif Mark = 16#9B# then
                  case Tone is
                     when 16#81# => return 16#E1BB9A#;
                     when 16#80# => return 16#E1BB9C#;
                     when 16#89# => return 16#E1BB9E#;
                     when 16#83# => return 16#E1BBA0#;
                     when 16#A3# => return 16#E1BBA2#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'o' =>
               if Mark = 16#82# then
                  case Tone is
                     when 16#81# => return 16#E1BB91#;
                     when 16#80# => return 16#E1BB93#;
                     when 16#89# => return 16#E1BB95#;
                     when 16#83# => return 16#E1BB97#;
                     when 16#A3# => return 16#E1BB99#;
                     when others => return 0;
                  end case;
               elsif Mark = 16#9B# then
                  case Tone is
                     when 16#81# => return 16#E1BB9B#;
                     when 16#80# => return 16#E1BB9D#;
                     when 16#89# => return 16#E1BB9F#;
                     when 16#83# => return 16#E1BBA1#;
                     when 16#A3# => return 16#E1BBA3#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'U' =>
               if Mark = 16#9B# then
                  case Tone is
                     when 16#81# => return 16#E1BBA8#;
                     when 16#80# => return 16#E1BBAA#;
                     when 16#89# => return 16#E1BBAC#;
                     when 16#83# => return 16#E1BBAE#;
                     when 16#A3# => return 16#E1BBB0#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when 'u' =>
               if Mark = 16#9B# then
                  case Tone is
                     when 16#81# => return 16#E1BBA9#;
                     when 16#80# => return 16#E1BBAB#;
                     when 16#89# => return 16#E1BBAD#;
                     when 16#83# => return 16#E1BBAF#;
                     when 16#A3# => return 16#E1BBB1#;
                     when others => return 0;
                  end case;
               else
                  return 0;
               end if;
            when others =>
               return 0;
         end case;
      end Vietnamese_Tone_Code;

      function Greek_Composed_Code
        (Lead : Natural;
         Tail : Natural;
         Mark : Natural;
         Tone : Natural)
         return Natural
      is
      begin
         if Mark = 16#81# and then Tone = 0 then
            if Lead = 16#CE# then
               case Tail is
                  when 16#91# => return 16#CE86#;
                  when 16#95# => return 16#CE88#;
                  when 16#97# => return 16#CE89#;
                  when 16#99# => return 16#CE8A#;
                  when 16#9F# => return 16#CE8C#;
                  when 16#A5# => return 16#CE8E#;
                  when 16#A9# => return 16#CE8F#;
                  when 16#B1# => return 16#CEAC#;
                  when 16#B5# => return 16#CEAD#;
                  when 16#B7# => return 16#CEAE#;
                  when 16#B9# => return 16#CEAF#;
                  when 16#BF# => return 16#CF8C#;
                  when others => return 0;
               end case;
            elsif Lead = 16#CF# then
               case Tail is
                  when 16#85# => return 16#CF8D#;
                  when 16#89# => return 16#CF8E#;
                  when others => return 0;
               end case;
            end if;
         elsif Mark = 16#88# then
            if Lead = 16#CE# then
               case Tail is
                  when 16#99# =>
                     return (if Tone = 16#81# then 0 else 16#CEAA#);
                  when 16#A5# =>
                     return (if Tone = 16#81# then 0 else 16#CEAB#);
                  when 16#B9# =>
                     return (if Tone = 16#81# then 16#CE90# else 16#CF8A#);
                  when others =>
                     return 0;
               end case;
            elsif Lead = 16#CF# and then Tail = 16#85# then
               return (if Tone = 16#81# then 16#CEB0# else 16#CF8B#);
            end if;
         end if;

         return 0;
      end Greek_Composed_Code;
   begin
      while Index <= Text'Last loop
         if Text (Index) in 'A' .. 'Z' or else Text (Index) in 'a' .. 'z' then
            declare
               Mark : constant Natural := Combining_Tail;
               Tone : constant Natural := Combining_Tail_After_First;
               Tone_Code : constant Natural :=
                 Vietnamese_Tone_Code (Text (Index), Mark, Tone);
               Code : constant Natural :=
                 (if Tone_Code /= 0
                  then Tone_Code
                  else Composed_Code (Text (Index), Mark));
            begin
               if Code /= 0 then
                  Append_Composed_Code (Code);
                  if Tone_Code /= 0 then
                     Index := Index + 5;
                  else
                     Index := Index + 3;
                  end if;
               else
                  Append_Char (Text (Index));
                  Index := Index + 1;
               end if;
            end;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) in 16#CE# | 16#CF#
         then
            declare
               Code : constant Natural :=
                 Greek_Composed_Code
                   (Character'Pos (Text (Index)),
                    Character'Pos (Text (Index + 1)),
                    Greek_Combining_Tail,
                    Greek_Combining_Tail_After_First);
            begin
               if Code /= 0 then
                  Append_Composed_Code (Code);
                  if Greek_Combining_Tail_After_First /= 0 then
                     Index := Index + 6;
                  else
                     Index := Index + 4;
                  end if;
               else
                  Append_Original (2);
                  Index := Index + 2;
               end if;
            end;
         else
            Append_Original (UTF8_Unit_Length (Text, Index));
            Index := Index + UTF8_Unit_Length (Text, Index);
         end if;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end Normalize_NFC;

   function Normalize_NFD
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Result : String (1 .. Natural'Max (Text'Length * 3, 1));
      Last   : Natural := 0;
      Index  : Natural := (if Text'Length = 0 then Text'Last + 1
                            else Text'First);

      procedure Append_Byte (Value : Natural) is
      begin
         Last := Last + 1;
         Result (Last) := Character'Val (Value);
      end Append_Byte;

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Combining (Tail : Natural) is
      begin
         Append_Byte (16#CC#);
         Append_Byte (Tail);
      end Append_Combining;

      procedure Append_Decomposed (Base : Character; Mark : Natural) is
      begin
         Append_Char (Base);
         Append_Combining (Mark);
      end Append_Decomposed;

      procedure Append_Decomposed_2
        (Base  : Character;
         First : Natural;
         Last_Mark  : Natural)
      is
      begin
         Append_Char (Base);
         Append_Combining (First);
         Append_Combining (Last_Mark);
      end Append_Decomposed_2;

      procedure Append_Decomposed_UTF8
        (Lead : Natural;
         Tail : Natural;
         Mark : Natural)
      is
      begin
         Append_Byte (Lead);
         Append_Byte (Tail);
         Append_Combining (Mark);
      end Append_Decomposed_UTF8;

      procedure Append_Decomposed_UTF8_2
        (Lead : Natural;
         Tail : Natural;
         First : Natural;
         Last_Mark : Natural)
      is
      begin
         Append_Byte (Lead);
         Append_Byte (Tail);
         Append_Combining (First);
         Append_Combining (Last_Mark);
      end Append_Decomposed_UTF8_2;

      procedure Append_Original (Count : Positive) is
      begin
         for Offset in 0 .. Count - 1 loop
            Append_Char (Text (Index + Offset));
         end loop;
      end Append_Original;
   begin
      while Index <= Text'Last loop
         if Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#CE#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#86# => Append_Decomposed_UTF8 (16#CE#, 16#91#, 16#81#);
               when 16#88# => Append_Decomposed_UTF8 (16#CE#, 16#95#, 16#81#);
               when 16#89# => Append_Decomposed_UTF8 (16#CE#, 16#97#, 16#81#);
               when 16#8A# => Append_Decomposed_UTF8 (16#CE#, 16#99#, 16#81#);
               when 16#8C# => Append_Decomposed_UTF8 (16#CE#, 16#9F#, 16#81#);
               when 16#8E# => Append_Decomposed_UTF8 (16#CE#, 16#A5#, 16#81#);
               when 16#8F# => Append_Decomposed_UTF8 (16#CE#, 16#A9#, 16#81#);
               when 16#90# =>
                  Append_Decomposed_UTF8_2 (16#CE#, 16#B9#, 16#88#, 16#81#);
               when 16#AA# => Append_Decomposed_UTF8 (16#CE#, 16#99#, 16#88#);
               when 16#AB# => Append_Decomposed_UTF8 (16#CE#, 16#A5#, 16#88#);
               when 16#AC# => Append_Decomposed_UTF8 (16#CE#, 16#B1#, 16#81#);
               when 16#AD# => Append_Decomposed_UTF8 (16#CE#, 16#B5#, 16#81#);
               when 16#AE# => Append_Decomposed_UTF8 (16#CE#, 16#B7#, 16#81#);
               when 16#AF# => Append_Decomposed_UTF8 (16#CE#, 16#B9#, 16#81#);
               when 16#B0# =>
                  Append_Decomposed_UTF8_2 (16#CF#, 16#85#, 16#88#, 16#81#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#CF#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#8A# => Append_Decomposed_UTF8 (16#CE#, 16#B9#, 16#88#);
               when 16#8B# => Append_Decomposed_UTF8 (16#CF#, 16#85#, 16#88#);
               when 16#8C# => Append_Decomposed_UTF8 (16#CE#, 16#BF#, 16#81#);
               when 16#8D# => Append_Decomposed_UTF8 (16#CF#, 16#85#, 16#81#);
               when 16#8E# => Append_Decomposed_UTF8 (16#CF#, 16#89#, 16#81#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C3#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#80# => Append_Decomposed ('A', 16#80#);
               when 16#81# => Append_Decomposed ('A', 16#81#);
               when 16#82# => Append_Decomposed ('A', 16#82#);
               when 16#83# => Append_Decomposed ('A', 16#83#);
               when 16#84# => Append_Decomposed ('A', 16#88#);
               when 16#85# => Append_Decomposed ('A', 16#8A#);
               when 16#87# => Append_Decomposed ('C', 16#A7#);
               when 16#88# => Append_Decomposed ('E', 16#80#);
               when 16#89# => Append_Decomposed ('E', 16#81#);
               when 16#8A# => Append_Decomposed ('E', 16#82#);
               when 16#8B# => Append_Decomposed ('E', 16#88#);
               when 16#8C# => Append_Decomposed ('I', 16#80#);
               when 16#8D# => Append_Decomposed ('I', 16#81#);
               when 16#8E# => Append_Decomposed ('I', 16#82#);
               when 16#8F# => Append_Decomposed ('I', 16#88#);
               when 16#91# => Append_Decomposed ('N', 16#83#);
               when 16#92# => Append_Decomposed ('O', 16#80#);
               when 16#93# => Append_Decomposed ('O', 16#81#);
               when 16#94# => Append_Decomposed ('O', 16#82#);
               when 16#95# => Append_Decomposed ('O', 16#83#);
               when 16#96# => Append_Decomposed ('O', 16#88#);
               when 16#99# => Append_Decomposed ('U', 16#80#);
               when 16#9A# => Append_Decomposed ('U', 16#81#);
               when 16#9B# => Append_Decomposed ('U', 16#82#);
               when 16#9C# => Append_Decomposed ('U', 16#88#);
               when 16#9D# => Append_Decomposed ('Y', 16#81#);
               when 16#A0# => Append_Decomposed ('a', 16#80#);
               when 16#A1# => Append_Decomposed ('a', 16#81#);
               when 16#A2# => Append_Decomposed ('a', 16#82#);
               when 16#A3# => Append_Decomposed ('a', 16#83#);
               when 16#A4# => Append_Decomposed ('a', 16#88#);
               when 16#A5# => Append_Decomposed ('a', 16#8A#);
               when 16#A7# => Append_Decomposed ('c', 16#A7#);
               when 16#A8# => Append_Decomposed ('e', 16#80#);
               when 16#A9# => Append_Decomposed ('e', 16#81#);
               when 16#AA# => Append_Decomposed ('e', 16#82#);
               when 16#AB# => Append_Decomposed ('e', 16#88#);
               when 16#AC# => Append_Decomposed ('i', 16#80#);
               when 16#AD# => Append_Decomposed ('i', 16#81#);
               when 16#AE# => Append_Decomposed ('i', 16#82#);
               when 16#AF# => Append_Decomposed ('i', 16#88#);
               when 16#B1# => Append_Decomposed ('n', 16#83#);
               when 16#B2# => Append_Decomposed ('o', 16#80#);
               when 16#B3# => Append_Decomposed ('o', 16#81#);
               when 16#B4# => Append_Decomposed ('o', 16#82#);
               when 16#B5# => Append_Decomposed ('o', 16#83#);
               when 16#B6# => Append_Decomposed ('o', 16#88#);
               when 16#B9# => Append_Decomposed ('u', 16#80#);
               when 16#BA# => Append_Decomposed ('u', 16#81#);
               when 16#BB# => Append_Decomposed ('u', 16#82#);
               when 16#BC# => Append_Decomposed ('u', 16#88#);
               when 16#BD# => Append_Decomposed ('y', 16#81#);
               when 16#BF# => Append_Decomposed ('y', 16#88#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C4#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#80# => Append_Decomposed ('A', 16#84#);
               when 16#81# => Append_Decomposed ('a', 16#84#);
               when 16#82# => Append_Decomposed ('A', 16#86#);
               when 16#83# => Append_Decomposed ('a', 16#86#);
               when 16#84# => Append_Decomposed ('A', 16#A8#);
               when 16#85# => Append_Decomposed ('a', 16#A8#);
               when 16#86# => Append_Decomposed ('C', 16#81#);
               when 16#87# => Append_Decomposed ('c', 16#81#);
               when 16#8A# => Append_Decomposed ('C', 16#87#);
               when 16#8B# => Append_Decomposed ('c', 16#87#);
               when 16#8C# => Append_Decomposed ('C', 16#8C#);
               when 16#8D# => Append_Decomposed ('c', 16#8C#);
               when 16#8E# => Append_Decomposed ('D', 16#8C#);
               when 16#8F# => Append_Decomposed ('d', 16#8C#);
               when 16#92# => Append_Decomposed ('E', 16#84#);
               when 16#93# => Append_Decomposed ('e', 16#84#);
               when 16#94# => Append_Decomposed ('E', 16#86#);
               when 16#95# => Append_Decomposed ('e', 16#86#);
               when 16#96# => Append_Decomposed ('E', 16#87#);
               when 16#97# => Append_Decomposed ('e', 16#87#);
               when 16#98# => Append_Decomposed ('E', 16#A8#);
               when 16#99# => Append_Decomposed ('e', 16#A8#);
               when 16#9A# => Append_Decomposed ('E', 16#8C#);
               when 16#9B# => Append_Decomposed ('e', 16#8C#);
               when 16#9E# => Append_Decomposed ('G', 16#86#);
               when 16#9F# => Append_Decomposed ('g', 16#86#);
               when 16#A0# => Append_Decomposed ('G', 16#87#);
               when 16#A1# => Append_Decomposed ('g', 16#87#);
               when 16#A2# => Append_Decomposed ('G', 16#A7#);
               when 16#A3# => Append_Decomposed ('g', 16#A7#);
               when 16#AA# => Append_Decomposed ('I', 16#84#);
               when 16#AB# => Append_Decomposed ('i', 16#84#);
               when 16#AC# => Append_Decomposed ('I', 16#86#);
               when 16#AD# => Append_Decomposed ('i', 16#86#);
               when 16#AE# => Append_Decomposed ('I', 16#A8#);
               when 16#AF# => Append_Decomposed ('i', 16#A8#);
               when 16#B0# => Append_Decomposed ('I', 16#87#);
               when 16#B9# => Append_Decomposed ('L', 16#81#);
               when 16#BA# => Append_Decomposed ('l', 16#81#);
               when 16#BB# => Append_Decomposed ('L', 16#A7#);
               when 16#BC# => Append_Decomposed ('l', 16#A7#);
               when 16#BD# => Append_Decomposed ('L', 16#8C#);
               when 16#BE# => Append_Decomposed ('l', 16#8C#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C5#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#83# => Append_Decomposed ('N', 16#81#);
               when 16#84# => Append_Decomposed ('n', 16#81#);
               when 16#85# => Append_Decomposed ('N', 16#A7#);
               when 16#86# => Append_Decomposed ('n', 16#A7#);
               when 16#87# => Append_Decomposed ('N', 16#8C#);
               when 16#88# => Append_Decomposed ('n', 16#8C#);
               when 16#8C# => Append_Decomposed ('O', 16#84#);
               when 16#8D# => Append_Decomposed ('o', 16#84#);
               when 16#8E# => Append_Decomposed ('O', 16#86#);
               when 16#8F# => Append_Decomposed ('o', 16#86#);
               when 16#94# => Append_Decomposed ('R', 16#81#);
               when 16#95# => Append_Decomposed ('r', 16#81#);
               when 16#96# => Append_Decomposed ('R', 16#A7#);
               when 16#97# => Append_Decomposed ('r', 16#A7#);
               when 16#98# => Append_Decomposed ('R', 16#8C#);
               when 16#99# => Append_Decomposed ('r', 16#8C#);
               when 16#9A# => Append_Decomposed ('S', 16#81#);
               when 16#9B# => Append_Decomposed ('s', 16#81#);
               when 16#9E# => Append_Decomposed ('S', 16#A7#);
               when 16#9F# => Append_Decomposed ('s', 16#A7#);
               when 16#A0# => Append_Decomposed ('S', 16#8C#);
               when 16#A1# => Append_Decomposed ('s', 16#8C#);
               when 16#A2# => Append_Decomposed ('T', 16#A7#);
               when 16#A3# => Append_Decomposed ('t', 16#A7#);
               when 16#A4# => Append_Decomposed ('T', 16#8C#);
               when 16#A5# => Append_Decomposed ('t', 16#8C#);
               when 16#AA# => Append_Decomposed ('U', 16#84#);
               when 16#AB# => Append_Decomposed ('u', 16#84#);
               when 16#AC# => Append_Decomposed ('U', 16#86#);
               when 16#AD# => Append_Decomposed ('u', 16#86#);
               when 16#B2# => Append_Decomposed ('U', 16#A8#);
               when 16#B3# => Append_Decomposed ('u', 16#A8#);
               when 16#B9# => Append_Decomposed ('Z', 16#81#);
               when 16#BA# => Append_Decomposed ('z', 16#81#);
               when 16#BB# => Append_Decomposed ('Z', 16#87#);
               when 16#BC# => Append_Decomposed ('z', 16#87#);
               when 16#BD# => Append_Decomposed ('Z', 16#8C#);
               when 16#BE# => Append_Decomposed ('z', 16#8C#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C6#
         then
            case Character'Pos (Text (Index + 1)) is
               when 16#A0# => Append_Decomposed ('O', 16#9B#);
               when 16#A1# => Append_Decomposed ('o', 16#9B#);
               when 16#AF# => Append_Decomposed ('U', 16#9B#);
               when 16#B0# => Append_Decomposed ('u', 16#9B#);
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index + 2 <= Text'Last
           and then Character'Pos (Text (Index)) = 16#E1#
         then
            declare
               B2 : constant Natural := Character'Pos (Text (Index + 1));
               B3 : constant Natural := Character'Pos (Text (Index + 2));
            begin
               if B2 = 16#BA# then
                  case B3 is
                     when 16#A0# => Append_Decomposed ('A', 16#A3#);
                     when 16#A1# => Append_Decomposed ('a', 16#A3#);
                     when 16#A4# => Append_Decomposed_2 ('A', 16#82#, 16#81#);
                     when 16#A5# => Append_Decomposed_2 ('a', 16#82#, 16#81#);
                     when 16#A6# => Append_Decomposed_2 ('A', 16#82#, 16#80#);
                     when 16#A7# => Append_Decomposed_2 ('a', 16#82#, 16#80#);
                     when 16#A8# => Append_Decomposed_2 ('A', 16#82#, 16#89#);
                     when 16#A9# => Append_Decomposed_2 ('a', 16#82#, 16#89#);
                     when 16#AA# => Append_Decomposed_2 ('A', 16#82#, 16#83#);
                     when 16#AB# => Append_Decomposed_2 ('a', 16#82#, 16#83#);
                     when 16#AC# => Append_Decomposed_2 ('A', 16#82#, 16#A3#);
                     when 16#AD# => Append_Decomposed_2 ('a', 16#82#, 16#A3#);
                     when 16#AE# => Append_Decomposed_2 ('A', 16#86#, 16#81#);
                     when 16#AF# => Append_Decomposed_2 ('a', 16#86#, 16#81#);
                     when 16#B0# => Append_Decomposed_2 ('A', 16#86#, 16#80#);
                     when 16#B1# => Append_Decomposed_2 ('a', 16#86#, 16#80#);
                     when 16#B2# => Append_Decomposed_2 ('A', 16#86#, 16#89#);
                     when 16#B3# => Append_Decomposed_2 ('a', 16#86#, 16#89#);
                     when 16#B4# => Append_Decomposed_2 ('A', 16#86#, 16#83#);
                     when 16#B5# => Append_Decomposed_2 ('a', 16#86#, 16#83#);
                     when 16#B6# => Append_Decomposed_2 ('A', 16#86#, 16#A3#);
                     when 16#B7# => Append_Decomposed_2 ('a', 16#86#, 16#A3#);
                     when 16#B8# => Append_Decomposed ('E', 16#A3#);
                     when 16#B9# => Append_Decomposed ('e', 16#A3#);
                     when 16#BE# => Append_Decomposed_2 ('E', 16#82#, 16#81#);
                     when 16#BF# => Append_Decomposed_2 ('e', 16#82#, 16#81#);
                     when others => Append_Original (3);
                  end case;
               elsif B2 = 16#BB# then
                  case B3 is
                     when 16#80# => Append_Decomposed_2 ('E', 16#82#, 16#80#);
                     when 16#81# => Append_Decomposed_2 ('e', 16#82#, 16#80#);
                     when 16#82# => Append_Decomposed_2 ('E', 16#82#, 16#89#);
                     when 16#83# => Append_Decomposed_2 ('e', 16#82#, 16#89#);
                     when 16#84# => Append_Decomposed_2 ('E', 16#82#, 16#83#);
                     when 16#85# => Append_Decomposed_2 ('e', 16#82#, 16#83#);
                     when 16#86# => Append_Decomposed_2 ('E', 16#82#, 16#A3#);
                     when 16#87# => Append_Decomposed_2 ('e', 16#82#, 16#A3#);
                     when 16#8A# => Append_Decomposed ('I', 16#A3#);
                     when 16#8B# => Append_Decomposed ('i', 16#A3#);
                     when 16#8C# => Append_Decomposed ('O', 16#A3#);
                     when 16#8D# => Append_Decomposed ('o', 16#A3#);
                     when 16#90# => Append_Decomposed_2 ('O', 16#82#, 16#81#);
                     when 16#91# => Append_Decomposed_2 ('o', 16#82#, 16#81#);
                     when 16#92# => Append_Decomposed_2 ('O', 16#82#, 16#80#);
                     when 16#93# => Append_Decomposed_2 ('o', 16#82#, 16#80#);
                     when 16#94# => Append_Decomposed_2 ('O', 16#82#, 16#89#);
                     when 16#95# => Append_Decomposed_2 ('o', 16#82#, 16#89#);
                     when 16#96# => Append_Decomposed_2 ('O', 16#82#, 16#83#);
                     when 16#97# => Append_Decomposed_2 ('o', 16#82#, 16#83#);
                     when 16#98# => Append_Decomposed_2 ('O', 16#82#, 16#A3#);
                     when 16#99# => Append_Decomposed_2 ('o', 16#82#, 16#A3#);
                     when 16#9A# => Append_Decomposed_2 ('O', 16#9B#, 16#81#);
                     when 16#9B# => Append_Decomposed_2 ('o', 16#9B#, 16#81#);
                     when 16#9C# => Append_Decomposed_2 ('O', 16#9B#, 16#80#);
                     when 16#9D# => Append_Decomposed_2 ('o', 16#9B#, 16#80#);
                     when 16#9E# => Append_Decomposed_2 ('O', 16#9B#, 16#89#);
                     when 16#9F# => Append_Decomposed_2 ('o', 16#9B#, 16#89#);
                     when 16#A0# => Append_Decomposed_2 ('O', 16#9B#, 16#83#);
                     when 16#A1# => Append_Decomposed_2 ('o', 16#9B#, 16#83#);
                     when 16#A2# => Append_Decomposed_2 ('O', 16#9B#, 16#A3#);
                     when 16#A3# => Append_Decomposed_2 ('o', 16#9B#, 16#A3#);
                     when 16#A4# => Append_Decomposed ('U', 16#A3#);
                     when 16#A5# => Append_Decomposed ('u', 16#A3#);
                     when 16#A8# => Append_Decomposed_2 ('U', 16#9B#, 16#81#);
                     when 16#A9# => Append_Decomposed_2 ('u', 16#9B#, 16#81#);
                     when 16#AA# => Append_Decomposed_2 ('U', 16#9B#, 16#80#);
                     when 16#AB# => Append_Decomposed_2 ('u', 16#9B#, 16#80#);
                     when 16#AC# => Append_Decomposed_2 ('U', 16#9B#, 16#89#);
                     when 16#AD# => Append_Decomposed_2 ('u', 16#9B#, 16#89#);
                     when 16#AE# => Append_Decomposed_2 ('U', 16#9B#, 16#83#);
                     when 16#AF# => Append_Decomposed_2 ('u', 16#9B#, 16#83#);
                     when 16#B0# => Append_Decomposed_2 ('U', 16#9B#, 16#A3#);
                     when 16#B1# => Append_Decomposed_2 ('u', 16#9B#, 16#A3#);
                     when 16#B4# => Append_Decomposed ('Y', 16#A3#);
                     when 16#B5# => Append_Decomposed ('y', 16#A3#);
                     when others => Append_Original (3);
                  end case;
               else
                  Append_Original (3);
               end if;
            end;
            Index := Index + 3;
         else
            Append_Original (UTF8_Unit_Length (Text, Index));
            Index := Index + UTF8_Unit_Length (Text, Index);
         end if;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end Normalize_NFD;

   function Arabic_Presentation_A_Two_Letter_Ligature_Key_Code
     (Middle : Natural;
      Trail  : Natural)
      return Natural
   is
   begin
      if Middle = 16#AF# then
         case Trail is
            when 16#AA# => return 16#06260627#;
            when 16#AB# => return 16#06260627#;
            when 16#AE# => return 16#06260648#;
            when 16#AF# => return 16#06260648#;
            when 16#B9# => return 16#06260649#;
            when 16#BA# => return 16#06260649#;
            when 16#BB# => return 16#06260649#;
            when others => return 0;
         end case;
      elsif Middle = 16#B0# then
         case Trail is
            when 16#80# => return 16#0626062C#;
            when 16#81# => return 16#0626062D#;
            when 16#82# => return 16#06260645#;
            when 16#83# => return 16#06260649#;
            when 16#84# => return 16#0626064A#;
            when 16#85# => return 16#0628062C#;
            when 16#86# => return 16#0628062D#;
            when 16#87# => return 16#0628062E#;
            when 16#88# => return 16#06280645#;
            when 16#89# => return 16#06280649#;
            when 16#8A# => return 16#0628064A#;
            when 16#8B# => return 16#062A062C#;
            when 16#8C# => return 16#062A062D#;
            when 16#8D# => return 16#062A062E#;
            when 16#8E# => return 16#062A0645#;
            when 16#8F# => return 16#062A0649#;
            when 16#90# => return 16#062A064A#;
            when 16#91# => return 16#062B062C#;
            when 16#92# => return 16#062B0645#;
            when 16#93# => return 16#062B0649#;
            when 16#94# => return 16#062B064A#;
            when 16#95# => return 16#062C062D#;
            when 16#96# => return 16#062C0645#;
            when 16#97# => return 16#062D062C#;
            when 16#98# => return 16#062D0645#;
            when 16#99# => return 16#062E062C#;
            when 16#9A# => return 16#062E062D#;
            when 16#9B# => return 16#062E0645#;
            when 16#9C# => return 16#0633062C#;
            when 16#9D# => return 16#0633062D#;
            when 16#9E# => return 16#0633062E#;
            when 16#9F# => return 16#06330645#;
            when 16#A0# => return 16#0635062D#;
            when 16#A1# => return 16#06350645#;
            when 16#A2# => return 16#0636062C#;
            when 16#A3# => return 16#0636062D#;
            when 16#A4# => return 16#0636062E#;
            when 16#A5# => return 16#06360645#;
            when 16#A6# => return 16#0637062D#;
            when 16#A7# => return 16#06370645#;
            when 16#A8# => return 16#06380645#;
            when 16#A9# => return 16#0639062C#;
            when 16#AA# => return 16#06390645#;
            when 16#AB# => return 16#063A062C#;
            when 16#AC# => return 16#063A0645#;
            when 16#AD# => return 16#0641062C#;
            when 16#AE# => return 16#0641062D#;
            when 16#AF# => return 16#0641062E#;
            when 16#B0# => return 16#06410645#;
            when 16#B1# => return 16#06410649#;
            when 16#B2# => return 16#0641064A#;
            when 16#B3# => return 16#0642062D#;
            when 16#B4# => return 16#06420645#;
            when 16#B5# => return 16#06420649#;
            when 16#B6# => return 16#0642064A#;
            when 16#B7# => return 16#06430627#;
            when 16#B8# => return 16#0643062C#;
            when 16#B9# => return 16#0643062D#;
            when 16#BA# => return 16#0643062E#;
            when 16#BB# => return 16#06430644#;
            when 16#BC# => return 16#06430645#;
            when 16#BD# => return 16#06430649#;
            when 16#BE# => return 16#0643064A#;
            when 16#BF# => return 16#0644062C#;
            when others => return 0;
         end case;
      elsif Middle = 16#B1# then
         case Trail is
            when 16#80# => return 16#0644062D#;
            when 16#81# => return 16#0644062E#;
            when 16#82# => return 16#06440645#;
            when 16#83# => return 16#06440649#;
            when 16#84# => return 16#0644064A#;
            when 16#85# => return 16#0645062C#;
            when 16#86# => return 16#0645062D#;
            when 16#87# => return 16#0645062E#;
            when 16#88# => return 16#06450645#;
            when 16#89# => return 16#06450649#;
            when 16#8A# => return 16#0645064A#;
            when 16#8B# => return 16#0646062C#;
            when 16#8C# => return 16#0646062D#;
            when 16#8D# => return 16#0646062E#;
            when 16#8E# => return 16#06460645#;
            when 16#8F# => return 16#06460649#;
            when 16#90# => return 16#0646064A#;
            when 16#91# => return 16#0647062C#;
            when 16#92# => return 16#06470645#;
            when 16#93# => return 16#06470649#;
            when 16#94# => return 16#0647064A#;
            when 16#95# => return 16#064A062C#;
            when 16#96# => return 16#064A062D#;
            when 16#97# => return 16#064A062E#;
            when 16#98# => return 16#064A0645#;
            when 16#99# => return 16#064A0649#;
            when 16#9A# => return 16#064A064A#;
            when 16#A4# => return 16#06260631#;
            when 16#A5# => return 16#06260632#;
            when 16#A6# => return 16#06260645#;
            when 16#A7# => return 16#06260646#;
            when 16#A8# => return 16#06260649#;
            when 16#A9# => return 16#0626064A#;
            when 16#AA# => return 16#06280631#;
            when 16#AB# => return 16#06280632#;
            when 16#AC# => return 16#06280645#;
            when 16#AD# => return 16#06280646#;
            when 16#AE# => return 16#06280649#;
            when 16#AF# => return 16#0628064A#;
            when 16#B0# => return 16#062A0631#;
            when 16#B1# => return 16#062A0632#;
            when 16#B2# => return 16#062A0645#;
            when 16#B3# => return 16#062A0646#;
            when 16#B4# => return 16#062A0649#;
            when 16#B5# => return 16#062A064A#;
            when 16#B6# => return 16#062B0631#;
            when 16#B7# => return 16#062B0632#;
            when 16#B8# => return 16#062B0645#;
            when 16#B9# => return 16#062B0646#;
            when 16#BA# => return 16#062B0649#;
            when 16#BB# => return 16#062B064A#;
            when 16#BC# => return 16#06410649#;
            when 16#BD# => return 16#0641064A#;
            when 16#BE# => return 16#06420649#;
            when 16#BF# => return 16#0642064A#;
            when others => return 0;
         end case;
      elsif Middle = 16#B2# then
         case Trail is
            when 16#80# => return 16#06430627#;
            when 16#81# => return 16#06430644#;
            when 16#82# => return 16#06430645#;
            when 16#83# => return 16#06430649#;
            when 16#84# => return 16#0643064A#;
            when 16#85# => return 16#06440645#;
            when 16#86# => return 16#06440649#;
            when 16#87# => return 16#0644064A#;
            when 16#88# => return 16#06450627#;
            when 16#89# => return 16#06450645#;
            when 16#8A# => return 16#06460631#;
            when 16#8B# => return 16#06460632#;
            when 16#8C# => return 16#06460645#;
            when 16#8D# => return 16#06460646#;
            when 16#8E# => return 16#06460649#;
            when 16#8F# => return 16#0646064A#;
            when 16#91# => return 16#064A0631#;
            when 16#92# => return 16#064A0632#;
            when 16#93# => return 16#064A0645#;
            when 16#94# => return 16#064A0646#;
            when 16#95# => return 16#064A0649#;
            when 16#96# => return 16#064A064A#;
            when 16#97# => return 16#0626062C#;
            when 16#98# => return 16#0626062D#;
            when 16#99# => return 16#0626062E#;
            when 16#9A# => return 16#06260645#;
            when 16#9B# => return 16#06260647#;
            when 16#9C# => return 16#0628062C#;
            when 16#9D# => return 16#0628062D#;
            when 16#9E# => return 16#0628062E#;
            when 16#9F# => return 16#06280645#;
            when 16#A0# => return 16#06280647#;
            when 16#A1# => return 16#062A062C#;
            when 16#A2# => return 16#062A062D#;
            when 16#A3# => return 16#062A062E#;
            when 16#A4# => return 16#062A0645#;
            when 16#A5# => return 16#062A0647#;
            when 16#A6# => return 16#062B0645#;
            when 16#A7# => return 16#062C062D#;
            when 16#A8# => return 16#062C0645#;
            when 16#A9# => return 16#062D062C#;
            when 16#AA# => return 16#062D0645#;
            when 16#AB# => return 16#062E062C#;
            when 16#AC# => return 16#062E0645#;
            when 16#AD# => return 16#0633062C#;
            when 16#AE# => return 16#0633062D#;
            when 16#AF# => return 16#0633062E#;
            when 16#B0# => return 16#06330645#;
            when 16#B1# => return 16#0635062D#;
            when 16#B2# => return 16#0635062E#;
            when 16#B3# => return 16#06350645#;
            when 16#B4# => return 16#0636062C#;
            when 16#B5# => return 16#0636062D#;
            when 16#B6# => return 16#0636062E#;
            when 16#B7# => return 16#06360645#;
            when 16#B8# => return 16#0637062D#;
            when 16#B9# => return 16#06380645#;
            when 16#BA# => return 16#0639062C#;
            when 16#BB# => return 16#06390645#;
            when 16#BC# => return 16#063A062C#;
            when 16#BD# => return 16#063A0645#;
            when 16#BE# => return 16#0641062C#;
            when 16#BF# => return 16#0641062D#;
            when others => return 0;
         end case;
      elsif Middle = 16#B3# then
         case Trail is
            when 16#80# => return 16#0641062E#;
            when 16#81# => return 16#06410645#;
            when 16#82# => return 16#0642062D#;
            when 16#83# => return 16#06420645#;
            when 16#84# => return 16#0643062C#;
            when 16#85# => return 16#0643062D#;
            when 16#86# => return 16#0643062E#;
            when 16#87# => return 16#06430644#;
            when 16#88# => return 16#06430645#;
            when 16#89# => return 16#0644062C#;
            when 16#8A# => return 16#0644062D#;
            when 16#8B# => return 16#0644062E#;
            when 16#8C# => return 16#06440645#;
            when 16#8D# => return 16#06440647#;
            when 16#8E# => return 16#0645062C#;
            when 16#8F# => return 16#0645062D#;
            when 16#90# => return 16#0645062E#;
            when 16#91# => return 16#06450645#;
            when 16#92# => return 16#0646062C#;
            when 16#93# => return 16#0646062D#;
            when 16#94# => return 16#0646062E#;
            when 16#95# => return 16#06460645#;
            when 16#96# => return 16#06460647#;
            when 16#97# => return 16#0647062C#;
            when 16#98# => return 16#06470645#;
            when 16#9A# => return 16#064A062C#;
            when 16#9B# => return 16#064A062D#;
            when 16#9C# => return 16#064A062E#;
            when 16#9D# => return 16#064A0645#;
            when 16#9E# => return 16#064A0647#;
            when 16#9F# => return 16#06260645#;
            when 16#A0# => return 16#06260647#;
            when 16#A1# => return 16#06280645#;
            when 16#A2# => return 16#06280647#;
            when 16#A3# => return 16#062A0645#;
            when 16#A4# => return 16#062A0647#;
            when 16#A5# => return 16#062B0645#;
            when 16#A6# => return 16#062B0647#;
            when 16#A7# => return 16#06330645#;
            when 16#A8# => return 16#06330647#;
            when 16#A9# => return 16#06340645#;
            when 16#AA# => return 16#06340647#;
            when 16#AB# => return 16#06430644#;
            when 16#AC# => return 16#06430645#;
            when 16#AD# => return 16#06440645#;
            when 16#AE# => return 16#06460645#;
            when 16#AF# => return 16#06460647#;
            when 16#B0# => return 16#064A0645#;
            when 16#B1# => return 16#064A0647#;
            when 16#B5# => return 16#06370649#;
            when 16#B6# => return 16#0637064A#;
            when 16#B7# => return 16#06390649#;
            when 16#B8# => return 16#0639064A#;
            when 16#B9# => return 16#063A0649#;
            when 16#BA# => return 16#063A064A#;
            when 16#BB# => return 16#06330649#;
            when 16#BC# => return 16#0633064A#;
            when 16#BD# => return 16#06340649#;
            when 16#BE# => return 16#0634064A#;
            when 16#BF# => return 16#062D0649#;
            when others => return 0;
         end case;
      elsif Middle = 16#B4# then
         case Trail is
            when 16#80# => return 16#062D064A#;
            when 16#81# => return 16#062C0649#;
            when 16#82# => return 16#062C064A#;
            when 16#83# => return 16#062E0649#;
            when 16#84# => return 16#062E064A#;
            when 16#85# => return 16#06350649#;
            when 16#86# => return 16#0635064A#;
            when 16#87# => return 16#06360649#;
            when 16#88# => return 16#0636064A#;
            when 16#89# => return 16#0634062C#;
            when 16#8A# => return 16#0634062D#;
            when 16#8B# => return 16#0634062E#;
            when 16#8C# => return 16#06340645#;
            when 16#8D# => return 16#06340631#;
            when 16#8E# => return 16#06330631#;
            when 16#8F# => return 16#06350631#;
            when 16#90# => return 16#06360631#;
            when 16#91# => return 16#06370649#;
            when 16#92# => return 16#0637064A#;
            when 16#93# => return 16#06390649#;
            when 16#94# => return 16#0639064A#;
            when 16#95# => return 16#063A0649#;
            when 16#96# => return 16#063A064A#;
            when 16#97# => return 16#06330649#;
            when 16#98# => return 16#0633064A#;
            when 16#99# => return 16#06340649#;
            when 16#9A# => return 16#0634064A#;
            when 16#9B# => return 16#062D0649#;
            when 16#9C# => return 16#062D064A#;
            when 16#9D# => return 16#062C0649#;
            when 16#9E# => return 16#062C064A#;
            when 16#9F# => return 16#062E0649#;
            when 16#A0# => return 16#062E064A#;
            when 16#A1# => return 16#06350649#;
            when 16#A2# => return 16#0635064A#;
            when 16#A3# => return 16#06360649#;
            when 16#A4# => return 16#0636064A#;
            when 16#A5# => return 16#0634062C#;
            when 16#A6# => return 16#0634062D#;
            when 16#A7# => return 16#0634062E#;
            when 16#A8# => return 16#06340645#;
            when 16#A9# => return 16#06340631#;
            when 16#AA# => return 16#06330631#;
            when 16#AB# => return 16#06350631#;
            when 16#AC# => return 16#06360631#;
            when 16#AD# => return 16#0634062C#;
            when 16#AE# => return 16#0634062D#;
            when 16#AF# => return 16#0634062E#;
            when 16#B0# => return 16#06340645#;
            when 16#B1# => return 16#06330647#;
            when 16#B2# => return 16#06340647#;
            when 16#B3# => return 16#06370645#;
            when 16#B4# => return 16#0633062C#;
            when 16#B5# => return 16#0633062D#;
            when 16#B6# => return 16#0633062E#;
            when 16#B7# => return 16#0634062C#;
            when 16#B8# => return 16#0634062D#;
            when 16#B9# => return 16#0634062E#;
            when 16#BA# => return 16#06370645#;
            when 16#BB# => return 16#06380645#;
            when others => return 0;
         end case;
      else
         return 0;
      end if;
   end Arabic_Presentation_A_Two_Letter_Ligature_Key_Code;

   function Arabic_Presentation_A_Three_Letter_Ligature_Key_Code
     (Middle : Natural;
      Trail  : Natural)
      return Long_Long_Integer
   is
      Code : constant Natural :=
        16#F000# + (Middle - 16#80#) * 16#40# + (Trail - 16#80#);
   begin
      case Code is
         when 16#FD50# => return 16#062A062C0645#;
         when 16#FD51# => return 16#062A062D062C#;
         when 16#FD52# => return 16#062A062D062C#;
         when 16#FD53# => return 16#062A062D0645#;
         when 16#FD54# => return 16#062A062E0645#;
         when 16#FD55# => return 16#062A0645062C#;
         when 16#FD56# => return 16#062A0645062D#;
         when 16#FD57# => return 16#062A0645062E#;
         when 16#FD58# => return 16#062C0645062D#;
         when 16#FD59# => return 16#062C0645062D#;
         when 16#FD5A# => return 16#062D0645064A#;
         when 16#FD5B# => return 16#062D06450649#;
         when 16#FD5C# => return 16#0633062D062C#;
         when 16#FD5D# => return 16#0633062C062D#;
         when 16#FD5E# => return 16#0633062C0649#;
         when 16#FD5F# => return 16#06330645062D#;
         when 16#FD60# => return 16#06330645062D#;
         when 16#FD61# => return 16#06330645062C#;
         when 16#FD62# => return 16#063306450645#;
         when 16#FD63# => return 16#063306450645#;
         when 16#FD64# => return 16#0635062D062D#;
         when 16#FD65# => return 16#0635062D062D#;
         when 16#FD66# => return 16#063506450645#;
         when 16#FD67# => return 16#0634062D0645#;
         when 16#FD68# => return 16#0634062D0645#;
         when 16#FD69# => return 16#0634062C064A#;
         when 16#FD6A# => return 16#06340645062E#;
         when 16#FD6B# => return 16#06340645062E#;
         when 16#FD6C# => return 16#063406450645#;
         when 16#FD6D# => return 16#063406450645#;
         when 16#FD6E# => return 16#0636062D0649#;
         when 16#FD6F# => return 16#0636062E0645#;
         when 16#FD70# => return 16#0636062E0645#;
         when 16#FD71# => return 16#06370645062D#;
         when 16#FD72# => return 16#06370645062D#;
         when 16#FD73# => return 16#063706450645#;
         when 16#FD74# => return 16#06370645064A#;
         when 16#FD75# => return 16#0639062C0645#;
         when 16#FD76# => return 16#063906450645#;
         when 16#FD77# => return 16#063906450645#;
         when 16#FD78# => return 16#063906450649#;
         when 16#FD79# => return 16#063A06450645#;
         when 16#FD7A# => return 16#063A0645064A#;
         when 16#FD7B# => return 16#063A06450649#;
         when 16#FD7C# => return 16#0641062E0645#;
         when 16#FD7D# => return 16#0641062E0645#;
         when 16#FD7E# => return 16#06420645062D#;
         when 16#FD7F# => return 16#064206450645#;
         when 16#FD80# => return 16#0644062D0645#;
         when 16#FD81# => return 16#0644062D064A#;
         when 16#FD82# => return 16#0644062D0649#;
         when 16#FD83# => return 16#0644062C062C#;
         when 16#FD84# => return 16#0644062C062C#;
         when 16#FD85# => return 16#0644062E0645#;
         when 16#FD86# => return 16#0644062E0645#;
         when 16#FD87# => return 16#06440645062D#;
         when 16#FD88# => return 16#06440645062D#;
         when 16#FD89# => return 16#0645062D062C#;
         when 16#FD8A# => return 16#0645062D0645#;
         when 16#FD8B# => return 16#0645062D064A#;
         when 16#FD8C# => return 16#0645062C062D#;
         when 16#FD8D# => return 16#0645062C0645#;
         when 16#FD8E# => return 16#0645062E062C#;
         when 16#FD8F# => return 16#0645062E0645#;
         when 16#FD92# => return 16#0645062C062E#;
         when 16#FD93# => return 16#06470645062C#;
         when 16#FD94# => return 16#064706450645#;
         when 16#FD95# => return 16#0646062D0645#;
         when 16#FD96# => return 16#0646062D0649#;
         when 16#FD97# => return 16#0646062C0645#;
         when 16#FD98# => return 16#0646062C0645#;
         when 16#FD99# => return 16#0646062C0649#;
         when 16#FD9A# => return 16#06460645064A#;
         when 16#FD9B# => return 16#064606450649#;
         when 16#FD9C# => return 16#064A06450645#;
         when 16#FD9D# => return 16#064A06450645#;
         when 16#FD9E# => return 16#0628062E064A#;
         when 16#FD9F# => return 16#062A062C064A#;
         when 16#FDA0# => return 16#062A062C0649#;
         when 16#FDA1# => return 16#062A062E064A#;
         when 16#FDA2# => return 16#062A062E0649#;
         when 16#FDA3# => return 16#062A0645064A#;
         when 16#FDA4# => return 16#062A06450649#;
         when 16#FDA5# => return 16#062C0645064A#;
         when 16#FDA6# => return 16#062C062D0649#;
         when 16#FDA7# => return 16#062C06450649#;
         when 16#FDA8# => return 16#0633062E0649#;
         when 16#FDA9# => return 16#0635062D064A#;
         when 16#FDAA# => return 16#0634062D064A#;
         when 16#FDAB# => return 16#0636062D064A#;
         when 16#FDAC# => return 16#0644062C064A#;
         when 16#FDAD# => return 16#06440645064A#;
         when 16#FDAE# => return 16#064A062D064A#;
         when 16#FDAF# => return 16#064A062C064A#;
         when 16#FDB0# => return 16#064A0645064A#;
         when 16#FDB1# => return 16#06450645064A#;
         when 16#FDB2# => return 16#06420645064A#;
         when 16#FDB3# => return 16#0646062D064A#;
         when 16#FDB4# => return 16#06420645062D#;
         when 16#FDB5# => return 16#0644062D0645#;
         when 16#FDB6# => return 16#06390645064A#;
         when 16#FDB7# => return 16#06430645064A#;
         when 16#FDB8# => return 16#0646062C062D#;
         when 16#FDB9# => return 16#0645062E064A#;
         when 16#FDBA# => return 16#0644062C0645#;
         when 16#FDBB# => return 16#064306450645#;
         when 16#FDBC# => return 16#0644062C0645#;
         when 16#FDBD# => return 16#0646062C062D#;
         when 16#FDBE# => return 16#062C062D064A#;
         when 16#FDBF# => return 16#062D062C064A#;
         when 16#FDC0# => return 16#0645062C064A#;
         when 16#FDC1# => return 16#06410645064A#;
         when 16#FDC2# => return 16#0628062D064A#;
         when 16#FDC3# => return 16#064306450645#;
         when 16#FDC4# => return 16#0639062C0645#;
         when 16#FDC5# => return 16#063506450645#;
         when 16#FDC6# => return 16#0633062E064A#;
         when 16#FDC7# => return 16#0646062C064A#;
         when 16#FDF9# => return 16#063506440649#;
         when others => return 0;
      end case;
   end Arabic_Presentation_A_Three_Letter_Ligature_Key_Code;

   function Arabic_Presentation_A_Four_Letter_Ligature_Key_Code
     (Middle : Natural;
      Trail  : Natural)
      return Long_Long_Integer
   is
      Code : constant Natural :=
        16#F000# + (Middle - 16#80#) * 16#40# + (Trail - 16#80#);
   begin
      case Code is
         when 16#FDF2# => return 16#0627064406440647#;
         when 16#FDF3# => return 16#0627064306280631#;
         when 16#FDF4# => return 16#0645062D0645062F#;
         when 16#FDF5# => return 16#0635064406390645#;
         when 16#FDF6# => return 16#0631063306480644#;
         when 16#FDF7# => return 16#06390644064A0647#;
         when 16#FDF8# => return 16#0648063306440645#;
         when others => return 0;
      end case;
   end Arabic_Presentation_A_Four_Letter_Ligature_Key_Code;

   function Transliterate_ASCII
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);

      Result : String (1 .. Natural'Max (Text'Length * 4, 1));
      Last   : Natural := 0;
      Index  : Natural := (if Text'Length = 0 then 1 else Text'First);

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Text (Value : String) is
      begin
         for C of Value loop
            Append_Char (C);
         end loop;
      end Append_Text;

      procedure Append_Original (Count : Positive) is
      begin
         for Offset in 0 .. Count - 1 loop
            Append_Char (Text (Index + Offset));
         end loop;
      end Append_Original;

      function Byte_At (Offset : Natural) return Natural is
      begin
         return Character'Pos (Text (Index + Offset));
      end Byte_At;

      procedure Append_Arabic_Codepoint_ASCII (Code_Point : Natural) is
      begin
         case Code_Point is
            when 16#0621# => Append_Text ("'");
            when 16#0622# | 16#0623# | 16#0625# | 16#0627# =>
               Append_Text ("a");
            when 16#0624# => Append_Text ("w");
            when 16#0626# => Append_Text ("y");
            when 16#0628# => Append_Text ("b");
            when 16#0629# => Append_Text ("h");
            when 16#062A# => Append_Text ("t");
            when 16#062B# => Append_Text ("th");
            when 16#062C# => Append_Text ("j");
            when 16#062D# => Append_Text ("h");
            when 16#062E# => Append_Text ("kh");
            when 16#062F# => Append_Text ("d");
            when 16#0630# => Append_Text ("dh");
            when 16#0631# => Append_Text ("r");
            when 16#0632# => Append_Text ("z");
            when 16#0633# => Append_Text ("s");
            when 16#0634# => Append_Text ("sh");
            when 16#0635# => Append_Text ("s");
            when 16#0636# => Append_Text ("d");
            when 16#0637# => Append_Text ("t");
            when 16#0638# => Append_Text ("z");
            when 16#0639# => Append_Text ("a");
            when 16#063A# => Append_Text ("gh");
            when 16#0641# => Append_Text ("f");
            when 16#0642# => Append_Text ("q");
            when 16#0643# => Append_Text ("k");
            when 16#0644# => Append_Text ("l");
            when 16#0645# => Append_Text ("m");
            when 16#0646# => Append_Text ("n");
            when 16#0647# => Append_Text ("h");
            when 16#0648# => Append_Text ("w");
            when 16#0649# => Append_Text ("a");
            when 16#064A# => Append_Text ("y");
            when 16#067E# => Append_Text ("p");
            when 16#0686# => Append_Text ("ch");
            when 16#0698# => Append_Text ("zh");
            when 16#06A9# => Append_Text ("k");
            when 16#06AF# => Append_Text ("g");
            when 16#06CC# => Append_Text ("y");
            when others => null;
         end case;
      end Append_Arabic_Codepoint_ASCII;

      procedure Append_Arabic_Packed_Three_ASCII
        (Packed : Long_Long_Integer)
      is
      begin
         Append_Arabic_Codepoint_ASCII
           (Natural (Packed / 16#100000000#));
         Append_Arabic_Codepoint_ASCII
           (Natural ((Packed / 16#10000#) mod 16#10000#));
         Append_Arabic_Codepoint_ASCII
           (Natural (Packed mod 16#10000#));
      end Append_Arabic_Packed_Three_ASCII;

      procedure Append_Arabic_Packed_Four_ASCII
        (Packed : Long_Long_Integer)
      is
      begin
         Append_Arabic_Codepoint_ASCII
           (Natural (Packed / 16#1000000000000#));
         Append_Arabic_Codepoint_ASCII
           (Natural ((Packed / 16#100000000#) mod 16#10000#));
         Append_Arabic_Codepoint_ASCII
           (Natural ((Packed / 16#10000#) mod 16#10000#));
         Append_Arabic_Codepoint_ASCII
           (Natural (Packed mod 16#10000#));
      end Append_Arabic_Packed_Four_ASCII;
   begin
      while Index <= Text'Last loop
         if Character'Pos (Text (Index)) < 16#80# then
            Append_Char (Text (Index));
            Index := Index + 1;
         elsif Index < Text'Last and then Byte_At (0) = 16#C3# then
            case Byte_At (1) is
               when 16#80# .. 16#85# => Append_Text ("A");
               when 16#86# => Append_Text ("AE");
               when 16#87# => Append_Text ("C");
               when 16#88# .. 16#8B# => Append_Text ("E");
               when 16#8C# .. 16#8F# => Append_Text ("I");
               when 16#90# => Append_Text ("D");
               when 16#91# => Append_Text ("N");
               when 16#92# .. 16#96# | 16#98# => Append_Text ("O");
               when 16#99# .. 16#9C# => Append_Text ("U");
               when 16#9D# => Append_Text ("Y");
               when 16#9E# => Append_Text ("Th");
               when 16#9F# => Append_Text ("ss");
               when 16#A0# .. 16#A5# => Append_Text ("a");
               when 16#A6# => Append_Text ("ae");
               when 16#A7# => Append_Text ("c");
               when 16#A8# .. 16#AB# => Append_Text ("e");
               when 16#AC# .. 16#AF# => Append_Text ("i");
               when 16#B0# => Append_Text ("d");
               when 16#B1# => Append_Text ("n");
               when 16#B2# .. 16#B6# | 16#B8# => Append_Text ("o");
               when 16#B9# .. 16#BC# => Append_Text ("u");
               when 16#BD# | 16#BF# => Append_Text ("y");
               when 16#BE# => Append_Text ("th");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#C4# then
            case Byte_At (1) is
               when 16#80# | 16#82# | 16#84# => Append_Text ("A");
               when 16#81# | 16#83# | 16#85# => Append_Text ("a");
               when 16#86# | 16#88# | 16#8A# | 16#8C# => Append_Text ("C");
               when 16#87# | 16#89# | 16#8B# | 16#8D# => Append_Text ("c");
               when 16#8E# | 16#90# => Append_Text ("D");
               when 16#8F# | 16#91# => Append_Text ("d");
               when 16#92# | 16#94# | 16#96# | 16#98# | 16#9A# =>
                  Append_Text ("E");
               when 16#93# | 16#95# | 16#97# | 16#99# | 16#9B# =>
                  Append_Text ("e");
               when 16#9C# | 16#9E# | 16#A0# | 16#A2# => Append_Text ("G");
               when 16#9D# | 16#9F# | 16#A1# | 16#A3# => Append_Text ("g");
               when 16#A4# | 16#A6# => Append_Text ("H");
               when 16#A5# | 16#A7# => Append_Text ("h");
               when 16#A8# | 16#AA# | 16#AC# | 16#AE# | 16#B0# =>
                  Append_Text ("I");
               when 16#A9# | 16#AB# | 16#AD# | 16#AF# | 16#B1# =>
                  Append_Text ("i");
               when 16#B2# => Append_Text ("IJ");
               when 16#B3# => Append_Text ("ij");
               when 16#B4# => Append_Text ("J");
               when 16#B5# => Append_Text ("j");
               when 16#B6# | 16#B8# => Append_Text ("K");
               when 16#B7# | 16#B9# => Append_Text ("k");
               when 16#BA# | 16#BC# | 16#BE# => Append_Text ("L");
               when 16#BB# | 16#BD# | 16#BF# => Append_Text ("l");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#C5# then
            case Byte_At (1) is
               when 16#80# | 16#82# => Append_Text ("L");
               when 16#81# | 16#83# => Append_Text ("l");
               when 16#84# | 16#86# | 16#88# | 16#8A# => Append_Text ("N");
               when 16#85# | 16#87# | 16#89# | 16#8B# => Append_Text ("n");
               when 16#8C# | 16#8E# | 16#90# => Append_Text ("O");
               when 16#8D# | 16#8F# | 16#91# => Append_Text ("o");
               when 16#92# => Append_Text ("OE");
               when 16#93# => Append_Text ("oe");
               when 16#94# | 16#96# | 16#98# => Append_Text ("R");
               when 16#95# | 16#97# | 16#99# => Append_Text ("r");
               when 16#9A# | 16#9C# | 16#9E# | 16#A0# => Append_Text ("S");
               when 16#9B# | 16#9D# | 16#9F# | 16#A1# => Append_Text ("s");
               when 16#A2# | 16#A4# | 16#A6# => Append_Text ("T");
               when 16#A3# | 16#A5# | 16#A7# => Append_Text ("t");
               when 16#A8# | 16#AA# | 16#AC# | 16#AE# | 16#B0# | 16#B2# =>
                  Append_Text ("U");
               when 16#A9# | 16#AB# | 16#AD# | 16#AF# | 16#B1# | 16#B3# =>
                  Append_Text ("u");
               when 16#B4# => Append_Text ("W");
               when 16#B5# => Append_Text ("w");
               when 16#B6# | 16#B8# => Append_Text ("Y");
               when 16#B7# => Append_Text ("y");
               when 16#B9# | 16#BB# | 16#BD# => Append_Text ("Z");
               when 16#BA# | 16#BC# | 16#BE# | 16#BF# => Append_Text ("z");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#C6# then
            case Byte_At (1) is
               when 16#A0# => Append_Text ("O");
               when 16#A1# => Append_Text ("o");
               when 16#AF# => Append_Text ("U");
               when 16#B0# => Append_Text ("u");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index + 2 <= Text'Last and then Byte_At (0) = 16#E1# then
            if Byte_At (1) = 16#BA# then
               case Byte_At (2) is
                  when 16#A0# => Append_Text ("A");
                  when 16#A1# => Append_Text ("a");
                  when 16#A4# | 16#A6# | 16#A8# | 16#AA# | 16#AC#
                     | 16#AE# | 16#B0# | 16#B2# | 16#B4# | 16#B6# =>
                     Append_Text ("A");
                  when 16#A5# | 16#A7# | 16#A9# | 16#AB# | 16#AD#
                     | 16#AF# | 16#B1# | 16#B3# | 16#B5# | 16#B7# =>
                     Append_Text ("a");
                  when 16#B8# => Append_Text ("E");
                  when 16#B9# => Append_Text ("e");
                  when 16#BE# => Append_Text ("E");
                  when 16#BF# => Append_Text ("e");
                  when others => Append_Original (3);
               end case;
            elsif Byte_At (1) = 16#BB# then
               case Byte_At (2) is
                  when 16#80# | 16#82# | 16#84# | 16#86# =>
                     Append_Text ("E");
                  when 16#81# | 16#83# | 16#85# | 16#87# =>
                     Append_Text ("e");
                  when 16#8A# => Append_Text ("I");
                  when 16#8B# => Append_Text ("i");
                  when 16#8C# => Append_Text ("O");
                  when 16#8D# => Append_Text ("o");
                  when 16#90# | 16#92# | 16#94# | 16#96# | 16#98# =>
                     Append_Text ("O");
                  when 16#91# | 16#93# | 16#95# | 16#97# | 16#99# =>
                     Append_Text ("o");
                  when 16#9A# | 16#9C# | 16#9E# | 16#A0# | 16#A2# =>
                     Append_Text ("O");
                  when 16#9B# | 16#9D# | 16#9F# | 16#A1# | 16#A3# =>
                     Append_Text ("o");
                  when 16#A4# => Append_Text ("U");
                  when 16#A5# => Append_Text ("u");
                  when 16#A8# | 16#AA# | 16#AC# | 16#AE# | 16#B0# =>
                     Append_Text ("U");
                  when 16#A9# | 16#AB# | 16#AD# | 16#AF# | 16#B1# =>
                     Append_Text ("u");
                  when 16#B4# => Append_Text ("Y");
                  when 16#B5# => Append_Text ("y");
                  when others => Append_Original (3);
               end case;
            elsif Byte_At (1) = 16#82# then
               case Byte_At (2) is
                  when 16#A0# => Append_Text ("A");
                  when 16#A1# => Append_Text ("B");
                  when 16#A2# => Append_Text ("G");
                  when 16#A3# => Append_Text ("D");
                  when 16#A4# => Append_Text ("E");
                  when 16#A5# => Append_Text ("V");
                  when 16#A6# => Append_Text ("Z");
                  when 16#A7# => Append_Text ("T");
                  when 16#A8# => Append_Text ("I");
                  when 16#A9# => Append_Text ("K");
                  when 16#AA# => Append_Text ("L");
                  when 16#AB# => Append_Text ("M");
                  when 16#AC# => Append_Text ("N");
                  when 16#AD# => Append_Text ("O");
                  when 16#AE# => Append_Text ("P");
                  when 16#AF# => Append_Text ("Zh");
                  when 16#B0# => Append_Text ("R");
                  when 16#B1# => Append_Text ("S");
                  when 16#B2# => Append_Text ("T");
                  when 16#B3# => Append_Text ("U");
                  when 16#B4# => Append_Text ("P");
                  when 16#B5# => Append_Text ("Kh");
                  when 16#B6# => Append_Text ("Gh");
                  when 16#B7# => Append_Text ("Q");
                  when 16#B8# => Append_Text ("Sh");
                  when 16#B9# => Append_Text ("Ch");
                  when 16#BA# => Append_Text ("Ts");
                  when 16#BB# => Append_Text ("J");
                  when 16#BC# => Append_Text ("Ts");
                  when 16#BD# => Append_Text ("Ch");
                  when 16#BE# => Append_Text ("Kh");
                  when 16#BF# => Append_Text ("J");
                  when others => Append_Original (3);
               end case;
            elsif Byte_At (1) = 16#83# then
               case Byte_At (2) is
                  when 16#80# => Append_Text ("H");
                  when 16#81# => Append_Text ("He");
                  when 16#82# => Append_Text ("Hie");
                  when 16#83# => Append_Text ("We");
                  when 16#84# => Append_Text ("Har");
                  when 16#85# => Append_Text ("Hoe");
                  when 16#87# => Append_Text ("Yn");
                  when 16#8D# => Append_Text ("Aen");
                  when 16#90# => Append_Text ("a");
                  when 16#91# => Append_Text ("b");
                  when 16#92# => Append_Text ("g");
                  when 16#93# => Append_Text ("d");
                  when 16#94# => Append_Text ("e");
                  when 16#95# => Append_Text ("v");
                  when 16#96# => Append_Text ("z");
                  when 16#97# => Append_Text ("t");
                  when 16#98# => Append_Text ("i");
                  when 16#99# => Append_Text ("k");
                  when 16#9A# => Append_Text ("l");
                  when 16#9B# => Append_Text ("m");
                  when 16#9C# => Append_Text ("n");
                  when 16#9D# => Append_Text ("o");
                  when 16#9E# => Append_Text ("p");
                  when 16#9F# => Append_Text ("zh");
                  when 16#A0# => Append_Text ("r");
                  when 16#A1# => Append_Text ("s");
                  when 16#A2# => Append_Text ("t");
                  when 16#A3# => Append_Text ("u");
                  when 16#A4# => Append_Text ("p");
                  when 16#A5# => Append_Text ("k");
                  when 16#A6# => Append_Text ("gh");
                  when 16#A7# => Append_Text ("q");
                  when 16#A8# => Append_Text ("sh");
                  when 16#A9# => Append_Text ("ch");
                  when 16#AA# => Append_Text ("ts");
                  when 16#AB# => Append_Text ("dz");
                  when 16#AC# => Append_Text ("ts");
                  when 16#AD# => Append_Text ("ch");
                  when 16#AE# => Append_Text ("kh");
                  when 16#AF# => Append_Text ("j");
                  when 16#B0# => Append_Text ("h");
                  when 16#B1# => Append_Text ("he");
                  when 16#B2# => Append_Text ("hie");
                  when 16#B3# => Append_Text ("we");
                  when 16#B4# => Append_Text ("har");
                  when 16#B5# => Append_Text ("hoe");
                  when 16#B6# => Append_Text ("fi");
                  when 16#B7# => Append_Text ("yn");
                  when 16#B8# => Append_Text ("elifi");
                  when 16#B9# => Append_Text ("gan");
                  when 16#BA# => Append_Text ("ain");
                  when 16#BC# => Append_Text ("n");
                  when 16#BD# => Append_Text ("aen");
                  when 16#BE# => Append_Text ("hard");
                  when 16#BF# => Append_Text ("labial");
                  when others => Append_Original (3);
               end case;
            elsif Byte_At (1) = 16#B2# then
               case Byte_At (2) is
                  when 16#90# => Append_Text ("A");
                  when 16#91# => Append_Text ("B");
                  when 16#92# => Append_Text ("G");
                  when 16#93# => Append_Text ("D");
                  when 16#94# => Append_Text ("E");
                  when 16#95# => Append_Text ("V");
                  when 16#96# => Append_Text ("Z");
                  when 16#97# => Append_Text ("T");
                  when 16#98# => Append_Text ("I");
                  when 16#99# => Append_Text ("K");
                  when 16#9A# => Append_Text ("L");
                  when 16#9B# => Append_Text ("M");
                  when 16#9C# => Append_Text ("N");
                  when 16#9D# => Append_Text ("O");
                  when 16#9E# => Append_Text ("P");
                  when 16#9F# => Append_Text ("Zh");
                  when 16#A0# => Append_Text ("R");
                  when 16#A1# => Append_Text ("S");
                  when 16#A2# => Append_Text ("T");
                  when 16#A3# => Append_Text ("U");
                  when 16#A4# => Append_Text ("P");
                  when 16#A5# => Append_Text ("K");
                  when 16#A6# => Append_Text ("Gh");
                  when 16#A7# => Append_Text ("Q");
                  when 16#A8# => Append_Text ("Sh");
                  when 16#A9# => Append_Text ("Ch");
                  when 16#AA# => Append_Text ("Ts");
                  when 16#AB# => Append_Text ("Dz");
                  when 16#AC# => Append_Text ("Ts");
                  when 16#AD# => Append_Text ("Ch");
                  when 16#AE# => Append_Text ("Kh");
                  when 16#AF# => Append_Text ("J");
                  when 16#B0# => Append_Text ("H");
                  when 16#B1# => Append_Text ("He");
                  when 16#B2# => Append_Text ("Hie");
                  when 16#B3# => Append_Text ("We");
                  when 16#B4# => Append_Text ("Har");
                  when 16#B5# => Append_Text ("Hoe");
                  when 16#B6# => Append_Text ("Fi");
                  when 16#B7# => Append_Text ("Yn");
                  when 16#B8# => Append_Text ("Elifi");
                  when 16#B9# => Append_Text ("Gan");
                  when 16#BA# => Append_Text ("Ain");
                  when 16#BD# => Append_Text ("Aen");
                  when 16#BE# => Append_Text ("Hard");
                  when 16#BF# => Append_Text ("Labial");
                  when others => Append_Original (3);
               end case;
            else
               Append_Original (3);
            end if;
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#E2#
           and then Byte_At (1) = 16#B4#
         then
            case Byte_At (2) is
               when 16#80# => Append_Text ("a");
               when 16#81# => Append_Text ("b");
               when 16#82# => Append_Text ("g");
               when 16#83# => Append_Text ("d");
               when 16#84# => Append_Text ("e");
               when 16#85# => Append_Text ("v");
               when 16#86# => Append_Text ("z");
               when 16#87# => Append_Text ("t");
               when 16#88# => Append_Text ("i");
               when 16#89# => Append_Text ("k");
               when 16#8A# => Append_Text ("l");
               when 16#8B# => Append_Text ("m");
               when 16#8C# => Append_Text ("n");
               when 16#8D# => Append_Text ("o");
               when 16#8E# => Append_Text ("p");
               when 16#8F# => Append_Text ("zh");
               when 16#90# => Append_Text ("r");
               when 16#91# => Append_Text ("s");
               when 16#92# => Append_Text ("t");
               when 16#93# => Append_Text ("u");
               when 16#94# => Append_Text ("p");
               when 16#95# => Append_Text ("kh");
               when 16#96# => Append_Text ("gh");
               when 16#97# => Append_Text ("q");
               when 16#98# => Append_Text ("sh");
               when 16#99# => Append_Text ("ch");
               when 16#9A# => Append_Text ("ts");
               when 16#9B# => Append_Text ("j");
               when 16#9C# => Append_Text ("ts");
               when 16#9D# => Append_Text ("ch");
               when 16#9E# => Append_Text ("kh");
               when 16#9F# => Append_Text ("j");
               when 16#A0# => Append_Text ("h");
               when 16#A1# => Append_Text ("he");
               when 16#A2# => Append_Text ("hie");
               when 16#A3# => Append_Text ("we");
               when 16#A4# => Append_Text ("har");
               when 16#A5# => Append_Text ("hoe");
               when 16#A7# => Append_Text ("yn");
               when 16#AD# => Append_Text ("aen");
               when others => Append_Original (3);
            end case;
            Index := Index + 3;
         elsif Index < Text'Last and then Byte_At (0) = 16#CE# then
            case Byte_At (1) is
               when 16#86# => Append_Text ("A");
               when 16#88# => Append_Text ("E");
               when 16#89# => Append_Text ("I");
               when 16#8A# => Append_Text ("I");
               when 16#8C# => Append_Text ("O");
               when 16#8E# => Append_Text ("Y");
               when 16#8F# => Append_Text ("O");
               when 16#90# => Append_Text ("i");
               when 16#91# => Append_Text ("A");
               when 16#92# => Append_Text ("B");
               when 16#93# => Append_Text ("G");
               when 16#94# => Append_Text ("D");
               when 16#95# => Append_Text ("E");
               when 16#96# => Append_Text ("Z");
               when 16#97# => Append_Text ("I");
               when 16#98# => Append_Text ("Th");
               when 16#99# => Append_Text ("I");
               when 16#9A# => Append_Text ("K");
               when 16#9B# => Append_Text ("L");
               when 16#9C# => Append_Text ("M");
               when 16#9D# => Append_Text ("N");
               when 16#9E# => Append_Text ("X");
               when 16#9F# => Append_Text ("O");
               when 16#A0# => Append_Text ("P");
               when 16#A1# => Append_Text ("R");
               when 16#A3# => Append_Text ("S");
               when 16#A4# => Append_Text ("T");
               when 16#A5# => Append_Text ("Y");
               when 16#A6# => Append_Text ("Ph");
               when 16#A7# => Append_Text ("Ch");
               when 16#A8# => Append_Text ("Ps");
               when 16#A9# => Append_Text ("O");
               when 16#AA# => Append_Text ("I");
               when 16#AB# => Append_Text ("Y");
               when 16#AC# => Append_Text ("a");
               when 16#AD# => Append_Text ("e");
               when 16#AE# => Append_Text ("i");
               when 16#AF# => Append_Text ("i");
               when 16#B0# => Append_Text ("y");
               when 16#B1# => Append_Text ("a");
               when 16#B2# => Append_Text ("b");
               when 16#B3# => Append_Text ("g");
               when 16#B4# => Append_Text ("d");
               when 16#B5# => Append_Text ("e");
               when 16#B6# => Append_Text ("z");
               when 16#B7# => Append_Text ("i");
               when 16#B8# => Append_Text ("th");
               when 16#B9# => Append_Text ("i");
               when 16#BA# => Append_Text ("k");
               when 16#BB# => Append_Text ("l");
               when 16#BC# => Append_Text ("m");
               when 16#BD# => Append_Text ("n");
               when 16#BE# => Append_Text ("x");
               when 16#BF# => Append_Text ("o");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#CF# then
            case Byte_At (1) is
               when 16#80# => Append_Text ("p");
               when 16#81# => Append_Text ("r");
               when 16#82# | 16#83# => Append_Text ("s");
               when 16#84# => Append_Text ("t");
               when 16#85# => Append_Text ("y");
               when 16#86# => Append_Text ("ph");
               when 16#87# => Append_Text ("ch");
               when 16#88# => Append_Text ("ps");
               when 16#89# => Append_Text ("o");
               when 16#8A# => Append_Text ("i");
               when 16#8B# => Append_Text ("y");
               when 16#8C# => Append_Text ("o");
               when 16#8D# => Append_Text ("y");
               when 16#8E# => Append_Text ("o");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D0# then
            case Byte_At (1) is
               when 16#81# => Append_Text ("Yo");
               when 16#90# => Append_Text ("A");
               when 16#91# => Append_Text ("B");
               when 16#92# => Append_Text ("V");
               when 16#93# => Append_Text ("G");
               when 16#94# => Append_Text ("D");
               when 16#95# => Append_Text ("E");
               when 16#96# => Append_Text ("Zh");
               when 16#97# => Append_Text ("Z");
               when 16#98# => Append_Text ("I");
               when 16#99# => Append_Text ("Y");
               when 16#9A# => Append_Text ("K");
               when 16#9B# => Append_Text ("L");
               when 16#9C# => Append_Text ("M");
               when 16#9D# => Append_Text ("N");
               when 16#9E# => Append_Text ("O");
               when 16#9F# => Append_Text ("P");
               when 16#A0# => Append_Text ("R");
               when 16#A1# => Append_Text ("S");
               when 16#A2# => Append_Text ("T");
               when 16#A3# => Append_Text ("U");
               when 16#A4# => Append_Text ("F");
               when 16#A5# => Append_Text ("Kh");
               when 16#A6# => Append_Text ("Ts");
               when 16#A7# => Append_Text ("Ch");
               when 16#A8# => Append_Text ("Sh");
               when 16#A9# => Append_Text ("Shch");
               when 16#AA# => Append_Text ("""");
               when 16#AB# => Append_Text ("Y");
               when 16#AC# => Append_Text ("'");
               when 16#AD# => Append_Text ("E");
               when 16#AE# => Append_Text ("Yu");
               when 16#AF# => Append_Text ("Ya");
               when 16#B0# => Append_Text ("a");
               when 16#B1# => Append_Text ("b");
               when 16#B2# => Append_Text ("v");
               when 16#B3# => Append_Text ("g");
               when 16#B4# => Append_Text ("d");
               when 16#B5# => Append_Text ("e");
               when 16#B6# => Append_Text ("zh");
               when 16#B7# => Append_Text ("z");
               when 16#B8# => Append_Text ("i");
               when 16#B9# => Append_Text ("y");
               when 16#BA# => Append_Text ("k");
               when 16#BB# => Append_Text ("l");
               when 16#BC# => Append_Text ("m");
               when 16#BD# => Append_Text ("n");
               when 16#BE# => Append_Text ("o");
               when 16#BF# => Append_Text ("p");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D1# then
            case Byte_At (1) is
               when 16#80# => Append_Text ("r");
               when 16#81# => Append_Text ("s");
               when 16#82# => Append_Text ("t");
               when 16#83# => Append_Text ("u");
               when 16#84# => Append_Text ("f");
               when 16#85# => Append_Text ("kh");
               when 16#86# => Append_Text ("ts");
               when 16#87# => Append_Text ("ch");
               when 16#88# => Append_Text ("sh");
               when 16#89# => Append_Text ("shch");
               when 16#8A# => Append_Text ("""");
               when 16#8B# => Append_Text ("y");
               when 16#8C# => Append_Text ("'");
               when 16#8D# => Append_Text ("e");
               when 16#8E# => Append_Text ("yu");
               when 16#8F# => Append_Text ("ya");
               when 16#91# => Append_Text ("yo");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D8# then
            case Byte_At (1) is
               when 16#A1# => Append_Text ("'");
               when 16#A2# | 16#A3# | 16#A5# | 16#A7# => Append_Text ("a");
               when 16#A4# => Append_Text ("w");
               when 16#A6# => Append_Text ("y");
               when 16#A8# => Append_Text ("b");
               when 16#A9# => Append_Text ("h");
               when 16#AA# => Append_Text ("t");
               when 16#AB# => Append_Text ("th");
               when 16#AC# => Append_Text ("j");
               when 16#AD# => Append_Text ("h");
               when 16#AE# => Append_Text ("kh");
               when 16#AF# => Append_Text ("d");
               when 16#B0# => Append_Text ("dh");
               when 16#B1# => Append_Text ("r");
               when 16#B2# => Append_Text ("z");
               when 16#B3# => Append_Text ("s");
               when 16#B4# => Append_Text ("sh");
               when 16#B5# => Append_Text ("s");
               when 16#B6# => Append_Text ("d");
               when 16#B7# => Append_Text ("t");
               when 16#B8# => Append_Text ("z");
               when 16#B9# => Append_Text ("a");
               when 16#BA# => Append_Text ("gh");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D9# then
            case Byte_At (1) is
               when 16#81# => Append_Text ("f");
               when 16#82# => Append_Text ("q");
               when 16#83# => Append_Text ("k");
               when 16#84# => Append_Text ("l");
               when 16#85# => Append_Text ("m");
               when 16#86# => Append_Text ("n");
               when 16#87# => Append_Text ("h");
               when 16#88# => Append_Text ("w");
               when 16#89# => Append_Text ("a");
               when 16#8A# => Append_Text ("y");
               when 16#BE# => Append_Text ("p");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#DA# then
            case Byte_At (1) is
               when 16#86# => Append_Text ("ch");
               when 16#98# => Append_Text ("zh");
               when 16#A9# => Append_Text ("k");
               when 16#AF# => Append_Text ("g");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#DB# then
            case Byte_At (1) is
               when 16#8C# => Append_Text ("y");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) = 16#BC#
           and then (Byte_At (2) in 16#90# .. 16#99#
                     or else Byte_At (2) in 16#A1# .. 16#BA#)
         then
            if Byte_At (2) in 16#90# .. 16#99# then
               Append_Char
                 (Character'Val
                    (Character'Pos ('0') + Byte_At (2) - 16#90#));
            else
               Append_Char
                 (Character'Val
                    (Character'Pos ('A') + Byte_At (2) - 16#A1#));
            end if;
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) = 16#BD#
           and then Byte_At (2) in 16#81# .. 16#9A#
         then
            Append_Char
              (Character'Val (Character'Pos ('a') + Byte_At (2) - 16#81#));
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) = 16#AC#
           and then Byte_At (2) in 16#80# .. 16#86#
         then
            case Byte_At (2) is
               when 16#80# => Append_Text ("ff");
               when 16#81# => Append_Text ("fi");
               when 16#82# => Append_Text ("fl");
               when 16#83# => Append_Text ("ffi");
               when 16#84# => Append_Text ("ffl");
               when 16#85# | 16#86# => Append_Text ("st");
               when others => Append_Original (3);
            end case;
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#AD# | 16#AE# | 16#AF#
           and then ((Byte_At (1) = 16#AD#
                      and then (Byte_At (2) in 16#96# .. 16#99#
                                or else Byte_At (2) in 16#BA# .. 16#BD#))
                     or else (Byte_At (1) = 16#AE#
                              and then (Byte_At (2) in 16#8A# .. 16#8B#
                                        or else
                                        Byte_At (2) in 16#8E# .. 16#95#))
                     or else (Byte_At (1) = 16#AF#
                              and then (Byte_At (2) in 16#A8# .. 16#A9#
                                        or else
                                        Byte_At (2) in 16#BC# .. 16#BF#)))
         then
            if Byte_At (1) = 16#AD# then
               case Byte_At (2) is
                  when 16#96# .. 16#99# => Append_Text ("p");
                  when 16#BA# .. 16#BD# => Append_Text ("ch");
                  when others => Append_Original (3);
               end case;
            elsif Byte_At (1) = 16#AE# then
               case Byte_At (2) is
                  when 16#8A# | 16#8B# => Append_Text ("zh");
                  when 16#8E# .. 16#91# => Append_Text ("k");
                  when 16#92# .. 16#95# => Append_Text ("g");
                  when others => Append_Original (3);
               end case;
            else
               case Byte_At (2) is
                  when 16#A8# | 16#A9# => Append_Text ("a");
                  when 16#BC# .. 16#BF# => Append_Text ("y");
                  when others => Append_Original (3);
               end case;
            end if;
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#B5# .. 16#B7#
           and then Arabic_Presentation_A_Four_Letter_Ligature_Key_Code
             (Byte_At (1), Byte_At (2)) /= 0
         then
            Append_Arabic_Packed_Four_ASCII
              (Arabic_Presentation_A_Four_Letter_Ligature_Key_Code
                 (Byte_At (1), Byte_At (2)));
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#B5# .. 16#B7#
           and then Arabic_Presentation_A_Three_Letter_Ligature_Key_Code
             (Byte_At (1), Byte_At (2)) /= 0
         then
            Append_Arabic_Packed_Three_ASCII
              (Arabic_Presentation_A_Three_Letter_Ligature_Key_Code
                 (Byte_At (1), Byte_At (2)));
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#AF# .. 16#B4#
           and then Arabic_Presentation_A_Two_Letter_Ligature_Key_Code
             (Byte_At (1), Byte_At (2)) /= 0
         then
            declare
               Packed : constant Natural :=
                 Arabic_Presentation_A_Two_Letter_Ligature_Key_Code
                   (Byte_At (1), Byte_At (2));
            begin
               Append_Arabic_Codepoint_ASCII (Packed / 16#10000#);
               Append_Arabic_Codepoint_ASCII (Packed mod 16#10000#);
            end;
            Index := Index + 3;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#BA# | 16#BB#
         then
            if Byte_At (1) = 16#BA# then
               case Byte_At (2) is
                  when 16#80# => Append_Text ("'");
                  when 16#81# .. 16#84# => Append_Text ("a");
                  when 16#85# | 16#86# => Append_Text ("w");
                  when 16#87# | 16#88# => Append_Text ("a");
                  when 16#89# .. 16#8C# => Append_Text ("y");
                  when 16#8D# | 16#8E# => Append_Text ("a");
                  when 16#8F# .. 16#92# => Append_Text ("b");
                  when 16#93# | 16#94# => Append_Text ("h");
                  when 16#95# .. 16#98# => Append_Text ("t");
                  when 16#99# .. 16#9C# => Append_Text ("th");
                  when 16#9D# .. 16#A0# => Append_Text ("j");
                  when 16#A1# .. 16#A4# => Append_Text ("h");
                  when 16#A5# .. 16#A8# => Append_Text ("kh");
                  when 16#A9# | 16#AA# => Append_Text ("d");
                  when 16#AB# | 16#AC# => Append_Text ("dh");
                  when 16#AD# | 16#AE# => Append_Text ("r");
                  when 16#AF# | 16#B0# => Append_Text ("z");
                  when 16#B1# .. 16#B4# => Append_Text ("s");
                  when 16#B5# .. 16#B8# => Append_Text ("sh");
                  when 16#B9# .. 16#BC# => Append_Text ("s");
                  when 16#BD# .. 16#BF# => Append_Text ("d");
                  when others => Append_Original (3);
               end case;
            else
               case Byte_At (2) is
                  when 16#80# => Append_Text ("d");
                  when 16#81# .. 16#84# => Append_Text ("t");
                  when 16#85# .. 16#88# => Append_Text ("z");
                  when 16#89# .. 16#8C# => Append_Text ("a");
                  when 16#8D# .. 16#90# => Append_Text ("gh");
                  when 16#91# .. 16#94# => Append_Text ("f");
                  when 16#95# .. 16#98# => Append_Text ("q");
                  when 16#99# .. 16#9C# => Append_Text ("k");
                  when 16#9D# .. 16#A0# => Append_Text ("l");
                  when 16#A1# .. 16#A4# => Append_Text ("m");
                  when 16#A5# .. 16#A8# => Append_Text ("n");
                  when 16#A9# .. 16#AC# => Append_Text ("h");
                  when 16#AD# | 16#AE# => Append_Text ("w");
                  when 16#AF# | 16#B0# => Append_Text ("a");
                  when 16#B1# .. 16#B4# => Append_Text ("y");
                  when 16#B5# .. 16#BC# => Append_Text ("la");
                  when others => Append_Original (3);
               end case;
            end if;
            Index := Index + 3;
         elsif Index < Text'Last and then Byte_At (0) = 16#D7# then
            case Byte_At (1) is
               when 16#90# => Append_Text ("a");
               when 16#91# => Append_Text ("b");
               when 16#92# => Append_Text ("g");
               when 16#93# => Append_Text ("d");
               when 16#94# => Append_Text ("h");
               when 16#95# => Append_Text ("v");
               when 16#96# => Append_Text ("z");
               when 16#97# => Append_Text ("kh");
               when 16#98# => Append_Text ("t");
               when 16#99# => Append_Text ("y");
               when 16#9A# | 16#9B# => Append_Text ("k");
               when 16#9C# => Append_Text ("l");
               when 16#9D# | 16#9E# => Append_Text ("m");
               when 16#9F# | 16#A0# => Append_Text ("n");
               when 16#A1# => Append_Text ("s");
               when 16#A2# => Append_Text ("a");
               when 16#A3# | 16#A4# => Append_Text ("p");
               when 16#A5# | 16#A6# => Append_Text ("ts");
               when 16#A7# => Append_Text ("q");
               when 16#A8# => Append_Text ("r");
               when 16#A9# => Append_Text ("sh");
               when 16#AA# => Append_Text ("t");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index + 2 <= Text'Last
           and then Byte_At (0) = 16#EF#
           and then Byte_At (1) in 16#AC# | 16#AD#
         then
            if Byte_At (1) = 16#AC# then
               case Byte_At (2) is
                  when 16#AA# .. 16#AD# => Append_Text ("sh");
                  when 16#AE# .. 16#B0# => Append_Text ("a");
                  when 16#B1# => Append_Text ("b");
                  when 16#B2# => Append_Text ("g");
                  when 16#B3# => Append_Text ("d");
                  when 16#B4# => Append_Text ("h");
                  when 16#B5# => Append_Text ("v");
                  when 16#B7# => Append_Text ("z");
                  when 16#B8# => Append_Text ("t");
                  when 16#B9# => Append_Text ("y");
                  when 16#BA# | 16#BB# => Append_Text ("k");
                  when 16#BC# => Append_Text ("l");
                  when 16#BE# => Append_Text ("m");
                  when others => Append_Original (3);
               end case;
            else
               case Byte_At (2) is
                  when 16#80# => Append_Text ("n");
                  when 16#81# => Append_Text ("s");
                  when 16#83# | 16#84# => Append_Text ("p");
                  when 16#86# => Append_Text ("ts");
                  when 16#87# => Append_Text ("q");
                  when 16#88# => Append_Text ("r");
                  when 16#89# => Append_Text ("sh");
                  when 16#8A# => Append_Text ("t");
                  when 16#8B# => Append_Text ("v");
                  when 16#8C# => Append_Text ("b");
                  when 16#8D# => Append_Text ("k");
                  when 16#8E# => Append_Text ("p");
                  when 16#8F# => Append_Text ("al");
                  when others => Append_Original (3);
               end case;
            end if;
            Index := Index + 3;
         elsif Index < Text'Last and then Byte_At (0) = 16#D4# then
            case Byte_At (1) is
               when 16#B1# => Append_Text ("A");
               when 16#B2# => Append_Text ("B");
               when 16#B3# => Append_Text ("G");
               when 16#B4# => Append_Text ("D");
               when 16#B5# => Append_Text ("E");
               when 16#B6# => Append_Text ("Z");
               when 16#B7# => Append_Text ("E");
               when 16#B8# => Append_Text ("Y");
               when 16#B9# => Append_Text ("T");
               when 16#BA# => Append_Text ("Zh");
               when 16#BB# => Append_Text ("I");
               when 16#BC# => Append_Text ("L");
               when 16#BD# => Append_Text ("Kh");
               when 16#BE# => Append_Text ("Ts");
               when 16#BF# => Append_Text ("K");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D5# then
            case Byte_At (1) is
               when 16#80# => Append_Text ("H");
               when 16#81# => Append_Text ("Dz");
               when 16#82# => Append_Text ("Gh");
               when 16#83# => Append_Text ("Ch");
               when 16#84# => Append_Text ("M");
               when 16#85# => Append_Text ("Y");
               when 16#86# => Append_Text ("N");
               when 16#87# => Append_Text ("Sh");
               when 16#88# => Append_Text ("O");
               when 16#89# => Append_Text ("Ch");
               when 16#8A# => Append_Text ("P");
               when 16#8B# => Append_Text ("J");
               when 16#8C# => Append_Text ("R");
               when 16#8D# => Append_Text ("S");
               when 16#8E# => Append_Text ("V");
               when 16#8F# => Append_Text ("T");
               when 16#90# => Append_Text ("R");
               when 16#91# => Append_Text ("Ts");
               when 16#92# => Append_Text ("W");
               when 16#93# => Append_Text ("P");
               when 16#94# => Append_Text ("K");
               when 16#95# => Append_Text ("O");
               when 16#96# => Append_Text ("F");
               when 16#A1# => Append_Text ("a");
               when 16#A2# => Append_Text ("b");
               when 16#A3# => Append_Text ("g");
               when 16#A4# => Append_Text ("d");
               when 16#A5# => Append_Text ("e");
               when 16#A6# => Append_Text ("z");
               when 16#A7# => Append_Text ("e");
               when 16#A8# => Append_Text ("y");
               when 16#A9# => Append_Text ("t");
               when 16#AA# => Append_Text ("zh");
               when 16#AB# => Append_Text ("i");
               when 16#AC# => Append_Text ("l");
               when 16#AD# => Append_Text ("kh");
               when 16#AE# => Append_Text ("ts");
               when 16#AF# => Append_Text ("k");
               when 16#B0# => Append_Text ("h");
               when 16#B1# => Append_Text ("dz");
               when 16#B2# => Append_Text ("gh");
               when 16#B3# => Append_Text ("ch");
               when 16#B4# => Append_Text ("m");
               when 16#B5# => Append_Text ("y");
               when 16#B6# => Append_Text ("n");
               when 16#B7# => Append_Text ("sh");
               when 16#B8# => Append_Text ("o");
               when 16#B9# => Append_Text ("ch");
               when 16#BA# => Append_Text ("p");
               when 16#BB# => Append_Text ("j");
               when 16#BC# => Append_Text ("r");
               when 16#BD# => Append_Text ("s");
               when 16#BE# => Append_Text ("v");
               when 16#BF# => Append_Text ("t");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         elsif Index < Text'Last and then Byte_At (0) = 16#D6# then
            case Byte_At (1) is
               when 16#80# => Append_Text ("r");
               when 16#81# => Append_Text ("ts");
               when 16#82# => Append_Text ("w");
               when 16#83# => Append_Text ("p");
               when 16#84# => Append_Text ("k");
               when 16#85# => Append_Text ("o");
               when 16#86# => Append_Text ("f");
               when others => Append_Original (2);
            end case;
            Index := Index + 2;
         else
            Append_Original (UTF8_Unit_Length (Text, Index));
            Index := Index + UTF8_Unit_Length (Text, Index);
         end if;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end Transliterate_ASCII;

   function Direction
     (Item : Locale_Id)
      return Text_Direction
   is
      Language : constant String := Primary_Language (Item);
      Script   : constant String := I18N.Locales.Script (Item);
   begin
      if Script = "Arab"
        or else Script = "Hebr"
        or else Script = "Thaa"
        or else Script = "Nkoo"
        or else Script = "Adlm"
        or else Script = "Rohg"
        or else Script = "Syrc"
        or else Script = "Mand"
        or else Language = "ar"
        or else Language = "fa"
        or else Language = "he"
        or else Language = "ur"
        or else Language = "yi"
        or else Language = "ps"
        or else Language = "sd"
        or else Language = "ug"
      then
         return Right_To_Left;
      else
         return Left_To_Right;
      end if;
   end Direction;

   function Is_Right_To_Left
     (Item : Locale_Id)
      return Boolean
   is
   begin
      return Direction (Item) = Right_To_Left;
   end Is_Right_To_Left;

   function Subtag_Count (Item : String) return Natural is
      Count : Natural := 0;
   begin
      if Item'Length = 0 then
         return 0;
      end if;

      Count := 1;
      for C of Item loop
         if C = '-' then
            Count := Count + 1;
         end if;
      end loop;

      return Count;
   end Subtag_Count;

   function Subtag (Item : String; Position : Positive) return String is
      First : Positive := Item'First;
      Count : Natural := 1;
   begin
      for Index in Item'Range loop
         if Item (Index) = '-' then
            if Count = Position then
               return Item (First .. Index - 1);
            end if;
            First := Index + 1;
            Count := Count + 1;
         end if;
      end loop;

      if Count = Position and then First <= Item'Last then
         return Item (First .. Item'Last);
      end if;

      return "";
   end Subtag;

   function Likely_Script (Language : String) return String is
   begin
      if Language = "ar" then
         return "Arab";
      elsif Language = "bn" then
         return "Beng";
      elsif Language = "fa" then
         return "Arab";
      elsif Language = "he" or else Language = "yi" then
         return "Hebr";
      elsif Language = "hi" then
         return "Deva";
      elsif Language = "ja" then
         return "Jpan";
      elsif Language = "ko" then
         return "Kore";
      elsif Language = "ru" then
         return "Cyrl";
      elsif Language = "sr" then
         return "Cyrl";
      elsif Language = "th" then
         return "Thai";
      elsif Language = "uk" then
         return "Cyrl";
      elsif Language = "zh" then
         return "Hans";
      else
         return "Latn";
      end if;
   end Likely_Script;

   function Likely_Region (Language : String) return String is
   begin
      if Language = "ar" then
         return "EG";
      elsif Language = "bn" then
         return "BD";
      elsif Language = "fa" then
         return "IR";
      elsif Language = "he" or else Language = "yi" then
         return "IL";
      elsif Language = "hi" then
         return "IN";
      elsif Language = "ja" then
         return "JP";
      elsif Language = "ko" then
         return "KR";
      elsif Language = "ru" then
         return "RU";
      elsif Language = "sr" then
         return "RS";
      elsif Language = "th" then
         return "TH";
      elsif Language = "uk" then
         return "UA";
      elsif Language = "zh" then
         return "CN";
      elsif Language = "de" then
         return "DE";
      elsif Language = "en" then
         return "US";
      elsif Language = "es" then
         return "ES";
      elsif Language = "fr" then
         return "FR";
      elsif Language = "id" then
         return "ID";
      elsif Language = "it" then
         return "IT";
      elsif Language = "nl" then
         return "NL";
      elsif Language = "pl" then
         return "PL";
      elsif Language = "pt" then
         return "BR";
      elsif Language = "ro" then
         return "RO";
      elsif Language = "tr" then
         return "TR";
      else
         return "001";
      end if;
   end Likely_Region;

   function Region_For_Script
     (Language : String;
      Script   : String;
      Default  : String)
      return String
   is
   begin
      if Language = "zh" and then Script = "Hant" then
         return "TW";
      elsif Language = "sr" and then Script = "Latn" then
         return "RS";
      else
         return Default;
      end if;
   end Region_For_Script;

   function Script_For_Region
     (Language : String;
      Region   : String;
      Default  : String)
      return String
   is
   begin
      if Language = "zh"
        and then (Region = "HK" or else Region = "MO" or else Region = "TW")
      then
         return "Hant";
      else
         return Default;
      end if;
   end Script_For_Region;

   function Maximize_Base (Item : String) return String is
      Count    : constant Natural := Subtag_Count (Item);
      Language : constant String := (if Count >= 1 then Subtag (Item, 1) else "");
      Script_Or_Region : constant String :=
        (if Count >= 2 then Subtag (Item, 2) else "");
      Third    : constant String := (if Count >= 3 then Subtag (Item, 3) else "");
      Default_Script : constant String := Likely_Script (Language);
      Default_Region : constant String := Likely_Region (Language);
   begin
      if Language'Length = 0 then
         return Item;
      end if;

      if Count = 1 then
         return Language & "-" & Default_Script & "-" & Default_Region;
      elsif Count = 2 and then Script_Or_Region'Length = 4 then
         return Language & "-" & Script_Or_Region & "-"
           & Region_For_Script (Language, Script_Or_Region, Default_Region);
      elsif Count = 2 then
         return Language & "-"
           & Script_For_Region (Language, Script_Or_Region, Default_Script)
           & "-" & Script_Or_Region;
      elsif Count = 3 then
         return Language & "-" & Script_Or_Region & "-" & Third;
      else
         return Item;
      end if;
   end Maximize_Base;

   function Maximize
     (Item : Locale_Id)
      return String
   is
      Canonical : constant String := Canonicalize (Item);
      Base      : constant String := Base_Locale (Canonical);
      Ext       : constant String := Extension_Locale (Canonical);
      Expanded  : constant String := Maximize_Base (Base);
   begin
      if Ext'Length = 0 then
         return Expanded;
      elsif Expanded'Length = 0 then
         return Ext;
      else
         return Expanded & "-" & Ext;
      end if;
   end Maximize;

   function Minimize
     (Item : Locale_Id)
      return String
   is
      Canonical : constant String := Canonicalize (Item);
      Base      : constant String := Base_Locale (Canonical);
      Ext       : constant String := Extension_Locale (Canonical);
      Expanded  : constant String := Maximize_Base (Base);
      Count     : constant Natural := Subtag_Count (Expanded);
   begin
      if Count < 3 then
         return Canonical;
      end if;

      declare
         Language : constant String := Subtag (Expanded, 1);
         Script   : constant String := Subtag (Expanded, 2);
         Region   : constant String := Subtag (Expanded, 3);
         Lang_Only : constant String := Language;
         Lang_Script : constant String := Language & "-" & Script;
         Lang_Region : constant String := Language & "-" & Region;
         Min_Base : constant String :=
           (if Maximize_Base (Lang_Only) = Expanded then Lang_Only
            elsif Maximize_Base (Lang_Script) = Expanded then Lang_Script
            elsif Maximize_Base (Lang_Region) = Expanded then Lang_Region
            else Expanded);
      begin
         if Ext'Length = 0 then
            return Min_Base;
         else
            return Min_Base & "-" & Ext;
         end if;
      end;
   end Minimize;

   function Token_End (Text : String; Start : Positive) return Natural is
   begin
      for Index in Start .. Text'Last loop
         if Text (Index) = ',' then
            return Index - 1;
         end if;
      end loop;

      return Text'Last;
   end Token_End;

   function Next_Start (Text : String; End_Index : Natural) return Natural is
   begin
      if End_Index >= Text'Last then
         return Text'Last + 1;
      else
         return End_Index + 2;
      end if;
   end Next_Start;

   function Semicolon_Index (Text : String) return Natural is
   begin
      for Index in Text'Range loop
         if Text (Index) = ';' then
            return Index;
         end if;
      end loop;

      return 0;
   end Semicolon_Index;

   function Q_Value (Text : String) return Natural is
      Semi : constant Natural := Semicolon_Index (Text);
      Q    : Natural := 1000;
   begin
      if Semi = 0 then
         return Q;
      end if;

      declare
         Params : constant String := Lower_ASCII
           (Ada.Strings.Fixed.Trim
              (Text (Semi + 1 .. Text'Last), Ada.Strings.Both));
         Eq     : Natural := 0;
      begin
         for Index in Params'Range loop
            if Params (Index) = '=' then
               Eq := Index;
               exit;
            end if;
         end loop;

         if Eq = 0
           or else Ada.Strings.Fixed.Trim
             (Params (Params'First .. Eq - 1), Ada.Strings.Both) /= "q"
         then
            return Q;
         end if;

         declare
            Value : constant String := Ada.Strings.Fixed.Trim
              (Params (Eq + 1 .. Params'Last), Ada.Strings.Both);
            Digit_Count : Natural := 0;
         begin
            if Value = "1" or else Value = "1.0"
              or else Value = "1.00" or else Value = "1.000"
            then
               return 1000;
            elsif Value'Length >= 1 and then Value (Value'First) = '0' then
               Q := 0;
               if Value'Length = 1 then
                  return Q;
               elsif Value'Length >= 2 and then Value (Value'First + 1) = '.'
               then
                  for Index in Value'First + 2 .. Value'Last loop
                     exit when Digit_Count = 3;
                     if Value (Index) not in '0' .. '9' then
                        return 0;
                     end if;
                     Q := Q * 10
                       + Character'Pos (Value (Index)) - Character'Pos ('0');
                     Digit_Count := Digit_Count + 1;
                  end loop;

                  while Digit_Count < 3 loop
                     Q := Q * 10;
                     Digit_Count := Digit_Count + 1;
                  end loop;

                  return Q;
               end if;
            end if;
         end;
      end;

      return 0;
   end Q_Value;

   function Range_Text (Text : String) return String is
      Semi : constant Natural := Semicolon_Index (Text);
   begin
      if Semi = 0 then
         return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      elsif Semi = Text'First then
         return "";
      else
         return Ada.Strings.Fixed.Trim
           (Text (Text'First .. Semi - 1), Ada.Strings.Both);
      end if;
   end Range_Text;

   function Parent_Chain_Matches
     (Child  : String;
      Parent : String)
      return Boolean
   is
   begin
      if Child = Parent then
         return True;
      end if;

      declare
         Next : constant String := I18N.Locales.Parent (Child);
      begin
         if Next'Length = 0 then
            return False;
         else
            return Parent_Chain_Matches (Next, Parent);
         end if;
      end;
   end Parent_Chain_Matches;

   function Match_Score
     (Requested : String;
      Available : String)
      return Natural
   is
      Req : constant String := Canonicalize (Requested);
      Av  : constant String := Canonicalize (Available);
   begin
      if Requested = "*" then
         return 10;
      elsif Req'Length = 0 or else Av'Length = 0 then
         return 0;
      elsif Req = Av then
         return 100;
      elsif Maximize (Req) = Maximize (Av) then
         return 90;
      elsif Parent_Chain_Matches (Maximize (Req), Av) then
         return 85;
      elsif Parent_Chain_Matches (Req, Av) then
         return 80;
      elsif Parent_Chain_Matches (Av, Req) then
         return 70;
      else
         return 0;
      end if;
   end Match_Score;

   function Match
     (Available_Locales : String;
      Requested_Ranges  : String;
      Default           : Locale_Id := "")
      return String
   is
      Best_Q          : Natural := 0;
      Best_Score      : Natural := 0;
      Best_Request    : Natural := Natural'Last;
      Best_Available  : Natural := Natural'Last;
      Best            : String (1 .. Available_Locales'Length + 5);
      Best_Last       : Natural := 0;
      Request_Start   : Natural :=
        (if Requested_Ranges'Length = 0 then Requested_Ranges'Last + 1
         else Requested_Ranges'First);
      Request_Order   : Natural := 0;

      procedure Set_Best (Value : String) is
      begin
         Best_Last := Value'Length;
         if Best_Last > 0 then
            Best (1 .. Best_Last) := Value;
         end if;
      end Set_Best;
   begin
      while Request_Start <= Requested_Ranges'Last loop
         declare
            Request_End : constant Natural :=
              Token_End (Requested_Ranges, Request_Start);
            Request_Token : constant String := Requested_Ranges
              (Request_Start .. Request_End);
            Request_Range : constant String := Range_Text (Request_Token);
            Request_Q : constant Natural := Q_Value (Request_Token);
            Available_Start : Natural :=
              (if Available_Locales'Length = 0 then Available_Locales'Last + 1
               else Available_Locales'First);
            Available_Order : Natural := 0;
         begin
            Request_Order := Request_Order + 1;
            if Request_Q > 0 and then Request_Range'Length > 0 then
               while Available_Start <= Available_Locales'Last loop
                  declare
                     Available_End : constant Natural :=
                       Token_End (Available_Locales, Available_Start);
                     Available_Token : constant String :=
                       Ada.Strings.Fixed.Trim
                         (Available_Locales
                            (Available_Start .. Available_End),
                          Ada.Strings.Both);
                     Score : constant Natural :=
                       Match_Score (Request_Range, Available_Token);
                     Better : constant Boolean :=
                       Score > 0
                       and then
                         (Request_Q > Best_Q
                          or else (Request_Q = Best_Q
                                   and then Score > Best_Score)
                          or else (Request_Q = Best_Q
                                   and then Score = Best_Score
                                   and then Request_Order < Best_Request)
                          or else (Request_Q = Best_Q
                                   and then Score = Best_Score
                                   and then Request_Order = Best_Request
                                   and then Available_Order < Best_Available));
                  begin
                     Available_Order := Available_Order + 1;
                     if Better then
                        Best_Q := Request_Q;
                        Best_Score := Score;
                        Best_Request := Request_Order;
                        Best_Available := Available_Order;
                        Set_Best (Canonicalize (Available_Token));
                     end if;
                     Available_Start :=
                       Next_Start (Available_Locales, Available_End);
                  end;
               end loop;
            end if;
            Request_Start := Next_Start (Requested_Ranges, Request_End);
         end;
      end loop;

      if Best_Last > 0 then
         return Best (1 .. Best_Last);
      else
         return Canonicalize (Default);
      end if;
   end Match;

   function Is_Bounded_Combining_Mark (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index < Text'Last then Character'Pos (Text (Index + 1)) else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return (Index < Text'Last
              and then ((B1 = 16#CC# and then B2 in 16#80# .. 16#BF#)
                        or else (B1 = 16#CD# and then B2 in 16#80# .. 16#AF#)
                        or else (B1 = 16#D6#
                                 and then (B2 in 16#91# .. 16#BD#
                                           or else B2 = 16#BF#))
                        or else (B1 = 16#D7#
                                 and then (B2 in 16#81# .. 16#82#
                                           or else B2 in 16#84# .. 16#85#
                                           or else B2 = 16#87#))
                        or else (B1 = 16#DC#
                                 and then (B2 = 16#91#
                                           or else B2 in 16#B0# .. 16#BF#))
                        or else (B1 = 16#DD#
                                 and then B2 in 16#80# .. 16#8A#)
                        or else (B1 = 16#DE#
                                 and then B2 in 16#A6# .. 16#B0#)
                        or else (B1 = 16#DF#
                                 and then B2 in 16#AB# .. 16#B3#)
                        or else (B1 = 16#D9#
                                 and then (B2 in 16#8B# .. 16#9F#
                                           or else B2 = 16#B0#))))
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E0#
                 and then ((B2 = 16#A0#
                            and then (B3 in 16#96# .. 16#99#
                                      or else B3 in 16#9B# .. 16#A3#
                                      or else B3 in 16#A5# .. 16#A7#
                                      or else B3 in 16#A9# .. 16#AD#))
                           or else
                             (B2 = 16#A1# and then B3 in 16#99# .. 16#9B#)))
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E1#
                 and then ((B2 = 16#AA# and then B3 in 16#B0# .. 16#BF#)
                           or else
                             (B2 = 16#AB# and then B3 in 16#80# .. 16#BF#)
                           or else
                             (B2 = 16#B7# and then B3 in 16#80# .. 16#BF#)))
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E2#
                 and then B2 = 16#83#
                 and then B3 in 16#90# .. 16#BF#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#EF#
                 and then B2 = 16#B8#
                 and then B3 in 16#A0# .. 16#AF#);
   end Is_Bounded_Combining_Mark;

   function Bounded_Combining_Mark_Length
     (Text  : String;
      Index : Natural)
      return Natural
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      if Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then ((B2 = 16#A0#
                   and then (B3 in 16#96# .. 16#99#
                             or else B3 in 16#9B# .. 16#A3#
                             or else B3 in 16#A5# .. 16#A7#
                             or else B3 in 16#A9# .. 16#AD#))
                  or else (B2 = 16#A1# and then B3 in 16#99# .. 16#9B#))
      then
         return 3;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then ((B2 = 16#AA# and then B3 in 16#B0# .. 16#BF#)
                  or else (B2 = 16#AB# and then B3 in 16#80# .. 16#BF#)
                  or else (B2 = 16#B7# and then B3 in 16#80# .. 16#BF#))
      then
         return 3;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E2#
        and then B2 = 16#83#
        and then B3 in 16#90# .. 16#BF#
      then
         return 3;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EF#
        and then B2 = 16#B8#
        and then B3 in 16#A0# .. 16#AF#
      then
         return 3;
      elsif Is_Bounded_Combining_Mark (Text, Index) then
         return 2;
      else
         return 0;
      end if;
   end Bounded_Combining_Mark_Length;

   function Is_Bounded_Indic_Thai_Grapheme_Extend
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      if Index + 2 > Text'Last then
         return False;
      elsif B1 = 16#E1# and then B2 = 16#9E# then
         --  Khmer dependent vowel signs U+17B6..U+17BF.
         return B3 in 16#B6# .. 16#BF#;
      elsif B1 = 16#E1# and then B2 = 16#9F# then
         --  Khmer signs U+17C0..U+17D3 plus atthacan U+17DD.
         return B3 in 16#80# .. 16#93# or else B3 = 16#9D#;
      elsif B1 /= 16#E0# then
         return False;
      elsif B2 = 16#A4# then
         --  Devanagari dependent vowel signs and virama U+093E..U+094D.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#A5# then
         --  Devanagari marks U+0940..U+094D.
         return B3 in 16#80# .. 16#8D#;
      elsif B2 = 16#A6# then
         --  Bengali dependent vowel signs U+09BE..U+09C4.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#A7# then
         --  Bengali marks U+09C0..U+09CD.
         return B3 in 16#80# .. 16#84# or else B3 = 16#8D#;
      elsif B2 = 16#A8# then
         --  Gurmukhi dependent vowel signs U+0A3E..U+0A4D.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#A9# then
         --  Gurmukhi marks U+0A40..U+0A4D plus bounded addak/tippi marks.
         return B3 in 16#80# .. 16#8D#
           or else B3 = 16#91#
           or else B3 in 16#B0# .. 16#B1#
           or else B3 = 16#B5#;
      elsif B2 = 16#AA# then
         --  Gujarati dependent vowel signs U+0ABE..U+0ACD.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#AB# then
         --  Gujarati marks U+0AC0..U+0ACD and vocalic signs U+0AE2..U+0AE3.
         return B3 in 16#80# .. 16#8D#
           or else B3 in 16#A2# .. 16#A3#;
      elsif B2 = 16#AC# then
         --  Odia dependent vowel signs U+0B3E..U+0B4D.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#AD# then
         --  Odia marks U+0B40..U+0B4D, ai length marks, and vocalic signs.
         return B3 in 16#80# .. 16#8D#
           or else B3 in 16#96# .. 16#97#
           or else B3 in 16#A2# .. 16#A3#;
      elsif B2 = 16#AE# then
         --  Tamil dependent vowel signs U+0BBE..U+0BCD.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#AF# then
         --  Tamil marks U+0BC0..U+0BCD.
         return B3 in 16#80# .. 16#8D#;
      elsif B2 = 16#B0# then
         --  Telugu dependent vowel signs U+0C3E..U+0C4D.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#B1# then
         --  Telugu marks U+0C40..U+0C4D, length marks, and vocalic signs.
         return B3 in 16#80# .. 16#8D#
           or else B3 in 16#95# .. 16#96#
           or else B3 in 16#A2# .. 16#A3#;
      elsif B2 = 16#B2# then
         --  Kannada dependent vowel signs U+0CBE..U+0CCD.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#B3# then
         --  Kannada marks U+0CC0..U+0CCD, length marks, and vocalic signs.
         return B3 in 16#80# .. 16#8D#
           or else B3 in 16#95# .. 16#96#
           or else B3 in 16#A2# .. 16#A3#;
      elsif B2 = 16#B4# then
         --  Malayalam dependent vowel signs U+0D3E..U+0D4D.
         return B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#B5# then
         --  Malayalam marks U+0D40..U+0D4D, au length mark, and vocalic signs.
         return B3 in 16#80# .. 16#8D#
           or else B3 = 16#97#
           or else B3 in 16#A2# .. 16#A3#;
      elsif B2 = 16#B7# then
         --  Sinhala vowel signs U+0DCA and U+0DCF..U+0DDF.
         return B3 = 16#8A# or else B3 in 16#8F# .. 16#9F#;
      elsif B2 = 16#B8# then
         --  Thai signs U+0E31 and U+0E34..U+0E3A.
         return B3 = 16#B1# or else B3 in 16#B4# .. 16#BA#;
      elsif B2 = 16#B9# then
         --  Thai signs U+0E47..U+0E4E.
         return B3 in 16#87# .. 16#8E#;
      elsif B2 = 16#BA# then
         --  Lao vowel signs U+0EB1..U+0EBC.
         return B3 in 16#B1# .. 16#BC#;
      elsif B2 = 16#BB# then
         --  Lao tone marks U+0EC8..U+0ECD.
         return B3 in 16#88# .. 16#8D#;
      elsif B2 = 16#BC# then
         --  Tibetan signs U+0F35, U+0F37, U+0F39, and U+0F3E..U+0F3F.
         return B3 in 16#B5# | 16#B7# | 16#B9#
           or else B3 in 16#BE# .. 16#BF#;
      elsif B2 = 16#BD# then
         --  Tibetan vowel signs U+0F71..U+0F7F.
         return B3 in 16#B1# .. 16#BF#;
      elsif B2 = 16#BE# then
         --  Tibetan vowel/sign continuation U+0F80..U+0F87.
         return B3 in 16#80# .. 16#87#;
      else
         return False;
      end if;
   end Is_Bounded_Indic_Thai_Grapheme_Extend;

   function Is_Bounded_Grapheme_Prepend
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
      B4 : constant Natural :=
        (if Index + 3 <= Text'Last then Character'Pos (Text (Index + 3))
         else 0);
   begin
      return (Index + 1 <= Text'Last
              and then ((B1 = 16#D8# and then B2 in 16#80# .. 16#85#)
                        or else (B1 = 16#DB# and then B2 = 16#9D#)
                        or else (B1 = 16#DC# and then B2 = 16#8F#)))
        or else (Index + 2 <= Text'Last
                 and then ((B1 = 16#E0# and then B2 = 16#A2#
                            and then B3 in 16#90# .. 16#91#)
                           or else (B1 = 16#E0# and then B2 = 16#A3#
                                    and then B3 = 16#A2#)))
        or else (Index + 3 <= Text'Last
                 and then B1 = 16#F0#
                 and then B2 = 16#91#
                 and then ((B3 = 16#82# and then B4 = 16#BD#)
                           or else (B3 = 16#83# and then B4 = 16#8D#)));
   end Is_Bounded_Grapheme_Prepend;

   function Grapheme_Prepend_Length
     (Text  : String;
      Index : Natural)
      return Natural
   is
      B1 : constant Natural := Character'Pos (Text (Index));
   begin
      if not Is_Bounded_Grapheme_Prepend (Text, Index) then
         return 0;
      elsif B1 = 16#F0# then
         return 4;
      elsif B1 = 16#E0# then
         return 3;
      else
         return 2;
      end if;
   end Grapheme_Prepend_Length;

   function Is_Bounded_Spacing_Mark
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      --  Myanmar spacing dependent vowel signs U+102B..U+1031 and U+1038.
      return Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#80#
        and then (B3 in 16#AB# .. 16#B1# or else B3 = 16#B8#);
   end Is_Bounded_Spacing_Mark;

   function Arabic_Presentation_B_Key_Code
     (Middle : Natural;
      Trail  : Natural)
      return Natural
   is
   begin
      if Middle = 16#BA# then
         case Trail is
            when 16#80# => return 16#D8A1#;
            when 16#81# | 16#82# => return 16#D8A2#;
            when 16#83# | 16#84# => return 16#D8A3#;
            when 16#85# | 16#86# => return 16#D8A4#;
            when 16#87# | 16#88# => return 16#D8A5#;
            when 16#89# .. 16#8C# => return 16#D8A6#;
            when 16#8D# | 16#8E# => return 16#D8A7#;
            when 16#8F# .. 16#92# => return 16#D8A8#;
            when 16#93# | 16#94# => return 16#D8A9#;
            when 16#95# .. 16#98# => return 16#D8AA#;
            when 16#99# .. 16#9C# => return 16#D8AB#;
            when 16#9D# .. 16#A0# => return 16#D8AC#;
            when 16#A1# .. 16#A4# => return 16#D8AD#;
            when 16#A5# .. 16#A8# => return 16#D8AE#;
            when 16#A9# | 16#AA# => return 16#D8AF#;
            when 16#AB# | 16#AC# => return 16#D8B0#;
            when 16#AD# | 16#AE# => return 16#D8B1#;
            when 16#AF# | 16#B0# => return 16#D8B2#;
            when 16#B1# .. 16#B4# => return 16#D8B3#;
            when 16#B5# .. 16#B8# => return 16#D8B4#;
            when 16#B9# .. 16#BC# => return 16#D8B5#;
            when 16#BD# .. 16#BF# => return 16#D8B6#;
            when others => return 0;
         end case;
      elsif Middle = 16#BB# then
         case Trail is
            when 16#80# => return 16#D8B6#;
            when 16#81# .. 16#84# => return 16#D8B7#;
            when 16#85# .. 16#88# => return 16#D8B8#;
            when 16#89# .. 16#8C# => return 16#D8B9#;
            when 16#8D# .. 16#90# => return 16#D8BA#;
            when 16#91# .. 16#94# => return 16#D981#;
            when 16#95# .. 16#98# => return 16#D982#;
            when 16#99# .. 16#9C# => return 16#D983#;
            when 16#9D# .. 16#A0# => return 16#D984#;
            when 16#A1# .. 16#A4# => return 16#D985#;
            when 16#A5# .. 16#A8# => return 16#D986#;
            when 16#A9# .. 16#AC# => return 16#D987#;
            when 16#AD# | 16#AE# => return 16#D988#;
            when 16#AF# | 16#B0# => return 16#D989#;
            when 16#B1# .. 16#B4# => return 16#D98A#;
            when 16#B5# | 16#B6# => return 16#100A2#;
            when 16#B7# | 16#B8# => return 16#100A3#;
            when 16#B9# | 16#BA# => return 16#100A5#;
            when 16#BB# | 16#BC# => return 16#100A7#;
            when others => return 0;
         end case;
      else
         return 0;
      end if;
   end Arabic_Presentation_B_Key_Code;

   function Arabic_Presentation_A_Single_Key_Code
     (Middle : Natural;
      Trail  : Natural)
      return Natural
   is
   begin
      if Middle = 16#AD# then
         case Trail is
            when 16#96# .. 16#99# => return 16#D9BE#;
            when 16#BA# .. 16#BD# => return 16#DA86#;
            when others => return 0;
         end case;
      elsif Middle = 16#AE# then
         case Trail is
            when 16#8A# | 16#8B# => return 16#DA98#;
            when 16#8E# .. 16#91# => return 16#DAA9#;
            when 16#92# .. 16#95# => return 16#DAAF#;
            when others => return 0;
         end case;
      elsif Middle = 16#AF# then
         case Trail is
            when 16#A8# | 16#A9# => return 16#D989#;
            when 16#BC# .. 16#BF# => return 16#DB8C#;
            when others => return 0;
         end case;
      else
         return 0;
      end if;
   end Arabic_Presentation_A_Single_Key_Code;

   function Sort_Key
     (Item   : String;
      Locale : Locale_Id := "")
      return String
   with
      SPARK_Mode => Off
   is
      Lang   : constant String := Language (Locale);
      Locale_Script : constant String := Script (Locale);
      Nordic : constant Boolean :=
        Lang = "sv" or else Lang = "da" or else Lang = "no";
      German : constant Boolean := Lang = "de";
      Numeric_Collation : constant Boolean :=
        Unicode_Extension (Locale, "kn") = "true";
      Czech_Slovak : constant Boolean := Lang = "cs" or else Lang = "sk";
      South_Slavic_Latin : constant Boolean :=
        (Lang = "bs" or else Lang = "hr" or else Lang = "sr")
        and then Locale_Script /= "Cyrl";
      Result : String (1 .. Natural'Max (Item'Length * 9, 1));
      Last   : Natural := 0;
      Index  : Natural :=
        (if Item'Length = 0 then Item'Last + 1 else Item'First);

      procedure Append_Text (Text : String) is
      begin
         if Text'Length > 0 then
            Result (Last + 1 .. Last + Text'Length) := Text;
            Last := Last + Text'Length;
         end if;
      end Append_Text;

      procedure Append_Char (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Append_Char;

      procedure Append_Natural_6 (Value : Natural) is
         Remaining : Natural := Natural'Min (Value, 999_999);
         Text       : String (1 .. 6) := [others => '0'];
      begin
         for Pos in reverse Text'Range loop
            Text (Pos) := Character'Val
              (Character'Pos ('0') + Remaining mod 10);
            Remaining := Remaining / 10;
         end loop;

         Append_Text (Text);
      end Append_Natural_6;

      function Is_Bounded_Han_Decimal_Digit (Digit_Index : Natural)
         return Boolean;

      function Collation_Digit_Length (Digit_Index : Natural) return Natural is
         B1 : constant Natural := Character'Pos (Item (Digit_Index));
         B2 : constant Natural :=
           (if Digit_Index + 1 <= Item'Last
            then Character'Pos (Item (Digit_Index + 1))
            else 0);
         B3 : constant Natural :=
           (if Digit_Index + 2 <= Item'Last
            then Character'Pos (Item (Digit_Index + 2))
            else 0);
         B4 : constant Natural :=
           (if Digit_Index + 3 <= Item'Last
            then Character'Pos (Item (Digit_Index + 3))
            else 0);
      begin
         if Item (Digit_Index) in '0' .. '9' then
            return 1;
         elsif Digit_Index + 1 <= Item'Last
           and then ((B1 = 16#D9# and then B2 in 16#A0# .. 16#A9#)
                     or else
                       (B1 = 16#DB# and then B2 in 16#B0# .. 16#B9#)
                     or else
                       (B1 = 16#DF# and then B2 in 16#80# .. 16#89#))
         then
            return 2;
         elsif Is_Bounded_Han_Decimal_Digit (Digit_Index)
           or else (Digit_Index + 2 <= Item'Last
                    and then
                      ((B1 = 16#E0# and then B2 = 16#A5#
                        and then B3 in 16#A6# .. 16#AF#)
                       or else
                         (B1 = 16#E0# and then B2 = 16#A7#
                          and then B3 in 16#A6# .. 16#AF#)
                       or else
                         (B1 = 16#E0# and then B2 in 16#A9# | 16#AB#
                          | 16#AD# | 16#AF# | 16#B1# | 16#B3#
                          | 16#B5# | 16#B7#
                          and then B3 in 16#A6# .. 16#AF#)
                       or else
                         (B1 = 16#E0# and then B2 = 16#B9#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#E0# and then B2 in 16#BB#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#E0# and then B2 = 16#BC#
                          and then B3 in 16#A0# .. 16#A9#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#81#
                          and then B3 in 16#80# .. 16#89#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#A5#
                          and then B3 in 16#86# .. 16#8F#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#A7#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#AD#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#AE#
                          and then B3 in 16#B0# .. 16#B9#)
                       or else
                         (B1 = 16#E1# and then B2 = 16#B1#
                          and then (B3 in 16#80# .. 16#89#
                                    or else B3 in 16#90# .. 16#99#))
                       or else
                         (B1 = 16#E1# and then B2 = 16#AA#
                          and then (B3 in 16#80# .. 16#89#
                                    or else B3 in 16#90# .. 16#99#))
                       or else
                         (B1 = 16#E1# and then B2 = 16#9F#
                          and then B3 in 16#A0# .. 16#A9#)
                       or else
                         (B1 = 16#EA# and then B2 = 16#98#
                          and then B3 in 16#A0# .. 16#A9#)
                       or else
                         (B1 = 16#EA# and then B2 = 16#A3#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#EA# and then B2 = 16#A4#
                          and then B3 in 16#80# .. 16#89#)
                       or else
                         (B1 = 16#EA# and then B2 in 16#A7# | 16#A9#
                          and then B3 in 16#90# .. 16#99#)
                       or else
                         (B1 = 16#EF# and then B2 = 16#BC#
                          and then B3 in 16#90# .. 16#99#)))
         then
            return 3;
         elsif Digit_Index + 3 <= Item'Last
           and then B1 = 16#F0#
           and then ((B2 = 16#90# and then B3 = 16#B4#
                      and then B4 in 16#B0# .. 16#B9#)
                     or else (B2 = 16#90# and then B3 = 16#92#
                              and then B4 in 16#A0# .. 16#A9#)
                     or else (B2 = 16#96# and then B3 = 16#AB#
                              and then B4 in 16#80# .. 16#89#)
                     or else (B2 = 16#9E# and then B3 = 16#93#
                              and then B4 in 16#B0# .. 16#B9#)
                     or else (B2 = 16#9E# and then B3 = 16#A5#
                              and then B4 in 16#90# .. 16#99#)
                     or else (B2 = 16#91#
                              and then
                                ((B3 = 16#81#
                                  and then B4 in 16#A6# .. 16#AF#)
                                 or else (B3 = 16#83#
                                          and then B4 in 16#B0# .. 16#B9#)
                                 or else (B3 = 16#84#
                                          and then B4 in 16#B6# .. 16#BF#)
                                 or else (B3 = 16#87#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#8B#
                                          and then B4 in 16#B0# .. 16#B9#)
                                 or else (B3 = 16#91#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#93#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#99#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#9B#
                                          and then B4 in 16#80# .. 16#89#)
                                 or else (B3 = 16#9C#
                                          and then B4 in 16#B0# .. 16#B9#)
                                 or else (B3 = 16#A3#
                                          and then B4 in 16#A0# .. 16#A9#)
                                 or else (B3 = 16#A5#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#B1#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#B5#
                                          and then B4 in 16#90# .. 16#99#)
                                 or else (B3 = 16#B6#
                                          and then B4 in 16#A0# .. 16#A9#)
                                 or else (B3 = 16#B7#
                                          and then B4 in 16#A0# .. 16#A9#)
                                 or else (B3 = 16#BD#
                                          and then B4 in 16#90# .. 16#99#))))
         then
            return 4;
         else
            return 0;
         end if;
      end Collation_Digit_Length;

      function Han_Decimal_Digit_Value (Digit_Index : Natural) return Natural
      is
         B1 : constant Natural := Character'Pos (Item (Digit_Index));
         B2 : constant Natural :=
           (if Digit_Index + 1 <= Item'Last
            then Character'Pos (Item (Digit_Index + 1))
            else 0);
         B3 : constant Natural :=
           (if Digit_Index + 2 <= Item'Last
            then Character'Pos (Item (Digit_Index + 2))
            else 0);
      begin
         if B1 = 16#E3# and then B2 = 16#80# and then B3 = 16#87# then
            return 0;
         elsif B1 = 16#E4# and then B2 = 16#B8# and then B3 = 16#80# then
            return 1;
         elsif B1 = 16#E4# and then B2 = 16#BA# and then B3 = 16#8C# then
            return 2;
         elsif B1 = 16#E4# and then B2 = 16#B8# and then B3 = 16#89# then
            return 3;
         elsif B1 = 16#E5# and then B2 = 16#9B# and then B3 = 16#9B# then
            return 4;
         elsif B1 = 16#E4# and then B2 = 16#BA# and then B3 = 16#94# then
            return 5;
         elsif B1 = 16#E5# and then B2 = 16#85# and then B3 = 16#AD# then
            return 6;
         elsif B1 = 16#E4# and then B2 = 16#B8# and then B3 = 16#83# then
            return 7;
         elsif B1 = 16#E5# and then B2 = 16#85# and then B3 = 16#AB# then
            return 8;
         else
            return 9;
         end if;
      end Han_Decimal_Digit_Value;

      function Is_Bounded_Han_Decimal_Digit (Digit_Index : Natural)
         return Boolean
      is
         B1 : constant Natural := Character'Pos (Item (Digit_Index));
         B2 : constant Natural :=
           (if Digit_Index + 1 <= Item'Last
            then Character'Pos (Item (Digit_Index + 1))
            else 0);
         B3 : constant Natural :=
           (if Digit_Index + 2 <= Item'Last
            then Character'Pos (Item (Digit_Index + 2))
            else 0);
      begin
         return Digit_Index + 2 <= Item'Last
           and then ((B1 = 16#E3# and then B2 = 16#80#
                      and then B3 = 16#87#)
                     or else
                       (B1 = 16#E4# and then B2 = 16#B8#
                        and then B3 in 16#80# | 16#83# | 16#89#)
                     or else
                       (B1 = 16#E4# and then B2 = 16#BA#
                        and then B3 in 16#8C# | 16#94#)
                     or else
                       (B1 = 16#E4# and then B2 = 16#B9#
                        and then B3 = 16#9D#)
                     or else
                       (B1 = 16#E5# and then B2 = 16#85#
                        and then B3 in 16#AB# | 16#AD#)
                     or else
                       (B1 = 16#E5# and then B2 = 16#9B#
                        and then B3 = 16#9B#));
      end Is_Bounded_Han_Decimal_Digit;

      function Collation_Digit_Value (Digit_Index : Natural) return Natural is
         B1 : constant Natural := Character'Pos (Item (Digit_Index));
         B2 : constant Natural :=
           (if Digit_Index + 1 <= Item'Last
            then Character'Pos (Item (Digit_Index + 1))
            else 0);
         B3 : constant Natural :=
           (if Digit_Index + 2 <= Item'Last
            then Character'Pos (Item (Digit_Index + 2))
            else 0);
         B4 : constant Natural :=
           (if Digit_Index + 3 <= Item'Last
            then Character'Pos (Item (Digit_Index + 3))
            else 0);
      begin
         if Item (Digit_Index) in '0' .. '9' then
            return Character'Pos (Item (Digit_Index)) - Character'Pos ('0');
         elsif B1 = 16#D9# then
            return B2 - 16#A0#;
         elsif B1 = 16#DB# then
            return B2 - 16#B0#;
         elsif B1 = 16#DF# then
            return B2 - 16#80#;
         elsif B1 = 16#E0#
           and then B2 in 16#A5# | 16#A7# | 16#A9# | 16#AB# | 16#AD#
           | 16#AF# | 16#B1# | 16#B3# | 16#B5# | 16#B7#
         then
            return B3 - 16#A6#;
         elsif B2 = 16#B9# or else B2 = 16#BB# or else B2 = 16#BC# then
            if B1 = 16#E0# and then B2 = 16#BC# then
               return B3 - 16#A0#;
            end if;
            return B3 - 16#90#;
         elsif B2 = 16#81# then
            return B3 - 16#80#;
         elsif B2 = 16#A5# then
            return B3 - 16#86#;
         elsif B2 = 16#A7# then
            return B3 - 16#90#;
         elsif B1 = 16#E1# and then B2 = 16#AD# then
            return B3 - 16#90#;
         elsif B1 = 16#E1# and then B2 = 16#AE# then
            return B3 - 16#B0#;
         elsif B1 = 16#E1# and then B2 = 16#B1# then
            if B3 in 16#80# .. 16#89# then
               return B3 - 16#80#;
            end if;
            return B3 - 16#90#;
         elsif B1 = 16#E1# and then B2 = 16#AA# then
            if B3 in 16#80# .. 16#89# then
               return B3 - 16#80#;
            end if;
            return B3 - 16#90#;
         elsif B1 = 16#EA# and then B2 = 16#98# then
            return B3 - 16#A0#;
         elsif B1 = 16#EA# and then B2 = 16#A3# then
            return B3 - 16#90#;
         elsif B1 = 16#EA# and then B2 = 16#A4# then
            return B3 - 16#80#;
         elsif B1 = 16#EA# and then B2 in 16#A7# | 16#A9# then
            return B3 - 16#90#;
         elsif B1 = 16#F0# and then B2 = 16#90# then
            if B3 = 16#92# then
               return B4 - 16#A0#;
            end if;
            return B4 - 16#B0#;
         elsif B1 = 16#F0# and then B2 = 16#96# then
            return B4 - 16#80#;
         elsif B1 = 16#F0# and then B2 = 16#9E# then
            if B3 = 16#93# then
               return B4 - 16#B0#;
            else
               return B4 - 16#90#;
            end if;
         elsif B1 = 16#F0# and then B2 = 16#91# then
            if B3 = 16#81# then
               return B4 - 16#A6#;
            elsif B3 = 16#83# then
               return B4 - 16#B0#;
            elsif B3 = 16#84# then
               return B4 - 16#B6#;
            elsif B3 = 16#87# then
               return B4 - 16#90#;
            elsif B3 = 16#8B# then
               return B4 - 16#B0#;
            elsif B3 = 16#91# or else B3 = 16#93# or else B3 = 16#99# then
               return B4 - 16#90#;
            elsif B3 = 16#9B# then
               return B4 - 16#80#;
            elsif B3 = 16#9C# then
               return B4 - 16#B0#;
            elsif B3 = 16#B1# or else B3 = 16#B5# then
               return B4 - 16#90#;
            elsif B3 = 16#B6# then
               return B4 - 16#A0#;
            elsif B3 = 16#B7# then
               return B4 - 16#A0#;
            elsif B3 = 16#BD# then
               return B4 - 16#90#;
            elsif B3 = 16#A5# then
               return B4 - 16#90#;
            else
               return B4 - 16#A0#;
            end if;
         elsif B2 = 16#9F# then
            return B3 - 16#A0#;
         else
            return Han_Decimal_Digit_Value (Digit_Index);
         end if;
      end Collation_Digit_Value;

      procedure Append_Numeric_Run is
         Normalized_Digit_Text : String (1 .. Natural'Max (Item'Length, 1));
         Digit_Last : Natural := 0;
         First_Significant : Natural := 1;
         Significant_Length : Natural;
      begin
         while Index <= Item'Last
           and then Collation_Digit_Length (Index) > 0
         loop
            Digit_Last := Digit_Last + 1;
            Normalized_Digit_Text (Digit_Last) := Character'Val
              (Character'Pos ('0') + Collation_Digit_Value (Index));
            Index := Index + Collation_Digit_Length (Index);
         end loop;

         while First_Significant < Digit_Last
           and then Normalized_Digit_Text (First_Significant) = '0'
         loop
            First_Significant := First_Significant + 1;
         end loop;

         Significant_Length := Digit_Last - First_Significant + 1;

         Append_Char (Character'Val (1));
         if Normalized_Digit_Text (First_Significant) = '0' then
            Append_Natural_6 (1);
            Append_Char ('0');
         else
            Append_Natural_6 (Significant_Length);
            Append_Text
              (Normalized_Digit_Text (First_Significant .. Digit_Last));
         end if;
         Append_Char (Character'Val (2));
      end Append_Numeric_Run;

      procedure Append_Hex_Nibble (Value : Natural) is
      begin
         if Value < 10 then
            Append_Char (Character'Val (Character'Pos ('0') + Value));
         else
            Append_Char (Character'Val (Character'Pos ('a') + Value - 10));
         end if;
      end Append_Hex_Nibble;

      procedure Append_Hex_Byte (Value : Natural) is
      begin
         Append_Hex_Nibble (Value / 16);
         Append_Hex_Nibble (Value mod 16);
      end Append_Hex_Byte;

      procedure Append_UTF8_Two_Byte_Key is
      begin
         Append_Char ('u');
         Append_Hex_Byte (Character'Pos (Item (Index)));
         Append_Hex_Byte (Character'Pos (Item (Index + 1)));
      end Append_UTF8_Two_Byte_Key;

      function Pair_Matches (First, Second : Natural) return Boolean is
      begin
         return Index < Item'Last
           and then Character'Pos (Item (Index)) = First
           and then Character'Pos (Item (Index + 1)) = Second;
      end Pair_Matches;

      function ASCII_Pair_Matches (First, Second : Character) return Boolean is
      begin
         return Index < Item'Last
           and then Lower_ASCII (Item (Index)) = First
           and then Lower_ASCII (Item (Index + 1)) = Second;
      end ASCII_Pair_Matches;

      function Three_Byte_Matches
        (First, Second, Third : Natural)
         return Boolean
      is
      begin
         return Index + 2 <= Item'Last
           and then Character'Pos (Item (Index)) = First
           and then Character'Pos (Item (Index + 1)) = Second
           and then Character'Pos (Item (Index + 2)) = Third;
      end Three_Byte_Matches;

      function Append_Tailored_Contraction return Boolean is
      begin
         if Czech_Slovak and then ASCII_Pair_Matches ('c', 'h') then
            Append_Text ("h{");
            Index := Index + 2;
            return True;
         elsif South_Slavic_Latin
           and then ASCII_Pair_Matches ('l', 'j')
         then
            Append_Text ("l{");
            Index := Index + 2;
            return True;
         elsif South_Slavic_Latin
           and then ASCII_Pair_Matches ('n', 'j')
         then
            Append_Text ("n{");
            Index := Index + 2;
            return True;
         elsif South_Slavic_Latin
           and then (Three_Byte_Matches
                       (Character'Pos ('D'), 16#C5#, 16#BD#)
                     or else Three_Byte_Matches
                       (Character'Pos ('D'), 16#C5#, 16#BE#)
                     or else Three_Byte_Matches
                       (Character'Pos ('d'), 16#C5#, 16#BD#)
                     or else Three_Byte_Matches
                       (Character'Pos ('d'), 16#C5#, 16#BE#))
         then
            Append_Text ("d{");
            Index := Index + 3;
            return True;
         else
            return False;
         end if;
      end Append_Tailored_Contraction;

      procedure Append_Latin_A is
      begin
         if Nordic then
            if Pair_Matches (16#C3#, 16#84#)
              or else Pair_Matches (16#C3#, 16#A4#)
              or else Pair_Matches (16#C3#, 16#86#)
              or else Pair_Matches (16#C3#, 16#A6#)
            then
               Append_Char ('|');
            elsif Pair_Matches (16#C3#, 16#85#)
              or else Pair_Matches (16#C3#, 16#A5#)
            then
               Append_Char ('{');
            else
               Append_Char ('a');
            end if;
         elsif German
           and then (Pair_Matches (16#C3#, 16#84#)
                     or else Pair_Matches (16#C3#, 16#A4#))
         then
            Append_Text ("ae");
         else
            Append_Char ('a');
         end if;
      end Append_Latin_A;

      procedure Append_Latin_O is
      begin
         if Nordic
           and then (Pair_Matches (16#C3#, 16#96#)
                     or else Pair_Matches (16#C3#, 16#B6#)
                     or else Pair_Matches (16#C3#, 16#98#)
                     or else Pair_Matches (16#C3#, 16#B8#))
         then
            Append_Char ('}');
         elsif German
           and then (Pair_Matches (16#C3#, 16#96#)
                     or else Pair_Matches (16#C3#, 16#B6#))
         then
            Append_Text ("oe");
         else
            Append_Char ('o');
         end if;
      end Append_Latin_O;

      procedure Append_UTF8_Two_Byte is
         B1 : constant Natural := Character'Pos (Item (Index));
         B2 : constant Natural := Character'Pos (Item (Index + 1));

         procedure Append_Armenian_Key is
            Normalized_B1 : Natural := B1;
            Normalized_B2 : Natural := B2;
         begin
            if B1 = 16#D4# and then B2 in 16#B1# .. 16#BF# then
               Normalized_B1 := 16#D5#;
               Normalized_B2 := B2 - 16#10#;
            elsif B1 = 16#D5# and then B2 in 16#80# .. 16#8F# then
               Normalized_B2 := B2 + 16#30#;
            elsif B1 = 16#D5# and then B2 in 16#90# .. 16#96# then
               Normalized_B1 := 16#D6#;
               Normalized_B2 := B2 - 16#10#;
            end if;

            Append_Text ("hy");
            Append_Hex_Byte (Normalized_B1);
            Append_Hex_Byte (Normalized_B2);
         end Append_Armenian_Key;
      begin
         if B1 = 16#CE# then
            case B2 is
               when 16#86# | 16#91# | 16#AC# | 16#B1# => Append_Text ("ga");
               when 16#88# | 16#95# | 16#AD# | 16#B5# => Append_Text ("ge");
               when 16#89# | 16#97# | 16#AE# | 16#B7# => Append_Text ("gh");
               when 16#8A# | 16#90# | 16#99# | 16#AA# | 16#AF# | 16#B9# =>
                  Append_Text ("gi");
               when 16#8C# | 16#9F# | 16#BF# => Append_Text ("go");
               when 16#8E# | 16#A5# | 16#AB# | 16#B0# => Append_Text ("gu");
               when 16#8F# | 16#A9# => Append_Text ("gw");
               when 16#92# | 16#B2# => Append_Text ("gb");
               when 16#93# | 16#B3# => Append_Text ("gg");
               when 16#94# | 16#B4# => Append_Text ("gd");
               when 16#96# | 16#B6# => Append_Text ("gz");
               when 16#98# | 16#B8# => Append_Text ("gq");
               when 16#9A# | 16#BA# => Append_Text ("gk");
               when 16#9B# | 16#BB# => Append_Text ("gl");
               when 16#9C# | 16#BC# => Append_Text ("gm");
               when 16#9D# | 16#BD# => Append_Text ("gn");
               when 16#9E# | 16#BE# => Append_Text ("gx");
               when 16#A0# => Append_Text ("gp");
               when 16#A1# => Append_Text ("gr");
               when 16#A3# => Append_Text ("gs");
               when 16#A4# => Append_Text ("gt");
               when 16#A6# => Append_Text ("gf");
               when 16#A7# => Append_Text ("gc");
               when 16#A8# => Append_Text ("gy");
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
            end case;
         elsif B1 = 16#CF# then
            case B2 is
               when 16#80# => Append_Text ("gp");
               when 16#81# => Append_Text ("gr");
               when 16#82# | 16#83# => Append_Text ("gs");
               when 16#84# => Append_Text ("gt");
               when 16#85# | 16#8B# | 16#8D# => Append_Text ("gu");
               when 16#86# => Append_Text ("gf");
               when 16#87# => Append_Text ("gc");
               when 16#88# => Append_Text ("gy");
               when 16#89# | 16#8E# => Append_Text ("gw");
               when 16#8A# => Append_Text ("gi");
               when 16#8C# => Append_Text ("go");
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
            end case;
         elsif B1 = 16#D0# then
            case B2 is
               when 16#81# => Append_Text ("ce");
               when 16#90# | 16#B0# => Append_Text ("ca");
               when 16#91# | 16#B1# => Append_Text ("cb");
               when 16#92# | 16#B2# => Append_Text ("cv");
               when 16#93# | 16#B3# => Append_Text ("cg");
               when 16#94# | 16#B4# => Append_Text ("cd");
               when 16#95# | 16#B5# => Append_Text ("ce");
               when 16#96# | 16#B6# => Append_Text ("czh");
               when 16#97# | 16#B7# => Append_Text ("cz");
               when 16#98# | 16#B8# => Append_Text ("ci");
               when 16#99# | 16#B9# => Append_Text ("cj");
               when 16#9A# | 16#BA# => Append_Text ("ck");
               when 16#9B# | 16#BB# => Append_Text ("cl");
               when 16#9C# | 16#BC# => Append_Text ("cm");
               when 16#9D# | 16#BD# => Append_Text ("cn");
               when 16#9E# | 16#BE# => Append_Text ("co");
               when 16#9F# | 16#BF# => Append_Text ("cp");
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
            end case;
         elsif B1 = 16#D1# then
            case B2 is
               when 16#80# => Append_Text ("cr");
               when 16#81# => Append_Text ("cs");
               when 16#82# => Append_Text ("ct");
               when 16#83# => Append_Text ("cu");
               when 16#84# => Append_Text ("cf");
               when 16#85# => Append_Text ("cx");
               when 16#86# => Append_Text ("cc");
               when 16#87# => Append_Text ("cch");
               when 16#88# => Append_Text ("csh");
               when 16#89# => Append_Text ("csch");
               when 16#8A# => Append_Text ("cy");
               when 16#8B# => Append_Text ("cyi");
               when 16#8C# => Append_Text ("csoft");
               when 16#8D# => Append_Text ("cee");
               when 16#8E# => Append_Text ("cyu");
               when 16#8F# => Append_Text ("cya");
               when 16#91# => Append_Text ("ce");
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
            end case;
         elsif (B1 = 16#D4# and then B2 in 16#B1# .. 16#BF#)
           or else (B1 = 16#D5#
                    and then (B2 in 16#80# .. 16#96#
                              or else B2 in 16#A1# .. 16#BF#))
           or else (B1 = 16#D6# and then B2 in 16#80# .. 16#87#)
         then
            Append_Armenian_Key;
         elsif B1 = 16#C3# then
            case B2 is
               when 16#80# .. 16#86# | 16#A0# .. 16#A6# =>
                  Append_Latin_A;
               when 16#87# | 16#A7# =>
                  Append_Char ('c');
               when 16#88# .. 16#8B# | 16#A8# .. 16#AB# =>
                  Append_Char ('e');
               when 16#8C# .. 16#8F# | 16#AC# .. 16#AF# =>
                  Append_Char ('i');
               when 16#91# | 16#B1# =>
                  if Lang = "es" then
                     Append_Text ("nz");
                  else
                     Append_Char ('n');
                  end if;
               when 16#92# .. 16#96# | 16#98# | 16#B2# .. 16#B6#
                  | 16#B8# =>
                  Append_Latin_O;
               when 16#99# .. 16#9C# | 16#B9# .. 16#BC# =>
                  if German and then (B2 = 16#9C# or else B2 = 16#BC#) then
                     Append_Text ("ue");
                  else
                     Append_Char ('u');
                  end if;
               when 16#9D# | 16#BD# | 16#BF# =>
                  Append_Char ('y');
               when 16#9F# =>
                  Append_Text ("ss");
               when others =>
                  Append_UTF8_Two_Byte_Key;
            end case;
         elsif B1 = 16#C4# then
            case B2 is
               when 16#80# .. 16#85# =>
                  Append_Char ('a');
               when 16#86# .. 16#8D# =>
                  Append_Char ('c');
               when 16#8E# .. 16#91# =>
                  Append_Char ('d');
               when 16#92# .. 16#9B# =>
                  Append_Char ('e');
               when 16#9C# .. 16#A3# =>
                  Append_Char ('g');
               when 16#A4# .. 16#A7# =>
                  Append_Char ('h');
               when 16#A8# .. 16#B1# =>
                  Append_Char ('i');
               when 16#B2# | 16#B3# =>
                  Append_Text ("ij");
               when 16#B4# | 16#B5# =>
                  Append_Char ('j');
               when 16#B6# .. 16#B9# =>
                  Append_Char ('k');
               when 16#BA# .. 16#BF# =>
                  Append_Char ('l');
               when others =>
                  Append_UTF8_Two_Byte_Key;
            end case;
         elsif B1 = 16#C5# then
            case B2 is
               when 16#80# .. 16#82# =>
                  Append_Char ('l');
               when 16#83# .. 16#8B# =>
                  Append_Char ('n');
               when 16#8C# .. 16#91# =>
                  Append_Latin_O;
               when 16#92# | 16#93# =>
                  Append_Text ("oe");
               when 16#94# .. 16#99# =>
                  Append_Char ('r');
               when 16#9A# | 16#9B# =>
                  Append_Char ('s');
               when 16#9C# .. 16#A1# =>
                  Append_Char ('s');
               when 16#A2# .. 16#A7# =>
                  Append_Char ('t');
               when 16#A8# .. 16#B3# =>
                  if German and then (B2 = 16#B2# or else B2 = 16#B3#) then
                     Append_Text ("ue");
                  else
                     Append_Char ('u');
                  end if;
               when 16#B4# | 16#B5# =>
                  Append_Char ('w');
               when 16#B6# .. 16#B8# =>
                  Append_Char ('y');
               when 16#B9# | 16#BA# | 16#BB# | 16#BC# =>
                  Append_Char ('z');
               when 16#BD# | 16#BE# =>
                  Append_Char ('z');
               when 16#BF# =>
                  Append_Char ('s');
               when others =>
                  Append_UTF8_Two_Byte_Key;
            end case;
         elsif B1 = 16#C6# then
            case B2 is
               when 16#A0# | 16#A1# =>
                  Append_Char ('o');
               when 16#AF# | 16#B0# =>
                  Append_Char ('u');
               when others =>
                  Append_UTF8_Two_Byte_Key;
            end case;
         else
            Append_UTF8_Two_Byte_Key;
         end if;

         Index := Index + 2;
      end Append_UTF8_Two_Byte;

      procedure Append_UTF8_Three_Byte_Key is
         B1 : constant Natural := Character'Pos (Item (Index));
         B2 : constant Natural := Character'Pos (Item (Index + 1));
         B3 : constant Natural := Character'Pos (Item (Index + 2));

         procedure Append_Two_Byte_Base_Key
           (Lead  : Natural;
            Trail : Natural)
         is
         begin
            Append_Char ('u');
            Append_Hex_Byte (Lead);
            Append_Hex_Byte (Trail);
         end Append_Two_Byte_Base_Key;

         procedure Append_Hebrew_Base_Key (Trail : Natural) is
         begin
            Append_Two_Byte_Base_Key (16#D7#, Trail);
         end Append_Hebrew_Base_Key;

         procedure Append_Arabic_Lam_Alef_Key (Alef_Trail : Natural) is
         begin
            Append_Two_Byte_Base_Key (16#D9#, 16#84#);
            Append_Two_Byte_Base_Key (16#D8#, Alef_Trail);
         end Append_Arabic_Lam_Alef_Key;

         procedure Append_Arabic_Codepoint_Key (Code_Point : Natural) is
            Offset : constant Natural := Code_Point - 16#0600#;
         begin
            Append_Two_Byte_Base_Key
              (16#D8# + Offset / 16#40#, 16#80# + Offset mod 16#40#);
         end Append_Arabic_Codepoint_Key;

         procedure Append_Arabic_Packed_Three_Key
           (Packed : Long_Long_Integer)
         is
         begin
            Append_Arabic_Codepoint_Key
              (Natural (Packed / 16#100000000#));
            Append_Arabic_Codepoint_Key
              (Natural ((Packed / 16#10000#) mod 16#10000#));
            Append_Arabic_Codepoint_Key
              (Natural (Packed mod 16#10000#));
         end Append_Arabic_Packed_Three_Key;

         procedure Append_Arabic_Packed_Four_Key
           (Packed : Long_Long_Integer)
         is
         begin
            Append_Arabic_Codepoint_Key
              (Natural (Packed / 16#1000000000000#));
            Append_Arabic_Codepoint_Key
              (Natural ((Packed / 16#100000000#) mod 16#10000#));
            Append_Arabic_Codepoint_Key
              (Natural ((Packed / 16#10000#) mod 16#10000#));
            Append_Arabic_Codepoint_Key
              (Natural (Packed mod 16#10000#));
         end Append_Arabic_Packed_Four_Key;

         procedure Append_Arabic_Presentation_B_Key is
            Code : constant Natural :=
              Arabic_Presentation_B_Key_Code (B2, B3);
         begin
            if Code = 0 then
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            elsif Code >= 16#10000# then
               Append_Arabic_Lam_Alef_Key (Code - 16#10000#);
            else
               Append_Two_Byte_Base_Key (Code / 16#100#, Code mod 16#100#);
            end if;
         end Append_Arabic_Presentation_B_Key;

         procedure Append_Arabic_Presentation_A_Single_Key is
            Code : constant Natural :=
              Arabic_Presentation_A_Single_Key_Code (B2, B3);
         begin
            if Code = 0 then
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            else
               Append_Two_Byte_Base_Key (Code / 16#100#, Code mod 16#100#);
            end if;
         end Append_Arabic_Presentation_A_Single_Key;

         procedure Append_Arabic_Presentation_A_Two_Letter_Ligature_Key is
            Packed : constant Natural :=
              Arabic_Presentation_A_Two_Letter_Ligature_Key_Code (B2, B3);
         begin
            if Packed = 0 then
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            else
               Append_Arabic_Codepoint_Key (Packed / 16#10000#);
               Append_Arabic_Codepoint_Key (Packed mod 16#10000#);
            end if;
         end Append_Arabic_Presentation_A_Two_Letter_Ligature_Key;

         procedure Append_Arabic_Presentation_A_Multi_Letter_Ligature_Key is
            Four : constant Long_Long_Integer :=
              Arabic_Presentation_A_Four_Letter_Ligature_Key_Code (B2, B3);
            Three : constant Long_Long_Integer :=
              Arabic_Presentation_A_Three_Letter_Ligature_Key_Code (B2, B3);
         begin
            if Four /= 0 then
               Append_Arabic_Packed_Four_Key (Four);
            elsif Three /= 0 then
               Append_Arabic_Packed_Three_Key (Three);
            else
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            end if;
         end Append_Arabic_Presentation_A_Multi_Letter_Ligature_Key;

         procedure Append_Georgian_Key (Code : Natural) is
         begin
            Append_Text ("ka");
            case Code is
               when 16#90# => Append_Char ('a');
               when 16#91# => Append_Char ('b');
               when 16#92# => Append_Char ('g');
               when 16#93# => Append_Char ('d');
               when 16#94# => Append_Char ('e');
               when 16#95# => Append_Char ('v');
               when 16#96# => Append_Char ('z');
               when 16#97# => Append_Char ('t');
               when 16#98# => Append_Char ('i');
               when 16#99# => Append_Char ('k');
               when 16#9A# => Append_Char ('l');
               when 16#9B# => Append_Char ('m');
               when 16#9C# => Append_Char ('n');
               when 16#9D# => Append_Char ('o');
               when 16#9E# => Append_Char ('p');
               when 16#9F# => Append_Text ("zh");
               when 16#A0# => Append_Char ('r');
               when 16#A1# => Append_Char ('s');
               when 16#A2# => Append_Char ('t');
               when 16#A3# => Append_Char ('u');
               when 16#A4# => Append_Char ('p');
               when 16#A5# => Append_Char ('k');
               when 16#A6# => Append_Text ("gh");
               when 16#A7# => Append_Char ('q');
               when 16#A8# => Append_Text ("sh");
               when 16#A9# => Append_Text ("ch");
               when 16#AA# => Append_Text ("ts");
               when 16#AB# => Append_Text ("dz");
               when 16#AC# => Append_Text ("ts");
               when 16#AD# => Append_Text ("ch");
               when 16#AE# => Append_Text ("kh");
               when 16#AF# => Append_Char ('j');
               when 16#B0# => Append_Char ('h');
               when 16#B1# => Append_Text ("he");
               when 16#B2# => Append_Text ("hie");
               when 16#B3# => Append_Text ("we");
               when 16#B4# => Append_Text ("har");
               when 16#B5# => Append_Text ("hoe");
               when 16#B6# => Append_Text ("fi");
               when 16#B7# => Append_Text ("yn");
               when 16#B8# => Append_Text ("elifi");
               when 16#B9# => Append_Text ("gan");
               when 16#BA# => Append_Text ("ain");
               when 16#BC# => Append_Char ('n');
               when 16#BD# => Append_Text ("aen");
               when 16#BE# => Append_Text ("hard");
               when 16#BF# => Append_Text ("labial");
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
                  Append_Hex_Byte (B3);
            end case;
         end Append_Georgian_Key;

         procedure Append_Hangul_Jamo_Key (B2_Key, B3_Key : Natural) is
         begin
            Append_Char ('u');
            Append_Text ("e1");
            Append_Hex_Byte (B2_Key);
            Append_Hex_Byte (B3_Key);
         end Append_Hangul_Jamo_Key;

         procedure Append_Hangul_Compatibility_Jamo_Key is
         begin
            if B2 = 16#84# then
               case B3 is
                  when 16#B1# => Append_Hangul_Jamo_Key (16#84#, 16#80#);
                  when 16#B2# => Append_Hangul_Jamo_Key (16#84#, 16#81#);
                  when 16#B3# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#80#);
                     Append_Hangul_Jamo_Key (16#84#, 16#89#);
                  when 16#B4# => Append_Hangul_Jamo_Key (16#84#, 16#82#);
                  when 16#B5# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#82#);
                     Append_Hangul_Jamo_Key (16#84#, 16#8C#);
                  when 16#B6# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#82#);
                     Append_Hangul_Jamo_Key (16#84#, 16#92#);
                  when 16#B7# => Append_Hangul_Jamo_Key (16#84#, 16#83#);
                  when 16#B8# => Append_Hangul_Jamo_Key (16#84#, 16#84#);
                  when 16#B9# => Append_Hangul_Jamo_Key (16#84#, 16#85#);
                  when 16#BA# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#80#);
                  when 16#BB# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#86#);
                  when 16#BC# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#87#);
                  when 16#BD# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#89#);
                  when 16#BE# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#90#);
                  when 16#BF# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#91#);
                  when others =>
                     Append_Char ('u');
                     Append_Hex_Byte (B1);
                     Append_Hex_Byte (B2);
                     Append_Hex_Byte (B3);
               end case;
            elsif B2 = 16#85# then
               case B3 is
                  when 16#80# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#85#);
                     Append_Hangul_Jamo_Key (16#84#, 16#92#);
                  when 16#81# => Append_Hangul_Jamo_Key (16#84#, 16#86#);
                  when 16#82# => Append_Hangul_Jamo_Key (16#84#, 16#87#);
                  when 16#83# => Append_Hangul_Jamo_Key (16#84#, 16#88#);
                  when 16#84# =>
                     Append_Hangul_Jamo_Key (16#84#, 16#87#);
                     Append_Hangul_Jamo_Key (16#84#, 16#89#);
                  when 16#85# => Append_Hangul_Jamo_Key (16#84#, 16#89#);
                  when 16#86# => Append_Hangul_Jamo_Key (16#84#, 16#8A#);
                  when 16#87# => Append_Hangul_Jamo_Key (16#84#, 16#8B#);
                  when 16#88# => Append_Hangul_Jamo_Key (16#84#, 16#8C#);
                  when 16#89# => Append_Hangul_Jamo_Key (16#84#, 16#8D#);
                  when 16#8A# => Append_Hangul_Jamo_Key (16#84#, 16#8E#);
                  when 16#8B# => Append_Hangul_Jamo_Key (16#84#, 16#8F#);
                  when 16#8C# => Append_Hangul_Jamo_Key (16#84#, 16#90#);
                  when 16#8D# => Append_Hangul_Jamo_Key (16#84#, 16#91#);
                  when 16#8E# => Append_Hangul_Jamo_Key (16#84#, 16#92#);
                  when 16#8F# .. 16#A3# =>
                     Append_Hangul_Jamo_Key (16#85#, B3 + 16#12#);
                  when others =>
                     Append_Char ('u');
                     Append_Hex_Byte (B1);
                     Append_Hex_Byte (B2);
                     Append_Hex_Byte (B3);
               end case;
            else
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            end if;
         end Append_Hangul_Compatibility_Jamo_Key;
      begin
         if B1 = 16#E1# and then B2 = 16#BA# then
            case B3 is
               when 16#A0# | 16#A1# => Append_Char ('a');
               when 16#A4# .. 16#B7# => Append_Char ('a');
               when 16#B8# | 16#B9# => Append_Char ('e');
               when 16#BE# | 16#BF# => Append_Char ('e');
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
                  Append_Hex_Byte (B3);
            end case;
         elsif B1 = 16#E1# and then B2 = 16#BB# then
            case B3 is
               when 16#80# .. 16#87# => Append_Char ('e');
               when 16#8A# | 16#8B# => Append_Char ('i');
               when 16#8C# | 16#8D# => Append_Char ('o');
               when 16#90# .. 16#99# => Append_Char ('o');
               when 16#9A# .. 16#A3# => Append_Char ('o');
               when 16#A4# | 16#A5# => Append_Char ('u');
               when 16#A8# .. 16#B1# => Append_Char ('u');
               when 16#B4# | 16#B5# => Append_Char ('y');
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
                  Append_Hex_Byte (B3);
            end case;
         elsif B1 = 16#E1#
           and then (B2 = 16#83# or else B2 = 16#B2#)
           and then B3 in 16#90# .. 16#BF#
           and then not (B2 = 16#83# and then B3 = 16#BB#)
           and then not (B2 = 16#B2# and then B3 = 16#BB#)
           and then not (B2 = 16#B2# and then B3 = 16#BC#)
         then
            Append_Georgian_Key (B3);
         elsif B1 = 16#E3#
           and then ((B2 = 16#84# and then B3 in 16#B1# .. 16#BF#)
                     or else (B2 = 16#85# and then B3 <= 16#A3#))
         then
            Append_Hangul_Compatibility_Jamo_Key;
         elsif B1 = 16#EF#
           and then ((B2 = 16#BD# and then B3 in 16#A6# .. 16#BF#)
                     or else (B2 = 16#BE# and then B3 in 16#80# .. 16#9F#))
         then
            if B2 = 16#BD# then
               case B3 is
                  when 16#A6# => Append_Text ("ue383b2");
                  when 16#A7# => Append_Text ("ue382a1");
                  when 16#A8# => Append_Text ("ue382a3");
                  when 16#A9# => Append_Text ("ue382a5");
                  when 16#AA# => Append_Text ("ue382a7");
                  when 16#AB# => Append_Text ("ue382a9");
                  when 16#AC# => Append_Text ("ue383a3");
                  when 16#AD# => Append_Text ("ue383a5");
                  when 16#AE# => Append_Text ("ue383a7");
                  when 16#AF# => Append_Text ("ue38383");
                  when 16#B0# => Append_Text ("ue383bc");
                  when 16#B1# => Append_Text ("ue382a2");
                  when 16#B2# => Append_Text ("ue382a4");
                  when 16#B3# => Append_Text ("ue382a6");
                  when 16#B4# => Append_Text ("ue382a8");
                  when 16#B5# => Append_Text ("ue382aa");
                  when 16#B6# => Append_Text ("ue382ab");
                  when 16#B7# => Append_Text ("ue382ad");
                  when 16#B8# => Append_Text ("ue382af");
                  when 16#B9# => Append_Text ("ue382b1");
                  when 16#BA# => Append_Text ("ue382b3");
                  when 16#BB# => Append_Text ("ue382b5");
                  when 16#BC# => Append_Text ("ue382b7");
                  when 16#BD# => Append_Text ("ue382b9");
                  when 16#BE# => Append_Text ("ue382bb");
                  when 16#BF# => Append_Text ("ue382bd");
                  when others =>
                     Append_Char ('u');
                     Append_Hex_Byte (B1);
                     Append_Hex_Byte (B2);
                     Append_Hex_Byte (B3);
               end case;
            else
               case B3 is
                  when 16#80# => Append_Text ("ue382bf");
                  when 16#81# => Append_Text ("ue38381");
                  when 16#82# => Append_Text ("ue38384");
                  when 16#83# => Append_Text ("ue38386");
                  when 16#84# => Append_Text ("ue38388");
                  when 16#85# => Append_Text ("ue3838a");
                  when 16#86# => Append_Text ("ue3838b");
                  when 16#87# => Append_Text ("ue3838c");
                  when 16#88# => Append_Text ("ue3838d");
                  when 16#89# => Append_Text ("ue3838e");
                  when 16#8A# => Append_Text ("ue3838f");
                  when 16#8B# => Append_Text ("ue38392");
                  when 16#8C# => Append_Text ("ue38395");
                  when 16#8D# => Append_Text ("ue38398");
                  when 16#8E# => Append_Text ("ue3839b");
                  when 16#8F# => Append_Text ("ue3839e");
                  when 16#90# => Append_Text ("ue3839f");
                  when 16#91# => Append_Text ("ue383a0");
                  when 16#92# => Append_Text ("ue383a1");
                  when 16#93# => Append_Text ("ue383a2");
                  when 16#94# => Append_Text ("ue383a4");
                  when 16#95# => Append_Text ("ue383a6");
                  when 16#96# => Append_Text ("ue383a8");
                  when 16#97# => Append_Text ("ue383a9");
                  when 16#98# => Append_Text ("ue383aa");
                  when 16#99# => Append_Text ("ue383ab");
                  when 16#9A# => Append_Text ("ue383ac");
                  when 16#9B# => Append_Text ("ue383ad");
                  when 16#9C# => Append_Text ("ue383af");
                  when 16#9D# => Append_Text ("ue383b3");
                  when 16#9E# | 16#9F# => null;
                  when others =>
                     Append_Char ('u');
                     Append_Hex_Byte (B1);
                     Append_Hex_Byte (B2);
                     Append_Hex_Byte (B3);
               end case;
            end if;
         elsif B1 = 16#EF# and then B2 = 16#BC# then
            if B3 in 16#90# .. 16#99# then
               Append_Char
                 (Character'Val (Character'Pos ('0') + B3 - 16#90#));
            elsif B3 in 16#A1# .. 16#BA# then
               Append_Char
                 (Character'Val (Character'Pos ('a') + B3 - 16#A1#));
            else
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            end if;
         elsif B1 = 16#EF# and then B2 = 16#BD# then
            if B3 in 16#81# .. 16#9A# then
               Append_Char
                 (Character'Val (Character'Pos ('a') + B3 - 16#81#));
            else
               Append_Char ('u');
               Append_Hex_Byte (B1);
               Append_Hex_Byte (B2);
               Append_Hex_Byte (B3);
            end if;
         elsif B1 = 16#EF# and then B2 = 16#AC# then
            case B3 is
               when 16#80# => Append_Text ("ff");
               when 16#81# => Append_Text ("fi");
               when 16#82# => Append_Text ("fl");
               when 16#83# => Append_Text ("ffi");
               when 16#84# => Append_Text ("ffl");
               when 16#85# | 16#86# => Append_Text ("st");
               when 16#AA# .. 16#AD# => Append_Hebrew_Base_Key (16#A9#);
               when 16#AE# .. 16#B0# => Append_Hebrew_Base_Key (16#90#);
               when 16#B1# => Append_Hebrew_Base_Key (16#91#);
               when 16#B2# => Append_Hebrew_Base_Key (16#92#);
               when 16#B3# => Append_Hebrew_Base_Key (16#93#);
               when 16#B4# => Append_Hebrew_Base_Key (16#94#);
               when 16#B5# => Append_Hebrew_Base_Key (16#95#);
               when 16#B7# => Append_Hebrew_Base_Key (16#96#);
               when 16#B8# => Append_Hebrew_Base_Key (16#98#);
               when 16#B9# => Append_Hebrew_Base_Key (16#99#);
               when 16#BA# => Append_Hebrew_Base_Key (16#9A#);
               when 16#BB# => Append_Hebrew_Base_Key (16#9B#);
               when 16#BC# => Append_Hebrew_Base_Key (16#9C#);
               when 16#BE# => Append_Hebrew_Base_Key (16#9E#);
               when others =>
                  Append_Char ('u');
                  Append_Hex_Byte (B1);
                  Append_Hex_Byte (B2);
                  Append_Hex_Byte (B3);
            end case;
         elsif B1 = 16#EF# and then B2 = 16#AD# then
            case B3 is
               when 16#80# => Append_Hebrew_Base_Key (16#A0#);
               when 16#81# => Append_Hebrew_Base_Key (16#A1#);
               when 16#83# => Append_Hebrew_Base_Key (16#A3#);
               when 16#84# => Append_Hebrew_Base_Key (16#A4#);
               when 16#86# => Append_Hebrew_Base_Key (16#A6#);
               when 16#87# => Append_Hebrew_Base_Key (16#A7#);
               when 16#88# => Append_Hebrew_Base_Key (16#A8#);
               when 16#89# => Append_Hebrew_Base_Key (16#A9#);
               when 16#8A# => Append_Hebrew_Base_Key (16#AA#);
               when 16#8B# => Append_Hebrew_Base_Key (16#95#);
               when 16#8C# => Append_Hebrew_Base_Key (16#91#);
               when 16#8D# => Append_Hebrew_Base_Key (16#9B#);
               when 16#8E# => Append_Hebrew_Base_Key (16#A4#);
               when 16#8F# =>
                  Append_Hebrew_Base_Key (16#90#);
                  Append_Hebrew_Base_Key (16#9C#);
               when others =>
                  Append_Arabic_Presentation_A_Single_Key;
            end case;
         elsif B1 = 16#EF# and then B2 = 16#AE# then
            Append_Arabic_Presentation_A_Single_Key;
         elsif B1 = 16#EF# and then B2 = 16#AF# then
            if Arabic_Presentation_A_Single_Key_Code (B2, B3) /= 0 then
               Append_Arabic_Presentation_A_Single_Key;
            else
               Append_Arabic_Presentation_A_Two_Letter_Ligature_Key;
            end if;
         elsif B1 = 16#EF# and then B2 in 16#B0# .. 16#B4# then
            Append_Arabic_Presentation_A_Two_Letter_Ligature_Key;
         elsif B1 = 16#EF# and then B2 in 16#B5# .. 16#B7# then
            Append_Arabic_Presentation_A_Multi_Letter_Ligature_Key;
         elsif B1 = 16#EF# and then B2 = 16#BB# then
            Append_Arabic_Presentation_B_Key;
         elsif B1 = 16#EF# and then B2 = 16#BA# then
            Append_Arabic_Presentation_B_Key;
         else
            Append_Char ('u');
            Append_Hex_Byte (B1);
            Append_Hex_Byte (B2);
            Append_Hex_Byte (B3);
         end if;
         Index := Index + 3;
      end Append_UTF8_Three_Byte_Key;

      procedure Append_UTF8_Four_Byte_Key is
         B1 : constant Natural := Character'Pos (Item (Index));
         B2 : constant Natural := Character'Pos (Item (Index + 1));
         B3 : constant Natural := Character'Pos (Item (Index + 2));
         B4 : constant Natural := Character'Pos (Item (Index + 3));
      begin
         Append_Char ('u');
         Append_Hex_Byte (B1);
         Append_Hex_Byte (B2);
         Append_Hex_Byte (B3);
         Append_Hex_Byte (B4);
         Index := Index + 4;
      end Append_UTF8_Four_Byte_Key;

      function Append_Halfwidth_Katakana_Marked_Key return Boolean is
      begin
         if Index + 5 > Item'Last
           or else Character'Pos (Item (Index)) /= 16#EF#
           or else Character'Pos (Item (Index + 3)) /= 16#EF#
           or else Character'Pos (Item (Index + 4)) /= 16#BE#
           or else not (Character'Pos (Item (Index + 1)) in 16#BD# | 16#BE#)
           or else not (Character'Pos (Item (Index + 5)) in 16#9E# | 16#9F#)
         then
            return False;
         end if;

         if Character'Pos (Item (Index + 5)) = 16#9E# then
            if Character'Pos (Item (Index + 1)) = 16#BD# then
               case Character'Pos (Item (Index + 2)) is
                  when 16#A6# => Append_Text ("ue383ba");
                  when 16#B3# => Append_Text ("ue383b4");
                  when 16#B6# => Append_Text ("ue382ac");
                  when 16#B7# => Append_Text ("ue382ae");
                  when 16#B8# => Append_Text ("ue382b0");
                  when 16#B9# => Append_Text ("ue382b2");
                  when 16#BA# => Append_Text ("ue382b4");
                  when 16#BB# => Append_Text ("ue382b6");
                  when 16#BC# => Append_Text ("ue382b8");
                  when 16#BD# => Append_Text ("ue382ba");
                  when 16#BE# => Append_Text ("ue382bc");
                  when 16#BF# => Append_Text ("ue382be");
                  when others => return False;
               end case;
            else
               case Character'Pos (Item (Index + 2)) is
                  when 16#80# => Append_Text ("ue38380");
                  when 16#81# => Append_Text ("ue38382");
                  when 16#82# => Append_Text ("ue38385");
                  when 16#83# => Append_Text ("ue38387");
                  when 16#84# => Append_Text ("ue38389");
                  when 16#8A# => Append_Text ("ue38390");
                  when 16#8B# => Append_Text ("ue38393");
                  when 16#8C# => Append_Text ("ue38396");
                  when 16#8D# => Append_Text ("ue38399");
                  when 16#8E# => Append_Text ("ue3839c");
                  when 16#9C# => Append_Text ("ue383b7");
                  when others => return False;
               end case;
            end if;
         else
            if Character'Pos (Item (Index + 1)) = 16#BE# then
               case Character'Pos (Item (Index + 2)) is
                  when 16#8A# => Append_Text ("ue38391");
                  when 16#8B# => Append_Text ("ue38394");
                  when 16#8C# => Append_Text ("ue38397");
                  when 16#8D# => Append_Text ("ue3839a");
                  when 16#8E# => Append_Text ("ue3839d");
                  when others => return False;
               end case;
            else
               return False;
            end if;
         end if;

         Index := Index + 6;
         return True;
      end Append_Halfwidth_Katakana_Marked_Key;
   begin
      while Index <= Item'Last loop
         declare
            B : constant Natural := Character'Pos (Item (Index));
         begin
            if Append_Tailored_Contraction then
               null;
            elsif Index + 5 <= Item'Last
              and then B = 16#EF#
              and then Append_Halfwidth_Katakana_Marked_Key
            then
               null;
            elsif Numeric_Collation
              and then Collation_Digit_Length (Index) > 0
            then
               Append_Numeric_Run;
            elsif Item (Index) in 'A' .. 'Z' then
               Append_Char (Lower_ASCII (Item (Index)));
               Index := Index + 1;
            elsif Is_Bounded_Combining_Mark (Item, Index) then
               Index := Index + Bounded_Combining_Mark_Length (Item, Index);
            elsif B < 16#80# then
               Append_Char (Lower_ASCII (Item (Index)));
               Index := Index + 1;
            elsif Index + 2 <= Item'Last and then B in 16#E0# .. 16#EF# then
               Append_UTF8_Three_Byte_Key;
            elsif Index + 3 <= Item'Last and then B in 16#F0# .. 16#F4# then
               Append_UTF8_Four_Byte_Key;
            elsif Index < Item'Last then
               Append_UTF8_Two_Byte;
            else
               Append_Char ('?');
               Index := Index + 1;
            end if;
         end;
      end loop;

      if Last = 0 then
         return "";
      else
         return Result (1 .. Last);
      end if;
   end Sort_Key;

   function Compare
     (Left   : String;
      Right  : String;
      Locale : Locale_Id := "")
      return Collation_Order
   with
      SPARK_Mode => Off
   is
      Left_Key  : constant String := Sort_Key (Left, Locale);
      Right_Key : constant String := Sort_Key (Right, Locale);

      function Raw_Compare (A, B : String) return Collation_Order is
         Limit : constant Natural := Natural'Min (A'Length, B'Length);
      begin
         if Limit > 0 then
            for Offset in 0 .. Limit - 1 loop
               declare
                  AC : constant Character := A (A'First + Offset);
                  BC : constant Character := B (B'First + Offset);
               begin
                  if Character'Pos (AC) < Character'Pos (BC) then
                     return Before;
                  elsif Character'Pos (AC) > Character'Pos (BC) then
                     return After;
                  end if;
               end;
            end loop;
         end if;

         if A'Length < B'Length then
            return Before;
         elsif A'Length > B'Length then
            return After;
         else
            return Same;
         end if;
      end Raw_Compare;

      Primary : constant Collation_Order := Raw_Compare (Left_Key, Right_Key);
   begin
      if Primary /= Same then
         return Primary;
      else
         return Raw_Compare (Left, Right);
      end if;
   end Compare;

   function Equivalent
     (Left   : String;
      Right  : String;
      Locale : Locale_Id := "")
      return Boolean
   with
      SPARK_Mode => Off
   is
   begin
      return Sort_Key (Left, Locale) = Sort_Key (Right, Locale);
   end Equivalent;

   function Contains
     (Text    : String;
      Pattern : String;
      Locale  : Locale_Id := "")
      return Boolean
   with
      SPARK_Mode => Off
   is
      Text_Key    : constant String := Sort_Key (Text, Locale);
      Pattern_Key : constant String := Sort_Key (Pattern, Locale);
   begin
      if Pattern_Key'Length = 0 then
         return True;
      elsif Text_Key'Length < Pattern_Key'Length then
         return False;
      else
         for Start in Text_Key'First ..
           Text_Key'Last - Pattern_Key'Length + 1
         loop
            if Text_Key (Start .. Start + Pattern_Key'Length - 1) =
              Pattern_Key
            then
               return True;
            end if;
         end loop;
      end if;

      return False;
   end Contains;

   function Is_Bounded_Two_Byte_Word_Element (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index < Text'Last then Character'Pos (Text (Index + 1)) else 0);
   begin
      if Index >= Text'Last then
         return False;
      elsif B1 = 16#C3# then
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#C4# then
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#C5# then
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#CD# then
         --  Greek and Coptic lower block U+0370..U+03BF.
         return B2 in 16#B0# .. 16#BF#;
      elsif B1 = 16#CE# or else B1 = 16#CF# then
         --  Greek and Coptic U+0380..U+03FF.
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#D0# or else B1 = 16#D1# then
         --  Cyrillic U+0400..U+04FF.
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#D2# then
         --  Cyrillic supplement start U+0500..U+053F.
         return B2 in 16#80# .. 16#AF#;
      elsif B1 = 16#D4# then
         --  Armenian uppercase letters U+0531..U+053F.
         return B2 in 16#B1# .. 16#BF#;
      elsif B1 = 16#D5# then
         --  Armenian uppercase/lowercase letters U+0540..U+057F.
         return B2 in 16#80# .. 16#96#
           or else B2 in 16#A1# .. 16#BF#;
      elsif B1 = 16#D6# then
         --  Armenian U+0580..U+0587 and Hebrew U+0590..U+05BF.
         return B2 in 16#80# .. 16#87#
           or else B2 in 16#90# .. 16#BF#;
      elsif B1 = 16#D7# then
         --  Hebrew U+05C0..U+05FF; includes marks but keeps words whole.
         return B2 in 16#80# .. 16#BF#;
      elsif B1 in 16#D8# .. 16#DB# then
         --  Arabic block U+0600..U+06FF; bounded broad treatment.
         return B2 in 16#80# .. 16#BF#;
      elsif B1 = 16#DC# then
         --  Syriac letters U+0710..U+072F.
         return B2 in 16#90# .. 16#AF#;
      elsif B1 = 16#DD# then
         --  Syriac letters U+074D..U+074F.
         return B2 in 16#8D# .. 16#8F#;
      elsif B1 = 16#DE# then
         --  Thaana letters U+0780..U+07A5 and U+07B1.
         return B2 in 16#80# .. 16#A5#
           or else B2 = 16#B1#;
      elsif B1 = 16#DF# then
         --  NKo digits U+07C0..U+07C9, letters U+07CA..U+07EA,
         --  marks U+07EB..U+07F3, letter signs U+07F4..U+07F5,
         --  and U+07FA.
         return B2 in 16#80# .. 16#B5#
           or else B2 = 16#BA#;
      else
         return False;
      end if;
   end Is_Bounded_Two_Byte_Word_Element;

   function Is_UTF8_Continuation (Value : Natural) return Boolean is
     (Value in 16#80# .. 16#BF#);

   function Is_Bounded_Three_Byte_Word_Element
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      if Index + 2 > Text'Last
        or else not Is_UTF8_Continuation (B2)
        or else not Is_UTF8_Continuation (B3)
      then
         return False;
      elsif B1 = 16#E0# then
         if B2 = 16#A0# then
            --  Samaritan letters and marks U+0800..U+082D.
            return B3 in 16#80# .. 16#AD#;
         elsif B2 = 16#A1# then
            --  Mandaic letters and marks U+0840..U+085B.
            return B3 in 16#80# .. 16#9B#;
         end if;
         --  Bounded South/Southeast Asian script blocks used by supported
         --  locales: Devanagari through Malayalam, Sinhala, Thai, Lao, and
         --  Tibetan.
         return B2 in 16#A4# .. 16#BD#;
      elsif B1 = 16#E1# then
         if B2 = 16#9E# or else B2 = 16#9F# then
            --  Khmer U+1780..U+17FF, kept as bounded word text.
            return True;
         elsif B2 = 16#8E# then
            --  Cherokee letters U+13A0..U+13BF.
            return B3 in 16#A0# .. 16#BF#;
         elsif B2 = 16#8F# then
            --  Cherokee letters U+13C0..U+13FF.
            return True;
         elsif B2 in 16#90# .. 16#99# then
            --  Unified Canadian Aboriginal Syllabics U+1401..U+167F;
            --  U+1400 remains outside the bounded word set.
            return B2 > 16#90# or else B3 >= 16#81#;
         elsif B2 = 16#A4# then
            --  Limbu letters and signs U+1900..U+193B.
            return B3 in 16#80# .. 16#BB#;
         elsif B2 = 16#A5# then
            --  Limbu signs/digits U+1940..U+194F and Tai Le letters
            --  U+1950..U+1974; Limbu punctuation U+1944..U+1945 separates.
            return B3 in 16#80# .. 16#83#
              or else B3 in 16#86# .. 16#B4#;
         elsif B2 = 16#A6# then
            --  New Tai Lue letters and vowel signs U+1980..U+19BF.
            return True;
         elsif B2 = 16#A7# then
            --  New Tai Lue final consonants/vowels U+19C0..U+19C9,
            --  digits U+19D0..U+19DA; punctuation U+19DE..U+19DF separates.
            return B3 in 16#80# .. 16#89#
              or else B3 in 16#90# .. 16#9A#;
         elsif B2 = 16#A8# then
            --  Buginese letters/signs U+1A00..U+1A1B and Tai Tham
            --  letters/signs U+1A20..U+1A3F; punctuation U+1A1E..U+1A1F
            --  separates.
            return B3 in 16#80# .. 16#9B#
              or else B3 in 16#A0# .. 16#BF#;
         elsif B2 = 16#A9# then
            --  Tai Tham letters and signs U+1A40..U+1A7F;
            --  U+1A5F and U+1A7D..U+1A7E are unassigned and remain
            --  separators.
            return B3 in 16#80# .. 16#9E#
              or else B3 in 16#A0# .. 16#BC#
              or else B3 = 16#BF#;
         elsif B2 = 16#AA# then
            --  Tai Tham digits U+1A80..U+1A99 and repetition mark
            --  U+1AA7; punctuation U+1AA0..U+1AA6 and U+1AA8..U+1AAD
            --  separates.
            return B3 in 16#80# .. 16#89#
              or else B3 in 16#90# .. 16#99#
              or else B3 = 16#A7#;
         elsif B2 = 16#AC# then
            --  Balinese letters and signs U+1B00..U+1B3F.
            return True;
         elsif B2 = 16#AD# then
            --  Balinese letters/signs U+1B40..U+1B4C, digits
            --  U+1B50..U+1B59, and musical combining marks U+1B6B..U+1B73;
            --  punctuation and musical symbols separate.
            return B3 in 16#80# .. 16#8C#
              or else B3 in 16#90# .. 16#99#
              or else B3 in 16#AB# .. 16#B3#;
         elsif B2 = 16#AE# then
            --  Sundanese letters/signs/digits U+1B80..U+1BBF.
            return True;
         elsif B2 = 16#B0# then
            --  Lepcha letters/marks U+1C00..U+1C37; punctuation separates.
            return B3 in 16#80# .. 16#B7#;
         elsif B2 = 16#B1# then
            --  Lepcha digits and letters U+1C40..U+1C4F plus Ol Chiki
            --  digits/letters/modifiers U+1C50..U+1C7D; punctuation separates.
            return B3 in 16#80# .. 16#89#
              or else B3 in 16#8D# .. 16#BD#;
         elsif B2 = 16#9A# then
            --  Ogham letters U+1681..U+169A and Runic start U+16A0..U+16BF;
            --  Ogham space mark and punctuation remain separators.
            return B3 in 16#81# .. 16#9A#
              or else B3 in 16#A0# .. 16#BF#;
         elsif B2 = 16#9B# then
            --  Runic letters U+16C0..U+16F8.
            return B3 in 16#80# .. 16#B8#;
         end if;
         --  Georgian letters U+10A0..U+10FF, Ethiopic letters
         --  U+1200..U+135A, and Georgian Mtavruli U+1C90..U+1CBF;
         --  punctuation remains a separator.
         return (B2 = 16#82# and then B3 >= 16#A0#)
           or else (B2 = 16#83#
                    and then (B3 <= 16#85#
                              or else B3 = 16#87#
                              or else B3 = 16#8D#
                              or else B3 in 16#90# .. 16#BA#
                              or else B3 in 16#BC# .. 16#BF#))
           or else B2 in 16#88# .. 16#8C#
           or else (B2 = 16#8D# and then B3 <= 16#9A#)
           or else (B2 = 16#B2# and then B3 in 16#90# .. 16#BF#);
      elsif B1 = 16#E2# then
         if B2 = 16#B4# then
            --  Tifinagh letters U+2D30..U+2D3F.
            return B3 in 16#B0# .. 16#BF#;
         elsif B2 = 16#B5# then
            --  Tifinagh letters U+2D40..U+2D67, modifier U+2D6F,
            --  and combining mark U+2D7F; U+2D70 punctuation separates.
            return B3 in 16#80# .. 16#A7#
              or else B3 = 16#AF#
              or else B3 = 16#BF#;
         end if;
         return False;
      elsif B1 = 16#E3# then
         --  Hiragana, Katakana, and Hangul compatibility Jamo.
         return B2 = 16#81#
           or else (B2 = 16#82# and then B3 <= 16#BF#)
           or else B2 = 16#83#
           or else (B2 = 16#84# and then B3 in 16#B1# .. 16#BF#)
           or else (B2 = 16#85# and then B3 <= 16#A3#)
           or else (B2 = 16#86# and then B3 <= 16#8E#);
      elsif B1 = 16#E4# then
         --  CJK Unified Ideographs start at U+4E00.
         return B2 >= 16#B8#;
      elsif B1 in 16#E5# .. 16#E8# then
         --  CJK Unified Ideographs middle range.
         return True;
      elsif B1 = 16#E9# then
         --  CJK Unified Ideographs end at U+9FFF.
         return B2 <= 16#BF#;
      elsif B1 = 16#EA# then
         if B2 in 16#94# .. 16#97# then
            --  Vai syllables U+A500..U+A5FF.
            return True;
         elsif B2 = 16#98# then
            --  Vai syllables/symbol/digits U+A600..U+A62B;
            --  punctuation U+A60D..U+A60F separates.
            return B3 in 16#80# .. 16#8C#
              or else B3 in 16#90# .. 16#AB#;
         elsif B2 = 16#A2# then
            --  Saurashtra letters/signs U+A880..U+A8BF.
            return True;
         elsif B2 = 16#A3# then
            --  Saurashtra signs U+A8C0..U+A8C5 and digits U+A8D0..U+A8D9;
            --  danda punctuation U+A8CE..U+A8CF separates.
            return B3 in 16#80# .. 16#85#
              or else B3 in 16#90# .. 16#99#;
         elsif B2 = 16#A4# then
            --  Kayah Li letters/marks/digits U+A900..U+A92D and Rejang
            --  letters U+A930..U+A93F; Kayah Li punctuation
            --  U+A92E..U+A92F separates.
            return B3 in 16#80# .. 16#AD#
              or else B3 in 16#B0# .. 16#BF#;
         elsif B2 = 16#A5# then
            --  Rejang letters/marks U+A930..U+A953;
            --  section mark U+A95F separates.
            return B3 <= 16#93#;
         elsif B2 = 16#A6# then
            --  Javanese letters/signs U+A980..U+A9BF.
            return True;
         elsif B2 = 16#A7# then
            --  Javanese pangkon/repetition/digits U+A9C0, U+A9CF,
            --  and U+A9D0..U+A9D9; punctuation separates.
            return B3 = 16#80#
              or else B3 = 16#8F#
              or else B3 in 16#90# .. 16#99#;
         elsif B2 = 16#A8# then
            --  Cham letters/marks U+AA00..U+AA3F.
            return True;
         elsif B2 = 16#A9# then
            --  Cham finals/signs/digits U+AA40..U+AA59;
            --  punctuation U+AA5C..U+AA5F separates.
            return B3 in 16#80# .. 16#8D#
              or else B3 in 16#90# .. 16#99#;
         end if;
         --  Hangul syllables start at U+AC00.
         return B2 >= 16#B0#;
      elsif B1 = 16#EB# or else B1 = 16#EC# then
         --  Hangul syllables middle range.
         return True;
      elsif B1 = 16#ED# then
         --  Hangul syllables end at U+D7AF.
         return B2 <= 16#9E#;
      elsif B1 = 16#EF# then
         --  Fullwidth ASCII compatibility forms, halfwidth Katakana, and
         --  presentation forms.
         return (B2 = 16#BC#
                 and then (B3 in 16#90# .. 16#99#
                           or else B3 in 16#A1# .. 16#BA#))
           or else (B2 = 16#BD#
                    and then (B3 in 16#81# .. 16#9A#
                              or else B3 in 16#A6# .. 16#BF#))
           or else (B2 = 16#BE# and then B3 in 16#80# .. 16#9F#)
           or else (B2 = 16#AC#
                 and then (B3 in 16#80# .. 16#86# or else B3 >= 16#9D#))
           or else B2 in 16#AD# .. 16#B7#
           or else (B2 = 16#B9# and then B3 >= 16#B0#)
           or else B2 in 16#BA# .. 16#BB#;
      else
         return False;
      end if;
   end Is_Bounded_Three_Byte_Word_Element;

   function Is_Bounded_Four_Byte_Word_Element
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
      B4 : constant Natural :=
        (if Index + 3 <= Text'Last then Character'Pos (Text (Index + 3))
         else 0);
   begin
      if Index + 3 > Text'Last
        or else not Is_UTF8_Continuation (B2)
        or else not Is_UTF8_Continuation (B3)
        or else not Is_UTF8_Continuation (B4)
      then
         return False;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#80# then
         --  Linear B syllables U+10000..U+1004D; reserved gaps separate.
         return B4 <= 16#8B#
           or else B4 in 16#8D# .. 16#A6#
           or else B4 in 16#A8# .. 16#BA#
           or else B4 in 16#BC# .. 16#BD#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#81# then
         --  Linear B syllables U+10040..U+1004D and U+10050..U+1005D.
         return B4 <= 16#8D#
           or else B4 in 16#90# .. 16#9D#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#82# then
         --  Linear B ideograms U+10080..U+100BF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#83# then
         --  Linear B ideograms U+100C0..U+100FA.
         return B4 <= 16#BA#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#84# then
         --  Aegean numbers U+10107..U+10133 and measures
         --  U+10137..U+1013F; punctuation U+10100..U+10102 separates.
         return B4 in 16#87# .. 16#B3#
           or else B4 in 16#B7# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8A# then
         --  Lycian letters U+10280..U+1029C plus Carian letters
         --  U+102A0..U+102BF.
         return B4 <= 16#9C#
           or else B4 >= 16#A0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8B# then
         --  Carian letters U+102C0..U+102D0.
         return B4 <= 16#90#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8C# then
         --  Old Italic letters/numerals U+10300..U+10323, letters
         --  U+1032D..U+1032F, and Gothic letters U+10330..U+1033F.
         return B4 <= 16#A3#
           or else B4 >= 16#AD#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8D# then
         --  Gothic letters U+10340..U+1034A and Old Permic letters/marks
         --  U+10350..U+1037A.
         return B4 <= 16#8A#
           or else B4 in 16#90# .. 16#BA#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8E# then
         --  Ugaritic letters U+10380..U+1039D plus Old Persian signs
         --  U+103A0..U+103BF; Ugaritic word divider U+1039F separates.
         return B4 <= 16#9D#
           or else B4 >= 16#A0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#8F# then
         --  Old Persian signs U+103C0..U+103C3, logograms
         --  U+103C8..U+103CF, and numbers U+103D1..U+103D5; word
         --  divider U+103D0 separates.
         return B4 <= 16#83#
           or else B4 in 16#88# .. 16#8F#
           or else B4 in 16#91# .. 16#95#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#90# then
         --  Deseret letters U+10400..U+1043F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#91# then
         --  Deseret letters U+10440..U+1044F and Shavian letters
         --  U+10450..U+1047F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#92# then
         --  Osmanya letters U+10480..U+1049D, digits U+104A0..U+104A9,
         --  and Osage uppercase letters U+104B0..U+104BF.
         return B4 <= 16#9D#
           or else B4 in 16#A0# .. 16#A9#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#93# then
         --  Osage uppercase/lowercase letters U+104C0..U+104D3 and
         --  U+104D8..U+104FB.
         return B4 <= 16#93#
           or else B4 in 16#98# .. 16#BB#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#94# then
         --  Elbasan letters U+10500..U+10527 plus Caucasian Albanian
         --  letters U+10530..U+1053F.
         return B4 <= 16#A7#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#95# then
         --  Caucasian Albanian letters U+10540..U+10563 plus Vithkuqi
         --  letters U+10570..U+1057A and U+1057C..U+1057F.
         return B4 <= 16#A3#
           or else B4 in 16#B0# .. 16#BA#
           or else B4 in 16#BC# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#96# then
         --  Vithkuqi letters U+10580..U+1058A, U+1058C..U+10592,
         --  U+10594..U+10595, U+10597..U+105A1, U+105A3..U+105B1,
         --  U+105B3..U+105B9, and U+105BB..U+105BC.
         return B4 <= 16#8A#
           or else B4 in 16#8C# .. 16#92#
           or else B4 in 16#94# .. 16#95#
           or else B4 in 16#97# .. 16#A1#
           or else B4 in 16#A3# .. 16#B1#
           or else B4 in 16#B3# .. 16#B9#
           or else B4 in 16#BB# .. 16#BC#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#97# then
         --  Todhri letters U+105C0..U+105F3.
         return B4 <= 16#B3#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A0# then
         --  Cypriot syllables U+10800..U+1083F; reserved gaps separate.
         return B4 <= 16#85#
           or else B4 = 16#88#
           or else B4 in 16#8A# .. 16#B5#
           or else B4 in 16#B7# .. 16#B8#
           or else B4 = 16#BC#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A1# then
         --  Imperial Aramaic letters/numbers U+10840..U+1085F and
         --  Palmyrene letters/numbers U+10860..U+1087F; section signs
         --  and fleurons separate.
         return B4 <= 16#95#
           or else B4 in 16#98# .. 16#9F#
           or else B4 in 16#A0# .. 16#B6#
           or else B4 in 16#B9# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A2# then
         --  Nabataean letters U+10880..U+1089E and numbers
         --  U+108A7..U+108AF.
         return B4 <= 16#9E#
           or else B4 in 16#A7# .. 16#AF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A3# then
         --  Hatran letters U+108E0..U+108F2 and U+108F4..U+108F5,
         --  plus numbers U+108FB..U+108FF.
         return B4 in 16#A0# .. 16#B2#
           or else B4 in 16#B4# .. 16#B5#
           or else B4 in 16#BB# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A4# then
         --  Phoenician letters/numbers U+10900..U+1091B and Lydian
         --  letters U+10920..U+10939; word separators/punctuation separate.
         return B4 <= 16#9B#
           or else B4 in 16#A0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A5# then
         --  Sidetic letters U+10940..U+10959.
         return B4 <= 16#99#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A6# then
         --  Meroitic Hieroglyphs U+10980..U+1099F plus Meroitic Cursive
         --  U+109A0..U+109B7 and U+109BC..U+109BF.
         return B4 <= 16#B7#
           or else B4 >= 16#BC#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A7# then
         --  Meroitic Cursive U+109C0..U+109CF and U+109D2..U+109FF.
         return B4 <= 16#8F#
           or else B4 >= 16#92#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A8# then
         --  Kharoshthi letters/marks U+10A00..U+10A3F with reserved gaps.
         return B4 <= 16#83#
           or else B4 in 16#85# .. 16#86#
           or else B4 in 16#8C# .. 16#93#
           or else B4 in 16#95# .. 16#97#
           or else B4 in 16#99# .. 16#B5#
           or else B4 in 16#B8# .. 16#BA#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#A9# then
         --  Kharoshthi digits/numbers U+10A40..U+10A48 and Old South
         --  Arabian letters/numbers U+10A60..U+10A7F; Kharoshthi
         --  punctuation U+10A50..U+10A58 separates.
         return B4 <= 16#88#
           or else B4 >= 16#A0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#AA# then
         --  Old North Arabian letters/numbers U+10A80..U+10A9F.
         return B4 <= 16#9F#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#AB# then
         --  Manichaean letters/logogram/marks U+10AC0..U+10AE6 and
         --  numbers U+10AEB..U+10AEF; punctuation U+10AF0..U+10AF6
         --  separates.
         return B4 <= 16#A6#
           or else B4 in 16#AB# .. 16#AF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#AC# then
         --  Avestan letters U+10B00..U+10B35; punctuation separates.
         return B4 <= 16#B5#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#AD# then
         --  Inscriptional Parthian letters/numbers U+10B40..U+10B5F and
         --  Inscriptional Pahlavi letters/numbers U+10B60..U+10B7F.
         return B4 <= 16#95#
           or else B4 in 16#98# .. 16#9F#
           or else B4 in 16#A0# .. 16#B2#
           or else B4 in 16#B8# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#AE# then
         --  Psalter Pahlavi letters U+10B80..U+10B91 and numbers
         --  U+10BA9..U+10BAF; punctuation U+10B99..U+10B9C separates.
         return B4 <= 16#91#
           or else B4 in 16#A9# .. 16#AF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B0# then
         --  Old Turkic letters U+10C00..U+10C3F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B1# then
         --  Old Turkic letters U+10C40..U+10C48.
         return B4 <= 16#88#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B2# then
         --  Old Hungarian uppercase letters U+10C80..U+10CB2.
         return B4 <= 16#B2#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B3# then
         --  Old Hungarian lowercase letters U+10CC0..U+10CF2 and
         --  numbers U+10CFA..U+10CFF.
         return B4 <= 16#B2#
           or else B4 in 16#BA# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B4# then
         --  Hanifi Rohingya letters/marks U+10D00..U+10D27 and digits
         --  U+10D30..U+10D39.
         return B4 <= 16#A7#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B5# then
         --  Garay digits, vowel signs/modifiers, uppercase/lowercase
         --  letters, and marks U+10D40..U+10D6D; punctuation and symbols
         --  separate.
         return B4 <= 16#AD#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B6# then
         --  Garay lowercase letters U+10D80..U+10D85.
         return B4 <= 16#85#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#B9# then
         --  Rumi numeral symbols U+10E60..U+10E7E.
         return B4 in 16#A0# .. 16#BE#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#BA# then
         --  Yezidi letters/marks U+10E80..U+10EAD and U+10EB0..U+10EB1.
         return B4 <= 16#AD#
           or else B4 in 16#B0# .. 16#B1#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#BC# then
         --  Old Sogdian letters/numbers U+10F00..U+10F27 and Sogdian
         --  letters/marks/numbers U+10F30..U+10F3F.
         return B4 <= 16#A7#
           or else B4 in 16#B0# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#BD# then
         --  Sogdian letters/marks/numbers U+10F40..U+10F54 plus Old
         --  Uyghur letters U+10F70..U+10F7F.
         return B4 <= 16#94#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#BE# then
         --  Old Uyghur letters U+10F80..U+10F89 plus Chorasmian letters
         --  U+10FB0..U+10FBF.
         return B4 <= 16#89#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#90# and then B3 = 16#BF# then
         --  Chorasmian letters U+10FC0..U+10FCB plus Elymaic letters
         --  U+10FE0..U+10FF6.
         return B4 <= 16#8B#
           or else B4 in 16#A0# .. 16#B6#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#80# then
         --  Brahmi letters/marks U+11000..U+1103F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#81# then
         --  Brahmi letters/marks/numbers U+11040..U+11046,
         --  U+11052..U+11075, and U+1107F; punctuation separates.
         return B4 in 16#80# .. 16#86#
           or else B4 in 16#92# .. 16#B5#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#82# then
         --  Kaithi letters/marks U+11080..U+110BA; punctuation separates.
         return B4 <= 16#BA#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#83# then
         --  Kaithi sign U+110C2 plus Sora Sompeng letters U+110D0..U+110E8
         --  and digits U+110F0..U+110F9.
         return B4 = 16#82#
           or else B4 in 16#90# .. 16#A8#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#84# then
         --  Chakma letters/marks U+11100..U+11134 and digits
         --  U+11136..U+1113F; punctuation separates.
         return B4 <= 16#B4#
           or else B4 in 16#B6# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#85# then
         --  Chakma letters/marks U+11144..U+11147.
         return B4 in 16#84# .. 16#87#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#86# then
         --  Sharada letters/marks U+11180..U+111BF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#87# then
         --  Sharada signs/numbers U+111C0..U+111C4, U+111C9..U+111CC,
         --  U+111CE..U+111DA, and U+111DC; punctuation separates.
         return B4 in 16#80# .. 16#84#
           or else B4 in 16#89# .. 16#8C#
           or else B4 in 16#8E# .. 16#9A#
           or else B4 = 16#9C#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#88# then
         --  Khojki letters/marks U+11200..U+1123F; gaps separate.
         return B4 <= 16#91#
           or else B4 in 16#93# .. 16#B7#
           or else B4 in 16#BE# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#89# then
         --  Khojki marks U+11240..U+11241.
         return B4 <= 16#81#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8A# then
         --  Multani letters U+11280..U+112A8 plus Khudawadi
         --  letters/marks U+112B0..U+112BF; gaps separate.
         return B4 <= 16#86#
           or else B4 = 16#88#
           or else B4 in 16#8A# .. 16#8D#
           or else B4 in 16#8F# .. 16#9D#
           or else B4 in 16#9F# .. 16#A8#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8B# then
         --  Khudawadi letters/marks U+112C0..U+112EA and digits
         --  U+112F0..U+112F9.
         return B4 <= 16#AA#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8C# then
         --  Grantha letters/marks U+11300..U+1133F; gaps separate.
         return B4 <= 16#83#
           or else B4 in 16#85# .. 16#8C#
           or else B4 in 16#8F# .. 16#90#
           or else B4 in 16#93# .. 16#A8#
           or else B4 in 16#AA# .. 16#B0#
           or else B4 in 16#B2# .. 16#B3#
           or else B4 in 16#B5# .. 16#B9#
           or else B4 in 16#BB# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8D# then
         --  Grantha letters/marks U+11340..U+11374; gaps separate.
         return B4 <= 16#84#
           or else B4 in 16#87# .. 16#88#
           or else B4 in 16#8B# .. 16#8D#
           or else B4 = 16#90#
           or else B4 = 16#97#
           or else B4 in 16#9D# .. 16#A3#
           or else B4 in 16#A6# .. 16#AC#
           or else B4 in 16#B0# .. 16#B4#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8E# then
         --  Tulu-Tigalari letters/marks U+11380..U+113BF with reserved
         --  gaps separate.
         return B4 <= 16#89#
           or else B4 = 16#8B#
           or else B4 = 16#8E#
           or else B4 in 16#90# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#8F# then
         --  Tulu-Tigalari marks U+113C0, U+113C2, U+113C5,
         --  U+113C7..U+113CA, U+113CC..U+113D3, and
         --  U+113E1..U+113E2; punctuation separates.
         return B4 = 16#80#
           or else B4 = 16#82#
           or else B4 = 16#85#
           or else B4 in 16#87# .. 16#8A#
           or else B4 in 16#8C# .. 16#93#
           or else B4 in 16#A1# .. 16#A2#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#90# then
         --  Newa letters/marks U+11400..U+1143F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#91# then
         --  Newa letters/marks/numbers U+11440..U+1144A,
         --  U+11450..U+11459, and U+1145E..U+11461; punctuation separates.
         return B4 <= 16#8A#
           or else B4 in 16#90# .. 16#99#
           or else B4 in 16#9E# .. 16#A1#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#92# then
         --  Tirhuta letters/marks U+11480..U+114BF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#93# then
         --  Tirhuta signs/digits U+114C0..U+114C5, U+114C7,
         --  and U+114D0..U+114D9; punctuation separates.
         return B4 <= 16#85#
           or else B4 = 16#87#
           or else B4 in 16#90# .. 16#99#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#96# then
         --  Siddham letters/marks U+11580..U+115BF; gaps separate.
         return B4 <= 16#B5#
           or else B4 in 16#B8# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#97# then
         --  Siddham marks U+115C0 and U+115D8..U+115DD.
         return B4 = 16#80#
           or else B4 in 16#98# .. 16#9D#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#98# then
         --  Modi letters/marks U+11600..U+1163F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#99# then
         --  Modi sign U+11640, letter U+11644, and digits U+11650..U+11659;
         --  punctuation separates.
         return B4 = 16#80#
           or else B4 = 16#84#
           or else B4 in 16#90# .. 16#99#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#9A# then
         --  Takri letters/marks U+11680..U+116B8; punctuation separates.
         return B4 <= 16#B8#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#9B# then
         --  Takri digits U+116C0..U+116C9.
         return B4 in 16#80# .. 16#89#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#9C# then
         --  Ahom letters/marks/numbers U+11700..U+1171A,
         --  U+1171D..U+1172B, and U+11730..U+1173B; punctuation separates.
         return B4 <= 16#9A#
           or else B4 in 16#9D# .. 16#AB#
           or else B4 in 16#B0# .. 16#BB#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#9D# then
         --  Ahom letters U+11740..U+11746.
         return B4 in 16#80# .. 16#86#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A0# then
         --  Dogra letters/marks U+11800..U+1183A.
         return B4 <= 16#BA#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A2# then
         --  Warang Citi letters U+118A0..U+118BF.
         return B4 >= 16#A0#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A3# then
         --  Warang Citi letters/digits U+118C0..U+118F2 and letter U+118FF.
         return B4 <= 16#B2#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A4# then
         --  Dives Akuru letters/marks U+11900..U+1193F; gaps separate.
         return B4 <= 16#86#
           or else B4 = 16#89#
           or else B4 in 16#8C# .. 16#93#
           or else B4 in 16#95# .. 16#96#
           or else B4 in 16#98# .. 16#B5#
           or else B4 in 16#B7# .. 16#B8#
           or else B4 in 16#BB# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A5# then
         --  Dives Akuru marks U+11940..U+11943 and digits U+11950..U+11959.
         return B4 <= 16#83#
           or else B4 in 16#90# .. 16#99#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A6# then
         --  Nandinagari letters/marks U+119A0..U+119BF; gaps separate.
         return B4 in 16#A0# .. 16#A7#
           or else B4 in 16#AA# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A7# then
         --  Nandinagari letters/marks U+119C0..U+119E4; gaps separate.
         return B4 <= 16#97#
           or else B4 in 16#9A# .. 16#A1#
           or else B4 in 16#A3# .. 16#A4#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A8# then
         --  Zanabazar Square letters/marks U+11A00..U+11A3E.
         return B4 <= 16#BE#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#A9# then
         --  Zanabazar Square mark U+11A47 plus Soyombo letters/marks
         --  U+11A50..U+11A7F.
         return B4 = 16#87#
           or else B4 in 16#90# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#AA# then
         --  Soyombo letters/marks U+11A80..U+11A99 and letter U+11A9D.
         return B4 <= 16#99#
           or else B4 = 16#9D#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#AB# then
         --  Pau Cin Hau letters U+11AC0..U+11AF8.
         return B4 in 16#80# .. 16#B8#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#AF# then
         --  Sunuwar letters U+11BC0..U+11BE0 and digits U+11BF0..U+11BF9;
         --  punctuation separates.
         return B4 <= 16#A0#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B0# then
         --  Bhaiksuki letters/marks U+11C00..U+11C08, U+11C0A..U+11C36,
         --  and U+11C38..U+11C3F; punctuation separates.
         return B4 <= 16#88#
           or else B4 in 16#8A# .. 16#B6#
           or else B4 in 16#B8# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B1# then
         --  Bhaiksuki sign/digits/numbers U+11C40 and U+11C50..U+11C6C,
         --  plus Marchen letters U+11C72..U+11C7F.
         return B4 = 16#80#
           or else B4 in 16#90# .. 16#AC#
           or else B4 in 16#B2# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B2# then
         --  Marchen letters/marks U+11C80..U+11C8F, U+11C92..U+11CA7,
         --  and U+11CA9..U+11CB6.
         return B4 <= 16#8F#
           or else B4 in 16#92# .. 16#A7#
           or else B4 in 16#A9# .. 16#B6#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B4# then
         --  Masaram Gondi letters/marks U+11D00..U+11D47; gaps separate.
         return B4 <= 16#86#
           or else B4 in 16#88# .. 16#89#
           or else B4 in 16#8B# .. 16#B6#
           or else B4 = 16#BA#
           or else B4 in 16#BC# .. 16#BD#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B5# then
         --  Masaram Gondi marks U+11D40..U+11D47 and digits U+11D50..U+11D59,
         --  plus Gunjala Gondi letters U+11D60..U+11D7F.
         return B4 in 16#80# .. 16#87#
           or else B4 in 16#90# .. 16#99#
           or else B4 >= 16#A0#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B6# then
         --  Gunjala Gondi letters/marks U+11D80..U+11D98 and digits
         --  U+11DA0..U+11DA9, plus Tolong Siki letters
         --  U+11DB0..U+11DBF; gaps separate.
         return B4 <= 16#8E#
           or else B4 in 16#90# .. 16#91#
           or else B4 in 16#93# .. 16#98#
           or else B4 in 16#A0# .. 16#A9#
           or else B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#B7# then
         --  Tolong Siki letters/signs U+11DC0..U+11DDB and digits
         --  U+11DE0..U+11DE9.
         return B4 <= 16#9B#
           or else B4 in 16#A0# .. 16#A9#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#BB# then
         --  Makasar letters/marks U+11EE0..U+11EF6.
         return B4 in 16#A0# .. 16#B6#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#BC# then
         --  Kawi letters/marks U+11F00..U+11F3F; gaps separate.
         return B4 <= 16#90#
           or else B4 in 16#92# .. 16#BA#
           or else B4 in 16#BE# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#91# and then B3 = 16#BD# then
         --  Kawi marks U+11F40..U+11F42 and digits U+11F50..U+11F59.
         return B4 <= 16#82#
           or else B4 in 16#90# .. 16#99#;
      elsif B1 = 16#F0# and then B2 = 16#92# and then B3 <= 16#8F# then
         --  Cuneiform signs U+12000..U+123FF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#92# and then B3 = 16#90# then
         --  Cuneiform numeric signs U+12400..U+1243F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#92# and then B3 = 16#91# then
         --  Cuneiform numeric signs U+12440..U+1246E; cuneiform
         --  punctuation U+12470..U+12474 separates.
         return B4 <= 16#AE#;
      elsif B1 = 16#F0# and then B2 = 16#92#
        and then B3 in 16#92# .. 16#94#
      then
         --  Early Dynastic Cuneiform signs U+12480..U+1253F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#92# and then B3 = 16#95# then
         --  Early Dynastic Cuneiform signs U+12540..U+12543.
         return B4 <= 16#83#;
      elsif B1 = 16#F0# and then B2 = 16#93# and then B3 <= 16#8F# then
         --  Egyptian Hieroglyphs U+13000..U+133FF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#93# and then B3 = 16#90# then
         --  Egyptian Hieroglyphs U+13400..U+1342E.
         return B4 <= 16#AE#;
      elsif B1 = 16#F0# and then B2 = 16#94#
        and then B3 in 16#90# .. 16#98#
      then
         --  Anatolian Hieroglyphs U+14400..U+1463F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#94# and then B3 = 16#99# then
         --  Anatolian Hieroglyphs U+14640..U+14646.
         return B4 <= 16#86#;
      elsif B1 = 16#F0# and then B2 = 16#96#
        and then B3 in 16#A0# .. 16#A7#
      then
         --  Bamum Supplement letters U+16800..U+169FF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#A8# then
         --  Bamum Supplement letters U+16A00..U+16A38.
         return B4 <= 16#B8#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#84# then
         --  Gurung Khema letters/marks/digits U+16100..U+16139.
         return B4 <= 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#B9# then
         --  Medefaidrin letters U+16E40..U+16E7F.
         return B4 >= 16#80#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#BA# then
         --  Medefaidrin letters/numbers U+16E80..U+16E96 plus Beria Erfe
         --  uppercase letters U+16EA0..U+16EB8 and lowercase letters
         --  U+16EBB..U+16EBF.
         return B4 <= 16#96#
           or else B4 in 16#A0# .. 16#B8#
           or else B4 in 16#BB# .. 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#BB# then
         --  Beria Erfe lowercase letters U+16EC0..U+16ED3.
         return B4 <= 16#93#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#A9# then
         --  Tangsa letters U+16A70..U+16A7F.
         return B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#AA# then
         --  Tangsa letters/marks U+16A80..U+16ABE.
         return B4 <= 16#BE#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#AB# then
         --  Tangsa digits U+16AC0..U+16AC9.
         return B4 <= 16#89#;
      elsif B1 = 16#F0# and then B2 = 16#96# and then B3 = 16#B5# then
         --  Kirat Rai signs/letters/marks U+16D40..U+16D6D and digits
         --  U+16D70..U+16D79; punctuation separates.
         return B4 <= 16#AD#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#97# then
         --  Tangut ideographs U+17000..U+17FFF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#98# and then B3 <= 16#9E# then
         --  Tangut ideographs U+18000..U+187BF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#98# and then B3 = 16#9F# then
         --  Tangut ideographs U+187C0..U+187FB.
         return B4 <= 16#BB#;
      elsif B1 = 16#F0# and then B2 = 16#98#
        and then B3 in 16#AC# .. 16#B2#
      then
         --  Khitan Small Script characters U+18B00..U+18CBF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#98# and then B3 = 16#B3# then
         --  Khitan Small Script characters U+18CC0..U+18CD5 plus the
         --  missing-character marker U+18CFF.
         return B4 <= 16#95#
           or else B4 = 16#BF#;
      elsif B1 = 16#F0# and then B2 = 16#98# and then B3 = 16#B4# then
         --  Tangut Supplement ideographs U+18D00..U+18D1E.
         return B4 <= 16#9E#;
      elsif B1 = 16#F0# and then B2 = 16#9B# and then B3 = 16#85# then
         --  Nushu characters U+1B170..U+1B17F.
         return B4 >= 16#B0#;
      elsif B1 = 16#F0# and then B2 = 16#9B#
        and then B3 in 16#86# .. 16#8A#
      then
         --  Nushu characters U+1B180..U+1B2BF.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#9B# and then B3 = 16#8B# then
         --  Nushu characters U+1B2C0..U+1B2FB.
         return B4 <= 16#BB#;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#8A# then
         --  Toto letters/mark U+1E290..U+1E2AE.
         return B4 in 16#90# .. 16#AE#;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#93# then
         --  Nag Mundari letters/marks U+1E4D0..U+1E4EB and digits
         --  U+1E4F0..U+1E4F9.
         return B4 in 16#90# .. 16#AB#
           or else B4 in 16#B0# .. 16#B9#;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#97# then
         --  Ol Onal letters/marks U+1E5D0..U+1E5F0 and digits
         --  U+1E5F1..U+1E5FA; abbreviation sign separates.
         return B4 in 16#90# .. 16#BA#;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#9B# then
         --  Tai Yo letters/signs U+1E6C0..U+1E6F5; symbols separate.
         return B4 <= 16#B5#;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#A4# then
         --  Adlam letters/marks U+1E900..U+1E93F.
         return True;
      elsif B1 = 16#F0# and then B2 = 16#9E# and then B3 = 16#A5# then
         --  Adlam marks U+1E940..U+1E94B and digits U+1E950..U+1E959.
         return B4 <= 16#8B#
           or else B4 in 16#90# .. 16#99#;
      else
         return False;
      end if;
   end Is_Bounded_Four_Byte_Word_Element;

   function Is_Bounded_Right_Apostrophe (Text : String; Index : Natural)
      return Boolean
   is
   begin
      return Index + 2 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#E2#
        and then Character'Pos (Text (Index + 1)) = 16#80#
        and then Character'Pos (Text (Index + 2)) = 16#99#;
   end Is_Bounded_Right_Apostrophe;

   function Is_Bounded_Digit_At (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
      B4 : constant Natural :=
        (if Index + 3 <= Text'Last then Character'Pos (Text (Index + 3))
         else 0);
   begin
      if Text (Index) in '0' .. '9' then
         return True;
      elsif Index + 1 <= Text'Last
        and then B1 = 16#D9#
      then
         --  Arabic-Indic digits U+0660..U+0669.
         return B2 in 16#A0# .. 16#A9#;
      elsif Index + 1 <= Text'Last
        and then B1 = 16#DB#
      then
         --  Extended Arabic-Indic digits U+06F0..U+06F9.
         return B2 in 16#B0# .. 16#B9#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#A5#
      then
         --  Devanagari digits U+0966..U+096F.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#A7#
      then
         --  Bengali digits U+09E6..U+09EF.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#A9#
      then
         --  Gurmukhi digits U+0A66..U+0A6F.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#AB#
      then
         --  Gujarati digits U+0AE6..U+0AEF.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#AD#
      then
         --  Odia digits U+0B66..U+0B6F.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#AF#
      then
         --  Tamil digits U+0BE6..U+0BEF.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#B1#
      then
         --  Telugu digits U+0C66..U+0C6F.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#B3#
      then
         --  Kannada digits U+0CE6..U+0CEF.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#B5#
      then
         --  Malayalam digits U+0D66..U+0D6F.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#B7#
      then
         --  Sinhala Lith digits U+0DE6..U+0DEF.
         return B3 in 16#A6# .. 16#AF#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#B9#
      then
         --  Thai digits U+0E50..U+0E59.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#BB#
      then
         --  Lao digits U+0ED0..U+0ED9.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E0#
        and then B2 = 16#BC#
      then
         --  Tibetan digits U+0F20..U+0F29.
         return B3 in 16#A0# .. 16#A9#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#81#
      then
         --  Myanmar digits U+1040..U+1049.
         return B3 in 16#80# .. 16#89#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#A5#
      then
         --  Limbu digits U+1946..U+194F.
         return B3 in 16#86# .. 16#8F#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#A7#
      then
         --  New Tai Lue digits U+19D0..U+19D9.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#AD#
      then
         --  Balinese digits U+1B50..U+1B59.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#AE#
      then
         --  Sundanese digits U+1BB0..U+1BB9.
         return B3 in 16#B0# .. 16#B9#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#B1#
      then
         --  Lepcha digits U+1C40..U+1C49 and Ol Chiki digits
         --  U+1C50..U+1C59.
         return B3 in 16#80# .. 16#89# or else B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#AA#
      then
         --  Tai Tham Hora digits U+1A80..U+1A89 and Tham digits
         --  U+1A90..U+1A99.
         return B3 in 16#80# .. 16#89# or else B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then B2 = 16#9F#
      then
         --  Khmer digits U+17E0..U+17E9.
         return B3 in 16#A0# .. 16#A9#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EF#
        and then B2 = 16#BC#
      then
         --  Fullwidth digits U+FF10..U+FF19.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EA#
        and then B2 = 16#98#
      then
         --  Vai digits U+A620..U+A629.
         return B3 in 16#A0# .. 16#A9#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EA#
        and then B2 = 16#A3#
      then
         --  Saurashtra digits U+A8D0..U+A8D9.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EA#
        and then B2 = 16#A4#
      then
         --  Kayah Li digits U+A900..U+A909.
         return B3 in 16#80# .. 16#89#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EA#
        and then B2 = 16#A7#
      then
         --  Javanese digits U+A9D0..U+A9D9.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#EA#
        and then B2 = 16#A9#
      then
         --  Cham digits U+AA50..U+AA59.
         return B3 in 16#90# .. 16#99#;
      elsif Index + 3 <= Text'Last
        and then B1 = 16#F0#
      then
         --  Supplementary-plane script digits for bounded Hanifi Rohingya,
         --  Garay, Osmanya, Tangsa, Gurung Khema, Kirat Rai, Ol Onal,
         --  Nag Mundari, Adlam, Brahmi,
         --  Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta,
         --  Modi, Takri, Ahom, Warang Citi, Dives Akuru, Sunuwar, Bhaiksuki,
         --  Masaram Gondi, Gunjala Gondi, Tolong Siki, and Kawi text.
         return (B2 = 16#90# and then B3 = 16#B4#
                 and then B4 in 16#B0# .. 16#B9#)
           or else (B2 = 16#90# and then B3 = 16#B5#
                    and then B4 in 16#80# .. 16#89#)
           or else (B2 = 16#90# and then B3 = 16#92#
                    and then B4 in 16#A0# .. 16#A9#)
           or else (B2 = 16#9E# and then B3 = 16#A5#
                    and then B4 in 16#90# .. 16#99#)
           or else (B2 = 16#9E# and then B3 = 16#97#
                    and then B4 in 16#B1# .. 16#BA#)
           or else (B2 = 16#96# and then B3 = 16#AB#
                    and then B4 in 16#80# .. 16#89#)
           or else (B2 = 16#96# and then B3 = 16#84#
                    and then B4 in 16#B0# .. 16#B9#)
           or else (B2 = 16#96# and then B3 = 16#B5#
                    and then B4 in 16#B0# .. 16#B9#)
           or else (B2 = 16#9E# and then B3 = 16#93#
                    and then B4 in 16#B0# .. 16#B9#)
           or else (B2 = 16#91#
                    and then
                      ((B3 = 16#81# and then B4 in 16#A6# .. 16#AF#)
                       or else (B3 = 16#83# and then B4 in 16#B0# .. 16#B9#)
                       or else (B3 = 16#84# and then B4 in 16#B6# .. 16#BF#)
                       or else (B3 = 16#87# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#8B# and then B4 in 16#B0# .. 16#B9#)
                       or else (B3 = 16#91# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#93# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#99# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#9B# and then B4 in 16#80# .. 16#89#)
                       or else (B3 = 16#9C# and then B4 in 16#B0# .. 16#B9#)
                       or else (B3 = 16#A3# and then B4 in 16#A0# .. 16#A9#)
                       or else (B3 = 16#A5# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#AF# and then B4 in 16#B0# .. 16#B9#)
                       or else (B3 = 16#B1# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#B5# and then B4 in 16#90# .. 16#99#)
                       or else (B3 = 16#B6# and then B4 in 16#A0# .. 16#A9#)
                       or else (B3 = 16#B7# and then B4 in 16#A0# .. 16#A9#)
                       or else (B3 = 16#BD# and then B4 in 16#90# .. 16#99#)));
      elsif Index + 1 <= Text'Last
        and then B1 = 16#DF#
      then
         --  NKo digits U+07C0..U+07C9.
         return B2 in 16#80# .. 16#89#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E3#
        and then B2 = 16#80#
      then
         --  Han decimal zero U+3007.
         return B3 = 16#87#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E4#
        and then B2 = 16#B8#
      then
         --  Han decimal one, seven, and three: U+4E00, U+4E03, U+4E09.
         return B3 in 16#80# | 16#83# | 16#89#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E4#
        and then B2 = 16#BA#
      then
         --  Han decimal two and five: U+4E8C, U+4E94.
         return B3 in 16#8C# | 16#94#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E4#
        and then B2 = 16#B9#
      then
         --  Han decimal nine: U+4E5D.
         return B3 = 16#9D#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E5#
        and then B2 = 16#85#
      then
         --  Han decimal eight and six: U+516B, U+516D.
         return B3 in 16#AB# | 16#AD#;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E5#
        and then B2 = 16#9B#
      then
         --  Han decimal four: U+56DB.
         return B3 = 16#9B#;
      else
         return False;
      end if;
   end Is_Bounded_Digit_At;

   function Bounded_Digit_Length
     (Text        : String;
      Digit_Index : Natural)
      return Natural
   is
      B1 : constant Natural := Character'Pos (Text (Digit_Index));
   begin
      if B1 < 16#80# then
         return 1;
      elsif B1 in 16#C2# .. 16#DF# then
         return 2;
      elsif B1 in 16#F0# .. 16#F4# then
         return 4;
      else
         return 3;
      end if;
   end Bounded_Digit_Length;

   function Has_Bounded_Digit_Before (Text : String; Index : Natural)
      return Boolean
   is
   begin
      if Index > Text'First
        and then Is_Bounded_Digit_At (Text, Index - 1)
      then
         return True;
      elsif Index >= Text'First + 2
        and then Is_Bounded_Digit_At (Text, Index - 2)
        and then Index - 2 + Bounded_Digit_Length (Text, Index - 2) = Index
      then
         return True;
      elsif Index >= Text'First + 3
        and then Is_Bounded_Digit_At (Text, Index - 3)
        and then Index - 3 + Bounded_Digit_Length (Text, Index - 3) = Index
      then
         return True;
      elsif Index >= Text'First + 4
        and then Is_Bounded_Digit_At (Text, Index - 4)
        and then Index - 4 + Bounded_Digit_Length (Text, Index - 4) = Index
      then
         return True;
      else
         return False;
      end if;
   end Has_Bounded_Digit_Before;

   function Is_Bounded_Numeric_Separator (Text : String; Index : Natural)
      return Boolean;

   function Word_Connector_Length (Text : String; Index : Natural)
      return Natural;

   function Is_Numeric_Word_Connector
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      C : constant Character := Text (Index);
      Length : constant Natural := Word_Connector_Length (Text, Index);
   begin
      return Length > 0
        and then (C = '.' or else C = ',' or else C = ':'
                  or else Is_Bounded_Numeric_Separator (Text, Index))
        and then Has_Bounded_Digit_Before (Text, Index)
        and then Index + Length <= Text'Last
        and then Is_Bounded_Digit_At (Text, Index + Length);
   end Is_Numeric_Word_Connector;

   function Is_Word_Element (Text : String; Index : Natural) return Boolean is
      C : constant Character := Text (Index);
   begin
      return Is_Alnum_ASCII (C)
        or else Is_Bounded_Digit_At (Text, Index)
        or else Is_Bounded_Combining_Mark (Text, Index)
        or else Is_Bounded_Two_Byte_Word_Element (Text, Index)
        or else Is_Bounded_Three_Byte_Word_Element (Text, Index)
        or else Is_Bounded_Four_Byte_Word_Element (Text, Index);
   end Is_Word_Element;

   function Word_Element_Length (Text : String; Index : Natural) return Natural
   is
   begin
      if Is_Bounded_Digit_At (Text, Index) then
         return Bounded_Digit_Length (Text, Index);
      elsif Is_Bounded_Two_Byte_Word_Element (Text, Index) then
         return 2;
      elsif Is_Bounded_Combining_Mark (Text, Index) then
         return Bounded_Combining_Mark_Length (Text, Index);
      elsif Is_Bounded_Three_Byte_Word_Element (Text, Index) then
         return 3;
      elsif Is_Bounded_Four_Byte_Word_Element (Text, Index) then
         return 4;
      else
         return 1;
      end if;
   end Word_Element_Length;

   function Is_Bounded_Numeric_Separator (Text : String; Index : Natural)
      return Boolean
   is
   begin
      return Index + 1 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#D9#
        and then Character'Pos (Text (Index + 1)) in 16#AB# | 16#AC#;
   end Is_Bounded_Numeric_Separator;

   function Word_Connector_Length (Text : String; Index : Natural) return Natural
   is
      C : constant Character := Text (Index);
   begin
      if C = ''' or else C = '-' or else C = '_' then
         return 1;
      elsif C = '.' or else C = ',' or else C = ':' then
         return 1;
      elsif Is_Bounded_Numeric_Separator (Text, Index) then
         return 2;
      elsif Is_Bounded_Right_Apostrophe (Text, Index) then
         return 3;
      else
         return 0;
      end if;
   end Word_Connector_Length;

   function Has_Word_Element_At (Text : String; Index : Natural) return Boolean
   is
   begin
      return Index <= Text'Last and then Is_Word_Element (Text, Index);
   end Has_Word_Element_At;

   function Is_Internal_Word_Connector
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      Length : constant Natural := Word_Connector_Length (Text, Index);
   begin
      if Length = 0 then
         return False;
      elsif Is_Numeric_Word_Connector (Text, Index) then
         return True;
      elsif Text (Index) = '.'
        or else Text (Index) = ','
        or else Text (Index) = ':'
        or else Is_Bounded_Numeric_Separator (Text, Index)
      then
         return False;
      else
         return Has_Word_Element_At (Text, Index + Length);
      end if;
   end Is_Internal_Word_Connector;

   function UTF8_Unit_Length (Text : String; Index : Natural) return Natural is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
      B4 : constant Natural :=
        (if Index + 3 <= Text'Last then Character'Pos (Text (Index + 3))
         else 0);
   begin
      if B1 < 16#80# then
         return 1;
      elsif B1 in 16#C2# .. 16#DF#
        and then Index + 1 <= Text'Last
        and then Is_UTF8_Continuation (B2)
      then
         return 2;
      elsif B1 in 16#E0# .. 16#EF#
        and then Index + 2 <= Text'Last
        and then Is_UTF8_Continuation (B2)
        and then Is_UTF8_Continuation (B3)
      then
         return 3;
      elsif B1 in 16#F0# .. 16#F4#
        and then Index + 3 <= Text'Last
        and then Is_UTF8_Continuation (B2)
        and then Is_UTF8_Continuation (B3)
        and then Is_UTF8_Continuation (B4)
      then
         return 4;
      else
         return 1;
      end if;
   end UTF8_Unit_Length;

   function Is_Bounded_Variation_Selector
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
      B4 : constant Natural :=
        (if Index + 3 <= Text'Last then Character'Pos (Text (Index + 3))
         else 0);
   begin
      return (Index + 2 <= Text'Last
              and then B1 = 16#EF#
              and then B2 = 16#B8#
              and then B3 in 16#80# .. 16#8F#)
        or else (Index + 3 <= Text'Last
                 and then B1 = 16#F3#
                 and then B2 = 16#A0#
                 and then ((B3 in 16#84# .. 16#86#
                            and then B4 in 16#80# .. 16#BF#)
                           or else
                             (B3 = 16#87#
                              and then B4 in 16#80# .. 16#AF#)));
   end Is_Bounded_Variation_Selector;

   function Bounded_Variation_Selector_Length
     (Text  : String;
      Index : Natural)
      return Natural
   is
   begin
      if Index + 3 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#F3#
        and then Character'Pos (Text (Index + 1)) = 16#A0#
        and then ((Character'Pos (Text (Index + 2)) in 16#84# .. 16#86#
                   and then Character'Pos (Text (Index + 3))
                            in 16#80# .. 16#BF#)
                  or else
                    (Character'Pos (Text (Index + 2)) = 16#87#
                     and then Character'Pos (Text (Index + 3))
                              in 16#80# .. 16#AF#))
      then
         return 4;
      elsif Is_Bounded_Variation_Selector (Text, Index) then
         return 3;
      else
         return 0;
      end if;
   end Bounded_Variation_Selector_Length;

   function Is_Bounded_Keycap_Mark
     (Text  : String;
      Index : Natural)
      return Boolean
   is
   begin
      --  Combining enclosing keycap U+20E3 used by emoji keycap sequences.
      return Index + 2 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#E2#
        and then Character'Pos (Text (Index + 1)) = 16#83#
        and then Character'Pos (Text (Index + 2)) = 16#A3#;
   end Is_Bounded_Keycap_Mark;

   function Is_Bounded_Emoji_Modifier
     (Text  : String;
      Index : Natural)
      return Boolean
   is
   begin
      --  Fitzpatrick skin-tone modifiers U+1F3FB..U+1F3FF.
      return Index + 3 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#F0#
        and then Character'Pos (Text (Index + 1)) = 16#9F#
        and then Character'Pos (Text (Index + 2)) = 16#8F#
        and then Character'Pos (Text (Index + 3)) in 16#BB# .. 16#BF#;
   end Is_Bounded_Emoji_Modifier;

   function Is_Bounded_Emoji_Tag
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B3 : Natural;
      B4 : Natural;
   begin
      --  Tag characters U+E0020..U+E007F used in bounded emoji tags.
      if Index + 3 > Text'Last
        or else Character'Pos (Text (Index)) /= 16#F3#
        or else Character'Pos (Text (Index + 1)) /= 16#A0#
      then
         return False;
      end if;

      B3 := Character'Pos (Text (Index + 2));
      B4 := Character'Pos (Text (Index + 3));
      return (B3 = 16#80# and then B4 in 16#A0# .. 16#BF#)
        or else (B3 = 16#81# and then B4 in 16#80# .. 16#BF#);
   end Is_Bounded_Emoji_Tag;

   function Is_Bounded_Regional_Indicator
     (Text  : String;
      Index : Natural)
      return Boolean
   is
   begin
      --  Regional indicator symbols U+1F1E6..U+1F1FF used for flag pairs.
      return Index + 3 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#F0#
        and then Character'Pos (Text (Index + 1)) = 16#9F#
        and then Character'Pos (Text (Index + 2)) = 16#87#
        and then Character'Pos (Text (Index + 3)) in 16#A6# .. 16#BF#;
   end Is_Bounded_Regional_Indicator;

   function Is_Zero_Width_Joiner (Text : String; Index : Natural)
      return Boolean
   is
   begin
      return Index + 2 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#E2#
        and then Character'Pos (Text (Index + 1)) = 16#80#
        and then Character'Pos (Text (Index + 2)) = 16#8D#;
   end Is_Zero_Width_Joiner;

   function Is_Bounded_Hangul_Jamo_L (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then ((B2 = 16#84# and then B3 in 16#80# .. 16#BF#)
                  or else (B2 = 16#85# and then B3 in 16#80# .. 16#9F#));
   end Is_Bounded_Hangul_Jamo_L;

   function Is_Bounded_Hangul_Jamo_V (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then ((B2 = 16#85# and then B3 in 16#A0# .. 16#BF#)
                  or else (B2 = 16#86# and then B3 in 16#80# .. 16#A7#));
   end Is_Bounded_Hangul_Jamo_V;

   function Is_Bounded_Hangul_Jamo_T (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return Index + 2 <= Text'Last
        and then B1 = 16#E1#
        and then ((B2 = 16#86# and then B3 in 16#A8# .. 16#BF#)
                  or else B2 = 16#87#);
   end Is_Bounded_Hangul_Jamo_T;

   procedure Consume_Bounded_Hangul_Jamo
     (Text : String;
      Pos  : in out Natural;
      Last : in out Natural)
   is
   begin
      if not Is_Bounded_Hangul_Jamo_L (Text, Last - 2) then
         return;
      end if;

      while Pos <= Text'Last and then Is_Bounded_Hangul_Jamo_L (Text, Pos) loop
         Last := Pos + 2;
         Pos := Last + 1;
      end loop;

      if Pos <= Text'Last and then Is_Bounded_Hangul_Jamo_V (Text, Pos) then
         while Pos <= Text'Last
           and then Is_Bounded_Hangul_Jamo_V (Text, Pos)
         loop
            Last := Pos + 2;
            Pos := Last + 1;
         end loop;

         while Pos <= Text'Last
           and then Is_Bounded_Hangul_Jamo_T (Text, Pos)
         loop
            Last := Pos + 2;
            Pos := Last + 1;
         end loop;
      end if;
   end Consume_Bounded_Hangul_Jamo;

   function Is_Bounded_Grapheme_Extend
     (Text  : String;
      Index : Natural)
      return Boolean
   is
   begin
      return Is_Bounded_Combining_Mark (Text, Index)
        or else Is_Bounded_Indic_Thai_Grapheme_Extend (Text, Index)
        or else Is_Bounded_Spacing_Mark (Text, Index)
        or else Is_Bounded_Variation_Selector (Text, Index)
        or else Is_Bounded_Keycap_Mark (Text, Index)
        or else Is_Bounded_Emoji_Modifier (Text, Index)
        or else Is_Bounded_Emoji_Tag (Text, Index);
   end Is_Bounded_Grapheme_Extend;

   function Grapheme_Extend_Length
     (Text  : String;
      Index : Natural)
      return Natural
   is
   begin
      if Is_Bounded_Combining_Mark (Text, Index) then
         return Bounded_Combining_Mark_Length (Text, Index);
      elsif Is_Bounded_Indic_Thai_Grapheme_Extend (Text, Index) then
         return 3;
      elsif Is_Bounded_Spacing_Mark (Text, Index) then
         return 3;
      elsif Is_Bounded_Variation_Selector (Text, Index) then
         return Bounded_Variation_Selector_Length (Text, Index);
      elsif Is_Bounded_Keycap_Mark (Text, Index) then
         return 3;
      elsif Is_Bounded_Emoji_Modifier (Text, Index) then
         return 4;
      elsif Is_Bounded_Emoji_Tag (Text, Index) then
         return 4;
      else
         return 0;
      end if;
   end Grapheme_Extend_Length;

   function Grapheme_Cluster_Last
     (Text  : String;
      First : Natural)
      return Natural
   is
      Pos  : Natural := First;
      Last : Natural;
   begin
      if First > Text'Last then
         return First - 1;
      elsif Text (First) = ASCII.CR
        and then First < Text'Last
        and then Text (First + 1) = ASCII.LF
      then
         return First + 1;
      elsif Character'Pos (Text (First)) < 32
        or else Character'Pos (Text (First)) = 127
      then
         return First;
      elsif First + 1 <= Text'Last
        and then Character'Pos (Text (First)) = 16#C2#
        and then Character'Pos (Text (First + 1)) in 16#80# .. 16#9F#
      then
         return First + 1;
      end if;

      Last := First + UTF8_Unit_Length (Text, First) - 1;
      Pos := Last + 1;
      while Is_Bounded_Grapheme_Prepend (Text, First)
        and then Pos <= Text'Last
        and then Is_Bounded_Grapheme_Prepend (Text, Pos)
      loop
         Last := Pos + Grapheme_Prepend_Length (Text, Pos) - 1;
         Pos := Last + 1;
      end loop;
      if Is_Bounded_Grapheme_Prepend (Text, First)
        and then Pos <= Text'Last
      then
         Last := Pos + UTF8_Unit_Length (Text, Pos) - 1;
         Pos := Last + 1;
      end if;

      if Is_Bounded_Regional_Indicator (Text, First)
        and then Is_Bounded_Regional_Indicator (Text, Pos)
      then
         Last := Pos + 3;
         Pos := Last + 1;
      elsif Last >= First + 2 then
         Consume_Bounded_Hangul_Jamo (Text, Pos, Last);
      end if;

      while Pos <= Text'Last loop
         if Is_Bounded_Grapheme_Extend (Text, Pos) then
            Last := Pos + Grapheme_Extend_Length (Text, Pos) - 1;
            Pos := Last + 1;
         elsif Is_Zero_Width_Joiner (Text, Pos)
           and then Pos + 3 <= Text'Last
         then
            Last := Pos + 2;
            Pos := Last + 1;
            Last := Pos + UTF8_Unit_Length (Text, Pos) - 1;
            Pos := Last + 1;
            while Pos <= Text'Last
              and then Is_Bounded_Grapheme_Extend (Text, Pos)
            loop
               Last := Pos + Grapheme_Extend_Length (Text, Pos) - 1;
               Pos := Last + 1;
            end loop;
         else
            exit;
         end if;
      end loop;

      return Last;
   end Grapheme_Cluster_Last;

   function Grapheme_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   is
      pragma Unreferenced (Locale);
      Count : Natural := 0;
      Pos   : Natural := (if Text'Length = 0 then Text'Last + 1
                          else Text'First);
      Last  : Natural;
   begin
      while Pos <= Text'Last loop
         Count := Count + 1;
         Last := Grapheme_Cluster_Last (Text, Pos);
         Pos := Last + 1;
      end loop;

      return Count;
   end Grapheme_Count;

   function Grapheme_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Count : Natural := 0;
      Pos   : Natural := (if Text'Length = 0 then Text'Last + 1
                          else Text'First);
      Last  : Natural;
   begin
      if Index = 0 then
         return "";
      end if;

      while Pos <= Text'Last loop
         Count := Count + 1;
         Last := Grapheme_Cluster_Last (Text, Pos);
         if Count = Index then
            return Text (Pos .. Last);
         end if;
         Pos := Last + 1;
      end loop;

      return "";
   end Grapheme_At;

   function Line_Break_Length (Text : String; Index : Natural) return Natural is
   begin
      if Text (Index) = ASCII.CR then
         if Index < Text'Last and then Text (Index + 1) = ASCII.LF then
            return 2;
         else
            return 1;
         end if;
      elsif Text (Index) = ASCII.LF then
         return 1;
      elsif Text (Index) = Character'Val (11) then
         return 1;
      elsif Text (Index) = ASCII.FF then
         return 1;
      elsif Index + 1 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#C2#
        and then Character'Pos (Text (Index + 1)) = 16#85#
      then
         return 2;
      elsif Index + 2 <= Text'Last
        and then Character'Pos (Text (Index)) = 16#E2#
        and then Character'Pos (Text (Index + 1)) = 16#80#
        and then Character'Pos (Text (Index + 2)) in 16#A8# | 16#A9#
      then
         return 3;
      else
         return 0;
      end if;
   end Line_Break_Length;

   procedure Next_Line
     (Text       : String;
      Start      : in out Natural;
      First      : out Natural;
      Last       : out Natural;
      Has_Result : out Boolean)
   is
      Pos          : Natural := Start;
      Break_Length : Natural;
   begin
      Has_Result := False;
      First := 0;
      Last := 0;

      if Pos > Text'Last then
         return;
      end if;

      First := Pos;

      while Pos <= Text'Last loop
         Break_Length := Line_Break_Length (Text, Pos);
         if Break_Length > 0 then
            Last := Pos + Break_Length - 1;
            Start := Last + 1;
            Has_Result := True;
            return;
         else
            Last := Pos + UTF8_Unit_Length (Text, Pos) - 1;
            Pos := Last + 1;
         end if;
      end loop;

      Start := Pos;
      Has_Result := Last >= First;
   end Next_Line;

   function Line_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   is
      pragma Unreferenced (Locale);
      Pos    : Natural := (if Text'Length = 0 then Text'Last + 1
                           else Text'First);
      First  : Natural;
      Last   : Natural;
      Found  : Boolean;
      Count  : Natural := 0;
   begin
      loop
         Next_Line (Text, Pos, First, Last, Found);
         exit when not Found;
         Count := Count + 1;
      end loop;

      return Count;
   end Line_Count;

   function Line_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Pos    : Natural := (if Text'Length = 0 then Text'Last + 1
                           else Text'First);
      First  : Natural;
      Last   : Natural;
      Found  : Boolean;
      Count  : Natural := 0;
   begin
      if Index = 0 then
         return "";
      end if;

      loop
         Next_Line (Text, Pos, First, Last, Found);
         exit when not Found;
         Count := Count + 1;
         if Count = Index then
            return Text (First .. Last);
         end if;
      end loop;

      return "";
   end Line_At;

   function Sentence_Whitespace_Length
     (Text  : String;
      Index : Natural)
      return Natural
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      if Text (Index) = ' '
        or else Text (Index) = ASCII.HT
        or else Text (Index) = ASCII.LF
        or else Text (Index) = ASCII.CR
        or else Text (Index) = Character'Val (11)
        or else Text (Index) = ASCII.FF
      then
         return 1;
      elsif Index + 1 <= Text'Last
        and then B1 = 16#C2#
        and then B2 in 16#85# | 16#A0#
      then
         --  Unicode NEL and non-breaking space.
         return 2;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E2#
        and then B2 = 16#80#
        and then B3 in 16#A8# | 16#A9#
      then
         --  Unicode line and paragraph separators.
         return 3;
      elsif Index + 2 <= Text'Last
        and then B1 = 16#E3#
        and then B2 = 16#80#
        and then B3 = 16#80#
      then
         --  Ideographic space.
         return 3;
      else
         return 0;
      end if;
   end Sentence_Whitespace_Length;

   function Is_Sentence_Terminator
     (Text  : String;
      Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return (Text (Index) = '.'
              and then not
                (Has_Bounded_Digit_Before (Text, Index)
                 and then Index < Text'Last
                 and then Is_Bounded_Digit_At (Text, Index + 1)))
        or else Text (Index) = '!'
        or else Text (Index) = '?'
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E2#
                 and then B2 = 16#80#
                 and then B3 = 16#A6#)
        or else (Index + 1 <= Text'Last
                 and then B1 = 16#D8#
                 and then B2 = 16#9F#)
        or else (Index + 1 <= Text'Last
                 and then B1 = 16#CD#
                 and then B2 = 16#BE#)
        or else (Index + 1 <= Text'Last
                 and then B1 = 16#D6#
                 and then B2 = 16#89#)
        or else (Index + 1 <= Text'Last
                 and then B1 = 16#D7#
                 and then B2 = 16#83#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E1#
                 and then B2 = 16#83#
                 and then B3 = 16#BB#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E0#
                 and then B2 = 16#A5#
                 and then B3 = 16#A4#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E1#
                 and then B2 = 16#81#
                 and then B3 in 16#8A# | 16#8B#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E1#
                 and then B2 = 16#8D#
                 and then B3 in 16#A2# | 16#A7#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E3#
                 and then B2 = 16#80#
                 and then B3 = 16#82#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#EF#
                 and then B2 = 16#BC#
                 and then B3 in 16#81# | 16#9F#);
   end Is_Sentence_Terminator;

   function Is_Bounded_Closing_Quote (Text : String; Index : Natural)
      return Boolean
   is
      B1 : constant Natural := Character'Pos (Text (Index));
      B2 : constant Natural :=
        (if Index + 1 <= Text'Last then Character'Pos (Text (Index + 1))
         else 0);
      B3 : constant Natural :=
        (if Index + 2 <= Text'Last then Character'Pos (Text (Index + 2))
         else 0);
   begin
      return (Index + 2 <= Text'Last
              and then B1 = 16#E2#
              and then B2 = 16#80#
              and then B3 in 16#99# | 16#9D# | 16#BA#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#E3#
                 and then B2 = 16#80#
                 and then B3 in 16#8D# | 16#8F# | 16#91# | 16#95#
                                | 16#97# | 16#99# | 16#9B#)
        or else (Index + 2 <= Text'Last
                 and then B1 = 16#EF#
                 and then ((B2 = 16#BC# and then B3 in 16#89# | 16#BD#)
                           or else (B2 = 16#BD# and then B3 = 16#9D#)));
   end Is_Bounded_Closing_Quote;

   function Sentence_Close_Length (Text : String; Index : Natural)
      return Natural
   is
   begin
      if Text (Index) = '"'
        or else Text (Index) = '''
        or else Text (Index) = ')'
        or else Text (Index) = ']'
        or else Text (Index) = '}'
      then
         return 1;
      elsif Is_Bounded_Closing_Quote (Text, Index) then
         return 3;
      else
         return 0;
      end if;
   end Sentence_Close_Length;

   procedure Next_Sentence
     (Text       : String;
      Start      : in out Natural;
      First      : out Natural;
      Last       : out Natural;
      Has_Result : out Boolean)
   is
      Pos : Natural := Start;
      Close_Length : Natural;
   begin
      Has_Result := False;
      First := 0;
      Last := 0;

      while Pos <= Text'Last loop
         declare
            Whitespace_Length : constant Natural :=
              Sentence_Whitespace_Length (Text, Pos);
         begin
            exit when Whitespace_Length = 0;
            Pos := Pos + Whitespace_Length;
         end;
      end loop;

      if Pos > Text'Last then
         Start := Pos;
         return;
      end if;

      First := Pos;

      while Pos <= Text'Last loop
         if Is_Sentence_Terminator (Text, Pos) then
            Last := Pos + UTF8_Unit_Length (Text, Pos) - 1;
            Pos := Last + 1;

            while Pos <= Text'Last loop
               Close_Length := Sentence_Close_Length (Text, Pos);
               exit when Close_Length = 0;
               Last := Pos + Close_Length - 1;
               Pos := Last + 1;
            end loop;

            Start := Pos;
            Has_Result := True;
            return;
         else
            Last := Pos + UTF8_Unit_Length (Text, Pos) - 1;
            Pos := Last + 1;
         end if;
      end loop;

      Start := Pos;
      Has_Result := Last >= First;
   end Next_Sentence;

   function Sentence_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   is
      pragma Unreferenced (Locale);
      Pos    : Natural := (if Text'Length = 0 then Text'Last + 1
                           else Text'First);
      First  : Natural;
      Last   : Natural;
      Found  : Boolean;
      Count  : Natural := 0;
   begin
      loop
         Next_Sentence (Text, Pos, First, Last, Found);
         exit when not Found;
         Count := Count + 1;
      end loop;

      return Count;
   end Sentence_Count;

   function Sentence_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Pos    : Natural := (if Text'Length = 0 then Text'Last + 1
                           else Text'First);
      First  : Natural;
      Last   : Natural;
      Found  : Boolean;
      Count  : Natural := 0;
   begin
      if Index = 0 then
         return "";
      end if;

      loop
         Next_Sentence (Text, Pos, First, Last, Found);
         exit when not Found;
         Count := Count + 1;
         if Count = Index then
            return Text (First .. Last);
         end if;
      end loop;

      return "";
   end Sentence_At;

   function Word_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   is
      pragma Unreferenced (Locale);
      Count   : Natural := 0;
      In_Word : Boolean := False;
      Pos     : Natural := (if Text'Length = 0 then Text'Last + 1
                            else Text'First);
   begin
      while Pos <= Text'Last loop
         if Is_Word_Element (Text, Pos) then
            if not In_Word then
               Count := Count + 1;
               In_Word := True;
            end if;
            Pos := Pos + Word_Element_Length (Text, Pos);
         elsif In_Word and then Is_Internal_Word_Connector (Text, Pos) then
            Pos := Pos + Word_Connector_Length (Text, Pos);
         else
            In_Word := False;
            Pos := Pos + 1;
         end if;
      end loop;

      return Count;
   end Word_Count;

   function Word_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   is
      pragma Unreferenced (Locale);
      Count      : Natural := 0;
      Word_First : Natural := 0;
      Word_Last  : Natural := 0;
      Pos        : Natural := (if Text'Length = 0 then Text'Last + 1
                               else Text'First);
   begin
      if Index = 0 then
         return "";
      end if;

      while Pos <= Text'Last loop
         if Is_Word_Element (Text, Pos) then
            Count := Count + 1;
            Word_First := Pos;

            while Pos <= Text'Last and then Is_Word_Element (Text, Pos) loop
               Word_Last := Pos + Word_Element_Length (Text, Pos) - 1;
               Pos := Pos + Word_Element_Length (Text, Pos);

               while Pos <= Text'Last
                 and then Is_Internal_Word_Connector (Text, Pos)
               loop
                  Word_Last := Pos + Word_Connector_Length (Text, Pos) - 1;
                  Pos := Pos + Word_Connector_Length (Text, Pos);
                  exit when Pos > Text'Last or else not Is_Word_Element (Text, Pos);
                  Word_Last := Pos + Word_Element_Length (Text, Pos) - 1;
                  Pos := Pos + Word_Element_Length (Text, Pos);
               end loop;
            end loop;

            if Count = Index then
               return Text (Word_First .. Word_Last);
            end if;
         else
            Pos := Pos + 1;
         end if;
      end loop;

      return "";
   end Word_At;

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
