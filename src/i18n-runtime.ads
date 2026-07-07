private with Ada.Containers.Vectors;
private with Ada.Containers.Indefinite_Hashed_Maps;
private with Ada.Strings.Hash;
private with Ada.Strings.Unbounded;

with I18N.Arguments;
with I18N.Diagnostics;
with I18N.Locales;
with I18N.Result;

private with I18N.Errors;
private with I18N.Compiled;
private with I18N.AST;

--  Stable runtime API.
--
--  Purpose:
--  This package owns runtime initialization, catalog/shard loading, catalog
--  validation, locale fallback, key resolution, and the stable public render
--  facades. Applications use Instance, Initialize, Initialize_Binary_File,
--  Load_File/Load_Binary_File/Load_Text, Validate_Catalog_File/Text,
--  Validate_Binary_Catalog_File/Text, Resolve, Render, Render_Into, Is_Valid,
--  and Finalize. Parser, validator, compiler, IR, cache, execution, formatter
--  implementation, generated CLDR data, internal error, buffer, and
--  observability packages are implementation details and are not part of the
--  public contract.
--
--  Error behavior:
--  Initialize records deterministic validity state. Public catalog Render returns
--  I18N.Result.Render_Result and does not raise for normal ICU/catalog/render
--  failures. Invalid runtimes render as Execution_Error. Loading and validation
--  report explicit statuses (Load_Result, Catalog_Validation_Result) instead of
--  raising.
--
--  Thread-safety:
--  Initialize and Finalize are setup/teardown operations and must not run
--  concurrently with renders on the same object. After successful
--  initialization, concurrent read-only public renders against the same runtime
--  are intended to be safe. Shared diagnostic callbacks must be externally
--  thread-safe.
--
--  Allocation behavior:
--  Initialization and loading may allocate for catalog storage and compilation.
--  Public Render returns a structured result containing a text view. Render_Into
--  is the public allocation-free path: it renders directly into caller-owned
--  fixed storage without building an intermediate dynamic buffer.
--
--  Message behavior:
--  Catalog messages support variables, plural/select/selectordinal with
--  locale-aware CLDR category selection, ICU-style apostrophe escaping, and the
--  deterministic formatting set: number skeletons such as {value, number},
--  {value, number, ::percent}, and {value, number, ::compact-short}; currency
--  formats such as {amount, currency, USD/standard},
--  {amount, currency, USD/unit-width-long}, and
--  {amount, number, ::currency/CHF precision-currency-cash}; date/time style
--  and skeleton formats such as {day, date, full}, {day, date, ::date-short},
--  {clock, time, ::time-short}, and {instant, datetime, ::yMdHHmmssz, UTC}; and
--  deterministic domain formatters for duration, byte size, unit,
--  measure-unit, relative-time, and list output. Number, currency, date/time,
--  and domain formatter output honors the supported locale digits and
--  deterministic CLDR-derived data boundary. Missing arguments report
--  Missing_Argument; malformed numeric, number, currency, date, time,
--  datetime, duration, byte-size, unit, relative-time, or list arguments report
--  Invalid_Argument.
--
--  Example:
--     I18N.Runtime.Initialize (Runtime, "messages.catalog");
--     Result := I18N.Runtime.Render (Runtime, "de-AT", "welcome", Args);
package I18N.Runtime is

   type Runtime is tagged limited private;
   subtype Instance is Runtime;

   --  Initialize a v1.1.0 runtime from the canonical catalog file format.
   --
   --  Catalog format is UTF-8-compatible ASCII text with one message per line:
   --
   --     locale.key = ICU message string
   --
   --  Blank lines and lines beginning with '#' are ignored. Quoted values are
   --  accepted and have their surrounding quotes removed. The reserved key
   --  "default_locale" sets the deterministic default locale used by fallback.
   --
   --  During initialization catalog structure and brace balance are validated,
   --  and entries are recorded behind a private normalized locale/key table.
   --  Invalid catalogs fail deterministically:
   --  Is_Valid becomes False and public catalog Render returns Execution_Error.
   --
   --  @param Item Runtime instance to initialize.
   --  @param Catalog_Path Path to a catalog file.
   procedure Initialize
     (Item         : in out Runtime;
      Catalog_Path : String);

   --  Initialize a runtime from a versioned binary catalog file.
   --
   --  The v1.1.0 binary catalog envelope is deterministic and versioned:
   --
   --     I18N-CATALOG-BINARY
   --     format_version=1
   --     ir_version=1
   --     payload=text
   --
   --  The blank line after the header is followed by canonical text catalog
   --  payload. The payload may also be encoded as payload=hex-text, where the
   --  body is ASCII hex bytes for the same canonical text catalog payload.
   --  Unsupported magic, format versions, IR versions, or payload kinds fail
   --  deterministically and leave the runtime invalid.
   --
   --  @param Item Runtime instance to initialize.
   --  @param Catalog_Path Path to a binary catalog file.
   procedure Initialize_Binary_File
     (Item         : in out Runtime;
      Catalog_Path : String);

   --  Append catalog entries from another canonical catalog file.
   --
   --  This preserves entries already loaded by Initialize or prior Load calls,
   --  validates the added catalog using the same rules as Initialize, and
   --  rejects duplicate locale/key pairs across all loaded catalogs. The
   --  reserved key "default_locale" is ignored during Load; the runtime default
   --  locale is established by Initialize.
   --
   --  @param Item Runtime instance to append to.
   --  @param Catalog_Path Path to a catalog file.
   procedure Load
     (Item         : in out Runtime;
      Catalog_Path : String);

   --  Stable v1.1.0 catalog render API.
   --
   --  Rendering does not mutate Runtime. It canonicalizes Locale casing and
   --  known CLDR language aliases, resolves it using deterministic fallback
   --  (for example de-AT -> de -> default locale), selects Key, and renders
   --  the selected ICU message. Normal ICU/render
   --  failures are returned as structured statuses and do not raise exceptions.
   --
   --  @param Item Initialized runtime instance.
   --  @param Locale Requested locale.
   --  @param Key Message key.
   --  @param Arguments Public argument map.
   --  @return Stable v1.1.0 public render result.
   function Render
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments)
      return I18N.Result.Render_Result;

   --  Return whether the last initialization produced a valid runtime.
   --
   --  @param Item Runtime instance to inspect.
   --  @return True when the catalog is valid for public rendering.
   function Is_Valid
     (Item : Runtime)
      return Boolean;

   --  Drop this runtime's references to catalog/message data. The global cache
   --  is intentionally not cleared by Finalize.
   --
   --  @param Item Runtime instance to finalize.
   procedure Finalize
     (Item : in out Runtime);

   ---------------------------------------------------------------------------
   --  Stable catalog-shard loading (deterministic, non-destructive).
   ---------------------------------------------------------------------------

   --  Deterministic policy applied when a loaded locale/key pair already exists
   --  in the runtime (or earlier in the same loaded input).
   type Duplicate_Policy is
     (Reject_Duplicates,   --  Loading fails on any duplicate locale/key pair.
      Keep_First,          --  Keep the existing entry; ignore the duplicate.
      Override_Previous);  --  Replace the previous entry with the new one.

   --  Outcome class for Load_File and Load_Text.
   type Load_Status is
     (Loaded,              --  All entries were ingested successfully.
      Source_Not_Found,    --  The catalog file does not exist or is not a file.
      Invalid_Catalog,     --  Catalog syntax or an ICU message was invalid.
      Duplicate_Rejected,  --  Reject_Duplicates hit an existing locale/key pair.
      Runtime_Invalid);    --  The runtime was already invalid before loading.

   --  Result of a non-destructive shard load.
   --
   --  On any non-Loaded status the runtime is left exactly as it was before the
   --  call: a failed load never installs partial entries and never corrupts an
   --  already usable runtime. Diagnostics carry optional structured detail.
   --
   --  The counters report exactly how the input was applied:
   --    Entries_Added    - new locale/key pairs inserted;
   --    Entries_Replaced - existing pairs overwritten (Override_Previous);
   --    Entries_Ignored  - duplicate pairs skipped (Keep_First).
   type Load_Result is record
      Status           : Load_Status := Invalid_Catalog;
      Entries_Added    : Natural := 0;
      Entries_Replaced : Natural := 0;
      Entries_Ignored  : Natural := 0;
      Diagnostics      : I18N.Diagnostics.Diagnostic_List;
   end record;

   --  Load catalog shards from a file into an existing runtime.
   --
   --  Multiple shards may be layered into one runtime (for example a base
   --  application catalog, then a library catalog, then a user override shard).
   --  Loading is transactional: either every entry in the file is ingested or
   --  the runtime is left unchanged. A "default_locale" directive is adopted
   --  only when the runtime has not established one yet (so Load_File/Load_Text
   --  can build a runtime from scratch); once Initialize or a prior load has set
   --  it, later shard directives are ignored. Unqualified keys bind to the
   --  current default locale.
   --
   --  @param Item Runtime instance to load into.
   --  @param Path Path to a catalog file.
   --  @param Result Outcome, entry count, and diagnostics.
   --  @param Policy Duplicate-handling policy. Default rejects duplicates.
   procedure Load_File
     (Item   : in out Instance;
      Path   : String;
      Result : out Load_Result;
      Policy : Duplicate_Policy := Reject_Duplicates);

   --  Load a versioned binary catalog shard from a file.
   --
   --  The decoded payload is ingested with the same transactional semantics as
   --  Load_File. Unsupported binary versions are rejected deterministically as
   --  Invalid_Catalog and do not mutate the runtime.
   --
   --  @param Item Runtime instance to load into.
   --  @param Path Path to a binary catalog file.
   --  @param Result Outcome, entry count, and diagnostics.
   --  @param Policy Duplicate-handling policy. Default rejects duplicates.
   procedure Load_Binary_File
     (Item   : in out Instance;
      Path   : String;
      Result : out Load_Result;
      Policy : Duplicate_Policy := Reject_Duplicates);

   --  Load catalog shards from an in-memory catalog string into a runtime.
   --
   --  Behaves exactly like Load_File but reads the catalog from Text. Source_Name
   --  is used only for diagnostics.
   --
   --  @param Item Runtime instance to load into.
   --  @param Source_Name Logical name used in diagnostics.
   --  @param Text Catalog text in the canonical line format.
   --  @param Result Outcome, entry count, and diagnostics.
   --  @param Policy Duplicate-handling policy. Default rejects duplicates.
   procedure Load_Text
     (Item        : in out Instance;
      Source_Name : String;
      Text        : String;
      Result      : out Load_Result;
      Policy      : Duplicate_Policy := Reject_Duplicates);

   ---------------------------------------------------------------------------
   --  Non-destructive catalog validation.
   ---------------------------------------------------------------------------

   --  Outcome of validating a catalog without touching any runtime.
   --
   --  Validation parses and validates every entry, detects duplicate keys
   --  within the input, invalid locale prefixes, invalid keys, and invalid ICU
   --  messages (including a missing required "other" branch). Diagnostics name
   --  the offending source line. It never mutates an existing runtime; if
   --  validation fails, any existing runtime remains usable.
   type Catalog_Validation_Result is record
      Valid       : Boolean := False;
      Entry_Count : Natural := 0;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   end record;

   --  Validate a catalog file without mutating any runtime.
   --
   --  @param Path Path to a catalog file.
   --  @return Validation outcome and diagnostics.
   function Validate_Catalog_File
     (Path : String)
      return Catalog_Validation_Result;

   --  Validate a versioned binary catalog file without mutating any runtime.
   --
   --  @param Path Path to a binary catalog file.
   --  @return Validation outcome and diagnostics.
   function Validate_Binary_Catalog_File
     (Path : String)
      return Catalog_Validation_Result;

   --  Validate catalog text without mutating any runtime.
   --
   --  @param Source_Name Logical name used in diagnostics.
   --  @param Text Catalog text in the canonical line format.
   --  @return Validation outcome and diagnostics.
   function Validate_Catalog_Text
     (Source_Name : String;
      Text        : String)
      return Catalog_Validation_Result;

   --  Validate versioned binary catalog text without mutating any runtime.
   --
   --  This is intended for tooling/tests that already hold the binary envelope
   --  in memory. It follows the same header and payload rules as
   --  Validate_Binary_Catalog_File.
   --
   --  @param Source_Name Logical name used in diagnostics.
   --  @param Text Binary catalog envelope text.
   --  @return Validation outcome and diagnostics.
   function Validate_Binary_Catalog_Text
     (Source_Name : String;
      Text        : String)
      return Catalog_Validation_Result;

   ---------------------------------------------------------------------------
   --  Runtime locale/tzdb data overrides.
   ---------------------------------------------------------------------------

   --  Outcome class for loading external deterministic runtime data.
   type Data_Load_Status is
     (Data_Loaded,
      Data_Source_Not_Found,
      Invalid_Data);

   --  Result of loading external deterministic runtime data.
   type Data_Load_Result is record
      Status      : Data_Load_Status := Invalid_Data;
      Diagnostics : I18N.Diagnostics.Diagnostic_List;
   end record;

   --  Load process-wide locale/tzdb overrides from text.
   --
   --  The v1.1.0 override format is line-oriented:
   --
   --     locale.xx.decimal_separator = ,
   --     locale.xx.group_separator = .
   --     locale.xx.uses_indian_grouping = true
   --     locale.xx.uses_day_month_year = true
   --     locale.xx.digit.0 = 0
   --     locale.xx.month.1 = January
   --     locale.xx.weekday.0 = Sunday
   --     locale.xx.date_style.short = d/M/yy
   --     locale.xx.available_format.yMMMd = d MMM y
   --     locale.xx.date_time_field_separator = " at "
   --     locale.xx.date_time_style_separator = " at "
   --     locale.xx.day_period_rule.morning1 = 04:00-10:00
   --     locale.xx.timezone_exemplar.Example/Zone = Example
   --     locale.xx.timezone_location_pattern = {0} Time
   --     locale.xx.timezone_location_pattern_standard = {0} Standard Time
   --     locale.xx.timezone_location_pattern_daylight = {0} Daylight Time
   --     locale.xx.timezone_short.Example/Zone = EXT
   --     locale.xx.list_final_separator = and
   --     locale.xx.unit.meter.unit-width-full-name.few = meters
   --     locale.xx.relative_exact.day.unit-width-full-name.-1 = yesterday
   --     locale.xx.relative_unit.day.many = days
   --     locale.xx.currency_symbol_first = true
   --     rbnf.xx.cardinal.2 = two
   --     rbnf.xx.cardinal.-2 = minus two
   --     rbnf.xx.ordinal.2 = second
   --     rbnf.xx.decimal_separator = point
   --     plural.rule.cardinal.xx.one = n is 1
   --     plural.rule.cardinal.xx.few = n mod 10 in 2..4
   --     timezone.Example/Zone.base_offset_minutes = 90
   --
   --  Loaded values are process-wide formatter data overrides. They are used
   --  before generated CLDR/tzdb fallback data and are transactional: malformed
   --  input installs no partial override set. LDML relativePattern and
   --  relativeTimePattern rows may use strict one-placeholder element text for
   --  relative affixes. LDML listPattern rows may use
   --  raw separators or strict {0}<separator>{1} pattern text, and CLDR
   --  listPattern type standard, or/disjunction, and unit containers provide
   --  context for child listPatternPart rows. Flexible
   --  day-period rules use half-open HH:MM-HH:MM ranges and may wrap midnight.
   --  LDML dayPeriodRuleSet and dayPeriodRules containers provide inherited
   --  locale lists for child dayPeriodRule rows. Exact LDML at rows are
   --  accepted for midnight at 00:00 and noon at 12:00.
   --  LDML unitDisplayName rows and unitName rows without count feed the
   --  other unit display slot. Unit and relative-unit count suffixes may use
   --  CLDR zero/one/two/few/many/other category names. LDML fields/field
   --  containers provide inherited relative unit and width for child relative
   --  and relativeTimePattern rows. LDML
   --  plurals and pluralRules containers provide inherited kind and
   --  space-separated locale lists for child pluralRule rows. LDML
   --  currency containers provide inherited ISO codes for child symbol and
   --  displayName rows. CLDR currencyFormats/currencyFormatLength containers
   --  provide context for bounded child currencyFormat pattern rows. LDML
   --  currencySpacing beforeCurrency/afterCurrency containers provide
   --  placement context for child insertBetween rows and accept
   --  currencyMatch/surroundingMatch metadata rows in that context. LDML
   --  defaultNumberingSystem rows and symbols numberSystem containers feed
   --  selected number-system decimal/group/sign/percent/exponent symbols. LDML
   --  monthContext/dayContext/quarterContext containers with type stand-alone
   --  feed stand-alone L/c/q skeleton names, including narrow width 5 rows, and
   --  monthWidth/dayWidth/quarterWidth and dayPeriodWidth containers provide
   --  inherited abbreviated/wide/narrow width context for child
   --  month/day/quarter/dayPeriod rows. LDML
   --  weekData containers with firstDay and minDays child rows feed locale
   --  week-data preferences. LDML
   --  date/time/dateTime format length containers provide style context for
   --  child pattern rows. LDML
   --  compoundUnitPattern rows with type per feed long or short per-unit
   --  separators from strict {0}<separator>{1} pattern text.
   --  RBNF spellout rows provide exact signed cardinal/ordinal spellout text,
   --  exact cardinal decimal spellout text, signed integer-part text for
   --  negative decimal spellout, and the decimal separator word used by number
   --  spellout skeletons. Literal numeric RBNF rule rows without substitutions
   --  are accepted as exact spellout rows; substitution-bearing rule rows feed
   --  bounded quotient/remainder composition.
   --  LDML timeZone rows and fixed-offset tzdb Zone/Link rows accept
   --  case-insensitive Z/UTC/GMT zero offsets plus +H, +HH, +HMM, +HHMM,
   --  +H:MM, and +HH:MM offsets, with matching negative numeric forms.
   --  Bounded fixed-offset tzdb Zone continuation rows use numeric or
   --  Jan-Dec until dates and optional HH[:MM[:SS]][u|g|z|s|w] times to
   --  feed runtime transition offsets; month/weekday tokens and Rule
   --  only/minimum/maximum year keywords are accepted case-insensitively.
   --  Full-line and trailing # comments are ignored in tzdb Zone,
   --  continuation, Rule, and Link rows.
   --  Checked normalized CLDR rows such as raw|day_month_year|xx and
   --  raw|symbol_first|xx feed the same date-style order and currency
   --  placement fields as key/value overrides; rbnf_text rows feed the
   --  spellout override table.
   --
   --  @param Source_Name Logical name used in diagnostics.
   --  @param Text Runtime data text.
   --  @return Load status and diagnostics.
   function Load_Data_Text
     (Source_Name : String;
      Text        : String)
      return Data_Load_Result;

   --  Load process-wide locale/tzdb overrides from a file.
   --
   --  @param Path Path to the runtime data file.
   --  @return Load status and diagnostics.
   function Load_Data_File
     (Path : String)
      return Data_Load_Result;

   --  Clear process-wide locale/tzdb runtime data overrides.
   procedure Clear_Runtime_Data;

   ---------------------------------------------------------------------------
   --  Key resolution through the locale fallback chain (no rendering).
   ---------------------------------------------------------------------------

   --  Outcome of a key-resolution query.
   type Resolve_Status is
     (Found,
      Missing_Key,
      Runtime_Invalid);

   Max_Resolved_Locale_Length : constant := 64;

   --  Result of Resolve. Use Resolved_Locale to read the locale that satisfied
   --  the request. When Status is not Found, the resolved locale is empty.
   type Resolve_Result is record
      Status               : Resolve_Status := Missing_Key;
      Resolved_Locale_Text : String (1 .. Max_Resolved_Locale_Length) :=
        [others => ' '];
      Resolved_Locale_Last : Natural range 0 .. Max_Resolved_Locale_Length := 0;
   end record;

   --  Return the locale that resolved the key (empty when Status /= Found).
   --
   --  @param Item Resolve result to inspect.
   --  @return Resolved locale identifier.
   function Resolved_Locale
     (Item : Resolve_Result)
      return I18N.Locales.Locale_Id
   is (Item.Resolved_Locale_Text (1 .. Item.Resolved_Locale_Last));

   --  Report whether a key resolves through the locale fallback chain without
   --  rendering it. Resolve does not require arguments and does not execute the
   --  message. It only answers whether the runtime can resolve Key for Locale
   --  through the runtime's deterministic canonicalization and fallback rules.
   --
   --  @param Item Initialized runtime instance.
   --  @param Locale Requested locale.
   --  @param Key Message key.
   --  @return Resolution status and the resolving locale.
   function Resolve
     (Item   : Instance;
      Locale : I18N.Locales.Locale_Id;
      Key    : String)
      return Resolve_Result;

   ---------------------------------------------------------------------------
   --  Bounded render facade (caller-owned output storage).
   ---------------------------------------------------------------------------

   --  Render a catalog message into caller-owned fixed output storage.
   --
   --  The caller-visible output path needs no allocation: rendering writes into
   --  Target. On success Last is the final written index (Target (Target'First
   --  .. Last) holds the output) and Status is Success. When the rendered text
   --  is longer than Target, Status is Buffer_Overflow, Target holds the prefix
   --  that fits, and Last is the number of characters written. On any other
   --  failure status, Last is 0 and Target contents are unspecified. This facade
   --  does not expose any private renderer, compiler, or cache internals.
   --
   --  @param Item Initialized runtime instance.
   --  @param Locale Requested locale.
   --  @param Key Message key.
   --  @param Arguments Public argument map.
   --  @param Target Caller-owned output buffer.
   --  @param Last Final written index, or 0 on non-overflow failure.
   --  @param Status Stable public render status.
   procedure Render_Into
     (Item      : Instance;
      Locale    : I18N.Locales.Locale_Id;
      Key       : String;
      Arguments : I18N.Arguments.Arguments;
      Target    : in out String;
      Last      : out Natural;
      Status    : out I18N.Result.Render_Status);

private

   use Ada.Strings.Unbounded;

   --  A compiled catalog entry: the parsed and validated ICU message AST is
   --  built once at load time (Root) and reused at render time. Source is kept
   --  for diagnostics only and never re-parsed on the render hot path.
   type Catalog_Entry is record
      Locale      : Unbounded_String;
      Message_Key : Unbounded_String;
      Source      : Unbounded_String;
      Root        : I18N.AST.Node_Access := null;
   end record;

   package Catalog_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Natural,
      Element_Type => Catalog_Entry);

   --  Deterministic (locale, key) -> compiled-entry index. The composite key is
   --  Locale & NUL & Key, giving O(1) per-locale lookup so message resolution is
   --  bounded by locale fallback depth. Stored indices stay stable because the
   --  catalog vector is only appended to or replaced in place, never compacted.
   package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Natural,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Runtime is tagged limited record
      Valid               : Boolean := True;
      Error               : I18N.Errors.Error_Kind := I18N.Errors.Parse_Error;

      --  Compatibility single-message state used only by the private
      --  I18N.Runtime.Compatibility child package and in-tree regression tests.
      --  The stable public catalog API does not expose or depend on this state.
      Message             : I18N.Compiled.Compiled_Message;
      Has_Message         : Boolean := False;

      Catalog             : Catalog_Vectors.Vector;
      Index               : Index_Maps.Map;
      Default_Locale      : Unbounded_String := To_Unbounded_String (I18N.Locales.Default_Locale_Name);
      Default_Locale_Seen : Boolean := False;
   end record;

end I18N.Runtime;
