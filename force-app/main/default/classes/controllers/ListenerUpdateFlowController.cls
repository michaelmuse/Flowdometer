global with sharing class ListenerUpdateFlowController {

    // ── Reverse lookup population (Build Plan Item B) ────────────────────
    // Guard against same-transaction re-entry: writing the back-reference
    // onto the tracked record can fire subscriber automation that re-enters
    // listener processing synchronously. The try/catch covers errors; this
    // flag covers recursion. Reset after the DML so later batches in the
    // same transaction still populate.
    @TestVisible private static Boolean reverseLookupGuard = false;
    // Test seam: lets unit tests target a packaged lookup-to-Flow__c field,
    // since the dynamically created fields don't exist in a test org.
    @TestVisible private static String reverseFieldApiNameOverride;
    // Test seam for the Flow-side direction (dynamic lookup ON Flow__c that
    // points at the tracked object), same rationale as above.
    @TestVisible private static String flowSideFieldApiNameOverride;

    //This method is called from the flow to update the flow records with the current object id and name
    @InvocableMethod(
        Label='Update Flow Records'
        Description=''
        Category='ListenerUpdateFlowController'
    )
    public static List<FlowUpdateResponse> updateFlowRecords(
        List<FlowUpdateRequest> lstFlowToUpdate
    ) {
        FlowUpdateResponse response = new FlowUpdateResponse();
        List<Flow__c> listenerFlowToUpdate = new List<Flow__c>();
        try {
            // CRUD permission check
            if (!Schema.sObjectType.Flow__c.isUpdateable()) {
                throw new SecurityException('Insufficient permissions to update Flow records');
            }
            
            // Input validation
            if (lstFlowToUpdate == null || lstFlowToUpdate.isEmpty() || 
                lstFlowToUpdate[0].varFlowID == null) {
                throw new IllegalArgumentException('Missing required input parameters');
            }
            
            MetaDataUtilityCls.setLookupFieldMaps(Flow__c.SObjectType.getDescribe().getName());
            System.debug(
                'listenerFlowToUpdateLst - ' + lstFlowToUpdate
            );

            for (FlowUpdateRequest req : lstFlowToUpdate) {
                // Input validation for each request
                if (req.varFlowID == null) {
                    continue; // Skip invalid records
                }
                
                Flow__c listenerFlow = new Flow__c(
                    Id = req.varFlowID
                );
                String fieldToUpdate = MetaDataUtilityCls.lookUpAPINameMap.containsKey(
                        req.varCurrentObjectName
                    )
                    ? MetaDataUtilityCls.lookUpAPINameMap.get(
                          req.varCurrentObjectName
                      )
                    : null;

                System.debug('fieldToUpdate - ' + fieldToUpdate);

                if (fieldToUpdate != null) {
                    // SYSTEM-CONTEXT bookkeeping write of the package's own
                    // lookup on its own Flow__c object. Deliberately NO
                    // isUpdateable()/FLS guard (Build Plan: population is
                    // FLS-independent — the triggering user may lack FLS on
                    // the field, e.g. a dynamic lookup granted only via the
                    // unmanaged Flowdometer_Dynamic_FLS PS, and that must not
                    // skip the write). Field existence is schema-verified;
                    // the DML is performed by the calling flow in its
                    // (system-mode) run context.
                    Schema.SObjectField field = Schema.sObjectType.Flow__c.fields.getMap().get(fieldToUpdate);
                    if (field != null) {
                        listenerFlow.put(fieldToUpdate, req.varCurrentObjectID);
                    } else {
                        System.debug(LoggingLevel.WARN, 'Field ' + fieldToUpdate + ' not found on Flow__c');
                    }
                } else {
                    // Dynamic Flow-side lookup (Flow__c -> tracked record).
                    // lookUpAPINameMap is keyed by field LABEL and the lookup
                    // key above is the object API NAME, so it only matches
                    // when the two are equal (standard objects). Dynamically
                    // created lookups on Flow__c are labeled with the tracked
                    // object's LABEL ("QA Tracked"), so custom objects never
                    // match — resolve by describe instead.
                    String dynamicFieldApi = resolveFlowSideLookupFieldApi(req.varCurrentObjectName);
                    if (dynamicFieldApi != null) {
                        // SYSTEM-CONTEXT bookkeeping write of the package's own
                        // dynamically created field on its own Flow__c object.
                        // Deliberately NO isUpdateable()/FLS guard: the user
                        // whose change triggered processing may lack FLS on the
                        // dynamic field, and that must not block the write.
                        // Visibility is governed by the unmanaged
                        // Flowdometer_Dynamic_FLS permission set. The DML is
                        // performed by the calling flow in its (system-mode)
                        // run context — same as the packaged-lookup path above.
                        listenerFlow.put(dynamicFieldApi, req.varCurrentObjectID);
                    }
                }

                // Check field-level security for Most_Recent_Step__c field
                try {
                    if (Schema.sObjectType.Flow__c.fields.Most_Recent_Step__c.isUpdateable()) {
                listenerFlow.Most_Recent_Step__c = req.currentStepId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error checking Most_Recent_Step__c permissions: ' + e.getMessage());
                }
                
                System.debug('listenerFlow - ' + listenerFlow);
                listenerFlowToUpdate.add(listenerFlow);
            }
            response.lstFlowToUpdate = listenerFlowToUpdate;
            response.hasRecords = !listenerFlowToUpdate.isEmpty();

            // Best-effort reverse population (tracked record -> Flow__c).
            // Internally try/caught: a failure here never affects the response.
            populateReverseLookups(lstFlowToUpdate);
        } catch (SecurityException se) {
            response.isCheckSuccess = false;
            response.errorMessage = 'Security error: ' + se.getMessage();
            System.debug(LoggingLevel.ERROR, 'Security exception: ' + se.getMessage());
        } catch (Exception ex) {
            response.isCheckSuccess = false;
            response.errorMessage = 'Error: ' + ex.getMessage();
            System.debug(LoggingLevel.ERROR, 'Exception: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
        }

        System.debug(
            'response from ListenerUpdateFlowController - ' + response
        );

        return new List<FlowUpdateResponse>{ response };
    }

    /**
     * Populate the dynamically created lookup on the TRACKED record (e.g.
     * Opportunity.Stage_Flow__c) with the Flow__c tracker Id — Build Plan
     * Item B ("tracked record -> Flow" population). Best-effort by design:
     * every failure path logs and returns; it never throws and never blocks
     * the primary Flow/Step processing. If the dynamic field has not been
     * created/propagated yet (listener just submitted), this no-ops.
     *
     * Security Review note: this is a SYSTEM-CONTEXT bookkeeping write of the
     * package's own correlation field. It intentionally does NOT enforce FLS
     * (no AccessLevel.USER_MODE, no stripInaccessible, no isUpdateable()
     * guard): the user whose field change triggered processing may lack FLS
     * on the field, and that must not block the write. User VISIBILITY of the
     * value is deliberately user-facing and is governed by the unmanaged
     * Flowdometer_Dynamic_FLS permission set (granted by FLSGrantJob and the
     * setup-gate reconciler). Row-level sharing IS respected via this class's
     * `with sharing` declaration. Sharing keywords govern row-level sharing
     * only — they do not control FLS.
     */
    @TestVisible
    private static void populateReverseLookups(List<FlowUpdateRequest> requests) {
        if (reverseLookupGuard || requests == null || requests.isEmpty()) {
            return;
        }
        try {
            // tracked object -> (tracked record Id -> resolved field API name)
            Map<String, Map<Id, String>> fieldByRecordByObject = new Map<String, Map<Id, String>>();
            Map<Id, Id> flowIdByRecordId = new Map<Id, Id>();

            for (FlowUpdateRequest req : requests) {
                if (req == null || req.varFlowID == null || req.varCurrentObjectID == null ||
                    String.isBlank(req.varCurrentObjectName) || String.isBlank(req.varTrackedFieldLabel)) {
                    continue;
                }
                String fieldApi = resolveReverseLookupFieldApi(
                    req.varCurrentObjectName, req.varTrackedFieldLabel
                );
                if (fieldApi == null) {
                    // Field not created/propagated yet, or name collision with a
                    // non-lookup subscriber field: graceful no-op for this row.
                    continue;
                }
                Map<Id, String> fieldByRecord = fieldByRecordByObject.get(req.varCurrentObjectName);
                if (fieldByRecord == null) {
                    fieldByRecord = new Map<Id, String>();
                    fieldByRecordByObject.put(req.varCurrentObjectName, fieldByRecord);
                }
                fieldByRecord.put(req.varCurrentObjectID, fieldApi);
                flowIdByRecordId.put(req.varCurrentObjectID, req.varFlowID);
            }
            if (fieldByRecordByObject.isEmpty()) {
                return;
            }

            List<SObject> toUpdate = new List<SObject>();
            // One query per distinct tracked object type in the batch. A single
            // invocation comes from one flow definition's merged interviews, so
            // in practice this loop runs once.
            for (String objectName : fieldByRecordByObject.keySet()) {
                Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
                if (objType == null) {
                    continue;
                }
                Map<Id, String> fieldByRecord = fieldByRecordByObject.get(objectName);
                Set<Id> recordIds = fieldByRecord.keySet();
                Set<String> selectFields = new Set<String>(fieldByRecord.values());

                // Injection-safe: objectName was resolved through the schema
                // describe above, and field names come from DescribeFieldResult
                // .getName() in resolveReverseLookupFieldApi — neither is raw
                // user input. Ids are bound. No SECURITY_ENFORCED on purpose:
                // this is the FLS-independent system-context path (see header).
                String soql = 'SELECT Id, ' + String.join(new List<String>(selectFields), ', ') +
                    ' FROM ' + objType.getDescribe().getName() + ' WHERE Id IN :recordIds';

                for (SObject rec : Database.query(soql)) {
                    String fieldApi = fieldByRecord.get(rec.Id);
                    Id desiredFlowId = flowIdByRecordId.get(rec.Id);
                    // Skip records already pointing at the right Flow: avoids
                    // redundant DML that would re-fire subscriber automation on
                    // every Step.
                    if ((Id) rec.get(fieldApi) == desiredFlowId) {
                        continue;
                    }
                    SObject upd = objType.newSObject(rec.Id);
                    upd.put(fieldApi, desiredFlowId);
                    toUpdate.add(upd);
                }
            }
            if (toUpdate.isEmpty()) {
                return;
            }

            reverseLookupGuard = true;
            try {
                // Partial-success DML: one bad row must not block the others.
                List<Database.SaveResult> results = Database.update(toUpdate, false);
                for (Database.SaveResult sr : results) {
                    if (!sr.isSuccess()) {
                        System.debug(LoggingLevel.WARN,
                            'Reverse lookup population failed for ' + sr.getId() + ': ' + sr.getErrors());
                    }
                }
            } finally {
                reverseLookupGuard = false;
            }
        } catch (Exception e) {
            // Best-effort: log and move on. The primary processing path and the
            // flow response are unaffected.
            System.debug(LoggingLevel.WARN,
                'Reverse lookup population skipped: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    /**
     * Resolve the dynamic lookup field on the tracked object that points back
     * to Flow__c. The field was created by LookupFieldCreator with label
     * "<tracked field label> Flow" (e.g. "Stage Flow" -> Stage_Flow__c).
     * Two candidates are checked because a runtime-created field carries no
     * namespace in a subscriber org but the org namespace in a namespaced
     * (package build) org. Returns the schema-confirmed API name, or null if
     * the field doesn't exist or is not a lookup to Flow__c.
     */
    @TestVisible
    private static String resolveReverseLookupFieldApi(String objectName, String trackedFieldLabel) {
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        String baseApi = (reverseFieldApiNameOverride != null)
            ? reverseFieldApiNameOverride
            : MetaDataUtilityCls.convertLabeltoAPIName(trackedFieldLabel + ' Flow');

        List<String> candidates = new List<String>{ baseApi };
        String ns = resolveNamespace();
        if (String.isNotBlank(ns)) {
            candidates.add(ns + '__' + baseApi);
        }

        for (String candidate : candidates) {
            Schema.SObjectField fld = fieldMap.get(candidate.toLowerCase());
            if (fld == null) {
                continue;
            }
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            if (dfr.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            for (Schema.SObjectType refTo : dfr.getReferenceTo()) {
                if (refTo == Flow__c.SObjectType) {
                    return dfr.getName();
                }
            }
        }
        return null;
    }

    /**
     * Resolve the dynamic lookup field ON Flow__c that points at the tracked
     * object (the Flow-side direction). LookupFieldCreator created it with
     * label = the tracked object's LABEL (e.g. "QA Tracked" ->
     * QA_Tracked__c on Flow__c). Two candidates are checked for the same
     * namespace reason as resolveReverseLookupFieldApi. The referenceTo check
     * guarantees we never write to a same-named field that points at a
     * different object (e.g. a shipped or subscriber field that happens to
     * collide on name). Returns the schema-confirmed API name, or null if the
     * field doesn't exist (not created/propagated yet — graceful no-op) or is
     * not a lookup to the tracked object.
     */
    @TestVisible
    private static String resolveFlowSideLookupFieldApi(String objectName) {
        if (String.isBlank(objectName)) {
            return null;
        }
        Schema.SObjectType trackedType = Schema.getGlobalDescribe().get(objectName);
        if (trackedType == null) {
            return null;
        }
        String baseApi = (flowSideFieldApiNameOverride != null)
            ? flowSideFieldApiNameOverride
            : MetaDataUtilityCls.convertLabeltoAPIName(trackedType.getDescribe().getLabel());

        List<String> candidates = new List<String>{ baseApi };
        String ns = resolveNamespace();
        if (String.isNotBlank(ns)) {
            candidates.add(ns + '__' + baseApi);
        }

        Map<String, Schema.SObjectField> flowFieldMap =
            Flow__c.SObjectType.getDescribe().fields.getMap();
        for (String candidate : candidates) {
            Schema.SObjectField fld = flowFieldMap.get(candidate.toLowerCase());
            if (fld == null) {
                continue;
            }
            Schema.DescribeFieldResult dfr = fld.getDescribe();
            if (dfr.getType() != Schema.DisplayType.REFERENCE) {
                continue;
            }
            for (Schema.SObjectType refTo : dfr.getReferenceTo()) {
                if (refTo == trackedType) {
                    return dfr.getName();
                }
            }
        }
        return null;
    }

    private static String resolveNamespace() {
        String className = ListenerUpdateFlowController.class.getName();
        return className.contains('.') ? className.substringBefore('.') : '';
    }

    //FlowUpdateRequest params from flow
    global class FlowUpdateRequest {
        @InvocableVariable
        global Id varCurrentObjectID;
        @InvocableVariable
        global String varCurrentObjectName;
        @InvocableVariable
        global Id varFlowID;
        @InvocableVariable
        global Id currentStepId;
        @InvocableVariable(
            Label='Tracked Field Label'
            Description='UI label of the tracked field; used to resolve the dynamic lookup on the tracked record for reverse population'
        )
        global String varTrackedFieldLabel;
    }

    //FlowUpdateResponse params to flow
    global class FlowUpdateResponse {
        @InvocableVariable
        global Boolean isCheckSuccess;
        @InvocableVariable
        global Boolean hasRecords;
        @InvocableVariable
        global List<Flow__c> lstFlowToUpdate;
        @InvocableVariable
        global String errorMessage;

        global FlowUpdateResponse() {
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstFlowToUpdate = new List<Flow__c>();
            this.errorMessage = '';
        }
    }
    
    // Custom exception class for security issues
    public class SecurityException extends Exception {}
}