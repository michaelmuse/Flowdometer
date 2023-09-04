global with sharing class ListenerUpdateFlowController {
    @InvocableMethod(label='Update Flow Records' description='' category='ListenerUpdateFlowController')
    public static List<FlowUpdateResponse> updateFlowRecords(List<FlowUpdateRequest> listenerFlowToUpdateLst) {
        FlowUpdateResponse response = new FlowUpdateResponse();
        List<Flowdometer__Flow__c> listenerFlowToUpdate = new List<Flowdometer__Flow__c>();
        try{
            MetaDataUtilityCls.getLookupField('Flowdometer__Flow__c');
            for(FlowUpdateRequest req : listenerFlowToUpdateLst){
                Flowdometer__Flow__c listenerFlow = new Flowdometer__Flow__c(Id = req.varFlowID);
                String fieldToUpdate = MetaDataUtilityCls.lookUpAPINameMap.containsKey(req.varCurrentObjectName) ? MetaDataUtilityCls.lookUpAPINameMap.get(req.varCurrentObjectName) : NULL;
                System.debug('fieldToUpdate - '+fieldToUpdate);
                if(fieldToUpdate != NULL){
                    listenerFlow.put(fieldToUpdate, req.varCurrentObjectID);
                }
                listenerFlow.Flowdometer__Most_Recent_Step__c = req.currentStepId;
                System.debug('listenerFlow - '+listenerFlow);
                listenerFlowToUpdate.add(listenerFlow);
            }
            response.lstFlowToUpdate = listenerFlowToUpdate;
            response.hasRecords = !listenerFlowToUpdate.isEmpty();
        }catch(Exception ex){
            response.isCheckSuccess = false;
        }
        return new List<FlowUpdateResponse>{response};
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

        global FlowUpdateResponse(){
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstFlowToUpdate = new List<Flowdometer__Flow__c>();
        }
    }
}