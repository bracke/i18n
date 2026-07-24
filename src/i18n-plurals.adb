with Ada.Characters.Handling;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with I18N.CLDR_Data;
with I18N.Locale_Data;
with I18N.Runtime_Data;

package body I18N.Plurals is

   --  Supported plural-rule families. Languages that share an integer rule set
   --  are grouped onto one family value.
   type Language is
     (Lang_N_Is_1,         --  one iff numeric n = 1, including 1.0
      Lang_One_Is_1,       --  one iff i = 1 and v = 0 (en, de, nl...)
      Lang_One_Is_0_Or_1,  --  one iff n in {0, 1}
      Lang_I_0_Or_N_1,     --  one iff i = 0 or n = 1
      Lang_N_One_Two,      --  one iff n = 1, two iff n = 2
      Lang_N_1_Compact,    --  n = 1 plus compact-million many
      Lang_I_01_Compact,   --  i in {0, 1} plus compact-million many
      Lang_I_1_V0_Compact, --  i = 1 and v = 0 plus compact-million many
      Lang_Ru,             --  East Slavic one/few/many (ru)
      Lang_Pl,             --  Polish one/few/many
      Lang_Cs,             --  Czech one/few/other
      Lang_Ar,             --  Arabic zero/one/two/few/many/other
      Lang_Ro,             --  Romanian one/few/other
      Lang_Lt,             --  Lithuanian one/few/many/other
      Lang_Sl,             --  Slovenian one/two/few/other
      Lang_Sr,             --  Serbian/Croatian one/few/other
      Lang_Cy,             --  Welsh zero/one/two/few/many/other
      Lang_Zero_One,       --  zero iff n = 0, one iff n = 1
      Lang_Ceb,
      Lang_Ff,
      Lang_Dsb,
      Lang_Lv,
      Lang_Be,
      Lang_Br,
      Lang_Da,
      Lang_Ga,
      Lang_Gd,
      Lang_Gv,
      Lang_He,
      Lang_Is,
      Lang_Kw,
      Lang_Lag,
      Lang_Mk,
      Lang_Mt,
      Lang_Shi,
      Lang_Si,
      Lang_Tzm,
      Lang_N_One_Ordinal,  --  ordinal one iff n = 1
      Lang_It_Ordinal,     --  Italian ordinal "many" set
      Lang_Indic_Ordinal,  --  Assamese/Bengali ordinal categories
      Lang_Hi_Ordinal,     --  Gujarati/Hindi ordinal categories
      Lang_Other_Only);    --  CJK and the root rule: always other

   --  Resolve the language subtag to its cardinal plural-rule family.
   function Cardinal_Family
     (Locale : I18N.Locales.Locale_Id)
      return Language
   is
      Found  : Boolean;
      Family : constant String :=
        I18N.Runtime_Data.Plural_Rule_Family ("cardinal", Locale, Found);
      Store_Found : Boolean := False;
      Store_Family : constant String :=
        (if Found then ""
         else I18N.Locale_Data.Lookup ("cardinal_family", Locale, "", Store_Found));
      Effective_Family : constant String :=
        (if Found then Family
         elsif Store_Found then Store_Family
         else I18N.CLDR_Data.Cardinal_Rule_Family (Locale));
   begin
      if Effective_Family = "n-is-1" then
         return Lang_N_Is_1;
      elsif Effective_Family = "one-is-1" then
         return Lang_One_Is_1;
      elsif Effective_Family = "one-is-0-or-1" then
         return Lang_One_Is_0_Or_1;
      elsif Effective_Family = "i-0-or-n-1" then
         return Lang_I_0_Or_N_1;
      elsif Effective_Family = "n-one-two" then
         return Lang_N_One_Two;
      elsif Effective_Family = "n-is-1-compact-many" then
         return Lang_N_1_Compact;
      elsif Effective_Family = "i-0-1-compact-many"
        or else Effective_Family = "i-0-to-1-compact-many"
      then
         return Lang_I_01_Compact;
      elsif Effective_Family = "i-1-v0-compact-many" then
         return Lang_I_1_V0_Compact;
      elsif Effective_Family = "ru" then
         return Lang_Ru;
      elsif Effective_Family = "pl" then
         return Lang_Pl;
      elsif Effective_Family = "cs" then
         return Lang_Cs;
      elsif Effective_Family = "ar" then
         return Lang_Ar;
      elsif Effective_Family = "ro" then
         return Lang_Ro;
      elsif Effective_Family = "lt" then
         return Lang_Lt;
      elsif Effective_Family = "sl" then
         return Lang_Sl;
      elsif Effective_Family = "sr" then
         return Lang_Sr;
      elsif Effective_Family = "cy" then
         return Lang_Cy;
      elsif Effective_Family = "zero-one" then
         return Lang_Zero_One;
      elsif Effective_Family = "ceb" then
         return Lang_Ceb;
      elsif Effective_Family = "ff" then
         return Lang_Ff;
      elsif Effective_Family = "dsb" then
         return Lang_Dsb;
      elsif Effective_Family = "lv" then
         return Lang_Lv;
      elsif Effective_Family = "be" then
         return Lang_Be;
      elsif Effective_Family = "br" then
         return Lang_Br;
      elsif Effective_Family = "da" then
         return Lang_Da;
      elsif Effective_Family = "ga" then
         return Lang_Ga;
      elsif Effective_Family = "gd" then
         return Lang_Gd;
      elsif Effective_Family = "gv" then
         return Lang_Gv;
      elsif Effective_Family = "he" then
         return Lang_He;
      elsif Effective_Family = "is" then
         return Lang_Is;
      elsif Effective_Family = "kw" then
         return Lang_Kw;
      elsif Effective_Family = "lag" then
         return Lang_Lag;
      elsif Effective_Family = "mk" then
         return Lang_Mk;
      elsif Effective_Family = "mt" then
         return Lang_Mt;
      elsif Effective_Family = "shi" then
         return Lang_Shi;
      elsif Effective_Family = "si" then
         return Lang_Si;
      elsif Effective_Family = "tzm" then
         return Lang_Tzm;
      else
         return Lang_Other_Only;
      end if;
   end Cardinal_Family;

   function Compact_Fraction (Value : Long_Long_Integer) return Long_Long_Integer is
      Result : Long_Long_Integer :=
        (if Value = Long_Long_Integer'First then Long_Long_Integer'Last
         elsif Value < 0 then -Value
         else Value);
   begin
      while Result /= 0 and then Result mod 10 = 0 loop
         Result := Result / 10;
      end loop;
      return Result;
   end Compact_Fraction;

   function In_Range
     (Value : Long_Long_Integer;
      Low   : Long_Long_Integer;
      High  : Long_Long_Integer)
      return Boolean is
   begin
      return Value >= Low and then Value <= High;
   end In_Range;

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

   function Category_From_Text (Text : String) return Plural_Category is
   begin
      if Text = "zero" then
         return Zero;
      elsif Text = "one" then
         return One;
      elsif Text = "two" then
         return Two;
      elsif Text = "few" then
         return Few;
      elsif Text = "many" then
         return Many;
      else
         return Other;
      end if;
   end Category_From_Text;

   function Runtime_Override
     (Kind   : String;
      Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer;
      Found  : out Boolean)
      return Plural_Category
   is
      Text : constant String :=
        I18N.Runtime_Data.Plural_Category (Kind, Locale, Value, Found);
   begin
      if Found then
         return Category_From_Text (Text);
      else
         return Other;
      end if;
   end Runtime_Override;

   function Trimmed (Text : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Trimmed;

   function Is_Integer_Text (Text : String) return Boolean is
      Dummy : Long_Long_Integer;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Dummy := Long_Long_Integer'Value (Text);
      return True;
   exception
      when Constraint_Error =>
         return False;
   end Is_Integer_Text;

   function Relation_Value
     (Name            : Character;
      N               : Long_Long_Integer;
      I               : Long_Long_Integer;
      V               : Natural;
      W               : Natural;
      F               : Long_Long_Integer;
      T               : Long_Long_Integer)
      return Long_Long_Integer
   is
   begin
      case Name is
         when 'n' => return N;
         when 'i' => return I;
         when 'v' => return Long_Long_Integer (V);
         when 'w' => return Long_Long_Integer (W);
         when 'f' => return F;
         when 't' => return T;
         when 'c' => return 0;
         when 'e' => return 0;
         when others => return 0;
      end case;
   end Relation_Value;

   procedure Trim_Fraction
     (V : Natural;
      F : Long_Long_Integer;
      W : out Natural;
      T : out Long_Long_Integer)
   is
   begin
      W := V;
      T := F;

      while W > 0 and then T mod 10 = 0 loop
         T := T / 10;
         W := W - 1;
      end loop;
   end Trim_Fraction;

   function Matches_Value_Item
     (Value : Long_Long_Integer;
      Item  : String)
      return Boolean
   is
      T : constant String := Trimmed (Item);
      Range_Sep : constant Natural :=
        Ada.Strings.Fixed.Index (T, "..");
   begin
      if Range_Sep = 0 then
         return Is_Integer_Text (T) and then Value = Long_Long_Integer'Value (T);
      else
         declare
            Low_Text  : constant String := Trimmed (T (T'First .. Range_Sep - 1));
            High_Text : constant String := Trimmed (T (Range_Sep + 2 .. T'Last));
         begin
            return Is_Integer_Text (Low_Text)
              and then Is_Integer_Text (High_Text)
              and then Value >= Long_Long_Integer'Value (Low_Text)
              and then Value <= Long_Long_Integer'Value (High_Text);
         end;
      end if;
   end Matches_Value_Item;

   function Matches_Value_List
     (Value : Long_Long_Integer;
      List  : String)
      return Boolean
   is
      Start : Positive := List'First;
   begin
      while Start <= List'Last loop
         declare
            Stop : Natural := List'Last + 1;
         begin
            for Index in Start .. List'Last loop
               if List (Index) = ',' then
                  Stop := Index;
                  exit;
               end if;
            end loop;

            if Stop > Start
              and then Matches_Value_Item (Value, List (Start .. Stop - 1))
            then
               return True;
            end if;

            Start := Stop + 1;
         end;
      end loop;

      return False;
   end Matches_Value_List;

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Without_Samples (Text : String) return String is
      Sample : constant Natural := Ada.Strings.Fixed.Index (Text, "@");
   begin
      if Sample = 0 then
         return Text;
      elsif Sample = Text'First then
         return "";
      else
         return Text (Text'First .. Sample - 1);
      end if;
   end Without_Samples;

   function Evaluate_Relation
     (Text            : String;
      N               : Long_Long_Integer;
      I               : Long_Long_Integer;
      V               : Natural;
      W               : Natural;
      F               : Long_Long_Integer;
      T_Operand       : Long_Long_Integer)
      return Boolean
   is
      T : constant String :=
        Trimmed (Ada.Characters.Handling.To_Lower (Text));
      Cursor : Natural := T'First;
      Value  : Long_Long_Integer;
      Remainder : Unbounded_String;
      Negated : Boolean := False;
   begin
      if T'Length = 0
        or else not (T (T'First) = 'n'
                     or else T (T'First) = 'i'
                     or else T (T'First) = 'v'
                     or else T (T'First) = 'w'
                     or else T (T'First) = 'f'
                     or else T (T'First) = 't'
                     or else T (T'First) = 'c'
                     or else T (T'First) = 'e')
      then
         return False;
      end if;

      Value := Relation_Value (T (T'First), N, I, V, W, F, T_Operand);
      Cursor := T'First + 1;
      Remainder := To_Unbounded_String (Trimmed (T (Cursor .. T'Last)));

      if Starts_With (To_String (Remainder), "mod ") then
         declare
            Current : constant String := To_String (Remainder);
            Rest : constant String :=
              Trimmed (Current (Current'First + 4 .. Current'Last));
            Space : constant Natural := Ada.Strings.Fixed.Index (Rest, " ");
         begin
            if Space = 0
              or else not Is_Integer_Text (Rest (Rest'First .. Space - 1))
              or else Long_Long_Integer'Value (Rest (Rest'First .. Space - 1)) <= 0
            then
               return False;
            end if;
            Value := Value mod Long_Long_Integer'Value (Rest (Rest'First .. Space - 1));
            Remainder := To_Unbounded_String (Trimmed (Rest (Space + 1 .. Rest'Last)));
         end;
      elsif Starts_With (To_String (Remainder), "% ") then
         declare
            Current : constant String := To_String (Remainder);
            Rest : constant String :=
              Trimmed (Current (Current'First + 2 .. Current'Last));
            Space : constant Natural := Ada.Strings.Fixed.Index (Rest, " ");
         begin
            if Space = 0
              or else not Is_Integer_Text (Rest (Rest'First .. Space - 1))
              or else Long_Long_Integer'Value (Rest (Rest'First .. Space - 1)) <= 0
            then
               return False;
            end if;
            Value := Value mod Long_Long_Integer'Value (Rest (Rest'First .. Space - 1));
            Remainder := To_Unbounded_String (Trimmed (Rest (Space + 1 .. Rest'Last)));
         end;
      end if;

      declare
         Current : constant String := To_String (Remainder);
      begin
         if Starts_With (Current, "is not ") then
            Negated := True;
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 7 .. Current'Last)));
         elsif Starts_With (Current, "not in ") then
            Negated := True;
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 7 .. Current'Last)));
         elsif Starts_With (Current, "not within ") then
            Negated := True;
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 11 .. Current'Last)));
         elsif Starts_With (Current, "!=") then
            Negated := True;
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 2 .. Current'Last)));
         elsif Starts_With (Current, "is ") then
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 3 .. Current'Last)));
         elsif Starts_With (Current, "in ") then
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 3 .. Current'Last)));
         elsif Starts_With (Current, "within ") then
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 7 .. Current'Last)));
         elsif Starts_With (Current, "=") then
            Remainder :=
              To_Unbounded_String
                (Trimmed (Current (Current'First + 1 .. Current'Last)));
         else
            return False;
         end if;
      end;

      return Matches_Value_List (Value, To_String (Remainder)) xor Negated;
   end Evaluate_Relation;

   function Evaluate_And_Group
     (Text : String;
      N    : Long_Long_Integer;
      I    : Long_Long_Integer;
      V    : Natural;
      W    : Natural;
      F    : Long_Long_Integer;
      T_Operand : Long_Long_Integer)
      return Boolean
   is
      T : constant String := Trimmed (Text);
      Start : Positive := T'First;
   begin
      while Start <= T'Last loop
         declare
            Sep : constant Natural :=
              Ada.Strings.Fixed.Index (T (Start .. T'Last), " and ");
            Stop : constant Natural :=
              (if Sep = 0 then T'Last + 1 else Sep);
         begin
            if Stop <= Start
              or else not Evaluate_Relation
                (T (Start .. Stop - 1), N, I, V, W, F, T_Operand)
            then
               return False;
            end if;
            Start := Stop + 5;
         end;
      end loop;

      return True;
   end Evaluate_And_Group;

   function Evaluate_Plural_Rule
     (Rule_Text : String;
      N         : Long_Long_Integer;
      I         : Long_Long_Integer;
      V         : Natural;
      W         : Natural;
      F         : Long_Long_Integer;
      T_Operand : Long_Long_Integer)
      return Boolean
   is
      T : constant String :=
        Trimmed
          (Ada.Characters.Handling.To_Lower (Without_Samples (Rule_Text)));
      Start : Positive := T'First;
   begin
      while Start <= T'Last loop
         declare
            Sep : constant Natural :=
              Ada.Strings.Fixed.Index (T (Start .. T'Last), " or ");
            Stop : constant Natural :=
              (if Sep = 0 then T'Last + 1 else Sep);
         begin
            if Stop > Start
              and then Evaluate_And_Group
                (T (Start .. Stop - 1), N, I, V, W, F, T_Operand)
            then
               return True;
            end if;
            Start := Stop + 4;
         end;
      end loop;

      return False;
   end Evaluate_Plural_Rule;

   function Runtime_Rule_Override
     (Kind   : String;
      Locale : I18N.Locales.Locale_Id;
      N      : Long_Long_Integer;
      I      : Long_Long_Integer;
      V      : Natural;
      F      : Long_Long_Integer;
      Found  : out Boolean)
      return Plural_Category
   is
      type Category_Text_Array is array (Positive range <>) of access constant String;
      Zero_Text : aliased constant String := "zero";
      One_Text  : aliased constant String := "one";
      Two_Text  : aliased constant String := "two";
      Few_Text  : aliased constant String := "few";
      Many_Text : aliased constant String := "many";
      Category_Texts : constant Category_Text_Array :=
        [Zero_Text'Access, One_Text'Access, Two_Text'Access,
         Few_Text'Access, Many_Text'Access];
      Rule_Found : Boolean;
      W          : Natural;
      T          : Long_Long_Integer;
   begin
      Trim_Fraction (V, F, W, T);

      for Index in Category_Texts'Range loop
         declare
            Name : constant String := Category_Texts (Index).all;
            Rule : constant String :=
              I18N.Runtime_Data.Plural_Category_Rule
                (Kind, Locale, Name, Rule_Found);
         begin
            if Rule_Found
              and then Evaluate_Plural_Rule (Rule, N, I, V, W, F, T)
            then
               Found := True;
               return Category_From_Text (Name);
            end if;
         end;
      end loop;

      Found := False;
      return Other;
   end Runtime_Rule_Override;

   function Cardinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   is
      N      : constant Long_Long_Integer := Magnitude (Value);
      Mod10  : constant Long_Long_Integer := N mod 10;
      Mod100 : constant Long_Long_Integer := N mod 100;
      Found  : Boolean;
   begin
      declare
         Override : constant Plural_Category :=
           Runtime_Override ("cardinal", Locale, N, Found);
      begin
         if Found then
            return Override;
         end if;
      end;

      declare
         Override : constant Plural_Category :=
           Runtime_Rule_Override ("cardinal", Locale, N, N, 0, 0, Found);
      begin
         if Found then
            return Override;
         end if;
      end;

      case Cardinal_Family (Locale) is
         when Lang_N_Is_1 =>
            return (if N = 1 then One else Other);

         when Lang_One_Is_1 =>
            --  en, de, nl: i = 1 and v = 0 -> one
            return (if N = 1 then One else Other);

         when Lang_One_Is_0_Or_1 =>
            --  n in {0, 1} -> one.
            return (if N = 0 or else N = 1 then One else Other);

         when Lang_I_0_Or_N_1 =>
            return (if N = 0 or else N = 1 then One else Other);

         when Lang_N_One_Two =>
            if N = 1 then
               return One;
            elsif N = 2 then
               return Two;
            else
               return Other;
            end if;

         when Lang_N_1_Compact =>
            if N = 1 then
               return One;
            elsif N /= 0 and then N mod 1_000_000 = 0 then
               return Many;
            else
               return Other;
            end if;

         when Lang_I_01_Compact =>
            if N = 0 or else N = 1 then
               return One;
            elsif N mod 1_000_000 = 0 then
               return Many;
            else
               return Other;
            end if;

         when Lang_I_1_V0_Compact =>
            if N = 1 then
               return One;
            elsif N /= 0 and then N mod 1_000_000 = 0 then
               return Many;
            else
               return Other;
            end if;

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

         when Lang_Ro =>
            --  Romanian: one (=1), few for 0 and n mod 100 in 1..19.
            if N = 1 then
               return One;
            elsif N = 0 or else Mod100 in 1 .. 19 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Lt =>
            --  Lithuanian: one/few by final digit, excluding 11..19.
            if Mod10 = 1 and then Mod100 not in 11 .. 19 then
               return One;
            elsif Mod10 in 2 .. 9 and then Mod100 not in 11 .. 19 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Sl =>
            --  Slovenian: one/two/few by n mod 100.
            if Mod100 = 1 then
               return One;
            elsif Mod100 = 2 then
               return Two;
            elsif Mod100 in 3 .. 4 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Sr =>
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;
            elsif Mod10 in 2 .. 4 and then Mod100 not in 12 .. 14 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Cy =>
            case N is
               when 0 => return Zero;
               when 1 => return One;
               when 2 => return Two;
               when 3 => return Few;
               when 6 => return Many;
               when others => return Other;
            end case;

         when Lang_Zero_One =>
            if N = 0 then
               return Zero;
            elsif N = 1 then
               return One;
            else
               return Other;
            end if;

         when Lang_Ceb =>
            if N in 1 .. 3 or else (Mod10 /= 4 and then Mod10 /= 6 and then Mod10 /= 9) then
               return One;
            else
               return Other;
            end if;

         when Lang_Ff =>
            return (if N = 0 or else N = 1 then One else Other);

         when Lang_Dsb =>
            if Mod100 = 1 then
               return One;
            elsif Mod100 = 2 then
               return Two;
            elsif Mod100 in 3 .. 4 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Lv =>
            if Mod10 = 0 or else Mod100 in 11 .. 19 then
               return Zero;
            elsif Mod10 = 1 and then Mod100 /= 11 then
               return One;
            else
               return Other;
            end if;

         when Lang_Be =>
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;
            elsif Mod10 in 2 .. 4 and then Mod100 not in 12 .. 14 then
               return Few;
            elsif Mod10 = 0 or else Mod10 in 5 .. 9 or else Mod100 in 11 .. 14 then
               return Many;
            else
               return Other;
            end if;

         when Lang_Br =>
            if Mod10 = 1 and then Mod100 /= 11 and then Mod100 /= 71 and then Mod100 /= 91 then
               return One;
            elsif Mod10 = 2 and then Mod100 /= 12 and then Mod100 /= 72 and then Mod100 /= 92 then
               return Two;
            elsif (Mod10 in 3 .. 4 or else Mod10 = 9)
              and then not In_Range (Mod100, 10, 19)
              and then not In_Range (Mod100, 70, 79)
              and then not In_Range (Mod100, 90, 99)
            then
               return Few;
            elsif N /= 0 and then N mod 1_000_000 = 0 then
               return Many;
            else
               return Other;
            end if;

         when Lang_Da =>
            return (if N = 1 then One else Other);

         when Lang_Ga =>
            case N is
               when 1 => return One;
               when 2 => return Two;
               when 3 .. 6 => return Few;
               when 7 .. 10 => return Many;
               when others => return Other;
            end case;

         when Lang_Gd =>
            if N = 1 or else N = 11 then
               return One;
            elsif N = 2 or else N = 12 then
               return Two;
            elsif N in 3 .. 10 or else N in 13 .. 19 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Gv =>
            if Mod10 = 1 then
               return One;
            elsif Mod10 = 2 then
               return Two;
            elsif Mod100 = 0 or else Mod100 = 20 or else Mod100 = 40
              or else Mod100 = 60 or else Mod100 = 80
            then
               return Few;
            else
               return Other;
            end if;

         when Lang_He =>
            if N = 1 then
               return One;
            elsif N = 2 then
               return Two;
            else
               return Other;
            end if;

         when Lang_Is =>
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;
            else
               return Other;
            end if;

         when Lang_Kw =>
            if N = 0 then
               return Zero;
            elsif N = 1 then
               return One;
            elsif Mod100 = 2 or else Mod100 = 22 or else Mod100 = 42
              or else Mod100 = 62 or else Mod100 = 82
              or else (N mod 1_000 = 0
                       and then (In_Range (N mod 100_000, 1_000, 20_000)
                                 or else N mod 100_000 = 40_000
                                 or else N mod 100_000 = 60_000
                                 or else N mod 100_000 = 80_000))
              or else (N /= 0 and then N mod 1_000_000 = 100_000)
            then
               return Two;
            elsif Mod100 = 3 or else Mod100 = 23 or else Mod100 = 43
              or else Mod100 = 63 or else Mod100 = 83
            then
               return Few;
            elsif Mod100 = 1 or else Mod100 = 21 or else Mod100 = 41
              or else Mod100 = 61 or else Mod100 = 81
            then
               return Many;
            else
               return Other;
            end if;

         when Lang_Lag =>
            if N = 0 then
               return Zero;
            elsif N = 1 then
               return One;
            else
               return Other;
            end if;

         when Lang_Mk =>
            if Mod10 = 1 and then Mod100 /= 11 then
               return One;
            else
               return Other;
            end if;

         when Lang_Mt =>
            if N = 1 then
               return One;
            elsif N = 2 then
               return Two;
            elsif N = 0 or else Mod100 in 3 .. 10 then
               return Few;
            elsif Mod100 in 11 .. 19 then
               return Many;
            else
               return Other;
            end if;

         when Lang_Shi =>
            if N = 0 or else N = 1 then
               return One;
            elsif N in 2 .. 10 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Si =>
            return (if N = 0 or else N = 1 then One else Other);

         when Lang_Tzm =>
            return (if N in 0 .. 1 or else N in 11 .. 99 then One else Other);

         when Lang_N_One_Ordinal | Lang_It_Ordinal
            | Lang_Indic_Ordinal | Lang_Hi_Ordinal | Lang_Other_Only =>
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
      I : constant Long_Long_Integer := Magnitude (Integer_Part);
   begin
      --  No visible fraction: identical to the integer classification.
      if Fraction_Digits = 0 then
         return Cardinal (Locale, I);
      end if;

      declare
         Found : Boolean;
         Override : constant Plural_Category :=
           Runtime_Rule_Override
             ("cardinal", Locale, I, I, Fraction_Digits,
              Magnitude (Fraction_Value), Found);
      begin
         if Found then
            return Override;
         end if;
      end;

      --  A visible fraction is present (operand v > 0).
      case Cardinal_Family (Locale) is
         when Lang_N_Is_1 =>
            return (if I = 1 and then Fraction_Value = 0 then One else Other);

         when Lang_One_Is_1 =>
            --  en/de/nl/da/es/it: "one" requires v = 0, so a fraction is other.
            return Other;

         when Lang_One_Is_0_Or_1 =>
            --  fr/pt: one iff i in {0, 1}, regardless of the fraction.
            return (if I = 0 or else I = 1 then One else Other);

         when Lang_I_0_Or_N_1 =>
            return
              (if I = 0
                 or else (I = 1 and then Fraction_Value = 0)
               then One
               else Other);

         when Lang_N_One_Two =>
            if Fraction_Value = 0 and then I = 1 then
               return One;
            elsif Fraction_Value = 0 and then I = 2 then
               return Two;
            else
               return Other;
            end if;

         when Lang_N_1_Compact =>
            return (if I = 1 and then Fraction_Value = 0 then One else Other);

         when Lang_I_01_Compact =>
            return (if I = 0 or else I = 1 then One else Other);

         when Lang_I_1_V0_Compact =>
            return Other;

         when Lang_Cs =>
            --  Czech: a visible fraction (v /= 0) is "many".
            return Many;

         when Lang_Ro =>
            --  Romanian fractions are "few".
            return Few;

         when Lang_Lt =>
            --  Lithuanian visible fractions are "many".
            return Many;

         when Lang_Sl =>
            --  Slovenian visible fractions are "few".
            return Few;

         when Lang_Sr =>
            declare
               F_Mod10  : constant Long_Long_Integer := Fraction_Value mod 10;
               F_Mod100 : constant Long_Long_Integer := Fraction_Value mod 100;
            begin
               if F_Mod10 = 1 and then F_Mod100 /= 11 then
                  return One;
               elsif F_Mod10 in 2 .. 4 and then F_Mod100 not in 12 .. 14 then
                  return Few;
               else
                  return Other;
               end if;
            end;

         when Lang_Ru | Lang_Pl | Lang_Ar | Lang_Cy | Lang_Zero_One
            | Lang_Be | Lang_Br | Lang_Ga | Lang_Gd | Lang_Kw | Lang_Mt
            | Lang_Tzm
            | Lang_N_One_Ordinal | Lang_It_Ordinal | Lang_Indic_Ordinal
            | Lang_Hi_Ordinal | Lang_Other_Only =>
            if Fraction_Value = 0 then
               return Cardinal (Locale, I);
            else
               return Other;
            end if;

         when Lang_Ceb =>
            declare
               F_Mod10 : constant Long_Long_Integer := Fraction_Value mod 10;
            begin
               return
                 (if F_Mod10 /= 4 and then F_Mod10 /= 6 and then F_Mod10 /= 9
                  then One
                  else Other);
            end;

         when Lang_Ff =>
            return (if I = 0 or else I = 1 then One else Other);

         when Lang_Dsb =>
            declare
               F_Mod100 : constant Long_Long_Integer := Fraction_Value mod 100;
            begin
               if F_Mod100 = 1 then
                  return One;
               elsif F_Mod100 = 2 then
                  return Two;
               elsif F_Mod100 in 3 .. 4 then
                  return Few;
               else
                  return Other;
               end if;
            end;

         when Lang_Lv =>
            declare
               F_Mod10  : constant Long_Long_Integer := Fraction_Value mod 10;
               F_Mod100 : constant Long_Long_Integer := Fraction_Value mod 100;
            begin
               if Fraction_Digits = 2 and then F_Mod100 in 11 .. 19 then
                  return Zero;
               elsif Fraction_Digits = 2 and then F_Mod10 = 1 and then F_Mod100 /= 11 then
                  return One;
               elsif Fraction_Digits /= 2 and then F_Mod10 = 1 then
                  return One;
               else
                  return Other;
               end if;
            end;

         when Lang_Da =>
            declare
               T : constant Long_Long_Integer := Compact_Fraction (Fraction_Value);
            begin
               if (I = 1 and then Fraction_Value = 0)
                 or else (T /= 0 and then (I = 0 or else I = 1))
               then
                  return One;
               else
                  return Other;
               end if;
            end;

         when Lang_Gv =>
            return Many;

         when Lang_He =>
            return (if I = 0 then One else Other);

         when Lang_Is =>
            declare
               T        : constant Long_Long_Integer := Compact_Fraction (Fraction_Value);
               T_Mod10  : constant Long_Long_Integer := T mod 10;
               T_Mod100 : constant Long_Long_Integer := T mod 100;
            begin
               if T = 0 then
                  return Cardinal (Locale, I);
               elsif T_Mod10 = 1 and then T_Mod100 /= 11 then
                  return One;
               else
                  return Other;
               end if;
            end;

         when Lang_Lag =>
            return (if I = 0 or else I = 1 then One else Other);

         when Lang_Mk =>
            declare
               F_Mod10  : constant Long_Long_Integer := Fraction_Value mod 10;
               F_Mod100 : constant Long_Long_Integer := Fraction_Value mod 100;
            begin
               return
                 (if F_Mod10 = 1 and then F_Mod100 /= 11 then One else Other);
            end;

         when Lang_Shi =>
            if I = 0 or else (I = 1 and then Fraction_Value = 0) then
               return One;
            elsif Fraction_Value = 0 and then I in 2 .. 10 then
               return Few;
            else
               return Other;
            end if;

         when Lang_Si =>
            if Fraction_Value = 0 and then (I = 0 or else I = 1) then
               return One;
            elsif I = 0 and then Fraction_Value = 1 then
               return One;
            else
               return Other;
            end if;
      end case;
   end Cardinal;

   function Ordinal
     (Locale : I18N.Locales.Locale_Id;
      Value  : Long_Long_Integer)
      return Plural_Category
   is
      N : constant Long_Long_Integer := Magnitude (Value);
      Found : Boolean;
   begin
      declare
         Override : constant Plural_Category :=
           Runtime_Override ("ordinal", Locale, N, Found);
      begin
         if Found then
            return Override;
         end if;
      end;

      declare
         Override : constant Plural_Category :=
           Runtime_Rule_Override ("ordinal", Locale, N, N, 0, 0, Found);
      begin
         if Found then
            return Override;
         end if;
      end;

      declare
         Family_Found : Boolean;
         Runtime_Family : constant String :=
           I18N.Runtime_Data.Plural_Rule_Family
             ("ordinal", Locale, Family_Found);
         Store_Found : Boolean := False;
         Store_Family : constant String :=
           (if Family_Found then ""
            else I18N.Locale_Data.Lookup
                   ("ordinal_family", Locale, "", Store_Found));
         Family : constant String :=
           (if Family_Found then Runtime_Family
            elsif Store_Found then Store_Family
            else I18N.CLDR_Data.Ordinal_Rule_Family (Locale));
      begin
         if Family = "en-ordinal" then
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

         elsif Family = "n-one-ordinal" then
            --  Ordinal split: 1 -> one; everything else -> other.
            return (if N = 1 then One else Other);

         elsif Family = "it-ordinal" then
            --  Italian ordinal "many" set; everything else -> other.
            if N = 8 or else N = 11 or else N = 80 or else N = 800 then
               return Many;
            else
               return Other;
            end if;

         elsif Family = "indic-ordinal" then
            case N is
               when 1 | 5 | 7 | 8 | 9 | 10 => return One;
               when 2 | 3 => return Two;
               when 4 => return Few;
               when 6 => return Many;
               when others => return Other;
            end case;

         elsif Family = "hi-ordinal" then
            case N is
               when 1 => return One;
               when 2 | 3 => return Two;
               when 4 => return Few;
               when 6 => return Many;
               when others => return Other;
            end case;

         elsif Family = "az-ordinal" then
            declare
               Mod10   : constant Long_Long_Integer := N mod 10;
               Mod100  : constant Long_Long_Integer := N mod 100;
               Mod1000 : constant Long_Long_Integer := N mod 1000;
            begin
               if Mod10 in 1 .. 2 or else Mod10 = 5 or else Mod10 in 7 .. 8
                 or else Mod100 = 20 or else Mod100 = 50 or else Mod100 = 70
                 or else Mod100 = 80
               then
                  return One;
               elsif Mod10 in 3 .. 4
                 or else Mod1000 = 100 or else Mod1000 = 200
                 or else Mod1000 = 300 or else Mod1000 = 400
                 or else Mod1000 = 500 or else Mod1000 = 600
                 or else Mod1000 = 700 or else Mod1000 = 800
                 or else Mod1000 = 900
               then
                  return Few;
               elsif N = 0 or else Mod10 = 6 or else Mod100 = 40
                 or else Mod100 = 60 or else Mod100 = 90
               then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "be-ordinal" then
            declare
               Mod10  : constant Long_Long_Integer := N mod 10;
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               return
                 (if Mod10 in 2 .. 3 and then Mod100 /= 12 and then Mod100 /= 13
                  then Few
                  else Other);
            end;

         elsif Family = "blo-ordinal" then
            if N = 0 then
               return Zero;
            elsif N = 1 then
               return One;
            elsif N in 2 .. 6 then
               return Few;
            else
               return Other;
            end if;

         elsif Family = "ca-ordinal" then
            case N is
               when 1 | 3 => return One;
               when 2 => return Two;
               when 4 => return Few;
               when others => return Other;
            end case;

         elsif Family = "cy-ordinal" then
            case N is
               when 0 | 7 | 8 | 9 => return Zero;
               when 1 => return One;
               when 2 => return Two;
               when 3 | 4 => return Few;
               when 5 | 6 => return Many;
               when others => return Other;
            end case;

         elsif Family = "gd-ordinal" then
            if N = 1 or else N = 11 then
               return One;
            elsif N = 2 or else N = 12 then
               return Two;
            elsif N = 3 or else N = 13 then
               return Few;
            else
               return Other;
            end if;

         elsif Family = "hu-ordinal" then
            return (if N = 1 or else N = 5 then One else Other);

         elsif Family = "ka-ordinal" then
            declare
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               if N = 1 then
                  return One;
               elsif N = 0 or else Mod100 in 2 .. 20
                 or else Mod100 = 40 or else Mod100 = 60 or else Mod100 = 80
               then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "kk-ordinal" then
            declare
               Mod10 : constant Long_Long_Integer := N mod 10;
            begin
               if (Mod10 = 0 and then N /= 0) or else Mod10 = 6 or else Mod10 = 9 then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "kw-ordinal" then
            declare
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               if N in 1 .. 4 or else Mod100 in 1 .. 4 or else Mod100 in 21 .. 24
                 or else Mod100 in 41 .. 44 or else Mod100 in 61 .. 64
                 or else Mod100 in 81 .. 84
               then
                  return One;
               elsif N = 5 or else Mod100 = 5 then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "lij-ordinal" then
            if N = 8 or else N = 11 or else N in 80 .. 89 or else N in 800 .. 899 then
               return Many;
            else
               return Other;
            end if;

         elsif Family = "mk-ordinal" then
            declare
               Mod10  : constant Long_Long_Integer := N mod 10;
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               if Mod10 = 1 and then Mod100 /= 11 then
                  return One;
               elsif Mod10 = 2 and then Mod100 /= 12 then
                  return Two;
               elsif Mod10 in 7 .. 8 and then Mod100 not in 17 .. 18 then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "mr-ordinal" then
            case N is
               when 1 => return One;
               when 2 | 3 => return Two;
               when 4 => return Few;
               when others => return Other;
            end case;

         elsif Family = "ne-ordinal" then
            return (if N in 1 .. 4 then One else Other);

         elsif Family = "or-ordinal" then
            case N is
               when 1 | 5 | 7 .. 9 => return One;
               when 2 | 3 => return Two;
               when 4 => return Few;
               when 6 => return Many;
               when others => return Other;
            end case;

         elsif Family = "sq-ordinal" then
            declare
               Mod10  : constant Long_Long_Integer := N mod 10;
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               if N = 1 then
                  return One;
               elsif Mod10 = 4 and then Mod100 /= 14 then
                  return Many;
               else
                  return Other;
               end if;
            end;

         elsif Family = "sv-ordinal" then
            declare
               Mod10  : constant Long_Long_Integer := N mod 10;
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               return
                 (if Mod10 in 1 .. 2 and then Mod100 not in 11 .. 12
                  then One
                  else Other);
            end;

         elsif Family = "tk-ordinal" then
            declare
               Mod10 : constant Long_Long_Integer := N mod 10;
            begin
               return
                 (if Mod10 = 6 or else Mod10 = 9 or else N = 10
                  then Few
                  else Other);
            end;

         elsif Family = "uk-ordinal" then
            declare
               Mod10  : constant Long_Long_Integer := N mod 10;
               Mod100 : constant Long_Long_Integer := N mod 100;
            begin
               return
                 (if Mod10 = 3 and then Mod100 /= 13 then Few else Other);
            end;

         else
            return Other;
         end if;
      end;
   end Ordinal;

end I18N.Plurals;
