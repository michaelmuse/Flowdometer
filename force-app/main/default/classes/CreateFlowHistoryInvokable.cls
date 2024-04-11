public with sharing class CreateFlowHistoryInvokable
{
    public class CreateFlowHistoryRequest
    {
        @InvocableVariable
        public Listener__c listenerConfig;
    }
    
    public class CreateFlowHistoryResponse
    {
        @InvocableVariable
        public String status;
        
        @InvocableVariable
        public String message;
        
        public CreateFlowHistoryResponse(String status, String message)
        {
            this.status = status;
            this.message = message;
        }
    }
    
    @InvocableMethod
    public static List<CreateFlowHistoryResponse> executeCreateFlowHistoryBatch(List<CreateFlowHistoryRequest> requests)
    {
        if(requests.isEmpty())
        {
            return setResponse('ERROR', 'You must provide a valid Listener Id');
        }
        
        System.enqueueJob(new CreateFlowHistoryBatch(requests[0].listenerConfig.Id));
        return null;
    }
    
    private static List<CreateFlowHistoryResponse> setResponse(String status, String message)
    {
        return new List<CreateFlowHistoryResponse>
        {
            new CreateFlowHistoryResponse(status, message)
        };
    }
}