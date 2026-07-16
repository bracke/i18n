--  Stable v1.1.0 public locale identifiers and fallback helpers.
--
--  Purpose:
--  This package defines the public locale identifier type used by catalog
--  rendering and the deterministic parent-locale helper used by fallback.
--
--  Locale identifiers are BCP-47-style strings such as "en", "de", or
--  "de-AT". Catalog ingest and public lookup canonicalize ASCII language,
--  script, region, and extension casing and apply deterministic CLDR language
--  aliases such as "iw" -> "he", "in" -> "id", "ji" -> "yi", and
--  "sh" -> "sr-Latn" before fallback removes the rightmost hyphen-separated
--  subtag and finally falls back to the runtime default locale.
--
--  Error behavior:
--  Locale parsing is deliberately simple. Invalid or unknown locale names are
--  treated as keys into the catalog/fallback chain; missing entries are reported
--  by render as Missing_Key.
--
--  Thread-safety and allocation:
--  Locale_Id is a String subtype. Parent returns a String value derived from
--  its input and has no global state. Canonicalize, Maximize, and Minimize
--  return String values derived from their inputs and have no global state.
--
--  Example:
--     Parent ("de-AT") = "de"
--     Parent ("de")    = ""
package I18N.Locales is
   pragma Preelaborate;
   pragma SPARK_Mode (On);

   --  Public locale identifier used by the stable render API.
   subtype Locale_Id is String;

   --  Deterministic text direction for locale-sensitive UI layout.
   type Text_Direction is (Left_To_Right, Right_To_Left);

   --  Deterministic locale-sensitive ordering result.
   type Collation_Order is (Before, Same, After);

   --  Built-in default locale name used when a catalog omits default_locale.
   Default_Locale_Name : constant String := "default";

   --  Return the deterministic canonical form for Item.
   --
   --  Canonicalization trims surrounding spaces, accepts '-' or '_' as
   --  separators, normalizes ASCII language/script/region/extension casing,
   --  and applies the built-in CLDR language aliases documented above.
   --
   --  @param Item Locale identifier to canonicalize.
   --  @return Canonical locale identifier, or empty string for empty input.
   function Canonicalize
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return Item without BCP-47 extension subtags.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Canonical locale base name before the first singleton extension.
   function Base_Name
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return Item's canonical primary language subtag.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Canonical language subtag, or empty string.
   function Language
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return Item's canonical script subtag when present.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Four-letter script subtag, or empty string.
   function Script
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return Item's canonical region subtag when present.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Two-letter or three-digit region subtag, or empty string.
   function Region
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return an English display name for Item's language subtag.
   --
   --  Unknown languages return the canonical language code.
   --
   --  @param Item Locale identifier or language code to inspect.
   --  @return English language display name or canonical code.
   function Language_Display_Name
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return a localized display name for Item's language subtag.
   --
   --  Display_Locale currently selects deterministic built-in display-name
   --  tables for supported UI locales, with English/code fallback.
   --
   --  @param Item Locale identifier or language code to inspect.
   --  @param Display_Locale Locale to use for the display name.
   --  @return Localized language display name or canonical code.
   function Language_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   with
     Global => null;

   --  Return an English display name for Item's script subtag.
   --
   --  Unknown scripts return the canonical script code.
   --
   --  @param Item Locale identifier or script code to inspect.
   --  @return English script display name or canonical code.
   function Script_Display_Name
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return a localized display name for Item's script subtag.
   --
   --  @param Item Locale identifier or script code to inspect.
   --  @param Display_Locale Locale to use for the display name.
   --  @return Localized script display name or canonical code.
   function Script_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   with
     Global => null;

   --  Return an English display name for Item's region subtag.
   --
   --  Unknown regions return the canonical region code.
   --
   --  @param Item Locale identifier or region code to inspect.
   --  @return English region display name or canonical code.
   function Region_Display_Name
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return a localized display name for Item's region subtag.
   --
   --  @param Item Locale identifier or region code to inspect.
   --  @param Display_Locale Locale to use for the display name.
   --  @return Localized region display name or canonical code.
   function Region_Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   with
     Global => null;

   --  Return a deterministic English display name for Item.
   --
   --  The primary language name is followed by script and region qualifiers
   --  in parentheses when present, for example "Serbian (Latin, Serbia)".
   --
   --  @param Item Locale identifier to inspect.
   --  @return English locale display name, or canonical code fallback.
   function Display_Name
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return a deterministic localized display name for Item.
   --
   --  @param Item Locale identifier to inspect.
   --  @param Display_Locale Locale to use for the display name.
   --  @return Localized locale display name, or canonical code fallback.
   function Display_Name
     (Item           : Locale_Id;
      Display_Locale : Locale_Id)
      return String
   with
     Global => null;

   --  Return a Unicode locale-extension keyword value.
   --
   --  For a locale such as "en-US-u-ca-gregory-nu-thai", Key "ca" returns
   --  "gregory" and Key "nu" returns "thai". A present key with no explicit
   --  type returns "true"; an absent or malformed key returns the empty string.
   --
   --  @param Item Locale identifier to inspect.
   --  @param Key Two-character Unicode locale-extension key.
   --  @return Canonical extension value, "true", or empty string.
   function Unicode_Extension
     (Item : Locale_Id;
      Key  : String)
      return String
   with
     Global => null;

   --  Return a bounded locale-sensitive lowercase transform.
   --
   --  This helper lowercases ASCII, applies Turkish/Azeri dotted-I rules for
   --  "tr" and "az", and maps bounded common Latin, Greek including common
   --  tonos/dialytika vowels and final-sigma word context, Cyrillic,
   --  Armenian, and Georgian Mtavruli/Mkhedruli plus Asomtavruli/Nuskhuri
   --  uppercase UTF-8 letters to lowercase. Unknown bytes are preserved.
   --  This is not a full Unicode case-mapping implementation.
   --
   --  @param Text Text to transform.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return Lowercase text for the bounded supported set.
   function To_Lower
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return a bounded locale-sensitive uppercase transform.
   --
   --  This helper uppercases ASCII, applies Turkish/Azeri dotted-I rules for
   --  "tr" and "az", maps German sharp-s to "SS", and maps bounded common
   --  Latin, Greek including common tonos/dialytika vowels and bounded
   --  dialytika-tonos uppercase expansion, Cyrillic, Armenian, and Georgian
   --  Mkhedruli/Mtavruli plus Nuskhuri/Asomtavruli lowercase UTF-8 letters
   --  to uppercase. Unknown bytes are preserved. This is not a full Unicode
   --  case-mapping implementation.
   --
   --  @param Text Text to transform.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return Uppercase text for the bounded supported set.
   function To_Upper
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return a bounded canonical-composition transform.
   --
   --  This helper composes selected common Latin base letters followed by
   --  bounded combining grave, acute, circumflex, tilde, macron, breve,
   --  dot-above, diaeresis, ring, caron, cedilla, ogonek, or horn marks into
   --  their precomposed UTF-8 forms, including additional Latin Extended acute
   --  and cedilla pairs, dot-below, base/tone-marked horn,
   --  circumflex/breve tone vowel pairs, and bounded Greek tonos/dialytika
   --  vowels. Unknown sequences are preserved. This is not a full Unicode
   --  NFC implementation.
   --
   --  @param Text Text to transform.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Bounded NFC-like text for the supported Latin and Greek set.
   function Normalize_NFC
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return a bounded canonical-decomposition transform.
   --
   --  This helper decomposes selected common precomposed Latin UTF-8 letters
   --  into ASCII base letters followed by bounded combining grave, acute,
   --  circumflex, tilde, macron, breve, dot-above, diaeresis, ring, caron,
   --  cedilla, ogonek, or horn marks, including additional Latin Extended acute
   --  and cedilla pairs, dot-below, base/tone-marked horn,
   --  circumflex/breve tone vowel pairs, and bounded Greek tonos/dialytika
   --  vowels. Unknown sequences are preserved. This is not a full Unicode
   --  NFD implementation.
   --
   --  @param Text Text to transform.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Bounded NFD-like text for the supported Latin and Greek set.
   function Normalize_NFD
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return a bounded ASCII transliteration.
   --
   --  This helper preserves ASCII, folds common Latin letters, selected
   --  Latin digraphs, Latin alphabetic presentation ligatures and fullwidth Latin letters/digits, dot-below
   --  vowels, base/tone-marked horn vowels, and circumflex/breve tone vowels
   --  to ASCII approximations, maps German
   --  sharp-s to "ss", maps bounded Greek including common tonos/dialytika
   --  and dialytika-tonos vowels plus Cyrillic, Arabic, Persian
   --  Arabic-script letters, Arabic presentation forms-B, and selected
   --  single-letter plus U+FBEA..U+FDF9 multi-letter ligature
   --  presentation forms-A,
   --  Hebrew letters and alphabetic presentation forms, and Georgian
   --  Mkhedruli/Mtavruli plus Asomtavruli/Nuskhuri
   --  UTF-8 letters to deterministic Latin
   --  approximations, and preserves unsupported bytes.
   --  This is not a full transliteration implementation.
   --
   --  @param Text Text to transform.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Bounded ASCII transliteration for supported text.
   function Transliterate_ASCII
     (Text   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return the text direction associated with Item's script or language.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Right_To_Left for explicit RTL scripts or built-in RTL language
   --          families, otherwise Left_To_Right.
   function Direction
     (Item : Locale_Id)
      return Text_Direction
   with
     Global => null;

   --  Convenience predicate for Direction (Item) = Right_To_Left.
   --
   --  @param Item Locale identifier to inspect.
   --  @return True when Item uses an explicit RTL script or built-in RTL
   --          primary language.
   function Is_Right_To_Left
     (Item : Locale_Id)
      return Boolean
   with
     Global => null;

   --  Add deterministic likely subtags for common CLDR locale families.
   --
   --  @param Item Locale identifier to maximize.
   --  @return Locale with likely script and region subtags when known.
   function Maximize
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Remove likely script/region subtags when they are redundant.
   --
   --  @param Item Locale identifier to minimize.
   --  @return Shortest deterministic locale whose maximized form matches Item.
   function Minimize
     (Item : Locale_Id)
      return String
   with
     Global => null;

   --  Return the best locale match from a comma-separated available list.
   --
   --  Requested_Ranges accepts comma-separated BCP-47 language ranges with
   --  optional Accept-Language-style q weights, for example
   --  "fr-CA, fr;q=0.8, en;q=0.5". Matching is deterministic: higher q wins,
   --  then exact/canonical matches, likely-subtag matches, fallback-parent
   --  matches, wildcard matches, and finally input order. The returned value is
   --  the canonical available locale, or Default when no range matches.
   --
   --  @param Available_Locales Comma-separated locales supported by the caller.
   --  @param Requested_Ranges Comma-separated requested language ranges.
   --  @param Default Locale to return when no range matches.
   --  @return Best canonical match, Default canonicalized, or empty string.
   function Match
     (Available_Locales : String;
      Requested_Ranges  : String;
      Default           : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return a deterministic primary collation key for Item.
   --
   --  The key lowercases ASCII, folds common Latin and Latin Extended letters
   --  plus Latin alphabetic presentation ligatures, fullwidth Latin
   --  letters/digits, halfwidth Katakana compatibility forms including
   --  voiced/semi-voiced mark composition, and Hangul compatibility-Jamo
   --  folding,
   --  uses German ae/oe/ue/ss expansions for German locales, keeps Nordic
   --  å/ä/æ/ö/ø ordering after z for Swedish, Danish, and Norwegian, and
   --  handles bounded Czech/Slovak ch plus South Slavic Latin dž/lj/nj
   --  contractions, ignores bounded combining marks including U+1AB0..U+1AFF,
   --  U+1DC0..U+1DFF, U+20D0..U+20FF, U+FE20..U+FE2F, and bounded
   --  Hebrew, Syriac, Thaana, NKo, Samaritan, and Mandaic marks,
   --  folds assigned Hebrew alphabetic presentation forms to base Hebrew
   --  letter keys, Arabic presentation forms-B, and selected single-letter
   --  plus U+FBEA..U+FDF9 multi-letter ligature presentation forms-A to base
   --  Arabic letter keys,
   --  folds bounded Greek case plus common
   --  tonos/dialytika vowels, Cyrillic, and Armenian case, and consumes
   --  unhandled two-byte UTF-8 elements plus bounded three-byte
   --  Samaritan, Mandaic, Ogham, Runic, Cherokee,
   --  Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le, New Tai Lue,
   --  Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham, Balinese,
   --  Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari, Bengali,
   --  Thai, Ethiopic, Hiragana, Katakana, halfwidth Katakana compatibility
   --  forms, Hangul compatibility Jamo, Han, and Hangul syllable elements
   --  plus bounded four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada,
   --  Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi,
   --  Linear B, Aegean Numbers, Lycian, Carian, Old Italic, Gothic,
   --  Old Permic, Ugaritic, Old Persian, Deseret, Shavian, Osmanya,
   --  Osage, Elbasan, Caucasian Albanian, Cypriot, Imperial Aramaic,
   --  Palmyrene, Phoenician, Lydian, Sidetic, Meroitic Hieroglyphs,
   --  Meroitic Cursive, Nabataean, Hatran, Kharoshthi, Old South Arabian,
   --  Old North Arabian, Manichaean, Avestan, Inscriptional Parthian,
   --  Inscriptional Pahlavi, Psalter Pahlavi, Old Turkic, Old Hungarian,
   --  Garay, Rumi Numeral Symbols, Vithkuqi, Todhri,
   --  Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur,
   --  Chorasmian, Elymaic,
   --  Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra,
   --  Dives Akuru, Nandinagari,
   --  Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen,
   --  Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian
   --  Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema,
   --  Tangsa, Kirat Rai, Tangut,
   --  Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto,
   --  Ol Onal, Tai Yo, Nag Mundari, and Adlam elements as
   --  stable byte-key units. The Unicode extension
   --  -u-kn-true enables bounded
   --  numeric ordering for ASCII, Arabic-Indic, extended Arabic-Indic,
   --  Devanagari, Bengali, Thai, NKo, fullwidth Latin letters/digits, Myanmar, Limbu,
   --  New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese, Sundanese,
   --  Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng, Chakma,
   --  Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi,
   --  Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki,
   --  Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai,
   --  Ol Onal, Tai Yo, Nag Mundari, Adlam, and Han decimal digit runs.
   --  This is a bounded public collation helper, not a full UCA sort-key
   --  implementation.
   --
   --  @param Item Text to key.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return Deterministic primary sort key.
   function Sort_Key
     (Item   : String;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Compare two strings with the deterministic public collation key.
   --
   --  Sort_Key decides primary order; raw byte order breaks equal-key ties so
   --  the result is deterministic for all UTF-8 input.
   --
   --  @param Left First text to compare.
   --  @param Right Second text to compare.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return Before, Same, or After.
   function Compare
     (Left   : String;
      Right  : String;
      Locale : Locale_Id := "")
      return Collation_Order
   with
     Global => null;

   --  Return whether two strings are equal at primary collation strength.
   --
   --  This compares Sort_Key values without the raw-byte tie-break used by
   --  Compare, so accented and tailored forms can be primary-equivalent.
   --
   --  @param Left First text to compare.
   --  @param Right Second text to compare.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return True when both strings have the same primary sort key.
   function Equivalent
     (Left   : String;
      Right  : String;
      Locale : Locale_Id := "")
      return Boolean
   with
     Global => null;

   --  Return whether Text contains Pattern at primary collation strength.
   --
   --  Both inputs are converted through Sort_Key before searching. Empty
   --  Pattern returns True. This is a bounded deterministic helper for common
   --  Latin text, not a full locale-aware search-collation implementation.
   --
   --  @param Text Text to search.
   --  @param Pattern Pattern to find.
   --  @param Locale Locale controlling bounded tailoring.
   --  @return True when Pattern's primary key occurs in Text's primary key.
   function Contains
     (Text    : String;
      Pattern : String;
      Locale  : Locale_Id := "")
      return Boolean
   with
     Global => null;

   --  Count bounded grapheme-like clusters in Text.
   --
   --  Clusters are formed from one UTF-8 code point plus bounded combining
   --  marks including U+1AB0..U+1AFF, U+1DC0..U+1DFF, U+20D0..U+20FF,
   --  U+FE20..U+FE2F, and bounded Hebrew, Syriac, Thaana, NKo,
   --  Samaritan, and Mandaic marks,
   --  bounded
   --  South/Southeast Asian dependent vowel, virama, and tone marks,
   --  variation selectors including U+FE00..U+FE0F and U+E0100..U+E01EF,
   --  emoji keycap marks, emoji
   --  skin-tone modifiers, emoji tag sequences, regional indicator flag
   --  pairs, multi-code-point zero-width-joiner sequences, and bounded Hangul Jamo
   --  L/V/T sequences. CRLF is counted as one cluster, while ASCII control
   --  characters and bounded Unicode C1 controls remain standalone clusters. Malformed bytes
   --  are counted as single byte clusters. This is not a full UAX #29
   --  implementation.
   --
   --  @param Text Text to inspect.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Number of bounded grapheme-like clusters.
   function Grapheme_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   with
     Global => null;

   --  Return the Nth bounded grapheme-like cluster from Text.
   --
   --  Index is 1-based. Zero or out-of-range indexes return the empty string.
   --  The returned cluster preserves the original UTF-8 bytes from Text.
   --
   --  @param Text Text to inspect.
   --  @param Index 1-based grapheme index.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Original text of the requested cluster, or empty string.
   function Grapheme_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Count bounded hard-line segments in Text.
   --
   --  Line boundaries are recognized at LF, CR, CRLF, vertical tab,
   --  form feed, Unicode next-line (NEL), Unicode line separator, and Unicode paragraph
   --  separator. The terminating break belongs to the preceding returned
   --  line segment. Empty text has zero lines, and a final trailing break
   --  does not create an additional empty line. This is not a full UAX #14
   --  line-break implementation.
   --
   --  @param Text Text to inspect.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Number of bounded hard-line segments.
   function Line_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   with
     Global => null;

   --  Return the Nth bounded hard-line segment from Text.
   --
   --  Index is 1-based. Zero or out-of-range indexes return the empty string.
   --  The returned line preserves original bytes, including a terminating line
   --  break when one is present.
   --
   --  @param Text Text to inspect.
   --  @param Index 1-based line index.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Original text of the requested line segment, or empty string.
   function Line_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Count bounded sentence segments in Text.
   --
   --  Sentence boundaries are recognized after ASCII '.', '!', and '?',
   --  Unicode ellipsis, bounded Arabic, Greek, and Ethiopic question marks,
   --  Armenian full stop, Hebrew sof pasuq, Georgian paragraph separator,
   --  Devanagari danda, Ethiopic full stop, Myanmar section signs, CJK
   --  ideographic full stop, and fullwidth exclamation/question terminators.
   --  Closing quotes/brackets immediately after a terminator stay in the
   --  sentence, including bounded CJK and fullwidth closing punctuation.
   --  ASCII periods between bounded ASCII, Arabic-Indic, extended
   --  Arabic-Indic, Devanagari, Bengali, Gurmukhi, Gujarati, Odia, Tamil,
   --  Telugu, Kannada, Malayalam, Sinhala, Thai, Lao, Tibetan, Khmer,
   --  fullwidth Latin letters/digits, Myanmar, Limbu, New Tai Lue, Kayah Li, Javanese, Cham,
   --  Tai Tham, Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra,
   --  Brahmi, Sora Sompeng, Chakma, Sharada, Khudawadi, Newa, Tirhuta,
   --  Modi, Takri, Ahom, Warang Citi, Hanifi Rohingya, Garay, Osmanya,
   --  Dives Akuru, Sunuwar, Bhaiksuki, Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa,
   --  Gurung Khema, Kirat Rai, Ol Onal, Nag Mundari,
   --  Adlam, and Han decimal digits stay inside numeric text.
   --  Leading and bounded ASCII/Unicode separator whitespace is not
   --  counted as a sentence. This is not a full UAX #29 sentence segmenter.
   --
   --  @param Text Text to inspect.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Number of bounded sentence segments.
   function Sentence_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   with
     Global => null;

   --  Return the Nth bounded sentence segment from Text.
   --
   --  Index is 1-based. Zero or out-of-range indexes return the empty string.
   --  The returned sentence preserves original bytes and excludes surrounding
   --  whitespace used only as a separator.
   --
   --  @param Text Text to inspect.
   --  @param Index 1-based sentence index.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Original text of the requested sentence, or empty string.
   function Sentence_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Count bounded word segments in Text.
   --
   --  Word characters are ASCII letters/digits, bounded Arabic-Indic,
   --  extended Arabic-Indic, Devanagari, Bengali, Thai, NKo, fullwidth
   --  Latin letters/digits, halfwidth Katakana, Hangul compatibility Jamo,
   --  Myanmar,
   --  Limbu, New Tai Lue, Kayah Li, Javanese, Cham, Tai Tham, Balinese,
   --  Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Brahmi, Sora Sompeng,
   --  Chakma, Sharada, Khudawadi, Newa, Tirhuta, Modi, Takri, Ahom,
   --  Warang Citi, Hanifi Rohingya, Garay, Osmanya, Dives Akuru, Sunuwar, Bhaiksuki,
   --  Masaram Gondi, Gunjala Gondi, Tolong Siki, Kawi, Tangsa, Gurung Khema, Kirat Rai,
   --  Ol Onal, Tai Yo, Nag Mundari, Adlam,
   --  and Han decimal digits,
   --  plus bounded
   --  two-byte Latin,
   --  Greek, Cyrillic, Armenian, Hebrew, Arabic-range, Syriac, Thaana, and NKo
   --  UTF-8 elements,
   --  bounded combining marks including U+1AB0..U+1AFF, U+1DC0..U+1DFF,
   --  U+20D0..U+20FF, U+FE20..U+FE2F, and bounded Hebrew, Syriac,
   --  Thaana, NKo, Samaritan, and Mandaic marks,
   --  bounded three-byte Samaritan, Mandaic, Ogham, Runic,
   --  Cherokee, Canadian Aboriginal Syllabics, Tifinagh, Limbu, Tai Le,
   --  New Tai Lue, Buginese, Kayah Li, Rejang, Javanese, Cham, Tai Tham,
   --  Balinese, Sundanese, Lepcha, Ol Chiki, Vai, Saurashtra, Devanagari,
   --  Bengali, Thai, Georgian, Ethiopic,
   --  Hiragana, Katakana, halfwidth Katakana compatibility forms, Hangul
   --  compatibility Jamo, Han, and Hangul syllable elements, plus bounded
   --  four-byte Brahmi, Kaithi, Sora Sompeng, Chakma, Sharada, Khudawadi,
   --  Newa, Tirhuta, Modi, Takri, Ahom, Warang Citi, Linear B,
   --  Aegean Numbers, Lycian, Carian, Old Italic,
   --  Gothic, Old Permic, Ugaritic, Old Persian, Deseret, Shavian,
   --  Osmanya, Osage, Elbasan, Caucasian Albanian, Cypriot,
   --  Imperial Aramaic, Palmyrene, Phoenician, Lydian,
   --  Meroitic Hieroglyphs, Meroitic Cursive, Nabataean, Hatran,
   --  Kharoshthi, Old South Arabian, Old North Arabian, Manichaean,
   --  Avestan, Inscriptional Parthian, Inscriptional Pahlavi,
   --  Psalter Pahlavi, Old Turkic, Old Hungarian, Garay, Rumi Numeral Symbols,
   --  Vithkuqi, Todhri,
   --  Hanifi Rohingya, Yezidi, Old Sogdian, Sogdian, Old Uyghur,
   --  Chorasmian, Elymaic,
   --  Khojki, Multani, Grantha, Tulu-Tigalari, Siddham, Dogra,
   --  Dives Akuru, Nandinagari,
   --  Zanabazar Square, Soyombo, Pau Cin Hau, Sunuwar, Bhaiksuki, Marchen,
   --  Masaram Gondi, Gunjala Gondi, Tolong Siki, Makasar, Kawi, Cuneiform, Egyptian
   --  Hieroglyphs, Anatolian Hieroglyphs, Bamum Supplement, Gurung Khema,
   --  Tangsa, Kirat Rai, Tangut,
   --  Tangut Supplement, Khitan Small Script, Nushu, Medefaidrin, Beria Erfe, Toto,
   --  Ol Onal, Tai Yo, Nag Mundari, and Adlam elements, and bounded
   --  Latin/Hebrew/Arabic presentation forms.
   --  Apostrophes,
   --  right apostrophes, hyphens, and
   --  underscores connect words only when followed by another word element.
   --  ASCII '.', ',', and ':', plus Arabic decimal/thousands separators
   --  U+066B and U+066C, connect numeric word parts only when bounded
   --  decimal digits appear on both sides. Other punctuation, spacing, symbols, and
   --  unsupported bytes separate words. Locale is accepted for symmetry with
   --  the other locale helpers; this segmentation is not full UAX #29.
   --
   --  @param Text Text to inspect.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Number of bounded word segments.
   function Word_Count
     (Text   : String;
      Locale : Locale_Id := "")
      return Natural
   with
     Global => null;

   --  Return the Nth bounded word segment from Text.
   --
   --  Index is 1-based. Zero or out-of-range indexes return the empty string.
   --  The returned word preserves the original UTF-8 bytes from Text.
   --
   --  @param Text Text to inspect.
   --  @param Index 1-based word index.
   --  @param Locale Locale controlling future tailoring; currently bounded.
   --  @return Original text of the requested word, or empty string.
   function Word_At
     (Text   : String;
      Index  : Natural;
      Locale : Locale_Id := "")
      return String
   with
     Global => null;

   --  Return the parent locale for Item.
   --
   --  @param Item Locale identifier to inspect.
   --  @return Parent locale or empty string when no parent exists.
   function Parent
     (Item : Locale_Id)
      return String
   with
     Global => null,
     Post   => Parent'Result'Length <= Item'Length;
end I18N.Locales;
