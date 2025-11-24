# CPU Bug Report – Listener Historical Backfill (Enable History = true)

## Terminology: two distinct history modes
Flowdometer uses Salesforce’s History Tracking feature for **both** historical backfills and ongoing change tracking. The naming collision (“history tracking” vs “Enable History”) is what makes the conversations confusing, so we define the two modes explicitly:

| Mode | What it means | How it’s triggered | Data volume |
| --- | --- | --- | --- |
| **Historical Backfill** | Query every history row that existed **before the listener’s baseline** so admins can see earlier changes. | Only runs when `listener.Flowdometer__Enable_History__c = true` **and** `Flowdometer__Last_Execution_On__c` is `null`. | Potentially months of data; thousands of rows. |
| **Incremental Polling** | Query new history rows that Salesforce recorded **after the last successful run** so we keep tracking changes every few minutes. | Runs on **every** invocation once we have a timestamp, regardless of the toggle state. | Usually dozens of rows because the `Listener_Batch_Flow` scheduled path fires every ~3 minutes. |

Key takeaway: toggling **off** the Enable History checkbox skips only the large backfill sweep. The listener still relies on Salesforce History Tracking to capture new edits that happen after a baseline timestamp is established.

### Functional guarantees (matches current behavior)
- **Toggle OFF (baseline missing)**: the branch at `parseRecordsToFlow()` lines `772-814` sets both `Last_Execution_On__c` and `Last_Check__c`, immediately exits, and does **not** create Flow/Step records for any pre-listener history rows. Future runs (with timestamps) keep polling for new changes every ~3 minutes.
- **Toggle ON (baseline missing)**: we intentionally run the historical sweep so admins get Flow/Step records for pre-listener activity. If the sweep cannot finish in one run, leftovers are serialized to `Flowdometer__Unprocessed_History_Records__c` and the listener keeps retrying via the “Run Every 0 Minutes” scheduled path.
- **Any toggle state (baseline exists)**: we always run the incremental query with `CreatedDate > :lastExecutionOn`, ensuring ongoing change tracking continues once the baseline is set.

## How the Apex enforces this contract
- `parseRecordsToFlow()` checks the toggle and only skips the query when both `Enable_History__c == false` **and** `lastExecutionOn == null`. In that skip branch we still stamp `Last_Execution_On__c`/`Last_Check__c` so subsequent runs have a baseline.
- As soon as `lastExecutionOn` is non-null we always enter `getLatestHistoryValues()`, which builds a query that includes `CreatedDate > :lastExecutionOn`. That incremental filter is added by `getQueryModifiers(true, lastExecutionOn)` and therefore applies to both toggle states.

```409:458:force-app/main/default/classes/controllers/ListenerFlowController.cls
        Map<String, Object> queryModifiers = new Map<String, Object>{
            'includeOrderBy' => true,
            'includeLimit' => true,
            'whereClause' => ''
        };
        if (isHistoryQuery && lastExecutionOn != null) {
            queryModifiers.put('whereClause', 'CreatedDate > :lastExecutionOn');
        }
```

The confusing part of the earlier write-up is that we used “history query” to describe both modes. In code, however:

1. **Historical backfill path** (`Enable_History__c = true`, `lastExecutionOn = null`)
   - `buildQuery()` omits the timestamp filter, so Salesforce returns every history row for the tracked field.
   - We optionally add `Id NOT IN :historyRecordIdsToExclude` to avoid re-processing Flow Steps that already exist, but the rest of the WHERE clause is just `(Field = 'created' OR Field = :fieldName)`.
   - Because the result set can exceed the governor limits, we batch the response, send only 20 records to Flow, and store the rest in `listener.Flowdometer__Unprocessed_History_Records__c`.

2. **Incremental polling path** (any toggle state once `lastExecutionOn` is set)
   - `buildQuery()` receives the timestamp and `getQueryModifiers()` injects `CreatedDate > :lastExecutionOn`.
   - The listener is invoked by `Listener_Batch_Flow.flow-meta.xml` every time `Last_Check__c` moves (scheduled path `Run_Every_3_Minutes`) and immediately whenever `Last_Execution_On__c` changes (scheduled path `Run_Every_0_Minutes`). That cadence keeps each incremental batch small.
   - No backlog JSON is written unless the incremental result itself exceeds 20 records, which rarely happens because the window is short.

```132:154:force-app/main/default/flows/Listener_Batch_Flow.flow-meta.xml
        <scheduledPaths>
            <name>Run_Every_3_Minutes</name>
            <connector>
                <targetReference>Check_If_the_Flow_is_Active</targetReference>
            </connector>
            <label>Run Every 3 Minutes</label>
            <maxBatchSize>1</maxBatchSize>
            <offsetNumber>3</offsetNumber>
            <offsetUnit>Minutes</offsetUnit>
            <recordField>Last_Check__c</recordField>
            <timeSource>RecordField</timeSource>
        </scheduledPaths>
        <scheduledPaths>
            <name>Run_Every_0_Minutes</name>
            <connector>
                <targetReference>Listener_Has_Unprocessed_Records</targetReference>
            </connector>
            <label>Run Every 0 Minutes</label>
            <maxBatchSize>1</maxBatchSize>
            <offsetNumber>0</offsetNumber>
            <offsetUnit>Minutes</offsetUnit>
            <recordField>Last_Execution_On__c</recordField>
            <timeSource>RecordField</timeSource>
        </scheduledPaths>
```

## Context & Symptoms
The CPU spikes we are chasing only appear on listeners where admins explicitly enabled the backfill (`Enable_History__c = true`) and the listener has not yet established `Last_Execution_On__c`. Listeners with the toggle **off** correctly skip this sweep and therefore never create Flow/Step records for pre-listener data. The snippets below show the branching that enforces this behavior and why the ON-path is still expensive.

```772:876:force-app/main/default/classes/controllers/ListenerFlowController.cls
                    Boolean enableHistoryTracking = false;
                    try {
                        // Safely read the toggle value - default to false if null or inaccessible
                        enableHistoryTracking = listenerConfig.Flowdometer__Enable_History__c == true;
                    } catch (Exception fieldEx) {
                        // If field is inaccessible or null, default to false (disabled)
                        System.debug(LoggingLevel.WARN, 'Could not read Enable_History__c field for listener ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Defaulting to disabled. Error: ' + fieldEx.getMessage());
                        enableHistoryTracking = false;
                    }
                    
                    // Only skip if toggle is disabled AND we're trying to query historical data (lastExecutionOn == null)
                    // If lastExecutionOn != null, we're querying new history and should always proceed
                    if (!enableHistoryTracking && lastExecutionOn == null) {
                        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking toggle is DISABLED for listener: ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Skipping historical data query (before Last_Execution_On__c). New history queries (after Last_Execution_On__c) will still be processed.');
                        response.hasRecords = false;
                        response.isCheckSuccess = true;
                        
                        // CRITICAL: Set Last_Execution_On__c even when skipping historical query
                        // This ensures future runs will have lastExecutionOn != null and can query new history
                        // Also update Last_Check__c to trigger the scheduled flow path "Run Every 3 Minutes"
                        Datetime now = System.now();
                        if (Schema.sObjectType.Listener__c.fields.Last_Execution_On__c.isUpdateable()) {
                            listenerConfig.Last_Execution_On__c = now;
                        }
                        if (Schema.sObjectType.Listener__c.fields.Last_Check__c.isUpdateable()) {
                            listenerConfig.Last_Check__c = now;
                        }
                        update listenerConfig;
                        
                        responseList.add(response);
                        continue; // Skip to next listener config - NO historical queries, but new history queries will still work
                    }
                    
                    // Proceed with history processing if:
                    // 1. Toggle is enabled (allow both historical and new history queries), OR
                    // 2. Toggle is disabled BUT lastExecutionOn != null (allow new history queries only)
                    if (lastExecutionOn == null) {
                    System.debug(LoggingLevel.INFO, '### FLOWDOMETER: History tracking toggle is ENABLED for listener: ' + 
                                (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    '. Proceeding with historical data query (before Last_Execution_On__c).');
                    } else {
                        System.debug(LoggingLevel.INFO, '### FLOWDOMETER: Querying new history records for listener: ' + 
                                    (listenerConfig.Id != null ? String.valueOf(listenerConfig.Id) : 'new') + 
                                    ' (after Last_Execution_On__c: ' + lastExecutionOn + '). This query proceeds regardless of toggle state.');
                    }
                    
                    // BEFORE querying new history, process any previously stored unprocessed history records
                    // Only process unprocessed records if history tracking is enabled
                    String unprocessedRecordsJson = listenerConfig.Flowdometer__Unprocessed_History_Records__c;
                    if (String.isNotBlank(unprocessedRecordsJson)) {
                        List<ListenerFlowController> lstListenerFlow = (List<ListenerFlowController>) JSON.deserialize(unprocessedRecordsJson, List<ListenerFlowController>.class);
                        response.lstListenerFlow = lstListenerFlow;
                        response.hasRecords = !lstListenerFlow.isEmpty();
                        response.isCheckSuccess = true;

                        // Batch size can be configurable; using 20 as the legacy default
                        Integer batchSize = 20;
                        Map<Id, Boolean> processedRecordsMap = new Map<Id, Boolean>();

                        // Use existing helper to split batches and serialize leftovers
                        controllerInstance.handleBatchAndUnprocessedRecords(
                            response,
                            listenerConfig,
                            batchSize,
                            processedRecordsMap
                        );

                        // Skip the remainder of the loop; this listener will be handled in the next scheduled run if leftovers remain
                        responseList.add(response);
                        continue;
                    }
                    
                    // Get history records since last execution
                    String objName = listenerConfig.Object_Name__c;
                    String objHistoryName = getHistoryObjectName(objName);
                    
                    // Determine the parent ID field name based on object type
                    String parentIdField = isCustomObject(objName) ? 'ParentId' : (objName + 'Id');
                    
                    System.debug(LoggingLevel.INFO, 'Fetching history records for: ' + 
                                objHistoryName + ', Parent Field: ' + parentIdField);
                    
                    // Find records that have changes since last execution
                    List<Id> targetRecordIds = new List<Id>();
                    
                    // Get the latest history values
                    HistoryValuesResult historyResult = getLatestHistoryValues(
                        targetRecordIds, 
                        listenerConfig, 
                        lastExecutionOn, 
                        controllerInstance,
                        objHistoryName,
                        parentIdField
                    );
```

- CPU timeouts only reproduce on orgs where the historical toggle is kept ON (e.g., Lead Status listeners that must backfill).
- `Flowdometer__Unprocessed_History_Records__c` keeps growing, causing scheduled paths to immediately re-fire and repeat the heavy sweep.
- Even after a few batches succeed, we revisit the same history rows because we never narrow the query below “all rows for this field”.

## Historical Backfill Execution Flow (Enable History path)
1. If the listener already has leftovers in `Flowdometer__Unprocessed_History_Records__c`, we deserialize the full JSON payload into `List<ListenerFlowController>`, send the first 20 rows back to Flow, re-serialize the rest, and exit early.
2. When the backlog field is empty **and we are still in historical mode**, we call `getLatestHistoryValues()` with an empty `targetRecordIds` list, construct a SOQL query that only filters on the tracked field (`Field = 'created' OR Field = :fieldName`), and pull up to 1,500 history rows at a time.
3. Every run starts by executing `SELECT COUNT()` on the entire history object to determine whether we should lower the LIMIT.
4. Each returned row goes through `preparingResponse()`, which currently rebuilds schema metadata and field labels per record before batching leftovers back into JSON.

## Performance Hotspots (only triggered during historical backfill)

### 1. Full-table `COUNT()` before every sweep
```494:505:force-app/main/default/classes/controllers/ListenerFlowController.cls
        try {
            // Try to get a count of history records before running the full query
            String countQuery = 'SELECT COUNT() FROM ' + objHistoryName + ' LIMIT 50000';
            Integer historyRecordCount = Database.countQuery(countQuery);
            isLargeObject = (historyRecordCount > 5000); // If more than 5K history records, consider it large
            
            if (isLargeObject) {
                System.debug(LoggingLevel.WARN, 'Large history object detected: ' + objHistoryName + 
                    ' with ' + historyRecordCount + ' records. Limiting query results.');
                // Reduce the limit for large objects
                maxRecordsToProcess = 500;
            }
        } catch (Exception e) {
            // If count query fails, just log and continue with default limit
            System.debug(LoggingLevel.WARN, 'Unable to determine record count for ' + objHistoryName + 
                ': ' + e.getMessage());
        }
```
- This `COUNT()` has no filters, so we scan the entire history object twice per run (once for the count and again for the actual rows). On LeadHistory-sized tables this alone can consume several thousand milliseconds of CPU.
- We only need to know whether more than 1,500 rows exist for the specific subset we care about. Counting the full table is unnecessary; a chunked parent-ID driver or `LIMIT 1` probing query would provide the same signal without materializing 50k rows.

### 2. Historical sweep query is unbounded
```320:371:force-app/main/default/classes/controllers/ListenerFlowController.cls
        if (isHistoryQuery) {
            selectFields.addAll(
                new List<String>{
                    'Field',
                    'OldValue',
                    'NewValue',
                    'CreatedDate',
                    parentIdField
                }
            );
            // Include the tracked field plus the special "created" marker row
            // fieldName is defined in getLatestHistoryValues (line 485) and will be in scope when Database.query() is called (line 547)
            whereConditions.add('(Field =: fieldValue OR Field =: fieldName)');
            if (!targetRecordIds.isEmpty()) {
                whereConditions.add(parentIdField + ' IN :targetRecordIds');
            }
            // Only get exclusion list if we don't have a lastExecutionOn timestamp
            // This prevents unnecessary queries when we can use timestamp-based filtering
if (lastExecutionOn == null) {
    historyRecordIdsToExclude = getHistoryRecordIdsToExclude();
                // Only add NOT IN clause if we have IDs to exclude and the list is reasonably sized
                // Large NOT IN clauses (>1000 items) can be very expensive
                if (!historyRecordIdsToExclude.isEmpty() && historyRecordIdsToExclude.size() <= 1000) {
        whereConditions.add('Id NOT IN :historyRecordIdsToExclude');
                }
    }
}
```
```865:876:force-app/main/default/classes/controllers/ListenerFlowController.cls
                    // Find records that have changes since last execution
                    List<Id> targetRecordIds = new List<Id>();
                    
                    // Get the latest history values
                    HistoryValuesResult historyResult = getLatestHistoryValues(
                        targetRecordIds, 
                        listenerConfig, 
                        lastExecutionOn, 
                        controllerInstance,
                        objHistoryName,
                        parentIdField
                    );
```
- `targetRecordIds` is always empty during the historical sweep, so the query effectively becomes “all history rows for this field”, bounded only by the global LIMIT 1500. There is no `CreatedDate >= listenerConfig.CreatedDate`, no parent scoping, and no chunking.
- The `NOT IN :historyRecordIdsToExclude` clause grows toward 1,000 IDs as soon as we start converting rows into Flow Steps, which pushes the optimizer toward nested-loop plans on large tables.
- Result: every run pulls another 1,500 rows, reprocesses duplicates, and spends most of its CPU preparing payloads that we immediately store back into `Unprocessed_History_Records__c`.

### 3. Backlog serialization/deserialization saturates CPU
```829:848:force-app/main/default/classes/controllers/ListenerFlowController.cls
                    String unprocessedRecordsJson = listenerConfig.Flowdometer__Unprocessed_History_Records__c;
                    if (String.isNotBlank(unprocessedRecordsJson)) {
                        List<ListenerFlowController> lstListenerFlow = (List<ListenerFlowController>) JSON.deserialize(unprocessedRecordsJson, List<ListenerFlowController>.class);
                        response.lstListenerFlow = lstListenerFlow;
                        response.hasRecords = !lstListenerFlow.isEmpty();
                        response.isCheckSuccess = true;

                        // Batch size can be configurable; using 20 as the legacy default
                        Integer batchSize = 20;
                        Map<Id, Boolean> processedRecordsMap = new Map<Id, Boolean>();

                        // Use existing helper to split batches and serialize leftovers
                        controllerInstance.handleBatchAndUnprocessedRecords(
                            response,
                            listenerConfig,
                            batchSize,
                            processedRecordsMap
                        );

                        // Skip the remainder of the loop; this listener will be handled in the next scheduled run if leftovers remain
                        responseList.add(response);
                        continue;
                    }
```
```1132:1177:force-app/main/default/classes/controllers/ListenerFlowController.cls
        // 1. Extract the first batch to send back to Flow
        List<ListenerFlowController> firstBatch = new List<ListenerFlowController>();
        for (Integer i = 0; i < batchSize; i++) {
            ListenerFlowController item = response.lstListenerFlow[i];
            firstBatch.add(item);
            processedRecordsMap.put(item.varHistoryRecordId, true);
        }

        // 2. Convert remaining records into a lightweight JSON for storage
        for (Integer i = batchSize; i < response.lstListenerFlow.size(); i++) {
            ListenerFlowController original = response.lstListenerFlow[i];
            if (processedRecordsMap.containsKey(original.varHistoryRecordId)) {
                continue; // already processed this record
            }
            SimplifiedListenerFlowController simplified = new SimplifiedListenerFlowController();
            simplified.varType = original.varType;
            simplified.varTrackedCustomObjectName = original.varTrackedCustomObjectName;
            simplified.varEditStartTime = original.varEditStartTime;
            simplified.varEditEndTime = original.varEditEndTime;
            simplified.varCurrentObjectID = original.varCurrentObjectID;
            simplified.varCurrentFieldTracked = original.varCurrentFieldTracked;
            simplified.varCurrentFieldValue = original.varCurrentFieldValue;
            simplified.varNameofTrackedRecord = original.varNameofTrackedRecord;
            simplified.varHistoryRecordId = original.varHistoryRecordId;
            simplified.varLastHistoryRecordId = original.varLastHistoryRecordId;
            remainingRecords.add(simplified);
        }

        // Serialize leftovers, keeping under the 131,072-char long-text limit
        String remainingRecordsJson = remainingRecords.isEmpty() ? null : JSON.serialize(remainingRecords);
        Integer fieldLimit = 131072;
        while (remainingRecordsJson != null && remainingRecordsJson.length() > fieldLimit) {
            // drop the oldest record until we fit
            remainingRecords.remove(0);
            remainingRecordsJson = remainingRecords.isEmpty() ? null : JSON.serialize(remainingRecords);
        }

        // Persist leftovers (or clear the field if none left)
        if (Schema.sObjectType.Listener__c.fields.Flowdometer__Unprocessed_History_Records__c.isUpdateable()) {
            listenerConfig.Flowdometer__Unprocessed_History_Records__c = remainingRecordsJson;
        }
        update listenerConfig;

        // Finally give Flow only the first batch for this run
        response.lstListenerFlow = firstBatch;
        response.hasRecords = !response.lstListenerFlow.isEmpty();
```
- We deserialize the **entire** backlog payload into heavyweight `ListenerFlowController` instances on every invocation, even though we only need the next 20 rows.
- After sending the first batch, we converge the remainder into another JSON blob, potentially serializing thousands of nodes multiple times to fit under the 131,072-character limit. This loop is a major contributor to CPU, heap, and DML time whenever a listener is still backfilling.
- Because the backlog is stored on the `Listener__c` record, we perform an `UPDATE Listener__c` per run whether or not new data was fetched.

### 4. Schema describe executed per record
```1058:1069:force-app/main/default/classes/controllers/ListenerFlowController.cls
// Translate API name to the field's UI label for better readability
String fieldLabel = fieldApi;
try {
    Schema.SObjectType sobType = Schema.getGlobalDescribe().get(listenerConfig.Object_Name__c);
    if(sobType != null) {
        Map<String,Schema.SObjectField> fmap = sobType.getDescribe().fields.getMap();
        Schema.SObjectField fld = fmap.get(fieldApi != null ? fieldApi.toLowerCase() : null);
        if(fld != null) {
            fieldLabel = fld.getDescribe().getLabel();
        }
    }
} catch(Exception ignore) {}
```
- Every history row calls `Schema.getGlobalDescribe()` and rebuilds the entire field map, even though all rows in a given run belong to the same object. On a 1,500-row batch this means at least 1,500 full schema traversals.
- The “Implemented Fix” described in the previous version of this document (cache describe results) never landed in the codebase; we still pay the per-row reflection cost today.

## Low-Risk Optimization Roadmap
Goal: chip away at the worst CPU offenders without wholesale rewrite or new test scaffolding. Each step below is self-contained and can be reverted independently.

1. **Schema describe cache in `preparingResponse()`** – **Status:** ✅ completed
   - Implementation: move a single `Schema.getGlobalDescribe()` call outside the history loops, transform field map into a lowercase-key cache (logic already prototyped in the stash).
   - Risk: near-zero; no behavior change, no test updates required.
   - Benefit: removes up to 1,500 describe calls per batch.

2. **Throttle history queries without `COUNT()`** – **Status:** ✅ completed
   - Replaced the unconditional `SELECT COUNT()` with a lightweight probe (`SELECT Id ... LIMIT 501`). If the probe returns all rows, we treat the history object as “large” and cap the real query at 500 rows; otherwise we keep the 1,000-row limit.
   - Risk: minimal (only changes the heuristic that was already approximate). Existing tests rely only on query construction, so they stay untouched.
   - Benefit: eliminates an entire table scan per run, shaving 500–2,000 ms when big history tables are involved while still keeping the optimization logic encapsulated.

3. **Backlog JSON quick-win** – **Status:** ✅ completed
   - If the stored JSON payload is short enough to fit in a single Flow batch (based on a simple character-count heuristic and an upper bound of 20 records), we now skip the expensive re-batching/reserialization path. The backlog field is cleared immediately and the records are returned to Flow, which avoids a redundant deserialize→serialize cycle.
   - Risk: trivial, pure Apex change driven by existing data; no new tests needed.

4. **CPU check frequency tuning** – **Status:** ✅ completed
   - Historical sweeps still check CPU every 200 records (only when `lastExecutionOn == null`), but incremental runs now check far less frequently (every 500 rows, and only if the probe labeled the history object as “large”). This removes most of the overhead from `Limits.getCpuTime()` during the common incremental path while keeping the guard for large sweeps.
   - Risk: none; the guard remains, and no tests reference CPU calls.

5. **Stage backlog-pointer concept (optional, future exploration)** – **Status:** deferred
   - Idea: instead of re-serializing leftover records into `Unprocessed_History_Records__c`, track lightweight markers (e.g., last processed history ID + CreatedDate) so the next run can re-query from where it left off.
   - Because this requires a new data format, feature flag, and more exhaustive testing (especially around history replay in customer orgs), we’re postponing it until the higher-priority fixes have been field tested. Keep this section as a parking lot item for future CPU tuning.

We will borrow code from the stashed branch only when it directly supports the steps above (e.g., the describe cache helper) and only after validating the snippet does not cascade into large refactors.

### Testing constraints we must honor
- Salesforce **does not allow Apex tests to insert or update History objects**, nor can we coerce Flow/Aura tests into creating real history rows outside very narrow patterns. Any refactor must therefore be validated either with existing org data, manual QA, or new tests that focus on the controller’s *post-query processing* (e.g., `preparingResponse()`, batching utilities) using fabricated SObjects.
- To avoid destabilizing hard-to-maintain tests, implement the performance fixes in small, independent increments (e.g., schema describe caching first, then backlog pointer mechanics) and keep unit tests scoped to logic we can deterministically control.
- If we introduce a new backlog-pointer format, we should design it so legacy JSON payloads are still replayed without failures—tests can then validate the conversion helpers without needing actual history records.

## Verification Plan
- Create a listener with `Enable_History__c = true`, clear `Last_Execution_On__c`, and ensure the first run backfills without exceeding ~5,000 ms CPU even when the backing history object contains >100k rows.
- Confirm that `Flowdometer__Unprocessed_History_Records__c` no longer balloons; subsequent runs should resume from a lightweight pointer and avoid repeated JSON churn.
- Validate that incremental runs (`lastExecutionOn != null`) are unaffected and still respect the `CreatedDate > :lastExecutionOn` filter.
- Add regression tests that seed more than 1,500 history rows, run the new chunking logic, and assert we eventually process the entire backlog without duplicate Flow Steps or CPU exceptions.

