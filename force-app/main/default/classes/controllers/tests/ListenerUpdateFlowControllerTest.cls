@IsTest
private class ListenerUpdateFlowControllerTest {
    @IsTest
    static void testUpdateFlowRecords() {
        // Create test data
        Flowdometer__Listener__c listenerConfig = new Flowdometer__Listener__c(
            Flowdometer__Object_Name__c = 'Opportunity',
            Flowdometer__Field_To_Track__c = 'StageName'
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

        Flowdometer__Flow__c flow1 = new Flowdometer__Flow__c();
        insert new List<Flowdometer__Flow__c>{ flow1 };

        Flowdometer__Step__c step1 = new Flowdometer__Step__c(
            Flowdometer__Field_Value_Initial__c = 'Prospecting',
            Flowdometer__Flow__c = flow1.Id
        );
        Flowdometer__Step__c step2 = new Flowdometer__Step__c(
            Flowdometer__Field_Value_Initial__c = 'Qualification',
            Flowdometer__Flow__c = flow1.Id
        );
        insert new List<Flowdometer__Step__c>{ step1, step2 };

        // Create test request
        ListenerUpdateFlowController.FlowUpdateRequest request1 = new ListenerUpdateFlowController.FlowUpdateRequest();
        request1.varCurrentObjectID = opportunity.Id;
        request1.varCurrentObjectName = 'Opportunity';
        request1.varFlowID = flow1.Id;
        request1.currentStepId = step1.Id;

        ListenerUpdateFlowController.FlowUpdateRequest request2 = new ListenerUpdateFlowController.FlowUpdateRequest();
        request2.varCurrentObjectID = opportunity.Id;
        request2.varCurrentObjectName = 'Opportunity';
        request2.varFlowID = flow1.Id;
        request2.currentStepId = step2.Id;

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
}
