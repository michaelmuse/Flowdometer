/**
 * Deterministic record-type resolution for the packaged Flow__c and Step__c objects,
 * exposed as an invocable action for the packaged flows.
 *
 * Why this exists: the flows previously resolved record types with SOQL on RecordType,
 * comparing SobjectType against string literals. String literals in flow metadata are
 * NOT namespace-rewritten at package install, so in any namespaced context (2GP build
 * org, subscriber org) the literal 'Flow__c' never matched the actual value
 * 'Flowdometer__Flow__c', the lookup returned no rows, and the listener pipeline
 * faulted with CANNOT_EXECUTE_FLOW_TRIGGER on Listener__c insert.
 *
 * Schema describe references below compile against this package's own objects, so the
 * platform applies the namespace automatically in every context. Resolution is exact:
 * it can never match a subscriber's or another package's look-alike object (e.g. a
 * local My_Flow__c with a 'Tracker' record type).
 *
 * Sharing: 'with sharing' is declared as the secure default. The class performs
 * describe calls only — no SOQL, no DML — so sharing has no functional effect here.
 */
public with sharing class FlowdometerRecordTypeProvider {
    private static final String RT_TRACKER = 'Tracker';
    private static final String RT_GOAL = 'Goal';

    public class Response {
        @InvocableVariable(label='Flow Tracker Record Type Id')
        public String flowTrackerRecordTypeId;
        @InvocableVariable(label='Flow Goal Record Type Id')
        public String flowGoalRecordTypeId;
        @InvocableVariable(label='Step Tracker Record Type Id')
        public String stepTrackerRecordTypeId;
        @InvocableVariable(label='Step Goal Record Type Id')
        public String stepGoalRecordTypeId;
    }

    @InvocableMethod(
        Label='Get Flowdometer Record Type Ids'
        Description='Returns the record type Ids of the packaged Flow and Step objects (Tracker and Goal), resolved via Schema describe so they are correct in any namespace context.'
        Category='Flowdometer'
    )
    public static List<Response> getRecordTypeIds(List<String> requests) {
        // The flow runtime passes one (unmapped, null) list element per interview and
        // expects one response per element. Resolution is org-wide constant data, so
        // every interview receives the same values.
        Integer interviewCount = (requests == null || requests.isEmpty()) ? 1 : requests.size();
        List<Response> responses = new List<Response>();
        for (Integer i = 0; i < interviewCount; i++) {
            Response res = new Response();
            res.flowTrackerRecordTypeId = resolve(Flow__c.SObjectType, RT_TRACKER);
            res.flowGoalRecordTypeId = resolve(Flow__c.SObjectType, RT_GOAL);
            res.stepTrackerRecordTypeId = resolve(Step__c.SObjectType, RT_TRACKER);
            res.stepGoalRecordTypeId = resolve(Step__c.SObjectType, RT_GOAL);
            responses.add(res);
        }
        return responses;
    }

    private static String resolve(Schema.SObjectType sObjType, String developerName) {
        Schema.RecordTypeInfo info = sObjType.getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get(developerName);
        return info == null ? null : String.valueOf(info.getRecordTypeId());
    }
}
