public with sharing class GetFlowsListController {
    public GetFlowsListController(ApexPages.StandardController stdController) {
        String currentId = ApexPages.CurrentPage().getparameters().get('id');

        // Enforce CRUD/FLS before querying subscriber data
        if (!Schema.sObjectType.Flowdometer__Flow__c.isAccessible() ||
            !Schema.sObjectType.Flowdometer__Flow__c.fields.Flowdometer__Tracked_Field_Name__c.isAccessible() ||
            !Schema.sObjectType.Flowdometer__Flow__c.fields.Flowdometer__Tracked_Object_ID__c.isAccessible()) {
            System.debug(LoggingLevel.WARN, 'Flowdometer__Flow__c is not accessible for the current user context.');
            return;
        }

        List<Flowdometer__Flow__c> flowList = [
            SELECT Id, Name, Flowdometer__Tracked_Field_Name__c
            FROM Flowdometer__Flow__c
            WHERE Flowdometer__Tracked_Object_ID__c = :currentId
            WITH SECURITY_ENFORCED
        ];
    }
}