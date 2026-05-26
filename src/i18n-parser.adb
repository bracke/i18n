with I18N.AST; use I18N.AST;
with Ada.Strings.Unbounded;

package body I18N.Parser is

   use Ada.Strings.Unbounded;

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
           One          => null,
           Other        => null,
           Male         => null,
           Female       => null,
           Select_Other => null,
           Ord_One      => null,
           Ord_Two      => null,
           Ord_Few      => null,
           Ord_Other    => null,
           Next         => null);
   end Empty_Branch_AST;

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
         raise Parse_Error with "Unclosed branch message";
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
      One_Branch   : I18N.AST.Node_Access := null;
      Other_Branch : I18N.AST.Node_Access := null;
      Have_One     : Boolean := False;
      Have_Other   : Boolean := False;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' after plural keyword";
      end if;

      Pos := Pos + 1;

      loop
         Skip_Whitespace (Source, Pos);

         if Pos > Source'Last then
            raise Parse_Error with "Unclosed plural block";
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            Branch_Name : constant String := Read_Identifier (Source, Pos);
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if Branch_Name /= "one" and then Branch_Name /= "other" then
               raise Parse_Error with "Expected one or other plural branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            if Branch_Name = "one" then
               if Have_One then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate one plural branch";
               end if;

               One_Branch := Branch_AST;
               Have_One := True;
            else
               if Have_Other then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate other plural branch";
               end if;

               Other_Branch := Branch_AST;
               Have_Other := True;
            end if;
         end;
      end loop;

      --  The parser leaves branch-completeness decisions to the validator so
      --  malformed grammar and incomplete validated ASTs receive distinct
      --  deterministic errors.
      Pos := Pos + 1;

      I18N.AST.Append_Plural
        (Head  => Head,
         Tail  => Tail,
         Name  => Name,
         One   => One_Branch,
         Other => Other_Branch);
   exception
      when others =>
         I18N.AST.Free (One_Branch);
         I18N.AST.Free (Other_Branch);
         raise;
   end Parse_Plural;

   procedure Parse_Select
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      Male_Branch   : I18N.AST.Node_Access := null;
      Female_Branch : I18N.AST.Node_Access := null;
      Other_Branch  : I18N.AST.Node_Access := null;
      Have_Male     : Boolean := False;
      Have_Female   : Boolean := False;
      Have_Other    : Boolean := False;
   begin
      Skip_Whitespace (Source, Pos);

      if Pos > Source'Last or else Source (Pos) /= ',' then
         raise Parse_Error with "Expected ',' after select keyword";
      end if;

      Pos := Pos + 1;

      loop
         Skip_Whitespace (Source, Pos);

         if Pos > Source'Last then
            raise Parse_Error with "Unclosed select block";
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            Branch_Name : constant String := Read_Identifier (Source, Pos);
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if Branch_Name /= "male"
              and then Branch_Name /= "female"
              and then Branch_Name /= "other"
            then
               raise Parse_Error
                 with "Expected male, female, or other select branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            if Branch_Name = "male" then
               if Have_Male then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate male select branch";
               end if;

               Male_Branch := Branch_AST;
               Have_Male := True;
            elsif Branch_Name = "female" then
               if Have_Female then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate female select branch";
               end if;

               Female_Branch := Branch_AST;
               Have_Female := True;
            else
               if Have_Other then
                  I18N.AST.Free (Branch_AST);
                  raise Parse_Error with "Duplicate other select branch";
               end if;

               Other_Branch := Branch_AST;
               Have_Other := True;
            end if;

         end;
      end loop;

      --  Validation enforces mandatory fallback branches after parsing.
      Pos := Pos + 1;

      I18N.AST.Append_Select
        (Head   => Head,
         Tail   => Tail,
         Name   => Name,
         Male   => Male_Branch,
         Female => Female_Branch,
         Other  => Other_Branch);
   exception
      when others =>
         I18N.AST.Free (Male_Branch);
         I18N.AST.Free (Female_Branch);
         I18N.AST.Free (Other_Branch);
         raise;
   end Parse_Select;

   procedure Parse_Select_Ordinal
     (Source : String;
      Pos    : in out Positive;
      Name   : String;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access)
   is
      One_Branch   : I18N.AST.Node_Access := null;
      Two_Branch   : I18N.AST.Node_Access := null;
      Few_Branch   : I18N.AST.Node_Access := null;
      Other_Branch : I18N.AST.Node_Access := null;
      Have_One     : Boolean := False;
      Have_Two     : Boolean := False;
      Have_Few     : Boolean := False;
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
            raise Parse_Error with "Unclosed selectordinal block";
         elsif Source (Pos) = '}' then
            exit;
         end if;

         declare
            Branch_Name : constant String := Read_Identifier (Source, Pos);
            Branch_AST  : I18N.AST.Node_Access := null;
         begin
            if Branch_Name /= "one"
              and then Branch_Name /= "two"
              and then Branch_Name /= "few"
              and then Branch_Name /= "other"
            then
               raise Parse_Error
                 with "Expected one, two, few, or other selectordinal branch";
            end if;

            Branch_AST := Parse_Branch_Message (Source => Source, Pos => Pos);

            if Branch_Name = "one" then
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
         One   => One_Branch,
         Two   => Two_Branch,
         Few   => Few_Branch,
         Other => Other_Branch);
   exception
      when others =>
         I18N.AST.Free (One_Branch);
         I18N.AST.Free (Two_Branch);
         I18N.AST.Free (Few_Branch);
         I18N.AST.Free (Other_Branch);
         raise;
   end Parse_Select_Ordinal;

   procedure Parse_Braced
     (Source : String;
      Pos    : in out Positive;
      Head   : in out I18N.AST.Node_Access;
      Tail   : in out I18N.AST.Node_Access) is
   begin
      if Pos > Source'Last then
         raise Parse_Error with "Unclosed brace before identifier";
      end if;

      declare
         Name : constant String := Read_Identifier (Source, Pos);
      begin
         if Pos > Source'Last then
            raise Parse_Error with "Unclosed brace after identifier";
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
            else
               raise Parse_Error
                 with
                   "Expected plural, select, or selectordinal keyword after selector";
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
                  raise Parse_Error with "Unmatched '}'";
               end if;

            when others =>
               Append (Source => Pending_Text, New_Item => Source (Pos));
               Pos := Pos + 1;
         end case;
      end loop;

      if Stop_On_Close then
         I18N.AST.Free (Head);
         raise Parse_Error with "Unclosed branch";
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
