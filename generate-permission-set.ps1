# Generate complete Permission Set with all field permissions

$flowFields = @(
    "Account__c", "Case__c", "Contact__c", "Created_by_Me__c", "Cycle_Time_Weekdays__c",
    "Days_Open_Since_Creation__c", "Days_since_Completion__c", "Days_to_first_Step_Weekdays__c",
    "Days_to_first_Step__c", "First_Step_Taken_at__c", "FirstStepOrNow__c",
    "Flow_Completion_Date__c", "Flow_Completion_Date_or_NOW__c", "Flow_Creation_Date__c",
    "Flow_Creation_Date_or_CREATED__c", "GoalCycleTime__c", "Goal__c",
    "Handle_Time_To_Current_Step_Weekdays__c", "HandleTimeToCurrent__c",
    "Handle_Time_vs_Goal__c", "Hours_Since_Created__c", "Hours_to_First_Step__c",
    "Lead__c", "Match_Goal_with_Flows__c", "Most_Recent_Step__c", "Name_of_Tracked_Record__c",
    "Next_Breach_At__c", "Opportunity__c", "Progress_Bar_vs_Goal__c", "Steps_in_Flow__c",
    "Total_Handle_Time__c", "Tracked_Field_Name__c", "Tracked_Object_ID__c",
    "Tracked_Object_Link__c", "Tracked_Object__c", "Type__c", "isGoal__c"
)

$stepFields = @(
    "Breach_happens_at__c", "BreachTime__c", "Created_by_Me__c", "CreatedByMe__c",
    "Ending_Timestamp_or_NOW__c", "EndTimestamp__c", "EndingTS__c",
    "Field_Value_Ending__c", "InitialTS__c", "Field_Value_Initial__c",
    "Final_Handle_Time_Weekdays__c", "Final_Handle_Time__c", "Flow_Goal_ID__c",
    "FlowGoalID__c", "Flow__c", "Goal_Breached__c", "Goal_Field_Change_Handle_Time_Hrs__c",
    "GoalUnit__c", "GoalBreached__c", "Handle_Time_Business_Hours__c",
    "Handle_Time_Hours_in_this_Step__c", "Handle_Time_over_Weekend_Days__c",
    "Handle_Time_vs_Goal__c", "Handle_Time_Weekdays__c", "HandleTimeVsGoal__c",
    "HandleTimeWeekdays__c", "HandleTimeWeekend__c", "History_Record_ID__c",
    "History_Record_ID_for_Last_Step__c", "Initial_Timestamp_or_CREATED__c",
    "InitialTimestamp__c", "isGoal__c", "Last_Step__c", "Next_Step__c",
    "Next_Step_vs_Goal_Next_Step__c", "NextStepVsGoalNextStep__c", "Plan_Next_Steps__c",
    "Progress_Bar_Elapsed_Color__c", "Progress_Bar_Remaining_Color__c",
    "ProgressBarElapsedColor__c", "ProgressBarRemainingColor__c", "ProgressBarVsGoal__c",
    "Sequence__c", "Sequence_and_Initial_Field_Value__c", "SequenceInitialFieldValue__c",
    "Start_Date__c", "StartDate__c", "Step_Goal__c", "Step_Handle_Time__c",
    "Step_is_currently_active__c", "StepActive__c", "StepVsTotal__c", "Success__c",
    "Terminal_Stage__c", "Time_since_breach_in_hrs__c", "TimeSinceBreach__c",
    "TimeUntilBreach__c", "Tracked_Field_Name_c__c", "Tracked_Object_Link__c",
    "Tracked_Object_Type__c", "TrackedFieldName__c", "TrackedObjectLink__c",
    "TrackedObjectType__c", "Type__c"
)

$listenerFields = @(
    "Enable_History__c", "Error_Message__c", "Field_To_Track__c", "Frequency__c",
    "Last_Check__c", "Last_Execution_On__c", "Latest_Flow_Error_Message__c",
    "Next_Check__c", "Object_Name__c", "TerminalStage__c", "Type__c",
    "Unprocessed_History_Records__c", "isActive__c"
)

# Generate field permissions XML
$flowFieldPerms = ($flowFields | ForEach-Object {
@"
    <fieldPermissions>
        <editable>true</editable>
        <field>Flow__c.$_</field>
        <readable>true</readable>
    </fieldPermissions>
"@
}) -join "`n"

$stepFieldPerms = ($stepFields | ForEach-Object {
@"
    <fieldPermissions>
        <editable>true</editable>
        <field>Step__c.$_</field>
        <readable>true</readable>
    </fieldPermissions>
"@
}) -join "`n"

$listenerFieldPerms = ($listenerFields | ForEach-Object {
@"
    <fieldPermissions>
        <editable>true</editable>
        <field>Listener__c.$_</field>
        <readable>true</readable>
    </fieldPermissions>
"@
}) -join "`n"

Write-Host "Generated field permissions for:"
Write-Host "  Flow__c: $($flowFields.Count) fields"
Write-Host "  Step__c: $($stepFields.Count) fields"
Write-Host "  Listener__c: $($listenerFields.Count) fields"
Write-Host ""
Write-Host "Copy these into Flowdometer_User.permissionset-meta.xml after the existing fieldPermissions section"
Write-Host ""
Write-Host "========== FLOW__C FIELDS =========="
Write-Host $flowFieldPerms
Write-Host ""
Write-Host "========== STEP__C FIELDS =========="
Write-Host $stepFieldPerms
Write-Host ""
Write-Host "========== LISTENER__C FIELDS =========="
Write-Host $listenerFieldPerms
