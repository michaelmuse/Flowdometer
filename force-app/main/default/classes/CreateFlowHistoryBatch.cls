global class CreateFlowHistoryBatch implements Queueable, Database.Batchable<SObject>
{
    public String recordId;
    public CreateFlowHistoryBatch(String recordId)
    {
        this.recordId = recordId;
    }
    
    // Queueable interface methods
    global void execute(QueueableContext context) {
        Database.executeBatch(new CreateFlowHistoryBatch(recordId));
    }
    
    
    // Batchable Interface methods
    global Id executeBatch() {
        return Database.executeBatch(new CreateFlowHistoryBatch(recordId),20);
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(buildQuery(recordId));
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {}
    
    global void finish(Database.BatchableContext bc) {}
    
    public static String buildQuery(Id recordId)
    {
        Flowdometer__Listener__c listener = [
            SELECT Id, Flowdometer__isActive__c, Flowdometer__Object_Name__c, Flowdometer__Field_To_Track__c
            FROM Flowdometer__Listener__c
            WHERE Id = :recordId
        ];
        
        SObjectType sObjectType = Schema.getGlobalDescribe().get(listener.Flowdometer__Object_Name__c).getDescribe().getSObjectType();
        
        String query =
            'SELECT ' + QueryBuilderUtils.getHistoryFields(sObjectType)
            + ' FROM ' + QueryBuilderUtils.getRecordHistoryObjectName(sObjectType)
            + ' WHERE Field = \'' + listener.Flowdometer__Field_To_Track__c + '\'';
        
        System.debug(query);
        return query;
    }
}