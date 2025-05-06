global with sharing class ListenerUpdateFlowController {
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
        List<Flowdometer__Flow__c> listenerFlowToUpdate = new List<Flowdometer__Flow__c>();
        try {
            // CRUD permission check
            if (!Schema.sObjectType.Flowdometer__Flow__c.isUpdateable()) {
                throw new SecurityException('Insufficient permissions to update Flow records');
            }
            
            // Input validation
            if (lstFlowToUpdate == null || lstFlowToUpdate.isEmpty() || 
                lstFlowToUpdate[0].varFlowID == null) {
                throw new IllegalArgumentException('Missing required input parameters');
            }
            
            MetaDataUtilityCls.setLookupFieldMaps('Flowdometer__Flow__c');
            System.debug(
                'listenerFlowToUpdateLst - ' + lstFlowToUpdate
            );

            for (FlowUpdateRequest req : lstFlowToUpdate) {
                // Input validation for each request
                if (req.varFlowID == null) {
                    continue; // Skip invalid records
                }
                
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
                    // Check field-level security before updating
                    try {
                        Schema.SObjectField field = Schema.sObjectType.Flowdometer__Flow__c.fields.getMap().get(fieldToUpdate);
                        if (field != null && field.getDescribe().isUpdateable()) {
                            listenerFlow.put(fieldToUpdate, req.varCurrentObjectID);
                        } else {
                            System.debug(LoggingLevel.WARN, 'Field ' + fieldToUpdate + ' is not updateable');
                        }
                    } catch (Exception e) {
                        System.debug(LoggingLevel.ERROR, 'Error checking field permissions: ' + e.getMessage());
                    }
                }

                // Check field-level security for Most_Recent_Step__c field
                try {
                    if (Schema.sObjectType.Flowdometer__Flow__c.fields.Flowdometer__Most_Recent_Step__c.isUpdateable()) {
                        listenerFlow.Flowdometer__Most_Recent_Step__c = req.currentStepId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.ERROR, 'Error checking Most_Recent_Step__c permissions: ' + e.getMessage());
                }
                
                System.debug('listenerFlow - ' + listenerFlow);
                listenerFlowToUpdate.add(listenerFlow);
            }
            response.lstFlowToUpdate = listenerFlowToUpdate;
            response.hasRecords = !listenerFlowToUpdate.isEmpty();
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
        @InvocableVariable
        global String errorMessage;

        global FlowUpdateResponse() {
            this.isCheckSuccess = true;
            this.hasRecords = false;
            this.lstFlowToUpdate = new List<Flowdometer__Flow__c>();
            this.errorMessage = '';
        }
    }
    
    // Custom exception class for security issues
    public class SecurityException extends Exception {}
}
