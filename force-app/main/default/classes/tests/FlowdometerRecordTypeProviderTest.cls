/**
 * Tests for FlowdometerRecordTypeProvider.
 *
 * Validates that describe-based resolution returns the exact packaged record types in
 * the current org's namespace context (these tests run in the packaging org, the
 * namespaced 2GP build org, and subscriber orgs). The SOQL cross-check resolves the
 * object API names via describe too, so the assertions are namespace-agnostic.
 */
@isTest
private class FlowdometerRecordTypeProviderTest {
    @isTest
    static void testResolvesAllFourRecordTypeIds() {
        Test.startTest();
        List<FlowdometerRecordTypeProvider.Response> responses =
            FlowdometerRecordTypeProvider.getRecordTypeIds(new List<String>{ null });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One response per request element');
        FlowdometerRecordTypeProvider.Response res = responses[0];

        String flowObjectName = Flow__c.SObjectType.getDescribe().getName();
        String stepObjectName = Step__c.SObjectType.getDescribe().getName();
        Map<String, Id> expected = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName, SobjectType
            FROM RecordType
            WHERE SobjectType IN (:flowObjectName, :stepObjectName)
                AND DeveloperName IN ('Tracker', 'Goal')
        ]) {
            expected.put(rt.SobjectType + '.' + rt.DeveloperName, rt.Id);
        }

        System.assertEquals(
            expected.get(flowObjectName + '.Tracker'),
            (Id) res.flowTrackerRecordTypeId,
            'Flow Tracker record type Id'
        );
        System.assertEquals(
            expected.get(flowObjectName + '.Goal'),
            (Id) res.flowGoalRecordTypeId,
            'Flow Goal record type Id'
        );
        System.assertEquals(
            expected.get(stepObjectName + '.Tracker'),
            (Id) res.stepTrackerRecordTypeId,
            'Step Tracker record type Id'
        );
        System.assertEquals(
            expected.get(stepObjectName + '.Goal'),
            (Id) res.stepGoalRecordTypeId,
            'Step Goal record type Id'
        );
    }

    @isTest
    static void testBulkifiedResponseSizeMatchesRequests() {
        List<FlowdometerRecordTypeProvider.Response> responses =
            FlowdometerRecordTypeProvider.getRecordTypeIds(new List<String>{ null, null, null });
        System.assertEquals(3, responses.size(), 'One response per interview');
        System.assertEquals(
            responses[0].flowTrackerRecordTypeId,
            responses[2].flowTrackerRecordTypeId,
            'All interviews receive identical values'
        );
    }

    @isTest
    static void testEmptyRequestListStillReturnsOneResponse() {
        List<FlowdometerRecordTypeProvider.Response> responses =
            FlowdometerRecordTypeProvider.getRecordTypeIds(new List<String>());
        System.assertEquals(1, responses.size(), 'Empty input yields a single response');
        System.assertNotEquals(null, responses[0].flowTrackerRecordTypeId, 'Ids resolved');
    }
}
