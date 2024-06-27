global class ListenerUpdateFlowController {
    //This method is called from the flow to update the flow records with the current object id and name
    @InvocableMethod(
        Label='Update Flow Records'
        Description=''
        Category='ListenerUpdateFlowController'
    )
    public static List<FlowUpdateResponse> updateFlowRecords(
        List<FlowUpdateRequest> listenerFlowToUpdateLst
    ) {
        FlowUpdateResponse response = new FlowUpdateResponse();
        List<Flowdometer__Flow__c> listenerFlowToUpdate = new List<Flowdometer__Flow__c>();
        try {
            MetaDataUtilityCls.setLookupFieldMaps('Flowdometer__Flow__c');
            System.debug(
                'listenerFlowToUpdateLst - ' + listenerFlowToUpdateLst
            );

            for (FlowUpdateRequest req : listenerFlowToUpdateLst) {
                Flowdometer__Flow__c listenerFlow = new Flowdometer__Flow__c(
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
                    listenerFlow.put(fieldToUpdate, req.varCurrentObjectID);
                }

                listenerFlow.Flowdometer__Most_Recent_Step__c = req.currentStepId;
                System.debug('listenerFlow - ' + listenerFlow);
                listenerFlowToUpdate.add(listenerFlow);
            }
            response.lstFlowToUpdate = listenerFlowToUpdate;
            response.hasRecords = !listenerFlowToUpdate.isEmpty();
        } catch (Exception ex) {
            response.isCheckSuccess = false;
        }

        System.debug(
            'response from ListenerUpdateFlowController - ' + response
        );

        return new List<FlowUpdateResponse>{ response };
        // q: Could you write some code that I can add to this method, where if hasRecords and checkSuccess are both True, then we update the flow stored in {!FlowToUpdateLst}, and if either of those are False, then we don't update the flow stored in {!FlowToUpdateLst}?
        // a: I think you can do this with a decision element in the flow.  You can have the decision element check the values of the two variables and then branch accordingly.  If you want to do it in the apex class, you can do it like this:
        // if (response.hasRecords && response.isCheckSuccess) {
        //     update response.lstFlowToUpdate;
        // }
        // If I do this, should be able to delete the last 2 elements of the flow called "Listener Creates Trackers": https://museoperations-dev-ed.lightning.force.com/builder_platform_interaction/flowBuilder.app?flowId=3015G0000011bRgQAI
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
    }

    //FlowUpdateResponse params to flow
    global class FlowUpdateResponse {
        @InvocableVariable
        global Boolean isCheckSuccess;
        @InvocableVariable
        global Boolean hasRecords;
        @InvocableVariable
        global List<Flowdometer__Flow__c> lstFlowToUpdate;

        global FlowUpdateResponse() {
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstFlowToUpdate = new List<Flowdometer__Flow__c>();
        }
    }
}
