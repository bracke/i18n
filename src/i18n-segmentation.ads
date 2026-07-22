--  Text segmentation: Unicode text boundary analysis.
--    Grapheme, Word, Sentence  -- UAX #29 (deterministic segmentation)
--    Line                      -- UAX #14 (line break opportunities)
--
--  Boundaries returns the 1-based byte offsets into Text at which a boundary of
--  the given kind occurs, always including 1 (start) and Text'Length + 1 (end).
--  Between consecutive returned offsets lies one segment (for Line, one span
--  ending at an allowed break -- mandatory or optional). Input is UTF-8.
package I18N.Segmentation is

   type Boundary_Kind is (Grapheme, Word, Sentence, Line);

   type Offset_Array is array (Positive range <>) of Positive;

   function Boundaries
     (Text : String; Kind : Boundary_Kind) return Offset_Array;

   --  Number of segments (= Boundaries'Length - 1, or 0 for empty text).
   function Count (Text : String; Kind : Boundary_Kind) return Natural;

   --  Whether the segmentation data file is present and loaded.
   function Available return Boolean;

end I18N.Segmentation;
