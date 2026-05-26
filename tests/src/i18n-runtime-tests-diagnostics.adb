with AUnit.Assertions;

with I18N.Diagnostics; use I18N.Diagnostics;
with I18N.Errors; use I18N.Errors;
with I18N.Observability; use I18N.Observability;
with I18N.Runtime.Compatibility;
with I18N.Arguments;

package body I18N.Runtime.Tests.Diagnostics is

   Max_Trace : constant Positive := 16;

   Trace_Events         :
     array (1 .. Max_Trace) of I18N.Observability.Trace_Event_Kind :=
       [others => I18N.Observability.Message_End];
   Trace_Count          : Natural := 0;
   First_Trace_Key      :
     String (1 .. I18N.Observability.Message_Key_Capacity) :=
       [others => Character'Val (0)];
   First_Trace_Key_Last : Natural := 0;

   procedure Reset_Trace is
   begin
      Trace_Count := 0;
      Trace_Events := [others => I18N.Observability.Message_End];
      First_Trace_Key := [others => Character'Val (0)];
      First_Trace_Key_Last := 0;
   end Reset_Trace;

   procedure Capture_Trace
     (Event : I18N.Observability.Trace_Event_Kind; Key : String) is
   begin
      if Trace_Count < Max_Trace then
         Trace_Count := Trace_Count + 1;
         Trace_Events (Trace_Count) := Event;
         if Trace_Count = 1 and then Key'Length > 0 then
            First_Trace_Key_Last :=
              Natural'Min (Key'Length, First_Trace_Key'Length);
            First_Trace_Key (1 .. First_Trace_Key_Last) :=
              Key (Key'First .. Key'First + First_Trace_Key_Last - 1);
         end if;
      end if;
   end Capture_Trace;

   function Captured_First_Key return String is
   begin
      if First_Trace_Key_Last = 0 then
         return "";
      end if;

      return First_Trace_Key (1 .. First_Trace_Key_Last);
   end Captured_First_Key;

   procedure Raising_Trace
     (Event : I18N.Observability.Trace_Event_Kind; Key : String)
   is
      pragma Unreferenced (Event, Key);
   begin
      raise Constraint_Error with "intentional trace failure";
   end Raising_Trace;

   procedure Add_Arg
     (Args : in out I18N.Arguments.Arguments; Key : String; Value : String) is
   begin
      I18N.Arguments.Set (Args => Args, Key => Key, Value => Value);
   end Add_Arg;

   procedure Test_Output_Unchanged_With_Trace
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Args, "name", "Ada");

      I18N.Runtime.Compatibility.Set_Trace_Callback (null);
      declare
         Without_Trace : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         Reset_Trace;
         I18N.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
         declare
            With_Trace : constant I18N.Errors.Result :=
              I18N.Runtime.Compatibility.Render (Runtime, Args);
         begin
            I18N.Runtime.Compatibility.Set_Trace_Callback (null);

            AUnit.Assertions.Assert
              (Condition => Without_Trace.Ok and then With_Trace.Ok,
               Message   => "both traced and untraced renders should succeed");
            AUnit.Assertions.Assert
              (Condition =>
                 I18N.Errors.Value_Text (Without_Trace)
                 = I18N.Errors.Value_Text (With_Trace),
               Message   => "trace callback must not change render output");
            AUnit.Assertions.Assert
              (Condition => I18N.Errors.Value_Text (With_Trace) = "Hello Ada",
               Message   =>
                 "expected rendered output should remain unchanged");
         end;
      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Output_Unchanged_With_Trace;

   procedure Test_Missing_Variable_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Parse_Error_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Missing_Branch_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Trace_Order (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Concurrent_Diagnostics_Are_Context_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Diagnostic_List_Overflow_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Metadata_Uses_Fixed_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Callback_Exception_Is_Non_Intrusive
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Metadata_Message_Key_Reaches_Start_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   overriding
   function Name (T : Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("I18N observability/diagnostics tests");
   end Name;

   overriding
   procedure Register_Tests (T : in out Test_Case) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Output_Unchanged_With_Trace'Access,
         "trace callback does not alter rendered output");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Variable_Diagnostic'Access,
         "missing variable produces structured diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Parse_Error_Diagnostic'Access,
         "invalid ICU produces parse diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Missing_Branch_Diagnostic'Access,
         "missing branch produces structured diagnostic");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Trace_Order'Access,
         "trace events appear start to ops to end");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Concurrent_Diagnostics_Are_Context_Local'Access,
         "concurrent diagnostics stay in caller-owned contexts");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Diagnostic_List_Overflow_Is_Bounded'Access,
         "diagnostic list overflow remains bounded and visible");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Metadata_Uses_Fixed_Storage'Access,
         "execution metadata uses fixed storage and truncates deterministically");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Callback_Exception_Is_Non_Intrusive'Access,
         "trace callback exceptions do not affect rendering");
      AUnit.Test_Cases.Registration.Register_Routine
        (T,
         Test_Metadata_Message_Key_Reaches_Start_Event'Access,
         "execution metadata message key reaches message start trace event");
   end Register_Tests;

   procedure Test_Missing_Variable_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Context : I18N.Runtime.Compatibility.Execution_Context;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Context);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              not Result.Ok
              and then Result.Error = I18N.Errors.Missing_Variable,
            Message   =>
              "missing variable should fail render deterministically");
         AUnit.Assertions.Assert
           (Condition =>
              I18N.Diagnostics.Has_Kind
                (Result.Diagnostics, I18N.Diagnostics.Missing_Variable),
            Message   => "missing variable diagnostic should be present");
         AUnit.Assertions.Assert
           (Condition =>
              I18N.Diagnostics.Key_Text
                (I18N.Diagnostics.Element (Result.Diagnostics, 1))
              = "name",
            Message   =>
              "missing variable diagnostic should include variable key");

      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Missing_Variable_Diagnostic;

   procedure Test_Parse_Error_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => not Result.Ok,
            Message   =>
              "invalid ICU should fail render through stored init error");
         AUnit.Assertions.Assert
           (Condition =>
              I18N.Diagnostics.Has_Kind
                (Result.Diagnostics, I18N.Diagnostics.Parse_Error),
            Message   => "parse diagnostic should be present for invalid ICU");

      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Parse_Error_Diagnostic;

   procedure Test_Missing_Branch_Diagnostic
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime, "{gender, select, male {He}}");
      Add_Arg (Args, "gender", "other");
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         AUnit.Assertions.Assert
           (Condition => not Result.Ok,
            Message   =>
              "missing required branch should fail deterministically");
         AUnit.Assertions.Assert
           (Condition =>
              I18N.Diagnostics.Has_Kind
                (Result.Diagnostics, I18N.Diagnostics.Missing_Branch),
            Message   => "missing branch diagnostic should be present");

      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Missing_Branch_Diagnostic;

   procedure Test_Trace_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message
        (Runtime,
         "Hello {name}, {count, plural, one {# file} other {# files}}");
      Add_Arg (Args, "name", "Ada");
      Add_Arg (Args, "count", "2");

      Reset_Trace;
      I18N.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         I18N.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok
              and then I18N.Errors.Value_Text (Result) = "Hello Ada, 2 files",
            Message   => "traced plural render should succeed");
         AUnit.Assertions.Assert
           (Condition => Trace_Count >= 5,
            Message   =>
              "trace should contain start, several operations, and end");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (1) = I18N.Observability.Message_Start,
            Message   => "first trace event should be message start");
         AUnit.Assertions.Assert
           (Condition =>
              Trace_Events (Trace_Count) = I18N.Observability.Message_End,
            Message   => "last trace event should be message end");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (2) = I18N.Observability.Op_Text,
            Message   => "first operation should be text");
         AUnit.Assertions.Assert
           (Condition => Trace_Events (3) = I18N.Observability.Op_Variable,
            Message   => "second operation should be variable");

      end;

      I18N.Runtime.Finalize (Runtime);
   end Test_Trace_Order;

   procedure Test_Concurrent_Diagnostics_Are_Context_Local
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime  : I18N.Runtime.Runtime;
      Failures : array (1 .. 4) of Boolean := [others => False] with Atomic_Components;

      task type Worker is
         entry Start (Index : Positive);
      end Worker;

      task body Worker is
         Id      : Positive := 1;
         Context : I18N.Runtime.Compatibility.Execution_Context;
      begin
         accept Start (Index : Positive) do
            Id := Index;
         end Start;

         declare
            Result : constant I18N.Errors.Result :=
              I18N.Runtime.Compatibility.Render (Runtime, Context);
         begin
            if Result.Ok
              or else
                not I18N.Diagnostics.Has_Kind
                      (Result.Diagnostics, I18N.Diagnostics.Missing_Variable)
              or else
                I18N.Diagnostics.Key_Text
                  (I18N.Diagnostics.Element (Result.Diagnostics, 1))
                /= "name"
            then
               Failures (Id) := True;
            end if;
         end;
      exception
         when others =>
            Failures (Id) := True;
      end Worker;

   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      I18N.Runtime.Compatibility.Set_Trace_Callback (null);

      declare
         Workers : array (1 .. 4) of Worker;
      begin
         for Index in Workers'Range loop
            Workers (Index).Start (Index);
         end loop;
      end;

      for Index in Failures'Range loop
         AUnit.Assertions.Assert
           (Condition => not Failures (Index),
            Message   =>
              "worker"
              & Integer'Image (Index)
              & " should have local diagnostics");
      end loop;

      I18N.Runtime.Finalize (Runtime);
   end Test_Concurrent_Diagnostics_Are_Context_Local;

   procedure Test_Diagnostic_List_Overflow_Is_Bounded
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      List : I18N.Diagnostics.Diagnostic_List;
   begin
      for Index in 1 .. I18N.Diagnostics.Max_Diagnostics + 3 loop
         I18N.Diagnostics.Add
           (List    => List,
            Kind    => I18N.Diagnostics.Missing_Variable,
            Message => "missing variable" & Integer'Image (Index),
            Key     => "name");
      end loop;

      AUnit.Assertions.Assert
        (Condition =>
           I18N.Diagnostics.Length (List) = I18N.Diagnostics.Max_Diagnostics,
         Message   => "diagnostic list length must remain fixed at capacity");
      AUnit.Assertions.Assert
        (Condition =>
           I18N.Diagnostics.Element (List, I18N.Diagnostics.Max_Diagnostics)
             .Kind
           = I18N.Diagnostics.Overflow_Warning,
         Message   => "last diagnostic should report bounded overflow");
      AUnit.Assertions.Assert
        (Condition =>
           I18N.Diagnostics.Key_Text
             (I18N.Diagnostics.Element
                (List, I18N.Diagnostics.Max_Diagnostics))
           = "diagnostics",
         Message   =>
           "overflow diagnostic should identify diagnostics capacity");
   end Test_Diagnostic_List_Overflow_Is_Bounded;

   procedure Test_Metadata_Uses_Fixed_Storage
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Metadata : I18N.Observability.Execution_Metadata;
      Long_Key :
        constant String (1 .. I18N.Observability.Message_Key_Capacity + 8) :=
          (others => 'k');
   begin
      I18N.Observability.Set_Message_Key (Metadata, Long_Key);
      I18N.Observability.Set_Locale (Metadata, "en");
      Metadata.Depth := 3;

      declare
         Stored_Key    : constant String :=
           I18N.Observability.Message_Key (Metadata);
         Stored_Locale : constant String :=
           I18N.Observability.Locale (Metadata);
      begin
         AUnit.Assertions.Assert
           (Condition =>
              Stored_Key'Length = I18N.Observability.Message_Key_Capacity,
            Message   =>
              "message key metadata should truncate to fixed capacity");
         AUnit.Assertions.Assert
           (Condition => Stored_Locale = "en",
            Message   =>
              "locale metadata should round-trip from fixed storage");
         AUnit.Assertions.Assert
           (Condition => Metadata.Depth = 3,
            Message   =>
              "metadata depth should remain caller-owned execution state");
      end;
   end Test_Metadata_Uses_Fixed_Storage;

   procedure Test_Callback_Exception_Is_Non_Intrusive
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Args    : I18N.Arguments.Arguments;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Args, "name", "Ada");

      I18N.Runtime.Compatibility.Set_Trace_Callback (Raising_Trace'Access);
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Args);
      begin
         I18N.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "Hello Ada",
            Message   =>
              "raising trace callback must not change render result");
      end;

      I18N.Runtime.Finalize (Runtime);
   exception
      when others =>
         I18N.Runtime.Compatibility.Set_Trace_Callback (null);
         I18N.Runtime.Finalize (Runtime);
         raise;
   end Test_Callback_Exception_Is_Non_Intrusive;

   procedure Test_Metadata_Message_Key_Reaches_Start_Event
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Runtime : I18N.Runtime.Runtime;
      Context : I18N.Runtime.Compatibility.Execution_Context;
   begin
      I18N.Runtime.Compatibility.Initialize_Message (Runtime, "Hello {name}");
      Add_Arg (Context.Args, "name", "Ada");
      I18N.Observability.Set_Message_Key (Context.Metadata, "greeting");

      Reset_Trace;
      I18N.Runtime.Compatibility.Set_Trace_Callback (Capture_Trace'Access);
      declare
         Result : constant I18N.Errors.Result :=
           I18N.Runtime.Compatibility.Render (Runtime, Context);
      begin
         I18N.Runtime.Compatibility.Set_Trace_Callback (null);

         AUnit.Assertions.Assert
           (Condition =>
              Result.Ok and then I18N.Errors.Value_Text (Result) = "Hello Ada",
            Message   => "metadata-backed render should succeed");
         AUnit.Assertions.Assert
           (Condition =>
              Trace_Count > 0
              and then Trace_Events (1) = I18N.Observability.Message_Start,
            Message   => "first event should be message start");
         AUnit.Assertions.Assert
           (Condition => Captured_First_Key = "greeting",
            Message   =>
              "message key metadata should be passed to start event");
      end;

      I18N.Runtime.Finalize (Runtime);
   exception
      when others =>
         I18N.Runtime.Compatibility.Set_Trace_Callback (null);
         I18N.Runtime.Finalize (Runtime);
         raise;
   end Test_Metadata_Message_Key_Reaches_Start_Event;

end I18N.Runtime.Tests.Diagnostics;
