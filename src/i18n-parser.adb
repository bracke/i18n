with I18N.AST; use I18N.AST;
with I18N.Currency;
with I18N.Extra_Format;
with I18N.Number_Format;
with Ada.Strings.Unbounded;

package body I18N.Parser is

   use Ada.Strings.Unbounded;

   Apostrophe           : constant Character := Character'Val (39);
   Escaped_Number_Sign  : constant Character := Character'Val (1);

   function Is_Quote_Syntax_Character (C : Character) return Boolean is
   begin
      return C = '{' or else C = '}' or else C = '#' or else C = Apostrophe;
   end Is_Quote_Syntax_Character;

   procedure Append_Quoted_Character
     (Text : in out Unbounded_String;
      C    : Character) is
   begin
      if C = '#' then
         Append (Source => Text, New_Item => Escaped_Number_Sign);
      else
         Append (Source => Text, New_Item => C);
      end if;
   end Append_Quoted_Character;

   procedure Raise_Unbalanced_Braces
     (Message : String)
   is
   begin
      raise Unbalanced_Braces with Message;
   end Raise_Unbalanced_Braces;

   function Is_Identifier_Character (C : Character) return Boolean is
   begin
      return
        (C in 'A' .. 'Z')
        or else (C in 'a' .. 'z')
        or else (C in '0' .. '9')
        or else C = '_'
        or else C = '-';
   end Is_Identifier_Character;

   function Is_Whitespace (C : Character) return Boolean is
   begin
      return
        C = ' '
        or else C = Character'Val (9)
        or else C = Character'Val (10)
        or else C = Character'Val (13);
   end Is_Whitespace;

   procedure Skip_Whitespace (Source : String; Pos : in out Positive) is
   begin
      while Pos <= Source'Last and then Is_Whitespace (Source (Pos)) loop
         Pos := Pos + 1;
      end loop;
   end Skip_Whitespace;

   procedure Flush_Text
     (Head : in out I18N.AST.Node_Access;
      Tail : in out I18N.AST.Node_Access;
      Text : in out Unbounded_String) is
   begin
      if Length (Text) > 0 then
         I18N.AST.Append_Text
           (Head => Head, Tail => Tail, Text => To_String (Text));

         Text := Null_Unbounded_String;
      end if;
   end Flush_Text;

   function Read_Identifier
     (Source : String; Pos : in out Positive) return String
   is
      Start : constant Positive := Pos;
   begin
      if Pos > Source'Last or else not Is_Identifier_Character (Source (Pos))
      then
         raise Parse_Error with "Expected identifier";
      end if;

      while Pos <= Source'Last and then Is_Identifier_Character (Source (Pos))
      loop
         Pos := Pos + 1;
      end loop;

      return Source (Start .. Pos - 1);
   end Read_Identifier;

   function Trimmed (Text : String) return String is
      First : Positive := Text'First;
      Last  : Natural := Text'Last;
   begin
      while First <= Text'Last and then Is_Whitespace (Text (First)) loop
         First := First + 1;
      end loop;

      while Last >= First and then Is_Whitespace (Text (Last)) loop
         Last := Last - 1;
      end loop;

      if Last < First then
         return "";
      end if;

      return Text (First .. Last);
   end Trimmed;

   function Read_Format_Option
     (Source : String; Pos : in out Positive) return String
   is
      Start : Positive;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) = '}' then
         return "";
      elsif Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' or '}' after format keyword";
      end if;

      Pos := Pos + 1;
      Start := Pos;

      while Pos <= Source'Last loop
         if Source (Pos) = Apostrophe then
            if Pos < Source'Last and then Source (Pos + 1) = Apostrophe then
               Pos := Pos + 2;
            else
               Pos := Pos + 1;
               while Pos <= Source'Last loop
                  if Source (Pos) = Apostrophe then
                     if Pos < Source'Last and then Source (Pos + 1) = Apostrophe
                     then
                        Pos := Pos + 2;
                     else
                        Pos := Pos + 1;
                        exit;
                     end if;
                  else
                     Pos := Pos + 1;
                  end if;
               end loop;
            end if;
         elsif Source (Pos) = '}' then
            exit;
         elsif Source (Pos) = '{' then
            raise Parse_Error with "Invalid format option";
         else
            Pos := Pos + 1;
         end if;
      end loop;

      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Unclosed format option");
      end if;

      return Trimmed (Source (Start .. Pos - 1));
   end Read_Format_Option;

   function Is_Date_Time_Style (Style : String) return Boolean is
      First_Comma : Natural := 0;
      Style_Only  : constant String :=
        (if Style'Length = 0 then "" else Style);

      function First_Unquoted_Comma (Text : String) return Natural is
         Apostrophe : constant Character := Character'Val (39);
         Index      : Natural := Text'First;
         In_Quote   : Boolean := False;
      begin
         while Index <= Text'Last loop
            if Text (Index) = Apostrophe then
               if Index < Text'Last and then Text (Index + 1) = Apostrophe
               then
                  Index := Index + 2;
               else
                  In_Quote := not In_Quote;
                  Index := Index + 1;
               end if;
            elsif Text (Index) = ',' and then not In_Quote then
               return Index;
            else
               Index := Index + 1;
            end if;
         end loop;

         return 0;
      end First_Unquoted_Comma;

      function Is_Skeleton (Text : String) return Boolean is
         Apostrophe : constant Character := Character'Val (39);
         Index      : Natural;

         function Is_Field (C : Character) return Boolean is
         begin
            case C is
               when 'G' | 'y' | 'Y' | 'u' | 'U' | 'r' | 'Q' | 'q'
                  | 'M' | 'L' | 'l' | 'w' | 'W' | 'd' | 'D' | 'F'
                  | 'g' | 'E' | 'e' | 'c' | 'a' | 'b' | 'B'
                  | 'h' | 'H' | 'K' | 'k' | 'j' | 'J' | 'C'
                  | 'm' | 's' | 'S' | 'A' | 'n' | 'N' | 'z' | 'Z'
                  | 'O' | 'v' | 'V' | 'X' | 'x' =>
                  return True;
               when others =>
                  return False;
            end case;
         end Is_Field;
      begin
         if Text'Length < 3
           or else Text (Text'First .. Text'First + 1) /= "::"
         then
            return False;
         end if;

         declare
            Alias : constant String := Text (Text'First + 2 .. Text'Last);
         begin
            if Alias = "short"
              or else Alias = "medium"
              or else Alias = "long"
              or else Alias = "full"
              or else Alias = "date-short"
              or else Alias = "date-medium"
              or else Alias = "date-long"
              or else Alias = "date-full"
              or else Alias = "date/short"
              or else Alias = "date/medium"
              or else Alias = "date/long"
              or else Alias = "date/full"
              or else Alias = "time-short"
              or else Alias = "time-medium"
              or else Alias = "time-long"
              or else Alias = "time-full"
              or else Alias = "time/short"
              or else Alias = "time/medium"
              or else Alias = "time/long"
              or else Alias = "time/full"
              or else Alias = "datetime-short"
              or else Alias = "datetime-medium"
              or else Alias = "datetime-long"
              or else Alias = "datetime-full"
              or else Alias = "datetime/short"
              or else Alias = "datetime/medium"
              or else Alias = "datetime/long"
              or else Alias = "datetime/full"
              or else Alias = "dateTime-short"
              or else Alias = "dateTime-medium"
              or else Alias = "dateTime-long"
              or else Alias = "dateTime-full"
              or else Alias = "dateTime/short"
              or else Alias = "dateTime/medium"
              or else Alias = "dateTime/long"
              or else Alias = "dateTime/full"
            then
               return True;
            end if;
         end;

         Index := Text'First + 2;
         while Index <= Text'Last loop
            if Text (Index) = Apostrophe then
               if Index < Text'Last and then Text (Index + 1) = Apostrophe
               then
                  Index := Index + 2;
               else
                  declare
                     Closed : Boolean := False;
                  begin
                     Index := Index + 1;
                     while Index <= Text'Last loop
                        if Text (Index) = Apostrophe then
                           if Index < Text'Last
                             and then Text (Index + 1) = Apostrophe
                           then
                              Index := Index + 2;
                           else
                              Closed := True;
                              Index := Index + 1;
                              exit;
                           end if;
                        else
                           Index := Index + 1;
                        end if;
                     end loop;

                     if not Closed then
                        return False;
                     end if;
                  end;
               end if;
            elsif Is_Field (Text (Index)) then
               Index := Index + 1;
            else
               return False;
            end if;
         end loop;

         return True;
      end Is_Skeleton;
   begin
      First_Comma := First_Unquoted_Comma (Style);

      if First_Comma /= 0 then
         declare
            Left  : constant String :=
              Trimmed (Style (Style'First .. First_Comma - 1));
            Right : constant String :=
              Trimmed (Style (First_Comma + 1 .. Style'Last));
         begin
            return Right'Length > 0 and then Is_Date_Time_Style (Left);
         end;
      end if;

      return
        Style_Only = ""
        or else Style_Only = "short"
        or else Style_Only = "medium"
        or else Style_Only = "long"
        or else Style_Only = "full"
        or else Is_Skeleton (Style_Only);
   end Is_Date_Time_Style;

   function Parse_Sequence
     (Source : String; Pos : in out Positive; Stop_On_Close : Boolean)
      return I18N.AST.Node_Access;

   function Empty_Branch_AST return I18N.AST.Node_Access is
   begin
      return
        new I18N.AST.Node'
          (Kind         => I18N.AST.Text,
           Text         => Null_Unbounded_String,
           Name         => Null_Unbounded_String,
           Currency_Code => Null_Unbounded_String,
           Plural_Offset => 0,
           Plural_Zero => null,
           One          => null,
           Plural_Two  => null,
           Plural_Few  => null,
           Plural_Many => null,
           Other        => null,
           Plural_Exact => null,
           Branches     => null,
           Ord_Zero     => null,
           Ord_One      => null,
           Ord_Two      => null,
           Ord_Few      => null,
           Ord_Many     => null,
           Ord_Other    => null,
           Ord_Exact    => null,
           Next         => null);
   end Empty_Branch_AST;

   function Image_No_Leading_Space (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      else
         return Image;
      end if;
   end Image_No_Leading_Space;

   function Read_Exact_Selector
     (Source : String;
      Pos    : in out Positive)
      return String
   is
      Start : Positive;
   begin
      if Pos > Source'Last or else Source (Pos) /= '=' then
         raise Parse_Error with "Expected exact selector";
      end if;

      Pos := Pos + 1;
      Start := Pos;

      if Pos <= Source'Last and then Source (Pos) = '-' then
         Pos := Pos + 1;
      end if;

      if Pos > Source'Last or else Source (Pos) not in '0' .. '9' then
         raise Parse_Error with "Expected exact selector digits";
      end if;

      while Pos <= Source'Last and then Source (Pos) in '0' .. '9' loop
         Pos := Pos + 1;
      end loop;

      return Image_No_Leading_Space
        (Long_Long_Integer'Value (Source (Start .. Pos - 1)));
   exception
      when Constraint_Error =>
         raise Parse_Error with "Exact selector out of range";
   end Read_Exact_Selector;

   function Parse_Branch_Message
     (Source : String; Pos : in out Positive) return I18N.AST.Node_Access
   is
      Branch_AST : I18N.AST.Node_Access := null;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= '{' then
         raise Parse_Error with "Expected branch message block";
      end if;

      Pos := Pos + 1;
      Branch_AST :=
        Parse_Sequence (Source => Source, Pos => Pos, Stop_On_Close => True);

      if Pos > Source'Last or else Source (Pos) /= '}' then
         I18N.AST.Free (Branch_AST);
         Raise_Unbalanced_Braces ("Unclosed branch message");
      end if;

      Pos := Pos + 1;

      if Branch_AST = null then
         --  Preserve the difference between an absent optional select branch
         --  and a present-but-empty branch such as male {}. Optional select
         --  branches use null to mean absent, so an explicit empty branch must
         --  have a real AST root.
         Branch_AST := Empty_Branch_AST;
      end if;

      return Branch_AST;
   exception
      when others =>
         I18N.AST.Free (Branch_AST);
         raise;
   end Parse_Branch_Message;

   procedure Parse_Plural
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Zero_Branch  : I18N.AST.Node_Access := null;
      One_Branch   : I18N.AST.Node_Access := null;
      Two_Branch   : I18N.AST.Node_Access := null;
      Few_Branch   : I18N.AST.Node_Access := null;
      Many_Branch  : I18N.AST.Node_Access := null;
      Other_Branch : I18N.AST.Node_Access := null;
      Exact_Branches : I18N.AST.Branch_Access := null;
      Exact_Tail     : I18N.AST.Branch_Access := null;
      Have_Zero    : Boolean := False;
      Have_One     : Boolean := False;
      Have_Two     : Boolean := False;
      Have_Few     : Boolean := False;
      Have_Many    : Boolean := False;
      Have_Other   : Boolean := False;
      Offset       : Long_Long_Integer := 0;
      Have_Offset  : Boolean := False;

      function Read_Natural_Offset
        (Source : String;
         Pos    : in out Positive)
         return Long_Long_Integer
      is
         Start : constant Positive := Pos;
      begin
         if Pos > Source'Last or else Source (Pos) not in '0' .. '9' then
            raise Parse_Error with "Expected plural offset digits";
         end if;

         while Pos <= Source'Last and then Source (Pos) in '0' .. '9' loop
            Pos := Pos + 1;
         end loop;

         return Long_Long_Integer'Value (Source (Start .. Pos - 1));
      exception
         when Constraint_Error =>
            raise Parse_Error with "Plural offset out of range";
      end Read_Natural_Offset;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' after plural keyword";
      end if;

      Pos := Pos + 1;

      loop
         Skip_Whitespace (Source, Pos);

         if Pos > Source'Last then
            Raise_Unbalanced_Braces ("Unclosed plural block");
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            Exact_Prefix : constant Boolean := Source (Pos) = '=';
            Branch_Name : constant String :=
              (if Exact_Prefix
               then Read_Exact_Selector (Source, Pos)
               else Read_Identifier (Source, Pos));
            Is_Exact    : constant Boolean := Exact_Prefix;
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if not Is_Exact and then Branch_Name = "offset" then
               if Have_Offset
                 or else Have_Zero
                 or else Have_One
                 or else Have_Two
                 or else Have_Few
                 or else Have_Many
                 or else Have_Other
               then
                  raise Parse_Error with "Plural offset must appear before branches";
               end if;

               Skip_Whitespace (Source, Pos);
               if Pos > Source'Last or else Source (Pos) /= ':' then
                  raise Parse_Error with "Expected ':' after plural offset";
               end if;

               Pos := Pos + 1;
               Skip_Whitespace (Source, Pos);
               Offset := Read_Natural_Offset (Source, Pos);
               Have_Offset := True;
               goto Continue_Plural;
            end if;

            if Is_Exact then
               if I18N.AST.Has_Branch (Exact_Branches, Branch_Name) then
                  raise Parse_Error with "Duplicate exact plural branch";
               end if;
            elsif Branch_Name /= "zero"
              and then Branch_Name /= "one"
              and then Branch_Name /= "two"
              and then Branch_Name /= "few"
              and then Branch_Name /= "many"
              and then Branch_Name /= "other"
            then
               raise Parse_Error with "Expected zero, one, two, few, many, or other plural branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            if Is_Exact then
               I18N.AST.Append_Branch
                 (Head      => Exact_Branches,
                  Tail      => Exact_Tail,
                  Name      => Branch_Name,
                  Body_Root => Branch_AST);
            elsif Branch_Name = "zero" then
               if Have_Zero then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate zero plural branch";
               end if;

               Zero_Branch := Branch_AST;
               Have_Zero := True;
            elsif Branch_Name = "one" then
               if Have_One then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate one plural branch";
               end if;

               One_Branch := Branch_AST;
               Have_One := True;
            elsif Branch_Name = "two" then
               if Have_Two then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate two plural branch";
               end if;

               Two_Branch := Branch_AST;
               Have_Two := True;
            elsif Branch_Name = "few" then
               if Have_Few then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate few plural branch";
               end if;

               Few_Branch := Branch_AST;
               Have_Few := True;
            elsif Branch_Name = "many" then
               if Have_Many then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate many plural branch";
               end if;

               Many_Branch := Branch_AST;
               Have_Many := True;
            elsif Branch_Name = "other" then
               if Have_Other then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate other plural branch";
               end if;

               Other_Branch := Branch_AST;
               Have_Other := True;
            end if;
         end;

         <<Continue_Plural>>
         null;
      end loop;

      --  The parser leaves branch-completeness decisions to the validator so
      --  malformed grammar and incomplete validated ASTs receive distinct
      --  deterministic errors.
      Pos := Pos + 1;

      I18N.AST.Append_Plural
        (Head  => Head,
         Tail  => Tail,
         Name  => Name,
         Offset => Offset,
         Zero  => Zero_Branch,
         One   => One_Branch,
         Two   => Two_Branch,
         Few   => Few_Branch,
         Many  => Many_Branch,
         Other => Other_Branch,
         Exact => Exact_Branches);
   exception
      when others =>
         I18N.AST.Free (Zero_Branch);
         I18N.AST.Free (One_Branch);
         I18N.AST.Free (Two_Branch);
         I18N.AST.Free (Few_Branch);
         I18N.AST.Free (Many_Branch);
         I18N.AST.Free (Other_Branch);
         I18N.AST.Free_Branches (Exact_Branches);
         raise;
   end Parse_Plural;

   procedure Parse_Select
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Branches      : I18N.AST.Branch_Access := null;
      Branches_Tail : I18N.AST.Branch_Access := null;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' after select keyword";
      end if;

      Pos := Pos + 1;

      loop
         Skip_Whitespace (Source, Pos);

         if Pos > Source'Last then
            Raise_Unbalanced_Braces ("Unclosed select block");
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            --  Branch names are arbitrary validated identifiers. Read_Identifier
            --  already rejects non-identifier characters, so any well-formed
            --  identifier is accepted here; completeness ("other" required) is
            --  enforced by I18N.Validation.
            Branch_Name : constant String := Read_Identifier (Source, Pos);
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if I18N.AST.Has_Branch (Branches, Branch_Name) then
               raise Parse_Error with "Duplicate select branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            I18N.AST.Append_Branch
              (Head      => Branches,
               Tail      => Branches_Tail,
               Name      => Branch_Name,
               Body_Root => Branch_AST);
         end;
      end loop;

      --  Validation enforces the mandatory "other" fallback branch after
      --  parsing.
      Pos := Pos + 1;

      I18N.AST.Append_Select
        (Head     => Head,
         Tail     => Tail,
         Name     => Name,
         Branches => Branches);
   exception
      when others =>
         I18N.AST.Free_Branches (Branches);
         raise;
   end Parse_Select;

   procedure Parse_Select_Ordinal
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Zero_Branch  : I18N.AST.Node_Access := null;
      One_Branch   : I18N.AST.Node_Access := null;
      Two_Branch   : I18N.AST.Node_Access := null;
      Few_Branch   : I18N.AST.Node_Access := null;
      Many_Branch  : I18N.AST.Node_Access := null;
      Other_Branch : I18N.AST.Node_Access := null;
      Exact_Branches : I18N.AST.Branch_Access := null;
      Exact_Tail     : I18N.AST.Branch_Access := null;
      Have_Zero    : Boolean := False;
      Have_One     : Boolean := False;
      Have_Two     : Boolean := False;
      Have_Few     : Boolean := False;
      Have_Many    : Boolean := False;
      Have_Other   : Boolean := False;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' after selectordinal keyword";
      end if;

      Pos := Pos + 1;

      loop
         Skip_Whitespace (Source, Pos);

         if Pos > Source'Last then
            Raise_Unbalanced_Braces ("Unclosed selectordinal block");
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            Exact_Prefix : constant Boolean := Source (Pos) = '=';
            Branch_Name : constant String :=
              (if Exact_Prefix
               then Read_Exact_Selector (Source, Pos)
               else Read_Identifier (Source, Pos));
            Is_Exact    : constant Boolean := Exact_Prefix;
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if Is_Exact then
               if I18N.AST.Has_Branch (Exact_Branches, Branch_Name) then
                  raise Parse_Error with "Duplicate exact selectordinal branch";
               end if;
            elsif Branch_Name /= "zero"
              and then Branch_Name /= "one"
              and then Branch_Name /= "two"
              and then Branch_Name /= "few"
              and then Branch_Name /= "many"
              and then Branch_Name /= "other"
            then
               raise Parse_Error
                 with "Expected zero, one, two, few, many, or other selectordinal branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            if Is_Exact then
               I18N.AST.Append_Branch
                 (Head      => Exact_Branches,
                  Tail      => Exact_Tail,
                  Name      => Branch_Name,
                  Body_Root => Branch_AST);
            elsif Branch_Name = "zero" then
               if Have_Zero then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate zero selectordinal branch";
               end if;

               Zero_Branch := Branch_AST;
               Have_Zero := True;
            elsif Branch_Name = "one" then
               if Have_One then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate one selectordinal branch";
               end if;

               One_Branch := Branch_AST;
               Have_One := True;
            elsif Branch_Name = "two" then
               if Have_Two then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate two selectordinal branch";
               end if;

               Two_Branch := Branch_AST;
               Have_Two := True;
            elsif Branch_Name = "few" then
               if Have_Few then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate few selectordinal branch";
               end if;

               Few_Branch := Branch_AST;
               Have_Few := True;
            elsif Branch_Name = "many" then
               if Have_Many then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate many selectordinal branch";
               end if;

               Many_Branch := Branch_AST;
               Have_Many := True;
            else
               if Have_Other then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error
                    with "Duplicate other selectordinal branch";
               end if;

               Other_Branch := Branch_AST;
               Have_Other := True;
            end if;
         end;
      end loop;

      --  Validation enforces mandatory ordinal branches after parsing.
      Pos := Pos + 1;

      I18N.AST.Append_Select_Ordinal
        (Head  => Head,
         Tail  => Tail,
         Name  => Name,
         Zero  => Zero_Branch,
         One   => One_Branch,
         Two   => Two_Branch,
         Few   => Few_Branch,
         Many  => Many_Branch,
         Other => Other_Branch,
         Exact => Exact_Branches);
   exception
      when others =>
         I18N.AST.Free (Zero_Branch);
         I18N.AST.Free (One_Branch);
         I18N.AST.Free (Two_Branch);
         I18N.AST.Free (Few_Branch);
         I18N.AST.Free (Many_Branch);
         I18N.AST.Free (Other_Branch);
         I18N.AST.Free_Branches (Exact_Branches);
         raise;
   end Parse_Select_Ordinal;

   procedure Parse_Number
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Option : constant String := Read_Format_Option (Source, Pos);

      function Currency_Style_From_Skeleton
        (Style : String;
         Target : out String;
         Last   : out Natural)
         return Boolean
      is
         Prefix : constant String := "::currency/";
         Pos    : Positive;
         Token_End : Natural;
         Code_Start : Positive;
         Code_End   : Natural;
         Code        : String (1 .. 3);
         Display     : Unbounded_String := Null_Unbounded_String;
         Cash        : Boolean := False;
         Accounting  : Boolean := False;

         function Apply_Token (Token : String) return Boolean is
         begin
            if Token = "" then
               return False;
            elsif Token = "symbol"
              or else Token = "unit-width-short"
              or else Token = "unit-width/short"
              or else Token = "standard"
            then
               Display := Null_Unbounded_String;
            elsif Token = "narrow"
              or else Token = "unit-width-narrow"
              or else Token = "unit-width/narrow"
            then
               Display := To_Unbounded_String ("unit-width-narrow");
            elsif Token = "name"
              or else Token = "unit-width-full-name"
              or else Token = "unit-width/full-name"
              or else Token = "unit-width-long"
              or else Token = "unit-width/long"
              or else Token = "full-name"
            then
               Display := To_Unbounded_String ("unit-width-full-name");
            elsif Token = "unit-width-iso-code"
              or else Token = "unit-width/iso-code"
              or else Token = "iso-code"
            then
               Display := To_Unbounded_String ("unit-width-iso-code");
            elsif Token = "cash"
              or else Token = "precision-currency-cash"
              or else Token = "precision-currency/cash"
              or else Token = "precision/currency-cash"
              or else Token = "::precision-currency-cash"
            then
               Cash := True;
            elsif Token = "precision-currency-standard"
              or else Token = "precision-currency/standard"
              or else Token = "precision/currency-standard"
              or else Token = "::precision-currency-standard"
            then
               Cash := False;
            elsif Token = "accounting"
              or else Token = "sign-accounting"
              or else Token = "sign/accounting"
            then
               Accounting := True;
            else
               return False;
            end if;

            return True;
         end Apply_Token;
      begin
         Last := 0;

         if Style'Length < Prefix'Length + 3
           or else Style (Style'First .. Style'First + Prefix'Length - 1)
             /= Prefix
         then
            return False;
         end if;

         Code_Start := Style'First + Prefix'Length;
         Code_End := Code_Start + 2;
         if Code_End > Style'Last then
            return False;
         end if;

         Code := Style (Code_Start .. Code_End);
         if not I18N.Currency.Is_Valid_Code (Code) then
            return False;
         end if;

         if Code_End = Style'Last then
            Target (Target'First .. Target'First + 2) := Code;
            Last := 3;
            return True;
         elsif Style (Code_End + 1) = '/' then
            declare
               Existing : constant String := Style (Code_Start .. Style'Last);
            begin
               if I18N.Currency.Is_Valid_Code (Existing) then
                  Target (Target'First .. Target'First + Existing'Length - 1) :=
                    Existing;
                  Last := Existing'Length;
                  return True;
               else
                  return False;
               end if;
            end;
         elsif Style (Code_End + 1) /= ' ' then
            return False;
         end if;

         Pos := Code_End + 1;
         while Pos <= Style'Last loop
            while Pos <= Style'Last and then Style (Pos) = ' ' loop
               Pos := Pos + 1;
            end loop;

            exit when Pos > Style'Last;

            Token_End := Pos;
            while Token_End <= Style'Last
              and then Style (Token_End) /= ' '
            loop
               Token_End := Token_End + 1;
            end loop;

            if not Apply_Token (Style (Pos .. Token_End - 1)) then
               return False;
            end if;

            Pos := Token_End;
         end loop;

         declare
            Variant : Unbounded_String := Null_Unbounded_String;
         begin
            if Cash then
               Variant := To_Unbounded_String ("cash");
            end if;

            if Length (Display) > 0 then
               if Length (Variant) > 0 then
                  Append (Variant, "-");
               end if;
               Append (Variant, To_String (Display));
            end if;

            if Accounting then
               if Length (Variant) > 0 then
                  Append (Variant, "-");
               end if;
               Append (Variant, "accounting");
            end if;

            if Length (Variant) = 0 then
               Target (Target'First .. Target'First + 2) := Code;
               Last := 3;
            else
               declare
                  Text : constant String := Code & "/" & To_String (Variant);
               begin
                  if Text'Length > Target'Length then
                     return False;
                  end if;
                  Target (Target'First .. Target'First + Text'Length - 1) :=
                    Text;
                  Last := Text'Length;
               end;
            end if;
         end;

         return I18N.Currency.Is_Valid_Code
           (Target (Target'First .. Target'First + Last - 1));
      end Currency_Style_From_Skeleton;

      function Unit_Style_From_Skeleton
        (Style  : String;
         Target : out String;
         Last   : out Natural)
         return Boolean
      is
         Prefix : constant String := "::measure-unit/";
         Pos    : Positive;
         Token_End : Natural;
         Unit_Start : Positive;
         Unit_End   : Natural;
         Width      : Unbounded_String :=
           To_Unbounded_String ("unit-width-full-name");
         Per_Unit   : Unbounded_String := Null_Unbounded_String;

         function Normalize_Unit (Token : String) return String is
         begin
            if Token = "length-meter"
              or else Token = "length-metre"
              or else Token = "meter"
              or else Token = "metre"
            then
               return "meter";
            elsif Token = "length-kilometer"
              or else Token = "length-kilometre"
              or else Token = "kilometer"
              or else Token = "kilometre"
            then
               return "kilometer";
            elsif Token = "length-mile" or else Token = "mile" then
               return "mile";
            elsif Token = "length-yard" or else Token = "yard" then
               return "yard";
            elsif Token = "length-foot" or else Token = "foot" then
               return "foot";
            elsif Token = "length-inch" or else Token = "inch" then
               return "inch";
            elsif Token = "length-centimeter" or else Token = "centimeter" then
               return "centimeter";
            elsif Token = "length-centimetre" or else Token = "centimetre" then
               return "centimeter";
            elsif Token = "length-millimeter" or else Token = "millimeter" then
               return "millimeter";
            elsif Token = "length-millimetre" or else Token = "millimetre" then
               return "millimeter";
            elsif Token = "length-decimeter" or else Token = "decimeter" then
               return "decimeter";
            elsif Token = "length-decimetre" or else Token = "decimetre" then
               return "decimeter";
            elsif Token = "length-micrometer" or else Token = "micrometer" then
               return "micrometer";
            elsif Token = "length-micrometre" or else Token = "micrometre" then
               return "micrometer";
            elsif Token = "length-nanometer" or else Token = "nanometer" then
               return "nanometer";
            elsif Token = "length-nanometre" or else Token = "nanometre" then
               return "nanometer";
            elsif Token = "length-picometer" or else Token = "picometer" then
               return "picometer";
            elsif Token = "length-picometre" or else Token = "picometre" then
               return "picometer";
            elsif Token = "length-nautical-mile"
              or else Token = "nautical-mile"
            then
               return "nautical-mile";
            elsif Token = "length-astronomical-unit"
              or else Token = "astronomical-unit"
            then
               return "astronomical-unit";
            elsif Token = "length-light-year" or else Token = "light-year" then
               return "light-year";
            elsif Token = "length-parsec" or else Token = "parsec" then
               return "parsec";
            elsif Token = "length-fathom" or else Token = "fathom" then
               return "fathom";
            elsif Token = "length-furlong" or else Token = "furlong" then
               return "furlong";
            elsif Token = "length-pixel" or else Token = "pixel" then
               return "pixel";
            elsif Token = "length-point" or else Token = "point" then
               return "point";
            elsif Token = "length-solar-radius"
              or else Token = "solar-radius"
            then
               return "solar-radius";
            elsif Token = "length-earth-radius"
              or else Token = "earth-radius"
            then
               return "earth-radius";
            elsif Token = "graphics-dot" or else Token = "dot" then
               return "dot";
            elsif Token = "graphics-megapixel"
              or else Token = "megapixel"
            then
               return "megapixel";
            elsif Token = "graphics-pixel-per-centimeter"
              or else Token = "graphics-pixel-per-centimetre"
              or else Token = "pixel-per-centimeter"
              or else Token = "pixel-per-centimetre"
            then
               return "pixel-per-centimeter";
            elsif Token = "graphics-pixel-per-inch"
              or else Token = "pixel-per-inch"
            then
               return "pixel-per-inch";
            elsif Token = "graphics-dot-per-centimeter"
              or else Token = "graphics-dot-per-centimetre"
              or else Token = "dot-per-centimeter"
              or else Token = "dot-per-centimetre"
            then
               return "dot-per-centimeter";
            elsif Token = "graphics-dot-per-inch"
              or else Token = "dot-per-inch"
            then
               return "dot-per-inch";
            elsif Token = "volume-liter"
              or else Token = "volume-litre"
              or else Token = "liter"
              or else Token = "litre"
            then
               return "liter";
            elsif Token = "volume-milliliter"
              or else Token = "volume-millilitre"
              or else Token = "milliliter"
              or else Token = "millilitre"
            then
               return "milliliter";
            elsif Token = "volume-gallon" or else Token = "gallon" then
               return "gallon";
            elsif Token = "volume-fluid-ounce"
              or else Token = "fluid-ounce"
            then
               return "fluid-ounce";
            elsif Token = "volume-cup" or else Token = "cup" then
               return "cup";
            elsif Token = "volume-tablespoon"
              or else Token = "tablespoon"
            then
               return "tablespoon";
            elsif Token = "volume-teaspoon"
              or else Token = "teaspoon"
            then
               return "teaspoon";
            elsif Token = "volume-pint" or else Token = "pint" then
               return "pint";
            elsif Token = "volume-quart" or else Token = "quart" then
               return "quart";
            elsif Token = "volume-barrel" or else Token = "barrel" then
               return "barrel";
            elsif Token = "volume-cubic-meter"
              or else Token = "volume-cubic-metre"
              or else Token = "cubic-meter"
              or else Token = "cubic-metre"
            then
               return "cubic-meter";
            elsif Token = "volume-cubic-centimeter"
              or else Token = "volume-cubic-centimetre"
              or else Token = "cubic-centimeter"
              or else Token = "cubic-centimetre"
            then
               return "cubic-centimeter";
            elsif Token = "volume-cubic-inch"
              or else Token = "cubic-inch"
            then
               return "cubic-inch";
            elsif Token = "volume-cubic-foot"
              or else Token = "cubic-foot"
            then
               return "cubic-foot";
            elsif Token = "volume-cubic-yard"
              or else Token = "cubic-yard"
            then
               return "cubic-yard";
            elsif Token = "volume-acre-foot"
              or else Token = "acre-foot"
            then
               return "acre-foot";
            elsif Token = "mass-gram" or else Token = "gram" then
               return "gram";
            elsif Token = "mass-kilogram" or else Token = "kilogram" then
               return "kilogram";
            elsif Token = "mass-milligram" or else Token = "milligram" then
               return "milligram";
            elsif Token = "mass-tonne" or else Token = "tonne" then
               return "tonne";
            elsif Token = "mass-pound" or else Token = "pound" then
               return "pound";
            elsif Token = "mass-ounce" or else Token = "ounce" then
               return "ounce";
            elsif Token = "mass-stone" or else Token = "stone" then
               return "stone";
            elsif Token = "mass-carat" or else Token = "carat" then
               return "carat";
            elsif Token = "mass-ton" or else Token = "ton" then
               return "ton";
            elsif Token = "mass-dalton" or else Token = "dalton" then
               return "dalton";
            elsif Token = "mass-earth-mass" or else Token = "earth-mass" then
               return "earth-mass";
            elsif Token = "mass-solar-mass" or else Token = "solar-mass" then
               return "solar-mass";
            elsif Token = "duration-nanosecond"
              or else Token = "nanosecond"
            then
               return "nanosecond";
            elsif Token = "duration-microsecond"
              or else Token = "microsecond"
            then
               return "microsecond";
            elsif Token = "duration-millisecond" or else Token = "millisecond" then
               return "millisecond";
            elsif Token = "duration-second" or else Token = "second" then
               return "second";
            elsif Token = "duration-minute" or else Token = "minute" then
               return "minute";
            elsif Token = "duration-hour" or else Token = "hour" then
               return "hour";
            elsif Token = "duration-day" or else Token = "day" then
               return "day";
            elsif Token = "duration-week" or else Token = "week" then
               return "week";
            elsif Token = "duration-month" or else Token = "month" then
               return "month";
            elsif Token = "duration-year" or else Token = "year" then
               return "year";
            elsif Token = "duration-quarter" or else Token = "quarter" then
               return "quarter";
            elsif Token = "duration-decade" or else Token = "decade" then
               return "decade";
            elsif Token = "duration-century" or else Token = "century" then
               return "century";
            elsif Token = "duration-fortnight" or else Token = "fortnight" then
               return "fortnight";
            elsif Token = "area-square-meter"
              or else Token = "area-square-metre"
              or else Token = "square-meter"
              or else Token = "square-metre"
            then
               return "square-meter";
            elsif Token = "area-square-kilometer"
              or else Token = "area-square-kilometre"
              or else Token = "square-kilometer"
              or else Token = "square-kilometre"
            then
               return "square-kilometer";
            elsif Token = "area-acre" or else Token = "acre" then
               return "acre";
            elsif Token = "area-hectare" or else Token = "hectare" then
               return "hectare";
            elsif Token = "area-square-foot"
              or else Token = "square-foot"
            then
               return "square-foot";
            elsif Token = "area-square-mile"
              or else Token = "square-mile"
            then
               return "square-mile";
            elsif Token = "area-square-centimeter"
              or else Token = "area-square-centimetre"
              or else Token = "square-centimeter"
              or else Token = "square-centimetre"
            then
               return "square-centimeter";
            elsif Token = "area-square-inch"
              or else Token = "square-inch"
            then
               return "square-inch";
            elsif Token = "area-square-yard"
              or else Token = "square-yard"
            then
               return "square-yard";
            elsif Token = "temperature-celsius" or else Token = "celsius" then
               return "celsius";
            elsif Token = "temperature-fahrenheit" or else Token = "fahrenheit" then
               return "fahrenheit";
            elsif Token = "temperature-kelvin" or else Token = "kelvin" then
               return "kelvin";
            elsif Token = "angle-degree" or else Token = "degree" then
               return "degree";
            elsif Token = "angle-radian" or else Token = "radian" then
               return "radian";
            elsif Token = "angle-revolution" or else Token = "revolution" then
               return "revolution";
            elsif Token = "angle-arc-minute"
              or else Token = "arc-minute"
            then
               return "arc-minute";
            elsif Token = "angle-arc-second"
              or else Token = "arc-second"
            then
               return "arc-second";
            elsif Token = "acceleration-g-force"
              or else Token = "g-force"
            then
               return "g-force";
            elsif Token = "acceleration-meter-per-square-second"
              or else Token = "acceleration-metre-per-square-second"
              or else Token = "meter-per-square-second"
              or else Token = "metre-per-square-second"
            then
               return "meter-per-square-second";
            elsif Token = "force-newton"
              or else Token = "newton"
            then
               return "newton";
            elsif Token = "force-pound-force"
              or else Token = "pound-force"
            then
               return "pound-force";
            elsif Token = "torque-newton-meter"
              or else Token = "torque-newton-metre"
              or else Token = "newton-meter"
              or else Token = "newton-metre"
            then
               return "newton-meter";
            elsif Token = "digital-byte" or else Token = "byte" then
               return "byte";
            elsif Token = "digital-bit" or else Token = "bit" then
               return "bit";
            elsif Token = "digital-kilobyte" or else Token = "kilobyte" then
               return "kilobyte";
            elsif Token = "digital-kilobit" or else Token = "kilobit" then
               return "kilobit";
            elsif Token = "digital-megabyte" or else Token = "megabyte" then
               return "megabyte";
            elsif Token = "digital-gigabyte" or else Token = "gigabyte" then
               return "gigabyte";
            elsif Token = "digital-terabyte" or else Token = "terabyte" then
               return "terabyte";
            elsif Token = "digital-terabit" or else Token = "terabit" then
               return "terabit";
            elsif Token = "digital-megabit" or else Token = "megabit" then
               return "megabit";
            elsif Token = "digital-gigabit" or else Token = "gigabit" then
               return "gigabit";
            elsif Token = "digital-petabyte" or else Token = "petabyte" then
               return "petabyte";
            elsif Token = "digital-petabit" or else Token = "petabit" then
               return "petabit";
            elsif Token = "digital-exabyte" or else Token = "exabyte" then
               return "exabyte";
            elsif Token = "digital-exabit" or else Token = "exabit" then
               return "exabit";
            elsif Token = "speed-kilometer-per-hour"
              or else Token = "speed-kilometre-per-hour"
              or else Token = "kilometer-per-hour"
              or else Token = "kilometre-per-hour"
            then
               return "kilometer-per-hour";
            elsif Token = "speed-mile-per-hour"
              or else Token = "mile-per-hour"
            then
               return "mile-per-hour";
            elsif Token = "speed-knot" or else Token = "knot" then
               return "knot";
            elsif Token = "speed-beaufort" or else Token = "beaufort" then
               return "beaufort";
            elsif Token = "speed-meter-per-second"
              or else Token = "speed-metre-per-second"
              or else Token = "meter-per-second"
              or else Token = "metre-per-second"
            then
               return "meter-per-second";
            elsif Token = "consumption-liter-per-100-kilometer"
              or else Token = "consumption-litre-per-100-kilometre"
              or else Token = "consumption-litre-per-100-kilometer"
              or else Token = "consumption-liter-per-100-kilometre"
              or else Token = "liter-per-100-kilometer"
              or else Token = "litre-per-100-kilometre"
              or else Token = "litre-per-100-kilometer"
              or else Token = "liter-per-100-kilometre"
            then
               return "liter-per-100-kilometer";
            elsif Token = "consumption-mile-per-gallon"
              or else Token = "mile-per-gallon"
            then
               return "mile-per-gallon";
            elsif Token = "consumption-mile-per-gallon-imperial"
              or else Token = "mile-per-gallon-imperial"
            then
               return "mile-per-gallon-imperial";
            elsif Token = "energy-joule" or else Token = "joule" then
               return "joule";
            elsif Token = "energy-kilojoule" or else Token = "kilojoule" then
               return "kilojoule";
            elsif Token = "energy-calorie" or else Token = "calorie" then
               return "calorie";
            elsif Token = "energy-kilocalorie" or else Token = "kilocalorie" then
               return "kilocalorie";
            elsif Token = "energy-kilowatt-hour"
              or else Token = "kilowatt-hour"
            then
               return "kilowatt-hour";
            elsif Token = "energy-electronvolt"
              or else Token = "electronvolt"
            then
               return "electronvolt";
            elsif Token = "energy-british-thermal-unit"
              or else Token = "british-thermal-unit"
            then
               return "british-thermal-unit";
            elsif Token = "energy-therm-us"
              or else Token = "therm-us"
            then
               return "therm-us";
            elsif Token = "power-watt" or else Token = "watt" then
               return "watt";
            elsif Token = "power-kilowatt" or else Token = "kilowatt" then
               return "kilowatt";
            elsif Token = "power-horsepower"
              or else Token = "horsepower"
            then
               return "horsepower";
            elsif Token = "frequency-hertz" or else Token = "hertz" then
               return "hertz";
            elsif Token = "frequency-kilohertz" or else Token = "kilohertz" then
               return "kilohertz";
            elsif Token = "frequency-megahertz" or else Token = "megahertz" then
               return "megahertz";
            elsif Token = "pressure-hectopascal"
              or else Token = "hectopascal"
            then
               return "hectopascal";
            elsif Token = "pressure-pascal" or else Token = "pascal" then
               return "pascal";
            elsif Token = "pressure-kilopascal" or else Token = "kilopascal" then
               return "kilopascal";
            elsif Token = "pressure-millibar" or else Token = "millibar" then
               return "millibar";
            elsif Token = "pressure-bar" or else Token = "bar" then
               return "bar";
            elsif Token = "pressure-atmosphere" or else Token = "atmosphere" then
               return "atmosphere";
            elsif Token = "pressure-inch-ofhg" or else Token = "inch-ofhg" then
               return "inch-ofhg";
            elsif Token = "pressure-millimeter-ofhg"
              or else Token = "millimeter-ofhg"
            then
               return "millimeter-ofhg";
            elsif Token = "pressure-pound-force-per-square-inch"
              or else Token = "pound-force-per-square-inch"
            then
               return "pound-force-per-square-inch";
            elsif Token = "electric-ampere" or else Token = "ampere" then
               return "ampere";
            elsif Token = "electric-milliampere"
              or else Token = "milliampere"
            then
               return "milliampere";
            elsif Token = "electric-volt" or else Token = "volt" then
               return "volt";
            elsif Token = "electric-millivolt"
              or else Token = "millivolt"
            then
               return "millivolt";
            elsif Token = "electric-ohm" or else Token = "ohm" then
               return "ohm";
            elsif Token = "light-lumen" or else Token = "lumen" then
               return "lumen";
            elsif Token = "light-lux" or else Token = "lux" then
               return "lux";
            elsif Token = "light-candela" or else Token = "candela" then
               return "candela";
            elsif Token = "light-solar-luminosity"
              or else Token = "solar-luminosity"
            then
               return "solar-luminosity";
            elsif Token = "concentr-percent" or else Token = "percent" then
               return "percent";
            elsif Token = "concentr-permille" or else Token = "permille" then
               return "permille";
            elsif Token = "concentr-permillion"
              or else Token = "permillion"
            then
               return "permillion";
            elsif Token = "concentr-portion" or else Token = "portion" then
               return "portion";
            elsif Token = "concentr-karat" or else Token = "karat" then
               return "karat";
            else
               return "";
            end if;
         end Normalize_Unit;

         function Apply_Token (Token : String) return Boolean is
         begin
            if Token = "unit-width-full-name"
              or else Token = "unit-width/full-name"
              or else Token = "unit-width-long"
              or else Token = "unit-width/long"
              or else Token = "full-name"
            then
               Width := To_Unbounded_String ("unit-width-full-name");
            elsif Token = "unit-width-short"
              or else Token = "unit-width/short"
              or else Token = "short"
            then
               Width := To_Unbounded_String ("unit-width-short");
            elsif Token = "unit-width-narrow"
              or else Token = "unit-width/narrow"
              or else Token = "narrow"
            then
               Width := To_Unbounded_String ("unit-width-narrow");
            elsif Token'Length > 17
              and then Token (Token'First .. Token'First + 16)
                = "per-measure-unit/"
            then
               declare
                  Unit_Text : constant String :=
                    Normalize_Unit (Token (Token'First + 17 .. Token'Last));
               begin
                  if Unit_Text = "" or else Length (Per_Unit) > 0 then
                     return False;
                  end if;

                  Per_Unit := To_Unbounded_String (Unit_Text);
               end;
            else
               return False;
            end if;

            return True;
         end Apply_Token;
      begin
         Last := 0;

         if Style'Length < Prefix'Length + 1
           or else Style (Style'First .. Style'First + Prefix'Length - 1)
             /= Prefix
         then
            return False;
         end if;

         Unit_Start := Style'First + Prefix'Length;
         Unit_End := Unit_Start;
         while Unit_End <= Style'Last
           and then Style (Unit_End) /= ' '
         loop
            Unit_End := Unit_End + 1;
         end loop;

         declare
            Unit : constant String :=
              Normalize_Unit (Style (Unit_Start .. Unit_End - 1));
         begin
            if Unit = "" then
               return False;
            end if;

            Pos := Unit_End;
            while Pos <= Style'Last loop
               while Pos <= Style'Last and then Style (Pos) = ' ' loop
                  Pos := Pos + 1;
               end loop;

               exit when Pos > Style'Last;

               Token_End := Pos;
               while Token_End <= Style'Last
                 and then Style (Token_End) /= ' '
               loop
                  Token_End := Token_End + 1;
               end loop;

               if not Apply_Token (Style (Pos .. Token_End - 1)) then
                  return False;
               end if;

               Pos := Token_End;
            end loop;

            declare
               Text : constant String :=
                 Unit & "/" & To_String (Width)
                 & (if Length (Per_Unit) = 0
                    then ""
                    else "/" & To_String (Per_Unit));
            begin
               if Text'Length > Target'Length
                 or else not I18N.Extra_Format.Is_Valid_Option
                   (I18N.Extra_Format.Unit, Text)
               then
                  return False;
               end if;

               Target (Target'First .. Target'First + Text'Length - 1) :=
                 Text;
               Last := Text'Length;
            end;
         end;

         return True;
      end Unit_Style_From_Skeleton;
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after number keyword");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after number keyword";
      end if;

      Pos := Pos + 1;

      if Option = "" then
         I18N.AST.Append_Number
           (Head => Head,
            Tail => Tail,
            Name => Name);
      elsif Option'Length > 11
        and then Option (Option'First .. Option'First + 10) = "::currency/"
      then
         declare
            Code_And_Option : String (1 .. Option'Length);
            Code_Last       : Natural;
         begin
            if not Currency_Style_From_Skeleton
              (Option, Code_And_Option, Code_Last)
            then
               raise Parse_Error with "Unsupported currency skeleton";
            end if;

            I18N.AST.Append_Currency
              (Head          => Head,
               Tail          => Tail,
               Name          => Name,
               Currency_Code => Code_And_Option (1 .. Code_Last));
         end;
      elsif Option'Length > 15
        and then Option (Option'First .. Option'First + 14)
          = "::measure-unit/"
      then
         declare
            Unit_Option : String (1 .. Option'Length + 32);
            Unit_Last   : Natural;
         begin
            if not Unit_Style_From_Skeleton
              (Option, Unit_Option, Unit_Last)
            then
               raise Parse_Error with "Unsupported measure-unit skeleton";
            end if;

            I18N.AST.Append_Extra_Format
              (Head   => Head,
               Tail   => Tail,
               Kind   => I18N.AST.Unit_Format,
               Name   => Name,
               Option => Unit_Option (1 .. Unit_Last));
         end;
      elsif I18N.Number_Format.Is_Valid_Style (Option) then
         I18N.AST.Append_Number
           (Head  => Head,
            Tail  => Tail,
            Name  => Name,
            Style => Option);
      else
         raise Parse_Error with "Unsupported number skeleton";
      end if;
   end Parse_Number;

   procedure Parse_Date
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Style : constant String := Read_Format_Option (Source, Pos);
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after date keyword");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after date keyword";
      elsif not Is_Date_Time_Style (Style) then
         raise Parse_Error with "Unsupported date style";
      end if;

      Pos := Pos + 1;
      I18N.AST.Append_Date
        (Head => Head,
         Tail => Tail,
         Name => Name,
         Style => Style);
   end Parse_Date;

   procedure Parse_Time
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Style : constant String := Read_Format_Option (Source, Pos);
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after time keyword");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after time keyword";
      elsif not Is_Date_Time_Style (Style) then
         raise Parse_Error with "Unsupported time style";
      end if;

      Pos := Pos + 1;
      I18N.AST.Append_Time
        (Head => Head,
         Tail => Tail,
         Name => Name,
         Style => Style);
   end Parse_Time;

   procedure Parse_Date_Time
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Style : constant String := Read_Format_Option (Source, Pos);
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after datetime keyword");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after datetime keyword";
      elsif not Is_Date_Time_Style (Style) then
         raise Parse_Error with "Unsupported datetime style";
      end if;

      Pos := Pos + 1;
      I18N.AST.Append_Date_Time
        (Head => Head,
         Tail => Tail,
         Name => Name,
         Style => Style);
   end Parse_Date_Time;

   procedure Parse_Currency
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Option : constant String := Read_Format_Option (Source, Pos);
   begin
      if Option = "" then
         raise Parse_Error with "Expected currency code";
      elsif Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after currency code");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after currency code";
      elsif not I18N.Currency.Is_Valid_Code (Option) then
         raise Parse_Error with "Invalid currency code";
      end if;

      Pos := Pos + 1;
      I18N.AST.Append_Currency
        (Head          => Head,
         Tail          => Tail,
         Name          => Name,
         Currency_Code => Option);
   end Parse_Currency;

   procedure Parse_Extra_Format
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Kind   : I18N.AST.Node_Kind;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Option : constant String := Read_Format_Option (Source, Pos);
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Expected '}' after formatter option");
      elsif Source (Pos) /= '}' then
         raise Parse_Error with "Expected '}' after formatter option";
      end if;

      if Kind in I18N.AST.Duration_Format | I18N.AST.Byte_Size_Format
        and then Option /= ""
      then
         raise Parse_Error with "Unsupported formatter option";
      elsif Kind = I18N.AST.List_Format
        and then not I18N.Extra_Format.Is_Valid_Option
                       (I18N.Extra_Format.List, Option)
      then
         raise Parse_Error with "Unsupported formatter option";
      elsif Kind in I18N.AST.Unit_Format | I18N.AST.Relative_Time_Format
        and then Option = ""
      then
         raise Parse_Error with "Expected formatter unit";
      elsif Kind = I18N.AST.Unit_Format
        and then not I18N.Extra_Format.Is_Valid_Option
                       (I18N.Extra_Format.Unit, Option)
      then
         raise Parse_Error with "Unsupported formatter unit";
      elsif Kind = I18N.AST.Relative_Time_Format
        and then not I18N.Extra_Format.Is_Valid_Option
                       (I18N.Extra_Format.Relative_Time, Option)
      then
         raise Parse_Error with "Unsupported formatter unit";
      end if;

      Pos := Pos + 1;
      I18N.AST.Append_Extra_Format
        (Head   => Head,
         Tail   => Tail,
         Kind   => Kind,
         Name   => Name,
         Option => Option);
   end Parse_Extra_Format;

   procedure Parse_Braced
     (Source : String;
      Pos    : in out Positive;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access) is
   begin
      if Pos > Source'Last then
         Raise_Unbalanced_Braces ("Unclosed brace before identifier");
      end if;

      declare
         Name : constant String := Read_Identifier (Source, Pos);
      begin
         if Pos > Source'Last then
            Raise_Unbalanced_Braces ("Unclosed brace after identifier");
         end if;

         --  Keep strict variable syntax for simple variables: {name } is still
         --  malformed. Plural and select selectors may use whitespace before the
         --  comma, which is common in hand-written ICU messages.
         if Is_Whitespace (Source (Pos)) then
            declare
               Delimiter_Pos : Positive := Pos;
            begin
               Skip_Whitespace (Source, Delimiter_Pos);

               if Delimiter_Pos <= Source'Last
                 and then Source (Delimiter_Pos) = ','
               then
                  Pos := Delimiter_Pos;
               end if;
            end;
         end if;

         if Source (Pos) = '}' then
            Pos := Pos + 1;
            I18N.AST.Append_Variable
              (Head => Head, Tail => Tail, Name => Name);
            return;
         elsif Source (Pos) /= ',' then
            raise Parse_Error with "Expected '}' or ',' after identifier";
         end if;

         Pos := Pos + 1;
         Skip_Whitespace (Source, Pos);

         declare
            Keyword : constant String := Read_Identifier (Source, Pos);
         begin
            if Keyword = "plural" then
               Parse_Plural
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "select" then
               Parse_Select
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "selectordinal" then
               Parse_Select_Ordinal
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "number" then
               Parse_Number
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "date" then
               Parse_Date
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "time" then
               Parse_Time
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "datetime" then
               Parse_Date_Time
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "currency" then
               Parse_Currency
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "duration" then
               Parse_Extra_Format
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Kind   => I18N.AST.Duration_Format,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "bytes" then
               Parse_Extra_Format
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Kind   => I18N.AST.Byte_Size_Format,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "unit" then
               Parse_Extra_Format
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Kind   => I18N.AST.Unit_Format,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "relative" then
               Parse_Extra_Format
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Kind   => I18N.AST.Relative_Time_Format,
                  Head   => Head,
                  Tail   => Tail);
            elsif Keyword = "list" then
               Parse_Extra_Format
                 (Source => Source,
                  Pos    => Pos,
                  Name   => Name,
                  Kind   => I18N.AST.List_Format,
                  Head   => Head,
                  Tail   => Tail);
            else
               raise Parse_Error
                 with
                   "Expected plural, select, selectordinal, number, date, "
                   & "time, datetime, currency, duration, bytes, unit, "
                   & "relative, or list keyword after selector";
            end if;
         end;
      end;
   end Parse_Braced;

   function Parse_Sequence
     (Source : String; Pos : in out Positive; Stop_On_Close : Boolean)
      return I18N.AST.Node_Access
   is
      Head         : I18N.AST.Node_Access := null;
      Tail         : I18N.AST.Node_Access := null;
      Pending_Text : Unbounded_String;

      function Has_Explicit_Quote_Close (Start : Positive) return Boolean is
         Index : Natural := Start;
      begin
         while Index <= Source'Last loop
            if Source (Index) = Apostrophe then
               if Index < Source'Last and then Source (Index + 1) = Apostrophe
               then
                  Index := Index + 2;
               else
                  return True;
               end if;
            elsif Stop_On_Close and then Source (Index) = '}' then
               return Index < Source'Last
                 and then Source (Index + 1) = Apostrophe;
            else
               Index := Index + 1;
            end if;
         end loop;

         return False;
      end Has_Explicit_Quote_Close;
   begin
      while Pos <= Source'Last loop
         case Source (Pos) is
            when '{'    =>
               Flush_Text (Head => Head, Tail => Tail, Text => Pending_Text);

               Pos := Pos + 1;
               Parse_Braced
                 (Source => Source, Pos => Pos, Head => Head, Tail => Tail);

            when '}'    =>
               if Stop_On_Close then
                  Flush_Text
                    (Head => Head, Tail => Tail, Text => Pending_Text);
                  return Head;
               else
                  I18N.AST.Free (Head);
                  Raise_Unbalanced_Braces ("Unmatched '}'");
               end if;

            when Apostrophe =>
               if Pos < Source'Last
                 and then Source (Pos + 1) = Apostrophe
               then
                  Append (Source => Pending_Text, New_Item => Apostrophe);
                  Pos := Pos + 2;
               elsif Pos < Source'Last
                 and then Is_Quote_Syntax_Character (Source (Pos + 1))
               then
                  Pos := Pos + 1;

                  declare
                     Explicit_Close : constant Boolean :=
                       Has_Explicit_Quote_Close (Pos);
                  begin
                     while Pos <= Source'Last loop
                        if Source (Pos) = Apostrophe then
                           if Pos < Source'Last
                             and then Source (Pos + 1) = Apostrophe
                           then
                              Append
                                (Source   => Pending_Text,
                                 New_Item => Apostrophe);
                              Pos := Pos + 2;
                           else
                              Pos := Pos + 1;
                              exit;
                           end if;
                        elsif Stop_On_Close
                          and then Source (Pos) = '}'
                          and then not Explicit_Close
                        then
                           --  ICU-style apostrophe quoting permits an
                           --  unterminated quoted span to end with the current
                           --  branch/message. Leave the closing brace for the
                           --  enclosing branch parser instead of consuming it
                           --  as literal quoted text.
                           exit;
                        else
                           Append_Quoted_Character
                             (Text => Pending_Text, C => Source (Pos));
                           Pos := Pos + 1;
                        end if;
                     end loop;
                  end;
               else
                  Append (Source => Pending_Text, New_Item => Apostrophe);
                  Pos := Pos + 1;
               end if;

            when others =>
               Append (Source => Pending_Text, New_Item => Source (Pos));
               Pos := Pos + 1;
         end case;
      end loop;

      if Stop_On_Close then
         I18N.AST.Free (Head);
         Raise_Unbalanced_Braces ("Unclosed branch");
      end if;

      Flush_Text (Head => Head, Tail => Tail, Text => Pending_Text);

      return Head;
   exception
      when others =>
         I18N.AST.Free (Head);
         raise;
   end Parse_Sequence;

   function Parse (Source : String) return I18N.AST.Node_Access is
      Pos  : Positive := Source'First;
      Root : I18N.AST.Node_Access := null;
   begin
      if Source'Length = 0 then
         return null;
      end if;

      Root :=
        Parse_Sequence (Source => Source, Pos => Pos, Stop_On_Close => False);

      return Root;
   exception
      when others =>
         I18N.AST.Free (Root);
         raise;
   end Parse;

end I18N.Parser;
