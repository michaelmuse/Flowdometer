@IsTest
private class ListenerUpdateFlowControllerTest {
    @IsTest
    static void testUpdateFlowRecords() {
        // Create test data
        Listener__c listenerConfig = new Listener__c(
            Object_Name__c = 'Opportunity',
            Field_To_Track__c = 'StageName'
        );
        insert listenerConfig;

        Opportunity opportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        opportunity.StageName = 'Qualification';
        update opportunity;

        Flow__c flow1 = new Flow__c();
        insert new List<Flow__c>{ flow1 };

        Step__c step1 = new Step__c(
            Field_Value_Initial__c = 'Prospecting',
            Flow__c = flow1.Id
        );
        Step__c step2 = new Step__c(
            Field_Value_Initial__c = 'Qualification',
            Flow__c = flow1.Id
        );
        insert new List<Step__c>{ step1, step2 };

        // Create test request. varTrackedFieldLabel is set so the reverse
        // population path runs: Opportunity has no Stage_Flow__c lookup in a
        // test org, proving the missing-field case is a graceful no-op that
        // does not affect the primary response (Build Plan Item B).
        ListenerUpdateFlowController.FlowUpdateRequest request1 = new ListenerUpdateFlowController.FlowUpdateRequest();
        request1.varCurrentObjectID = opportunity.Id;
        request1.varCurrentObjectName = 'Opportunity';
        request1.varFlowID = flow1.Id;
        request1.currentStepId = step1.Id;
        request1.varTrackedFieldLabel = 'Stage';

        ListenerUpdateFlowController.FlowUpdateRequest request2 = new ListenerUpdateFlowController.FlowUpdateRequest();
        request2.varCurrentObjectID = opportunity.Id;
        request2.varCurrentObjectName = 'Opportunity';
        request2.varFlowID = flow1.Id;
        request2.currentStepId = step2.Id;
        request2.varTrackedFieldLabel = 'Stage';

        // Call the method
        List<ListenerUpdateFlowController.FlowUpdateResponse> responseList = ListenerUpdateFlowController.updateFlowRecords(
            new List<ListenerUpdateFlowController.FlowUpdateRequest>{
                request1,
                request2
            }
        );
        ListenerUpdateFlowController.FlowUpdateResponse response = responseList[0];

        // Perform assertions
        System.assertEquals(true, response.isCheckSuccess);
        System.assertEquals(true, response.hasRecords);
        System.assertEquals(2, response.lstFlowToUpdate.size());
    }

    /**
     * Positive path for reverse lookup population (Build Plan Item B).
     * Dynamic lookups (e.g. Opportunity.Stage_Flow__c) cannot exist in a test
     * org, so the test targets the packaged Flow__c.Goal__c field - a real
     * lookup to Flow__c - via the @TestVisible override. This exercises the
     * full path: two-candidate (namespace-aware) field resolution, the
     * reference-to-Flow__c type check, the query-compare, and the DML.
     */
    @IsTest
    static void testReverseLookupPopulationWritesValue() {
        Id goalRtId = Schema.SObjectType.Flow__c.getRecordTypeInfosByDeveloperName()
            .get('Goal').getRecordTypeId();
        Flow__c trackedFlow = new Flow__c();
        Flow__c trackerFlow = new Flow__c(RecordTypeId = goalRtId);
        insert new List<Flow__c>{ trackedFlow, trackerFlow };

        String flowObjectApi = Flow__c.SObjectType.getDescribe().getName();

        ListenerUpdateFlowController.FlowUpdateRequest request = new ListenerUpdateFlowController.FlowUpdateRequest();
        request.varCurrentObjectID = trackedFlow.Id;
        request.varCurrentObjectName = flowObjectApi;
        request.varFlowID = trackerFlow.Id;
        request.varTrackedFieldLabel = 'Anything';

        ListenerUpdateFlowController.reverseFieldApiNameOverride = 'Goal__c';

        Test.startTest();
        List<ListenerUpdateFlowController.FlowUpdateResponse> responseList =
            ListenerUpdateFlowController.updateFlowRecords(
                new List<ListenerUpdateFlowController.FlowUpdateRequest>{ request }
            );
        Test.stopTest();

        System.assertEquals(true, responseList[0].isCheckSuccess,
            'Primary processing must succeed: ' + responseList[0].errorMessage);

        Flow__c reloaded = [SELECT Goal__c FROM Flow__c WHERE Id = :trackedFlow.Id];
        System.assertEquals(trackerFlow.Id, reloaded.Goal__c,
            'Reverse lookup on the tracked record should point at the Flow tracker');
        System.assertEquals(false, ListenerUpdateFlowController.reverseLookupGuard,
            'Recursion guard must be reset after the write');
    }

    /**
     * A record already pointing at the right Flow must be skipped: redundant
     * DML would re-fire subscriber automation on every Step.
     */
    @IsTest
    static void testReverseLookupPopulationSkipsWhenAlreadySet() {
        Id goalRtId = Schema.SObjectType.Flow__c.getRecordTypeInfosByDeveloperName()
            .get('Goal').getRecordTypeId();
        Flow__c trackerFlow = new Flow__c(RecordTypeId = goalRtId);
        insert trackerFlow;
        Flow__c trackedFlow = new Flow__c(Goal__c = trackerFlow.Id);
        insert trackedFlow;

        ListenerUpdateFlowController.FlowUpdateRequest request = new ListenerUpdateFlowController.FlowUpdateRequest();
        request.varCurrentObjectID = trackedFlow.Id;
        request.varCurrentObjectName = Flow__c.SObjectType.getDescribe().getName();
        request.varFlowID = trackerFlow.Id;
        request.varTrackedFieldLabel = 'Anything';

        ListenerUpdateFlowController.reverseFieldApiNameOverride = 'Goal__c';

        Test.startTest();
        Integer dmlBefore = Limits.getDmlStatements();
        ListenerUpdateFlowController.populateReverseLookups(
            new List<ListenerUpdateFlowController.FlowUpdateRequest>{ request }
        );
        Integer dmlAfter = Limits.getDmlStatements();
        Test.stopTest();

        System.assertEquals(dmlBefore, dmlAfter,
            'No DML should run when the reverse lookup already has the right value');
    }

    /**
     * The static recursion guard must block a same-transaction re-entry
     * (e.g. subscriber automation fired by the reverse write calling back
     * into listener processing).
     */
    @IsTest
    static void testReverseLookupGuardBlocksReentry() {
        Flow__c trackedFlow = new Flow__c();
        Flow__c trackerFlow = new Flow__c();
        insert new List<Flow__c>{ trackedFlow, trackerFlow };

        ListenerUpdateFlowController.FlowUpdateRequest request = new ListenerUpdateFlowController.FlowUpdateRequest();
        request.varCurrentObjectID = trackedFlow.Id;
        request.varCurrentObjectName = Flow__c.SObjectType.getDescribe().getName();
        request.varFlowID = trackerFlow.Id;
        request.varTrackedFieldLabel = 'Anything';

        ListenerUpdateFlowController.reverseFieldApiNameOverride = 'Goal__c';
        ListenerUpdateFlowController.reverseLookupGuard = true;

        Test.startTest();
        ListenerUpdateFlowController.populateReverseLookups(
            new List<ListenerUpdateFlowController.FlowUpdateRequest>{ request }
        );
        Test.stopTest();

        ListenerUpdateFlowController.reverseLookupGuard = false;

        Flow__c reloaded = [SELECT Goal__c FROM Flow__c WHERE Id = :trackedFlow.Id];
        System.assertEquals(null, reloaded.Goal__c,
            'No write should occur while the recursion guard is active');
    }

    /**
     * Field resolution: missing field and non-lookup collisions return null;
     * a real lookup-to-Flow__c field resolves (namespace-aware) to its
     * schema-confirmed API name.
     */
    @IsTest
    static void testResolveReverseLookupFieldApi() {
        // No such field on Opportunity in a test org
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveReverseLookupFieldApi('Opportunity', 'Stage'),
            'Missing dynamic field must resolve to null');

        // Unknown object
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveReverseLookupFieldApi('No_Such_Object__c', 'Stage'),
            'Unknown object must resolve to null');

        // Non-lookup collision: Flow__c.Tracked_Object__c is a text field
        ListenerUpdateFlowController.reverseFieldApiNameOverride = 'Tracked_Object__c';
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveReverseLookupFieldApi(
                Flow__c.SObjectType.getDescribe().getName(), 'Anything'),
            'A non-lookup field with a matching name must not be written to');

        // Real lookup to Flow__c resolves to the schema-confirmed name
        ListenerUpdateFlowController.reverseFieldApiNameOverride = 'Goal__c';
        String resolved = ListenerUpdateFlowController.resolveReverseLookupFieldApi(
            Flow__c.SObjectType.getDescribe().getName(), 'Anything');
        System.assertNotEquals(null, resolved, 'Lookup-to-Flow__c field must resolve');
        System.assert(resolved.endsWithIgnoreCase('Goal__c'),
            'Resolved name should be the schema-confirmed API name, got: ' + resolved);
    }

    /**
     * Flow-side field resolution (dynamic lookup ON Flow__c pointing at the
     * tracked object). Mirrors the reverse-direction matrix: unknown object
     * and missing field return null; a same-named non-lookup field returns
     * null; a lookup pointing at a DIFFERENT object than the tracked one
     * returns null (write-to-wrong-object guard); a real match resolves to
     * the schema-confirmed (namespace-aware) API name.
     */
    @IsTest
    static void testResolveFlowSideLookupFieldApi() {
        String flowApi = Flow__c.SObjectType.getDescribe().getName();

        // Unknown object / blank input
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi('No_Such_Object__c'),
            'Unknown object must resolve to null');
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi(null),
            'Blank object must resolve to null');

        // Shipped lookup resolves with NO override: Flow__c has a packaged
        // Opportunity lookup, and the Opportunity label-derived name matches.
        String resolvedShipped =
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi('Opportunity');
        System.assertNotEquals(null, resolvedShipped,
            'Shipped Flow__c.Opportunity lookup must resolve from the object label');
        System.assert(resolvedShipped.endsWithIgnoreCase('Opportunity__c'),
            'Resolved name should be schema-confirmed, got: ' + resolvedShipped);

        // Non-lookup collision: Flow__c.Tracked_Object__c is a text field
        ListenerUpdateFlowController.flowSideFieldApiNameOverride = 'Tracked_Object__c';
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi(flowApi),
            'A non-lookup field with a matching name must not be written to');

        // Wrong referenceTo: Flow__c.Opportunity__c references Opportunity,
        // not Flow__c — must not resolve when the tracked object is Flow__c.
        ListenerUpdateFlowController.flowSideFieldApiNameOverride = 'Opportunity__c';
        System.assertEquals(null,
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi(flowApi),
            'A lookup to a different object must not resolve');

        // Positive: Flow__c.Goal__c is a real lookup to Flow__c
        ListenerUpdateFlowController.flowSideFieldApiNameOverride = 'Goal__c';
        String resolvedDynamic =
            ListenerUpdateFlowController.resolveFlowSideLookupFieldApi(flowApi);
        System.assertNotEquals(null, resolvedDynamic,
            'Lookup referencing the tracked object must resolve');
        System.assert(resolvedDynamic.endsWithIgnoreCase('Goal__c'),
            'Resolved name should be schema-confirmed, got: ' + resolvedDynamic);
    }

    /**
     * End-to-end Flow-side population: when the packaged-lookup map misses
     * (tracked object's label != API name, i.e. every custom object), the
     * dynamic resolver supplies the field and updateFlowRecords sets the
     * tracked record Id on the OUTBOUND Flow__c sObject (the calling flow
     * performs the DML). Dynamic fields can't exist in a test org, so the
     * test targets packaged Flow__c.Goal__c via the override, with Flow__c
     * itself acting as the tracked object (Goal__c references Flow__c).
     */
    @IsTest
    static void testFlowSideLookupPopulationSetsField() {
        Flow__c trackedRecord = new Flow__c();
        Flow__c trackerFlow = new Flow__c();
        insert new List<Flow__c>{ trackedRecord, trackerFlow };

        ListenerUpdateFlowController.FlowUpdateRequest request = new ListenerUpdateFlowController.FlowUpdateRequest();
        request.varCurrentObjectID = trackedRecord.Id;
        // Flow__c's label-derived name ("Flow") never matches its API name,
        // exercising the map-miss -> dynamic-resolver fallback path.
        request.varCurrentObjectName = Flow__c.SObjectType.getDescribe().getName();
        request.varFlowID = trackerFlow.Id;
        // varTrackedFieldLabel deliberately null: reverse population skips,
        // isolating the Flow-side direction.

        ListenerUpdateFlowController.flowSideFieldApiNameOverride = 'Goal__c';

        Test.startTest();
        List<ListenerUpdateFlowController.FlowUpdateResponse> responseList =
            ListenerUpdateFlowController.updateFlowRecords(
                new List<ListenerUpdateFlowController.FlowUpdateRequest>{ request }
            );
        Test.stopTest();

        ListenerUpdateFlowController.FlowUpdateResponse response = responseList[0];
        System.assertEquals(true, response.isCheckSuccess,
            'Primary processing must succeed: ' + response.errorMessage);
        System.assertEquals(1, response.lstFlowToUpdate.size());
        System.assertEquals(trackedRecord.Id,
            (Id) response.lstFlowToUpdate[0].get(Flow__c.Goal__c),
            'Flow-side lookup must carry the tracked record Id for the flow to persist');
    }
}