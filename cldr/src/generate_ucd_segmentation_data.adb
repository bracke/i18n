--  Build share/i18n/segmentation.i18ndata from the UCD break-property files.
--  One section "seg" with six whole-table records (sorted keys): each value is a
--  sorted list of "lo:hi:PROP" ranges the engine parses once and binary-searches.
--    extpict  Extended_Pictographic (emoji-data.txt)      -> E
--    gcb      Grapheme_Cluster_Break                       -> Control/CR/.../ZWJ
--    incb     Indic_Conjunct_Break (DerivedCoreProperties) -> Consonant/Extend/Linker
--    line     Line_Break (LineBreak.txt)                   -> AL/CM/.../ZWJ
--    sentence Sentence_Break
--    word     Word_Break
with Ada.Text_IO;            use Ada.Text_IO;
with Ada.Strings;           use Ada.Strings;
with Ada.Strings.Fixed;     use Ada.Strings.Fixed;
with Ada.Containers.Vectors;

procedure Generate_UCD_Segmentation_Data is

   UCD : constant String := "upstream/ucd/";
   Out_Path : constant String := "../share/i18n/segmentation.i18ndata";

   type Rng is record
      Lo, Hi : Natural;
      Prop   : String (1 .. 24);
      P_Last : Natural;
   end record;

   package Rng_Vectors is new Ada.Containers.Vectors (Positive, Rng);
   use Rng_Vectors;

   function Hex (S : String) return Natural is
      V : Natural := 0;
   begin
      for C of S loop
         case C is
            when '0' .. '9' => V := V * 16 + (Character'Pos (C) - 48);
            when 'A' .. 'F' => V := V * 16 + (Character'Pos (C) - 55);
            when 'a' .. 'f' => V := V * 16 + (Character'Pos (C) - 87);
            when others => null;
         end case;
      end loop;
      return V;
   end Hex;

   function Hex_Img (V : Natural) return String is
      D : constant String := "0123456789ABCDEF";
      N : Natural := V;
      R : String (1 .. 8);
      I : Natural := R'Last;
   begin
      if V = 0 then
         return "0";
      end if;
      while N > 0 loop
         R (I) := D (N mod 16 + 1);
         N := N / 16;
         I := I - 1;
      end loop;
      return R (I + 1 .. R'Last);
   end Hex_Img;

   procedure Mk (Lo, Hi : Natural; P : String; V : in out Rng_Vectors.Vector) is
      R : Rng;
   begin
      R.Lo := Lo;
      R.Hi := Hi;
      R.P_Last := P'Length;
      R.Prop (1 .. P'Length) := P;
      V.Append (R);
   end Mk;

   --  The vectors accumulate ranges per dimension.
   V_GCB, V_Ext, V_InCB, V_Word, V_Sent, V_Line : Rng_Vectors.Vector;
   V_EAW, V_GC, V_ExtCn : Rng_Vectors.Vector;

   --  Assigned code points (from UnicodeData.txt), used to derive the
   --  Extended_Pictographic & Cn set that line breaking's LB30b needs.
   Assigned : array (0 .. 16#10FFFF#) of Boolean := [others => False];

   --  General_Category (Mn/Mc/Pi/Pf) from UnicodeData.txt: needed by the line
   --  breaker (SA resolution, Pi/Pf quotation). UnicodeData is ';'-delimited
   --  with the category in field 2; the categories we keep never use the
   --  First>/<Last range blocks, so single code points suffice.
   procedure Load_GC (V : in out Rng_Vectors.Vector) is
      F         : File_Type;
      Range_Lo  : Natural := 0;
      In_Range  : Boolean := False;
   begin
      Open (F, In_File, UCD & "UnicodeData.txt");
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            S1   : constant Natural := Index (Line, ";");
         begin
            if S1 /= 0 then
               declare
                  CPv    : constant Natural := Hex (Line (Line'First .. S1 - 1));
                  After1 : constant String := Line (S1 + 1 .. Line'Last);
                  S2     : constant Natural := Index (After1, ";");
                  Name   : constant String :=
                    (if S2 = 0 then After1 else After1 (After1'First .. S2 - 1));
               begin
                  --  Mark assigned code points (handling First>/<Last blocks).
                  if Name'Length >= 6
                    and then Name (Name'Last - 5 .. Name'Last) = "First>"
                  then
                     Range_Lo := CPv; In_Range := True;
                  elsif In_Range
                    and then Name'Length >= 5
                    and then Name (Name'Last - 4 .. Name'Last) = "Last>"
                  then
                     for K in Range_Lo .. CPv loop
                        Assigned (K) := True;
                     end loop;
                     In_Range := False;
                  else
                     Assigned (CPv) := True;
                  end if;
                  --  Collect Mn/Mc/Pi/Pf.
                  if S2 /= 0 then
                     declare
                        After2 : constant String :=
                          After1 (S2 + 1 .. After1'Last);
                        S3     : constant Natural := Index (After2, ";");
                        GC     : constant String :=
                          (if S3 = 0 then After2
                           else After2 (After2'First .. S3 - 1));
                     begin
                        if GC = "Mn" or else GC = "Mc" or else GC = "Pi"
                          or else GC = "Pf"
                        then
                           Mk (CPv, CPv, GC, V);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Load_GC;

   --  Extended_Pictographic code points that are unassigned (Cn): iterate the
   --  ExtPict ranges and keep the gaps not covered by UnicodeData.
   procedure Build_ExtCn (V : in out Rng_Vectors.Vector) is
   begin
      for R of V_Ext loop
         declare
            Run_Lo : Natural := 0;
            In_Run : Boolean := False;
         begin
            for K in R.Lo .. R.Hi loop
               if not Assigned (K) then
                  if not In_Run then
                     Run_Lo := K; In_Run := True;
                  end if;
               elsif In_Run then
                  Mk (Run_Lo, K - 1, "E", V);
                  In_Run := False;
               end if;
            end loop;
            if In_Run then
               Mk (Run_Lo, R.Hi, "E", V);
            end if;
         end;
      end loop;
   end Build_ExtCn;

   --  Read a UCD property file, appending ranges whose second ';' field passes
   --  Keep, mapping the raw property name via Map, into vector V.
   generic
      with function Keep (Field2, Field3 : String) return Boolean;
      with function Map (Field2, Field3 : String) return String;
   procedure Load (Name : String; V : in out Rng_Vectors.Vector);

   procedure Load (Name : String; V : in out Rng_Vectors.Vector) is
      F : File_Type;
   begin
      Open (F, In_File, UCD & Name);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
            Hash : constant Natural :=
              (if Index (Line, "#") = 0 then Line'Last + 1
               else Index (Line, "#"));
            --  Note: emoji-data has "Prop# comment" with no space before #.
            Bdy  : constant String := Line (Line'First .. Hash - 1);
            S1   : constant Natural := Index (Bdy, ";");
         begin
            if S1 /= 0 then
               declare
                  CPs : constant String :=
                    Trim (Bdy (Bdy'First .. S1 - 1), Both);
                  Rest : constant String := Bdy (S1 + 1 .. Bdy'Last);
                  S2   : constant Natural := Index (Rest, ";");
                  F2   : constant String :=
                    Trim ((if S2 = 0 then Rest
                           else Rest (Rest'First .. S2 - 1)), Both);
                  F3   : constant String :=
                    Trim ((if S2 = 0 then "" else Rest (S2 + 1 .. Rest'Last)),
                          Both);
                  Dots : constant Natural := Index (CPs, "..");
               begin
                  if CPs /= "" and then F2 /= "" and then Keep (F2, F3) then
                     declare
                        Lo : constant Natural :=
                          (if Dots = 0 then Hex (CPs)
                           else Hex (CPs (CPs'First .. Dots - 1)));
                        Hi : constant Natural :=
                          (if Dots = 0 then Lo
                           else Hex (CPs (Dots + 2 .. CPs'Last)));
                        P  : constant String := Map (F2, F3);
                     begin
                        Mk (Lo, Hi, P, V);
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      Close (F);
   end Load;

   --  Small classifier/mapper functions passed as generic actuals; each ignores
   --  one of the two ';'-separated fields.
   pragma Warnings (Off, "formal parameter * is not referenced");
   function Keep_F2 (F2, F3 : String) return String is (F2);
   function Yes (F2, F3 : String) return Boolean is (True);
   function Is_ExtPict (F2, F3 : String) return Boolean is
     (F2 = "Extended_Pictographic");
   function As_E (F2, F3 : String) return String is ("E");
   function Is_InCB (F2, F3 : String) return Boolean is
     (F2 = "InCB" and then F3 /= "None");
   function InCB_Val (F2, F3 : String) return String is (F3);
   function Is_Wide (F2, F3 : String) return Boolean is
     (F2 = "W" or else F2 = "F" or else F2 = "H");
   function As_W (F2, F3 : String) return String is ("W");
   pragma Warnings (On, "formal parameter * is not referenced");

   procedure Load_GCB  is new Load (Yes, Keep_F2);
   procedure Load_Ext  is new Load (Is_ExtPict, As_E);
   procedure Load_InCB is new Load (Is_InCB, InCB_Val);
   procedure Load_Word is new Load (Yes, Keep_F2);
   procedure Load_Sent is new Load (Yes, Keep_F2);
   procedure Load_Line is new Load (Yes, Keep_F2);
   procedure Load_EAW  is new Load (Is_Wide, As_W);

   function Lo_Less (A, B : Rng) return Boolean is (A.Lo < B.Lo);
   package Sorting is new Rng_Vectors.Generic_Sorting ("<" => Lo_Less);

   procedure Sort_By_Lo (V : in out Rng_Vectors.Vector) is
   begin
      Sorting.Sort (V);
   end Sort_By_Lo;

   Out_F : File_Type;

   procedure Emit_Record (Key : String; V : in out Rng_Vectors.Vector) is
   begin
      Sort_By_Lo (V);
      Put (Out_F, Key & Character'Val (16#09#));
      declare
         First : Boolean := True;
      begin
         for R of V loop
            if not First then
               Put (Out_F, " ");
            end if;
            First := False;
            Put (Out_F, Hex_Img (R.Lo) & ":" & Hex_Img (R.Hi) & ":"
                 & R.Prop (1 .. R.P_Last));
         end loop;
      end;
      New_Line (Out_F);
   end Emit_Record;

begin
   Load_GCB  ("auxiliary/GraphemeBreakProperty.txt", V_GCB);
   Load_Ext  ("emoji/emoji-data.txt", V_Ext);
   Load_InCB ("DerivedCoreProperties.txt", V_InCB);
   Load_Word ("auxiliary/WordBreakProperty.txt", V_Word);
   Load_Sent ("auxiliary/SentenceBreakProperty.txt", V_Sent);
   Load_Line ("LineBreak.txt", V_Line);
   Load_EAW  ("EastAsianWidth.txt", V_EAW);
   Load_GC   (V_GC);
   Build_ExtCn (V_ExtCn);

   Create (Out_F, Out_File, Out_Path);
   Put_Line (Out_F, "I18NDATA|1|17.0.0");
   Put_Line (Out_F, "@seg|9");
   --  Sorted record keys: eaw < extcn < extpict < gc < gcb < incb < line
   --  < sentence < word.
   Emit_Record ("eaw", V_EAW);
   Emit_Record ("extcn", V_ExtCn);
   Emit_Record ("extpict", V_Ext);
   Emit_Record ("gc", V_GC);
   Emit_Record ("gcb", V_GCB);
   Emit_Record ("incb", V_InCB);
   Emit_Record ("line", V_Line);
   Emit_Record ("sentence", V_Sent);
   Emit_Record ("word", V_Word);
   Close (Out_F);

   Put_Line ("segmentation.i18ndata written:"
             & Integer'Image (Integer (V_GCB.Length)) & " gcb,"
             & Integer'Image (Integer (V_Ext.Length)) & " extpict,"
             & Integer'Image (Integer (V_InCB.Length)) & " incb,"
             & Integer'Image (Integer (V_Word.Length)) & " word,"
             & Integer'Image (Integer (V_Sent.Length)) & " sentence,"
             & Integer'Image (Integer (V_Line.Length)) & " line");
end Generate_UCD_Segmentation_Data;
