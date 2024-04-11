public with sharing class QueryBuilderUtils
{
    private static final String DEFAULT_HISTORY_FIELDS = 'Id, Field, OldValue, NewValue, CreatedDate';
   
    public static String getParentNameFieldc(String objectName)
    {
        Map<String, String> objectToNameFieldMap = new Map<String, String>
        {
            'Case' => 'CaseNumber',
            'Solution' => 'SolutionNumber',
            'Contract' => 'ContractNumber'
        };
        
        if (objectToNameFieldMap.containsKey(objectName))
        {
            return objectToNameFieldMap.get(objectName);
        }
        
        // Return 'Name' by default, because it's used by majority of standard objects and all custom objects
        return 'Name';
    }
    
    public static String getHistoryFields(SObjectType sObjectType)
    {
        String objectName = sObjectType.getDescribe().getName();
        String parentId = objectName.endsWith('__c') ? 'ParentId' : (objectName + 'Id');
        
        return DEFAULT_HISTORY_FIELDS + ', ' + parentId;
    }
    
    public static String getRecordHistoryObjectName(SObjectType sObjectType)
    {
        // Special case: Opportunity
        if (sObjectType == Opportunity.getSObjectType())
        {
            return 'OpportunityFieldHistory';
        }
        
        // Determine if the object is custom or not
        Boolean isCustom = sObjectType.getDescribe().isCustom();
        String objectName = sObjectType.getDescribe().getName();
        
        // Handle standard and custom objects based on the flag
        if (isCustom)
        {
            // Custom Objects: Remove '__c' and append '__History'
            String cleanedObjectName = objectName.replace('__c', '');
            return cleanedObjectName + '__History';
        }
        
        // Standard Objects: Directly append "History" to the object name
        return objectName + 'History';
    }
}