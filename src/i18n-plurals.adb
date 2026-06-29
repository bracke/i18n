package body I18N.Plurals is

   --  Supported plural-rule families. Languages that share an integer rule set
   --  are grouped onto one family value.
   type Language is
     (Lang_One_Is_1,       --  one iff n = 1 (en, de, nl, es, it)
      Lang_One_Is_0_Or_1,  --  one iff n in {0, 1} (fr, pt)
      Lang_Ru,             --  East Slavic one/few/many (ru)
      Lang_Pl,             --  Polish one/few/many
      Lang_Cs,             --  Czech one/few/other
      Lang_Ar,             --  Arabic zero/one/two/few/many/other
      Lang_Fr_Ordinal,     --  French ordinal split (one iff n = 1)
      Lang_It_Ordinal,     --  Italian ordinal "many" set
      Lang_Other_Only);    --  CJK and the root rule: always other

   --  Lowercase an ASCII letter.
   function Lower (C : Character) return Character is
   begin
      if C in 'A' .. 'Z' then
         return Character'Val (Character'Pos (C) + 32);
      end if;
      return C;
   end Lower;

   --  Two-letter language subtag, lowercased, or "" when not a 2-letter subtag.
   function Subtag_Of (Locale : I18N.Locales.Locale_Id) return String is
      Last : Natural := Locale'Last;
   begin
      for Index in Locale'Range loop
         if Locale (Index) = '-' then
            Last := Index - 1;
            exit;
         end if;
      end loop;

      declare
         Raw : constant String := Locale (Locale'First .. Last);
      begin
         if Raw'Length /= 2 then
            return "";
         end if;
         return [Lower (Raw (Raw'First)), Lower (Raw (Raw'First + 1))];
      end;
   end Subtag_Of;

   --  Resolve the language subtag to its cardinal plural-rule family.
   function Cardinal_Family
     (Locale : I18N.Locales.Locale_Id)
      return Language
   is
      S : constant String := Subtag_Of (Locale);
   begin
      if S = "en" or else S = "de" or else S = "nl"
        or else S = "da" or else S = "es" or else S = "it"
      then
         return Lang_One_Is_1;
      elsif S = "fr" or else S = "pt" then
         return Lang_One_Is_0_Or_1;
      elsif S = "ru" then
         return Lang_Ru;
      elsif S = "pl" then
         return Lang_Pl;
      elsif S = "cs" then
         return Lang_Cs;
      elsif S = "ar" then
         return Lang_Ar;
      else
         --  ja, zh, ko, and every unsupported locale use the root rule.
         return Lang_Other_Only;
      end if;
   end Cardinal_Family;

   --  Absolute value as a non-negative magnitude. Long_Long_Integer'First has no
   --  positive counterpart; it is mapped to a large non-special magnitude so the
   --  classification stays total and deterministic.
   function Magnitude (Value : Long_Long_Integer) return Long_Long_Integer is
   begin
      if Value = Long_Long_Integer'First then
         return Long_Long_Integer'Last;
      elsif Value < 0 then
         return -Value;
      else
         return Value;
      end if;
   end Magnitude;

   function Cardinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   is
      N      : constant Long_Long_Integer := Magnitude (Value);
      Mod10  : constant Long_Long_Integer := N mod 10;
      Mod100 : constant Long_Long_Integer := N mod 100;
   begin
      case Cardinal_Family (Locale) is
         when Lang_One_Is_1 =>
            --  en, de, nl, da, es, it: i = 1 and v = 0 -> one
            return (if N = 1 then One else Other);

         when Lang_One_Is_0_Or_1 =>
            --  fr, pt: i in {0, 1} -> one (compact "many" not modelled)
            return (if N = 0 or else N = 1 then One else Other);

         when Lang_Ru =>
            --  Russian (integers): one / few / many partition all values.
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;
            elsif Mod10 in 2 .. 4 and then Mod100 not in 12 .. 14 then
               return Few;
            else
               return Many;
            end if;

         when Lang_Pl =>
            --  Polish (integers): one (=1) / few / many.
            if N = 1 then
               return One;
            elsif Mod10 in 2 .. 4 and then Mod100 not in 12 .. 14 then
               return Few;
            else
               return Many;
            end if;

         when Lang_Cs =>
            --  Czech (integers): one (=1) / few (2..4) / other.
            if N = 1 then
               return One;
            elsif N in 2 .. 4 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Ar =>
            --  Arabic exercises every category.
            if N = 0 then
               return Zero;
            elsif N = 1 then
               return One;
            elsif N = 2 then
               return Two;
            elsif Mod100 in 3 .. 10 then
               return Few;
            elsif Mod100 in 11 .. 99 then
               return Many;
            else
               return Other;
            end if;

         when Lang_Fr_Ordinal | Lang_It_Ordinal | Lang_Other_Only =>
            return Other;
      end case;
   end Cardinal;

   function Cardinal
     (Locale          : I18N.Locales.Locale_Id;
      Integer_Part    : Long_Long_Integer;
      Fraction_Digits : Natural;
      Fraction_Value  : Long_Long_Integer)
      return Plural_Category
   is
      pragma Unreferenced (Fraction_Value);
      I : constant Long_Long_Integer := Magnitude (Integer_Part);
   begin
      --  No visible fraction: identical to the integer classification.
      if Fraction_Digits = 0 then
         return Cardinal (Locale, I);
      end if;

      --  A visible fraction is present (operand v > 0).
      case Cardinal_Family (Locale) is
         when Lang_One_Is_1 =>
            --  en/de/nl/da/es/it: "one" requires v = 0, so a fraction is other.
            return Other;

         when Lang_One_Is_0_Or_1 =>
            --  fr/pt: one iff i in {0, 1}, regardless of the fraction.
            return (if I = 0 or else I = 1 then One else Other);

         when Lang_Cs =>
            --  Czech: a visible fraction (v /= 0) is "many".
            return Many;

         when Lang_Ru | Lang_Pl | Lang_Ar
            | Lang_Fr_Ordinal | Lang_It_Ordinal | Lang_Other_Only =>
            --  Fractions fall to "other" under the modelled rules.
            return Other;
      end case;
   end Cardinal;

   function Ordinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   is
      N : constant Long_Long_Integer := Magnitude (Value);
      S : constant String := Subtag_Of (Locale);
   begin
      if S = "en" then
         declare
            Mod10  : constant Long_Long_Integer := N mod 10;
            Mod100 : constant Long_Long_Integer := N mod 100;
         begin
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;     --  1st, 21st, 31st ...
            elsif Mod10 = 2 and then Mod100 /= 12 then
               return Two;     --  2nd, 22nd, 32nd ...
            elsif Mod10 = 3 and then Mod100 /= 13 then
               return Few;     --  3rd, 23rd, 33rd ...
            else
               return Other;   --  4th, 11th, 12th, 13th ...
            end if;
         end;

      elsif S = "fr" then
         --  French ordinal: 1 -> one ("1er"); everything else -> other.
         return (if N = 1 then One else Other);

      elsif S = "it" then
         --  Italian ordinal "many" set; everything else -> other.
         if N = 8 or else N = 11 or else N = 80 or else N = 800 then
            return Many;
         else
            return Other;
         end if;

      else
         --  de, nl, es, pt, ru, pl, cs, ar, CJK, and the root rule treat all
         --  integer ordinals as "other".
         return Other;
      end if;
   end Ordinal;

end I18N.Plurals;
