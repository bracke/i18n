with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with I18N.AST; use I18N.AST;
with I18N.Diagnostics;
with I18N.Result; use I18N.Result;
with I18N.Parser;
with I18N.Observability;
with I18N.Validation;

package body I18N.Runtime is

   function Trimmed (Text : String) return String is
   begin
      return Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
   end Trimmed;

   function Unquote (Text : String) return String is
      T : constant String := Trimmed (Text);
   begin
      if T'Length >= 2 and then T (T'First) = '"' and then T (T'Last) = '"'
      then
         --  Catalog authoring uses quoted values in examples and tests.  Strip
         --  enclosing quotes repeatedly so a value that has already passed
         --  through one normalization layer remains stable and does not render
         --  spurious literal quote characters.
         return Unquote (T (T'First + 1 .. T'Last - 1));
      end if;

      return T;
   end Unquote;

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

   function Braces_Balanced (Text : String) return Boolean is
      Depth : Natural := 0;
   begin
      for C of Text loop
         if C = '{' then
            Depth := Depth + 1;
         elsif C = '}' then
            if Depth = 0 then
               return False;
            end if;

            Depth := Depth - 1;
         end if;
      end loop;

      return Depth = 0;
   end Braces_Balanced;

   function Catalog_Contains
     (Item : Runtime; Locale : String; Key : String) return Boolean
   is
      Wanted_Locale : constant String := Trimmed (Locale);
      Wanted_Key    : constant String := Trimmed (Key);
   begin
      for Catalog_Item of Item.Catalog loop
         if To_String (Catalog_Item.Locale) = Wanted_Locale
           and then To_String (Catalog_Item.Message_Key) = Wanted_Key
         then
            return True;
         end if;
      end loop;

      return False;
   end Catalog_Contains;

   procedure Add_Catalog_Entry
     (Item : in out Runtime; Locale : String; Key : String; Source : String) is
   begin
      if not Item.Valid then
         return;
      end if;

      if Locale'Length = 0 or else Key'Length = 0 then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
         return;
      end if;

      if Catalog_Contains (Item, Locale, Key) then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
         return;
      end if;

      if not Braces_Balanced (Source) then
         Item.Valid := False;
         Item.Error := I18N.Errors.Unbalanced_Braces;
         return;
      end if;

      Item.Catalog.Append
        (Catalog_Entry'
           (Locale      => To_Unbounded_String (Trimmed (Locale)),
            Message_Key => To_Unbounded_String (Trimmed (Key)),
            Source      => To_Unbounded_String (Unquote (Source))));
   exception
      when others =>
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
   end Add_Catalog_Entry;

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
            if Item.Default_Locale_Seen or else Value'Length = 0 then
               Item.Valid := False;
               Item.Error := I18N.Errors.Validation_Error;
               return;
            end if;

            Item.Default_Locale := To_Unbounded_String (Value);
            Item.Default_Locale_Seen := True;
         end;
      end if;
   end Parse_Default_Locale_Line;

   procedure Parse_Catalog_Line (Item : in out Runtime; Line : String) is
      Clean : constant String := Trimmed (Line);
      Eq    : Natural;
      Dot   : Natural;
   begin
      if Clean'Length = 0 or else Clean (Clean'First) = '#' then
         return;
      end if;

      Eq := Equals_Index (Clean);
      if Eq = 0 or else Eq = Clean'First then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      end if;

      declare
         Name_Text  : constant String :=
           Trimmed (Clean (Clean'First .. Eq - 1));
         Value_Text : constant String :=
           (if Eq = Clean'Last
            then ""
            else Unquote (Clean (Eq + 1 .. Clean'Last)));
      begin
         if Name_Text = "default_locale" then
            return;
         end if;

         Dot := Dot_Index (Name_Text);
         if Dot = 0 then
            Add_Catalog_Entry
              (Item   => Item,
               Locale => To_String (Item.Default_Locale),
               Key    => Name_Text,
               Source => Value_Text);
         else
            if Dot = Name_Text'First or else Dot = Name_Text'Last then
               Item.Valid := False;
               Item.Error := I18N.Errors.Validation_Error;
               return;
            end if;

            Add_Catalog_Entry
              (Item   => Item,
               Locale => Name_Text (Name_Text'First .. Dot - 1),
               Key    => Name_Text (Dot + 1 .. Name_Text'Last),
               Source => Value_Text);
         end if;
      end;
   end Parse_Catalog_Line;

   procedure Initialize (Item : in out Runtime; Catalog_Path : String) is
   begin
      Finalize (Item);
      Item.Valid := True;
      Item.Error := I18N.Errors.Parse_Error;
      Item.Default_Locale :=
        To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Item.Default_Locale_Seen := False;

      if not Ada.Directories.Exists (Catalog_Path) then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      elsif Ada.Directories."/="
              (Ada.Directories.Kind (Catalog_Path),
               Ada.Directories.Ordinary_File)
      then
         Item.Valid := False;
         Item.Error := I18N.Errors.Parse_Error;
         return;
      end if;

      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open
           (File => File, Mode => Ada.Text_IO.In_File, Name => Catalog_Path);

         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               Parse_Default_Locale_Line (Item, Line);
               exit when not Item.Valid;
            end;
         end loop;

         Ada.Text_IO.Close (File);

         if not Item.Valid then
            return;
         end if;

         Ada.Text_IO.Open
           (File => File, Mode => Ada.Text_IO.In_File, Name => Catalog_Path);

         while not Ada.Text_IO.End_Of_File (File) loop
            declare
               Line : constant String := Ada.Text_IO.Get_Line (File);
            begin
               Parse_Catalog_Line (Item, Line);
               exit when not Item.Valid;
            end;
         end loop;

         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            Item.Valid := False;
            Item.Error := I18N.Errors.Parse_Error;
      end;

      if Item.Valid and then Item.Catalog.Is_Empty then
         Item.Valid := False;
         Item.Error := I18N.Errors.Validation_Error;
      end if;
   end Initialize;

   procedure Find_Source
     (Item   : Runtime;
      Locale : String;
      Key    : String;
      Found  : out Boolean;
      Source : out Unbounded_String)
   is
      Wanted_Locale : constant String := Trimmed (Locale);
      Wanted_Key    : constant String := Trimmed (Key);
   begin
      for Catalog_Item of Item.Catalog loop
         if To_String (Catalog_Item.Locale) = Wanted_Locale
           and then To_String (Catalog_Item.Message_Key) = Wanted_Key
         then
            Found := True;
            Source := Catalog_Item.Source;
            return;
         end if;
      end loop;

      Found := False;
      Source := Null_Unbounded_String;
   end Find_Source;

   function To_Public_Status
     (Kind : I18N.Errors.Error_Kind) return I18N.Result.Render_Status is
   begin
      case Kind is
         when I18N.Errors.Missing_Variable                               =>
            return I18N.Result.Missing_Argument;

         when I18N.Errors.Invalid_Selector | I18N.Errors.Invalid_Ordinal =>
            return I18N.Result.Invalid_Argument;

         when I18N.Errors.Buffer_Overflow                                =>
            return I18N.Result.Buffer_Overflow;

         when I18N.Errors.Missing_Branch                                 =>
            return I18N.Result.Formatting_Error;

         when I18N.Errors.Parse_Error
            | I18N.Errors.Validation_Error
            | I18N.Errors.Unbalanced_Braces                              =>
            return I18N.Result.Execution_Error;
      end case;
   end To_Public_Status;

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
         if C = '#' and then Active then
            Append (Result, Number_Text);
         else
            Append (Result, C);
         end if;
      end loop;

      return To_String (Result);
   end Substitute_Number;

   function Normalized_Source (Source : String) return String is
   begin
      return Unquote (Source);
   end Normalized_Source;

   function Contains_Complex_ICU (Source : String) return Boolean is
   begin
      return
        Ada.Strings.Fixed.Index (Source, ", plural") /= 0
        or else Ada.Strings.Fixed.Index (Source, ",plural") /= 0
        or else Ada.Strings.Fixed.Index (Source, ", select") /= 0
        or else Ada.Strings.Fixed.Index (Source, ",select") /= 0
        or else Ada.Strings.Fixed.Index (Source, ", selectordinal") /= 0
        or else Ada.Strings.Fixed.Index (Source, ",selectordinal") /= 0;
   end Contains_Complex_ICU;

   function Render_Simple_Source
     (Source : String; Arguments : I18N.Arguments.Arguments)
      return I18N.Result.Render_Result
   is
      Output      : Unbounded_String;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
      Pos         : Positive := Source'First;
   begin
      I18N.Observability.Emit (I18N.Observability.Message_Start, "");

      if Source'Length = 0 then
         I18N.Observability.Emit (I18N.Observability.Message_End, "");
         return
           (Status      => I18N.Result.Success,
            Text        => I18N.Result.To_Output_View (""),
            Diagnostics => Diagnostics);
      end if;

      while Pos <= Source'Last loop
         if Source (Pos) = '{' then
            declare
               Close_Pos : Natural := 0;
            begin
               for Index in Pos + 1 .. Source'Last loop
                  if Source (Index) = '}' then
                     Close_Pos := Index;
                     exit;
                  elsif Source (Index) = '{' then
                     return
                       Public_Failure
                         (Status      => I18N.Result.Execution_Error,
                          Diagnostics => Diagnostics);
                  end if;
               end loop;

               if Close_Pos = 0 then
                  return
                    Public_Failure
                      (Status      => I18N.Result.Execution_Error,
                       Diagnostics => Diagnostics);
               end if;

               declare
                  Name : constant String :=
                    Trimmed (Source (Pos + 1 .. Close_Pos - 1));
               begin
                  if Name'Length = 0
                    or else Ada.Strings.Fixed.Index (Name, ",") /= 0
                  then
                     return
                       Public_Failure
                         (Status      => I18N.Result.Execution_Error,
                          Diagnostics => Diagnostics);
                  end if;

                  I18N.Observability.Emit
                    (I18N.Observability.Op_Variable, Name);
                  if I18N.Arguments.Has (Arguments, Name) then
                     Append (Output, I18N.Arguments.Get (Arguments, Name));
                  else
                     Add_Runtime_Diagnostic
                       (Diagnostics => Diagnostics,
                        Status      => I18N.Result.Missing_Argument,
                        Key         => Name);
                     return
                       Public_Failure
                         (Status      => I18N.Result.Missing_Argument,
                          Diagnostics => Diagnostics);
                  end if;
               end;

               Pos := Close_Pos + 1;
            end;
         elsif Source (Pos) = '}' then
            return
              Public_Failure
                (Status      => I18N.Result.Execution_Error,
                 Diagnostics => Diagnostics);
         else
            I18N.Observability.Emit (I18N.Observability.Op_Text, "");
            Append (Output, Source (Pos));
            Pos := Pos + 1;
         end if;
      end loop;

      I18N.Observability.Emit (I18N.Observability.Message_End, "");

      if Length (Output) > I18N.Result.Max_Output_Length then
         Add_Runtime_Diagnostic
           (Diagnostics => Diagnostics,
            Status      => I18N.Result.Buffer_Overflow,
            Key         => "output");
         return
           Public_Failure
             (Status      => I18N.Result.Buffer_Overflow,
              Diagnostics => Diagnostics);
      end if;

      return
        (Status      => I18N.Result.Success,
         Text        => I18N.Result.To_Output_View (To_String (Output)),
         Diagnostics => Diagnostics);
   exception
      when others =>
         return I18N.Result.Failure (I18N.Result.Internal_Error);
   end Render_Simple_Source;

   procedure Render_Public_Nodes
     (Root          : I18N.AST.Node_Access;
      Arguments     : I18N.Arguments.Arguments;
      Output        : in out Unbounded_String;
      Status        : in out I18N.Result.Render_Status;
      Diagnostics   : in out I18N.Diagnostics.Diagnostic_List;
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
                              Branch   : constant I18N.AST.Node_Access :=
                                (if Value = 1
                                 then Current.One
                                 else Current.Other);
                           begin
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
                        Value  : constant String :=
                          I18N.Arguments.Get (Arguments, Key);
                        Branch : constant I18N.AST.Node_Access :=
                          (if Value = "male"
                           then Current.Male
                           elsif Value = "female"
                           then Current.Female
                           else Current.Select_Other);
                     begin
                        if Branch = null then
                           Status := I18N.Result.Formatting_Error;
                           Add_Runtime_Diagnostic (Diagnostics, Status, Key);
                        else
                           Render_Public_Nodes
                             (Root          => Branch,
                              Arguments     => Arguments,
                              Output        => Output,
                              Status        => Status,
                              Diagnostics   => Diagnostics,
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
                              Branch   : I18N.AST.Node_Access :=
                                Current.Ord_Other;
                           begin
                              if Value = 1 then
                                 Branch := Current.Ord_One;
                              elsif Value = 2 then
                                 Branch := Current.Ord_Two;
                              elsif Value = 3 then
                                 Branch := Current.Ord_Few;
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

   function Render_Source
     (Source : String; Arguments : I18N.Arguments.Arguments)
      return I18N.Result.Render_Result
   is
      Normal_Source : constant String := Normalized_Source (Source);
      Root          : I18N.AST.Node_Access := null;
      Output        : Unbounded_String;
      Status        : I18N.Result.Render_Status := I18N.Result.Success;
      Diagnostics   : I18N.Diagnostics.Diagnostic_List;
   begin
      if Normal_Source'Length = 0 then
         return
           (Status      => I18N.Result.Success,
            Text        => I18N.Result.To_Output_View (""),
            Diagnostics => Diagnostics);
      elsif not Contains_Complex_ICU (Normal_Source) then
         return Render_Simple_Source (Normal_Source, Arguments);
      end if;

      I18N.Observability.Emit (I18N.Observability.Message_Start, "");

      begin
         Root := I18N.Parser.Parse (Normal_Source);
      exception
         when I18N.Parser.Parse_Error =>
            I18N.AST.Free (Root);
            return
              Public_Failure
                (Status      => I18N.Result.Execution_Error,
                 Diagnostics => Diagnostics);
         when others =>
            I18N.AST.Free (Root);
            return I18N.Result.Failure (I18N.Result.Execution_Error);
      end;

      declare
         Validation_Result : constant I18N.Errors.Result :=
           I18N.Validation.Validate (Root);
      begin
         if not Validation_Result.Ok then
            I18N.AST.Free (Root);
            return
              Public_Failure
                (Status      => To_Public_Status (Validation_Result.Error),
                 Diagnostics => Validation_Result.Diagnostics);
         end if;
      end;

      Render_Public_Nodes
        (Root        => Root,
         Arguments   => Arguments,
         Output      => Output,
         Status      => Status,
         Diagnostics => Diagnostics);

      I18N.AST.Free (Root);
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
         I18N.AST.Free (Root);
         return I18N.Result.Failure (I18N.Result.Internal_Error);
   end Render_Source;

   function Render
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments) return I18N.Result.Render_Result
   is
      Current : Unbounded_String := To_Unbounded_String (Locale);
      Source  : Unbounded_String;
      Found   : Boolean := False;
   begin
      if not Item.Valid then
         return I18N.Result.Failure (I18N.Result.Execution_Error);
      end if;

      loop
         Find_Source
           (Item   => Item,
            Locale => Trimmed (To_String (Current)),
            Key    => Trimmed (Key),
            Found  => Found,
            Source => Source);

         if Found then
            return Render_Source (To_String (Source), Arguments);
         end if;

         declare
            Parent : constant String :=
              I18N.Locales.Parent (To_String (Current));
         begin
            exit when Parent'Length = 0;
            Current := To_Unbounded_String (Parent);
         end;
      end loop;

      if To_String (Item.Default_Locale) /= Locale then
         Find_Source
           (Item   => Item,
            Locale => Trimmed (To_String (Item.Default_Locale)),
            Key    => Trimmed (Key),
            Found  => Found,
            Source => Source);

         if Found then
            return Render_Source (To_String (Source), Arguments);
         end if;
      end if;

      return I18N.Result.Failure (I18N.Result.Missing_Key);
   exception
      when others =>
         return I18N.Result.Failure (I18N.Result.Internal_Error);
   end Render;

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
      Item.Catalog.Clear;
      Item.Default_Locale :=
        To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Item.Default_Locale_Seen := False;
   end Finalize;

end I18N.Runtime;
