with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with I18N.AST; use I18N.AST;
with I18N.Currency;
with I18N.Date_Time_Format;
with I18N.Extra_Format;
with I18N.Number_Format;
with I18N.Result; use I18N.Result;
with I18N.Parser;
with I18N.Observability;
with I18N.Plurals;
with I18N.Runtime_Data;
with I18N.Validation;

package body I18N.Runtime is

   Escaped_Number_Sign : constant Character := Character'Val (1);

   use type I18N.Plurals.Plural_Category;

   ---------------------------------------------------------------------------
   --  Small text helpers (catalog line parsing).
   ---------------------------------------------------------------------------

   function Trimmed (Text : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Trimmed;

   function Unquote (Text : String) return String is
      T : constant String := Trimmed (Text);
   begin
      if T'Length >= 2 and then T (T'First) = '"' and then T (T'Last) = '"'
      then
         --  Strip enclosing quotes repeatedly so a value already normalized once
         --  stays stable and does not render spurious literal quote characters.
         return Unquote (T (T'First + 1 .. T'Last - 1));
      end if;

      return T;
   end Unquote;

   function Canonical_Locale (Text : String) return String is
   begin
      return I18N.Locales.Canonicalize (Text);
   end Canonical_Locale;

   function Dot_Index (Text : String) return Natural is
   begin
      for Index in Text'Range loop
         if Text (Index) = '.' then
            return Index;
         end if;
      end loop;
      return 0;
   end Dot_Index;

   function Equals_Index (Text : String) return Natural is
   begin
      for Index in Text'Range loop
         if Text (Index) = '=' then
            return Index;
         end if;
      end loop;
      return 0;
   end Equals_Index;

   --  Composite index key: Locale & NUL & Key. NUL cannot appear in a locale or
   --  key, so the join is unambiguous.
   function Composite (Locale : String; Key : String) return String is
   begin
      return Locale & Character'Val (0) & Key;
   end Composite;

   --  Render a " at line N" suffix for diagnostics (empty when Line is 0).
   function Line_Suffix (Line : Natural) return String is
   begin
      if Line = 0 then
         return "";
      end if;
      --  Natural'Image carries a leading space, so this reads " at line 5".
      return " at line" & Natural'Image (Line);
   end Line_Suffix;

   ---------------------------------------------------------------------------
   --  Line readers.
   ---------------------------------------------------------------------------

   package Line_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Unbounded_String);

   procedure Read_File_Lines
     (Path  : String;
      Found : out Boolean;
      Lines : out Line_Vectors.Vector)
   is
      File : Ada.Text_IO.File_Type;
   begin
      Lines.Clear;
      Found := False;

      if not Ada.Directories.Exists (Path) then
         return;
      elsif Ada.Directories."/="
              (Ada.Directories.Kind (Path),
               Ada.Directories.Ordinary_File)
      then
         return;
      end if;

      Ada.Text_IO.Open
        (File => File, Mode => Ada.Text_IO.In_File, Name => Path);

      while not Ada.Text_IO.End_Of_File (File) loop
         Lines.Append (To_Unbounded_String (Ada.Text_IO.Get_Line (File)));
      end loop;

      Ada.Text_IO.Close (File);
      Found := True;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         Lines.Clear;
         Found := False;
   end Read_File_Lines;

   function Split_Text_Lines (Text : String) return Line_Vectors.Vector is
      Lines   : Line_Vectors.Vector;
      Current : Unbounded_String;

      procedure Flush is
         S : constant String := To_String (Current);
      begin
         --  Drop a trailing carriage return so CRLF input matches LF input.
         if S'Length > 0 and then S (S'Last) = Character'Val (13) then
            Lines.Append (To_Unbounded_String (S (S'First .. S'Last - 1)));
         else
            Lines.Append (Current);
         end if;
         Current := Null_Unbounded_String;
      end Flush;

   begin
      for C of Text loop
         if C = Character'Val (10) then
            Flush;
         else
            Append (Current, C);
         end if;
      end loop;

      if Length (Current) > 0 then
         Flush;
      end if;

      return Lines;
   end Split_Text_Lines;

   procedure Add_Load_Diagnostic
     (Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Kind        : I18N.Diagnostics.Diagnostic_Kind;
      Message     : String := "";
      Key         : String := "");

   function Decode_Binary_Catalog
     (Lines       : Line_Vectors.Vector;
      Source_Name : String;
      Payload     : out Line_Vectors.Vector;
      Diagnostics : in out I18N.Diagnostics.Diagnostic_List)
      return Boolean
   is
      Header_Count : constant Natural := 5;

      function Hex_Value (Item : Character) return Integer is
      begin
         if Item in '0' .. '9' then
            return Character'Pos (Item) - Character'Pos ('0');
         elsif Item in 'A' .. 'F' then
            return 10 + Character'Pos (Item) - Character'Pos ('A');
         elsif Item in 'a' .. 'f' then
            return 10 + Character'Pos (Item) - Character'Pos ('a');
         else
            return -1;
         end if;
      end Hex_Value;

      function Decode_Hex_Payload (Text : String) return String is
         Result : String (1 .. Text'Length / 2);
         Out_Pos : Natural := 0;
      begin
         if Text'Length = 0 or else Text'Length mod 2 /= 0 then
            return "";
         end if;

         for Index in 0 .. (Text'Length / 2) - 1 loop
            declare
               High : constant Integer :=
                 Hex_Value (Text (Text'First + Index * 2));
               Low  : constant Integer :=
                 Hex_Value (Text (Text'First + Index * 2 + 1));
            begin
               if High < 0 or else Low < 0 then
                  return "";
               end if;

               Out_Pos := Out_Pos + 1;
               Result (Out_Pos) :=
                 Character'Val (High * 16 + Low);
            end;
         end loop;

         return Result;
      end Decode_Hex_Payload;
   begin
      Payload.Clear;

      if Natural (Lines.Length) < Header_Count then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Parse_Error,
            "binary catalog header is incomplete in " & Source_Name, "");
         return False;
      end if;

      if To_String (Lines.Element (0)) /= "I18N-CATALOG-BINARY" then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Parse_Error,
            "invalid binary catalog magic in " & Source_Name, "");
         return False;
      elsif Trimmed (To_String (Lines.Element (1))) /= "format_version=1" then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Validation_Error,
            "unsupported binary catalog format version in " & Source_Name,
            To_String (Lines.Element (1)));
         return False;
      elsif Trimmed (To_String (Lines.Element (2))) /= "ir_version=1" then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Validation_Error,
            "unsupported binary catalog IR version in " & Source_Name,
            To_String (Lines.Element (2)));
         return False;
      elsif Trimmed (To_String (Lines.Element (3))) /= "payload=text"
        and then Trimmed (To_String (Lines.Element (3))) /= "payload=hex-text"
      then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Validation_Error,
            "unsupported binary catalog payload kind in " & Source_Name,
            To_String (Lines.Element (3)));
         return False;
      elsif Trimmed (To_String (Lines.Element (4))) /= "" then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Parse_Error,
            "binary catalog header must end with a blank line in "
            & Source_Name,
            To_String (Lines.Element (4)));
         return False;
      end if;

      if Natural (Lines.Length) = Header_Count then
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Validation_Error,
            "binary catalog payload is empty in " & Source_Name, "");
         return False;
      end if;

      if Trimmed (To_String (Lines.Element (3))) = "payload=hex-text" then
         declare
            Hex_Text : Unbounded_String;
         begin
            for Index in 5 .. Lines.Last_Index loop
               Append (Hex_Text, Trimmed (To_String (Lines.Element (Index))));
            end loop;

            declare
               Decoded : constant String :=
                 Decode_Hex_Payload (To_String (Hex_Text));
            begin
               if Decoded'Length = 0 then
                  Add_Load_Diagnostic
                    (Diagnostics, I18N.Diagnostics.Validation_Error,
                     "invalid hex-text binary catalog payload in "
                     & Source_Name,
                     "");
                  return False;
               end if;

               Payload := Split_Text_Lines (Decoded);
            end;
         end;
      else
         for Index in 5 .. Lines.Last_Index loop
            Payload.Append (Lines.Element (Index));
         end loop;
      end if;

      return True;
   exception
      when others =>
         Payload.Clear;
         Add_Load_Diagnostic
           (Diagnostics, I18N.Diagnostics.Parse_Error,
            "invalid binary catalog envelope in " & Source_Name, "");
         return False;
   end Decode_Binary_Catalog;

   ---------------------------------------------------------------------------
   --  Message compilation (parse + validate once at load time).
   ---------------------------------------------------------------------------

   procedure Compile_One
     (Source : String;
      Root   : out I18N.AST.Node_Access;
      Ok     : out Boolean;
      Error  : out I18N.Errors.Error_Kind)
   is
      Parsed : I18N.AST.Node_Access := null;
   begin
      Root := null;

      begin
         Parsed := I18N.Parser.Parse (Source);
      exception
         when I18N.Parser.Unbalanced_Braces =>
            I18N.AST.Free (Parsed);
            Ok := False;
            Error := I18N.Errors.Unbalanced_Braces;
            return;
         when I18N.Parser.Parse_Error =>
            I18N.AST.Free (Parsed);
            Ok := False;
            Error := I18N.Errors.Parse_Error;
            return;
         when others =>
            I18N.AST.Free (Parsed);
            Ok := False;
            Error := I18N.Errors.Parse_Error;
            return;
      end;

      declare
         Validation_Result : constant I18N.Errors.Result :=
           I18N.Validation.Validate (Parsed);
      begin
         if not Validation_Result.Ok then
            I18N.AST.Free (Parsed);
            Ok := False;
            Error := Validation_Result.Error;
            return;
         end if;
      end;

      Root := Parsed;
      Ok := True;
      Error := I18N.Errors.Parse_Error;
   end Compile_One;

   ---------------------------------------------------------------------------
   --  Staging (transactional ingest support).
   ---------------------------------------------------------------------------

   type Staged_Entry is record
      Locale : Unbounded_String;
      Key    : Unbounded_String;
      Source : Unbounded_String;
      Line   : Natural := 0;
      Root   : I18N.AST.Node_Access := null;
   end record;

   package Staged_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Staged_Entry);

   procedure Free_Staged (Staged : in out Staged_Vectors.Vector) is
   begin
      for I in Staged.First_Index .. Staged.Last_Index loop
         declare
            E : Staged_Entry := Staged.Element (I);
         begin
            if E.Root /= null then
               I18N.AST.Free (E.Root);
               E.Root := null;
               Staged.Replace_Element (I, E);
            end if;
         end;
      end loop;
      Staged.Clear;
   end Free_Staged;

   --  Add a diagnostic for a load/validation failure.
   procedure Add_Load_Diagnostic
     (Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Kind        : I18N.Diagnostics.Diagnostic_Kind;
      Message     : String := "";
      Key         : String := "")
   is
   begin
      I18N.Diagnostics.Add
        (List => Diagnostics, Kind => Kind, Message => Message, Key => Key);
   end Add_Load_Diagnostic;

   --  A valid locale prefix is a BCP-47-style sequence of alphanumeric subtags
   --  separated by single hyphens, with no leading, trailing, or empty subtag.
   function Is_Valid_Locale (Text : String) return Boolean is
      After_Hyphen : Boolean := True;  --  start state rejects a leading hyphen
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if C = '-' then
            if After_Hyphen then
               return False;  --  leading hyphen or empty subtag ("--")
            end if;
            After_Hyphen := True;
         elsif C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' then
            After_Hyphen := False;
         else
            return False;
         end if;
      end loop;

      return not After_Hyphen;  --  reject a trailing hyphen
   end Is_Valid_Locale;

   --  Locale-like values accepted for `default_locale` directives. This form
   --  accepts underscores as separators while preserving the same empty-subtag
   --  rule as `Is_Valid_Locale`; canonicalization handles case normalization.
   function Is_Valid_Default_Locale (Text : String) return Boolean is
      After_Separator : Boolean := True;  --  start state rejects a leading sep
   begin
      if Text'Length = 0 then
         return False;
      end if;

      for C of Text loop
         if C = '-' or else C = '_' then
            if After_Separator then
               return False;  --  leading separator or empty subtag
            end if;
            After_Separator := True;
         elsif C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' then
            After_Separator := False;
         else
            return False;
         end if;
      end loop;

      return not After_Separator;  --  reject a trailing separator
   end Is_Valid_Default_Locale;

   --  Extract and validate a default-locale directive from catalog lines.
   procedure Analyze_Default_Locale
     (Lines         : Line_Vectors.Vector;
      Has_Default   : out Boolean;
      Value         : out Unbounded_String;
      Duplicate     : out Boolean;
      Invalid       : out Boolean;
      Invalid_Tag   : out Unbounded_String;
      Invalid_Line  : out Natural;
      Duplicate_Line : out Natural)
   is
      First_Default : Boolean := True;
   begin
      Has_Default := False;
      Duplicate := False;
      Invalid := False;
      Value := Null_Unbounded_String;
      Invalid_Tag := Null_Unbounded_String;
      Invalid_Line := 0;
      Duplicate_Line := 0;

      for Index in Lines.First_Index .. Lines.Last_Index loop
         declare
            Raw      : constant Unbounded_String := Lines.Element (Index);
            Clean    : constant String := Trimmed (To_String (Raw));
            Line_No  : constant Natural := Index + 1;
         begin
            if Clean'Length > 0 and then Clean (Clean'First) /= '#' then
               declare
                  Eq : constant Natural := Equals_Index (Clean);
               begin
                  if Eq /= 0 and then Eq /= Clean'First then
                     declare
                        Name : constant String :=
                          Trimmed (Clean (Clean'First .. Eq - 1));
                        Value_Text : constant String :=
                          (if Eq = Clean'Last
                           then ""
                           else Unquote (Clean (Eq + 1 .. Clean'Last)));
                     begin
                        if Name = "default_locale" then
                           if First_Default then
                              First_Default := False;
                              Has_Default := True;

                              if not Is_Valid_Default_Locale (Value_Text) then
                                 Invalid := True;
                                 Invalid_Tag := To_Unbounded_String (Value_Text);
                                 Invalid_Line := Line_No;
                              else
                                 declare
                                    Canonical : constant String :=
                                      Canonical_Locale (Value_Text);
                                 begin
                                    if not Is_Valid_Locale (Canonical) then
                                       Invalid := True;
                                       Invalid_Tag :=
                                         To_Unbounded_String (Value_Text);
                                       Invalid_Line := Line_No;
                                    else
                                       Value := To_Unbounded_String (Canonical);
                                    end if;
                                 end;
                              end if;
                           else
                              Duplicate := True;
                              if Duplicate_Line = 0 then
                                 Duplicate_Line := Line_No;
                              end if;
                           end if;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Analyze_Default_Locale;

   --  A valid key is a non-empty run of identifier characters and dots, with no
   --  leading or trailing dot. Dots are allowed so dotted keys such as
   --  "cart.items" remain valid (the locale/key split uses only the first dot).
   function Is_Valid_Key (Text : String) return Boolean is
   begin
      if Text'Length = 0
        or else Text (Text'First) = '.'
        or else Text (Text'Last) = '.'
      then
         return False;
      end if;

      for C of Text loop
         if C not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '-' | '.' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Key;

   --  Parse every catalog line into staged entries. The runtime is not touched.
   --  default_locale directives are ignored here; unqualified keys bind to
   --  Default_Locale. On any malformed line or invalid ICU message, Ok is False,
   --  Error classifies the failure, and all staged roots are released.
   procedure Stage_Lines
     (Lines          : Line_Vectors.Vector;
      Default_Locale : String;
      Source_Name    : String;
      Staged         : out Staged_Vectors.Vector;
      Ok             : out Boolean;
      Error          : out I18N.Errors.Error_Kind;
      Diagnostics    : in out I18N.Diagnostics.Diagnostic_List)
   is
   begin
      Staged.Clear;
      Ok := True;
      Error := I18N.Errors.Parse_Error;

      for Idx in Lines.First_Index .. Lines.Last_Index loop
         declare
            Line_No : constant Positive := Idx + 1;
            Clean   : constant String :=
              Trimmed (To_String (Lines.Element (Idx)));
         begin
            if Clean'Length = 0 or else Clean (Clean'First) = '#' then
               null;  --  blank or comment line
            else
               declare
                  Eq : constant Natural := Equals_Index (Clean);
               begin
                  if Eq = 0 or else Eq = Clean'First then
                     Add_Load_Diagnostic
                       (Diagnostics, I18N.Diagnostics.Parse_Error,
                        "missing '=' separator in " & Source_Name
                        & Line_Suffix (Line_No),
                        Clean);
                     Free_Staged (Staged);
                     Ok := False;
                     Error := I18N.Errors.Parse_Error;
                     return;
                  end if;

                  declare
                     Name  : constant String :=
                       Trimmed (Clean (Clean'First .. Eq - 1));
                     Value : constant String :=
                       (if Eq = Clean'Last
                        then ""
                        else Unquote (Clean (Eq + 1 .. Clean'Last)));
                     Dot   : constant Natural := Dot_Index (Name);
                  begin
                     if Name = "default_locale" then
                        null;  --  honored only by Initialize
                     else
                        declare
                           Locale : Unbounded_String;
                           Key    : Unbounded_String;
                           Valid_Split : Boolean := True;
                        begin
                           if Dot = 0 then
                              Locale :=
                                To_Unbounded_String
                                  (Canonical_Locale (Default_Locale));
                              Key := To_Unbounded_String (Name);
                           elsif Dot = Name'First or else Dot = Name'Last then
                              Valid_Split := False;
                           else
                              Locale :=
                                To_Unbounded_String
                                  (Name (Name'First .. Dot - 1));
                              Key :=
                                To_Unbounded_String
                                  (Name (Dot + 1 .. Name'Last));
                           end if;

                           if not Valid_Split
                             or else Length (Locale) = 0
                             or else Length (Key) = 0
                             or else not Is_Valid_Locale (To_String (Locale))
                             or else not Is_Valid_Key (To_String (Key))
                           then
                              Add_Load_Diagnostic
                                (Diagnostics,
                                 I18N.Diagnostics.Validation_Error,
                                 "invalid locale prefix or key in "
                                 & Source_Name & Line_Suffix (Line_No),
                                 Name);
                              Free_Staged (Staged);
                              Ok := False;
                              Error := I18N.Errors.Validation_Error;
                              return;
                           end if;

                           Locale :=
                             To_Unbounded_String
                               (Canonical_Locale (To_String (Locale)));

                           declare
                              Root      : I18N.AST.Node_Access := null;
                              Msg_Ok    : Boolean;
                              Msg_Error : I18N.Errors.Error_Kind;
                           begin
                              Compile_One (Value, Root, Msg_Ok, Msg_Error);
                              if not Msg_Ok then
                                 Add_Load_Diagnostic
                                   (Diagnostics,
                                    I18N.Errors.To_Diagnostic_Kind (Msg_Error),
                                    "invalid ICU message in " & Source_Name
                                    & Line_Suffix (Line_No),
                                    To_String (Key));
                                 Free_Staged (Staged);
                                 Ok := False;
                                 Error := Msg_Error;
                                 return;
                              end if;

                              Staged.Append
                                (Staged_Entry'
                                   (Locale => Locale,
                                    Key    => Key,
                                    Source => To_Unbounded_String (Value),
                                    Line   => Line_No,
                                    Root   => Root));
                           end;
                        end;
                     end if;
                  end;
               end;
            end if;
         end;
      end loop;
   end Stage_Lines;

   --  Append one committed entry to the runtime and index it.
   procedure Commit_Append
     (Item   : in out Runtime;
      Locale : Unbounded_String;
      Key    : Unbounded_String;
      Source : Unbounded_String;
      Root   : I18N.AST.Node_Access)
   is
   begin
      Item.Catalog.Append
        (Catalog_Entry'
           (Locale      => Locale,
            Message_Key => Key,
            Source      => Source,
            Root        => Root));
      Item.Index.Insert
        (Composite (To_String (Locale), To_String (Key)),
         Item.Catalog.Last_Index);
   end Commit_Append;

   --  Replace an existing entry in place, releasing the previous compiled AST.
   procedure Commit_Override
     (Item  : in out Runtime;
      Idx   : Natural;
      Source : Unbounded_String;
      Root  : I18N.AST.Node_Access)
   is
      Existing : Catalog_Entry := Item.Catalog.Element (Idx);
   begin
      if Existing.Root /= null then
         I18N.AST.Free (Existing.Root);
      end if;
      Existing.Source := Source;
      Existing.Root := Root;
      Item.Catalog.Replace_Element (Idx, Existing);
   end Commit_Override;

   --  Apply staged entries to the runtime under Policy. Transactional for
   --  Reject_Duplicates: a duplicate aborts before any mutation. Apply takes
   --  ownership of every staged root (committed roots are transferred, skipped
   --  roots are released), so callers may always call Free_Staged afterwards.
   procedure Apply_Staged
     (Item     : in out Runtime;
      Staged   : in out Staged_Vectors.Vector;
      Policy   : Duplicate_Policy;
      Status   : out Load_Status;
      Added    : out Natural;
      Replaced : out Natural;
      Ignored  : out Natural)
   is
   begin
      Added := 0;
      Replaced := 0;
      Ignored := 0;
      Status := Loaded;

      if Policy = Reject_Duplicates then
         --  Pre-check: any collision (with existing entries or within the input)
         --  aborts without mutating the runtime.
         declare
            Seen : Index_Maps.Map;
         begin
            for E of Staged loop
               declare
                  Comp : constant String :=
                    Composite (To_String (E.Locale), To_String (E.Key));
               begin
                  if Item.Index.Contains (Comp) or else Seen.Contains (Comp)
                  then
                     Status := Duplicate_Rejected;
                     return;
                  end if;
                  Seen.Insert (Comp, 0);
               end;
            end loop;
         end;
      end if;

      for I in Staged.First_Index .. Staged.Last_Index loop
         declare
            E    : Staged_Entry := Staged.Element (I);
            Comp : constant String :=
              Composite (To_String (E.Locale), To_String (E.Key));
            Exists : constant Boolean := Item.Index.Contains (Comp);
         begin
            case Policy is
               when Reject_Duplicates =>
                  Commit_Append (Item, E.Locale, E.Key, E.Source, E.Root);
                  Added := Added + 1;
                  E.Root := null;

               when Keep_First =>
                  if Exists then
                     I18N.AST.Free (E.Root);
                     E.Root := null;
                     Ignored := Ignored + 1;
                  else
                     Commit_Append (Item, E.Locale, E.Key, E.Source, E.Root);
                     Added := Added + 1;
                     E.Root := null;
                  end if;

               when Override_Previous =>
                  if Exists then
                     Commit_Override
                       (Item, Item.Index.Element (Comp), E.Source, E.Root);
                     Replaced := Replaced + 1;
                  else
                     Commit_Append (Item, E.Locale, E.Key, E.Source, E.Root);
                     Added := Added + 1;
                  end if;
                  E.Root := null;
            end case;

            Staged.Replace_Element (I, E);
         end;
      end loop;
   end Apply_Staged;

   --  Original default_locale line handler (Initialize only).
   procedure Parse_Default_Locale_Line (Item : in out Runtime; Line : String)
   is
      Clean : constant String := Trimmed (Line);
      Eq    : Natural;
      Name  : Unbounded_String;
   begin
      if Clean'Length = 0 or else Clean (Clean'First) = '#' then
         return;
      end if;

      Eq := Equals_Index (Clean);
      if Eq = 0 or else Eq = Clean'First then
         return;
      end if;

      Name := To_Unbounded_String (Trimmed (Clean (Clean'First .. Eq - 1)));
      if To_String (Name) = "default_locale" then
         declare
            Value : constant String := Unquote (Clean (Eq + 1 .. Clean'Last));
         begin
            if Item.Default_Locale_Seen
              or else not Is_Valid_Default_Locale (Value)
            then
               Item.Valid := False;
               Item.Error := I18N.Errors.Validation_Error;
               return;
            end if;

            if not Is_Valid_Locale (Canonical_Locale (Value)) then
               Item.Valid := False;
               Item.Error := I18N.Errors.Validation_Error;
               return;
            end if;

            Item.Default_Locale :=
              To_Unbounded_String (Canonical_Locale (Value));
            Item.Default_Locale_Seen := True;
         end;
      end if;
   end Parse_Default_Locale_Line;

   --  Detect the first default_locale directive, or return the built-in default.
   function Detect_Default_Locale
     (Lines : Line_Vectors.Vector)
      return String
    is
      Unused_Invalid_Tag : Unbounded_String;
      Unused_Invalid_Line : Natural;
      Unused_Duplicate_Line : Natural;
      Has_Default : Boolean;
      Value       : Unbounded_String;
      Duplicate   : Boolean;
      Invalid     : Boolean;
   begin
      Analyze_Default_Locale
        (Lines       => Lines,
         Has_Default => Has_Default,
         Value       => Value,
         Duplicate   => Duplicate,
         Invalid     => Invalid,
         Invalid_Tag => Unused_Invalid_Tag,
         Invalid_Line => Unused_Invalid_Line,
         Duplicate_Line => Unused_Duplicate_Line);

      if Has_Default then
         if not Invalid and then not Duplicate then
            return To_String (Value);
         end if;
         return I18N.Locales.Default_Locale_Name;
      end if;

      return I18N.Locales.Default_Locale_Name;
   end Detect_Default_Locale;

   ---------------------------------------------------------------------------
   --  Public status / diagnostics helpers.
   ---------------------------------------------------------------------------

   function Public_Failure
     (Status      : I18N.Result.Render_Status;
      Diagnostics : I18N.Diagnostics.Diagnostic_List)
      return I18N.Result.Render_Result is
   begin
      return
        (Status      => Status,
         Text        => I18N.Result.To_Output_View (""),
         Diagnostics => Diagnostics);
   end Public_Failure;

   procedure Add_Runtime_Diagnostic
     (Diagnostics : in out I18N.Diagnostics.Diagnostic_List;
      Status      : I18N.Result.Render_Status;
      Key         : String := "")
   is
      Kind    : I18N.Diagnostics.Diagnostic_Kind :=
        I18N.Diagnostics.Parse_Error;
      Message : constant String := I18N.Result.Render_Status'Image (Status);
   begin
      case Status is
         when I18N.Result.Missing_Argument                             =>
            Kind := I18N.Diagnostics.Missing_Variable;

         when I18N.Result.Invalid_Argument                             =>
            Kind := I18N.Diagnostics.Invalid_Selector;

         when I18N.Result.Formatting_Error                             =>
            Kind := I18N.Diagnostics.Missing_Branch;

         when I18N.Result.Buffer_Overflow                              =>
            Kind := I18N.Diagnostics.Overflow_Warning;

         when I18N.Result.Execution_Error | I18N.Result.Internal_Error =>
            Kind := I18N.Diagnostics.Parse_Error;

         when I18N.Result.Success | I18N.Result.Missing_Key            =>
            return;
      end case;

      I18N.Diagnostics.Add
        (List => Diagnostics, Kind => Kind, Message => Message, Key => Key);
   end Add_Runtime_Diagnostic;

   ---------------------------------------------------------------------------
   --  Compiled-AST rendering (no parsing on the render hot path).
   ---------------------------------------------------------------------------

   function Is_Decimal_Integer (Text : String) return Boolean is
      Start : Positive;
   begin
      if Text'Length = 0 then
         return False;
      end if;

      Start := Text'First;
      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return False;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
      end loop;

      return True;
   end Is_Decimal_Integer;

   function Integer_Image_No_Leading_Space
     (Value : Long_Long_Integer) return String
   is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Integer_Image_No_Leading_Space;

   function Substitute_Number
     (Text : String; Number_Text : String; Active : Boolean) return String
   is
      Result : Unbounded_String;
   begin
      for C of Text loop
         if C = Escaped_Number_Sign then
            Append (Result, '#');
         elsif C = '#' and then Active then
            Append (Result, Number_Text);
         else
            Append (Result, C);
         end if;
      end loop;

      return To_String (Result);
   end Substitute_Number;

   --  Split a decimal string ("12.50", "-1.5") into CLDR operands. Requires at
   --  least one digit on each side of a single '.'; sets Valid := False for any
   --  other shape (including a plain integer with no fraction).
   procedure Split_Decimal
     (Text            : String;
      Integer_Part    : out Long_Long_Integer;
      Fraction_Digits : out Natural;
      Fraction_Value  : out Long_Long_Integer;
      Valid           : out Boolean)
   is
      Start : Natural := Text'First;
      Dot   : Natural := 0;
   begin
      Integer_Part    := 0;
      Fraction_Digits := 0;
      Fraction_Value  := 0;
      Valid           := False;

      if Text'Length = 0 then
         return;
      end if;

      if Text (Start) = '-' or else Text (Start) = '+' then
         if Text'Length = 1 then
            return;
         end if;
         Start := Start + 1;
      end if;

      for Index in Start .. Text'Last loop
         if Text (Index) = '.' then
            if Dot /= 0 then
               return;  --  more than one '.'
            end if;
            Dot := Index;
         elsif Text (Index) not in '0' .. '9' then
            return;     --  non-digit
         end if;
      end loop;

      --  Need digits before and after a single dot.
      if Dot = 0 or else Dot = Start or else Dot = Text'Last then
         return;
      end if;

      Integer_Part    := Long_Long_Integer'Value (Text (Start .. Dot - 1));
      Fraction_Digits := Text'Last - Dot;
      Fraction_Value  := Long_Long_Integer'Value (Text (Dot + 1 .. Text'Last));
      Valid           := True;
   exception
      when Constraint_Error =>
         Valid := False;
   end Split_Decimal;

   --  Classify a plural selector argument, accepting both whole numbers and
   --  decimal quantities (the latter via CLDR fractional operands). Sets
   --  Valid := False when the argument is neither.
   procedure Classify_Plural_Argument
     (Raw      : String;
      Locale   : String;
      Offset   : Long_Long_Integer;
      Category : out I18N.Plurals.Plural_Category;
      Rendered : out Unbounded_String;
      Valid    : out Boolean)
   is
   begin
      Category := I18N.Plurals.Other;
      Rendered := Null_Unbounded_String;
      Valid    := True;

      if Offset /= 0 then
         if not Is_Decimal_Integer (Raw) then
            Valid := False;
            return;
         end if;

         declare
            Value : constant Long_Long_Integer := Long_Long_Integer'Value (Raw);
            Adjusted : constant Long_Long_Integer := Value - Offset;
         begin
            Category := I18N.Plurals.Cardinal (Locale, Adjusted);
            Rendered :=
              To_Unbounded_String (Integer_Image_No_Leading_Space (Adjusted));
         end;
      elsif Is_Decimal_Integer (Raw) then
         declare
            Value : constant Long_Long_Integer := Long_Long_Integer'Value (Raw);
         begin
            Category := I18N.Plurals.Cardinal (Locale, Value);
            Rendered :=
              To_Unbounded_String (Integer_Image_No_Leading_Space (Value));
         end;
      else
         declare
            I_Part     : Long_Long_Integer;
            Digit_Count : Natural;
            F_Val      : Long_Long_Integer;
            OK         : Boolean;
         begin
            Split_Decimal (Raw, I_Part, Digit_Count, F_Val, OK);
            if OK then
               Category :=
                 I18N.Plurals.Cardinal (Locale, I_Part, Digit_Count, F_Val);
               Rendered := To_Unbounded_String (Raw);
            else
               Valid := False;
            end if;
         end;
      end if;
   exception
      when Constraint_Error =>
         Valid := False;
   end Classify_Plural_Argument;

   procedure Render_Public_Nodes
     (Root          : I18N.AST.Node_Access;
      Arguments     : I18N.Arguments.Arguments;
      Output        : in out Unbounded_String;
      Status        : in out I18N.Result.Render_Status;
      Diagnostics   : in out I18N.Diagnostics.Diagnostic_List;
      Locale        : String;
      Number_Text   : String := "";
      Number_Active : Boolean := False)
   is
      Current : I18N.AST.Node_Access := Root;
   begin
      while Current /= null loop
         exit when Status /= I18N.Result.Success;

         case Current.Kind is
            when I18N.AST.Text          =>
               I18N.Observability.Emit (I18N.Observability.Op_Text, "");
               Append
                 (Output,
                  Substitute_Number
                    (Text        => To_String (Current.Text),
                     Number_Text => Number_Text,
                     Active      => Number_Active));

            when I18N.AST.Variable      =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     Append (Output, I18N.Arguments.Get (Arguments, Key));
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Number        =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Number_Format.Format_Into
                          (Value_Text => I18N.Arguments.Get (Arguments, Key),
                           Locale     => Locale,
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Overflow);

                        if Overflow then
                           Status := I18N.Result.Buffer_Overflow;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append (Output, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Date_Format | I18N.AST.Time_Format
               | I18N.AST.Date_Time_Format =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        if Current.Kind = I18N.AST.Date_Format then
                           I18N.Date_Time_Format.Format_Date_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        elsif Current.Kind = I18N.AST.Time_Format then
                           I18N.Date_Time_Format.Format_Time_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        else
                           I18N.Date_Time_Format.Format_Date_Time_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Overflow);
                        end if;

                        if Overflow then
                           Status := I18N.Result.Buffer_Overflow;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append (Output, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Currency      =>
               declare
                  Key  : constant String := To_String (Current.Name);
                  Code : constant String := To_String (Current.Currency_Code);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Currency.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Currency.Format_Into
                          (Amount_Text   => I18N.Arguments.Get (Arguments, Key),
                           Currency_Code => Code,
                           Locale        => Locale,
                           Target        => Formatted,
                           Last          => Last,
                           Ok            => Ok,
                           Overflow      => Overflow);

                        if Overflow then
                           Status := I18N.Result.Buffer_Overflow;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append (Output, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Duration_Format | I18N.AST.Byte_Size_Format
               | I18N.AST.Unit_Format | I18N.AST.Relative_Time_Format
               | I18N.AST.List_Format =>
               declare
                  Key : constant String := To_String (Current.Name);

                  function Kind return I18N.Extra_Format.Extra_Kind is
                  begin
                     case Current.Kind is
                        when I18N.AST.Duration_Format =>
                           return I18N.Extra_Format.Duration;
                        when I18N.AST.Byte_Size_Format =>
                           return I18N.Extra_Format.Byte_Size;
                        when I18N.AST.Unit_Format =>
                           return I18N.Extra_Format.Unit;
                        when I18N.AST.Relative_Time_Format =>
                           return I18N.Extra_Format.Relative_Time;
                        when others =>
                           return I18N.Extra_Format.List;
                     end case;
                  end Kind;
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Extra_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Overflow  : Boolean;
                     begin
                        I18N.Extra_Format.Format_Into
                          (Kind     => Kind,
                           Value    => I18N.Arguments.Get (Arguments, Key),
                           Locale   => Locale,
                           Option   => To_String (Current.Currency_Code),
                           Target   => Formatted,
                           Last     => Last,
                           Ok       => Ok,
                           Overflow => Overflow);

                        if Overflow then
                           Status := I18N.Result.Buffer_Overflow;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append (Output, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Plural        =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Plural, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Category : I18N.Plurals.Plural_Category;
                        Rendered : Unbounded_String;
                        Valid    : Boolean;
                     begin
                        --  Accept whole numbers and decimal quantities (the
                        --  latter via CLDR fractional operands).
                        Classify_Plural_Argument
                          (Raw      => I18N.Arguments.Get (Arguments, Key),
                           Locale   => Locale,
                           Offset   => Current.Plural_Offset,
                           Category => Category,
                           Rendered => Rendered,
                           Valid    => Valid);
                        if not Valid then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        else
                           declare
                              Raw_Value : constant String :=
                                I18N.Arguments.Get (Arguments, Key);
                              Exact_Key : constant String :=
                                (if Is_Decimal_Integer (Raw_Value)
                                 then Integer_Image_No_Leading_Space
                                        (Long_Long_Integer'Value (Raw_Value))
                                 else "");
                              Branch : I18N.AST.Node_Access :=
                                (if Exact_Key'Length > 0
                                 then I18N.AST.Branch_Body
                                        (Current.Plural_Exact, Exact_Key)
                                 else null);
                           begin
                              if Branch = null then
                                 Branch :=
                                   (case Category is
                                      when I18N.Plurals.Zero =>
                                         Current.Plural_Zero,
                                      when I18N.Plurals.One =>
                                         Current.One,
                                      when I18N.Plurals.Two =>
                                         Current.Plural_Two,
                                      when I18N.Plurals.Few =>
                                         Current.Plural_Few,
                                      when I18N.Plurals.Many =>
                                         Current.Plural_Many,
                                      when I18N.Plurals.Other =>
                                         Current.Other);
                              end if;

                              if Branch = null then
                                 Branch := Current.Other;
                              end if;

                              if Branch = null then
                                 Status := I18N.Result.Formatting_Error;
                                 Add_Runtime_Diagnostic
                                   (Diagnostics, Status, Key);
                              else
                                 Render_Public_Nodes
                                   (Root          => Branch,
                                    Arguments     => Arguments,
                                    Output        => Output,
                                    Status        => Status,
                                    Diagnostics   => Diagnostics,
                                    Locale        => Locale,
                                    Number_Text   => To_String (Rendered),
                                    Number_Active => True);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.Select_Node   =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Select, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Value   : constant String :=
                          I18N.Arguments.Get (Arguments, Key);
                        Matched : constant Boolean :=
                          I18N.AST.Has_Branch (Current.Branches, Value);
                        Branch  : constant I18N.AST.Node_Access :=
                          (if Matched
                           then I18N.AST.Branch_Body (Current.Branches, Value)
                           else
                             I18N.AST.Branch_Body (Current.Branches, "other"));
                     begin
                        if not Matched
                          and then not I18N.AST.Has_Branch
                                         (Current.Branches, "other")
                        then
                           Status := I18N.Result.Formatting_Error;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Branch /= null then
                           --  A present-but-empty branch (Branch = null)
                           --  renders as empty text with Success.
                           Render_Public_Nodes
                             (Root          => Branch,
                              Arguments     => Arguments,
                              Output        => Output,
                              Status        => Status,
                              Diagnostics   => Diagnostics,
                              Locale        => Locale,
                              Number_Text   => Number_Text,
                              Number_Active => Number_Active);
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.SelectOrdinal =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Ordinal, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Raw : constant String :=
                          I18N.Arguments.Get (Arguments, Key);
                     begin
                        if not Is_Decimal_Integer (Raw) then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        else
                           declare
                              Value    : constant Long_Long_Integer :=
                                Long_Long_Integer'Value (Raw);
                              Rendered : constant String :=
                                Integer_Image_No_Leading_Space (Value);
                              --  Select the ordinal branch by the locale's CLDR
                              --  ordinal category. Categories without a matching
                              --  branch fall back to other.
                              Branch   : I18N.AST.Node_Access :=
                                I18N.AST.Branch_Body
                                  (Current.Ord_Exact, Rendered);
                           begin
                              if Branch = null then
                                 case I18N.Plurals.Ordinal (Locale, Value) is
                                    when I18N.Plurals.Zero =>
                                       Branch := Current.Ord_Zero;
                                    when I18N.Plurals.One =>
                                       Branch := Current.Ord_One;
                                    when I18N.Plurals.Two =>
                                       Branch := Current.Ord_Two;
                                    when I18N.Plurals.Few =>
                                       Branch := Current.Ord_Few;
                                    when I18N.Plurals.Many =>
                                       Branch := Current.Ord_Many;
                                    when others =>
                                       Branch := Current.Ord_Other;
                                 end case;
                              end if;

                              --  An absent category branch falls back to "other".
                              if Branch = null then
                                 Branch := Current.Ord_Other;
                              end if;

                              if Branch = null then
                                 Status := I18N.Result.Formatting_Error;
                                 Add_Runtime_Diagnostic
                                   (Diagnostics, Status, Key);
                              else
                                 Render_Public_Nodes
                                   (Root          => Branch,
                                    Arguments     => Arguments,
                                    Output        => Output,
                                    Status        => Status,
                                    Diagnostics   => Diagnostics,
                                    Locale        => Locale,
                                    Number_Text   => Rendered,
                                    Number_Active => True);
                              end if;
                           end;
                        end if;
                     exception
                        when Constraint_Error =>
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     end;
                  end if;
               end;
         end case;

         Current := Current.Next;
      end loop;
   end Render_Public_Nodes;

   --  Execute a precompiled catalog entry. No parsing or compilation occurs on
   --  this path: complexity is O(output length).
   function Render_Compiled
     (Root      : I18N.AST.Node_Access;
      Arguments : I18N.Arguments.Arguments;
      Locale    : String)
      return I18N.Result.Render_Result
   is
      Output      : Unbounded_String;
      Status      : I18N.Result.Render_Status := I18N.Result.Success;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   begin
      I18N.Observability.Emit (I18N.Observability.Message_Start, "");
      Render_Public_Nodes
        (Root        => Root,
         Arguments   => Arguments,
         Output      => Output,
         Status      => Status,
         Diagnostics => Diagnostics,
         Locale      => Locale);
      I18N.Observability.Emit (I18N.Observability.Message_End, "");

      if Status /= I18N.Result.Success then
         return Public_Failure (Status => Status, Diagnostics => Diagnostics);
      elsif Length (Output) > I18N.Result.Max_Output_Length then
         Add_Runtime_Diagnostic
           (Diagnostics => Diagnostics,
            Status      => I18N.Result.Buffer_Overflow,
            Key         => "output");
         return
           Public_Failure
             (Status      => I18N.Result.Buffer_Overflow,
              Diagnostics => Diagnostics);
      else
         return
           (Status      => I18N.Result.Success,
            Text        => I18N.Result.To_Output_View (To_String (Output)),
            Diagnostics => Diagnostics);
      end if;
   exception
      when others =>
         return I18N.Result.Failure (I18N.Result.Internal_Error);
   end Render_Compiled;

   --  Append Text into caller-owned Target, tracking the written count and a
   --  saturating overflow flag. No allocation occurs.
   procedure Append_Bounded
     (Target   : in out String;
      Count    : in out Natural;
      Overflow : in out Boolean;
      Text     : String)
   is
   begin
      for C of Text loop
         if Count >= Target'Length then
            Overflow := True;
            return;
         end if;
         Target (Target'First + Count) := C;
         Count := Count + 1;
      end loop;
   end Append_Bounded;

   --  Append text into Target, substituting '#' with Number_Text when active.
   procedure Append_Text_Bounded
     (Target        : in out String;
      Count         : in out Natural;
      Overflow      : in out Boolean;
      Text          : String;
      Number_Text   : String;
      Number_Active : Boolean)
   is
   begin
      for C of Text loop
         if C = Escaped_Number_Sign then
            Append_Bounded (Target, Count, Overflow, "#");
         elsif C = '#' and then Number_Active then
            Append_Bounded (Target, Count, Overflow, Number_Text);
         else
            Append_Bounded (Target, Count, Overflow, [1 => C]);
         end if;
         exit when Overflow;
      end loop;
   end Append_Text_Bounded;

   --  Render an AST directly into caller-owned fixed storage. This is the true
   --  no-heap render path: it never materializes an Unbounded_String. It mirrors
   --  Render_Public_Nodes branch-selection semantics, including locale-aware
   --  plural/ordinal categories.
   procedure Render_Bounded_Nodes
     (Root          : I18N.AST.Node_Access;
      Arguments     : I18N.Arguments.Arguments;
      Target        : in out String;
      Count         : in out Natural;
      Overflow      : in out Boolean;
      Status        : in out I18N.Result.Render_Status;
      Diagnostics   : in out I18N.Diagnostics.Diagnostic_List;
      Locale        : String;
      Number_Text   : String := "";
      Number_Active : Boolean := False)
   is
      Current : I18N.AST.Node_Access := Root;
   begin
      while Current /= null loop
         exit when Status /= I18N.Result.Success or else Overflow;

         case Current.Kind is
            when I18N.AST.Text          =>
               I18N.Observability.Emit (I18N.Observability.Op_Text, "");
               Append_Text_Bounded
                 (Target, Count, Overflow,
                  To_String (Current.Text), Number_Text, Number_Active);

            when I18N.AST.Variable      =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     Append_Bounded
                       (Target, Count, Overflow,
                        I18N.Arguments.Get (Arguments, Key));
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Number        =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Number_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Format_Overflow : Boolean;
                     begin
                        I18N.Number_Format.Format_Into
                          (Value_Text => I18N.Arguments.Get (Arguments, Key),
                           Locale     => Locale,
                           Style      => To_String (Current.Currency_Code),
                           Target     => Formatted,
                           Last       => Last,
                           Ok         => Ok,
                           Overflow   => Format_Overflow);

                        if Format_Overflow then
                           Overflow := True;
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append_Bounded
                             (Target, Count, Overflow, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Date_Format | I18N.AST.Time_Format
               | I18N.AST.Date_Time_Format =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Date_Time_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Format_Overflow : Boolean;
                     begin
                        if Current.Kind = I18N.AST.Date_Format then
                           I18N.Date_Time_Format.Format_Date_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Format_Overflow);
                        elsif Current.Kind = I18N.AST.Time_Format then
                           I18N.Date_Time_Format.Format_Time_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Format_Overflow);
                        else
                           I18N.Date_Time_Format.Format_Date_Time_Into
                             (Value_Text => I18N.Arguments.Get (Arguments, Key),
                              Locale     => Locale,
                              Style      => To_String (Current.Currency_Code),
                              Target     => Formatted,
                              Last       => Last,
                              Ok         => Ok,
                              Overflow   => Format_Overflow);
                        end if;

                        if Format_Overflow then
                           Overflow := True;
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append_Bounded
                             (Target, Count, Overflow, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Currency      =>
               declare
                  Key  : constant String := To_String (Current.Name);
                  Code : constant String := To_String (Current.Currency_Code);
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Currency.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Format_Overflow : Boolean;
                     begin
                        I18N.Currency.Format_Into
                          (Amount_Text   => I18N.Arguments.Get (Arguments, Key),
                           Currency_Code => Code,
                           Locale        => Locale,
                           Target        => Formatted,
                           Last          => Last,
                           Ok            => Ok,
                           Overflow      => Format_Overflow);

                        if Format_Overflow then
                           Overflow := True;
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append_Bounded
                             (Target, Count, Overflow, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Duration_Format | I18N.AST.Byte_Size_Format
               | I18N.AST.Unit_Format | I18N.AST.Relative_Time_Format
               | I18N.AST.List_Format =>
               declare
                  Key : constant String := To_String (Current.Name);

                  function Kind return I18N.Extra_Format.Extra_Kind is
                  begin
                     case Current.Kind is
                        when I18N.AST.Duration_Format =>
                           return I18N.Extra_Format.Duration;
                        when I18N.AST.Byte_Size_Format =>
                           return I18N.Extra_Format.Byte_Size;
                        when I18N.AST.Unit_Format =>
                           return I18N.Extra_Format.Unit;
                        when I18N.AST.Relative_Time_Format =>
                           return I18N.Extra_Format.Relative_Time;
                        when others =>
                           return I18N.Extra_Format.List;
                     end case;
                  end Kind;
               begin
                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Key);
                  if I18N.Arguments.Has (Arguments, Key) then
                     declare
                        Formatted : String (1 .. I18N.Extra_Format.Max_Formatted_Length);
                        Last      : Natural;
                        Ok        : Boolean;
                        Format_Overflow : Boolean;
                     begin
                        I18N.Extra_Format.Format_Into
                          (Kind     => Kind,
                           Value    => I18N.Arguments.Get (Arguments, Key),
                           Locale   => Locale,
                           Option   => To_String (Current.Currency_Code),
                           Target   => Formatted,
                           Last     => Last,
                           Ok       => Ok,
                           Overflow => Format_Overflow);

                        if Format_Overflow then
                           Overflow := True;
                        elsif not Ok then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Last > 0 then
                           Append_Bounded
                             (Target, Count, Overflow, Formatted (1 .. Last));
                        end if;
                     end;
                  else
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  end if;
               end;

            when I18N.AST.Plural        =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Plural, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Category : I18N.Plurals.Plural_Category;
                        Rendered : Unbounded_String;
                        Valid    : Boolean;
                     begin
                        Classify_Plural_Argument
                          (Raw      => I18N.Arguments.Get (Arguments, Key),
                           Locale   => Locale,
                           Offset   => Current.Plural_Offset,
                           Category => Category,
                           Rendered => Rendered,
                           Valid    => Valid);
                        if not Valid then
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        else
                           declare
                              Raw_Value : constant String :=
                                I18N.Arguments.Get (Arguments, Key);
                              Exact_Key : constant String :=
                                (if Is_Decimal_Integer (Raw_Value)
                                 then Integer_Image_No_Leading_Space
                                        (Long_Long_Integer'Value (Raw_Value))
                                 else "");
                              Branch : I18N.AST.Node_Access :=
                                (if Exact_Key'Length > 0
                                 then I18N.AST.Branch_Body
                                        (Current.Plural_Exact, Exact_Key)
                                 else null);
                           begin
                              if Branch = null then
                                 Branch :=
                                   (case Category is
                                      when I18N.Plurals.Zero =>
                                         Current.Plural_Zero,
                                      when I18N.Plurals.One =>
                                         Current.One,
                                      when I18N.Plurals.Two =>
                                         Current.Plural_Two,
                                      when I18N.Plurals.Few =>
                                         Current.Plural_Few,
                                      when I18N.Plurals.Many =>
                                         Current.Plural_Many,
                                      when I18N.Plurals.Other =>
                                         Current.Other);
                              end if;

                              if Branch = null then
                                 Branch := Current.Other;
                              end if;

                              if Branch = null then
                                 Status := I18N.Result.Formatting_Error;
                                 Add_Runtime_Diagnostic
                                   (Diagnostics, Status, Key);
                              else
                                 Render_Bounded_Nodes
                                   (Branch, Arguments, Target, Count, Overflow,
                                    Status, Diagnostics, Locale,
                                    To_String (Rendered), True);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.Select_Node   =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Select, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Value   : constant String :=
                          I18N.Arguments.Get (Arguments, Key);
                        Matched : constant Boolean :=
                          I18N.AST.Has_Branch (Current.Branches, Value);
                        Branch  : constant I18N.AST.Node_Access :=
                          (if Matched
                           then I18N.AST.Branch_Body (Current.Branches, Value)
                           else
                             I18N.AST.Branch_Body (Current.Branches, "other"));
                     begin
                        if not Matched
                          and then not I18N.AST.Has_Branch
                                         (Current.Branches, "other")
                        then
                           Status := I18N.Result.Formatting_Error;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        elsif Branch /= null then
                           Render_Bounded_Nodes
                             (Branch, Arguments, Target, Count, Overflow,
                              Status, Diagnostics, Locale, Number_Text,
                              Number_Active);
                        end if;
                     end;
                  end if;
               end;

            when I18N.AST.SelectOrdinal =>
               declare
                  Key : constant String := To_String (Current.Name);
               begin
                  I18N.Observability.Emit (I18N.Observability.Op_Ordinal, Key);
                  if not I18N.Arguments.Has (Arguments, Key) then
                     Status := I18N.Result.Missing_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  elsif not Is_Decimal_Integer
                              (I18N.Arguments.Get (Arguments, Key))
                  then
                     Status := I18N.Result.Invalid_Argument;
                     Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                  else
                     declare
                        Value    : constant Long_Long_Integer :=
                          Long_Long_Integer'Value
                            (I18N.Arguments.Get (Arguments, Key));
                        Rendered : constant String :=
                          Integer_Image_No_Leading_Space (Value);
                        Branch   : I18N.AST.Node_Access :=
                          I18N.AST.Branch_Body (Current.Ord_Exact, Rendered);
                     begin
                        if Branch = null then
                           case I18N.Plurals.Ordinal (Locale, Value) is
                              when I18N.Plurals.Zero =>
                                 Branch := Current.Ord_Zero;
                              when I18N.Plurals.One =>
                                 Branch := Current.Ord_One;
                              when I18N.Plurals.Two =>
                                 Branch := Current.Ord_Two;
                              when I18N.Plurals.Few =>
                                 Branch := Current.Ord_Few;
                              when I18N.Plurals.Many =>
                                 Branch := Current.Ord_Many;
                              when others =>
                                 Branch := Current.Ord_Other;
                           end case;
                        end if;

                        --  An absent category branch falls back to "other".
                        if Branch = null then
                           Branch := Current.Ord_Other;
                        end if;

                        if Branch = null then
                           Status := I18N.Result.Formatting_Error;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        else
                           Render_Bounded_Nodes
                             (Branch, Arguments, Target, Count, Overflow,
                              Status, Diagnostics, Locale, Rendered, True);
                        end if;
                     exception
                        when Constraint_Error =>
                           Status := I18N.Result.Invalid_Argument;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                     end;
                  end if;
               end;
         end case;

         Current := Current.Next;
      end loop;
   end Render_Bounded_Nodes;

   ---------------------------------------------------------------------------
   --  Locale fallback resolution (shared by Render, Resolve, Render_Into).
   ---------------------------------------------------------------------------

   procedure Index_Lookup
     (Item   : Runtime;
      Locale : String;
      Key    : String;
      Hit    : out Boolean;
      Idx    : out Natural)
   is
      Comp : constant String := Composite (Trimmed (Locale), Trimmed (Key));
   begin
      if Item.Index.Contains (Comp) then
         Hit := True;
         Idx := Item.Index.Element (Comp);
      else
         Hit := False;
         Idx := 0;
      end if;
   end Index_Lookup;

   --  Walk the deterministic fallback chain (locale -> parent -> ... -> default
   --  locale). Bounded by locale fallback depth with O(1) per-locale lookup.
   procedure Resolve_Entry
     (Item            : Runtime;
      Locale          : String;
      Key             : String;
      Hit             : out Boolean;
      Resolved_Locale : out Unbounded_String;
      Idx             : out Natural)
   is
      Requested : constant String := Canonical_Locale (Locale);
      Current   : Unbounded_String := To_Unbounded_String (Requested);
   begin
      Resolved_Locale := Null_Unbounded_String;
      Idx := 0;

      loop
         Index_Lookup (Item, To_String (Current), Key, Hit, Idx);
         if Hit then
            Resolved_Locale := Current;
            return;
         end if;

         declare
            Parent : constant String :=
              I18N.Locales.Parent (To_String (Current));
         begin
            exit when Parent'Length = 0;
            Current := To_Unbounded_String (Parent);
         end;
      end loop;

      if To_String (Item.Default_Locale) /= Requested then
         Index_Lookup
           (Item, To_String (Item.Default_Locale), Key, Hit, Idx);
         if Hit then
            Resolved_Locale := Item.Default_Locale;
            return;
         end if;
      end if;

      Hit := False;
   end Resolve_Entry;

   ---------------------------------------------------------------------------
   --  Initialization and legacy loading.
   ---------------------------------------------------------------------------

   procedure Reset_Defaults (Item : in out Runtime) is
   begin
      Item.Valid := True;
      Item.Error := I18N.Errors.Parse_Error;
      Item.Default_Locale :=
        To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Item.Default_Locale_Seen := False;
   end Reset_Defaults;

   --  Strict ingest used by Initialize and the legacy Load: stage the lines,
   --  apply them under Reject_Duplicates, and mark the runtime invalid on any
   --  failure. Succeeded reports whether every entry was committed.
   procedure Ingest_Strict
     (Item        : in out Runtime;
      Lines       : Line_Vectors.Vector;
      Source_Name : String;
      Succeeded   : out Boolean)
   is
      Staged      : Staged_Vectors.Vector;
      Stage_Ok    : Boolean;
      Stage_Error : I18N.Errors.Error_Kind;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
      Status      : Load_Status;
      Added       : Natural;
      Replaced    : Natural;
      Ignored     : Natural;
   begin
      Stage_Lines
        (Lines          => Lines,
         Default_Locale => To_String (Item.Default_Locale),
         Source_Name    => Source_Name,
         Staged         => Staged,
         Ok             => Stage_Ok,
         Error          => Stage_Error,
         Diagnostics    => Diagnostics);

      if not Stage_Ok then
         Free_Staged (Staged);
         Item.Valid := False;
         Item.Error := Stage_Error;
         Succeeded := False;
         return;
      end if;

      Apply_Staged
        (Item, Staged, Reject_Duplicates, Status, Added, Replaced, Ignored);
      Free_Staged (Staged);

      if Status /= Loaded then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
         Succeeded := False;
         return;
      end if;

      Succeeded := True;
   end Ingest_Strict;

   procedure Initialize (Item : in out Runtime; Catalog_Path : String) is
      Found     : Boolean;
      Lines     : Line_Vectors.Vector;
      Succeeded : Boolean;
   begin
      Finalize (Item);
      Reset_Defaults (Item);

      Read_File_Lines (Catalog_Path, Found, Lines);
      if not Found then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      end if;

      --  Establish the default locale before binding unqualified keys.
      for Raw of Lines loop
         Parse_Default_Locale_Line (Item, To_String (Raw));
         exit when not Item.Valid;
      end loop;

      if not Item.Valid then
         return;
      end if;

      Ingest_Strict (Item, Lines, Catalog_Path, Succeeded);
      if not Succeeded then
         return;
      end if;

      if Item.Catalog.Is_Empty then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
      end if;
   end Initialize;

   procedure Initialize_Binary_File
     (Item         : in out Runtime;
      Catalog_Path : String)
   is
      Found       : Boolean;
      Lines       : Line_Vectors.Vector;
      Payload     : Line_Vectors.Vector;
      Succeeded   : Boolean;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   begin
      Finalize (Item);
      Reset_Defaults (Item);

      Read_File_Lines (Catalog_Path, Found, Lines);
      if not Found then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      elsif not Decode_Binary_Catalog
                  (Lines, Catalog_Path, Payload, Diagnostics)
      then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
         return;
      end if;

      for Raw of Payload loop
         Parse_Default_Locale_Line (Item, To_String (Raw));
         exit when not Item.Valid;
      end loop;

      if not Item.Valid then
         return;
      end if;

      Ingest_Strict (Item, Payload, Catalog_Path, Succeeded);
      if not Succeeded then
         return;
      end if;

      if Item.Catalog.Is_Empty then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
      end if;
   end Initialize_Binary_File;

   procedure Load (Item : in out Runtime; Catalog_Path : String) is
      Found     : Boolean;
      Lines     : Line_Vectors.Vector;
      Succeeded : Boolean;
   begin
      if not Item.Valid then
         return;
      end if;

      Read_File_Lines (Catalog_Path, Found, Lines);
      if not Found then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      end if;

      Ingest_Strict (Item, Lines, Catalog_Path, Succeeded);
   end Load;

   ---------------------------------------------------------------------------
   --  Stable shard loading (non-destructive).
   ---------------------------------------------------------------------------

   procedure Ingest_Lines
     (Item   : in out Runtime;
      Lines  : Line_Vectors.Vector;
      Source_Name : String;
      Policy : Duplicate_Policy;
      Result : in out Load_Result)
   is
      Staged            : Staged_Vectors.Vector;
      Stage_Ok          : Boolean;
      Stage_Error       : I18N.Errors.Error_Kind;
      Status            : Load_Status;
      Added             : Natural;
      Replaced          : Natural;
      Ignored           : Natural;
      Effective_Default : Unbounded_String := Item.Default_Locale;
      Set_Default       : Boolean := False;
   begin
      --  A runtime that has not established a default locale yet adopts a
      --  default_locale directive from this input, so Load_Text/Load_File can
      --  build a runtime from scratch. The change is committed only if the load
      --  succeeds. Once Initialize (or a prior load) has set the default locale,
      --  shard default_locale directives are ignored.
      if not Item.Default_Locale_Seen then
         declare
            Has_Default : Boolean;
            Duplicate   : Boolean;
            Invalid     : Boolean;
            Default     : Unbounded_String;
            Invalid_Tag : Unbounded_String;
            Invalid_Line  : Natural;
            Duplicate_Line : Natural;
         begin
            Analyze_Default_Locale
              (Lines       => Lines,
               Has_Default => Has_Default,
               Value       => Default,
               Duplicate   => Duplicate,
               Invalid     => Invalid,
               Invalid_Tag => Invalid_Tag,
               Invalid_Line => Invalid_Line,
               Duplicate_Line => Duplicate_Line);

            if Duplicate then
               Add_Load_Diagnostic
                 (Result.Diagnostics, I18N.Diagnostics.Validation_Error,
                  "duplicate default_locale in " & Source_Name
                  & Line_Suffix (Duplicate_Line));
               Result.Status := Invalid_Catalog;
               return;
            elsif Has_Default and then Invalid then
               Add_Load_Diagnostic
                 (Result.Diagnostics, I18N.Diagnostics.Validation_Error,
                  "invalid default_locale in " & Source_Name
                  & Line_Suffix (Invalid_Line),
                  To_String (Invalid_Tag));
               Result.Status := Invalid_Catalog;
               return;
            elsif Has_Default then
               Effective_Default := Default;
               Set_Default := True;
            end if;
         end;
      end if;

      Stage_Lines
        (Lines          => Lines,
         Default_Locale => To_String (Effective_Default),
         Source_Name    => Source_Name,
         Staged         => Staged,
         Ok             => Stage_Ok,
         Error          => Stage_Error,
         Diagnostics    => Result.Diagnostics);

      if not Stage_Ok then
         Free_Staged (Staged);
         Result.Status := Invalid_Catalog;
         return;
      end if;

      Apply_Staged (Item, Staged, Policy, Status, Added, Replaced, Ignored);
      Free_Staged (Staged);

      Result.Status := Status;
      Result.Entries_Added := Added;
      Result.Entries_Replaced := Replaced;
      Result.Entries_Ignored := Ignored;

      if Status = Loaded and then Set_Default then
         Item.Default_Locale := Effective_Default;
         Item.Default_Locale_Seen := True;
      end if;
   end Ingest_Lines;

   procedure Load_File
     (Item   : in out Instance;
      Path   : String;
      Result : out Load_Result;
      Policy : Duplicate_Policy := Reject_Duplicates)
   is
      Found : Boolean;
      Lines : Line_Vectors.Vector;
   begin
      Result := (Status => Invalid_Catalog, Entries_Added => 0, others => <>);

      if not Item.Valid then
         Result.Status := Runtime_Invalid;
         return;
      end if;

      Read_File_Lines (Path, Found, Lines);
      if not Found then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Parse_Error,
            "catalog file not found", Path);
         Result.Status := Source_Not_Found;
         return;
      end if;

      Ingest_Lines (Item, Lines, Path, Policy, Result);
   exception
      when others =>
         Result.Status := Invalid_Catalog;
   end Load_File;

   procedure Load_Binary_File
     (Item   : in out Instance;
      Path   : String;
      Result : out Load_Result;
      Policy : Duplicate_Policy := Reject_Duplicates)
   is
      Found   : Boolean;
      Lines   : Line_Vectors.Vector;
      Payload : Line_Vectors.Vector;
   begin
      Result := (Status => Invalid_Catalog, Entries_Added => 0, others => <>);

      if not Item.Valid then
         Result.Status := Runtime_Invalid;
         return;
      end if;

      Read_File_Lines (Path, Found, Lines);
      if not Found then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Parse_Error,
            "binary catalog file not found", Path);
         Result.Status := Source_Not_Found;
         return;
      elsif not Decode_Binary_Catalog
                  (Lines, Path, Payload, Result.Diagnostics)
      then
         Result.Status := Invalid_Catalog;
         return;
      end if;

      Ingest_Lines (Item, Payload, Path, Policy, Result);
   exception
      when others =>
         Result.Status := Invalid_Catalog;
   end Load_Binary_File;

   procedure Load_Text
     (Item        : in out Instance;
      Source_Name : String;
      Text        : String;
      Result      : out Load_Result;
      Policy      : Duplicate_Policy := Reject_Duplicates)
   is
      Lines : constant Line_Vectors.Vector := Split_Text_Lines (Text);
   begin
      Result := (Status => Invalid_Catalog, Entries_Added => 0, others => <>);

      if not Item.Valid then
         Result.Status := Runtime_Invalid;
         return;
      end if;

      Ingest_Lines (Item, Lines, Source_Name, Policy, Result);
   exception
      when others =>
         Result.Status := Invalid_Catalog;
   end Load_Text;

   ---------------------------------------------------------------------------
   --  Non-destructive validation.
   ---------------------------------------------------------------------------

   function Validate_Lines
     (Lines       : Line_Vectors.Vector;
      Source_Name : String)
      return Catalog_Validation_Result
   is
      Result      : Catalog_Validation_Result;
      Staged      : Staged_Vectors.Vector;
      Stage_Ok    : Boolean;
      Stage_Error : I18N.Errors.Error_Kind;
      Has_Default : Boolean;
      Duplicate   : Boolean;
      Invalid     : Boolean;
      Invalid_Tag : Unbounded_String;
      Default     : Unbounded_String;
      Invalid_Line : Natural;
      Duplicate_Line : Natural;
   begin
      Analyze_Default_Locale
        (Lines       => Lines,
         Has_Default => Has_Default,
         Value       => Default,
         Duplicate   => Duplicate,
         Invalid     => Invalid,
         Invalid_Tag => Invalid_Tag,
         Invalid_Line => Invalid_Line,
         Duplicate_Line => Duplicate_Line);

      if Duplicate then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Validation_Error,
            "duplicate default_locale in " & Source_Name
            & Line_Suffix (Duplicate_Line),
            "default_locale");
         Result.Valid := False;
         return Result;
      elsif Has_Default and then Invalid then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Validation_Error,
            "invalid default_locale in " & Source_Name
            & Line_Suffix (Invalid_Line),
            To_String (Invalid_Tag));
         Result.Valid := False;
         return Result;
      end if;

      Stage_Lines
        (Lines          => Lines,
         Default_Locale => (if Has_Default then To_String (Default)
                           else I18N.Locales.Default_Locale_Name),
         Source_Name    => Source_Name,
         Staged         => Staged,
         Ok             => Stage_Ok,
         Error          => Stage_Error,
         Diagnostics    => Result.Diagnostics);

      if not Stage_Ok then
         Free_Staged (Staged);
         Result.Valid := False;
         return Result;
      end if;

      --  Reject duplicate keys within the validated input. Detection must not
      --  mutate Staged while iterating it, so duplicates are flagged first and
      --  the staged roots are released afterwards.
      declare
         Seen      : Index_Maps.Map;
         Duplicate : Boolean := False;
      begin
         for E of Staged loop
            declare
               Comp : constant String :=
                 Composite (To_String (E.Locale), To_String (E.Key));
            begin
               if Seen.Contains (Comp) then
                  Add_Load_Diagnostic
                    (Result.Diagnostics, I18N.Diagnostics.Validation_Error,
                     "duplicate key within catalog " & Source_Name
                     & Line_Suffix (E.Line),
                     To_String (E.Key));
                  Duplicate := True;
                  exit;
               end if;
               Seen.Insert (Comp, 0);
            end;
         end loop;

         if Duplicate then
            Free_Staged (Staged);
            Result.Valid := False;
            return Result;
         end if;
      end;

      Result.Entry_Count := Natural (Staged.Length);
      Result.Valid := True;
      Free_Staged (Staged);
      return Result;
   end Validate_Lines;

   function Validate_Catalog_File
     (Path : String)
      return Catalog_Validation_Result
   is
      Result : Catalog_Validation_Result;
      Found  : Boolean;
      Lines  : Line_Vectors.Vector;
   begin
      Read_File_Lines (Path, Found, Lines);
      if not Found then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Parse_Error,
            "catalog file not found", Path);
         Result.Valid := False;
         return Result;
      end if;

      return Validate_Lines (Lines, Path);
   exception
      when others =>
         Result.Valid := False;
         return Result;
   end Validate_Catalog_File;

   function Validate_Binary_Catalog_File
     (Path : String)
      return Catalog_Validation_Result
   is
      Result  : Catalog_Validation_Result;
      Found   : Boolean;
      Lines   : Line_Vectors.Vector;
      Payload : Line_Vectors.Vector;
   begin
      Read_File_Lines (Path, Found, Lines);
      if not Found then
         Add_Load_Diagnostic
           (Result.Diagnostics, I18N.Diagnostics.Parse_Error,
            "binary catalog file not found", Path);
         Result.Valid := False;
         return Result;
      elsif not Decode_Binary_Catalog
                  (Lines, Path, Payload, Result.Diagnostics)
      then
         Result.Valid := False;
         return Result;
      end if;

      return Validate_Lines (Payload, Path);
   exception
      when others =>
         Result.Valid := False;
         return Result;
   end Validate_Binary_Catalog_File;

   function Validate_Catalog_Text
     (Source_Name : String;
      Text        : String)
      return Catalog_Validation_Result
   is
   begin
      return Validate_Lines (Split_Text_Lines (Text), Source_Name);
   exception
      when others =>
         declare
            Result : Catalog_Validation_Result;
         begin
            Result.Valid := False;
            return Result;
         end;
   end Validate_Catalog_Text;

   function Validate_Binary_Catalog_Text
     (Source_Name : String;
      Text        : String)
      return Catalog_Validation_Result
   is
      Result  : Catalog_Validation_Result;
      Payload : Line_Vectors.Vector;
   begin
      if not Decode_Binary_Catalog
                (Split_Text_Lines (Text), Source_Name, Payload,
                 Result.Diagnostics)
      then
         Result.Valid := False;
         return Result;
      end if;

      return Validate_Lines (Payload, Source_Name);
   exception
      when others =>
      Result.Valid := False;
      return Result;
   end Validate_Binary_Catalog_Text;

   function Load_Data_Text
     (Source_Name : String;
      Text        : String)
      return Data_Load_Result
   is
      Result : Data_Load_Result;
   begin
      if I18N.Runtime_Data.Load_Text
           (Source_Name => Source_Name,
            Text        => Text,
            Diagnostics => Result.Diagnostics)
      then
         Result.Status := Data_Loaded;
      else
         Result.Status := Invalid_Data;
      end if;

      return Result;
   exception
      when others =>
         Result.Status := Invalid_Data;
         return Result;
   end Load_Data_Text;

   function Load_Data_File
     (Path : String)
      return Data_Load_Result
   is
      Found  : Boolean;
      Lines  : Line_Vectors.Vector;
      Buffer : Unbounded_String;
      Result : Data_Load_Result;
   begin
      Read_File_Lines (Path, Found, Lines);
      if not Found then
         Result.Status := Data_Source_Not_Found;
         I18N.Diagnostics.Add
           (Result.Diagnostics, I18N.Diagnostics.Parse_Error,
            "runtime data file not found", Path);
         return Result;
      end if;

      for Line of Lines loop
         Append (Buffer, To_String (Line));
         Append (Buffer, ASCII.LF);
      end loop;

      return Load_Data_Text (Path, To_String (Buffer));
   exception
      when others =>
         Result.Status := Invalid_Data;
         return Result;
   end Load_Data_File;

   procedure Clear_Runtime_Data is
   begin
      I18N.Runtime_Data.Clear;
   end Clear_Runtime_Data;

   ---------------------------------------------------------------------------
   --  Rendering, resolution, and bounded rendering.
   ---------------------------------------------------------------------------

   function Render
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments) return I18N.Result.Render_Result
   is
      Hit             : Boolean;
      Resolved_Locale : Unbounded_String;
      Idx             : Natural;
   begin
      if not Item.Valid then
         return I18N.Result.Failure (I18N.Result.Execution_Error);
      end if;

      Resolve_Entry (Item, Locale, Key, Hit, Resolved_Locale, Idx);

      if Hit then
         --  Plural/ordinal selection uses the locale the message resolved in
         --  (for example a de message resolved for de-AT uses de rules).
         return
           Render_Compiled
             (Root      => Item.Catalog.Element (Idx).Root,
              Arguments => Arguments,
              Locale    => To_String (Resolved_Locale));
      end if;

      return I18N.Result.Failure (I18N.Result.Missing_Key);
   exception
      when others =>
         return I18N.Result.Failure (I18N.Result.Internal_Error);
   end Render;

   function Resolve
     (Item   : Instance;
      Locale : I18N.Locales.Locale_Id;
      Key    : String)
      return Resolve_Result
   is
      Result          : Resolve_Result;
      Hit             : Boolean;
      Resolved_Locale : Unbounded_String;
      Idx             : Natural;
   begin
      if not Item.Valid then
         Result.Status := Runtime_Invalid;
         return Result;
      end if;

      Resolve_Entry (Item, Locale, Key, Hit, Resolved_Locale, Idx);

      if Hit then
         Result.Status := Found;
         declare
            S : constant String := To_String (Resolved_Locale);
            N : constant Natural :=
              Natural'Min (S'Length, Max_Resolved_Locale_Length);
         begin
            if N > 0 then
               Result.Resolved_Locale_Text (1 .. N) :=
                 S (S'First .. S'First + N - 1);
            end if;
            Result.Resolved_Locale_Last := N;
         end;
      else
         Result.Status := Missing_Key;
      end if;

      return Result;
   exception
      when others =>
         declare
            Failed : Resolve_Result;
         begin
            Failed.Status := Runtime_Invalid;
            return Failed;
         end;
   end Resolve;

   procedure Render_Into
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments;
      Target    : in out String;
      Last      : out Natural;
      Status    : out I18N.Result.Render_Status)
   is
      Hit             : Boolean;
      Resolved_Locale : Unbounded_String;
      Idx             : Natural;
   begin
      Last := 0;

      if not Item.Valid then
         Status := I18N.Result.Execution_Error;
         return;
      end if;

      Resolve_Entry (Item, Locale, Key, Hit, Resolved_Locale, Idx);
      if not Hit then
         Status := I18N.Result.Missing_Key;
         return;
      end if;

      declare
         Count       : Natural := 0;
         Overflow    : Boolean := False;
         RStatus     : I18N.Result.Render_Status := I18N.Result.Success;
         Diagnostics : I18N.Diagnostics.Diagnostic_List;
      begin
         I18N.Observability.Emit (I18N.Observability.Message_Start, "");
         Render_Bounded_Nodes
           (Root        => Item.Catalog.Element (Idx).Root,
            Arguments   => Arguments,
            Target      => Target,
            Count       => Count,
            Overflow    => Overflow,
            Status      => RStatus,
            Diagnostics => Diagnostics,
            Locale      => To_String (Resolved_Locale));
         I18N.Observability.Emit (I18N.Observability.Message_End, "");

         if RStatus /= I18N.Result.Success then
            Last := 0;
            Status := RStatus;
         elsif Overflow then
            Last := (if Count = 0 then 0 else Target'First + Count - 1);
            Status := I18N.Result.Buffer_Overflow;
         else
            Last := (if Count = 0 then 0 else Target'First + Count - 1);
            Status := I18N.Result.Success;
         end if;
      end;
   exception
      when others =>
         Last := 0;
         Status := I18N.Result.Internal_Error;
   end Render_Into;

   ---------------------------------------------------------------------------
   --  Validity and lifecycle.
   ---------------------------------------------------------------------------

   function Is_Valid (Item : Runtime) return Boolean is
   begin
      return Item.Valid;
   end Is_Valid;

   procedure Finalize (Item : in out Runtime) is
   begin
      Item.Valid := True;
      Item.Error := I18N.Errors.Parse_Error;
      I18N.Compiled.Clear (Item.Message);
      Item.Has_Message := False;

      for I in Item.Catalog.First_Index .. Item.Catalog.Last_Index loop
         declare
            E : Catalog_Entry := Item.Catalog.Element (I);
         begin
            if E.Root /= null then
               I18N.AST.Free (E.Root);
               E.Root := null;
               Item.Catalog.Replace_Element (I, E);
            end if;
         end;
      end loop;

      Item.Catalog.Clear;
      Item.Index.Clear;
      Item.Default_Locale :=
        To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Item.Default_Locale_Seen := False;
   end Finalize;

end I18N.Runtime;
