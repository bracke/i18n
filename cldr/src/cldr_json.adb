with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Cldr_Json is

   HT : constant Character := Character'Val (16#09#);
   LF : constant Character := Character'Val (16#0A#);
   CR : constant Character := Character'Val (16#0D#);

   function Read_File (Path : String) return String is
      use Ada.Streams;
      use Ada.Streams.Stream_IO;
      F   : File_Type;
      Len : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Open (F, In_File, Path);
      Len := Natural (Ada.Directories.Size (Path));
      declare
         Buf    : Stream_Element_Array (1 .. 65536);
         Last   : Stream_Element_Offset;
         Result : String (1 .. Len);
         Pos    : Natural := 0;
      begin
         loop
            Read (F, Buf, Last);
            for I in 1 .. Natural (Last) loop
               Pos := Pos + 1;
               Result (Pos) := Character'Val (Buf (Stream_Element_Offset (I)));
            end loop;
            exit when Last < Buf'Last;
         end loop;
         Close (F);
         return Result (1 .. Pos);
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
         return "";
   end Read_File;

   procedure For_Each
     (Text    : String;
      Process : not null access procedure (Name : String; Value : String))
   is
      Index   : Natural := Text'First;
      In_Text : Boolean;

      procedure Skip_WS is
      begin
         while Index <= Text'Last
           and then Text (Index) in ' ' | HT | CR | LF
         loop
            Index := Index + 1;
         end loop;
      end Skip_WS;

      function Read_String return String is
         First : Natural;
      begin
         if Index > Text'Last or else Text (Index) /= '"' then
            return "";
         end if;
         Index := Index + 1;
         First := Index;
         while Index <= Text'Last loop
            if Text (Index) = '\' then
               Index := Index + 2;
            elsif Text (Index) = '"' then
               declare
                  Result : constant String := Text (First .. Index - 1);
               begin
                  Index := Index + 1;
                  return Result;
               end;
            else
               Index := Index + 1;
            end if;
         end loop;
         return "";
      end Read_String;

      function Read_Value return String is
         First : constant Natural := Index;
         Depth : Natural := 0;
      begin
         if Index > Text'Last then
            return "";
         elsif Text (Index) = '{' or else Text (Index) = '[' then
            In_Text := False;
            while Index <= Text'Last loop
               if Text (Index) = '"' then
                  In_Text := not In_Text;
               elsif In_Text and then Text (Index) = '\' then
                  Index := Index + 1;
               elsif not In_Text then
                  if Text (Index) in '{' | '[' then
                     Depth := Depth + 1;
                  elsif Text (Index) in '}' | ']' then
                     Depth := Depth - 1;
                     if Depth = 0 then
                        Index := Index + 1;
                        return Text (First .. Index - 1);
                     end if;
                  end if;
               end if;
               Index := Index + 1;
            end loop;
         elsif Text (Index) = '"' then
            return Read_String;
         else
            while Index <= Text'Last and then Text (Index) not in ',' | '}' loop
               Index := Index + 1;
            end loop;
            return Text (First .. Index - 1);
         end if;
         return "";
      end Read_Value;
   begin
      Skip_WS;
      if Index > Text'Last or else Text (Index) /= '{' then
         return;
      end if;
      Index := Index + 1;
      loop
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) = '}';
         declare
            Name : constant String := Read_String;
         begin
            Skip_WS;
            exit when Index > Text'Last or else Text (Index) /= ':';
            Index := Index + 1;
            Skip_WS;
            declare
               Value : constant String := Read_Value;
            begin
               Process (Name, Value);
            end;
         end;
         Skip_WS;
         exit when Index > Text'Last or else Text (Index) /= ',';
         Index := Index + 1;
      end loop;
   end For_Each;

   function Field (Text : String; Name : String) return String is
      Found : Unbounded_String;

      procedure Capture (N : String; Value : String) is
      begin
         if N = Name and then Length (Found) = 0 then
            Found := To_Unbounded_String (Value);
         end if;
      end Capture;
   begin
      For_Each (Text, Capture'Access);
      return To_String (Found);
   end Field;

   procedure For_Each_String
     (Array_Text : String;
      Process    : not null access procedure (Value : String))
   is
      I : Natural := Array_Text'First;
   begin
      while I <= Array_Text'Last and then Array_Text (I) /= '[' loop
         I := I + 1;
      end loop;
      if I > Array_Text'Last then
         return;
      end if;
      I := I + 1;
      loop
         while I <= Array_Text'Last
           and then Array_Text (I) in ' ' | HT | CR | LF | ','
         loop
            I := I + 1;
         end loop;
         exit when I > Array_Text'Last or else Array_Text (I) /= '"';

         declare
            First : constant Natural := I + 1;
         begin
            I := I + 1;
            while I <= Array_Text'Last loop
               if Array_Text (I) = '\' then
                  I := I + 2;
               elsif Array_Text (I) = '"' then
                  exit;
               else
                  I := I + 1;
               end if;
            end loop;
            Process (Array_Text (First .. I - 1));
            I := I + 1;   --  past the closing quote
         end;
      end loop;
   end For_Each_String;

   procedure For_Each_Pair
     (Array_Text : String;
      Process    : not null access procedure (A : String; B : String))
   is
      I : Natural := Array_Text'First;

      --  Read the string starting at the next '"' at or after I; advance I past
      --  its closing quote. "" if none.
      function Read_At return String is
         First : Natural;
      begin
         while I <= Array_Text'Last and then Array_Text (I) /= '"' loop
            I := I + 1;
         end loop;
         if I > Array_Text'Last then
            return "";
         end if;
         I := I + 1;
         First := I;
         while I <= Array_Text'Last loop
            if Array_Text (I) = '\' then
               I := I + 2;
            elsif Array_Text (I) = '"' then
               declare
                  R : constant String := Array_Text (First .. I - 1);
               begin
                  I := I + 1;
                  return R;
               end;
            else
               I := I + 1;
            end if;
         end loop;
         return "";
      end Read_At;
   begin
      --  Skip to the outer '['.
      while I <= Array_Text'Last and then Array_Text (I) /= '[' loop
         I := I + 1;
      end loop;
      if I <= Array_Text'Last then
         I := I + 1;
      end if;

      loop
         --  Find the next inner '[' before the outer ']'.
         while I <= Array_Text'Last
           and then Array_Text (I) /= '[' and then Array_Text (I) /= ']'
         loop
            I := I + 1;
         end loop;
         exit when I > Array_Text'Last or else Array_Text (I) = ']';
         I := I + 1;   --  past the inner '['
         declare
            A : constant String := Read_At;
            B : constant String := Read_At;
         begin
            Process (A, B);
         end;
         --  Skip to the inner ']'.
         while I <= Array_Text'Last and then Array_Text (I) /= ']' loop
            I := I + 1;
         end loop;
         if I <= Array_Text'Last then
            I := I + 1;   --  past inner ']'
         end if;
      end loop;
   end For_Each_Pair;

   function Unescape (Raw : String) return String is
      Result : String (1 .. Raw'Length * 2);
      Last   : Natural := 0;
      I      : Natural := Raw'First;

      procedure Put (C : Character) is
      begin
         Last := Last + 1;
         Result (Last) := C;
      end Put;

      procedure Put_Code_Point (CP : Natural) is
      begin
         if CP <= 16#7F# then
            Put (Character'Val (CP));
         elsif CP <= 16#7FF# then
            Put (Character'Val (16#C0# + CP / 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         elsif CP <= 16#FFFF# then
            Put (Character'Val (16#E0# + CP / 16#1000#));
            Put (Character'Val (16#80# + (CP / 16#40#) mod 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         else
            Put (Character'Val (16#F0# + CP / 16#40000#));
            Put (Character'Val (16#80# + (CP / 16#1000#) mod 16#40#));
            Put (Character'Val (16#80# + (CP / 16#40#) mod 16#40#));
            Put (Character'Val (16#80# + CP mod 16#40#));
         end if;
      end Put_Code_Point;

      function Hex (C : Character) return Natural is
        (case C is
            when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
            when 'a' .. 'f' => 10 + Character'Pos (C) - Character'Pos ('a'),
            when 'A' .. 'F' => 10 + Character'Pos (C) - Character'Pos ('A'),
            when others     => 0);
   begin
      while I <= Raw'Last loop
         if Raw (I) = '\' and then I < Raw'Last then
            case Raw (I + 1) is
               when '"'  => Put ('"'); I := I + 2;
               when '\'  => Put ('\'); I := I + 2;
               when '/'  => Put ('/'); I := I + 2;
               when 'n'  => Put (LF);  I := I + 2;
               when 't'  => Put (HT);  I := I + 2;
               when 'r'  => Put (CR);  I := I + 2;
               when 'b'  => Put (Character'Val (8));  I := I + 2;
               when 'f'  => Put (Character'Val (12)); I := I + 2;
               when 'u'  =>
                  if I + 5 <= Raw'Last then
                     declare
                        CP : constant Natural :=
                          Hex (Raw (I + 2)) * 16#1000#
                          + Hex (Raw (I + 3)) * 16#100#
                          + Hex (Raw (I + 4)) * 16#10#
                          + Hex (Raw (I + 5));
                        Lo : Natural;
                     begin
                        if CP in 16#D800# .. 16#DBFF#
                          and then I + 11 <= Raw'Last
                          and then Raw (I + 6) = '\' and then Raw (I + 7) = 'u'
                        then
                           Lo := Hex (Raw (I + 8)) * 16#1000#
                             + Hex (Raw (I + 9)) * 16#100#
                             + Hex (Raw (I + 10)) * 16#10#
                             + Hex (Raw (I + 11));
                           Put_Code_Point
                             (16#10000#
                              + (CP - 16#D800#) * 16#400#
                              + (Lo - 16#DC00#));
                           I := I + 12;
                        else
                           Put_Code_Point (CP);
                           I := I + 6;
                        end if;
                     end;
                  else
                     I := I + 2;
                  end if;
               when others => Put (Raw (I + 1)); I := I + 2;
            end case;
         else
            Put (Raw (I));
            I := I + 1;
         end if;
      end loop;
      return Result (1 .. Last);
   end Unescape;

end Cldr_Json;
