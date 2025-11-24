# Flow Version Diff: Listener_Configuration_Main_Flow

## Summary
- **Version 22 (Active)**: Does NOT check `Enable_History__c` in the `Check_FlowdoConfig` decision
- **Version 23 (Draft/Inactive)**: DOES check `Enable_History__c` in the `Check_FlowdoConfig` decision

## Key Difference: Check_FlowdoConfig Decision

### Version 22 (Active) - Current Behavior
The `Check_FlowdoConfig` decision only checks `isActive__c`:

```xml
<decisions>
    <name>Check_FlowdoConfig</name>
    <label>Check FlowdoConfig</label>
    <locationX>833</locationX>
    <locationY>134</locationY>
    <defaultConnectorLabel>Default Outcome</defaultConnectorLabel>
    <rules>
        <name>isActive_Config</name>
        <conditionLogic>and</conditionLogic>
        <conditions>
            <leftValueReference>varFlowDoConfig.Flowdometer__isActive__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <booleanValue>true</booleanValue>
            </rightValue>
        </conditions>
        <!-- NOTE: Only ONE condition - no Enable_History__c check -->
        <connector>
            <targetReference>Reset_Trigger</targetReference>
        </connector>
        <label>isActive Config</label>
    </rules>
</decisions>
```

**Flow Path**: 
- If `isActive__c == true` → Proceeds to `Reset_Trigger` → `Get_ALL_Record_Types` → `Query_and_Parse_History_Records_Latest` (Apex method)
- If `isActive__c == false` → Takes default outcome (likely exits flow)

### Version 23 (Draft/Inactive) - Proposed Behavior
The `Check_FlowdoConfig` decision checks BOTH `isActive__c` AND `Enable_History__c`:

```xml
<decisions>
    <name>Check_FlowdoConfig</name>
    <label>Check FlowdoConfig</label>
    <locationX>833</locationX>
    <locationY>134</locationY>
    <defaultConnectorLabel>Default Outcome</defaultConnectorLabel>
    <rules>
        <name>isActive_Config</name>
        <conditionLogic>and</conditionLogic>
        <conditions>
            <leftValueReference>varFlowDoConfig.isActive__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <booleanValue>true</booleanValue>
            </rightValue>
        </conditions>
        <conditions>
            <!-- NEW CONDITION: Enable_History__c check -->
            <leftValueReference>varFlowDoConfig.Enable_History__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <booleanValue>true</booleanValue>
            </rightValue>
        </conditions>
        <connector>
            <targetReference>Reset_Trigger</targetReference>
        </connector>
        <label>isActive Config</label>
    </rules>
</decisions>
```

**Flow Path**:
- If `isActive__c == true` AND `Enable_History__c == true` → Proceeds to `Reset_Trigger` → `Get_ALL_Record_Types` → `Query_and_Parse_History_Records_Latest` (Apex method)
- If `isActive__c == false` OR `Enable_History__c == false` → Takes default outcome (likely exits flow)

## Impact Analysis

### Current Behavior (v22 Active)
- The flow will call the Apex method (`Query_and_Parse_History_Records_Latest`) whenever `isActive__c == true`, regardless of `Enable_History__c` value
- The Apex method itself handles the `Enable_History__c` toggle logic (as we fixed earlier)
- This means the flow always reaches the Apex method when active, and the Apex code decides whether to process history

### Proposed Behavior (v23 Draft)
- The flow will only call the Apex method when BOTH `isActive__c == true` AND `Enable_History__c == true`
- If `Enable_History__c == false`, the flow exits early and never calls the Apex method
- This creates a **double-check** scenario where:
  1. Flow level: Blocks execution if `Enable_History__c == false`
  2. Apex level: Also checks `Enable_History__c` and skips historical queries if `false` and `lastExecutionOn == null`

## Recommendation

**The v23 (Draft) version is INCORRECT** for the intended design because:

1. **It prevents new history queries**: When `Enable_History__c == false`, the flow exits early and never calls the Apex method. This means:
   - Historical queries (before `Last_Execution_On__c`) are correctly blocked ✅
   - **BUT** new history queries (after `Last_Execution_On__c`) are also blocked ❌

2. **The Apex code already handles this correctly**: The Apex method we fixed earlier properly differentiates between:
   - Historical queries (blocked when `Enable_History__c == false` AND `lastExecutionOn == null`)
   - New history queries (always allowed, regardless of toggle)

3. **The flow should always call the Apex method**: The Apex method needs to run to:
   - Update `Last_Execution_On__c` (even when skipping historical queries)
   - Process new history records (when `lastExecutionOn != null`)

## Correct Solution

**Keep the v22 (Active) behavior** - the flow should NOT check `Enable_History__c`. The decision should only check `isActive__c`, allowing the Apex method to handle the `Enable_History__c` toggle logic correctly.

