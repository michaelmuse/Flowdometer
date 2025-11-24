# Comprehensive Flow Version Diff: Listener_Configuration_Main_Flow

## Summary
- **Version 22 (Active)**: Current production version
- **Version 23 (Draft/Inactive)**: Latest draft version (should NOT be activated)

---

## 1. Check_FlowdoConfig Decision Element ⚠️ **CRITICAL DIFFERENCE**

### Version 22 (Active)
```xml
<decisions>
    <name>Check_FlowdoConfig</name>
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
        <!-- ONLY ONE CONDITION - No Enable_History__c check -->
    </rules>
</decisions>
```

**Behavior**: Flow proceeds to Apex when `isActive__c == true` (regardless of `Enable_History__c`)

### Version 23 (Draft)
```xml
<decisions>
    <name>Check_FlowdoConfig</name>
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
            <!-- ADDED: Enable_History__c check -->
            <leftValueReference>varFlowDoConfig.Enable_History__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <booleanValue>true</booleanValue>
            </rightValue>
        </conditions>
    </rules>
</decisions>
```

**Behavior**: Flow only proceeds to Apex when BOTH `isActive__c == true` AND `Enable_History__c == true`

**⚠️ PROBLEM**: This incorrectly blocks new history queries when `Enable_History__c == false`

---

## 2. Field Reference Namespace Differences

### Version 22 (Active) - Uses Namespace Prefix
All custom field references include the `Flowdometer__` namespace prefix:

- `varFlowDoConfig.Flowdometer__isActive__c`
- `varFlowDoConfig.Flowdometer__Latest_Flow_Error_Message__c`
- `updateFlowdoConfig.Flowdometer__isActive__c`
- Field in `Reset_Trigger`: `Flowdometer__isActive__c`

### Version 23 (Draft) - No Namespace Prefix
All custom field references omit the namespace prefix:

- `varFlowDoConfig.isActive__c`
- `varFlowDoConfig.Enable_History__c`
- `varFlowDoConfig.Latest_Flow_Error_Message__c`
- Field in `Reset_Trigger`: `isActive__c`

**Impact**: 
- v22 uses fully qualified field names (with namespace)
- v23 uses unqualified field names (without namespace)
- Both should work in a namespaced org, but v22 is more explicit and safer

---

## 3. Update_FlowdoConfig_0 Element Location

### Version 22 (Active)
- **locationX**: `706`
- **locationY**: `674`

### Version 23 (Draft)
- **locationX**: `442`
- **locationY**: `2282`

**Impact**: Visual layout difference in Flow Builder. This is cosmetic only and doesn't affect functionality.

---

## 4. Apex Action Name Reference

### Version 22 (Active)
- **actionName**: `Flowdometer__ListenerFlowController` (with namespace)
- **nameSegment**: `Flowdometer__ListenerFlowController`

### Version 23 (Draft)
- **actionName**: `ListenerFlowController` (without namespace)
- **nameSegment**: `ListenerFlowController`

**Impact**: 
- v22 uses fully qualified class name
- v23 uses unqualified class name
- Both should work, but v22 is more explicit

---

## 5. Subflow Reference

### Version 22 (Active)
- **flowName**: `Flowdometer__Listener_Flow_Sub_Flow` (with namespace)

### Version 23 (Draft)
- **flowName**: `Listener_Flow_Sub_Flow` (without namespace)

**Impact**: 
- v22 uses fully qualified flow name
- v23 uses unqualified flow name
- Both should work, but v22 is more explicit

---

## 6. Status

### Version 22 (Active)
- **status**: `Active`

### Version 23 (Draft)
- **status**: `Draft`

---

## Summary of All Differences

| Element | Version 22 (Active) | Version 23 (Draft) | Impact |
|---------|-------------------|-------------------|--------|
| **Check_FlowdoConfig Decision** | Only checks `Flowdometer__isActive__c` | Checks BOTH `isActive__c` AND `Enable_History__c` | ⚠️ **CRITICAL** - v23 incorrectly blocks new history queries |
| **Field References** | Uses `Flowdometer__` namespace prefix | No namespace prefix | ⚠️ **MODERATE** - v22 is more explicit and safer |
| **Update_FlowdoConfig_0 Location** | X: 706, Y: 674 | X: 442, Y: 2282 | ✅ **COSMETIC** - Visual layout only |
| **Apex Action Name** | `Flowdometer__ListenerFlowController` | `ListenerFlowController` | ⚠️ **MODERATE** - v22 is more explicit |
| **Subflow Reference** | `Flowdometer__Listener_Flow_Sub_Flow` | `Listener_Flow_Sub_Flow` | ⚠️ **MODERATE** - v22 is more explicit |
| **Status** | Active | Draft | ✅ **EXPECTED** |

---

## Recommendations

### ❌ DO NOT ACTIVATE Version 23

**Reasons**:
1. **Critical Logic Error**: The `Enable_History__c` check in the decision element incorrectly blocks new history queries when the toggle is disabled
2. **Namespace Inconsistency**: v23 removes namespace prefixes, making it less explicit and potentially more fragile
3. **Apex Already Handles Toggle**: The Apex code (`ListenerFlowController.cls`) already correctly handles the `Enable_History__c` toggle logic, differentiating between historical and new history queries

### ✅ Keep Version 22 Active

**Reasons**:
1. **Correct Behavior**: Flow always calls Apex when `isActive__c == true`, allowing Apex to handle the toggle logic correctly
2. **Explicit Namespace References**: Uses fully qualified names, making dependencies clear
3. **Proven in Production**: Currently active and working correctly

### 🔧 If Version 23 Needs to Be Fixed

To make v23 correct, you would need to:
1. **Remove the `Enable_History__c` condition** from `Check_FlowdoConfig` decision (revert to v22 behavior)
2. **Add namespace prefixes** to all field references for consistency
3. **Add namespace prefixes** to Apex action and subflow references

However, it's recommended to **keep v22 active** and **delete or abandon v23** since v22 already has the correct behavior.

