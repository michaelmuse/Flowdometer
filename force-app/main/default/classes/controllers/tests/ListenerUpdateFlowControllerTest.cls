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