with I18N.Data_Store;

package body I18N.Segmentation is

   type CP is range 0 .. 16#10FFFF#;

   --  ------------------------------------------------------------------
   --  Property value enumerations (one per boundary dimension)
   --  ------------------------------------------------------------------

   type GCB is
     (GCB_Other, GCB_CR, GCB_LF, GCB_Control, GCB_Extend, GCB_ZWJ, GCB_RI,
      GCB_Prepend, GCB_SpacingMark, GCB_L, GCB_V, GCB_T, GCB_LV, GCB_LVT);

   type ICB is (ICB_None, ICB_Consonant, ICB_Extend, ICB_Linker);

   type WB is
     (WB_Other, WB_CR, WB_LF, WB_Newline, WB_Extend, WB_ZWJ, WB_RI, WB_Format,
      WB_Katakana, WB_HebrewLetter, WB_ALetter, WB_SingleQuote, WB_DoubleQuote,
      WB_MidNumLet, WB_MidLetter, WB_MidNum, WB_Numeric, WB_ExtendNumLet,
      WB_WSegSpace);

   type SB is
     (SB_Other, SB_CR, SB_LF, SB_Extend, SB_Sep, SB_Format, SB_Sp, SB_Lower,
      SB_Upper, SB_OLetter, SB_Numeric, SB_ATerm, SB_SContinue, SB_STerm,
      SB_Close);

   type LB is
     (LB_XX, LB_AI, LB_AK, LB_AL, LB_AP, LB_AS, LB_B2, LB_BA, LB_BB, LB_BK,
      LB_CB, LB_CJ, LB_CL, LB_CM, LB_CP, LB_CR, LB_EB, LB_EM, LB_EX, LB_GL,
      LB_H2, LB_H3, LB_HH, LB_HL, LB_HY, LB_ID, LB_IN, LB_IS, LB_JL, LB_JT,
      LB_JV, LB_LF, LB_NL, LB_NS, LB_NU, LB_OP, LB_PO, LB_PR, LB_QU, LB_RI,
      LB_SA, LB_SG, LB_SP, LB_SY, LB_VF, LB_VI, LB_WJ, LB_ZW, LB_ZWJ);

   type GC is (GC_Other, GC_Mn, GC_Mc, GC_Pi, GC_Pf);

   --  ------------------------------------------------------------------
   --  Range tables
   --  ------------------------------------------------------------------

   type Seg_Range is record
      Lo, Hi : CP;
      Code   : Natural;
   end record;
   type Range_Array is array (Positive range <>) of Seg_Range;
   type Range_Access is access Range_Array;

   Tab_Ext, Tab_GCB, Tab_ICB, Tab_Line, Tab_Sent, Tab_Word : Range_Access;
   Tab_EAW, Tab_GC, Tab_ExtCn : Range_Access;
   Loaded    : Boolean := False;
   Have_Data : Boolean := False;

   function Hex_Val (S : String) return Natural is
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
   end Hex_Val;

   --  Parse a "lo:hi:NAME lo:hi:NAME ..." value into a Range_Array, mapping the
   --  property name via Code_Of.
   function Parse_Table
     (S : String; Code_Of : not null access function (N : String) return Natural)
      return Range_Access
   is
      Count : Natural := 0;
   begin
      if S'Length > 0 then
         Count := 1;
         for C of S loop
            if C = ' ' then
               Count := Count + 1;
            end if;
         end loop;
      end if;
      declare
         Result : constant Range_Access := new Range_Array (1 .. Count);
         Idx    : Natural := 0;
         I      : Natural := S'First;
      begin
         while I <= S'Last loop
            declare
               J : Natural := I;
            begin
               while J <= S'Last and then S (J) /= ' ' loop
                  J := J + 1;
               end loop;
               --  Token S (I .. J-1) = "lo:hi:NAME".
               declare
                  Tok : String renames S (I .. J - 1);
                  C1  : Natural := Tok'First;
                  C2  : Natural;
               begin
                  while C1 <= Tok'Last and then Tok (C1) /= ':' loop
                     C1 := C1 + 1;
                  end loop;
                  C2 := C1 + 1;
                  while C2 <= Tok'Last and then Tok (C2) /= ':' loop
                     C2 := C2 + 1;
                  end loop;
                  Idx := Idx + 1;
                  Result (Idx) :=
                    (Lo   => CP (Hex_Val (Tok (Tok'First .. C1 - 1))),
                     Hi   => CP (Hex_Val (Tok (C1 + 1 .. C2 - 1))),
                     Code => Code_Of (Tok (C2 + 1 .. Tok'Last)));
               end;
               I := J + 1;
            end;
         end loop;
         return Result;
      end;
   end Parse_Table;

   function Lookup (Tab : Range_Access; C : CP; Default : Natural) return Natural is
      Lo : Natural := Tab'First;
      Hi : Natural := Tab'Last;
   begin
      while Lo <= Hi loop
         declare
            Mid : constant Natural := (Lo + Hi) / 2;
         begin
            if C < Tab (Mid).Lo then
               Hi := Mid - 1;
            elsif C > Tab (Mid).Hi then
               Lo := Mid + 1;
            else
               return Tab (Mid).Code;
            end if;
         end;
      end loop;
      return Default;
   end Lookup;

   --  ------------------------------------------------------------------
   --  Name -> code mappers
   --  ------------------------------------------------------------------

   function GCB_Code (N : String) return Natural is
   begin
      if N = "CR" then
         return GCB'Pos (GCB_CR);
      elsif N = "LF" then
         return GCB'Pos (GCB_LF);
      elsif N = "Control" then
         return GCB'Pos (GCB_Control);
      elsif N = "Extend" then
         return GCB'Pos (GCB_Extend);
      elsif N = "ZWJ" then
         return GCB'Pos (GCB_ZWJ);
      elsif N = "Regional_Indicator" then
         return GCB'Pos (GCB_RI);
      elsif N = "Prepend" then
         return GCB'Pos (GCB_Prepend);
      elsif N = "SpacingMark" then
         return GCB'Pos (GCB_SpacingMark);
      elsif N = "L" then
         return GCB'Pos (GCB_L);
      elsif N = "V" then
         return GCB'Pos (GCB_V);
      elsif N = "T" then
         return GCB'Pos (GCB_T);
      elsif N = "LV" then
         return GCB'Pos (GCB_LV);
      elsif N = "LVT" then
         return GCB'Pos (GCB_LVT);
      else
         return GCB'Pos (GCB_Other);
      end if;
   end GCB_Code;

   function ICB_Code (N : String) return Natural is
   begin
      if N = "Consonant" then
         return ICB'Pos (ICB_Consonant);
      elsif N = "Extend" then
         return ICB'Pos (ICB_Extend);
      elsif N = "Linker" then
         return ICB'Pos (ICB_Linker);
      else
         return ICB'Pos (ICB_None);
      end if;
   end ICB_Code;

   function Ext_Code (N : String) return Natural is (if N = "E" then 1 else 0);

   function WB_Code (N : String) return Natural is
   begin
      if N = "CR" then
         return WB'Pos (WB_CR);
      elsif N = "LF" then
         return WB'Pos (WB_LF);
      elsif N = "Newline" then
         return WB'Pos (WB_Newline);
      elsif N = "Extend" then
         return WB'Pos (WB_Extend);
      elsif N = "ZWJ" then
         return WB'Pos (WB_ZWJ);
      elsif N = "Regional_Indicator" then
         return WB'Pos (WB_RI);
      elsif N = "Format" then
         return WB'Pos (WB_Format);
      elsif N = "Katakana" then
         return WB'Pos (WB_Katakana);
      elsif N = "Hebrew_Letter" then
         return WB'Pos (WB_HebrewLetter);
      elsif N = "ALetter" then
         return WB'Pos (WB_ALetter);
      elsif N = "Single_Quote" then
         return WB'Pos (WB_SingleQuote);
      elsif N = "Double_Quote" then
         return WB'Pos (WB_DoubleQuote);
      elsif N = "MidNumLet" then
         return WB'Pos (WB_MidNumLet);
      elsif N = "MidLetter" then
         return WB'Pos (WB_MidLetter);
      elsif N = "MidNum" then
         return WB'Pos (WB_MidNum);
      elsif N = "Numeric" then
         return WB'Pos (WB_Numeric);
      elsif N = "ExtendNumLet" then
         return WB'Pos (WB_ExtendNumLet);
      elsif N = "WSegSpace" then
         return WB'Pos (WB_WSegSpace);
      else
         return WB'Pos (WB_Other);
      end if;
   end WB_Code;

   function SB_Code (N : String) return Natural is
   begin
      if N = "CR" then
         return SB'Pos (SB_CR);
      elsif N = "LF" then
         return SB'Pos (SB_LF);
      elsif N = "Extend" then
         return SB'Pos (SB_Extend);
      elsif N = "Sep" then
         return SB'Pos (SB_Sep);
      elsif N = "Format" then
         return SB'Pos (SB_Format);
      elsif N = "Sp" then
         return SB'Pos (SB_Sp);
      elsif N = "Lower" then
         return SB'Pos (SB_Lower);
      elsif N = "Upper" then
         return SB'Pos (SB_Upper);
      elsif N = "OLetter" then
         return SB'Pos (SB_OLetter);
      elsif N = "Numeric" then
         return SB'Pos (SB_Numeric);
      elsif N = "ATerm" then
         return SB'Pos (SB_ATerm);
      elsif N = "SContinue" then
         return SB'Pos (SB_SContinue);
      elsif N = "STerm" then
         return SB'Pos (SB_STerm);
      elsif N = "Close" then
         return SB'Pos (SB_Close);
      else
         return SB'Pos (SB_Other);
      end if;
   end SB_Code;

   function LB_Code (N : String) return Natural is
      type Pair is record K : String (1 .. 2); V : LB; end record;
      Table : constant array (Positive range <>) of Pair :=
        [("AI", LB_AI), ("AK", LB_AK), ("AL", LB_AL), ("AP", LB_AP),
         ("AS", LB_AS), ("B2", LB_B2), ("BA", LB_BA), ("BB", LB_BB),
         ("BK", LB_BK), ("CB", LB_CB), ("CJ", LB_CJ), ("CL", LB_CL),
         ("CM", LB_CM), ("CP", LB_CP), ("CR", LB_CR), ("EB", LB_EB),
         ("EM", LB_EM), ("EX", LB_EX), ("GL", LB_GL), ("H2", LB_H2),
         ("H3", LB_H3), ("HH", LB_HH), ("HL", LB_HL), ("HY", LB_HY),
         ("ID", LB_ID), ("IN", LB_IN), ("IS", LB_IS), ("JL", LB_JL),
         ("JT", LB_JT), ("JV", LB_JV), ("LF", LB_LF), ("NL", LB_NL),
         ("NS", LB_NS), ("NU", LB_NU), ("OP", LB_OP), ("PO", LB_PO),
         ("PR", LB_PR), ("QU", LB_QU), ("RI", LB_RI), ("SA", LB_SA),
         ("SG", LB_SG), ("SP", LB_SP), ("SY", LB_SY), ("VF", LB_VF),
         ("VI", LB_VI), ("WJ", LB_WJ), ("ZW", LB_ZW)];
   begin
      if N'Length = 3 and then N = "ZWJ" then
         return LB'Pos (LB_ZWJ);
      end if;
      if N'Length = 2 then
         for P of Table loop
            if P.K = N then
               return LB'Pos (P.V);
            end if;
         end loop;
      end if;
      return LB'Pos (LB_XX);
   end LB_Code;

   function EAW_Code (N : String) return Natural is (if N = "W" then 1 else 0);

   function GC_Code (N : String) return Natural is
   begin
      if N = "Mn" then
         return GC'Pos (GC_Mn);
      elsif N = "Mc" then
         return GC'Pos (GC_Mc);
      elsif N = "Pi" then
         return GC'Pos (GC_Pi);
      elsif N = "Pf" then
         return GC'Pos (GC_Pf);
      else
         return GC'Pos (GC_Other);
      end if;
   end GC_Code;

   --  ------------------------------------------------------------------
   --  Loading
   --  ------------------------------------------------------------------

   procedure Ensure_Loaded is
   begin
      if Loaded then
         return;
      end if;
      Loaded := True;
      if not I18N.Data_Store.Available ("segmentation") then
         return;
      end if;
      Have_Data := True;
      Tab_Ext  := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "extpict"),
         Ext_Code'Access);
      Tab_GCB  := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "gcb"), GCB_Code'Access);
      Tab_ICB  := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "incb"), ICB_Code'Access);
      Tab_Line := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "line"), LB_Code'Access);
      Tab_Sent := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "sentence"),
         SB_Code'Access);
      Tab_Word := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "word"), WB_Code'Access);
      Tab_EAW  := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "eaw"), EAW_Code'Access);
      Tab_GC   := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "gc"), GC_Code'Access);
      Tab_ExtCn := Parse_Table
        (I18N.Data_Store.Lookup ("segmentation", "seg", "extcn"),
         Ext_Code'Access);
   end Ensure_Loaded;

   function G  (C : CP) return GCB is (GCB'Val (Lookup (Tab_GCB, C, 0)));
   function IC (C : CP) return ICB is (ICB'Val (Lookup (Tab_ICB, C, 0)));
   function EP (C : CP) return Boolean is (Lookup (Tab_Ext, C, 0) = 1);
   function W  (C : CP) return WB is (WB'Val (Lookup (Tab_Word, C, 0)));
   function S  (C : CP) return SB is (SB'Val (Lookup (Tab_Sent, C, 0)));
   function LC (C : CP) return LB is (LB'Val (Lookup (Tab_Line, C, 0)));
   function Wide (C : CP) return Boolean is (Lookup (Tab_EAW, C, 0) = 1);
   function GCat (C : CP) return GC is (GC'Val (Lookup (Tab_GC, C, 0)));
   function Ext_Cn (C : CP) return Boolean is (Lookup (Tab_ExtCn, C, 0) = 1);

   --  ------------------------------------------------------------------
   --  UTF-8 decode
   --  ------------------------------------------------------------------

   type CP_Array is array (Positive range <>) of CP;
   type Off_Array is array (Positive range <>) of Positive;

   procedure Decode
     (Text : String; CPs : out CP_Array; Offs : out Off_Array; N : out Natural)
   is
      I : Natural := Text'First;
   begin
      N := 0;
      while I <= Text'Last loop
         declare
            B : constant Natural := Character'Pos (Text (I));
            V : CP;
            Nb : Natural;
         begin
            if B < 16#80# then
               V := CP (B); Nb := 0;
            elsif B < 16#E0# then
               V := CP (B - 16#C0#); Nb := 1;
            elsif B < 16#F0# then
               V := CP (B - 16#E0#); Nb := 2;
            else
               V := CP (B - 16#F0#); Nb := 3;
            end if;
            for K in 1 .. Nb loop
               exit when I + K > Text'Last;
               V := V * 64 + CP (Character'Pos (Text (I + K)) - 16#80#);
            end loop;
            N := N + 1;
            CPs (N) := V;
            Offs (N) := I - Text'First + 1;
            I := I + Nb + 1;
         end;
      end loop;
      Offs (N + 1) := Text'Length + 1;
   end Decode;

   --  ------------------------------------------------------------------
   --  Grapheme cluster boundaries (UAX #29)
   --  ------------------------------------------------------------------

   procedure Grapheme_Breaks
     (C : CP_Array; N : Natural; Brk : out Off_Array)
   is
      RI_Cnt     : Natural := 0;      --  consecutive RI ending at prev
      Pict_Ready : Boolean := False;  --  prev = ExtPict Extend* ZWJ
      Pict_Open  : Boolean := False;  --  prev run = ExtPict Extend*
      ICB_Open   : Boolean := False;  --  Consonant (Extend|Linker)* open
      Has_Linker : Boolean := False;  --  ...with a Linker seen

      procedure Update (X : CP) is
      begin
         --  Regional indicator run.
         if G (X) = GCB_RI then
            RI_Cnt := RI_Cnt + 1;
         else
            RI_Cnt := 0;
         end if;
         --  Extended pictographic ZWJ sequence.
         if EP (X) then
            Pict_Open := True; Pict_Ready := False;
         elsif G (X) = GCB_Extend and then Pict_Open then
            null;
         elsif G (X) = GCB_ZWJ and then Pict_Open then
            Pict_Open := False; Pict_Ready := True;
         else
            Pict_Open := False; Pict_Ready := False;
         end if;
         --  Indic conjunct cluster.
         if IC (X) = ICB_Consonant then
            ICB_Open := True; Has_Linker := False;
         elsif ICB_Open and then IC (X) = ICB_Linker then
            Has_Linker := True;
         elsif ICB_Open and then IC (X) = ICB_Extend then
            null;
         else
            ICB_Open := False; Has_Linker := False;
         end if;
      end Update;

      function Break_Before (P, Curr : CP) return Boolean is
      begin
         if G (P) = GCB_CR and then G (Curr) = GCB_LF then
            return False;                                       --  GB3
         elsif G (P) in GCB_Control | GCB_CR | GCB_LF then
            return True;                                        --  GB4
         elsif G (Curr) in GCB_Control | GCB_CR | GCB_LF then
            return True;                                        --  GB5
         elsif G (P) = GCB_L
           and then G (Curr) in GCB_L | GCB_V | GCB_LV | GCB_LVT
         then
            return False;                                       --  GB6
         elsif G (P) in GCB_LV | GCB_V and then G (Curr) in GCB_V | GCB_T then
            return False;                                       --  GB7
         elsif G (P) in GCB_LVT | GCB_T and then G (Curr) = GCB_T then
            return False;                                       --  GB8
         elsif G (Curr) in GCB_Extend | GCB_ZWJ then
            return False;                                       --  GB9
         elsif G (Curr) = GCB_SpacingMark then
            return False;                                       --  GB9a
         elsif G (P) = GCB_Prepend then
            return False;                                       --  GB9b
         elsif ICB_Open and then Has_Linker
           and then IC (Curr) = ICB_Consonant
         then
            return False;                                       --  GB9c
         elsif G (P) = GCB_ZWJ and then Pict_Ready and then EP (Curr) then
            return False;                                       --  GB11
         elsif G (P) = GCB_RI and then G (Curr) = GCB_RI
           and then RI_Cnt mod 2 = 1
         then
            return False;                                       --  GB12/13
         else
            return True;                                        --  GB999
         end if;
      end Break_Before;

      B_Count : Natural := 0;
   begin
      Brk (1) := 1;
      B_Count := 1;
      if N >= 1 then
         Update (C (1));
      end if;
      for I in 2 .. N loop
         if Break_Before (C (I - 1), C (I)) then
            B_Count := B_Count + 1;
            Brk (B_Count) := I;
         end if;
         Update (C (I));
      end loop;
      Brk (B_Count + 1) := N + 1;   --  sentinel count marker via last slot
   end Grapheme_Breaks;

   --  ------------------------------------------------------------------
   --  Word boundaries (UAX #29)
   --  ------------------------------------------------------------------

   procedure Word_Breaks (C : CP_Array; N : Natural; Brk : out Off_Array) is

      function Is_Ig (P : WB) return Boolean is
        (P in WB_Extend | WB_Format | WB_ZWJ);

      function AH (P : WB) return Boolean is (P in WB_ALetter | WB_HebrewLetter);
      function MNLQ (P : WB) return Boolean is
        (P in WB_MidNumLet | WB_SingleQuote);

      function Prev_NI (I : Natural) return Natural is
         J : Natural := I - 1;
      begin
         while J >= 1 and then Is_Ig (W (C (J))) loop
            J := J - 1;
         end loop;
         return J;
      end Prev_NI;

      function Next_NI (I : Natural) return Natural is
         J : Natural := I + 1;
      begin
         while J <= N and then Is_Ig (W (C (J))) loop
            J := J + 1;
         end loop;
         return J;
      end Next_NI;

      function RI_Run (PI : Natural) return Natural is
         Cnt : Natural := 0;
         K   : Natural := PI;
      begin
         while K >= 1 and then W (C (K)) = WB_RI loop
            Cnt := Cnt + 1;
            K := Prev_NI (K);
         end loop;
         return Cnt;
      end RI_Run;

      function Break_Before (I : Natural) return Boolean is
         Pr : constant WB := W (C (I - 1));
         Cu : constant WB := W (C (I));
      begin
         if Pr = WB_CR and then Cu = WB_LF then
            return False;                                       --  WB3
         elsif Pr in WB_Newline | WB_CR | WB_LF then
            return True;                                        --  WB3a
         elsif Cu in WB_Newline | WB_CR | WB_LF then
            return True;                                        --  WB3b
         elsif Pr = WB_ZWJ and then EP (C (I)) then
            return False;                                       --  WB3c
         elsif Pr = WB_WSegSpace and then Cu = WB_WSegSpace then
            return False;                                       --  WB3d
         elsif Is_Ig (Cu) then
            return False;                                       --  WB4
         end if;
         declare
            PI  : constant Natural := Prev_NI (I);
         begin
            if PI = 0 then
               return True;
            end if;
            declare
               A   : constant WB := W (C (PI));
               B   : constant WB := Cu;
               PPI : constant Natural := Prev_NI (PI);
               App : constant WB :=
                 (if PPI > 0 then W (C (PPI)) else WB_Other);
               NI  : constant Natural := Next_NI (I);
               Bn  : constant WB := (if NI <= N then W (C (NI)) else WB_Other);
            begin
               if AH (A) and then AH (B) then
                  return False;                                 --  WB5
               elsif AH (A) and then (B = WB_MidLetter or else MNLQ (B))
                 and then AH (Bn)
               then
                  return False;                                 --  WB6
               elsif (A = WB_MidLetter or else MNLQ (A)) and then AH (App)
                 and then AH (B)
               then
                  return False;                                 --  WB7
               elsif A = WB_HebrewLetter and then B = WB_SingleQuote then
                  return False;                                 --  WB7a
               elsif A = WB_HebrewLetter and then B = WB_DoubleQuote
                 and then Bn = WB_HebrewLetter
               then
                  return False;                                 --  WB7b
               elsif A = WB_DoubleQuote and then App = WB_HebrewLetter
                 and then B = WB_HebrewLetter
               then
                  return False;                                 --  WB7c
               elsif A = WB_Numeric and then B = WB_Numeric then
                  return False;                                 --  WB8
               elsif AH (A) and then B = WB_Numeric then
                  return False;                                 --  WB9
               elsif A = WB_Numeric and then AH (B) then
                  return False;                                 --  WB10
               elsif (A = WB_MidNum or else MNLQ (A)) and then App = WB_Numeric
                 and then B = WB_Numeric
               then
                  return False;                                 --  WB11
               elsif A = WB_Numeric and then (B = WB_MidNum or else MNLQ (B))
                 and then Bn = WB_Numeric
               then
                  return False;                                 --  WB12
               elsif A = WB_Katakana and then B = WB_Katakana then
                  return False;                                 --  WB13
               elsif A in WB_ALetter | WB_HebrewLetter | WB_Numeric
                   | WB_Katakana | WB_ExtendNumLet
                 and then B = WB_ExtendNumLet
               then
                  return False;                                 --  WB13a
               elsif A = WB_ExtendNumLet
                 and then B in WB_ALetter | WB_HebrewLetter | WB_Numeric
                   | WB_Katakana
               then
                  return False;                                 --  WB13b
               elsif A = WB_RI and then B = WB_RI
                 and then RI_Run (PI) mod 2 = 1
               then
                  return False;                                 --  WB15/16
               else
                  return True;                                  --  WB999
               end if;
            end;
         end;
      end Break_Before;

      B_Count : Natural := 1;
   begin
      Brk (1) := 1;
      for I in 2 .. N loop
         if Break_Before (I) then
            B_Count := B_Count + 1;
            Brk (B_Count) := I;
         end if;
      end loop;
      Brk (B_Count + 1) := N + 1;
   end Word_Breaks;

   --  ------------------------------------------------------------------
   --  Line break opportunities (UAX #14)
   --  ------------------------------------------------------------------

   procedure Line_Breaks (C : CP_Array; N : Natural; Brk : out Off_Array) is
      Res : array (1 .. N) of LB := (others => LB_XX);   --  resolved + folded
      Zwj : array (1 .. N) of Boolean := (others => False);
      Abs_CM : array (1 .. N) of Boolean := (others => False);

      function No_Absorb (P : LB) return Boolean is
        (P in LB_BK | LB_CR | LB_LF | LB_NL | LB_SP | LB_ZW);

      --  Index of the last non-SP char at or before I (0 if none).
      function Base_Idx (I : Natural) return Natural is
         J : Natural := I;
      begin
         while J >= 1 and then Res (J) = LB_SP loop
            J := J - 1;
         end loop;
         return J;
      end Base_Idx;

      --  Last non-SP resolved class at or before I (for the SP* rules).
      function Base_Before (I : Natural) return LB is
         J : constant Natural := Base_Idx (I);
      begin
         return (if J >= 1 then Res (J) else LB_XX);
      end Base_Before;

      --  Class just before a run ending at I, skipping SP (for LB21a lookback).
      function Prev_Nonsp (I : Natural) return LB is
         J : Natural := I - 1;
      begin
         while J >= 1 and then Res (J) = LB_SP loop
            J := J - 1;
         end loop;
         return (if J >= 1 then Res (J) else LB_XX);
      end Prev_Nonsp;

      --  Base position of a char, seeing through absorbed CM/ZWJ (LB9).
      function Base_Of (I : Natural) return Natural is
         J : Natural := I;
      begin
         while J >= 1 and then Abs_CM (J) loop
            J := J - 1;
         end loop;
         return J;
      end Base_Of;

      --  LB28a Brahmic group: AK, AS, or the dotted circle U+25CC (class AL).
      function AK_Grp (I : Natural) return Boolean is
         J : constant Natural := Base_Of (I);
      begin
         return J >= 1
           and then (Res (J) in LB_AK | LB_AS or else C (J) = 16#25CC#);
      end AK_Grp;

      --  LB25: the maximal (NU|SY|IS) run ending at I contains a NU, i.e. I is
      --  the tail of a NU (NU|SY|IS)* numeric sequence (CM folded via Base_Of).
      function Traces_To_NU (I : Natural) return Boolean is
         J     : Natural := Base_Of (I);
         Found : Boolean := False;
      begin
         while J >= 1 and then Res (J) in LB_NU | LB_SY | LB_IS loop
            if Res (J) = LB_NU then
               Found := True;
            end if;
            exit when J = 1;
            J := Base_Of (J - 1);
         end loop;
         return Found;
      end Traces_To_NU;

      --  I is the end of NU (NU|SY|IS)* with an optional trailing CL/CP.
      function Num_Seq_End (I : Natural) return Boolean is
         B : constant Natural := Base_Of (I);
      begin
         if Res (B) in LB_CL | LB_CP then
            return B >= 2 and then Traces_To_NU (B - 1);
         else
            return Traces_To_NU (I);
         end if;
      end Num_Seq_End;

      --  LB15a: opening quote (Pi & QU) in the right left-context, then SP* x.
      function LB15a (I : Natural) return Boolean is
         J : constant Natural := Base_Of (Base_Idx (I));   --  through SP and CM
      begin
         if J < 1 or else Res (J) /= LB_QU or else GCat (C (J)) /= GC_Pi then
            return False;
         end if;
         return J = 1
           or else Res (J - 1) in LB_BK | LB_CR | LB_LF | LB_NL | LB_OP | LB_QU
             | LB_GL | LB_SP | LB_ZW;
      end LB15a;

      --  LB15b: closing quote (Pf & QU) followed by space/punctuation/eot.
      function LB15b (I : Natural) return Boolean is
      begin
         if Res (I + 1) /= LB_QU or else GCat (C (I + 1)) /= GC_Pf then
            return False;
         end if;
         return I + 2 > N
           or else Res (I + 2) in LB_SP | LB_GL | LB_WJ | LB_CL | LB_QU | LB_CP
             | LB_EX | LB_IS | LB_SY | LB_BK | LB_CR | LB_LF | LB_NL | LB_ZW;
      end LB15b;

      --  LB20a: (sot|BK|CR|LF|NL|SP|ZW|CB|GL) (HY|HH) x (AL|HL).
      function LB20a (I : Natural) return Boolean is
         BP : constant Natural := Base_Of (I);
      begin
         return Res (I) in LB_HY | LB_HH and then Res (I + 1) in LB_AL | LB_HL
           and then (BP = 1
                     or else Res (BP - 1) in LB_BK | LB_CR | LB_LF | LB_NL
                       | LB_SP | LB_ZW | LB_CB | LB_GL);
      end LB20a;

      function Break_After (I : Natural) return Boolean is
         L : constant LB := Res (I);
         R : constant LB := Res (I + 1);
         BB : constant LB := Base_Before (I);
      begin
         --  LB4 / LB5 mandatory.
         if L = LB_BK then
            return True;
         elsif L = LB_CR and then R = LB_LF then
            return False;
         elsif L in LB_CR | LB_LF | LB_NL then
            return True;
         --  LB6
         elsif R in LB_BK | LB_CR | LB_LF | LB_NL then
            return False;
         --  LB7
         elsif R = LB_SP or else R = LB_ZW then
            return False;
         --  LB8  ZW SP* /
         elsif BB = LB_ZW then
            return True;
         --  LB8a  ZWJ x
         elsif Zwj (I) then
            return False;
         --  LB9  x CM/ZWJ (absorbed)
         elsif Abs_CM (I + 1) then
            return False;
         --  LB11
         elsif R = LB_WJ or else L = LB_WJ then
            return False;
         --  LB12 / LB12a
         elsif L = LB_GL then
            return False;
         elsif R = LB_GL and then L not in LB_SP | LB_BA | LB_HY | LB_HH then
            return False;
         --  LB13
         elsif R in LB_CL | LB_CP | LB_EX | LB_SY then
            return False;
         --  LB14  OP SP* x
         elsif BB = LB_OP then
            return False;
         --  LB15a  opening quote:  ... (Pi&QU) SP* x
         elsif LB15a (I) then
            return False;
         --  LB15b  x (Pf&QU) followed by space/punctuation/eot
         elsif LB15b (I) then
            return False;
         --  LB15c  SP / IS NU  (a number with a leading separator may wrap)
         elsif L = LB_SP and then R = LB_IS
           and then I + 2 <= N and then Res (I + 2) = LB_NU
         then
            return True;
         --  LB15d  x IS
         elsif R = LB_IS then
            return False;
         --  LB16  (CL|CP) SP* x NS
         elsif BB in LB_CL | LB_CP and then R = LB_NS then
            return False;
         --  LB17  B2 SP* x B2
         elsif BB = LB_B2 and then R = LB_B2 then
            return False;
         --  LB18  SP /
         elsif L = LB_SP then
            return True;
         --  LB19  x [QU - Pi] ; [QU - Pf] x
         elsif R = LB_QU and then GCat (C (I + 1)) /= GC_Pi then
            return False;
         elsif L = LB_QU and then GCat (C (Base_Of (I))) /= GC_Pf then
            return False;
         --  LB19a  do not break either side of a quotation mark unless it is
         --  adjacent to an East Asian wide character.
         elsif R = LB_QU and then not Wide (C (Base_Of (I))) then
            return False;
         elsif R = LB_QU
           and then (I + 2 > N or else not Wide (C (I + 2)))
         then
            return False;
         elsif L = LB_QU and then not Wide (C (I + 1)) then
            return False;
         elsif L = LB_QU
           and then (Base_Of (I) <= 1 or else not Wide (C (Base_Of (I) - 1)))
         then
            return False;
         --  LB20  / CB ; CB /
         elsif L = LB_CB or else R = LB_CB then
            return True;
         --  LB20a  (sot|BK|CR|LF|NL|SP|ZW|CB|GL) (HY|HH) x (AL|HL)
         elsif LB20a (I) then
            return False;
         --  LB21  x BA ; x HY ; x NS ; x HH ; BB x
         elsif R in LB_BA | LB_HY | LB_NS | LB_HH or else L = LB_BB then
            return False;
         --  LB21a  HL (HY|HH) x [^HL]
         elsif Prev_Nonsp (I) = LB_HL and then L in LB_HY | LB_HH
           and then R /= LB_HL
         then
            return False;
         --  LB21b  SY x HL
         elsif L = LB_SY and then R = LB_HL then
            return False;
         --  LB22  x IN
         elsif R = LB_IN then
            return False;
         --  LB23  (AL|HL) x NU ; NU x (AL|HL)
         elsif L in LB_AL | LB_HL | LB_CM and then R = LB_NU then
            return False;
         elsif L = LB_NU and then R in LB_AL | LB_HL | LB_CM then
            return False;
         --  LB23a  PR x (ID|EB|EM) ; (ID|EB|EM) x PO
         elsif L = LB_PR and then R in LB_ID | LB_EB | LB_EM then
            return False;
         elsif L in LB_ID | LB_EB | LB_EM and then R = LB_PO then
            return False;
         --  LB24  (PR|PO) x (AL|HL) ; (AL|HL) x (PR|PO)
         elsif L in LB_PR | LB_PO and then R in LB_AL | LB_HL | LB_CM then
            return False;
         elsif L in LB_AL | LB_HL | LB_CM and then R in LB_PR | LB_PO then
            return False;
         --  LB25  numbers
         elsif L = LB_IS and then R = LB_NU then
            return False;
         elsif L in LB_PR | LB_PO and then R = LB_NU then
            return False;
         elsif L in LB_PR | LB_PO and then R in LB_OP | LB_HY
           and then I + 2 <= N and then Res (I + 2) = LB_NU
         then
            return False;
         elsif L in LB_OP | LB_HY and then R = LB_NU then
            return False;
         elsif Traces_To_NU (I)
           and then R in LB_NU | LB_SY | LB_IS | LB_CL | LB_CP
         then
            return False;
         elsif Num_Seq_End (I) and then R in LB_PO | LB_PR then
            return False;
         --  LB26  Hangul
         elsif L = LB_JL and then R in LB_JL | LB_JV | LB_H2 | LB_H3 then
            return False;
         elsif L in LB_JV | LB_H2 and then R in LB_JV | LB_JT then
            return False;
         elsif L in LB_JT | LB_H3 and then R = LB_JT then
            return False;
         --  LB27
         elsif L in LB_JL | LB_JV | LB_JT | LB_H2 | LB_H3 and then R = LB_PO then
            return False;
         elsif L = LB_PR and then R in LB_JL | LB_JV | LB_JT | LB_H2 | LB_H3 then
            return False;
         --  LB28  (AL|HL) x (AL|HL)
         elsif L in LB_AL | LB_HL | LB_CM and then R in LB_AL | LB_HL | LB_CM then
            return False;
         --  LB28a  Brahmic orthographic syllables (◌ = U+25CC joins the group)
         elsif L = LB_AP and then AK_Grp (I + 1) then
            return False;
         elsif AK_Grp (I) and then R in LB_VF | LB_VI then
            return False;
         elsif Res (Base_Of (I)) = LB_VI and then Base_Of (I) >= 2
           and then AK_Grp (Base_Of (I) - 1)
           and then (R = LB_AK or else C (I + 1) = 16#25CC#)
         then
            return False;
         elsif AK_Grp (I) and then AK_Grp (I + 1)
           and then I + 2 <= N and then Res (I + 2) = LB_VF
         then
            return False;
         --  LB29  IS x (AL|HL)
         elsif L = LB_IS and then R in LB_AL | LB_HL then
            return False;
         --  LB30  (AL|HL|NU) x OP[!EA] ; CP[!EA] x (AL|HL|NU)
         elsif L in LB_AL | LB_HL | LB_NU and then R = LB_OP
           and then not Wide (C (I + 1))
         then
            return False;
         elsif L = LB_CP and then R in LB_AL | LB_HL | LB_NU
           and then not Wide (C (I))
         then
            return False;
         --  LB30b  EB x EM ; [ExtPict & Cn] x EM
         elsif L = LB_EB and then R = LB_EM then
            return False;
         elsif R = LB_EM and then Ext_Cn (C (Base_Of (I))) then
            return False;
         --  LB31  default: break.
         else
            return True;
         end if;
      end Break_After;

      RI_Count : Natural := 0;
      B_Count  : Natural := 1;
   begin
      --  Resolve classes (LB1) and fold CM/ZWJ (LB9/LB10).
      for I in 1 .. N loop
         declare
            R0 : LB := LC (C (I));
         begin
            if R0 = LB_SA then
               R0 := (if GCat (C (I)) in GC_Mn | GC_Mc then LB_CM else LB_AL);
            elsif R0 in LB_AI | LB_SG | LB_XX then
               R0 := LB_AL;               --  LB1
            elsif R0 = LB_CJ then
               R0 := LB_NS;               --  LB1
            end if;
            if LC (C (I)) = LB_ZWJ then
               Zwj (I) := True;
            end if;
            if R0 in LB_CM | LB_ZWJ then
               if I = 1 or else No_Absorb (Res (I - 1)) then
                  Res (I) := LB_AL;       --  LB10 standalone
               else
                  Res (I) := Res (I - 1); --  LB9 absorb
                  Abs_CM (I) := True;
               end if;
            else
               Res (I) := R0;
            end if;
         end;
      end loop;

      Brk (1) := 1;
      for I in 1 .. N - 1 loop
         --  LB30a  RI RI (even); absorbed CM does not reset the RI run.
         if not Abs_CM (I) then
            if Res (I) = LB_RI then
               RI_Count := RI_Count + 1;
            else
               RI_Count := 0;
            end if;
         end if;
         declare
            Do_Break : Boolean := Break_After (I);
         begin
            if Res (I) = LB_RI and then Res (I + 1) = LB_RI
              and then RI_Count mod 2 = 1
            then
               Do_Break := False;        --  LB30a
            end if;
            if Do_Break then
               B_Count := B_Count + 1;
               Brk (B_Count) := I + 1;
            end if;
         end;
      end loop;
      Brk (B_Count + 1) := N + 1;
   end Line_Breaks;

   --  ------------------------------------------------------------------
   --  Sentence boundaries (UAX #29)
   --  ------------------------------------------------------------------

   procedure Sentence_Breaks (C : CP_Array; N : Natural; Brk : out Off_Array) is

      type TKind is (T_None, T_A, T_S);
      Term        : TKind := T_None;   --  active (A|S)Term Close* Sp* tail
      Had_Close   : Boolean := False;
      Had_Sp      : Boolean := False;
      Before_Term : SB := SB_Other;    --  char before the terminator (SB7)
      Last_Prop   : SB := SB_Other;    --  previous non-ignore property

      function Is_Ig (P : SB) return Boolean is (P in SB_Extend | SB_Format);

      procedure Update (X : CP) is
         PX : constant SB := S (X);
      begin
         if PX = SB_ATerm then
            Before_Term := Last_Prop; Term := T_A;
            Had_Close := False; Had_Sp := False;
         elsif PX = SB_STerm then
            Before_Term := Last_Prop; Term := T_S;
            Had_Close := False; Had_Sp := False;
         elsif Term /= T_None and then PX = SB_Close and then not Had_Sp then
            Had_Close := True;
         elsif Term /= T_None and then PX = SB_Sp then
            Had_Sp := True;
         else
            Term := T_None; Had_Close := False; Had_Sp := False;
         end if;
         Last_Prop := PX;
      end Update;

      --  SB8: ATerm Close* Sp* x (not stop)* Lower.
      function SB8_Ahead (I : Natural) return Boolean is
         J : Natural := I;
      begin
         while J <= N loop
            declare
               P : constant SB := S (C (J));
            begin
               if not Is_Ig (P) then
                  if P = SB_Lower then
                     return True;
                  elsif P in SB_OLetter | SB_Upper | SB_Sep | SB_CR | SB_LF
                    | SB_STerm | SB_ATerm
                  then
                     return False;
                  end if;
               end if;
            end;
            J := J + 1;
         end loop;
         return False;
      end SB8_Ahead;

      function Break_Before (I : Natural) return Boolean is
         Lu : constant SB := S (C (I - 1));
         Ru : constant SB := S (C (I));
      begin
         if Lu = SB_CR and then Ru = SB_LF then
            return False;                                       --  SB3
         elsif Lu in SB_Sep | SB_CR | SB_LF then
            return True;                                        --  SB4
         elsif Is_Ig (Ru) then
            return False;                                       --  SB5
         elsif Term = T_A and then not Had_Close and then not Had_Sp
           and then Ru = SB_Numeric
         then
            return False;                                       --  SB6
         elsif Term = T_A and then not Had_Close and then not Had_Sp
           and then Before_Term in SB_Upper | SB_Lower and then Ru = SB_Upper
         then
            return False;                                       --  SB7
         elsif Term = T_A and then SB8_Ahead (I) then
            return False;                                       --  SB8
         elsif Term /= T_None
           and then Ru in SB_SContinue | SB_STerm | SB_ATerm
         then
            return False;                                       --  SB8a
         elsif Term /= T_None and then not Had_Sp
           and then Ru in SB_Close | SB_Sp | SB_Sep | SB_CR | SB_LF
         then
            return False;                                       --  SB9
         elsif Term /= T_None and then Ru in SB_Sp | SB_Sep | SB_CR | SB_LF then
            return False;                                       --  SB10
         elsif Term /= T_None then
            return True;                                        --  SB11
         else
            return False;                                       --  SB998
         end if;
      end Break_Before;

      B_Count : Natural := 1;
   begin
      Brk (1) := 1;
      if N >= 1 and then not Is_Ig (S (C (1))) then
         Update (C (1));
      end if;
      for I in 2 .. N loop
         if Break_Before (I) then
            B_Count := B_Count + 1;
            Brk (B_Count) := I;
         end if;
         if not Is_Ig (S (C (I))) then
            Update (C (I));
         end if;
      end loop;
      Brk (B_Count + 1) := N + 1;
   end Sentence_Breaks;

   --  ------------------------------------------------------------------
   --  Public
   --  ------------------------------------------------------------------

   function Boundaries
     (Text : String; Kind : Boundary_Kind) return Offset_Array
   is
   begin
      Ensure_Loaded;
      if Text'Length = 0 then
         return [1 => 1];
      end if;
      declare
         CPs  : CP_Array (1 .. Text'Length);
         Offs : Off_Array (1 .. Text'Length + 1);
         N    : Natural;
         --  Break positions are code-point indices 1 .. N+1 (index into CPs);
         --  Idx holds them, then we map to byte offsets.
         Idx  : Off_Array (1 .. Text'Length + 1);
         BN   : Natural;
      begin
         if not Have_Data then
            return [1 => 1, 2 => Text'Length + 1];
         end if;
         Decode (Text, CPs, Offs, N);
         case Kind is
            when Grapheme => Grapheme_Breaks (CPs, N, Idx);
            when Word     => Word_Breaks (CPs, N, Idx);
            when Sentence => Sentence_Breaks (CPs, N, Idx);
            when Line     => Line_Breaks (CPs, N, Idx);
         end case;
         --  Idx is a list of code-point indices terminated where the value
         --  equals N+1. Count them.
         BN := 0;
         for K in Idx'Range loop
            BN := BN + 1;
            exit when Idx (K) = N + 1;
         end loop;
         declare
            Result : Offset_Array (1 .. BN);
         begin
            for K in 1 .. BN loop
               if Idx (K) = N + 1 then
                  Result (K) := Text'Length + 1;
               else
                  Result (K) := Offs (Idx (K));
               end if;
            end loop;
            return Result;
         end;
      end;
   end Boundaries;

   function Count (Text : String; Kind : Boundary_Kind) return Natural is
      B : constant Offset_Array := Boundaries (Text, Kind);
   begin
      return (if B'Length <= 1 then 0 else B'Length - 1);
   end Count;

   function Available return Boolean is
   begin
      Ensure_Loaded;
      return Have_Data;
   end Available;

end I18N.Segmentation;
