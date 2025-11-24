# Enable History Toggle – Deep Dive

> Goal: let admins skip heavy “backfill” history sweeps while continuing to collect **new** history as soon as a Listener establishes a baseline timestamp.

---

## Flow + Apex orchestration

### `Listener_Batch_Flow.flow-meta.xml`
- **Record-trigger path** (create/update, `isActive__c = true`) routes through:
  - `Has_This_Flow_Run_Before?` (`Last_Execution_On__c` null check).
  - `Listener_Has_Unprocessed_Records` to prioritize flushing `Unprocessed_History_Records__c`.
- **Scheduled paths**
  - `Run_Every_3_Minutes` watches `Last_Check__c`. If this field stops changing, the schedule stops firing.
  - `Run_Every_0_Minutes` watches `Last_Execution_On__c` so backlog batches rerun immediately.
- All paths converge on `Listener_Configuration_Main_Flow` with the current Listener injected via `varFlowdoConfig`.

### `Listener_Configuration_Main_Flow.flow-meta.xml`
- `Reset_Trigger` temporarily flips `isActive__c` to false to avoid recursion, then `Get_ALL_Record_Types` fetches the Flow/Step record types.
- `Query_and_Parse_History_Records_Latest` invokes `ListenerFlowController.parseRecordsToFlow`.
- `Check_Records` only enters `Listener_Flow_Sub_Flow` (creates Flow/Step tracker records) when Apex returns both `hasRecords = true` and `isCheckSuccess = true`.

**Implication:** If Apex ever reports `hasRecords = false`, the flow does nothing. The toggle logic in Apex therefore directly controls whether Flows/Steps appear downstream.

---

## History query pipeline (`ListenerFlowController.cls`)

### `buildQuery()` (history mode)
```apex
'SELECT Id, Field, OldValue, NewValue, CreatedDate, {parentIdField}
 FROM {HistoryObject}
 WHERE (Field =: fieldValue OR Field =: fieldName)'
```
- `fieldValue = 'created'` captures Salesforce’s synthetic “record created” row.
- `fieldName = listenerConfig.Field_To_Track__c` (validated earlier to prevent SOQL injection).
- Optional clauses:
  - `parentIdField IN :targetRecordIds` when we scope the query (e.g., backlog clean-up).
  - `Id NOT IN :historyRecordIdsToExclude` when `lastExecutionOn == null` so we skip rows already converted into Flow Steps.
- `getQueryModifiers(true, lastExecutionOn)` is the key differentiator:
  - When `lastExecutionOn != null`, it injects `CreatedDate > :lastExecutionOn`, producing an **incremental** query.
  - When `lastExecutionOn == null`, no timestamp filter is added, so we perform the historical sweep.

### `getLatestHistoryValues()`
1. Calls `buildQuery()` to assemble the SOQL string.
2. Executes the query, populating `historyRecordsMap` (parentId → history records) and `sortingDatetimeMap` for consistent ordering.
3. Returns both maps so `preparingResponse()` can hydrate the Flow DTOs (`lstListenerFlow`).

### `parseRecordsToFlow()`
1. Reads `enableHistoryTracking = listenerConfig.Flowdometer__Enable_History__c == true`.
2. **Early exit**: if the toggle is OFF **and** `lastExecutionOn == null`, skip the historical query altogether, but still set `Last_Execution_On__c` and `Last_Check__c` to `System.now()`. This establishes the baseline timestamp so future runs can execute incremental queries.
3. Process any JSON stored in `Unprocessed_History_Records__c`.
4. Run `getLatestHistoryValues()` to fetch rows (incremental runs now include the `CreatedDate > :lastExecutionOn` filter).
5. Load parent records and call `preparingResponse()` to build `lstListenerFlow`.
6. Batch leftovers (if more than 20 rows) back into `Unprocessed_History_Records__c`, then re-stamp both timestamps.

### Test coverage in `ListenerFlowControllerTest.cls`
- `testEnableHistoryToggle_Disabled_HistoricalQuery` asserts that the first-run backfill is skipped when the toggle is off.
- `testEnableHistoryToggle_Disabled_NewHistoryQuery` verifies that incremental runs proceed even though we cannot assert real history rows in Apex tests.
- Three complementary tests cover the toggle=ON path plus a defensive null-field scenario.

---

## Intended toggle behavior

| Scenario | Expected query | Flow/Step tracker creation |
| --- | --- | --- |
| Toggle OFF, first run (`lastExecutionOn == null`) | **No query** – we skip the historical sweep | No (intentionally skipped) |
| Toggle OFF, later runs (`lastExecutionOn != null`) | Includes `CreatedDate > :lastExecutionOn` | **Yes** – any new change should surface in `lstListenerFlow` |
| Toggle ON, first run | Full historical query + optional `NOT IN` clause | Yes, until backlog completes |
| Toggle ON, later runs | Same incremental query | Yes |

So the toggle should only control **historical** queries. Incremental queries must always continue once a baseline timestamp exists.

---

## Current regression

Later in `parseRecordsToFlow()` we pass the raw toggle value into the five-argument overload of `preparingResponse()`:

```apex
controllerInstance.preparingResponse(
    response,
    listenerConfig,
    sObjectMap,
    controllerInstance,
    enableHistoryTracking
);
```

That overload immediately returns (and sets `response.hasRecords = false`) whenever the flag is `false`. As a result:

- Every toggle-OFF listener reports “no records” even if the incremental query returned history rows.
- `Check_Records` in the flow never enters the branch that creates Flow/Step tracker records.
- Admins observe “no new flows/steps” for listeners with the toggle OFF, which matches the current org behavior.

The original regression we fixed (blocking all queries) is gone, but this downstream guard now suppresses legitimate incremental results.

---

## Preferred fix (keeps design intact)

1. **Keep** the existing guard that skips the historical sweep when `!enableHistoryTracking && lastExecutionOn == null`.
2. **Stop passing the raw toggle** into `preparingResponse()`. Instead:
   - Always call the four-argument overload, **or**
   - Pass a flag such as `skippedHistoricalQueryThisRun` that is `true` only when we actually skipped the query during this invocation.
3. **Continue updating** both `Last_Execution_On__c` and `Last_Check__c` whether we process records or deliberately skip the historical query; this keeps both scheduled paths firing.
4. **Add a regression test** that toggles history OFF, performs two updates on a tracked object after `Last_Execution_On__c` is set, and asserts that `hasRecords` (and ideally `lstListenerFlow`) becomes true. We can generate real history in tests by updating an Opportunity or Case inside `Test.startTest/Test.stopTest`.

These changes respect the original design: the toggle skips expensive backfills but never sacrifices ongoing change tracking.

---

## Troubleshooting checklist

- [ ] `Last_Check__c` advances after each run (verifies the 3‑minute schedule).
- [ ] Debug logs show `CreatedDate > :lastExecutionOn` when toggle OFF + timestamp present.
- [ ] `response.hasRecords` reflects the actual query result even when the toggle is OFF.
- [ ] `Unprocessed_History_Records__c` clears as batches finish; otherwise the listener stays on the immediate scheduled path.

Once the `preparingResponse()` short-circuit is addressed, listeners with `Enable_History__c = false` will resume creating Flow/Step tracker records for new history while still skipping the initial backfill.***

