with I18N.Data_Store;

package body I18N.Emoji is

   Sep : constant Character := I18N.Data_Store.Key_Separator;

   function Normalize (Locale : String) return String is
      Result : String := Locale;
   begin
      for I in Result'Range loop
         if Result (I) = '_' then
            Result (I) := '-';
         end if;
      end loop;
      return Result;
   end Normalize;

   --  Look up Emoji in Section of a shard tree, walking the locale's parents.
   function Lookup_Tree
     (Tree    : String;
      Section : String;
      Locale  : String;
      Emoji   : String)
      return String
   is
      Cand : constant String := Normalize (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         declare
            Hit : constant String :=
              I18N.Data_Store.Lookup
                (Tree & "/" & Cand (Cand'First .. Last), Section, Emoji);
         begin
            if Hit /= "" then
               return Hit;
            end if;
         end;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return "";
   end Lookup_Tree;

   --  Base tree first (single emoji), then the derived tree (sequences).
   function Resolve
     (Section : String;
      Locale  : String;
      Emoji   : String)
      return String
   is
      Base : constant String :=
        Lookup_Tree ("annotations", Section, Locale, Emoji);
   begin
      if Base /= "" then
         return Base;
      end if;
      return Lookup_Tree ("annotations-derived", Section, Locale, Emoji);
   end Resolve;

   function Name (Locale : String; Emoji : String) return String is
     (Resolve ("name", Locale, Emoji));

   function Keywords (Locale : String; Emoji : String) return String is
     (Resolve ("keyword", Locale, Emoji));

   function Keyword_Count (Locale : String; Emoji : String) return Natural is
      Joined : constant String := Keywords (Locale, Emoji);
      Count  : Natural := (if Joined = "" then 0 else 1);
   begin
      for C of Joined loop
         if C = Sep then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Keyword_Count;

   function Keyword
     (Locale : String;
      Emoji  : String;
      N      : Positive)
      return String
   is
      Joined : constant String := Keywords (Locale, Emoji);
      Index  : Positive := 1;
      Start  : Natural := Joined'First;
   begin
      for I in Joined'Range loop
         if Joined (I) = Sep then
            if Index = N then
               return Joined (Start .. I - 1);
            end if;
            Index := Index + 1;
            Start := I + 1;
         end if;
      end loop;
      if Index = N and then Start <= Joined'Last then
         return Joined (Start .. Joined'Last);
      end if;
      return "";
   end Keyword;

   function Available (Locale : String) return Boolean is
      Cand : constant String := Normalize (Locale);
      Last : Natural := Cand'Last;
   begin
      loop
         if I18N.Data_Store.Available
              ("annotations/" & Cand (Cand'First .. Last))
         then
            return True;
         end if;
         declare
            Cut : Natural := 0;
         begin
            for I in reverse Cand'First .. Last loop
               if Cand (I) = '-' then
                  Cut := I;
                  exit;
               end if;
            end loop;
            exit when Cut = 0;
            Last := Cut - 1;
         end;
      end loop;
      return False;
   end Available;

end I18N.Emoji;
